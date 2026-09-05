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
