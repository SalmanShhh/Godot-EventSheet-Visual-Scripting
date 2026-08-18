## A hand-written script that exercises every reading lens at once, so the lenses are proved
## against REAL lifted rows rather than against strings a test made up. It carries, on purpose:
## an @onready node reference (M13/M20), an inverted condition (M12), a nested if (M15), a call
## with named arguments (M16), snake_case state and an @export knob (M9), and a property chain
## (M10). It is also the round-trip subject: opening it as a sheet and re-emitting it must
## reproduce this file byte for byte, because every lens here is display-only.
class_name ReadingLensesFixture
extends CharacterBody2D

@onready var hp_bar: ProgressBar = %HpBar

## Grace window in seconds to still take the ground jump just after walking off a ledge.
@export var coyote_time: float = 0.1
@export var wall_jump_enabled: bool = true

var _coyote_timer: float = 0.0
var _jumps_left: int = 0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	if wall_jump_enabled:
		if _coyote_timer > 0.0:
			_jumps_left -= 1
			add_look(velocity.x, velocity.y)
	hp_bar.value = _coyote_timer


func add_look(x: float, y: float) -> void:
	_coyote_timer = x + y
