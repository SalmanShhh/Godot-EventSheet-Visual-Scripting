## @ace_tags(lighting, time, day-night)
## @ace_category("Day/Night Cycle")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/day_night_cycle/icon.svg")
class_name DayNightCycleBehavior
extends Node
## A clock that runs the sky. A whole day passes every Day Length Minutes; the sun turns with the hour, and three curves say how bright the sun, the ambient light and the sky itself are through the day. Point Sun Light at a light and World Lighting at a WorldEnvironment or a CanvasModulate - 2D and 3D both work, and an unset target is skipped. On Sunrise, On Sunset, On Midnight and On The Hour are what a game listens to; It Is Night and It Is Day are what it asks.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("DayNightCycleBehavior behavior requires a Node parent.")

## Fires as the clock passes Sunrise Hour - the moment to put the torches out.
## @ace_trigger
## @ace_name("On Sunrise")
## @ace_category("Day/Night Cycle")
signal sunrise
## Fires as the clock passes Sunset Hour - the moment to light the streetlamps.
## @ace_trigger
## @ace_name("On Sunset")
## @ace_category("Day/Night Cycle")
signal sunset
## Fires as the clock passes 0:00 - one whole game day has gone by.
## @ace_trigger
## @ace_name("On Midnight")
## @ace_category("Day/Night Cycle")
signal midnight
## Fires every time the clock reaches a whole hour, carrying the hour it reached (0 to 23). Compare it to branch on one hour in particular.
## @ace_trigger
## @ace_name("On The Hour")
## @ace_category("Day/Night Cycle")
signal hour_struck(hour: int)

## How long a whole game day takes in real minutes. 20 is a long exploration day; 2 is a level that races through dusk.
@export_range(0.1, 240, 0.1, "suffix:min") var day_length_minutes: float = 20.0
## The hour the sun reaches the horizon on its way up, on a 24 hour clock. On Sunrise fires as the clock passes it.
@export_range(0, 24, 0.25, "suffix:h") var sunrise_hour: float = 6.0
## The hour the sun reaches the horizon on its way down, on a 24 hour clock. Daylight and night are stretched over their own halves of the sun's turn, so noon is overhead whatever these two are set to.
@export_range(0, 24, 0.25, "suffix:h") var sunset_hour: float = 19.0
## What time it is now, on a 24 hour clock - 8.5 is half past eight in the morning. Set it here to choose the hour a scene opens on, or from a row with Set The Time.
@export_range(0, 24, 0.01, "suffix:h") var time_of_day: float = 8.0
## How many times faster than Day Length Minutes the clock actually runs. 1 is that length exactly, 60 is a time-lapse, 0 stops it.
@export_range(0, 240, 0.1) var clock_scale: float = 1.0
## How bright the sun light is through the day, drawn left to right from midnight to midnight. Leave it empty for a plain sunrise-to-sunset arc.
@export var sun_brightness: Curve = null
## How bright the environment's ambient light is through the day, midnight to midnight. Leave it empty and night keeps a little ambient light rather than going pitch black.
@export var ambient_brightness: Curve = null
## How much daylight the sky itself carries, midnight to midnight: it brightens a 3D background, and lifts a 2D CanvasModulate from the colour the scene was authored with toward full daylight. Leave it empty for the same arc the sun takes.
@export var sky_tint_strength: Curve = null
## The light that plays the sun. A DirectionalLight3D also turns with the hour; any other light only changes brightness. Leave it empty to drive no light at all.
@export_node_path("Light2D", "Light3D") var sun_light: NodePath = ""
## What the sky is: a WorldEnvironment for a 3D scene, or the CanvasModulate that holds a 2D level's darkness. Leave it empty to drive neither.
@export_node_path("WorldEnvironment", "CanvasModulate") var world_lighting: NodePath = ""

## The whole hour last announced, so On The Hour rings once per hour rather than once per
## frame, and the colour the CanvasModulate was authored with, which is this level's NIGHT:
## the cycle lifts the scene's own darkness toward daylight rather than replacing it, so a
## designer's night colour survives.
var _last_hour: int = -1
var _authored_darkness: Color = Color.WHITE
var _paused: bool = false

func _ready() -> void:
	if not world_lighting.is_empty():
		# The colour a 2D level was authored with IS its night: read it once, before the first
		# frame writes over it, so the cycle lifts the designer's darkness rather than inventing one.
		var darkness: CanvasModulate = get_node_or_null(world_lighting) as CanvasModulate
		if darkness != null:
			_authored_darkness = darkness.color
	_last_hour = int(floor(time_of_day))
	_drive_the_world()

func _process(delta: float) -> void:
	if _paused or day_length_minutes <= 0.0 or clock_scale <= 0.0:
		return
	var previous: float = time_of_day
	# 24 game hours per Day Length Minutes of real time, scaled by whatever the clock is set to.
	time_of_day = fposmod(time_of_day + delta * (24.0 / (day_length_minutes * 60.0)) * clock_scale, 24.0)
	_announce_moments(previous, time_of_day)
	_drive_the_world()

## @ace_action
## @ace_featured
## @ace_name("Set The Time")
## @ace_description("Jumps the clock to an hour on the 24 hour clock - the row a cutscene, a bed or a debug key uses. The hours it skips over do NOT ring: a jump is one moment, not the twelve it passed.")
## @ace_display_template("Set the time to [b]{hour}[/b]:00")
## @ace_icon("res://eventsheet_addons/day_night_cycle/icon.svg")
## @ace_codegen_template("$DayNightCycleBehavior.set_the_time({hour})")
func set_the_time(hour: float) -> void:
	time_of_day = fposmod(hour, 24.0)
	_last_hour = int(floor(time_of_day))
	_drive_the_world()

## @ace_action
## @ace_name("Run The Clock Faster")
## @ace_description("Changes how fast the clock runs without changing the day it is set to - what a game uses for a rest at an inn, or for a sky that races while a menu is open.")
## @ace_display_template("Run the clock [b]{times_faster}[/b] times faster")
## @ace_icon("res://eventsheet_addons/day_night_cycle/icon.svg")
## @ace_codegen_template("$DayNightCycleBehavior.run_the_clock({times_faster})")
func run_the_clock(times_faster: float) -> void:
	clock_scale = maxf(times_faster, 0.0)

## @ace_action
## @ace_name("Pause The Clock")
## @ace_description("Stops the clock where it is. The sky keeps whatever it is showing - nothing is reset.")
## @ace_display_template("Pause the clock")
## @ace_icon("res://eventsheet_addons/day_night_cycle/icon.svg")
## @ace_codegen_template("$DayNightCycleBehavior.pause_the_clock()")
func pause_the_clock() -> void:
	_paused = true

## @ace_action
## @ace_name("Resume The Clock")
## @ace_description("Starts the clock again from where it was paused.")
## @ace_display_template("Resume the clock")
## @ace_icon("res://eventsheet_addons/day_night_cycle/icon.svg")
## @ace_codegen_template("$DayNightCycleBehavior.resume_the_clock()")
func resume_the_clock() -> void:
	_paused = false

## @ace_condition
## @ace_name("It Is Day")
## @ace_description("True between sunrise and sunset. The comparison is made in hours SINCE sunrise so that a day running past midnight (sunrise 20:00, sunset 4:00) reads the same as an ordinary one.")
## @ace_display_template("It is day")
## @ace_icon("res://eventsheet_addons/day_night_cycle/icon.svg")
## @ace_codegen_template("$DayNightCycleBehavior.it_is_day()")
func it_is_day() -> bool:
	return fposmod(time_of_day - sunrise_hour, 24.0) < fposmod(sunset_hour - sunrise_hour, 24.0)

## @ace_condition
## @ace_name("It Is Night")
## @ace_description("True between sunset and sunrise - the other half of the same question, written as one row so a sheet never has to invert anything.")
## @ace_display_template("It is night")
## @ace_icon("res://eventsheet_addons/day_night_cycle/icon.svg")
## @ace_codegen_template("$DayNightCycleBehavior.it_is_night()")
func it_is_night() -> bool:
	return not it_is_day()

## Where the sun is on its circle: 0 at sunrise, 0.25 overhead, 0.5 at sunset, 1 back at
## sunrise. Daylight and night are stretched over their own halves rather than over equal
## twelves, which is what puts noon overhead whichever hours a project sets.
func _sun_turn() -> float:
	var daylight_hours: float = fposmod(sunset_hour - sunrise_hour, 24.0)
	var since_sunrise: float = fposmod(time_of_day - sunrise_hour, 24.0)
	if daylight_hours <= 0.0:
		return since_sunrise / 24.0
	if since_sunrise < daylight_hours:
		return since_sunrise / daylight_hours * 0.5
	return 0.5 + (since_sunrise - daylight_hours) / (24.0 - daylight_hours) * 0.5

## How much sun there is right now, 0 through the night and 1 at noon - the fallback every
## curve uses when it has not been drawn, and the shape the drawn ones are read against.
func _daylight() -> float:
	return clampf(sin(TAU * _sun_turn()), 0.0, 1.0)

## One curve's value for the hour it is now, or `fallback` when nobody drew that curve. A
## curve is read left to right across the whole day, so 0 is midnight and 1 is midnight again.
func _sample(curve: Curve, fallback: float) -> float:
	if curve == null:
		return fallback
	return curve.sample(clampf(time_of_day / 24.0, 0.0, 1.0))

## True when the clock passed a mark between two readings. It is a function rather than a
## comparison because of midnight: after the wrap `now` is SMALLER than `previous`, and every
## mark still ahead of previous or already behind now was passed on the way round.
func _crossed(previous: float, now: float, mark: float) -> bool:
	var target: float = fposmod(mark, 24.0)
	if now >= previous:
		return previous < target and target <= now
	return target > previous or target <= now

## Rings whichever bells the clock passed between two readings.
func _announce_moments(previous: float, now: float) -> void:
	if _crossed(previous, now, sunrise_hour):
		sunrise.emit()
	if _crossed(previous, now, sunset_hour):
		sunset.emit()
	if _crossed(previous, now, 0.0):
		midnight.emit()
	var struck: int = int(floor(now))
	if struck != _last_hour:
		_last_hour = struck
		hour_struck.emit(struck)

## Writes the hour into whichever of the two targets are set. Everything here is an ordinary
## property write on an ordinary node - there is no lighting system underneath.
func _drive_the_world() -> void:
	var daylight: float = _daylight()
	if not sun_light.is_empty():
		_drive_the_sun(get_node_or_null(sun_light), daylight)
	if not world_lighting.is_empty():
		_drive_the_sky(get_node_or_null(world_lighting), daylight)

## Turns the sun and sets its brightness. Only a DIRECTIONAL 3D light has an angle worth
## turning: its rotation is where the whole sky's light comes from, while a spot's rotation is
## where somebody aimed it and a 2D light lies flat on the screen. So the turn belongs to a
## DirectionalLight3D alone - point Sun Light at any other light and only its brightness moves,
## which is exactly what that property's own tooltip promises - and the brightness is read off
## whichever property this light spells brightness with.
func _drive_the_sun(sun_node: Node, daylight: float) -> void:
	if sun_node == null:
		return
	var sun_3d: DirectionalLight3D = sun_node as DirectionalLight3D
	if sun_3d != null:
		sun_3d.rotation_degrees.x = -360.0 * _sun_turn()
	var brightness: String = "light_energy" if "light_energy" in sun_node else "energy"
	if brightness in sun_node:
		sun_node.set(brightness, _sample(sun_brightness, daylight))

## Sets the sky: a 3D scene's ambient and background energy live on its Environment, and a 2D
## level's daylight is the CanvasModulate lifted from the colour it was authored with toward
## white. Night keeps a floor of ambient light when no curve says otherwise, because a scene
## nobody can see is a bug rather than a night.
func _drive_the_sky(world_node: Node, daylight: float) -> void:
	var darkness: CanvasModulate = world_node as CanvasModulate
	if darkness != null:
		darkness.color = _authored_darkness.lerp(Color.WHITE, _sample(sky_tint_strength, daylight))
		return
	var holder: WorldEnvironment = world_node as WorldEnvironment
	if holder == null or holder.environment == null:
		return
	holder.environment.ambient_light_energy = _sample(ambient_brightness, lerpf(0.15, 1.0, daylight))
	holder.environment.background_energy_multiplier = _sample(sky_tint_strength, daylight)

# Day/Night Cycle: one clock for the whole sky. Day Length Minutes sets the pace, Sunrise Hour and Sunset Hour set the shape, and the three curves say how bright the sun, the ambient light and the sky are through it. Point Sun Light and World Lighting at what you want driven and leave the rest empty. The rows are Set The Time, Run The Clock Faster, Pause and Resume, the questions It Is Night and It Is Day, and the four moment triggers. This pack is an event sheet - extend it by editing it.
