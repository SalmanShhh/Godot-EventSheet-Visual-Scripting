# Godot EventSheets - the Drawing Prefab's shape-aware `steps` editor (editor-only).
#
# Instead of the generic grid's opaque p1/p2/p3 columns, each step is a CARD whose fields match its
# shape - a circle shows "Radius", a rect shows "Width"/"Height", a line shows "End X"/"End Y"/
# "Thickness", and so on. The cards themselves are the shared card-list drawer (drag to reorder,
# fold one open, a searchable Add dropdown); all this file supplies is the shape vocabulary. The
# stored keys (kind, x, y, p1, p2, p3, color, texture) are unchanged, so the pack, the rasterizer
# and the .tres bytes are all untouched - this only relabels and lays out the SAME data.
#
# It lives BESIDE the Inspector plugin rather than inside it, and carries no `class_name`, because
# the plugin is constructed at editor boot: naming the card-list drawer (and, through it, the card
# schemas) from the registered file would compile all of it at every editor start, for every project
# that has no drawing prefab in it. The plugin loads this file BY PATH, the first time a prefab's
# `steps` property is actually parsed.
@tool
extends EditorProperty

var _editor: ShapeStepsEditor = null


func _init() -> void:
	_editor = ShapeStepsEditor.new()
	_editor.value_changed.connect(_on_changed)
	add_child(_editor)
	set_bottom_editor(_editor)


func _on_changed(steps: Array) -> void:
	emit_changed(get_edited_property(), steps)
	# A plain property write does not fire the resource's `changed` signal, so preview panels
	# (and the FileSystem thumbnail) would not repaint. Emit it explicitly on each edit.
	var edited: Object = get_edited_object()
	if edited is Resource:
		(edited as Resource).emit_changed()


func _update_property() -> void:
	var incoming: Variant = get_edited_object().get(get_edited_property())
	if not (incoming is Array):
		incoming = []
	# Skip the write-back the emit_changed round-trip causes (values already match) so an open
	# SpinBox / picker keeps focus while you type.
	if (incoming as Array) == _editor.get_steps():
		return
	_editor.set_steps(incoming as Array)


## The shape-aware steps list: the SHARED card-list drawer, handed the prefab's own vocabulary. Each
## step is a card titled by its shape, read top to bottom as four short sections - where it sits and
## how it blends, its geometry, its colours, and its dashes - and the Add button is the searchable
## dropdown every card list has.
##
## THE EIGHT SHIPPED KEYS ARE UNTOUCHED. kind, x, y, p1, p2, p3, color and texture mean exactly what
## they always did, so a prefab saved before this card existed opens, draws, edits and saves as the
## same bytes. What the card adds beside them is OPTIONAL - a step without them draws the way it
## always drew, and only a step somebody actually adds or edits gains one:
##
##   unit         how the thickness number is READ (px / world / screen). The number itself is
##                always pixels, exactly as a shape stores it, so switching the dropdown never
##                moves a stored value.
##   scale_mode   whether the thickness follows the stamp's scale (uniform) or holds its width
##                however the whole prefab is scaled (fixed).
##   blend        how the step meets what is behind it.
##   color_mode   single, two (a blend along the step) or gradient.
##   color_b      the far end of a two-colour step.
##   caps         what the two ends of a line look like: none, square or round.
##   dashed       the dash pattern on a line: the length of one dash, the gap after it (the two are
##   dash_size    linked by the "=" beside them), how far the pattern is moved along, and which of
##   dash_spacing the three ends the dashes wear.
##   dash_offset
##   dash_style
##
## WHAT THE PICTURE CAN AND CANNOT SHOW. The canvas and the thumbnail draw with the engine's own
## draw calls, which know caps, dashes, the scale rule and a single colour - so those are drawn. A
## two-colour or gradient step and a blend other than normal are STORED and drawn flat: the crisp,
## blended, gradient version of the same shape is what the Vector Shapes nodes are for, and the
## guide says so rather than the card pretending.
class ShapeStepsEditor:
	extends EventSheetCardListDrawer

	const KINDS: Array[String] = ["circle", "ring", "rect", "line", "cone", "stamp"]
	## The four sections a card reads as, in order.
	const GROUP_PLACEMENT: String = "Placement"
	const GROUP_GEOMETRY: String = "Geometry"
	const GROUP_COLOUR: String = "Colour"
	const GROUP_DASHED: String = "Dashed"
	## Per-shape fields, in display order. `key` is the frozen storage slot (p1/p2/p3/texture); `label` is
	## the human title shown beside it; `drawer` names the editor, in the same words an export marker uses.
	## The placement, colour and dash sections are common and are appended around these.
	const SHAPE_FIELDS: Dictionary = {
		"circle": [{"key": "p1", "label": "Radius"}],
		"ring": [{"key": "p1", "label": "Radius"}, {"key": "p2", "label": "Thickness", "drawer": "unit:kinds=px|world|screen,store=px"}, {"key": "unit", "label": "Read in", "drawer": "options:px,world,screen"}],
		"rect": [{"key": "p1", "label": "Width"}, {"key": "p2", "label": "Height"}],
		"line": [{"key": "p1", "label": "End X"}, {"key": "p2", "label": "End Y"}, {"key": "p3", "label": "Thickness", "drawer": "unit:kinds=px|world|screen,store=px"}, {"key": "unit", "label": "Read in", "drawer": "options:px,world,screen"}],
		"cone": [{"key": "p1", "label": "Facing"}, {"key": "p2", "label": "FOV"}, {"key": "p3", "label": "Radius"}],
		"stamp": [{"key": "p1", "label": "Scale"}, {"key": "p2", "label": "Spin"}, {"key": "texture", "label": "Texture", "drawer": "texture_preview"}],
	}
	## Which shapes have a stroke with two ends, and so a Caps row - and which have a length a dash
	## pattern can run along. The pattern is walked along LINE SEGMENTS, so a line has one and the
	## curved shapes do not: a card never offers a field the picture would not change.
	const CAPPED_KINDS: Array[String] = ["line"]
	const DASHABLE_KINDS: Array[String] = ["line"]
	## And which have a THICKNESS for the scale rule to be about. A stamp is scaled by its own Scale
	## field and a disc has no stroke at all, so neither is asked a question it cannot answer.
	const THICKNESS_KINDS: Array[String] = ["ring", "line"]
	## What a freshly ADDED step of each shape starts as, in storage order. Every slot is seeded so the
	## Dictionary shape matches what the rasterizer and the round-trip expect the moment it is added -
	## and only then: loading a step never writes one of these.
	const SHAPE_DEFAULTS: Dictionary = {
		"circle": {"p1": 12.0, "p2": 0.0, "p3": 0.0},
		"ring": {"p1": 12.0, "p2": 2.0, "p3": 0.0},
		"rect": {"p1": 24.0, "p2": 16.0, "p3": 0.0},
		"line": {"p1": 24.0, "p2": 0.0, "p3": 2.0},
		"cone": {"p1": 0.0, "p2": 60.0, "p3": 32.0},
		"stamp": {"p1": 1.0, "p2": 0.0, "p3": 0.0},
	}
	## What the optional keys start as on a newly added step - each one the behaviour the step had
	## before the key existed, so a step added today and a step added a year ago draw the same
	## picture until somebody changes one.
	const OPTIONAL_DEFAULTS: Dictionary = {
		"unit": "px",
		"scale_mode": "uniform",
		"blend": "normal",
		"color_mode": "single",
		"color_b": "#ffffff",
		"caps": "none",
		"dashed": false,
		"dash_size": 8.0,
		"dash_spacing": 6.0,
		"dash_offset": 0.0,
		"dash_style": "plain",
	}
	## What each shape is, in the words the card's info line shows when it is unfolded.
	const SHAPE_HELP: Dictionary = {
		"circle": "A filled disc of the given radius, centred on the offset.",
		"ring": "An outlined circle - its radius, and how thick the outline is.",
		"rect": "A filled rectangle of the given width and height, centred on the offset.",
		"line": "A stroke from the offset to the end point, of the given thickness - with ends you pick and a dash pattern you can turn on.",
		"cone": "A filled wedge: which way it faces, how wide it opens, and how far it reaches.",
		"stamp": "A texture drawn at the offset, scaled and spun.",
	}


	func _init() -> void:
		super._init({"kind_key": "kind", "stripe_key": "kind", "schema_dict": build_schema()})


	## The prefab's vocabulary as a card schema: one kind per shape, its fields grouped into the four
	## sections a designer reads in order. The stripe is coloured by the SHAPE, so a list of mixed
	## shapes reads at a glance, and the schema declares no enable key because a step the rasterizer
	## would still draw must not grow a checkbox that does nothing.
	static func build_schema() -> Dictionary:
		var kinds: Array = []
		for kind: String in KINDS:
			kinds.append({
				"kind": kind,
				"category": kind,
				"label": kind.capitalize(),
				"help": SHAPE_HELP.get(kind, ""),
				"fields": fields_for(kind),
				"defaults": defaults_for(kind),
			})
		return {"kinds": kinds}


	## One shape's fields, in the order the card draws them: where it sits and how it blends, what it
	## is, what colour it is, and (for a shape with a length to run one along) its dashes.
	static func fields_for(kind: String) -> Array:
		var fields: Array = [
			{"key": "kind", "label": "Shape", "drawer": "options:%s" % ",".join(PackedStringArray(KINDS)), "group": GROUP_PLACEMENT},
			{"key": "x", "label": "Offset X", "group": GROUP_PLACEMENT},
			{"key": "y", "label": "Offset Y", "group": GROUP_PLACEMENT},
			{"key": "blend", "label": "Blend", "drawer": "options:normal,add,subtract,multiply,premultiplied", "group": GROUP_PLACEMENT},
		]
		if THICKNESS_KINDS.has(kind):
			fields.append({"key": "scale_mode", "label": "Scale", "drawer": "toggle_row:uniform,fixed:segmented", "group": GROUP_PLACEMENT})
		for field: Variant in SHAPE_FIELDS.get(kind, []):
			var shape_field: Dictionary = (field as Dictionary).duplicate()
			shape_field["group"] = GROUP_GEOMETRY
			fields.append(shape_field)
		fields.append({"key": "color_mode", "label": "Colour mode", "drawer": "options:single,two,gradient", "group": GROUP_COLOUR})
		fields.append({"key": "color", "label": "Colour", "drawer": "swatch_row", "group": GROUP_COLOUR})
		fields.append({"key": "color_b", "label": "Second colour", "drawer": "swatch_row", "show_if": "color_mode==two", "group": GROUP_COLOUR})
		if CAPPED_KINDS.has(kind):
			fields.append({"key": "caps", "label": "End caps", "drawer": "toggle_row:none,square,round:segmented", "group": GROUP_COLOUR})
		if DASHABLE_KINDS.has(kind):
			fields.append({"key": "dashed", "label": "Dashed", "drawer": "bool", "group": GROUP_DASHED})
			fields.append({"key": "dash_size", "label": "Dash", "show_if": "dashed", "link": "dash_spacing", "group": GROUP_DASHED})
			fields.append({"key": "dash_spacing", "label": "Gap", "show_if": "dashed", "link": "dash_size", "group": GROUP_DASHED})
			fields.append({"key": "dash_offset", "label": "Offset", "show_if": "dashed", "group": GROUP_DASHED})
			fields.append({"key": "dash_style", "label": "Style", "drawer": "toggle_row:plain,angled,rounded:segmented", "show_if": "dashed", "group": GROUP_DASHED})
		return fields


	## What one freshly added step of a shape holds: the eight shipped keys exactly as they were
	## seeded before this card existed, then the optional keys the card actually shows for that
	## shape - each at the value that draws what the step drew without it.
	static func defaults_for(kind: String) -> Dictionary:
		var defaults: Dictionary = {"x": 0.0, "y": 0.0}
		for slot: Variant in SHAPE_DEFAULTS.get(kind, {}):
			defaults[str(slot)] = SHAPE_DEFAULTS[kind][slot]
		defaults["color"] = "#ffffff"
		defaults["texture"] = ""
		for field: Variant in fields_for(kind):
			var key: String = str((field as Dictionary).get("key", ""))
			if OPTIONAL_DEFAULTS.has(key) and not defaults.has(key):
				defaults[key] = OPTIONAL_DEFAULTS[key]
		return defaults


	func set_steps(steps: Array) -> void:
		set_value(steps)


	func get_steps() -> Array:
		return get_value()


	## A step of the DEFAULT shape - a visible filled circle, so the preview shows something the moment
	## a step exists. The Add dropdown names its own shape; this is the door for everything else.
	func add_default_step() -> void:
		add_first_kind()
