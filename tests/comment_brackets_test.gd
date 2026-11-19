# Square brackets in a comment row. A note such as `a[b] and items[i]` holds text that looks like a bold or
# italic tag, and it used to be drawn as "a and items and": the brackets and what sat in them vanished. A
# comment is the user's own words, so only a tag CLOSED later in the text is markup; everything else is shown
# as typed. The file's bytes never change - this is only what is drawn and measured.
@tool
class_name CommentBracketsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "comment_brackets_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_what_a_comment_line_draws() and ok
	ok = _test_a_comment_row_draws_and_measures_what_it_holds() and ok
	return ok


static func _drawn(text: String) -> String:
	var joined: String = ""
	for segment: Dictionary in EventSheetBBCodeLite.parse(text, Color.WHITE, true):
		joined += str(segment.get("text", ""))
	return joined


static func _test_what_a_comment_line_draws() -> bool:
	return SUPPORT.pin_table(TEST_NAME, {
		"# a[b] and items[i] and [b]": "# a[b] and items[i] and [b]",
		"[0, 1] and [url] and [color=red] unclosed": "[0, 1] and [url] and [color=red] unclosed",
		"[b]bold[/b] words": "bold words",
		"[i]slanted[/i] and [color=red]red[/color]": "slanted and red",
		"[b]bold[/b] then items[i] and a[b]": "bold then items[i] and a[b]",
		"stray [/b] closer": "stray [/b] closer",
		"nested [b]one [i]two[/i] three[/b]": "nested one two three",
		"[B]loud[/B]": "loud",
		"a[b]x[/b]": "ax",
		"": "",
	}, func(text: Variant) -> Variant: return _drawn(str(text)))


static func _test_a_comment_row_draws_and_measures_what_it_holds() -> bool:
	var ok: bool = true
	var typed: String = "a[b] and items[i] and [0, 1] and [url]"
	var sheet: EventSheetResource = EventSheetResource.new()
	var plain: CommentRow = CommentRow.new()
	plain.text = typed
	sheet.events.append(plain)
	var styled: CommentRow = CommentRow.new()
	styled.text = "[b]bold[/b] and items[i]"
	sheet.events.append(styled)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var rows: Array = viewport.get_flat_rows()
	var plain_row: EventRowData = rows[0].get("row")
	var styled_row: EventRowData = rows[1].get("row")
	var plain_meta: Dictionary = plain_row.spans[0].metadata
	ok = SUPPORT.pin_value(TEST_NAME, "brackets that close nothing are drawn from the text as typed",
		(plain_meta.get("bbcode_segments", []) as Array).is_empty(), true) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "the span keeps the typed text", plain_row.spans[0].text, typed) and ok
	var styled_meta: Dictionary = styled_row.spans[0].metadata
	var drawn: String = ""
	for segment: Dictionary in styled_meta.get("bbcode_segments", []) as Array:
		drawn += str(segment.get("text", ""))
	ok = SUPPORT.pin_value(TEST_NAME, "a real tag still styles and a stray bracket beside it stays", drawn, "bold and items[i]") and ok
	ok = SUPPORT.pin_value(TEST_NAME, "the span keeps the raw text of a styled line", styled_row.spans[0].text, "[b]bold[/b] and items[i]") and ok
	ok = SUPPORT.pin_value(TEST_NAME, "the file text of the plain row is untouched", plain.text, typed) and ok
	editor.free()
	return ok
