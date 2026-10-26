@tool
class_name EventSheetFunctionsPanel
extends VBoxContainer
# The Functions tab of the side panel: every function this file has, at a glance.
#
# Drawn the way Godot's own docks are - a filter (with ＋ beside it, which adds a function), then
# plain rows with an icon, a name and a count:
#
#   ƒ juice_tile    1 call      a sheet function, and how many times this file calls it
#   ƒ _process      code        a function still written as code in the file
#
# Sheet functions come first, in the order the sheet holds them (✦ after a name = published as an
# ACE), then the functions still written as code, in file order. The rows are DERIVED from the open
# sheet every time it changes, so there is no stored list to fall out of date. The panel is shell
# only: right-click on a sheet function is the dock's (it offers Delete Function).

## The ＋ beside the filter - the dock opens the function dialog (the ACE Studio).
signal add_requested

## The row kinds `function_rows` returns.
const KIND_SHEET: String = "sheet"
const KIND_CODE: String = "code"

## The function list itself: column 0 the icon and the name, column 1 the count. A sheet function's
## row carries {"kind": "sheet", "index": <its index in sheet.functions>} as its metadata, a code
## function's {"kind": "code", "name": <its name>}.
var list: Tree = null
var filter_edit: LineEdit = null

var _rows: Array = []
var _filter: String = ""
## The sheet the rows are read from, and whether they still have to be. Reading them counts every
## function's calls over the whole file, so it waits until the tab is on screen: a side panel that
## rests closed (the state every project starts in) costs nothing on first open or on an edit.
var _sheet: EventSheetResource = null
var _stale: bool = false


func _init() -> void:
	name = "Functions"
	add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.name = "EventSheetFunctionsFilterRow"
	var add_button: Button = Button.new()
	add_button.name = "EventSheetFunctionsAdd"
	add_button.text = "＋"
	add_button.flat = true
	add_button.tooltip_text = EventSheetL10n.translate("Add a function…")
	add_button.pressed.connect(func() -> void: add_requested.emit())
	filter_row.add_child(add_button)
	filter_edit = LineEdit.new()
	filter_edit.name = "EventSheetFunctionsFilter"
	filter_edit.placeholder_text = EventSheetL10n.translate("Filter…")
	filter_edit.clear_button_enabled = true
	filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_edit.text_changed.connect(func(text: String) -> void:
		_filter = text
		_rebuild())
	filter_row.add_child(filter_edit)
	add_child(filter_row)
	list = Tree.new()
	list.name = "EventSheetFunctionsList"
	# The side panel decides the tab's size, so the body carries no minimum of its own.
	list.custom_minimum_size = Vector2.ZERO
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.hide_root = true
	list.columns = 2
	list.set_column_expand(0, true)
	list.set_column_expand(1, false)
	list.set_column_custom_minimum_width(1, int(EventSheetPalette.scaled_f(58.0)))
	list.allow_reselect = true
	# Without this a right-click selects nothing, and the menu would open on whatever was selected
	# last rather than on the row under the pointer.
	list.allow_rmb_select = true
	add_child(list)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		catch_up()
	# The magnifier a Godot dock's filter wears, from the editor's own icons when there are any.
	if what == NOTIFICATION_THEME_CHANGED and filter_edit != null and has_theme_icon("Search", "EditorIcons"):
		filter_edit.right_icon = get_theme_icon("Search", "EditorIcons")
		_rebuild()


## The Functions tab's hover.
func tab_tooltip() -> String:
	return EventSheetL10n.translate(
		"Every function in this file: the sheet's own (✦ = published as an ACE), then the ones still written as code.")


## Re-read the open sheet's functions - now when the tab is on screen, and the moment it is shown
## otherwise.
func set_sheet(sheet: EventSheetResource) -> void:
	_sheet = sheet
	_stale = true
	catch_up()


## Read the rows now if they wait and the tab is on screen. The side panel calls it after it shows a
## tab, which also covers a panel that is not in a tree yet (no visibility notification reaches it).
func catch_up() -> void:
	if _stale and _on_screen():
		_ensure_rows()
		_rebuild()


## Whether the rows wait for the tab to be shown before they are read.
func rows_pending() -> bool:
	return _stale


## Whether this tab and every control holding it are shown - asked of the controls themselves, so it
## answers the same in a tree and out of one.
func _on_screen() -> bool:
	var node: Node = self
	while node != null:
		if node is CanvasItem and not (node as CanvasItem).visible:
			return false
		node = node.get_parent()
	return true


func _ensure_rows() -> void:
	if not _stale:
		return
	_stale = false
	_rows = function_rows(_sheet)


## How many sheet functions the tab lists.
func sheet_function_count() -> int:
	_ensure_rows()
	var count: int = 0
	for row: Variant in _rows:
		if str((row as Dictionary).get("kind", "")) == KIND_SHEET:
			count += 1
	return count


## The index into `sheet.functions` of the selected row, or -1 when nothing - or a function written
## as code - is selected.
func selected_function_index() -> int:
	var selected: TreeItem = list.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		return -1
	var meta: Dictionary = selected.get_metadata(0)
	return int(meta.get("index", -1)) if str(meta.get("kind", "")) == KIND_SHEET else -1


## Select the row of the sheet function at `index` in `sheet.functions`.
func select_function(index: int) -> void:
	if _stale:
		_ensure_rows()
		_rebuild()
	var item: TreeItem = list.get_root().get_first_child() if list.get_root() != null else null
	while item != null:
		var meta: Variant = item.get_metadata(0)
		if meta is Dictionary and str((meta as Dictionary).get("kind", "")) == KIND_SHEET \
				and int((meta as Dictionary).get("index", -1)) == index:
			item.select(0)
			return
		item = item.get_next()


## What the tab lists, as [{kind, name, label, count, tooltip, index}] - pure, so a test pins it.
## Sheet functions first: their name (a ✦ after it when published as an ACE), how many times this
## file calls them, and their signature plus their description on hover. Then the functions still
## written as code, read off the code blocks the sheet keeps.
static func function_rows(sheet: EventSheetResource) -> Array:
	var rows: Array = []
	if sheet == null:
		return rows
	var code_blocks: PackedStringArray = PackedStringArray()
	_collect_code(sheet.events, code_blocks)
	var calls_by_name: Dictionary = call_counts(sheet, code_blocks)
	for function_index: int in sheet.functions.size():
		var function: EventFunction = sheet.functions[function_index] as EventFunction
		if function == null:
			continue
		var calls: int = int(calls_by_name.get(function.function_name, 0))
		var description: String = EventSheetDescriptions.display(EventSheetDescriptions.for_function(function))
		var signature: String = signature_of(function)
		rows.append({
			"kind": KIND_SHEET,
			"name": function.function_name,
			"label": (function.function_name + "  ✦") if function.expose_as_ace else function.function_name,
			"count": call_count_text(calls),
			"tooltip": signature if description.is_empty() else "%s\n%s" % [signature, description],
			"index": function_index,
		})
	var seen: Dictionary = {}
	for code: String in code_blocks:
		for function_name: String in code_function_names(code):
			if seen.has(function_name):
				continue
			seen[function_name] = true
			rows.append({
				"kind": KIND_CODE,
				"name": function_name,
				"label": function_name,
				"count": EventSheetL10n.translate("code"),
				"tooltip": EventSheetL10n.translate("Written as code in this file."),
				"index": -1,
			})
	return rows


## "name(a, b)" - a sheet function's signature, as its hover opens with.
static func signature_of(function: EventFunction) -> String:
	var param_ids: PackedStringArray = PackedStringArray()
	for param_variant: Variant in function.params:
		if param_variant is ACEParam:
			param_ids.append((param_variant as ACEParam).id)
	return "%s(%s)" % [function.function_name, ", ".join(param_ids)]


## "1 call" / "3 calls", or nothing for a function this file never calls (a published verb, an
## entry point other files call).
static func call_count_text(calls: int) -> String:
	if calls <= 0:
		return ""
	return EventSheetL10n.translate("1 call") if calls == 1 else EventSheetL10n.translate("%d calls") % calls


## How many times this file calls `function_name`: every Call row naming it (in events, groups,
## sub-events and the other functions' bodies), plus every `function_name(` in the code the sheet
## keeps as code that is not the line defining it.
static func call_count(sheet: EventSheetResource, function_name: String, code_blocks: PackedStringArray) -> int:
	if function_name.is_empty():
		return 0
	var count: int = _count_call_rows(sheet.events, function_name)
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name != function_name:
			count += _count_call_rows((entry as EventFunction).events, function_name)
	var pattern: RegEx = RegEx.create_from_string("(?<![\\w.])%s\\s*\\(" % function_name)
	var definition: RegEx = RegEx.create_from_string("^\\s*(static\\s+)?func\\s+%s\\s*\\(" % function_name)
	for code: String in code_blocks:
		for line: String in code.split("\n"):
			if definition.search(line) != null:
				continue
			count += pattern.search_all(line.split("#")[0]).size()
	return count


## How many times this file calls each name, in ONE pass over the file: {name: calls}. The same
## count `call_count` gives one function - Call rows in events, groups, sub-events and the other
## functions' bodies (a function calling itself is not counted), plus every `name(` in the code the
## sheet keeps as code, the name a `func` line defines left out.
static func call_counts(sheet: EventSheetResource, code_blocks: PackedStringArray) -> Dictionary:
	var counts: Dictionary = {}
	if sheet == null:
		return counts
	_tally_call_rows(sheet.events, "", counts)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			_tally_call_rows((entry as EventFunction).events, (entry as EventFunction).function_name, counts)
	var called: RegEx = RegEx.create_from_string("(?<![\\w.])([A-Za-z_]\\w*)\\s*\\(")
	var definition: RegEx = RegEx.create_from_string("^\\s*(?:static\\s+)?func\\s+([A-Za-z_]\\w*)\\s*\\(")
	for code: String in code_blocks:
		for line: String in code.split("\n"):
			var defined: RegExMatch = definition.search(line)
			for found: RegExMatch in called.search_all(line.split("#")[0]):
				var called_name: String = found.get_string(1)
				# `func` itself is no call, and neither is the name its line defines.
				if called_name == "func" or (defined != null and called_name == defined.get_string(1)):
					continue
				counts[called_name] = int(counts.get(called_name, 0)) + 1
	return counts


static func _tally_call_rows(rows: Array, inside_function: String, counts: Dictionary) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_tally_call_rows(group.events if not group.events.is_empty() else group.rows, inside_function, counts)
			continue
		if not (entry is EventRow):
			continue
		var event: EventRow = entry as EventRow
		for action: Variant in event.actions:
			var called_name: String = _called_function_name(action)
			if not called_name.is_empty() and called_name != inside_function:
				counts[called_name] = int(counts.get(called_name, 0)) + 1
		_tally_call_rows(event.sub_events, inside_function, counts)


## The names of the functions a block of code defines, in the order it defines them.
static func code_function_names(code: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var definition: RegEx = RegEx.create_from_string("^(?:static\\s+)?func\\s+([A-Za-z_]\\w*)\\s*\\(")
	for line: String in code.split("\n"):
		var found: RegExMatch = definition.search(line)
		if found != null:
			names.append(found.get_string(1))
	return names


static func _collect_code(rows: Array, into: PackedStringArray) -> void:
	for entry: Variant in rows:
		if entry is RawCodeRow:
			into.append((entry as RawCodeRow).code)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_code(group.events if not group.events.is_empty() else group.rows, into)


static func _count_call_rows(rows: Array, function_name: String) -> int:
	var count: int = 0
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			count += _count_call_rows(group.events if not group.events.is_empty() else group.rows, function_name)
			continue
		if not (entry is EventRow):
			continue
		var event: EventRow = entry as EventRow
		for action: Variant in event.actions:
			if _called_function_name(action) == function_name:
				count += 1
		count += _count_call_rows(event.sub_events, function_name)
	return count


## The function a Call row calls, or "" for any other action.
static func _called_function_name(action: Variant) -> String:
	if not (action is ACEAction):
		return ""
	var call_action: ACEAction = action as ACEAction
	if not (call_action.provider_id.is_empty() or call_action.provider_id == "Core") \
			or call_action.ace_id != "CallFunction":
		return ""
	var params: Dictionary = call_action.params if not call_action.params.is_empty() else call_action.parameters
	return str(params.get("function_name", "")).strip_edges()


func _rebuild() -> void:
	if list == null:
		return
	list.clear()
	var root: TreeItem = list.create_item()
	var needle: String = _filter.strip_edges().to_lower()
	var icon: Texture2D = get_theme_icon("MemberMethod", "EditorIcons") \
		if has_theme_icon("MemberMethod", "EditorIcons") else null
	var muted: Color = EventSheetActiveTheme.chrome().object_bar_section_color
	for row_variant: Variant in _rows:
		var row: Dictionary = row_variant
		if not needle.is_empty() and not str(row.get("name", "")).to_lower().contains(needle):
			continue
		var item: TreeItem = list.create_item(root)
		var is_code: bool = str(row.get("kind", "")) == KIND_CODE
		item.set_text(0, str(row.get("label", "")) if icon != null else "ƒ  %s" % str(row.get("label", "")))
		if icon != null:
			item.set_icon(0, icon)
		item.set_tooltip_text(0, str(row.get("tooltip", "")))
		if is_code:
			item.set_custom_color(0, muted)
		item.set_text(1, str(row.get("count", "")))
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_custom_color(1, muted)
		item.set_metadata(0, {"kind": KIND_CODE, "name": str(row.get("name", ""))} if is_code
			else {"kind": KIND_SHEET, "index": int(row.get("index", -1))})
