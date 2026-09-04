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
## step is a card titled by its shape, whose fields are that shape's - a circle shows "Radius", a
## line shows "End X" / "End Y" / "Thickness" - and the Add button is the searchable dropdown every
## card list has. The stored keys (kind, x, y, p1, p2, p3, color, texture) are untouched: nothing is
## written into a step on load, and an edit keeps the spelling the file already used, so a prefab
## saved before this editor existed opens, edits and saves as the same bytes.
class ShapeStepsEditor:
	extends EventSheetCardListDrawer

	const KINDS: Array[String] = ["circle", "ring", "rect", "line", "cone", "stamp"]
	## Per-shape fields, in display order. `key` is the frozen storage slot (p1/p2/p3/texture); `label` is
	## the human title shown beside it; `drawer` names the editor, in the same words an export marker uses.
	## x, y (offset) and color are common to every shape and appended separately.
	const SHAPE_FIELDS: Dictionary = {
		"circle": [{"key": "p1", "label": "Radius"}],
		"ring": [{"key": "p1", "label": "Radius"}, {"key": "p2", "label": "Thickness"}],
		"rect": [{"key": "p1", "label": "Width"}, {"key": "p2", "label": "Height"}],
		"line": [{"key": "p1", "label": "End X"}, {"key": "p2", "label": "End Y"}, {"key": "p3", "label": "Thickness"}],
		"cone": [{"key": "p1", "label": "Facing"}, {"key": "p2", "label": "FOV"}, {"key": "p3", "label": "Radius"}],
		"stamp": [{"key": "p1", "label": "Scale"}, {"key": "p2", "label": "Spin"}, {"key": "texture", "label": "Texture", "drawer": "texture_preview"}],
	}
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
	## What each shape is, in the words the card's info line shows when it is unfolded.
	const SHAPE_HELP: Dictionary = {
		"circle": "A filled disc of the given radius, centred on the offset.",
		"ring": "An outlined circle - its radius, and how thick the outline is.",
		"rect": "A filled rectangle of the given width and height, centred on the offset.",
		"line": "A stroke from the offset to the end point, of the given thickness.",
		"cone": "A filled wedge: which way it faces, how wide it opens, and how far it reaches.",
		"stamp": "A texture drawn at the offset, scaled and spun.",
	}


	func _init() -> void:
		super._init({"kind_key": "kind", "stripe_key": "kind", "schema_dict": build_schema()})


	## The prefab's vocabulary as a card schema: one kind per shape, its fields the shape's own slots
	## followed by the offset and the colour every shape has. The stripe is coloured by the SHAPE, so
	## a list of mixed shapes reads at a glance, and the schema declares no enable key because a step
	## the rasterizer would still draw must not grow a checkbox that does nothing.
	static func build_schema() -> Dictionary:
		var kinds: Array = []
		for kind: String in KINDS:
			var fields: Array = [{"key": "kind", "label": "Shape", "drawer": "options:%s" % ",".join(PackedStringArray(KINDS))}]
			for field: Variant in SHAPE_FIELDS[kind]:
				fields.append(field)
			fields.append({"key": "x", "label": "Offset X"})
			fields.append({"key": "y", "label": "Offset Y"})
			fields.append({"key": "color", "label": "Color", "drawer": "swatch_row"})
			var defaults: Dictionary = {"x": 0.0, "y": 0.0}
			for slot: Variant in SHAPE_DEFAULTS[kind]:
				defaults[str(slot)] = SHAPE_DEFAULTS[kind][slot]
			defaults["color"] = "#ffffff"
			defaults["texture"] = ""
			kinds.append({
				"kind": kind,
				"category": kind,
				"label": kind.capitalize(),
				"help": SHAPE_HELP.get(kind, ""),
				"fields": fields,
				"defaults": defaults,
			})
		return {"kinds": kinds}


	func set_steps(steps: Array) -> void:
		set_value(steps)


	func get_steps() -> Array:
		return get_value()


	## A step of the DEFAULT shape - a visible filled circle, so the preview shows something the moment
	## a step exists. The Add dropdown names its own shape; this is the door for everything else.
	func add_default_step() -> void:
		add_first_kind()
