@tool
class_name EventSheetBehaviourLibraryFlow
extends RefCounted

# The editor's half of the behaviour library: copying a pack in and attaching it, taking one out,
# tidying away the ones nothing uses, and the Welcome's kits. EventSheetPackLibrary answers the
# questions (what a pack needs, who uses it, which folders a kit brings); this file does the work in
# the open editor - the copy, Godot's import of what was copied, the node, the undo step, the trash -
# and says what it did in the dock's status line.
#
# The dock owns one instance and calls init(self). Nothing here is built until somebody adds,
# removes or tidies, so a session that never does pays nothing for it.

## How long an import may take before the flow stops waiting for it and attaches anyway. Godot says
## when a scan has finished; this only stops a scan that never says so from holding the window.
const IMPORT_WAIT_SECONDS := 60.0
## The files a pack folder holds that Godot reads as they are, with no import step.
const READ_AS_IS: PackedStringArray = ["gd", "uid", "gdshader", "gdshaderinc", "tres", "tscn", "res", "md", "txt", "cfg", "json"]

var _dock: Control = null
var _remove_window: ConfirmationDialog = null
var _remove_pack: Dictionary = {}
var _remove_title: Label = null
var _remove_body: Label = null
var _remove_users: EventSheetPopupUI.StateNote = null
var _tidy_window: ConfirmationDialog = null
var _tidy_summary: Label = null
var _tidy_list: VBoxContainer = null
var _tidy_ticks: Dictionary = {}
## Called after a pack is added or removed, so a window that lists packs can show the change.
var on_changed: Callable = Callable()


func init(dock: Control) -> void:
	_dock = dock


# --- adding -------------------------------------------------------------------------------------


## The sentence the Add behaviour window and the status line say once a library pack is in: the
## pack, what came along because it needs it, and how many folders Godot imported.
static func added_sentence(pack_name: String, needed_names: PackedStringArray, imported: int) -> String:
	var folders_said: String = EventSheetL10n.translate("Godot imported 1 folder.") if imported == 1 \
		else EventSheetL10n.translate("Godot imported %d folders.") % imported
	if needed_names.is_empty():
		return EventSheetL10n.translate("Added %s to the project.") % pack_name + " " + folders_said
	return EventSheetL10n.translate("Added %s to the project, with %s it needs.") % [pack_name, _and_list(needed_names)] \
		+ " " + folders_said


## "A", "A and B", "A, B and C".
static func _and_list(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return EventSheetL10n.translate("%s and %s") % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## Copies a library pack and what it needs into the project, waits for Godot to import them, then
## attaches the pack to the object - one undo step that takes the node out and sends the copied
## folders to the trash. Returns {"ok", "message", "node", "copied"}. A coroutine: await it.
func add_and_attach(pack: Dictionary, values: Dictionary, object_label: String) -> Dictionary:
	var pack_dir: String = str(pack.get("dir", ""))
	var wanted: PackedStringArray = EventSheetPackLibrary.folders_to_add(pack_dir)
	var copied: Dictionary = await copy_and_import(wanted)
	if not bool(copied.get("ok", false)):
		_dock._set_status(str(copied.get("message", "")), true)
		return copied
	var added: PackedStringArray = copied.get("copied", PackedStringArray())
	var in_project: Dictionary = EventSheetPackCatalog.describe(pack_dir)
	var host: Node = _dock._scene_node_for_object(object_label)
	if host == null:
		host = _scene_root_named(object_label)
	var needed_names: PackedStringArray = PackedStringArray()
	for folder: String in added:
		if folder != pack_dir:
			needed_names.append(str(EventSheetPackCatalog.describe(folder).get("name", folder)))
	var said: String = added_sentence(str(pack.get("name", pack_dir)), needed_names, added.size())
	if in_project.is_empty() or host == null:
		# The folders are in and stay in: the object is not in the open scene, so there is nothing to
		# attach to yet, and the pack is now one click away in the list.
		var unattached: String = said + " " + EventSheetL10n.translate("Open the scene holding %s to attach it.") % object_label
		_dock._set_status(unattached, false)
		_after_change()
		return {"ok": true, "message": unattached, "copied": added}
	var result: Dictionary = EventSheetAddBehavior.attach_node(in_project, host, values)
	var node: Node = result.get("node") as Node
	if node != null and Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		# The node and the folders are already in; the step only teaches Ctrl+Z to take both back out
		# (the folders to the trash, where they can be restored) and Ctrl+Y to put both back.
		var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
		undo.create_action(EventSheetL10n.translate("Add behaviour %s") % str(pack.get("name", pack_dir)), UndoRedo.MERGE_DISABLE, host)
		undo.add_do_method(self, "_restore_folders", added)
		undo.add_do_method(host, "add_child", node)
		undo.add_do_property(node, "owner", node.owner)
		undo.add_do_reference(node)
		undo.add_undo_method(host, "remove_child", node)
		undo.add_undo_method(self, "_trash_folders", added)
		undo.commit_action(false)
		EditorInterface.mark_scene_as_unsaved()
	_after_change()
	var message: String = said if bool(result.get("ok", false)) else str(result.get("message", ""))
	_dock._set_status(message, not bool(result.get("ok", false)))
	return {"ok": bool(result.get("ok", false)), "message": message, "node": node, "copied": added,
		"host": host}


## The open scene's root when it is the object itself - a sheet that is the scene root's own script
## names no child path to look up, so the object bar's label is the root's own name.
func _scene_root_named(object_label: String) -> Node:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	return edited_root if edited_root != null and str(edited_root.name) == object_label else null


## Takes the last library add back, the way Ctrl+Z would: the node out, the folders to the trash.
## The Add behaviour window's Undo, which is the same step on the same history.
func undo_last(host: Node) -> void:
	if host == null or not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	manager.get_history_undo_redo(manager.get_object_history_id(host)).undo()


## Copies the folders back in from the library, for the redo of an add.
func _restore_folders(folders: PackedStringArray) -> void:
	copy_and_import(folders)
	_after_change()


## Sends the folders an add copied in to the trash, for its undo.
func _trash_folders(folders: PackedStringArray) -> void:
	for folder: String in folders:
		EventSheetPackLibrary.send_to_trash(folder)
	import_folders(PackedStringArray())
	_after_change()


## Copies library folders in, in two steps with an import after each: first everything but the
## scripts, so the pictures a script's `@icon` names are imported, then the scripts. Copying both at
## once had Godot register each script and look for its icon before the icon was imported - one
## "Failed loading resource" per pack, and on a large add an editor that crashed part way. Returns
## what copy_into_project returns. A coroutine: await it.
func copy_and_import(wanted: PackedStringArray) -> Dictionary:
	var copied: Dictionary = EventSheetPackLibrary.copy_into_project(wanted, EventSheetPackLibrary.LIBRARY_ROOT,
		EventSheetPackLibrary.PROJECT_ROOT, true)
	var added: PackedStringArray = copied.get("copied", PackedStringArray())
	if added.is_empty():
		return copied
	await import_folders(added)
	var scripts_error: Error = EventSheetPackLibrary.copy_scripts(added)
	if scripts_error != OK:
		copied["ok"] = false
		copied["message"] = EventSheetL10n.translate("%s could not be copied into the project (%s).") % [", ".join(added), error_string(scripts_error)]
	await import_folders(added)
	await _classes_registered(added)
	return copied


## Waits until Godot's class list holds every class the copied scripts declare: a script loaded
## before then (the vocabulary's rebuild loads them) cannot find a base class from the same pack.
func _classes_registered(folders: PackedStringArray) -> void:
	if not Engine.is_editor_hint() or _dock == null or not _dock.is_inside_tree():
		return
	var wanted: Dictionary = {}
	var declared: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for folder: String in folders:
		for script_path: String in EventSheetPackLibrary._scripts_in(EventSheetPackLibrary.PROJECT_ROOT.path_join(folder)):
			var found: RegExMatch = declared.search(FileAccess.get_file_as_string(script_path))
			if found != null:
				wanted[found.get_string(1)] = true
	var give_up: SceneTreeTimer = _dock.get_tree().create_timer(IMPORT_WAIT_SECONDS)
	while not wanted.is_empty() and give_up.time_left > 0.0:
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			wanted.erase(str(entry.get("class", "")))
		if not wanted.is_empty():
			await _dock.get_tree().process_frame


## Asks Godot to import what changed under eventsheet_addons/ and waits until it says it has, so a
## class the copied packs declare is known before anything uses it. A coroutine: await it.
##
## The scan finds the new files but imports their pictures and sounds a step later, and a rebuild of
## the vocabulary in between loads a pack icon that is not imported yet. So once the scan is done,
## this also waits until every copied file Godot imports has its import.
func import_folders(folders: PackedStringArray) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface") or _dock == null or not _dock.is_inside_tree():
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	var finished: Array[bool] = [false]
	filesystem.filesystem_changed.connect(func() -> void: finished[0] = true, CONNECT_ONE_SHOT)
	filesystem.scan()
	var give_up: SceneTreeTimer = _dock.get_tree().create_timer(IMPORT_WAIT_SECONDS)
	while (not finished[0] or filesystem.is_scanning()) and give_up.time_left > 0.0:
		await _dock.get_tree().process_frame
	# Godot refuses a second import started while its own runs, so this waits for the files it is
	# importing to arrive rather than importing them itself.
	while give_up.time_left > 0.0 and not _all_imported(folders):
		await _dock.get_tree().process_frame


static func _all_imported(folders: PackedStringArray) -> bool:
	for folder: String in folders:
		if not unimported_files(EventSheetPackLibrary.PROJECT_ROOT.path_join(folder)).is_empty():
			return false
	return true


## Every file under `folder` Godot imports (a picture, a sound, a compute shader, a table) that has
## no `.import` beside it yet. Scripts, shaders, scenes and resources are read as they are.
static func unimported_files(folder: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return out
	for file_name: String in DirAccess.get_files_at(folder):
		var extension: String = file_name.get_extension()
		if READ_AS_IS.has(extension) or EventSheetPackLibrary.GENERATED_EXTENSIONS.has(extension):
			continue
		if not FileAccess.file_exists(folder.path_join(file_name) + ".import"):
			out.append(folder.path_join(file_name))
	for child: String in DirAccess.get_directories_at(folder):
		out.append_array(unimported_files(folder.path_join(child)))
	return out


func _after_change() -> void:
	# The pack listing is keyed by the folders' modification times, so a folder copied in or trashed
	# is seen by the rebuild without being told.
	if _dock != null and _dock.has_method("_refresh_ace_registry"):
		_dock._refresh_ace_registry()
	if on_changed.is_valid():
		on_changed.call()


# --- the Welcome's kits ------------------------------------------------------------------------


## Copies in every folder the chosen kits bring and imports them. Returns {"ok", "message", "copied"}.
## A coroutine: await it.
func add_kits(chosen: Array[Dictionary]) -> Dictionary:
	var wanted: PackedStringArray = EventSheetPackLibrary.kit_folders(chosen)
	var copied: Dictionary = await copy_and_import(wanted)
	var added: PackedStringArray = copied.get("copied", PackedStringArray())
	if not added.is_empty():
		_after_change()
	var message: String = str(copied.get("message", "")) if not bool(copied.get("ok", false)) \
		else (EventSheetL10n.translate("Nothing was added.") if added.is_empty()
			else EventSheetL10n.translate("Added %d behaviours to eventsheet_addons/. Add or remove any of them from an object's Behaviours list.") % added.size())
	_dock._set_status(message, not bool(copied.get("ok", false)))
	return {"ok": bool(copied.get("ok", false)), "message": message, "copied": added}


# --- removing ----------------------------------------------------------------------------------


## The warning a removal shows, from the files that use the pack: {"heading", "lines"}, both empty
## when nothing does.
static func remove_warning(found_users: Array[Dictionary]) -> Dictionary:
	if found_users.is_empty():
		return {"heading": "", "lines": PackedStringArray()}
	var all_sheets: bool = true
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in found_users:
		var path: String = str(entry.get("path", ""))
		var rows: int = int(entry.get("rows", 0))
		if path.get_extension() != "gd":
			all_sheets = false
		var count: String = EventSheetL10n.translate("1 row") if rows == 1 else EventSheetL10n.translate("%d rows") % rows
		lines.append("%s · %s" % [path.get_file(), count])
	var heading: String = ""
	if found_users.size() == 1:
		heading = EventSheetL10n.translate("Used by 1 sheet") if all_sheets else EventSheetL10n.translate("Used by 1 file")
	else:
		heading = (EventSheetL10n.translate("Used by %d sheets") if all_sheets else EventSheetL10n.translate("Used by %d files")) % found_users.size()
	return {"heading": heading, "lines": lines}


## Right-click an In project behaviour > Remove from project…: says which files use it first, and
## sends its folder to the trash only on Remove.
func confirm_remove(pack: Dictionary) -> void:
	_remove_pack = pack
	if _remove_window == null:
		var parts: Dictionary = EventSheetPopupUI.panel_window("", Vector2i(EventSheetPalette.scaled(520), 0), _dock,
			EventSheetL10n.translate("Remove"), _remove_confirmed, true)
		_remove_window = parts["window"]
		_remove_window.cancel_button_text = EventSheetL10n.translate("Keep it")
		var box: VBoxContainer = parts["box"]
		_remove_body = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(480.0))
		_remove_body.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
		box.add_child(_remove_body)
		_remove_users = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(460.0))
		box.add_child(_remove_users)
	var pack_dir: String = str(pack.get("dir", ""))
	var pack_name: String = str(pack.get("name", pack_dir))
	_remove_window.title = EventSheetL10n.translate("Remove %s from the project?") % pack_name
	var kept: String = EventSheetL10n.translate("It stays in the library, so you can add it back at any time.") \
		if EventSheetPackLibrary.folders().has(pack_dir) \
		else EventSheetL10n.translate("It is not in the library, so the trash is where it can be restored from.")
	_remove_body.text = EventSheetL10n.translate("Its folder %s goes to the system trash.") % ("eventsheet_addons/%s/" % pack_dir) + " " + kept
	var warning: Dictionary = remove_warning(EventSheetPackLibrary.users(pack_dir, EventSheetPackLibrary.usage_corpus()))
	if str(warning["heading"]).is_empty():
		_remove_users.say("")
	else:
		_remove_users.say("%s\n%s\n%s" % [warning["heading"], "\n".join(warning["lines"]),
			EventSheetL10n.translate("Those rows stay as written and show as missing until it is added back. The Doctor lists them.")],
			EventSheetPopupUI.TONE_WARNING)
	EventSheetPopupUI.popup_fitted(_remove_window)


func _remove_confirmed() -> void:
	var pack_dir: String = str(_remove_pack.get("dir", ""))
	var error: Error = EventSheetPackLibrary.send_to_trash(pack_dir)
	if error != OK:
		_dock._set_status(EventSheetL10n.translate("%s could not be sent to the trash (%s); it is still in the project.") % [
			"eventsheet_addons/%s/" % pack_dir, error_string(error)], true)
		return
	await import_folders(PackedStringArray())
	_after_change()
	_dock._set_status(EventSheetL10n.translate("Removed %s: its folder is in the system trash.") % str(_remove_pack.get("name", pack_dir)))


# --- tidying -----------------------------------------------------------------------------------


## The Tidy behaviours summary line for a project holding `held` packs, `unused` of them unused.
static func tidy_summary(held: int, unused: int) -> String:
	return EventSheetL10n.translate("This project holds %d behaviours. No sheet uses %d of them. Ticked ones go to the trash and stay in the library.") % [held, unused]


## The main button's words for `ticked` packs.
static func tidy_button_text(ticked: int) -> String:
	return EventSheetL10n.translate("Remove %d unused") % ticked


## Project Doctor > Tidy behaviours…: every pack the project holds, the unused ones ticked and the
## used ones locked, with who uses them. Only packs the library also holds can be ticked - one the
## project made itself has no copy anywhere else.
func open_tidy() -> void:
	if _tidy_window == null:
		var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("Tidy behaviours"),
			Vector2i(EventSheetPalette.scaled(600), EventSheetPalette.scaled(460)), _dock, tidy_button_text(0), _tidy_confirmed, true)
		_tidy_window = parts["window"]
		_tidy_window.cancel_button_text = EventSheetL10n.translate("Not now")
		var box: VBoxContainer = parts["box"]
		_tidy_summary = EventSheetPopupUI.hint_label("", EventSheetPalette.scaled_f(560.0))
		_tidy_summary.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
		box.add_child(_tidy_summary)
		_tidy_list = VBoxContainer.new()
		_tidy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(560.0), EventSheetPalette.scaled_f(300.0))
		scroll.add_child(_tidy_list)
		box.add_child(EventSheetPopupUI.panel_section(scroll))
	for child: Node in _tidy_list.get_children():
		child.free()
	_tidy_ticks.clear()
	var rows: Array[Dictionary] = EventSheetPackLibrary.tidy_rows(EventSheetPackCatalog.packs(), EventSheetPackLibrary.usage_corpus())
	var unused: int = 0
	for row: Dictionary in rows:
		var found_users: Array = row.get("users", [])
		var line: HBoxContainer = HBoxContainer.new()
		var tick: CheckBox = CheckBox.new()
		tick.text = str(row.get("name", ""))
		tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var removable: bool = found_users.is_empty() and bool(row.get("in_library", false))
		tick.button_pressed = removable
		tick.disabled = not removable
		if found_users.is_empty() and not bool(row.get("in_library", false)):
			tick.tooltip_text = EventSheetL10n.translate("Made in this project: the library has no copy to add it back from.")
		tick.toggled.connect(func(_on: bool) -> void: _refresh_tidy_button())
		line.add_child(tick)
		var note: Label = Label.new()
		note.text = EventSheetPackLibrary.used_by_text(found_users)
		note.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
		line.add_child(note)
		_tidy_list.add_child(line)
		_tidy_ticks[str(row.get("dir", ""))] = tick
		if removable:
			unused += 1
	_tidy_summary.text = tidy_summary(rows.size(), unused)
	_refresh_tidy_button()
	EventSheetPopupUI.popup_fitted(_tidy_window, Vector2i(EventSheetPalette.scaled(600), EventSheetPalette.scaled(460)))


func _refresh_tidy_button() -> void:
	var ticked: int = ticked_for_tidy().size()
	_tidy_window.ok_button_text = tidy_button_text(ticked)
	_tidy_window.get_ok_button().disabled = ticked == 0


## The folders ticked in Tidy behaviours right now.
func ticked_for_tidy() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for pack_dir: String in _tidy_ticks:
		var tick: CheckBox = _tidy_ticks[pack_dir]
		if tick.button_pressed and not tick.disabled:
			out.append(pack_dir)
	return out


func _tidy_confirmed() -> void:
	var removed: int = 0
	var refused: PackedStringArray = PackedStringArray()
	for pack_dir: String in ticked_for_tidy():
		if EventSheetPackLibrary.send_to_trash(pack_dir) == OK:
			removed += 1
		else:
			refused.append(pack_dir)
	await import_folders(PackedStringArray())
	_after_change()
	var said: String = EventSheetL10n.translate("Sent %d unused behaviours to the trash; each stays in the library.") % removed
	if not refused.is_empty():
		said += " " + EventSheetL10n.translate("Still in the project (the trash refused them): %s.") % ", ".join(refused)
	_dock._set_status(said, not refused.is_empty())
