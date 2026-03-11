#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUT_DIR="${SCRIPT_DIR}/../Assets"

OUT_DIR="$DEFAULT_OUT_DIR"
NAME="AppIcon"
THEME="google-vault"
SIZE="1024"
APP_PATH=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options]

Options:
  --out-dir <path>      Output directory for PNG/iconset/icns (default: ${DEFAULT_OUT_DIR})
  --name <name>         Base icon name (default: AppIcon)
  --theme <theme>       Icon theme label (any value; custom values generate a unique palette)
  --size <px>           Master icon size (default: 1024)
  --app <path>          Optional .app bundle to install icon into
  -h, --help            Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --theme) THEME="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --app) APP_PATH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v sips >/dev/null 2>&1; then
  echo "[ERR] sips not found" >&2
  exit 1
fi

OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
ICONSET_DIR="${OUT_DIR}/${NAME}.iconset"
MASTER_PNG="${OUT_DIR}/${NAME}-1024.png"
ICNS_PATH="${OUT_DIR}/${NAME}.icns"

mkdir -p "$OUT_DIR" "$ICONSET_DIR"

echo "[INFO] Generating master PNG: $MASTER_PNG"
python3 "${SCRIPT_DIR}/generate_icon.py" --output "$MASTER_PNG" --size "$SIZE" --theme "$THEME"

find "$ICONSET_DIR" -name '*.png' -delete
for sz in 16 32 128 256 512; do
  sips -z "$sz" "$sz" "$MASTER_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}.png" >/dev/null
  sz2=$((sz * 2))
  sips -z "$sz2" "$sz2" "$MASTER_PNG" --out "$ICONSET_DIR/icon_${sz}x${sz}@2x.png" >/dev/null
done

echo "[INFO] Building ICNS: $ICNS_PATH"
python3 "${SCRIPT_DIR}/build_icns.py" --iconset "$ICONSET_DIR" --output "$ICNS_PATH"

if [[ -n "$APP_PATH" ]]; then
  APP_PATH="$(cd "$APP_PATH" && pwd)"
  if [[ ! -d "$APP_PATH/Contents" ]]; then
    echo "[ERR] Not a valid .app bundle: $APP_PATH" >&2
    exit 1
  fi

  echo "[INFO] Installing icon into app bundle: $APP_PATH"
  mkdir -p "$APP_PATH/Contents/Resources"
  cp "$ICNS_PATH" "$APP_PATH/Contents/Resources/${NAME}.icns"

  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$APP_PATH/Contents/Info.plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string ${NAME}" "$APP_PATH/Contents/Info.plist"
  /usr/bin/plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null

  xattr -cr "$APP_PATH"
  codesign --force --deep --sign - "$APP_PATH" >/dev/null
  codesign --verify --deep --strict "$APP_PATH"
  echo "[INFO] Installed and re-signed: $APP_PATH"
fi

echo "[OK] Icon pipeline complete"
echo "     Master PNG: $MASTER_PNG"
echo "     Iconset:    $ICONSET_DIR"
echo "     ICNS:       $ICNS_PATH"
