extends CanvasLayer

const BRIEF: String = """MISSION BRIEF
objective: %s
time left: %s
"""

const DEBRIEF: String = """MISSION OVER
result: %s
time taken: %s
"""

@onready var screen: Label = $Screen
@onready var toast: Label = $Toast
@onready var clock: Label = $Clock

var seconds_left: int = 120


func _ready() -> void:
	toast.hide()
	screen.hide()
	clock.show()


func _process(delta: float) -> void:
	seconds_left -= int(delta)
	clock.text = str(seconds_left)


func brief(objective: String) -> void:
	screen.text = BRIEF % [objective, str(seconds_left)]
	screen.show()
	toast.hide()


func debrief(result: String) -> void:
	screen.text = DEBRIEF % [result, str(120 - seconds_left)]
	screen.show()
	clock.hide()


func dismiss() -> void:
	screen.hide()
	toast.hide()
	clock.show()
