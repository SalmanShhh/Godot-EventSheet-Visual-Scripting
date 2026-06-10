# Godot EventSheets — Godot-feel batch: find-in-sheet, script-editor shortcuts
# (F9 breakpoint, Ctrl+/ toggle-enabled, Alt+Up/Down move), and editor-theme inheritance
# (default tokens derived from the user's base/accent editor colors).
@tool
extends RefCounted
class_name GodotFeelTest

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

	# ── Theme derivation (pure; relations, not absolute colors) ──────────────
	var dark: EventSheetEditorStyle = EventSheetEditorThemeDeriver.derive(Color(0.13, 0.14, 0.17), Color(0.27, 0.55, 0.89))
	all_passed = _check("dark editors derive a darker sheet background",
		dark.event_style.sheet_background_color.v < 0.17, true) and all_passed
	all_passed = _check("selection inherits the accent hue",
		is_equal_approx(dark.event_style.selection_fill_color.r, 0.27) and dark.event_style.selection_fill_color.a < 0.5, true) and all_passed
	all_passed = _check("accent drives the group identity",
		dark.event_style.group_accent_color, Color(0.27, 0.55, 0.89)) and all_passed
	var light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.derive(Color(0.9, 0.9, 0.9), Color(0.2, 0.4, 0.8))
	all_passed = _check("light editors derive a lighter background",
		light.event_style.sheet_background_color.v > 0.85, true) and all_passed
	all_passed = _check("derive_from_editor is editor-only",
		EventSheetEditorThemeDeriver.derive_from_editor() == null, true) and all_passed

	# ── Sheet with mixed rows ────────────────────────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	var first: CommentRow = CommentRow.new()
	first.text = "movement setup"
	sheet.events.append(first)
	var second: CommentRow = CommentRow.new()
	second.text = "score handling"
	sheet.events.append(second)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "velocity.x = speed"
	sheet.events.append(block)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# Find: span text + block code both searchable, case-insensitive.
	all_passed = _check("find matches span text", viewport.search_rows("SCORE").size(), 1) and all_passed
	all_passed = _check("find matches GDScript block code", viewport.search_rows("velocity.x").size(), 1) and all_passed
	all_passed = _check("empty queries match nothing", viewport.search_rows("  ").size(), 0) and all_passed

	# Find-step cycles through matches with wrap-around.
	editor._ensure_find_bar()
	editor._find_edit.text = "o"
	editor._on_find_text_changed("o")
	var first_hit: int = editor._find_matches[0] if not editor._find_matches.is_empty() else -1
	all_passed = _check("typing jumps to the first match",
		viewport.get_selected_context().get("row_index", -1), first_hit) and all_passed
	var match_count: int = editor._find_matches.size()
	for step in range(match_count):
		editor._find_step(1)
	all_passed = _check("stepping wraps back around",
		viewport.get_selected_context().get("row_index", -1), first_hit) and all_passed

	# Ctrl+/: toggles enabled on the model (undoable path).
	viewport._select_row(0, -1)
	editor._toggle_selected_rows_enabled()
	all_passed = _check("toggle disables the selected row", first.enabled, false) and all_passed
	editor._toggle_selected_rows_enabled()
	all_passed = _check("toggle re-enables", first.enabled, true) and all_passed

	# Alt+Down: moves the selected row past its neighbor.
	viewport._select_row(0, -1)
	editor._move_selected_row(1)
	all_passed = _check("move-down reorders the model", sheet.events[0], second) and all_passed
	all_passed = _check("moved row sits below its old neighbor", sheet.events[1], first) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] godot_feel_test: %s" % label)
		return true
	print("[FAIL] godot_feel_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
