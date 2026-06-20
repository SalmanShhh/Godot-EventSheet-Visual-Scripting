#!/bin/sh
# git merge driver for EventSheet .tres files (see docs/VERSION-CONTROL.md).
# git invokes it as:  sheet_merge.sh %O %A %B %P
#   %O = common ancestor, %A = ours (ALSO the output file), %B = theirs, %P = pathname.
# Requires the Godot binary on PATH or in $GODOT.
#
# The merged sheet is written to %A by the script. We derive the clean/conflict exit code
# from the printed sentinel rather than Godot's process exit code, because Godot can emit a
# harmless non-zero on teardown that git would otherwise read as a conflict.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$("${GODOT:-godot}" --headless --quiet --path "$DIR" --script tools/sheet_merge.gd -- "$1" "$2" "$3" "$4" 2>/dev/null)"
echo "$OUT"
echo "$OUT" | grep -q "\[sheet_merge\] clean merge" && exit 0
exit 1
