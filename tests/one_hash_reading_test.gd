# Godot EventSheets - how a script that keeps its annotation words as one-hash comments reads in the sheet.
#
# The words sit above the description in such a file (Godot needs the description next to the member), and the
# block that holds them is stored in the two-hash form every reader is written for. On screen, a comment block
# still reads description first and its words after it, and a code block shows the words with the file's own
# one hash. Both are only how the lines are shown: the file's bytes, the block's text and each line's place in
# it are untouched, and a file that keeps two hashes reads exactly as before.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "one_hash_reading_test"
const ROWS := "# @ace_category(\"Pins\")\n## Pins things.\n@tool\nclass_name RowProbe\nextends Node\n\n# The modes that copy a place, written out\n# rather than inferred.\n# @ace_hidden\n## The ways the place can be pinned.\nconst PLACE_MODES: PackedStringArray = [\n\t\"a\", \"b\"\n]\n"
const TWO_HASH_ROWS := "## @ace_category(\"Pins\")\n## Pins things.\n@tool\nclass_name RowProbeTwo\nextends Node\n\n# The modes that copy a place, written out\n# rather than inferred.\n## @ace_hidden\n## The ways the place can be pinned.\nconst PLACE_MODES: PackedStringArray = [\n\t\"a\", \"b\"\n]\n"
const BLOCK_CODE := "## @ace_category(\"Pins\")\n## Pins things.\nvar loose: int = 1"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_order_is_a_pure_question(ok)
	ok = _test_the_sheet_reads_description_first(ok)
	ok = _test_a_two_hash_file_reads_as_it_did(ok)
	ok = _test_the_file_is_untouched(ok)
	return ok


static func _test_the_order_is_a_pure_question(ok: bool) -> bool:
	var builder: GDScript = load("res://addons/eventsheet/editor/interaction/viewport_row_builder.gd")
	var words_then_description: PackedStringArray = PackedStringArray(["## @ace_hidden", "## What it is.", "## And more."])
	ok = SUPPORT.check(P, "words then description is turned round in a one-hash file",
		builder.comment_display_order(words_then_description, true), [1, 2, 0]) and ok
	ok = SUPPORT.check(P, "and left alone in a two-hash file",
		builder.comment_display_order(words_then_description, false), [0, 1, 2]) and ok
	ok = SUPPORT.check(P, "a block that is only words keeps its order",
		builder.comment_display_order(PackedStringArray(["## @ace_hidden", "## @ace_name(\"A\")"]), true), [0, 1]) and ok
	ok = SUPPORT.check(P, "a block that is only a description keeps its order",
		builder.comment_display_order(PackedStringArray(["## One.", "## Two."]), true), [0, 1]) and ok
	ok = SUPPORT.check(P, "a description first stays where it is",
		builder.comment_display_order(PackedStringArray(["## What it is.", "## @ace_hidden"]), true), [0, 1]) and ok
	ok = SUPPORT.check(P, "a note in front of the words is not a description that follows them",
		builder.comment_display_order(PackedStringArray(["# note", "## @ace_hidden", "## What it is."]), true), [0, 1, 2]) and ok
	ok = SUPPORT.check(P, "a blank line in front stays in front",
		builder.comment_display_order(PackedStringArray(["", "## @ace_hidden", "## What it is."]), true), [0, 2, 1]) and ok
	ok = SUPPORT.check(P, "a blank line inside the block keeps the block as it is",
		builder.comment_display_order(PackedStringArray(["## @ace_hidden", "", "## What it is."]), true), [0, 1, 2]) and ok
	return ok


## What the spans of every row that holds a raw block say, as {code, texts}: the block's own text and, in
## order, the text of each of its lines on screen.
static func _raw_rows(sheet: EventSheetResource) -> Array:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var rows: Array = []
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not (row_data.source_resource is RawCodeRow):
			continue
		var texts: PackedStringArray = PackedStringArray()
		var places: Array[int] = []
		for span: EventSheetSemanticSpan in row_data.spans:
			if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("kind", "")) == "raw_code":
				texts.append(span.text)
				places.append(int((span.metadata as Dictionary).get("line_index", -1)))
		rows.append({"code": (row_data.source_resource as RawCodeRow).code, "texts": texts, "places": places})
	viewport.free()
	return rows


static func _opened(source: String, name: String) -> EventSheetResource:
	var path: String = SUPPORT.own_path(name)
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, path)
	sheet.external_source_path = path
	return sheet


## A sheet holding one block of code that carries an annotation line, in the spelling `spelling` says.
static func _block_sheet(spelling: String, name: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = SUPPORT.own_path(name)
	sheet.annotation_spelling = spelling
	var block: RawCodeRow = RawCodeRow.new()
	block.code = BLOCK_CODE
	sheet.events.append(block)
	return sheet


static func _only(rows: Array, needle: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row["code"]).contains(needle):
			return row
	return {}


static func _test_the_sheet_reads_description_first(ok: bool) -> bool:
	var comment_block: Dictionary = _only(_raw_rows(_opened(ROWS, "one_hash_rows.gd")), "The ways the place can be pinned.")
	ok = SUPPORT.check(P, "the comment block is stored in the two-hash form every reader is written for",
		str(comment_block.get("code", "")), "## @ace_hidden\n## The ways the place can be pinned.") and ok
	ok = SUPPORT.check(P, "it reads the description first, then the words, as one row",
		Array(comment_block.get("texts", PackedStringArray())), ["The ways the place can be pinned.", "@ace_hidden"]) and ok
	ok = SUPPORT.check(P, "and each line is stacked in the place it is shown, since the layout stacks by it",
		comment_block.get("places", []), [0, 1]) and ok
	var head_texts: Array = Array(_only(_raw_rows(_block_sheet("#", "one_hash_block.gd")), "@ace_category").get("texts", PackedStringArray()))
	ok = SUPPORT.check(P, "a code block shows its annotation words with the file's one hash",
		head_texts.has("# @ace_category(\"Pins\")"), true) and ok
	ok = SUPPORT.check(P, "and never with two", head_texts.has("## @ace_category(\"Pins\")"), false) and ok
	ok = SUPPORT.check(P, "while the description line in the same block keeps its two", head_texts.has("## Pins things."), true) and ok
	return ok


static func _test_a_two_hash_file_reads_as_it_did(ok: bool) -> bool:
	var comment_block: Dictionary = _only(_raw_rows(_opened(TWO_HASH_ROWS, "two_hash_rows.gd")), "The ways the place can be pinned.")
	ok = SUPPORT.check(P, "a two-hash file's comment block keeps its own order",
		Array(comment_block.get("texts", PackedStringArray())), ["@ace_hidden", "The ways the place can be pinned."]) and ok
	var head_texts: Array = Array(_only(_raw_rows(_block_sheet("##", "two_hash_block.gd")), "@ace_category").get("texts", PackedStringArray()))
	ok = SUPPORT.check(P, "and its code block shows two hashes", head_texts.has("## @ace_category(\"Pins\")"), true) and ok
	return ok


static func _test_the_file_is_untouched(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("one_hash_bytes.gd")
	_raw_rows(_opened(ROWS, "one_hash_bytes_open.gd"))
	ok = SUPPORT.check(P, "reading the rows changes nothing about the file's own bytes", SUPPORT.reemit(ROWS, path), ROWS) and ok
	return ok
