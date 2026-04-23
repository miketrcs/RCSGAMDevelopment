import Foundation
import AppKit

@MainActor
final class RunnerViewModel: ObservableObject {
    @Published var action: BulkAction = .deleteVaultMessages
    @Published var csvPath = ""
    @Published var gamPathOverride = ""
    @Published var mode: RunnerMode = .preview
    @Published var workers = 8
    @Published var retries = 3
    @Published var backoff = 0.75
    @Published var forcePasswordChange = true
    @Published var status = "Ready"
    @Published var output = ""
    @Published var isRunning = false
    @Published var detectedGAMPath = ""
    @Published var showingGAMSetupHelp = false
    @Published var showingCSVHelp = false

    private let engine = NativeDeleteEngine()
    private let gamLocator = GAMLocator()
    private var currentTask: Task<Void, Never>?
    private var pendingLines: [String] = []
    private var allLines: [String] = []
    private var flushScheduled = false
    private static let maxDisplayCharacters = 2_000_000

    let architectureSummary = """
    UI
    - RootView
    - RunnerViewModel

    Core services
    - CSVLoader
    - GAMLocator
    - GAMCommandBuilder
    - GAMProcessRunner
    - NativeDeleteEngine
    - OutputStore

    Planned execution flow
    1. Validate config.
    2. Resolve GAM path.
    3. Select the requested bulk action.
    4. Load and normalize CSV rows.
    5. Convert rows into typed tasks.
    6. Execute bounded concurrent GAM processes.
    7. Classify results and stream output back to the UI.
    """

    var modeRequiresGAM: Bool {
        mode == .check || mode == .execute
    }

    var isGAMAvailable: Bool {
        !detectedGAMPath.isEmpty
    }

    var actionDescription: String {
        action.subtitle
    }

    var showsPasswordChangeToggle: Bool {
        action == .changePasswordsCSV
    }

    func browseCSV() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window) { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                self?.csvPath = url.path
            }
            return
        }

        if panel.runModal() == .OK, let url = panel.url {
            csvPath = url.path
        }
    }

    func refreshGAMPath() {
        detectedGAMPath = gamLocator.resolvePath(override: gamPathOverride) ?? ""
    }

    func run() {
        guard !isRunning else { return }

        let path = NSString(string: csvPath).expandingTildeInPath
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "CSV path is required"
            appendOutput("[ERR] Choose a CSV file first.")
            return
        }

        let config = RunnerConfig(
            csvPath: path,
            gamPathOverride: gamPathOverride,
            action: action,
            mode: mode,
            workers: workers,
            retries: retries,
            backoffSeconds: backoff,
            forcePasswordChange: forcePasswordChange
        )

        isRunning = true
        output = ""
        allLines = []
        refreshGAMPath()
        status = "Running \(mode.title(for: action))"
        appendOutput("[INFO] Action: \(action.title)")
        appendOutput("[INFO] Starting \(mode.title(for: action).lowercased())")
        appendOutput("[INFO] CSV: \(path)")
        if !detectedGAMPath.isEmpty {
            appendOutput("[INFO] GAM: \(detectedGAMPath)")
        }

        let engine = self.engine
        currentTask = Task.detached(priority: .userInitiated) {
            do {
                try await engine.run(config: config) { line in
                    await MainActor.run {
                        self.appendOutput(line)
                    }
                }
                await MainActor.run {
                    self.flushPendingOutput()
                    self.status = Task.isCancelled ? "Cancelled" : "Completed"
                    self.isRunning = false
                    self.currentTask = nil
                }
            } catch AppError.cancelled {
                await MainActor.run {
                    self.flushPendingOutput()
                    self.appendOutput("[INFO] Operation cancelled.")
                    self.status = "Cancelled"
                    self.isRunning = false
                    self.currentTask = nil
                }
            } catch {
                await MainActor.run {
                    self.flushPendingOutput()
                    self.appendOutput("[ERR] \(error.localizedDescription)")
                    self.status = "Failed"
                    self.isRunning = false
                    self.currentTask = nil
                }
            }
        }
    }

    func checkGAMVersion() {
        runDiagnostic(initialStatus: "Checking GAM version") {
            try await self.engine.checkGAMVersion(override: self.gamPathOverride)
        }
    }

    func testGAMSetup() {
        runDiagnostic(initialStatus: "Testing GAM setup") {
            try await self.engine.testGAMSetup(override: self.gamPathOverride)
        }
    }

    func clearOutput() {
        output = ""
        allLines = []
        status = "Ready"
    }

    func cancel() {
        guard isRunning else { return }
        status = "Cancelling"
        appendOutput("[INFO] Cancelling current operation...")
        currentTask?.cancel()
    }

    func saveOutput() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "gam-output.txt"

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window) { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                self?.writeOutput(to: url)
            }
            return
        }

        if panel.runModal() == .OK, let url = panel.url {
            writeOutput(to: url)
        }
    }

    private func writeOutput(to url: URL) {
        do {
            try allLines.joined().write(to: url, atomically: true, encoding: .utf8)
            status = "Output saved"
            appendOutput("[INFO] Saved output to \(url.path)")
        } catch {
            status = "Save failed"
            appendOutput("[ERR] Failed to save output: \(error.localizedDescription)")
        }
    }

    private func appendOutput(_ text: String) {
        let line = text.hasSuffix("\n") ? text : text + "\n"
        allLines.append(line)
        pendingLines.append(line)
        guard !flushScheduled else { return }
        flushScheduled = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            self?.flushPendingOutput()
        }
    }

    private func flushPendingOutput() {
        guard !pendingLines.isEmpty else {
            flushScheduled = false
            return
        }
        let joined = pendingLines.joined()
        pendingLines.removeAll(keepingCapacity: true)
        flushScheduled = false

        guard output.count < Self.maxDisplayCharacters else { return }
        let available = Self.maxDisplayCharacters - output.count
        if joined.count <= available {
            output += joined
        } else {
            output += String(joined.prefix(available))
            output += "\n[Display limit reached — use Save Output for the complete log.]\n"
        }
    }

    private func runDiagnostic(
        initialStatus: String,
        operation: @escaping @Sendable () async throws -> [String]
    ) {
        guard !isRunning else { return }

        isRunning = true
        refreshGAMPath()
        status = initialStatus
        appendOutput("[INFO] \(initialStatus)")
        if !detectedGAMPath.isEmpty {
            appendOutput("[INFO] GAM: \(detectedGAMPath)")
        }

        currentTask = Task.detached(priority: .userInitiated) {
            do {
                let lines = try await operation()
                await MainActor.run {
                    for line in lines {
                        self.appendOutput(line)
                    }
                    self.flushPendingOutput()
                    self.status = Task.isCancelled ? "Cancelled" : "Completed"
                    self.isRunning = false
                    self.currentTask = nil
                    self.refreshGAMPath()
                }
            } catch AppError.cancelled {
                await MainActor.run {
                    self.flushPendingOutput()
                    self.appendOutput("[INFO] Operation cancelled.")
                    self.status = "Cancelled"
                    self.isRunning = false
                    self.currentTask = nil
                    self.refreshGAMPath()
                }
            } catch {
                await MainActor.run {
                    self.flushPendingOutput()
                    self.appendOutput("[ERR] \(error.localizedDescription)")
                    self.status = "Failed"
                    self.isRunning = false
                    self.currentTask = nil
                    self.refreshGAMPath()
                }
            }
        }
    }
}
