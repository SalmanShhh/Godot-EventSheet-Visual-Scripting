# Godot EventSheets - EVERY ROW READING AS ONE SORTED TEXT (dev tool).
#
# The registry dumps beside this one write down what a verb IS and what it SAYS. Neither of them
# writes down what a ROW READS LIKE, and a row's reading is the thing a person actually looks at: the
# object word in its own column, the sentence in the cell, the chip marks around it. A refactor of
# the two reading files can move any of that without moving an emitted byte, a descriptor field or a
# translation key, which is exactly the kind of change no gate here could see.
#
# So the readings get a text of their own, in the same shape and with the same escaping:
#
#     <origin>  <lane>  <object>  <segments>  <path>
#
# tab separated, sorted by origin, no counts, no timestamps, no machine paths - the same properties
# that make the identity dump diffable, for the same reason. `tools/reading_lines.gd` beside this
# file is the writer and says what each field means.
#
# THE POPULATION IS BOTH HALVES OF WHAT THE BUILDER READS:
#
#   1. EVERY BUILTIN DESCRIPTOR filled with its own defaults, in each lane it can hold a row in - the
#      same population the built-in compile gate walks, which is what a picker offers on day one.
#      Expressions are skipped: they are values inside a row, never a row.
#   2. EVERY ROW OF EVERY SHEET under `demo/showcase/` and `eventsheet_addons/` - the generated
#      showcases and the shipped behaviour packs, opened the way opening a `.gd` opens them. That is
#      about 150 files and 34,000 lines of real game code, which is where the readings that only
#      happen to a lifted line live.
#
# THE GATE IS A DIFF, not a committed golden - and that is a DECISION, not an omission. The text is
# 4-5 MB and it moves the day any showcase is regenerated or any verb is added, so a copy committed
# beside the tree would be stale more often than it was right, and a stale golden is worse than none:
# it fails for the wrong reason and teaches a reader to update it without looking. What IS worth
# keeping is the one line that identifies a text, so every run prints `sha=` beside its receipt. A
# change that means to move no reading quotes that line before and after; a change that means to move
# one says which lines. Neither needs a 5 MB file in the repository.
#
# Run it before a change and after it, and compare:
#
#     "$GODOT" --headless --path . --script tools/reading_dump.gd -- out=user://before.txt
#     ... make the change ...
#     "$GODOT" --headless --path . --script tools/reading_dump.gd -- out=user://after.txt
#
# A refactor that only shrinks the reading code prints `same`. A line that moved is a reading that
# moved, which is a behavior change and reverts.
#
# USAGE
#   "$GODOT" --headless --path . --script tools/reading_dump.gd
#   "$GODOT" --headless --path . --script tools/reading_dump.gd -- out=user://readings.txt
#   "$GODOT" --headless --path . --script tools/reading_dump.gd -- only=builtin
#   "$GODOT" --headless --path . --script tools/reading_dump.gd -- dirs=res://demo/showcase/
#
#   out=    write the text to a file instead of stdout, so the console binary's own banner lines
#           cannot land in a text somebody means to diff
#   only=   `builtin`, `sheets`, or `all` (the default)
#   dirs=   comma-separated folders to walk instead of the two defaults
#
# DETERMINISTIC AND BYTE-STABLE: the walk is sorted, the origin keys are stable across a vocabulary
# that grows, and nothing written is a time, a path outside the project or a live count of anything.
# Two runs over an unchanged tree write the same bytes, which `reading_dump_test` asserts.
@tool
extends SceneTree

const LINES := preload("res://tools/reading_lines.gd")

## The folders whose sheets are walked unless a run says otherwise: the generated showcases (whole
## small games) and the shipped behaviour packs (the vocabulary's own code). Between them they are
## the largest body of real event-sheet reading the tree holds.
const DEFAULT_DIRS: Array[String] = ["res://demo/showcase/", "res://eventsheet_addons/"]


func _init() -> void:
	var output_path: String = ""
	var only: String = "all"
	var folders: PackedStringArray = PackedStringArray(DEFAULT_DIRS)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			output_path = argument.trim_prefix("out=")
		elif argument.begins_with("only="):
			only = argument.trim_prefix("only=")
		elif argument.begins_with("dirs="):
			folders = argument.trim_prefix("dirs=").split(",", false)
	var readings: Array = []
	if only != "sheets":
		readings.append_array(LINES.builtin_readings())
	var unreadable: PackedStringArray = PackedStringArray()
	var dropped: PackedStringArray = PackedStringArray()
	if only != "builtin":
		readings.append_array(LINES.folder_readings(folders, unreadable, dropped))
	var text: String = LINES.text(readings)
	if output_path.is_empty():
		print(text)
	else:
		var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			print("could not write %s" % output_path)
			quit(1)
			return
		file.store_string(text)
		file.close()
		print("written=%s" % output_path)
	# The tail is the receipt, not the text: counted on stderr's side of the line so a redirected
	# `out=` run still says what it walked, and a piped run can drop it.
	print("sha=%s" % text.sha256_text())
	print("readings=%d unreadable=%d dropped=%d" % [readings.size(), unreadable.size(), dropped.size()])
	for path: String in unreadable:
		print("  does not open as a sheet: %s" % path)
	for path: String in dropped:
		print("  an event of this sheet reached the canvas as nothing: %s" % path)
	if not dropped.is_empty():
		# A REFUSAL, not a warning. A dump taken over a tree that drops rows is a text about a
		# population this run did not have, and every figure derived from it inherits the gap - which
		# is what happened once, silently, while the receipt below said all was well.
		print("REFUSED: this text is not a baseline - %d event(s) reached the canvas as nothing." % dropped.size())
		quit(1)
		return
	quit(0)
