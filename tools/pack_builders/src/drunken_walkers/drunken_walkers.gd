# Pack source - drunken_walkers. The behaviour code this pack ships, as real GDScript:
# highlighted, checked and breakpointable here, and assembled into the pack by
# Lib.pack_from_source. Every #region, and the body of every top-level func, is one piece of the
# sheet; everything else is scaffolding the pack declares for itself at build time and never
# reads from here.
extends Node

# The Inspector variables. They are declared on the builder's manifest (which is what emits them,
# with their tooltips and ranges); these lines exist so this file parses and type-checks on its own.
var grid_width: int = 64
var grid_height: int = 64
var max_grid_size: int = 2048
var cell_size: int = 32
var origin_x: float = 0.0
var origin_y: float = 0.0
var empty_value: int = 0
var start_seed: String = ""
var random_source: String = "internal"
var debug_mode: bool = false

#region block_1
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
signal generation_complete()

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

## Allocates the grid and seeds the stream, once. Called from _ready and from every entry point,
## so a generator driven from code before it enters the tree behaves exactly like one in a scene.
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

## Fills a fresh buffer of the given size with the Empty Value.
## @ace_hidden
func _allocate(width: int, height: int) -> void:
	_width = maxi(1, width)
	_height = maxi(1, height)
	_cells = PackedInt32Array()
	_cells.resize(_width * _height)
	_cells.fill(empty_value)
	_index_cache.clear()

## Whether the cell is on the grid at all. Off-grid is not an error anywhere in this pack, it is
## simply a cell that matches nothing and can never be stepped into.
## @ace_hidden
func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _width and y < _height

## One value from the stream, in [0, 1). EVERY stochastic decision in this pack comes through
## here, which is what makes the seed reproduce a whole map: internal is the pack's own seeded
## generator, shared borrows the Advanced Random autoload so one seed drives a whole game, and
## injected reads the queue Inject Random filled. A dry queue falls back rather than failing.
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

## Writes one cell and fires On Cell Carved when the value actually changed. Everything that
## carves - walkers, dilation, outlining - goes through this one door, which is why the trigger
## can promise "only on a change" without any caller having to remember it.
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

## The neighbour a heading resolves to. Degrees in, one of the eight grid neighbours out.
## @ace_hidden
func _heading_step(heading: float) -> Vector2i:
	var octant: int = int(round(fposmod(heading, 360.0) / 45.0)) % 8
	return NEIGHBOUR_STEPS[octant]

## Heading number `index` of a walker's direction set: `directions` evenly spaced headings
## anchored at the start angle, so entry 0 is always the start angle.
## @ace_hidden
func _heading_of(walker: Walker, index: int) -> float:
	return fposmod(walker.start_angle + float(index) * 360.0 / float(maxi(1, walker.directions)), 360.0)

## The relative weight of direction `index`: what the weights list says, or 1 for an entry it
## does not reach. Negative entries are floored to 0, which is how a weight rules a heading out.
## @ace_hidden
func _weight_of(walker: Walker, index: int) -> float:
	if index < walker.weights.size():
		return maxf(0.0, walker.weights[index])
	return 1.0

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

## The weighted pick, spending EXACTLY ONE value whether or not weights are set - so adding
## weights to a walker never shifts anything downstream of it in the stream. All-zero weights
## fall back to an even pick rather than deadlocking, so a walker can never be stuck by its own
## weights.
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

## Stamps the walker's brush at its current cell: the square brush, or the oriented dig rectangle
## when either dig dimension is set.
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

## The dig rectangle: a brush that TURNS WITH THE WALKER. Width is measured across the heading and
## is always centred, so a corridor keeps its width around every corner. Depth is measured along
## the heading and is signed: positive digs ahead of the walker, negative digs behind it, and both
## include the walker's own cell. On a diagonal the rectangle is filled solidly rather than left as
## the lattice of holes a naive rotation would produce.
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

## Publishes a walker as the context the trigger expressions read.
## @ace_hidden
func _set_context(walker: Walker) -> void:
	_ctx_walker_id = walker.id
	_ctx_walker_tag = walker.tag
	_ctx_walker_x = walker.x
	_ctx_walker_y = walker.y
	_ctx_walker_angle = fposmod(walker.heading, 360.0)
	_ctx_walker_steps_left = walker.steps_left

## Puts the walker context back to its resting reading, so an expression asked outside a trigger
## answers 0 and "" rather than whatever the last walker happened to leave behind.
## @ace_hidden
func _clear_context() -> void:
	_ctx_walker_id = ""
	_ctx_walker_tag = ""
	_ctx_walker_x = 0
	_ctx_walker_y = 0
	_ctx_walker_angle = 0.0
	_ctx_walker_steps_left = 0

## Ends a walker once, whatever ended it, and fires On Walker Finished with its final cell in
## context - so chaining logic never stalls, not even on a walker that ran out of legal moves.
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

## One step. Returns false when the walker cannot continue, which is the only way a walk ends.
##
## The randomness is spent here, in this order, and nowhere else in a walk: one value on the turn
## check, one more if it turns, and one more again if the heading it is holding would leave the
## grid and has to be re-rolled - one value for that re-roll whichever pool it draws from, so
## widening at a corner never shifts the stream. The turn check is rolled even when the turn
## chance is 1, on purpose: it means changing a probability changes THAT decision and leaves
## every later one exactly where it was in the stream.
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

## Runs one registered walker to the end of its budget. Batch runs skip On Walker Stepped.
## @ace_hidden
func _run_to_end(walker: Walker) -> void:
	while _advance(walker, false):
		pass

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

## Whether a mark of this tag may sit here: minimum spacing is a EUCLIDEAN distance in cells and
## only ever applies BETWEEN MARKS OF THE SAME TAG, so coins never crowd enemies out. A spacing of
## 0 still forbids two marks of one tag stacking on a single cell, so you never get a double coin
## by accident. Marks already on the grid count, not just the ones this pass placed.
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

## Records a mark and fires On Mark Placed with it in context.
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

## Whether a cell passes the placement rule. Off-grid neighbours never match, which is what makes
## a cell on the grid border always an edge cell and never an interior one, with no special case.
## @ace_hidden
func _placement_allows(x: int, y: int, value: int, placement: String) -> bool:
	match placement:
		"interior":
			return _neighbours_holding(x, y, value) == 8
		"edge":
			return _neighbours_holding(x, y, value) < 8
		_:
			return true

## How many of the eight surrounding cells hold a value. Off-grid neighbours never match.
## @ace_hidden
func _neighbours_holding(x: int, y: int, value: int) -> int:
	var found: int = 0
	for step: Vector2i in NEIGHBOUR_STEPS:
		var nx: int = x + step.x
		var ny: int = y + step.y
		if _inside(nx, ny) and _cells[ny * _width + nx] == value:
			found += 1
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

## One field of a walker definition, under either spelling: the documented definition key, or the
## snake_case name the same field wears everywhere else in a Godot project.
## @ace_hidden
func _field(data: Dictionary, key: String, alias: String, fallback: Variant) -> Variant:
	if data.has(key):
		return data[key]
	if data.has(alias):
		return data[alias]
	return fallback

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

## The whole generator as one Dictionary, and the door a save pack comes in through: any node
## answering save_state / load_state is snapshotted with no registration and no base class, and an
## autoload is walked by name, so a save pack picks this generator up as "DrunkenWalkers" the
## moment it is registered. Save State As Text is this same record, stringified.
##
## The RNG seed and state travel as TEXT: they are 64-bit integers, and a JSON number is a double,
## which would quietly round the biggest of them and land the reload on a different stream.
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

## Puts a saved record back, SILENTLY: no On Cell Carved and no On Mark Placed for restored
## content, which is why a repaint after a load reads Count Cells and the index expressions rather
## than waiting for a trigger.
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

## The registered walker, or null. Every Set Walker action warns by name through this one door in
## debug mode, so a typo in an id says so instead of doing nothing.
## @ace_hidden
func _walker(id: String) -> Walker:
	if _walkers.has(id):
		return _walkers[id] as Walker
	if debug_mode:
		push_warning("Drunken Walkers: there is no walker called '%s' registered." % id)
	return null
#endregion

func _ready() -> void:
	_ensure_started()

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

func clear_grid(value: int) -> void:
	_ensure_started()
	_cells.fill(value)
	_index_cache.clear()

func set_cell(x: int, y: int, value: int) -> void:
	_ensure_started()
	if not _inside(x, y):
		return
	_cells[y * _width + x] = value
	_index_cache.clear()

func set_origin(x: float, y: float, new_cell_size: int) -> void:
	origin_x = x
	origin_y = y
	if new_cell_size != 0:
		cell_size = maxi(1, new_cell_size)

func draw_cells_to_tilemap(layer: TileMapLayer, value: int, source_id: int, atlas_x: int, atlas_y: int) -> void:
	_ensure_started()
	if layer == null:
		if debug_mode:
			push_warning("Drunken Walkers: Draw Cells To Tilemap was given no TileMapLayer, so nothing was painted.")
		return
	for index: int in _cells_holding(value):
		layer.set_cell(Vector2i(index % _width, index / _width), source_id, Vector2i(atlas_x, atlas_y))

func set_seed(seed_text: String) -> void:
	_ensure_started()
	_seed_text = seed_text
	_rng.seed = hash(seed_text)
	# Set Seed resets the stream and NOTHING ELSE. The grid, the walkers and the marks are left
	# exactly as they are, so you can re-seed and re-run without reallocating anything.

func set_random_source(source: String) -> void:
	var wanted: String = source.strip_edges().to_lower()
	if wanted in ["internal", "shared", "injected"]:
		random_source = wanted
		_injected_underran = false
		return
	if debug_mode:
		push_warning("Drunken Walkers: '%s' is not a random source. Use internal, shared or injected." % source)

func inject_random(value: float) -> void:
	_injected.append(clampf(value, 0.0, 1.0))

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

func set_walker_carve_value(id: String, value: int) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		# Applies from the walker's next step, so anything already carved keeps its old value.
		# That is the point: change it mid-walk and one walker lays down two materials.
		walker.carve_value = value

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

func set_walker_turn_chance(id: String, chance: float) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		walker.turn_chance = clampf(chance, 0.0, 1.0)

func set_walker_brush_size(id: String, size: int) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		walker.brush_size = maxi(1, size)

func set_walker_start_angle(id: String, degrees: float) -> void:
	var walker: Walker = _walker(id)
	if walker == null:
		return
	# The whole direction set rotates, and the current heading rotates with it, so the walker
	# keeps pointing where it was pointing relative to its own set. The weights rotate too,
	# because entry 0 always weighs the start angle.
	walker.heading = fposmod(walker.heading + degrees - walker.start_angle, 360.0)
	walker.start_angle = fposmod(degrees, 360.0)

func set_walker_dig_size(id: String, width: int, depth: int) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		# 0 on an axis falls back to the square brush for that axis, and 0 on both restores the
		# plain square brush - so this action is a toggle rather than a one-way door.
		walker.brush_width = width
		walker.brush_height = depth

func set_walker_direction_weights(id: String, weights: String) -> void:
	var walker: Walker = _walker(id)
	if walker != null:
		walker.weights = _weights_from_text(weights)

func remove_walker(id: String) -> void:
	if not _walkers.has(id):
		return
	# Cells it already carved stay exactly as they are, because carving writes into the grid as
	# it happens rather than being replayed at the end.
	_walkers.erase(id)
	_order.erase(id)

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

func run_walker(id: String) -> void:
	_ensure_started()
	var walker: Walker = _walker(id)
	if walker != null:
		# One walker, to the end of its budget. On Generation Complete is deliberately NOT fired:
		# this is one pass of a bigger generation, not the end of it.
		_run_to_end(walker)

func step_walker(id: String, steps: int) -> void:
	_ensure_started()
	var walker: Walker = _walker(id)
	if walker == null:
		return
	for _index: int in maxi(0, steps):
		if not _advance(walker, true):
			return

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

func load_state_from_text(state: String) -> void:
	var parsed: Variant = JSON.parse_string(state)
	if not (parsed is Dictionary):
		if debug_mode:
			push_warning("Drunken Walkers: Load State From Text was given something that is not a saved state, so nothing was restored.")
		return
	load_state(parsed as Dictionary)

func is_cell_value(x: int, y: int, value: int) -> bool:
	_ensure_started()
	# Stricter than the Cell Value expression on purpose: an out-of-bounds cell matches NOTHING,
	# not even the Empty Value, which is what lets you test the border honestly.
	return _inside(x, y) and _cells[y * _width + x] == value

func is_inside_grid(x: int, y: int) -> bool:
	_ensure_started()
	return _inside(x, y)

func has_mark_at(x: int, y: int, tag: String) -> bool:
	for mark: Dictionary in _marks:
		if int(mark["x"]) == x and int(mark["y"]) == y and (tag.is_empty() or str(mark["tag"]) == tag):
			return true
	return false

func has_walker(id: String) -> bool:
	return _walkers.has(id)

func cell_value(x: int, y: int) -> int:
	_ensure_started()
	# Never errors: a cell outside the grid reads as the Empty Value.
	if not _inside(x, y):
		return empty_value
	return _cells[y * _width + x]

func current_grid_width() -> int:
	_ensure_started()
	return _width

func current_grid_height() -> int:
	_ensure_started()
	return _height

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

func neighbour_count(x: int, y: int, value: int) -> int:
	_ensure_started()
	return _neighbours_holding(x, y, value)

func cell_to_world_x(x: int) -> float:
	return origin_x + (float(x) + 0.5) * float(cell_size)

func cell_to_world_y(y: int) -> float:
	return origin_y + (float(y) + 0.5) * float(cell_size)

func world_to_cell_x(world_x: float) -> int:
	# May land outside the grid, because a point on screen may simply not be over it. Guard the
	# answer with Is Inside Grid before you use it.
	return floori((world_x - origin_x) / float(maxi(1, cell_size)))

func world_to_cell_y(world_y: float) -> int:
	return floori((world_y - origin_y) / float(maxi(1, cell_size)))

func count_cells(value: int) -> int:
	_ensure_started()
	return _cells_holding(value).size()

func cell_x_by_index(value: int, index: int) -> int:
	_ensure_started()
	var found: PackedInt32Array = _cells_holding(value)
	if index < 0 or index >= found.size():
		return -1
	return found[index] % _width

func cell_y_by_index(value: int, index: int) -> int:
	_ensure_started()
	var found: PackedInt32Array = _cells_holding(value)
	if index < 0 or index >= found.size():
		return -1
	return found[index] / _width

func count_marks(tag: String) -> int:
	if tag.is_empty():
		return _marks.size()
	var found: int = 0
	for mark: Dictionary in _marks:
		if str(mark["tag"]) == tag:
			found += 1
	return found

func mark_x_by_index(tag: String, index: int) -> int:
	var found: int = 0
	for mark: Dictionary in _marks:
		if not tag.is_empty() and str(mark["tag"]) != tag:
			continue
		if found == index:
			return int(mark["x"])
		found += 1
	return -1

func mark_y_by_index(tag: String, index: int) -> int:
	var found: int = 0
	for mark: Dictionary in _marks:
		if not tag.is_empty() and str(mark["tag"]) != tag:
			continue
		if found == index:
			return int(mark["y"])
		found += 1
	return -1

func current_seed() -> String:
	_ensure_started()
	return _seed_text

func injected_remaining() -> int:
	return maxi(0, _injected.size() - _injected_head)

func save_state_as_text() -> String:
	return JSON.stringify(save_state())

func walker_x() -> int:
	return _ctx_walker_x

func walker_y() -> int:
	return _ctx_walker_y

func walker_angle() -> float:
	return _ctx_walker_angle

func walker_steps_left() -> int:
	return _ctx_walker_steps_left

func walker_id() -> String:
	return _ctx_walker_id

func walker_tag() -> String:
	return _ctx_walker_tag

func carved_x() -> int:
	return _ctx_carved_x

func carved_y() -> int:
	return _ctx_carved_y

func carved_value() -> int:
	return _ctx_carved_value

func mark_x() -> int:
	return _ctx_mark_x

func mark_y() -> int:
	return _ctx_mark_y

func mark_tag() -> String:
	return _ctx_mark_tag
