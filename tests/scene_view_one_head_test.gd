# EventForge - one head bar for every kind of file. A scene view opens on the same 30 px grey bar a
# script does (the scene's name, `Scene · root <type>`, the scripts count with its card), each script
# under it reads under its own head bar naming the node it sits on, with no folded band stack and no
# Behaviors band among the rows, and a sheet that lives only in memory opens on a bar named
# "Untitled" with no file doors.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "scene_view_one_head_test"

const SCENE := "res://demo/showcase/carousel/showcase_carousel.tscn"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetSceneSheet.build(SCENE)
	var view: EventSheetViewport = _view(sheet, false)
	var rows: Array[EventRowData] = view._root_rows
	var grey: Color = view._get_event_style().head_bar_color
	var bars: Array = []
	for row_data: EventRowData in rows:
		if row_data.fixed_height == ViewportRowBuilder.SHEET_HEAD_BAR_HEIGHT:
			bars.append(_texts(row_data).slice(0, 2))
	var ok: bool = SUPPORT.pins(P, [
		["the scene opens on the head bar's height", rows[0].fixed_height, ViewportRowBuilder.SHEET_HEAD_BAR_HEIGHT],
		["in the head bar's grey, not the accent", rows[0].custom_color, grey],
		["naming the scene, its root and its scripts", _texts(rows[0]),
			PackedStringArray(["◆", "showcase_carousel.tscn", "Scene · root", "Node2D", "9 scripts"])],
		["the scripts count opens a card", _card_id(rows[0], "9 scripts"), "scripts"],
		["the first script reads under a bar naming its node", _texts(rows[1]).slice(0, 5),
			PackedStringArray(["◆", "Carousel", "Custom node · extends", "Node2D", "· showcase_carousel.gd"])],
		["with its behaviours as a count with a card", _card_id(rows[1], "34 behaviours"), "behaviours"],
		["every script opens on one bar", bars.size(), 10],
		["no Behaviors band among the rows", _uids_with(rows, "object_behaviors_"), 0],
		["no band stack under a script's bar", _uids_with(rows, ViewportRowBuilder.HEAD_BAND_UID_PREFIX + "name"), 0],
	])
	view.free()
	# A sheet that lives only in memory, in the editor's own view.
	var unsaved := EventSheetResource.new()
	unsaved.host_class = "Node2D"
	unsaved.events = [EventRow.new()]
	var unsaved_view: EventSheetViewport = _view(unsaved, true)
	var head: EventRowData = unsaved_view._root_rows[0]
	ok = SUPPORT.pins(P, [
		["an unsaved sheet opens on the head bar", head.row_uid.begins_with(ViewportRowBuilder.SHEET_HEAD_BAR_UID_PREFIX), true],
		["named Untitled", _texts(head)[1], "Untitled"],
		["with no file doors on its card", _doors(head), PackedStringArray(["Edit description…"])],
	]) and ok
	unsaved_view.free()
	# A figure in the Manual or a theme preview shows rows, not a file: no bar there.
	var figure: EventSheetViewport = _view(unsaved, false)
	ok = SUPPORT.pin_value(P, "a view that shows rows, not a file, keeps no bar",
		figure._root_rows[0].row_uid.begins_with(ViewportRowBuilder.SHEET_HEAD_BAR_UID_PREFIX), false) and ok
	figure.free()
	return ok


static func _view(sheet: EventSheetResource, heads_unsaved: bool) -> EventSheetViewport:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.heads_unsaved_sheets = heads_unsaved
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	return view


static func _texts(row_data: EventRowData) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		texts.append(span.text)
	return texts


static func _card_id(row_data: EventRowData, text: String) -> String:
	for span: SemanticSpan in row_data.spans:
		if span.text == text and span.metadata is Dictionary and (span.metadata as Dictionary).get("head_card") is Dictionary:
			return str(((span.metadata as Dictionary)["head_card"] as Dictionary).get("id", ""))
	return ""


static func _doors(row_data: EventRowData) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and (span.metadata as Dictionary).get("head_card") is Dictionary:
			var card: Dictionary = (span.metadata as Dictionary)["head_card"]
			if str(card.get("id", "")) == "name":
				for door: Variant in card.get("doors", []):
					labels.append(str((door as Array)[0]))
	return labels


static func _uids_with(rows: Array[EventRowData], part: String) -> int:
	var found: int = 0
	for row_data: EventRowData in rows:
		if row_data.row_uid.contains(part):
			found += 1
	return found
