#!/bin/sh
# Web-Link bauen: Godot-Web-Export, Engine gepackt, alles in build/web-link.
# Die Seite (godot/tools/web_link/index.html) leitet die Anfragen nach
# index.wasm und index.pck auf engine.wasm (gzip) und daten.wasm um, weil der
# Artifact-Dienst nur Dateien bis 15 MB und nur bestimmte Typen ausliefert.
#   ./web-link.sh     (Godot-Pfad per GODOT=..., sonst "godot" aus dem PATH)
set -e
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
EXP="$ROOT/build/godot-web"
OUT="$ROOT/build/web-link"
mkdir -p "$EXP" "$OUT"
cd "$ROOT/godot"
"$GODOT" --headless --import >/dev/null 2>&1
"$GODOT" --headless --export-release Web "$EXP/index.html" >/dev/null 2>&1
gzip -9 -c "$EXP/index.wasm" > "$OUT/engine.wasm"
cp "$EXP/index.pck" "$OUT/daten.wasm"
cp "$EXP/index.js" "$EXP/index.audio.worklet.js" "$EXP/index.audio.position.worklet.js" "$OUT/"
PCK=$(wc -c < "$EXP/index.pck" | tr -d ' ')
WASM=$(wc -c < "$EXP/index.wasm" | tr -d ' ')
sed -e "s/__PCK_SIZE__/$PCK/" -e "s/__WASM_SIZE__/$WASM/" "$ROOT/godot/tools/web_link/index.html" > "$OUT/index.html"
ls -la "$OUT"
