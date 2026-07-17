# Pack builder - advanced_random (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Advanced Random addon: a faithful port of the Advanced Random PLUGIN - a single
## GLOBAL utility, so it ships as an AUTOLOAD (one shared seed = reproducible runs). Wraps
## Godot's own RandomNumberGenerator (seeded distributions: uniform / range / dice / normal)
## and FastNoiseLite (Perlin/Simplex/value noise with fractal octaves), plus permutation
## tables and shuffle bags (pick without repeats). Categories use the picker's "Parent: Sub"
## nesting so the vocabulary clusters under one Advanced Random section.
## THE DEEPEST EXTENSION POINT: this pack IS an event sheet - open the .tres, add functions,
## recompile, re-register.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "AdvancedRandom"
	sheet.host_class = "Node"
	sheet.custom_class_name = "AdvancedRandomAddon"
	sheet.class_description = "A randomness toolkit driven from event rows: seeded generators, dice, bell curves, Perlin/Simplex noise, shuffle bags, weighted picks, and plain-language chance conditions. Ships as the AdvancedRandom autoload, so one shared seed can replay an entire run."
	sheet.addon_tags = PackedStringArray(["random", "noise", "procedural"])
	sheet.variables = {
		"seed_on_start": {"type": "int", "default": 0, "exported": true, "description": "Seed applied on _ready - 0 gives a fresh random seed each run; any other value makes runs reproducible.",
			"attributes": {"tooltip": "Seed applied on _ready (0 = a fresh random seed each run; any other value = reproducible runs).", "group": "Advanced Random"}},
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Advanced Random (autoload): register as the AdvancedRandom autoload, then call its ACEs from any sheet - seeded numbers/dice/normal, Perlin/Simplex noise, permutation tables, shuffle bags, weighted picks, and a Chance(%) condition. Set seed_on_start in the Inspector for reproducible runs. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# Class-level state: Godot's own RNG + noise generators, a permutation table, named bags.
	var state: RawCodeRow = RawCodeRow.new()
	state.code = "\n".join(PackedStringArray([
		"var _rng: RandomNumberGenerator = RandomNumberGenerator.new()",
		"var _noise: FastNoiseLite = FastNoiseLite.new()",
		"var _perm: PackedInt32Array = PackedInt32Array()",
		"var _bags: Dictionary = {}",
	]))
	sheet.events.append(state)

	# Seed on start: a fixed seed_on_start = reproducible; 0 = a fresh random seed.
	var ready_tick: EventRow = EventRow.new()
	ready_tick.trigger_provider_id = "Core"
	ready_tick.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"if seed_on_start != 0:",
		"\t_rng.seed = seed_on_start",
		"\t_noise.seed = seed_on_start",
		"else:",
		"\t_rng.randomize()",
		"\t_noise.seed = _rng.randi()",
	]))
	ready_tick.actions.append(ready_body)
	sheet.events.append(ready_tick)

	# ── Setup actions ──
	Lib.append_function(sheet, "set_random_seed", "Set Seed", "Advanced Random: Setup", "Sets the seed for BOTH numbers and noise - same seed reproduces the same sequence.",
		[["seed_value", "int"]],
		"_rng.seed = seed_value\n_noise.seed = seed_value")
	Lib.append_function(sheet, "randomize_seed", "Randomize Seed", "Advanced Random: Setup", "Picks a fresh, unpredictable seed (non-reproducible).",
		[],
		"_rng.randomize()\n_noise.seed = _rng.randi()")
	Lib.append_function(sheet, "set_noise_type", "Set Noise Type", "Advanced Random: Setup", "FastNoiseLite.NoiseType: 0 Simplex · 1 Simplex Smooth · 2 Cellular · 3 Perlin · 4 Value Cubic · 5 Value.",
		[["noise_type", "int"]],
		"_noise.noise_type = clampi(noise_type, 0, 5)")
	Lib.append_function(sheet, "set_noise_frequency", "Set Noise Frequency", "Advanced Random: Setup", "Lower = smoother/larger features; higher = noisier (default 0.01).",
		[["frequency", "float"]],
		"_noise.frequency = frequency")
	Lib.append_function(sheet, "set_noise_octaves", "Set Noise Octaves", "Advanced Random: Setup", "Fractal detail layers - more octaves add fine detail (fractal/fBm noise).",
		[["octaves", "int"]],
		"_noise.fractal_octaves = maxi(octaves, 1)")
	Lib.append_function(sheet, "generate_permutation", "Generate Permutation Table", "Advanced Random: Setup", "Builds a shuffled 0..size-1 table (read with the Permutation expression) - a fixed deck order.",
		[["size", "int"]],
		"\n".join(PackedStringArray([
			"var values: Array = range(maxi(size, 0))",
			"for i: int in range(values.size() - 1, 0, -1):",
			"\tvar j: int = _rng.randi_range(0, i)",
			"\tvar swap: Variant = values[i]",
			"\tvalues[i] = values[j]",
			"\tvalues[j] = swap",
			"_perm = PackedInt32Array(values)",
		])))
	Lib.append_function(sheet, "make_shuffle_bag", "Make Shuffle Bag", "Advanced Random: Setup", "Creates a named bag of items - Shuffle Bag Pick draws each once before any repeats.",
		[["bag_name", "String"], ["items", "Array"]],
		"_bags[bag_name] = {\"items\": items.duplicate(), \"pile\": []}")

	# ── Distributions (numbers) ──
	_expr(sheet, "random_value", "Random (0-1)", "Advanced Random: Numbers", "A uniform float in [0, 1).", [], "return _rng.randf()", TYPE_FLOAT)
	_expr(sheet, "random_range", "Random Range", "Advanced Random: Numbers", "A uniform float between min and max.", [["minimum", "float"], ["maximum", "float"]], "return _rng.randf_range(minimum, maximum)", TYPE_FLOAT)
	_expr(sheet, "random_int", "Random Int", "Advanced Random: Numbers", "A uniform integer between min and max (inclusive).", [["minimum", "int"], ["maximum", "int"]], "return _rng.randi_range(minimum, maximum)", TYPE_INT)
	_expr(sheet, "dice", "Roll Dice", "Advanced Random: Numbers", "Rolls a die with the given number of sides (1..sides).", [["sides", "int"]], "return _rng.randi_range(1, maxi(sides, 1))", TYPE_INT)
	_expr(sheet, "random_sign", "Random Sign", "Advanced Random: Numbers", "Either -1 or +1.", [], "return -1 if _rng.randf() < 0.5 else 1", TYPE_INT)
	_expr(sheet, "normal", "Normal (Gaussian)", "Advanced Random: Numbers", "A normally-distributed float around mean with the given deviation.", [["mean", "float"], ["deviation", "float"]], "return _rng.randfn(mean, deviation)", TYPE_FLOAT)

	# ── Noise (FastNoiseLite) ──
	_expr(sheet, "noise_1d", "Noise 1D", "Advanced Random: Noise", "Smooth noise along a line at x - returns [-1, 1].", [["x", "float"]], "return _noise.get_noise_1d(x)", TYPE_FLOAT)
	_expr(sheet, "noise_2d", "Noise 2D", "Advanced Random: Noise", "Smooth noise at (x, y) - great for terrain/heightmaps; returns [-1, 1].", [["x", "float"], ["y", "float"]], "return _noise.get_noise_2d(x, y)", TYPE_FLOAT)
	_expr(sheet, "noise_3d", "Noise 3D", "Advanced Random: Noise", "Smooth noise at (x, y, z) - returns [-1, 1].", [["x", "float"], ["y", "float"], ["z", "float"]], "return _noise.get_noise_3d(x, y, z)", TYPE_FLOAT)

	# ── Picking ──
	_expr(sheet, "permutation", "Permutation Value", "Advanced Random: Picking", "Reads index (wrapped) from the permutation table - generate it first.", [["index", "int"]], "return _perm[posmod(index, _perm.size())] if not _perm.is_empty() else 0", TYPE_INT)
	_expr(sheet, "pick", "Pick From", "Advanced Random: Picking", "A uniformly-random element of the array (null if empty).", [["options", "Array"]], "return options[_rng.randi_range(0, options.size() - 1)] if not options.is_empty() else null", TYPE_MAX)
	_expr(sheet, "weighted_index", "Weighted Index", "Advanced Random: Picking", "An index chosen in proportion to the weights array (heavier = likelier).", [["weights", "Array"]],
		"\n".join(PackedStringArray([
			"var total: float = 0.0",
			"for weight: Variant in weights:",
			"\ttotal += maxf(float(weight), 0.0)",
			"if total <= 0.0:",
			"\treturn 0",
			"var roll: float = _rng.randf() * total",
			"var running: float = 0.0",
			"for i: int in weights.size():",
			"\trunning += maxf(float(weights[i]), 0.0)",
			"\tif roll < running:",
			"\t\treturn i",
			"return weights.size() - 1",
		])), TYPE_INT)
	_expr(sheet, "pick_from_table", "Pick From Table", "Advanced Random: Picking", "A weighted-random value from a RandomTableResource (.tres) - author your odds as a data asset and draw from it. \"\" if the table is empty.", [["table", "Resource"]],
		"\n".join(PackedStringArray([
			"if table == null:",
			"\treturn \"\"",
			"var rows: Variant = table.get(\"entries\")",
			"if not (rows is Array):",
			"\treturn \"\"",
			"var total: float = 0.0",
			"for row: Variant in (rows as Array):",
			"\tif row is Dictionary:",
			"\t\ttotal += maxf(float((row as Dictionary).get(\"weight\", 0.0)), 0.0)",
			"if total <= 0.0:",
			"\treturn \"\"",
			"var roll: float = _rng.randf() * total",
			"var running: float = 0.0",
			"for row: Variant in (rows as Array):",
			"\tif row is Dictionary:",
			"\t\trunning += maxf(float((row as Dictionary).get(\"weight\", 0.0)), 0.0)",
			"\t\tif roll < running:",
			"\t\t\treturn str((row as Dictionary).get(\"value\", \"\"))",
			"return \"\""
		])), TYPE_STRING)
	_expr(sheet, "shuffle_bag_pick", "Shuffle Bag Pick", "Advanced Random: Picking", "Draws the next item from a named bag - every item appears once before any repeat.", [["bag_name", "String"]],
		"\n".join(PackedStringArray([
			"if not _bags.has(bag_name):",
			"\treturn null",
			"var bag: Dictionary = _bags[bag_name]",
			"var pile: Array = bag[\"pile\"]",
			"if pile.is_empty():",
			"\tpile = (bag[\"items\"] as Array).duplicate()",
			"\tbag[\"pile\"] = pile",
			"if pile.is_empty():",
			"\treturn null",
			"var drawn: int = _rng.randi_range(0, pile.size() - 1)",
			"var value: Variant = pile[drawn]",
			"pile.remove_at(drawn)",
			"return value",
		])), TYPE_MAX)

	# ── Chance conditions ──
	_cond(sheet, "chance", "Chance", "Advanced Random: Chance", "True roughly percent of the time (0-100) - e.g. Chance(5) for a 5% event.", [["percent", "float"]], "return _rng.randf() * 100.0 < percent")
	_cond(sheet, "one_in", "One In", "Advanced Random: Chance", "True with a 1-in-n probability.", [["n", "int"]], "return _rng.randi_range(1, maxi(n, 1)) == 1")

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# The noise and permutation channels re-seed via their own Configure verbs and are",
		"# not part of the snapshot.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"seed\": _rng.seed,",
		"\t\t\"state\": _rng.state,",
		"\t\t\"bags\": _bags.duplicate(true)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t# Seed must be assigned before state - assigning seed resets the RNG state.",
		"\t_rng.seed = int(state.get(\"seed\", 0))",
		"\t_rng.state = int(state.get(\"state\", 0))",
		"\t_bags = (state.get(\"bags\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/advanced_random/advanced_random_addon")


## An expression ACE (returns a value).
static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, return_type: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = return_type
	sheet.functions.append(fn)


## A condition ACE (returns bool).
static func _cond(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)
