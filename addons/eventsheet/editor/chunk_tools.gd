@tool
class_name EventSheetChunkTools
extends RefCounted

# Split Scene Into Chunks, and Merge Chunks - the two editor tools the Streamer packs ship with.
#
# A streamed world is a FOLDER OF SCENES named by cell, which is a format anybody can make by
# hand, read in a file browser and keep in version control. These two tools are the convenience,
# not the format: Split takes the big scene somebody has already built and writes the folder from
# it, Merge puts the folder back together into one scene so it can be edited as a whole again.
# Nothing here is baked, and a project that never runs either tool has lost nothing.
#
# THE WORK IS PURE WHERE IT CAN BE. `plan_split` decides which child belongs to which cell over a
# live node tree and touches no disk at all, so the decision is testable and the writing is a thin
# shell around it. The grammar of a chunk's NAME is not spelled here either: it comes from
# EventForgeChunkFolderFacts, which the packs and the Doctor read too, so the four can never
# disagree about which file is cell (3, -2).
#
# WHAT IT DOES NOT DO, said plainly: it moves the DIRECT CHILDREN of the scene's root, by their
# own position, and nothing else. A child whose position is not where it appears - one driven by a
# script, parented under another node, or drawn by a tilemap - is left where it already is and
# named in the receipt rather than guessed at. Split writes no root chunk, so "left behind" means
# left in the original scene, which Split never changes: a name in that list is a node the chunk
# folder does not hold. A tilemap is one node holding a whole world of cells and splitting it
# would mean rewriting its data; that is a job for the tilemap's own tools.

## What a chunk scene's root is called. One name, so a merged scene reads the same way whichever
## tool wrote it.
const CHUNK_ROOT_NAME := "Chunk"

## What Split calls its files when the caller says nothing. Deliberately free of digits: the
## address is the numbers at the END of the name, so a prefix ending in one would be read as part
## of it.
const DEFAULT_PREFIX := "chunk"


## Which cell each direct child of `root` belongs to, and which children could not be placed.
## Pure over a live node tree: no disk, no editor, no scene tree needed.
##
## `cell_size` is the box one chunk covers. A 2D scene uses x and z (a Node2D's own y is the
## depth axis of a flat grid, which is what the file names spell); a 3D scene uses all three when
## `flat` is false and ignores y when it is true.
static func plan_split(root: Node, cell_size: Vector3, flat: bool) -> Dictionary:
	var cells: Dictionary = {}
	var left_behind: PackedStringArray = PackedStringArray()
	if root == null:
		return {"cells": cells, "left_behind": left_behind}
	for child: Node in root.get_children():
		var placed: bool = false
		var cell: Vector3i = Vector3i.ZERO
		if child is Node2D:
			cell = cell_of(Vector3((child as Node2D).position.x, 0.0, (child as Node2D).position.y),
				cell_size, true)
			placed = true
		elif child is Node3D:
			cell = cell_of((child as Node3D).position, cell_size, flat)
			placed = true
		if not placed:
			# A Control, a Timer, an AudioStreamPlayer: it has no place in the world, so it has
			# no cell either. It stays in the scene being read - which Split never changes - and
			# is named in the receipt, never guessed at.
			left_behind.append(child.name)
			continue
		if not cells.has(cell):
			cells[cell] = []
		(cells[cell] as Array).append(child)
	return {"cells": cells, "left_behind": left_behind}


## The cell a world point falls in - floored, so a point one unit before the origin is the cell
## before it. The same arithmetic the packs do at run time, written once.
static func cell_of(point: Vector3, cell_size: Vector3, flat: bool) -> Vector3i:
	var width: float = cell_size.x if absf(cell_size.x) > 0.001 else 1.0
	var height: float = cell_size.y if absf(cell_size.y) > 0.001 else 1.0
	var depth: float = cell_size.z if absf(cell_size.z) > 0.001 else 1.0
	var level: int = 0 if flat else int(floor(point.y / height))
	return Vector3i(int(floor(point.x / width)), level, int(floor(point.z / depth)))


## Where a cell's own origin is in world space - what Split subtracts from every child it moves,
## and what Merge adds back.
static func origin_of(cell: Vector3i, cell_size: Vector3, flat: bool) -> Vector3:
	return Vector3(float(cell.x) * cell_size.x,
		0.0 if flat else float(cell.y) * cell_size.y, float(cell.z) * cell_size.z)


## Writes one folder of chunk scenes from one big scene, and returns the receipt: the files it
## wrote, the children it could not place, and the one sentence naming what stopped it.
## The scene it reads is never touched.
static func split_scene(scene_path: String, cell_size: Vector3, folder: String, prefix: String,
		flat: bool) -> Dictionary:
	var receipt: Dictionary = {"written": PackedStringArray(), "cells": 0,
		"left_behind": PackedStringArray(), "problem": ""}
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		receipt["problem"] = "%s is not a scene." % scene_path
		return receipt
	var root: Node = packed.instantiate()
	if root == null:
		receipt["problem"] = "%s could not be opened." % scene_path
		return receipt
	var into: String = _tidy_folder(folder)
	if into.is_empty() or DirAccess.make_dir_recursive_absolute(into) != OK:
		root.free()
		receipt["problem"] = "%s is not a folder this tool can write into." % folder
		return receipt
	var plan: Dictionary = plan_split(root, cell_size, flat)
	receipt["left_behind"] = plan["left_behind"]
	var written: PackedStringArray = PackedStringArray()
	var cells: Array = (plan["cells"] as Dictionary).keys()
	cells.sort_custom(_before)
	var used_prefix: String = prefix.strip_edges()
	if used_prefix.is_empty():
		used_prefix = DEFAULT_PREFIX
	for cell: Vector3i in cells:
		var chunk_path: String = into + EventForgeChunkFolderFacts.file_name_of(used_prefix, cell, flat)
		if _write_chunk(root, (plan["cells"] as Dictionary)[cell] as Array, cell, cell_size, flat,
				chunk_path):
			written.append(chunk_path)
	root.free()
	receipt["written"] = written
	receipt["cells"] = written.size()
	return receipt


## Puts a folder of chunk scenes back together as one scene, each chunk's children moved back to
## where they were in the world. The chunks it reads are never touched.
static func merge_chunks(folder: String, cell_size: Vector3, into_path: String) -> Dictionary:
	var receipt: Dictionary = {"written": "", "cells": 0, "problem": ""}
	var from: String = _tidy_folder(folder)
	var names: PackedStringArray = DirAccess.get_files_at(from)
	names.sort()
	var addresses: Array[Dictionary] = []
	for file_name: String in names:
		var address: Dictionary = EventForgeChunkFolderFacts.address_of(file_name)
		if not address.is_empty():
			address["file"] = file_name
			addresses.append(address)
	if addresses.is_empty():
		receipt["problem"] = "%s holds no scenes named like a cell." % folder
		return receipt
	var flat: bool = bool(addresses[0]["flat"])
	var root: Node = Node3D.new() if not _first_chunk_is_2d(from, addresses) else Node2D.new()
	root.name = into_path.get_file().get_basename().capitalize().replace(" ", "")
	if root.name.is_empty():
		root.name = "World"
	for address: Dictionary in addresses:
		var chunk_scene: PackedScene = load(from + str(address["file"])) as PackedScene
		if chunk_scene == null:
			continue
		var chunk: Node = chunk_scene.instantiate()
		var origin: Vector3 = origin_of(address["cell"] as Vector3i, cell_size, flat)
		for child: Node in chunk.get_children():
			var moved: Node = child.duplicate()
			_offset(moved, origin)
			root.add_child(moved)
			_own(moved, root)
		chunk.free()
		receipt["cells"] = int(receipt["cells"]) + 1
	var packed: PackedScene = PackedScene.new()
	var problem: int = packed.pack(root)
	if problem == OK:
		problem = ResourceSaver.save(packed, into_path)
	root.free()
	if problem != OK:
		receipt["problem"] = "%s could not be written." % into_path
		return receipt
	receipt["written"] = into_path
	return receipt


# One cell's scene: the children that fall in it, moved to the cell's own origin so the chunk is
# authored around (0, 0) and the grid does the placing at run time.
static func _write_chunk(root: Node, children: Array, cell: Vector3i, cell_size: Vector3,
		flat: bool, chunk_path: String) -> bool:
	var chunk_root: Node = Node2D.new() if root is Node2D else Node3D.new()
	chunk_root.name = CHUNK_ROOT_NAME
	var origin: Vector3 = origin_of(cell, cell_size, flat)
	for child: Node in children:
		var moved: Node = child.duplicate()
		_offset(moved, -origin)
		chunk_root.add_child(moved)
		_own(moved, chunk_root)
	var packed: PackedScene = PackedScene.new()
	var problem: int = packed.pack(chunk_root)
	if problem == OK:
		problem = ResourceSaver.save(packed, chunk_path)
	chunk_root.free()
	return problem == OK


# Moves one node by a world offset, in whichever dimension it lives in. A 2D node's depth axis is
# its own y, which is what the flat file names spell.
static func _offset(node: Node, by: Vector3) -> void:
	if node is Node2D:
		(node as Node2D).position += Vector2(by.x, by.z)
	elif node is Node3D:
		(node as Node3D).position += by


# Every node of a branch owned by the root being packed - the one rule PackedScene.pack has, and
# the reason a duplicated branch has to be walked rather than just added.
static func _own(node: Node, owner: Node) -> void:
	node.owner = owner
	for child: Node in node.get_children():
		_own(child, owner)


# Whether the folder's chunks are 2D, asked of the first one that opens. A folder mixes dimensions
# only if somebody wrote it by hand that way, and then the first chunk is as good an answer as any.
static func _first_chunk_is_2d(from: String, addresses: Array[Dictionary]) -> bool:
	for address: Dictionary in addresses:
		var chunk_scene: PackedScene = load(from + str(address["file"])) as PackedScene
		if chunk_scene == null:
			continue
		var state: SceneState = chunk_scene.get_state()
		return ClassDB.is_parent_class(state.get_node_type(0), "Node2D") if state.get_node_count() > 0 else false
	return false


# The folder as something a file name can be joined to: exactly one trailing slash.
static func _tidy_folder(folder: String) -> String:
	var tidied: String = folder.strip_edges()
	if tidied.is_empty():
		return ""
	return tidied if tidied.ends_with("/") else tidied + "/"


# One deterministic order over cells, so a split writes its files in the same sequence every time.
static func _before(left: Vector3i, right: Vector3i) -> bool:
	if left.x != right.x:
		return left.x < right.x
	if left.y != right.y:
		return left.y < right.y
	return left.z < right.z
