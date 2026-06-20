# EventForge — EventRow resource
# Serializable event row with trigger, conditions, actions, and child rows.
@tool
extends Resource
class_name EventRow

enum ElseMode {
	NONE,
	ELSE,
	ELIF
}

enum ConditionMode {
	AND,
	OR
}

static var _uid_counter: int = 0

@export var enabled: bool = true
## Real breakpoints: when the sheet's emit_breakpoints toggle is on, this event's body
## starts with a `breakpoint` statement (pausing the Godot debugger).
@export var debug_break: bool = false
## Optional conditional-breakpoint guard: when non-empty, the breakpoint fires only when this
## GDScript boolean expression is true (compiled as `if <cond>: breakpoint`) — break on the
## frame that matters instead of every pass.
@export var debug_break_condition: String = ""
@export var comment: String = ""
@export var trigger_provider_id: String = ""
@export var trigger_id: String = ""
@export var trigger_params: Dictionary = {}
## For signal-backed triggers: the node whose signal fires this event, relative to the
## generated script's owner ("" = self). Lets sheets react to OTHER nodes' signals (child
## behaviors, timers…) — the compiler emits the `_ready` connection.
@export var trigger_source_path: String = ""
## Baked argument signature for custom signal triggers (e.g. "amount: int"), captured from
## the ACE definition at apply time so the compiler can generate a connectable handler
## without registry access (mirrors codegen_template baking on conditions/actions).
@export var trigger_args: String = ""
@export var trigger: ACECondition = null
@export var conditions: Array[ACECondition] = []
@export var condition_mode: int = ConditionMode.AND
@export var actions: Array[Resource] = []
@export var sub_events: Array[Resource] = []
@export var else_mode: ElseMode = ElseMode.NONE
@export var event_uid: String = ""
@export var local_variables: Array[LocalVariable] = []
@export var pick_filters: Array[PickFilter] = []

func _init() -> void:
	if event_uid.is_empty():
		event_uid = _generate_short_uid()

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "event"

## Generates a short UID with a deterministic fallback counter.
static func _generate_short_uid() -> String:
	var crypto: Crypto = Crypto.new()
	var random_bytes: PackedByteArray = crypto.generate_random_bytes(3)
	if random_bytes.size() == 3:
		return random_bytes.hex_encode()
	_uid_counter += 1
	return "%06x" % _uid_counter
