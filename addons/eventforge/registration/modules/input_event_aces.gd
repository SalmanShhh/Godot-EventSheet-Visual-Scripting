# EventForge module - THE INPUT EVENT ITSELF: the questions a handler asks the event it was handed.
#
# A sheet already has the polled input questions - Is Action Pressed and its two edges, which ask the
# `Input` singleton how things stand right now. Those are the right rows under Every Tick, and they
# are the wrong rows inside `_input(event)`: a handler is given ONE event and asked what it is, and
# asking the singleton instead answers about a different moment and cannot be stopped from
# propagating. Hand-written Godot therefore reads
#
#     func _unhandled_input(event: InputEvent) -> void:
#         if event.is_action_pressed("jump"):
#
# and there was no row for that line, so it opened as Expression Is True - the honest catch-all, and
# the plainest thing a sheet can say about the commonest input shape there is.
#
# These are that line's twin, in the sheet's own words. Same three edges as the polled family (down,
# up, and the held-down repeat), asked of the event; plus the two facts an event carries that no
# poll can answer - which action it is at all, and how hard it is being held. The HANDLER CONTEXT IS
# PRESERVED: nothing here invents a new place to put the question, the rows sit under the input
# triggers the sheet already has (On input / On unhandled input / On key input / On control input),
# and the action names come from the project's own Input Map exactly as the polled family's do.
#
# WHAT IS NOT HERE, on purpose. Stopping an event from travelling further is Stop This Input Here,
# which the Controls vocabulary already ships; asking whether a key event is a held-down repeat is
# Key Is A Held-Down Repeat, ditto. A row that already exists is not spelled twice.
#
# THE REPEAT IS ITS OWN QUESTION, NOT A SWITCH ON THE PRESS. Godot's second argument to
# `is_action_pressed` widens the press to include the auto-repeats a held key produces, and it would
# be tempting to hang a yes/no parameter off the press row for it. It is not one: with the parameter
# blank the row would have to write `event.is_action_pressed("jump", false)`, which is not the line
# anybody writes, and every opened project would fail to recognise its own spelling. Two questions,
# two rows, each writing exactly what a person writes.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeInputEventACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## Where these rows are filed. Deliberately NOT the "Input" section the polled family lives in: a
## reader scanning that list should not have to tell two nearly identically worded rows apart by
## their small print, and the section's own sentence is what says which one they are looking at.
const CAT := "Input Event"


## The parameter every row here shares: an action out of the project's own Input Map, held as the
## QUOTED literal (`"jump"`) because that is what the field's dropdown offers and what every other
## action field in the plugin holds. The templates write the `&` themselves, which is the engine's
## StringName shorthand and saves a hash per call in a handler that runs on every keystroke.
static func _action_param(description: String) -> ACEParam:
	return F.make_param("action", "String", F.default_input_action(), "Action", description,
		"input_action", F.input_action_options())


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "EventIsActionPressed", "Event Is Action Pressed",
		ACEDescriptor.ACEType.CONDITION, "event.is_action_pressed(&{action})", "",
		[_action_param("The action this event has to be, from the Input Map.")],
		CAT, "{action} was pressed")
		.described("True when the event this handler was handed is the named action going down. The press half of the event the handler is holding - not a question about how things stand now, which is what Is Action Pressed answers."))

	descriptors.append(F.make_descriptor("Core", "EventIsActionPressedRepeating", "Event Is Action Pressed Or Repeating",
		ACEDescriptor.ACEType.CONDITION, "event.is_action_pressed(&{action}, true)", "",
		[_action_param("The action this event has to be, from the Input Map.")],
		CAT, "{action} was pressed or is repeating")
		.described("The same press, widened to include the auto-repeats a held key sends - what a menu that scrolls while you hold the stick wants, and what a jump does not."))

	descriptors.append(F.make_descriptor("Core", "EventIsActionReleased", "Event Is Action Released",
		ACEDescriptor.ACEType.CONDITION, "event.is_action_released(&{action})", "",
		[_action_param("The action this event has to be, from the Input Map.")],
		CAT, "{action} was released")
		.described("True when the event this handler was handed is the named action coming back up, for charge-and-release moves and for letting go of a held control."))

	descriptors.append(F.make_descriptor("Core", "EventIsAction", "Event Is The Action",
		ACEDescriptor.ACEType.CONDITION, "event.is_action(&{action})", "",
		[_action_param("The action this event has to be, from the Input Map.")],
		CAT, "the event is {action}")
		.described("True when the event belongs to the named action at all, whichever way it is going. The row to ask before reading how hard it is held, since a strength is only meaningful once you know which control it came from."))

	descriptors.append(F.make_descriptor("Core", "EventActionStrength", "Event Action Strength",
		ACEDescriptor.ACEType.EXPRESSION, "event.get_action_strength(&{action})", "",
		[_action_param("The action to read out of this event, from the Input Map.")],
		CAT, "how hard {action} is held in this event")
		.described("How far the control behind this event is pushed, from 0 to 1 - a stick or a trigger reads the whole range, a key reads 0 or 1."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "What the ONE event an input handler was handed is: which action it belongs to, whether it is going down, coming up or repeating, and how hard it is held. These are the rows for the inside of On input / On unhandled input; the Input section's rows ask the keyboard how things stand right now instead, which is what an every-tick event wants."}
