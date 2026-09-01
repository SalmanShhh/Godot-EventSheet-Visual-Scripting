# Saving what the player built, written the way people actually type it: a local for the branch, the
# owner walk that makes the children part of the file at all, a PackedScene, and the write. The
# recogniser is measured against what is written rather than against what the compiler emits.
#
# `save_the_level` is the plain hand-written tail - pack it, save it, let the engine's console say so
# if either refuses. `save_the_ship` is the same tail with both failures answered. `save_the_room` is
# what the row itself writes today: the walk BORROWS the ownership it needs and hands it back once
# the pack is done, which is what makes saving a branch inside a branch you already saved write a
# whole file instead of a truncated one.
#
# `pack_it_only` is the BOUNDARY, and it is here on purpose: the same pack and the same write with NO
# walk in front of them is a different program - it saves a scene holding one node, reports OK twice,
# and loads back empty - so it is left as the code it is.
extends Node


func save_the_level() -> void:
	var branch := $Level
	for part: Node in branch.find_children("*", "", true, false):
		if part.owner == null:
			part.owner = branch
	var scene := PackedScene.new()
	scene.pack(branch)
	ResourceSaver.save(scene, "user://built_level.tscn")


func save_the_ship() -> void:
	var __branch_s1: Node = $Ship
	for __part_s1: Node in __branch_s1.find_children("*", "", true, false):
		if __part_s1.owner == null:
			__part_s1.owner = __branch_s1
	var __scene_s1 := PackedScene.new()
	var __packed_s1 := __scene_s1.pack(__branch_s1)
	if __packed_s1 != OK:
		push_error("Save Branch As Scene File: %s could not be packed (error %d)." % [__branch_s1.name, __packed_s1])
	elif ResourceSaver.save(__scene_s1, "user://built_ship.tscn") != OK:
		push_error("Save Branch As Scene File: nothing was written to %s." % "user://built_ship.tscn")


func save_the_room() -> void:
	var __branch_r1: Node = $Level/Room
	var __adopted_r1: Array[Node] = []
	for __part_r1: Node in __branch_r1.find_children("*", "", true, false):
		if __part_r1.owner == null:
			__part_r1.owner = __branch_r1
			__adopted_r1.append(__part_r1)
	var __scene_r1 := PackedScene.new()
	var __packed_r1 := __scene_r1.pack(__branch_r1)
	for __lent_r1: Node in __adopted_r1:
		__lent_r1.owner = null
	if __packed_r1 != OK:
		push_error("Save Branch As Scene File: %s could not be packed (error %d)." % [__branch_r1.name, __packed_r1])
	elif ResourceSaver.save(__scene_r1, "user://built_room.tscn") != OK:
		push_error("Save Branch As Scene File: nothing was written to %s." % "user://built_room.tscn")


func pack_it_only() -> void:
	var scene := PackedScene.new()
	scene.pack($Level)
	ResourceSaver.save(scene, "user://flat.tscn")
