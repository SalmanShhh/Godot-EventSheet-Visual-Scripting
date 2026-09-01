# Godot EventSheets - the standing contracts, checked from a command line (CI-able, read-only).
#
#   godot --headless --path . --script tools/verify_sheets.gd
#   godot --headless --path . --script tools/verify_sheets.gd -- res://player.gd res://enemy.gd
#   godot --headless --path . --script tools/verify_sheets.gd -- --skip res://tests/fixtures/
#
# Exit 0 when every check passes, 1 when any fails. A failure prints one line naming the file, the
# line, what is wrong and where in the editor the same thing is shown - the shape a terminal turns
# into a link.
#
# With no paths it reads the whole project, which is what a branch gate and a CI job want. With
# paths it reads exactly those, which is what a pre-commit hook wants: it hands over the staged
# files and the run costs a fraction of a second per file instead of a walk of everything.
#
# `--skip <prefix>` leaves out every path starting with that prefix, and exists for one situation: a
# folder of deliberately broken GDScript kept as test fixtures is the one thing this gate cannot
# tell from a real file. Repeat it for several. It applies to a listed path as much as to a walked
# one, so a hook can pass git's whole list without filtering it first.
#
# Nothing under res:// is written or touched, and the report is sorted - two machines given the same
# tree print the same lines.
@tool
extends SceneTree


func _init() -> void:
	var requested: PackedStringArray = PackedStringArray()
	var skipped: PackedStringArray = PackedStringArray()
	var expecting_skip: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if expecting_skip:
			skipped.append(argument)
			expecting_skip = false
		elif argument == "--skip":
			expecting_skip = true
		else:
			requested.append(argument)
	# The gate names ITSELF, because the whole-project form always has this file in its corpus and
	# check 1 loads every file as a script to ask the engine's own verdict. Asking that of the script
	# the engine is currently running hangs the process and then takes it down; a file the engine is
	# running is a file the engine read, so that one answer comes from that fact instead.
	var running: String = str((get_script() as Script).resource_path)
	var result: Dictionary = EventSheetVerify.run(requested, skipped, running)
	var failures: Array = result.get("failures", []) as Array
	for failure: Dictionary in failures:
		print(EventSheetVerify.failure_line(failure))
	print(EventSheetVerify.verdict(result))
	quit(1 if not failures.is_empty() else 0)
