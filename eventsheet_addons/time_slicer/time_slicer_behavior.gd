## @ace_tags(performance, scheduling)
## @ace_category("Time Slicer")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/time_slicer/icon.svg")
class_name TimeSlicerBehavior
extends Node
## A managed work queue that spreads heavy work across frames: enqueue items in one event and the slicer drains them a slice at a time, firing On Process Item for each until the per-frame budget runs out. Spawning 500 enemies or carving a dungeon no longer freezes the frame.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("TimeSlicerBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Process Item")
signal process_item(item: Variant)
## @ace_trigger
## @ace_name("On Drained")
signal drained

## Max milliseconds per frame spent draining the queue (used when Mode includes ms).
@export_range(0.1, 16, 0.1) var frame_budget_ms: float = 4.0
## Hard cap on items processed per frame (used when Mode includes count).
@export var max_items_per_frame: int = 64
## Which per-frame budget stops the drain - both the ms fence and the item cap, ms only, or count only.
@export_enum("both", "ms", "count") var mode: String = "both"
var _queue: Array = []
var _last_count: int = 0
var _paused: bool = false

func _ready() -> void:
	set_process(not _queue.is_empty())

func _process(delta: float) -> void:
	if _paused or _queue.is_empty():
		set_process(false)
		return
	# Wall-clock ms fence - the one budget primitive shared across the frame-spreading tools.
	var __budget_end := Time.get_ticks_usec() + int(frame_budget_ms * 1000.0)
	var __n := 0
	while not _queue.is_empty():
		process_item.emit(_queue.pop_front())
		__n += 1
		if mode != "count" and Time.get_ticks_usec() >= __budget_end:
			break
		if mode != "ms" and __n >= max_items_per_frame:
			break
	_last_count = __n
	if _queue.is_empty():
		drained.emit()
	# An empty queue is real idleness - a slicer with nothing to drain should cost nothing per
	# frame. Recomputed after On Drained, because a handler is free to enqueue the next batch
	# from inside it; every enqueue verb turns processing back on the same way.
	set_process(not _queue.is_empty() and not _paused)

## @ace_action
## @ace_name("Enqueue Item")
## @ace_category("Time Slicer")
## @ace_description("Adds one item to the work queue (processed later within the per-frame budget).")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.enqueue_item({item})")
func enqueue_item(item: Variant) -> void:
	_queue.append(item)
	# Work to do means frames to do it in - unless the slicer is paused, which is the one
	# state that keeps items queued on purpose.
	set_process(not _paused)

## @ace_action
## @ace_featured
## @ace_name("Enqueue Items")
## @ace_category("Time Slicer")
## @ace_description("Adds every element of an array to the work queue.")
## @ace_display_template("Enqueue [b]{items}[/b]")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.enqueue_items({items})")
func enqueue_items(items: Array) -> void:
	_queue.append_array(items)
	set_process(not _paused)

## @ace_action
## @ace_name("Enqueue Group")
## @ace_category("Time Slicer")
## @ace_description("Adds every node in a group to the work queue (e.g. process all enemies, spread over frames).")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.enqueue_group({group})")
func enqueue_group(group: String) -> void:
	_queue.append_array(get_tree().get_nodes_in_group(group))
	set_process(not _paused)

## @ace_action
## @ace_name("Clear Queue")
## @ace_category("Time Slicer")
## @ace_description("Drops all pending items without processing them.")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.clear_queue()")
func clear_queue() -> void:
	_queue.clear()
	# Nothing left to drain, so nothing left to spend a frame on.
	set_process(false)

## @ace_action
## @ace_featured
## @ace_name("Set Frame Budget")
## @ace_category("Time Slicer")
## @ace_description("Sets the per-frame millisecond budget at runtime (dial it down during heavy scenes).")
## @ace_display_template("Set frame budget to [b]{ms}[/b] ms")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.set_frame_budget({ms})")
func set_frame_budget(ms: float) -> void:
	frame_budget_ms = maxf(0.0, ms)

## @ace_action
## @ace_name("Pause")
## @ace_category("Time Slicer")
## @ace_description("Stops draining (items stay queued).")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.pause_slicer()")
func pause_slicer() -> void:
	_paused = true
	# A paused slicer is not waiting on anything - it holds its items and does no work, so it
	# should not be charged a frame for holding them.
	set_process(false)

## @ace_action
## @ace_name("Resume")
## @ace_category("Time Slicer")
## @ace_description("Resumes draining the queue.")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.resume_slicer()")
func resume_slicer() -> void:
	_paused = false
	set_process(not _queue.is_empty())

## @ace_condition
## @ace_name("Is Busy")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.is_busy()")
func is_busy() -> bool:
	return not _queue.is_empty()

## @ace_expression
## @ace_name("Items Remaining")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.items_remaining()")
func items_remaining() -> int:
	return _queue.size()

## @ace_expression
## @ace_name("Last Frame Item Count")
## @ace_icon("res://eventsheet_addons/time_slicer/icon.svg")
## @ace_codegen_template("$TimeSlicerBehavior.last_frame_item_count()")
func last_frame_item_count() -> int:
	return _last_count

# Time Slicer: a managed work queue that drains within a per-frame ms / count budget. Enqueue items, react to On Process Item(item) - heavy work self-spreads across frames with no loop, no await, no hitch.
