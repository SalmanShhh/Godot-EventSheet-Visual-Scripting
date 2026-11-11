# Godot EventSheets - what kind of array a row's list field names.
#
# The stack and queue rows (Pop back into, Move back to, Swap, For each popped) take their lists from
# the Array variable dropdown, and three things about them depend on the array's DECLARED type:
#
#   - a pop into a local writes `var last: Vector2i = ...` when the list is an `Array[Vector2i]`, so the
#     type check and autocomplete know what `last` is. An untyped Array gives an untyped local;
#   - a swap of two typed arrays whose element types differ is refused in the parameters window, with
#     one line naming both types, because a typed array only ever holds its own type;
#   - the dropdown itself offers another object's arrays as well as the sheet's own.
#
# This reads the declaration the way the rest of the editor does - the sheet's variables, its local
# variables, and for another object the script that object wears (EventSheetScriptMembers) - and
# nothing is ever instantiated. Pure and static, so every answer is pinned without a dialog.
@tool
class_name EventSheetArrayTypes
extends RefCounted


## The declared type of the list `list_expression` names, e.g. "Array[Vector2i]", "Array", or "" when
## nothing declares one (a name the sheet does not know, or a variable with no type).
static func declared_type(sheet: EventSheetResource, list_expression: String) -> String:
	var text: String = list_expression.strip_edges()
	if sheet == null or text.is_empty():
		return ""
	if sheet.variables.has(text):
		return str((sheet.variables[text] as Dictionary).get("type", "")).strip_edges()
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == text:
			return str((entry as LocalVariable).type_name).strip_edges()
	for other: Dictionary in EventSheetScriptMembers.other_arrays(sheet):
		if str(other.get("expression", "")) == text:
			return str(other.get("type", "")).strip_edges()
	return ""


## The element type inside an array type: "Vector2i" for "Array[Vector2i]", "" for a plain "Array".
static func element_type(declared: String) -> String:
	var text: String = declared.strip_edges()
	if not (text.begins_with("Array[") and text.ends_with("]")):
		return ""
	return text.substr(6, text.length() - 7).strip_edges()


## The element type of the list a row names, "" when the list is untyped or unknown.
static func list_element_type(sheet: EventSheetResource, list_expression: String) -> String:
	return element_type(declared_type(sheet, list_expression))


## The one line a Swap row is refused with, or "" when the two lists may trade places. Only two TYPED
## arrays of different element types are refused: either side untyped is the plain Array every other
## row already takes.
static func swap_problem(sheet: EventSheetResource, first: String, second: String) -> String:
	var first_type: String = element_type(declared_type(sheet, first))
	var second_type: String = element_type(declared_type(sheet, second))
	if first_type.is_empty() or second_type.is_empty() or first_type == second_type:
		return ""
	return EventSheetL10n.translate("%s is Array[%s] and %s is Array[%s], and a typed array only holds its own type.") % [
		first.strip_edges(), first_type, second.strip_edges(), second_type]
