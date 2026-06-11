# EventForge — EventGroup resource
# Organisational row that groups related event rows.
@tool
extends Resource
class_name EventGroup

static var _uid_counter: int = 0

@export var enabled: bool = true
@export var name: String = ""
@export var group_name: String = "" # Backwards-compatible alias.
@export var description: String = ""
@export var collapsed: bool = false
@export var expanded: bool = true # Backwards-compatible alias.
@export var color_tag: String = ""
@export var events: Array[Resource] = []
@export var rows: Array[Resource] = [] # Backwards-compatible alias.
@export var group_uid: String = ""
## C3-style group color tag: when alpha > 0 this tints the group's accent bar and
## background instead of the theme tokens (organize big sheets by color).
@export var custom_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## C3-style group-local variables: visually scoped to the group, compiled as class-level
## members under a "# <Group> group locals" header (GDScript has no narrower scope that
## persists across frames).
@export var local_variables: Array[Resource] = []

func _init() -> void:
	if group_uid.is_empty():
		group_uid = _generate_short_uid()

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "group"

## Returns effective collapsed state across collapsed/expanded aliases.
func is_collapsed() -> bool:
	if collapsed:
		return true
	return not expanded

## Sets collapsed state while keeping expanded alias in sync.
func set_collapsed_state(value: bool) -> void:
	collapsed = value
	expanded = not value

## Generates a short UID with a deterministic fallback counter.
static func _generate_short_uid() -> String:
	var crypto: Crypto = Crypto.new()
	var random_bytes: PackedByteArray = crypto.generate_random_bytes(3)
	if random_bytes.size() == 3:
		return random_bytes.hex_encode()
	_uid_counter += 1
	return "%06x" % _uid_counter
