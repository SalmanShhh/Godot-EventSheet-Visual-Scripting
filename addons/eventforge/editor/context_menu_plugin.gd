# Godot EventSheets — editor context-menu entries (Scene dock / FileSystem / script
# editor), one thin EditorContextMenuPlugin instantiated per slot by plugin.gd.
# Cores live in EventSheetWorkflow; callbacks are injected Callables so this class
# never reaches into the dock directly. NOTE: like EditorDebuggerPlugin, this editor
# class is glue — never instantiate it in headless tests.
@tool
class_name EventSheetContextMenu
extends EditorContextMenuPlugin

var slot: int = -1
var open_sheet: Callable = Callable()    # Callable(path: String)
var attach_sheet: Callable = Callable()  # Callable(node: Node)
var goto_row: Callable = Callable()      # Callable(script_path: String)


func _popup_menu(paths: PackedStringArray) -> void:
	match slot:
		EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE:
			if paths.size() == 1:
				add_context_menu_item("Attach Event Sheet", _on_attach_requested)
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM:
			# Right-clicking ANY .gd (or a sheet .tres) in the FileSystem offers "Open as Event Sheet" —
			# a GDScript-backed sheet opens an arbitrary script losslessly. The Script glyph makes the item
			# easy to spot among Godot's native file actions.
			if should_offer_open_as_sheet(slot, paths):
				add_context_menu_item("Open as Event Sheet", _on_open_requested, _open_as_sheet_icon())
		EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR:
			add_context_menu_item("Open as Event Sheet", _on_open_requested, _open_as_sheet_icon())
			for path: String in paths:
				if not EventSheetProjectDoctor.sheet_for_script(path).is_empty():
					add_context_menu_item("Go to Sheet Row", _on_goto_row_requested)
					break


## True when this slot + paths should offer "Open as Event Sheet". Pure + static so the decision is
## unit-testable WITHOUT instantiating this editor-only plugin: the script editor always offers it (the
## open buffer is a .gd), and the FileSystem offers it whenever any selected path is a .gd or an
## EventSheet .tres (per EventSheetWorkflow.is_openable_as_sheet).
static func should_offer_open_as_sheet(menu_slot: int, paths: PackedStringArray) -> bool:
	if menu_slot == EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR:
		return true
	if menu_slot == EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM:
		for path: String in paths:
			if EventSheetWorkflow.is_openable_as_sheet(path):
				return true
	return false


## The editor "Script" glyph for the menu item (a .gd opened as a sheet); null headless / pre-theme.
static func _open_as_sheet_icon() -> Texture2D:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_theme: Theme = EditorInterface.get_editor_theme()
		if editor_theme != null and editor_theme.has_icon("Script", "EditorIcons"):
			return editor_theme.get_icon("Script", "EditorIcons")
	return null


func _on_goto_row_requested(targets: Variant) -> void:
	if goto_row.is_valid() and targets is Array and not (targets as Array).is_empty():
		var entry: Variant = (targets as Array)[0]
		goto_row.call((entry as Script).resource_path if entry is Script else str(entry))


func _on_attach_requested(targets: Variant) -> void:
	if attach_sheet.is_valid() and targets is Array and not (targets as Array).is_empty() and (targets as Array)[0] is Node:
		attach_sheet.call((targets as Array)[0])


## Slot payloads differ (FileSystem sends paths, the script editor sends Script
## objects) — resolve both to a path.
func _on_open_requested(targets: Variant) -> void:
	if not open_sheet.is_valid():
		return
	var entries: Array = []
	if targets is PackedStringArray:
		for path: String in (targets as PackedStringArray):
			entries.append(path)
	elif targets is Array:
		entries = targets
	for entry: Variant in entries:
		var path: String = (entry as Script).resource_path if entry is Script else str(entry)
		if EventSheetWorkflow.is_openable_as_sheet(path):
			open_sheet.call(path)
			return
