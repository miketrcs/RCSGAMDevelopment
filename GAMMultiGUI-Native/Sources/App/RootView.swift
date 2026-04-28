import AppKit
import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = RunnerViewModel()
    private let fireEngineRed = Color(red: 0.8, green: 0.0, blue: 0.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GAMIT")
                .font(.title2)
                .bold()

            Text("macOS app that uses GAM for bulk admin actions, starting with Vault message deletes and CSV-based user suspension.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Bulk Action")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Bulk Action", selection: $viewModel.action) {
                    ForEach(BulkAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.actionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("CSV")
                    .frame(width: 70, alignment: .leading)
                TextField(viewModel.action.csvPrompt, text: $viewModel.csvPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") {
                    viewModel.browseCSV()
                }
                Button("?") {
                    viewModel.showingCSVHelp = true
                }
            }

            HStack(spacing: 8) {
                Text("GAM Path")
                    .frame(width: 70, alignment: .leading)
                TextField("Optional override", text: $viewModel.gamPathOverride)
                    .textFieldStyle(.roundedBorder)
                Button("Check GAM Version") {
                    viewModel.checkGAMVersion()
                }
                .disabled(viewModel.isRunning)
                Button("Test GAM Setup") {
                    viewModel.testGAMSetup()
                }
                .disabled(viewModel.isRunning)
                Button("GAM Setup Help") {
                    viewModel.showingGAMSetupHelp = true
                }
            }

            if viewModel.modeRequiresGAM && !viewModel.isGAMAvailable {
                Text("GAM is not currently detected. Check and execute modes need a valid GAM install or a GAM_PATH override.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !viewModel.detectedGAMPath.isEmpty {
                Text("Detected GAM: \(viewModel.detectedGAMPath)")
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
                        ForEach(RunnerMode.allCases) { mode in
                            Button {
                                viewModel.mode = mode
                            } label: {
                                Text(mode.title(for: viewModel.action))
                                    .foregroundStyle(mode == .execute ? fireEngineRed : .primary)
                                    .frame(maxWidth: .infinity, minHeight: 34)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(modeButtonFill(for: mode))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(modeButtonStroke(for: mode), lineWidth: 1)
                            )
                        }
                    }
                    .frame(width: 430)

                    if viewModel.showsPasswordChangeToggle {
                        Toggle("Force password change at next sign-in", isOn: $viewModel.forcePasswordChange)
                            .toggleStyle(.checkbox)
                            .padding(.top, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    LabeledTextField(title: "Workers", value: $viewModel.workers, width: 72)
                    LabeledTextField(title: "Retries", value: $viewModel.retries, width: 72)
                    LabeledDecimalField(title: "Backoff", value: $viewModel.backoff, width: 88)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(viewModel.isRunning ? "Running..." : "Run") {
                    viewModel.run()
                }
                .disabled(viewModel.isRunning)
                .keyboardShortcut(.defaultAction)

                Button("Cancel") {
                    viewModel.cancel()
                }
                .disabled(!viewModel.isRunning)

                Button("Clear Output") {
                    viewModel.clearOutput()
                }

                Button("Save Output") {
                    viewModel.saveOutput()
                }

                Spacer()

                if let progress = viewModel.progress {
                    ProgressView(value: progress)
                        .frame(width: 120)
                    Text("\(Int(progress * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }

                Text("Status: \(viewModel.status)")
                    .foregroundStyle(viewModel.isRunning ? .orange : .secondary)
            }

            OutputTextView(
                text: viewModel.output.isEmpty ? "Output will appear here..." : viewModel.output,
                isPlaceholder: viewModel.output.isEmpty,
                autoScroll: viewModel.isRunning && viewModel.mode == .execute
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .padding(18)
        .onAppear {
            viewModel.refreshGAMPath()
        }
        .onChange(of: viewModel.gamPathOverride) { _ in
            viewModel.refreshGAMPath()
        }
        .sheet(isPresented: $viewModel.showingGAMSetupHelp) {
            GAMSetupHelpView()
                .frame(minWidth: 560, idealWidth: 640, maxWidth: 760, minHeight: 360, idealHeight: 440)
        }
        .sheet(isPresented: $viewModel.showingCSVHelp) {
            CSVHelpView(action: viewModel.action)
                .frame(minWidth: 560, idealWidth: 680, maxWidth: 760, minHeight: 320, idealHeight: 360)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showGAMSetupHelp)) { _ in
            viewModel.showingGAMSetupHelp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCSVHelp)) { _ in
            viewModel.showingCSVHelp = true
        }
    }

    private func modeButtonFill(for mode: RunnerMode) -> Color {
        if mode == .execute {
            return viewModel.mode == mode ? fireEngineRed.opacity(0.18) : fireEngineRed.opacity(0.08)
        }

        return viewModel.mode == mode ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor)
    }

    private func modeButtonStroke(for mode: RunnerMode) -> Color {
        if mode == .execute {
            return fireEngineRed
        }

        return viewModel.mode == mode ? Color.accentColor : Color.secondary.opacity(0.22)
    }
}

private struct OutputTextView: NSViewRepresentable {
    let text: String
    let isPlaceholder: Bool
    let autoScroll: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.string = text
        textView.textColor = isPlaceholder ? .secondaryLabelColor : .labelColor

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let textChanged = textView.string != text
        if textChanged {
            textView.string = text
        }
        textView.textColor = isPlaceholder ? .secondaryLabelColor : .labelColor
        if autoScroll && textChanged {
            textView.scrollRangeToVisible(NSRange(location: textView.string.utf16.count, length: 0))
        }
    }
}

private struct LabeledTextField: View {
    let title: String
    @Binding var value: Int
    let width: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            TextField(title, value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }
}

private struct LabeledDecimalField: View {
    let title: String
    @Binding var value: Double
    let width: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
        }
    }
}

private struct GAMSetupHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Install GAM on macOS")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Due to security reasons, the links below are not hotlinks. Please copy and paste them into your browser.")
                        .foregroundStyle(.red)

                    Text("Use the official GAM install docs. After GAM is installed and authorized, this native app can call `gam` directly without the Python wrapper.")

                    Text("1. Open Terminal")
                    Text("2. Run this command:")
                        .font(.headline)

                    HelpCodeBlock(text: "bash <(curl -s -S -L https://git.io/gam-install)")

                    Text("3. Follow the setup prompts to install and authorize GAM.")
                    Text("4. Relaunch this app, or set the GAM Path field to your installed GAM executable.")

                    Text("To update an existing GAM install later, run:")
                        .font(.headline)

                    HelpCodeBlock(text: "bash <(curl -s -S -L https://git.io/gam-install) -l")

                    Text("Copy and paste these URLs into your browser if needed:")
                        .font(.headline)

                    HelpInlineLink(text: "https://github.com/GAM-team/GAM/wiki/Downloads-Installs")
                    HelpInlineLink(text: "https://github.com/GAM-team/GAM")
                    HelpInlineLink(text: "https://github.com/GAM-team/GAM/wiki/How-to-Update-GAM7")

                    Divider()

                    Text("Notes")
                        .font(.headline)

                    Text("`Check GAM Version` verifies that the executable can be launched.")
                    Text("`Test GAM Setup` runs `gam version` and `gam info domain` to validate the local workspace configuration.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .padding(.vertical, 14)

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
    }
}

private struct CSVHelpView: View {
    let action: BulkAction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(action.csvHelpTitle)
                    .font(.title3)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(helpIntro)

                    Text("Recommended workflow:")
                        .font(.headline)

                    ForEach(helpSteps, id: \.self) { step in
                        Text(step)
                    }

                    Text(helpFooter)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .padding(.vertical, 14)

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
    }

    private var helpIntro: String {
        switch action {
        case .deleteVaultMessages:
            return "This file is typically exported from Google Vault."
        case .suspendUsersCSV:
            return "This file can be any UTF-8 CSV that lists the users you want to suspend."
        case .archiveUsersCSV:
            return "This file can be any UTF-8 CSV that lists the users you want to archive."
        case .changePasswordsCSV:
            return "This file can be any UTF-8 CSV that lists the users whose passwords you want to change."
        }
    }

    private var helpSteps: [String] {
        switch action {
        case .deleteVaultMessages:
            return [
                "1. Search in Google Vault for the subject line or other details that match the specific day you need.",
                "2. Once you find the matching emails, export them as MBOX.",
                "3. From the downloaded export files, use the file that ends with `-metadata.csv`.",
                "4. Review the file with Review CSV, Preview Commands, and Check (first 10) before executing deletes."
            ]
        case .suspendUsersCSV:
            return [
                "1. Prepare a CSV with one user identifier column such as `Account`, `User`, `Email`, or `Primary Email`.",
                "2. Review the CSV first so blank or malformed rows are easy to catch.",
                "3. Use Preview Commands to inspect the exact `gam update user ... suspended on` command.",
                "4. Use Check (first 10) to verify the first set of users with `gam info user` before executing suspends."
            ]
        case .archiveUsersCSV:
            return [
                "1. Prepare a CSV with one user identifier column such as `Account`, `User`, `Email`, or `Primary Email`.",
                "2. Review the CSV first so blank or malformed rows are easy to catch.",
                "3. Use Preview Commands to inspect the exact `gam update user ... archived on` command.",
                "4. Use Check (first 10) to verify the first set of users with `gam info user` before executing archives."
            ]
        case .changePasswordsCSV:
            return [
                "1. Prepare a CSV with a user column such as `Account`, `User`, `Email`, or `Primary Email` plus a `Password` column.",
                "2. Review the CSV first so blank users or blank passwords are easy to catch.",
                "3. Use Preview Commands to inspect the exact command shape; the output redacts passwords for safety.",
                "4. Use Check (first 10) to verify the first set of users with `gam info user` before executing password changes."
            ]
        }
    }

    private var helpFooter: String {
        switch action {
        case .deleteVaultMessages:
            return "The app expects the Vault metadata CSV so it can read the `Account` and `Rfc822MessageId` fields correctly."
        case .suspendUsersCSV:
            return "The suspend workflow only requires a user-identifying column. Extra columns are fine and remain visible in Review CSV output."
        case .archiveUsersCSV:
            return "The archive workflow only requires a user-identifying column. Extra columns are fine and remain visible in Review CSV output."
        case .changePasswordsCSV:
            return "The password workflow requires both a user column and a `Password` column. Preview output redacts the password value, but execute still uses the CSV value."
        }
    }
}

private struct HelpCodeBlock: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .foregroundStyle(Color.accentColor)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
    }
}

private struct HelpInlineLink: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .foregroundStyle(Color.accentColor)
    }
}
