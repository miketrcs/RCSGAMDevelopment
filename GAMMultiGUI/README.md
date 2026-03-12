# GAMMultiGUI

macOS SwiftUI wrapper for `gamgmaildeletebymsgidparallel.py`.

## Version
- Current version: `1.4.0`
- Release date: `2026-03-12`

## Behavior
- `Run` clears the output area before each launch so every execution starts with a fresh log.
- `Clear Output` remains available as a manual reset button.
- `Save Output` writes the current output pane to a plain-text file.
- `Cancel` terminates the running process.
- Modes are `Review CSV`, `Preview Commands`, `Check (first 10)`, and `Execute Deletes`.
- `Test GAM Setup` runs local GAM diagnostics, including version and `gam info domain`.
- `GAM Setup Help` provides macOS install guidance, Python download guidance, support/contact details, and copy/paste-only URLs.
- `Check GAM Version` runs a local GAM version check and appends the result to the output pane.
- The packaged app bundle includes `gamgmaildeletebymsgid.py` and `gamgmaildeletebymsgidparallel.py` in `Contents/Resources`, and the GUI prefers the bundled parallel script when available.

## Build
The package builds a single executable target:
- `GAMMultiGUI`

Use the Xcode toolchain when building locally:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift build -c release --product GAMMultiGUI --arch arm64 --arch x86_64
```

The packaged app bundle lives at:
- `dist/GAMMultiGUI.app`

## Distribution
Packaged deliverables:
- `dist/GAMMultiGUI.app`: signed macOS app bundle
- `dist/GAMMultiGUI-1.4.0.pkg`: signed, notarized, stapled installer package for `/Applications`

Notes:
- the app bundle includes `gamgmaildeletebymsgid.py` and `gamgmaildeletebymsgidparallel.py`
- users still need Python installed on macOS
- check/execute features still require a working GAM install and authorization
