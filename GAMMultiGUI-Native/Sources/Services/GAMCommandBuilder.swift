import Foundation

struct GAMCommandBuilder {
    func command(for task: GAMTask, mode: RunnerMode, gamPath: String) -> [String] {
        var command = [
            gamPath,
            "user",
            task.user,
            "delete",
            "messages",
            "query",
            "rfc822msgid:\(task.messageID)"
        ]

        if mode == .execute {
            command.append("doit")
        }

        return command
    }
}
