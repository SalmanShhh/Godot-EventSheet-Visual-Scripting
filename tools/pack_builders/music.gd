# Pack builder - music (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Music: the director that plays the game's songs, as the Music autoload.
##
## The Audio rows play a sound ON a player, which is the right shape for a footstep and the wrong
## shape for a song. Music is one thing playing at a time, crossfaded rather than cut, with layers
## that come up as the danger rises, a stinger over the top, a duck under a line of dialogue, and a
## beat the rest of the game can hear. That is a service, not a node - so this pack ships as the
## Music AUTOLOAD, exactly the way Scene Flow and Save System do, and any sheet reaches it without
## a node path.
##
## THE BEAT IS READ, NOT COUNTED. Nothing here keeps its own metronome: every beat answer is the
## stream's own playback position, less the output latency the audio device adds, turned into beats
## at the track's tempo. A counter drifts against the song within a minute; the position cannot.
## That is what the Timed Input module's Beat Grade and Off The Beat By have been waiting for - put
## Next Beat At in their Beat At slot and a rhythm lane is two rows.
##
## THE PACK SHIPS NO TRACKS. A track is a MusicTrackResource the game owns, named whatever the game
## names it, kept wherever the game keeps its music; a pack setting names the folder to look in and
## another names the bus to play out on. There is no list of songs anywhere in the editor.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("music", "Node", "MusicAddon",
		"The game's songs as the Music autoload: play a track and crossfade from whatever was playing, bring a layer up as the danger rises, duck under a line of dialogue, drop a stinger over the top, and read the beat straight off the stream's own position so On Beat lands where the player hears it. Tracks are MusicTrackResource files you own; the pack ships none.",
		Lib.manifest().autoload("Music").category("Music").tags(["audio", "music", "rhythm", "beat"]))
	# Property ORDER is part of the pack: these emit in the order they are declared here.
	src.sheet.variables = {
		"music_bus": {"type": "String", "default": "Music", "exported": true,
			"attributes": {"tooltip": "The audio bus the music plays out on. Set Music Volume writes this bus, so an options-menu music slider and this director are moving the same fader. Make the bus in Godot's Audio panel first - the name here has to match it."}},
		"music_folder": {"type": "String", "default": "res://music/", "exported": true,
			"attributes": {"tooltip": "Where the Play row looks a track NAME up: \"forest\" finds forest.tres here. A row may also give a full res:// path instead, which skips the folder entirely."}},
		"beat_number_every": {"type": "int", "default": 8, "exported": true,
			"attributes": {"tooltip": "How many beats apart On Beat Number fires - 8 is a phrase, 16 is a longer one. On Bar already covers the downbeat, so this is for the change that should land less often than that.", "range": {"min": "1", "max": "64", "step": "1"}}},
		"debug_mode": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Warns about a track name that finds no file, a track with no stream in it, a missing audio bus, and a Switch To Clip on a stream that is not interactive. On while you build, off for release."}},
	}
	src.note("Music (autoload): register as the Music autoload, then play tracks from any sheet. A track is a MusicTrackResource file you own - the stream, its layers, its tempo and its loop points - and the beat triggers read the stream's own position rather than counting, so they stay on the song. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.block("block_2")
	src.on_ready()
	src.on_process()

	# ── The song ──────────────────────────────────────────────────────────────────────────
	src.verb("play", "Play",
		"Plays a track, crossfading down whatever was playing over the fade seconds. A fade of 0 is a cut. The name is looked up as a file in the Music Folder, or given as a full res:// path.",
		[["track", "String"], ["fade", "float"]])
	_default(src.sheet, "track", "\"forest\"")
	_default(src.sheet, "fade", "1.0")
	src.verb("crossfade_to", "Crossfade To",
		"Crossfades to another track over the seconds given - the same machinery as Play, spelled the way a music change reads. It always takes time; Play with a fade of 0 is the cut.",
		[["track", "String"], ["seconds", "float"]])
	_default(src.sheet, "track", "\"battle\"")
	_default(src.sheet, "seconds", "2.0")
	src.verb("stop_music", "Stop",
		"Fades the music out over the seconds given and frees the players. A fade of 0 stops it dead.",
		[["fade", "float"]])
	_default(src.sheet, "fade", "1.0")
	src.verb("pause_music", "Pause",
		"Pauses the music where it is. The director runs while the tree is paused, so a pause menu does NOT silence the song by itself - this is the row that does, and Resume carries on from the same place.",
		[])
	src.verb("resume_music", "Resume",
		"Carries on from where Pause left off, rather than starting the track again.",
		[])
	src.verb("stinger", "Stinger",
		"Plays a one-shot over the music - the sting on a discovery, the flourish on a win - and ducks the music underneath it for exactly as long as the sound lasts, then brings it back up.",
		[["path", "String"], ["duck_db", "float"]])
	_hint(src.sheet, "path", "audio_path")
	_default(src.sheet, "path", "\"res://music/sting.ogg\"")
	_default(src.sheet, "duck_db", "6.0")

	# ── Under a voice ─────────────────────────────────────────────────────────────────────
	src.verb("duck", "Duck",
		"Drops the music by that many decibels over the seconds given, and leaves it there - under a line of dialogue, a radio call, a cutscene. Unduck brings it back.",
		[["db", "float"], ["seconds", "float"]])
	_default(src.sheet, "db", "8.0")
	_default(src.sheet, "seconds", "0.25")
	src.verb("unduck", "Unduck",
		"Brings the music back up to full over the seconds given.",
		[["seconds", "float"]])
	_default(src.sheet, "seconds", "0.5")
	src.verb("set_music_volume", "Set Music Volume",
		"Sets the music bus's volume from a 0-to-1 level - the number an options-menu slider gives, with the decibel conversion done for you. It writes the same bus the Options rows do.",
		[["level", "float"]])
	_default(src.sheet, "level", "0.8")

	# ── Layers ────────────────────────────────────────────────────────────────────────────
	src.verb("fade_layer", "Fade Layer",
		"Fades one of the track's layers to a 0-to-1 volume over the seconds given - the drums coming in as the danger rises, the strings dropping out as it passes. The layers are one synchronized stream, so they cannot drift out of time with the song.",
		[["layer", "String"], ["to", "float"], ["seconds", "float"]])
	_default(src.sheet, "layer", "\"drums\"")
	_default(src.sheet, "to", "1.0")
	_default(src.sheet, "seconds", "1.5")
	src.verb("set_layers", "Set Layers",
		"Says which layers are on, all at once, as a comma-separated list: every layer named fades up, every other layer of the track fades down. It states the whole mix rather than changing one thing, so it is safe to fire on every state change.",
		[["layers", "String"], ["seconds", "float"]])
	_default(src.sheet, "layers", "\"drums, strings\"")
	_default(src.sheet, "seconds", "1.0")
	src.verb("switch_to_clip", "Switch To Clip",
		"Switches an interactive track to another of its clips by name. The stream's own transition rules decide when the change lands - on the bar, at the end of the clip, through a filler. Needs the track's stream to be an AudioStreamInteractive, which Godot 4.3 and later provide.",
		[["clip", "String"]])
	_default(src.sheet, "clip", "\"chorus\"")

	# ── The beat ──────────────────────────────────────────────────────────────────────────
	src.verb("set_tempo", "Set Tempo",
		"Sets the tempo the beat is counted at, and how many seconds into the file the first beat lands. A track file carries both already - this is for a song whose file does not, or for a tempo that changes mid-piece.",
		[["bpm", "float"], ["offset", "float"]])
	_default(src.sheet, "bpm", "120.0")
	_default(src.sheet, "offset", "0.0")

	# ── Questions ─────────────────────────────────────────────────────────────────────────
	src.condition("is_playing", "Is Playing",
		"True while a track is playing and not paused.",
		[])
	src.expression("current_track", "Current Track",
		"The name of the track playing now, or nothing when the music is stopped.",
		[], TYPE_STRING)
	src.expression("position_in_bars", "Position In Bars",
		"How far into the song the player is, counted in bars - the number a music-driven level reads to know where it is.",
		[], TYPE_FLOAT)
	src.expression("beat_number", "Beat Number",
		"Which beat of the song is playing right now, counted from the track's first beat.",
		[], TYPE_INT)
	src.expression("seconds_to_next_beat", "Seconds To Next Beat",
		"How long until the next beat lands, in seconds - the wait before a move that should fire on the beat.",
		[], TYPE_FLOAT)
	src.expression("beat_phase", "Beat Phase",
		"How far through its beat the song is, from 0 on the beat to just under 1 before the next - the number a pulse, a bob or a breathing light rides on.",
		[], TYPE_FLOAT)
	src.expression("next_beat_at", "Next Beat At",
		"The moment the next beat lands, on the same engine clock the Timed Input rows measure a press with - put it in Beat Grade's Beat At slot and a press is graded against the song.",
		[], TYPE_FLOAT)
	src.expression("layer_volume", "Layer Volume",
		"How loud one of the track's layers is right now, from 0 to 1.",
		[["layer", "String"]], TYPE_FLOAT)
	_default(src.sheet, "layer", "\"drums\"")

	Lib.verb_sentences(src.sheet, {
		"play": "Play [b]{track}[/b], fade [b]{fade}[/b] s",
		"crossfade_to": "Crossfade to [b]{track}[/b] over [b]{seconds}[/b] s",
		"stop_music": "Stop the music over [b]{fade}[/b] s",
		"stinger": "Stinger [b]{path}[/b], ducking [b]{duck_db}[/b] dB",
		"duck": "Duck by [b]{db}[/b] dB",
		"unduck": "Unduck over [b]{seconds}[/b] s",
		"set_music_volume": "Set music volume to [b]{level}[/b]",
		"fade_layer": "Fade layer [b]{layer}[/b] to [b]{to}[/b] over [b]{seconds}[/b] s",
		"set_layers": "Set layers to [b]{layers}[/b] over [b]{seconds}[/b] s",
		"switch_to_clip": "Switch to clip [b]{clip}[/b]",
		"set_tempo": "Set tempo [b]{bpm}[/b] bpm",
	})
	# The three a new user should meet first: start a song, bring a layer up, get out from under a
	# line of dialogue.
	Lib.feature_verbs(src.sheet, ["play", "fade_layer", "duck"])
	return Lib.publish(src, "res://eventsheet_addons/music/music_addon")


## Pre-fills the last-declared verb's parameter default, so a dropped row opens with a usable value
## instead of an empty field (authoring-time metadata only - defaults never appear in the compiled
## .gd of a game that uses the row).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the parameter HINT on the last-declared verb's parameter - the key the params dialog reads
## to decide which little editor a field gets. "audio_path" is the one with the preview button, so
## a stinger can be heard before the row is applied.
static func _hint(sheet: EventSheetResource, param_id: String, hint: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.hint = hint
