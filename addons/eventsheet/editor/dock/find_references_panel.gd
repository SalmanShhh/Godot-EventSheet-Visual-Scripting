@tool
extends RefCounted
class_name EventSheetFindReferencesPanel
# The "Find References" window: whole-symbol uses of a variable / function / signal across EVERY sheet,
# with jump-to-sheet. Symbol-aware (so `speed` never matches `move_speed`), unlike substring Find.
# Extracted from event_sheet_dock.gd to keep that file maintainable; this owns its own window / edit /
# results-tree widgets and reaches dock state (the active view + load-sheet) through the `_dock`
# back-reference, the same pattern as the other dock/ helpers.

var _dock: Control = null
var _find_refs_window: Window = null
var _find_refs_edit: LineEdit = null
var _find_refs_tree: Tree = null

func init(dock: Control) -> void:
    _dock = dock

## Find References: whole-symbol uses of a variable/function/signal across EVERY sheet, with
## jump-to-sheet — symbol-aware (so `speed` never matches `move_speed`), unlike substring Find.
func open() -> void:
    if _find_refs_window == null:
        _find_refs_window = Window.new()
        _find_refs_window.title = "Find References (whole symbol)"
        _find_refs_window.size = Vector2i(640, 460)
        _find_refs_window.close_requested.connect(func() -> void: _find_refs_window.hide())
        var box: VBoxContainer = VBoxContainer.new()
        box.set_anchors_preset(Control.PRESET_FULL_RECT)
        var body: VBoxContainer = EventSheetPopupUI.form_box()
        body.size_flags_vertical = Control.SIZE_EXPAND_FILL
        var find_box: VBoxContainer = EventSheetPopupUI.form_box()
        var row: HBoxContainer = HBoxContainer.new()
        _find_refs_edit = LineEdit.new()
        _find_refs_edit.placeholder_text = "Symbol — a variable / function / signal name…"
        _find_refs_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _find_refs_edit.text_submitted.connect(func(_t: String) -> void: _run_find_references())
        row.add_child(_find_refs_edit)
        var find_button: Button = Button.new()
        find_button.text = "Find References"
        find_button.pressed.connect(_run_find_references)
        row.add_child(find_button)
        find_box.add_child(row)
        body.add_child(EventSheetPopupUI.titled_card("Find symbol", find_box))
        _find_refs_tree = Tree.new()
        _find_refs_tree.hide_root = true
        _find_refs_tree.columns = 3
        _find_refs_tree.set_column_title(0, "Sheet")
        _find_refs_tree.set_column_title(1, "Where")
        _find_refs_tree.set_column_title(2, "Match")
        _find_refs_tree.column_titles_visible = true
        _find_refs_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _find_refs_tree.item_activated.connect(_on_find_reference_activated)
        var results_card: PanelContainer = EventSheetPopupUI.titled_card("Results", _find_refs_tree)
        results_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        body.add_child(results_card)
        box.add_child(EventSheetPopupUI.margined(body))
        _find_refs_window.add_child(box)
        _dock.add_child(_find_refs_window)
    var seed: String = _selected_symbol_text()
    if not seed.is_empty():
        _find_refs_edit.text = seed
    _find_refs_window.popup_centered()
    _find_refs_edit.grab_focus()
    if not _find_refs_edit.text.strip_edges().is_empty():
        _run_find_references()

## Populates the references tree. Returns the total count (so it's headlessly testable).
func _run_find_references() -> int:
    _find_refs_tree.clear()
    var root: TreeItem = _find_refs_tree.create_item()
    var symbol: String = _find_refs_edit.text.strip_edges()
    if symbol.is_empty():
        return 0
    var total: int = 0
    for entry: Dictionary in EventSheetFindReferences.find_in_project(symbol):
        var sheet_path: String = str(entry.get("sheet", ""))
        for reference: Dictionary in (entry.get("references", []) as Array):
            var item: TreeItem = _find_refs_tree.create_item(root)
            item.set_text(0, sheet_path.get_file())
            item.set_text(1, "%s ×%d" % [str(reference.get("kind", "")), int(reference.get("count", 0))])
            item.set_text(2, str(reference.get("preview", "")))
            item.set_metadata(0, sheet_path)
            total += int(reference.get("count", 0))
    var summary: TreeItem = _find_refs_tree.create_item(root)
    summary.set_text(0, "%d reference(s)" % total)
    if total == 0:
        summary.set_text(1, "no whole-symbol matches")
    return total

func _on_find_reference_activated() -> void:
    var item: TreeItem = _find_refs_tree.get_selected()
    if item == null:
        return
    var path: String = str(item.get_metadata(0)) if item.get_metadata(0) != null else ""
    if not path.is_empty() and ResourceLoader.exists(path):
        _dock._load_sheet_from_path(path)

## Seeds the search box from a selected local-variable or signal row (a quick "find this").
func _selected_symbol_text() -> String:
    var resource: Variant = _dock._active_view().get_selected_context().get("source_resource", null)
    if resource is LocalVariable:
        return (resource as LocalVariable).name
    if resource is SignalRow:
        return (resource as SignalRow).signal_name
    return ""
