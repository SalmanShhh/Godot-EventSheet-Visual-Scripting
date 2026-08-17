# Godot EventSheets - Event Bus pack runtime behaviour.
#
# Loads the COMPILED EventBus autoload pack and drives it treeless (signals still emit on a bare
# instance, so the trigger is proved for real): broadcasting a channel with a payload, the On Event
# trigger's captured arguments, the one-shot listener that unsubscribes itself, the per-frame and
# ever-broadcast conditions, the counters, the report, and the save-state round-trip.
#
# Two verbs need a scene tree, which the suite has none of (run_tests.gd works inside
# SceneTree._init, where Engine.get_main_loop() is still null). Both are run against the SHIPPED
# source with two names redirected - `get_tree()` to a stand-in that answers process_frame and
# get_nodes_in_group, and `is_inside_tree()` to a flag - so every other character of the pack runs
# exactly as it ships. What those two names emit is pinned separately, off the file.
@tool
class_name EventBusPackTest
extends RefCounted

const PACK := "res://eventsheet_addons/event_bus/event_bus_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("event bus pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed
	all_passed = _test_annotations() and all_passed
	all_passed = _test_broadcast_and_trigger(script) and all_passed
	all_passed = _test_one_shot(script) and all_passed
	all_passed = _test_wait_timeout(script) and all_passed
	all_passed = _test_wait_success_and_group() and all_passed
	all_passed = _test_wait_forever_never_gives_up() and all_passed
	all_passed = _test_event_log_is_capped_and_printable(script) and all_passed
	all_passed = _test_persistence(script) and all_passed
	return all_passed


## The blurb's other promise about the give-up time: 0 waits FOREVER. A wait that quietly treated 0
## as "already expired" would break every cutscene gate written the way the description describes.
static func _test_wait_forever_never_gives_up() -> bool:
	var all_passed: bool = true
	var script: GDScript = _harness_script()
	if script == null:
		return _check("the stand-in harness parses", false, true)
	var fake_script: GDScript = GDScript.new()
	fake_script.source_code = "extends Node\n\nsignal process_frame\n"
	fake_script.reload()
	var fake: Node = Node.new()
	fake.set_script(fake_script)
	var bus: Node = script.new()
	bus.fake_tree = fake
	bus.in_tree = true

	bus.wait_for("curtain_up", 0.0)
	for _frame: int in 5:
		fake.process_frame.emit()
	all_passed = _check("a give-up time of 0 has not given up after five frames",
		bus.wait_for_event_timed_out("curtain_up"), false) and all_passed
	all_passed = _check("and has not succeeded either - it is simply still waiting",
		bus.wait_for_event_succeeded("curtain_up"), false) and all_passed
	bus.broadcast("curtain_up", {})
	fake.process_frame.emit()
	all_passed = _check("the message it was waiting for still resolves it",
		bus.wait_for_event_succeeded("curtain_up"), true) and all_passed
	bus.free()
	fake.free()
	return all_passed


## The report is a RING: a long session broadcasting all day must not grow the log without bound.
## Print Event Bus Report is a diagnostic, so what is checked is the text it is built from.
static func _test_event_log_is_capped_and_printable(script: GDScript) -> bool:
	var all_passed: bool = true
	var bus: Node = script.new()
	for index: int in 250:
		bus.broadcast("tick", {"n": index})
	var lines: PackedStringArray = str(bus.event_bus_report()).split("\n")
	all_passed = _check("the log stops growing at its cap", lines.size(), 200) and all_passed
	all_passed = _check("and keeps the NEWEST broadcasts, not the oldest",
		str(lines[lines.size() - 1]).contains("\"n\":249"), true) and all_passed
	all_passed = _check("so the oldest ones really did fall off the front",
		str(bus.event_bus_report()).contains("\"n\":0}"), false) and all_passed
	all_passed = _check("every counter still counts every broadcast, capped log or not",
		bus.event_broadcast_count("tick"), 250) and all_passed
	bus.clear_event_log()
	all_passed = _check("Clear Event Log empties the report", str(bus.event_bus_report()), "") and all_passed
	all_passed = _check("but leaves the counters alone", bus.event_broadcast_count("tick"), 250) and all_passed
	bus.free()
	return all_passed


## The published contract, read off the shipped file: the trigger's annotation and payload, and
## the one template that must carry `await` (without it the row would not suspend at all).
static func _test_annotations() -> bool:
	var all_passed: bool = true
	var source: String = FileAccess.get_file_as_string(PACK)
	all_passed = _check("the bus declares ONE signal, with channel and payload",
		source.contains("signal event_raised(channel: String, payload: Dictionary)"), true) and all_passed
	all_passed = _check("that signal is published as a trigger",
		source.contains("## @ace_trigger\n## @ace_name(\"On Event\")"), true) and all_passed
	all_passed = _check("Wait For Event emits an AWAITED call, so the row really suspends",
		source.contains("## @ace_codegen_template(\"await EventBus.wait_for({channel}, {seconds})\")"), true) and all_passed
	all_passed = _check("Broadcast Event emits a plain autoload call",
		source.contains("## @ace_codegen_template(\"EventBus.broadcast({channel}, {payload})\")"), true) and all_passed
	all_passed = _check("Broadcast To Group asks the tree for its members",
		source.contains("deliver_to(get_tree().get_nodes_in_group(group), method_name, payload)"), true) and all_passed
	all_passed = _check("Wait For Event waits a frame at a time so a deadline can interrupt it",
		source.contains("await get_tree().process_frame"), true) and all_passed
	return all_passed


## Broadcast Event, the On Event trigger's captured arguments, and the reading verbs.
static func _test_broadcast_and_trigger(script: GDScript) -> bool:
	var all_passed: bool = true
	var bus: Node = script.new()
	var heard: Array = []
	bus.event_raised.connect(func(channel: String, payload: Dictionary) -> void: heard.append([channel, payload]))

	all_passed = _check("a channel nobody used has never been broadcast", bus.event_was_ever_broadcast("boss_defeated"), false) and all_passed
	all_passed = _check("and its count is zero", bus.event_broadcast_count("boss_defeated"), 0) and all_passed

	bus.broadcast("boss_defeated", {"title": "The Warden", "xp": 500})
	all_passed = _check("the trigger fired once", heard.size(), 1) and all_passed
	all_passed = _check("the row's first captured value is the channel", (heard[0] as Array)[0], "boss_defeated") and all_passed
	all_passed = _check("the payload arrives as the signal's own argument, read by key",
		str(((heard[0] as Array)[1] as Dictionary)["title"]), "The Warden") and all_passed
	all_passed = _check("and the numbers come through untouched",
		int(((heard[0] as Array)[1] as Dictionary)["xp"]), 500) and all_passed
	all_passed = _check("the channel now counts one", bus.event_broadcast_count("boss_defeated"), 1) and all_passed
	all_passed = _check("Event Was Ever Broadcast turns true", bus.event_was_ever_broadcast("boss_defeated"), true) and all_passed
	all_passed = _check("Event Was Broadcast This Frame is true in the same frame",
		bus.event_was_broadcast_this_frame("boss_defeated"), true) and all_passed
	all_passed = _check("but not for a channel that was never sent",
		bus.event_was_broadcast_this_frame("door_opened"), false) and all_passed

	# TWO broadcasts in one frame: the reason the payload is a signal argument rather than a stored
	# last value. Each listener call carries its own record.
	bus.broadcast("boss_defeated", {"title": "The Second", "xp": 10})
	all_passed = _check("a second broadcast fires the trigger again", heard.size(), 2) and all_passed
	all_passed = _check("the FIRST row still reads its own payload",
		str(((heard[0] as Array)[1] as Dictionary)["title"]), "The Warden") and all_passed
	all_passed = _check("and the second reads the second",
		str(((heard[1] as Array)[1] as Dictionary)["title"]), "The Second") and all_passed
	all_passed = _check("the counter reached two", bus.event_broadcast_count("boss_defeated"), 2) and all_passed

	# A bare ping: no details at all is a legitimate broadcast.
	bus.broadcast("ping", {})
	all_passed = _check("a payload-less ping still fires", heard.size(), 3) and all_passed
	all_passed = _check("the report holds a line per broadcast", bus.event_bus_report().split("\n").size(), 3) and all_passed
	all_passed = _check("and names the channel", bus.event_bus_report().contains("ping"), true) and all_passed
	bus.clear_event_log()
	all_passed = _check("clearing empties the report", bus.event_bus_report(), "") and all_passed
	all_passed = _check("but keeps the counters", bus.event_broadcast_count("boss_defeated"), 2) and all_passed
	bus.free()
	return all_passed


## Listen Once For Event: one delivery, then it unsubscribes itself. And the fan-out delivery.
static func _test_one_shot(script: GDScript) -> bool:
	var all_passed: bool = true
	var listener_script: GDScript = GDScript.new()
	listener_script.source_code = "extends Node\n\nvar seen: Array = []\n\nfunc _on_bus_event(channel: String, payload: Dictionary) -> void:\n\tseen.append([channel, payload])\n\nfunc other(payload: Dictionary) -> void:\n\tseen.append(payload)\n"
	all_passed = _check("the listener stand-in parses", listener_script.reload(), OK) and all_passed

	var bus: Node = script.new()
	var listener: Node = listener_script.new()
	bus.listen_once("tutorial_done", listener, "_on_bus_event")
	all_passed = _check("nothing is delivered before the broadcast", (listener.seen as Array).size(), 0) and all_passed
	bus.broadcast("other_channel", {})
	all_passed = _check("a different channel does not wake it", (listener.seen as Array).size(), 0) and all_passed
	bus.broadcast("tutorial_done", {"step": 3})
	all_passed = _check("the one-shot listener heard it", (listener.seen as Array).size(), 1) and all_passed
	all_passed = _check("with the channel as its first argument", str(((listener.seen as Array)[0] as Array)[0]), "tutorial_done") and all_passed
	all_passed = _check("and the payload as its second", int((((listener.seen as Array)[0] as Array)[1] as Dictionary)["step"]), 3) and all_passed
	bus.broadcast("tutorial_done", {"step": 4})
	all_passed = _check("it unsubscribed itself, so a second broadcast is silent", (listener.seen as Array).size(), 1) and all_passed

	# A listener that has been freed is skipped rather than crashing the broadcast.
	var doomed: Node = listener_script.new()
	bus.listen_once("gone", doomed, "_on_bus_event")
	doomed.free()
	bus.broadcast("gone", {})
	all_passed = _check("a freed one-shot listener is skipped, not crashed into", bus.event_broadcast_count("gone"), 1) and all_passed

	# The fan-out half: only members that answer to the method are called.
	var answering: Node = listener_script.new()
	var deaf: Node = Node.new()
	bus.deliver_to([answering, deaf], "other", {"amount": 7})
	all_passed = _check("a group member that has the method is called", (answering.seen as Array).size(), 1) and all_passed
	all_passed = _check("with the payload handed over", int(((answering.seen as Array)[0] as Dictionary)["amount"]), 7) and all_passed
	all_passed = _check("and one that does not is skipped silently", is_instance_valid(deaf), true) and all_passed

	listener.free()
	answering.free()
	deaf.free()
	bus.free()
	return all_passed


## Wait For Event's give-up path, on the shipped instance: a deadline already past returns without
## ever reaching the tree, so this half needs no stand-in at all.
static func _test_wait_timeout(script: GDScript) -> bool:
	var all_passed: bool = true
	var bus: Node = script.new()
	all_passed = _check("before any wait, neither outcome is claimed", bus.wait_for_event_succeeded("door_opened"), false) and all_passed
	all_passed = _check("and timed-out is false too, not a phantom failure", bus.wait_for_event_timed_out("door_opened"), false) and all_passed
	bus.wait_for("door_opened", 0.0001)
	all_passed = _check("a deadline that has already passed gives up", bus.wait_for_event_timed_out("door_opened"), true) and all_passed
	all_passed = _check("so the success branch stays shut", bus.wait_for_event_succeeded("door_opened"), false) and all_passed
	all_passed = _check("and another channel is unaffected", bus.wait_for_event_timed_out("other"), false) and all_passed
	bus.free()
	return all_passed


## The two verbs that need a tree, run against the shipped source with get_tree() / is_inside_tree()
## redirected at the stand-in described in the file header.
static func _test_wait_success_and_group() -> bool:
	var all_passed: bool = true
	var script: GDScript = _harness_script()
	all_passed = _check("the stand-in harness parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var fake_script: GDScript = GDScript.new()
	fake_script.source_code = "extends Node\n\nsignal process_frame\n\nvar members: Array = []\n\nfunc get_nodes_in_group(group: String) -> Array:\n\treturn members\n"
	all_passed = _check("the tree stand-in parses", fake_script.reload(), OK) and all_passed
	var fake: Node = Node.new()
	fake.set_script(fake_script)

	var bus: Node = script.new()
	bus.fake_tree = fake
	bus.in_tree = true

	# The success path: the wait suspends, the broadcast lands, the next frame resumes it.
	bus.wait_for("door_opened", 8.0)
	all_passed = _check("the wait has not resolved yet", bus.wait_for_event_succeeded("door_opened"), false) and all_passed
	# The half a two-state outcome got wrong: a wait still IN FLIGHT is not a wait that gave up, and
	# a row asking Wait For Event Timed Out mid-wait used to run the recovery branch on the spot.
	all_passed = _check("and a wait still running has not timed out either", bus.wait_for_event_timed_out("door_opened"), false) and all_passed
	bus.broadcast("door_opened", {"who": "lever"})
	fake.process_frame.emit()
	all_passed = _check("once the message lands, the wait succeeded", bus.wait_for_event_succeeded("door_opened"), true) and all_passed
	all_passed = _check("and it did NOT read as a timeout", bus.wait_for_event_timed_out("door_opened"), false) and all_passed

	# The group fan-out, through the real Broadcast To Group entry point.
	var member_script: GDScript = GDScript.new()
	member_script.source_code = "extends Node\n\nvar got: Array = []\n\nfunc on_bus_event(payload: Dictionary) -> void:\n\tgot.append(payload)\n"
	member_script.reload()
	var member: Node = member_script.new()
	fake.members = [member, Node.new()]
	bus.broadcast_to_group("listeners", "on_bus_event", {"level": 2})
	all_passed = _check("every capable group member is called", (member.got as Array).size(), 1) and all_passed
	all_passed = _check("with the payload", int(((member.got as Array)[0] as Dictionary)["level"]), 2) and all_passed

	# And with no tree at all the same row is a quiet no-op rather than a crash.
	bus.in_tree = false
	bus.broadcast_to_group("listeners", "on_bus_event", {"level": 3})
	all_passed = _check("outside the tree the fan-out does nothing", (member.got as Array).size(), 1) and all_passed

	(fake.members as Array)[1].free()
	member.free()
	bus.free()
	fake.free()
	return all_passed


## Save state carries the counters; the live listeners and per-frame stamps belong to the run.
static func _test_persistence(script: GDScript) -> bool:
	var all_passed: bool = true
	var bus: Node = script.new()
	bus.broadcast("boss_defeated", {})
	bus.broadcast("boss_defeated", {})
	bus.broadcast("door_opened", {})
	var state: Dictionary = bus.save_state()
	var restored: Node = script.new()
	restored.load_state(state)
	all_passed = _check("counts survive a save round-trip", restored.event_broadcast_count("boss_defeated"), 2) and all_passed
	all_passed = _check("for every channel", restored.event_broadcast_count("door_opened"), 1) and all_passed
	all_passed = _check("Event Was Ever Broadcast reads true on the restored bus",
		restored.event_was_ever_broadcast("boss_defeated"), true) and all_passed
	all_passed = _check("but this-frame stamps do not travel",
		restored.event_was_broadcast_this_frame("boss_defeated"), false) and all_passed
	all_passed = _check("an empty state changes nothing", _load_empty(restored), 2) and all_passed
	bus.free()
	restored.free()
	return all_passed


static func _load_empty(bus: Node) -> int:
	bus.load_state({})
	return int(bus.event_broadcast_count("boss_defeated"))


## The shipped pack source with its class_name and icon dropped (an in-memory script cannot claim a
## global class name that is already registered) and the two tree names redirected at stand-ins.
static func _harness_script() -> GDScript:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(PACK).split("\n"):
		if line.begins_with("class_name ") or line.begins_with("@icon("):
			continue
		kept.append(line)
	var text: String = "\n".join(kept).replace("get_tree()", "_tree()").replace("is_inside_tree()", "_in_tree()")
	text += "\n\nvar fake_tree: Object = null\nvar in_tree: bool = false\n\nfunc _tree() -> Object:\n\treturn fake_tree\n\nfunc _in_tree() -> bool:\n\treturn in_tree\n"
	var script: GDScript = GDScript.new()
	script.source_code = text
	return script if script.reload() == OK else null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_bus_pack_test: %s" % label)
		return true
	print("[FAIL] event_bus_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
