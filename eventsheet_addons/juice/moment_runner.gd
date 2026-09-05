## @ace_version(1.0.0)
@icon("res://eventsheet_addons/juice/icon.svg")
class_name MomentRunner
extends RefCounted
## The one runner behind every moment: the waits a moment block is timed by, the strength an amount is scaled by, and the falloff that makes a far impact quieter.

# THE ONE RUNNER BEHIND EVERY MOMENT.
#
# A moment is a beat of feedback - the shake and the freeze and the flash of a hit - and this
# project can write one down in three places: as a block of rows in a sheet (which compiles to a
# coroutine calling the waits below), as a moment FILE the Juice pack's Moment row plays, and as
# a list a node holds. All three run through this file, so a beat behaves the same wherever it
# was written and a fix lands once instead of three times.
#
# WHAT IT KNOWS, and nothing else:
#   the waits      at / then / hold, each on the clock the step chose. A moment's schedule is
#                  worked out when the sheet compiles, so what arrives here is one number.
#   the strength   what an amount really becomes once the play's strength has scaled it and the
#                  no-flashing ceiling has held it down.
#   the range      how much of the strength survives the distance between where the moment
#                  happened and whoever is watching.
#
# PLAIN GDSCRIPT, AND NOT THE PLUGIN'S. Nothing here touches an editor, a sheet, or any class the
# plugin declares. It allocates nothing per frame - a wait is one timer per step, and the strength
# maths is arithmetic - so a moment costs the same on a phone and in a browser as it does on a
# desktop.

## The clock a wait is measured on. "game" follows Engine.time_scale, so a moment stretches with a
## slowmo; "real" ignores it, which is what a step after a hitstop wants.
const CLOCK_GAME: String = "game"
const CLOCK_REAL: String = "real"

## How the strength falls off between where the moment happened and the edge of its range.
const FALLOFF_LINEAR: String = "linear"
const FALLOFF_SMOOTH: String = "smooth"
const FALLOFF_NONE: String = "none"

## The project-wide answer to "this player has asked for no flashing", spelled the same here as
## everywhere else that reads it.
const NO_FLASHING_META: StringName = &"no_flashing"

## The ceiling every amount a player SEES is held under while no flashing is on, and the floor
## every one of those times is held over. Same numbers the moment layer already holds itself to:
## the hit still hits, it just cannot strobe.
const FLASH_CEILING: float = 0.3
const FLASH_FLOOR_SECONDS: float = 0.4

## The step words that leave NOTHING to walk back through. A shake has already been felt, a
## hitstop has already let the frame go, a shockwave has already crossed the screen: there is no
## half of one of those to undo, so the way back steps over them rather than playing them again.
## Every other word writes a value, and a value can be walked home.
##
## This is NOT the same question as touched_by below, and punch and hitstop answer both. One
## way is about the way BACK: there is no half of a punch or a freeze to play in reverse, so
## the revert walk steps over them. Touched by is about the value each one WROTE: a punch left
## a scale behind and a hitstop left a time scale, and a Restore puts those back. A step can
## leave nothing to replay and still leave something to put right.
const ONE_WAY_VERBS: PackedStringArray = ["shake", "hitstop", "punch", "shockwave", "chromatic"]

## The step words whose amount is an AMPLITUDE - how much of something a player SEES, from none
## of it to all of it. ONLY these are held under the ceiling and over the floor above, because
## only these are what a no-flashing setting is about. A hitstop's freeze fraction, a slowmo's
## time scale, a zoom's percentage and the value a property is walked to are numbers of other
## kinds: holding one of those to 0.3 would not be less flashing, it would be the wrong number.
##
## ONE list, here, because a moment has three homes - a block of rows, a moment file, and the
## list a feedback node holds - and a word held to the ceiling in one of them and not in another
## would be a different beat depending on where somebody wrote it down.
const AMPLITUDE_VERBS: PackedStringArray = ["shake", "flash", "punch", "shockwave",
	"chromatic", "pulse", "hold"]

## The names the values a moment writes are kept under, so the beat that recorded one and the row
## that puts it back are spelling the same thing. A post effect's key carries the effect's own
## name after the prefix, because a moment may hold several of them at once.
const TOUCH_HOST_TINT: String = "host tint"
const TOUCH_HOST_SCALE: String = "host scale"
const TOUCH_CAMERA_ZOOM: String = "camera zoom"
const TOUCH_TIME_SCALE: String = "time scale"
const TOUCH_POST_PREFIX: String = "post "
## Wait until `seconds` after the step above started - the At word. The number is the GAP the
## compiler worked out, never the absolute time, so nothing here has to remember when a moment began.
static func at(host: Node, seconds: float, clock: String = CLOCK_GAME) -> Signal:
	return wait(host, seconds, clock)
## Wait `seconds` after the previous step started - the Then word.
static func then(host: Node, seconds: float, clock: String = CLOCK_GAME) -> Signal:
	return wait(host, seconds, clock)
## Wait for the slowest step above to finish, then `delay` - the Hold word. `longest` is how much
## of that step is still to run when the Hold is reached, which the compiler folded out of the
## durations the rows declared; a moment whose steps are all instant passes 0 and waits only the delay.
static func hold(host: Node, longest: float, delay: float, clock: String = CLOCK_GAME) -> Signal:
	return wait(host, maxf(longest, 0.0) + maxf(delay, 0.0), clock)
## The one wait the three words go through. A zero wait is still a wait of one frame, which is what
## makes a Hold a beat rather than a no-op.
static func wait(host: Node, seconds: float, clock: String = CLOCK_GAME) -> Signal:
	var tree: SceneTree = _tree(host)
	if tree == null:
		push_warning("Moment: a step asked to wait with no scene tree to wait in - the wait was skipped.")
		return Signal()
	return tree.create_timer(maxf(seconds, 0.0), true, false, clock == CLOCK_REAL).timeout
## The strength a play really has once the distance has been paid for: full strength with no range
## and no place, less the further away the moment happened, and nothing at all past the edge.
##
## `from` may be a node or a point (Vector2 / Vector3). Who is watching is the active camera, and
## the host itself when there is none - a game with no camera still hears its own hits.
static func strength_at(host: Node, strength: float, from: Variant, within: float,
		falloff: String = FALLOFF_LINEAR) -> float:
	if within <= 0.0:
		return strength
	var place: Variant = place_of(from)
	var listener: Variant = place_of(listener_of(host))
	if place == null or listener == null:
		return strength
	var apart: float = _distance(place, listener)
	if apart < 0.0:
		return strength
	return strength * falloff_factor(apart, within, falloff)
## Whoever the distance is measured to: the camera the player is looking through, or the host
## itself when this game has none.
static func listener_of(host: Node) -> Node:
	var tree: SceneTree = _tree(host)
	if tree == null:
		return host
	var viewport: Viewport = host.get_viewport() if host != null and host.is_inside_tree() else tree.root
	if viewport == null:
		return host
	var camera_3d: Camera3D = viewport.get_camera_3d()
	if camera_3d != null:
		return camera_3d
	var camera_2d: Camera2D = viewport.get_camera_2d()
	if camera_2d != null:
		return camera_2d
	return host
## The tree a wait happens in: the host's own, or the running one when the host is not in it yet.
static func _tree(host: Node) -> SceneTree:
	if host != null and host.is_inside_tree():
		return host.get_tree()
	return Engine.get_main_loop() as SceneTree
## The shortest a step of these words really lasts when its card asks for 0 - "let it use its
## own natural length". The layer that plays them holds them to this floor, so the book has to
## count the same number: a beat counted as instant is over in the book while the flash it
## started is still on the screen, which turns On Moment Finished into a lie and makes Revert
## impossible for exactly as long as there is something to revert.
const NATURAL_SECONDS: float = 0.05
const NATURALLY_TIMED_VERBS: PackedStringArray = ["flash", "punch", "zoom", "chromatic", "pulse"]

## What one amount really becomes: scaled by the strength this play has, then held under the
## ceiling while no flashing is on. ONE function, so no step can be the one that forgot.
static func scaled(amount: float, strength: float) -> float:
	var wanted: float = amount * maxf(strength, 0.0)
	if no_flashing():
		return clampf(wanted, -FLASH_CEILING, FLASH_CEILING)
	return wanted

## And what one duration really becomes: never quicker than the floor while no flashing is on,
## because a small amplitude arriving ten times a second is still a strobe.
static func seconds_of(seconds: float) -> float:
	if no_flashing():
		return maxf(seconds, FLASH_FLOOR_SECONDS)
	return maxf(seconds, 0.0)

## Whether this player has asked for no flashing.
static func no_flashing() -> bool:
	return bool(Engine.get_meta(NO_FLASHING_META, false))

## Whether one step word's amount is an amplitude, and so whether the ceiling and the floor have
## anything to say about it at all. The one question every home of a moment asks before clamping.
static func is_amplitude(verb: String) -> bool:
	return AMPLITUDE_VERBS.has(verb.strip_edges().to_lower())

## How much of the strength survives one distance. Pure arithmetic, so it is the piece a test can
## pin without a camera, a viewport or a frame: 1 at the middle, 0 at the edge and beyond, and the
## smooth word rounds the shoulders of the line between.
static func falloff_factor(distance: float, within: float, falloff: String = FALLOFF_LINEAR) -> float:
	if within <= 0.0:
		return 1.0
	if distance >= within:
		return 0.0
	if falloff == FALLOFF_NONE:
		return 1.0
	var near: float = clampf(1.0 - distance / within, 0.0, 1.0)
	if falloff == FALLOFF_SMOOTH:
		return near * near * (3.0 - 2.0 * near)
	return near

## Where something is: a point is already the answer, a node is asked for its own place, and
## anything else has none.
static func place_of(what: Variant) -> Variant:
	if what is Vector2 or what is Vector3:
		return what
	if what is Node2D:
		return (what as Node2D).global_position
	if what is Node3D:
		return (what as Node3D).global_position
	if what is Control:
		return (what as Control).global_position
	return null

## The distance between two places, or -1 when they are not the same kind of place (a 2D moment
## and a 3D camera cannot be measured against each other, and guessing would be worse than saying so).
static func _distance(place: Variant, listener: Variant) -> float:
	if place is Vector2 and listener is Vector2:
		return (place as Vector2).distance_to(listener as Vector2)
	if place is Vector3 and listener is Vector3:
		return (place as Vector3).distance_to(listener as Vector3)
	return -1.0

## The order a moment's steps are taken in: top to bottom, or bottom to top when the play was
## asked for backwards. EVERY step is in it either way - playing a beat in reverse is still
## playing the whole beat, which is what makes a hover-out the hover-in read the other way.
static func walk_order(steps: Array, backwards: bool = false) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	for index: int in steps.size():
		order.append(steps.size() - 1 - index if backwards else index)
	return order

## The order the way BACK is walked: bottom to top, with the one-way words left out. A revert is
## not a second play - it is the beat undoing itself - so a step that only ever happened once is
## stepped over rather than fired again on the way home.
static func revert_order(steps: Array) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	for index: int in steps.size():
		var at: int = steps.size() - 1 - index
		var step: Variant = steps[at]
		if step is Dictionary and not is_one_way(str((step as Dictionary).get("verb", ""))):
			order.append(at)
	return order

## Whether one step word leaves nothing behind to walk home.
static func is_one_way(verb: String) -> bool:
	return ONE_WAY_VERBS.has(verb.strip_edges().to_lower())

## What one step is CALLED - the name a trigger carries and a debug view prints. Its own label
## when it was given one, else the word it is made of, else where it sits in the list, so a step
## always has something to be called and no sheet has to count rows to find out which fired.
static func step_label(step: Dictionary, index: int) -> String:
	var named: String = str(step.get("label", "")).strip_edges()
	if not named.is_empty():
		return named
	var verb: String = str(step.get("verb", "")).strip_edges()
	if not verb.is_empty():
		return verb
	return "step %d" % (index + 1)

## How long ONE step lasts: what its card says, or the natural length of its word when the card
## says nothing. A word with no natural length of its own is instant, which is the honest answer.
static func step_seconds(verb: String, seconds: float) -> float:
	if seconds > 0.0:
		return seconds
	return NATURAL_SECONDS if NATURALLY_TIMED_VERBS.has(verb.strip_edges().to_lower()) else 0.0

## How long a beat LASTS: the longest of its steps, because a moment's steps all begin together
## and the beat is over when the slowest one is. A moment of instant steps has no length at all,
## which is the honest answer rather than a made-up tail.
static func length_of(steps: Array) -> float:
	var longest: float = 0.0
	for step: Variant in steps:
		if step is Dictionary:
			var card: Dictionary = step as Dictionary
			var lasts: float = step_seconds(str(card.get("verb", "")), maxf(float(card.get("seconds", 0.0)), 0.0))
			longest = maxf(longest, lasts)
	return longest

## How far through a play is, from 0 at its first frame to 1 at its last. A beat with no length
## is finished the instant it begins, so it answers 1 rather than dividing by nothing.
static func progress_of(elapsed: float, length: float) -> float:
	if length <= 0.0:
		return 1.0
	return clampf(elapsed / length, 0.0, 1.0)

## What ONE step writes: the key naming the value a Restore has to put back, or an empty string
## for a step that leaves nothing behind. This is the whole of the first-touch rule in one place,
## so the layer that records a value and the row that returns it can never drift apart.
static func touched_by(verb: String, effect: String = "") -> String:
	match verb.strip_edges().to_lower():
		"flash":
			return TOUCH_HOST_TINT
		"punch":
			return TOUCH_HOST_SCALE
		"zoom":
			return TOUCH_CAMERA_ZOOM
		"slowmo", "hitstop":
			return TOUCH_TIME_SCALE
		"pulse", "hold":
			var named: String = effect.strip_edges().to_lower()
			return "" if named.is_empty() else TOUCH_POST_PREFIX + named
	return ""

## Every value a whole moment will write, once each and in the order a reader meets them. The
## order is the steps' own, so a Restore puts a beat back the way it was taken apart.
static func touched_by_steps(steps: Array) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for step: Variant in steps:
		if not (step is Dictionary):
			continue
		var card: Dictionary = step as Dictionary
		var key: String = touched_by(str(card.get("verb", "")), str(card.get("effect", "")))
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	return keys
