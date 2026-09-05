# Measures the figures README.md's front page quotes about the plugin, and names the sentences that
# disagree with what the tree actually holds. Run:
#   godot --headless --path . --script tools/measure_front_page.gd
#   godot --headless --path . --script tools/measure_front_page.gd -- --reading
#   godot --headless --path . --script tools/measure_front_page.gd -- --reading limit=25
#
# WHY THIS EXISTS: the same reason tools/measure_packs.gd exists. Three sentences on the front page
# carry hand-typed numbers - how many verbs the vocabulary holds, how many of them are triggers, how
# many files the plugin's own source is, how many of those open with no script block in them, and
# what share of their lines the sheet draws as rows. Nothing derived any of them, so they drift
# silently: the file count was written as 1,045 and the tree held more than that before this tool
# existed. This is the one place they are computed.
#
# READ-ONLY, DELIBERATELY. measure_packs rewrites its literal because a pack count is a walk of
# builders that any checkout reproduces in a second. These are not that: the reading half opens and
# re-emits every script in the plugin, which is minutes of work whose answer depends on every file
# in the tree - including the half-finished ones sitting beside yours. A rewrite from a dirty
# working copy would put a number into the records that no clean checkout can reproduce, which is
# the exact failure measure_packs' header warns about. So this MEASURES and NAMES; a human moves the
# literal, having run it where the answer means something.
#
# RUN THE READING HALF IN AN ISOLATED WORKTREE:
#   git worktree add ../ef-measure HEAD
#   godot --headless --path ../ef-measure --script tools/measure_front_page.gd -- --reading
# Without that, an uncommitted script counts as one of the plugin's files and its lines land in the
# share. The vocabulary half is safe anywhere: it asks the registry, which only holds what the
# providers registered.
#
# WHAT IS MEASURED, EXACTLY:
#
#   THE VOCABULARY (seconds; always run). Every descriptor the registry holds, and how many of them
#   are triggers - `ACEDescriptor.ACEType.TRIGGER`, which is what "triggers" means everywhere else
#   in this repo. The parameter total is printed beside them because it is the next thing anybody
#   asks; no sentence on the front page quotes it today, so nothing is checked against it.
#
#   THE READING (minutes; only under --reading). Every `.gd` under `res://addons/` and `res://tools/`
#   - the plugin's own hand-written source, which is what "this repo's own N hand-written files"
#   names. `eventsheet_addons/`, `demo/` and `tests/` are NOT in it: the first two are compiler
#   output and the third is written to be read by a runner rather than by a person. Each file is
#   opened as a sheet through the same reader the canvas reads (EventSheetLiftReading), and three
#   numbers come out: how many files there are, how many of them hold no script block at all
#   (`block_rows == 0`), and `drawn` - the share of all their lines that arrive as rows rather than
#   as blocks.
#
# WHAT IS DELIBERATELY NOT CHECKED, AND WHY. The front page's third figure - "89.9% of those rows in
# the sheet's own words" - is the NAMING question, not the drawing one, and the two are different
# numbers that must never be swapped: DRAWING asks how much of a file the canvas shows as rows
# instead of as a wall of code, NAMING asks how many of those rows a vocabulary has words for. A
# folder can draw entirely as rows and still hold hundreds of lines no vocabulary claims, which is
# the whole reason `tools/reading_shape_census.gd` prints its two numbers apart and labels them.
# `drawn` below is the DRAWING share, so it is printed under its own name and checked against
# nothing. Deriving the naming one means agreeing first on what its denominator is - every row, or
# every row that carries a verb - and that is a decision to make in front of the sentence rather
# than a line to add here. Until somebody makes it, that literal stays hand-typed and stays said.
#
# DETERMINISTIC: the walk is sorted, nothing printed is a time or a path outside the project, and
# two runs over an unchanged tree print the same bytes.
@tool
extends SceneTree

## The folders the plugin's own source lives in. Sorted walks of both, and nothing else: the packs
## and the showcases are COMPILER OUTPUT, so counting them would be measuring the emitter rather
## than what somebody wrote.
const SOURCE_DIRS: Array[String] = ["res://addons/", "res://tools/"]

## The file whose sentences are checked. One file, because the front page is the only place these
## particular numbers are quoted - CLAUDE.md quotes the pack count and nothing here.
const RECORD_FILE: String = "res://README.md"

## The sentences, as the patterns that find their literals. Each is checked only when the run has
## measured the figure it names, so a run without --reading says nothing about the reading ones
## rather than calling them wrong.
##
## `key` is what the measurement is called below; `pattern` finds the literal, whose FIRST capture
## group is the number; `needs_reading` says which half has to have run.
const SENTENCES: Array[Dictionary] = [
	{"key": "aces", "pattern": "\\*\\*([\\d,]+) native ACEs\\*\\*", "needs_reading": false},
	{"key": "triggers", "pattern": "\\((\\d+) triggers\\)", "needs_reading": false},
	{"key": "files", "pattern": "own \\*?\\*?([\\d,]+) hand-written files", "needs_reading": true},
	{"key": "files", "pattern": "\\*\\*([\\d,]+) files, [\\d,]+ of them at zero script blocks",
		"needs_reading": true},
	{"key": "zero_blocks", "pattern": "\\*\\*[\\d,]+ files, ([\\d,]+) of them at zero script blocks",
		"needs_reading": true}
]


func _init() -> void:
	var with_reading: bool = false
	var limit: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--reading":
			with_reading = true
		elif argument.begins_with("limit="):
			limit = maxi(int(argument.trim_prefix("limit=")), 0)
	var measured: Dictionary = _vocabulary()
	print("aces=%d triggers=%d parameters=%d" % [int(measured["aces"]), int(measured["triggers"]),
		int(measured["parameters"])])
	if with_reading:
		measured.merge(_reading(limit), true)
		print("files=%d zero_blocks=%d drawn=%s" % [int(measured["files"]),
			int(measured["zero_blocks"]), _one_decimal(float(measured["drawn"]))])
	else:
		print("files=(not measured - pass --reading)")
	_report(measured, with_reading, limit)
	quit(0)


## The vocabulary half: every descriptor the registry holds, counted by what it is. Seconds, and it
## asks the same registry every other reader asks, so it cannot report a vocabulary the editor does
## not have.
func _vocabulary() -> Dictionary:
	var aces: int = 0
	var triggers: int = 0
	var parameters: int = 0
	for entry: Variant in ACERegistry.get_all_descriptors():
		var descriptor: ACEDescriptor = entry as ACEDescriptor
		if descriptor == null:
			continue
		aces += 1
		if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
			triggers += 1
		parameters += descriptor.params.size()
	return {"aces": aces, "triggers": triggers, "parameters": parameters}


## The reading half: every plugin script opened as a sheet, through the reader the canvas reads.
## `limit` cuts the walk short for a smoke run - the numbers it then prints are about those files
## and nothing else, which the report says out loud rather than leaving somebody to notice.
func _reading(limit: int) -> Dictionary:
	var scripts: PackedStringArray = PackedStringArray()
	for directory: String in SOURCE_DIRS:
		scripts.append_array(_scripts_under(directory))
	if limit > 0 and scripts.size() > limit:
		scripts = scripts.slice(0, limit)
	var files: int = 0
	var zero_blocks: int = 0
	var read_lines: int = 0
	var total_lines: int = 0
	for path: String in scripts:
		var source: String = FileAccess.get_file_as_string(path)
		if source.strip_edges().is_empty():
			continue
		files += 1
		var reading: Dictionary = EventSheetLiftReading.read(source, path)
		var coverage: Dictionary = reading.get("coverage", {}) as Dictionary
		if int(coverage.get("block_rows", 0)) == 0:
			zero_blocks += 1
		read_lines += int(coverage.get("read_lines", 0))
		total_lines += int(coverage.get("total_lines", 0))
	var drawn: float = 100.0
	if total_lines > 0:
		drawn = 100.0 * float(read_lines) / float(total_lines)
	return {"files": files, "zero_blocks": zero_blocks, "drawn": drawn,
		"read_lines": read_lines, "total_lines": total_lines}


## What the front page says against what was just measured. A sentence whose literal agrees is not
## mentioned: the point of the report is the drift, and a list of everything that is fine buries it.
func _report(measured: Dictionary, with_reading: bool, limit: int) -> void:
	if limit > 0:
		print("")
		print("SMOKE RUN: only the first %d script(s) were read, so the reading figures are about"
			% limit)
		print("those files and nothing else. Nothing is checked against README.md.")
		return
	var text: String = FileAccess.get_file_as_string(RECORD_FILE)
	if text.is_empty():
		print("")
		print("%s could not be read, so no sentence was checked." % RECORD_FILE)
		return
	var drifted: PackedStringArray = PackedStringArray()
	for sentence: Dictionary in SENTENCES:
		if bool(sentence["needs_reading"]) and not with_reading:
			continue
		var key: String = str(sentence["key"])
		var found: RegExMatch = RegEx.create_from_string(str(sentence["pattern"])).search(text)
		if found == null:
			drifted.append("  the sentence matching `%s` is no longer in %s"
				% [str(sentence["pattern"]), RECORD_FILE])
			continue
		var quoted: String = found.get_string(1)
		var said: String = _thousands(int(measured[key]))
		if quoted == said:
			continue
		drifted.append("  line %d says %s, measured %s  (%s)"
			% [_line_of(text, found.get_start()), quoted, said, key])
	print("")
	if drifted.is_empty():
		print("front page: every measured figure agrees with %s." % RECORD_FILE)
		return
	print("front page: %d figure(s) in %s disagree with the tree:" % [drifted.size(), RECORD_FILE])
	for line: String in drifted:
		print(line)
	print("Move the literal by hand, having run the reading half in an isolated worktree.")


## Which line of a text an offset falls on, 1-based - so the report names a line somebody can go to.
func _line_of(text: String, offset: int) -> int:
	return text.left(offset).count("\n") + 1


## A count as the front page writes one: grouped in threes, because that is how every number in
## those sentences is spelled and a comparison against `1045` would report drift that is not there.
func _thousands(value: int) -> String:
	var digits: String = str(absi(value))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = ",%s%s" % [digits.substr(digits.length() - 3), grouped]
		digits = digits.left(digits.length() - 3)
	grouped = "%s%s" % [digits, grouped]
	return "-%s" % grouped if value < 0 else grouped


## A share to one decimal place, never rounded up past what was measured, because a share the tree
## does not have is the one thing this must not print. Printed, and checked against nothing - see
## the header on the drawing question and the naming one.
func _one_decimal(value: float) -> String:
	return "%.1f" % (floorf(value * 10.0) / 10.0)


## Every .gd under a folder, sorted. Sorted rather than walked-and-printed, so the count and the
## percentage are the same on NTFS (near-alphabetical) and on ext4 (hash order).
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
				pending.append(directory_path.path_join(name) + "/")
		for name: String in directory.get_files():
			if name.ends_with(".gd"):
				found.append(directory_path.path_join(name))
	found.sort()
	return found
