# Godot EventSheets - a whole filtered event, with the hit used by the row underneath (preview).
#
# Rendered by tools/render_previews.gd. One event, read out of a hand-written script so the picture
# is of the reading and not of a sheet built to flatter it: the trigger says "On overlap with", the
# group it filters on sits in the trigger's own cell, and the thing that arrived rides beside it as a
# payload chip - which the two action rows underneath then use by name. That chain is the whole point
# of the filter: the row below does not have to ask again what was hit.
#
# The source is written to the user directory at build time rather than kept in the repository,
# because it exists only to be photographed.
@tool
extends RefCounted

const PREVIEW_NAME: String = "collision-filter-event"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 320)

const SOURCE_PATH: String = "user://preview_collision_filter_event.gd"

const SOURCE: String = """extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	body.queue_free()
	score += 1
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
	window.custom_minimum_size = Vector2(0.0, 190.0)
	window.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(viewport)
	var card: PanelContainer = EventSheetPopupUI.titled_card(
		"The hit is filtered once, then used by the rows underneath", window)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined
