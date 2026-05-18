# EventSheet — ACE Picker dialog component
# Owns the picker window, search field, filtered tree, and mode-aware filtering.
# Use open() to show it and connect to ace_selected to receive the chosen ACEDefinition.
@tool
class_name ACEPickerDialog
extends RefCounted

## Emitted when the user double-clicks or activates a definition in the picker.
## context is the same dictionary passed to open().
signal ace_selected(definition: ACEDefinition, context: Dictionary)

var _window: Window = null
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

	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.add_child(content)

	_search = LineEdit.new()
	_search.placeholder_text = "Search actions, conditions, triggers..."
	_search.text_changed.connect(func(_text: String) -> void: _refresh_tree())
	content.add_child(_search)

	_hint = Label.new()
	_hint.text = ""
	content.add_child(_hint)

	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 2
	_tree.set_column_title(0, "ACE")
	_tree.set_column_title(1, "Category")
	_tree.set_column_titles_visible(true)
	_tree.item_activated.connect(_on_item_activated)
	content.add_child(_tree)

## Update the registry used for searching (e.g. after a hot-reload).
func set_registry(registry: EventSheetACERegistry) -> void:
	_registry = registry

## Open the picker for the given mode.
## mode: "new_event" | "new_condition_event" | "new_sub_condition_event" | "append_condition" | "append_action"
##       | "replace_condition" | "replace_action" | "replace_trigger"
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
	_search.text = ""
	_hint.text = _build_hint_text(mode, signals_only)
	_refresh_tree()
	_window.popup_centered(Vector2i(720, 520))
	_window.grab_focus()
	_search.grab_focus()

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

func _refresh_tree() -> void:
	if _tree == null or _registry == null:
		return
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var query: String = _search.text
	var mode: String = str(_context.get("mode", "new_event"))
	var signals_only: bool = bool(_context.get("signals_only", false))
	var definitions: Array[ACEDefinition] = _registry.search(query)
	var category_nodes: Dictionary = {}
	for definition: ACEDefinition in definitions:
		if not _is_allowed_for_mode(definition, mode, signals_only):
			continue
		var category: String = definition.category
		if category.is_empty():
			category = "General"
		if not category_nodes.has(category):
			var cat_item: TreeItem = _tree.create_item(root)
			cat_item.set_text(0, category)
			category_nodes[category] = cat_item
		var item: TreeItem = _tree.create_item(category_nodes[category])
		item.set_text(0, "%s — %s" % [definition.provider_id, definition.display_name])
		item.set_text(1, category)
		if not definition.description.is_empty():
			item.set_tooltip_text(0, definition.description)
			item.set_tooltip_text(1, definition.description)
		item.set_metadata(0, definition)

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
