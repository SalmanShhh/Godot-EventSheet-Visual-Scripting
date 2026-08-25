# Godot EventSheets - exporting a sheet as an image, a PDF or Markdown with figures.
#
# Everything that needs no screen is pinned here by VALUE: how a tall picture is cut into pages, the
# exact bytes a hand-written PDF starts and ends with, that the PDF really is one page per slice and
# that the pixels inside it come back out of its Flate stream unchanged (the one claim a "does it
# open?" test cannot make), and the Markdown a sheet plus its figures assembles into.
#
# The capture itself is not here on purpose: it needs a window and a frame to draw in, and a test
# that faked one would be pinning the fake.
@tool
class_name SheetExportTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_stitch_formats_match() and all_passed
	all_passed = _test_page_slices() and all_passed
	all_passed = _test_split_pages() and all_passed
	all_passed = _test_pdf_structure() and all_passed
	all_passed = _test_pdf_pixels_survive() and all_passed
	all_passed = _test_markdown_with_figures() and all_passed
	all_passed = _test_figure_names() and all_passed
	return all_passed


static func _picture(width: int, height: int) -> Image:
	var picture: Image = Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	for y: int in height:
		for x: int in width:
			picture.set_pixel(x, y, Color(float(x % 5) / 4.0, float(y % 7) / 6.0, 0.25))
	return picture


# ── stitching ─────────────────────────────────────────────────────────────────────────────────


## The bug this pins wrote every export as a blank file. The whole-sheet capture stitches screen
## grabs into an RGBA8 buffer with `blit_rect`, which requires both images to share a format and
## does NOTHING when they do not - and a grab off an opaque viewport comes back RGB8. Nothing threw:
## the PNG, the PDF page and the Markdown figures were all written from an untouched empty buffer.
static func _test_stitch_formats_match() -> bool:
	var grab: Image = _picture(6, 4)
	var passed: bool = _check("the fixture really is the format a screen grab is",
		grab.get_format(), Image.FORMAT_RGB8)
	var matched: Image = EventSheetSheetExport.matched_to(grab, Image.FORMAT_RGBA8)
	passed = _check("it comes back in the format the stitch buffer is",
		matched.get_format(), Image.FORMAT_RGBA8) and passed
	passed = _check("and the caller's own picture is not converted under it",
		grab.get_format(), Image.FORMAT_RGB8) and passed
	passed = _check("a pixel survives the conversion",
		matched.get_pixel(3, 2), grab.get_pixel(3, 2)) and passed
	var already: Image = Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	passed = _check("a picture already in the format is handed straight back",
		EventSheetSheetExport.matched_to(already, Image.FORMAT_RGBA8) == already, true) and passed
	# The claim that matters: after matching, the blit actually copies. A blit between mismatched
	# formats leaves the destination untouched, which is exactly what shipped.
	var stitched: Image = Image.create_empty(6, 4, false, Image.FORMAT_RGBA8)
	stitched.blit_rect(matched, Rect2i(0, 0, 6, 4), Vector2i.ZERO)
	passed = _check("the stitched page holds the grabbed pixels, not blank",
		stitched.get_pixel(3, 2), grab.get_pixel(3, 2)) and passed
	return passed


# ── pages ─────────────────────────────────────────────────────────────────────────────────────


static func _test_page_slices() -> bool:
	var even: Array = EventSheetSheetExport.page_slices(300, 100)
	var passed: bool = _check("a picture that divides exactly makes whole pages",
		str(even), str([Vector2i(0, 100), Vector2i(100, 100), Vector2i(200, 100)]))
	var ragged: Array = EventSheetSheetExport.page_slices(250, 100)
	passed = _check("the last page is what is left, never a padded one",
		str(ragged[2]), str(Vector2i(200, 50))) and passed
	passed = _check("a picture shorter than a page is one page",
		EventSheetSheetExport.page_slices(40, 100).size(), 1) and passed
	passed = _check("nothing to cut is no pages",
		EventSheetSheetExport.page_slices(0, 100).size(), 0) and passed
	return passed


static func _test_split_pages() -> bool:
	var pages: Array = EventSheetSheetExport.split_pages(_picture(20, 250), 100)
	var passed: bool = _check("three pages come out of two and a half", pages.size(), 3)
	passed = _check("each page keeps the width", (pages[0] as Image).get_width(), 20) and passed
	passed = _check("and the tail page is the height that was left",
		(pages[2] as Image).get_height(), 50) and passed
	return passed


# ── the PDF ───────────────────────────────────────────────────────────────────────────────────


static func _test_pdf_structure() -> bool:
	var pages: Array = EventSheetSheetExport.split_pages(_picture(30, 150), 100)
	var bytes: PackedByteArray = EventSheetSheetExport.pdf_bytes(pages)
	# The picture streams are binary, so the file is read in the two places that are text: the head
	# with the catalog and the page tree, and the tail with the cross-reference table.
	var text: String = bytes.slice(0, 400).get_string_from_ascii()
	var tail: String = bytes.slice(maxi(bytes.size() - 400, 0)).get_string_from_ascii()
	var passed: bool = _check("it is a PDF", text.begins_with("%PDF-1.4"), true)
	passed = _check("it ends the way a PDF ends", tail.ends_with("%%EOF\n"), true) and passed
	passed = _check("it has a catalog", text.contains("/Type /Catalog"), true) and passed
	passed = _check("the page tree counts both pages", text.contains("/Count 2"), true) and passed
	passed = _check("and names them both",
		text.contains("/Kids [3 0 R 6 0 R]"), true) and passed
	passed = _check("the first page is the size of its picture",
		text.contains("/MediaBox [0 0 30 100]"), true) and passed
	passed = _check("the tail page is the size of what was left",
		_holds(bytes, "/MediaBox [0 0 30 50]"), true) and passed
	passed = _check("the pictures ride as Flate-compressed RGB",
		_holds(bytes, "/ColorSpace /DeviceRGB") and _holds(bytes, "/Filter /FlateDecode"), true) and passed
	passed = _check("there is a cross-reference table", tail.contains("\nxref\n0 9\n"), true) and passed
	passed = _check("whose start is written at the end", tail.contains("startxref"), true) and passed
	passed = _check("nothing to write is no file",
		EventSheetSheetExport.pdf_bytes([]).size(), 0) and passed
	return passed


## The claim a structure test cannot make: the pixels that went in are the pixels a reader gets.
static func _test_pdf_pixels_survive() -> bool:
	var picture: Image = _picture(8, 6)
	var raw: PackedByteArray = EventSheetSheetExport.rgb_bytes(picture)
	var passed: bool = _check("RGB bytes are three per pixel", raw.size(), 8 * 6 * 3)
	var stream: PackedByteArray = EventSheetSheetExport._flate(raw)
	passed = _check("the stream carries the zlib header", stream[0], 0x78) and passed
	passed = _check("and its compression level", stream[1], 0x9C) and passed
	var back: PackedByteArray = EventSheetSheetExport.unflate(stream, raw.size())
	passed = _check("and the pixels come back out unchanged", back, raw) and passed
	# The checksum is what a reader validates the stream with - pin it against a known answer.
	passed = _check("the Adler-32 of an empty run is 1",
		EventSheetSheetExport.adler32(PackedByteArray()), 1) and passed
	passed = _check("and of \"abc\" is the value zlib gives",
		EventSheetSheetExport.adler32("abc".to_ascii_buffer()), 0x024D0127) and passed
	return passed


# ── Markdown with figures ─────────────────────────────────────────────────────────────────────


static func _test_markdown_with_figures() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	sheet.events.append(event)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var rows: Array = []
	rows.assign(viewport.get_row_tree())
	viewport.free()
	var plain: String = EventSheetSheetExport.markdown_with_figures(rows, "player", [])
	var passed: bool = _check("with no figures it is the sheet's own listing",
		plain, EventSheetTextListing.markdown_for_rows(rows, "player"))
	var with_figures: String = EventSheetSheetExport.markdown_with_figures(rows, "player",
		[{"title": "Combat", "path": "res://docs/player-combat.png"}])
	passed = _check("the listing still leads",
		with_figures.begins_with("# player\n\n```text\n"), true) and passed
	passed = _check("and a figure per group is embedded under it, by its own name",
		with_figures.contains("![Combat](player-combat.png)"), true) and passed
	return passed


static func _test_figure_names() -> bool:
	var passed: bool = _check("a figure is named for its document and its group",
		EventSheetSheetExport.figure_file_name("res://docs/player.md", "Combat", 0), "player-combat.png")
	passed = _check("a group whose name is not a file name still gets one",
		EventSheetSheetExport.figure_file_name("res://docs/player.md", "Every tick (physics)", 1),
		"player-every-tick--physics.png") and passed
	passed = _check("and a group with no name at all is numbered",
		EventSheetSheetExport.figure_file_name("res://docs/player.md", "", 2), "player-group-3.png") and passed
	return passed


## Whether an ASCII run appears anywhere in the file. A PDF is part text and part binary, so it
## cannot be read as one string - a byte search is the honest way to ask.
static func _holds(bytes: PackedByteArray, needle: String) -> bool:
	var wanted: PackedByteArray = needle.to_ascii_buffer()
	for start: int in range(0, maxi(bytes.size() - wanted.size() + 1, 0)):
		if bytes.slice(start, start + wanted.size()) == wanted:
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_export_test: %s" % label)
		return true
	print("[FAIL] sheet_export_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
