# EventForge - the extension seams (the 12 additions that let end users build custom features)
#
# Pins the headless-testable contracts: row menu registration + filtering, dictionary-defined
# ACEs joining the registry, starter registration + build dispatch, quick-add synonyms, section
# descriptions, param editor registry, lifecycle notification, palette categories, block kind
# style/validate defaults, and verify_pack against a real bundled pack. UI-only seams
# (preferences row, Doctor fix button, custom tours) are exercised by their host surfaces.
@tool
class_name ApiExtensionSeamsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Row context-menu items: filter decides applicability; action receives the resource.
	var touched: Array = []
	EventSheets.register_row_menu_item("Zz Probe",
		func(resource: Resource) -> bool: return resource is EventRow,
		func(resource: Resource) -> void: touched.append(resource))
	var event_row: EventRow = EventRow.new()
	var items: Array[Dictionary] = EventSheets.row_menu_items_for(event_row)
	all_passed = _check("row item applies to an EventRow", items.size() >= 1, true) and all_passed
	all_passed = _check("row item filtered off a non-event", EventSheets.row_menu_items_for(CommentRow.new()).size(), 0) and all_passed
	(items[0].get("action") as Callable).call(event_row)
	all_passed = _check("row action receives the row", touched.size() == 1 and touched[0] == event_row, true) and all_passed
	EventSheets.unregister_row_menu_item("Zz Probe")
	all_passed = _check("row item unregisters", EventSheets.row_menu_items_for(event_row).size(), 0) and all_passed

	# Dictionary-defined ACEs: built, registered, discoverable through a registry refresh.
	var definition: ACEDefinition = EventSheets.register_simple_ace({
		"id": "ZzDash", "kind": "action", "display_name": "Zz Dash",
		"category": "Zz Extensions", "template": "velocity.x = {speed}",
		"params": [{"id": "speed", "type_name": "float", "default": "300.0"}],
	})
	all_passed = _check("simple_ace builds an action", definition.ace_type, ACEDefinition.ACEType.ACTION) and all_passed
	all_passed = _check("simple_ace keeps its template", str(definition.metadata.get("codegen_template", "")), "velocity.x = {speed}") and all_passed
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], false)
	all_passed = _check("registered simple ACE joins the registry",
		registry.find_definition("Extension", "ZzDash") == definition, true) and all_passed
	EventSheets.simple_aces().clear()

	# Starters: registered entries appear (ids 1000+) and build fresh sheets.
	EventSheets.register_starter({"label": "Zz Starter", "build": func() -> EventSheetResource:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "Area2D"
		return sheet})
	var listed: Array[Dictionary] = EventSheetStarterTemplates.create_new_starters()
	all_passed = _check("registered starter listed at id 1000",
		int(listed[listed.size() - 1].get("id", -1)) == 1000 and str(listed[listed.size() - 1].get("label", "")) == "Zz Starter", true) and all_passed
	all_passed = _check("registered starter builds its sheet",
		EventSheetStarterTemplates.build_starter(1000).host_class, "Area2D") and all_passed
	EventSheets.registered_starters().clear()

	# Quick-add synonyms: a pack phrase maps to its search term.
	EventSheets.register_quick_add_synonyms({"zz dash forward": "zzdash"})
	all_passed = _check("registered synonym resolves",
		Array(ACEPickerDialog._c3_synonym_queries("zz dash forward")).has("zzdash"), true) and all_passed

	# Section descriptions: same channel the built-ins use.
	EventSheets.register_section_description("Zz Extensions", "Verbs from the Zz probe pack.")
	all_passed = _check("registered section blurb resolves",
		EventSheetSectionInfo.description_for("Zz Extensions"), "Verbs from the Zz probe pack.") and all_passed

	# Param editors: registered by tag, retrieved by the dialog's lookup.
	EventSheets.register_param_editor("zz_tag", func(_p: Dictionary, _v: String) -> LineEdit: return LineEdit.new())
	all_passed = _check("param editor registered", EventSheets.param_editor_for("zz_tag").is_valid(), true) and all_passed
	all_passed = _check("unknown param tag is invalid", EventSheets.param_editor_for("nope").is_valid(), false) and all_passed

	# Lifecycle: listeners fire with the payload.
	var seen: Array = []
	EventSheets.on_sheet_saved(func(payload: Dictionary) -> void: seen.append(payload))
	EventSheets._notify_lifecycle("saved", {"path": "res://zz.gd"})
	all_passed = _check("lifecycle listener fires with payload",
		seen.size() == 1 and str((seen[0] as Dictionary).get("path", "")) == "res://zz.gd", true) and all_passed

	# Palette categories: the category prefixes the stored title.
	EventSheets.register_palette_command("Reroll", func() -> void: pass, "Zz Pack")
	var palette_titles: Array = []
	for command: Dictionary in EventSheets.palette_commands():
		palette_titles.append(str(command.get("title", "")))
	all_passed = _check("palette category prefixes the title", palette_titles.has("Zz Pack: Reroll"), true) and all_passed
	EventSheets.unregister_palette_command("Zz Pack: Reroll")

	# Block kind hooks: safe defaults so every existing kind is untouched.
	var kind: EventSheetBlockKind = EventSheetBlockKind.new()
	all_passed = _check("block style defaults empty", kind.style(null).is_empty(), true) and all_passed
	all_passed = _check("block validate defaults clean", kind.validate(null), "") and all_passed

	# verify_pack: a real bundled pack passes both gates; a bad path reports honestly.
	var report: Dictionary = EventSheets.verify_pack("res://eventsheet_addons/fps_controller/fps_controller_behavior.gd")
	all_passed = _check("verify_pack passes a shipped pack",
		bool(report.get("ok")) and bool(report.get("parses")) and bool(report.get("round_trips")), true) and all_passed
	var missing: Dictionary = EventSheets.verify_pack("res://nope/never.gd")
	all_passed = _check("verify_pack reports a missing file",
		not bool(missing.get("ok")) and (missing.get("errors") as Array).size() >= 1, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] api_extension_seams_test: %s" % label)
		return true
	print("[FAIL] api_extension_seams_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
