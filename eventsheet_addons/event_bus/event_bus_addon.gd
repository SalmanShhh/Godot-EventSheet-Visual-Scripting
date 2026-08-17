## @ace_tags(events, messaging, decoupling)
## @ace_category("Events")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/event_bus/icon.svg")
class_name EventBusPackAddon
extends Node
## A game-wide message board addressed by name as the EventBus autoload singleton: Broadcast Event sends a named channel with a record of details, and every sheet that cares answers with the On Event trigger, reading the channel and the payload straight off the row. Wait For Event suspends an event until a message arrives or a give-up time passes, and its outcome reads back as the Wait For Event Succeeded / Wait For Event Timed Out conditions.

## @ace_trigger
## @ace_name("On Event")
## @ace_category("Events")
signal event_raised(channel: String, payload: Dictionary)

# channel -> the frame number (Engine.get_process_frames) of its most recent broadcast.
var _frames: Dictionary = {}
# channel -> how many times it has been broadcast this run. Wait For Event watches this
# counter rather than the signal, so a give-up time can interrupt the wait.
var _counts: Dictionary = {}
# channel -> how the most recent Wait For Event on it ended: 0 (or missing) = one is still
# waiting, 1 = the message arrived, 2 = it gave up. THREE states, not a bool: a wait that is
# still in flight has not timed out, and a bool would have to answer one of the two anyway.
var _wait_outcomes: Dictionary = {}
# channel -> Array of {node, method}: one-shot listeners, run once and then dropped.
var _once_listeners: Dictionary = {}
# "channel  payload" lines for the report, newest last, capped so a long session cannot grow
# without bound.
var _log: Array[String] = []
const _LOG_LIMIT: int = 200

## @ace_action
## @ace_name("Wait For Event")
## @ace_category("Events")
## @ace_description("Suspends this event until the named message is broadcast, or until the give-up time passes. The rows below it run when it resolves, so read what happened with the Wait For Event Succeeded / Wait For Event Timed Out conditions. A give-up time of 0 waits forever.")
## @ace_display_template("Wait for event [b]{channel}[/b], give up after [b]{seconds}[/b]s")
## @ace_param(channel, hint: expression, desc: "The message to wait for. Any sheet anywhere can be the one that broadcasts it.")
## @ace_param(seconds, desc: "Give up after this long. 0 waits forever - only safe under a one-shot trigger.")
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("await EventBus.wait_for({channel}, {seconds})")
func wait_for(channel: String = "door_opened", seconds: float = 8.0) -> void:
	# Watching the counter rather than awaiting the signal is what lets the give-up time
	# interrupt the wait: GDScript cannot await two signals and take whichever lands first.
	var seen: int = int(_counts.get(channel, 0))
	var deadline: int = Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)
	_wait_outcomes[channel] = 0
	while int(_counts.get(channel, 0)) == seen:
		if seconds > 0.0 and Time.get_ticks_msec() >= deadline:
			_wait_outcomes[channel] = 2
			return
		await get_tree().process_frame
	_wait_outcomes[channel] = 1

## @ace_action
## @ace_featured
## @ace_name("Broadcast Event")
## @ace_category("Events")
## @ace_description("Sends a named message to everyone listening, with a record of details. Anyone anywhere can answer it with On Event - the listener needs no reference to you, and you need none to it. The details arrive on the listener's row as the payload record, read by key.")
## @ace_display_template("Broadcast event [b]{channel}[/b] with [b]{payload}[/b]")
## @ace_param_hint(channel expression)
## @ace_param_hint(payload expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.broadcast({channel}, {payload})")
func broadcast(channel: String = "boss_defeated", payload: Dictionary = {}) -> void:
	_frames[channel] = Engine.get_process_frames()
	_counts[channel] = int(_counts.get(channel, 0)) + 1
	if _log.size() >= _LOG_LIMIT:
		_log.remove_at(0)
	_log.append("%s  %s" % [channel, JSON.stringify(payload)])
	event_raised.emit(channel, payload)
	_run_once_listeners(channel, payload)

## @ace_action
## @ace_name("Listen Once For Event")
## @ace_category("Events")
## @ace_description("Asks for ONE delivery of a channel and then unsubscribes itself, so a tutorial gate or a one-time hint can never fire twice and can never leak. When the message arrives the named method is called on the node you picked, with the channel and the payload as its two arguments.")
## @ace_display_template("Listen once for [b]{channel}[/b], then call [b]{method_name}[/b] on [i]{on_node}[/i]")
## @ace_param_hint(channel expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.listen_once({channel}, {on_node}, {method_name})")
func listen_once(channel: String = "tutorial_done", on_node: Node = null, method_name: String = "_on_bus_event") -> void:
	if on_node == null or method_name.is_empty():
		push_warning("EventBus: Listen Once For Event needs a node and a method name.")
		return
	var waiting: Array = _once_listeners.get(channel, [])
	waiting.append({"node": on_node, "method": method_name})
	_once_listeners[channel] = waiting

## @ace_action
## @ace_name("Broadcast To Group")
## @ace_category("Events")
## @ace_description("Calls a named method on every member of a group that actually has it, handing over the payload record. The fan-out half of the bus: use it when the answer belongs to a family of nodes rather than to a sheet, and nothing breaks when a member does not implement the method.")
## @ace_display_template("Broadcast to group [b]{group}[/b] by calling [b]{method_name}[/b] with [b]{payload}[/b]")
## @ace_param_hint(group group_reference)
## @ace_param_hint(payload expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.broadcast_to_group({group}, {method_name}, {payload})")
func broadcast_to_group(group: String = "listeners", method_name: String = "on_bus_event", payload: Dictionary = {}) -> void:
	if not is_inside_tree():
		return
	deliver_to(get_tree().get_nodes_in_group(group), method_name, payload)

## @ace_action
## @ace_name("Clear Event Log")
## @ace_category("Events")
## @ace_description("Empties the record of what has been broadcast this session. The counters that Event Broadcast Count reads are kept, so only the report text is affected.")
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.clear_event_log()")
func clear_event_log() -> void:
	_log.clear()

## @ace_action
## @ace_name("Print Event Bus Report")
## @ace_category("Events")
## @ace_description("Prints every broadcast recorded this session to the output, newest last, one channel and payload per line. A diagnostic: reach for it while you are hunting a missing listener, not in shipping rows.")
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.print_event_bus_report()")
func print_event_bus_report() -> void:
	print("Event Bus: %d broadcast(s)\n%s" % [_log.size(), "\n".join(_log)])

## @ace_condition
## @ace_name("Wait For Event Succeeded")
## @ace_category("Events")
## @ace_description("Whether the most recent Wait For Event on this channel ended because the message arrived. Put it on the rows under the wait - it is a state check on the wait that just finished, not a trigger. A wait still in flight is neither succeeded nor timed out.")
## @ace_param_hint(channel expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.wait_for_event_succeeded({channel})")
func wait_for_event_succeeded(channel: String = "door_opened") -> bool:
	return int(_wait_outcomes.get(channel, 0)) == 1

## @ace_condition
## @ace_name("Wait For Event Timed Out")
## @ace_category("Events")
## @ace_description("Whether the most recent Wait For Event on this channel gave up without the message arriving. The recovery branch: say something else, open a different door, skip the beat. It stays false while a wait is still running, so it can only mean give-up.")
## @ace_param_hint(channel expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.wait_for_event_timed_out({channel})")
func wait_for_event_timed_out(channel: String = "door_opened") -> bool:
	return int(_wait_outcomes.get(channel, 0)) == 2

## @ace_condition
## @ace_name("Event Was Broadcast This Frame")
## @ace_category("Events")
## @ace_description("Whether this channel was broadcast during the frame being processed right now. The polled read for a per-frame event; where you can, answer with the On Event trigger instead - it costs nothing and cannot miss.")
## @ace_param_hint(channel expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.event_was_broadcast_this_frame({channel})")
func event_was_broadcast_this_frame(channel: String = "boss_defeated") -> bool:
	return int(_frames.get(channel, -1)) == Engine.get_process_frames()

## @ace_condition
## @ace_name("Event Was Ever Broadcast")
## @ace_category("Events")
## @ace_description("Whether this channel has been broadcast at least once since the game started. Useful for a gate that must stay open once something has happened, e.g. "the boss has been defeated at some point".")
## @ace_param_hint(channel expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.event_was_ever_broadcast({channel})")
func event_was_ever_broadcast(channel: String = "boss_defeated") -> bool:
	return int(_counts.get(channel, 0)) > 0

## @ace_expression
## @ace_name("Event Broadcast Count")
## @ace_category("Events")
## @ace_description("How many times this channel has been broadcast since the game started. 0 for a channel nobody has used.")
## @ace_param_hint(channel expression)
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.event_broadcast_count({channel})")
func event_broadcast_count(channel: String = "boss_defeated") -> int:
	return int(_counts.get(channel, 0))

## @ace_expression
## @ace_name("Event Bus Report")
## @ace_category("Events")
## @ace_description("Everything broadcast this session as text, one "channel  payload" line each, newest last. Drop it into a debug label while you are hunting a listener that never fired.")
## @ace_icon("res://eventsheet_addons/event_bus/icon.svg")
## @ace_codegen_template("EventBus.event_bus_report()")
func event_bus_report() -> String:
	return "\n".join(_log)

func _run_once_listeners(channel: String, payload: Dictionary) -> void:
	# Runs and clears every one-shot listener waiting on a channel. Called from broadcast AFTER the
	# signal, so an ordinary On Event row and a one-shot row see the same broadcast in a stable order.
	var waiting: Array = _once_listeners.get(channel, [])
	if waiting.is_empty():
		return
	_once_listeners.erase(channel)
	for entry: Variant in waiting:
		if not (entry is Dictionary):
			continue
		# Deliberately untyped: a listener that has been freed since it subscribed cannot be
		# assigned to a typed Node var at all, and skipping it is the whole point of the guard.
		var listener: Variant = (entry as Dictionary).get("node", null)
		var method_name: String = str((entry as Dictionary).get("method", ""))
		if is_instance_valid(listener) and (listener as Node).has_method(method_name):
			(listener as Node).call(method_name, channel, payload)

## @ace_hidden
func deliver_to(members: Array, method_name: String, payload: Dictionary) -> void:
	# The delivery half of Broadcast To Group, split from the group lookup so the same fan-out runs
	# over any list of nodes - which is also how it is exercised without a live scene tree.
	for member: Variant in members:
		if member is Node and (member as Node).has_method(method_name):
			(member as Node).call(method_name, payload)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted by
	# Save/Load Node State) and duck-types these two methods. Plain data only - the live
	# listeners and the per-frame stamps belong to this run and are deliberately left out.
	return {"counts": _counts.duplicate(true)}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_counts = (state.get("counts", {}) as Dictionary).duplicate(true)

# Event Bus: register as the EventBus autoload. Broadcast Event sends a named channel with a payload record; On Event is the trigger every listener uses, and its channel and payload arrive as row values. Wait For Event is the awaitable form for cutscenes and tutorial gates. This pack is an event sheet - extend it by editing it.
