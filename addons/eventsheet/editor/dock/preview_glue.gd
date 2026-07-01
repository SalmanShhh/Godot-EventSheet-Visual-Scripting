@tool
extends RefCounted
class_name EventSheetPreviewGlue
# The .gd-PREVIEW / OPEN-IN-GODOT / LIFT-REPORT cluster. This helper owns:
#   • the read-only .gd-preview banner — the plain-language strip shown when a sheet is opened as a
#     read-only .gd (a lifted GDScript view), with its "Edit Events" unlock and "Open in Godot
#     Script Editor" buttons,
#   • the glue that hands a Script/res:// path to Godot's own script editor
#     (EditorInterface.edit_script) for every "Open in Godot" action (preview, raw-code block,
#     generated code, provider script),
#   • the lift-report window — the Tree that explains, per block, what lifted to events and what
#     stayed verbatim code (EventSheetLiftReport), refreshed for the current sheet on open.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • the preview-banner WIDGET members `_preview_banner` + `_preview_label` — they stay declared on
#     the dock so `_refresh_title_strip()` and the tests can read them by name. `build_preview_banner()`
#     constructs the panel and assigns `_dock._preview_banner` / `_dock._preview_label` back (mirrors
#     the menu_bar "widgets-stay, builder-assigns-back" pattern),
#   • the active-tab state (`_current_sheet`, `_current_sheet_path`) and its `read_only` flag,
#   • the mutation funnel (`_perform_undoable_sheet_edit` / `_mark_dirty` / `_set_status` /
#     `_refresh_after_edit`), plus `_save_backed_sheet`, `_refresh_title_strip`, `_persist_session`,
#     `_clear_undo_history`,
#   • the RAW-CODE dialog (`_raw_code_target` / `_raw_code_edit` / `_raw_code_dialog` — a separate
#     concern that lives on the dock), `_side_panel` / `_code_edit`, and `_provider_list`.
# Globals (EditorInterface, EventSheetLiftReport, GDScriptImporter, …) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures + returns) for every method
# reached from outside this helper — the in-file `.connect(...)` sites, the tests, and the sibling
# dock/ helpers (menu_bar → `_open_lift_report`; sheet_io + session_store → `_refresh_preview_banner`;
# new_addon_panel → `_open_gdscript_path_in_godot`; ace_apply → `_on_preview_edit_requested`) — so
# those callers resolve unchanged.
#
# STATE NOTE: `_last_lift_report` lives here now. sheet_io reaches it through the dock's
# `_preview_glue` handle (`_dock._preview_glue._last_lift_report`) when it seeds the report on open.
#
# CLOSURE NOTES:
#   • `_open_raw_code_block_in_godot` hands a lambda to `_dock._perform_undoable_sheet_edit(...)` that
#     captures the LOCALS `target` + `code` (not helper/dock members) — so it survives verbatim; only
#     the surrounding `_dock.` reach-ins changed.
#   • `_open_lift_report` connects `_lift_report_window.close_requested` to a lambda capturing
#     `_lift_report_window`, which lives here too — so the capture is clean.

var _dock: Control = null

func init(dock: Control) -> void:
	_dock = dock

# ── Lift report: what lifted to events and why each block stayed code
# (EventSheetLiftReport; refreshed for the current sheet on open) ─────────────────────
var _last_lift_report: Array[Dictionary] = []
var _lift_report_window: Window = null
var _lift_report_tree: Tree = null

## Builds the read-only preview banner: a clear, plain-language strip with REAL buttons so a
## first-time user knows exactly what is happening and what to do next. Hidden by default.
func build_preview_banner() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "EventSheetPreviewBanner"
	panel.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.26, 0.40)
	style.border_color = Color(0.40, 0.62, 0.95)
	style.set_border_width(SIDE_LEFT, 4)
	style.set_content_margin_all(6.0)
	panel.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_dock._preview_label = Label.new()
	_dock._preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dock._preview_label.text = "Viewing as a sheet"
	row.add_child(_dock._preview_label)
	var edit_button: Button = Button.new()
	edit_button.text = "Edit Events"
	edit_button.tooltip_text = "Start editing this sheet here. From then on, Save (Ctrl+S) updates the file — or use Save As… to keep the original and save a copy."
	edit_button.pressed.connect(_on_preview_edit_requested)
	row.add_child(edit_button)
	var script_button: Button = Button.new()
	script_button.text = "Open in Godot Script Editor"
	script_button.tooltip_text = "Edit the .gd directly in Godot's script editor — your changes reload here when you come back to this tab."
	script_button.pressed.connect(_on_preview_open_in_script_editor)
	row.add_child(script_button)
	return panel

## Shows/updates the preview banner: visible only while previewing a .gd read-only, with the
## source name + a plain-language lift-fidelity summary (events lifted vs. code kept verbatim).
func _refresh_preview_banner() -> void:
	if _dock._preview_banner == null:
		return
	var is_preview: bool = _dock._current_sheet != null and _dock._current_sheet.read_only
	_dock._preview_banner.visible = is_preview
	if not is_preview or _dock._preview_label == null:
		return
	var source_name: String = _dock._current_sheet.external_source_path.get_file()
	if source_name.is_empty():
		source_name = "this sheet"
	_dock._preview_label.text = "👁  Viewing %s as a sheet — just start editing to change it here, or \"Open in Godot Script Editor\" for the code.  (%s)" % [source_name, EventSheetLiftReport.summary(_last_lift_report)]

## "Edit Events": turn the preview into a normal GDScript-backed sheet (Save then compiles
## back to the .gd). The banner flips to a plain warning so the consequence stays obvious.
func _on_preview_edit_requested() -> void:
	if _dock._current_sheet == null:
		return
	_dock._current_sheet.read_only = false
	_refresh_preview_banner()
	_dock._refresh_title_strip()
	_dock._persist_session()  # remember the unlock so the sheet doesn't come back locked next restart
	var source_name: String = _dock._current_sheet.external_source_path.get_file()
	if source_name.is_empty():
		source_name = "this sheet"
	_dock._set_status("Now editing %s — Save (Ctrl+S) saves your changes to the file, or use Save As… to keep a separate copy." % source_name)

## "Open in Godot Script Editor": hand the .gd to Godot's own script editor for direct code edits.
func _on_preview_open_in_script_editor() -> void:
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path.is_empty():
		return
	_open_gdscript_path_in_godot(_dock._current_sheet.external_source_path)

## Hands a Script resource to Godot's own script editor — the shared glue behind every "Open in
## Godot" action. Guarded: a no-op (with a status note) outside the editor or when edit_script is
## unavailable, so headless/runtime callers degrade gracefully. Returns whether it opened.
func _edit_script_in_godot(script: Script, line: int = -1) -> bool:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		_dock._set_status("Open in Godot is only available inside the Godot editor.", true)
		return false
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if script == null or not editor_interface.has_method("edit_script"):
		_dock._set_status("Could not open the script in Godot's editor.", true)
		return false
	editor_interface.call("edit_script", script, line)
	if editor_interface.has_method("set_main_screen_editor"):
		editor_interface.call("set_main_screen_editor", "Script")
	return true

## Opens an existing res:// .gd in Godot's script editor (provider scripts, a backed sheet's source).
func _open_gdscript_path_in_godot(path: String, line: int = -1) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		_dock._set_status("Script not found: %s" % path, true)
		return false
	var script: Resource = load(path)
	if not (script is Script):
		_dock._set_status("%s could not be opened as a GDScript." % path.get_file(), true)
		return false
	return _edit_script_in_godot(script as Script, line)

## "Open in Godot" for the GDScript block in the popup. A block in a code-backed (.gd) sheet IS part
## of a real file: apply the popup text, compile the sheet back to its .gd, and open that source —
## further edits in Godot reload into the sheet on focus (the existing backed-sheet reload). If the
## sheet doesn't compile, the popup stays open and nothing opens (no stale source / lost edit). A
## block in a .tres sheet has no file behind it; point the user at Save As… → .gd.
func _open_raw_code_block_in_godot() -> void:
	if _dock._raw_code_target == null or _dock._raw_code_edit == null or _dock._current_sheet == null:
		return
	if _dock._current_sheet.external_source_path.is_empty():
		_dock._set_status("Open in Godot edits the sheet's .gd source — Save As… this sheet as a .gd first to edit its code in Godot.", true)
		return
	var target: RawCodeRow = _dock._raw_code_target
	var code: String = _dock._raw_code_edit.text
	var source_path: String = _dock._current_sheet.external_source_path
	_dock._perform_undoable_sheet_edit("Edit GDScript Block", func() -> bool:
		if target.code == code:
			return false
		target.code = code
		return true)
	# Refuse to open a stale source: if the sheet doesn't compile, _save_backed_sheet() left a
	# "Save failed: …" status and the .gd on disk is unchanged. Keep the popup open to fix it.
	if not _dock._save_backed_sheet():
		return
	_dock._raw_code_dialog.hide()
	if _open_gdscript_path_in_godot(source_path):
		_dock._set_status("Saved and opened %s in Godot — the sheet reloads your edits when you come back." % source_path.get_file())

## "Open in Godot" for the generated GDScript. A code-backed sheet's source IS its generated output —
## open the real .gd. A non-backed (.tres) sheet has no source file (and the generated text often
## declares a class_name, which can't safely be written to a throwaway), so point the user at Save
## As… → .gd; the in-dock panel + Copy stay available for read-only viewing.
func _open_generated_in_godot() -> void:
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path.is_empty():
		_dock._set_status("Open in Godot opens the .gd source — Save As… this sheet as a .gd to open its generated code in Godot (or use Copy).", true)
		return
	_open_gdscript_path_in_godot(_dock._current_sheet.external_source_path)

## "Open in Godot" for the selected custom-ACE provider script (a real res:// .gd).
func _on_provider_open_in_godot_pressed() -> void:
	if _dock._provider_list == null:
		return
	var selected: PackedInt32Array = _dock._provider_list.get_selected_items()
	if selected.is_empty():
		_dock._set_status("Select a provider script first, then Open in Godot.", true)
		return
	_open_gdscript_path_in_godot(_dock._provider_list.get_item_text(selected[0]))

func _open_lift_report() -> void:
	var report: Array[Dictionary] = EventSheetLiftReport.for_sheet(_dock._current_sheet)
	if _lift_report_window == null:
		_lift_report_window = Window.new()
		_lift_report_window.title = "Lift Report — what became events, what stayed code"
		_lift_report_window.size = Vector2i(640, 400)
		_lift_report_window.close_requested.connect(func() -> void: _lift_report_window.hide())
		_lift_report_tree = Tree.new()
		_lift_report_tree.set_anchors_preset(Control.PRESET_FULL_RECT)
		_lift_report_tree.hide_root = true
		_lift_report_tree.columns = 3
		_lift_report_tree.set_column_title(0, "Kind")
		_lift_report_tree.set_column_title(1, "Row")
		_lift_report_tree.set_column_title(2, "Why it stayed code (and the structured equivalent)")
		_lift_report_tree.set_column_expand(0, false)
		_lift_report_tree.set_column_custom_minimum_width(0, 80)
		_lift_report_tree.set_column_expand(1, false)
		_lift_report_tree.set_column_custom_minimum_width(1, 220)
		_lift_report_tree.column_titles_visible = true
		_lift_report_window.add_child(_lift_report_tree)
		_dock.add_child(_lift_report_window)
	_lift_report_tree.clear()
	var root_item: TreeItem = _lift_report_tree.create_item()
	for entry: Dictionary in report:
		var item: TreeItem = _lift_report_tree.create_item(root_item)
		var kind: String = str(entry.get("kind"))
		item.set_text(0, kind.to_upper())
		item.set_custom_color(0, Color(0.55, 0.85, 0.6) if kind in ["event", "function"] else Color(0.85, 0.78, 0.5))
		item.set_text(1, str(entry.get("label")))
		item.set_text(2, str(entry.get("reason")))
	_dock._set_status("Lift Report: %s." % EventSheetLiftReport.summary(report))
	_lift_report_window.popup_centered()
