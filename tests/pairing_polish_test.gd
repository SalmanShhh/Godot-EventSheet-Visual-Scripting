# EventForge — Pairing polish: reverse provenance, ƒx expression validation, row-cell icons
#
# Reverse provenance: clicking generated code selects the sheet row (smallest containing
# source-map range, falling outward when an inner resource has no row). ƒx fields
# compile-check as expressions against the sheet context. ACE cells carry object icons
# (resolved like the picker; cached per provider::ace).
@tool
extends RefCounted
class_name PairingPolishTest

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

	# Sheet: two events (the second with an in-flow GDScript block) + a comment row.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"health": {"type": "int", "default": 100, "exported": false}}
	var first_event: EventRow = EventRow.new()
	first_event.trigger_provider_id = "Core"
	first_event.trigger_id = "OnReady"
	var first_action: ACEAction = ACEAction.new()
	first_action.provider_id = "Test"
	first_action.ace_id = "setup"
	first_action.codegen_template = "setup()"
	first_event.actions.append(first_action)
	sheet.events.append(first_event)
	var second_event: EventRow = EventRow.new()
	second_event.trigger_provider_id = "Core"
	second_event.trigger_id = "OnProcess"
	var inline_block: RawCodeRow = RawCodeRow.new()
	inline_block.code = "health += 1"
	second_event.actions.append(inline_block)
	sheet.events.append(second_event)

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# select_resource: the reverse-provenance primitive.
	all_passed = _check("select_resource selects the row", viewport.select_resource(second_event), true) and all_passed
	all_passed = _check("selection context reflects it",
		viewport.get_selected_context().get("source_resource", null) == second_event, true) and all_passed
	all_passed = _check("select_resource(null) is a no-op", viewport.select_resource(null), false) and all_passed

	# Reverse provenance through the dock: clicking a generated line selects its row;
	# in-flow block lines fall back to their enclosing event (the block has no row).
	editor._toggle_code_panel()
	var source_map: Array = editor._code_source_map
	all_passed = _check("code panel produced a source map", source_map.is_empty(), false) and all_passed
	var inline_entry: Dictionary = {}
	var first_entry: Dictionary = {}
	for entry in source_map:
		if str(entry.get("uid", "")) == str(inline_block.get_instance_id()):
			inline_entry = entry
		elif str(entry.get("uid", "")) == str(first_event.get_instance_id()):
			first_entry = entry
	all_passed = _check("in-flow block is source-mapped", inline_entry.is_empty(), false) and all_passed
	editor._select_sheet_row_for_code_line(int(first_entry.get("start", 0)))
	all_passed = _check("clicking an event's line selects that event",
		viewport.get_selected_context().get("source_resource", null) == first_event, true) and all_passed
	editor._select_sheet_row_for_code_line(int(inline_entry.get("start", 0)))
	all_passed = _check("clicking an in-flow block's line selects its event (fallback outward)",
		viewport.get_selected_context().get("source_resource", null) == second_event, true) and all_passed

	# ƒx expression validation against the sheet context.
	all_passed = _check("valid expression lints ok",
		bool(EventSheetGDScriptLint.lint_expression("health + 10", sheet).get("ok", false)), true) and all_passed
	all_passed = _check("invalid expression is rejected",
		bool(EventSheetGDScriptLint.lint_expression("health +", sheet).get("ok", true)), false) and all_passed
	all_passed = _check("statements are not expressions",
		bool(EventSheetGDScriptLint.lint_expression("var x = 1", sheet).get("ok", true)), false) and all_passed
	all_passed = _check("empty expression is fine",
		bool(EventSheetGDScriptLint.lint_expression("  ", sheet).get("ok", false)), true) and all_passed

	# Row-cell icons: an addon ACE with @ace_icon resolves to a texture even headless
	# (res:// load), lands in span metadata, and widens the measured span.
	var icon_sheet: EventSheetResource = EventSheetResource.new()
	var icon_event: EventRow = EventRow.new()
	icon_event.trigger_provider_id = "Core"
	icon_event.trigger_id = "OnProcess"
	var heal_action: ACEAction = ACEAction.new()
	heal_action.provider_id = "DemoHealthAddon"
	heal_action.ace_id = "method:heal"
	heal_action.params = {"amount": 5}
	icon_event.actions.append(heal_action)
	icon_sheet.events.append(icon_event)
	var icon_editor: EventSheetEditor = EventSheetEditor.new()
	icon_editor.setup(icon_sheet)
	icon_editor.set_undo_redo_manager(NoopUndoManager.new())
	var icon_viewport: EventSheetViewport = icon_editor.get_viewport_control()
	var heal_icon: Texture2D = icon_viewport._object_icon_for("DemoHealthAddon", "method:heal")
	all_passed = _check("@ace_icon resolves for row cells", heal_icon != null, true) and all_passed
	var icon_span: SemanticSpan = SemanticSpan.new()
	icon_span.metadata = {"object_icon": heal_icon}
	var plain_span: SemanticSpan = SemanticSpan.new()
	plain_span.metadata = {}
	var font: Font = ThemeDB.fallback_font
	var with_icon: float = icon_viewport._measure_span_width(icon_span, "Heal 5 HP", font, 13)
	var without_icon: float = icon_viewport._measure_span_width(plain_span, "Heal 5 HP", font, 13)
	all_passed = _check("icon widens the measured span by the fixed advance",
		is_equal_approx(with_icon - without_icon, EventRowRenderer.OBJECT_ICON_ADVANCE), true) and all_passed
	all_passed = _check("icon resolution is cached",
		icon_viewport._object_icon_for("DemoHealthAddon", "method:heal") == heal_icon, true) and all_passed

	editor.free()
	icon_editor.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pairing_polish_test: %s" % label)
		return true
	print("[FAIL] pairing_polish_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
