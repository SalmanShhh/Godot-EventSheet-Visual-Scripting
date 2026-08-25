# EventForge - EventGroup resource
# Organisational row that groups related event rows.
@tool
class_name EventGroup
extends Resource

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
## Event-sheet-style group color tag: when alpha > 0 this tints the group's accent bar and
## background instead of the theme tokens (organize big sheets by color).
@export var custom_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Event-sheet-style group-local variables: visually scoped to the group, compiled as class-level
## members under a "# <Group> group locals" header (GDScript has no narrower scope that
## persists across frames).
@export var local_variables: Array[Resource] = []
## The Set Group Active feature, opt-in: compiles a `__group_<name>_active` member and guards
## every contained event with it - feature flags / debug switches / cheap state
## machines at RUNTIME. Off (default) keeps groups zero-cost compile-time organization.
@export var runtime_toggleable: bool = false
## WHO runs this group's events over a network: "" / "everyone" (nobody is left out, and
## nothing at all is emitted), "host", or "owner". The commonest multiplayer mistake is a rule that
## runs on every peer when it should run once, and repeating an Is host condition on every event is
## how that mistake gets made - so the answer is asked once, of the group.
@export var runs_on: String = ""

## The three answers, as the values written into the `## @ace_group(...)` header.
const RUNS_ON_EVERYONE := "everyone"
const RUNS_ON_HOST := "host"
const RUNS_ON_OWNER := "owner"

## The GDScript test each answer compiles to, and the ONE table behind all of it: the compiler's
## guard, the word the head shows, the dialog's dropdown, the menu, and the reading that recognises
## a hand-written guard all resolve here, so none of them can mean something the others do not.
## "everyone" is deliberately absent - it is the answer that writes nothing.
const RUNS_ON_GUARDS: Dictionary = {
	RUNS_ON_HOST: "multiplayer.is_server()",
	RUNS_ON_OWNER: "is_multiplayer_authority()"
}


## The test a runs_on value compiles to, or "" for everyone / a value nothing recognises. Single
## player is untouched either way: `multiplayer.is_server()` is true with no peer connected.
static func runs_on_guard(value: String) -> String:
	return str(RUNS_ON_GUARDS.get(value.strip_edges(), ""))


func _init() -> void:
	if group_uid.is_empty():
		group_uid = _generate_short_uid()


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "group"


## The name this group reads with, across the `name` / `group_name` alias pair. The one answer -
## the editor, the refactors and the compiler all ask here rather than choosing an alias each.
func display_name() -> String:
	if not name.is_empty():
		return name
	if not group_name.is_empty():
		return group_name
	return "Group"


## The rows this group holds, across the `events` / `rows` alias pair.
func child_rows() -> Array[Resource]:
	return events if not events.is_empty() else rows


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
