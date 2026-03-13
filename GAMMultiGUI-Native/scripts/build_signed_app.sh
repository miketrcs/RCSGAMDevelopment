#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"

APP_NAME="${APP_NAME:-GAMIT}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-GAMMultiGUI}"
BUNDLE_ID="${BUNDLE_ID:-com.miketrcs.gammultigui.native}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARIZE_PKG="${NOTARIZE_PKG:-1}"
VERSION_FILE="${VERSION_FILE:-$PROJECT_DIR/VERSION}"
VERSION="$(tr -d '\n' < "$VERSION_FILE")"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$REPO_ROOT" rev-list --count HEAD)}"

BUILD_DIR="$PROJECT_DIR/.build"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
PKG_NAME="${PKG_NAME:-$APP_NAME-$VERSION.pkg}"
PKG_PATH="$DIST_DIR/$PKG_NAME"
PKG_SHA_PATH="$PKG_PATH.sha256"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ICON_SOURCE="$PROJECT_DIR/Assets/AppIcon.icns"
PRODUCT_BINARY="$BUILD_DIR/apple/Products/Release/$EXECUTABLE_NAME"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "SIGN_IDENTITY is required. Export your Developer ID Application certificate name." >&2
  exit 1
fi

if [[ -z "$PKG_SIGN_IDENTITY" ]]; then
  echo "PKG_SIGN_IDENTITY is required. Export your Developer ID Installer certificate name." >&2
  exit 1
fi

if [[ "$NOTARIZE_PKG" == "1" && -z "$NOTARY_PROFILE" ]]; then
  echo "NOTARY_PROFILE is required when NOTARIZE_PKG=1." >&2
  exit 1
fi

mkdir -p "$DIST_DIR"

env \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache" \
  CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-module-cache" \
  swift build -c release --product "$EXECUTABLE_NAME" --arch arm64 --arch x86_64

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$PRODUCT_BINARY" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"

cat > "$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
spctl -a -t exec -vv "$APP_BUNDLE"

rm -f "$PKG_PATH" "$PKG_SHA_PATH"
productbuild --component "$APP_BUNDLE" /Applications --sign "$PKG_SIGN_IDENTITY" "$PKG_PATH"
pkgutil --check-signature "$PKG_PATH"

if [[ "$NOTARIZE_PKG" == "1" ]]; then
  xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$PKG_PATH"
fi

spctl -a -t install -vv "$PKG_PATH"
shasum -a 256 "$PKG_PATH" > "$PKG_SHA_PATH"

echo "Signed app bundle created at: $APP_BUNDLE"
echo "Signed installer package created at: $PKG_PATH"
echo "SHA-256 checksum written to: $PKG_SHA_PATH"
