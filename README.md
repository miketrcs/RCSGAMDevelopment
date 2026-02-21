# RCSGAMDevelopment

Delete Gmail messages by `Rfc822MessageId` from a CSV export using GAM.

## Project Structure
- `gamit.py`: CLI script that reads the CSV and deletes matching Gmail messages with GAM.
- `README.md`: Usage and configuration instructions.

## Requirements
- Python 3
- GAM installed and executable (default path: `~/bin/gam7/gam`)
- CSV file with at least these headers:
  - `Account`
  - `Rfc822MessageId`

## Defaults
- `GAM_PATH`: `~/bin/gam7/gam`
- No default CSV path. You must provide `-f /path/to/file.csv` each run.

## Run
```bash
python3 gamit.py -f /path/to/export-metadata.csv
```

## Dry Run
```bash
python3 gamit.py -f /path/to/export-metadata.csv
```

## Execute Deletes
```bash
python3 gamit.py -x -f /path/to/export-metadata.csv
```

## Use a Custom CSV File
```bash
python3 gamit.py -f /path/to/export-metadata.csv
```

With execute mode and custom file:
```bash
python3 gamit.py -x -f /path/to/export-metadata.csv
```

## Optional GAM Override
```bash
GAM_PATH="/custom/path/to/gam" python3 gamit.py -f /path/to/export-metadata.csv
```
