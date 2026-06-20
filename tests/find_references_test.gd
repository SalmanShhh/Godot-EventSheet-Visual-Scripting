# Godot EventSheets — symbol-aware Find References test.
# Proves whole-symbol matching (\bname\b) so `speed` finds the variable `speed` but never
# `move_speed`, that definitions resolve, and that the rename preview counts what it'll touch.
@tool
extends RefCounted
class_name FindReferencesTest

static func run() -> bool:
    var passed: bool = true
    var sheet: EventSheetResource = EventSheetResource.new()
    sheet.variables = {
        "speed": {"type": "float", "default": 1.0},
        "move_speed": {"type": "float", "default": 2.0}
    }
    var e1: EventRow = EventRow.new()
    var c1: RawCodeRow = RawCodeRow.new()
    c1.code = "host.velocity.x = speed"
    e1.actions.append(c1)
    sheet.events.append(e1)
    var e2: EventRow = EventRow.new()
    var c2: RawCodeRow = RawCodeRow.new()
    c2.code = "host.velocity.x = move_speed * 2.0"
    e2.actions.append(c2)
    sheet.events.append(e2)
    var comment: CommentRow = CommentRow.new()
    comment.text = "tune the speed here"
    sheet.events.append(comment)

    var refs: Array = EventSheetFindReferences.find_in_sheet(sheet, "speed")
    var total: int = 0
    var matched_move: bool = false
    for reference: Dictionary in refs:
        total += int(reference.get("count", 0))
        if str(reference.get("preview", "")).contains("move_speed"):
            matched_move = true
    # `speed` matches the code usage + the comment word, but NOT move_speed.
    passed = _check("whole-word find matches speed (code + comment), not move_speed", total, 2) and passed
    passed = _check("move_speed is not a false-positive reference to speed", matched_move, false) and passed

    var refs_move: Array = EventSheetFindReferences.find_in_sheet(sheet, "move_speed")
    var total_move: int = 0
    for reference: Dictionary in refs_move:
        total_move += int(reference.get("count", 0))
    passed = _check("move_speed is found as its own symbol", total_move, 1) and passed

    passed = _check("speed resolves to a variable definition",
        str(EventSheetFindReferences.find_definition(sheet, "speed").get("kind", "")), "variable") and passed
    passed = _check("an unknown symbol has no definition",
        bool(EventSheetFindReferences.find_definition(sheet, "nope").get("found", true)), false) and passed

    var preview: Dictionary = EventSheetFindReferences.rename_preview(sheet, "speed", "velocity_scale")
    passed = _check("rename preview counts the references it'll touch", int(preview.get("reference_count", -1)), 2) and passed
    passed = _check("rename preview validates the new name", bool(preview.get("valid", false)), true) and passed

    return passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] find_references_test: %s" % label)
        return true
    print("[FAIL] find_references_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
