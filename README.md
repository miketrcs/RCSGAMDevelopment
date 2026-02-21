# RCSGAMDevelopment

Delete Gmail messages by `Rfc822MessageId` from a CSV export using GAM.

## Project Structure
- `gamit.py`: CLI script that reads the CSV and deletes matching Gmail messages with GAM.
- `README.md`: Usage and configuration instructions.

## Requirements
- Python 3
- GAM installed and executable
- CSV file with at least these headers:
  - `Account`
  - `Rfc822MessageId`

## Dry Run
```bash
python3 gamit.py -f /path/to/export-metadata.csv
```

## Execute Deletes
```bash
python3 gamit.py -x -f /path/to/export-metadata.csv
```

## Optional GAM Override
```bash
GAM_PATH="/custom/path/to/gam" python3 gamit.py -f /path/to/export-metadata.csv
```
