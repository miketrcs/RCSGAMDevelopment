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
- `CSV_PATH`: `~/Downloads/exportjobopportunity-metadata.csv`

## Run
```bash
python3 gamit.py
```

## Dry Run
```bash
python3 gamit.py --dry-run
```

## Optional Overrides
```bash
GAM_PATH="/custom/path/to/gam" CSV_PATH="/custom/path/to/file.csv" python3 gamit.py
```

With dry run and overrides:

```bash
GAM_PATH="/custom/path/to/gam" CSV_PATH="/custom/path/to/file.csv" python3 gamit.py --dry-run
```
