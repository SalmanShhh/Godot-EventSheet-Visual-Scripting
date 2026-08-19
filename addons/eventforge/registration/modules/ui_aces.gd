# EventForge module - UI / menu vocabulary (Control / BaseButton / Range / LineEdit)
#
# The first-class menu/HUD surface: Button On Pressed / On Toggled triggers (connected via
# the OnButtonPressed/OnButtonToggled arms in trigger_resolver.gd), focus navigation, and
# Range/LineEdit get-set. Lane-1 wraps of native Control nodes, single-line per the parity
# contract. Module contract: see ace_factory.gd - ace_ids/templates are API (covenant).
@tool
class_name EventForgeUIACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Triggers (signal-backed; trigger_resolver.gd connects "pressed"/"toggled") ──
	descriptors.append(F.make_descriptor("Core", "OnButtonPressed", "On Pressed", ACEDescriptor.ACEType.TRIGGER, "", "pressed", [], "Signals / Scene / Input", "On pressed", "BaseButton")
		.described("Runs when the player clicks or activates this button."))
	descriptors.append(F.make_descriptor("Core", "OnButtonToggled", "On Toggled", ACEDescriptor.ACEType.TRIGGER, "", "toggled", [F.make_param("toggled_on", "bool", "false", "Toggled On", "True when the button is now pressed.")], "Signals / Scene / Input", "On toggled {toggled_on}", "BaseButton")
		.described("Runs when a toggle button is switched on or off."))

	# ── Focus navigation (Control) ──
	descriptors.append(F.make_descriptor("Core", "GrabFocus", "Set Focus", ACEDescriptor.ACEType.ACTION, "grab_focus()", "", [], "UI", "Set focus", "Control")
		.described("Gives this control keyboard focus, so input goes to it next."))
	descriptors.append(F.make_descriptor("Core", "ReleaseFocus", "Release Focus", ACEDescriptor.ACEType.ACTION, "release_focus()", "", [], "UI", "Release focus", "Control")
		.described("Removes keyboard focus from this control."))
	descriptors.append(F.make_descriptor("Core", "FocusNext", "Focus Next", ACEDescriptor.ACEType.ACTION, "var __n_{uid} = find_next_valid_focus()\nif __n_{uid}: __n_{uid}.grab_focus()", "", [], "UI", "Focus next control", "Control")
		.described("Moves keyboard focus to the next control in tab order."))
	descriptors.append(F.make_descriptor("Core", "FocusPrevious", "Focus Previous", ACEDescriptor.ACEType.ACTION, "var __p_{uid} = find_prev_valid_focus()\nif __p_{uid}: __p_{uid}.grab_focus()", "", [], "UI", "Focus previous control", "Control")
		.described("Moves keyboard focus to the previous control in tab order."))
	descriptors.append(F.make_descriptor("Core", "SetFocusNeighbor", "Set Focus Neighbor", ACEDescriptor.ACEType.ACTION, "set_focus_neighbor({side}, {target})", "", [F.make_param("side", "String", "SIDE_RIGHT", "Side", "Which neighbor to set.", "", ["SIDE_LEFT", "SIDE_TOP", "SIDE_RIGHT", "SIDE_BOTTOM"]), F.make_param("target", "String", "^\"../Sibling\"", "Target", "NodePath of the neighbor control.", "expression")], "UI", "Set [b]{side}[/b] focus neighbor to [i]{target}[/i]", "Control")
		.described("Sets which control gets focus when arrowing in a given direction."))
	descriptors.append(F.make_descriptor("Core", "HasFocus", "Has Focus", ACEDescriptor.ACEType.CONDITION, "has_focus()", "", [], "UI", "Has focus", "Control")
		.described("True when this control currently holds keyboard focus."))
	descriptors.append(F.make_descriptor("Core", "SetAnchorsPreset", "Set Anchors Preset", ACEDescriptor.ACEType.ACTION, "set_anchors_and_offsets_preset({preset})", "", [F.make_param("preset", "String", "Control.PRESET_FULL_RECT", "Preset", "Layout preset.", "", ["Control.PRESET_FULL_RECT", "Control.PRESET_CENTER", "Control.PRESET_TOP_LEFT", "Control.PRESET_TOP_RIGHT", "Control.PRESET_BOTTOM_LEFT", "Control.PRESET_BOTTOM_RIGHT", "Control.PRESET_CENTER_TOP", "Control.PRESET_CENTER_BOTTOM", "Control.PRESET_LEFT_WIDE", "Control.PRESET_RIGHT_WIDE", "Control.PRESET_TOP_WIDE", "Control.PRESET_BOTTOM_WIDE"])], "UI", "Set anchors preset {preset}", "Control")
		.described("Snaps a control's anchors to a layout preset like full-rect or center."))
	descriptors.append(F.make_descriptor("Core", "SetThemeColorOverride", "Override Theme Color", ACEDescriptor.ACEType.ACTION, "add_theme_color_override({name}, {color})", "", [F.make_param("name", "String", "&\"font_color\"", "Name", "Theme color slot (e.g. font_color, font_outline_color).", "expression"), F.make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "New color.", "color")], "UI", "Override theme color {name} = {color}", "Control")
		.described("Overrides one theme color on this control, like its font color."))

	# ── BaseButton (Button / CheckBox / TextureButton …) ──
	descriptors.append(F.make_descriptor("Core", "IsButtonPressed", "Is Button Pressed", ACEDescriptor.ACEType.CONDITION, "button_pressed", "", [], "UI", "Is button pressed", "BaseButton")
		.described("True while this button is currently pressed or toggled on."))
	descriptors.append(F.make_descriptor("Core", "IsButtonDisabled", "Is Button Disabled", ACEDescriptor.ACEType.CONDITION, "disabled", "", [], "UI", "Is button disabled", "BaseButton")
		.described("True when this button is disabled and can't be clicked."))
	descriptors.append(F.make_descriptor("Core", "SetButtonDisabled", "Set Button Disabled", ACEDescriptor.ACEType.ACTION, "disabled = {disabled}", "", [F.make_param("disabled", "String", "true", "Disabled", "Disable the button?", "", ["true", "false"])], "UI", "Set button disabled {disabled}", "BaseButton")
		.described("Enables or disables a button so it can or can't be clicked."))
	descriptors.append(F.make_descriptor("Core", "SetButtonPressedState", "Set Button Pressed", ACEDescriptor.ACEType.ACTION, "set_pressed_no_signal({pressed})", "", [F.make_param("pressed", "String", "true", "Pressed", "Pressed state (does not emit toggled).", "", ["true", "false"])], "UI", "Set button pressed {pressed}", "BaseButton")
		.described("Sets a toggle button's pressed state without firing its toggled event."))
	descriptors.append(F.make_descriptor("Core", "GetButtonText", "Button Text", ACEDescriptor.ACEType.EXPRESSION, "text", "", [], "UI", "button text", "Button")
		.described("Returns the label text currently shown on the button."))

	# ── Range (ProgressBar / Slider / SpinBox) - HUD bars + sliders ──
	descriptors.append(F.make_descriptor("Core", "SetRangeValue", "Set Slider Value", ACEDescriptor.ACEType.ACTION, "value = {value}", "", [F.make_param("value", "String", "0", "Value", "New value.", "expression")], "UI", "Set value to {value}", "Range")
		.described("Sets a slider, progress bar, or spinbox to a specific value."))
	descriptors.append(F.make_descriptor("Core", "SetRangeMax", "Set Max Value", ACEDescriptor.ACEType.ACTION, "max_value = {max}", "", [F.make_param("max", "String", "100", "Max", "Maximum value.", "expression")], "UI", "Set max value to {max}", "Range")
		.described("Sets the maximum value of a slider, progress bar, or spinbox."))
	descriptors.append(F.make_descriptor("Core", "GetRangeValue", "Value", ACEDescriptor.ACEType.EXPRESSION, "value", "", [], "UI", "value", "Range")
		.described("Returns the current value of a slider, progress bar, or spinbox."))
	descriptors.append(F.make_descriptor("Core", "GetRangeRatio", "Value Ratio", ACEDescriptor.ACEType.EXPRESSION, "ratio", "", [], "UI", "value ratio (0..1)", "Range")
		.described("Returns the value as a 0-to-1 ratio, handy for filling bars."))

	# ── LineEdit ──
	descriptors.append(F.make_descriptor("Core", "SetLineEditText", "Set Field Text", ACEDescriptor.ACEType.ACTION, "text = str({value})", "", [F.make_param("value", "String", "\"\"", "Text", "Text to set.", "expression")], "UI", "Set field text to {value}", "LineEdit")
		.described("Sets the text shown in a single-line text field."))
	descriptors.append(F.make_descriptor("Core", "ClearLineEdit", "Clear Field", ACEDescriptor.ACEType.ACTION, "clear()", "", [], "UI", "Clear field", "LineEdit")
		.described("Empties a single-line text field of all its text."))
	descriptors.append(F.make_descriptor("Core", "GetLineEditText", "Field Text", ACEDescriptor.ACEType.EXPRESSION, "text", "", [], "UI", "field text", "LineEdit")
		.described("Returns whatever text the player has typed into the field."))

	# S12 - the UI shapes an opened script already READS as these words: a bar filled to a value out
	# of a maximum, a centred dialog, and the mixer's master volume as the 0-to-1 a slider gives.
	descriptors.append(F.make_descriptor("Core", "SetProgress", "Set Progress", ACEDescriptor.ACEType.ACTION, "value = {value}
max_value = {max}", "", [F.make_param("value", "String", "0", "Value", "How full the bar is.", "expression"), F.make_param("max", "String", "100", "Of", "The full amount.", "expression")], "UI", "Set progress to {value} of {max}", "Range")
		.described("Fills a progress bar to a value out of a maximum, both in one row."))
	descriptors.append(F.make_descriptor("Core", "ShowDialogCentred", "Show Dialog", ACEDescriptor.ACEType.ACTION, "popup_centered()", "", [], "UI", "Show dialog (centred)", "Window")
		.described("Opens this dialog in the middle of the screen."))
	descriptors.append(F.make_descriptor("Core", "SetMasterVolume", "Set Master Volume", ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_volume_db(0, linear_to_db({level}))", "", [F.make_param("level", "String", "0.5", "Level", "0 = silent, 1 = full - the number a volume slider gives.", "expression")], "UI", "Set master volume to {level} (0 to 1)")
		.described("Sets the overall game volume from a 0-to-1 slider value."))

	# ── V2 - the object words a form has: Text input, List, Check box, File chooser, Tabs ──
	# Every template below writes exactly the line the opened-script reading recognises, so a picked
	# row and a hand-written one are the same bytes and read the same sentence.
	descriptors.append(F.make_descriptor("Core", "SetTextInputPlaceholder", "Set Placeholder", ACEDescriptor.ACEType.ACTION, "placeholder_text = {value}", "", [F.make_param("value", "String", "\"\"", "Placeholder", "The grey hint shown while the field is empty.", "expression")], "UI", "Set placeholder to {value}", "LineEdit")
		.described("Sets the grey hint text shown in an empty text field."))
	descriptors.append(F.make_descriptor("Core", "ListAddItem", "Add Item", ACEDescriptor.ACEType.ACTION, "add_item({value})", "", [F.make_param("value", "String", "\"Item\"", "Item", "The text of the new entry.", "expression")], "UI", "Add item {value}", "ItemList")
		.described("Adds one entry to the end of a list."))
	descriptors.append(F.make_descriptor("Core", "ListRemoveItem", "Remove Item", ACEDescriptor.ACEType.ACTION, "remove_item({index})", "", [F.make_param("index", "String", "0", "Index", "Which entry to remove, counting from 0.", "expression")], "UI", "Remove item {index}", "ItemList")
		.described("Removes one entry from a list by its position."))
	descriptors.append(F.make_descriptor("Core", "ListSelectItem", "Select Item", ACEDescriptor.ACEType.ACTION, "select({index})", "", [F.make_param("index", "String", "0", "Index", "Which entry to highlight, counting from 0.", "expression")], "UI", "Select item {index}", "ItemList")
		.described("Highlights one entry of a list as the chosen one."))
	descriptors.append(F.make_descriptor("Core", "ListClear", "Clear List", ACEDescriptor.ACEType.ACTION, "clear()", "", [], "UI", "Clear", "ItemList")
		.described("Empties a list of every entry."))
	descriptors.append(F.make_descriptor("Core", "ListItemText", "Item Text", ACEDescriptor.ACEType.EXPRESSION, "get_item_text({index})", "", [F.make_param("index", "String", "0", "Index", "Which entry to read, counting from 0.", "expression")], "UI", "item text {index}", "ItemList")
		.described("Returns the text of one entry of a list."))
	descriptors.append(F.make_descriptor("Core", "CheckBoxIsChecked", "Is Checked", ACEDescriptor.ACEType.CONDITION, "button_pressed", "", [], "UI", "Is checked", "CheckBox")
		.described("True while a check box is ticked."))
	descriptors.append(F.make_descriptor("Core", "CheckBoxSetChecked", "Set Checked", ACEDescriptor.ACEType.ACTION, "button_pressed = {checked}", "", [F.make_param("checked", "String", "true", "Checked", "Tick the box?", "", ["true", "false"])], "UI", "Set checked {checked}", "CheckBox")
		.described("Ticks or unticks a check box."))
	descriptors.append(F.make_descriptor("Core", "OpenFileChooser", "Open File Chooser", ACEDescriptor.ACEType.ACTION, "popup_centered()", "", [], "UI", "Open", "FileDialog")
		.described("Opens a file chooser in the middle of the screen."))
	descriptors.append(F.make_descriptor("Core", "SwitchToTab", "Switch To Tab", ACEDescriptor.ACEType.ACTION, "current_tab = {index}", "", [F.make_param("index", "String", "0", "Tab", "Which tab to show, counting from 0.", "expression")], "UI", "Switch to tab {index}", "TabContainer")
		.described("Shows one tab of a tabbed panel."))
	descriptors.append(F.make_descriptor("Core", "SetFormattedText", "Set Formatted Text", ACEDescriptor.ACEType.ACTION, "text = {value}", "", [F.make_param("value", "String", "\"\"", "Text", "Text with [b]tags[/b] in it.", "expression")], "UI", "Set formatted text to {value}", "RichTextLabel")
		.described("Replaces a rich text label's contents, tags and all."))
	descriptors.append(F.make_descriptor("Core", "AppendFormattedText", "Append Formatted Text", ACEDescriptor.ACEType.ACTION, "append_text({value})", "", [F.make_param("value", "String", "\"\"", "Text", "Text with [b]tags[/b] in it.", "expression")], "UI", "Append formatted text {value}", "RichTextLabel")
		.described("Adds text to the end of a rich text label without clearing it."))
	descriptors.append(F.make_descriptor("Core", "SetTooltip", "Set Tooltip", ACEDescriptor.ACEType.ACTION, "tooltip_text = {value}", "", [F.make_param("value", "String", "\"\"", "Tooltip", "What the pointer shows when it rests here.", "expression")], "UI", "Set tooltip to {value}", "Control")
		.described("Sets the little label the pointer shows when it rests on this control."))

	return descriptors
