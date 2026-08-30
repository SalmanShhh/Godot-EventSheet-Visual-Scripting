# Godot EventSheets - a landing composing a spawn, read out of hand-written code (preview module).
#
# Rendered by tools/render_previews.gd. The picture is of the READING, not of a sheet built to
# flatter it: the source below is the landing check a platformer already contains - the memory, the
# comparison, and the update after it - with a puff of dust spawned at the feet inside it.
#
# What the sheet shows is the point. The `if` is not two unrelated questions ("is on the floor" AND
# "not some variable"); it is ONE sentence, so it opens as ON LANDED with JUST LANDED under it, and
# the spawn underneath reads as the row it is, placing the copy relative to the character's own
# position. The memory's own name and the line that updates it stay exactly as the author wrote
# them, because the sheet writes this file back byte for byte.
#
# The source is written to the user directory at build time rather than kept in the repository,
# because it exists only to be photographed.
@tool
extends RefCounted

const PREVIEW_NAME: String = "collision-edge-event"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 620)

const SOURCE_PATH: String = "user://preview_collision_edge_event.gd"

const SOURCE: String = """extends CharacterBody2D

var was_on_floor: bool = false


func _physics_process(delta: float) -> void:
	if is_on_floor() and not was_on_floor:
		var dust = load("res://dust.tscn").instantiate()
		get_parent().add_child(dust)
		dust.global_position = global_position + Vector2(0, 16)
	was_on_floor = is_on_floor()
"""


static func build(host: Window) -> Control:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	# A fixed height inside a plain Control, for the same reason the other sheet previews use one: a
	# canvas asks its container for every pixel it can get, and a card would hand them all over.
	var window: Control = Control.new()
	window.custom_minimum_size = Vector2(0.0, 490.0)
	window.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(viewport)
	var card: PanelContainer = EventSheetPopupUI.titled_card(
		"The landing every platformer already contains, opened as the row it is", window)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined
