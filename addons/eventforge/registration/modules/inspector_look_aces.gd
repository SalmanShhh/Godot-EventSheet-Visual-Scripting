# EventForge module - the Inspector look (what a script that draws one property in Godot's Inspector does).
#
# A look is a script that extends EventSheetInspectorLook, a thin layer over Godot's EditorProperty. The
# Inspector calls three functions on it, and this module makes each one a trigger: the control is built
# (`_look_built`), a value is to be shown (`_value_shown`), and the value moved without the look
# (`_value_changed_from_outside`). Two actions and one expression are the look's own calls: write a new
# value, make a control the one keyboard focus lands on, read the value now.
#
# Every row compiles to the plain function or call it names, so a look written by hand opens as these
# rows and saves back byte for byte. The picker offers them on a sheet whose script extends
# EventSheetInspectorLook and on no other (see EventSheetPickerGates.IN_LOOK_SHEET).
@tool
class_name EventForgeInspectorLookACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The shelf these rows are filed on. They carry no host class on purpose: a host would make the actions
## retargetable ("On node"), and a look's calls are always its own. The picker gates them by this shelf.
const CAT := "Inspector Look"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.trig("OnLookBuilt", "On Look Built", "_look_built", CAT, "On look built",
		"Runs once, when Godot's Inspector first needs this look and builds it for a property. Make the controls here: add them as children, connect their signals. The questions you asked in the Variable window are already answered by now."))
	descriptors.append(F.trig("OnValueShown", "On Value Shown", "_value_shown", CAT, "On value shown",
		"Runs every time the Inspector refreshes the property: when it is first drawn, after the person edits it, after undo. The value to show arrives as `value`. Put it into the controls here, and never write a value back from here."))
	descriptors.append(F.trig("OnValueChangedFromOutside", "On Value Changed From Outside", "_value_changed_from_outside", CAT, "On value changed from outside",
		"Runs when the value moved without this look moving it: undo, a script, another editor. It runs just before On Value Shown, with the new value as `value`."))
	descriptors.append(F.act("SetFieldValue", "Set Field Value", "set_field_value({value})", CAT, "Set the field's value to {value}",
		"Writes a new value to the property this look draws. The Inspector keeps undo, so this is one undo step. Use it when the person changes something in your controls.")
		.param("value", "field_value()", "Value", "The new value for the property.", "expression"))
	descriptors.append(F.act("AddFocusable", "Make Control Take Focus", "add_focusable({control})", CAT, "Make {control} the one focus lands on",
		"Tells the Inspector that this control is where the keyboard focus goes when the person tabs to the property, or clicks its name.")
		.param("control", "self", "Control", "The control that takes the focus.", "expression"))
	descriptors.append(F.expr("FieldValue", "The Field's Value", "field_value()", CAT, "the field's value",
		"The value of the property this look draws, right now."))
	descriptors.append(F.expr("ThemedPanel", "A Themed Panel", "themed_panel()", CAT, "a themed panel",
		"A panel wearing the Inspector's own field colour, for a block that sits under the row. Add the things it holds as its children."))
	descriptors.append(F.expr("MessageLine", "A Message Line", "message_line({text})", CAT, "a line saying {text}",
		"A line of words in the Inspector's own font that wraps to the room it has. Put it under the field to say what the field means or what is wrong.")
		.param("text", "\"\"", "Text", "The words to show.", "expression"))
	descriptors.append(F.expr("NumberField", "A Number Field", "number_field({label})", CAT, "a number field labelled {label}",
		"Godot's own number field with its label inside it. Connect its value_changed signal, and set its value with set_value_no_signal when the Inspector shows a value.")
		.param("label", "\"\"", "Label", "The word shown inside the field, such as x or Reach.", "expression"))
	descriptors.append(F.expr("JoinedStrip", "A Joined Strip", "joined_strip({buttons})", CAT, "a joined strip of {buttons}",
		"Joins toggle buttons into one strip with no gaps, the pressed one filled with the accent. Give it an array of buttons you have made.")
		.param("buttons", "[]", "Buttons", "The buttons to join, in order.", "expression"))
	descriptors.append(F.act("AddUnderField", "Add Under The Field", "add_under_field({first_row}, {under})", CAT, "Put {under} under {first_row}",
		"Puts a wide part (a dial, a picture, a table) on a line of its own under the first row, in the value column, with the name staying level with the first row. This adds both controls, so do not add them yourself.")
		.param("first_row", "self", "First row", "The control that holds the first line of fields.", "expression")
		.param("under", "self", "Under it", "The wide part that sits below.", "expression"))
	return descriptors
