# EventForge module - Tables (a spreadsheet read as rows of records) plus the text/folder loops.
#
# WHAT THIS IS. One expression turns a .csv whose FIRST line is the column names into an Array of
# Dictionaries - one record per row, every field reachable as row["price"] - so the designer-edits-a-
# spreadsheet pipeline (items, enemies, dialogue lines, level metadata, loot weights, quest steps)
# stops being a wall of retyped actions. Table From Text is the same parse over a blob you already
# have; Column Of Table and Row Where read one column / one record back out of the result.
#
# WHY THE TEMPLATES ARE ONE (long) LINE. An expression lands in an fx field, so it has to BE a single
# GDScript expression: no statements, no helper function, and nothing from the plugin at runtime -
# the parity contract says emitted code is plain GDScript that keeps working after the plugin is
# deleted. The parse is therefore written as a fold rather than a loop, and every local it needs is
# a lambda parameter (all named with a __ prefix so none of them can shadow a sheet variable).
#
# THE PARSE POLICY - every clause below is pinned by tests/table_aces_test.gd:
#   - a cell wrapped in "double quotes" may contain the separator, and a doubled "" inside such a
#     cell is one literal quote character. Both survive by swapping them for control-character
#     sentinels (U+0001 for the escaped quote, U+001F for a protected separator) before the split
#     and swapping them back afterwards, so no cell is ever re-scanned.
#   - CRLF and lone-CR line endings are normalised before the line split and blank lines are
#     dropped, which is also what makes a missing trailing newline a non-event.
#   - a BLANK column name is skipped (no row could address it) and a REPEATED column name keeps the
#     FIRST column's value, so row["price"] and Column Of Table(table, "price") can never disagree
#     about which column they mean.
#   - a SHORT row fills its missing columns with "" instead of being dropped, and cells past the
#     last column name are ignored. A missing or unreadable file reads as "" and so as no rows.
#   - a line whose quote characters do not PAIR UP (an inches mark, a hand-typed row) is split
#     plainly, with the stray quote kept as a literal character. Without that clause the fold's
#     inside/outside flag never closed and every separator after the stray quote was protected, so
#     the line silently lost a column.
#
# LOOPING CONDITIONS. For Each Line / Part / Resource are CONDITIONS whose template returns a
# COLLECTION: `.looping(iterator)` lands them in the event's loop lane as a pick filter, so the
# event's actions run once per item and the loop index, frame-spreading and byte-exact round-trip
# all come from the pick machinery that already ships.
#
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never
# rename). Module contract: see ace_factory.gd.
@tool
class_name EventForgeTableACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT_TABLES := "Files: Tables"
const CAT_LOOPS := "Loops"

## The separator picker. Values are inserted verbatim into the template, so each key is a GDScript
## string literal, never a bare character. Deliberately a short fixed list: these three are what a
## spreadsheet export actually writes, and the parse policy above is proven against them.
const SEPARATOR_OPTIONS: Array = [
	{"key": "\",\"", "label": "Comma"},
	{"key": "\";\"", "label": "Semicolon"},
	{"key": "\"\\t\"", "label": "Tab"}
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# -- Tables: a spreadsheet as rows of records --
	descriptors.append(F.make_descriptor("Core", "TableFromFile", "Table From File", ACEDescriptor.ACEType.EXPRESSION,
		table_expression("FileAccess.get_file_as_string({path})", "{separator}"), "",
		[F.make_param("path", "String", "\"res://data/items.csv\"", "File", "The .csv to read. Its FIRST line must be the column names.", "expression"),
			_separator_param()],
		CAT_TABLES, "rows of [b]{path}[/b]")
		.described("Reads a .csv whose FIRST line is the column names and gives you one record per row, each field reachable by column name - row[\"price\"]. Quoted cells may contain the separator, Windows line endings are fine, and a missing file simply gives no rows. Store it in an Array variable, then walk it with a For Each pick filter.").featured())

	descriptors.append(F.make_descriptor("Core", "TableFromText", "Table From Text", ACEDescriptor.ACEType.EXPRESSION,
		table_expression("{text}", "{separator}"), "",
		[F.make_param("text", "String", "\"\"", "Text", "Spreadsheet text you already have - a pasted blob, a downloaded body, a file you read earlier. FIRST line = the column names.", "expression"),
			_separator_param()],
		CAT_TABLES, "rows in [b]{text}[/b]")
		.described("The same column-names-first parse as Table From File, but over text you already hold instead of a file on disk."))

	descriptors.append(F.make_descriptor("Core", "TableColumn", "Column Of Table", ACEDescriptor.ACEType.EXPRESSION,
		"{table}.map(func(__record): return __record.get({column}, \"\"))", "",
		[_table_param(), F.make_param("column", "String", "\"price\"", "Column", "The column name to read, exactly as it is spelled in the header row.", "expression")],
		CAT_TABLES, "column [b]{column}[/b] of [b]{table}[/b]")
		.described("Gives one whole column as a list, in row order - handy for a dropdown's items, a weights list, or a quick sum. A row missing that column contributes empty text."))

	descriptors.append(F.make_descriptor("Core", "TableRowWhere", "Row Where", ACEDescriptor.ACEType.EXPRESSION,
		"{table}.reduce(func(__found, __record): return __found if not __found.is_empty() else (__record if str(__record.get({column}, \"\")) == str({value}) else __found), {})", "",
		[_table_param(), F.make_param("column", "String", "\"id\"", "Column", "The column to match on, exactly as it is spelled in the header row.", "expression"),
			F.make_param("value", "String", "\"sword\"", "Is", "The value to look for. Compared as text, so 25 and \"25\" both match a cell reading 25.", "expression")],
		CAT_TABLES, "row of [b]{table}[/b] where [b]{column}[/b] is [b]{value}[/b]")
		.described("Finds the FIRST record whose column holds this value - the single-item lookup, e.g. the row for item \"sword\". Gives an empty record when nothing matches, so check it with Dictionary Is Empty before reading fields."))

	# -- Looping conditions: the loop lane, one row instead of split-then-pick-filter --
	descriptors.append(F.make_descriptor("Core", "ForEachLineInText", "For Each Line In Text", ACEDescriptor.ACEType.CONDITION,
		"{text}.replace(\"\\r\\n\", \"\\n\").replace(\"\\r\", \"\\n\").split(\"\\n\", false)", "",
		[F.make_param("text", "String", "\"\"", "Text", "The text to walk line by line - a file you read, a pasted blob, a leaderboard body.", "expression")],
		CAT_LOOPS, "for each line in [b]{text}[/b]")
		.described("Runs this event's actions once per LINE of the text, skipping blank ones. Windows (CRLF) and old-Mac (CR) endings are handled, so no line arrives with a stray carriage return. Read the current one as `line`.").looping("line").featured())

	descriptors.append(F.make_descriptor("Core", "ForEachPartInText", "For Each Part In Text", ACEDescriptor.ACEType.CONDITION,
		"Array({text}.split({separator}, false)).map(func(__part): return __part.strip_edges()).filter(func(__part): return not __part.is_empty())", "",
		[F.make_param("text", "String", "\"\"", "Text", "The text to break up - a tag list, a chat command's arguments, one cell of a spreadsheet.", "expression"),
			F.make_param("separator", "String", "\",\"", "Split by", "What separates the pieces, e.g. \",\" or \";\" or \" \".", "expression")],
		CAT_LOOPS, "for each part of [b]{text}[/b] split by [b]{separator}[/b]")
		.described("Runs this event's actions once per PIECE of the text. Each piece arrives with its surrounding spaces trimmed, and empty pieces are skipped, so \"sword; shield;; bow\" is three parts. Read the current one as `part`.").looping("part"))

	descriptors.append(F.make_descriptor("Core", "ForEachResourceInFolder", "For Each Resource In Folder", ACEDescriptor.ACEType.CONDITION,
		"Array(DirAccess.get_files_at({folder}) if DirAccess.dir_exists_absolute({folder}) else PackedStringArray()).map(func(__file): return String(__file).trim_suffix(\".remap\")).filter(func(__file): return __file.ends_with(\".tres\") or __file.ends_with(\".res\")).map(func(__file): return load({folder}.path_join(__file))).filter(func(__resource): return __resource != null)", "",
		[F.make_param("folder", "String", "\"res://data/items\"", "Folder", "Folder of data assets to walk. Only .tres / .res files are loaded; anything else in there is ignored.", "expression")],
		CAT_LOOPS, "for each resource in [b]{folder}[/b]")
		.described("Runs this event's actions once per data asset (.tres / .res) in a folder, already loaded - the \"a folder of items IS my item list\" setup, with no list to maintain. A folder that is not there walks nothing (quietly - it is checked first, so a loop that runs every frame cannot spam errors), and anything that fails to load is skipped rather than arriving as null. Read the current one as `entry`.").looping("entry"))

	return descriptors


## The whole table parse as ONE expression: `text_expression` is the spreadsheet text (a file read or
## a blob), `separator_expression` the column separator, both already in GDScript form. Composed here
## rather than typed twice so Table From File and Table From Text can never drift apart; the STRING
## this returns is the frozen artifact, so change it only the way a shipped template changes (not at
## all). The outer lambda exists to name the parsed rows once - an expression cannot declare a local,
## and the header row is needed for every record.
static func table_expression(text_expression: String, separator_expression: String) -> String:
	var lines: String = "Array(%s.replace(\"\\r\\n\", \"\\n\").replace(\"\\r\", \"\\n\").split(\"\\n\", false))" % text_expression
	var rows: String = "%s.map(func(__line): return %s)" % [lines, cells_expression("__line", separator_expression)]
	return "(func(__rows): return range(1, __rows.size()).map(func(__row): return range(__rows[0].size()).reduce(func(__record, __column): return __record if __rows[0][__column].strip_edges().is_empty() else __record.merged({__rows[0][__column].strip_edges(): (__rows[__row][__column] if __column < __rows[__row].size() else \"\")}), {}))).call(%s)" % rows


## One line of a spreadsheet split into cells, quote-aware, as ONE expression. The fold walks the
## pieces between double quotes and flips an inside/outside flag: outside pieces keep their
## separators, inside pieces have theirs swapped for U+001F so the split cannot break a quoted cell
## apart. A doubled "" is swapped for U+0001 first, so it neither flips the flag nor survives as two
## characters. Both sentinels are swapped back in the final map.
##
## UNBALANCED QUOTES take the other branch, and that branch is the whole reason the line is bound by
## a lambda here. A line with an ODD number of quote characters has no closing quote, so the fold's
## flag stays "inside" to the end of the line and every separator after the stray quote is protected
## - `1,12" pipe,50` came back as TWO cells and lost the price column, silently. When the count is
## odd the protection pass is skipped entirely and the line splits plainly, so the stray quote is
## what it obviously is: a literal character in a cell (an inches mark, a hand-typed row). The `""`
## sentinel is still swapped back either way, so an escaped quote survives both branches.
static func cells_expression(line_expression: String, separator_expression: String) -> String:
	return "Array((func(__line): return (Array(__line.split(\"\\\"\")).reduce(func(__acc, __part): return [__acc[0] + (__part.replace(%s, \"\\u001f\") if __acc[1] else __part), not __acc[1]], [\"\", false])[0] if __line.count(\"\\\"\") %% 2 == 0 else __line)).call(%s.replace(\"\\\"\\\"\", \"\\u0001\")).split(%s)).map(func(__cell): return __cell.replace(\"\\u001f\", %s).replace(\"\\u0001\", \"\\\"\"))" % [separator_expression, line_expression, separator_expression, separator_expression]


## The column separator picker, shared by both table expressions.
static func _separator_param() -> ACEParam:
	return F.make_param("separator", "String", "\",\"", "Separator", "What separates the columns in that file.", "", SEPARATOR_OPTIONS)


## The parsed table a reading verb works on - the Array variable a Table From File / Table From Text
## expression was stored in.
static func _table_param() -> ACEParam:
	return F.make_param("table", "String", "table", "Table", "The rows-of-records variable a Table From File (or Table From Text) expression filled.", "variable_reference:Array")
