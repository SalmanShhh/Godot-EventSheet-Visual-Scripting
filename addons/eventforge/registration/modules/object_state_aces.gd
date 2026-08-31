# EventForge module - one object's own state: asking about it, going to it, and answering a change.
#
# An enemy is patrolling, or chasing, or staggered. That is a VARIABLE - the pattern every event
# sheet already builds and every Godot project writes as an enum - so these rows are that enum's
# vocabulary and nothing more. There is no new kind of row here, no group that only runs in a state,
# and no diagram: the states band on the sheet head is the diagram.
#
# Every one of them compiles to the line a person would have written, in most cases the SAME line:
#
#   Go to X               state = State.X
#   Is in X               state == State.X
#   Was in X              previous_state == State.X
#   Is in X for over 2s   state == State.X and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > 2.0
#
# WHY GOING TO A STATE IS ONE PLAIN ASSIGNMENT: the announcement rides in the `state` variable's own
# SETTER, which is where Godot puts "and tell everybody" - so nothing has to remember to emit the
# signal, a project that assigns the variable directly is already announcing it, and the line a row
# writes is the line anybody would have typed. That is also what lets these lift both ways. The same
# setter records what we were in before and when this state began, which is why Was in and the timed
# Is in need no bookkeeping row of their own.
#
# WHY `from_state, to_state` ON THE SIGNAL: the moment of a change is where the real work lives - drop
# the guard as the stagger starts, raise it again after - and half of that question is what we just
# LEFT. For ONE change, On leaving fires before On entering, because the room is emptied before the
# next one is filled.
#
# AND WHAT THAT DOES NOT SAY. The setter announces synchronously, so a Go to written INSIDE an On
# entering or On leaving row is a SECOND change announced immediately: its own leaving-then-entering
# rows run to the end, and only then do the first change's remaining rows resume - by which time the
# object is somewhere else. That is what a plain setter does and what the same lines written by hand
# do, so it is stated rather than papered over: a machine that chains a change from inside a change
# should make the second one its own row, under a condition, in the ordinary way.
#
# THE DECLARATIONS THEY LEAN ON (the `State` enum, the `state` variable with its setter,
# `previous_state`, `state_entered_msec` and `state_changed`) are ORDINARY rows the Declare states
# dialog on the sheet head writes - so a project that hand-wrote them is already using these, and an
# object that never asked for states has none of it.
#
# RELATED, AND DELIBERATELY THE SAME SHAPE: the Game State module beside this one is this exact
# vocabulary for the GAME's own machine (the Mode enum an Autoload declares, In mode X, Go to mode X)
# - one level up, same declarations, same setter idea, same trigger order. And the State Machine
# behaviour pack in `eventsheet_addons/state_machine/` is the older answer to the same question: a
# child node holding a String state. It is frozen and keeps working; the difference is that a string
# is whatever was typed and an enum member is one of a declared few, offered by the field and checked
# by the Doctor, so new work belongs here.
@tool
class_name EventForgeObjectStateACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker category. One section, so the whole family reads as one idea - and named apart from
## Game State because an object's state and the game's mode are two different machines.
const CAT: String = "Object State"

## The hint that makes a field OFFER this object's declared states as you type, which is the point of
## declaring them once: the answer is picked rather than remembered.
##
## It offers, it does not forbid. A state this object does not declare yet is still typeable, because
## one may be about to be declared and a field that refused would make declaring them in the other
## order impossible. A row naming a state nobody declares is therefore something the Doctor SAYS -
## "a state this object does not declare" - rather than something the field prevents.
const STATE_HINT: String = "state_reference"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "InState", "Is In State", ACEDescriptor.ACEType.CONDITION,
		"state == State.{state}", "", [_state_param()], CAT, "Is in {state}")
		.described("True while this object is in the given state. The states are declared once, on the states band of this sheet's head, and this row picks one of them."))

	descriptors.append(F.make_descriptor("Core", "InStateForOver", "Is In State For Over",
		ACEDescriptor.ACEType.CONDITION,
		"state == State.{state} and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > {seconds}",
		"", [_state_param(), _seconds_param()], CAT, "Is in {state} for over {seconds}s")
		.described("True while this object has been in the given state for longer than that many seconds - the timed half of Is in. The clock restarts every time the state changes, so a stagger that ends after a second is this row and nothing else."))

	descriptors.append(F.make_descriptor("Core", "WasInState", "Was In State", ACEDescriptor.ACEType.CONDITION,
		"previous_state == State.{state}", "", [_state_param()], CAT, "Was in {state}")
		.described("True while the state this object was in BEFORE the current one is the given state. Answers \"what did we come from\" - the chase that began from patrolling is a different chase from the one that began from being staggered."))

	descriptors.append(F.make_descriptor("Core", "GoToState", "Go To State", ACEDescriptor.ACEType.ACTION,
		"state = State.{state}", "", [_state_param()], CAT, "Go to {state}")
		.described("Moves this object into another state and says so: On leaving the old one and On entering the new one both run, in that order. Going to the state it is already in changes nothing and announces nothing."))

	descriptors.append(F.make_descriptor("Core", "OnEnteringState", "On Entering State",
		ACEDescriptor.ACEType.TRIGGER, "", "state_changed", [_state_param()],
		CAT, "On entering {state}")
		.described("Runs the moment this object enters the given state, after every On leaving row of the state it came from, so what is being left has finished tidying up before the new one starts. A Go to written inside one of these rows is a second change announced straight away: its own rows run to the end first, and the rows left in this one then run for a state the object has already left."))

	descriptors.append(F.make_descriptor("Core", "OnLeavingState", "On Leaving State",
		ACEDescriptor.ACEType.TRIGGER, "", "state_changed", [_state_param()],
		CAT, "On leaving {state}")
		.described("Runs the moment this object leaves the given state, before anything answering the state it is entering. Put back here whatever the state switched on - the alarm it raised, the shader it turned red."))

	return descriptors


## The one parameter the whole family shares: which state, as a member of this object's own enum. The
## hint is what turns the field into that list rather than into free text, and the default names no
## state at all - a row must say which, and the object's own declarations are where the answer comes
## from.
static func _state_param() -> ACEParam:
	return F.make_param("state", "String", "", "State",
		"Which of this object's declared states. The Declare states dialog on the sheet head is where they are declared, and this list is exactly what it wrote.",
		STATE_HINT)


## How long the timed condition waits. Seconds, because that is what a designer says out loud, and an
## expression is allowed here as everywhere else a number is.
##
## WHICH CLOCK: `Time.get_ticks_msec()`, which is wall time and keeps running while the scene tree is
## paused. A game that goes to a Paused mode freezes its objects, and every timed row here goes on
## counting through the pause and answers the instant play resumes. A state timer that has to stop
## with the game is a variable the sheet adds to under a not-paused condition, which says out loud
## which clock it is on.
static func _seconds_param() -> ACEParam:
	return F.make_param("seconds", "float", "1.0", "Seconds",
		"How long the object must already have been in that state for this to be true. The clock starts again on every change of state.",
		"expression")
