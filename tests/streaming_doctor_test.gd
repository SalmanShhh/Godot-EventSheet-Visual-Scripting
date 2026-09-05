# Godot EventSheets - the chunk-folder reading, and the Doctor's Streaming section over it.
#
# A streamed world has no format: the file name IS the address, so everything the Doctor can say
# about one comes out of a grammar (`chunk_3_-2.tscn` is cell (3, -2)) and two rules over it. Both
# halves are pinned here, and every fixture is written out rather than read off disk, because the
# question is what the RULES say and not what this repository's folders happen to hold.
#
# The traps it exists to catch:
#   - a prefix with an underscore in it (`sector_a_3_-2.tscn`) still reads as an address;
#   - a name with one number is not a chunk, and neither is a name with no prefix;
#   - a flat name and a stacked name in one folder is somebody's naming accident, not a grid,
#     and the folder is left alone rather than reported wrongly;
#   - the holes are the cells missing from the BOX the folder spans, in one deterministic order;
#   - a deliberately sparse world - two islands far apart - is not a grid with holes, so it earns
#     no finding at all;
#   - a chunk carrying a camera is found by reading the scene as TEXT, because loading every
#     chunk of a streamed world to audit it is the one thing the pack exists to avoid;
#   - the section registers under the id the chips and the panel address it by.
@tool
class_name StreamingDoctorTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST := "streaming_doctor_test"

## A chunk scene with a camera in it - the shape a `.tscn` really has, so the reading is pinned
## against the text the editor writes rather than against a substring somebody invented.
const CHUNK_WITH_A_CAMERA := """[gd_scene load_steps=2 format=3]

[node name="Chunk" type="Node2D"]

[node name="Camera2D" type="Camera2D" parent="."]
"""

const CHUNK_WITHOUT_A_CAMERA := """[gd_scene load_steps=2 format=3]

[node name="Chunk" type="Node2D"]

[node name="Ground" type="StaticBody2D" parent="."]
"""


static func run() -> bool:
	var passed: bool = _a_file_name_is_an_address()
	passed = _an_address_is_a_file_name() and passed
	passed = _a_folder_is_a_grid_or_it_is_not() and passed
	passed = _the_holes_are_the_cells_the_box_is_missing() and passed
	passed = _a_sparse_world_is_not_a_grid_with_holes() and passed
	passed = _a_camera_is_read_out_of_the_scene_text() and passed
	passed = _the_section_reports_both_and_registers() and passed
	return passed


# ── The grammar ───────────────────────────────────────────────────────────────────────────────


static func _a_file_name_is_an_address() -> bool:
	return SUPPORT.pins(TEST, [
		["two numbers is a flat cell, with no height in it",
			EventForgeChunkFolderFacts.address_of("chunk_3_-2.tscn"),
			{"prefix": "chunk", "cell": Vector3i(3, 0, -2), "flat": true}],
		["three numbers is a stacked cell",
			EventForgeChunkFolderFacts.address_of("chunk_3_1_-2.tscn"),
			{"prefix": "chunk", "cell": Vector3i(3, 1, -2), "flat": false}],
		["a prefix may hold underscores of its own",
			EventForgeChunkFolderFacts.address_of("sector_a_3_-2.tscn"),
			{"prefix": "sector_a", "cell": Vector3i(3, 0, -2), "flat": true}],
		["one number is not an address", EventForgeChunkFolderFacts.address_of("chunk_3.tscn"), {}],
		["and neither is a name that is nothing but numbers",
			EventForgeChunkFolderFacts.address_of("3_-2.tscn"), {}],
		["nor a file that is not a scene",
			EventForgeChunkFolderFacts.address_of("chunk_3_-2.png"), {}],
	])


static func _an_address_is_a_file_name() -> bool:
	return SUPPORT.pins(TEST, [
		["a flat cell is written without its always-zero height",
			EventForgeChunkFolderFacts.file_name_of("chunk", Vector3i(3, 0, -2), true),
			"chunk_3_-2.tscn"],
		["a stacked cell carries all three numbers",
			EventForgeChunkFolderFacts.file_name_of("chunk", Vector3i(3, 1, -2), false),
			"chunk_3_1_-2.tscn"],
		["and what is written reads back as the cell it was written for",
			EventForgeChunkFolderFacts.address_of(
				EventForgeChunkFolderFacts.file_name_of("sector_a", Vector3i(-4, 0, 7), true)),
			{"prefix": "sector_a", "cell": Vector3i(-4, 0, 7), "flat": true}],
	])


# ── What counts as a chunk folder ─────────────────────────────────────────────────────────────


static func _a_folder_is_a_grid_or_it_is_not() -> bool:
	var one_grid: Dictionary = EventForgeChunkFolderFacts.folders(PackedStringArray([
		"res://world/chunks/chunk_0_0.tscn", "res://world/chunks/chunk_1_0.tscn",
		"res://world/hero.tscn"]))
	var too_few: Dictionary = EventForgeChunkFolderFacts.folders(PackedStringArray([
		"res://world/chunks/chunk_0_0.tscn"]))
	var mixed: Dictionary = EventForgeChunkFolderFacts.folders(PackedStringArray([
		"res://world/chunks/chunk_0_0.tscn", "res://world/chunks/chunk_1_0_0.tscn",
		"res://world/chunks/chunk_2_0.tscn"]))
	return SUPPORT.pins(TEST, [
		["a folder of two addressed scenes is a grid", one_grid.keys(), ["res://world/chunks"]],
		["and the scene beside it that is not addressed is not part of it",
			(one_grid["res://world/chunks"] as Dictionary)["cells"],
			[Vector3i(0, 0, 0), Vector3i(1, 0, 0)]],
		["one scene named like a cell is a coincidence, not a grid", too_few.keys(), []],
		["and a folder that cannot agree whether it is flat is left alone", mixed.keys(), []],
	])


# ── The holes ─────────────────────────────────────────────────────────────────────────────────


static func _the_holes_are_the_cells_the_box_is_missing() -> bool:
	# A three-by-three grid with the middle and one corner never made.
	var cells: Array = []
	for x: int in range(3):
		for z: int in range(3):
			if Vector3i(x, 0, z) in [Vector3i(1, 0, 1), Vector3i(2, 0, 2)]:
				continue
			cells.append(Vector3i(x, 0, z))
	return SUPPORT.pins(TEST, [
		["the holes are named, in one deterministic order",
			EventForgeChunkFolderFacts.missing_cells(cells),
			[Vector3i(1, 0, 1), Vector3i(2, 0, 2)]],
		["a full box has none", EventForgeChunkFolderFacts.missing_cells([
			Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(1, 0, 1)]), []],
		["and the count agrees with the list without walking the box",
			EventForgeChunkFolderFacts.missing_count(cells), 2],
		["and the words a finding uses leave the always-zero height out",
			EventForgeChunkFolderFacts.cells_as_words(
				[Vector3i(1, 0, 1), Vector3i(2, 0, 2)], true, 6), "(1, 1), (2, 2)"],
		["stopping when it has named enough of them",
			EventForgeChunkFolderFacts.cells_as_words(
				[Vector3i(1, 0, 1), Vector3i(2, 0, 2)], true, 1), "(1, 1), ..."],
	])


## A world of two distant islands spans an enormous box that is almost all hole. It is not a grid
## somebody forgot to finish, and a page of notes about its "missing" cells would be noise about a
## world that is exactly as its author left it.
static func _a_sparse_world_is_not_a_grid_with_holes() -> bool:
	return SUPPORT.pins(TEST, [
		["one hole in a grid of eight is worth a word",
			EventForgeChunkFolderFacts.gap_is_worth_reporting(8, 1), true],
		["two islands with a hundred empty cells between them are not",
			EventForgeChunkFolderFacts.gap_is_worth_reporting(4, 100), false],
		["a folder too small to have a shape yet says nothing",
			EventForgeChunkFolderFacts.gap_is_worth_reporting(3, 1), false],
		["and a full grid has nothing to say either",
			EventForgeChunkFolderFacts.gap_is_worth_reporting(9, 0), false],
		["two islands are counted, never enumerated: a quarter of a million cells, answered flat",
			EventForgeChunkFolderFacts.missing_count(
				[Vector3i(0, 0, 0), Vector3i(500, 0, 500)]), 250999],
		["and the count is what decides the question, so the box is never walked",
			EventForgeChunkFolderFacts.gap_is_worth_reporting(2,
				EventForgeChunkFolderFacts.missing_count(
					[Vector3i(0, 0, 0), Vector3i(500, 0, 500)])), false],
	])


# ── The camera ────────────────────────────────────────────────────────────────────────────────


static func _a_camera_is_read_out_of_the_scene_text() -> bool:
	return SUPPORT.pins(TEST, [
		["a chunk carrying a Camera2D is found",
			EventSheetStreamingDoctor.carries_a_camera(CHUNK_WITH_A_CAMERA), true],
		["a chunk carrying a Camera3D is found too",
			EventSheetStreamingDoctor.carries_a_camera(
				CHUNK_WITH_A_CAMERA.replace("Camera2D", "Camera3D")), true],
		["and a chunk that is only scenery is left alone",
			EventSheetStreamingDoctor.carries_a_camera(CHUNK_WITHOUT_A_CAMERA), false],
	])


# ── The section ───────────────────────────────────────────────────────────────────────────────


static func _the_section_reports_both_and_registers() -> bool:
	var paths: PackedStringArray = PackedStringArray()
	for x: int in range(3):
		for z: int in range(3):
			if Vector3i(x, 0, z) == Vector3i(1, 0, 1):
				continue
			paths.append("res://world/chunks/chunk_%d_%d.tscn" % [x, z])
	var folders: Dictionary = EventForgeChunkFolderFacts.folders(paths)
	var texts: Dictionary = {}
	for scene_path: String in paths:
		texts[scene_path] = CHUNK_WITHOUT_A_CAMERA
	texts["res://world/chunks/chunk_2_2.tscn"] = CHUNK_WITH_A_CAMERA
	var report: Array[Dictionary] = EventSheetStreamingDoctor.report(folders, texts)
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in report:
		checks.append(str(finding["check"]))
	# Registering twice would run the section twice; the seam replaces by id, and this is what
	# proves it (ensure_registered may already have been called by a Doctor run in this process).
	EventSheetStreamingDoctor.ensure_registered()
	EventSheetStreamingDoctor.ensure_registered()
	var registered: int = 0
	for entry: Dictionary in EventSheetProjectDoctor._extension_checks:
		if str(entry.get("id", "")) == EventSheetStreamingDoctor.CHECK_ID:
			registered += 1
	var empty: Array[Dictionary] = EventSheetStreamingDoctor.report({}, {})
	return SUPPORT.pins(TEST, [
		["the summary comes first, then the hole, then the camera", checks, PackedStringArray([
			EventSheetStreamingDoctor.CHECK_ID, EventSheetStreamingDoctor.CHECK_GAP,
			EventSheetStreamingDoctor.CHECK_CAMERA])],
		["the hole finding names the file that is missing", str(report[1]["subject"]),
			"chunk_1_1.tscn"],
		["the camera finding opens the chunk that carries it", str(report[2]["path"]),
			"res://world/chunks/chunk_2_2.tscn"],
		["a project with no chunk folder in it reports nothing at all", empty.size(), 0],
		["and the section is registered through the public seam, exactly once", registered, 1],
	])
