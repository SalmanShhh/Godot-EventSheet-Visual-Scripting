# Godot EventSheets - Grid to CSV and back (the data-asset grid round trip).
#
# A data asset's grid (an Array of Dictionary rows behind the Inspector's table drawer) written out
# as a CSV a designer opens in a spreadsheet, and an edited CSV read back into that grid. Balance
# passes, translators, bulk generation from external tools, a git-diffable content review, and
# importing a table someone built before they ever opened Godot - all of that is one file away, and
# the answer to "did it actually save" is a sentence, never a guess: every write reports the real
# Error it got back.
#
# THE PARSE POLICY IS THE RUNTIME'S. Table From File (the shipped Files: Tables verb) already reads
# a header-row CSV at game time, and this reader answers identically for the same bytes:
#   - the FIRST line is the column names; a blank name is skipped and a repeated one keeps the
#     first column, so no row can address two columns by one name,
#   - a cell in "double quotes" may contain the separator, and a doubled "" inside it is one
#     literal quote,
#   - a line whose quotes do NOT pair up splits plainly, keeping the stray quote as a character
#     (an inches mark, a hand-typed row) instead of silently swallowing a column,
#   - CRLF / lone-CR endings and blank lines are normalised away, so a missing trailing newline is
#     a non-event,
#   - a SHORT row fills its missing columns rather than being dropped; cells past the last column
#     name are ignored.
# tests/editor_seams_test.gd pins that agreement against the runtime expression itself, so the two
# can never drift apart.
#
# TYPES COME FROM THE GRID, NOT THE FILE. A CSV cell is text; the column schema (the table drawer's
# {name, type} list, read from the resource's own export hint or from the sheet variable's
# attributes) says whether it lands as an int, a float, a bool or text - and a column the CSV never
# mentions is filled with the SAME blank the drawer's "Add Row" button uses, so an imported row is
# indistinguishable from a hand-added one.
@tool
class_name EventSheetGridCSV
extends RefCounted

## Column separators offered by the dialog. The keys are the literal characters; the list matches
## the runtime table verbs' picker, because these three are what a spreadsheet export writes.
const SEPARATOR_OPTIONS: Array[Dictionary] = [
	{"key": ",", "label": "Comma  (.csv)"},
	{"key": ";", "label": "Semicolon"},
	{"key": "\t", "label": "Tab  (.tsv)"}
]
## Cell types the round trip understands; anything else is carried as text.
const CELL_TYPES: Array[String] = ["String", "int", "float", "bool", "enum", "color"]

# ── Column schemas ───────────────────────────────────────────────────────────


## The schema declared on a RESOURCE property (`@export_custom(..., "eventsheet:table:a=int,b=String")`),
## parsed by the drawer's own reader so the CSV columns are exactly the Inspector's columns.
static func columns_from_resource(resource: Resource, property_name: String) -> Array:
	if resource == null or property_name.is_empty():
		return []
	for property: Dictionary in resource.get_property_list():
		if str(property.get("name", "")) != property_name:
			continue
		var hint: Dictionary = EventSheetAttributeDrawers.parse_drawer_hint(str(property.get("hint_string", "")))
		if str(hint.get("drawer", "")) != "table":
			continue
		var args: Array = hint.get("args", []) if hint.get("args") is Array else []
		return EventSheetAttributeDrawers.parse_table_columns(str(args[0]) if not args.is_empty() else "")
	return []


## The schema declared on a SHEET VARIABLE (the `{"drawer": "table", "table_columns": [...]}`
## attributes EventSheets.resource_grid builds).
static func columns_from_attributes(attributes: Dictionary) -> Array:
	if str(attributes.get("drawer", "")) != "table" or not (attributes.get("table_columns") is Array):
		return []
	var columns: Array = []
	for entry: Variant in (attributes.get("table_columns") as Array):
		if not (entry is Dictionary):
			continue
		var column_name: String = str((entry as Dictionary).get("name", "")).strip_edges()
		if column_name.is_empty():
			continue
		var column_type: String = str((entry as Dictionary).get("type", "String")).strip_edges()
		var options: Array = SheetCompiler.table_enum_options(column_type)
		if not options.is_empty():
			columns.append({"name": column_name, "type": "enum", "options": options})
			continue
		columns.append({"name": column_name, "type": column_type if CELL_TYPES.has(column_type) else "String"})
	return columns


## The last-resort schema: the keys the ROWS themselves use, in first-seen order, typed by the value
## found. It keeps the round trip working on a grid whose declaration is unavailable (a plain
## Array property, a resource from another plugin) instead of refusing the whole file.
static func columns_from_rows(rows: Array) -> Array:
	var columns: Array = []
	var seen: Dictionary = {}
	for row: Variant in rows:
		if not (row is Dictionary):
			continue
		for key: Variant in (row as Dictionary).keys():
			var column_name: String = str(key)
			if seen.has(column_name):
				continue
			seen[column_name] = true
			var value: Variant = (row as Dictionary)[key]
			var column_type: String = "String"
			if value is bool:
				column_type = "bool"
			elif value is int:
				column_type = "int"
			elif value is float:
				column_type = "float"
			columns.append({"name": column_name, "type": column_type})
	return columns

# ── Text codec ───────────────────────────────────────────────────────────────


## The grid as CSV text: the column names as the first line, one line per row, terminated by a
## newline (what every spreadsheet writes, and what the reader forgives either way).
static func to_csv(rows: Array, columns: Array, separator: String = ",") -> String:
	var lines: PackedStringArray = PackedStringArray()
	var header: PackedStringArray = PackedStringArray()
	for column: Variant in columns:
		header.append(_escape_cell(str((column as Dictionary).get("name", "")), separator))
	lines.append(separator.join(header))
	for row: Variant in rows:
		var record: Dictionary = row as Dictionary if row is Dictionary else {}
		var cells: PackedStringArray = PackedStringArray()
		for column: Variant in columns:
			var column_name: String = str((column as Dictionary).get("name", ""))
			cells.append(_escape_cell(cell_text(record.get(column_name, "")), separator))
		lines.append(separator.join(cells))
	return "\n".join(lines) + "\n"


## One stored cell as the text a spreadsheet shows. Numbers keep their own form (no thousands
## separators, no locale), booleans read as true/false, everything else is its plain text.
static func cell_text(value: Variant) -> String:
	if value == null:
		return ""
	if value is bool:
		return "true" if value else "false"
	if value is float:
		# str() on a whole float gives "1" in Godot; the column type is what re-types it on the way
		# back in, so the shortest honest text is what belongs in a spreadsheet cell.
		return String.num(value, 6).rstrip("0").rstrip(".") if value != floorf(value) else str(int(value))
	return str(value)


## CSV text -> one record per row, keyed by the header names (the runtime's parse policy - see the
## file header). The header line itself is never a record.
static func parse_records(text: String, separator: String = ",") -> Array:
	var records: Array = []
	var lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n", false)
	if lines.is_empty():
		return records
	var header: PackedStringArray = split_cells(lines[0], separator)
	for line_index: int in range(1, lines.size()):
		var cells: PackedStringArray = split_cells(lines[line_index], separator)
		var record: Dictionary = {}
		for column_index: int in range(header.size()):
			var column_name: String = header[column_index].strip_edges()
			if column_name.is_empty() or record.has(column_name):
				continue
			record[column_name] = cells[column_index] if column_index < cells.size() else ""
		records.append(record)
	return records


## One CSV line split into cells, quote-aware. A line with an ODD number of quote characters has no
## closing quote, so it splits plainly and the stray quote stays a literal character - without that
## branch every separator after it would be protected and the line would silently lose a column.
static func split_cells(line: String, separator: String = ",") -> PackedStringArray:
	# Control-character sentinels, the same trick the runtime table verb uses: a separator INSIDE a
	# quoted cell and an escaped "" both become a character no spreadsheet writes, so the split cannot
	# break them apart and no cell is ever re-scanned.
	var protected_separator: String = "\u001f"
	var escaped_quote: String = "\u0001"
	var working: String = line.replace("\"\"", escaped_quote)
	if working.count("\"") % 2 == 0:
		var rebuilt: String = ""
		var inside: bool = false
		for part: String in working.split("\""):
			rebuilt += part.replace(separator, protected_separator) if inside else part
			inside = not inside
		working = rebuilt
	var cells: PackedStringArray = PackedStringArray()
	for cell: String in working.split(separator):
		cells.append(cell.replace(protected_separator, separator).replace(escaped_quote, "\""))
	return cells


## CSV text -> grid rows shaped by `columns`, plus the sentence saying what lined up: which columns
## the file never mentioned (filled with the drawer's own blank) and which it carried that the grid
## has no room for (ignored).
static func rows_from_csv(text: String, columns: Array, separator: String = ",") -> Dictionary:
	var records: Array = parse_records(text, separator)
	var rows: Array = []
	var known: Dictionary = {}
	for column: Variant in columns:
		known[str((column as Dictionary).get("name", ""))] = true
	var missing: PackedStringArray = PackedStringArray()
	var ignored: Dictionary = {}
	for record: Variant in records:
		var source: Dictionary = record as Dictionary
		var row: Dictionary = {}
		for column: Variant in columns:
			var column_dict: Dictionary = column as Dictionary
			var column_name: String = str(column_dict.get("name", ""))
			if not source.has(column_name):
				if not missing.has(column_name):
					missing.append(column_name)
				row[column_name] = EventSheetDrawerWidgets.DrawerTable._default_for(column_dict)
				continue
			row[column_name] = cell_value(str(source[column_name]), column_dict)
		for key: Variant in source.keys():
			if not known.has(str(key)):
				ignored[str(key)] = true
		rows.append(row)
	var notes: PackedStringArray = PackedStringArray()
	notes.append("%d row(s)" % rows.size())
	if not missing.is_empty():
		notes.append("filled %s (no such column in the file)" % ", ".join(missing))
	if not ignored.is_empty():
		var ignored_names: Array = ignored.keys()
		ignored_names.sort()
		notes.append("ignored %s (no such column in the grid)" % ", ".join(PackedStringArray(ignored_names)))
	return {"rows": rows, "note": ", ".join(notes)}


## One CSV cell as the value its column stores - the same shapes the table drawer writes, so an
## imported row and a hand-typed one are indistinguishable.
static func cell_value(text: String, column: Dictionary) -> Variant:
	var trimmed: String = text.strip_edges()
	match str(column.get("type", "String")):
		"int":
			return int(trimmed.to_float()) if trimmed.is_valid_float() else 0
		"float":
			return trimmed.to_float() if trimmed.is_valid_float() else 0.0
		"bool":
			return trimmed.to_lower() in ["true", "1", "yes", "on"]
	return text

# ── Files: the round trip, with the real outcome ─────────────────────────────


## The grid property's rows on a loaded resource, or {} with a readable reason.
static func read_grid(resource: Resource, property_name: String) -> Dictionary:
	if resource == null:
		return {"ok": false, "message": "There is no resource to read."}
	var value: Variant = resource.get(property_name)
	if not (value is Array):
		var grids: PackedStringArray = grid_property_names(resource)
		var suggestion: String = " It has: %s." % ", ".join(grids) if not grids.is_empty() else " It has no grid at all."
		return {"ok": false, "message": "\"%s\" is not a grid on this resource.%s" % [property_name, suggestion]}
	return {"ok": true, "rows": value as Array}


## Every Array property on the resource - what to offer when the named grid isn't there.
static func grid_property_names(resource: Resource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if resource == null:
		return names
	for property: Dictionary in resource.get_property_list():
		if int(property.get("type", TYPE_NIL)) == TYPE_ARRAY and (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
			names.append(str(property.get("name", "")))
	return names


## Writes the CSV. The message is the receipt: the path and the row count when it landed, the real
## file error when it did not.
static func write_csv(csv_path: String, rows: Array, columns: Array, separator: String = ",") -> Dictionary:
	if csv_path.strip_edges().is_empty():
		return {"ok": false, "message": "Give the .csv a path to write to."}
	if columns.is_empty():
		return {"ok": false, "message": "This grid has no columns, so there is nothing to line up in a spreadsheet."}
	var file: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not write %s - %s." % [csv_path, error_string(FileAccess.get_open_error())]}
	file.store_string(to_csv(rows, columns, separator))
	file.close()
	return {"ok": true, "message": "Wrote %d row(s) to %s." % [rows.size(), csv_path], "rows": rows.size()}


## Reads the CSV into grid rows. Missing file, unreadable file and an empty file each answer in
## words rather than as an empty grid nobody asked for.
static func read_csv(csv_path: String, columns: Array, separator: String = ",") -> Dictionary:
	if csv_path.strip_edges().is_empty():
		return {"ok": false, "message": "Give the .csv a path to read from."}
	if not FileAccess.file_exists(csv_path):
		return {"ok": false, "message": "Could not read %s - there is no file at that path." % csv_path}
	var file: FileAccess = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Could not read %s - %s." % [csv_path, error_string(FileAccess.get_open_error())]}
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {"ok": false, "message": "%s is empty - a grid CSV needs a first line naming the columns." % csv_path}
	var parsed: Dictionary = rows_from_csv(text, columns, separator)
	return {"ok": true, "rows": parsed.get("rows", []), "message": "Read %s - %s." % [csv_path, str(parsed.get("note", ""))]}


## Saves the data asset back, reporting the Error by name. This is the "did it save?" half: a write
## that fails says which error it was, instead of looking exactly like a write that worked.
static func save_resource(resource: Resource, resource_path: String) -> Dictionary:
	if resource == null:
		return {"ok": false, "message": "There is no resource to save."}
	var error: int = ResourceSaver.save(resource, resource_path)
	if error != OK:
		return {"ok": false, "message": "Could not save %s - %s." % [resource_path, error_string(error)], "error": error}
	return {"ok": true, "message": "Saved %s." % resource_path, "error": OK}


## Whole export: a data asset's grid out to a .csv. One call so the dialog, an extension, and the
## suite all take the same path.
static func export_to_csv(resource_path: String, property_name: String, csv_path: String, separator: String = ",") -> Dictionary:
	var resource: Resource = load(resource_path) if ResourceLoader.exists(resource_path) else null
	if resource == null:
		return {"ok": false, "message": "Could not load %s - there is no data asset at that path." % resource_path}
	var grid: Dictionary = read_grid(resource, property_name)
	if not bool(grid.get("ok", false)):
		return grid
	var rows: Array = grid.get("rows", [])
	var columns: Array = columns_from_resource(resource, property_name)
	if columns.is_empty():
		columns = columns_from_rows(rows)
	return write_csv(csv_path, rows, columns, separator)


## Whole import: a .csv back into a data asset's grid, saved. Reports the read AND the save, so a
## file that parsed but could not be written says exactly that.
static func import_from_csv(csv_path: String, resource_path: String, property_name: String, separator: String = ",") -> Dictionary:
	var resource: Resource = load(resource_path) if ResourceLoader.exists(resource_path) else null
	if resource == null:
		return {"ok": false, "message": "Could not load %s - there is no data asset at that path." % resource_path}
	var grid: Dictionary = read_grid(resource, property_name)
	if not bool(grid.get("ok", false)):
		return grid
	var columns: Array = columns_from_resource(resource, property_name)
	if columns.is_empty():
		columns = columns_from_rows(grid.get("rows", []))
	var read: Dictionary = read_csv(csv_path, columns, separator)
	if not bool(read.get("ok", false)):
		return read
	resource.set(property_name, read.get("rows", []))
	var saved: Dictionary = save_resource(resource, resource_path)
	if not bool(saved.get("ok", false)):
		return saved
	return {
		"ok": true,
		"rows": (read.get("rows", []) as Array).size(),
		"message": "%s %s" % [str(read.get("message", "")), str(saved.get("message", ""))]
	}


## Doubles the quotes and wraps the cell only when it has to - a separator, a quote or a line break
## inside it. Everything else stays bare, so the file stays diffable.
static func _escape_cell(text: String, separator: String) -> String:
	if text.contains(separator) or text.contains("\"") or text.contains("\n") or text.contains("\r"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text
