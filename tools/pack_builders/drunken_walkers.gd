# Pack builder - drunken_walkers (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## The six shape recipes, as a dropdown on Add Walker From Preset. The keys are what the action
## reads (it lowercases and turns underscores into spaces), the labels are what the picker shows.
const _PRESETS := ["cave=Cave", "corridors=Corridors", "river=River", "ore_vein=Ore Vein",
	"lightning=Lightning", "blob=Blob"]

## The three placement rules Scatter Marks filters eligible cells by.
const _PLACEMENTS := ["any=Any cell", "interior=Interior only", "edge=Edge only"]

## Where the generator's randomness comes from.
const _SOURCES := ["internal=Internal seeded", "shared=Shared Advanced Random", "injected=Injected queue"]


## Drunken Walkers: a seeded grid generator driven from event rows. Walkers are agents with a
## heading that stagger one cell per step and write a value into what they visit; marks are tagged
## points the pack places for you with real spacing rules. The whole run comes out of ONE seeded
## stream in a fixed order, so a seed string reproduces a map cell for cell - floors, ore, coins
## and enemies alike - on every machine the game ships to.
##
## The pack owns the grid and nothing visible: it never draws a tile, spawns a node or sets a
## position. You read the results through triggers and expressions and drive your own TileMapLayer
## or scenes, which is exactly why it works with any art pipeline.
##
## It ships as the DrunkenWalkers AUTOLOAD, exactly like every other generator here (ProcRoom,
## AdvancedRandom, LootBox, Storylets, SkinVault): a generator is a project-wide service reached
## from any sheet without a node path, and one seed driving one grid is what makes a run
## reproducible. The cost is honest - one grid per project - and the pack says so where it bites.
##
## Ported from a well-known event-sheet engine's generator addon, with its determinism contract
## kept intact: same seed plus same action order gives identical output, a weighted pick spends
## exactly one random value whether or not weights are set, Create Grid does not reset the seed,
## and Set Seed does not clear the grid.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("drunken_walkers", "Node", "DrunkenWalkersAddon",
		"A seeded grid generator as the DrunkenWalkers autoload: register walkers that stagger across a grid of integers carving caves, corridors, rivers and ore veins, scatter tagged marks with real spacing and placement rules, then read the result back as cells and marks. One seed string reproduces the whole map, placement included, on every machine.",
		Lib.manifest().autoload("DrunkenWalkers").category("Drunken Walkers").tags(["procedural", "generation", "random", "grid"]))
	# Property ORDER is part of the pack: these emit in the order they are declared here.
	src.sheet.variables = {
		"grid_width": {"type": "int", "default": 64, "exported": true,
			"attributes": {"tooltip": "Grid width in cells. The grid is built at this size from the start, and this is the fallback Create Grid uses for a width of 0 or less.", "range": {"min": "1", "max": "2048", "step": "1"}}},
		"grid_height": {"type": "int", "default": 64, "exported": true,
			"attributes": {"tooltip": "Grid height in cells. The grid is built at this size from the start, and this is the fallback Create Grid uses for a height of 0 or less.", "range": {"min": "1", "max": "2048", "step": "1"}}},
		"max_grid_size": {"type": "int", "default": 2048, "exported": true,
			"attributes": {"tooltip": "Hard cap on both axes. Create Grid clamps to it and says so in Debug Mode, so a bad expression fails loudly instead of reserving gigabytes.", "range": {"min": "1", "max": "8192", "step": "1"}}},
		"cell_size": {"type": "int", "default": 32, "exported": true,
			"attributes": {"tooltip": "Pixel size of one cell. Used only by the four coordinate conversion expressions, never by generation itself.", "range": {"min": "1", "max": "512", "step": "1"}}},
		"origin_x": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "World X of the grid's top-left corner, for the coordinate expressions."}},
		"origin_y": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "World Y of the grid's top-left corner, for the coordinate expressions."}},
		"empty_value": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "The value a fresh grid is filled with. It is also what an out-of-bounds Cell Value reads, and the only value Outline Cells is allowed to overwrite."}},
		"start_seed": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The seed the generator starts on. Left empty it derives one from the clock and remembers it, so Current Seed can still show the player a code - but the first run of a session is not reproducible until you call Set Seed."}},
		"random_source": {"type": "String", "default": "internal", "exported": true, "options": ["internal", "shared", "injected"],
			"attributes": {"tooltip": "internal = this pack's own seeded generator. shared = the Advanced Random autoload, so one seed drives every procedural system at once. injected = the queue Inject Random fills, for one audited stream."}},
		"debug_mode": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Warns about walker lifecycles, clamped grid sizes, scatters that could not fit, an injected queue running dry, and the four common reasons a map comes out empty. On while you build, off for release."}},
	}
	src.note("Drunken Walkers (autoload): register as the DrunkenWalkers autoload, then size a grid, set a seed, register walkers and run them from any sheet. The pack owns the grid and the marks; you paint the tiles and spawn the objects from the results. Same seed plus same action order = the same map every time. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()

	# ── Grid ──────────────────────────────────────────────────────────────────────────────
	src.verb("create_grid", "Create Grid",
		"Allocates a fresh grid filled with the Empty Value, clamped to Max Grid Size. Only needed for a size other than the Grid Width / Grid Height properties, because that grid already exists from the start. A width or height of 0 or less falls back to its property. Destroys the previous grid, every registered walker and every mark - it is \"start a new level\". The seed is not touched.",
		[["width", "int"], ["height", "int"]])
	src.verb("clear_grid", "Clear Grid",
		"Refills every cell with a value you choose. Walkers, marks and the random stream are left alone, and it does not fire On Cell Carved. Use it to re-run the same walkers over a blank slate without re-registering them.",
		[["value", "int"]])
	src.verb("set_cell", "Set Cell",
		"Writes one cell directly. Deliberately silent: it does not fire On Cell Carved, which makes it the right tool for pre-placing anchors like a guaranteed entrance or a boss room before the walkers run.",
		[["x", "int"], ["y", "int"], ["value", "int"]])
	src.verb("set_origin", "Set Origin",
		"Moves the grid in world space and optionally changes the cell size, for the four coordinate expressions. Pass 0 for the cell size to keep the current one.",
		[["x", "float"], ["y", "float"], ["new_cell_size", "int"]])
	src.verb("draw_cells_to_tilemap", "Draw Cells To Tilemap",
		"Paints one tile into a TileMapLayer for every cell holding a value, replacing the whole paint loop. Cell coordinates map straight onto tile coordinates. Call it once per value; a source id of -1 erases those tiles instead.",
		[["layer", "TileMapLayer"], ["value", "int"], ["source_id", "int"], ["atlas_x", "int"], ["atlas_y", "int"]])

	# ── Randomness ────────────────────────────────────────────────────────────────────────
	src.verb("set_seed", "Set Seed",
		"Resets the generator from a seed string. Call it BEFORE generating: the same seed with the same action order reproduces identical output, and calling it afterwards changes nothing about the map you just built. It does not clear the grid.",
		[["seed_text", "String"]])
	src.verb("set_random_source", "Set Random Source",
		"Switches where every decision draws from: this pack's own seeded generator, the shared Advanced Random autoload, or the injected queue Inject Random fills. You may switch mid-run, so one pass can audit through a single stream while the rest does not.",
		[["source", "String"]])
	_options(src.sheet, "source", _SOURCES)
	src.verb("inject_random", "Inject Random",
		"Queues one value between 0 and 1 for the injected source, generation consuming them in order. Budget roughly two per walker step plus one per mark candidate. A queue that runs dry falls back to the internal generator rather than failing, and says so in Debug Mode.",
		[["value", "float"]])

	# ── Walkers ───────────────────────────────────────────────────────────────────────────
	src.verb("add_walker", "Add Walker",
		"Registers a walker with the eight settings you change most: where it starts, how many steps it has, how many headings it may face (1 to 8), how far it may turn in one step, its tag and the value it carves. Everything else takes its default. Re-using an id replaces that walker without moving it in the run order.",
		[["id", "String"], ["start_x", "int"], ["start_y", "int"], ["steps", "int"],
			["directions", "int"], ["max_turn", "float"], ["tag", "String"], ["carve_value", "int"]])
	src.verb("add_walker_from_preset", "Add Walker From Preset",
		"Registers a walker from a named shape recipe - Cave, Corridors, River, Ore Vein, Lightning or Blob - so you only need a position, a tag and a carve value. Tune it afterwards with the Set Walker actions.",
		[["preset", "String"], ["id", "String"], ["start_x", "int"], ["start_y", "int"],
			["tag", "String"], ["carve_value", "int"]])
	_options(src.sheet, "preset", _PRESETS)
	src.verb("define_walker", "Define Walker",
		"Registers a walker from a whole JSON definition in one string, which suits definitions that live in a data file or a level editor. Anything you leave out takes its default. Both spellings of every field are accepted, so startX and start_x both work.",
		[["definition", "String"]])
	src.verb("set_walker_carve_value", "Set Walker Carve Value",
		"Changes the integer an existing walker writes into the cells it visits. It applies from that walker's next step, so anything already carved keeps its old value - which is how one walker lays down two materials along one path.",
		[["id", "String"], ["value", "int"]])
	src.verb("set_walker_steps", "Set Walker Steps",
		"Sets a walker's REMAINING step budget, and un-finishes a finished walker, so topping one up and running it again extends the path it already drew.",
		[["id", "String"], ["steps", "int"]])
	src.verb("set_walker_turn_chance", "Set Walker Turn Chance",
		"Sets the 0 to 1 probability that a walker even considers turning on a given step. At 1 the heading performs its own random walk and the path curls; around 0.15 to 0.3 is what actually reads as a road or a river.",
		[["id", "String"], ["chance", "float"]])
	src.verb("set_walker_brush_size", "Set Walker Brush Size",
		"Sets the square block a walker stamps each step. 1 is a single cell, 3 is a centred 3x3. It never rotates, so it is right for blobby caves and wrong for corridors - use the dig size for those. Ignored while a dig size is set.",
		[["id", "String"], ["size", "int"]])
	src.verb("set_walker_start_angle", "Set Walker Start Angle",
		"Rotates the walker's whole direction set to a new anchor angle, in degrees, 0 being right and 90 down. The direction weights rotate with it, because weight entry 0 always weighs the start angle.",
		[["id", "String"], ["degrees", "float"]])
	src.verb("set_walker_dig_size", "Set Walker Dig Size",
		"Swaps the square brush for a rectangle that TURNS WITH THE WALKER. Width is measured across the heading and is always centred, so a corridor keeps its width around every corner. Depth is measured along the heading and is signed: positive digs ahead of the walker, negative digs behind it. 0 on an axis falls back to the brush size, and 0 on both restores the square brush.",
		[["id", "String"], ["width", "int"], ["depth", "int"]])
	src.verb("set_walker_direction_weights", "Set Walker Direction Weights",
		"Biases which heading a walker turns toward, as a comma separated list of relative weights in direction order starting at the start angle. A 0 rules that heading out, a missing entry counts as 1, extra entries are ignored, and an empty string restores equal weights.",
		[["id", "String"], ["weights", "String"]])
	src.verb("remove_walker", "Remove Walker",
		"Unregisters a walker. Everything it already carved stays exactly as it is, because carving writes into the grid as it happens rather than being replayed at the end.",
		[["id", "String"]])
	src.verb("run_all_walkers", "Run All Walkers",
		"Runs every registered walker to the end of its budget, in registration order, then fires On Generation Complete. This is the whole generation in one row.",
		[])
	src.verb("run_walkers_by_tag", "Run Walkers By Tag",
		"Runs only the walkers carrying a tag, in registration order, then fires On Walkers By Tag Complete. Staging generation in tagged passes is how a later pass reacts to what an earlier one carved. An empty tag is not a wildcard here: it runs the walkers that genuinely have no tag.",
		[["tag", "String"]])
	src.verb("run_walker", "Run Walker",
		"Runs one walker by id to the end of its budget. It fires On Cell Carved and On Walker Finished but deliberately NOT On Generation Complete, because it is one pass of a bigger generation rather than the end of it.",
		[["id", "String"]])
	src.verb("step_walker", "Step Walker",
		"Advances one walker by up to this many steps instead of running it out, firing On Walker Stepped per step - the row that makes the map draw itself in front of the player. The walk is identical to an instant run, just spread over time. The first call carves the start cell, so nothing has to place the walker first.",
		[["id", "String"], ["steps", "int"]])

	# ── Marks ─────────────────────────────────────────────────────────────────────────────
	src.verb("drop_marks_along_walk", "Drop Marks Along Walk",
		"Replays a walker's recorded path and considers a candidate every N steps, keeping each with the given chance and rejecting it if it lands too close to an existing mark of the same tag. The walker must have run already, because the path is recorded as it walks. Candidates start at step N, not at the start cell.",
		[["walker_id", "String"], ["tag", "String"], ["every_steps", "int"], ["chance", "float"],
			["min_spacing", "float"]])
	src.verb("scatter_marks", "Scatter Marks",
		"Places up to this many tagged marks on cells holding a value, filtered by the placement rule and thinned by minimum spacing. The count is a maximum, not a promise: tight spacing or a rule that matches almost nothing places fewer, and Debug Mode says how many it managed.",
		[["count", "int"], ["tag", "String"], ["value", "int"], ["placement", "String"],
			["min_spacing", "float"]])
	_options(src.sheet, "placement", _PLACEMENTS)
	src.verb("clear_marks", "Clear Marks",
		"Removes every mark carrying a tag, an empty tag removing all of them. The grid is untouched, so clearing marks and re-scattering only re-rolls the placement.",
		[["tag", "String"]])

	# ── Post-processing ───────────────────────────────────────────────────────────────────
	src.verb("dilate_cells", "Dilate Cells",
		"Grows every region of a value outward by one ring per iteration, which is how one-cell corridors become chambers. It converts ANY neighbouring cell, including ones holding other values, so dilate before you carve terrain you want to keep. Each iteration works from a snapshot, so one pass grows exactly one ring.",
		[["value", "int"], ["iterations", "int"]])
	src.verb("outline_cells", "Outline Cells",
		"Writes an outline value into every Empty Value cell touching a cell of the target value - the classic walls-around-the-floor pass. Unlike dilation it only ever overwrites the Empty Value, so water and ore survive it, which makes it safe to run last.",
		[["value", "int"], ["outline_value", "int"]])

	# ── Save and load ─────────────────────────────────────────────────────────────────────
	src.verb("load_state_from_text", "Load State From Text",
		"Restores a whole generator from the text Save State As Text produced: the grid, the origin and cell size, the seed, the random stream's own position, every walker with its progress and recorded path, and every mark. Restoring is SILENT - no On Cell Carved and no On Mark Placed - so repaint from Count Cells and the index expressions afterwards.",
		[["state", "String"]])

	# ── Conditions ────────────────────────────────────────────────────────────────────────
	src.condition("is_cell_value", "Is Cell Value",
		"True when the cell holds exactly that value. Stricter than the Cell Value expression: an out-of-bounds cell matches nothing, not even the Empty Value, which is what lets you test the border honestly.",
		[["x", "int"], ["y", "int"], ["value", "int"]])
	src.condition("is_inside_grid", "Is Inside Grid",
		"True when the X and Y fall inside the current grid. Guard anything built from Layout To X / Layout To Y with it, because a point on screen may simply not be over the grid.",
		[["x", "int"], ["y", "int"]])
	src.condition("has_mark_at", "Has Mark At",
		"True when a mark with the tag sits on that cell. An empty tag matches any mark, which is the quick way to ask whether anything is already here.",
		[["x", "int"], ["y", "int"], ["tag", "String"]])
	src.condition("has_walker", "Has Walker",
		"True when a walker with that id is currently registered.",
		[["id", "String"]])

	# ── Expressions ───────────────────────────────────────────────────────────────────────
	src.expression("cell_value", "Cell Value",
		"The value at a cell. Asking outside the grid reads the Empty Value rather than erroring, so it is always safe to call.",
		[["x", "int"], ["y", "int"]], TYPE_INT)
	src.expression("current_grid_width", "Current Grid Width",
		"The current grid width in cells, which is what Create Grid last built rather than the property.",
		[], TYPE_INT)
	src.expression("current_grid_height", "Current Grid Height",
		"The current grid height in cells, which is what Create Grid last built rather than the property.",
		[], TYPE_INT)
	src.expression("as_text", "As Text",
		"The whole grid as text, one character per cell and one line per row. Character N of what you pass stands for value N, and an unmapped value shows as a question mark. Put it in a Label to see the map instantly, before you have a tilemap at all.",
		[["characters", "String"]], TYPE_STRING)
	src.expression("neighbour_count", "Neighbour Count",
		"How many of the eight surrounding cells hold a value. Off-grid neighbours never match, which is what makes border detection and autotiling work without special-casing the edge.",
		[["x", "int"], ["y", "int"], ["value", "int"]], TYPE_INT)
	src.expression("cell_to_world_x", "Cell To World X",
		"The world X of that cell's CENTRE, from Origin X and Cell Size - so a sprite placed on it lands centred in its tile whatever the origin is.",
		[["x", "int"]], TYPE_FLOAT)
	src.expression("cell_to_world_y", "Cell To World Y",
		"The world Y of that cell's centre, from Origin Y and Cell Size.",
		[["y", "int"]], TYPE_FLOAT)
	src.expression("world_to_cell_x", "World To Cell X",
		"The cell X containing that world X. It may fall outside the grid, so guard it with Is Inside Grid.",
		[["world_x", "float"]], TYPE_INT)
	src.expression("world_to_cell_y", "World To Cell Y",
		"The cell Y containing that world Y. It may fall outside the grid, so guard it with Is Inside Grid.",
		[["world_y", "float"]], TYPE_INT)
	src.expression("count_cells", "Count Cells",
		"How many cells currently hold the value. Pairs with the two index expressions to walk the whole set, which is the fast way to paint a generated map.",
		[["value", "int"]], TYPE_INT)
	src.expression("cell_x_by_index", "Cell X By Index",
		"The X of the index-th cell holding the value, counted from 0 in a stable left-to-right, top-to-bottom order. Out of range reads -1 rather than erroring.",
		[["value", "int"], ["index", "int"]], TYPE_INT)
	src.expression("cell_y_by_index", "Cell Y By Index",
		"The Y of the index-th cell holding the value, in the same stable order. Out of range reads -1.",
		[["value", "int"], ["index", "int"]], TYPE_INT)
	src.expression("count_marks", "Count Marks",
		"How many marks carry the tag. An empty tag counts every mark, whatever its tag.",
		[["tag", "String"]], TYPE_INT)
	src.expression("mark_x_by_index", "Mark X By Index",
		"The X of the index-th mark with the tag, counted from 0 in placement order. Out of range reads -1.",
		[["tag", "String"], ["index", "int"]], TYPE_INT)
	src.expression("mark_y_by_index", "Mark Y By Index",
		"The Y of the index-th mark with the tag, in placement order. Out of range reads -1.",
		[["tag", "String"], ["index", "int"]], TYPE_INT)
	src.expression("current_seed", "Current Seed",
		"The seed the generator was last set with, including one derived from the clock - so a player can always be shown the code that reproduces the run they are in.",
		[], TYPE_STRING)
	src.expression("injected_remaining", "Injected Remaining",
		"How many injected values are still queued. Read it after a generation to see how much headroom the queue actually had.",
		[], TYPE_INT)
	src.expression("save_state_as_text", "Save State As Text",
		"The whole generator as one JSON string: the grid, the origin and cell size, the seed, the random stream's own position, every walker with its progress and recorded path, and every mark. Because the stream position round-trips, a half-finished Step Walker animation resumes and produces the identical remaining path. Save it with any save pack, hand it back to Load State From Text.",
		[], TYPE_STRING)
	src.expression("walker_x", "Walker X",
		"The current X of the triggering walker. Reads 0 outside the walker triggers, never a stale cell.",
		[], TYPE_INT)
	src.expression("walker_y", "Walker Y",
		"The current Y of the triggering walker. Reads 0 outside the walker triggers.",
		[], TYPE_INT)
	src.expression("walker_angle", "Walker Angle",
		"The current heading of the triggering walker in degrees, 0 being right and 90 down - point a digger sprite at it and it faces where it is going.",
		[], TYPE_FLOAT)
	src.expression("walker_steps_left", "Walker Steps Left",
		"The remaining step budget of the triggering walker, which is the natural driver for a generation progress bar.",
		[], TYPE_INT)
	src.expression("walker_id", "Walker ID",
		"The id of the triggering walker. It is empty inside the post-processing passes and outside the triggers, which is how On Cell Carved tells a dilated cell from a carved one.",
		[], TYPE_STRING)
	src.expression("walker_tag", "Walker Tag",
		"The tag of the triggering walker, or the batch tag inside On Walkers By Tag Complete.",
		[], TYPE_STRING)
	src.expression("carved_x", "Carved X",
		"The X of the cell just written, inside On Cell Carved.",
		[], TYPE_INT)
	src.expression("carved_y", "Carved Y",
		"The Y of the cell just written, inside On Cell Carved.",
		[], TYPE_INT)
	src.expression("carved_value", "Carved Value",
		"The value just written into the cell, inside On Cell Carved.",
		[], TYPE_INT)
	src.expression("mark_x", "Mark X",
		"The X of the mark just placed, inside On Mark Placed.",
		[], TYPE_INT)
	src.expression("mark_y", "Mark Y",
		"The Y of the mark just placed, inside On Mark Placed.",
		[], TYPE_INT)
	src.expression("mark_tag", "Mark Tag",
		"The tag of the mark just placed, inside On Mark Placed.",
		[], TYPE_STRING)

	Lib.verb_sentences(src.sheet, {
		"create_grid": "start a new [b]{width}[/b] x [b]{height}[/b] grid",
		"clear_grid": "wipe every cell back to [b]{value}[/b]",
		"set_cell": "write [b]{value}[/b] into cell ([b]{x}[/b], [b]{y}[/b])",
		"set_origin": "put the grid's corner at ([b]{x}[/b], [b]{y}[/b]), cells [b]{new_cell_size}[/b] px",
		"draw_cells_to_tilemap": "paint every [b]{value}[/b] cell into [i]{layer}[/i] as tile ([b]{atlas_x}[/b], [b]{atlas_y}[/b]) of source [b]{source_id}[/b]",
		"set_seed": "seed the generator with [b]{seed_text}[/b]",
		"set_random_source": "draw randomness from [b]{source}[/b]",
		"inject_random": "queue [b]{value}[/b] for the injected stream",
		"add_walker": "add walker [b]{id}[/b] at ([b]{start_x}[/b], [b]{start_y}[/b]) - [b]{steps}[/b] steps, [b]{directions}[/b] headings, turning up to [b]{max_turn}[/b], tagged [b]{tag}[/b], carving [b]{carve_value}[/b]",
		"add_walker_from_preset": "add a [b]{preset}[/b] walker [b]{id}[/b] at ([b]{start_x}[/b], [b]{start_y}[/b]), tagged [b]{tag}[/b], carving [b]{carve_value}[/b]",
		"define_walker": "define a walker from [b]{definition}[/b]",
		"set_walker_carve_value": "walker [b]{id}[/b] carves [b]{value}[/b] from now on",
		"set_walker_steps": "give walker [b]{id}[/b] [b]{steps}[/b] steps left",
		"set_walker_turn_chance": "walker [b]{id}[/b] considers turning [b]{chance}[/b] of the time",
		"set_walker_brush_size": "walker [b]{id}[/b] stamps a [b]{size}[/b] cell square",
		"set_walker_start_angle": "point walker [b]{id}[/b]'s direction set at [b]{degrees}[/b] degrees",
		"set_walker_dig_size": "walker [b]{id}[/b] digs [b]{width}[/b] wide by [b]{depth}[/b] deep",
		"set_walker_direction_weights": "weight walker [b]{id}[/b]'s headings [b]{weights}[/b]",
		"remove_walker": "unregister walker [b]{id}[/b]",
		"run_all_walkers": "run every walker",
		"run_walkers_by_tag": "run the walkers tagged [b]{tag}[/b]",
		"run_walker": "run walker [b]{id}[/b]",
		"step_walker": "step walker [b]{id}[/b] on by [b]{steps}[/b]",
		"drop_marks_along_walk": "drop [b]{tag}[/b] marks along walker [b]{walker_id}[/b] every [b]{every_steps}[/b] steps, chance [b]{chance}[/b], spacing [b]{min_spacing}[/b]",
		"scatter_marks": "scatter [b]{count}[/b] [b]{tag}[/b] marks on [b]{value}[/b] cells, [b]{placement}[/b], spacing [b]{min_spacing}[/b]",
		"clear_marks": "forget the [b]{tag}[/b] marks",
		"dilate_cells": "grow the [b]{value}[/b] cells outward [b]{iterations}[/b] ring(s)",
		"outline_cells": "outline the [b]{value}[/b] cells with [b]{outline_value}[/b]",
		"load_state_from_text": "restore the generator from [b]{state}[/b]",
		"is_cell_value": "cell ([b]{x}[/b], [b]{y}[/b]) is [b]{value}[/b]",
		"is_inside_grid": "([b]{x}[/b], [b]{y}[/b]) is inside the grid",
		"has_mark_at": "a [b]{tag}[/b] mark sits on ([b]{x}[/b], [b]{y}[/b])",
		"has_walker": "walker [b]{id}[/b] is registered",
	})
	Lib.feature_verbs(src.sheet, ["create_grid", "set_seed", "add_walker", "add_walker_from_preset",
		"run_all_walkers", "step_walker", "scatter_marks", "outline_cells", "draw_cells_to_tilemap",
		"count_cells"])
	return Lib.publish(src, "res://eventsheet_addons/drunken_walkers/drunken_walkers_behavior")


## Sets the dropdown options[] on the last-declared verb's parameter, so the row offers the words
## it actually accepts instead of a free-text field somebody has to spell right.
static func _options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed
