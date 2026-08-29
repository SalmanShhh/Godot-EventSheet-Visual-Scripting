# Godot EventSheets - what a sheet spawns, said at the top of it (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is that nothing on the head was authored: every `spawns` band is read back
# out of the sheet's own rows, with the cap a crowd row put on it and the pool a pack row takes from,
# and the last line is the band scale law doing its work - what fits is named, the rest is counted.
#
# The file is written to `user://` and opened the way any other script is, because the head is built
# from the PRELUDE of a file rather than from a sheet held in memory; nothing is written inside the
# repository.
@tool
extends RefCounted

const PREVIEW_NAME: String = "spawns-head-band"
const PREVIEW_SIZE: Vector2i = Vector2i(1500, 520)

const FIXTURE: String = "user://eventforge_preview_spawner.gd"

## The sheet the picture is of: a spawner that makes four different things, two of them capped into
## crowds and one of them pooled, and two more beyond what the band names.
const SOURCE: String = """@tool
class_name WaveSpawner
extends Node2D
## Sends the waves, and keeps the count of each one where it belongs.


func _ready() -> void:
	ObjectPool.create_pool("shots", "res://bullet.tscn", 24)


func _on_spawn_timer_timeout() -> void:
	var new_enemy = load("res://enemy.tscn").instantiate()
	new_enemy.add_to_group("enemies", true)
	add_child(new_enemy)
	new_enemy.global_position = global_position
	var new_mark = load("res://mark.tscn").instantiate()
	add_child(new_mark)
	new_mark.global_position = global_position
	var new_crate = load("res://crate.tscn").instantiate()
	add_child(new_crate)
	new_crate.global_position = global_position
	var new_coin = load("res://coin.tscn").instantiate()
	add_child(new_coin)
	new_coin.global_position = global_position
	var new_spark = load("res://spark.tscn").instantiate()
	add_child(new_spark)
	new_spark.global_position = global_position
"""


static func build(host: Window) -> Control:
	var file: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
	if file != null:
		file.store_string(SOURCE)
		file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	host.add_child(viewport)
	return viewport
