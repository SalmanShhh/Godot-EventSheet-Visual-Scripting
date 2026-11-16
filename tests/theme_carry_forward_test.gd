# Godot EventSheets - Four things the theme work left reading wrong.
#
# The Section's right-click menu says Section in every entry, the Shared sheet window's title says Shared
# sheets, the Theme Editor's opening note is true for a script sheet, and the Sheet theme menu still ticks
# the theme a sheet wears after a Density pick.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_carry_forward_test"
const DENSITY_PATH := "res://addons/eventsheet/themes/density/spacious_density.tres"
const THEME_PATH := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SCRIPT_TEXT := "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"ready\")\n"


static func run() -> bool:
	var ok: bool = true
	ok = _section_menu() and ok
	ok = _shared_sheet_title() and ok
	ok = _window_note() and ok
	ok = _density_keeps_the_tick() and ok
	return ok


static func _labels(menu: PopupMenu) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for i: int in range(menu.item_count):
		if not menu.is_item_separator(i):
			labels.append(menu.get_item_text(i))
	return labels


static func _section_menu() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var group_row: EventRowData = EventRowData.new()
	group_row.row_type = EventRowData.RowType.GROUP
	editor._context_row = group_row
	editor._context_menus._build_row_context_menu(group_row)
	var group_labels: PackedStringArray = _labels(editor._row_context_menu)
	var menu_source: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/dock/context_menus.gd")
	var ok: bool = SUPPORT.pins(P + ": menu", [
		["the section menu folds one Section", group_labels.has("Open / Close Section"), true],
		["and all of them", group_labels.has("Open All / Close All Sections"), true],
		["and never says Group beside Edit Section", group_labels.has("Open / Close Group") or group_labels.has("Open All / Close All Groups"), false],
		["a selection is put into a new Section, not a Group", menu_source.contains("translate(\"Group Selection into New Group\")"), false],
	])
	editor.free()
	return ok


static func _shared_sheet_title() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	editor._includes.open()
	var title: String = editor._includes._include_manager_window.title
	editor._includes._include_manager_window.hide()
	editor.free()
	return SUPPORT.check(P, "the Shared sheet window's title says Shared sheets", title.begins_with("Shared Sheets in "), true)


static func _window_note() -> bool:
	var window: EventSheetThemeEditor = EventSheetThemeEditor.new()
	var dock: Control = preload("res://tests/theme_window_files_test.gd").recorder_dock()
	window._prepare(dock, null)
	var for_sheet: String = window._note.text
	window._dialog.free()
	dock.free()
	var script_dock: Control = Control.new()
	var script_source: GDScript = GDScript.new()
	script_source.source_code = "extends Control\nvar _current_sheet_path: String = \"res://probe.gd\"\nfunc apply_theme_style(_style) -> void:\n\tpass\nfunc _set_status(_text: String, _is_error: bool = false) -> void:\n\tpass\n"
	script_source.reload()
	script_dock.set_script(script_source)
	var script_window: EventSheetThemeEditor = EventSheetThemeEditor.new()
	script_window._prepare(script_dock, null)
	var for_script: String = script_window._note.text
	script_window._dialog.free()
	script_dock.free()
	return SUPPORT.pins(P + ": note", [
		["a sheet saved as a resource keeps the old sentence", for_sheet, "Apply writes this look into the open sheet only"],
		["a script sheet is told nothing is written into the script", for_script.contains("Nothing is written into the script"), true],
		["and the note stays two short sentences", for_script.count(". ") <= 1, true],
	])


static func _density_keeps_the_tick() -> bool:
	var path: String = SUPPORT.own_path("tick_probe_sheet.gd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SCRIPT_TEXT)
	file.close()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(path)
	var manager: EventSheetThemeManager = dock._theme_manager
	var menu: PopupMenu = manager._theme_menu
	if menu == null or not ResourceLoader.exists(DENSITY_PATH):
		dock.free()
		return SUPPORT.check(P, "the Sheet theme menu exists to be ticked", menu != null, true)
	dock.load_theme_style_from_path(THEME_PATH)
	manager.apply_density_path(DENSITY_PATH)
	# The menu is filled again each time View opens.
	manager._populate_theme_menu()
	var ticked: PackedStringArray = PackedStringArray()
	for i: int in range(menu.item_count):
		if menu.is_item_checkable(i) and menu.is_item_checked(i) and str(menu.get_item_metadata(i)) != EventSheetThemeManager.DENSITY_SUBMENU_METADATA:
			ticked.append(menu.get_item_text(i))
	var ok: bool = SUPPORT.check(P, "after a Density pick the menu still ticks the theme the sheet wears", ticked, PackedStringArray(["Classic Sheet"]))
	dock.use_default_theme()
	dock.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok
