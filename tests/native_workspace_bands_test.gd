@tool
extends RefCounted
# Godot EventSheets - the Editor Native workspace: the sheet straight under the toolbar
#
# One theme switch, fold_workspace_bands, off by default, on in the Editor Native starter and its rule
# and stated off in every other shipped theme. Pinned here as values:
#   1. the switch: on in the starter and the derived native look, off in Classic Sheet and by default;
#   2. the title strip, the identity band and the Conditions | Actions header rest folded under it and
#      come back the moment a theme that keeps them is published;
#   3. the canvas carries no Add event / + Add... band under it, only its own 8 px of top air, and the
#      scroll's panel is padded 10 px at each side while the sheet fills what is inside the padding;
#   4. what the identity band said rides the class head's name hover;
#   5. the lane boundary is grabbed from the divider inside an event, never from a row that is not one;
#   6. a tucked rail leaves nothing on screen, the rail rests tucked until the reader chooses, and
#      View > Side Rail's gesture brings it back;
#   7. an unsaved sheet's tab says so on its hover.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_workspace_bands_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SHOWCASE := "res://demo/showcase/platformer_shooter/platformer_shooter.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_switch() and ok
	ok = _test_the_bands_fold() and ok
	ok = _test_the_canvas_top_and_sides() and ok
	ok = _test_the_identity_hover() and ok
	ok = _test_the_divider_grab() and ok
	ok = _test_the_rail() and ok
	ok = _test_the_unsaved_tab() and ok
	EventSheetActiveTheme.publish(null)
	return ok


static func _test_the_switch() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["the starter folds the bands", (load(NATIVE_THEME) as EventSheetEditorStyle).fold_workspace_bands, true],
		["the derived native look does", EventSheetEditorThemeDeriver.native_style(Color("#363d4a"))
			.fold_workspace_bands, true],
		["the light one too", EventSheetEditorThemeDeriver.native_style(Color("#f2f2f2"))
			.fold_workspace_bands, true],
		["Classic Sheet keeps them", (load(CLASSIC_THEME) as EventSheetEditorStyle).fold_workspace_bands, false],
		["and so does the default", EventSheetEditorStyle.new().fold_workspace_bands, false],
	])


static func _test_the_bands_fold() -> bool:
	var native: EventSheetEditor = _editor(NATIVE_THEME, _sheet_with_events(2))
	var classic: EventSheetEditor = _editor(CLASSIC_THEME, _sheet_with_events(2))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Editor Native: the title strip, the identity band and the header rest folded",
			[native._title_strip.visible, native._identity_banner.visible, native._column_header.visible],
			[false, false, false]],
		["Classic Sheet keeps all three", [classic._title_strip.visible, classic._identity_banner.visible,
			classic._column_header.visible], [true, true, true]],
	])
	# A re-read of the sheet (every save and rename refreshes the identity band) keeps it folded.
	native._refresh_title_strip()
	ok = SUPPORT.check(TEST_NAME, "a refresh of the sheet leaves the identity band folded",
		native._identity_banner.visible, false) and ok
	# A switch to a theme that keeps the bands brings every one of them back.
	EventSheetActiveTheme.publish(load(CLASSIC_THEME) as EventSheetEditorStyle)
	native._menu_bar.apply_theme_chrome()
	ok = SUPPORT.check(TEST_NAME, "switching to Classic Sheet brings the three back",
		[native._title_strip.visible, native._identity_banner.visible, native._column_header.visible],
		[true, true, true]) and ok
	native.free()
	classic.free()
	return ok


static func _test_the_canvas_top_and_sides() -> bool:
	var native: EventSheetEditor = _editor(NATIVE_THEME, _sheet_with_events(2))
	var classic: EventSheetEditor = _editor(CLASSIC_THEME, _sheet_with_events(2))
	var font_size: int = EventSheetPalette.resolve_font_size(classic._viewport._get_font_size(), -1)
	var native_panel: StyleBox = native._scroll.get_theme_stylebox("panel")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Editor Native carries no corner links", ViewportCornerLinks.shown_on(native._viewport), false],
		["and its rows start under 8 px of air, not under the links' band",
			native._viewport.content_top_offset(), 8.0],
		["Classic Sheet keeps the links", ViewportCornerLinks.shown_on(classic._viewport), true],
		["and the band they own", classic._viewport.content_top_offset(),
			ViewportCornerLinks.band_height(font_size)],
		["the folded scroll is padded 10 px at each side",
			[native._scroll.has_theme_stylebox_override("panel"), native_panel.get_margin(SIDE_LEFT) >= 10.0,
				native_panel.get_margin(SIDE_RIGHT) >= 10.0], [true, true, true]],
		["Classic Sheet's scroll is as the editor draws it",
			classic._scroll.has_theme_stylebox_override("panel"), false],
	])
	# A figure is a picture of a sheet: exactly as tall as its rows, whatever the theme.
	native._viewport.figure_mode = true
	ok = SUPPORT.check(TEST_NAME, "a figure owes the top nothing", native._viewport.content_top_offset(), 0.0) and ok
	native._viewport.figure_mode = false
	native.free()
	classic.free()
	return ok


static func _test_the_identity_hover() -> bool:
	var sheet: EventSheetResource = _sheet_with_events(1)
	sheet.custom_class_name = "Gate"
	sheet.host_class = "Node2D"
	var native: EventSheetEditor = _editor(NATIVE_THEME, GDScriptImporter.new().import_external(SHOWCASE))
	var native_note: String = _name_hover(native._viewport)
	var classic: EventSheetEditor = _editor(CLASSIC_THEME, GDScriptImporter.new().import_external(SHOWCASE))
	var classic_note: String = _name_hover(classic._viewport)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the band's line, as a static", SheetIdentityBanner.identity_label(sheet),
			"Gate - Custom Node · extends Node2D"],
		["its hover lines for a pack with a knob", SheetIdentityBanner.identity_hover_lines(
			_pack_sheet(), "res://eventsheet_addons/demo_pack/demo_pack.gd"),
			PackedStringArray(["Addon Pack v1.2", "Event Sheet · a script for the Node it's attached to", "@ 1 knob"])],
		["Editor Native's class head name says what the folded band said, then its own words", native_note,
			"PlatformerShooter - Custom Node · extends Node2D
@ 1 knob
F2 renames this class everywhere."],
		["Classic Sheet's keeps its own words alone", classic_note, "F2 renames this class everywhere."],
	])
	native.free()
	classic.free()
	return ok


static func _test_the_divider_grab() -> bool:
	var native: EventSheetEditor = _editor(NATIVE_THEME, _sheet_with_events(2))
	var classic: EventSheetEditor = _editor(CLASSIC_THEME, _sheet_with_events(2))
	var view: EventSheetViewport = native._viewport
	var event_index: int = _first_row_of_type(view, EventRowData.RowType.EVENT)
	var head_index: int = _first_row_not_event(view)
	var divider_x: float = view.get_lane_divider_x(view._get_logical_canvas_width())
	var inside: Vector2 = Vector2(divider_x, view.get_row_top(event_index) + 4.0)
	var grab: Dictionary = view.event_boundary_grab_at(inside)
	var classic_view: EventSheetViewport = classic._viewport
	var classic_inside: Vector2 = Vector2(
		classic_view.get_lane_divider_x(classic_view._get_logical_canvas_width()),
		classic_view.get_row_top(_first_row_of_type(classic_view, EventRowData.RowType.EVENT)) + 4.0)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a press on an event's divider grabs the lane split", str(grab.get("kind", "")), "lane_divider"],
		["at the divider itself", float(grab.get("boundary_x", -1.0)), divider_x],
		["a press well inside a lane grabs nothing",
			view.event_boundary_grab_at(Vector2(divider_x - 60.0, inside.y)), {}],
		["nor does a press on a row that is not an event", view.event_boundary_grab_at(
			Vector2(divider_x, view.get_row_top(head_index) + 4.0)) if head_index >= 0 else {}, {}],
		["Classic Sheet keeps the drag in its header band", classic_view.event_boundary_grab_at(classic_inside), {}],
	])
	# The drag in hand moves the split the way the header's drag does, and lets go the same way.
	var ratio_before: float = view.get_event_style().condition_lane_ratio
	var began: bool = view.begin_column_header_drag(grab)
	view.drag_column_header_to(divider_x + 80.0)
	var ended: bool = view.end_column_header_drag()
	ok = SUPPORT.pins(TEST_NAME, [
		["the drag begins", began, true],
		["moving it widens the conditions lane", view.get_event_style().condition_lane_ratio > ratio_before, true],
		["and it ends", ended, true],
	]) and ok
	native.free()
	classic.free()
	return ok


static func _test_the_rail() -> bool:
	var native: EventSheetEditor = _editor(NATIVE_THEME, _sheet_with_events(1))
	var classic: EventSheetEditor = _editor(CLASSIC_THEME, _sheet_with_events(1))
	var rail: EventSheetRailPanels = native._rail_panels
	var rail_root: Control = native._workspace_body.get_child(0) as Control
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Editor Native rests with the rail tucked while the reader has not chosen", rail.is_rail_shown(), false],
		["and leaves nothing of it on screen", rail_root.visible, false],
		["Classic Sheet keeps the rail out", classic._rail_panels.is_rail_shown(), true],
		["with its column showing", (classic._workspace_body.get_child(0) as Control).visible, true],
	])
	# View > Side Rail: the tick is the rail shown, and pressing it flips the rail.
	rail.set_rail_tucked(rail.is_rail_shown())
	ok = SUPPORT.pins(TEST_NAME, [
		["Side Rail brings it back", rail.is_rail_shown(), true],
		["column and all", rail_root.visible, true],
	]) and ok
	rail.set_rail_tucked(rail.is_rail_shown())
	ok = SUPPORT.pins(TEST_NAME, [
		["and tucks it again, chosen now", rail.is_rail_shown(), false],
		["with no edge strip left behind", rail_root.visible, false],
	]) and ok
	# Under a theme that keeps the bands, the same tucked rail is the narrow edge strip it always was.
	rail.set_bands_folded(false)
	ok = SUPPORT.pins(TEST_NAME, [
		["a quiet theme draws the tucked rail as its edge strip", rail_root.visible, true],
		["still tucked", rail.is_rail_tucked(), true],
	]) and ok
	native.free()
	classic.free()
	return ok


static func _test_the_unsaved_tab() -> bool:
	var native: EventSheetEditor = _editor(NATIVE_THEME, _sheet_with_events(1))
	native._refresh_tab_bar()
	var native_tip: String = native._tab_bar.get_tab_tooltip(0) if native._tab_bar.get_tab_count() > 0 else "<no tab>"
	EventSheetActiveTheme.publish(load(CLASSIC_THEME) as EventSheetEditorStyle)
	native._refresh_tab_bar()
	var classic_tip: String = native._tab_bar.get_tab_tooltip(0) if native._tab_bar.get_tab_count() > 0 else "<no tab>"
	native.free()
	return SUPPORT.pins(TEST_NAME, [
		["an unsaved sheet's tab says so on its hover under Editor Native", native_tip, "Unsaved (in-memory)"],
		["a theme with the title strip leaves the tab's hover as it was", classic_tip, ""],
	])


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


static func _pack_sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.addon_version = "1.2"
	sheet.host_class = "Node"
	sheet.variables["speed"] = {"type": TYPE_FLOAT, "default": 1.0, "exported": true}
	return sheet


static func _name_hover(view: EventSheetViewport) -> String:
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if not (span.metadata is Dictionary):
				continue
			var metadata: Dictionary = span.metadata as Dictionary
			if str(metadata.get("head_band", "")) == EventSheetHeadBands.BAND_NAME \
					and span.type == SemanticSpan.SpanType.VALUE:
				return str(metadata.get("hover_note", ""))
	return "<no class head name>"


static func _first_row_of_type(view: EventSheetViewport, row_type: int) -> int:
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_type == row_type:
			return index
	return -1


static func _first_row_not_event(view: EventSheetViewport) -> int:
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_type != EventRowData.RowType.EVENT:
			return index
	return -1
