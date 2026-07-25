#!/bin/bash
#
# Rota — one-command installer
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/aalemoro/Rota/main/scripts/install.sh)"
#
set -euo pipefail

REPO_URL="https://github.com/aalemoro/Rota.git"
BOLD=$(tput bold 2>/dev/null || true)
NORM=$(tput sgr0 2>/dev/null || true)

echo "${BOLD}🎡  Rota installer${NORM}"

# 1. Apple Command Line Tools (compiler + git)
if ! xcode-select -p >/dev/null 2>&1; then
  echo "🔧  Apple's Command Line Tools are required (free, ~2 min)."
  echo "    A system dialog will appear — click Install, then re-run this command."
  xcode-select --install >/dev/null 2>&1 || true
  exit 1
fi

# 2. Fetch the latest source
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "⬇️   Downloading Rota…"
git clone --quiet --depth 1 "$REPO_URL" "$TMP/Rota"

# 3. Build the app bundle
echo "🔨  Building (first build takes about a minute)…"
make -C "$TMP/Rota" app >/dev/null

# 4. Install
echo "📦  Installing…"
if rm -rf /Applications/Rota.app 2>/dev/null && cp -R "$TMP/Rota/build/Rota.app" /Applications/ 2>/dev/null; then
  DEST="/Applications/Rota.app"
else
  mkdir -p ~/Applications
  rm -rf ~/Applications/Rota.app
  cp -R "$TMP/Rota/build/Rota.app" ~/Applications/
  DEST="$HOME/Applications/Rota.app"
fi
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

open "$DEST"
echo "${BOLD}✅  Rota is running.${NORM} Tip: the first time, macOS will ask permission to control Music — click Allow."
