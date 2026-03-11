# Icon Tooling

Reusable local icon pipeline for macOS apps.

## Files
- `generate_icon.py`: Generates a 1024x1024 master PNG (RGBA).
- `build_icns.py`: Builds an `.icns` file from a standard macOS iconset directory.
- `make_icon.sh`: One-command wrapper for full pipeline, with optional app-bundle install.

## Requirements
- `python3`
- `sips` (built into macOS)
- `PlistBuddy`, `codesign`, `xattr` (built into macOS) for `--app` install mode

## Quick Start

Generate icon assets in the default `../Assets` directory:

```bash
/Users/mike/RCSGAMDevelopment/GAMMultiGUI/scripts/make_icon.sh
```

Generate a different name/theme/output directory:

```bash
/Users/mike/RCSGAMDevelopment/GAMMultiGUI/scripts/make_icon.sh \
  --out-dir /tmp/my-icons \
  --name VaultOpsIcon \
  --theme google-vault-light
```

Install icon into an app bundle and re-sign ad-hoc:

```bash
/Users/mike/RCSGAMDevelopment/GAMMultiGUI/scripts/make_icon.sh \
  --name AppIcon \
  --app /Users/mike/RCSGAMDevelopment/GAMMultiGUI/dist/GAMMultiGUI.app
```

## Advanced Usage

Generate only the master PNG:

```bash
python3 /Users/mike/RCSGAMDevelopment/GAMMultiGUI/scripts/generate_icon.py \
  --output /tmp/AppIcon-1024.png \
  --theme google-vault \
  --size 1024
```

Build `.icns` from an existing iconset folder:

```bash
python3 /Users/mike/RCSGAMDevelopment/GAMMultiGUI/scripts/build_icns.py \
  --iconset /tmp/AppIcon.iconset \
  --output /tmp/AppIcon.icns
```

## Notes
- Recommended master icon size is `1024`.
- `--theme` is free-form. `google-vault` and `google-vault-light` keep their built-in palettes; any other value generates a deterministic unique palette.
- If Finder shows a stale app icon after replacement:

```bash
touch /path/to/YourApp.app
```
