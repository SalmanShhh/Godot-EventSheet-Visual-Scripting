@tool
extends RefCounted
class_name EventSheetSheetTypeDialog
# The "Sheet Type" dialog: a discoverable alternative to the Inspector fields for choosing what a sheet
# compiles into (plain event sheet / custom node / behavior / editor tool / autoload) and its identity,
# behaviour toggles, and composition (tags / includes / uses / requires / autoload). Extracted from
# event_sheet_dock.gd; this owns the dialog + its 13 widgets, but the data it touches stays on the dock:
# the field-builders (_add_sheet_type_field is shared with the pick dialog) and the
# _apply_sheet_type_settings service (which ~8 tests drive directly) are reached via the _dock
# back-reference. The dock keeps a thin _open_sheet_type_dialog delegate for its menu / banner callers.

var _dock: Control = null
var _sheet_type_dialog: ConfirmationDialog = null
var _sheet_type_option: OptionButton = null
var _sheet_type_name_edit: LineEdit = null
var _sheet_type_icon_edit: LineEdit = null
var _sheet_type_description_edit: TextEdit = null
var _sheet_type_host_edit: LineEdit = null
var _sheet_type_tool_check: CheckBox = null
var _sheet_type_family_check: CheckBox = null
var _sheet_type_tags_edit: LineEdit = null
var _sheet_type_includes_edit: LineEdit = null
var _sheet_type_uses_edit: LineEdit = null
var _sheet_type_requires_edit: LineEdit = null
var _sheet_type_autoload_edit: LineEdit = null

func init(dock: Control) -> void:
	_dock = dock

func open() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_ensure_sheet_type_dialog()
	if _dock._current_sheet.tool_mode and _dock._current_sheet.host_class == "EditorScript":
		_sheet_type_option.select(3)
	elif _dock._current_sheet.behavior_mode:
		_sheet_type_option.select(2)
	elif not _dock._current_sheet.custom_class_name.strip_edges().is_empty():
		_sheet_type_option.select(1)
	else:
		_sheet_type_option.select(0)
	_sheet_type_name_edit.text = _dock._current_sheet.custom_class_name
	_sheet_type_icon_edit.text = _dock._current_sheet.custom_class_icon
	_sheet_type_description_edit.text = _dock._current_sheet.class_description
	_sheet_type_host_edit.text = _dock._current_sheet.host_class
	_sheet_type_tool_check.button_pressed = _dock._current_sheet.tool_mode
	_sheet_type_family_check.button_pressed = _dock._current_sheet.is_family
	_sheet_type_tags_edit.text = ", ".join(_dock._current_sheet.addon_tags)
	_sheet_type_includes_edit.text = ", ".join(PackedStringArray(_dock._current_sheet.includes))
	_sheet_type_uses_edit.text = ", ".join(PackedStringArray(_dock._current_sheet.uses_addons))
	_sheet_type_requires_edit.text = ", ".join(PackedStringArray(_dock._current_sheet.requires_behaviors))
	_sheet_type_autoload_edit.text = _dock._current_sheet.autoload_name
	_sheet_type_dialog.popup_centered(Vector2i(460, 300))

func _ensure_sheet_type_dialog() -> void:
	if _sheet_type_dialog != null:
		return
	_sheet_type_dialog = ConfirmationDialog.new()
	_sheet_type_dialog.title = "Sheet Type"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_option = OptionButton.new()
	_sheet_type_option.add_item("Event Sheet")           # plain: compiles onto the host node
	_sheet_type_option.add_item("Custom Node")           # class_name + @icon → Create Node dialog
	_sheet_type_option.add_item("Behavior (acts on parent)")  # Node component with `host`
	_sheet_type_option.add_item("Editor Tool (EditorScript)")  # EXPERIMENTAL: events -> editor tooling
	_sheet_type_option.add_item("Autoload (Singleton)")  # extends Node; registered project-wide
	form.add_child(_sheet_type_option)
	# Identity card — class name / icon / description / host, the fields that name the generated type.
	var ident_box: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_name_edit = _dock._add_sheet_type_field(ident_box, "Class name", "PatrolBehavior")
	_sheet_type_icon_edit = _dock._add_sheet_type_field(ident_box, "Icon (res://…)", "res://icons/patrol.svg")
	_sheet_type_description_edit = _dock._add_sheet_type_multiline_field(ident_box, "Description", "What this behaviour/node does — shown in Godot's Create Node dialog.")
	_sheet_type_host_edit = _dock._add_sheet_type_field(ident_box, "Host / base class", "CharacterBody2D")
	form.add_child(EventSheetPopupUI.titled_card("Identity", ident_box))
	# Behaviour card — the two compile-mode toggles (@tool + Family).
	var behaviour_box: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_tool_check = CheckBox.new()
	_sheet_type_tool_check.text = "@tool — runs inside the editor (EXPERIMENTAL, editor-version-coupled)"
	behaviour_box.add_child(_sheet_type_tool_check)
	# Family flag (horizontal abstraction): a named sheet's instances are collected into
	# group family_<class>, so other sheets can write ONE rule over all of them ("for each Enemy: …").
	# Only meaningful for a Custom Node / Behavior (it needs a class name); cleared for a plain sheet.
	_sheet_type_family_check = CheckBox.new()
	_sheet_type_family_check.text = "Family — collect instances into a group so one rule can target all of them"
	behaviour_box.add_child(_sheet_type_family_check)
	form.add_child(EventSheetPopupUI.titled_card("Behaviour", behaviour_box))
	# Composition card — how this sheet wires to addon sheets / classes / behaviors / autoload.
	var composition_box: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_tags_edit = _dock._add_sheet_type_field(composition_box, "Tags (comma-separated)", "movement, retro, jam")
	_sheet_type_includes_edit = _dock._add_sheet_type_field(composition_box, "Includes (addon sheets)", "res://eventsheet_addons/screen_shake/screen_shake.tres, …")
	_sheet_type_uses_edit = _dock._add_sheet_type_field(composition_box, "Uses (addon classes)", "ScreenShake, MathHelpers — owned helper instances")
	_sheet_type_requires_edit = _dock._add_sheet_type_field(composition_box, "Requires (sibling behaviors)", "ScreenShake — shows the warning badge when the sibling is missing")
	_sheet_type_autoload_edit = _dock._add_sheet_type_field(composition_box, "Autoload name (singleton)", "GameState — global identifier every sheet can call")
	form.add_child(EventSheetPopupUI.titled_card("Composition", composition_box))
	form.add_child(EventSheetPopupUI.hint_label("Custom nodes appear in Godot's Create Node dialog with their icon.\nBehaviors attach as child nodes and act on their parent via the typed `host` accessor.", 420.0))
	_sheet_type_dialog.add_child(EventSheetPopupUI.margined(form))
	_sheet_type_dialog.confirmed.connect(_on_sheet_type_confirmed)
	_dock.add_child(_sheet_type_dialog)

func _on_sheet_type_confirmed() -> void:
	_dock._apply_sheet_type_settings(
		_sheet_type_option.selected,
		_sheet_type_name_edit.text,
		_sheet_type_icon_edit.text,
		_sheet_type_host_edit.text,
		_sheet_type_tool_check.button_pressed,
		VariableDialog.parse_options(_sheet_type_tags_edit.text)
	,
		VariableDialog.parse_options(_sheet_type_includes_edit.text),
		VariableDialog.parse_options(_sheet_type_uses_edit.text),
		VariableDialog.parse_options(_sheet_type_requires_edit.text),
		_sheet_type_autoload_edit.text,
		_sheet_type_description_edit.text,
		_sheet_type_family_check.button_pressed
	)
