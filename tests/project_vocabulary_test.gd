# EventSheet - the project's own code as pickable vocabulary (interop P1b). Pins the VALUES
# that decide whether a user's script is usable with zero setup: a real project class
# reflects into typed verbs from its SCRIPT (never an instance), the emitted call is the
# plain one a human would write, an autoload emits through its singleton name while a plain
# class stays retargetable, the two shapes are cached apart, and the curated vocabulary is
# never shadowed.
@tool
class_name ProjectVocabularyTest
extends RefCounted

const TEMP_DIR: String = "res://.eventsheets_vocab_test"
const TEMP_SCRIPT: String = TEMP_DIR + "/scratch_vocab_source.gd"


static func run() -> bool:
	var ok: bool = true

	# ── The member-access prefix (static + pure) ──
	ok = _check("no singleton keeps the retargetable marker",
		EventSheetClassDBSource.member_prefix(""), "{target.}") and ok
	ok = _check("a singleton emits through its own name",
		EventSheetClassDBSource.member_prefix("GameState"), "GameState.") and ok
	ok = _check("whitespace is not a singleton",
		EventSheetClassDBSource.member_prefix("   "), "{target.}") and ok

	# ── A REAL project class reflects into verbs, from the script alone ──
	# The fixture is written to disk because reflection reads the script, and a class the
	# global class list does not know cannot be resolved - so this also proves the path a
	# user's own script takes.
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var file: FileAccess = FileAccess.open(TEMP_SCRIPT, FileAccess.WRITE)
	file.store_string("\n".join(PackedStringArray([
		"class_name ScratchVocabSource",
		"extends Node",
		"",
		"",
		"signal restocked",
		"",
		"@export var slot_count: int = 8",
		"",
		"",
		"func add_item(item_id: String, count: int) -> void:",
		"\tpass",
		"",
		"",
		"func has_item(item_id: String) -> bool:",
		"\treturn false",
		"",
		"",
		"func total_weight() -> float:",
		"\treturn 0.0",
		"",
		"",
		"func _private_helper() -> void:",
		"\tpass",
	])))
	file.close()

	# Reflect straight off the SCRIPT: this is the derivation the picker uses, and it must
	# work without ever instantiating (a non-@tool script cannot instantiate in-editor).
	var script: Script = load(TEMP_SCRIPT) as Script
	var kinds: Dictionary = {}
	var templates: Dictionary = {}
	for method_info: Dictionary in script.get_script_method_list():
		var member: String = str(method_info.get("name", ""))
		if member.begins_with("_"):
			continue
		var definition: ACEDefinition = EventSheetClassDBSource._method_definition("ScratchVocabSource", method_info)
		if definition != null:
			kinds[member] = definition.ace_type
			templates[member] = str(definition.metadata.get("codegen_template", ""))
	ok = _check("a void method reflects as an Action",
		kinds.get("add_item"), ACEDefinition.ACEType.ACTION) and ok
	ok = _check("a bool method reflects as a Condition",
		kinds.get("has_item"), ACEDefinition.ACEType.CONDITION) and ok
	ok = _check("a value method reflects as an Expression",
		kinds.get("total_weight"), ACEDefinition.ACEType.EXPRESSION) and ok
	ok = _check("a private method never reflects", kinds.has("_private_helper"), false) and ok
	ok = _check("the emitted call is the plain one a human would write",
		templates.get("add_item"), "{target.}add_item({item_id}, {count})") and ok

	# ── Autoload shape: the singleton name replaces the target marker ──
	var singleton_templates: Dictionary = {}
	for method_info: Dictionary in script.get_script_method_list():
		var definition: ACEDefinition = EventSheetClassDBSource._method_definition(
			"ScratchVocabSource", method_info, "Inventory")
		if definition != null:
			singleton_templates[str(method_info.get("name", ""))] = str(definition.metadata.get("codegen_template", ""))
	ok = _check("an autoload emits through its singleton name",
		singleton_templates.get("add_item"), "Inventory.add_item({item_id}, {count})") and ok
	ok = _check("the singleton shape carries no target parameter (it is reached by name)",
		str(singleton_templates.get("has_item", "")).contains("{target"), false) and ok

	# ── The two shapes cache APART (a prefix must not poison the plain set) ──
	var plain_first: Array = EventSheetClassDBSource.definitions_for_class("Timer")
	var singleton_set: Array = EventSheetClassDBSource.definitions_for_class("Timer", "GameClock")
	var plain_again: Array = EventSheetClassDBSource.definitions_for_class("Timer")
	ok = _check("the plain set is unchanged after a prefixed reflection of the same class",
		plain_again.size(), plain_first.size()) and ok
	var plain_has_marker: bool = false
	var singleton_has_marker: bool = false
	for definition: ACEDefinition in plain_again:
		if str(definition.metadata.get("codegen_template", "")).begins_with("{target.}"):
			plain_has_marker = true
	for definition: ACEDefinition in singleton_set:
		if str(definition.metadata.get("codegen_template", "")).begins_with("{target.}"):
			singleton_has_marker = true
	ok = _check("the plain set keeps the retargetable marker", plain_has_marker, true) and ok
	ok = _check("the singleton set never carries the retargetable marker", singleton_has_marker, false) and ok

	# ── The curated vocabulary is never shadowed by reflection ──
	var duplicate_curated: bool = false
	for definition: ACEDefinition in EventSheetClassDBSource.definitions_for_class("Node"):
		if str(definition.metadata.get("codegen_template", "")) == "{target.}queue_free()":
			duplicate_curated = true
	ok = _check("a member a curated verb already covers is filtered out", duplicate_curated, false) and ok

	DirAccess.remove_absolute(TEMP_SCRIPT)
	DirAccess.remove_absolute(TEMP_DIR)
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] project_vocabulary_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
