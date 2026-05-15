# EventForge — Action picker
@tool
extends PopupPanel
class_name ActionPicker

signal action_selected(action: ACEAction)

var _search: LineEdit
var _list: ItemList
var _descriptors: Array[ACEDescriptor] = []

func _ready() -> void:
    setup()

## Opens picker and refreshes descriptor list.
func open_picker() -> void:
    setup()
    _refresh_descriptors()
    popup_centered(Vector2i(420, 320))
    _search.grab_focus()

func setup() -> void:
    if _search != null:
        return

    var root: VBoxContainer = VBoxContainer.new()
    root.custom_minimum_size = Vector2(420, 320)
    add_child(root)

    _search = LineEdit.new()
    _search.placeholder_text = "Search actions"
    _search.text_changed.connect(_on_search_changed)
    root.add_child(_search)

    _list = ItemList.new()
    _list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _list.item_activated.connect(_on_item_activated)
    _list.item_selected.connect(_on_item_selected)
    root.add_child(_list)

func _refresh_descriptors(filter_text: String = "") -> void:
    _descriptors.clear()
    for descriptor: ACEDescriptor in ACERegistry.get_builtin_descriptors():
        if descriptor == null or descriptor.ace_type != ACEDescriptor.ACEType.ACTION:
            continue
        var haystack: String = "%s %s" % [descriptor.display_name, descriptor.ace_id]
        if not filter_text.is_empty() and not haystack.to_lower().contains(filter_text.to_lower()):
            continue
        _descriptors.append(descriptor)

    _list.clear()
    for descriptor: ACEDescriptor in _descriptors:
        _list.add_item(descriptor.display_name if not descriptor.display_name.is_empty() else descriptor.ace_id)

func _emit_selection(index: int) -> void:
    if index < 0 or index >= _descriptors.size():
        return

    var descriptor: ACEDescriptor = _descriptors[index]
    var action: ACEAction = ACEAction.new()
    action.provider_id = descriptor.provider_id
    action.ace_id = descriptor.ace_id
    action.params = {}
    emit_signal("action_selected", action)
    hide()

func _on_search_changed(new_text: String) -> void:
    _refresh_descriptors(new_text.strip_edges())

func _on_item_selected(index: int) -> void:
    _emit_selection(index)

func _on_item_activated(index: int) -> void:
    _emit_selection(index)
