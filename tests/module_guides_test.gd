# Godot EventSheets - the built-in module guides (docs/Modules/): the same standard the addon
# guides are held to, applied to the vocabulary that ships in the picker before a single pack
# is enabled.
#
# Four gates, in the order a guide rots:
#   1. MAPPING + SWEEP  every vocabulary module resolves to a guide file that exists, so a
#      renamed guide (or a new module nobody documented) fails here instead of shipping a dead
#      "module:<name>" doc id.
#   2. SHAPE            fifteen or more numbered use cases, and exactly five bolded "Other use
#      cases" lines - the shape docs/Addons guides are written to.
#   3. VOCABULARY       every verb named in a guide's reference table exists in the LIVE
#      registry. This is the one that catches a rename: the doc cannot invent a verb, and a
#      shipped verb that changes its display name takes its guide row down with it.
#   4. HOUSE RULES      no em-dashes, and nothing unindexed.
@tool
class_name ModuleGuidesTest
extends RefCounted

const GUIDE_DIR := "res://docs/Modules"
const GUIDE_INDEX := "res://docs/Modules/README.md"
const DOCS_INDEX := "res://docs/README.md"

## The reference tables are markdown tables whose first column header is exactly this. Anything
## else in a guide (a comparison table, a parameter table) is not a verb list and is not swept.
const VERB_COLUMN := "Verb"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_guide_mapping() and all_passed
	all_passed = _test_module_sweep() and all_passed
	all_passed = _test_guide_shape() and all_passed
	all_passed = _test_verbs_exist() and all_passed
	all_passed = _test_house_rules() and all_passed
	return all_passed


## The derivation mirrors the addon one: an override wins, otherwise Title-Case-Words, and a
## unit key folds a module file name and a picker category onto the same lookup.
static func _test_guide_mapping() -> bool:
	var all_passed: bool = true
	all_passed = _check("a module file resolves to its guide",
		EventSheets.module_guide_target("system_aces.gd"), "docs/Modules/Timers-Waiting-And-Cooldowns.md") and all_passed
	all_passed = _check("a full module path resolves the same way",
		EventSheets.module_guide_target("res://addons/eventforge/registration/modules/tilemap_aces.gd"),
		"docs/Modules/Working-With-Tilemaps.md") and all_passed
	all_passed = _check("a picker category resolves too - punctuation and all",
		EventSheets.module_guide_target("Variables: Vector"), "docs/Modules/Working-With-Vectors-And-Directions.md") and all_passed
	all_passed = _check("a category with an ampersand folds to one key",
		EventSheets.module_guide_name("Math & Random"), "Doing-Math-And-Randomness") and all_passed
	all_passed = _check("the two casting guides are told apart by category",
		EventSheets.module_guide_name("Raycast 3D"), "Raycasting-And-Overlaps-In-3D") and all_passed
	all_passed = _check("a path folds to its unit key",
		EventSheets.module_guide_unit("res://addons/eventforge/registration/modules/native_3d_aces.gd"), "native_3d") and all_passed
	all_passed = _check("an undocumented unit still derives a name, acronyms intact",
		EventSheets.module_guide_name("widget_3d"), "Widget-3D") and all_passed
	all_passed = _check("an empty unit has no guide", EventSheets.module_guide_target(""), "") and all_passed
	return all_passed


## THE drift gate. Every vocabulary module on disk must resolve to a guide that ships - the same
## sweep docs_links_test runs over the pack directories.
static func _test_module_sweep() -> bool:
	var all_passed: bool = true
	var missing: PackedStringArray = PackedStringArray()
	var units: PackedStringArray = EventSheets.module_guide_units()
	for unit: String in units:
		var target: String = EventSheets.module_guide_target(unit)
		if not FileAccess.file_exists("res://" + target):
			missing.append("%s -> %s" % [unit, target])
	all_passed = _check("every vocabulary module resolves to a guide that ships", ", ".join(missing), "") and all_passed
	all_passed = _check("the sweep actually saw the modules", units.size() > 40, true) and all_passed
	# The detector must be able to fail: a module nobody documented resolves to a path that is not
	# there, which is exactly what the sweep above reports.
	all_passed = _check("the sweep would catch an undocumented module",
		FileAccess.file_exists("res://" + EventSheets.module_guide_target("no_such_module_here")), false) and all_passed
	return all_passed


## The docs/Addons shape: fifteen or more numbered use cases, and exactly five bolded lines under
## "Other use cases".
static func _test_guide_shape() -> bool:
	var all_passed: bool = true
	var thin: PackedStringArray = PackedStringArray()
	var wrong_tail: PackedStringArray = PackedStringArray()
	for guide: String in _guide_files():
		var text: String = FileAccess.get_file_as_string(GUIDE_DIR.path_join(guide))
		var numbered: int = 0
		var other: int = 0
		var in_other: bool = false
		for line: String in text.split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.ends_with("Other use cases"):
				in_other = true
				continue
			if stripped.begins_with("## ") and in_other:
				in_other = false
			if not stripped.begins_with("**"):
				continue
			if in_other:
				other += 1
			elif _numbered_use_case(stripped):
				numbered += 1
		if numbered < 15:
			thin.append("%s has %d" % [guide, numbered])
		if other != 5:
			wrong_tail.append("%s has %d" % [guide, other])
	all_passed = _check("every guide carries 15 or more numbered use cases", ", ".join(thin), "") and all_passed
	all_passed = _check("every guide closes with exactly five other use cases", ", ".join(wrong_tail), "") and all_passed
	return all_passed


## A numbered use case opens its paragraph as `**3. Something.**`.
static func _numbered_use_case(line: String) -> bool:
	var head: String = line.trim_prefix("**")
	var digits: String = ""
	for index: int in head.length():
		if not head[index].is_valid_int():
			break
		digits += head[index]
	return not digits.is_empty() and head.substr(digits.length()).begins_with(". ")


## No guide may invent vocabulary. Every verb named in a reference table is looked up in the LIVE
## registry, so a renamed or removed verb fails here rather than sending a reader to a picker
## entry that is not called that any more.
static func _test_verbs_exist() -> bool:
	var all_passed: bool = true
	var known: Dictionary = _registry_display_names()
	var unknown: PackedStringArray = PackedStringArray()
	var swept: int = 0
	for guide: String in _guide_files():
		for verb: String in _reference_verbs(FileAccess.get_file_as_string(GUIDE_DIR.path_join(guide))):
			swept += 1
			if known.has(verb):
				continue
			# A display name shared by two verbs is disambiguated in the table by the section it
			# belongs to - "Save Setting (Game Options)" - so the qualifier comes off before the
			# name is called unknown.
			var bare: String = verb.substr(0, verb.rfind(" (")).strip_edges() if verb.ends_with(")") and verb.contains(" (") else verb
			if not known.has(bare):
				unknown.append("%s: %s" % [guide, verb])
	all_passed = _check("every verb in a reference table exists in the registry", ", ".join(unknown), "") and all_passed
	all_passed = _check("the reference tables were actually read", swept > 900, true) and all_passed
	all_passed = _check("the lookup can say no", known.has("No Such Verb Here"), false) and all_passed
	return all_passed


## Display name -> true for every built-in verb, straight from the registry.
static func _registry_display_names() -> Dictionary:
	var names: Dictionary = {}
	for descriptor: ACEDescriptor in ACERegistry.get_builtin_descriptors():
		names[descriptor.display_name] = true
	return names


## The first column of every markdown table headed `| Verb | … |`, with bold and code decoration
## stripped. A table with any other first header is not a verb reference and is skipped.
static func _reference_verbs(text: String) -> PackedStringArray:
	var verbs: PackedStringArray = PackedStringArray()
	var in_table: bool = false
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.begins_with("|"):
			in_table = false
			continue
		var first_cell: String = stripped.trim_prefix("|").get_slice("|", 0).strip_edges()
		if first_cell == VERB_COLUMN:
			in_table = true
			continue
		if not in_table:
			continue
		if first_cell.is_empty() or first_cell.lstrip("-: ").is_empty():
			continue  # the header separator row
		verbs.append(first_cell.replace("**", "").replace("`", "").strip_edges())
	return verbs


## House rules: plain " - " instead of em-dashes, no unindexed guide, and the documentation index
## points at the new group.
static func _test_house_rules() -> bool:
	var all_passed: bool = true
	var em_dash: String = String.chr(0x2014)
	var dashed: PackedStringArray = PackedStringArray()
	var unlisted: PackedStringArray = PackedStringArray()
	var index: String = FileAccess.get_file_as_string(GUIDE_INDEX)
	for guide: String in _guide_files():
		var text: String = FileAccess.get_file_as_string(GUIDE_DIR.path_join(guide))
		if text.contains(em_dash):
			dashed.append(guide)
		if not index.contains("(%s)" % guide):
			unlisted.append(guide)
	if index.contains(em_dash):
		dashed.append("README.md")
	all_passed = _check("no module guide uses an em-dash", ", ".join(dashed), "") and all_passed
	all_passed = _check("every module guide is listed in the module index", ", ".join(unlisted), "") and all_passed
	var docs_index: String = FileAccess.get_file_as_string(DOCS_INDEX)
	all_passed = _check("the documentation index carries the built-in vocabulary group",
		docs_index.contains("## Built-in vocabulary") and docs_index.contains("(Modules/README.md)"), true) and all_passed
	return all_passed


## Every shipped guide file, sorted. The index page is NOT one of them - it carries no use cases
## and no verb tables, so it is checked separately (for em-dashes, and for listing the rest).
static func _guide_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(GUIDE_DIR):
		if file_name.ends_with(".md") and file_name != "README.md":
			files.append(file_name)
	files.sort()
	return files


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] module_guides_test: %s" % label)
		return true
	print("[FAIL] module_guides_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
