# EventForge — ACE palette
@tool
extends VBoxContainer
class_name ACEPalette

signal ace_selected(descriptor: ACEDescriptor)

const SECTION_ORDER: Array[String] = ["Conditions", "Actions", "Expressions"]

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

	for section_name: String in SECTION_ORDER:
		var section_items: Array[ACEDescriptor] = []
		for descriptor: ACEDescriptor in _descriptors:
			if descriptor == null or not _descriptor_in_section(descriptor, section_name):
				continue
			var haystack: String = "%s %s %s" % [descriptor.display_name, descriptor.ace_id, descriptor.category]
			if not query.is_empty() and not haystack.to_lower().contains(query):
				continue
			section_items.append(descriptor)

		if section_items.is_empty():
			continue

		var section: TreeItem = _tree.create_item(root)
		section.set_text(0, section_name)
		section.set_selectable(0, false)
		var category_items: Dictionary = {}
		for descriptor: ACEDescriptor in section_items:
			var category: String = descriptor.category.strip_edges()
			if category.is_empty():
				category = descriptor.provider_id if not descriptor.provider_id.is_empty() else "General"
			if not category_items.has(category):
				category_items[category] = [] as Array[ACEDescriptor]
			(category_items[category] as Array[ACEDescriptor]).append(descriptor)

		var category_names: Array[String] = []
		for category_key: Variant in category_items.keys():
			category_names.append(str(category_key))
		category_names.sort()
		for category_name: String in category_names:
			var category_node: TreeItem = _tree.create_item(section)
			category_node.set_text(0, category_name)
			category_node.set_selectable(0, false)
			var entries: Array[ACEDescriptor] = category_items[category_name] as Array[ACEDescriptor]
			for descriptor: ACEDescriptor in entries:
				var item: TreeItem = _tree.create_item(category_node)
				item.set_text(0, descriptor.display_name if not descriptor.display_name.is_empty() else descriptor.ace_id)
				item.set_metadata(0, descriptor)

func _descriptor_in_section(descriptor: ACEDescriptor, section_name: String) -> bool:
	match section_name:
		"Conditions":
			return descriptor.ace_type == ACEDescriptor.ACEType.CONDITION or descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER
		"Actions":
			return descriptor.ace_type == ACEDescriptor.ACEType.ACTION
		"Expressions":
			return descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION
		_:
			return false

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
