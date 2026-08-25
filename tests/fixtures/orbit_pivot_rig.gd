@tool
extends Node3D

# Fixture - the two shapes the orbit reading has to tell apart, in ONE file placed in ONE scene.
#
# `pivot` is a node whose only child in `orbit_pivot_rig.tscn` is a camera arm, so turning it is the
# camera going round what it looks at: the reading says Orbit around its centre. `plain` holds a
# mesh, so turning it is a turn, and the reading says nothing extra. Nothing here runs - the facts
# walk reads the .tscn beside it as text, and the test asks the grammar about these two lines.

@onready var pivot: Node3D = $CameraPivot
@onready var plain: Node3D = $Crate


func turn(relative: Vector2) -> void:
	pivot.rotate_y(-relative.x * 0.005)
	plain.rotate_y(-relative.x * 0.005)
