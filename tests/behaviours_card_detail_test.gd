# EventForge - the head bar's behaviours card keeps everything the Behaviors band it replaced could
# unfold to: one line per kind and its settings, with the nodes that wear it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "behaviours_card_detail_test"
const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"


static func run() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(CAROUSEL)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var notes: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in view._root_rows[0].spans:
		var card: Variant = (span.metadata as Dictionary).get("head_card") if span.metadata is Dictionary else null
		if card is Dictionary and str((card as Dictionary).get("id", "")) == "behaviours":
			notes = (card as Dictionary).get("notes", PackedStringArray())
	view.free()
	var built := ViewportRowBuilder.new()
	var ok: bool = SUPPORT.pins(P, [
		["the card says each kind, its settings and the nodes wearing it", notes, PackedStringArray([
			"Spring ×10 · on Carousel … Tile7", "Tween ×10 · on Carousel … Tile7", "Flash ×2 · on Carousel · Hero",
			"Juice · on Carousel", "Scenes · on Carousel", "Blend Modes · on Carousel",
			"Screen FX · layer = 100 · on Carousel",
			"Sine ×8 · movement = \"vertical\" · period = 1.6 · magnitude = 18.0 · on Tile0 … Tile7"])],
		["one node is named on its own line", built.behaviour_detail_lines([{"name": "Juice", "host": "Carousel", "script": ""}]),
			PackedStringArray(["Juice · on Carousel"])],
	])
	return ok
