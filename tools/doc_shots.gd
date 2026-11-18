# Godot EventSheets - THE PICTURE HARNESS: retakes the documentation pictures from the REAL editor.
#
# A guide's picture is only worth having if it shows what the reader will see, and the reader sees
# the real Godot editor: its fonts, its theme, its docks. A bare control tree drawn by a plain script
# has none of that, so this harness runs INSIDE an editor (non-headless, `--editor`), drives it the
# way a person does (opens a sheet, selects a node, opens a menu with the keys a person would press)
# and saves one PNG per shot, cropped to what the picture's own words name.
#
# WHAT A RUN NEEDS (the launcher `tools/doc_shots.ps1` sets all of it up and is the way to run this):
#   * a SANDBOX settings folder (`config=<folder>`): the editor reads and writes its settings under the
#     user's config folder, and a run must never touch the developer's own. The harness refuses to run
#     unless the editor reports its config folder under that path.
#   * single-window mode and a 100% display scale in those settings (`tools/doc_shots/editor_settings_dark.txt`),
#     so a menu or a window is drawn inside the one editor window and the pixels are the same on every machine.
#   * no saved session, no picker recents and no dock layout from an earlier run, so a picture never
#     carries a leftover.
#
# THE LIST: `tools/doc_shots/shots.json`. One entry per picture (`window` [w, h] asks for a different editor size): its name, the file it replaces, the
# batch it belongs to, a `source` sheet to open (or explicit `steps`), the rows to keep (`rows`) or a
# `crop`, and - written by `tools/doc_shots_fingerprint.gd` after a capture - the fingerprint of what the
# picture shows, which `tests/doc_pictures_fresh_test.gd` recomputes to tell a picture that has gone stale.
#
# THE STEPS a shot can run (each is a small function below; frames are counted, never seconds):
#   wait {frames}                       main_screen {value}               open_sheet {path}
#   wait_sheet                          close_other_tabs {path}           open_scene {path}
#   select_node {path}                  reassert_selection                picker {mode, seed}
#   dock_call {method}                  clear_status                      close_popups
#   push_key {key, mods, times}         menu_open {button, path}          view_rows {from, to, width, height}
#   fold {text, open}                   right_click_row {text}   click_row {text, x}            click_control {class, text}
#   new_from_template {id}              project_setting {name, value} (in memory only)   lane_ratio {value}   play_scene {path}   stop_scene   hover_sheet {x, y}   dump_controls
#   (menu_open also takes activate: true to press the last item; a shot may list `cleanup` steps and `parts` with a `layout`)
#
# THE CROPS: `window` (the whole editor), `main_screen`, `sheet` (the sheet canvas), `rows` (the rows named
# by view_rows), `inspector`, `popup` (the top window exactly, title bar in and nothing outside it),
# `menus` (every open menu plus the strip it hangs from), `strip`, `top` (the strip and the tab bar) and `submenu` (only the last menu opened), `code` (the code panel) and `rect` ([x, y, w, h]). No scaling: one picture
# pixel is one screen pixel.
#
# RERUNS: nothing here uses a clock, a random number or the real mouse. The text caret is pinned so it
# never blinks into a picture, a menu is placed where a click would put it, and a popup is cropped to
# itself, so two runs over one tree write the same bytes. The report lists the hash of every picture.
#
#   godot --editor --path . --script tools/doc_shots.gd -- list=tools/doc_shots/shots.json out=<folder> config=<sandbox> [only=a,b] [batch=strip] [install=1]
@tool
extends SceneTree

## The longest a run may take before it quits by itself, so a stuck popup can never keep an editor open.
const WATCHDOG_SECONDS: float = 1500.0

var _args: Dictionary = {}
var _list: Dictionary = {}
var _out: String = ""
var _report: PackedStringArray = PackedStringArray()
var _failed: PackedStringArray = PackedStringArray()
## The rectangle a step marked as the part of the screen the picture is about (rows, a row's menu).
var _focus: Rect2i = Rect2i()
## Whether `_focus` was set by the shot that is running.
var _has_focus: bool = false
var _row_rect: Rect2i = Rect2i()
## The last menu a step opened (the submenu a path ended in).
var _last_menu: PopupMenu = null


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var at: int = argument.find("=")
		if at > 0:
			_args[argument.substr(0, at)] = argument.substr(at + 1)
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _w(frames: int) -> void:
	for i: int in frames:
		await process_frame


func _log(line: String) -> void:
	print("[shots] ", line)
	_report.append(line)


func _normal(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()


func _start() -> void:
	var sandbox: String = _normal(str(_args.get("config", "")))
	if sandbox.is_empty() or not _normal(OS.get_config_dir()).begins_with(sandbox):
		push_error("[shots] refusing: the editor's config folder %s is not the sandbox given as config=" % OS.get_config_dir())
		quit(3)
		return
	create_timer(WATCHDOG_SECONDS).timeout.connect(func() -> void:
		_log("watchdog fired")
		quit(2))
	_out = str(_args.get("out", ""))
	if _out.is_empty():
		push_error("[shots] out=<folder> is required")
		quit(3)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(_args.get("list", ""))))
	if not (parsed is Dictionary):
		push_error("[shots] list= is not a readable shots file")
		quit(3)
		return
	_list = parsed
	var size: Array = _list.get("window", [1600, 900])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	DisplayServer.window_set_position(Vector2i(40, 40))
	# A run waits on frames; an editor that only draws when something changed would sleep through them.
	OS.low_processor_usage_mode = false
	# A tooltip must never open under a pushed hover and land in a picture.
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 600.0)
	await _w(int(_list.get("settle_frames", 150)))
	_log("window %s scale %s single_window %s godot %s" % [DisplayServer.window_get_size(),
		EditorInterface.get_editor_scale(),
		EditorInterface.get_editor_settings().get_setting("interface/editor/display/single_window_mode"),
		Engine.get_version_info()["string"]])
	var only: PackedStringArray = str(_args.get("only", "")).split(",", false)
	var batch: String = str(_args.get("batch", ""))
	for shot: Dictionary in _list["shots"]:
		if not only.is_empty() and not only.has(str(shot["name"])):
			continue
		if not batch.is_empty() and str(shot.get("batch", "")) != batch:
			continue
		await _take(shot)
	var file: FileAccess = FileAccess.open(_out.path_join("report.txt"), FileAccess.WRITE)
	file.store_string("\n".join(_report) + "\n")
	file.close()
	if not _failed.is_empty():
		_log("FAILED: %s" % ", ".join(_failed))
	quit(0 if _failed.is_empty() else 1)


func _take(shot: Dictionary) -> void:
	var started: int = Time.get_ticks_msec()
	# A shot may ask for a wider editor (a head bar with many buttons needs the room); every other shot
	# is taken at the list's own size, so the pictures of one batch share a frame.
	var wanted: Array = shot.get("window", _list.get("window", [1600, 900]))
	if DisplayServer.window_get_size() != Vector2i(int(wanted[0]), int(wanted[1])):
		DisplayServer.window_set_size(Vector2i(int(wanted[0]), int(wanted[1])))
		await _w(30)
	var ok: bool = true
	var pieces: Array[Image] = []
	var parts: Array = shot.get("parts", [shot])
	for part: Dictionary in parts:
		_has_focus = false
		if EventSheets._dock != null:
			await _show_events()
			await _rest_toolbar()
			EventSheets._dock._reset_lane_split()
			EventSheets._dock._set_status("")
		for step: Dictionary in _steps_of(part):
			ok = await _step(step) and ok
		await _w(8)
		_quiet_carets()
		await _w(4)
		_dump_rows(str(shot["name"]))
		var image: Image = await _grab(part, str(shot["name"]))
		if image == null:
			ok = false
		else:
			pieces.append(image)
	for step: Dictionary in shot.get("cleanup", []):
		await _step(step)
	if ok:
		var joined: Image = pieces[0] if pieces.size() == 1 else _join(pieces, str(shot.get("layout", "vertical")))
		_save(shot, joined)
	if not ok:
		_failed.append(str(shot["name"]))
	_log("%s steps_ok=%s %d ms" % [shot["name"], ok, Time.get_ticks_msec() - started])


## The sheet's own Events view: a picture of the rows never carries the code panel an earlier one opened.
func _show_events() -> void:
	for node: Node in _all_of("Button", EventSheets._dock):
		var button: Button = node as Button
		if button.is_visible_in_tree() and button.text.strip_edges() == "Events" and button.toggle_mode and not button.button_pressed:
			var rect: Rect2 = button.get_global_rect()
			await _click_at(rect.position + rect.size * 0.5, MOUSE_BUTTON_LEFT)


## The strip at rest (a chevron reading "»"): the plugin remembers an expanded strip in the project's
## editor metadata, so an earlier picture must not leave it open for the next.
func _rest_toolbar() -> void:
	for node: Node in _all_of("Button", EventSheets._dock):
		var button: Button = node as Button
		if button.is_visible_in_tree() and button.text.strip_edges() == "«":
			var rect: Rect2 = button.get_global_rect()
			await _click_at(rect.position + rect.size * 0.5, MOUSE_BUTTON_LEFT)
			return


## Several captures of one picture side by side or stacked, with a small gap in the editor's own base colour.
func _join(pieces: Array[Image], layout: String) -> Image:
	var gap: int = 8
	var horizontal: bool = layout == "horizontal"
	var width: int = 0
	var height: int = 0
	for piece: Image in pieces:
		piece.convert(Image.FORMAT_RGBA8)
		if horizontal:
			width += piece.get_width()
			height = maxi(height, piece.get_height())
		else:
			height += piece.get_height()
			width = maxi(width, piece.get_width())
	if horizontal:
		width += gap * (pieces.size() - 1)
	else:
		height += gap * (pieces.size() - 1)
	var joined: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	joined.fill(EditorInterface.get_editor_theme().get_color("base_color", "Editor"))
	var at: int = 0
	for piece: Image in pieces:
		if layout == "horizontal":
			joined.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(at, 0))
			at += piece.get_width() + gap
		else:
			joined.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(0, at))
			at += piece.get_height() + gap
	return joined


## Writes every row of the open sheet as `index<TAB>text`, so a shot's `rows` can be chosen from what the
## canvas really says.
func _dump_rows(shot_name: String) -> void:
	var view: EventSheetViewport = EventSheets._dock._viewport
	if view == null:
		return
	DirAccess.make_dir_recursive_absolute(_out.path_join("rows"))
	var file: FileAccess = FileAccess.open(_out.path_join("rows").path_join("%s.txt" % shot_name), FileAccess.WRITE)
	for index: int in view.get_total_row_count():
		file.store_line("%d	%s" % [index, _row_text(view, index)])
	file.close()


## The steps of a shot: what it lists, or, for a shot that names only a `source` sheet, the usual way of
## opening one and putting its rows in frame.
func _steps_of(shot: Dictionary) -> Array:
	if shot.has("steps"):
		return shot["steps"]
	var steps: Array = []
	var source: String = str(shot.get("source", ""))
	steps.append({"do": "close_popups"})
	for first: Variant in shot.get("prelude", []):
		steps.append(first)
	if not source.is_empty():
		steps.append({"do": "main_screen", "value": "EventSheet"})
		steps.append({"do": "open_sheet", "path": source})
		steps.append({"do": "wait_sheet", "path": source})
		steps.append({"do": "close_other_tabs", "path": source})
	steps.append({"do": "clear_status"})
	for extra: Variant in shot.get("before", []):
		steps.append(extra)
	if shot.has("rows"):
		var rows: Array = shot["rows"]
		steps.append({"do": "view_rows", "from": rows[0], "to": rows[1] if rows.size() > 1 else "", "height": int(shot.get("height", 0)), "width": int(shot.get("width", 1200))})
	return steps


func _step(step: Dictionary) -> bool:
	var dock: Object = EventSheets._dock
	match str(step["do"]):
		"wait":
			await _w(int(step["frames"]))
		"main_screen":
			EditorInterface.set_main_screen_editor(str(step["value"]))
			await _w(20)
		"open_sheet":
			for attempt: int in 40:
				if EventSheets.open_sheet(str(step["path"])):
					return true
				await _w(30)
			_log("open_sheet failed %s" % step["path"])
			return false
		"wait_sheet":
			return await _wait_sheet(str(step["path"]))
		"open_scene":
			EditorInterface.open_scene_from_path(str(step["path"]))
			await _w(40)
		"select_node":
			var node: Node = _scene_node(str(step["path"]))
			if node == null:
				_log("no node %s" % step["path"])
				return false
			EditorInterface.get_selection().clear()
			EditorInterface.get_selection().add_node(node)
			EditorInterface.edit_node(node)
			await _w(10)
		"reassert_selection":
			var picked: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
			if not picked.is_empty():
				EditorInterface.edit_node(picked[0])
			await _w(6)
		"picker":
			var context: Dictionary = (step.get("context", {}) as Dictionary).duplicate()
			context["search_seed"] = str(step.get("seed", ""))
			dock._ace_picker.open(str(step["mode"]), bool(step.get("signals_only", false)), null, context)
			await _w(40)
		"dock_call":
			dock.callv(str(step["method"]), step.get("args", []))
			await _w(int(step.get("frames", 20)))
		"dock_path_call":
			# A method of an object the dock holds: "_rail_panels.set_panel_tucked" with its arguments.
			var parts_of: PackedStringArray = str(step["path"]).split(".")
			var target: Object = dock
			for i: int in parts_of.size() - 1:
				target = target.get(parts_of[i])
				if target == null:
					return true
			target.callv(parts_of[parts_of.size() - 1], step.get("args", []))
			await _w(int(step.get("frames", 20)))
		"close_other_tabs":
			for i: int in range(dock._open_tabs.size() - 1, -1, -1):
				if str(dock._open_tabs[i].get("path", "")) != str(step["path"]):
					dock._close_tab(i)
			await _w(20)
		"clear_status":
			dock._set_status("")
			await _w(2)
		"close_popups":
			_close_popups()
			await _w(10)
		"push_key":
			for i: int in int(step.get("times", 1)):
				await _key(_keycode(str(step["key"])), step.get("mods", []))
		"menu_open":
			return await _menu_open(str(step["button"]), step.get("path", []), bool(step.get("activate", false)))
		"new_from_template":
			for i: int in range(dock._open_tabs.size() - 1, -1, -1):
				dock._close_tab(i)
			await _w(20)
			dock._starter._new_sheet_from_template(int(step["id"]))
			await _w(int(step.get("frames", 60)))
			if str(dock._current_sheet_path) != "":
				_log("the new sheet did not replace %s" % dock._current_sheet_path)
				return false
		"view_rows":
			return await _view_rows(step)
		"lane_ratio":
			var view: EventSheetViewport = dock._viewport
			view._get_event_style().condition_lane_ratio = float(step["value"])
			view._update_layout_style_signature(view._get_font_size())
			view._row_metrics_helper.rebuild()
			view._layout_cache.clear()
			view._update_canvas_min_size()
			view.queue_redraw()
			await _w(10)
		"project_setting":
			ProjectSettings.set_setting(str(step["name"]), step["value"])
		"play_scene":
			EditorInterface.play_custom_scene(str(step["path"]))
			await _w(int(step.get("frames", 150)))
		"stop_scene":
			EditorInterface.stop_playing_scene()
			await _w(60)
		"dump_controls":
			_dump_controls(str(step.get("name", "controls")))
		"fold":
			return await _fold(str(step["text"]), bool(step.get("open", true)))
		"right_click_row":
			return await _right_click_row(str(step["text"]), float(step.get("x", 400.0)))
		"hover_sheet":
			var area: Rect2 = dock._scroll.get_global_rect()
			var at: Vector2 = area.position + Vector2(float(step.get("x", 300.0)), float(step.get("y", 40.0)))
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.position = at
			motion.global_position = at
			root.push_input(motion)
			await _w(12)
		"click_row":
			return await _click_row(str(step["text"]), float(step.get("x", 260.0)))
		"click_control":
			return await _click_control(str(step["class"]), str(step.get("text", "")))
		_:
			_log("unknown step %s" % step["do"])
			return false
	return true


## Every visible control of the editor as `path<TAB>class<TAB>text<TAB>rect`, to find the one a step names.
func _dump_controls(file_name: String) -> void:
	var file: FileAccess = FileAccess.open(_out.path_join("%s.txt" % file_name), FileAccess.WRITE)
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree():
			file.store_line("%s	%s	%s	%s" % [root.get_path_to(control), control.get_class(), str(control.get("text")) if "text" in control else "", control.get_global_rect()])
	file.close()


func _close_popups() -> void:
	for win: Window in root.get_embedded_subwindows():
		if win.visible:
			win.hide()


func _scene_node(path: String) -> Node:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return null
	return scene_root if path == "." else scene_root.get_node_or_null(path)


## A sheet is ready when the "Opening <file>" strip is gone and its row count has stopped moving.
func _wait_sheet(path: String) -> bool:
	var dock: Object = EventSheets._dock
	var last: int = -1
	var steady: int = 0
	for frame: int in 1800:
		await process_frame
		var rows: int = dock._viewport.get_total_row_count() if dock._viewport != null else 0
		if rows > 0 and rows == last and not dock._open_progress.is_opening(path):
			steady += 1
			if steady >= 25:
				return true
		else:
			steady = 0
		last = rows
	_log("sheet never settled %s" % path)
	return false


func _keycode(name: String) -> Key:
	return OS.find_keycode_from_string(name)


## One key press and release, pushed to the editor window the way the keyboard would deliver it.
func _key(code: Key, mods: Array = []) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		event.shift_pressed = mods.has("shift")
		event.ctrl_pressed = mods.has("ctrl")
		event.alt_pressed = mods.has("alt")
		root.push_input(event)
		await _w(2)


func _all_of(class_name_: String, from: Node) -> Array[Node]:
	return from.find_children("*", class_name_, true, false)


func _visible_menus() -> Array[PopupMenu]:
	var menus: Array[PopupMenu] = []
	for node: Node in _all_of("PopupMenu", root):
		var menu: PopupMenu = node as PopupMenu
		if menu.visible:
			menus.append(menu)
	return menus


## Opens a menu of the dock's strip and walks `path` down it with the arrow keys, which is what a person
## does without a mouse. The last item stays highlighted, and a submenu opens beside the one before it.
func _menu_open(button_text: String, path: Array, activate: bool = false) -> bool:
	var dock: Object = EventSheets._dock
	var button: MenuButton = null
	if button_text == "@open":
		# A menu a dock call already opened (it places itself from the real cursor, so it is moved first).
		var shown: Array[PopupMenu] = _visible_menus()
		if shown.is_empty():
			_log("no menu is open")
			return false
		shown[0].position = Vector2i(330, 120)
		_focus = Rect2i(shown[0].position, shown[0].size)
		_has_focus = true
		return await _walk_menu(shown[0], path, activate)
	if button_text == "@play":
		button = dock._menu_bar.play_button().menu()
	for node: Node in ([] if button != null else _all_of("MenuButton", dock)):
		var candidate: MenuButton = node as MenuButton
		if candidate.is_visible_in_tree() and candidate.text.strip_edges().ends_with(button_text):
			button = candidate
			break
	if button == null:
		_log("no menu button %s" % button_text)
		return false
	_focus = Rect2i(dock._toolbar.get_global_rect())
	_has_focus = true
	button.show_popup()
	await _w(12)
	return await _walk_menu(button.get_popup(), path, activate)


## Walks `path` down an open menu with the arrow keys; the last item stays highlighted.
func _walk_menu(first: PopupMenu, path: Array, activate: bool) -> bool:
	var menu: PopupMenu = first
	_last_menu = first
	for label: Variant in path:
		var index: int = -1
		for i: int in menu.item_count:
			if menu.get_item_text(i).strip_edges() == str(label):
				index = i
				break
		if index < 0:
			var items: PackedStringArray = PackedStringArray()
			for i: int in menu.item_count:
				items.append(menu.get_item_text(i))
			_log("no menu item %s among: %s" % [label, " | ".join(items)])
			return false
		menu.set_focused_item(index)
		await _w(6)
		var submenu: PopupMenu = menu.get_item_submenu_node(index)
		if submenu != null:
			await _key(KEY_RIGHT)
			await _w(10)
			if not submenu.visible:
				_log("submenu %s did not open" % label)
				return false
			menu = submenu
			_last_menu = submenu
	if activate:
		await _key(KEY_ENTER)
		await _w(20)
	await _w(20)
	return true


## Puts the rows from the one holding `from` to the one holding `to` at the top of the sheet and keeps
## that part of the canvas for the picture.
func _view_rows(step: Dictionary) -> bool:
	var dock: Object = EventSheets._dock
	var view: EventSheetViewport = dock._viewport
	var first: int = _find_row(view, step["from"])
	if first < 0:
		_log("no row reads %s" % step["from"])
		return false
	var last: int = first
	if str(step.get("to", "")) != "":
		last = _find_row(view, step["to"], first)
		if last < 0:
			_log("no row reads %s" % step["to"])
			return false
	var scroll: ScrollContainer = dock._scroll
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = maxi(0, int(view.get_row_top(first)) - 4)
	await _w(6)
	var area: Rect2i = Rect2i(scroll.get_global_rect())
	var top: int = int(view.get_global_position().y + view.get_row_top(first)) - 4
	var bottom: int = int(view.get_global_position().y + view.get_row_top(last) + view.get_row_height(last)) + 4
	if int(step.get("height", 0)) > 0:
		bottom = top + int(step["height"])
	top = maxi(top, area.position.y)
	bottom = mini(bottom, area.end.y)
	_row_rect = Rect2i(area.position.x, top, mini(area.size.x, int(step.get("width", 1200))), bottom - top)
	_focus = _row_rect
	_has_focus = true
	return true


func _row_text(view: EventSheetViewport, index: int) -> String:
	var data: EventRowData = view.get_row_data(index)
	if data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: EventSheetSemanticSpan in data.spans:
		parts.append(span.text)
	return " ".join(parts)


func _find_row(view: EventSheetViewport, text: Variant, after: int = -1) -> int:
	if text is int or text is float:
		return int(text)
	if str(text) == "@last":
		return view.get_total_row_count() - 1
	var needle: String = str(text).to_lower()
	for index: int in range(maxi(after, 0), view.get_total_row_count()):
		if _row_text(view, index).to_lower().contains(needle):
			return index
	return -1


func _fold(text: String, open: bool) -> bool:
	var view: EventSheetViewport = EventSheets._dock._viewport
	var index: int = _find_row(view, text)
	if index < 0:
		_log("no row to fold: %s" % text)
		return false
	var data: EventRowData = view.get_row_data(index)
	if data.folded == open:
		view.toggle_row_fold_by_uid(data.row_uid)
	await _w(10)
	return true


## A real right click on a canvas row: hover first (eight frames), then press and release. The dock opens
## its menu where the real cursor is, which a pushed event never moves and a harness must not move, so the
## menu is then put where the click was, inside the window.
func _right_click_row(text: String, x: float = 400.0) -> bool:
	var dock: Object = EventSheets._dock
	var view: EventSheetViewport = dock._viewport
	var index: int = _find_row(view, text)
	if index < 0:
		_log("no row to click: %s" % text)
		return false
	dock._scroll.scroll_vertical = maxi(0, int(view.get_row_top(index)) - 40)
	await _w(6)
	var at: Vector2 = Vector2(view.get_global_position().x + x,
		view.get_global_position().y + view.get_row_top(index) + view.get_row_height(index) * 0.5)
	await _click_at(at, MOUSE_BUTTON_RIGHT)
	for menu: PopupMenu in _visible_menus():
		var spot: Vector2i = Vector2i(at) + Vector2i(40, 4)
		spot.x = mini(spot.x, root.size.x - menu.size.x - 4)
		spot.y = mini(spot.y, root.size.y - menu.size.y - 4)
		menu.position = spot
	_focus = Rect2i(Vector2i(view.get_global_position()) + Vector2i(0, int(view.get_row_top(index))),
		Vector2i(int(view.size.x), int(view.get_row_height(index))))
	_has_focus = true
	await _w(6)
	return true


## A real left click on a canvas row, `x` pixels in from the left edge of the sheet.
func _click_row(text: String, x: float) -> bool:
	var dock: Object = EventSheets._dock
	var view: EventSheetViewport = dock._viewport
	var index: int = _find_row(view, text)
	if index < 0:
		_log("no row to click: %s" % text)
		return false
	dock._scroll.scroll_vertical = maxi(0, int(view.get_row_top(index)) - 40)
	await _w(6)
	await _click_at(Vector2(view.get_global_position().x + x,
		view.get_global_position().y + view.get_row_top(index) + minf(view.get_row_height(index) * 0.5, 14.0)), MOUSE_BUTTON_LEFT)
	return true


func _click_at(at: Vector2, button: MouseButton) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	await _w(8)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
		await _w(2)
	await _w(8)


## Finds a visible control by class and, when given, text, hovers it for eight frames and clicks it.
func _click_control(class_name_: String, text: String) -> bool:
	for node: Node in _all_of(class_name_, EventSheets._dock):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		if text != "" and str(control.get("text")).strip_edges() != text:
			continue
		var rect: Rect2 = control.get_global_rect()
		await _click_at(rect.position + rect.size * 0.5, MOUSE_BUTTON_LEFT)
		return true
	_log("no control %s %s" % [class_name_, text])
	return false


## The text caret blinks, and which half of the blink a capture lands on would differ from run to run.
func _quiet_carets() -> void:
	# The editor's error toasts (the deliberately broken test scripts the plugin's background scan loads
	# raise them) fade on a timer, so they must not be in a picture at all.
	for node: Node in root.find_children("*", "Control", true, false):
		if node.get_class() == "EditorToaster":
			(node as Control).visible = false
	for node: Node in _all_of("LineEdit", root):
		(node as LineEdit).caret_blink = false
	for node: Node in _all_of("TextEdit", root):
		(node as TextEdit).caret_blink = false


func _popup_rect() -> Rect2i:
	var top: Window = null
	for win: Window in root.get_embedded_subwindows():
		if win.visible and not (win is PopupMenu):
			top = win
	if top == null:
		return Rect2i()
	var title: int = top.get_theme_constant("title_height", "Window")
	return Rect2i(top.position - Vector2i(0, title), top.size + Vector2i(0, title))


func _grab(shot: Dictionary, shot_name: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var whole: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	var rect: Rect2i = whole
	var crop: String = str(shot.get("crop", "rows" if shot.has("rows") else ("sheet" if shot.has("source") else "window")))
	match crop:
		"main_screen":
			rect = Rect2i(EditorInterface.get_editor_main_screen().get_global_rect())
		"sheet":
			rect = Rect2i(EventSheets._dock._scroll.get_global_rect())
			rect.size.x = mini(rect.size.x, 1200)
			if int(shot.get("height", 0)) > 0:
				rect.size.y = mini(rect.size.y, int(shot["height"]))
		"rows":
			rect = _row_rect
		"inspector":
			rect = Rect2i(EditorInterface.get_inspector().get_parent().get_global_rect())
		"popup":
			rect = _popup_rect()
			if rect.size == Vector2i.ZERO:
				_log("%s: no window is open" % shot_name)
				return null
		"menus":
			rect = _focus if _has_focus else Rect2i()
			for menu: PopupMenu in _visible_menus():
				rect = Rect2i(menu.position, menu.size) if rect.size == Vector2i.ZERO else rect.merge(Rect2i(menu.position, menu.size))
			rect = rect.grow(4)
		"submenu":
			if _last_menu != null:
				rect = Rect2i(_last_menu.position, _last_menu.size).grow(4)
		"rect":
			var given: Array = shot["rect"]
			rect = Rect2i(int(given[0]), int(given[1]), int(given[2]), int(given[3]))
		"strip":
			rect = Rect2i(EventSheets._dock._toolbar.get_global_rect()).grow(4)
			rect.position.y += int(shot.get("trim_top", 0))
			rect.size.y -= int(shot.get("trim_top", 0))
		"code":
			for node: Node in _all_of("CodeEdit", EventSheets._dock):
				if (node as Control).is_visible_in_tree():
					rect = Rect2i((node as Control).get_global_rect())
					break
			if int(shot.get("height", 0)) > 0:
				rect.size.y = mini(rect.size.y, int(shot["height"]))
		"top":
			rect = Rect2i(EditorInterface.get_editor_main_screen().get_global_rect())
			rect.size.y = mini(rect.size.y, int(shot.get("height", 120)))
	rect = rect.intersection(whole)
	if rect.size.x < 8 or rect.size.y < 8:
		_log("%s: the crop %s is empty" % [shot_name, crop])
		return null
	return image.get_region(rect)


func _save(shot: Dictionary, cropped: Image) -> void:
	var path: String = _out.path_join("%s.png" % shot["name"])
	cropped.save_png(path)
	_log("saved %s %s sha=%s" % [path.get_file(), cropped.get_size(), FileAccess.get_sha256(path).left(16)])
	if str(_args.get("install", "")) == "1" and shot.has("target"):
		var target: String = ProjectSettings.globalize_path("res://").path_join(str(shot["target"]))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		cropped.save_png(target)
