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
- `GAM Setup Help` provides macOS install guidance and official GAM links for users who have not installed GAM yet.
- `Check GAM Version` runs a local GAM version check and appends the result to the output pane.

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
