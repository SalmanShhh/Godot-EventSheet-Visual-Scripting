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

## Node-type sections pre-declared at the top of the "Add Event" picker, in order.
const EVENT_PICKER_GROUPS: Array[String] = [
	"CharacterBody2D", "Area2D", "Node2D", "RigidBody2D", "Timer", "AnimationPlayer"
]

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
	_window.title = "Select ACE"
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

	_search = LineEdit.new()
	_search.name = "ACEPickerSearch"
	_search.placeholder_text = "Search actions, conditions, triggers..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _refresh_tree())
	content.add_child(_search)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", GROUP_COLOR_NEUTRAL)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_hint)

	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 2
	_tree.set_column_title(0, "ACE")
	_tree.set_column_title(1, "Type")
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 96)
	_tree.set_column_titles_visible(true)
	_tree.item_activated.connect(_on_item_activated)
	content.add_child(_tree)

## Update the registry used for searching (e.g. after a hot-reload).
func set_registry(registry: EventSheetACERegistry) -> void:
	_registry = registry

## Open the picker for the given mode.
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
	_refresh_tree()
	_window.popup_centered(Vector2i(720, 520))
	_window.grab_focus()
	_search.grab_focus()

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

	var definitions: Array[ACEDefinition] = _registry.search(query)
	# Construct 3 vocabulary bridge: familiar C3 phrases also find their Godot equivalents.
	for synonym_query: String in _c3_synonym_queries(query):
		for extra_definition: ACEDefinition in _registry.search(synonym_query):
			if not definitions.has(extra_definition):
				definitions.append(extra_definition)
	for definition: ACEDefinition in definitions:
		if not _is_allowed_for_mode(definition, mode, signals_only):
			continue
		var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
		var is_node_type_group: bool = not node_type.is_empty()
		var group_key: String = node_type if is_node_type_group else _category_of(definition)
		if not group_nodes.has(group_key):
			group_nodes[group_key] = _make_group_item(root, group_key, is_node_type_group)
		var item: TreeItem = _tree.create_item(group_nodes[group_key])
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

func _on_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	var definition: ACEDefinition = item.get_metadata(0)
	if definition == null:
		return
	close()
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
