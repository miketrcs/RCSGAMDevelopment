# RCSGAMDevelopment

Delete Gmail messages by `Rfc822MessageId` from a CSV export using GAM.

Developer: `miketrcs`

## License And Risk
- License: Apache-2.0. See [LICENSE](/Users/mike/RCSGAMDevelopment/LICENSE).
- Use at your own risk. Review and validate the code before use. See [DISCLAIMER.md](/Users/mike/RCSGAMDevelopment/DISCLAIMER.md).

## Project Structure
- `gamgmaildeletebymsgid.py`: Single-process CLI script for CSV-driven Gmail deletion checks/deletes with GAM.
- `gamgmaildeletebymsgidparallel.py`: Parallel version with worker/retry/backoff controls for faster processing.
- `GAMMultiGUI/`: macOS SwiftUI wrapper for running the parallel script with a local GUI.
- `README.md`: Usage and configuration instructions.

## Requirements
- Python 3
- GAM installed and executable
- CSV file with at least these headers:
  - `Account`
  - `Rfc822MessageId`

## Platform Note
- The GUI app and Python scripts were built and tested on macOS 26.x.

For the packaged macOS GUI app:
- the app bundle includes the Python scripts
- users still need Python installed on macOS
- users still need GAM installed and authorized for check/execute flows

## Versioning
- Shared version source: `VERSION`
- Current version: `1.4.0`
- Release date: `2026-03-12`
- `gamgmaildeletebymsgid.py`: `1.4.0` (2026-03-12)
- `gamgmaildeletebymsgidparallel.py`: `1.4.0` (2026-03-12)
- `GAMMultiGUI`: `1.4.0` (2026-03-12)

Track versions with git tags that match `VERSION` (example: `v1.4.0`).

## Review CSV Mode
```bash
python3 gamgmaildeletebymsgid.py --review -f /path/to/export-metadata.csv
```

Review mode prints parsed CSV rows, including skipped rows and reasons, and does not call GAM.
Use `--log-file /path/to/log.txt` with either script if you want the console output saved to disk while it runs.
Use `--gam-version` with either script to print the locally installed GAM version and exit.

## Preview Commands Mode (Default)
```bash
python3 gamgmaildeletebymsgid.py -f /path/to/export-metadata.csv
```

Preview mode does not call GAM or Google APIs; it only prints commands.

Mode/status labels:
- Review mode prints `CSV-VALID` or `CSV-SKIP`
- Preview mode prints `CSV-TEST`
- Check mode prints `DRYRUNFOUND` or `DRYRUNNOMATCH`
- Execute mode prints `DELETED` or `NOMATCH`

## Check Mode (First 10 Valid Rows)
```bash
python3 gamgmaildeletebymsgid.py -c -f /path/to/export-metadata.csv
```

Check mode calls GAM without `doit` and does not delete mail.

## Execute Deletes
```bash
python3 gamgmaildeletebymsgid.py -x -f /path/to/export-metadata.csv
```

`-x/--execute` and `-c/--check` are mutually exclusive.

## Optional GAM Override
```bash
GAM_PATH="/custom/path/to/gam" python3 gamgmaildeletebymsgid.py -f /path/to/export-metadata.csv
```

## Parallel Script
```bash
python3 gamgmaildeletebymsgidparallel.py --review -f /path/to/export-metadata.csv
python3 gamgmaildeletebymsgidparallel.py -f /path/to/export-metadata.csv
python3 gamgmaildeletebymsgidparallel.py -c -f /path/to/export-metadata.csv
python3 gamgmaildeletebymsgidparallel.py -x -f /path/to/export-metadata.csv -w 8 -r 3 -b 0.75
python3 gamgmaildeletebymsgidparallel.py --review -f /path/to/export-metadata.csv --log-file /path/to/review-log.txt
```

Parallel options:
- `-w, --workers`: Number of concurrent GAM workers (higher is faster, but can increase rate-limit errors).
- `-r, --retries`: Number of retry attempts for transient/rate-limit failures per row.
- `-b, --backoff`: Base backoff delay in seconds before retries; each retry uses exponential backoff from this base.

## GAMMultiGUI
`GAMMultiGUI` is the local macOS wrapper for `gamgmaildeletebymsgidparallel.py`.

Current GUI behavior:
- Pressing `Run` clears the output pane before validation and launch so each run starts fresh.
- `Clear Output` still works as a manual action when you want to wipe the log without starting a run.
- `Save Output` exports the current output pane to a `.txt` file.
- Modes are `Review CSV`, `Preview Commands`, `Check (first 10)`, and `Execute Deletes`.
- `Test GAM Setup` runs local GAM diagnostics, including version and `gam info domain`, before you start destructive actions.
- `GAM Setup Help` shows macOS installation guidance, Python download guidance, support/contact details, and copy/paste-only URLs.
- `Check GAM Version` runs a local GAM version check from the app without starting a delete workflow.
- The packaged app bundle carries its own copies of the Python scripts in `Contents/Resources`.

## Distribution
Current packaged artifacts:
- `GAMMultiGUI/dist/GAMMultiGUI.app`: signed macOS app bundle
- `GAMMultiGUI/dist/GAMMultiGUI-1.4.0.pkg`: signed, notarized, stapled macOS installer package

Installer behavior:
- installs `GAMMultiGUI.app` into `/Applications`
- accepted by Gatekeeper as a notarized Developer ID installer
