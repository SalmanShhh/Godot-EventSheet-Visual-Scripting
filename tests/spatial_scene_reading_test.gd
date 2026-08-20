@tool
class_name SpatialSceneReadingTest
extends RefCounted

# Pins the 3D words batch thirteen gave the sheet:
#
#   X4   orbiting, in both spellings - a camera pivot going round what it looks at, and the angle
#        written out as a cosine and a sine at a radius - plus a camera arm's length
#   X6   camera-relative locomotion: the five-line basis mix reads as ONE action, the fall under it
#        reads as a fall, and what a body is standing on reads as the shipped question
#   X7   an AnimationTree's magic parameter strings read as the object's Animation aspect
#   X8   what a mesh lets through - the visible-range band, see-through, the shadow switch - and the
#        two triggers a notifier raises when something comes into view and leaves again
#   X9   the world's look: the Environment object, and an effect parameter set everywhere
#   X19  UI that lives in the world: billboards, world size, a bar's width, an in-world screen
#
# Five gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row;
#   3. the pattern registry - each new shape claimed on the event that owns it;
#   4. the promise all of them rest on - the file still saves byte-identically;
#   5. PARITY - a row dropped from the picker reads exactly what the typed line reads, and compiles
#      back to exactly the line the reading recognises. Both directions, or the words drift.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions.

const SOURCE_PATH := "user://eventforge_spatial_words_reading.gd"

## X4's first spelling needs a SCENE: a `rotate_y` reads as an orbit only when the scene says the
## node it turns holds nothing but a camera rig. The fixture rig beside this file is that scene, and
## the facts walk reads it straight back out as text - nothing here instances anything.
const PIVOT_SCRIPT_PATH := "res://tests/fixtures/orbit_pivot_rig.gd"

const SOURCE: String = """extends CharacterBody3D

@onready var cam: Camera3D = $CameraPivot/Camera3D
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var horn: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var rock: MeshInstance3D = $Rock
@onready var env: Environment = $WorldEnvironment.environment
@onready var name_tag: Label3D = $NameTag
@onready var hp_bar: Sprite3D = $HpBar
@onready var panel_view: SubViewport = $Screen/SubViewport
@export var run_speed := 6.0
var moon_angle := 0.0
var moon_radius := 8.0
var moon: Node3D = null

func _physics_process(delta: float) -> void:
	var input := Input.get_vector(&"left", &"right", &"forward", &"back")
	var cam_basis := cam.global_transform.basis
	var dir := cam_basis.x * input.x + cam_basis.z * input.y
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed
	velocity.y -= 30.0 * delta

func circle_the_moon(delta: float) -> void:
	moon_angle += delta
	global_position = moon.global_position + Vector3(cos(moon_angle), 0.0, sin(moon_angle)) * moon_radius
	arm.spring_length = 6.0

func animate(pace: float) -> void:
	anim_tree.set("parameters/Locomotion/blend_position", pace)
	anim_state.travel("Jump")
	anim_tree.set("parameters/TimeScale/scale", 0.5)
	anim_tree.set("parameters/Shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func tune() -> void:
	horn.max_distance = 40.0
	horn.unit_size = 3.0
	rock.visibility_range_begin = 10.0
	rock.visibility_range_end = 90.0
	rock.transparency = 0.4
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func apply_dusk() -> void:
	env.fog_enabled = true
	env.fog_density = 0.02
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.ambient_light_energy = 0.3
	RenderingServer.global_shader_parameter_set("wind_strength", 2.0)

func dress_the_knight(hp: float) -> void:
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = true
	hp_bar.pixel_size = 0.004
	hp_bar.region_rect.size.x = hp
	panel_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
"""

## Every reading the opened file must contain, one per shape these items claim. The object is the
## class the script extends, because this file declares no class_name of its own.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# X6 - the five-line run is ONE action, and the fall under it says what it is
	"CharacterBody3D ▸ Move relative to the camera along input at run_speed (flattened to the ground)",
	"CharacterBody3D ▸ Fall at 30 (gravity)",
	# X4 - the angle written out, and the arm the camera hangs off
	"CharacterBody3D ▸ Orbit moon at radius moon radius angle moon angle (on the ground plane)",
	"arm ▸ Set camera distance to 6",
	# X7 - the blend tree, under the object's Animation aspect
	"CharacterBody3D ▸ Animation ▸ Set Locomotion blend to pace",
	"CharacterBody3D ▸ Animation ▸ Go to state \"Jump\"",
	"CharacterBody3D ▸ Animation ▸ Set animation speed to 0.5",
	"CharacterBody3D ▸ Animation ▸ Play one-shot animation Shoot",
	# X8 - the sound that carries, the band a mesh is drawn in, and the two switches
	"horn ▸ Set hearing distance to 40",
	"horn ▸ Set falloff to 3",
	"rock ▸ Visible from 10 to 90",
	"rock ▸ Set see-through to 40%",
	"rock ▸ Set shadows off",
	# X9 - the world's look, under the Environment object
	"Environment ▸ Set fog on",
	"Environment ▸ Set fog density to 0.02",
	"Environment ▸ Set glow on",
	"Environment ▸ Set glow strength to 0.4",
	"Environment ▸ Set ambient light to 30%",
	"System ▸ Set effect parameter wind strength to 2 (everywhere)",
	# X19 - UI standing in the world
	"name_tag ▸ Set always face the camera on",
	"name_tag ▸ Set show through walls on",
	"hp_bar ▸ Set world size to 0.004 (per pixel)",
	"hp_bar ▸ Set bar width to hp",
	"panel_view ▸ Set redraw only when seen"
])

## Readings the file must NOT contain: the words each shape replaced. A reading that silently
## stopped firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	# X6 - the four lines the run swallowed, each a perfectly good row on its own before it
	"dir ▸ Set y to 0",
	"CharacterBody3D ▸ Set velocity X to dir X * run_speed",
	"CharacterBody3D ▸ Subtract 30 * dt from velocity Y",
	# X8 / X9 / X19 - the property writes these readings renamed
	"horn ▸ Set max distance to 40",
	"rock ▸ Set transparency to 0.4",
	"env ▸ Set fog enabled to true",
	"name_tag ▸ Set no depth test to true"
])

## The statements whose sentence these items settle, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# X4 - the angle written out, its plane named by the axis the circle is flat against
	"global_position = target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius":
		"Player ▸ Orbit target at radius radius angle angle (on the ground plane)",
	"global_position = target.global_position + Vector3(cos(a), sin(a), 0.0) * 4.0":
		"Player ▸ Orbit target at radius 4 angle a (on the upright plane)",
	"arm.spring_length = 6.0": "arm ▸ Set camera distance to 6",
	# X7 - the three parameter roles, and the state machine's own step
	"anim_tree.set(\"parameters/Locomotion/blend_position\", pace)":
		"Player ▸ Animation ▸ Set Locomotion blend to pace",
	"anim_tree.set(\"parameters/TimeScale/scale\", 0.5)":
		"Player ▸ Animation ▸ Set animation speed to 0.5",
	"anim_tree.set(\"parameters/Shoot/request\", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)":
		"Player ▸ Animation ▸ Play one-shot animation Shoot",
	"anim_state.travel(\"Jump\")": "Player ▸ Animation ▸ Go to state \"Jump\"",
	# X8 - the seen-and-heard distances and switches
	"rock.transparency = 0.4": "rock ▸ Set see-through to 40%",
	"rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF": "rock ▸ Set shadows off",
	"rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON": "rock ▸ Set shadows on",
	"rock.visibility_range_begin = 10.0": "rock ▸ Set visible from 10",
	"rock.visibility_range_end = 90.0": "rock ▸ Set visible until 90",
	# X9 - the environment block, reached both ways
	"env.fog_enabled = true": "Environment ▸ Set fog on",
	"env.fog_enabled = false": "Environment ▸ Set fog off",
	"env.fog_light_color = Color(0.7, 0.6, 0.8)": "Environment ▸ Set fog colour to 0.7, 0.6, 0.8",
	"env.ssao_enabled = true": "Environment ▸ Set ambient occlusion on",
	"$WorldEnvironment.environment.ambient_light_energy = 0.3":
		"Environment ▸ Set ambient light to 30%",
	"RenderingServer.global_shader_parameter_set(\"wind_strength\", 2.0)":
		"System ▸ Set effect parameter wind strength to 2 (everywhere)",
	"rock.set_instance_shader_parameter(\"tint\", 0.5)": "rock ▸ Set effect parameter tint to 0.5",
	# X19 - the world-space UI knobs
	"name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED":
		"name_tag ▸ Set always face the camera on",
	"name_tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y":
		"name_tag ▸ Set always face the camera on (upright)",
	"name_tag.billboard = BaseMaterial3D.BILLBOARD_DISABLED":
		"name_tag ▸ Set always face the camera off",
	"name_tag.no_depth_test = true": "name_tag ▸ Set show through walls on",
	"hp_bar.pixel_size = 0.004": "hp_bar ▸ Set world size to 0.004 (per pixel)",
	"hp_bar.region_rect.size.x = hp": "hp_bar ▸ Set bar width to hp",
	"panel_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE":
		"panel_view ▸ Set redraw only when seen",
	"panel_view.push_input(click)": "panel_view ▸ Send input click (UI on a surface)"
}

## The questions these items settle, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	"is_on_floor()": "Player ▸ Is on floor",
	"is_on_wall()": "Player ▸ Is by wall",
	"anim_state.get_current_node() == \"Land\"": "Player ▸ Animation ▸ Current state is \"Land\"",
	"anim_state.get_current_node() != \"Land\"": "Player ▸ not Animation ▸ Current state is \"Land\""
}

## The shapes that must NOT be claimed. Every one of them is ALMOST one of the readings above, and a
## reading that is almost right is worse than the code it replaced.
static var REFUSED_STATEMENTS: PackedStringArray = PackedStringArray([
	# X8 / X19 - the general property spellings, on a class that is not one of these families
	"crate.transparency = 0.4",
	"crate.pixel_size = 0.004",
	# X9 - a fog knob on something that is not an environment
	"crate.fog_density = 0.02"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _orbit_pivot_needs_the_scene() and ok
	var opened: Dictionary = _open_and_read()
	var readings: PackedStringArray = opened.get("readings", PackedStringArray())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _pattern_claims(opened.get("patterns", {})) and ok
	ok = _round_trip() and ok
	ok = _picked_matches_typed() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] spatial_words_reading_test: %s" % label)
		return true
	print("[FAIL] spatial_words_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened 3D script hands the grammar: what the script is, and what class
## each of its object variables was declared as.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "CharacterBody3D",
		"object_classes": {
			"arm": "SpringArm3D", "anim_tree": "AnimationTree",
			"anim_state": "AnimationNodeStateMachinePlayback",
			"horn": "AudioStreamPlayer3D", "rock": "MeshInstance3D", "env": "Environment",
			"name_tag": "Label3D", "hp_bar": "Sprite3D", "panel_view": "SubViewport",
			"target": "Node3D", "crate": "Node3D"
		},
		"engine_properties": {"global_position": true, "position": true, "velocity": true}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code, _joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	for expression: String in CONDITION_READINGS:
		ok = _check("condition %s" % expression,
			_joined_pieces(EventSheetSentence.condition_pieces(expression, context)),
			str(CONDITION_READINGS[expression])) and ok
	for refused: String in REFUSED_STATEMENTS:
		ok = _check("refused %s" % refused,
			EventSheetSentence.statement(refused, context).has("pattern"), false) and ok
	# The two shapes that are ALMOST an orbit keep whatever reading they always had - an offset added
	# to another object's place is the Pin it was - so what is pinned here is that neither of them is
	# claimed as an orbit. An ellipse has no one word, and a constant offset is not a circle.
	for not_an_orbit: String in [
			"global_position = target.global_position + Vector3(cos(a), 0.0, sin(b)) * radius",
			"global_position = target.global_position + Vector3(0.0, 2.0, 0.0)"]:
		ok = _check("not an orbit: %s" % not_an_orbit,
			str(EventSheetSentence.statement(not_an_orbit, context).get("pattern", "")) == "orbit",
			false) and ok
	# The pattern each reading carries, which is the only thing the registry is filled from.
	ok = _check("an orbit claims the orbit pattern",
		str(EventSheetSentence.statement(
			"global_position = target.global_position + Vector3(cos(a), 0.0, sin(a)) * 8.0", context)
			.get("pattern", "")), "orbit") and ok
	ok = _check("and offers the pack that does the whole shape",
		str(EventSheetSentence.statement(
			"global_position = target.global_position + Vector3(cos(a), 0.0, sin(a)) * 8.0", context)
			.get("adoptable", "")), "orbit_3d") and ok
	ok = _check("a fall claims the movement pattern",
		str(EventSheetSentence.statement("velocity.y -= 30.0 * delta", context).get("pattern", "")),
		"movement") and ok
	ok = _check("a world-space UI knob claims its own pattern",
		str(EventSheetSentence.statement("name_tag.no_depth_test = true", context).get("pattern", "")),
		"worldspace_ui") and ok
	ok = _check("an environment knob claims the lighting pattern",
		str(EventSheetSentence.statement("env.fog_enabled = true", context).get("pattern", "")),
		"lighting") and ok
	# X6 - the run recognised piece by piece, which is what the row builder's pass is built on.
	ok = _check("a camera's basis names the camera",
		EventSheetSentence.camera_basis_source("cam.global_transform.basis"), "cam") and ok
	ok = _check("the basis mix names the input vector",
		EventSheetSentence.camera_basis_mix_input(
			"(cam_basis.x * input.x + cam_basis.z * input.y)", "cam_basis"), "input") and ok
	ok = _check("a mix off two different bases is refused",
		EventSheetSentence.camera_basis_mix_input(
			"cam_basis.x * input.x + other.z * input.y", "cam_basis"), "") and ok
	ok = _check("a mix driven by two different inputs is refused",
		EventSheetSentence.camera_basis_mix_input(
			"cam_basis.x * input.x + cam_basis.z * other.y", "cam_basis"), "") and ok
	ok = _check("the flatten line is recognised",
		EventSheetSentence.is_flatten_line("dir.y = 0.0", "dir"), true) and ok
	ok = _check("a velocity step names the speed it moves at",
		EventSheetSentence.velocity_step_speed("velocity.x = dir.x * speed", "dir"), "speed") and ok
	ok = _check("a velocity step off another direction is refused",
		EventSheetSentence.velocity_step_speed("velocity.x = other.x * speed", "dir"), "") and ok
	# X8 - the two triggers, in both spellings a trigger arrives in.
	ok = _check("coming into view is a trigger the sheet has words for",
		EventSheetSentence.view_trigger_words("signal:screen_entered"), "On entered view") and ok
	ok = _check("and leaving it again is the other half",
		EventSheetSentence.view_trigger_words("OnScreenExited"), "On left view") and ok
	ok = _check("an ordinary signal keeps its own words",
		EventSheetSentence.view_trigger_words("signal:died"), "") and ok
	return ok


## X4. The pivot reading is gated on the SCENE, and this is the gate: the SAME `rotate_y` line reads
## as an orbit on the node whose only child is a camera arm, and as the plain rotate it is on the
## node holding a crate. Both nodes live in one fixture scene, so nothing about the line itself can
## be what tells them apart.
static func _orbit_pivot_needs_the_scene() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PIVOT_SCRIPT_PATH)
	var pivots: Dictionary = EventSheetViewportReadingRows.orbit_pivot_map(sheet)
	ok = _check("the scene says which node is a camera pivot",
		bool(pivots.get("pivot", false)), true) and ok
	ok = _check("and a node holding anything else is not one",
		bool(pivots.get("plain", false)), false) and ok
	var context: Dictionary = _context().merged({
		"orbit_pivots": pivots,
		"object_classes": {"pivot": "Node3D", "plain": "Node3D"}
	}, true)
	ok = _check("turning the pivot reads as an orbit",
		_joined_segments(EventSheetSentence.statement("pivot.rotate_y(-relative.x * 0.005)", context)),
		"pivot ▸ Orbit around its centre by -relative.x * 0.005 (yaw)") and ok
	ok = _check("and it offers the pack that ships the shape",
		str(EventSheetSentence.statement("pivot.rotate_y(-relative.x * 0.005)", context)
			.get("adoptable", "")), "orbit_3d") and ok
	ok = _check("turning anything else keeps the plain rotate",
		EventSheetSentence.statement("plain.rotate_y(-relative.x * 0.005)", context).has("pattern"),
		false) and ok
	return ok


## One condition reading as "object ▸ sentence", or the bare sentence when no object is named.
static func _joined_pieces(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## Writes the source, opens it as a sheet, walks every row and returns {readings, patterns}.
static func _open_and_read() -> Dictionary:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	return _render(sheet)


## Every cell of a sheet as "object ▸ text", plus {pattern id: how many events claimed it}.
static func _render(sheet: EventSheetResource) -> Dictionary:
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	# A cell is several SPANS - the sentence, then the muted half-word after it - and a sentence with
	# a note could never be pinned span by span. The spans of one cell share a lane and a line index,
	# so those two are what group them back into the line a reader sees.
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		var cells: Dictionary = {}
		var order: Array = []
		for span: SemanticSpan in row_data.spans:
			var key: String = "%s|%d" % [str(span.metadata.get("lane", "")),
				int(span.metadata.get("line_index", 0))]
			if not cells.has(key):
				cells[key] = {"object": "", "text": ""}
				order.append(key)
			var cell: Dictionary = cells[key]
			var span_object: String = str(span.metadata.get("object_label", ""))
			if str(cell["object"]).is_empty():
				cell["object"] = span_object
			cell["text"] = str(cell["text"]) + span.text
		for key: Variant in order:
			var cell: Dictionary = cells[key]
			if not str(cell["text"]).strip_edges().is_empty():
				readings.append(_labelled(str(cell["object"]), str(cell["text"])))
	var patterns: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
	viewport.free()
	return {"readings": readings, "patterns": patterns}


static func _labelled(object_label: String, text: String) -> String:
	var body: String = text.strip_edges()
	return "%s ▸ %s" % [object_label, body] if not object_label.is_empty() else body


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Gate three: each new shape is claimed in the registry, on the event that owns it.
static func _pattern_claims(patterns: Dictionary) -> bool:
	var ok: bool = true
	ok = _check("the orbit pattern is claimed on the function that circles",
		int(patterns.get("orbit", 0)) > 0, true) and ok
	ok = _check("the world-space UI pattern is claimed on the function that dresses the knight",
		int(patterns.get("worldspace_ui", 0)) > 0, true) and ok
	ok = _check("the lighting pattern is claimed for the environment block",
		int(patterns.get("lighting", 0)) > 0, true) and ok
	ok = _check("and the camera-relative run claims movement",
		int(patterns.get("movement", 0)) > 0, true) and ok
	return ok


## Gate four: every reading here is a lens over a value the row already holds, so opening the file
## and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## Gate five - the parity promise, in both directions. Each authored row must COMPILE to exactly the
## line its reading recognises, and must READ as the sentence the typed line reads. A row that only
## managed one of the two would be a word the sheet can say but not write back, or write but not read.
static func _picked_matches_typed() -> bool:
	var ok: bool = true
	var emitted: Dictionary = {
		"OrbitAtRadius": "global_position = target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 8.0",
		"SetCameraDistance": "spring_length = 6.0",
		"PlayOneShotAnimation": "set(\"parameters/Shoot/request\", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)",
		"AudioSetHearingDistance3D": "max_distance = 40.0",
		"AudioSetLoudnessFalloff": "unit_size = 3.0",
		"SetVisibleRange": "visibility_range_begin = 10.0\nvisibility_range_end = 90.0",
		"SetSeeThrough": "transparency = 0.4",
		"SetShadowsOff3D": "cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF",
		"SetFaceTheCamera": "$NameTag.billboard = BaseMaterial3D.BILLBOARD_ENABLED",
		"SetShowThroughWalls": "$NameTag.no_depth_test = true",
		"SetWorldSize": "$HpBar.pixel_size = 0.004",
		"SetBarWidth": "$HpBar.region_rect.size.x = hp",
		"SetSurfaceRedraw": "render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE",
		"SetFog": "$WorldEnvironment.environment.fog_enabled = true",
		"SetFogDensity": "$WorldEnvironment.environment.fog_density = 0.02",
		"SetGlow": "$WorldEnvironment.environment.glow_enabled = true",
		"AnimationStateIs": "get(\"parameters/playback\").get_current_node() == \"Idle\""
	}
	var params: Dictionary = {
		"OrbitAtRadius": {"centre": "target", "radius": "8.0", "angle": "angle"},
		"SetCameraDistance": {"value": "6.0"},
		"PlayOneShotAnimation": {"name": "Shoot"},
		"AudioSetHearingDistance3D": {"value": "40.0"},
		"AudioSetLoudnessFalloff": {"value": "3.0"},
		"SetVisibleRange": {"near": "10.0", "far": "90.0"},
		"SetSeeThrough": {"value": "0.4"},
		"SetShadowsOff3D": {},
		"SetFaceTheCamera": {"node": "$NameTag"},
		"SetShowThroughWalls": {"node": "$NameTag", "on": "true"},
		"SetWorldSize": {"node": "$HpBar", "value": "0.004"},
		"SetBarWidth": {"node": "$HpBar", "width": "hp"},
		"SetSurfaceRedraw": {"mode": "UPDATE_WHEN_VISIBLE"},
		"SetFog": {"env": "$WorldEnvironment.environment", "on": "true"},
		"SetFogDensity": {"env": "$WorldEnvironment.environment", "value": "0.02"},
		"SetGlow": {"env": "$WorldEnvironment.environment", "on": "true"},
		"AnimationStateIs": {"state": "\"Idle\""}
	}
	for ace_id: String in emitted:
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = ace_id
		action.params = params[ace_id]
		var line: String = ActionCodegen.generate_action(action) if ace_id != "AnimationStateIs" \
			else _condition_code(ace_id, params[ace_id])
		ok = _check("%s emits the line its reading recognises" % ace_id, line.strip_edges(),
			str(emitted[ace_id])) and ok
	# And the other direction: the picked rows, rendered through the canvas, say what the typed lines
	# say. The sheet is hosted on the world-space label, so the host-scoped rows have an object.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Label3D"
	sheet.custom_class_name = "NameTag"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.actions.append(_action("SetFaceTheCamera", {"node": "self"}))
	event_row.actions.append(_action("SetWorldSize", {"node": "self", "value": "0.004"}))
	event_row.actions.append(_action("SetSeeThrough", {"value": "0.4"}))
	event_row.actions.append(_action("SetFogDensity",
		{"env": "$WorldEnvironment.environment", "value": "0.02"}))
	sheet.events.append(event_row)
	var readings: PackedStringArray = _render(sheet).get("readings", PackedStringArray())
	for expected: String in ["NameTag ▸ Set always face the camera on",
			"NameTag ▸ Set world size to 0.004 (per pixel)", "NameTag ▸ Set see-through to 40%",
			"Environment ▸ Set fog density to 0.02"]:
		ok = _check("picked row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## The GDScript one CONDITION row stands for, which the codegen spells differently from an action.
static func _condition_code(ace_id: String, params: Dictionary) -> String:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return ConditionCodegen.generate_condition(condition)


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action
