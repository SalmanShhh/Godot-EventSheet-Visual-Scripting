# Godot EventSheets - MCP server: where a row is, and the edits that move rows.
#
# A row is named by its ADDRESS: the indices from the top of the sheet down to it, joined with "/".
# "3" is the fourth top-level row; "3/0" is the first row inside it (an event's first sub-event, or a
# group's first child). The empty address is the sheet itself, which is what "insert at the top level"
# names. read_sheet hands every row its address, so an assistant reads one and passes it straight
# back. An address is a place, not a handle: an insert or a delete above a row moves it, so a client
# reads the sheet again after a structural edit rather than reusing addresses it held from before.
#
# Every function here works on the sheet it is handed and nothing else - no file, no editor. The
# server decides where that sheet comes from (the open tab, through the undo funnel, or the file on
# disk) and what happens to it afterwards.
@tool
extends RefCounted


## The rows directly under `container`: a sheet's top level, an event's sub-events, or a group's
## children. A group written before `events` existed keeps them in `rows`, and is read from there
## while `events` is empty, exactly as the compiler reads it. Null for a row that holds no rows.
static func children_of(container: Object) -> Variant:
	if container is EventSheetResource:
		return (container as EventSheetResource).events
	if container is EventRow:
		return (container as EventRow).sub_events
	if container is EventGroup:
		var group: EventGroup = container as EventGroup
		return group.rows if group.events.is_empty() and not group.rows.is_empty() else group.events
	return null


## The indices an address spells, or null when it is not one ("2/x", "-1", "3//1").
static func parse_address(address: String) -> Variant:
	var indices: Array[int] = []
	var trimmed: String = address.strip_edges()
	if trimmed.is_empty():
		return indices
	for part: String in trimmed.split("/"):
		if not part.is_valid_int() or part.to_int() < 0:
			return null
		indices.append(part.to_int())
	return indices


## What an address points at: {"row": Resource, "list": Array, "index": int, "parent": Object}, or
## {"error": String}. The empty address is the sheet itself, with no list around it.
static func resolve(sheet: EventSheetResource, address: String) -> Dictionary:
	var indices: Variant = parse_address(address)
	if indices == null:
		return {"error": "\"%s\" is not a row address (indices joined with /, e.g. \"3\" or \"3/0\")." % address}
	var current: Object = sheet
	var list: Variant = null
	var index: int = -1
	var parent: Object = null
	for step: int in indices as Array[int]:
		var children: Variant = children_of(current)
		if children == null:
			return {"error": "Row %s holds no rows, so there is nothing at %s." % [_address_before(address), address]}
		if step >= (children as Array).size():
			return {"error": "There is no row %s (that level has %d)." % [address, (children as Array).size()]}
		parent = current
		list = children
		index = step
		current = (children as Array)[step]
	return {"row": current, "list": list, "index": index, "parent": parent}


static func _address_before(address: String) -> String:
	var cut: int = address.rfind("/")
	return "the sheet" if cut < 0 else address.left(cut)


## The address of `row` in `sheet`, or "" when the row is not in the event tree (a function's body
## row, or a row of another sheet). Found by identity, so it is the row object itself.
static func address_of(sheet: EventSheetResource, row: Object) -> String:
	if sheet == null or row == null:
		return ""
	return _find(sheet.events, row, "")


static func _find(rows: Array, target: Object, prefix: String) -> String:
	for index: int in range(rows.size()):
		var here: String = str(index) if prefix.is_empty() else "%s/%d" % [prefix, index]
		var row: Variant = rows[index]
		if row == target:
			return here
		if row is Object:
			var children: Variant = children_of(row as Object)
			if children != null:
				var found: String = _find(children as Array, target, here)
				if not found.is_empty():
					return found
	return ""


## Puts `rows` under the row at `parent_address` (empty = the top level), starting at `position`.
## A negative position, or one past the end, appends. Returns "" or the reason nothing was inserted.
static func insert(sheet: EventSheetResource, parent_address: String, position: int, rows: Array) -> String:
	var target: Dictionary = resolve(sheet, parent_address)
	if target.has("error"):
		return str(target.get("error"))
	var children: Variant = children_of(target.get("row") as Object)
	if children == null:
		return "Row %s is not an event or a group, so rows cannot go inside it." % parent_address
	var list: Array = children as Array
	var at: int = list.size() if position < 0 or position > list.size() else position
	for row: Variant in rows:
		list.insert(at, row)
		at += 1
	return ""


## Takes the row at `address` out of the sheet, with everything under it. "" or the reason.
static func delete(sheet: EventSheetResource, address: String) -> String:
	if address.strip_edges().is_empty():
		return "Name the row to delete - the empty address is the whole sheet."
	var target: Dictionary = resolve(sheet, address)
	if target.has("error"):
		return str(target.get("error"))
	(target.get("list") as Array).remove_at(int(target.get("index")))
	return ""


## Puts `rows` where the row at `address` is, in its place and in their order. "" or the reason.
static func replace(sheet: EventSheetResource, address: String, rows: Array) -> String:
	if address.strip_edges().is_empty():
		return "Name the row to edit - the empty address is the whole sheet."
	if rows.is_empty():
		return "Nothing to put in its place - to remove a row, use delete_row."
	var target: Dictionary = resolve(sheet, address)
	if target.has("error"):
		return str(target.get("error"))
	var list: Array = target.get("list") as Array
	var at: int = int(target.get("index"))
	list.remove_at(at)
	for row: Variant in rows:
		list.insert(at, row)
		at += 1
	return ""


## The rows `text` stands for: EventSheet snippet text read as a snippet, anything else read as
## GDScript through the same lossless lift the editor's paste uses (a line it cannot lift stays a
## GDScript block row, so nothing is lost). The `extends` line a bare paste is given is dropped.
static func rows_from_text(text: String) -> Array:
	var rows: Array = []
	if EventSheetSnippet.is_snippet_text(text):
		return EventSheetSnippet.deserialize(text).get("rows", []) as Array
	var converted: EventSheetResource = GDScriptImporter.new().import_external_source(text)
	if converted == null:
		return rows
	for row: Variant in converted.events:
		if row is RawCodeRow and (row as RawCodeRow).code.strip_edges().begins_with("extends "):
			continue
		rows.append(row)
	return rows


## Each row's kind, the way read_sheet names it.
static func kinds_of(rows: Array) -> Array:
	var kinds: Array = []
	for row: Variant in rows:
		if row is Object and (row as Object).has_method("get_row_kind"):
			kinds.append(str((row as Object).call("get_row_kind")))
		elif row is Object:
			kinds.append(str((row as Object).get_class()))
	return kinds


## Every variable row in the event tree, plus nothing else. A `.gd` sheet declares its members as
## these rows; a stored sheet keeps most of its variables in `sheet.variables` instead.
static func variable_rows(sheet: EventSheetResource) -> Array[LocalVariable]:
	var found: Array[LocalVariable] = []
	_collect_variables(sheet.events, found)
	return found


static func _collect_variables(rows: Array, into: Array[LocalVariable]) -> void:
	for row: Variant in rows:
		if row is LocalVariable:
			into.append(row as LocalVariable)
		elif row is Object:
			var children: Variant = children_of(row as Object)
			if children != null:
				_collect_variables(children as Array, into)
