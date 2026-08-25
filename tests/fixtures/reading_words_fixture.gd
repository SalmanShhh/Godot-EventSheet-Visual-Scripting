@tool
class_name ReadingWordsFixture
extends CharacterBody2D

# A hand-written script carrying one of every shape the event-sheet words claim, so the
# render harness can show what an ordinary game script reads like. Never run: it exists to be OPENED.

var lives: int = 3
var label: String = ""
var inventory: Dictionary = {}
var items: Array = []
var speed: float = 100.0
var attacker: Node = null

## @ace_trigger
## @ace_name("On Damaged")
signal damaged(amount: int, source: Node)


func _ready() -> void:
	position.x = 100
	label = str(lives) + " lives"
	label = "Score: %d" % lives
	lives = inventory["potion"]
	lives = items[0]
	lives = randi_range(1, 6)
	speed = rad_to_deg(rotation)
	speed = snapped(speed, 0.5)
	lives = items.size()
	print("ready")
	get_tree().call_group("enemies", "flee")
	create_tween().tween_property(self, "position", velocity, 0.3)
	damaged.emit(3, attacker)


func _physics_process(delta: float) -> void:
	velocity.x = speed * delta
	for i in range(3):
		lives += i
		break
	for i in range(2, 8):
		continue
	while lives > 0:
		lives -= 1
	for child in get_children():
		child.queue_free()


func _process(_delta: float) -> void:
	await get_tree().process_frame
