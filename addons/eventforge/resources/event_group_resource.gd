# EventForge — EventGroupResource resource
@tool
extends Resource
class_name EventGroupResource

static var _uid_counter: int = 0

@export var group_uid: String = ""
@export var group_name: String = ""
@export var rows: Array[Resource] = []

func _init() -> void:
if group_uid.is_empty():
group_uid = _generate_short_uid()

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
