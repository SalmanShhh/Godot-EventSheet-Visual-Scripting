# EventForge module — UI / menu vocabulary (Control / BaseButton / Range / LineEdit)
#
# The first-class menu/HUD surface: Button On Pressed / On Toggled triggers (connected via
# the OnButtonPressed/OnButtonToggled arms in trigger_resolver.gd), focus navigation, and
# Range/LineEdit get-set. Lane-1 wraps of native Control nodes, single-line per the parity
# contract. Module contract: see ace_factory.gd — ace_ids/templates are API (covenant).
@tool
extends RefCounted
class_name EventForgeUIACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Triggers (signal-backed; trigger_resolver.gd connects "pressed"/"toggled") ──
	descriptors.append(F.make_descriptor("Core", "OnButtonPressed", "On Pressed", ACEDescriptor.ACEType.TRIGGER, "", "pressed", [], "Signals / Scene / Input", "On pressed", "BaseButton")
		.described("Runs when the player clicks or activates this button."))
	descriptors.append(F.make_descriptor("Core", "OnButtonToggled", "On Toggled", ACEDescriptor.ACEType.TRIGGER, "", "toggled", [F.make_param("toggled_on", "bool", "false", "Toggled On", "True when the button is now pressed.")], "Signals / Scene / Input", "On toggled {toggled_on}", "BaseButton")
		.described("Runs when a toggle button is switched on or off."))

	# ── Focus navigation (Control) ──
	descriptors.append(F.make_descriptor("Core", "GrabFocus", "Grab Focus", ACEDescriptor.ACEType.ACTION, "grab_focus()", "", [], "UI", "Grab focus", "Control")
		.described("Gives this control keyboard focus, so input goes to it next."))
	descriptors.append(F.make_descriptor("Core", "ReleaseFocus", "Release Focus", ACEDescriptor.ACEType.ACTION, "release_focus()", "", [], "UI", "Release focus", "Control")
		.described("Removes keyboard focus from this control."))
	descriptors.append(F.make_descriptor("Core", "FocusNext", "Focus Next", ACEDescriptor.ACEType.ACTION, "var __n_{uid} = find_next_valid_focus()\nif __n_{uid}: __n_{uid}.grab_focus()", "", [], "UI", "Focus next control", "Control")
		.described("Moves keyboard focus to the next control in tab order."))
	descriptors.append(F.make_descriptor("Core", "FocusPrevious", "Focus Previous", ACEDescriptor.ACEType.ACTION, "var __p_{uid} = find_prev_valid_focus()\nif __p_{uid}: __p_{uid}.grab_focus()", "", [], "UI", "Focus previous control", "Control")
		.described("Moves keyboard focus to the previous control in tab order."))
	descriptors.append(F.make_descriptor("Core", "SetFocusNeighbor", "Set Focus Neighbor", ACEDescriptor.ACEType.ACTION, "set_focus_neighbor({side}, {target})", "", [F.make_param("side", "String", "SIDE_RIGHT", "Side", "Which neighbor to set.", "", ["SIDE_LEFT", "SIDE_TOP", "SIDE_RIGHT", "SIDE_BOTTOM"]), F.make_param("target", "String", "^\"../Sibling\"", "Target", "NodePath of the neighbor control.", "expression")], "UI", "Set {side} focus neighbor to {target}", "Control")
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

	# ── Range (ProgressBar / Slider / SpinBox) — HUD bars + sliders ──
	descriptors.append(F.make_descriptor("Core", "SetRangeValue", "Set Value", ACEDescriptor.ACEType.ACTION, "value = {value}", "", [F.make_param("value", "String", "0", "Value", "New value.", "expression")], "UI", "Set value to {value}", "Range")
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

	return descriptors
