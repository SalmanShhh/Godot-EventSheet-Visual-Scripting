@tool
class_name EventSheetSheetExport
extends RefCounted
# EXPORT A SHEET AS A PICTURE (V16) - the render harness, made a user feature.
#
# Sheet ▸ Export ▸ Image (PNG) / PDF / Markdown with figures. The picture is the sheet exactly as it
# is being read - the current theme, density, arrangement and lenses, with the event numbers on -
# because it is the canvas itself that is captured, not a second renderer that could drift from it.
#
# What lives HERE is everything that needs no screen: splitting one tall picture into pages, writing
# those pages into a PDF, and assembling the Markdown around them. The capture itself is the dock's
# (it needs a viewport and a frame to draw in), which is also what makes all of this testable
# headless: a page split is arithmetic and a PDF is bytes.
#
# THE PDF IS WRITTEN BY HAND, with no library: a catalog, a page tree, and one page per slice whose
# whole content is that slice drawn edge to edge. The pixels ride as a Flate-compressed RGB image -
# PDF's own FlateDecode is zlib, so the deflate stream Godot produces is wrapped in the two-byte
# zlib header and the Adler-32 checksum that a reader expects. One point per pixel, so a page comes
# out the size the sheet was rendered at.

## The zlib header for "deflate, default compression" - the two bytes in front of every FlateDecode
## stream this writes, and the four Adler-32 bytes that close it.
const ZLIB_HEADER_SIZE := 2
const ZLIB_CHECKSUM_SIZE := 4

## How tall one exported page is, in pixels, when the caller does not say. A4 at 96 dpi in portrait,
## which is what a sheet printed for a design doc wants.
const DEFAULT_PAGE_HEIGHT := 1123


# ── Markdown ──────────────────────────────────────────────────────────────────────────────────


## The sheet as a Markdown document: the plain-text listing the sheet already writes, and a figure
## per group under it. `figures` is `[{"title": String, "path": String}]` - each one is embedded
## with its title as the alt text, so the document reads without the pictures too.
static func markdown_with_figures(rows: Array, sheet_title: String, figures: Array) -> String:
	var body: String = EventSheetTextListing.markdown_for_rows(rows, sheet_title)
	if figures.is_empty():
		return body
	var lines: PackedStringArray = PackedStringArray([body, ""])
	for figure: Variant in figures:
		var entry: Dictionary = figure
		var title: String = str(entry.get("title", "")).strip_edges()
		var path: String = str(entry.get("path", "")).strip_edges()
		if path.is_empty():
			continue
		lines.append("![%s](%s)" % [title, path.get_file()])
		lines.append("")
	return "\n".join(lines)


## The figure file name one group's picture gets, beside the Markdown it is embedded in: the
## document's own name, then the group's, in the plain lowercase a file name wants.
static func figure_file_name(document_path: String, group_title: String, index: int) -> String:
	var base: String = document_path.get_file().get_basename()
	var slug: String = group_title.to_lower()
	var cleaned: String = ""
	for character: String in slug:
		cleaned += character if character.is_valid_identifier() or character.is_valid_int() else "-"
	cleaned = cleaned.strip_edges().lstrip("-").rstrip("-")
	if cleaned.is_empty():
		cleaned = "group-%d" % (index + 1)
	return "%s-%s.png" % [base, cleaned]


# ── pages ─────────────────────────────────────────────────────────────────────────────────────


## Where each page starts and how tall it is, top to bottom: `[Vector2i(y, height)]`. The last page
## is whatever is left, never a padded one - a short tail page is honest, a stretched one is not.
static func page_slices(image_height: int, page_height: int = DEFAULT_PAGE_HEIGHT) -> Array:
	var slices: Array = []
	if image_height <= 0:
		return slices
	var step: int = maxi(page_height, 1)
	var cursor: int = 0
	while cursor < image_height:
		slices.append(Vector2i(cursor, mini(step, image_height - cursor)))
		cursor += step
	return slices


## One tall picture cut into pages.
static func split_pages(picture: Image, page_height: int = DEFAULT_PAGE_HEIGHT) -> Array:
	var pages: Array = []
	if picture == null:
		return pages
	for slice: Variant in page_slices(picture.get_height(), page_height):
		var band: Vector2i = slice
		pages.append(picture.get_region(Rect2i(0, band.x, picture.get_width(), band.y)))
	return pages


# ── the PDF ───────────────────────────────────────────────────────────────────────────────────


## A minimal PDF holding one page per picture, each drawn edge to edge at one point per pixel.
## Empty when there is nothing to write.
static func pdf_bytes(pages: Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	if pages.is_empty():
		return out
	var page_ids: PackedStringArray = PackedStringArray()
	for page_index: int in pages.size():
		page_ids.append("%d 0 R" % (3 + page_index * 3))
	_append_ascii(out, "%PDF-1.4\n")
	# A binary comment right after the header is what tells a reader this file is not plain text.
	out.append_array(PackedByteArray([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]))
	# Every object by its id: 1 is the catalog, 2 the page tree, then three per page (the page, its
	# picture and the one drawing instruction that puts the picture on it).
	var by_id: Dictionary = {
		1: "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
		2: "2 0 obj\n<< /Type /Pages /Kids [%s] /Count %d >>\nendobj\n" % [
			" ".join(page_ids), pages.size()],
	}
	for page_index: int in pages.size():
		var picture: Image = pages[page_index] as Image
		var width: int = picture.get_width()
		var height: int = picture.get_height()
		var page_id: int = 3 + page_index * 3
		var image_id: int = page_id + 1
		var content_id: int = page_id + 2
		by_id[page_id] = ("%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] " +
			"/Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>\nendobj\n") % [
			page_id, width, height, image_id, content_id]
		by_id[image_id] = {"kind": "image", "width": width, "height": height,
			"data": _flate(rgb_bytes(picture))}
		by_id[content_id] = {"kind": "content",
			"data": ("q\n%d 0 0 %d 0 0 cm\n/Im0 Do\nQ\n" % [width, height]).to_ascii_buffer()}
	# Objects are written in id order so the cross-reference table is a straight walk.
	var ids: Array = by_id.keys()
	ids.sort()
	var offsets: Dictionary = {}
	for entry: Variant in ids:
		var object_id: int = entry
		offsets[object_id] = out.size()
		var value: Variant = by_id[object_id]
		if value is String:
			_append_ascii(out, value as String)
			continue
		var stream: Dictionary = value
		var data: PackedByteArray = stream["data"]
		if str(stream.get("kind", "")) == "image":
			_append_ascii(out, ("%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d " +
				"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length %d >>\nstream\n") % [
				object_id, int(stream["width"]), int(stream["height"]), data.size()])
		else:
			_append_ascii(out, "%d 0 obj\n<< /Length %d >>\nstream\n" % [object_id, data.size()])
		out.append_array(data)
		_append_ascii(out, "\nendstream\nendobj\n")
	var xref_offset: int = out.size()
	var highest: int = int(ids[ids.size() - 1])
	_append_ascii(out, "xref\n0 %d\n0000000000 65535 f \n" % (highest + 1))
	for object_id: int in range(1, highest + 1):
		_append_ascii(out, "%010d 00000 n \n" % int(offsets.get(object_id, 0)))
	_append_ascii(out, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [
		highest + 1, xref_offset])
	return out


## One picture's pixels as plain RGB bytes, row by row - the shape a DeviceRGB image object wants.
static func rgb_bytes(picture: Image) -> PackedByteArray:
	var copy: Image = Image.new()
	copy.copy_from(picture)
	if copy.get_format() != Image.FORMAT_RGB8:
		copy.convert(Image.FORMAT_RGB8)
	return copy.get_data()


## `data` as a zlib stream: the two-byte header, the raw deflate, and the Adler-32 of the original
## bytes - what a PDF reader means by FlateDecode.
static func _flate(data: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.append(0x78)
	out.append(0x9C)
	out.append_array(data.compress(FileAccess.COMPRESSION_DEFLATE))
	var checksum: int = adler32(data)
	out.append((checksum >> 24) & 0xFF)
	out.append((checksum >> 16) & 0xFF)
	out.append((checksum >> 8) & 0xFF)
	out.append(checksum & 0xFF)
	return out


## The Adler-32 of a byte run, as zlib defines it.
static func adler32(data: PackedByteArray) -> int:
	var low: int = 1
	var high: int = 0
	for byte: int in data:
		low = (low + byte) % 65521
		high = (high + low) % 65521
	return (high << 16) | low


## The bytes a Flate stream carries, back again - the inverse of _flate, so a test can prove the
## pixels in the PDF are the pixels that went in.
static func unflate(stream: PackedByteArray, expected_size: int) -> PackedByteArray:
	if stream.size() <= ZLIB_HEADER_SIZE + ZLIB_CHECKSUM_SIZE:
		return PackedByteArray()
	return stream.slice(ZLIB_HEADER_SIZE, stream.size() - ZLIB_CHECKSUM_SIZE).decompress(
		expected_size, FileAccess.COMPRESSION_DEFLATE)


static func _append_ascii(into: PackedByteArray, text: String) -> void:
	into.append_array(text.to_ascii_buffer())
