@tool
class_name EventSheetRunControls
extends RefCounted

# THE WAYS TO PLAY. One table, six entries, and every control that offers a run reads it - the play
# button's face and dropdown at the head of the strip, and the same six as plain buttons on the
# expanded strip:
#
#   ▶  Run Scene              save, then play the scene this sheet's script is on
#   🐞 Debug layout           the same run with Event Trace, Live Values and breakpoints armed
#   ⏱ Run with profiler      the same run with the costs lens on, the numbers kept after it stops
#   ▶  Play as host + client  two tagged copies of the game at once, for testing a networked one
#   ▶  Preview layout         Godot's own F6, under the name an event-sheet author reaches for
#   ▶▶ Preview project        Godot's own F5, the whole game from its start
#
# The last two are RELABELS and nothing else: same key, same behaviour, familiar name. The first
# four are the sheet's own gestures. Every one of them hands the run to EditorInterface, and while a
# game is running the ones that would start another read Stop or Restart instead, so no control on
# the strip is ever lying about what it will do.

## The ways to play, in the order the play button's dropdown lists them, as
## [id, resting label, tooltip, editor icon, shortcut action]. Static so a test pins the set without
## a dock behind it, and so every strip that offers a run offers the same six under the same words.
##
## The tooltip cell is empty for a run whose tooltip has to report a live editor setting; ask
## `tooltip_for`, which knows the one module that writes it.
const BUTTONS: Array = [
	["run_scene", "Run Scene",
		"Save, then play the scene that uses this sheet's script.", "Play", ""],
	["debug_layout", "🐞 Debug layout",
		"Run this layout with the sheet's own debugger armed: Event Trace lights the rows as they fire, Live Values streams the variables, and rows with a breakpoint pause the game.",
		"Debug", "debug_layout"],
	["run_profiler", "⏱ Run with profiler",
		"Run this layout with the trace armed and the costs lens on. Play for a while, stop, and every row wears what one fire of it cost - kept until you clear it, and still there when you open the editor tomorrow.",
		"Timer", ""],
	["host_client", "Play as host + client", "", "Instance", ""],
	["preview_layout", "▶ Preview layout",
		"Run the scene this sheet's script is on (F6). The sheet keeps running beside it.",
		"PlayScene", "preview_layout"],
	# MainPlay, not MainScene: the editor ships no icon called MainScene (probed against the running
	# 4.7 editor theme), so this entry arrived iconless on the face, in the dropdown and on the
	# expanded strip. MainPlay is the icon Godot's own run bar wears for exactly this run.
	["preview_project", "▶▶ Preview project",
		"Run the project's main scene (F5) - the whole game from its start, not just this layout.",
		"MainPlay", "preview_project"],
]

## The two entries that are pure relabels of Godot's own keys. The play button's dropdown puts them
## under their own heading, below the four the sheet owns: same key, same run, familiar name.
const GODOT_OWN: PackedStringArray = ["preview_layout", "preview_project"]

## What a button says instead while a game is running. A run that would start a second copy stops
## the first one; Preview project restarts it, because "the whole game from its start" is what that
## button means at any moment. Debug layout and the profiler keep their names: pressing either while
## a game runs re-arms and plays again, which is what their names already say.
const RUNNING_LABELS: Dictionary = {
	"run_scene": "■ Stop",
	"host_client": "■ Stop",
	"preview_layout": "■ Stop",
	"preview_project": "↻ Restart",
}

## Where the play button's chosen face is remembered: the editor's per-project metadata, section
## "eventsheets", beside every other per-project editor choice. Per project, because which way you
## reach for first is a property of the game you are making.
const MAIN_RUN_META_KEY: String = "eventsheets_play_main"

## What the face does in a project that has never chosen.
const DEFAULT_MAIN_RUN: String = "run_scene"

## How often the strip re-asks the editor whether a game is running, in seconds. A game can start
## and stop without this dock hearing about it - closed from its own window, or played and stopped
## from Godot's own play bar - and the one primary control on the strip must never be the last to
## know. One boolean read per tick, and a relabel only when the answer CHANGED.
const POLL_SECONDS: float = 0.5

var _dock: Control = null
var _buttons: Dictionary = {}
var _main_run: String = ""

## The run state the last relabel was made for. Kept so a poll that finds nothing changed costs one
## comparison rather than a walk over every adopted button.
var _labelled_running: bool = false

## The timer that asks. Held so a second build cannot leave two of them ticking.
var _poll_timer: Timer = null


func init(dock: Control) -> void:
	_dock = dock


## Registers a button so the strip can relabel it when the game starts and stops. Several controls
## carry the same run (the play button's face and the expanded strip's own button), so each id keeps
## EVERY adopter - a single slot per id let the second one steal the first one's relabel, and the
## toolbar's Preview button never became Stop. Freed buttons are pruned on the way in.
func adopt(button_id: String, button: Button) -> void:
	var adopters: Array = []
	for known: Variant in _buttons.get(button_id, []):
		if is_instance_valid(known) and known != button:
			adopters.append(known)
	adopters.append(button)
	_buttons[button_id] = adopters


## Drops a button from every id it was adopted under. The play button's face changes which run it
## is, and a face still adopted by its old id would be relabelled by a run it no longer performs.
func release(button: Button) -> void:
	for button_id: Variant in _buttons:
		var kept: Array = []
		for known: Variant in _buttons[button_id]:
			if is_instance_valid(known) and known != button:
				kept.append(known)
		_buttons[button_id] = kept


## The label a button wears right now: its resting name, or what it does while a game is running.
static func label_for(button_id: String, running: bool) -> String:
	if running and RUNNING_LABELS.has(button_id):
		return str(RUNNING_LABELS[button_id])
	for entry: Variant in BUTTONS:
		if str((entry as Array)[0]) == button_id:
			return str((entry as Array)[1])
	return button_id


## Whether this is one of the ways to play at all - the guard every stored or passed id goes
## through, so a stale choice degrades to the default rather than to a face that runs nothing.
static func has_run(run_id: String) -> bool:
	for entry: Variant in BUTTONS:
		if str((entry as Array)[0]) == run_id:
			return true
	return false


## The editor icon a run wears, by the editor theme's own name for it. Empty when the id is not one
## of the six; an icon the running editor theme does not carry simply never arrives, and the words
## carry the control on their own.
static func icon_for(run_id: String) -> String:
	for entry: Variant in BUTTONS:
		var record: Array = entry
		if str(record[0]) == run_id:
			return str(record[3])
	return ""


## The shortcut-table action whose key this run prints, or "" for a run with no key of its own.
## Nothing here types a key name: the binding is looked up, so a rebind shows through untouched.
static func shortcut_action_for(run_id: String) -> String:
	for entry: Variant in BUTTONS:
		var record: Array = entry
		if str(record[0]) == run_id:
			return str(record[4])
	return ""


## What a run says on hover, translated. "Play as host + client" is the one whose words depend on a
## live editor setting - it reports whether Godot's Run Multiple Instances is already set the way it
## would set it - so it is asked of the one module that writes that setting.
static func tooltip_for(run_id: String) -> String:
	if run_id == "host_client":
		return EventSheetRunInstances.tooltip()
	for entry: Variant in BUTTONS:
		var record: Array = entry
		if str(record[0]) == run_id:
			return EventSheetL10n.translate(str(record[2]))
	return ""


## The chosen main run, resolved from whatever is on record. Anything that is not one of the six
## means nobody has chosen, and nobody choosing means Run Scene. Pure, so the suite pins the whole
## tri-state without an editor behind it.
static func main_run_from(stored: Variant) -> String:
	if stored is String and has_run(str(stored)):
		return str(stored)
	return DEFAULT_MAIN_RUN


## Which run the play button's face performs. Read once per session and kept, so the face and the
## dropdown's tick are one answer rather than two reads that can disagree.
func main_run_id() -> String:
	if _main_run.is_empty():
		_main_run = main_run_from(_stored_main_run())
	return _main_run


## Choose the face's run and remember it for this project. An id that is not one of the six is
## refused rather than stored, so a later table never has to clean up after this one.
func set_main_run(run_id: String) -> void:
	if not has_run(run_id):
		return
	_main_run = run_id
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", MAIN_RUN_META_KEY, run_id)


## Relabels every adopted button for the current run state. Cheap enough to call on a timer or on
## any dock refresh.
func refresh() -> void:
	refresh_as(is_playing())


## Starts (or restarts) the watch that keeps the labels honest. `host` is the node the timer lives
## on - the dock itself, never the toolbar, because the strip's children are a pinned list and a
## Timer among them is not a control anybody meant to put there.
##
## Without this, the face's words were only ever recomputed when the SHEET started a run or the
## choice changed: a game closed from its own window, or started and stopped from Godot's play bar,
## left the face reading "■ Stop" while nothing ran. Clicking still did the right thing (activate
## re-asks), but the one primary control on the strip was saying something untrue.
func watch(host: Node) -> void:
	if host == null:
		return
	if _poll_timer != null and is_instance_valid(_poll_timer):
		_poll_timer.queue_free()
	_poll_timer = Timer.new()
	_poll_timer.name = "EventSheetRunWatch"
	_poll_timer.wait_time = POLL_SECONDS
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(poll)
	host.add_child(_poll_timer)


## One tick of the watch: relabel only if the editor's answer changed since the last relabel.
func poll() -> void:
	poll_step(is_playing())


## Whether a tick that found `running` should relabel, and the bookkeeping that goes with it. Pure
## enough to pin without an editor behind it: the suite drives the whole start/stop transition
## through this rather than through a running game.
func poll_step(running: bool) -> bool:
	if running == _labelled_running:
		return false
	refresh_as(running)
	return true


## Relabel every adopted button for a KNOWN run state, rather than for the one the editor reports.
## The watch owns this: it has already asked, and asking twice invites the two answers to disagree.
func refresh_as(running: bool) -> void:
	_labelled_running = running
	for button_id: Variant in _buttons:
		for button: Variant in _buttons[button_id]:
			if is_instance_valid(button):
				(button as Button).text = EventSheetL10n.translate(label_for(str(button_id), running))


func is_playing() -> bool:
	var editor_interface: Object = EventSheetEditorSettings.interface()
	if editor_interface == null or not editor_interface.has_method("is_playing_scene"):
		return false
	return bool(editor_interface.call("is_playing_scene"))


## One run asked for. While a game runs the ones that would start a second copy stop it instead,
## which is what their labels say by then.
func activate(button_id: String) -> void:
	var running: bool = is_playing()
	match button_id:
		"run_scene":
			if running:
				_stop()
			elif _dock != null and _dock.has_method("_run_from_sheet"):
				_dock.call("_run_from_sheet")
		"host_client":
			if running:
				_stop()
			elif _dock != null and _dock.has_method("_play_as_host_and_client"):
				_dock.call("_play_as_host_and_client")
		"preview_layout":
			if running:
				_stop()
			else:
				_play_current()
		"preview_project":
			if running:
				_stop()
				_play_main()
			else:
				_play_main()
		"debug_layout":
			_arm_debugger()
			if running:
				_stop()
			_play_current()
		"run_profiler":
			# The dock owns this one: arming the trace is the small half, and clearing the old numbers
			# and turning the costs lens on is the half that makes the button mean what it says.
			if _dock != null and _dock.has_method("_run_with_profiler"):
				_dock.call("_run_with_profiler")
	refresh()


## Debug layout is the ordinary run with the sheet's own debugger turned on first - the three
## switches the Tools menu already offers, flipped together so "debug this layout" is one gesture.
func _arm_debugger() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return
	# Set the flags rather than calling the toggles: a toggle turns a switch that is already on back
	# OFF, and "Debug layout" must always end with all three armed.
	sheet.emit_event_trace = true
	sheet.emit_live_values = true
	sheet.emit_breakpoints = true
	_dock._set_status(EventSheetL10n.translate("Debug layout: Event Trace, Live Values and breakpoints are on for this run."))


func _play_current() -> void:
	var editor_interface: Object = EventSheetEditorSettings.interface()
	if editor_interface == null or not editor_interface.has_method("play_current_scene"):
		_dock._set_status("Preview needs the Godot editor - there is nothing to run from here.", true)
		return
	_dock._on_save_requested()
	editor_interface.call("play_current_scene")


func _play_main() -> void:
	var editor_interface: Object = EventSheetEditorSettings.interface()
	if editor_interface == null or not editor_interface.has_method("play_main_scene"):
		_dock._set_status("Preview needs the Godot editor - there is nothing to run from here.", true)
		return
	_dock._on_save_requested()
	editor_interface.call("play_main_scene")


func _stop() -> void:
	var editor_interface: Object = EventSheetEditorSettings.interface()
	if editor_interface != null and editor_interface.has_method("stop"):
		editor_interface.call("stop")


## What the project chose, read the way every other per-project editor choice here is read: with a
## NON-null sentinel default, because a missing key read with a null default prints an editor ERROR
## on a fresh project. "" is that sentinel, and it is not one of the six, so it reads as no choice.
func _stored_main_run() -> Variant:
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return ""
	return settings.call("get_project_metadata", "eventsheets", MAIN_RUN_META_KEY, "")

