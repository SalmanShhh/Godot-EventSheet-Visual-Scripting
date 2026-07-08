# EventSheet - Variable creation dialog component
# Provides a reusable form for creating global or local variables.
# Connect to variable_confirmed to receive the result.
@tool
class_name VariableDialog
extends RefCounted

## Emitted when the user confirms variable creation or editing.
## scope is "global" or "local". exported = accessible outside the generated script
## (@export var) vs. private (var).
signal variable_confirmed(name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary, is_constant: bool, exported: bool, options: PackedStringArray, attributes: Dictionary, onready: bool)

var _dialog: ConfirmationDialog = null
var _scope_label: Label = null
var _name_edit: LineEdit = null
var _name_warning: Label = null
var _sheet_provider: Callable = Callable()
var _type_option: OptionButton = null
# "Whole numbers only" - shown only when the friendly "Number" type is selected; ticked stores int,
# unticked stores float. The dialog's display is friendly; the stored type stays a real Godot type.
var _whole_numbers_check: CheckBox = null
var _whole_numbers_row: HBoxContainer = null
var _default_edit: LineEdit = null
var _items_button: Button = null
var _items_window: Window = null
var _items_edit: TextEdit = null
var _const_check: CheckBox = null
var _exported_check: CheckBox = null
# "@onready" toggle - tree-placed variables only (class-level). When on, the variable compiles to
# `@onready var` and the Default field is a verbatim GDScript expression (a node ref like $Player).
var _onready_check: CheckBox = null
var _onready_row: HBoxContainer = null
# Free-text type shown IN PLACE of the dropdown while @onready is on - so node classes the dropdown can't
# list (Sprite2D, Label, CharacterBody2D…) are authorable. _selected_stored_type() reads it when onready.
var _onready_type_edit: LineEdit = null
var _const_help: Label = null
var _type_help: Label = null
var _scope: String = "global"
var _context: Dictionary = {}
var _default_help: Label = null
var _options_edit: LineEdit = null
var _options_row: HBoxContainer = null
var _enum_fill_menu: MenuButton = null
var _enum_provider: Callable = Callable()
var _attr_toggle: Button = null
var _attr_section: VBoxContainer = null
var _attr_section_card: PanelContainer = null  # themed inset card wrapping _attr_section (matches the picker's panels)
# A second, nested disclosure inside _attr_section: the "Advanced" tier holds the wiring/organizational
# attributes (grouping, show-if/lock-unless/on-changed, clamp, read-only) so the Basic tier (tooltip, range,
# drawer, multiline) reads first.
var _attr_advanced_toggle: Button = null
var _attr_advanced_section: VBoxContainer = null
## Attribute keys whose fields live in the nested Advanced tier. MUST mirror the fields parented under
## _attr_advanced_section in init_dialog - if you move a field between the Basic and Advanced tiers, update
## this too, or open_for_edit's auto-expand will disagree with where the field actually sits.
const _ADVANCED_ATTR_KEYS: Array[String] = ["group", "subgroup", "header", "info", "required", "validate", "action", "show_if", "lock_unless", "on_changed", "clamp", "read_only"]
## The Range field's placeholder per type - one source of truth so the initial build and the per-type swap in
## _refresh_contextual_rows can't drift. Vector2 prompts a single dial reach; numeric prompts min, max, step.
const _RANGE_PLACEHOLDER_NUMERIC: String = "min, max, step (numeric: slider)"
const _RANGE_PLACEHOLDER_VECTOR2: String = "max reach - the dial's magnitude (e.g. 150)"
var _attr_tooltip_edit: LineEdit = null
var _attr_group_edit: LineEdit = null
var _attr_subgroup_edit: LineEdit = null
var _attr_header_edit: LineEdit = null
var _attr_info_edit: LineEdit = null
var _attr_required_check: CheckBox = null
var _attr_validate_edit: LineEdit = null
var _attr_action_edit: LineEdit = null
var _attr_range_edit: LineEdit = null
var _attr_multiline_check: CheckBox = null
var _attr_no_alpha_check: CheckBox = null
var _attr_exp_easing_check: CheckBox = null
var _attr_placeholder_edit: LineEdit = null
var _attr_placeholder_row: Control = null
var _attr_show_if_edit: LineEdit = null
var _attr_lock_unless_edit: LineEdit = null
var _attr_on_changed_edit: LineEdit = null
var _attr_clamp_check: CheckBox = null
var _attr_read_only_check: CheckBox = null
var _attr_drawer_option: OptionButton = null
var _attr_table_columns_edit: LineEdit = null
var _drawer_preview_box: VBoxContainer = null
# The "Inspector look" picker: type-filtered plain-language
# presets for the wider hint families (file/folder pickers, checkbox flags, layer grids,
# node-path filters, valued dropdowns, storage), each with one contextual detail field. The
# "Ships as:" strip renders the EXACT annotation the current choices compile to (the ACE
# Studio pattern), so the friendly names teach the annotation instead of hiding it.
var _attr_look_option: OptionButton = null
var _look_gallery: EventSheetLookGalleryDialog = null
## Queried at gating time (dock-owned preference); invalid Callable = expert mode.
var simple_mode_provider: Callable = Callable()
var _inspector_preview_card: EventSheetInspectorPreviewCard = null
var _attr_look_detail_edit: LineEdit = null
var _attr_look_detail_row: Control = null
var _attr_or_greater_check: CheckBox = null
var _attr_or_less_check: CheckBox = null
var _attr_suffix_edit: LineEdit = null
var _attr_range_modifier_row: Control = null
var _ships_as_label: Label = null

## Offered types. Collections accept GDScript literal defaults ({"key": 1}, [1, 2]) with
## live validation; typed containers (Godot 4 Array[T] / Dictionary[K, V]) also check
## element types for builtin T.
const TYPE_OPTIONS: PackedStringArray = [
	"int", "float", "bool", "String",
	# Common game-value types - also the hosts for the Tier 3 drawers (dial / swatches / texture / curve).
	"Vector2", "Color", "Texture2D", "Curve",
	"Variant",
	"Array", "Array[int]", "Array[float]", "Array[String]",
	"Dictionary", "Dictionary[String, int]", "Dictionary[String, float]",
	"Dictionary[String, String]", "Dictionary[String, Variant]"
]

## Plain-language hover hints for the Type dropdown, in everyday terms (the three common kinds are a
## number, text, and yes/no). The stored type name is unchanged - these are on-demand explanations, not renames.
const TYPE_HINTS: Dictionary = {
	"Number": "A number - a count, score, position, speed… Tick \"Whole numbers only\" for integers.",
	"Text": "Text - words, names, messages.",
	"Yes-No": "A yes/no, on/off switch (true / false).",
	"int": "A whole number, no decimals (for a count or score).",
	"float": "A number that can have decimals - the everyday number type.",
	"bool": "Yes / no, on / off (true / false).",
	"String": "Text.",
	"Vector2": "An x/y pair: a direction, velocity, or position.",
	"Color": "An RGBA colour.",
	"Texture2D": "An image / sprite resource.",
	"Curve": "A shape over 0–1 (easing, falloff, ramps).",
	"Variant": "Any type - untyped (advanced; prefer a specific type when you can).",
}


## Initialise and attach the dialog to parent_node.
## Must be called before open().
func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Create Variable"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dialog.close_requested.connect(_close)
	_dialog.canceled.connect(_close)
	parent_node.add_child(_dialog)

	var form: VBoxContainer = VBoxContainer.new()
	form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	form.custom_minimum_size = Vector2(420.0, 180.0)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.add_child(EventSheetPopupUI.margined(form))

	_scope_label = Label.new()
	form.add_child(_scope_label)

	var name_row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "health"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Enter in the Name field confirms the dialog (parity with function_dialog / the ACE picker).
	_dialog.register_text_enter(_name_edit)
	name_row.add_child(_name_edit)
	form.add_child(name_row)
	_name_warning = Label.new()
	_name_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_warning.custom_minimum_size = Vector2(380.0, 0.0)
	_name_warning.visible = false
	_name_warning.modulate = Color(1.0, 0.5, 0.5)
	form.add_child(_name_warning)
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh_name_warning())

	var type_row: HBoxContainer = HBoxContainer.new()
	var type_label: Label = Label.new()
	type_label.text = "Type"
	type_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	type_row.add_child(type_label)
	_type_option = OptionButton.new()
	# Friendly labels first (Number / Text / Yes-No), then a separator, then the advanced Godot types
	# under their own names. Only the DISPLAY changes - _selected_stored_type() always returns a real
	# Godot type (int/float/String/bool/…), so the stored type_name and the .gd round-trip are unchanged.
	for friendly: String in ["Number", "Text", "Yes-No"]:
		_type_option.add_item(friendly)
		_type_option.set_item_tooltip(_type_option.item_count - 1, str(TYPE_HINTS[friendly]))
	_type_option.add_separator("Advanced types")
	for option: String in TYPE_OPTIONS:
		# int / float collapse into "Number" + a "Whole numbers only" tick; bool → Yes-No; String → Text.
		if option == "int" or option == "float" or option == "bool" or option == "String":
			continue
		_type_option.add_item(option)
		if TYPE_HINTS.has(option):
			_type_option.set_item_tooltip(_type_option.item_count - 1, str(TYPE_HINTS[option]))
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.item_selected.connect(func(_index: int) -> void:
		_refresh_whole_numbers_row()
		_refresh_const_ui()
		_refresh_default_hint()
		_refresh_contextual_rows()
		_refresh_items_button()
	)
	type_row.add_child(_type_option)
	# @onready mode swaps the dropdown for this free-text field (the dropdown can't name node classes). Hidden
	# until onready is ticked; _apply_onready_state toggles it, _selected_stored_type() reads it.
	_onready_type_edit = LineEdit.new()
	_onready_type_edit.placeholder_text = "type - e.g. Node2D, Label, Sprite2D (or Variant for any)"
	_onready_type_edit.tooltip_text = "The variable's type. For a node reference, type the node's class (Sprite2D, Label, Area2D…) or leave Variant."
	_onready_type_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_onready_type_edit.visible = false
	type_row.add_child(_onready_type_edit)
	form.add_child(type_row)

	# "Whole numbers only" - the int/float distinction, surfaced only when "Number" is the chosen type.
	_whole_numbers_row = HBoxContainer.new()
	var whole_spacer: Control = Control.new()
	whole_spacer.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	_whole_numbers_row.add_child(whole_spacer)
	_whole_numbers_check = CheckBox.new()
	_whole_numbers_check.text = "Whole numbers only"
	_whole_numbers_check.tooltip_text = "A whole number (no decimals) - stored as an int. Unticked stores a float."
	_whole_numbers_check.toggled.connect(func(_on: bool) -> void:
		_refresh_default_hint()
		_refresh_contextual_rows())
	_whole_numbers_row.add_child(_whole_numbers_check)
	_whole_numbers_row.visible = false
	form.add_child(_whole_numbers_row)

	var default_row: HBoxContainer = HBoxContainer.new()
	var default_label: Label = Label.new()
	default_label.text = "Default"
	default_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	default_row.add_child(default_label)
	_default_edit = LineEdit.new()
	_default_edit.placeholder_text = "0"
	_default_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_default_edit.text_changed.connect(func(_text: String) -> void:
		_refresh_default_hint()
	)
	default_row.add_child(_default_edit)
	_items_button = Button.new()
	_items_button.text = "Edit items…"
	_items_button.tooltip_text = "Edit an Array/Dictionary's items one per line instead of typing a literal."
	_items_button.pressed.connect(_open_items_editor)
	default_row.add_child(_items_button)
	_refresh_items_button()
	form.add_child(default_row)
	_options_row = HBoxContainer.new()
	var options_label: Label = Label.new()
	options_label.text = "Options (combo)"
	options_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	_options_row.add_child(options_label)
	_options_edit = LineEdit.new()
	_options_edit.placeholder_text = "comma-separated, e.g. easy, normal, hard (String only)"
	_options_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_row.add_child(_options_edit)
	# Sheet enums fill the combo in one click (user call: automate enums into combos).
	_enum_fill_menu = MenuButton.new()
	_enum_fill_menu.text = "From enum"
	_enum_fill_menu.flat = false
	_enum_fill_menu.visible = false
	_enum_fill_menu.about_to_popup.connect(_populate_enum_fill_menu)
	_enum_fill_menu.get_popup().index_pressed.connect(func(index: int) -> void:
		_options_edit.text = str(_enum_fill_menu.get_popup().get_item_metadata(index)))
	_options_row.add_child(_enum_fill_menu)
	form.add_child(_options_row)
	# Inspector attributes behind a disclosure ("More options") - the dialog used to throw everything at once.
	# Collapsed for new variables, auto-expanded when an edited variable already uses an attribute. Exported
	# globals only. (Progressive disclosure.)
	_attr_toggle = Button.new()
	_attr_toggle.flat = true
	_attr_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_attr_toggle.toggle_mode = true
	_attr_toggle.text = "▸  More options (tooltip, range, drawer…)"
	_attr_toggle.tooltip_text = "Optional Inspector polish for exported globals - everything compiles to plain Godot annotations."
	_attr_toggle.toggled.connect(func(expanded: bool) -> void:
		_attr_toggle.text = ("▾" if expanded else "▸") + _attr_toggle.text.substr(1)
		_attr_section_card.visible = expanded)
	form.add_child(_attr_toggle)
	_attr_section = VBoxContainer.new()
	# Themed inset card (the same sunken-panel surface the ACE picker uses), so the optional-attributes
	# block reads as a distinct panel instead of flat form rows floating on the dialog background.
	_attr_section_card = EventSheetPopupUI.panel_section(_attr_section)
	_attr_section_card.visible = false
	form.add_child(_attr_section_card)
	# ── BASIC tier: the friendly polish a designer reaches for first ──
	_attr_tooltip_edit = LineEdit.new()
	_attr_tooltip_edit.placeholder_text = "shown when hovering the property"
	_attr_section.add_child(EventSheetPopupUI.form_row("Tooltip", _attr_tooltip_edit))
	_attr_range_edit = LineEdit.new()
	_attr_range_edit.placeholder_text = _RANGE_PLACEHOLDER_NUMERIC
	_attr_range_edit.text_changed.connect(func(_t: String) -> void:
		_refresh_drawer_preview()
		_refresh_clamp_gate()
		_refresh_ships_as())
	_attr_section.add_child(EventSheetPopupUI.form_row("Range", _attr_range_edit))
	_attr_drawer_option = OptionButton.new()
	_attr_drawer_option.add_item("Default field")
	_attr_drawer_option.tooltip_text = "Swap the Inspector field for a richer drawer (dial, swatches, curve…).\nGraceful: a plain field without the editor plugin (parity preserved)."
	_attr_drawer_option.item_selected.connect(func(_i: int) -> void: _refresh_drawer_preview())
	_attr_section.add_child(EventSheetPopupUI.form_row("Show as", _attr_drawer_option))
	# The table drawer's one config field: its column schema, in plain "name:type" pairs.
	_attr_table_columns_edit = LineEdit.new()
	_attr_table_columns_edit.placeholder_text = "columns, e.g. item:String, count:int, rare:bool"
	_attr_table_columns_edit.tooltip_text = "One column per entry: name:type (String, int, float or bool).\nEach Array element becomes a row with these cells."
	_attr_table_columns_edit.text_changed.connect(func(_t: String) -> void: _refresh_drawer_preview())
	_attr_section.add_child(EventSheetPopupUI.form_row("Table columns", _attr_table_columns_edit))
	# Live "what the drawer looks like" preview - the actual widget, updated as the type / drawer / bounds change.
	_drawer_preview_box = VBoxContainer.new()
	_drawer_preview_box.visible = false
	_drawer_preview_box.add_theme_constant_override("separation", 3)
	_attr_section.add_child(_drawer_preview_box)
	_attr_multiline_check = CheckBox.new()
	_attr_multiline_check.text = "Multiline (String: big text box)"
	_attr_section.add_child(_attr_multiline_check)
	# Color-only: @export_color_no_alpha - a solid RGB swatch (the Inspector hides the alpha slider).
	_attr_no_alpha_check = CheckBox.new()
	_attr_no_alpha_check.text = "No alpha (Color: solid RGB, no transparency)"
	_attr_section.add_child(_attr_no_alpha_check)
	# float-only: @export_exp_easing - an easing-curve handle in the Inspector (for 0-1 attenuation values).
	_attr_exp_easing_check = CheckBox.new()
	_attr_exp_easing_check.text = "Easing curve (float: exponential ease handle)"
	_attr_section.add_child(_attr_exp_easing_check)
	# String-only: @export_placeholder - grey hint text shown while the field is empty.
	_attr_placeholder_edit = LineEdit.new()
	_attr_placeholder_edit.placeholder_text = "grey hint shown when the field is empty"
	_attr_placeholder_row = EventSheetPopupUI.form_row("Placeholder", _attr_placeholder_edit)
	_attr_section.add_child(_attr_placeholder_row)
	# Range modifiers (numeric): open-ended slider ends + a unit suffix, folded into the range.
	var range_modifier_box: HBoxContainer = HBoxContainer.new()
	range_modifier_box.add_theme_constant_override("separation", 8)
	_attr_or_greater_check = CheckBox.new()
	_attr_or_greater_check.text = "No upper limit"
	_attr_or_greater_check.tooltip_text = "The slider stops at max but typing a bigger number is allowed (or_greater)."
	_attr_or_greater_check.toggled.connect(func(_on: bool) -> void: _refresh_ships_as())
	range_modifier_box.add_child(_attr_or_greater_check)
	_attr_or_less_check = CheckBox.new()
	_attr_or_less_check.text = "No lower limit"
	_attr_or_less_check.tooltip_text = "Typing below min is allowed (or_less)."
	_attr_or_less_check.toggled.connect(func(_on: bool) -> void: _refresh_ships_as())
	range_modifier_box.add_child(_attr_or_less_check)
	_attr_suffix_edit = LineEdit.new()
	_attr_suffix_edit.placeholder_text = "unit, e.g. px"
	_attr_suffix_edit.custom_minimum_size = Vector2(90.0, 0.0)
	_attr_suffix_edit.tooltip_text = "Shown after the number in the Inspector (suffix:px)."
	_attr_suffix_edit.text_changed.connect(func(_t: String) -> void: _refresh_ships_as())
	range_modifier_box.add_child(_attr_suffix_edit)
	_attr_range_modifier_row = EventSheetPopupUI.form_row("Slider extras", range_modifier_box)
	_attr_section.add_child(_attr_range_modifier_row)
	# The Inspector-look presets (type-filtered; rebuilt by _refresh_contextual_rows).
	_attr_look_option = OptionButton.new()
	_attr_look_option.tooltip_text = "How this variable's field LOOKS in the Inspector - pickers, flags, layer grids... Plain fields need no choice here."
	_attr_look_option.item_selected.connect(func(_i: int) -> void:
		_refresh_look_detail()
		_refresh_ships_as())
	# "Browse..." opens the same presets as picture tiles (choose by recognition,
	# not vocabulary); both surfaces drive this one dropdown.
	var look_field: HBoxContainer = HBoxContainer.new()
	_attr_look_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	look_field.add_child(_attr_look_option)
	var browse_looks_button: Button = Button.new()
	browse_looks_button.text = "Browse..."
	browse_looks_button.tooltip_text = "Pick the Inspector look from picture tiles instead of the list."
	browse_looks_button.pressed.connect(_open_look_gallery)
	look_field.add_child(browse_looks_button)
	_attr_section.add_child(EventSheetPopupUI.form_row("Inspector look", look_field))
	_attr_look_detail_edit = LineEdit.new()
	_attr_look_detail_edit.text_changed.connect(func(_t: String) -> void: _refresh_ships_as())
	_attr_look_detail_row = EventSheetPopupUI.form_row("Details", _attr_look_detail_edit)
	_attr_look_detail_row.visible = false
	_attr_section.add_child(_attr_look_detail_row)
	# The Inspector preview card: a live mock of the final Inspector rows (group header,
	# subgroup indent, name, widget) + a one-sentence summary - the picture for beginners,
	# with the "Ships as:" strip below it as the code truth for experts.
	_inspector_preview_card = EventSheetInspectorPreviewCard.new()
	_attr_section.add_child(_inspector_preview_card)
	# "Ships as:" - the exact annotation these choices compile to, straight from the compiler's
	# own prefix builder so it can never drift from reality.
	_ships_as_label = Label.new()
	_ships_as_label.add_theme_color_override("font_color", EventSheetPalette.TEXT_MUTED)
	_ships_as_label.add_theme_font_size_override("font_size", 12)
	_ships_as_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_attr_section.add_child(_ships_as_label)
	# Everything the strip reads refreshes it live, so the taught annotation is never stale.
	_attr_multiline_check.toggled.connect(func(_on: bool) -> void: _refresh_ships_as())
	_attr_no_alpha_check.toggled.connect(func(_on: bool) -> void: _refresh_ships_as())
	_attr_exp_easing_check.toggled.connect(func(_on: bool) -> void: _refresh_ships_as())
	_attr_placeholder_edit.text_changed.connect(func(_t: String) -> void: _refresh_ships_as())
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_ships_as())
	# ── ADVANCED tier (nested disclosure): wiring + organization that assumes other vars/funcs exist or
	# Godot-Inspector fluency - kept out of the common path so the Basic tier reads cleanly. ──
	_attr_advanced_toggle = Button.new()
	_attr_advanced_toggle.flat = true
	_attr_advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_attr_advanced_toggle.toggle_mode = true
	_attr_advanced_toggle.text = "▸  Advanced (grouping, conditions, clamp…)"
	_attr_advanced_toggle.tooltip_text = "Inspector grouping, conditional show/lock, an on-changed callback, clamp, read-only - for variables that reference other variables or functions."
	_attr_advanced_toggle.toggled.connect(func(expanded: bool) -> void:
		_attr_advanced_toggle.text = ("▾" if expanded else "▸") + _attr_advanced_toggle.text.substr(1)
		_attr_advanced_section.visible = expanded)
	_attr_section.add_child(_attr_advanced_toggle)
	_attr_advanced_section = VBoxContainer.new()
	_attr_advanced_section.visible = false
	_attr_section.add_child(_attr_advanced_section)
	_attr_group_edit = LineEdit.new()
	_attr_group_edit.placeholder_text = "Inspector section header (e.g. Combat)"
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Group under heading", _attr_group_edit))
	_attr_subgroup_edit = LineEdit.new()
	_attr_subgroup_edit.placeholder_text = "nested section under the group (e.g. Melee)"
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Sub-heading", _attr_subgroup_edit))
	# Decor: editor-only comment markers rendered above the property (a plain field without the plugin).
	_attr_header_edit = LineEdit.new()
	_attr_header_edit.placeholder_text = "accent label above (e.g. Combat #e06666)"
	_attr_header_edit.tooltip_text = "A coloured section label drawn above this property in the Inspector.\nEnd with a #rrggbb to tint it. Editor decor only - plain comment in the code."
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Section header", _attr_header_edit))
	_attr_info_edit = LineEdit.new()
	_attr_info_edit.placeholder_text = "note panel above (e.g. Shared resource - edits affect every user.)"
	_attr_info_edit.tooltip_text = "A quiet info panel drawn above this property in the Inspector.\nEditor decor only - plain comment in the code."
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Info note", _attr_info_edit))
	_attr_required_check = CheckBox.new()
	_attr_required_check.text = "Required (warn in the Inspector while unset)"
	_attr_required_check.tooltip_text = "Shows a red warning above the field until a value is assigned\n(a Resource left empty, a String left blank). Editor-only."
	_attr_advanced_section.add_child(_attr_required_check)
	_attr_validate_edit = LineEdit.new()
	_attr_validate_edit.placeholder_text = "sheet function returning a warning String (empty = valid)"
	_attr_validate_edit.tooltip_text = "The Inspector calls this function while the property is edited and shows\nthe returned message above the field. Needs a @tool sheet to run in-editor."
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Validate with", _attr_validate_edit))
	_attr_action_edit = LineEdit.new()
	_attr_action_edit.placeholder_text = "function and button label, e.g. reroll_stats Reroll"
	_attr_action_edit.tooltip_text = "Renders a small button with this field that calls the named sheet function.\nNeeds a @tool sheet to act in-editor. Label optional (defaults to the function name)."
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Field button", _attr_action_edit))
	_attr_show_if_edit = LineEdit.new()
	_attr_show_if_edit.placeholder_text = "bool variable (hidden when false)"
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Show if", _attr_show_if_edit))
	_attr_lock_unless_edit = LineEdit.new()
	_attr_lock_unless_edit.placeholder_text = "bool variable (read-only when false)"
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("Lock unless", _attr_lock_unless_edit))
	_attr_on_changed_edit = LineEdit.new()
	_attr_on_changed_edit.placeholder_text = "sheet function called after assignment"
	_attr_advanced_section.add_child(EventSheetPopupUI.form_row("On changed", _attr_on_changed_edit))
	var attr_checks: HBoxContainer = HBoxContainer.new()
	_attr_clamp_check = CheckBox.new()
	_attr_clamp_check.text = "Clamp to range"
	attr_checks.add_child(_attr_clamp_check)
	_attr_read_only_check = CheckBox.new()
	_attr_read_only_check.text = "Read-only"
	attr_checks.add_child(_attr_read_only_check)
	_attr_advanced_section.add_child(attr_checks)
	_default_help = Label.new()
	_default_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_default_help.custom_minimum_size = Vector2(380.0, 0.0)
	_default_help.visible = false
	_default_help.modulate = Color(0.82, 0.82, 0.82, 0.82)
	form.add_child(_default_help)

	var const_row: HBoxContainer = HBoxContainer.new()
	var const_label: Label = Label.new()
	const_label.text = "Flags"
	const_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	const_row.add_child(const_label)
	_const_check = CheckBox.new()
	_const_check.text = "Constant (can't change at runtime)"
	const_row.add_child(_const_check)
	form.add_child(const_row)

	var access_row: HBoxContainer = HBoxContainer.new()
	var access_label: Label = Label.new()
	access_label.text = "Access"
	access_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	access_row.add_child(access_label)
	_exported_check = CheckBox.new()
	_exported_check.text = "Editable in the Inspector (a designer property)"
	_exported_check.tooltip_text = "On: a designer can tweak this per-instance in the Inspector (@export var).\nOff: internal script state - a plain private var (the default for a new variable)."
	_exported_check.toggled.connect(func(_pressed: bool) -> void: _update_attr_gating())
	access_row.add_child(_exported_check)
	form.add_child(access_row)

	# @onready row - shown only for tree-placed (class-level) variables (open_for_edit gates visibility).
	_onready_row = HBoxContainer.new()
	var onready_label: Label = Label.new()
	onready_label.text = "On ready"
	onready_label.custom_minimum_size = Vector2(EventSheetPopupUI.LABEL_MIN_WIDTH, 0.0)
	_onready_row.add_child(onready_label)
	_onready_check = CheckBox.new()
	_onready_check.text = "Set on _ready() - for node refs like $Player"
	_onready_check.tooltip_text = "On: compiles to @onready var - the Default is a GDScript EXPRESSION evaluated when the node enters the tree (e.g. $Player, get_node(\"UI/Score\")), not a literal.\nUse it to grab a node reference once the scene is ready."
	_onready_check.toggled.connect(func(pressed: bool) -> void: _on_onready_toggled_interactive(pressed))
	_onready_row.add_child(_onready_check)
	form.add_child(_onready_row)

	_const_help = Label.new()
	_const_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_const_help.custom_minimum_size = Vector2(380.0, 0.0)
	_const_help.visible = false
	_const_help.modulate = Color(0.82, 0.82, 0.82, 0.82)
	form.add_child(_const_help)

	_type_help = Label.new()
	_type_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_type_help.custom_minimum_size = Vector2(380.0, 0.0)
	_type_help.visible = false
	_type_help.modulate = Color(0.82, 0.82, 0.82, 0.82)
	form.add_child(_type_help)


## A 130px-label + expanding-field row, matching the main form's columns, so the optional
## Inspector fields line up with Name/Type/Default above instead of running full-width.
## ── Friendly type mapping (display ↔ stored Godot type) ──────────────────────
## The real Godot type the current selection stores (written to LocalVariable.type_name and
## round-tripped). Friendly labels map back to int/float/String/bool; advanced types are literal.
## Only the DROPDOWN DISPLAY is friendly - the stored type is unchanged, so compile/import round-trip.
func _selected_stored_type() -> String:
	# In @onready mode the type comes from the free-text field (node classes the dropdown can't list); empty
	# falls back to Variant, which safely accepts any node reference / expression.
	if _onready_check != null and _onready_check.button_pressed and _onready_type_edit != null:
		var typed_name: String = _onready_type_edit.text.strip_edges()
		return typed_name if not typed_name.is_empty() else "Variant"
	if _type_option == null or _type_option.selected < 0:
		return "int"
	var label: String = _type_option.get_item_text(_type_option.selected)
	match label:
		"Number":
			return "int" if _whole_numbers_check != null and _whole_numbers_check.button_pressed else "float"
		"Text":
			return "String"
		"Yes-No":
			return "bool"
		_:
			return label


## Selects the dropdown entry (+ the Whole-numbers tick) that stores `type_name` - the reverse of
## _selected_stored_type, used to prefill the dialog when editing an existing variable.
func _select_stored_type(type_name: String) -> void:
	var target: String = type_name
	match type_name:
		"int":
			target = "Number"
			if _whole_numbers_check != null:
				_whole_numbers_check.button_pressed = true
		"float":
			target = "Number"
			if _whole_numbers_check != null:
				_whole_numbers_check.button_pressed = false
		"String":
			target = "Text"
		"bool":
			target = "Yes-No"
	for index: int in range(_type_option.item_count):
		if _type_option.get_item_text(index) == target:
			_type_option.select(index)
			break
	_refresh_whole_numbers_row()


## Shows the "Whole numbers only" tick only while the friendly "Number" type is selected.
func _refresh_whole_numbers_row() -> void:
	if _whole_numbers_row == null:
		return
	var label: String = _type_option.get_item_text(_type_option.selected) if _type_option != null and _type_option.selected >= 0 else ""
	_whole_numbers_row.visible = label == "Number"


## ── Structured data editor (Array/Dictionary "Edit items…") ──────────────────
## True when the chosen type is a collection, so the structured items editor applies.
func _selected_type_is_collection() -> bool:
	return _selected_stored_type().begins_with("Array") or _selected_stored_type().begins_with("Dictionary")


func _refresh_items_button() -> void:
	if _items_button != null:
		_items_button.visible = _selected_type_is_collection()


## Edit an Array/Dictionary's items one per line (Array: a value per line; Dictionary a
## "key: value" per line) instead of typing a cramped literal. Round-trips through the
## literal so the stored default's shape is unchanged.
func _open_items_editor() -> void:
	if _items_window == null:
		_build_items_window()
	var is_dict: bool = _selected_stored_type().begins_with("Dictionary")
	_items_edit.text = "\n".join(collection_literal_items(_default_edit.text))
	_items_edit.placeholder_text = "one \"key\": value per line" if is_dict else "one value per line"
	_items_window.title = "Edit Dictionary Items" if is_dict else "Edit Array Items"
	_items_window.popup_centered(Vector2i(420, 360))
	_items_edit.grab_focus()


func _build_items_window() -> void:
	_items_window = Window.new()
	_items_window.visible = false
	_items_window.min_size = Vector2i(360, 280)
	_items_window.close_requested.connect(func() -> void: _items_window.hide())
	_dialog.add_child(_items_window)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	_items_window.add_child(box)
	var hint: Label = Label.new()
	hint.text = "One item per line - each line is a GDScript value expression."
	box.add_child(hint)
	_items_edit = TextEdit.new()
	_items_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_items_edit)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var cancel: Button = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: _items_window.hide())
	buttons.add_child(cancel)
	var apply_button: Button = Button.new()
	apply_button.text = "Apply"
	apply_button.pressed.connect(_apply_items_editor)
	buttons.add_child(apply_button)
	box.add_child(buttons)


func _apply_items_editor() -> void:
	var is_dict: bool = _selected_stored_type().begins_with("Dictionary")
	var items: PackedStringArray = PackedStringArray()
	for line: String in _items_edit.text.split("\n"):
		if not line.strip_edges().is_empty():
			items.append(line.strip_edges())
	_default_edit.text = items_to_collection_literal(items, is_dict)
	_refresh_default_hint()
	_items_window.hide()


## Splits an Array/Dictionary literal into its top-level entries (bracket- + string-aware):
## '[1, [2, 3], "a,b"]' -> ['1', '[2, 3]', '"a,b"']. Pure + static, so it is unit-testable.
static func collection_literal_items(literal: String) -> PackedStringArray:
	var items: PackedStringArray = PackedStringArray()
	var trimmed: String = literal.strip_edges()
	if (trimmed.begins_with("[") and trimmed.ends_with("]")) or (trimmed.begins_with("{") and trimmed.ends_with("}")):
		trimmed = trimmed.substr(1, trimmed.length() - 2)
	trimmed = trimmed.strip_edges()
	if trimmed.is_empty():
		return items
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var current: String = ""
	for i: int in trimmed.length():
		var ch: String = trimmed[i]
		if in_string:
			current += ch
			if ch == quote and (i == 0 or trimmed[i - 1] != "\\"):
				in_string = false
			continue
		if ch == "\"" or ch == "'":
			in_string = true
			quote = ch
			current += ch
		elif ch == "[" or ch == "{" or ch == "(":
			depth += 1
			current += ch
		elif ch == "]" or ch == "}" or ch == ")":
			depth -= 1
			current += ch
		elif ch == "," and depth == 0:
			items.append(current.strip_edges())
			current = ""
		else:
			current += ch
	if not current.strip_edges().is_empty():
		items.append(current.strip_edges())
	return items


## Wraps item expressions back into an Array literal ("[a, b]") or Dictionary literal
## ("{k: v, …}"). Empty -> "[]" / "{}".
static func items_to_collection_literal(items: PackedStringArray, is_dictionary: bool) -> String:
	if items.is_empty():
		return "{}" if is_dictionary else "[]"
	var joined: String = ", ".join(items)
	return ("{%s}" % joined) if is_dictionary else ("[%s]" % joined)


## Open the dialog for the given scope ("global" or "local").
func open(scope: String) -> void:
	# A new variable is internal script state by DEFAULT (a plain private var) - the user opts into
	# "Designer-tweakable (@export)" deliberately, instead of every global leaking onto the Inspector.
	open_for_edit(scope, {}, "", "int", "", false, "Create Variable", false, false)


## Inspector attributes (range, group, show-if…) only mean anything on an @export var, so their
## disclosure shows only when "Designer-tweakable" is on (and the variable can export). With it off the
## section is hidden + collapsed, so a user never sets attributes that would silently no-op.
func _update_attr_gating() -> void:
	if _attr_toggle == null:
		return
	var can_export: bool = _exported_check != null and _exported_check.button_pressed and not _exported_check.disabled
	_attr_toggle.visible = can_export
	# Simple Mode keeps the whole Advanced tier out of sight: its six fields are wiring
	# and organization, not looks. Display-only - attributes already set on a variable
	# still round-trip untouched, and the tier returns the moment Simple Mode turns off.
	var simple: bool = simple_mode_provider.is_valid() and bool(simple_mode_provider.call())
	if _attr_advanced_toggle != null and simple:
		_attr_advanced_toggle.visible = false
		_attr_advanced_toggle.set_pressed_no_signal(false)
		if _attr_advanced_section != null:
			_attr_advanced_section.visible = false
	elif _attr_advanced_toggle != null:
		_attr_advanced_toggle.visible = true
	if not can_export:
		_attr_toggle.set_pressed_no_signal(false)
		_attr_toggle.text = "▸" + _attr_toggle.text.substr(1)
		if _attr_section_card != null:
			_attr_section_card.visible = false
		# Also collapse the nested Advanced tier so a later re-expand starts from the Basic-first state (rather
		# than leaving the advanced block remembered-open from an earlier export-on session).
		if _attr_advanced_toggle != null:
			_attr_advanced_toggle.set_pressed_no_signal(false)
			_attr_advanced_toggle.text = "▸" + _attr_advanced_toggle.text.substr(1)
			if _attr_advanced_section != null:
				_attr_advanced_section.visible = false


## Interactive tick: seed the free-text type with a safe Variant default (a node ref is safest untyped, and
## the user can then type the node's class). Only when empty, so an already-typed field is left alone.
func _on_onready_toggled_interactive(pressed: bool) -> void:
	if pressed and _onready_type_edit != null and _onready_type_edit.text.strip_edges().is_empty():
		_onready_type_edit.text = "Variant"
	_apply_onready_state(pressed)


## @onready is mutually exclusive with const / @export (the compiler emits ONLY `@onready var`): ticking it
## clears + disables both, swaps the Type dropdown for the free-text type field (node classes the dropdown
## can't list), and turns the Default into an expression prompt. Unticking restores everything (export stays
## disabled for a local-scope variable, which is always private). Shared by the interactive tick and open_for_edit.
func _apply_onready_state(pressed: bool) -> void:
	if pressed:
		if _const_check != null:
			_const_check.set_pressed_no_signal(false)
		if _exported_check != null:
			_exported_check.set_pressed_no_signal(false)
	if _const_check != null:
		_const_check.disabled = pressed
	if _exported_check != null:
		_exported_check.disabled = pressed or _scope == "local"
	if _default_edit != null:
		_default_edit.placeholder_text = "expression, e.g. $Player or get_node(\"UI/Score\")" if pressed else ""
	# Swap the Type control: free-text in onready mode, the friendly dropdown otherwise.
	if _onready_type_edit != null:
		_onready_type_edit.visible = pressed
	if _type_option != null:
		_type_option.visible = not pressed
	if _whole_numbers_row != null and pressed:
		_whole_numbers_row.visible = false
	elif not pressed:
		_refresh_whole_numbers_row()
	# In onready mode const is already disabled (not a per-type story), so the "const unavailable for <type>"
	# hint is redundant + can read stale against the free-text type - hide it.
	if _const_help != null and pressed:
		_const_help.visible = false
	_update_attr_gating()


func open_for_edit(
	scope: String,
	context: Dictionary = {},
	name: String = "",
	type_name: String = "int",
	default_value: Variant = "",
	lock_type: bool = false,
	title: String = "Edit Variable",
	is_constant: bool = false,
	exported: bool = true,
	onready: bool = false
) -> void:
	if _dialog == null:
		push_error("VariableDialog.open() called before init_dialog().")
		return
	_scope = scope
	_context = context.duplicate(true)
	_scope_label.text = "Scope: %s" % scope.capitalize()
	_dialog.title = title
	_name_edit.text = name
	_refresh_name_warning()
	_default_edit.text = _default_display_text(default_value)
	# Select the friendly dropdown entry (+ Whole-numbers tick) that stores this Godot type.
	_select_stored_type(type_name)
	_refresh_items_button()
	_const_check.button_pressed = is_constant
	# Local variables are inherently private to the script body, so the export toggle only
	# applies to global (sheet-level) variables.
	var is_local: bool = scope == "local"
	_exported_check.button_pressed = exported and not is_local
	_exported_check.disabled = is_local
	_exported_check.tooltip_text = (
		"Local variables are always private to the script."
		if is_local
		else "On: a designer tweaks this per-instance in the Inspector (@export var).\nOff: internal script state - a plain private var."
	)
	# @onready is a tree-placed (class-level) concept only - hidden for global/local scopes. Applying the
	# toggle also (re)sets the const/@export disabling to a consistent state for the current scope.
	var is_tree: bool = scope == "tree"
	if _onready_row != null:
		_onready_row.visible = is_tree
	if _onready_check != null:
		_onready_check.set_pressed_no_signal(onready and is_tree)
	# EDITING an onready var: seed the free-text type with its declared type (so Sprite2D shows + round-trips).
	# Otherwise clear it, so ticking onready later defaults to Variant instead of a stale numeric type.
	if _onready_type_edit != null:
		_onready_type_edit.text = type_name if (onready and is_tree) else ""
	_apply_onready_state(onready and is_tree)
	var existing_attributes: Dictionary = context.get("attributes") if context.get("attributes") is Dictionary else {}
	_attr_tooltip_edit.text = str(existing_attributes.get("tooltip", ""))
	_attr_group_edit.text = str(existing_attributes.get("group", ""))
	_attr_subgroup_edit.text = str(existing_attributes.get("subgroup", ""))
	var existing_header: String = str(existing_attributes.get("header", ""))
	var existing_header_color: String = str(existing_attributes.get("header_color", ""))
	_attr_header_edit.text = (existing_header + " " + existing_header_color).strip_edges() if not existing_header_color.is_empty() else existing_header
	_attr_info_edit.text = str(existing_attributes.get("info", ""))
	_attr_required_check.set_pressed_no_signal(bool(existing_attributes.get("required", false)))
	_attr_validate_edit.text = str(existing_attributes.get("validate", ""))
	var existing_action: String = str(existing_attributes.get("action", ""))
	var existing_action_label: String = str(existing_attributes.get("action_label", ""))
	_attr_action_edit.text = (existing_action + " " + existing_action_label).strip_edges() if not existing_action_label.is_empty() else existing_action
	var existing_range: Variant = existing_attributes.get("range")
	# Default a missing step to 1: a drawer-recovered range carries only min/max, and the apply needs all
	# three parts (so a reopened progress_bar/dial re-saves cleanly instead of erroring on "min, max").
	_attr_range_edit.text = "%s, %s, %s" % [str((existing_range as Dictionary).get("min", "0")), str((existing_range as Dictionary).get("max", "100")), str((existing_range as Dictionary).get("step", "1"))] if existing_range is Dictionary else ""
	_attr_multiline_check.button_pressed = bool(existing_attributes.get("multiline", false))
	_attr_no_alpha_check.button_pressed = bool(existing_attributes.get("no_alpha", false))
	_attr_exp_easing_check.button_pressed = bool(existing_attributes.get("exp_easing", false))
	_attr_placeholder_edit.text = str(existing_attributes.get("placeholder", ""))
	if existing_range is Dictionary:
		_attr_or_greater_check.button_pressed = bool((existing_range as Dictionary).get("or_greater", false))
		_attr_or_less_check.button_pressed = bool((existing_range as Dictionary).get("or_less", false))
		_attr_suffix_edit.text = str((existing_range as Dictionary).get("suffix", ""))
	else:
		_attr_or_greater_check.button_pressed = false
		_attr_or_less_check.button_pressed = false
		_attr_suffix_edit.text = ""
	_prefill_look(existing_attributes)
	_attr_show_if_edit.text = str(existing_attributes.get("show_if", ""))
	_attr_lock_unless_edit.text = str(existing_attributes.get("lock_unless", ""))
	_attr_on_changed_edit.text = str(existing_attributes.get("on_changed", ""))
	_attr_clamp_check.button_pressed = bool(existing_attributes.get("clamp", false))
	_attr_read_only_check.button_pressed = bool(existing_attributes.get("read_only", false))
	# Progressive disclosure: "More options" starts collapsed for new variables and auto-expands when the
	# edited variable already uses any attribute. The nested "Advanced" tier auto-expands ONLY when an
	# advanced attribute is set - a tooltip-only variable shouldn't unfurl the whole advanced block.
	if _attr_toggle != null:
		var has_any: bool = not existing_attributes.is_empty()
		_attr_toggle.button_pressed = has_any
		_attr_section_card.visible = has_any
		_attr_toggle.text = ("▾" if _attr_section_card.visible else "▸") + _attr_toggle.text.substr(1)
	if _attr_advanced_toggle != null:
		var has_advanced: bool = false
		for adv_key: String in _ADVANCED_ATTR_KEYS:
			if existing_attributes.has(adv_key):
				has_advanced = true
				break
		_attr_advanced_toggle.button_pressed = has_advanced
		_attr_advanced_section.visible = has_advanced
		_attr_advanced_toggle.text = ("▾" if has_advanced else "▸") + _attr_advanced_toggle.text.substr(1)
	# Inspector attributes only apply to an exported var, so gate their disclosure on the toggle.
	_update_attr_gating()
	_refresh_const_ui()
	_refresh_default_hint()
	_refresh_contextual_rows()
	# Re-select the drawer the variable already uses (after _refresh_contextual_rows rebuilt the per-type options).
	var existing_drawer: String = str(existing_attributes.get("drawer", ""))
	# Toggle-button choices reopen in the familiar Options field (they left it on apply).
	if existing_attributes.get("toggle_options") is Array and _options_edit != null and _options_edit.text.strip_edges().is_empty():
		var toggle_texts: PackedStringArray = PackedStringArray()
		for toggle_option: Variant in existing_attributes.get("toggle_options"):
			toggle_texts.append(str(toggle_option))
		_options_edit.text = ", ".join(toggle_texts)
	if existing_attributes.get("table_columns") is Array:
		var column_texts: PackedStringArray = PackedStringArray()
		for column: Variant in existing_attributes.get("table_columns"):
			if column is Dictionary:
				column_texts.append("%s:%s" % [str((column as Dictionary).get("name", "")), str((column as Dictionary).get("type", "String"))])
		_attr_table_columns_edit.text = ", ".join(column_texts)
	if not existing_drawer.is_empty() and _attr_drawer_option.item_count > 1:
		_select_drawer_kind(existing_drawer)
		_refresh_drawer_preview()
	_type_option.disabled = lock_type
	_type_help.visible = lock_type
	_type_help.text = "Type is locked because this variable is already in use."
	if _dialog.is_inside_tree():
		_dialog.popup_centered(Vector2i(468, 248))
		# Land focus on the Name field so creating/editing a variable is keyboard-first (parity with
		# function_dialog / the ACE picker); select_all lets edit-mode immediately overtype the name.
		_name_edit.grab_focus()
		_name_edit.select_all()


func _close() -> void:
	if _dialog != null:
		_dialog.hide()


func _on_confirmed() -> void:
	var var_name: String = _name_edit.text.strip_edges()
	if var_name.is_empty():
		return
	# Guardrail: a name that shadows a host-class member breaks the generated script (a global
	# becomes a duplicate member that will not load; a local silently hides the member). Block it.
	var shadow_owner: String = _shadow_owner(var_name)
	if not shadow_owner.is_empty():
		if _name_warning != null:
			_name_warning.visible = true
			_name_warning.text = "✗ \"%s\" shadows a %s member - pick another name." % [var_name, shadow_owner]
		if _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered", Vector2i(460, 260))
		return
	var type_name: String = _selected_stored_type()
	# @onready (tree scope): the Default is a verbatim GDScript expression (a node ref / call), NOT a literal -
	# so skip the literal validation/coercion and the combo/attribute machinery a deferred node handle never
	# uses. const/@export are emitted false (the compiler emits only `@onready var`).
	if _onready_check != null and _onready_check.button_pressed and _scope == "tree":
		# The expression is mandatory: a blank one would emit `@onready var x: Type = ` - a syntax error.
		# Block it (event-sheet-style: reopen with the text intact) instead of committing broken GDScript.
		var onready_expr: String = _default_edit.text.strip_edges()
		if onready_expr.is_empty():
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ @onready needs an expression (e.g. $Player or get_node(\"UI/Score\"))."
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(460, 260))
			return
		# type_name is _selected_stored_type() = the @onready free-text type: a node class the user typed
		# (Sprite2D, Label…) or Variant (safe for any node ref). const/@export are false - the compiler
		# emits only @onready var.
		variable_confirmed.emit(var_name, type_name, onready_expr, _scope, _context.duplicate(true), false, false, PackedStringArray(), {}, true)
		return
	# Guardrail (event-sheet-style): an invalid collection literal never commits - the dialog
	# reopens with the text intact so the user fixes or cancels deliberately.
	var verdict: Dictionary = validate_default(type_name, _default_edit.text)
	if not bool(verdict.get("ok", true)):
		if _default_help != null:
			_default_help.visible = true
			_default_help.text = "✗ %s" % str(verdict.get("error", ""))
		if _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered", Vector2i(440, 240))
		return
	var default_value: Variant = _parse_default(type_name, _default_edit.text)
	# Combo guardrail (event sheet): a String with options must default to one of them.
	var combo_options: PackedStringArray = parse_options(_options_edit.text if _options_edit != null else "")
	if type_name == "String" and not combo_options.is_empty():
		if str(default_value).strip_edges().is_empty():
			default_value = combo_options[0]
		elif not combo_options.has(str(default_value)):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ Default must be one of the options (%s)." % ", ".join(combo_options)
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
	# Keep this defensive check in case stale UI state emits a checked const flag
	# for a type that does not support const.
	var is_constant: bool = _const_check.button_pressed and _supports_constant(type_name)
	var exported: bool = _exported_check.button_pressed and _scope == "global"
	var attributes: Dictionary = {}
	if not _attr_tooltip_edit.text.strip_edges().is_empty():
		attributes["tooltip"] = _attr_tooltip_edit.text.strip_edges()
	if not _attr_group_edit.text.strip_edges().is_empty():
		attributes["group"] = _attr_group_edit.text.strip_edges()
	if not _attr_subgroup_edit.text.strip_edges().is_empty():
		attributes["subgroup"] = _attr_subgroup_edit.text.strip_edges()
	attributes.merge(_decor_attributes(), true)
	# Numeric-only attributes are gated on the type so a leftover value from a
	# previous type (the field is now HIDDEN by _refresh_contextual_rows) is inert
	# rather than erroring about a field the user can no longer see.
	var is_numeric: bool = type_name == "int" or type_name == "float"
	# Vector2 keeps a range too - its max drives the direction dial's magnitude, and the Range row is shown
	# for it (_refresh_contextual_rows). Without this it'd be dropped on apply, resetting the dial to max 100.
	var range_applies: bool = is_numeric or type_name == "Vector2"
	var range_text: String = _attr_range_edit.text.strip_edges()
	if not range_text.is_empty() and range_applies:
		# Forgiving: 1 part = max (min 0, step 1); 2 = min, max (step 1); 3 = min, max, step. A dial uses only
		# its max, so a designer shouldn't have to type a min/step it ignores - config is optional with sensible
		# defaults, and config beyond a max never hard-errors.
		# allow_empty=TRUE: keep empty slots so positions are preserved ("0,,5" → ["0","","5"], a blank max that
		# _parse_range_parts correctly rejects). split(",", false) would drop the empty and silently misread it.
		var range_parts: PackedStringArray = range_text.split(",")
		var parsed_range: Dictionary = _parse_range_parts(range_parts)
		if parsed_range.is_empty():
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ Range is a max (e.g. 200), or min, max, step (e.g. 0, 100, 1)."
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
		attributes["range"] = parsed_range
	if _attr_multiline_check.button_pressed and type_name == "String":
		attributes["multiline"] = true
	if _attr_no_alpha_check.button_pressed and type_name == "Color":
		attributes["no_alpha"] = true
	if _attr_exp_easing_check.button_pressed and type_name == "float":
		attributes["exp_easing"] = true
	var placeholder_text: String = _attr_placeholder_edit.text.strip_edges()
	if not placeholder_text.is_empty() and not placeholder_text.contains("\"") and type_name == "String":
		attributes["placeholder"] = placeholder_text
	_fold_look_attributes(attributes, type_name)
	for conditional in [["show_if", _attr_show_if_edit], ["lock_unless", _attr_lock_unless_edit], ["on_changed", _attr_on_changed_edit]]:
		var conditional_value: String = (conditional[1] as LineEdit).text.strip_edges()
		if conditional_value.is_empty():
			continue
		if not EventSheetIdentifierRules.is_valid(conditional_value):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ %s must be a single identifier (a variable/function name)." % str(conditional[0]).capitalize()
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
		attributes[conditional[0]] = conditional_value
	# Clamp/drawer are numeric-only and hidden otherwise: inert when not numeric.
	if _attr_clamp_check.button_pressed and is_numeric:
		if not attributes.has("range"):
			if _default_help != null:
				_default_help.visible = true
				_default_help.text = "✗ Clamp needs a Range (min, max, step) to clamp to."
			if _dialog.is_inside_tree():
				_dialog.call_deferred("popup_centered", Vector2i(440, 260))
			return
		attributes["clamp"] = true
	if _attr_read_only_check.button_pressed:
		attributes["read_only"] = true
	var drawer_kind: String = _selected_drawer_kind()
	if not drawer_kind.is_empty():
		attributes["drawer"] = drawer_kind
	if drawer_kind == "table":
		var table_columns: Array = _dialog_table_columns()
		if not table_columns.is_empty():
			attributes["table_columns"] = table_columns
	# Toggle buttons consume the Options list: the choices ride the drawer marker INSTEAD of
	# @export_enum (one annotation slot), so the combo list is withheld from the plain path.
	if drawer_kind == "toggle_row" and type_name == "String" and not combo_options.is_empty():
		attributes["toggle_options"] = Array(combo_options)
		combo_options = PackedStringArray()
	variable_confirmed.emit(var_name, type_name, default_value, _scope, _context.duplicate(true), is_constant, exported, combo_options, attributes, false)


## Returns the trimmed text from the name field.
func get_last_name_text() -> String:
	if _name_edit == null:
		return ""
	return _name_edit.text.strip_edges()


## Parses the comma-separated combo options text ("a, b, c").
static func parse_options(raw: String) -> PackedStringArray:
	var options: PackedStringArray = PackedStringArray()
	for entry: String in raw.split(","):
		if not entry.strip_edges().is_empty():
			options.append(entry.strip_edges())
	return options


## The text shown in the Default field for a value - the inverse of _parse_default, and the pair MUST
## round-trip. Containers and the value types (Vector2/Color) use the canonical GDScript literal so
## _parse_default can read them back; str() would give the unparseable "(0, 0)" form, silently zeroing the
## first component on the next edit. null (a resource default) shows as an empty field, not the literal
## "<null>". A test pins `_parse_default(type, _default_display_text(v)) == v`.
static func _default_display_text(value: Variant) -> String:
	if value == null:
		return ""
	if value is Array or value is Dictionary or value is Vector2 or value is Color:
		return SheetCompiler._to_code_literal(value)
	return str(value)


static func _parse_default(type_name: String, raw: String) -> Variant:
	var value: String = raw.strip_edges()
	if is_collection_type(type_name):
		if value.is_empty():
			return {} if type_name.begins_with("Dictionary") else []
		var parsed: Variant = str_to_var(value)
		if parsed is Array or parsed is Dictionary:
			return parsed
		return {} if type_name.begins_with("Dictionary") else []
	match type_name:
		"int":
			return int(value) if not value.is_empty() else 0
		"float":
			return float(value) if not value.is_empty() else 0.0
		"bool":
			return value.to_lower() in ["true", "1", "yes"]
		"String":
			return value
		"Vector2":
			if value.begins_with("Vector2(") and value.ends_with(")"):
				var literal_v: Variant = str_to_var(value)
				return literal_v if literal_v is Vector2 else Vector2.ZERO
			var xy: PackedStringArray = value.split(",")
			return Vector2(xy[0].strip_edges().to_float(), xy[1].strip_edges().to_float()) if xy.size() == 2 else Vector2.ZERO
		"Color":
			if value.begins_with("Color(") and value.ends_with(")"):
				var literal_c: Variant = str_to_var(value)
				return literal_c if literal_c is Color else Color.WHITE
			if value.begins_with("#"):
				return Color.from_string(value, Color.WHITE)
			var rgba: PackedStringArray = value.split(",")
			if rgba.size() >= 3:
				return Color(rgba[0].strip_edges().to_float(), rgba[1].strip_edges().to_float(), rgba[2].strip_edges().to_float(), rgba[3].strip_edges().to_float() if rgba.size() >= 4 else 1.0)
			return Color.WHITE
		"Texture2D", "Curve":
			# Resource-typed exports default to null; the value is assigned in the Inspector (or via a drawer).
			return null
		_:
			return value


static func is_collection_type(type_name: String) -> bool:
	return type_name.begins_with("Array") or type_name.begins_with("Dictionary")


## Validates a default-value text against the chosen type ({ok, error}). Collections must
## be GDScript literals of the right container kind; typed containers (Array[T] /
## Dictionary[K, V]) also check element types when T is a builtin scalar.
static func validate_default(type_name: String, raw: String) -> Dictionary:
	var value: String = raw.strip_edges()
	if not is_collection_type(type_name) or value.is_empty():
		return {"ok": true, "error": ""}
	var parsed: Variant = str_to_var(value)
	var wants_dictionary: bool = type_name.begins_with("Dictionary")
	if parsed == null or (wants_dictionary and not (parsed is Dictionary)) or (not wants_dictionary and not (parsed is Array)):
		return {"ok": false, "error": "Not a valid %s literal - e.g. %s" % [
			"Dictionary" if wants_dictionary else "Array",
			"{\"key\": 1}" if wants_dictionary else "[1, 2, 3]"
		]}
	var element_type: String = ""
	if type_name.contains("[") and type_name.ends_with("]"):
		var inner: String = type_name.get_slice("[", 1).trim_suffix("]")
		element_type = inner.get_slice(",", 1).strip_edges() if wants_dictionary else inner.strip_edges()
	var scalar_checks: Dictionary = {"int": TYPE_INT, "float": TYPE_FLOAT, "String": TYPE_STRING, "bool": TYPE_BOOL}
	if scalar_checks.has(element_type):
		var expected_type: int = int(scalar_checks[element_type])
		var values: Array = (parsed as Dictionary).values() if wants_dictionary else (parsed as Array)
		for element: Variant in values:
			# int literals are valid floats in GDScript.
			if typeof(element) == TYPE_INT and expected_type == TYPE_FLOAT:
				continue
			if typeof(element) != expected_type:
				return {"ok": false, "error": "Element %s is not %s (declared %s)." % [str(element), element_type, type_name]}
	return {"ok": true, "error": ""}


## Live ✓/✗ hint under the default field while typing collection literals.
## Show fields only when they can apply (user call: don't throw everything at once):
## combo options are String-only, range/clamp/drawer are numeric, multiline is String.
func _refresh_contextual_rows() -> void:
	if _type_option == null or _options_row == null:
		return
	var type_name: String = _selected_stored_type()
	var numeric: bool = type_name in ["int", "float"]
	_options_row.visible = type_name == "String"
	_enum_fill_menu.visible = _options_row.visible and _enum_provider.is_valid() and not (_enum_provider.call() as Array).is_empty()
	if _attr_range_edit != null:
		# Range now lives in a labelled row - hide the whole row, not just the field, so its
		# "Range" label doesn't linger on non-numeric types. Vector2 keeps it too: its max drives the dial.
		_attr_range_edit.get_parent().visible = numeric or type_name == "Vector2"
		# For a Vector2 the Range is just the dial's reach (only max is read), so prompt for one number, not the
		# numeric "min, max, step" - the forgiving parser accepts a bare max.
		_attr_range_edit.placeholder_text = _RANGE_PLACEHOLDER_VECTOR2 if type_name == "Vector2" else _RANGE_PLACEHOLDER_NUMERIC
		_attr_clamp_check.visible = numeric
		_attr_multiline_check.visible = type_name == "String"
		_attr_no_alpha_check.visible = type_name == "Color"
		_attr_exp_easing_check.visible = type_name == "float"
		_attr_placeholder_row.visible = type_name == "String"
	if _attr_range_modifier_row != null:
		_attr_range_modifier_row.visible = numeric
	_rebuild_look_options(type_name)
	# The drawer picker offers the drawers the current type can host (or hides when there are none).
	_rebuild_drawer_options(_drawer_kinds_for_type(type_name))
	_refresh_drawer_preview()
	_refresh_clamp_gate()
	_refresh_ships_as()


## Rebuilds the look picker for the current type, keeping the selection when it still applies.
## The preset table + type filter live in EventSheetInspectorLooks, shared with the gallery.
func _rebuild_look_options(type_name: String) -> void:
	if _attr_look_option == null:
		return
	var previous: String = _selected_look_id()
	_attr_look_option.clear()
	_attr_look_option.add_item("Default field")
	_attr_look_option.set_item_metadata(0, "")
	for preset: Dictionary in EventSheetInspectorLooks.for_type(type_name):
		_attr_look_option.add_item(str(preset.get("label")))
		_attr_look_option.set_item_metadata(_attr_look_option.item_count - 1, str(preset.get("id")))
	for index: int in range(_attr_look_option.item_count):
		if str(_attr_look_option.get_item_metadata(index)) == previous:
			_attr_look_option.select(index)
			break
	_attr_look_option.get_parent().get_parent().visible = _attr_look_option.item_count > 1
	_refresh_look_detail()


func _selected_look_id() -> String:
	if _attr_look_option == null or _attr_look_option.selected < 0:
		return ""
	return str(_attr_look_option.get_item_metadata(_attr_look_option.selected))


## Shows the one contextual field the selected look needs (filters / labels / node types).
func _refresh_look_detail() -> void:
	if _attr_look_detail_row == null:
		return
	var preset: Dictionary = EventSheetInspectorLooks.preset_by_id(_selected_look_id())
	var detail: String = str(preset.get("detail", ""))
	_attr_look_detail_row.visible = not detail.is_empty()
	if not detail.is_empty():
		_attr_look_detail_edit.placeholder_text = detail


## "Browse..." opens the picture-tile gallery; a chosen tile drives the SAME dropdown
## (select + the same refreshes), so the fold/apply path stays single no matter how
## the look was picked.
func _open_look_gallery() -> void:
	if _look_gallery == null:
		_look_gallery = EventSheetLookGalleryDialog.new()
		_dialog.add_child(_look_gallery)
		_look_gallery.look_chosen.connect(_on_gallery_look_chosen)
	_look_gallery.open_for_type(_selected_stored_type(), _selected_look_id())


func _on_gallery_look_chosen(look_id: String) -> void:
	if _attr_look_option == null:
		return
	for index: int in range(_attr_look_option.item_count):
		if str(_attr_look_option.get_item_metadata(index)) == look_id:
			_attr_look_option.select(index)
			break
	_refresh_look_detail()
	_refresh_ships_as()
	# A look that needs details (flag labels, file filters) lands ready to type.
	if _attr_look_detail_row != null and _attr_look_detail_row.visible and _attr_look_detail_edit != null:
		_attr_look_detail_edit.grab_focus()


## Folds the look picker + range modifiers into the attributes dict - the SAME keys the
## compiler reads in _structured_hint_prefix, so the dialog and emission can never disagree.
func _fold_look_attributes(attributes: Dictionary, type_name: String) -> void:
	var numeric: bool = type_name == "int" or type_name == "float"
	if attributes.get("range") is Dictionary and numeric:
		var range_spec: Dictionary = attributes.get("range")
		if _attr_or_greater_check != null and _attr_or_greater_check.button_pressed:
			range_spec["or_greater"] = true
		if _attr_or_less_check != null and _attr_or_less_check.button_pressed:
			range_spec["or_less"] = true
		var suffix: String = _attr_suffix_edit.text.strip_edges() if _attr_suffix_edit != null else ""
		if not suffix.is_empty() and not suffix.contains("\""):
			range_spec["suffix"] = suffix
	var detail: String = _attr_look_detail_edit.text.strip_edges() if _attr_look_detail_edit != null else ""
	match _selected_look_id():
		"file", "global_file":
			if type_name == "String":
				var file_spec: Dictionary = {"mode": "file", "global": _selected_look_id() == "global_file"}
				var filters: Array = []
				for filter_text: String in detail.split(",", false):
					if not filter_text.strip_edges().is_empty():
						filters.append(filter_text.strip_edges())
				if not filters.is_empty():
					file_spec["filters"] = filters
				attributes["file"] = file_spec
		"dir", "global_dir":
			if type_name == "String":
				attributes["file"] = {"mode": "dir", "global": _selected_look_id() == "global_dir"}
		"flags":
			if type_name == "int":
				attributes["flags"] = _parse_look_labels(detail)
		"enum_values":
			if type_name == "int":
				attributes["enum_values"] = _parse_look_labels(detail)
		"node_path":
			if type_name == "NodePath":
				var node_types: Array = []
				for type_text: String in detail.split(",", false):
					if not type_text.strip_edges().is_empty():
						node_types.append(type_text.strip_edges())
				if not node_types.is_empty():
					attributes["node_path_types"] = node_types
		"suggestions":
			if type_name == "String":
				var suggestion_entries: Array = []
				for suggestion_text: String in detail.split(",", false):
					if not suggestion_text.strip_edges().is_empty():
						suggestion_entries.append(suggestion_text.strip_edges())
				if not suggestion_entries.is_empty():
					attributes["suggestions"] = suggestion_entries
		"storage":
			attributes["storage"] = true
		"preset_password":
			if type_name == "String":
				attributes["custom_preset"] = "password"
		"preset_expression":
			if type_name == "String":
				attributes["custom_preset"] = "expression"
		"preset_link":
			attributes["custom_preset"] = "link"
		"easing_attenuation":
			if type_name == "float":
				attributes["exp_easing"] = true
				attributes["exp_easing_flags"] = ["attenuation"]
		"easing_positive":
			if type_name == "float":
				attributes["exp_easing"] = true
				attributes["exp_easing_flags"] = ["positive_only"]
		_:
			if _selected_look_id().begins_with("layers_") and type_name == "int":
				attributes["layers"] = _selected_look_id().trim_prefix("layers_")


## "Fire:1, Ice" -> [{label, value}] (value stays a string; empty = auto).
static func _parse_look_labels(detail: String) -> Array:
	var entries: Array = []
	for part: String in detail.split(",", false):
		var trimmed: String = part.strip_edges()
		if trimmed.is_empty():
			continue
		var colon: int = trimmed.rfind(":")
		if colon > 0:
			entries.append({"label": trimmed.substr(0, colon).strip_edges(), "value": trimmed.substr(colon + 1).strip_edges()})
		else:
			entries.append({"label": trimmed, "value": ""})
	return entries


## Reselects the look + detail from an edited variable's existing attributes.
func _prefill_look(existing: Dictionary) -> void:
	_rebuild_look_options(_selected_stored_type())
	var look_id: String = ""
	var detail: String = ""
	if bool(existing.get("storage", false)):
		look_id = "storage"
	elif not str(existing.get("custom_preset", "")).is_empty():
		look_id = "preset_%s" % str(existing.get("custom_preset"))
	elif existing.get("exp_easing_flags") is Array and not (existing.get("exp_easing_flags") as Array).is_empty():
		look_id = "easing_attenuation" if (existing.get("exp_easing_flags") as Array).has("attenuation") else "easing_positive"
	elif existing.get("file") is Dictionary:
		var file_spec: Dictionary = existing.get("file")
		var is_global: bool = bool(file_spec.get("global", false))
		look_id = ("global_" if is_global else "") + ("dir" if str(file_spec.get("mode", "file")) == "dir" else "file")
		var filter_parts: PackedStringArray = PackedStringArray()
		for filter_entry: Variant in file_spec.get("filters", []):
			filter_parts.append(str(filter_entry))
		detail = ", ".join(filter_parts)
	elif existing.get("flags") is Array:
		look_id = "flags"
		detail = _look_labels_text(existing.get("flags"))
	elif existing.get("enum_values") is Array:
		look_id = "enum_values"
		detail = _look_labels_text(existing.get("enum_values"))
	elif not str(existing.get("layers", "")).is_empty():
		look_id = "layers_%s" % str(existing.get("layers"))
	elif existing.get("node_path_types") is Array:
		look_id = "node_path"
		var type_parts: PackedStringArray = PackedStringArray()
		for type_entry: Variant in existing.get("node_path_types"):
			type_parts.append(str(type_entry))
		detail = ", ".join(type_parts)
	elif existing.get("suggestions") is Array:
		look_id = "suggestions"
		var suggestion_parts: PackedStringArray = PackedStringArray()
		for suggestion_entry: Variant in existing.get("suggestions"):
			suggestion_parts.append(str(suggestion_entry))
		detail = ", ".join(suggestion_parts)
	for index: int in range(_attr_look_option.item_count):
		if str(_attr_look_option.get_item_metadata(index)) == look_id:
			_attr_look_option.select(index)
			break
	_attr_look_detail_edit.text = detail
	_refresh_look_detail()


static func _look_labels_text(entries: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		if entry is Dictionary:
			var value: String = str((entry as Dictionary).get("value", ""))
			var label: String = str((entry as Dictionary).get("label", ""))
			parts.append(label if value.is_empty() else "%s:%s" % [label, value])
	return ", ".join(parts)


## "Ships as:" - renders the EXACT annotation the current choices compile to, using the
## compiler's own prefix builder as the single source of truth (the ACE Studio pattern).
func _refresh_ships_as() -> void:
	if _ships_as_label == null:
		return
	var type_name: String = _selected_stored_type()
	var preview: Dictionary = {}
	var range_text: String = _attr_range_edit.text.strip_edges() if _attr_range_edit != null else ""
	if not range_text.is_empty() and (type_name == "int" or type_name == "float"):
		var parsed_range: Dictionary = _parse_range_parts(range_text.split(","))
		if not parsed_range.is_empty():
			preview["range"] = parsed_range
	_fold_look_attributes(preview, type_name)
	var prefix: String = SheetCompiler._structured_hint_prefix(preview, type_name)
	if prefix.is_empty():
		if _attr_multiline_check.button_pressed and type_name == "String":
			prefix = "@export_multiline "
		elif _attr_no_alpha_check.button_pressed and type_name == "Color":
			prefix = "@export_color_no_alpha "
		elif _attr_exp_easing_check.button_pressed and type_name == "float":
			prefix = "@export_exp_easing "
		elif not _attr_placeholder_edit.text.strip_edges().is_empty() and type_name == "String":
			prefix = "@export_placeholder(\"%s\") " % _attr_placeholder_edit.text.strip_edges()
		else:
			prefix = "@export "
	var shown_name: String = "value"
	if _name_edit != null and not _name_edit.text.strip_edges().is_empty():
		shown_name = _name_edit.text.strip_edges()
	_ships_as_label.text = "Ships as:  %svar %s: %s" % [prefix, shown_name, type_name]
	_refresh_inspector_preview(shown_name, type_name, preview)


## The preview card rides the exact triggers (and folded attributes) of the "Ships as:"
## strip, then layers on the tiers the strip does not need: checkboxes, drawer, grouping.
func _refresh_inspector_preview(shown_name: String, type_name: String, folded_attributes: Dictionary) -> void:
	if _inspector_preview_card == null:
		return
	var card_attributes: Dictionary = folded_attributes.duplicate(true)
	if _attr_multiline_check != null and _attr_multiline_check.button_pressed and type_name == "String":
		card_attributes["multiline"] = true
	if _attr_no_alpha_check != null and _attr_no_alpha_check.button_pressed and type_name == "Color":
		card_attributes["no_alpha"] = true
	if _attr_exp_easing_check != null and _attr_exp_easing_check.button_pressed and type_name == "float":
		card_attributes["exp_easing"] = true
	if _attr_placeholder_edit != null and not _attr_placeholder_edit.text.strip_edges().is_empty() and type_name == "String":
		card_attributes["placeholder"] = _attr_placeholder_edit.text.strip_edges()
	var drawer_kind: String = _selected_drawer_kind()
	if not drawer_kind.is_empty():
		card_attributes["drawer"] = drawer_kind
	if drawer_kind == "table" and not _dialog_table_columns().is_empty():
		card_attributes["table_columns"] = _dialog_table_columns()
	if _attr_group_edit != null and not _attr_group_edit.text.strip_edges().is_empty():
		card_attributes["group"] = _attr_group_edit.text.strip_edges()
	if _attr_subgroup_edit != null and not _attr_subgroup_edit.text.strip_edges().is_empty():
		card_attributes["subgroup"] = _attr_subgroup_edit.text.strip_edges()
	card_attributes.merge(_decor_attributes(), true)
	if _attr_clamp_check != null and _attr_clamp_check.button_pressed:
		card_attributes["clamp"] = true
	if _attr_read_only_check != null and _attr_read_only_check.button_pressed:
		card_attributes["read_only"] = true
	var default_text: String = _default_edit.text.strip_edges() if _default_edit != null else ""
	var exported: bool = _exported_check != null and _exported_check.button_pressed
	var constant: bool = _const_check != null and _const_check.button_pressed
	_inspector_preview_card.update_preview(shown_name, type_name, default_text, card_attributes, exported, constant)


## The drawer kinds a variable type can host (empty for most types). Vector2 hosts two: a direction
## dial (the vector as an arrow) and a min-max range slider (x = low end, y = high end).
static func _drawer_kinds_for_type(type_name: String) -> PackedStringArray:
	match type_name:
		"int", "float":
			return PackedStringArray(["progress_bar"])
		"Vector2":
			return PackedStringArray(["vector_dial", "min_max"])
		"Array":
			return PackedStringArray(["table"])
		"String":
			return PackedStringArray(["toggle_row"])
		"Color":
			return PackedStringArray(["swatch_row"])
		"Texture2D":
			return PackedStringArray(["texture_preview"])
		"Curve":
			return PackedStringArray(["curve_editor"])
	return PackedStringArray()


## Human label for the drawer option entry.
static func _drawer_label_for_kind(kind: String) -> String:
	match kind:
		"progress_bar":
			return "Progress bar"
		"vector_dial":
			return "Direction dial"
		"min_max":
			return "Min-max range"
		"table":
			return "Editable table"
		"toggle_row":
			return "Toggle buttons (uses Options)"
		"swatch_row":
			return "Swatch row"
		"texture_preview":
			return "Texture preview"
		"curve_editor":
			# "preview", not "editor": the drawer renders + picks a Curve; you shape its points in Godot's
			# stock Curve editor after assigning. The label shouldn't promise in-place point editing.
			return "Curve preview"
	return ""


## The table columns typed in the dialog ("item:String, count:int" - colon syntax, matching the
## flags/enum detail fields), as the same {name, type} entries the compiler emits. Missing types
## default to String; the marker-side parser (attribute_drawers) uses "=" pairs instead.
func _dialog_table_columns() -> Array:
	if _attr_table_columns_edit == null:
		return []
	var columns: Array = []
	for pair: String in _attr_table_columns_edit.text.split(",", false):
		var trimmed: String = pair.strip_edges()
		if trimmed.is_empty():
			continue
		var colon: int = trimmed.rfind(":")
		var column_name: String = (trimmed.substr(0, colon) if colon > 0 else trimmed).strip_edges()
		var column_type: String = trimmed.substr(colon + 1).strip_edges() if colon > 0 else "String"
		if column_name.is_empty():
			continue
		if not column_type in ["String", "int", "float", "bool"]:
			column_type = "String"
		columns.append({"name": column_name, "type": column_type})
	return columns


## The decor attributes from the Section header / Info note fields. The header field accepts an
## optional trailing #rrggbb accent ("Combat #e06666"), split here with the same rule the importer
## uses, so what you type is exactly what a reopened variable shows.
func _decor_attributes() -> Dictionary:
	var decor: Dictionary = {}
	var header: String = _attr_header_edit.text.strip_edges() if _attr_header_edit != null else ""
	if not header.is_empty():
		var tokens: PackedStringArray = header.split(" ")
		var last: String = tokens[tokens.size() - 1] if tokens.size() > 1 else ""
		if last.length() == 7 and last.begins_with("#") and last.substr(1).is_valid_hex_number():
			decor["header_color"] = last
			header = header.substr(0, header.length() - last.length()).strip_edges()
		if not header.is_empty():
			decor["header"] = header
	var info: String = _attr_info_edit.text.strip_edges() if _attr_info_edit != null else ""
	if not info.is_empty():
		decor["info"] = info
	if _attr_required_check != null and _attr_required_check.button_pressed:
		decor["required"] = true
	var validate_function: String = _attr_validate_edit.text.strip_edges() if _attr_validate_edit != null else ""
	if validate_function.is_valid_identifier():
		decor["validate"] = validate_function
	var action_spec: String = _attr_action_edit.text.strip_edges() if _attr_action_edit != null else ""
	if not action_spec.is_empty():
		var first_space: int = action_spec.find(" ")
		var action_function: String = action_spec.substr(0, first_space) if first_space > 0 else action_spec
		if action_function.is_valid_identifier():
			decor["action"] = action_function
			if first_space > 0 and not action_spec.substr(first_space + 1).strip_edges().is_empty():
				decor["action_label"] = action_spec.substr(first_space + 1).strip_edges()
	return decor


## The drawer kind currently chosen in the dialog ("" = Default field).
func _selected_drawer_kind() -> String:
	if _attr_drawer_option == null or _attr_drawer_option.selected <= 0:
		return ""
	var meta: Variant = _attr_drawer_option.get_item_metadata(_attr_drawer_option.selected)
	return str(meta) if meta != null else ""


## Rebuilds the drawer OptionButton to offer Default + every drawer the type hosts, preserving the current
## choice when it is still offered so a refresh doesn't silently reset the user's selection.
func _rebuild_drawer_options(kinds: PackedStringArray) -> void:
	if _attr_drawer_option == null:
		return
	var previous: String = _selected_drawer_kind()
	_attr_drawer_option.clear()
	_attr_drawer_option.add_item("Default field")
	for kind: String in kinds:
		_attr_drawer_option.add_item(_drawer_label_for_kind(kind))
		_attr_drawer_option.set_item_metadata(_attr_drawer_option.item_count - 1, kind)
	# Hide the whole "Show as" row (label + option) for types with no drawer, not just the OptionButton.
	var show_row: Node = _attr_drawer_option.get_parent()
	if show_row is Control:
		(show_row as Control).visible = not kinds.is_empty()
	_select_drawer_kind(previous)


## Selects the option whose metadata matches `kind` (Default when absent) - shared by the rebuild's
## choice-preserve and the reopen path, so both survive a type hosting more than one drawer.
func _select_drawer_kind(kind: String) -> void:
	for i: int in range(1, _attr_drawer_option.item_count):
		if str(_attr_drawer_option.get_item_metadata(i)) == kind:
			_attr_drawer_option.select(i)
			return
	_attr_drawer_option.select(0)


## Forgiving Range parse, shared by the apply (_on_confirmed) and the preview (_parse_range_bounds) so they
## never disagree: 1 part = max (min 0, step 1); 2 = min, max (step 1); 3 = min, max, step. Returns {} (an
## error) only for 0 or >3 parts, or a blank max. The drawer/marker reads only min & max.
static func _parse_range_parts(parts: PackedStringArray) -> Dictionary:
	var trimmed: PackedStringArray = PackedStringArray()
	for part: String in parts:
		trimmed.append(part.strip_edges())
	match trimmed.size():
		1:
			return {} if trimmed[0].is_empty() else {"min": "0", "max": trimmed[0], "step": "1"}
		2:
			return {} if trimmed[1].is_empty() else {"min": trimmed[0] if not trimmed[0].is_empty() else "0", "max": trimmed[1], "step": "1"}
		3:
			return {} if trimmed[1].is_empty() else {"min": trimmed[0] if not trimmed[0].is_empty() else "0", "max": trimmed[1], "step": trimmed[2] if not trimmed[2].is_empty() else "1"}
	return {}


## {min, max} (as floats) parsed from the Range field - drives the progress_bar / dial bounds in the preview,
## using the SAME forgiving rule as the apply so a 1-part "150" reads as max 150 in both.
func _parse_range_bounds() -> Dictionary:
	if _attr_range_edit == null:
		return {"min": 0.0, "max": 100.0}
	var parsed: Dictionary = _parse_range_parts(_attr_range_edit.text.split(","))  # allow_empty: positions preserved (see _on_confirmed)
	if parsed.is_empty():
		return {"min": 0.0, "max": 100.0}
	return {"min": str(parsed.get("min", "0")).to_float(), "max": str(parsed.get("max", "100")).to_float()}


## Compact display of a numeric bound: drop a trailing ".0" so 150.0 reads "150", but keep 1.5 as "1.5".
static func _format_bound(value: float) -> String:
	# 0.001 is a cosmetic "close enough to whole" tolerance - display-only, never used for storage or compares.
	return str(int(round(value))) if absf(value - round(value)) < 0.001 else str(value)


## Pre-validate the Clamp↔Range dependency: Clamp needs a min+max to
## clamp to, so disable the checkbox (with a hint) until a valid Range is entered - making the dependency
## visible BEFORE confirm instead of erroring on OK. No-op when Clamp is hidden (non-numeric types).
func _refresh_clamp_gate() -> void:
	if _attr_clamp_check == null or not _attr_clamp_check.visible:
		return
	var has_range: bool = _attr_range_edit != null and not _parse_range_parts(_attr_range_edit.text.split(",")).is_empty()
	_attr_clamp_check.disabled = not has_range
	if has_range:
		_attr_clamp_check.tooltip_text = "Clamp the value to the Range on every assignment."
	else:
		_attr_clamp_check.set_pressed_no_signal(false)
		_attr_clamp_check.tooltip_text = "Enter a Range (a max, or min, max) above first - Clamp keeps the value inside it."


## Rebuilds the live preview to show the actual drawer widget (display-only) at a representative value.
func _refresh_drawer_preview() -> void:
	if _drawer_preview_box == null:
		return
	for child: Node in _drawer_preview_box.get_children():
		child.queue_free()
	var kind: String = _selected_drawer_kind()
	# The Columns row only matters while the table drawer is chosen; it hides with it.
	if _attr_table_columns_edit != null and _attr_table_columns_edit.get_parent() is Control:
		(_attr_table_columns_edit.get_parent() as Control).visible = kind == "table"
	if kind.is_empty():
		_drawer_preview_box.visible = false
		return
	_drawer_preview_box.visible = true
	var caption: Label = Label.new()
	# Surface the one bound that matters next to the preview, so the link between the distant "Range" field and
	# the dial's reach / the bar's span is visible instead of hidden.
	var bounds: Dictionary = _parse_range_bounds()
	match kind:
		"vector_dial":
			caption.text = "Drawer preview · reach %s" % _format_bound(bounds["max"])
		"progress_bar", "min_max":
			caption.text = "Drawer preview · %s–%s" % [_format_bound(bounds["min"]), _format_bound(bounds["max"])]
		_:
			caption.text = "Drawer preview"
	caption.add_theme_font_size_override("font_size", 10)
	caption.modulate = Color(0.72, 0.76, 0.84)
	_drawer_preview_box.add_child(caption)
	var widget: Control = _make_drawer_preview_widget(kind)
	if widget != null:
		_drawer_preview_box.add_child(widget)


## Instantiates a reusable drawer widget for the preview, sized/valued so the user sees what it looks like.
func _make_drawer_preview_widget(kind: String) -> Control:
	var bounds: Dictionary = _parse_range_bounds()
	match kind:
		"progress_bar":
			var bar: EventSheetDrawerWidgets.DrawerProgressBar = EventSheetDrawerWidgets.DrawerProgressBar.new(bounds["min"], bounds["max"])
			bar.editable = false
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.set_value(lerpf(bounds["min"], bounds["max"], 0.65))
			return bar
		"min_max":
			var slider: EventSheetDrawerWidgets.DrawerMinMaxSlider = EventSheetDrawerWidgets.DrawerMinMaxSlider.new(bounds["min"], bounds["max"])
			slider.editable = false
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.set_value(Vector2(lerpf(bounds["min"], bounds["max"], 0.25), lerpf(bounds["min"], bounds["max"], 0.75)))
			return slider
		"toggle_row":
			var toggle_options: PackedStringArray = parse_options(_options_edit.text if _options_edit != null else "")
			if toggle_options.is_empty():
				toggle_options = PackedStringArray(["easy", "normal", "hard"])
			var toggle_widget: EventSheetDrawerWidgets.DrawerToggleRow = EventSheetDrawerWidgets.DrawerToggleRow.new(toggle_options)
			toggle_widget.editable = false
			toggle_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			toggle_widget.set_value(toggle_options[0])
			return toggle_widget
		"table":
			var columns: Array = _dialog_table_columns()
			if columns.is_empty():
				columns = [{"name": "item", "type": "String"}, {"name": "count", "type": "int"}]
			var table: EventSheetDrawerWidgets.DrawerTable = EventSheetDrawerWidgets.DrawerTable.new(columns)
			table.editable = false
			table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sample_row: Dictionary = {}
			for column: Dictionary in columns:
				sample_row[str(column.get("name"))] = EventSheetDrawerWidgets.DrawerTable._default_for(str(column.get("type", "String")))
			table.set_value([sample_row])
			return table
		"vector_dial":
			var dial: EventSheetDrawerWidgets.DrawerVectorDial = EventSheetDrawerWidgets.DrawerVectorDial.new(bounds["max"])
			dial.editable = false
			dial.set_value(Vector2(bounds["max"] * 0.5, -bounds["max"] * 0.3))
			return dial
		"swatch_row":
			var row: EventSheetDrawerWidgets.DrawerSwatchRow = EventSheetDrawerWidgets.DrawerSwatchRow.new()
			row.editable = false
			row.set_value(Color("#e23b3b"))
			return row
		"texture_preview":
			return EventSheetDrawerWidgets.DrawerTexturePreview.new()
		"curve_editor":
			var cw: EventSheetDrawerWidgets.DrawerCurvePreview = EventSheetDrawerWidgets.DrawerCurvePreview.new()
			cw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return cw
	return null


## Wires the sheet-enum source for the one-click combo fill (returns
## Array[Dictionary{name, members}]).
## The dock injects the active sheet so the name field can check host-member shadowing.
func set_sheet_provider(provider: Callable) -> void:
	_sheet_provider = provider


## Owner class if `var_name` shadows a host-class member (method/signal/constant/property),
## else "". Drives the live name warning + the confirm-time block.
func _shadow_owner(var_name: String) -> String:
	if not _sheet_provider.is_valid():
		return ""
	var sheet: EventSheetResource = _sheet_provider.call() as EventSheetResource
	if sheet == null:
		return ""
	return EventSheetProjectDoctor.shadowed_member_class(sheet, var_name.strip_edges())


## Live feedback: shows/hides the shadow warning as the user types the name.
func _refresh_name_warning() -> void:
	if _name_warning == null:
		return
	var owner: String = _shadow_owner(_name_edit.text)
	if owner.is_empty():
		_name_warning.visible = false
	else:
		_name_warning.visible = true
		_name_warning.text = "⚠ \"%s\" shadows a %s member - rename to avoid a clash." % [_name_edit.text.strip_edges(), owner]


func set_enum_provider(provider: Callable) -> void:
	_enum_provider = provider


func _populate_enum_fill_menu() -> void:
	var popup: PopupMenu = _enum_fill_menu.get_popup()
	popup.clear()
	if not _enum_provider.is_valid():
		return
	for entry: Variant in (_enum_provider.call() as Array):
		if not (entry is Dictionary):
			continue
		var members: PackedStringArray = PackedStringArray()
		for member: Variant in (entry as Dictionary).get("members", []):
			# Members may carry explicit values ("HURT = 4") - the combo wants names.
			members.append(str(member).get_slice("=", 0).strip_edges())
		popup.add_item(str((entry as Dictionary).get("name", "")))
		popup.set_item_metadata(popup.item_count - 1, ", ".join(members))


func _refresh_default_hint() -> void:
	if _default_help == null or _type_option == null or _default_edit == null:
		return
	var type_name: String = _selected_stored_type()
	if not is_collection_type(type_name):
		_default_help.visible = false
		# Resource-typed exports have no literal default (they're assigned in the Inspector), so don't suggest "0".
		_default_edit.placeholder_text = "(none)" if type_name in ["Texture2D", "Curve"] else "0"
		return
	_default_edit.placeholder_text = "{\"key\": 1}" if type_name.begins_with("Dictionary") else "[1, 2, 3]"
	if _default_edit.text.strip_edges().is_empty():
		_default_help.visible = false
		return
	var verdict: Dictionary = validate_default(type_name, _default_edit.text)
	_default_help.visible = true
	_default_help.text = "✓ literal OK" if bool(verdict.get("ok", false)) else "✗ %s" % str(verdict.get("error", ""))


func _refresh_const_ui() -> void:
	if _const_check == null or _const_help == null or _type_option == null:
		return
	var type_name: String = _selected_stored_type()
	var supports_const: bool = _supports_constant(type_name)
	_const_check.disabled = not supports_const
	if not supports_const:
		_const_check.button_pressed = false
	_const_help.visible = not supports_const
	_const_help.text = "Const is unavailable for Variant variables."


func _supports_constant(type_name: String) -> bool:
	return type_name != "Variant"
