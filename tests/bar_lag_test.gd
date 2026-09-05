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
#   * IT PARKS. A HUD with no lagging bar on it processes nothing at all.
#
# The whole thing is stepped by hand: the follower takes a delta, so what a frame does is arithmetic
# a test can pin rather than something only a running game can be asked about.
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
	for frame: int in 5:
		kit._follow_bar(BAR_NAME, FRAME)
		read_at.append(kit.bar_lag_value(BAR_NAME))
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["the first frame of the wait leaves the underlay where the bar was", read_at[0], 100.0],
		["and so does the second", read_at[1], 100.0],
		["with the wait spent, it slides at the rate that crosses the bar in the lag",
			read_at[2], 50.0],
		["and lands on the value rather than passing it", read_at[3], 20.0],
		["where it stays", read_at[4], 20.0],
		["so the bar is no longer lagging", kit.is_bar_lagging(BAR_NAME), false]
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
		kit._follow_bar(BAR_NAME, FRAME)
	bar.value = 80.0
	kit._follow_bar(BAR_NAME, FRAME)
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
		kit._follow_bar(BAR_NAME, FRAME)
	var underlay: ColorRect = bar.get_node_or_null("__bar_lag") as ColorRect
	var mid: Dictionary = {"x": underlay.position.x, "w": underlay.size.x, "shown": underlay.visible}
	for frame: int in 2:
		kit._follow_bar(BAR_NAME, FRAME)
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


## A lag of no seconds is how a lag is taken away: the record goes, and so does the rectangle.
static func _test_taking_the_lag_away_takes_the_underlay_with_it() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	bar.value = 20.0
	kit._follow_bar(BAR_NAME, FRAME)
	var armed: bool = bar.get_node_or_null("__bar_lag") != null
	kit.set_bar_lag(BAR_NAME, 0.0, Color.RED)
	var ok: bool = SUPPORT.pins("bar_lag_test", [
		["the underlay was there", armed, true],
		["a lag of no seconds forgets the bar", kit.is_bar_lagging(BAR_NAME), false],
		["and reading it back answers the bar's own value again",
			kit.bar_lag_value(BAR_NAME), 20.0],
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
## book rather than followed for ever.
static func _forgets_a_bar_that_is_gone() -> bool:
	var hud: Node = _hud()
	var bar: ProgressBar = hud.find_child(BAR_NAME, true, false) as ProgressBar
	var kit: Node = hud.get_child(1)
	kit.set_bar_lag(BAR_NAME, LAG_SECONDS, Color.RED)
	hud.remove_child(bar)
	bar.free()
	kit.ui_cache.clear()
	kit._follow_bar(BAR_NAME, FRAME)
	var forgotten: bool = not kit.bar_lags.has(BAR_NAME)
	hud.free()
	return forgotten
