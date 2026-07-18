## @ace_tags(random, noise, procedural)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/advanced_random/icon.svg")
class_name AdvancedRandomAddon
extends Node
## A randomness toolkit driven from event rows: seeded generators, dice, bell curves, Perlin/Simplex noise, shuffle bags, weighted picks, and plain-language chance conditions. Ships as the AdvancedRandom autoload, so one shared seed can replay an entire run.

## Seed applied on _ready (0 = a fresh random seed each run; any other value = reproducible runs).
@export_group("Advanced Random")
@export var seed_on_start: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noise: FastNoiseLite = FastNoiseLite.new()
var _perm: PackedInt32Array = PackedInt32Array()
var _bags: Dictionary = {}

func _ready() -> void:
	if seed_on_start != 0:
		_rng.seed = seed_on_start
		_noise.seed = seed_on_start
	else:
		_rng.randomize()
		_noise.seed = _rng.randi()

## @ace_action
## @ace_featured
## @ace_name("Set Seed")
## @ace_category("Advanced Random: Setup")
## @ace_description("Sets the seed for BOTH numbers and noise - same seed reproduces the same sequence.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.set_random_seed({seed_value})")
func set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	_noise.seed = seed_value

## @ace_action
## @ace_name("Randomize Seed")
## @ace_category("Advanced Random: Setup")
## @ace_description("Picks a fresh, unpredictable seed (non-reproducible).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.randomize_seed()")
func randomize_seed() -> void:
	_rng.randomize()
	_noise.seed = _rng.randi()

## @ace_action
## @ace_name("Set Noise Type")
## @ace_category("Advanced Random: Setup")
## @ace_description("FastNoiseLite.NoiseType: 0 Simplex · 1 Simplex Smooth · 2 Cellular · 3 Perlin · 4 Value Cubic · 5 Value.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.set_noise_type({noise_type})")
func set_noise_type(noise_type: int) -> void:
	_noise.noise_type = clampi(noise_type, 0, 5)

## @ace_action
## @ace_name("Set Noise Frequency")
## @ace_category("Advanced Random: Setup")
## @ace_description("Lower = smoother/larger features; higher = noisier (default 0.01).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.set_noise_frequency({frequency})")
func set_noise_frequency(frequency: float) -> void:
	_noise.frequency = frequency

## @ace_action
## @ace_name("Set Noise Octaves")
## @ace_category("Advanced Random: Setup")
## @ace_description("Fractal detail layers - more octaves add fine detail (fractal/fBm noise).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.set_noise_octaves({octaves})")
func set_noise_octaves(octaves: int) -> void:
	_noise.fractal_octaves = maxi(octaves, 1)

## @ace_action
## @ace_name("Generate Permutation Table")
## @ace_category("Advanced Random: Setup")
## @ace_description("Builds a shuffled 0..size-1 table (read with the Permutation expression) - a fixed deck order.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.generate_permutation({size})")
func generate_permutation(size: int) -> void:
	var values: Array = range(maxi(size, 0))
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: Variant = values[i]
		values[i] = values[j]
		values[j] = swap
	_perm = PackedInt32Array(values)

## @ace_action
## @ace_featured
## @ace_name("Make Shuffle Bag")
## @ace_category("Advanced Random: Setup")
## @ace_description("Creates a named bag of items - Shuffle Bag Pick draws each once before any repeats.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.make_shuffle_bag({bag_name}, {items})")
func make_shuffle_bag(bag_name: String, items: Array) -> void:
	_bags[bag_name] = {"items": items.duplicate(), "pile": []}

## @ace_expression
## @ace_name("Random (0-1)")
## @ace_category("Advanced Random: Numbers")
## @ace_description("A uniform float in [0, 1).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.random_value()")
func random_value() -> float:
	return _rng.randf()

## @ace_expression
## @ace_name("Random Range")
## @ace_category("Advanced Random: Numbers")
## @ace_description("A uniform float between min and max.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.random_range({minimum}, {maximum})")
func random_range(minimum: float, maximum: float) -> float:
	return _rng.randf_range(minimum, maximum)

## @ace_expression
## @ace_name("Random Int")
## @ace_category("Advanced Random: Numbers")
## @ace_description("A uniform integer between min and max (inclusive).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.random_int({minimum}, {maximum})")
func random_int(minimum: int, maximum: int) -> int:
	return _rng.randi_range(minimum, maximum)

## @ace_expression
## @ace_name("Roll Dice")
## @ace_category("Advanced Random: Numbers")
## @ace_description("Rolls a die with the given number of sides (1..sides).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.dice({sides})")
func dice(sides: int) -> int:
	return _rng.randi_range(1, maxi(sides, 1))

## @ace_expression
## @ace_name("Random Sign")
## @ace_category("Advanced Random: Numbers")
## @ace_description("Either -1 or +1.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.random_sign()")
func random_sign() -> int:
	return -1 if _rng.randf() < 0.5 else 1

## @ace_expression
## @ace_name("Normal (Gaussian)")
## @ace_category("Advanced Random: Numbers")
## @ace_description("A normally-distributed float around mean with the given deviation.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.normal({mean}, {deviation})")
func normal(mean: float, deviation: float) -> float:
	return _rng.randfn(mean, deviation)

## @ace_expression
## @ace_name("Noise 1D")
## @ace_category("Advanced Random: Noise")
## @ace_description("Smooth noise along a line at x - returns [-1, 1].")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.noise_1d({x})")
func noise_1d(x: float) -> float:
	return _noise.get_noise_1d(x)

## @ace_expression
## @ace_name("Noise 2D")
## @ace_category("Advanced Random: Noise")
## @ace_description("Smooth noise at (x, y) - great for terrain/heightmaps; returns [-1, 1].")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.noise_2d({x}, {y})")
func noise_2d(x: float, y: float) -> float:
	return _noise.get_noise_2d(x, y)

## @ace_expression
## @ace_name("Noise 3D")
## @ace_category("Advanced Random: Noise")
## @ace_description("Smooth noise at (x, y, z) - returns [-1, 1].")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.noise_3d({x}, {y}, {z})")
func noise_3d(x: float, y: float, z: float) -> float:
	return _noise.get_noise_3d(x, y, z)

## @ace_expression
## @ace_name("Permutation Value")
## @ace_category("Advanced Random: Picking")
## @ace_description("Reads index (wrapped) from the permutation table - generate it first.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.permutation({index})")
func permutation(index: int) -> int:
	return _perm[posmod(index, _perm.size())] if not _perm.is_empty() else 0

## @ace_expression
## @ace_name("Pick From")
## @ace_category("Advanced Random: Picking")
## @ace_description("A uniformly-random element of the array (null if empty).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.pick({options})")
func pick(options: Array) -> Variant:
	return options[_rng.randi_range(0, options.size() - 1)] if not options.is_empty() else null

## @ace_expression
## @ace_name("Weighted Index")
## @ace_category("Advanced Random: Picking")
## @ace_description("An index chosen in proportion to the weights array (heavier = likelier).")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.weighted_index({weights})")
func weighted_index(weights: Array) -> int:
	var total: float = 0.0
	for weight: Variant in weights:
		total += maxf(float(weight), 0.0)
	if total <= 0.0:
		return 0
	var roll: float = _rng.randf() * total
	var running: float = 0.0
	for i: int in weights.size():
		running += maxf(float(weights[i]), 0.0)
		if roll < running:
			return i
	return weights.size() - 1

## @ace_expression
## @ace_name("Pick From Table")
## @ace_category("Advanced Random: Picking")
## @ace_description("A weighted-random value from a RandomTableResource (.tres) - author your odds as a data asset and draw from it. "" if the table is empty.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.pick_from_table({table})")
func pick_from_table(table: Resource) -> String:
	if table == null:
		return ""
	var rows: Variant = table.get("entries")
	if not (rows is Array):
		return ""
	var total: float = 0.0
	for row: Variant in (rows as Array):
		if row is Dictionary:
			total += maxf(float((row as Dictionary).get("weight", 0.0)), 0.0)
	if total <= 0.0:
		return ""
	var roll: float = _rng.randf() * total
	var running: float = 0.0
	for row: Variant in (rows as Array):
		if row is Dictionary:
			running += maxf(float((row as Dictionary).get("weight", 0.0)), 0.0)
			if roll < running:
				return str((row as Dictionary).get("value", ""))
	return ""

## @ace_expression
## @ace_name("Shuffle Bag Pick")
## @ace_category("Advanced Random: Picking")
## @ace_description("Draws the next item from a named bag - every item appears once before any repeat.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.shuffle_bag_pick({bag_name})")
func shuffle_bag_pick(bag_name: String) -> Variant:
	if not _bags.has(bag_name):
		return null
	var bag: Dictionary = _bags[bag_name]
	var pile: Array = bag["pile"]
	if pile.is_empty():
		pile = (bag["items"] as Array).duplicate()
		bag["pile"] = pile
	if pile.is_empty():
		return null
	var drawn: int = _rng.randi_range(0, pile.size() - 1)
	var value: Variant = pile[drawn]
	pile.remove_at(drawn)
	return value

## @ace_condition
## @ace_name("Chance")
## @ace_category("Advanced Random: Chance")
## @ace_description("True roughly percent of the time (0-100) - e.g. Chance(5) for a 5% event.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.chance({percent})")
func chance(percent: float) -> bool:
	return _rng.randf() * 100.0 < percent

## @ace_condition
## @ace_name("One In")
## @ace_category("Advanced Random: Chance")
## @ace_description("True with a 1-in-n probability.")
## @ace_icon("res://eventsheet_addons/advanced_random/icon.svg")
## @ace_codegen_template("AdvancedRandom.one_in({n})")
func one_in(n: int) -> bool:
	return _rng.randi_range(1, maxi(n, 1)) == 1

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# The noise and permutation channels re-seed via their own Configure verbs and are
	# not part of the snapshot.
	return {
		"seed": _rng.seed,
		"state": _rng.state,
		"bags": _bags.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	# Seed must be assigned before state - assigning seed resets the RNG state.
	_rng.seed = int(state.get("seed", 0))
	_rng.state = int(state.get("state", 0))
	_bags = (state.get("bags", {}) as Dictionary).duplicate(true)

# Advanced Random (autoload): register as the AdvancedRandom autoload, then call its ACEs from any sheet - seeded numbers/dice/normal, Perlin/Simplex noise, permutation tables, shuffle bags, weighted picks, and a Chance(%) condition. Set seed_on_start in the Inspector for reproducible runs. This pack is an event sheet - extend it by editing it.
