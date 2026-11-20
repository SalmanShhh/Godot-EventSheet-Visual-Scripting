# EventSheets - a row always says when it runs.
#
# A tick handler with no condition of its own used to leave its condition cell empty, on the rule
# that blank means "every frame". A reader who does not know that rule saw a row with no "when" at
# all. The cell now reads the same words the row reads with a condition beside it ("On process",
# "On physics process"), in every place such an event can sit. It still wears no trigger arrow (the
# arrow marks what fires once) and it is display only: the row keeps its trigger id.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "every_frame_trigger_cell_test"
const NativeRowMarks := preload("res://addons/eventsheet/editor/interaction/native_row_marks.gd")


static func run() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var plain: EventRow = _tick("OnProcess", "")
	var physics: EventRow = _tick("OnPhysicsProcess", "")
	var conditioned: EventRow = _tick("OnProcess", "hp > 0")
	var in_group: EventRow = _tick("OnProcess", "")
	var group: EventGroup = EventGroup.new()
	group.name = "Movement"
	group.events.append(in_group)
	var parent: EventRow = _tick("OnReady", "")
	var sub_event: EventRow = _tick("", "")
	parent.sub_events.append(sub_event)
	var blank: EventRow = _tick("", "")
	for row: Resource in [plain, physics, conditioned, group, parent, blank]:
		sheet.events.append(row)
	viewport._sheet = sheet
	var builder: EventSheetViewportRowBuilder = viewport._row_builder
	var ok: bool = SUPPORT.pins(P, [
		["an on-process event with no condition names its trigger", _words(builder, plain), ["On process"]],
		["an on-physics-process event with no condition names its trigger", _words(builder, physics), ["On physics process"]],
		["an event with a condition still names its trigger once, before the condition", _words(builder, conditioned).slice(0, 1), ["On process"]],
		["and it has the condition's own cell after it", _words(builder, conditioned).size(), 2],
		["an event inside a group names its trigger", _words(builder, in_group), ["On process"]],
		["a blank top-level event names the every-frame tick", _words(builder, blank), ["On process"]],
		["a sub-event keeps its empty lane: it follows its parent, it is not a tick", _words(builder, sub_event), []],
		["a cell that names a tick carries the System object", _objects(builder, plain), ["System"]],
		["the every-frame cell wears no trigger arrow: the arrow marks what fires once", _marks(builder, plain), []],
		["and the one-shot trigger keeps its arrow", _marks(builder, parent), ["trigger"]],
		["the trigger id is untouched", plain.trigger_id, "OnProcess"],
		["the line count the row builder reports matches the lines it builds",
			builder._count_event_lines(plain), _last_line(builder, plain) + 1],
	])
	viewport.free()
	return ok


static func _tick(trigger_id: String, condition: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core" if not trigger_id.is_empty() else ""
	row.trigger_id = trigger_id
	if not condition.is_empty():
		var check: ACECondition = ACECondition.new()
		check.provider_id = "Core"
		check.ace_id = "CompareExpression"
		check.codegen_template = condition
		row.conditions.append(check)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RunCode"
	action.codegen_template = "tick()"
	row.actions.append(action)
	return row


## The words of the cells in the condition lane, in order (badges and payload chips left out).
static func _words(builder: EventSheetViewportRowBuilder, row: EventRow) -> Array:
	var out: Array = []
	for span: EventSheetSemanticSpan in builder._build_event_spans(row):
		var meta: Dictionary = span.metadata as Dictionary
		if str(meta.get("lane", "")) == "condition" and bool(meta.get("chip", false)) and not span.text.is_empty():
			out.append(span.text)
	return out


static func _last_line(builder: EventSheetViewportRowBuilder, row: EventRow) -> int:
	var last: int = 0
	for span: EventSheetSemanticSpan in builder._build_event_spans(row):
		last = maxi(last, int((span.metadata as Dictionary).get("line_index", 0)))
	return last


static func _objects(builder: EventSheetViewportRowBuilder, row: EventRow) -> Array:
	var out: Array = []
	for span: EventSheetSemanticSpan in builder._build_event_spans(row):
		var meta: Dictionary = span.metadata as Dictionary
		if str(meta.get("kind", "")) == "trigger" and bool(meta.get("chip", false)):
			out.append(str(meta.get("object_label", "")))
	return out


## The kind mark (arrow) the trigger badge of the row draws, "" for none.
static func _marks(builder: EventSheetViewportRowBuilder, row: EventRow) -> Array:
	var out: Array = []
	for span: EventSheetSemanticSpan in builder._build_event_spans(row):
		var meta: Dictionary = span.metadata as Dictionary
		if str(meta.get("badge_style", "")) == "trigger":
			out.append(NativeRowMarks.kind_mark_for(meta, span.text))
	return out
