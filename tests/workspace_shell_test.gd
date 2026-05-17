# EventForge — restarted workspace shell tests
@tool
extends RefCounted
class_name WorkspaceShellTest

## Runs workspace shell tests.
static func run() -> bool:
    var all_passed: bool = true
    var editor: EventSheetEditor = EventSheetEditor.new()
    var scroll: Node = editor.find_child("EventSheetScroll", true, false)
    var viewport: Node = editor.find_child("EventSheetViewport", true, false)
    var split: Node = editor.find_child("EventSheetWorkspaceSplit", true, false)
    var side_panel: Node = editor.find_child("EventSheetSidePanel", true, false)
    all_passed = _check("workspace uses scroll container root", scroll is ScrollContainer, true) and all_passed
    all_passed = _check("workspace uses custom viewport renderer", viewport is EventSheetViewport, true) and all_passed
    all_passed = _check("workspace uses split layout shell", split is HSplitContainer, true) and all_passed
    all_passed = _check("workspace exposes side panel", side_panel is VBoxContainer, true) and all_passed
    all_passed = _check("scroll has exactly one child", scroll != null and scroll.get_child_count() == 1, true) and all_passed
    all_passed = _check("viewport supports selection API", viewport != null and viewport.has_signal("selection_changed"), true) and all_passed
    all_passed = _check("viewport supports row drop API", viewport != null and viewport.has_signal("row_drop_requested"), true) and all_passed
    all_passed = _check("viewport supports multi-row drop API", viewport != null and viewport.has_signal("rows_drop_requested"), true) and all_passed
    all_passed = _check("viewport supports ace drop API", viewport != null and viewport.has_signal("ace_drop_requested"), true) and all_passed
    all_passed = _check("viewport supports ace edit API", viewport != null and viewport.has_signal("ace_edit_requested"), true) and all_passed
    all_passed = _check("viewport supports context menu API", viewport != null and viewport.has_signal("context_menu_requested"), true) and all_passed
    all_passed = _check("viewport exposes editor state scaffold", viewport != null and viewport.has_method("get_editor_state_snapshot"), true) and all_passed
    all_passed = _check("viewport exposes disabled row scaffold", viewport != null and viewport.has_method("set_row_disabled"), true) and all_passed
    editor.set_size(Vector2(1200.0, 720.0))
    editor._sync_workspace_layout()
    all_passed = _check(
        "side panel minimum width stays compact",
        side_panel != null and side_panel.custom_minimum_size.x <= 160.0,
        true
    ) and all_passed
    all_passed = _check(
        "split keeps most width for the sheet canvas",
        split != null and split.split_offset >= 980,
        true
    ) and all_passed
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
