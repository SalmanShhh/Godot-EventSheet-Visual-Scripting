## @ace_tags(procedural, generation, random, grid)
## @ace_category("Drunken Walkers")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/drunken_walkers/icon.svg")
class_name DrunkenWalkersAddon
extends Node
## A seeded grid generator as the DrunkenWalkers autoload: register walkers that stagger across a grid of integers carving caves, corridors, rivers and ore veins, scatter tagged marks with real spacing and placement rules, then read the result back as cells and marks. One seed string reproduces the whole map, placement included, on every machine.

## Fires once for every cell whose value actually CHANGES - during walker runs, Dilate Cells and
## Outline Cells. Carved X, Carved Y and Carved Value describe the cell; Walker ID names the walker
## responsible, and reads empty for the two post-processing passes. A walker re-crossing ground it
## already carved does not fire it again, because nothing changed.
## @ace_trigger
## @ace_name("On Cell Carved")
signal cell_carved(x: int, y: int, value: int, walker_id: String)
## Fires after each step of Step Walker, and ONLY from Step Walker - batch runs skip it on purpose
## so bulk generation stays fast. Walker X, Walker Y, Walker Angle and Walker Steps Left are all
## live inside it. Compare the walker id yourself to filter; an empty comparison matches them all.
## @ace_trigger
## @ace_name("On Walker Stepped")
signal walker_stepped(walker_id: String)
## Fires when a walker exhausts its step budget or runs out of legal moves. Walker X and Walker Y
## are its final cell, which is how one walker starts where another stopped.
## @ace_trigger
## @ace_name("On Walker Finished")
signal walker_finished(walker_id: String)
## Fires once per mark placed by Drop Marks Along Walk and Scatter Marks. Mark X, Mark Y and
## Mark Tag describe it.
## @ace_trigger
## @ace_name("On Mark Placed")
signal mark_placed(tag: String)
## Fires after a Run Walkers By Tag batch has finished every walker carrying that tag. Walker Tag
## holds the batch tag inside it.
## @ace_trigger
## @ace_name("On Walkers By Tag Complete")
signal walkers_by_tag_complete(tag: String)
## Fires after Run All Walkers has run every registered walker. The idiomatic place to scatter
## marks, outline the walls and paint the tilemap.
## @ace_trigger
## @ace_name("On Generation Complete")
signal generation_complete

## Grid width in cells. The grid is built at this size from the start, and this is the fallback Create Grid uses for a width of 0 or less.
@export_range(1, 2048, 1) var grid_width: int = 64
## Grid height in cells. The grid is built at this size from the start, and this is the fallback Create Grid uses for a height of 0 or less.
@export_range(1, 2048, 1) var grid_height: int = 64
## Hard cap on both axes. Create Grid clamps to it and says so in Debug Mode, so a bad expression fails loudly instead of reserving gigabytes.
@export_range(1, 8192, 1) var max_grid_size: int = 2048
## Pixel size of one cell. Used only by the four coordinate conversion expressions, never by generation itself.
@export_range(1, 512, 1) var cell_size: int = 32
## World X of the grid's top-left corner, for the coordinate expressions.
@export var origin_x: float = 0.0
## World Y of the grid's top-left corner, for the coordinate expressions.
@export var origin_y: float = 0.0
## The value a fresh grid is filled with. It is also what an out-of-bounds Cell Value reads, and the only value Outline Cells is allowed to overwrite.
@export var empty_value: int = 0
## The seed the generator starts on. Left empty it derives one from the clock and remembers it, so Current Seed can still show the player a code - but the first run of a session is not reproducible until you call Set Seed.
@export var start_seed: String = ""
## internal = this pack's own seeded generator. shared = the Advanced Random autoload, so one seed drives every procedural system at once. injected = the queue Inject Random fills, for one audited stream.
@export_enum("internal", "shared", "injected") var random_source: String = "internal"
## Warns about walker lifecycles, clamped grid sizes, scatters that could not fit, an injected queue running dry, and the four common reasons a map comes out empty. On while you build, off for release.
@export var debug_mode: bool = false

## The eight grid neighbours, clockwise from "right" (0 degrees right, 90 degrees down, which is
## Godot's own y-down screen sense). A heading picks its neighbour by ROUNDING THE DEGREES into
## this table rather than by taking a cosine, so the same heading picks the same neighbour on
## every platform a game exports to - which is the whole determinism promise in one line.
const NEIGHBOUR_STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]

## The six shape recipes Add Walker From Preset registers, by the name you pass it. The numbers are
## the recipe, not a suggestion: they are what the preset means, and every one of them is reachable
## afterwards through the Set Walker actions. "blob" is the one recipe written as a band (30 to 50
## steps), taken here at its midpoint so a preset is one concrete walker.
const PRESETS: Dictionary = {
	"cave": {"steps": 400, "directions": 8, "max_turn": 180.0, "turn_chance": 1.0,
		"brush_size": 1, "weights": ""},
	"corridors": {"steps": 400, "directions": 4, "max_turn": 90.0, "turn_chance": 0.15,
		"brush_size": 1, "weights": ""},
	"river": {"steps": 400, "directions": 3, "max_turn": 45.0, "turn_chance": 0.35,
		"brush_size": 2, "weights": ""},
	"ore vein": {"steps": 400, "directions": 8, "max_turn": 90.0, "turn_chance": 1.0,
		"brush_size": 1, "weights": "2,6,9,6,2,0,0,0"},
	"lightning": {"steps": 400, "directions": 8, "max_turn": 45.0, "turn_chance": 1.0,
		"brush_size": 1, "weights": "1,5,9,5,1,0,0,0"},
	"blob": {"steps": 40, "directions": 8, "max_turn": 180.0, "turn_chance": 1.0,
		"brush_size": 4, "weights": ""},
}

## The shape number Save State As Text stamps, so a state written by an older build is recognisable
## rather than silently misread.
const STATE_VERSION: int = 1

# One walker: where it is, where it is pointing, what it stamps, and how much of its budget is
# left. A walker is registered by Add Walker and does nothing at all until a Run or Step action
# asks it to move, which is why registering fifty of them costs nothing.
class Walker extends RefCounted:
	var id: String = ""
	var start_x: int = 0
	var start_y: int = 0
	var x: int = 0
	var y: int = 0
	var steps: int = 400
	var steps_left: int = 400
	var directions: int = 8
	var max_turn: float = 180.0
	var start_angle: float = 0.0
	var heading: float = 0.0
	var turn_chance: float = 1.0
	var carve_value: int = 1
	var brush_size: int = 1
	var brush_width: int = 0
	var brush_height: int = 0
	var weights: Array[float] = []
	var tag: String = ""
	var started: bool = false
	var finished: bool = false
	var border_rerolls: int = 0
	var path: Array[Vector2i] = []

	# The walker as one Dictionary: the DEFINITION keys Define Walker reads, plus the progress
	# keys a saved state needs. One shape does both jobs, so a walker saved mid-walk is also a
	# definition you can hand back to Define Walker.
	func to_dict() -> Dictionary:
		var flat_path: Array[int] = []
		for cell: Vector2i in path:
			flat_path.append(cell.x)
			flat_path.append(cell.y)
		return {
			"id": id, "startX": start_x, "startY": start_y, "steps": steps,
			"directions": directions, "maxTurn": max_turn, "startAngle": start_angle,
			"turnChance": turn_chance, "carveValue": carve_value, "brushSize": brush_size,
			"brushWidth": brush_width, "brushHeight": brush_height,
			"weights": weights.duplicate(), "tag": tag,
			"x": x, "y": y, "heading": heading, "stepsLeft": steps_left,
			"started": started, "finished": finished, "borderRerolls": border_rerolls,
			"path": flat_path,
		}

	# The progress half of the shape, applied over a walker whose definition has already been read.
	func apply_progress(data: Dictionary) -> void:
		x = int(data.get("x", start_x))
		y = int(data.get("y", start_y))
		heading = float(data.get("heading", start_angle))
		steps_left = int(data.get("stepsLeft", steps))
		started = bool(data.get("started", false))
		finished = bool(data.get("finished", false))
		border_rerolls = int(data.get("borderRerolls", 0))
		path.clear()
		var flat: Array = data.get("path", []) as Array
		var index: int = 0
		while index + 1 < flat.size():
			path.append(Vector2i(int(flat[index]), int(flat[index + 1])))
			index += 2

# The grid: one flat row-major buffer of integers plus its two dimensions. Every cell holds one
# number and nothing else, which is what keeps this fast and lets any art pipeline read it.
var _cells: PackedInt32Array = PackedInt32Array()
var _width: int = 0
var _height: int = 0

# The walkers, by id, plus the REGISTRATION ORDER they run in. Re-using an id replaces the walker
# without moving it in that order, because the order is part of the seed.
var _walkers: Dictionary = {}
var _order: Array[String] = []

# The marks, in placement order: {"x": int, "y": int, "tag": String}.
var _marks: Array[Dictionary] = []

# The one seeded stream everything draws from, and the seed string it was last set with.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed_text: String = ""

# The injected queue and how far into it generation has read. Injected values are consumed in
# order; a head index rather than a pop keeps the queue cheap and makes the remaining count exact.
var _injected: Array[float] = []
var _injected_head: int = 0
var _injected_underran: bool = false

# The context the trigger expressions read. Each one is set immediately before its trigger emits
# and put back afterwards, so Walker X outside a walker trigger is 0 rather than stale.
var _ctx_walker_id: String = ""
var _ctx_walker_tag: String = ""
var _ctx_walker_x: int = 0
var _ctx_walker_y: int = 0
var _ctx_walker_angle: float = 0.0
var _ctx_walker_steps_left: int = 0
var _ctx_carved_x: int = 0
var _ctx_carved_y: int = 0
var _ctx_carved_value: int = 0
var _ctx_mark_x: int = 0
var _ctx_mark_y: int = 0
var _ctx_mark_tag: String = ""

# Cell lookups, cached per value and dropped the moment any cell changes. Count Cells plus the two
# index expressions is the fast path for painting a map, and it is only fast if asking for the
# hundredth cell does not walk the grid for the hundredth time.
var _index_cache: Dictionary = {}

# The grid exists from the moment the object does, so Cell Value and the grid conditions answer
# from the first frame. This flag is set by the one function that does the whole start-up.
var _started: bool = false
## The neighbour a heading resolves to. Degrees in, one of the eight grid neighbours out.
## @ace_hidden
func _heading_step(heading: float) -> Vector2i:
	var octant: int = int(round(fposmod(heading, 360.0) / 45.0)) % 8
	return NEIGHBOUR_STEPS[octant]
## The directions reachable from `from_heading` this step: the members of the direction set whose
## heading is within Max Turn of where the walker is already pointing. This is the difference
## between a scribble and a path, and it is why two directions with a small max turn draw a
## straight line - the other heading is 180 degrees away and simply out of reach.
## @ace_hidden
func _reachable(walker: Walker, from_heading: float) -> Array[int]:
	var found: Array[int] = []
	for index: int in maxi(1, walker.directions):
		var gap: float = fmod(absf(_heading_of(walker, index) - fposmod(from_heading, 360.0)), 360.0)
		if gap > 180.0:
			gap = 360.0 - gap
		if gap <= walker.max_turn + 0.000001:
			found.append(index)
	return found
## Every member of the walker's direction set, by index. The pool the border re-roll widens to
## when Max Turn has left it nothing in bounds to pick.
## @ace_hidden
func _all_headings(walker: Walker) -> Array[int]:
	var found: Array[int] = []
	for index: int in maxi(1, walker.directions):
		found.append(index)
	return found
## Those of `choices` whose step would land inside the grid. Kept apart from the border re-roll
## so the narrowed pool and the widened one are filtered by one rule rather than two.
## @ace_hidden
func _in_bounds(walker: Walker, choices: Array[int]) -> Array[int]:
	var legal: Array[int] = []
	for index: int in choices:
		var candidate: Vector2i = _heading_step(_heading_of(walker, index))
		if _inside(walker.x + candidate.x, walker.y + candidate.y):
			legal.append(index)
	return legal
## The cells holding a value, as linear indices in a stable left-to-right, top-to-bottom order.
## Cached until the next write, because painting a map asks for this once per cell.
## @ace_hidden
func _cells_holding(value: int) -> PackedInt32Array:
	if _index_cache.has(value):
		return _index_cache[value] as PackedInt32Array
	var found: PackedInt32Array = PackedInt32Array()
	for index: int in _cells.size():
		if _cells[index] == value:
			found.append(index)
	_index_cache[value] = found
	return found
## A weights list from the comma-separated spelling the action takes. An empty string restores
## equal weights, negatives floor to 0, and anything that is not a number falls back to 1.
## @ace_hidden
func _weights_from_text(text: String) -> Array[float]:
	var parsed: Array[float] = []
	if text.strip_edges().is_empty():
		return parsed
	for part: String in text.split(","):
		var piece: String = part.strip_edges()
		parsed.append(maxf(0.0, piece.to_float()) if piece.is_valid_float() else 1.0)
	return parsed
## A weights list from a JSON array, under the same rules as the text spelling.
## @ace_hidden
func _weights_from_array(values: Array) -> Array[float]:
	var parsed: Array[float] = []
	for entry: Variant in values:
		if entry is float or entry is int:
			parsed.append(maxf(0.0, float(entry)))
		else:
			parsed.append(1.0)
	return parsed
## Registers a walker under an id, keeping its place in the run order when the id is already
## taken - because the run order is part of the seed, and replacing a walker must not reshuffle
## the map. Returns the walker so the caller can fill in the rest of the definition.
## @ace_hidden
func _register(id: String) -> Walker:
	var walker: Walker = Walker.new()
	walker.id = id
	if not _walkers.has(id):
		_order.append(id)
	_walkers[id] = walker
	return walker
## The registered walker, or null. Every Set Walker action warns by name through this one door in
## debug mode, so a typo in an id says so instead of doing nothing.
## @ace_hidden
func _walker(id: String) -> Walker:
	if _walkers.has(id):
		return _walkers[id] as Walker
	if debug_mode:
		push_warning("Drunken Walkers: there is no walker called '%s' registered." % id)
	return null

func _ready() -> void:
	_ensure_started()

## @ace_action
## @ace_featured
## @ace_name("Create Grid")
## @ace_category("Drunken Walkers")
## @ace_description("Allocates a fresh grid filled with the Empty Value, clamped to Max Grid Size. Only needed for a size other than the Grid Width / Grid Height properties, because that grid already exists from the start. A width or height of 0 or less falls back to its property. Destroys the previous grid, every registered walker and every mark - it is "start a new level". The seed is not touched.")
## @ace_display_template("start a new [b]{width}[/b] x [b]{height}[/b] grid")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.create_grid({width}, {height})")
func create_grid(width: int, height: int) -> void:
	_ensure_started()
	var cap: int = maxi(1, max_grid_size)
	var new_width: int = width
	var new_height: int = height
	if new_width == 0 or new_height == 0:
		# A grid with no cells is never what anyone meant, so 0 is read as a mistake rather than
		# as a request, and falls back to the property exactly as a negative does.
		if debug_mode:
			push_warning("Drunken Walkers: Create Grid was given a 0 dimension, so the Grid Width / Grid Height property was used instead.")
	if new_width <= 0:
		new_width = grid_width
	if new_height <= 0:
		new_height = grid_height
	if new_width > cap or new_height > cap:
		if debug_mode:
			push_warning("Drunken Walkers: Create Grid clamped %d x %d to the Max Grid Size of %d." % [
				new_width, new_height, cap])
		new_width = mini(new_width, cap)
		new_height = mini(new_height, cap)
	_allocate(new_width, new_height)
	# Destructive on purpose: this is "start a new level", so the walkers and marks of the last
	# one go with it. The seed is NOT touched, so re-creating a grid does not disturb the stream.
	_walkers.clear()
	_order.clear()
	_marks.clear()

## @ace_action
## @ace_name("Clear Grid")
## @ace_category("Drunken Walkers")
## @ace_description("Refills every cell with a value you choose. Walkers, marks and the random stream are left alone, and it does not fire On Cell Carved. Use it to re-run the same walkers over a blank slate without re-registering them.")
## @ace_display_template("wipe every cell back to [b]{value}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.clear_grid({value})")
func clear_grid(value: int) -> void:
	_ensure_started()
	_cells.fill(value)
	_index_cache.clear()

## @ace_action
## @ace_name("Set Cell")
## @ace_category("Drunken Walkers")
## @ace_description("Writes one cell directly. Deliberately silent: it does not fire On Cell Carved, which makes it the right tool for pre-placing anchors like a guaranteed entrance or a boss room before the walkers run.")
## @ace_display_template("write [b]{value}[/b] into cell ([b]{x}[/b], [b]{y}[/b])")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_cell({x}, {y}, {value})")
func set_cell(x: int, y: int, value: int) -> void:
	_ensure_started()
	if not _inside(x, y):
		return
	_cells[y * _width + x] = value
	_index_cache.clear()

## @ace_action
## @ace_name("Set Origin")
## @ace_category("Drunken Walkers")
## @ace_description("Moves the grid in world space and optionally changes the cell size, for the four coordinate expressions. Pass 0 for the cell size to keep the current one.")
## @ace_display_template("put the grid's corner at ([b]{x}[/b], [b]{y}[/b]), cells [b]{new_cell_size}[/b] px")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_origin({x}, {y}, {new_cell_size})")
func set_origin(x: float, y: float, new_cell_size: int) -> void:
	origin_x = x
	origin_y = y
	if new_cell_size != 0:
		cell_size = maxi(1, new_cell_size)

## @ace_action
## @ace_featured
## @ace_name("Draw Cells To Tilemap")
## @ace_category("Drunken Walkers")
## @ace_description("Paints one tile into a TileMapLayer for every cell holding a value, replacing the whole paint loop. Cell coordinates map straight onto tile coordinates. Call it once per value; a source id of -1 erases those tiles instead.")
## @ace_display_template("paint every [b]{value}[/b] cell into [i]{layer}[/i] as tile ([b]{atlas_x}[/b], [b]{atlas_y}[/b]) of source [b]{source_id}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.draw_cells_to_tilemap({layer}, {value}, {source_id}, {atlas_x}, {atlas_y})")
func draw_cells_to_tilemap(layer: TileMapLayer, value: int, source_id: int, atlas_x: int, atlas_y: int) -> void:
	_ensure_started()
	if layer == null:
		if debug_mode:
			push_warning("Drunken Walkers: Draw Cells To Tilemap was given no TileMapLayer, so nothing was painted.")
		return
	for index: int in _cells_holding(value):
		layer.set_cell(Vector2i(index % _width, index / _width), source_id, Vector2i(atlas_x, atlas_y))

## @ace_action
## @ace_featured
## @ace_name("Set Seed")
## @ace_category("Drunken Walkers")
## @ace_description("Resets the generator from a seed string. Call it BEFORE generating: the same seed with the same action order reproduces identical output, and calling it afterwards changes nothing about the map you just built. It does not clear the grid.")
## @ace_display_template("seed the generator with [b]{seed_text}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_seed({seed_text})")
func set_seed(seed_text: String) -> void:
	_ensure_started()
	_seed_text = seed_text
	_rng.seed = hash(seed_text)
	# Set Seed resets the stream and NOTHING ELSE. The grid, the walkers and the marks are left
	# exactly as they are, so you can re-seed and re-run without reallocating anything.

## @ace_action
## @ace_name("Set Random Source")
## @ace_category("Drunken Walkers")
## @ace_description("Switches where every decision draws from: this pack's own seeded generator, the shared Advanced Random autoload, or the injected queue Inject Random fills. You may switch mid-run, so one pass can audit through a single stream while the rest does not.")
## @ace_display_template("draw randomness from [b]{source}[/b]")
## @ace_param_options(source internal=Internal seeded, shared=Shared Advanced Random, injected=Injected queue)
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_random_source({source})")
func set_random_source(source: String) -> void:
	var wanted: String = source.strip_edges().to_lower()
	if wanted in ["internal", "shared", "injected"]:
		random_source = wanted
		_injected_underran = false
		return
	if debug_mode:
		push_warning("Drunken Walkers: '%s' is not a random source. Use internal, shared or injected." % source)

## @ace_action
## @ace_name("Inject Random")
## @ace_category("Drunken Walkers")
## @ace_description("Queues one value between 0 and 1 for the injected source, generation consuming them in order. Budget roughly two per walker step plus one per mark candidate. A queue that runs dry falls back to the internal generator rather than failing, and says so in Debug Mode.")
## @ace_display_template("queue [b]{value}[/b] for the injected stream")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.inject_random({value})")
func inject_random(value: float) -> void:
	_injected.append(clampf(value, 0.0, 1.0))

## @ace_action
## @ace_featured
## @ace_name("Add Walker")
## @ace_category("Drunken Walkers")
## @ace_description("Registers a walker with the eight settings you change most: where it starts, how many steps it has, how many headings it may face (1 to 8), how far it may turn in one step, its tag and the value it carves. Everything else takes its default. Re-using an id replaces that walker without moving it in the run order.")
## @ace_display_template("add walker [b]{id}[/b] at ([b]{start_x}[/b], [b]{start_y}[/b]) - [b]{steps}[/b] steps, [b]{directions}[/b] headings, turning up to [b]{max_turn}[/b], tagged [b]{tag}[/b], carving [b]{carve_value}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.add_walker({id}, {start_x}, {start_y}, {steps}, {directions}, {max_turn}, {tag}, {carve_value})")
func add_walker(id: String, start_x: int, start_y: int, steps: int, directions: int, max_turn: float, tag: String, carve_value: int) -> void:
	_ensure_started()
	var walker: Walker = _register(id)
	walker.start_x = start_x
	walker.start_y = start_y
	walker.x = start_x
	walker.y = start_y
	walker.steps = maxi(0, steps)
	walker.steps_left = walker.steps
	walker.directions = clampi(directions, 1, 8)
	walker.max_turn = clampf(max_turn, 0.0, 180.0)
	walker.tag = tag
	walker.carve_value = carve_value

## @ace_action
## @ace_featured
## @ace_name("Add Walker From Preset")
## @ace_category("Drunken Walkers")
## @ace_description("Registers a walker from a named shape recipe - Cave, Corridors, River, Ore Vein, Lightning or Blob - so you only need a position, a tag and a carve value. Tune it afterwards with the Set Walker actions.")
## @ace_display_template("add a [b]{preset}[/b] walker [b]{id}[/b] at ([b]{start_x}[/b], [b]{start_y}[/b]), tagged [b]{tag}[/b], carving [b]{carve_value}[/b]")
## @ace_param_options(preset cave=Cave, corridors=Corridors, river=River, ore_vein=Ore Vein, lightning=Lightning, blob=Blob)
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.add_walker_from_preset({preset}, {id}, {start_x}, {start_y}, {tag}, {carve_value})")
func add_walker_from_preset(preset: String, id: String, start_x: int, start_y: int, tag: String, carve_value: int) -> void:
	_ensure_started()
	var recipe_name: String = preset.strip_edges().to_lower().replace("_", " ")
	if not PRESETS.has(recipe_name):
		if debug_mode:
			push_warning("Drunken Walkers: '%s' is not a shape recipe. Use cave, corridors, river, ore vein, lightning or blob." % preset)
		return
	var recipe: Dictionary = PRESETS[recipe_name] as Dictionary
	var walker: Walker = _register(id)
	walker.start_x = start_x
	walker.start_y = start_y
	walker.x = start_x
	walker.y = start_y
	walker.steps = int(recipe["steps"])
	walker.steps_left = walker.steps
	walker.directions = int(recipe["directions"])
	walker.max_turn = float(recipe["max_turn"])
	walker.turn_chance = float(recipe["turn_chance"])
	walker.brush_size = int(recipe["brush_size"])
	walker.weights = _weights_from_text(str(recipe["weights"]))
	walker.tag = tag
	walker.carve_value = carve_value

## @ace_action
## @ace_name("Define Walker")
## @ace_category("Drunken Walkers")
## @ace_description("Registers a walker from a whole JSON definition in one string, which suits definitions that live in a data file or a level editor. Anything you leave out takes its default. Both spellings of every field are accepted, so startX and start_x both work.")
## @ace_display_template("define a walker from [b]{definition}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.define_walker({definition})")
func define_walker(definition: String) -> void:
	_ensure_started()
	var parsed: Variant = JSON.parse_string(definition)
	if not (parsed is Dictionary):
		if debug_mode:
			push_warning("Drunken Walkers: this walker definition is not JSON an object could be read from, so the walker was skipped: %s" % definition)
		return
	var data: Dictionary = parsed as Dictionary
	var id: String = str(_field(data, "id", "id", ""))
	if id.is_empty():
		if debug_mode:
			push_warning("Drunken Walkers: a walker definition with no id was skipped: %s" % definition)
		return
	var walker: Walker = _register(id)
	walker.start_x = int(_field(data, "startX", "start_x", 0))
	walker.start_y = int(_field(data, "startY", "start_y", 0))
	walker.steps = maxi(0, int(_field(data, "steps", "steps", 400)))
	walker.directions = clampi(int(_field(data, "directions", "directions", 8)), 1, 8)
	walker.max_turn = clampf(float(_field(data, "maxTurn", "max_turn", 180.0)), 0.0, 180.0)
	walker.start_angle = float(_field(data, "startAngle", "start_angle", 0.0))
	walker.turn_chance = clampf(float(_field(data, "turnChance", "turn_chance", 1.0)), 0.0, 1.0)
	walker.carve_value = int(_field(data, "carveValue", "carve_value", 1))
	walker.brush_size = maxi(1, int(_field(data, "brushSize", "brush_size", 1)))
	walker.brush_width = int(_field(data, "brushWidth", "brush_width", 0))
	walker.brush_height = int(_field(data, "brushHeight", "brush_height", 0))
	walker.tag = str(_field(data, "tag", "tag", ""))
	var weights: Variant = _field(data, "weights", "weights", [])
	walker.weights = _weights_from_array(weights as Array) if weights is Array else _weights_from_text(str(weights))
	walker.x = walker.start_x
	walker.y = walker.start_y
	walker.heading = walker.start_angle
	walker.steps_left = walker.steps

## @ace_action
## @ace_name("Set Walker Carve Value")
## @ace_category("Drunken Walkers")
## @ace_description("Changes the integer an existing walker writes into the cells it visits. It applies from that walker's next step, so anything already carved keeps its old value - which is how one walker lays down two materials along one path.")
## @ace_display_template("walker [b]{id}[/b] carves [b]{value}[/b] from now on")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_walker_carve_value({id}, {value})")
func set_walker_carve_value(id: String, value: int) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		# Applies from the walker's next step, so anything already carved keeps its old value.
		# That is the point: change it mid-walk and one walker lays down two materials.
		walker.carve_value = value

## @ace_action
## @ace_name("Set Walker Steps")
## @ace_category("Drunken Walkers")
## @ace_description("Sets a walker's REMAINING step budget, and un-finishes a finished walker, so topping one up and running it again extends the path it already drew.")
## @ace_display_template("give walker [b]{id}[/b] [b]{steps}[/b] steps left")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_walker_steps({id}, {steps})")
func set_walker_steps(id: String, steps: int) -> void:
	var walker: Walker = _walker(id)
	if walker == null:
		return
	# The value becomes the REMAINING budget and un-finishes a finished walker, so topping a
	# walker up and running it again extends the path it already drew.
	walker.steps_left = maxi(0, steps)
	walker.steps = maxi(walker.steps, walker.steps_left)
	if walker.steps_left > 0:
		walker.finished = false

## @ace_action
## @ace_name("Set Walker Turn Chance")
## @ace_category("Drunken Walkers")
## @ace_description("Sets the 0 to 1 probability that a walker even considers turning on a given step. At 1 the heading performs its own random walk and the path curls; around 0.15 to 0.3 is what actually reads as a road or a river.")
## @ace_display_template("walker [b]{id}[/b] considers turning [b]{chance}[/b] of the time")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_walker_turn_chance({id}, {chance})")
func set_walker_turn_chance(id: String, chance: float) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		walker.turn_chance = clampf(chance, 0.0, 1.0)

## @ace_action
## @ace_name("Set Walker Brush Size")
## @ace_category("Drunken Walkers")
## @ace_description("Sets the square block a walker stamps each step. 1 is a single cell, 3 is a centred 3x3. It never rotates, so it is right for blobby caves and wrong for corridors - use the dig size for those. Ignored while a dig size is set.")
## @ace_display_template("walker [b]{id}[/b] stamps a [b]{size}[/b] cell square")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_walker_brush_size({id}, {size})")
func set_walker_brush_size(id: String, size: int) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		walker.brush_size = maxi(1, size)

## @ace_action
## @ace_name("Set Walker Start Angle")
## @ace_category("Drunken Walkers")
## @ace_description("Rotates the walker's whole direction set to a new anchor angle, in degrees, 0 being right and 90 down. The direction weights rotate with it, because weight entry 0 always weighs the start angle.")
## @ace_display_template("point walker [b]{id}[/b]'s direction set at [b]{degrees}[/b] degrees")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_walker_start_angle({id}, {degrees})")
func set_walker_start_angle(id: String, degrees: float) -> void:
	var walker: Walker = _walker(id)
	if walker == null:
		return
	# The whole direction set rotates, and the current heading rotates with it, so the walker
	# keeps pointing where it was pointing relative to its own set. The weights rotate too,
	# because entry 0 always weighs the start angle.
	walker.heading = fposmod(walker.heading + degrees - walker.start_angle, 360.0)
	walker.start_angle = fposmod(degrees, 360.0)

## @ace_action
## @ace_name("Set Walker Dig Size")
## @ace_category("Drunken Walkers")
## @ace_description("Swaps the square brush for a rectangle that TURNS WITH THE WALKER. Width is measured across the heading and is always centred, so a corridor keeps its width around every corner. Depth is measured along the heading and is signed: positive digs ahead of the walker, negative digs behind it. 0 on an axis falls back to the brush size, and 0 on both restores the square brush.")
## @ace_display_template("walker [b]{id}[/b] digs [b]{width}[/b] wide by [b]{depth}[/b] deep")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_walker_dig_size({id}, {width}, {depth})")
func set_walker_dig_size(id: String, width: int, depth: int) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		# 0 on an axis falls back to the square brush for that axis, and 0 on both restores the
		# plain square brush - so this action is a toggle rather than a one-way door.
		walker.brush_width = width
		walker.brush_height = depth

## @ace_action
## @ace_name("Set Walker Direction Weights")
## @ace_category("Drunken Walkers")
## @ace_description("Biases which heading a walker turns toward, as a comma separated list of relative weights in direction order starting at the start angle. A 0 rules that heading out, a missing entry counts as 1, extra entries are ignored, and an empty string restores equal weights.")
## @ace_display_template("weight walker [b]{id}[/b]'s headings [b]{weights}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.set_walker_direction_weights({id}, {weights})")
func set_walker_direction_weights(id: String, weights: String) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		walker.weights = _weights_from_text(weights)

## @ace_action
## @ace_name("Remove Walker")
## @ace_category("Drunken Walkers")
## @ace_description("Unregisters a walker. Everything it already carved stays exactly as it is, because carving writes into the grid as it happens rather than being replayed at the end.")
## @ace_display_template("unregister walker [b]{id}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.remove_walker({id})")
func remove_walker(id: String) -> void:
	if not _walkers.has(id):
		return
	# Cells it already carved stay exactly as they are, because carving writes into the grid as
	# it happens rather than being replayed at the end.
	_walkers.erase(id)
	_order.erase(id)

## @ace_action
## @ace_featured
## @ace_name("Run All Walkers")
## @ace_category("Drunken Walkers")
## @ace_description("Runs every registered walker to the end of its budget, in registration order, then fires On Generation Complete. This is the whole generation in one row.")
## @ace_display_template("run every walker")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.run_all_walkers()")
func run_all_walkers() -> void:
	_ensure_started()
	if debug_mode and _order.is_empty():
		push_warning("Drunken Walkers: Run All Walkers ran with no walkers registered, so the grid is unchanged.")
	var running: Array[String] = _order.duplicate()
	var unfinished: int = 0
	for id: String in running:
		var walker: Walker = _walkers.get(id) as Walker
		if walker == null:
			continue
		if not walker.finished:
			unfinished += 1
		_run_to_end(walker)
	if debug_mode and not running.is_empty() and unfinished == 0:
		push_warning("Drunken Walkers: every registered walker had already finished, so Run All Walkers carved nothing. Set Walker Steps tops one up.")
	generation_complete.emit()

## @ace_action
## @ace_name("Run Walkers By Tag")
## @ace_category("Drunken Walkers")
## @ace_description("Runs only the walkers carrying a tag, in registration order, then fires On Walkers By Tag Complete. Staging generation in tagged passes is how a later pass reacts to what an earlier one carved. An empty tag is not a wildcard here: it runs the walkers that genuinely have no tag.")
## @ace_display_template("run the walkers tagged [b]{tag}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.run_walkers_by_tag({tag})")
func run_walkers_by_tag(tag: String) -> void:
	_ensure_started()
	var matched: int = 0
	for id: String in _order.duplicate():
		var walker: Walker = _walkers.get(id) as Walker
		# An empty tag is NOT a wildcard here: it runs the walkers that genuinely have no tag.
		if walker == null or walker.tag != tag:
			continue
		matched += 1
		_run_to_end(walker)
	if debug_mode and matched == 0:
		push_warning("Drunken Walkers: no registered walker carries the tag '%s', so Run Walkers By Tag carved nothing." % tag)
	_ctx_walker_tag = tag
	walkers_by_tag_complete.emit(tag)
	_ctx_walker_tag = ""

## @ace_action
## @ace_name("Run Walker")
## @ace_category("Drunken Walkers")
## @ace_description("Runs one walker by id to the end of its budget. It fires On Cell Carved and On Walker Finished but deliberately NOT On Generation Complete, because it is one pass of a bigger generation rather than the end of it.")
## @ace_display_template("run walker [b]{id}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.run_walker({id})")
func run_walker(id: String) -> void:
	_ensure_started()
	var walker: Walker = _walker(id)
	if walker != null:
		# One walker, to the end of its budget. On Generation Complete is deliberately NOT fired:
		# this is one pass of a bigger generation, not the end of it.
		_run_to_end(walker)

## @ace_action
## @ace_featured
## @ace_name("Step Walker")
## @ace_category("Drunken Walkers")
## @ace_description("Advances one walker by up to this many steps instead of running it out, firing On Walker Stepped per step - the row that makes the map draw itself in front of the player. The walk is identical to an instant run, just spread over time. The first call carves the start cell, so nothing has to place the walker first.")
## @ace_display_template("step walker [b]{id}[/b] on by [b]{steps}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.step_walker({id}, {steps})")
func step_walker(id: String, steps: int) -> void:
	_ensure_started()
	var walker: Walker = _walker(id)
	if walker == null:
		return
	for _index: int in maxi(0, steps):
		if not _advance(walker, true):
			return

## @ace_action
## @ace_name("Drop Marks Along Walk")
## @ace_category("Drunken Walkers")
## @ace_description("Replays a walker's recorded path and considers a candidate every N steps, keeping each with the given chance and rejecting it if it lands too close to an existing mark of the same tag. The walker must have run already, because the path is recorded as it walks. Candidates start at step N, not at the start cell.")
## @ace_display_template("drop [b]{tag}[/b] marks along walker [b]{walker_id}[/b] every [b]{every_steps}[/b] steps, chance [b]{chance}[/b], spacing [b]{min_spacing}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.drop_marks_along_walk({walker_id}, {tag}, {every_steps}, {chance}, {min_spacing})")
func drop_marks_along_walk(walker_id: String, tag: String, every_steps: int, chance: float, min_spacing: float) -> void:
	_ensure_started()
	var walker: Walker = _walker(walker_id)
	if walker == null:
		return
	var stride: int = maxi(1, every_steps)
	var placed: int = 0
	var candidates: int = 0
	# Candidates start at step N rather than at the walk's start cell, so the first possible mark
	# appears after the walker has actually travelled.
	var index: int = stride
	while index < walker.path.size():
		candidates += 1
		var cell: Vector2i = walker.path[index]
		# The chance is rolled per candidate even when it is 1, so tuning it moves this decision
		# and leaves every later draw in the stream where it was.
		if _next_random() < chance and _spacing_allows(cell.x, cell.y, tag, min_spacing):
			_place_mark(cell.x, cell.y, tag)
			placed += 1
		index += stride
	if debug_mode:
		push_warning("Drunken Walkers: Drop Marks Along Walk considered %d candidate(s) along '%s' and placed %d '%s' mark(s)." % [
			candidates, walker_id, placed, tag])

## @ace_action
## @ace_featured
## @ace_name("Scatter Marks")
## @ace_category("Drunken Walkers")
## @ace_description("Places up to this many tagged marks on cells holding a value, filtered by the placement rule and thinned by minimum spacing. The count is a maximum, not a promise: tight spacing or a rule that matches almost nothing places fewer, and Debug Mode says how many it managed.")
## @ace_display_template("scatter [b]{count}[/b] [b]{tag}[/b] marks on [b]{value}[/b] cells, [b]{placement}[/b], spacing [b]{min_spacing}[/b]")
## @ace_param_options(placement any=Any cell, interior=Interior only, edge=Edge only)
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.scatter_marks({count}, {tag}, {value}, {placement}, {min_spacing})")
func scatter_marks(count: int, tag: String, value: int, placement: String, min_spacing: float) -> void:
	_ensure_started()
	var rule: String = placement.strip_edges().to_lower()
	var eligible: Array[Vector2i] = []
	for index: int in _cells_holding(value):
		var x: int = index % _width
		var y: int = index / _width
		if _placement_allows(x, y, value, rule):
			eligible.append(Vector2i(x, y))
	var placed: int = 0
	# One value per EXAMINED candidate, and every examined candidate leaves the pool, so the pass
	# always ends: either it has placed what you asked for, or it has run out of room.
	while placed < count and not eligible.is_empty():
		var pick: int = mini(int(_next_random() * float(eligible.size())), eligible.size() - 1)
		var cell: Vector2i = eligible[pick]
		eligible[pick] = eligible[eligible.size() - 1]
		eligible.resize(eligible.size() - 1)
		if _spacing_allows(cell.x, cell.y, tag, min_spacing):
			_place_mark(cell.x, cell.y, tag)
			placed += 1
	if debug_mode and placed < count:
		push_warning("Drunken Walkers: Scatter Marks placed %d of the %d '%s' mark(s) asked for - the spacing, the placement rule or the space available ran out first." % [
			placed, count, tag])

## @ace_action
## @ace_name("Clear Marks")
## @ace_category("Drunken Walkers")
## @ace_description("Removes every mark carrying a tag, an empty tag removing all of them. The grid is untouched, so clearing marks and re-scattering only re-rolls the placement.")
## @ace_display_template("forget the [b]{tag}[/b] marks")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.clear_marks({tag})")
func clear_marks(tag: String) -> void:
	# An empty tag clears them all. The grid is untouched either way, so clearing marks and
	# re-scattering is cheap.
	if tag.is_empty():
		_marks.clear()
		return
	var kept: Array[Dictionary] = []
	for mark: Dictionary in _marks:
		if str(mark["tag"]) != tag:
			kept.append(mark)
	_marks = kept

## @ace_action
## @ace_name("Dilate Cells")
## @ace_category("Drunken Walkers")
## @ace_description("Grows every region of a value outward by one ring per iteration, which is how one-cell corridors become chambers. It converts ANY neighbouring cell, including ones holding other values, so dilate before you carve terrain you want to keep. Each iteration works from a snapshot, so one pass grows exactly one ring.")
## @ace_display_template("grow the [b]{value}[/b] cells outward [b]{iterations}[/b] ring(s)")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.dilate_cells({value}, {iterations})")
func dilate_cells(value: int, iterations: int) -> void:
	_ensure_started()
	for _pass: int in maxi(1, iterations):
		# Each iteration is computed from a SNAPSHOT, so one pass grows exactly one ring rather
		# than smearing across the grid in the scan direction.
		var before: PackedInt32Array = _cells.duplicate()
		for index: int in before.size():
			if before[index] == value:
				continue
			var x: int = index % _width
			var y: int = index / _width
			for step: Vector2i in NEIGHBOUR_STEPS:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if _inside(nx, ny) and before[ny * _width + nx] == value:
					# Any neighbouring cell is converted, whatever value it held, so dilating
					# floor eats into water where they touch. Dilate before you carve terrain
					# you want to keep.
					_write(x, y, value, "")
					break

## @ace_action
## @ace_featured
## @ace_name("Outline Cells")
## @ace_category("Drunken Walkers")
## @ace_description("Writes an outline value into every Empty Value cell touching a cell of the target value - the classic walls-around-the-floor pass. Unlike dilation it only ever overwrites the Empty Value, so water and ore survive it, which makes it safe to run last.")
## @ace_display_template("outline the [b]{value}[/b] cells with [b]{outline_value}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.outline_cells({value}, {outline_value})")
func outline_cells(value: int, outline_value: int) -> void:
	_ensure_started()
	var before: PackedInt32Array = _cells.duplicate()
	for index: int in before.size():
		# Only ever overwrites the Empty Value, so an outline pass never eats water, ore or any
		# other terrain, which is what makes it safe to run last.
		if before[index] != empty_value:
			continue
		var x: int = index % _width
		var y: int = index / _width
		for step: Vector2i in NEIGHBOUR_STEPS:
			var nx: int = x + step.x
			var ny: int = y + step.y
			if _inside(nx, ny) and before[ny * _width + nx] == value:
				_write(x, y, outline_value, "")
				break

## @ace_action
## @ace_name("Load State From Text")
## @ace_category("Drunken Walkers")
## @ace_description("Restores a whole generator from the text Save State As Text produced: the grid, the origin and cell size, the seed, the random stream's own position, every walker with its progress and recorded path, and every mark. Restoring is SILENT - no On Cell Carved and no On Mark Placed - so repaint from Count Cells and the index expressions afterwards.")
## @ace_display_template("restore the generator from [b]{state}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.load_state_from_text({state})")
func load_state_from_text(state: String) -> void:
	var parsed: Variant = JSON.parse_string(state)
	if not (parsed is Dictionary):
		if debug_mode:
			push_warning("Drunken Walkers: Load State From Text was given something that is not a saved state, so nothing was restored.")
		return
	load_state(parsed as Dictionary)

## @ace_condition
## @ace_name("Is Cell Value")
## @ace_category("Drunken Walkers")
## @ace_description("True when the cell holds exactly that value. Stricter than the Cell Value expression: an out-of-bounds cell matches nothing, not even the Empty Value, which is what lets you test the border honestly.")
## @ace_display_template("cell ([b]{x}[/b], [b]{y}[/b]) is [b]{value}[/b]")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.is_cell_value({x}, {y}, {value})")
func is_cell_value(x: int, y: int, value: int) -> bool:
	_ensure_started()
	# Stricter than the Cell Value expression on purpose: an out-of-bounds cell matches NOTHING,
	# not even the Empty Value, which is what lets you test the border honestly.
	return _inside(x, y) and _cells[y * _width + x] == value

## @ace_condition
## @ace_name("Is Inside Grid")
## @ace_category("Drunken Walkers")
## @ace_description("True when the X and Y fall inside the current grid. Guard anything built from Layout To X / Layout To Y with it, because a point on screen may simply not be over the grid.")
## @ace_display_template("([b]{x}[/b], [b]{y}[/b]) is inside the grid")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.is_inside_grid({x}, {y})")
func is_inside_grid(x: int, y: int) -> bool:
	_ensure_started()
	return _inside(x, y)

## @ace_condition
## @ace_name("Has Mark At")
## @ace_category("Drunken Walkers")
## @ace_description("True when a mark with the tag sits on that cell. An empty tag matches any mark, which is the quick way to ask whether anything is already here.")
## @ace_display_template("a [b]{tag}[/b] mark sits on ([b]{x}[/b], [b]{y}[/b])")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.has_mark_at({x}, {y}, {tag})")
func has_mark_at(x: int, y: int, tag: String) -> bool:
	for mark: Dictionary in _marks:
		if int(mark["x"]) == x and int(mark["y"]) == y and (tag.is_empty() or str(mark["tag"]) == tag):
			return true
	return false

## @ace_condition
## @ace_name("Has Walker")
## @ace_category("Drunken Walkers")
## @ace_description("True when a walker with that id is currently registered.")
## @ace_display_template("walker [b]{id}[/b] is registered")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.has_walker({id})")
func has_walker(id: String) -> bool:
	return _walkers.has(id)

## @ace_expression
## @ace_name("Cell Value")
## @ace_category("Drunken Walkers")
## @ace_description("The value at a cell. Asking outside the grid reads the Empty Value rather than erroring, so it is always safe to call.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.cell_value({x}, {y})")
func cell_value(x: int, y: int) -> int:
	_ensure_started()
	# Never errors: a cell outside the grid reads as the Empty Value.
	if not _inside(x, y):
		return empty_value
	return _cells[y * _width + x]

## @ace_expression
## @ace_name("Current Grid Width")
## @ace_category("Drunken Walkers")
## @ace_description("The current grid width in cells, which is what Create Grid last built rather than the property.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.current_grid_width()")
func current_grid_width() -> int:
	_ensure_started()
	return _width

## @ace_expression
## @ace_name("Current Grid Height")
## @ace_category("Drunken Walkers")
## @ace_description("The current grid height in cells, which is what Create Grid last built rather than the property.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.current_grid_height()")
func current_grid_height() -> int:
	_ensure_started()
	return _height

## @ace_expression
## @ace_name("As Text")
## @ace_category("Drunken Walkers")
## @ace_description("The whole grid as text, one character per cell and one line per row. Character N of what you pass stands for value N, and an unmapped value shows as a question mark. Put it in a Label to see the map instantly, before you have a tilemap at all.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.as_text({characters})")
func as_text(characters: String) -> String:
	_ensure_started()
	var rows: PackedStringArray = PackedStringArray()
	for y: int in _height:
		var row: String = ""
		for x: int in _width:
			var value: int = _cells[y * _width + x]
			row += characters[value] if value >= 0 and value < characters.length() else "?"
		rows.append(row)
	return "\n".join(rows)

## @ace_expression
## @ace_name("Neighbour Count")
## @ace_category("Drunken Walkers")
## @ace_description("How many of the eight surrounding cells hold a value. Off-grid neighbours never match, which is what makes border detection and autotiling work without special-casing the edge.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.neighbour_count({x}, {y}, {value})")
func neighbour_count(x: int, y: int, value: int) -> int:
	_ensure_started()
	return _neighbours_holding(x, y, value)

## @ace_expression
## @ace_name("Cell To World X")
## @ace_category("Drunken Walkers")
## @ace_description("The world X of that cell's CENTRE, from Origin X and Cell Size - so a sprite placed on it lands centred in its tile whatever the origin is.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.cell_to_world_x({x})")
func cell_to_world_x(x: int) -> float:
	return origin_x + (float(x) + 0.5) * float(cell_size)

## @ace_expression
## @ace_name("Cell To World Y")
## @ace_category("Drunken Walkers")
## @ace_description("The world Y of that cell's centre, from Origin Y and Cell Size.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.cell_to_world_y({y})")
func cell_to_world_y(y: int) -> float:
	return origin_y + (float(y) + 0.5) * float(cell_size)

## @ace_expression
## @ace_name("World To Cell X")
## @ace_category("Drunken Walkers")
## @ace_description("The cell X containing that world X. It may fall outside the grid, so guard it with Is Inside Grid.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.world_to_cell_x({world_x})")
func world_to_cell_x(world_x: float) -> int:
	# May land outside the grid, because a point on screen may simply not be over it. Guard the
	# answer with Is Inside Grid before you use it.
	return floori((world_x - origin_x) / float(maxi(1, cell_size)))

## @ace_expression
## @ace_name("World To Cell Y")
## @ace_category("Drunken Walkers")
## @ace_description("The cell Y containing that world Y. It may fall outside the grid, so guard it with Is Inside Grid.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.world_to_cell_y({world_y})")
func world_to_cell_y(world_y: float) -> int:
	return floori((world_y - origin_y) / float(maxi(1, cell_size)))

## @ace_expression
## @ace_featured
## @ace_name("Count Cells")
## @ace_category("Drunken Walkers")
## @ace_description("How many cells currently hold the value. Pairs with the two index expressions to walk the whole set, which is the fast way to paint a generated map.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.count_cells({value})")
func count_cells(value: int) -> int:
	_ensure_started()
	return _cells_holding(value).size()

## @ace_expression
## @ace_name("Cell X By Index")
## @ace_category("Drunken Walkers")
## @ace_description("The X of the index-th cell holding the value, counted from 0 in a stable left-to-right, top-to-bottom order. Out of range reads -1 rather than erroring.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.cell_x_by_index({value}, {index})")
func cell_x_by_index(value: int, index: int) -> int:
	_ensure_started()
	var found: PackedInt32Array = _cells_holding(value)
	if index < 0 or index >= found.size():
		return -1
	return found[index] % _width

## @ace_expression
## @ace_name("Cell Y By Index")
## @ace_category("Drunken Walkers")
## @ace_description("The Y of the index-th cell holding the value, in the same stable order. Out of range reads -1.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.cell_y_by_index({value}, {index})")
func cell_y_by_index(value: int, index: int) -> int:
	_ensure_started()
	var found: PackedInt32Array = _cells_holding(value)
	if index < 0 or index >= found.size():
		return -1
	return found[index] / _width

## @ace_expression
## @ace_name("Count Marks")
## @ace_category("Drunken Walkers")
## @ace_description("How many marks carry the tag. An empty tag counts every mark, whatever its tag.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.count_marks({tag})")
func count_marks(tag: String) -> int:
	if tag.is_empty():
		return _marks.size()
	var found: int = 0
	for mark: Dictionary in _marks:
		if str(mark["tag"]) == tag:
			found += 1
	return found

## @ace_expression
## @ace_name("Mark X By Index")
## @ace_category("Drunken Walkers")
## @ace_description("The X of the index-th mark with the tag, counted from 0 in placement order. Out of range reads -1.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.mark_x_by_index({tag}, {index})")
func mark_x_by_index(tag: String, index: int) -> int:
	var found: int = 0
	for mark: Dictionary in _marks:
		if not tag.is_empty() and str(mark["tag"]) != tag:
			continue
		if found == index:
			return int(mark["x"])
		found += 1
	return -1

## @ace_expression
## @ace_name("Mark Y By Index")
## @ace_category("Drunken Walkers")
## @ace_description("The Y of the index-th mark with the tag, in placement order. Out of range reads -1.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.mark_y_by_index({tag}, {index})")
func mark_y_by_index(tag: String, index: int) -> int:
	var found: int = 0
	for mark: Dictionary in _marks:
		if not tag.is_empty() and str(mark["tag"]) != tag:
			continue
		if found == index:
			return int(mark["y"])
		found += 1
	return -1

## @ace_expression
## @ace_name("Current Seed")
## @ace_category("Drunken Walkers")
## @ace_description("The seed the generator was last set with, including one derived from the clock - so a player can always be shown the code that reproduces the run they are in.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.current_seed()")
func current_seed() -> String:
	_ensure_started()
	return _seed_text

## @ace_expression
## @ace_name("Injected Remaining")
## @ace_category("Drunken Walkers")
## @ace_description("How many injected values are still queued. Read it after a generation to see how much headroom the queue actually had.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.injected_remaining()")
func injected_remaining() -> int:
	return maxi(0, _injected.size() - _injected_head)

## @ace_expression
## @ace_name("Save State As Text")
## @ace_category("Drunken Walkers")
## @ace_description("The whole generator as one JSON string: the grid, the origin and cell size, the seed, the random stream's own position, every walker with its progress and recorded path, and every mark. Because the stream position round-trips, a half-finished Step Walker animation resumes and produces the identical remaining path. Save it with any save pack, hand it back to Load State From Text.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.save_state_as_text()")
func save_state_as_text() -> String:
	return JSON.stringify(save_state())

## @ace_expression
## @ace_name("Walker X")
## @ace_category("Drunken Walkers")
## @ace_description("The current X of the triggering walker. Reads 0 outside the walker triggers, never a stale cell.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.walker_x()")
func walker_x() -> int:
	return _ctx_walker_x

## @ace_expression
## @ace_name("Walker Y")
## @ace_category("Drunken Walkers")
## @ace_description("The current Y of the triggering walker. Reads 0 outside the walker triggers.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.walker_y()")
func walker_y() -> int:
	return _ctx_walker_y

## @ace_expression
## @ace_name("Walker Angle")
## @ace_category("Drunken Walkers")
## @ace_description("The current heading of the triggering walker in degrees, 0 being right and 90 down - point a digger sprite at it and it faces where it is going.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.walker_angle()")
func walker_angle() -> float:
	return _ctx_walker_angle

## @ace_expression
## @ace_name("Walker Steps Left")
## @ace_category("Drunken Walkers")
## @ace_description("The remaining step budget of the triggering walker, which is the natural driver for a generation progress bar.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.walker_steps_left()")
func walker_steps_left() -> int:
	return _ctx_walker_steps_left

## @ace_expression
## @ace_name("Walker ID")
## @ace_category("Drunken Walkers")
## @ace_description("The id of the triggering walker. It is empty inside the post-processing passes and outside the triggers, which is how On Cell Carved tells a dilated cell from a carved one.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.walker_id()")
func walker_id() -> String:
	return _ctx_walker_id

## @ace_expression
## @ace_name("Walker Tag")
## @ace_category("Drunken Walkers")
## @ace_description("The tag of the triggering walker, or the batch tag inside On Walkers By Tag Complete.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.walker_tag()")
func walker_tag() -> String:
	return _ctx_walker_tag

## @ace_expression
## @ace_name("Carved X")
## @ace_category("Drunken Walkers")
## @ace_description("The X of the cell just written, inside On Cell Carved.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.carved_x()")
func carved_x() -> int:
	return _ctx_carved_x

## @ace_expression
## @ace_name("Carved Y")
## @ace_category("Drunken Walkers")
## @ace_description("The Y of the cell just written, inside On Cell Carved.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.carved_y()")
func carved_y() -> int:
	return _ctx_carved_y

## @ace_expression
## @ace_name("Carved Value")
## @ace_category("Drunken Walkers")
## @ace_description("The value just written into the cell, inside On Cell Carved.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.carved_value()")
func carved_value() -> int:
	return _ctx_carved_value

## @ace_expression
## @ace_name("Mark X")
## @ace_category("Drunken Walkers")
## @ace_description("The X of the mark just placed, inside On Mark Placed.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.mark_x()")
func mark_x() -> int:
	return _ctx_mark_x

## @ace_expression
## @ace_name("Mark Y")
## @ace_category("Drunken Walkers")
## @ace_description("The Y of the mark just placed, inside On Mark Placed.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.mark_y()")
func mark_y() -> int:
	return _ctx_mark_y

## @ace_expression
## @ace_name("Mark Tag")
## @ace_category("Drunken Walkers")
## @ace_description("The tag of the mark just placed, inside On Mark Placed.")
## @ace_icon("res://eventsheet_addons/drunken_walkers/icon.svg")
## @ace_codegen_template("DrunkenWalkers.mark_tag()")
func mark_tag() -> String:
	return _ctx_mark_tag

## @ace_hidden
func _ensure_started() -> void:
	if _started:
		return
	_started = true
	_allocate(grid_width, grid_height)
	if start_seed.is_empty():
		# No seed given: derive one from the clock and REMEMBER it, so Current Seed can still
		# show the player a code that reproduces this run even though nobody chose it.
		_rng.randomize()
		_seed_text = str(_rng.seed)
	else:
		_seed_text = start_seed
		_rng.seed = hash(start_seed)

## @ace_hidden
func _allocate(width: int, height: int) -> void:
	_width = maxi(1, width)
	_height = maxi(1, height)
	_cells = PackedInt32Array()
	_cells.resize(_width * _height)
	_cells.fill(empty_value)
	_index_cache.clear()

## @ace_hidden
func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _width and y < _height

## @ace_hidden
func _next_random() -> float:
	if random_source == "injected":
		if _injected_head < _injected.size():
			var value: float = _injected[_injected_head]
			_injected_head += 1
			return value
		if debug_mode and not _injected_underran:
			_injected_underran = true
			push_warning("Drunken Walkers: the injected queue ran dry, so generation fell back to the internal generator. Queue more values with Inject Random.")
	elif random_source == "shared" and is_inside_tree():
		var shared: Node = get_node_or_null("/root/AdvancedRandom")
		if shared != null:
			return float(shared.random_value())
	return _rng.randf()

## @ace_hidden
func _write(x: int, y: int, value: int, walker_id: String) -> void:
	if not _inside(x, y):
		return
	var index: int = y * _width + x
	if _cells[index] == value:
		return
	_cells[index] = value
	_index_cache.clear()
	var kept_id: String = _ctx_walker_id
	_ctx_carved_x = x
	_ctx_carved_y = y
	_ctx_carved_value = value
	_ctx_walker_id = walker_id
	cell_carved.emit(x, y, value, walker_id)
	_ctx_carved_x = 0
	_ctx_carved_y = 0
	_ctx_carved_value = 0
	_ctx_walker_id = kept_id

## @ace_hidden
func _heading_of(walker: Walker, index: int) -> float:
	return fposmod(walker.start_angle + float(index) * 360.0 / float(maxi(1, walker.directions)), 360.0)

## @ace_hidden
func _weight_of(walker: Walker, index: int) -> float:
	if index < walker.weights.size():
		return maxf(0.0, walker.weights[index])
	return 1.0

## @ace_hidden
func _pick(walker: Walker, choices: Array[int]) -> float:
	var roll: float = _next_random()
	if choices.is_empty():
		return walker.heading
	var total: float = 0.0
	for index: int in choices:
		total += _weight_of(walker, index)
	if total <= 0.0:
		return _heading_of(walker, choices[mini(int(roll * float(choices.size())), choices.size() - 1)])
	var target: float = roll * total
	var running: float = 0.0
	for index: int in choices:
		running += _weight_of(walker, index)
		if target < running:
			return _heading_of(walker, index)
	return _heading_of(walker, choices[choices.size() - 1])

## @ace_hidden
func _stamp(walker: Walker) -> void:
	if walker.brush_width != 0 or walker.brush_height != 0:
		_stamp_dig(walker)
		return
	var size: int = maxi(1, walker.brush_size)
	# Odd sizes centre exactly. Even sizes cannot centre on a square grid, so they extend right
	# and down, which is the least surprising of the two ways to break the tie.
	var low: int = (size - 1) / 2
	for row: int in size:
		for column: int in size:
			_write(walker.x + column - low, walker.y + row - low, walker.carve_value, walker.id)

## @ace_hidden
func _stamp_dig(walker: Walker) -> void:
	var fallback: int = maxi(1, walker.brush_size)
	var width: int = absi(walker.brush_width) if walker.brush_width != 0 else fallback
	var depth: int = walker.brush_height if walker.brush_height != 0 else fallback
	var span: int = maxi(1, absi(depth))
	var forward_sign: float = -1.0 if depth < 0 else 1.0
	var forward: Vector2 = Vector2(_heading_step(walker.heading)).normalized()
	var across: Vector2 = Vector2(-forward.y, forward.x)
	var low: int = (maxi(1, width) - 1) / 2
	var base: Vector2 = Vector2(float(walker.x), float(walker.y))
	for along: int in span:
		for side: int in maxi(1, width):
			var point: Vector2 = base + forward * (float(along) * forward_sign) + across * float(side - low)
			_write(roundi(point.x), roundi(point.y), walker.carve_value, walker.id)

## @ace_hidden
func _set_context(walker: Walker) -> void:
	_ctx_walker_id = walker.id
	_ctx_walker_tag = walker.tag
	_ctx_walker_x = walker.x
	_ctx_walker_y = walker.y
	_ctx_walker_angle = fposmod(walker.heading, 360.0)
	_ctx_walker_steps_left = walker.steps_left

## @ace_hidden
func _clear_context() -> void:
	_ctx_walker_id = ""
	_ctx_walker_tag = ""
	_ctx_walker_x = 0
	_ctx_walker_y = 0
	_ctx_walker_angle = 0.0
	_ctx_walker_steps_left = 0

## @ace_hidden
func _finish(walker: Walker) -> void:
	if walker.finished:
		return
	walker.finished = true
	if debug_mode:
		push_warning("Drunken Walkers: walker '%s' finished at (%d, %d) with %d step(s) left and %d border re-roll(s)." % [
			walker.id, walker.x, walker.y, walker.steps_left, walker.border_rerolls])
	_set_context(walker)
	walker_finished.emit(walker.id)
	_clear_context()

## @ace_hidden
func _advance(walker: Walker, emit_stepped: bool) -> bool:
	if walker.finished:
		return false
	if not walker.started:
		walker.started = true
		if not _inside(walker.x, walker.y):
			if debug_mode:
				push_warning("Drunken Walkers: walker '%s' starts at (%d, %d), which is outside the %d x %d grid, so it carves nothing." % [
					walker.id, walker.x, walker.y, _width, _height])
			_finish(walker)
			return false
		if debug_mode:
			push_warning("Drunken Walkers: walker '%s' starts at (%d, %d) with %d step(s)." % [
				walker.id, walker.x, walker.y, walker.steps_left])
		# The first step carves the cell the walker is standing on, so nothing has to "place" it.
		_stamp(walker)
		walker.path.append(Vector2i(walker.x, walker.y))
	if walker.steps_left <= 0:
		_finish(walker)
		return false
	# A one-direction walker spends nothing on turning, because it has no choice to make.
	if walker.directions > 1 and _next_random() < walker.turn_chance:
		walker.heading = _pick(walker, _reachable(walker, walker.heading))
	var step: Vector2i = _heading_step(walker.heading)
	if not _inside(walker.x + step.x, walker.y + step.y):
		# Borders REPEL rather than stop: re-roll among the headings that stay IN BOUNDS,
		# spending one more value. Max Turn narrows that pool only while it can - a walker
		# whose every reachable heading is blocked widens to its whole direction set and turns
		# as sharply as it has to, which is how it leaves a corner instead of ending in one.
		# Nothing in bounds at all is the one way a walk ends early.
		var legal: Array[int] = _in_bounds(walker, _reachable(walker, walker.heading))
		if legal.is_empty():
			legal = _in_bounds(walker, _all_headings(walker))
		if legal.is_empty():
			_finish(walker)
			return false
		walker.border_rerolls += 1
		walker.heading = _pick(walker, legal)
		step = _heading_step(walker.heading)
	walker.x += step.x
	walker.y += step.y
	_stamp(walker)
	walker.path.append(Vector2i(walker.x, walker.y))
	walker.steps_left -= 1
	if emit_stepped:
		_set_context(walker)
		walker_stepped.emit(walker.id)
		_clear_context()
	if walker.steps_left <= 0:
		_finish(walker)
		return false
	return true

## @ace_hidden
func _run_to_end(walker: Walker) -> void:
	while _advance(walker, false):
		pass

## @ace_hidden
func _spacing_allows(x: int, y: int, tag: String, min_spacing: float) -> bool:
	var limit: float = maxf(0.0, min_spacing)
	for mark: Dictionary in _marks:
		if str(mark["tag"]) != tag:
			continue
		var dx: float = float(int(mark["x"]) - x)
		var dy: float = float(int(mark["y"]) - y)
		var squared: float = dx * dx + dy * dy
		if squared == 0.0 or squared < limit * limit:
			return false
	return true

## @ace_hidden
func _place_mark(x: int, y: int, tag: String) -> void:
	_marks.append({"x": x, "y": y, "tag": tag})
	_ctx_mark_x = x
	_ctx_mark_y = y
	_ctx_mark_tag = tag
	mark_placed.emit(tag)
	_ctx_mark_x = 0
	_ctx_mark_y = 0
	_ctx_mark_tag = ""

## @ace_hidden
func _placement_allows(x: int, y: int, value: int, placement: String) -> bool:
	match placement:
		"interior":
			return _neighbours_holding(x, y, value) == 8
		"edge":
			return _neighbours_holding(x, y, value) < 8
		_:
			return true

## @ace_hidden
func _neighbours_holding(x: int, y: int, value: int) -> int:
	var found: int = 0
	for step: Vector2i in NEIGHBOUR_STEPS:
		var nx: int = x + step.x
		var ny: int = y + step.y
		if _inside(nx, ny) and _cells[ny * _width + nx] == value:
			found += 1
	return found

## @ace_hidden
func _field(data: Dictionary, key: String, alias: String, fallback: Variant) -> Variant:
	if data.has(key):
		return data[key]
	if data.has(alias):
		return data[alias]
	return fallback

## @ace_hidden
func save_state() -> Dictionary:
	_ensure_started()
	var saved_walkers: Array[Dictionary] = []
	for id: String in _order:
		saved_walkers.append((_walkers[id] as Walker).to_dict())
	var remaining: Array[float] = []
	for index: int in range(_injected_head, _injected.size()):
		remaining.append(_injected[index])
	return {
		"version": STATE_VERSION,
		"width": _width, "height": _height, "cells": Array(_cells),
		"emptyValue": empty_value, "originX": origin_x, "originY": origin_y,
		"cellSize": cell_size, "seed": _seed_text,
		"rngSeed": str(_rng.seed), "rngState": str(_rng.state),
		"randomSource": random_source, "injected": remaining,
		"walkers": saved_walkers, "marks": _marks.duplicate(true),
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	_started = true
	_width = maxi(1, int(state.get("width", 1)))
	_height = maxi(1, int(state.get("height", 1)))
	_cells = PackedInt32Array()
	_cells.resize(_width * _height)
	var saved_cells: Array = state.get("cells", []) as Array
	for index: int in mini(saved_cells.size(), _cells.size()):
		_cells[index] = int(saved_cells[index])
	_index_cache.clear()
	empty_value = int(state.get("emptyValue", empty_value))
	origin_x = float(state.get("originX", origin_x))
	origin_y = float(state.get("originY", origin_y))
	cell_size = int(state.get("cellSize", cell_size))
	_seed_text = str(state.get("seed", ""))
	# The seed goes in first and the state after it, because setting a seed RESETS the state.
	# Restoring both in that order is what puts generation back on the identical stream, so a
	# half-finished Step Walker animation resumes and produces the identical remaining path.
	_rng.seed = int(str(state.get("rngSeed", "0")))
	_rng.state = int(str(state.get("rngState", "0")))
	random_source = str(state.get("randomSource", random_source))
	_injected.clear()
	for value: Variant in state.get("injected", []) as Array:
		_injected.append(float(value))
	_injected_head = 0
	_injected_underran = false
	_walkers.clear()
	_order.clear()
	for entry: Variant in state.get("walkers", []) as Array:
		var saved: Dictionary = entry as Dictionary
		var walker: Walker = _register(str(saved.get("id", "")))
		walker.start_x = int(saved.get("startX", 0))
		walker.start_y = int(saved.get("startY", 0))
		walker.steps = int(saved.get("steps", 400))
		walker.directions = clampi(int(saved.get("directions", 8)), 1, 8)
		walker.max_turn = float(saved.get("maxTurn", 180.0))
		walker.start_angle = float(saved.get("startAngle", 0.0))
		walker.turn_chance = float(saved.get("turnChance", 1.0))
		walker.carve_value = int(saved.get("carveValue", 1))
		walker.brush_size = int(saved.get("brushSize", 1))
		walker.brush_width = int(saved.get("brushWidth", 0))
		walker.brush_height = int(saved.get("brushHeight", 0))
		walker.weights = _weights_from_array(saved.get("weights", []) as Array)
		walker.tag = str(saved.get("tag", ""))
		walker.apply_progress(saved)
	_marks.clear()
	for entry: Variant in state.get("marks", []) as Array:
		var mark: Dictionary = entry as Dictionary
		_marks.append({"x": int(mark.get("x", 0)), "y": int(mark.get("y", 0)),
			"tag": str(mark.get("tag", ""))})

# Drunken Walkers (autoload): register as the DrunkenWalkers autoload, then size a grid, set a seed, register walkers and run them from any sheet. The pack owns the grid and the marks; you paint the tiles and spawn the objects from the results. Same seed plus same action order = the same map every time. This pack is an event sheet - extend it by editing it.
