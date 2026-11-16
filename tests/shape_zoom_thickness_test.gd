# Godot EventSheets - a stroke set to keep its weight on screen keeps it when a camera zooms.
#
# "Fixed on screen" divided the typed thickness by the node's own scale only, so under a Camera2D at
# zoom 2 a 4 px line was 8 px wide on the screen. The width is now worked out from the scale the node
# is really shown at - its transform with the canvas, which holds the camera's zoom, and the viewport's
# own canvas transform, which holds the editor view's zoom - and a fixed shape redraws when that scale
# moves. A test run has no scene tree, so the rule is asked as the pure function the shape draws with,
# and the places that feed it are pinned as text.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "shape_zoom_thickness_test"
const BASE := "res://eventsheet_addons/vector_shapes/vector_shape_2d.gd"
const FIXED := "fixed on screen"
const WITH_NODE := "with the node"


static func run() -> bool:
	var script: GDScript = load(BASE) as GDScript
	var source: String = FileAccess.get_file_as_string(BASE)
	var asked: bool = _has(script, "on_screen_thickness")
	var ok: bool = SUPPORT.check(TEST_NAME, "the rule is a function a test can ask", asked, true)
	if asked:
		ok = SUPPORT.pins(TEST_NAME, [
			["fixed: at zoom 2 the world width is half", script.call("on_screen_thickness", 4.0, FIXED, 2.0), 2.0],
			["fixed: at zoom 0.5 the world width is twice", script.call("on_screen_thickness", 4.0, FIXED, 0.5), 8.0],
			["fixed: a mirrored scale counts by its size", script.call("on_screen_thickness", 4.0, FIXED, -2.0), 2.0],
			["fixed: a scale of 0 is not a division by 0", is_finite(float(script.call("on_screen_thickness", 4.0, FIXED, 0.0))), true],
			["with the node: a zoom changes nothing", script.call("on_screen_thickness", 4.0, WITH_NODE, 2.0), 4.0],
			["with the node: nor at zoom 0.5", script.call("on_screen_thickness", 4.0, WITH_NODE, 0.5), 4.0],
		]) and ok
	ok = SUPPORT.pins(TEST_NAME, [
		["the shape asks the scale it is shown at", source.contains("get_global_transform_with_canvas()"), true],
		["the editor view's zoom is part of it", source.contains("get_global_canvas_transform()"), true],
		["not the node's own scale alone", source.contains("value / maxf(absf(global_scale.x), 0.0001)"), false],
		["a fixed shape keeps the scale it was drawn at", source.contains("_canvas_scale_seen"), true],
		["the rule's function is hidden from the picker", source.contains("## @ace_hidden\nstatic func on_screen_thickness("), true],
	]) and ok
	return ok


static func _has(script: GDScript, method: String) -> bool:
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method:
			return true
	return false
