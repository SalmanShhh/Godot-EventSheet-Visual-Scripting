extends Area2D

@export var value = 10

var taken = false


func _ready():
	body_entered.connect(func(body): collect(body))


func collect(body):
	if taken:
		return
	taken = true
	if body.has_method("add_coins"):
		body.add_coins(value)
	queue_free()
