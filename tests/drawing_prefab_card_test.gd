# Godot EventSheets - the Drawing Prefab's step card: what it offers, and what it must never move.
#
# THE FIRST PIN IS THE PROMISE. `tests/fixtures/drawing_prefab_before_the_card.tres` is a prefab as
# it was saved BEFORE this card grew its sections and its optional keys. It is loaded, saved again
# and compared BYTE FOR BYTE: the card may relabel, group and unfold as much as it likes, but a
# prefab somebody saved last year opens, edits and saves as the same file.
#
# The rest is the card itself, pinned as data rather than as Controls: which fields each shape
# offers and which section each sits in, what a newly added step holds, and which fields a mode
# hides. The picture is pinned where a picture can be pinned by value - the software rasterizer that
# makes the Inspector's preview and the FileSystem thumbnail - so "the dashed one looks different"
# is a pixel somebody can point at rather than a screenshot somebody has to trust.
@tool
class_name DrawingPrefabCardTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "drawing_prefab_card_test"

## The card's own file, and the software rasterizer both previews draw with. Reached by path: the
## steps editor is loaded by the Inspector plugin the same way.
const STEPS_PROPERTY_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
const RASTER_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd"

## A prefab saved before this pass, and where the round trip writes its copy.
const FIXTURE_PATH := "res://tests/fixtures/drawing_prefab_before_the_card.tres"
const ROUND_TRIP_PATH := "user://drawing_prefab_card_test_round_trip.tres"

## The background the pixel pins are read against, and the size they are read at.
const PREVIEW_BACKGROUND := Color(0.1, 0.1, 0.1, 1.0)
const PREVIEW_SIZE := Vector2i(64, 64)


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_the_round_trip() and all_passed
	all_passed = _pin_the_card() and all_passed
	all_passed = _pin_the_new_keys() and all_passed
	all_passed = _pin_the_picture() and all_passed
	return all_passed


## A prefab saved before the card existed, loaded and saved again: the same bytes.
static func _pin_the_round_trip() -> bool:
	var before: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var prefab: Resource = ResourceLoader.load(FIXTURE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var saved: int = ResourceSaver.save(prefab, ROUND_TRIP_PATH) if prefab != null else FAILED
	var after: String = FileAccess.get_file_as_string(ROUND_TRIP_PATH) if saved == OK else ""
	var steps: Variant = prefab.get("steps") if prefab != null else []
	var first: Dictionary = (steps as Array)[0] if steps is Array and not (steps as Array).is_empty() else {}
	var rows: Array = [
		["the fixture opens", prefab != null, true],
		["a step holds the eight shipped keys and nothing else",
			",".join(PackedStringArray(first.keys())), "color,kind,p1,p2,p3,texture,x,y"],
		["it saves again byte for byte", _without_generated_ids(after), _without_generated_ids(before)],
	]
	DirAccess.remove_absolute(ROUND_TRIP_PATH)
	return SUPPORT.pins(PREFIX, rows)


## The one thing in a saved resource that is NOT the resource: the random suffix Godot mints for an
## external reference every time it writes a file ("1_2jjkl"). It is regenerated on every save of
## every .tres in every project, so comparing it would pin the engine's dice rather than this card;
## everything else in the file - every key, every value, every line, and their order - is compared
## exactly as written.
static func _without_generated_ids(text: String) -> String:
	var ids: RegEx = RegEx.create_from_string("[0-9]+_[a-z0-9]{5}")
	return ids.sub(text, "id", true)


## The card: which fields a shape offers, in which section, and what a newly added one holds.
static func _pin_the_card() -> bool:
	var editor: GDScript = load(STEPS_PROPERTY_PATH) as GDScript
	var steps_editor: GDScript = editor.get_script_constant_map().get("ShapeStepsEditor") as GDScript
	var line_fields: Array = steps_editor.call("fields_for", "line")
	var circle_fields: Array = steps_editor.call("fields_for", "circle")
	return SUPPORT.pins(PREFIX, [
		["a line's card, field by field", _keys_of(line_fields),
			"kind,x,y,blend,scale_mode,p1,p2,p3,unit,color_mode,color,color_b,caps,dashed,dash_size,dash_spacing,dash_offset,dash_style"],
		["a line's card, section by section", _groups_of(line_fields),
			"Placement,Placement,Placement,Placement,Placement,Geometry,Geometry,Geometry,Geometry,Colour,Colour,Colour,Colour,Dashed,Dashed,Dashed,Dashed,Dashed"],
		["a circle has no ends and no dashes to offer", _keys_of(circle_fields),
			"kind,x,y,blend,p1,color_mode,color,color_b"],
		["a new circle step, key by key", ",".join(PackedStringArray(
			(steps_editor.call("defaults_for", "circle") as Dictionary).keys())),
			"x,y,p1,p2,p3,color,texture,blend,color_mode,color_b"],
		["a new line step starts undashed", str((steps_editor.call("defaults_for", "line") as Dictionary).get("dashed")), "false"],
		["a new line step reads its thickness in pixels", str((steps_editor.call("defaults_for", "line") as Dictionary).get("unit")), "px"],
		["the second colour belongs to a two-colour step",
			EventSheetCardSchemas.field_visible({"key": "color_b", "show_if": "color_mode==two"}, {"color_mode": "two"}), true],
		["and to no other", EventSheetCardSchemas.field_visible(
			{"key": "color_b", "show_if": "color_mode==two"}, {"color_mode": "single"}), false],
		["the dash fields belong to a dashed step", EventSheetCardSchemas.field_visible(
			{"key": "dash_size", "show_if": "dashed"}, {"dashed": true}), true],
		["the dash and the gap are linked", str(_field_named(line_fields, "dash_size").get("link")), "dash_spacing"],
	])


## The optional keys are data like any other: they survive a trip through the card unchanged, and
## the pack's own compiler reads them into the entry the renderers draw with.
static func _pin_the_new_keys() -> bool:
	var step: Dictionary = {
		"kind": "line", "x": 0.0, "y": 0.0, "p1": 32.0, "p2": 0.0, "p3": 3.0, "color": "#00ff88", "texture": "",
		"unit": "world", "scale_mode": "fixed", "blend": "add", "color_mode": "two", "color_b": "#ff0088",
		"caps": "round", "dashed": true, "dash_size": 5.0, "dash_spacing": 3.0, "dash_offset": 0.25, "dash_style": "angled",
	}
	var compiled: Array = DrawingPrefabResource.compile_steps([step])
	var entry: Dictionary = compiled[0] if not compiled.is_empty() else {}
	var older: Array = DrawingPrefabResource.compile_steps([{"kind": "line", "x": 0.0, "y": 0.0, "p1": 32.0, "p2": 0.0, "p3": 3.0, "color": "#00ff88", "texture": ""}])
	var older_entry: Dictionary = older[0] if not older.is_empty() else {}
	return SUPPORT.pins(PREFIX, [
		["the keys a card writes, in storage order", ",".join(PackedStringArray(step.keys())),
			"kind,x,y,p1,p2,p3,color,texture,unit,scale_mode,blend,color_mode,color_b,caps,dashed,dash_size,dash_spacing,dash_offset,dash_style"],
		["the ends reach the renderer", str(entry.get("caps")), "round"],
		["the dashes reach the renderer", str(entry.get("dashed")), "true"],
		["so does the dash length", entry.get("dash_size"), 5.0],
		["so does the gap", entry.get("dash_spacing"), 3.0],
		["so does the offset", entry.get("dash_offset"), 0.25],
		["so does the style", str(entry.get("dash_style")), "angled"],
		["and the scale rule", str(entry.get("scale_mode")), "fixed"],
		["a step written before the keys existed compiles undashed", str(older_entry.get("dashed")), "false"],
		["and cut square at its ends, which is the line it always drew", str(older_entry.get("caps")), "none"],
		["and following the stamp's scale, as it always did", str(older_entry.get("scale_mode")), "uniform"],
	])


## The picture: a dashed line is not a plain line, at pixels a reader can point at - and a key the
## rasterizer has never heard of changes nothing at all.
static func _pin_the_picture() -> bool:
	var raster: Script = load(RASTER_PATH)
	var plain: Array = [_pixel_step({})]
	var dashed: Array = [_pixel_step({"dashed": true, "dash_size": 4.0, "dash_spacing": 4.0, "dash_offset": 0.0, "dash_style": "plain", "caps": "none"})]
	var unknown: Array = [_pixel_step({"wobble": 3.0})]
	var plain_image: Image = raster.call("rasterize", plain, PREVIEW_SIZE, PREVIEW_BACKGROUND)
	var dashed_image: Image = raster.call("rasterize", dashed, PREVIEW_SIZE, PREVIEW_BACKGROUND)
	var unknown_image: Image = raster.call("rasterize", unknown, PREVIEW_SIZE, PREVIEW_BACKGROUND)
	return SUPPORT.pins(PREFIX, [
		["the plain line is drawn where the dash is", _is_drawn(plain_image, 12, 32), true],
		["the dashed line is drawn there too", _is_drawn(dashed_image, 12, 32), true],
		["the plain line is drawn where the gap is", _is_drawn(plain_image, 16, 32), true],
		["the dashed line leaves the gap empty", _is_drawn(dashed_image, 16, 32), false],
		["a plain line covers this many pixels", _drawn_pixels(plain_image), 184],
		["a dashed one covers half of them", _drawn_pixels(dashed_image), 92],
		["a key the rasterizer never heard of changes nothing", unknown_image.get_data() == plain_image.get_data(), true],
	])


## The one line step the pixel pins are read from - 40 units long, 4 thick, across the middle.
static func _pixel_step(extra: Dictionary) -> Dictionary:
	var step: Dictionary = {"kind": "line", "x": -20.0, "y": 0.0, "p1": 40.0, "p2": 0.0, "p3": 4.0, "color": "#ff0000", "texture": ""}
	for key: Variant in extra:
		step[str(key)] = extra[key]
	return step


## Whether the step's colour reached one pixel (its red channel is the whole of it against a dark
## background), and how many pixels it reached in all.
static func _is_drawn(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).r > 0.5


static func _drawn_pixels(image: Image) -> int:
	var total: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).r > 0.5:
				total += 1
	return total


## The field keys of a card, in the order it draws them.
static func _keys_of(fields: Array) -> String:
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		keys.append(str((field as Dictionary).get("key", "")))
	return ",".join(keys)


## The section each of those fields sits under, in the same order.
static func _groups_of(fields: Array) -> String:
	var groups: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		groups.append(EventSheetCardSchemas.field_group(field as Dictionary))
	return ",".join(groups)


static func _field_named(fields: Array, key: String) -> Dictionary:
	for field: Variant in fields:
		if str((field as Dictionary).get("key", "")) == key:
			return field
	return {}
