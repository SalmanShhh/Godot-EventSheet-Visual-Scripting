# Godot EventSheets - the picture a Juice card wears on its line and in the Add box.
#
# Every kind of card has a drawing; the card line draws it where the small family square used to be, in the
# family's colour, and the Add box draws it beside the kind's name. What this pins: the family colours still
# read 3:1 against the card line they sit on (as the colour and as the neutral drawing multiplied by it);
# every kind and the default for a card of your own produce a picture; a card of your own takes the icon its
# script names with `@icon` and keeps its colours; a muted card is quietened and a selected one takes the
# selected ink; the Add box shows each kind's picture and its headings keep their tile; and a list whose
# schema draws no pictures (the Drawing Prefab's) is exactly what it was.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFAB_STEPS := preload("res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd")
const ICONS_PATH: String = "res://addons/eventsheet/editor/inspector/juice_card_icons.gd"
const NAME: String = "juice_card_icons_test"

## The card line's ground on a dark and on a light editor, measured from the card line in the editor.
const GROUND_DARK: String = "#1b1b1b"
const GROUND_LIGHT: String = "#f5f5f5"
## The neutral ink the drawings are made in: a tint multiplies it, so a family colour shows at 224 / 255.
const NEUTRAL_INK: float = 224.0 / 255.0
const LEAST_CONTRAST: float = 3.0


static func run() -> bool:
	var ok: bool = true
	ok = _contrast_pins() and ok
	ok = _picture_pins() and ok
	ok = _own_pins() and ok
	ok = _line_pins() and ok
	ok = _add_box_pins() and ok
	ok = _prefab_pins() and ok
	return ok


## WCAG contrast of two opaque colours.
static func contrast(first: Color, second: Color) -> float:
	var high: float = maxf(_luminance(first), _luminance(second))
	var low: float = minf(_luminance(first), _luminance(second))
	return (high + 0.05) / (low + 0.05)


static func _luminance(colour: Color) -> float:
	var channels: Array = []
	for value: float in [colour.r, colour.g, colour.b]:
		channels.append(value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * float(channels[0]) + 0.7152 * float(channels[1]) + 0.0722 * float(channels[2])


static func _whole(value: float) -> float:
	return roundf(value * 255.0) / 255.0


## What a tint makes of the neutral drawing: each channel times the ink, to the nearest of 255.
static func on_ink(colour: Color) -> Color:
	return Color(_whole(colour.r * NEUTRAL_INK), _whole(colour.g * NEUTRAL_INK), _whole(colour.b * NEUTRAL_INK))


static func _contrast_pins() -> bool:
	var ok: bool = true
	var dark: Color = Color.from_string(GROUND_DARK, Color.BLACK)
	var light: Color = Color.from_string(GROUND_LIGHT, Color.WHITE)
	var stripes: Dictionary = EventSheetFeedbackCardSchema.STRIPES
	var stripes_light: Dictionary = EventSheetFeedbackCardSchema.STRIPES_LIGHT
	ok = SUPPORT.check(NAME, "the dark and the light colours name the same families",
		",".join(PackedStringArray(stripes.keys())), ",".join(PackedStringArray(stripes_light.keys()))) and ok
	for family: String in stripes:
		var on_dark: Color = Color.from_string(str(stripes[family]), Color.BLACK)
		var on_light: Color = Color.from_string(str(stripes_light[family]), Color.BLACK)
		ok = SUPPORT.check(NAME, "%s reads %s:1 on a dark card line as its colour" % [family, LEAST_CONTRAST],
			contrast(on_dark, dark) >= LEAST_CONTRAST, true) and ok
		ok = SUPPORT.check(NAME, "%s reads %s:1 on a dark card line as the tinted drawing" % [family, LEAST_CONTRAST],
			contrast(on_ink(on_dark), dark) >= LEAST_CONTRAST, true) and ok
		ok = SUPPORT.check(NAME, "%s reads %s:1 on a light card line as its colour" % [family, LEAST_CONTRAST],
			contrast(on_light, light) >= LEAST_CONTRAST, true) and ok
		ok = SUPPORT.check(NAME, "%s reads %s:1 on a light card line as the tinted drawing" % [family, LEAST_CONTRAST],
			contrast(on_ink(on_light), light) >= LEAST_CONTRAST, true) and ok
	return ok


static func _picture_pins() -> bool:
	var ok: bool = true
	var icons: Script = load(ICONS_PATH) as Script
	var schema: Dictionary = EventSheetFeedbackCardSchema.schema()
	for entry: Variant in schema["kinds"]:
		var kind: String = str((entry as Dictionary)["kind"])
		var drawn: Dictionary = EventSheetCardSchemas.card_icon(schema, entry as Dictionary, 1.0)
		var texture: Texture2D = drawn.get("texture") as Texture2D
		ok = SUPPORT.check(NAME, "%s has a picture" % kind, texture != null, true) and ok
		if texture != null:
			ok = SUPPORT.check(NAME, "the picture of %s is 16 px square at scale 1" % kind, texture.get_size(), Vector2(16, 16)) and ok
			ok = SUPPORT.check(NAME, "the picture of %s is meant to be tinted" % kind, drawn.get("tint"), true) and ok
	var big: Texture2D = (icons.call("icon_for", {"kind": "shake"}, 2.0) as Dictionary)["texture"] as Texture2D
	ok = SUPPORT.check(NAME, "at twice the scale a picture is drawn at twice the size, not stretched", big.get_size(), Vector2(32, 32)) and ok
	ok = SUPPORT.check(NAME, "a kind the pack has no drawing for has no picture", icons.call("icon_for", {"kind": "nothing_like_it"}, 1.0), {}) and ok
	ok = SUPPORT.check(NAME, "an entry with no kind has no picture", icons.call("icon_for", {}, 1.0), {}) and ok
	ok = SUPPORT.check(NAME, "a schema with no `icons` draws none", EventSheetCardSchemas.card_icon({"kinds": []}, {"kind": "shake"}, 1.0), {}) and ok
	return ok


static func _write(file_name: String, text: String) -> String:
	var path: String = SUPPORT.own_path(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


static func _own_pins() -> bool:
	var icons: Script = load(ICONS_PATH) as Script
	var named: String = _write("own_with_icon.gd", "@icon(\"res://eventsheet_addons/juice/icon.svg\")\nclass_name OwnWithIconCard\nextends JuiceCard\n")
	var plain: String = _write("own_without_icon.gd", "class_name OwnWithoutIconCard\nextends JuiceCard\n")
	var missing: String = _write("own_missing_icon.gd", "@icon(\"res://nowhere/none.svg\")\nextends JuiceCard\n")
	var with_icon: Dictionary = icons.call("icon_for", {"script_path": named, "kind": "OwnWithIconCard"}, 1.0)
	var without_icon: Dictionary = icons.call("icon_for", {"script_path": plain, "kind": "OwnWithoutIconCard"}, 1.0)
	var gone: Dictionary = icons.call("icon_for", {"script_path": missing}, 1.0)
	var default_picture: Texture2D = (icons.call("icon_for", {"kind": "own"}, 1.0) as Dictionary).get("texture") as Texture2D
	var rows: Array = [
		["the line `@icon(...)` is read off a script", icons.call("icon_path_of", "@icon(\"res://a/b.svg\")\nextends Node\n"), "res://a/b.svg"],
		["a spaced `@icon( ... )` is read the same", icons.call("icon_path_of", "@icon( \"uid://abc\" )\n"), "uid://abc"],
		["a script with no `@icon` names none", icons.call("icon_path_of", "extends Node\n"), ""],
		["an `@icon` inside a comment is not one", icons.call("icon_path_of", "# @icon(\"res://x.svg\")\nextends Node\n"), ""],
		["a card of your own that names an icon wears it", with_icon.get("texture") != null, true],
		["and keeps its colours: no family tint on it", with_icon.get("tint"), false],
		["a card of your own that names none wears the default drawing", without_icon.get("texture") != null, true],
		["tinted with its family colour", without_icon.get("tint"), true],
		["the default is the one drawing `own`", (without_icon.get("texture") as Texture2D).get_image().get_data() == default_picture.get_image().get_data(), true],
		["a card of your own that names an icon that is not there falls back to the default", gone.get("tint"), true]
	]
	return SUPPORT.pins(NAME, rows)


## A list holding one card of every kind.
static func _drawer() -> EventSheetCardListDrawer:
	var cards: Array = []
	for entry: Variant in EventSheetFeedbackCardSchema.schema()["kinds"]:
		cards.append({"verb": str((entry as Dictionary)["kind"])})
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": EventSheetFeedbackCardSchema.schema()})
	drawer.set_value(cards)
	return drawer


static func _line_pins() -> bool:
	var ok: bool = true
	var drawer: EventSheetCardListDrawer = _drawer()
	var schema: Dictionary = drawer.schema()
	var cards: Array = drawer.get_value()
	ok = SUPPORT.check(NAME, "every card on the line wears a picture", drawer._pictures.size(), cards.size()) and ok
	for index: int in range(cards.size()):
		var entry: Dictionary = EventSheetCardSchemas.kind_entry(schema, str((cards[index] as Dictionary)["verb"]))
		var family: Color = EventSheetCardSchemas.tile_color(schema, str(entry["category"]), false)
		var picture: TextureRect = drawer._pictures.get(index) as TextureRect
		ok = SUPPORT.check(NAME, "%s is drawn in the colour of its family" % entry["kind"], picture.modulate if picture != null else Color.BLACK, family) and ok
	var first: TextureRect = drawer._pictures.get(0) as TextureRect
	ok = SUPPORT.check(NAME, "the picture is 16 px square", first.custom_minimum_size, Vector2(16, 16) * EventSheetLookStyle.px(1.0)) and ok
	# A muted card is quietened the way its name is: toward the quiet ink, never to it, so the family still shows.
	var live: Color = first.modulate
	drawer.set_card_enabled(0, false)
	var muted: TextureRect = drawer._pictures.get(0) as TextureRect
	ok = SUPPORT.check(NAME, "a muted card's picture is quieter than a live one's", muted.modulate != live, true) and ok
	ok = SUPPORT.check(NAME, "and is its family colour toward the quiet ink", muted.modulate, live.lerp(EventSheetLookStyle.quiet(), 0.6)) and ok
	drawer.set_card_enabled(0, true)
	ok = SUPPORT.check(NAME, "switching the card back on gives the colour back", (drawer._pictures.get(0) as TextureRect).modulate, live) and ok
	# A selected card takes the selected ink the way its name does.
	drawer.select_card(1)
	ok = SUPPORT.check(NAME, "a selected card's picture takes the selected ink", (drawer._pictures.get(1) as TextureRect).modulate, EventSheetLookStyle.selected_row_ink()) and ok
	drawer.clear_selection()
	var released: Color = EventSheetCardSchemas.tile_color(schema, str(EventSheetCardSchemas.kind_entry(schema, "hitstop")["category"]), false)
	ok = SUPPORT.check(NAME, "and gives its colour back when it is let go", (drawer._pictures.get(1) as TextureRect).modulate, released) and ok
	# Opening a card changes its body and not the mark.
	drawer._unfolded[2] = true
	drawer._rebuild()
	ok = SUPPORT.check(NAME, "an open card still wears its picture", drawer._pictures.has(2), true) and ok
	drawer.free()
	return ok


static func _add_box_pins() -> bool:
	var ok: bool = true
	var drawer: EventSheetCardListDrawer = _drawer()
	var schema: Dictionary = drawer.schema()
	drawer._on_add_pressed()
	drawer._add_filter.text = ""
	drawer._fill_add_tree()
	var leaves: int = 0
	var pictured: int = 0
	var headings_are_tiles: bool = true
	var yours_keep_colours: bool = false
	var group: TreeItem = drawer._add_tree.get_root().get_first_child()
	while group != null:
		var heading_icon: Texture2D = group.get_icon(0)
		headings_are_tiles = headings_are_tiles and heading_icon != null and heading_icon.get_size().x < 16.0 * EventSheetLookStyle.px(1.0)
		var leaf: TreeItem = group.get_first_child()
		while leaf != null:
			leaves += 1
			var entry: Dictionary = EventSheetCardSchemas.kind_entry(schema, str(leaf.get_metadata(0)))
			if str(entry["category"]) == "yours":
				# The shipped example card of your own names an `@icon`, which keeps its own colours.
				yours_keep_colours = leaf.get_icon(0) != null and leaf.get_icon_modulate(0) == Color.WHITE
			elif leaf.get_icon(0) != null and leaf.get_icon_modulate(0) == EventSheetCardSchemas.tile_color(schema, str(entry["category"]), false):
				pictured += 1
			leaf = leaf.get_next()
		group = group.get_next()
	ok = SUPPORT.check(NAME, "the Add box lists the fifty-seven kinds and the pack's own example card", leaves, 58) and ok
	ok = SUPPORT.check(NAME, "each kind wears its picture in its family's colour", pictured, 57) and ok
	ok = SUPPORT.check(NAME, "a card of your own wears its own icon in its own colours", yours_keep_colours, true) and ok
	ok = SUPPORT.check(NAME, "the family headings keep their square tile", headings_are_tiles, true) and ok
	drawer._add_popup.hide()
	drawer.free()
	return ok


## The Drawing Prefab's list draws no picture: its schema has no `icons`, and its cards are what they were.
static func _prefab_pins() -> bool:
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	editor.set_steps([{"kind": "line", "x": 1.0, "y": 2.0, "p1": 5.0, "p2": 6.0, "p3": 3.0, "color": "red"}])
	var rows: Array = [
		["the Drawing Prefab's schema asks for no pictures", editor.schema().has("icons"), false],
		["so no card of it wears one", editor._pictures.size(), 0]
	]
	editor.free()
	return SUPPORT.pins(NAME, rows)
