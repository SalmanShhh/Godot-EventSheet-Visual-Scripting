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
	descriptors.append(F.make_descriptor("Core", "AudioSetBusMuted", "Set Bus Muted", ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})", "", [F.make_param("bus", "String", "\"Music\"", "Bus", "Audio bus name (Master, Music, SFX, ...).", "expression"), F.make_param("muted", "bool", "true", "Muted", "true silences the bus, false restores it.", "expression")], CAT, "set bus {bus} muted {muted}")
		.described("Mutes or unmutes a whole bus - the options-menu music/SFX toggle in one action."))
	descriptors.append(F.make_descriptor("Core", "AudioSetBusSolo", "Set Bus Solo", ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_solo(AudioServer.get_bus_index({bus}), {solo})", "", [F.make_param("bus", "String", "\"Music\"", "Bus", "Audio bus name.", "expression"), F.make_param("solo", "bool", "true", "Solo", "true plays ONLY soloed buses.", "expression")], CAT, "set bus {bus} solo {solo}")
		.described("Solos a bus so only it (and other soloed buses) is heard - focus dialogue in a cutscene, audition a layer."))
	descriptors.append(F.make_descriptor("Core", "AudioSetBusBypass", "Set Bus Effects Bypassed", ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_bypass_effects(AudioServer.get_bus_index({bus}), {bypassed})", "", [F.make_param("bus", "String", "\"Music\"", "Bus", "Audio bus name.", "expression"), F.make_param("bypassed", "bool", "true", "Bypassed", "true skips every effect on the bus.", "expression")], CAT, "set bus {bus} effects bypassed {bypassed}")
		.described("Skips or restores ALL effects on a bus at once - dry vs processed in one flip."))
	descriptors.append(F.make_descriptor("Core", "AudioSetBusEffectEnabled", "Set Bus Effect Enabled", ACEDescriptor.ACEType.ACTION, "AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index}, {enabled})", "", [F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression"), F.make_param("effect_index", "int", "0", "Effect #", "The effect's slot on the bus (top = 0), as set up in the Audio panel.", "expression"), F.make_param("enabled", "bool", "true", "Enabled", "true turns the effect on.", "expression")], CAT, "set bus {bus} effect {effect_index} enabled {enabled}")
		.described("Flips ONE prepared effect on a bus - add a lowpass to Master in the Audio panel, then toggle it for the underwater/muffled state; same trick for cave reverb or a flashbang highpass.").featured())
	descriptors.append(F.make_descriptor("Core", "AudioSetPlaybackSpeed", "Set Audio Playback Speed", ACEDescriptor.ACEType.ACTION, "AudioServer.playback_speed_scale = {scale}", "", [F.make_param("scale", "float", "1.0", "Scale", "1 = normal, 0.5 = half speed (deeper), 2 = double.", "expression")], CAT, "set audio playback speed {scale}")
		.described("Scales EVERY sound's playback speed and pitch - set it alongside Slowmo so the world's audio drops with time, then back to 1.").featured())

	# ── Conditions ──
	descriptors.append(F.make_descriptor("Core", "AudioBusExists", "Bus Exists", ACEDescriptor.ACEType.CONDITION, "AudioServer.get_bus_index({bus}) >= 0", "", [F.make_param("bus", "String", "\"Music\"", "Bus", "Audio bus name.", "expression")], CAT, "bus {bus} exists")
		.described("True when a bus with this name is in the current bus layout - guard optional buses."))
	descriptors.append(F.make_descriptor("Core", "AudioIsBusEffectEnabled", "Is Bus Effect Enabled", ACEDescriptor.ACEType.CONDITION, "AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index})", "", [F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression"), F.make_param("effect_index", "int", "0", "Effect #", "The effect's slot on the bus (top = 0).", "expression")], CAT, "bus {bus} effect {effect_index} is enabled")
		.described("True while a bus effect slot is switched on - toggle states without a tracking variable."))

	# ── Expressions ──
	descriptors.append(F.make_descriptor("Core", "AudioBusPeakDb", "Bus Peak Volume (dB)", ACEDescriptor.ACEType.EXPRESSION, "AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index({bus}), 0)", "", [F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")], CAT, "bus {bus} peak dB")
		.described("The bus's current peak level in dB (very negative = silence) - drive a VU meter, ducking, or audio-reactive visuals."))
	descriptors.append(F.make_descriptor("Core", "AudioPlaybackSpeed", "Audio Playback Speed", ACEDescriptor.ACEType.EXPRESSION, "AudioServer.playback_speed_scale", "", [], CAT, "audio playback speed")
		.described("The current global playback speed scale."))
	descriptors.append(F.make_descriptor("Core", "AudioBusCount", "Bus Count", ACEDescriptor.ACEType.EXPRESSION, "AudioServer.get_bus_count()", "", [], CAT, "bus count")
		.described("How many buses the current layout has."))
	descriptors.append(F.make_descriptor("Core", "AudioOutputLatency", "Audio Output Latency", ACEDescriptor.ACEType.EXPRESSION, "AudioServer.get_output_latency()", "", [], CAT, "audio output latency")
		.described("The output latency in seconds - rhythm games subtract it when judging hits."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "The mixing desk from events - mute/solo/bypass buses, flip prepared bus effects (underwater lowpass, cave reverb), scale global playback speed with slowmo, and read peak levels for VU meters and ducking."}
