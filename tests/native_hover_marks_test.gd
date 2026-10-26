@tool
extends RefCounted
# Godot EventSheets - the hover links, the selected gutter, the one group head and the status
# bar's sheet counts
#
# Every pin here is a VALUE the paint is decided by, because all four are drawing on top of rows the
# sheet already builds:
#   1. the hover links say "Add condition" / "Add action" and ship on, in the renderer and the canvas,
#      and show on the hovered event, the selected one and under an empty lane - nowhere else;
#   2. a selected gutter's ink reads on its fill, and the fill reaches across the trigger icon's slot
#      for a top-level event and only over the slot (when an icon is there) for a nested one;
#   3. every look draws the one group head: one line, the folder mark, the title, the description
#      beside it (shortened, whole on hover), the counts and the switch glyph - Editor Native too;
#   4. the status bar counts the rows drawn amber and the sheet's events in the words a group head
#      uses.

const SUPPORT := preload("res://tests/support.gd")
const NativeRowMarks := preload("res://addons/eventsheet/editor/interaction/native_row_marks.gd")
const TEST_NAME := "native_hover_marks_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_hover_links() and ok
	ok = _test_selected_gutter() and ok
	ok = _test_one_group_head() and ok
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
		["under an outline selection a nested event's fill is one shape from the gutter to its icon, at depth 1, 2 and 3",
			[NativeRowMarks.selected_slot_rect(gutter, row, 1, 18, true, true),
				NativeRowMarks.selected_slot_rect(gutter, row, 2, 18, true, true),
				NativeRowMarks.selected_slot_rect(gutter, row, 3, 18, true, true)],
			[Rect2(gutter.end.x, 100.0, slot_end + 18.0 - gutter.end.x, 24.0),
				Rect2(gutter.end.x, 100.0, slot_end + 36.0 - gutter.end.x, 24.0),
				Rect2(gutter.end.x, 100.0, slot_end + 54.0 - gutter.end.x, 24.0)]],
		["and with no icon the margin is the same one shape",
			NativeRowMarks.selected_slot_rect(gutter, row, 2, 18, false, true),
			Rect2(gutter.end.x, 100.0, slot_end + 36.0 - gutter.end.x, 24.0)],
		["Editor Native asks for the one shape, Classic Sheet keeps the slot alone",
			[(load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style().selection_as_outline,
				(load(CLASSIC_THEME) as EventSheetEditorStyle).get_event_style().selection_as_outline],
			[true, false]],
		["a top-level event reads the same either way", NativeRowMarks.selected_slot_rect(gutter, row, 0, 18, true, true),
			NativeRowMarks.selected_slot_rect(gutter, row, 0, 18, true)],
	])


static func _test_one_group_head() -> bool:
	var native: Dictionary = _group_head(NATIVE_THEME)
	var classic: Dictionary = _group_head(CLASSIC_THEME)
	var native_switchable: Dictionary = _group_head(NATIVE_THEME, true)
	return SUPPORT.pins(TEST_NAME, [
		["the two-line head is gone from the theme tokens",
			"group_head_two_line" in EventSheetEventStyle.new(), false],
		["Editor Native reads its head in one line", native.get("line_count"), 1],
		["the description sits beside the name", native.get("description_line"), 0],
		["upright, not italic", native.get("description_italic"), false],
		["a long description shortens with an ellipsis", native.get("description_elides"), true],
		["and reads whole on hover", native.get("description_hover"), "Opens the gate and reports the space key"],
		["the switch is the glyph, not a tick box", native.get("active_tick"), false],
		["a switchable group keeps its ring in Editor Native too", native_switchable.get("ring"), true],
		["it leads with the folder mark and echoes its line, like every look", (native.get("chrome") as Array).size(), 2],
		["so Editor Native and Classic Sheet read the same head", native.get("texts"), classic.get("texts")],
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
static func _group_head(theme_path: String, toggleable: bool = false) -> Dictionary:
	var sheet := EventSheetResource.new()
	sheet.editor_style = load(theme_path) as EventSheetEditorStyle
	var group := EventGroup.new()
	group.name = "Gate Movement"
	group.description = "Opens the gate and reports the space key"
	group.runtime_toggleable = toggleable
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
		view._layout_builder.get_or_build_row_layout(index, 900.0, font, font_size)
		var texts: PackedStringArray = PackedStringArray()
		var words: Array = []
		var chrome: Array = []
		found["line_count"] = row_data.line_count
		found["font"] = font
		found["font_size"] = font_size
		found["description_italic"] = false
		found["description_elides"] = false
		found["description_hover"] = ""
		found["active_tick"] = false
		found["ring"] = false
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata
			texts.append(span.text)
			# The folder mark (a badge that is not the switch) and the echo of the line are chrome;
			# everything else is the head's words.
			var is_chrome: bool = bool(metadata.get("group_echo", false)) or (bool(metadata.get("badge", false))
				and str(metadata.get("group_action", "")).is_empty())
			if is_chrome:
				chrome.append(span.text)
			else:
				words.append(span.text)
			if bool(metadata.get("group_title", false)):
				found["title_x"] = span.rect.position.x
			if str(metadata.get("edit_kind", "")) == "group_description":
				found["description_x"] = span.rect.position.x
				found["description_line"] = int(metadata.get("line_index", 0))
				found["description_italic"] = bool(metadata.get("italic_note", false))
				found["description_elides"] = bool(metadata.get("elide", false))
				found["description_hover"] = str(metadata.get("hover_note", ""))
			if str(metadata.get("group_action", "")) == "enabled" and span.text in [
					ViewportRowBuilder.GROUP_SWITCHABLE_ON_GLYPH, ViewportRowBuilder.GROUP_SWITCHABLE_OFF_GLYPH]:
				found["ring"] = true
			if str(metadata.get("group_action", "")) == "enabled":
				found["active_tick"] = bool(metadata.get("group_active_tick", false))
		found["texts"] = texts
		found["words"] = words
		found["chrome"] = chrome
	view.free()
	return found

