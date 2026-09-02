# Godot EventSheets - WHAT CLAIMS THIS LINE (dev tool).
#
# Point it at a script and a line number and it says, in provenance order, which reading layer claims
# that line: the curated lift tables (which entry, in which family file), the entries derived from a
# marked example, the hand-written matcher families, the general reverse index, the derived call and
# property readings (and which receiver resolution answered), and finally the honest verbatim
# fallback. The answers come from the real readers - EventSheetLiftProvenance asks the same
# EventSheetLiftReading, EventSheetACELifter and derived-reading code that runs when a file opens -
# so a line this tool explains is a line the editor reads the same way.
#
# USAGE
#   "$GODOT" --headless --path . --script tools/explain.gd -- res://path/to/file.gd 42
#   "$GODOT" --headless --path . --script tools/explain.gd -- res://path/to/file.gd 42 out=user://x.txt
#
# The output is plain text, one line per layer that answers, and the same bytes on every machine.
# `out=` writes it to a file instead of stdout, so the console binary's own banner lines cannot land
# in a text somebody means to diff.
#
# THE FAST LOOP FOR A TABLE ENTRY. This tool says which entry claims a line; the harness says whether
# that entry still keeps its promise. Between them the loop for changing one spelling is:
#
#   1. explain the line:   ... --script tools/explain.gd -- res://my/file.gd 42
#   2. edit the entry the TABLE layer named, in the family file it named;
#   3. rerun that entry ALONE, without the other several hundred:
#        $env:EVENTFORGE_LIFT_ONLY = "torch_brightness"
#        $env:EVENTFORGE_TEST_ONLY = "lift_table_test"
#        "$GODOT" --headless --path . --script tests/run_tests.gd
#      which prints the entry's generated fixture line, the row it claims, the values it reads off it
#      and the bytes it re-emits - the whole round trip for one entry, in a second or two;
#   4. read the diff in the `expected:` / `actual:` pair, and go back to 2.
#
# `EVENTFORGE_LIFT_ONLY` takes a comma-separated list of entry ids, exactly as EVENTFORGE_TEST_ONLY
# takes test names. Unset, the harness runs the whole table as it always has.
@tool
extends SceneTree


func _init() -> void:
	var script_path: String = ""
	var number: int = 0
	var output_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			output_path = argument.trim_prefix("out=")
		elif argument.is_valid_int():
			number = argument.to_int()
		elif script_path.is_empty():
			script_path = argument
	if script_path.is_empty() or number <= 0:
		print("usage: explain.gd -- <res://script.gd> <line number> [out=<path>]")
		quit(1)
		return
	if not FileAccess.file_exists(script_path):
		print("no such file: %s" % script_path)
		quit(1)
		return
	var source: String = FileAccess.get_file_as_string(script_path)
	var text: String = EventSheetLiftProvenance.text(source, number, script_path)
	if output_path.is_empty():
		print(text)
		quit(0)
		return
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		print("could not write %s" % output_path)
		quit(1)
		return
	file.store_string(text + "\n")
	file.close()
	print("written=%s" % output_path)
	quit(0)
