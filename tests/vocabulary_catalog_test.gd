# EventSheet - the vocabulary override catalog (interop P3). The headline assertion is the
# DELETE-SAFETY property the whole design rests on: removing the catalog restores the
# inferred vocabulary with every id and every emitted call byte-identical, so a project that
# loses the file keeps compiling exactly the same. Also pins the resolution order (source
# annotations outrank the catalog), the immutability rule (shared definitions are never
# mutated), and each refinement by value.
@tool
class_name VocabularyCatalogTest
extends RefCounted

const SCRATCH_PATH: String = "user://scratch_vocabulary_catalog.tres"


static func run() -> bool:
	var ok: bool = true
	EventSheetVocabularyCatalog.reset_for_tests(SCRATCH_PATH)

	ok = _check("the key shape is the provider::ace pair",
		EventSheetVocabularyCatalog.key_for("Enemy", "method:take_damage"), "Enemy::method:take_damage") and ok

	# A reflected set to refine (the real reflection path, not a fabricated one).
	var source: Array = EventSheetClassDBSource.definitions_for_class("Node")
	ok = _check("the reflected source is non-empty", source.size() > 0, true) and ok
	var sample: ACEDefinition = null
	for definition: ACEDefinition in source:
		if definition.id == "method:add_to_group":
			sample = definition
	ok = _check("a known reflected verb is present", sample != null, true) and ok
	if sample == null:
		return false
	var original_name: String = sample.display_name
	var original_template: String = str(sample.metadata.get("codegen_template", ""))

	# ── No catalog: the set passes through untouched, by reference ──
	var untouched: Array[ACEDefinition] = EventSheetVocabularyCatalog.apply(source)
	ok = _check("with no overrides every definition passes through", untouched.size(), source.size()) and ok
	ok = _check("pass-through does not copy (same shared instance)", untouched[0] == source[0], true) and ok

	# ── Rename + recategorize ──
	EventSheetVocabularyCatalog.set_override("Node", "method:add_to_group",
		{"display_name": "Tag As", "category": "Tagging"})
	var refined: Array[ACEDefinition] = EventSheetVocabularyCatalog.apply(source)
	var renamed: ACEDefinition = _find(refined, "method:add_to_group")
	ok = _check("the override renames the verb", renamed.display_name, "Tag As") and ok
	ok = _check("the override recategorizes the verb", renamed.category, "Tagging") and ok
	# The sentence leads with the display name, so a rename must carry into it.
	ok = _check("the row sentence follows the rename",
		str(renamed.metadata.get("display_template", "")).begins_with("Tag As"), true) and ok
	ok = _check("the emitted call is NEVER changed by a rename",
		str(renamed.metadata.get("codegen_template", "")), original_template) and ok
	ok = _check("the id is NEVER changed by a rename", renamed.id, "method:add_to_group") and ok
	# Immutability: the shared cached definition must not have been touched.
	ok = _check("the shared definition is not mutated", sample.display_name, original_name) and ok

	# ── Hiding one verb, and excluding a whole class ──
	EventSheetVocabularyCatalog.set_override("Node", "method:add_to_group", {"hidden": true})
	ok = _check("a hidden verb is dropped",
		_find(EventSheetVocabularyCatalog.apply(source), "method:add_to_group") == null, true) and ok
	EventSheetVocabularyCatalog.set_override("Node", "method:add_to_group", {"hidden": null})
	ok = _check("clearing an override restores the verb",
		_find(EventSheetVocabularyCatalog.apply(source), "method:add_to_group") != null, true) and ok
	EventSheetVocabularyCatalog.set_class_excluded("Node", true)
	ok = _check("an excluded class offers nothing",
		EventSheetVocabularyCatalog.apply(source).size(), 0) and ok
	EventSheetVocabularyCatalog.set_class_excluded("Node", false)
	ok = _check("restoring a class brings its verbs back",
		EventSheetVocabularyCatalog.apply(source).size(), source.size()) and ok

	# ── Resolution order: source annotations outrank the catalog ──
	var annotated: ACEDefinition = ACEDefinition.new()
	annotated.provider_id = "Node"
	annotated.id = "method:add_to_group"
	annotated.display_name = "Authored Name"
	annotated.metadata = {"codegen_template": "x()"}  # no "reflected" mark = it came from source
	EventSheetVocabularyCatalog.set_override("Node", "method:add_to_group", {"display_name": "Catalog Name"})
	var mixed: Array[ACEDefinition] = EventSheetVocabularyCatalog.apply([annotated])
	ok = _check("an annotated verb ignores the catalog", mixed[0].display_name, "Authored Name") and ok

	# ── THE GATE: deleting the catalog changes nothing structural ──
	var before_ids: Array = []
	var before_templates: Array = []
	for definition: ACEDefinition in EventSheetVocabularyCatalog.apply(source):
		before_ids.append("%s::%s" % [definition.provider_id, definition.id])
		before_templates.append(str(definition.metadata.get("codegen_template", "")))
	# Delete the file the way a user would, and forget the in-memory copy.
	if ResourceLoader.exists(SCRATCH_PATH):
		DirAccess.remove_absolute(SCRATCH_PATH)
	EventSheetVocabularyCatalog.reset_for_tests(SCRATCH_PATH)
	var after_ids: Array = []
	var after_templates: Array = []
	for definition: ACEDefinition in EventSheetVocabularyCatalog.apply(source):
		after_ids.append("%s::%s" % [definition.provider_id, definition.id])
		after_templates.append(str(definition.metadata.get("codegen_template", "")))
	ok = _check("deleting the catalog keeps every verb id", after_ids, before_ids) and ok
	ok = _check("deleting the catalog keeps every emitted call", after_templates, before_templates) and ok

	# ── Persistence round-trip: an override survives a reload from disk ──
	EventSheetVocabularyCatalog.set_override("Node", "method:add_to_group", {"display_name": "Persisted"})
	EventSheetVocabularyCatalog.reset_for_tests(SCRATCH_PATH)  # forces a load from disk
	ok = _check("an override survives a reload",
		_find(EventSheetVocabularyCatalog.apply(source), "method:add_to_group").display_name, "Persisted") and ok
	# Emptying the catalog removes the file rather than leaving an empty artifact.
	EventSheetVocabularyCatalog.set_override("Node", "method:add_to_group", {"display_name": null})
	ok = _check("an emptied catalog deletes its file", ResourceLoader.exists(SCRATCH_PATH), false) and ok

	EventSheetVocabularyCatalog.reset_for_tests()
	return ok


static func _find(definitions: Array, ace_id: String) -> ACEDefinition:
	for definition: ACEDefinition in definitions:
		if definition.id == ace_id:
			return definition
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] vocabulary_catalog_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
