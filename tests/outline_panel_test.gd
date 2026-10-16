# Godot EventSheets - the Outline panel (the script editor's method-list, for sheets):
# a jump tree of the STRUCTURAL rows - groups (nested), region openers, published
# functions. Pins: the entry walk (order, kinds, depths, endregion excluded), and the
# panel tree build (indented items carrying their jump targets).
@tool
class_name OutlinePanelTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false


static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	var region_open: CustomBlockRow = CustomBlockRow.new()
	region_open.kind_id = "region"
	region_open.fields = {"label": "Setup"}
	sheet.events.append(region_open)
	var region_close: CustomBlockRow = CustomBlockRow.new()
	region_close.kind_id = "region"
	region_close.fields = {"is_end": true}
	sheet.events.append(region_close)
	var combat: EventGroup = EventGroup.new()
	combat.group_name = "Combat"
	var bosses: EventGroup = EventGroup.new()
	bosses.group_name = "Bosses"
	combat.events.append(bosses)
	sheet.events.append(combat)
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	sheet.functions.append(heal)

	# ---- the walk: region opener, group, nested group (depth 1), then the function ----
	var entries: Array = EventSheetOutlinePanel.outline_entries(sheet)
	var shape: Array = []
	for entry: Dictionary in entries:
		shape.append("%s:%s@%d" % [entry.get("kind"), entry.get("label"), entry.get("depth")])
	all_passed = _check("the walk finds regions, nested groups, and functions in order (endregion excluded)",
		str(shape), str(["region:Setup@0", "group:Combat@0", "group:Bosses@1", "function:heal@0"])) and all_passed
	all_passed = _check("entries carry their jump resource", entries[1].get("resource"), combat) and all_passed

	# ---- the panel tree: nested groups indent, items carry metadata ----
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var panel: EventSheetOutlinePanel = editor._ensure_outline_panel()
	panel.build()
	panel.refresh()
	var root: TreeItem = editor._outline_tree.get_root()
	var first: TreeItem = root.get_first_child()
	all_passed = _check("the first outline item is the region", first.get_text(0), "# Setup") and all_passed
	var group_item: TreeItem = first.get_next()
	all_passed = _check("the group item follows with its jump target", group_item.get_metadata(0), combat) and all_passed
	all_passed = _check("the nested group indents under its parent", group_item.get_first_child().get_text(0), "Bosses") and all_passed
	# The filter narrows the tree to what holds the words, keeping the folder a match lives in.
	panel.filter_edit.text = "boss"
	panel.refresh()
	first = editor._outline_tree.get_root().get_first_child()
	group_item = first.get_next()
	all_passed = _check("a filter hides what does not hold its words but keeps the folder above a match",
		[first.visible, group_item.visible, group_item.get_first_child().visible, group_item.get_next().visible],
		[false, true, true, false]) and all_passed
	all_passed = _check("the function closes the outline", group_item.get_next().get_text(0), "ƒ heal") and all_passed
	editor.free()

	# ---- explicit parentage (review regression): a region inside a SIBLING event's
	# sub-events must NOT nest under the earlier group that happened to share its depth ----
	var carrier: EventRow = EventRow.new()
	carrier.trigger_provider_id = "Core"
	carrier.trigger_id = "OnReady"
	var nested_region: CustomBlockRow = CustomBlockRow.new()
	nested_region.kind_id = "region"
	nested_region.fields = {"label": "Inside Sub-Events"}
	carrier.sub_events.append(nested_region)
	sheet.events.append(carrier)
	var reparent_entries: Array = EventSheetOutlinePanel.outline_entries(sheet)
	var nested_entry: Dictionary = {}
	for entry: Dictionary in reparent_entries:
		if str(entry.get("label", "")) == "Inside Sub-Events":
			nested_entry = entry
	all_passed = _check("a sub-event region stays TOP-LEVEL, never under the unrelated group",
		int(nested_entry.get("parent", -99)), -1) and all_passed

	all_passed = _check("groups and notes wear editor icons; a region and a function keep their code marks",
		[EventSheetOutlinePanel.KINDS["group"][2], EventSheetOutlinePanel.KINDS["todo_folder"][2],
			EventSheetOutlinePanel.KINDS["todo"], EventSheetOutlinePanel.KINDS["region"][0],
			EventSheetOutlinePanel.KINDS["function"][0]],
		["Folder", "Folder", ["", Color("#8b91a3"), "NodeInfo"], "# ", "ƒ "]) and all_passed
	all_passed = _check("a filter keeps each match and every folder above it, in any case",
		EventSheetOutlinePanel.filter_matches(entries, "BOSS"), [false, true, true, false]) and all_passed
	all_passed = _check("an empty filter keeps everything",
		EventSheetOutlinePanel.filter_matches(entries, "  "), [true, true, true, true]) and all_passed
	all_passed = _jumps_land_in_the_active_pane() and all_passed
	return all_passed


## The outline is built from the active pane, so its jumps land there too: in split view, picking an
## entry selects it in the pane the reader is working in, not always in the left one.
static func _jumps_land_in_the_active_pane() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var lead: CommentRow = CommentRow.new()
	lead.text = "lead"
	sheet.events.append(lead)
	var combat: EventGroup = EventGroup.new()
	combat.group_name = "Combat"
	sheet.events.append(combat)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var primary: EventSheetViewport = editor.get_viewport_control()
	editor._multi_view._toggle_split_view()
	var split: EventSheetViewport = editor._multi_view._split_viewport
	primary._select_row(0, -1)
	# Selecting in the split makes it the active pane (selecting in the left pane would reclaim it).
	split._select_row(0, -1)
	var panel: EventSheetOutlinePanel = editor._ensure_outline_panel()
	panel.build()
	panel.refresh()
	var group_item: TreeItem = editor._outline_tree.get_root().get_first_child()
	group_item.select(0)
	panel._on_entry_selected()
	var landed: Array = [split.get_selected_context().get("source_resource", null),
		primary.get_selected_context().get("source_resource", null)]
	editor._multi_view._toggle_split_view()
	editor.free()
	return _check("an outline jump in split view lands in the active pane", landed, [combat, lead])


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] outline_panel_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
