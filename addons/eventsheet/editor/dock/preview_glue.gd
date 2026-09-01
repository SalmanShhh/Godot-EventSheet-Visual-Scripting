@tool
class_name EventSheetPreviewGlue
extends RefCounted
# The .gd-PREVIEW / OPEN-IN-GODOT / LIFT-REPORT cluster. This helper owns:
#   • the read-only .gd-preview banner - the plain-language strip shown when a sheet is opened as a
#     read-only .gd (a lifted GDScript view), with its "Edit Events" unlock and "Open in Godot
#     Script Editor" buttons,
#   • the glue that hands a Script/res:// path to Godot's own script editor
#     (EditorInterface.edit_script) for every "Open in Godot" action (preview, raw-code block,
#     generated code, provider script),
#   • the lift-report window - the Tree that explains, per block, what lifted to events and what
#     stayed verbatim code (EventSheetLiftReport), refreshed for the current sheet on open.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • the preview-banner WIDGET members `_preview_banner` + `_preview_label` - they stay declared on
#     the dock so `_refresh_title_strip()` and the tests can read them by name. `build_preview_banner()`
#     constructs the panel and assigns `_dock._preview_banner` / `_dock._preview_label` back (mirrors
#     the menu_bar "widgets-stay, builder-assigns-back" pattern),
#   • the active-tab state (`_current_sheet`, `_current_sheet_path`) and its `read_only` flag,
#   • the mutation funnel (`_perform_undoable_sheet_edit` / `_mark_dirty` / `_set_status` /
#     `_refresh_after_edit`), plus `_save_backed_sheet`, `_refresh_title_strip`, `_persist_session`,
#     `_clear_undo_history`,
#   • the RAW-CODE dialog (`_raw_code_target` / `_raw_code_edit` / `_raw_code_dialog` - a separate
#     concern that lives on the dock), `_side_panel` / `_code_edit`, and `_provider_list`.
# Globals (EditorInterface, EventSheetLiftReport, GDScriptImporter, …) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures + returns) for every method
# reached from outside this helper - the in-file `.connect(...)` sites, the tests, and the sibling
# dock/ helpers (menu_bar → `_open_lift_report`; sheet_io + session_store → `_refresh_preview_banner`;
# new_addon_panel → `_open_gdscript_path_in_godot`; ace_apply → `_on_preview_edit_requested`) - so
# those callers resolve unchanged.
#
# CLOSURE NOTES:
#   • `_open_raw_code_block_in_godot` hands a lambda to `_dock._perform_undoable_sheet_edit(...)` that
#     captures the LOCALS `target` + `code` (not helper/dock members) - so it survives verbatim; only
#     the surrounding `_dock.` reach-ins changed.
#   • `_open_lift_report` connects `_lift_report_window.close_requested` to a lambda capturing
#     `_lift_report_window`, which lives here too - so the capture is clean.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# ── Lift report: what lifted to events and why each block stayed code ─────────────────────
var _lift_report_window: Window = null
var _lift_report_tree: Tree = null


## The banner's two grounds. A read-only PREVIEW is calm blue: nothing is wrong, the file is simply
## not unlocked yet. A file BLOCKED by an unfinished merge is a warning ground, because it is a state
## rather than a mode - there is no button that opens it, and it must never look like one that merely
## has not been pressed.
const PREVIEW_BANNER_BACKGROUND := Color(0.16, 0.26, 0.40)
const PREVIEW_BANNER_BORDER := Color(0.40, 0.62, 0.95)
const CONFLICT_BANNER_BACKGROUND := Color(0.36, 0.18, 0.14)
const CONFLICT_BANNER_BORDER := Color(0.92, 0.48, 0.34)

## The blocked state's one button, kept by name because the refresh below shows and hides the
## banner's buttons by their role rather than by their position in the row.
var _conflict_button: Button = null


## Builds the read-only preview banner: a clear, plain-language strip with REAL buttons so a
## first-time user knows exactly what is happening and what to do next. Hidden by default.
func build_preview_banner() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "EventSheetPreviewBanner"
	panel.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PREVIEW_BANNER_BACKGROUND
	style.border_color = PREVIEW_BANNER_BORDER
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
	edit_button.tooltip_text = "Start editing this sheet here. From then on, Save (Ctrl+S) updates the file - or use Save As… to keep the original and save a copy."
	edit_button.pressed.connect(_on_preview_edit_requested)
	row.add_child(edit_button)
	var script_button: Button = Button.new()
	script_button.text = "Open in Godot Script Editor"
	script_button.tooltip_text = "Edit the .gd directly in Godot's script editor - your changes reload here when you come back to this tab."
	script_button.pressed.connect(_on_preview_open_in_script_editor)
	row.add_child(script_button)
	# The blocked state's own door, hidden for every ordinary preview. It is a way to LOOK at the two
	# sides side by side rather than an unlock: the banner says the merge tool is where this is
	# finished, and this window is the reading of what is in the way, not a second merge tool.
	_conflict_button = Button.new()
	_conflict_button.name = "EventSheetConflictButton"
	_conflict_button.text = "Show the conflicts"
	_conflict_button.tooltip_text = "Read the two sides of each conflict side by side. Finishing the merge still belongs in the tool you started it in."
	_conflict_button.visible = false
	_conflict_button.pressed.connect(_on_show_conflicts_requested)
	row.add_child(_conflict_button)
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
	# THE ONE SANCTIONED BANNER. Everything else this editor finds about a sheet is a finding, and a
	# finding never says a word in the sheet - it sets the quiet amber row state and its words live in
	# the help strip and the Doctor. A file a merge has not finished with is not a finding: it is a
	# FILE-LEVEL BLOCKING STATE, the file is not GDScript, and a state may say so at the head.
	if _dock._current_sheet.blocked_by_conflict():
		_paint_blocked_banner()
		return
	_paint_banner_ground(PREVIEW_BANNER_BACKGROUND, PREVIEW_BANNER_BORDER)
	if _conflict_button != null:
		_conflict_button.visible = false
	# Back to one trimmed line: an ordinary preview's banner is a note beside the work, and a
	# wrapping one would push the sheet down the screen on every narrow dock.
	_dock._preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_dock._preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A scene read as one sheet has no single file to write back to, so there is nothing to
	# unlock: the banner says what this is and where editing happens instead. The buttons that offer
	# a file go away with it.
	var scene_view: bool = EventSheetSceneSheet.is_scene_sheet(_dock._current_sheet)
	for button: Node in _dock._preview_banner.find_children("", "Button", true, false):
		(button as Button).visible = not scene_view and button != _conflict_button
	if scene_view:
		_dock._preview_label.text = "👁  Reading %s - every script this scene uses, in tree order. Double-click an object bar to open that script and edit it." % EventSheetSceneSheet.scene_path_of(_dock._current_sheet).get_file()
		return
	var source_name: String = _dock._current_sheet.external_source_path.get_file()
	if source_name.is_empty():
		source_name = "this sheet"
	# The lift summary is recomputed from the ACTIVE sheet on every refresh - a cached report went
	# stale the moment you switched tabs between two previews (the banner kept the other sheet's
	# counts). Recomputing is a cheap row walk, and previews are read-only so refreshes are rare.
	var report: Array[Dictionary] = EventSheetLiftReport.for_sheet(_dock._current_sheet)
	_dock._preview_label.text = "👁  Viewing %s as a sheet - just start editing to change it here, or \"Open in Godot Script Editor\" for the code.  (%s)" % [source_name, EventSheetLiftReport.summary(report)]


## The blocked banner: the marker lines named, the reason stated, and the merge tool pointed at. The
## unlock button is not hidden as a courtesy - it is hidden because there is no unlock. The only
## button left is the reading of what is in the way.
func _paint_blocked_banner() -> void:
	_paint_banner_ground(CONFLICT_BANNER_BACKGROUND, CONFLICT_BANNER_BORDER)
	for button: Node in _dock._preview_banner.find_children("", "Button", true, false):
		(button as Button).visible = button == _conflict_button
	# The blocked sentence WRAPS rather than trailing off in an ellipsis. A preview banner may be
	# trimmed because the reader can go on working without reading it; this one names the lines the
	# file is blocked over and where the block is lifted, and a reader who cannot see the end of it
	# is a reader who does not know what to do next.
	_dock._preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock._preview_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var source_name: String = _dock._current_sheet.external_source_path.get_file()
	if source_name.is_empty():
		source_name = "This file"
	_dock._preview_label.text = "⚠  " + EventSheetConflictGuard.banner_text(source_name,
		_dock._current_sheet.conflict_marker_lines)
	if _conflict_button != null:
		# Only offered when there is something to read: a file whose markers are a leftover half of a
		# region has no two sides to put side by side, and a button that opens an empty window is a
		# worse answer than no button.
		_conflict_button.visible = EventSheetConflictRegions.has_conflicts(
			FileAccess.get_file_as_string(_dock._current_sheet.external_source_path))


## Repaints the banner's ground. One place, so the two states cannot drift into looking alike.
func _paint_banner_ground(background: Color, border: Color) -> void:
	var style: StyleBox = _dock._preview_banner.get_theme_stylebox("panel")
	var flat: StyleBoxFlat = style as StyleBoxFlat
	if flat == null:
		return
	flat.bg_color = background
	flat.border_color = border


## "Show the conflicts": the two sides of each region, side by side, read-only until a person picks.
## A door onto the file's own contents, and not an unlock - the sheet behind it stays blocked.
func _on_show_conflicts_requested() -> void:
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path.is_empty():
		return
	_dock._open_conflict_view(_dock._current_sheet.external_source_path)


## "Edit Events": turn the preview into a normal GDScript-backed sheet (Save then compiles
## back to the .gd). The banner flips to a plain warning so the consequence stays obvious.
##
## A BLOCKED FILE HAS NO UNLOCK. The button is not on its banner, but this is the funnel every other
## unlock path in the editor comes through as well (the first intentional edit unlocks a preview), so
## the refusal belongs here rather than on the button that is already gone.
func _on_preview_edit_requested() -> void:
	if _dock._current_sheet == null:
		return
	if _dock._current_sheet.blocked_by_conflict():
		_dock._set_status(EventSheetConflictGuard.save_refusal(
			_dock._current_sheet.external_source_path.get_file()), true)
		return
	_dock._current_sheet.read_only = false
	_refresh_preview_banner()
	_dock._refresh_title_strip()
	_dock._persist_session()  # remember the unlock so the sheet doesn't come back locked next restart
	var source_name: String = _dock._current_sheet.external_source_path.get_file()
	if source_name.is_empty():
		source_name = "this sheet"
	_dock._set_status("Now editing %s - Save (Ctrl+S) saves your changes to the file, or use Save As… to keep a separate copy." % source_name)


## "Open in Godot Script Editor": hand the .gd to Godot's own script editor for direct code edits.
func _on_preview_open_in_script_editor() -> void:
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path.is_empty():
		return
	_open_gdscript_path_in_godot(_dock._current_sheet.external_source_path)


## Hands a Script resource to Godot's own script editor - the shared glue behind every "Open in
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
## of a real file: apply the popup text, compile the sheet back to its .gd, and open that source -
## further edits in Godot reload into the sheet on focus (the existing backed-sheet reload). If the
## sheet doesn't compile, the popup stays open and nothing opens (no stale source / lost edit). A
## block in a .tres sheet has no file behind it; point the user at Save As… → .gd.
func _open_raw_code_block_in_godot() -> void:
	if _dock._raw_code_target == null or _dock._raw_code_edit == null or _dock._current_sheet == null:
		return
	if _dock._current_sheet.external_source_path.is_empty():
		_dock._set_status("Open in Godot edits the sheet's .gd source - Save As… this sheet as a .gd first to edit its code in Godot.", true)
		return
	var target: RawCodeRow = _dock._raw_code_target
	var code: String = _dock._raw_code_edit.text
	var source_path: String = _dock._current_sheet.external_source_path
	_dock._perform_undoable_sheet_edit("Edit Script Block", func() -> bool:
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
		_dock._set_status("Saved and opened %s in Godot - the sheet reloads your edits when you come back." % source_path.get_file())


## "Open in Godot" for the generated GDScript. A code-backed sheet's source IS its generated output -
## open the real .gd. A non-backed (.tres) sheet has no source file (and the generated text often
## declares a class_name, which can't safely be written to a throwaway), so point the user at Save
## As… → .gd; the in-dock panel + Copy stay available for read-only viewing.
func _open_generated_in_godot() -> void:
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path.is_empty():
		_dock._set_status("Open in Godot opens the .gd source - Save As… this sheet as a .gd to open its generated code in Godot (or use Copy).", true)
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
		_lift_report_window.title = "Lift Report - what became events, what stayed code"
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
