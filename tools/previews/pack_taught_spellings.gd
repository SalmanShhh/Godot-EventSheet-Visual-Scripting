# Godot EventSheets - a hand-written file read twice, before and after a pack teaches its spellings.
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
#
#   ABOVE, the same file with the pack's own spellings switched off. Every line is a method call
#     nothing curated claims, so every one of them reads as the plain generic call - which is honest,
#     and is the floor.
#   BELOW, the same bytes with the installed pack's `## @ace_lift_example` spellings answering. The
#     rows are the pack's own verbs, with the pack's names and its parameters. Not one byte moved:
#     the line the author wrote is baked onto the row, so saving writes their file back exactly.
#
# THE LAST LINE IS THE REFUSAL, and it is in the picture on purpose. `flicker` is a bare variable,
# and a pack spelling may only claim the three ways a row addresses a node - a bare name matches
# every receiver in the language, so claiming it would take the line away from readings that already
# say more about it. That row keeps the generic call in both halves.
@tool
extends RefCounted

const PREVIEW_NAME: String = "pack-taught-spellings"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 900)

## Its own staging name, written fresh each build: a fixed path shared with another harness can
## silently import the PREVIOUS run's file, and every symptom of that points at the reader instead.
const SOURCE_PATH: String = "user://preview_pack_taught_spellings.gd"

const SOURCE: String = """extends Node

@onready var flicker: Node = $Torch/LightFlickerBehavior


func _ready() -> void:
	$LightFlickerBehavior.start_flickering(0.5)
	%Torchlight.start_flickering()
	get_node("LightFlickerBehavior").stop_flickering(1.0)
	flicker.stop_flickering()
"""


static func build(host: Window) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	# The tables are read off disk once per session, so the "before" half asks for none of them and
	# the "after" half puts the real ones back.
	EventForgePackSpellings.override_tables_for_tests({})
	EventSheetLiftReading.clear_cache()
	column.add_child(EventSheetPopupUI.titled_card(
		"Before: nothing claims these calls, so each reads as the plain generic call",
		_sheet_view(_sheet(), 360.0)))
	EventForgePackSpellings.reset_cache_for_tests()
	EventSheetLiftReading.clear_cache()
	column.add_child(EventSheetPopupUI.titled_card(
		"After: the pack's own verbs, same bytes - and the bare variable still keeps the plain call",
		_sheet_view(_sheet(), 360.0)))
	var margined: MarginContainer = EventSheetPopupUI.margined(column)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


static func _sheet() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


## One sheet as a read-only canvas of a fixed height - a canvas asks its container for every pixel it
## can get, and two of them in a column would leave the second with none.
static func _sheet_view(sheet: EventSheetResource, height: float) -> Control:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	sheet.read_only = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	viewport.expand_all()
	var frame: Control = Control.new()
	frame.custom_minimum_size = Vector2(0.0, height)
	frame.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(viewport)
	return frame
