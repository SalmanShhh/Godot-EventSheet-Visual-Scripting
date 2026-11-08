# Godot EventSheets - an expression condition that names the frame step keeps its expression colour.
#
# The condition reader hands back a coloured value sentence only when it has something to say about the
# expression. It used to have something to say about every `delta` (it respelled it `dt`); the respelling
# is gone, so the words are what the file wrote, and the cell must still read as the coloured expression
# it was. An expression with no frame step in it is untouched: it is left to the generic reading.
@tool
class_name FrameStepExpressionTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "frame_step_expression_test"


static func run() -> bool:
	var rows: Array = []
	for expression: String in ["_separate(delta)", "entry.integrate(delta)", "_follow_bar(str(bar_name), target as Range, delta)"]:
		var reading: Dictionary = EventSheetSentence.condition(expression, {})
		var segments: Array = reading.get("segments", [])
		var shown: String = ""
		var tone: String = ""
		if not segments.is_empty():
			shown = str((segments[0] as Dictionary).get("text", ""))
			tone = str((segments[0] as Dictionary).get("tone", ""))
		rows.append(["%s reads as the same words" % expression, shown, expression])
		rows.append(["%s wears the expression colour" % expression, tone, "value"])
	rows.append(["a name that only contains the letters is not the frame step",
		EventSheetSentence.condition("delta_v.integrate()", {}).is_empty(), true])
	rows.append(["a member called delta is somebody else's name",
		EventSheetSentence.condition("host.delta.integrate()", {}).is_empty(), true])
	rows.append(["an expression with no frame step is left to the generic reading",
		EventSheetSentence.condition("entry.integrate(step)", {}).is_empty(), true])
	return SUPPORT.pins(P, rows)
