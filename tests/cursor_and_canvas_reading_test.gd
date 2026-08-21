@tool
class_name CursorAndCanvasReadingTest
extends RefCounted

# Pins batch thirteen's cursor-and-canvas readings and the words that author them:
#
#   X2   the camera-ray run - project_ray_origin, project_ray_normal, the query, intersect_ray -
#        reads as ONE row asking what is under the cursor, with the reach and the folded empty-check
#        as its muted note; a ray hit's own entries read as what they mean
#   X20  canvas space - the canvas centre, a position ON THE CANVAS in either dimension, a distance
#        between two canvas points named in PIXELS, whether a point is behind the camera, the world
#        point under a canvas point at a depth, and an arrow clamped to the canvas edge
#   X30  the same run aimed through a crosshair object and restricted to a layer mask, and the three
#        aimed-floor expressions the picker writes, which share ONE emitted helper per file
#
# Six gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - three hand-written files opened as sheets, walked row by row;
#   3. the shapes that must NOT be claimed, because an almost-right reading is worse than the code;
#   4. the pattern registry - each new shape claimed on the function that owns it;
#   5. the promise all of them rest on - every file still saves byte-identically;
#   6. the authoring half - what the picker writes reads back as the sentence it offered, and the
#      shared helper is emitted exactly once however many of the words a file uses.
#
# The sources live here as strings rather than in tests/fixtures/ for the same reason their sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions.

const X2_PATH := "user://eventforge_cursor_ray_reading.gd"
const X20_PATH := "user://eventforge_canvas_reading.gd"
const X30_PATH := "user://eventforge_aimed_floor_reading.gd"

## X2. The four-line run every 3D tool writes, with the branch that clears what it found.
const X2_SOURCE: String = """extends Node3D

@onready var cam: Camera3D = $Camera3D
var hovered: Node3D = null

func _pick(mouse_pos: Vector2) -> void:
	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 1000.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		hovered = null
		return
	hovered = hit.collider
"""

## X20. The nearest-to-crosshair walk, and the 2D twin that asks where a node is on the canvas.
const X20_SOURCE: String = """extends Node3D

@onready var cam: Camera3D = $Camera3D
@export var assist_radius := 48.0
var best: Node3D = null

func _aim_assist(enemies: Array) -> void:
	var centre := get_viewport().get_visible_rect().size / 2.0
	var best_d := assist_radius
	best = null
	for e in enemies:
		if cam.is_position_behind(e.global_position):
			continue
		var on_screen := cam.unproject_position(e.global_position)
		var d := centre.distance_to(on_screen)
		if d < best_d:
			best_d = d
			best = e

func _screen_pos(o: Node2D) -> Vector2:
	return o.get_global_transform_with_canvas().origin
"""

## X30. The same run aimed through a crosshair object and filtered to one layer.
const X30_SOURCE: String = """extends Node3D

@onready var cam: Camera3D = $Camera3D
@onready var crosshair: Sprite2D = $HUD/Crosshair

func _aim() -> Dictionary:
	var from := cam.project_ray_origin(crosshair.get_global_transform_with_canvas().origin)
	var dir := cam.project_ray_normal(crosshair.get_global_transform_with_canvas().origin)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	return {"point": hit.position, "object": hit.collider, "normal": hit.normal}
"""

## Every reading the three opened files must contain, one per shape these items claim.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# X2 - four lines of plumbing, one row, and the branch under it folded into the note.
	"System ▸ Set hit to the object under the cursor",
	"reach 1000 · none when nothing is hit",
	"System ▸ Set hovered to the object under the cursor",
	# X20 - the canvas words, each one the sentence its ACE writes.
	"= the canvas centre",
	"= e's position on the canvas",
	"= the canvas distance from centre to on_screen (pixels)",
	"e ▸ is behind the camera",
	"System ▸ Return o's position on the canvas",
	# X30 - the aimed, filtered run, with the layer it may see said in the note.
	"System ▸ Set hit to the object under crosshair",
	"on layer 1, reach 500 · none when nothing is hit"
])

## Readings the files must NOT contain: the plumbing each shape replaced. A reading that silently
## stopped firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"= cam.project_ray_origin(mouse_pos)",
	"= world_3d.direct_space_state.intersect_ray(query)",
	"= cam.unproject_position(e.global_position)",
	"= distance from centre to on_screen",
	"System ▸ cam.is_position_behind(e's global position)"
])

## The values these items name, and what the sheet calls them. A ray HIT's entries only read this way
## on a file that CAST one - the context below is what that file's own walk answered.
static var EXPRESSION_READINGS: Dictionary = {
	"cam.unproject_position(e.global_position)": "e's position on the canvas",
	"o.get_global_transform_with_canvas().origin": "o's position on the canvas",
	"get_screen_transform() * e.global_position": "e's position on the canvas",
	"get_viewport().get_visible_rect().size / 2.0": "the canvas centre",
	"get_viewport_rect().size * 0.5": "the canvas centre",
	"centre.distance_to(on_screen)": "the canvas distance from centre to on_screen (pixels)",
	"cam.project_position(on_screen, 12.0)": "the world point under on_screen at depth 12",
	"hit.position": "where the cursor touches the world",
	"hit.normal": "the surface's facing there",
	"hit.collider": "the object under the cursor",
	# X30 - what the picker writes, read back as the sentence it offered.
	"__eventsheets_aim_floor(get_viewport().get_mouse_position(), 1, 500.0).get(\"position\", Vector3.ZERO)":
		"the floor point under the cursor",
	"__eventsheets_aim_floor(get_viewport().get_mouse_position(), 1, 500.0).get(\"collider\", null)":
		"the floor object under the cursor",
	"__eventsheets_aim_floor(crosshair.get_global_transform_with_canvas().origin, 1, 500.0).get(\"normal\", Vector3.UP)":
		"the floor's slope under crosshair"
}

## The questions these items settle, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	"cam.is_position_behind(e.global_position)": "e ▸ is behind the camera",
	"rad_to_deg(hit.normal.angle_to(Vector3.UP)) > 30": "System ▸ slope steeper than 30°"
}

## The shapes that must NOT be claimed: a distance between two WORLD points (the bug naming canvas
## distance apart exists to prevent), a half of a ray with no query built from it, and a rectangle
## divided by something that is not two.
static var REFUSED_EXPRESSIONS: PackedStringArray = PackedStringArray([
	"a.distance_to(b)",
	"get_viewport().get_visible_rect().size / 3.0"
])


static func run() -> bool:
	var ok: bool = true

	# The helper is appended for CALLS only. A file that merely NAMES the helper inside a string
	# literal - a pattern table, a doc - must reopen byte-identically; injecting the definition
	# there broke the lossless contract on the grammar file itself once.
	ok = _check("a string literal naming the helper earns no injection",
		EventSheets.round_trips("extends Node


var table: Dictionary = {\"call\": \"__eventsheets_aim_floor(\"}
"), true) and ok
	ok = _grammar_values() and ok
	var readings: PackedStringArray = PackedStringArray()
	var patterns: Dictionary = {}
	for entry: Array in [[X2_PATH, X2_SOURCE], [X20_PATH, X20_SOURCE], [X30_PATH, X30_SOURCE]]:
		var opened: Dictionary = _open_and_read(str(entry[0]), str(entry[1]))
		readings.append_array(opened.get("readings", PackedStringArray()))
		for pattern: Variant in (opened.get("patterns", {}) as Dictionary):
			patterns[pattern] = int(patterns.get(pattern, 0)) \
				+ int((opened["patterns"] as Dictionary)[pattern])
	for expected: String in EXPECTED_READINGS:
		ok = _check("an opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	# Two files cast a ray, and each claim is made by BOTH passes that may claim - the file's own walk
	# (which owns the function) and the row builder's span pass (which owns the row). The registry
	# dedupes per row, so two files answer four claims, and a pass that stopped claiming would show
	# here as two.
	ok = _check("the cursor's ray is claimed on both functions that cast one, by both passes",
		int(patterns.get("cursor_ray", 0)), 4) and ok
	ok = _check("the canvas pick is claimed on the function that walks the enemies",
		int(patterns.get("aim_assist", 0)), 1) and ok
	ok = _round_trip() and ok
	ok = _authoring() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] cursor_and_canvas_reading_test: %s" % label)
		return true
	print("[FAIL] cursor_and_canvas_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened 3D script hands the grammar, including the two maps this item's own
## walk fills: the locals a cursor ray filled, and the locals holding a canvas point.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "Node3D",
		"object_classes": {"cam": "Camera3D", "e": "Node3D", "o": "Node2D", "crosshair": "Sprite2D"},
		"engine_properties": {"position": true, "global_position": true},
		"cursor_rays": {"hit": {"reach": "1000.0", "aimed_at": "", "mask": "", "cleared": true}},
		"canvas_points": {"centre": true, "on_screen": true}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for value: String in EXPRESSION_READINGS:
		ok = _check("expression %s" % value, EventSheetSentence.expression_text(value, context),
			str(EXPRESSION_READINGS[value])) and ok
	for question: String in CONDITION_READINGS:
		ok = _check("condition %s" % question,
			_joined_pieces(EventSheetSentence.condition_pieces(question, context)),
			str(CONDITION_READINGS[question])) and ok
	for refused: String in REFUSED_EXPRESSIONS:
		ok = _check("refused %s" % refused,
			EventSheetSentence.canvas_expression_words(refused, context), "") and ok
	# X2 - the run recognised step by step, and the far end that says how far it reaches.
	ok = _check("the ray's start is recognised",
		str(EventSheetSentence.cursor_ray_step_parts("cam.project_ray_origin(mouse_pos)").get("step", "")),
		"project_ray_origin") and ok
	ok = _check("the cast reached through the world is recognised",
		str(EventSheetSentence.cursor_ray_step_parts(
			"get_world_3d().direct_space_state.intersect_ray(query)").get("query", "")), "query") and ok
	ok = _check("the far end of a ray says how far it reaches",
		EventSheetSentence.cursor_ray_reach("origin + dir * 1000.0", "origin", "dir"), "1000.0") and ok
	ok = _check("a ray to a FIXED point is not a reach at all",
		EventSheetSentence.cursor_ray_reach("target.global_position", "origin", "dir"), "") and ok
	ok = _check("a ray between two places is the sight question it is",
		EventSheetSentence.fixed_point_ray_words("muzzle", "target.global_position", context),
		"the first object between muzzle and target.global_position") and ok
	# X30 - the note, in the project's own layer words when the mask names them and its own value
	# otherwise, so a mask nobody named still reads honestly.
	ok = _check("the note says the reach and the layers the ray may see",
		EventSheetSentence.cursor_ray_note("500.0", "1", EventSheetSentence.PHYSICS_DIMENSION_3D, context),
		"on layer 1, reach 500") and ok
	ok = _check("a run nobody filtered says only how far it reaches",
		EventSheetSentence.cursor_ray_note("1000.0", "", EventSheetSentence.PHYSICS_DIMENSION_3D, context),
		"reach 1000") and ok
	# X20 - an off-screen arrow, pinned inside the view.
	ok = _check("an arrow at the edge says it is clamped there",
		EventSheetSentence.canvas_expression_words(
			"cam.unproject_position(e.global_position).clamp(Vector2(48, 48), Vector2(1872, 1032))",
			context),
		"e's position on the canvas clamped to the canvas edge") and ok
	return ok


## One condition reading as "object ▸ sentence", or the bare sentence when no object is named.
static func _joined_pieces(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## Writes a source, opens it as a sheet, walks every row and returns {readings, patterns} - the cell
## readings as "object ▸ text", and {pattern id: how many rows claimed it}.
static func _open_and_read(path: String, source: String) -> Dictionary:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	var patterns: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
	viewport.free()
	return {"readings": readings, "patterns": patterns}


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Gate five: every reading here is a lens over a value the row already holds, so opening each file
## and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var ok: bool = true
	for entry: Array in [[X2_PATH, X2_SOURCE], [X20_PATH, X20_SOURCE], [X30_PATH, X30_SOURCE]]:
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(str(entry[0]))
		var output: String = str(SheetCompiler.compile(sheet, str(entry[0])).get("output", ""))
		ok = _check("opening %s and saving it reproduces every byte" % str(entry[0]),
			output, str(entry[1])) and ok
	return ok


## Gate six: the authoring half. Every new word's template is what the reading recognises, and the
## shared helper is written into the file ONCE however many of the aimed-floor words a file uses -
## which is the whole reason they call a helper instead of each spelling the ray out.
static func _authoring() -> bool:
	var ok: bool = true
	for pair: Array in [["MouseFloorPoint", "the floor point under the cursor"],
			["MouseFloorObject", "the floor object under the cursor"],
			["MouseFloorSlope", "the floor's slope under the cursor"]]:
		var descriptor: ACEDescriptor = _descriptor(str(pair[0]))
		var written: String = str(descriptor.codegen_template).replace("{layer}", "1").replace("{reach}", "500.0")
		ok = _check("%s writes what the reading recognises" % str(pair[0]),
			EventSheetSentence.expression_text(written, _context()), str(pair[1])) and ok
	# The picker's own words for the two cursor questions, so a sheet says them the same way in 2D
	# and in 3D. Pinned by VALUE because they are the strings a reader sees on the row.
	ok = _check("the hover question is the sheet's own Mouse word",
		_descriptor("CursorIsOverObject3D").display_text, "cursor is over {object}") and ok
	ok = _check("the click question reads as the trigger it is",
		_descriptor("OnObjectClicked3D").display_text, "On {object} clicked") and ok
	# There is no Canvas Distance VERB on purpose: the shipped Distance Between already writes that
	# exact line, and a second ACE spelling it identically would shadow it in the reverse-lifter. What
	# the canvas needs is a name, and the reading supplies it - so this gate is that the verb stays
	# absent while the sentence keeps working (pinned in the expression table above).
	ok = _check("no second verb shadows the shipped distance spelling",
		_descriptor("CanvasDistance").ace_id, "") and ok
	ok = _check("the canvas pick says which point it measures from",
		_descriptor("PickNearestToCanvasPoint").display_text,
		"pick nearest of [i]{list}[/i] to canvas point {from} -> [b]{name}[/b]") and ok
	# One helper, however many of the words the file uses - and the SAME one whichever wrote it.
	var emitted: String = _compile_with(["MouseFloorPoint", "MouseFloorSlope"])
	ok = _check("the shared helper is written into the file exactly once",
		emitted.count("func %s(" % SheetCompiler.AIMED_CURSOR_HELPER), 1) and ok
	ok = _check("a file that asks only for the slope gains the very same helper",
		_helper_body(_compile_with(["MouseFloorSlope"])),
		_helper_body(_compile_with(["MouseFloorPoint"]))) and ok
	ok = _check("a file that asks for none of them gains no helper at all",
		_compile_with([]).contains("func %s(" % SheetCompiler.AIMED_CURSOR_HELPER), false) and ok
	return ok


## One shipped descriptor by id, so a rename would fail here rather than silently.
static func _descriptor(ace_id: String) -> ACEDescriptor:
	for descriptor: ACEDescriptor in EventForgeCursorCanvasACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor
	return ACEDescriptor.new()


## A one-event sheet whose actions each store one of the named expressions, compiled.
static func _compile_with(ace_ids: Array) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = "aimhelper"
	for index: int in ace_ids.size():
		var descriptor: ACEDescriptor = _descriptor(str(ace_ids[index]))
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "SetVar"
		action.params = {
			"var_name": "aimed_%d" % index,
			"value": str(descriptor.codegen_template).replace("{layer}", "1").replace("{reach}", "500.0")
		}
		event_row.actions.append(action)
	sheet.events.append(event_row)
	return str(SheetCompiler.compile(sheet, "user://eventforge_aim_helper_emitted.gd").get("output", ""))


## Just the helper's own lines out of an emitted file, so two files can be compared on the ONE thing
## this gate is about rather than on the rows around it.
static func _helper_body(emitted: String) -> String:
	var head: String = "func %s(" % SheetCompiler.AIMED_CURSOR_HELPER
	var body: PackedStringArray = PackedStringArray()
	var inside: bool = false
	for line: String in emitted.split("\n"):
		if line.begins_with(head):
			inside = true
		elif inside and not line.begins_with("\t"):
			inside = false
		if inside:
			body.append(line)
	return "\n".join(body)
