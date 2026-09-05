# EventForge module - Audio Server vocabulary (the mixing desk from events).
#
# The AudioServer controls games actually reach for: muting / soloing / bypassing buses,
# toggling bus EFFECTS (the underwater lowpass, the cave reverb - flip a prepared effect
# instead of coding DSP), the global playback speed (pairs with the Juice pack's Slowmo so
# pitch drops with time), and the metering expressions a VU bar or ducking rig reads.
# Everything compiles to plain AudioServer calls with zero plugin references, honouring the
# parity covenant. Buses are addressed by NAME, resolved with get_bus_index at the call.
# (Bus VOLUME + Is Bus Muted already live in the Options Menu vocabulary; not repeated here.)
@tool
class_name EventForgeAudioServerACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Audio Server"

## The runtime the sweep rows call - a real file in the project's own folder, plain typed GDScript
## with no plugin class named anywhere in it, exactly like the free-spot and world-look helpers the
## spawn and environment rows call. Named once here, and frozen with the templates that spell it.
const MIX_CALL: String = "EventForgeBusMix"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Actions ──
	descriptors.append(F.act("AudioSetBusMuted", "Set Bus Muted", "AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})", CAT, "set bus {bus} muted {muted}", "Mutes or unmutes a whole bus - the options-menu music/SFX toggle in one action.").param("bus", "\"Music\"", "Bus", "Audio bus name (Master, Music, SFX, ...).", "expression").param_typed("bool", "muted", "true", "Muted", "true silences the bus, false restores it.", "expression"))
	descriptors.append(F.act("AudioSetBusSolo", "Set Bus Solo", "AudioServer.set_bus_solo(AudioServer.get_bus_index({bus}), {solo})", CAT, "set bus {bus} solo {solo}", "Solos a bus so only it (and other soloed buses) is heard - focus dialogue in a cutscene, audition a layer.").param("bus", "\"Music\"", "Bus", "Audio bus name.", "expression").param_typed("bool", "solo", "true", "Solo", "true plays ONLY soloed buses.", "expression"))
	descriptors.append(F.act("AudioSetBusBypass", "Set Bus Effects Bypassed", "AudioServer.set_bus_bypass_effects(AudioServer.get_bus_index({bus}), {bypassed})", CAT, "set bus {bus} effects bypassed {bypassed}", "Skips or restores ALL effects on a bus at once - dry vs processed in one flip.").param("bus", "\"Music\"", "Bus", "Audio bus name.", "expression").param_typed("bool", "bypassed", "true", "Bypassed", "true skips every effect on the bus.", "expression"))
	descriptors.append(F.act("AudioSetBusEffectEnabled", "Set Bus Effect Enabled", "AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index}, {enabled})", CAT, "set bus {bus} effect {effect_index} enabled {enabled}", "Flips ONE prepared effect on a bus - add a lowpass to Master in the Audio panel, then toggle it for the underwater/muffled state; same trick for cave reverb or a flashbang highpass.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression").param_typed("int", "effect_index", "0", "Effect #", "The effect's slot on the bus (top = 0), as set up in the Audio panel.", "expression").param_typed("bool", "enabled", "true", "Enabled", "true turns the effect on.", "expression").featured())
	descriptors.append(F.act("AudioSetPlaybackSpeed", "Set Audio Playback Speed", "AudioServer.playback_speed_scale = {scale}", CAT, "set audio playback speed {scale}", "Scales EVERY sound's playback speed and pitch - set it alongside Slowmo so the world's audio drops with time, then back to 1.").param_typed("float", "scale", "1.0", "Scale", "1 = normal, 0.5 = half speed (deeper), 2 = double.", "expression").featured())

	# ── The sweeps: a bus's sound MOVED rather than switched ──
	# Each of these walks one number over time through an effect on the bus, added the first time and
	# reused after, and never through the bus volume the player set in the options screen. The walk is
	# one Tween, which the engine parks and frees the moment it lands, so a swept bus costs nothing at
	# rest. Restore Bus puts every kind back where it was resting before the first sweep touched it.
	descriptors.append(F.act("AudioMuffleBus", "Muffle Bus", "%s.muffle(self, {bus}, {cutoff_hz}, {seconds})" % MIX_CALL, CAT, "muffle bus {bus} to {cutoff_hz} Hz over {seconds} s", "Walks a bus underwater: a low-pass filter's cutoff slides down to the number you name over the seconds you name, so everything brighter than it goes quiet. A tenth of a second of this under a hitstop is what makes the hit feel heavy. The filter is added to the bus the FIRST time this runs, opened so wide it does nothing, and reused every time after - so the bus layout in the Audio panel gains one slot and never gains another. Restore Bus opens it again.").param_built(_bus_param("\"Master\"")).param_typed("float", "cutoff_hz", "400.0", "To Hz", "Where the cutoff lands. 400 is a pillow over the speaker, 1000 is a wall away, 20500 is not there at all.", "expression").param_built(_seconds_param("How long the walk down takes.")).featured())
	descriptors.append(F.act("AudioDiveBusVolume", "Dive Bus Volume", "%s.dive(self, {bus}, {volume_db}, {seconds})" % MIX_CALL, CAT, "dive bus {bus} to {volume_db} dB over {seconds} s", "Walks a bus's level down (or up) over time, so the sound effects duck under a line of dialogue or the whole world drops away under a slowmo. It moves an amplify effect on the bus, NOT the bus volume the player chose in the options screen - that one is theirs, and a beat that moved it would leave their setting wherever the beat happened to end. Restore Bus brings the level back.").param_built(_bus_param("\"SFX\"")).param_typed("float", "volume_db", "-12.0", "To dB", "Where the level lands. 0 is untouched, -12 is well under, -80 is silence.", "expression").param_built(_seconds_param("How long the dive takes.")))
	descriptors.append(F.act("AudioWashBus", "Wash Bus", "%s.wash(self, {bus}, {wetness}, {seconds})" % MIX_CALL, CAT, "wash bus {bus} to {wetness} over {seconds} s", "Grows a room behind the sound: a reverb's wet amount walks up over the seconds you name, with its dry left alone, so the sound is still there and now it is somewhere. A kill, a cave mouth, a dream. The reverb is added to the bus the first time this runs, silent until the walk starts, and it is the costliest of the three sweeps on a phone.").param_built(_bus_param("\"Master\"")).param_typed("float", "wetness", "0.5", "To Wet", "How much room, from 0 (none) to 1 (all of it).", "expression").param_built(_seconds_param("How long the room takes to grow.")))
	descriptors.append(F.act("AudioRestoreBus", "Restore Bus", "%s.restore(self, {bus}, {seconds})" % MIX_CALL, CAT, "restore bus {bus} over {seconds} s", "Walks every sweep this bus has been under back to where it was resting BEFORE the first one touched it - the cutoff open, the level as it was, the room gone. Home is where the mix was to start with, not where the last beat left it, so a moment can muffle and dive without ever saying how to come back and one row at the end of it puts the room right.").param_built(_bus_param("\"Master\"")).param_built(_seconds_param("How long the walk home takes.")).featured())
	descriptors.append(F.act("AudioSnapshotBuses", "Snapshot Buses As", "%s.snapshot({snapshot_name})" % MIX_CALL, CAT, "snapshot buses as {snapshot_name}", "Writes down what every bus is doing right now - its level, whether it is muted, whether it is soloed - under a name you choose. Nothing ships with this: there is no house \"underwater\" and no house \"paused\", because a game's mix is the game's. Take the first one at startup, call it normal, and every later recall has somewhere honest to come back to.").param("snapshot_name", "\"normal\"", "As", "The name to file this mix under. Recall Bus Snapshot takes the same name.", "expression"))
	descriptors.append(F.act("AudioRecallBusSnapshot", "Recall Bus Snapshot", "%s.recall(self, {snapshot_name}, {seconds})" % MIX_CALL, CAT, "recall bus snapshot {snapshot_name} over {seconds} s", "Puts a mix you snapshotted back. The levels are WALKED over the seconds you name; the mutes and the solos are cut at once, because there is nothing between silent and not silent to walk through. A name nobody has taken says so and changes nothing, rather than inventing a mix.").param("snapshot_name", "\"normal\"", "Snapshot", "The name a Snapshot Buses As row filed a mix under.", "expression").param_built(_seconds_param("How long the levels take to walk back. 0 puts them back at once.", "0.3")))

	# ── Conditions ──
	descriptors.append(F.cond("AudioBusIsSweeping", "Bus Is Sweeping", "%s.is_sweeping({bus})" % MIX_CALL, CAT, "bus {bus} is sweeping", "True while a Muffle, Dive, Wash or Restore on this bus is still walking. The question a second beat asks before starting a sweep over the top of the first one.").param_built(_bus_param("\"Master\"")))
	descriptors.append(F.cond("AudioHasBusSnapshot", "Bus Snapshot Exists", "%s.has_snapshot({snapshot_name})" % MIX_CALL, CAT, "bus snapshot {snapshot_name} exists", "True once a Snapshot Buses As row has filed a mix under this name in this run - the guard before a recall in a scene that may have been reached without passing the place the snapshot was taken.").param("snapshot_name", "\"normal\"", "Snapshot", "The name to ask about.", "expression"))
	descriptors.append(F.cond("AudioBusExists", "Bus Exists", "AudioServer.get_bus_index({bus}) >= 0", CAT, "bus {bus} exists", "True when a bus with this name is in the current bus layout - guard optional buses.").param("bus", "\"Music\"", "Bus", "Audio bus name.", "expression"))
	descriptors.append(F.cond("AudioIsBusEffectEnabled", "Is Bus Effect Enabled", "AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index})", CAT, "bus {bus} effect {effect_index} is enabled", "True while a bus effect slot is switched on - toggle states without a tracking variable.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression").param_typed("int", "effect_index", "0", "Effect #", "The effect's slot on the bus (top = 0).", "expression"))

	# ── Expressions ──
	descriptors.append(F.expr("AudioBusPeakDb", "Bus Peak Volume (dB)", "AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index({bus}), 0)", CAT, "bus {bus} peak dB", "The bus's current peak level in dB (very negative = silence) - drive a VU meter, ducking, or audio-reactive visuals.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression"))
	descriptors.append(F.expr("AudioPlaybackSpeed", "Audio Playback Speed", "AudioServer.playback_speed_scale", CAT, "audio playback speed", "The current global playback speed scale."))
	descriptors.append(F.expr("AudioBusCount", "Bus Count", "AudioServer.get_bus_count()", CAT, "bus count", "How many buses the current layout has."))
	descriptors.append(F.expr("AudioOutputLatency", "Audio Output Latency", "AudioServer.get_output_latency()", CAT, "audio output latency", "The output latency in seconds - rhythm games subtract it when judging hits."))

	return descriptors


## The bus a row acts on, addressed by name and resolved at the call, exactly as every other row in
## this module addresses one. The default differs per row - a muffle is usually on Master and a dive
## usually on the effects - so the starting name is the argument.
static func _bus_param(starts_on: String) -> ACEParam:
	return F.make_param("bus", "String", starts_on, "Bus",
		"Audio bus name (Master, Music, SFX, ...).", "expression")


## How long a sweep takes. One builder, because four rows ask the same question and a beat's tenth of
## a second reads the same on all of them.
static func _seconds_param(words: String, starts_on: String = "0.12") -> ACEParam:
	return F.make_param("seconds", "float", starts_on, "Over Seconds", words, "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "The mixing desk from events - mute/solo/bypass buses, flip prepared bus effects (underwater lowpass, cave reverb), scale global playback speed with slowmo, and read peak levels for VU meters and ducking."}
