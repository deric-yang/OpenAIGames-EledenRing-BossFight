#!/bin/zsh
set -e
cd "$(dirname "$0")"
exec ../sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot --path . -- --assembly-preview
