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
var _help_strip: EventSheetPopupUI.HelpStrip = null
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
var _plugin_capabilities_box: VBoxContainer = null
var _plugin_capability_checks: Dictionary = {}
var _identity_card: PanelContainer = null
var _ships_as: Label = null
var _more_toggle: Button = null
var _more_card: PanelContainer = null
# As-you-type host suggestions (IntelliSense-style): an unfocusable popup under the field, so the
# caret never leaves the LineEdit; Up/Down highlight, Enter accepts, Escape dismisses.
var _host_suggest: PopupMenu = null
var _host_suggest_items: PackedStringArray = PackedStringArray()
var _host_suggest_index: int = -1
var _icon_file_dialog: EditorFileDialog = null

## One plain-English line per type, shown under the dropdown - what the choice MEANS, not its jargon.
const TYPE_HINTS: Array[String] = [
	"Plain events on whatever node this sheet is attached to.",
	"A new node type: appears in Godot's Add Node dialog with your icon.",
	"Attach under any node as a child - its events act on that parent.",
	"Runs inside the editor (File > Run), not in the game. Experimental.",
	"One always-on instance the whole game can call by name.",
	"A data asset type: each saved file of it is edited in the Inspector.",
	"Claims about your game that a runner checks and reports pass/fail on.",
	# R33. The three tool types that are not "a chore you press Run on". They share the Editor Tools
	# vocabulary with index 3 and differ only in WHEN they run, which is what each line says first.
	"A plugin the editor switches on: it adds a dock, a Tools menu item, an object type.",
	"Runs when files are imported - fix up or check what just landed in the project.",
	"Runs when the project is exported - stamp a build, bake a file, strip debug content.",
	# W17. The two remaining shapes. The add-on line names the six classes rather than the concept,
	# because "add-on" alone tells a reader nothing about which one they are choosing.
	"A piece a plugin hands the editor: a Properties bar add-on, importer, thumbnail maker, debugger panel, context menu or view handle.",
	"A script the Godot binary runs headless from the command line, with arguments and an exit code.",
]

## What each type is CALLED, indexed by the same frozen type index TYPE_HINTS is. The list used to be
## twelve add_item() calls in the dialog builder; keeping the words here means the dropdown, the
## status lines and a test all read the same table.
const TYPE_LABELS: PackedStringArray = [
	"Event Sheet",                                    # plain: compiles onto the host node
	"Custom Node",                                    # class_name + @icon -> Create Node dialog
	"Behavior (acts on parent)",                      # Node component with `host`
	"Editor Tool",                                    # EXPERIMENTAL: events -> editor tooling
	"Autoload (always-on singleton)",                 # extends Node; registered project-wide
	"Custom Resource (data asset)",                   # extends Resource; each .tres is designer-editable
	"Test (asserts + verdict)",                       # extends Node + signal test_started
	"Editor Plugin (dock, menu item, object type)",   # extends EditorPlugin
	"Import Tool (runs on import)",                   # EditorScript + On File Imported
	"Export Hook (runs on export)",                   # EditorScript + On Project Export
	"Editor Add-on (Properties bar, importer, thumbnails…)",
	"Command Tool (runs headless from the command line)",  # extends SceneTree
]

## C4. The order the KIND dropdown reads in: the six kinds most sheets are, then a divider, then the
## kinds that make editor tooling. `-1` is the divider. The type INDEX is what a saved sheet
## round-trips through, so the list is reordered by carrying each index as the item's id rather than
## by renumbering anything.
const TYPE_ORDER: PackedInt32Array = [0, 1, 2, 4, 5, 6, -1, 3, 7, 8, 9, 10, 11]


## The tool types whose host the sheet does not get to choose, and what each is forced to. Index 3
## (Editor Tool) is here too: one table, so the dialog's preview line and the apply path cannot drift.
## An Import tool and an Export hook are both EditorScripts - a plain named handler the editor calls -
## while an Editor plugin is the engine's own EditorPlugin node.
## W17 appends index 11 (Command tool). Index 10 (Editor add-on) is deliberately absent: it is the
## one tool type whose host the sheet DOES choose.
const TOOL_TYPE_HOSTS: Dictionary = {
	3: "EditorScript",
	7: "EditorPlugin",
	8: "EditorScript",
	9: "EditorScript",
	11: "SceneTree",
}

## W17. The type indices that are tool sheets - every one of them forces `@tool` on, whether or not
## it also forces a host. Index 10 is here and not in TOOL_TYPE_HOSTS for exactly that reason.
const TOOL_TYPE_INDICES: PackedInt32Array = [3, 7, 8, 9, 10, 11]

## What ticking each Editor-plugin capability seeds into the sheet: the trigger the editor calls, the
## action that adds the thing, and the action that takes it away again. Keyed by the checkbox order
## the mockup fixed (dock, Tools menu item, custom object type, Inspector button).
const PLUGIN_CAPABILITIES: Array[Dictionary] = [
	{"key": "dock", "label": "a dock", "add": "AddEditorDock", "remove": "RemoveEditorDock"},
	{"key": "menu_item", "label": "a Tools menu item", "add": "AddToolsMenuItem", "remove": "RemoveToolsMenuItem"},
	{"key": "object_type", "label": "a custom object type", "add": "AddEditorObjectType", "remove": "RemoveEditorObjectType"},
	{"key": "inspector", "label": "an Inspector button", "add": "AddEditorInspectorPlugin", "remove": "RemoveEditorInspectorPlugin"},
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
			_select_type(editor_script_type_index(_dock._current_sheet))
		EventSheetScriptIntent.Intent.EDITOR_PLUGIN:
			_select_type(7)
		EventSheetScriptIntent.Intent.EDITOR_ADDON:
			_select_type(10)
		EventSheetScriptIntent.Intent.COMMAND_TOOL:
			_select_type(11)
		EventSheetScriptIntent.Intent.BEHAVIOUR:
			_select_type(2)
		EventSheetScriptIntent.Intent.AUTOLOAD:
			_select_type(4)
		EventSheetScriptIntent.Intent.TEST:
			_select_type(6)
		EventSheetScriptIntent.Intent.CUSTOM_RESOURCE:
			_select_type(5)
		EventSheetScriptIntent.Intent.CUSTOM_NODE:
			_select_type(1)
		_:
			_select_type(0)
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
	for key: String in _plugin_capability_checks:
		(_plugin_capability_checks[key] as CheckBox).button_pressed = sheet_has_capability(_dock._current_sheet, key)
	# Collapse the power fields on every open, so the first read is always the short form.
	_set_more_expanded(false)
	_refresh_type_ui()
	_sheet_type_dialog.popup_centered(Vector2i(480, 0))


## Which field rows the CHOSEN type shows - mirrors apply_sheet_type_settings field by field: a plain
## sheet clears the named-type identity so those fields hide; Editor Tool / Autoload force their host
## so the host row hides; Family only means something for node instances (custom node / behavior).
## Static and value-driven so tests pin it without building the dialog.
static func field_visibility(type_index: int) -> Dictionary:
	# A Test sheet is not a type anyone instantiates by name - it is a script a runner starts - so it
	# hides the class-name/icon pair a Create Node entry needs while keeping the description (what
	# this test covers) and forcing its own host, like Editor Tool and Autoload do.
	# R33. The four tool types (3 / 7 / 8 / 9) force their own host, so the host row hides for them the
	# way it does for Autoload and Test; the Editor-plugin capability ticks are the one row only index
	# 7 shows, because they are the only choice an EditorPlugin sheet makes that a script cannot.
	return {
		"name": type_index != 0 and type_index != 6,
		"icon": type_index != 0 and type_index != 6,
		"description": type_index != 0,
		# W17. Index 10 (Editor add-on) joins the host-showing list: which of Godot's add-on classes it
		# extends IS the choice that type makes, so hiding the field would hide the whole decision.
		"host": type_index in [0, 1, 2, 5, 10],
		"family": type_index in [1, 2],
		"autoload": type_index == 4,
		"plugin_capabilities": type_index == 7,
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
	if TOOL_TYPE_HOSTS.has(type_index):
		effective_host = str(TOOL_TYPE_HOSTS[type_index])
	elif type_index == 6:
		effective_host = "Node"
	elif type_index == 4:
		effective_host = "Node"
	elif type_index == 10 and effective_host.is_empty():
		# W17. An add-on with nothing typed yet is most often a Properties bar add-on, and a preview
		# reading "extends Node" would be a lie about what the sheet will compile to.
		effective_host = "EditorInspectorPlugin"
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


## R33. Which of the three EditorScript type indices a sheet already IS. All three compile to the
## same `@tool extends EditorScript`; what tells them apart is the moment the editor calls them, so
## the trigger the sheet carries is the honest answer. A tool with neither is the plain Editor Tool
## (index 3) - the one you press Run on. Static + value-driven so a test pins it without a dialog.
static func editor_script_type_index(sheet: EventSheetResource) -> int:
	if sheet == null:
		return 3
	for entry: Variant in sheet.events:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		match event.trigger_id:
			"OnFileImported":
				return 8
			"OnProjectExport":
				return 9
	return 3


## True when the sheet already carries the ADD action for an Editor-plugin capability, so reopening
## the Sheet Type dialog shows the ticks the sheet actually has and OK never seeds a second copy.
static func sheet_has_capability(sheet: EventSheetResource, capability_key: String) -> bool:
	if sheet == null:
		return false
	var add_id: String = ""
	for capability: Dictionary in PLUGIN_CAPABILITIES:
		if str(capability["key"]) == capability_key:
			add_id = str(capability["add"])
	if add_id.is_empty():
		return false
	for entry: Variant in sheet.events:
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		for action: Variant in event.actions:
			if action is ACEAction and (action as ACEAction).ace_id == add_id:
				return true
	return false


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


## As-you-type host suggestions. Empty text offers the curated shortlist (steer first, type later).
## Typed text ranks case-insensitive PREFIX matches before substring matches, drawn from the classes
## that make sense as a host - Node or Resource family, instantiable (filters out servers and
## abstract engine machinery a beginner should never land on) - plus the project's own class_name
## scripts (injectable for tests; defaults to the live global class list). Free text always wins:
## suggestions steer, they never block.
static func host_candidates(typed: String, project_classes: Array = [], limit: int = 8) -> PackedStringArray:
	var results: PackedStringArray = PackedStringArray()
	var trimmed: String = typed.strip_edges()
	if trimmed.is_empty():
		for entry: Dictionary in COMMON_HOSTS:
			results.append(str(entry["host"]))
			if results.size() >= limit:
				break
		return results
	var lower: String = trimmed.to_lower()
	var user_classes: Array = project_classes
	if user_classes.is_empty():
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			user_classes.append(str(entry.get("class", "")))
	var prefix_hits: PackedStringArray = PackedStringArray()
	var substring_hits: PackedStringArray = PackedStringArray()
	for candidate: Variant in user_classes:
		_bucket_candidate(str(candidate), lower, prefix_hits, substring_hits)
	for engine_class: String in ClassDB.get_class_list():
		if not ClassDB.can_instantiate(engine_class):
			continue
		if not (ClassDB.is_parent_class(engine_class, "Node") or ClassDB.is_parent_class(engine_class, "Resource")):
			continue
		_bucket_candidate(engine_class, lower, prefix_hits, substring_hits)
	prefix_hits.sort()
	substring_hits.sort()
	for hit: String in prefix_hits:
		if results.size() < limit:
			results.append(hit)
	for hit: String in substring_hits:
		if results.size() < limit and not results.has(hit):
			results.append(hit)
	return results


static func _bucket_candidate(candidate: String, lower_typed: String, prefix_hits: PackedStringArray, substring_hits: PackedStringArray) -> void:
	if candidate.is_empty():
		return
	var candidate_lower: String = candidate.to_lower()
	if candidate_lower == lower_typed:
		return  # already typed exactly - suggesting it back is noise
	if candidate_lower.begins_with(lower_typed):
		prefix_hits.append(candidate)
	elif candidate_lower.contains(lower_typed):
		substring_hits.append(candidate)


## The chosen KIND, as the frozen type index. The dropdown is ordered for reading (the common six,
## a divider, then the editor kinds) and carries each type index as its item id, so what a sheet
## round-trips through is never the position in a list.
func _selected_type() -> int:
	var chosen: int = _sheet_type_option.get_selected_id()
	return chosen if chosen >= 0 else 0


## Selects a KIND by its frozen type index.
func _select_type(type_index: int) -> void:
	for item: int in range(_sheet_type_option.item_count):
		if _sheet_type_option.get_item_id(item) == type_index:
			_sheet_type_option.select(item)
			return


## What the help strip says about one item of the KIND list: the kind's name and the line that says
## what it is for. {} for the divider, which the strip is asked to say nothing about.
func _kind_help(item_index: int) -> Dictionary:
	if item_index < 0 or item_index >= _sheet_type_option.item_count:
		return {}
	# A divider carries no type index, and the strip is asked to say nothing about it.
	var type_index: int = _sheet_type_option.get_item_id(item_index)
	if type_index < 0 or type_index >= TYPE_HINTS.size():
		return {}
	return {"heading": "Kind · %s" % TYPE_LABELS[type_index], "body": TYPE_HINTS[type_index]}


func _ensure_sheet_type_dialog() -> void:
	if _sheet_type_dialog != null:
		return
	_sheet_type_dialog = ConfirmationDialog.new()
	_sheet_type_dialog.title = "Sheet Type"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	# Drop a Scene-dock node ANYWHERE on the dialog and the host field takes its class - the
	# fastest honest answer to "what do I type in Controls / extends?" is the node you meant.
	form.set_drag_forwarding(Callable(), _can_drop_node, _drop_node)
	_sheet_type_option = OptionButton.new()
	for type_index: int in TYPE_ORDER:
		if type_index < 0:
			_sheet_type_option.add_separator()
			continue
		_sheet_type_option.add_item(TYPE_LABELS[type_index], type_index)
	_sheet_type_option.item_selected.connect(func(_index: int) -> void: _refresh_type_ui())
	form.add_child(EventSheetPopupUI.form_row("Kind", _sheet_type_option))
	# Identity card - only the fields the chosen type consumes are visible (see field_visibility).
	var ident_box: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_name_edit = _dock._add_sheet_type_field(ident_box, "Name", "PatrolBehavior")
	_sheet_type_host_edit = _dock._add_sheet_type_field(ident_box, "Extends", "CharacterBody2D")
	var host_row: HBoxContainer = _sheet_type_host_edit.get_parent()
	_host_label = host_row.get_child(0)
	# As-you-type suggestions: an unfocusable popup under the field (the caret stays in the LineEdit),
	# listing matching classes with their editor icons. Up/Down highlight, Enter accepts, Escape closes.
	_host_suggest = PopupMenu.new()
	_host_suggest.unfocusable = true
	_host_suggest.id_pressed.connect(func(index: int) -> void: _accept_host_suggestion(index))
	_sheet_type_host_edit.add_child(_host_suggest)
	_sheet_type_host_edit.text_changed.connect(func(text: String) -> void: _refresh_host_suggestions(text))
	_sheet_type_host_edit.focus_exited.connect(func() -> void: _host_suggest.hide())
	_sheet_type_host_edit.gui_input.connect(_on_host_edit_input)
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
	_sheet_type_icon_edit = _dock._add_sheet_type_field(ident_box, "Icon", "res://icons/patrol.svg")
	# Pick the icon straight from the FileSystem instead of typing a res:// path.
	var icon_browse: Button = Button.new()
	icon_browse.text = "Browse…"
	icon_browse.pressed.connect(_open_icon_file_dialog)
	_sheet_type_icon_edit.get_parent().add_child(icon_browse)
	_sheet_type_description_edit = _dock._add_sheet_type_multiline_field(ident_box, "Description", "What this does - shown in Godot's Create Node dialog.")
	_sheet_type_autoload_edit = _dock._add_sheet_type_field(ident_box, "Autoload name", "GameState - a global name every sheet can call")
	# C4 - "Runs in the editor too" reads as a field of the sheet's identity, not as a power option:
	# it is one of the lines the head shows, so it is edited where the other lines are.
	_sheet_type_tool_check = CheckBox.new()
	_sheet_type_tool_check.text = "Runs in the editor too  -  @tool"
	ident_box.add_child(_sheet_type_tool_check)
	# Family flag (horizontal abstraction): a named sheet's instances are collected into
	# group family_<class>, so other sheets can write ONE rule over all of them ("for each Enemy: …").
	_sheet_type_family_check = CheckBox.new()
	_sheet_type_family_check.text = "Family - one rule can target every instance at once"
	ident_box.add_child(_sheet_type_family_check)
	# R33. What an Editor plugin ADDS to the editor. Ticking a box is the whole authoring gesture: on
	# OK the sheet arrives with the pair of events that capability needs (add it when the plugin is
	# enabled, take it away again when it is disabled). Seeding is additive and idempotent - a box
	# whose actions are already on the sheet writes nothing, so reopening the dialog is safe.
	_plugin_capabilities_box = VBoxContainer.new()
	_plugin_capabilities_box.add_child(EventSheetPopupUI.hint_label(
		"What this plugin adds to the editor. Each tick arrives as a pair of events: added when the plugin is enabled, removed when it is disabled.", 440.0))
	for capability: Dictionary in PLUGIN_CAPABILITIES:
		var check: CheckBox = CheckBox.new()
		check.text = str(capability["label"])
		_plugin_capabilities_box.add_child(check)
		_plugin_capability_checks[str(capability["key"])] = check
	ident_box.add_child(_plugin_capabilities_box)
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
	_more_toggle.text = "▸ More (tags, includes, uses, requires)"
	_more_toggle.toggled.connect(func(pressed: bool) -> void: _set_more_expanded(pressed))
	form.add_child(_more_toggle)
	var more_box: VBoxContainer = EventSheetPopupUI.form_box()
	_sheet_type_tags_edit = _dock._add_sheet_type_field(more_box, "Tags (comma-separated)", "movement, retro, jam")
	_sheet_type_includes_edit = _dock._add_sheet_type_field(more_box, "Includes (addon sheets)", "res://eventsheet_addons/screen_shake/screen_shake.tres, …")
	_sheet_type_uses_edit = _dock._add_sheet_type_field(more_box, "Uses (addon classes)", "ScreenShake, MathHelpers - owned helper instances")
	_sheet_type_requires_edit = _dock._add_sheet_type_field(more_box, "Requires (sibling behaviors)", "ScreenShake - shows a warning badge when missing")
	_more_card = EventSheetPopupUI.titled_card("More options", more_box)
	_more_card.visible = false
	form.add_child(_more_card)
	# C4 / P0 - ONE help strip at the foot, describing whatever field or kind is focused. No READS AS
	# line: the sheet's own head, right above this dialog, IS the preview of what these fields write.
	_help_strip = EventSheetPopupUI.help_strip(
		"Kind · %s" % TYPE_LABELS[0], TYPE_HINTS[0], "", "", 440.0)
	form.add_child(_help_strip)
	_help_strip.follow_option(_sheet_type_option, _kind_help)
	_help_strip.follow(_sheet_type_name_edit, "Name · class_name",
		"How this script is known to the project and the Add Node dialog. Letters, digits and underscores; it must not be a class Godot already has.")
	_help_strip.follow(_sheet_type_host_edit, "Extends",
		"The class this sheet builds on: everything that class can do, this sheet can do. Type to get suggestions, or drop a node from the Scene dock onto this dialog.")
	_help_strip.follow(_sheet_type_icon_edit, "Icon · @icon",
		"The image Godot shows for this class in the Scene dock and the Add Node dialog. Any res:// image; Browse… picks one.")
	_help_strip.follow(_sheet_type_description_edit, "Description · ##",
		"One or two sentences saying what this sheet is. Godot shows them in the Create Node dialog, and the sheet's head shows them on its own band.")
	_help_strip.follow(_sheet_type_autoload_edit, "Autoload name",
		"The name every other sheet writes to reach this one. It lives in project.godot, not in this file.")
	_help_strip.follow(_sheet_type_tool_check, "Runs in the editor too · @tool",
		"The script runs inside the editor as well as in the game, so its events fire while you are building the scene.")
	_sheet_type_dialog.add_child(EventSheetPopupUI.margined(form))
	_sheet_type_dialog.confirmed.connect(_on_sheet_type_confirmed)
	_dock.add_child(_sheet_type_dialog)


## Applies the chosen type's field set: hint text, row visibility, and the host label wording
## ("Acts on" for a behavior, "Extends" for a data asset). Values are never touched - hiding is
## purely visual, so OK without edits round-trips the sheet unchanged.
func _refresh_type_ui() -> void:
	var type_index: int = _selected_type()
	var shown: Dictionary = field_visibility(type_index)
	_sheet_type_name_edit.get_parent().visible = bool(shown["name"])
	_sheet_type_icon_edit.get_parent().visible = bool(shown["icon"])
	_sheet_type_description_edit.get_parent().visible = bool(shown["description"])
	_sheet_type_host_edit.get_parent().visible = bool(shown["host"])
	_sheet_type_autoload_edit.get_parent().visible = bool(shown["autoload"])
	_sheet_type_family_check.visible = bool(shown["family"])
	_plugin_capabilities_box.visible = bool(shown["plugin_capabilities"])
	match type_index:
		2:
			_host_label.text = "Acts on (parent)"
		5:
			_host_label.text = "Extends (data type)"
		_:
			_host_label.text = "Extends"
	_host_menu.visible = type_index != 5  # the node shortlist makes no sense for a Resource host
	_refresh_identity_preview()
	if _sheet_type_dialog.visible:
		_sheet_type_dialog.reset_size()


## Rebuilds the suggestion popup for the typed host text. Shown only while the field has focus and
## there is something to offer; an exact match or no match closes it, so it never lingers as noise.
func _refresh_host_suggestions(typed: String) -> void:
	if _host_suggest == null or not _sheet_type_host_edit.has_focus():
		return
	_host_suggest_items = host_candidates(typed)
	_host_suggest_index = -1
	if _host_suggest_items.is_empty():
		_host_suggest.hide()
		return
	_host_suggest.clear()
	for candidate: String in _host_suggest_items:
		# The editor's own class icon when it has one (a Script glyph for project classes) - the same
		# visual language as Godot's Create Node dialog, so classes are recognizable at a glance.
		var icon_name: String = candidate if _dock.has_theme_icon(candidate, "EditorIcons") else "Script"
		if _dock.has_theme_icon(icon_name, "EditorIcons"):
			_host_suggest.add_icon_item(_dock.get_theme_icon(icon_name, "EditorIcons"), candidate)
		else:
			_host_suggest.add_item(candidate)
	_host_suggest.position = Vector2i(_sheet_type_host_edit.get_screen_position() + Vector2(0.0, _sheet_type_host_edit.size.y))
	_host_suggest.reset_size()
	if not _host_suggest.visible:
		_host_suggest.popup()


func _accept_host_suggestion(index: int) -> void:
	if index < 0 or index >= _host_suggest_items.size():
		return
	_sheet_type_host_edit.text = _host_suggest_items[index]
	_sheet_type_host_edit.caret_column = _sheet_type_host_edit.text.length()
	_host_suggest.hide()
	_sheet_type_host_edit.grab_focus()
	_refresh_identity_preview()


## Keyboard-first suggestion flow while the caret STAYS in the field: Down opens/advances the
## highlight, Up retreats, Enter accepts the highlighted (or only) match, Escape dismisses without
## touching the dialog. Plain typing keeps flowing to the LineEdit untouched.
func _on_host_edit_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed:
		return
	match key_event.keycode:
		KEY_DOWN:
			if not _host_suggest.visible:
				_refresh_host_suggestions(_sheet_type_host_edit.text)
			elif _host_suggest_index < _host_suggest_items.size() - 1:
				_host_suggest_index += 1
				_host_suggest.set_focused_item(_host_suggest_index)
			_sheet_type_host_edit.accept_event()
		KEY_UP:
			if _host_suggest.visible and _host_suggest_index > 0:
				_host_suggest_index -= 1
				_host_suggest.set_focused_item(_host_suggest_index)
				_sheet_type_host_edit.accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			if _host_suggest.visible:
				_accept_host_suggestion(_host_suggest_index if _host_suggest_index >= 0 else 0)
				_sheet_type_host_edit.accept_event()
		KEY_ESCAPE:
			if _host_suggest.visible:
				_host_suggest.hide()
				_sheet_type_host_edit.accept_event()


## The FileSystem picker for the class icon - browse res:// images instead of typing a path.
## Scene-dock node drag payloads carry {type: "nodes", nodes: [NodePath...]}.
func _can_drop_node(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("type", "")) == "nodes" \
		and not ((data as Dictionary).get("nodes", []) as Array).is_empty()


func _drop_node(_at_position: Vector2, data: Variant) -> void:
	var node_paths: Array = (data as Dictionary).get("nodes", [])
	var dropped: Node = _dock.get_node_or_null(node_paths[0]) if not node_paths.is_empty() else null
	if dropped == null:
		return
	# The host class the node ACTUALLY is: its script's class_name when it has one (that is the
	# class a sheet would be controlling), else the engine class.
	var host_class: String = ""
	var node_script: Script = dropped.get_script() as Script
	if node_script != null:
		host_class = str(node_script.get_global_name())
	if host_class.is_empty():
		host_class = dropped.get_class()
	var shown: Dictionary = field_visibility(_selected_type())
	if not bool(shown.get("host", false)):
		_dock._set_status("%s doesn't take a host class - the dropped node's %s was not applied." % [
			TYPE_LABELS[_selected_type()], host_class], true)
		return
	_sheet_type_host_edit.text = host_class
	_refresh_identity_preview()
	_dock._set_status("Host set from the dropped node: %s (%s)." % [dropped.name, host_class])


func _open_icon_file_dialog() -> void:
	if _icon_file_dialog == null:
		_icon_file_dialog = EditorFileDialog.new()
		_icon_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_icon_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_icon_file_dialog.add_filter("*.svg, *.png, *.webp", "Images")
		_icon_file_dialog.file_selected.connect(func(path: String) -> void:
			_sheet_type_icon_edit.text = path)
		_dock.add_child(_icon_file_dialog)
	_icon_file_dialog.popup_centered_ratio(0.5)


func _refresh_identity_preview() -> void:
	var own_class_name: String = _dock._current_sheet.custom_class_name if _dock._current_sheet != null else ""
	_ships_as.text = identity_preview(
		_selected_type(),
		_sheet_type_name_edit.text,
		_sheet_type_host_edit.text,
		_sheet_type_autoload_edit.text,
		own_class_name
	)


func _set_more_expanded(expanded: bool) -> void:
	if _more_toggle == null:
		return
	_more_toggle.set_pressed_no_signal(expanded)
	_more_toggle.text = ("▾" if expanded else "▸") + " More (tags, includes, uses, requires)"
	_more_card.visible = expanded
	if _sheet_type_dialog != null and _sheet_type_dialog.visible:
		_sheet_type_dialog.reset_size()


func _on_sheet_type_confirmed() -> void:
	_dock._apply_sheet_type_settings(
		_selected_type(),
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
	if _selected_type() == 7:
		_seed_plugin_capabilities()


## Appends the events each newly-ticked Editor-plugin capability needs. Runs AFTER the type has been
## applied, and re-reads _current_sheet rather than holding a reference across that edit: the undo
## funnel commits by replacing resources with snapshot duplicates, so the sheet object from before is
## already stale. Only capabilities the sheet does not have are written, so OK is safe to press twice.
func _seed_plugin_capabilities() -> void:
	var wanted: Array[Dictionary] = []
	for capability: Dictionary in PLUGIN_CAPABILITIES:
		var check: CheckBox = _plugin_capability_checks.get(str(capability["key"])) as CheckBox
		if check != null and check.button_pressed and not sheet_has_capability(_dock._current_sheet, str(capability["key"])):
			wanted.append(capability)
	if wanted.is_empty():
		return
	var labels: PackedStringArray = PackedStringArray()
	for capability: Dictionary in wanted:
		labels.append(str(capability["label"]))
	var added: bool = _dock._perform_undoable_sheet_edit("Add Plugin Capabilities", func() -> bool:
		var enabled: EventRow = _ensure_plugin_lifecycle_event("OnPluginEnabled")
		var disabled: EventRow = _ensure_plugin_lifecycle_event("OnPluginDisabled")
		for capability: Dictionary in wanted:
			var add_action: ACEAction = _build_capability_action(str(capability["add"]))
			if add_action != null:
				enabled.actions.append(add_action)
			var remove_action: ACEAction = _build_capability_action(str(capability["remove"]))
			if remove_action != null:
				disabled.actions.append(remove_action)
		return true
	)
	if added:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Plugin now adds %s." % ", ".join(labels))


## The sheet's On Plugin Enabled / On Plugin Disabled event, reused when it is already there so a
## second capability joins the same event instead of opening a second one saying the same thing.
func _ensure_plugin_lifecycle_event(trigger_id: String) -> EventRow:
	for entry: Variant in _dock._current_sheet.events:
		var event: EventRow = entry as EventRow
		if event != null and event.trigger_id == trigger_id:
			return event
	var created: EventRow = EventRow.new()
	created.trigger_provider_id = "Core"
	created.trigger_id = trigger_id
	_dock._current_sheet.events.append(created)
	return created


## One capability action, built through the SAME factory the picker uses, so a seeded row and a
## hand-dropped one are the same row - parameter defaults, baked template and `{uid}` included.
func _build_capability_action(ace_id: String) -> ACEAction:
	var definition: ACEDefinition = _dock._find_definition("Core", ace_id)
	if definition == null:
		return null
	return _dock._ace_apply._create_action_from_definition(definition, {})
