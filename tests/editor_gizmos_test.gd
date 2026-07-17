# EventForge - behavior editor gizmos (the "behaviors draw their setup in the editor" seam):
# a behavior ships `static func editor_gizmo_draw(params, host, canvas)` on its emitted script
# (or registers a drawer via EventSheets.register_editor_gizmo) and, while its node is
# selected, a transient owner-less canvas child of the host repaints it live. Pins: target
# resolution (host-selected scans children; behavior-selected resolves its parent; opt-in
# only), registered-drawer precedence, live param capture (exported knobs AND internal state),
# and the shipped Bound To gizmo static surviving pack emission.
@tool
class_name EditorGizmosTest
extends RefCounted

const GIZMOS_PATH := "res://addons/eventsheet/editor/behavior_gizmos.gd"
const BOUND_TO_PATH := "res://eventsheet_addons/bound_to/bound_to_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var gizmos: Script = load(GIZMOS_PATH)

	# ---- target resolution: selecting the HOST scans children, opt-in only ----
	var host: Node2D = Node2D.new()
	var behavior: Node = Node.new()
	behavior.set_script(load(BOUND_TO_PATH))
	var plain: Node = Node.new()
	host.add_child(behavior)
	host.add_child(plain)
	var target: Dictionary = gizmos.call("gizmo_target_for", host)
	all_passed = _check("host-selected resolves the host", target.get("host") == host, true) and all_passed
	all_passed = _check("only the opted-in child gets an entry", (target.get("entries") as Array).size(), 1) and all_passed

	# ---- selecting the BEHAVIOR itself resolves its parent as the host ----
	var from_behavior: Dictionary = gizmos.call("gizmo_target_for", behavior)
	all_passed = _check("behavior-selected resolves its parent host", from_behavior.get("host") == host, true) and all_passed
	all_passed = _check("behavior-selected carries its own entry", (from_behavior.get("entries") as Array).size(), 1) and all_passed

	# ---- a plain node with no gizmo behaviors resolves to no entries ----
	var bare: Node2D = Node2D.new()
	var none: Dictionary = gizmos.call("gizmo_target_for", bare)
	all_passed = _check("no opted-in behaviors means no entries", (none.get("entries") as Array).is_empty(), true) and all_passed
	bare.free()

	# ---- a registered drawer opts a script-less-static behavior in, and takes priority ----
	var drawn: Array = []
	var drawer: Callable = func(_params: Dictionary, _host: Node2D, _canvas: CanvasItem) -> void: drawn.append(true)
	EventSheets.register_editor_gizmo(BOUND_TO_PATH, drawer)
	var with_drawer: Dictionary = gizmos.call("gizmo_target_for", behavior)
	var entry: Dictionary = (with_drawer.get("entries") as Array)[0]
	all_passed = _check("a registered drawer wins over the static", (entry.get("drawer") as Callable).is_valid(), true) and all_passed
	EventSheets.register_editor_gizmo(BOUND_TO_PATH, Callable())

	# ---- live params: exported knobs AND internal state travel to the drawer ----
	behavior.set("half_width", 24.0)
	behavior.set("custom_bounds", Rect2(1.0, 2.0, 3.0, 4.0))
	var canvas_script: Script = load("res://addons/eventsheet/editor/behavior_gizmo_canvas.gd")
	var params: Dictionary = canvas_script.call("live_params", behavior)
	all_passed = _check("exported knobs read live", float(params.get("half_width", 0.0)), 24.0) and all_passed
	all_passed = _check("internal state (custom_bounds) travels too", params.get("custom_bounds"), Rect2(1.0, 2.0, 3.0, 4.0)) and all_passed
	host.free()

	# ---- the shipped demo: Bound To's gizmo static survives pack emission ----
	var emitted: String = FileAccess.get_file_as_string(BOUND_TO_PATH)
	all_passed = _check("Bound To ships the gizmo static",
		emitted.contains("static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void:"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] editor_gizmos_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
