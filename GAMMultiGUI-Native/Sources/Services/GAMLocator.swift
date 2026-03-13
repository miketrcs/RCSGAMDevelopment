import Foundation

struct GAMLocator {
    func resolvePath(override: String) -> String? {
        let overridePath = NSString(string: override).expandingTildeInPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !overridePath.isEmpty, FileManager.default.isExecutableFile(atPath: overridePath) {
            return overridePath
        }

        let candidates = [
            NSString(string: NSHomeDirectory()).appendingPathComponent("bin/gam7/gam"),
            "/opt/homebrew/bin/gam",
            "/usr/local/bin/gam"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "gam"]
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return FileManager.default.isExecutableFile(atPath: path) ? path : nil
        } catch {
            return nil
        }
    }
}
