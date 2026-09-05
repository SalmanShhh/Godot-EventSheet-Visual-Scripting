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
## @ace_param(channel, default: feedback, desc: "The group every player that should feel this is in.")
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
	if _alive(token) and index < order.size():
		push_warning("Feedback Player: a loop on %s never came back, so the play was given up after %d steps." % [name, MAX_PLAY_STEPS])
	if _alive(token):
		_live.erase(token)
		_close()

## Holds a walk while the player is paused. It waits on the resume signal rather than polling, so a
## pause costs nothing while it lasts, ends the frame it is lifted, and wakes for a stop as well -
## every door that ends a pause raises the same signal.
func _wait_out_pause(token: int) -> void:
	if _paused and _alive(token):
		await _resumed

## What one card does, and where the head goes next. The timing words move the head; every other
## word is a feedback, which is felt and stepped over.
func _take(order: Array, index: int, card: Dictionary, at_strength: float, token: int) -> int:
	var word: String = str(card.get("verb", "")).strip_edges().to_lower()
	if not _card_runs(card, at_strength):
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
			await MomentRunner.hold(self, _longest_above(order, index), float(card.get("seconds", 0.0)), clock)
		LOOP_START:
			pass
		LOOP_BACK:
			var back: int = _loop_target(order, index, card)
			var left: int = int(card.get("loops_left", card.get("loops", 1)))
			if left > 0 and back >= 0:
				card["loops_left"] = left - 1
				await MomentRunner.then(self, MomentRunner.seconds_of(float(card.get("seconds", 0.0))), clock)
				return back
			card["loops_left"] = int(card.get("loops", 1))
		_:
			now_playing = str(card.get("label", word))
			_do_step(card, at_strength)
			await _repeat_rest(card, at_strength, clock, token)
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
	if not bool(card.get("active", true)):
		return false
	var chance: float = float(card.get("chance", 100.0))
	if chance < 100.0 and randf() * 100.0 >= chance:
		return false
	if at_strength < float(card.get("min_strength", 0.0)):
		return false
	var ceiling: float = float(card.get("max_strength", 0.0))
	return ceiling <= 0.0 or at_strength <= ceiling

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
	progress = 0.0
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

# Feedback Player: add this node under an object, fill its list in the Inspector, and one row plays the whole beat. Cards are dragged into order, ticked off, and tuned in place; Pause and Hold space them out and Loop Back repeats a stretch. The ten shake-and-flash words are played by the Juice behaviour beside this node, so put one there too. The list is the same shape a moment file holds - drop a file on the slot to play it instead, or save the list out as one. This pack is an event sheet - extend it by editing it.
