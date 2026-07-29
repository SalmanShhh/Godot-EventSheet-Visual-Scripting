# EventForge - every behaviour pack ships its OWN icon (eventsheet_addons/<pack>/icon.svg), wired
# end to end: save_pack auto-detects the pack-local icon, the emitted .gd carries it as `@icon(...)`
# (Create New Node dialog) and per-member `## @ace_icon(...)` (picker rows + viewport object labels),
# and the picker's builtin section headers map categories to editor-theme icons. Pins: the asset +
# its import sidecar exist for every pack, the emitted paths point at the pack's own icon (never the
# shared behavior.svg anymore), and the category->EditorIcons mapping covers every live builtin
# category (subs inherit their parent) so a new module can't silently ship an icon-less section.
@tool
class_name PackIconsTest
extends RefCounted


const ADDONS_DIR := "res://eventsheet_addons"

# Categories deliberately left without a module icon (nothing in the editor theme fits yet).
const UNMAPPED_CATEGORIES := ["Performance"]


static func run() -> bool:
	var ok: bool = true

	# ---- every pack directory ships icon.svg + its .import sidecar ----
	var dir: DirAccess = DirAccess.open(ADDONS_DIR)
	ok = _check(ok, dir != null, "eventsheet_addons opens")
	var pack_dirs: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			pack_dirs.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	ok = _check(ok, pack_dirs.size() >= 74, "at least 74 pack dirs found (got %d)" % pack_dirs.size())
	for pack: String in pack_dirs:
		var icon_path: String = "%s/%s/icon.svg" % [ADDONS_DIR, pack]
		ok = _check(ok, FileAccess.file_exists(icon_path), "%s has icon.svg" % pack)
		ok = _check(ok, FileAccess.file_exists(icon_path + ".import"), "%s icon.svg is imported" % pack)

	# ---- the emitted pack .gd points at its own icon, in both @icon and every @ace_icon ----
	for pack: String in pack_dirs:
		var pack_icon: String = "%s/%s/icon.svg" % [ADDONS_DIR, pack]
		var gd_path: String = _pack_script_path(pack)
		ok = _check(ok, not gd_path.is_empty(), "%s has a pack .gd" % pack)
		if gd_path.is_empty():
			continue
		var source: String = FileAccess.get_file_as_string(gd_path)
		ok = _check(ok, source.contains("@icon(\"%s\")" % pack_icon), "%s @icon points at its own icon.svg" % pack)
		ok = _check(ok, not source.contains("behavior.svg"), "%s no longer references the shared behavior.svg" % pack)
		var ace_icon_prefix: String = "## @ace_icon(\""
		var search_from: int = 0
		while true:
			var found: int = source.find(ace_icon_prefix, search_from)
			if found == -1:
				break
			var value_start: int = found + ace_icon_prefix.length()
			var value_end: int = source.find("\")", value_start)
			ok = _check(ok, source.substr(value_start, value_end - value_start) == pack_icon, "%s @ace_icon points at its own icon.svg" % pack)
			search_from = value_end

	# ---- builtin category -> EditorIcons mapping: full coverage of the live vocabulary ----
	var categories: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		categories[descriptor.category] = true
	for category: String in categories:
		if category in UNMAPPED_CATEGORIES:
			continue
		var icon_name: String = ACEPickerDialog.category_icon_name(category)
		ok = _check(ok, not icon_name.is_empty(), "builtin category \"%s\" maps to an editor icon" % category)

	# ---- the mapping's own semantics: explicit entry, derivation, inheritance, unknown -> "" ----
	# 1. An explicit entry wins, and is how an abstract category (no class of that name, no host
	#    node behind its verbs) gets an icon at all.
	var math_icon: String = ACEPickerDialog.category_icon_name("Math & Random")
	ok = _check(ok, math_icon == "RandomNumberGenerator", "Math & Random maps to RandomNumberGenerator (got %s)" % math_icon)
	var array_icon: String = ACEPickerDialog.category_icon_name("Variables: Array")
	ok = _check(ok, array_icon == "Array", "Variables: Array has its own entry (got %s)" % array_icon)
	var dirs_icon: String = ACEPickerDialog.category_icon_name("Files: Directories")
	ok = _check(ok, dirs_icon == "Folder", "Files: Directories has its own entry (got %s)" % dirs_icon)

	# 2. DERIVED FROM THE NAME, case- and space-insensitively, so a category named after a class
	#    needs no entry. These deliberately have none - if someone re-adds one, the derivation has
	#    silently stopped being exercised.
	var ray_icon: String = ACEPickerDialog.category_icon_name("Raycast 2D")
	ok = _check(ok, ray_icon == "RayCast2D", "\"Raycast 2D\" derives RayCast2D from its name (got %s)" % ray_icon)
	var tilemap_icon: String = ACEPickerDialog.category_icon_name("Tilemap")
	ok = _check(ok, tilemap_icon == "TileMap", "\"Tilemap\" derives TileMap despite the capitalisation (got %s)" % tilemap_icon)
	ok = _check(ok, not ACEPickerDialog.CATEGORY_EDITOR_ICONS.has("Raycast 2D"), "Raycast 2D is derived, not listed")

	# 2b. The vocabulary list holds BOTH shapes, so the host lookup has to read both. An ACEDescriptor
	# keeps its host in `node_type`; an ACEDefinition - what a provider script and simple_ace produce -
	# has no such property and keeps it in `metadata`. Reading `.node_type` unconditionally threw once
	# per definition, which headless runs never saw (definitions only join the list in a live editor)
	# and which filled the Output dock the moment anyone opened a sheet.
	var host_descriptor: ACEDescriptor = ACEDescriptor.new()
	host_descriptor.node_type = "Area2D"
	ok = _check(ok, ACEPickerDialog.host_class_of(host_descriptor) == "Area2D",
		"a descriptor's host reads off node_type (got %s)" % ACEPickerDialog.host_class_of(host_descriptor))
	var host_definition: ACEDefinition = ACEDefinition.new()
	host_definition.metadata = {"node_type": "Timer"}
	ok = _check(ok, ACEPickerDialog.host_class_of(host_definition) == "Timer",
		"a definition's host reads off metadata (got %s)" % ACEPickerDialog.host_class_of(host_definition))
	ok = _check(ok, ACEPickerDialog.host_class_of(ACEDefinition.new()) == "",
		"and a definition with no host is empty, not an error")
	ok = _check(ok, not ACEPickerDialog.CATEGORY_EDITOR_ICONS.has("Tilemap"), "Tilemap is derived, not listed")

	# 3. DERIVED FROM THE HOST its verbs run on, which is what rescues a category whose name is not
	#    a class. "UI" is not a class; every UI verb hosts on a Control, so the Control icon it is.
	var ui_icon: String = ACEPickerDialog.category_icon_name("UI")
	ok = _check(ok, ui_icon == "Control", "\"UI\" derives Control from its verbs' host (got %s)" % ui_icon)
	ok = _check(ok, not ACEPickerDialog.CATEGORY_EDITOR_ICONS.has("UI"), "UI is derived, not listed")
	# A caller that knows the host passes it in, so an addon's own category resolves with no entry
	# anywhere - the case that used to leave a pack section iconless.
	var hinted: String = ACEPickerDialog.category_icon_name("Turrets", "Node2D")
	ok = _check(ok, hinted == "Node2D", "an unlisted category resolves from the caller's host hint (got %s)" % hinted)

	# 4. "Parent: Sub" inherits whatever the parent resolves to, derivation included.
	var picking_icon: String = ACEPickerDialog.category_icon_name("Nodes: Picking")
	ok = _check(ok, picking_icon == "Node", "Nodes: Picking inherits the Nodes entry (got %s)" % picking_icon)
	var sub_derived: String = ACEPickerDialog.category_icon_name("Tilemap: Layers")
	ok = _check(ok, sub_derived == "TileMap", "a sub-category inherits a DERIVED parent icon too (got %s)" % sub_derived)

	# 5. Nothing to go on still means no icon - a text-only header, never a wrong guess.
	var unknown_icon: String = ACEPickerDialog.category_icon_name("Not A Real Category")
	ok = _check(ok, unknown_icon == "", "an unknown category resolves to empty (got %s)" % unknown_icon)

	return ok


## The pack's main .gd (the only .gd directly inside the pack folder). Empty when none exists.
static func _pack_script_path(pack: String) -> String:
	var pack_dir: DirAccess = DirAccess.open("%s/%s" % [ADDONS_DIR, pack])
	if pack_dir == null:
		return ""
	pack_dir.list_dir_begin()
	var entry: String = pack_dir.get_next()
	while not entry.is_empty():
		if not pack_dir.current_is_dir() and entry.ends_with(".gd"):
			pack_dir.list_dir_end()
			return "%s/%s/%s" % [ADDONS_DIR, pack, entry]
		entry = pack_dir.get_next()
	pack_dir.list_dir_end()
	return ""


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
