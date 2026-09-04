# Godot EventSheets - Split Scene Into Chunks and Merge Chunks, driven with no editor.
#
# The two tools are the convenience beside a format anybody could write by hand, so what has to be
# true of them is narrow and exact: a child lands in the cell its own position falls in, it is
# re-based to that cell's origin so the chunk is authored around (0, 0) and the grid does the
# placing, and merging puts every one of them back where it started. That last one is the whole
# promise - a split you cannot undo is a one-way door onto somebody's level.
#
# The traps it exists to catch:
#   - a child one unit before the origin belongs to the cell BEFORE it, not to cell 0;
#   - a 2D scene's depth axis is its own y, which is what the flat file names spell;
#   - a child with no place in the world (a Timer, a Control) is named rather than guessed at;
#   - the files a split writes are the names the packs and the Doctor read;
#   - split then merge returns every child to the position it was authored at.
@tool
class_name ChunkToolsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST := "chunk_tools_test"
const WORLD_PATH := "user://chunk_tools_test_world.tscn"
const CHUNK_FOLDER := "user://chunk_tools_test_chunks"
const MERGED_PATH := "user://chunk_tools_test_merged.tscn"

## The cell box every case here uses: a hundred units on a side, so a position reads as its cell
## at a glance.
const CELL := Vector3(100.0, 100.0, 100.0)


static func run() -> bool:
	var passed: bool = _a_child_belongs_to_the_cell_its_position_falls_in()
	passed = _a_child_with_no_place_in_the_world_is_named() and passed
	passed = _a_split_writes_the_names_the_packs_read() and passed
	passed = _merging_puts_every_child_back() and passed
	passed = _the_receipt_says_what_happened() and passed
	return passed


# ── The plan ──────────────────────────────────────────────────────────────────────────────────


## Flooring, and the 2D depth axis. A Node2D's y is the SECOND number of a flat address, which is
## why `chunk_3_-2.tscn` is three cells right and two cells up the screen.
static func _a_child_belongs_to_the_cell_its_position_falls_in() -> bool:
	var root: Node2D = Node2D.new()
	var here: Node2D = _marker(root, "Here", Vector2(50.0, 50.0))
	var over: Node2D = _marker(root, "Over", Vector2(350.0, 50.0))
	var before: Node2D = _marker(root, "Before", Vector2(-1.0, -1.0))
	var plan: Dictionary = EventSheetChunkTools.plan_split(root, CELL, true)
	var cells: Dictionary = plan["cells"]
	var pins: Array = [
		["a child in the first cell is in cell (0, 0)",
			(cells[Vector3i(0, 0, 0)] as Array).size(), 1],
		["and it is the one that was standing there", (cells[Vector3i(0, 0, 0)] as Array)[0] == here, true],
		["three cells right is cell (3, 0)", (cells[Vector3i(3, 0, 0)] as Array)[0] == over, true],
		["one unit before the origin is the cell BEFORE it, on both flat axes",
			(cells[Vector3i(-1, 0, -1)] as Array)[0] == before, true],
		["a point's cell is floored, never truncated",
			EventSheetChunkTools.cell_of(Vector3(-0.5, 0.0, -0.5), CELL, true), Vector3i(-1, 0, -1)],
		["and a cell's own origin is where the split re-bases its children to",
			EventSheetChunkTools.origin_of(Vector3i(3, 0, -2), CELL, true),
			Vector3(300.0, 0.0, -200.0)],
	]
	root.free()
	return SUPPORT.pins(TEST, pins)


## A Timer has no position, so it has no cell. Guessing one would move somebody's node into a
## chunk that may never load; naming it in the receipt is the honest answer.
static func _a_child_with_no_place_in_the_world_is_named() -> bool:
	var root: Node2D = Node2D.new()
	_marker(root, "Rock", Vector2(50.0, 50.0))
	var timer: Timer = Timer.new()
	timer.name = "Respawn"
	root.add_child(timer)
	var plan: Dictionary = EventSheetChunkTools.plan_split(root, CELL, true)
	var pins: Array = [
		["the node with a place in the world is placed", (plan["cells"] as Dictionary).size(), 1],
		["and the one without is named rather than guessed at", plan["left_behind"],
			PackedStringArray(["Respawn"])],
	]
	root.free()
	return SUPPORT.pins(TEST, pins)


# ── The files ─────────────────────────────────────────────────────────────────────────────────


## The names a split writes are the names the Streamer packs ask the disk for and the Doctor reads
## the grid out of. They come from one grammar, so this is the pin that keeps the four in step.
static func _a_split_writes_the_names_the_packs_read() -> bool:
	var receipt: Dictionary = _split_a_world()
	var written: PackedStringArray = receipt["written"]
	var names: PackedStringArray = PackedStringArray()
	for path: String in written:
		names.append(path.get_file())
	var folders: Dictionary = EventForgeChunkFolderFacts.folders(written)
	return SUPPORT.pins(TEST, [
		["one file per cell that had something in it, in a fixed order", names,
			PackedStringArray(["chunk_-1_-1.tscn", "chunk_0_0.tscn", "chunk_3_0.tscn"])],
		["nothing stopped it", str(receipt["problem"]), ""],
		["and the folder it wrote reads back as a chunk folder", folders.size(), 1],
	])


## Split, then merge, then look: every child is where it was authored. A split you cannot undo is
## a one-way door onto somebody's level, so this is the promise the pair exists to keep.
static func _merging_puts_every_child_back() -> bool:
	_split_a_world()
	var receipt: Dictionary = EventSheetChunkTools.merge_chunks(CHUNK_FOLDER, CELL, MERGED_PATH)
	var merged: PackedScene = load(MERGED_PATH) as PackedScene
	var positions: Dictionary = {}
	if merged != null:
		var root: Node = merged.instantiate()
		for child: Node in root.get_children():
			if child is Node2D:
				positions[child.name] = (child as Node2D).position
		root.free()
	return SUPPORT.pins(TEST, [
		["every chunk was read", int(receipt["cells"]), 3],
		["nothing stopped it", str(receipt["problem"]), ""],
		["and every child is back where it was authored", positions, {
			"Here": Vector2(50.0, 50.0), "Over": Vector2(350.0, 50.0),
			"Before": Vector2(-1.0, -1.0)}],
	])


# ── The receipt ───────────────────────────────────────────────────────────────────────────────


## The dialog says one sentence afterwards, and a sentence nobody pins is a sentence that quietly
## stops mentioning the children it left behind.
static func _the_receipt_says_what_happened() -> bool:
	return SUPPORT.pins(TEST, [
		["a clean split counts its files", EventSheetChunkToolsDialog.receipt_words(
			{"cells": 4, "left_behind": PackedStringArray()}, true), "Wrote 4 chunk scene(s)."],
		["a split that left something behind says so, by name",
			EventSheetChunkToolsDialog.receipt_words(
				{"cells": 4, "left_behind": PackedStringArray(["Respawn"])}, true),
			"Wrote 4 chunk scene(s). 1 child(ren) had no place in the world and stayed put: Respawn."],
		["a merge names the scene it wrote", EventSheetChunkToolsDialog.receipt_words(
			{"cells": 9, "written": "res://world/world.tscn"}, false),
			"Merged 9 chunk(s) into res://world/world.tscn."],
		["and a problem is the whole answer", EventSheetChunkToolsDialog.receipt_words(
			{"problem": "res://nope.tscn is not a scene."}, true),
			"res://nope.tscn is not a scene."],
	])


# ── The fixture ───────────────────────────────────────────────────────────────────────────────


## Three markers in three cells, saved as a scene and split into a folder. Written to user://,
## because the tool reads and writes real files and the point is to check that it does.
static func _split_a_world() -> Dictionary:
	var root: Node2D = Node2D.new()
	root.name = "World"
	_marker(root, "Here", Vector2(50.0, 50.0))
	_marker(root, "Over", Vector2(350.0, 50.0))
	_marker(root, "Before", Vector2(-1.0, -1.0))
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, WORLD_PATH)
	root.free()
	return EventSheetChunkTools.split_scene(WORLD_PATH, CELL, CHUNK_FOLDER,
		EventSheetChunkTools.DEFAULT_PREFIX, true)


## One named marker under a root, owned by it, which is the one rule PackedScene.pack has.
static func _marker(root: Node, marker_name: String, at: Vector2) -> Node2D:
	var marker: Node2D = Node2D.new()
	marker.name = marker_name
	marker.position = at
	root.add_child(marker)
	marker.owner = root
	return marker
