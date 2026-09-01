# EventForge - the one gesture a tool sheet's undoable rows make, said once.
#
# A sheet that edits the scene the user has open is a tool, and a tool that changes somebody's scene
# without their Ctrl+Z working afterwards is a tool they will not run twice. Godot's answer is the
# editor's own undo manager: a named action is opened, the do and undo halves of each change are
# added to it, and committing it both performs the change and files it in the history. Nothing here
# invents any of that - EditorInterface.get_editor_undo_redo() is the engine's own object, and every
# line below is the line a tool author would have typed.
#
# WHAT THIS FILE IS FOR. Four readers have to agree about that bracket down to the byte:
#   - the compiler, which writes it around the undoable rows of one event;
#   - the importer, which has to recognise it again and hand the rows back without it;
#   - the Doctor's tool-edits section, which asks whether an edit was made undoably at all;
#   - the sheet's own quiet amber state, which is the same finding read on the row.
# Written out four times those four would drift on the first reword, so the words, the ace ids and
# the shapes live here and the four ask.
#
# THE ONE-GESTURE RULE. Every undoable row of ONE event shares ONE undo step: the action is created
# before the first of them and committed after the last, so a reader's single Ctrl+Z takes back the
# whole gesture rather than peeling it off one property at a time. Committing is also what PERFORMS
# the change (EditorUndoRedoManager.commit_action executes the do half by default), which is why an
# undoable row on its own does nothing and why the bracket is the compiler's job rather than each
# row's: three rows each opening and committing their own action would be three entries in the
# history, and the reader would have to press Ctrl+Z three times to get back where they started.
#
# NESTING CANNOT HAPPEN WHILE THE BODY RUNS TO ITS END, and that much is a property of the shape
# rather than a promise. The bracket opens and closes inside one event body with nothing held between
# fires - no member, no flag, no static - so an event that fires again on the next frame opens a
# fresh action over a closed one.
#
# THE ONE THING THE SHAPE CANNOT RULE OUT is a body that stops half way. A row that WAITS between the
# first and the last undoable row of an event suspends the function with the action still OPEN, and
# anything else that runs during that suspension opens its own. That is not a hazard this file can
# close by writing the bracket differently: the reader put a wait inside a gesture, and only they can
# say whether the gesture or the wait was the mistake. So the compiler SAYS SO - `waits_inside` below
# is what it asks, and the warning names the event - rather than either pretending it cannot happen
# or quietly moving somebody's rows around.
#
# THE REMOVAL GUARD NEVER WRAPS ONE OF THESE. `create_action` is emitted at the body indent, in front
# of the first undoable row, while a row inside the removal guard is emitted one indent further in -
# so if an undoable row were ever guarded, a false guard would commit an action with no operations in
# it: an empty entry in somebody's undo history. It cannot happen today, because the guard is only
# ever raised over the three destroy rows (EventForgeRemovalGuard.GUARDED_ACE_IDS) and none of them
# writes to the history, and the suite pins that those two lists stay disjoint.
#
# THE ROWS ARE EDITOR-ONLY, in the same sense the rest of the Editor object's vocabulary is: the undo
# history belongs to the editor, and a game has none. The picker already keeps "Editor Tools" pages
# off a game sheet; the compiler asks the same question again on the way out, so a row that reached a
# game sheet by being pasted refuses there, in the trigger's own words, instead of compiling into a
# line that would fail the moment the game ran.
@tool
class_name EventForgeUndoableEdits
extends RefCounted

## The three rows that write into the editor's undo history. Frozen with the descriptors they name -
## the compiler brackets exactly these, the importer reads exactly these back, and the Doctor offers
## exactly these as the respelling of an edit that cannot be taken back.
const ACE_IDS: Array[String] = ["SetPropertyUndoable", "AddNodeUndoable", "RemoveNodeUndoable"]

## The editor's undo manager, as every emitted line spells it. One spelling, so the bracket the
## compiler writes and the bracket the importer looks for cannot differ by a character.
const HISTORY: String = "EditorInterface.get_editor_undo_redo()"

## The line that closes the gesture. The opening line carries a name and is built below.
const COMMIT_LINE: String = "EditorInterface.get_editor_undo_redo().commit_action()"

## How the opening line starts, up to the name. One cheap `begins_with` in front of the whole
## bracket reading, so the importer pays a substring test per statement rather than a registry
## lookup: this is asked of every line of every file anybody opens.
const CREATE_PREFIX: String = "EditorInterface.get_editor_undo_redo().create_action("

## What the gesture is called when the event has no trigger of its own to be named after - a sheet
## function's body, a fragment lifted on its own. Honest rather than clever: it says what it is.
const FALLBACK_GESTURE: String = "Editor tool edit"

## The plain edits whose undoable twin the Doctor can offer as a one-click respelling. Key is the row
## somebody picked, value the row that does the same thing through the history. The three pairs share
## their parameter names exactly (target/property/value, node/parent, node), which is what makes the
## respelling a change of ace id and nothing else - no value is rewritten, so nothing can be lost.
const TWIN_FOR_ACE: Dictionary = {
	"SetProperty": "SetPropertyUndoable",
	"AddNodeToEditedScene": "AddNodeUndoable",
	"RemoveChild": "RemoveNodeUndoable",
}

## The three kinds of edit a tool makes to the scene it has open, as the Doctor names them. Read off
## an emitted line rather than off an ace id, so a change somebody typed into a verbatim block earns
## the same finding a picked row does.
const EDIT_PROPERTY: String = "property"
const EDIT_ADD: String = "add"
const EDIT_REMOVE: String = "remove"

## The calls that add a node to a tree and take one back out of it, as the lines that make them are
## spelled. Substring tests rather than patterns: this runs over every action of every event of a
## tool sheet, and the shapes are unambiguous enough that a pattern would only be slower.
const ADD_CALLS: Array[String] = [".add_child(", ".add_sibling("]
const REMOVE_CALLS: Array[String] = [".remove_child(", ".queue_free(", ".free("]

## How a sheet says it is working on the scene the editor has open, rather than on itself. This is
## the gate the not-undoable rule stands behind, and it matters more than it looks: a @tool script on
## an ordinary node sets its own properties all day long and is perfectly correct doing so, because
## it is not editing anybody's scene and there is no history for it to be missing from. A sheet that
## reaches for the edited scene root or for the editor's selection IS editing somebody's scene, and
## that is the sheet the rule has something to say about.
const OPEN_SCENE_MARKS: Array[String] = [
	"EditorInterface.get_edited_scene_root()",
	"EditorInterface.get_selection()",
]

## Compiled once for the life of the session: the property assignment the plain Set Property row and
## a hand-typed line both write, and the opening line of a gesture with its name captured.
static var _regexes: Dictionary = {}


## True when this text works on the scene the editor has open (see OPEN_SCENE_MARKS). Asked of a
## whole file by the Doctor before it opens it, and of a whole sheet's emitted rows by the rule.
static func touches_open_scene(text: String) -> bool:
	for mark: String in OPEN_SCENE_MARKS:
		if text.contains(mark):
			return true
	return false


## The line that opens a gesture of this name. The name is escaped the way GDScript escapes a string
## literal, so a trigger whose words carry a quote cannot break the file it is written into.
static func create_line(gesture: String) -> String:
	return "%s.create_action(\"%s\")" % [HISTORY, gesture.c_escape()]


## The name a gesture opened at this line carries, or "" when the line is not one. The exact inverse
## of create_line, which is what lets the importer ask "is this the bracket the compiler would have
## written here" instead of guessing.
static func gesture_of_create_line(line: String) -> String:
	var found: RegExMatch = _regex("^EditorInterface\\.get_editor_undo_redo\\(\\)\\.create_action\\(\"(?<gesture>.*)\"\\)$").search(
		line.strip_edges())
	return "" if found == null else found.get_string("gesture").c_unescape()


## True when this row is one of the three that write into the editor's undo history. Asked of an
## action of any kind, so a verbatim block or a match row answers false rather than erroring.
static func is_undoable(item: Variant) -> bool:
	if not (item is Resource):
		return false
	var row: Resource = item
	if not bool(row.get("enabled")):
		return false
	return ACE_IDS.has(str(row.get("ace_id")))


## The slots of the FIRST and LAST undoable row in one lane, as x and y. (-1, -1) when the lane has
## none, which is the answer the compiler brackets nothing on. First and last rather than each,
## because everything between them belongs to the same gesture whether it is undoable or not: an
## ordinary row standing between two undoable ones is part of what the reader did.
static func gesture_span(actions: Array) -> Vector2i:
	var first: int = -1
	var last: int = -1
	for index: int in actions.size():
		if is_undoable(actions[index]):
			if first < 0:
				first = index
			last = index
	return Vector2i(first, last)


## True when a row that WAITS stands anywhere inside one lane's gesture. An awaited row suspends the
## function with the action open, so the gesture is still open while other events run - which is the
## one shape the bracket cannot close on its own, and therefore the one the compiler warns about.
## Asked of the span rather than of the whole lane: a wait BEFORE the first undoable row, or after
## the last, is outside the gesture and is nobody's problem.
static func waits_inside(actions: Array, span: Vector2i) -> bool:
	if span.x < 0:
		return false
	for index: int in range(span.x, mini(span.y + 1, actions.size())):
		var row: Resource = actions[index] as Resource
		if row == null or row.get("enabled") == false:
			continue
		if row.get("is_awaited") == true or row.get("await_call") == true:
			return true
	return false


## The words the compiler says it in. Here rather than in the compiler for the reason every other
## spelling in this file is here: the test that pins the warning and the line that writes it have to
## be one string.
static func waits_inside_warning(gesture: String) -> String:
	return "%s: a row between its undoable rows WAITS, so the undo step stays open across that wait and anything else that runs meanwhile opens its own. Move the waiting row out from between them, or give it an event of its own." % gesture


## What the gesture written around one event's rows is called: the event's own trigger, said the way
## the picker says it. An event with no trigger of its own (a sub-event, a sheet function's body)
## inherits the name of the event it sits under, so one gesture keeps one name however deep the rows
## that make it are.
static func gesture_name(event_row: EventRow, inherited: String = "") -> String:
	if event_row != null and not event_row.trigger_id.strip_edges().is_empty():
		return gesture_of_trigger(event_row.trigger_provider_id, event_row.trigger_id)
	return inherited if not inherited.strip_edges().is_empty() else FALLBACK_GESTURE


## The words one trigger is known by, off the registry so a renamed trigger is named right. The
## DISPLAY NAME rather than the display text: the name goes in the editor's own undo menu, where
## "On Editor Run" reads and "On editor run (File > Run)" does not. English on purpose - it is a
## string in somebody's generated file, and a file that said something different per machine would
## not be the same file.
static func gesture_of_trigger(provider_id: String, trigger_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		provider_id if not provider_id.strip_edges().is_empty() else "Core", trigger_id)
	return FALLBACK_GESTURE if descriptor == null else descriptor.display_name


## The kind of scene edit one emitted line makes, or "" when it makes none. This is the question the
## Doctor's tool-edits section and the sheet's quiet amber state both ask, so the two can never
## disagree about which lines are edits.
##
## A line that already goes through the history is NOT an edit by this reading: it is the answer.
static func raw_edit_kind(line: String) -> String:
	var text: String = line.strip_edges()
	if text.is_empty() or text.contains(HISTORY):
		return ""
	for call_text: String in ADD_CALLS:
		if text.contains(call_text):
			return EDIT_ADD
	for call_text: String in REMOVE_CALLS:
		if text.contains(call_text):
			return EDIT_REMOVE
	# A property written on something: a name, a `$Path`, a `%Unique`, or a call chain, followed by a
	# dot, a property name and a single `=`. The single is what keeps a comparison (`==`) and every
	# compound assignment out of it: those change nothing on their own or are already a read.
	return EDIT_PROPERTY if _regex("^[A-Za-z_$%][A-Za-z0-9_.$%\"'/()]*\\.[A-Za-z_][A-Za-z0-9_]*[ \\t]*=[ \\t]*[^=].*$").search(text) != null else ""


## A pattern, compiled once and held. These run over every line of every tool sheet the Doctor reads.
static func _regex(pattern: String) -> RegEx:
	if not _regexes.has(pattern):
		_regexes[pattern] = RegEx.create_from_string(pattern)
	return _regexes[pattern]
