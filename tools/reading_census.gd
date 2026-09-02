# Godot EventSheets - HOW MUCH OF THE TWO READING FILES RE-SAYS THE DESCRIPTOR (dev tool).
#
# `viewport_row_builder.gd` and `sentence_grammar.gd` are the two largest hand-written files in the
# tree. The standing claim about them is that a lot of both re-says what the ACE descriptor already
# says - the display words, the parameter hints, the object word - and that the generic assembly
# could draw those rows on its own. That claim has never been measured. This tool measures it.
#
# WHAT IT ANSWERS, in the order it prints them:
#
#   ROWS BY PATH. Every reading of the whole population (`tools/reading_dump.gd`'s population: every
#   builtin descriptor filled with its defaults, plus every row of every sheet under the showcases
#   and the shipped packs) classified by the path that shaped it - the generic assembly alone, the
#   shared grammar, a derived layer, a named per-vocabulary branch, verbatim code, or the chrome that
#   is not a reading of a verb at all. The classification is `tools/reading_lines.gd`'s and is asked
#   of the real readers.
#
#   THE ANATOMY. Both files broken down by what their functions hold: the ones a reading can reach,
#   the ones only a test names, the ones nothing names at all, and - inside the reachable half - the
#   `ace_id` match arms, which are the per-vocabulary special-casing at the grain somebody would
#   actually delete it at. A match arm is a BLOCK: it goes whole or it stays.
#
#   THE DERIVABLE SHARE. For every ACE cell the generic assembly is built beside the real one and the
#   two are compared - same base text, same object word. A cell the generic assembly reproduces is a
#   cell whose branch said nothing the descriptor did not already say. Reported as a share of cells,
#   and then as LINES: the arms every one of whose cells is reproduced.
#
#   THE SAMPLE. Thirty of those comparisons printed in full, so the share above is a number somebody
#   can check rather than take. Chosen by an even stride through the sorted population, which is
#   deterministic and is not the tool picking its own evidence.
#
#   THE PROJECTION. What wave 5 can expect: the lines held by arms that are wholly reproduced, with a
#   band for the arms whose evidence is thin, and the order to take the families in. An arm no row in
#   the population reached is reported apart and counted in NEITHER figure - nothing was measured
#   about it, and a projection that quietly assumed it would delete cleanly is how a projection loses.
#
# HOW REACH IS DECIDED: STATICALLY, by name. A function is reachable when the shipped plugin names it
# anywhere outside its own file, or when a function that is reachable names it inside the file. That
# is an over-estimate of reach on purpose - it can call a function reachable that no row ever runs -
# so the "named by nothing" list it produces is a strict UNDER-estimate of what is dead. An
# under-estimate is the safe direction for a list somebody is going to delete from.
#
# USAGE
#   "$GODOT" --headless --path . --script tools/reading_census.gd
#   "$GODOT" --headless --path . --script tools/reading_census.gd -- out=user://census.txt
#   "$GODOT" --headless --path . --script tools/reading_census.gd -- only=builtin
#
#   out=    write the report to a file instead of stdout
#   only=   `builtin`, `sheets`, or `all` (the default) - the same population switch the dump takes
#   sample= how many bespoke comparisons to print in full (default 30)
#
# The whole population takes a few minutes: it opens every showcase and every pack as a sheet and
# builds every row of each. `only=builtin` answers in seconds and is the loop to iterate in.
@tool
extends SceneTree

const LINES := preload("res://tools/reading_lines.gd")

## How many bespoke comparisons are printed in full unless a run says otherwise. Thirty is the size
## a person can actually read, which is the whole point of printing them.
const DEFAULT_SAMPLE: int = 30

## The two files the anatomy is about.
const READING_FILES: Array[String] = [
	"res://addons/eventsheet/editor/interaction/viewport_row_builder.gd",
	"res://addons/eventsheet/editor/interaction/sentence_grammar.gd",
]

## Where a name has to appear for the function it names to count as reachable by the shipped plugin.
const PLUGIN_ROOTS: Array[String] = ["res://addons/"]

## Where a name appearing means only a test or a tool knows about it - which is a different fact and
## is reported as one.
const HARNESS_ROOTS: Array[String] = ["res://tests/", "res://tools/"]

## How few cells an arm may be judged on before its lines go into the projection's BAND rather than
## its figure. Two rows agreeing is a coincidence; three is a small piece of evidence.
const THIN_EVIDENCE: int = 3


func _init() -> void:
	var output_path: String = ""
	var only: String = "all"
	var sample: int = DEFAULT_SAMPLE
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			output_path = argument.trim_prefix("out=")
		elif argument.begins_with("only="):
			only = argument.trim_prefix("only=")
		elif argument.begins_with("sample="):
			sample = maxi(int(argument.trim_prefix("sample=")), 0)
	var readings: Array = []
	if only != "sheets":
		readings.append_array(LINES.builtin_readings())
	var unreadable: PackedStringArray = PackedStringArray()
	if only != "builtin":
		readings.append_array(LINES.folder_readings(
			PackedStringArray(["res://demo/showcase/", "res://eventsheet_addons/"]), unreadable))
	var report: String = _report(readings, unreadable, sample)
	if output_path.is_empty():
		print(report)
		quit(0)
		return
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		print("could not write %s" % output_path)
		quit(1)
		return
	file.store_string(report)
	file.close()
	print("written=%s" % output_path)
	quit(0)


## The whole report as one text.
func _report(readings: Array, unreadable: PackedStringArray, sample: int) -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("reading census - format %d" % LINES.FORMAT_VERSION)
	out.append("")
	out.append_array(_population_lines(readings, unreadable))
	out.append("")
	out.append_array(_path_lines(readings))
	out.append("")
	out.append_array(_branch_lines(readings))
	out.append("")
	out.append_array(_anatomy_lines())
	out.append("")
	out.append_array(_derivable_lines(readings))
	out.append("")
	out.append_array(_sample_lines(readings, sample))
	out.append("")
	out.append_array(_projection_lines(readings))
	return "\n".join(out) + "\n"


# ── the population and the paths ────────────────────────────────────────────────


## What was read, and what could not be.
func _population_lines(readings: Array, unreadable: PackedStringArray) -> PackedStringArray:
	var builtin: int = 0
	for entry: Variant in readings:
		if (entry as LINES.Reading).origin.begins_with("builtin::"):
			builtin += 1
	var out: PackedStringArray = PackedStringArray()
	out.append("POPULATION")
	out.append("  cells from builtin descriptors   %d" % builtin)
	out.append("  cells from opened sheets         %d" % (readings.size() - builtin))
	out.append("  cells in all                     %d" % readings.size())
	out.append("  files that do not open as sheets %d" % unreadable.size())
	for path: String in unreadable:
		out.append("    %s" % path)
	return out


## Rows by the path that shaped them, counted and shared.
func _path_lines(readings: Array) -> PackedStringArray:
	var counts: Dictionary = {}
	for entry: Variant in readings:
		var path: int = (entry as LINES.Reading).path
		counts[path] = int(counts.get(path, 0)) + 1
	var out: PackedStringArray = PackedStringArray(["ROWS BY PATH"])
	for index: int in range(LINES.PATH_NAMES.size()):
		out.append("  %-10s %7d  %s" % [LINES.PATH_NAMES[index], int(counts.get(index, 0)),
			_share(int(counts.get(index, 0)), readings.size())])
	return out


## The branches that answered, most-taken first. The tail is counted rather than listed, for the same
## reason every band here is: a list of four hundred branches is a list nobody reads.
func _branch_lines(readings: Array) -> PackedStringArray:
	var counts: Dictionary = {}
	for entry: Variant in readings:
		var reading: LINES.Reading = entry as LINES.Reading
		if reading.branch.is_empty():
			continue
		var key: String = reading.path_text()
		counts[key] = int(counts.get(key, 0)) + 1
	var ranked: Array = _ranked(counts)
	var out: PackedStringArray = PackedStringArray(["BRANCHES THAT ANSWERED  (%d in all)" % ranked.size()])
	var shown: int = mini(25, ranked.size())
	for index: int in range(shown):
		var pair: Array = ranked[index] as Array
		out.append("  %7d  %s" % [int(pair[1]), str(pair[0])])
	if ranked.size() > shown:
		var rest: int = 0
		for index: int in range(shown, ranked.size()):
			rest += int((ranked[index] as Array)[1])
		out.append("  %7d  ... over %d more branches" % [rest, ranked.size() - shown])
	return out


# ── the anatomy of the two files ────────────────────────────────────────────────


## Both reading files by what their functions hold.
func _anatomy_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray(["ANATOMY OF THE TWO READING FILES"])
	var used: Dictionary = _names_used(PLUGIN_ROOTS, READING_FILES)
	var harness: Dictionary = _names_used(HARNESS_ROOTS, READING_FILES)
	for path: String in READING_FILES:
		# The two measured files call EACH OTHER, so the sweep above - which skips both, to keep a
		# file's own internal calls out of its seed set - has to be given back the OTHER one's names
		# before this file's reach is worked out. Without that, everything the row builder reaches in
		# the grammar reads as named by nothing.
		var seeds: Dictionary = used.duplicate()
		for other: String in READING_FILES:
			if other == path:
				continue
			for name: Variant in _called_names(FileAccess.get_file_as_string(other)).keys():
				seeds[name] = true
		var functions: Array = functions_of(path)
		var reach: Dictionary = _reach(path, functions, seeds)
		var total: int = 0
		var reached_lines: int = 0
		var harness_lines: int = 0
		var dead_lines: int = 0
		var harness_count: int = 0
		var dead: Array = []
		for entry: Variant in functions:
			var function: Dictionary = entry as Dictionary
			var held: int = int(function.get("lines", 0))
			total += held
			if bool(reach.get(str(function.get("name", "")), false)):
				reached_lines += held
			elif harness.has(str(function.get("name", ""))):
				harness_lines += held
				harness_count += 1
			else:
				dead_lines += held
				dead.append(function)
		var arms: Array = LINES.arms_of(path)
		var arm_lines: int = 0
		for arm: Variant in arms:
			arm_lines += int((arm as Dictionary).get("lines", 0))
		var dispatch: Array = LINES.arms_of(path, false)
		var dispatch_lines: int = 0
		for arm: Variant in dispatch:
			dispatch_lines += int((arm as Dictionary).get("lines", 0))
		out.append("  %s" % path.get_file())
		out.append("    file                     %6d lines" % _line_count(path))
		out.append("    functions                %6d  holding %d lines" % [functions.size(), total])
		out.append("    reachable from the plugin%6d lines" % reached_lines)
		out.append("    named only by a harness  %6d lines over %d function(s)" % [harness_lines,
			harness_count])
		out.append("    named by nothing         %6d lines over %d function(s)" % [dead_lines,
			dead.size()])
		for entry: Variant in dead:
			var function: Dictionary = entry as Dictionary
			out.append("      %s  (%d lines, from line %d)" % [str(function.get("name", "")),
				int(function.get("lines", 0)), int(function.get("line", 0))])
		out.append("    ace_id match arms        %6d lines over %d arm(s)" % [arm_lines, arms.size()])
		out.append("    all name-dispatch arms   %6d lines over %d arm(s)  %s of the file" % [
			dispatch_lines, dispatch.size(), _share(dispatch_lines, _line_count(path))])
		# What is left once the per-vocabulary dispatch is taken out: the bands, the region heads, the
		# extents walk, the operators and the wraps. The true grammar of the canvas, which no
		# descriptor can say anything about and which no deletion of vocabulary branches touches.
		out.append("    structure and grammar    %6d lines  %s of the file" % [
			reached_lines - dispatch_lines, _share(reached_lines - dispatch_lines,
			_line_count(path))])
	return out


## Every top-level function one file declares, as {"name", "line", "lines"}. `lines` counts the
## declaration through the last line before the next top-level declaration, blank tail trimmed - the
## block a maintainer would remove, which is the unit the projection is priced in.
static func functions_of(script_path: String) -> Array:
	var source: String = FileAccess.get_file_as_string(script_path)
	return functions_in(source)


## The same, over a buffer, so a test pins it without a file.
##
## TOP-LEVEL functions only. A function declared inside an inner `class` is indented and belongs to
## that class, which is a block of its own and is not something a reading reaches by name.
static func functions_in(source: String) -> Array:
	var lines: PackedStringArray = source.split("\n")
	var found: Array = []
	var open_function: Dictionary = {}
	var last_body: int = 0
	var in_header: bool = false
	for index: int in range(lines.size()):
		var line: String = lines[index]
		# A SIGNATURE THAT SPANS LINES ends with its own `) -> Type:` at column zero, which reads
		# exactly like the next top-level declaration and would otherwise close the function before
		# its body began - reporting an eight-line block for a two-hundred-line one, and cutting
		# everything it calls out of the reach walk. The header runs until a line ends the way a
		# header ends.
		if in_header:
			last_body = index + 1
			in_header = not line.strip_edges().ends_with(":")
			continue
		if line.is_empty() or line.begins_with("\t") or line.begins_with(" "):
			# The BODY, which is what a function's line count is nearly all of. Tracked here rather
			# than at the top-level lines below, where the walk only ever sees the boundaries.
			if not line.strip_edges().is_empty():
				last_body = index + 1
			continue
		if not open_function.is_empty():
			open_function["lines"] = last_body - int(open_function.get("line", index)) + 1
			found.append(open_function)
			open_function = {}
		if line.begins_with("func ") or line.begins_with("static func "):
			open_function = {"name": _declared_name(line), "line": index + 1, "lines": 1}
			last_body = index + 1
			in_header = not line.strip_edges().ends_with(":")
	if not open_function.is_empty():
		open_function["lines"] = last_body - int(open_function.get("line", lines.size())) + 1
		found.append(open_function)
	return found


## The name a `func` line declares.
static func _declared_name(line: String) -> String:
	var head: String = line.trim_prefix("static ").trim_prefix("func ")
	var open_at: int = head.find("(")
	return head.substr(0, open_at).strip_edges() if open_at > 0 else head.strip_edges()


## Which of one file's functions the plugin can reach: the ones something outside the file names,
## plus everything those name inside it, to a fixed point.
static func _reach(script_path: String, functions: Array, used_elsewhere: Dictionary) -> Dictionary:
	var bodies: Dictionary = _bodies_of(script_path, functions)
	var reached: Dictionary = {}
	var pending: PackedStringArray = PackedStringArray()
	for entry: Variant in functions:
		var name: String = str((entry as Dictionary).get("name", ""))
		if used_elsewhere.has(name):
			reached[name] = true
			pending.append(name)
	while not pending.is_empty():
		var name: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for called: String in PackedStringArray(bodies.get(name, PackedStringArray())):
			if reached.has(called) or not bodies.has(called):
				continue
			reached[called] = true
			pending.append(called)
	return reached


## Each function's body reduced to the names it calls, keyed by function name.
static func _bodies_of(script_path: String, functions: Array) -> Dictionary:
	var lines: PackedStringArray = FileAccess.get_file_as_string(script_path).split("\n")
	var declared: Dictionary = {}
	for entry: Variant in functions:
		declared[str((entry as Dictionary).get("name", ""))] = true
	var bodies: Dictionary = {}
	for entry: Variant in functions:
		var function: Dictionary = entry as Dictionary
		var start: int = int(function.get("line", 1))
		var held: int = int(function.get("lines", 1))
		var body: String = "\n".join(lines.slice(start, mini(start + held - 1, lines.size())))
		var calls: PackedStringArray = PackedStringArray()
		for name: String in _called_names(body).keys():
			if declared.has(name):
				calls.append(name)
		bodies[str(function.get("name", ""))] = calls
	return bodies


## Every identifier used as a call in a buffer, as a set.
static func _called_names(source: String) -> Dictionary:
	var found: Dictionary = {}
	var matcher: RegEx = _call_regex()
	for hit: RegExMatch in matcher.search_all(source):
		found[hit.get_string(1)] = true
	return found

static var _call_matcher: RegEx = null


## The one compiled matcher for a call, shared by every walk here.
static func _call_regex() -> RegEx:
	if _call_matcher == null:
		_call_matcher = RegEx.new()
		_call_matcher.compile("([A-Za-z_][A-Za-z0-9_]*)\\s*\\(")
	return _call_matcher


## Every name called anywhere under the given roots, skipping the files being measured. One pass over
## the tree, so the reach walk above is a dictionary lookup rather than a search.
static func _names_used(roots: Array[String], skip: Array[String]) -> Dictionary:
	var found: Dictionary = {}
	for root: String in roots:
		for path: String in LINES.scripts_under(root):
			if skip.has(path):
				continue
			for name: Variant in _called_names(FileAccess.get_file_as_string(path)).keys():
				found[name] = true
	return found


## How many lines a file holds, counted the way the maintainability ledger counts them: a file's
## closing newline ends its last line rather than opening another one.
static func _line_count(script_path: String) -> int:
	var source: String = FileAccess.get_file_as_string(script_path)
	var held: int = source.split("\n").size()
	return held - 1 if source.ends_with("\n") else held


# ── the derivable share ─────────────────────────────────────────────────────────


## What the generic assembly reproduces, as cells and then as lines.
func _derivable_lines(readings: Array) -> PackedStringArray:
	var ace_cells: int = 0
	var derivable: int = 0
	var by_path: Dictionary = {}
	var derivable_by_path: Dictionary = {}
	for entry: Variant in readings:
		var reading: LINES.Reading = entry as LINES.Reading
		if reading.ace_key.is_empty():
			continue
		ace_cells += 1
		by_path[reading.path] = int(by_path.get(reading.path, 0)) + 1
		if reading.is_derivable():
			derivable += 1
			derivable_by_path[reading.path] = int(derivable_by_path.get(reading.path, 0)) + 1
	var shaped: int = ace_cells - int(by_path.get(LINES.Path.TEMPLATE, 0))
	var shaped_derivable: int = derivable - int(derivable_by_path.get(LINES.Path.TEMPLATE, 0))
	var out: PackedStringArray = PackedStringArray(["THE DERIVABLE SHARE"])
	out.append("  ACE cells                          %7d" % ace_cells)
	out.append("  reproduced by the generic assembly %7d  %s" % [derivable,
		_share(derivable, ace_cells)])
	# THE HEADLINE. The share above counts the cells the generic assembly already draws, where the
	# answer is trivially yes. The question the census exists to answer is about the OTHER cells: of
	# the ones a branch shaped, how many would the descriptor have said the same way?
	out.append("  of the cells a BRANCH shaped       %7d of %d  %s" % [shaped_derivable, shaped,
		_share(shaped_derivable, shaped)])
	for index: int in range(LINES.PATH_NAMES.size()):
		var held: int = int(by_path.get(index, 0))
		if held == 0:
			continue
		out.append("    %-10s %7d of %7d  %s" % [LINES.PATH_NAMES[index],
			int(derivable_by_path.get(index, 0)), held,
			_share(int(derivable_by_path.get(index, 0)), held)])
	return out


## Thirty comparisons printed in full: the reading the builder produced, and the reading the generic
## assembly would have produced for the same row. An even stride through the sorted population, so
## the sample is the population's own and not this tool's choice of evidence.
func _sample_lines(readings: Array, sample: int) -> PackedStringArray:
	var candidates: Array = []
	for entry: Variant in readings:
		var reading: LINES.Reading = entry as LINES.Reading
		if reading.ace_key.is_empty() or reading.path == LINES.Path.TEMPLATE:
			continue
		candidates.append(reading)
	candidates.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (a as LINES.Reading).origin < (b as LINES.Reading).origin)
	var out: PackedStringArray = PackedStringArray([
		"THE SAMPLE  (%d of %d cells a branch shaped, by an even stride)" % [
			mini(sample, candidates.size()), candidates.size()]])
	if candidates.is_empty() or sample <= 0:
		return out
	var stride: int = maxi(candidates.size() / maxi(sample, 1), 1)
	var taken: int = 0
	var index: int = 0
	while index < candidates.size() and taken < sample:
		var reading: LINES.Reading = candidates[index] as LINES.Reading
		out.append("  %s  [%s]" % [reading.origin, reading.path_text()])
		out.append("    built   %s ▸ %s" % [reading.actual_object, reading.actual])
		out.append("    generic %s ▸ %s" % [reading.generic_object, reading.generic])
		out.append("    %s" % ("SAME - the branch says nothing the descriptor did not"
			if reading.is_derivable() else "DIFFERS - the branch is the only thing that says this"))
		taken += 1
		index += stride
	return out


# ── the projection ──────────────────────────────────────────────────────────────


## What wave 5 can expect, priced in whole match arms.
func _projection_lines(readings: Array) -> PackedStringArray:
	var visited: Dictionary = {}
	var clean: Dictionary = {}
	for entry: Variant in readings:
		var reading: LINES.Reading = entry as LINES.Reading
		if reading.branch.is_empty() or reading.ace_key.is_empty():
			continue
		visited[reading.branch] = int(visited.get(reading.branch, 0)) + 1
		if reading.is_derivable():
			clean[reading.branch] = int(clean.get(reading.branch, 0)) + 1
	var out: PackedStringArray = PackedStringArray(["THE WAVE-5 PROJECTION"])
	var totals: Dictionary = {"visited_arms": 0, "visited_lines": 0, "clean_arms": 0,
		"clean_lines": 0, "thin_lines": 0, "unvisited_arms": 0, "unvisited_lines": 0}
	var families: Array = []
	for path: String in READING_FILES:
		for arm_entry: Variant in LINES.arms_of(path):
			var arm: Dictionary = arm_entry as Dictionary
			var ids: PackedStringArray = PackedStringArray(arm.get("ids", PackedStringArray()))
			var held: int = int(arm.get("lines", 0))
			var seen: int = 0
			var reproduced: int = 0
			for identifier: String in ids:
				seen += int(visited.get(identifier, 0))
				reproduced += int(clean.get(identifier, 0))
			if seen == 0:
				totals["unvisited_arms"] = int(totals["unvisited_arms"]) + 1
				totals["unvisited_lines"] = int(totals["unvisited_lines"]) + held
				continue
			totals["visited_arms"] = int(totals["visited_arms"]) + 1
			totals["visited_lines"] = int(totals["visited_lines"]) + held
			if reproduced < seen:
				continue
			totals["clean_arms"] = int(totals["clean_arms"]) + 1
			totals["clean_lines"] = int(totals["clean_lines"]) + held
			if seen < THIN_EVIDENCE:
				totals["thin_lines"] = int(totals["thin_lines"]) + held
			families.append([path.get_file(), ", ".join(ids), held, seen])
	out.append("  arms a cell reached        %4d arms / %5d lines" % [int(totals["visited_arms"]),
		int(totals["visited_lines"])])
	out.append("  of those, wholly reproduced%4d arms / %5d lines  %s absorption" % [
		int(totals["clean_arms"]), int(totals["clean_lines"]),
		_share(int(totals["clean_lines"]), int(totals["visited_lines"]))])
	out.append("  arms no cell reached       %4d arms / %5d lines  (nothing measured - not projected)"
		% [int(totals["unvisited_arms"]), int(totals["unvisited_lines"])])
	out.append("  PROJECTION                 %5d lines, band -%d (the arms judged on fewer than %d cells)"
		% [int(totals["clean_lines"]), int(totals["thin_lines"]), THIN_EVIDENCE])
	families.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left: Array = a as Array
		var right: Array = b as Array
		return int(left[2]) > int(right[2]) if int(left[2]) != int(right[2]) else str(left[1]) < str(right[1]))
	out.append("  the order to take them in, largest first:")
	for index: int in range(mini(20, families.size())):
		var family: Array = families[index] as Array
		out.append("    %5d lines  %-24s %s  (%d cells)" % [int(family[2]), str(family[0]),
			str(family[1]), int(family[3])])
	if families.size() > 20:
		out.append("    ... and %d more" % (families.size() - 20))
	return out


# ── shared spelling ─────────────────────────────────────────────────────────────


## A share as a percentage, said the one way so two lines of this report can be compared.
func _share(part: int, whole: int) -> String:
	if whole <= 0:
		return "(nothing to share)"
	return "%5.1f%%" % (100.0 * float(part) / float(whole))


## A count dictionary as [key, count] pairs, biggest first, ties broken on the key so two runs rank
## them the same way.
func _ranked(counts: Dictionary) -> Array:
	var pairs: Array = []
	for key: Variant in counts.keys():
		pairs.append([str(key), int(counts[key])])
	pairs.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left: Array = a as Array
		var right: Array = b as Array
		return int(left[1]) > int(right[1]) if int(left[1]) != int(right[1]) else str(left[0]) < str(right[0]))
	return pairs
