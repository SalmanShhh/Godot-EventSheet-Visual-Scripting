extends Node2D


func make_crate_part_of_level() -> void:
	$Level/Crate.owner = $Level


func copy_the_crate() -> void:
	add_child($Level/Crate.duplicate())
	add_child($Level/Crate.duplicate(Node.DUPLICATE_SIGNALS * int(false) | Node.DUPLICATE_GROUPS * int(true) | Node.DUPLICATE_SCRIPTS * int(true)))


func move_the_crate() -> void:
	reparent($Level)
	reparent($Player/Hand, false)
