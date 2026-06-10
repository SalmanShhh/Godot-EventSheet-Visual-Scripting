# Godot EventSheets — Function verify-lift + trailing-comment preservation
# Generated sheet FUNCTIONS (with their @ace annotation blocks) and trailing top-level
# comments now lift back into real rows. Two-pass safety: when the full lift can't verify
# byte-identically, the event-only lift retries — function/comment upgrades can never
# regress previously-lifting files. The shipped PlatformerMovement pack doubles as the
# end-to-end fixture (behavior-mode annotation regeneration incl. $Class templates).
@tool
extends RefCounted
class_name FunctionLiftTest

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
	all_passed = _check("behavior pack functions lift", pack.functions.size() >= 2, true) and all_passed
	# _enter_tree is the behavior host-binding scaffold: external emission keeps the
	# prelude verbatim (it never synthesizes the host block), so it must stay a block.
	all_passed = _check("only the host-binding scaffold stays a block",
		pack_function_blocks, ["func _enter_tree() -> void:"] as Array[String]) and all_passed
	all_passed = _check("behavior identity recovered from the prelude",
		pack.behavior_mode and pack.custom_class_name == "PlatformerMovement" and pack.host_class == "CharacterBody2D", true) and all_passed
	pack.external_source_path = "user://eventsheets_pack_lift_rt.gd"
	var pack_roundtrip: String = str(SheetCompiler.compile(pack, "user://eventsheets_pack_lift_rt.gd").get("output", ""))
	all_passed = _check("behavior pack round-trips byte-identically", pack_roundtrip == pack_source, true) and all_passed

	# Two-pass safety: an unannotated handwritten function keeps the file as blocks,
	# byte-identical (no regression, no corruption).
	var handwritten: String = "extends Node\n\nfunc helper() -> void:\n\tprint(\"hi\")\n"
	var handwritten_imported: EventSheetResource = GDScriptImporter.new().import_external_source(handwritten)
	all_passed = _check("unannotated functions stay blocks", handwritten_imported.functions.is_empty(), true) and all_passed
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
