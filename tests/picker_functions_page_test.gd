# Godot EventSheets - the ACE picker's Functions page (the open script's own verbs).
#
# When a sheet came from a .gd file, the picker's object page opens with that file's OWN functions:
# the published verbs first, then a folded Helpers part for the ones the file never published. This
# test proves the page against tests/fixtures/picker_functions_fixture.gd, opened the way the dock
# opens a .gd, so every string pinned here is a string a reader actually meets.
#
# What it pins, in the order a reader meets it:
#   1. THE PAGE. The section title, its sub-note, the folded Helpers header, and every entry label
#      in order - name, kind in one word, one chip per parameter.
#   2. THE GUARD. A sheet with no .gd behind it, and a .gd with no functions, show no section.
#   3. THE INSERT. Every entry is a COPY of the frozen Core "Call Function" ACE with its target
#      named in metadata - the ace id and the codegen template are compatibility promises, so a
#      Functions pick must travel the existing path rather than invent one.
#   4. SEARCH. Typing part of a function's display name (or of its GDScript name) finds it.
#   5. THE CHIPS. The ghost row's before-you-type suggestions lead with the script's own verbs.
#   6. SYMMETRY. Pick a verb -> the call it emits -> reopen the emitted file as a sheet -> the row
#      is the same Core/CallFunction aimed at the same function, and reads "Functions · Call <Name>".
@tool
class_name PickerFunctionsPageTest
extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/picker_functions_fixture.gd"
const ROUND_TRIP_PATH := "user://picker_functions_round_trip.gd"


## Minimal dock stand-in: suggested_definitions only reads the registry and the open sheet off it.
class StubDock:
	extends Control
	var _ace_registry: EventSheetACERegistry = null
	var _current_sheet: EventSheetResource = null


static func run() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)

	passed = _test_the_page(sheet) and passed
	passed = _test_the_guard() and passed
	passed = _test_the_insert(sheet, registry) and passed
	passed = _test_search(sheet, registry) and passed
	passed = _test_chips(sheet, registry) and passed
	passed = _test_symmetry(registry) and passed
	return passed


# ── 1. The page ──


static func _test_the_page(sheet: EventSheetResource) -> bool:
	var content: Dictionary = ACEPickerDialog.functions_page_content(sheet)
	var passed: bool = _check("the section is titled with the function mark",
		str(content.get("title", "")), "ƒ Functions")
	passed = _check("the sub-note counts every function in the file",
		str(content.get("note", "")), "this script - 4") and passed
	passed = _check("the folded part is headed with its own count",
		str(content.get("helpers_header", "")), "+ Helpers (2)") and passed
	passed = _check("the published verbs lead, each with its kind and its parameter chip",
		_labels(content.get("published", [])),
		"Award Points   action   amount number | Round Is Ready   condition   enabled true/false") and passed
	passed = _check("the helpers follow, each saying it is not published as an ACE",
		_labels(content.get("helpers", [])),
		"Reset Score   action · not published | Doubled Score   expression · not published") and passed
	passed = _check("the entries name the functions they call",
		_function_names(content.get("published", [])) + " | " + _function_names(content.get("helpers", [])),
		"award_points, round_is_ready | reset_score, doubled_score") and passed
	return passed


# ── 2. The guard ──


static func _test_the_guard() -> bool:
	var authored: EventSheetResource = EventSheetResource.new()
	var passed: bool = _check("a sheet with no .gd behind it shows no Functions section",
		ACEPickerDialog.functions_page_content(authored).is_empty(), true)
	passed = _check("nor does a null sheet",
		ACEPickerDialog.functions_page_content(null).is_empty(), true) and passed
	var functionless: EventSheetResource = EventSheetResource.new()
	functionless.external_source_path = "res://some_script.gd"
	passed = _check("nor does a .gd that declares no functions",
		ACEPickerDialog.functions_page_content(functionless).is_empty(), true) and passed
	return passed


# ── 3. The insert ──


static func _test_the_insert(sheet: EventSheetResource, registry: EventSheetACERegistry) -> bool:
	var definitions: Array[ACEDefinition] = ACEPickerDialog.function_call_definitions(sheet, registry)
	var identities: PackedStringArray = PackedStringArray()
	var templates: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = PackedStringArray()
	var targets: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		identities.append("%s/%s" % [definition.provider_id, definition.id])
		templates.append(str(definition.metadata.get("codegen_template", "")))
		names.append(definition.display_name)
		targets.append(str(definition.metadata.get(ACEPickerDialog.FUNCTION_META_KEY, "")))
	var passed: bool = _check("every entry is the frozen Core call ace",
		", ".join(identities),
		"Core/CallFunction, Core/CallFunction, Core/CallFunction, Core/CallFunction")
	passed = _check("its codegen template is untouched",
		", ".join(templates),
		"{function_name}({args}), {function_name}({args}), {function_name}({args}), {function_name}({args})") and passed
	passed = _check("each entry reads as a call to the named verb",
		", ".join(names),
		"Call Award Points, Call Round Is Ready, Call Reset Score, Call Doubled Score") and passed
	passed = _check("and carries the function it aims at",
		", ".join(targets),
		"award_points, round_is_ready, reset_score, doubled_score") and passed
	passed = _check("the shared cached definition is left alone",
		str(registry.find_definition("Core", "CallFunction").display_name), "Call Function") and passed
	return passed


# ── 4. Search ──


static func _test_search(sheet: EventSheetResource, registry: EventSheetACERegistry) -> bool:
	var definitions: Array[ACEDefinition] = ACEPickerDialog.function_call_definitions(sheet, registry)
	var passed: bool = _check("part of a display name finds the verb",
		_matches(definitions, "award"), "Call Award Points")
	passed = _check("so does the GDScript name a coder would type",
		_matches(definitions, "round_is_ready"), "Call Round Is Ready") and passed
	passed = _check("a helper is findable too",
		_matches(definitions, "doubled"), "Call Doubled Score") and passed
	passed = _check("an empty query finds nothing", _matches(definitions, "   "), "") and passed
	passed = _check("a word from no function finds nothing",
		_matches(definitions, "teleport"), "") and passed
	return passed


# ── 5. The chips ──


static func _test_chips(sheet: EventSheetResource, registry: EventSheetACERegistry) -> bool:
	var dock: StubDock = StubDock.new()
	dock._ace_registry = registry
	dock._current_sheet = sheet
	var actions: EventSheetAuthorActions = EventSheetAuthorActions.new()
	actions.init(dock)
	var chips: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in actions.suggested_definitions("action", 4):
		chips.append(definition.display_name)
	var leading: PackedStringArray = chips.slice(0, 2)
	var passed: bool = _check("the script's own verbs lead the action chips",
		", ".join(leading), "Call Award Points, Call Round Is Ready")
	passed = _check("and the row is still filled out to its limit", chips.size(), 4) and passed
	# A condition key asks for conditions; the call rows are actions, so they stay out of that row.
	var condition_chips: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in actions.suggested_definitions("condition", 4):
		condition_chips.append(definition.display_name)
	passed = _check("the condition chips are not hijacked by them",
		condition_chips.has("Call Award Points"), false) and passed
	dock.free()
	return passed


# ── 6. Symmetry ──


## Pick a verb, let the sheet emit the call, reopen the emitted file: the row must come back as the
## same Core/CallFunction aimed at the same function, reading "Functions · Call Award Points". The
## call is dropped inside a helper's body so the round trip runs through the fixture's OWN file.
static func _test_symmetry(registry: EventSheetACERegistry) -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	var picked: ACEDefinition = null
	for definition: ACEDefinition in ACEPickerDialog.function_call_definitions(sheet, registry):
		if str(definition.metadata.get(ACEPickerDialog.FUNCTION_META_KEY, "")) == "award_points":
			picked = definition
			break
	var passed: bool = _check("the picker offers the verb to pick", picked != null, true)
	if picked == null:
		return false
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = picked.provider_id
	call_action.ace_id = picked.id
	call_action.codegen_template = str(picked.metadata.get("codegen_template", ""))
	call_action.params = {"function_name": str(picked.metadata.get(ACEPickerDialog.FUNCTION_META_KEY, "")), "args": "5.0"}
	var host: EventFunction = ViewportRowBuilder.find_function_by_name(sheet, "reset_score")
	(host.events[0] as EventRow).actions.append(call_action)
	var emitted: String = str(SheetCompiler.new().compile(sheet, ROUND_TRIP_PATH).get("output", ""))
	passed = _check("the pick emits a plain call, nothing plugin-shaped",
		emitted.contains("\taward_points(5.0)\n"), true) and passed
	var file: FileAccess = FileAccess.open(ROUND_TRIP_PATH, FileAccess.WRITE)
	file.store_string(emitted)
	file.close()

	var reopened: EventSheetResource = GDScriptImporter.new().import_external(ROUND_TRIP_PATH)
	var reopened_host: EventFunction = ViewportRowBuilder.find_function_by_name(reopened, "reset_score")
	var lifted: ACEAction = null
	for entry: Variant in (reopened_host.events[0] as EventRow).actions:
		if entry is ACEAction and (entry as ACEAction).ace_id == "CallFunction":
			lifted = entry as ACEAction
			break
	passed = _check("reopening the file lifts the line back to a call row", lifted != null, true) and passed
	if lifted == null:
		return false
	passed = _check("aimed at the same function, with the same argument",
		"%s/%s %s(%s)" % [lifted.provider_id, lifted.ace_id,
			str(lifted.params.get("function_name", "")), str(lifted.params.get("args", ""))],
		"Core/CallFunction award_points(5.0)") and passed
	# The reading the row draws from that lifted call - the object word, the verb, and one chip per
	# argument named by the called function's OWN parameter.
	var called: EventFunction = ViewportRowBuilder.find_function_by_name(reopened, "award_points")
	var pieces: Array = EventSheetViewportReadingRows.call_reading_pieces(
		EventSheetVerbProperties.display_name_of(called),
		PackedStringArray(["5.0"]),
		EventSheetViewportReadingRows.parameter_names_of(called),
		false
	)
	var reading: PackedStringArray = PackedStringArray()
	for piece: Variant in pieces:
		reading.append(str((piece as Array)[0]).strip_edges())
	passed = _check("and the reopened row reads as the same named verb under Functions",
		" ".join(reading).strip_edges(), "Functions Call Award Points  amount = 5.0") and passed
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUND_TRIP_PATH))
	return passed


# ── Helpers ──


static func _labels(entries: Variant) -> String:
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in (entries as Array):
		out.append(str((entry as Dictionary).get("label", "")))
	return " | ".join(out)


static func _function_names(entries: Variant) -> String:
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in (entries as Array):
		out.append(str((entry as Dictionary).get("function_name", "")))
	return ", ".join(out)


static func _matches(definitions: Array[ACEDefinition], query: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		if ACEPickerDialog.function_matches_query(definition, query):
			out.append(definition.display_name)
	return ", ".join(out)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] picker_functions_page_test: %s" % label)
		return true
	print("[FAIL] picker_functions_page_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
