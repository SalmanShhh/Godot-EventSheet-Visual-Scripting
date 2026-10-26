# EventForge - the `#` paragraph a script closes on, said by the head bar's name card as the file's
# description, reads once: in the card, not again as the sheet's last row. The card's Edit
# description… edits that very note, and a marked-up comment row never echoes its raw markup.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "closing_description_reads_once_test"

const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"


static func run() -> bool:
	var sheet: EventSheetResource = _open(CAROUSEL)
	sheet.read_only = false
	var view: EventSheetViewport = _view(sheet)
	var card: Dictionary = _name_card(view)
	var closing: CommentRow = _last_note(sheet)
	var ok: bool = SUPPORT.pins(P, [
		["the file keeps its closing paragraph", closing != null, true],
		["the name card says it as the description", str((card.get("lines", PackedStringArray()) as PackedStringArray)[0]).left(37),
			"Carousel of Juice - 8 tiles sine-sway"],
		["no row of the canvas draws it again", _rows_drawing(view, closing), 0],
		["the canvas ends on juice_tile's rows", _last_root_uid(view).begins_with("define_fn_juice_tile"), true],
		["no span puts raw markup on the sheet", _raw_markup_spans(view), PackedStringArray()],
		["Edit description… edits the claimed note", _door_action(card, "Edit description…"),
			ViewportRowBuilder.HEAD_ACTION_EDIT_DESCRIPTION_NOTE],
		["the door finds that note on the built rows", ViewportRowBuilder.claimed_description_note(view._root_rows) == closing, true],
		["the file still re-emits byte for byte", str(SheetCompiler.compile(sheet).get("output", "")),
			FileAccess.get_file_as_string(CAROUSEL)],
	])
	view.free()
	# A marked-up note in the middle of a sheet is not claimed, keeps its row, and wears no echo.
	var marked: EventSheetResource = EventSheetResource.new()
	var note := CommentRow.new()
	note.text = "A [b]short[/b] note."
	var after := EventRow.new()
	marked.events = [note, after]
	var marked_style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	marked_style.ensure_defaults()
	marked.editor_style = marked_style
	var marked_view: EventSheetViewport = _view(marked)
	ok = SUPPORT.pins(P, [
		["a mid-file note keeps its row", _rows_drawing(marked_view, _first_note(marked)), 1],
		["a marked-up note echoes no raw markup", _raw_markup_spans(marked_view), PackedStringArray()],
		["the head card claims no mid-file note", ViewportRowBuilder.claimed_description_note(marked_view._root_rows) == null, true],
	]) and ok
	marked_view.free()
	return ok


static func _open(path: String) -> EventSheetResource:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	return sheet


static func _view(sheet: EventSheetResource) -> EventSheetViewport:
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	return view


static func _name_card(view: EventSheetViewport) -> Dictionary:
	for row_data: EventRowData in view._root_rows:
		if not row_data.row_uid.begins_with(ViewportRowBuilder.SHEET_HEAD_BAR_UID_PREFIX):
			continue
		for span: SemanticSpan in row_data.spans:
			if span.metadata is Dictionary and (span.metadata as Dictionary).get("head_card") is Dictionary:
				var card: Dictionary = (span.metadata as Dictionary)["head_card"]
				if str(card.get("id", "")) == "name":
					return card
	return {}


static func _last_note(sheet: EventSheetResource) -> CommentRow:
	for index: int in range(sheet.events.size() - 1, -1, -1):
		if sheet.events[index] is CommentRow:
			return sheet.events[index] as CommentRow
	return null


static func _first_note(sheet: EventSheetResource) -> CommentRow:
	for entry: Variant in sheet.events:
		if entry is CommentRow:
			return entry as CommentRow
	return null


static func _rows_drawing(view: EventSheetViewport, note: CommentRow) -> int:
	var found: int = 0
	for row_data: EventRowData in view._root_rows:
		if note != null and row_data.source_resource == note:
			found += 1
	return found


static func _last_root_uid(view: EventSheetViewport) -> String:
	var rows: Array[EventRowData] = view._root_rows
	for index: int in range(rows.size() - 1, -1, -1):
		# The "+ Add event…" footer is the sheet's own last line, not a row of the file.
		if rows[index].indent == 0 and not rows[index].row_uid.begins_with("add_event_footer_"):
			return rows[index].row_uid
	return ""


## Every span whose DRAWN text carries `[b]`: a span drawn through BBCode segments draws the
## segments, any other span its text.
static func _raw_markup_spans(view: EventSheetViewport) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in view._root_rows:
		for span: SemanticSpan in row_data.spans:
			var drawn: String = span.text
			if span.metadata is Dictionary and (span.metadata as Dictionary).has("bbcode_segments"):
				drawn = ""
				for segment: Variant in (span.metadata as Dictionary)["bbcode_segments"]:
					drawn += str((segment as Dictionary).get("text", ""))
			if drawn.contains("[b]"):
				found.append(drawn.left(40))
	return found


static func _door_action(card: Dictionary, label: String) -> String:
	for door: Variant in card.get("doors", []):
		if door is Array and str((door as Array)[0]) == label:
			return str((door as Array)[1])
	return ""
