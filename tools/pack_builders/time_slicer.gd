# Pack builder — time_slicer (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Frame-spreading made easy (Solution 1, see docs/PERFORMANCE.md — the beginner path): a
## managed work queue that drains within a per-frame TIME or COUNT budget. Enqueue items in one event,
## react to On Process Item(item) in another — like reacting to a signal. Heavy work that would hitch
## if done all at once (spawning 500 objects, updating 10k entities) self-spreads across as many frames
## as the budget needs, with no loop and no await. Attach as a child component, or register it as an
## autoload for one global slicer. Uses the shared budget primitive: a Time.get_ticks_usec() ms fence.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "TimeSlicerBehavior"
	sheet.addon_tags = PackedStringArray(["performance", "scheduling"])
	sheet.variables = {
		"frame_budget_ms": {"type": "float", "default": 4.0, "exported": true,
			"attributes": {"tooltip": "Max milliseconds per frame spent draining the queue (used when Mode includes ms).", "range": {"min": "0.1", "max": "16", "step": "0.1"}}},
		"max_items_per_frame": {"type": "int", "default": 64, "exported": true,
			"attributes": {"tooltip": "Hard cap on items processed per frame (used when Mode includes count)."}},
		"mode": {"type": "String", "default": "both", "exported": true, "options": ["both", "ms", "count"]},
		"_queue": {"type": "Array", "default": [], "exported": false},
		"_last_count": {"type": "int", "default": 0, "exported": false},
		"_paused": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Time Slicer: a managed work queue that drains within a per-frame ms / count budget. Enqueue items, react to On Process Item(item) — heavy work self-spreads across frames with no loop, no await, no hitch."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Process Item\")",
		"## @ace_category(\"Time Slicer\")",
		"signal process_item(item: Variant)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Drained\")",
		"## @ace_category(\"Time Slicer\")",
		"signal drained",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Busy\")",
		"## @ace_category(\"Time Slicer\")",
		"## @ace_codegen_template(\"$TimeSlicerBehavior.is_busy()\")",
		"func is_busy() -> bool:",
		"\treturn not _queue.is_empty()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Items Remaining\")",
		"## @ace_category(\"Time Slicer\")",
		"func items_remaining() -> int:",
		"\treturn _queue.size()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Last Frame Item Count\")",
		"## @ace_category(\"Time Slicer\")",
		"func last_frame_item_count() -> int:",
		"\treturn _last_count"
	]))
	sheet.events.append(block)
	# Per-frame: drain the queue within the budget, emitting On Process Item per item, On Drained at empty.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if _paused or _queue.is_empty():",
		"\treturn",
		"# Wall-clock ms fence — the one budget primitive shared across the frame-spreading tools.",
		"var __budget_end := Time.get_ticks_usec() + int(frame_budget_ms * 1000.0)",
		"var __n := 0",
		"while not _queue.is_empty():",
		"\tprocess_item.emit(_queue.pop_front())",
		"\t__n += 1",
		"\tif mode != \"count\" and Time.get_ticks_usec() >= __budget_end:",
		"\t\tbreak",
		"\tif mode != \"ms\" and __n >= max_items_per_frame:",
		"\t\tbreak",
		"_last_count = __n",
		"if _queue.is_empty():",
		"\tdrained.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)
	Lib.append_function(sheet, "enqueue_item", "Enqueue Item", "Time Slicer", "Adds one item to the work queue (processed later within the per-frame budget).",
		[["item", "Variant"]],
		"_queue.append(item)")
	Lib.append_function(sheet, "enqueue_items", "Enqueue Items", "Time Slicer", "Adds every element of an array to the work queue.",
		[["items", "Array"]],
		"_queue.append_array(items)")
	Lib.append_function(sheet, "enqueue_group", "Enqueue Group", "Time Slicer", "Adds every node in a group to the work queue (e.g. process all enemies, spread over frames).",
		[["group", "String"]],
		"_queue.append_array(get_tree().get_nodes_in_group(group))")
	Lib.append_function(sheet, "clear_queue", "Clear Queue", "Time Slicer", "Drops all pending items without processing them.",
		[],
		"_queue.clear()")
	Lib.append_function(sheet, "set_frame_budget", "Set Frame Budget", "Time Slicer", "Sets the per-frame millisecond budget at runtime (dial it down during heavy scenes).",
		[["ms", "float"]],
		"frame_budget_ms = maxf(0.0, ms)")
	Lib.append_function(sheet, "pause_slicer", "Pause", "Time Slicer", "Stops draining (items stay queued).",
		[],
		"_paused = true")
	Lib.append_function(sheet, "resume_slicer", "Resume", "Time Slicer", "Resumes draining the queue.",
		[],
		"_paused = false")
	return Lib.save_pack(sheet, "res://eventsheet_addons/time_slicer/time_slicer_behavior")
