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

var _view: ShapeStepsView = null
## What joins this list to the prefab's picture (set by the Inspector plugin): a click in the picture selects a card here, and a
## selection here quietens the other shapes in the picture.
var picking: RefCounted = null


func _init() -> void:
	_view = ShapeStepsView.new()
	_view.value_changed.connect(_on_changed)
	_view.view_switched.connect(_on_switched)
	add_child(_view)
	set_bottom_editor(_view)


func _ready() -> void:
	if picking != null:
		picking.call("attach_cards", _view.cards())
	# The view this object was last left in, for as long as the editor runs: the Inspector rebuilds its rows on
	# every selection, and a list shown as a table a moment ago comes back as a table. Nothing is written to the file.
	var edited: Object = get_edited_object()
	if edited != null and ShapeStepsView.remembered(edited.get_instance_id()):
		_view.show_table(true)


func _on_switched(table: bool) -> void:
	var edited: Object = get_edited_object()
	if edited != null:
		ShapeStepsView.remember(edited.get_instance_id(), table)


func _on_changed(steps: Array) -> void:
	emit_changed(get_edited_property(), steps)
	# A plain property write does not fire the resource's `changed` signal, so preview panels
	# (and the FileSystem thumbnail) would not repaint. Emit it explicitly on each edit.
	var edited: Object = get_edited_object()
	if edited is Resource:
		(edited as Resource).emit_changed()


## A locked prefab (one inside an imported scene, or a read-only sub-resource) shows its cards but
## cannot be changed from them.
func _set_read_only(read_only: bool) -> void:
	_view.set_editable(not read_only)


func _update_property() -> void:
	var incoming: Variant = get_edited_object().get(get_edited_property())
	if not (incoming is Array):
		incoming = []
	# Skip the write-back the emit_changed round-trip causes (values already match) so an open
	# SpinBox / picker keeps focus while you type.
	if (incoming as Array) == _view.get_steps():
		return
	_view.set_steps(incoming as Array)


## The shape-aware steps list: the SHARED card-list drawer, handed the prefab's own vocabulary. Each
## step is a card titled by its shape, one surface with no section headings: the shape, where it sits,
## its own named fields and its colour, with a line's look in a fold - and the Add button is the
## searchable box every card list has.
##
## A THICKNESS IS READ IN THE UNIT ITS OWN FIELD OFFERS. The Thickness row carries the unit dropdown
## (px, world, screen) and always STORES pixels, exactly as a shape node does, so switching the view
## never moves a stored value - and there is no second control saying the same thing beside it.
##
## THE EIGHT SHIPPED KEYS ARE UNTOUCHED. kind, x, y, p1, p2, p3, color and texture mean exactly what
## they always did, so a prefab saved before this card existed opens, draws, edits and saves as the
## same bytes. What the card adds beside them is OPTIONAL - a step without them draws the way it
## always drew, and only a step somebody actually adds or edits gains one:
##
##   scale_mode   whether the thickness follows the stamp's scale (uniform) or holds its width
##                however the whole prefab is scaled (fixed).
##   caps         what the two ends of a line look like: none, square or round.
##   dashed       the dash pattern on a line: the length of one dash, the gap after it (the two are
##   dash_size    linked by the "=" beside them), how far the pattern is moved along, and which of
##   dash_spacing the three ends the dashes wear.
##   dash_offset
##   dash_style
##
## EVERY FIELD ON THE CARD CHANGES THE PICTURE. The three renderers a prefab has - the stamp node,
## the canvas gizmo and the off-thread thumbnail - all draw with the engine's own `_draw()` calls,
## and one `compile_steps` normaliser feeds all three. So a field is on this card only when that
## normaliser carries it and a draw call reads it: caps, dashes, the scale rule and one colour.
##
## WHICH IS WHY THERE IS NO BLEND ROW, AND NO SECOND COLOUR. A `_draw()` call has no blend mode of
## its own - blending is a `CanvasItemMaterial` on the NODE, one for every step it draws - so a
## per-step blend is not something any of the three renderers could honour without a node per step.
## A ramp needs a Gradient to point at, and a step is a Dictionary of numbers with nowhere to keep
## one. Those looks are what the Vector Shapes nodes are for: each is its own node, so each carries
## its own material and its own ramp. A control that stored a word no renderer read would be a
## control that changes nothing, which is worse than not offering it.
class ShapeStepsEditor:
	extends EventSheetCardListDrawer

	## Asked for by the quiet link under the list: show this same list as a table.
	signal table_requested


	const KINDS: Array[String] = ["circle", "ring", "rect", "line", "cone", "stamp", "arc", "pie", "rounded_rect", "regular_polygon"]
	const SHAPE_TILE_PATH: String = "res://addons/eventsheet/editor/inspector/drawing_prefab_shape_tile.gd"
	## Per-shape fields, in display order. `key` is the frozen storage slot (p1/p2/p3/texture); `label` is
	## the human title shown beside it; `drawer` names the editor, in the same words an export marker uses.
	## The shape, offset, colour and line-look rows are common and are put around these.
	const SHAPE_FIELDS: Dictionary = {
		"circle": [{"key": "p1", "label": "Radius", "suffix": "px"}],
		"ring": [{"key": "p1", "label": "Radius", "suffix": "px"}, {"key": "p2", "label": "Thickness", "drawer": "unit:kinds=px|world|screen,store=px"}],
		"rect": [{"key": "p1", "label": "Width", "suffix": "px"}, {"key": "p2", "label": "Height", "suffix": "px"}],
		"line": [{"key": "p1", "label": "End X", "suffix": "px"}, {"key": "p2", "label": "End Y", "suffix": "px"}, {"key": "p3", "label": "Thickness", "drawer": "unit:kinds=px|world|screen,store=px"}],
		"cone": [{"key": "p1", "label": "Facing", "suffix": "°"}, {"key": "p2", "label": "FOV", "suffix": "°"}, {"key": "p3", "label": "Radius", "suffix": "px"}],
		"stamp": [{"key": "texture", "label": "Texture", "drawer": "resource:Texture2D"}, {"key": "p1", "label": "Scale", "suffix": "x"}, {"key": "p2", "label": "Spin", "suffix": "°"}],
		"arc": [{"key": "p1", "label": "Radius", "suffix": "px"}, {"key": "p2", "label": "Start angle", "suffix": "°"}, {"key": "p3", "label": "End angle", "suffix": "°"}, {"key": "thickness", "label": "Thickness", "drawer": "unit:kinds=px|world|screen,store=px", "unset": 2.0}],
		"pie": [{"key": "p1", "label": "Radius", "suffix": "px"}, {"key": "p2", "label": "Start angle", "suffix": "°"}, {"key": "p3", "label": "End angle", "suffix": "°"}],
		"rounded_rect": [{"key": "p1", "label": "Width", "suffix": "px"}, {"key": "p2", "label": "Height", "suffix": "px"}, {"key": "p3", "label": "Corners", "suffix": "px"}],
		"regular_polygon": [{"key": "p1", "label": "Radius", "suffix": "px"}, {"key": "p2", "label": "Sides", "drawer": "int"}, {"key": "p3", "label": "Angle", "suffix": "°"}],
	}
	## The word each shape's card says under its fields, where the shape has one worth saying.
	const HELP_LINE_KINDS: Array[String] = ["rect", "stamp", "rounded_rect"]
	## The fold a line's own look sits in, and the keys that make it open on its own when one differs.
	const LOOK_FOLD: String = "Line look"
	## Which shapes have a stroke with two ends, and so a Caps row - and which have a length a dash
	## pattern can run along. The pattern is walked along LINE SEGMENTS, so a line has one and the
	## curved shapes do not: a card never offers a field the picture would not change.
	const CAPPED_KINDS: Array[String] = ["line"]
	const DASHABLE_KINDS: Array[String] = ["line"]
	## And which have a THICKNESS for the scale rule to be about. A stamp is scaled by its own Scale
	## field, a disc has no stroke at all, a ring's outline is drawn at the thickness it says
	## whatever the scale rule (no renderer reads one for a ring), so only a line and an arc are asked.
	const THICKNESS_KINDS: Array[String] = ["line", "arc"]
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
		"arc": {"p1": 16.0, "p2": -90.0, "p3": 180.0, "thickness": 3.0},
		"pie": {"p1": 16.0, "p2": -90.0, "p3": 90.0},
		"rounded_rect": {"p1": 32.0, "p2": 20.0, "p3": 6.0},
		"regular_polygon": {"p1": 16.0, "p2": 6.0, "p3": -90.0},
	}
	## What the optional keys start as on a newly added step - each one the behaviour the step had
	## before the key existed, so a step added today and a step added a year ago draw the same
	## picture until somebody changes one.
	const OPTIONAL_DEFAULTS: Dictionary = {
		"scale_mode": "uniform",
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
		"rect": "A filled rectangle of the given width and height, drawn right and down from the offset.",
		"line": "A stroke from the offset to the end point, of the given thickness - with ends you pick and a dash pattern you can turn on.",
		"cone": "A filled wedge: which way it faces, how wide it opens, and how far it reaches.",
		"stamp": "A texture drawn at the offset, scaled and spun.",
		"arc": "An outlined part of a circle: its radius, where it starts and ends, and how thick it is.",
		"pie": "A filled slice of a circle between two angles.",
		"rounded_rect": "A filled rectangle with round corners, drawn right and down from the offset.",
		"regular_polygon": "A filled shape of equal sides around the offset: a triangle, a hexagon.",
	}


	func _init() -> void:
		super._init({"kind_key": "kind", "stripe_key": "kind", "schema_dict": build_schema()})
		# Under the list, quiet and at the right: the way to see the same shapes as a table, for edits across
		# many of them. It only changes how THIS Inspector shows the list; nothing is written for it.
		var under: HBoxContainer = HBoxContainer.new()
		var gap: Control = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		under.add_child(gap)
		var link: LinkButton = LinkButton.new()
		link.text = EventSheetL10n.translate("Open as a table")
		link.tooltip_text = EventSheetL10n.translate("Shows this same list as a table. Nothing is saved differently.")
		link.pressed.connect(func() -> void: table_requested.emit())
		under.add_child(link)
		_body.add_child(under)


	## The prefab's vocabulary as a card schema: one kind per shape. The stripe is coloured by the
	## SHAPE, so a list of mixed shapes reads at a glance, and the schema declares no enable key because
	## a step the rasterizer would still draw must not grow a checkbox that does nothing. Each card line
	## wears a tile that draws its shape in the step's own colour and says its size in the shape's own
	## words (`badge`), and both follow the numbers as they are typed (`live_head`).
	static func build_schema() -> Dictionary:
		var kinds: Array = []
		for kind: String in KINDS:
			kinds.append({
				"kind": kind,
				"category": kind,
				"label": kind_label(kind),
				"help": SHAPE_HELP.get(kind, ""),
				"fields": fields_for(kind),
				"defaults": defaults_for(kind),
				"badge": Callable(ShapeStepsEditor, "summary_of"),
			})
		return {"kinds": kinds, "head_tile": Callable(ShapeStepsEditor, "make_tile"), "live_head": true, "badge_warn": Callable(ShapeStepsEditor, "has_finding"), "fold_word": EventSheetL10n.translate("Shapes (%d)"), "link_before_unit": true,
			"help_in_body": false, "fold_open": Callable(ShapeStepsEditor, "fold_open_for"), "fallback_entry": Callable(ShapeStepsEditor, "unknown_entry"),
			"order_captions": [EventSheetL10n.translate("Drawn first, underneath"), EventSheetL10n.translate("Drawn last, on top")],
			"add_word": EventSheetL10n.translate("Add shape"), "add_hint": EventSheetL10n.translate("Enter adds the highlighted shape."),
			"flat_add": true, "open_new": true, "kind_icon": Callable(ShapeStepsEditor, "kind_icon")}


	## A shape's plain name, in the editor's language. The stored word (`rect`) never changes.
	static func kind_label(kind: String) -> String:
		match kind:
			"circle":
				return EventSheetL10n.translate("Circle")
			"ring":
				return EventSheetL10n.translate("Ring")
			"rect":
				return EventSheetL10n.translate("Rectangle")
			"line":
				# "Line" alone is a row of text in most languages, so the shape has a key of its own; a language
				# with no row for it reads the plain English word.
				var said: String = EventSheetL10n.translate("Line (shape)")
				return "Line" if said == "Line (shape)" else said
			"cone":
				return EventSheetL10n.translate("Cone")
			"stamp":
				return EventSheetL10n.translate("Stamp")
			"arc":
				return EventSheetL10n.translate("Arc")
			"pie":
				return EventSheetL10n.translate("Pie")
			"rounded_rect":
				return EventSheetL10n.translate("Rounded rectangle")
			"regular_polygon":
				return EventSheetL10n.translate("Polygon")
		return kind.capitalize()


	## A number as a person writes it: no trailing ".0", at most two decimals.
	static func _num(value: Variant) -> String:
		var text: String = str(snappedf(float(value), 0.01))
		return text.trim_suffix(".0")


	## The file a stamp's texture text names: a path as written, or the path a uid text stands for. "" when
	## the card names none.
	static func texture_path_of(card: Dictionary) -> String:
		var text: String = str(card.get("texture", "")).strip_edges()
		if text.begins_with("uid://"):
			var id: int = ResourceUID.text_to_id(text)
			return ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
		return text


	## What a card line says beside the shape's name, in that shape's own words: "radius 46, 5 px thick",
	## "24 x 16", a line's true length, how wide a cone opens, a stamp's file.
	static func summary_of(card: Dictionary) -> String:
		var p1: float = float(card.get("p1", 0.0))
		var p2: float = float(card.get("p2", 0.0))
		match str(card.get("kind", "")):
			"circle":
				return EventSheetL10n.translate("radius %s") % _num(p1)
			"ring":
				return EventSheetL10n.translate("radius %s, %s px thick") % [_num(p1), _num(p2)]
			"rect":
				return EventSheetL10n.translate("%s x %s") % [_num(p1), _num(p2)]
			"line":
				var length: float = Vector2(float(card.get("x", 0.0)), float(card.get("y", 0.0))).distance_to(Vector2(p1, p2))
				return EventSheetL10n.translate("%s px long") % _num(length)
			"cone":
				return EventSheetL10n.translate("%s° wide") % _num(p2)
			"arc", "pie":
				return EventSheetL10n.translate("radius %s, %s°") % [_num(p1), _num(minf(absf(float(card.get("p3", 0.0)) - p2), 360.0))]
			"rounded_rect":
				return EventSheetL10n.translate("%s x %s") % [_num(p1), _num(p2)]
			"regular_polygon":
				return EventSheetL10n.translate("%s sides, radius %s") % [_num(clampf(roundf(p2), 3.0, 32.0)), _num(p1)]
			"stamp":
				var text: String = str(card.get("texture", "")).strip_edges()
				if text.is_empty():
					return EventSheetL10n.translate("no texture")
				var path: String = texture_path_of(card)
				if path.is_empty():
					return EventSheetL10n.translate("texture not found")
				return path.get_file() if ResourceLoader.exists(path) else EventSheetL10n.translate("%s (not found)") % path.get_file()
		return str(card.get("kind", ""))


	## The tile on a card line: the shape drawn in the step's colour. Loaded by path, so nothing that runs
	## at editor boot names it.
	static func make_tile(card: Dictionary, on_light: bool) -> Control:
		var tile: Control = load(SHAPE_TILE_PATH).new(int(EventSheetLookStyle.px(16.0)), on_light)
		tile.call("set_card", card)
		return tile


	## What is wrong with a step, in at most two short plain sentences - or "" when it draws something. A
	## finding is said under the field on the open card and, through the summary, on the folded line.
	static func finding_of(card: Dictionary) -> String:
		var p1: float = float(card.get("p1", 0.0))
		var p2: float = float(card.get("p2", 0.0))
		var p3: float = float(card.get("p3", 0.0))
		match str(card.get("kind", "")):
			"circle":
				if p1 <= 0.0:
					return EventSheetL10n.translate("Radius is 0, so this circle draws nothing.")
			"ring":
				if p1 <= 0.0:
					return EventSheetL10n.translate("Radius is 0, so this ring draws nothing.")
			"rect":
				if p1 <= 0.0:
					return EventSheetL10n.translate("Width is 0, so this rectangle draws nothing.")
				if p2 <= 0.0:
					return EventSheetL10n.translate("Height is 0, so this rectangle draws nothing.")
			"line":
				if Vector2(float(card.get("x", 0.0)), float(card.get("y", 0.0))).is_equal_approx(Vector2(p1, p2)):
					return EventSheetL10n.translate("The start and the end are the same point, so this line has no length.")
			"cone":
				if p2 <= 0.0:
					return EventSheetL10n.translate("FOV is 0, so this cone draws nothing.")
				if p3 <= 0.0:
					return EventSheetL10n.translate("Radius is 0, so this cone draws nothing.")
			"arc", "pie":
				var shape_word: String = "arc" if str(card.get("kind", "")) == "arc" else "pie"
				if p1 <= 0.0:
					return EventSheetL10n.translate("Radius is 0, so this arc draws nothing.") if shape_word == "arc" else EventSheetL10n.translate("Radius is 0, so this pie draws nothing.")
				if absf(p3 - p2) < 0.03:
					return EventSheetL10n.translate("The start and the end are the same angle, so this arc draws nothing.") if shape_word == "arc" else EventSheetL10n.translate("The start and the end are the same angle, so this pie draws nothing.")
			"rounded_rect":
				if p1 <= 0.0:
					return EventSheetL10n.translate("Width is 0, so this rounded rectangle draws nothing.")
				if p2 <= 0.0:
					return EventSheetL10n.translate("Height is 0, so this rounded rectangle draws nothing.")
				if p3 > minf(p1, p2) * 0.5 + 0.001:
					return EventSheetL10n.translate("The corners are larger than half the shorter side, so they are drawn at half of it.")
			"regular_polygon":
				if p1 <= 0.0:
					return EventSheetL10n.translate("Radius is 0, so this polygon draws nothing.")
				if roundf(p2) < 3.0:
					return EventSheetL10n.translate("A polygon needs at least 3 sides, so this one is drawn with 3.")
				if roundf(p2) > 32.0:
					return EventSheetL10n.translate("A polygon is drawn with 32 sides at most, so this one is drawn with 32.")
			"stamp":
				if str(card.get("texture", "")).strip_edges().is_empty():
					return EventSheetL10n.translate("No texture yet, so this shape draws nothing.")
				var path: String = texture_path_of(card)
				if path.is_empty() or not ResourceLoader.exists(path):
					return EventSheetL10n.translate("The texture could not be loaded, so this shape draws nothing.")
			_:
				return EventSheetL10n.translate("\"%s\" is not a shape this list knows. It is kept as it is.") % str(card.get("kind", ""))
		return ""


	static func has_finding(card: Dictionary) -> bool:
		return not finding_of(card).is_empty()


	## The card a step whose shape is none of the six is shown as: it says so, keeps a Shape row to repair it
	## with, and holds everything it held. Nothing about it is dropped or rewritten.
	static func unknown_entry(card: Dictionary) -> Dictionary:
		return {
			"kind": str(card.get("kind", "")),
			"category": "",
			"label": EventSheetL10n.translate("Unknown shape"),
			"fields": [shape_row(), finding_row()],
			"badge": Callable(ShapeStepsEditor, "summary_of"),
		}


	## The Shape drop-down every card starts with. A word that is none of the six shows as nothing chosen.
	static func shape_row() -> Dictionary:
		var shape_choices: PackedStringArray = PackedStringArray()
		for named: String in KINDS:
			shape_choices.append("%s=%s" % [named, kind_label(named)])
		return {"key": "kind", "label": "Shape", "drawer": "options:%s" % ",".join(shape_choices), "blank_unknown": true,
			"option_icon": Callable(ShapeStepsEditor, "kind_icon")}


	## The quiet amber line under a card's fields: empty (and taking no room) while the step draws something.
	static func finding_row() -> Dictionary:
		return {"key": "finding", "label": "", "drawer": "note", "text": Callable(ShapeStepsEditor, "finding_of"),
			"warn_when": Callable(ShapeStepsEditor, "has_finding"), "hide_empty": true, "full_width": true}


	## The picture a kind wears where no step exists yet (the Add box, the Shape drop-down): its tile in the editor's text colour.
	static func kind_icon(kind: String, on_light: bool) -> Texture2D:
		# No step yet, so the editor's own text colour: the one picture every place a shape is named draws.
		var colour: Color = EventSheetLookStyle.ink()
		return ImageTexture.create_from_image(load(SHAPE_TILE_PATH).call("shape_image", kind, colour, int(EventSheetLookStyle.px(16.0)), on_light))


	## One shape's fields, in the order the card draws them: where it sits, what it is, what colour it
	## is, and (for a shape with a length to run one along) its dashes.
	static func fields_for(kind: String) -> Array:
		# The card is one surface with no section headings: the shape first (changing it keeps p1, p2 and p3
		# under the new names), the offset as ONE row of x and y, the shape's own named fields with their
		# units as small plain text, the colour, and - on a line only - its look in a fold.
		var fields: Array = [
			shape_row(),
			{"key": "x", "label": "Offset", "drawer": "pair", "pair": "y", "suffix": "px"},
		]
		for field: Variant in SHAPE_FIELDS.get(kind, []):
			fields.append((field as Dictionary).duplicate())
		fields.append({"key": "color", "label": "Colour", "drawer": "color_button"})
		if CAPPED_KINDS.has(kind):
			fields.append({"key": "caps", "label": "End caps", "drawer": "toggle_row:none,square,round:segmented", "fold": LOOK_FOLD})
		if THICKNESS_KINDS.has(kind):
			fields.append({"key": "scale_mode", "label": "Follows scale", "drawer": "tick_words:uniform,fixed", "unset": "uniform",
				"tick_text": "grows with the stamp", "fold": LOOK_FOLD})
		if DASHABLE_KINDS.has(kind):
			fields.append({"key": "dashed", "label": "Dashed", "drawer": "bool", "redraw": true, "fold": LOOK_FOLD})
			fields.append({"key": "dash_size", "label": "Dash", "show_if": "dashed", "link": "dash_spacing", "suffix": "px", "fold": LOOK_FOLD})
			fields.append({"key": "dash_spacing", "label": "Gap", "show_if": "dashed", "link": "dash_size", "suffix": "px", "fold": LOOK_FOLD})
			fields.append({"key": "dash_offset", "label": "Dash offset", "show_if": "dashed", "suffix": EventSheetL10n.translate("dashes"), "fold": LOOK_FOLD})
			fields.append({"key": "dash_style", "label": "Style", "drawer": "toggle_row:plain,angled,rounded:segmented", "show_if": "dashed", "fold": LOOK_FOLD})
		if HELP_LINE_KINDS.has(kind):
			fields.append({"key": "help_note", "label": "", "drawer": "note", "text": Callable(ShapeStepsEditor, "help_line"), "full_width": true})
		fields.append(finding_row())
		return fields


	## The one quiet line a shape says under its fields: what a rectangle is measured from, what a stamp's
	## colour does.
	static func help_line(card: Dictionary) -> String:
		match str(card.get("kind", "")):
			"rect", "rounded_rect":
				return EventSheetL10n.translate("Drawn right and down from the offset.")
			"stamp":
				return EventSheetL10n.translate("The colour tints the texture.")
		return ""


	## Whether a card's Line look fold opens by itself: when any of the look keys it holds is not at the value
	## that draws the plain line. A step without them (everything saved before the look existed) stays shut.
	static func fold_open_for(card: Dictionary, fold_name: String) -> bool:
		if fold_name != LOOK_FOLD:
			return false
		for key: Variant in OPTIONAL_DEFAULTS:
			if card.has(key) and str(card[key]) != str(OPTIONAL_DEFAULTS[key]):
				return true
		return false


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


## The two ways to look at one list of steps - the cards and the table - in one place, so a quiet link under
## the cards can switch THIS Inspector to the table and the table's own link can switch back. Both views hold
## the same list: switching writes nothing, an edit in either is an edit of the list, and the keys the table has
## no column for (a line's ends and dashes) ride through a table edit because the table writes into the very
## row it was handed. Which view an object was left in is remembered for the session only, never in the file.
class ShapeStepsView:
	extends VBoxContainer

	signal value_changed(steps: Array)
	## The view changed: true for the table, false for the cards.
	signal view_switched(table: bool)

	## The columns the table has always had for this list.
	const TABLE_COLUMNS: String = "kind=enum(circle|ring|rect|line|cone|stamp|arc|pie|rounded_rect|regular_polygon),x=float,y=float,p1=float,p2=float,p3=float,color=color,texture=String"

	## The view each object was last left in, by instance id, for as long as the editor runs.
	static var _left_as_table: Dictionary = {}

	var _cards: ShapeStepsEditor = null
	var _table: Control = null
	var _table_on: bool = false
	## Entries of the list that are not Dictionaries, as [original index, value], so a table edit hands them back.
	var _junk: Array = []


	func _init() -> void:
		_cards = ShapeStepsEditor.new()
		_cards.value_changed.connect(func(steps: Array) -> void: value_changed.emit(steps))
		_cards.table_requested.connect(func() -> void: show_table(true))
		add_child(_cards)
		_table = EventSheetDrawerWidgets.DrawerTable.new(EventSheetAttributeDrawers.parse_table_columns(TABLE_COLUMNS))
		_table.open_table = func() -> void: show_table(false)
		_table.open_word = EventSheetL10n.translate("Show as cards")
		_table.open_tip = EventSheetL10n.translate("Shows this list as cards again.")
		_table.connect("value_changed", _on_table_changed)
		_table.visible = false
		add_child(_table)


	static func remember(object_id: int, table: bool) -> void:
		if table:
			_left_as_table[object_id] = true
		else:
			_left_as_table.erase(object_id)


	static func remembered(object_id: int) -> bool:
		return bool(_left_as_table.get(object_id, false))


	func cards() -> ShapeStepsEditor:
		return _cards


	func table() -> Control:
		return _table


	func table_shown() -> bool:
		return _table_on


	## Shows the table or the cards. The list is handed across as it is; nothing is announced and nothing is written.
	func show_table(table: bool) -> void:
		if table == _table_on:
			return
		var steps: Array = get_steps()
		_table_on = table
		if table:
			_table.call("set_value", steps)
		else:
			_cards.set_steps(steps)
		_cards.visible = not table
		_table.visible = table
		view_switched.emit(table)


	func set_steps(steps: Array) -> void:
		_junk = []
		for position: int in range(steps.size()):
			if not (steps[position] is Dictionary):
				_junk.append([position, steps[position]])
		_cards.set_steps(steps)
		_table.call("set_value", steps)


	func get_steps() -> Array:
		if not _table_on:
			return _cards.get_steps()
		var rows: Array = _table.call("get_value")
		for kept: Variant in _junk:
			rows.insert(mini(int((kept as Array)[0]), rows.size()), (kept as Array)[1])
		return rows


	func set_editable(editable: bool) -> void:
		_cards.set_editable(editable)
		_table.set("editable", editable)
		_table.call("_rebuild")


	func _on_table_changed(_rows: Array) -> void:
		value_changed.emit(get_steps())
