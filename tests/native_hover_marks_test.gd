@tool
extends RefCounted
# Godot EventSheets - the hover links, the selected gutter, the two-line group head and the status
# bar's sheet counts
#
# Every pin here is a VALUE the paint is decided by, because all four are drawing on top of rows the
# sheet already builds:
#   1. the hover links say "Add condition" / "Add action" and ship on, in the renderer and the canvas,
#      and show on the hovered event, the selected one and under an empty lane - nowhere else;
#   2. a selected gutter's ink reads on its fill, and the fill reaches across the trigger icon's slot
#      for a top-level event and only over the slot (when an icon is there) for a nested one;
#   3. a theme that asks for the two-line group head moves the description under the name, in
#      italics, and draws the switch as an Active tick - the same spans with the same words, so the
#      reading is unchanged - and a theme that does not ask leaves the head exactly as it was;
#   4. the status bar counts the rows drawn amber and the sheet's events in the words a group head
#      uses.

const SUPPORT := preload("res://tests/support.gd")
const NativeRowMarks := preload("res://addons/eventsheet/editor/interaction/native_row_marks.gd")
const NativeHeadMarks := preload("res://addons/eventsheet/editor/interaction/native_head_marks.gd")
const TEST_NAME := "native_hover_marks_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_hover_links() and ok
	ok = _test_selected_gutter() and ok
	ok = _test_two_line_group_head() and ok
	ok = _test_status_counts() and ok
	return ok


static func _test_hover_links() -> bool:
	var renderer := EventRowRenderer.new()
	var view := EventSheetViewport.new()
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the condition lane's link", EventRowRenderer.hover_link_label("add_condition"), "Add condition"],
		["the action lane's link", EventRowRenderer.hover_link_label("add_action"), "Add action"],
		["the renderer ships the hover links on", renderer.show_hover_add_links, true],
		["and so does the canvas", view.show_hover_add_links, true],
		["the View menu item has its own number", EventSheetMenuBar.HOVER_ADD_LINKS_VIEW_ID, 9819],
		["a filled lane of an event at rest keeps its door hidden",
			EventRowRenderer.add_door_revealed(false, false, true), false],
		["the hovered event shows it", EventRowRenderer.add_door_revealed(true, false, true), true],
		["so does the selected event, which a keyboard selection reaches with no pointer",
			EventRowRenderer.add_door_revealed(false, true, true), true],
		["and an empty lane shows it at rest, so a new event is never a blank lane",
			EventRowRenderer.add_door_revealed(false, false, false), true],
	])
	view.free()
	return ok


static func _test_selected_gutter() -> bool:
	var gutter := Rect2(0.0, 100.0, float(EventSheetPalette.GUTTER_WIDTH), 24.0)
	var row := Rect2(0.0, 100.0, 800.0, 24.0)
	var slot_end: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + float(EventSheetPalette.GUTTER_WIDTH) \
		+ NativeRowMarks.TRIGGER_ICON_SLOT
	var nested_slot_x: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + float(EventSheetPalette.GUTTER_WIDTH) + 36.0
	return SUPPORT.pins(TEST_NAME, [
		["white on the design's dark selected blue", NativeRowMarks.ink_on(Color("#2c5d87")), Color.WHITE],
		["white on the light skin's selected blue", NativeRowMarks.ink_on(Color("#2b6fd6")), Color.WHITE],
		["near-black on a pale fill", NativeRowMarks.ink_on(Color("#e8eef6")), Color(0.08, 0.09, 0.11)],
		["a top-level event's fill runs from the gutter across the icon slot",
			NativeRowMarks.selected_slot_rect(gutter, row, 0, 18, true),
			Rect2(gutter.end.x, 100.0, slot_end - gutter.end.x, 24.0)],
		["and does so with no icon too, so the margin stays one shape",
			NativeRowMarks.selected_slot_rect(gutter, row, 0, 18, false),
			Rect2(gutter.end.x, 100.0, slot_end - gutter.end.x, 24.0)],
		["a nested event fills only the slot its icon sits in",
			NativeRowMarks.selected_slot_rect(gutter, row, 2, 18, true),
			Rect2(nested_slot_x, 100.0, NativeRowMarks.TRIGGER_ICON_SLOT, 24.0)],
		["a nested event with no icon fills nothing more", NativeRowMarks.selected_slot_rect(gutter, row, 2, 18, false),
			Rect2()],
	])


static func _test_two_line_group_head() -> bool:
	var native: Dictionary = _group_head(NATIVE_THEME)
	var classic: Dictionary = _group_head(CLASSIC_THEME)
	return SUPPORT.pins(TEST_NAME, [
		["the starter asks for the two-line head", (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style().group_head_two_line, true],
		["the derived native look asks for it too", EventSheetEditorThemeDeriver.native_style(
			Color("#363d4a")).get_event_style().group_head_two_line, true],
		["the token defaults to the one-line head", EventSheetEventStyle.new().group_head_two_line, false],
		["two lines: the description sits on the second", native.get("description_line"), 1],
		["laid out under the name", native.get("description_x"), native.get("title_x")],
		["in italics", native.get("description_italic"), true],
		["the head is two lines tall", native.get("line_count"), 2],
		["the switch is drawn as the Active tick", native.get("active_tick"), true],
		["holding the room the tick and the word take", native.get("switch_width"),
			NativeHeadMarks.active_tick_width(native.get("font"), int(native.get("font_size")))],
		["the words are the same words", native.get("texts"), classic.get("texts")],
		["one line: the description beside the name", classic.get("description_line"), 0],
		["no italics there", classic.get("description_italic"), false],
		["no tick there", classic.get("active_tick"), false],
		["and the head is one line", classic.get("line_count"), 1],
		["the switch says Active", NativeHeadMarks.active_word(), "Active"],
	])


static func _test_status_counts() -> bool:
	var sheet := EventSheetResource.new()
	for trigger: String in ["OnReady", "OnProcess", "OnPhysicsProcess"]:
		var event := EventRow.new()
		event.trigger_id = trigger
		sheet.events.append(event)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var clean: int = view.attention_row_count()
	(view._root_rows[1] as EventRowData).attention_note = "a finding"
	var flagged: int = view.attention_row_count()
	view.free()
	return SUPPORT.pins(TEST_NAME, [
		["a sheet with nothing amber", clean, 0],
		["one amber row is one problem", flagged, 1],
		["no problems, said as a count", EventSheetDock.problem_count_text(0), "No problems"],
		["one", EventSheetDock.problem_count_text(1), "1 problem"],
		["many", EventSheetDock.problem_count_text(4), "4 problems"],
		["the events, as a group head counts them", [EventSheetDock.event_count_text(1),
			EventSheetDock.event_count_text(4)], ["1 event", "4 events"]],
	])


## The laid-out head of one group with a description under `theme_path`: where its name and its
## description start, which line the description is on, how the switch is drawn, and its words.
static func _group_head(theme_path: String) -> Dictionary:
	var sheet := EventSheetResource.new()
	sheet.editor_style = load(theme_path) as EventSheetEditorStyle
	var group := EventGroup.new()
	group.name = "Gate Movement"
	group.description = "Opens the gate and reports the space key"
	var event := EventRow.new()
	event.trigger_id = "OnProcess"
	group.events.append(event)
	sheet.events.append(group)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var found: Dictionary = {}
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.source_resource != group:
			continue
		var font: Font = view._get_font()
		var font_size: int = view._get_font_size()
		view._get_or_build_row_layout(index, 900.0, font, font_size)
		var texts: PackedStringArray = PackedStringArray()
		found["line_count"] = row_data.line_count
		found["font"] = font
		found["font_size"] = font_size
		found["description_italic"] = false
		found["active_tick"] = false
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata
			texts.append(span.text)
			if bool(metadata.get("group_title", false)):
				found["title_x"] = span.rect.position.x
			if str(metadata.get("edit_kind", "")) == "group_description":
				found["description_x"] = span.rect.position.x
				found["description_line"] = int(metadata.get("line_index", 0))
				found["description_italic"] = bool(metadata.get("italic_note", false))
			if str(metadata.get("group_action", "")) == "enabled":
				found["active_tick"] = bool(metadata.get("group_active_tick", false))
				found["switch_width"] = float(metadata.get("badge_fixed_width", 0.0))
		found["texts"] = texts
	view.free()
	return found

