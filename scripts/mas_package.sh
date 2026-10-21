#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# scripts/mas_package.sh — build, firma e impacchetta Rota per il Mac App Store.
#
#   ./scripts/mas_package.sh
#
# Prima di lanciarlo servono, in profiles/:
#   Rota_MAS.provisionprofile         (App ID io.github.aalemoro.rota)
#   RotaWidget_MAS.provisionprofile   (App ID io.github.aalemoro.rota.widget)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")/.."

# Identita' di firma: le trova da sole nel portachiavi (override con APP_CERT/PKG_CERT).
find_id() { security find-identity -v -p codesigning | sed -n "s/.*\"\(.*$1.*\)\".*/\1/p" | head -1; }
# i certificati Installer NON sono identita' di codesigning: vanno cercati senza -p
find_id_pkg() { security find-identity -v | sed -n "s/.*\"\(.*$1.*\)\".*/\1/p" | head -1; }
APP_CERT="${APP_CERT:-$(find_id 'Apple Distribution')}"
[[ -z "$APP_CERT" ]] && APP_CERT="$(find_id '3rd Party Mac Developer Application')"
PKG_CERT="${PKG_CERT:-$(find_id_pkg 'Mac Developer Installer')}"

APP="build/Rota.app"
APPEX="$APP/Contents/PlugIns/RotaWidgetExtension.appex"
PROFILE_APP="${PROFILE_APP:-profiles/Rota_MAS.provisionprofile}"
PROFILE_WIDGET="${PROFILE_WIDGET:-profiles/RotaWidget_MAS.provisionprofile}"

echo "App cert : ${APP_CERT:-NON TROVATO}"
echo "Pkg cert : ${PKG_CERT:-NON TROVATO}"
[[ -n "$APP_CERT" ]] || { echo "❌ manca il certificato Apple Distribution"; exit 1; }
[[ -n "$PKG_CERT" ]] || { echo "❌ manca il certificato Mac Installer Distribution (3rd Party Mac Developer Installer)"; exit 1; }

for f in "$PROFILE_APP" "$PROFILE_WIDGET"; do
  [[ -f "$f" ]] || { echo "❌ manca $f — scaricalo da developer.apple.com"; exit 1; }
done

echo "▶︎ build…"
make app

echo "▶︎ provisioning profiles…"
cp "$PROFILE_APP"    "$APP/Contents/embedded.provisionprofile"
cp "$PROFILE_WIDGET" "$APPEX/Contents/embedded.provisionprofile"

echo "▶︎ pulizia attributi estesi (com.apple.quarantine)…"
xattr -cr "$APP"

echo "▶︎ firma widget…"
codesign --force --timestamp --options runtime \
  --entitlements scripts/mas-widget.entitlements \
  --sign "$APP_CERT" "$APPEX"

echo "▶︎ firma app…"
codesign --force --timestamp --options runtime \
  --entitlements scripts/mas.entitlements \
  --sign "$APP_CERT" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP" | head -40

echo "▶︎ pkg…"
rm -f build/Rota.pkg
productbuild --component "$APP" /Applications --sign "$PKG_CERT" build/Rota.pkg

echo "✅ build/Rota.pkg pronto — aprilo con Transporter.app (Deliver) per l'upload."
