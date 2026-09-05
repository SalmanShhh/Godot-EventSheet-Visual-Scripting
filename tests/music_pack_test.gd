# Godot EventSheets - the Music pack, driven directly.
#
# A music director is a machine made almost entirely of numbers that move over time, and none of
# them can be seen in a screenshot: how loud each deck is halfway through a crossfade, how far the
# duck has come back up, which beat of the song the player is standing on. So this file loads the
# COMPILED pack, drives the real director with no scene tree, no audio device and no players at
# all, and pins the values it produces.
#
# Everything the director decides is a plain function of delta and its own state - there is not a
# Tween anywhere in the pack - which is exactly what lets a whole two-second crossfade be run here
# in two calls and inspected at the halfway mark.
#
# The traps it exists to catch, each one a rule the pack states and a reader would otherwise have
# to trust:
#   - the pack is the Music autoload, and every row it emits addresses it by that name;
#   - the beat is READ from the playback position less the output latency, never counted, so a
#     device with a big buffer moves the answer rather than being ignored;
#   - seconds to the next beat is a WHOLE beat when you are standing exactly on one;
#   - a duck walks in decibels at the rate its seconds asked for, and a duck given no time arrives;
#   - a stinger holds the duck for its own length and then comes back up with nobody asking;
#   - a layer that nothing has faded is silent, and Set Layers states the WHOLE mix rather than
#     changing one thing about it;
#   - a crossfade hands over between two decks and releases the one that reached silence, so a
#     third track can never start a crossfade over a crossfade;
#   - Pause keeps the position and Resume carries on, because a pause menu must not restart a song;
#   - a track's layers become ONE synchronized stream in sorted order, which is what stops them
#     drifting;
#   - a track file round-trips: what the Inspector wrote is what the director reads back.
@tool
class_name MusicPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/music/music_addon.gd"
const TRACK_RESOURCE := "res://eventsheet_addons/music_track_resource/music_track_resource.gd"
const TEST := "music_pack_test"

## Where the tracks this test writes live. A folder of its own so the director's own name lookup is
## exercised, rather than a path handed straight to it.
const TRACK_FOLDER := "user://music_pack_test/"


static func run() -> bool:
	var script: GDScript = load(PACK)
	var passed: bool = SUPPORT.check(TEST, "the pack loads and parses", script != null, true)
	if script == null:
		return passed
	_write_tracks()
	passed = _the_pack_ships_as_the_autoload(script) and passed
	passed = _the_beat_is_read_from_the_position(script) and passed
	passed = _a_beat_you_stand_on_has_already_happened(script) and passed
	passed = _ducking_walks_in_decibels(script) and passed
	passed = _a_held_duck_comes_back_up_on_its_own(script) and passed
	passed = _a_crossfade_hands_over_between_two_decks(script) and passed
	passed = _stopping_pausing_and_resuming(script) and passed
	passed = _layers_walk_and_set_layers_states_the_mix(script) and passed
	passed = _layers_become_one_synchronized_stream(script) and passed
	passed = _a_track_file_round_trips() and passed
	passed = _next_beat_at_rides_the_engine_clock(script) and passed
	passed = _a_stinger_over_a_duck_leaves_the_duck(script) and passed
	passed = _two_stings_over_each_other_still_come_back_up(script) and passed
	passed = _no_beat_fires_before_the_first_one(script) and passed
	passed = _a_song_with_an_intro_plays_it_once(script) and passed
	passed = _a_track_that_ends_stops_being_the_track(script) and passed
	_forget_tracks()
	return passed


# ── One director, reached from anywhere ───────────────────────────────────────────────────────


## Music is a project-wide service - one song playing at a time, for the whole game - so this pack
## ships as the Music AUTOLOAD the way Scene Flow and Save System do. That is not a remark about
## the file: it is what every row the pack emits ADDRESSES, so it is pinned against the shipped
## bytes rather than against the builder's intent.
static func _the_pack_ships_as_the_autoload(script: GDScript) -> bool:
	var source: String = FileAccess.get_file_as_string(PACK)
	var not_the_autoload: int = 0
	var published: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if not line.begins_with("## @ace_codegen_template("):
			continue
		if not line.begins_with("## @ace_codegen_template(\"Music."):
			not_the_autoload += 1
			continue
		published.append(line.substr(line.find("Music.") + 6).split("(")[0])
	var director: Node = script.new()
	var runs_while_paused: bool = director.has_method("pause_music") and director.has_method("resume_music")
	director.free()
	return SUPPORT.pins(TEST, [
		["every published verb addresses the autoload by name", not_the_autoload, 0],
		# NAMED, not counted: a pin on the number goes green on a run where one row arrived and
		# another went missing, and says nothing about either.
		["and every verb the builder declares is one of them", _sorted(published),
			["beat_number", "beat_phase", "crossfade_to", "current_track", "duck", "fade_layer",
				"is_playing", "layer_volume", "next_beat_at", "pause_music", "play",
				"position_in_bars", "resume_music", "seconds_to_next_beat", "set_layers",
				"set_music_volume", "set_tempo", "stinger", "stop_music", "switch_to_clip",
				"unduck"]],
		["nothing is scoped to a node, because an autoload has no host to act on",
			source.contains("var host: Node"), false],
		["the tree's pause does not silence the song by itself",
			source.contains("process_mode = Node.PROCESS_MODE_ALWAYS"), true],
		["so pausing the music is its own row", runs_while_paused, true],
	])


# ── The beat is read, never counted ───────────────────────────────────────────────────────────


## The whole promise of the beat rows: they are the stream's own playback position, less the output
## latency the audio device adds on the way out, turned into beats at the track's tempo. A counter
## would drift against the song within a minute, and a latency nobody subtracted would put every
## answer a buffer's width early.
##
## Driven from a STUBBED position and a stubbed latency, which is the only way to ask the question
## at all with no audio device in the room.
static func _the_beat_is_read_from_the_position(script: GDScript) -> bool:
	var director: Node = script.new()
	director.set_tempo(120.0, 0.0)
	var on_the_nose: float = director.beat_at(2.0, 0.0)
	var with_latency: float = director.beat_at(2.0, 0.1)
	var phase: float = director.beat_phase_at(2.25, 0.0)
	director.set_tempo(120.0, 0.25)
	var with_offset: float = director.beat_at(2.25, 0.0)
	director.set_tempo(90.0, 0.0)
	var slower: float = director.beat_at(2.0, 0.0)
	var bar_beats: int = director.bar_beats()
	director.free()
	return SUPPORT.pins(TEST, [
		["two seconds at 120 bpm is the fourth beat", _round(on_the_nose), 4.0],
		["a tenth of a second of output latency moves the answer back a fifth of a beat",
			_round(with_latency), 3.8],
		["a quarter-second offset puts the fourth beat a quarter-second later",
			_round(with_offset), 4.0],
		["the same two seconds at 90 bpm is three beats", _round(slower), 3.0],
		["halfway between beats reads as half a beat through one", _round(phase), 0.5],
		["and a director with no track bars in four", bar_beats, 4],
	])


## Seconds To Next Beat on an exact beat is a WHOLE beat, not nothing: the beat you are standing on
## has already happened, and a row waiting for "the next beat" that answered 0 would fire twice.
static func _a_beat_you_stand_on_has_already_happened(script: GDScript) -> bool:
	var director: Node = script.new()
	director.set_tempo(120.0, 0.0)
	var standing_on_one: float = director.seconds_to_beat(2.0, 0.0)
	var quarter_through: float = director.seconds_to_beat(2.125, 0.0)
	var just_before: float = director.seconds_to_beat(2.4, 0.0)
	director.free()
	return SUPPORT.pins(TEST, [
		["standing exactly on a beat, the next one is a whole beat away",
			_round(standing_on_one), 0.5],
		["a quarter of the way through a beat leaves three quarters of it",
			_round(quarter_through), 0.375],
		["and two fifths of the way through, a tenth of a second is left",
			_round(just_before), 0.1],
	])


# ── Under a voice ─────────────────────────────────────────────────────────────────────────────


## The duck is decibels walked over seconds, and the level and the duck are added in ONE place, so
## a crossfade and a duck can never fight over volume_db.
static func _ducking_walks_in_decibels(script: GDScript) -> bool:
	var director: Node = script.new()
	director.duck(8.0, 0.5)
	var at_the_start: float = director._duck_db
	director.advance(0.25)
	var halfway: float = director._duck_db
	director.advance(0.25)
	var arrived: float = director._duck_db
	director.advance(0.25)
	var stays: float = director._duck_db
	director.unduck(0.5)
	director.advance(0.5)
	var back_up: float = director._duck_db
	director.duck(6.0, 0.0)
	var instant: float = director._duck_db
	# A deck at full level under a 6 dB duck is 6 dB down: linear_to_db(1.0) is exactly 0.
	director._levels[0] = 1.0
	var deck_under_the_duck: float = director.deck_db(0)
	director.free()
	return SUPPORT.pins(TEST, [
		["a duck starts where the music was", _round(at_the_start), 0.0],
		["and is halfway down after half its seconds", _round(halfway), -4.0],
		["and arrives at the decibels it was asked for", _round(arrived), -8.0],
		["and stays there rather than walking past", _round(stays), -8.0],
		["Unduck brings it back to nothing", _round(back_up), 0.0],
		["a duck given no time simply arrives", _round(instant), -6.0],
		["and a deck at full volume reads the duck, because the two are added in one place",
			_round(deck_under_the_duck), -6.0],
	])


## A stinger ducks the music for exactly as long as the sound lasts and then brings it back up with
## nobody asking - which is the difference between a flourish and a mix that stays quiet for ever
## because somebody forgot the second row.
static func _a_held_duck_comes_back_up_on_its_own(script: GDScript) -> bool:
	var director: Node = script.new()
	director.duck(10.0, 0.0)
	director._hold_duck(1.0, 0.5, 0.0)
	director.advance(0.5)
	var still_down: float = director._duck_db
	director.advance(0.5)
	var released: float = director._duck_db
	director.advance(0.25)
	var coming_back: float = director._duck_db
	director.advance(0.25)
	var home: float = director._duck_db
	director.free()
	return SUPPORT.pins(TEST, [
		["the music stays down while the sting is playing", _round(still_down), -10.0],
		["it is still down on the frame the hold runs out", _round(released), -10.0],
		["then walks back up over the release it was given", _round(coming_back), -5.0],
		["and arrives at full without a second row", _round(home), 0.0],
	])


# ── The crossfade ─────────────────────────────────────────────────────────────────────────────


## Two decks and no more: what one loses the other gains, and the deck that reaches silence is
## released rather than left playing at nothing. That release is what stops a third track starting
## a crossfade over a crossfade - a mix nobody can hear the shape of.
static func _a_crossfade_hands_over_between_two_decks(script: GDScript) -> bool:
	var director: Node = _director(script)
	director.play("Forest", 0.0)
	var first_track: String = director.current_track()
	var first_tempo: float = director._bpm
	director.crossfade_to("Battle", 2.0)
	director.advance(1.0)
	var incoming_halfway: float = director._levels[director._front]
	var outgoing_halfway: float = director._levels[1 - director._front]
	director.advance(1.0)
	var incoming_arrived: float = director._levels[director._front]
	var outgoing_released: String = director._deck_tracks[1 - director._front]
	var second_track: String = director.current_track()
	var second_tempo: float = director._bpm
	director.play("nothing at all", 1.0)
	var unmoved: String = director.current_track()
	director.free()
	return SUPPORT.pins(TEST, [
		["a track played with no fade is up at once", first_track, "Forest"],
		["and its own tempo is what the beat rows count at", _round(first_tempo), 120.0],
		["halfway through a two-second crossfade the incoming deck is halfway up",
			_round(incoming_halfway), 0.5],
		["and the outgoing deck is halfway down", _round(outgoing_halfway), 0.5],
		["at the end the incoming deck is full", _round(incoming_arrived), 1.0],
		["the outgoing deck is released rather than left playing silently",
			outgoing_released, ""],
		["Current Track is the track that arrived", second_track, "Battle"],
		["whose tempo came with it", _round(second_tempo), 140.0],
		["and a name that finds no file changes nothing", unmoved, "Battle"],
	])


## Stop, Pause and Resume. Pause keeps the position on purpose: a pause menu that restarted the
## song every time it opened would be worse than one that let the song play on.
static func _stopping_pausing_and_resuming(script: GDScript) -> bool:
	var director: Node = _director(script)
	director.play("Forest", 0.0)
	var playing: bool = director.is_playing()
	director.pause_music()
	var while_paused: bool = director.is_playing()
	var kept: String = director.current_track()
	director.resume_music()
	var after_resume: bool = director.is_playing()
	director.stop_music(1.0)
	director.advance(0.5)
	var half_faded: float = director._levels[director._front]
	director.advance(0.5)
	var stopped: bool = director.is_playing()
	var forgotten: String = director.current_track()
	director.free()
	return SUPPORT.pins(TEST, [
		["a played track is playing", playing, true],
		["a paused one is not", while_paused, false],
		["but it has not been forgotten, so Resume carries on from the same place",
			kept, "Forest"],
		["and Resume puts it back", after_resume, true],
		["Stop fades over the seconds it was given", _round(half_faded), 0.5],
		["and the music is stopped once the fade lands", stopped, false],
		["with nothing left playing to name", forgotten, ""],
	])


# ── Layers ────────────────────────────────────────────────────────────────────────────────────


## A layer nothing has faded is silent, a fade walks it at the rate its seconds asked for, and Set
## Layers states the WHOLE mix - every layer named comes up, every other layer of the track goes
## down - which is what makes it safe to fire on every state change.
static func _layers_walk_and_set_layers_states_the_mix(script: GDScript) -> bool:
	var director: Node = _director(script)
	director.play("Forest", 0.0)
	var silent_at_the_start: float = director.layer_volume("drums")
	director.fade_layer("Drums", 1.0, 2.0)
	director.advance(1.0)
	var halfway_up: float = director.layer_volume("drums")
	var case_does_not_matter: float = director.layer_volume("DRUMS")
	director.set_layers("strings", 1.0)
	director.advance(0.5)
	var drums_falling: float = director.layer_volume("drums")
	var strings_rising: float = director.layer_volume("strings")
	director.advance(0.5)
	var drums_out: float = director.layer_volume("drums")
	var strings_in: float = director.layer_volume("strings")
	director.fade_layer("drums", 1.0, 0.0)
	var instant: float = director.layer_volume("drums")
	director.free()
	return SUPPORT.pins(TEST, [
		["a layer nobody has faded is silent", _round(silent_at_the_start), 0.0],
		["a two-second fade is halfway up after one", _round(halfway_up), 0.5],
		["and the layer's name is not case-sensitive", _round(case_does_not_matter), 0.5],
		["Set Layers takes the layer it did not name down", _round(drums_falling), 0.25],
		["while the one it did name comes up", _round(strings_rising), 0.5],
		["and both arrive", _round(drums_out), 0.0],
		["at the mix the row stated", _round(strings_in), 1.0],
		["a fade given no time simply arrives", _round(instant), 1.0],
	])


## The layers are ONE AudioStreamSynchronized rather than several players started at the same
## moment and hoped for, which is the whole reason they cannot drift after a pause. The slots are
## filled in sorted name order, so the slot a layer takes is the same on every machine.
static func _layers_become_one_synchronized_stream(script: GDScript) -> bool:
	var director: Node = _director(script)
	var track: Resource = load(TRACK_FOLDER + "forest.tres")
	var built: AudioStream = director._stream_for(track)
	var synchronized: AudioStreamSynchronized = built as AudioStreamSynchronized
	var order: String = ", ".join(director._layer_order)
	var plain: Resource = load(TRACK_FOLDER + "battle.tres")
	var unlayered: AudioStream = director._stream_for(plain)
	var no_layers: String = ", ".join(director._layer_order)
	director.free()
	return SUPPORT.pins(TEST, [
		["a track with layers plays as one synchronized stream", synchronized != null, true],
		["holding the song and every layer", synchronized.stream_count if synchronized != null else 0, 3],
		["with the song itself in the first slot",
			synchronized.get_sync_stream(0) == track.stream if synchronized != null else false, true],
		["and the layers in sorted order, so a slot means the same thing everywhere",
			order, "drums, strings"],
		["a track with no layers is played as it is, with no wrapper around it",
			unlayered is AudioStreamSynchronized, false],
		["and names no layers", no_layers, ""],
	])


# ── The track file ────────────────────────────────────────────────────────────────────────────


## A track is an ordinary resource file the game owns. What the Inspector wrote into it is what the
## director reads back out - which is the whole contract, and the reason the pack ships no tracks.
static func _a_track_file_round_trips() -> bool:
	var written: Resource = load(TRACK_FOLDER + "forest.tres")
	var layers: Dictionary = written.layers
	var names: Array = layers.keys()
	names.sort()
	return SUPPORT.pins(TEST, [
		["the name it answers to", str(written.track_name), "Forest"],
		["the song itself", written.stream != null, true],
		["the layers, by name", ", ".join(PackedStringArray(names)), "drums, strings"],
		["each carrying a stream of its own", layers["drums"] != null, true],
		["the tempo", _round(written.bpm), 120.0],
		["the offset to the first beat", _round(written.beat_offset), 0.0],
		["how many beats a bar holds", int(written.beats_per_bar), 4],
		["where the loop goes back to", _round(written.loop_from), 4.0],
		["and where it goes back FROM", _round(written.loop_to), 8.0],
	])


## Next Beat At answers on the ENGINE clock - the same one the Timed Input module's Beat Grade
## measures a press with - rather than in stream time, which is what lets a press be graded against
## the song with no arithmetic in the sheet at all.
static func _next_beat_at_rides_the_engine_clock(script: GDScript) -> bool:
	var director: Node = _director(script)
	var with_nothing_playing: float = director.next_beat_at()
	director.play("Battle", 0.0)
	director.set_tempo(120.0, 0.0)
	var ahead: float = director.next_beat_at() - Time.get_ticks_msec() / 1000.0
	var beat_seconds: float = director.seconds_to_next_beat()
	# Asked with the latency named rather than measured: what the audio device on THIS machine
	# adds is a fact about the machine, and a pin that read it would answer differently in CI.
	var from_a_standing_start: float = director.seconds_to_beat(0.0, 0.0)
	director.free()
	return SUPPORT.pins(TEST, [
		# NOTHING PLAYING HAS NO NEXT BEAT: a lane that took an answer here would place its notes
		# a fraction of a beat away instead of the lead it asked for.
		["a director with nothing playing answers no beat at all",
			_round(with_nothing_playing), 0.0],
		["the next beat is a moment in the future, not a position in the stream",
			absf(ahead - beat_seconds) < 0.05, true],
		["and at 120 bpm from a standing start that is half a second away",
			_round(from_a_standing_start), 0.5],
	])


## A STINGER OVER A LINE OF DIALOGUE. The music is already ducked under a voice when the sting lands,
## and the voice is still speaking when the sting ends - so the hold has to hand the music back to the
## duck it interrupted rather than to full volume, and the sting must not RAISE a deeper duck on its
## way in. Both halves are pinned, because either one alone puts the music over the line.
static func _a_stinger_over_a_duck_leaves_the_duck(script: GDScript) -> bool:
	var director: Node = script.new()
	director.duck(8.0, 0.0)
	var under_the_voice: float = director._duck_db
	# What Stinger does once its sound is loaded: duck at least as far as what it found, and hold.
	var standing: float = director._duck_target_db
	director.duck(maxf(3.0, absf(standing)), 0.0)
	director._hold_duck(0.5, 0.25, standing)
	var under_the_sting: float = director._duck_db
	director.advance(0.5)
	director.advance(0.25)
	var after_the_sting: float = director._duck_db
	director.advance(1.0)
	var still_under_the_voice: float = director._duck_db
	director.unduck(0.0)
	var when_the_line_ends: float = director._duck_db
	director.free()
	return SUPPORT.pins(TEST, [
		["a line of dialogue ducks the music", _round(under_the_voice), -8.0],
		["a quieter sting does not lift the duck it landed over", _round(under_the_sting), -8.0],
		["and when the sting ends the music comes back to the duck, not to full",
			_round(after_the_sting), -8.0],
		["and stays there for as long as the line lasts", _round(still_under_the_voice), -8.0],
		["until the row that ducked it brings it up", _round(when_the_line_ends), 0.0],
	])


## TWO STINGS THAT OVERLAP HAND THE MUSIC BACK TO WHAT WAS THERE BEFORE THE FIRST OF THEM. A sting
## returns the music to the duck it found, and while a hold is running the duck it finds is the
## PREVIOUS STING'S. A second sting returning to the level in force would therefore hand the music
## back to the first sting's decibels with no hold left to lift them: the mix would stay down for the
## rest of the game, and the director's own frame would go on running for ever to hold it there.
static func _two_stings_over_each_other_still_come_back_up(script: GDScript) -> bool:
	var director: Node = script.new()
	# Two two-second stings, a second apart, over nothing at all.
	director._begin_sting(6.0, 2.0)
	director.advance(1.0)
	director._begin_sting(6.0, 2.0)
	var wrote_down: float = director._duck_return_db
	director.advance(1.85)
	director.advance(0.4)
	var back_up: float = director._duck_db
	var aimed_at: float = director._duck_target_db
	var parks: bool = director._at_rest()
	# The same pair over a line of dialogue: both hand the music back to the LINE's duck.
	var under: Node = script.new()
	under.duck(8.0, 0.0)
	under._begin_sting(6.0, 2.0)
	under.advance(1.0)
	under._begin_sting(6.0, 2.0)
	under.advance(1.85)
	under.advance(0.4)
	var still_under_the_voice: float = under._duck_db
	var runs_on: bool = under._at_rest()
	under.unduck(0.0)
	var when_the_line_ends: float = under._duck_db
	director.free()
	under.free()
	return SUPPORT.pins(TEST, [
		["the second sting keeps the standing level the first one wrote down",
			_round(wrote_down), 0.0],
		["when both holds have run out the music is back at full", _round(back_up), 0.0],
		["aimed at full, not at the sting it was under", _round(aimed_at), 0.0],
		["and the director parks its own frame again", parks, true],
		["over a line, both stings hand the music back to the line's duck",
			_round(still_under_the_voice), -8.0],
		["which is not rest, because the line is still being spoken", runs_on, false],
		["until the row that ducked it brings it up", _round(when_the_line_ends), 0.0],
	])


## NO BEAT BEFORE THE FIRST ONE. A song whose first beat lands a second and a half into the file is
## standing at beat minus three when it opens, and On Beat handing a game a negative beat number is
## a beat that never happened: a lane spawning a note per beat would spawn three of them before the
## song had begun. The walk up to the first beat is still counted, so nothing fires twice afterwards.
static func _no_beat_fires_before_the_first_one(script: GDScript) -> bool:
	var director: Node = script.new()
	director.set_tempo(120.0, 1.5)
	var beats: Array = []
	var bars: Array = []
	director.beat.connect(func(number: int) -> void: beats.append(number))
	director.bar.connect(func(number: int) -> void: bars.append(number))
	# The play head walking from the top of the file to just before the third beat, an eighth of a
	# second at a time: at 120 bpm the beats are half a second apart, and the first is at 1.5 s.
	var at: float = 0.0
	while at < 2.4:
		director._fire_beats(at, 0.0)
		at += 0.125
	var counted: int = director._last_beat
	director.free()
	return SUPPORT.pins(TEST, [
		["the beats a song with a beat-and-a-half offset fires from its top are the real ones",
			beats, [0, 1]],
		["and its bars begin at the first one", bars, [0]],
		["while the count before the first beat is remembered rather than fired", counted, 1],
	])


## AN INTRO IS HEARD ONCE. A song written with an intro carries a loop point, and starting every play
## at that point means the intro never plays at all - which is the opposite of what the field is for.
## The first play of a song starts at its beginning; every play after it comes in at the loop.
static func _a_song_with_an_intro_plays_it_once(script: GDScript) -> bool:
	var director: Node = _director(script)
	var before_anything: float = director.start_position(true)
	director.play("Forest", 0.0)
	var opened_from: float = director.start_position(true)
	var came_back_to: float = director.start_position(false)
	var heard_it: bool = director._heard.has("Forest")
	var not_yet_at_the_loop: bool = director.loop_reached(7.9)
	var at_the_loop: bool = director.loop_reached(8.0)
	director.play("Battle", 0.0)
	var a_track_with_no_loop: bool = director.loop_reached(60.0)
	director.free()
	return SUPPORT.pins(TEST, [
		["with no track at all, a play starts at the beginning", _round(before_anything), 0.0],
		["the first time a song is asked for it plays from the beginning, intro and all",
			_round(opened_from), 0.0],
		["and every time after it comes in at the loop point the track wrote down",
			_round(came_back_to), 4.0],
		["which is remembered by the name the track answers to", heard_it, true],
		["a track is not at its loop end a tenth of a second early", not_yet_at_the_loop, false],
		["and is when it reaches the point it named", at_the_loop, true],
		["a track that names no loop end plays through", a_track_with_no_loop, false],
	])


## A TRACK THAT ENDS. A stream that does not loop simply stops, and nothing in the director would
## notice on its own: the name would stay written down, Is Playing would answer yes for ever, the
## frame would never park, and the beat would be counted from a position of zero - a beat BEFORE the
## first one. The deck's own finished signal is what says so, and this is the answer it leads to.
static func _a_track_that_ends_stops_being_the_track(script: GDScript) -> bool:
	var director: Node = _director(script)
	director.play("Battle", 0.0)
	var while_it_plays: bool = director.is_playing()
	var running_with_no_players: bool = director._front_is_running()
	director._deck_finished(director._front)
	var after_it_ends: bool = director.is_playing()
	var named: String = director.current_track()
	var nothing_left_to_do: bool = director._at_rest()
	director.free()
	return SUPPORT.pins(TEST, [
		["a track that was started is playing", while_it_plays, true],
		["and with no audio device in the room, no deck is running", running_with_no_players, false],
		["a track that reached its end is no longer playing", after_it_ends, false],
		["and there is nothing left to name", named, ""],
		["so the director parks its own frame", nothing_left_to_do, true],
	])


# ── The fixtures ──────────────────────────────────────────────────────────────────────────────


## A director whose Music Folder is this test's own, so the shipped name lookup is what finds the
## tracks rather than a path handed straight to it.
static func _director(script: GDScript) -> Node:
	var director: Node = script.new()
	director.music_folder = TRACK_FOLDER
	return director


## Two track files: one with layers and a loop point, one plain and at a different tempo, so a
## crossfade can be seen carrying the tempo across with it.
static func _write_tracks() -> void:
	DirAccess.make_dir_recursive_absolute(TRACK_FOLDER)
	var track_script: GDScript = load(TRACK_RESOURCE)
	var forest: Resource = track_script.new()
	forest.track_name = "Forest"
	forest.stream = _silence()
	forest.layers = {"strings": _silence(), "drums": _silence()}
	forest.bpm = 120.0
	forest.beats_per_bar = 4
	forest.loop_from = 4.0
	forest.loop_to = 8.0
	ResourceSaver.save(forest, TRACK_FOLDER + "forest.tres")
	var battle: Resource = track_script.new()
	battle.track_name = "Battle"
	battle.stream = _silence()
	battle.bpm = 140.0
	ResourceSaver.save(battle, TRACK_FOLDER + "battle.tres")


## The tracks this test wrote, taken back off the machine. A serial run of the whole suite inherits
## whatever the run before it left in user://, so a test that writes files puts them away again.
static func _forget_tracks() -> void:
	for name: String in ["forest.tres", "battle.tres"]:
		if FileAccess.file_exists(TRACK_FOLDER + name):
			DirAccess.remove_absolute(TRACK_FOLDER + name)
	DirAccess.remove_absolute(TRACK_FOLDER)


## A list of names in one order, whatever order they were gathered in - so a pin reads as the names
## the pack publishes rather than as the order a file happens to hold them in.
static func _sorted(names: PackedStringArray) -> Array:
	var sorted: Array = Array(names)
	sorted.sort()
	return sorted


## One audio stream, carrying nothing. The director never reads a sample - it reads the position -
## so an empty stream is a whole track as far as everything pinned here is concerned.
static func _silence() -> AudioStream:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.data = PackedByteArray()
	return stream


## Floats compared at four decimal places, because the arithmetic here is decimal arithmetic done
## in binary: two seconds less a tenth, times 120, over 60 is 3.8000000000000003, and a pin against
## a literal 3.8 would be red for no reason anybody could act on.
##
## Rounded by multiply-and-DIVIDE rather than by snappedf, because snapping multiplies back up by
## the step and lands on 3.8000000000000003 again - the same number the pin was red for. Dividing
## gives the nearest double to 3.8, which is exactly what the literal in the pin is.
static func _round(value: float) -> float:
	return roundf(value * 10000.0) / 10000.0
