# Godot EventSheets - the spawn sentence said in three dimensions.
#
# What this gate holds, in the order the mistakes actually happen:
#   1. THE LINES, AND THEIR ORDER. The 3D twins are the 2D pair's three statements with a Node3D
#      host: instance, parent, place. The deferred twin still places BEFORE it parents, because a
#      copy that is not in a tree yet has nothing for a global position to be global to. Swap either
#      and the copy lands somewhere else at runtime while every other test stays green.
#   2. THE HOST. Each 3D row is filed under Node3D and each 2D row is still filed under Node2D, which
#      is the whole of what makes the picker offer the right one - the emitted lines of the spawn
#      pair are the same characters in both dimensions.
#   3. THE PLACEMENT WORDS. Each 3D answer to "where" is one expression, pinned as the exact text it
#      emits. The box reads two kinds of box, the sphere corrects its radius by the CUBE root (an
#      even scatter through a VOLUME, which is the square root's argument one dimension up), and the
#      ring is a ring.
#   4. THE ROUND TRIP. Each of them survives an open-and-re-emit trip inside a 3D spawn row's field,
#      byte for byte, exactly as its 2D twin does.
#   5. THE REFUSAL, RECORDED. There is no 3D Random Place Off Screen Edge, and the module says why in
#      its own comment. A later pass that quietly adds one has to change this line first.
#
# Values are pinned, never counts: a count would go on passing while the wrong line moved.
@tool
class_name SpawnInThreeDimensionsTest
extends RefCounted

const MODULE_PATH: String = "res://addons/eventforge/registration/modules/spawn_aces.gd"

## The scene expression the fixtures spawn - a load() of a path, so the fixture stands on its own
## the way the row's own default does.
const ENEMY: String = "load(\"res://enemy.tscn\")"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_twins_emit_the_same_three_lines_on_a_3d_host() and passed
	passed = _test_the_deferred_twin_places_before_it_parents() and passed
	passed = _test_the_placement_words_are_one_expression_each() and passed
	passed = _test_a_3d_spawn_round_trips_byte_for_byte() and passed
	passed = _test_there_is_no_3d_screen_edge_and_the_module_says_why() and passed
	return passed


# ── 1 and 2. The lines, and the host they are filed under ──


static func _test_the_twins_emit_the_same_three_lines_on_a_3d_host() -> bool:
	var by_id: Dictionary = _descriptors()
	var passed: bool = true
	passed = _check("Spawn A Copy (3D) emits instance, parent, place - in that order",
		str(by_id.get("SpawnNewCopy3D", ACEDescriptor.new()).codegen_template),
		"var {name} = {scene}.instantiate()\n{parent}.add_child({name})\n{name}.global_position = {at}") and passed
	passed = _check("the 3D spawn is filed under Node3D",
		str(by_id.get("SpawnNewCopy3D", ACEDescriptor.new()).node_type), "Node3D") and passed
	passed = _check("and the 2D spawn is still filed under Node2D",
		str(by_id.get("SpawnNewCopy", ACEDescriptor.new()).node_type), "Node2D") and passed
	passed = _check("the row opens placing the copy where the spawner is",
		_default_of(by_id.get("SpawnNewCopy3D", null), "at"), "global_position") and passed
	passed = _check("the row opens adding the copy under the spawning node",
		_default_of(by_id.get("SpawnNewCopy3D", null), "parent"), "self") and passed
	# The 3D field offers 3D starters. A Vector2 in a Node3D row's At field is the one mistake this
	# list exists to stop, so the question is asked of the whole list rather than of one position in
	# it: the 3D literal is there, and nothing two-dimensional is.
	var starters: Array = _module().get("PLACEMENT_STARTERS_3D")
	var two_dimensional: PackedStringArray = PackedStringArray()
	for starter: Variant in starters:
		if str(starter).contains("Vector2") or str(starter).contains("in_2d"):
			two_dimensional.append(str(starter))
	passed = _check("the At field offers a Vector3",
		starters.has("Vector3(0, 0, 0)"), true) and passed
	passed = _check("and nothing two-dimensional at all",
		two_dimensional, PackedStringArray()) and passed
	return passed


static func _test_the_deferred_twin_places_before_it_parents() -> bool:
	var by_id: Dictionary = _descriptors()
	var passed: bool = true
	passed = _check("Spawn A Copy Safely (3D) defers the parenting",
		str(by_id.get("SpawnNewCopyDeferred3D", ACEDescriptor.new()).codegen_template),
		"var {name} = {scene}.instantiate()\n{name}.position = {at}\n{parent}.call_deferred(\"add_child\", {name})") and passed
	passed = _check("and says so in its sentence rather than deferring quietly",
		str(by_id.get("SpawnNewCopyDeferred3D", ACEDescriptor.new()).display_text).contains("added on the next idle moment"),
		true) and passed
	var output: String = _compiled_with("SpawnNewCopyDeferred3D", {
		"scene": ENEMY, "name": "foe", "at": "Vector3(0, 0, 0)", "parent": "self"
	}, "user://eventforge_spawn3d_deferred.gd")
	var place_at: int = output.find("\tfoe.position = Vector3(0, 0, 0)")
	var parent_at: int = output.find("\tself.call_deferred(\"add_child\", foe)")
	passed = _check("the deferred row writes the deferred add", parent_at >= 0, true) and passed
	passed = _check("the deferred row places the copy before it hands it over",
		place_at >= 0 and place_at < parent_at, true) and passed
	return passed


# ── 3. The placement words ──


static func _test_the_placement_words_are_one_expression_each() -> bool:
	var by_id: Dictionary = _descriptors()
	var passed: bool = true
	passed = _check("place of a node, in three dimensions",
		str(by_id.get("PlaceAtNode3D", ACEDescriptor.new()).codegen_template), "{node}.global_position") and passed
	# The box reads BOTH kinds of box a level is drawn with, and the casts are what let one
	# expression ask which it is: a node reached by path is a plain Node until something says
	# otherwise, and GDScript will not read `size` off one that has not.
	passed = _check("a random place inside a box measures the box rather than retrying",
		str(by_id.get("PlaceInsideBox3D", ACEDescriptor.new()).codegen_template),
		"({box} as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)"
		+ " * ((({box} as CollisionShape3D).shape as BoxShape3D).size"
		+ " if {box} is CollisionShape3D else ({box} as CSGBox3D).size))") and passed
	# THE CORRECTION, one dimension up. A square root scatters a DISC evenly; a solid ball needs the
	# cube root, because the volume inside a radius grows as its cube. A twin that copied the 2D
	# spelling straight across would bunch every spawn toward the middle of the sphere.
	passed = _check("a random place inside a sphere pulls the radius back by the cube root",
		str(by_id.get("PlaceInsideSphere3D", ACEDescriptor.new()).codegen_template),
		"({ball} as Node3D).to_global(Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()"
		+ " * (({ball} as CollisionShape3D).shape as SphereShape3D).radius * pow(randf(), 1.0 / 3.0))") and passed
	passed = _check("and not by the square root, which would bunch the scatter in the middle",
		str(by_id.get("PlaceInsideSphere3D", ACEDescriptor.new()).codegen_template).contains("sqrt("),
		false) and passed
	passed = _check("a random place around a node is a ring on the ground plane",
		str(by_id.get("PlaceAroundNode3D", ACEDescriptor.new()).codegen_template),
		"{node}.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * {radius}") and passed
	# A local point ADDED to a global one is the bug the 2D twins were corrected for; neither of the
	# two shape-sampling rows here may be written that way.
	for placement_id: String in ["PlaceInsideBox3D", "PlaceInsideSphere3D"]:
		passed = _check("%s hands its point back through to_global" % placement_id,
			str(by_id.get(placement_id, ACEDescriptor.new()).codegen_template).contains(".to_global("), true) and passed
	# Every one of the four is offered on the 3D page, which is what a Node3D sheet's picker asks.
	for placement_id: String in ["PlaceAtNode3D", "PlaceInsideBox3D", "PlaceInsideSphere3D", "PlaceAroundNode3D"]:
		passed = _check("%s is filed under Node3D" % placement_id,
			str(by_id.get(placement_id, ACEDescriptor.new()).node_type), "Node3D") and passed
	return passed


# ── 4. The round trip ──


static func _test_a_3d_spawn_round_trips_byte_for_byte() -> bool:
	var passed: bool = true
	for placement: String in [
		"$Marker3D.global_position",
		"($SpawnBox as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)"
		+ " * ((($SpawnBox as CollisionShape3D).shape as BoxShape3D).size"
		+ " if $SpawnBox is CollisionShape3D else ($SpawnBox as CSGBox3D).size))",
		"global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 5.0",
	]:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "Node3D"
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnReady"
		event.actions.append(_action("SpawnNewCopy3D", {
			"scene": ENEMY, "name": "foe", "at": placement, "parent": "self"
		}))
		sheet.events.append(event)
		var source: String = _compile(sheet, "user://eventforge_spawn3d_place.gd")
		passed = _check("the placement expression is emitted as written",
			source.contains("\tfoe.global_position = %s" % placement), true) and passed
		var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
		imported.external_source_path = "user://eventforge_spawn3d_place_back.gd"
		passed = _check("a 3D spawn placed by %s re-emits byte for byte" % placement.get_slice("(", 0),
			_compile(imported, "user://eventforge_spawn3d_place_back.gd") == source, true) and passed
	return passed


# ── 5. The refusal ──


static func _test_there_is_no_3d_screen_edge_and_the_module_says_why() -> bool:
	var by_id: Dictionary = _descriptors()
	var passed: bool = _check("no 3D screen-edge row was quietly added",
		by_id.has("PlaceAtScreenEdge3D"), false)
	# The refusal is only honest while it is WRITTEN DOWN. A pass that deletes the paragraph and
	# leaves the gap unexplained fails here, which is the point of pinning prose at all.
	var module_text: String = FileAccess.get_file_as_string(MODULE_PATH)
	passed = _check("and the module says why in its own words",
		module_text.contains("there is no 3D Random Place Off Screen Edge"), true) and passed
	passed = _check("naming the camera frustum as the reason",
		module_text.contains("camera's frustum"), true) and passed
	return passed


# ── Harness ──


## The Spawn module, loaded BY PATH so the test does not wait on the editor class cache having been
## regenerated for a newly added module.
static func _module() -> GDScript:
	return load(MODULE_PATH)


static func _descriptors() -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: Variant in _module().call("get_descriptors"):
		if descriptor is ACEDescriptor:
			by_id[str((descriptor as ACEDescriptor).ace_id)] = descriptor
	return by_id


## One parameter's default, as the literal the row opens on.
static func _default_of(descriptor: Variant, param_id: String) -> String:
	if not (descriptor is ACEDescriptor):
		return ""
	for param: ACEParam in (descriptor as ACEDescriptor).params:
		if str(param.id) == param_id:
			return str(param.default_value)
	return ""


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action


## One row of the given kind, compiled in a ready handler on a Node3D - the smallest sheet that can
## hold a 3D spawn.
static func _compiled_with(ace_id: String, params: Dictionary, path: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node3D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action(ace_id, params))
	sheet.events.append(event)
	return _compile(sheet, path)


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] spawn_in_three_dimensions_test: %s -> expected %s, got %s" % [label, expected, got])
	return false
