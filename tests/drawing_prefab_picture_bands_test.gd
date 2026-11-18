# Godot EventSheets - the Inspector picture of a large Drawing Prefab is drawn in bands, and is the same picture.
#
# A prefab of 200 shapes took about a fifth of a second to draw on its worker. The picture is now cut into horizontal
# bands that are drawn at once; every pixel still belongs to one band and is blended by the same steps in the same
# order, so the image is exactly the one a single pass draws. This pins that: a spread of prefabs that uses all ten
# kinds (with colours that are see-through, rotated cones and polygons, dashed and capped lines, a stamp), drawn whole
# and in bands, at two sizes and with some steps quietened, compared byte for byte.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "drawing_prefab_picture_bands_test"
const STAMP_TEXTURE: String = "res://addons/eventsheet/help/images/ace-picker-figure.png"


## A deterministic prefab of `count` steps cycling through every kind, with every look the card can set.
static func _prefab(count: int, seed_shift: int) -> Array:
	var kinds: Array = ["circle", "ring", "rect", "line", "cone", "arc", "pie", "rounded_rect", "regular_polygon", "circle"]
	var steps: Array = []
	for index: int in count:
		var spin: int = index + seed_shift
		var kind: String = kinds[spin % kinds.size()]
		var color: String = "#%02x%02x%02x" % [(spin * 37) % 256, (spin * 91) % 256, (spin * 53) % 256]
		if spin % 7 == 3:
			color = "#%02x%02x%02x%02x" % [(spin * 37) % 256, (spin * 91) % 256, (spin * 53) % 256, 90 + (spin % 100)]
		var step: Dictionary = {"kind": kind, "x": float((spin % 17) * 13 - 100), "y": float((spin / 17) * 11 - 50), "p1": 6.0 + float(spin % 9), "p2": 4.0 + float(spin % 6), "p3": 3.0 + float(spin % 5), "color": color}
		match kind:
			"cone":
				step["p1"] = float((spin * 29) % 360)
				step["p2"] = 40.0 + float(spin % 50)
				step["p3"] = 14.0 + float(spin % 12)
			"arc", "pie":
				step["p2"] = float((spin * 17) % 360)
				step["p3"] = float((spin * 17) % 360) + 70.0 + float(spin % 200)
				step["thickness"] = 2.0 + float(spin % 4)
			"regular_polygon":
				step["p2"] = 3.0 + float(spin % 6)
				step["p3"] = float((spin * 11) % 90)
			"line":
				step["p1"] = float((spin % 17) * 13 - 60)
				step["p2"] = float((spin / 17) * 11 + 20)
				if spin % 2 == 0:
					step["dashed"] = true
					step["dash_size"] = 5.0
					step["dash_spacing"] = 3.0
					step["dash_style"] = ["plain", "rounded", "angled"][spin % 3]
				step["caps"] = ["none", "square", "round"][spin % 3]
		steps.append(step)
	return steps


static func run() -> bool:
	var table: Array = []
	var ground: Color = Color(0.11, 0.12, 0.15, 1.0)
	var sizes: Array = [Vector2i(384, 200), Vector2i(97, 61)]
	for count: int in [40, 200]:
		for shift: int in [0, 5]:
			var steps: Array = _prefab(count, shift)
			for size: Vector2i in sizes:
				var whole: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, [], 1)
				var banded: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, [], 8)
				var odd: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, [], 3)
				var chosen: Array = [2, 3, count - 1]
				var quiet_whole: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, chosen, 1)
				var quiet_banded: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, chosen, 8)
				var label: String = "%d shapes (shift %d) at %dx%d" % [count, shift, size.x, size.y]
				table.append([label + ": eight bands draw the picture a single pass draws", banded.get_data() == whole.get_data(), true])
				table.append([label + ": so do three", odd.get_data() == whole.get_data(), true])
				table.append([label + ": and with other shapes quietened", quiet_banded.get_data() == quiet_whole.get_data(), true])
				table.append([label + ": the picture is the size asked for", banded.get_size(), size])
	var plain: Array = _prefab(200, 0)
	var asked_for: Image = EventSheetDrawingPrefabPreview.rasterize(plain, Vector2i(384, 200), ground)
	table.append(["a call that does not say how many bands decides for itself and gets the same picture", asked_for.get_data() == EventSheetDrawingPrefabPreview.rasterize(plain, Vector2i(384, 200), ground, [], 1).get_data(), true])
	var drawn_something: bool = false
	for column: int in range(0, 384, 7):
		if asked_for.get_pixel(column, 100) != ground:
			drawn_something = true
	table.append(["the picture holds shapes, not only the ground", drawn_something, true])
	# A prefab with a stamp (whose texture loads while it is drawn) is drawn whole whatever it is asked.
	var stamped: Array = _prefab(60, 0)
	stamped.append({"kind": "stamp", "x": 0.0, "y": 0.0, "p1": 0.2, "p2": 30.0, "color": "#ffffff", "texture": STAMP_TEXTURE})
	table.append(["a prefab with a stamp is drawn whole", EventSheetDrawingPrefabPreview._bands_for(stamped), 1])
	table.append(["a prefab of two hundred shapes is drawn in bands", EventSheetDrawingPrefabPreview._bands_for(plain) > 1, true])
	table.append(["a small prefab is drawn whole", EventSheetDrawingPrefabPreview._bands_for(_prefab(5, 0)), 1])
	var with_stamp: Image = EventSheetDrawingPrefabPreview.rasterize(stamped, Vector2i(384, 200), ground)
	table.append(["a stamp prefab draws the same picture however it is drawn", with_stamp.get_data() == EventSheetDrawingPrefabPreview.rasterize(stamped, Vector2i(384, 200), ground, [], 1).get_data(), true])
	var ok: bool = SUPPORT.pins(P, table)
	ok = fuzz_pins() and ok
	ok = band_pins() and ok
	return hoist_pins() and ok


## Random shapes of every kind, some tiny, some with nothing to draw, some half outside the picture.
static func _random_steps(seed_value: int, count: int) -> Array:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	var kinds: Array = ["circle", "ring", "rect", "line", "cone", "arc", "pie", "rounded_rect", "regular_polygon"]
	var steps: Array = []
	for index: int in count:
		var kind: String = kinds[random.randi() % kinds.size()]
		var step: Dictionary = {"kind": kind, "x": random.randf_range(-120.0, 120.0), "y": random.randf_range(-80.0, 80.0),
			"p1": random.randf_range(-6.0, 70.0), "p2": random.randf_range(-6.0, 70.0), "p3": random.randf_range(-6.0, 40.0),
			"color": "#%02x%02x%02x%02x" % [random.randi() % 256, random.randi() % 256, random.randi() % 256, 60 + random.randi() % 196]}
		if kind == "line":
			if random.randi() % 5 == 0:
				step["p1"] = step["x"]
			if random.randi() % 5 == 0:
				step["p2"] = step["y"]
			step["caps"] = ["none", "square", "round"][random.randi() % 3]
			if random.randi() % 2 == 0:
				step["dashed"] = true
				step["dash_size"] = random.randf_range(1.0, 12.0)
				step["dash_spacing"] = random.randf_range(0.0, 9.0)
				step["dash_offset"] = random.randf_range(0.0, 3.0)
				step["dash_style"] = ["plain", "rounded", "angled"][random.randi() % 3]
		if kind == "arc":
			step["thickness"] = random.randf_range(0.2, 9.0)
		steps.append(step)
	return steps


## Visiting only the columns of a row that can hold a shape draws the pixels visiting every column draws.
static func fuzz_pins() -> bool:
	var table: Array = []
	var ground: Color = Color(0.11, 0.12, 0.15, 1.0)
	var same: int = 0
	var total: int = 0
	var first_difference: String = ""
	for seed_value: int in 24:
		var steps: Array = _random_steps(seed_value, 30)
		for size: Vector2i in [Vector2i(160, 100), Vector2i(61, 87)]:
			EventSheetDrawingPrefabPreview.prune_columns = true
			var pruned: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, [], 1)
			EventSheetDrawingPrefabPreview.prune_columns = false
			var long_way: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, [], 1)
			EventSheetDrawingPrefabPreview.prune_columns = true
			total += 1
			if pruned.get_data() == long_way.get_data():
				same += 1
			elif first_difference.is_empty():
				first_difference = "seed %d at %dx%d" % [seed_value, size.x, size.y]
	table.append(["random pictures drawn visiting only the needed columns equal the ones drawn the long way (%d of %d)" % [same, total], first_difference, ""])
	return SUPPORT.pins(P, table)


## The two tests a fill asks of every pixel, worked out once per shape, answer what the per-pixel functions answer.
static func hoist_pins() -> bool:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 91
	var polygon_wrong: int = 0
	var sweep_wrong: int = 0
	for round: int in 3000:
		var offset: Vector2 = Vector2(random.randf_range(-60.0, 60.0), random.randf_range(-60.0, 60.0))
		var sides: float = random.randf_range(2.0, 40.0)
		var angle: float = random.randf_range(-400.0, 400.0)
		var radius: float = random.randf_range(1.0, 70.0)
		var count: int = EventSheetDrawingPrefabPreview._sides_of(sides)
		var around: float = fposmod(offset.angle() - deg_to_rad(angle), TAU / float(count)) - PI / float(count)
		var hoisted: bool = offset.length() * cos(around) <= radius * cos(PI / float(count))
		if hoisted != EventSheetDrawingPrefabPreview._in_polygon(offset, radius, sides, angle):
			polygon_wrong += 1
		var start: float = random.randf_range(-720.0, 720.0)
		var finish: float = start + random.randf_range(-800.0, 800.0) * (0.0 if round % 40 == 0 else 1.0)
		var plan: Vector3 = EventSheetDrawingPrefabPreview._sweep_plan(start, finish)
		var inside: bool = plan.z != 0.0 and (plan.z == 2.0 or fposmod(offset.angle() - plan.x, TAU) <= plan.y)
		if inside != EventSheetDrawingPrefabPreview._in_sweep(offset, start, finish):
			sweep_wrong += 1
	return SUPPORT.pins(P, [
		["a polygon's test, worked out once per shape, answers what the per-pixel test answers", polygon_wrong, 0],
		["so does a sweep's", sweep_wrong, 0],
	])


## Steps of the kinds that were still asked pixel by pixel: rings thick and thin (some with no hole, some half outside the
## picture), arcs of a full turn and of part of one, pies, cones, and see-through colours over each other.
static func _band_steps(seed_value: int) -> Array:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	var steps: Array = []
	for index: int in 40:
		var color: String = "#%02x%02x%02x%02x" % [random.randi() % 256, random.randi() % 256, random.randi() % 256, [255, 255, 200, 120, 60][random.randi() % 5]]
		var at: Dictionary = {"x": random.randf_range(-130.0, 130.0), "y": random.randf_range(-90.0, 90.0), "color": color}
		match index % 6:
			0:
				steps.append(at.merged({"kind": "ring", "p1": random.randf_range(2.0, 60.0), "p2": random.randf_range(0.2, 70.0)}))
			1:
				steps.append(at.merged({"kind": "arc", "p1": random.randf_range(2.0, 60.0), "p2": 0.0, "p3": [360.0, 720.0, -360.0, 400.0][random.randi() % 4], "thickness": random.randf_range(0.3, 40.0)}))
			2:
				var from_angle: float = random.randf_range(0.0, 360.0)
				steps.append(at.merged({"kind": "arc", "p1": random.randf_range(2.0, 60.0), "p2": from_angle, "p3": from_angle + random.randf_range(20.0, 340.0), "thickness": random.randf_range(0.3, 25.0)}))
			3:
				var start: float = random.randf_range(0.0, 360.0)
				steps.append(at.merged({"kind": "pie", "p1": random.randf_range(2.0, 60.0), "p2": start, "p3": start + random.randf_range(10.0, 360.0)}))
			4:
				steps.append(at.merged({"kind": "cone", "p1": random.randf_range(0.0, 360.0), "p2": random.randf_range(5.0, 330.0), "p3": random.randf_range(3.0, 60.0)}))
			5:
				steps.append(at.merged({"kind": "circle", "p1": random.randf_range(2.0, 50.0)}))
	return steps


## The rings, arcs, pies and cones, and a run of see-through colour written across in one go, draw the pixels that asking
## every pixel one by one draws, on the ground and with some steps quietened.
static func band_pins() -> bool:
	var ground: Color = Color(0.11, 0.12, 0.15, 1.0)
	var table: Array = []
	var same_pruned: int = 0
	var same_runs: int = 0
	var total: int = 0
	var first_difference: String = ""
	for seed_value: int in 30:
		var steps: Array = _band_steps(seed_value)
		for size: Vector2i in [Vector2i(160, 100), Vector2i(61, 87)]:
			for quiet: Array in [[], [seed_value % 40, 7]]:
				EventSheetDrawingPrefabPreview.prune_columns = false
				EventSheetDrawingPrefabPreview.blend_runs = false
				var long_way: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, quiet, 1)
				EventSheetDrawingPrefabPreview.prune_columns = true
				var pruned: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, quiet, 1)
				EventSheetDrawingPrefabPreview.blend_runs = true
				var runs: Image = EventSheetDrawingPrefabPreview.rasterize(steps, size, ground, quiet, 1)
				total += 1
				if pruned.get_data() == long_way.get_data():
					same_pruned += 1
				elif first_difference.is_empty():
					first_difference = "pruned: seed %d at %dx%d quiet %s" % [seed_value, size.x, size.y, str(quiet)]
				if runs.get_data() == long_way.get_data():
					same_runs += 1
				elif first_difference.is_empty():
					first_difference = "runs: seed %d at %dx%d quiet %s" % [seed_value, size.x, size.y, str(quiet)]
	EventSheetDrawingPrefabPreview.prune_columns = true
	EventSheetDrawingPrefabPreview.blend_runs = true
	table.append(["rings, arcs, pies and cones drawn visiting only the columns they can fill equal the long way (%d of %d)" % [same_pruned, total], first_difference, ""])
	table.append(["and with see-through runs blended in one go (%d of %d)" % [same_runs, total], same_runs, total])
	return SUPPORT.pins(P, table)
