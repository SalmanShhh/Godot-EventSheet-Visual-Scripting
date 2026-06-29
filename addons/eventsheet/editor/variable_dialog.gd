# EventSheet — Variable creation dialog component
# Provides a reusable form for creating global or local variables.
# Connect to variable_confirmed to receive the result.
@tool
class_name VariableDialog
extends RefCounted

## Emitted when the user confirms variable creation or editing.
## scope is "global" or "local". exported = accessible outside the generated script
## (@export var) vs. private (var).
signal variable_confirmed(name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary, is_constant: bool, exported: bool, options: PackedStringArray, attributes: Dictionary)

var _dialog: ConfirmationDialog = null
var _scope_label: Label = null
var _name_edit: LineEdit = null
var _name_warning: Label = null
var _sheet_provider: Callable = Callable()
var _type_option: OptionButton = null
var _default_edit: LineEdit = null
var _items_button: Button = null
var _items_window: Window = null
var _items_edit: TextEdit = null
var _const_check: CheckBox = null
var _exported_check: CheckBox = null
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
# A second, nested disclosure inside _attr_section: the "Advanced" tier holds the wiring/organizational
# attributes (grouping, show-if/lock-unless/on-changed, clamp, read-only) so the Basic tier (tooltip, range,
# drawer, multiline) reads first. See docs/PROGRESSIVE-DISCLOSURE-SPEC.md.
var _attr_advanced_toggle: Button = null
var _attr_advanced_section: VBoxContainer = null
## Attribute keys whose fields live in the nested Advanced tier. MUST mirror the fields parented under
## _attr_advanced_section in init_dialog — if you move a field between the Basic and Advanced tiers, update
## this too, or open_for_edit's auto-expand will disagree with where the field actually sits.
const _ADVANCED_ATTR_KEYS: Array[String] = ["group", "subgroup", "show_if", "lock_unless", "on_changed", "clamp", "read_only"]
## The Range field's placeholder per type — one source of truth so the initial build and the per-type swap in
## _refresh_contextual_rows can't drift. Vector2 prompts a single dial reach; numeric prompts min, max, step.
const _RANGE_PLACEHOLDER_NUMERIC: String = "min, max, step (numeric: slider)"
const _RANGE_PLACEHOLDER_VECTOR2: String = "max reach — the dial's magnitude (e.g. 150)"
var _attr_tooltip_edit: LineEdit = null
var _attr_group_edit: LineEdit = null
var _attr_subgroup_edit: LineEdit = null
var _attr_range_edit: LineEdit = null
var _attr_multiline_check: CheckBox = null
var _attr_show_if_edit: LineEdit = null
var _attr_lock_unless_edit: LineEdit = null
var _attr_on_changed_edit: LineEdit = null
var _attr_clamp_check: CheckBox = null
var _attr_read_only_check: CheckBox = null
var _attr_drawer_option: OptionButton = null
var _drawer_preview_box: VBoxContainer = null

## Offered types. Collections accept GDScript literal defaults ({"key": 1}, [1, 2]) with
## live validation; typed containers (Godot 4 Array[T] / Dictionary[K, V]) also check
## element types for builtin T.
const TYPE_OPTIONS: PackedStringArray = [
	"int", "float", "bool", "String",
	# Common game-value types — also the hosts for the Tier 3 drawers (dial / swatches / texture / curve).
	"Vector2", "Color", "Texture2D", "Curve",
	"Variant",
	"Array", "Array[int]", "Array[float]", "Array[String]",
	"Dictionary", "Dictionary[String, int]", "Dictionary[String, float]",
	"Dictionary[String, String]", "Dictionary[String, Variant]"
]

## Plain-language hover hints for the Type dropdown, in terms a Construct 3 migrant already owns (C3 has only
## Number / Text / Boolean). The stored type name is unchanged — these are on-demand explanations, not renames.
const TYPE_HINTS: Dictionary = {
	"int": "A whole number, no decimals (like a C3 Number used for a count or score).",
	"float": "A number that can have decimals — the everyday C3 Number.",
	"bool": "Yes / no, on / off (true / false) — a C3 Boolean.",
	"String": "Text — a C3 String.",
	"Vector2": "An x/y pair: a direction, velocity, or position.",
	"Color": "An RGBA colour.",
	"Texture2D": "An image / sprite resource.",
	"Curve": "A shape over 0–1 (easing, falloff, ramps).",
	"Variant": "Any type — untyped (advanced; prefer a specific type when you can).",
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
	for option: String in TYPE_OPTIONS:
		_type_option.add_item(option)
		# C3-friendly hover hints, on demand (docs/PROGRESSIVE-DISCLOSURE-SPEC.md): a Construct migrant has no
		# model for int-vs-float or Variant, so each type explains itself in plain terms without renaming it.
		if TYPE_HINTS.has(option):
			_type_option.set_item_tooltip(_type_option.item_count - 1, str(TYPE_HINTS[option]))
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.item_selected.connect(func(_index: int) -> void:
		_refresh_const_ui()
		_refresh_default_hint()
		_refresh_contextual_rows()
		_refresh_items_button()
	)
	type_row.add_child(_type_option)
	form.add_child(type_row)

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
	# Inspector attributes behind a disclosure ("More options") — the dialog used to throw everything at once.
	# Collapsed for new variables, auto-expanded when an edited variable already uses an attribute. Exported
	# globals only. Progressive disclosure: docs/PROGRESSIVE-DISCLOSURE-SPEC.md.
	_attr_toggle = Button.new()
	_attr_toggle.flat = true
	_attr_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_attr_toggle.toggle_mode = true
	_attr_toggle.text = "▸  More options (tooltip, range, drawer…)"
	_attr_toggle.tooltip_text = "Optional Inspector polish for exported globals — everything compiles to plain Godot annotations."
	_attr_toggle.toggled.connect(func(expanded: bool) -> void:
		_attr_toggle.text = ("▾" if expanded else "▸") + _attr_toggle.text.substr(1)
		_attr_section.visible = expanded)
	form.add_child(_attr_toggle)
	_attr_section = VBoxContainer.new()
	_attr_section.visible = false
	form.add_child(_attr_section)
	# ── BASIC tier: the friendly polish a designer reaches for first ──
	_attr_tooltip_edit = LineEdit.new()
	_attr_tooltip_edit.placeholder_text = "shown when hovering the property"
	_attr_section.add_child(EventSheetPopupUI.form_row("Tooltip", _attr_tooltip_edit))
	_attr_range_edit = LineEdit.new()
	_attr_range_edit.placeholder_text = _RANGE_PLACEHOLDER_NUMERIC
	_attr_range_edit.text_changed.connect(func(_t: String) -> void:
		_refresh_drawer_preview()
		_refresh_clamp_gate())
	_attr_section.add_child(EventSheetPopupUI.form_row("Range", _attr_range_edit))
	_attr_drawer_option = OptionButton.new()
	_attr_drawer_option.add_item("Default field")
	_attr_drawer_option.tooltip_text = "Swap the Inspector field for a richer drawer (dial, swatches, curve…).\nGraceful: a plain field without the editor plugin (parity preserved)."
	_attr_drawer_option.item_selected.connect(func(_i: int) -> void: _refresh_drawer_preview())
	_attr_section.add_child(EventSheetPopupUI.form_row("Show as", _attr_drawer_option))
	# Live "what the drawer looks like" preview — the actual widget, updated as the type / drawer / bounds change.
	_drawer_preview_box = VBoxContainer.new()
	_drawer_preview_box.visible = false
	_drawer_preview_box.add_theme_constant_override("separation", 3)
	_attr_section.add_child(_drawer_preview_box)
	_attr_multiline_check = CheckBox.new()
	_attr_multiline_check.text = "Multiline (String: big text box)"
	_attr_section.add_child(_attr_multiline_check)
	# ── ADVANCED tier (nested disclosure): wiring + organization that assumes other vars/funcs exist or
	# Godot-Inspector fluency — kept out of the common path so the Basic tier reads cleanly. ──
	_attr_advanced_toggle = Button.new()
	_attr_advanced_toggle.flat = true
	_attr_advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_attr_advanced_toggle.toggle_mode = true
	_attr_advanced_toggle.text = "▸  Advanced (grouping, conditions, clamp…)"
	_attr_advanced_toggle.tooltip_text = "Inspector grouping, conditional show/lock, an on-changed callback, clamp, read-only — for variables that reference other variables or functions."
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
	_exported_check.text = "Editable in the Inspector (like a C3 property)"
	_exported_check.tooltip_text = "On: a designer can tweak this per-instance in the Inspector (@export var).\nOff: internal script state — a plain private var (the default for a new variable)."
	_exported_check.toggled.connect(func(_pressed: bool) -> void: _update_attr_gating())
	access_row.add_child(_exported_check)
	form.add_child(access_row)

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
## ── Structured data editor (Array/Dictionary "Edit items…") ──────────────────
## True when the chosen type is a collection, so the structured items editor applies.
func _selected_type_is_collection() -> bool:
	var type_name: String = _type_option.get_item_text(_type_option.selected) if _type_option != null and _type_option.selected >= 0 else ""
	return type_name.begins_with("Array") or type_name.begins_with("Dictionary")

func _refresh_items_button() -> void:
	if _items_button != null:
		_items_button.visible = _selected_type_is_collection()

## Edit an Array/Dictionary's items one per line (Array: a value per line; Dictionary a
## "key: value" per line) instead of typing a cramped literal. Round-trips through the
## literal so the stored default's shape is unchanged.
func _open_items_editor() -> void:
	if _items_window == null:
		_build_items_window()
	var is_dict: bool = _type_option.get_item_text(_type_option.selected).begins_with("Dictionary")
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
	hint.text = "One item per line — each line is a GDScript value expression."
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
	var is_dict: bool = _type_option.get_item_text(_type_option.selected).begins_with("Dictionary")
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
	# A new variable is internal script state by DEFAULT (a plain private var) — the user opts into
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
	if not can_export:
		_attr_toggle.set_pressed_no_signal(false)
		_attr_toggle.text = "▸" + _attr_toggle.text.substr(1)
		if _attr_section != null:
			_attr_section.visible = false
		# Also collapse the nested Advanced tier so a later re-expand starts from the Basic-first state (rather
		# than leaving the advanced block remembered-open from an earlier export-on session).
		if _attr_advanced_toggle != null:
			_attr_advanced_toggle.set_pressed_no_signal(false)
			_attr_advanced_toggle.text = "▸" + _attr_advanced_toggle.text.substr(1)
			if _attr_advanced_section != null:
				_attr_advanced_section.visible = false

func open_for_edit(
	scope: String,
	context: Dictionary = {},
	name: String = "",
	type_name: String = "int",
	default_value: Variant = "",
	lock_type: bool = false,
	title: String = "Edit Variable",
	is_constant: bool = false,
	exported: bool = true
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
	var selected_index: int = 0
	for index: int in range(_type_option.item_count):
		if _type_option.get_item_text(index) == type_name:
			selected_index = index
			break
	_type_option.select(selected_index)
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
		else "On: a designer tweaks this per-instance in the Inspector (@export var).\nOff: internal script state — a plain private var."
	)
	var existing_attributes: Dictionary = context.get("attributes") if context.get("attributes") is Dictionary else {}
	_attr_tooltip_edit.text = str(existing_attributes.get("tooltip", ""))
	_attr_group_edit.text = str(existing_attributes.get("group", ""))
	_attr_subgroup_edit.text = str(existing_attributes.get("subgroup", ""))
	var existing_range: Variant = existing_attributes.get("range")
	# Default a missing step to 1: a drawer-recovered range carries only min/max, and the apply needs all
	# three parts (so a reopened progress_bar/dial re-saves cleanly instead of erroring on "min, max").
	_attr_range_edit.text = "%s, %s, %s" % [str((existing_range as Dictionary).get("min", "0")), str((existing_range as Dictionary).get("max", "100")), str((existing_range as Dictionary).get("step", "1"))] if existing_range is Dictionary else ""
	_attr_multiline_check.button_pressed = bool(existing_attributes.get("multiline", false))
	_attr_show_if_edit.text = str(existing_attributes.get("show_if", ""))
	_attr_lock_unless_edit.text = str(existing_attributes.get("lock_unless", ""))
	_attr_on_changed_edit.text = str(existing_attributes.get("on_changed", ""))
	_attr_clamp_check.button_pressed = bool(existing_attributes.get("clamp", false))
	_attr_read_only_check.button_pressed = bool(existing_attributes.get("read_only", false))
	# Progressive disclosure: "More options" starts collapsed for new variables and auto-expands when the
	# edited variable already uses any attribute. The nested "Advanced" tier auto-expands ONLY when an
	# advanced attribute is set — a tooltip-only variable shouldn't unfurl the whole advanced block.
	if _attr_toggle != null:
		var has_any: bool = not existing_attributes.is_empty()
		_attr_toggle.button_pressed = has_any
		_attr_section.visible = has_any
		_attr_toggle.text = ("▾" if _attr_section.visible else "▸") + _attr_toggle.text.substr(1)
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
	if not existing_drawer.is_empty() and _attr_drawer_option.item_count > 1 and str(_attr_drawer_option.get_item_metadata(1)) == existing_drawer:
		_attr_drawer_option.select(1)
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
			_name_warning.text = "✗ \"%s\" shadows a %s member — pick another name." % [var_name, shadow_owner]
		if _dialog.is_inside_tree():
			_dialog.call_deferred("popup_centered", Vector2i(460, 260))
		return
	var type_name: String = _type_option.get_item_text(_type_option.selected)
	# Guardrail (event-sheet-style): an invalid collection literal never commits — the dialog
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
	# Numeric-only attributes are gated on the type so a leftover value from a
	# previous type (the field is now HIDDEN by _refresh_contextual_rows) is inert
	# rather than erroring about a field the user can no longer see.
	var is_numeric: bool = type_name == "int" or type_name == "float"
	# Vector2 keeps a range too — its max drives the direction dial's magnitude, and the Range row is shown
	# for it (_refresh_contextual_rows). Without this it'd be dropped on apply, resetting the dial to max 100.
	var range_applies: bool = is_numeric or type_name == "Vector2"
	var range_text: String = _attr_range_edit.text.strip_edges()
	if not range_text.is_empty() and range_applies:
		# Forgiving: 1 part = max (min 0, step 1); 2 = min, max (step 1); 3 = min, max, step. A dial uses only
		# its max, so a designer shouldn't have to type a min/step it ignores — config is optional with sensible
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
	variable_confirmed.emit(var_name, type_name, default_value, _scope, _context.duplicate(true), is_constant, exported, combo_options, attributes)

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

## The text shown in the Default field for a value — the inverse of _parse_default, and the pair MUST
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
		return {"ok": false, "error": "Not a valid %s literal — e.g. %s" % [
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
	var type_name: String = _type_option.get_item_text(maxi(_type_option.selected, 0))
	var numeric: bool = type_name in ["int", "float"]
	_options_row.visible = type_name == "String"
	_enum_fill_menu.visible = _options_row.visible and _enum_provider.is_valid() and not (_enum_provider.call() as Array).is_empty()
	if _attr_range_edit != null:
		# Range now lives in a labelled row — hide the whole row, not just the field, so its
		# "Range" label doesn't linger on non-numeric types. Vector2 keeps it too: its max drives the dial.
		_attr_range_edit.get_parent().visible = numeric or type_name == "Vector2"
		# For a Vector2 the Range is just the dial's reach (only max is read), so prompt for one number, not the
		# numeric "min, max, step" — the forgiving parser accepts a bare max.
		_attr_range_edit.placeholder_text = _RANGE_PLACEHOLDER_VECTOR2 if type_name == "Vector2" else _RANGE_PLACEHOLDER_NUMERIC
		_attr_clamp_check.visible = numeric
		_attr_multiline_check.visible = type_name == "String"
	# The drawer picker offers only the one drawer the current type can host (or hides when there is none).
	_rebuild_drawer_options(_drawer_kind_for_type(type_name))
	_refresh_drawer_preview()
	_refresh_clamp_gate()

## The single drawer kind a variable type can host (or "" — most types host no drawer).
static func _drawer_kind_for_type(type_name: String) -> String:
	match type_name:
		"int", "float":
			return "progress_bar"
		"Vector2":
			return "vector_dial"
		"Color":
			return "swatch_row"
		"Texture2D":
			return "texture_preview"
		"Curve":
			return "curve_editor"
	return ""

## Human label for the drawer option entry.
static func _drawer_label_for_kind(kind: String) -> String:
	match kind:
		"progress_bar":
			return "Progress bar"
		"vector_dial":
			return "Direction dial"
		"swatch_row":
			return "Swatch row"
		"texture_preview":
			return "Texture preview"
		"curve_editor":
			# "preview", not "editor": the drawer renders + picks a Curve; you shape its points in Godot's
			# stock Curve editor after assigning. The label shouldn't promise in-place point editing.
			return "Curve preview"
	return ""

## The drawer kind currently chosen in the dialog ("" = Default field).
func _selected_drawer_kind() -> String:
	if _attr_drawer_option == null or _attr_drawer_option.selected <= 0:
		return ""
	var meta: Variant = _attr_drawer_option.get_item_metadata(_attr_drawer_option.selected)
	return str(meta) if meta != null else ""

## Rebuilds the drawer OptionButton to offer Default + (when the type hosts one) its single drawer, preserving
## the current choice when the kind is unchanged so a refresh doesn't silently reset the user's selection.
func _rebuild_drawer_options(kind: String) -> void:
	if _attr_drawer_option == null:
		return
	var previous: String = _selected_drawer_kind()
	_attr_drawer_option.clear()
	_attr_drawer_option.add_item("Default field")
	if not kind.is_empty():
		_attr_drawer_option.add_item(_drawer_label_for_kind(kind))
		_attr_drawer_option.set_item_metadata(1, kind)
	# Hide the whole "Show as" row (label + option) for types with no drawer, not just the OptionButton.
	var show_row: Node = _attr_drawer_option.get_parent()
	if show_row is Control:
		(show_row as Control).visible = not kind.is_empty()
	_attr_drawer_option.select(1 if (not kind.is_empty() and previous == kind) else 0)

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

## {min, max} (as floats) parsed from the Range field — drives the progress_bar / dial bounds in the preview,
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
	# 0.001 is a cosmetic "close enough to whole" tolerance — display-only, never used for storage or compares.
	return str(int(round(value))) if absf(value - round(value)) < 0.001 else str(value)

## Pre-validate the Clamp↔Range dependency (docs/PROGRESSIVE-DISCLOSURE-SPEC.md): Clamp needs a min+max to
## clamp to, so disable the checkbox (with a hint) until a valid Range is entered — making the dependency
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
		_attr_clamp_check.tooltip_text = "Enter a Range (a max, or min, max) above first — Clamp keeps the value inside it."

## Rebuilds the live preview to show the actual drawer widget (display-only) at a representative value.
func _refresh_drawer_preview() -> void:
	if _drawer_preview_box == null:
		return
	for child: Node in _drawer_preview_box.get_children():
		child.queue_free()
	var kind: String = _selected_drawer_kind()
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
		"progress_bar":
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
		_name_warning.text = "⚠ \"%s\" shadows a %s member — rename to avoid a clash." % [_name_edit.text.strip_edges(), owner]

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
			# Members may carry explicit values ("HURT = 4") — the combo wants names.
			members.append(str(member).get_slice("=", 0).strip_edges())
		popup.add_item(str((entry as Dictionary).get("name", "")))
		popup.set_item_metadata(popup.item_count - 1, ", ".join(members))

func _refresh_default_hint() -> void:
	if _default_help == null or _type_option == null or _default_edit == null:
		return
	var type_name: String = _type_option.get_item_text(_type_option.selected)
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
	var type_name: String = _type_option.get_item_text(_type_option.selected)
	var supports_const: bool = _supports_constant(type_name)
	_const_check.disabled = not supports_const
	if not supports_const:
		_const_check.button_pressed = false
	_const_help.visible = not supports_const
	_const_help.text = "Const is unavailable for Variant variables."

func _supports_constant(type_name: String) -> bool:
	return type_name != "Variant"
