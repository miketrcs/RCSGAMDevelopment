import Foundation

private struct RunSummary {
    var successes = 0
    var misses = 0
    var errors = 0
    var exceptions = 0

    mutating func record(_ result: GAMResult) {
        switch result.status {
        case .deleted, .dryRunFound:
            successes += 1
        case .noMatch, .dryRunNoMatch:
            misses += 1
        case .error:
            errors += 1
        case .exception:
            exceptions += 1
        case .reviewValid, .reviewSkip, .preview:
            break
        }
    }
}

struct NativeDeleteEngine {
    private let csvLoader = CSVLoader()
    private let gamLocator = GAMLocator()
    private let commandBuilder = GAMCommandBuilder()
    private let processRunner = GAMProcessRunner()

    func run(
        config: RunnerConfig,
        emitLine: @escaping @Sendable (String) async -> Void
    ) async throws {
        let rows = try csvLoader.loadRows(from: config.csvPath)
        try Task.checkCancellation()

        switch config.mode {
        case .review:
            try await formatReview(rows: rows, emitLine: emitLine)
        case .preview:
            try await formatPreview(rows: rows, config: config, emitLine: emitLine)
        case .check:
            try await formatCheck(rows: rows, config: config, emitLine: emitLine)
        case .execute:
            try await formatExecute(rows: rows, config: config, emitLine: emitLine)
        }
    }

    func checkGAMVersion(override: String) async throws -> [String] {
        let gamPath = try resolveGAMPath(override: override)
        let command = [gamPath, "version"]
        let result = try await processRunner.run(command: command)

        var output = ["[INFO] Checking GAM version at \(gamPath)"]
        if result.output.isEmpty {
            output.append("[INFO] GAM ran from \(gamPath) but did not return version text.")
        } else {
            output.append(result.output)
        }
        output.append("[INFO] Exit code: \(result.exitCode)")
        return output
    }

    func testGAMSetup(override: String) async throws -> [String] {
        let gamPath = try resolveGAMPath(override: override)
        let commands: [([String], String)] = [
            ([gamPath, "version"], "[INFO] GAM version"),
            ([gamPath, "info", "domain"], "[INFO] GAM domain info")
        ]

        var output = ["[INFO] Running GAM workspace diagnostics using \(gamPath)"]
        for (command, header) in commands {
            try Task.checkCancellation()
            let result = try await processRunner.run(command: command)
            output.append(header)
            if result.output.isEmpty {
                output.append("[INFO] No output returned")
            } else {
                output.append(result.output)
            }
            output.append("[INFO] Exit code: \(result.exitCode)")
        }
        return output
    }

    private func formatReview(
        rows: [CSVRow],
        emitLine: @escaping @Sendable (String) async -> Void
    ) async throws {
        var validCount = 0
        var skippedCount = 0
        var bufferedLines: [String] = []
        bufferedLines.reserveCapacity(200)

        for row in rows {
            try Task.checkCancellation()
            let description = formatRow(row.rawFields)
            if row.validation.isValid {
                validCount += 1
                bufferedLines.append("[CSV-VALID] row=\(row.rowNumber) \(description)")
            } else {
                skippedCount += 1
                bufferedLines.append("[CSV-SKIP] row=\(row.rowNumber) reason=\(row.validation.reason) \(description)")
            }

            if bufferedLines.count >= 200 {
                await emitLine(bufferedLines.joined(separator: "\n"))
                bufferedLines.removeAll(keepingCapacity: true)
            }
        }

        if !bufferedLines.isEmpty {
            await emitLine(bufferedLines.joined(separator: "\n"))
        }
        await emitLine("")
        await emitLine("Done. rows=\(rows.count) valid=\(validCount) skipped=\(skippedCount) ran=\(rows.count) errors=0 exceptions=0 (mode=review)")
    }

    private func formatPreview(
        rows: [CSVRow],
        config: RunnerConfig,
        emitLine: @escaping @Sendable (String) async -> Void
    ) async throws {
        let tasks = rows
            .filter { $0.validation.isValid }
            .map { GAMTask(rowNumber: $0.rowNumber, user: $0.account, messageID: $0.rfc822MessageID) }

        let gamPath = gamLocator.resolvePath(override: config.gamPathOverride) ?? "gam"
        var bufferedLines: [String] = []
        bufferedLines.reserveCapacity(200)

        for task in tasks {
            try Task.checkCancellation()
            let command = commandBuilder.command(for: task, mode: .preview, gamPath: gamPath)
            bufferedLines.append("[CSV-TEST] user=\(task.user) msgid=\(task.messageID) cmd=\(command.joined(separator: " "))")

            if bufferedLines.count >= 200 {
                await emitLine(bufferedLines.joined(separator: "\n"))
                bufferedLines.removeAll(keepingCapacity: true)
            }
        }

        if !bufferedLines.isEmpty {
            await emitLine(bufferedLines.joined(separator: "\n"))
        }
        let skippedCount = rows.count - tasks.count
        await emitLine("")
        await emitLine("Done. rows=\(rows.count) valid=\(tasks.count) skipped=\(skippedCount) ran=\(tasks.count) miss=0 errors=0 (mode=preview)")
    }

    private func formatCheck(
        rows: [CSVRow],
        config: RunnerConfig,
        emitLine: @escaping @Sendable (String) async -> Void
    ) async throws {
        let gamPath = try resolveGAMPath(override: config.gamPathOverride)
        let validTasks = rows
            .filter { $0.validation.isValid }
            .map { GAMTask(rowNumber: $0.rowNumber, user: $0.account, messageID: $0.rfc822MessageID) }

        let tasks = Array(validTasks.prefix(10))
        if validTasks.count > tasks.count {
            await emitLine("[INFO] check mode limiting to first 10 valid rows (from \(validTasks.count)).")
        }
        await emitLine("Starting. rows=\(rows.count) valid=\(tasks.count) workers=\(min(config.workers, max(1, tasks.count))) retries=\(config.retries) mode=check")

        let summary = try await runConcurrentTasks(
            tasks: tasks,
            config: config,
            gamPath: gamPath,
            mode: .check,
            emitLine: emitLine
        )

        let skippedCount = rows.count - validTasks.count
        await emitLine("")
        await emitLine("Done. rows=\(rows.count) valid=\(validTasks.count) skipped=\(skippedCount) ran=\(tasks.count) miss=\(summary.misses) errors=\(summary.errors) exceptions=\(summary.exceptions) (mode=check)")
    }

    private func formatExecute(
        rows: [CSVRow],
        config: RunnerConfig,
        emitLine: @escaping @Sendable (String) async -> Void
    ) async throws {
        let gamPath = try resolveGAMPath(override: config.gamPathOverride)
        let tasks = rows
            .filter { $0.validation.isValid }
            .map { GAMTask(rowNumber: $0.rowNumber, user: $0.account, messageID: $0.rfc822MessageID) }

        await emitLine("Starting. rows=\(rows.count) valid=\(tasks.count) workers=\(min(config.workers, max(1, tasks.count))) retries=\(config.retries) mode=execute")

        let summary = try await runConcurrentTasks(
            tasks: tasks,
            config: config,
            gamPath: gamPath,
            mode: .execute,
            emitLine: emitLine
        )

        let skippedCount = rows.count - tasks.count
        await emitLine("")
        await emitLine("Done. rows=\(rows.count) valid=\(tasks.count) skipped=\(skippedCount) ran=\(tasks.count) miss=\(summary.misses) errors=\(summary.errors) exceptions=\(summary.exceptions) deleted=\(summary.successes) (mode=execute)")
    }

    private func runTask(
        task: GAMTask,
        gamPath: String,
        mode: RunnerMode,
        retries: Int,
        backoffSeconds: Double
    ) async throws -> GAMResult {
        let command = commandBuilder.command(for: task, mode: mode, gamPath: gamPath)
        var attempt = 0

        while true {
            try Task.checkCancellation()
            attempt += 1

            do {
                let processResult = try await processRunner.run(command: command)
                let output = processResult.output
                let outputLower = output.lowercased()

                if isNoMatchOutput(outputLower) {
                    return GAMResult(
                        status: mode == .check ? .dryRunNoMatch : .noMatch,
                        user: task.user,
                        messageID: task.messageID,
                        output: output,
                        attempts: attempt,
                        rowNumber: task.rowNumber
                    )
                }

                if processResult.exitCode == 0 || (mode == .check && isCheckFoundOutput(outputLower)) {
                    return GAMResult(
                        status: mode == .check ? .dryRunFound : .deleted,
                        user: task.user,
                        messageID: task.messageID,
                        output: output,
                        attempts: attempt,
                        rowNumber: task.rowNumber
                    )
                }

                if attempt <= retries && hasRateLimitError(outputLower) {
                    try await Task.sleep(nanoseconds: retryDelayNanoseconds(attempt: attempt, baseSeconds: backoffSeconds))
                    continue
                }

                return GAMResult(
                    status: .error,
                    user: task.user,
                    messageID: task.messageID,
                    output: output,
                    attempts: attempt,
                    rowNumber: task.rowNumber
                )
            } catch AppError.cancelled {
                throw AppError.cancelled
            } catch {
                if attempt <= retries {
                    try await Task.sleep(nanoseconds: retryDelayNanoseconds(attempt: attempt, baseSeconds: backoffSeconds))
                    continue
                }

                return GAMResult(
                    status: .exception,
                    user: task.user,
                    messageID: task.messageID,
                    output: error.localizedDescription,
                    attempts: attempt,
                    rowNumber: task.rowNumber
                )
            }
        }
    }

    private func runConcurrentTasks(
        tasks: [GAMTask],
        config: RunnerConfig,
        gamPath: String,
        mode: RunnerMode,
        emitLine: @escaping @Sendable (String) async -> Void
    ) async throws -> RunSummary {
        if tasks.isEmpty {
            return RunSummary()
        }

        let maxWorkers = max(1, min(config.workers, tasks.count))
        var iterator = tasks.makeIterator()
        var summary = RunSummary()

        try await withThrowingTaskGroup(of: GAMResult.self) { group in
            for _ in 0..<maxWorkers {
                guard let task = iterator.next() else { break }
                group.addTask {
                    try await runTask(
                        task: task,
                        gamPath: gamPath,
                        mode: mode,
                        retries: config.retries,
                        backoffSeconds: config.backoffSeconds
                    )
                }
            }

            while let result = try await group.next() {
                try Task.checkCancellation()
                summary.record(result)
                await emitLine(formatResult(result))

                if result.status == .error && !result.output.isEmpty {
                    await emitLine(result.output)
                    await emitLine("---")
                }

                if let task = iterator.next() {
                    group.addTask {
                        try await runTask(
                            task: task,
                            gamPath: gamPath,
                            mode: mode,
                            retries: config.retries,
                            backoffSeconds: config.backoffSeconds
                        )
                    }
                }
            }
        }

        return summary
    }

    private func formatResult(_ result: GAMResult) -> String {
        switch result.status {
        case .deleted:
            return "[DELETED] user=\(result.user) msgid=\(result.messageID) attempts=\(result.attempts)"
        case .noMatch:
            return "[NOMATCH] user=\(result.user) msgid=\(result.messageID) attempts=\(result.attempts)"
        case .dryRunFound:
            return "[DRYRUNFOUND] user=\(result.user) msgid=\(result.messageID) attempts=\(result.attempts)"
        case .dryRunNoMatch:
            return "[DRYRUNNOMATCH] user=\(result.user) msgid=\(result.messageID) attempts=\(result.attempts)"
        case .error:
            return "[ERR] user=\(result.user) msgid=\(result.messageID) attempts=\(result.attempts)"
        case .exception:
            return "[EXC] user=\(result.user) msgid=\(result.messageID) attempts=\(result.attempts) exc=\(result.output)"
        case .reviewValid, .reviewSkip, .preview:
            return result.output
        }
    }

    private func formatRow(_ fields: [String: String]) -> String {
        let sortedKeys = fields.keys.sorted()
        return sortedKeys.map { key in
            let value = fields[key]?.isEmpty == false ? fields[key]! : "<blank>"
            return "\(key)=\(value)"
        }.joined(separator: " | ")
    }

    private func resolveGAMPath(override: String) throws -> String {
        guard let path = gamLocator.resolvePath(override: override) else {
            throw AppError.gamNotFound
        }
        return path
    }

    private func hasRateLimitError(_ output: String) -> Bool {
        let markers = [
            "rate limit",
            "ratelimit",
            "quota",
            "429",
            "userratelimitexceeded",
            "toomanyrequests",
            "backend error",
            "temporarily unavailable"
        ]
        return markers.contains { output.contains($0) }
    }

    private func isNoMatchOutput(_ output: String) -> Bool {
        let markers = [
            "0 messages",
            "got 0 messages",
            "no messages",
            "no threads",
            "no messages matched",
            "not deleted: no messages matched"
        ]
        return markers.contains { output.contains($0) }
    }

    private func isCheckFoundOutput(_ output: String) -> Bool {
        let markers = [
            "would delete",
            "would be deleted",
            "not deleted:",
            "messages matched",
            "got 1 message",
            "got 2 messages",
            "got 3 messages",
            "got 4 messages",
            "got 5 messages",
            "got 6 messages",
            "got 7 messages",
            "got 8 messages",
            "got 9 messages"
        ]
        return markers.contains { output.contains($0) }
    }

    private func retryDelayNanoseconds(attempt: Int, baseSeconds: Double) -> UInt64 {
        let delaySeconds = baseSeconds * pow(2.0, Double(attempt - 1))
        let clamped = max(0.0, delaySeconds)
        return UInt64(clamped * 1_000_000_000)
    }
}
