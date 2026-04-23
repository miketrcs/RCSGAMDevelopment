import Foundation

struct GAMResultFormatter {
    func formatResult(_ result: GAMResult, action: BulkAction) -> String {
        switch result.status {
        case .success:       return successResultLine(action: action, result: result)
        case .miss:          return missResultLine(action: action, result: result)
        case .dryRunSuccess: return dryRunSuccessResultLine(action: action, result: result)
        case .dryRunMiss:    return dryRunMissResultLine(action: action, result: result)
        case .error:         return errorResultLine(action: action, result: result)
        case .exception:     return exceptionResultLine(action: action, result: result)
        case .reviewValid, .reviewSkip, .preview: return result.output
        }
    }

    func previewLine(for action: BulkAction, task: GAMTask, command: [String], forcePasswordChange: Bool) -> String {
        switch action {
        case .deleteVaultMessages:
            return "[CSV-TEST] user=\(task.user) msgid=\(task.detail) cmd=\(command.joined(separator: " "))"
        case .suspendUsersCSV:
            return "[CSV-TEST] user=\(task.user) cmd=\(command.joined(separator: " "))"
        case .archiveUsersCSV:
            return "[CSV-TEST] user=\(task.user) cmd=\(command.joined(separator: " "))"
        case .changePasswordsCSV:
            var redactedCommand = command
            if let passwordIndex = redactedCommand.firstIndex(of: "password"),
               redactedCommand.indices.contains(passwordIndex + 1) {
                redactedCommand[passwordIndex + 1] = "<redacted>"
            }
            redactedCommand.append(contentsOf: ["changepassword", forcePasswordChange ? "on" : "off"])
            return "[CSV-TEST] user=\(task.user) password=<redacted> cmd=\(redactedCommand.joined(separator: " "))"
        }
    }

    func formatRow(_ fields: [String: String]) -> String {
        let sortedKeys = fields.keys.sorted()
        return sortedKeys.map { key in
            let value = fields[key]?.isEmpty == false ? fields[key]! : "<blank>"
            return "\(key)=\(value)"
        }.joined(separator: " | ")
    }

    private func successResultLine(action: BulkAction, result: GAMResult) -> String {
        switch action {
        case .deleteVaultMessages:
            return "[DELETED] user=\(result.user) msgid=\(result.detail) attempts=\(result.attempts)"
        case .suspendUsersCSV:
            return "[SUSPENDED] user=\(result.user) attempts=\(result.attempts)"
        case .archiveUsersCSV:
            return "[ARCHIVED] user=\(result.user) attempts=\(result.attempts)"
        case .changePasswordsCSV:
            return "[PASSWORDCHANGED] user=\(result.user) attempts=\(result.attempts)"
        }
    }

    private func missResultLine(action: BulkAction, result: GAMResult) -> String {
        switch action {
        case .deleteVaultMessages:
            return "[NOMATCH] user=\(result.user) msgid=\(result.detail) attempts=\(result.attempts)"
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            return "[USERMISS] user=\(result.user) attempts=\(result.attempts)"
        }
    }

    private func dryRunSuccessResultLine(action: BulkAction, result: GAMResult) -> String {
        switch action {
        case .deleteVaultMessages:
            return "[DRYRUNFOUND] user=\(result.user) msgid=\(result.detail) attempts=\(result.attempts)"
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            return "[USEROK] user=\(result.user) attempts=\(result.attempts)"
        }
    }

    private func dryRunMissResultLine(action: BulkAction, result: GAMResult) -> String {
        switch action {
        case .deleteVaultMessages:
            return "[DRYRUNNOMATCH] user=\(result.user) msgid=\(result.detail) attempts=\(result.attempts)"
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            return "[USERMISS] user=\(result.user) attempts=\(result.attempts)"
        }
    }

    private func errorResultLine(action: BulkAction, result: GAMResult) -> String {
        switch action {
        case .deleteVaultMessages:
            return "[ERR] user=\(result.user) msgid=\(result.detail) attempts=\(result.attempts)"
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            return "[ERR] user=\(result.user) attempts=\(result.attempts)"
        }
    }

    private func exceptionResultLine(action: BulkAction, result: GAMResult) -> String {
        switch action {
        case .deleteVaultMessages:
            return "[EXC] user=\(result.user) msgid=\(result.detail) attempts=\(result.attempts) exc=\(result.output)"
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            return "[EXC] user=\(result.user) attempts=\(result.attempts) exc=\(result.output)"
        }
    }
}
