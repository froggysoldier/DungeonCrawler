#!/bin/sh
# Alle Godot-Tests headless ausführen. Laufzeitfehler zählen als Fehlschlag.
#   ./test.sh            alle Tests
#   ./test.sh replay     nur Dateien, deren Name "replay" enthält
# Godot-Pfad per GODOT=..., sonst "godot" aus dem PATH.
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/godot" || exit 1
# Import registriert neue Klassen (class_name) und Ressourcen
"$GODOT" --headless --import >/dev/null 2>&1
if [ -n "$1" ]; then
	exec "$GODOT" --headless -s res://tests/run_tests.gd -- "$1"
fi
exec "$GODOT" --headless -s res://tests/run_tests.gd
