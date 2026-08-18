@tool
class_name ReadingWords4Fixture
extends CharacterBody2D

# A hand-written script carrying one of every shape batch four's reading claims - type and membership
# questions, the text and math expression names, saving / files / JSON, the behaviour words a body, a
# camera and an emitter read in, the input phases, and the debug verbs. Never run: it exists to be
# OPENED, so the render harness can show what an ordinary game script reads like.

var hp: int = 10
var label: String = ""
var inventory: Dictionary = {}
var wave: Array = []
var config: ConfigFile = ConfigFile.new()
var log_file: FileAccess = null
var other: Node = null

@onready var ball: RigidBody2D = $Ball
@onready var lens: Camera2D = $Lens
@onready var sparks: GPUParticles2D = $Sparks


func _ready() -> void:
	label = label.to_upper()
	label = label.to_lower()
	label = label.substr(0, 3)
	label = label.substr(2, 4)
	label = label.right(4)
	hp = label.length()
	hp = label.find("x")
	label = label.replace("a", "b")
	label = label.strip_edges()
	label = "{0}: {1}".format([hp, label])
	hp = pow(hp, 2)
	wave = label.split(",")
	config.set_value("save", "score", hp)
	hp = config.get_value("save", "score", 0)
	config.save("user://save.cfg")
	config.load("user://save.cfg")
	log_file = FileAccess.open("user://logs/log.txt", FileAccess.WRITE)
	log_file.store_string(label)
	label = log_file.get_as_text()
	label = JSON.stringify(inventory)
	inventory = JSON.parse_string(label)
	push_error("no target")
	push_warning(label)
	printerr(label)
	print_rich(label)
	assert(hp >= 0, "hp went negative")
	breakpoint


func _physics_process(_delta: float) -> void:
	ball.apply_impulse(velocity)
	ball.apply_force(velocity)
	ball.linear_velocity = velocity
	ball.angular_velocity = 2.0
	lens.zoom = Vector2(2, 2)
	lens.make_current()
	sparks.emitting = true
	sparks.restart()
	set_collision_mask_value(2, true)
	set_collision_layer_value(3, false)
	collision_layer = 0
	hp = Input.get_axis("left", "right")
	hp = Input.get_action_strength("gas")


func _process(_delta: float) -> void:
	if other is Node2D:
		hp += 1
	if "potion" in inventory:
		hp += 1
	if hp in [1, 2, 3]:
		hp += 1
	if hp in wave:
		hp += 1
	if other.has_method("take_damage"):
		hp += 1
	if has_node("Ball"):
		hp += 1
	if label.begins_with("a"):
		hp += 1
	if label.contains("b"):
		hp += 1
	if hp >= 10:
		hp = 0
	if config.has_section_key("save", "score"):
		hp = 0
	if FileAccess.file_exists("user://logs/log.txt"):
		hp = 0
	if Input.is_action_just_released("jump"):
		hp = 0
	if Input.is_key_pressed(KEY_X):
		hp = 0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		hp = 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		hp = 0
	if event.is_action_released("pause"):
		hp = 1
