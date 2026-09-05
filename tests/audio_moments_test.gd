# A bus swept rather than switched - the muffle, the dive, the wash, the walk home and the mix
# snapshot, pinned on a REAL bus in the running AudioServer.
#
# The claim this file holds to account has four parts:
#
#   * THE EFFECT IS ADDED ONCE AND KEPT. The first sweep of a kind on a bus adds the engine effect it
#     moves, opened at the value that does nothing; every sweep after that reuses the same one. Pinned
#     by arming twice and counting what the bus is carrying.
#   * A SWEEP IS A NUMBER MOVING, and the number is pinned by VALUE after hand-stepped ticks rather
#     than by watching a frame go by: the same write a played sweep steps through, stepped here.
#   * HOME IS WHERE THE MIX WAS. The value an effect rested at before the first sweep touched it is
#     what Restore Bus walks back to, not where the last beat left it.
#   * A SNAPSHOT IS THE MIX. Level, silence and focus, written down under a name the project chose
#     and put back - three values per bus, and nothing shipped for anybody.
#
# The bus is made here and taken away again, so the mixing desk this test finished with is the one it
# found. Same for the three books the runtime keeps on the Engine: whatever was there before this
# test ran is put back after it, which is what lets a serial run put this test anywhere in its order.
@tool
class_name AudioMomentsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/audio_server_aces.gd")

## The bus this test does its work on. Named after the test so a parallel shard cannot collide with
## another one's desk.
const TEST_BUS: String = "EventForgeAudioMomentsTestBus"

## Where the walk starts and where it lands, so the hand-stepped ticks and the pins read the same two
## numbers rather than two copies of them.
const FROM_HZ: float = 20500.0
const TO_HZ: float = 400.0


static func run() -> bool:
	var kept: Dictionary = _books_as_found()
	var ok: bool = true
	ok = _test_the_rows() and ok
	ok = _test_the_effect_is_added_once_and_kept() and ok
	ok = _test_a_sweep_lands_on_its_target() and ok
	ok = _test_the_walk_home_is_where_the_mix_was() and ok
	ok = _test_nothing_is_left_in_the_air() and ok
	ok = _test_a_snapshot_puts_three_values_back() and ok
	ok = _test_a_snapshot_nobody_took_changes_nothing() and ok
	_put_the_books_back(kept)
	return ok


## The eight rows, by the bytes they emit and the fields they hand a reader. Every one of them names
## the runtime in the project's own folder, never a plugin class.
static func _test_the_rows() -> bool:
	var templates: Dictionary = {}
	var fields: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		templates[row.ace_id] = str(row.codegen_template)
		var named: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in row.params:
			named.append("%s=%s" % [parameter.id, str(parameter.default_value)])
		fields[row.ace_id] = ", ".join(named)
	return SUPPORT.pins("audio_moments_test", [
		["muffling is one call", templates.get("AudioMuffleBus", ""),
			"EventForgeBusMix.muffle(self, {bus}, {cutoff_hz}, {seconds})"],
		["so is the dive", templates.get("AudioDiveBusVolume", ""),
			"EventForgeBusMix.dive(self, {bus}, {volume_db}, {seconds})"],
		["and the wash", templates.get("AudioWashBus", ""),
			"EventForgeBusMix.wash(self, {bus}, {wetness}, {seconds})"],
		["the walk home names no kind, because it walks them all",
			templates.get("AudioRestoreBus", ""),
			"EventForgeBusMix.restore(self, {bus}, {seconds})"],
		["a snapshot is taken by name", templates.get("AudioSnapshotBuses", ""),
			"EventForgeBusMix.snapshot({snapshot_name})"],
		["and recalled over a length of time", templates.get("AudioRecallBusSnapshot", ""),
			"EventForgeBusMix.recall(self, {snapshot_name}, {seconds})"],
		["the sweeping question is a condition", templates.get("AudioBusIsSweeping", ""),
			"EventForgeBusMix.is_sweeping({bus})"],
		["the muffle row's fields", fields.get("AudioMuffleBus", ""),
			"bus=\"Master\", cutoff_hz=400.0, seconds=0.12"],
		["the recall row's fields", fields.get("AudioRecallBusSnapshot", ""),
			"snapshot_name=\"normal\", seconds=0.3"]
	])


## Arming twice adds one effect, not two, and the one it adds is opened at the value that does
## nothing - so a bus that has met a muffle row and never swept sounds exactly as it did.
static func _test_the_effect_is_added_once_and_kept() -> bool:
	var index: int = _fresh_bus()
	var before: int = AudioServer.get_bus_effect_count(index)
	var first: AudioEffect = EventForgeBusMix.arm(TEST_BUS, EventForgeBusMix.MUFFLE)
	var opened: float = EventForgeBusMix.read(TEST_BUS, EventForgeBusMix.MUFFLE)
	var again: AudioEffect = EventForgeBusMix.arm(TEST_BUS, EventForgeBusMix.MUFFLE)
	var ok: bool = SUPPORT.pins("audio_moments_test", [
		["the bus started with no effects on it", before, 0],
		["arming adds the filter a muffle moves", first is AudioEffectLowPassFilter, true],
		["opened so wide it does nothing", opened, EventForgeBusMix.OPEN_CUTOFF_HZ],
		["arming again reuses the same one", again == first, true],
		["so the bus layout gains one slot and never gains another",
			AudioServer.get_bus_effect_count(index), 1],
		["a dive moves an amplify, never the volume the player set",
			EventForgeBusMix.arm(TEST_BUS, EventForgeBusMix.DIVE) is AudioEffectAmplify, true],
		["and a wash moves a reverb",
			EventForgeBusMix.arm(TEST_BUS, EventForgeBusMix.WASH) is AudioEffectReverb, true],
		["a word that is not a way to sweep a bus arms nothing",
			EventForgeBusMix.arm(TEST_BUS, "thicken") == null, true]
	])
	_drop_bus()
	return ok


## The sweep, stepped by hand: the same write a played walk steps through, called at the quarter, the
## half and the end, and the cutoff read back off the real bus each time.
static func _test_a_sweep_lands_on_its_target() -> bool:
	_fresh_bus()
	EventForgeBusMix.arm(TEST_BUS, EventForgeBusMix.MUFFLE)
	var read_at: Array = []
	for step: float in [0.25, 0.5, 1.0]:
		EventForgeBusMix.write(lerpf(FROM_HZ, TO_HZ, step), TEST_BUS, EventForgeBusMix.MUFFLE)
		read_at.append(EventForgeBusMix.read(TEST_BUS, EventForgeBusMix.MUFFLE))
	var ok: bool = SUPPORT.pins("audio_moments_test", [
		["a quarter of the way down", read_at[0], lerpf(FROM_HZ, TO_HZ, 0.25)],
		["half way", read_at[1], lerpf(FROM_HZ, TO_HZ, 0.5)],
		["and landed on the number the row named", read_at[2], TO_HZ]
	])
	_drop_bus()
	return ok


## A sweep with nowhere to walk - no node, or a node that is not in a tree - writes the value at once
## rather than promising a walk nothing would ever step. And the walk home goes to where the mix was
## resting BEFORE any of it, not to where the last sweep left it.
static func _test_the_walk_home_is_where_the_mix_was() -> bool:
	_fresh_bus()
	EventForgeBusMix.muffle(null, TEST_BUS, TO_HZ, 0.0)
	var muffled: float = EventForgeBusMix.read(TEST_BUS, EventForgeBusMix.MUFFLE)
	EventForgeBusMix.dive(null, TEST_BUS, -18.0, 0.0)
	var dived: float = EventForgeBusMix.read(TEST_BUS, EventForgeBusMix.DIVE)
	EventForgeBusMix.muffle(null, TEST_BUS, 900.0, 0.0)
	EventForgeBusMix.restore(null, TEST_BUS, 0.0)
	var ok: bool = SUPPORT.pins("audio_moments_test", [
		["a hostless sweep writes its number at once", muffled, TO_HZ],
		["the dive lands on the amplify's level", dived, -18.0],
		["the walk home opens the filter again",
			EventForgeBusMix.read(TEST_BUS, EventForgeBusMix.MUFFLE),
			EventForgeBusMix.OPEN_CUTOFF_HZ],
		["and puts the level back where it was, not where the last beat left it",
			EventForgeBusMix.read(TEST_BUS, EventForgeBusMix.DIVE),
			EventForgeBusMix.OPEN_VOLUME_DB]
	])
	_drop_bus()
	return ok


## Every sweep parks: a walk that has landed is not in the air, and a bus nothing is walking on is not
## sweeping. Pinned as the book itself, because "parked" here means nothing is left behind to tick.
static func _test_nothing_is_left_in_the_air() -> bool:
	_fresh_bus()
	EventForgeBusMix.muffle(null, TEST_BUS, TO_HZ, 0.0)
	EventForgeBusMix.wash(null, TEST_BUS, 0.5, 0.0)
	var ok: bool = SUPPORT.pins("audio_moments_test", [
		["a bus nobody is walking on is not sweeping",
			EventForgeBusMix.is_sweeping(TEST_BUS), false],
		["and neither is one that never met a row",
			EventForgeBusMix.is_sweeping("Master"), false],
		["with nothing left in the air to be ticked",
			Engine.get_meta(EventForgeBusMix.SWEEPING_META, {}).is_empty(), true]
	])
	_drop_bus()
	return ok


## The three things a snapshot remembers about one bus, changed and put back. Nothing ships: the mix
## in the pins is the one this test set up, which is exactly how a project's own is made.
static func _test_a_snapshot_puts_three_values_back() -> bool:
	var index: int = _fresh_bus()
	AudioServer.set_bus_volume_db(index, -6.0)
	AudioServer.set_bus_mute(index, true)
	AudioServer.set_bus_solo(index, true)
	EventForgeBusMix.snapshot("__audio_moments_test")
	AudioServer.set_bus_volume_db(index, 0.0)
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_solo(index, false)
	var taken: bool = EventForgeBusMix.has_snapshot("__audio_moments_test")
	EventForgeBusMix.recall(null, "__audio_moments_test", 0.0)
	var ok: bool = SUPPORT.pins("audio_moments_test", [
		["the mix was written down under the name the project chose", taken, true],
		["the level comes back", AudioServer.get_bus_volume_db(index), -6.0],
		["the silence comes back", AudioServer.is_bus_mute(index), true],
		["and the focus comes back", AudioServer.is_bus_solo(index), true]
	])
	_drop_bus()
	return ok


## A name nobody has taken changes nothing at all, rather than inventing a mix out of the defaults.
static func _test_a_snapshot_nobody_took_changes_nothing() -> bool:
	var index: int = _fresh_bus()
	AudioServer.set_bus_volume_db(index, -3.0)
	EventForgeBusMix.recall(null, "__audio_moments_test_never_taken", 0.0)
	var ok: bool = SUPPORT.pins("audio_moments_test", [
		["a snapshot nobody took does not exist",
			EventForgeBusMix.has_snapshot("__audio_moments_test_never_taken"), false],
		["and recalling it leaves the desk exactly as it was",
			AudioServer.get_bus_volume_db(index), -3.0]
	])
	_drop_bus()
	return ok


## A bus of this test's own, added at the end of the layout and empty of effects.
static func _fresh_bus() -> int:
	_drop_bus()
	AudioServer.add_bus()
	var index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, TEST_BUS)
	return index


## And taken away again, which takes its effects with it - so the mixing desk this test finished with
## is the one it found.
static func _drop_bus() -> void:
	var index: int = AudioServer.get_bus_index(TEST_BUS)
	if index > 0:
		AudioServer.remove_bus(index)


## The three books the runtime keeps on the Engine, exactly as this test found them.
static func _books_as_found() -> Dictionary:
	var kept: Dictionary = {}
	for named: StringName in _book_names():
		if Engine.has_meta(named):
			kept[named] = (Engine.get_meta(named) as Dictionary).duplicate(true)
	return kept


## Put back: a book this test found is restored to what it held, and one it created is removed, so
## the Engine ledger balances whatever order a serial run put this test in.
static func _put_the_books_back(kept: Dictionary) -> void:
	for named: StringName in _book_names():
		if kept.has(named):
			Engine.set_meta(named, kept[named])
		elif Engine.has_meta(named):
			Engine.remove_meta(named)


static func _book_names() -> Array[StringName]:
	return [EventForgeBusMix.SWEEPING_META, EventForgeBusMix.RESTING_META,
		EventForgeBusMix.SNAPSHOTS_META]
