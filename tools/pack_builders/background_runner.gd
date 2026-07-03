# Pack builder - background_runner (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Off-thread heavy compute - the "too heavy for one frame even spread out" lane. Run In Background hands a PURE function to the engine's WorkerThreadPool; the
## main thread only polls, so it never hitches, and On Done(result) fires on the main thread (safe to
## touch the scene there). Use it for procedural generation, pathfinding bakes, image/data crunching.
##
## ADVANCED, and the one rule is unenforceable: the work callable MUST be pure - no scene-tree access, no
## Node methods, no non-thread-safe Resource touches, data in / data out only. Touching a node off-thread
## crashes or produces heisenbugs. WorkerThreadPool.add_task discards the callable's return value, so each
## call gets a unique id and the worker stores its result in a Mutex-guarded dictionary for the poll to read.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "BackgroundRunner"
	sheet.addon_tags = PackedStringArray(["performance", "threading"])
	var about: CommentRow = CommentRow.new()
	about.text = "Run In Background: hands a PURE function (no scene-tree access!) to a worker thread; On Done(result) fires on the main thread when it finishes. For heavy compute that would hitch even when spread across frames."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# In-flight tasks as [task_id, call_id]; results keyed by call_id, written off-thread under _mutex.",
		"var _tasks: Array = []",
		"var _results: Dictionary = {}",
		"var _next_id: int = 0",
		"var _mutex: Mutex = null",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Done\")",
		"## @ace_category(\"Background\")",
		"signal done(result: Variant)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Running\")",
		"## @ace_category(\"Background\")",
		"## @ace_codegen_template(\"$BackgroundRunner.is_running()\")",
		"func is_running() -> bool:",
		"\treturn not _tasks.is_empty()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Tasks Running\")",
		"## @ace_category(\"Background\")",
		"func tasks_running() -> int:",
		"\treturn _tasks.size()",
		"",
		"## Runs the (PURE) work callable off the main thread, then stores its result for the poll to emit.",
		"func _run_task(work: Callable, call_id: int) -> void:",
		"\tvar result: Variant = work.call()",
		"\t_mutex.lock()",
		"\t_results[call_id] = result",
		"\t_mutex.unlock()"
	]))
	sheet.events.append(block)
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"_mutex = Mutex.new()"
	]))
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)
	# Per-frame: poll completed tasks and emit On Done on the main thread (safe to touch the scene there).
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if _tasks.is_empty():",
		"\treturn",
		"for __i: int in range(_tasks.size() - 1, -1, -1):",
		"\tvar __entry: Array = _tasks[__i]",
		"\tif WorkerThreadPool.is_task_completed(__entry[0]):",
		"\t\tWorkerThreadPool.wait_for_task_completion(__entry[0])",
		"\t\t_mutex.lock()",
		"\t\tvar __result: Variant = _results.get(__entry[1], null)",
		"\t\t_results.erase(__entry[1])",
		"\t\t_mutex.unlock()",
		"\t\t_tasks.remove_at(__i)",
		"\t\tdone.emit(__result)"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)
	Lib.append_function(sheet, "run_in_background", "Run In Background", "Background",
		"Runs a PURE callable off the main thread; On Done(result) fires when it finishes. WARNING: the callable must NOT touch nodes / the scene tree / non-thread-safe resources - data in, data out only.",
		[["work", "Callable"]], "\n".join(PackedStringArray([
		"if _mutex == null:",
		"\t_mutex = Mutex.new()",
		"var __cid: int = _next_id",
		"_next_id += 1",
		"var __tid: int = WorkerThreadPool.add_task(_run_task.bind(work, __cid))",
		"_tasks.append([__tid, __cid])"
	])))
	Lib.append_function(sheet, "run_batch_in_background", "Run Batch In Background", "Background",
		"Fans an array across worker threads: runs work.bind(item) for each item (On Done fires per item). The callable must be PURE.",
		[["items", "Array"], ["work", "Callable"]], "\n".join(PackedStringArray([
		"for __item: Variant in items:",
		"\trun_in_background(work.bind(__item))"
	])))
	return Lib.save_pack(sheet, "res://eventsheet_addons/background_runner/background_runner_behavior")
