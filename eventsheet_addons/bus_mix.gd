## @ace_version(1.0.0)
class_name EventForgeBusMix
extends RefCounted
## A bus swept rather than switched - the muffle, the dive, the wash and the mix snapshot the Muffle Bus, Dive Bus Volume, Wash Bus, Restore Bus, Snapshot Buses As and Recall Bus Snapshot rows call.

# A BUS SWEPT RATHER THAN SWITCHED.
#
# The bus rows beside these flip a prepared effect on and off, which is one frame's worth of change:
# the world is dry, then it is underwater. A hit does not feel like that. What a heavy hit feels
# like is the room going under for a tenth of a second and coming back, and that is a NUMBER MOVING -
# a cutoff walking down and up again, a level dipping and returning, a reverb welling up behind the
# rest of the mix. This file is those walks.
#
# THREE SWEEPS, AND WHAT EACH ONE REALLY MOVES:
#   muffle   the cutoff of a low-pass filter on the bus. Everything above the cutoff goes quiet, so
#            400 Hz is a pillow over the speaker and 20500 is not there at all.
#   dive     the level of an AMPLIFY effect on the bus - never the bus's own volume. The player set
#            that in the options screen and it is theirs; a beat that moved it would be arguing with
#            them, and worse, would leave their setting wherever the beat happened to end.
#   wash     the wet amount of a reverb on the bus, with its dry left alone, so the room grows behind
#            the sound instead of replacing it.
#
# THE EFFECT IS ADDED ONCE AND KEPT. The first sweep of a kind on a bus looks for an effect of that
# kind already in the bus layout and uses it; when there is none it adds one, opened at the value
# that does nothing at all, so adding it is silent. Every sweep after that reuses it. The bus layout
# in the Audio panel therefore GAINS a slot the first time a game runs one of these rows, which the
# rows say in their own help rather than leaving somebody to find it.
#
# WHERE HOME IS. The value an effect had when a sweep first touched it is written down as that bus's
# resting value, and Restore Bus walks every armed kind back to it. So a moment can dive and never
# say how to come back up, and one row at the end of it puts the room right.
#
# A SNAPSHOT IS THE MIX, NOT A STYLE. Snapshot Buses As writes down every bus's level, mute and solo
# under a name the project chose, and Recall Bus Snapshot walks them back. Nothing ships: there is no
# house "underwater" and no house "paused", because a game's mix is the game's. The first snapshot is
# taken from the live desk, usually at startup and usually called normal.
#
# PLAIN GDSCRIPT, AND NOT THE PLUGIN'S. Nothing here touches an editor, a sheet or any class the
# plugin declares, and this file ships in the project's OWN folder rather than in the plugin's, so a
# sheet holding one of these rows goes on parsing and running after the editor is gone.
#
# THE COST. A sweep is one Tween walking one float, which the engine parks and frees the moment it
# lands; at rest the whole file costs nothing at all. A snapshot is one walk of the bus list, taken
# when the row runs and never per frame. Nothing here allocates while a sweep is in the air.

## The three kinds a bus is swept by, spelled once so the rows, the resting values and the tests all
## say the same word.
const MUFFLE: String = "muffle"
const DIVE: String = "dive"
const WASH: String = "wash"

## The cutoff at which a low-pass is not there: above anything a person hears, which is why arming a
## muffle is silent until the sweep starts moving.
const OPEN_CUTOFF_HZ: float = 20500.0

## The level at which an amplify is not there, and the wet at which a reverb is not there.
const OPEN_VOLUME_DB: float = 0.0
const OPEN_WET: float = 0.0

## Where the live sweeps, the resting values and the named snapshots are kept. On the Engine, because
## a mix outlives the scene that changed it: a dive started in the arena has to finish even if the
## arena is freed halfway through, and a snapshot taken at startup has to be there in the third
## level. The names are constants so a test can put back exactly what it found.
const SWEEPING_META: StringName = &"eventforge_bus_sweeping"
const RESTING_META: StringName = &"eventforge_bus_resting"
const SNAPSHOTS_META: StringName = &"eventforge_bus_snapshots"

## The three things a snapshot remembers about one bus. Level, silence and focus: what a mix IS from
## the outside, and all three restorable without touching a single effect the game set up by hand.
const VOLUME_KEY: String = "volume_db"
const MUTED_KEY: String = "muted"
const SOLOED_KEY: String = "soloed"


## Sweeps a bus's low-pass cutoff to `cutoff_hz` over `seconds`, adding the filter the first time and
## reusing it after. Low numbers are underwater; Restore Bus opens it again.
static func muffle(host: Node, bus: String, cutoff_hz: float, seconds: float) -> void:
	sweep(host, bus, MUFFLE, cutoff_hz, seconds)


## Sweeps a bus's level down to `volume_db` over `seconds` through an amplify effect - never through
## the bus volume the player chose in the options screen.
static func dive(host: Node, bus: String, volume_db: float, seconds: float) -> void:
	sweep(host, bus, DIVE, volume_db, seconds)


## Sweeps a reverb's wet amount up to `wetness` (0 to 1) over `seconds`, leaving its dry alone, so
## the room grows behind the sound rather than replacing it.
static func wash(host: Node, bus: String, wetness: float, seconds: float) -> void:
	sweep(host, bus, WASH, wetness, seconds)


## Walks every kind this bus has been swept by back to the value it rested at before the first sweep
## touched it, over `seconds`. The one row at the end of a beat that puts the room right.
static func restore(host: Node, bus: String, seconds: float) -> void:
	var resting: Dictionary = _resting().get(bus, {}) as Dictionary
	for kind: String in resting.keys():
		sweep(host, bus, kind, float(resting[kind]), seconds)


## The one sweep behind the four rows: arm the effect, note where home is, and walk the value there.
## With no node to walk in - no host, or a host that is not in the tree yet - the value is written at
## once, which is the honest answer rather than a walk nothing would ever step.
static func sweep(host: Node, bus: String, kind: String, to: float, seconds: float) -> void:
	var effect: AudioEffect = arm(bus, kind)
	if effect == null:
		return
	var from: float = read(bus, kind)
	if seconds <= 0.0 or host == null or not host.is_inside_tree():
		write(to, bus, kind)
		return
	_sweeping_by(bus, 1)
	var tween: Tween = host.create_tween()
	tween.tween_method(func(value: float) -> void: write(value, bus, kind), from, to, seconds)
	tween.tween_callback(func() -> void: _sweeping_by(bus, -1))


## Finds or adds the effect one kind is swept through, and writes down the value it was resting at
## the first time this bus met that kind. An effect this file ADDS is opened at the value that does
## nothing, so arming is silent; one the project put there itself is left exactly as it was found.
static func arm(bus: String, kind: String) -> AudioEffect:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("Bus mix: there is no bus called \"%s\" in this project's bus layout." % bus)
		return null
	var found: AudioEffect = _effect_on(index, kind)
	if found == null:
		found = _new_effect(kind)
		if found == null:
			push_warning("Bus mix: \"%s\" is not a way to sweep a bus - muffle, dive and wash are." % kind)
			return null
		_write_to(found, kind, _open_value(kind))
		AudioServer.add_bus_effect(index, found)
	_rest_at(bus, kind, _read_from(found, kind))
	return found


## What one kind reads on a bus right now, or the value that kind does nothing at when the bus has no
## effect of that kind at all.
static func read(bus: String, kind: String) -> float:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return _open_value(kind)
	var found: AudioEffect = _effect_on(index, kind)
	return _read_from(found, kind) if found != null else _open_value(kind)


## Writes one kind's value on a bus. This is what a sweep steps through, so a test can step it by
## hand and read the same numbers a played sweep writes.
static func write(value: float, bus: String, kind: String) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var found: AudioEffect = _effect_on(index, kind)
	if found != null:
		_write_to(found, kind, value)


## True while any sweep on this bus is still in the air - the question a row asks before starting a
## second beat over the top of the first.
static func is_sweeping(bus: String) -> bool:
	return int(_sweeping().get(bus, 0)) > 0


## Writes down every bus's level, silence and focus under a name the project chose. Taken from the
## live desk, so the first one is whatever the game sounds like at the moment it is asked for.
static func snapshot(snapshot_name: String) -> void:
	var taken: Dictionary = {}
	for index: int in AudioServer.get_bus_count():
		taken[AudioServer.get_bus_name(index)] = {
			VOLUME_KEY: AudioServer.get_bus_volume_db(index),
			MUTED_KEY: AudioServer.is_bus_mute(index),
			SOLOED_KEY: AudioServer.is_bus_solo(index)
		}
	_snapshots()[snapshot_name] = taken


## Puts a named snapshot back: the levels walked over `seconds`, the mutes and solos cut at once,
## because there is nothing between silent and not silent to walk through. A name nobody has taken
## says so rather than changing the mix to something invented.
static func recall(host: Node, snapshot_name: String, seconds: float) -> void:
	if not has_snapshot(snapshot_name):
		push_warning("Bus mix: no snapshot called \"%s\" has been taken - take one with Snapshot Buses As before recalling it." % snapshot_name)
		return
	var taken: Dictionary = _snapshots()[snapshot_name] as Dictionary
	var walking: bool = seconds > 0.0 and host != null and host.is_inside_tree()
	var tween: Tween = host.create_tween() if walking else null
	if tween != null:
		tween.set_parallel(true)
	for bus: String in taken.keys():
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var state: Dictionary = taken[bus] as Dictionary
		AudioServer.set_bus_mute(index, bool(state[MUTED_KEY]))
		AudioServer.set_bus_solo(index, bool(state[SOLOED_KEY]))
		if tween == null:
			AudioServer.set_bus_volume_db(index, float(state[VOLUME_KEY]))
		else:
			var named: String = bus
			tween.tween_method(func(value: float) -> void: _write_volume(value, named),
				AudioServer.get_bus_volume_db(index), float(state[VOLUME_KEY]), seconds)


## Whether a snapshot of that name has been taken this run.
static func has_snapshot(snapshot_name: String) -> bool:
	return _snapshots().has(snapshot_name)


## The value one kind does nothing at - where an effect this file adds is opened, and what a bus with
## no effect of that kind reads as.
static func _open_value(kind: String) -> float:
	match kind:
		MUFFLE:
			return OPEN_CUTOFF_HZ
		DIVE:
			return OPEN_VOLUME_DB
		WASH:
			return OPEN_WET
	return 0.0


## The effect on a bus one kind is swept through, or null when the bus has none of that kind yet.
static func _effect_on(index: int, kind: String) -> AudioEffect:
	for slot: int in AudioServer.get_bus_effect_count(index):
		var found: AudioEffect = AudioServer.get_bus_effect(index, slot)
		if _is_kind(found, kind):
			AudioServer.set_bus_effect_enabled(index, slot, true)
			return found
	return null


## Whether one effect is the kind a sweep word means.
static func _is_kind(effect: AudioEffect, kind: String) -> bool:
	match kind:
		MUFFLE:
			return effect is AudioEffectLowPassFilter
		DIVE:
			return effect is AudioEffectAmplify
		WASH:
			return effect is AudioEffectReverb
	return false


## A fresh effect of one kind, or null for a word that is not a kind.
static func _new_effect(kind: String) -> AudioEffect:
	match kind:
		MUFFLE:
			return AudioEffectLowPassFilter.new()
		DIVE:
			return AudioEffectAmplify.new()
		WASH:
			var reverb: AudioEffectReverb = AudioEffectReverb.new()
			reverb.dry = 1.0
			return reverb
	return null


## The property one kind moves, read off an effect.
static func _read_from(effect: AudioEffect, kind: String) -> float:
	match kind:
		MUFFLE:
			return (effect as AudioEffectLowPassFilter).cutoff_hz
		DIVE:
			return (effect as AudioEffectAmplify).volume_db
		WASH:
			return (effect as AudioEffectReverb).wet
	return 0.0


## And the same property written.
static func _write_to(effect: AudioEffect, kind: String, value: float) -> void:
	match kind:
		MUFFLE:
			(effect as AudioEffectLowPassFilter).cutoff_hz = maxf(value, 1.0)
		DIVE:
			(effect as AudioEffectAmplify).volume_db = value
		WASH:
			(effect as AudioEffectReverb).wet = clampf(value, 0.0, 1.0)


## One bus's level, as a recall's walk steps it.
static func _write_volume(value: float, bus: String) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)


## Notes where one kind rested on one bus, the FIRST time that bus met that kind and never again -
## home is where the mix was before any beat touched it, not where the last beat left it.
static func _rest_at(bus: String, kind: String, value: float) -> void:
	var resting: Dictionary = _resting()
	var per_bus: Dictionary = resting.get(bus, {}) as Dictionary
	if not per_bus.has(kind):
		per_bus[kind] = value
	resting[bus] = per_bus


## Counts a sweep in or out of the air on one bus.
static func _sweeping_by(bus: String, change: int) -> void:
	var sweeping: Dictionary = _sweeping()
	var left: int = int(sweeping.get(bus, 0)) + change
	if left > 0:
		sweeping[bus] = left
	else:
		sweeping.erase(bus)


## The three books this file keeps, each made the first time it is opened.
static func _sweeping() -> Dictionary:
	return _book(SWEEPING_META)


static func _resting() -> Dictionary:
	return _book(RESTING_META)


static func _snapshots() -> Dictionary:
	return _book(SNAPSHOTS_META)


static func _book(named: StringName) -> Dictionary:
	if not Engine.has_meta(named):
		Engine.set_meta(named, {})
	return Engine.get_meta(named) as Dictionary
