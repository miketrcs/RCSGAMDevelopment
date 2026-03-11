# GAMMultiGUI

macOS SwiftUI wrapper for `gamgmaildeletebymsgidparallel.py`.

## Version
- Current version: `1.1.0`
- Release date: `2026-03-11`

## Behavior
- `Run` clears the output area before each launch so every execution starts with a fresh log.
- `Clear Output` remains available as a manual reset button.
- `Cancel` terminates the running process.

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
