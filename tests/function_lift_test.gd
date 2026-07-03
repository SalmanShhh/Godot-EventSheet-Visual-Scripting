# Godot EventSheets — Function verify-lift + trailing-comment preservation
# Generated sheet FUNCTIONS (with their @ace annotation blocks) and trailing top-level
# comments now lift back into real rows. Two-pass safety: when the full lift can't verify
# byte-identically, the event-only lift retries — function/comment upgrades can never
# regress previously-lifting files. The shipped PlatformerMovement pack doubles as the
# end-to-end fixture (behavior-mode annotation regeneration incl. $Class templates).
@tool
class_name FunctionLiftTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Authored: trigger event + exposed function + hidden function + trailing comment.
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "CharacterBody2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "QueueFree"
	event.actions.append(act)
	authored.events.append(event)
	var dash: EventFunction = EventFunction.new()
	dash.function_name = "dash"
	dash.expose_as_ace = true
	dash.ace_display_name = "Dash"
	dash.ace_category = "Movement"
	dash.description = "Dashes forward."
	var strength: ACEParam = ACEParam.new()
	strength.id = "strength"
	strength.type_name = "float"
	dash.params.append(strength)
	var dash_body: RawCodeRow = RawCodeRow.new()
	dash_body.code = "velocity.x = strength"
	dash.events.append(dash_body)
	authored.functions.append(dash)
	var helper: EventFunction = EventFunction.new()
	helper.function_name = "internal_tick"
	var helper_body: RawCodeRow = RawCodeRow.new()
	helper_body.code = "queue_free()"
	helper.events.append(helper_body)
	authored.functions.append(helper)
	var note: CommentRow = CommentRow.new()
	note.text = "trailing note"
	authored.events.append(note)

	var source: String = str(SheetCompiler.compile(authored, "user://eventsheets_fn_lift_src.gd").get("output", ""))
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var function_blocks: int = 0
	var lifted_comment: CommentRow = null
	for row in imported.events:
		if row is RawCodeRow and (row as RawCodeRow).code.begins_with("func "):
			function_blocks += 1
		elif row is CommentRow:
			lifted_comment = row
	all_passed = _check("no function blocks remain", function_blocks, 0) and all_passed
	all_passed = _check("two sheet functions lifted", imported.functions.size(), 2) and all_passed
	var lifted_dash: EventFunction = null
	var lifted_helper: EventFunction = null
	for fn in imported.functions:
		if (fn as EventFunction).function_name == "dash":
			lifted_dash = fn
		elif (fn as EventFunction).function_name == "internal_tick":
			lifted_helper = fn
	all_passed = _check("exposed function keeps its exposure",
		lifted_dash != null and lifted_dash.expose_as_ace and lifted_dash.ace_display_name == "Dash" and lifted_dash.ace_category == "Movement", true) and all_passed
	all_passed = _check("exposed function keeps its description",
		lifted_dash != null and lifted_dash.description == "Dashes forward.", true) and all_passed
	all_passed = _check("params reverse with types",
		lifted_dash != null and lifted_dash.params.size() == 1 and (lifted_dash.params[0] as ACEParam).id == "strength" and (lifted_dash.params[0] as ACEParam).type_name == "float", true) and all_passed
	all_passed = _check("hidden function stays unexposed",
		lifted_helper != null and not lifted_helper.expose_as_ace, true) and all_passed
	all_passed = _check("trailing comment lifts as a comment row",
		lifted_comment != null and lifted_comment.text == "trailing note", true) and all_passed
	imported.external_source_path = "user://eventsheets_fn_lift_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_fn_lift_rt.gd").get("output", ""))
	all_passed = _check("function lift round-trips byte-identically", roundtrip == source, true) and all_passed

	# End-to-end on the shipped behavior pack: behavior-mode annotation regeneration
	# ($PlatformerMovement.jump() templates) must verify too.
	var pack_source: String = FileAccess.get_file_as_string("res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd")
	var pack: EventSheetResource = GDScriptImporter.new().import_external_source(pack_source)
	var pack_function_blocks: Array[String] = []
	for row in pack.events:
		if row is RawCodeRow and (row as RawCodeRow).code.begins_with("func "):
			pack_function_blocks.append((row as RawCodeRow).code.split("\n")[0])
	# The enriched platformer authors its conditions/expressions/helpers as @ace_* method blocks; the
	# build-time function-lift turns them into EventFunction rows (exposed functions gain the sheet's
	# @ace_icon, so external import round-trips byte-exact), so they recover as exposed sheet functions
	# (jump, Is Moving, Can Jump…) and the private _perform_jump as an un-exposed one — not code blocks.
	var pack_function_names: Array[String] = []
	for pack_fn in pack.functions:
		if pack_fn is EventFunction:
			pack_function_names.append((pack_fn as EventFunction).function_name)
	all_passed = _check("behavior pack lifts its exposed ACE methods to EventFunctions",
		pack_function_names.has("jump") and pack_function_names.has("set_move_speed")
		and pack_function_names.has("is_moving") and pack_function_names.has("can_jump"), true) and all_passed
	all_passed = _check("the private helper lifts as an un-exposed function",
		pack_function_names.has("_perform_jump"), true) and all_passed
	# _enter_tree is the behavior host-binding scaffold — external emission keeps the prelude
	# verbatim (it never synthesizes the host block), so it must stay a block.
	all_passed = _check("the host-binding scaffold stays a block",
		pack_function_blocks.has("func _enter_tree() -> void:"), true) and all_passed
	all_passed = _check("behavior identity recovered from the prelude",
		pack.behavior_mode and pack.custom_class_name == "PlatformerMovement" and pack.host_class == "CharacterBody2D", true) and all_passed
	pack.external_source_path = "user://eventsheets_pack_lift_rt.gd"
	var pack_roundtrip: String = str(SheetCompiler.compile(pack, "user://eventsheets_pack_lift_rt.gd").get("output", ""))
	all_passed = _check("behavior pack round-trips byte-identically", pack_roundtrip == pack_source, true) and all_passed

	# Phase 1: an unannotated hand-written function reverse-lifts to an un-exposed sheet function
	# (lifted_unannotated suppresses the @ace_hidden emission), still byte-identical.
	var handwritten: String = "extends Node\n\nfunc helper() -> void:\n\tprint(\"hi\")\n"
	var handwritten_imported: EventSheetResource = GDScriptImporter.new().import_external_source(handwritten)
	all_passed = _check("unannotated function lifts to one un-exposed sheet function",
		handwritten_imported.functions.size() == 1
		and (handwritten_imported.functions[0] as EventFunction).function_name == "helper"
		and not (handwritten_imported.functions[0] as EventFunction).expose_as_ace
		and (handwritten_imported.functions[0] as EventFunction).lifted_unannotated, true) and all_passed
	handwritten_imported.external_source_path = "user://eventsheets_hand_rt.gd"
	var handwritten_roundtrip: String = str(SheetCompiler.compile(handwritten_imported, "user://eventsheets_hand_rt.gd").get("output", ""))
	all_passed = _check("handwritten file stays byte-identical", handwritten_roundtrip == handwritten, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_lift_test: %s" % label)
		return true
	print("[FAIL] function_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
