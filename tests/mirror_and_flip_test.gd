# Y19 / Y20 / Y21 - mirror and flip, on every host that can do it.
#
# Six gates, each pinning VALUES:
#   1. the readings - every spelling of "this thing faces the other way", in the sheet's own words
#   2. the refusals - what these readings must NOT claim, the plain `scale.x = 2` above all
#   3. the authoring half - the host table's ace ids, templates and hosts
#   4. the two-way byte gate - a file of these lines opens as rows and saves back byte-identically
#   5. the Doctor - the two notes mirroring earns, and the quick fix each one offers
#   6. the pattern - every one of these readings claims "facing", with its own line as the evidence
@tool
class_name MirrorAndFlipTest
extends RefCounted

const SOURCE_PATH := "user://eventforge_mirror_and_flip.gd"

## The objects an opened file's head declares, the way the readings see them.
static var CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"self_class": "CharacterBody2D",
	"object_classes": {
		"sprite": "Sprite2D",
		"body": "Node2D",
		"mesh": "Node3D",
		"panel": "PanelContainer",
		"ray": "RayCast2D",
		"muzzle": "Marker2D",
		"dust": "GPUParticles2D",
		"plate": "Label",
		"anim_tree": "AnimationTree",
		"target": "Node2D",
		"other": "Node2D",
		"camera": "Camera2D",
		"tiles": "TileMapLayer"
	}
}

## Gate 1. Every mirroring statement, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# Y19 - the whole object, said four ways
	"body.scale.x = -1.0": "body ▸ Set mirrored (whole object)",
	"body.scale.x = 1.0": "body ▸ Set not mirrored (whole object)",
	"body.scale.x = -body.scale.x": "body ▸ Set mirrored (whole object)",
	"body.scale.x = -1.0 if velocity.x < 0.0 else 1.0":
		"body ▸ Set mirrored to moving left (whole object)",
	"body.scale.x = -1.0 if velocity.x > 0.0 else 1.0":
		"body ▸ Set mirrored to moving right (whole object)",
	"body.scale.x = sign(velocity.x)": "body ▸ Set mirrored to moving left (whole object)",
	"body.scale.x = -1.0 if target.global_position.x < global_position.x else 1.0":
		"body ▸ Set mirrored to target is to the left (whole object)",
	"body.scale.x = -1.0 if target.global_position.x > global_position.x else 1.0":
		"body ▸ Set mirrored to target is to the right (whole object)",
	# Y19 - the host the note changes for
	"mesh.scale.x = -mesh.scale.x": "mesh ▸ Set mirrored (flips the mesh's winding)",
	"panel.scale.x = -1.0": "panel ▸ Set mirrored (UI)",
	# Y19 - the flag hosts, and the value that decides it
	"sprite.flip_h = true": "sprite ▸ Set mirrored",
	"sprite.flip_h = dir < 0": "sprite ▸ Set mirrored when dir < 0",
	"sprite.flip_h = facing_left": "sprite ▸ Set mirrored to facing left",
	"sprite.flip_v = is_upside_down": "sprite ▸ Set flipped to is upside down",
	# Y19 - the honest 3D turn
	"mesh.rotate_y(PI)": "mesh ▸ Turn around",
	"mesh.rotate_y(deg_to_rad(180))": "mesh ▸ Turn around",
	# Y20 - what has to come along
	"ray.target_position.x = absf(ray.target_position.x) * signf(scale.x)":
		"ray ▸ Ray follows facing",
	"muzzle.position.x = absf(muzzle.position.x) * signf(scale.x)":
		"muzzle ▸ Spawn point follows facing",
	"dust.local_coords = true": "dust ▸ Particles follow facing",
	"plate.scale.x = signf(scale.x)": "plate ▸ Keeps its text upright",
	"anim_tree.set(\"parameters/Locomotion/blend_position\", signf(scale.x))":
		"Player ▸ Animation ▸ Faces the way it moves",
	# Y21 - the rest of the hosts, each in its own honest line
	"mesh.scale.x = -absf(mesh.scale.x) if mirrored else absf(mesh.scale.x)":
		"mesh ▸ Set mirrored to mirrored (flips the mesh's winding)",
	"panel.scale.x = -1.0 if mirror_ui else 1.0": "panel ▸ Set mirrored to mirror ui (UI)",
	"camera.zoom.x = -absf(camera.zoom.x) if mirror_view else absf(camera.zoom.x)":
		"camera ▸ Mirror the view",
	"camera.zoom.x = -camera.zoom.x": "camera ▸ Mirror the view",
	"tiles.set_cell(Vector2i(2, 0), tiles.get_cell_source_id(Vector2i(2, 0)), tiles.get_cell_atlas_coords(Vector2i(2, 0)), TileSetAtlasSource.TRANSFORM_FLIP_H if flip_tile else 0)":
		"tiles ▸ Set tile at (2, 0) flipped to flip tile"
}

## Gate 1. The questions, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	"sprite.flip_h": "sprite ▸ Is mirrored",
	"not sprite.flip_h": "sprite ▸ Is not mirrored",
	"sprite.flip_v": "sprite ▸ Is flipped",
	"not sprite.flip_v": "sprite ▸ Is not flipped",
	"body.scale.x < 0.0": "body ▸ Is mirrored",
	"body.scale.x > 0.0": "body ▸ Is not mirrored"
}

## Gate 2. The shapes these readings must NOT claim. An almost-right sentence is worse than the code
## it replaced, and `scale.x` is a SIZE far more often than it is a mirror.
static var REFUSALS: Dictionary = {
	"body.scale.x = 2.0": "body ▸ Set scale.x to 2",
	"body.scale.x = -2.0": "body ▸ Set scale.x to -2",
	"body.scale.x = -other.scale.x": "body ▸ Set scale.x to -other.scale.x",
	"mesh.rotate_y(deg_to_rad(90.0 * delta))": "mesh ▸ Rotate counter-clockwise at 90°/s · yaw"
}

## Gate 3. The host table, as ace id -> [display name, template, host class]. Ids and templates are
## API once shipped, so this table IS the covenant.
static var HOST_TABLE: Dictionary = {
	"SetMirroredSprite2D": ["Set Mirrored", "{target.}flip_h = {mirrored}", "Sprite2D"],
	"SetMirroredSprite3D": ["Set Mirrored", "{target.}flip_h = {mirrored}", "Sprite3D"],
	"SetMirroredTextureRect": ["Set Mirrored", "{target.}flip_h = {mirrored}", "TextureRect"],
	"SetFlippedAnimatedSprite2D": ["Set Flipped", "{target.}flip_v = {flipped}", "AnimatedSprite2D"],
	"IsMirroredSprite2D": ["Is Mirrored", "{target.}flip_h", "Sprite2D"],
	"IsFlippedSprite2D": ["Is Flipped", "{target.}flip_v", "Sprite2D"],
	"SetMirroredObject": ["Set Mirrored (whole object)",
		"{target.}scale.x = -1.0 if {mirrored} else 1.0", "Node2D"],
	"IsMirroredObject": ["Is Mirrored", "{target.}scale.x < 0.0", "Node2D"],
	"SetMirroredSpatial": ["Set Mirrored",
		"scale.x = -absf(scale.x) if {mirrored} else absf(scale.x)", "Node3D"],
	"SetMirroredLabel3D": ["Set Mirrored",
		"scale.x = -absf(scale.x) if {mirrored} else absf(scale.x)", "Label3D"],
	"TurnAround": ["Turn Around", "{target.}rotate_y(PI)", "Node3D"],
	"FaceDirectionOfMovement": ["Face Direction Of Movement",
		"if {velocity}.x != 0.0:\n\t{target.}scale.x = -1.0 if {velocity}.x < 0.0 else 1.0",
		"CharacterBody2D"],
	"FaceObject": ["Face Object",
		"{target.}scale.x = -1.0 if {object}.global_position.x < global_position.x else 1.0", "Node2D"],
	"KeepUpright": ["Keep Upright", "{target}.scale.x = signf(scale.x)", "Node2D"],
	"SetMirroredControl": ["Set Mirrored",
		"{target.}pivot_offset.x = {target.}size.x * 0.5\n{target.}scale.x = -1.0 if {mirrored} else 1.0",
		"Control"],
	"MirrorTheView": ["Mirror The View",
		"zoom.x = -absf(zoom.x) if {mirrored} else absf(zoom.x)", "Camera2D"],
	"MirrorViewportView": ["Mirror The View",
		"{target.}pivot_offset.x = {target.}size.x * 0.5\n{target.}scale.x = -1.0 if {mirrored} else 1.0",
		"SubViewportContainer"],
	"SetTileFlipped": ["Set Tile Flipped",
		"{target.}set_cell({coords}, {target.}get_cell_source_id({coords}), {target.}get_cell_atlas_coords({coords}), TileSetAtlasSource.TRANSFORM_FLIP_H if {mirrored} else 0)",
		"TileMapLayer"],
	"MirrorPath": ["Mirror Path",
		"for __point_{uid}: int in curve.point_count:\n\tcurve.set_point_position(__point_{uid}, Vector2(-curve.get_point_position(__point_{uid}).x, curve.get_point_position(__point_{uid}).y))",
		"Path2D"]
}

## Gate 4. A file made of nothing but these lines. Opening it as a sheet and saving it untouched must
## put back every byte - which is what makes the readings a lens rather than a rewrite.
const SOURCE: String = """extends CharacterBody2D

@onready var body: Node2D = $Body
@onready var sprite: Sprite2D = $Body/Sprite2D
@onready var plate: Label = $Body/Plate

func _physics_process(delta):
	if velocity.x != 0.0:
		body.scale.x = -1.0 if velocity.x < 0.0 else 1.0
	plate.scale.x = signf(body.scale.x)
	sprite.flip_v = is_upside_down

func face(target: Node2D) -> void:
	body.scale.x = -1.0 if target.global_position.x < global_position.x else 1.0
"""

## Gate 5. A file that mirrors only its sprite and holds a ray - the "attacks only work facing right"
## shape, exactly as a reader writes it.
const RAY_SOURCE: String = """extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var sword: RayCast2D = $Sword

func _physics_process(delta):
	sprite.flip_h = velocity.x < 0.0
"""

## Gate 5. A file that mirrors the whole object and holds a name plate that nothing puts back upright.
const PLATE_SOURCE: String = """extends CharacterBody2D

@onready var body: Node2D = $Body
@onready var plate: Label = $Body/Plate

func _physics_process(delta):
	body.scale.x = -1.0 if velocity.x < 0.0 else 1.0
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_readings() and ok
	ok = _test_refusals() and ok
	ok = _test_host_table() and ok
	ok = _test_round_trip() and ok
	ok = _test_doctor() and ok
	ok = _test_pattern() and ok
	return ok


## Gate 1. Every spelling of mirroring, in the sheet's own words.
static func _test_readings() -> bool:
	var ok: bool = true
	for code: String in STATEMENT_READINGS:
		ok = _check(code, _statement(code), str(STATEMENT_READINGS[code])) and ok
	for code: String in CONDITION_READINGS:
		ok = _check(code, _condition(code), str(CONDITION_READINGS[code])) and ok
	return ok


## Gate 2. The lines that stay exactly what they were.
static func _test_refusals() -> bool:
	var ok: bool = true
	for code: String in REFUSALS:
		ok = _check("refuses %s" % code, _statement(code), str(REFUSALS[code])) and ok
	ok = _check("a plain size claims no pattern", _pattern("body.scale.x = 2.0"), "") and ok
	ok = _check("a size on a 3D object claims no pattern", _pattern("mesh.scale.x = 3.0"), "") and ok
	return ok


## Gate 3. The authoring half: one row per host, each writing the host's own honest line.
static func _test_host_table() -> bool:
	var ok: bool = true
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[str(descriptor.ace_id)] = descriptor
	for ace_id: String in HOST_TABLE:
		var descriptor: Variant = shipped.get(ace_id, null)
		if descriptor == null:
			ok = _check("the Facing page ships %s" % ace_id, "missing", "shipped")
			continue
		var expected: Array = HOST_TABLE[ace_id] as Array
		var found: ACEDescriptor = descriptor as ACEDescriptor
		ok = _check("%s is named" % ace_id, str(found.display_name), str(expected[0])) and ok
		ok = _check("%s writes its host's own line" % ace_id,
			str(found.codegen_template), str(expected[1])) and ok
		ok = _check("%s is offered on its host" % ace_id, str(found.node_type), str(expected[2])) and ok
		ok = _check("%s is filed on the Facing page" % ace_id, str(found.category), "Facing") and ok
	# The reverse index holds exactly ONE row per line: `flip_h = true` is one line whichever class
	# wrote it, so the host twins author only and the shipped sprite row still speaks for the line.
	ok = _check("the host twins stay out of the reverse index",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("SetMirroredSprite2D"), true) and ok
	ok = _check("the object row speaks for its own line",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("SetMirroredObject"), false) and ok
	return ok


## Gate 4. The lens promise: nothing these readings say moves a byte.
static func _test_round_trip() -> bool:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## Gate 5. The two notes, and the one edit each of them names.
static func _test_doctor() -> bool:
	var ok: bool = _check("a sprite-only mirror leaves its ray behind",
		", ".join(EventSheetProjectDoctor.rays_not_following_facing(RAY_SOURCE)), "sword")
	ok = _check("a ray whose reach is signed by the facing is fine",
		", ".join(EventSheetProjectDoctor.rays_not_following_facing(
			RAY_SOURCE + "\tsword.target_position.x = absf(sword.target_position.x) * signf(scale.x)\n")),
		"") and ok
	ok = _check("a whole-object mirror writes its name plate backwards",
		", ".join(EventSheetProjectDoctor.labels_under_a_mirrored_body(PLATE_SOURCE)), "plate") and ok
	ok = _check("a plate already kept upright is fine",
		", ".join(EventSheetProjectDoctor.labels_under_a_mirrored_body(
			PLATE_SOURCE + "\tplate.scale.x = signf(scale.x)\n")), "") and ok
	ok = _check("a whole-object mirror is not a sprite-only one",
		EventSheetProjectDoctor.mirrors_only_a_sprite(PLATE_SOURCE), false) and ok
	ok = _check("the ray note offers the one edit that fixes it",
		_fix_labels("ray-not-following-facing", "sword"), "Put sword under the mirrored body") and ok
	ok = _check("the plate note offers the row that fixes it",
		_fix_labels("label-under-a-mirrored-body", "plate"), "Keep plate upright") and ok
	return ok


## Gate 6. Every reading names the pattern it recognised, with its own line as the evidence.
static func _test_pattern() -> bool:
	var ok: bool = _check("a whole-object mirror claims facing",
		_pattern("body.scale.x = -1.0"), "facing")
	ok = _check("a half turn claims facing", _pattern("mesh.rotate_y(PI)"), "facing") and ok
	ok = _check("a ray that follows claims facing",
		_pattern("ray.target_position.x = absf(ray.target_position.x) * signf(scale.x)"), "facing") and ok
	ok = _check("the question claims facing too",
		_pattern("body.scale.x < 0.0"), "facing") and ok
	ok = _check("the evidence is the line the reading came from",
		", ".join(EventSheetSentence.statement("body.scale.x = -1.0", CONTEXT).get(
			"evidence", PackedStringArray()) as PackedStringArray), "body.scale.x = -1.0") and ok
	ok = _check("the pattern has words a reader knows it by",
		EventSheetPatternVocabulary.words("facing"), "Facing") and ok
	return ok


## One statement reading as "object ▸ sentence".
static func _statement(code: String) -> String:
	return _joined(EventSheetSentence.statement(code, CONTEXT))


## One condition reading as "object ▸ sentence".
static func _condition(code: String) -> String:
	return _joined(EventSheetSentence.condition(code, CONTEXT))


## The pattern a line's reading claims, "" when it claims none.
static func _pattern(code: String) -> String:
	var reading: Dictionary = EventSheetSentence.statement(code, CONTEXT)
	if reading.is_empty():
		reading = EventSheetSentence.condition(code, CONTEXT)
	return str(reading.get("pattern", ""))


## The labels a Doctor finding's chips would carry, joined.
static func _fix_labels(check: String, subject: String) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for fix: Dictionary in EventSheetQuickFixes.fixes_for({"check": check, "subject": subject}):
		labels.append(str(fix.get("label", "")))
	return ", ".join(labels)


static func _joined(reading: Dictionary) -> String:
	if reading.is_empty():
		return "(no reading)"
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() \
		else text.strip_edges()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] mirror_and_flip_test: %s" % label)
		return true
	print("[FAIL] mirror_and_flip_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
