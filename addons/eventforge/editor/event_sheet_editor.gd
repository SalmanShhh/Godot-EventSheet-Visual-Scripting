# EventForge — Event sheet editor
@tool
extends Control
class_name EventSheetEditor

enum ViewMode {
    EVENT_SHEET,
    GDSCRIPT,
    SPLIT
}

var current_sheet: EventSheetResource = null
var current_view_mode: ViewMode = ViewMode.SPLIT
var generated_code_preview: String = ""

var _selected_row: EventRow = null
var _pending_row_for_condition: EventRow = null
var _pending_row_for_action: EventRow = null

var _toolbar: SheetToolbar
var _main_split: HSplitContainer
var _sheet_area: HSplitContainer
var _ace_palette: ACEPalette
var _row_scroll: ScrollContainer
var _row_list: VBoxContainer
var _gdscript_panel: GDScriptPanel
var _status_label: Label
var _condition_picker: ConditionPicker
var _action_picker: ActionPicker

func _ready() -> void:
    _build_ui()
    create_new_sheet()
    set_view_mode(ViewMode.SPLIT)

## Assigns an active sheet resource and refreshes editor content.
func set_sheet(sheet: EventSheetResource) -> void:
    current_sheet = sheet
    _selected_row = null
    refresh_rows()
    refresh_preview()

## Creates a new in-memory sheet and resets editor state.
func create_new_sheet() -> void:
    var sheet: EventSheetResource = EventSheetResource.new()
    sheet.host_class = "Node"
    sheet.events = []
    set_sheet(sheet)
    _set_status("New in-memory sheet created.")

## Rebuilds visible event rows.
func refresh_rows() -> void:
    if _row_list == null:
        return

    for child: Node in _row_list.get_children():
        child.queue_free()

    if current_sheet == null:
        return

    for entry: Resource in current_sheet.events:
        if not (entry is EventRow):
            continue
        var row: EventRow = entry
        var row_ui: EventRowUI = EventRowUI.new()
        row_ui.set_row(row)
        row_ui.set_selected(row == _selected_row)
        row_ui.selected.connect(_on_row_selected)
        row_ui.delete_requested.connect(_on_row_delete_requested)
        row_ui.add_condition_requested.connect(_on_add_condition_requested)
        row_ui.add_action_requested.connect(_on_add_action_requested)
        _row_list.add_child(row_ui)

## Recompiles the sheet to update the generated code preview panel.
func refresh_preview() -> void:
    if _gdscript_panel == null:
        return

    if current_sheet == null:
        generated_code_preview = "# No sheet loaded\n"
        _gdscript_panel.set_source(generated_code_preview)
        _set_status("No sheet loaded.")
        return

    var output_path: String = ""
    if current_sheet.resource_path.is_empty():
        output_path = "res://eventforge_preview_generated.gd"

    var result: Dictionary = SheetCompiler.compile(current_sheet, output_path)
    generated_code_preview = str(result.get("output", ""))
    _gdscript_panel.set_source(generated_code_preview)

    if bool(result.get("success", false)):
        var warnings: Array = result.get("warnings", [])
        if warnings.is_empty():
            _set_status("Compile succeeded.")
        else:
            _set_status("Compile succeeded with warnings: %s" % "; ".join(warnings))
    else:
        var errors: Array = result.get("errors", [])
        _set_status("Compile failed: %s" % "; ".join(errors))

## Applies Event Sheet / GDScript / Split layout visibility.
func set_view_mode(mode: ViewMode) -> void:
    current_view_mode = mode
    if _toolbar != null:
        _toolbar.set_view_mode(mode)

    if _sheet_area == null or _gdscript_panel == null:
        return

    match mode:
        ViewMode.EVENT_SHEET:
            _sheet_area.visible = true
            _gdscript_panel.visible = false
        ViewMode.GDSCRIPT:
            _sheet_area.visible = false
            _gdscript_panel.visible = true
        ViewMode.SPLIT:
            _sheet_area.visible = true
            _gdscript_panel.visible = true

func _build_ui() -> void:
    if _toolbar != null:
        return

    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    var root: VBoxContainer = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(root)

    _toolbar = SheetToolbar.new()
    _toolbar.setup()
    _toolbar.new_sheet_requested.connect(create_new_sheet)
    _toolbar.add_event_requested.connect(_on_add_event_requested)
    _toolbar.compile_requested.connect(refresh_preview)
    _toolbar.refresh_preview_requested.connect(refresh_preview)
    _toolbar.view_mode_changed.connect(_on_toolbar_view_mode_changed)
    root.add_child(_toolbar)

    _main_split = HSplitContainer.new()
    _main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_main_split)

    _sheet_area = HSplitContainer.new()
    _sheet_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _sheet_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _main_split.add_child(_sheet_area)

    _ace_palette = ACEPalette.new()
    _ace_palette.custom_minimum_size = Vector2(260, 260)
    _ace_palette.refresh()
    _sheet_area.add_child(_ace_palette)

    _row_scroll = ScrollContainer.new()
    _row_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _row_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _sheet_area.add_child(_row_scroll)

    _row_list = VBoxContainer.new()
    _row_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _row_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _row_scroll.add_child(_row_list)

    _gdscript_panel = GDScriptPanel.new()
    _gdscript_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _gdscript_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _main_split.add_child(_gdscript_panel)

    _status_label = Label.new()
    _status_label.text = "Ready"
    root.add_child(_status_label)

    _condition_picker = ConditionPicker.new()
    _condition_picker.condition_selected.connect(_on_condition_selected)
    add_child(_condition_picker)

    _action_picker = ActionPicker.new()
    _action_picker.action_selected.connect(_on_action_selected)
    add_child(_action_picker)

func _on_add_event_requested() -> void:
    if current_sheet == null:
        create_new_sheet()

    var row: EventRow = EventRow.new()
    current_sheet.events.append(row)
    _selected_row = row
    refresh_rows()
    _mark_preview_dirty()

func _on_row_selected(row: EventRow) -> void:
    _selected_row = row
    refresh_rows()

func _on_row_delete_requested(row: EventRow) -> void:
    if current_sheet == null:
        return

    var events: Array = current_sheet.events
    for index: int in range(events.size()):
        if events[index] == row:
            events.remove_at(index)
            break
    if _selected_row == row:
        _selected_row = null
    refresh_rows()
    _mark_preview_dirty()

func _on_add_condition_requested(row: EventRow) -> void:
    _pending_row_for_condition = row
    if _condition_picker != null:
        _condition_picker.open_picker()

func _on_add_action_requested(row: EventRow) -> void:
    _pending_row_for_action = row
    if _action_picker != null:
        _action_picker.open_picker()

func _on_condition_selected(condition: ACECondition) -> void:
    if _pending_row_for_condition == null or condition == null:
        return
    _pending_row_for_condition.conditions.append(condition)
    _pending_row_for_condition = null
    refresh_rows()
    _mark_preview_dirty()

func _on_action_selected(action: ACEAction) -> void:
    if _pending_row_for_action == null or action == null:
        return
    _pending_row_for_action.actions.append(action)
    _pending_row_for_action = null
    refresh_rows()
    _mark_preview_dirty()

func _on_toolbar_view_mode_changed(mode: int) -> void:
    match mode:
        ViewMode.EVENT_SHEET:
            set_view_mode(ViewMode.EVENT_SHEET)
        ViewMode.GDSCRIPT:
            set_view_mode(ViewMode.GDSCRIPT)
        ViewMode.SPLIT:
            set_view_mode(ViewMode.SPLIT)

func _mark_preview_dirty() -> void:
    _set_status("Preview may be out of date — click Refresh Preview.")

func _set_status(message: String) -> void:
    if _status_label != null:
        _status_label.text = message
