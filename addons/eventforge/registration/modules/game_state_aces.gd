# EventForge module - the game's own mode: going to one, asking about one, and coming back. The same machine one level down, for ONE object rather than the whole game, is Object State (that object's own State enum, Is in X, Go to X).
#
# A game has a mode - Playing, Paused, Cutscene, Menu - and almost every project grows one as an
# enum plus a hundred ifs. The ifs are the part that breaks: one gets forgotten, movement runs
# during a cutscene, and nothing errors.
#
# These four rows are that enum's vocabulary, and every one of them compiles to the line a person
# would have written - one line, in most cases the SAME line:
#
#   Go to mode X    mode = Mode.X
#   In mode X       mode == Mode.X
#   Push mode X     push_mode(Mode.X) - the same, remembering what was underneath: menus open OVER
#                   pause, which sits OVER playing, and that is a stack whether or not a project
#                   admits it
#   Go back         go_back()
#
# The last two call FUNCTIONS the Edit modes dialog declares beside the four declarations, rather
# than writing the two lines each themselves. Two reasons, and the second is the one that decided it:
# a row named Push Mode whose only call is `push_back` would claim `push_back` in every list a reader
# ever writes - the vocabulary index reads a leading call as what a row is ABOUT - and a row that
# calls `push_mode` is about pushing a mode, which is true.
#
# WHY GOING TO A MODE IS ONE PLAIN ASSIGNMENT: the announcement rides in the `mode` variable's own
# SETTER, which is where Godot puts "and tell everybody" - so nothing has to remember to emit the
# signal, a project that assigns the variable directly is already announcing it, and the line a row
# writes is the line anybody would have typed. That is also what lets these lift both ways.
#
# The declarations they lean on (the `Mode` enum, the `mode` variable with its setter, `mode_changed`
# and `mode_stack`) are ORDINARY rows the Edit modes dialog writes - so a project that hand-wrote
# them is already using these, and a project that never asked for modes has none of it.
#
# WHY `from_mode, to_mode` ON THE SIGNAL: the moment of a change is where the real work lives - fade
# the music down as the cutscene starts, bring it back after - and half of that question is what we
# just LEFT. On leaving fires before On entering, always, because the room is emptied before the next
# one is filled.
@tool
class_name EventForgeGameStateACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker category. One section, so the four rows and the two triggers read as one idea.
const CAT: String = "Game State"

## The mode parameter every one of them takes, with the hint that makes it a list of THIS sheet's
## declared modes rather than free text.
const MODE_HINT: String = "mode_reference"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.act("GoToMode", "Go To Mode", "mode = Mode.{mode}", CAT, "Go to mode {mode}", "Moves the whole game into another mode and says so. Groups that run in a mode start and stop running by themselves; On entering and On leaving rows do the work of the moment itself.").param_built(_mode_param()))

	descriptors.append(F.cond("InMode", "In Mode", "mode == Mode.{mode}", CAT, "In mode {mode}", "True while the game is in this mode. For a whole group of rows, say it once on the group instead - the group's own \"runs in\" word does this for every row inside it.").param_built(_mode_param()))

	descriptors.append(F.act("PushMode", "Push Mode", "push_mode(Mode.{mode})", CAT, "Push mode {mode}", "Goes to a mode REMEMBERING the one underneath - a menu opened over a pause that sits over playing. Go back returns to whatever was under this one, which is the escape-key bug solved in the vocabulary.").param_built(_mode_param()))

	descriptors.append(F.act("GoBackMode", "Go Back", "go_back()", CAT, "Go back", "Returns to the mode under this one - the menu closes onto the pause it opened over. With nothing pushed it does nothing at all, which is what makes it safe to bind to a key."))

	descriptors.append(F.trig(EventSheetModeFacts.ENTERING_TRIGGER_ID, "On Entering Mode", EventSheetModeFacts.CHANGED_SIGNAL, CAT, "On entering {mode}", "Runs the moment the game enters this mode. On leaving fires FIRST, always in that order, so the room is emptied before the next one is filled.").param_built(_mode_param()))

	descriptors.append(F.trig(EventSheetModeFacts.LEAVING_TRIGGER_ID, "On Leaving Mode", EventSheetModeFacts.CHANGED_SIGNAL, CAT, "On leaving {mode}", "Runs the moment the game leaves this mode, before anything answering the mode it is entering. Fade the music down here and bring it back in the other one.").param_built(_mode_param()))

	return descriptors


## The one parameter these six share: which mode, as a member of this sheet's own enum. The hint is
## what turns the field into that list rather than into free text, and the default names no mode at
## all - a row must say which, and the picker's own list is where the answer comes from.
static func _mode_param() -> ACEParam:
	return F.make_param(EventSheetModeFacts.MODE_PARAM, "String", "", "Mode",
		"Which of this game's declared modes. The Edit modes dialog on the sheet head is where they are declared.",
		MODE_HINT)
