# EventForge module - Audio (the Audio vocabulary, the Godot way).
#
# A global, tag-based mixer is one approach; Godot's idiom is nodes + buses, so the
# vocabulary splits in three, all compiling to plain GDScript (parity contract):
#   1. FIRE-AND-FORGET one-shots ("Play sound"): a throwaway AudioStreamPlayer(2D) that
#      frees itself on finish - the most common Play call, zero bookkeeping, zero
#      plugin runtime (the multi-line/{uid} template machinery bakes a private local).
#   2. PLAYER-SCOPED ACEs (node_type AudioStreamPlayer): attach a sheet/behavior to a
#      player node for music & controlled playback - play/stop/seek/volume/pitch,
#      "by tag" control mapped to "by node", the Godot-contextual answer.
#   3. BUS ACEs (Godot extra): master/SFX/Music volume + mute - what
#      tag-groups stand in for elsewhere, native here.
#
# Sound params use hint "audio_path": the params dialog shows a ▶ preview button so you
# can hear the file before applying (see ACEParamsDialog._create_audio_path_field).
@tool
class_name EventForgeAudioACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# 1 - Fire-and-forget one-shots ("Play"). Each Play remembers its throwaway player as
	# "__last_sfx" meta on the emitting node, so the last-sound ACEs below can retune the
	# shot that JUST fired (the event-sheet "last played sound" idiom) - still zero plugin
	# runtime, still self-freeing.
	descriptors.append(F.act("PlaySound", "Play Sound", "var __sfx_{uid} = AudioStreamPlayer.new()\n__sfx_{uid}.stream = load({path})\nif __sfx_{uid}.stream == null:\n\t__sfx_{uid}.queue_free()\nelse:\n\t__sfx_{uid}.bus = {bus}\n\t__sfx_{uid}.volume_db = {volume_db}\n\tadd_child(__sfx_{uid})\n\tset_meta(\"__last_sfx\", __sfx_{uid})\n\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)\n\t__sfx_{uid}.play()", "Audio", "Play sound {path}", "Plays a sound file once on a chosen bus and volume, then cleans itself up. Remembers the shot as the LAST SOUND, so Set Last Sound Playback Rate right after can retune it.").param("path", "\"res://sound.ogg\"", "Sound", "Audio file to play once.", "audio_path").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression").param("volume_db", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression"))
	descriptors.append(F.act("PlaySoundAt", "Play Sound At (2D)", "var __sfx_{uid} = AudioStreamPlayer2D.new()\n__sfx_{uid}.stream = load({path})\nif __sfx_{uid}.stream == null:\n\t__sfx_{uid}.queue_free()\nelse:\n\t__sfx_{uid}.global_position = {position}\n\tadd_child(__sfx_{uid})\n\tset_meta(\"__last_sfx\", __sfx_{uid})\n\t__sfx_{uid}.finished.connect(__sfx_{uid}.queue_free)\n\t__sfx_{uid}.play()", "Audio", "Play sound {path} at {position}", "Plays a sound at a world position so it gets louder or quieter with distance. Remembers the shot as the LAST SOUND for the last-sound actions.", "Node2D").param("path", "\"res://sound.ogg\"", "Sound", "Audio file to play once, positionally.", "audio_path").param("position", "global_position", "Position", "World position (2D falloff).", "expression"))

	# 1b - Last-sound control: retune the one-shot that just fired. The classic use is
	# pitch variation - Play Sound, then Set Last Sound Playback Rate randf_range(0.9, 1.1)
	# so repeated hits never sound machine-gun identical. Each node remembers ITS OWN last
	# shot (the meta lives on the emitting node); the guard makes a finished-and-freed shot
	# a safe no-op.
	descriptors.append(F.act("SetLastSoundRate", "Set Last Sound Playback Rate", "var __last_sfx_{uid} = get_meta(\"__last_sfx\", null)\nif is_instance_valid(__last_sfx_{uid}):\n\t__last_sfx_{uid}.pitch_scale = {rate}", "Audio", "Set last sound rate {rate}x", "Changes the speed and pitch of the sound the last Play Sound started (1 = normal). Put it right after Play Sound - the default randf_range(0.9, 1.1) gives every shot a slightly different pitch.").param("rate", "randf_range(0.9, 1.1)", "Rate", "1 = normal speed/pitch; the default randomizes a little for natural variation.", "expression"))
	descriptors.append(F.act("SetLastSoundVolume", "Set Last Sound Volume", "var __last_sfx_{uid} = get_meta(\"__last_sfx\", null)\nif is_instance_valid(__last_sfx_{uid}):\n\t__last_sfx_{uid}.volume_db = {db}", "Audio", "Set last sound volume {db} dB", "Changes the volume of the sound the last Play Sound started, in decibels.").param("db", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression"))
	descriptors.append(F.act("StopLastSound", "Stop Last Sound", "var __last_sfx_{uid} = get_meta(\"__last_sfx\", null)\nif is_instance_valid(__last_sfx_{uid}):\n\t__last_sfx_{uid}.queue_free()", "Audio", "Stop last sound", "Silences and frees the sound the last Play Sound started (one-shots are throwaway players, so stopping IS freeing)."))

	# 2 - Player-scoped (music & controlled playback; attach to an AudioStreamPlayer).
	descriptors.append(F.act("AudioPlay", "Play", "play({from})", "Audio", "Play from {from}s", "Starts this audio player, optionally from a given time in seconds.", "AudioStreamPlayer").param("from", "0.0", "From (s)", "Start position in seconds.", "expression"))
	descriptors.append(F.act("AudioPlayStream", "Play Sound File", "stream = load({path})\nplay()", "Audio", "Play file {path}", "Loads an audio file into this player and starts playing it.", "AudioStreamPlayer").param("path", "\"res://music.ogg\"", "Sound", "Audio file to load and play.", "audio_path"))
	descriptors.append(F.act("AudioStop", "Stop", "stop()", "Audio", "Stop", "Stops this audio player from playing right now.", "AudioStreamPlayer"))
	descriptors.append(F.act("AudioSeek", "Seek", "seek({seconds})", "Audio", "Seek to {seconds} seconds", "Jumps this audio player's playback to a specific time in seconds.", "AudioStreamPlayer").param("seconds", "0.0", "Seconds", "Playback position.", "expression"))
	descriptors.append(F.act("AudioSetVolume", "Set Volume", "volume_db = {db}", "Audio", "Set volume to {db} dB", "Sets how loud this audio player is, in decibels (0 = full, -80 = silent).", "AudioStreamPlayer").param("db", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression"))
	descriptors.append(F.act("AudioSetPitch", "Set Pitch", "pitch_scale = {pitch}", "Audio", "Set pitch to {pitch}", "Changes this player's speed and pitch (1 = normal, higher = faster).", "AudioStreamPlayer").param("pitch", "1.0", "Pitch", "1 = normal speed/pitch.", "expression"))
	descriptors.append(F.cond("AudioIsPlaying", "Is Playing", "playing", "Audio", "Is playing", "True when this audio player is currently making sound.", "AudioStreamPlayer"))
	descriptors.append(F.expr("AudioGetPosition", "Playback Position", "get_playback_position()", "Audio", "playback position", "Gives the current playback time of this audio player, in seconds.", "AudioStreamPlayer"))

	# 3 - Bus control (Godot extras; event-sheet users fake these with tag groups).
	var bus_param: ACEParam = F.make_param("bus", "String", "\"Master\"", "Bus", "Audio bus name.", "expression")
	descriptors.append(F.act("SetBusVolume", "Set Bus Volume", "AudioServer.set_bus_volume_db(AudioServer.get_bus_index({bus}), {db})", "Audio", "Set bus {bus} volume to {db} dB", "Sets the volume of a named audio bus, like Music or SFX.").param_built(bus_param).param("db", "0.0", "Volume dB", "0 = full, -80 = silent.", "expression"))
	descriptors.append(F.act("SetBusMute", "Mute Bus", "AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})", "Audio", "Set bus {bus} muted: {muted}", "Mutes or unmutes a named audio bus all at once.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression").param_choice("muted", "true", "Muted", "true to silence the bus.", ["true", "false"]))
	descriptors.append(F.expr("GetBusVolume", "Bus Volume", "AudioServer.get_bus_volume_db(AudioServer.get_bus_index({bus}))", "Audio", "bus {bus} volume", "Gives the current volume of a named audio bus, in decibels.").param("bus", "\"Master\"", "Bus", "Audio bus name.", "expression"))

	# The sound a player holds, the bus it goes out on, and its volume as the 0-to-1 level a
	# slider gives rather than as decibels. Each writes the shape the opened-script reading recognises.
	descriptors.append(F.act("AudioSetStream", "Set Sound", "stream = load({path})", "Audio", "Set sound to {path}", "Puts a sound file into this player, ready to play.", "AudioStreamPlayer").param("path", "\"res://sound.ogg\"", "Sound", "Audio file this player holds.", "audio_path"))
	descriptors.append(F.act("AudioSetBus", "Set Bus", "bus = {bus}", "Audio", "Set bus to {bus}", "Sends this player's sound out on a named bus, like SFX or Music.", "AudioStreamPlayer").param("bus", "\"SFX\"", "Bus", "Audio bus this player goes out on.", "expression"))
	descriptors.append(F.act("AudioSetVolumeLevel", "Set Volume (0 to 1)", "volume_db = linear_to_db({level})", "Audio", "Set volume to {level} (0 to 1)", "Sets how loud this player is from a 0-to-1 level, with the decibel conversion done for you.", "AudioStreamPlayer").param("level", "0.5", "Level", "0 = silent, 1 = full - the number a volume slider gives.", "expression"))

	# ── a sound heard FROM a place, and the two faders a music change is made of ────────
	descriptors.append(F.act("AudioSetHearingDistance", "Set Hearing Distance", "max_distance = {value}", "Audio", "Set hearing distance to {value}", "Sets how far a positional sound carries. Past this distance it is silent.", "AudioStreamPlayer2D").param_typed("float", "value", "600.0", "Distance", "How far away the sound can still be heard at all.", "expression"))
	descriptors.append(F.act("AudioSetFalloff", "Set Falloff", "attenuation = {value}", "Audio", "Set falloff to {value}", "Sets how quickly a positional sound fades as the listener moves away.", "AudioStreamPlayer2D").param_typed("float", "value", "1.0", "Falloff", "How fast the sound fades with distance: 1 is even, higher drops off sooner.", "expression"))
	# ── the same two knobs on a sound heard from a place in 3D. Godot spells the falloff
	# differently there (`unit_size` rather than `attenuation`), which is why each is its own row
	# rather than one row that guesses - the same split the 2D and 3D light rows already make. ──
	descriptors.append(F.act("AudioSetHearingDistance3D", "Set Hearing Distance (3D)", "max_distance = {value}", "Audio", "Set hearing distance to {value}", "Sets how far a 3D positional sound carries. Past this distance it is silent.", "AudioStreamPlayer3D").param_typed("float", "value", "40.0", "Distance", "How far away the sound can still be heard at all. 0 means no limit.", "expression"))
	descriptors.append(F.act("AudioSetLoudnessFalloff", "Set Loudness Falloff", "unit_size = {value}", "Audio", "Set falloff to {value}", "Sets how quickly a 3D positional sound fades as the listener moves away.", "AudioStreamPlayer3D").param_typed("float", "value", "10.0", "Falloff", "How far the sound stays at full loudness before it starts fading. Bigger carries further.", "expression"))
	descriptors.append(F.act("AudioCrossfade", "Crossfade", "{from}.volume_db = linear_to_db(1.0 - {amount})\n{to}.volume_db = linear_to_db({amount})", "Audio", "Crossfade {from} → {to} by {amount}", "Fades one music player down while the other comes up, from one 0-to-1 number. Both players must already be playing.").param("from", "$MusicA", "From", "The player fading out.", "expression").param("to", "$MusicB", "To", "The player fading in.", "expression").param("amount", "0.5", "Amount", "0 is all the first track, 1 is all the second - drive it from a timer.", "expression").featured())

	return descriptors
