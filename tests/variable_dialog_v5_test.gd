# Godot EventSheets - V5 (the Add variable dialog), P4 (the one help strip) and K1 (the operator
# words), pinned where they are decided rather than where they are drawn.
#
# V5's claim is that the dialog asks for the row in the order the row is READ: the scope first (it
# is the row's first word), then the name, the type, the value. So the order of the fields is the
# test, along with what each scope does to the rest of the form - a Local can never be an Inspector
# property, a Constant is neither Static nor a property, a Global asks the one extra question of
# which autoload it lands on.
#
# P4's claim is that ONE strip at the foot says whatever is focused, and that its READS AS line is
# the row itself while its IN CODE line is the compiler's own emitted declaration - so the dialog
# can never promise a line the compiled sheet would not write.
@tool
class_name VariableDialogV5Test
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var host: Node = Node.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {"taken": {"type": "int", "default": 0}}
	var dialog: VariableDialog = VariableDialog.new()
	dialog.init_dialog(host)
	dialog.set_sheet_provider(func() -> EventSheetResource: return sheet)
	dialog.open_for_edit("global", {}, "hp", "int", "100", false, "Add variable")

	# ── The title says the gesture; the line under it says whose variable this will be ──
	ok = _check("the dialog is titled Add variable", dialog._dialog.title, "Add variable") and ok
	ok = _check("…and names the owner under it", dialog._owner_label.text, "to Player") and ok
	ok = _check("editing says so instead", _edit_title(dialog, sheet), "Edit variable") and ok

	# ── The field order V5 pins ──
	ok = _check("the fields read in the row's own order", Array(dialog.field_order()), [
		"Scope", "Write into", "Name", "Type", "Whole numbers only", "Initial value",
		"Options (combo)", "Description", "Flags", "On ready"
	]) and ok
	# ── No hint text sits under a checkbox: the strip is the one place that explains. The row holds
	# only checkboxes, and only the flags the scope in front of you can actually wear are on screen ──
	ok = _check("the Flags row carries checkboxes and nothing else",
		_flag_row_classes(dialog), ["CheckBox", "CheckBox", "CheckBox"]) and ok
	ok = _check("a member variable is offered Static and Constant",
		_visible_flags(dialog), ["Static", "Constant"]) and ok
	ok = _check("the Inspector checkbox lives behind More options",
		dialog._exported_check.get_parent().get_parent() == dialog._attr_section, true) and ok
	dialog.open_for_edit("global", {}, "hp", "int", "100", false, "Add variable")
	ok = _check("an instance variable is not asked which autoload it lands on",
		Array(dialog.field_order(true)).has("Write into"), false) and ok

	# ── Scope is a DROPDOWN, in the sheet's own order, one description line per choice ──
	ok = _check("the scopes are offered in SCOPE_ORDER", _scope_keys(dialog),
		Array(EventSheetVariableSentence.SCOPE_ORDER)) and ok
	ok = _check("Instance says what it means, naming the object",
		dialog._scope_option.get_item_tooltip(0), "one per Player - each copy in the scene has its own") and ok
	ok = _check("Static says what it means",
		dialog._scope_option.get_item_tooltip(4), "one value shared by every Player, kept between scenes") and ok

	# ── The type list: the three everybody needs, a divider, then the rest - stored types as
	# METADATA, so the words can read plainly while the .gd round-trip is unchanged ──
	ok = _check("the type list leads with the three plain kinds", _type_labels(dialog, 3),
		["Number", "Text", "Boolean"]) and ok
	ok = _check("Number stores a real Godot type", dialog._selected_stored_type(), "int") and ok
	ok = _check("Text is described with its GDScript spelling",
		VariableDialog.type_description("String"), "words in quotes, \"hello\" · String") and ok
	ok = _check("the GDScript spelling sits muted beside the field",
		(dialog._type_option.get_meta("code_note") as Label).text, "int") and ok
	dialog._whole_numbers_check.button_pressed = false
	dialog._refresh_type_code_note()
	ok = _check("…and follows the whole-numbers tick",
		(dialog._type_option.get_meta("code_note") as Label).text, "float") and ok
	dialog._whole_numbers_check.button_pressed = true

	# ── What each scope does to the rest of the form ──
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_LOCAL)
	ok = _check("a Local reads as a Local row", dialog.row_preview_text(), "Local whole number  hp = 100") and ok
	ok = _check("a Local can never be an Inspector property", dialog._exported_check.disabled, true) and ok
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_CONSTANT)
	ok = _check("a Constant greys Static", dialog._static_check.disabled, true) and ok
	ok = _check("…and the Inspector with it", dialog._exported_check.disabled, true) and ok
	ok = _check("a Constant emits const", dialog.code_line_text(), "const hp: int = 100") and ok
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_STATIC)
	ok = _check("Static in the dropdown ticks the Static flag", dialog._static_check.button_pressed, true) and ok
	ok = _check("a Static emits static var", dialog.code_line_text(), "static var hp: int = 100") and ok
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_GLOBAL)
	ok = _check("Global reveals the write-into picker", dialog._global_target_row.visible, true) and ok
	ok = _check("…and the picker always offers to make one",
		dialog._global_target_option.get_item_text(dialog._global_target_option.item_count - 1), "New global sheet…") and ok
	ok = _check("a Global reads as a Global row", dialog.row_preview_text(), "Global whole number  hp = 100") and ok

	# ── A clash is shown INLINE while you type, not on OK ──
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_INSTANCE)
	dialog._name_edit.text = "taken"
	dialog._refresh_name_warning()
	ok = _check("a name already taken here is flagged under the field", dialog._name_warning.visible, true) and ok
	ok = _check("…and says so plainly", dialog._name_warning.text,
		"⚠ \"taken\" is already a variable here - pick another name.") and ok
	dialog._name_edit.text = "hp"
	dialog._refresh_name_warning()
	ok = _check("a free name is not flagged", dialog._name_warning.visible, false) and ok
	ok = _check("the variable being edited never clashes with itself",
		_clash_while_editing(dialog, sheet), false) and ok

	# ── P4: the strip follows focus, and its two lines are the row and the line ──
	dialog.open_for_edit("global", {}, "hp", "int", "100", false, "Add variable")
	ok = _check("the strip opens on the scope", dialog._help_strip.heading_label.text, "SCOPE · INSTANCE") and ok
	ok = _check("READS AS is the row the sheet will show",
		dialog._help_strip.reads_as_value.text, "Instance whole number  hp = 100") and ok
	ok = _check("IN CODE is the line the compiler will write",
		dialog._help_strip.in_code_value.text, "@export var hp: int = 100") and ok
	dialog._name_edit.focus_entered.emit()
	ok = _check("focusing the name field swaps the strip", dialog._help_strip.heading_label.text, "NAME") and ok
	var typed: Dictionary = dialog._describe_type_index(1)
	ok = _check("a type describes itself before it is picked", str(typed.get("heading", "")), "Type · Text") and ok

	# ── "Initial value", not "Default"; the Inspector polish stays behind "More options" ──
	ok = _check("the value field is the Initial value",
		Array(dialog.field_order()).has("Initial value"), true) and ok
	ok = _check("the section names what is inside it",
		dialog._attr_toggle.text, "▾  More options (Inspector, range, drawer, group…)") and ok
	# An ALREADY-exported variable opens with the card unfurled: the Inspector tick lives inside it,
	# and a ticked box the reader cannot see would be a silent fact.
	ok = _check("an exported variable opens with it unfurled", dialog._attr_section_card.visible, true) and ok

	# ── V re-opens with the last scope; an edit never moves ──
	dialog._apply_scope_key(EventSheetVariableSentence.SCOPE_LOCAL)
	dialog.open("global")
	ok = _check("a fresh variable opens on the scope the last one used",
		dialog.current_scope_word(), EventSheetVariableSentence.SCOPE_LOCAL) and ok
	dialog.open_for_edit("global", {"editing": true, "original_name": "taken"}, "taken", "int", "0", false, "Edit Variable")
	ok = _check("editing opens on the variable's own scope",
		dialog.current_scope_word(), EventSheetVariableSentence.SCOPE_INSTANCE) and ok

	# ── K1: the operator list reads as the row reads, and keeps the token it inserts ──
	ok = _check("the operator labels lead with the symbol", _comparison_labels(), [
		"=  equal to", "≠  not equal to", "<  less than", "≤  at most", ">  greater than", "≥  at least"
	]) and ok
	ok = _check("the inserted tokens are untouched", _comparison_keys(),
		Array(EventForgeACEFactory.COMPARISON_OPERATORS)) and ok
	ok = _check("a params dialog shows the GDScript form muted", _params_operator_note(), "<=") and ok

	ok = _test_the_strip_is_the_only_explanation(dialog) and ok
	host.free()
	return ok


## P4/P3 - ONE strip, and nothing beside a field. Every verdict the dialog reaches - a literal that
## will not parse, a Constant the type cannot have, a locked type - is said THERE, in the strip's
## own red or amber, and taken back from there when it is answered.
static func _test_the_strip_is_the_only_explanation(dialog: VariableDialog) -> bool:
	var ok: bool = _check("the form draws no hint label of its own",
		_loose_labels(dialog), PackedStringArray(["owner line", "name clash"]))
	dialog.open_for_edit("global", {}, "loot", "Array", "[1, 2, 3]", false, "Add variable")
	ok = _check("a literal that parses says nothing extra",
		dialog._help_strip.tone, EventSheetPopupUI.HelpStrip.TONE_NORMAL) and ok
	dialog._default_edit.text = "[1, 2"
	dialog._refresh_default_hint()
	ok = _check("a literal that does not parse turns the strip red",
		dialog._help_strip.tone, EventSheetPopupUI.HelpStrip.TONE_ERROR) and ok
	ok = _check("and the strip is headed by the field it is about",
		dialog._help_strip.heading_label.text, "INITIAL VALUE") and ok
	dialog._default_edit.text = "[1, 2]"
	dialog._refresh_default_hint()
	ok = _check("fixing it puts the field's own description back",
		dialog._help_strip.tone, EventSheetPopupUI.HelpStrip.TONE_NORMAL) and ok
	ok = _check("which is the one the table carries",
		dialog._help_strip.body_label.text, VariableDialog.field_help("Initial value")) and ok
	dialog.open_for_edit("global", {}, "anything", "Variant", "", false, "Add variable")
	ok = _check("a type that cannot be frozen greys the Constant tick",
		dialog._const_check.disabled, true) and ok
	ok = _check("and the tick says why, in the strip",
		dialog._constant_help().begins_with("Const is unavailable"), true) and ok
	dialog.open_for_edit("global", {}, "taken", "int", "0", true, "Edit variable")
	ok = _check("a locked type opens the strip on the reason",
		dialog._help_strip.body_label.text,
		"Type is locked because this variable is already in use.") and ok
	ok = _check("in the warning voice, not the ordinary one",
		dialog._help_strip.tone, EventSheetPopupUI.HelpStrip.TONE_WARNING) and ok
	return ok


## What the form draws loose between its rows: the owner line under the title, and the inline name
## clash. Anything else is a note beside a field - the very thing the one strip replaced - and it
## comes back named by its text, so a regression says which label came back.
static func _loose_labels(dialog: VariableDialog) -> PackedStringArray:
	var known: Dictionary = {dialog._owner_label: "owner line", dialog._name_warning: "name clash"}
	var found: PackedStringArray = PackedStringArray()
	for child: Node in (dialog._scope_option.get_parent().get_parent() as Node).get_children():
		if child is Label:
			found.append(str(known.get(child, "hint: %s" % (child as Label).text)))
	return found


## The scope keys the dropdown offers, in order.
## What the Flags row is made of - nothing but checkboxes, which is the whole claim.
static func _flag_row_classes(dialog: VariableDialog) -> Array:
	var classes: Array = []
	for child: Node in dialog._static_check.get_parent().get_children():
		classes.append(child.get_class())
	return classes


## The flags actually on screen right now, in the order they read.
static func _visible_flags(dialog: VariableDialog) -> Array:
	var shown: Array = []
	for child: Node in dialog._static_check.get_parent().get_children():
		if child is CheckBox and (child as CheckBox).visible:
			shown.append((child as CheckBox).text)
	return shown


static func _scope_keys(dialog: VariableDialog) -> Array:
	var keys: Array = []
	for index: int in range(dialog._scope_option.item_count):
		keys.append(str(dialog._scope_option.get_item_metadata(index)))
	return keys


## The first `count` type labels.
static func _type_labels(dialog: VariableDialog, count: int) -> Array:
	var labels: Array = []
	for index: int in range(mini(count, dialog._type_option.item_count)):
		labels.append(dialog._type_option.get_item_text(index))
	return labels


## The window title after opening on an existing variable.
static func _edit_title(dialog: VariableDialog, _sheet: EventSheetResource) -> String:
	dialog.open_for_edit("global", {"editing": true, "original_name": "hp"}, "hp", "int", "100", false, "Edit Variable")
	return dialog._dialog.title


## Whether the variable a dialog opened ON is reported as clashing with itself.
static func _clash_while_editing(dialog: VariableDialog, _sheet: EventSheetResource) -> bool:
	dialog.open_for_edit("global", {"editing": true, "original_name": "taken"}, "taken", "int", "0", false, "Edit Variable")
	return dialog.name_clashes("taken")


static func _comparison_labels() -> Array:
	var labels: Array = []
	for option: Dictionary in EventForgeACEFactory.COMPARISON_OPTIONS:
		labels.append(str(option["label"]))
	return labels


static func _comparison_keys() -> Array:
	var keys: Array = []
	for option: Dictionary in EventForgeACEFactory.COMPARISON_OPTIONS:
		keys.append(str(option["key"]))
	return keys


## The muted code note beside an operator dropdown built by the ACE params dialog - the K1 promise
## that a dialog showing the friendly words still shows the token it will insert.
static func _params_operator_note() -> String:
	var params: ACEParamsDialog = ACEParamsDialog.new()
	var field: Control = params._create_field(
		{"type": TYPE_STRING, "default_value": "<=", "options": EventForgeACEFactory.COMPARISON_OPTIONS},
		{}, "op", "")
	var dropdown: OptionButton = params._fields["op"] as OptionButton
	var note: String = (dropdown.get_meta("code_note") as Label).text if dropdown.has_meta("code_note") else ""
	field.free()
	return note


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_dialog_v5_test: %s" % label)
		return true
	print("[FAIL] variable_dialog_v5_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
