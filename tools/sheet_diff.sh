#!/bin/sh
# git textconv wrapper (see CONTRIBUTING "Reviewable sheet diffs").
# Requires the Godot binary on PATH or in $GODOT.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "${GODOT:-godot}" --headless --quiet --path "$DIR" --script tools/sheet_to_text.gd -- "$1" 2>/dev/null
