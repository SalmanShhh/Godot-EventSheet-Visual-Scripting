# Godot EventSheets - the backup ring, with a door on it (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The moment the door exists for: an update has been taken, and one of the files it wrote over - or
# removed altogether - is wanted back. The list is what the ring is really holding, newest first,
# each row saying which file, when that copy was taken and how big it is, with the removed one
# saying that the pack does not have it any more.
#
# THE PACK AND THE RING ARE FIXTURES UNDER user://. Nothing under eventsheet_addons/ is touched by
# taking a picture, and the ring is filled the only way it is ever filled: by running a real update
# over the fixture pack.
@tool
extends RefCounted

const PREVIEW_NAME: String = "pack-restore-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(820, 560)

const FIXTURE_ROOT: String = "user://eventforge_pack_restore_preview"
const PACK_DIR: String = "chest_kit"

const PACK_V1: String = """@tool
extends Node


## @ace_action
## @ace_name("Open Chest")
func open_chest(loot_table: String = "\\"common\\"") -> void:
	print(loot_table)
"""

const PACK_V2: String = """@tool
extends Node


## @ace_action
## @ace_name("Open Chest")
func open_chest(loot_table: String = "\\"common\\"") -> void:
	print(loot_table)


## @ace_action
## @ace_name("Lock Chest")
func lock_chest() -> void:
	print("locked")
"""


static func build(host: Window) -> Node:
	var folder: String = _updated_fixture()
	var dialog: EventSheetPackRestoreDialog = EventSheetPackRestoreDialog.new()
	host.add_child(dialog)
	dialog.open_restore(folder)
	dialog.popup_centered(Vector2i(780, 520))
	return dialog


## The pack as a project would have it after taking an update: the script and the guide rewritten,
## the old sound file dropped, and the previous bytes of all three sitting in the ring - which is
## what the window is about.
static func _updated_fixture() -> String:
	var folder: String = FIXTURE_ROOT.path_join(PACK_DIR)
	if DirAccess.dir_exists_absolute(folder):
		for stale: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(stale))
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("chest_kit.gd"), PACK_V1)
	_write(folder.path_join("guide.md"), "# Chest Kit\n\nChests.\n")
	_write(folder.path_join("chest_open.ogg.import"), "[remap]\n")
	_write(folder.path_join("loot_table.tres"), "[gd_resource type=\"Resource\"]\n")
	for relative: String in ["chest_kit.gd", "guide.md", "loot_table.tres"]:
		for stale: String in EventSheetBackups.list_backups(folder.path_join(relative)):
			DirAccess.remove_absolute(stale)
	EventSheetPackManifest.stamp(folder, "2.0.0")
	var incoming: Dictionary = {
		"chest_kit.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": "# Chest Kit\n\nChests, and what falls out of them.\n".to_utf8_buffer(),
	}
	EventSheetPackUpdate.apply(folder, incoming,
		EventSheetPackUpdate.plan(folder, incoming), {}, "2.1.0")
	return folder


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
