@tool
extends RefCounted
class_name EventSheetCommandPalette
# The Command Palette (Ctrl+P): keyboard-first access to every dock action — the affordance power
# users reach for first. The command list + fuzzy filter are pure/testable (filter_commands is static
# so tests can score titles without a live window); the popup is the GUI shell built lazily. Every
# command targets a dock method that STAYS on the dock — this helper only owns the list, the filter,
# and the window shell, reaching the dock's actions + add_child through the `_dock` back-reference,
# the same pattern as the other dock/ helpers. Extracted from event_sheet_dock.gd to keep that file
# maintainable; the dock keeps thin delegates so its shortcut caller and the tests don't change.

var _dock: Control = null
var _command_palette_window: Window = null
var _command_palette_search: LineEdit = null
var _command_palette_list: ItemList = null
var _command_palette_matches: Array = []

func init(dock: Control) -> void:
	_dock = dock

## Every command the palette can run: {title, run}. Kept in one place so the palette,
## (future) menus, and tests share the same source of truth.
func _command_palette_commands() -> Array[Dictionary]:
	return [
		{"title": "New Sheet…", "run": _dock._open_template_menu},
		{"title": "Open Sheet…", "run": _dock._on_open_requested},
		{"title": "Save Sheet", "run": _dock._on_save_requested},
		{"title": "Save Sheet As…", "run": _dock._on_save_as_requested},
		{"title": "Export Generated GDScript…", "run": _dock._export_gdscript_requested},
		{"title": "Run Scene", "run": _dock._run_from_sheet},
		{"title": "Add Event", "run": _dock._on_add_event_requested},
		{"title": "Add Condition", "run": _dock._on_add_condition_requested},
		{"title": "Add Action", "run": _dock._on_add_action_requested},
		{"title": "Add Global Variable…", "run": _dock._on_add_global_variable_requested},
		{"title": "Add Function…", "run": _dock._open_function_dialog},
		{"title": "Toggle GDScript Panel", "run": _dock._toggle_code_panel},
		{"title": "Toggle Simple Mode", "run": func() -> void: _dock.set_simple_mode(not _dock._simple_mode)},
		{"title": "Zoom In", "run": _dock._on_zoom_in_requested},
		{"title": "Zoom Out", "run": _dock._on_zoom_out_requested},
		{"title": "Sheet Type…", "run": _dock._open_sheet_type_dialog},
		{"title": "Export Addon Pack…", "run": _dock._export_addon_pack},
		{"title": "Open Welcome", "run": _dock.show_welcome},
	]

## Pure fuzzy filter (testable): returns the commands whose title matches `query` as a
## prefix > substring > subsequence, best first. Empty query returns everything in order.
static func filter_commands(commands: Array, query: String) -> Array:
	var q: String = query.strip_edges().to_lower()
	if q.is_empty():
		return commands.duplicate()
	var scored: Array = []
	for index: int in range(commands.size()):
		var title: String = str((commands[index] as Dictionary).get("title", "")).to_lower()
		var score: int = _command_match_score(title, q)
		if score >= 0:
			scored.append({"cmd": commands[index], "score": score, "index": index})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] < b["score"]
		return a["index"] < b["index"])
	var result: Array = []
	for entry: Dictionary in scored:
		result.append(entry["cmd"])
	return result

static func _command_match_score(title: String, q: String) -> int:
	if title.begins_with(q):
		return 0
	if title.contains(q):
		return 1
	# Subsequence: every query char appears in order (typo-tolerant "ae" → "Add Event").
	var ti: int = 0
	for qi: int in range(q.length()):
		var found: bool = false
		while ti < title.length():
			if title[ti] == q[qi]:
				found = true
				ti += 1
				break
			ti += 1
		if not found:
			return -1
	return 2

## Pure fuzzy filter over project sheet PATHS for the `#` mode (Navigate §13.3): returns [{title, path}]
## whose file name matches `query` (the leading `#` already stripped) as prefix > substring > subsequence,
## best first; empty query = all, name-sorted. Static → testable without a window, like filter_commands.
static func filter_sheets(sheet_paths: PackedStringArray, query: String) -> Array:
	var q: String = query.strip_edges().to_lower()
	var entries: Array = []
	for path: String in sheet_paths:
		var sheet_name: String = path.get_file()
		var score: int = 0 if q.is_empty() else _command_match_score(sheet_name.to_lower(), q)
		if score >= 0:
			entries.append({"title": sheet_name, "path": path, "score": score})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) < int(b["score"])
		return str(a["title"]) < str(b["title"]))
	var result: Array = []
	for entry: Dictionary in entries:
		result.append({"title": str(entry["title"]), "path": str(entry["path"])})
	return result

## The `#` mode's palette entries: every matching project sheet as a {title, run} that opens it.
func _sheet_matches(query: String) -> Array:
	var matches: Array = []
	for entry: Dictionary in filter_sheets(_dock.list_project_sheets(), query):
		var path: String = str(entry["path"])
		matches.append({"title": "# %s" % str(entry["title"]), "run": func() -> void: _dock._load_sheet_from_path(path)})
	return matches

## Every named symbol in a sheet — exposed functions (ƒ), signals (➜), and tree variables (@) — as
## [{title, name, resource}]. `name` is the bare identifier (fuzzy-match target); `title` carries the
## kind glyph; `resource` is what the palette reveals. Static + pure over the sheet → testable. Recurses
## groups so a symbol inside a group is still findable.
static func collect_symbols(sheet: EventSheetResource) -> Array:
	var symbols: Array = []
	if sheet == null:
		return symbols
	for function_variant: Variant in sheet.functions:
		if function_variant is EventFunction and not (function_variant as EventFunction).function_name.strip_edges().is_empty():
			symbols.append({"title": "ƒ %s" % (function_variant as EventFunction).function_name, "name": (function_variant as EventFunction).function_name, "resource": function_variant})
	_collect_symbol_rows(sheet.events, symbols)
	return symbols

static func _collect_symbol_rows(rows: Array, symbols: Array) -> void:
	for row: Variant in rows:
		if row is SignalRow and not (row as SignalRow).signal_name.strip_edges().is_empty():
			symbols.append({"title": "➜ %s" % (row as SignalRow).signal_name, "name": (row as SignalRow).signal_name, "resource": row})
		elif row is LocalVariable and not (row as LocalVariable).name.strip_edges().is_empty():
			symbols.append({"title": "@ %s" % (row as LocalVariable).name, "name": (row as LocalVariable).name, "resource": row})
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			_collect_symbol_rows(group.events if not group.events.is_empty() else group.rows, symbols)

## Pure fuzzy filter over collected symbols by their `name` (prefix > substring > subsequence), best
## first, name-sorted. Empty query = all in collection order. Static → testable.
static func filter_symbols(symbols: Array, query: String) -> Array:
	var q: String = query.strip_edges().to_lower()
	if q.is_empty():
		return symbols.duplicate()
	var scored: Array = []
	for index: int in range(symbols.size()):
		var name: String = str((symbols[index] as Dictionary).get("name", "")).to_lower()
		var score: int = _command_match_score(name, q)
		if score >= 0:
			scored.append({"sym": symbols[index], "score": score, "index": index})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) < int(b["score"])
		return int(a["index"]) < int(b["index"]))
	var result: Array = []
	for entry: Dictionary in scored:
		result.append(entry["sym"])
	return result

## The `@` mode's palette entries: matching symbols in the active sheet as {title, run} that reveal them.
func _symbol_matches(query: String) -> Array:
	var matches: Array = []
	for symbol: Variant in filter_symbols(collect_symbols(_dock._current_sheet), query):
		var resource: Resource = (symbol as Dictionary).get("resource")
		matches.append({"title": str((symbol as Dictionary).get("title", "")), "run": func() -> void:
			var view: EventSheetViewport = _dock._active_view()
			if view != null:
				view.reveal_resource(resource)})
	return matches

func _open_command_palette() -> void:
	if not Engine.is_editor_hint() and DisplayServer.get_name() == "headless":
		return
	if _command_palette_window == null:
		_build_command_palette_window()
	_command_palette_search.text = ""
	_refresh_command_palette("")
	_command_palette_window.popup_centered(Vector2i(520, 420))
	_command_palette_search.grab_focus()

func _build_command_palette_window() -> void:
	_command_palette_window = Window.new()
	_command_palette_window.title = "Command Palette"
	_command_palette_window.transient = true
	_command_palette_window.exclusive = false
	_command_palette_window.close_requested.connect(func() -> void: _command_palette_window.hide())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	_command_palette_window.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	_command_palette_search = LineEdit.new()
	_command_palette_search.placeholder_text = "Type a command…  (# sheet · @ symbol · ↑/↓ Enter Esc)"
	_command_palette_search.clear_button_enabled = true
	_command_palette_search.text_changed.connect(_refresh_command_palette)
	_command_palette_search.gui_input.connect(_on_command_palette_search_input)
	box.add_child(_command_palette_search)
	_command_palette_list = ItemList.new()
	_command_palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_command_palette_list.item_activated.connect(func(idx: int) -> void: _run_command_palette_index(idx))
	box.add_child(_command_palette_list)
	_dock.add_child(_command_palette_window)

func _refresh_command_palette(query: String) -> void:
	# Navigate §13.3 prefix modes: `#` opens any project sheet, `@` jumps to a symbol in the ACTIVE
	# sheet (function / signal / variable); anything else fuzzy-runs a command.
	if query.begins_with("#"):
		_command_palette_matches = _sheet_matches(query.substr(1))
	elif query.begins_with("@"):
		_command_palette_matches = _symbol_matches(query.substr(1))
	else:
		_command_palette_matches = filter_commands(_command_palette_commands(), query)
	if _command_palette_list == null:
		return
	_command_palette_list.clear()
	for cmd: Dictionary in _command_palette_matches:
		_command_palette_list.add_item(str(cmd.get("title", "")))
	if _command_palette_list.item_count > 0:
		_command_palette_list.select(0)

func _on_command_palette_search_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key: InputEventKey = event as InputEventKey
	match key.keycode:
		KEY_ESCAPE:
			_command_palette_window.hide()
		KEY_ENTER, KEY_KP_ENTER:
			var sel: PackedInt32Array = _command_palette_list.get_selected_items()
			_run_command_palette_index(sel[0] if sel.size() > 0 else 0)
		KEY_DOWN:
			_move_command_palette_selection(1)
		KEY_UP:
			_move_command_palette_selection(-1)

func _move_command_palette_selection(delta: int) -> void:
	if _command_palette_list == null or _command_palette_list.item_count == 0:
		return
	var sel: PackedInt32Array = _command_palette_list.get_selected_items()
	var current: int = sel[0] if sel.size() > 0 else 0
	var next: int = clampi(current + delta, 0, _command_palette_list.item_count - 1)
	_command_palette_list.select(next)
	_command_palette_list.ensure_current_is_visible()

func _run_command_palette_index(index: int) -> void:
	if index < 0 or index >= _command_palette_matches.size():
		return
	var run: Callable = (_command_palette_matches[index] as Dictionary).get("run", Callable())
	if _command_palette_window != null:
		_command_palette_window.hide()
	if run.is_valid():
		run.call()
