# EventForge - a position anchor for a lifted mid-file LIFECYCLE HANDLER (GDScript-backed sheets).
#
# The sibling of FunctionAnchorRow, for events instead of functions. Events normally emit as the
# grouped trigger section, which the external compile path writes AFTER every in-place raw row -
# so before anchors a `_unhandled_input` sitting below a pack's published verbs could not lift at
# all (lifting it would hoist the handler above those verbs and break the whole-file byte-verify).
# An anchor sits in sheet.events at the handler's original slot; the EventRows it emits follow it
# immediately in the same array (so the canvas draws them exactly where the file has them), and
# the external compile path emits ONE function for them at this slot instead of folding them into
# the trailing grouped section. Created only by the lifter, and only when in-place emission
# reproduces the source lines byte-exactly.
@tool
class_name EventAnchorRow
extends Resource

## The EventRows (by event_uid, following this row in sheet.events) that emit as one handler here.
@export var event_uids: PackedStringArray = PackedStringArray()

## The trigger the anchored handler resolves to ("OnUnhandledInput", …) - informational, so a
## reader of the resource can tell what the slot holds without walking the rows.
@export var trigger_id: String = ""
