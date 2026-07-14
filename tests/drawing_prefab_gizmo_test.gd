# EventForge - DrawingPrefabResource preview gizmos (2D + 3D)
#
# Guards the selection-driven preview lifecycle of drawing_prefab_gizmo.gd and drawing_prefab_3d_gizmo.gd:
# select any node that references a DrawingPrefabResource and it previews - a transient DrawingPrefabStamp
# at the host in 2D, a camera-facing Sprite3D billboard in 3D - never serializing (owner == null). The
# actual vector rendering is proven separately (drawing_prefab_stamp + the software rasterizer); this pins
# the glue: detection (find a referenced prefab, by value's script path, on any node), the self-drawing
# skip list, and the build/clear lifecycle.
@tool
class_name DrawingPrefabGizmoTest
extends RefCounted

const STAMP_PATH: String = "res://eventsheet_addons/drawing_prefab_stamp/drawing_prefab_stamp.gd"
const PREFAB_PATH: String = "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd"


static func run() -> bool:
	var all_passed: bool = true

	var prefab: Resource = load(PREFAB_PATH).new()
	prefab.set("steps", [{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 8.0, "color": "white"}])

	# A node that REFERENCES a prefab through an exported property (the generic case: any node, any
	# property name). Compiled at runtime so the test owns no fixture script.
	var ref_src: GDScript = GDScript.new()
	ref_src.source_code = "extends Node2D\n@export var marker: DrawingPrefabResource"
	ref_src.reload()
	var ref_node: Node2D = Node2D.new()
	ref_node.set_script(ref_src)
	ref_node.set("marker", prefab)

	# ── 2D gizmo: detection + self-drawing skip + lifecycle ──
	all_passed = _check("2D find_prefab detects a referenced prefab",
		EventSheetDrawingPrefabGizmo.find_prefab(ref_node), prefab) and all_passed
	var bare: Node2D = Node2D.new()
	all_passed = _check("2D find_prefab returns null when none is referenced",
		EventSheetDrawingPrefabGizmo.find_prefab(bare), null) and all_passed

	# The stamp draws its own prefab, so the gizmo must skip it (never double-draw). Its host is a Node2D.
	var stamp_node: Node2D = Node2D.new()
	stamp_node.set_script(load(STAMP_PATH))
	all_passed = _check("the DrawingPrefabStamp is skipped (self-drawing)",
		EventSheetDrawingPrefabGizmo._is_self_drawing(stamp_node), true) and all_passed
	all_passed = _check("a plain Node2D is not self-drawing",
		EventSheetDrawingPrefabGizmo._is_self_drawing(bare), false) and all_passed
	stamp_node.free()

	var host: Node2D = Node2D.new()
	var gizmo: EventSheetDrawingPrefabGizmo = EventSheetDrawingPrefabGizmo.new()
	gizmo._add_preview(host, prefab)
	var stamp: Node = host.get_node_or_null(EventSheetDrawingPrefabGizmo.PREVIEW_NODE_NAME)
	all_passed = _check("preview stamp is added under the host", stamp != null, true) and all_passed
	if stamp != null:
		all_passed = _check("preview stamp is the DrawingPrefabStamp renderer",
			str((stamp.get_script() as Script).resource_path).ends_with("drawing_prefab_stamp.gd"), true) and all_passed
		all_passed = _check("preview stamp never serializes (owner is null)", stamp.owner, null) and all_passed
		all_passed = _check("preview stamp carries the prefab", stamp.get("prefab"), prefab) and all_passed
	gizmo._clear_preview()
	all_passed = _check("clearing removes the preview stamp",
		host.get_node_or_null(EventSheetDrawingPrefabGizmo.PREVIEW_NODE_NAME), null) and all_passed
	gizmo.init(null)
	gizmo.teardown()
	all_passed = _check("2D init(null) + teardown() are safe no-ops", true, true) and all_passed
	host.free()

	# ── 3D gizmo: detection + billboard construction ──
	all_passed = _check("3D find_prefab detects a referenced prefab",
		EventSheetDrawingPrefab3DGizmo.find_prefab(ref_node), prefab) and all_passed
	var billboard: Node3D = EventSheetDrawingPrefab3DGizmo.build_billboard(prefab)
	all_passed = _check("build_billboard returns a Sprite3D", billboard is Sprite3D, true) and all_passed
	if billboard is Sprite3D:
		var sprite: Sprite3D = billboard as Sprite3D
		all_passed = _check("billboard is camera-facing",
			sprite.billboard, BaseMaterial3D.BILLBOARD_ENABLED) and all_passed
		all_passed = _check("billboard is textured from the rasterizer",
			sprite.texture != null and sprite.texture.get_width() == EventSheetDrawingPrefab3DGizmo.TEXTURE_SIZE.x, true) and all_passed
		all_passed = _check("billboard is unshaded", sprite.shaded, false) and all_passed
		all_passed = _check("billboard is transparent", sprite.transparent, true) and all_passed
		billboard.free()
	all_passed = _check("build_billboard(null) is null (nothing to draw)",
		EventSheetDrawingPrefab3DGizmo.build_billboard(null), null) and all_passed
	var gizmo3d: EventSheetDrawingPrefab3DGizmo = EventSheetDrawingPrefab3DGizmo.new()
	gizmo3d.init(null)
	gizmo3d.teardown()
	all_passed = _check("3D init(null) + teardown() are safe no-ops", true, true) and all_passed

	bare.free()
	ref_node.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] drawing_prefab_gizmo_test: %s" % label)
		return true
	print("[FAIL] drawing_prefab_gizmo_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
