# Godot EventSheets — Gutter bookmarks + compile-time sheet includes
# Bookmarks: session navigation aids (Ctrl+M toggle, F4/Shift+F4 cycle) drawn as gutter
# pennants. Includes: other sheets' variables/rows/functions merge at compile (root wins
# collisions, cycles skip with warnings) — included rows never enter the editing model.
@tool
class_name BookmarksIncludesTest
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

	# ── Bookmarks ────────────────────────────────────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	for index in range(3):
		var comment: CommentRow = CommentRow.new()
		comment.text = "row %d" % index
		sheet.events.append(comment)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	all_passed = _check("no bookmarks, no jump", viewport.jump_to_bookmark(1), false) and all_passed
	viewport._select_row(0, -1)
	viewport.toggle_bookmark_selected()
	viewport._select_row(2, -1)
	viewport.toggle_bookmark_selected()
	var first_row: EventRowData = viewport.get_flat_rows()[0].get("row")
	all_passed = _check("bookmark flag set on the row", first_row.bookmark_enabled, true) and all_passed
	viewport._select_row(0, -1)
	all_passed = _check("F4 jumps forward", viewport.jump_to_bookmark(1), true) and all_passed
	all_passed = _check("forward jump lands on the next bookmark", viewport.get_selected_context().get("source_resource", null), sheet.events[2]) and all_passed
	all_passed = _check("forward jump wraps", viewport.jump_to_bookmark(1) and viewport.get_selected_context().get("source_resource", null) == sheet.events[0], true) and all_passed
	all_passed = _check("backward jump wraps", viewport.jump_to_bookmark(-1) and viewport.get_selected_context().get("source_resource", null) == sheet.events[2], true) and all_passed
	viewport.toggle_bookmark_selected()
	editor._refresh_after_edit()
	var refreshed_last: EventRowData = viewport.get_flat_rows()[2].get("row")
	all_passed = _check("toggle-off survives refresh (central sync)", refreshed_last.bookmark_enabled, false) and all_passed
	editor.free()

	# ── Includes ─────────────────────────────────────────────────────────────
	var library: EventSheetResource = EventSheetResource.new()
	library.variables = {"shared_score": {"type": "int", "default": 0, "exported": true}}
	var library_event: EventRow = EventRow.new()
	library_event.trigger_provider_id = "Core"
	library_event.trigger_id = "OnReady"
	var library_action: ACEAction = ACEAction.new()
	library_action.provider_id = "Test"
	library_action.ace_id = "lib"
	library_action.codegen_template = "library_setup()"
	library_event.actions.append(library_action)
	library.events.append(library_event)
	var library_function: EventFunction = EventFunction.new()
	library_function.function_name = "library_setup"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "shared_score = 0"
	library_function.events.append(body)
	library.functions.append(library_function)
	var save_error: Error = ResourceSaver.save(library, "user://eventsheets_include_lib.tres")
	all_passed = _check("library sheet saves", save_error, OK) and all_passed

	var root: EventSheetResource = EventSheetResource.new()
	root.includes = ["user://eventsheets_include_lib.tres"]
	root.variables = {"own_var": {"type": "int", "default": 1, "exported": false}}
	var compile_result: Dictionary = SheetCompiler.compile(root, "user://eventsheets_include_out.gd")
	var output: String = str(compile_result.get("output", ""))
	all_passed = _check("included variable emits", output.contains("@export var shared_score: int = 0"), true) and all_passed
	all_passed = _check("own variable still emits", output.contains("var own_var: int = 1"), true) and all_passed
	all_passed = _check("included event compiles", output.contains("library_setup()"), true) and all_passed
	all_passed = _check("included function compiles", output.contains("func library_setup() -> void:"), true) and all_passed
	all_passed = _check("included rows never enter the model", root.events.is_empty(), true) and all_passed

	# Collisions: root wins, with a warning.
	root.variables["shared_score"] = {"type": "int", "default": 99, "exported": false}
	var collision_result: Dictionary = SheetCompiler.compile(root, "user://eventsheets_include_coll.gd")
	all_passed = _check("root wins variable collisions",
		str(collision_result.get("output", "")).contains("var shared_score: int = 99"), true) and all_passed
	all_passed = _check("collision warns", str(collision_result.get("warnings", [])).contains("root wins"), true) and all_passed

	# Cycles: a sheet including itself terminates with a warning.
	var cyclic: EventSheetResource = EventSheetResource.new()
	cyclic.includes = ["user://eventsheets_include_cycle.tres"]
	var cycle_save: Error = ResourceSaver.save(cyclic, "user://eventsheets_include_cycle.tres")
	all_passed = _check("cyclic sheet saves", cycle_save, OK) and all_passed
	var loaded_cycle: EventSheetResource = load("user://eventsheets_include_cycle.tres")
	var cycle_result: Dictionary = SheetCompiler.compile(loaded_cycle, "user://eventsheets_include_cycle_out.gd")
	all_passed = _check("include cycles terminate with a warning",
		str(cycle_result.get("warnings", [])).contains("cycle"), true) and all_passed

	# Missing include: warning, not failure.
	var missing: EventSheetResource = EventSheetResource.new()
	missing.includes = ["user://does_not_exist.tres"]
	var missing_result: Dictionary = SheetCompiler.compile(missing, "user://eventsheets_include_missing.gd")
	all_passed = _check("missing includes warn but compile",
		bool(missing_result.get("success", false)) and str(missing_result.get("warnings", [])).contains("not found"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] bookmarks_includes_test: %s" % label)
		return true
	print("[FAIL] bookmarks_includes_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
