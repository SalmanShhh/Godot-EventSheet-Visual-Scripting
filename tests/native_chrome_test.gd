@tool
extends RefCounted
# Godot EventSheets - the Editor Native chrome: tabs over the strip, the status bar's selection line,
# comments drawn as notes, the selection drawn as a gutter and a frame
#
# Four theme switches, off by default, on in the Editor Native starter and its rule and stated off in
# every other shipped theme. Pinned here as values:
#   1. the switches: on in the starter and the derived native look, off in Classic Sheet and by default,
#      and the status bar's ok colour clear unless the theme states it;
#   2. tabs_above_toolbar puts the TabBar over the strip in the dock's column, and a quiet theme keeps
#      it under the strip, where the dock was built;
#   3. status_bar_selection_line says "Event 3 selected · <trigger, conditions>" at the strip's left
#      edge and paints No problems in the ok colour; a quiet theme keeps "event 3 of 9" by the counts;
#   4. comment_notes leads a comment row with the note's grip-and-bubble span and drops its echo, and
#      draws an action-lane comment as a note without its "#" (its words inset past the lead); a quiet
#      theme keeps the echo and the marker;
#   5. selection_as_outline frames a selected event in its gutter's hue a step brighter (#2c5d87
#      frames as #3979b0, a hair from the design's #3a72b0).

const SUPPORT := preload("res://tests/support.gd")
const NativeRowMarks := preload("res://addons/eventsheet/editor/interaction/native_row_marks.gd")
const TEST_NAME := "native_chrome_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_switches() and ok
	ok = _test_tabs_over_the_strip() and ok
	ok = _test_the_selection_line() and ok
	ok = _test_the_status_layout() and ok
	ok = _test_comment_notes() and ok
	ok = _test_the_selection_frame() and ok
	EventSheetActiveTheme.publish(null)
	return ok


static func _test_the_switches() -> bool:
	var native: EventSheetEditorStyle = load(NATIVE_THEME) as EventSheetEditorStyle
	var classic: EventSheetEditorStyle = load(CLASSIC_THEME) as EventSheetEditorStyle
	var derived: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color("#363d4a"))
	var defaults := EventSheetEditorStyle.new()
	return SUPPORT.pins(TEST_NAME, [
		["the starter's four switches", [native.tabs_above_toolbar, native.status_bar_selection_line,
			native.get_event_style().comment_notes, native.get_event_style().selection_as_outline],
			[true, true, true, true]],
		["the derived native look's", [derived.tabs_above_toolbar, derived.status_bar_selection_line,
			derived.get_event_style().comment_notes, derived.get_event_style().selection_as_outline],
			[true, true, true, true]],
		["Classic Sheet's", [classic.tabs_above_toolbar, classic.status_bar_selection_line,
			classic.get_event_style().comment_notes, classic.get_event_style().selection_as_outline],
			[false, false, false, false]],
		["and the defaults", [defaults.tabs_above_toolbar, defaults.status_bar_selection_line,
			defaults.get_event_style().comment_notes, defaults.get_event_style().selection_as_outline],
			[false, false, false, false]],
		["the starter's ok colour is the design's green",
			native.get_chrome_style().status_ok_color.to_html(false), "8fc27a"],
		["the derived dark look's too", derived.get_chrome_style().status_ok_color, Color("#8fc27a")],
		["the light look's is deeper", EventSheetEditorThemeDeriver.native_style(Color("#f2f2f2"))
			.get_chrome_style().status_ok_color, Color("#2f6b1f")],
		["clear by default", defaults.get_chrome_style().status_ok_color, Color(0.0, 0.0, 0.0, 0.0)],
		["and clear in Classic Sheet", classic.get_chrome_style().status_ok_color, Color(0.0, 0.0, 0.0, 0.0)],
	])


static func _test_tabs_over_the_strip() -> bool:
	var native: EventSheetEditor = _editor(NATIVE_THEME, EventSheetResource.new())
	var classic: EventSheetEditor = _editor(CLASSIC_THEME, EventSheetResource.new())
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Editor Native stacks the tabs over the strip",
			native._tab_bar.get_index() < native._toolbar.get_index(), true],
		["directly over it", native._toolbar.get_index() - native._tab_bar.get_index(), 1],
		["Classic Sheet keeps them under the strip, as the dock was built",
			classic._tab_bar.get_index() - classic._toolbar.get_index(), 1],
	])
	# A theme switch moves them back, and a second publish of the same theme moves nothing.
	EventSheetActiveTheme.publish(load(CLASSIC_THEME) as EventSheetEditorStyle)
	native._menu_bar.apply_theme_chrome()
	var after_switch: int = native._tab_bar.get_index() - native._toolbar.get_index()
	native._menu_bar.apply_theme_chrome()
	ok = SUPPORT.pins(TEST_NAME, [
		["switching to a quiet theme puts them back under the strip", after_switch, 1],
		["and asking again moves nothing", native._tab_bar.get_index() - native._toolbar.get_index(), 1],
	]) and ok
	native.free()
	classic.free()
	return ok


static func _test_the_selection_line() -> bool:
	var row := EventRowData.new()
	row.event_number = 3
	row.spans = [
		_span("Every tick", {"kind": "trigger", "lane": "condition"}),
		_span("Keyboard", {"badge": true, "lane": "condition"}),
		_span("Space is down", {"kind": "condition", "lane": "condition"}),
		_span("Log \"Space held\"", {"kind": "action", "lane": "action"}),
		_span("Add condition", {"kind": "add_condition", "lane": "condition"}),
	]
	var bare := EventRowData.new()
	bare.event_number = 7
	var comment := EventRowData.new()
	comment.row_type = EventRowData.RowType.COMMENT
	return SUPPORT.pins(TEST_NAME, [
		["the design's status line", EventSheetDock.selection_line_text(row),
			"Event 3 selected · Every tick, Space is down"],
		["an event with no conditions says only which it is", EventSheetDock.selection_line_text(bare),
			"Event 7 selected"],
		["a row the margin does not number says nothing", EventSheetDock.selection_line_text(comment), ""],
		["and no selection says nothing", EventSheetDock.selection_line_text(null), ""],
	])


static func _test_the_status_layout() -> bool:
	var native: EventSheetEditor = _editor(NATIVE_THEME, _sheet_with_events(3))
	_select_event(native, 2)
	var native_index: int = native._row_address_label.get_index()
	var native_text: String = native._row_address_label.text
	var ok_colour: Color = native._problem_count_label.modulate
	native.free()
	var classic: EventSheetEditor = _editor(CLASSIC_THEME, _sheet_with_events(3))
	_select_event(classic, 2)
	var classic_after_count: int = classic._row_address_label.get_index() - classic._event_count_label.get_index()
	var classic_text: String = classic._row_address_label.text
	var classic_colour: Color = classic._problem_count_label.modulate
	classic.free()
	return SUPPORT.pins(TEST_NAME, [
		["Editor Native says what is selected at the strip's left edge", native_index, 0],
		["in the sheet's words", native_text.begins_with("Event 2 selected"), true],
		["No problems in the ok colour", ok_colour, Color("#8fc27a")],
		["Classic Sheet keeps the address beside the counts", classic_after_count, 1],
		["worded as it was", classic_text.begins_with("event 2 of 3"), true],
		["in the counts' quiet colour",
			classic_colour, (load(CLASSIC_THEME) as EventSheetEditorStyle).get_chrome_style().row_address_color],
	])


static func _test_comment_notes() -> bool:
	var native: Dictionary = _comment_rows(NATIVE_THEME)
	var classic: Dictionary = _comment_rows(CLASSIC_THEME)
	return SUPPORT.pins(TEST_NAME, [
		["a note leads with its grip and bubble", native.get("lead"), true],
		["holding the lead's room", native.get("lead_width"), NativeRowMarks.comment_note_lead_width() - 2.0],
		["and echoes no line", native.get("echo"), false],
		["its words are its words", native.get("words"), ["Set up the gate."]],
		["the action-lane note drops its marker", native.get("action_text"), "log ready"],
		["is drawn as a note", native.get("action_note"), true],
		["its words inset past the card and the lead", native.get("action_padding"),
			NativeRowMarks.comment_note_text_inset()],
		["the comment wraps from where its words start, past the lead",
			float(native.get("origin")) - float(classic.get("origin")), NativeRowMarks.comment_note_lead_width()],
		["a quiet theme draws no lead", classic.get("lead"), false],
		["keeps the echo", classic.get("echo"), true],
		["the same words", classic.get("words"), ["Set up the gate."]],
		["and the action lane's # marker", classic.get("action_text"), "# log ready"],
		["as a plain cell", classic.get("action_note"), false],
	])


static func _test_the_selection_frame() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["the design's dark gutter frames a step brighter in its own hue (the design draws #3a72b0)",
			NativeRowMarks.selection_frame_color(Color("#2c5d87")).to_html(false), "3979b0"],
		["a light gutter frames a step deeper",
			NativeRowMarks.selection_frame_color(Color("#2b6fd6")).v < Color("#2b6fd6").v, true],
		["in the same hue", is_equal_approx(NativeRowMarks.selection_frame_color(Color("#2b6fd6")).h,
			Color("#2b6fd6").h), true],
	])


# ── Helpers ─────────────────────────────────────────────────────────────────────────────────────


static func _span(text: String, metadata: Dictionary) -> SemanticSpan:
	var span := SemanticSpan.new()
	span.text = text
	span.metadata = metadata
	return span


static func _editor(theme_path: String, sheet: EventSheetResource) -> EventSheetEditor:
	var editor := EventSheetEditor.new()
	sheet.editor_style = load(theme_path) as EventSheetEditorStyle
	editor.setup(sheet)
	return editor


static func _sheet_with_events(count: int) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	for index: int in range(count):
		var event := EventRow.new()
		event.trigger_id = "OnProcess"
		sheet.events.append(event)
	return sheet


static func _select_event(editor: EventSheetEditor, number: int) -> void:
	var view: EventSheetViewport = editor._viewport
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT and row_data.event_number == number:
			view._select_row(index)
			break
	editor._update_row_address_status()


## One comment row and one event whose action lane holds a comment, built under `theme_path`, read
## back as the values the paint is decided by.
static func _comment_rows(theme_path: String) -> Dictionary:
	var sheet := EventSheetResource.new()
	sheet.editor_style = load(theme_path) as EventSheetEditorStyle
	var note := CommentRow.new()
	note.text = "Set up the gate."
	sheet.events.append(note)
	var event := EventRow.new()
	event.trigger_id = "OnReady"
	var action_note := CommentRow.new()
	action_note.text = "log ready"
	event.actions.append(action_note)
	sheet.events.append(event)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var found: Dictionary = {"lead": false, "echo": false, "words": [], "action_note": false}
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if row_data.source_resource == note:
				if bool(metadata.get("comment_note_lead", false)):
					found["lead"] = true
					found["lead_width"] = float(metadata.get("badge_fixed_width", 0.0))
				elif bool(metadata.get("code_echo", false)):
					found["echo"] = true
				elif str(metadata.get("edit_kind", "")) == "comment_text":
					(found["words"] as Array).append(span.text)
			elif bool(metadata.get("action_comment", false)):
				found["action_text"] = span.text
				found["action_note"] = bool(metadata.get("comment_note", false))
				found["action_padding"] = float(metadata.get("padding_x", 0.0))
	found["origin"] = view._row_metrics_helper._comment_text_origin_x(0)
	view.free()
	return found
