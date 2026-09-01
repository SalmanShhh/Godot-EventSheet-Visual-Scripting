# Godot EventSheets - a pack update, mid-decision (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The moment the whole slice exists for: a new version has been read, nothing has been written, and
# the three lists say what taking it would do. Four files nobody touched, listed rather than swept;
# two the project changed, each with its own answer and a way to see the difference; and the
# vocabulary, diffed out of the two versions' registry dumps rather than read off a release note.
#
# THE PACK IS A FIXTURE UNDER user://. Nothing under eventsheet_addons/ is touched by taking a
# picture, and the vocabulary section is real all the same: both versions are reflected the way the
# registry reflects any installed pack, so the verb that moved really did move.
@tool
extends RefCounted

const PREVIEW_NAME: String = "pack-update-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(900, 700)

const FIXTURE_ROOT: String = "user://eventforge_pack_update_preview"
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
## @ace_succeeded_by(Core::Print, renames: loot_table=text)
func open_chest(loot_table: String = "\\"common\\"") -> void:
	print(loot_table)


## @ace_action
## @ace_name("Lock Chest")
func lock_chest() -> void:
	print("locked")
"""


static func build(host: Window) -> Node:
	var folder: String = _fixture()
	var dialog: EventSheetPackUpdateDialog = EventSheetPackUpdateDialog.new()
	host.add_child(dialog)
	dialog.open_update(folder, _incoming(), "2.1.0")
	dialog.popup_centered(Vector2i(860, 660))
	return dialog


## What the new version brings: the pack script rewritten, a guide rewritten, an icon and a
## translation table it adds, and no sign of the old sound file it drops.
static func _incoming() -> Dictionary:
	return {
		"chest_kit.gd": PACK_V2.to_utf8_buffer(),
		"guide.md": "# Chest Kit\n\nChests, and what falls out of them.\n".to_utf8_buffer(),
		"icon.svg": "<svg/>".to_utf8_buffer(),
		"strings.csv": "keys,en\nopen,Open\n".to_utf8_buffer(),
		"loot_table.tres": "[gd_resource type=\"Resource\"]\n".to_utf8_buffer(),
	}


## The pack as this project has it: attached, then lived in - the guide rewritten in the project's
## own words and one value in the loot table nudged.
static func _fixture() -> String:
	var folder: String = FIXTURE_ROOT.path_join(PACK_DIR)
	if DirAccess.dir_exists_absolute(folder):
		for stale: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(stale))
	DirAccess.make_dir_recursive_absolute(folder)
	_write(folder.path_join("chest_kit.gd"), PACK_V1)
	_write(folder.path_join("guide.md"), "# Chest Kit\n\nChests.\n")
	_write(folder.path_join("icon.svg"), "<svg/>")
	_write(folder.path_join("strings.csv"), "keys,en\nopen,Open\n")
	_write(folder.path_join("loot_table.tres"), "[gd_resource type=\"Resource\"]\n")
	_write(folder.path_join("chime.txt"), "a placeholder for the sound this version drops\n")
	EventSheetPackManifest.stamp(folder, "2.0.0")
	# Now the two edits the project made after it attached.
	_write(folder.path_join("guide.md"), "# Chest Kit\n\nChests - and OUR rule about mimics.\n")
	_write(folder.path_join("loot_table.tres"), "[gd_resource type=\"Resource\"]\n; tuned for our drop rates\n")
	return folder


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
