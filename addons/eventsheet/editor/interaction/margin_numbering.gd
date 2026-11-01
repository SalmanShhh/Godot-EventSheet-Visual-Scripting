@tool
extends RefCounted
## The number each event wears in the margin, for readers that have no canvas of their own (the Doctor,
## Find in project). The look that nests by lines numbers a pair's branches and the groups too, so the
## events after them are drawn lower than the sheet's own count; this reads that off a throwaway
## viewport built the way the dock builds one, so the answer is the gutter's and cannot drift from it.


## instance-id -> margin number, for every numbered event (and function) of `sheet`.
static func numbers(sheet: EventSheetResource) -> Dictionary:
	var model: Dictionary = EventSheetResource.event_numbers(sheet.events, sheet.functions)
	var look: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(
		sheet.editor_style, EventSheetEditorThemeDeriver.running_editor_base())
	if look == null or not look.get_event_style().sub_event_strips:
		return model
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.apply_editor_style(look)
	view.set_sheet(sheet)
	var shown: Dictionary = {}
	for id: Variant in model:
		shown[id] = view.display_event_number(int(model[id]))
	view.free()
	return shown
