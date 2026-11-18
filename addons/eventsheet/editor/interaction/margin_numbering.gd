@tool
extends RefCounted
## The number each event wears in the margin, for readers that have no canvas of their own (the Doctor,
## Find in project). The look that nests by lines numbers a pair's branches and the groups too, so the
## events after them are drawn lower than the sheet's own count; this reads that off a throwaway
## viewport built the way the dock builds one, so the answer is the gutter's and cannot drift from it.
##
## Building that viewport reads every row of the sheet, which is most of a sheet's cost to open, so it
## is built only for a sheet that holds something the numbering can move for: a group, a lambda handed
## to `connect`, a file included, or any row this does not recognise. A sheet of plain events and
## declarations is numbered exactly as the sheet itself numbers it, which is what the canvas would
## answer for it.

const SceneSheetMarks := preload("res://addons/eventforge/importer/scene_sheet_marks.gd")


## instance-id -> margin number, for every numbered event (and function) of `sheet`.
static func numbers(sheet: EventSheetResource) -> Dictionary:
	var model: Dictionary = EventSheetResource.event_numbers(sheet.events, sheet.functions)
	var look: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(
		sheet.editor_style, EventSheetEditorThemeDeriver.running_editor_base())
	if look == null or not look.get_event_style().sub_event_strips:
		return model
	if not can_differ(sheet):
		return model
	return canvas_numbers(sheet, model)


## The numbers read off a throwaway canvas, whatever the sheet holds. The answer `numbers` gives for a
## sheet that can differ, and the one a test holds the shortcut up against.
static func canvas_numbers(sheet: EventSheetResource, model: Dictionary) -> Dictionary:
	var look: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(
		sheet.editor_style, EventSheetEditorThemeDeriver.running_editor_base())
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	# Not stretched by anchors: a size set on a control that is would print an engine warning each time.
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.size = Vector2(1200.0, 900.0)
	view.apply_editor_style(look)
	view.set_sheet(sheet)
	var shown: Dictionary = {}
	for id: Variant in model:
		shown[id] = view.display_event_number(int(model[id]))
	view.free()
	return shown


## Whether a canvas could number this sheet differently from the sheet's own count. Errs towards true:
## anything it does not recognise as a row that takes a number of its own counts as one that might.
static func can_differ(sheet: EventSheetResource) -> bool:
	if SceneSheetMarks.is_scene_sheet(sheet) or not sheet.includes.is_empty():
		return true
	if _rows_can_differ(sheet.events):
		return true
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction) or _rows_can_differ((entry as EventFunction).events) \
				or _rows_can_differ((entry as EventFunction).rows):
			return true
	return false


static func _rows_can_differ(rows: Array) -> bool:
	for row: Variant in rows:
		if row is EventRow:
			if _event_can_differ(row as EventRow):
				return true
		elif row is RawCodeRow:
			if (row as RawCodeRow).code.contains(".connect("):
				return true
		elif row is InnerClassRow:
			var body: EventSheetResource = (row as InnerClassRow).body
			if body != null and can_differ(body):
				return true
		elif not (row is LocalVariable or row is SignalRow or row is EnumRow or row is CommentRow
				or row is FunctionAnchorRow or row is EventAnchorRow or row is CollectionDeclRow):
			return true
	return false


static func _event_can_differ(event: EventRow) -> bool:
	# An else arm is half of a pair, and a value written `a if c else b` is a branch drawn as one: each
	# takes a place in the margin of its own, so any "if " in an action's words is a reason to ask the canvas.
	if event.else_mode != EventRow.ElseMode.NONE:
		return true
	for action: Variant in event.actions:
		if action is ACEAction:
			var written: String = "%s %s" % [str((action as ACEAction).params), str((action as ACEAction).parameters)]
			if written.contains("func(") or written.contains("if "):
				return true
		elif action is RawCodeRow:
			if (action as RawCodeRow).code.contains("func(") or (action as RawCodeRow).code.contains("if "):
				return true
		elif action is MatchRow:
			var branches: String = (action as MatchRow).branches_text
			if not (action as MatchRow).cases.is_empty() or branches.contains("func(") or branches.contains("if "):
				return true
		elif not (action is CollectionDeclRow):
			return true
	return _rows_can_differ(event.sub_events)
