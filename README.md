# RCSGAMDevelopment

Delete Gmail messages by `Rfc822MessageId` from a CSV export using GAM.

Developer: `miketrcs`

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

## Versioning
- Shared version source: `VERSION`
- Current version: `1.1.0`
- Release date: `2026-03-11`
- `gamgmaildeletebymsgid.py`: `1.1.0` (2026-03-11)
- `gamgmaildeletebymsgidparallel.py`: `1.1.0` (2026-03-11)
- `GAMMultiGUI`: `1.1.0` (2026-03-11)

Track versions with git tags that match `VERSION` (example: `v1.1.0`).

## Preview Mode (Default)
```bash
python3 gamgmaildeletebymsgid.py -f /path/to/export-metadata.csv
```

Preview mode does not call GAM or Google APIs; it only prints commands.

Preview/check/delete status labels:
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
python3 gamgmaildeletebymsgidparallel.py -f /path/to/export-metadata.csv
python3 gamgmaildeletebymsgidparallel.py -c -f /path/to/export-metadata.csv
python3 gamgmaildeletebymsgidparallel.py -x -f /path/to/export-metadata.csv -w 8 -r 3 -b 0.75
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
