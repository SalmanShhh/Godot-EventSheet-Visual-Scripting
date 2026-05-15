# EventForge — ACE palette
@tool
extends VBoxContainer
class_name ACEPalette

signal ace_selected(descriptor: ACEDescriptor)

const SECTION_ORDER: Array[int] = [
	ACEDescriptor.ACEType.TRIGGER,
	ACEDescriptor.ACEType.CONDITION,
	ACEDescriptor.ACEType.ACTION,
	ACEDescriptor.ACEType.EXPRESSION
]

const SECTION_LABELS: Dictionary = {
	ACEDescriptor.ACEType.TRIGGER: "Triggers",
	ACEDescriptor.ACEType.CONDITION: "Conditions",
	ACEDescriptor.ACEType.ACTION: "Actions",
	ACEDescriptor.ACEType.EXPRESSION: "Expressions"
}

var _search: LineEdit
var _tree: Tree
var _descriptors: Array[ACEDescriptor] = []

func _ready() -> void:
	setup()
	refresh()

## Builds palette controls.
func setup() -> void:
	if _search != null:
		return

	_search = LineEdit.new()
	_search.placeholder_text = "Search ACEs"
	_search.text_changed.connect(_on_search_changed)
	add_child(_search)

	_tree = Tree.new()
	_tree.hide_root = true
	_tree.columns = 1
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)

## Reloads built-in ACE descriptors and applies current search filter.
func refresh() -> void:
	_descriptors = ACERegistry.get_builtin_descriptors()
	_render_tree(_search.text if _search != null else "")

func _render_tree(filter_text: String) -> void:
	if _tree == null:
		return

	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var query: String = filter_text.strip_edges().to_lower()

	for ace_type: int in SECTION_ORDER:
		var section_items: Array[ACEDescriptor] = []
		for descriptor: ACEDescriptor in _descriptors:
			if descriptor == null or descriptor.ace_type != ace_type:
				continue
			var haystack: String = "%s %s %s" % [descriptor.display_name, descriptor.ace_id, descriptor.category]
			if not query.is_empty() and not haystack.to_lower().contains(query):
				continue
			section_items.append(descriptor)

		if section_items.is_empty():
			continue

		var section: TreeItem = _tree.create_item(root)
		section.set_text(0, str(SECTION_LABELS.get(ace_type, "Other")))
		section.set_selectable(0, false)

		for descriptor: ACEDescriptor in section_items:
			var item: TreeItem = _tree.create_item(section)
			item.set_text(0, descriptor.display_name if not descriptor.display_name.is_empty() else descriptor.ace_id)
			item.set_metadata(0, descriptor)

func _emit_selected_from_item(item: TreeItem) -> void:
	if item == null:
		return
	var descriptor: Variant = item.get_metadata(0)
	if descriptor is ACEDescriptor:
		emit_signal("ace_selected", descriptor)

func _on_search_changed(new_text: String) -> void:
	_render_tree(new_text)

func _on_item_selected() -> void:
	_emit_selected_from_item(_tree.get_selected())

func _on_item_activated() -> void:
	_emit_selected_from_item(_tree.get_selected())
