# EventForge module — Audio (the Audio vocabulary, the Godot way).
#
# A global, tag-based mixer is one approach; Godot's idiom is nodes + buses, so the
# vocabulary splits in three, all compiling to plain GDScript (parity contract):
#   1. FIRE-AND-FORGET one-shots ("Play sound"): a throwaway AudioStreamPlayer(2D) that
#      frees itself on finish — the most common Play call, zero bookkeeping, zero
#      plugin runtime (the multi-line/{uid} template machinery bakes a private local).
#   2. PLAYER-SCOPED ACEs (node_type AudioStreamPlayer): attach a sheet/behavior to a
#      player node for music & controlled playback — play/stop/seek/volume/pitch,
#      "by tag" control mapped to "by node", the Godot-contextual answer.
#   3. BUS ACEs (Godot extra): master/SFX/Music volume + mute — what
#      tag-groups stand in for elsewhere, native here.
#
# Sound params use hint "audio_path": the params dialog shows a ▶ preview button so you
# can hear the file before applying (see ACEParamsDialog._create_audio_path_field).
@tool
extends RefCounted
class_name EventForgeAudioACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# 1 — Fire-and-forget one-shots ("Play").
	descriptors.append(F.make_descriptor("Core", "PlaySound", "Play Sound", ACEDescriptor.ACEType.ACTION,
		"var __sfx_{uid} = AudioStreamPlayer.new()\n__sfx_{uid}.stream = load({path})\nif __sfx_{uid}.stream == null:\n\t__sfx_{uid}.queue_free()\nelse:\n\t__sfx_{uid}.bus = {bus}\n\t__sfx_{uid}.volume_db = {volume_db}\n\tadd_child(__sfx_{uid})\n\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)\n\t__sfx_{uid}.play()",
		"", [
			F.make_param("path", "String", "\"res://sound.ogg\"", "Sound", "Audio file to play once.", "audio_path"),
			F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression"),
			F.make_param("volume_db", "String", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression")
		], "Audio", "Play sound {path}")
		.described("Plays a sound file once on a chosen bus and volume, then cleans itself up."))
	descriptors.append(F.make_descriptor("Core", "PlaySoundAt", "Play Sound At (2D)", ACEDescriptor.ACEType.ACTION,
		"var __sfx_{uid} = AudioStreamPlayer2D.new()\n__sfx_{uid}.stream = load({path})\nif __sfx_{uid}.stream == null:\n\t__sfx_{uid}.queue_free()\nelse:\n\t__sfx_{uid}.global_position = {position}\n\tadd_child(__sfx_{uid})\n\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)\n\t__sfx_{uid}.play()",
		"", [
			F.make_param("path", "String", "\"res://sound.ogg\"", "Sound", "Audio file to play once, positionally.", "audio_path"),
			F.make_param("position", "String", "global_position", "Position", "World position (2D falloff).", "expression")
		], "Audio", "Play sound {path} at {position}", "Node2D")
		.described("Plays a sound at a world position so it gets louder or quieter with distance."))

	# 2 — Player-scoped (music & controlled playback; attach to an AudioStreamPlayer).
	descriptors.append(F.make_descriptor("Core", "AudioPlay", "Play", ACEDescriptor.ACEType.ACTION,
		"play({from})", "", [F.make_param("from", "String", "0.0", "From (s)", "Start position in seconds.", "expression")],
		"Audio", "Play from {from}s", "AudioStreamPlayer")
		.described("Starts this audio player, optionally from a given time in seconds."))
	descriptors.append(F.make_descriptor("Core", "AudioPlayStream", "Play Sound File", ACEDescriptor.ACEType.ACTION,
		"stream = load({path})\nplay()", "", [F.make_param("path", "String", "\"res://music.ogg\"", "Sound", "Audio file to load and play.", "audio_path")],
		"Audio", "Play file {path}", "AudioStreamPlayer")
		.described("Loads an audio file into this player and starts playing it."))
	descriptors.append(F.make_descriptor("Core", "AudioStop", "Stop", ACEDescriptor.ACEType.ACTION,
		"stop()", "", [], "Audio", "Stop", "AudioStreamPlayer")
		.described("Stops this audio player from playing right now."))
	descriptors.append(F.make_descriptor("Core", "AudioSeek", "Seek", ACEDescriptor.ACEType.ACTION,
		"seek({seconds})", "", [F.make_param("seconds", "String", "0.0", "Seconds", "Playback position.", "expression")],
		"Audio", "Seek to {seconds}s", "AudioStreamPlayer")
		.described("Jumps this audio player's playback to a specific time in seconds."))
	descriptors.append(F.make_descriptor("Core", "AudioSetVolume", "Set Volume", ACEDescriptor.ACEType.ACTION,
		"volume_db = {db}", "", [F.make_param("db", "String", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression")],
		"Audio", "Set volume to {db} dB", "AudioStreamPlayer")
		.described("Sets how loud this audio player is, in decibels (0 = full, -80 = silent)."))
	descriptors.append(F.make_descriptor("Core", "AudioSetPitch", "Set Playback Rate", ACEDescriptor.ACEType.ACTION,
		"pitch_scale = {pitch}", "", [F.make_param("pitch", "String", "1.0", "Pitch", "1 = normal speed/pitch.", "expression")],
		"Audio", "Set playback rate {pitch}x", "AudioStreamPlayer")
		.described("Changes this player's speed and pitch (1 = normal, higher = faster)."))
	descriptors.append(F.make_descriptor("Core", "AudioIsPlaying", "Is Playing", ACEDescriptor.ACEType.CONDITION,
		"playing", "", [], "Audio", "is playing", "AudioStreamPlayer")
		.described("True when this audio player is currently making sound."))
	descriptors.append(F.make_descriptor("Core", "AudioGetPosition", "Playback Position", ACEDescriptor.ACEType.EXPRESSION,
		"get_playback_position()", "", [], "Audio", "playback position", "AudioStreamPlayer")
		.described("Gives the current playback time of this audio player, in seconds."))

	# 3 — Bus control (Godot extras; event-sheet users fake these with tag groups).
	var bus_param: ACEParam = F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")
	descriptors.append(F.make_descriptor("Core", "SetBusVolume", "Set Bus Volume", ACEDescriptor.ACEType.ACTION,
		"AudioServer.set_bus_volume_db(AudioServer.get_bus_index({bus}), {db})", "", [
			bus_param,
			F.make_param("db", "String", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression")
		], "Audio", "Set bus {bus} volume to {db} dB")
		.described("Sets the volume of a named audio bus, like Music or SFX."))
	descriptors.append(F.make_descriptor("Core", "SetBusMute", "Mute Bus", ACEDescriptor.ACEType.ACTION,
		"AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})", "", [
			F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression"),
			F.make_param("muted", "String", "true", "Muted", "true to silence the bus.", "", ["true", "false"])
		], "Audio", "Set bus {bus} muted: {muted}")
		.described("Mutes or unmutes a named audio bus all at once."))
	descriptors.append(F.make_descriptor("Core", "GetBusVolume", "Bus Volume", ACEDescriptor.ACEType.EXPRESSION,
		"AudioServer.get_bus_volume_db(AudioServer.get_bus_index({bus}))", "", [
			F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")
		], "Audio", "bus {bus} volume")
		.described("Gives the current volume of a named audio bus, in decibels."))

	return descriptors
