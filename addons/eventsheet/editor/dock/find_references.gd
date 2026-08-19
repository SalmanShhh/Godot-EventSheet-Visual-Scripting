# EventSheet - symbol-aware Find References / Go-to-Definition.
#
# Project Find matches substrings; this matches whole symbols (\bname\b), so searching
# `speed` finds the variable `speed` but NOT `move_speed` or the word "speed" mid-identifier.
# It tags each hit with the surface it lives in (param / code / pick / comment / group), and
# can resolve a symbol's DEFINITION (a sheet variable, function, signal, or local var). The
# same walk backs a rename PREVIEW, so a project-wide rename shows what it will touch first.
@tool
class_name EventSheetFindReferences
extends RefCounted


## Whole-symbol references to `symbol` in one sheet: [{kind, count, preview}].
static func find_in_sheet(sheet: EventSheetResource, symbol: String) -> Array:
	var results: Array = []
	if sheet == null or symbol.strip_edges().is_empty():
		return results
	var regex: RegEx = RegEx.create_from_string("\\b%s\\b" % _escape(symbol.strip_edges()))
	if regex == null:
		return results
	var fragments: Array = []
	_collect(sheet.events, fragments)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, fragments)
	for fragment: Dictionary in fragments:
		var hits: Array = regex.search_all(str(fragment.get("text", "")))
		if not hits.is_empty():
			results.append({
				"kind": str(fragment.get("kind", "")),
				"count": hits.size(),
				# The ROW the hit sits on, so a Find result can jump to it. Additive: callers that
				# only read kind/count/preview are untouched.
				"row": fragment.get("row", null),
				"preview": _preview(str(fragment.get("text", "")), (hits[0] as RegExMatch).get_start())
			})
	return results


## Project-wide references grouped by sheet, for the Find results bar: [{sheet, count,
## references}] where every reference also carries the ROW resource it sits on, so clicking a
## result can jump to it. `extra_sheets` is {path: EventSheetResource} for sheets the project scan
## cannot see by itself - the open tabs, which in a .gd project is most of them.
static func find_in_project_rows(symbol: String, extra_sheets: Dictionary = {}) -> Array:
	var found: Array = []
	var seen: Dictionary = {}
	for path: Variant in extra_sheets.keys():
		var open_sheet: EventSheetResource = extra_sheets[path] as EventSheetResource
		if open_sheet == null:
			continue
		seen[str(path)] = true
		var open_references: Array = find_in_sheet(open_sheet, symbol)
		if not open_references.is_empty():
			stamp_source_lines(open_sheet, open_references)
			found.append({"sheet": str(path), "count": _total_of(open_references), "references": open_references})
	for path: String in EventSheetProjectFind.list_project_sheets():
		if seen.has(path):
			continue
		seen[path] = true
		var sheet: EventSheetResource = load(path) as EventSheetResource
		if sheet == null:
			continue
		var references: Array = find_in_sheet(sheet, symbol)
		if not references.is_empty():
			stamp_source_lines(sheet, references)
			found.append({"sheet": path, "count": _total_of(references), "references": references})
	# The `.gd` sheets nobody has opened. `list_project_sheets()` only knows `.tres`, but `.gd` is the
	# DEFAULT sheet format - so without this pass Find all references was blind to most of a real
	# project and quietly answered "3 sheets" when the truth was thirty.
	found.append_array(_find_in_unopened_scripts(symbol, seen))
	return found


## References in project `.gd` files that are not already accounted for. Two passes on purpose,
## because the expensive half must only run where there is something to find:
##
##  1. a TEXT scan of every project script (a few milliseconds each, no `load`, no parse) drops every
##     file that does not contain the symbol as a whole word - which is nearly all of them;
##  2. only the survivors are imported, and only through the importer's RAW pass (`lift = false`).
##     That is the same fast half the async open job runs first - tens of milliseconds against the
##     seconds a full lift costs - and it is all this needs: a raw sheet still carries every line as
##     a row, so the walk finds the symbol and a result still has a row to jump to.
##
## `seen` is updated in place, so a path counted here is never counted twice.
static func _find_in_unopened_scripts(symbol: String, seen: Dictionary) -> Array:
	var found: Array = []
	var wanted: String = symbol.strip_edges()
	if wanted.is_empty():
		return found
	var regex: RegEx = RegEx.create_from_string("\\b%s\\b" % _escape(wanted))
	if regex == null:
		return found
	var importer: GDScriptImporter = GDScriptImporter.new()
	for path: String in project_scripts():
		if seen.has(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		if source.is_empty() or regex.search(source) == null:
			continue
		seen[path] = true
		var sheet: EventSheetResource = importer.import_external(path, false)
		if sheet == null:
			continue
		var references: Array = find_in_sheet(sheet, wanted)
		if not references.is_empty():
			stamp_source_lines(sheet, references)
			found.append({"sheet": path, "count": _total_of(references), "references": references})
	return found


## Every `.gd` in the project that could be a sheet, sorted so two runs list the same files in the
## same order. Plugin code and the import cache are skipped: `res://addons` is this plugin and other
## people's plugins, and neither is a sheet the reader wrote.
static func project_scripts(root: String = "res://") -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var current: String = directories.pop_back()
		if current.begins_with("res://addons"):
			continue
		var dir: DirAccess = DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			var entry_path: String = current.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					directories.append(entry_path)
			elif entry.get_extension() == "gd":
				found.append(entry_path)
			entry = dir.get_next()
		dir.list_dir_end()
	found.sort()
	return found


## The sheets already open in tabs, as {path: EventSheetResource}. They are the LIVE version of their
## files - a reference to something typed a second ago exists only in memory - so every project-wide
## walk starts from them. One door, because the Find results bar and the Find references window
## asking the same question two different ways is how they came to disagree in the first place.
static func open_sheets_of(dock: Control) -> Dictionary:
	var open_sheets: Dictionary = {}
	if dock == null:
		return open_sheets
	for tab: Variant in dock._open_tabs:
		if not (tab is Dictionary):
			continue
		var path: String = str((tab as Dictionary).get("path", ""))
		var sheet: EventSheetResource = (tab as Dictionary).get("sheet") as EventSheetResource
		if sheet == null:
			continue
		# A `.gd` opened as a sheet has no tab path - the file it came from is on the sheet itself.
		if path.is_empty():
			path = sheet.external_source_path
		if not path.is_empty():
			open_sheets[path] = sheet
	if dock._current_sheet != null:
		var current_path: String = dock._current_sheet_path
		if current_path.is_empty():
			current_path = dock._current_sheet.external_source_path
		if not current_path.is_empty():
			open_sheets[current_path] = dock._current_sheet
	return open_sheets


## Stamps each reference with the LINE its row emits at, so a cross-sheet jump can land on the exact
## row after the sheet opens.
##
## The row resource itself cannot survive that jump: opening a sheet builds a brand new resource
## tree, so the row found here and the row in the opened tab are different objects and matching by
## identity would silently land on nothing. A line number survives, because an opened file re-emits
## byte-identically - line N of what this sheet compiles to is line N of the file the reader will be
## looking at - and the editor already knows how to select the row a line belongs to.
##
## One compile per sheet that actually has a hit, which is the only place the cost is worth paying.
## Best effort throughout: a sheet that does not compile simply gets no line, and the jump falls back
## to opening the sheet, which is what it did before.
static func stamp_source_lines(sheet: EventSheetResource, references: Array) -> void:
	if sheet == null or references.is_empty():
		return
	var source_map: Array = SheetCompiler.compile(sheet, "").get("source_map", []) as Array
	if source_map.is_empty():
		return
	for reference: Dictionary in references:
		var row: Variant = reference.get("row", null)
		if not (row is Resource):
			continue
		var span: Vector2i = EventSheetLineRowMapper.range_for_resource(source_map, row as Resource)
		if span.x > 0:
			reference["line"] = span.x


static func _total_of(references: Array) -> int:
	var total: int = 0
	for reference: Dictionary in references:
		total += int(reference.get("count", 0))
	return total


## Project-wide references: [{sheet, count, references}] for every sheet that uses `symbol`.
## `extra_sheets` is {path: EventSheetResource} for the sheets already open in tabs, which are the
## live versions of their files - a reference to something typed a second ago is only in memory.
## Now a thin alias of find_in_project_rows: the two doors answered different questions about the
## same project (one saw `.gd` files, the other did not), which is exactly the kind of difference
## nobody discovers until a rename misses half its uses.
static func find_in_project(symbol: String, extra_sheets: Dictionary = {}) -> Array:
	return find_in_project_rows(symbol, extra_sheets)


## Where `symbol` is DEFINED in this sheet: {kind, found}. kind ∈ variable / function /
## signal / local / "" (not defined here).
static func find_definition(sheet: EventSheetResource, symbol: String) -> Dictionary:
	if sheet == null:
		return {"kind": "", "found": false}
	var name: String = symbol.strip_edges()
	if sheet.variables.has(name):
		return {"kind": "variable", "found": true}
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == name:
			return {"kind": "function", "found": true}
	var definition: Dictionary = {"kind": "", "found": false}
	_scan_definitions(sheet.events, name, definition)
	return definition


## Validate + count: what a rename of `old_name`→`new_name` would touch, BEFORE applying.
## {valid, error, reference_count, references}.
static func rename_preview(sheet: EventSheetResource, old_name: String, new_name: String) -> Dictionary:
	var error: String = EventSheetRefactor.validate_new_name(sheet, old_name, new_name)
	var references: Array = find_in_sheet(sheet, old_name)
	var count: int = 0
	for reference: Dictionary in references:
		count += int(reference.get("count", 0))
	return {"valid": error.is_empty(), "error": error, "reference_count": count, "references": references}


static func _scan_definitions(rows: Array, name: String, into: Dictionary) -> void:
	for row: Variant in rows:
		if into.get("found", false):
			return
		if row is LocalVariable and (row as LocalVariable).name == name:
			into["kind"] = "local"
			into["found"] = true
			return
		elif row is SignalRow and (row as SignalRow).signal_name == name:
			into["kind"] = "signal"
			into["found"] = true
			return
		elif row is EventGroup:
			_scan_definitions((row as EventGroup).events if not (row as EventGroup).events.is_empty() else (row as EventGroup).rows, name, into)
		elif row is EventRow:
			_scan_definitions((row as EventRow).sub_events, name, into)


## Every findable text fragment of a sheet, tagged with its surface - the one walker anything that
## has to ask "what does this file actually SAY" shares, so a new question cannot be asked of a
## different set of rows than Find all references answers from.
static func text_fragments(sheet: EventSheetResource) -> Array:
	var fragments: Array = []
	if sheet == null:
		return fragments
	_collect(sheet.events, fragments)
	return fragments


## Findable text fragments tagged with their surface. Parallels project_find's collector but
## keeps the surface kind so references read "in a param" vs "in a comment".
static func _collect(rows: Array, into: Array) -> void:
	for row: Variant in rows:
		if row is CommentRow:
			into.append({"text": (row as CommentRow).text, "kind": "comment", "row": row})
		elif row is RawCodeRow:
			into.append({"text": (row as RawCodeRow).code, "kind": "code", "row": row})
		elif row is LocalVariable:
			into.append({"text": (row as LocalVariable).name, "kind": "local", "row": row})
		elif row is SignalRow:
			into.append({"text": (row as SignalRow).signal_name + " " + " ".join((row as SignalRow).params), "kind": "signal", "row": row})
		elif row is EventGroup:
			into.append({"text": (row as EventGroup).group_name, "kind": "group", "row": row})
			_collect((row as EventGroup).events if not (row as EventGroup).events.is_empty() else (row as EventGroup).rows, into)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			for ace: Variant in event_row.conditions + event_row.actions:
				if ace is RawCodeRow:
					into.append({"text": (ace as RawCodeRow).code, "kind": "code", "row": event_row})
				elif ace is Resource and ace.get("params") is Dictionary:
					if ace.get("comment") is String and not str(ace.get("comment")).is_empty():
						into.append({"text": str(ace.get("comment")), "kind": "comment", "row": event_row})
					for value: Variant in (ace.get("params") as Dictionary).values():
						if value is String:
							into.append({"text": value, "kind": "param", "row": event_row})
			for pick: Variant in event_row.pick_filters:
				if pick is PickFilter:
					into.append({"text": (pick as PickFilter).collection_value + " " + (pick as PickFilter).predicate_expression, "kind": "pick", "row": event_row})
			_collect(event_row.sub_events, into)


static func _preview(text: String, at: int) -> String:
	return text.substr(maxi(at - 18, 0), 62).replace("\n", " ").strip_edges()


## Identifiers are word chars only, but guard against regex metacharacters defensively.
static func _escape(symbol: String) -> String:
	var escaped: String = ""
	for character: String in symbol:
		if character.is_valid_identifier() or character.is_valid_int() or character == "_":
			escaped += character
		else:
			escaped += "\\" + character
	return escaped
