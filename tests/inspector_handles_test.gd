# Godot EventSheets - the preview card any object can ask for, and the viewport handle seam.
#
# Two pieces of Inspector chrome, pinned by VALUE:
#   * `# @inspector_preview` and `# @inspector_handle <property> <kind> [from <property>]` - object
#     decor, plain `#` comments that emit nothing at all, so a project without the plugin ships the
#     same bytes and runs the same code;
#   * the maths a drag does: where each mark sits, what the property becomes when the cursor is at a
#     point, what the editor's grid rounds that to, and the ONE undo step a finished drag writes.
#
# The decor is refused rather than guessed at whenever a line is not exactly the grammar - a
# mistyped handle draws nothing instead of dragging the wrong property.
@tool
class_name InspectorHandlesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P: String = "inspector_handles_test"
const PROVIDER_PATH: String = "user://eventsheets_preview_provider.gd"

## A pack's script as an author writes it: the card, three handles, and a line for each refusal.
const FIXTURE_SOURCE: String = """@tool
extends Node2D

# @inspector_preview
# @inspector_handle end point
# @inspector_handle radius length from origin
# @inspector_handle start_angle angle from origin

@export var end: Vector2 = Vector2(64.0, 0.0)
@export var radius: float = 32.0
@export var start_angle: float = 0.0
"""


static func run() -> bool:
	var ok: bool = true
	ok = _decor_parser() and ok
	ok = _handle_maths() and ok
	ok = _undo_step() and ok
	ok = _preview_card() and ok
	ok = _typed_writes() and ok
	ok = _preview_notices_quiet_edits() and ok
	return ok


# ── The decor, by value ─────────────────────────────────────────────────────
static func _decor_parser() -> bool:
	var decor: Dictionary = EventSheetInspectorObjectDecor.parse(FIXTURE_SOURCE)
	var ok: bool = SUPPORT.pins(P, [
		["the script asks for the preview card", decor.get("preview", false), true],
		["three handles, in the order they are declared", decor.get("handles", []), [
			{"property": "end", "kind": "point", "from": ""},
			{"property": "radius", "kind": "length", "from": "origin"},
			{"property": "start_angle", "kind": "angle", "from": "origin"}]],
		["a script with no decor asks for nothing",
			EventSheetInspectorObjectDecor.parse("extends Node2D\n\n@export var radius: float = 1.0\n"),
			{"preview": false, "handles": []}]
	])

	# One line at a time: the grammar, and every way of missing it.
	ok = SUPPORT.pins(P, [
		["a bare point handle", EventSheetInspectorObjectDecor.parse_handle_line("end point"),
			{"property": "end", "kind": "point", "from": ""}],
		["a length measured from another property",
			EventSheetInspectorObjectDecor.parse_handle_line("radius length from origin"),
			{"property": "radius", "kind": "length", "from": "origin"}],
		["a list of points", EventSheetInspectorObjectDecor.parse_handle_line("path points"),
			{"property": "path", "kind": "points", "from": ""}],
		["an unknown kind is refused", EventSheetInspectorObjectDecor.parse_handle_line("end blob"), {}],
		["a property that is not an identifier is refused",
			EventSheetInspectorObjectDecor.parse_handle_line("not-a-name point"), {}],
		["an anchor that is not an identifier is refused",
			EventSheetInspectorObjectDecor.parse_handle_line("radius length from 12"), {}],
		["a kind with no property is refused", EventSheetInspectorObjectDecor.parse_handle_line("point"), {}],
		["a word that is not `from` is refused",
			EventSheetInspectorObjectDecor.parse_handle_line("start_angle angle around origin"), {}],
		["trailing words are refused rather than ignored",
			EventSheetInspectorObjectDecor.parse_handle_line("end point please"), {}]
	]) and ok

	# A doc comment is the hover tooltip, never decor - the same rule the property decor follows.
	ok = SUPPORT.pins(P, [
		["a `##` line is a tooltip, not decor",
			EventSheetInspectorObjectDecor.parse("extends Node2D\n## @inspector_handle end point\n"),
			{"preview": false, "handles": []}],
		["and neither is a mention inside a sentence",
			EventSheetInspectorObjectDecor.parse("extends Node2D\n# see # @inspector_preview\n").get("preview", false),
			false]
	]) and ok

	# The chips: what an author reads before opening a scene.
	ok = SUPPORT.pins(P, [
		["a point chip", EventSheetInspectorObjectDecor.chip_text({"property": "end", "kind": "point", "from": ""}), "end ●"],
		["a length chip names its anchor",
			EventSheetInspectorObjectDecor.chip_text({"property": "radius", "kind": "length", "from": "origin"}),
			"radius ○ from origin"],
		["an angle chip", EventSheetInspectorObjectDecor.chip_text({"property": "spin", "kind": "angle", "from": ""}), "spin ◇"],
		["a list chip", EventSheetInspectorObjectDecor.chip_text({"property": "path", "kind": "points", "from": ""}), "path ●●"],
		["the whole declaration as chips",
			EventSheetInspectorObjectDecor.chips(EventSheetInspectorObjectDecor.parse(FIXTURE_SOURCE).get("handles", [])),
			PackedStringArray(["end ●", "radius ○ from origin", "start_angle ◇ from origin"])]
	]) and ok

	# The Inspector Designer reads the same lines off the file the sheet opens from, because a decor
	# comment belongs to no row and so cannot be read off one.
	var source_path: String = "user://eventsheets_handles_designer.gd"
	var file: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
	file.store_string(FIXTURE_SOURCE)
	file.close()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = source_path
	var plain: EventSheetResource = EventSheetResource.new()
	ok = SUPPORT.pins(P, [
		["the Designer chips the handles the sheet's own file declares",
			EventSheetInspectorDesignerDialog.declared_handle_chips(sheet),
			PackedStringArray(["end ●", "radius ○ from origin", "start_angle ◇ from origin"])],
		["a sheet that is not backed by a file chips nothing",
			EventSheetInspectorDesignerDialog.declared_handle_chips(plain), PackedStringArray()],
		["and neither does no sheet at all",
			EventSheetInspectorDesignerDialog.declared_handle_chips(null), PackedStringArray()]
	]) and ok
	DirAccess.remove_absolute(source_path)
	return ok


# ── Where a mark sits, and what dragging it writes ──────────────────────────
static func _handle_maths() -> bool:
	var node: Node2D = Node2D.new()
	node.set_script(_fixture_script())
	node.set("origin", Vector2(10.0, 4.0))
	node.set("end", Vector2(64.0, 0.0))
	node.set("radius", 32.0)
	node.set("start_angle", 90.0)
	node.set("path", PackedVector2Array([Vector2(1.0, 2.0), Vector2(3.0, 4.0)]))
	var point_handle: Dictionary = {"property": "end", "kind": "point", "from": ""}
	var length_handle: Dictionary = {"property": "radius", "kind": "length", "from": "origin"}
	var angle_handle: Dictionary = {"property": "start_angle", "kind": "angle", "from": "origin"}
	var points_handle: Dictionary = {"property": "path", "kind": "points", "from": "origin"}
	var ok: bool = SUPPORT.pins(P, [
		["no anchor is the node's own origin",
			EventSheetInspectorHandlePlugin.anchor_of(node, point_handle), Vector2.ZERO],
		["an anchor property is read off the node",
			EventSheetInspectorHandlePlugin.anchor_of(node, length_handle), Vector2(10.0, 4.0)],
		["a missing anchor property is the origin, not a crash",
			EventSheetInspectorHandlePlugin.anchor_of(node, {"property": "end", "kind": "point", "from": "nowhere"}),
			Vector2.ZERO],
		["a point mark sits on the point",
			EventSheetInspectorHandlePlugin.marks_of(node, point_handle), [{"local": Vector2(64.0, 0.0), "index": 0}]],
		["a length mark sits that far along from its anchor",
			EventSheetInspectorHandlePlugin.marks_of(node, length_handle), [{"local": Vector2(42.0, 4.0), "index": 0}]],
		["an angle mark rides an arm at the angle it holds",
			_rounded_vector((EventSheetInspectorHandlePlugin.marks_of(node, angle_handle)[0] as Dictionary).get("local")),
			Vector2(10.0, 4.0 + EventSheetInspectorHandlePlugin.ANGLE_ARM)],
		["a list of points is one mark each, numbered",
			EventSheetInspectorHandlePlugin.marks_of(node, points_handle),
			[{"local": Vector2(11.0, 6.0), "index": 0}, {"local": Vector2(13.0, 8.0), "index": 1}]]
	])

	# The drag itself: cursor in node-local space -> the value the property takes.
	ok = SUPPORT.pins(P, [
		["a point is the offset from its anchor",
			EventSheetInspectorHandlePlugin.value_from_point("point", Vector2(10.0, 4.0), Vector2(30.0, 24.0), false),
			Vector2(20.0, 20.0)],
		["a length is the distance to its anchor",
			EventSheetInspectorHandlePlugin.value_from_point("length", Vector2(10.0, 4.0), Vector2(13.0, 8.0), false), 5.0],
		["an angle is the direction, in degrees",
			_rounded(EventSheetInspectorHandlePlugin.value_from_point("angle", Vector2.ZERO, Vector2(0.0, 10.0), false)), 90.0],
		["an angle behind the anchor wraps rather than going negative",
			_rounded(EventSheetInspectorHandlePlugin.value_from_point("angle", Vector2.ZERO, Vector2(0.0, -10.0), false)), 270.0],
		["snapping puts a point on the editor's grid",
			EventSheetInspectorHandlePlugin.value_from_point("point", Vector2.ZERO, Vector2(19.0, 13.0), true),
			Vector2(16.0, 16.0)],
		["snapping rounds a length to the same grid",
			EventSheetInspectorHandlePlugin.value_from_point("length", Vector2.ZERO, Vector2(19.0, 0.0), true), 16.0],
		["snapping rounds an angle to the editor's rotation step",
			_rounded(EventSheetInspectorHandlePlugin.value_from_point("angle", Vector2.ZERO, Vector2(10.0, 1.0), true)), 0.0],
		["the grid is the editor's own default", EventSheetInspectorHandlePlugin.GRID_STEP, 8.0],
		["and so is the rotation step", EventSheetInspectorHandlePlugin.ROTATION_STEP_DEG, 15.0]
	]) and ok

	# Moving one entry of a list keeps the property's own container type.
	var packed: PackedVector2Array = PackedVector2Array([Vector2(1.0, 2.0), Vector2(3.0, 4.0)])
	var moved: Variant = EventSheetInspectorHandlePlugin.replaced_point(packed, 1, Vector2(9.0, 9.0))
	ok = SUPPORT.pins(P, [
		["the moved entry took the new place", moved, PackedVector2Array([Vector2(1.0, 2.0), Vector2(9.0, 9.0)])],
		["a packed array stays packed", moved is PackedVector2Array, true],
		["a plain array stays plain",
			EventSheetInspectorHandlePlugin.replaced_point([Vector2(1.0, 2.0)], 0, Vector2(5.0, 5.0)) is Array, true],
		["an entry that is not there leaves the list alone",
			EventSheetInspectorHandlePlugin.replaced_point(packed, 7, Vector2(9.0, 9.0)), packed]
	]) and ok
	node.free()
	return ok


# ── One drag, one undo step ─────────────────────────────────────────────────
static func _undo_step() -> bool:
	var node: Node2D = Node2D.new()
	node.set_script(_fixture_script())
	node.set("radius", 32.0)
	var undo: UndoRedo = UndoRedo.new()
	var wrote: bool = EventSheetInspectorHandlePlugin.commit_drag(undo, node, "radius", 32.0, 48.0)
	var after_commit: Variant = node.get("radius")
	undo.undo()
	var after_undo: Variant = node.get("radius")
	undo.redo()
	var ok: bool = SUPPORT.pins(P, [
		["a finished drag writes one step", undo.get_history_count(), 1],
		["and says so", wrote, true],
		["the step is named for the property it moved", undo.get_current_action_name(), "Drag radius"],
		["committing wrote the dragged value", after_commit, 48.0],
		["one undo puts the property back where it started", after_undo, 32.0],
		["redo brings the drag back", node.get("radius"), 48.0]
	])

	# A drag that ended where it started is not an edit, so it is not a step either.
	var still: UndoRedo = UndoRedo.new()
	ok = SUPPORT.pins(P, [
		["a drag that moved nothing writes no step",
			EventSheetInspectorHandlePlugin.commit_drag(still, node, "radius", 48.0, 48.0), false],
		["so the history stays empty", still.get_history_count(), 0],
		["and neither does a drag with no undo manager",
			EventSheetInspectorHandlePlugin.commit_drag(null, node, "radius", 1.0, 2.0), false]
	]) and ok
	# UndoRedo is an Object, not a RefCounted: a run that only drops the reference leaks it, and the
	# leak is counted at exit against every other test in the same process.
	undo.clear_history()
	undo.free()
	still.free()
	node.free()
	return ok


# ── The preview card, and where its picture comes from ──────────────────────
static func _preview_card() -> bool:
	var prefab: DrawingPrefabResource = DrawingPrefabResource.new()
	prefab.steps = [{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 12.0, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""}]
	var node: Node2D = Node2D.new()
	var plain: Resource = Resource.new()
	var ok: bool = SUPPORT.pins(P, [
		["a renderer handed in wins",
			EventSheetInspectorPreviewPanel.source_of(prefab, EventSheetDrawingPrefabInspector.rasterize_prefab), "given"],
		["a node with nothing registered draws itself in a viewport",
			EventSheetInspectorPreviewPanel.source_of(node), "viewport"],
		["a resource nothing can draw shows the empty card",
			EventSheetInspectorPreviewPanel.source_of(plain), "none"],
		["and so does no object at all", EventSheetInspectorPreviewPanel.source_of(null), "none"]
	])

	# A pack that cannot ship a renderer registers one for its script path, and it outranks the
	# object's own method.
	var provider: Object = _write_provider()
	if provider != null:
		EventSheets.register_inspector_preview(PROVIDER_PATH, _flat_texture)
		ok = SUPPORT.pins(P, [
			["a registered renderer is used", EventSheetInspectorPreviewPanel.source_of(provider), "registered"],
			["it outranks the object's own method",
				EventSheetInspectorPreviewPanel.render_texture(provider, Vector2i(8, 4)).get_size(), Vector2(8.0, 4.0)]
		]) and ok
		EventSheets.unregister_inspector_preview(PROVIDER_PATH)
		ok = SUPPORT.pins(P, [
			["unregistering hands the object back its own method",
				EventSheetInspectorPreviewPanel.source_of(provider), "object"],
			["which draws the picture instead",
				EventSheetInspectorPreviewPanel.render_texture(provider, Vector2i(6, 6)).get_size(), Vector2(6.0, 6.0)]
		]) and ok

	# The drawing prefab's card: the same shared card, drawing exactly the picture it always drew.
	var card: EventSheetInspectorPreviewPanel = EventSheetInspectorPreviewPanel.new(prefab, EventSheetDrawingPrefabInspector.rasterize_prefab)
	card.refresh()
	var drawn: Texture2D = card.preview_texture()
	ok = SUPPORT.pins(P, [
		["the prefab card is drawn by the prefab's own rasterizer", drawn != null, true],
		["at the size the card has always asked for",
			drawn.get_size() if drawn != null else Vector2.ZERO, Vector2(EventSheetInspectorPreviewPanel.RASTER_SIZE)],
		["the card keeps its shipped height",
			card.custom_minimum_size, Vector2(0.0, float(EventSheetInspectorPreviewPanel.CARD_HEIGHT))]
	]) and ok
	card.free()
	node.free()
	DirAccess.remove_absolute(PROVIDER_PATH)
	return ok


## A resource whose script lives on disk (so it has a resource_path a renderer can be registered
## against) and which also draws itself - the two sources, on one object, to pin their order.
static func _write_provider() -> Object:
	var file: FileAccess = FileAccess.open(PROVIDER_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string("@tool\nextends Resource\n\n\nfunc inspector_preview_texture(size: Vector2i) -> Texture2D:\n\treturn ImageTexture.create_from_image(Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8))\n")
	file.close()
	var script: GDScript = load(PROVIDER_PATH) as GDScript
	return script.new() if script != null and script.can_instantiate() else null


## The registered renderer's picture: a flat image at the asked-for size, so the pin is its size.
static func _flat_texture(_object: Object, size: Vector2i) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8))


## A trigonometric answer read to three decimals: 90 degrees is 90, not 89.99999999999999. Pins are
## still VALUES - this only spells how many of a float's digits the pin is about.
## A dragged value in the type the property already holds: a length or an angle stored as a whole
## number is written as one, because a typed int member refuses a float through `set` and the mark
## would otherwise move under the cursor while the property stayed where it was.
static func _typed_writes() -> bool:
	return SUPPORT.pins(P, [
		["a whole-number property is written a whole number",
			EventSheetInspectorHandlePlugin.matched_type(3, 12.7), 13],
		["a number property is written the number itself",
			EventSheetInspectorHandlePlugin.matched_type(2.5, 12.7), 12.7],
		["a point is written as the point it is",
			EventSheetInspectorHandlePlugin.matched_type(Vector2.ZERO, Vector2(1.0, 2.0)), Vector2(1.0, 2.0)],
		["a property the node does not hold is written as it came",
			EventSheetInspectorHandlePlugin.matched_type(null, 4.0), 4.0]
	])


## The preview card watches the object it draws: a plain `@export` write announces nothing, so the
## card compares the object's stored values instead of waiting for a signal that never comes.
static func _preview_notices_quiet_edits() -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = "extends Resource\n\n\n@export var width: float = 4.0\n@export var height: float = 2.0\n"
	script.reload()
	var subject: Resource = script.new()
	var before: int = EventSheetInspectorPreviewPanel.state_hash(subject)
	var unchanged: int = EventSheetInspectorPreviewPanel.state_hash(subject)
	subject.set("width", 9.0)
	var after: int = EventSheetInspectorPreviewPanel.state_hash(subject)
	return SUPPORT.pins(P, [
		["the same values read the same", unchanged, before],
		["an edit nothing announced still reads as a change", after != before, true],
		["nothing to draw reads as nothing", EventSheetInspectorPreviewPanel.state_hash(null), 0]
	])


static func _rounded(value: Variant) -> float:
	return roundf(float(value) * 1000.0) / 1000.0


static func _rounded_vector(value: Variant) -> Vector2:
	var point: Vector2 = value if value is Vector2 else Vector2.ZERO
	return Vector2(_rounded(point.x), _rounded(point.y))


## The fixture node's script: the properties the handles name, as a pack would export them.
static func _fixture_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Node2D\n\n\n@export var origin: Vector2 = Vector2.ZERO\n@export var end: Vector2 = Vector2.ZERO\n@export var radius: float = 0.0\n@export var start_angle: float = 0.0\n@export var path: PackedVector2Array = PackedVector2Array()\n"
	script.reload()
	return script
