#!/bin/zsh
cd "$(dirname "$0")"
GILDED_GODOT="${GODOT_BIN:-../sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot}"
exec "$GILDED_GODOT" --path . -- --crown-intro
