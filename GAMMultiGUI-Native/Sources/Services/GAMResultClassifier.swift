import Foundation

struct GAMResultClassifier {
    func hasRateLimitError(_ output: String) -> Bool {
        let markers = [
            "rate limit", "ratelimit", "quota", "429",
            "userratelimitexceeded", "toomanyrequests",
            "backend error", "temporarily unavailable"
        ]
        return markers.contains { output.contains($0) }
    }

    func isMissOutput(_ output: String, action: BulkAction, mode: RunnerMode) -> Bool {
        switch action {
        case .deleteVaultMessages:
            let markers = [
                "0 messages", "got 0 messages", "no messages",
                "no threads", "no messages matched",
                "not deleted: no messages matched"
            ]
            return markers.contains { output.contains($0) }
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            guard mode == .check else { return false }
            let markers = [
                "does not exist", "not found", "unknown user", "resource not found"
            ]
            return markers.contains { output.contains($0) }
        }
    }

    func isSuccessfulResult(output: String, exitCode: Int32, action: BulkAction, mode: RunnerMode) -> Bool {
        switch action {
        case .deleteVaultMessages:
            return exitCode == 0 || (mode == .check && isDeleteCheckFoundOutput(output))
        case .suspendUsersCSV, .archiveUsersCSV, .changePasswordsCSV:
            return exitCode == 0
        }
    }

    private func isDeleteCheckFoundOutput(_ output: String) -> Bool {
        let markers = [
            "would delete", "would be deleted", "not deleted:",
            "messages matched", "got 1 message", "got 2 messages",
            "got 3 messages", "got 4 messages", "got 5 messages",
            "got 6 messages", "got 7 messages", "got 8 messages",
            "got 9 messages"
        ]
        return markers.contains { output.contains($0) }
    }
}
