# Godot EventSheets - editor context-menu entries (Scene dock / FileSystem / script
# editor), one thin EditorContextMenuPlugin instantiated per slot by plugin.gd.
# Cores live in EventSheetWorkflow; callbacks are injected Callables so this class
# never reaches into the dock directly. NOTE: like EditorDebuggerPlugin, this editor
# class is glue - never instantiate it in headless tests.
@tool
class_name EventSheetContextMenu
extends EditorContextMenuPlugin

# Loaded BY PATH at call time, never named as classes: this plugin registers at editor boot, and
# a class-name reference would compile the whole workflow/doctor subtree (importer + compiler)
# right there. Right-click latency absorbs the one-time load instead; load() caches afterwards.
const WORKFLOW_PATH: String = "res://addons/eventforge/editor/workflow_entry_points.gd"
const PROJECT_DOCTOR_PATH: String = "res://addons/eventforge/project_doctor.gd"

var slot: int = -1
var open_sheet: Callable = Callable()    # Callable(path: String)
var attach_sheet: Callable = Callable()  # Callable(node: Node)
var goto_row: Callable = Callable()      # Callable(script_path: String)
var create_sheet: Callable = Callable()  # Callable(directory: String)
var connect_signal: Callable = Callable()  # Callable(node: Node)


func _popup_menu(paths: PackedStringArray) -> void:
	match slot:
		EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE:
			if paths.size() == 1:
				add_context_menu_item("Attach Event Sheet", _on_attach_requested)
				# Wiring a signal into events, right where signals are wired: offered when
				# the selected node's script pairs with (or is) a sheet.
				add_context_menu_item("Connect Signal to Event Sheet...", _on_connect_signal_requested)
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM:
			# Right-clicking ANY .gd (or a sheet .tres) in the FileSystem offers "Open as Event Sheet" -
			# a GDScript-backed sheet opens an arbitrary script losslessly. The Script glyph makes the item
			# easy to spot among Godot's native file actions.
			if should_offer_open_as_sheet(slot, paths):
				add_context_menu_item("Open as Event Sheet", _on_open_requested, _open_as_sheet_icon())
		EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE:
			# The FileSystem "Create New >" submenu: sit "Event Sheet..." beside the native
			# Folder/Scene/Script/Resource/TextFile entries. The ellipsis matches the siblings
			# (it opens a name + starter dialog). Always offered - creating a file needs no selection.
			if should_offer_create_sheet(slot):
				add_context_menu_item("Event Sheet...", _on_create_sheet_requested, _open_as_sheet_icon())
		EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR:
			add_context_menu_item("Open as Event Sheet", _on_open_requested, _open_as_sheet_icon())
			for path: String in paths:
				if not load(PROJECT_DOCTOR_PATH).sheet_for_script(path).is_empty():
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
			if load(WORKFLOW_PATH).is_openable_as_sheet(path):
				return true
	return false


## True when this slot should offer "Create New > Event Sheet". Pure + static so the decision is
## unit-testable without instantiating this editor-only plugin. Unlike "Open as Event Sheet", the
## create action needs no selection (it mints a new file), so it is offered in the FileSystem
## create slot and nowhere else.
static func should_offer_create_sheet(menu_slot: int) -> bool:
	return menu_slot == EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE


## Resolves the right-clicked FileSystem target to a directory (the folder itself, or the folder
## holding a right-clicked file) and asks the plugin to create a new sheet there. Static + pure so
## the resolution is unit-testable; falls back to res:// when nothing usable comes through.
static func directory_from_targets(targets: Variant) -> String:
	var candidate: String = ""
	if targets is PackedStringArray and not (targets as PackedStringArray).is_empty():
		candidate = (targets as PackedStringArray)[0]
	elif targets is Array and not (targets as Array).is_empty():
		candidate = str((targets as Array)[0])
	candidate = candidate.strip_edges()
	if candidate.is_empty():
		return "res://"
	# A right-clicked FOLDER comes through as the directory itself (no file extension); a
	# right-clicked FILE resolves to its containing folder.
	if candidate.get_extension().is_empty() or DirAccess.dir_exists_absolute(candidate):
		return candidate
	var parent: String = candidate.get_base_dir()
	return parent if not parent.is_empty() else "res://"


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


func _on_connect_signal_requested(targets: Variant) -> void:
	if connect_signal.is_valid() and targets is Array and not (targets as Array).is_empty() and (targets as Array)[0] is Node:
		connect_signal.call((targets as Array)[0])


func _on_create_sheet_requested(targets: Variant) -> void:
	if create_sheet.is_valid():
		create_sheet.call(directory_from_targets(targets))


## Slot payloads differ (FileSystem sends paths, the script editor sends Script
## objects) - resolve both to a path.
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
		if load(WORKFLOW_PATH).is_openable_as_sheet(path):
			open_sheet.call(path)
			return
