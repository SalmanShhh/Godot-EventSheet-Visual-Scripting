# Godot EventSheets — the Live Values panel (dock subsystem)
#
# Extracted from EventSheetDock (decomposition arc, step 3): the streaming window
# (editable tree, nested containers), the per-pane chip forwarding, and the edit-back
# send path. The dock forwards its historical field/method names here so the test
# surface and the plugin wiring are unchanged.
@tool
extends RefCounted
class_name EventSheetLiveValuesPanel

var _dock: Control = null

func _init(dock: Control) -> void:
    _dock = dock

var window: Window = null
var label: RichTextLabel = null
var tree: Tree = null
var debugger: EventSheetLiveValuesDebugger = null

## Wired by the plugin entry point so value edits can flow back to the running game.
func setdebugger(debugger: EventSheetLiveValuesDebugger) -> void:
    debugger = debugger

## Toggles live-value streaming for this sheet (debug compiles send variable frames;
## the window shows them while the game runs). Recompile + run to start streaming.
func toggle() -> void:
    if _dock._current_sheet == null:
        return
    _dock._current_sheet.emit_live_values = not _dock._current_sheet.emit_live_values
    if _dock._current_sheet.emit_live_values:
        ensure_window()
        window.popup_centered()
        _dock._set_status("Live Values ON: recompile and run — variables stream every 0.25s while the debugger is attached.")
    else:
        if window != null:
            window.hide()
        _dock._set_status("Live Values OFF (recompile to remove the stream).")

## Lazily builds the floating Live Values window the first time it's needed. Named to match
## the dock's call site (event_sheet_dock.gd: _ensure_live_values_panel().ensure_window()).
func ensure_window() -> void:
    if window != null:
        return
    window = Window.new()
    window.title = "Live Values"
    window.size = Vector2i(320, 380)
    window.close_requested.connect(func() -> void: window.hide())
    var live_box: VBoxContainer = VBoxContainer.new()
    live_box.set_anchors_preset(Control.PRESET_FULL_RECT)
    label = RichTextLabel.new()
    label.fit_content = true
    label.text = "Waiting for a running game…  (double-click a value to EDIT it live)"
    live_box.add_child(label)
    tree = Tree.new()
    tree.hide_root = true
    tree.columns = 2
    tree.set_column_title(0, "Variable")
    tree.set_column_title(1, "Value (editable)")
    tree.column_titles_visible = true
    tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tree.item_edited.connect(_on_live_value_edited)
    live_box.add_child(tree)
    window.add_child(live_box)
    _dock.add_child(window)

## Debugger-plugin sink (wired by the plugin entry point): one values frame -> the
## editable tree + inline chips next to variable rows in every pane (rung 3).
func update_values(values: Dictionary) -> void:
    for pane: EventSheetViewport in [_dock._viewport, _dock._split_viewport, _dock._detached_viewport]:
        if pane != null:
            pane.set_live_values(values)
    ensure_window()
    label.text = "Streaming — double-click a value to edit it in the running game."
    var value_keys: Array = values.keys()
    value_keys.sort()
    # Rebuild only when the key set changes; otherwise update in place so an
    # in-progress edit isn't stomped by the next frame.
    var rebuild: bool = tree.get_root() == null or tree.get_root().get_child_count() != value_keys.size()
    if rebuild:
        tree.clear()
        var root_item: TreeItem = tree.create_item()
        for value_key: Variant in value_keys:
            var item: TreeItem = tree.create_item(root_item)
            item.set_text(0, str(value_key))
            _fill_live_value_item(item, values[value_key])
    else:
        var item: TreeItem = tree.get_root().get_first_child()
        var index: int = 0
        while item != null and index < value_keys.size():
            item.set_text(0, str(value_keys[index]))
            if tree.get_edited() != item:
                _fill_live_value_item(item, values[value_keys[index]])
            item = item.get_next()
            index += 1

## One value -> one tree row. Dictionaries/Arrays expand into read-only subtrees
## (GDevelop's variables-debugger style); scalars stay editable leaves.
func _fill_live_value_item(item: TreeItem, value: Variant) -> void:
    for stale: TreeItem in item.get_children():
        item.remove_child(stale)
    if value is Dictionary:
        item.set_text(1, "{…} %d entries" % (value as Dictionary).size())
        item.set_editable(1, false)
        var dictionary_keys: Array = (value as Dictionary).keys()
        dictionary_keys.sort()
        for child_key: Variant in dictionary_keys:
            var child: TreeItem = item.create_child()
            child.set_text(0, str(child_key))
            _fill_live_value_item(child, (value as Dictionary)[child_key])
            child.set_editable(1, false)
    elif value is Array:
        item.set_text(1, "[…] %d items" % (value as Array).size())
        item.set_editable(1, false)
        for child_index: int in range((value as Array).size()):
            var element: TreeItem = item.create_child()
            element.set_text(0, "[%d]" % child_index)
            _fill_live_value_item(element, (value as Array)[child_index])
            element.set_editable(1, false)
    else:
        item.set_text(1, str(value))
        item.set_editable(1, true)

## Tree edit -> typed value -> running game (debug session). C3's editable debugger.
func _on_live_value_edited() -> void:
    var edited: TreeItem = tree.get_edited()
    if edited == null:
        return
    var variable_name: String = edited.get_text(0)
    var new_value: Variant = EventSheetLiveValuesDebugger.parse_edited_value(edited.get_text(1))
    if debugger != null and debugger.send_set_value(variable_name, new_value):
        _dock._set_status("Live edit: %s = %s sent to the running game." % [variable_name, str(new_value)])
    else:
        _dock._set_status("Live edit needs a streaming debug session (run the game with Live Values on).", true)

