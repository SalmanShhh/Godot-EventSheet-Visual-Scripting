# Pack source - vector_shapes, the stroke style a shape may wear instead of its own fields.
#
# Twenty aim lines in one game want one thickness, one cap and one dash pattern. A style is that
# answer as a FILE the project owns: a resource holding the look half of a shape's fields, dropped
# into any 2D shape's Style slot. The pack ships none of them - the first one is saved out of a
# shape somebody tuned, which is what the Save As Style button on a shape's Inspector does.
#
# WHY THE KEYS ARE THE SHAPE'S OWN FIELD NAMES. A style does not translate: every field here is
# spelled exactly as the shape spells it, so `value_for("dash_count")` answers for `dash_count` and
# nothing keeps a mapping table in step. It also means a shape that HAS NOT GOT a field (a Triangle
# has no dashes) is untouched by a style that carries one: the shape reads its own property first,
# and a property it does not declare reads as nothing at all.
#
# It is a 2D style. The 3D shapes measure a thickness in world units with a unit of their own, so a
# style holding pixels would be a lie there rather than a shortcut, and their Inspector has no slot.
extends Resource

#region style_fields
## How wide the stroke is. The dropdown at the field's right reads the number in pixels, world units
## or screen units; the number stored here is always pixels, exactly as a shape stores it.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:unit:kinds=px|world|screen,store=px") var thickness: float = 2.0:
	set(value):
		thickness = value
		emit_changed()
## Whether the stroke follows the node's own scale, or keeps the weight it has on screen however far
## the camera zooms.
@export_enum("with the node", "fixed on screen") var thickness_scale: String = "with the node":
	set(value):
		thickness_scale = value
		emit_changed()
## What the two ends of a stroke look like: cut off, squared off half a thickness past the end, or
## rounded.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:none,square,round:segmented") var caps: String = "round":
	set(value):
		caps = value
		emit_changed()
@export_group("Colour")
## How the shape is coloured. A shape that has not got the mode this names keeps drawing the way it
## did - the words are the family's, and each shape offers the ones it can draw.
@export_enum("single", "two", "radial", "angular", "gradient", "per corner") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		emit_changed()
## The main colour - the whole shape in single mode, and the first end of the blend in the others.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour: Color = Color("#e6e6e6"):
	set(value):
		colour = value
		emit_changed()
## The other end of the blend.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour_b: Color = Color("#4a90d9"):
	set(value):
		colour_b = value
		emit_changed()
## The ramp a gradient shape is coloured with. An empty slot leaves each shape its own ramp.
@export var gradient: Gradient = null:
	set(value):
		gradient = value
		emit_changed()
@export_group("Dashed")
## Turns the stroke into dashes on every shape wearing this style.
@export var dashed: bool = false:
	set(value):
		dashed = value
		emit_changed()
## How a dash length is measured: in world pixels, in multiples of the stroke's own thickness, or
## not at all - "count" fits a fixed number of dashes to the shape however long it is.
@export_enum("world", "relative", "count") var dash_space: String = "count":
	set(value):
		dash_space = value
		emit_changed()
## How the pattern meets the ends: off leaves it where it falls, tiling fits it a whole number of
## times, end to end also centres a dash on each end.
@export_enum("off", "tiling", "end to end") var dash_snap: String = "tiling":
	set(value):
		dash_snap = value
		emit_changed()
## One dash, in the space above.
@export var dash_size: float = 12.0:
	set(value):
		dash_size = value
		emit_changed()
## How many dashes the shape carries, in count mode.
@export_range(1, 128, 1) var dash_count: int = 12:
	set(value):
		dash_count = value
		emit_changed()
## The gap after each dash: a share of one dash period in count mode, a length otherwise.
@export var dash_spacing: float = 0.5:
	set(value):
		dash_spacing = value
		emit_changed()
## What one dash looks like: cut square, leaning over, or rounded at both ends.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:plain,angled,rounded:icons=vector_shapes_dash") var dash_style: String = "plain":
	set(value):
		dash_style = value
		emit_changed()
@export_group("Drawing")
## How a shape wearing this style meets what is behind it.
@export_enum("normal", "add", "subtract", "multiply", "premultiplied") var blend: String = "normal":
	set(value):
		blend = value
		emit_changed()
#endregion

#region style_runtime
## The shape fields a style speaks for, spelled as the shapes spell them. A field NOT in this list
## is the shape's own however the style is filled in - which is what keeps a style a LOOK rather
## than a second copy of a shape: a radius, an end point and a list of points are never in here.
## @ace_hidden
static func styled_keys() -> PackedStringArray:
	return PackedStringArray(["thickness", "thickness_scale", "caps", "colour_mode", "colour", "colour_b", "gradient", "dashed", "dash_space", "dash_snap", "dash_size", "dash_count", "dash_spacing", "dash_style", "blend"])

## What this style says one field should be, or null when it says nothing about it. A shape asks
## this for every field it draws with, so an unfilled gradient slot (null) leaves the shape's own.
## @ace_hidden
func value_for(key: String) -> Variant:
	if not styled_keys().has(key):
		return null
	return get(key)
#endregion
