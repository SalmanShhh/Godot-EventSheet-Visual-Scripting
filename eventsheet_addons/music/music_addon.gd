## @ace_tags(audio, music, rhythm, beat)
## @ace_category("Music")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/music/icon.svg")
class_name MusicAddon
extends Node
## The game's songs as the Music autoload: play a track and crossfade from whatever was playing, bring a layer up as the danger rises, duck under a line of dialogue, drop a stinger over the top, and read the beat straight off the stream's own position so On Beat lands where the player hears it. Tracks are MusicTrackResource files you own; the pack ships none.

## Fires on every whole beat of the track that is playing, carrying the beat's own number counted
## from the track's offset. The beat is read from where the stream has actually got to, less the
## audio device's output latency, so it lands where the player HEARS it rather than where the
## engine wrote it.
## @ace_trigger
## @ace_name("On Beat")
signal beat(number: int)
## Fires on the first beat of every bar, carrying the bar's number. How many beats a bar holds is
## the track's own Beats Per Bar, so a waltz bars in three without anything here changing.
## @ace_trigger
## @ace_name("On Bar")
signal bar(number: int)
## Fires on every nth beat, where n is the Beat Number Every setting - the phrase rather than the
## beat, for a change that should land on the eighth or the sixteenth rather than on each one.
## @ace_trigger
## @ace_name("On Beat Number")
signal nth_beat(number: int)

## The audio bus the music plays out on. Set Music Volume writes this bus, so an options-menu music slider and this director are moving the same fader. Make the bus in Godot's Audio panel first - the name here has to match it.
@export var music_bus: String = "Music"
## Where the Play row looks a track NAME up: "forest" finds forest.tres here. A row may also give a full res:// path instead, which skips the folder entirely.
@export var music_folder: String = "res://music/"
## How many beats apart On Beat Number fires - 8 is a phrase, 16 is a longer one. On Bar already covers the downbeat, so this is for the change that should land less often than that.
@export_range(1, 64, 1) var beat_number_every: int = 8
## Warns about a track name that finds no file, a track with no stream in it, a missing audio bus, and a Switch To Clip on a stream that is not interactive. On while you build, off for release.
@export var debug_mode: bool = false

## How many players a crossfade needs: the one going out and the one coming in. Two is the whole
## machine - a third would be a second crossfade running over the first, which is a mix nobody can
## hear the shape of.
const DECK_COUNT: int = 2

## The quietest a deck is allowed to be treated as, so linear_to_db is never handed a 0 (which is
## minus infinity, and an infinity written into volume_db is a silence nothing recovers from).
const SILENT_LEVEL: float = 0.0001

## The two players. Empty until _ready builds them, which is what lets every rule below be driven
## and pinned with no scene tree and no audio device in the picture.
var _decks: Array[AudioStreamPlayer] = []

## How loud each deck is right now, and where it is walking to, as a 0-to-1 level. Levels rather
## than decibels because a crossfade is a straight line in loudness, not in decibels.
var _levels: Array[float] = [0.0, 0.0]
var _level_targets: Array[float] = [0.0, 0.0]

## How fast a level walks, as full range per second. 0 means the last change was instant and there
## is nothing to walk.
var _fade_rate: float = 0.0

## Which deck holds the track that is playing now; the other one is whatever is fading out.
var _front: int = 0

## What each deck is playing, by name. Empty is an idle deck, which is what Is Playing and Current
## Track read.
var _deck_tracks: Array[String] = ["", ""]

## The track resource the front deck is playing, or null. Typed Resource rather than
## MusicTrackResource so this pack still parses in a project that installed it without the track
## resource beside it - every field is read by name.
var _track: Resource = null

## The tempo the beat is counted at: beats per minute, and the offset in seconds from the start of
## the stream to the first beat. Read from the track when one starts, and overridable by Set Tempo
## for a track whose file does not carry it.
var _bpm: float = 120.0
var _beat_offset: float = 0.0

## The last whole beat and bar a trigger fired for, so each fires once per beat rather than once
## per frame. Reset when a track starts, which is why the first beat of a new track always arrives.
var _last_beat: int = -1
var _last_bar: int = -1

## Ducking: where the music's decibel offset is, where it is walking to, how fast, and how long it
## holds down before it comes back up on its own (a stinger ducks for its own length).
var _duck_db: float = 0.0
var _duck_target_db: float = 0.0
var _duck_rate: float = 0.0
var _duck_hold: float = 0.0
var _duck_release: float = 0.4

## Where a HELD duck comes back up to when its hold runs out. Nothing, usually - but a stinger that
## lands over a line of dialogue interrupted a duck that is still wanted, and coming back up to full
## there would raise the music over the voice it was ducked under. So the stinger writes down what it
## found and the hold hands the music back to it.
var _duck_return_db: float = 0.0

## The tracks that have been started this session, by the name each answered to. A song is played from
## its beginning the first time it is asked for and from its loop point every time after, which is the
## whole of what an intro is: heard once, skipped on the way back in.
var _heard: Dictionary = {}

## Layer levels, by layer name: where each is, where it is walking to, and how fast. A layer nobody
## has faded is silent, so a track's layers all start under the base stream.
var _layer_levels: Dictionary = {}
var _layer_targets: Dictionary = {}
var _layer_rates: Dictionary = {}

## The layer names of the stream now playing, in the order they were built into it - which is the
## order their volumes are written back in, so a name and its slot can never drift apart.
var _layer_order: PackedStringArray = PackedStringArray()

## Whether the music is paused. Pause keeps the position, so Resume carries on rather than
## restarting.
var _paused: bool = false

## One deck, or null when the players have not been built - which is every case outside a running
## game, and the reason none of the rules here need a scene tree.
## @ace_hidden
func _deck(index: int) -> AudioStreamPlayer:
	if index < 0 or index >= _decks.size():
		return null
	return _decks[index]
## The track a name stands for: a resource path as written, or the name looked up as a file in the
## Music Folder. A name that answers to neither plays nothing and says so in Debug Mode - the pack
## ships no tracks at all, because which songs a game has is the game's business.
## @ace_hidden
func _track_named(called: String) -> Resource:
	var word: String = called.strip_edges()
	if word.is_empty():
		return null
	if word.begins_with("res://") or word.begins_with("user://"):
		if ResourceLoader.exists(word):
			return load(word) as Resource
		return null
	var path: String = music_folder.path_join(word.to_lower().replace(" ", "_") + ".tres")
	if ResourceLoader.exists(path):
		return load(path) as Resource
	return null
## The stream a track plays as: its own stream on its own, or - when the track names layers - ONE
## AudioStreamSynchronized holding the base stream and every layer together. That is the whole
## reason layers cannot drift: they are not several players being started at the same moment and
## hoping, they are one stream with several volumes.
##
## A fresh synchronized stream is built per play, so the volumes written into it every frame are
## this playback's own and never the saved file's.
## @ace_hidden
func _stream_for(track: Resource) -> AudioStream:
	_layer_order = PackedStringArray()
	if track == null:
		return null
	var main: AudioStream = track.get("stream") as AudioStream
	if main == null:
		return null
	var declared: Variant = track.get("layers")
	var layers: Dictionary = {}
	if declared is Dictionary:
		layers = declared
	if layers.is_empty():
		return main
	# Sorted, so the slot a layer takes is the same on every machine that builds this stream.
	var names: Array = layers.keys()
	names.sort()
	var built: AudioStreamSynchronized = AudioStreamSynchronized.new()
	built.stream_count = 1 + names.size()
	built.set_sync_stream(0, main)
	built.set_sync_stream_volume(0, 0.0)
	var slot: int = 1
	for entry: Variant in names:
		var key: String = str(entry).strip_edges().to_lower()
		built.set_sync_stream(slot, layers[entry] as AudioStream)
		built.set_sync_stream_volume(slot, linear_to_db(SILENT_LEVEL))
		_layer_order.append(key)
		slot += 1
	return built

func _ready() -> void:
	# The song is not part of the world's clock. A pause menu pauses the tree, and the music has to
	# go on playing under it unless a row says otherwise - so the director and its players run
	# always, and Pause is the row that stops the music.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in range(DECK_COUNT):
		var deck: AudioStreamPlayer = AudioStreamPlayer.new()
		deck.name = "Deck%d" % index
		deck.bus = music_bus
		deck.volume_db = linear_to_db(SILENT_LEVEL)
		deck.finished.connect(_deck_finished.bind(index))
		add_child(deck)
		_decks.append(deck)
	# Nothing is playing yet, so nothing is walking: the frame starts parked and every row that
	# starts something turns it back on.
	set_process(false)

func _process(delta: float) -> void:
	advance(delta)
	_apply_volumes()
	if is_playing() and _front_is_running():
		var at: float = _position()
		if loop_reached(at):
			_take_the_loop()
			at = _position()
		_fire_beats(at, _latency())
	if _at_rest():
		set_process(false)

## @ace_action
## @ace_featured
## @ace_name("Play")
## @ace_category("Music")
## @ace_description("Plays a track, crossfading down whatever was playing over the fade seconds. A fade of 0 is a cut. The name is looked up as a file in the Music Folder, or given as a full res:// path. A song is played from its beginning the first time it is asked for and from its loop point every time after, so a track with an intro is heard whole once and comes straight back in at the loop.")
## @ace_display_template("Play [b]{track}[/b], fade [b]{fade}[/b] s")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.play({track}, {fade})")
func play(track: String, fade: float) -> void:
	_start_track(track, maxf(fade, 0.0))

## @ace_action
## @ace_name("Crossfade To")
## @ace_category("Music")
## @ace_description("Crossfades to another track over the seconds given - the same machinery as Play, spelled the way a music change reads. It always takes time; Play with a fade of 0 is the cut.")
## @ace_display_template("Crossfade to [b]{track}[/b] over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.crossfade_to({track}, {seconds})")
func crossfade_to(track: String, seconds: float) -> void:
	# A crossfade is a Play that always takes time: a zero here would be a cut, which is what Play
	# with no fade already is.
	_start_track(track, maxf(seconds, 0.01))

## @ace_action
## @ace_name("Stop")
## @ace_category("Music")
## @ace_description("Fades the music out over the seconds given and frees the players. A fade of 0 stops it dead.")
## @ace_display_template("Stop the music over [b]{fade}[/b] s")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.stop_music({fade})")
func stop_music(fade: float) -> void:
	_fade_rate = 0.0 if fade <= 0.0 else 1.0 / fade
	for index: int in range(_level_targets.size()):
		_level_targets[index] = 0.0
	if fade <= 0.0:
		for index: int in range(_levels.size()):
			_levels[index] = 0.0
			_release_deck(index)
	_paused = false
	set_process(true)

## @ace_action
## @ace_name("Pause")
## @ace_category("Music")
## @ace_description("Pauses the music where it is. The director runs while the tree is paused, so a pause menu does NOT silence the song by itself - this is the row that does, and Resume carries on from the same place.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.pause_music()")
func pause_music() -> void:
	_paused = true
	for deck: AudioStreamPlayer in _decks:
		deck.stream_paused = true

## @ace_action
## @ace_name("Resume")
## @ace_category("Music")
## @ace_description("Carries on from where Pause left off, rather than starting the track again.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.resume_music()")
func resume_music() -> void:
	_paused = false
	for deck: AudioStreamPlayer in _decks:
		deck.stream_paused = false
	set_process(true)

## @ace_action
## @ace_name("Stinger")
## @ace_category("Music")
## @ace_description("Plays a one-shot over the music - the sting on a discovery, the flourish on a win - and ducks the music underneath it for exactly as long as the sound lasts, then brings it back up.")
## @ace_display_template("Stinger [b]{path}[/b], ducking [b]{duck_db}[/b] dB")
## @ace_param_hint(path audio_path)
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.stinger({path}, {duck_db})")
func stinger(path: String, duck_db: float) -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		if debug_mode:
			push_warning("Music: there is no sound at %s, so no stinger played." % path)
		return
	# A throwaway player that frees itself on the way out, the way every one-shot here is played -
	# the stinger is a sound over the music, not a third deck.
	var shot: AudioStreamPlayer = AudioStreamPlayer.new()
	shot.stream = stream
	shot.bus = music_bus
	add_child(shot)
	shot.finished.connect(shot.queue_free)
	shot.play()
	# A sting ducks at least as far as whatever it found and hands the music back to the STANDING
	# duck rather than to full volume, which is the whole of what a sting over a line of dialogue -
	# or over another sting - has to get right.
	_begin_sting(duck_db, stream.get_length())

## @ace_action
## @ace_featured
## @ace_name("Duck")
## @ace_category("Music")
## @ace_description("Drops the music by that many decibels over the seconds given, and leaves it there - under a line of dialogue, a radio call, a cutscene. Unduck brings it back.")
## @ace_display_template("Duck by [b]{db}[/b] dB")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.duck({db}, {seconds})")
func duck(db: float, seconds: float) -> void:
	_duck_target_db = -absf(db)
	_duck_rate = 0.0 if seconds <= 0.0 else absf(_duck_target_db - _duck_db) / seconds
	if seconds <= 0.0:
		_duck_db = _duck_target_db
	_duck_hold = 0.0
	_duck_return_db = 0.0
	set_process(true)

## @ace_action
## @ace_name("Unduck")
## @ace_category("Music")
## @ace_description("Brings the music back up to full over the seconds given.")
## @ace_display_template("Unduck over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.unduck({seconds})")
func unduck(seconds: float) -> void:
	_duck_target_db = 0.0
	_duck_rate = 0.0 if seconds <= 0.0 else absf(_duck_db) / seconds
	if seconds <= 0.0:
		_duck_db = 0.0
	_duck_hold = 0.0
	_duck_return_db = 0.0
	set_process(true)

## @ace_action
## @ace_name("Set Music Volume")
## @ace_category("Music")
## @ace_description("Sets the music bus's volume from a 0-to-1 level - the number an options-menu slider gives, with the decibel conversion done for you. It writes the same bus the Options rows do.")
## @ace_display_template("Set music volume to [b]{level}[/b]")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.set_music_volume({level})")
func set_music_volume(level: float) -> void:
	var index: int = AudioServer.get_bus_index(music_bus)
	if index < 0:
		if debug_mode:
			push_warning("Music: this project has no audio bus called \"%s\", so the volume was not set." % music_bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clampf(level, 0.0, 1.0), SILENT_LEVEL)))

## @ace_action
## @ace_featured
## @ace_name("Fade Layer")
## @ace_category("Music")
## @ace_description("Fades one of the track's layers to a 0-to-1 volume over the seconds given - the drums coming in as the danger rises, the strings dropping out as it passes. The layers are one synchronized stream, so they cannot drift out of time with the song.")
## @ace_display_template("Fade layer [b]{layer}[/b] to [b]{to}[/b] over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.fade_layer({layer}, {to}, {seconds})")
func fade_layer(layer: String, to: float, seconds: float) -> void:
	var key: String = layer.strip_edges().to_lower()
	if key.is_empty():
		return
	var target: float = clampf(to, 0.0, 1.0)
	var from: float = float(_layer_levels.get(key, 0.0))
	_layer_targets[key] = target
	_layer_rates[key] = 0.0 if seconds <= 0.0 else absf(target - from) / seconds
	if seconds <= 0.0:
		_layer_levels[key] = target
	elif not _layer_levels.has(key):
		_layer_levels[key] = 0.0
	set_process(true)

## @ace_action
## @ace_name("Set Layers")
## @ace_category("Music")
## @ace_description("Says which layers are on, all at once, as a comma-separated list: every layer named fades up, every other layer of the track fades down. It states the whole mix rather than changing one thing, so it is safe to fire on every state change.")
## @ace_display_template("Set layers to [b]{layers}[/b] over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.set_layers({layers}, {seconds})")
func set_layers(layers: String, seconds: float) -> void:
	var wanted: Dictionary = {}
	for part: String in layers.split(","):
		var key: String = part.strip_edges().to_lower()
		if not key.is_empty():
			wanted[key] = true
	# Every layer the track holds is addressed, so the row says what the mix IS rather than what to
	# change about it - which is what makes it safe to fire on every state change.
	for layer: String in _layer_order:
		fade_layer(layer, 1.0 if wanted.has(layer) else 0.0, seconds)

## @ace_action
## @ace_name("Switch To Clip")
## @ace_category("Music")
## @ace_description("Switches an interactive track to another of its clips by name. The stream's own transition rules decide when the change lands - on the bar, at the end of the clip, through a filler. Needs the track's stream to be an AudioStreamInteractive, which Godot 4.3 and later provide. An interactive stream does not report a playback position, so the beat readings and the beat moments are silent on a track driven this way: a song answers either the clips or the beat, not both.")
## @ace_display_template("Switch to clip [b]{clip}[/b]")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.switch_to_clip({clip})")
func switch_to_clip(clip: String) -> void:
	var deck: AudioStreamPlayer = _deck(_front)
	if deck == null:
		return
	var playback: AudioStreamPlayback = deck.get_stream_playback()
	if playback == null or not playback.has_method("switch_to_clip_by_name"):
		if debug_mode:
			push_warning("Music: Switch To Clip needs the track's stream to be an AudioStreamInteractive, which Godot 4.3 and later provide.")
		return
	playback.call("switch_to_clip_by_name", clip)

## @ace_action
## @ace_name("Set Tempo")
## @ace_category("Music")
## @ace_description("Sets the tempo the beat is counted at, and how many seconds into the file the first beat lands. A track file carries both already - this is for a song whose file does not, or for a tempo that changes mid-piece.")
## @ace_display_template("Set tempo [b]{bpm}[/b] bpm")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.set_tempo({bpm}, {offset})")
func set_tempo(bpm: float, offset: float) -> void:
	_bpm = maxf(bpm, 1.0)
	_beat_offset = offset
	_last_beat = -1
	_last_bar = -1

## @ace_condition
## @ace_name("Is Playing")
## @ace_category("Music")
## @ace_description("True while a track is playing and not paused.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.is_playing()")
func is_playing() -> bool:
	if _paused:
		return false
	return not _deck_tracks[_front].is_empty()

## @ace_expression
## @ace_name("Current Track")
## @ace_category("Music")
## @ace_description("The name of the track playing now, or nothing when the music is stopped.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.current_track()")
func current_track() -> String:
	return _deck_tracks[_front]

## @ace_expression
## @ace_name("Position In Bars")
## @ace_category("Music")
## @ace_description("How far into the song the player is, counted in bars - the number a music-driven level reads to know where it is.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.position_in_bars()")
func position_in_bars() -> float:
	return beat_at(_position(), _latency()) / float(bar_beats())

## @ace_expression
## @ace_name("Beat Number")
## @ace_category("Music")
## @ace_description("Which beat of the song is playing right now, counted from the track's first beat.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.beat_number()")
func beat_number() -> int:
	return floori(beat_at(_position(), _latency()))

## @ace_expression
## @ace_name("Seconds To Next Beat")
## @ace_category("Music")
## @ace_description("How long until the next beat lands, in seconds - the wait before a move that should fire on the beat.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.seconds_to_next_beat()")
func seconds_to_next_beat() -> float:
	return seconds_to_beat(_position(), _latency())

## @ace_expression
## @ace_name("Beat Phase")
## @ace_category("Music")
## @ace_description("How far through its beat the song is, from 0 on the beat to just under 1 before the next - the number a pulse, a bob or a breathing light rides on.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.beat_phase()")
func beat_phase() -> float:
	return beat_phase_at(_position(), _latency())

## @ace_expression
## @ace_name("Next Beat At")
## @ace_category("Music")
## @ace_description("The moment the next beat lands, on the same engine clock the Timed Input rows measure a press with - put it in Beat Grade's Beat At slot and a press is graded against the song. It answers 0 while nothing is playing, which is a rhythm lane's cue to place its note by its own lead instead.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.next_beat_at()")
func next_beat_at() -> float:
	# NOTHING PLAYING HAS NO NEXT BEAT. Answering one anyway - which a position of zero quietly does -
	# would put a rhythm lane's notes a fraction of a beat away instead of the lead it asked for, in
	# every project that has this director installed and no track running.
	if not is_playing():
		return 0.0
	return Time.get_ticks_msec() / 1000.0 + seconds_to_beat(_position(), _latency())

## @ace_expression
## @ace_name("Layer Volume")
## @ace_category("Music")
## @ace_description("How loud one of the track's layers is right now, from 0 to 1.")
## @ace_icon("res://eventsheet_addons/music/icon.svg")
## @ace_codegen_template("Music.layer_volume({layer})")
func layer_volume(layer: String) -> float:
	return float(_layer_levels.get(layer.strip_edges().to_lower(), 0.0))

## The moment of the music the player is HEARING right now: where the stream has got to, less the
## output latency the audio device adds on the way out. Every beat answer below is measured from
## this rather than from the raw position, which is the honest way to stay on the beat - on a
## machine with a big buffer the two are a tenth of a second apart, and a tenth of a second is the
## difference between a perfect and a miss.
## @ace_hidden
func heard_position(position: float, latency: float) -> float:
	return position - latency

## Which beat a moment of the music is on, as a fraction: 2.5 is halfway between the third beat and
## the fourth. Everything else about the beat is this number rounded, split or subtracted.
## @ace_hidden
func beat_at(position: float, latency: float) -> float:
	if _bpm <= 0.0:
		return 0.0
	return (heard_position(position, latency) - _beat_offset) * _bpm / 60.0

## How far through its beat a moment is, from 0 on the beat to just under 1 before the next - the
## number a pulse, a bob or a light breathes on.
## @ace_hidden
func beat_phase_at(position: float, latency: float) -> float:
	var walked: float = beat_at(position, latency)
	return walked - floorf(walked)

## Seconds from a moment of the music to the NEXT whole beat after it. On an exact beat that is a
## whole beat away, not nothing: the beat you are standing on has already happened.
## @ace_hidden
func seconds_to_beat(position: float, latency: float) -> float:
	if _bpm <= 0.0:
		return 0.0
	var walked: float = beat_at(position, latency)
	return (floorf(walked) + 1.0 - walked) * 60.0 / _bpm

## A number written on a track resource, or the fallback when the file carries no such field. This
## is how the pack reads a track WITHOUT naming its class: a project that installed the director
## without the track resource beside it still parses, and a track somebody wrote themselves works
## as long as it spells the same fields.
## @ace_hidden
func _track_number(track: Resource, field: String, fallback: float) -> float:
	if track == null:
		return fallback
	var value: Variant = track.get(field)
	if value is float or value is int:
		return float(value)
	return fallback

## How many beats a bar of the current track holds, never less than one. It is the track's own
## fact, so a waltz bars in three and a march in four with nothing here changing.
## @ace_hidden
func bar_beats() -> int:
	return maxi(int(_track_number(_track, "beats_per_bar", 4.0)), 1)

## Where the front deck's stream has got to, in seconds. Zero when nothing is playing, and zero
## with no players at all, which is what lets the beat arithmetic above be driven by hand.
## @ace_hidden
func _position() -> float:
	var deck: AudioStreamPlayer = _deck(_front)
	if deck == null or not deck.playing:
		return 0.0
	return deck.get_playback_position()

## What the audio device adds between the mix and the speaker, in seconds, LESS how long ago the last
## mix was. The playback position steps forward one mix chunk at a time rather than smoothly, so on
## its own it is up to a chunk behind by the end of a frame - and a chunk is tens of milliseconds,
## which is the difference between a perfect and a good. This is the engine's own recipe for the
## question "where is the song right now", and the answer moves smoothly because of the second term.
## @ace_hidden
func _latency() -> float:
	return AudioServer.get_output_latency() - AudioServer.get_time_since_last_mix()

## How loud a deck should be right now, in decibels: its own level, dropped by however far the
## music is ducked. One place, so the crossfade and the duck can never fight over volume_db.
## @ace_hidden
func deck_db(index: int) -> float:
	if index < 0 or index >= _levels.size():
		return -80.0
	return linear_to_db(maxf(_levels[index], SILENT_LEVEL)) + _duck_db

## Frees a deck: it stops, forgets its stream, and reads as idle. A deck that has faded all the way
## out is released here rather than left playing silently, because a silent stream still costs a
## mix and still moves its own playback position.
## @ace_hidden
func _release_deck(index: int) -> void:
	if index < 0 or index >= _deck_tracks.size():
		return
	_deck_tracks[index] = ""
	_levels[index] = 0.0
	_level_targets[index] = 0.0
	if index == _front:
		_track = null
	var deck: AudioStreamPlayer = _deck(index)
	if deck != null:
		deck.stop()
		deck.stream = null

## What Current Track answers with for a track: the name written on the resource when it carries
## one, and otherwise the word the row asked for.
## @ace_hidden
func _track_key(called: String, track: Resource) -> String:
	if track != null:
		var named: Variant = track.get("track_name")
		if named is String and not str(named).strip_edges().is_empty():
			return str(named).strip_edges()
	return called.strip_edges()

## Starts a track on the free deck and walks the other one out - which is the whole of Play,
## Crossfade To and a scene change's music, spelled once.
## @ace_hidden
func _start_track(track_name: String, fade: float) -> void:
	var found: Resource = _track_named(track_name)
	if found == null:
		if debug_mode:
			push_warning("Music: no track called \"%s\" - looked for a file at %s." % [
				track_name, music_folder.path_join(track_name.strip_edges().to_lower().replace(" ", "_") + ".tres")])
		return
	var stream: AudioStream = _stream_for(found)
	if stream == null:
		if debug_mode:
			push_warning("Music: the track \"%s\" carries no stream, so there is nothing to play." % track_name)
		return
	var incoming: int = 1 - _front
	# Whatever was still fading out on the free deck stops now: a third track would be a crossfade
	# over a crossfade, and nobody can hear the shape of that.
	_release_deck(incoming)
	var outgoing: int = _front
	_front = incoming
	_track = found
	_bpm = maxf(_track_number(found, "bpm", 120.0), 1.0)
	_beat_offset = _track_number(found, "beat_offset", 0.0)
	_last_beat = -1
	_last_bar = -1
	_paused = false
	_layer_levels = {}
	_layer_targets = {}
	_layer_rates = {}
	var key: String = _track_key(track_name, found)
	var first_play: bool = not _heard.has(key)
	_heard[key] = true
	_deck_tracks[incoming] = key
	_level_targets[incoming] = 1.0
	_level_targets[outgoing] = 0.0
	_fade_rate = 0.0 if fade <= 0.0 else 1.0 / fade
	if fade <= 0.0:
		_levels[incoming] = 1.0
		_release_deck(outgoing)
	else:
		_levels[incoming] = 0.0
	var deck: AudioStreamPlayer = _deck(incoming)
	if deck != null:
		deck.stream = stream
		deck.volume_db = deck_db(incoming)
		deck.stream_paused = false
		deck.play(start_position(first_play))
	set_process(true)

## Where a track's loop begins: the seconds its own Loop From names, and 0 for a track that names
## none. A play COMING BACK to a song starts here, which is how an intro is heard once.
## @ace_hidden
func _loop_start() -> float:
	return maxf(_track_number(_track, "loop_from", 0.0), 0.0)

## Where a play starts: the beginning the first time this song is asked for, and its loop point every
## time after. A song with a four-bar intro plays the intro when the level opens and comes straight
## back in at the loop when the fight ends - which is what the track's two loop fields are for, and
## what starting every play at the loop point took away.
## @ace_hidden
func start_position(first_play: bool) -> float:
	return 0.0 if first_play else _loop_start()

## Whether the front deck has reached the point its track loops BACK from. Only a track that names a
## Loop To beyond its Loop From loops here: a stream that loops itself is left to do it, and a track
## that names neither plays through to its end.
## @ace_hidden
func loop_reached(position: float) -> bool:
	var loop_to: float = _track_number(_track, "loop_to", 0.0)
	return loop_to > _loop_start() and position >= loop_to

## Sends the front deck back to its loop point and lets the beat count from there. The beat numbers
## start again with the loop, which is what a bar counter driving a level wants: the same bar of the
## music is the same number every time round.
## @ace_hidden
func _take_the_loop() -> void:
	var deck: AudioStreamPlayer = _deck(_front)
	if deck == null:
		return
	deck.seek(_loop_start())
	_last_beat = -1
	_last_bar = -1

## Holds the duck down for a while, names how long it takes to come back up, and says WHERE it comes
## back up to - what a stinger does for its own length, without a timer node anywhere. `back_to` is
## the STANDING duck the hold hands the music back to: 0 for a stinger over nothing, and the
## dialogue duck for a stinger that landed over a line.
## @ace_hidden
func _hold_duck(seconds: float, release: float, back_to: float) -> void:
	_duck_hold = maxf(seconds, 0.0)
	_duck_release = maxf(release, 0.0)
	_duck_return_db = minf(back_to, 0.0)

## What a sting does to the duck, in one place so it can be driven with no sound file in the picture.
##
## A STINGER NEVER LIFTS A DUCK. The music may already be under a line of dialogue, and that line is
## still being spoken when the sting ends - so the sting ducks at least as far as whatever it found,
## and hands the music back to THAT rather than to full volume.
##
## What it hands back to is the STANDING duck - the one a row asked for and no row has lifted - never
## another sting's temporary one. While a hold is running, the level IN FORCE is that sting's own
## duck: a second sting handing back to the level it found would return the music to the first
## sting's decibels with no hold left to lift them, and the music would stay down for the rest of the
## game. So an overlapping sting inherits the standing level the hold was already carrying, and the
## last hold to run out is the one that lifts the music.
## @ace_hidden
func _begin_sting(depth_db: float, length: float) -> void:
	var in_force: float = _duck_target_db
	var standing: float = _duck_return_db if _duck_hold > 0.0 else in_force
	duck(maxf(absf(depth_db), absf(in_force)), 0.15)
	_hold_duck(maxf(length - 0.15, 0.0), 0.4, standing)

## One frame of every walk the director has running: the crossfade, the duck and each layer. It is
## a plain function of delta and the state above rather than a tween, which is what lets a test
## drive a whole crossfade in four calls and pin the level at each one - and what makes a fade that
## is halfway through survive a pause, a scene change and a slow frame without a node to lose.
## @ace_hidden
func advance(delta: float) -> void:
	_advance_levels(delta)
	_advance_duck(delta)
	_advance_layers(delta)

## The crossfade: both decks walk towards their targets at the same rate, so what one loses the
## other gains. A deck that has arrived at silence with nothing else asked of it is released.
## @ace_hidden
func _advance_levels(delta: float) -> void:
	if _fade_rate > 0.0:
		var step: float = _fade_rate * delta
		for index: int in range(_levels.size()):
			_levels[index] = move_toward(_levels[index], _level_targets[index], step)
	for index: int in range(_levels.size()):
		if is_zero_approx(_levels[index]) and is_zero_approx(_level_targets[index]):
			_release_deck(index)

## The duck: down over its seconds, held for as long as it was asked to hold, then back up on its
## own. A duck that was given no time simply arrives, so nothing here has to special-case it.
##
## The hold eats its own share of the frame and only the LEFTOVER walks, which matters on the frame
## a hold runs out: spending the whole delta on the walk as well would start the climb a frame's
## worth of the way up, and on a long frame that is an audible jump rather than a fade.
## @ace_hidden
func _advance_duck(delta: float) -> void:
	var walked: float = delta
	if _duck_hold > 0.0:
		var spent: float = minf(_duck_hold, delta)
		_duck_hold -= spent
		walked = delta - spent
		if _duck_hold <= 0.0:
			_duck_hold = 0.0
			if _duck_return_db < 0.0:
				duck(-_duck_return_db, _duck_release)
			else:
				unduck(_duck_release)
	if _duck_rate > 0.0 and walked > 0.0:
		_duck_db = move_toward(_duck_db, _duck_target_db, _duck_rate * walked)

## The layers: each one walks its own level at its own rate, because a game brings the drums up
## over a second and drops the strings out over four.
## @ace_hidden
func _advance_layers(delta: float) -> void:
	for key: Variant in _layer_targets.keys():
		var rate: float = float(_layer_rates.get(key, 0.0))
		if rate <= 0.0:
			continue
		_layer_levels[key] = move_toward(float(_layer_levels.get(key, 0.0)),
			float(_layer_targets[key]), rate * delta)

## Writes the levels the walks above arrived at onto the players and onto the synchronized stream's
## own volumes. Split from advance so that everything the director decides can be driven and
## pinned without an audio device, and only the writing needs one.
## @ace_hidden
func _apply_volumes() -> void:
	for index: int in range(_decks.size()):
		var deck: AudioStreamPlayer = _deck(index)
		if deck != null:
			deck.volume_db = deck_db(index)
	var front: AudioStreamPlayer = _deck(_front)
	if front == null:
		return
	var synchronized: AudioStreamSynchronized = front.stream as AudioStreamSynchronized
	if synchronized == null:
		return
	for index: int in range(_layer_order.size()):
		var level: float = float(_layer_levels.get(_layer_order[index], 0.0))
		synchronized.set_sync_stream_volume(index + 1, linear_to_db(maxf(level, SILENT_LEVEL)))

## Fires the beat triggers for a moment of the music, once each per beat. Nothing fires while
## nothing is playing, and the first beat of a new track always arrives because the numbers are
## reset when one starts.
## @ace_hidden
func _fire_beats(position: float, latency: float) -> void:
	var whole: int = floori(beat_at(position, latency))
	if whole == _last_beat:
		return
	_last_beat = whole
	beat.emit(whole)
	if beat_number_every > 0 and whole % beat_number_every == 0:
		nth_beat.emit(whole)
	var bar_index: int = floori(float(whole) / float(bar_beats()))
	if bar_index != _last_bar:
		_last_bar = bar_index
		bar.emit(bar_index)

## Whether the front deck's stream is actually running. NOT the same question as Is Playing: between
## the frame a track ends and the frame the engine says so, the name is still written down.
## @ace_hidden
func _front_is_running() -> bool:
	var deck: AudioStreamPlayer = _deck(_front)
	return deck != null and deck.playing

## A deck whose stream reached its end. A track that does not loop simply stops, and nothing else here
## would ever notice: the name would stay written down, Is Playing would go on saying yes, the frame
## would never park, and the next beat would be counted from a position of zero - which reads as the
## beat BEFORE the first one.
## @ace_hidden
func _deck_finished(index: int) -> void:
	_release_deck(index)
	set_process(true)

## Whether there is nothing left to do: no track on either deck and the duck back where it started.
## The director parks its own frame when this is true, so a game with the music stopped pays for
## nothing.
## @ace_hidden
func _at_rest() -> bool:
	for playing: String in _deck_tracks:
		if not playing.is_empty():
			return false
	return is_zero_approx(_duck_db) and is_zero_approx(_duck_target_db)

# Music (autoload): register as the Music autoload, then play tracks from any sheet. A track is a MusicTrackResource file you own - the stream, its layers, its tempo and its loop points - and the beat triggers read the stream's own position rather than counting, so they stay on the song. This pack is an event sheet - extend it by editing it.
