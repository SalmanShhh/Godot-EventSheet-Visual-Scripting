# Godot EventSheets - the VERBATIM LEDGER as plain text: what the lines nothing claims look like.
#
# The Doctor's Reading page answers this for the project a person has open. This answers it for a
# FOLDER, headless, as text a person can read, diff and paste into a plan - which is the input for
# deciding where the next curated table should go. A shape said thirty times is a table entry waiting
# to be written; a shape said once is nobody's table, and is counted rather than listed.
#
# The census is the same one the Doctor page and the corpus pins use, through the same reader
# (EventSheetLiftReading + EventSheetReadingShapes), so this tool can never report a different
# ledger from the editor's own.
#
# USAGE (the binary is Godot 4.7 - keep the path out of anything committed):
#   "$GODOT" --headless --path . --script tools/reading_shape_census.gd
#   "$GODOT" --headless --path . --script tools/reading_shape_census.gd -- dir=res://demo top=40
#
#   dir=    the folder to walk, recursively (default: the showcases)
#   top=    how many shapes to name before counting the rest (default: 25)
#   limit=  how many scripts to read at most (default: every one of them)
#
# DETERMINISTIC AND BYTE-STABLE: the walk is sorted, the ranking breaks ties on the shape's own text,
# and nothing printed is a time, a path outside the project, or a live count of anything but the
# folder. Two runs over an unchanged folder print the same bytes.
@tool
extends SceneTree

## The folder the ledger is about unless a run says otherwise. The showcases are the plugin's own
## corpus of whole generated games, which is the closest thing here to somebody's project.
const DEFAULT_DIR: String = "res://demo/showcase/"

## How many shapes are NAMED before the rest are counted - the band scale law, as a default a run can
## raise. A ledger of four hundred rows is a ledger nobody reads.
const DEFAULT_TOP: int = 25

## How many lines one shape opens with before the rest of its lines are counted. Same law, one level
## down: the point of the lines is to show what the shape really is, and three of them do that.
const LINES_PER_SHAPE: int = 3


func _init() -> void:
	var directory: String = DEFAULT_DIR
	var top: int = DEFAULT_TOP
	var limit: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("dir="):
			directory = argument.trim_prefix("dir=")
		elif argument.begins_with("top="):
			top = maxi(int(argument.trim_prefix("top=")), 1)
		elif argument.begins_with("limit="):
			limit = maxi(int(argument.trim_prefix("limit=")), 0)
	if not directory.ends_with("/"):
		directory += "/"
	var scripts: PackedStringArray = _scripts_under(directory)
	if limit > 0 and scripts.size() > limit:
		scripts = scripts.slice(0, limit)
	var lines: Array[Dictionary] = []
	var read_lines: int = 0
	var total_lines: int = 0
	var read: int = 0
	for path: String in scripts:
		var source: String = FileAccess.get_file_as_string(path)
		if source.strip_edges().is_empty():
			continue
		read += 1
		var reading: Dictionary = EventSheetLiftReading.read(source, path)
		var coverage: Dictionary = reading.get("coverage", {}) as Dictionary
		read_lines += int(coverage.get("read_lines", 0))
		total_lines += int(coverage.get("total_lines", 0))
		lines.append_array(EventSheetReadingShapes.stays_code_lines(reading, path))
	var census: Dictionary = EventSheetReadingShapes.census(lines)
	_print_ledger(directory, read, scripts.size(), read_lines, total_lines, census, top)
	quit(0)


## The ledger itself. The two numbers are said APART and labelled, because they answer different
## questions and adding them together is the one mistake this page exists to prevent: the percentage
## is about DRAWING (how much of the file the canvas shows as rows rather than as a wall of code),
## the stays-code count is about NAMING (how many lines no vocabulary claims). A folder can draw
## entirely as rows and still have hundreds of lines nothing names.
func _print_ledger(directory: String, read: int, found: int, read_lines: int, total_lines: int,
		census: Dictionary, top: int) -> void:
	var percent: int = 100
	if total_lines > 0:
		percent = int(floor(100.0 * float(read_lines) / float(total_lines)))
	var shapes: Array = census.get("shapes", []) as Array
	var one_offs: Array = census.get("one_offs", []) as Array
	print("reading shape census: %s" % directory)
	print("scripts read: %d of %d" % [read, found])
	print("reads as rows: %d%% - the DRAWING question (%d of %d lines drawn as rows)" % [
		percent, read_lines, total_lines])
	print("stays code: %d line(s) - the NAMING question (what no vocabulary claims)" % [
		int(census.get("lines", 0))])
	print("")
	var repeated_lines: int = 0
	for entry: Variant in shapes:
		repeated_lines += int((entry as Dictionary).get("count", 0))
	print("%d shape(s) said more than once, over %d line(s):" % [shapes.size(), repeated_lines])
	for index: int in range(shapes.size()):
		var entry: Dictionary = shapes[index] as Dictionary
		if index >= top:
			print("  ... and %d more shape(s), over %d line(s)" % [shapes.size() - top,
				repeated_lines - _lines_in(shapes, top)])
			break
		print("  %5d  %s" % [int(entry.get("count", 0)), str(entry.get("shape", ""))])
		var held: Array = entry.get("lines", []) as Array
		for line_index: int in range(mini(LINES_PER_SHAPE, held.size())):
			var line: Dictionary = held[line_index] as Dictionary
			print("         %s:%d  %s" % [str(line.get("path", "")), int(line.get("number", 0)),
				str(line.get("text", "")).strip_edges()])
		if held.size() > LINES_PER_SHAPE:
			print("         ... and %d more line(s)" % (held.size() - LINES_PER_SHAPE))
	print("")
	# The honest tail. Counted, never expanded: a list of lines nothing else repeats is the longest
	# and least useful thing this tool could print, and the count is the whole truth about it.
	print("one-off shapes: %d line(s) nothing else here repeats" % one_offs.size())
	print("notes inside code: %d line(s) that hold no statement to shape" % int(census.get("notes", 0)))
	print("shapes=%d one_offs=%d stays_code=%d" % [shapes.size(), one_offs.size(),
		int(census.get("lines", 0))])


## How many lines the first `count` shapes hold - what the "and N more" line has to subtract.
func _lines_in(shapes: Array, count: int) -> int:
	var held: int = 0
	for index: int in range(mini(count, shapes.size())):
		held += int((shapes[index] as Dictionary).get("count", 0))
	return held


## Every .gd under a folder, sorted. Sorted rather than walked-and-printed, so the ledger is the same
## on NTFS (near-alphabetical) and on ext4 (hash order).
func _scripts_under(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray([root])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		for name: String in directory.get_directories():
			if not name.begins_with("."):
				pending.append(directory_path.path_join(name))
		for file_name: String in directory.get_files():
			var name: String = file_name.trim_suffix(".remap")
			if name.ends_with(".gd"):
				found.append(directory_path.path_join(name))
	found.sort()
	return found
