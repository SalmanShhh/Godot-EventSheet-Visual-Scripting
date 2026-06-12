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

func _popup_menu(paths: PackedStringArray) -> void:
	match slot:
		EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE:
			if paths.size() == 1:
				add_context_menu_item("Attach Event Sheet", _on_attach_requested)
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM:
			for path: String in paths:
				if EventSheetWorkflow.is_openable_as_sheet(path):
					add_context_menu_item("Open as Event Sheet", _on_open_requested)
					break
		EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR:
			add_context_menu_item("Open as Event Sheet", _on_open_requested)

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
