## @ace_tags(performance, scheduling)
## @ace_category("Time Slicer")
@icon("res://eventsheet_addons/behavior.svg")
class_name TimeSlicerBehavior
extends Node

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

var _last_count: int = 0
var _paused: bool = false
var _queue: Array = []
## Max milliseconds per frame spent draining the queue (used when Mode includes ms).
@export_range(0.1, 16, 0.1) var frame_budget_ms: float = 4.0
## Hard cap on items processed per frame (used when Mode includes count).
@export var max_items_per_frame: int = 64
@export_enum("both", "ms", "count") var mode: String = "both"

func _process(delta: float) -> void:
	if _paused or _queue.is_empty():
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

## @ace_action
## @ace_name("Enqueue Item")
## @ace_category("Time Slicer")
## @ace_description("Adds one item to the work queue (processed later within the per-frame budget).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.enqueue_item({item})")
func enqueue_item(item) -> void:
	_queue.append(item)

## @ace_action
## @ace_name("Enqueue Items")
## @ace_category("Time Slicer")
## @ace_description("Adds every element of an array to the work queue.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.enqueue_items({items})")
func enqueue_items(items: Array) -> void:
	_queue.append_array(items)

## @ace_action
## @ace_name("Enqueue Group")
## @ace_category("Time Slicer")
## @ace_description("Adds every node in a group to the work queue (e.g. process all enemies, spread over frames).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.enqueue_group({group})")
func enqueue_group(group: String) -> void:
	_queue.append_array(get_tree().get_nodes_in_group(group))

## @ace_action
## @ace_name("Clear Queue")
## @ace_category("Time Slicer")
## @ace_description("Drops all pending items without processing them.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.clear_queue()")
func clear_queue() -> void:
	_queue.clear()

## @ace_action
## @ace_name("Set Frame Budget")
## @ace_category("Time Slicer")
## @ace_description("Sets the per-frame millisecond budget at runtime (dial it down during heavy scenes).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.set_frame_budget({ms})")
func set_frame_budget(ms: float) -> void:
	frame_budget_ms = maxf(0.0, ms)

## @ace_action
## @ace_name("Pause")
## @ace_category("Time Slicer")
## @ace_description("Stops draining (items stay queued).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.pause_slicer()")
func pause_slicer() -> void:
	_paused = true

## @ace_action
## @ace_name("Resume")
## @ace_category("Time Slicer")
## @ace_description("Resumes draining the queue.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.resume_slicer()")
func resume_slicer() -> void:
	_paused = false

## @ace_condition
## @ace_name("Is Busy")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.is_busy()")
func is_busy() -> bool:
	return not _queue.is_empty()

## @ace_expression
## @ace_name("Items Remaining")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.items_remaining()")
func items_remaining() -> int:
	return _queue.size()

## @ace_expression
## @ace_name("Last Frame Item Count")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$TimeSlicerBehavior.last_frame_item_count()")
func last_frame_item_count() -> int:
	return _last_count

# Time Slicer: a managed work queue that drains within a per-frame ms / count budget. Enqueue items, react to On Process Item(item) - heavy work self-spreads across frames with no loop, no await, no hitch.
