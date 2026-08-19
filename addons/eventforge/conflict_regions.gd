# Godot EventSheets - conflict regions in an opened script (the "resolve it as events" reading).
#
# A .gd file that a merge left unresolved carries the three marker lines a merge writes:
#
#   <<<<<<< HEAD
#   ...our version of these lines...
#   =======
#   ...their version of these lines...
#   >>>>>>> their-branch
#
# (a merge run with diff3 also writes a `||||||| base` section between the two, which is recorded
# here and never offered as a side to keep - it is what BOTH sides changed, not a candidate.)
#
# This file is the whole reading and the whole resolution, with no editor in it, so the dialog, the
# Doctor check and the tests all agree about what a conflicted file says:
#  - find() locates every region with its two sides and the labels the merge wrote,
#  - blocks() cuts one side into the runs a reader picks between (one per function / one per
#    paragraph of statements) so the choice can be made per event rather than per file,
#  - side_by_side() pairs the two sides' blocks and says which pairs are identical (those are the
#    greyed rows - nothing to decide) and which differ,
#  - resolve() writes the file back with the markers gone and EVERY BYTE OUTSIDE THE REGIONS
#    UNTOUCHED. That last promise is why resolution rebuilds the file from the original lines
#    rather than from anything re-emitted: a file with one conflict in it must not come back with
#    the rest of it reformatted.
#
# Line endings survive: the source is split on "\n" only, so a CRLF file keeps its "\r" on the end
# of every kept line, and the marker lines (which are dropped whole) take their own with them.
@tool
class_name EventSheetConflictRegions
extends RefCounted

## The four marker prefixes a merge writes. Frozen: they are git's, not ours.
const OURS_MARK := "<<<<<<<"
const BASE_MARK := "|||||||"
const SPLIT_MARK := "======="
const THEIRS_MARK := ">>>>>>>"

## What each side of a region may be kept as.
const KEEP_OURS := "ours"
const KEEP_THEIRS := "theirs"
const KEEP_BOTH := "both"


## True when the source still holds an unresolved region. Cheap enough to ask on every open.
static func has_conflicts(source: String) -> bool:
	for line: String in source.split("\n"):
		if line.begins_with(OURS_MARK):
			return true
	return false


## Every unresolved region in `source`, in file order. Each is
## {index, start_line, end_line, ours_label, theirs_label, ours: PackedStringArray,
##  theirs: PackedStringArray, base: PackedStringArray}, where start_line / end_line are the
## zero-based line numbers of the `<<<<<<<` and `>>>>>>>` lines themselves.
##
## A region whose end marker never arrives is NOT reported: half a region is a file that is still
## being written, and offering to "resolve" it would delete the rest of the file.
static func find(source: String) -> Array[Dictionary]:
	var regions: Array[Dictionary] = []
	var lines: PackedStringArray = source.split("\n")
	var index: int = 0
	while index < lines.size():
		if not lines[index].begins_with(OURS_MARK):
			index += 1
			continue
		var region: Dictionary = _read_region(lines, index)
		if region.is_empty():
			index += 1
			continue
		region["index"] = regions.size()
		regions.append(region)
		index = int(region["end_line"]) + 1
	return regions


static func _read_region(lines: PackedStringArray, start: int) -> Dictionary:
	var ours: PackedStringArray = PackedStringArray()
	var base: PackedStringArray = PackedStringArray()
	var theirs: PackedStringArray = PackedStringArray()
	var section: int = 0  # 0 = ours, 1 = base, 2 = theirs
	var cursor: int = start + 1
	while cursor < lines.size():
		var line: String = lines[cursor]
		if line.begins_with(OURS_MARK):
			return {}  # a second opening before this one closed: not a region we understand
		if line.begins_with(BASE_MARK):
			section = 1
		elif line.strip_edges() == SPLIT_MARK:
			section = 2
		elif line.begins_with(THEIRS_MARK):
			return {
				"start_line": start,
				"end_line": cursor,
				"ours_label": _label(lines[start], OURS_MARK),
				"theirs_label": _label(line, THEIRS_MARK),
				"ours": ours,
				"base": base,
				"theirs": theirs,
			}
		elif section == 0:
			ours.append(line)
		elif section == 1:
			base.append(line)
		else:
			theirs.append(line)
		cursor += 1
	return {}


## The name the merge wrote after a marker ("HEAD", a branch, a commit subject). Empty when the
## merge wrote a bare marker, which some tools do.
static func _label(line: String, mark: String) -> String:
	return line.substr(mark.length()).strip_edges()


## One side cut into the runs a reader picks between: a function and its body stay together, and a
## paragraph of statements separated by a blank line is one run. Returns an Array of
## {label, lines: PackedStringArray, first_line}, where `first_line` is the offset inside the side.
##
## The cut is deliberately the reader's, not the parser's: what a person means by "this event" in a
## conflicted region is the block of lines that hangs together on screen, and a blank line is how
## every GDScript file already says where one ends.
static func blocks(side: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var current: PackedStringArray = PackedStringArray()
	var current_start: int = 0
	for offset: int in side.size():
		var line: String = side[offset]
		var starts_block: bool = _is_block_head(line) and not current.is_empty()
		if starts_block:
			out.append(_finish_block(current, current_start))
			current = PackedStringArray()
			current_start = offset
		if line.strip_edges().is_empty():
			current.append(line)
			if not _all_blank(current):
				out.append(_finish_block(current, current_start))
				current = PackedStringArray()
				current_start = offset + 1
			continue
		if current.is_empty():
			current_start = offset
		current.append(line)
	if not current.is_empty():
		out.append(_finish_block(current, current_start))
	return out


static func _is_block_head(line: String) -> bool:
	var text: String = line.strip_edges()
	return text.begins_with("func ") or text.begins_with("static func ")


static func _all_blank(lines: PackedStringArray) -> bool:
	for line: String in lines:
		if not line.strip_edges().is_empty():
			return false
	return true


static func _finish_block(lines: PackedStringArray, first_line: int) -> Dictionary:
	return {"label": _block_label(lines), "lines": lines, "first_line": first_line}


## What a block is called in the two columns: its first line of substance, tidied. A block of pure
## blank lines is named for what it is rather than shown as an empty row.
static func _block_label(lines: PackedStringArray) -> String:
	for line: String in lines:
		var text: String = line.strip_edges()
		if not text.is_empty():
			return text
	return "(blank line)"


## The two sides paired for the columns: an Array of {ours, theirs, same}, where `ours` / `theirs`
## are block dictionaries (or null where one side has no counterpart) and `same` is true when the
## pair is identical - the rows the view greys out because there is nothing to decide about them.
##
## Pairing is by position, which is what a merge conflict actually is: two rewrites of the SAME run
## of lines. Anything cleverer would invent an alignment the merge itself did not make.
static func side_by_side(region: Dictionary) -> Array[Dictionary]:
	var ours: Array[Dictionary] = blocks(region.get("ours", PackedStringArray()) as PackedStringArray)
	var theirs: Array[Dictionary] = blocks(region.get("theirs", PackedStringArray()) as PackedStringArray)
	var rows: Array[Dictionary] = []
	for position: int in maxi(ours.size(), theirs.size()):
		var left: Variant = ours[position] if position < ours.size() else null
		var right: Variant = theirs[position] if position < theirs.size() else null
		rows.append({"ours": left, "theirs": right, "same": _same_block(left, right)})
	return rows


static func _same_block(left: Variant, right: Variant) -> bool:
	if left == null or right == null:
		return false
	var left_lines: PackedStringArray = (left as Dictionary).get("lines", PackedStringArray()) as PackedStringArray
	var right_lines: PackedStringArray = (right as Dictionary).get("lines", PackedStringArray()) as PackedStringArray
	return "\n".join(left_lines) == "\n".join(right_lines)


## The lines one region resolves to, given one choice per BLOCK PAIR (the per-event pick). Choices
## shorter than the pairing fall back to keeping ours, so a half-answered dialog can never drop
## someone's work.
static func resolved_lines(region: Dictionary, choices: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var rows: Array[Dictionary] = side_by_side(region)
	for position: int in rows.size():
		var choice: String = str(choices[position]) if position < choices.size() else KEEP_OURS
		var row: Dictionary = rows[position]
		if row["same"]:
			out.append_array(_block_lines(row["ours"]))
			continue
		match choice:
			KEEP_THEIRS:
				out.append_array(_block_lines(row["theirs"]))
			KEEP_BOTH:
				out.append_array(_block_lines(row["ours"]))
				out.append_array(_block_lines(row["theirs"]))
			_:
				out.append_array(_block_lines(row["ours"]))
	return out


static func _block_lines(block: Variant) -> PackedStringArray:
	if block == null:
		return PackedStringArray()
	return (block as Dictionary).get("lines", PackedStringArray()) as PackedStringArray


## Keeping one whole side (the "Keep ours" / "Keep theirs" / "Keep both" buttons on the region
## header rather than on a single pair): the choice repeated for every pair.
static func whole_side_choices(region: Dictionary, choice: String) -> Array:
	var out: Array = []
	for _row: Dictionary in side_by_side(region):
		out.append(choice)
	return out


## The resolved file. `choices_by_region` is an Array with one entry per region, each itself an
## Array of per-pair choices. Returns {ok, text, error}.
##
## THE CONTRACT: every line that is not inside a region is copied across verbatim, in order, and
## the marker lines are the only lines that disappear on their own. A file with one region resolved
## and another left alone still holds the second region's markers, exactly as it did.
static func resolve(source: String, choices_by_region: Array) -> Dictionary:
	var regions: Array[Dictionary] = find(source)
	if regions.is_empty():
		return {"ok": true, "text": source, "error": ""}
	var lines: PackedStringArray = source.split("\n")
	var out: PackedStringArray = PackedStringArray()
	var cursor: int = 0
	for region: Dictionary in regions:
		var start: int = int(region["start_line"])
		var end: int = int(region["end_line"])
		while cursor < start:
			out.append(lines[cursor])
			cursor += 1
		var choices: Variant = choices_by_region[region["index"]] if int(region["index"]) < choices_by_region.size() else null
		if choices == null:
			# Not answered: the region stays exactly as it was, markers and all.
			while cursor <= end:
				out.append(lines[cursor])
				cursor += 1
			continue
		out.append_array(resolved_lines(region, choices as Array))
		cursor = end + 1
	while cursor < lines.size():
		out.append(lines[cursor])
		cursor += 1
	return {"ok": true, "text": "\n".join(out), "error": ""}


## What the Doctor says about a file that still has regions in it, in the sheet's own words.
## Returned as the message text only; the caller adds the severity and the path.
static func doctor_message(regions: Array[Dictionary], file_name: String) -> String:
	if regions.size() == 1:
		return "%s still has an unresolved merge conflict - open it and pick per event (Keep ours / Keep theirs / Keep both)." % file_name
	return "%s still has %d unresolved merge conflicts - open it and pick per event (Keep ours / Keep theirs / Keep both)." % [file_name, regions.size()]


## The line the conflict view puts above the two columns.
static func region_heading(region: Dictionary) -> String:
	var ours_label: String = str(region.get("ours_label", ""))
	var theirs_label: String = str(region.get("theirs_label", ""))
	if ours_label.is_empty() and theirs_label.is_empty():
		return "Conflict %d" % (int(region.get("index", 0)) + 1)
	return "Conflict %d: %s against %s" % [int(region.get("index", 0)) + 1, ours_label, theirs_label]
