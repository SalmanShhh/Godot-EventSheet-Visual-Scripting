# Godot EventSheets - Addon composition Lane A (meta-packs):
# meta-packs via compile-time inclusion, governed by ProjectSettings policy knobs.
# THE INVARIANT: policy gates compiles, it never changes emitted bytes.
@tool
class_name AddonCompositionTest
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


static func _set_policy(key: String, value: Variant) -> void:
	ProjectSettings.set_setting("eventsheets/addons/%s" % key, value)


static func _clear_policies() -> void:
	for key in ["composition_mode", "max_include_depth", "collision_policy", "include_sources", "deprecated_tag_blocks", "export_bundling", "depth_overflow"]:
		if ProjectSettings.has_setting("eventsheets/addons/%s" % key):
			ProjectSettings.set_setting("eventsheets/addons/%s" % key, null)


static func _make_base(path: String, tags: PackedStringArray = PackedStringArray()) -> EventSheetResource:
	var base: EventSheetResource = EventSheetResource.new()
	base.addon_tags = tags
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "shake"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "print(\"shake\")"
	fn.events.append(body)
	base.functions.append(fn)
	ResourceSaver.save(base, path)
	return base


static func run() -> bool:
	var all_passed: bool = true
	_clear_policies()

	# Meta-pack: a behavior sheet including a base addon compiles standalone.
	_make_base("user://eventsheets_base_addon.tres", PackedStringArray(["approved"]))
	var meta: EventSheetResource = EventSheetResource.new()
	meta.behavior_mode = true
	meta.host_class = "Node2D"
	meta.custom_class_name = "JamKit"
	meta.includes = ["user://eventsheets_base_addon.tres"]
	var result: Dictionary = SheetCompiler.compile(meta, "user://eventsheets_jamkit.gd")
	var output: String = str(result.get("output", ""))
	all_passed = _check("meta-pack compiles with the include's function",
		bool(result.get("success", false)) and output.contains("func shake() -> void:"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("meta-pack output parses", generated.reload(true) == OK, true) and all_passed

	# Policy: composition off blocks addon includes with a named error.
	_set_policy("composition_mode", "off")
	var blocked: Dictionary = SheetCompiler.compile(meta, "user://eventsheets_jamkit_off.gd")
	all_passed = _check("composition_mode off errors for addon sheets",
		not bool(blocked.get("success", true)) and str(blocked.get("errors")).contains("composition_mode"), true) and all_passed
	_clear_policies()

	# Policy: tagged sources reject untagged includes, accept tagged ones.
	_make_base("user://eventsheets_untagged_addon.tres")
	var strict: EventSheetResource = EventSheetResource.new()
	strict.behavior_mode = true
	strict.host_class = "Node2D"
	strict.custom_class_name = "StrictKit"
	strict.includes = ["user://eventsheets_untagged_addon.tres"]
	_set_policy("include_sources", "tagged:approved")
	var rejected: Dictionary = SheetCompiler.compile(strict, "user://eventsheets_strict.gd")
	all_passed = _check("tagged: sourcing rejects untagged includes",
		not bool(rejected.get("success", true)) and str(rejected.get("errors")).contains("approved"), true) and all_passed
	var accepted: Dictionary = SheetCompiler.compile(meta, "user://eventsheets_jamkit_tagged.gd")
	all_passed = _check("tagged: sourcing accepts tagged includes", bool(accepted.get("success", false)), true) and all_passed
	_clear_policies()

	# Policy: deprecated includes warn by default, error when configured.
	_make_base("user://eventsheets_old_addon.tres", PackedStringArray(["deprecated"]))
	var old_user: EventSheetResource = EventSheetResource.new()
	old_user.includes = ["user://eventsheets_old_addon.tres"]
	var warned: Dictionary = SheetCompiler.compile(old_user, "user://eventsheets_old_user.gd")
	all_passed = _check("deprecated includes warn by default",
		bool(warned.get("success", false)) and str(warned.get("warnings")).contains("deprecated"), true) and all_passed
	_set_policy("deprecated_tag_blocks", "error")
	var banned: Dictionary = SheetCompiler.compile(old_user, "user://eventsheets_old_user2.gd")
	all_passed = _check("deprecated_tag_blocks=error blocks", not bool(banned.get("success", true)), true) and all_passed
	_clear_policies()

	# Policy: collision_policy=error turns root-wins into a failure.
	var collide_base: EventSheetResource = EventSheetResource.new()
	collide_base.variables = {"speed": {"type": "int", "default": 1, "exported": false}}
	ResourceSaver.save(collide_base, "user://eventsheets_collide_base.tres")
	var collider: EventSheetResource = EventSheetResource.new()
	collider.variables = {"speed": {"type": "int", "default": 2, "exported": false}}
	collider.includes = ["user://eventsheets_collide_base.tres"]
	var soft: Dictionary = SheetCompiler.compile(collider, "user://eventsheets_collide.gd")
	all_passed = _check("collisions warn by default (root wins)",
		bool(soft.get("success", false)) and str(soft.get("warnings")).contains("root wins"), true) and all_passed
	_set_policy("collision_policy", "error")
	var hard: Dictionary = SheetCompiler.compile(collider, "user://eventsheets_collide2.gd")
	all_passed = _check("collision_policy=error fails the compile", not bool(hard.get("success", true)), true) and all_passed
	_clear_policies()

	# THE INVARIANT: identical bytes under permissive vs strict-but-passing policy.
	var permissive_output: String = str(SheetCompiler.compile(meta, "user://eventsheets_inv1.gd").get("output", ""))
	_set_policy("include_sources", "tagged:approved")
	_set_policy("collision_policy", "error")
	var strict_output: String = str(SheetCompiler.compile(meta, "user://eventsheets_inv2.gd").get("output", ""))
	_clear_policies()
	all_passed = _check("policy never changes emitted bytes", permissive_output == strict_output, true) and all_passed

	# Sheet Type dialog applies includes.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var dialog_sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(dialog_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._apply_sheet_type_settings(2, "ComposedThing", "", "Node2D", false, PackedStringArray(["kit"]), PackedStringArray(["user://eventsheets_base_addon.tres"]))
	all_passed = _check("Sheet Type applies includes",
		dialog_sheet.includes.size() == 1 and dialog_sheet.includes[0] == "user://eventsheets_base_addon.tres", true) and all_passed

	# Export bundling: the included sheet travels with the pack.
	dialog_sheet.behavior_mode = true
	dialog_sheet.host_class = "Node2D"
	editor._export_addon_pack("user://eventsheets_pack_out")
	all_passed = _check("Export Addon bundles the include",
		FileAccess.file_exists("user://eventsheets_pack_out/eventsheets_base_addon.tres"), true) and all_passed
	editor.free()

	# Lane B: uses_addons emit owned helper instances; bad names warn-and-skip.
	var lane_b: EventSheetResource = EventSheetResource.new()
	lane_b.uses_addons = ["EventSheetIdentifierRules", "Not A Class!"]
	var lane_b_result: Dictionary = SheetCompiler.compile(lane_b, "user://eventsheets_laneb.gd")
	var lane_b_output: String = str(lane_b_result.get("output", ""))
	all_passed = _check("uses_addons emits an owned instance",
		lane_b_output.contains("var __uses_event_sheet_identifier_rules := EventSheetIdentifierRules.new()"), true) and all_passed
	all_passed = _check("invalid uses entries warn and skip",
		str(lane_b_result.get("warnings")).contains("Not A Class!") and not lane_b_output.contains("Not A Class!"), true) and all_passed
	var lane_b_script: GDScript = GDScript.new()
	lane_b_script.source_code = lane_b_output
	all_passed = _check("uses output parses", lane_b_script.reload(true) == OK, true) and all_passed

	# Depth rail: chains past max_include_depth warn (rail tightened to 1 here so a
	# two-level chain crosses it; the default rail is 2).
	var chain_base: EventSheetResource = EventSheetResource.new()
	ResourceSaver.save(chain_base, "user://eventsheets_chain_base.tres")
	var chain_mid: EventSheetResource = EventSheetResource.new()
	chain_mid.includes = ["user://eventsheets_chain_base.tres"]
	ResourceSaver.save(chain_mid, "user://eventsheets_chain_mid.tres")
	var chain_top: EventSheetResource = EventSheetResource.new()
	chain_top.includes = ["user://eventsheets_chain_mid.tres"]
	_set_policy("max_include_depth", 1)
	var chain_result: Dictionary = SheetCompiler.compile(chain_top, "user://eventsheets_chain.gd")
	_clear_policies()
	all_passed = _check("include chains past the depth rail warn",
		bool(chain_result.get("success", false)) and str(chain_result.get("warnings")).contains("Deep chains"), true) and all_passed

	# Sheet Type applies Uses too.
	var uses_editor: EventSheetEditor = EventSheetEditor.new()
	var uses_sheet: EventSheetResource = EventSheetResource.new()
	uses_editor.setup(uses_sheet)
	uses_editor.set_undo_redo_manager(NoopUndoManager.new())
	uses_editor._apply_sheet_type_settings(2, "UsesThing", "", "Node2D", false, PackedStringArray(), PackedStringArray(), PackedStringArray(["ScreenShake"]))
	all_passed = _check("Sheet Type applies uses classes",
		uses_sheet.uses_addons.size() == 1 and uses_sheet.uses_addons[0] == "ScreenShake", true) and all_passed
	uses_editor.free()

	# Lane B.2: sibling requirements compile to _get_configuration_warnings().
	var pack: EventSheetResource = EventSheetResource.new()
	pack.behavior_mode = true
	pack.host_class = "Node2D"
	pack.custom_class_name = "ComboKit"
	pack.requires_behaviors = ["ScreenShake", "bad name!"]
	var pack_result: Dictionary = SheetCompiler.compile(pack, "user://eventsheets_b2.gd")
	var pack_output: String = str(pack_result.get("output", ""))
	all_passed = _check("requires emits the configuration-warnings hook",
		pack_output.contains("func _get_configuration_warnings() -> PackedStringArray:") and pack_output.contains("[\"ScreenShake\"]"), true) and all_passed
	all_passed = _check("invalid requires entries warn and skip",
		str(pack_result.get("warnings")).contains("bad name!") and not pack_output.contains("bad name!"), true) and all_passed
	var pack_script: GDScript = GDScript.new()
	pack_script.source_code = pack_output
	all_passed = _check("requires output parses", pack_script.reload(true) == OK, true) and all_passed
	pack.requires_behaviors = []
	all_passed = _check("no requires, no hook",
		str(SheetCompiler.compile(pack, "user://eventsheets_b2b.gd").get("output", "")).contains("_get_configuration_warnings"), false) and all_passed

	# Sheet Type applies Requires too.
	var req_editor: EventSheetEditor = EventSheetEditor.new()
	var req_sheet: EventSheetResource = EventSheetResource.new()
	req_editor.setup(req_sheet)
	req_editor.set_undo_redo_manager(NoopUndoManager.new())
	req_editor._apply_sheet_type_settings(2, "ReqThing", "", "Node2D", false, PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(["ScreenShake"]))
	all_passed = _check("Sheet Type applies sibling requirements",
		req_sheet.requires_behaviors.size() == 1 and req_sheet.requires_behaviors[0] == "ScreenShake", true) and all_passed
	req_editor.free()

	# MCP policy awareness: tagged include_sources hides untagged ADDON ACEs from
	# list_aces while Core builtins stay listed.
	var server: EventSheetMCPServer = EventSheetMCPServer.new()
	var core_definition: ACEDefinition = ACEDefinition.new()
	core_definition.provider_id = "Core"
	core_definition.id = "Wait"
	var tagged_definition: ACEDefinition = ACEDefinition.new()
	tagged_definition.provider_id = "ScreenShake"
	tagged_definition.id = "Shake"
	tagged_definition.metadata = {"tags": ["approved"]}
	var untagged_definition: ACEDefinition = ACEDefinition.new()
	untagged_definition.provider_id = "OldThing"
	untagged_definition.id = "DoOld"
	all_passed = _check("permissive policy lists everything",
		server._policy_allows_definition(core_definition) and server._policy_allows_definition(untagged_definition), true) and all_passed
	_set_policy("include_sources", "tagged:approved")
	all_passed = _check("tagged policy keeps Core + tagged addons",
		server._policy_allows_definition(core_definition) and server._policy_allows_definition(tagged_definition), true) and all_passed
	all_passed = _check("tagged policy hides untagged addons over MCP",
		server._policy_allows_definition(untagged_definition), false) and all_passed
	_clear_policies()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] addon_composition_test: %s" % label)
		return true
	print("[FAIL] addon_composition_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
