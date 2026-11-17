# EventForge - the head bar's behaviours card keeps everything the Behaviors band it replaced could
# unfold to: one line per kind and its settings, with the nodes that wear it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "behaviours_card_detail_test"
const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(CAROUSEL)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var notes: PackedStringArray = PackedStringArray()
	for span: EventSheetSemanticSpan in view._root_rows[0].spans:
		var card: Variant = (span.metadata as Dictionary).get("head_card") if span.metadata is Dictionary else null
		if card is Dictionary and str((card as Dictionary).get("id", "")) == "behaviours":
			notes = (card as Dictionary).get("notes", PackedStringArray())
	view.free()
	var built := EventSheetViewportRowBuilder.new()
	var ok: bool = SUPPORT.pins(P, [
		["the card says each kind, its settings and the nodes wearing it", notes, PackedStringArray([
			"Spring ×10 · on Carousel … Tile7", "Tween ×10 · on Carousel … Tile7", "Flash ×2 · on Carousel · Hero",
			"Juice · on Carousel", "Juice · steps = 5 cards · on Hero", "Juice · steps = 6 cards · on Cube",
			"Juice · steps = 12 cards · on Carousel", "Juice · steps = 1 card · on Carousel",
			"Juice · steps = 2 cards · autoplay = true · loop = true · loop wait = 0.5 · on Tile5",
			"Scenes · on Carousel", "Blend Modes · on Carousel",
			"Screen FX · layer = 100 · on Carousel", "Juice 3D · on Cube",
			"Sine ×8 · movement = \"vertical\" · period = 1.6 · magnitude = 18.0 · on Tile0 … Tile7"])],
		["one node is named on its own line", built.behaviour_detail_lines([{"name": "Juice", "host": "Carousel", "script": ""}]),
			PackedStringArray(["Juice · on Carousel"])],
		["a list of juice cards is a count, never the array's text", built.behaviour_detail_lines([_with_steps(2)]),
			PackedStringArray(["Juice Player · steps = 2 cards · on Hero"])],
		["one card is one card", built.behaviour_detail_lines([_with_steps(1)]),
			PackedStringArray(["Juice Player · steps = 1 card · on Hero"])],
		["an array of anything else keeps its own text", built.behaviour_detail_lines([_with_text("Array[int]([1, 2])")]),
			PackedStringArray(["Juice Player · steps = Array[int]([1, 2]) · on Hero"])],
	])
	return _saved_scene_pins() and ok


## A scene as Godot SAVES it: a list of juice cards runs over several lines, and the head bar must still read it as
## one value, "2 cards", not as the first line of it.
static func _saved_scene_pins() -> bool:
	var path: String = SUPPORT.own_path("behaviours_card_saved_scene.tscn")
	var text: String = "[gd_scene load_steps=2 format=3]

[ext_resource type=\"Script\" path=\"res://eventsheet_addons/juice/juice_player.gd\" id=\"1_player\"]

"
	text += "[node name=\"Hero\" type=\"Node2D\"]

[node name=\"JuicePlayer\" type=\"Node\" parent=\".\"]
script = ExtResource(\"1_player\")
"
	text += "steps = Array[Dictionary]([{
\"amount\": 1.0,
\"label\": \"a [b]hit[/b] (big)\",
\"verb\": \"shake\"
}, {
\"amount\": 2.0,
\"verb\": \"flash\"
}])
strength = 1.0
"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var facts: Dictionary = EventSheetObjectFacts.scene_facts(path)
	var behaviours: Array = facts.get("behaviors", [])
	var lines: PackedStringArray = EventSheetViewportRowBuilder.new().behaviour_detail_lines(behaviours)
	var properties: Array = (behaviours[0] as Dictionary).get("properties", []) if not behaviours.is_empty() else []
	var names: PackedStringArray = PackedStringArray()
	for property: Variant in properties:
		names.append(str((property as Dictionary).get("name", "")))
	return SUPPORT.pins(P, [
		["a list of cards saved over several lines reads as a count on the head bar", lines, PackedStringArray(["Juice · steps = 2 cards · strength = 1.0 · on Hero"])],
		["and the line after the list is still its own value", names, PackedStringArray(["steps", "strength"])],
	])


## A Juice Player on a node called Hero, holding `count` cards, as the scene writes them.
static func _with_steps(count: int) -> Dictionary:
	var cards: PackedStringArray = PackedStringArray()
	for index: int in range(count):
		cards.append("{\"verb\": \"shake\", \"amount\": %d.0}" % (index + 1))
	return _with_text("Array[Dictionary]([%s])" % ", ".join(cards))


static func _with_text(written: String) -> Dictionary:
	return {"name": "Juice Player", "host": "Hero", "script": "", "properties": [{"name": "steps", "value": written}]}
