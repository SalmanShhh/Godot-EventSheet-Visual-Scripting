## The HUD object of the scene fixture. It carries one function with a named parameter (so a bound
## value reads as "count = 3") and one handler the scene file itself wires, on a CHILD node - the
## wiring a script on a child never used to be able to see.
class_name OpenedSceneHud
extends CanvasLayer

var wave: int = 0


func show_wave(count: int) -> void:
	wave = count


func _on_wave_timer_timeout() -> void:
	wave += 1
