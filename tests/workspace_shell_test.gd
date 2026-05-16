# EventForge — Workspace shell behavior tests
# Covers toolbar save signals, dirty indicator, status bar routing, and
# the document-editor shell additions introduced for issue #59.
@tool
extends RefCounted
class_name WorkspaceShellTest

## Runs workspace shell tests.
static func run() -> bool:
	var all_passed: bool = true

	# ── SheetToolbar: save signals ────────────────────────────────────────────
	var toolbar: SheetToolbar = SheetToolbar.new()
	all_passed = _check(
		"toolbar has save_requested signal",
		toolbar.has_signal("save_requested"),
		true
	) and all_passed
	all_passed = _check(
		"toolbar has save_as_requested signal",
		toolbar.has_signal("save_as_requested"),
		true
	) and all_passed

	# ── Dirty indicator: starts hidden ────────────────────────────────────────
	all_passed = _check(
		"dirty indicator not null",
		toolbar._dirty_indicator != null,
		true
	) and all_passed
	all_passed = _check(
		"dirty indicator hidden initially",
		toolbar._dirty_indicator.visible,
		false
	) and all_passed

	# ── set_dirty shows / hides indicator ─────────────────────────────────────
	toolbar.set_dirty(true)
	all_passed = _check(
		"dirty indicator visible after set_dirty(true)",
		toolbar._dirty_indicator.visible,
		true
	) and all_passed

	toolbar.set_dirty(false)
	all_passed = _check(
		"dirty indicator hidden after set_dirty(false)",
		toolbar._dirty_indicator.visible,
		false
	) and all_passed

	# ── set_sheet_loaded clears dirty ─────────────────────────────────────────
	toolbar.set_dirty(true)
	toolbar.set_sheet_loaded(false)
	all_passed = _check(
		"set_sheet_loaded(false) clears dirty indicator",
		toolbar._dirty_indicator.visible,
		false
	) and all_passed

	# ── Save buttons disabled without a loaded sheet ──────────────────────────
	all_passed = _check(
		"save btn not null",
		toolbar._save_btn != null,
		true
	) and all_passed
	all_passed = _check(
		"save btn disabled without sheet",
		toolbar._save_btn.disabled,
		true
	) and all_passed
	all_passed = _check(
		"save_as btn disabled without sheet",
		toolbar._save_as_btn.disabled,
		true
	) and all_passed

	toolbar.set_sheet_loaded(true)
	all_passed = _check(
		"save btn enabled with loaded sheet",
		toolbar._save_btn.disabled,
		false
	) and all_passed
	all_passed = _check(
		"save_as btn enabled with loaded sheet",
		toolbar._save_as_btn.disabled,
		false
	) and all_passed

	# ── Shortcuts hint includes Ctrl+S ────────────────────────────────────────
	all_passed = _check(
		"shortcut hint includes Ctrl+S Save",
		SheetToolbar.shortcut_hint_text().find("Ctrl+S") != -1,
		true
	) and all_passed

	# ── format_document_meta unchanged ────────────────────────────────────────
	all_passed = _check(
		"toolbar meta null sheet",
		SheetToolbar.format_document_meta(null),
		"No sheet loaded"
	) and all_passed
	all_passed = _check(
		"toolbar path null sheet",
		SheetToolbar.format_document_path(null),
		"No path"
	) and all_passed
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables["hp"] = {"type": "int", "default": 100}
	all_passed = _check(
		"toolbar meta with 1 var 0 events",
		SheetToolbar.format_document_meta(sheet),
		"1 globals · 0 root rows"
	) and all_passed
	all_passed = _check(
		"toolbar path unsaved sheet",
		SheetToolbar.format_document_path(sheet),
		"Unsaved (in-memory)"
	) and all_passed
	sheet.take_over_path("res://demo/workspace_shell_test_sheet.tres")
	all_passed = _check(
		"toolbar path saved sheet",
		SheetToolbar.format_document_path(sheet),
		"res://demo/workspace_shell_test_sheet.tres"
	) and all_passed
	toolbar.set_context(sheet, "none")
	all_passed = _check(
		"toolbar path label follows context",
		toolbar._sheet_path_label.text,
		"res://demo/workspace_shell_test_sheet.tres"
	) and all_passed

	# ── EventSheetEditor: dirty state flag ────────────────────────────────────
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.current_sheet = EventSheetResource.new()
	var workspace_split: Node = editor.find_child("WorkspaceSplit", true, false)
	all_passed = _check(
		"editor uses central split container shell",
		workspace_split is HSplitContainer,
		true
	) and all_passed
	var resource_tab: Node = editor.find_child("SheetCanvasResourceTab", true, false)
	all_passed = _check(
		"canvas document strip includes resource tab shell",
		resource_tab is PanelContainer,
		true
	) and all_passed
	all_passed = _check(
		"inspector shell is compact",
		editor._inspector_panel != null and editor._inspector_panel.custom_minimum_size.x <= 200.0,
		true
	) and all_passed
	all_passed = _check(
		"editor not dirty initially",
		editor._is_dirty,
		false
	) and all_passed

	editor._mark_dirty()
	all_passed = _check(
		"editor is dirty after _mark_dirty",
		editor._is_dirty,
		true
	) and all_passed

	editor._clear_dirty()
	all_passed = _check(
		"editor not dirty after _clear_dirty",
		editor._is_dirty,
		false
	) and all_passed

	# Repeated _mark_dirty calls should be idempotent (no double-toggle).
	editor._mark_dirty()
	editor._mark_dirty()
	all_passed = _check(
		"editor still dirty after double _mark_dirty",
		editor._is_dirty,
		true
	) and all_passed

	toolbar.free()
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] workspace_shell_test: %s" % label)
		return true
	print("[FAIL] workspace_shell_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
