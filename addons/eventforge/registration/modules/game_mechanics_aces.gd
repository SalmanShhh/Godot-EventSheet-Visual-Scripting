# EventForge module - the game shapes every project writes by hand
#
# Meters that fill and drain at a rate, the noise one object makes and others hear, a boss fight's
# phase ladder and its invulnerability window, and a mission clock shown as minutes and seconds.
# Each template is the exact line the reading recognises, so a row dropped from the picker and a
# line typed by hand are the same sentence and the file round-trips either way.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeGameMechanicsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker sections these verbs cluster under.
const CATEGORY_METERS := "Meters"
const CATEGORY_STEALTH := "Stealth"
const CATEGORY_BOSS := "Boss"
const CATEGORY_MISSIONS := "Missions"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append_array(_meter_descriptors())
	descriptors.append_array(_stealth_descriptors())
	descriptors.append_array(_boss_descriptors())
	descriptors.append_array(_mission_descriptors())
	return descriptors


## A meter is a number that moves at a SPEED and stops at a limit - the countdown's two-way
## twin. Both halves clamp, because a meter that overshoots its limit is a bug every project fixes
## the same way and nobody enjoys writing twice.
static func _meter_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "FillMeter", "Fill Meter",
		ACEDescriptor.ACEType.ACTION, "{var_name} = minf({var_name} + {rate} * delta, {cap})", "",
		[
			F.make_param("var_name", "String", "meter", "Meter", "The number to fill.", "variable_reference"),
			F.make_param("rate", "String", "40.0", "Per second", "How much it gains each second.", "expression"),
			F.make_param("cap", "String", "100.0", "Up to", "The value it stops at.", "expression")
		], CATEGORY_METERS, "Fill [b]{var_name}[/b] at [b]{rate}[/b] up to [b]{cap}[/b]")
		.described("Raises a number at a steady rate per second and stops it at a limit - a suspicion meter filling while a guard sees you, a bar charging, stamina coming back.").featured())
	descriptors.append(F.make_descriptor("Core", "DrainMeter", "Drain Meter",
		ACEDescriptor.ACEType.ACTION, "{var_name} = maxf({var_name} - {rate} * delta, {floor})", "",
		[
			F.make_param("var_name", "String", "meter", "Meter", "The number to drain.", "variable_reference"),
			F.make_param("rate", "String", "15.0", "Per second", "How much it loses each second.", "expression"),
			F.make_param("floor", "String", "0.0", "Down to", "The value it stops at.", "expression")
		], CATEGORY_METERS, "Drain [b]{var_name}[/b] at [b]{rate}[/b] down to [b]{floor}[/b]")
		.described("Lowers a number at a steady rate per second and stops it at a floor - suspicion cooling off, a shield decaying, a charge bleeding away.").featured())
	return descriptors


## Sound as a first-class event: one object makes a noise somewhere, and everything close
## enough to hear it is told where. The walk over the hearers is what a hand-written script spells
## out; here it is one row, and the receiving half is a trigger.
static func _stealth_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "MakeNoise", "Make Noise",
		ACEDescriptor.ACEType.ACTION,
		"for __heard_{uid} in get_tree().get_nodes_in_group({group}):\n\tif __heard_{uid}.global_position.distance_to({at}) < {radius}:\n\t\t__heard_{uid}.hear({at})",
		"",
		[
			F.make_param("at", "String", "Vector2.ZERO", "At", "Where the noise happened (a position expression).", "expression"),
			F.make_param("radius", "String", "200.0", "Heard within", "How far the noise carries.", "expression"),
			F.make_param("group", "String", "\"hears_noise\"", "Heard by", "The group whose members can hear - each one needs an On Noise Heard event.", "group_reference")
		], CATEGORY_STEALTH, "Make noise at [b]{at}[/b], heard within [b]{radius}[/b]")
		.described("Tells everything in the listening group that a noise happened at a place, but only the ones close enough to hear it. Footsteps, a door, a thrown bottle.").featured())
	descriptors.append(F.make_descriptor("Core", "OnNoiseHeard", "On Noise Heard",
		ACEDescriptor.ACEType.TRIGGER, "", "hear", [], CATEGORY_STEALTH,
		"On noise heard at")
		.described("Runs when a Make Noise action happens close enough for this object to hear it, with the place it came from. Put this object in the listening group first (Add To Group, on created)."))
	return descriptors


## The two halves of every boss fight nobody wants to hand-write twice: the ladder of health
## thresholds each phase starts at, and the window after a hit when nothing lands.
static func _boss_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "BossPhaseStarts", "Phase Starts",
		ACEDescriptor.ACEType.CONDITION,
		"{phase_var} < {phase} and {hp} <= {max_hp} * {share}", "",
		[
			F.make_param("phase", "String", "2", "Phase", "The phase number that starts here.", "expression"),
			F.make_param("share", "String", "0.6", "At share of maximum", "The health share it starts at - 0.6 is 60%.", "expression"),
			F.make_param("hp", "String", "hp", "Health", "The variable holding health now.", "variable_reference"),
			F.make_param("max_hp", "String", "max_hp", "Maximum health", "The variable holding full health.", "variable_reference"),
			F.make_param("phase_var", "String", "phase", "Phase variable", "The variable holding which phase the fight is in - set it in the actions below.", "variable_reference")
		], CATEGORY_BOSS,
		"Phase [b]{phase}[/b] starts ([b]{hp}[/b] <= [b]{share}[/b] of [b]{max_hp}[/b], once)")
		.described("True the one time health first falls past a share of its maximum while the fight is in an earlier phase. The phase guard is what makes it happen once: set the phase variable in the actions under this condition.").featured())
	descriptors.append(F.make_descriptor("Core", "SetInvulnerableFor", "Set Invulnerable For",
		ACEDescriptor.ACEType.ACTION,
		"{flag} = true\nawait get_tree().create_timer({seconds}).timeout\n{flag} = false", "",
		[
			F.make_param("flag", "String", "invulnerable", "Flag", "The boolean that says nothing lands.", "variable_reference"),
			F.make_param("seconds", "String", "0.5", "For seconds", "How long the window lasts.", "expression")
		], CATEGORY_BOSS, "Set [b]{flag}[/b] for [b]{seconds}[/b] seconds")
		.described("Turns a flag on, waits, and turns it back off - the invulnerability window after a hit, written once instead of as a flag and a timer that can drift apart."))
	return descriptors


## A mission clock is an ordinary countdown with a deadline and an audience: the one thing it
## needs that a cooldown does not is to be READABLE, which is what m:ss is for.
static func _mission_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.make_descriptor("Core", "StartMissionTimer", "Start Mission Timer",
		ACEDescriptor.ACEType.ACTION, "{var_name} = {seconds}", "",
		[
			F.make_param("var_name", "String", "mission_time_left", "Timer variable", "The variable holding the seconds left.", "variable_reference"),
			F.make_param("seconds", "String", "180.0", "Time", "How long the mission runs - type it as minutes:seconds.", "minutes_seconds")
		], CATEGORY_MISSIONS, "Start [b]{var_name}[/b] at [b]{seconds}[/b]")
		.described("Puts a number of seconds on the mission clock. Type the time the way a player reads it - 3:00 - and the row stores the seconds.").featured())
	descriptors.append(F.make_descriptor("Core", "AddMissionTime", "Add Mission Time",
		ACEDescriptor.ACEType.ACTION, "{var_name} += {seconds}", "",
		[
			F.make_param("var_name", "String", "mission_time_left", "Timer variable", "The variable holding the seconds left.", "variable_reference"),
			F.make_param("seconds", "String", "30.0", "Time", "How much time to add - type it as minutes:seconds.", "minutes_seconds")
		], CATEGORY_MISSIONS, "Add [b]{seconds}[/b] to [b]{var_name}[/b]")
		.described("Puts time back on the mission clock - the pickup that buys you another half minute."))
	descriptors.append(F.make_descriptor("Core", "MissionTimeLeft", "Mission Time Left",
		ACEDescriptor.ACEType.EXPRESSION,
		"(\"%02d:%02d\" % [int({var_name}) / 60, int({var_name}) % 60])", "",
		[
			F.make_param("var_name", "String", "mission_time_left", "Timer variable", "The variable holding the seconds left.", "variable_reference")
		], CATEGORY_MISSIONS, "Missions.TimeLeft")
		.described("Gives the time left as text a player can read - \"2:41\" - ready to drop into a HUD label.").featured())
	return descriptors
