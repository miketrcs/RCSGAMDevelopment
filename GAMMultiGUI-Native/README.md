# GAMMultiGUI Native

This folder contains the native-only macOS app that keeps the existing `gam` dependency while removing the Python runner scripts from the app workflow.

## Version

- Current version: `1.5`

The original app remains in `/Users/mike/RCSGAMDevelopment/GAMMultiGUI`. This folder is the native app workspace.

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

- CSV review
- preview mode
- check mode
- execute mode
- configurable workers, retries, and backoff
- direct `gam` invocation
- streaming logs into the UI
- cancel support
- save output

Not included:

- replacing `gam`
- direct Google API integration

## Local Signed Build

This workspace includes a repeatable local app/installer release script:

```bash
./scripts/build_signed_app.sh
```

Default output:

- `dist/GAMMultiGUI-Native.app`: universal macOS app bundle signed with the local Developer ID application certificate
- `dist/GAMMultiGUI-Native-1.5.pkg`: signed, notarized, stapled macOS installer package for `/Applications`
- `dist/GAMMultiGUI-Native-1.5.pkg.sha256`: SHA-256 checksum file for the installer package

Default signing metadata:

- bundle identifier: `com.miketrcs.gammultigui.native`
- app bundle name: `GAMMultiGUI-Native.app`
- installer signing identity: `Developer ID Installer: Rutherford County Schools (S6PHL8CDV2)`
- notarization keychain profile: `ACNOTARY`

Override examples:

```bash
APP_NAME=GAMMultiGUI \
BUNDLE_ID=com.miketrcs.gammultigui \
SIGN_IDENTITY="Developer ID Application: Rutherford County Schools (S6PHL8CDV2)" \
PKG_SIGN_IDENTITY="Developer ID Installer: Rutherford County Schools (S6PHL8CDV2)" \
NOTARY_PROFILE=ACNOTARY \
./scripts/build_signed_app.sh
```

## Proposed Structure

```text
GAMMultiGUI-Native/
  Package.swift
  README.md
  Sources/
    App/
      GAMMultiGUIApp.swift
      RootView.swift
    Features/
      Runner/
        RunnerViewModel.swift
    Domain/
      RunnerMode.swift
      CSVRow.swift
      GAMTask.swift
      GAMResult.swift
      RunnerConfig.swift
    Services/
      CSVLoader.swift
      GAMLocator.swift
      GAMCommandBuilder.swift
      GAMProcessRunner.swift
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

### `CSVLoader`

Reads the CSV file and converts rows into typed domain records.

Responsibilities:

- read UTF-8 and UTF-8 with BOM
- map `Account` and `Rfc822MessageId`
- normalize message IDs and account values
- produce review-friendly validation results

### `NativeDeleteEngine`

The native replacement for `gamgmaildeletebymsgidparallel.py`.

Responsibilities:

- accept validated tasks and runtime config
- branch by mode: review, preview, check, execute
- limit check mode to the first 10 valid rows
- run a bounded number of concurrent tasks
- apply retry and exponential backoff for transient failures
- emit structured progress events as each task completes

Implementation direction:

- use Swift concurrency with a bounded task queue
- keep output event-based instead of printing raw strings first

### `GAMProcessRunner`

Small wrapper around `Process`.

Responsibilities:

- launch `gam`
- capture stdout and stderr
- return exit code and combined output
- support cancellation

This keeps shell/process code isolated from business logic.

### `GAMCommandBuilder`

Builds the exact commands now assembled in Python.

Examples:

- preview/check: `gam user <acct> delete messages query rfc822msgid:<id>`
- execute: same command plus `doit`

### `GAMLocator`

Native version of the existing detection logic.

Responsibilities:

- honor explicit override first
- check common install paths
- optionally fall back to `which gam`

### `OutputStore`

Single place that receives structured events and formats them for the output pane.

Responsibilities:

- append log lines on the main actor
- preserve current status summary style
- make it easy to later support richer UI tables without losing plain-text output

## Data Flow

1. User picks CSV and mode in `RootView`.
2. `RunnerViewModel` validates config and resolves `gam`.
3. `CSVLoader` parses rows into `[CSVRow]`.
4. `NativeDeleteEngine` converts valid rows into `[GAMTask]`.
5. For preview/check/execute, `GAMCommandBuilder` builds commands.
6. `GAMProcessRunner` executes `gam` with bounded concurrency.
7. Engine classifies results into `GAMResult`.
8. `OutputStore` formats events into the visible log.

## Migration Plan

### Phase 1

Port review and preview mode only.

Why first:

- no destructive behavior
- no `gam` dependency required for preview
- validates CSV parsing and log formatting

### Phase 2

Port `gam` lookup, version check, and test setup actions.

### Phase 3

Port check mode with first-10 behavior and output classification.

### Phase 4

Port execute mode, retries, backoff, and cancellation.

### Phase 5

Match the current UX closely enough to swap the production app over.

## Risk Notes

- The main technical risk is matching the Python output classification logic closely enough that operators trust the new app.
- Cancellation will need careful handling because `Process` cancellation and worker coordination can drift if we do not centralize ownership.
- Concurrency should be bounded explicitly; a naive `TaskGroup` could overrun GAM or trigger avoidable rate limiting.

## Recommended Next Step

Continue validating native behavior against the original app until you are comfortable swapping this workspace into the main product path.
