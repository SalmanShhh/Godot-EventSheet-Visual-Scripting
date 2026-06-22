# EventForge module — Audio (the C3 Audio addon, the Godot way).
#
# C3's Audio is a global, tag-based mixer. Godot's idiom is nodes + buses, so the
# vocabulary splits in three, all compiling to plain GDScript (parity contract):
#   1. FIRE-AND-FORGET one-shots ("Play sound"): a throwaway AudioStreamPlayer(2D) that
#      frees itself on finish — C3's most common Play call, zero bookkeeping, zero
#      plugin runtime (the multi-line/{uid} template machinery bakes a private local).
#   2. PLAYER-SCOPED ACEs (node_type AudioStreamPlayer): attach a sheet/behavior to a
#      player node for music & controlled playback — play/stop/seek/volume/pitch,
#      C3's "by tag" control mapped to "by node", the Godot-contextual answer.
#   3. BUS ACEs (Godot extra, no C3 equivalent): master/SFX/Music volume + mute — what
#      C3 users build tag-groups for, native here.
#
# Sound params use hint "audio_path": the params dialog shows a ▶ preview button so you
# can hear the file before applying (see ACEParamsDialog._create_audio_path_field).
@tool
extends RefCounted
class_name EventForgeAudioACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# 1 — Fire-and-forget one-shots (C3 "Play").
	descriptors.append(F.make_descriptor("Core", "PlaySound", "Play Sound", ACEDescriptor.ACEType.ACTION,
		"var __sfx_{uid} = AudioStreamPlayer.new()\n__sfx_{uid}.stream = load({path})\nif __sfx_{uid}.stream == null:\n\t__sfx_{uid}.queue_free()\nelse:\n\t__sfx_{uid}.bus = {bus}\n\t__sfx_{uid}.volume_db = {volume_db}\n\tadd_child(__sfx_{uid})\n\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)\n\t__sfx_{uid}.play()",
		"", [
			F.make_param("path", "String", "\"res://sound.ogg\"", "Sound", "Audio file to play once.", "audio_path"),
			F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression"),
			F.make_param("volume_db", "String", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression")
		], "Audio", "Play sound {path}"))
	descriptors.append(F.make_descriptor("Core", "PlaySoundAt", "Play Sound At (2D)", ACEDescriptor.ACEType.ACTION,
		"var __sfx_{uid} = AudioStreamPlayer2D.new()\n__sfx_{uid}.stream = load({path})\nif __sfx_{uid}.stream == null:\n\t__sfx_{uid}.queue_free()\nelse:\n\t__sfx_{uid}.global_position = {position}\n\tadd_child(__sfx_{uid})\n\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)\n\t__sfx_{uid}.play()",
		"", [
			F.make_param("path", "String", "\"res://sound.ogg\"", "Sound", "Audio file to play once, positionally.", "audio_path"),
			F.make_param("position", "String", "global_position", "Position", "World position (2D falloff).", "expression")
		], "Audio", "Play sound {path} at {position}", "Node2D"))

	# 2 — Player-scoped (music & controlled playback; attach to an AudioStreamPlayer).
	descriptors.append(F.make_descriptor("Core", "AudioPlay", "Play", ACEDescriptor.ACEType.ACTION,
		"play({from})", "", [F.make_param("from", "String", "0.0", "From (s)", "Start position in seconds.", "expression")],
		"Audio", "Play from {from}s", "AudioStreamPlayer"))
	descriptors.append(F.make_descriptor("Core", "AudioPlayStream", "Play Sound File", ACEDescriptor.ACEType.ACTION,
		"stream = load({path})\nplay()", "", [F.make_param("path", "String", "\"res://music.ogg\"", "Sound", "Audio file to load and play.", "audio_path")],
		"Audio", "Play file {path}", "AudioStreamPlayer"))
	descriptors.append(F.make_descriptor("Core", "AudioStop", "Stop", ACEDescriptor.ACEType.ACTION,
		"stop()", "", [], "Audio", "Stop", "AudioStreamPlayer"))
	descriptors.append(F.make_descriptor("Core", "AudioSeek", "Seek", ACEDescriptor.ACEType.ACTION,
		"seek({seconds})", "", [F.make_param("seconds", "String", "0.0", "Seconds", "Playback position.", "expression")],
		"Audio", "Seek to {seconds}s", "AudioStreamPlayer"))
	descriptors.append(F.make_descriptor("Core", "AudioSetVolume", "Set Volume", ACEDescriptor.ACEType.ACTION,
		"volume_db = {db}", "", [F.make_param("db", "String", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression")],
		"Audio", "Set volume to {db} dB", "AudioStreamPlayer"))
	descriptors.append(F.make_descriptor("Core", "AudioSetPitch", "Set Playback Rate", ACEDescriptor.ACEType.ACTION,
		"pitch_scale = {pitch}", "", [F.make_param("pitch", "String", "1.0", "Pitch", "1 = normal speed/pitch.", "expression")],
		"Audio", "Set playback rate {pitch}x", "AudioStreamPlayer"))
	descriptors.append(F.make_descriptor("Core", "AudioIsPlaying", "Is Playing", ACEDescriptor.ACEType.CONDITION,
		"playing", "", [], "Audio", "is playing", "AudioStreamPlayer"))
	descriptors.append(F.make_descriptor("Core", "AudioGetPosition", "Playback Position", ACEDescriptor.ACEType.EXPRESSION,
		"get_playback_position()", "", [], "Audio", "playback position", "AudioStreamPlayer"))

	# 3 — Bus control (Godot extras; C3 users fake these with tag groups).
	var bus_param: ACEParam = F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")
	descriptors.append(F.make_descriptor("Core", "SetBusVolume", "Set Bus Volume", ACEDescriptor.ACEType.ACTION,
		"AudioServer.set_bus_volume_db(AudioServer.get_bus_index({bus}), {db})", "", [
			bus_param,
			F.make_param("db", "String", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression")
		], "Audio", "Set bus {bus} volume to {db} dB"))
	descriptors.append(F.make_descriptor("Core", "SetBusMute", "Mute Bus", ACEDescriptor.ACEType.ACTION,
		"AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})", "", [
			F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression"),
			F.make_param("muted", "String", "true", "Muted", "true to silence the bus.", "", ["true", "false"])
		], "Audio", "Set bus {bus} muted: {muted}"))
	descriptors.append(F.make_descriptor("Core", "GetBusVolume", "Bus Volume", ACEDescriptor.ACEType.EXPRESSION,
		"AudioServer.get_bus_volume_db(AudioServer.get_bus_index({bus}))", "", [
			F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")
		], "Audio", "bus {bus} volume"))

	return descriptors
