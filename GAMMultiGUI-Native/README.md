# GAMIT Native

This folder contains `GAMIT Native`, the native-only macOS app that uses GAM for bulk admin workflows without relying on the Python runner scripts.

## Version

- Current version: `1.5.6`

The original `GAMMultiGUI` app remains in `/Users/mike/All Development/RCSGAMDevelopment/GAMMultiGUI`. This folder is the native app workspace.

## Changelog

### v1.5.6
- Execute mode now shows a live progress bar and percentage (0–100%) in the status row as tasks complete
- Log output auto-scrolls to the bottom during Execute mode runs

### v1.5.5
- Performance: batch output flushes reduce string copy overhead during large runs
- Performance: 2 MB display cap on output pane; Save Output always writes the complete log
- Code quality: GAMResultClassifier and GAMResultFormatter extracted from NativeDeleteEngine for cleaner separation of concerns
- Fix: CancellationError now correctly propagates through retry logic — cancelling mid-retry no longer shows as an exception in output
- Fix: CSV loader redundant UTF-8 fallback removed; misleading inout parameter cleaned up
- Adds archive users and change passwords CSV workflows to the bulk action picker

## Goal

Replace this current handoff:

- SwiftUI app
- `Process` launches `python3`
- Python parses CSV, manages modes, concurrency, retries, and output
- Python launches `gam`

With this:

- SwiftUI app
- Swift services parse CSV, validate rows, manage modes, concurrency, retries, and output
- Swift launches `gam` directly with `Process`

## Scope

Included:

- Vault message delete workflow from CSV
- CSV-based suspend users workflow
- CSV-based archive users workflow
- CSV-based password change workflow
- CSV review
- preview mode
- check mode
- execute mode
- configurable workers, retries, and backoff
- direct `gam` invocation
- streaming logs into the UI
- cancel support
- save output

Planned next additions:

- move users from one OU to another
- mass actions by OU or group (not just CSV)

Still not included:

- replacing `gam`
- direct Google API integration

## Local Signed Build

This workspace includes a repeatable local app/installer release script:

```bash
export SIGN_IDENTITY="Developer ID Application: Example Org (TEAMID)"
export PKG_SIGN_IDENTITY="Developer ID Installer: Example Org (TEAMID)"
export NOTARY_PROFILE=YOUR_NOTARY_PROFILE
./scripts/build_signed_app.sh
```

Default output:

- `dist/GAMIT.app`: universal macOS app bundle
- `dist/GAMIT-1.5.6.pkg`: macOS installer package for `/Applications`
- `dist/GAMIT-1.5.6.pkg.sha256`: SHA-256 checksum file for the installer package

Default app metadata:

- bundle identifier: `com.miketrcs.gammultigui.native`
- app bundle name: `GAMIT.app`

Override examples:

```bash
APP_NAME=GAMMultiGUI \
BUNDLE_ID=com.miketrcs.gammultigui \
SIGN_IDENTITY="Developer ID Application: Example Org (TEAMID)" \
PKG_SIGN_IDENTITY="Developer ID Installer: Example Org (TEAMID)" \
NOTARY_PROFILE=YOUR_NOTARY_PROFILE \
./scripts/build_signed_app.sh
```

Set `NOTARIZE_PKG=0` if you want to skip notarization for a local-only build.

## Structure

```text
GAMMultiGUI-Native/
  Package.swift
  README.md
  VERSION
  Sources/
    App/
      GAMMultiGUIApp.swift
      RootView.swift
    Features/
      Runner/
        RunnerViewModel.swift
    Domain/
      BulkAction.swift
      RunnerMode.swift
      CSVRow.swift
      GAMTask.swift
      GAMResult.swift
      RunnerConfig.swift
    Services/
      AppError.swift
      CSVLoader.swift
      GAMLocator.swift
      GAMCommandBuilder.swift
      GAMProcessRunner.swift
      GAMResultClassifier.swift
      GAMResultFormatter.swift
      NativeDeleteEngine.swift
      OutputStore.swift
```

## Architecture

### `RunnerViewModel`

Owns UI state and coordinates the run lifecycle.

Responsibilities:

- hold selected CSV path
- hold optional `GAM_PATH` override
- hold mode, workers, retries, and backoff
- validate inputs before launch
- start and cancel runs
- expose status and streamed output to SwiftUI
- batch output flushes for performance
- enforce a 2 MB display cap with full output preserved for Save Output

### `BulkAction`

Represents the operator-selected workflow.

Current actions:

- delete Vault messages from CSV
- suspend users from CSV
- archive users from CSV
- change passwords from CSV

### `CSVLoader`

Reads the CSV file and converts rows into typed domain records.

Responsibilities:

- read UTF-8 and UTF-8 with BOM
- map workflow-specific columns such as `Account`, `Rfc822MessageId`, `User`, `Primary Email`, and `Password`
- normalize message IDs and account values
- produce review-friendly validation results

### `NativeDeleteEngine`

The native bulk-action execution engine.

Responsibilities:

- accept validated tasks and runtime config
- branch by mode: review, preview, check, execute
- limit check mode to the first 10 valid rows
- run a bounded number of concurrent tasks
- apply retry and exponential backoff for transient failures
- emit structured progress events as each task completes
- correctly propagate cancellation through retry sleeps and task checks

### `GAMResultClassifier`

Pure classification logic with no side effects.

Responsibilities:

- determine whether GAM output indicates a miss, rate limit error, or successful result
- keep output classification isolated from execution and formatting

### `GAMResultFormatter`

Pure formatting logic with no side effects.

Responsibilities:

- format `GAMResult` values into display strings for each action type
- format preview command lines
- format CSV row descriptions for review output

### `GAMProcessRunner`

Small wrapper around `Process`.

Responsibilities:

- launch `gam`
- capture stdout and stderr
- return exit code and combined output
- support cancellation via `withTaskCancellationHandler` — process is terminated immediately on cancel

### `GAMCommandBuilder`

Builds the exact commands for the selected workflow.

Examples:

- preview/check: `gam user <acct> delete messages query rfc822msgid:<id>`
- execute: same command plus `doit`
- suspend preview/execute: `gam update user <acct> suspended on`
- suspend check: `gam info user <acct>`

### `GAMLocator`

Finds the `gam` executable.

Responsibilities:

- honor explicit override first
- check common install paths
- optionally fall back to `which gam`

### `OutputStore`

Observable output accumulator available for future UI extensions.

## Data Flow

1. User picks CSV and mode in `RootView`.
2. `RunnerViewModel` validates config and resolves `gam`.
3. `CSVLoader` parses rows into `[CSVRow]`.
4. `NativeDeleteEngine` converts valid rows into `[GAMTask]`.
5. For preview/check/execute, `GAMCommandBuilder` builds commands.
6. `GAMProcessRunner` executes `gam` with bounded concurrency.
7. `GAMResultClassifier` classifies each result.
8. `GAMResultFormatter` formats each result into a display string.
9. `RunnerViewModel` batches and streams output into the UI.
