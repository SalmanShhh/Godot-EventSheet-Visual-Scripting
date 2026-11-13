@tool
class_name WeightMathTest
extends RefCounted

## The sums behind a weighted table: weights, shares, the odds line and a seeded roll.

const SUPPORT := preload("res://tests/support.gd")
const MATH := preload("res://addons/eventsheet/editor/inspector/weight_math.gd")


static func _rows() -> Array:
	return [
		{"item": "Coin", "weight": 5.0},
		{"item": "Gem", "weight": 2.5},
		{"item": "Sword", "weight": 0.5},
		{"item": "Ghost", "weight": -3.0},
		{"item": "", "weight": "heavy"},
	]


static func run() -> bool:
	var rows: Array = _rows()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var counts: PackedInt32Array = MATH.roll(rows, "weight", 1000, rng)
	var total_rolled: int = 0
	for count: int in counts:
		total_rolled += count
	var tied: Array = [{"weight": 1}, {"weight": 1}]
	var none: Array = [{"weight": 0}, {"weight": -2}]
	return SUPPORT.pins("weight_math_test", [
		["a negative weight counts as 0", MATH.weight_of(rows[3], "weight"), 0.0],
		["a weight that is not a number counts as 0", MATH.weight_of(rows[4], "weight"), 0.0],
		["a missing column counts as 0", MATH.weight_of(rows[0], "nothing"), 0.0],
		["a row that is not a Dictionary counts as 0", MATH.weight_of(5, "weight"), 0.0],
		["the total adds only the weights above 0", MATH.total(rows, "weight"), 8.0],
		["shares are each weight over the total", MATH.shares(rows, "weight"), PackedFloat64Array([0.625, 0.3125, 0.0625, 0.0, 0.0])],
		["no total gives no shares", MATH.shares(none, "weight"), PackedFloat64Array([0.0, 0.0])],
		["62.5 percent reads with its decimal", MATH.percent_text(0.625), "62.5%"],
		["a whole percent drops the decimal", MATH.percent_text(0.5), "50%"],
		["6.25 percent rounds to one decimal", MATH.percent_text(0.0625), "6.3%"],
		["zero reads as 0%", MATH.percent_text(0.0), "0%"],
		["the largest share is the first row here", MATH.largest(rows, "weight"), 0],
		["a tie goes to the first row", MATH.largest(tied, "weight"), 0],
		["no weight at all has no largest", MATH.largest(none, "weight"), -1],
		["every roll lands on a row", total_rolled, 1000],
		["a row with no weight is never rolled", [counts[3], counts[4]], [0, 0]],
		["the biggest weight comes up most", counts[0] > counts[1] and counts[1] > counts[2], true],
		["a table with no weight rolls nothing", MATH.roll(none, "weight", 1000, rng), PackedInt32Array([0, 0])],
		["the same seed rolls the same table", MATH.roll(rows, "weight", 1000, _seeded(7)), counts],
		["a row is named by its text column", MATH.row_name(rows[0], "item", 0), "Coin"],
		["an empty name falls back to its place", MATH.row_name(rows[4], "item", 4), "Row 5"],
		["the first text column is found", MATH.first_text_column([{"name": "n", "type": "int"}, {"name": "item", "type": "String"}]), "item"],
		["no text column gives an empty name", MATH.first_text_column([{"name": "n", "type": "int"}]), ""],
		["the odds line names the biggest first", MATH.odds_line(rows, "weight", "item", 3, "and %d more"), "Coin 62.5%, Gem 31.3%, Sword 6.3%"],
		["a longer table says how many more", MATH.odds_line(rows, "weight", "item", 2, "and %d more"), "Coin 62.5%, Gem 31.3% and 1 more"],
		["a table with no weight has an empty line", MATH.odds_line(none, "weight", "item", 3, "and %d more"), ""],
	])


static func _seeded(value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = value
	return rng
