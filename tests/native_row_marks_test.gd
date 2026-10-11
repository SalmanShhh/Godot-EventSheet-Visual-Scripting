@tool
extends RefCounted
# Godot EventSheets - the drawn marks of an event row
#
# The trigger icon beside an event's number, the System and input glyphs in the object column, the
# hairline after the object column, the grip on the hovered event's lane divider, and the word
# colour a variable name wears inside a sentence. All of them are paint: none is a span, none is
# measured, so the pins here are the VALUES each mark is decided and placed by:
#   1. which trigger kind an event draws, and which editor icon stands for it;
#   2. where the icon sits - inside the slot every event row already reserves, clear of the margin
#      and of the condition lane;
#   3. which object labels wear their own glyph;
#   4. the hairline's and the grip's geometry;
#   5. where a sheet's own variable names are found in a sentence, in every spelling, and how those
#      ranges join the value ranges the painter walks;
#   6. that the row builder stamps them, and the tone of a grammar-read piece, without touching a
#      span's text;
#   7. that a variable added to the SAME sheet object (an ordinary edit changes the sheet in place)
#      colours on the next row build, and a renamed one stops colouring under its old name.

const SUPPORT := preload("res://tests/support.gd")
const NativeRowMarks := preload("res://addons/eventsheet/editor/interaction/native_row_marks.gd")
const TEST_NAME := "native_row_marks_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_trigger_kinds() and ok
	ok = _test_trigger_icon_place() and ok
	ok = _test_object_glyphs() and ok
	ok = _test_hairline_and_grip() and ok
	ok = _test_variable_words() and ok
	ok = _test_builder_stamps_paint_metadata() and ok
	ok = _test_variable_added_in_place_colours_next_build() and ok
	return ok


static func _test_trigger_kinds() -> bool:
	var else_row := EventRowData.new()
	var else_event := EventRow.new()
	else_event.trigger_id = "OnProcess"
	else_event.else_mode = EventRow.ElseMode.ELSE
	else_row.source_resource = else_event
	var ready_row := EventRowData.new()
	var ready_event := EventRow.new()
	ready_event.trigger_id = "OnReady"
	ready_row.source_resource = ready_event
	var group_row := EventRowData.new()
	group_row.row_type = EventRowData.RowType.GROUP
	group_row.source_resource = ready_event
	return SUPPORT.pins(TEST_NAME, [
		["On ready is the start icon", NativeRowMarks.trigger_kind_for_id("OnReady"), "ready"],
		["entering the tree runs once too", NativeRowMarks.trigger_kind_for_id("OnEnterTree"), "ready"],
		["Every tick", NativeRowMarks.trigger_kind_for_id("OnProcess"), "tick"],
		["Every physics tick is told apart from the tick", NativeRowMarks.trigger_kind_for_id("OnPhysicsProcess"), "physics"],
		["a floor edge is a physics-step moment", NativeRowMarks.trigger_kind_for_id("OnLanded"), "physics"],
		["an input handler", NativeRowMarks.trigger_kind_for_id("OnUnhandledInput"), "input"],
		["a custom signal", NativeRowMarks.trigger_kind_for_id("signal:died"), "signal"],
		["an engine notification", NativeRowMarks.trigger_kind_for_id("OnNotification:NOTIFICATION_PAUSED"), "other"],
		["no trigger, no icon", NativeRowMarks.trigger_kind_for_id(""), ""],
		["an event row reads its own trigger", NativeRowMarks.trigger_kind(ready_row), "ready"],
		["an Else block never repeats its trigger", NativeRowMarks.trigger_kind(else_row), ""],
		["a group row draws none", NativeRowMarks.trigger_kind(group_row), ""],
		["the editor icons, by kind", NativeRowMarks.TRIGGER_EDITOR_ICONS, {
			"ready": "Play", "tick": "Reload", "signal": "Signal", "other": "Notification"}],
		["every kind says what it means on hover", [
			NativeRowMarks.trigger_tooltip("ready"), NativeRowMarks.trigger_tooltip("tick"),
			NativeRowMarks.trigger_tooltip("physics"), NativeRowMarks.trigger_tooltip("input"),
			NativeRowMarks.trigger_tooltip("signal"), NativeRowMarks.trigger_tooltip("other"),
			NativeRowMarks.trigger_tooltip("")], [
			"Runs once, when the node starts (On ready).", "Runs every frame (Every tick).",
			"Runs every physics step (Every physics tick).",
			"Runs when input arrives - a key, a button, the mouse.", "Runs when a signal is emitted.",
			"Runs when the engine sends this notification.", ""]],
	])


static func _test_trigger_icon_place() -> bool:
	var row_rect := Rect2(0.0, 100.0, 800.0, 24.0)
	var top_level: Rect2 = NativeRowMarks.trigger_icon_rect(row_rect, 0, 18)
	var nested: Rect2 = NativeRowMarks.trigger_icon_rect(row_rect, 2, 18)
	# The condition lane of a top-level event starts at padding + margin + the 18 px slot.
	var lane_start: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + float(EventSheetPalette.GUTTER_WIDTH) + 18.0
	return SUPPORT.pins(TEST_NAME, [
		["a top-level event's icon, centred on its row", top_level, Rect2(32.0, 105.0, 14.0, 14.0)],
		["a nested event's icon moves with its indent", nested, Rect2(68.0, 105.0, 14.0, 14.0)],
		["the icon starts right of the margin", top_level.position.x > float(EventSheetPalette.GUTTER_WIDTH), true],
		["the icon ends before the condition lane", top_level.end.x <= lane_start, true],
	])


static func _test_object_glyphs() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["System wears the gear", NativeRowMarks.object_glyph_for("System"), "system"],
		["Keyboard wears the keyboard", NativeRowMarks.object_glyph_for("Keyboard"), "keyboard"],
		["Mouse", NativeRowMarks.object_glyph_for("Mouse"), "mouse"],
		["Gamepad", NativeRowMarks.object_glyph_for("Gamepad"), "gamepad"],
		["Touch", NativeRowMarks.object_glyph_for("Touch"), "touch"],
		["a node keeps its class icon", NativeRowMarks.object_glyph_for("Player"), ""],
		["the label that reads input actions wears the keyboard", NativeRowMarks.object_glyph_for("Input"), "keyboard"],
	])


static func _test_hairline_and_grip() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["the hairline stands short of a row's top and bottom",
			NativeRowMarks.object_hairline_rect(Rect2(100.0, 10.0, 80.0, 24.0), 150.0), Rect2(147.0, 15.0, 1.0, 14.0)],
		["a short cell keeps a near full-height line",
			NativeRowMarks.object_hairline_rect(Rect2(100.0, 10.0, 80.0, 12.0), 150.0), Rect2(147.0, 11.0, 1.0, 10.0)],
		["three grip dots, centred on the divider",
			NativeRowMarks.grip_dot_centres(Rect2(400.0, 0.0, 7.0, 24.0)),
			PackedVector2Array([Vector2(403.5, 6.0), Vector2(403.5, 12.0), Vector2(403.5, 18.0)])],
		["a hairline divider holds no grip", NativeRowMarks.grip_dot_centres(Rect2(400.0, 0.0, 2.0, 24.0)), PackedVector2Array()],
		["dot size on a wide divider", NativeRowMarks.grip_dot_size(7.0), 3.0],
		["dot size on a narrow one", NativeRowMarks.grip_dot_size(3.0), 2.0],
	])


static func _test_variable_words() -> bool:
	var regex: RegEx = NativeRowMarks.variable_names_regex(PackedStringArray(["open_speed", "open_progress", "x"]))
	var sentence: String = "Add Open Speed × delta to Open Progress"
	return SUPPORT.pins(TEST_NAME, [
		["the Inspector spelling is found", NativeRowMarks.variable_word_ranges(sentence, regex),
			[[4, 10, "variable"], [26, 13, "variable"]]],
		["the name as written is found", NativeRowMarks.variable_word_ranges("open_speed * delta", regex),
			[[0, 10, "variable"]]],
		["the humanized-names spelling is found", NativeRowMarks.variable_word_ranges("set open progress", regex),
			[[4, 13, "variable"]]],
		["never inside a longer word", NativeRowMarks.variable_word_ranges("reopen_speed", regex), []],
		["a one-letter name is never coloured", NativeRowMarks.variable_word_ranges("x = 3", regex), []],
		["only inside the parameters, where the row knows them",
			NativeRowMarks.variable_word_ranges("Set open_speed to open_speed", regex, [[18, 10]]), [[18, 10, "variable"]]],
		["a sheet with no variables finds nothing", NativeRowMarks.variable_names_regex(PackedStringArray()), null],
		["a value range wins an overlap, the rest join in order",
			NativeRowMarks.merged_word_ranges([[6, 1, "number"]], [[0, 3, "variable"], [5, 4, "variable"]]),
			[[0, 3, "variable"], [6, 1, "number"]]],
		["no variable ranges leave the value ranges as they were",
			NativeRowMarks.merged_word_ranges([[6, 1, "number"]], []), [[6, 1, "number"]]],
	])


static func _test_builder_stamps_paint_metadata() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet := EventSheetResource.new()
	var variable := LocalVariable.new()
	variable.name = "open_speed"
	sheet.events.append(variable)
	viewport._sheet = sheet
	var action: SemanticSpan = viewport._make_span("Add open speed to score", SemanticSpan.SpanType.ACTION, {"kind": "action"})
	var comment: SemanticSpan = viewport._make_span("open speed", SemanticSpan.SpanType.COMMENT, {"kind": "comment"})
	var pieces: Array = viewport._row_builder.grammar_bbcode_segments([{"text": "speed", "tone": "name"}, {"text": " = 2", "tone": "value"}])
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["an action sentence carries where the variable is", action.metadata.get("variable_ranges", []), [[4, 10, "variable"]]],
		["and its text is untouched", action.text, "Add open speed to score"],
		["a comment is not searched", comment.metadata.has("variable_ranges"), false],
		["a grammar piece keeps its tone for the painter", [str(pieces[0].get("tone")), str(pieces[1].get("tone"))], ["name", "value"]],
	])
	viewport.free()
	return ok


static func _test_variable_added_in_place_colours_next_build() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet := EventSheetResource.new()
	var variable := LocalVariable.new()
	variable.name = "open_speed"
	sheet.events.append(variable)
	viewport._sheet = sheet
	var before: SemanticSpan = viewport._make_span("Add jump height to score", SemanticSpan.SpanType.ACTION, {"kind": "action"})
	# The edit an undoable sheet edit makes: the same sheet object, one more variable, one renamed.
	var added := LocalVariable.new()
	added.name = "jump_height"
	sheet.events.append(added)
	variable.name = "close_speed"
	viewport._row_builder.invalidate_lens_caches()
	var after: SemanticSpan = viewport._make_span("Add jump height to score", SemanticSpan.SpanType.ACTION, {"kind": "action"})
	var renamed: SemanticSpan = viewport._make_span("Add open speed to score", SemanticSpan.SpanType.ACTION, {"kind": "action"})
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["before the edit the new name is not a variable", before.metadata.get("variable_ranges", []), []],
		["after the next build it colours", after.metadata.get("variable_ranges", []), [[4, 11, "variable"]]],
		["and the old name of a renamed variable no longer does", renamed.metadata.get("variable_ranges", []), []],
	])
	viewport.free()
	return ok
