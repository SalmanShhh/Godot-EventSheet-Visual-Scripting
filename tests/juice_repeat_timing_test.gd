# Godot EventSheets - a repeating juice card starts every pass on time, whatever the frames were doing.
#
# THE ONE THING THIS FILE IS ABOUT: pass k of a card with Repeat and Every starts k * Every after the first
# pass, counted on the card's own clock from the instant the first pass started. A scene tree's own timer is
# credited the whole length of the frame it is made in, so a first play that followed a slow frame (a scene
# that had just loaded) had its second pass arrive early by that much: Every 0.5 gave a gap of 0.37 seconds
# once, then 0.50 for the rest of the game. The player now counts with a Stopwatch, and the counting is one
# function, `tick`, so this file drives it with chosen frame lengths instead of a running tree.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_repeat_timing"

const RUNNER: GDScript = preload("res://eventsheet_addons/juice/moment_runner.gd")
const PLAYER_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"

## A frame of 1/16 second: exact in binary, so no pin below depends on rounding.
const FRAME: float = 0.0625


static func run() -> bool:
	var ok: bool = true
	# 16 frames a second, Every 0.5, three passes: the second and third start at 0.5 and 1.0.
	ok = SUPPORT.check(TEST_NAME, "even frames: passes 2 and 3 start at 0.5 and 1.0", _starts(false, 1.0, [], FRAME, 0.5, 3), [0.5, 1.0]) and ok
	# One long frame (0.3 s) right after the first pass: the clock counts it as the time it was, so pass 2
	# starts at the first frame that reaches 0.5 and pass 3 is still 0.5 later than that ONE start, not later.
	ok = SUPPORT.check(TEST_NAME, "a long first frame: passes at 0.55 and 1.05", _starts(false, 1.0, [0.3], FRAME, 0.5, 3), [0.55, 1.05]) and ok
	# A long frame in the middle moves the pass it falls in; the passes after it keep their own times, each one
	# the same short distance past its k * Every and never further.
	ok = SUPPORT.check(TEST_NAME, "a long middle frame: later passes stay a whole Every apart", _starts(false, 1.0, [FRAME * 4.0, 0.3], FRAME, 0.5, 4), [0.55, 1.05, 1.55]) and ok
	# Slow motion stretches the game clock and leaves the real clock alone.
	ok = SUPPORT.check(TEST_NAME, "game clock at half speed: twice as long", _starts(false, 0.5, [], FRAME, 0.5, 3), [1.0, 2.0]) and ok
	ok = SUPPORT.check(TEST_NAME, "real clock at half speed: unchanged", _starts(true, 0.5, [], FRAME, 0.5, 3), [0.5, 1.0]) and ok
	# A stopped game clock never reaches the pass.
	ok = SUPPORT.check(TEST_NAME, "game clock stopped: no pass starts", _starts(false, 0.0, [], FRAME, 0.5, 3), []) and ok
	# Every 0: the next pass is the next frame, as a zero wait always was.
	ok = SUPPORT.check(TEST_NAME, "Every 0 is a frame apart", _starts(false, 1.0, [], FRAME, 0.0, 3), [FRAME, FRAME * 2.0]) and ok
	# The player counts its passes with the stopwatch it started with the first pass, not a timer per gap.
	var player_text: String = FileAccess.get_file_as_string(PLAYER_PATH)
	ok = SUPPORT.check(TEST_NAME, "the player measures each pass from the first", player_text.contains("await started.until(float(pass_index) * MomentRunner.seconds_of(interval))"), true) and ok
	ok = SUPPORT.check(TEST_NAME, "the player starts that stopwatch before the first pass", player_text.find("MomentRunner.stopwatch(self, clock)") < player_text.find("_do_step(card, at_strength)\n\tawait _repeat_rest"), true) and ok
	return ok


## When each pass after the first starts, in seconds from the first, for a card with `count` passes Every
## `every` seconds. `time_scale` is what the game ran at; `early` is the lengths of the frames that come
## first, and every frame after them is `frame` long. The run gives up after 200 frames.
static func _starts(real: bool, time_scale: float, early: Array, frame: float, every: float, count: int) -> Array:
	var watch: Object = RUNNER.Stopwatch.new(null, real)
	var found: Array = []
	var state: Array = [0.0, 1]
	watch.reached.connect(func() -> void:
		found.append(snappedf(float(state[0]), 0.0001))
		state[1] = int(state[1]) + 1
		if int(state[1]) < count:
			watch.until(float(state[1]) * every))
	if count > 1:
		watch.until(every)
	var lengths: Array = early.duplicate()
	for index: int in range(200):
		lengths.append(frame)
	for length: Variant in lengths:
		state[0] = float(state[0]) + float(length)
		watch.tick(float(length), time_scale)
		if found.size() >= count - 1:
			break
	return found
