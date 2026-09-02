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
	descriptors.append(F.trig("OnButtonPressed", "On Pressed", "pressed", "Signals / Scene / Input", "On pressed", "Runs when the player clicks or activates this button.", "BaseButton"))
	descriptors.append(F.trig("OnButtonToggled", "On Toggled", "toggled", "Signals / Scene / Input", "On toggled {toggled_on}", "Runs when a toggle button is switched on or off.", "BaseButton").param_typed("bool", "toggled_on", "false", "Toggled On", "True when the button is now pressed."))

	# ── Focus navigation (Control) ──
	descriptors.append(F.act("GrabFocus", "Set Focus", "grab_focus()", "UI", "Set focus", "Gives this control keyboard focus, so input goes to it next.", "Control"))
	descriptors.append(F.act("ReleaseFocus", "Release Focus", "release_focus()", "UI", "Release focus", "Removes keyboard focus from this control.", "Control"))
	descriptors.append(F.act("FocusNext", "Focus Next", "var __n_{uid} = find_next_valid_focus()\nif __n_{uid}: __n_{uid}.grab_focus()", "UI", "Focus next control", "Moves keyboard focus to the next control in tab order.", "Control"))
	descriptors.append(F.act("FocusPrevious", "Focus Previous", "var __p_{uid} = find_prev_valid_focus()\nif __p_{uid}: __p_{uid}.grab_focus()", "UI", "Focus previous control", "Moves keyboard focus to the previous control in tab order.", "Control"))
	descriptors.append(F.act("SetFocusNeighbor", "Set Focus Neighbor", "set_focus_neighbor({side}, {target})", "UI", "Set [b]{side}[/b] focus neighbor to [i]{target}[/i]", "Sets which control gets focus when arrowing in a given direction.", "Control").param_choice("side", "SIDE_RIGHT", "Side", "Which neighbor to set.", ["SIDE_LEFT", "SIDE_TOP", "SIDE_RIGHT", "SIDE_BOTTOM"]).param("target", "^\"../Sibling\"", "Target", "NodePath of the neighbor control.", "expression"))
	descriptors.append(F.cond("HasFocus", "Has Focus", "has_focus()", "UI", "Has focus", "True when this control currently holds keyboard focus.", "Control"))
	descriptors.append(F.act("SetAnchorsPreset", "Set Anchors Preset", "set_anchors_and_offsets_preset({preset})", "UI", "Set anchors preset {preset}", "Snaps a control's anchors to a layout preset like full-rect or center.", "Control").param_choice("preset", "Control.PRESET_FULL_RECT", "Preset", "Layout preset.", ["Control.PRESET_FULL_RECT", "Control.PRESET_CENTER", "Control.PRESET_TOP_LEFT", "Control.PRESET_TOP_RIGHT", "Control.PRESET_BOTTOM_LEFT", "Control.PRESET_BOTTOM_RIGHT", "Control.PRESET_CENTER_TOP", "Control.PRESET_CENTER_BOTTOM", "Control.PRESET_LEFT_WIDE", "Control.PRESET_RIGHT_WIDE", "Control.PRESET_TOP_WIDE", "Control.PRESET_BOTTOM_WIDE"]))
	descriptors.append(F.act("SetThemeColorOverride", "Override Theme Color", "add_theme_color_override({name}, {color})", "UI", "Override theme color {name} = {color}", "Overrides one theme color on this control, like its font color.", "Control").param("name", "&\"font_color\"", "Name", "Theme color slot (e.g. font_color, font_outline_color).", "expression").param("color", "Color(1, 1, 1, 1)", "Color", "New color.", "color"))

	# ── BaseButton (Button / CheckBox / TextureButton …) ──
	descriptors.append(F.cond("IsButtonPressed", "Is Button Pressed", "button_pressed", "UI", "Is button pressed", "True while this button is currently pressed or toggled on.", "BaseButton"))
	descriptors.append(F.cond("IsButtonDisabled", "Is Button Disabled", "disabled", "UI", "Is button disabled", "True when this button is disabled and can't be clicked.", "BaseButton"))
	descriptors.append(F.act("SetButtonDisabled", "Set Button Disabled", "disabled = {disabled}", "UI", "Set button disabled {disabled}", "Enables or disables a button so it can or can't be clicked.", "BaseButton").param_choice("disabled", "true", "Disabled", "Disable the button?", ["true", "false"]))
	descriptors.append(F.act("SetButtonPressedState", "Set Button Pressed", "set_pressed_no_signal({pressed})", "UI", "Set button pressed {pressed}", "Sets a toggle button's pressed state without firing its toggled event.", "BaseButton").param_choice("pressed", "true", "Pressed", "Pressed state (does not emit toggled).", ["true", "false"]))
	descriptors.append(F.expr("GetButtonText", "Button Text", "text", "UI", "button text", "Returns the label text currently shown on the button.", "Button"))

	# ── Range (ProgressBar / Slider / SpinBox) - HUD bars + sliders ──
	descriptors.append(F.act("SetRangeValue", "Set Slider Value", "value = {value}", "UI", "Set value to {value}", "Sets a slider, progress bar, or spinbox to a specific value.", "Range").param("value", "0", "Value", "New value.", "expression"))
	descriptors.append(F.act("SetRangeMax", "Set Max Value", "max_value = {max}", "UI", "Set max value to {max}", "Sets the maximum value of a slider, progress bar, or spinbox.", "Range").param("max", "100", "Max", "Maximum value.", "expression"))
	descriptors.append(F.expr("GetRangeValue", "Value", "value", "UI", "value", "Returns the current value of a slider, progress bar, or spinbox.", "Range"))
	descriptors.append(F.expr("GetRangeRatio", "Value Ratio", "ratio", "UI", "value ratio (0..1)", "Returns the value as a 0-to-1 ratio, handy for filling bars.", "Range"))

	# ── LineEdit ──
	descriptors.append(F.act("SetLineEditText", "Set Field Text", "text = str({value})", "UI", "Set field text to {value}", "Sets the text shown in a single-line text field.", "LineEdit").param("value", "\"\"", "Text", "Text to set.", "expression"))
	descriptors.append(F.act("ClearLineEdit", "Clear Field", "clear()", "UI", "Clear field", "Empties a single-line text field of all its text.", "LineEdit"))
	descriptors.append(F.expr("GetLineEditText", "Field Text", "text", "UI", "field text", "Returns whatever text the player has typed into the field.", "LineEdit"))

	# The UI shapes an opened script already READS as these words: a bar filled to a value out
	# of a maximum, a centred dialog, and the mixer's master volume as the 0-to-1 a slider gives.
	descriptors.append(F.make_descriptor("Core", "SetProgress", "Set Progress", ACEDescriptor.ACEType.ACTION, "value = {value}
max_value = {max}", "", [F.make_param("value", "String", "0", "Value", "How full the bar is.", "expression"), F.make_param("max", "String", "100", "Of", "The full amount.", "expression")], "UI", "Set progress to {value} of {max}", "Range")
		.described("Fills a progress bar to a value out of a maximum, both in one row."))
	descriptors.append(F.act("ShowDialogCentred", "Show Dialog", "popup_centered()", "UI", "Show dialog (centred)", "Opens this dialog in the middle of the screen.", "Window"))
	descriptors.append(F.act("SetMasterVolume", "Set Master Volume", "AudioServer.set_bus_volume_db(0, linear_to_db({level}))", "UI", "Set master volume to {level} (0 to 1)", "Sets the overall game volume from a 0-to-1 slider value.").param("level", "0.5", "Level", "0 = silent, 1 = full - the number a volume slider gives.", "expression"))

	# ── the object words a form has: Text input, List, Check box, File chooser, Tabs ───────
	# Every template below writes exactly the line the opened-script reading recognises, so a picked
	# row and a hand-written one are the same bytes and read the same sentence.
	descriptors.append(F.act("SetTextInputPlaceholder", "Set Placeholder", "placeholder_text = {value}", "UI", "Set placeholder to {value}", "Sets the grey hint text shown in an empty text field.", "LineEdit").param("value", "\"\"", "Placeholder", "The grey hint shown while the field is empty.", "expression"))
	descriptors.append(F.act("ListAddItem", "Add Item", "add_item({value})", "UI", "Add item {value}", "Adds one entry to the end of a list.", "ItemList").param("value", "\"Item\"", "Item", "The text of the new entry.", "expression"))
	descriptors.append(F.act("ListRemoveItem", "Remove Item", "remove_item({index})", "UI", "Remove item {index}", "Removes one entry from a list by its position.", "ItemList").param("index", "0", "Index", "Which entry to remove, counting from 0.", "expression"))
	descriptors.append(F.act("ListSelectItem", "Select Item", "select({index})", "UI", "Select item {index}", "Highlights one entry of a list as the chosen one.", "ItemList").param("index", "0", "Index", "Which entry to highlight, counting from 0.", "expression"))
	descriptors.append(F.act("ListClear", "Clear List", "clear()", "UI", "Clear", "Empties a list of every entry.", "ItemList"))
	descriptors.append(F.expr("ListItemText", "Item Text", "get_item_text({index})", "UI", "item text {index}", "Returns the text of one entry of a list.", "ItemList").param("index", "0", "Index", "Which entry to read, counting from 0.", "expression"))
	descriptors.append(F.cond("CheckBoxIsChecked", "Is Checked", "button_pressed", "UI", "Is checked", "True while a check box is ticked.", "CheckBox"))
	descriptors.append(F.act("CheckBoxSetChecked", "Set Checked", "button_pressed = {checked}", "UI", "Set checked {checked}", "Ticks or unticks a check box.", "CheckBox").param_choice("checked", "true", "Checked", "Tick the box?", ["true", "false"]))
	descriptors.append(F.act("OpenFileChooser", "Open File Chooser", "popup_centered()", "UI", "Open", "Opens a file chooser in the middle of the screen.", "FileDialog"))
	descriptors.append(F.act("SwitchToTab", "Switch To Tab", "current_tab = {index}", "UI", "Switch to tab {index}", "Shows one tab of a tabbed panel.", "TabContainer").param("index", "0", "Tab", "Which tab to show, counting from 0.", "expression"))
	# Setting a rich label's whole text is DELIBERATELY not a row of its own: `text = {value}` is the
	# same line as any other property write, so a row for it would shadow Set Property in the
	# reverse-lift and make every `x.text = …` in the project read as a rich label. The reading
	# still says "Set formatted text" when the object IS a RichTextLabel, and Set Property authors
	# the same bytes.
	descriptors.append(F.act("AppendFormattedText", "Append Formatted Text", "append_text({value})", "UI", "Append formatted text {value}", "Adds text to the end of a rich text label without clearing it.", "RichTextLabel").param("value", "\"\"", "Text", "Text with [b]tags[/b] in it.", "expression"))
	descriptors.append(F.act("SetTooltip", "Set Tooltip", "tooltip_text = {value}", "UI", "Set tooltip to {value}", "Sets the little label the pointer shows when it rests on this control.", "Control").param("value", "\"\"", "Tooltip", "What the pointer shows when it rests here.", "expression"))

	return descriptors
