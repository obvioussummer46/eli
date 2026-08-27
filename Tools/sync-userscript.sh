#!/usr/bin/env bash
# Regenerates the bundled restyle script from the Safari userscript so both
# stay identical. Run after editing userscript/schulportal-mobile.user.js.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="userscript/schulportal-mobile.user.js"
DST="SchulportalMobile/Resources/portal-mobile.js"

{
  echo "// Schulportal Hessen — mobile restyle, injected into the in-app browser."
  echo "//"
  echo "// This is the body of \`$SRC\` with the"
  echo "// ==UserScript== metadata block removed, so the exact same code runs in Safari"
  echo "// and inside the app. Keep the two in sync: \`Tools/sync-userscript.sh\`."
  echo
  sed -n '/^\/\/ ==\/UserScript==$/,$p' "$SRC" | tail -n +2 | sed '/./,$!d'
} > "$DST"

echo "wrote $DST ($(wc -l < "$DST") lines)"
