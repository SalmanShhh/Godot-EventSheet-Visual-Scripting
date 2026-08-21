# Godot EventSheets - the palette param hint (colour sets shown side by side)
# A palette data asset holds several colour SETS, one per kind of colour vision, and the Use
# Palette action's asset slot draws them all beside each other instead of naming a file. Pins:
# the path reader (quoted path in, expression refused), the set reader on a real
# ColorPaletteResource saved to disk (set names, role names, the colours themselves), the
# generic fallback that reads a palette-shaped asset with no set_names, and the wiring (the
# hint is registered in the params dialog, Use Palette's asset param carries it, and its
# frozen codegen template is untouched).
@tool
class_name PaletteSwatchParamTest
extends RefCounted

const ASSET_PATH: String = "user://x29_palette_swatch_test.tres"


static func run() -> bool:
	var all_passed: bool = true
	var dialog := ACEParamsDialog

	# ---- the path reader ----
	all_passed = _check("a quoted asset path unquotes",
		dialog.palette_path_of("\"res://palettes/default.tres\""), "res://palettes/default.tres") and all_passed
	all_passed = _check("an expression is not a path", dialog.palette_path_of("chosen_palette"), "") and all_passed
	all_passed = _check("an empty field is not a path", dialog.palette_path_of("  "), "") and all_passed

	# ---- a real asset on disk ----
	var palette: Resource = _write_palette()
	if palette == null:
		print("  [FAIL] palette_swatch_param_test: the palette asset could not be written")
		return false
	var sets: Array = dialog.palette_sets_at(ASSET_PATH)
	all_passed = _check("both sets are read", _set_names(sets), "Default|Deuteranopia") and all_passed
	all_passed = _check("the first set keeps its colours in order",
		_set_hexes(sets, 0), "ff0000|00ff00") and all_passed
	all_passed = _check("the second set keeps its own colours",
		_set_hexes(sets, 1), "0055ff|ffcc00") and all_passed
	all_passed = _check("the roles come back in order",
		"|".join(dialog.palette_role_names_at(ASSET_PATH)), "Danger|Safe") and all_passed

	# ---- an asset with no set names still draws, numbered ----
	var unnamed: Resource = _write_palette()
	unnamed.set("set_names", PackedStringArray())
	ResourceSaver.save(unnamed, ASSET_PATH)
	var unnamed_sets: Array = dialog.palette_sets_at(ASSET_PATH)
	all_passed = _check("unnamed sets are numbered rather than dropped",
		_set_names(unnamed_sets), "1|2") and all_passed

	# ---- nothing on disk degrades to no strip at all ----
	all_passed = _check("a path with no asset behind it reads as no sets",
		dialog.palette_sets_at("res://x29_no_such_palette.tres").size(), 0) and all_passed

	# ---- the strip itself: role labels first, then one column per set ----
	var strip: HBoxContainer = HBoxContainer.new()
	dialog.fill_palette_swatches(strip, "\"%s\"" % ASSET_PATH)
	all_passed = _check("the strip draws a column per set beside the role labels",
		_strip_labels(strip), "Danger|Safe / 1 / 2") and all_passed
	all_passed = _check("the first swatch carries the palette's first colour",
		_first_swatch_hex(strip), "ff0000") and all_passed
	var empty_strip: HBoxContainer = HBoxContainer.new()
	dialog.fill_palette_swatches(empty_strip, "chosen_palette")
	all_passed = _check("an expression leaves the strip hidden", empty_strip.visible, false) and all_passed
	strip.free()
	empty_strip.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ASSET_PATH))

	# ---- wiring ----
	var params_dialog: ACEParamsDialog = ACEParamsDialog.new()
	params_dialog._ensure_hint_factories()
	all_passed = _check("the params dialog registers the palette hint",
		params_dialog._hint_factories.has("palette"), true) and all_passed
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "UsePalette")
	all_passed = _check("Use Palette exists", descriptor != null, true) and all_passed
	if descriptor != null:
		all_passed = _check("its asset param carries the palette hint",
			(descriptor.params[1] as ACEParam).hint, "palette") and all_passed
		all_passed = _check("the frozen template is untouched",
			descriptor.codegen_template, "{palette} = load({path})") and all_passed
	return all_passed


## A two-set palette written to disk: the reader loads from a path, so a resource built only in
## memory would never exercise it.
static func _write_palette() -> Resource:
	var palette: Resource = ColorPaletteResource.new()
	palette.set("palette_name", "x29 test")
	palette.set("role_names", PackedStringArray(["Danger", "Safe"]))
	palette.set("set_names", PackedStringArray(["Default", "Deuteranopia"]))
	var sets: Array[PackedColorArray] = [
		PackedColorArray([Color("ff0000"), Color("00ff00")]),
		PackedColorArray([Color("0055ff"), Color("ffcc00")])
	]
	palette.set("set_colors", sets)
	if ResourceSaver.save(palette, ASSET_PATH) != OK:
		return null
	return palette


static func _set_names(sets: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in sets:
		names.append(str((entry as Dictionary).get("name", "")))
	return "|".join(names)


static func _set_hexes(sets: Array, index: int) -> String:
	if index >= sets.size():
		return ""
	var hexes: PackedStringArray = PackedStringArray()
	for colour: Color in ((sets[index] as Dictionary).get("colors", PackedColorArray()) as PackedColorArray):
		hexes.append(colour.to_html(false))
	return "|".join(hexes)


## The strip read back as text: each column's labels joined by "|", the columns by " / ".
static func _strip_labels(strip: HBoxContainer) -> String:
	var columns: PackedStringArray = PackedStringArray()
	for column: Node in strip.get_children():
		var texts: PackedStringArray = PackedStringArray()
		for child: Node in column.get_children():
			if child is Label:
				texts.append((child as Label).text)
		columns.append("|".join(texts))
	return " / ".join(columns)


static func _first_swatch_hex(strip: HBoxContainer) -> String:
	for column: Node in strip.get_children():
		for child: Node in column.get_children():
			if child is ColorRect:
				return (child as ColorRect).color.to_html(false)
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] palette_swatch_param_test: %s" % label)
		return true
	print("[FAIL] palette_swatch_param_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
