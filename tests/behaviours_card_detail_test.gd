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
			"Juice · on Carousel", "Scenes · on Carousel", "Blend Modes · on Carousel",
			"Screen FX · layer = 100 · on Carousel",
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
	return ok


## A Juice Player on a node called Hero, holding `count` cards, as the scene writes them.
static func _with_steps(count: int) -> Dictionary:
	var cards: PackedStringArray = PackedStringArray()
	for index: int in range(count):
		cards.append("{\"verb\": \"shake\", \"amount\": %d.0}" % (index + 1))
	return _with_text("Array[Dictionary]([%s])" % ", ".join(cards))


static func _with_text(written: String) -> Dictionary:
	return {"name": "Juice Player", "host": "Hero", "script": "", "properties": [{"name": "steps", "value": written}]}
