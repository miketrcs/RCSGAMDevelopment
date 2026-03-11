import AppKit
import Foundation
import SwiftUI

@main
struct GAMMultiGUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 620)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class RunnerViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case preview
        case check
        case execute

        var id: String { rawValue }

        var title: String {
            switch self {
            case .preview: return "Preview"
            case .check: return "Check (first 10)"
            case .execute: return "Execute Deletes"
            }
        }
    }

    @Published var scriptPath: String = RunnerViewModel.defaultScriptPath()
    @Published var csvPath: String = ""
    @Published var gamPath: String = ProcessInfo.processInfo.environment["GAM_PATH"] ?? ""

    @Published var mode: Mode = .preview
    @Published var workers: String = "8"
    @Published var retries: String = "3"
    @Published var backoff: String = "0.75"

    @Published var isRunning = false
    @Published var output = ""
    @Published var status = "Idle"

    private var process: Process?

    static func defaultScriptPath() -> String {
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            NSString(string: cwd).appendingPathComponent("../gamgmaildeletebymsgidparallel.py"),
            NSString(string: cwd).appendingPathComponent("gamgmaildeletebymsgidparallel.py"),
            "/Users/mike/RCSGAMDevelopment/gamgmaildeletebymsgidparallel.py"
        ]

        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return NSString(string: path).standardizingPath
        }

        return candidates.last ?? ""
    }

    func appendLine(_ line: String) {
        output += line
        if !line.hasSuffix("\n") {
            output += "\n"
        }
    }

    func browseCSV() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            csvPath = url.path
        }
    }

    func browseScript() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pythonScript, .plainText]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            scriptPath = url.path
        }
    }

    func clearOutput() {
        output = ""
    }

    func run() {
        guard !isRunning else { return }

        let script = NSString(string: scriptPath).expandingTildeInPath
        let csv = NSString(string: csvPath).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: script) else {
            status = "Script path is invalid"
            appendLine("[ERR] Script not found: \(script)")
            return
        }

        guard FileManager.default.fileExists(atPath: csv) else {
            status = "CSV path is invalid"
            appendLine("[ERR] CSV not found: \(csv)")
            return
        }

        guard let workersInt = Int(workers), workersInt >= 1 else {
            status = "Workers must be >= 1"
            appendLine("[ERR] Workers must be >= 1")
            return
        }

        guard let retriesInt = Int(retries), retriesInt >= 0 else {
            status = "Retries must be >= 0"
            appendLine("[ERR] Retries must be >= 0")
            return
        }

        guard let backoffDouble = Double(backoff), backoffDouble > 0 else {
            status = "Backoff must be > 0"
            appendLine("[ERR] Backoff must be > 0")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args = ["python3", script, "-f", csv, "-w", "\(workersInt)", "-r", "\(retriesInt)", "-b", "\(backoffDouble)"]
        switch mode {
        case .check:
            args.append("-c")
        case .execute:
            args.append("-x")
        case .preview:
            break
        }
        task.arguments = args

        var env = ProcessInfo.processInfo.environment
        if !gamPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            env["GAM_PATH"] = NSString(string: gamPath).expandingTildeInPath
        }
        task.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.appendLine(text)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.appendLine(text)
            }
        }

        task.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                self?.isRunning = false
                self?.process = nil
                self?.status = proc.terminationStatus == 0 ? "Completed" : "Failed (\(proc.terminationStatus))"
                self?.appendLine("\n[INFO] Process exited with code \(proc.terminationStatus)")
            }
        }

        do {
            process = task
            isRunning = true
            status = "Running"
            appendLine("[INFO] Launching: /usr/bin/env \(args.joined(separator: " "))")
            try task.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            isRunning = false
            process = nil
            status = "Launch failed"
            appendLine("[ERR] Failed to launch process: \(error.localizedDescription)")
        }
    }

    func cancel() {
        guard let task = process, isRunning else { return }
        task.terminate()
        status = "Cancelling"
    }
}

struct ContentView: View {
    @StateObject private var vm = RunnerViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GAM Multi Script Wrapper")
                .font(.title2).bold()

            HStack(spacing: 8) {
                Text("Script")
                    .frame(width: 70, alignment: .leading)
                TextField("Path to gamgmaildeletebymsgidparallel.py", text: $vm.scriptPath)
                Button("Browse") { vm.browseScript() }
            }

            HStack(spacing: 8) {
                Text("CSV")
                    .frame(width: 70, alignment: .leading)
                TextField("Path to CSV", text: $vm.csvPath)
                Button("Browse") { vm.browseCSV() }
            }

            HStack(spacing: 8) {
                Text("GAM_PATH")
                    .frame(width: 70, alignment: .leading)
                TextField("Optional override", text: $vm.gamPath)
            }

            HStack(spacing: 18) {
                Picker("Mode", selection: $vm.mode) {
                    ForEach(RunnerViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                LabeledTextField(title: "Workers", text: $vm.workers, width: 72)
                LabeledTextField(title: "Retries", text: $vm.retries, width: 72)
                LabeledTextField(title: "Backoff", text: $vm.backoff, width: 88)
            }

            HStack(spacing: 10) {
                Button(vm.isRunning ? "Running..." : "Run") {
                    vm.run()
                }
                .disabled(vm.isRunning)

                Button("Cancel") {
                    vm.cancel()
                }
                .disabled(!vm.isRunning)

                Button("Clear Output") {
                    vm.clearOutput()
                }

                Spacer()
                Text("Status: \(vm.status)")
                    .foregroundStyle(vm.isRunning ? .orange : .secondary)
            }

            ScrollView {
                Text(vm.output.isEmpty ? "Output will appear here..." : vm.output)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .padding(16)
    }
}

private struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    let width: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }
}
