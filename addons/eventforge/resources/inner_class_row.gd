# EventForge - a class written inside a script (GDScript-backed sheets).
#
#	class Hit:
#		var amount: int = 1
#
#		func is_critical() -> bool:
#			return amount > 10
#
# reads as one "Class Hit" head with its members under it. The members are not kept as text: the
# body, one tab shallower, is opened as a sheet of its own, so its variables are variable rows and
# its functions are function events, read by exactly the reader that reads the file around it.
#
# Created only by the inner class lift, and only when writing the body back - every line one tab
# deeper again, under the header kept verbatim - reproduces the class byte for byte. A class that
# cannot come back exactly stays the code it was, on its own, and the rest of the file still reads.
#
# Every field is @export because sheet snapshots duplicate resources, and duplicate() copies
# exported properties only.
@tool
class_name InnerClassRow
extends Resource

## Where the body's emission is pointed while it is written, so the compiler takes the path that keeps
## a file's own order. Never written to: a class's body is only ever echoed.
const BODY_PATH: String = "user://eventforge_inner_class.gd"

## The `class Name[ extends Base]:` line, verbatim.
@export var header: String = ""
## The class body, one tab shallower, opened as a sheet. Its rows emit one tab deeper again.
@export var body: EventSheetResource = null


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "inner_class"


## The class name the header declares ("" when the header is not a class line).
func inner_class_name() -> String:
	var found: RegExMatch = RegEx.create_from_string("^class ([A-Za-z_][A-Za-z0-9_]*)").search(header)
	return found.get_string(1) if found != null else ""


## The base class the header names after `extends` ("" when it names none).
func base_class() -> String:
	var found: RegExMatch = RegEx.create_from_string(" extends ([A-Za-z_][A-Za-z0-9_.]*)").search(header)
	return found.get_string(1) if found != null else ""


## The class's lines as the file holds them, from the body's own emission: the header, then every
## body line one tab deeper (an empty line stays empty).
static func indent_body(header_line: String, body_text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([header_line])
	var body_lines: PackedStringArray = body_text.split("\n")
	# The body's emission ends on its final newline, which is not a line of the class.
	if not body_lines.is_empty() and body_lines[body_lines.size() - 1].is_empty():
		body_lines.remove_at(body_lines.size() - 1)
	for line: String in body_lines:
		out.append("" if line.is_empty() else "\t" + line)
	return out
