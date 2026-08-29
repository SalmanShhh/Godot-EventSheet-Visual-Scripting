# Pack builder - day_night_cycle (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Day/Night Cycle: every day/night system anyone writes is the same three lines run forever -
## advance a clock, turn it into a sun angle, lerp the colours - so this pack owns those three and
## leaves the game the moments. The clock, the curves and the two targets are Inspector work; the
## sheet gets four triggers (sunrise, sunset, midnight, the hour), two questions (it is night, it is
## day) and the four actions that move the clock about.
##
## Both dimensions work off the same clock: point Sun Light at a DirectionalLight3D and World
## Lighting at a WorldEnvironment for a 3D sky, or at a CanvasModulate for a 2D level, and leave the
## one you are not using empty. A target that is not set is simply skipped, so a project can adopt
## the triggers on their own and drive nothing at all.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	# A plain Node: the cycle drives its targets through exported NodePaths rather than through its
	# parent, which is what lets one behaviour light a 2D level and a 3D sky with the same clock.
	sheet.host_class = "Node"
	sheet.custom_class_name = "DayNightCycleBehavior"
	sheet.class_description = "A clock that runs the sky. A whole day passes every Day Length Minutes; the sun turns with the hour, and three curves say how bright the sun, the ambient light and the sky itself are through the day. Point Sun Light at a light and World Lighting at a WorldEnvironment or a CanvasModulate - 2D and 3D both work, and an unset target is skipped. On Sunrise, On Sunset, On Midnight and On The Hour are what a game listens to; It Is Night and It Is Day are what it asks."
	sheet.addon_category = "Day/Night Cycle"
	sheet.addon_tags = PackedStringArray(["lighting", "time", "day-night"])
	# Every verb here is annotated, so `node` mode adds no vocabulary - what it adds is the CALL:
	# a method's code is synthesized as `$Class.method(...)` (retargetable) only in this mode, and
	# a member whose annotation block keeps it verbatim gets no template written for it otherwise.
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"day_length_minutes": {"type": "float", "default": 20.0, "exported": true, "attributes": {"tooltip": "How long a whole game day takes in real minutes. 20 is a long exploration day; 2 is a level that races through dusk.", "range": {"min": "0.1", "max": "240", "step": "0.1", "suffix": "min"}}},
		"sunrise_hour": {"type": "float", "default": 6.0, "exported": true, "attributes": {"tooltip": "The hour the sun reaches the horizon on its way up, on a 24 hour clock. On Sunrise fires as the clock passes it.", "range": {"min": "0", "max": "24", "step": "0.25", "suffix": "h"}}},
		"sunset_hour": {"type": "float", "default": 19.0, "exported": true, "attributes": {"tooltip": "The hour the sun reaches the horizon on its way down, on a 24 hour clock. Daylight and night are stretched over their own halves of the sun's turn, so noon is overhead whatever these two are set to.", "range": {"min": "0", "max": "24", "step": "0.25", "suffix": "h"}}},
		"time_of_day": {"type": "float", "default": 8.0, "exported": true, "attributes": {"tooltip": "What time it is now, on a 24 hour clock - 8.5 is half past eight in the morning. Set it here to choose the hour a scene opens on, or from a row with Set The Time.", "range": {"min": "0", "max": "24", "step": "0.01", "suffix": "h"}}},
		"clock_scale": {"type": "float", "default": 1.0, "exported": true, "attributes": {"tooltip": "How many times faster than Day Length Minutes the clock actually runs. 1 is that length exactly, 60 is a time-lapse, 0 stops it.", "range": {"min": "0", "max": "240", "step": "0.1"}}},
		"sun_brightness": {"type": "Curve", "default": null, "exported": true, "attributes": {"tooltip": "How bright the sun light is through the day, drawn left to right from midnight to midnight. Leave it empty for a plain sunrise-to-sunset arc."}},
		"ambient_brightness": {"type": "Curve", "default": null, "exported": true, "attributes": {"tooltip": "How bright the environment's ambient light is through the day, midnight to midnight. Leave it empty and night keeps a little ambient light rather than going pitch black."}},
		"sky_tint_strength": {"type": "Curve", "default": null, "exported": true, "attributes": {"tooltip": "How much daylight the sky itself carries, midnight to midnight: it brightens a 3D background, and lifts a 2D CanvasModulate from the colour the scene was authored with toward full daylight. Leave it empty for the same arc the sun takes."}},
		"sun_light": {"type": "NodePath", "default": "", "exported": true, "attributes": {"tooltip": "The light that plays the sun. A DirectionalLight3D also turns with the hour; any other light only changes brightness. Leave it empty to drive no light at all.", "node_path_types": ["Light2D", "Light3D"]}},
		"world_lighting": {"type": "NodePath", "default": "", "exported": true, "attributes": {"tooltip": "What the sky is: a WorldEnvironment for a 3D scene, or the CanvasModulate that holds a 2D level's darkness. Leave it empty to drive neither.", "node_path_types": ["WorldEnvironment", "CanvasModulate"]}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Day/Night Cycle: one clock for the whole sky. Day Length Minutes sets the pace, Sunrise Hour and Sunset Hour set the shape, and the three curves say how bright the sun, the ambient light and the sky are through it. Point Sun Light and World Lighting at what you want driven and leave the rest empty. The rows are Set The Time, Run The Clock Faster, Pause and Resume, the questions It Is Night and It Is Day, and the four moment triggers. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# The four moments the clock announces, each a real signal published as a trigger, so a sheet
	# connects to them exactly as it connects to any other signal in the project.
	_moment(sheet, "sunrise", "On Sunrise", "", "Fires as the clock passes Sunrise Hour - the moment to put the torches out.")
	_moment(sheet, "sunset", "On Sunset", "", "Fires as the clock passes Sunset Hour - the moment to light the streetlamps.")
	_moment(sheet, "midnight", "On Midnight", "", "Fires as the clock passes 0:00 - one whole game day has gone by.")
	_moment(sheet, "hour_struck", "On The Hour", "hour: int", "Fires every time the clock reaches a whole hour, carrying the hour it reached (0 to 23). Compare it to branch on one hour in particular.")

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## The whole hour last announced, so On The Hour rings once per hour rather than once per",
		"## frame, and the colour the CanvasModulate was authored with, which is this level's NIGHT:",
		"## the cycle lifts the scene's own darkness toward daylight rather than replacing it, so a",
		"## designer's night colour survives.",
		"var _last_hour: int = -1",
		"var _authored_darkness: Color = Color.WHITE",
		"var _paused: bool = false",
		"",
		"## Jumps the clock to an hour on the 24 hour clock - the row a cutscene, a bed or a debug key",
		"## uses. The hours it skips over do NOT ring: a jump is one moment, not the twelve it passed.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Set The Time\")",
		"## @ace_display_template(\"Set the time to [b]{hour}[/b]:00\")",
		"func set_the_time(hour: float) -> void:",
		"\ttime_of_day = fposmod(hour, 24.0)",
		"\t_last_hour = int(floor(time_of_day))",
		"\t_drive_the_world()",
		"",
		"## Changes how fast the clock runs without changing the day it is set to - what a game uses",
		"## for a rest at an inn, or for a sky that races while a menu is open.",
		"## @ace_action",
		"## @ace_name(\"Run The Clock Faster\")",
		"## @ace_display_template(\"Run the clock [b]{times_faster}[/b] times faster\")",
		"func run_the_clock(times_faster: float) -> void:",
		"\tclock_scale = maxf(times_faster, 0.0)",
		"",
		"## Stops the clock where it is. The sky keeps whatever it is showing - nothing is reset.",
		"## @ace_action",
		"## @ace_name(\"Pause The Clock\")",
		"## @ace_display_template(\"Pause the clock\")",
		"func pause_the_clock() -> void:",
		"\t_paused = true",
		"\t# A stopped clock has no hour to advance, so it stops costing a frame too; Resume The Clock",
		"\t# starts it again. The Inspector knobs stay live - a day length or a clock scale of 0 is read",
		"\t# in the tick rather than switched off here, so changing either while the game runs works.",
		"\tset_process(false)",
		"",
		"## Starts the clock again from where it was paused.",
		"## @ace_action",
		"## @ace_name(\"Resume The Clock\")",
		"## @ace_display_template(\"Resume the clock\")",
		"func resume_the_clock() -> void:",
		"\t_paused = false",
		"\tset_process(true)",
		"",
		"## True between sunrise and sunset. The comparison is made in hours SINCE sunrise so that a",
		"## day running past midnight (sunrise 20:00, sunset 4:00) reads the same as an ordinary one.",
		"## @ace_condition",
		"## @ace_name(\"It Is Day\")",
		"## @ace_display_template(\"It is day\")",
		"func it_is_day() -> bool:",
		"\treturn fposmod(time_of_day - sunrise_hour, 24.0) < fposmod(sunset_hour - sunrise_hour, 24.0)",
		"",
		"## True between sunset and sunrise - the other half of the same question, written as one row",
		"## so a sheet never has to invert anything.",
		"## @ace_condition",
		"## @ace_name(\"It Is Night\")",
		"## @ace_display_template(\"It is night\")",
		"func it_is_night() -> bool:",
		"\treturn not it_is_day()",
		"",
		"## Where the sun is on its circle: 0 at sunrise, 0.25 overhead, 0.5 at sunset, 1 back at",
		"## sunrise. Daylight and night are stretched over their own halves rather than over equal",
		"## twelves, which is what puts noon overhead whichever hours a project sets.",
		"func _sun_turn() -> float:",
		"\tvar daylight_hours: float = fposmod(sunset_hour - sunrise_hour, 24.0)",
		"\tvar since_sunrise: float = fposmod(time_of_day - sunrise_hour, 24.0)",
		"\tif daylight_hours <= 0.0:",
		"\t\treturn since_sunrise / 24.0",
		"\tif since_sunrise < daylight_hours:",
		"\t\treturn since_sunrise / daylight_hours * 0.5",
		"\treturn 0.5 + (since_sunrise - daylight_hours) / (24.0 - daylight_hours) * 0.5",
		"",
		"## How much sun there is right now, 0 through the night and 1 at noon - the fallback every",
		"## curve uses when it has not been drawn, and the shape the drawn ones are read against.",
		"func _daylight() -> float:",
		"\treturn clampf(sin(TAU * _sun_turn()), 0.0, 1.0)",
		"",
		"## One curve's value for the hour it is now, or `fallback` when nobody drew that curve. A",
		"## curve is read left to right across the whole day, so 0 is midnight and 1 is midnight again.",
		"func _sample(curve: Curve, fallback: float) -> float:",
		"\tif curve == null:",
		"\t\treturn fallback",
		"\treturn curve.sample(clampf(time_of_day / 24.0, 0.0, 1.0))",
		"",
		"## True when the clock passed a mark between two readings. It is a function rather than a",
		"## comparison because of midnight: after the wrap `now` is SMALLER than `previous`, and every",
		"## mark still ahead of previous or already behind now was passed on the way round.",
		"func _crossed(previous: float, now: float, mark: float) -> bool:",
		"\tvar target: float = fposmod(mark, 24.0)",
		"\tif now >= previous:",
		"\t\treturn previous < target and target <= now",
		"\treturn target > previous or target <= now",
		"",
		"## Rings whichever bells the clock passed between two readings.",
		"func _announce_moments(previous: float, now: float) -> void:",
		"\tif _crossed(previous, now, sunrise_hour):",
		"\t\tsunrise.emit()",
		"\tif _crossed(previous, now, sunset_hour):",
		"\t\tsunset.emit()",
		"\tif _crossed(previous, now, 0.0):",
		"\t\tmidnight.emit()",
		"\tvar struck: int = int(floor(now))",
		"\tif struck != _last_hour:",
		"\t\t_last_hour = struck",
		"\t\thour_struck.emit(struck)",
		"",
		"## Writes the hour into whichever of the two targets are set. Everything here is an ordinary",
		"## property write on an ordinary node - there is no lighting system underneath.",
		"func _drive_the_world() -> void:",
		"\tvar daylight: float = _daylight()",
		"\tif not sun_light.is_empty():",
		"\t\t_drive_the_sun(get_node_or_null(sun_light), daylight)",
		"\tif not world_lighting.is_empty():",
		"\t\t_drive_the_sky(get_node_or_null(world_lighting), daylight)",
		"",
		"## Turns the sun and sets its brightness. Only a DIRECTIONAL 3D light has an angle worth",
		"## turning: its rotation is where the whole sky's light comes from, while a spot's rotation is",
		"## where somebody aimed it and a 2D light lies flat on the screen. So the turn belongs to a",
		"## DirectionalLight3D alone - point Sun Light at any other light and only its brightness moves,",
		"## which is exactly what that property's own tooltip promises - and the brightness is read off",
		"## whichever property this light spells brightness with.",
		"func _drive_the_sun(sun_node: Node, daylight: float) -> void:",
		"\tif sun_node == null:",
		"\t\treturn",
		"\tvar sun_3d: DirectionalLight3D = sun_node as DirectionalLight3D",
		"\tif sun_3d != null:",
		"\t\tsun_3d.rotation_degrees.x = -360.0 * _sun_turn()",
		"\tvar brightness: String = \"light_energy\" if \"light_energy\" in sun_node else \"energy\"",
		"\tif brightness in sun_node:",
		"\t\tsun_node.set(brightness, _sample(sun_brightness, daylight))",
		"",
		"## Sets the sky: a 3D scene's ambient and background energy live on its Environment, and a 2D",
		"## level's daylight is the CanvasModulate lifted from the colour it was authored with toward",
		"## white. Night keeps a floor of ambient light when no curve says otherwise, because a scene",
		"## nobody can see is a bug rather than a night.",
		"func _drive_the_sky(world_node: Node, daylight: float) -> void:",
		"\tvar darkness: CanvasModulate = world_node as CanvasModulate",
		"\tif darkness != null:",
		"\t\tdarkness.color = _authored_darkness.lerp(Color.WHITE, _sample(sky_tint_strength, daylight))",
		"\t\treturn",
		"\tvar holder: WorldEnvironment = world_node as WorldEnvironment",
		"\tif holder == null or holder.environment == null:",
		"\t\treturn",
		"\tholder.environment.ambient_light_energy = _sample(ambient_brightness, lerpf(0.15, 1.0, daylight))",
		"\tholder.environment.background_energy_multiplier = _sample(sky_tint_strength, daylight)"
	]))
	sheet.events.append(block)

	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"if not world_lighting.is_empty():",
		"\t# The colour a 2D level was authored with IS its night: read it once, before the first",
		"\t# frame writes over it, so the cycle lifts the designer's darkness rather than inventing one.",
		"\tvar darkness: CanvasModulate = get_node_or_null(world_lighting) as CanvasModulate",
		"\tif darkness != null:",
		"\t\t_authored_darkness = darkness.color",
		"_last_hour = int(floor(time_of_day))",
		"_drive_the_world()"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if _paused or day_length_minutes <= 0.0 or clock_scale <= 0.0:",
		"\treturn",
		"var previous: float = time_of_day",
		"# 24 game hours per Day Length Minutes of real time, scaled by whatever the clock is set to.",
		"time_of_day = fposmod(time_of_day + delta * (24.0 / (day_length_minutes * 60.0)) * clock_scale, 24.0)",
		"_announce_moments(previous, time_of_day)",
		"_drive_the_world()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return Lib.save_pack(sheet, "res://eventsheet_addons/day_night_cycle/day_night_cycle_behavior")


## One moment of the clock: a signal declared as a row, published as a trigger, and named the way a
## sheet reads it rather than the way the code spells it. `parameters` is empty for a moment that
## carries nothing, and one declaration ("hour: int") for the one that does.
static func _moment(sheet: EventSheetResource, signal_name: String, reads_as: String, parameters: String, about: String) -> void:
	var bell: SignalRow = SignalRow.new()
	bell.signal_name = signal_name
	bell.ace_name = reads_as
	bell.description = about
	bell.trigger = true
	bell.ace_category = sheet.addon_category
	if not parameters.is_empty():
		bell.params = PackedStringArray([parameters])
	sheet.events.append(bell)
