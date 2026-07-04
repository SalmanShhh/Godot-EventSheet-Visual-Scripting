# Godot EventSheets - featured ACEs (the everyday-verb highlight).
#
# The picker renders featured verbs bold and floats them to the top of their category,
# so the out-of-box vocabulary leads with intentions (wait, spawn, destroy, play, move)
# instead of statements. Three sources feed one flag: the picker's curated Core FEATURED
# const (typo-gated here against the live registry), a built-in descriptor's .featured()
# chainable, and an addon's ## @ace_featured annotation - the latter two arrive through
# definition metadata.
@tool
class_name FeaturedACEsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# Typo gate: every curated key must resolve in the real builtin registry - a renamed
	# or misspelled id would otherwise silently unfeature the verb.
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var missing: PackedStringArray = PackedStringArray()
	for key: Variant in ACEPickerDialog.FEATURED:
		var parts: PackedStringArray = str(key).split("/")
		if registry.find_definition(parts[0], parts[1]) == null:
			missing.append(str(key))
	ok = _check("every curated FEATURED key resolves in the registry", ", ".join(missing), "") and ok

	# The metadata channel: .featured() on a built-in descriptor flows through the adapter.
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = "Demo"
	descriptor.ace_id = "Dash"
	descriptor.featured()
	var adapted: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(descriptor)
	ok = _check(".featured() flows through the adapter", bool(adapted.metadata.get("featured", false)), true) and ok

	# ## @ace_featured on an addon member flows through the generator. The analyzer reads
	# annotations from the script's FILE (resource_path), so the fixture goes to user://.
	var fixture_path: String = "user://featured_provider_fixture.gd"
	var fixture_file: FileAccess = FileAccess.open(fixture_path, FileAccess.WRITE)
	fixture_file.store_string("\n".join(PackedStringArray([
		"@tool",
		"extends RefCounted",
		"",
		"",
		"## @ace_action",
		"## @ace_featured",
		"func boost(amount: int) -> void:",
		"\tpass",
		"",
		"",
		"## @ace_action",
		"func plain(amount: int) -> void:",
		"\tpass",
		"",
	])))
	fixture_file.close()
	var provider_script: GDScript = load(fixture_path) as GDScript
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var featured_flag: bool = false
	var plain_flag: bool = true
	for definition: ACEDefinition in generator.generate_from_object(provider_script.new()):
		if definition.id == "method:boost":
			featured_flag = bool(definition.metadata.get("featured", false))
		elif definition.id == "method:plain":
			plain_flag = bool(definition.metadata.get("featured", false))
	ok = _check("@ace_featured flows through the generator", featured_flag, true) and ok
	ok = _check("unannotated members stay unfeatured", plain_flag, false) and ok

	# The picker treats both sources as featured.
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	ok = _check("the picker features metadata-flagged verbs", picker._is_featured(adapted), true) and ok
	ok = _check("the picker features curated Core verbs",
		picker._is_featured(registry.find_definition("Core", "Wait")), true) and ok
	ok = _check("everything else stays plain",
		picker._is_featured(registry.find_definition("Core", "Always")), false) and ok

	# The highlight is REAL in the tree: featured rows carry the bold custom font, plain
	# rows carry none (the objective form of "renders bold" - pixel bolding is theme-bound).
	var parent: Node = Node.new()
	var tree_picker: ACEPickerDialog = ACEPickerDialog.new()
	tree_picker.init_dialog(parent, registry)
	tree_picker._context = {"mode": "append_action", "signals_only": false, "selected_resource": null}
	tree_picker._refresh_tree()
	var featured_font: Font = null
	var plain_font: Font = ThemeDB.fallback_font
	var item: TreeItem = tree_picker._first_definition_item(tree_picker._tree.get_root())
	while item != null:
		var definition: Variant = item.get_metadata(0)
		if definition is ACEDefinition:
			if tree_picker._is_featured(definition) and featured_font == null:
				featured_font = item.get_custom_font(0)
			elif not tree_picker._is_featured(definition):
				plain_font = item.get_custom_font(0)
				break
		item = item.get_next_in_tree()
	ok = _check("featured tree rows carry the bold font", featured_font != null, true) and ok
	ok = _check("plain tree rows carry no custom font", plain_font == null, true) and ok
	parent.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] featured_aces_test: %s" % label)
		return true
	print("[FAIL] featured_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
