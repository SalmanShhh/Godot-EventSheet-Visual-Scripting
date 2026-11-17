# Godot EventSheets - a held Alt+Down on a very large Drawing Prefab keeps up.
#
# At 200 shapes a step used to take most of a second: every card was drawn again and the picture was drawn on the
# main thread, twice. A step now draws the cards that moved and only asks for a picture. This holds the main
# thread's share of a step to a budget, and to a fraction of what drawing the whole list costs in the same process
# (the ratio is what stays true on a slow or busy machine).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STEPS_PROPERTY_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
const P := "card_reorder_perf_test"
## This test MEASURES, so it has to have the machine to itself: the sharded runner keeps it out of every parallel shard.
const PARALLEL_UNSAFE := true
## The most one step may take on the main thread at 200 shapes, in milliseconds.
const STEP_BUDGET_MS: float = 100.0
const SHAPES: int = 200
const STEPS: int = 20


static func _steps(count: int) -> Array:
	var kinds: Array = ["circle", "ring", "rect", "line", "cone", "arc", "pie"]
	var steps: Array = []
	for index: int in count:
		steps.append({"kind": kinds[index % kinds.size()], "x": float(index), "y": 0.0, "p1": 5.0 + float(index % 9), "p2": 3.0, "p3": 2.0, "color": "#ff8800"})
	return steps


static func _median(values: Array) -> float:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


static func run() -> bool:
	var editor_class: GDScript = (load(STEPS_PROPERTY_PATH) as GDScript).get_script_constant_map().get("ShapeStepsEditor") as GDScript
	var drawer: EventSheetCardListDrawer = editor_class.new() as EventSheetCardListDrawer
	drawer.set_value(_steps(SHAPES))
	var whole: Array = []
	for round: int in 3:
		var started: int = Time.get_ticks_usec()
		drawer.set_value(drawer.get_value())
		whole.append(float(Time.get_ticks_usec() - started) / 1000.0)
	drawer.select_card(0)
	var steps: Array = []
	for step: int in STEPS:
		var begun: int = Time.get_ticks_usec()
		drawer.move_selected(1)
		steps.append(float(Time.get_ticks_usec() - begun) / 1000.0)
	var add_times: Array = []
	for round: int in 5:
		var begun: int = Time.get_ticks_usec()
		drawer.add_card("circle")
		add_times.append(float(Time.get_ticks_usec() - begun) / 1000.0)
	var step_ms: float = _median(steps)
	var whole_ms: float = _median(whole)
	print("  [perf] %d shapes: one step %.2f ms, a whole redraw %.2f ms, an add %.2f ms" % [SHAPES, step_ms, whole_ms, _median(add_times)])
	var ok: bool = SUPPORT.pins(P, [
		["a step at 200 shapes stays inside its budget on the main thread", step_ms < STEP_BUDGET_MS, true],
		["and costs under a tenth of drawing the whole list", step_ms < whole_ms * 0.1, true],
		["an add costs under a tenth of drawing the whole list too", _median(add_times) < whole_ms * 0.1, true],
		["the card went where it was walked to", (drawer.get_value() as Array)[STEPS]["x"], 0.0],
	])
	drawer.free()
	return ok
