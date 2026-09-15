#!/usr/bin/env bash
# Local dev server that actually shows the local Xiangqi engine.
#
# `elm reactor` doesn't work for this: it serves its own auto-generated
# wrapper HTML per .elm file and never runs the <script type="module">
# bridge that wires app.ports.{loadEngine,requestEngineMove,engineEvent} to
# assets/engine/worker.js. This script builds with the same checked-in
# index.html used by the real deploy and serves it.
#
# Builds into .dev-dist/ (gitignored, NOT the tracked dist/ directory --
# that one holds a real committed build; this script's output is a
# throwaway dev-mode build and has no business overwriting it).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PORT="${1:-8090}"   # not 8000: that's elm reactor's default port
DIST=.dev-dist

echo "Building Elm..."
elm make src/Main.elm --output="$DIST/bundle.js"

echo "Copying index.html..."
cp index.html "$DIST/index.html"

echo "Copying assets..."
rm -rf "$DIST/assets" "$DIST/cont"
cp -r assets "$DIST/assets"
cp -r cont "$DIST/cont"
[ -f status.json ] && cp status.json "$DIST/status.json" || echo '{"history":[]}' > "$DIST/status.json"

echo
echo "Serving http://localhost:$PORT/  (Ctrl+C to stop)"
echo "Open http://localhost:$PORT/ and click through to /xiangqi"
cd "$DIST"
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT"
else
  exec npx --yes serve -l "$PORT" .
fi
