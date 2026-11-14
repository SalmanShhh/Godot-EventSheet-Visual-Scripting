@tool
class_name RegistryRefreshOnSaveTest
extends RefCounted

# Godot EventSheets - saving a script the picker reads from changes what the picker offers, with no
# restart and no tab switch.
#
# A word on a `##` line is the whole change - a new sentence, a new name - and the vocabulary used to
# be rebuilt only when the LIST of registered scripts moved, so a save left the picker on the old words
# until the editor was restarted. The registry signature now carries each registered or shared script's
# saved time and length, and the editor's filesystem ping asks it. A switch between two tabs whose
# scripts did not change still builds nothing.

const SUPPORT := preload("res://tests/support.gd")
const SCRIPT_PATH: String = "user://registry_refresh_probe.gd"

const FIRST_TEXT: String = "extends Node\n\n## @ace_name(\"First name\")\nfunc go() -> void:\n\tpass\n"
const SECOND_TEXT: String = "extends Node\n\n## @ace_name(\"Second name\")\nfunc go() -> void:\n\tpass\n\n\n"


static func run() -> bool:
	_write(FIRST_TEXT)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.ace_provider_scripts = [SCRIPT_PATH]
	dock.setup(sheet)
	var before: String = dock._tab_state.registry_signature()
	var builds_before: int = dock._tab_state.registry_builds()
	var ok: bool = SUPPORT.pins("registry_refresh_on_save_test", [
		["the signature names the script and when it was saved", before.contains("sheet|%s|" % SCRIPT_PATH), true],
		["nothing needs rebuilding while the script is as it was", dock._tab_state.registry_needs_rebuild(), false],
	])
	_write(SECOND_TEXT)
	ok = SUPPORT.pins("registry_refresh_on_save_test", [
		["saving the script moves the signature", dock._tab_state.registry_needs_rebuild(), true],
	]) and ok
	# The editor's ping is what asks; it rebuilds exactly once for the one change.
	dock._on_translations_maybe_changed()
	ok = SUPPORT.pins("registry_refresh_on_save_test", [
		["the ping rebuilt the vocabulary once", dock._tab_state.registry_builds(), builds_before + 1],
		["and it is current again", dock._tab_state.registry_needs_rebuild(), false],
		["the registry now reads the new word", _names(dock).has("Second name"), true],
		["and no longer the old one", _names(dock).has("First name"), false],
	]) and ok
	dock._on_translations_maybe_changed()
	ok = SUPPORT.pins("registry_refresh_on_save_test", [
		["a ping with nothing changed builds nothing", dock._tab_state.registry_builds(), builds_before + 1],
	]) and ok
	dock.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRIPT_PATH))
	return ok


static func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## The display names the registry holds for the probe script's one function.
static func _names(dock: EventSheetDock) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in dock.get_ace_registry().get_all_definitions():
		if definition.id == "method:go":
			names.append(definition.display_name)
	return names
