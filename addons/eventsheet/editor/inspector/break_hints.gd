# Godot EventSheets - where a long line of code may be broken when it is drawn.
#
# A label breaks a line at its spaces, and inside one word only when that word alone is wider than the
# label: a quoted hint such as "eventsheet:table:item=String,count=int" has no space, so it was cut in the
# middle of "String" ("Stri" / "ng"). A zero-width space after a comma, an opening bracket, a colon or an
# equals sign is a place the line may break and shows nothing. The text a window READS stays the true line;
# only the copy it draws gets these. Loaded by path by the Variable window, so the editor's first open
# compiles none of it.
@tool
extends RefCounted

## The code point of the zero-width space.
const ZERO_WIDTH_SPACE: int = 0x200B


## `code` with a break point after every comma, opening bracket, colon and equals sign that is not already
## followed by a space (so `var hp: int = 1` is untouched and `item=String,count=int` may break at each).
static func after_separators(code: String) -> String:
	var separators: RegEx = RegEx.create_from_string("([,(\\[{:=])(?=\\S)")
	return separators.sub(code, "$1" + String.chr(ZERO_WIDTH_SPACE), true)
