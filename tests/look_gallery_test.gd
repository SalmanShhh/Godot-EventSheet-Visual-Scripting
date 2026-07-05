# Godot EventSheets - the Look Gallery (v0.11 chapter 2, P1: choose by picture).
#
# EventSheetInspectorLooks is the single source of truth for the Inspector-look
# presets: the Variable dialog's dropdown, the gallery's picture tiles, and these
# pins all read one table + one type filter, so the surfaces cannot drift. Pins are
# VALUES (exact id lists per type), not counts.
@tool
class_name LookGalleryTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# The shared type filter, pinned per type as exact ordered id lists.
	ok = _check("int looks", _ids_for("int"), [
		"flags", "enum_values",
		"layers_2d_physics", "layers_2d_render", "layers_2d_navigation",
		"layers_3d_physics", "layers_3d_render", "layers_3d_navigation",
		"layers_avoidance", "storage"
	]) and ok
	ok = _check("String looks", _ids_for("String"), [
		"file", "global_file", "dir", "global_dir", "suggestions",
		"preset_password", "preset_expression", "storage"
	]) and ok
	ok = _check("float looks", _ids_for("float"), [
		"easing_attenuation", "easing_positive", "storage"
	]) and ok
	ok = _check("Vector2 looks", _ids_for("Vector2"), ["preset_link", "storage"]) and ok

	# Every preset (and the default) renders a preview miniature, mouse-transparent
	# so the tile button underneath receives the click.
	var previews_ok: bool = true
	var mouse_ok: bool = true
	var preview_ids: Array = [""]
	for preset: Dictionary in EventSheetInspectorLooks.PRESETS:
		preview_ids.append(str(preset.get("id")))
	for look_id: String in preview_ids:
		var preview: Control = EventSheetInspectorLooks.build_preview(look_id)
		if preview == null:
			previews_ok = false
			print("  no preview for look '%s'" % look_id)
			continue
		if preview.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			mouse_ok = false
			print("  preview for look '%s' would swallow tile clicks" % look_id)
		preview.free()
	ok = _check("every look renders a preview miniature", previews_ok, true) and ok
	ok = _check("previews are mouse-transparent", mouse_ok, true) and ok

	# The gallery shows Default first, then exactly the filtered presets, in order.
	var gallery := EventSheetLookGalleryDialog.new()
	gallery.rebuild_for_type("int", "flags")
	var expected_tiles: Array = [""]
	expected_tiles.append_array(_ids_for("int"))
	ok = _check("gallery tiles = Default + the filtered presets", gallery.tile_look_ids(), expected_tiles) and ok
	gallery.rebuild_for_type("float", "")
	var float_tiles: Array = [""]
	float_tiles.append_array(_ids_for("float"))
	ok = _check("gallery re-filters on type change", gallery.tile_look_ids(), float_tiles) and ok
	gallery.free()

	return ok


static func _ids_for(type_name: String) -> Array:
	var output: Array = []
	for preset: Dictionary in EventSheetInspectorLooks.for_type(type_name):
		output.append(str(preset.get("id")))
	return output


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if str(actual) == str(expected):
		print("[PASS] look_gallery_test: %s" % label)
		return true
	print("[FAIL] look_gallery_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
