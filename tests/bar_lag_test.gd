# The bar whose underlay trails the value down after a hit - the one HUD element every game has.
#
# The claim this file holds to account has four parts:
#
#   * THE UNDERLAY WAITS, THEN FOLLOWS. Pinned by value, frame by hand-stepped frame: it stays where
#     it was for the lag seconds, then slides to the value, taking those same seconds to cross the
#     whole bar.
#   * A GAIN HAS NOTHING TO TRAIL, so the underlay lands with a rising bar rather than showing a
#     player the good news twice.
#   * IT WATCHES THE BAR rather than being told, so a value written by any means at all trails the
#     same way - which is why Set Bar keeps its three arguments and its bytes.
#   * IT PARKS, AND THE BAR WAKES IT. A HUD with no lagging bar on it processes nothing at all, and
#     an ARMED lag costs nothing either once its underlay has caught up: the tick stops, and the
#     bar's own value_changed is what turns it back on. Taking the lag away lets go of that watcher.
#
# The whole thing is stepped by hand: the follower takes a delta, so what a frame does is arithmetic
# a test can pin rather than something only a running game can be asked about. The follower is
# handed the bar it is following, because the tick above it is the one that looks a name up - and
# the one that drops a name whose bar has gone, since a book cannot be walked and written at once.
@tool
class_name BarLagTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/hud_kit/hud_kit_behavior.gd"

## The bar this test drives: a hundred wide, a hundred deep, and a lag of half a second. At that lag
## the underlay crosses the whole bar in half a second, which is two hundred a second - so a quarter
## of a second moves it fifty, and every number below is that and not a rounding.
const BAR_NAME: String = "health"
const LAG_SECONDS: float = 0.5
const FRAME: float = 0.25


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_rows_ship() and ok
	ok = _test_the_underlay_waits_then_follows() and ok
	ok = _test_a_gain_has_nothing_to_trail() and ok
	ok = _test_the_underlay_is_drawn_over_the_empty_part() and ok
	ok = _test_a_hud_with_no_lag_parks() and ok
	ok = _test_an_armed_lag_parks_and_the_bar_wakes_it() and ok
	ok = _test_taking_the_lag_away_takes_the_underlay_with_it() and ok
	return ok


## The three rows the pack grew, and the one it did not: Set Bar keeps its three arguments, because
## the underlay watches the bar instead of being told.
static func _test_the_rows_ship() -> bool:
	var source: String = FileAccess.get_file_as_string(PACK)
	var script: GDScript = load(PACK)
	return SUPPORT.pins("bar_lag_test", [
		["the pack loads and parses", script != null, true],
		["arming a lag is an action", source.contains(
			"## @ace_codegen_template(\"$HudKitBehavior.set_bar_lag({bar_name}, {seconds}, {lag_colour})\")"), true],
		["reading the underlay back is an expression", source.contains(
			"## @ace_codegen_template(\"$HudKitBehavior.bar_lag_value({bar_name})\")"), true],
		["and asking whether it is still moving is a condition", source.contains(
			"## @ace_codegen_template(\"$HudKitBehavior.is_bar_lagging({bar_name})\")"), true],
		["Set Bar keeps the three arguments it shipped with", source.contains(
			"func set_bar(bar_name: String, value: float, max_value: float) -> void:"), true]
	])


## Frame by frame: the underlay stays where it was for the whole lag, then slides down at the rate
## that crosses the bar in that same time, and stops the moment it reaches the value.
static func _test_the_underlay_waits_then_follows() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	bar.value = 20.0
	var read_at: Array[float] = []
	var still_behind: Array = []
	for frame: int in 5:
		still_behind.append(kit._follow_bar(BAR_NAME, bar, FRAME))
		read_at.append(kit.bar_lag_value(BAR_NAME))
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["the first frame of the wait leaves the underlay where the bar was", read_at[0], 100.0],
		["and so does the second", read_at[1], 100.0],
		["with the wait spent, it slides at the rate that crosses the bar in the lag",
			read_at[2], 50.0],
		["and lands on the value rather than passing it", read_at[3], 20.0],
		["where it stays", read_at[4], 20.0],
		["so the bar is no longer lagging", kit.is_bar_lagging(BAR_NAME), false],
		["and the follower says, frame by frame, whether it is still behind the bar - which is what the tick above it parks on",
			still_behind, [true, true, true, false, false]]
	])
	hud.free()
	return ok


## A rising bar has nothing to trail: the underlay lands with it rather than showing the good news a
## second time.
static func _test_a_gain_has_nothing_to_trail() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	bar.value = 20.0
	for frame: int in 4:
		kit._follow_bar(BAR_NAME, bar, FRAME)
	bar.value = 80.0
	kit._follow_bar(BAR_NAME, bar, FRAME)
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["a gain takes the underlay with it at once", kit.bar_lag_value(BAR_NAME), 80.0],
		["with nothing left trailing", kit.is_bar_lagging(BAR_NAME), false]
	])
	hud.free()
	return ok


## The underlay covers the stretch between where the bar is now and where it was - which is the EMPTY
## part of the bar, so nothing the bar itself draws is covered up. And it hides the moment the two
## agree, which is what makes an untouched bar look untouched.
static func _test_the_underlay_is_drawn_over_the_empty_part() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	bar.value = 20.0
	for frame: int in 3:
		kit._follow_bar(BAR_NAME, bar, FRAME)
	var underlay: ColorRect = bar.get_node_or_null("__bar_lag") as ColorRect
	var mid: Dictionary = {"x": underlay.position.x, "w": underlay.size.x, "shown": underlay.visible}
	for frame: int in 2:
		kit._follow_bar(BAR_NAME, bar, FRAME)
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["one rectangle is added inside the bar and no more", bar.get_child_count(), 1],
		["it starts where the bar's fill ends", mid["x"], 20.0],
		["and reaches where the value used to be", mid["w"], 30.0],
		["drawn in the colour the row named", underlay.color, Color.RED],
		["as tall as the bar - asked of the bar rather than of a number, because a ProgressBar's own theme decides how deep it is",
			underlay.size.y, bar.size.y],
		["shown while the two differ", mid["shown"], true],
		["and hidden once they agree", underlay.visible, false]
	])
	hud.free()
	return ok


## A HUD with nothing to follow parks its tick the first frame it looks, which is the whole of the
## cost of this feature on a HUD that does not use it.
static func _test_a_hud_with_no_lag_parks() -> bool:
	var hud: Node = _hud()
	var kit: Node = hud.get_child(1)
	kit.set_process(true)
	kit._process(FRAME)
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["a HUD with no lagging bar stops processing the first frame it looks",
			kit.is_processing(), false]
	])
	hud.free()
	return ok


## An ARMED lag parks too, which is the half of the claim a HUD that uses the feature depends on: the
## tick runs while the underlay is behind its bar and stops the frame it catches up, and the BAR is
## what turns it back on - Range says value_changed however the value was set, so a hit landing from
## a sheet, an animation or a tween wakes the same underlay without being routed through this pack.
##
## The waking is driven through the handler the bar's signal is wired to rather than by writing the
## bar. That is not a shortcut around the wiring - the wiring itself is pinned below, by asking the
## bar whether that exact handler is connected to its value_changed - but a Range emits nothing at
## all while it is outside a SceneTree, and this suite has none, so writing the bar would pin a
## silence that says nothing about the code. What the handler is HANDED here is what the signal
## carries in a live tree: the new value, and the name the row armed.
static func _test_an_armed_lag_parks_and_the_bar_wakes_it() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	var armed_ticking: bool = kit.is_processing()
	var wired: bool = bar.value_changed.is_connected(Callable(kit, "_bar_moved").bind(BAR_NAME))
	bar.value = 20.0
	# Four frames is the whole walk at this lag: two of waiting, one at the crossing rate, one that
	# lands - the same four the frame-by-frame pins above read the underlay at.
	for frame: int in 4:
		kit._process(FRAME)
	var caught_up: float = kit.bar_lag_value(BAR_NAME)
	var asleep: bool = not bool((kit.bar_lags[BAR_NAME] as Dictionary)["awake"])
	kit._process(FRAME)
	var parked: bool = kit.is_processing()
	# And the bar's own word wakes it: the record is following again and the tick is back on.
	kit._bar_moved(5.0, BAR_NAME)
	var awake_again: bool = bool((kit.bar_lags[BAR_NAME] as Dictionary)["awake"])
	var ticking_again: bool = kit.is_processing()
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["arming a lag starts the tick", armed_ticking, true],
		["and wires the bar's own value_changed to the handler that wakes it", wired, true],
		["the underlay catches the bar up", caught_up, 20.0],
		["and the record that caught up stops asking for frames", asleep, true],
		["so the frame after it landed, the HUD is processing nothing at all", parked, false],
		["the word the bar sends wakes the record again", awake_again, true],
		["and turns the tick back on with it", ticking_again, true]
	])
	hud.free()
	return ok


## A lag of no seconds is how a lag is taken away: the record goes, and so does the rectangle.
static func _test_taking_the_lag_away_takes_the_underlay_with_it() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	bar.value = 20.0
	kit._follow_bar(BAR_NAME, bar, FRAME)
	var armed: bool = bar.get_node_or_null("__bar_lag") != null
	var watched: bool = bar.value_changed.is_connected(Callable(kit, "_bar_moved").bind(BAR_NAME))
	kit.set_bar_lag(BAR_NAME, 0.0, Color.RED)
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["the underlay was there", armed, true],
		["and the bar was being listened to while the lag was armed", watched, true],
		["a lag of no seconds forgets the bar", kit.is_bar_lagging(BAR_NAME), false],
		["and reading it back answers the bar's own value again",
			kit.bar_lag_value(BAR_NAME), 20.0],
		["taking the lag away lets go of the bar's own word too, so nothing is left listening",
			bar.value_changed.is_connected(Callable(kit, "_bar_moved").bind(BAR_NAME)), false],
		["a bar the kit cannot find is forgotten rather than followed for ever",
			_forgets_a_bar_that_is_gone(), true]
	])
	hud.free()
	return ok


## A HUD root with one bar under it and the kit beside it. Built rather than loaded, because a scene
## file would be one more thing to keep in step with the pack.
static func _hud() -> Node:
	var root: Node = Node.new()
	var bar: ProgressBar = ProgressBar.new()
	bar.name = BAR_NAME
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.size = Vector2(100.0, 12.0)
	root.add_child(bar)
	var kit: Node = (load(PACK) as GDScript).new()
	kit.host = root
	root.add_child(kit)
	return root


## The kit follows a bar by NAME, so a bar that has been taken out of the scene is dropped from the
## book rather than followed for ever. It is the TICK that drops it, not the follower: the follower
## is handed a bar and has none to lose, and the book cannot be written while the tick is walking
## it, so the names that turned out to be gone are collected and erased after the walk.
static func _forgets_a_bar_that_is_gone() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	hud.remove_child(bar)
	bar.free()
	kit.ui_cache.clear()
	kit._process(FRAME)
	var forgotten: bool = not kit.bar_lags.has(BAR_NAME)
	hud.free()
	return forgotten
