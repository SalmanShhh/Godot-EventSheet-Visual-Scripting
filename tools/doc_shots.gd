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
#   static_call {script, method, args}  copy_to_user {from, to}          delete_user {path}      api {method, args}
#   params_dialog {provider, ace, values}   type_text {text}              drag_divider {dx}       end_drag
#   hover_span {row, word}              close_scene                       picker_collapse {text}  rename_file {from, to}
#   report_files {paths}
#   doctor_page {page, select, nth, width, height}   the Project Doctor window drawn with the findings one staged page
#                                       holds (tools/doc_shots/doctor_pages.gd.txt: migration, reading, collisions, scene_trust,
#                                       watch, tidiness); `select` picks a finding row so its fixes show; doctor_release puts back
#                                       what the collisions page set
#   popup_size {width, height, frame}   the top window at an exact size (`frame` counts the title bar in the height)
#   tab {path, index}                   the tab of a TabContainer a dock property path names
#   select_tree_item {path, text, nth, column}   a row of a Tree a dock property path names, chosen by a cell's text
#   snap                                grabs the crop now and keeps it, so one shot can show a window twice (layout horizontal)
#   drag_label {text, dx}               press on a label of the top window and drag right dx pixels (number scrubbing)
#   hover_row {text, x, frames}         the pointer resting on a row until Godot's own tooltip opens (use keep_mouse and crop borderless)
#   (menu_open also takes activate: true to press the last item; a shot may list `cleanup` steps and `parts` with a `layout`;
#   `keep_mouse: true` leaves the pointer where a step put it - otherwise it is parked in a corner before every capture;
#   `crop_top` and `crop_height` keep one stretch of a tall popup)
#
# THE CROPS: `window` (the whole editor), `main_screen`, `sheet` (the sheet canvas), `rows` (the rows named
# by view_rows), `inspector`, `popup` (the top window exactly, title bar in and nothing outside it),
# `inspector_menus` (the Inspector with the menus open on it), `borderless` (a window with no title bar, such as a tooltip), `menus` (every open menu plus the strip it hangs from), `strip`, `top` (the strip and the tab bar) and `submenu` (only the last menu opened), `code` (the code panel) and `rect` ([x, y, w, h]). No scaling: one picture
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
## A window object a step opened and the shot still needs alive (a RefCounted would be freed at once).
var _held: RefCounted = null
## The part being taken and the pictures its `snap` steps already grabbed (a before-and-after in one frame).
var _part: Dictionary = {}
var _part_name: String = ""
var _snaps: Array[Image] = []


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
	var batch: PackedStringArray = str(_args.get("batch", "")).split(",", false)
	for shot: Dictionary in _list["shots"]:
		if not only.is_empty() and not only.has(str(shot["name"])):
			continue
		if not batch.is_empty() and not batch.has(str(shot.get("batch", ""))):
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
	var stashed: PackedStringArray = PackedStringArray()
	var staged: PackedStringArray = await _stage(shot.get("stage", []))
	for part: Dictionary in parts:
		_has_focus = false
		_part = part
		_part_name = str(shot["name"])
		_snaps.clear()
		if EventSheets._dock != null:
			await _show_events()
			await _rest_toolbar()
			EventSheets._dock._reset_lane_split()
			EventSheets._dock._set_status("")
		stashed.append_array(_unstash(str(part.get("source", ""))))
		for step: Dictionary in _steps_of(part):
			ok = await _step(step) and ok
		if not bool(part.get("keep_mouse", false)) and not (str(part.get("crop", "")) in ["menus", "submenu", "popup"]):
			await _park_mouse()
		await _w(8)
		_quiet_carets()
		await _w(4)
		_dump_rows(str(shot["name"]))
		var image: Image = await _grab(part, str(shot["name"]))
		pieces.append_array(_snaps)
		_snaps.clear()
		if image == null:
			ok = false
		else:
			pieces.append(image)
	for step: Dictionary in shot.get("cleanup", []):
		await _step(step)
	for path: String in stashed:
		_remove_stashed(path)
	await _unstage(staged)
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
		"static_call":
			# A static function of a script, for a cache a picture's setting would otherwise find stale.
			(load(str(step["script"])) as GDScript).callv(str(step["method"]), step.get("args", []))
		"copy_to_user":
			# A file a picture needs that must not sit in the project (a script with real errors would
			# break every import), put in the user folder for the shot and removed again by `delete_user`.
			var text: String = FileAccess.get_file_as_string(str(step["from"]))
			var copy: FileAccess = FileAccess.open(str(step["to"]), FileAccess.WRITE)
			copy.store_string(text)
			copy.close()
		"delete_user":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(step["path"])))
		"drag_divider":
			# The Conditions | Actions boundary taken in hand and moved `dx` pixels, and NOT let go (a picture of
			# the guide line the drag draws); `end_drag` lets go.
			var lanes_view: EventSheetViewport = dock._viewport
			var boundary_x: float = lanes_view.get_lane_divider_x(lanes_view._get_logical_canvas_width())
			lanes_view.begin_column_header_drag({"kind": "lane_divider", "boundary_x": boundary_x})
			lanes_view.drag_column_header_to(boundary_x + float(step.get("dx", 60.0)))
			await _w(12)
		"end_drag":
			dock._viewport.end_column_header_drag()
			await _w(6)
		"hover_span":
			# The pointer resting on one word of a row: the row holding `row`, the first span reading `word`.
			var hover_view: EventSheetViewport = dock._viewport
			var hover_row: int = _find_row(hover_view, step["row"])
			if hover_row < 0:
				_log("no row to hover: %s" % step["row"])
				return false
			var hover_data: EventRowData = hover_view.get_row_data(hover_row)
			for span_index: int in hover_data.spans.size():
				if hover_data.spans[span_index].text == str(step["word"]):
					hover_view._set_hover_state(hover_row, span_index)
					hover_view.queue_redraw()
					break
			if hover_view._hover_match_spans.is_empty():
				var said: PackedStringArray = PackedStringArray()
				for span_text: EventSheetSemanticSpan in hover_data.spans:
					said.append(span_text.text)
				_log("no span reads %s among: %s" % [step["word"], " | ".join(said)])
			await _w(12)
		"close_scene":
			EditorInterface.close_scene()
			await _w(20)
		"rename_file":
			# A file renamed the way the FileSystem dock renames one: on disk, the editor told to rescan, and
			# the dock's own moved-files signal sent, which is what the plugin listens to.
			DirAccess.rename_absolute(ProjectSettings.globalize_path(str(step["from"])), ProjectSettings.globalize_path(str(step["to"])))
			EditorInterface.get_resource_filesystem().scan()
			EditorInterface.get_file_system_dock().files_moved.emit(str(step["from"]), str(step["to"]))
			await _w(30)
		"report_files":
			for path: Variant in step["paths"]:
				_log("file %s exists=%s" % [path, FileAccess.file_exists(str(path))])
		"picker_collapse":
			# One section of the Add window's list folded shut (a section named by its heading).
			var picker_tree: Tree = dock._ace_picker._objects_tree
			var section: TreeItem = picker_tree.get_root().get_first_child() if picker_tree.get_root() != null else null
			while section != null:
				if section.get_text(0) == str(step["text"]):
					section.collapsed = true
				section = section.get_next()
			await _w(10)
		"api":
			# One of the public EventSheets calls (open_docs and the like), the way a plugin would make it.
			load("res://addons/eventsheet/api/eventsheets.gd").callv(str(step["method"]), step.get("args", []))
			await _w(int(step.get("frames", 40)))
		"params_dialog":
			# The parameters window of one verb, opened the way the picker opens it, with the values given.
			var definition: ACEDefinition = dock._ace_registry.find_definition(str(step["provider"]), str(step["ace"]))
			if definition == null:
				_log("no verb %s/%s" % [step["provider"], step["ace"]])
				return false
			var context: Dictionary = (step.get("context", {}) as Dictionary).duplicate()
			context["from_picker"] = true
			dock._ace_params.open_with_values(definition, context, step.get("values", {}))
			await _w(int(step.get("frames", 40)))
		"type_text":
			# What a person types into the focused field, set at once (the field's own change signal fires).
			var focused: Control = _typing_target(str(step.get("where", "")), int(step.get("nth", 0)))
			if focused is LineEdit:
				(focused as LineEdit).text = str(step["text"])
				(focused as LineEdit).text_changed.emit(str(step["text"]))
			elif focused is TextEdit:
				(focused as TextEdit).text = str(step["text"])
				(focused as TextEdit).text_changed.emit()
			else:
				_log("nothing focused to type into")
				return false
			await _w(int(step.get("frames", 20)))
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
		"expand_trees":
			# Every folded branch of every visible Tree in the dock opened (the Objects panel keeps Behaviours and Globals folded).
			for tree_node: Node in _all_of("Tree", dock):
				var tree: Tree = tree_node as Tree
				if tree.is_visible_in_tree() and tree.get_root() != null:
					_expand_item(tree.get_root())
			await _w(int(step.get("frames", 15)))
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
			if str(step.get("in", "")) == "popup":
				return await _click_control_in_popup(str(step["class"]), str(step.get("text", "")), int(step.get("nth", 0)))
			return await _click_control(str(step["class"]), str(step.get("text", "")))
		"ask_reply":
			# The answer an Ask box would have got back, fed in so no request leaves the machine.
			dock._ask._show_answer(str(step["reply"]), dock.get_ace_registry().get_all_definitions())
			await _w(int(step.get("frames", 30)))
		"connect_signal_dialog":
			# The window the Scene dock's Connect Signal door opens, for one node of the open scene.
			_held = load("res://addons/eventsheet/editor/connect_signal_dialog.gd").new()
			_held.open(_scene_node(str(step["node"])), str(step["sheet"]), EditorInterface.get_base_control())
			await _w(int(step.get("frames", 40)))
		"unfold":
			# Every foldable section of the top window whose title starts with the words given, opened (and scrolled to).
			var opened: Control = null
			for fold_node: Node in root.find_children("*", "FoldableContainer", true, false):
				var fold: FoldableContainer = fold_node as FoldableContainer
				if fold.is_visible_in_tree() and fold.title.begins_with(str(step["title"])):
					fold.folded = false
					opened = fold
			await _w(6)
			if opened != null and bool(step.get("scroll", false)):
				var up: Node = opened.get_parent()
				while up != null and not (up is ScrollContainer):
					up = up.get_parent()
				if up != null:
					(up as ScrollContainer).ensure_control_visible(opened)
					await _w(4)
					(up as ScrollContainer).scroll_vertical = int(opened.get_global_rect().position.y - (up as Control).get_global_rect().position.y + (up as ScrollContainer).scroll_vertical) - 4
			await _w(int(step.get("frames", 8)))
			return opened != null
		"static_dock_call":
			# A static function of a script that takes the dock first (the refactor menu's entry points).
			(load(str(step["script"])) as GDScript).callv(str(step["method"]), [dock] + step.get("args", []))
			await _w(int(step.get("frames", 30)))
		"reveal":
			# Scrolls the top window so a button reading `text` is in view (a tall window inside a short one).
			var reveal_top: Window = null
			for win: Window in root.get_embedded_subwindows():
				if win.visible and not (win is PopupMenu):
					reveal_top = win
			if reveal_top == null:
				return false
			for reveal_node: Node in reveal_top.find_children("*", "Button", true, false):
				var reveal_button: Button = reveal_node as Button
				if reveal_button.is_visible_in_tree() and reveal_button.text.strip_edges() == str(step["text"]):
					var scroll_up: Node = reveal_button.get_parent()
					while scroll_up != null:
						if scroll_up is ScrollContainer:
							(scroll_up as ScrollContainer).ensure_control_visible(reveal_button)
						scroll_up = scroll_up.get_parent()
					break
			await _w(int(step.get("frames", 10)))
		"figure_insert":
			# The Add these events button of the first Manual figure on screen, pressed by its own handler.
			var figure_found: bool = false
			for fig_node: Node in root.find_children("*", "Control", true, false):
				if fig_node.get_script() != null and fig_node.get_script().get_global_name() == &"EventSheetDocFigure" and (fig_node as Control).is_visible_in_tree():
					fig_node.call("_on_insert_pressed")
					figure_found = true
					break
			await _w(int(step.get("frames", 30)))
			if not figure_found:
				_log("no figure on screen")
				return false
		"open_menu_button":
			# A MenuButton of the top window opened the way its press opens it (a pushed click on a window drawn inside the editor can miss).
			var menu_top: Window = null
			for win: Window in root.get_embedded_subwindows():
				if win.visible and not (win is PopupMenu):
					menu_top = win
			if menu_top == null:
				_log("no window holds a menu button")
				return false
			for menu_node: Node in menu_top.find_children("*", "MenuButton", true, false):
				var menu_button: MenuButton = menu_node as MenuButton
				if menu_button.is_visible_in_tree() and (str(step.get("text", "")).is_empty() or menu_button.text.strip_edges() == str(step["text"])):
					menu_button.show_popup()
					await _w(int(step.get("frames", 15)))
					return true
			_log("no menu button in the window")
			return false
		"click_inspector":
			# A control of the Inspector found by class and tooltip (or text), clicked like a person would.
			var clicked: bool = false
			var passed: int = 0
			for insp_node: Node in EditorInterface.get_inspector().find_children("*", str(step["class"]), true, false):
				var insp: Control = insp_node as Control
				if not insp.is_visible_in_tree():
					continue
				if str(step.get("tooltip", "")) != "" and insp.tooltip_text != str(step["tooltip"]):
					continue
				if str(step.get("text", "")) != "" and str(insp.get("text")).strip_edges() != str(step["text"]):
					continue
				if passed < int(step.get("nth", 0)):
					passed += 1
					continue
				var irect: Rect2 = insp.get_global_rect()
				await _click_at(irect.position + irect.size * 0.5, MOUSE_BUTTON_LEFT)
				clicked = true
				break
			if not clicked:
				_log("no inspector control %s" % str(step.get("tooltip", step.get("text", ""))))
				return false
		"manual_call":
			# A call on the Manual's browser, wherever the Manual is showing (beside the sheet or in its window).
			var doc_dock: Object = load("res://addons/eventsheet/editor/docs/doc_dock.gd")
			var browser: Object = doc_dock.active_dock().browser() if doc_dock.is_shown_beside() else dock._docs.browser()
			if browser == null:
				_log("the Manual is not open")
				return false
			var walk: PackedStringArray = str(step["method"]).split(".")
			var holder: Object = browser
			for walked: int in walk.size() - 1:
				holder = holder.get(walk[walked])
			holder.callv(walk[walk.size() - 1], step.get("args", []))
			await _w(int(step.get("frames", 30)))
		"edit_resource":
			EditorInterface.edit_resource(load(str(step["path"])))
			await _w(int(step.get("frames", 30)))
		"inspector_unfold_all":
			for section: Node in EditorInterface.get_inspector().find_children("*", "EditorInspectorSection", true, false):
				section.call("unfold")
			await _w(int(step.get("frames", 20)))
		"snap":
			# Grabs the picture as it is now, for a shot that shows the same window twice (before and after).
			var snapped: Image = await _grab(_part, _part_name)
			if snapped == null:
				return false
			_snaps.append(snapped)
		"select_tree_item":
			# A row of a Tree held by the dock (a property path), chosen by the text of one of its cells.
			var tree_owner: Object = dock
			for tree_part: String in str(step["path"]).split("."):
				tree_owner = tree_owner.get(tree_part)
			var wanted: TreeItem = _find_tree_item((tree_owner as Tree).get_root(), str(step["text"]), int(step.get("nth", 0)))
			if wanted == null:
				_log("no tree row %s" % step["text"])
				return false
			(tree_owner as Tree).set_selected(wanted, int(step.get("column", 0)))
			await _w(int(step.get("frames", 20)))
		"drag_label":
			# A press on a label in the top window and a drag to the right, the way a number is scrubbed.
			var drag_top: Window = null
			for win: Window in root.get_embedded_subwindows():
				if win.visible and not (win is PopupMenu):
					drag_top = win
			if drag_top == null:
				return false
			var grabbed: Control = null
			for node: Node in drag_top.find_children("*", "Label", true, false):
				if (node as Label).is_visible_in_tree() and (node as Label).text.strip_edges() == str(step["text"]):
					grabbed = node as Control
					break
			if grabbed == null:
				_log("no label %s to drag" % step["text"])
				return false
			var grab_rect: Rect2 = grabbed.get_global_rect()
			var start: Vector2 = Vector2(drag_top.position) + grab_rect.position + grab_rect.size * 0.5
			var move: InputEventMouseMotion = InputEventMouseMotion.new()
			move.position = start
			move.global_position = start
			root.push_input(move)
			await _w(6)
			var press: InputEventMouseButton = InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = start
			press.global_position = start
			root.push_input(press)
			await _w(3)
			var pieces_of_drag: int = 8
			for part_index: int in range(1, pieces_of_drag + 1):
				var drag_to: Vector2 = start + Vector2(float(step["dx"]) * part_index / pieces_of_drag, 0.0)
				var dragged: InputEventMouseMotion = InputEventMouseMotion.new()
				dragged.position = drag_to
				dragged.global_position = drag_to
				dragged.relative = Vector2(float(step["dx"]) / pieces_of_drag, 0.0)
				dragged.button_mask = MOUSE_BUTTON_MASK_LEFT
				root.push_input(dragged)
				await _w(3)
			var release: InputEventMouseButton = InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			release.position = start + Vector2(float(step["dx"]), 0.0)
			release.global_position = release.position
			root.push_input(release)
			await _w(int(step.get("frames", 10)))
		"hover_row":
			# The real pointer resting on a word of a row long enough for Godot's own tooltip to open.
			var tip_view: EventSheetViewport = dock._viewport
			var tip_row: int = _find_row(tip_view, step["text"])
			if tip_row < 0:
				_log("no row to hover: %s" % step["text"])
				return false
			dock._scroll.scroll_vertical = maxi(0, int(tip_view.get_row_top(tip_row)) - 40)
			await _w(6)
			var tip_at: Vector2 = Vector2(tip_view.get_global_position().x + float(step.get("x", 200.0)),
				tip_view.get_global_position().y + tip_view.get_row_top(tip_row) + minf(tip_view.get_row_height(tip_row) * 0.5, 14.0))
			for nudge: int in 6:
				var tip_move: InputEventMouseMotion = InputEventMouseMotion.new()
				tip_move.position = tip_at + Vector2(float(nudge % 2), 0.0)
				tip_move.global_position = tip_move.position
				root.push_input(tip_move)
				await _w(10)
			await _w(int(step.get("frames", 90)))
		"doctor_page":
			# The Project Doctor window drawn with the findings of one staged page (tools/doc_shots/doctor_pages.gd):
			# the window's own page code, without the audit of this repository's own files behind it. `select` names
			# a finding row to select, so the fixes it offers show under it.
			var panel: Object = dock._doctor
			if panel._doctor_window == null:
				panel._build()
			panel._doctor_window.size = Vector2i(int(step.get("width", 1120)), int(step.get("height", 720)))
			EventSheetWindowPlacement.popup_centered(panel._doctor_window)
			var staged_findings: Array = _doctor_pages().call("findings", str(step["page"]))
			panel._draw_page(staged_findings)
			await _w(20)
			if step.has("select"):
				var chosen: TreeItem = _find_tree_item(panel._doctor_tree.get_root(), str(step["select"]), int(step.get("nth", 0)))
				if chosen == null:
					_log("no finding row %s" % step["select"])
					return false
				panel._doctor_tree.set_selected(chosen, 3)
				await _w(20)
		"doctor_release":
			_doctor_pages().call("release_collisions")
		"popup_size":
			# The top window at an exact size, so a picture keeps the frame it always had.
			var sized: Window = null
			for win: Window in root.get_embedded_subwindows():
				if win.visible and not (win is PopupMenu):
					sized = win
			if sized == null:
				_log("popup_size: no window is open")
				return false
			var title_bar: int = sized.get_theme_constant("title_height", "Window")
			# `frame: true` sizes the whole picture (title bar included) instead of the window under it.
			sized.size = Vector2i(int(step["width"]), int(step["height"]) - (title_bar if bool(step.get("frame", false)) else 0))
			sized.position = Vector2i((root.size.x - sized.size.x) / 2, maxi((root.size.y - sized.size.y) / 2, sized.get_theme_constant("title_height", "Window")))
			await _w(int(step.get("frames", 20)))
		"tab":
			# A tab of the TabContainer found by a dock property path (for example "_save_studio._tabs").
			var holder_tabs: Object = dock
			for part: String in str(step["path"]).split("."):
				holder_tabs = holder_tabs.get(part)
			(holder_tabs as TabContainer).current_tab = int(step["index"])
			await _w(int(step.get("frames", 20)))
		_:
			_log("unknown step %s" % step["do"])
			return false
	return true


## The staged Doctor pages, compiled from their text file at run time. They live in a `.txt` so the editor's
## own self-reading sample of project scripts is never shifted by a file that exists only to take pictures.
func _doctor_pages() -> GDScript:
	var pages: GDScript = GDScript.new()
	pages.source_code = FileAccess.get_file_as_string("res://tools/doc_shots/doctor_pages.gd.txt")
	pages.reload()
	return pages


func _find_tree_item(from: TreeItem, text: String, nth: int) -> TreeItem:
	var found: Array[TreeItem] = []
	var stack: Array[TreeItem] = [from]
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		for column: int in item.get_tree().columns:
			if item.get_text(column).contains(text):
				found.append(item)
				break
		var children: Array[TreeItem] = item.get_children()
		children.reverse()
		stack.append_array(children)
	return found[nth] if nth < found.size() else null


func _expand_item(item: TreeItem) -> void:
	item.collapsed = false
	var child: TreeItem = item.get_first_child()
	while child != null:
		_expand_item(child)
		child = child.get_next()


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


## The field a `type_text` step fills: the focused one, or (when a window is open and the step names one with `where`, the text the field holds now, or `nth`) a field found in the top window - a window opened by a call has no focus until a person clicks.
func _typing_target(where: String, nth: int) -> Control:
	var top: Window = null
	for win: Window in root.get_embedded_subwindows():
		if win.visible and not (win is PopupMenu):
			top = win
	if top != null and where.is_empty() and nth == 0:
		var owner_control: Control = root.gui_get_focus_owner()
		if owner_control != null and top.is_ancestor_of(owner_control):
			return owner_control
	if top == null:
		return root.gui_get_focus_owner()
	var seen: int = 0
	for node: Node in top.find_children("*", "LineEdit", true, false):
		var line: LineEdit = node as LineEdit
		if not line.is_visible_in_tree() or not line.editable:
			continue
		if not where.is_empty() and line.text != where:
			continue
		if seen < nth:
			seen += 1
			continue
		line.grab_focus()
		return line
	for node: Node in top.find_children("*", "TextEdit", true, false):
		if (node as TextEdit).is_visible_in_tree():
			return node as Control
	return root.gui_get_focus_owner()


## Like `_click_control`, inside the top embedded window (a window's controls are placed from the window's own corner).
func _click_control_in_popup(class_name_: String, text: String, nth: int) -> bool:
	var top: Window = null
	for win: Window in root.get_embedded_subwindows():
		if win.visible and not (win is PopupMenu):
			top = win
	if top == null:
		_log("no window to click in")
		return false
	var seen: int = 0
	for node: Node in top.find_children("*", class_name_, true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		if text != "" and str(control.get("text")).strip_edges() != text:
			continue
		if seen < nth:
			seen += 1
			continue
		var rect: Rect2 = control.get_global_rect()
		await _click_at(Vector2(top.position) + rect.position + rect.size * 0.5, MOUSE_BUTTON_LEFT)
		return true
	_log("no control %s %s in the window" % [class_name_, text])
	return false


## The pointer a step left over the canvas would light a row or a chip in the picture, and where it stopped
## differs from shot to shot, so it is put over the empty part of the Scene dock before every capture: the
## pointer leaves the sheet (so no row or chip stays lit) and lands on a panel that holds nothing at that spot.
func _park_mouse() -> void:
	var at: Vector2 = Vector2(150, 440)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	await _w(6)
	# A pointer that leaves the canvas does not always tell it so: the row or chip it last lit (and its drag
	# grip) is let go of here.
	if EventSheets._dock != null and EventSheets._dock._viewport != null:
		EventSheets._dock._viewport._set_hover_state(-1, -1)
		EventSheets._dock._viewport.queue_redraw()
		await _w(4)


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
			# `crop_top` drops that many pixels from the top of the window and `crop_height` keeps only the next
			# stretch of it (the part a picture is about).
			var dropped: int = mini(int(shot.get("crop_top", 0)), rect.size.y - 8)
			rect.position.y += dropped
			rect.size.y -= dropped
			if int(shot.get("crop_height", 0)) > 0:
				rect.size.y = mini(rect.size.y, int(shot["crop_height"]))
		"inspector_menus":
			# The Inspector as the editor lays it out, with every menu open on it.
			rect = Rect2i(EditorInterface.get_inspector().get_parent().get_global_rect())
			for menu: PopupMenu in _visible_menus():
				rect = rect.merge(Rect2i(menu.position, menu.size))
		"borderless":
			# A window with no title bar (a tooltip): exactly its own rectangle.
			rect = Rect2i()
			for win: Window in root.get_embedded_subwindows():
				if win.visible and win.borderless:
					rect = Rect2i(win.position, win.size)
			if rect.size == Vector2i.ZERO:
				_log("%s: no tooltip is open" % shot_name)
				return null
		"popups":
			rect = Rect2i()
			for win: Window in root.get_embedded_subwindows():
				if win.visible and not (win is PopupMenu):
					var title_h: int = win.get_theme_constant("title_height", "Window")
					var piece: Rect2i = Rect2i(win.position - Vector2i(0, title_h), win.size + Vector2i(0, title_h))
					rect = piece if rect.size == Vector2i.ZERO else rect.merge(piece)
		"manual_dock":
			rect = Rect2i(load("res://addons/eventsheet/editor/docs/doc_dock.gd").active_dock().get_global_rect())
		"manual_beside":
			rect = Rect2i(load("res://addons/eventsheet/editor/docs/doc_dock.gd").active_dock().get_global_rect()).merge(Rect2i(EditorInterface.get_editor_main_screen().get_global_rect()))
		"figure":
			for fig_node: Node in root.find_children("*", "Control", true, false):
				if fig_node.get_script() != null and fig_node.get_script().get_global_name() == &"EventSheetDocFigure" and (fig_node as Control).is_visible_in_tree():
					var local_rect: Rect2i = Rect2i((fig_node as Control).get_global_rect())
					var frame: Rect2i = Rect2i(Vector2i.ZERO, fig_node.get_window().size) if fig_node.get_window() != root else whole
					if not frame.encloses(local_rect):
						continue
					rect = local_rect
					if fig_node.get_window() != root:
						rect.position += fig_node.get_window().position
					break
		"error_strip":
			var strip_node: Node = EventSheets._dock.find_child("EventSheetRuntimeErrorStrip", true, false)
			if strip_node != null:
				rect = Rect2i((strip_node as Control).get_global_rect()).grow(2)
		"margin":
			rect = Rect2i(_row_rect.position, Vector2i(int(shot.get("width", 72)), _row_rect.size.y))
		"popup_menus":
			rect = _popup_rect()
			for menu: PopupMenu in _visible_menus():
				rect = Rect2i(menu.position, menu.size) if rect.size == Vector2i.ZERO else rect.merge(Rect2i(menu.position, menu.size))
			rect = rect.grow(2)
		"rail":
			rect = Rect2i(EventSheets._dock._rail_panels._root.get_global_rect())
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
	if int(shot.get("scale", 1)) > 1:
		cropped.convert(Image.FORMAT_RGBA8)
		cropped.resize(cropped.get_width() * int(shot["scale"]), cropped.get_height() * int(shot["scale"]), Image.INTERPOLATE_NEAREST)
	cropped.save_png(path)
	_log("saved %s %s sha=%s" % [path.get_file(), cropped.get_size(), FileAccess.get_sha256(path).left(16)])
	if str(_args.get("install", "")) == "1" and shot.has("target"):
		var target: String = ProjectSettings.globalize_path("res://").path_join(str(shot["target"]))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		cropped.save_png(target)


## A sheet resource kept as `<name>.tres.txt` (so the project's own scans never read a sample sheet as one of its
## sheets) is put where the shot names it for the length of the shot. Returns the paths it wrote.
func _unstash(path: String) -> PackedStringArray:
	var written: PackedStringArray = PackedStringArray()
	if path.is_empty() or FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".txt"):
		return written
	var copy: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	copy.store_string(FileAccess.get_file_as_string(path + ".txt"))
	copy.close()
	written.append(path)
	return written


## Files a picture needs at the paths a game would have (`res://scenes/enemy.tscn`, `res://sfx/jump.wav`): each
## `{from, to}` entry copies a fixture to its game path for the length of the shot, so the path resolves while the
## picture is taken and nowhere else. Returns the paths it wrote, for `_unstage`.
func _stage(entries: Array) -> PackedStringArray:
	var written: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		var to: String = str(entry["to"])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to.get_base_dir()))
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(str(entry["from"]))
		var copy: FileAccess = FileAccess.open(to, FileAccess.WRITE)
		copy.store_buffer(bytes)
		copy.close()
		written.append(to)
	if not written.is_empty():
		EditorInterface.get_resource_filesystem().scan()
		await _w(90)
	return written


## Takes the staged files away again with the import and id files the editor wrote beside them, then the folders
## they made once nothing else is in them.
func _unstage(paths: PackedStringArray) -> void:
	var folders: Dictionary = {}
	for path: String in paths:
		for leftover: String in [path, path + ".import", path + ".uid"]:
			if FileAccess.file_exists(leftover):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
		# A table file the editor imported as a translation leaves one generated file per column beside it.
		for generated: String in DirAccess.get_files_at(path.get_base_dir()):
			if generated.begins_with(path.get_file().get_basename() + ".") and generated.ends_with(".translation"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir().path_join(generated)))
		var folder: String = path.get_base_dir()
		while folder != "res://" and not folder.is_empty():
			folders[folder] = true
			folder = folder.get_base_dir()
	var ordered: Array = folders.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for folder: String in ordered:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	if not paths.is_empty():
		EditorInterface.get_resource_filesystem().scan()
		await _w(30)


## Takes a stashed sheet away again, with the compiled script and the id files the editor wrote beside it.
func _remove_stashed(path: String) -> void:
	var base: String = path.get_basename()
	for leftover: String in [path, base + "_generated.gd", base + "_generated.gd.uid"]:
		if FileAccess.file_exists(leftover):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
