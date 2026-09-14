#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="Overwatch.app"
RES="$APP/Contents/Resources"
MACOS="$APP/Contents/MacOS"

BIN=""
for candidate in \
  ".build/apple/Products/Release/Overwatch" \
  ".build/release/Overwatch" \
  ".build/x86_64-apple-macosx/release/Overwatch" \
  ".build/arm64-apple-macosx/release/Overwatch"
do
  if [[ -x "$candidate" ]]; then
    BIN="$candidate"
    break
  fi
done

if [[ -z "$BIN" ]]; then
  echo "Missing Overwatch binary — run swift build -c release first" >&2
  exit 1
fi

echo "Packaging $BIN ($(lipo -archs "$BIN" 2>/dev/null || echo unknown arch))"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BIN" "$MACOS/Overwatch"
cp Info.plist "$APP/Contents/Info.plist"

if [[ -f Resources/AppIcon.png ]]; then
  mkdir -p "$ROOT/.build/AppIcon.iconset"
  for dim in 16 32 128 256 512; do
    sips -z "$dim" "$dim" Resources/AppIcon.png --out "$ROOT/.build/AppIcon.iconset/icon_${dim}x${dim}.png" >/dev/null
    sips -z $((dim * 2)) $((dim * 2)) Resources/AppIcon.png --out "$ROOT/.build/AppIcon.iconset/icon_${dim}x${dim}@2x.png" >/dev/null
  done
  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ROOT/.build/AppIcon.iconset" -o "$RES/AppIcon.icns" 2>/dev/null || true
  fi
  if [[ ! -f "$RES/AppIcon.icns" ]]; then
    sips -s format icns Resources/AppIcon.png --out "$RES/AppIcon.icns" >/dev/null 2>&1 || cp Resources/AppIcon.png "$RES/AppIcon.png"
  fi
  cp Resources/AppIcon.png "$RES/AppIcon.png"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null
fi

echo "Built $APP"
