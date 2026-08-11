# Godot EventSheets - TimelineStep resource
# One beat of a Timeline block: WHEN (seconds from the timeline's start) and WHAT (one action-lane
# item - an ACEAction, a RawCodeRow line, or a CommentRow note - compiled through the ordinary
# action codegen). Steps live in TimelineRow.steps in schedule order; the emitter awaits the gap
# between one step's time and the next, so the sheet reads as the schedule it is.
@tool
class_name TimelineStep
extends Resource

@export var enabled: bool = true
## Seconds from the timeline's start at which this step runs. Equal times run back to back.
@export var at: float = 0.0
## The step's action (ACEAction / RawCodeRow / CommentRow), compiled like any event-body action.
@export var action: Resource = null


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "timeline_step"
