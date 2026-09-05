# A hit felt in the hand: the shape a haptic pattern really is, the player's dial over it, and the
# two platforms where the whole vocabulary is silent on purpose.
#
# The claim this file holds to account has four parts:
#
#   * A PATTERN IS A SHAPE, not a motor strength. Pinned as the phases themselves - when each pulse
#     starts and how long it lasts - because that arithmetic is the whole of what a pattern means and
#     it can be asked without a device, a tree or a frame.
#   * NOTHING SHIPS. A new pattern opens on a single short tap and every other shape is made from
#     there, so the starter is pinned as the resource's own defaults rather than as a file.
#   * THE PLAYER'S DIAL IS ONE NUMBER, read by every row through one function, and 0 means off.
#   * THE SILENCE IS DELIBERATE. On the web there is nothing to rumble, and the answer is a quiet
#     no-op plus ONE note on the way to shipping - never a warning per row.
#
# The dial lives on the Engine, so whatever was there before this test ran is put back after it.
@tool
class_name HapticsWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/vibration_aces.gd")
const SHIP_IT := preload("res://addons/eventforge/ship_it_doctor.gd")


static func run() -> bool:
	var kept: Dictionary = _dials_as_found()
	var ok: bool = true
	ok = _test_the_rows() and ok
	ok = _test_a_new_pattern_is_one_short_tap() and ok
	ok = _test_a_pattern_is_its_phases() and ok
	ok = _test_the_players_dial_scales_every_row() and ok
	ok = _test_a_pattern_is_taken_as_a_file_or_as_a_path() and ok
	ok = _test_the_web_is_silent() and ok
	ok = _test_the_doctor_says_it_once() and ok
	_put_the_dials_back(kept)
	return ok


## The eight rows, by the bytes they emit. The three device rows beside them are untouched, which is
## the point of the pair: the machine's words stay, and the hand's words land next to them.
static func _test_the_rows() -> bool:
	var templates: Dictionary = {}
	var fields: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		templates[row.ace_id] = str(row.codegen_template)
		var named: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in row.params:
			named.append("%s=%s" % [parameter.id, str(parameter.default_value)])
		fields[row.ace_id] = ", ".join(named)
	return SUPPORT.pins("haptics_words_test", [
		["a shape is one call", templates.get("HapticPlay", ""),
			"EventForgeHaptics.play(self, {pattern})"],
		["an emphasis carries its own strength and no file",
			templates.get("HapticEmphasis", ""), "EventForgeHaptics.emphasis({strength})"],
		["the continuous rumble starts with one call", templates.get("HapticContinuousStart", ""),
			"EventForgeHaptics.continuous_start({amplitude})"],
		["and stops with one", templates.get("HapticContinuousStop", ""),
			"EventForgeHaptics.continuous_stop()"],
		["the dial is written the way every other accessibility dial is",
			templates.get("SetHapticStrength", ""),
			"Engine.set_meta(\"haptic_strength\", clampf({percent} / 100.0, 0.0, 1.0))"],
		["and read the same way", templates.get("HapticStrength", ""),
			"float(Engine.get_meta(\"haptic_strength\", 1.0))"],
		["the shape row picks a file rather than typing a path",
			fields.get("HapticPlay", ""), "pattern=\"\""],
		["the three device rows are untouched", templates.get("VibrationHandheld", ""),
			"Input.vibrate_handheld({duration_ms})"]
	])


## Nothing ships. A pattern nobody has edited is a single short tap, which is the one shape that is
## not a taste, and every other shape is made from it.
static func _test_a_new_pattern_is_one_short_tap() -> bool:
	var fresh: HapticPatternResource = HapticPatternResource.new()
	return SUPPORT.pins("haptics_words_test", [
		["a new pattern is at full strength", fresh.amplitude, 1.0],
		["short", fresh.seconds, 0.08],
		["and once", fresh.repeats, 1],
		["so its whole length is that one pulse", fresh.length(), 0.08]
	])


## The shape itself: when each pulse starts, measured from the beginning, and how long it lasts. The
## air between is what makes a repeat a repeat - without it four pulses are one long buzz.
##
## The lengths here are eighths and quarters on purpose: those land EXACTLY in binary, so a pin that
## says 0.375 is a pin about the arithmetic rather than about how a tenth is stored.
static func _test_a_pattern_is_its_phases() -> bool:
	var alarm: HapticPatternResource = HapticPatternResource.new()
	alarm.seconds = 0.125
	alarm.gap_seconds = 0.25
	alarm.repeats = 3
	var shape: Array[Dictionary] = EventForgeHaptics.phases(alarm)
	return SUPPORT.pins("haptics_words_test", [
		["three pulses", shape.size(), 3],
		["the first at the beginning", shape[0]["at"], 0.0],
		["the second a pulse and a gap later", shape[1]["at"], 0.375],
		["the third the same again", shape[2]["at"], 0.75],
		["each as long as the pattern says", shape[2]["seconds"], 0.125],
		["and the whole shape ends when the last pulse does", alarm.length(), 0.875],
		["a pattern that is not there has no shape at all",
			EventForgeHaptics.phases(null).size(), 0]
	])


## One function, so no row can be the one that forgot: every amplitude goes through the dial, 0 turns
## the whole vocabulary off without a branch anywhere in a sheet, and nothing ever leaves 0 to 1.
static func _test_the_players_dial_scales_every_row() -> bool:
	Engine.set_meta(EventForgeHaptics.STRENGTH_META, 1.0)
	var full: float = EventForgeHaptics.scaled(0.8)
	Engine.set_meta(EventForgeHaptics.STRENGTH_META, 0.5)
	var halved: float = EventForgeHaptics.scaled(0.8)
	Engine.set_meta(EventForgeHaptics.STRENGTH_META, 0.0)
	var off: float = EventForgeHaptics.scaled(1.0)
	Engine.set_meta(EventForgeHaptics.STRENGTH_META, 4.0)
	var over: float = EventForgeHaptics.scaled(1.0)
	Engine.remove_meta(EventForgeHaptics.STRENGTH_META)
	return SUPPORT.pins("haptics_words_test", [
		["the dial at one leaves the shape as it was made", full, 0.8],
		["at a half it is half as hard", halved, 0.4],
		["at zero nothing is felt", off, 0.0],
		["a dial past the top still lands on the top", over, 1.0],
		["and with no dial set at all the shape is as it was made",
			EventForgeHaptics.scaled(0.25), 0.25]
	])


## Two things a row can hand over, one answer: the file itself, as a step or a piece of code passes
## it, and the path to it, as a row picked in the editor writes it.
static func _test_a_pattern_is_taken_as_a_file_or_as_a_path() -> bool:
	var made: HapticPatternResource = HapticPatternResource.new()
	made.seconds = 0.25
	var path: String = "user://__haptics_words_test_pattern.tres"
	ResourceSaver.save(made, path)
	var by_path: HapticPatternResource = EventForgeHaptics.pattern_of(path)
	var ok: bool = SUPPORT.pins("haptics_words_test", [
		["the file itself is the pattern", EventForgeHaptics.pattern_of(made) == made, true],
		["and a path to one is read back as the same shape",
			by_path.seconds if by_path != null else -1.0, 0.25],
		["a path to nothing is nothing rather than a guess",
			EventForgeHaptics.pattern_of("res://__no_such_haptic_pattern.tres") == null, true],
		["and neither is an empty box", EventForgeHaptics.pattern_of("") == null, true]
	])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


## The web has nothing to rumble, and the answer is silence rather than a failure. Asked of a NAMED
## platform so the question can be put without being on one.
static func _test_the_web_is_silent() -> bool:
	return SUPPORT.pin_table("haptics_words_test", {
		"Web": true,
		"Windows": false,
		"Android": false,
		"macOS": false
	}, func(os_name: String) -> bool: return EventForgeHaptics.silent_on(os_name))


## Once, on the way to shipping - never a note per row. Two files full of haptic rows are still one
## sentence, because it is one decision about the whole project.
static func _test_the_doctor_says_it_once() -> bool:
	var sources: Dictionary = {
		"res://enemy.gd": "func hurt() -> void:\n\tEventForgeHaptics.play(self, \"res://haptics/hit.tres\")",
		"res://player.gd": "func step() -> void:\n\tEventForgeHaptics.emphasis(1.0)",
		"res://menu.gd": "func open() -> void:\n\tpass"
	}
	var found: Array[Dictionary] = SHIP_IT.haptics_findings(sources)
	var quiet: Array[Dictionary] = SHIP_IT.haptics_findings({"res://menu.gd": "func open() -> void:\n\tpass"})
	return SUPPORT.pins("haptics_words_test", [
		["two files of haptic rows are one note", found.size(), 1],
		["filed as a decision rather than a defect", str(found[0].get("severity", "")), "info"],
		["under its own check", str(found[0].get("check", "")), SHIP_IT.CHECK_HAPTICS],
		["naming the first file that rumbles", str(found[0].get("path", "")), "res://enemy.gd"],
		["and a project that never rumbles hears nothing at all", quiet.size(), 0]
	])


## The dial, exactly as this test found it.
static func _dials_as_found() -> Dictionary:
	var kept: Dictionary = {}
	for named: StringName in _dial_names():
		if Engine.has_meta(named):
			kept[named] = Engine.get_meta(named)
	return kept


## Put back: one this test found is restored, one it created is removed, so the Engine ledger
## balances whatever order a serial run put this test in.
static func _put_the_dials_back(kept: Dictionary) -> void:
	for named: StringName in _dial_names():
		if kept.has(named):
			Engine.set_meta(named, kept[named])
		elif Engine.has_meta(named):
			Engine.remove_meta(named)


static func _dial_names() -> Array[StringName]:
	return [EventForgeHaptics.STRENGTH_META, EventForgeHaptics.UNTIL_META,
		EventForgeHaptics.CONTINUOUS_META]
