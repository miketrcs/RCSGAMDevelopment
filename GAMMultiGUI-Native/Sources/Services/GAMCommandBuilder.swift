import Foundation

struct GAMCommandBuilder {
    func command(for task: GAMTask, action: BulkAction, mode: RunnerMode, gamPath: String) -> [String] {
        switch action {
        case .deleteVaultMessages:
            var command = [
                gamPath,
                "user",
                task.user,
                "delete",
                "messages",
                "query",
                "rfc822msgid:\(task.detail)"
            ]

            if mode == .execute {
                command.append("doit")
            }

            return command
        case .suspendUsersCSV:
            if mode == .check {
                return [gamPath, "info", "user", task.user]
            }

            return [gamPath, "update", "user", task.user, "suspended", "on"]
        case .archiveUsersCSV:
            if mode == .check {
                return [gamPath, "info", "user", task.user]
            }

            return [gamPath, "update", "user", task.user, "archived", "on"]
        case .changePasswordsCSV:
            if mode == .check {
                return [gamPath, "info", "user", task.user]
            }

            return [gamPath, "update", "user", task.user, "password", task.detail]
        }
    }
}
