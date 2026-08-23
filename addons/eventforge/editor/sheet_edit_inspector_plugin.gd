# Godot EventSheets - the Inspector's "Edit Event Sheet" / "Instance variables" buttons
#
# Godot devs live in the Inspector: when the selected node's script is generated
# from a sheet (the pairing rule knows), one button jumps straight to the sheet -
# and quietly says "edit the sheet, not the script".
#
# V10 - beside it, "Instance variables · N", because that is where an event-sheet author looks for
# an object's variables: on the object. It opens the same table the sheet already has. Under both
# buttons, the one question the Inspector cannot answer on its own - which of this object's
# variables are NOT down there, and what makes one appear.
#
# The variable census is a LIGHT SCAN of the script's own text, not a sheet open: this plugin is
# registered at editor boot and a selection must not cost a compile. It reads member declarations
# the same way the autoload scan does, and being wrong about an exotic one costs a count, never a
# written line.
@tool
class_name EventSheetEditButtonPlugin
extends EditorInspectorPlugin

var open_sheet: Callable = Callable()  # Callable(sheet_path: String)
## V10. Callable(sheet_path: String) - opens the sheet AND its instance-variable table.
var open_variables: Callable = Callable()


func _can_handle(object: Object) -> bool:
	return not sheet_path_for(object).is_empty()


func _parse_begin(object: Object) -> void:
	var sheet_path: String = sheet_path_for(object)
	if sheet_path.is_empty():
		return
	var row: HBoxContainer = HBoxContainer.new()
	var button: Button = Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "Edit Event Sheet"
	button.tooltip_text = "%s is generated from %s - edit the sheet, not the script." % [
		(object.get_script() as Script).resource_path.get_file() if object.get_script() != null else "the script", sheet_path.get_file()]
	button.pressed.connect(func() -> void:
		if open_sheet.is_valid():
			open_sheet.call(sheet_path))
	row.add_child(button)
	var script_path: String = (object.get_script() as Script).resource_path if object.get_script() != null else ""
	var variables: Array[Dictionary] = member_variables(script_path)
	var variables_button: Button = Button.new()
	variables_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variables_button.text = "Instance variables · %d" % variables.size()
	variables_button.tooltip_text = "This object's own variables - name, type, initial value, and whether each is editable here."
	variables_button.pressed.connect(func() -> void:
		if open_variables.is_valid():
			open_variables.call(sheet_path)
		elif open_sheet.is_valid():
			open_sheet.call(sheet_path))
	row.add_child(variables_button)
	add_custom_control(row)
	var note: String = hidden_variables_note(variables)
	if not note.is_empty():
		var note_label: Label = Label.new()
		note_label.text = note
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
		add_custom_control(note_label)


## V10. The object's own member variables, read off its script: [{"name", "exported"}] in file order.
## `@export` (in any of its hinted spellings) on the line above is what puts a variable in the
## Inspector, which is exactly the fact the note below reports. Static + pure, so both are testable
## without an editor.
static func member_variables(script_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return found
	var pattern: RegEx = RegEx.new()
	pattern.compile("^(?:static )?var +([A-Za-z_][A-Za-z0-9_]*)")
	var exported_next: bool = false
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		# Members only: anything indented is inside a function and is nobody's property.
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var bare: String = line.strip_edges()
		# `@export var speed: float = 200.0` puts both facts on one line; `@export_range(0, 100)` on
		# its own line marks the NEXT one. Both spellings are the same declaration, so the annotation
		# is taken off the front and whatever is left is read as usual.
		if bare.begins_with("@export"):
			exported_next = true
			var space_at: int = bare.find(" ")
			if space_at < 0:
				continue
			bare = bare.substr(space_at + 1).strip_edges()
		var found_match: RegExMatch = pattern.search(bare)
		if found_match == null:
			if not bare.is_empty() and not bare.begins_with("#"):
				exported_next = false
			continue
		found.append({"name": found_match.get_string(1), "exported": exported_next})
		exported_next = false
	return found


## V10. The muted line under the buttons: the variables that exist but are not down here, and the one
## gesture that changes that. "" when every variable is already in the Inspector, and when there are
## none at all - a note about an empty list answers nothing.
static func hidden_variables_note(variables: Array[Dictionary]) -> String:
	var hidden: PackedStringArray = PackedStringArray()
	for entry: Dictionary in variables:
		if not bool(entry.get("exported", false)):
			hidden.append(str(entry.get("name", "")))
	if hidden.is_empty():
		return ""
	return "Not in the Inspector: %s - open the table to expose one." % ", ".join(hidden)

# _can_handle fires on every Inspector refresh; sheet_for_script reads files, so
# results are memoized by script path + mtime (review catch).
static var _pairing_cache: Dictionary = {}


## The sheet behind this object's attached script, or "" (which also means
## "don't handle").
static func sheet_path_for(object: Object) -> String:
	if not (object is Node):
		return ""
	var script: Script = (object as Node).get_script() as Script
	if script == null or script.resource_path.is_empty():
		return ""
	var script_path: String = script.resource_path
	var mtime: int = int(FileAccess.get_modified_time(script_path))
	var cached: Variant = _pairing_cache.get(script_path)
	if cached is Dictionary and int((cached as Dictionary).get("mtime")) == mtime:
		return str((cached as Dictionary).get("sheet"))
	# Loaded by path, not named as a class: this inspector plugin registers at editor boot, and
	# naming EventSheetProjectDoctor would compile its whole subtree (the compiler included)
	# right there. The first Inspector selection absorbs the one-time load instead.
	var sheet_path: String = load("res://addons/eventforge/project_doctor.gd").sheet_for_script(script_path)
	_pairing_cache[script_path] = {"mtime": mtime, "sheet": sheet_path}
	return sheet_path
