# Run by custom_monitors_test.gd in a process of its own: the tree and the engine's monitor table
# are real here, which run_tests.gd cannot give a test. It loads the script the test compiled from a
# Show In Monitors row (argument after `--`), puts nodes made from it in the tree, and prints one
# `monitors_probe checks=N fails=M` line plus a `monitors_probe_fail` line for each failed check.
extends SceneTree

const NAME: String = "Game/Score"

var _checks: int = 0
var _fails: int = 0


func _initialize() -> void:
	# A node added during startup is not yet in a tree that is running; wait for the first frame.
	await process_frame
	var script: GDScript = load(OS.get_cmdline_user_args()[0]) as GDScript
	if script == null:
		print("monitors_probe_fail the script did not load")
		quit(1)
		return
	var first: Node = script.new()
	root.add_child(first)
	_check("the graph is added when the node is ready", Performance.has_custom_monitor(NAME), true)
	_check("it reads the number as it stands", Performance.get_custom_monitor(NAME), 3)
	first.set("score", 9)
	_check("it reads the number again at each look, not once", Performance.get_custom_monitor(NAME), 9)

	first._ready()
	_check("running the row again replaces the graph with no error", Performance.get_custom_monitor(NAME), 9)

	var second: Node = script.new()
	second.set("score", 40)
	root.add_child(second)
	_check("a second node showing the same name replaces the first, with no error",
		Performance.get_custom_monitor(NAME), 40)

	first.free()
	_check("a node leaving takes its graph with it", Performance.has_custom_monitor(NAME), false)
	_check("and it is not left in the engine's list", Performance.get_custom_monitor_names().has(NAME), false)

	var third: Node = script.new()
	root.add_child(third)
	third.queue_free()
	await process_frame
	await process_frame
	_check("a node freed at the end of the frame takes its graph too", Performance.has_custom_monitor(NAME), false)

	var fourth: Node = script.new()
	root.add_child(fourth)
	root.remove_child(fourth)
	_check("a node taken out of the tree takes its graph", Performance.has_custom_monitor(NAME), false)
	fourth.free()

	var fifth: Node = script.new()
	root.add_child(fifth)
	Performance.remove_custom_monitor(NAME)
	fifth.free()
	_check("a graph taken away by hand does not make the node's leaving an error",
		Performance.has_custom_monitor(NAME), false)

	print("monitors_probe checks=%d fails=%d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	_checks += 1
	if actual != expected:
		_fails += 1
		print("monitors_probe_fail %s: expected %s, got %s" % [label, str(expected), str(actual)])
