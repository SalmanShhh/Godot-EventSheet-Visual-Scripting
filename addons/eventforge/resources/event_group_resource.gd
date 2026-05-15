# EventForge — EventGroupResource resource
# Reusable event group resource that can be inlined into event sheets.
@tool
extends Resource
class_name EventGroupResource

static var _uid_counter: int = 0

@export var name: String = ""
@export var group_name: String = "" # Backwards-compatible alias.
@export var description: String = ""
@export var version: String = "0.1.0"
@export var required_host_class: String = ""
@export var required_providers: Array[String] = []
@export var declared_variables: Dictionary = {}
@export var events: Array[Resource] = []
@export var rows: Array[Resource] = [] # Backwards-compatible alias.
@export var group_uid: String = ""

func _init() -> void:
	if group_uid.is_empty():
		group_uid = _generate_short_uid()

## Generates a short UID with a deterministic fallback counter.
static func _generate_short_uid() -> String:
	var crypto: Crypto = Crypto.new()
	var random_bytes: PackedByteArray = crypto.generate_random_bytes(3)
	if random_bytes.size() == 3:
		return random_bytes.hex_encode()
	_uid_counter += 1
	return "%06x" % _uid_counter
