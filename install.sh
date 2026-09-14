#!/bin/bash
# Compile Maconky on this Mac and install it. Local builds are not quarantined.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "Maconky needs Swift 6. Install Xcode Command Line Tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

ARCH="$(uname -m)"
echo "Building Maconky for ${ARCH} on this Mac…"
make ARCHS="${ARCH}" app

DEST="${MACONKY_INSTALL_DIR:-$HOME/Applications}"
mkdir -p "${DEST}"
rm -rf "${DEST}/Maconky.app"
ditto "${ROOT}/Maconky.app" "${DEST}/Maconky.app"

echo "Installed ${DEST}/Maconky.app"
open "${DEST}/Maconky.app"
echo "Look for the gauge icon in the menu bar."
