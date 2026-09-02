# EventForge module - reading a part out of a line, and saying what went wrong.
#
# Two halves that answer the same beginner question ("what is actually in this text, and why did it
# not work?"), with no regular expression anywhere in the UI:
#
#   1. Extraction, in words. Text Before / Text Between / Text After name the piece you want instead
#      of the index arithmetic that computes it (Find + Mid), and Number In Text pulls the first
#      number out of a label, a header, a version string or a chat line. They cover log lines,
#      dialogue scripts with [mood] tags, filenames, BBCode, chat commands and pasted input.
#      Split Keeping Quotes is the splitter every console, search box and command line needs:
#      `give "iron sword" 2` is three pieces, not four.
#   2. Failure as a sentence. Explain JSON Problem, Explain Table Problem and Missing Fields turn a
#      silent null into text you can print - "line 4: Expected ':'", "row 12, column "price": "abc"
#      is not a number", "tiles, spawn_point". Their shared convention is what makes them safe to
#      branch on: an EMPTY result means nothing is wrong, so the shipped Text Is Blank condition
#      (inverted) is the whole failure branch. That convention is why each report must SAY something
#      for every input it cannot read - a diagnostic whose own failure mode is the all-clear would
#      wave the malformed file straight through the branch that exists to stop it.
#      One disagreement to know about, because it is not this module's to fix: the shipped JSON Is
#      Valid reads a document holding just the word `null` as invalid (its template is
#      `JSON.parse_string(text) != null`), while Explain JSON Problem correctly has nothing to say
#      about it, so composing the two logs an error with a blank reason. Branch on the report's own
#      emptiness instead. The condition's template is a shipped compatibility promise, so correcting
#      it belongs to a deprecation, not here.
#
# Every descriptor here is a pure expression: no state, no member declaration, no helper library, no
# plugin reference at runtime. Each is null-safe BY CONSTRUCTION rather than by convention - a missing
# marker, an empty line, a missing column and a null record each land on a documented empty result
# instead of an error, and every one of those edges is pinned in tests/text_extract_aces_test.gd.
#
# Two idioms recur and are deliberate:
#   - `(Array(text.split(marker, true, 1)) + [""])[1]` is "the rest after the first marker, or
#     nothing". String.get_slice cannot express it: with a missing delimiter get_slice returns the
#     WHOLE string for every index, so "the part after" would silently hand back the whole line.
#   - `(func(...): ...).call(...)` binds a value ONCE inside a single expression. JSON's error line
#     and message live on the JSON instance that parsed, so the instance must be named; the same
#     shape lets the table and record verbs read their argument once instead of three times.
@tool
class_name EventForgeTextExtractACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## Extraction sits with the shipped Token At / Mid / Find In Text verbs; the reports sit with the
## data they explain - JSON text under "JSON", one record under "Variables: Dictionary", and the
## table report in "Files: Tables" beside Table From File, the verb that PRODUCES the rows it reads
## (an author who just built a table and wants "why is my spreadsheet wrong" looks in one section,
## not two).
const TEXT_CAT := "Text"
const JSON_CAT := "JSON"
const TABLE_CAT := "Files: Tables"
const RECORD_CAT := "Variables: Dictionary"

## The teaching line every extraction verb defaults to, so a freshly dropped row already reads as a
## worked example: Before it is "Ada", Between the brackets is "angry", After "]: " is "hi".
const SAMPLE_LINE := "\"Ada [angry]: hi\""


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Extraction: name the piece, not the arithmetic ──
	# get_slice(marker, 0) is exactly "up to the first marker", and its missing-delimiter behaviour
	# (the whole string) is the right answer here: with no marker to cut at, the part before the
	# marker IS the whole line.
	descriptors.append(F.expr("TextBefore", "Text Before", "{text}.get_slice({marker}, 0)", TEXT_CAT, "the part of {text} before {marker}", "The part of the text before the first marker: Text Before(\"Ada [angry]: hi\", \" [\") is \"Ada\". When the marker is not there you get the whole text back, so nothing is silently lost.").param_typed("String", "text", SAMPLE_LINE, "Text", "The line to read a piece out of.", "expression").param("marker", "\" [\"", "Before", "The marker to stop at (the first one wins).", "expression"))

	# "Everything after the first marker" needs the split form: get_slice would return the whole
	# string when the marker is missing, and only the NEXT segment when it repeats.
	descriptors.append(F.expr("TextAfter", "Text After", "str((Array({text}.split({marker}, true, 1)) + [\"\"])[1])", TEXT_CAT, "the part of {text} after {marker}", "Everything after the first marker: Text After(\"Ada [angry]: hi\", \"]: \") is \"hi\". Empty when the marker is not there, because then there is no \"after\".").param_typed("String", "text", SAMPLE_LINE, "Text", "The line to read a piece out of.", "expression").param("marker", "\"]: \"", "After", "The marker to start after (the first one wins).", "expression"))

	descriptors.append(F.expr("TextBetween", "Text Between", "str((Array({text}.split({open}, true, 1)) + [\"\"])[1]).get_slice({close}, 0)", TEXT_CAT, "the part of {text} between {open} and {close}", "The part between two markers: Text Between(\"Ada [angry]: hi\", \"[\", \"]\") is \"angry\". Empty when the opening marker is missing, and the rest of the text when the closing one is.").param_typed("String", "text", SAMPLE_LINE, "Text", "The line to read a piece out of.", "expression").param("open", "\"[\"", "After", "The opening marker.", "expression").param("close", "\"]\"", "Before", "The closing marker.", "expression").featured())

	# The one verb that compiles to a regular expression - and shows none. `-?[0-9]+(\.[0-9]+)?`
	# matches a whole or decimal number, optionally signed; search_all returns [] on a miss, so the
	# + ["0"] tail is what makes "no number" read as 0 instead of crashing.
	descriptors.append(F.expr("NumberInText", "Number In Text", "(RegEx.create_from_string(\"-?[0-9]+(\\\\.[0-9]+)?\").search_all({text}).map(func(__m): return __m.get_string()) + [\"0\"]).front().to_float()", TEXT_CAT, "the first number in {text}", "The first number found anywhere in the text, whole or decimal: \"Chapter 3\" gives 3, \"v1.25-beta\" gives 1.25. You get 0 when there is no number at all, and you never write a pattern.").param("text", "\"Chapter 3\"", "Text", "Text that has a number somewhere in it.", "expression"))

	# Quote-aware splitting as ONE expression: split on the quote character, then walk the segments
	# with an accumulator that flips on each quote. Even segments (outside quotes) split on the
	# separator with allow_empty = false, so runs of spaces collapse; odd segments (inside quotes)
	# survive whole. An empty quoted "" falls through to the split branch, which yields nothing.
	descriptors.append(F.expr("SplitKeepingQuotes", "Split Keeping Quotes", "Array({text}.split(\"\\\"\")).reduce(func(__acc, __part): return [not __acc[0], __acc[1] + ([__part] if __acc[0] and not __part.is_empty() else Array(__part.split({separator}, false)))], [false, []])[1]", TEXT_CAT, "pieces of {text}, keeping quotes together", "Splits text on a separator but keeps anything inside \"double quotes\" together as one piece, and drops the quotes: give \"iron sword\" 2 is three pieces, not four. Empty pieces are skipped, so runs of separators never produce blanks.").param("text", "\"give \\\"iron sword\\\" 2\"", "Text", "The line to split - a console entry, a search box, a pasted cell.", "expression").param("separator", "\" \"", "Separator", "What separates the pieces OUTSIDE quotes.", "expression").featured())

	# ── Reports: the failure as a sentence, empty when there is nothing to say ──
	# JSON.parse_string() answers null for both "invalid" and the literal null, and carries no
	# message at all. The line and the message live on the JSON instance that parsed, so the instance
	# is bound by an immediately-called lambda - the only way to name it inside one expression.
	# get_error_line() counts from 0; the + 1 makes it the line number an editor shows.
	descriptors.append(F.expr("ExplainJsonProblem", "Explain JSON Problem", "(func(__json: JSON) -> String: return \"\" if __json.parse({text}) == OK else \"line %d: %s\" % [__json.get_error_line() + 1, __json.get_error_message()]).call(JSON.new())", JSON_CAT, "why {text} is not valid JSON", "Why this JSON failed to parse, with the line: \"line 4: Expected ':'\". Empty when it parses fine, so an empty result IS the all-clear. Log it and the bug report writes itself. Branch on this expression's own emptiness (Text Is Blank, inverted) rather than on JSON Is Valid: that condition reads a file holding just the word null as invalid, and this one has nothing to say about it, so pairing them logs an error with a blank reason.").param("text", "\"{}\"", "Text", "The JSON text to check - a file you read, a paste, a server reply.", "expression").featured())

	# One list of records, the columns that must hold numbers, and the FIRST cell that does not.
	# The rows are bound once by the lambda, so the argument is evaluated a single time no matter how
	# many rows and columns are walked. A missing column reads as an empty cell, which is also not a
	# number, so a mistyped column name is reported rather than skipped.
	#
	# The typeof guard on each row is load-bearing, not defensive noise. Without it a row that is not
	# a record at all (a list of LISTS, which is what a table read by some other route looks like)
	# faulted inside the lambda on `.get(column, "")` and the whole expression evaluated to "" - and
	# "" is this module's ALL-CLEAR, so the one shape the verb cannot read reported that nothing was
	# wrong and waved a malformed import straight through the branch meant to stop it. Now it says so.
	#
	# Rows are numbered from 1 over the RECORDS, which is what the caller holds; a file read by Table
	# From File has already dropped its header line, so line 1 of the spreadsheet is not a row here.
	# The description says that rather than promising spreadsheet line numbers it cannot know.
	descriptors.append(F.expr("ExplainTableProblem", "Explain Table Problem", "(func(__rows: Array, __cols: Array) -> String: return str((range(__rows.size()).map(func(__i): return (([\"row %d is not a record\" % (__i + 1)] if typeof(__rows[__i]) != TYPE_DICTIONARY else __cols.filter(func(__c): return not str(__rows[__i].get(__c, \"\")).strip_edges().is_valid_float()).map(func(__c): return \"row %d, column \\\"%s\\\": \\\"%s\\\" is not a number\" % [__i + 1, __c, __rows[__i].get(__c, \"\")])) + [\"\"]).front()).filter(func(__p): return not str(__p).is_empty()) + [\"\"]).front())).call({records}, {columns})", TABLE_CAT, "what is wrong in {records}", "The first cell of a table that should be a number and is not, said out loud: \"row 12, column \"price\": \"abc\" is not a number\". Rows are counted from 1 over the rows you hold - Table From File has already used up the header line, so row 12 is line 13 of the file. A row that is not a record at all is reported too. Empty when every listed column checks out.").param("records", "[]", "Rows", "A list of records - one per row, each field reachable by column name.", "expression").param("columns", "[\"price\"]", "Number columns", "The columns that must hold numbers.", "expression"))

	# Works on a record OR a resource, because Dictionary.get(key) and Object.get(property) both
	# answer null for something that is not there. Blank means null, empty text, an empty list or an
	# empty record - a 0 is a real value and is never reported as missing.
	descriptors.append(F.expr("MissingFields", "Missing Fields", "(func(__record: Variant, __names: Array) -> String: return \", \".join(PackedStringArray(__names.map(func(__n): return [str(__n).strip_edges(), __record.get(str(__n).strip_edges()) if __record != null else null]).filter(func(__p): return __p[1] == null or ((__p[1] is String or __p[1] is Array or __p[1] is Dictionary) and __p[1].is_empty())).map(func(__p): return __p[0])))).call({record}, Array({fields}.split(\",\")))", RECORD_CAT, "the fields missing from {record}", "The listed fields that are missing or left blank, comma-separated, and empty when the record is complete. Blank means nothing there: null, empty text, an empty list or an empty record - a 0 is a real value and is never reported.").param("record", "{}", "Record", "A record or a resource to check.", "expression").param("fields", "\"id, name\"", "Fields", "The fields it must have filled in, separated by commas.", "expression"))

	return descriptors
