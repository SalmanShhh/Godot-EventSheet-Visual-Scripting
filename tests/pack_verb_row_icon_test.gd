# Godot EventSheets - a row for a verb a pack publishes leads with the pack's icon.
#
# The pass that dresses every line with the icon of the object it names used to replace a pack verb's icon
# with the class icon of the sheet's own object, so "Platformer: Jump" led with the same circle as every
# other line of the sheet. A pack's verb keeps the icon its pack names; every other line is dressed as before.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "pack_verb_row_icon_test"
const PLATFORMER_ICON: String = "res://eventsheet_addons/platformer_movement/icon.svg"


static func run() -> bool:
	var view: EventSheetViewport = EventSheetViewport.new()
	var builder: EventSheetViewportRowBuilder = view._row_builder
	var verb: ACEDefinition = ACEDefinition.new()
	verb.provider_id = "FakePack"
	verb.id = "jump"
	verb.icon = PLATFORMER_ICON
	view._ace_registry._store_definition(verb)
	var pack_picture: Texture2D = EventSheetACEIcons.path_icon(PLATFORMER_ICON)
	var offered: Texture2D = builder._object_icon_for("FakePack", "jump")
	# The class icon the sheet's own object would be dressed with.
	var own_class: ImageTexture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	builder._line_icon_cache["Hero"] = own_class
	var pack_span: EventSheetSemanticSpan = builder._make_span("Platformer: Jump", EventSheetSemanticSpan.SpanType.ACTION,
		{"lane": "action", "object_label": "Hero", "object_icon": offered})
	var plain_span: EventSheetSemanticSpan = builder._make_span("Set x", EventSheetSemanticSpan.SpanType.ACTION,
		{"lane": "action", "object_label": "Hero", "object_icon": ImageTexture.create_from_image(Image.create(3, 3, false, Image.FORMAT_RGBA8))})
	builder._dress_line_object_icons([pack_span, plain_span] as Array[EventSheetSemanticSpan])
	var rows: Array = [
		["the pack's icon is there", pack_picture != null, true],
		["a pack's verb is handed the pack's icon", offered == pack_picture, true],
		["a pack verb keeps it when the line is dressed", (pack_span.metadata as Dictionary).get("object_icon") == pack_picture, true],
		["a line of the sheet's own is dressed with its object's class icon", (plain_span.metadata as Dictionary).get("object_icon") == own_class, true]
	]
	view.free()
	return SUPPORT.pins(NAME, rows)
