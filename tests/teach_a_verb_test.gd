# Godot EventSheets - Teach a Verb (abstraction lever: your vocabulary grows as you build).
#
# A sheet's published verbs (exposed ƒ functions) become PROJECT-WIDE picker vocabulary
# in one gesture: the sheet's compiled .gd joins the provider scan, persisted in project
# settings (TAUGHT_PROVIDERS_SETTING). The verb keeps living in its home sheet - correct
# self-semantics, the code runs on the node that owns it - and other sheets call it
# node-targeted, retargetable, exactly like a behavior pack's ACE. Teaching writes
# SETTINGS, never the sheet, so it needs no undo step and cannot disturb round-trips.
@tool
class_name TeachAVerbTest
extends RefCounted

const SHEET_PATH := "user://teach_verb_sheet.gd"


static func run() -> bool:
	var ok: bool = true
	ProjectSettings.set_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, null)

	# A game sheet with one published verb.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ScoreKeeper"
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "add_score"
	verb.ace_display_name = "Add Score"
	verb.ace_category = "Score"
	verb.expose_as_ace = true
	var amount_param: ACEParam = ACEParam.new()
	amount_param.id = "amount"
	amount_param.type_name = "int"
	verb.params = [amount_param]
	sheet.functions.append(verb)
	var compile_result: Dictionary = SheetCompiler.compile(sheet, SHEET_PATH)
	ok = _check("the teaching sheet compiles", bool(compile_result.get("success", false)), true) and ok

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(sheet)
	dock._current_sheet_path = SHEET_PATH

	# Refusal guards come first: no class name, then no published verbs.
	var nameless: EventSheetResource = EventSheetResource.new()
	dock._current_sheet = nameless
	ok = _check("teaching refuses without a class name", dock._providers_glue.share_verbs_with_project(), false) and ok
	nameless.custom_class_name = "VerbLess"
	ok = _check("teaching refuses without published verbs", dock._providers_glue.share_verbs_with_project(), false) and ok

	# The real teach: setting gains the compiled path, and the verb reaches the registry.
	dock._current_sheet = sheet
	ok = _check("teaching succeeds", dock._providers_glue.share_verbs_with_project(), true) and ok
	var taught: PackedStringArray = PackedStringArray(ProjectSettings.get_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, PackedStringArray()))
	ok = _check("the setting records the compiled script", taught.has(SHEET_PATH), true) and ok
	ok = _check("teaching twice records once", dock._providers_glue.share_verbs_with_project() and PackedStringArray(ProjectSettings.get_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, PackedStringArray())).size() == 1, true) and ok
	var taught_definition: ACEDefinition = dock._ace_registry.find_definition("ScoreKeeper", "method:add_score")
	ok = _check("the taught verb is in the vocabulary", taught_definition != null, true) and ok
	if taught_definition != null:
		ok = _check("the taught verb is node-targeted and retargetable",
			str(taught_definition.metadata.get("codegen_template", "")).contains("add_score"), true) and ok

	# A SECOND sheet's picker sees it too - the whole point of teaching.
	var other_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	other_dock.setup(EventSheetResource.new())
	ok = _check("another sheet's registry has the taught verb",
		other_dock._ace_registry.find_definition("ScoreKeeper", "method:add_score") != null, true) and ok
	other_dock.free()
	dock.free()
	ProjectSettings.set_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, null)
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] teach_a_verb_test: %s" % label)
		return true
	print("[FAIL] teach_a_verb_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
