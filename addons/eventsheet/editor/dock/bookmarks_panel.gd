# Godot EventSheets — the Bookmarks panel (dock subsystem)
#
# Extracted from EventSheetDock (decomposition arc, step 4): lists every Ctrl+B'd row
# from the primary pane's shared view state; activating one reveals it. The dock
# forwards its historical field names (settable — tests construct the window).
@tool
extends RefCounted
class_name EventSheetBookmarksPanel

var _dock: Control = null

func _init(dock: Control) -> void:
    _dock = dock

var window: Window = null
var list: ItemList = null

## Lists every bookmarked row; activating one reveals it (Ctrl+B marks rows).
func open() -> void:
    if window == null:
        window = Window.new()
        window.title = "Bookmarks"
        window.size = Vector2i(360, 300)
        window.close_requested.connect(func() -> void: window.hide())
        list = ItemList.new()
        list.set_anchors_preset(Control.PRESET_FULL_RECT)
        list.item_activated.connect(func(index: int) -> void:
            var target: Resource = list.get_item_metadata(index)
            if target != null and _dock._viewport != null:
                _dock._viewport.reveal_resource(target)
        )
        var card: Control = EventSheetPopupUI.titled_card("Bookmarked Rows", list)
        card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var body: Control = EventSheetPopupUI.margined(card)
        body.set_anchors_preset(Control.PRESET_FULL_RECT)
        window.add_child(body)
        _dock.add_child(window)
    refresh()
    window.popup_centered()

## Fills the bookmarks list from the primary pane (popup-free; testable headless).
func refresh() -> void:
    list.clear()
    if _dock._viewport != null:
        for flat_entry: Dictionary in _dock._viewport.get_flat_rows():
            var row_data: EventRowData = flat_entry.get("row")
            if row_data != null and row_data.bookmark_enabled and row_data.source_resource != null:
                var label: String = row_data.source_resource.get_class()
                if not row_data.spans.is_empty():
                    label = str(row_data.spans[0].text).left(60)
                var item_index: int = list.add_item("🔖 %s" % label)
                list.set_item_metadata(item_index, row_data.source_resource)
    if list.item_count == 0:
        list.add_item("(no bookmarks — Ctrl+B marks the selected row)")

