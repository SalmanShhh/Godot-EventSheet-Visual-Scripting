class_name BoomerLevelDoor
extends StaticBody3D
## The red keycard door. Try Door on the level's sheet opens it when the key fits and tells it here when it does not.

var door_open: bool = false
var locked_hint: String = ""
## The key this door wants. Try Door reads it off the door itself.
@export var needs_key: String = "red_key"
## How far the door rises out of the way, in metres.
@export var slide_height: float = 3.2
## How long the door takes to open.
@export var slide_seconds: float = 0.6

func locked_door_tried(key: Variant) -> void:
	locked_hint = "Locked. You need the %s keycard." % str(key)

## @ace_hidden
func open_door() -> void:
	if not door_open:
		door_open = true
		var __door_door = self
		__door_door.set_deferred("collision_layer", 0)
		create_tween().tween_property(__door_door, "position", __door_door.position + Vector3(0.0, slide_height, 0.0), slide_seconds)

# Keycard door: it opens when the key fits and says so when it does not.
