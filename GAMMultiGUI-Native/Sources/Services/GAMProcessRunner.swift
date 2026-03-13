import Foundation

private final class ProcessExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var completed = false

    func store(process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        process = nil
        return true
    }

    func cancel() {
        lock.lock()
        let process = self.process
        lock.unlock()
        process?.terminate()
    }
}

struct GAMProcessRunner {
    func run(command: [String]) async throws -> (exitCode: Int32, output: String) {
        guard let executable = command.first else {
            throw AppError.processLaunchFailed("Missing executable.")
        }

        let state = ProcessExecutionState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                task.executableURL = URL(fileURLWithPath: executable)
                task.arguments = Array(command.dropFirst())
                task.standardOutput = stdoutPipe
                task.standardError = stderrPipe

                task.terminationHandler = { process in
                    let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(decoding: outputData + errorData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard state.finish() else { return }

                    if Task.isCancelled || process.terminationReason == .uncaughtSignal {
                        continuation.resume(throwing: AppError.cancelled)
                    } else {
                        continuation.resume(returning: (process.terminationStatus, output))
                    }
                }

                do {
                    try task.run()
                    state.store(process: task)
                } catch {
                    guard state.finish() else { return }
                    continuation.resume(throwing: AppError.processLaunchFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            state.cancel()
        }
    }
}
