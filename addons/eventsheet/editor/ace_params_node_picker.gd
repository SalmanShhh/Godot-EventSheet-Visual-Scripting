@tool
extends RefCounted
class_name ACEParamsNodePicker
# The "Pick Node" dialog opened by the 🔍 button next to an expression field — a large-project
# scene-node search that hands a node reference back into the field. Extracted from
# ace_params_dialog.gd to keep that file maintainable; it owns all its own widgets and reaches the
# host ACEParamsDialog (the value-bearing _fields, the live ƒx validation, node-reference formatting)
# through the `_host` back-reference, the same pattern as the other editor helpers.
#
# Search modes (all case-insensitive):
#   plain text        -> matches node NAME, CLASS or PATH ("Area2D" finds every area)
#   group:enemies     -> nodes in that Godot group
#   script:Enemy      -> nodes whose attached script matches (global class or filename)
#   scene:query       -> CROSS-SCENE: scans res:// .tscn files for matching node headers
# Filter chips (2D/3D/UI/Audio/Physics) pre-filter by base class. Recently picked nodes
# surface first; "Used in sheet" lists every $Ref this sheet already makes, tinted red
# when the node no longer exists in the edited scene (broken-reference audit).
#
# The host (ACEParamsDialog) keeps a one-line delegate for every method/var/static reached from
# outside (tests, tools, the host's own field-builder) so callers and the by-class-name static
# calls (ACEParamsDialog.node_matches_query, …) keep working unchanged.

# The host ACEParamsDialog instance (named _host, not _dialog, because the host's OWN field is
# literally `var _dialog: ConfirmationDialog` — `_host._dialog` reads unambiguously, `_dialog._dialog`
# would not). ACEParamsDialog extends RefCounted (not Control), so the back-ref is typed as the host
# class, and `_host._dialog` is the ConfirmationDialog this picker parents its window under.
var _host: ACEParamsDialog = null

var _node_picker_window: AcceptDialog = null
var _node_picker_unique_button: Button = null
var _node_picker_tree: Tree = null
var _node_picker_search: LineEdit = null
var _node_picker_target_key: String = ""
var _node_picker_chips: Dictionary = {}  # chip label -> Button (toggle)
var _node_picker_used_toggle: Button = null
var _node_picker_recents: PackedStringArray = PackedStringArray()

const NODE_PICKER_CHIP_CLASSES: Dictionary = {
    "2D": ["Node2D"], "3D": ["Node3D"], "UI": ["Control"],
    "Audio": ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"],
    "Physics": ["CollisionObject2D", "CollisionObject3D", "Joint2D", "Joint3D"]
}
const NODE_PICKER_RECENTS_CAP := 8
const NODE_PICKER_SCENE_SCAN_CAP := 200

func init(host: ACEParamsDialog) -> void:
    _host = host

func _open_node_picker(key: String) -> void:
    _node_picker_target_key = key
    _ensure_node_picker_ui()
    _populate_node_picker()
    _node_picker_window.get_ok_button().disabled = true
    _node_picker_window.popup_centered(Vector2i(520, 560))
    _node_picker_search.grab_focus()

## Builds the picker UI lazily (separate from _open so headless tests can drive it).
func _ensure_node_picker_ui() -> void:
    if _node_picker_window == null:
        _node_picker_window = AcceptDialog.new()
        _node_picker_window.title = "Pick Node"
        _node_picker_window.min_size = Vector2i(480, 460)
        _node_picker_window.ok_button_text = "Use Node"
        _node_picker_window.get_ok_button().disabled = true
        _node_picker_window.close_requested.connect(func() -> void: _node_picker_window.hide())
        _node_picker_window.confirmed.connect(_on_node_picker_activated)
        # One-click "Make %unique": turns the selected deep node into a scene-unique node (undoable) and
        # hands back %Name — so ANY node, not just pre-marked ones, gets a flat path-free handle. The button
        # enables only for a non-root node that isn't already unique (see _on_node_picker_selection_changed).
        _node_picker_unique_button = _node_picker_window.add_button("Make %unique", true, "make_unique")
        _node_picker_unique_button.disabled = true
        _node_picker_window.custom_action.connect(_on_node_picker_custom_action)
        var box: VBoxContainer = EventSheetPopupUI.form_box()
        # Find card: the search box + the filter chips, grouped in a titled inset card.
        var find_box: VBoxContainer = EventSheetPopupUI.form_box()
        _node_picker_search = LineEdit.new()
        _node_picker_search.clear_button_enabled = true
        _node_picker_search.placeholder_text = "Search…  (also group:enemies, script:Enemy, scene:Coin)"
        _node_picker_search.text_changed.connect(func(_t: String) -> void: _populate_node_picker())
        # Enter commits the first result (parity with the main ACE picker's type-and-Enter).
        _node_picker_search.text_submitted.connect(func(_t: String) -> void: _activate_first_node_picker_match())
        find_box.add_child(_node_picker_search)
        var chip_row: HBoxContainer = HBoxContainer.new()
        chip_row.add_theme_constant_override("separation", 4)
        for chip_label: String in NODE_PICKER_CHIP_CLASSES.keys():
            var chip: Button = Button.new()
            chip.text = chip_label
            chip.toggle_mode = true
            chip.toggled.connect(func(_on: bool) -> void: _populate_node_picker())
            chip_row.add_child(chip)
            _node_picker_chips[chip_label] = chip
        _node_picker_used_toggle = Button.new()
        _node_picker_used_toggle.text = "Used in sheet"
        _node_picker_used_toggle.toggle_mode = true
        _node_picker_used_toggle.tooltip_text = "List every node reference this sheet makes (red = missing from the scene)."
        _node_picker_used_toggle.toggled.connect(func(_on: bool) -> void: _populate_node_picker())
        chip_row.add_child(_node_picker_used_toggle)
        find_box.add_child(chip_row)
        box.add_child(EventSheetPopupUI.titled_card("Find a node", find_box))
        _node_picker_tree = Tree.new()
        _node_picker_tree.columns = 2
        _node_picker_tree.set_column_title(0, "Node")
        _node_picker_tree.set_column_title(1, "Class")
        _node_picker_tree.column_titles_visible = true
        _node_picker_tree.hide_root = true
        _node_picker_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _node_picker_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _node_picker_tree.item_activated.connect(_on_node_picker_activated)
        _node_picker_tree.item_selected.connect(_on_node_picker_selection_changed)
        # A bare Control holder bounds the dialog height: a Tree reports its full content height as its
        # minimum and an AcceptDialog would grow to fit it. The tree fills the holder + scrolls internally.
        var tree_holder: Control = Control.new()
        tree_holder.custom_minimum_size = Vector2(0.0, 320.0)
        tree_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tree_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _node_picker_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        tree_holder.add_child(_node_picker_tree)
        var results_card: PanelContainer = EventSheetPopupUI.titled_card("Results", tree_holder)
        results_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        box.add_child(results_card)
        _node_picker_window.add_child(EventSheetPopupUI.margined(box))
        _host._dialog.add_child(_node_picker_window)

func _populate_node_picker() -> void:
    var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
    _populate_node_picker_from_root(scene_root)

## Population factored from the editor entry point so tests can drive an explicit tree.
func _populate_node_picker_from_root(scene_root: Node) -> void:
    _node_picker_tree.clear()
    var root_item: TreeItem = _node_picker_tree.create_item()
    var query: String = _node_picker_search.text.strip_edges()
    # Used-in-sheet audit view.
    if _node_picker_used_toggle != null and _node_picker_used_toggle.button_pressed:
        var sheet: EventSheetResource = null
        if _host._lint_context_provider.is_valid():
            sheet = _host._lint_context_provider.call() as EventSheetResource
        for reference: String in extract_sheet_node_references(sheet):
            var item: TreeItem = _node_picker_tree.create_item(root_item)
            var exists: bool = scene_root != null and scene_root.has_node(NodePath(reference))
            item.set_text(0, reference)
            item.set_text(1, "" if exists else "MISSING")
            item.set_metadata(0, reference)
            if not exists:
                item.set_custom_color(0, Color(0.9, 0.35, 0.35))
                item.set_custom_color(1, Color(0.9, 0.35, 0.35))
        return
    # Cross-scene search: scan .tscn node headers.
    if query.to_lower().begins_with("scene:"):
        for hit: Dictionary in scan_scene_files(query.substr(6).strip_edges()):
            var scene_item: TreeItem = _node_picker_tree.create_item(root_item)
            scene_item.set_text(0, "%s  —  %s" % [str(hit.get("node", "")), str(hit.get("file", ""))])
            scene_item.set_text(1, str(hit.get("class", "")))
            scene_item.set_metadata(0, "scene::" + str(hit.get("file", "")))
        return
    if scene_root == null:
        var empty: TreeItem = _node_picker_tree.create_item(root_item)
        empty.set_text(0, "(no scene open)")
        return
    # Recents first (when not searching).
    if query.is_empty():
        for recent: String in _node_picker_recents:
            if scene_root.has_node(NodePath(recent)):
                var recent_item: TreeItem = _node_picker_tree.create_item(root_item)
                recent_item.set_text(0, "★ " + recent)
                recent_item.set_text(1, scene_root.get_node(NodePath(recent)).get_class())
                recent_item.set_metadata(0, recent)
    _append_node_picker_rows(scene_root, scene_root, root_item, query)

func _append_node_picker_rows(node: Node, scene_root: Node, parent_item: TreeItem, query: String) -> void:
    var relative: String = str(scene_root.get_path_to(node))
    if _chip_filter_allows(node) and node_matches_query(node, relative, query):
        var item: TreeItem = _node_picker_tree.create_item(parent_item)
        # Show the %handle for scene-unique nodes (what picking them yields) so the deep-path shortcut is
        # visible at a glance; the metadata stays the relative path, resolved back to %Name on use.
        var is_unique: bool = node != scene_root and node.unique_name_in_owner and node.owner == scene_root
        item.set_text(0, ("%" + str(node.name)) if is_unique else (relative if node != scene_root else node.name))
        item.set_text(1, node.get_class())
        item.set_metadata(0, relative if node != scene_root else ".")
    for child: Node in node.get_children():
        _append_node_picker_rows(child, scene_root, parent_item, query)

## True when no chip is active, or the node inherits any active chip's base classes.
func _chip_filter_allows(node: Node) -> bool:
    var any_active: bool = false
    for chip_label: String in _node_picker_chips.keys():
        var chip: Button = _node_picker_chips[chip_label]
        if not chip.button_pressed:
            continue
        any_active = true
        for base_class: String in NODE_PICKER_CHIP_CLASSES[chip_label]:
            if node.is_class(base_class):
                return true
    return not any_active

## Query matching with the group:/script: prefixes (plain = name/class/path).
static func node_matches_query(node: Node, relative_path: String, query: String) -> bool:
    if query.is_empty():
        return true
    var lowered: String = query.to_lower()
    if lowered.begins_with("group:"):
        return node.is_in_group(StringName(query.substr(6).strip_edges()))
    if lowered.begins_with("script:"):
        var wanted: String = lowered.substr(7).strip_edges()
        var script: Script = node.get_script() as Script
        if script == null:
            return false
        return str(script.get_global_name()).to_lower().contains(wanted) \
            or script.resource_path.get_file().to_lower().contains(wanted)
    return node.name.to_lower().contains(lowered) \
        or node.get_class().to_lower().contains(lowered) \
        or relative_path.to_lower().contains(lowered)

## Every $Name / $"Path" reference the sheet makes (params, blocks, pick filters).
static func extract_sheet_node_references(sheet: EventSheetResource) -> PackedStringArray:
    var references: PackedStringArray = PackedStringArray()
    if sheet == null:
        return references
    var reference_regex: RegEx = RegEx.new()
    reference_regex.compile("\\$(?:\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_/]*))")
    var haystacks: PackedStringArray = PackedStringArray()
    _collect_reference_haystacks(sheet.events, haystacks)
    for function_entry: Variant in sheet.functions:
        if function_entry is EventFunction:
            _collect_reference_haystacks((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, haystacks)
    for haystack: String in haystacks:
        for regex_match: RegExMatch in reference_regex.search_all(haystack):
            var reference: String = regex_match.get_string(1) if not regex_match.get_string(1).is_empty() else regex_match.get_string(2)
            if not references.has(reference):
                references.append(reference)
    return references

static func _collect_reference_haystacks(rows: Array, into: PackedStringArray) -> void:
    for row: Variant in rows:
        if row is RawCodeRow:
            into.append((row as RawCodeRow).code)
        elif row is EventGroup:
            var group: EventGroup = row as EventGroup
            _collect_reference_haystacks(group.events if not group.events.is_empty() else group.rows, into)
        elif row is EventRow:
            var event_row: EventRow = row as EventRow
            for ace: Variant in event_row.conditions + event_row.actions:
                if ace is RawCodeRow:
                    into.append((ace as RawCodeRow).code)
                elif ace is MatchRow:
                    into.append((ace as MatchRow).branches_text)
                elif ace is Resource and ace.get("params") is Dictionary:
                    for value: Variant in (ace.get("params") as Dictionary).values():
                        if value is String:
                            into.append(value)
            for pick: Variant in event_row.pick_filters:
                if pick is PickFilter:
                    into.append((pick as PickFilter).collection_value)
                    into.append((pick as PickFilter).predicate_expression)
            _collect_reference_haystacks(event_row.sub_events, into)

## Cross-scene search: regex-scans .tscn node headers (text format) under res://.
## Returns [{file, node, class}] capped at NODE_PICKER_SCENE_SCAN_CAP.
static func scan_scene_files(query: String, base_dir: String = "res://") -> Array:
    var hits: Array = []
    if query.is_empty():
        return hits
    var header_regex: RegEx = RegEx.new()
    header_regex.compile("\\[node name=\"([^\"]+)\"(?: type=\"([^\"]+)\")?")
    var pending: PackedStringArray = PackedStringArray([base_dir])
    var lowered: String = query.to_lower()
    while not pending.is_empty() and hits.size() < NODE_PICKER_SCENE_SCAN_CAP:
        var directory_path: String = pending[pending.size() - 1]
        pending.remove_at(pending.size() - 1)
        var directory: DirAccess = DirAccess.open(directory_path)
        if directory == null:
            continue
        directory.list_dir_begin()
        var entry: String = directory.get_next()
        while not entry.is_empty():
            var full_path: String = directory_path.path_join(entry)
            if directory.current_is_dir():
                if not entry.begins_with("."):
                    pending.append(full_path)
            elif entry.get_extension() == "tscn":
                var content: String = FileAccess.get_file_as_string(full_path)
                for regex_match: RegExMatch in header_regex.search_all(content):
                    var node_name: String = regex_match.get_string(1)
                    var node_class: String = regex_match.get_string(2)
                    if node_name.to_lower().contains(lowered) or node_class.to_lower().contains(lowered):
                        hits.append({"file": full_path, "node": node_name, "class": node_class})
                        if hits.size() >= NODE_PICKER_SCENE_SCAN_CAP:
                            break
            entry = directory.get_next()
    return hits

## Enter in the node-picker search box commits the first matching node.
func _activate_first_node_picker_match() -> void:
    var first: TreeItem = _host._first_metadata_row(_node_picker_tree.get_root()) if _node_picker_tree != null else null
    if first != null:
        first.select(0)
        _on_node_picker_activated()

## Enables the "Use Node" button only when a row that carries a node reference is highlighted, so the
## confirm action can never commit an empty/heading row.
func _on_node_picker_selection_changed() -> void:
    var selected: TreeItem = _node_picker_tree.get_selected() if _node_picker_tree != null else null
    if _node_picker_window != null:
        _node_picker_window.get_ok_button().disabled = selected == null or selected.get_metadata(0) == null
    if _node_picker_unique_button != null:
        var meta: Variant = selected.get_metadata(0) if selected != null else null
        var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
        _node_picker_unique_button.disabled = meta == null or not _node_is_uniqueable(scene_root, str(meta))

func _on_node_picker_activated() -> void:
    var selected: TreeItem = _node_picker_tree.get_selected()
    if selected == null:
        return
    var relative: String = str(selected.get_metadata(0))
    var reference: String
    if relative.begins_with("scene::"):
        reference = ACEParamsDialog.format_quoted_literal(relative.trim_prefix("scene::"))
    else:
        var picker_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
        reference = "self" if relative == "." else ACEParamsDialog._best_node_reference(picker_root, relative)
        var existing_index: int = _node_picker_recents.find(relative)
        if existing_index >= 0:
            _node_picker_recents.remove_at(existing_index)
        _node_picker_recents.insert(0, relative)
        if _node_picker_recents.size() > NODE_PICKER_RECENTS_CAP:
            _node_picker_recents.resize(NODE_PICKER_RECENTS_CAP)
    var field: Variant = _host._fields.get(_node_picker_target_key)
    if field is TextEdit:
        (field as TextEdit).insert_text_at_caret(reference)
        _host._validate_expression_field(field)
    elif field is LineEdit:
        (field as LineEdit).insert_text_at_caret(reference)
    _node_picker_window.hide()

func _on_node_picker_custom_action(action: StringName) -> void:
    if str(action) == "make_unique":
        _make_picked_node_unique()

## Marks the picked node scene-unique (undoable) and hands back %Name — so ANY deep node, not just
## pre-marked ones, becomes a flat path-free handle in one click, without leaving the sheet for the scene
## editor. No-op outside the editor or for a non-uniqueable selection.
func _make_picked_node_unique() -> void:
    if not Engine.is_editor_hint():
        return
    var selected: TreeItem = _node_picker_tree.get_selected() if _node_picker_tree != null else null
    if selected == null:
        return
    var scene_root: Node = EditorInterface.get_edited_scene_root()
    var relative: String = str(selected.get_metadata(0)) if selected.get_metadata(0) != null else ""
    if not _node_is_uniqueable(scene_root, relative):
        return
    var node: Node = scene_root.get_node_or_null(NodePath(relative))
    if node == null:
        return
    var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
    if undo != null:
        undo.create_action("Mark \"%s\" as scene-unique" % node.name)
        undo.add_do_property(node, "unique_name_in_owner", true)
        undo.add_undo_property(node, "unique_name_in_owner", false)
        undo.commit_action()
    else:
        node.unique_name_in_owner = true
    var field: Variant = _host._fields.get(_node_picker_target_key)
    var reference: String = "%" + str(node.name)
    if field is TextEdit:
        (field as TextEdit).insert_text_at_caret(reference)
        _host._validate_expression_field(field)
    elif field is LineEdit:
        (field as LineEdit).insert_text_at_caret(reference)
    _node_picker_window.hide()

## True when the node at relative_path can be made scene-unique: it exists, isn't the scene root or a
## cross-scene entry, is owned by this scene, and isn't already unique. Pure → unit-testable.
static func _node_is_uniqueable(scene_root: Node, relative_path: String) -> bool:
    if scene_root == null or relative_path.is_empty() or relative_path == "." or relative_path.begins_with("scene::"):
        return false
    var node: Node = scene_root.get_node_or_null(NodePath(relative_path))
    return node != null and node != scene_root and node.owner == scene_root and not node.unique_name_in_owner
