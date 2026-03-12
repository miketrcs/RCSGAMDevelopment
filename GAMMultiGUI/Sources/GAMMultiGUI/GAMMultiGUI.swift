import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
        case review
        case preview
        case check
        case execute

        var id: String { rawValue }

        var title: String {
            switch self {
            case .review: return "Review CSV"
            case .preview: return "Preview Commands"
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
    @Published var showingGAMSetupHelp = false
    @Published var showingCSVHelp = false
    @Published var detectedGAMPath = ""

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

    var modeRequiresGAM: Bool {
        mode == .check || mode == .execute
    }

    var isGAMAvailable: Bool {
        !resolvedGAMPath().isEmpty
    }

    func refreshGAMAvailability() {
        detectedGAMPath = resolvedGAMPath()
    }

    private func presentOpenPanel(
        configure: (NSOpenPanel) -> Void,
        onSelect: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        configure(panel)

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                onSelect(url)
            }
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            onSelect(url)
        }
    }

    private func presentSavePanel(
        suggestedName: String,
        onSelect: @escaping (URL) -> Void
    ) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedName

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                onSelect(url)
            }
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            onSelect(url)
        }
    }

    private func resolvedGAMPath() -> String {
        let override = NSString(string: gamPath).expandingTildeInPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty, FileManager.default.isExecutableFile(atPath: override) {
            return override
        }

        let candidates = [
            NSString(string: ProcessInfo.processInfo.environment["GAM_PATH"] ?? "").expandingTildeInPath,
            NSString(string: NSHomeDirectory()).appendingPathComponent("bin/gam7/gam"),
            "/opt/homebrew/bin/gam",
            "/usr/local/bin/gam"
        ]

        for candidate in candidates {
            if !candidate.isEmpty, FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
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
            guard task.terminationStatus == 0 else { return "" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return FileManager.default.isExecutableFile(atPath: path) ? path : ""
        } catch {
            return ""
        }
    }

    func saveOutput() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suggestedName = "gam-output-\(formatter.string(from: Date())).txt"

        presentSavePanel(suggestedName: suggestedName) { [self] url in
            do {
                try self.output.write(to: url, atomically: true, encoding: .utf8)
                self.status = "Output saved"
                self.appendLine("[INFO] Saved output to \(url.path)")
            } catch {
                self.status = "Save failed"
                self.appendLine("[ERR] Failed to save output: \(error.localizedDescription)")
            }
        }
    }

    func checkGAMVersion() {
        refreshGAMAvailability()

        guard !detectedGAMPath.isEmpty else {
            status = "GAM not found"
            appendLine("[ERR] GAM was not found on this Mac.")
            appendLine("[INFO] Open 'GAM Setup Help' for install and update steps.")
            showingGAMSetupHelp = true
            return
        }

        status = "Checking GAM version"
        appendLine("[INFO] Checking GAM version at \(detectedGAMPath)")

        let gamExecutable = detectedGAMPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            task.executableURL = URL(fileURLWithPath: gamExecutable)
            task.arguments = ["version"]
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe

            do {
                try task.run()
                task.waitUntilExit()
                let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: outputData + errorData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                Task { @MainActor in
                    guard let self else { return }
                    if output.isEmpty {
                        self.appendLine("[INFO] GAM ran from \(gamExecutable) but did not return version text.")
                    } else {
                        self.appendLine(output)
                    }
                    self.status = task.terminationStatus == 0 ? "GAM version checked" : "GAM version check failed"
                }
            } catch {
                Task { @MainActor in
                    guard let self else { return }
                    self.status = "GAM version check failed"
                    self.appendLine("[ERR] Failed to check GAM version: \(error.localizedDescription)")
                }
            }
        }
    }

    func testGAMSetup() {
        refreshGAMAvailability()

        guard !detectedGAMPath.isEmpty else {
            status = "GAM not found"
            appendLine("[ERR] GAM was not found on this Mac.")
            appendLine("[INFO] Open 'GAM Setup Help' for install and update steps.")
            showingGAMSetupHelp = true
            return
        }

        status = "Testing GAM setup"
        appendLine("[INFO] Running GAM workspace diagnostics using \(detectedGAMPath)")

        let gamExecutable = detectedGAMPath
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let commands: [([String], String)] = [
                (["version"], "[INFO] GAM version"),
                (["info", "domain"], "[INFO] GAM domain info")
            ]

            for (arguments, header) in commands {
                let task = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                task.executableURL = URL(fileURLWithPath: gamExecutable)
                task.arguments = arguments
                task.standardOutput = stdoutPipe
                task.standardError = stderrPipe

                do {
                    try task.run()
                    task.waitUntilExit()
                    let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(decoding: outputData + errorData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let exitCode = task.terminationStatus

                    Task { @MainActor [weak self, header, output, exitCode] in
                        guard let self else { return }
                        self.appendLine(header)
                        if output.isEmpty {
                            self.appendLine("[INFO] No output returned")
                        } else {
                            self.appendLine(output)
                        }
                        self.appendLine("[INFO] Exit code: \(exitCode)")
                    }
                } catch {
                    let errorMessage = error.localizedDescription
                    let commandText = arguments.joined(separator: " ")
                    Task { @MainActor [weak self, errorMessage, commandText] in
                        guard let self else { return }
                        self.status = "GAM setup test failed"
                        self.appendLine("[ERR] Failed to run \(commandText): \(errorMessage)")
                    }
                    return
                }
            }

            Task { @MainActor in
                guard let self else { return }
                self.status = "GAM setup tested"
            }
        }
    }

    func browseCSV() {
        presentOpenPanel { panel in
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.commaSeparatedText, .plainText]
            panel.allowsMultipleSelection = false
        } onSelect: { [self] url in
            self.csvPath = url.path
        }
    }

    func browseScript() {
        presentOpenPanel { panel in
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.pythonScript, .plainText]
            panel.allowsMultipleSelection = false
        } onSelect: { [self] url in
            self.scriptPath = url.path
        }
    }

    func clearOutput() {
        output = ""
    }

    func run() {
        guard !isRunning else { return }

        clearOutput()
        refreshGAMAvailability()

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

        if modeRequiresGAM && !isGAMAvailable {
            status = "GAM not found"
            appendLine("[ERR] GAM was not found on this Mac.")
            appendLine("[INFO] Open 'GAM Setup Help' for official macOS install steps.")
            showingGAMSetupHelp = true
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args = ["python3", script, "-f", csv, "-w", "\(workersInt)", "-r", "\(retriesInt)", "-b", "\(backoffDouble)"]
        switch mode {
        case .review:
            args.append("--review")
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
                Button("?") {
                    vm.showingCSVHelp = true
                }
            }

            HStack(spacing: 8) {
                Text("GAM_PATH")
                    .frame(width: 70, alignment: .leading)
                TextField("Optional override", text: $vm.gamPath)
                Button("GAM Setup Help") {
                    vm.showingGAMSetupHelp = true
                }
                Button("Check GAM Version") {
                    vm.checkGAMVersion()
                }
            }

            if vm.modeRequiresGAM && !vm.isGAMAvailable {
                Text("GAM is not currently detected. Check mode and Execute Deletes need a valid GAM install or a GAM_PATH override.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !vm.detectedGAMPath.isEmpty {
                Text("Detected GAM: \(vm.detectedGAMPath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 150), spacing: 8),
                            GridItem(.flexible(minimum: 150), spacing: 8)
                        ],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(RunnerViewModel.Mode.allCases) { mode in
                            Button(mode.title) {
                                vm.mode = mode
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(vm.mode == mode ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(vm.mode == mode ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: 1)
                            )
                        }
                    }
                    .frame(width: 430)
                }

                VStack(alignment: .leading, spacing: 10) {
                    LabeledTextField(title: "Workers", text: $vm.workers, width: 72)
                    LabeledTextField(title: "Retries", text: $vm.retries, width: 72)
                    LabeledTextField(title: "Backoff", text: $vm.backoff, width: 88)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(vm.isRunning ? "Running..." : "Run") {
                    vm.run()
                }
                .disabled(vm.isRunning)

                Button("Test GAM Setup") {
                    vm.testGAMSetup()
                }
                .disabled(vm.isRunning)

                Button("Cancel") {
                    vm.cancel()
                }
                .disabled(!vm.isRunning)

                Button("Clear Output") {
                    vm.clearOutput()
                }

                Button("Save Output") {
                    vm.saveOutput()
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
        .onAppear {
            vm.refreshGAMAvailability()
        }
        .onChange(of: vm.gamPath) { _ in
            vm.refreshGAMAvailability()
        }
        .sheet(isPresented: $vm.showingGAMSetupHelp) {
            GAMSetupHelpView()
                .frame(minWidth: 640, minHeight: 440)
        }
        .sheet(isPresented: $vm.showingCSVHelp) {
            CSVHelpView()
                .frame(minWidth: 680, minHeight: 360)
        }
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

private struct GAMSetupHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Install GAM on macOS")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }

            Text("Use the official GAM install docs. The quickest supported path is the installer script from the GAM downloads page.")

            Text("1. Open Terminal")
            Text("2. Run this command:")
                .font(.headline)

            Text(verbatim: "bash <(curl -s -S -L https://git.io/gam-install)")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(Color.accentColor)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )

            Text("3. Follow the setup prompts to install and authorize GAM.")
            Text("4. Relaunch this app, or set the GAM_PATH field to your installed GAM executable.")

            Text("To update an existing GAM install later, run:")
                .font(.headline)

            Text(verbatim: "bash <(curl -s -S -L https://git.io/gam-install) -l")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(Color.accentColor)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )

            Text("Copy/paste these URLs into your browser if needed:")
                .font(.headline)

            Text(verbatim: "https://github.com/GAM-team/GAM/wiki/Downloads-Installs")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(Color.accentColor)

            Text(verbatim: "https://github.com/GAM-team/GAM")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(Color.accentColor)

            Text(verbatim: "https://github.com/GAM-team/GAM/wiki/How-to-Update-GAM7")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(Color.accentColor)

            Spacer()
        }
        .padding(20)
    }
}

private struct CSVHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CSV File Guidance")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }

            Text("This file is exported from Google Vault.")

            Text("Recommended workflow:")
                .font(.headline)

            Text("1. Search in Google Vault for the subject line or other information that matches the specific day you need.")
            Text("2. Once you find the matching emails, export them as MBOX.")
            Text("3. From the downloaded export files, use the file that ends with `-metadata.csv`.")
            Text("4. Please review the file with Review CSV, Preview Commands, and Check (First 10) before executing deletes.")

            Text("The app expects the Vault metadata CSV so it can read the `Account` and `Rfc822MessageId` fields correctly.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(20)
    }
}
