# EventForge - DrawingPrefabResource compiled-steps cache (the 1000+ prefab optimization).
#
# Both prefab renderers (DrawingPrefabStamp.draw_prefab_steps and CanvasSurface.prefab) used to re-parse
# every step on every draw - a dict.get per field plus Color.from_string (a string scan) plus, for stamps,
# ResourceLoader.exists + load. compiled_steps() parses ONCE into typed entries and caches them, so 1000+
# stamps sharing one prefab pay the parse a single time. This pins the two things that matter:
#   1. Correctness: the cached entries equal a raw parse field-for-field, so the shared draw loop (fed from
#      either) renders byte-identically - the covenant the optimization must not break.
#   2. Speed: reusing the cache is strictly faster than re-parsing each draw (the CPU win).
@tool
class_name DrawingPrefabPerfTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# A representative prefab: every kind, including a stamp so the texture-load branch is exercised.
	var res: DrawingPrefabResource = DrawingPrefabResource.new()
	res.steps = [
		{"kind": "ring", "x": 0.0, "y": 0.0, "p1": 60.0, "p2": 8.0, "color": "#ffcc33"},
		{"kind": "circle", "x": 4.0, "y": -2.0, "p1": 16.0, "color": "#ff5533"},
		{"kind": "cone", "x": 0.0, "y": 0.0, "p1": -90.0, "p2": 50.0, "p3": 78.0, "color": "#33ccffaa"},
		{"kind": "rect", "x": -20.0, "y": -20.0, "p1": 40.0, "p2": 40.0, "color": "cornflowerblue"},
		{"kind": "line", "x": 0.0, "y": 0.0, "p1": 30.0, "p2": 30.0, "p3": 3.0, "color": "white"},
		{"kind": "stamp", "x": 0.0, "y": 0.0, "p1": 1.0, "p2": 0.0, "texture": "res://eventsheet_addons/behavior.svg", "color": "white"},
	]

	# ── Correctness: compiled entries equal a raw parse of the same steps (byte-identical render source) ──
	var raw: Array = DrawingPrefabResource.compile_steps(res.steps)
	var cached: Array = res.compiled_steps()
	var fields_match: bool = raw.size() == cached.size() and cached.size() == res.steps.size()
	for i: int in mini(raw.size(), cached.size()):
		var a: Dictionary = raw[i]
		var b: Dictionary = cached[i]
		if a["kind"] != b["kind"] or a["x"] != b["x"] or a["y"] != b["y"] or a["p1"] != b["p1"] \
				or a["p2"] != b["p2"] or a["p3"] != b["p3"] or a["color"] != b["color"] or a["tex"] != b["tex"]:
			fields_match = false
	ok = _check("compiled entries equal a raw parse (byte-identical render source)", fields_match, true) and ok
	ok = _check("kind is kept as a parsed string", str(cached[0]["kind"]), "ring") and ok
	ok = _check("color is pre-parsed to a Color", cached[0]["color"] is Color, true) and ok
	ok = _check("stamp texture is pre-loaded to a Texture2D", cached[5]["tex"] is Texture2D, true) and ok

	# ── Caching: repeated calls return the SAME array instance (parsed once) ──
	ok = _check("cache returns the same array instance", is_same(res.compiled_steps(), res.compiled_steps()), true) and ok

	# ── Speed: reusing the cache is strictly cheaper than re-parsing every draw ──
	var n: int = 2000
	var t0: int = Time.get_ticks_usec()
	for i: int in n:
		var reparsed: Array = DrawingPrefabResource.compile_steps(res.steps)  # what the old renderers did each draw
		if reparsed.size() < 0:
			ok = false
	var old_us: int = Time.get_ticks_usec() - t0
	var t1: int = Time.get_ticks_usec()
	for i: int in n:
		var hit: Array = res.compiled_steps()  # the shipped cached path
		if hit.size() < 0:
			ok = false
	var new_us: int = Time.get_ticks_usec() - t1
	print("[perf] drawing prefab expand: reparse=%.2fms cached=%.2fms (%d steps x %d draws)" % [old_us / 1000.0, new_us / 1000.0, res.steps.size(), n])
	ok = _check("cached path is faster than re-parsing each draw", new_us < old_us, true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] drawing_prefab_perf_test: %s" % label)
		return true
	print("[FAIL] drawing_prefab_perf_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
