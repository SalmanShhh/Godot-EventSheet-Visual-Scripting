# Godot EventSheets - Tidy this script: the pure half.
#
# A script keeps the spelling it was written in. Opening it and saving it untouched writes the same bytes,
# and a row placed today writes a plainer line than the same row placed a year ago. Tidy is the one door that
# brings an older script up to today's spelling, and it only ever runs because the reader asked.
#
# What it turns on, per row, is the choice the row already has: a guard that wraps a float literal in a
# floor (`folds_literals`), a denial written `not x` for `not (x)` (`plain_negation`), the short loop-budget, filter and connect lines (`tidy_budget`, `filter_flipped`,
# `connect_short`), a member that leaves out the icon and category its class already says
# (`lean_annotations`), and, for the whole file, annotation words written as one-hash comments above the
# description (`annotation_spelling`). Nothing else about a row changes.
#
# IT CLAIMS ONLY WHAT IT CAN READ BACK. The plan is made on a copy of the sheet. The tidied text must open
# again as a sheet that writes the same bytes, and must parse as far as the original did; a change that fails
# either is left out and only counted. Every line that would change is listed before anything is written, and
# a second Tidy over the result finds nothing.
@tool
extends RefCounted

const LiteralFold := preload("res://addons/eventforge/compiler/literal_fold.gd")

## The per-row choices Tidy may turn on. Each is a saved field with an old-spelling default of false.
const FLAGS: Array[String] = ["folds_literals", "tidy_budget", "filter_flipped", "connect_short", "lean_annotations", "plain_negation"]

## The file-wide spelling Tidy moves to.
const ONE_HASH: String = "#"

## Where a probe compile and a reopen pretend the file lives. Nothing is ever written there.
const PROBE_PATH: String = "user://__tidy_probe.gd"

## Past this many differing lines the line diff gives up and the whole run is shown as one change.
const DIFF_LIMIT: int = 2500

static var _plain_path_re: RegEx = null


## What Tidy would do to `sheet`, worked out on a copy: nothing is touched. `reads_back` is optional: given, it
## replaces the check that a result opens again and parses (it is asked the text and answers a bool). Returns
##   "changes"   Array of {line, before, after}: every line that would be written differently ("" on one side
##               for a line that is only added or only removed)
##   "left"      how many lines would also change but are left as they are because the result could not be read back
##   "turned"    the indices (in walk order) of the rows whose choice is turned on
##   "spelling"  the file spelling to move to, or "" when it stays
##   "after"     the whole text Tidy would write
##   "unsure"    true when the sheet could not be planned at all (its copy does not write the same text)
static func plan(sheet: EventSheetResource, reads_back: Callable = Callable()) -> Dictionary:
	var result: Dictionary = {"changes": [], "left": 0, "turned": [], "spelling": "", "after": "", "unsure": false}
	if sheet == null:
		return result
	var before: String = _text(sheet)
	result["after"] = before
	if before.is_empty():
		return result
	var copy: EventSheetResource = _copy_of(sheet)
	if _text(copy) != before:
		result["unsure"] = true
		return result
	var wants_spelling: bool = _can_move_spelling(copy)
	var candidates: Array[Dictionary] = _candidates(copy)
	var active: Array[int] = []
	for index: int in candidates.size():
		if _worth_trying(copy, candidates[index]):
			active.append(index)
	if active.is_empty() and not wants_spelling:
		return result
	var parses_before: Array = [-1, before]
	# First, everything at once: when the whole result reads back, that is the answer.
	_turn(copy, candidates, active, wants_spelling, true)
	var everything: String = _text(copy)
	if everything == before:
		return result
	if _accepts(reads_back, everything, parses_before, sheet.external_source_path):
		var needed: Array[int] = _without_idle(copy, candidates, active, everything)
		result["after"] = everything
		result["turned"] = needed
		result["spelling"] = ONE_HASH if wants_spelling else ""
		result["changes"] = changed_lines(before, everything)
		return result
	# Otherwise one choice at a time, and only the ones that read back stay.
	_turn(copy, candidates, active, wants_spelling, false)
	var kept_text: String = before
	var kept: Array[int] = []
	var kept_spelling: bool = false
	var left: int = 0
	if wants_spelling:
		copy.annotation_spelling = ONE_HASH
		copy.annotation_words_first = true
		var spelled: String = _text(copy)
		if spelled != kept_text:
			if _accepts(reads_back, spelled, parses_before, sheet.external_source_path):
				kept_text = spelled
				kept_spelling = true
			else:
				left += changed_lines(kept_text, spelled).size()
				copy.annotation_spelling = sheet.annotation_spelling
				copy.annotation_words_first = false
	for index: int in active:
		var holder: Resource = candidates[index]["holder"]
		var flag: String = str(candidates[index]["flag"])
		holder.set(flag, true)
		var turned_text: String = _text(copy)
		if turned_text == kept_text:
			holder.set(flag, false)
			continue
		if _accepts(reads_back, turned_text, parses_before, sheet.external_source_path):
			kept_text = turned_text
			kept.append(index)
		else:
			left += changed_lines(kept_text, turned_text).size()
			holder.set(flag, false)
	result["left"] = left
	if kept_text == before:
		return result
	result["after"] = kept_text
	result["turned"] = kept
	result["spelling"] = ONE_HASH if kept_spelling else ""
	result["changes"] = changed_lines(before, kept_text)
	return result


## Turns on what `plan` said, in `sheet` itself, and returns how many rows were turned (a file spelling move
## counts as one). Call it inside the edit that makes the change undoable. `made` is a plan made on this very
## sheet; when the text the sheet now writes is not the text the plan promised, everything is put back and 0
## comes back, so what lands is never anything but what was shown.
static func apply(sheet: EventSheetResource, made: Dictionary) -> int:
	if sheet == null or (made.get("changes", []) as Array).is_empty():
		return 0
	var before_spelling: String = sheet.annotation_spelling
	var before_first: bool = sheet.annotation_words_first
	var candidates: Array[Dictionary] = _candidates(sheet)
	var turned: Array = made.get("turned", [])
	var done: int = 0
	for index: Variant in turned:
		if int(index) >= candidates.size():
			continue
		(candidates[int(index)]["holder"] as Resource).set(str(candidates[int(index)]["flag"]), true)
		done += 1
	if not str(made.get("spelling", "")).is_empty():
		sheet.annotation_spelling = str(made["spelling"])
		sheet.annotation_words_first = true
		done += 1
	if _text(sheet) != str(made.get("after", "")):
		for index: Variant in turned:
			if int(index) < candidates.size():
				(candidates[int(index)]["holder"] as Resource).set(str(candidates[int(index)]["flag"]), false)
		sheet.annotation_spelling = before_spelling
		sheet.annotation_words_first = before_first
		return 0
	return done


## The lines of a plan as the window and the tests read them: `before => after`, indentation dropped so a long
## line is read whole, and a line that is only added or only removed says so.
static func preview_lines(made: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in made.get("changes", []):
		var change: Dictionary = entry
		var before: String = str(change.get("before", "")).strip_edges()
		var after: String = str(change.get("after", "")).strip_edges()
		if before.is_empty() and not after.is_empty():
			before = EventSheetL10n.translate("(no line)")
		elif after.is_empty() and not before.is_empty():
			after = EventSheetL10n.translate("(line removed)")
		out.append("%s => %s" % [before, after])
	return out


# ── What a result has to survive ─────────────────────────────────────────────────────────────────


## The text `sheet` writes now, written nowhere.
static func _text(sheet: EventSheetResource) -> String:
	return str(EventSheetCompiler.echo(sheet).get("output", ""))


static func _copy_of(sheet: EventSheetResource) -> EventSheetResource:
	var copy: EventSheetResource = sheet.duplicate(true)
	copy.external_source_path = sheet.external_source_path
	return copy


## The question every result has to pass. `override` stands in for the real reading when a caller hands one
## (a test that needs a result to be refused); it is asked the text and answers a bool.
static func _accepts(override: Callable, text: String, original: Array, path: String) -> bool:
	if override.is_valid():
		return bool(override.call(text))
	return _reads_back(text, original, path)


## True when `text` opens as a sheet that writes the same bytes, and parses wherever the original did.
## `original` is [-1, the original text]: whether the original parses is only asked (and remembered in the
## first slot) when the new text does not, so a script that parses never makes Godot print an error.
static func _reads_back(text: String, original: Array, path: String) -> bool:
	var reopened: EventSheetResource = EventSheetGDScriptImporter.new().import_external_source(text, true, path)
	if reopened == null:
		return false
	reopened.external_source_path = path if not path.is_empty() else PROBE_PATH
	if _text(reopened) != text:
		return false
	if _parses(text, path):
		return true
	if int(original[0]) < 0:
		original[0] = 1 if _parses(str(original[1]), path) else 0
	return int(original[0]) == 0


## Whether the script parses on its own. The class_name line is left out: a second script claiming a name
## the project already holds is an error of its own, and says nothing about the lines Tidy touches. A
## script that extends another by a path beside it is given that path in full, since the probe has no file.
static func _parses(text: String, path: String) -> bool:
	var probe: GDScript = GDScript.new()
	var source: String = RegEx.create_from_string("(?m)^class_name\\s.*$").sub(text, "", true)
	if not path.is_empty() and path.contains("/"):
		var beside: RegEx = RegEx.create_from_string("(?m)^extends \"([^\"/:]+\\.gd)\"")
		source = beside.sub(source, "extends \"%s/$1\"" % path.get_base_dir(), true)
	probe.source_code = source
	return probe.reload(true) == OK


## A file read with two-hash annotation lines can move to one hash; a file that already writes one hash, or
## says nothing, has nowhere to go. A sheet with no annotation word at all is left alone.
static func _can_move_spelling(sheet: EventSheetResource) -> bool:
	if sheet.annotation_spelling != EventSheetAnnotationLine.TWO:
		return false
	return EventSheetAnnotationLine.spelling_of(_text(sheet)) == EventSheetAnnotationLine.TWO


# ── The rows that carry a choice ─────────────────────────────────────────────────────────────────


## Every saved resource under `sheet` that carries one of the choices at its old setting, in a walk order
## that is the same for a sheet and for its copy: {holder, flag}.
static func _candidates(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_walk(sheet, {}, found)
	return found


static func _walk(value: Variant, seen: Dictionary, found: Array[Dictionary]) -> void:
	if value is Array:
		for item: Variant in value:
			_walk(item, seen, found)
		return
	if not (value is Resource) or seen.has((value as Resource).get_instance_id()):
		return
	var holder: Resource = value
	seen[holder.get_instance_id()] = true
	for flag: String in FLAGS:
		if flag in holder and holder.get(flag) == false:
			found.append({"holder": holder, "flag": flag})
	for property: Dictionary in holder.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE != 0 and int(property["type"]) in [TYPE_OBJECT, TYPE_ARRAY]:
			_walk(holder.get(str(property["name"])), seen, found)


## Sets every choice in `active` to `on`, and the file spelling with it.
static func _turn(copy: EventSheetResource, candidates: Array[Dictionary], active: Array[int], spelling: bool, on: bool) -> void:
	for index: int in active:
		(candidates[index]["holder"] as Resource).set(str(candidates[index]["flag"]), on)
	if spelling:
		copy.annotation_spelling = ONE_HASH if on else EventSheetAnnotationLine.TWO
		copy.annotation_words_first = on


## Whether turning this one choice on could change a line, asked the cheap way where there is one: the
## literal fold and the member annotations are asked of the one row or function, the others of what the row
## holds. A yes is a maybe; the whole sheet's text settles it.
static func _worth_trying(sheet: EventSheetResource, candidate: Dictionary) -> bool:
	var holder: Resource = candidate["holder"]
	match str(candidate["flag"]):
		"folds_literals":
			var template: String = str(holder.get("codegen_template"))
			if template.is_empty():
				var descriptor: ACEDescriptor = ACERegistry.find_descriptor(str(holder.get("provider_id")), str(holder.get("ace_id")))
				template = descriptor.codegen_template if descriptor != null else ""
			var params: Dictionary = holder.get("params")
			return LiteralFold.fold_template(template, params) != template
		"lean_annotations":
			var event_function: EventFunction = holder as EventFunction
			var long_form: String = EventSheetCompiler.emit_function_block_text(event_function, sheet, true)
			event_function.lean_annotations = true
			var lean_form: String = EventSheetCompiler.emit_function_block_text(event_function, sheet, true)
			event_function.lean_annotations = false
			return long_form != lean_form
		"plain_negation":
			return bool(holder.get("negated"))
		"connect_short":
			return _plain_path().search(str(holder.get("trigger_source_path"))) != null
		"tidy_budget":
			return int(holder.get("frame_spread_count")) > 0 or float(holder.get("frame_spread_budget_ms")) > 0.0
		"filter_flipped":
			return not str(holder.get("predicate_expression")).strip_edges().is_empty() 				or not (holder.get("filter_conditions") as Array).is_empty()
	return true


static func _plain_path() -> RegEx:
	if _plain_path_re == null:
		_plain_path_re = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)*$")
	return _plain_path_re


## The choices of `active`, with the ones that turned out to change nothing left out (and turned back off).
## The literal fold and the member annotations were asked exactly already; the loop, filter and connect
## choices were only asked loosely, so each is turned off alone to see whether the text moves.
static func _without_idle(copy: EventSheetResource, candidates: Array[Dictionary], active: Array[int], everything: String) -> Array[int]:
	var needed: Array[int] = []
	for index: int in active:
		var flag: String = str(candidates[index]["flag"])
		if flag == "folds_literals" or flag == "lean_annotations":
			needed.append(index)
			continue
		var holder: Resource = candidates[index]["holder"]
		holder.set(flag, false)
		if _text(copy) == everything:
			continue
		holder.set(flag, true)
		needed.append(index)
	return needed


# ── The lines that differ ────────────────────────────────────────────────────────────────────────


## Every line `after` writes differently from `before`, as {line, before, after} in file order. A one-hash
## annotation word and the two-hash line it replaces are one change even where the word moved above the
## description.
static func changed_lines(before: String, after: String) -> Array:
	var left: PackedStringArray = before.split("\n")
	var right: PackedStringArray = after.split("\n")
	var start: int = 0
	while start < left.size() and start < right.size() and left[start] == right[start]:
		start += 1
	var tail: int = 0
	while tail < left.size() - start and tail < right.size() - start and left[left.size() - 1 - tail] == right[right.size() - 1 - tail]:
		tail += 1
	var middle_left: PackedStringArray = left.slice(start, left.size() - tail)
	var middle_right: PackedStringArray = right.slice(start, right.size() - tail)
	var kept: Array = _common(middle_left, middle_right)
	var removed: Array[Dictionary] = []
	var added: Array[Dictionary] = []
	for index: int in middle_left.size():
		if not (kept[0] as Dictionary).has(index):
			removed.append({"line": start + index + 1, "text": middle_left[index]})
	for index: int in middle_right.size():
		if not (kept[1] as Dictionary).has(index):
			added.append({"line": start + index + 1, "text": middle_right[index]})
	return _paired(removed, added)


## Which lines of each side the shortest edit keeps: [left index set, right index set]. When the edit is longer
## than DIFF_LIMIT, nothing is kept and the whole middle reads as one change.
static func _common(left: PackedStringArray, right: PackedStringArray) -> Array:
	var kept_left: Dictionary = {}
	var kept_right: Dictionary = {}
	var n: int = left.size()
	var m: int = right.size()
	if n == 0 or m == 0:
		return [kept_left, kept_right]
	var limit: int = mini(n + m, DIFF_LIMIT)
	var offset: int = limit + 1
	var frontier: PackedInt32Array = PackedInt32Array()
	frontier.resize(2 * limit + 3)
	var history: Array = []
	var found_at: int = -1
	for d: int in range(limit + 1):
		history.append(frontier.duplicate())
		for k: int in range(-d, d + 1, 2):
			var x: int
			if k == -d or (k != d and frontier[offset + k - 1] < frontier[offset + k + 1]):
				x = frontier[offset + k + 1]
			else:
				x = frontier[offset + k - 1] + 1
			var y: int = x - k
			while x < n and y < m and left[x] == right[y]:
				x += 1
				y += 1
			frontier[offset + k] = x
			if x >= n and y >= m:
				found_at = d
				break
		if found_at >= 0:
			break
	if found_at < 0:
		return [kept_left, kept_right]
	# Walk back from the end, keeping the diagonal runs.
	var x_end: int = n
	var y_end: int = m
	for d: int in range(found_at, -1, -1):
		var snapshot: PackedInt32Array = history[d]
		var k: int = x_end - y_end
		var previous_k: int
		if k == -d or (k != d and snapshot[offset + k - 1] < snapshot[offset + k + 1]):
			previous_k = k + 1
		else:
			previous_k = k - 1
		var previous_x: int = snapshot[offset + previous_k]
		var previous_y: int = previous_x - previous_k
		if d == 0:
			previous_x = 0
			previous_y = 0
		# The diagonal run that ended at (x_end, y_end) starts after the single step from the previous point.
		var step_x: int = previous_x
		var step_y: int = previous_y
		if d > 0:
			if previous_k == k + 1:
				step_y += 1
			else:
				step_x += 1
		while x_end > step_x and y_end > step_y:
			x_end -= 1
			y_end -= 1
			kept_left[x_end] = true
			kept_right[y_end] = true
		x_end = previous_x
		y_end = previous_y
	return [kept_left, kept_right]


## Removed and added lines paired into changes: a removed line and an added line that are the same words under
## the two spellings of an annotation go together; the rest pair off in order, and what has no partner stands
## alone.
static func _paired(removed: Array[Dictionary], added: Array[Dictionary]) -> Array:
	var partner: Dictionary = {}
	var taken: Dictionary = {}
	for r: int in removed.size():
		var key: String = _spelling_free(str(removed[r]["text"]))
		if not key.begins_with("@ace_"):
			continue
		for a: int in added.size():
			if not taken.has(a) and _spelling_free(str(added[a]["text"])) == key:
				partner[r] = a
				taken[a] = true
				break
	var out: Array = []
	var leftovers_removed: Array[Dictionary] = []
	var leftovers_added: Array[Dictionary] = []
	for a: int in added.size():
		if not taken.has(a):
			leftovers_added.append(added[a])
	for r: int in removed.size():
		if partner.has(r):
			out.append({"line": int(removed[r]["line"]), "before": str(removed[r]["text"]), "after": str(added[int(partner[r])]["text"])})
		else:
			leftovers_removed.append(removed[r])
	var pairs: int = maxi(leftovers_removed.size(), leftovers_added.size())
	for index: int in pairs:
		var from_removed: Dictionary = leftovers_removed[index] if index < leftovers_removed.size() else {}
		var from_added: Dictionary = leftovers_added[index] if index < leftovers_added.size() else {}
		out.append({
			"line": int(from_removed.get("line", from_added.get("line", 0))),
			"before": str(from_removed.get("text", "")),
			"after": str(from_added.get("text", "")),
		})
	out.sort_custom(func(left_change: Dictionary, right_change: Dictionary) -> bool:
		return int(left_change["line"]) < int(right_change["line"]))
	return out


## An annotation line without its marker, so `## @ace_name("A")` and `# @ace_name("A")` compare equal.
static func _spelling_free(line: String) -> String:
	var stripped: String = line.strip_edges()
	if stripped.begins_with("## "):
		return stripped.substr(3)
	if stripped.begins_with("# "):
		return stripped.substr(2)
	return stripped
