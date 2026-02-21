# RCSGAMDEVELOPMENT

Deletes Gmail messages by `Rfc822MessageId` from a CSV export using GAM.

## What changed
- Removed hardcoded `/Users/mike/...` paths.
- Script now derives defaults from the current user home directory (`Path.home()`).
- Added environment variable overrides for paths.

## Defaults
- `GAM_PATH`: defaults to `~/bin/gam7/gam`
- `CSV_PATH`: defaults to `~/Downloads/exportjobopportunity-metadata.csv`

## Run
```bash
python3 gamit.py
```

## Dry run
```bash
python3 gamit.py --dry-run
```

## Optional overrides
```bash
GAM_PATH="/custom/path/to/gam" CSV_PATH="/custom/path/to/file.csv" python3 gamit.py
```

With dry run and overrides:
```bash
GAM_PATH="/custom/path/to/gam" CSV_PATH="/custom/path/to/file.csv" python3 gamit.py --dry-run
```
