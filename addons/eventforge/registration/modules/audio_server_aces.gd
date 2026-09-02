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


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Actions ──
	descriptors.append(F.act("AudioSetBusMuted", "Set Bus Muted", "AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})", CAT, "set bus {bus} muted {muted}", "Mutes or unmutes a whole bus - the options-menu music/SFX toggle in one action.").param("bus", "\"Music\"", "Bus", "Audio bus name (Master, Music, SFX, ...).", "expression").param_typed("bool", "muted", "true", "Muted", "true silences the bus, false restores it.", "expression"))
	descriptors.append(F.act("AudioSetBusSolo", "Set Bus Solo", "AudioServer.set_bus_solo(AudioServer.get_bus_index({bus}), {solo})", CAT, "set bus {bus} solo {solo}", "Solos a bus so only it (and other soloed buses) is heard - focus dialogue in a cutscene, audition a layer.").param("bus", "\"Music\"", "Bus", "Audio bus name.", "expression").param_typed("bool", "solo", "true", "Solo", "true plays ONLY soloed buses.", "expression"))
	descriptors.append(F.act("AudioSetBusBypass", "Set Bus Effects Bypassed", "AudioServer.set_bus_bypass_effects(AudioServer.get_bus_index({bus}), {bypassed})", CAT, "set bus {bus} effects bypassed {bypassed}", "Skips or restores ALL effects on a bus at once - dry vs processed in one flip.").param("bus", "\"Music\"", "Bus", "Audio bus name.", "expression").param_typed("bool", "bypassed", "true", "Bypassed", "true skips every effect on the bus.", "expression"))
	descriptors.append(F.act("AudioSetBusEffectEnabled", "Set Bus Effect Enabled", "AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index}, {enabled})", CAT, "set bus {bus} effect {effect_index} enabled {enabled}", "Flips ONE prepared effect on a bus - add a lowpass to Master in the Audio panel, then toggle it for the underwater/muffled state; same trick for cave reverb or a flashbang highpass.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression").param_typed("int", "effect_index", "0", "Effect #", "The effect's slot on the bus (top = 0), as set up in the Audio panel.", "expression").param_typed("bool", "enabled", "true", "Enabled", "true turns the effect on.", "expression").featured())
	descriptors.append(F.act("AudioSetPlaybackSpeed", "Set Audio Playback Speed", "AudioServer.playback_speed_scale = {scale}", CAT, "set audio playback speed {scale}", "Scales EVERY sound's playback speed and pitch - set it alongside Slowmo so the world's audio drops with time, then back to 1.").param_typed("float", "scale", "1.0", "Scale", "1 = normal, 0.5 = half speed (deeper), 2 = double.", "expression").featured())

	# ── Conditions ──
	descriptors.append(F.cond("AudioBusExists", "Bus Exists", "AudioServer.get_bus_index({bus}) >= 0", CAT, "bus {bus} exists", "True when a bus with this name is in the current bus layout - guard optional buses.").param("bus", "\"Music\"", "Bus", "Audio bus name.", "expression"))
	descriptors.append(F.cond("AudioIsBusEffectEnabled", "Is Bus Effect Enabled", "AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index})", CAT, "bus {bus} effect {effect_index} is enabled", "True while a bus effect slot is switched on - toggle states without a tracking variable.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression").param_typed("int", "effect_index", "0", "Effect #", "The effect's slot on the bus (top = 0).", "expression"))

	# ── Expressions ──
	descriptors.append(F.expr("AudioBusPeakDb", "Bus Peak Volume (dB)", "AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index({bus}), 0)", CAT, "bus {bus} peak dB", "The bus's current peak level in dB (very negative = silence) - drive a VU meter, ducking, or audio-reactive visuals.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression"))
	descriptors.append(F.expr("AudioPlaybackSpeed", "Audio Playback Speed", "AudioServer.playback_speed_scale", CAT, "audio playback speed", "The current global playback speed scale."))
	descriptors.append(F.expr("AudioBusCount", "Bus Count", "AudioServer.get_bus_count()", CAT, "bus count", "How many buses the current layout has."))
	descriptors.append(F.expr("AudioOutputLatency", "Audio Output Latency", "AudioServer.get_output_latency()", CAT, "audio output latency", "The output latency in seconds - rhythm games subtract it when judging hits."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "The mixing desk from events - mute/solo/bypass buses, flip prepared bus effects (underwater lowpass, cave reverb), scale global playback speed with slowmo, and read peak levels for VU meters and ducking."}
