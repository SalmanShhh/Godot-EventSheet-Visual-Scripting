@tool
class_name EventSheetThemeManager
extends RefCounted
# Owns loading / applying / picking the editor theme style + the theme file dialog + theme editor +
# the live-reload binding to the active `.tres`. This helper owns:
#   • the theme service methods - use_default_theme / load_theme_style_from_path / reload_active_theme
#     (persist the chosen EventSheetEditorStyle on the sheet, out of undo history - presentation, not
#     content) and the menu/toolbar handlers that drive them (_on_load_theme_requested,
#     _on_reload_theme_requested, _on_set_default_theme_requested, _on_theme_preset_selected),
#   • the theme FILE DIALOG (build_theme_file_dialog / _on_theme_file_selected) that lets a user load
#     an EventSheetEditorStyle .tres/.res from res://,
#   • the visual THEME EDITOR window (_open_theme_editor → EventSheetThemeEditor) + apply_theme_style,
#     the "Apply To Current Sheet" landing point (also reached by theme_editor_dialog.gd via the dock's
#     apply_theme_style delegate),
#   • View ▸ Sheet theme, the per-sheet theme SWITCHER (bind_sheet_theme_menu / _populate_theme_menu /
#     _refresh_theme_menu_selection / _on_theme_preset_selected). The submenu is built by menu_bar.gd
#     and handed over here, which then owns filling it, ticking it and acting on a pick. It replaced
#     an OptionButton on the toolbar; the per-sheet semantics are unchanged,
#   • the LIVE-RELOAD binding to the active style: _active_theme_style + _sync_active_theme_binding
#     (connect/disconnect/swap the style's `changed` signal on tab-switch) + _on_active_theme_style_changed
#     (the handler that repaints when the active `.tres` is edited on disk). The state var and BOTH
#     methods live here, so the signal wiring is fully self-contained.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • `_refresh_title_strip` (the title/identity hub - not theme; apply_theme_style pulls it via _dock),
#   • the active-tab state (`_current_sheet` / `_current_sheet_path`), `_viewport`,
#   • the mutation funnel (`_perform_undoable_sheet_edit` / `_mark_dirty` / `_set_status` /
#     `_refresh_after_edit`) + `_suggest_sheet_directory`.
# Globals (EventSheetEditorStyle / EventSheetThemePresets / EventSheetEditorThemeDeriver /
# EventSheetThemeEditor) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures + returns) for every method
# reached from outside this helper - the in-file call sites, the tests (dock.load_theme_style_from_path
# / dock.reload_active_theme / dock.use_default_theme), menu_bar.gd (_on_load_theme_requested /
# _on_reload_theme_requested / _open_theme_editor / _bind_sheet_theme_menu / _populate_sheet_theme_menu),
# and theme_editor_dialog.gd (which does `_dock.has_method("apply_theme_style")` +
# `_dock.call("apply_theme_style", ...)`) - so those callers resolve unchanged.
#
# STATEFUL-SIGNAL / TEARDOWN NOTE: the dock's `_notification(NOTIFICATION_PREDELETE)` stays on the dock
# but calls `teardown_theme_binding()` here to disconnect the active style's `changed` signal + null the
# field (the binding is owned here, so the teardown lives here too).
#
# HIDDEN-READER NOTE: the dock's `_apply_editor_native_defaults` (a Godot-feel method that stays on the
# dock) reads the active style through `get_active_theme_style()` and re-applies via the dock's
# apply_theme_style delegate - so the field can live here without moving that method.
#
# CLOSURE NOTE: `apply_theme_style` hands a lambda to `_dock._perform_undoable_sheet_edit(...)` that
# captures the LOCAL `style` (not a helper/dock member), so it survives verbatim; only the inner
# `_current_sheet` reach-ins became `_dock.`.

const THEME_FILTERS: Array[String] = ["*.tres ; EventSheetEditorStyle", "*.res ; EventSheetEditorStyle"]

var _dock: Control = null

# The active editor style (the sheet's EventSheetEditorStyle), tracked here so its `changed` signal can
# drive a live repaint when the backing `.tres` is edited on disk. Bound/rebound by
# _sync_active_theme_binding on every tab-switch; torn down by teardown_theme_binding on dock delete.
var _active_theme_style: EventSheetEditorStyle = null
var _theme_editor: EventSheetThemeEditor = null
var _theme_file_dialog: FileDialog = null


func init(dock: Control) -> void:
	_dock = dock


## The dock's Godot-feel path (_apply_editor_native_defaults) reads the active style through this
## getter to decide whether to derive the "Match Editor" default - the field lives here now.
func get_active_theme_style() -> EventSheetEditorStyle:
	return _active_theme_style


func use_default_theme() -> bool:
	if _dock._current_sheet == null or _dock._current_sheet.editor_style == null:
		return false
	# Out of undo history, like every theme switch (presentation, not content).
	_dock._current_sheet.editor_style = null
	_dock._refresh_after_edit()
	return true


func load_theme_style_from_path(path: String) -> bool:
	if _dock._current_sheet == null:
		return false
	var resolved_path: String = path.strip_edges()
	if resolved_path.is_empty():
		_dock._set_status("Theme load failed: no file selected.", true)
		return false
	var loaded: Resource = ResourceLoader.load(resolved_path)
	if not (loaded is EventSheetEditorStyle):
		_dock._set_status("Theme load failed: %s is not an EventSheetEditorStyle." % resolved_path.get_file(), true)
		return false
	# Theme switches stay OUT of the undo history (user call: undo is for sheet
	# content - ACEs and variables - never presentation). Still marks dirty: the
	# style is persisted on the sheet.
	_dock._current_sheet.editor_style = loaded as EventSheetEditorStyle
	_dock._refresh_after_edit()
	_dock._mark_dirty("Applied theme: %s." % resolved_path.get_file())
	return true


func reload_active_theme() -> bool:
	if _dock._current_sheet == null:
		_dock._set_status("Reload theme failed: no sheet loaded.", true)
		return false
	var active_style: EventSheetEditorStyle = _dock._current_sheet.editor_style
	if active_style == null:
		_dock._set_status("Reload theme failed: no active style.", true)
		return false
	var style_path: String = active_style.resource_path
	if style_path.is_empty():
		_dock._set_status("Reload theme failed: active style is unsaved.", true)
		return false
	var reloaded: Resource = ResourceLoader.load(style_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not (reloaded is EventSheetEditorStyle):
		_dock._set_status("Reload theme failed: could not load resource.", true)
		return false
	_dock._current_sheet.editor_style = reloaded as EventSheetEditorStyle
	_dock._refresh_after_edit()
	return true


func build_theme_file_dialog() -> void:
	if _theme_file_dialog != null:
		return
	_theme_file_dialog = FileDialog.new()
	_theme_file_dialog.name = "EventSheetThemeFileDialog"
	_theme_file_dialog.title = "Load EventSheet Theme"
	_theme_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_theme_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_theme_file_dialog.filters = PackedStringArray(THEME_FILTERS)
	_theme_file_dialog.file_selected.connect(_on_theme_file_selected)
	_dock.add_child(_theme_file_dialog)


func _on_load_theme_requested() -> void:
	if _theme_file_dialog == null:
		build_theme_file_dialog()
	if _theme_file_dialog == null:
		_dock._set_status("Theme picker unavailable.", true)
		return
	_theme_file_dialog.current_dir = _dock._suggest_sheet_directory()
	_theme_file_dialog.popup_centered(Vector2i(760, 520))


func _on_theme_file_selected(path: String) -> void:
	load_theme_style_from_path(path)


func _on_set_default_theme_requested() -> void:
	if use_default_theme():
		_dock._mark_dirty("Applied default theme.")
	else:
		_dock._set_status("Default theme already active.", true)


func _on_reload_theme_requested() -> void:
	if reload_active_theme():
		_dock._set_status("Reloaded active theme.")
	else:
		_dock._set_status("Reload theme failed: no active style resource path.", true)


## View ▸ Sheet theme, the per-sheet theme switcher. Held here rather than on the dock because this
## helper is the one that fills it, ticks it and acts on it; the menu itself is built by menu_bar.gd
## and handed over at build time.
var _theme_menu: PopupMenu = null


## The Density submenu that hangs off Sheet theme, and the sentinel its item carries so the two
## loops over the theme menu (the tick sweep and the pick handler) can tell a submenu row from a
## theme row. A submenu row has no theme behind it; ticking one would put a check mark on a door.
const DENSITY_SUBMENU_NAME := "EventSheetSheetDensityMenu"
const DENSITY_SUBMENU_METADATA := "submenu:density"

var _density_menu: PopupMenu = null


## Takes ownership of the View menu’s Sheet theme submenu: fills it now and wires the pick.
func bind_sheet_theme_menu(menu: PopupMenu) -> void:
	if menu == null:
		return
	_theme_menu = menu
	if not _theme_menu.id_pressed.is_connected(_on_theme_preset_selected):
		_theme_menu.id_pressed.connect(_on_theme_preset_selected)
	if _density_menu == null:
		_density_menu = PopupMenu.new()
		_density_menu.name = DENSITY_SUBMENU_NAME
		_density_menu.id_pressed.connect(_on_density_preset_selected)
		_theme_menu.add_child(_density_menu)
	_populate_theme_menu()


## Fills the Sheet theme submenu with "Match Editor (default)" plus every discovered bundled theme,
## the sheet’s own one ticked. Ids are indices into the list this call just built, so the entries
## and the ids can never drift; the menu is refilled every time View opens, which is what lets a
## theme dropped into the themes folder mid-session be pickable with no restart.
func _populate_theme_menu() -> void:
	if _theme_menu == null:
		return
	_theme_menu.clear()
	# The default IS the editor-derived style (see _apply_editor_native_defaults) -
	# label it so a Godot dev knows the sheet already matches their editor.
	_theme_menu.add_radio_check_item(EventSheetL10n.translate("Match Editor (default)"), 0)
	_theme_menu.set_item_metadata(0, "")
	for preset: Dictionary in EventSheetThemePresets.list_presets():
		_theme_menu.add_radio_check_item(str(preset.get("name", "Theme")), _theme_menu.item_count)
		_theme_menu.set_item_metadata(_theme_menu.item_count - 1, str(preset.get("path", "")))
	# Density ▸ - how much room the sheet gives its rows, which is a separate question from what
	# colour it is. Refilled with the theme list for the same reason: a starter dropped into the
	# density folder mid-session is pickable the next time View opens.
	if _density_menu != null:
		_theme_menu.add_separator()
		_theme_menu.add_submenu_item(EventSheetL10n.translate("Density"), DENSITY_SUBMENU_NAME,
			_theme_menu.item_count)
		_theme_menu.set_item_metadata(_theme_menu.item_count - 1, DENSITY_SUBMENU_METADATA)
		_populate_density_menu()
	_refresh_theme_menu_selection()


## Fills the Density submenu with every shipped starter, tightest first, the one this sheet's
## spacing matches ticked. A sheet whose theme states its own numbers matches none of them and ticks
## nothing, which is the honest answer - it is wearing its own density, not a starter.
func _populate_density_menu() -> void:
	if _density_menu == null:
		return
	_density_menu.clear()
	var current: EventSheetDensityStyle = EventSheetDensityStyle.read_from(_active_style_or_default())
	for preset: Dictionary in EventSheetDensityPresets.list_presets():
		var density: EventSheetDensityStyle = preset["density"] as EventSheetDensityStyle
		_density_menu.add_radio_check_item(str(preset.get("name", "Density")), _density_menu.item_count)
		_density_menu.set_item_metadata(_density_menu.item_count - 1, str(preset.get("path", "")))
		_density_menu.set_item_checked(_density_menu.item_count - 1, density.matches(current))


## The style the sheet is actually painted with - its own, or the bundled default a theme-less sheet
## falls back to. The Density tick has to read the second one too, or a fresh sheet would show no
## density ticked while plainly wearing one.
func _active_style_or_default() -> EventSheetEditorStyle:
	if _dock._current_sheet != null and _dock._current_sheet.editor_style != null:
		return _dock._current_sheet.editor_style
	return EventSheetActiveTheme.active()


## Applies a density starter to the current sheet: its six numbers are copied onto a DUPLICATE of
## the sheet's own style, so a starter shared by two sheets is never edited in place and every
## colour the theme states survives untouched. Out of the undo history, like every theme switch.
func _on_density_preset_selected(index: int) -> void:
	if _density_menu == null or index < 0 or index >= _density_menu.item_count:
		return
	var path: String = str(_density_menu.get_item_metadata(index))
	if path.is_empty() or _dock._current_sheet == null:
		return
	var loaded: Resource = ResourceLoader.load(path)
	if not (loaded is EventSheetDensityStyle):
		_dock._set_status("Density load failed: %s is not an EventSheetDensityStyle." % path.get_file(), true)
		return
	var style: EventSheetEditorStyle = _dock._current_sheet.editor_style
	# A theme-less sheet is painted with the editor-derived default. Freezing THAT into a resource
	# is what lets a density be stored at all, and the sheet looks identical the moment it happens -
	# it simply stops re-deriving its colours from the editor theme later on.
	style = (
		style.duplicate(true) as EventSheetEditorStyle
		if style != null
		else EventSheetGodotTheme.adapt_to_editor(EventSheetEditorStyle.new())
	)
	(loaded as EventSheetDensityStyle).apply_to(style)
	_dock._current_sheet.editor_style = style
	# Through the same binding swap a tab switch uses, so the style that just stopped being active
	# lets go of its `changed` signal and the new one takes it up. Setting the field by hand here
	# left the old style connected and the new one deaf to an edit on disk.
	_sync_active_theme_binding()
	_dock._refresh_after_edit()
	_dock._mark_dirty("Row density: %s." % EventSheetDensityPresets._humanize(path.get_file()))
	_populate_density_menu()


## Ticks the entry matching the current sheet’s active theme (Match Editor if none).
func _refresh_theme_menu_selection() -> void:
	if _theme_menu == null:
		return
	var active_path: String = ""
	if _dock._current_sheet != null and _dock._current_sheet.editor_style != null:
		active_path = _dock._current_sheet.editor_style.resource_path
	var target_index: int = 0
	for i in range(_theme_menu.item_count):
		if str(_theme_menu.get_item_metadata(i)) == active_path:
			target_index = i
			break
	for i in range(_theme_menu.item_count):
		if str(_theme_menu.get_item_metadata(i)) == DENSITY_SUBMENU_METADATA:
			continue
		_theme_menu.set_item_checked(i, i == target_index)


## Applies the chosen theme preset (or the built-in default) to the current sheet. Per-sheet, out of
## the undo history, persisted on the sheet resource - exactly what picking one always did.
func _on_theme_preset_selected(index: int) -> void:
	if _theme_menu == null or index < 0 or index >= _theme_menu.item_count:
		return
	var path: String = str(_theme_menu.get_item_metadata(index))
	if path == DENSITY_SUBMENU_METADATA:
		return
	if path.is_empty():
		_on_set_default_theme_requested()
	else:
		load_theme_style_from_path(path)
	_refresh_theme_menu_selection()


func _open_theme_editor() -> void:
	if _theme_editor == null:
		_theme_editor = EventSheetThemeEditor.new()
	_theme_editor.open(_dock, _active_theme_style)


## Called by the theme editor's "Apply To Current Sheet": assigns the working style to the
## active sheet undoably and repaints.
func apply_theme_style(style: EventSheetEditorStyle) -> void:
	if _dock._current_sheet == null or style == null:
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Apply Theme", func() -> bool:
		_dock._current_sheet.editor_style = style
		return true
	)
	if changed:
		_active_theme_style = style
		_publish_active_style()
		_dock._refresh_after_edit()
		_refresh_theme_menu_selection()
		_dock._mark_dirty("Theme applied from the theme editor.")


func _sync_active_theme_binding() -> void:
	var next_style: EventSheetEditorStyle = (
		_dock._current_sheet.editor_style
		if _dock._current_sheet != null and _dock._current_sheet.editor_style != null
		else null
	)
	if _active_theme_style == next_style:
		return
	if _active_theme_style != null and _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
		_active_theme_style.changed.disconnect(_on_active_theme_style_changed)
	_active_theme_style = next_style
	if _active_theme_style != null and not _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
		_active_theme_style.changed.connect(_on_active_theme_style_changed)
	_publish_active_style()


## Hands the active style to the chrome OUTSIDE the canvas - the Object bar, the status strip, the
## Manual - which have no path back to a sheet and read their tokens through EventSheetActiveTheme.
## Called from every point the active style can change, so a theme switch reaches them in the same
## breath it reaches the viewport.
func _publish_active_style() -> void:
	EventSheetActiveTheme.publish(_active_theme_style)


func _on_active_theme_style_changed() -> void:
	if _dock._viewport == null or _dock._current_sheet == null:
		return
	_dock._viewport.set_sheet(_dock._current_sheet)
	_dock._set_status("Theme change detected and reloaded.")


## Called from the dock's _notification(NOTIFICATION_PREDELETE): disconnect the active style's
## `changed` signal + null the field (the binding is owned here, so the teardown lives here too).
func teardown_theme_binding() -> void:
	if _active_theme_style != null and _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
		_active_theme_style.changed.disconnect(_on_active_theme_style_changed)
	_active_theme_style = null
