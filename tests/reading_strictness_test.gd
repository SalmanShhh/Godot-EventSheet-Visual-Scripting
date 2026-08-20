# Godot EventSheets - the pattern readings' STRICTNESS, and the hygiene of what they quote.
#
# A pattern reading tells a reader that several lines together mean one thing. It is the one reading
# that cannot be checked by looking at the row it sits on, so two things have to hold and neither is
# checked by the readings' own tests:
#
#   1. NEAR MISSES CLAIM NOTHING. Every shape below is one edit away from a pattern and is not one -
#      a countdown nobody compares to zero, a pool drained with no guard, two waits with nothing
#      between them, a loop that measures but keeps no winner, a state variable nobody switches on,
#      a body property written on a plain node. Each is pinned by the patterns it claims (the empty
#      string for almost all of them), never by a count, so a reading that starts over-claiming names
#      itself here rather than passing a "still 0 patterns" check by claiming a different wrong one.
#
#   2. WHAT A CLAIM SAYS OUT LOUD IS CODE. The hover quotes a claim's evidence to the reader ("read
#      as the ... pattern because: <lines>"), and a claim made by an event whose rows all lifted
#      carries the ids of those rows as its grounds. Those are what the registry reasons with - a
#      reader cannot find `MoveAndSlide` anywhere in their own file - so no ace id may reach the
#      words a reader is shown. Pinned over the reading fixtures that actually claim.
#
# And the covenant under both: a reading may not change what is saved, so every case here also
# re-emits byte-identically. The cases are written to `user://` as real files because the importer
# and the annotations both read from disk.
@tool
class_name ReadingStrictnessTest
extends RefCounted

## Shapes one edit away from a pattern, and the two that ARE one (the positive controls, which is
## what stops the near-miss pins passing because the readings stopped working altogether).
const CASES: Dictionary = {
	"awaits_with_nothing_between": "extends Node\n\n\nfunc intro() -> void:\n\tawait get_tree().create_timer(1.0).timeout\n\tawait get_tree().create_timer(2.0).timeout\n",
	"clamped_to_one_not_zero": "extends Node\n\nvar fuse: float = 3.0\n\n\nfunc _process(delta: float) -> void:\n\tfuse = max(1.0, fuse - delta)\n\tif fuse > 0:\n\t\tprint(fuse)\n",
	"countdown_never_compared": "extends Node\n\nvar cooldown: float = 1.0\n\n\nfunc _process(delta: float) -> void:\n\tcooldown -= delta\n",
	"drag_flag_never_lowered": "extends Node2D\n\nvar _dragging: bool = false\n\n\nfunc _ready() -> void:\n\t_dragging = true\n",
	"friction_on_plain_node": "extends Node2D\n\nvar friction: float = 0.2\n\n\nfunc _process(_delta: float) -> void:\n\tprint(friction)\n",
	"gravity_scale_on_node2d": "extends Node2D\n\nvar gravity_scale: float = 1.0\n\n\nfunc _ready() -> void:\n\tgravity_scale = 2.0\n",
	"loop_that_keeps_but_never_measures": "extends Node\n\n\nfunc _ready() -> void:\n\tvar best: Variant = null\n\tfor foe: Variant in [1, 2, 3]:\n\t\tif foe < 2:\n\t\t\tbest = foe\n\tprint(best)\n",
	"loop_that_only_measures": "extends Node2D\n\n\nfunc _ready() -> void:\n\tfor foe: Node2D in get_tree().get_nodes_in_group(\"foes\"):\n\t\tprint(global_position.distance_to(foe.global_position))\n",
	"move_toward_wrong_arity": "extends Node\n\nvar fuse: float = 3.0\n\n\nfunc _process(delta: float) -> void:\n\tfuse = move_toward(fuse, 0)\n\tif fuse > 0:\n\t\tprint(delta)\n",
	"nested_calls": "extends Node2D\n\n\nfunc _ready() -> void:\n\tposition = position.lerp(Vector2(maxf(0.0, 1.0), minf(2.0, 3.0)), 0.5)\n",
	"one_await_is_a_pause": "extends Node\n\n\nfunc intro() -> void:\n\tprint(\"go\")\n\tawait get_tree().create_timer(1.0).timeout\n\tprint(\"done\")\n",
	"pop_back_without_guard": "extends Node\n\nvar pool: Array = []\n\n\nfunc _ready() -> void:\n\tvar b = pool.pop_back()\n\tadd_child(b)\n",
	"push_back_on_plain_list": "extends Node\n\nvar log_lines: Array = []\n\n\nfunc _ready() -> void:\n\tlog_lines.push_back(\"a\")\n",
	"raycast_without_target": "extends Node2D\n\n@onready var ray: RayCast2D = $RayCast2D\n\n\nfunc _process(_delta: float) -> void:\n\tif ray.is_colliding():\n\t\tprint(\"hit\")\n",
	"state_var_nobody_switches_on": "extends Node\n\nenum States { IDLE, RUN, JUMP }\n\nvar state: int = States.IDLE\n\n\nfunc _ready() -> void:\n\tprint(state)\n",
	"subtraction_that_is_not_delta": "extends Node\n\nvar ammo: int = 10\n\n\nfunc _process(_delta: float) -> void:\n\tammo -= 1\n\tif ammo > 0:\n\t\tprint(ammo)\n",
	"table_entry_compared_to_zero": "extends Node\n\nvar stats: Dictionary = {}\n\n\nfunc _process(delta: float) -> void:\n\tstats[\"hp\"] -= delta\n\tif stats[\"hp\"] > 0:\n\t\tprint(stats)\n",
	"unicode_strings": "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"café ✓ 日本語\")\n",
	"whitespace_inside_the_clamp": "extends Node\n\nvar fuse: float = 3.0\n\n\nfunc _process(delta: float) -> void:\n\tfuse = max( 0.0 , fuse - delta )\n\tif fuse > 0:\n\t\tprint(fuse)\n",
	"z_index_write": "extends Node2D\n\n\nfunc _ready() -> void:\n\tz_index = 3\n",
	"real_countdown_with_notes_between": "extends Node\n\nvar cooldown: float = 1.0\n\n\nfunc _process(delta: float) -> void:\n\t# the shot timer\n\tcooldown -= delta\n\t# ready again?\n\tif cooldown <= 0:\n\t\tcooldown = 1.0\n",
	"real_nearest_over_a_typed_loop": "extends Node2D\n\n\nfunc _ready() -> void:\n\tvar nearest: Node2D = null\n\tvar best: float = 1000.0\n\tfor foe: Node2D in get_tree().get_nodes_in_group(\"foes\"):\n\t\tvar d: float = global_position.distance_to(foe.global_position)\n\t\tif d < best:\n\t\t\tbest = d\n\t\t\tnearest = foe\n\tprint(nearest)\n",
	"real_sequence": "extends Node\n\nvar beat: int = 0\n\n\nfunc intro() -> void:\n\tbeat = 1\n\tawait get_tree().create_timer(1.0).timeout\n\tbeat = 2\n\tawait get_tree().create_timer(2.0).timeout\n\tbeat = 3\n",
}

## The patterns each case claims, in the order they are claimed. "" is the answer for a near miss -
## and the three real ones are named, so the whole table cannot go quiet at once and still pass.
const CLAIMED: Dictionary = {
	"awaits_with_nothing_between": "",
	"clamped_to_one_not_zero": "",
	"countdown_never_compared": "",
	"drag_flag_never_lowered": "",
	"friction_on_plain_node": "",
	"gravity_scale_on_node2d": "",
	"loop_that_keeps_but_never_measures": "",
	"loop_that_only_measures": "",
	"move_toward_wrong_arity": "",
	"nested_calls": "",
	"one_await_is_a_pause": "",
	"pop_back_without_guard": "",
	"push_back_on_plain_list": "",
	"raycast_without_target": "",
	"state_var_nobody_switches_on": "",
	"subtraction_that_is_not_delta": "",
	"table_entry_compared_to_zero": "",
	"unicode_strings": "",
	"whitespace_inside_the_clamp": "",
	"z_index_write": "",
	"real_countdown_with_notes_between": "countdown",
	"real_nearest_over_a_typed_loop": "picking",
	"real_sequence": "wait_sequence",
}

## The fixtures whose claims are checked for quotable evidence: one whose patterns come from lifted
## rows, one whose patterns come from raw lines, and one that lifts almost completely.
const EVIDENCE_FIXTURES: Array[String] = [
	"res://tests/fixtures/opened_script_batch8_systems.gd",
	"res://tests/fixtures/opened_script_batch9_behaviors.gd",
	"res://tests/fixtures/input_controls_fixture.gd",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_near_misses() and ok
	ok = _test_evidence_is_quotable() and ok
	return ok


static func _test_near_misses() -> bool:
	var ok: bool = true
	var names: Array = CASES.keys()
	names.sort()
	for entry: Variant in names:
		var case_name: String = str(entry)
		var source: String = str(CASES[case_name])
		var path: String = "user://strictness_%s.gd" % case_name
		var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		writer.store_string(source)
		writer.close()
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		ok = _check("%s re-emits byte-identically" % case_name,
			str(SheetCompiler.compile(sheet, path).get("output", "")), source) and ok
		var view: EventSheetViewport = _open(sheet)
		var _rows: Array = view.get_flat_rows()
		var claimed: PackedStringArray = PackedStringArray()
		for claim: Variant in EventSheetPatternFacts.claims(sheet):
			var pattern: String = str((claim as Dictionary).get("pattern", ""))
			# A blank sub-event is claimed on every tick body and shows no chip; the reader-facing
			# claims are the marked ones, so those are what is pinned.
			if EventSheetPatternVocabulary.is_marked(pattern) and not claimed.has(pattern):
				claimed.append(pattern)
		ok = _check("%s claims" % case_name, ", ".join(claimed), str(CLAIMED.get(case_name, "?"))) and ok
		view.free()
	return ok


static func _test_evidence_is_quotable() -> bool:
	var ok: bool = true
	var offenders: PackedStringArray = PackedStringArray()
	var said: int = 0
	for path: String in EVIDENCE_FIXTURES:
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		EventSheetPatternFacts.clear(sheet)
		EventSheetViewportReadingRows.claim_patterns(sheet)
		EventSheetViewportReadingRows.claim_godot_systems_patterns(sheet)
		EventSheetViewportReadingRows.claim_behavior_patterns(sheet)
		EventSheetViewportReadingRows.claim_behavior_shape_patterns(sheet)
		var owners: Dictionary = {}
		for claim: Variant in EventSheetPatternFacts.claims(sheet):
			owners[str((claim as Dictionary).get("row_uid", ""))] = true
		for owner: Variant in owners:
			var told: String = ViewportTooltipHelper.pattern_evidence_line(sheet, str(owner))
			if told.is_empty():
				continue
			said += 1
			for claim: Variant in EventSheetPatternFacts.claims_for_row(sheet, str(owner)):
				var ace_ids: PackedStringArray = (claim as Dictionary).get("ace_ids", PackedStringArray())
				for ace_id: String in ace_ids:
					if told.contains(ace_id):
						offenders.append("%s: %s is told the internal name %s" % [
							path.get_file(), str((claim as Dictionary).get("pattern", "")), ace_id])
	ok = _check("no pattern hover says an internal name out loud", ", ".join(offenders), "") and ok
	ok = _check("and the fixtures did say something", said > 0, true) and ok
	return ok


static func _open(sheet: EventSheetResource) -> EventSheetViewport:
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	return view


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_strictness_test: %s" % label)
		return true
	print("[FAIL] reading_strictness_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
