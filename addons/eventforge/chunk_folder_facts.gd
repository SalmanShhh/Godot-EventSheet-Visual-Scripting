# Godot EventSheets - the ONE reading of a folder of chunk scenes.
#
# A streamed world has no format: it is a folder of scenes named by cell, and the file name IS the
# address. `chunk_3_-2.tscn` is cell (3, -2) on a flat grid; `chunk_3_0_-2.tscn` is cell (3, 0, -2)
# on a 3D one. That grammar is read in three places - the Streamer packs at run time, the Doctor's
# Streaming section, and the Split Scene Into Chunks tool that writes such a folder - so it is
# written down once here and the three ask this file rather than each spelling it again.
#
# The prefix is whatever comes BEFORE the numbers, so a project may call its chunks `chunk`,
# `world` or `sector_a` and this still reads them. What decides a name is the run of whole numbers
# at the END of it: two of them is a flat grid, three is a stacked one, and a name with fewer than
# two is not a chunk at all. A prefix that itself ends in a number (`level_2`) is therefore read
# as part of the address, which is the one ambiguity in the grammar and the reason the tool that
# WRITES a folder never generates such a prefix.
#
# NOTHING here touches the disk: every function is pure over the names it is handed, so the
# Doctor's corpus, the tool's preview and a test all get the same answers from the same rules.
@tool
class_name EventForgeChunkFolderFacts
extends RefCounted

## The extension a chunk scene has. A folder of `.scn` files is a chunk folder too as far as the
## packs are concerned, but the tool writes text scenes and the Doctor reads them, so this is the
## one the reading is written against.
const SCENE_EXTENSION := "tscn"

## How few chunks a folder may hold and still be worth calling a chunk folder. One scene named
## like a cell is a coincidence; two is a grid somebody started.
const SMALLEST_FOLDER := 2


## What one file name says, or an empty dictionary when it says nothing. The keys are
## `prefix` (the words before the address), `cell` (a Vector3i, with y always 0 on a flat grid)
## and `flat` (true when the name carried two numbers rather than three).
static func address_of(file_name: String) -> Dictionary:
	if file_name.get_extension().to_lower() != SCENE_EXTENSION:
		return {}
	var parts: PackedStringArray = file_name.get_basename().split("_")
	var numbers: Array[int] = []
	var index: int = parts.size() - 1
	while index >= 0 and numbers.size() < 3 and _is_whole_number(parts[index]):
		numbers.push_front(int(parts[index]))
		index -= 1
	if numbers.size() < 2 or index < 0:
		return {}
	var prefix: String = "_".join(PackedStringArray(Array(parts).slice(0, index + 1)))
	if prefix.is_empty():
		return {}
	if numbers.size() == 2:
		return {"prefix": prefix, "cell": Vector3i(numbers[0], 0, numbers[1]), "flat": true}
	return {"prefix": prefix, "cell": Vector3i(numbers[0], numbers[1], numbers[2]), "flat": false}


## The file name one cell's scene has. The inverse of `address_of`, and the one place the tool
## that writes a folder gets its names from.
static func file_name_of(prefix: String, cell: Vector3i, flat: bool) -> String:
	if flat:
		return "%s_%d_%d.%s" % [prefix, cell.x, cell.z, SCENE_EXTENSION]
	return "%s_%d_%d_%d.%s" % [prefix, cell.x, cell.y, cell.z, SCENE_EXTENSION]


## The chunk folders among a list of scene paths: folder -> the cells it holds, in the order the
## paths arrived. A folder is only a chunk folder when at least two of its scenes read as an
## address and they all agree on whether the grid is flat - a folder of two flat chunks and one
## stacked one is somebody's naming accident, not a grid, and saying so wrongly would be worse
## than saying nothing.
static func folders(scene_paths: PackedStringArray) -> Dictionary:
	var by_folder: Dictionary = {}
	for scene_path: String in scene_paths:
		var address: Dictionary = address_of(scene_path.get_file())
		if address.is_empty():
			continue
		var folder: String = scene_path.get_base_dir()
		if not by_folder.has(folder):
			by_folder[folder] = {"cells": [], "paths": PackedStringArray(), "flat": bool(address["flat"]),
				"prefix": str(address["prefix"]), "mixed": false}
		var entry: Dictionary = by_folder[folder]
		if bool(entry["flat"]) != bool(address["flat"]):
			entry["mixed"] = true
		(entry["cells"] as Array).append(address["cell"] as Vector3i)
		var paths: PackedStringArray = entry["paths"]
		paths.append(scene_path)
		entry["paths"] = paths
	var kept: Dictionary = {}
	for folder: String in by_folder.keys():
		var entry: Dictionary = by_folder[folder]
		if bool(entry["mixed"]) or (entry["cells"] as Array).size() < SMALLEST_FOLDER:
			continue
		kept[folder] = entry
	return kept


## The cells missing from the box the given cells span, sorted, so two machines reading one folder
## report the same holes in the same order. A world with nothing but two distant islands in it
## spans a box that is mostly empty and is NOT a grid with holes - `gap_is_worth_reporting` is the
## question that tells the two apart, and this function only lists.
static func missing_cells(cells: Array) -> Array[Vector3i]:
	var present: Dictionary = {}
	for cell: Vector3i in cells:
		present[cell] = true
	if present.is_empty():
		return []
	var low: Vector3i = present.keys()[0] as Vector3i
	var high: Vector3i = low
	for cell: Vector3i in present.keys():
		low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
		high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
	var missing: Array[Vector3i] = []
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			for z: int in range(low.z, high.z + 1):
				var cell: Vector3i = Vector3i(x, y, z)
				if not present.has(cell):
					missing.append(cell)
	missing.sort_custom(_before)
	return missing


## Whether a folder's holes are worth a word. A gap is worth reporting when the folder is a grid
## somebody meant to fill - most of the box is there and a few cells are not. A handful of scenes
## scattered across a huge box is a deliberately sparse world, and a note about its "holes" would
## be a page of noise about a world that is exactly as its author left it.
static func gap_is_worth_reporting(present: int, missing: int) -> bool:
	if missing <= 0 or present < 4:
		return false
	return missing * 4 <= present


## The cells as words, at most this many of them, so a finding names the holes instead of counting
## them. Flat cells are read without their always-zero height.
static func cells_as_words(cells: Array, flat: bool, most: int) -> String:
	var words: PackedStringArray = PackedStringArray()
	for cell: Vector3i in cells:
		if words.size() >= most:
			words.append("...")
			break
		words.append("(%d, %d)" % [cell.x, cell.z] if flat else "(%d, %d, %d)" % [cell.x, cell.y, cell.z])
	return ", ".join(words)


# One deterministic order over cells: x, then y, then z.
static func _before(left: Vector3i, right: Vector3i) -> bool:
	if left.x != right.x:
		return left.x < right.x
	if left.y != right.y:
		return left.y < right.y
	return left.z < right.z


# True for a part that is a whole number, sign and all. `is_valid_int` accepts a leading "-", which
# is exactly what a cell left of the origin needs.
static func _is_whole_number(part: String) -> bool:
	return not part.is_empty() and part.is_valid_int()
