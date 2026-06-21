# EventSheet — ACE Picker dialog component
# Owns the picker window, search field, grouped/filtered tree, and mode-aware filtering.
# Use open() to show it and connect to ace_selected to receive the chosen ACEDefinition.
#
# Construct 3-style presentation:
#  - Entries are grouped by Godot node type (ACEDefinition.metadata.node_type) when set,
#    otherwise by category. Node-type sections are colour-coded amber; Run Context /
#    Triggers teal-green; Variables muted blue; Custom ACEs purple; others neutral.
#  - Each entry's name is tinted by ACE type (trigger = green, condition = blue,
#    action = teal, expression = purple) and its tooltip is prefixed with the type, e.g.
#    "[Condition]  Is on floor".
#  - In event-creation modes the node-type sections are pre-declared (always present) and,
#    while searching, empty sections are hidden so only matching groups remain.
@tool
class_name ACEPickerDialog
extends RefCounted

## Emitted when the user double-clicks or activates a definition in the picker.
## context is the same dictionary passed to open().
signal ace_selected(definition: ACEDefinition, context: Dictionary)

## Session-recents (C3 surfaces familiar ACEs first): last-used ACE ids, newest first.
static var _recent_ace_ids: PackedStringArray = PackedStringArray()
const RECENT_ACES_CAP := 8

## ⭐ Favorites persist in ProjectSettings — per-project and PR-shareable, like the
## composition policy. Right-click a picker entry to pin/unpin.
const FAVORITES_SETTING := "eventsheets/picker/favorites"

## Simple Mode (the newcomer view) hides the advanced "drop to code" + debug ACEs from the picker,
## so beginners aren't shown Run GDScript / Evaluate / Breakpoint / Assert / Print Rich. Keyed by
## "provider_id::ace_id" (definition.id == the descriptor's ace_id — see ace_adapter.gd).
const _SIMPLE_MODE_DENYLIST := {
	"Core::RunGDScript": true,
	"Core::EvaluateGDScript": true,
	"Core::EvaluateExpression": true,
	"Core::Breakpoint": true,
	"Core::Assert": true,
	"Core::PrintRich": true,
}

static func favorite_ids() -> PackedStringArray:
	if ProjectSettings.has_setting(FAVORITES_SETTING):
		return PackedStringArray(ProjectSettings.get_setting(FAVORITES_SETTING))
	return PackedStringArray()

static func toggle_favorite(provider_id: String, ace_id: String) -> bool:
	var favorites: PackedStringArray = favorite_ids()
	var favorite_key: String = "%s/%s" % [provider_id, ace_id]
	var existing: int = favorites.find(favorite_key)
	if existing >= 0:
		favorites.remove_at(existing)
	else:
		favorites.append(favorite_key)
	ProjectSettings.set_setting(FAVORITES_SETTING, favorites if not favorites.is_empty() else null)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	return existing < 0

## True when `query`'s characters appear in order inside `text` (case/space-insensitive)
## — the power user's "stt" reflex from C3/GDevelop pickers.
static func fuzzy_match(query: String, text: String) -> bool:
	var needle: String = query.to_lower().replace(" ", "")
	var haystack: String = text.to_lower().replace(" ", "")
	if needle.is_empty():
		return false
	var position: int = 0
	for character in needle:
		position = haystack.find(character, position)
		if position < 0:
			return false
		position += 1
	return true

## Records a use (newest first, deduped, capped) — drives the ★ Recent picker section.
static func note_recent(provider_id: String, ace_id: String) -> void:
	var recent_key: String = "%s/%s" % [provider_id, ace_id]
	var existing_recent: int = _recent_ace_ids.find(recent_key)
	if existing_recent >= 0:
		_recent_ace_ids.remove_at(existing_recent)
	_recent_ace_ids.insert(0, recent_key)
	if _recent_ace_ids.size() > RECENT_ACES_CAP:
		_recent_ace_ids.resize(RECENT_ACES_CAP)

## Node-type sections pre-declared at the top of the "Add Event" picker, in order.
const EVENT_PICKER_GROUPS: Array[String] = [
	"CharacterBody2D", "Area2D", "Node2D", "RigidBody2D", "Timer", "AnimationPlayer"
]

## Categories nest one level on this separator: "Variables: Array" renders as an Array
## folder inside the Variables section. Authors get a sub-section just by naming the
## category "Parent: Sub" — no schema change. Node-type sections never sub-nest.
const SUBCATEGORY_SEPARATOR: String = ": "

# Group-header colours (by group kind).
const GROUP_COLOR_NODE_TYPE := Color("#e0b070")  # amber — Godot class sections
const GROUP_COLOR_TRIGGER := Color("#6fd0b0")     # teal-green — run context / triggers / signals
const GROUP_COLOR_VARIABLE := Color("#8fb4e0")    # muted blue — variables
const GROUP_COLOR_CUSTOM := Color("#c79bf0")      # purple — custom / runtime providers
const GROUP_COLOR_NEUTRAL := Color("#9aa1ad")     # neutral muted — other categories

# Per-item colours (by ACE type).
const ITEM_COLOR_TRIGGER := Color("#7ee787")    # soft green
const ITEM_COLOR_CONDITION := Color("#7fb0ff")  # soft blue
const ITEM_COLOR_ACTION := Color("#5fd0c0")     # soft teal
const ITEM_COLOR_EXPRESSION := Color("#c79bf0") # soft purple

var _window: Window = null
var _header: Label = null
var _search: LineEdit = null
var _tree: Tree = null
var _info_label: RichTextLabel = null
var _info_panel: PanelContainer = null
var _favorites_list: Tree = null
var _recent_list: Tree = null
var _favorite_button: Button = null
var _add_button: Button = null
var _cancel_button: Button = null
var _selected_definition: ACEDefinition = null
var _hint: Label = null
var _context: Dictionary = {}
var _registry: EventSheetACERegistry = null

## Initialise and attach the picker window to parent_node.
## Must be called before open().
func init_dialog(parent_node: Node, registry: EventSheetACERegistry) -> void:
	_registry = registry
	if _window != null:
		return
	_window = Window.new()
	_window.title = "Add Action / Condition"
	_window.visible = false
	_window.min_size = Vector2i(640, 420)
	_window.close_requested.connect(close)
	parent_node.add_child(_window)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	_window.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 16)
	content.add_child(_header)

	# Search row: the field + a ⭐ toggle that pins/unpins the highlighted ACE.
	var search_row: HBoxContainer = HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	content.add_child(search_row)
	_search = LineEdit.new()
	_search.name = "ACEPickerSearch"
	_search.placeholder_text = "Search actions, conditions, triggers..."
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void:
		_refresh_tree()
		_select_first_match())
	_search.text_submitted.connect(func(_text: String) -> void: _activate_first_match())
	search_row.add_child(_search)
	_favorite_button = Button.new()
	_favorite_button.toggle_mode = true
	_favorite_button.text = "⭐"
	_favorite_button.tooltip_text = "Pin the highlighted entry to Favorites (or right-click any entry)."
	_favorite_button.focus_mode = Control.FOCUS_NONE
	_favorite_button.pressed.connect(_on_favorite_button_pressed)
	search_row.add_child(_favorite_button)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", GROUP_COLOR_NEUTRAL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint)

	# Body: ⭐ Favorites + ★ Recent panes on the left (Create-Node style), category tree right.
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 200
	content.add_child(split)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(180.0, 0.0)
	side.add_theme_constant_override("separation", 4)
	split.add_child(side)
	var favorites_label: Label = Label.new()
	favorites_label.text = "⭐ Favorites"
	favorites_label.add_theme_color_override("font_color", GROUP_COLOR_NEUTRAL)
	side.add_child(favorites_label)
	_favorites_list = _make_side_tree()
	side.add_child(_favorites_list)
	var recent_label: Label = Label.new()
	recent_label.text = "★ Recent"
	recent_label.add_theme_color_override("font_color", GROUP_COLOR_NEUTRAL)
	side.add_child(recent_label)
	_recent_list = _make_side_tree()
	side.add_child(_recent_list)
	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 2
	_tree.set_column_title(0, "Action / Condition")
	_tree.set_column_title(1, "Type")
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 96)
	_tree.set_column_titles_visible(true)
	_tree.item_activated.connect(_on_item_activated)
	_tree.item_selected.connect(_on_item_selected_for_info)
	_tree.gui_input.connect(_on_tree_gui_input)
	split.add_child(_tree)
	# Description panel (Create-Node style): the highlighted ACE's name, type + what it does.
	_info_panel = PanelContainer.new()
	_info_panel.custom_minimum_size = Vector2(0.0, 64.0)
	content.add_child(_info_panel)
	var info_margin: MarginContainer = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_top", 6)
	info_margin.add_theme_constant_override("margin_bottom", 6)
	_info_panel.add_child(info_margin)
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.scroll_active = false
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_margin.add_child(_info_label)
	# Action row: Cancel + Add, alongside the existing double-click / Enter-to-add.
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 6)
	content.add_child(button_row)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.pressed.connect(close)
	button_row.add_child(_cancel_button)
	_add_button = Button.new()
	_add_button.text = "Add"
	_add_button.disabled = true
	_add_button.pressed.connect(_on_add_button_pressed)
	button_row.add_child(_add_button)

## Provider returning true when Simple Mode is on (wired by the dock) — gates the denylist below.
var _simple_mode_provider: Callable = Callable()

func set_simple_mode_provider(provider: Callable) -> void:
	_simple_mode_provider = provider

## Update the registry used for searching (e.g. after a hot-reload).
func set_registry(registry: EventSheetACERegistry) -> void:
	_registry = registry

## Open the picker for the given mode.
## Selects + reveals the entry for an ace id — the double-click-to-replace flow
## opens the picker focused on what's being replaced. Ancestors expand first:
## selecting inside a collapsed group is invisible, which reads as "not selected".
func preselect(ace_id: String) -> void:
	if _tree == null or ace_id.is_empty():
		return
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var item: TreeItem = stack.pop_back()
		if item == null:
			continue
		var item_meta: Variant = item.get_metadata(0)
		if item_meta is ACEDefinition and (item_meta as ACEDefinition).id == ace_id:
			var ancestor: TreeItem = item.get_parent()
			while ancestor != null:
				ancestor.collapsed = false
				ancestor = ancestor.get_parent()
			item.select(0)
			_tree.scroll_to_item(item)
			return
		stack.push_back(item.get_next())
		stack.push_back(item.get_first_child())

## mode: "new_event" | "new_condition_event" | "new_sub_condition_event" | "append_condition"
##       | "append_action" | "replace_condition" | "replace_action" | "replace_trigger"
## signals_only: restrict results to signal triggers
## selected_resource: the currently selected EventRow (for context passing)
func open(mode: String, signals_only: bool, selected_resource: Resource, extra_context: Dictionary = {}) -> void:
	if _window == null:
		push_error("ACEPickerDialog.open() called before init_dialog().")
		return
	_context = {
		"mode": mode,
		"signals_only": signals_only,
		"selected_resource": selected_resource
	}
	for key in extra_context.keys():
		_context[key] = extra_context[key]
	var title: String = _title_for_mode(mode, signals_only)
	_window.title = title
	_header.text = title
	_search.text = ""
	_hint.text = _build_hint_text(mode, signals_only)
	_selected_definition = null
	if _add_button != null:
		_add_button.disabled = true
	if _favorite_button != null:
		_favorite_button.set_pressed_no_signal(false)
	_update_info_panel(null)
	_refresh_tree()
	_refresh_side_panes()
	_select_first_match()
	_window.popup_centered(Vector2i(720, 520))
	_window.grab_focus()
	_search.grab_focus()
	# Deferred so it lands AFTER the popup and any visibility-driven refresh —
	# callers preselect via context instead of racing the open sequence.
	if _context.has("preselect_ace_id"):
		call_deferred("preselect", str(_context.get("preselect_ace_id")))

func _title_for_mode(mode: String, signals_only: bool) -> String:
	if signals_only:
		return "Add Event"
	match mode:
		"new_event", "new_condition_event":
			return "Add Event"
		"new_sub_condition_event":
			return "Add Sub-Event"
		"append_condition":
			return "Add Condition"
		"append_action":
			return "Add Action"
		"replace_condition":
			return "Replace Condition"
		"replace_trigger":
			return "Replace Trigger"
		"replace_action":
			return "Replace Action"
		_:
			return "Add Event"

func _build_hint_text(mode: String, signals_only: bool) -> String:
	if signals_only:
		return "Select a signal trigger ACE to create a signal event."
	match mode:
		"new_condition_event":
			return "Select a condition or trigger ACE to create a new event."
		"new_sub_condition_event":
			return "Select a condition or trigger ACE to create a nested sub-condition event."
		"append_condition":
			return "Select a condition or trigger ACE to append to the selected event."
		"append_action":
			return "Select an action ACE to append to the selected event."
		"replace_condition":
			return "Select a condition ACE to replace the current condition."
		"replace_trigger":
			return "Select a trigger ACE to replace the current trigger."
		"replace_action":
			return "Select an action ACE to replace the current action."
		_:
			return "Select an ACE to create a new event."

## Construct 3 phrase → Godot search-term bridge, so C3 users typing their old vocabulary
## still find the right ACE (e.g. "on start of layout" finds _ready-based triggers).
const C3_SEARCH_SYNONYMS := {
	"on start of layout": "ready",
	"start of layout": "ready",
	"every tick": "process",
	"on created": "ready",
	"spawn": "instantiate",
	"create object": "instantiate",
	"destroy": "queue_free",
	"on collision": "body_entered",
	"is overlapping": "overlap",
	"set position": "position",
	"compare variable": "variable",
	"wait": "timer",
	"go to layout": "scene",
	"goto layout": "scene",
	"restart layout": "restart",
	"choose": "choose",
	"pick random": "random",
	"set text": "text",
	"play sound": "play",
	"play audio": "play",
	"flash": "flash",
	"fade": "tween",
	"animate": "tween",
	"pathfinding": "path",
	"find path": "path",
	"set invisible": "hide",
	"set visible": "show",
	"set opacity": "tint",
	"time scale": "time scale",
	"tokenat": "token",
	"zeropad": "zero pad",
	"fullscreen": "fullscreen",
	"compare two values": "compare values",
	"is between": "between",
	"key is down": "key",
	"on key pressed": "key pressed",
	"mouse button is down": "mouse button",
	"cursor": "mouse",
	"gamepad": "gamepad",
	"is in touch": "touch",
	"on any touch start": "on touch",
	"vibrate": "vibrate",
	"play music": "play file",
	"set master volume": "bus volume",
	"audio": "audio",
	"playback time": "playback position",
}

static func _c3_synonym_queries(query: String) -> Array[String]:
	var lowered: String = query.to_lower().strip_edges()
	var extra: Array[String] = []
	if lowered.length() < 4:
		return extra
	for phrase: String in C3_SEARCH_SYNONYMS:
		if lowered.contains(phrase) or phrase.contains(lowered):
			var mapped: String = str(C3_SEARCH_SYNONYMS[phrase])
			if not extra.has(mapped):
				extra.append(mapped)
	return extra

func _refresh_tree() -> void:
	if _tree == null or _registry == null:
		return
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var query: String = _search.text.strip_edges()
	var mode: String = str(_context.get("mode", "new_event"))
	var signals_only: bool = bool(_context.get("signals_only", false))
	var is_event_mode: bool = mode in ["new_event", "new_condition_event", "new_sub_condition_event"]
	var filtering: bool = not query.is_empty()

	var group_nodes: Dictionary = {}
	# Pre-declare node-type sections for event creation so they appear in a stable order.
	# While filtering, empty pre-declared sections are hidden (created on demand below).
	if is_event_mode and not signals_only and not filtering:
		for node_type: String in EVENT_PICKER_GROUPS:
			group_nodes[node_type] = _make_group_item(root, node_type, true)

	# ⭐ Favorites + ★ Recent now live in dedicated left panes (see _refresh_side_panes), not as
	# in-tree groups — so they stay visible while you browse categories, Create-Node style.

	var definitions: Array[ACEDefinition] = _registry.search(query)
	# Construct 3 vocabulary bridge: familiar C3 phrases also find their Godot equivalents.
	for synonym_query: String in _c3_synonym_queries(query):
		for extra_definition: ACEDefinition in _registry.search(synonym_query):
			if not definitions.has(extra_definition):
				definitions.append(extra_definition)
	# Fuzzy fallback ("stt" -> Set Time Scale): subsequence matches on the display name
	# join AFTER exact + synonym hits, capped so noise never buries real matches.
	if filtering and query.length() >= 2:
		var fuzzy_added: int = 0
		for candidate: ACEDefinition in _registry.get_all_definitions():
			if fuzzy_added >= 12:
				break
			if definitions.has(candidate):
				continue
			if fuzzy_match(query, candidate.display_name):
				definitions.append(candidate)
				fuzzy_added += 1
	for definition: ACEDefinition in definitions:
		if not _is_allowed_for_mode(definition, mode, signals_only):
			continue
		var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
		var is_node_type_group: bool = not node_type.is_empty()
		var group_key: String = node_type if is_node_type_group else _category_of(definition)
		var group_item: TreeItem = _resolve_group_item(root, group_nodes, group_key, is_node_type_group)
		var item: TreeItem = _tree.create_item(group_item)
		item.set_text(0, _item_label(definition))
		var item_icon: Texture2D = resolve_definition_icon(definition)
		if item_icon != null:
			item.set_icon(0, item_icon)
			item.set_icon_max_width(0, 16)
		item.set_custom_color(0, _item_color_for(definition.ace_type))
		item.set_text(1, _ace_type_label(definition.ace_type))
		item.set_custom_color(1, _item_color_for(definition.ace_type))
		item.set_tooltip_text(0, _item_tooltip(definition))
		item.set_tooltip_text(1, _item_tooltip(definition))
		item.set_metadata(0, definition)

func _make_group_item(root: TreeItem, group_key: String, is_node_type: bool) -> TreeItem:
	var group_item: TreeItem = _tree.create_item(root)
	group_item.set_text(0, group_key)
	# Node-type sections show the class's editor icon (C3 users expect the object's icon
	# next to its name everywhere).
	if is_node_type:
		var class_icon: Texture2D = editor_icon(group_key)
		if class_icon != null:
			group_item.set_icon(0, class_icon)
			group_item.set_icon_max_width(0, 16)
	group_item.set_custom_color(0, _group_color_for(group_key, is_node_type))
	group_item.set_selectable(0, false)
	group_item.set_selectable(1, false)
	return group_item

## Resolves (creating as needed) the tree item a row hangs under. Categories using the
## "Parent: Sub" separator nest one level — the parent folder is shared with any flat ACEs
## in the same category, and each distinct sub gets its own folder. Node-type sections and
## separator-less categories stay flat, exactly as before.
func _resolve_group_item(root: TreeItem, group_nodes: Dictionary, group_key: String, is_node_type: bool) -> TreeItem:
	if group_nodes.has(group_key):
		return group_nodes[group_key]
	var parts: PackedStringArray = PackedStringArray() if is_node_type else split_subcategory(group_key)
	if parts.is_empty():
		var flat_item: TreeItem = _make_group_item(root, group_key, is_node_type)
		group_nodes[group_key] = flat_item
		return flat_item
	var parent_key: String = parts[0]
	var child_label: String = parts[1]
	var parent_item: TreeItem
	if group_nodes.has(parent_key):
		parent_item = group_nodes[parent_key]
	else:
		parent_item = _make_group_item(root, parent_key, false)
		group_nodes[parent_key] = parent_item
	var sub_item: TreeItem = _make_sub_group_item(parent_item, child_label)
	group_nodes[group_key] = sub_item
	return sub_item

## A nested sub-category folder ("Array" inside "Variables"): same non-selectable folder
## styling as a top-level group, parented under its category instead of the tree root.
func _make_sub_group_item(parent_item: TreeItem, child_label: String) -> TreeItem:
	var sub_item: TreeItem = _tree.create_item(parent_item)
	sub_item.set_text(0, child_label)
	sub_item.set_custom_color(0, _group_color_for(child_label, false))
	sub_item.set_selectable(0, false)
	sub_item.set_selectable(1, false)
	return sub_item

## Splits a "Parent: Sub" category into [parent, child] (both stripped). Returns an empty
## array when there is no sub-category separator, so the category renders as a flat group.
## Pure + static so the grouping can be unit-tested without a display server.
static func split_subcategory(group_key: String) -> PackedStringArray:
	var index: int = group_key.find(SUBCATEGORY_SEPARATOR)
	if index == -1:
		return PackedStringArray()
	var parent_name: String = group_key.substr(0, index).strip_edges()
	var child_name: String = group_key.substr(index + SUBCATEGORY_SEPARATOR.length()).strip_edges()
	if parent_name.is_empty() or child_name.is_empty():
		return PackedStringArray()
	return PackedStringArray([parent_name, child_name])

## Resolves an ACE's icon, in C3-familiarity order: an explicit `res://` texture from the
## addon's @ace_icon annotation → the node type's editor class icon → a member-kind editor
## icon (signal/method/property). Returns null headless / when nothing matches, which keeps
## the previous text-only look. Static + shared so row rendering can reuse it later.
static func resolve_definition_icon(definition: ACEDefinition) -> Texture2D:
	if definition == null:
		return null
	var icon_hint: String = definition.icon.strip_edges()
	if icon_hint.begins_with("res://") and ResourceLoader.exists(icon_hint):
		var loaded: Resource = load(icon_hint)
		if loaded is Texture2D:
			return loaded
	var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
	if not node_type.is_empty():
		var class_icon: Texture2D = editor_icon(node_type)
		if class_icon != null:
			return class_icon
	match definition.ace_type:
		ACEDefinition.ACEType.TRIGGER:
			return editor_icon("MemberSignal")
		ACEDefinition.ACEType.ACTION:
			return editor_icon("MemberMethod")
		ACEDefinition.ACEType.EXPRESSION:
			return editor_icon("MemberProperty")
		ACEDefinition.ACEType.CONDITION:
			return editor_icon("MemberConstant")
	return null

## Fetches a named editor-theme icon ("EditorIcons" — class icons and member glyphs).
## Null outside the editor or when the name is unknown, so callers degrade gracefully.
static func editor_icon(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return null
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_icon(icon_name, "EditorIcons"):
		return null
	return theme.get_icon(icon_name, "EditorIcons")

func _category_of(definition: ACEDefinition) -> String:
	var category: String = definition.category.strip_edges()
	return category if not category.is_empty() else "General"

func _item_label(definition: ACEDefinition) -> String:
	if definition.provider_id.is_empty() or definition.provider_id == "Core":
		return definition.display_name
	return "%s  ·  %s" % [definition.display_name, definition.provider_id]

func _item_tooltip(definition: ACEDefinition) -> String:
	var body: String = definition.description if not definition.description.is_empty() else definition.display_name
	return "[%s]  %s" % [_ace_type_label(definition.ace_type), body]

func _ace_type_label(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.TRIGGER:
			return "Trigger"
		ACEDefinition.ACEType.CONDITION:
			return "Condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "Expression"
		_:
			return "Action"

func _item_color_for(ace_type: int) -> Color:
	match ace_type:
		ACEDefinition.ACEType.TRIGGER:
			return ITEM_COLOR_TRIGGER
		ACEDefinition.ACEType.CONDITION:
			return ITEM_COLOR_CONDITION
		ACEDefinition.ACEType.EXPRESSION:
			return ITEM_COLOR_EXPRESSION
		_:
			return ITEM_COLOR_ACTION

func _group_color_for(group_key: String, is_node_type: bool) -> Color:
	if is_node_type:
		return GROUP_COLOR_NODE_TYPE
	var key: String = group_key.to_lower()
	if key.contains("run context") or key.contains("trigger") or key.contains("signal"):
		return GROUP_COLOR_TRIGGER
	if key.contains("variable"):
		return GROUP_COLOR_VARIABLE
	if key.contains("custom"):
		return GROUP_COLOR_CUSTOM
	return GROUP_COLOR_NEUTRAL

func _is_allowed_for_mode(definition: ACEDefinition, mode: String, signals_only: bool) -> bool:
	if definition == null:
		return false
	# Simple Mode hides the advanced / code-drop ACEs (Run GDScript, Evaluate, Breakpoint, …).
	if _simple_mode_provider.is_valid() and bool(_simple_mode_provider.call()) and _SIMPLE_MODE_DENYLIST.has(definition.provider_id + "::" + definition.id):
		return false
	if signals_only:
		# Use source_kind metadata for precise signal detection (set by the generator).
		# Fall back to category string only when metadata is absent.
		var source_kind: String = str(definition.metadata.get("source_kind", ""))
		var is_signal: bool = source_kind == "signal" or (source_kind.is_empty() and definition.category.to_lower().contains("signal"))
		return definition.ace_type == ACEDefinition.ACEType.TRIGGER and is_signal
	match mode:
		"new_condition_event":
			return definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]
		"new_sub_condition_event":
			return definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]
		"append_condition":
			return definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]
		"append_action":
			return definition.ace_type == ACEDefinition.ACEType.ACTION
		"replace_condition":
			return definition.ace_type == ACEDefinition.ACEType.CONDITION
		"replace_trigger":
			return definition.ace_type == ACEDefinition.ACEType.TRIGGER
		"replace_action":
			return definition.ace_type == ACEDefinition.ACEType.ACTION
		_:
			return definition.ace_type in [ACEDefinition.ACEType.TRIGGER, ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.ACTION]

## C3-style bottom info pane: selecting an entry shows its description AND the exact
## GDScript it will generate — the picker doubles as a teaching surface.
func _on_item_selected_for_info() -> void:
	var selected: TreeItem = _tree.get_selected()
	var definition: ACEDefinition = selected.get_metadata(0) as ACEDefinition if selected != null else null
	# Picking in the main tree clears the side-pane highlight so there is one logical selection.
	if definition != null:
		if _favorites_list != null:
			_favorites_list.deselect_all()
		if _recent_list != null:
			_recent_list.deselect_all()
	_on_definition_selected(definition)

## Right-click pins/unpins the entry under the cursor as a ⭐ Favorite.
func _on_tree_gui_input(input_event: InputEvent) -> void:
	if not (input_event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = input_event
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var clicked: TreeItem = _tree.get_item_at_position(mouse_event.position)
	var definition: ACEDefinition = clicked.get_metadata(0) as ACEDefinition if clicked != null else null
	if definition == null:
		return
	var pinned: bool = toggle_favorite(definition.provider_id, definition.id)
	if _info_label != null:
		_info_label.text = ("⭐ Pinned %s to Favorites" if pinned else "Unpinned %s from Favorites") % definition.display_name
	if _favorite_button != null and _selected_definition == definition:
		_favorite_button.set_pressed_no_signal(pinned)
	_refresh_side_panes()

## Enter in the search box applies the first concrete match — type-and-Enter, no mouse.
## Depth-first so sub-category folders (root → parent → sub → entry) are reached too.
## Picker speed: pre-select the first concrete ACE so the description panel + Add button
## populate immediately and arrow/Enter work without a first click (type → glance → Enter).
func _select_first_match() -> void:
	if _tree == null:
		return
	var first: TreeItem = _first_definition_item(_tree.get_root())
	if first != null:
		first.select(0)
		_tree.scroll_to_item(first)

func _activate_first_match() -> void:
	var match_item: TreeItem = _first_definition_item(_tree.get_root())
	if match_item != null:
		match_item.select(0)
		_on_item_activated()

## Depth-first search for the first tree item carrying an ACEDefinition (a real ACE row),
## descending through group / sub-group folders (which carry no metadata of their own).
func _first_definition_item(item: TreeItem) -> TreeItem:
	if item == null:
		return null
	var child: TreeItem = item.get_first_child()
	while child != null:
		if child.get_metadata(0) is ACEDefinition:
			return child
		var nested: TreeItem = _first_definition_item(child)
		if nested != null:
			return nested
		child = child.get_next()
	return null

func _on_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	_commit_definition(item.get_metadata(0) as ACEDefinition if item != null else null)

## A compact single-column Tree for the ⭐ Favorites / ★ Recent side panes (Create-Node style).
func _make_side_tree() -> Tree:
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 1
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0.0, 90.0)
	tree.item_selected.connect(_on_side_item_selected.bind(tree))
	tree.item_activated.connect(_on_side_item_activated.bind(tree))
	return tree

## Fills the Favorites + Recent panes from the persisted lists, filtered to the current mode.
func _refresh_side_panes() -> void:
	if _favorites_list == null or _recent_list == null or _registry == null:
		return
	var mode: String = str(_context.get("mode", "new_event"))
	var signals_only: bool = bool(_context.get("signals_only", false))
	_populate_side_pane(_favorites_list, favorite_ids(), mode, signals_only)
	_populate_side_pane(_recent_list, _recent_ace_ids, mode, signals_only)

func _populate_side_pane(tree: Tree, keys: PackedStringArray, mode: String, signals_only: bool) -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()
	for key: String in keys:
		for candidate: ACEDefinition in _registry.get_all_definitions():
			if "%s/%s" % [candidate.provider_id, candidate.id] != key:
				continue
			if not _is_allowed_for_mode(candidate, mode, signals_only):
				break
			var item: TreeItem = tree.create_item(root)
			item.set_text(0, _item_label(candidate))
			var icon: Texture2D = resolve_definition_icon(candidate)
			if icon != null:
				item.set_icon(0, icon)
				item.set_icon_max_width(0, 16)
			item.set_custom_color(0, _item_color_for(candidate.ace_type))
			item.set_tooltip_text(0, _item_tooltip(candidate))
			item.set_metadata(0, candidate)
			break

func _on_side_item_selected(tree: Tree) -> void:
	var item: TreeItem = tree.get_selected()
	var definition: ACEDefinition = item.get_metadata(0) as ACEDefinition if item != null else null
	if definition == null:
		return
	# One logical selection across the three trees: clear the others.
	if _tree != null:
		_tree.deselect_all()
	var other: Tree = _recent_list if tree == _favorites_list else _favorites_list
	if other != null:
		other.deselect_all()
	_on_definition_selected(definition)

func _on_side_item_activated(tree: Tree) -> void:
	var item: TreeItem = tree.get_selected()
	_commit_definition(item.get_metadata(0) as ACEDefinition if item != null else null)

## Unified selection: the highlighted ACE (tree or side pane) drives the description panel, the
## ⭐ button state, and what Add / Enter will insert.
func _on_definition_selected(definition: ACEDefinition) -> void:
	_selected_definition = definition
	_update_info_panel(definition)
	if _add_button != null:
		_add_button.disabled = definition == null
	if _favorite_button != null:
		_favorite_button.set_pressed_no_signal(definition != null and _is_favorite(definition))

func _is_favorite(definition: ACEDefinition) -> bool:
	return favorite_ids().has("%s/%s" % [definition.provider_id, definition.id])

## Create-Node-style description panel: name, type + category, what it does, and its codegen.
func _update_info_panel(definition: ACEDefinition) -> void:
	if _info_label == null:
		return
	if definition == null:
		_info_label.text = ""
		return
	var description: String = definition.description if not definition.description.is_empty() else str(definition.metadata.get("display_template", definition.display_name))
	var template: String = str(definition.metadata.get("codegen_template", ""))
	var header_line: String = "[b]%s[/b]  ·  %s  ·  %s" % [definition.display_name, _ace_type_label(definition.ace_type), _category_of(definition)]
	var body: String = header_line + "\n" + description
	if not template.is_empty():
		body += "\n[code]%s[/code]" % template
	_info_label.text = body

func _on_favorite_button_pressed() -> void:
	if _selected_definition == null:
		_favorite_button.set_pressed_no_signal(false)
		return
	var pinned: bool = toggle_favorite(_selected_definition.provider_id, _selected_definition.id)
	_favorite_button.set_pressed_no_signal(pinned)
	_refresh_side_panes()

func _on_add_button_pressed() -> void:
	_commit_definition(_selected_definition)

## Single commit path for the tree, the side panes, and the Add button.
func _commit_definition(definition: ACEDefinition) -> void:
	if definition == null:
		return
	close()
	note_recent(definition.provider_id, definition.id)
	ace_selected.emit(definition, _context.duplicate(true))

func close() -> void:
	if _window == null:
		return
	_window.hide()

func is_open() -> bool:
	return _window != null and _window.visible

func get_popup_rect() -> Rect2:
	if _window == null:
		return Rect2()
	return Rect2(Vector2(_window.position), Vector2(_window.size))
