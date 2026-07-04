# Godot EventSheets - semantic 3-way git merge driver for sheets (.tres)
#
# A serialized .tres is effectively unmergeable by git's line merge (sub-resource ids,
# ext_resource indices shift). This driver merges sheets at the ROW level keyed on the
# stable row UIDs (event_uid/group_uid) + content signatures, so two people editing
# DIFFERENT rows merge cleanly, and only genuine same-row edits surface as conflicts.
#
# Git wiring:
#   .gitattributes:  *.tres merge=eventsheet
#   .git/config:     [merge "eventsheet"]
#                        name = EventSheets semantic merge
#                        driver = tools/sheet_merge.sh %O %A %B %P
# Git calls the driver with the ancestor (%O), ours (%A, also the output), theirs (%B) and
# the pathname (%P). The driver writes the merged sheet back to %A and exits 0 (clean) or
# 1 (conflicts remain - both versions are kept, fenced by ⚠ comment rows, for the user to
# resolve in the editor).
@tool
extends SceneTree

const TextDump := preload("res://addons/eventforge/sheet_text_dump.gd")


func _init() -> void:
	var args: PackedStringArray = _driver_args()
	if args.size() < 3:
		push_error("[sheet_merge] usage: -- <ancestor> <ours> <theirs>")
		quit(2)
		return
	var ancestor: EventSheetResource = _load_sheet(args[0])
	var ours: EventSheetResource = _load_sheet(args[1])
	var theirs: EventSheetResource = _load_sheet(args[2])
	if ours == null or theirs == null:
		# Not both event sheets - let git fall back to its default merge.
		quit(1)
		return
	if ancestor == null:
		ancestor = EventSheetResource.new()
	var outcome: Dictionary = merge_sheets(ancestor, ours, theirs)
	var merged: EventSheetResource = outcome.get("sheet")
	var conflicts: Array = outcome.get("conflicts", [])
	var save_error: Error = ResourceSaver.save(merged, args[1])
	if save_error != OK:
		push_error("[sheet_merge] could not write merged sheet: %d" % save_error)
		quit(1)
		return
	if conflicts.is_empty():
		print("[sheet_merge] clean merge of %s" % (args[2] if args.size() < 4 else args[3]))
		quit(0)
	else:
		print("[sheet_merge] %d conflict(s) kept for review: %s" % [conflicts.size(), ", ".join(PackedStringArray(conflicts))])
		quit(1)


## Args after the `--` separator (git passes the temp file paths there via the .sh wrapper).
func _driver_args() -> PackedStringArray:
	var all: PackedStringArray = OS.get_cmdline_user_args()
	if all.is_empty():
		# Fallback: take everything after a literal "--" in the raw cmdline.
		var raw: PackedStringArray = OS.get_cmdline_args()
		var seen: bool = false
		for token: String in raw:
			if seen:
				all.append(token)
			elif token == "--":
				seen = true
	return all


func _load_sheet(path: String) -> EventSheetResource:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	# CACHE_MODE_IGNORE: the three revisions share a logical identity; never alias them.
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return resource as EventSheetResource

# ── Testable merge core ────────────────────────────────────────────────────────────────


## Three-way merges three sheets. Returns {"sheet": EventSheetResource, "conflicts": Array}.
## Pure (no file I/O) so it can be unit-tested with in-memory sheets.
static func merge_sheets(ancestor: EventSheetResource, ours: EventSheetResource, theirs: EventSheetResource) -> Dictionary:
	var conflicts: Array = []
	var merged: EventSheetResource = ours.duplicate(true)
	merged.host_class = _merge_scalar(ancestor.host_class, ours.host_class, theirs.host_class, "host class", conflicts)
	merged.custom_class_name = _merge_scalar(ancestor.custom_class_name, ours.custom_class_name, theirs.custom_class_name, "class name", conflicts)
	merged.variables = _merge_variables(ancestor.variables, ours.variables, theirs.variables, conflicts)
	merged.includes = _merge_string_list(ancestor.includes, ours.includes, theirs.includes)
	merged.events = _merge_rows(ancestor.events, ours.events, theirs.events, conflicts)
	merged.functions = _merge_functions(ancestor.functions, ours.functions, theirs.functions, conflicts)
	return {"sheet": merged, "conflicts": conflicts}


## A scalar that changed on only one side takes that side; changed-on-both (differently) is
## a conflict and keeps OURS (recorded so the caller can flag it).
static func _merge_scalar(ancestor: Variant, ours: Variant, theirs: Variant, label: String, conflicts: Array) -> Variant:
	if ours == theirs:
		return ours
	if ours == ancestor:
		return theirs
	if theirs == ancestor:
		return ours
	conflicts.append(label)
	return ours


## Union of includes preserving ours' order, then theirs' additions. Removal on one side is
## honoured when the other side didn't re-add it.
static func _merge_string_list(ancestor: Array, ours: Array, theirs: Array) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in ours:
		var value: String = str(entry)
		# Dropped by theirs (and we didn't keep it intentionally)? Honour the removal.
		if ancestor.has(value) and not theirs.has(value):
			continue
		if not result.has(value):
			result.append(value)
	for entry: Variant in theirs:
		var value: String = str(entry)
		if not ancestor.has(value) and not result.has(value):
			result.append(value)
	return result


## Per-key 3-way merge of the variables dictionary.
static func _merge_variables(ancestor: Dictionary, ours: Dictionary, theirs: Dictionary, conflicts: Array) -> Dictionary:
	var result: Dictionary = {}
	var keys: Dictionary = {}
	for key: Variant in ours.keys(): keys[key] = true
	for key: Variant in theirs.keys(): keys[key] = true
	for key: Variant in keys.keys():
		var in_ours: bool = ours.has(key)
		var in_theirs: bool = theirs.has(key)
		var in_anc: bool = ancestor.has(key)
		var our_value: Variant = ours.get(key)
		var their_value: Variant = theirs.get(key)
		var anc_value: Variant = ancestor.get(key)
		if in_ours and in_theirs:
			if our_value == their_value:
				result[key] = our_value
			elif our_value == anc_value:
				result[key] = their_value
			elif their_value == anc_value:
				result[key] = our_value
			else:
				conflicts.append("variable %s" % str(key))
				result[key] = our_value
		elif in_ours and not in_theirs:
			# Theirs removed it; honour the removal only if we left it untouched.
			if not in_anc or our_value != anc_value:
				result[key] = our_value
		elif in_theirs and not in_ours:
			if not in_anc or their_value != anc_value:
				result[key] = their_value
	return result


## Functions match by name (3-way on the function's text signature).
static func _merge_functions(ancestor: Array, ours: Array, theirs: Array, conflicts: Array) -> Array[Resource]:
	var anc: Dictionary = _function_map(ancestor)
	var our_map: Dictionary = _function_map(ours)
	var their_map: Dictionary = _function_map(theirs)
	var result: Array[Resource] = []
	for entry: Variant in ours:
		if not (entry is EventFunction):
			result.append(entry)
			continue
		var name: String = (entry as EventFunction).function_name
		if their_map.has(name):
			var our_sig: String = _function_sig(entry)
			var their_sig: String = _function_sig(their_map[name])
			var anc_sig: String = _function_sig(anc[name]) if anc.has(name) else ""
			if our_sig == their_sig or their_sig == anc_sig:
				result.append(entry)
			elif our_sig == anc_sig:
				result.append(their_map[name])
			else:
				conflicts.append("function %s()" % name)
				result.append(entry)
		else:
			if anc.has(name) and _function_sig(entry) == _function_sig(anc[name]):
				continue  # theirs deleted, ours unchanged → drop
			result.append(entry)
	for entry: Variant in theirs:
		if entry is EventFunction:
			var name: String = (entry as EventFunction).function_name
			if not our_map.has(name) and not anc.has(name):
				result.append(entry)
	return result


## The heart of it: 3-way merge the top-level rows keyed on UID (events/groups) or content
## (uid-less rows). Order = ours' order, with theirs' additions appended.
static func _merge_rows(ancestor: Array, ours: Array, theirs: Array, conflicts: Array) -> Array[Resource]:
	var anc: Dictionary = _row_map(ancestor)
	var our_map: Dictionary = _row_map(ours)
	var their_map: Dictionary = _row_map(theirs)
	var result: Array[Resource] = []
	for row: Variant in ours:
		var key: String = _row_key(row)
		if their_map.has(key):
			var our_sig: String = _row_sig(row)
			var their_sig: String = _row_sig(their_map[key])
			var anc_sig: String = _row_sig(anc[key]) if anc.has(key) else ""
			if our_sig == their_sig or their_sig == anc_sig:
				result.append(row)
			elif our_sig == anc_sig:
				result.append(their_map[key])
			else:
				conflicts.append("row %s" % key)
				result.append(_conflict_marker("◀ OURS"))
				result.append(row)
				result.append(_conflict_marker("THEIRS ▶"))
				result.append(their_map[key])
		else:
			if anc.has(key):
				# Theirs deleted this row.
				if _row_sig(row) == _row_sig(anc[key]):
					continue  # we left it untouched → accept the deletion
				conflicts.append("row %s (deleted upstream, edited here)" % key)
				result.append(row)
			else:
				result.append(row)  # ours added it
	# Theirs' additions (and rows theirs kept but ours deleted while theirs edited them).
	for row: Variant in theirs:
		var key: String = _row_key(row)
		if our_map.has(key):
			continue
		if anc.has(key):
			# Not in ours, was in ancestor: ours deleted it. If theirs edited it, that's a
			# delete-vs-edit conflict - restore theirs' version so the change isn't lost.
			if _row_sig(row) != _row_sig(anc[key]):
				conflicts.append("row %s (deleted here, edited upstream)" % key)
				result.append(row)
		else:
			result.append(row)  # theirs added it
	return result


static func _row_map(rows: Array) -> Dictionary:
	var map: Dictionary = {}
	for row: Variant in rows:
		if row is Resource:
			map[_row_key(row)] = row
	return map


static func _function_map(functions: Array) -> Dictionary:
	var map: Dictionary = {}
	for entry: Variant in functions:
		if entry is EventFunction:
			map[(entry as EventFunction).function_name] = entry
	return map


## Stable identity: events/groups by their UID, uid-less rows by their content (so an edit
## to a comment reads as remove+add - acceptable for the rare comment-vs-comment case).
static func _row_key(row: Variant) -> String:
	if row is EventRow:
		return "event:" + (row as EventRow).event_uid
	if row is EventGroup:
		return "group:" + (row as EventGroup).group_uid
	return "content:" + _row_sig(row)


## A row's content fingerprint: its readable text dump (deterministic, order-preserving).
static func _row_sig(row: Variant) -> String:
	if not (row is Resource):
		return str(row)
	var lines: PackedStringArray = PackedStringArray()
	TextDump._dump_rows([row], lines, 0)
	return "\n".join(lines)


static func _function_sig(entry: Variant) -> String:
	if not (entry is EventFunction):
		return str(entry)
	var event_function: EventFunction = entry
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s(%s)" % [event_function.function_name, ", ".join(_function_param_names(event_function))])
	TextDump._dump_rows(event_function.events if not event_function.events.is_empty() else event_function.rows, lines, 1)
	return "\n".join(lines)


static func _function_param_names(event_function: EventFunction) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if param is ACEParam:
			names.append((param as ACEParam).id)
	return names


static func _conflict_marker(side: String) -> CommentRow:
	var comment: CommentRow = CommentRow.new()
	comment.text = "⚠ MERGE CONFLICT %s - keep one, delete the other, then re-save" % side
	return comment
