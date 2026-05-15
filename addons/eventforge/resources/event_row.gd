# EventForge — EventRow resource
@tool
extends Resource
class_name EventRow

enum ElseMode {
NONE,
ELSE,
ELIF
}

static var _uid_counter: int = 0

@export var enabled: bool = true
@export var trigger_provider_id: String = ""
@export var trigger_id: String = ""
@export var trigger_params: Dictionary = {}
@export var conditions: Array[ACECondition] = []
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

## Generates a short deterministic-ish UID with fallback.
static func _generate_short_uid() -> String:
var crypto: Crypto = Crypto.new()
var random_bytes: PackedByteArray = PackedByteArray()
if crypto != null:
random_bytes = crypto.generate_random_bytes(3)
if random_bytes.size() == 3:
return random_bytes.hex_encode()
_uid_counter += 1
return "%06x" % _uid_counter
