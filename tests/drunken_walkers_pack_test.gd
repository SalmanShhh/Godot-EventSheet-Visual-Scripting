# Godot EventSheets - the Drunken Walkers pack, driven directly.
#
# The pack is a seeded generator, so almost everything worth asserting about it is a PROMISE
# ABOUT REPRODUCTION rather than about one map: the same seed and the same action order give the
# same cells, a weighted pick spends one value whether or not weights are set, Create Grid leaves
# the seed alone and Set Seed leaves the grid alone. None of that can be checked by looking at a
# picture of a cave, so this file loads the COMPILED pack, drives the real generator with no scene
# tree and no physics, and pins the values it produces.
#
# The traps it exists to catch, each one a rule the source guide states and a reader would
# otherwise have to trust:
#   - the pack is the DrunkenWalkers autoload, and every row it emits addresses it by that name;
#   - two directions cannot turn unless the max turn is 180, so a smaller one draws a line;
#   - a diagonal walk leaves holes that thickness, not direction, fixes;
#   - a border repels rather than traps, re-rolling among the headings that stay IN BOUNDS,
#     so a corner widens the pool past Max Turn instead of ending the walk;
#   - a walker with nothing in bounds at all still FINISHES;
#   - a 0 weight rules a heading out for good, border re-rolls included;
#   - a cell on the grid border can never be interior, because off-grid neighbours never match;
#   - spacing is per tag, spans two passes, and at 0 still forbids two marks stacking;
#   - dilation grows exactly one ring per iteration because it reads a snapshot;
#   - outlining only ever overwrites the Empty Value;
#   - On Walker Stepped fires from Step Walker and from nothing else;
#   - On Cell Carved fires on a CHANGE, so a second walk over the same cells is silent;
#   - a saved state resumes on the identical random stream, cell for cell.
@tool
class_name DrunkenWalkersPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/drunken_walkers/drunken_walkers_behavior.gd"
const TEST := "drunken_walkers_pack_test"


static func run() -> bool:
	var script: GDScript = load(PACK)
	var passed: bool = SUPPORT.check(TEST, "the pack loads and parses", script != null, true)
	if script == null:
		return passed
	passed = _the_pack_ships_as_the_autoload(script) and passed
	passed = _seed_reproduces_the_map(script) and passed
	passed = _grid_and_seed_are_independent(script) and passed
	passed = _two_directions_cannot_turn_without_180(script) and passed
	passed = _thickness_fills_the_diagonal_holes(script) and passed
	passed = _borders_repel_and_a_boxed_walker_finishes(script) and passed
	passed = _a_zero_weight_rules_a_heading_out(script) and passed
	passed = _placement_rules_read_the_eight_neighbours(script) and passed
	passed = _spacing_is_per_tag_and_spans_passes(script) and passed
	passed = _dilate_grows_one_ring_from_a_snapshot(script) and passed
	passed = _outline_only_overwrites_the_empty_value(script) and passed
	passed = _cells_are_indexed_left_to_right_top_to_bottom(script) and passed
	passed = _stepped_fires_from_step_walker_only(script) and passed
	passed = _carving_fires_on_a_change_only(script) and passed
	passed = _a_saved_state_resumes_the_identical_path(script) and passed
	passed = _the_six_presets_carry_their_recipe(script) and passed
	passed = _define_walker_reads_a_whole_definition(script) and passed
	return passed


# ── One generator, reached from anywhere ──────────────────────────────────────────────────────


## A generator is a project-wide service, so this pack ships as the DrunkenWalkers AUTOLOAD, the
## way every other generator here does. That is not a remark about the file: it is what every row
## the pack emits ADDRESSES, so it is pinned against the shipped bytes rather than against the
## builder's intent. The seam it has to keep answering is the save one - a save pack walks the
## autoloads by name and asks each of them for save_state, with no parent in the picture.
static func _the_pack_ships_as_the_autoload(script: GDScript) -> bool:
	var source: String = FileAccess.get_file_as_string(PACK)
	var templates: int = 0
	var not_the_autoload: int = 0
	for line: String in source.split("\n"):
		if not line.begins_with("## @ace_codegen_template("):
			continue
		templates += 1
		if not line.begins_with("## @ace_codegen_template(\"DrunkenWalkers."):
			not_the_autoload += 1
	var pack: Node = script.new()
	var answers_the_save_seam: bool = pack.has_method("save_state") and pack.has_method("load_state")
	pack.free()
	return SUPPORT.pins(TEST, [
		["every published verb addresses the autoload by name", not_the_autoload, 0],
		["and all sixty-three of them are published", templates, 63],
		["nothing is scoped to a node, because an autoload has no host to act on",
			source.contains("var host: Node"), false],
		["and the save seam still answers, which is how a save pack finds an autoload",
			answers_the_save_seam, true],
	])


# ── The seed is the map ───────────────────────────────────────────────────────────────────────


static func _seed_reproduces_the_map(script: GDScript) -> bool:
	var first: String = _generated_map(script, "sundown")
	var again: String = _generated_map(script, "sundown")
	var other: String = _generated_map(script, "sundowo")
	return SUPPORT.pins(TEST, [
		["the same seed carves byte-identical cells", again, first],
		["a seed one character apart carves a different map", other == first, false],
		["and the map is not simply empty", first.contains("#"), true],
	])


## One 24 x 16 map from one seed: the whole point of the pack in five rows.
static func _generated_map(script: GDScript, seed_text: String) -> String:
	var pack: Node = script.new()
	pack.create_grid(24, 16)
	pack.set_seed(seed_text)
	pack.add_walker("main", 12, 8, 200, 8, 180.0, "", 1)
	pack.run_all_walkers()
	var text: String = pack.as_text(".#")
	pack.free()
	return text


static func _grid_and_seed_are_independent(script: GDScript) -> bool:
	var pack: Node = script.new()
	# Create Grid does not reset the seed.
	pack.set_seed("keep-me")
	pack.create_grid(20, 20)
	var seed_after_grid: String = pack.current_seed()
	# Set Seed does not clear the grid.
	pack.create_grid(7, 5)
	pack.set_cell(1, 1, 4)
	pack.set_seed("brand-new")
	var passed: bool = SUPPORT.pins(TEST, [
		["Create Grid leaves the seed exactly as it was", seed_after_grid, "keep-me"],
		["Set Seed leaves the grid's width alone", pack.current_grid_width(), 7],
		["Set Seed leaves the grid's height alone", pack.current_grid_height(), 5],
		["Set Seed leaves a hand-written cell alone", pack.cell_value(1, 1), 4],
		["an out-of-bounds read is the Empty Value, never an error", pack.cell_value(99, 99), 0],
		["but the Is Cell Value condition matches nothing out of bounds",
			pack.is_cell_value(99, 99, 0), false],
	])
	pack.free()
	return passed


# ── Directions, turning and thickness ─────────────────────────────────────────────────────────


static func _two_directions_cannot_turn_without_180(script: GDScript) -> bool:
	# Two headings sit 180 degrees apart, so any smaller max turn puts the second one out of
	# reach and the walk is a dead straight line - identical to a one-direction walker.
	var straight: Node = script.new()
	straight.create_grid(20, 11)
	straight.set_seed("ribbon")
	straight.add_walker("line", 2, 5, 10, 2, 90.0, "", 1)
	straight.run_all_walkers()
	var straight_cells: int = straight.count_cells(1)
	var straight_row: bool = _every_cell_on_row(straight, 1, 5)
	straight.free()

	# Raise it to 180 and the opposite problem appears: it reverses on the spot, so ten steps of
	# walking carve fewer than eleven cells.
	var reversing: Node = script.new()
	reversing.create_grid(20, 11)
	reversing.set_seed("ribbon")
	reversing.add_walker("line", 2, 5, 10, 2, 180.0, "", 1)
	reversing.run_all_walkers()
	var reversing_cells: int = reversing.count_cells(1)
	var reversing_row: bool = _every_cell_on_row(reversing, 1, 5)
	reversing.free()

	return SUPPORT.pins(TEST, [
		["a max turn under 180 draws the start cell plus every step", straight_cells, 11],
		["and never leaves its row", straight_row, true],
		["a max turn of 180 doubles back over ground it already carved",
			reversing_cells < straight_cells, true],
		["and still never leaves its row, because both headings are horizontal",
			reversing_row, true],
	])


static func _thickness_fills_the_diagonal_holes(script: GDScript) -> bool:
	# A diagonal step moves on both axes at once, so it never touches the cell between.
	var thin: Node = script.new()
	thin.create_grid(20, 20)
	thin.add_walker("diagonal", 2, 2, 5, 1, 0.0, "", 1)
	thin.set_walker_start_angle("diagonal", 45.0)
	thin.run_all_walkers()
	var thin_gap: int = thin.cell_value(3, 2)
	var thin_cells: int = thin.count_cells(1)
	thin.free()

	# The fix is thickness, not direction: the same walk with a two-cell brush is solid.
	var thick: Node = script.new()
	thick.create_grid(20, 20)
	thick.add_walker("diagonal", 2, 2, 5, 1, 0.0, "", 1)
	thick.set_walker_start_angle("diagonal", 45.0)
	thick.set_walker_brush_size("diagonal", 2)
	thick.run_all_walkers()
	var thick_gap: int = thick.cell_value(3, 2)
	thick.free()

	return SUPPORT.pins(TEST, [
		["a one-cell diagonal walk carves the start cell plus every step", thin_cells, 6],
		["and leaves the cell beside each step empty", thin_gap, 0],
		["a two-cell brush fills that same hole", thick_gap, 1],
	])


static func _borders_repel_and_a_boxed_walker_finishes(script: GDScript) -> bool:
	# A walker that can never leave a five-cell square eventually stands on every cell of it,
	# because the border re-rolls it back inward instead of ending the walk.
	var boxed: Node = script.new()
	boxed.create_grid(5, 5)
	boxed.set_seed("rattle")
	boxed.add_walker("rattle", 2, 2, 300, 8, 180.0, "", 1)
	boxed.run_all_walkers()
	var filled: String = boxed.as_text(".#")
	boxed.free()

	# No legal heading at all is the one way a walk ends early, and it still FINISHES, so
	# chaining logic never stalls.
	var trapped: Node = script.new()
	trapped.create_grid(1, 1)
	var finished: Array[String] = []
	trapped.walker_finished.connect(func(id: String) -> void: finished.append(id))
	trapped.add_walker("stuck", 0, 0, 100, 8, 180.0, "", 1)
	trapped.run_all_walkers()
	var trapped_cells: int = trapped.count_cells(1)
	trapped.free()

	# A walker that starts off the grid carves nothing at all and finishes immediately.
	var outside: Node = script.new()
	outside.create_grid(8, 8)
	outside.add_walker("nowhere", 40, 40, 50, 8, 180.0, "", 1)
	outside.run_all_walkers()
	var outside_cells: int = outside.count_cells(1)
	outside.free()

	# THE CORNER. Four diagonal headings anchored at 225 degrees and a 90 degree max turn: a
	# walker standing in the top-left cell pointing up-left can reach 225, 135 and 315, and all
	# three leave the grid. A re-roll narrowed by Max Turn would therefore find nothing and end
	# the walk on its first step. The re-roll is scoped to the headings that stay IN BOUNDS
	# instead, widening past Max Turn when it must, so the walker turns as sharply as the corner
	# demands, takes 45 degrees back into the grid, and spends its whole budget. Turn chance 0
	# leaves the border as the ONLY thing that can change the heading.
	var cornered: Node = script.new()
	cornered.create_grid(12, 12)
	cornered.set_seed("corner")
	cornered.add_walker("corner", 0, 0, 40, 4, 90.0, "", 1)
	cornered.set_walker_start_angle("corner", 225.0)
	cornered.set_walker_turn_chance("corner", 0.0)
	cornered.run_all_walkers()
	var cornered_cells: int = cornered.count_cells(1)
	var cornered_far_corner: int = cornered.cell_value(11, 11)
	cornered.free()

	return SUPPORT.pins(TEST, [
		["a boxed-in walker fills its whole grid rather than sticking to an edge",
			filled, "#####\n#####\n#####\n#####\n#####"],
		["a walker with nowhere legal to go still carves its own cell", trapped_cells, 1],
		["and still fires On Walker Finished", str(finished), str(["stuck"])],
		["a walker that starts outside the grid carves nothing", outside_cells, 0],
		["a cornered walker turns past its max turn rather than ending in the corner",
			cornered_cells, 12],
		["and walks the whole diagonal rather than stopping on its start cell",
			cornered_far_corner, 1],
	])


static func _a_zero_weight_rules_a_heading_out(script: GDScript) -> bool:
	# Weights 1,5,9,5,1,0,0,0 zero the three upward headings (indices 5, 6 and 7 are 225, 270
	# and 315 degrees), so a walker carrying them can never climb above the row it started on.
	var pack: Node = script.new()
	pack.create_grid(21, 21)
	pack.set_seed("descend")
	pack.add_walker("vein", 10, 2, 40, 8, 180.0, "", 1)
	pack.set_walker_direction_weights("vein", "1,5,9,5,1,0,0,0")
	pack.run_all_walkers()
	var highest: int = _highest_carved_row(pack, 1)
	var carved: int = pack.count_cells(1)
	pack.free()
	return SUPPORT.pins(TEST, [
		["a zeroed heading is never picked, so nothing is carved above the start row",
			highest, 2],
		["while the walk itself still happened", carved > 1, true],
	])


# ── Marks: placement, spacing, tags ───────────────────────────────────────────────────────────


static func _placement_rules_read_the_eight_neighbours(script: GDScript) -> bool:
	# A solid 5 x 5 block of floor inside a 9 x 9 grid: nine of its cells have all eight
	# neighbours holding the value, and the other sixteen do not.
	var block: Node = script.new()
	block.create_grid(9, 9)
	for y: int in range(2, 7):
		for x: int in range(2, 7):
			block.set_cell(x, y, 1)
	block.set_seed("placement")
	block.scatter_marks(100, "inner", 1, "interior", 0.0)
	block.scatter_marks(100, "outer", 1, "edge", 0.0)
	block.scatter_marks(100, "either", 1, "any", 0.0)
	var interior: int = block.count_marks("inner")
	var edge: int = block.count_marks("outer")
	var any_placement: int = block.count_marks("either")
	block.free()

	# Off-grid neighbours never match, so a cell on the grid border is always an edge cell and
	# never an interior one - which is what makes border detection work with no special case.
	var full: Node = script.new()
	full.create_grid(9, 9)
	full.clear_grid(1)
	full.set_seed("borders")
	full.scatter_marks(200, "inner", 1, "interior", 0.0)
	var full_interior: int = full.count_marks("inner")
	full.free()

	return SUPPORT.pins(TEST, [
		["interior is the 3 x 3 heart of a 5 x 5 block", interior, 9],
		["edge is everything else in it", edge, 16],
		["any placement is the whole block", any_placement, 25],
		["a grid filled edge to edge has only its 7 x 7 middle as interior",
			full_interior, 49],
	])


static func _spacing_is_per_tag_and_spans_passes(script: GDScript) -> bool:
	var pack: Node = script.new()
	pack.create_grid(9, 9)
	pack.clear_grid(1)
	pack.set_seed("spacing")
	# A spacing of 0 still forbids two marks of one tag stacking on a single cell, so a 9 x 9
	# grid takes exactly its 81 cells and not one more.
	pack.scatter_marks(500, "dust", 1, "any", 0.0)
	var stacked: int = pack.count_marks("dust")
	# Separate tags never crowd each other out.
	pack.scatter_marks(500, "gems", 1, "any", 0.0)
	var second_tag: int = pack.count_marks("gems")
	# Two passes of ONE tag see each other: the second keeps its distance from the first.
	pack.create_grid(21, 21)
	pack.clear_grid(1)
	pack.scatter_marks(4, "chest", 1, "any", 4.0)
	var after_first_pass: int = pack.count_marks("chest")
	pack.scatter_marks(4, "chest", 1, "any", 4.0)
	var closest: float = _closest_pair(pack, "chest")
	var after_second_pass: int = pack.count_marks("chest")
	pack.free()
	return SUPPORT.pins(TEST, [
		["spacing 0 still refuses to stack two marks of a tag on one cell", stacked, 81],
		["a second tag is spaced against itself alone", second_tag, 81],
		["the first pass places what it was asked for on a grid with room", after_first_pass, 4],
		["the second pass adds more of the same tag", after_second_pass, 8],
		["and every one of them respects the other pass's spacing", closest >= 4.0, true],
	])


# ── The two post-processing passes ────────────────────────────────────────────────────────────


static func _dilate_grows_one_ring_from_a_snapshot(script: GDScript) -> bool:
	var one: Node = script.new()
	one.create_grid(9, 9)
	one.set_cell(4, 4, 1)
	one.dilate_cells(1, 1)
	var after_one: int = one.count_cells(1)
	one.free()

	var two: Node = script.new()
	two.create_grid(9, 9)
	two.set_cell(4, 4, 1)
	two.dilate_cells(1, 2)
	var after_two: int = two.count_cells(1)
	two.free()

	# Dilation converts a neighbour whatever value it held, which is why it has to run before
	# you carve terrain you want to keep.
	var terrain: Node = script.new()
	terrain.create_grid(9, 9)
	terrain.set_cell(4, 4, 1)
	terrain.set_cell(5, 4, 2)
	terrain.dilate_cells(1, 1)
	var eaten: int = terrain.cell_value(5, 4)
	terrain.free()

	return SUPPORT.pins(TEST, [
		["one iteration grows exactly one ring, not a smear across the scan",
			after_one, 9],
		["two iterations grow exactly two", after_two, 25],
		["and dilation converts another terrain value where they touch", eaten, 1],
	])


static func _outline_only_overwrites_the_empty_value(script: GDScript) -> bool:
	var pack: Node = script.new()
	pack.create_grid(9, 9)
	for y: int in range(3, 6):
		for x: int in range(3, 6):
			pack.set_cell(x, y, 1)
	# A neighbouring cell that already holds water: an outline pass must leave it be.
	pack.set_cell(2, 2, 7)
	pack.outline_cells(1, 3)
	var passed: bool = SUPPORT.pins(TEST, [
		["an empty cell touching the floor becomes the outline value", pack.cell_value(2, 3), 3],
		["a cell holding another value is never overwritten", pack.cell_value(2, 2), 7],
		["the floor itself is untouched", pack.cell_value(4, 4), 1],
		["and the ring is exactly the cells that touch it", pack.count_cells(3), 15],
	])
	pack.free()
	return passed


# ── Reading the results back ──────────────────────────────────────────────────────────────────


static func _cells_are_indexed_left_to_right_top_to_bottom(script: GDScript) -> bool:
	var pack: Node = script.new()
	pack.create_grid(5, 5)
	# Written out of order on purpose: the index order is the GRID's, not the writing order.
	pack.set_cell(1, 2, 1)
	pack.set_cell(3, 1, 1)
	pack.set_cell(0, 0, 1)
	var passed: bool = SUPPORT.pins(TEST, [
		["the first cell is the top-left one", str([pack.cell_x_by_index(1, 0),
			pack.cell_y_by_index(1, 0)]), str([0, 0])],
		["then the next row's, left to right", str([pack.cell_x_by_index(1, 1),
			pack.cell_y_by_index(1, 1)]), str([3, 1])],
		["then the row after that", str([pack.cell_x_by_index(1, 2),
			pack.cell_y_by_index(1, 2)]), str([1, 2])],
		["how many there are", pack.count_cells(1), 3],
		["an index past the end reads -1 rather than erroring",
			pack.cell_x_by_index(1, 3), -1],
		["and so does a negative one", pack.cell_y_by_index(1, -1), -1],
		["a mark index past the end reads -1 too", pack.mark_x_by_index("none", 0), -1],
		["the eight neighbours are counted without the border special case",
			pack.neighbour_count(0, 0, 1), 0],
	])
	pack.free()
	return passed


# ── The trigger matrix ────────────────────────────────────────────────────────────────────────


static func _stepped_fires_from_step_walker_only(script: GDScript) -> bool:
	var pack: Node = script.new()
	pack.create_grid(20, 20)
	pack.set_seed("animate")
	var stepped: Array[String] = []
	var finished: Array[String] = []
	var completed: Array[String] = []
	var batches: Array[String] = []
	pack.walker_stepped.connect(func(id: String) -> void: stepped.append(id))
	pack.walker_finished.connect(func(id: String) -> void: finished.append(id))
	pack.generation_complete.connect(func() -> void: completed.append("all"))
	pack.walkers_by_tag_complete.connect(func(tag: String) -> void: batches.append(tag))

	pack.add_walker("shown", 10, 10, 3, 8, 180.0, "", 1)
	pack.step_walker("shown", 5)
	var stepped_from_stepping: int = stepped.size()
	var finished_from_stepping: int = finished.size()

	stepped.clear()
	finished.clear()
	pack.add_walker("bulk", 5, 5, 20, 8, 180.0, "terrain", 1)
	pack.run_walker("bulk")
	var stepped_from_running: int = stepped.size()
	var completed_from_run_walker: int = completed.size()

	pack.add_walker("batched", 15, 15, 10, 8, 180.0, "terrain", 1)
	pack.run_walkers_by_tag("terrain")
	pack.run_all_walkers()

	var passed: bool = SUPPORT.pins(TEST, [
		["Step Walker fires On Walker Stepped once per step it actually took",
			stepped_from_stepping, 3],
		["and On Walker Finished when the budget runs out", finished_from_stepping, 1],
		["a batch run fires no stepped trigger at all", stepped_from_running, 0],
		["Run Walker does not fire On Generation Complete", completed_from_run_walker, 0],
		["Run Walkers By Tag fires its own completion with the batch tag",
			str(batches), str(["terrain"])],
		["Run All Walkers fires On Generation Complete", completed.size(), 1],
	])
	pack.free()
	return passed


static func _carving_fires_on_a_change_only(script: GDScript) -> bool:
	var pack: Node = script.new()
	pack.create_grid(5, 5)
	var carved: Array[int] = []
	var carved_ids: Array[String] = []
	pack.cell_carved.connect(func(_x: int, _y: int, value: int, id: String) -> void:
		carved.append(value)
		carved_ids.append(id))
	pack.add_walker("first", 0, 2, 4, 1, 0.0, "", 1)
	pack.run_all_walkers()
	var first_pass: int = carved.size()
	var first_id: String = carved_ids[0] if not carved_ids.is_empty() else "?"

	# The same walk again over the same cells: nothing CHANGES, so nothing fires.
	carved.clear()
	pack.add_walker("second", 0, 2, 4, 1, 0.0, "", 1)
	pack.run_walker("second")
	var second_pass: int = carved.size()

	# Set Cell and Clear Grid are documented silent writes.
	carved.clear()
	pack.set_cell(4, 4, 6)
	pack.clear_grid(0)
	var silent_writes: int = carved.size()

	# A post-processing pass carves with an EMPTY walker id, which is how a sheet tells a
	# dilated cell from a walked one.
	carved_ids.clear()
	pack.set_cell(2, 2, 1)
	pack.dilate_cells(1, 1)
	var post_id: String = carved_ids[0] if not carved_ids.is_empty() else "?"

	var passed: bool = SUPPORT.pins(TEST, [
		["a five-cell walk carves five cells", first_pass, 5],
		["and names the walker responsible", first_id, "first"],
		["walking the same cells again changes nothing, so nothing fires", second_pass, 0],
		["Set Cell and Clear Grid are silent", silent_writes, 0],
		["a dilated cell reports no walker at all", post_id, ""],
		["and the walker context is back to nothing outside a trigger",
			str([pack.walker_id(), pack.walker_x(), pack.carved_value(), pack.mark_tag()]),
			str(["", 0, 0, ""])],
	])
	pack.free()
	return passed


# ── Save and load ─────────────────────────────────────────────────────────────────────────────


static func _a_saved_state_resumes_the_identical_path(script: GDScript) -> bool:
	var live: Node = script.new()
	live.create_grid(24, 24)
	live.set_seed("resume-me")
	live.add_walker("show", 12, 12, 60, 8, 180.0, "", 1)
	live.step_walker("show", 20)
	live.scatter_marks(3, "gem", 1, "any", 2.0)
	var state: String = live.save_state_as_text()
	var half_way: String = live.as_text(".#")
	live.step_walker("show", 60)
	var finished_map: String = live.as_text(".#")
	var finished_marks: int = live.count_marks("gem")
	live.free()

	var restored: Node = script.new()
	var replayed: Array[String] = []
	restored.cell_carved.connect(func(_x: int, _y: int, _v: int, _id: String) -> void:
		replayed.append("carved"))
	restored.mark_placed.connect(func(_tag: String) -> void: replayed.append("mark"))
	restored.load_state_from_text(state)
	var loading_replayed: int = replayed.size()
	var restored_half_way: String = restored.as_text(".#")
	restored.step_walker("show", 60)
	var restored_map: String = restored.as_text(".#")
	var restored_marks: int = restored.count_marks("gem")
	var restored_seed: String = restored.current_seed()
	restored.free()

	# The save-pack seam: any node answering save_state / load_state is snapshotted with no
	# registration and no base class - and a save pack walks the autoloads by name - so the same
	# record travels through a Dictionary as well as through text.
	var through_seam: Node = script.new()
	through_seam.load_state(JSON.parse_string(state) as Dictionary)
	var seam_map: String = through_seam.as_text(".#")
	var seam_text: String = through_seam.save_state_as_text()
	through_seam.free()

	return SUPPORT.pins(TEST, [
		["the state restores the grid exactly as it was saved", restored_half_way, half_way],
		["the save-pack seam carries the same record as the text door", seam_map, half_way],
		["and hands it back byte for byte", seam_text, state],
		["and every mark with it", restored_marks, finished_marks],
		["and the seed the run was on", restored_seed, "resume-me"],
		["loading replays no trigger at all", loading_replayed, 0],
		["the remaining walk continues on the identical random stream",
			restored_map, finished_map],
		["and it really did carry on walking", finished_map == half_way, false],
	])


# ── Recipes and definitions ───────────────────────────────────────────────────────────────────


static func _the_six_presets_carry_their_recipe(script: GDScript) -> bool:
	var pack: Node = script.new()
	pack.create_grid(30, 30)
	for preset: String in ["cave", "corridors", "river", "ore vein", "lightning", "blob"]:
		pack.add_walker_from_preset(preset, preset, 15, 15, "shapes", 1)
	var passed: bool = SUPPORT.pins(TEST, [
		["Cave is eight headings, a 180 degree max turn and a full turn chance",
			_recipe(pack, "cave"), "8/180/1/1/"],
		["Corridors is four headings at right angles, turning rarely",
			_recipe(pack, "corridors"), "4/90/0.15/1/"],
		["River is three headings, a gentle turn and a two-cell brush",
			_recipe(pack, "river"), "3/45/0.35/2/"],
		["Ore Vein always descends", _recipe(pack, "ore vein"),
			"8/90/1/1/2,6,9,6,2,0,0,0"],
		["Lightning drifts sideways but can never climb", _recipe(pack, "lightning"),
			"8/45/1/1/1,5,9,5,1,0,0,0"],
		["Blob is short and fat", _recipe(pack, "blob"), "8/180/1/4/"],
		["a preset gets the id, position, tag and carve value you gave it",
			str([pack.has_walker("cave"), pack.has_walker("nothing")]), str([true, false])],
		["and a name that is not a recipe registers nothing",
			_registers(pack, "spaghetti"), false],
	])
	pack.free()
	return passed


static func _define_walker_reads_a_whole_definition(script: GDScript) -> bool:
	var pack: Node = script.new()
	pack.create_grid(30, 30)
	pack.define_walker("{\"id\":\"river\",\"startX\":3,\"startY\":4,\"steps\":7,\"directions\":4,"
		+ "\"maxTurn\":90,\"turnChance\":0.5,\"carveValue\":9,\"brushSize\":2,"
		+ "\"brushWidth\":5,\"brushHeight\":-2,\"tag\":\"water\",\"weights\":[1,4,9,0]}")
	# The snake_case spelling of every field is accepted too, because that is how the same
	# field is written everywhere else in a Godot project.
	pack.define_walker("{\"id\":\"road\",\"start_x\":8,\"start_y\":9,\"steps\":12,"
		+ "\"turn_chance\":0.15,\"carve_value\":3}")
	var walker: RefCounted = pack._walkers["river"]
	var road: RefCounted = pack._walkers["road"]
	var passed: bool = SUPPORT.pins(TEST, [
		["every field of the definition lands on the walker",
			str([walker.start_x, walker.start_y, walker.steps, walker.directions,
				walker.max_turn, walker.turn_chance, walker.carve_value, walker.brush_size,
				walker.brush_width, walker.brush_height, walker.tag]),
			str([3, 4, 7, 4, 90.0, 0.5, 9, 2, 5, -2, "water"])],
		["including the weights array, negatives floored to 0",
			str(walker.weights), str([1.0, 4.0, 9.0, 0.0])],
		["the snake_case spelling of the same fields works as well",
			str([road.start_x, road.start_y, road.steps, road.turn_chance, road.carve_value]),
			str([8, 9, 12, 0.15, 3])],
		["anything left out takes its default", str([road.directions, road.max_turn,
			road.brush_size, road.tag]), str([8, 180.0, 1, ""])],
		["and a string that is not a definition registers nothing",
			_defines(pack, "{not json"), false],
	])
	pack.free()
	return passed


# ── Small readers the pins are built from ─────────────────────────────────────────────────────


## One preset's recipe as a single readable string: headings / max turn / turn chance / brush /
## weights. Pinning it as one value keeps the whole recipe on one line of the report.
static func _recipe(pack: Node, id: String) -> String:
	var walker: RefCounted = pack._walkers[id]
	var weights: PackedStringArray = PackedStringArray()
	for weight: float in walker.weights:
		weights.append(str(int(weight)))
	return "%d/%s/%s/%d/%s" % [walker.directions, _plain(walker.max_turn),
		_plain(walker.turn_chance), walker.brush_size, ",".join(weights)]


## A float without its trailing zeros, so a recipe reads 180 and 0.15 rather than 180.0.
static func _plain(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")


## Whether Add Walker From Preset accepted this name.
static func _registers(pack: Node, preset: String) -> bool:
	pack.add_walker_from_preset(preset, "probe", 1, 1, "", 1)
	return pack.has_walker("probe")


## Whether Define Walker accepted this string. Handing it a string that is not JSON is the point
## of the pin, so the engine's own "Parse JSON failed" line during this test is expected noise.
static func _defines(pack: Node, definition: String) -> bool:
	var before: int = pack._walkers.size()
	pack.define_walker(definition)
	return pack._walkers.size() > before


## Whether every cell holding the value sits on one row.
static func _every_cell_on_row(pack: Node, value: int, row: int) -> bool:
	for index: int in pack.count_cells(value):
		if pack.cell_y_by_index(value, index) != row:
			return false
	return true


## The topmost row any cell of this value was carved on.
static func _highest_carved_row(pack: Node, value: int) -> int:
	var highest: int = pack.current_grid_height()
	for index: int in pack.count_cells(value):
		highest = mini(highest, pack.cell_y_by_index(value, index))
	return highest


## The distance between the two closest marks carrying a tag.
static func _closest_pair(pack: Node, tag: String) -> float:
	var closest: float = 1000000.0
	var total: int = pack.count_marks(tag)
	for first: int in total:
		for second: int in range(first + 1, total):
			var dx: float = float(pack.mark_x_by_index(tag, first)
				- pack.mark_x_by_index(tag, second))
			var dy: float = float(pack.mark_y_by_index(tag, first)
				- pack.mark_y_by_index(tag, second))
			closest = minf(closest, sqrt(dx * dx + dy * dy))
	return closest
