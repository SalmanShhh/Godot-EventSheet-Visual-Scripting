# EventForge - error-line → row jump. Paste a Godot error or stack-trace line into the command
# palette ("res://….gd:42" anywhere in the text) and its one entry opens that .gd AS A SHEET and
# selects the row that emitted the line (via the line↔row mapper) - a runtime error pastes straight
# back onto the event that caused it. Pins the pure parser (full error lines, quoted paths, no-line
# and non-script text fail closed), the mode dispatch (an error line wins over command fuzzing), and
# the end-to-end jump on a real pack.
@tool
class_name PaletteErrorJumpTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The parser ──
	var direct: Dictionary = EventSheetCommandPalette.parse_error_location("res://game/gen.gd:17")
	ok = _check("bare path:line parses", str(direct.get("path", "")) + "#" + str(direct.get("line", 0)), "res://game/gen.gd#17") and ok
	var stack_line: Dictionary = EventSheetCommandPalette.parse_error_location(
		"SCRIPT ERROR: Invalid operands. at: _process (res://eventsheet_addons/health/health_behavior.gd:97)")
	ok = _check("a full Output-panel error line parses",
		str(stack_line.get("path", "")), "res://eventsheet_addons/health/health_behavior.gd") and ok
	ok = _check("the line rides along", int(stack_line.get("line", 0)), 97) and ok
	ok = _check("quoted paths parse",
		int(EventSheetCommandPalette.parse_error_location("at \"res://a/b.gd:3\"").get("line", 0)), 3) and ok
	ok = _check("a path with no line fails closed",
		EventSheetCommandPalette.parse_error_location("res://a/b.gd is broken").is_empty(), true) and ok
	ok = _check("plain text fails closed",
		EventSheetCommandPalette.parse_error_location("add event").is_empty(), true) and ok

	# ── Dispatch + the end-to-end jump on a real pack ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	# Find the real line of take_damage's body so the assertion tracks the file, not a magic number.
	var pack_lines: PackedStringArray = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text().split("\n")
	var body_line: int = -1
	for line_index: int in range(pack_lines.size()):
		if pack_lines[line_index].begins_with("func take_damage"):
			body_line = line_index + 2  # a line INSIDE the body, 1-based
			break
	ok = _check("found take_damage in the pack", body_line > 0, true) and ok

	dock._command_palette._refresh_command_palette("at: take_damage (%s:%d)" % [pack_path, body_line])
	var matches: Array = dock._command_palette._command_palette_matches
	ok = _check("an error line produces exactly one palette entry", matches.size(), 1) and ok
	ok = _check("the entry names the jump", str((matches[0] as Dictionary).get("title", "")).contains("health_behavior.gd:%d" % body_line), true) and ok

	((matches[0] as Dictionary).get("run") as Callable).call()
	ok = _check("the pack opened as a sheet", dock.get_current_sheet().external_source_path, pack_path) and ok
	var selected: Resource = dock._active_view().get_selected_context().get("source_resource", null)
	ok = _check("a row was selected", selected != null, true) and ok
	# take_damage lifts as a REAL EventFunction now, so the jump lands on its Define block - the
	# reveal path unfolds the Published verbs section to reach it.
	ok = _check("the selected row is the one that emitted the line (take_damage's Define block)",
		selected is EventFunction and (selected as EventFunction).function_name == "take_damage", true) and ok

	# ── Commands still fuzz when there's no location ──
	dock._command_palette._refresh_command_palette("add event")
	ok = _check("plain queries still fuzzy-match commands",
		str((dock._command_palette._command_palette_matches[0] as Dictionary).get("title", "")), "Add Event") and ok

	dock.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] palette_error_jump_test: %s" % label)
		return true
	print("[FAIL] palette_error_jump_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
