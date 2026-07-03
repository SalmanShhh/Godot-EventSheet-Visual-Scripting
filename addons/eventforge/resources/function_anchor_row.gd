# EventForge - a position anchor for a lifted mid-file function (GDScript-backed sheets).
#
# Sheet functions live in EventSheetResource.functions and normally emit as the trailing
# functions section - which is why, before anchors, only a TRAILING run of helper functions
# could reverse-lift (a lifted function would otherwise re-emit at the end of the file and
# break the byte-verify). An anchor sits in sheet.events at the function's original slot and
# tells the external compile path "emit <function_name> HERE", so a helper in the middle of a
# hand-written .gd can lift to a real editable EventFunction while the file keeps its exact
# layout. Created only by the lifter, and only when in-place emission reproduces the source
# lines byte-exactly.
@tool
class_name FunctionAnchorRow
extends Resource

## The EventFunction (by name, in this sheet's functions array) that emits at this slot.
@export var function_name: String = ""
