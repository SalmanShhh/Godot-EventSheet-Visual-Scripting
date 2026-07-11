# EventForge - Eventsheet-authored behaviors: expose-as-ACE + identity UX
#
# Sheet functions marked expose_as_ace compile WITH @ace_* annotations; feeding the
# generated script back through the semantic analyzer proves the addon loop (drop the
# compiled .gd into eventsheet_addons/ and the behavior's ACEs publish). The identity UX
# (banner, tab badges, host-aware header, Sheet Type dialog) makes the sheet type visible.
@tool
class_name BehaviorAuthoringTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# Behavior sheet with one exposed function.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "PatrolBehavior"
	sheet.custom_class_icon = "res://addons/eventsheet/icons/eventsheet.svg"
	var dash: EventFunction = EventFunction.new()
	dash.function_name = "dash"
	dash.expose_as_ace = true
	dash.ace_display_name = "Dash"
	dash.ace_category = "Movement"
	dash.description = "Dashes the host forward."
	var strength_param: ACEParam = ACEParam.new()
	strength_param.id = "strength"
	strength_param.type_name = "float"
	dash.params.append(strength_param)
	sheet.functions.append(dash)
	var hidden: EventFunction = EventFunction.new()
	hidden.function_name = "internal_tick"
	sheet.functions.append(hidden)

	var output_path: String = "user://eventforge_behavior_authoring.gd"
	var output: String = str(SheetCompiler.compile(sheet, output_path).get("output", ""))
	all_passed = _check("exposed function carries @ace_action", output.contains("## @ace_action"), true) and all_passed
	all_passed = _check("display name annotation emitted", output.contains("## @ace_name(\"Dash\")"), true) and all_passed
	all_passed = _check("category annotation emitted", output.contains("## @ace_category(\"Movement\")"), true) and all_passed
	all_passed = _check("sheet icon flows to the published ACE", output.contains("## @ace_icon(\"res://addons/eventsheet/icons/eventsheet.svg\")"), true) and all_passed
	all_passed = _check("behavior codegen template targets the child node",
		output.contains("## @ace_codegen_template(\"$PatrolBehavior.dash({strength})\")"), true) and all_passed
	all_passed = _check("unexposed functions stay annotation-free",
		output.contains("## @ace_action\nfunc internal_tick"), false) and all_passed

	# The addon loop: the generated script parses back into ACE overrides.
	var generated_script: Script = load(output_path)
	var source_metadata: Dictionary = EventSheetSemanticAnalyzer.new().parse_source_metadata(generated_script)
	var dash_overrides: Dictionary = source_metadata.get("methods", {}).get("dash", {})
	all_passed = _check("generated annotations parse back (name)", str(dash_overrides.get("name", "")), "Dash") and all_passed
	all_passed = _check("generated annotations parse back (codegen template)",
		str(dash_overrides.get("codegen_template", "")), "$PatrolBehavior.dash({strength})") and all_passed
	var internal_overrides: Dictionary = source_metadata.get("methods", {}).get("internal_tick", {})
	all_passed = _check("unexposed function is published as hidden (skipped by the generator)",
		bool(internal_overrides.get("hidden", false)), true) and all_passed

	# Non-behavior sheets expose self methods (no child-node prefix).
	var node_sheet: EventSheetResource = EventSheetResource.new()
	node_sheet.custom_class_name = "PatrollingGuard"
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.expose_as_ace = true
	node_sheet.functions.append(heal)
	var node_output: String = str(SheetCompiler.compile(node_sheet, "user://eventforge_node_authoring.gd").get("output", ""))
	all_passed = _check("custom-node templates call self methods",
		node_output.contains("## @ace_codegen_template(\"heal()\")"), true) and all_passed

	# Identity UX: banner content/visibility, tab badge, host-aware header label.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("banner visible for behavior sheets", editor._identity_banner.visible, true) and all_passed
	all_passed = _check("banner announces the behavior + host",
		editor._identity_banner._label.contains("PatrolBehavior - Behavior · acts on host: CharacterBody2D"), true) and all_passed
	all_passed = _check("tab badge marks behavior sheets",
		editor._format_tab_title(sheet, "", false).begins_with("⚙ "), true) and all_passed
	all_passed = _check("column header gains the host context",
		editor.get_viewport_control().get_host_context_label(), " - host: CharacterBody2D") and all_passed

	# Sheet Type dialog application path (the discoverable event-sheet-style control).
	var plain_sheet: EventSheetResource = EventSheetResource.new()
	var second_editor: EventSheetEditor = EventSheetEditor.new()
	second_editor.setup(plain_sheet)
	second_editor.set_undo_redo_manager(NoopUndoManager.new())
	# Plain sheets keep a minimal identity strip (the beginner's "what is this" cue + the save-time
	# health chip) - the old rule hid the banner for exactly the sheets newcomers make.
	all_passed = _check("banner visible for plain sheets too", second_editor._identity_banner.visible, true) and all_passed
	all_passed = _check("plain-sheet banner says what it is",
		second_editor._identity_banner._label.begins_with("Event Sheet · "), true) and all_passed
	second_editor._apply_sheet_type_settings(2, "GuardBrain", "res://addons/eventsheet/icons/eventsheet.svg", "Area2D")
	all_passed = _check("dialog apply sets behavior mode", plain_sheet.behavior_mode, true) and all_passed
	all_passed = _check("dialog apply sets name/host",
		plain_sheet.custom_class_name == "GuardBrain" and plain_sheet.host_class == "Area2D", true) and all_passed
	second_editor._refresh_title_strip()
	all_passed = _check("banner appears after type change", second_editor._identity_banner.visible, true) and all_passed
	editor.free()
	second_editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] behavior_authoring_test: %s" % label)
		return true
	print("[FAIL] behavior_authoring_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
