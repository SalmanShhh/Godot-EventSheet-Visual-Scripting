# Godot EventSheets - layers speak their names.
#
# A project that named its collision layers said which of them is the wall and which is the enemy.
# The rows about those layers should say it too, and this pins the whole of what that means:
#
#   the reader   one place turns a layer number into the project's word for it, and back.
#   the rows     five sentences per dimension, whose parameter is that layer.
#   the code     what is EMITTED is the engine's own call with the NUMBER in it. No name, no comment.
#   the lift     the same call, written by hand, opens as the same sentence - in the right dimension.
#   the notes    a number the project cannot name is a note in the Doctor, and only when the project
#                names other layers.
#
# The project settings this test needs are written, read and put back exactly as they were found, so
# it can run beside anything and leave the project as it started.
@tool
class_name CollisionLayerNamesTest
extends RefCounted

## The layer names this test works against, written for the length of the run.
const LAYER_SETTINGS: Array = [
	["layer_names/2d_physics/layer_1", "World"],
	["layer_names/2d_physics/layer_2", "Enemies"],
	["layer_names/3d_physics/layer_1", "Terrain"],
	["layer_names/3d_physics/layer_4", "Pickups"]
]

const SOURCE_2D_PATH := "user://collision_layer_names_2d.gd"
const SOURCE_3D_PATH := "user://collision_layer_names_3d.gd"

const SOURCE_2D: String = """extends CharacterBody2D


func _ready() -> void:
	set_collision_mask_value(2, true)
	set_collision_mask_value(2, false)
	set_collision_layer_value(1, true)
	set_collision_layer_value(1, false)
	if get_collision_mask_value(2):
		print("watching")
"""

const SOURCE_3D: String = """extends CharacterBody3D


func _ready() -> void:
	set_collision_mask_value(4, true)
"""


static func run() -> bool:
	var previous: Dictionary = _apply_layer_names()
	var ok: bool = _test_the_reader()
	ok = _test_the_lens() and ok
	ok = _test_the_rows() and ok
	ok = _test_what_is_emitted() and ok
	ok = _test_the_lift() and ok
	ok = _test_the_picker() and ok
	ok = _test_the_notes() and ok
	_restore(previous)
	return ok


# ── the reader ───────────────────────────────────────────────────────────────────


static func _test_the_reader() -> bool:
	var two_d: String = EventForgePhysicsLayers.DIMENSION_2D
	var three_d: String = EventForgePhysicsLayers.DIMENSION_3D
	var ok: bool = _check("a named layer reads by its name",
		EventForgePhysicsLayers.name_of(2, two_d), "Enemies")
	ok = _check("a layer nobody named reads as nothing",
		EventForgePhysicsLayers.name_of(7, two_d), "") and ok
	ok = _check("and says itself as its number",
		EventForgePhysicsLayers.words_for(7, two_d), "7") and ok
	ok = _check("the two dimensions are two lists",
		EventForgePhysicsLayers.words_for(1, three_d), "Terrain") and ok
	ok = _check("a value that is not a number is left alone",
		EventForgePhysicsLayers.words_for_value("wall_layer", two_d), "wall_layer") and ok
	ok = _check("and neither is a number Godot has no layer for",
		EventForgePhysicsLayers.words_for_value("40", two_d), "40") and ok
	ok = _check("a name answers with its number",
		EventForgePhysicsLayers.number_of("Enemies", two_d), 2) and ok
	ok = _check("a name the project never gave answers with nothing",
		EventForgePhysicsLayers.number_of("Lava", two_d), 0) and ok
	ok = _check("the named layers, lowest first",
		EventForgePhysicsLayers.named_layers(three_d),
		[{"number": 1, "name": "Terrain"}, {"number": 4, "name": "Pickups"}]) and ok
	ok = _check("a picker lists the first eight",
		EventForgePhysicsLayers.listed_layers(two_d).size(), 8) and ok
	ok = _check("plus whichever one the row already points at",
		EventForgePhysicsLayers.listed_layers(two_d, 20).size(), 9) and ok
	ok = _check("a 3D body reads the 3D names",
		EventForgePhysicsLayers.dimension_for_class("CharacterBody3D"), three_d) and ok
	ok = _check("and everything else reads the 2D ones",
		EventForgePhysicsLayers.dimension_for_class("CharacterBody2D"), two_d) and ok
	ok = _check("including a class nothing can place",
		EventForgePhysicsLayers.dimension_for_class(""), two_d) and ok
	return ok


# ── the lens: the number a row stores, read as the word it means ─────────────────


static func _test_the_lens() -> bool:
	var ok: bool = _check("the 2D lens reads the project's word",
		EventForgeValueLens.read(EventForgeValueLens.LENS_PHYSICS_LAYER_2D, "2"), "Enemies")
	ok = _check("the 3D lens reads the other list",
		EventForgeValueLens.read(EventForgeValueLens.LENS_PHYSICS_LAYER_3D, "4"), "Pickups") and ok
	ok = _check("an unnamed layer reads as its number",
		EventForgeValueLens.read(EventForgeValueLens.LENS_PHYSICS_LAYER_2D, "6"), "6") and ok
	ok = _check("an expression is the author's own and is left alone",
		EventForgeValueLens.read(EventForgeValueLens.LENS_PHYSICS_LAYER_2D, "wall_layer"),
		"wall_layer") and ok
	ok = _check("the hint alone is enough to pick the lens",
		EventForgeValueLens.lens_of({"hint": "physics_layer_name_3d"}),
		EventForgeValueLens.LENS_PHYSICS_LAYER_3D) and ok
	return ok


# ── the rows ─────────────────────────────────────────────────────────────────────


## Every named-layer ace_id, and the line it compiles to before the cross-node prefix is added.
const EXPECTED_ROWS: Dictionary = {
	"CollideWithLayer": "set_collision_mask_value({layer}, true)",
	"StopCollidingWithLayer": "set_collision_mask_value({layer}, false)",
	"BeOnLayer": "set_collision_layer_value({layer}, true)",
	"LeaveLayer": "set_collision_layer_value({layer}, false)",
	"IsSetToCollideWithLayer": "get_collision_mask_value({layer})",
}


static func _test_the_rows() -> bool:
	var ok: bool = true
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeCollisionACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	for ace_id: String in EXPECTED_ROWS.keys():
		ok = _check("%s is a row" % ace_id, by_id.has(ace_id), true) and ok
		ok = _check("%s3D is its twin" % ace_id, by_id.has("%s3D" % ace_id), true) and ok
		if not (by_id.has(ace_id) and by_id.has("%s3D" % ace_id)):
			continue
		var flat: ACEDescriptor = by_id[ace_id]
		var deep: ACEDescriptor = by_id["%s3D" % ace_id]
		ok = _check("%s writes the engine's own call" % ace_id,
			flat.codegen_template, str(EXPECTED_ROWS[ace_id])) and ok
		ok = _check("%s writes the same one" % deep.ace_id,
			deep.codegen_template, str(EXPECTED_ROWS[ace_id])) and ok
		ok = _check("%s is filed under the 2D collision object" % ace_id,
			flat.node_type, "CollisionObject2D") and ok
		ok = _check("%s under the 3D one" % deep.ace_id,
			deep.node_type, "CollisionObject3D") and ok
		ok = _check("%s takes a 2D named layer" % ace_id,
			_layer_hint(flat), "physics_layer_name_2d") and ok
		ok = _check("%s takes a 3D one" % deep.ace_id,
			_layer_hint(deep), "physics_layer_name_3d") and ok
		ok = _check("%s reads its layer through the matching lens" % ace_id,
			_layer_lens(flat), "physics_layer_name_2d") and ok
		ok = _check("%s says what its layer is" % ace_id,
			_layer_description(flat).contains("Project Settings"), true) and ok
	# The picker's own words, so a reader meets the sentence before the row.
	ok = _check("the mask verb says what it does",
		str(by_id["CollideWithLayer"].display_text), "Collide with {layer}") and ok
	ok = _check("and its opposite",
		str(by_id["StopCollidingWithLayer"].display_text), "Stop colliding with {layer}") and ok
	ok = _check("the layer verb is a different sentence",
		str(by_id["BeOnLayer"].display_text), "Be on layer {layer}") and ok
	ok = _check("and its opposite",
		str(by_id["LeaveLayer"].display_text), "Leave layer {layer}") and ok
	ok = _check("the question asks",
		str(by_id["IsSetToCollideWithLayer"].display_text), "is set to collide with {layer}") and ok
	# And the frozen bit verbs are untouched beside them.
	ok = _check("the bit verb it stands beside is unchanged",
		str(by_id["SetCollisionMaskBit"].codegen_template),
		"set_collision_mask_value({mask}, {enabled})") and ok
	return ok


static func _layer_hint(descriptor: ACEDescriptor) -> String:
	for param: ACEParam in descriptor.params:
		if param.id == "layer":
			return param.hint
	return ""


static func _layer_lens(descriptor: ACEDescriptor) -> String:
	for param: ACEParam in descriptor.params:
		if param.id == "layer":
			return param.display_lens
	return ""


static func _layer_description(descriptor: ACEDescriptor) -> String:
	for param: ACEParam in descriptor.params:
		if param.id == "layer":
			return param.description
	return ""


# ── what is emitted ──────────────────────────────────────────────────────────────


static func _test_what_is_emitted() -> bool:
	var line: String = _emit("CollideWithLayer", {"layer": "2"})
	var ok: bool = _check("the emitted line is the engine's own call with the number in it",
		line, "set_collision_mask_value(2, true)")
	ok = _check("and carries no name at all", line.contains("Enemies"), false) and ok
	ok = _check("and no comment residue", line.contains("#"), false) and ok
	ok = _check("the shipped row can act on another node",
		_emit("BeOnLayer", {"layer": "3", "target": "$Enemy"}),
		"$Enemy.set_collision_layer_value(3, true)") and ok
	ok = _check("and on its own by default",
		_emit("LeaveLayer", {"layer": "3"}), "set_collision_layer_value(3, false)") and ok
	return ok


## One row's line, through the SHIPPED descriptor - the one the cross-node pass has already put its
## optional receiver on, which is what a sheet actually carries.
static func _emit(ace_id: String, params: Dictionary) -> String:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	action.codegen_template = _shipped_template(ace_id)
	return ActionCodegen.generate_action(action)


static func _shipped_template(ace_id: String) -> String:
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor.codegen_template
	return ""


# ── the lift ─────────────────────────────────────────────────────────────────────


static func _test_the_lift() -> bool:
	var ok: bool = _check("a 2D file reads the 2D names",
		EventForgeCollisionLayerLift.extended_class(SOURCE_2D), "CharacterBody2D")
	var flat: PackedStringArray = _lifted_ace_ids(SOURCE_2D_PATH, SOURCE_2D)
	ok = _check("the four verbs and the question open as the named-layer rows", flat,
		PackedStringArray(["CollideWithLayer", "StopCollidingWithLayer", "BeOnLayer",
			"LeaveLayer", "IsSetToCollideWithLayer", "PrintLog"])) and ok
	var deep: PackedStringArray = _lifted_ace_ids(SOURCE_3D_PATH, SOURCE_3D)
	ok = _check("the same spelling in a 3D file opens as the 3D row", deep,
		PackedStringArray(["CollideWithLayer3D"])) and ok
	ok = _check("and the file saves back byte for byte",
		_round_trips(SOURCE_2D_PATH, SOURCE_2D), true) and ok
	ok = _check("as does the 3D one", _round_trips(SOURCE_3D_PATH, SOURCE_3D), true) and ok
	return ok


## Every ace_id the rows of one lifted file carry, in the order the file says them.
static func _lifted_ace_ids(path: String, source: String) -> PackedStringArray:
	var sheet: EventSheetResource = _open(path, source)
	var found: PackedStringArray = PackedStringArray()
	# A sheet's rows are not all events - a raw block is a row too - so the walk asks each one what
	# it is rather than declaring an answer.
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		var event: EventRow = row
		for condition: ACECondition in event.conditions:
			found.append(condition.ace_id)
		for action: ACEAction in event.actions:
			found.append(action.ace_id)
	return found


static func _round_trips(path: String, source: String) -> bool:
	var sheet: EventSheetResource = _open(path, source)
	sheet.external_source_path = path
	return str(SheetCompiler.compile(sheet, path).get("output", "")) == source


static func _open(path: String, source: String) -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	return GDScriptImporter.new().import_external(path)


# ── the notes ────────────────────────────────────────────────────────────────────


## THE FIELD ITSELF, and the one thing it must never do: throw away what the row already says. The
## lift keeps `set_collision_mask_value(wall_layer, true)` as `wall_layer` and the sentence reads it
## back as `wall_layer` - so a dialog that answered 1 for it would rewrite working code on the way
## out of a form that was only opened, which is a round-trip break through the picker.
static func _test_the_picker() -> bool:
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var two_d: String = EventForgePhysicsLayers.DIMENSION_2D
	var written: Control = dialog._create_single_layer_field("expression", "wall_layer", two_d)
	var expression_field: Control = dialog._fields["expression"]
	var ok: bool = _check("an expression comes back out of the field exactly as it went in",
		dialog._extract_value(expression_field), "wall_layer")
	ok = _check("and the field reads as that expression rather than as a layer nobody chose",
		(expression_field as MenuButton).text, "wall_layer") and ok
	var numbered: Control = dialog._create_single_layer_field("number", "2", two_d)
	var number_field: Control = dialog._fields["number"]
	ok = _check("a plain layer still comes back as its number",
		dialog._extract_value(number_field), 2) and ok
	ok = _check("read as the project's word for it", (number_field as MenuButton).text, "Enemies") and ok
	# The two rows own the controls; the dialog itself is reference-counted and goes with the scope.
	written.free()
	numbered.free()
	return ok


static func _test_the_notes() -> bool:
	# Layer 6 is a 2D layer this project does not name, while it names layers 1 and 2 - the note.
	var unnamed: Array[Dictionary] = EventSheetCollisionLayerDoctor.script_findings(
		"res://enemy.gd", "extends CharacterBody2D\n\nfunc _ready() -> void:\n\tset_collision_mask_value(6, true)\n")
	var ok: bool = _check("a layer the project cannot name earns one note", unnamed.size(), 1)
	if unnamed.size() == 1:
		ok = _check("filed as the unnamed-layer check",
			str(unnamed[0]["check"]), EventSheetCollisionLayerDoctor.CHECK_UNNAMED) and ok
		ok = _check("as a note rather than a warning", str(unnamed[0]["severity"]), "info") and ok
		ok = _check("naming the layer it is about",
			str(unnamed[0]["message"]).contains("layer 6"), true) and ok
	ok = _check("a layer the project DOES name says nothing",
		EventSheetCollisionLayerDoctor.script_findings("res://enemy.gd",
			"extends CharacterBody2D\n\nfunc _ready() -> void:\n\tset_collision_mask_value(2, true)\n"),
		[] as Array[Dictionary]) and ok
	var out_of_range: Array[Dictionary] = EventSheetCollisionLayerDoctor.script_findings(
		"res://enemy.gd", "extends CharacterBody2D\n\nfunc _ready() -> void:\n\tset_collision_mask_value(40, true)\n")
	ok = _check("a number that is not a layer at all is a warning", out_of_range.size(), 1) and ok
	if out_of_range.size() == 1:
		ok = _check("filed as the out-of-range check",
			str(out_of_range[0]["check"]), EventSheetCollisionLayerDoctor.CHECK_NOT_A_LAYER) and ok
		ok = _check("and said as a warning", str(out_of_range[0]["severity"]), "warning") and ok
	# The 3D file's layer 4 IS named in 3D and is not named in 2D: the dimension is the file's own.
	ok = _check("the note reads the file's own dimension",
		EventSheetCollisionLayerDoctor.script_findings("res://enemy3d.gd", SOURCE_3D),
		[] as Array[Dictionary]) and ok
	ok = _check("a layer written as an expression is nobody's guess",
		EventSheetCollisionLayerDoctor.layer_numbers(
			"set_collision_mask_value(wall_layer, true)"), PackedInt32Array()) and ok
	ok = _check("and a script that never mentions a layer is never read",
		EventSheetCollisionLayerDoctor.says_enough("extends Node\n"), false) and ok
	return ok


# ── the project settings this test writes, and puts back ────────────────────────


static func _apply_layer_names() -> Dictionary:
	var previous: Dictionary = {}
	for entry: Array in LAYER_SETTINGS:
		previous[entry[0]] = ProjectSettings.get_setting(str(entry[0]), null)
		ProjectSettings.set_setting(str(entry[0]), str(entry[1]))
	return previous


static func _restore(previous: Dictionary) -> void:
	for key: Variant in previous:
		ProjectSettings.set_setting(str(key), previous[key])


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] collision_layer_names_test: %s" % label)
		return true
	print("[FAIL] collision_layer_names_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
