# EventForge - restarted workspace shell tests
@tool
class_name WorkspaceShellTest
extends RefCounted


## Runs workspace shell tests.
static func run() -> bool:
    var all_passed: bool = true
    var editor: EventSheetEditor = EventSheetEditor.new()
    var workspace_root: Node = editor.find_child("EventSheetWorkspaceRoot", true, false)
    var scroll: Node = editor.find_child("EventSheetScroll", true, false)
    var viewport: Node = editor.find_child("EventSheetViewport", true, false)
    var preview_window: Node = editor.find_child("ACEPreviewWindow", true, false)
    all_passed = _check("workspace root exists", workspace_root is VBoxContainer, true) and all_passed
    all_passed = _check("workspace uses scroll container root", scroll is ScrollContainer, true) and all_passed
    all_passed = _check("workspace uses custom viewport renderer", viewport is EventSheetViewport, true) and all_passed
    all_passed = _check("scroll has exactly one child", scroll != null and scroll.get_child_count() == 1, true) and all_passed
    all_passed = _check("workspace exposes popup ace preview window", preview_window is Window, true) and all_passed
    all_passed = _check("viewport supports selection API", viewport != null and viewport.has_signal("selection_changed"), true) and all_passed
    all_passed = _check("viewport supports row drop API", viewport != null and viewport.has_signal("row_drop_requested"), true) and all_passed
    all_passed = _check("viewport supports multi-row drop API", viewport != null and viewport.has_signal("rows_drop_requested"), true) and all_passed
    all_passed = _check("viewport supports ace drop API", viewport != null and viewport.has_signal("ace_drop_requested"), true) and all_passed
    all_passed = _check("viewport supports ace edit API", viewport != null and viewport.has_signal("ace_edit_requested"), true) and all_passed
    all_passed = _check("viewport supports context menu API", viewport != null and viewport.has_signal("context_menu_requested"), true) and all_passed
    all_passed = _check("viewport supports empty-space context menu API", viewport != null and viewport.has_signal("empty_space_context_menu_requested"), true) and all_passed
    all_passed = _check("viewport supports empty-space double-click API", viewport != null and viewport.has_signal("empty_space_double_clicked"), true) and all_passed
    all_passed = _check("viewport exposes editor state scaffold", viewport != null and viewport.has_method("get_editor_state_snapshot"), true) and all_passed
    all_passed = _check("viewport exposes zoom getter", viewport != null and viewport.has_method("get_zoom_factor"), true) and all_passed
    all_passed = _check("viewport exposes zoom controls", viewport != null and viewport.has_method("zoom_in") and viewport.has_method("zoom_out"), true) and all_passed
    all_passed = _check("viewport exposes disabled row scaffold", viewport != null and viewport.has_method("set_row_disabled"), true) and all_passed
    editor.set_size(Vector2(1200.0, 720.0))
    all_passed = _check(
        "workspace root is anchored to fill editor",
        workspace_root != null
            and is_equal_approx((workspace_root as Control).anchor_right, 1.0)
            and is_equal_approx((workspace_root as Control).anchor_bottom, 1.0),
        true
    ) and all_passed
    all_passed = _check(
        "scroll fills editor workspace width",
        scroll != null and scroll.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
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
