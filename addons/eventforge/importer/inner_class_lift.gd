# Godot EventSheets - a class written inside a script, read as a Class head with its members under it.
#
# The body of `class Hit:` is ordinary GDScript one tab deeper, so it is read by the reader that reads
# every file: the body is taken one tab shallower, opened as a sheet of its own (variables become
# variable rows, functions become function events, a class inside it becomes a Class of its own), and
# kept on an InnerClassRow beside the header line.
#
# THE GATE. The body is written back by the compiler, every line one tab deeper again, and the class
# is claimed only when that reproduces its lines byte for byte. A class that cannot come back exactly
# stays the code it was, ON ITS OWN: the row holding it is split around the class first, so the lines
# beside it are untouched and the rest of the file still reads. And once every class is placed, the
# whole sheet is written once more and compared with the file (or, when the sheet wrote something else
# before, with that), so a claim can never move a byte anywhere else either. When that whole-file
# compare fails, the classes are claimed again one at a time, so only the one that moved a byte stays
# code.
#
# A class of fields alone is left to the reading it already has (a Data type with its fields as rows
# and its own Add field door); this claims the classes that hold behaviour.
@tool
extends RefCounted

## `class Name[ extends Base]:` at column 0 - the only header this reads. A class line with a comment
## after it, or written over two lines, is a spelling the header is not kept in, so it stays code.
const HEADER_PATTERN: String = "^class [A-Za-z_][A-Za-z0-9_]*(?: extends [A-Za-z_][A-Za-z0-9_.]*)?:$"


## Claims every class this sheet's top-level code rows hold that comes back byte for byte. Runs after
## the rest of the lift, on the rows it left as code; `source` is the file those rows were read from.
static func lift(sheet: EventSheetResource, source: String) -> void:
	if sheet == null or not _holds_any_class(sheet):
		return
	var header: RegEx = RegEx.create_from_string(HEADER_PATTERN)
	# The file's own path is set only once it is opened, after the lift; until then the order-keeping
	# path the compare below needs is reached through the body's.
	var saved_path: String = sheet.external_source_path
	if saved_path.is_empty():
		sheet.external_source_path = InnerClassRow.BODY_PATH
	var before_rows: Array = sheet.events.duplicate()
	_place(sheet, before_rows, _holders(before_rows, header), source)
	sheet.external_source_path = saved_path


## Every class read once, on its own: one entry per code row holding at least one class that came
## back, as {raw, pieces, classes: {piece index: InnerClassRow}}, in file order.
static func _holders(rows: Array, header: RegEx) -> Array[Dictionary]:
	var holders: Array[Dictionary] = []
	for entry: Variant in rows:
		var raw: RawCodeRow = entry as RawCodeRow
		if raw == null or not _has_class_line(raw.code):
			continue
		var pieces: Array[Dictionary] = _pieces(raw.code.split("
"), header)
		var classes: Dictionary = {}
		for piece_index: int in pieces.size():
			if bool(pieces[piece_index]["class"]):
				var inner: InnerClassRow = _read_class(pieces[piece_index]["lines"])
				if inner != null:
					classes[piece_index] = inner
		if not classes.is_empty():
			holders.append({"raw": raw, "pieces": pieces, "classes": classes})
	return holders


## The classes `holders` read, put into the sheet as long as the whole file still comes back: all of
## them when it does, otherwise again ONE AT A TIME in file order, each kept only while the file still
## comes back with it, so the class that moved a byte stays code and the ones beside it still read.
static func _place(sheet: EventSheetResource, before_rows: Array, holders: Array[Dictionary], source: String) -> void:
	var every: Array = []
	for holder_index: int in holders.size():
		for piece_index: Variant in (holders[holder_index]["classes"] as Dictionary).keys():
			every.append([holder_index, piece_index])
	if every.is_empty():
		return
	sheet.events = _claimed(before_rows, holders, every)
	var after_text: String = str(SheetCompiler.echo(sheet).get("output", ""))
	if after_text == source:
		return
	# The file as written is what the rows wrote before the claims, nearly always; only when the sheet
	# writes something else is the before written out to compare against.
	sheet.events = before_rows
	var before_text: String = str(SheetCompiler.echo(sheet).get("output", ""))
	var kept: Array = every
	if after_text != before_text:
		kept = []
		for claim: Array in every:
			sheet.events = _claimed(before_rows, holders, kept + [claim])
			if str(SheetCompiler.echo(sheet).get("output", "")) == before_text:
				kept.append(claim)
	sheet.events = _claimed(before_rows, holders, kept)


## `before_rows` with the `claims` ([holder index, piece index] pairs) put in: a code row holding a
## claimed class is split into its pieces, each claimed class an InnerClassRow and every other piece
## code as it stands; a code row with no claimed class is left whole.
static func _claimed(before_rows: Array, holders: Array[Dictionary], claims: Array) -> Array:
	var rows: Array = before_rows.duplicate()  # the sheet's own typed array, emptied
	rows.clear()
	for entry: Variant in before_rows:
		var holder_index: int = -1
		for index: int in holders.size():
			if holders[index]["raw"] == entry:
				holder_index = index
		var wanted: Array = []
		for claim: Array in claims:
			if int(claim[0]) == holder_index:
				wanted.append(claim[1])
		if wanted.is_empty():
			rows.append(entry)
			continue
		var raw: RawCodeRow = entry as RawCodeRow
		var pieces: Array[Dictionary] = holders[holder_index]["pieces"]
		for piece_index: int in pieces.size():
			if wanted.has(piece_index):
				rows.append(holders[holder_index]["classes"][piece_index])
				continue
			var code_row: RawCodeRow = RawCodeRow.new()
			code_row.code = "\n".join(pieces[piece_index]["lines"])
			code_row.enabled = raw.enabled
			code_row.note = raw.note
			code_row.lift_note = raw.lift_note
			rows.append(code_row)
	return rows


## One class, read: an InnerClassRow when its body comes back exactly, null otherwise. `lines` is
## the header and every line under it, trailing blank lines already handed back to what follows.
static func _read_class(lines: PackedStringArray) -> InnerClassRow:
	# A string opened inside the class and closed below it: the class ended inside a value.
	if "\n".join(lines).count("\"\"\"") % 2 == 1:
		return null
	var body: PackedStringArray = PackedStringArray()
	var holds_function: bool = false
	for line_index: int in range(1, lines.size()):
		var line: String = lines[line_index]
		if line.is_empty():
			body.append("")
		elif line.begins_with("\t"):
			body.append(line.substr(1))
			if line.begins_with("\tfunc ") or line.begins_with("\tstatic func "):
				holds_function = true
		else:
			return null  # a line this shallower body cannot hold (spaces, or a string at column 0)
	if not holds_function:
		return null
	var body_source: String = "\n".join(body) + "\n"
	var body_sheet: EventSheetResource = _open_body(body_source)
	if body_sheet == null:
		return null
	var row: InnerClassRow = InnerClassRow.new()
	row.header = lines[0]
	row.body = body_sheet
	if SheetCompiler.inner_class_lines(row) != lines:
		return null
	return row


## The body opened as a sheet, by the same importer and lift a whole file goes through. The lift's
## progress counters belong to the file being opened, so they are put back afterwards.
static func _open_body(body_source: String) -> EventSheetResource:
	var phase: String = EventSheetACELifter.progress_phase
	var total: int = EventSheetACELifter.progress_functions_total
	var done: int = EventSheetACELifter.progress_functions_done
	var body_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(body_source, true, "")
	EventSheetACELifter.progress_phase = phase
	EventSheetACELifter.progress_functions_total = total
	EventSheetACELifter.progress_functions_done = done
	return body_sheet


## The row's lines cut into pieces: each class (its header and the lines under it, without the blank
## lines after it) is a piece of its own, and the lines between classes are pieces as they stand.
## Every line lands in exactly one piece, in order, so the pieces always join back into the row.
static func _pieces(lines: PackedStringArray, header: RegEx) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var current: PackedStringArray = PackedStringArray()
	var inside_string: bool = false
	var index: int = 0
	while index < lines.size():
		var line: String = lines[index]
		if not inside_string and header.search(line) != null:
			if not current.is_empty():
				pieces.append({"class": false, "lines": current})
				current = PackedStringArray()
			var end: int = index + 1
			while end < lines.size() and (lines[end].strip_edges().is_empty() or lines[end].begins_with("\t") or lines[end].begins_with(" ")):
				end += 1
			while end > index + 1 and lines[end - 1].strip_edges().is_empty():
				end -= 1
			pieces.append({"class": true, "lines": lines.slice(index, end)})
			index = end
			continue
		if line.count("\"\"\"") % 2 == 1:
			inside_string = not inside_string
		current.append(line)
		index += 1
	if not current.is_empty():
		pieces.append({"class": false, "lines": current})
	return pieces


static func _holds_any_class(sheet: EventSheetResource) -> bool:
	for entry: Variant in sheet.events:
		if entry is RawCodeRow and _has_class_line((entry as RawCodeRow).code):
			return true
	return false


static func _has_class_line(code: String) -> bool:
	return code.begins_with("class ") or code.contains("\nclass ")
