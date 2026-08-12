# Godot EventSheets - the data-asset vocabulary (resource_aces.gd).
#
# Fifteen verbs across four jobs: a folder of .tres as content, independent copies (the shared-asset
# trap), pouring values between objects, and migrating a record written by an older build. Each verb
# is proven TWICE:
#   1. EMISSION - a real row is compiled through SheetCompiler and the exact emitted GDScript pinned,
#      so a template edit that changes what users ship fails here.
#   2. RUNTIME - the SHIPPED template (substituted through the real ActionCodegen, never a re-typed
#      copy) is assembled into a GDScript, reload()ed, and driven for the behaviour the picker help
#      promises, including the edge cases: a missing folder, a missing file, a non-resource, a name
#      the other object does not have, a name NEITHER has, a freed object, a field left at 0, a
#      version field holding null, a blank list, a second migration run.
# The copy pair carries the load-bearing proof: mutate the copy's sub-resource and the ORIGINAL must
# be untouched for the independent copy, and must change for the sharing one - the difference the
# verbs exist to make legible.
#
# One engine error line is EXPECTED: a deliberately unreadable .tres written into the sandbox folder,
# proving Resources In Folder leaves a file that fails to load OUT of the list rather than handing
# back a dead entry - the mod-folder case the verb exists for.
@tool
class_name ResourceACEsTest
extends RefCounted

const SANDBOX := "user://eventforge_resource_aces_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_registry_shape() and ok
	ok = _test_folder_emission() and ok
	ok = _test_folder_runtime() and ok
	ok = _test_copy_emission() and ok
	ok = _test_copy_resource_runtime() and ok
	ok = _test_deep_copy_collections_runtime() and ok
	ok = _test_pouring_emission() and ok
	ok = _test_copy_values_runtime() and ok
	ok = _test_fill_blanks_runtime() and ok
	ok = _test_apply_preset_runtime() and ok
	ok = _test_matches_properties_runtime() and ok
	ok = _test_migration_emission() and ok
	ok = _test_migration_runtime() and ok
	return ok


## Every verb registers, in a category the picker already has an icon for, with the right kind.
static func _test_registry_shape() -> bool:
	var by_id: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[d.ace_id] = d
	var ok: bool = true
	var expected: Dictionary = {
		"ResourcesInFolder": ["Files", ACEDescriptor.ACEType.EXPRESSION],
		"ResourceInFolder": ["Files", ACEDescriptor.ACEType.EXPRESSION],
		"LoadResourceOrDefault": ["Files", ACEDescriptor.ACEType.EXPRESSION],
		"CountResourcesInFolder": ["Files", ACEDescriptor.ACEType.EXPRESSION],
		"CopyResourceDeep": ["Helpers", ACEDescriptor.ACEType.EXPRESSION],
		"CopyResourceShallow": ["Helpers", ACEDescriptor.ACEType.EXPRESSION],
		"ArrayDeepDuplicate": ["Variables: Array", ACEDescriptor.ACEType.EXPRESSION],
		"DictDeepDuplicate": ["Variables: Dictionary", ACEDescriptor.ACEType.EXPRESSION],
		"CopyValuesFrom": ["Helpers", ACEDescriptor.ACEType.ACTION],
		"FillBlanksFrom": ["Helpers", ACEDescriptor.ACEType.ACTION],
		"ApplyPresetToNode": ["Helpers", ACEDescriptor.ACEType.ACTION],
		"MatchesPropertiesOf": ["Helpers", ACEDescriptor.ACEType.CONDITION],
		"DataIsOlderThanVersion": ["Variables: Dictionary", ACEDescriptor.ACEType.CONDITION],
		"RenameField": ["Variables: Dictionary", ACEDescriptor.ACEType.ACTION],
		"StampDataVersion": ["Variables: Dictionary", ACEDescriptor.ACEType.ACTION],
	}
	for ace_id: String in expected:
		ok = _check("%s is registered" % ace_id, by_id.has(ace_id), true) and ok
		if not by_id.has(ace_id):
			continue
		var descriptor: ACEDescriptor = by_id[ace_id]
		ok = _check("%s sits in %s" % [ace_id, expected[ace_id][0]], str(descriptor.category), str(expected[ace_id][0])) and ok
		ok = _check("%s is the right kind of verb" % ace_id, descriptor.ace_type, int(expected[ace_id][1])) and ok
		ok = _check("%s carries hover help" % ace_id, str(descriptor.description).strip_edges().is_empty(), false) and ok
	# The two copy verbs must NAME the difference in their own display text - that is the whole point.
	ok = _check("the independent copy says so on the row",
		str(by_id["CopyResourceDeep"].display_name), "Copy Resource (Independent)") and ok
	ok = _check("the sharing copy says so on the row",
		str(by_id["CopyResourceShallow"].display_name), "Copy Resource (Share Sub-Resources)") and ok
	return ok


# ── #6 Resource Library ─────────────────────────────────────────────────────────────────────────
## The four folder expressions land inside a Set Variable row exactly as authored.
static func _test_folder_emission() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _row()
	row.actions.append(_action("SetVar", {"var_name": "catalogue", "value": _fill("ResourcesInFolder", {})}))
	row.actions.append(_action("SetVar", {"var_name": "one", "value": _fill("ResourceInFolder", {"name": "\"rusty_sword\""})}))
	row.actions.append(_action("SetVar", {"var_name": "stats", "value": _fill("LoadResourceOrDefault", {"fallback": "null"})}))
	row.actions.append(_action("SetVar", {"var_name": "mods", "value": _fill("CountResourcesInFolder", {"folder": "\"res://mods\""})}))
	sheet.events.append(row)
	var output: String = _compile(sheet, "user://eventforge_res_folder_emit.gd")
	var ok: bool = _check("Resources In Folder emits the trimmed-remap scan behind a folder-exists guard",
		output.contains("\tcatalogue = Array(DirAccess.get_files_at(\"res://data/items\") if DirAccess.dir_exists_absolute(\"res://data/items\") else PackedStringArray()).map(func(__f): return \"res://data/items\".path_join(__f.trim_suffix(\".remap\"))).filter(func(__p): return __p.get_extension() in [\"tres\", \"res\"]).map(func(__p): return load(__p))"), true)
	ok = _check("Resource In Folder emits the guarded by-name load",
		output.contains("\tone = (load(\"res://data/items\".path_join(\"rusty_sword\") + \".tres\") if ResourceLoader.exists(\"res://data/items\".path_join(\"rusty_sword\") + \".tres\") else null)"), true) and ok
	ok = _check("Load Resource Or Default emits the exists-guarded fallback",
		output.contains("\tstats = (load(\"res://data/item.tres\") if ResourceLoader.exists(\"res://data/item.tres\") else null)"), true) and ok
	ok = _check("Count Of Resources In emits a count that never loads a file",
		output.contains("\tmods = Array(DirAccess.get_files_at(\"res://mods\") if DirAccess.dir_exists_absolute(\"res://mods\") else PackedStringArray()).filter(func(__f): return __f.trim_suffix(\".remap\").get_extension() in [\"tres\", \"res\"]).size()"), true) and ok
	# A folder that is not there yet (the mod folder before the player fills it) is the NORMAL case:
	# DirAccess.get_files_at prints a red engine error for one, so both walks must test it first.
	ok = _check("the folder list checks the folder exists before reading it",
		_fill("ResourcesInFolder", {}).contains("if DirAccess.dir_exists_absolute("), true) and ok
	ok = _check("the folder count checks the folder exists before reading it",
		_fill("CountResourcesInFolder", {}).contains("if DirAccess.dir_exists_absolute("), true) and ok
	return ok


## A real folder of .tres on disk: the list loads them, the by-name fetch finds one, the count
## ignores everything that is not a data asset, and every one of them survives a missing folder.
static func _test_folder_runtime() -> bool:
	var folder: String = SANDBOX + "/library"
	DirAccess.make_dir_recursive_absolute(folder)
	_save_curve(folder + "/alpha.tres", 42)
	_save_curve(folder + "/beta.tres", 7)
	var notes: FileAccess = FileAccess.open(folder + "/readme.txt", FileAccess.WRITE)
	if notes != null:
		notes.store_string("not a resource")
		notes.close()

	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func all_in(folder: String) -> Array:",
		"\treturn %s" % _fill("ResourcesInFolder", {"folder": "folder"}),
		"func one_in(folder: String, asset_name: String):",
		"\treturn %s" % _fill("ResourceInFolder", {"folder": "folder", "name": "asset_name"}),
		"func or_default(path: String, fallback):",
		"\treturn %s" % _fill("LoadResourceOrDefault", {"path": "path", "fallback": "fallback"}),
		"func count_in(folder: String) -> int:",
		"\treturn %s" % _fill("CountResourcesInFolder", {"folder": "folder"}),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the folder templates assemble into a script", false, true)

	var loaded: Array = instance.call("all_in", folder)
	var resolutions: Array = []
	for entry: Variant in loaded:
		resolutions.append(int((entry as Curve).bake_resolution))
	resolutions.sort()
	var ok: bool = _check("Resources In Folder loads every data asset and skips the .txt", resolutions, [7, 42])
	ok = _check("Resources In Folder returns an empty list for a folder that is not there",
		instance.call("all_in", SANDBOX + "/nope"), []) and ok

	# A mod folder is the case this verb was added for, and a .tres saved by an older build (or one
	# whose script class was removed) loads as NOTHING. It must be left out rather than arriving as a
	# dead entry the first `entry.field` in a For Each trips over - and `has(null)` does not reliably
	# catch it, so the guard an author would reach for would not have saved them either. The engine
	# logs a parse error for the unreadable file: that line is expected, and is the point.
	var broken: FileAccess = FileAccess.open(folder + "/broken.tres", FileAccess.WRITE)
	if broken != null:
		broken.store_string("this is not a resource at all {{{")
		broken.close()
	var with_broken: Array = instance.call("all_in", folder)
	ok = _check("a file that fails to load is left out, not handed back as nothing",
		with_broken.size(), 2) and ok
	var live: int = 0
	for entry: Variant in with_broken:
		if entry != null:
			live += 1
	ok = _check("so every entry in the list is a real data asset", live, 2) and ok
	# Its looping twin walks the same folder, and the two must agree about what is in it.
	var loop_source: String = "@tool\nextends RefCounted\nfunc walk(folder: String) -> Array:\n\treturn %s\n" % _fill("ForEachResourceInFolder", {"folder": "folder"})
	var loop_instance: RefCounted = _instance(loop_source)
	if loop_instance == null:
		ok = _check("the For Each Resource In Folder template assembles into a script", false, true) and ok
	else:
		ok = _check("For Each Resource In Folder walks exactly the same entries",
			(loop_instance.call("walk", folder) as Array).size(), with_broken.size()) and ok
	DirAccess.remove_absolute(folder + "/broken.tres")

	var one: Variant = instance.call("one_in", folder, "alpha")
	ok = _check("Resource In Folder fetches the named asset", int((one as Curve).bake_resolution), 42) and ok
	ok = _check("Resource In Folder hands back nothing for a name that is not there",
		instance.call("one_in", folder, "missing"), null) and ok

	var spare: Curve = Curve.new()
	spare.bake_resolution = 99
	var got: Variant = instance.call("or_default", folder + "/beta.tres", spare)
	ok = _check("Load Resource Or Default loads the real file when it exists", int((got as Curve).bake_resolution), 7) and ok
	ok = _check("Load Resource Or Default hands back the fallback when the file is missing",
		instance.call("or_default", folder + "/gone.tres", spare) == spare, true) and ok

	ok = _check("Count Of Resources In counts the data assets only", int(instance.call("count_in", folder)), 2) and ok
	ok = _check("Count Of Resources In is zero for a folder that is not there",
		int(instance.call("count_in", SANDBOX + "/nope")), 0) and ok
	return ok


# ── #7 Copy Resource (Independent) / (Share Sub-Resources) / Deep Copy ──────────────────────────
static func _test_copy_emission() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _row()
	row.actions.append(_action("SetVar", {"var_name": "own_stats", "value": _fill("CopyResourceDeep", {"resource": "enemy_stats"})}))
	row.actions.append(_action("SetVar", {"var_name": "cheap", "value": _fill("CopyResourceShallow", {"resource": "enemy_stats"})}))
	row.actions.append(_action("SetVar", {"var_name": "rows", "value": _fill("ArrayDeepDuplicate", {"var_name": "grid"})}))
	row.actions.append(_action("SetVar", {"var_name": "book", "value": _fill("DictDeepDuplicate", {"var_name": "level_data"})}))
	sheet.events.append(row)
	var output: String = _compile(sheet, "user://eventforge_res_copy_emit.gd")
	var ok: bool = _check("Copy Resource (Independent) emits duplicate(true) behind a Resource guard",
		output.contains("\town_stats = (enemy_stats.duplicate(true) if enemy_stats is Resource else null)"), true)
	ok = _check("Copy Resource (Share Sub-Resources) emits duplicate(false) behind the same guard",
		output.contains("\tcheap = (enemy_stats.duplicate(false) if enemy_stats is Resource else null)"), true) and ok
	ok = _check("Deep Copy of an array emits duplicate(true)",
		output.contains("\trows = grid.duplicate(true)"), true) and ok
	ok = _check("Deep Copy of a dictionary emits duplicate(true)",
		output.contains("\tbook = level_data.duplicate(true)"), true) and ok
	return ok


## THE trap, proven both ways: a .tres shared across nodes is one object, so an independent copy must
## survive a write to its sub-resource with the original untouched, and the sharing copy must NOT.
static func _test_copy_resource_runtime() -> bool:
	var inner_script: GDScript = _script("@tool\nextends Resource\n\n@export var hp: int = 10\n")
	var outer_script: GDScript = _script("@tool\nextends Resource\n\n@export var label: String = \"base\"\n@export var tags: Array = []\n@export var inner: Resource = null\n")
	if inner_script == null or outer_script == null:
		return _check("the sample resource scripts compile", false, true)

	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func independent(res):",
		"\treturn %s" % _fill("CopyResourceDeep", {"resource": "res"}),
		"func sharing(res):",
		"\treturn %s" % _fill("CopyResourceShallow", {"resource": "res"}),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the copy templates assemble into a script", false, true)

	var asset: Resource = outer_script.new()
	asset.set("inner", inner_script.new())
	asset.set("tags", ["shipped"])

	var mine: Resource = instance.call("independent", asset)
	var ok: bool = _check("the independent copy is not the asset itself", mine == asset, false)
	ok = _check("the independent copy carries the asset's values", str(mine.get("label")), "base") and ok
	ok = _check("the independent copy has its OWN sub-resource",
		mine.get("inner") == asset.get("inner"), false) and ok
	mine.get("inner").set("hp", 99)
	mine.get("tags").append("run")
	ok = _check("writing to the independent copy's sub-resource leaves the asset alone",
		int(asset.get("inner").get("hp")), 10) and ok
	ok = _check("writing to the independent copy's list leaves the asset's list alone",
		asset.get("tags"), ["shipped"]) and ok

	var cheap: Resource = instance.call("sharing", asset)
	ok = _check("the sharing copy is not the asset itself", cheap == asset, false) and ok
	ok = _check("the sharing copy points at the asset's SAME sub-resource",
		cheap.get("inner") == asset.get("inner"), true) and ok
	cheap.get("inner").set("hp", 77)
	ok = _check("writing to the sharing copy's sub-resource DOES reach the asset - the documented trap",
		int(asset.get("inner").get("hp")), 77) and ok

	# The guard: anything that is not a resource gives nothing back instead of crashing.
	ok = _check("an independent copy of nothing is nothing", instance.call("independent", null), null) and ok
	ok = _check("an independent copy of a plain number is nothing", instance.call("independent", 5), null) and ok
	ok = _check("a sharing copy of nothing is nothing", instance.call("sharing", null), null) and ok
	return ok


## Deep Copy vs the shipped (shallow) Copy Array / Copy Dictionary: the nested value is what differs.
static func _test_deep_copy_collections_runtime() -> bool:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func deep_list(list: Array) -> Array:",
		"\treturn %s" % _fill("ArrayDeepDuplicate", {"var_name": "list"}),
		"func shallow_list(list: Array) -> Array:",
		"\treturn %s" % _fill("ArrayDuplicate", {"var_name": "list"}),
		"func deep_dict(dict: Dictionary) -> Dictionary:",
		"\treturn %s" % _fill("DictDeepDuplicate", {"var_name": "dict"}),
		"func shallow_dict(dict: Dictionary) -> Dictionary:",
		"\treturn %s" % _fill("DictDuplicate", {"var_name": "dict"}),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the deep-copy templates assemble into a script", false, true)

	var nested_list: Array = [["a"], ["b"]]
	var deep: Array = instance.call("deep_list", nested_list)
	deep[0].append("z")
	var ok: bool = _check("a deep array copy's nested list is its own", nested_list[0], ["a"])
	var shallow: Array = instance.call("shallow_list", nested_list)
	shallow[0].append("z")
	ok = _check("the shipped shallow Copy Array shares the nested list - the reason Deep Copy exists",
		nested_list[0], ["a", "z"]) and ok

	var nested_dict: Dictionary = {"room": {"name": "start"}}
	var deep_d: Dictionary = instance.call("deep_dict", nested_dict)
	deep_d["room"]["name"] = "changed"
	ok = _check("a deep dictionary copy's nested dictionary is its own",
		str(nested_dict["room"]["name"]), "start") and ok
	var shallow_d: Dictionary = instance.call("shallow_dict", nested_dict)
	shallow_d["room"]["name"] = "changed"
	ok = _check("the shipped shallow Copy Dictionary shares the nested dictionary",
		str(nested_dict["room"]["name"]), "changed") and ok

	# The two Deep Copy verbs SHARE a display name and a template, which is deliberate: one sits in
	# Variables: Array beside Copy Array, the other in Variables: Dictionary beside Copy Dictionary,
	# and each offers the param type its section expects. That is only safe because an EXPRESSION is
	# never put in the reverse-lift index at all - so there is no tie for registry order to break and
	# a hand-written `save.duplicate(true)` cannot come back as the wrong one of the pair. Pinned
	# here so a future change that starts indexing expressions has to face this pair first.
	var array_copy: ACEDescriptor = ACERegistry.find_descriptor("Core", "ArrayDeepDuplicate")
	var dict_copy: ACEDescriptor = ACERegistry.find_descriptor("Core", "DictDeepDuplicate")
	ok = _check("both Deep Copy verbs are expressions", [int(array_copy.ace_type), int(dict_copy.ace_type)],
		[int(ACEDescriptor.ACEType.EXPRESSION), int(ACEDescriptor.ACEType.EXPRESSION)]) and ok
	ok = _check("each is filed in the section whose Copy verb it completes",
		[str(array_copy.category), str(dict_copy.category)], ["Variables: Array", "Variables: Dictionary"]) and ok
	ok = _check("and each offers the param type that section expects",
		[str(array_copy.params[0].hint), str(dict_copy.params[0].hint)],
		["variable_reference:Array", "variable_reference:Dictionary"]) and ok
	var indexed: int = 0
	for entry: Variant in EventSheetACELifter._build_reverse_entries():
		if str((entry as Dictionary).get("ace_id", "")) in ["ArrayDeepDuplicate", "DictDeepDuplicate"]:
			indexed += 1
	ok = _check("neither reaches the reverse-lift index, so the shared template cannot mis-claim a line",
		indexed, 0) and ok
	return ok


# ── #8 Copy Values From / Fill Blanks From / Apply Preset To Node / Matches Properties Of ───────
static func _test_pouring_emission() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _row()
	row.conditions.append(_condition("MatchesPropertiesOf", {"target": "self", "names": "\"position, rotation\"", "other": "$Player"}))
	row.actions.append(_action("CopyValuesFrom", {"target": "self", "source": "$EnemyTemplate", "names": "\"speed, damage\""}, "a"))
	row.actions.append(_action("FillBlanksFrom", {"target": "self", "base": "base_tuning"}, "b"))
	row.actions.append(_action("ApplyPresetToNode", {"preset": "enraged_tuning", "target": "self"}, "c"))
	sheet.events.append(row)
	var output: String = _compile(sheet, "user://eventforge_res_pour_emit.gd")

	# The `__n in self` clause is the load-bearing one: Object.get() answers null for a property that
	# is not there, so without it a misspelled name compared null to null and read as "in sync".
	var ok: bool = _check("Matches Properties Of emits an all() that requires the name to EXIST, both sides null-guarded",
		output.contains("(self != null and $Player != null and Array(\"position, rotation\".split(\",\", false)).all(func(__n): return __n.strip_edges() in self and self.get(__n.strip_edges()) == $Player.get(__n.strip_edges())))"), true)
	ok = _check("Copy Values From binds both objects once, then copies by name",
		output.contains("\t\tvar __src_a: Object = $EnemyTemplate\n\t\tvar __dst_a: Object = self\n\t\tvar __fields_a: PackedStringArray = \"speed, damage\".split(\",\", false)"), true) and ok
	ok = _check("Copy Values From falls back to the source's own script variables when no names are given",
		output.contains("\t\tif __fields_a.is_empty():\n\t\t\tfor __info_a: Dictionary in __src_a.get_property_list():\n\t\t\t\tif int(__info_a[\"usage\"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:"), true) and ok
	ok = _check("Copy Values From only writes a field both objects have",
		output.contains("\t\t\tif __key_a in __src_a and __key_a in __dst_a:\n\t\t\t\t__dst_a.set(__key_a, __src_a.get(__key_a))"), true) and ok
	ok = _check("Fill Blanks From walks the base's script variables",
		output.contains("\t\tvar __base_b: Object = base_tuning\n\t\tvar __target_b: Object = self"), true) and ok
	ok = _check("Fill Blanks From treats null and empty text / list / record as blank",
		output.contains("\t\t\tif __value_b == null or (__value_b is String and __value_b.is_empty()) or (__value_b is Array and __value_b.is_empty()) or (__value_b is Dictionary and __value_b.is_empty()):"), true) and ok
	ok = _check("Apply Preset To Node guards both sides before it writes anything",
		output.contains("\t\tvar __preset_c: Object = enraged_tuning\n\t\tvar __node_c: Object = self\n\t\tif __preset_c != null and __node_c != null:"), true) and ok
	return ok


static func _test_copy_values_runtime() -> bool:
	var actor_script: GDScript = _script("@tool\nextends Node\n\nvar speed: float = 0.0\nvar damage: int = 0\nvar label: String = \"\"\n")
	var partial_script: GDScript = _script("@tool\nextends Node\n\nvar speed: float = 0.0\n")
	if actor_script == null or partial_script == null:
		return _check("the sample actor scripts compile", false, true)

	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func pour(dst: Object, src: Object, names: String) -> void:",
		_indent(_fill("CopyValuesFrom", {"target": "dst", "source": "src", "names": "names"}), 1),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the Copy Values From template assembles into a script", false, true)

	var source_node: Node = _node(actor_script, {"speed": 9.5, "damage": 4, "label": "template"})
	var target_node: Node = _node(actor_script, {"speed": 0.0, "damage": 0, "label": "mine"})
	instance.call("pour", target_node, source_node, "speed, damage")
	var ok: bool = _check("a named property is copied", float(target_node.get("speed")), 9.5)
	ok = _check("a second named property is copied", int(target_node.get("damage")), 4) and ok
	ok = _check("a property left off the list is not touched", str(target_node.get("label")), "mine") and ok

	# Blank list = every variable the SOURCE's script declares.
	var blank_target: Node = _node(actor_script, {"speed": 0.0, "damage": 0, "label": "mine"})
	instance.call("pour", blank_target, source_node, "")
	ok = _check("a blank list copies every script variable the source declares",
		str(blank_target.get("label")), "template") and ok

	# A name the target does not have is skipped, not an error - one preset can serve several types.
	var partial: Node = _node(partial_script, {"speed": 0.0})
	instance.call("pour", partial, source_node, "speed, damage, label")
	ok = _check("a shared property still copies onto a node that lacks the others",
		float(partial.get("speed")), 9.5) and ok
	ok = _check("a name the target does not have is skipped instead of crashing",
		partial.get("damage"), null) and ok

	source_node.free()
	target_node.free()
	blank_target.free()
	partial.free()
	return ok


static func _test_fill_blanks_runtime() -> bool:
	var actor_script: GDScript = _script("@tool\nextends Node\n\nvar speed: float = 0.0\nvar label: String = \"\"\nvar tags: Array = []\nvar note = null\n")
	if actor_script == null:
		return _check("the fill-blanks sample script compiles", false, true)

	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func fill(target: Object, base: Object) -> void:",
		_indent(_fill("FillBlanksFrom", {"target": "target", "base": "base"}), 1),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the Fill Blanks From template assembles into a script", false, true)

	var base: Node = _node(actor_script, {"speed": 99.0, "label": "from base", "tags": ["x"], "note": "base note"})
	var target: Node = _node(actor_script, {"speed": 3.0, "label": "", "tags": [], "note": null})
	instance.call("fill", target, base)
	var ok: bool = _check("a value already filled in is left alone", float(target.get("speed")), 3.0)
	ok = _check("empty text is filled from the base", str(target.get("label")), "from base") and ok
	ok = _check("an empty list is filled from the base", target.get("tags"), ["x"]) and ok
	ok = _check("a null field is filled from the base", str(target.get("note")), "base note") and ok

	# Running it again changes nothing: everything is filled now.
	instance.call("fill", target, base)
	ok = _check("filling twice is stable", float(target.get("speed")), 3.0) and ok
	base.free()
	target.free()

	# THE boundary the row help now states out loud, and the one a variant author will meet: a 0 and
	# a false are REAL values, so a field left at its numeric default is NOT filled from the base.
	# It reads the same way as Is Nothing and Missing Fields, which is the whole point of saying it.
	var flags_script: GDScript = _script("@tool\nextends Node\n\nvar damage: int = 0\nvar charges: float = 0.0\nvar equipped: bool = false\nvar label: String = \"\"\n")
	if flags_script == null:
		return _check("the zero-boundary sample script compiles", false, true) and ok
	var tuned: Node = _node(flags_script, {"damage": 12, "charges": 2.5, "equipped": true, "label": "base"})
	var variant: Node = _node(flags_script, {"damage": 0, "charges": 0.0, "equipped": false, "label": ""})
	instance.call("fill", variant, tuned)
	ok = _check("a whole number left at 0 is a real value and is kept", int(variant.get("damage")), 0) and ok
	ok = _check("a decimal left at 0.0 is kept too", float(variant.get("charges")), 0.0) and ok
	ok = _check("a switch left off is kept", bool(variant.get("equipped")), false) and ok
	ok = _check("while blank text really is blank and IS filled", str(variant.get("label")), "base") and ok
	tuned.free()
	variant.free()
	return ok


static func _test_apply_preset_runtime() -> bool:
	var preset_script: GDScript = _script("@tool\nextends Resource\n\n@export var speed: float = 12.0\n@export var damage: int = 6\n@export var only_on_preset: String = \"ignored\"\n")
	var actor_script: GDScript = _script("@tool\nextends Node\n\nvar speed: float = 0.0\nvar damage: int = 0\n")
	if preset_script == null or actor_script == null:
		return _check("the preset sample scripts compile", false, true)

	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func apply(preset, target: Object) -> void:",
		_indent(_fill("ApplyPresetToNode", {"preset": "preset", "target": "target"}), 1),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the Apply Preset To Node template assembles into a script", false, true)

	var preset: Resource = preset_script.new()
	var node: Node = _node(actor_script, {"speed": 0.0, "damage": 0})
	instance.call("apply", preset, node)
	var ok: bool = _check("the preset's value lands on the node", float(node.get("speed")), 12.0)
	ok = _check("a second preset field lands too", int(node.get("damage")), 6) and ok
	ok = _check("a preset field the node does not have is skipped", node.get("only_on_preset"), null) and ok

	# An unfilled preset slot is the common Inspector case: nothing happens, nothing crashes.
	instance.call("apply", null, node)
	ok = _check("an empty preset leaves the node exactly as it was", float(node.get("speed")), 12.0) and ok
	node.free()
	return ok


static func _test_matches_properties_runtime() -> bool:
	var actor_script: GDScript = _script("@tool\nextends Node\n\nvar speed: float = 0.0\nvar damage: int = 0\n")
	if actor_script == null:
		return _check("the matches-properties sample script compiles", false, true)

	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func matches(target: Object, other: Object, names: String) -> bool:",
		"\treturn %s" % _fill("MatchesPropertiesOf", {"target": "target", "other": "other", "names": "names"}),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the Matches Properties Of template assembles into a script", false, true)

	var a: Node = _node(actor_script, {"speed": 4.0, "damage": 2})
	var b: Node = _node(actor_script, {"speed": 4.0, "damage": 2})
	var ok: bool = _check("two objects holding the same values match",
		bool(instance.call("matches", a, b, "speed, damage")), true)
	b.set("damage", 3)
	ok = _check("one differing property is enough to stop matching",
		bool(instance.call("matches", a, b, "speed, damage")), false) and ok
	ok = _check("the unlisted difference is ignored when the list does not name it",
		bool(instance.call("matches", a, b, "speed")), true) and ok
	ok = _check("a blank list has nothing to compare, so it matches",
		bool(instance.call("matches", a, b, "")), true) and ok

	# THE failure this condition must not have: Object.get() answers null for a property that is not
	# there, so comparing a name NEITHER object has used to compare null to null and report "still in
	# sync" - the safest-looking answer, and the wrong one, for a typo or a field somebody renamed.
	b.set("damage", 2)
	ok = _check("two objects really are in sync again",
		bool(instance.call("matches", a, b, "speed, damage")), true) and ok
	ok = _check("a name NEITHER object has does not quietly pass",
		bool(instance.call("matches", a, b, "ghost_prop")), false) and ok
	ok = _check("and one misspelled name in a good list is enough to report a mismatch",
		bool(instance.call("matches", a, b, "speed, dmaage")), false) and ok
	# A name only ONE side has is a mismatch too - the pouring verbs skip it, the comparison says so.
	var lopsided: GDScript = _script("@tool\nextends Node\n\nvar speed: float = 0.0\n")
	var partial: Node = _node(lopsided, {"speed": 4.0})
	ok = _check("a name the other side lacks reads as not matching",
		bool(instance.call("matches", a, partial, "speed, damage")), false) and ok
	ok = _check("while the names they share still compare",
		bool(instance.call("matches", a, partial, "speed")), true) and ok
	partial.free()
	# "The ghost was freed" is exactly when this gets asked, so neither side may fault on nothing.
	ok = _check("a missing object reads as not matching rather than faulting",
		bool(instance.call("matches", a, null, "speed")), false) and ok
	ok = _check("and so does a missing object under test",
		bool(instance.call("matches", null, a, "speed")), false) and ok
	a.free()
	b.free()
	return ok


# ── #24 Data Is Older Than Version / Rename Field / Stamp Data Version ──────────────────────────
static func _test_migration_emission() -> bool:
	var sheet: EventSheetResource = _sheet()
	var row: EventRow = _row()
	row.conditions.append(_condition("DataIsOlderThanVersion", {"record": "save", "field": "\"version\"", "version": "3"}))
	row.actions.append(_action("RenameField", {"record": "save", "from_field": "\"hp\"", "to_field": "\"health\""}))
	row.actions.append(_action("StampDataVersion", {"record": "save", "field": "\"version\"", "version": "3"}))
	sheet.events.append(row)
	var output: String = _compile(sheet, "user://eventforge_res_migrate_emit.gd")
	# str().to_int() rather than int(): Dictionary.get falls back only on a MISSING key, so a payload
	# carrying "version": null reached int(null), which is a runtime error - and the gate that makes
	# old data safe is the one that must not fault. Pinned as the shipped shape.
	var ok: bool = _check("Data Is Older Than Version emits a fault-proof number read with 0 as the missing-field default",
		output.contains("(str(save.get(\"version\", 0)).to_int() < 3)"), true)
	ok = _check("Rename Field emits the guarded move-then-erase",
		output.contains("\t\tif save.has(\"hp\"):\n\t\t\tsave[\"health\"] = save[\"hp\"]\n\t\t\tsave.erase(\"hp\")"), true) and ok
	# A PLAIN subscript write, deliberately. Wrapping the number in int() gave this template more
	# literal characters than Set Key's, and the reverse-lifter sorts on exactly that - so every
	# hand-written `config["count"] = int(text_value)` in a user's project was re-labelled as
	# "stamp this record as version text_value". The next check is that regression's own guard.
	ok = _check("Stamp Data Version emits a plain subscript write",
		output.contains("\t\tsave[\"version\"] = 3"), true) and ok
	var entries: Array = EventSheetACELifter._build_reverse_entries()
	var stolen: Dictionary = EventSheetACELifter._match_entry("config[\"count\"] = int(text_value)", entries, "action")
	ok = _check("so an ordinary int-cast record write is still read as Set Key, not as a version stamp",
		str(stolen.get("ace_id", "")), "DictSetKey") and ok
	ok = _check("and it keeps the whole expression as the value it wrote",
		str((stolen.get("params", {}) as Dictionary).get("value", "")), "int(text_value)") and ok
	return ok


static func _test_migration_runtime() -> bool:
	var source: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func older(record: Dictionary, field: String, version: int) -> bool:",
		"\treturn %s" % _fill("DataIsOlderThanVersion", {"record": "record", "field": "field", "version": "version"}),
		"func rename(record: Dictionary, from_field: String, to_field: String) -> void:",
		_indent(_fill("RenameField", {"record": "record", "from_field": "from_field", "to_field": "to_field"}), 1),
		"func stamp(record: Dictionary, field: String, version) -> void:",
		_indent(_fill("StampDataVersion", {"record": "record", "field": "field", "version": "version"}), 1),
		"",
	])
	var instance: RefCounted = _instance(source)
	if instance == null:
		return _check("the migration templates assemble into a script", false, true)

	# The promise on the tin: no version field at all counts as 0, so the FIRST format upgrades too.
	var ok: bool = _check("a record with no version field is older than version 3",
		bool(instance.call("older", {"hp": 5}, "version", 3)), true)
	ok = _check("a record already at the current version is not older",
		bool(instance.call("older", {"version": 3}, "version", 3)), false) and ok
	ok = _check("a record from an older build is older",
		bool(instance.call("older", {"version": 1}, "version", 3)), true) and ok
	ok = _check("a newer record is not treated as older",
		bool(instance.call("older", {"version": 4}, "version", 3)), false) and ok
	# JSON hands numbers back as text or floats; the int read copes with both.
	ok = _check("a version stored as text still compares as a number",
		bool(instance.call("older", {"version": "1"}, "version", 3)), true) and ok
	ok = _check("a version stored as a float still compares as a number",
		bool(instance.call("older", {"version": 3.0}, "version", 3)), false) and ok
	# The field PRESENT but empty is not the same as the field missing, and Dictionary.get does not
	# fall back on it. A payload with "version": null used to take the whole gate down with a runtime
	# error; it now reads as 0, which is the same answer as "no version field at all".
	ok = _check("a version field written but never filled counts as oldest",
		bool(instance.call("older", {"version": null}, "version", 3)), true) and ok
	ok = _check("a version field holding a word counts as oldest too",
		bool(instance.call("older", {"version": "unknown"}, "version", 3)), true) and ok
	ok = _check("an empty version field counts as oldest",
		bool(instance.call("older", {"version": ""}, "version", 3)), true) and ok

	var record: Dictionary = {"hp": 5, "room": "cave"}
	instance.call("rename", record, "hp", "health")
	ok = _check("Rename Field moves the value to its new name", int(record.get("health", -1)), 5) and ok
	ok = _check("Rename Field removes the old name", record.has("hp"), false) and ok
	ok = _check("Rename Field leaves the rest of the record alone", str(record.get("room", "")), "cave") and ok
	# Safe to run twice: the old name is gone, so the second run must change nothing.
	instance.call("rename", record, "hp", "health")
	ok = _check("running the same rename again changes nothing", int(record.get("health", -1)), 5) and ok
	var untouched: Dictionary = {"room": "cave"}
	instance.call("rename", untouched, "hp", "health")
	ok = _check("renaming a field that was never there adds nothing", untouched.has("health"), false) and ok

	instance.call("stamp", record, "version", 3)
	ok = _check("Stamp Data Version writes the number", int(record.get("version", -1)), 3) and ok
	ok = _check("a whole number is stored as one", typeof(record.get("version")), TYPE_INT) and ok
	ok = _check("Stamp Data Version leaves the rest of the record alone", int(record.get("health", -1)), 5) and ok
	ok = _check("the stamped record is no longer older than that version",
		bool(instance.call("older", record, "version", 3)), false) and ok
	# The write is a plain subscript, so it stores whatever it is given - and the READ side is what
	# makes the pair work regardless: a float or a text version still compares as the number it is.
	instance.call("stamp", record, "version", 4.0)
	ok = _check("a float version is stored as given", typeof(record.get("version")), TYPE_FLOAT) and ok
	ok = _check("and the gate still reads it correctly",
		bool(instance.call("older", record, "version", 4)), false) and ok
	instance.call("stamp", record, "version", "5")
	ok = _check("a text version is read as the number it holds",
		bool(instance.call("older", record, "version", 5)), false) and ok
	ok = _check("and still counts as older than the build after it",
		bool(instance.call("older", record, "version", 6)), true) and ok
	return ok


# ── Helpers ─────────────────────────────────────────────────────────────────────────────────────
## The SHIPPED descriptor's template with the given params substituted through the REAL codegen -
## every param not named here falls back to its shipped default, exactly as the dock bakes a row.
static func _fill(ace_id: String, values: Dictionary, uid: String = "t") -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return "<missing %s>" % ace_id
	var params: Dictionary = {"uid": uid}
	for parameter: ACEParam in descriptor.params:
		params[parameter.id] = str(values.get(parameter.id, parameter.default_value))
	return ActionCodegen._apply_template(str(descriptor.codegen_template), params)


static func _action(ace_id: String, values: Dictionary, uid: String = "t") -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = _fill(ace_id, values, uid)
	return action


static func _condition(ace_id: String, values: Dictionary, uid: String = "t") -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.codegen_template = _fill(ace_id, values, uid)
	return condition


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	return sheet


static func _row() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	return row


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


## Indents every line of a (possibly multi-line) statement block, so an action template drops into a
## harness function body the same way the compiler drops it into a trigger body.
static func _indent(block: String, levels: int) -> String:
	var pad: String = ""
	for i: int in range(levels):
		pad += "\t"
	var out: PackedStringArray = PackedStringArray()
	for line: String in block.split("\n"):
		out.append(pad + line)
	return "\n".join(out)


static func _script(source: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  sample script failed to reload:\n%s" % source)
		return null
	return script


static func _instance(source: String) -> RefCounted:
	var script: GDScript = _script(source)
	if script == null:
		print("  assembled template script:\n%s" % source)
		return null
	return script.new()


static func _node(script: GDScript, values: Dictionary) -> Node:
	var node: Node = Node.new()
	node.set_script(script)
	for key: String in values:
		node.set(key, values[key])
	return node


## Writes a real .tres to disk whose one distinguishing value is readable back after a load.
static func _save_curve(path: String, resolution: int) -> void:
	var curve: Curve = Curve.new()
	curve.bake_resolution = resolution
	ResourceSaver.save(curve, path)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] resource_aces_test: %s" % label)
		return true
	print("[FAIL] resource_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
