# @ace_tags(juice, juice player, feedback, game feel)
# @ace_category("Juice Player")
# @ace_provider_id(FeedbackPlayer)
# @ace_version(1.0.0)
@icon("res://eventsheet_addons/juice/icon.svg")
class_name JuicePlayer
extends Node
## The list of juice cards an object plays: add this node under it, fill the list with shakes, flashes, holds and loops, and one row plays the lot. A Juice node does one effect when a row asks; a Juice Player plays a list of juice cards, one after another. The list is the same shape a moment file holds, so it can be saved out and shared; the strength on the row scales every amount in it.

# @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node
	if host == null:
		push_warning("Juice Player needs a parent node: put it under one, or set Acts on. This one is at " + str(get_path()) + ".")

# @ace_trigger
# @ace_name("On Juice Started")
# @ace_category("Juice Player")
signal on_feedbacks_started(at_strength: float)
# @ace_trigger
# @ace_name("On Juice Finished")
# @ace_category("Juice Player")
signal on_feedbacks_finished
# @ace_trigger
# @ace_name("On Juice Signal")
# @ace_category("Juice Player")
signal on_feedback_signal(word: String)
# @ace_trigger
# @ace_name("On Juice Card Started")
# @ace_category("Juice Player")
signal on_feedback_started(label: String)
# @ace_trigger
# @ace_name("On Juice Card Finished")
# @ace_category("Juice Player")
signal on_feedback_finished(label: String)
# @ace_trigger
# @ace_name("On Juice Card Skipped")
# @ace_category("Juice Player")
signal on_feedback_skipped(label: String, why: String)
# @ace_trigger
# @ace_name("On Hold Reached")
# @ace_category("Juice Player")
signal on_hold_reached
# @ace_trigger
# @ace_name("On Loop")
# @ace_category("Juice Player")
signal on_loop(loops_left: int)

# @inspector_header Juice Player #8a6fd4
# @inspector_info One juice card per effect. Pause and Hold space them out, Loop Start and Loop Back repeat a stretch, and everything else is felt. Play plays the list; the strength on the row scales every amount in it. A Juice node does one effect when a row asks; a Juice Player plays a list of them.
## The juice cards this object plays, in order. Each one is a card: what it does, how much, how long, and the timing words between them.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:cards:kind=verb,schema=feedback_steps,stripes=category") var steps: Array[Dictionary] = []
## Scales every amount in the list before the row's own strength applies.
@export var strength: float = 1.0
# @inspector_look toggle_row
## Which end of the list a play starts from.
@export_enum("top to bottom", "bottom to top") var direction: String = "top to bottom"
# @inspector_look toggle_row
## What a second play does while the first is still running: restart it, ignore the new one, or let the two overlap.
@export_enum("restart", "ignore", "overlap") var while_playing: String = "restart"
## Plays the list once, at full strength, when this node enters the scene: a spawn pop, a pickup shimmer.
@export var autoplay: bool = false
## Plays the whole list again and again until Stop Juice or Set Looping ends it. A pass waits at least a frame, so a list with no time in it cannot lock the game.
@export var loop: bool = false
## How many passes a loop makes before it stops by itself. 0 is until stopped.
@export_range(0, 100, 1, "or_greater") var loop_times: int = 0
## Seconds between one pass and the next. 0 waits one frame.
@export_range(0, 10, 0.01, "or_greater", "suffix:s") var loop_wait: float = 0.0
## Seconds that must pass between plays; sooner requests are refused.
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

## Most steps one play may run, loops included, before it gives up.
const MAX_PLAY_STEPS: int = 4096

## Direction word: walk the list from the first card to the last.
const TOP_TO_BOTTOM: String = "top to bottom"
## Direction word: walk the list from the last card to the first.
const BOTTOM_TO_TOP: String = "bottom to top"
## Answer to a play while already playing: stop and start again from the top.
const RESTART: String = "restart"
## Answer to a play while already playing: do nothing and let it carry on.
const IGNORE: String = "ignore"
## Answer to a play while already playing: start a second play alongside the first.
const OVERLAP: String = "overlap"

# The words below are this node's own. Every other word is played by the Juice behaviour
# beside it - the same call a moment file makes - so a card list and a moment file are the same
# ten words plus timing.
## Step word: stop the play here until Resume is called.
const PAUSE: String = "pause"
## Step word: wait here until the named signal arrives.
const HOLD_UNTIL: String = "hold_until"
## Step word: marks the card a Loop Back returns to.
const LOOP_START: String = "loop_start"
## Step word: go back to the Loop Start card, a set number of times.
const LOOP_BACK: String = "loop_back"
## Step word: tween a property of a node to a value.
const TWEEN_PROPERTY: String = "tween_property"
## Step word: emit a signal on a node.
const EMIT_SIGNAL: String = "emit_signal"
## Step word: start another Juice Player and let it run.
const PLAY_PLAYER: String = "play_player"
## The word a card of your own is played under, so a class named Pause is not taken for the built-in word.
const YOURS: String = "yours"
## Step word: play a sound.
const SOUND: String = "sound"
## Step word: stop a sound an earlier Sound card started, by that card's name, with an optional fade.
const STOP_SOUND: String = "stop_sound"
## Step word: move a bus's volume to a value over a time. Restore Initial Values puts it back.
const FADE_BUS: String = "fade_bus"
## Step word: rumble a controller, or buzz a phone, for a time.
const VIBRATE: String = "vibrate"
## The volume a fade-out ends on, below which nothing is heard.
const SILENT_DB: float = -80.0
## Heard-from word: the sound comes from the object this player is under, so it sits in space.
const HEARD_HERE: String = "here"
## Heard-from word: the sound plays flat, the same wherever the listener is.
const HEARD_EVERYWHERE: String = "everywhere"
## Most sounds one player has going at once. A new one takes the oldest voice when all are busy.
const SOUND_VOICES: int = 4
## The lowest pitch a roll may land on, because a pitch scale has to stay above zero.
const LOWEST_PITCH: float = 0.05

# @ace_hidden
## Raised whenever a pause ends, however it ended. Private, so it is plumbing rather than vocabulary.
signal _resumed

## Live while the game runs - written by the play, read in the remote Inspector of the running node.
var playing: bool = false
## How far through the cards the play has got, from 0 to 1.
var progress: float = 0.0
## Label of the card being played now, or empty when nothing is playing.
var now_playing: String = ""

## Tokens of the plays still running, so a stale play can tell it was stopped.
var _live: Array[int] = []
## The token handed to the next play that starts.
var _next_token: int = 0
## True while the play is paused on a Pause card.
var _paused: bool = false
## True once the list has played at least once, which Skip Next Time reads.
var _played_once: bool = false
## When the list last played, in seconds, used to enforce its cooldown.
var _last_played_at: float = -1000.0
## The cards in the order this play walks them.
var _order: Array = []
## Index in the order of the card being played.
var _head: int = 0
## Strength the current play was started at, which scales every card in it.
var _head_strength: float = 1.0

# A Skip To End does the
# cards the walk has not reached, and the head is the one card that could be in both: without
# this it would be decided twice, which would consume a Skip Next Time twice over and feel a
# card the walk is still in the middle of a second time.
## Whether the card the head is on has already been answered by the walk.
var _head_taken: bool = false
## Cards started beside the walk, counted for each play by its token, so a play stays open until they are felt.
var _pending: Dictionary = {}
## The cards waiting out their own delay, by ticket, which a Skip To End feels at once.
var _waiting: Dictionary = {}
## The ticket handed to the next card that waits.
var _next_ticket: int = 0

# A moment file dropped on two players is ONE resource shared by both, so a counter
# written into its steps would have each play counting the other's loops down, and the file on
# disk would come back from a play changed.
## Loops still to run for each Loop Back card, kept per play.
var _loops_left: Dictionary = {}
## The random roll each card's chance is answered with, kept per play.
var _rolls: Dictionary = {}
## The properties this play changed and the values to put back on Restore.
var _restore_to: Array = []
# Each tween is kept by handle, because otherwise it goes on writing over the restored value the
# very next frame, which is a Restore that visibly does nothing.
## The tweens this player started, so a Revert or a Restore can stop them before it puts a value back.
var _tweens: Array[Tween] = []

## Players this play started through a Play Player card; they follow it.
var _nested: Array[Node] = []

## Most cards of your own a player keeps hold of at once, the oldest let go first.
const MOST_OWN_RUNNING: int = 16
## The cards of your own a play has started and not yet stopped, so Stop and Restore can reach them.
var _own_running: Array[Resource] = []

## The few players this node plays its Sound cards through, kept and reused instead of made per hit.
var _voices: Array[Node] = []

## The voice each Sound card's sound is on, by the card's name, so a Stop Sound card can find it.
var _sounding: Dictionary = {}
## The bus volumes a Fade Bus card moved, by bus name, as they were before the first one - what Restore puts back.
var _bus_restore: Dictionary = {}
## The tweens that are moving a bus volume right now.
var _bus_tweens: Array[Tween] = []
## When the card that ends last will have ended, on the wall clock, so a wait can last until the cards are done.
var _ends_at: float = 0.0
## Which voice a run of hits takes next once every voice is busy.
var _next_voice: int = 0
## The Sound cards already complained about, so a missing sound is said once and not on every hit.
var _told_sound: Dictionary = {}

## The Juice behaviour found beside this player, kept once found.
var _juice_node: Node = null
## True once the missing-Juice warning has been printed, so it is printed only once.
var _told_no_juice: bool = false
## The Juice behaviour beside this node - found by the step call it answers rather than by its class,
## so this pack names no other pack. Said once when there is none, because a list of ten shakes with
## no behaviour under it would otherwise be ten warnings a frame.
func _juice() -> Node:
	var found: Node = _juice_quiet()
	if found != null:
		return found
	if not _told_no_juice:
		_told_no_juice = true
		push_warning("Juice Player: %s has no Juice behaviour beside it, so its shake, flash and hitstop steps did nothing. Add a Juice node under the same object." % name)
	return null
## The script of a card of your own, by the uid (or path) the card holds, or null when that file is not
## in the project any more.
static func own_script_of(card: Dictionary) -> Script:
	var address: String = str(card.get("card_script", "")).strip_edges()
	if address.is_empty() or not ResourceLoader.exists(address):
		return null
	return load(address) as Script
## A fresh card of your own holding the values the saved card keeps under its export names. A file kept
## as text (a uid or a path) is loaded for an export that holds a Resource. Null when the script is gone or
## is not a card (it has no `play`).
static func own_card_of(card: Dictionary) -> Resource:
	var script: Script = own_script_of(card)
	if script == null or not script.can_instantiate():
		return null
	var made: Variant = script.new()
	if not (made is Resource) or not (made as Resource).has_method("play"):
		return null
	for property: Dictionary in script.get_script_property_list():
		var export_name: String = str(property.get("name", ""))
		if not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) or not card.has(export_name):
			continue
		var stored: Variant = card[export_name]
		if int(property.get("type", TYPE_NIL)) == TYPE_OBJECT and stored is String:
			stored = load(stored) if ResourceLoader.exists(stored) else null
		(made as Resource).set(export_name, stored)
	return made as Resource
## The sound a card names, or null when it names none or the file is not there.
static func _stream_at(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
## A voice of the kind asked for: a free one if there is one, else a new one while there is room, else
## the oldest one taken over (and made the kind asked for).
func _voice_for(kind: String) -> Node:
	for index: int in range(_voices.size() - 1, -1, -1):
		if not is_instance_valid(_voices[index]):
			_voices.remove_at(index)
	for voice: Node in _voices:
		if voice.get_class() == kind and not bool(voice.get("playing")):
			return voice
	if _voices.size() < SOUND_VOICES:
		var fresh: Node = ClassDB.instantiate(kind) as Node
		add_child(fresh)
		_voices.append(fresh)
		return fresh
	var slot: int = _next_voice % _voices.size()
	_next_voice += 1
	var taken: Node = _voices[slot]
	if taken.get_class() == kind:
		taken.call("stop")
		return taken
	taken.queue_free()
	var replacement: Node = ClassDB.instantiate(kind) as Node
	add_child(replacement)
	_voices[slot] = replacement
	return replacement

# --- Addressed by label: the rows that edit the list while the game runs ---
# Every row that names one juice card names it by its LABEL - the name typed on the card in the
# Inspector, or, for a card nobody named, its own word. That is the whole addressing scheme: a
# list tuned in the Inspector and a list retuned by rows can never disagree about which step is
# meant, and a label that is not in the list is said out loud rather than quietly ignored.

# An OVERRIDE list: a word that is
# not in it belongs to no family, so Mute Juice Family leaves it alone, and a card carrying
# its own `category` key answers with that instead of with this. It is the RUNTIME copy of the
# question, and the editor's card list takes its stripe colours from here rather than keeping a
# second one, so a word can only ever have one family.
## Which family a card belongs to when it does not say so itself.
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
	"play_player": "signal",
	"sound": "audio",
	"stop_sound": "audio",
	"fade_bus": "audio",
	"vibrate": "device",
	"tween_property": "transform",
	"particles": "scene",
	"spawn_scene": "scene",
	"push": "scene",
	"force_for_a_time": "scene",
	"gravity_for_a_time": "scene",
	"freeze_body": "scene",
	"animation": "transform",
	"sprite_animation": "transform",
	"show_hide": "transform",
	"squash_stretch": "transform",
	"punch_position": "transform",
	"punch_rotation": "transform",
	"pop": "transform",
	"fade": "transform",
	"grab_focus": "transform",
	"count_to": "transform",
	"reveal_text": "transform",
	"fill_bar": "transform",
	"shader_value": "transform",
	"call_method": "signal",
	"pause_player": "signal",
	"collision_for": "scene",
	"collision_layer_for": "scene",
	"remove_node": "scene",
	"draw_order": "scene",
	"switch_node": "scene",
	"look_at": "transform",
	"rotate_by": "transform",
	"rotate_to": "transform",
	"rotation_shake": "transform",
	"light": "scene",
	"scene_look": "screen",
	"bus_effect": "audio",
	"spring": "transform",
	"slow_object": "pause",
	"animation_parameter": "transform"
}

## Keys that Set Juice Card Field and Juice Card Field accept.
const FIELD_KEYS: PackedStringArray = ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops"]
## The keys beyond the eight above that the Set Juice Card Field row writes on any card: the clock and the strength window of the Timing foldout.
const TIMING_FIELD_KEYS: PackedStringArray = ["clock", "min_strength", "max_strength"]
## The keys a moment file's step can hold, plus the two every card carries that a file has no use for: its label and its switch.
const MOMENT_KEYS: PackedStringArray = ["verb", "amount", "effect", "seconds", "label", "active"]
## Juice families muted right now.
var _muted: Dictionary = {}

## The list whose cards this player has copied for itself; until then they are shared with scene copies.
var _owned_steps: Array[Dictionary] = []

## Labels to skip once on the next play, removed as they are used.
var _skip_once: Dictionary = {}

## True while a Hold Here is holding the play still on its current card.
var _held: bool = false
## Label of the card a Jump To Juice Card asked to carry on from, or empty.
var _jump_to: String = ""

## When this play began, on the wall clock, so one card's own progress can be answered without a tick running to count it.
var _started_at: float = 0.0

# --- Cards that reach other nodes: particles, animation, scenes, bodies, UI and shaders ---
# A card of these words points at a node with a NodePath written relative to this player (the editor
# fills it in with Godot's node picker), so a scene can be moved or copied and its cards still find
# their nodes. A card that points at nothing acts on the object this player is under. A path that
# finds no node is said ONCE, in the Output panel, and the card does nothing: it never raises an
# error and never says it again on the next play.

## Step word: restart, start or stop a particles node.
const PARTICLES: String = "particles"
## Step word: play a clip of an AnimationPlayer.
const ANIMATION: String = "animation"
## Step word: play an animation of an AnimatedSprite2D or AnimatedSprite3D.
const SPRITE_ANIMATION: String = "sprite_animation"
## Step word: show a node, hide it, or show it for a time.
const SHOW_HIDE: String = "show_hide"
## Step word: call a method of a node.
const CALL_METHOD: String = "call_method"
## Step word: add a copy of a scene to the running scene.
const SPAWN_SCENE: String = "spawn_scene"
## Step word: give a body one shove.
const PUSH: String = "push"
## Step word: a steady force on a RigidBody for a time.
const FORCE_FOR_A_TIME: String = "force_for_a_time"
## Step word: a different gravity scale on a RigidBody for a time.
const GRAVITY_FOR_A_TIME: String = "gravity_for_a_time"
## Step word: hold a RigidBody still for a time.
const FREEZE_BODY: String = "freeze_body"
## Step word: squash and stretch the object this player is under, through the Juice node.
const SQUASH_STRETCH: String = "squash_stretch"
## Step word: kick the position of the object this player is under, through the Juice node.
const PUNCH_POSITION: String = "punch_position"
## Step word: kick the rotation of the object this player is under, through the Juice node.
const PUNCH_ROTATION: String = "punch_rotation"
## Step word: scale a node up from its middle and let it settle.
const POP: String = "pop"
## Step word: fade a node through its modulate.
const FADE: String = "fade"
## Step word: give a Control the keyboard and gamepad focus.
const GRAB_FOCUS: String = "grab_focus"
## Step word: a label counts to a number.
const COUNT_TO: String = "count_to"
## Step word: the letters of a label appear one after another.
const REVEAL_TEXT: String = "reveal_text"
## Step word: a bar glides to a value.
const FILL_BAR: String = "fill_bar"
## Step word: move one value of the shader on a node.
const SHADER_VALUE: String = "shader_value"
## Step word: pause, resume or flip another Juice Player, or this one.
const PAUSE_PLAYER: String = "pause_player"
## Step word: switch a collision shape off for a time.
const COLLISION_FOR: String = "collision_for"
## Step word: take a body or an area off a collision layer, or stop it seeing one, for a time.
const COLLISION_LAYER_FOR: String = "collision_layer_for"
## Step word: free a node, or hand it back to its pool.
const REMOVE_NODE: String = "remove_node"
## Step word: draw a 2D node in front of the rest for a time.
const DRAW_ORDER: String = "draw_order"
## Step word: hide a node, stop its scripts or disable its collision, for a time or for good.
const SWITCH_NODE: String = "switch_node"
## Step word: turn a node to face another.
const LOOK_AT: String = "look_at"
## Step word: turn a node by an angle.
const ROTATE_BY: String = "rotate_by"
## Step word: turn a node to an angle.
const ROTATE_TO: String = "rotate_to"
## Step word: wobble the angle of a node and settle it.
const ROTATION_SHAKE: String = "rotation_shake"
## Step word: flare a light and let it go back.
const LIGHT: String = "light"
## Step word: move one value of the scene's look for a time.
const SCENE_LOOK: String = "scene_look"
## Step word: hold an effect of an audio bus for a time.
const BUS_EFFECT: String = "bus_effect"
## Step word: kick a value of a 2D node and let its Spring node settle it.
const SPRING: String = "spring"
## Step word: slow the animations and particles under a node for a time.
const SLOW_OBJECT: String = "slow_object"
## Step word: move one parameter of an AnimationTree and bring it back.
const ANIMATION_PARAMETER: String = "animation_parameter"

## Every word this node plays itself that points at another node or at the world.
const WORLD_WORDS: PackedStringArray = [
	"particles", "animation", "sprite_animation", "show_hide", "call_method", "spawn_scene", "push",
	"force_for_a_time", "gravity_for_a_time", "freeze_body", "squash_stretch", "punch_position",
	"punch_rotation", "pop", "fade", "grab_focus", "count_to", "reveal_text", "fill_bar", "shader_value", "pause_player",
	"collision_for", "collision_layer_for", "remove_node", "draw_order", "switch_node", "look_at", "rotate_by",
	"rotate_to", "rotation_shake", "light", "scene_look", "bus_effect", "spring", "slow_object", "animation_parameter"
]

## Particles word: play the burst again from the start.
const DO_RESTART: String = "restart"
## Particles word: switch emitting on.
const DO_START: String = "start"
## Particles word: switch emitting off.
const DO_STOP: String = "stop"
## Show or Hide word: show the node.
const DO_SHOW: String = "show"
## Show or Hide word: hide the node.
const DO_HIDE: String = "hide"
## Show or Hide word: show the node for the card's seconds, then hide it.
const DO_FLASH: String = "flash"

## Push direction word: along a fixed direction.
const PUSH_FIXED: String = "fixed"
## Push direction word: away from a picked node.
const PUSH_AWAY: String = "away"
## Push direction word: the way the body is already moving.
const PUSH_ALONG: String = "along"

## The transition words of a Tween, as Godot names them.
const TRANSITIONS: Dictionary = {
	"linear": Tween.TRANS_LINEAR, "sine": Tween.TRANS_SINE, "quint": Tween.TRANS_QUINT,
	"quart": Tween.TRANS_QUART, "quad": Tween.TRANS_QUAD, "expo": Tween.TRANS_EXPO,
	"elastic": Tween.TRANS_ELASTIC, "cubic": Tween.TRANS_CUBIC, "circ": Tween.TRANS_CIRC,
	"bounce": Tween.TRANS_BOUNCE, "back": Tween.TRANS_BACK, "spring": Tween.TRANS_SPRING
}

## The ease words of a Tween, as Godot names them.
const EASES: Dictionary = {
	"in": Tween.EASE_IN, "out": Tween.EASE_OUT, "in_out": Tween.EASE_IN_OUT, "out_in": Tween.EASE_OUT_IN
}

## The cards that have already said their node is missing, by label, so it is said once.
var _told_cards: Dictionary = {}

## The materials a Shader Value card gave one node, by node id, so a second card reuses the copy.
var _own_materials: Dictionary = {}

## The forces a Force For A Time card is holding on bodies right now: body, force and the timer's end.
var _held_forces: Array[Dictionary] = []
## The path a card holds under a key, or an empty path when it holds none. A card written by hand may
## hold the path as text, so both spellings read.
static func _path_of(card: Dictionary, key: String) -> NodePath:
	var stored: Variant = card.get(key, NodePath())
	return stored if stored is NodePath else NodePath(str(stored))
## The node a card points at, or null. A card that names none acts on the object this player is under
## when `host_when_empty` is set, and on nothing otherwise.
func _target(card: Dictionary, key: String, host_when_empty: bool) -> Node:
	var path: NodePath = _path_of(card, key)
	if path.is_empty():
		return host if host_when_empty else null
	return get_node_or_null(path)
## A tween of this player's own, kept so a Restore or a stop can end it. Tweens that have finished are let go.
func _new_tween() -> Tween:
	for held: int in range(_tweens.size() - 1, -1, -1):
		if not is_instance_valid(_tweens[held]) or not _tweens[held].is_running():
			_tweens.remove_at(held)
	var made: Tween = create_tween()
	_tweens.append(made)
	return made
## The body a body card acts on, or null (said once) when the card names one that is not there.
func _body_of(card: Dictionary) -> Node:
	var body: Node = _target(card, "body", true)
	if body == null:
		_card_missing(card, "points at no body")
	return body
## The shader material of a node: a CanvasItem's material, or a 3D object's material override.
static func _shader_material_of(target: Node) -> ShaderMaterial:
	if target is CanvasItem:
		return (target as CanvasItem).material as ShaderMaterial
	if target is GeometryInstance3D:
		return (target as GeometryInstance3D).material_override as ShaderMaterial
	return null
## The player a Play Player card plays: the one it picked, else the one its old typed name finds. Said
## once, and refused, when it is this player itself or a player that is playing this one.
func _player_to_play(card: Dictionary, typed: String) -> Node:
	var other: Node = null
	if _names_a_node(card, "player"):
		other = _target(card, "player", false)
		if other == null:
			_card_missing(card, "points at no Juice Player")
			return null
	else:
		other = get_node_or_null(NodePath(typed))
	if other == self or (other != null and _plays_through(other, self, 0)):
		_card_missing(card, "would play a player that is already playing it")
		return null
	return other

# --- Cards that change the scene, the light, the look and the sound ---
# A "for a time" card changes a value and puts it back when its time is up. Two cards can change the same value
# (a collision shape switched off by a hit and again by a dodge): it goes back when the LAST of them is done, to
# what it was before the FIRST touched it, so an overlap can never leave a shape off for good. Stop, Restore and
# the player leaving the scene put everything back at once. Where Godot refuses a change in the middle of a
# physics step (a shape's disabled tick, a layer, a mask) the change is made at the safe moment instead.

## What every player's cards hold changed right now, by object, property and layer: the value from before, and who holds it.
static var _holds: Dictionary = {}

## The number the next hold takes as its ticket, so a timer that outlives a Stop can never end a later hold.
static var _next_hold: int = 0

## The ways back of a bus effect, each a Callable, kept until its time is up or the play ends.
var _ways_back: Array[Callable] = []

## The lights this player has flaring and will let go back by themselves, with what each rested at, until the flare is over.
var _flares: Array[Dictionary] = []

## The effects a Bus Effect card added because its bus lacked them, by bus and kind: the effect, and how many cards still hold it.
static var _added_effects: Dictionary = {}

## The nodes a Remove Node card is holding back until this list has finished.
var _removals: Array[Node] = []

## The classes of a collision shape, the nodes a card can switch off.
const SHAPE_CLASSES: PackedStringArray = ["CollisionShape2D", "CollisionShape3D", "CollisionPolygon2D", "CollisionPolygon3D"]

## The most a 2D node can be drawn in front of or behind the rest: Godot refuses a z index past it.
const MOST_Z_INDEX: int = 4096

## How many times a second a rotation shake swings from one side to the other and back.
const SHAKE_HERTZ: float = 12.0

## The words whose effect a skip to the end leaves out, because they last only a time and the skip is already past it.
const LASTS_ONLY_A_TIME: PackedStringArray = [
	"collision_for", "collision_layer_for", "draw_order", "switch_node", "rotation_shake", "light", "scene_look", "bus_effect",
	"spring", "slow_object", "animation_parameter"
]

## The switch a value of the look does nothing without, by the start of its name. The longest start comes first.
const LOOK_SWITCHES: Array = [
	["volumetric_fog_", "volumetric_fog_enabled"], ["adjustment_", "adjustment_enabled"], ["glow_", "glow_enabled"], ["fog_", "fog_enabled"]
]
## Every collision shape at or under a node.
static func _shapes_under(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	if _is_shape(root):
		found.append(root)
	for named: String in SHAPE_CLASSES:
		for shape: Node in root.find_children("*", named, true, false):
			found.append(shape)
	return found
## The node whose look a Scene Look card changes: the one it names, else the first WorldEnvironment in the running
## scene.
func _look_holder(card: Dictionary) -> Node:
	var named: Node = _target(card, "node", false)
	if named != null or not is_inside_tree() or get_tree().current_scene == null:
		return named
	var found: Array[Node] = get_tree().current_scene.find_children("*", "WorldEnvironment", true, false)
	return found[0] if not found.is_empty() else null
## The file that sweeps a bus, or null when the project does not carry it.
static func _bus_mix() -> Script:
	var path: String = "res://eventsheet_addons/bus_mix.gd"
	return load(path) as Script if ResourceLoader.exists(path) else null
## The last effect of a bus that is the kind a way of changing it uses, or null.
static func _last_bus_effect_of(index: int, how: String) -> AudioEffect:
	for slot: int in range(AudioServer.get_bus_effect_count(index) - 1, -1, -1):
		var effect: AudioEffect = AudioServer.get_bus_effect(index, slot)
		var wanted: bool = effect is AudioEffectLowPassFilter
		if how == "dive":
			wanted = effect is AudioEffectAmplify
		elif how == "wash":
			wanted = effect is AudioEffectReverb
		if wanted:
			return effect
	return null
## The engine nodes that have a speed of their own: what Slow One Object slows. An AnimationTree has none.
const SPEED_CLASSES: PackedStringArray = ["AnimationPlayer", "AnimatedSprite2D", "AnimatedSprite3D", "GPUParticles2D", "CPUParticles2D",
		"GPUParticles3D", "CPUParticles3D"]

## The parts of an AnimationTree parameter list that are the tree's own bookkeeping, written by the tree while it plays.
const TREE_BOOKKEEPING: PackedStringArray = ["fade_in_remaining", "fade_out_remaining", "time_to_restart"]

## The springs a Spring card has kicked and not yet seen land, by spring and property: the way back that settles each.
var _springs_moving: Dictionary = {}
# @ace_hidden
## Every node at or under a node that has a speed of its own.
static func speed_nodes_under(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	if root == null:
		return found
	for named: String in SPEED_CLASSES:
		if root.is_class(named):
			found.append(root)
			break
	for named: String in SPEED_CLASSES:
		for node: Node in root.find_children("*", named, true, false):
			if not found.has(node):
				found.append(node)
	return found
# @ace_hidden
## The Spring node that moves a node's values: the node itself, or the child that can kick a property.
static func spring_of(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("bump_property"):
		return node
	for child: Node in node.get_children():
		if child.has_method("bump_property"):
			return child
	return null

# --- Looping a list, and stopping everything ---
# A list that loops is walked again and again by one coroutine that waits at least a frame between
# passes, so a list with nothing in it that takes time cannot lock the game. Every way a play can end
# (Stop, Revert, the node leaving the scene, every player stopped at once) ends what the cards
# STARTED as well as the walk: a list of instant cards has finished walking long before the shake it
# began does, so ending the walk alone would end nothing.

## The group every Juice Player joins by itself, so one call on the tree reaches all. Not the default channel of Play Juice On Channel.
const PLAYERS_GROUP: String = "every_juice_player"

## Whether juice plays at all, for the whole game, set by Set All Juice Players Enabled. It lives on the script, so it holds across scenes.
static var _all_enabled: bool = true

## True once this player has said it was asked to play while every player was switched off, so it is said once.
var _told_switched_off: bool = false

## Counts the plays, so a loop that was stopped or replaced can tell and end after its pass.
var _loop_run: int = 0
## The Juice behaviour beside this node, without a word of complaint when there is none.
func _juice_quiet() -> Node:
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
	return null

# @ace_action
# @ace_featured
# @ace_name("Play Juice")
# @ace_description("Plays this node's list of juice cards and carries straight on with the rows under this one. The strength scales every amount in the list, so a light hit and a heavy one are one list at two numbers.")
# @ace_display_template("Play juice at [b]{at_strength}[/b]")
# @ace_lift_example("$FeedbackPlayer.play([[at_strength|argument: 1.0]])")
# @ace_lift_example("$JuicePlayer.play([[at_strength|argument: 1.0]])")
# @ace_param(at_strength, default: 1.0, desc: "Scales every amount in the list. 1 is the list as tuned, 0.5 a lighter version of the same beat.")
# @ace_codegen_template("$JuicePlayer.play({at_strength})")
func play(at_strength: float) -> void:
	if _may_start():
		_play_list(at_strength, direction == BOTTOM_TO_TOP)

# @ace_action
# @ace_featured
# @ace_name("Play Juice And Wait")
# @ace_description("Plays the list and WAITS for the last card to finish - the rows under this one are what happens afterwards. Use it when the hit has to land before the death animation starts.")
# @ace_display_template("Play juice at [b]{at_strength}[/b] and wait")
# @ace_lift_example("await $FeedbackPlayer.play_and_wait([[at_strength|argument: 1.0]])")
# @ace_lift_example("await $JuicePlayer.play_and_wait([[at_strength|argument: 1.0]])")
# @ace_param(at_strength, default: 1.0, desc: "Scales every amount in the list, exactly as Play Juice does.")
# @ace_codegen_template("await $JuicePlayer.play_and_wait({at_strength})")
func play_and_wait(at_strength: float) -> void:
	if _may_start():
		await _play_list(at_strength, direction == BOTTOM_TO_TOP)
		var still: float = _ends_at - float(Time.get_ticks_msec()) / 1000.0
		if still > 0.0:
			await MomentRunner.then(self, still, MomentRunner.CLOCK_REAL)

# @ace_action
# @ace_name("Play Juice Backwards")
# @ace_description("Plays the list from the far end, so the last juice card is felt first. The other half of a beat that has to undo itself - a door that opened, closing.")
# @ace_display_template("Play juice backwards at [b]{at_strength}[/b]")
# @ace_lift_example("$FeedbackPlayer.play_backwards([[at_strength|argument: 1.0]])")
# @ace_lift_example("$JuicePlayer.play_backwards([[at_strength|argument: 1.0]])")
# @ace_param(at_strength, default: 1.0, desc: "Scales every amount in the list, exactly as Play Juice does.")
# @ace_codegen_template("$JuicePlayer.play_backwards({at_strength})")
func play_backwards(at_strength: float) -> void:
	if _may_start():
		_play_list(at_strength, direction != BOTTOM_TO_TOP)

# @ace_action
# @ace_name("Play Juice On Channel")
# @ace_description("Plays every Juice Player in a group at once, at one strength - the whole squad flinching, every button in a menu bouncing. Put the players in the group and name it here.")
# @ace_display_template("Play juice on channel [b]{channel}[/b] at [b]{at_strength}[/b]")
# @ace_lift_example("$FeedbackPlayer.play_on_channel([[channel|name: "juice_players"]], [[at_strength|argument: 1.0]])")
# @ace_lift_example("$JuicePlayer.play_on_channel([[channel|name: "juice_players"]], [[at_strength|argument: 1.0]])")
# @ace_param(channel, default: juice_players, desc: "The group every player that should feel this is in.")
# @ace_param(at_strength, default: 1.0, desc: "Scales every amount in every list it reaches.")
# @ace_codegen_template("$JuicePlayer.play_on_channel("{channel}", {at_strength})")
func play_on_channel(channel: String, at_strength: float) -> void:
	if channel.strip_edges().is_empty() or not is_inside_tree():
		return
	get_tree().call_group(channel, "play_feedbacks_from_channel", at_strength)

# @ace_action
# @ace_featured
# @ace_name("Stop Juice")
# @ace_description("Stops the play where it is and ends what its cards started, even when the list has already been walked: a shake, a slowmo, a hold on the clock, a tween part of the way, a sound, a force, a shape switched off, a light, an effect on a bus. Whatever a card held for a time is given back now; a value it was moving stays where it had got to, and Restore Initial Values puts it back. A loop stops too.")
# @ace_lift_example("$FeedbackPlayer.stop()")
# @ace_lift_example("$JuicePlayer.stop()")
# @ace_codegen_template("$JuicePlayer.stop()")
func stop() -> void:
	_loop_run += 1
	_end_effects()
	_told_nested("stop")
	if not playing:
		return
	_live.clear()
	_waiting.clear()
	_resumed.emit()
	_close()

# @ace_action
# @ace_name("Skip To End")
# @ace_description("Stops waiting and does everything that is left at once - the cutscene skip of a juice list. Every card from the head down is felt, without the pauses between them.")
# @ace_lift_example("$FeedbackPlayer.skip_to_end()")
# @ace_lift_example("$JuicePlayer.skip_to_end()")
# @ace_codegen_template("$JuicePlayer.skip_to_end()")
func skip_to_end() -> void:
	if not playing:
		return
	_live.clear()
	_paused = false
	_resumed.emit()
	var left: Array = _order
	var from: int = _head + 1 if _head_taken else _head
	var at_strength: float = _head_strength
	var late: Array = _waiting.values()
	_waiting.clear()
	_close()
	_told_nested("skip_to_end")
	for index: int in range(from, left.size()):
		if not (left[index] is Dictionary):
			continue
		var card: Dictionary = left[index]
		if _card_runs(card, at_strength, index) and not _is_timing(word_of(card)):
			_do_step(card, at_strength, true)
	for waiting: Variant in late:
		var card: Dictionary = waiting as Dictionary
		_do_step(card, at_strength, true)

# @ace_action
# @ace_name("Restore Initial Values")
# @ace_description("Puts every value this player's cards changed back to what it was before the FIRST card touched it, and ends the shake, the slowmo and the other effects the Juice node was holding for them. The undo of a list that moved the object rather than flashing it, or turned a light, a layer or a node's order.")
# @ace_lift_example("$FeedbackPlayer.restore()")
# @ace_lift_example("$JuicePlayer.restore()")
# @ace_codegen_template("$JuicePlayer.restore()")
func restore() -> void:
	_stop_tweens()
	_restore_buses()
	_release_forces()
	_release_holds()
	_take_ways_back()
	_tell_juice_ended(true)
	_told_own("restore")
	_told_nested("restore")
	for entry: Variant in _restore_to:
		var card: Dictionary = entry as Dictionary
		var object: Object = card.get("object") as Object
		if object != null and is_instance_valid(object):
			object.set(str(card.get("property", "")), card.get("value"))
	_restore_to.clear()

# @ace_action
# @ace_name("Revert")
# @ace_description("Stops the play and puts back what it changed, the LAST change first - so a stack of tweens unwinds in the order it was built rather than all at once.")
# @ace_lift_example("$FeedbackPlayer.revert()")
# @ace_lift_example("$JuicePlayer.revert()")
# @ace_codegen_template("$JuicePlayer.revert()")
func revert() -> void:
	stop()
	_restore_to.reverse()
	restore()

# @ace_action
# @ace_name("Stop All Juice Players")
# @ace_description("Stops every Juice Player in the scene and ends what they started: sounds, shakes, a slowmo, a fade on a bus, a force. With 'and restore' every object goes back to how it was before its player first touched it. It acts on every player whichever object the row is on.")
# @ace_display_template("Stop all juice players, restore [b]{and_restore}[/b]")
# @ace_lift_example("$FeedbackPlayer.stop_all_juice_players([[and_restore|argument: false]])")
# @ace_lift_example("$JuicePlayer.stop_all_juice_players([[and_restore|argument: false]])")
# @ace_param(and_restore, default: false, desc: "Put every object back the way it was, as well as stopping.")
# @ace_codegen_template("$JuicePlayer.stop_all_juice_players({and_restore})")
func stop_all_juice_players(and_restore: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().call_group(PLAYERS_GROUP, "stop_juice_from_group", and_restore)

# @ace_action
# @ace_name("Set All Juice Players Enabled")
# @ace_description("The one switch for the whole game, for a cutscene or an options menu: while it is off a Play does nothing, whichever player it is asked of. It does not stop a play that is already running; Stop All Juice Players does that.")
# @ace_display_template("Set all juice players enabled [b]{enabled}[/b]")
# @ace_lift_example("$FeedbackPlayer.set_all_juice_players_enabled([[enabled|argument: true]])")
# @ace_lift_example("$JuicePlayer.set_all_juice_players_enabled([[enabled|argument: true]])")
# @ace_param(enabled, default: true, desc: "False switches all juice off, true switches it back on.")
# @ace_codegen_template("$JuicePlayer.set_all_juice_players_enabled({enabled})")
func set_all_juice_players_enabled(enabled: bool) -> void:
	_all_enabled = enabled

# @ace_action
# @ace_name("Toggle Juice Paused")
# @ace_description("Pauses the play if it is running and resumes it if it is paused: one row for a button, or an alarm that holds while a door is open.")
# @ace_display_template("Toggle juice paused")
# @ace_lift_example("$FeedbackPlayer.toggle_juice_paused()")
# @ace_lift_example("$JuicePlayer.toggle_juice_paused()")
# @ace_codegen_template("$JuicePlayer.toggle_juice_paused()")
func toggle_juice_paused() -> void:
	if _paused:
		resume_feedbacks()
	else:
		pause_feedbacks()

# @ace_action
# @ace_name("Set Looping")
# @ace_description("Turns the Loop tick on or off from a row. Turned off, the pass that is running finishes and the list stops there; use Stop Juice to end it at once. Turning it on does not start a play: play the list as usual.")
# @ace_display_template("Set looping [b]{on}[/b]")
# @ace_lift_example("$FeedbackPlayer.set_looping([[on|argument: true]])")
# @ace_lift_example("$JuicePlayer.set_looping([[on|argument: true]])")
# @ace_param(on, default: true, desc: "True loops the list when it plays, false plays it once.")
# @ace_codegen_template("$JuicePlayer.set_looping({on})")
func set_looping(on: bool) -> void:
	loop = on

# @ace_action
# @ace_name("Pause Juice")
# @ace_description("Holds the play where it is without losing its place. Resume Juice carries on from the same card.")
# @ace_lift_example("$FeedbackPlayer.pause_feedbacks()")
# @ace_lift_example("$JuicePlayer.pause_feedbacks()")
# @ace_codegen_template("$JuicePlayer.pause_feedbacks()")
func pause_feedbacks() -> void:
	_paused = playing

# @ace_action
# @ace_name("Resume Juice")
# @ace_description("Carries on from where Pause Juice left off.")
# @ace_lift_example("$FeedbackPlayer.resume_feedbacks()")
# @ace_lift_example("$JuicePlayer.resume_feedbacks()")
# @ace_codegen_template("$JuicePlayer.resume_feedbacks()")
func resume_feedbacks() -> void:
	_paused = false
	_resumed.emit()

# @ace_condition
# @ace_name("Is Playing")
# @ace_description("True while a play is running - between the started and the finished trigger.")
# @ace_lift_example("$FeedbackPlayer.is_playing()")
# @ace_lift_example("$JuicePlayer.is_playing()")
# @ace_codegen_template("$JuicePlayer.is_playing()")
func is_playing() -> bool:
	return playing

# @ace_condition
# @ace_name("Has Played")
# @ace_description("True once this player has played at least once, and stays true. The "they have seen this already" question, with nothing to store.")
# @ace_lift_example("$FeedbackPlayer.has_played()")
# @ace_lift_example("$JuicePlayer.has_played()")
# @ace_codegen_template("$JuicePlayer.has_played()")
func has_played() -> bool:
	return _played_once

# @ace_expression
# @ace_name("Juice Progress")
# @ace_description("How far down the list the play has got, 0 at the first card and 1 when the last one is done.")
# @ace_codegen_template("$JuicePlayer.feedbacks_progress()")
func feedbacks_progress() -> float:
	return progress

# @ace_expression
# @ace_name("Juice Duration")
# @ace_description("The longest path through the list in seconds - the same number the head of the Inspector shows, so a row can wait exactly as long as the beat lasts.")
# @ace_codegen_template("$JuicePlayer.feedbacks_duration()")
func feedbacks_duration() -> float:
	return duration_of(_steps_now())

# @ace_action
# @ace_name("Add Juice Card")
# @ace_description("Adds one juice card to this player's list while the game runs - the same card the Inspector adds, with the same fields. Leave the after box empty to put it at the end, or name a card to put it straight after that one.")
# @ace_display_template("Add juice card [b]{step}[/b] after [b]{after_label}[/b]")
# @ace_lift_example("$FeedbackPlayer.add_feedback([[step|expression: {"verb": "shake"}]], [[after_label|name: "shake"]])")
# @ace_lift_example("$FeedbackPlayer.add_feedback([[step|expression: {"verb": "shake"}]], "")")
# @ace_lift_example("$JuicePlayer.add_feedback([[step|expression: {"verb": "shake"}]], [[after_label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.add_feedback([[step|expression: {"verb": "shake"}]], "")")
# @ace_param(step, hint: feedback_step, default: {"verb": "shake", "amount": 0.4, "seconds": 0.2}, desc: "The juice card itself: pick its kind and fill the card, exactly as in the Inspector's list.")
# @ace_param(after_label, hint: juice_card_label, desc: "The label of the card this one goes after. Empty puts it at the end of the list.")
# @ace_codegen_template("$JuicePlayer.add_feedback({step}, "{after_label}")")
func add_feedback(step: Dictionary, after_label: String) -> void:
	var list: Array = _own_list()
	var at: int = list.size()
	if not after_label.strip_edges().is_empty():
		at = _index_in(list, after_label)
		if at < 0:
			_no_such(after_label, "Add Juice Card")
			return
		at += 1
	list.insert(at, _carded(step))

# @ace_action
# @ace_name("Insert Juice Card Before")
# @ace_description("Puts a juice card into the list immediately ABOVE the card you name - the other half of Add Juice Card, for a step that has to be felt before something already in the beat.")
# @ace_display_template("Insert juice card [b]{step}[/b] before [b]{before_label}[/b]")
# @ace_lift_example("$FeedbackPlayer.insert_feedback_before([[step|expression: {"verb": "shake"}]], [[before_label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.insert_feedback_before([[step|expression: {"verb": "shake"}]], [[before_label|name: "shake"]])")
# @ace_param(step, hint: feedback_step, default: {"verb": "flash", "amount": 1.0, "seconds": 0.1}, desc: "The juice card itself: pick its kind and fill the card, exactly as in the Inspector's list.")
# @ace_param(before_label, hint: juice_card_label, default: shake, desc: "The label of the card this one goes above.")
# @ace_codegen_template("$JuicePlayer.insert_feedback_before({step}, "{before_label}")")
func insert_feedback_before(step: Dictionary, before_label: String) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, before_label)
	if at < 0:
		_no_such(before_label, "Insert Juice Card Before")
		return
	list.insert(at, _carded(step))

# @ace_action
# @ace_name("Replace Juice Card")
# @ace_description("Swaps one card in the list for another, in place. THE weapon-change row: the beat the designer tuned stays the beat, and only the kick inside it changes. The new card keeps the old one's label unless it brings its own, so every other row that names it goes on working.")
# @ace_display_template("Replace juice card [b]{label}[/b] with [b]{step}[/b]")
# @ace_lift_example("$FeedbackPlayer.replace_feedback([[label|name: "kick"]], [[step|expression: {"verb": "shake"}]])")
# @ace_lift_example("$JuicePlayer.replace_feedback([[label|name: "kick"]], [[step|expression: {"verb": "shake"}]])")
# @ace_param(label, hint: juice_card_label, default: kick, desc: "The label of the card being swapped out.")
# @ace_param(step, hint: feedback_step, default: {"verb": "punch", "amount": 1.0, "seconds": 0.1}, desc: "What takes its place: a kind and its fields, as in the Inspector's list.")
# @ace_codegen_template("$JuicePlayer.replace_feedback("{label}", {step})")
func replace_feedback(label: String, step: Dictionary) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Replace Juice Card")
		return
	var fresh: Dictionary = _carded(step)
	if str(fresh.get("label", "")).strip_edges().is_empty():
		fresh["label"] = _label_of(list[at] as Dictionary)
	list[at] = fresh

# @ace_action
# @ace_name("Remove Juice Card")
# @ace_description("Takes one card out of the list. What an upgrade that drops a part of a beat does, and the undo of Add Juice Card.")
# @ace_display_template("Remove juice card [b]{label}[/b]")
# @ace_lift_example("$FeedbackPlayer.remove_feedback([[label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.remove_feedback([[label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card to take out.")
# @ace_codegen_template("$JuicePlayer.remove_feedback("{label}")")
func remove_feedback(label: String) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Remove Juice Card")
		return
	list.remove_at(at)

# @ace_action
# @ace_name("Move Juice Card To")
# @ace_description("Moves one card to a place in the list - the drag handle, as a row. The first card is 1; a number past the end puts it last.")
# @ace_display_template("Move juice card [b]{label}[/b] to [b]{position}[/b]")
# @ace_lift_example("$FeedbackPlayer.move_feedback_to([[label|name: "shake"]], [[position|argument: 1]])")
# @ace_lift_example("$JuicePlayer.move_feedback_to([[label|name: "shake"]], [[position|argument: 1]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card to move.")
# @ace_param(position, default: 1, desc: "Where it lands. The first card in the list is 1.")
# @ace_codegen_template("$JuicePlayer.move_feedback_to("{label}", {position})")
func move_feedback_to(label: String, position: int) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Move Juice Card To")
		return
	var card: Dictionary = list[at] as Dictionary
	list.remove_at(at)
	list.insert(clampi(position - 1, 0, list.size()), card)

# @ace_action
# @ace_name("Enable Juice Card")
# @ace_description("Ticks one card's box, so it is felt again from the next play on. The enable box in the Inspector, as a row.")
# @ace_display_template("Enable juice card [b]{label}[/b]")
# @ace_lift_example("$FeedbackPlayer.enable_feedback([[label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.enable_feedback([[label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card to switch on.")
# @ace_codegen_template("$JuicePlayer.enable_feedback("{label}")")
func enable_feedback(label: String) -> void:
	var card: Dictionary = _edited(label, "Enable Juice Card")
	if not card.is_empty():
		card["active"] = true

# @ace_action
# @ace_name("Disable Juice Card")
# @ace_description("Unticks one card's box, so the play steps over it. What an accessibility option that drops the screen shake and keeps the sound does with one row.")
# @ace_display_template("Disable juice card [b]{label}[/b]")
# @ace_lift_example("$FeedbackPlayer.disable_feedback([[label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.disable_feedback([[label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card to switch off.")
# @ace_codegen_template("$JuicePlayer.disable_feedback("{label}")")
func disable_feedback(label: String) -> void:
	var card: Dictionary = _edited(label, "Disable Juice Card")
	if not card.is_empty():
		card["active"] = false

# @ace_action
# @ace_name("Set Juice Card Field")
# @ace_description("Retunes ONE value on one card: how much, how long, which extra word. The number box in the Inspector, as a row, so a weapon or a difficulty can move an amount without a second list.")
# @ace_display_template("Set juice card [b]{label}[/b] [b]{field}[/b] to [b]{value}[/b]")
# @ace_lift_example("$FeedbackPlayer.set_feedback_field([[label|name: "shake"]], [[field|name: "amount"]], [[value|expression: 0.5]])")
# @ace_lift_example("$JuicePlayer.set_feedback_field([[label|name: "shake"]], [[field|name: "amount"]], [[value|expression: 0.5]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being tuned.")
# @ace_param(field, hint: juice_card_field, options: amount|effect|seconds|delay|interval|repeat|chance|loops|clock|min_strength|max_strength, autocomplete: amount|effect|seconds|delay|interval|repeat|chance|loops|clock|min_strength|max_strength, default: amount, desc: "Which value on the card to write.")
# @ace_param(value, hint: juice_card_value, default: 1.0, desc: "What to write. A number for an amount or a length, a word for the extra one.")
# @ace_codegen_template("$JuicePlayer.set_feedback_field("{label}", "{field}", {value})")
func set_feedback_field(label: String, field: String, value: Variant) -> void:
	var card: Dictionary = _edited(label, "Set Juice Card Field")
	if card.is_empty():
		return
	if field == "verb" or field == "card_script":
		push_warning("Juice Player: the card \"%s\" on %s cannot have its %s changed, because that is what makes it the card it is, so Set Juice Card Field left it alone. Replace the card instead." % [label, name, field])
		return
	if not FIELD_KEYS.has(field) and not TIMING_FIELD_KEYS.has(field) and not card.has(field):
		push_warning("Juice Player: the card \"%s\" on %s has no field called \"%s\", so Set Juice Card Field did nothing." % [label, name, field])
		return
	card[field] = value

# @ace_action
# @ace_name("Set Juice Card Timing")
# @ace_description("Moves one card in time: how long it waits first, how many times it repeats and how far apart, and which clock it counts on. The card's Timing foldout, as a row.")
# @ace_display_template("Set juice card [b]{label}[/b] timing: delay [b]{delay}[/b] s, [b]{repeat}[/b] times")
# @ace_lift_example("$FeedbackPlayer.set_feedback_timing([[label|name: "shake"]], [[delay|argument: 0.0]], [[repeat|argument: 1]], [[interval|argument: 0.0]], [[clock|name: "game"]])")
# @ace_lift_example("$JuicePlayer.set_feedback_timing([[label|name: "shake"]], [[delay|argument: 0.0]], [[repeat|argument: 1]], [[interval|argument: 0.0]], [[clock|name: "game"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being retimed.")
# @ace_param(delay, default: 0.0, desc: "How long the card waits after the head reaches it, in seconds.")
# @ace_param(repeat, default: 1, desc: "How many times it is felt. 1 is once.")
# @ace_param(interval, default: 0.0, desc: "The gap between repeats, in seconds.")
# @ace_param(clock, options: game|real, default: game, desc: "Which clock it counts on: game time slows with a slowmo, real time never does.")
# @ace_codegen_template("$JuicePlayer.set_feedback_timing("{label}", {delay}, {repeat}, {interval}, "{clock}")")
func set_feedback_timing(label: String, delay: float, repeat: int, interval: float, clock: String) -> void:
	var card: Dictionary = _edited(label, "Set Juice Card Timing")
	if card.is_empty():
		return
	card["delay"] = maxf(delay, 0.0)
	card["repeat"] = maxi(repeat, 1)
	card["interval"] = maxf(interval, 0.0)
	card["clock"] = clock

# @ace_action
# @ace_name("Set Juice Card Chance")
# @ace_description("How often one card is felt at all, as a percentage. 100 is every time, 25 is a quarter of the hits - the cheapest variety there is.")
# @ace_display_template("Set juice card [b]{label}[/b] chance [b]{percent}[/b]%")
# @ace_lift_example("$FeedbackPlayer.set_feedback_chance([[label|name: "shake"]], [[percent|argument: 100.0]])")
# @ace_lift_example("$JuicePlayer.set_feedback_chance([[label|name: "shake"]], [[percent|argument: 100.0]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being rolled for.")
# @ace_param(percent, default: 100.0, desc: "The chance it is felt, 0 to 100.")
# @ace_codegen_template("$JuicePlayer.set_feedback_chance("{label}", {percent})")
func set_feedback_chance(label: String, percent: float) -> void:
	var card: Dictionary = _edited(label, "Set Juice Card Chance")
	if not card.is_empty():
		card["chance"] = clampf(percent, 0.0, 100.0)

# @ace_action
# @ace_name("Rename Juice Card")
# @ace_description("Renames one card. Every other row addresses cards by this name, so renaming one is renaming what the rest of the sheet has to say.")
# @ace_display_template("Rename juice card [b]{label}[/b] to [b]{new_label}[/b]")
# @ace_lift_example("$FeedbackPlayer.set_feedback_label([[label|name: "shake"]], [[new_label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.set_feedback_label([[label|name: "shake"]], [[new_label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The card's name now.")
# @ace_param(new_label, default: big shake, desc: "What it is called from here on.")
# @ace_codegen_template("$JuicePlayer.set_feedback_label("{label}", "{new_label}")")
func set_feedback_label(label: String, new_label: String) -> void:
	var card: Dictionary = _edited(label, "Rename Juice Card")
	if not card.is_empty():
		card["label"] = new_label

# @ace_action
# @ace_name("Duplicate Juice Card")
# @ace_description("Copies one card and puts the copy straight under it, under a name of its own. Two shakes a frame apart out of one tuned card.")
# @ace_display_template("Duplicate juice card [b]{label}[/b] as [b]{new_label}[/b]")
# @ace_lift_example("$FeedbackPlayer.duplicate_feedback([[label|name: "shake"]], [[new_label|name: "shake"]])")
# @ace_lift_example("$FeedbackPlayer.duplicate_feedback([[label|name: "shake"]], "")")
# @ace_lift_example("$JuicePlayer.duplicate_feedback([[label|name: "shake"]], [[new_label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.duplicate_feedback([[label|name: "shake"]], "")")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card to copy.")
# @ace_param(new_label, desc: "What the copy is called. Empty names it after the original.")
# @ace_codegen_template("$JuicePlayer.duplicate_feedback("{label}", "{new_label}")")
func duplicate_feedback(label: String, new_label: String) -> void:
	var list: Array = _own_list()
	var at: int = _index_in(list, label)
	if at < 0:
		_no_such(label, "Duplicate Juice Card")
		return
	var copy: Dictionary = (list[at] as Dictionary).duplicate(true)
	copy["label"] = new_label if not new_label.strip_edges().is_empty() else _label_of(copy) + " copy"
	list.insert(at + 1, copy)

# @ace_action
# @ace_name("Clear Juice Cards")
# @ace_description("Empties the list. What a player that is about to be handed a whole beat by Copy Juice Cards From or Load Moment File wants first.")
# @ace_lift_example("$FeedbackPlayer.clear_feedbacks()")
# @ace_lift_example("$JuicePlayer.clear_feedbacks()")
# @ace_codegen_template("$JuicePlayer.clear_feedbacks()")
func clear_feedbacks() -> void:
	steps.clear()
	moment_file = null

# @ace_action
# @ace_name("Copy Juice Cards From")
# @ace_description("Takes another player's whole list and makes it this one's - a copy, so retuning either afterwards leaves the other alone. One tuned enemy hit, given to every enemy that spawns.")
# @ace_display_template("Copy juice cards from [i]{other}[/i]")
# @ace_lift_example("$FeedbackPlayer.copy_feedbacks_from([[other|argument: 1]])")
# @ace_lift_example("$JuicePlayer.copy_feedbacks_from([[other|argument: 1]])")
# @ace_param(other, desc: "The Juice Player to copy the list off.")
# @ace_codegen_template("$JuicePlayer.copy_feedbacks_from({other})")
func copy_feedbacks_from(other: Node) -> void:
	if other == null:
		return
	var carried: Variant = other.get("steps")
	if not (carried is Array):
		push_warning("Juice Player: %s cannot copy cards from %s, which is not a Juice Player, so Copy Juice Cards From did nothing." % [name, other.name])
		return
	var list: Array = _own_list()
	list.clear()
	for entry: Variant in carried as Array:
		if entry is Dictionary:
			list.append((entry as Dictionary).duplicate(true))

# @ace_action
# @ace_name("Load Moment File")
# @ace_description("Brings a moment file's beat INTO this player's list, as a copy - so it can be retuned by rows afterwards without ever writing to the file two other objects may be playing.")
# @ace_display_template("Load moment file [b]{path}[/b]")
# @ace_lift_example("$FeedbackPlayer.load_moment_file([[path|text: "res://moment.tres"]])")
# @ace_lift_example("$JuicePlayer.load_moment_file([[path|text: "res://moment.tres"]])")
# @ace_param(path, default: res://eventsheet_addons/juice/impact.tres, desc: "The moment file to read, as its res:// path.")
# @ace_codegen_template("$JuicePlayer.load_moment_file("{path}")")
func load_moment_file(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Juice Player: %s has no moment file at \"%s\" to load, so Load Moment File did nothing." % [name, path])
		return
	var file: Resource = load(path)
	if file == null or not (file.get("steps") is Array):
		push_warning("Juice Player: %s cannot load \"%s\", which is not a moment file, so Load Moment File did nothing." % [name, path])
		return
	moment_file = file
	_own_list()

# @ace_action
# @ace_name("Save Moment File")
# @ace_description("Writes this list out as a moment file, so a beat tuned while the game ran can be shared, shipped or loaded back. Only the four keys a file holds are written, and only for the ten moment words a file can be played by: a card that is switched off, the timing words a list adds, and this node's own three (a property tween, a signal, a nested player) are named in a warning and left out.")
# @ace_display_template("Save moment file to [b]{path}[/b]")
# @ace_lift_example("$FeedbackPlayer.save_moment_file([[path|text: "res://moment.tres"]])")
# @ace_lift_example("$JuicePlayer.save_moment_file([[path|text: "res://moment.tres"]])")
# @ace_param(path, default: user://my_moment.tres, desc: "Where to write it. At run time that is a user:// path, which is the only place a game may write.")
# @ace_codegen_template("$JuicePlayer.save_moment_file("{path}")")
func save_moment_file(path: String) -> void:
	var kind: Script = load("res://eventsheet_addons/moment_resource/moment_resource.gd") as Script
	if kind == null:
		push_warning("Juice Player: %s cannot save a moment file because this project has no moment file script, so Save Moment File did nothing." % name)
		return
	var written: Array[Dictionary] = []
	var left_behind: PackedStringArray = PackedStringArray()
	var left_keys: PackedStringArray = PackedStringArray()
	for entry: Variant in _steps_now():
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		var word: String = word_of(card)
		if not bool(card.get("active", true)) or _is_timing(word) or _is_own_word(word):
			left_behind.append(_label_of(card))
			continue
		written.append({"verb": str(card.get("verb", "")), "amount": float(card.get("amount", 1.0)), "effect": str(card.get("effect", "")), "seconds": float(card.get("seconds", 0.0))})
		var dropped: PackedStringArray = keys_a_file_drops(card)
		if not dropped.is_empty():
			left_keys.append("%s (%s)" % [_label_of(card), ", ".join(dropped)])
	var file: Resource = kind.new()
	file.set("moment_name", name)
	file.set("steps", written)
	for note: String in _moment_file_notes(left_behind, left_keys):
		push_warning(note)
	if ResourceSaver.save(file, path) != OK:
		push_warning("Juice Player: %s could not write \"%s\", so Save Moment File saved nothing." % [name, path])

# @ace_action
# @ace_name("Set Juice Player Strength")
# @ace_description("Turns this whole player up or down without retuning a single card - the object's own volume knob, on top of the strength the play row asks for.")
# @ace_display_template("Set juice player strength [b]{value}[/b]")
# @ace_lift_example("$FeedbackPlayer.set_player_strength([[value|argument: 1.0]])")
# @ace_lift_example("$JuicePlayer.set_player_strength([[value|argument: 1.0]])")
# @ace_param(value, default: 1.0, desc: "What every amount in the list is scaled by. 1 is the list as tuned.")
# @ace_codegen_template("$JuicePlayer.set_player_strength({value})")
func set_player_strength(value: float) -> void:
	strength = maxf(value, 0.0)

# @ace_action
# @ace_name("Set Juice Player Cooldown")
# @ace_description("The shortest gap between two plays, in seconds. A play asked for sooner is refused, which is how a rapid-fire hit stops stacking its own juice.")
# @ace_display_template("Set juice player cooldown [b]{seconds}[/b] s")
# @ace_lift_example("$FeedbackPlayer.set_player_cooldown([[seconds|argument: 0.1]])")
# @ace_lift_example("$JuicePlayer.set_player_cooldown([[seconds|argument: 0.1]])")
# @ace_param(seconds, default: 0.1, desc: "The gap. 0 lets every play through.")
# @ace_codegen_template("$JuicePlayer.set_player_cooldown({seconds})")
func set_player_cooldown(seconds: float) -> void:
	cooldown = maxf(seconds, 0.0)

# @ace_action
# @ace_name("Set Can Play While Playing")
# @ace_description("What a second play does while the first is still running: start again from the top, be ignored, or run alongside it.")
# @ace_display_template("While playing, [b]{answer}[/b]")
# @ace_lift_example("$FeedbackPlayer.set_can_play_while_playing([[answer|name: "restart"]])")
# @ace_lift_example("$JuicePlayer.set_can_play_while_playing([[answer|name: "restart"]])")
# @ace_param(answer, options: restart|ignore|overlap, default: restart, desc: "Restart, ignore, or overlap.")
# @ace_codegen_template("$JuicePlayer.set_can_play_while_playing("{answer}")")
func set_can_play_while_playing(answer: String) -> void:
	while_playing = answer

# @ace_action
# @ace_name("Mute Juice Family")
# @ace_description("Silences a whole family of cards at once - every screen effect, every camera move, every sound - and lets them back with the same row. THE accessibility option: one row per switch on the settings screen, and no card has to be found and unticked.")
# @ace_display_template("Mute juice family [b]{category}[/b]: [b]{muted}[/b]")
# @ace_lift_example("$FeedbackPlayer.mute_feedback_category([[category|name: "screen"]], [[muted|argument: true]])")
# @ace_lift_example("$JuicePlayer.mute_feedback_category([[category|name: "screen"]], [[muted|argument: true]])")
# @ace_param(category, options: audio|transform|camera|screen|pause|loop|signal, default: screen, desc: "The family to silence.")
# @ace_param(muted, default: true, desc: "On silences it; off lets it be felt again.")
# @ace_codegen_template("$JuicePlayer.mute_feedback_category("{category}", {muted})")
func mute_feedback_category(category: String, muted: bool) -> void:
	var family: String = category.strip_edges().to_lower()
	if family.is_empty():
		return
	if muted:
		_muted[family] = true
	else:
		_muted.erase(family)

# @ace_action
# @ace_name("Mute Juice Family On Channel")
# @ace_description("The same switch, thrown for every Juice Player in a group at once - which is what a settings screen wants, because the option is about the game rather than about one object.")
# @ace_display_template("Mute juice family [b]{category}[/b] on channel [b]{channel}[/b]: [b]{muted}[/b]")
# @ace_lift_example("$FeedbackPlayer.mute_category_on_channel([[channel|name: "juice_players"]], [[category|name: "screen"]], [[muted|argument: true]])")
# @ace_lift_example("$JuicePlayer.mute_category_on_channel([[channel|name: "juice_players"]], [[category|name: "screen"]], [[muted|argument: true]])")
# @ace_param(channel, default: juice_players, desc: "The group every player the switch reaches is in.")
# @ace_param(category, options: audio|transform|camera|screen|pause|loop|signal, default: screen, desc: "The family to silence.")
# @ace_param(muted, default: true, desc: "On silences it; off lets it be felt again.")
# @ace_codegen_template("$JuicePlayer.mute_category_on_channel("{channel}", "{category}", {muted})")
func mute_category_on_channel(channel: String, category: String, muted: bool) -> void:
	if channel.strip_edges().is_empty() or not is_inside_tree():
		return
	get_tree().call_group(channel, "mute_feedback_category", category, muted)

# @ace_action
# @ace_name("Scale Juice Amounts")
# @ace_description("Multiplies how much every card in a family does - the effect-strength slider on a settings screen, where half is still the same beat and not a shorter one. Leave the family empty to move the whole list.")
# @ace_display_template("Scale juice amounts [b]{category}[/b] by [b]{factor}[/b]")
# @ace_lift_example("$FeedbackPlayer.scale_feedback_amounts([[category|name: "shake"]], [[factor|argument: 0.5]])")
# @ace_lift_example("$FeedbackPlayer.scale_feedback_amounts("", [[factor|argument: 0.5]])")
# @ace_lift_example("$JuicePlayer.scale_feedback_amounts([[category|name: "shake"]], [[factor|argument: 0.5]])")
# @ace_lift_example("$JuicePlayer.scale_feedback_amounts("", [[factor|argument: 0.5]])")
# @ace_param(category, options: ""|audio|transform|camera|screen|pause|loop|signal, desc: "The family to scale, or empty for every card.")
# @ace_param(factor, default: 0.5, desc: "What each amount is multiplied by. 0.5 is half as much.")
# @ace_codegen_template("$JuicePlayer.scale_feedback_amounts("{category}", {factor})")
func scale_feedback_amounts(category: String, factor: float) -> void:
	var family: String = category.strip_edges().to_lower()
	for entry: Variant in _own_list():
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		if family.is_empty() or _category_of(card) == family:
			card["amount"] = float(card.get("amount", 1.0)) * factor

# @ace_action
# @ace_name("Scale Juice Timing")
# @ace_description("Stretches or squeezes the whole beat in time: every length, every wait and every gap multiplied by the same number. Half makes a snappier version of a beat nobody has to retune card by card.")
# @ace_display_template("Scale juice timing by [b]{factor}[/b]")
# @ace_lift_example("$FeedbackPlayer.retime_feedbacks([[factor|argument: 0.5]])")
# @ace_lift_example("$JuicePlayer.retime_feedbacks([[factor|argument: 0.5]])")
# @ace_param(factor, default: 0.5, desc: "What every length is multiplied by. 0.5 is twice as fast.")
# @ace_codegen_template("$JuicePlayer.retime_feedbacks({factor})")
func retime_feedbacks(factor: float) -> void:
	var scale: float = maxf(factor, 0.0)
	for entry: Variant in _own_list():
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		for key: String in ["seconds", "delay", "interval"]:
			if card.has(key):
				card[key] = float(card[key]) * scale

# @ace_action
# @ace_name("Shuffle Juice Cards Between")
# @ace_description("Reorders the stretch of the list between two cards, both included, at random. The cheapest variety a repeated hit can have: the same juice cards, in a different order every time.")
# @ace_display_template("Shuffle juice cards [b]{first_label}[/b] to [b]{last_label}[/b]")
# @ace_lift_example("$FeedbackPlayer.shuffle_feedbacks_between([[first_label|name: "shake_a"]], [[last_label|name: "shake_c"]])")
# @ace_lift_example("$JuicePlayer.shuffle_feedbacks_between([[first_label|name: "shake_a"]], [[last_label|name: "shake_c"]])")
# @ace_param(first_label, default: shake_a, desc: "One end of the stretch.")
# @ace_param(last_label, default: shake_c, desc: "The other end.")
# @ace_codegen_template("$JuicePlayer.shuffle_feedbacks_between("{first_label}", "{last_label}")")
func shuffle_feedbacks_between(first_label: String, last_label: String) -> void:
	var list: Array = _own_list()
	var from: int = _index_in(list, first_label)
	var to: int = _index_in(list, last_label)
	if from < 0 or to < 0:
		_no_such(first_label if from < 0 else last_label, "Shuffle Juice Cards Between")
		return
	if to < from:
		var swapped: int = from
		from = to
		to = swapped
	var stretch: Array = list.slice(from, to + 1)
	stretch.shuffle()
	for offset: int in range(stretch.size()):
		list[from + offset] = stretch[offset]

# @ace_action
# @ace_name("Pick One Juice Card Starting With")
# @ace_description("Ticks exactly one of the cards whose label starts with what you type and unticks the rest, so shake_a, shake_b and shake_c become one shake chosen fresh each time. Variety out of the list itself, with no branch in the sheet.")
# @ace_display_template("Pick one juice card starting with [b]{prefix}[/b]")
# @ace_lift_example("$FeedbackPlayer.pick_one_feedback_of([[prefix|name: "shake_"]])")
# @ace_lift_example("$JuicePlayer.pick_one_feedback_of([[prefix|name: "shake_"]])")
# @ace_param(prefix, default: shake_, desc: "The start of the labels to choose between.")
# @ace_codegen_template("$JuicePlayer.pick_one_feedback_of("{prefix}")")
func pick_one_feedback_of(prefix: String) -> void:
	var wanted: String = prefix.strip_edges()
	if wanted.is_empty():
		return
	var matches: Array = []
	for entry: Variant in _own_list():
		if entry is Dictionary and _label_of(entry as Dictionary).begins_with(wanted):
			matches.append(entry)
	if matches.is_empty():
		_no_such(wanted, "Pick One Juice Card Starting With")
		return
	var chosen: int = randi() % matches.size()
	for index: int in range(matches.size()):
		(matches[index] as Dictionary)["active"] = index == chosen

# @ace_action
# @ace_name("Jump To Juice Card")
# @ace_description("Moves the head of a RUNNING play to the card you name, so the rest of the beat starts there. What a hit that interrupts its own wind-up wants.")
# @ace_display_template("Jump to juice card [b]{label}[/b]")
# @ace_lift_example("$FeedbackPlayer.jump_to_feedback([[label|name: "impact"]])")
# @ace_lift_example("$JuicePlayer.jump_to_feedback([[label|name: "impact"]])")
# @ace_param(label, hint: juice_card_label, default: impact, desc: "The label of the card to carry on from.")
# @ace_codegen_template("$JuicePlayer.jump_to_feedback("{label}")")
func jump_to_feedback(label: String) -> void:
	_jump_to = label.strip_edges()

# @ace_action
# @ace_name("Skip Juice Card Once")
# @ace_description("Steps over one card the NEXT time the play reaches it, and then forgets about it. The one-off exception a disable would have to be undone after.")
# @ace_display_template("Skip juice card [b]{label}[/b] once")
# @ace_lift_example("$FeedbackPlayer.skip_feedback_once([[label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.skip_feedback_once([[label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card to step over once.")
# @ace_codegen_template("$JuicePlayer.skip_feedback_once("{label}")")
func skip_feedback_once(label: String) -> void:
	if _index_of(label) < 0:
		_no_such(label, "Skip Juice Card Once")
		return
	_skip_once[label.strip_edges()] = true

# @ace_action
# @ace_name("Set Loop Count")
# @ace_description("How many times a Loop Back card sends the head round. A charge that gets longer the further it is held, without a second list.")
# @ace_display_template("Set loop count [b]{label}[/b] to [b]{loops}[/b]")
# @ace_lift_example("$FeedbackPlayer.set_loop_count([[label|name: "loop_back"]], [[loops|argument: 2]])")
# @ace_lift_example("$JuicePlayer.set_loop_count([[label|name: "loop_back"]], [[loops|argument: 2]])")
# @ace_param(label, hint: juice_card_label, default: loop_back, desc: "The label of the Loop Back card.")
# @ace_param(loops, default: 2, desc: "How many times round. 0 walks straight past it.")
# @ace_codegen_template("$JuicePlayer.set_loop_count("{label}", {loops})")
func set_loop_count(label: String, loops: int) -> void:
	var card: Dictionary = _edited(label, "Set Loop Count")
	if card.is_empty():
		return
	card["loops"] = maxi(loops, 0)
	var at: int = _index_in(_order, label)
	if at >= 0:
		_loops_left[at] = maxi(loops, 0)

# @ace_action
# @ace_name("Hold Here")
# @ace_description("Stops the head where it is and leaves it there - a charge held, a beat waiting on the player. Release Hold carries on from the same card, and nothing ticks while it waits.")
# @ace_lift_example("$FeedbackPlayer.hold_here()")
# @ace_lift_example("$JuicePlayer.hold_here()")
# @ace_codegen_template("$JuicePlayer.hold_here()")
func hold_here() -> void:
	_held = playing

# @ace_action
# @ace_name("Release Hold")
# @ace_description("Lets a held play carry on from the card it stopped on.")
# @ace_lift_example("$FeedbackPlayer.release_hold()")
# @ace_lift_example("$JuicePlayer.release_hold()")
# @ace_codegen_template("$JuicePlayer.release_hold()")
func release_hold() -> void:
	_held = false
	_resumed.emit()

# @ace_condition
# @ace_name("Juice Card Is Playing")
# @ace_description("True while the head is on that card - the moment the hit is being felt rather than the whole beat around it.")
# @ace_display_template("Juice card [b]{label}[/b] is playing")
# @ace_lift_example("$FeedbackPlayer.feedback_is_playing([[label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.feedback_is_playing([[label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being asked about.")
# @ace_codegen_template("$JuicePlayer.feedback_is_playing("{label}")")
func feedback_is_playing(label: String) -> bool:
	return playing and now_playing == label.strip_edges()

# @ace_condition
# @ace_name("Has Juice Card")
# @ace_description("True when this player's list holds a card by that name. The question a row asks before it retunes one, and the one a Doctor finding is about.")
# @ace_display_template("Has juice card [b]{label}[/b]")
# @ace_lift_example("$FeedbackPlayer.has_feedback([[label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.has_feedback([[label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label to look for.")
# @ace_codegen_template("$JuicePlayer.has_feedback("{label}")")
func has_feedback(label: String) -> bool:
	return _index_of(label) >= 0

# @ace_condition
# @ace_name("Juice Card Is Enabled")
# @ace_description("True when that card's box is ticked - so a settings screen can show the switch the way the list actually has it.")
# @ace_display_template("Juice card [b]{label}[/b] is enabled")
# @ace_lift_example("$FeedbackPlayer.feedback_is_enabled([[label|name: "shake"]])")
# @ace_lift_example("$JuicePlayer.feedback_is_enabled([[label|name: "shake"]])")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being asked about.")
# @ace_codegen_template("$JuicePlayer.feedback_is_enabled("{label}")")
func feedback_is_enabled(label: String) -> bool:
	var at: int = _index_of(label)
	return at >= 0 and bool((_steps_now()[at] as Dictionary).get("active", true))

# @ace_expression
# @ace_name("Juice Card Count")
# @ace_description("How many cards this player's list holds, ticked or not - the number the head of the Inspector shows.")
# @ace_codegen_template("$JuicePlayer.feedback_count()")
func feedback_count() -> int:
	return _steps_now().size()

# @ace_expression
# @ace_name("Juice Card Label At")
# @ace_description("The name of the card at a place in the list, so a settings screen can list a beat without knowing what is in it. The first card is 1; a number past the end answers with nothing.")
# @ace_param(position, default: 1, desc: "Which card. The first in the list is 1.")
# @ace_codegen_template("$JuicePlayer.feedback_label_at({position})")
func feedback_label_at(position: int) -> String:
	var list: Array = _steps_now()
	var at: int = position - 1
	if at < 0 or at >= list.size() or not (list[at] is Dictionary):
		return ""
	return _label_of(list[at] as Dictionary)

# @ace_expression
# @ace_name("Juice Card Field")
# @ace_description("What one card says at one of its fields - the amount it does, how long it lasts, the extra word it carries. The read half of Set Juice Card Field, so a slider can be shown at the value the list actually holds.")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being read.")
# @ace_param(field, hint: juice_card_field, options: amount|effect|seconds|delay|interval|repeat|chance|loops|clock|min_strength|max_strength, autocomplete: amount|effect|seconds|delay|interval|repeat|chance|loops|clock|min_strength|max_strength, default: amount, desc: "Which value to read.")
# @ace_codegen_template("$JuicePlayer.feedback_field("{label}", "{field}")")
func feedback_field(label: String, field: String) -> Variant:
	return _card_named(label).get(field, null)

# @ace_expression
# @ace_name("Juice Card Progress")
# @ace_description("How far through one card the play is, 0 before it starts and 1 once it is done. Read off the plan rather than off a tick, so asking it costs nothing.")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being watched.")
# @ace_codegen_template("$JuicePlayer.feedback_progress("{label}")")
func feedback_progress(label: String) -> float:
	return _progress_of(label)

# @ace_expression
# @ace_name("Juice Card Duration")
# @ace_description("How long ONE card lasts, its own wait included - beside Juice Duration, which is how long the whole beat lasts.")
# @ace_param(label, hint: juice_card_label, default: shake, desc: "The label of the card being measured.")
# @ace_codegen_template("$JuicePlayer.feedback_duration("{label}")")
func feedback_duration(label: String) -> float:
	var card: Dictionary = _card_named(label)
	var own: float = card_length(card) if _is_timing(word_of(card)) else card_span(card)
	return own + maxf(float(card.get("delay", 0.0)), 0.0)

# @ace_expression
# @ace_name("Current Juice Card")
# @ace_description("The label of the card the head is on right now, or nothing when no play is running.")
# @ace_codegen_template("$JuicePlayer.current_feedback()")
func current_feedback() -> String:
	return now_playing

# @ace_expression
# @ace_name("Loops Left")
# @ace_description("How many times round a Loop Back card still has to go in the play that is running.")
# @ace_param(label, hint: juice_card_label, default: loop_back, desc: "The label of the Loop Back card.")
# @ace_codegen_template("$JuicePlayer.loops_left("{label}")")
func loops_left(label: String) -> int:
	if playing:
		var at: int = _index_in(_order, label)
		if at >= 0:
			return int(_loops_left.get(at, 0))
	return int(_card_named(label).get("loops", 0))

## Autoplay: when the node enters the scene with the box ticked, the list plays once at full strength.
func _ready() -> void:
	if not is_in_group(PLAYERS_GROUP):
		add_to_group(PLAYERS_GROUP)
	if autoplay:
		play(1.0)

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
	if not _all_enabled:
		if not _told_switched_off:
			_told_switched_off = true
			push_warning("Juice Player: %s did not play because every Juice Player is switched off (Set All Juice Players Enabled)." % name)
		return false
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if cooldown > 0.0 and now - _last_played_at < cooldown:
		return false
	if playing and while_playing == IGNORE:
		return false
	if playing and while_playing == RESTART:
		# The interrupted walk stops where it is, and its play is CLOSED here rather than left
		# open: a sheet pairing On Juice Started with On Juice Finished must get both,
		# and the walk that was cut short will never reach the end that would have said so.
		# It ends the way Stop Juice ends, waking a held head and telling the players this
		# play started through a Play Player card: half a beat carrying on under the restart is
		# exactly what the restart was asked to replace.
		_live.clear()
		_waiting.clear()
		_resumed.emit()
		_told_nested("stop")
		_close()
	_last_played_at = now
	return true

# @ace_hidden
## The longest path through a list of steps: a stretch between two holds runs at once, so it is as
## long as its slowest card, and the holds and pauses add up. A Hold that names a card waits for that
## card alone, so what is still running beside it carries on into what comes next. The Inspector head,
## the card badge and the expression all read this one function, so no two of them can disagree.
static func duration_of(list: Array) -> float:
	var walked: Dictionary = _timeline(list)
	return maxf(float(walked["at"]), float(walked["latest"]))

## The one pass over a list that every answer about time reads: where each felt card starts, where the
## head is after the Pauses and Holds, and when the latest card ends. A card's Delay and Repeat hold up
## THAT card only, so the cards under it start where they would have without it; a Pause moves the head
## along, and a Hold waits for the latest END of the cards since the last Hold (or for the one card it
## names), then its own wait. Returns {plan, at, latest, ends}: `at` is the head, `latest` the last end,
## `ends` the end of each card of the stretch by label.
static func _timeline(list: Array) -> Dictionary:
	var plan: Array = []
	var at: float = 0.0
	var latest: float = 0.0
	var ends: Dictionary = {}
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		if not bool(card.get("active", true)):
			continue
		var word: String = word_of(card)
		if word == LOOP_START or word == LOOP_BACK:
			continue
		var delay: float = maxf(float(card.get("delay", 0.0)), 0.0)
		var seconds: float = card_length(card)
		if word == HOLD_UNTIL:
			var arrived: float = at + delay
			at = maxf(arrived, _waited_until(card, ends, latest)) + seconds
			latest = maxf(latest, at)
			ends.clear()
		elif word == PAUSE:
			at += delay + seconds
		else:
			var starts: float = at + delay
			var ends_at: float = starts + card_span(card)
			plan.append({"card": card, "at": starts, "seconds": seconds, "repeat": maxi(int(card.get("repeat", 1)), 1), "every": maxf(float(card.get("interval", 0.0)), 0.0)})
			latest = maxf(latest, ends_at)
			ends[card_label(card)] = maxf(float(ends.get(card_label(card), 0.0)), ends_at)
	return {"plan": plan, "at": at, "latest": latest, "ends": ends}

# @ace_hidden
## How long a felt card lasts from its first play to the end of its last: its own length plus the gaps
## of its repeats. A card that is not repeated lasts its length.
static func card_span(card: Dictionary) -> float:
	var repeat: int = maxi(int(card.get("repeat", 1)), 1)
	var interval: float = maxf(float(card.get("interval", 0.0)), 0.0)
	return card_length(card) + float(repeat - 1) * interval

## The moment a Hold stops waiting: the end of the card it names, or the latest end of the stretch when it
## names nothing or names a card that is not above it in that stretch.
static func _waited_until(hold: Dictionary, ends: Dictionary, latest: float) -> float:
	var wanted: String = str(hold.get("waits_for", "")).strip_edges()
	if wanted.is_empty() or not ends.has(wanted):
		return latest
	return float(ends[wanted])

## The word a card is played under: `yours` for a card of your own (it holds the address of its script),
## else its saved word, trimmed and in lower case. Every place that asks what a card is asks here.
static func word_of(card: Dictionary) -> String:
	if card.has("card_script"):
		return YOURS
	return str(card.get("verb", "")).strip_edges().to_lower()

## Whether a word moves the head rather than being felt.
static func _is_timing(word: String) -> bool:
	return word == PAUSE or word == HOLD_UNTIL or word == LOOP_START or word == LOOP_BACK

## And whether a word is this NODE'S own rather than a moment's: a property walked to a value, a
## signal, a nested player and a sound. The ten moment words are played by the Juice node beside this
## one; these four are done here, and a moment FILE has nowhere to keep them.
static func _is_own_word(word: String) -> bool:
	return word == TWEEN_PROPERTY or word == EMIT_SIGNAL or word == PLAY_PLAYER or word == SOUND \
			or word == STOP_SOUND or word == FADE_BUS or word == VIBRATE or word == YOURS or WORLD_WORDS.has(word)

## The number a card's chance is answered with. One roll per card is thrown before the beat
## begins, so a Skip To End reads the decision the walk would have read rather than throwing the
## dice a second time for the same card.
func _rolled_at(index: int) -> float:
	if not _rolls.has(index):
		_rolls[index] = randf() * 100.0
	return float(_rolls[index])

## And the roll that card will be answered with NEXT time, thrown the moment the walk has used
## this one - which is what keeps a card inside a loop a fresh chance every time round.
func _roll_again(index: int) -> void:
	_rolls[index] = randf() * 100.0

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
		_head_taken = false
		progress = float(index) / float(maxi(order.size(), 1))
		index = await _take(order, index, order[index] as Dictionary, at_strength, token)
		index = _landing(order, index)
	while _alive(token) and int(_pending.get(token, 0)) > 0:
		await _resumed
	_pending.erase(token)
	if _alive(token) and index < order.size():
		push_warning("Juice Player: a loop on %s never came back, so the play was given up after %d steps." % [name, MAX_PLAY_STEPS])
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
## word is a juice card, which is felt and stepped over.
func _take(order: Array, index: int, card: Dictionary, at_strength: float, token: int) -> int:
	var word: String = word_of(card)
	var refused: String = _why_not(card, at_strength, index)
	_head_taken = true
	_roll_again(index)
	if not refused.is_empty():
		if not _is_timing(word):
			on_feedback_skipped.emit(_label_of(card), refused)
		return index + 1
	var clock: String = MomentRunner.CLOCK_REAL if str(card.get("clock", "")) == "real" else MomentRunner.CLOCK_GAME
	var delay: float = maxf(float(card.get("delay", 0.0)), 0.0)
	# A card that is felt and waits or repeats on its own is run beside the walk: its Delay and Repeat hold
	# up THAT card only, and the cards under it start when they would have without it. A Pause, a Hold and
	# the loop cards are the head's own waits, so their delay is waited out here.
	if not _is_timing(word) and (delay > 0.0 or int(card.get("repeat", 1)) > 1):
		_run_beside(card, at_strength, clock, token)
		return index + 1
	if delay > 0.0:
		await MomentRunner.at(self, delay, clock)
		if not _alive(token):
			return order.size()
	match word:
		PAUSE:
			await MomentRunner.then(self, MomentRunner.seconds_of(float(card.get("seconds", 0.0))), clock)
		HOLD_UNTIL:
			on_hold_reached.emit()
			await MomentRunner.hold(self, left_above(order, index), float(card.get("seconds", 0.0)), clock)
		LOOP_START:
			pass
		LOOP_BACK:
			var back: int = _loop_target(order, index, card)
			var left: int = int(_loops_left.get(index, int(card.get("loops", 1))))
			if left > 0 and back >= 0:
				_loops_left[index] = left - 1
				on_loop.emit(left - 1)
				await MomentRunner.then(self, MomentRunner.seconds_of(float(card.get("seconds", 0.0))), clock)
				return back
			_loops_left[index] = int(card.get("loops", 1))
		_:
			await _feel(card, at_strength, clock, token)
	return index + 1

## One felt card, played: announced, done, and repeated as often as it asks. Every felt card comes through here
## whether the walk waited for it or started it beside itself.
func _feel(card: Dictionary, at_strength: float, clock: String, token: int) -> void:
	now_playing = str(card.get("label", word_of(card)))
	on_feedback_started.emit(_label_of(card))
	_ends_at = maxf(_ends_at, float(Time.get_ticks_msec()) / 1000.0 + card_span(card))
	_do_step(card, at_strength)
	await _repeat_rest(card, at_strength, clock, token)
	on_feedback_finished.emit(_label_of(card))

## A felt card that waits out its own delay or plays more than once, started beside the walk. The head has
## moved on already; the play stays open until this card has finished, and a Stop ends it where it is.
func _run_beside(card: Dictionary, at_strength: float, clock: String, token: int) -> void:
	_pending[token] = int(_pending.get(token, 0)) + 1
	_next_ticket += 1
	var ticket: int = _next_ticket
	var delay: float = maxf(float(card.get("delay", 0.0)), 0.0)
	_ends_at = maxf(_ends_at, float(Time.get_ticks_msec()) / 1000.0 + delay + card_span(card))
	if delay > 0.0:
		_waiting[ticket] = card
		await MomentRunner.at(self, delay, clock)
	if _alive(token):
		_waiting.erase(ticket)
		await _feel(card, at_strength, clock, token)
	_waiting.erase(ticket)
	_pending[token] = int(_pending.get(token, 1)) - 1
	_resumed.emit()

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
func _card_runs(card: Dictionary, at_strength: float, index: int) -> bool:
	return _why_not(card, at_strength, index).is_empty()

## WHY a card was not felt, in one word, or "" when it was. The reason is what On Juice Card Skipped
## carries, so a row can tell a card the player muted from one the dice went against - and it is
## asked ONCE for each card the head reaches, because answering the same card twice would consume
## a Skip Next Time twice over and throw the dice again for a decision already made.
func _why_not(card: Dictionary, at_strength: float, index: int) -> String:
	if not bool(card.get("active", true)):
		return "off"
	var named: String = _label_of(card)
	if _skip_once.has(named):
		_skip_once.erase(named)
		return "skipped once"
	# A family switch silences what is FELT. A Pause, a Hold and the two loop cards only move the head,
	# so muting their family leaves the beat the length it was.
	if _muted.has(_category_of(card)) and not _is_timing(word_of(card)):
		return "muted"
	var chance: float = float(card.get("chance", 100.0))
	if chance < 100.0 and _rolled_at(index) >= chance:
		return "chance"
	if at_strength < float(card.get("min_strength", 0.0)):
		return "strength"
	var ceiling: float = float(card.get("max_strength", 0.0))
	if ceiling > 0.0 and at_strength > ceiling:
		return "strength"
	return ""

## One juice card, felt. The ten moment words go to the Juice behaviour beside this node - the same
## call a moment file makes - and this node's own words are done here.
func _do_step(card: Dictionary, at_strength: float, skipping: bool = false) -> void:
	var word: String = word_of(card)
	var amount: float = float(card.get("amount", 1.0))
	var effect: String = str(card.get("effect", ""))
	var seconds: float = maxf(float(card.get("seconds", 0.0)), 0.0)
	# The player's own strength scales EVERY kind of card, not only the felt ones: a whole
	# object's juice turned down has to turn down the tween that moves it too.
	var at: float = at_strength * maxf(strength, 0.0)
	# The no-flashing ceiling and floor belong to the words a player SEES, and the runner beside
	# this file holds that list for every home a moment has. None of this node's own three words
	# is one of them: a property tween's target is a position, a width or an angle, a signal
	# carries no amount at all, and a nested player is handed a strength rather than an amplitude.
	# Holding a tween to 200 pixels down to 0.3 would not be less flashing, it would be the wrong
	# number. The ten moment words below ARE in the list, and the Juice node holds them to it as
	# they arrive.
	if word == YOURS:
		_play_own_card(card, at)
		return
	if WORLD_WORDS.has(word):
		if skipping and LASTS_ONLY_A_TIME.has(word):
			return
		_play_world_card(word, card, at, seconds, skipping)
		return
	match word:
		TWEEN_PROPERTY:
			# A card that holds none of the newer keys is the one-number tween it always was.
			if _is_whole_tween(card):
				_tween_card(card, at, seconds)
			else:
				_tween_property(card, effect, amount * at, maxf(seconds, 0.0))
		EMIT_SIGNAL:
			if _names_a_node(card, "node") and not str(card.get("signal", "")).is_empty():
				_emit_on_node(card)
			else:
				on_feedback_signal.emit(effect)
		SOUND:
			# A skip jumps to where the beat ends, and a sound is not a place: it is not heard late.
			if not skipping:
				_play_sound(card, at)
		STOP_SOUND:
			if not skipping:
				_stop_sound(effect, seconds)
		FADE_BUS:
			if not skipping:
				_fade_bus(card, effect, amount, seconds)
		VIBRATE:
			if not skipping:
				_vibrate(card, at)
		PLAY_PLAYER:
			var other: Node = _player_to_play(card, effect)
			if other != null and other.has_method("play"):
				if not _nested.has(other):
					_nested.append(other)
				other.call("play", at * maxf(amount, 0.0))
				# A play started BY a skip is skipped too. The list that started it has already been
				# closed, so there is nothing left to tell it later - and a cutscene skip that leaves a
				# nested beat running at its full length has not skipped the cutscene.
				if skipping and other.has_method("skip_to_end"):
					other.call("skip_to_end")
		_:
			var juice: Node = _juice()
			if juice != null and word == "shake" and MomentRunner.is_timed_shake(card) and juice.has_method("shake_from_card"):
				# A Shake card with a tick or a curve lasts its Seconds and has a shape; one without keeps shaking
				# as it always has, and so does a Juice node too old to know the difference.
				juice.call("shake_from_card", card, at)
			elif juice != null:
				juice.call("moment_step", word, amount, effect, seconds, at)

# @ace_hidden
## What a broadcast on a channel arrives as. A NAME OF THIS PACK'S OWN, never the bare word play:
## an audio, video or animation player in the same group answers to that one too, and call_group
## swallows the error - so a channel meant for juice would quietly start somebody's music.
func play_feedbacks_from_channel(at_strength: float) -> void:
	play(at_strength)

## Everything this play set going through a Play Player card, told the same thing the outer list was
## just told. A nested play is part of the beat around it: stopping, skipping or restoring the list
## that started it has to reach the ones it started, or half the beat carries on alone.
func _told_nested(what: String) -> void:
	for other: Node in _nested:
		if is_instance_valid(other) and other.has_method(what):
			other.call(what)
	if what != "restore":
		_nested.clear()

## The tweens this player started, stopped and forgotten. A value put back while the tween that moved
## it is still running is written over on the very next frame, so a Restore stops them first.
func _stop_tweens() -> void:
	for walked: Tween in _tweens:
		if is_instance_valid(walked):
			walked.kill()
	_tweens.clear()
	_flares.clear()

## A property on the host walked to a value, with what it was written down first so Restore can put
## it back. The walk is the engine's own tween, so nothing ticks while nothing is playing. A property the
## host does not have is said once, naming this player and the card.
func _tween_property(card: Dictionary, property: String, value: float, seconds: float) -> void:
	if host == null or property.strip_edges().is_empty():
		return
	var before: Variant = host.get(property)
	if before == null:
		_card_missing(card, "points at %s, which has no property called \"%s\"" % [host.name, property])
		return
	_keep_first(host, property, before)
	if seconds <= 0.0:
		host.set(property, value)
		return
	# The handle is KEPT: a Restore that only writes the value back is written over again by this
	# very tween on the next frame. Restoring stops them first.
	# The ones that have finished are let go of here rather than kept for the life of the node.
	for held: int in range(_tweens.size() - 1, -1, -1):
		if not is_instance_valid(_tweens[held]) or not _tweens[held].is_running():
			_tweens.remove_at(held)
	var walked: Tween = create_tween()
	_tweens.append(walked)
	walked.tween_property(host, NodePath(property), value, seconds)

# @ace_hidden
## What one play of a Sound card is made of: the stream, the level, the pitch and the bus. The two rolls
## are numbers from 0 to 1 that land inside the card's spreads (0 is the bottom of one, 0.5 the middle and
## 1 the top), so the game, which throws dice, and the editor's Listen button, which throws them too,
## read one function and mean the same card.
static func sound_settings(card: Dictionary, at_strength: float, pitch_roll: float, volume_roll: float) -> Dictionary:
	var volume: float = float(card.get("volume_db", 0.0)) + (clampf(volume_roll, 0.0, 1.0) * 2.0 - 1.0) * maxf(float(card.get("volume_spread_db", 0.0)), 0.0)
	if bool(card.get("follows_strength", false)):
		volume += linear_to_db(maxf(at_strength, 0.0001))
	var pitch: float = float(card.get("pitch", 1.0)) + (clampf(pitch_roll, 0.0, 1.0) * 2.0 - 1.0) * maxf(float(card.get("pitch_spread", 0.0)), 0.0)
	return {
		"stream": str(card.get("stream", "")),
		"volume_db": volume,
		"pitch_scale": maxf(pitch, LOWEST_PITCH),
		"bus": str(card.get("bus", "Master")),
		"here": str(card.get("heard_from", HEARD_HERE)) != HEARD_EVERYWHERE
	}

# @ace_hidden
## How long one card lasts on its own, its delay not counted. A Sound card lasts as long as its stream
## plays at its pitch (a half second sound at double pitch is a quarter of a second); every other card
## says so with its Seconds. The plan, the badge and the Hold all read this one function.
static func card_length(card: Dictionary) -> float:
	if word_of(card) == YOURS:
		return _own_length(card)
	if (word_of(card) == LIGHT or word_of(card) == ANIMATION_PARAMETER) and bool(card.get("back", true)):
		return maxf(float(card.get("seconds", 0.0)), 0.0) + maxf(float(card.get("back_seconds", 0.2)), 0.0)
	if word_of(card) == SCENE_LOOK or word_of(card) == BUS_EFFECT:
		return maxf(float(card.get("seconds", 0.0)), 0.0) + maxf(float(card.get("back_seconds", 0.3)), 0.0)
	if word_of(card) != SOUND:
		return maxf(float(card.get("seconds", 0.0)), 0.0)
	var stream: AudioStream = _stream_at(str(card.get("stream", "")))
	if stream == null:
		return 0.0
	return stream.get_length() / maxf(float(card.get("pitch", 1.0)), LOWEST_PITCH)

## How long a card of your own says it takes. The editor does not run a script that is not a tool script, so
## there the card's seconds stand in for it.
static func _own_length(card: Dictionary) -> float:
	if Engine.is_editor_hint():
		return maxf(float(card.get("seconds", 0.0)), 0.0)
	var made: Resource = own_card_of(card)
	if made == null or not made.has_method("length"):
		return 0.0
	return maxf(float(made.call("length")), 0.0)

## Plays a card of your own: a fresh copy holding the card's values, told which player is playing it, and
## kept until the list is stopped or restored so it can be told to stop or put things back.
func _play_own_card(card: Dictionary, at: float) -> void:
	var made: Resource = own_card_of(card)
	if made == null:
		_card_missing(card, "names a card script that is not in the project")
		return
	if "player" in made:
		made.set("player", self)
	_own_running.append(made)
	if _own_running.size() > MOST_OWN_RUNNING:
		_own_running.remove_at(0)
	made.call("play", host, at)

## Tells every card of your own that is still going to `stop` or `restore`. A card is let go of once it has
## been told to put things back, so a Stop followed by a Restore reaches it twice.
func _told_own(what: String) -> void:
	for made: Resource in _own_running:
		if is_instance_valid(made) and made.has_method(what):
			made.call(what)
	if what == "restore":
		_own_running.clear()

## One Sound card, heard. It plays through one of a few voices kept for the purpose, so a fast run of
## hits reuses them instead of making a node each. Muting the Sound family never reaches here: the walk
## has already stepped over the card.
func _play_sound(card: Dictionary, at: float) -> void:
	var settings: Dictionary = sound_settings(card, at, randf(), randf())
	var stream: AudioStream = _stream_at(str(settings.get("stream", "")))
	if stream == null:
		if str(settings.get("stream", "")).is_empty():
			_tell_sound(card, "has no sound picked, so it stayed silent.")
		else:
			_tell_sound(card, "cannot find its sound \"%s\", so it stayed silent." % str(settings.get("stream", "")))
		return
	var bus: String = str(settings.get("bus", "Master"))
	if AudioServer.get_bus_index(bus) < 0:
		_tell_sound(card, "asks for the bus \"%s\", which this project does not have, so it played on Master." % bus)
		bus = "Master"
	var kind: String = "AudioStreamPlayer"
	if bool(settings.get("here", true)) and host is Node2D:
		kind = "AudioStreamPlayer2D"
	elif bool(settings.get("here", true)) and host is Node3D:
		kind = "AudioStreamPlayer3D"
	var voice: Node = _voice_for(kind)
	voice.set("stream", stream)
	voice.set("volume_db", float(settings.get("volume_db", 0.0)))
	voice.set("pitch_scale", float(settings.get("pitch_scale", 1.0)))
	voice.set("bus", bus)
	if kind != "AudioStreamPlayer":
		voice.set("global_position", host.get("global_position"))
	voice.call("play")
	_sounding[_label_of(card)] = voice

## Says what is wrong with a Sound card once, naming this player and the card.
func _tell_sound(card: Dictionary, what: String) -> void:
	var told: String = _label_of(card) + what
	if _told_sound.has(told):
		return
	_told_sound[told] = true
	push_warning("Juice Player: the sound card \"%s\" on %s %s" % [_label_of(card), name, what])

## How much of the cards above is still to run when a Hold is reached - the number the Hold waits for.
## Read off the same pass the plan reads: the latest END of the cards since the last Hold (their delays and
## repeats counted), or only the end of the card the Hold names when it names one that is there (a name that
## is no card above waits for the slowest, as a Hold that names nothing does), less the time the head has
## already spent getting here.
static func left_above(order: Array, index: int) -> float:
	var walked: Dictionary = _timeline(order.slice(0, maxi(index, 0)))
	var delay: float = 0.0
	var wanted: String = ""
	if index >= 0 and index < order.size() and order[index] is Dictionary:
		delay = maxf(float((order[index] as Dictionary).get("delay", 0.0)), 0.0)
		wanted = str((order[index] as Dictionary).get("waits_for", "")).strip_edges()
	var arrived: float = float(walked["at"]) + delay
	var until: float = float(walked["latest"])
	if not wanted.is_empty() and (walked["ends"] as Dictionary).has(wanted):
		until = float((walked["ends"] as Dictionary)[wanted])
	return maxf(until - arrived, 0.0)

## The same number, asked of the walk's own copy of the list.
func _longest_above(order: Array, index: int) -> float:
	return left_above(order, index)

## Where a Loop Back sends the head: the nearest Hold or Loop Start above it that the card is willing
## to land on. -1 when there is none, which makes the loop a step that does nothing.
func _loop_target(order: Array, index: int, card: Dictionary) -> int:
	var to_hold: bool = bool(card.get("to_hold", true))
	var to_start: bool = bool(card.get("to_loop_start", true))
	var walk: int = index - 1
	while walk >= 0:
		var word: String = word_of(order[walk] as Dictionary)
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
	_ends_at = _started_at
	_order = order
	_head = 0
	_head_strength = at_strength
	_head_taken = false
	_nested.clear()
	_waiting.clear()
	_loops_left.clear()
	_rolls.clear()
	for index: int in order.size():
		if order[index] is Dictionary:
			_loops_left[index] = int((order[index] as Dictionary).get("loops", 1))
			_rolls[index] = randf() * 100.0
	_tell_juice_began(order)
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
	_remove_waiting()

# @ace_hidden
## When each card of a list starts and how long it lasts: [{card, at, seconds}], in list order. A
## stretch between two holds starts together, a Pause pushes everything under it along, and the
## loops are left out because a plan is what one pass looks like. The Inspector's timeline and the
## editor preview both read this, so the picture and the sample can never disagree.
static func schedule_of(list: Array) -> Array:
	return _timeline(list)["plan"]

# @ace_hidden
## How far through a play of a card an editor preview is `time` seconds into the list: 0 to 1 while one of the
## card's plays (the first, or a repeat) is going, -1 when none is. The preview, the lit marks on the cards and
## the sample of a card all ask this, so a card that repeats is seen repeating in the editor.
static func through_at(plan: Dictionary, time: float) -> float:
	var span: float = maxf(float(plan.get("seconds", 0.0)), 0.05)
	var repeats: int = maxi(int(plan.get("repeat", 1)), 1)
	var gap: float = maxf(float(plan.get("every", 0.0)), 0.0)
	for pass_index: int in range(repeats):
		var through: float = (time - float(plan.get("at", 0.0)) - float(pass_index) * gap) / span
		if through >= 0.0 and through <= 1.0:
			return through
	return -1.0

# @ace_hidden
## What the object would be doing `time` into a play - the editor's look at the list, sampled rather
## than run. The shape is the plugin's shared behaviour-preview contract (exported values in, the
## host's rest state in, the properties to write out), so the Tools-menu preview and the Inspector's
## own Play button read one function and show one picture.
##
## Only the three words an editor can honestly show are sampled: a shake as a wobble, a punch as a
## swell, and a tweened property walking to its value. A hitstop and a flash are things a running
## game does to time and to the screen, and drawing a guess at them would be worse than the gap.
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
		var through: float = through_at(plan, time)
		if through < 0.0:
			continue
		var amount: float = float(card.get("amount", 1.0)) * at_strength
		var word: String = word_of(card)
		if word == "shake":
			# A card with a tick or a curve draws the shape the running shake has; one without draws the fall
			# it always drew.
			var level: float = 1.0 - through
			if MomentRunner.is_timed_shake(card):
				var kept: String = str(card.get("curve", "")).strip_edges()
				var curve: Curve = load(kept) as Curve if not kept.is_empty() and ResourceLoader.exists(kept) else null
				level = MomentRunner.shake_shape(through, bool(card.get("fade_in", false)), bool(card.get("fade_out", false)), curve)
			offset += Vector2(sin(time * 47.0), cos(time * 53.0)) * amount * 8.0 * level
		elif word == "punch":
			swell += amount * 0.2 * sin(through * PI)
		elif word == TWEEN_PROPERTY and not card.has("node") and not card.has("to"):
			var property: String = str(card.get("effect", ""))
			if base.has(property) and (base[property] is float or base[property] is int):
				written[property] = lerpf(float(base[property]), amount, through)
	if base.get("position") is Vector2 and offset != Vector2.ZERO:
		written["position"] = (base["position"] as Vector2) + offset
	if base.get("scale") is Vector2 and not is_zero_approx(swell):
		written["scale"] = (base["scale"] as Vector2) * (1.0 + swell)
	return written

## Stops the sound a Sound card of that name started, fading it out over `fade` seconds when asked. An
## empty name stops every sound this player has going. A sound that has already ended is left alone.
func _stop_sound(card_name: String, fade: float) -> void:
	var wanted: String = card_name.strip_edges()
	for label: Variant in _sounding.keys():
		if not wanted.is_empty() and str(label) != wanted:
			continue
		var voice: Node = _sounding[label] as Node
		_sounding.erase(label)
		if voice == null or not is_instance_valid(voice) or not bool(voice.get("playing")):
			continue
		if fade > 0.0:
			var fading: Tween = create_tween()
			fading.tween_property(voice, "volume_db", SILENT_DB, fade)
			fading.tween_callback(voice.call.bind("stop"))
		else:
			voice.call("stop")

## Moves a bus's volume to `target_db` over `seconds`, remembering where it was so Restore can put it back.
## A bus this project does not have is said once and left alone.
func _fade_bus(card: Dictionary, bus: String, target_db: float, seconds: float) -> void:
	var index: int = AudioServer.get_bus_index(bus.strip_edges())
	if index < 0:
		_card_missing(card, "names the bus \"%s\", which this project does not have" % bus)
		return
	var key: String = AudioServer.get_bus_name(index)
	if not _bus_restore.has(key):
		_bus_restore[key] = AudioServer.get_bus_volume_db(index)
	if seconds <= 0.0:
		AudioServer.set_bus_volume_db(index, target_db)
		return
	var moved: Tween = get_tree().create_tween()
	_bus_tweens.append(moved)
	moved.tween_method(func(level: float) -> void: AudioServer.set_bus_volume_db(index, level), AudioServer.get_bus_volume_db(index), target_db, seconds)

## Puts every bus a Fade Bus card moved back to the volume it had.
func _restore_buses() -> void:
	for moved: Tween in _bus_tweens:
		if moved != null and moved.is_valid():
			moved.kill()
	_bus_tweens.clear()
	for key: Variant in _bus_restore:
		var index: int = AudioServer.get_bus_index(str(key))
		if index >= 0:
			AudioServer.set_bus_volume_db(index, float(_bus_restore[key]))
	_bus_restore.clear()

## Rumbles every controller that is connected - the weak motor and the strong one, each scaled by the
## strength of the play - and buzzes a phone for the same time. The web has neither, so there it does nothing.
func _vibrate(card: Dictionary, at: float) -> void:
	if OS.has_feature("web"):
		return
	var seconds: float = maxf(float(card.get("seconds", 0.0)), 0.0)
	var weak: float = clampf(float(card.get("weak", 0.5)) * at, 0.0, 1.0)
	var strong: float = clampf(float(card.get("strong", 0.5)) * at, 0.0, 1.0)
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, seconds)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(int(seconds * 1000.0), maxf(weak, strong))

# @ace_hidden
## What the editor can show of a card's word: "felt" when it plays for real (a shake, a punch, a
## tweened property, a sound, and the cards that move another node), "time" when the editor shows only its length (a wait, a loop word,
## and the two that change the game's time), and "skipped:<why>" for the rest, with the reason in
## words. One answer for the Inspector's play buttons, Debug view and the guide.
static func editor_kind(word: String) -> String:
	match word:
		"shake", "punch", TWEEN_PROPERTY, SOUND, PARTICLES, ANIMATION, SPRITE_ANIMATION, SHOW_HIDE, SQUASH_STRETCH, PUNCH_POSITION, PUNCH_ROTATION, POP, FADE, COUNT_TO, REVEAL_TEXT, FILL_BAR, SHADER_VALUE, LOOK_AT, ROTATE_BY, ROTATE_TO, ROTATION_SHAKE, DRAW_ORDER, LIGHT:
			return "felt"
		PAUSE, HOLD_UNTIL, LOOP_START, LOOP_BACK, "hitstop", "slowmo":
			return "time"
		STOP_SOUND:
			return "skipped:it ends a sound the running game started"
		FADE_BUS:
			return "skipped:it moves a bus volume, which the editor leaves alone"
		VIBRATE:
			return "skipped:a controller or a phone is not in the editor"
		GRAB_FOCUS:
			return "skipped:focus belongs to the running game"
		PUSH, FORCE_FOR_A_TIME, GRAVITY_FOR_A_TIME, FREEZE_BODY:
			return "skipped:not shown in the editor, physics needs the running game"
		COLLISION_FOR, COLLISION_LAYER_FOR:
			return "skipped:not shown in the editor, physics needs the running game"
		REMOVE_NODE:
			return "skipped:it would remove a node from your scene"
		SWITCH_NODE:
			return "skipped:it would switch a node of your scene off"
		SCENE_LOOK:
			return "skipped:it would change the look the editor saves"
		BUS_EFFECT:
			return "skipped:the editor's buses are the project's own"
		SPRING:
			return "skipped:a spring needs the running game's Spring node"
		SLOW_OBJECT:
			return "skipped:it would slow the animations of your scene in the editor"
		ANIMATION_PARAMETER:
			return "skipped:an animation tree runs in the game"
		SPAWN_SCENE:
			return "skipped:not shown in the editor, it adds a scene to the running game"
		CALL_METHOD:
			return "skipped:not shown in the editor, it would run your own code"
		EMIT_SIGNAL:
			return "skipped:a signal runs the game's own code"
		PLAY_PLAYER:
			return "skipped:another player runs its own list"
	return "skipped:the running game draws it"

# @ace_hidden
## The keys of a card that a moment file would leave off: everything but its kind, amount, effect and seconds,
## and the label and switch every card carries. Save Moment File names them before it writes, so nothing
## a card holds is dropped without being said.
static func keys_a_file_drops(card: Dictionary) -> PackedStringArray:
	var dropped: PackedStringArray = PackedStringArray()
	for key: Variant in card:
		if not MOMENT_KEYS.has(str(key)):
			dropped.append(str(key))
	return dropped

# @ace_hidden
## What Save Moment File says before it writes: the cards it left out of the file altogether, and the keys it left
## off the cards it kept, each in a sentence that names this player. Nothing a card holds is dropped unsaid.
func _moment_file_notes(left_behind: PackedStringArray, left_keys: PackedStringArray) -> PackedStringArray:
	var notes: PackedStringArray = PackedStringArray()
	if not left_behind.is_empty():
		notes.append("Juice Player: a moment file holds the ten moment words only - no timing, no card that is switched off, and none of this node's own three (a property tween, a signal, a nested player) - so %s left these out of the file: %s." % [name, ", ".join(left_behind)])
	if not left_keys.is_empty():
		notes.append("Juice Player: a moment file holds a card's kind, amount, effect and seconds and nothing else, so %s left these off the cards it kept: %s." % [name, "; ".join(left_keys)])
	return notes

# @ace_hidden
## The name one card answers to: what it was called in the list, or its own word when it was never
## named. THE ONE PLACE a label is derived, so every row addresses cards identically, and a Hold that
## waits for one card names it the same way.
static func card_label(card: Dictionary) -> String:
	var named: String = str(card.get("label", "")).strip_edges()
	return named if not named.is_empty() else str(card.get("verb", "")).strip_edges()

## The same name, asked of the card by this node.
func _label_of(card: Dictionary) -> String:
	return card_label(card)

## Which family a card belongs to: its own word for it when it carries one, else the family its
## word belongs to, else none at all.
func _category_of(card: Dictionary) -> String:
	var said: String = str(card.get("category", "")).strip_edges().to_lower()
	if not said.is_empty():
		return said
	return str(CATEGORY_OF.get(word_of(card), ""))

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

## Said when a row names a juice card this player has not got. A warning rather than an error,
## because the rest of the beat is still worth playing; in the editor the same mistake is a quiet
## finding on the row itself, which is where it can actually be fixed.
func _no_such(label: String, row: String) -> void:
	push_warning("Juice Player: %s has no juice card labelled \"%s\", so %s did nothing." % [name, label, row])

## The list the EDIT rows work on: this player's own. A player whose moment-file slot is filled is
## playing a beat two other objects may be playing too, and an edit row must never write into that
## file - so the first edit takes a copy of it into this list and lets the slot go. The beat is
## unchanged; it is simply this object's own now. The same goes for the list itself: copies of one
## scene share the card dictionaries inside it, so the first edit also swaps every card for a copy
## made in place (the list keeps its identity, so a play already walking it carries on). A player
## nothing ever edits copies nothing. A stream, a curve or any other resource on a card stays the
## very same resource; only the dictionaries and arrays around it are copied.
func _own_list() -> Array:
	if moment_file != null:
		var carried: Variant = moment_file.get("steps")
		steps.clear()
		if carried is Array:
			for entry: Variant in carried as Array:
				if entry is Dictionary:
					steps.append((entry as Dictionary).duplicate(true))
		moment_file = null
		_owned_steps = steps
		return steps
	if not is_same(_owned_steps, steps):
		for at: int in range(steps.size()):
			steps[at] = (steps[at] as Dictionary).duplicate(true)
		_owned_steps = steps
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
	# A card of your own holds the keys of its own exports and nothing a moment file's step has, so its
	# `seconds` is the one it exports or none at all.
	if step.has("card_script"):
		return step.duplicate()
	var card: Dictionary = {"verb": "", "amount": 1.0, "effect": "", "seconds": 0.0}
	for key: Variant in step:
		card[key] = step[key]
	return card

## Where the head goes when Jump To Juice Card has been asked for: the label's place in the order
## being walked, or where the head was going anyway. Asked once per step, and it reads an empty
## string in every play nobody jumped in.
func _landing(order: Array, index: int) -> int:
	if _jump_to.is_empty():
		return index
	var landed: int = _index_in(order, _jump_to)
	if landed < 0:
		_no_such(_jump_to, "Jump To Juice Card")
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

# @ace_looping(feedback_label)
# @ace_name("For Each Juice Card")
# @ace_description("Runs the actions under it once per juice card in this player's list, top to bottom, with the label of each one in hand.")
# @ace_codegen_template("$JuicePlayer.for_each_feedback()")
## Every label in the list, in order - what For Each Juice Card loops over, and what a settings
## screen that lists a beat's parts is built out of.
func for_each_feedback() -> Array:
	var labels: Array = []
	for entry: Variant in _steps_now():
		if entry is Dictionary:
			labels.append(_label_of(entry as Dictionary))
	return labels

## Says once that a card could not do its work, and tells On Juice Card Skipped why.
func _card_missing(card: Dictionary, reason: String) -> void:
	var label: String = _label_of(card)
	on_feedback_skipped.emit(label, "target missing")
	if _told_cards.has(label):
		return
	_told_cards[label] = true
	push_warning("Juice Player: the card \"%s\" on %s %s, so it did nothing." % [label, name, reason])

## Writes down what a property was, so Restore Initial Values can put it back.
func _remember(object: Object, property: String) -> Variant:
	var before: Variant = object.get_indexed(NodePath(property))
	_keep_first(object, property, before)
	return before

## The number a card's text means: a plain number, or a name read from the game - an autoload and then
## its properties ("GameState.score"), else a property of the object this player is under. Null when
## the text names nothing that holds a number.
func _number_from(text: String) -> Variant:
	var said: String = text.strip_edges()
	if said.is_empty():
		return null
	if said.is_valid_float():
		return said.to_float()
	var parts: PackedStringArray = said.split(".")
	var current: Variant = get_node_or_null("/root/" + parts[0])
	if current == null and host != null:
		current = host.get(parts[0])
	for part: int in range(1, parts.size()):
		if not (current is Object):
			return null
		current = (current as Object).get(parts[part])
	if current is float or current is int:
		return float(current)
	return null

## One world card, done. The words are the ones in WORLD_WORDS; `at` is the strength already multiplied
## by this player's own, and `seconds` the card's length.
func _play_world_card(word: String, card: Dictionary, at: float, seconds: float, skipping: bool = false) -> void:
	match word:
		PARTICLES:
			_particles(card)
		ANIMATION:
			_animation(card, seconds)
		SPRITE_ANIMATION:
			_sprite_animation(card, seconds)
		SHOW_HIDE:
			_show_hide(card, seconds)
		CALL_METHOD:
			_call_method(card)
		SPAWN_SCENE:
			_spawn_scene(card)
		PUSH:
			_push(card, at)
		FORCE_FOR_A_TIME:
			_force_for_a_time(card, seconds)
		GRAVITY_FOR_A_TIME:
			_gravity_for_a_time(card, seconds)
		FREEZE_BODY:
			_freeze_body(card, seconds)
		SQUASH_STRETCH, PUNCH_POSITION, PUNCH_ROTATION:
			_punch_through_juice(word, card, at, seconds)
		POP:
			_pop(card, seconds)
		FADE:
			_fade(card, seconds)
		GRAB_FOCUS:
			_grab_focus(card)
		COUNT_TO:
			_count_to(card, seconds)
		REVEAL_TEXT:
			_reveal_text(card, seconds)
		FILL_BAR:
			_fill_bar(card, seconds)
		SHADER_VALUE:
			_shader_value(card, seconds)
		PAUSE_PLAYER:
			_pause_player(card)
		COLLISION_FOR:
			_collision_for(card, seconds)
		COLLISION_LAYER_FOR:
			_collision_layer_for(card, seconds)
		REMOVE_NODE:
			_remove_node(card, skipping)
		DRAW_ORDER:
			_draw_order(card, seconds)
		SWITCH_NODE:
			_switch_node(card, seconds)
		LOOK_AT:
			_look_at(card, 0.0 if skipping else seconds)
		ROTATE_BY:
			_turn(card, 0.0 if skipping else seconds, true)
		ROTATE_TO:
			_turn(card, 0.0 if skipping else seconds, false)
		ROTATION_SHAKE:
			_rotation_shake(card, at, seconds)
		LIGHT:
			_light(card, at, seconds)
		SCENE_LOOK:
			_scene_look(card, seconds)
		BUS_EFFECT:
			_bus_effect(card, seconds)
		SPRING:
			_spring(card, at)
		SLOW_OBJECT:
			_slow_object(card, seconds)
		ANIMATION_PARAMETER:
			_animation_parameter(card, seconds)

## Restarts, starts or stops a particles node.
func _particles(card: Dictionary) -> void:
	var target: Node = _target(card, "node", false)
	if target == null or not ("emitting" in target):
		_card_missing(card, "points at no particles node")
		return
	_remember(target, "emitting")
	match str(card.get("do", DO_RESTART)):
		DO_STOP:
			target.set("emitting", false)
		DO_START:
			target.set("emitting", true)
		_:
			if target.has_method("restart"):
				target.call("restart")
			target.set("emitting", true)

## Plays a clip of an AnimationPlayer. The card's seconds stretch the clip to that length, so Scale
## Juice Timing speeds an animation up with the rest of the list.
func _animation(card: Dictionary, seconds: float) -> void:
	var target: AnimationPlayer = _target(card, "node", false) as AnimationPlayer
	if target == null:
		_card_missing(card, "points at no animation player")
		return
	var clip_name: String = str(card.get("animation", ""))
	if not target.has_animation(clip_name):
		_card_missing(card, "names the animation \"%s\", which that player does not have" % clip_name)
		return
	var length: float = target.get_animation(clip_name).length
	var speed: float = length / seconds if seconds > 0.0 and length > 0.0 else 1.0
	target.play(clip_name, -1.0, speed)

## Plays an animation of an AnimatedSprite2D or AnimatedSprite3D, stretched to the card's seconds.
func _sprite_animation(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", false)
	var frames: SpriteFrames = target.get("sprite_frames") as SpriteFrames if target != null else null
	if frames == null or not target.has_method("play"):
		_card_missing(card, "points at no animated sprite")
		return
	var clip_name: String = str(card.get("animation", ""))
	if not frames.has_animation(clip_name):
		_card_missing(card, "names the animation \"%s\", which that sprite does not have" % clip_name)
		return
	var length: float = float(frames.get_frame_count(clip_name)) / maxf(frames.get_animation_speed(clip_name), 0.001)
	target.call("play", clip_name, length / seconds if seconds > 0.0 and length > 0.0 else 1.0)

## Shows a node, hides it, or shows it for the card's seconds and hides it again.
func _show_hide(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	if target == null or not ("visible" in target):
		_card_missing(card, "points at no node that can be shown or hidden")
		return
	_remember(target, "visible")
	var word: String = str(card.get("do", DO_FLASH))
	target.set("visible", word != DO_HIDE)
	if word == DO_FLASH:
		get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(func() -> void:
			if is_instance_valid(target):
				target.set("visible", false))

## Calls a method of a node with the values the card holds.
func _call_method(card: Dictionary) -> void:
	var target: Node = _target(card, "node", false)
	var method: String = str(card.get("method", ""))
	if target == null or not target.has_method(method):
		_card_missing(card, "points at no node with a method called \"%s\"" % method)
		return
	var given: Variant = card.get("args", [])
	target.callv(method, given if given is Array else [])

## Adds a copy of a scene to the running scene, at this object or at a node, taking it from the
## object pool when that scene has one.
func _spawn_scene(card: Dictionary) -> void:
	var path: String = str(card.get("scene", ""))
	var scene: PackedScene = load(path) as PackedScene if not path.is_empty() and ResourceLoader.exists(path) else null
	if scene == null:
		_card_missing(card, "names a scene that is not in the project")
		return
	var anchor: Node = _target(card, "node", true) if str(card.get("at", "here")) == "node" else host
	if anchor == null:
		_card_missing(card, "points at no node to drop the scene at")
		return
	var place: Variant = anchor.get("global_position")
	var pool: Node = get_node_or_null("/root/ObjectPool")
	var pooled: String = _pool_named_for(pool, scene)
	if not pooled.is_empty() and place != null:
		pool.call("spawn_safely", pooled, place)
		return
	var made: Node = scene.instantiate()
	var world: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	world.add_child.call_deferred(made)
	if place != null:
		made.set.call_deferred("global_position", place)

## The name of the object pool that holds copies of this scene, or "" when none does.
func _pool_named_for(pool: Node, scene: PackedScene) -> String:
	if pool == null or not pool.has_method("spawn_safely"):
		return ""
	var pools: Variant = pool.get("_pools")
	if not (pools is Dictionary):
		return ""
	for pool_name: Variant in (pools as Dictionary):
		var entry: Variant = (pools as Dictionary)[pool_name]
		if entry is Dictionary and (entry as Dictionary).get("scene") == scene:
			return str(pool_name)
	return ""

## The direction a Push goes, always of length one, or a zero vector when it has none.
func _push_direction(card: Dictionary, body: Node) -> Variant:
	var in_3d: bool = body is Node3D
	match str(card.get("direction", PUSH_AWAY)):
		PUSH_FIXED:
			var fixed: Vector3 = Vector3(float(card.get("x", 0.0)), float(card.get("y", -1.0)), float(card.get("z", 0.0)))
			if in_3d:
				return fixed.normalized()
			return Vector2(fixed.x, fixed.y).normalized()
		PUSH_ALONG:
			var moving: Variant = body.get("linear_velocity")
			if moving == null:
				moving = body.get("velocity")
			if moving is Vector2 or moving is Vector3:
				return moving.normalized()
			return _no_direction(in_3d)
	var from: Variant = body.get("global_position")
	var other: Node = _target(card, "from", false)
	var there: Variant = null
	if other != null:
		there = other.get("global_position")
	if from == null or there == null or typeof(there) != typeof(from):
		return _no_direction(in_3d)
	return (from - there).normalized()

## The direction of a push that has none: a vector of no length, of the kind the body uses.
static func _no_direction(in_3d: bool) -> Variant:
	if in_3d:
		return Vector3.ZERO
	return Vector2.ZERO

## A shove. A RigidBody takes it as an impulse, a CharacterBody has it added to its velocity once and
## carries on moving itself. Anything else is not a body, and the card says so.
func _push(card: Dictionary, at: float) -> void:
	var body: Node = _body_of(card)
	if body == null:
		return
	var speed: float = float(card.get("speed", 300.0)) * (at if bool(card.get("scaled", true)) else 1.0)
	var way: Variant = _push_direction(card, body)
	if body is RigidBody2D:
		(body as RigidBody2D).apply_central_impulse((way as Vector2) * speed * (body as RigidBody2D).mass)
	elif body is RigidBody3D:
		(body as RigidBody3D).apply_central_impulse((way as Vector3) * speed * (body as RigidBody3D).mass)
	elif body is CharacterBody2D:
		(body as CharacterBody2D).velocity += (way as Vector2) * speed
	elif body is CharacterBody3D:
		(body as CharacterBody3D).velocity += (way as Vector3) * speed
	else:
		_card_missing(card, "points at something that is not a physics body")

## A steady force on a RigidBody for a time, taken away again when the time is up or on Restore.
func _force_for_a_time(card: Dictionary, seconds: float) -> void:
	var body: Node = _body_of(card)
	if body == null:
		return
	var force: Variant = Vector3(float(card.get("x", 0.0)), float(card.get("y", -400.0)), float(card.get("z", 0.0)))
	if body is RigidBody2D:
		force = Vector2((force as Vector3).x, (force as Vector3).y)
		(body as RigidBody2D).add_constant_central_force(force)
	elif body is RigidBody3D:
		(body as RigidBody3D).add_constant_central_force(force)
	else:
		_card_missing(card, "points at something that is not a RigidBody")
		return
	var held: Dictionary = {"body": body, "force": force}
	_held_forces.append(held)
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(_release_force.bind(held))

## Takes one held force off its body, once.
func _release_force(held: Dictionary) -> void:
	if not _held_forces.has(held):
		return
	_held_forces.erase(held)
	var body: Object = held.get("body") as Object
	if body == null or not is_instance_valid(body):
		return
	if body is RigidBody2D:
		(body as RigidBody2D).add_constant_central_force(-(held["force"] as Vector2))
	elif body is RigidBody3D:
		(body as RigidBody3D).add_constant_central_force(-(held["force"] as Vector3))

## Takes every held force off, at once.
func _release_forces() -> void:
	for held: Dictionary in _held_forces.duplicate():
		_release_force(held)

## A different gravity scale on a RigidBody for a time, then the one it had.
func _gravity_for_a_time(card: Dictionary, seconds: float) -> void:
	var body: Node = _body_of(card)
	if body == null:
		return
	if not (body is RigidBody2D or body is RigidBody3D):
		_card_missing(card, "points at something that is not a RigidBody")
		return
	var before: Variant = _remember(body, "gravity_scale")
	body.set("gravity_scale", float(card.get("amount", 0.2)))
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.set("gravity_scale", before))

## Holds a RigidBody still for a time. Freezing is not allowed in the middle of a physics step, so it
## is asked for at the end of the frame.
func _freeze_body(card: Dictionary, seconds: float) -> void:
	var body: Node = _body_of(card)
	if body == null:
		return
	if not (body is RigidBody2D or body is RigidBody3D):
		_card_missing(card, "points at something that is not a RigidBody")
		return
	var before: Variant = _remember(body, "freeze")
	body.set_deferred("freeze", true)
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.set_deferred("freeze", before))

## Squash and stretch, a position kick or a rotation kick, done by the Juice node beside this one.
func _punch_through_juice(word: String, card: Dictionary, at: float, seconds: float) -> void:
	var juice: Node = _juice()
	if juice == null:
		return
	match word:
		SQUASH_STRETCH:
			juice.call("squash_and_stretch", float(card.get("amount", 0.3)) * at, seconds)
		PUNCH_POSITION:
			juice.call("punch_position", Vector2(float(card.get("x", 0.0)), float(card.get("y", -10.0))) * at, seconds)
		PUNCH_ROTATION:
			juice.call("punch_rotation", float(card.get("amount", 10.0)) * at, seconds)

## Scales a node up from its middle and lets it settle back.
func _pop(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	if target == null or not ("scale" in target):
		_card_missing(card, "points at no node that can be scaled")
		return
	if target is Control:
		(target as Control).pivot_offset = (target as Control).size / 2.0
	var rest: Variant = _remember(target, "scale")
	var peak: float = float(card.get("amount", 1.3))
	var made: Tween = _new_tween()
	made.tween_property(target, "scale", rest * peak, seconds * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	made.tween_property(target, "scale", rest, seconds * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Fades a node to an alpha through its modulate.
func _fade(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	if not (target is CanvasItem):
		_card_missing(card, "points at no node that can be faded")
		return
	_remember(target, "modulate")
	_new_tween().tween_property(target, "modulate:a", float(card.get("amount", 0.0)), seconds)

## Gives a Control the keyboard and gamepad focus.
func _grab_focus(card: Dictionary) -> void:
	var target: Control = _target(card, "node", false) as Control
	if target == null:
		_card_missing(card, "points at no control")
		return
	target.grab_focus()

## A label counts from the number it shows to a number.
func _count_to(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", false)
	var goal: Variant = _number_from(str(card.get("to", "")))
	if target == null or not ("text" in target):
		_card_missing(card, "points at no label")
		return
	if goal == null:
		_card_missing(card, "names a number that is not there (\"%s\")" % str(card.get("to", "")))
		return
	_remember(target, "text")
	var shown: String = str(target.get("text")).strip_edges()
	var from: float = shown.to_float() if shown.is_valid_float() else 0.0
	_new_tween().tween_method(func(value: float) -> void:
		if is_instance_valid(target):
			target.set("text", str(int(round(value)))), from, float(goal), seconds)

## The letters of a label appear one after another over the card's seconds.
func _reveal_text(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", false)
	if target == null or not ("visible_ratio" in target):
		_card_missing(card, "points at no label")
		return
	_remember(target, "visible_ratio")
	target.set("visible_ratio", 0.0)
	# A card that holds a speed (letters a second) reveals the text the label holds right now at that
	# speed; a card with only seconds takes exactly that long.
	var span: float = seconds
	var speed: float = float(card.get("speed", 0.0))
	if speed > 0.0:
		span = float(str(target.get("text")).length()) / speed
	_new_tween().tween_property(target, "visible_ratio", 1.0, span)

## A bar or slider glides to a number.
func _fill_bar(card: Dictionary, seconds: float) -> void:
	var target: Range = _target(card, "node", false) as Range
	var goal: Variant = _number_from(str(card.get("to", "")))
	if target == null:
		_card_missing(card, "points at no bar")
		return
	if goal == null:
		_card_missing(card, "names a number that is not there (\"%s\")" % str(card.get("to", "")))
		return
	_remember(target, "value")
	_new_tween().tween_property(target, "value", float(goal), seconds)

## Moves one value of the shader on a node. With "only this object" on, the node gets a copy of its
## material to itself first, so the others that share the file are left alone; Restore gives the node
## its own material back.
func _shader_value(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	var shared: ShaderMaterial = _shader_material_of(target) if target != null else null
	var value_name: String = str(card.get("parameter", ""))
	if shared == null or shared.shader == null or value_name.is_empty():
		_card_missing(card, "points at no node with a shader to move")
		return
	var material: ShaderMaterial = shared
	if bool(card.get("only_this", true)):
		var key: int = target.get_instance_id()
		if not _own_materials.has(key) or not is_instance_valid(_own_materials[key]):
			_own_materials[key] = shared.duplicate()
			var slot: String = "material" if target is CanvasItem else "material_override"
			_remember(target, slot)
			target.set(slot, _own_materials[key])
		material = _own_materials[key]
	var property: String = "shader_parameter/" + value_name
	var before: Variant = material.get_shader_parameter(value_name)
	if before == null:
		before = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), value_name)
	if before == null:
		_card_missing(card, "names the shader value \"%s\", which that shader does not declare" % value_name)
		return
	_keep_first(material, property, before)
	var goal: Variant = card.get("to", before)
	var made: Tween = _new_tween()
	var way: Tween = made.set_trans(TRANSITIONS.get(str(card.get("trans", "sine")), Tween.TRANS_SINE) as Tween.TransitionType)
	if bool(card.get("back", false)):
		way.tween_property(material, property, goal, seconds * 0.5)
		way.tween_property(material, property, before, seconds * 0.5)
	else:
		way.tween_property(material, property, goal, seconds)

## A property of a node walked to a value, the whole card: any node, a typed value, where it starts,
## its transition and ease, and whether it comes back. Cards that hold none of these keys never reach
## here and play exactly as they always did.
func _tween_card(card: Dictionary, at: float, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	var property: String = str(card.get("effect", "")).strip_edges()
	if target == null:
		_card_missing(card, "points at a node that is not there")
		return
	if property.is_empty():
		return
	var before: Variant = target.get_indexed(NodePath(property))
	if before == null:
		_card_missing(card, "points at %s, which has no property called \"%s\"" % [target.name, property])
		return
	_keep_first(target, property, before)
	var goal: Variant = card.get("to", float(card.get("amount", 1.0)))
	var relative: bool = bool(card.get("relative", false))
	# A number is scaled by the strength of the play, as the one-number tween always was; a colour or a
	# position is a place, not an amount, so only a value added to what is there is scaled.
	if goal is float or goal is int or (relative and (goal is Vector2 or goal is Vector3)):
		goal = goal * at
	if card.has("from"):
		target.set_indexed(NodePath(property), card["from"])
	var made: Tween = _new_tween()
	var shaped: Tween = made.set_trans(TRANSITIONS.get(str(card.get("trans", "linear")), Tween.TRANS_LINEAR) as Tween.TransitionType)
	shaped.set_ease(EASES.get(str(card.get("ease", "in_out")), Tween.EASE_IN_OUT) as Tween.EaseType)
	var there: PropertyTweener = shaped.tween_property(target, NodePath(property), goal, seconds * (0.5 if bool(card.get("back", false)) else 1.0))
	if relative:
		there.as_relative()
	if bool(card.get("back", false)):
		shaped.tween_property(target, NodePath(property), before, seconds * 0.5)

## Whether a Tween Property card holds any of the keys that make it the whole card. A card that holds
## none of them is the one-number tween on this object it has always been.
static func _is_whole_tween(card: Dictionary) -> bool:
	for key: String in ["node", "to", "from", "trans", "ease", "relative", "back"]:
		if card.has(key):
			return true
	return false

## Whether the card names a node under this key at all.
static func _names_a_node(card: Dictionary, key: String) -> bool:
	return not _path_of(card, key).is_empty()

## Fires a signal of a node, with the values the card holds.
func _emit_on_node(card: Dictionary) -> void:
	var target: Node = _target(card, "node", false)
	var wanted: String = str(card.get("signal", ""))
	if target == null or not target.has_signal(wanted):
		_card_missing(card, "points at no node with a signal called \"%s\"" % wanted)
		return
	var given: Variant = card.get("args", [])
	target.callv("emit_signal", [wanted] + (given as Array if given is Array else []))

## Whether `from` is playing, through the players it started, the one named `wanted`. The depth is a
## guard against a ring of players that has no end.
static func _plays_through(from: Node, wanted: Node, depth: int) -> bool:
	if depth > 8 or from.get("playing") != true:
		return false
	var started: Variant = from.get("_nested")
	if not (started is Array):
		return false
	for other: Variant in (started as Array):
		if other == wanted or (other is Node and _plays_through(other as Node, wanted, depth + 1)):
			return true
	return false

## Changes one property of an object, and says which hold it is. The first hold on a property writes down what it was
## (the way back goes there, and so does Restore); later holds on the same property only add themselves. `layer` is 0
## for a whole property, or a layer number from 1 to 32 when the thing held is one layer or one mask bit. `deferred`
## writes at the safe moment, which Godot asks for on a shape, a layer and a mask.
func _hold(target: Object, property: String, value: Variant, deferred: bool = false, layer: int = 0) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {}
	var key: String = "%d|%s|%d" % [target.get_instance_id(), property, layer]
	var hold: Dictionary = _holds.get(key, {})
	var first_value: Variant = target.get(property)
	if hold.is_empty():
		var before: Variant = first_value
		if layer > 0:
			before = bool(target.call("get_%s_value" % property, layer))
		hold = {"object": target, "property": property, "layer": layer, "deferred": deferred, "before": before, "tickets": []}
		_holds[key] = hold
	elif layer == 0:
		first_value = hold["before"]
	_keep_first(target, property, first_value)
	_next_hold += 1
	(hold["tickets"] as Array).append({"id": _next_hold, "owner": get_instance_id()})
	_put(hold, value)
	return {"key": key, "ticket": _next_hold}

## Writes a value to the object a hold is on: the whole property, or one layer of it.
static func _put(hold: Dictionary, value: Variant) -> void:
	var object: Object = hold["object"] as Object
	var property: String = str(hold["property"])
	if int(hold["layer"]) > 0:
		object.call_deferred("set_%s_value" % property, int(hold["layer"]), bool(value))
	elif bool(hold["deferred"]):
		object.set_deferred(property, value)
	else:
		object.set(property, value)

## Holds a property for `seconds` and then lets it go. With no scene tree to count the time in, the hold is let go at
## once.
func _hold_for(target: Object, property: String, value: Variant, seconds: float, deferred: bool = false, layer: int = 0) -> void:
	var ticket: Dictionary = _hold(target, property, value, deferred, layer)
	if ticket.is_empty():
		return
	if not is_inside_tree():
		_end_hold(ticket)
		return
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(_end_hold.bind(ticket))

## Lets one hold go. When it was the last on its property, the property goes back to what it was before the first.
static func _end_hold(ticket: Dictionary) -> void:
	var key: String = str(ticket.get("key", ""))
	var held: Dictionary = _holds.get(key, {})
	if held.is_empty():
		return
	var tickets: Array = held["tickets"]
	for index: int in range(tickets.size()):
		if int((tickets[index] as Dictionary)["id"]) == int(ticket.get("ticket", 0)):
			tickets.remove_at(index)
			break
	if not tickets.is_empty():
		return
	_holds.erase(key)
	_give_back(held)

## Puts a held property back to what it was before the first card, unless the object is gone.
static func _give_back(held: Dictionary) -> void:
	var object: Object = held.get("object") as Object
	if object != null and is_instance_valid(object):
		_put(held, held["before"])

## Lets every hold of THIS player go at once, which is what Stop, Restore and leaving the scene do. A thing another
## player is still holding stays held until that one lets go.
func _release_holds() -> void:
	var mine: int = get_instance_id()
	for key: String in _holds.keys():
		var held: Dictionary = _holds[key]
		var tickets: Array = held["tickets"]
		var before: int = tickets.size()
		for index: int in range(tickets.size() - 1, -1, -1):
			if int((tickets[index] as Dictionary)["owner"]) == mine:
				tickets.remove_at(index)
		if before > 0 and tickets.is_empty():
			_holds.erase(key)
			_give_back(held)

## Keeps a way back for a change no node holds, and takes it when the time is up. With no scene tree to count in, it
## is taken at once.
func _way_back_in(seconds: float, back: Callable) -> void:
	_ways_back.append(back)
	if not is_inside_tree():
		_take_way_back(back)
		return
	get_tree().create_timer(maxf(seconds, 0.0)).timeout.connect(_take_way_back.bind(back))

## Takes one way back, once.
func _take_way_back(back: Callable) -> void:
	if not _ways_back.has(back):
		return
	_ways_back.erase(back)
	if back.is_valid():
		back.call()

## Takes every way back at once.
func _take_ways_back() -> void:
	for back: Callable in _ways_back.duplicate():
		_take_way_back(back)

## Whether a node is a collision shape or a collision polygon, in 2D or in 3D.
static func _is_shape(node: Node) -> bool:
	for named: String in SHAPE_CLASSES:
		if node.is_class(named):
			return true
	return false

## Switches a collision shape off for a time. Godot refuses a shape's disabled tick in the middle of a physics step,
## so it is changed at the safe moment, both ways.
func _collision_for(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", false)
	if target == null or not _is_shape(target):
		_card_missing(card, "points at no collision shape")
		return
	_hold_for(target, "disabled", true, seconds, true)

## Changes one layer of what a body is on, or of what it sees, for a time. Both are changed at the safe moment, so a
## card played from a collision is safe.
func _collision_layer_for(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", false)
	if target == null or not (target is CollisionObject2D or target is CollisionObject3D):
		_card_missing(card, "points at no body or area")
		return
	var part: String = "collision_layer" if str(card.get("part", "mask")) == "layer" else "collision_mask"
	_hold_for(target, part, bool(card.get("on", false)), seconds, true, clampi(int(card.get("layer", 1)), 1, 32))

## Removes a node: handed back to its object pool when it came from one, freed when it did not. With "after this list
## ends" it waits for the list, so the sound and the particles of a death are not cut off with it; a node that holds
## this player waits whatever the tick says, because freeing it would end the list.
func _remove_node(card: Dictionary, skipping: bool) -> void:
	var target: Node = _target(card, "node", true)
	if target == null:
		_card_missing(card, "points at a node that is not there")
		return
	var holds_this_player: bool = target == self or target.is_ancestor_of(self)
	if skipping or not playing or not (bool(card.get("after_list", true)) or holds_this_player):
		_retire(target)
	elif not _removals.has(target):
		_removals.append(target)

## Hands a node back to its pool, or frees it, through the file that decides which.
func _retire(target: Node) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var pool: String = "res://eventsheet_addons/pooled_nodes.gd"
	if ResourceLoader.exists(pool):
		(load(pool) as Script).call("retire", target)
	else:
		target.queue_free()

## Removes the nodes that waited for the end of the list.
func _remove_waiting() -> void:
	var waiting: Array[Node] = _removals.duplicate()
	_removals.clear()
	for target: Node in waiting:
		_retire(target)

## Draws a 2D node in front of the rest, or behind it, for a time. Godot refuses a z index past 4096, so the number
## is held inside it.
func _draw_order(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	if not (target is CanvasItem):
		_card_missing(card, "points at no 2D node, and a 3D node is drawn by its distance from the camera")
		return
	_hold_for(target, "z_index", clampi(int(card.get("z_index", 10)), -MOST_Z_INDEX, MOST_Z_INDEX), seconds)

## Switches a node off in the three ways Godot has, each its own tick: hidden, not processing, and its collision
## shapes disabled. For a time, or until a card switches it on again.
func _switch_node(card: Dictionary, seconds: float) -> void:
	var target: Node = _target(card, "node", true)
	if target == null:
		_card_missing(card, "points at a node that is not there")
		return
	var word: String = str(card.get("do", "for_a_time"))
	var off: bool = word != "on"
	var timed: bool = word == "for_a_time"
	var done: bool = false
	if bool(card.get("visible", true)) and "visible" in target:
		_switch_property(target, "visible", not off, timed, seconds, false)
		done = true
	if bool(card.get("process", true)):
		_switch_property(target, "process_mode", Node.PROCESS_MODE_DISABLED if off else Node.PROCESS_MODE_INHERIT, timed, seconds, false)
		done = true
	if bool(card.get("collision", false)):
		for shape: Node in _shapes_under(target):
			_switch_property(shape, "disabled", off, timed, seconds, true)
			done = true
	if not done:
		_card_missing(card, "has nothing ticked to switch")

## One property of a switched node: held for a time, or written for good with Restore able to undo it.
func _switch_property(target: Object, property: String, value: Variant, timed: bool, seconds: float, deferred: bool) -> void:
	if timed:
		_hold_for(target, property, value, seconds, deferred)
		return
	_keep_first(target, property, target.get(property))
	if deferred:
		target.set_deferred(property, value)
	else:
		target.set(property, value)

## Whether a card turns a node that the physics engine owns. Turning one fights the engine, so the card says where to
## point it instead.
func _refuses_turning(card: Dictionary, node: Node) -> bool:
	if node is RigidBody2D or node is RigidBody3D:
		_card_missing(card, "points at a RigidBody, which the physics engine turns (point it at the sprite or mesh under the body instead)")
		return true
	return false

## The property a turn writes: a 2D node and a Control turn by `rotation`, a 3D node about its up axis.
static func _turn_path(node: Node) -> String:
	return "rotation:y" if node is Node3D else "rotation"

## Whether a node can be turned by this card at all.
static func _can_turn(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control

## Turns a node by an angle or to one, over a time. A Control turns about its middle. What the angle was is written
## down, so Restore turns it back.
func _turn(card: Dictionary, seconds: float, by: bool) -> void:
	var node: Node = _target(card, "node", true)
	if node == null or not _can_turn(node):
		_card_missing(card, "points at no node that can be turned")
		return
	if _refuses_turning(card, node):
		return
	var path: NodePath = NodePath(_turn_path(node))
	var now: float = float(node.get_indexed(path))
	var wanted: float = deg_to_rad(float(card.get("degrees", 45.0 if by else 90.0)))
	var goal: float = now + wanted if by else now + angle_difference(now, wanted)
	_keep_first(node, "rotation", node.get("rotation"))
	if node is Control:
		_keep_first(node, "pivot_offset", (node as Control).pivot_offset)
		(node as Control).pivot_offset = (node as Control).size / 2.0
	if seconds <= 0.0:
		node.set_indexed(path, goal)
		return
	_new_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(node, path, goal, seconds)

## Turns a node to face another node, over a time: in 2D the angle that points its right at it, in 3D the way the
## engine's own look at turns it, with the head up. A node at the same place has nothing to face, and a target
## straight above looks along the forward axis instead of flipping.
func _look_at(card: Dictionary, seconds: float) -> void:
	var node: Node = _target(card, "node", true)
	var goal: Node = _target(card, "target", false)
	if node == null or goal == null:
		_card_missing(card, "points at a node or a target that is not there")
		return
	if _refuses_turning(card, node):
		return
	if node is Node2D and goal is Node2D:
		var from: Node2D = node as Node2D
		var offset: Vector2 = (goal as Node2D).global_position - from.global_position
		if offset.length() < 0.001:
			_card_missing(card, "is at the same place as its target (there is nothing to face)")
			return
		var wanted: float = from.global_rotation + angle_difference(from.global_rotation, offset.angle())
		_keep_first(from, "rotation", from.rotation)
		if seconds <= 0.0:
			from.global_rotation = wanted
			return
		_new_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(from, NodePath("global_rotation"), wanted, seconds)
	elif node is Node3D and goal is Node3D:
		var here: Node3D = node as Node3D
		var start: Vector3 = here.global_position
		var end: Vector3 = (goal as Node3D).global_position
		if start.distance_to(end) < 0.001:
			_card_missing(card, "is at the same place as its target (there is nothing to face)")
			return
		var up: Vector3 = Vector3.UP
		if absf((end - start).normalized().dot(Vector3.UP)) > 0.999:
			up = Vector3.FORWARD
		var goal_turn: Quaternion = Transform3D(Basis(), start).looking_at(end, up).basis.get_rotation_quaternion()
		_keep_first(here, "rotation", here.rotation)
		if seconds <= 0.0:
			_turn_towards(1.0, here, here.global_transform.basis.get_rotation_quaternion(), goal_turn)
			return
		_new_tween().tween_method(_turn_towards.bind(here, here.global_transform.basis.get_rotation_quaternion(), goal_turn), 0.0, 1.0, seconds)
	else:
		_card_missing(card, "and its target are not both 2D nodes or both 3D nodes")

## One step of a 3D turn: the node's angle `through` of the way from where it was to where it faces, keeping its size
## and its place.
func _turn_towards(through: float, node: Node3D, from_turn: Quaternion, goal_turn: Quaternion) -> void:
	if not is_instance_valid(node):
		return
	var now: Transform3D = node.global_transform
	node.global_transform = Transform3D(Basis(from_turn.slerp(goal_turn, through)).scaled(now.basis.get_scale()), now.origin)

## Wobbles the angle of a node and settles it, with the same fade ticks and curve a Shake card has. The angle it had
## is written back at the end, whatever the last step was.
func _rotation_shake(card: Dictionary, at: float, seconds: float) -> void:
	var node: Node = _target(card, "node", true)
	if node == null or not _can_turn(node):
		_card_missing(card, "points at no node that can be turned")
		return
	if _refuses_turning(card, node):
		return
	var path: NodePath = NodePath(_turn_path(node))
	var rest: float = float(node.get_indexed(path))
	_hold_for(node, "rotation", node.get("rotation"), seconds)
	var curve: Curve = null
	var kept: String = str(card.get("curve", "")).strip_edges()
	if not kept.is_empty() and ResourceLoader.exists(kept):
		curve = load(kept) as Curve
	var radians: float = deg_to_rad(float(card.get("degrees", 10.0))) * at
	_new_tween().tween_method(_shake_turn.bind(node, path, rest, radians, maxf(seconds, 0.001), bool(card.get("fade_in", false)), bool(card.get("fade_out", true)), curve), 0.0, 1.0, maxf(seconds, 0.001))

## One step of a rotation shake: the angle at rest plus a swing the shape of the shake makes smaller or larger. The
## last step is the rest itself.
func _shake_turn(through: float, node: Node, path: NodePath, rest: float, radians: float, span: float, fade_in: bool, fade_out: bool, curve: Curve) -> void:
	if not is_instance_valid(node):
		return
	if through >= 1.0:
		node.set_indexed(path, rest)
		return
	node.set_indexed(path, rest + radians * MomentRunner.shake_shape(through, fade_in, fade_out, curve) * sin(through * span * TAU * SHAKE_HERTZ))

# @ace_hidden
## The three names a light answers to: how bright it is, what colour it is, and what switches it on and off. A 2D
## light says energy, color and enabled; a 3D light says light_energy, light_color and visible. Empty for a node that
## is no light.
static func light_properties(light: Node) -> Dictionary:
	if light is Light2D:
		return {"energy": "energy", "colour": "color", "on": "enabled"}
	if light is Light3D:
		return {"energy": "light_energy", "colour": "light_color", "on": "visible"}
	return {}

## Flares a light to a brightness and a colour over a time, and lets it go back by itself. A light that was off is
## switched on for the flare and off again after. Stop leaves it where it got to; Restore puts it back.
func _light(card: Dictionary, at: float, seconds: float) -> void:
	var light: Node = _target(card, "node", true)
	var names: Dictionary = light_properties(light) if light != null else {}
	if names.is_empty():
		_card_missing(card, "points at no light")
		return
	var energy: String = str(names["energy"])
	var colour: String = str(names["colour"])
	var rest_energy: float = float(light.get(energy))
	var rest_colour: Color = light.get(colour)
	_keep_first(light, energy, rest_energy)
	_keep_first(light, colour, rest_colour)
	var peak: float = rest_energy + (float(card.get("energy_to", 3.0)) - rest_energy) * at
	var tint: Color = rest_colour.lerp(_colour_of(card.get("colour_to", Color(1.0, 0.6, 0.2))), clampf(at, 0.0, 1.0))
	# A card that names no start begins where the light is now, as every card did before it could.
	if card.has("energy_from"):
		light.set(energy, float(card["energy_from"]))
	if card.has("colour_from"):
		light.set(colour, _colour_of(card["colour_from"]))
	var goes_back: bool = bool(card.get("back", true))
	var back_seconds: float = maxf(float(card.get("back_seconds", 0.2)), 0.0)
	if not bool(light.get(str(names["on"]))):
		if goes_back:
			_hold_for(light, str(names["on"]), true, seconds + back_seconds)
		else:
			light.set(str(names["on"]), true)
	var made: Tween = _new_tween().set_parallel(true)
	_eased(made, str(card.get("ease", "out")))
	made.tween_property(light, NodePath(energy), peak, seconds)
	made.tween_property(light, NodePath(colour), tint, seconds)
	if goes_back:
		made.chain().tween_property(light, NodePath(energy), rest_energy, back_seconds)
		made.tween_property(light, NodePath(colour), rest_colour, back_seconds)
		made.finished.connect(_forget_flare.bind(_note_flare(light, energy, colour, rest_energy, rest_colour)))

# @ace_hidden
## Writes down a light that is flaring and will go back by itself, so a player that goes away before the flare is
## over can put it back. Gives the note, which is what ends it.
func _note_flare(light: Node, energy: String, colour: String, rest_energy: float, rest_colour: Color) -> Dictionary:
	var flare: Dictionary = {"light": light, "energy": energy, "colour": colour, "rest_energy": rest_energy, "rest_colour": rest_colour}
	_flares.append(flare)
	return flare

## A flare ran its whole way: there is nothing to put back.
func _forget_flare(flare: Dictionary) -> void:
	_flares.erase(flare)

## Puts every light that is still flaring back to what it rested at, the way the other cards put their own back when
## the player goes away. A Stop does not come here: it leaves a light where it got to.
func _put_flares_back() -> void:
	for flare: Dictionary in _flares:
		var light: Object = flare.get("light") as Object
		if light != null and is_instance_valid(light):
			light.set(str(flare["energy"]), flare["rest_energy"])
			light.set(str(flare["colour"]), flare["rest_colour"])
	_flares.clear()

## The curve of a tween: the words a card keeps, as Godot's transition and ease.
func _eased(made: Tween, word: String) -> void:
	match word:
		"linear":
			made.set_trans(Tween.TRANS_LINEAR)
		"in":
			made.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		"in_out":
			made.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			made.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## A colour from what a card keeps: a colour, or the text of one.
static func _colour_of(value: Variant) -> Color:
	return value as Color if value is Color else Color(str(value))

# @ace_hidden
## The switch a value of the look does nothing without, or an empty word when it needs none.
static func look_switch_of(property: String) -> String:
	for entry: Array in LOOK_SWITCHES:
		if property.begins_with(str(entry[0])):
			return str(entry[1])
	return ""

## The resources a node holds a look in, as the members that hold them.
static func _look_members(holder: Node) -> PackedStringArray:
	if holder is WorldEnvironment:
		return PackedStringArray(["environment", "camera_attributes"])
	if holder is Camera3D:
		return PackedStringArray(["environment", "attributes"])
	return PackedStringArray()

## Moves one value of the scene's look to a number and back, on the scene's OWN copy of it. An Environment is a file
## many scenes share, so the first change gives this scene a copy; the file is never written and the original is put
## back when the time is up, on Stop and on Restore.
func _scene_look(card: Dictionary, seconds: float) -> void:
	var holder: Node = _look_holder(card)
	var property: String = str(card.get("property", "glow_intensity"))
	var resource: Resource = null
	var members: PackedStringArray = _look_members(holder) if holder != null else PackedStringArray()
	for named: String in members:
		var held: Resource = holder.get(named) as Resource
		var probe: Resource = held
		if probe == null:
			if named == "environment":
				probe = Environment.new()
			else:
				probe = CameraAttributesPractical.new()
		if property in probe:
			resource = probe
			if held == null or not held.resource_path.is_empty():
				resource = probe.duplicate() if held != null else probe
				_hold_for(holder, named, resource, seconds + maxf(float(card.get("back_seconds", 0.3)), 0.0))
			break
	if resource == null:
		_card_missing(card, "finds no look in this scene with a value called \"%s\"" % property)
		return
	var back_seconds: float = maxf(float(card.get("back_seconds", 0.3)), 0.0)
	var before: Variant = resource.get(property)
	var switch: String = look_switch_of(property)
	_hold_for(resource, property, before, seconds + back_seconds)
	if not switch.is_empty() and switch in resource and not bool(resource.get(switch)):
		_hold_for(resource, switch, true, seconds + back_seconds)
	var made: Tween = _new_tween()
	made.tween_property(resource, NodePath(property), card.get("to", before), seconds)
	made.tween_property(resource, NodePath(property), before, back_seconds)

## Holds an effect of an audio bus for a time: switches one that is already on the bus on, or muffles, dives or
## washes the bus through the effect that does it, and puts it back by itself. An effect the bus lacks is added at
## its END, which moves none of the others, and is taken off again when the way back is done.
func _bus_effect(card: Dictionary, seconds: float) -> void:
	var bus: String = str(card.get("bus", "Master"))
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		_card_missing(card, "names the bus \"%s\", which this project does not have" % bus)
		return
	var how: String = str(card.get("how", "muffle"))
	var back_seconds: float = maxf(float(card.get("back_seconds", 0.2)), 0.0)
	if how == "switch":
		var slot: int = int(card.get("slot", 0))
		if slot < 0 or slot >= AudioServer.get_bus_effect_count(index):
			_card_missing(card, "names effect %d on the bus %s, which has %d" % [slot, bus, AudioServer.get_bus_effect_count(index)])
			return
		var was_on: bool = AudioServer.is_bus_effect_enabled(index, slot)
		AudioServer.set_bus_effect_enabled(index, slot, true)
		_way_back_in(seconds, AudioServer.set_bus_effect_enabled.bind(index, slot, was_on))
		return
	var mix: Script = _bus_mix()
	if mix == null or not is_inside_tree():
		_card_missing(card, "needs the bus mix file of the project")
		return
	var wanted: float = bus_value_for(how, float(card.get("to", 400.0)))
	var resting: float = float(mix.call("read", bus, how))
	_bus_hold(bus, how)
	mix.call("sweep", get_tree().root, bus, how, wanted, 0.0)
	_way_back_in(seconds, _sweep_back.bind(bus, how, resting, back_seconds))

## Walks a bus back to where one kind of effect rested, on the root of the tree, which no scene change can free.
## When this card added the effect, the last card to give it back takes it off the bus once the walk is done.
func _sweep_back(bus: String, how: String, resting: float, over: float) -> void:
	var mix: Script = _bus_mix()
	if mix != null and is_inside_tree():
		mix.call("sweep", get_tree().root, bus, how, resting, over)
	if not _added_effects.has(bus + "|" + how):
		return
	if over <= 0.0 or not is_inside_tree():
		_bus_let_go(bus, how)
	else:
		get_tree().create_timer(over).timeout.connect(Callable(get_script(), "_bus_let_go").bind(bus, how))

## Takes one card's hold of the effect a way of changing a bus runs through. An effect the bus lacks is added at its
## end for the card, and taken off again by the last card to let go.
static func _bus_hold(bus: String, how: String) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var key: String = bus + "|" + how
	if not _added_effects.has(key) and not _bus_has_kind(index, how):
		_added_effects[key] = {"effect": null, "holds": 0}
	var mix: Script = _bus_mix()
	if mix != null:
		mix.call("arm", bus, how)
	if _added_effects.has(key):
		var added: Dictionary = _added_effects[key]
		if added["effect"] == null:
			added["effect"] = _last_bus_effect_of(index, how)
		added["holds"] = int(added["holds"]) + 1

## Whether a bus carries an effect of the kind a way of changing it uses.
static func _bus_has_kind(index: int, how: String) -> bool:
	return _last_bus_effect_of(index, how) != null

## Gives back one card's hold of an effect it added. The last card to let go takes the effect off the bus and forgets
## where the bus rested, so the layout ends as it began.
static func _bus_let_go(bus: String, how: String) -> void:
	var key: String = bus + "|" + how
	var added: Dictionary = _added_effects.get(key, {})
	if added.is_empty():
		return
	added["holds"] = int(added["holds"]) - 1
	if int(added["holds"]) > 0:
		return
	_added_effects.erase(key)
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0 and added["effect"] != null:
		for slot: int in range(AudioServer.get_bus_effect_count(index)):
			if AudioServer.get_bus_effect(index, slot) == added["effect"]:
				AudioServer.remove_bus_effect(index, slot)
				break
	var mix: Script = _bus_mix()
	var book: StringName = mix.get_script_constant_map().get("RESTING_META", &"") if mix != null else &""
	if book != &"" and Engine.has_meta(book):
		var resting: Dictionary = Engine.get_meta(book)
		var per_bus: Dictionary = resting.get(bus, {})
		per_bus.erase(how)
		if per_bus.is_empty():
			resting.erase(bus)

## Slows the animations and particles under a node for a time, and puts their speed back. A node of your own code has
## no speed to slow, and Godot has nothing to slow it with. The speed is the node's own, which multiplies with the
## game's time scale.
func _slow_object(card: Dictionary, seconds: float) -> void:
	var root: Node = _target(card, "node", true)
	var found: Array[Node] = speed_nodes_under(root)
	if found.is_empty():
		_card_missing(card, "finds nothing under %s that has a speed to slow" % (str(root.name) if root != null else "it"))
		return
	for node: Node in found:
		_hold_for(node, "speed_scale", maxf(float(card.get("speed", 0.3)), 0.0), seconds)

# @ace_hidden
## A kick in the kind of value the property holds: what a card keeps, made a number, two or three numbers or a colour,
## and scaled by the strength of the play.
static func spring_kick(amount: Variant, current: Variant, at: float) -> Variant:
	var number: float = 1.0
	if amount is float or amount is int:
		number = float(amount)
	elif amount is Vector2:
		number = (amount as Vector2).x
	elif amount is Vector3:
		number = (amount as Vector3).x
	elif amount is Color:
		number = (amount as Color).r
	match typeof(current):
		TYPE_VECTOR2:
			return (amount as Vector2 if amount is Vector2 else Vector2(number, number)) * at
		TYPE_VECTOR3:
			return (amount as Vector3 if amount is Vector3 else Vector3(number, number, number)) * at
		TYPE_COLOR:
			return (amount as Color if amount is Color else Color(number, number, number, number)) * at
	return number * at

## Kicks a value of a 2D node and lets its Spring node settle it. The Spring node moves it back to where it rested, so
## nothing is left changed; a Stop settles it at once, and Restore puts back the value from before the card.
func _spring(card: Dictionary, at: float) -> void:
	var target: Node = _target(card, "node", true)
	if not (target is Node2D):
		_card_missing(card, "points at a node a Spring node cannot move, which has to be a 2D node")
		return
	var spring: Node = spring_of(target)
	if spring == null:
		_card_missing(card, "finds no Spring node under %s" % target.name)
		return
	var property: String = str(card.get("property", "scale"))
	var current: Variant = target.get_indexed(NodePath(property))
	if not [TYPE_FLOAT, TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR].has(typeof(current)):
		_card_missing(card, "springs %s, which is not a number, a Vector2, a Vector3 or a colour" % property)
		return
	if card.has("damping") or card.has("frequency"):
		var damping: float = float(card.get("damping", spring.get("default_damping")))
		var frequency: float = float(card.get("frequency", sqrt(float(spring.get("default_stiffness"))) / TAU))
		spring.call("set_property_spring", property, damping, frequency)
	_keep_first(target, property, current)
	spring.call("bump_property", property, spring_kick(card.get("kick"), current, at))
	var key: String = "%d|%s" % [spring.get_instance_id(), property]
	if _springs_moving.has(key):
		_ways_back.erase(_springs_moving[key])
	var settle: Callable = _spring_rest.bind(spring, target, property)
	_springs_moving[key] = settle
	_ways_back.append(settle)
	var landed: Callable = _spring_landed.bind(spring)
	if not spring.is_connected("spring_reached", landed):
		spring.connect("spring_reached", landed)

## Settles a spring at the value it rests on, at once: what a Stop does to a spring that is still bouncing.
func _spring_rest(spring: Node, target: Node, property: String) -> void:
	if spring == null or not is_instance_valid(spring):
		return
	var entry: Variant = (spring.get("property_springs") as Dictionary).get(property)
	if entry == null:
		return
	entry.set("active", false)
	entry.set("velocity", Vector4.ZERO)
	entry.set("value", entry.get("target"))
	if target != null and is_instance_valid(target):
		target.set_indexed(NodePath(property), entry.call("unpack"))

## A spring landed by itself: there is nothing left for a Stop to settle.
func _spring_landed(landed: String, spring: Node) -> void:
	var key: String = "%d|%s" % [spring.get_instance_id(), landed]
	if _springs_moving.has(key):
		_ways_back.erase(_springs_moving[key])
		_springs_moving.erase(key)

# @ace_hidden
## The parameters of an AnimationTree a card may move: numbers, whole numbers, ticks and a Vector2 that are not read-only,
## and not the playback object of a state machine or the timers a one-shot keeps for itself.
static func writable_parameters(tree: AnimationTree) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if tree == null:
		return found
	for entry: Dictionary in tree.get_property_list():
		var named: String = str(entry.get("name", ""))
		if not named.begins_with("parameters/") or (int(entry.get("usage", 0)) & PROPERTY_USAGE_READ_ONLY) != 0:
			continue
		if not [TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_VECTOR2].has(int(entry.get("type", TYPE_NIL))):
			continue
		if not TREE_BOOKKEEPING.has(named.get_file()):
			found.append(named)
	return found

## Moves one parameter of an AnimationTree to a value over a time and brings it back. A number or a vector is walked; a
## tick or a whole number is set and put back when the time is up. Stop leaves it where it got to, Restore puts it back.
func _animation_parameter(card: Dictionary, seconds: float) -> void:
	var tree: AnimationTree = _target(card, "node", false) as AnimationTree
	var parameter: String = str(card.get("parameter", ""))
	if tree == null:
		_card_missing(card, "points at no animation tree")
		return
	if not writable_parameters(tree).has(parameter):
		_card_missing(card, "names the parameter \"%s\", which this tree has no writable parameter of" % parameter)
		return
	var rest: Variant = tree.get(parameter)
	_keep_first(tree, parameter, rest)
	var goes_back: bool = bool(card.get("back", true))
	var back_seconds: float = maxf(float(card.get("back_seconds", 0.2)), 0.0)
	var wanted: Variant = card.get("to", rest)
	match typeof(rest):
		TYPE_BOOL:
			wanted = bool(wanted)
		TYPE_INT:
			wanted = int(wanted)
		TYPE_VECTOR2:
			wanted = wanted as Vector2 if wanted is Vector2 else Vector2(float(wanted), float(wanted))
		_:
			wanted = float(wanted)
	if typeof(rest) == TYPE_BOOL or typeof(rest) == TYPE_INT:
		if goes_back:
			_hold_for(tree, parameter, wanted, seconds)
		else:
			tree.set(parameter, wanted)
		return
	var made: Tween = _new_tween()
	made.tween_method(_set_parameter.bind(tree, parameter), rest, wanted, seconds)
	if goes_back:
		made.tween_method(_set_parameter.bind(tree, parameter), wanted, rest, back_seconds)

## Writes one parameter of an AnimationTree, unless the tree is gone.
func _set_parameter(value: Variant, tree: AnimationTree, parameter: String) -> void:
	if is_instance_valid(tree):
		tree.set(parameter, value)

# @ace_hidden
## The number a way of changing a bus can take: a cutoff in hertz for a muffle, a level in decibels for a dive (an
## amplify of +400 dB would be the end of the speakers), a share of wet for a wash.
static func bus_value_for(how: String, value: float) -> float:
	match how:
		"dive":
			return clampf(value, -80.0, 24.0)
		"wash":
			return clampf(value, 0.0, 1.0)
	return clampf(value, 20.0, 20500.0)

## Plays the list once, or over and over while Loop is ticked: the pass is walked, then the loop
## waits Wait Between seconds (one frame at least) and walks it again, until Times passes have been
## made (0 is until stopped), Loop is turned off or the play is stopped.
func _play_list(at_strength: float, backwards: bool) -> void:
	_loop_run += 1
	var mine: int = _loop_run
	var passes: int = 0
	while true:
		await _walk(_steps_now(), at_strength, backwards)
		passes += 1
		if not loop or mine != _loop_run or not is_inside_tree():
			return
		if loop_times > 0 and passes >= loop_times:
			return
		if loop_wait > 0.0:
			await get_tree().create_timer(loop_wait).timeout
		else:
			await get_tree().process_frame
		if mine != _loop_run or not is_inside_tree():
			return

## The name this player's values are kept under in the Juice node's book.
func _key() -> String:
	return "juice player %d" % get_instance_id()

## Writes down what a property was, ONCE for each object and property: the first value is the one
## Restore puts back, whatever the cards after it did to the property.
func _keep_first(object: Object, property: String, before: Variant) -> void:
	for entry: Variant in _restore_to:
		var held: Dictionary = entry as Dictionary
		if held.get("object") == object and str(held.get("property", "")) == property:
			return
	_restore_to.append({"object": object, "property": property, "value": before})

## Tells the Juice node a play is beginning, so it writes down what every value its cards will touch is
## worth now (once) and what each will be worth when the cards have run their course.
func _tell_juice_began(list: Array) -> void:
	var juice: Node = _juice_quiet()
	if juice != null and juice.has_method("juice_player_began"):
		juice.call("juice_player_began", _key(), list)

## Tells the Juice node this player's cards are over: with `put_back` false every value lands where the
## cards would have left it, with true it goes back to what it was before the first card. The shake, the
## slowmo and the hold on the clock end either way.
func _tell_juice_ended(put_back: bool) -> void:
	var juice: Node = _juice_quiet()
	if juice != null and juice.has_method("juice_player_ended"):
		juice.call("juice_player_ended", _key(), put_back)

## Ends everything the cards of this player set going, whether or not the walk is still on: the tweens it
## started (a value stays where it had got to), a fade on a bus, the sounds, the forces, the cards of your
## own, and the effects the Juice node is holding.
func _end_effects() -> void:
	_stop_tweens()
	for moved: Tween in _bus_tweens:
		if moved != null and moved.is_valid():
			moved.kill()
	_bus_tweens.clear()
	_stop_sound("", 0.0)
	_release_forces()
	_release_holds()
	_take_ways_back()
	_removals.clear()
	_told_own("stop")
	_tell_juice_ended(false)

## What leaving the scene does: the play ends and so does what it started, so a slowmo or a shake cannot
## outlive the thing that began it. On Juice Finished is said a moment later, so a player that was only
## taken out of the tree (put away in a pool) says it and one that was freed does not.
func _exit_tree() -> void:
	_loop_run += 1
	_put_flares_back()
	_end_effects()
	_told_nested("stop")
	if not playing:
		return
	_live.clear()
	_waiting.clear()
	_resumed.emit()
	playing = false
	_paused = false
	_held = false
	progress = 1.0
	now_playing = ""
	call_deferred("emit_signal", "on_feedbacks_finished")

# @ace_hidden
## What the scene tree tells every player in the group. A name of this pack's own, never the bare word
## stop: an audio player, an animation player or a timer in the same group answers to that one too.
func stop_juice_from_group(and_restore: bool) -> void:
	if and_restore:
		revert()
	else:
		stop()

## Pauses, resumes or flips the player a Pause Or Resume card names, or this one when it names none.
func _pause_player(card: Dictionary) -> void:
	var other: Node = self
	if _names_a_node(card, "player"):
		other = _target(card, "player", false)
		if other == null or not other.has_method("toggle_juice_paused"):
			_card_missing(card, "points at no Juice Player")
			return
	match str(card.get("mode", "pause")):
		"resume":
			other.call("resume_feedbacks")
		"toggle":
			other.call("toggle_juice_paused")
		_:
			other.call("pause_feedbacks")

# Juice Player: add this node under an object (the node was called Feedback Player before version 0.21.0), fill its list in the Inspector, and one row plays the whole beat. Cards are dragged into order, ticked off, and tuned in place; Pause and Hold space them out and Loop Back repeats a stretch. The ten shake-and-flash words are played by the Juice behaviour beside this node, so put one there too. The list is the same shape a moment file holds - drop a file on the slot to play it instead, or save the list out as one. This pack is an event sheet - extend it by editing it.
