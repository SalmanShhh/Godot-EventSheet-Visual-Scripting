@tool
class_name EventSheetSheetTypeDialog
extends RefCounted
# The "Sheet Type" dialog: a discoverable alternative to the Inspector fields for choosing what a sheet
# compiles into (plain event sheet / custom node / behavior / editor tool / autoload / custom resource)
# and its identity, plus the composition wiring (tags / includes / uses / requires).
#
# ANTI-FATIGUE CONTRACT: the dialog shows only the fields the CHOSEN type actually consumes, mirroring
# apply_sheet_type_settings exactly (a plain sheet CLEARS class name/icon/description/family/tags; an
# Autoload/Editor Tool FORCES its host, so those fields hide). Hiding is visual only - every control is
# filled from the sheet at open() and its value passes through on OK, so opening + OK never mutates
# hidden state. The composition fields and the experimental @tool toggle live behind a collapsed
# "More options" disclosure. A live identity line previews the compiled `class_name X extends Y` and
# validates the host class + class name as you type.

var _dock: Control = null
var _sheet_type_dialog: ConfirmationDialog = null
var _sheet_type_option: OptionButton = null
var _type_hint: Label = null
var _sheet_type_name_edit: LineEdit = null
var _sheet_type_icon_edit: LineEdit = null
var _sheet_type_description_edit: TextEdit = null
var _sheet_type_host_edit: LineEdit = null
var _host_label: Label = null
var _host_menu: MenuButton = null
var _sheet_type_tool_check: CheckBox = null
var _sheet_type_family_check: CheckBox = null
var _sheet_type_tags_edit: LineEdit = null
var _sheet_type_includes_edit: LineEdit = null
var _sheet_type_uses_edit: LineEdit = null
var _sheet_type_requires_edit: LineEdit = null
var _sheet_type_autoload_edit: LineEdit = null
var _identity_card: PanelContainer = null
var _ships_as: Label = null
var _more_toggle: Button = null
var _more_card: PanelContainer = null

## One plain-English line per type, shown under the dropdown - what the choice MEANS, not its jargon.
const TYPE_HINTS: Array[String] = [
	"Plain events on whatever node this sheet is attached to.",
	"A new node type: appears in Godot's Add Node dialog with your icon.",
	"Attach under any node as a child - its events act on that parent.",
	"Runs inside the editor (File > Run), not in the game. Experimental.",
	"One always-on instance the whole game can call by name.",
	"A data asset type: each saved file of it is edited in the Inspector.",
]

## The curated "what does this sheet control?" shortlist for the host Choose menu - friendly words
## first, the Godot class in parentheses, so a newcomer picks by meaning instead of memorized names.
const COMMON_HOSTS: Array[Dictionary] = [
	{"label": "2D Character - moves and collides (CharacterBody2D)", "host": "CharacterBody2D"},
	{"label": "2D Object - a sprite, prop, or point (Node2D)", "host": "Node2D"},
	{"label": "2D Physics Object - pushed by forces (RigidBody2D)", "host": "RigidBody2D"},
	{"label": "2D Area / Trigger - detects overlaps (Area2D)", "host": "Area2D"},
	{"label": "UI Control - buttons, labels, menus (Control)", "host": "Control"},
	{"label": "3D Character (CharacterBody3D)", "host": "CharacterBody3D"},
	{"label": "3D Object (Node3D)", "host": "Node3D"},
	{"label": "Invisible Manager - logic only (Node)", "host": "Node"},
]


func init(dock: Control) -> void:
	_dock = dock


func open() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_ensure_sheet_type_dialog()
	match EventSheetScriptIntent.of_sheet(_dock._current_sheet):
		EventSheetScriptIntent.Intent.EDITOR_TOOL:
			_sheet_type_option.select(3)
		EventSheetScriptIntent.Intent.BEHAVIOUR:
			_sheet_type_option.select(2)
		EventSheetScriptIntent.Intent.AUTOLOAD:
			_sheet_type_option.select(4)
		EventSheetScriptIntent.Intent.CUSTOM_RESOURCE:
			_sheet_type_option.select(5)
		EventSheetScriptIntent.Intent.CUSTOM_NODE:
			_sheet_type_option.select(1)
		_:
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
	# Collapse the power fields on every open, so the first read is always the short form.
	_set_more_expanded(false)
	_refresh_type_ui()
	_sheet_type_dialog.popup_centered(Vector2i(480, 0))


## Which field rows the CHOSEN type shows - mirrors apply_sheet_type_settings field by field: a plain
## sheet clears the named-type identity so those fields hide; Editor Tool / Autoload force their host
## so the host row hides; Family only means something for node instances (custom node / behavior).
## Static and value-driven so tests pin it without building the dialog.
static func field_visibility(type_index: int) -> Dictionary:
	return {
		"name": type_index != 0,
		"icon": type_index != 0,
		"description": type_index != 0,
		"host": type_index in [0, 1, 2, 5],
		"family": type_index in [1, 2],
		"autoload": type_index == 4,
	}


## The live identity line: the compiled `class_name X extends Y` preview when everything is valid,
## or the FIRST problem as a plain "x ..." message. own_class_name is the sheet's already-saved name,
## excepted from the collision check (a saved sheet registers its own global class).
static func identity_preview(type_index: int, class_name_text: String, host_text: String, autoload_name: String, own_class_name: String = "") -> String:
	var shown: Dictionary = field_visibility(type_index)
	var class_name_value: String = class_name_text.strip_edges()
	var host_value: String = host_text.strip_edges()
	if bool(shown.get("host", false)) and not host_value.is_empty() and not _class_is_known(host_value):
		var suggestion: String = _nearest_class(host_value)
		return "x Unknown class \"%s\"%s" % [host_value, (" - did you mean %s?" % suggestion) if not suggestion.is_empty() else ""]
	if bool(shown.get("name", false)) and not class_name_value.is_empty():
		if not EventSheetIdentifierRules.is_valid(class_name_value):
			return "x \"%s\" can't be a class name (letters/digits/underscores, no keywords)." % class_name_value
		if class_name_value != own_class_name and _class_is_known(class_name_value):
			return "x \"%s\" is already a class name - pick another." % class_name_value
	var effective_host: String = host_value
	if type_index == 3:
		effective_host = "EditorScript"
	elif type_index == 4:
		effective_host = "Node"
	elif type_index == 5 and not EventSheetScriptIntent.is_resource_host(effective_host):
		effective_host = "Resource"
	elif effective_host.is_empty():
		effective_host = "Node"
	var preview: String = "extends %s" % effective_host
	if not class_name_value.is_empty() and type_index != 0:
		preview = "class_name %s %s" % [class_name_value, preview]
	if type_index == 4 and not autoload_name.strip_edges().is_empty():
		preview += "  -  autoload \"%s\"" % autoload_name.strip_edges()
	return "Ships as:  %s" % preview


## True when the name is an engine class OR a project class_name (user scripts register globally).
static func _class_is_known(type_name: String) -> bool:
	if ClassDB.class_exists(type_name):
		return true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == type_name:
			return true
	return false


## Case-insensitive nearest engine-class match for typo help ("CharcterBody2D" -> CharacterBody2D),
## via the built-in bigram String.similarity(). Below the threshold no suggestion is offered - a
## wrong guess is worse than none. An exact case-insensitive hit scores 1.0 and always wins.
static func _nearest_class(typed: String) -> String:
	var lower: String = typed.to_lower()
	var best: String = ""
	var best_score: float = 0.74
	for engine_class: String in ClassDB.get_class_list():
		var score: float = lower.similarity(engine_class.to_lower())
		if score > best_score:
			best_score = score
			best = engine_class
	return best


func _ensure_sheet_type_dialog() -> void:
	if _sheet_type_dialog != null:
		return
	_sheet_type_dialog = ConfirmationDialog.new()
	_sheet_type_dialog.title = "Sheet Type"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_option = OptionButton.new()
	_sheet_type_option.add_item("Event Sheet")           # plain: compiles onto the host node
	_sheet_type_option.add_item("Custom Node")           # class_name + @icon -> Create Node dialog
	_sheet_type_option.add_item("Behavior (acts on parent)")  # Node component with `host`
	_sheet_type_option.add_item("Editor Tool")           # EXPERIMENTAL: events -> editor tooling
	_sheet_type_option.add_item("Autoload (always-on singleton)")  # extends Node; registered project-wide
	_sheet_type_option.add_item("Custom Resource (data asset)")  # extends Resource; each .tres is designer-editable
	_sheet_type_option.item_selected.connect(func(_index: int) -> void: _refresh_type_ui())
	form.add_child(_sheet_type_option)
	_type_hint = EventSheetPopupUI.hint_label(TYPE_HINTS[0], 440.0)
	form.add_child(_type_hint)
	# Identity card - only the fields the chosen type consumes are visible (see field_visibility).
	var ident_box: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_name_edit = _dock._add_sheet_type_field(ident_box, "Class name", "PatrolBehavior")
	_sheet_type_icon_edit = _dock._add_sheet_type_field(ident_box, "Icon (res://…)", "res://icons/patrol.svg")
	_sheet_type_description_edit = _dock._add_sheet_type_multiline_field(ident_box, "Description", "What this does - shown in Godot's Create Node dialog.")
	_sheet_type_host_edit = _dock._add_sheet_type_field(ident_box, "Controls / extends", "CharacterBody2D")
	var host_row: HBoxContainer = _sheet_type_host_edit.get_parent()
	_host_label = host_row.get_child(0)
	# "Choose…" fills the host field from the curated shortlist - pick by meaning, type only if you
	# already know the exact class.
	_host_menu = MenuButton.new()
	_host_menu.text = "Choose…"
	_host_menu.flat = false
	for entry: Dictionary in COMMON_HOSTS:
		_host_menu.get_popup().add_item(str(entry["label"]))
	_host_menu.get_popup().index_pressed.connect(func(index: int) -> void:
		_sheet_type_host_edit.text = str(COMMON_HOSTS[index]["host"])
		_refresh_identity_preview())
	host_row.add_child(_host_menu)
	_sheet_type_autoload_edit = _dock._add_sheet_type_field(ident_box, "Autoload name", "GameState - a global name every sheet can call")
	# Family flag (horizontal abstraction): a named sheet's instances are collected into
	# group family_<class>, so other sheets can write ONE rule over all of them ("for each Enemy: …").
	_sheet_type_family_check = CheckBox.new()
	_sheet_type_family_check.text = "Family - one rule can target every instance at once"
	ident_box.add_child(_sheet_type_family_check)
	# The live compiled-identity line: `class_name X extends Y`, or the first validation problem.
	_ships_as = EventSheetPopupUI.hint_label("", 440.0)
	ident_box.add_child(_ships_as)
	_identity_card = EventSheetPopupUI.titled_card("Identity", ident_box)
	form.add_child(_identity_card)
	for edit: LineEdit in [_sheet_type_name_edit, _sheet_type_host_edit, _sheet_type_autoload_edit]:
		edit.text_changed.connect(func(_text: String) -> void: _refresh_identity_preview())
	# "More options" disclosure - the composition wiring + the experimental @tool toggle. Collapsed on
	# every open so the everyday read stays short; power users expand it deliberately.
	_more_toggle = Button.new()
	_more_toggle.toggle_mode = true
	_more_toggle.flat = true
	_more_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_more_toggle.text = "▸ More options (tags, includes, @tool)"
	_more_toggle.toggled.connect(func(pressed: bool) -> void: _set_more_expanded(pressed))
	form.add_child(_more_toggle)
	var more_box: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_tags_edit = _dock._add_sheet_type_field(more_box, "Tags (comma-separated)", "movement, retro, jam")
	_sheet_type_includes_edit = _dock._add_sheet_type_field(more_box, "Includes (addon sheets)", "res://eventsheet_addons/screen_shake/screen_shake.tres, …")
	_sheet_type_uses_edit = _dock._add_sheet_type_field(more_box, "Uses (addon classes)", "ScreenShake, MathHelpers - owned helper instances")
	_sheet_type_requires_edit = _dock._add_sheet_type_field(more_box, "Requires (sibling behaviors)", "ScreenShake - shows a warning badge when missing")
	_sheet_type_tool_check = CheckBox.new()
	_sheet_type_tool_check.text = "@tool - runs inside the editor (EXPERIMENTAL)"
	more_box.add_child(_sheet_type_tool_check)
	_more_card = EventSheetPopupUI.titled_card("More options", more_box)
	_more_card.visible = false
	form.add_child(_more_card)
	_sheet_type_dialog.add_child(EventSheetPopupUI.margined(form))
	_sheet_type_dialog.confirmed.connect(_on_sheet_type_confirmed)
	_dock.add_child(_sheet_type_dialog)


## Applies the chosen type's field set: hint text, row visibility, and the host label wording
## ("Acts on" for a behavior, "Extends" for a data asset). Values are never touched - hiding is
## purely visual, so OK without edits round-trips the sheet unchanged.
func _refresh_type_ui() -> void:
	var type_index: int = _sheet_type_option.selected
	_type_hint.text = TYPE_HINTS[type_index] if type_index >= 0 and type_index < TYPE_HINTS.size() else ""
	var shown: Dictionary = field_visibility(type_index)
	_sheet_type_name_edit.get_parent().visible = bool(shown["name"])
	_sheet_type_icon_edit.get_parent().visible = bool(shown["icon"])
	_sheet_type_description_edit.get_parent().visible = bool(shown["description"])
	_sheet_type_host_edit.get_parent().visible = bool(shown["host"])
	_sheet_type_autoload_edit.get_parent().visible = bool(shown["autoload"])
	_sheet_type_family_check.visible = bool(shown["family"])
	match type_index:
		2:
			_host_label.text = "Acts on (parent)"
		5:
			_host_label.text = "Extends (data type)"
		_:
			_host_label.text = "Controls / extends"
	_host_menu.visible = type_index != 5  # the node shortlist makes no sense for a Resource host
	_refresh_identity_preview()
	if _sheet_type_dialog.visible:
		_sheet_type_dialog.reset_size()


func _refresh_identity_preview() -> void:
	var own_class_name: String = _dock._current_sheet.custom_class_name if _dock._current_sheet != null else ""
	_ships_as.text = identity_preview(
		_sheet_type_option.selected,
		_sheet_type_name_edit.text,
		_sheet_type_host_edit.text,
		_sheet_type_autoload_edit.text,
		own_class_name
	)


func _set_more_expanded(expanded: bool) -> void:
	if _more_toggle == null:
		return
	_more_toggle.set_pressed_no_signal(expanded)
	_more_toggle.text = ("▾" if expanded else "▸") + " More options (tags, includes, @tool)"
	_more_card.visible = expanded
	if _sheet_type_dialog != null and _sheet_type_dialog.visible:
		_sheet_type_dialog.reset_size()


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
