# Godot EventSheets - the builtin Draw ACE module.
#
# Pins that drawing is now first-class, pickable vocabulary usable on ANY node (not only via the Drawing
# Canvas behavior): the module registers Draw Line/Circle/Ring/... and Canvas Texture, each compiling to a
# CanvasSurface.for_node({node}) call (the shared runtime, not a plugin class). Templates are API once
# shipped, so a couple are pinned verbatim. The suite's builtin-ACE compile test proves they parse.
@tool
class_name DrawingACEsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var descs: Array[ACEDescriptor] = EventForgeDrawingACEs.get_descriptors()
	var by_id: Dictionary = {}
	for d: ACEDescriptor in descs:
		by_id[str(d.ace_id)] = d

	all_passed = _check("the drawing module ships a full vocabulary", descs.size() >= 15, true) and all_passed
	all_passed = _check("Draw Circle registers", by_id.has("DrawCircle"), true) and all_passed
	all_passed = _check("Canvas Texture, Start Ribbon, Draw Prefab register",
		by_id.has("DrawCanvasTexture") and by_id.has("DrawStartRibbon") and by_id.has("DrawPrefabAce"), true) and all_passed

	# Frozen templates: each verb draws onto the shared runtime, on the picked node, not a plugin class.
	all_passed = _check("Draw Circle compiles onto CanvasSurface.for_node({node})",
		str((by_id.get("DrawCircle") as ACEDescriptor).codegen_template) if by_id.has("DrawCircle") else "MISSING",
		"CanvasSurface.for_node({node}).circle({x}, {y}, {radius}, {color})") and all_passed
	all_passed = _check("Canvas Texture is an expression on the node's surface",
		str((by_id.get("DrawCanvasTexture") as ACEDescriptor).codegen_template) if by_id.has("DrawCanvasTexture") else "MISSING",
		"CanvasSurface.for_node({node}).texture()") and all_passed

	# Dashed shapes: new ace_ids + frozen templates (additive - the shared dash primitive on the runtime).
	all_passed = _check("dashed verbs register", by_id.has("DrawDashedLine") and by_id.has("DrawDashedRing") and by_id.has("DrawDashedRect"), true) and all_passed
	all_passed = _check("Draw Dashed Line template is frozen", str((by_id.get("DrawDashedLine") as ACEDescriptor).codegen_template) if by_id.has("DrawDashedLine") else "MISSING", "CanvasSurface.for_node({node}).dashed_line({from_x}, {from_y}, {to_x}, {to_y}, {dash_length}, {gap_length}, {width}, {color})") and all_passed
	all_passed = _check("Draw Dashed Rect template is frozen", str((by_id.get("DrawDashedRect") as ACEDescriptor).codegen_template) if by_id.has("DrawDashedRect") else "MISSING", "CanvasSurface.for_node({node}).dashed_rect({x}, {y}, {width}, {height}, {dash_length}, {gap_length}, {line_width}, {color})") and all_passed

	# No emitted template names a plugin class (the runtime lives in eventsheet_addons, not the editor).
	var clean: bool = true
	for d: ACEDescriptor in descs:
		if str(d.codegen_template).contains("EventForge") or str(d.codegen_template).contains("EventSheet"):
			clean = false
	all_passed = _check("no Draw ACE references an editor plugin class", clean, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] drawing_aces_test: %s" % label)
		return true
	print("[FAIL] drawing_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
