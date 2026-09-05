## @ace_tags(juice, feedback, game feel)
## @ace_category("Feedback Player")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/juice/icon.svg")
class_name FeedbackPlayer
extends Node
## The list of feedbacks an object plays: add this node under it, fill the list with shakes, flashes, holds and loops, and one row plays the lot. The list is the same shape a moment file holds, so it can be saved out and shared; the strength on the row scales every amount in it.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("FeedbackPlayer behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Feedbacks Started")
## @ace_category("Feedback Player")
signal on_feedbacks_started(at_strength: float)
## @ace_trigger
## @ace_name("On Feedbacks Finished")
## @ace_category("Feedback Player")
signal on_feedbacks_finished
## @ace_trigger
## @ace_name("On Feedback Signal")
## @ace_category("Feedback Player")
signal on_feedback_signal(word: String)
## @ace_trigger
## @ace_name("On Feedback Started")
## @ace_category("Feedback Player")
signal on_feedback_started(label: String)
## @ace_trigger
## @ace_name("On Feedback Finished")
## @ace_category("Feedback Player")
signal on_feedback_finished(label: String)
## @ace_trigger
## @ace_name("On Feedback Skipped")
## @ace_category("Feedback Player")
signal on_feedback_skipped(label: String, why: String)
## @ace_trigger
## @ace_name("On Hold Reached")
## @ace_category("Feedback Player")
signal on_hold_reached
## @ace_trigger
## @ace_name("On Loop")
## @ace_category("Feedback Player")
signal on_loop(loops_left: int)

# @inspector_header Feedback Player #8a6fd4
# @inspector_info One card per feedback. Pause and Hold space them out, Loop Start and Loop Back repeat a stretch, and everything else is felt. Play plays the list; the strength on the row scales every amount in it.
## The feedbacks this object plays, in order. Each one is a card: what it does, how much, how long, and the timing words between them.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:cards:kind=verb,schema=feedback_steps,stripes=category") var steps: Array[Dictionary] = []
## What every amount in the list is scaled by before the strength on the row is applied. Turn a whole object's feedback down without retuning a single card.
@export var strength: float = 1.0
## Which end of the list a play starts from.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:top to bottom,bottom to top") var direction: String = "top to bottom"
## What a second play does while the first is still running: restart it, ignore the new one, or let the two overlap.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:restart,ignore,overlap") var while_playing: String = "restart"
## The shortest gap between two plays, in seconds. A play asked for sooner than this is refused, which is how a rapid-fire hit stops stacking its own feedback.
@export var cooldown: float = 0.0
## Optional: a moment file to play INSTEAD of the list. Drop one here to share a beat between objects; Save As File writes this list out as one.
@export var moment_file: Resource = null

# --- The play: one list, one head, one strength ---
# A play is a walk down the list, and its identity is a TOKEN. Every walk in flight holds one, and a
# suspended step does nothing at all once its token has left the live list - which is how a stop, a
# restart or a skip ends a coroutine without a flag per step, and how "overlap" runs two plays at
# once without either of them ending the other.
#
# The card the head is on is not copied. A card carries its own live values while it runs (the loops
# it has left), and those are what the remote Inspector of the running node shows.

## The most steps one play may take, loops included. A Loop Back with nothing to end it would
## otherwise be a play that never comes back; this is the number at which it gives up and says so.
const MAX_PLAY_STEPS: int = 4096

## The two directions a list is walked in, and the three answers to "it is already playing".
const TOP_TO_BOTTOM: String = "top to bottom"
const BOTTOM_TO_TOP: String = "bottom to top"
const RESTART: String = "restart"
const IGNORE: String = "ignore"
const OVERLAP: String = "overlap"

## The step words this node adds to the ten a moment file holds. Every other word is played by the
## Juice behaviour beside it - the same call a moment file makes - so a card list and a moment file
## are the same ten words plus timing.
const PAUSE: String = "pause"
const HOLD_UNTIL: String = "hold_until"
const LOOP_START: String = "loop_start"
const LOOP_BACK: String = "loop_back"
const TWEEN_PROPERTY: String = "tween_property"
const EMIT_SIGNAL: String = "emit_signal"
const PLAY_PLAYER: String = "play_player"

## Raised whenever a pause ends, however it ended. Private, so it is plumbing rather than vocabulary.
signal _resumed

## Live while the game runs - written by the play, read in the remote Inspector of the running node.
var playing: bool = false
var progress: float = 0.0
var now_playing: String = ""

var _live: Array[int] = []
var _next_token: int = 0
var _paused: bool = false
var _played_once: bool = false
var _last_played_at: float = -1000.0
var _order: Array = []
var _head: int = 0
var _head_strength: float = 1.0
var _restore_to: Array = []
var _juice_node: Node = null
var _told_no_juice: bool = false
## The Juice behaviour beside this node - found by the step call it answers rather than by its class,
## so this pack names no other pack. Said once when there is none, because a list of ten shakes with
## no behaviour under it would otherwise be ten warnings a frame.
func _juice() -> Node:
	if _juice_node != null and is_instance_valid(_juice_node):
		return _juice_node
	var looked: Array = []
	if host != null:
		looked.append_array(host.get_children())
	looked.append_array(get_children())
	for child: Variant in looked:
		var node: Node = child as Node
		if node != null and node.has_method("moment_step"):
			_juice_node = node
			return _juice_node
	if not _told_no_juice:
		_told_no_juice = true
		push_warning("Feedback Player: %s has no Juice behaviour beside it, so its shake, flash and hitstop steps did nothing. Add a Juice node under the same object." % name)
	return null

# --- Addressed by label: the rows that edit the list while the game runs ---
# Every row that names one feedback names it by its LABEL - the name typed on the card in the
# Inspector, or, for a card nobody named, its own word. That is the whole addressing scheme: a
# list tuned in the Inspector and a list retuned by rows can never disagree about which step is
# meant, and a label that is not in the list is said out loud rather than quietly ignored.

## Which family a card belongs to when it does not say so itself. An OVERRIDE list: a word that is
## not in it belongs to no family, so Mute Feedback Category leaves it alone, and a card carrying
## its own `category` key answers with that instead of with this. It is the RUNTIME copy of the
## question, and the editor's card list takes its stripe colours from here rather than keeping a
## second one, so a word can only ever have one family.
const CATEGORY_OF: Dictionary = {
	"shake": "camera",
	"zoom": "camera",
	"punch": "transform",
	"flash": "transform",
	"hitstop": "pause",
	"slowmo": "pause",
	"shockwave": "screen",
	"chromatic": "screen",
	"pulse": "screen",
	"hold": "screen",
	"pause": "pause",
	"hold_until": "pause",
	"loop_start": "loop",
	"loop_back": "loop",
	"emit_signal": "signal",
	"play_player": "signal"
}

## The keys Set Feedback Field writes and Feedback Field reads. Named rather than open, so a typo
## cannot quietly add a key nothing ever looks at - the one failure a dictionary with no schema
## behind it is prone to.
const FIELD_KEYS: PackedStringArray = ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops"]

## The families muted right now, as a set. Empty in every project that never mutes one, which is
## why it costs a lookup in an empty dictionary rather than a branch per card.
var _muted: Dictionary = {}

## The labels Skip Feedback Once has been asked about and the play has not reached yet. Each is
## taken out the moment it is used, so the row means once rather than from now on.
var _skip_once: Dictionary = {}

## Hold Here, and the label Jump To Feedback wants the head moved to at the next step.
var _held: bool = false
var _jump_to: String = ""

## When this play began, on the wall clock, so one card's own progress can be answered without a
## tick running to count it.
var _started_at: float = 0.0
## Every label in the list, in order - what For Each Feedback loops over, and what a settings
## screen that lists a beat's parts is built out of.
## @ace_looping(feedback_label)
## @ace_name("For Each Feedback")
## @ace_category("Feedback Player")
## @ace_description("Runs the actions under it once per feedback in this player's list, top to bottom, with the label of each one in hand.")
func for_each_feedback() -> Array:
	var labels: Array = []
	for entry: Variant in _steps_now():
		if entry is Dictionary:
			labels.append(_label_of(entry as Dictionary))
	return labels

## @ace_action
## @ace_featured
## @ace_name("Play Feedbacks")
## @ace_category("Feedback Player")
## @ace_description("Plays this node's list of feedbacks and carries straight on with the rows under this one. The strength scales every amount in the list, so a light hit and a heavy one are one list at two numbers.")
## @ace_display_template("Play feedbacks at [b]{at_strength}[/b]")
## @ace_param(at_strength, default: 1.0, desc: "Scales every amount in the list. 1 is the list as tuned, 0.5 a lighter version of the same beat.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.play({at_strength})")
func play(at_strength: float) -> void:
	if _may_start():
		_walk(_steps_now(), at_strength, direction == BOTTOM_TO_TOP)

## @ace_action
## @ace_featured
## @ace_name("Play Feedbacks And Wait")
## @ace_category("Feedback Player")
## @ace_description("Plays the list and WAITS for the last card to finish - the rows under this one are what happens afterwards. Use it when the hit has to land before the death animation starts.")
## @ace_display_template("Play feedbacks at [b]{at_strength}[/b] and wait")
## @ace_param(at_strength, default: 1.0, desc: "Scales every amount in the list, exactly as Play Feedbacks does.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("await $FeedbackPlayer.play_and_wait({at_strength})")
func play_and_wait(at_strength: float) -> void:
	if _may_start():
		await _walk(_steps_now(), at_strength, direction == BOTTOM_TO_TOP)

## @ace_action
## @ace_name("Play Backwards")
## @ace_category("Feedback Player")
## @ace_description("Plays the list from the far end, so the last feedback is felt first. The other half of a beat that has to undo itself - a door that opened, closing.")
## @ace_display_template("Play feedbacks backwards at [b]{at_strength}[/b]")
## @ace_param(at_strength, default: 1.0, desc: "Scales every amount in the list, exactly as Play Feedbacks does.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.play_backwards({at_strength})")
func play_backwards(at_strength: float) -> void:
	if _may_start():
		_walk(_steps_now(), at_strength, direction != BOTTOM_TO_TOP)

## @ace_action
## @ace_name("Play On Channel")
## @ace_category("Feedback Player")
## @ace_description("Plays every feedback player in a group at once, at one strength - the whole squad flinching, every button in a menu bouncing. Put the players in the group and name it here.")
## @ace_display_template("Play feedbacks on channel [b]{channel}[/b] at [b]{at_strength}[/b]")
## @ace_param(channel, default: "feedback", desc: "The group every player that should feel this is in.")
## @ace_param(at_strength, default: 1.0, desc: "Scales every amount in every list it reaches.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.play_on_channel({channel}, {at_strength})")
func play_on_channel(channel: String, at_strength: float) -> void:
	if channel.strip_edges().is_empty() or not is_inside_tree():
		return
	get_tree().call_group(channel, "play", at_strength)

## @ace_action
## @ace_featured
## @ace_name("Stop Feedbacks")
## @ace_category("Feedback Player")
## @ace_description("Stops the play where it is. Whatever a card already started keeps running on its own - this stops the LIST, not the shake it set going.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.stop()")
func stop() -> void:
	if not playing:
		return
	_live.clear()
	_resumed.emit()
	_close()

## @ace_action
## @ace_name("Skip To End")
## @ace_category("Feedback Player")
## @ace_description("Stops waiting and does everything that is left at once - the cutscene skip of a feedback list. Every card from the head down is felt, without the pauses between them.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.skip_to_end()")
func skip_to_end() -> void:
	if not playing:
		return
	_live.clear()
	_paused = false
	_resumed.emit()
	var left: Array = _order
	var from: int = _head
	var at_strength: float = _head_strength
	_close()
	for index: int in range(from, left.size()):
		if not (left[index] is Dictionary):
			continue
		var card: Dictionary = left[index]
		if _card_runs(card, at_strength) and not _is_timing(str(card.get("verb", ""))):
			_do_step(card, at_strength)

## @ace_action
## @ace_name("Restore Initial Values")
## @ace_category("Feedback Player")
## @ace_description("Puts every value this player's Tween Property cards changed back the way they found it. The undo of a list that moved the object rather than flashing it.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.restore()")
func restore() -> void:
	for entry: Variant in _restore_to:
		var card: Dictionary = entry as Dictionary
		var object: Object = card.get("object") as Object
		if object != null and is_instance_valid(object):
			object.set(str(card.get("property", "")), card.get("value"))
	_restore_to.clear()

## @ace_action
## @ace_name("Revert")
## @ace_category("Feedback Player")
## @ace_description("Stops the play and puts back what it changed, the LAST change first - so a stack of tweens unwinds in the order it was built rather than all at once.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.revert()")
func revert() -> void:
	stop()
	_restore_to.reverse()
	restore()

## @ace_action
## @ace_name("Pause Feedbacks")
## @ace_category("Feedback Player")
## @ace_description("Holds the play where it is without losing its place. Resume Feedbacks carries on from the same card.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.pause_feedbacks()")
func pause_feedbacks() -> void:
	_paused = playing

## @ace_action
## @ace_name("Resume Feedbacks")
## @ace_category("Feedback Player")
## @ace_description("Carries on from where Pause Feedbacks left off.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.resume_feedbacks()")
func resume_feedbacks() -> void:
	_paused = false
	_resumed.emit()

## @ace_condition
## @ace_name("Is Playing")
## @ace_category("Feedback Player")
## @ace_description("True while a play is running - between the started and the finished trigger.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.is_playing()")
func is_playing() -> bool:
	return playing

## @ace_condition
## @ace_name("Has Played")
## @ace_category("Feedback Player")
## @ace_description("True once this player has played at least once, and stays true. The "they have seen this already" question, with nothing to store.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.has_played()")
func has_played() -> bool:
	return _played_once

## @ace_expression
## @ace_name("Feedbacks Progress")
## @ace_category("Feedback Player")
## @ace_description("How far down the list the play has got, 0 at the first card and 1 when the last one is done.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedbacks_progress()")
func feedbacks_progress() -> float:
	return progress

## @ace_expression
## @ace_name("Feedbacks Duration")
## @ace_category("Feedback Player")
## @ace_description("The longest path through the list in seconds - the same number the head of the Inspector shows, so a row can wait exactly as long as the beat lasts.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedbacks_duration()")
func feedbacks_duration() -> float:
	return duration_of(_steps_now())

## @ace_action
## @ace_name("Add Feedback")
## @ace_category("Feedback Player")
## @ace_description("Adds one feedback to this player's list while the game runs - the same card the Inspector adds, with the same fields. Leave the after box empty to put it at the end, or name a card to put it straight after that one.")
## @ace_display_template("Add feedback [b]{step}[/b] after [b]{after_label}[/b]")
## @ace_param(step, hint: feedback_step, default: {"verb": "shake", "amount": 0.4, "seconds": 0.2}, desc: "The feedback itself: pick its kind and fill the card, exactly as in the Inspector's list.")
## @ace_param(after_label, default: "", desc: "The label of the card this one goes after. Empty puts it at the end of the list.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.add_feedback({step}, {after_label})")
func add_feedback(step: Dictionary, after_label: String) -> void:
	var list: Array = _own_list()
	var at: int = list.size()
	if not after_label.strip_edges().is_empty():
		at = _index_in(list, after_label)
		if at < 0:
			_no_such(after_label, "Add Feedback")
			return
		at += 1
	list.insert(at, _carded(step))

## @ace_action
## @ace_name("Insert Feedback Before")
## @ace_category("Feedback Player")
## @ace_description("Puts a feedback into the list immediately ABOVE the card you name - the other half of Add Feedback, for a step that has to be felt before something already in the beat.")
## @ace_display_template("Insert feedback [b]{step}[/b] before [b]{before_label}[/b]")
## @ace_param(step, hint: feedback_step, default: {"verb": "flash", "amount": 1.0, "seconds": 0.1}, desc: "The feedback itself: pick its kind and fill the card, exactly as in the Inspector's list.")
## @ace_param(before_label, default: "shake", desc: "The label of the card this one goes above.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.insert_feedback_before({step}, {before_label})")
func insert_feedback_before(step: Dictionary, before_label: String) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, before_label)
	if at < 0:
		_no_such(before_label, "Insert Feedback Before")
		return
	list.insert(at, _carded(step))

## @ace_action
## @ace_name("Replace Feedback")
## @ace_category("Feedback Player")
## @ace_description("Swaps one card in the list for another, in place. THE weapon-change row: the beat the designer tuned stays the beat, and only the kick inside it changes. The new card keeps the old one's label unless it brings its own, so every other row that names it goes on working.")
## @ace_display_template("Replace feedback [b]{label}[/b] with [b]{step}[/b]")
## @ace_param(label, default: "kick", desc: "The label of the card being swapped out.")
## @ace_param(step, hint: feedback_step, default: {"verb": "recoil", "amount": 1.0, "seconds": 0.1}, desc: "What takes its place: a kind and its fields, as in the Inspector's list.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.replace_feedback({label}, {step})")
func replace_feedback(label: String, step: Dictionary) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Replace Feedback")
		return
	var fresh: Dictionary = _carded(step)
	if str(fresh.get("label", "")).strip_edges().is_empty():
		fresh["label"] = _label_of(list[at] as Dictionary)
	list[at] = fresh

## @ace_action
## @ace_name("Remove Feedback")
## @ace_category("Feedback Player")
## @ace_description("Takes one card out of the list. What an upgrade that drops a part of a beat does, and the undo of Add Feedback.")
## @ace_display_template("Remove feedback [b]{label}[/b]")
## @ace_param(label, default: "shake", desc: "The label of the card to take out.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.remove_feedback({label})")
func remove_feedback(label: String) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Remove Feedback")
		return
	list.remove_at(at)

## @ace_action
## @ace_name("Move Feedback To")
## @ace_category("Feedback Player")
## @ace_description("Moves one card to a place in the list - the drag handle, as a row. The first card is 1; a number past the end puts it last.")
## @ace_display_template("Move feedback [b]{label}[/b] to [b]{position}[/b]")
## @ace_param(label, default: "shake", desc: "The label of the card to move.")
## @ace_param(position, default: 1, desc: "Where it lands. The first card in the list is 1.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.move_feedback_to({label}, {position})")
func move_feedback_to(label: String, position: int) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Move Feedback To")
		return
	var card: Dictionary = list[at] as Dictionary
	list.remove_at(at)
	list.insert(clampi(position - 1, 0, list.size()), card)

## @ace_action
## @ace_name("Enable Feedback")
## @ace_category("Feedback Player")
## @ace_description("Ticks one card's box, so it is felt again from the next play on. The enable box in the Inspector, as a row.")
## @ace_display_template("Enable feedback [b]{label}[/b]")
## @ace_param(label, default: "shake", desc: "The label of the card to switch on.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.enable_feedback({label})")
func enable_feedback(label: String) -> void:
	var card: Dictionary = _edited(label, "Enable Feedback")
	if not card.is_empty():
		card["active"] = true

## @ace_action
## @ace_name("Disable Feedback")
## @ace_category("Feedback Player")
## @ace_description("Unticks one card's box, so the play steps over it. What an accessibility option that drops the screen shake and keeps the sound does with one row.")
## @ace_display_template("Disable feedback [b]{label}[/b]")
## @ace_param(label, default: "shake", desc: "The label of the card to switch off.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.disable_feedback({label})")
func disable_feedback(label: String) -> void:
	var card: Dictionary = _edited(label, "Disable Feedback")
	if not card.is_empty():
		card["active"] = false

## @ace_action
## @ace_name("Set Feedback Field")
## @ace_category("Feedback Player")
## @ace_description("Retunes ONE value on one card: how much, how long, which extra word. The number box in the Inspector, as a row, so a weapon or a difficulty can move an amount without a second list.")
## @ace_display_template("Set feedback [b]{label}[/b] [b]{field}[/b] to [b]{value}[/b]")
## @ace_param(label, default: "shake", desc: "The label of the card being tuned.")
## @ace_param(field, options: amount|effect|seconds|delay|interval|repeat|chance|loops, default: amount, desc: "Which value on the card to write.")
## @ace_param(value, default: 1.0, desc: "What to write. A number for an amount or a length, a word for the extra one.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_feedback_field({label}, "{field}", {value})")
func set_feedback_field(label: String, field: String, value: Variant) -> void:
	var card: Dictionary = _edited(label, "Set Feedback Field")
	if card.is_empty():
		return
	if not FIELD_KEYS.has(field):
		push_warning("Feedback Player: a card has no field called \"%s\", so Set Feedback Field did nothing." % field)
		return
	card[field] = value

## @ace_action
## @ace_name("Set Feedback Timing")
## @ace_category("Feedback Player")
## @ace_description("Moves one card in time: how long it waits first, how many times it repeats and how far apart, and which clock it counts on. The card's Timing foldout, as a row.")
## @ace_display_template("Set feedback [b]{label}[/b] timing: delay [b]{delay}[/b] s, [b]{repeat}[/b] times")
## @ace_param(label, default: "shake", desc: "The label of the card being retimed.")
## @ace_param(delay, default: 0.0, desc: "How long the card waits after the head reaches it, in seconds.")
## @ace_param(repeat, default: 1, desc: "How many times it is felt. 1 is once.")
## @ace_param(interval, default: 0.0, desc: "The gap between repeats, in seconds.")
## @ace_param(clock, options: game|real, default: game, desc: "Which clock it counts on: game time slows with a slowmo, real time never does.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_feedback_timing({label}, {delay}, {repeat}, {interval}, "{clock}")")
func set_feedback_timing(label: String, delay: float, repeat: int, interval: float, clock: String) -> void:
	var card: Dictionary = _edited(label, "Set Feedback Timing")
	if card.is_empty():
		return
	card["delay"] = maxf(delay, 0.0)
	card["repeat"] = maxi(repeat, 1)
	card["interval"] = maxf(interval, 0.0)
	card["clock"] = clock

## @ace_action
## @ace_name("Set Feedback Chance")
## @ace_category("Feedback Player")
## @ace_description("How often one card is felt at all, as a percentage. 100 is every time, 25 is a quarter of the hits - the cheapest variety there is.")
## @ace_display_template("Set feedback [b]{label}[/b] chance [b]{percent}[/b]%")
## @ace_param(label, default: "shake", desc: "The label of the card being rolled for.")
## @ace_param(percent, default: 100.0, desc: "The chance it is felt, 0 to 100.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_feedback_chance({label}, {percent})")
func set_feedback_chance(label: String, percent: float) -> void:
	var card: Dictionary = _edited(label, "Set Feedback Chance")
	if not card.is_empty():
		card["chance"] = clampf(percent, 0.0, 100.0)

## @ace_action
## @ace_name("Set Feedback Label")
## @ace_category("Feedback Player")
## @ace_description("Renames one card. Every other row addresses cards by this name, so renaming one is renaming what the rest of the sheet has to say.")
## @ace_display_template("Rename feedback [b]{label}[/b] to [b]{new_label}[/b]")
## @ace_param(label, default: "shake", desc: "The card's name now.")
## @ace_param(new_label, default: "big shake", desc: "What it is called from here on.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_feedback_label({label}, {new_label})")
func set_feedback_label(label: String, new_label: String) -> void:
	var card: Dictionary = _edited(label, "Set Feedback Label")
	if not card.is_empty():
		card["label"] = new_label

## @ace_action
## @ace_name("Duplicate Feedback")
## @ace_category("Feedback Player")
## @ace_description("Copies one card and puts the copy straight under it, under a name of its own. Two shakes a frame apart out of one tuned card.")
## @ace_display_template("Duplicate feedback [b]{label}[/b] as [b]{new_label}[/b]")
## @ace_param(label, default: "shake", desc: "The label of the card to copy.")
## @ace_param(new_label, default: "", desc: "What the copy is called. Empty names it after the original.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.duplicate_feedback({label}, {new_label})")
func duplicate_feedback(label: String, new_label: String) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Duplicate Feedback")
		return
	var copy: Dictionary = (list[at] as Dictionary).duplicate(true)
	copy["label"] = new_label if not new_label.strip_edges().is_empty() else _label_of(copy) + " copy"
	list.insert(at + 1, copy)

## @ace_action
## @ace_name("Clear Feedbacks")
## @ace_category("Feedback Player")
## @ace_description("Empties the list. What a player that is about to be handed a whole beat by Copy Feedbacks From or Load Moment File wants first.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.clear_feedbacks()")
func clear_feedbacks() -> void:
	steps.clear()
	moment_file = null

## @ace_action
## @ace_name("Copy Feedbacks From")
## @ace_category("Feedback Player")
## @ace_description("Takes another player's whole list and makes it this one's - a copy, so retuning either afterwards leaves the other alone. One tuned enemy hit, given to every enemy that spawns.")
## @ace_display_template("Copy feedbacks from [i]{other}[/i]")
## @ace_param(other, desc: "The Feedback Player to copy the list off.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.copy_feedbacks_from({other})")
func copy_feedbacks_from(other: Node) -> void:
	if other == null:
		return
	var carried: Variant = other.get("steps")
	if not (carried is Array):
		push_warning("Feedback Player: %s is not a Feedback Player, so Copy Feedbacks From did nothing." % other.name)
		return
	var list: Array = _own_list()
	list.clear()
	for entry: Variant in carried as Array:
		if entry is Dictionary:
			list.append((entry as Dictionary).duplicate(true))

## @ace_action
## @ace_name("Load Moment File")
## @ace_category("Feedback Player")
## @ace_description("Brings a moment file's beat INTO this player's list, as a copy - so it can be retuned by rows afterwards without ever writing to the file two other objects may be playing.")
## @ace_display_template("Load moment file [b]{path}[/b]")
## @ace_param(path, default: "res://eventsheet_addons/juice/impact.tres", desc: "The moment file to read, as its res:// path.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.load_moment_file({path})")
func load_moment_file(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Feedback Player: there is no moment file at \"%s\", so Load Moment File did nothing." % path)
		return
	var file: Resource = load(path)
	if file == null or not (file.get("steps") is Array):
		push_warning("Feedback Player: \"%s\" is not a moment file, so Load Moment File did nothing." % path)
		return
	moment_file = file
	_own_list()

## @ace_action
## @ace_name("Save Moment File")
## @ace_category("Feedback Player")
## @ace_description("Writes this list out as a moment file, so a beat tuned while the game ran can be shared, shipped or loaded back. Only the four keys a file holds are written; the timing a list adds is this node's own.")
## @ace_display_template("Save moment file to [b]{path}[/b]")
## @ace_param(path, default: "user://my_moment.tres", desc: "Where to write it. At run time that is a user:// path, which is the only place a game may write.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.save_moment_file({path})")
func save_moment_file(path: String) -> void:
	var kind: Script = load("res://eventsheet_addons/moment_resource/moment_resource.gd") as Script
	if kind == null:
		push_warning("Feedback Player: this project has no moment file script, so Save Moment File did nothing.")
		return
	var written: Array[Dictionary] = []
	for entry: Variant in _steps_now():
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		written.append({"verb": str(card.get("verb", "")), "amount": float(card.get("amount", 1.0)), "effect": str(card.get("effect", "")), "seconds": float(card.get("seconds", 0.0))})
	var file: Resource = kind.new()
	file.set("moment_name", name)
	file.set("steps", written)
	if ResourceSaver.save(file, path) != OK:
		push_warning("Feedback Player: \"%s\" could not be written, so Save Moment File saved nothing." % path)

## @ace_action
## @ace_name("Set Player Strength")
## @ace_category("Feedback Player")
## @ace_description("Turns this whole player up or down without retuning a single card - the object's own volume knob, on top of the strength the play row asks for.")
## @ace_display_template("Set player strength [b]{value}[/b]")
## @ace_param(value, default: 1.0, desc: "What every amount in the list is scaled by. 1 is the list as tuned.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_player_strength({value})")
func set_player_strength(value: float) -> void:
	strength = maxf(value, 0.0)

## @ace_action
## @ace_name("Set Player Cooldown")
## @ace_category("Feedback Player")
## @ace_description("The shortest gap between two plays, in seconds. A play asked for sooner is refused, which is how a rapid-fire hit stops stacking its own feedback.")
## @ace_display_template("Set player cooldown [b]{seconds}[/b] s")
## @ace_param(seconds, default: 0.1, desc: "The gap. 0 lets every play through.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_player_cooldown({seconds})")
func set_player_cooldown(seconds: float) -> void:
	cooldown = maxf(seconds, 0.0)

## @ace_action
## @ace_name("Set Can Play While Playing")
## @ace_category("Feedback Player")
## @ace_description("What a second play does while the first is still running: start again from the top, be ignored, or run alongside it.")
## @ace_display_template("While playing, [b]{answer}[/b]")
## @ace_param(answer, options: restart|ignore|overlap, default: restart, desc: "Restart, ignore, or overlap.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_can_play_while_playing("{answer}")")
func set_can_play_while_playing(answer: String) -> void:
	while_playing = answer

## @ace_action
## @ace_name("Mute Feedback Category")
## @ace_category("Feedback Player")
## @ace_description("Silences a whole family of cards at once - every screen effect, every camera move, every sound - and lets them back with the same row. THE accessibility option: one row per switch on the settings screen, and no card has to be found and unticked.")
## @ace_display_template("Mute feedback category [b]{category}[/b]: [b]{muted}[/b]")
## @ace_param(category, options: audio|transform|camera|screen|pause|loop|signal, default: screen, desc: "The family to silence.")
## @ace_param(muted, default: true, desc: "On silences it; off lets it be felt again.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.mute_feedback_category("{category}", {muted})")
func mute_feedback_category(category: String, muted: bool) -> void:
	var family: String = category.strip_edges().to_lower()
	if family.is_empty():
		return
	if muted:
		_muted[family] = true
	else:
		_muted.erase(family)

## @ace_action
## @ace_name("Mute Feedback Category On Channel")
## @ace_category("Feedback Player")
## @ace_description("The same switch, thrown for every Feedback Player in a group at once - which is what a settings screen wants, because the option is about the game rather than about one object.")
## @ace_display_template("Mute feedback category [b]{category}[/b] on channel [b]{channel}[/b]: [b]{muted}[/b]")
## @ace_param(channel, default: "feedback", desc: "The group every player the switch reaches is in.")
## @ace_param(category, options: audio|transform|camera|screen|pause|loop|signal, default: screen, desc: "The family to silence.")
## @ace_param(muted, default: true, desc: "On silences it; off lets it be felt again.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.mute_category_on_channel({channel}, "{category}", {muted})")
func mute_category_on_channel(channel: String, category: String, muted: bool) -> void:
	if channel.strip_edges().is_empty() or not is_inside_tree():
		return
	get_tree().call_group(channel, "mute_feedback_category", category, muted)

## @ace_action
## @ace_name("Scale Feedback Amounts")
## @ace_category("Feedback Player")
## @ace_description("Multiplies how much every card in a family does - the effect-strength slider on a settings screen, where half is still the same beat and not a shorter one. Leave the family empty to move the whole list.")
## @ace_display_template("Scale feedback amounts [b]{category}[/b] by [b]{factor}[/b]")
## @ace_param(category, options: |audio|transform|camera|screen|pause|loop|signal, desc: "The family to scale, or empty for every card.")
## @ace_param(factor, default: 0.5, desc: "What each amount is multiplied by. 0.5 is half as much.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.scale_feedback_amounts("{category}", {factor})")
func scale_feedback_amounts(category: String, factor: float) -> void:
	var family: String = category.strip_edges().to_lower()
	for entry: Variant in _own_list():
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		if family.is_empty() or _category_of(card) == family:
			card["amount"] = float(card.get("amount", 1.0)) * factor

## @ace_action
## @ace_name("Retime Feedbacks")
## @ace_category("Feedback Player")
## @ace_description("Stretches or squeezes the whole beat in time: every length, every wait and every gap multiplied by the same number. Half makes a snappier version of a beat nobody has to retune card by card.")
## @ace_display_template("Retime feedbacks by [b]{factor}[/b]")
## @ace_param(factor, default: 0.5, desc: "What every length is multiplied by. 0.5 is twice as fast.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.retime_feedbacks({factor})")
func retime_feedbacks(factor: float) -> void:
	var scale: float = maxf(factor, 0.0)
	for entry: Variant in _own_list():
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		for key: String in ["seconds", "delay", "interval"]:
			if card.has(key):
				card[key] = float(card[key]) * scale

## @ace_action
## @ace_name("Shuffle Feedbacks Between")
## @ace_category("Feedback Player")
## @ace_description("Reorders the stretch of the list between two cards, both included, at random. The cheapest variety a repeated hit can have: the same feedbacks, in a different order every time.")
## @ace_display_template("Shuffle feedbacks [b]{first_label}[/b] to [b]{last_label}[/b]")
## @ace_param(first_label, default: "shake_a", desc: "One end of the stretch.")
## @ace_param(last_label, default: "shake_c", desc: "The other end.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.shuffle_feedbacks_between({first_label}, {last_label})")
func shuffle_feedbacks_between(first_label: String, last_label: String) -> void:
	var list: Array = _own_list()
	var from: int = _index_in(list, first_label)
	var to: int = _index_in(list, last_label)
	if from < 0 or to < 0:
		_no_such(first_label if from < 0 else last_label, "Shuffle Feedbacks Between")
		return
	if to < from:
		var swapped: int = from
		from = to
		to = swapped
	var stretch: Array = list.slice(from, to + 1)
	stretch.shuffle()
	for offset: int in range(stretch.size()):
		list[from + offset] = stretch[offset]

## @ace_action
## @ace_name("Pick One Feedback Of")
## @ace_category("Feedback Player")
## @ace_description("Ticks exactly one of the cards whose label starts with what you type and unticks the rest, so shake_a, shake_b and shake_c become one shake chosen fresh each time. Variety out of the list itself, with no branch in the sheet.")
## @ace_display_template("Pick one feedback of [b]{prefix}[/b]")
## @ace_param(prefix, default: "shake_", desc: "The start of the labels to choose between.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.pick_one_feedback_of({prefix})")
func pick_one_feedback_of(prefix: String) -> void:
	var wanted: String = prefix.strip_edges()
	if wanted.is_empty():
		return
	var matches: Array = []
	for entry: Variant in _own_list():
		if entry is Dictionary and _label_of(entry as Dictionary).begins_with(wanted):
			matches.append(entry)
	if matches.is_empty():
		_no_such(wanted, "Pick One Feedback Of")
		return
	var chosen: int = randi() % matches.size()
	for index: int in range(matches.size()):
		(matches[index] as Dictionary)["active"] = index == chosen

## @ace_action
## @ace_name("Jump To Feedback")
## @ace_category("Feedback Player")
## @ace_description("Moves the head of a RUNNING play to the card you name, so the rest of the beat starts there. What a hit that interrupts its own wind-up wants.")
## @ace_display_template("Jump to feedback [b]{label}[/b]")
## @ace_param(label, default: "impact", desc: "The label of the card to carry on from.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.jump_to_feedback({label})")
func jump_to_feedback(label: String) -> void:
	_jump_to = label.strip_edges()

## @ace_action
## @ace_name("Skip Feedback Once")
## @ace_category("Feedback Player")
## @ace_description("Steps over one card the NEXT time the play reaches it, and then forgets about it. The one-off exception a disable would have to be undone after.")
## @ace_display_template("Skip feedback [b]{label}[/b] once")
## @ace_param(label, default: "shake", desc: "The label of the card to step over once.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.skip_feedback_once({label})")
func skip_feedback_once(label: String) -> void:
	if _index_of(label) < 0:
		_no_such(label, "Skip Feedback Once")
		return
	_skip_once[label.strip_edges()] = true

## @ace_action
## @ace_name("Set Loop Count")
## @ace_category("Feedback Player")
## @ace_description("How many times a Loop Back card sends the head round. A charge that gets longer the further it is held, without a second list.")
## @ace_display_template("Set loop count [b]{label}[/b] to [b]{loops}[/b]")
## @ace_param(label, default: "loop_back", desc: "The label of the Loop Back card.")
## @ace_param(loops, default: 2, desc: "How many times round. 0 walks straight past it.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.set_loop_count({label}, {loops})")
func set_loop_count(label: String, loops: int) -> void:
	var card: Dictionary = _edited(label, "Set Loop Count")
	if card.is_empty():
		return
	card["loops"] = maxi(loops, 0)
	card["loops_left"] = maxi(loops, 0)

## @ace_action
## @ace_name("Hold Here")
## @ace_category("Feedback Player")
## @ace_description("Stops the head where it is and leaves it there - a charge held, a beat waiting on the player. Release Hold carries on from the same card, and nothing ticks while it waits.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.hold_here()")
func hold_here() -> void:
	_held = playing

## @ace_action
## @ace_name("Release Hold")
## @ace_category("Feedback Player")
## @ace_description("Lets a held play carry on from the card it stopped on.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.release_hold()")
func release_hold() -> void:
	_held = false
	_resumed.emit()

## @ace_condition
## @ace_name("Feedback Is Playing")
## @ace_category("Feedback Player")
## @ace_description("True while the head is on that card - the moment the hit is being felt rather than the whole beat around it.")
## @ace_display_template("Feedback [b]{label}[/b] is playing")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedback_is_playing({label})")
func feedback_is_playing(label: String) -> bool:
	return playing and now_playing == label.strip_edges()

## @ace_condition
## @ace_name("Has Feedback")
## @ace_category("Feedback Player")
## @ace_description("True when this player's list holds a card by that name. The question a row asks before it retunes one, and the one a Doctor finding is about.")
## @ace_display_template("Has feedback [b]{label}[/b]")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.has_feedback({label})")
func has_feedback(label: String) -> bool:
	return _index_of(label) >= 0

## @ace_condition
## @ace_name("Feedback Is Enabled")
## @ace_category("Feedback Player")
## @ace_description("True when that card's box is ticked - so a settings screen can show the switch the way the list actually has it.")
## @ace_display_template("Feedback [b]{label}[/b] is enabled")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedback_is_enabled({label})")
func feedback_is_enabled(label: String) -> bool:
	var at: int = _index_of(label)
	return at >= 0 and bool((_steps_now()[at] as Dictionary).get("active", true))

## @ace_expression
## @ace_name("Feedback Count")
## @ace_category("Feedback Player")
## @ace_description("How many cards this player's list holds, ticked or not - the number the head of the Inspector shows.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedback_count()")
func feedback_count() -> int:
	return _steps_now().size()

## @ace_expression
## @ace_name("Feedback Label At")
## @ace_category("Feedback Player")
## @ace_description("The name of the card at a place in the list, so a settings screen can list a beat without knowing what is in it. The first card is 1; a number past the end answers with nothing.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedback_label_at({position})")
func feedback_label_at(position: int) -> String:
	var list: Array = _steps_now()
	var at: int = position - 1
	if at < 0 or at >= list.size() or not (list[at] is Dictionary):
		return ""
	return _label_of(list[at] as Dictionary)

## @ace_expression
## @ace_name("Feedback Field")
## @ace_category("Feedback Player")
## @ace_description("What one card says at one of its fields - the amount it does, how long it lasts, the extra word it carries. The read half of Set Feedback Field, so a slider can be shown at the value the list actually holds.")
## @ace_param_options(field amount, effect, seconds, delay, interval, repeat, chance, loops)
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedback_field({label}, "{field}")")
func feedback_field(label: String, field: String) -> Variant:
	return _card_named(label).get(field, null)

## @ace_expression
## @ace_name("Feedback Progress")
## @ace_category("Feedback Player")
## @ace_description("How far through one card the play is, 0 before it starts and 1 once it is done. Read off the plan rather than off a tick, so asking it costs nothing.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedback_progress({label})")
func feedback_progress(label: String) -> float:
	return _progress_of(label)

## @ace_expression
## @ace_name("Feedback Duration")
## @ace_category("Feedback Player")
## @ace_description("How long ONE card lasts, its own wait included - beside Feedbacks Duration, which is how long the whole beat lasts.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.feedback_duration({label})")
func feedback_duration(label: String) -> float:
	var card: Dictionary = _card_named(label)
	return maxf(float(card.get("seconds", 0.0)), 0.0) + maxf(float(card.get("delay", 0.0)), 0.0)

## @ace_expression
## @ace_name("Current Feedback")
## @ace_category("Feedback Player")
## @ace_description("The label of the card the head is on right now, or nothing when no play is running.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.current_feedback()")
func current_feedback() -> String:
	return now_playing

## @ace_expression
## @ace_name("Loops Left")
## @ace_category("Feedback Player")
## @ace_description("How many times round a Loop Back card still has to go in the play that is running.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$FeedbackPlayer.loops_left({label})")
func loops_left(label: String) -> int:
	var card: Dictionary = _card_named(label)
	return int(card.get("loops_left", card.get("loops", 0)))

## The steps this play walks: the moment file's when one is dropped on the slot, else the list.
func _steps_now() -> Array:
	if moment_file != null:
		var carried: Variant = moment_file.get("steps")
		if carried is Array:
			return carried as Array
	return steps

## Whether a walk is still the one it started as. A step that comes back after its token has left the
## live list stops there, which is the whole of stopping.
func _alive(token: int) -> bool:
	return _live.has(token)

## Whether a new play may start now - the cooldown and the "can play while playing" answer in one
## place, so every door into the runner refuses for the same reasons.
func _may_start() -> bool:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if cooldown > 0.0 and now - _last_played_at < cooldown:
		return false
	if playing and while_playing == IGNORE:
		return false
	if playing and while_playing == RESTART:
		_live.clear()
	_last_played_at = now
	return true

## The longest path through a list of steps: a stretch between two holds runs at once, so it is as
## long as its slowest card, and the holds and pauses add up. The Inspector head, the card badge and
## the expression all read this one function, so no two of them can disagree.
## @ace_hidden
static func duration_of(list: Array) -> float:
	var total: float = 0.0
	var stretch: float = 0.0
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		if not bool(card.get("active", true)):
			continue
		var word: String = str(card.get("verb", ""))
		var seconds: float = maxf(float(card.get("seconds", 0.0)), 0.0) + maxf(float(card.get("delay", 0.0)), 0.0)
		if word == HOLD_UNTIL:
			total += stretch + seconds
			stretch = 0.0
		elif word == PAUSE:
			total += seconds
		elif word != LOOP_START and word != LOOP_BACK:
			stretch = maxf(stretch, seconds)
	return total + stretch

## Whether a word moves the head rather than being felt.
static func _is_timing(word: String) -> bool:
	return word == PAUSE or word == HOLD_UNTIL or word == LOOP_START or word == LOOP_BACK

## The one walk down a list. Every door into the runner comes through here, so the direction, the
## chance, the timing words and the loops are decided once.
func _walk(list: Array, at_strength: float, backwards: bool) -> void:
	var order: Array = []
	for entry: Variant in list:
		if entry is Dictionary:
			order.append(entry)
	if backwards:
		order.reverse()
	var token: int = _begin(order, at_strength)
	var index: int = 0
	for taken: int in range(MAX_PLAY_STEPS):
		if index >= order.size() or not _alive(token):
			break
		await _wait_out_pause(token)
		if not _alive(token):
			break
		_head = index
		progress = float(index) / float(maxi(order.size(), 1))
		index = await _take(order, index, order[index] as Dictionary, at_strength, token)
		index = _landing(order, index)
	if _alive(token) and index < order.size():
		push_warning("Feedback Player: a loop on %s never came back, so the play was given up after %d steps." % [name, MAX_PLAY_STEPS])
	if _alive(token):
		_live.erase(token)
		_close()

## Holds a walk while the player is paused OR held where it is. It waits on the resume signal
## rather than polling, so a pause costs nothing while it lasts, ends the frame it is lifted, and
## wakes for a stop as well - every door that ends a wait raises the same signal. The loop is
## bounded rather than open because two doors can hold the head at once, and a resume that lifts
## only one of them must go back to waiting rather than walking on.
func _wait_out_pause(token: int) -> void:
	for waited: int in range(MAX_PLAY_STEPS):
		if not ((_paused or _held) and _alive(token)):
			return
		await _resumed

## What one card does, and where the head goes next. The timing words move the head; every other
## word is a feedback, which is felt and stepped over.
func _take(order: Array, index: int, card: Dictionary, at_strength: float, token: int) -> int:
	var word: String = str(card.get("verb", "")).strip_edges().to_lower()
	var refused: String = _why_not(card, at_strength)
	if not refused.is_empty():
		if not _is_timing(word):
			on_feedback_skipped.emit(_label_of(card), refused)
		return index + 1
	var clock: String = MomentRunner.CLOCK_REAL if str(card.get("clock", "")) == "real" else MomentRunner.CLOCK_GAME
	var delay: float = maxf(float(card.get("delay", 0.0)), 0.0)
	if delay > 0.0:
		await MomentRunner.at(self, delay, clock)
		if not _alive(token):
			return order.size()
	match word:
		PAUSE:
			await MomentRunner.then(self, MomentRunner.seconds_of(float(card.get("seconds", 0.0))), clock)
		HOLD_UNTIL:
			on_hold_reached.emit()
			await MomentRunner.hold(self, _longest_above(order, index), float(card.get("seconds", 0.0)), clock)
		LOOP_START:
			pass
		LOOP_BACK:
			var back: int = _loop_target(order, index, card)
			var left: int = int(card.get("loops_left", card.get("loops", 1)))
			if left > 0 and back >= 0:
				card["loops_left"] = left - 1
				on_loop.emit(left - 1)
				await MomentRunner.then(self, MomentRunner.seconds_of(float(card.get("seconds", 0.0))), clock)
				return back
			card["loops_left"] = int(card.get("loops", 1))
		_:
			now_playing = str(card.get("label", word))
			on_feedback_started.emit(_label_of(card))
			_do_step(card, at_strength)
			await _repeat_rest(card, at_strength, clock, token)
			on_feedback_finished.emit(_label_of(card))
	return index + 1

## The repeats a card asks for after its first play, each one an interval apart.
func _repeat_rest(card: Dictionary, at_strength: float, clock: String, token: int) -> void:
	var repeat: int = maxi(int(card.get("repeat", 1)), 1)
	var interval: float = maxf(float(card.get("interval", 0.0)), 0.0)
	for pass_index: int in range(1, repeat):
		if not _alive(token):
			return
		await MomentRunner.then(self, MomentRunner.seconds_of(interval), clock)
		if not _alive(token):
			return
		_do_step(card, at_strength)

## Whether a card is felt at all: its enable box, its chance, and the strength window it asked for.
func _card_runs(card: Dictionary, at_strength: float) -> bool:
	return _why_not(card, at_strength).is_empty()

## WHY a card was not felt, in one word, or "" when it was. The reason is what On Feedback Skipped
## carries, so a row can tell a card the player muted from one the dice went against - and it is
## asked once per card per play, because rolling the chance twice would be a different beat.
func _why_not(card: Dictionary, at_strength: float) -> String:
	if not bool(card.get("active", true)):
		return "off"
	var named: String = _label_of(card)
	if _skip_once.has(named):
		_skip_once.erase(named)
		return "skipped once"
	if _muted.has(_category_of(card)):
		return "muted"
	var chance: float = float(card.get("chance", 100.0))
	if chance < 100.0 and randf() * 100.0 >= chance:
		return "chance"
	if at_strength < float(card.get("min_strength", 0.0)):
		return "strength"
	var ceiling: float = float(card.get("max_strength", 0.0))
	if ceiling > 0.0 and at_strength > ceiling:
		return "strength"
	return ""

## One feedback, felt. The ten moment words go to the Juice behaviour beside this node - the same
## call a moment file makes - and this node's own words are done here.
func _do_step(card: Dictionary, at_strength: float) -> void:
	var word: String = str(card.get("verb", "")).strip_edges().to_lower()
	var amount: float = float(card.get("amount", 1.0))
	var effect: String = str(card.get("effect", ""))
	var seconds: float = maxf(float(card.get("seconds", 0.0)), 0.0)
	match word:
		TWEEN_PROPERTY:
			_tween_property(effect, MomentRunner.scaled(amount, at_strength), MomentRunner.seconds_of(seconds))
		EMIT_SIGNAL:
			on_feedback_signal.emit(effect)
		PLAY_PLAYER:
			var other: Node = get_node_or_null(NodePath(effect))
			if other != null and other.has_method("play"):
				other.call("play", at_strength * maxf(amount, 0.0))
		_:
			var juice: Node = _juice()
			if juice != null:
				juice.call("moment_step", word, amount, effect, seconds, at_strength * maxf(strength, 0.0))

## A property on the host walked to a value, with what it was written down first so Restore can put
## it back. The walk is the engine's own tween, so nothing ticks while nothing is playing.
func _tween_property(property: String, value: float, seconds: float) -> void:
	if host == null or property.strip_edges().is_empty():
		return
	var before: Variant = host.get(property)
	if before == null:
		push_warning("Feedback Player: %s has no property called \"%s\", so that step did nothing." % [host.name, property])
		return
	_restore_to.append({"object": host, "property": property, "value": before})
	if seconds <= 0.0:
		host.set(property, value)
		return
	create_tween().tween_property(host, NodePath(property), value, seconds)

## How much of the slowest step above is still to run when a Hold is reached - the number the hold
## word waits for. Read back over the cards between this hold and the one above it.
func _longest_above(order: Array, index: int) -> float:
	var longest: float = 0.0
	var walk: int = index - 1
	while walk >= 0:
		var card: Dictionary = order[walk] as Dictionary
		var word: String = str(card.get("verb", ""))
		if word == HOLD_UNTIL:
			break
		if bool(card.get("active", true)):
			longest = maxf(longest, maxf(float(card.get("seconds", 0.0)), 0.0))
		walk -= 1
	return longest

## Where a Loop Back sends the head: the nearest Hold or Loop Start above it that the card is willing
## to land on. -1 when there is none, which makes the loop a step that does nothing.
func _loop_target(order: Array, index: int, card: Dictionary) -> int:
	var to_hold: bool = bool(card.get("to_hold", true))
	var to_start: bool = bool(card.get("to_loop_start", true))
	var walk: int = index - 1
	while walk >= 0:
		var word: String = str((order[walk] as Dictionary).get("verb", ""))
		if to_hold and word == HOLD_UNTIL:
			return walk + 1
		if to_start and word == LOOP_START:
			return walk + 1
		walk -= 1
	return -1

## The bookkeeping every play opens with: a token of its own, the live values seeded, the head at the
## top and the started signal out.
func _begin(order: Array, at_strength: float) -> int:
	_next_token += 1
	_live.append(_next_token)
	playing = true
	_played_once = true
	_paused = false
	_held = false
	_jump_to = ""
	progress = 0.0
	_started_at = float(Time.get_ticks_msec()) / 1000.0
	_order = order
	_head = 0
	_head_strength = at_strength
	for entry: Variant in order:
		if entry is Dictionary:
			(entry as Dictionary)["loops_left"] = int((entry as Dictionary).get("loops", 1))
	on_feedbacks_started.emit(at_strength)
	return _next_token

## And the bookkeeping the last walk out closes with.
func _close() -> void:
	if not _live.is_empty():
		return
	playing = false
	_paused = false
	_held = false
	progress = 1.0
	now_playing = ""
	on_feedbacks_finished.emit()

## When each card of a list starts and how long it lasts: [{card, at, seconds}], in list order. A
## stretch between two holds starts together, a Pause pushes everything under it along, and the
## loops are left out because a plan is what one pass looks like. The Inspector's timeline and the
## editor preview both read this, so the picture and the sample can never disagree.
## @ace_hidden
static func schedule_of(list: Array) -> Array:
	var plan: Array = []
	var at: float = 0.0
	var stretch: float = 0.0
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		if not bool(card.get("active", true)):
			continue
		var word: String = str(card.get("verb", ""))
		var delay: float = maxf(float(card.get("delay", 0.0)), 0.0)
		var seconds: float = maxf(float(card.get("seconds", 0.0)), 0.0)
		if word == HOLD_UNTIL:
			at += stretch + delay + seconds
			stretch = 0.0
			continue
		if word == PAUSE:
			at += delay + seconds
			continue
		if word == LOOP_START or word == LOOP_BACK:
			continue
		plan.append({"card": card, "at": at + delay, "seconds": seconds})
		stretch = maxf(stretch, delay + seconds)
	return plan

## What the object would be doing `time` into a play - the editor's look at the list, sampled rather
## than run. The shape is the plugin's shared behaviour-preview contract (exported values in, the
## host's rest state in, the properties to write out), so the Tools-menu preview and the Inspector's
## own Play button read one function and show one picture.
##
## Only the three words an editor can honestly show are sampled: a shake as a wobble, a punch as a
## swell, and a tweened property walking to its value. A hitstop and a flash are things a running
## game does to time and to the screen, and drawing a guess at them would be worse than the gap.
## @ace_hidden
static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:
	var list: Variant = params.get("steps", [])
	if not (list is Array):
		return {}
	var at_strength: float = maxf(float(params.get("strength", 1.0)), 0.0)
	var written: Dictionary = {}
	var offset: Vector2 = Vector2.ZERO
	var swell: float = 0.0
	for entry: Variant in schedule_of(list as Array):
		var plan: Dictionary = entry as Dictionary
		var card: Dictionary = plan.get("card") as Dictionary
		var span: float = maxf(float(plan.get("seconds", 0.0)), 0.05)
		var through: float = (time - float(plan.get("at", 0.0))) / span
		if through < 0.0 or through > 1.0:
			continue
		var amount: float = float(card.get("amount", 1.0)) * at_strength
		var word: String = str(card.get("verb", ""))
		if word == "shake":
			offset += Vector2(sin(time * 47.0), cos(time * 53.0)) * amount * 8.0 * (1.0 - through)
		elif word == "punch":
			swell += amount * 0.2 * sin(through * PI)
		elif word == TWEEN_PROPERTY:
			var property: String = str(card.get("effect", ""))
			if base.has(property) and (base[property] is float or base[property] is int):
				written[property] = lerpf(float(base[property]), amount, through)
	if base.get("position") is Vector2 and offset != Vector2.ZERO:
		written["position"] = (base["position"] as Vector2) + offset
	if base.get("scale") is Vector2 and not is_zero_approx(swell):
		written["scale"] = (base["scale"] as Vector2) * (1.0 + swell)
	return written

## The name one card answers to: what it was called in the list, or its own word when it was never
## named. THE ONE PLACE a label is derived, so every row addresses cards identically.
func _label_of(card: Dictionary) -> String:
	var named: String = str(card.get("label", "")).strip_edges()
	return named if not named.is_empty() else str(card.get("verb", "")).strip_edges()

## Which family a card belongs to: its own word for it when it carries one, else the family its
## word belongs to, else none at all.
func _category_of(card: Dictionary) -> String:
	var said: String = str(card.get("category", "")).strip_edges().to_lower()
	if not said.is_empty():
		return said
	return str(CATEGORY_OF.get(str(card.get("verb", "")).strip_edges().to_lower(), ""))

## Where a label sits in a list, or -1 when nothing in it answers to that name.
func _index_in(list: Array, label: String) -> int:
	var wanted: String = label.strip_edges()
	if wanted.is_empty():
		return -1
	for index: int in range(list.size()):
		if list[index] is Dictionary and _label_of(list[index] as Dictionary) == wanted:
			return index
	return -1

## Where a label sits in the list this player is playing.
func _index_of(label: String) -> int:
	return _index_in(_steps_now(), label)

## The card a label names, or an empty one. Empty rather than null so every reader can ask it a
## question without checking first, and a card that is not there answers with the defaults.
func _card_named(label: String) -> Dictionary:
	var list: Array = _steps_now()
	var at: int = _index_in(list, label)
	return list[at] as Dictionary if at >= 0 else {}

## Said when a row names a feedback this player has not got. A warning rather than an error,
## because the rest of the beat is still worth playing; in the editor the same mistake is a quiet
## finding on the row itself, which is where it can actually be fixed.
func _no_such(label: String, row: String) -> void:
	push_warning("Feedback Player: %s has no feedback labelled \"%s\", so %s did nothing." % [name, label, row])

## The list the EDIT rows work on: this player's own. A player whose moment-file slot is filled is
## playing a beat two other objects may be playing too, and an edit row must never write into that
## file - so the first edit takes a copy of it into this list and lets the slot go. The beat is
## unchanged; it is simply this object's own now.
func _own_list() -> Array:
	if moment_file != null:
		var carried: Variant = moment_file.get("steps")
		steps.clear()
		if carried is Array:
			for entry: Variant in carried as Array:
				if entry is Dictionary:
					steps.append((entry as Dictionary).duplicate(true))
		moment_file = null
	return steps

## The card a row is about to write to, taken from this player's OWN list, or an empty dictionary
## when the label names nothing - with the warning already said, so no row has to say it twice.
func _edited(label: String, row: String) -> Dictionary:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, row)
		return {}
	return list[at] as Dictionary

## One dictionary made into a card: its own keys over the four every moment file's step holds, so
## a step written by a row and one added in the Inspector are the same shape and neither has to be
## converted into the other. The enable key is left ABSENT, which is what on means.
func _carded(step: Dictionary) -> Dictionary:
	var card: Dictionary = {"verb": "", "amount": 1.0, "effect": "", "seconds": 0.0}
	for key: Variant in step:
		card[key] = step[key]
	return card

## Where the head goes when Jump To Feedback has been asked for: the label's place in the order
## being walked, or where the head was going anyway. Asked once per step, and it reads an empty
## string in every play nobody jumped in.
func _landing(order: Array, index: int) -> int:
	if _jump_to.is_empty():
		return index
	var landed: int = _index_in(order, _jump_to)
	if landed < 0:
		_no_such(_jump_to, "Jump To Feedback")
	_jump_to = ""
	return landed if landed >= 0 else index

## How far through ONE card the play is, 0 before it starts and 1 once it is done. Read off the
## plan rather than off a tick: the schedule says when each card starts and how long it lasts and
## the clock says how long this play has been going, so nothing has to run to answer it.
func _progress_of(label: String) -> float:
	if not playing:
		return 0.0
	var elapsed: float = float(Time.get_ticks_msec()) / 1000.0 - _started_at
	for entry: Variant in schedule_of(_steps_now()):
		var plan: Dictionary = entry as Dictionary
		if _label_of(plan.get("card") as Dictionary) != label.strip_edges():
			continue
		var span: float = maxf(float(plan.get("seconds", 0.0)), 0.0)
		if span <= 0.0:
			return 1.0 if elapsed >= float(plan.get("at", 0.0)) else 0.0
		return clampf((elapsed - float(plan.get("at", 0.0))) / span, 0.0, 1.0)
	return 0.0

# Feedback Player: add this node under an object, fill its list in the Inspector, and one row plays the whole beat. Cards are dragged into order, ticked off, and tuned in place; Pause and Hold space them out and Loop Back repeats a stretch. The ten shake-and-flash words are played by the Juice behaviour beside this node, so put one there too. The list is the same shape a moment file holds - drop a file on the slot to play it instead, or save the list out as one. This pack is an event sheet - extend it by editing it.
