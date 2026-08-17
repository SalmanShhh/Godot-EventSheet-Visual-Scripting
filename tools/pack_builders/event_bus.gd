# Pack builder - event_bus (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

const PACK_ICON := "res://eventsheet_addons/event_bus/icon.svg"


## Event Bus: a game-wide message board addressed by NAME as an AUTOLOAD sheet (EventBus). One row
## broadcasts a channel with a record of details; any sheet anywhere answers it with the On Event
## trigger and reads the details straight off the row, because the trigger IS a Godot signal and its
## arguments are the row's captured context.
##  - A channel exists without an owner, so a listener can subscribe before the broadcaster spawns
##    and stay subscribed after it is freed. That is the case group signals cannot serve.
##  - Wait For Event suspends the calling event until the message arrives or the give-up time passes,
##    and the outcome reads back as ordinary conditions (Wait For Event Succeeded / Timed Out) rather
##    than as a variable the handler must remember to check.
##  - Listen Once For Event unsubscribes itself the moment it fires, the CONNECT_ONE_SHOT idea as a
##    row; Broadcast To Group is the has_method fan-out for a family of nodes.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "EventBus"
	sheet.host_class = "Node"
	sheet.custom_class_name = "EventBusPackAddon"
	sheet.class_description = "A game-wide message board addressed by name as the EventBus autoload singleton: Broadcast Event sends a named channel with a record of details, and every sheet that cares answers with the On Event trigger, reading the channel and the payload straight off the row. Wait For Event suspends an event until a message arrives or a give-up time passes, and its outcome reads back as the Wait For Event Succeeded / Wait For Event Timed Out conditions."
	sheet.addon_category = "Events"
	sheet.addon_tags = PackedStringArray(["events", "messaging", "decoupling"])
	var about: CommentRow = CommentRow.new()
	about.text = "Event Bus: register as the EventBus autoload. Broadcast Event sends a named channel with a payload record; On Event is the trigger every listener uses, and its channel and payload arrive as row values. Wait For Event is the awaitable form for cutscenes and tutorial gates. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# ONE signal for the whole bus: the channel and the payload are its arguments, so a listener row
	# reads them directly instead of fetching a stored last-value that two broadcasts in one frame
	# would have already overwritten.
	var raised_signal: SignalRow = SignalRow.new()
	raised_signal.signal_name = "event_raised"
	raised_signal.params = PackedStringArray(["channel: String", "payload: Dictionary"])
	raised_signal.trigger = true
	raised_signal.ace_name = "On Event"
	raised_signal.ace_category = "Events"
	sheet.events.append(raised_signal)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# channel -> the frame number (Engine.get_process_frames) of its most recent broadcast.",
		"var _frames: Dictionary = {}",
		"# channel -> how many times it has been broadcast this run. Wait For Event watches this",
		"# counter rather than the signal, so a give-up time can interrupt the wait.",
		"var _counts: Dictionary = {}",
		"# channel -> how the most recent Wait For Event on it ended: 0 (or missing) = one is still",
		"# waiting, 1 = the message arrived, 2 = it gave up. THREE states, not a bool: a wait that is",
		"# still in flight has not timed out, and a bool would have to answer one of the two anyway.",
		"var _wait_outcomes: Dictionary = {}",
		"# channel -> Array of {node, method}: one-shot listeners, run once and then dropped.",
		"var _once_listeners: Dictionary = {}",
		"# \"channel  payload\" lines for the report, newest last, capped so a long session cannot grow",
		"# without bound.",
		"var _log: Array[String] = []",
		"const _LOG_LIMIT: int = 200",
		"",
		"# Runs and clears every one-shot listener waiting on a channel. Called from broadcast AFTER the",
		"# signal, so an ordinary On Event row and a one-shot row see the same broadcast in a stable order.",
		"func _run_once_listeners(channel: String, payload: Dictionary) -> void:",
		"\tvar waiting: Array = _once_listeners.get(channel, [])",
		"\tif waiting.is_empty():",
		"\t\treturn",
		"\t_once_listeners.erase(channel)",
		"\tfor entry: Variant in waiting:",
		"\t\tif not (entry is Dictionary):",
		"\t\t\tcontinue",
		"\t\t# Deliberately untyped: a listener that has been freed since it subscribed cannot be",
		"\t\t# assigned to a typed Node var at all, and skipping it is the whole point of the guard.",
		"\t\tvar listener: Variant = (entry as Dictionary).get(\"node\", null)",
		"\t\tvar method_name: String = str((entry as Dictionary).get(\"method\", \"\"))",
		"\t\tif is_instance_valid(listener) and (listener as Node).has_method(method_name):",
		"\t\t\t(listener as Node).call(method_name, channel, payload)",
		"",
		"# The delivery half of Broadcast To Group, split from the group lookup so the same fan-out runs",
		"# over any list of nodes - which is also how it is exercised without a live scene tree.",
		"## @ace_hidden",
		"func deliver_to(members: Array, method_name: String, payload: Dictionary) -> void:",
		"\tfor member: Variant in members:",
		"\t\tif member is Node and (member as Node).has_method(method_name):",
		"\t\t\t(member as Node).call(method_name, payload)"
	]))
	sheet.events.append(block)

	# --- Sending ---
	Lib.append_function(sheet, "broadcast", "Broadcast Event", "Events", "Sends a named message to everyone listening, with a record of details. Anyone anywhere can answer it with On Event - the listener needs no reference to you, and you need none to it. The details arrive on the listener's row as the payload record, read by key.",
		[["channel", "String"], ["payload", "Dictionary"]],
		"\n".join(PackedStringArray([
			"_frames[channel] = Engine.get_process_frames()",
			"_counts[channel] = int(_counts.get(channel, 0)) + 1",
			"if _log.size() >= _LOG_LIMIT:",
			"\t_log.remove_at(0)",
			"_log.append(\"%s  %s\" % [channel, JSON.stringify(payload)])",
			"event_raised.emit(channel, payload)",
			"_run_once_listeners(channel, payload)"
		])))
	Lib.append_function(sheet, "listen_once", "Listen Once For Event", "Events", "Asks for ONE delivery of a channel and then unsubscribes itself, so a tutorial gate or a one-time hint can never fire twice and can never leak. When the message arrives the named method is called on the node you picked, with the channel and the payload as its two arguments.",
		[["channel", "String"], ["on_node", "Node"], ["method_name", "String"]],
		"\n".join(PackedStringArray([
			"if on_node == null or method_name.is_empty():",
			"\tpush_warning(\"EventBus: Listen Once For Event needs a node and a method name.\")",
			"\treturn",
			"var waiting: Array = _once_listeners.get(channel, [])",
			"waiting.append({\"node\": on_node, \"method\": method_name})",
			"_once_listeners[channel] = waiting"
		])))
	Lib.append_function(sheet, "broadcast_to_group", "Broadcast To Group", "Events", "Calls a named method on every member of a group that actually has it, handing over the payload record. The fan-out half of the bus: use it when the answer belongs to a family of nodes rather than to a sheet, and nothing breaks when a member does not implement the method.",
		[["group", "String"], ["method_name", "String"], ["payload", "Dictionary"]],
		"\n".join(PackedStringArray([
			"if not is_inside_tree():",
			"\treturn",
			"deliver_to(get_tree().get_nodes_in_group(group), method_name, payload)"
		])))
	Lib.append_function(sheet, "clear_event_log", "Clear Event Log", "Events", "Empties the record of what has been broadcast this session. The counters that Event Broadcast Count reads are kept, so only the report text is affected.",
		[],
		"_log.clear()")
	Lib.append_function(sheet, "print_event_bus_report", "Print Event Bus Report", "Events", "Prints every broadcast recorded this session to the output, newest last, one channel and payload per line. A diagnostic: reach for it while you are hunting a missing listener, not in shipping rows.",
		[],
		"print(\"Event Bus: %d broadcast(s)\\n%s\" % [_log.size(), \"\\n\".join(_log)])")

	# The awaitable is the one verb that needs a hand-written template: it must suspend the CALLING
	# event rather than this node, and only `await` in the emitted line does that. An exposed sheet
	# function regenerates its own template (without the await), so this one is authored as a
	# verbatim annotated block. The full `@ace_param` form is what keeps it verbatim: the importer
	# refuses to lift an annotation block it cannot fully re-emit, which is exactly the guarantee
	# this verb needs.
	var waiter: RawCodeRow = RawCodeRow.new()
	waiter.code = "\n".join(PackedStringArray([
		"## @ace_action",
		"## @ace_name(\"Wait For Event\")",
		"## @ace_category(\"Events\")",
		"## @ace_description(\"Suspends this event until the named message is broadcast, or until the give-up time passes. The rows below it run when it resolves, so read what happened with the Wait For Event Succeeded / Wait For Event Timed Out conditions. A give-up time of 0 waits forever.\")",
		"## @ace_display_template(\"Wait for event [b]{channel}[/b], give up after [b]{seconds}[/b]s\")",
		"## @ace_param(channel, hint: expression, desc: \"The message to wait for. Any sheet anywhere can be the one that broadcasts it.\")",
		"## @ace_param(seconds, desc: \"Give up after this long. 0 waits forever - only safe under a one-shot trigger.\")",
		"## @ace_icon(\"" + PACK_ICON + "\")",
		"## @ace_codegen_template(\"await EventBus.wait_for({channel}, {seconds})\")",
		"func wait_for(channel: String = \"door_opened\", seconds: float = 8.0) -> void:",
		"\t# Watching the counter rather than awaiting the signal is what lets the give-up time",
		"\t# interrupt the wait: GDScript cannot await two signals and take whichever lands first.",
		"\tvar seen: int = int(_counts.get(channel, 0))",
		"\tvar deadline: int = Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)",
		"\t_wait_outcomes[channel] = 0",
		"\twhile int(_counts.get(channel, 0)) == seen:",
		"\t\tif seconds > 0.0 and Time.get_ticks_msec() >= deadline:",
		"\t\t\t_wait_outcomes[channel] = 2",
		"\t\t\treturn",
		"\t\tawait get_tree().process_frame",
		"\t_wait_outcomes[channel] = 1"
	]))
	sheet.events.append(waiter)

	# --- Conditions ---
	Lib.condition(sheet, "wait_for_event_succeeded", "Wait For Event Succeeded", "Events", "Whether the most recent Wait For Event on this channel ended because the message arrived. Put it on the rows under the wait - it is a state check on the wait that just finished, not a trigger. A wait still in flight is neither succeeded nor timed out.", [["channel", "String"]],
		"return int(_wait_outcomes.get(channel, 0)) == 1")
	Lib.condition(sheet, "wait_for_event_timed_out", "Wait For Event Timed Out", "Events", "Whether the most recent Wait For Event on this channel gave up without the message arriving. The recovery branch: say something else, open a different door, skip the beat. It stays false while a wait is still running, so it can only mean give-up.", [["channel", "String"]],
		"return int(_wait_outcomes.get(channel, 0)) == 2")
	Lib.condition(sheet, "event_was_broadcast_this_frame", "Event Was Broadcast This Frame", "Events", "Whether this channel was broadcast during the frame being processed right now. The polled read for a per-frame event; where you can, answer with the On Event trigger instead - it costs nothing and cannot miss.", [["channel", "String"]],
		"return int(_frames.get(channel, -1)) == Engine.get_process_frames()")
	Lib.condition(sheet, "event_was_ever_broadcast", "Event Was Ever Broadcast", "Events", "Whether this channel has been broadcast at least once since the game started. Useful for a gate that must stay open once something has happened, e.g. \"the boss has been defeated at some point\".", [["channel", "String"]],
		"return int(_counts.get(channel, 0)) > 0")

	# --- Expressions ---
	Lib.number(sheet, "event_broadcast_count", "Event Broadcast Count", "Events", "How many times this channel has been broadcast since the game started. 0 for a channel nobody has used.", [["channel", "String"]],
		"return int(_counts.get(channel, 0))", TYPE_INT)
	Lib.number(sheet, "event_bus_report", "Event Bus Report", "Events", "Everything broadcast this session as text, one \"channel  payload\" line each, newest last. Drop it into a debug label while you are hunting a listener that never fired.", [],
		"return \"\\n\".join(_log)", TYPE_STRING)

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted by",
		"# Save/Load Node State) and duck-types these two methods. Plain data only - the live",
		"# listeners and the per-frame stamps belong to this run and are deliberately left out.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {\"counts\": _counts.duplicate(true)}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_counts = (state.get(\"counts\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	Lib.verb_sentences(sheet, {
		"broadcast": "Broadcast event [b]{channel}[/b] with [b]{payload}[/b]",
		"listen_once": "Listen once for [b]{channel}[/b], then call [b]{method_name}[/b] on [i]{on_node}[/i]",
		"broadcast_to_group": "Broadcast to group [b]{group}[/b] by calling [b]{method_name}[/b] with [b]{payload}[/b]",
	})
	Lib.feature_verbs(sheet, ["broadcast"])
	_set_defaults(sheet, "broadcast", {"channel": "\"boss_defeated\"", "payload": "{}"}, {"channel": "expression", "payload": "expression"})
	_set_defaults(sheet, "listen_once", {"channel": "\"tutorial_done\"", "on_node": "null", "method_name": "\"_on_bus_event\""}, {"channel": "expression"})
	_set_defaults(sheet, "broadcast_to_group", {"group": "\"listeners\"", "method_name": "\"on_bus_event\"", "payload": "{}"}, {"group": "group_reference", "payload": "expression"})
	_set_defaults(sheet, "wait_for_event_succeeded", {"channel": "\"door_opened\""}, {"channel": "expression"})
	_set_defaults(sheet, "wait_for_event_timed_out", {"channel": "\"door_opened\""}, {"channel": "expression"})
	_set_defaults(sheet, "event_was_broadcast_this_frame", {"channel": "\"boss_defeated\""}, {"channel": "expression"})
	_set_defaults(sheet, "event_was_ever_broadcast", {"channel": "\"boss_defeated\""}, {"channel": "expression"})
	_set_defaults(sheet, "event_broadcast_count", {"channel": "\"boss_defeated\""}, {"channel": "expression"})
	return Lib.save_pack(sheet, "res://eventsheet_addons/event_bus/event_bus_addon", PACK_ICON)


## Gives an exposed verb's parameters GDScript defaults (which become the row's pre-filled cells,
## since the emitted pack carries no separate picker default) and optional widget hints.
static func _set_defaults(sheet: EventSheetResource, function_name: String, defaults: Dictionary, hints: Dictionary = {}) -> void:
	for function_resource: Resource in sheet.functions:
		if not (function_resource is EventFunction) or (function_resource as EventFunction).function_name != function_name:
			continue
		for parameter: ACEParam in (function_resource as EventFunction).params:
			if defaults.has(parameter.id):
				parameter.gdscript_default = str(defaults[parameter.id])
			if hints.has(parameter.id):
				parameter.hint = str(hints[parameter.id])
		return
	push_warning("_set_defaults: no function named %s on this sheet (typo?)" % function_name)
