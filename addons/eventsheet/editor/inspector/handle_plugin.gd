# Godot EventSheets - viewport handles for any script that declares them (editor-only).
#
# A node whose script carries `# @inspector_handle <property> <kind> [from <anchor>]` lines shows a
# draggable mark per handle while it is selected, the way the engine's own collision shapes do: a
# filled dot for a point, a hollow dot for a length, a diamond for an angle, and one dot per entry
# for a list of points. Dragging writes the property; letting go of the mouse writes ONE undo step.
#
# 2D rides the editor plugin's canvas forwarding, 3D an EditorNode3DGizmoPlugin (loaded by path in
# handle_gizmo_3d.gd, so this file never names an editor-only class). The forwarding is the FORCE
# variant plus always-on input forwarding, because the plugin that owns it also owns a main editor
# screen: a plugin whose _handles() claims scene nodes makes Godot switch workspaces the moment one
# is selected, which is the same reason the behaviour gizmos ride selection instead. Force
# forwarding is independent of _handles, so the 2D editor is left exactly as its user left it.
#
# Everything the drag computes is a pure static below (anchor, mark position, dragged value,
# snapping, the undo pair), so the maths is pinned headless and the editor code above it only moves
# a mouse into those functions.
@tool
class_name EventSheetInspectorHandlePlugin
extends RefCounted

const GIZMO_3D_PATH: String = "res://addons/eventsheet/editor/inspector/handle_gizmo_3d.gd"

## The angle mark sits this far (node-local units) from its anchor - far enough to grab, near enough
## to stay in view on a small shape. The angle a drag reads is the direction, never this distance.
const ANGLE_ARM: float = 48.0
## Godot's own Configure Snap defaults: an 8 unit grid and a 15 degree rotation step. The 2D editor
## keeps the step a user configures in that scene's editor state, which no public API reads back, so
## a drag snaps to the editor's DEFAULTS while the snap modifier is held rather than pretending to
## know a number it cannot see.
const GRID_STEP: float = 8.0
const ROTATION_STEP_DEG: float = 15.0

var _plugin: EditorPlugin = null
var _editor_interface: EditorInterface = null
var _gizmo_3d: EditorNode3DGizmoPlugin = null
var _target: Node2D = null
var _handles: Array = []
# The live drag: which handle, which list entry (points only), and the value the property held when
# the mouse went down - the undo half of the one step a drag writes.
var _drag_index: int = -1
var _drag_point_index: int = 0
var _drag_before: Variant = null


## Wires the handles to the editor plugin that owns them: selection drives what is drawn, the
## plugin's canvas forwarding drives the drawing and the dragging, and the 3D gizmo covers Node3D.
## A null plugin (a headless test, a non-editor context) is a safe no-op.
func init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	if _plugin == null:
		return
	_editor_interface = _plugin.get_editor_interface()
	if _editor_interface != null:
		var selection: EditorSelection = _editor_interface.get_selection()
		if selection != null and not selection.selection_changed.is_connected(_on_selection_changed):
			selection.selection_changed.connect(_on_selection_changed)
	_plugin.set_input_event_forwarding_always_enabled()
	_plugin.set_force_draw_over_forwarding_enabled()
	var gizmo_script: Script = load(GIZMO_3D_PATH) as Script
	if gizmo_script != null and gizmo_script.can_instantiate():
		_gizmo_3d = gizmo_script.new()
		# The gizmo commits its own drags, so it needs the same undo manager this seam uses - without
		# it a 3D drag would move the property and leave no step to undo.
		_gizmo_3d.set("undo_redo", _plugin.get_undo_redo())
		_plugin.add_node_3d_gizmo_plugin(_gizmo_3d)
	_on_selection_changed()


## Drops the gizmo and the selection connection - a disabled plugin leaves the editor as it found it.
func teardown() -> void:
	if _plugin != null and _gizmo_3d != null:
		_plugin.remove_node_3d_gizmo_plugin(_gizmo_3d)
	_gizmo_3d = null
	if _editor_interface != null:
		var selection: EditorSelection = _editor_interface.get_selection()
		if selection != null and selection.selection_changed.is_connected(_on_selection_changed):
			selection.selection_changed.disconnect(_on_selection_changed)
	_editor_interface = null
	_plugin = null
	_target = null
	_handles = []


## The selected Node2D whose script declares handles, or nothing - one node at a time, so a
## multi-selection drags nothing by accident.
func _on_selection_changed() -> void:
	_target = null
	_handles = []
	_drag_index = -1
	if _editor_interface == null:
		return
	var selected: Array[Node] = _editor_interface.get_selection().get_selected_nodes()
	if selected.size() != 1:
		return
	var node: Node2D = selected[0] as Node2D
	if node == null:
		return
	var declared: Array = EventSheetInspectorObjectDecor.handles_for(node)
	if declared.is_empty():
		return
	_target = node
	_handles = declared
	if _plugin != null:
		_plugin.update_overlays()


## The 2D editor's overlay, in viewport space: one mark per handle, with a hairline back to the
## anchor it is measured from.
func draw_over_viewport(overlay: Control) -> void:
	if overlay == null or _target == null or not is_instance_valid(_target):
		return
	var to_screen: Transform2D = _target.get_viewport_transform() * _target.get_global_transform()
	var accent: Color = Color(0.36, 0.66, 1.0)
	for index: int in range(_handles.size()):
		var handle: Dictionary = _handles[index]
		var anchor_screen: Vector2 = to_screen * anchor_of(_target, handle)
		for mark: Dictionary in marks_of(_target, handle):
			var at: Vector2 = to_screen * (mark.get("local") as Vector2)
			overlay.draw_line(anchor_screen, at, Color(accent.r, accent.g, accent.b, 0.45), 1.0, true)
			_draw_mark(overlay, at, str(handle.get("kind", "")), accent, index == _drag_index)


## One handle mark: filled for a point, hollow for a length, a diamond for an angle.
func _draw_mark(overlay: Control, at: Vector2, kind: String, accent: Color, active: bool) -> void:
	var radius: float = float(EventSheetPalette.scaled(6 if active else 5))
	var ink: Color = Color(1.0, 0.85, 0.4) if active else accent
	match kind:
		"length":
			overlay.draw_arc(at, radius, 0.0, TAU, 20, ink, 2.0, true)
		"angle":
			var diamond: PackedVector2Array = PackedVector2Array([
				at + Vector2(0.0, -radius), at + Vector2(radius, 0.0),
				at + Vector2(0.0, radius), at + Vector2(-radius, 0.0)])
			overlay.draw_colored_polygon(diamond, ink)
		_:
			overlay.draw_circle(at, radius, ink)
			overlay.draw_arc(at, radius, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 1.0, true)


## The 2D editor's input: press a mark to start a drag, move to write the property live, release to
## write the one undo step. Returns false for everything else, so the 2D editor keeps every gesture
## this seam did not claim.
func canvas_gui_input(event: InputEvent) -> bool:
	if _target == null or not is_instance_valid(_target) or _handles.is_empty():
		return false
	var to_screen: Transform2D = _target.get_viewport_transform() * _target.get_global_transform()
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button.pressed:
			return _begin_drag(button.position, to_screen)
		if _drag_index >= 0:
			_end_drag()
			return true
		return false
	if event is InputEventMouseMotion and _drag_index >= 0:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_drag(to_screen.affine_inverse() * motion.position, motion.ctrl_pressed)
		return true
	return false


## Grabs the mark under the cursor, remembering the value the property holds right now.
func _begin_drag(screen_point: Vector2, to_screen: Transform2D) -> bool:
	var grab: float = float(EventSheetPalette.scaled(10))
	for index: int in range(_handles.size()):
		var handle: Dictionary = _handles[index]
		for mark: Dictionary in marks_of(_target, handle):
			if (to_screen * (mark.get("local") as Vector2)).distance_to(screen_point) > grab:
				continue
			_drag_index = index
			_drag_point_index = int(mark.get("index", 0))
			_drag_before = _target.get(str(handle.get("property", "")))
			return true
	return false


## Writes the dragged value onto the node as the mouse moves - no undo entry yet, so a whole drag
## stays one step.
func _apply_drag(local_point: Vector2, snapping: bool) -> void:
	var handle: Dictionary = _handles[_drag_index]
	var property: String = str(handle.get("property", ""))
	var value: Variant = value_from_point(str(handle.get("kind", "")), anchor_of(_target, handle), local_point, snapping)
	if str(handle.get("kind", "")) == "points":
		value = replaced_point(_target.get(property), _drag_point_index, value as Vector2)
	_target.set(property, matched_type(_target.get(property), value))
	if _plugin != null:
		_plugin.update_overlays()


## Ends the drag with the one undo step it earned (and none at all when nothing actually moved).
func _end_drag() -> void:
	var handle: Dictionary = _handles[_drag_index]
	var property: String = str(handle.get("property", ""))
	if _plugin != null:
		commit_drag(_plugin.get_undo_redo(), _target, property, _drag_before, _target.get(property))
	_drag_index = -1
	_drag_before = null

# ── The maths, pure: every value a drag produces comes from one of these ──


## The point a handle is measured from: the property named by `from`, or the node's own origin.
static func anchor_of(node: Object, handle: Dictionary) -> Vector2:
	var anchor_property: String = str(handle.get("from", ""))
	if node == null or anchor_property.is_empty():
		return Vector2.ZERO
	var value: Variant = node.get(anchor_property)
	return value if value is Vector2 else Vector2.ZERO


## Where a handle's marks sit in node-local space: one for a point, a length or an angle, and one
## per entry for a list of points. Each mark is {"local": Vector2, "index": int}.
static func marks_of(node: Object, handle: Dictionary) -> Array:
	if node == null:
		return []
	var anchor: Vector2 = anchor_of(node, handle)
	var value: Variant = node.get(str(handle.get("property", "")))
	match str(handle.get("kind", "")):
		"point":
			return [{"local": anchor + (value if value is Vector2 else Vector2.ZERO), "index": 0}]
		"length":
			return [{"local": anchor + Vector2(float(value if value is float or value is int else 0.0), 0.0), "index": 0}]
		"angle":
			var degrees: float = float(value if value is float or value is int else 0.0)
			return [{"local": anchor + Vector2(ANGLE_ARM, 0.0).rotated(deg_to_rad(degrees)), "index": 0}]
		"points":
			var marks: Array = []
			var entries: Array = point_list(value)
			for index: int in range(entries.size()):
				marks.append({"local": anchor + (entries[index] as Vector2), "index": index})
			return marks
	return []


## What the dragged property becomes when the cursor is at `local_point`: a point is an offset from
## the anchor, a length is the distance to it, an angle is the direction in degrees (0 to 360).
## Snapping is the editor's own grid step, and its rotation step for an angle.
static func value_from_point(kind: String, anchor: Vector2, local_point: Vector2, snapping: bool) -> Variant:
	var offset: Vector2 = local_point - anchor
	match kind:
		"point", "points":
			return snapped_point(offset, snapping)
		"length":
			var length: float = offset.length()
			return snappedf(length, GRID_STEP) if snapping else length
		"angle":
			var degrees: float = fposmod(rad_to_deg(offset.angle()), 360.0)
			return fposmod(snappedf(degrees, ROTATION_STEP_DEG), 360.0) if snapping else degrees
	return offset


## A dragged value in the type the property already holds. A length in whole pixels or an angle in
## whole degrees is an `int` member, and a typed `int` member REFUSES a float through `set` - so
## without this the mark moves under the cursor and the property never changes.
static func matched_type(existing: Variant, value: Variant) -> Variant:
	if existing is int and value is float:
		return int(round(float(value)))
	return value


## A point on the editor's grid while the snap modifier is held, and exactly where the cursor is
## otherwise.
static func snapped_point(offset: Vector2, snapping: bool) -> Vector2:
	return offset.snapped(Vector2(GRID_STEP, GRID_STEP)) if snapping else offset


## A list-of-points property as an Array of Vector2, whichever way the script typed it.
static func point_list(value: Variant) -> Array:
	var points: Array = []
	if value is PackedVector2Array:
		for point: Vector2 in (value as PackedVector2Array):
			points.append(point)
	elif value is Array:
		for entry: Variant in (value as Array):
			if entry is Vector2:
				points.append(entry)
	return points


## The same list with one entry moved, keeping the property's own container type - a
## PackedVector2Array stays packed, a plain Array stays plain.
static func replaced_point(value: Variant, index: int, point: Vector2) -> Variant:
	var points: Array = point_list(value)
	if index < 0 or index >= points.size():
		return value
	points[index] = point
	if value is PackedVector2Array:
		var packed: PackedVector2Array = PackedVector2Array()
		for entry: Variant in points:
			packed.append(entry as Vector2)
		return packed
	return points


## The one undo step a finished drag writes. Takes the undo manager duck-typed (the editor's
## EditorUndoRedoManager in the editor, a plain UndoRedo in the suite) so the step count is pinned
## headless. A drag that ended where it started writes nothing at all.
static func commit_drag(undo_redo: Object, node: Object, property: String, before: Variant, after: Variant) -> bool:
	if undo_redo == null or node == null or property.is_empty() or before == after:
		return false
	undo_redo.call("create_action", "Drag %s" % property)
	undo_redo.call("add_do_property", node, property, after)
	undo_redo.call("add_undo_property", node, property, before)
	undo_redo.call("commit_action")
	return true
