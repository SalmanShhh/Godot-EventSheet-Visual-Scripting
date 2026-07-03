# EventForge - script intent (behaviour / autoload / editor tool / custom resource / node).
#
# THE CONTRACT: the intent derives from fields sheets ALREADY carry (never stored), one table
# drives the intent-aware UX (New-menu sections, Sheet Type preset, banner pill, empty-sheet
# advice), and the two new script destinations work end to end - a Custom Resource sheet
# compiles to a .tres-able class, an Editor Tool starter compiles to an @tool EditorScript.
@tool
extends RefCounted
class_name ScriptIntentTest


static func run() -> bool:
	var all_passed: bool = true

	# ── Intent detection over existing fields ──
	var plain: EventSheetResource = EventSheetResource.new()
	all_passed = _check("plain sheet classifies as EVENT_SHEET",
		EventSheetScriptIntent.of_sheet(plain), EventSheetScriptIntent.Intent.EVENT_SHEET) and all_passed
	var behaviour: EventSheetResource = EventSheetResource.new()
	behaviour.behavior_mode = true
	all_passed = _check("behavior_mode classifies as BEHAVIOUR",
		EventSheetScriptIntent.of_sheet(behaviour), EventSheetScriptIntent.Intent.BEHAVIOUR) and all_passed
	var autoload_sheet: EventSheetResource = EventSheetResource.new()
	autoload_sheet.autoload_mode = true
	all_passed = _check("autoload_mode classifies as AUTOLOAD",
		EventSheetScriptIntent.of_sheet(autoload_sheet), EventSheetScriptIntent.Intent.AUTOLOAD) and all_passed
	var tool_sheet: EventSheetResource = EventSheetResource.new()
	tool_sheet.tool_mode = true
	tool_sheet.host_class = "EditorScript"
	all_passed = _check("@tool + EditorScript classifies as EDITOR_TOOL",
		EventSheetScriptIntent.of_sheet(tool_sheet), EventSheetScriptIntent.Intent.EDITOR_TOOL) and all_passed
	var resource_sheet: EventSheetResource = EventSheetResource.new()
	resource_sheet.host_class = "Resource"
	resource_sheet.custom_class_name = "LootTable"
	all_passed = _check("Resource host classifies as CUSTOM_RESOURCE",
		EventSheetScriptIntent.of_sheet(resource_sheet), EventSheetScriptIntent.Intent.CUSTOM_RESOURCE) and all_passed
	all_passed = _check("Resource SUBCLASS hosts count as resources (AudioStream)",
		EventSheetScriptIntent.is_resource_host("AudioStream"), true) and all_passed
	all_passed = _check("node hosts do not count as resources",
		EventSheetScriptIntent.is_resource_host("CharacterBody2D"), false) and all_passed

	# ── Every intent has display identity + empty-sheet advice ──
	for intent: EventSheetScriptIntent.Intent in EventSheetScriptIntent.Intent.values():
		var display: Dictionary = EventSheetScriptIntent.display(intent)
		all_passed = _check("intent %d has a label + glyph" % intent,
			not str(display.get("label", "")).is_empty() and not str(display.get("glyph", "")).is_empty(), true) and all_passed
	var resource_advice: Dictionary = EventSheetScriptIntent.empty_sheet_advice(resource_sheet)
	all_passed = _check("resource advice steers to exported variables + functions",
		str(resource_advice.get("primary", "")).contains("exported variables")
		and str(resource_advice.get("tip", "")).contains("functions"), true) and all_passed
	all_passed = _check("tool advice names On Editor Run",
		str(EventSheetScriptIntent.empty_sheet_advice(tool_sheet).get("primary", "")).contains("On Editor Run"), true) and all_passed

	# ── Sheet Type index 5 = Custom Resource; node-ish hosts fall back to Resource ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._apply_sheet_type_settings(5, "LootTable", "", "Node2D")
	all_passed = _check("Custom Resource type forces a Resource host (node host rejected)",
		dock._current_sheet.host_class, "Resource") and all_passed
	dock._apply_sheet_type_settings(5, "MusicBank", "", "AudioStream")
	all_passed = _check("a Resource-subclass host is kept",
		dock._current_sheet.host_class, "AudioStream") and all_passed
	all_passed = _check("the applied sheet classifies as CUSTOM_RESOURCE",
		EventSheetScriptIntent.of_sheet(dock._current_sheet), EventSheetScriptIntent.Intent.CUSTOM_RESOURCE) and all_passed
	dock.free()

	# ── The two new starters compile to their intended script shapes ──
	var loot: EventSheetResource = EventSheetStarterTemplates._build_custom_resource_starter()
	var loot_output: String = str(SheetCompiler.compile(loot, "user://intent_loot.gd").get("output", ""))
	all_passed = _check("resource starter compiles to a named Resource class",
		loot_output.contains("class_name LootTable") and loot_output.contains("extends Resource"), true) and all_passed
	all_passed = _check("resource starter ships a callable function",
		loot_output.contains("func roll() -> String:"), true) and all_passed
	var chore: EventSheetResource = EventSheetStarterTemplates._build_editor_tool_starter()
	var chore_output: String = str(SheetCompiler.compile(chore, "user://intent_tool.gd").get("output", ""))
	all_passed = _check("editor tool starter compiles to an @tool EditorScript",
		chore_output.contains("@tool") and chore_output.contains("extends EditorScript"), true) and all_passed
	all_passed = _check("editor tool starter wires On Editor Run",
		chore_output.contains("func _run() -> void:"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] script_intent_test: %s" % label)
		return true
	print("[FAIL] script_intent_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
