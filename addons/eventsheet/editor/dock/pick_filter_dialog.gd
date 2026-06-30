@tool
extends RefCounted
class_name EventSheetPickFilterDialog
# The pick-filter ("For Each") dialog: authors a per-event loop / picking filter (iterator name,
# collection kind, Where / Order-by expression fields with live GDScript completion, a presets dropdown,
# and a commit-time linter that refuses to save an expression that doesn't compile). Everything still
# compiles down to plain for/while loops. Extracted from event_sheet_dock.gd; owns its own dialog +
# widgets and reaches dock state (current sheet, undo / refresh / dirty / status, the shared
# _add_sheet_type_field field-builder, and the static _text_before_caret) through the _dock
# back-reference. The dock keeps one delegate (_open_pick_filter_dialog) for its signal / menu callers;
# the pick-filter test and the dialog render-tool reach the widgets as dock._pick.<member>.

var _dock: Control = null
var _pick_dialog: ConfirmationDialog = null
var _pick_iterator_edit: LineEdit = null
var _pick_kind_option: OptionButton = null
var _pick_collection_edit: LineEdit = null
var _pick_predicate_edit: CodeEdit = null
var _pick_order_edit: CodeEdit = null
var _pick_desc_check: CheckBox = null
var _pick_preset_option: OptionButton = null
var _pick_first_n_spin: SpinBox = null
var _pick_delete_button: Button = null
var _pick_target_event: EventRow = null
var _pick_target_index: int = -1

func init(dock: Control) -> void:
    _dock = dock

## Opens the pick-filter dialog: pick_index = -1 adds a new filter, >= 0 edits/deletes.
func open(event_resource: Resource, pick_index: int = -1) -> void:
    var event_row: EventRow = event_resource as EventRow
    if event_row == null:
        _dock._set_status("Select an event to add a pick filter.", true)
        return
    _ensure_pick_dialog()
    _pick_target_event = event_row
    _pick_target_index = pick_index
    var editing: bool = pick_index >= 0 and pick_index < event_row.pick_filters.size()
    var pick: PickFilter = event_row.pick_filters[pick_index] if editing else PickFilter.new()
    _pick_iterator_edit.text = pick.iterator_name
    _pick_kind_option.select(_pick_kind_to_option(pick.collection_kind))
    _pick_collection_edit.text = pick.collection_value if not pick.collection_value.is_empty() else pick.source_expression
    _pick_predicate_edit.text = pick.predicate_expression
    _pick_order_edit.text = pick.order_by_expression
    _pick_desc_check.button_pressed = pick.order_descending
    _pick_preset_option.select(0)
    _pick_first_n_spin.value = pick.pick_first_n
    _pick_delete_button.visible = editing
    _pick_dialog.title = "Edit Pick Filter (For Each)" if editing else "Add Pick Filter (For Each)"
    _pick_dialog.popup_centered(Vector2i(520, 300))

func _ensure_pick_dialog() -> void:
    if _pick_dialog != null:
        return
    _pick_dialog = ConfirmationDialog.new()
    var form: VBoxContainer = EventSheetPopupUI.form_box()
    form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var loop_box: VBoxContainer = EventSheetPopupUI.form_box()
    _pick_iterator_edit = _dock._add_sheet_type_field(loop_box, "Iterator name", "item")
    var kind_row: HBoxContainer = HBoxContainer.new()
    var kind_label: Label = Label.new()
    kind_label.text = "Collection"
    kind_label.custom_minimum_size = Vector2(130.0, 0.0)
    kind_row.add_child(kind_label)
    _pick_kind_option = OptionButton.new()
    _pick_kind_option.add_item("Node group")        # → get_tree().get_nodes_in_group(value)
    _pick_kind_option.add_item("Children")          # → get_children()
    _pick_kind_option.add_item("GDScript iterable") # → value verbatim (array, range(), …)
    _pick_kind_option.add_item("Repeat N times")    # → for i in range(value)
    _pick_kind_option.add_item("While (condition)") # → while value
    _pick_kind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    kind_row.add_child(_pick_kind_option)
    loop_box.add_child(kind_row)
    _pick_collection_edit = _dock._add_sheet_type_field(loop_box, "Group / expression", "enemies   or   range(3)")
    form.add_child(EventSheetPopupUI.titled_card("Loop", loop_box))
    var filter_box: VBoxContainer = EventSheetPopupUI.form_box()
    _pick_predicate_edit = _add_expression_field(filter_box, "Where (GDScript)", "item.health < 50   (optional)")
    _pick_order_edit = _add_expression_field(filter_box, "Order by (GDScript)", "item.global_position.distance_to(position)   (optional)")
    _pick_desc_check = CheckBox.new()
    _pick_desc_check.text = "Descending (highest first)"
    filter_box.add_child(_pick_desc_check)
    form.add_child(EventSheetPopupUI.titled_card("Filter & order", filter_box))
    var preset_box: VBoxContainer = EventSheetPopupUI.form_box()
    var preset_label: Label = Label.new()
    preset_label.text = "Presets (loops & picking)"
    preset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    preset_label.custom_minimum_size = Vector2(380.0, 0.0)
    preset_box.add_child(preset_label)
    _pick_preset_option = OptionButton.new()
    for preset_name: String in ["Custom…", "For (indexed)", "For Each", "For Each (ordered)", "Repeat", "While", "Pick all (group)", "Pick by comparison / evaluate", "Pick by highest value", "Pick by lowest value", "Pick nth instance", "Pick random instance", "Pick last created", "Pick overlapping point"]:
        _pick_preset_option.add_item(preset_name)
    _pick_preset_option.item_selected.connect(_apply_pick_preset)
    preset_box.add_child(_pick_preset_option)
    form.add_child(EventSheetPopupUI.titled_card("Presets", preset_box))
    var limit_box: VBoxContainer = EventSheetPopupUI.form_box()
    var n_row: HBoxContainer = HBoxContainer.new()
    var n_label: Label = Label.new()
    n_label.text = "Pick first N (0 = all)"
    n_label.custom_minimum_size = Vector2(130.0, 0.0)
    n_row.add_child(n_label)
    _pick_first_n_spin = SpinBox.new()
    _pick_first_n_spin.min_value = 0
    _pick_first_n_spin.max_value = 9999
    n_row.add_child(_pick_first_n_spin)
    limit_box.add_child(n_row)
    form.add_child(EventSheetPopupUI.titled_card("Limit", limit_box))
    _pick_delete_button = Button.new()
    _pick_delete_button.text = "Delete This Pick Filter"
    _pick_delete_button.pressed.connect(_on_pick_filter_deleted)
    form.add_child(_pick_delete_button)
    _pick_dialog.add_child(EventSheetPopupUI.margined(form))
    _pick_dialog.confirmed.connect(_on_pick_filter_confirmed)
    _dock.add_child(_pick_dialog)

func _pick_kind_to_option(kind: int) -> int:
    match kind:
        PickFilter.CollectionKind.GROUP:
            return 0
        PickFilter.CollectionKind.CHILDREN:
            return 1
        PickFilter.CollectionKind.REPEAT:
            return 3
        PickFilter.CollectionKind.WHILE:
            return 4
        _:
            return 2
func _pick_option_to_kind(option: int) -> int:
    match option:
        0:
            return PickFilter.CollectionKind.GROUP
        1:
            return PickFilter.CollectionKind.CHILDREN
        3:
            return PickFilter.CollectionKind.REPEAT
        4:
            return PickFilter.CollectionKind.WHILE
        _:
            return PickFilter.CollectionKind.EXPRESSION

## Presets: each fills the pick-filter fields with the matching loop/picking shape
## (everything still compiles to plain for/while loops — see _emit_pick_filters).
func _apply_pick_preset(index: int) -> void:
    match index:
        1:  # For (indexed)
            _pick_kind_option.select(3)
            _pick_iterator_edit.text = "i"
            _pick_collection_edit.text = "10"
            _pick_order_edit.text = ""
            _pick_predicate_edit.text = ""
        2:  # For Each
            _pick_kind_option.select(0)
            _pick_iterator_edit.text = "item"
            _pick_order_edit.text = ""
        3:  # For Each (ordered)
            _pick_kind_option.select(0)
            _pick_iterator_edit.text = "item"
            _pick_order_edit.text = "item.name"
        4:  # Repeat
            _pick_kind_option.select(3)
            _pick_iterator_edit.text = "_i"
            _pick_collection_edit.text = "10"
        5:  # While
            _pick_kind_option.select(4)
            _pick_collection_edit.text = "health > 0"
        6:  # Pick all (group)
            _pick_kind_option.select(0)
            _pick_predicate_edit.text = ""
            _pick_order_edit.text = ""
            _pick_first_n_spin.value = 0
        7:  # Pick by comparison / evaluate
            _pick_kind_option.select(0)
            _pick_predicate_edit.text = "item.health < 50"
        8:  # Pick by highest value
            _pick_kind_option.select(0)
            _pick_order_edit.text = "item.health"
            _pick_desc_check.button_pressed = true
            _pick_first_n_spin.value = 1
        9:  # Pick by lowest value
            _pick_kind_option.select(0)
            _pick_order_edit.text = "item.health"
            _pick_desc_check.button_pressed = false
            _pick_first_n_spin.value = 1
        10: # Pick nth instance
            _pick_kind_option.select(2)
            _pick_collection_edit.text = "[get_tree().get_nodes_in_group(\"enemies\")[0]]"
        11: # Pick random instance
            _pick_kind_option.select(2)
            _pick_collection_edit.text = "[get_tree().get_nodes_in_group(\"enemies\").pick_random()]"
        12: # Pick last created
            _pick_kind_option.select(2)
            _pick_collection_edit.text = "[get_tree().get_nodes_in_group(\"enemies\").back()]"
        13: # Pick overlapping point
            _pick_kind_option.select(0)
            _pick_predicate_edit.text = "item.global_position.distance_to(get_global_mouse_position()) < 32.0"

func _on_pick_filter_confirmed() -> void:
    if _pick_target_event == null:
        return
    # Commit guard: refuse to save a For Each whose collection / where / order-by doesn't compile,
    # and re-open the dialog with the error (reuses the on-save pick-filter linter; fail-open).
    var __pick_err: String = _pick_dialog_first_error()
    if not __pick_err.is_empty():
        _dock._set_status(__pick_err, true)
        _pick_dialog.popup_centered(Vector2i(520, 300))
        return
    var event_row: EventRow = _pick_target_event
    var target_index: int = _pick_target_index
    var iterator: String = _pick_iterator_edit.text.strip_edges()
    var kind: int = _pick_option_to_kind(_pick_kind_option.selected)
    var collection: String = _pick_collection_edit.text.strip_edges()
    var predicate: String = _pick_predicate_edit.text.strip_edges()
    var first_n: int = int(_pick_first_n_spin.value)
    var changed: bool = _dock._perform_undoable_sheet_edit("Edit Pick Filter", func() -> bool:
        var pick: PickFilter = event_row.pick_filters[target_index] if target_index >= 0 and target_index < event_row.pick_filters.size() else PickFilter.new()
        pick.iterator_name = iterator if not iterator.is_empty() else "item"
        pick.collection_kind = kind
        pick.collection_value = collection
        pick.predicate_expression = predicate
        pick.order_by_expression = _pick_order_edit.text.strip_edges()
        pick.order_descending = _pick_desc_check.button_pressed
        pick.pick_first_n = first_n
        if target_index < 0:
            event_row.pick_filters.append(pick)
        return true
    )
    if changed:
        _dock._refresh_after_edit()
        _dock._mark_dirty("Pick filter saved (compiles as a for-each loop).")

## Returns the first diagnostic message if the pick dialog's collection / where / order-by doesn't
## compile (reusing the on-save pick-filter linter), else "". Fail-open: no sheet -> "" (treated as OK).
func _pick_dialog_first_error() -> String:
    if _dock._current_sheet == null:
        return ""
    var temp_pick: PickFilter = PickFilter.new()
    temp_pick.enabled = true
    temp_pick.collection_kind = _pick_option_to_kind(_pick_kind_option.selected)
    temp_pick.collection_value = _pick_collection_edit.text.strip_edges()
    temp_pick.iterator_name = _pick_iterator_edit.text.strip_edges()
    temp_pick.predicate_expression = _pick_predicate_edit.text.strip_edges()
    temp_pick.order_by_expression = _pick_order_edit.text.strip_edges()
    var temp_event: EventRow = EventRow.new()
    temp_event.pick_filters.append(temp_pick)
    var diags: Array = []
    EventSheetDiagnostics._check_pick_filters(temp_event, _dock._current_sheet, diags)
    return "" if diags.is_empty() else str((diags[0] as Dictionary).get("message", "An expression doesn't compile."))

func _on_pick_filter_deleted() -> void:
    if _pick_target_event == null or _pick_target_index < 0:
        _pick_dialog.hide()
        return
    var event_row: EventRow = _pick_target_event
    var target_index: int = _pick_target_index
    var changed: bool = _dock._perform_undoable_sheet_edit("Delete Pick Filter", func() -> bool:
        if target_index < event_row.pick_filters.size():
            event_row.pick_filters.remove_at(target_index)
            return true
        return false
    )
    _pick_dialog.hide()
    if changed:
        _dock._refresh_after_edit()
        _dock._mark_dirty("Pick filter removed.")

## Like _add_sheet_type_field, but the input is a single-line CodeEdit with live GDScript completion
## (used for the pick-filter Where / Order-by fields, which take iterator-scoped expressions).
func _add_expression_field(form: VBoxContainer, label_text: String, placeholder: String) -> CodeEdit:
    var row: HBoxContainer = HBoxContainer.new()
    var label: Label = Label.new()
    label.text = label_text
    label.custom_minimum_size = Vector2(130.0, 0.0)
    row.add_child(label)
    var edit: CodeEdit = CodeEdit.new()
    edit.placeholder_text = placeholder
    edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    edit.custom_minimum_size = Vector2(0.0, 31.0)
    edit.scroll_fit_content_height = true
    edit.gutters_draw_line_numbers = false
    edit.code_completion_enabled = true
    edit.text_changed.connect(func() -> void:
        # Keep it single-line so Enter confirms the dialog instead of inserting a newline.
        if edit.text.contains("\n"):
            var caret: int = edit.get_caret_column()
            edit.text = edit.text.replace("\n", " ")
            edit.set_caret_column(mini(caret, edit.text.length()))
        edit.request_code_completion()
    )
    edit.code_completion_requested.connect(_populate_pick_completion.bind(edit))
    row.add_child(edit)
    form.add_child(row)
    return edit

## Completion for the pick-filter Where / Order-by fields: sheet variables / functions / host members
## (the shared lint symbol provider the on-save check uses) plus the current For-Each iterator name, so
## "item.health" and distance expressions complete against the same vocabulary they're validated against.
func _populate_pick_completion(edit: CodeEdit) -> void:
    if edit == null:
        return
    var before: String = _dock._text_before_caret(edit)
    for candidate: Dictionary in EventSheetGDScriptLint.completion_for_context(before, _dock._current_sheet):
        var label: String = str(candidate.get("label", ""))
        edit.add_code_completion_option(int(candidate.get("kind", CodeEdit.KIND_PLAIN_TEXT)), label, label)
    # The iterator (the loop variable) isn't a sheet symbol — surface it unless we're after a dot.
    if not before.strip_edges().ends_with("."):
        var iterator: String = _pick_iterator_edit.text.strip_edges()
        if iterator.is_empty():
            iterator = "item"
        edit.add_code_completion_option(CodeEdit.KIND_VARIABLE, iterator, iterator)
    edit.update_code_completion_options(true)
