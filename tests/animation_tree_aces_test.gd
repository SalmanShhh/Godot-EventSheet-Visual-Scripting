# Godot EventSheets - the blend tree, the root motion and the bones.
#
# The claims these rows make, in the order they would break:
#
#   1. THE PARAMETER PATH IS THE ENGINE'S OWN STRING. Every tree row is a value written into, or read
#      out of, a magic path, and a path with one character wrong is accepted by `set()` and does
#      nothing. Pinned as the emitted text, character for character - the blend position, the layer
#      amount, the advance condition, the time scale and the two calls on the playback object.
#   2. THE ROOT MOTION FORMULA IS ARITHMETIC, SO IT IS RUN. The emitted right-hand side is evaluated
#      with a fixture basis and a fixture step, both in 3D and in its 2D twin, so what is pinned is
#      the VELOCITY the body gets rather than the presence of a word in a string. A formula whose
#      multiplication and division swapped places would still read fine and would still fail here.
#   3. THE TWO STATE MOMENTS REACH THE PLAYBACK OBJECT. `state_started` is not a signal of the
#      AnimationTree node at all - it belongs to the object the tree keeps under
#      `parameters/playback` - so a sheet holding the event is COMPILED here and its `_ready` line
#      pinned, because a connect line aimed at the node would fail at run time and never here.
#   4. THE TREE'S OWN NAMES ARE READ OFF THE SCENE. A fixture scene with a state machine, a
#      one-dimensional space and a layer in it is written out and read back: the states, the spaces,
#      which of them is which, and how many dimensions each has. The same read through an external
#      `.tres`, because a rig of any size keeps its tree in a file.
#   5. THE TWO QUIET NOTES SAY SOMETHING TRUE. The Doctor section is handed one script and one tree
#      and asked for its findings: a travel to a state the tree does not declare, and a vector
#      written into a space that is a line. Both are notes, both name the file, and a script no
#      scene can be paired with earns neither.
#   6. A HAND-TYPED TRAVEL READS BACK AS THE ROW, and re-emits byte for byte. The other half of that
#      claim is what is NOT claimed: `global_position` is not read as Bone Position, because the
#      shipped place rows already speak for that line.
#
# ONE THING DELIBERATELY NOT TESTED HERE: whether anything blends. A headless suite has no scene
# tree and no mixer, so what is proven is the string, the arithmetic in it and the round trip - not
# the pose.
@tool
class_name AnimationTreeACEsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MODULE_PATH := "res://addons/eventforge/registration/modules/animation_player_aces.gd"
const SKELETON_PATH := "res://addons/eventforge/registration/modules/skeleton_aces.gd"
const COLLECTION_PATH := "res://addons/eventforge/registration/modules/collection_aces.gd"
const SCENE_PROBE := "user://animation_tree_probe.tscn"
const EXTERNAL_SCENE_PROBE := "user://animation_tree_external_probe.tscn"
const TREE_PROBE := "user://animation_tree_probe.tres"
const SCRIPT_PROBE := "user://animation_tree_probe.gd"
const COMPILE_PROBE := "user://animation_tree_compile_probe.gd"

## A rig with one of everything the reader has to tell apart: a state machine with four states, a
## ONE-dimensional blend space, a layer that takes an amount rather than a position, and - the shape
## that catches a flattening reader - a two-dimensional space that lives INSIDE the machine, whose
## parameter path is therefore the whole way down to it.
const FIXTURE_SCENE := """[gd_scene load_steps=6 format=3]

[sub_resource type="AnimationNodeBlendSpace1D" id="AnimationNodeBlendSpace1D_a"]

[sub_resource type="AnimationNodeBlend2" id="AnimationNodeBlend2_a"]

[sub_resource type="AnimationNodeBlendSpace2D" id="AnimationNodeBlendSpace2D_b"]

[sub_resource type="AnimationNodeStateMachine" id="AnimationNodeStateMachine_a"]
states/Idle/node = SubResource("AnimationNodeAnimation_a")
states/Run/node = SubResource("AnimationNodeAnimation_b")
states/Swing/node = SubResource("AnimationNodeAnimation_c")
states/Aiming/node = SubResource("AnimationNodeBlendSpace2D_b")

[sub_resource type="AnimationNodeBlendTree" id="AnimationNodeBlendTree_a"]
nodes/Locomotion/node = SubResource("AnimationNodeBlendSpace1D_a")
nodes/Aim/node = SubResource("AnimationNodeBlend2_a")
nodes/Machine/node = SubResource("AnimationNodeStateMachine_a")

[node name="Player" type="CharacterBody2D"]

[node name="Anim" type="AnimationTree" parent="."]
tree_root = SubResource("AnimationNodeBlendTree_a")
"""

## The same tree kept in a FILE, which is what a rig of any size does. The scene beside it points at
## it, so the reader has to open the second file to answer anything at all.
const FIXTURE_TREE_FILE := """[gd_resource type="AnimationNodeBlendTree" load_steps=2 format=3]

[sub_resource type="AnimationNodeBlendSpace2D" id="AnimationNodeBlendSpace2D_a"]

[resource]
nodes/Ground/node = SubResource("AnimationNodeBlendSpace2D_a")
"""

const FIXTURE_EXTERNAL_SCENE := """[gd_scene load_steps=2 format=3]

[ext_resource type="AnimationNodeBlendTree" path="user://animation_tree_probe.tres" id="1_tree"]

[node name="Rig" type="Node3D"]

[node name="Anim" type="AnimationTree" parent="."]
tree_root = ExtResource("1_tree")
"""

## The line a person writes by hand to walk a state machine somewhere. It is the fixture AND the
## expected output: the lift's promise is that opening this and saving it again changes nothing.
const HAND_WRITTEN := """extends Node


func _ready() -> void:
	$Anim.get("parameters/playback").travel(&"Swing")
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_registration() and all_passed
	all_passed = _run_parameter_paths() and all_passed
	all_passed = _run_root_motion() and all_passed
	all_passed = _run_state_moments() and all_passed
	all_passed = _run_bones() and all_passed
	all_passed = _run_tree_reading() and all_passed
	all_passed = _run_doctor() and all_passed
	all_passed = _run_lift() and all_passed
	if all_passed:
		print("[PASS] animation_tree_aces_test: the blend tree, the root motion and the bones")
	return all_passed


## The rows register with the ids, kinds and hosts the picker files them under - and the two rows
## that already shipped are still exactly where they were.
static func _run_registration() -> bool:
	var by_id: Dictionary = _by_id(MODULE_PATH)
	var rows: Array = []
	for entry: Array in [
			["JumpToState", ACEDescriptor.ACEType.ACTION, "AnimationTree"],
			["AnimationStateIsAny", ACEDescriptor.ACEType.CONDITION, "AnimationTree"],
			["SetBlendPosition", ACEDescriptor.ACEType.ACTION, "AnimationTree"],
			["BlendToward", ACEDescriptor.ACEType.ACTION, "AnimationTree"],
			["BlendLayer", ACEDescriptor.ACEType.ACTION, "AnimationTree"],
			["SetTreeCondition", ACEDescriptor.ACEType.ACTION, "AnimationTree"],
			["SetTreeTimeScale", ACEDescriptor.ACEType.ACTION, "AnimationTree"],
			["AnimationTimeInState", ACEDescriptor.ACEType.EXPRESSION, "AnimationTree"],
			["OnAnimationStateEntered", ACEDescriptor.ACEType.TRIGGER, "AnimationTree"],
			["OnAnimationStateLeft", ACEDescriptor.ACEType.TRIGGER, "AnimationTree"],
			["OnAnimationReachedMarker", ACEDescriptor.ACEType.TRIGGER, "AnimationPlayer"],
			["AnimationJustPastMarker", ACEDescriptor.ACEType.CONDITION, "AnimationPlayer"],
			["ApplyRootMotion", ACEDescriptor.ACEType.ACTION, "CharacterBody2D"],
			["ApplyRootMotion3D", ACEDescriptor.ACEType.ACTION, "CharacterBody3D"]]:
		var ace_id: String = str(entry[0])
		rows.append(["%s is registered" % ace_id, by_id.has(ace_id), true])
		if not by_id.has(ace_id):
			continue
		var descriptor: ACEDescriptor = by_id[ace_id]
		rows.append(["%s is the kind it says" % ace_id, int(descriptor.ace_type), int(entry[1])])
		rows.append(["%s belongs to the node it acts on" % ace_id, str(descriptor.node_type), str(entry[2])])
		rows.append(["%s files under Animation" % ace_id, str(descriptor.category), "Animation"])
	# THE FREEZE, and the survey behind it: NINE rows already drove a tree, not the two this module
	# holds - seven of them on the collections shelf, one of which is the travel row this slice was
	# asked to add. None of them is re-minted, and every one still writes exactly the line it wrote.
	var shipped: Dictionary = _by_id(COLLECTION_PATH)
	rows.append(["travel already ships, and is not minted a second time",
		by_id.has("TravelToState"), false])
	rows.append(["the shipped travel row still writes its own line",
		str(shipped["TravelToState"].codegen_template), "get(\"parameters/playback\").travel({state})"])
	rows.append(["and still lists under the name it shipped with",
		str(shipped["TravelToState"].display_name), "Travel To State"])
	rows.append(["the generic blend setter is untouched too",
		str(shipped["SetTreeParam"].codegen_template), "set({path}, {value})"])
	rows.append(["the shipped one-shot row still writes its own line",
		str(by_id["PlayOneShotAnimation"].codegen_template),
		"set(\"parameters/{name}/request\", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)"])
	rows.append(["and the shipped state question still asks its own",
		str(by_id["AnimationStateIs"].codegen_template),
		"get(\"parameters/playback\").get_current_node() == {state}"])
	# The name a picker lists: the several-states question is a NEW name beside the shipped single
	# one rather than a second row called the same thing.
	rows.append(["the several-states question has a name of its own",
		str(by_id["AnimationStateIsAny"].display_name), "Is In Any State"])
	rows.append(["and the shipped single one keeps its", str(by_id["AnimationStateIs"].display_name),
		"Current State Is"])
	# The two 2D/3D twins really are one word on two nodes.
	rows.append(["root motion is one word in both dimensions",
		[str(by_id["ApplyRootMotion"].display_name), str(by_id["ApplyRootMotion3D"].display_name)],
		["Apply Root Motion", "Apply Root Motion"]])
	# The fields that read the tree say so through their hint, which is what puts the tree's own
	# names in the list rather than a free-text box.
	rows.append(["the shipped travel row's state field now asks the tree for its states",
		_hint_of(shipped["TravelToState"], "state"), "animation_state"])
	rows.append(["and so does the shipped state question's",
		_hint_of(shipped["IsInState"], "state"), "animation_state"])
	rows.append(["the jump's field asks the same list",
		_hint_of(by_id["JumpToState"], "state"), "animation_state"])
	rows.append(["the blend field asks it for its spaces",
		_hint_of(by_id["SetBlendPosition"], "space"), "blend_space"])
	rows.append(["and the layer field for its layers", _hint_of(by_id["BlendLayer"], "layer"), "blend_layer"])
	return SUPPORT.pins("animation_tree_aces_test", rows)


## The magic strings, character for character. A path with one letter wrong is accepted in silence,
## so the only useful pin is the whole emitted line.
static func _run_parameter_paths() -> bool:
	var rows: Array = []
	rows.append(["the shipped travel goes through the machine's own transitions",
		_emitted(COLLECTION_PATH, "TravelToState", {"state": "&\"Swing\"", "target": ""}),
		"get(\"parameters/playback\").travel(&\"Swing\")"])
	rows.append(["and reaches another tree when one is named",
		_emitted(COLLECTION_PATH, "TravelToState", {"state": "&\"Swing\"", "target": "$Anim"}),
		"$Anim.get(\"parameters/playback\").travel(&\"Swing\")"])
	rows.append(["a jump starts the state instead, with no transition",
		_emitted(MODULE_PATH, "JumpToState", {"state": "\"Idle\"", "target": ""}),
		"get(\"parameters/playback\").start(\"Idle\")"])
	rows.append(["several states is one membership question",
		_emitted(MODULE_PATH, "AnimationStateIsAny", {"states": "[\"Idle\", \"Run\"]", "target": ""}),
		"get(\"parameters/playback\").get_current_node() in [\"Idle\", \"Run\"]"])
	rows.append(["a blend position names the space inside the path",
		_emitted(MODULE_PATH, "SetBlendPosition", {"space": "Locomotion", "value": "move_input", "target": ""}),
		"set(\"parameters/Locomotion/blend_position\", move_input)"])
	rows.append(["blending toward it is a tween on that same property",
		_emitted(MODULE_PATH, "BlendToward", {"space": "Locomotion", "value": "Vector2.RIGHT", "seconds": "0.2", "target": "self", "uid": "a1"}),
		"\n".join(PackedStringArray([
			"if self.has_meta(&\"blend_Locomotion\"):",
			"\t(self.get_meta(&\"blend_Locomotion\") as Tween).kill()",
			"var __blend_a1: Tween = self.create_tween()",
			"self.set_meta(&\"blend_Locomotion\", __blend_a1)",
			"__blend_a1.tween_property(self, \"parameters/Locomotion/blend_position\", Vector2.RIGHT, 0.2)"]))])
	rows.append(["a layer is an amount rather than a position",
		_emitted(MODULE_PATH, "BlendLayer", {"layer": "Aim", "amount": "1.0", "seconds": "0.2", "target": "$Anim", "uid": "a1"}),
		"\n".join(PackedStringArray([
			"if $Anim.has_meta(&\"blend_Aim\"):",
			"\t($Anim.get_meta(&\"blend_Aim\") as Tween).kill()",
			"var __blend_a1: Tween = $Anim.create_tween()",
			"$Anim.set_meta(&\"blend_Aim\", __blend_a1)",
			"__blend_a1.tween_property($Anim, \"parameters/Aim/blend_amount\", 1.0, 0.2)"]))])
	rows.append(["an advance condition is written where the transition reads it",
		_emitted(MODULE_PATH, "SetTreeCondition", {"condition": "is_running", "value": "true", "target": ""}),
		"set(\"parameters/conditions/is_running\", true)"])
	rows.append(["a time scale is a node of the tree, not a property of it",
		_emitted(MODULE_PATH, "SetTreeTimeScale", {"node": "TimeScale", "scale": "0.5", "target": ""}),
		"set(\"parameters/TimeScale/scale\", 0.5)"])
	rows.append(["how long the state has been playing is the playback's own answer",
		_emitted(MODULE_PATH, "AnimationTimeInState", {"target": ""}),
		"get(\"parameters/playback\").get_current_play_position()"])
	# The marker edge: true on the crossing and false for the rest of the clip, which is the whole
	# difference between it and the shipped Reached Marker beside it.
	var edge: ACEDescriptor = _by_id(MODULE_PATH)["AnimationJustPastMarker"]
	rows.append(["the crossing remembers whether it had already happened",
		str(edge.member_template), "var __marker_{uid}: bool = false"])
	rows.append(["the memory is cleared the moment the play head is behind the marker again",
		str(edge.codegen_prelude).contains("__marker_{uid} = __marker_{uid} and"), true])
	rows.append(["and set the moment the crossing is answered",
		str(edge.codegen_on_true), "__marker_{uid} = true"])
	return SUPPORT.pins("animation_tree_aces_test", rows)


## Root motion is arithmetic, so the arithmetic is RUN. The emitted right-hand side is evaluated with
## a fixture basis and a fixture step: a formula that divided where it should multiply would read
## perfectly well and would still fail here.
static func _run_root_motion() -> bool:
	var rows: Array = []
	var three_d: String = _emitted(MODULE_PATH, "ApplyRootMotion3D",
		{"tree": "$Anim", "scale": "1.0", "target": "", "uid": "a1"})
	rows.append(["the 3D row turns the animator's step by the body's own facing first",
		three_d.split("\n")[0],
		"velocity = ((basis * $Anim.get_root_motion_position()) / delta * 1.0) if delta > 0.0 else Vector3.ZERO"])
	rows.append(["and turns the body by the root's own turn",
		three_d.split("\n")[1], "quaternion *= $Anim.get_root_motion_rotation()"])
	# The fixture: a body already facing left (a quarter turn about up) and an animation that steps
	# one metre forward in half a step. Turned by the basis, forward becomes left; divided by the
	# step, one metre becomes two metres a second.
	var turned: Variant = _value("(Basis(Vector3.UP, PI / 2) * Vector3(0, 0, 1)) / 0.5 * 1.0")
	rows.append(["a metre forward in half a step is two metres a second",
		_rounded_vector3(turned), Vector3(2.0, 0.0, 0.0)])
	rows.append(["and the scale really scales it",
		_rounded_vector3(_value("(Basis(Vector3.UP, PI / 2) * Vector3(0, 0, 1)) / 0.5 * 0.5")),
		Vector3(1.0, 0.0, 0.0)])
	var two_d: String = _emitted(MODULE_PATH, "ApplyRootMotion",
		{"tree": "$Anim", "scale": "1.0", "target": "", "uid": "a1"})
	rows.append(["the 2D twin reads the step once, into a local of its own",
		two_d.split("\n")[0], "var __root_a1: Vector3 = $Anim.get_root_motion_position()"])
	rows.append(["and takes the two dimensions it has, leaving the third alone",
		two_d.split("\n")[1],
			"velocity = (Vector2(__root_a1.x, __root_a1.y) / delta * 1.0) if delta > 0.0 else Vector2.ZERO"])
	rows.append(["turning by the root's turn about the one axis 2D has",
		two_d.split("\n")[2], "rotation += $Anim.get_root_motion_rotation().get_euler().z"])
	rows.append(["a step of three by four in a quarter of a step is four times that",
		_value("Vector2(Vector3(3, 4, 9).x, Vector3(3, 4, 9).y) / 0.25 * 1.0"), Vector2(12.0, 16.0)])
	# A FRAME OF NO TIME IS NO MOVEMENT. Engine.time_scale = 0 is how a game freezes, and a step
	# divided by a frame of zero is an infinity written into velocity - which throws the body out
	# of the level on the next Move And Slide. RUN, both twins, at the frame time that does it.
	rows.append(["a frozen frame moves the 2D body nowhere rather than infinitely far",
		_value("(Vector2(1, 1) / 0.0 * 1.0) if 0.0 > 0.0 else Vector2.ZERO"), Vector2.ZERO])
	rows.append(["and the 3D body likewise",
		_value("((Basis.IDENTITY * Vector3(0, 0, 1)) / 0.0 * 1.0) if 0.0 > 0.0 else Vector3.ZERO"),
			Vector3.ZERO])
	rows.append(["while an ordinary frame still steps",
		_value("(Vector2(1, 1) / 0.5 * 1.0) if 0.5 > 0.0 else Vector2.ZERO"), Vector2(2.0, 2.0)])
	# The row acts on another body when one is named, on EVERY line it names one - which is why it
	# carries its own target rather than taking the automatic prefix.
	var retargeted: String = _emitted(MODULE_PATH, "ApplyRootMotion3D",
		{"tree": "$Anim", "scale": "1.0", "target": "$Rider", "uid": "a1"})
	rows.append(["the retargeted 3D row names the other body on both sides",
		retargeted.split("\n")[0],
		"$Rider.velocity = (($Rider.basis * $Anim.get_root_motion_position()) / delta * 1.0) if delta > 0.0 else Vector3.ZERO"])
	return SUPPORT.pins("animation_tree_aces_test", rows)


## The two state moments are signals of the PLAYBACK object, so the `_ready` line has to reach
## through the tree to it. Pinned as the compiled file, because a connect line aimed at the node
## would compile perfectly and fail at run time.
static func _run_state_moments() -> bool:
	var rows: Array = []
	var entered: Dictionary = TriggerResolver.resolve_trigger(_trigger_row("OnAnimationStateEntered", "Anim"))
	rows.append(["entering a state hangs off the playback's own signal",
		str(entered.get("signal_name", "")), "state_started"])
	rows.append(["the state's name rides along", str(entered.get("args", "")), "state: StringName"])
	rows.append(["the handler is named after the tree it listens to",
		str(entered.get("function_name", "")), "_on_anim_state_entered"])
	rows.append(["and the source reaches through the tree to the playback object",
		str(entered.get("source_path", "")), "member:get_node(\"Anim\").get(\"parameters/playback\")"])
	var self_hosted: Dictionary = TriggerResolver.resolve_trigger(_trigger_row("OnAnimationStateLeft", ""))
	rows.append(["a sheet that IS the tree reaches its own playback",
		str(self_hosted.get("source_path", "")), "member:get(\"parameters/playback\")"])
	rows.append(["leaving a state is the machine's other signal",
		str(self_hosted.get("signal_name", "")), "state_finished"])
	var marker: Dictionary = TriggerResolver.resolve_trigger(_trigger_row("OnAnimationReachedMarker", ""))
	rows.append(["a marker moment rides the mixer's own step",
		str(marker.get("signal_name", "")), "mixer_updated"])
	# The whole compiled file: the connect line, and that the file parses at all.
	var compiled: String = _compiled(_state_sheet())
	rows.append(["the connect line is the one a hand-written project writes",
		compiled.contains("\tget_node(\"Anim\").get(\"parameters/playback\").state_started.connect(_on_anim_state_entered)"), true])
	rows.append(["the handler is written with the state it was handed",
		compiled.contains("func _on_anim_state_entered(state: StringName) -> void:"), true])
	rows.append(["and the whole emitted file parses", _parses(compiled), true])
	# THE CROSSING, COMPILED. Its memory is cleared in a PRELUDE and read in the term, which are two
	# halves of one row - so both have to address the same node, and both have to understand the
	# optional `{target.}` slot. They did not: the prelude wrote its braces out verbatim and the file
	# did not parse. Pinned as the whole emitted handler.
	var marker_file: String = _compiled(_marker_sheet())
	rows.append(["the crossing's memory is cleared before the question is asked",
		marker_file.contains("\t__marker_z9 = __marker_z9 and current_animation == \"attack\" and current_animation_position >= get_animation(\"attack\").get_marker_time(\"impact\")"), true])
	rows.append(["the question is the comparison AND not having answered it already",
		marker_file.contains("\tif (current_animation == \"attack\" and current_animation_position >= get_animation(\"attack\").get_marker_time(\"impact\")) and not __marker_z9:"), true])
	rows.append(["answering it writes the memory down", marker_file.contains("\t\t__marker_z9 = true"), true])
	rows.append(["the memory itself is declared once, with the row's own id in its name",
		marker_file.contains("var __marker_z9: bool = false"), true])
	rows.append(["and that whole file parses too", _parses(marker_file), true])
	return SUPPORT.pins("animation_tree_aces_test", rows)


## The bones: the 3D row sets the engine's own modifier up, and the 2D twin does the one line the
## modifier would have done.
static func _run_bones() -> bool:
	var by_id: Dictionary = _by_id(SKELETON_PATH)
	var rows: Array = []
	for entry: Array in [
			["PointBoneAt3D", ACEDescriptor.ACEType.ACTION, "LookAtModifier3D"],
			["PointBoneAt2D", ACEDescriptor.ACEType.ACTION, "Bone2D"],
			["BonePosition3D", ACEDescriptor.ACEType.EXPRESSION, "Skeleton3D"],
			["BonePosition2D", ACEDescriptor.ACEType.EXPRESSION, "Bone2D"],
			["SetBonePoseOverride", ACEDescriptor.ACEType.ACTION, "Skeleton3D"],
			["SetBonePoseOverride2D", ACEDescriptor.ACEType.ACTION, "Skeleton2D"]]:
		var ace_id: String = str(entry[0])
		rows.append(["%s is registered" % ace_id, by_id.has(ace_id), true])
		if not by_id.has(ace_id):
			continue
		rows.append(["%s is the kind it says" % ace_id, int((by_id[ace_id] as ACEDescriptor).ace_type), int(entry[1])])
		rows.append(["%s belongs to the node it acts on" % ace_id, str((by_id[ace_id] as ACEDescriptor).node_type), str(entry[2])])
		rows.append(["%s files under Skeleton" % ace_id, str((by_id[ace_id] as ACEDescriptor).category), "Skeleton"])
	var point: String = _emitted(SKELETON_PATH, "PointBoneAt3D",
		{"bone": "\"Head\"", "node": "$Player", "seconds": "0.2", "weight": "1.0", "target": ""})
	rows.append(["the 3D row names the bone on the modifier", point.split("\n")[0], "bone_name = \"Head\""])
	rows.append(["and points it at a path relative to the modifier itself",
		point.split("\n")[1], "target_node = get_path_to($Player)"])
	rows.append(["the ease is the modifier's own duration", point.split("\n")[2], "duration = 0.2"])
	rows.append(["and the weight its own influence", point.split("\n")[3], "influence = 1.0"])
	rows.append(["a retargeted modifier is named on both sides of the path line",
		_emitted(SKELETON_PATH, "PointBoneAt3D", {"bone": "\"Head\"", "node": "$Player", "seconds": "0.2", "weight": "1.0", "target": "$Rig/LookAt"}).split("\n")[1],
		"$Rig/LookAt.target_node = $Rig/LookAt.get_path_to($Player)"])
	rows.append(["the 2D twin turns the bone a frame's worth toward the thing",
		_emitted(SKELETON_PATH, "PointBoneAt2D", {"node": "$Player", "seconds": "0.2", "weight": "1.0", "target": ""}),
		"global_rotation = lerp_angle(global_rotation, ($Player.global_position - global_position).angle(), clampf(delta / maxf(0.2, 0.001), 0.0, 1.0) * 1.0)"])
	# A quarter of the way through a fifth of a second is a quarter of the turn, and the clamp is
	# what stops a long frame overshooting it.
	rows.append(["a frame that is a quarter of the time takes a quarter of the turn",
		_value("clampf(0.05 / maxf(0.2, 0.001), 0.0, 1.0) * 1.0"), 0.25])
	rows.append(["and a frame longer than the whole time still only takes all of it",
		_value("clampf(0.9 / maxf(0.2, 0.001), 0.0, 1.0) * 1.0"), 1.0])
	rows.append(["a bone's place is read back out of skeleton space into the world's",
		_emitted(SKELETON_PATH, "BonePosition3D", {"bone": "\"Head\"", "target": ""}),
		"(global_transform * get_bone_global_pose(find_bone(\"Head\"))).origin"])
	# THE POSE IS IN THE WORLD'S SPACE, as the field says - and the engine call wants one in the
	# SKELETON'S, which is the trap the reading row above corrects for in the other direction. The
	# row divides the skeleton out, so a pose read from Bone Position means what it says.
	rows.append(["an override is a pose AND how much of it wins",
		_emitted(SKELETON_PATH, "SetBonePoseOverride", {"bone": "\"Spine\"", "pose": "Transform3D.IDENTITY", "amount": "0.5", "target": ""}),
		"set_bone_global_pose_override(find_bone(\"Spine\"), global_transform.affine_inverse() * Transform3D.IDENTITY, 0.5, true)"])
	rows.append(["and the 2D twin says the same thing to a 2D skeleton",
		_emitted(SKELETON_PATH, "SetBonePoseOverride2D", {"bone": "2", "pose": "Transform2D.IDENTITY", "amount": "0.5", "target": ""}),
		"set_bone_local_pose_override(2, Transform2D.IDENTITY, 0.5, true)"])
	return SUPPORT.pins("animation_tree_aces_test", rows)


## The tree's own names, read off a scene rather than guessed - once from a tree kept inside the
## scene, once from one kept in a file the scene points at.
static func _run_tree_reading() -> bool:
	var rows: Array = []
	_write(SCENE_PROBE, FIXTURE_SCENE)
	EventSheetSceneAnimationTree.clear_cache()
	EventSheetSceneConnections.clear_cache()
	var trees: Array[Dictionary] = EventSheetSceneAnimationTree.for_scene(SCENE_PROBE)
	rows.append(["the scene's one tree is found", trees.size(), 1])
	rows.append(["named as the scene names it", str(trees[0].get("name", "")) if not trees.is_empty() else "", "Anim"])
	rows.append(["every state of the machine is read, however deep it sits",
		Array(EventSheetSceneAnimationTree.state_names(trees)), ["Idle", "Run", "Swing", "Aiming"]])
	# A SPACE IS OFFERED UNDER ITS PATH, because the path is what the row writes: a space inside a
	# state machine is `parameters/Machine/Aiming/blend_position`, and a bare "Aiming" dropped into
	# that string names a parameter the tree does not have - accepted by set() and silent for ever.
	rows.append(["the spaces are the nodes that take a position, each under the path it sits at",
		Array(EventSheetSceneAnimationTree.space_names(trees)), ["Locomotion", "Machine/Aiming"]])
	rows.append(["the layers are the ones that take an amount",
		Array(EventSheetSceneAnimationTree.layer_names(trees)), ["Aim"]])
	rows.append(["and a one-dimensional space says it is one",
		EventSheetSceneAnimationTree.dimensions_of(trees, "Locomotion"), 1])
	rows.append(["and a nested one says how many it has, asked by that same path",
		EventSheetSceneAnimationTree.dimensions_of(trees, "Machine/Aiming"), 2])
	rows.append(["while its bare name is a parameter nothing has",
		EventSheetSceneAnimationTree.dimensions_of(trees, "Aiming"), 0])
	rows.append(["a name no tree declares has no dimensions at all",
		EventSheetSceneAnimationTree.dimensions_of(trees, "Nonesuch"), 0])
	rows.append(["a misspelled state is caught",
		Array(EventSheetSceneAnimationTree.missing_states(trees, PackedStringArray(["&\"Swng\"", "&\"Idle\""]))), ["Swng"]])
	rows.append(["with the one it was nearly offered",
		EventSheetSceneAnimationTree.nearest(trees, "&\"Swng\""), "Swing"])
	rows.append(["a name built while the game runs is never checked",
		Array(EventSheetSceneAnimationTree.missing_states(trees, PackedStringArray(["\"attack_\" + weapon"]))), []])
	# The same read, through a file. A rig of any size keeps its tree in one.
	_write(TREE_PROBE, FIXTURE_TREE_FILE)
	_write(EXTERNAL_SCENE_PROBE, FIXTURE_EXTERNAL_SCENE)
	EventSheetSceneAnimationTree.clear_cache()
	EventSheetSceneConnections.clear_cache()
	var external: Array[Dictionary] = EventSheetSceneAnimationTree.for_scene(EXTERNAL_SCENE_PROBE)
	rows.append(["a tree kept in a file is opened and read",
		Array(EventSheetSceneAnimationTree.space_names(external)), ["Ground"]])
	rows.append(["and a two-dimensional space says it is two",
		EventSheetSceneAnimationTree.dimensions_of(external, "Ground"), 2])
	EventSheetSceneAnimationTree.clear_cache()
	EventSheetSceneConnections.clear_cache()
	return SUPPORT.pins("animation_tree_aces_test", rows)


## The two quiet notes, over one script and one tree - no filesystem, no project.
static func _run_doctor() -> bool:
	var rows: Array = []
	_write(SCENE_PROBE, FIXTURE_SCENE)
	EventSheetSceneAnimationTree.clear_cache()
	EventSheetSceneConnections.clear_cache()
	var trees: Array[Dictionary] = EventSheetSceneAnimationTree.for_scene(SCENE_PROBE)
	var source: String = "func _ready() -> void:\n\t$Anim.get(\"parameters/playback\").travel(&\"Swng\")\n\t$Anim.set(\"parameters/Locomotion/blend_position\", Vector2(1, 0))\n"
	var findings: Array[Dictionary] = EventSheetAnimationDoctor.report(
		[{"path": "res://player.gd", "source": source, "trees": trees}])
	rows.append(["the section reports its summary and both notes", findings.size(), 3])
	rows.append(["the summary counts what it found",
		str(findings[0].get("message", "")),
		"Animation: 1 script(s) drive a blend tree, 1 state(s) no tree declares, 1 blend position(s) written as a vector into a one-dimensional space."])
	rows.append(["a state nobody declared is filed as itself",
		str(findings[1].get("check", "")), "animation-unknown-state"])
	rows.append(["and says which state, with the one it was nearly",
		str(findings[1].get("message", "")),
		"player.gd travels to \"Swng\", which no animation tree in its scene declares. A misspelled state travels nowhere and is never reported by the game itself. Did you mean \"Swing\"?"])
	rows.append(["a vector into a line is filed as itself",
		str(findings[2].get("check", "")), "animation-blend-dimensions"])
	rows.append(["and says what is quietly dropped",
		str(findings[2].get("message", "")),
		"player.gd writes a vector into \"Locomotion\", which is a one-dimensional blend space. Only the first number is used - the rest of the direction is dropped without a word."])
	rows.append(["every note is a note, never an error",
		[str(findings[1].get("severity", "")), str(findings[2].get("severity", ""))], ["info", "info"]])
	# A script no scene can be paired with has no list of names to be wrong about, so it is counted
	# and asked nothing else. That is the difference between a quiet reading and a noisy one.
	var unpaired: Array[Dictionary] = EventSheetAnimationDoctor.report(
		[{"path": "res://shared.gd", "source": source, "trees": [] as Array[Dictionary]}])
	rows.append(["a script no one scene runs earns the summary and nothing else", unpaired.size(), 1])
	# And a correct sheet earns no note at all, which is the whole of the quiet sheet.
	var clean: String = "func _ready() -> void:\n\t$Anim.get(\"parameters/playback\").travel(&\"Swing\")\n\t$Anim.set(\"parameters/Locomotion/blend_position\", 0.5)\n"
	var quiet: Array[Dictionary] = EventSheetAnimationDoctor.report(
		[{"path": "res://player.gd", "source": clean, "trees": trees}])
	rows.append(["a sheet that says it right says nothing back", quiet.size(), 1])
	rows.append(["and its summary counts no trouble", str(quiet[0].get("message", "")),
		"Animation: 1 script(s) drive a blend tree, 0 state(s) no tree declares, 0 blend position(s) written as a vector into a one-dimensional space."])
	# The two readers behind the notes, on their own: what the sweep sees in a line.
	rows.append(["the sweep reads the state out of a travel",
		Array(EventSheetAnimationDoctor.states_travelled_to(source)), ["&\"Swng\""]])
	var written: Array[Dictionary] = EventSheetAnimationDoctor.blend_positions_written(source)
	rows.append(["and the space and the value out of a blend write",
		[str(written[0].get("space", "")), str(written[0].get("value", ""))] if not written.is_empty() else [],
		["Locomotion", "Vector2(1, 0)"]])
	EventSheetSceneAnimationTree.clear_cache()
	EventSheetSceneConnections.clear_cache()
	DirAccess.remove_absolute(SCENE_PROBE)
	DirAccess.remove_absolute(EXTERNAL_SCENE_PROBE)
	DirAccess.remove_absolute(TREE_PROBE)
	return SUPPORT.pins("animation_tree_aces_test", rows)


## A hand-typed travel, opened as the row that would have written it, and saved again unchanged -
## and the line that is deliberately NOT claimed.
static func _run_lift() -> bool:
	var rows: Array = []
	_write(SCRIPT_PROBE, HAND_WRITTEN)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SCRIPT_PROBE, false)
	EventSheetACELifter.reset_progress()
	rows.append(["the file opens as events", EventSheetACELifter.attempt_lift(sheet, HAND_WRITTEN), true])
	var found: ACEAction = _find_action(sheet, "TravelToState")
	rows.append(["the travel opens as the row that writes it", found != null, true])
	if found != null:
		rows.append(["with the state it was written with", str(found.params.get("state", "")), "&\"Swing\""])
		rows.append(["and the tree it was written on", str(found.params.get("target", "")), "$Anim"])
	rows.append(["and saving it again reproduces the file byte for byte",
		str(SheetCompiler.compile(sheet, SCRIPT_PROBE).get("output", "")), HAND_WRITTEN])
	# DELIBERATELY NOT CLAIMED: a bare `global_position` read is the line the shipped place rows
	# already speak for, so the 2D bone expression authors only.
	rows.append(["the 2D bone reading is kept out of the reverse index",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("BonePosition2D"), true])
	rows.append(["and so is the crossing, whose line only exists inside a compiled sheet",
		EventSheetACELifter.REVERSE_LIFT_EXCLUDED_ACE_IDS.has("AnimationJustPastMarker"), true])
	DirAccess.remove_absolute(SCRIPT_PROBE)
	return SUPPORT.pins("animation_tree_aces_test", rows)


# -- the pieces ------------------------------------------------------------------------------


## A sheet whose host IS the tree's owner, holding one state event - the shape whose `_ready` line
## has to reach the playback object.
static func _state_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event_row: EventRow = _trigger_row("OnAnimationStateEntered", "Anim")
	var say: ACEAction = ACEAction.new()
	say.provider_id = "Core"
	say.ace_id = "Print"
	say.codegen_template = "print(state)"
	event_row.actions.append(say)
	sheet.events.append(event_row)
	return sheet


## A sheet holding the marker trigger and the crossing question the dock drops under it, with the
## uid already baked exactly as the dock bakes it at apply time.
static func _marker_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "AnimationPlayer"
	var event_row: EventRow = _trigger_row("OnAnimationReachedMarker", "")
	event_row.trigger_params = {"animation": "\"attack\"", "marker": "\"impact\""}
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "AnimationJustPastMarker")
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "AnimationJustPastMarker"
	gate.codegen_template = str(descriptor.codegen_template).replace("{uid}", "z9")
	gate.member_declaration = str(descriptor.member_template).replace("{uid}", "z9")
	gate.codegen_prelude = str(descriptor.codegen_prelude).replace("{uid}", "z9")
	gate.codegen_on_true = str(descriptor.codegen_on_true).replace("{uid}", "z9")
	gate.params = {"animation": "\"attack\"", "marker": "\"impact\"", "target": ""}
	event_row.conditions.append(gate)
	var say: ACEAction = ACEAction.new()
	say.provider_id = "Core"
	say.ace_id = "Print"
	say.codegen_template = "print(\"hit\")"
	event_row.actions.append(say)
	sheet.events.append(event_row)
	return sheet


static func _trigger_row(trigger_id: String, source_path: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	row.trigger_source_path = source_path
	return row


static func _find_action(sheet: EventSheetResource, ace_id: String) -> ACEAction:
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row == null:
			continue
		for candidate: Variant in event_row.actions:
			var action: ACEAction = candidate as ACEAction
			if action != null and str(action.ace_id) == ace_id:
				return action
	return null


static func _compiled(sheet: EventSheetResource) -> String:
	var output: String = str(SheetCompiler.compile(sheet, COMPILE_PROBE).get("output", ""))
	if FileAccess.file_exists(COMPILE_PROBE):
		DirAccess.remove_absolute(COMPILE_PROBE)
	return output


## Runs an emitted expression for real - the pinned text is also the text that is run.
static func _value(expression: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends RefCounted\n\n\nstatic func probe() -> Variant:\n\treturn %s\n" % expression
	if script.reload() != OK:
		print("  [FAIL] animation_tree_aces_test: an emitted expression did not compile")
		return null
	return script.call("probe")


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


## What the SHIPPED row emits, not what the module file authored: a node-scoped row gains its
## `{target.}` prefix and its "On node" field at registration, so the template a reader's row really
## carries is the registry's one. The module path is still asked for, so a row that failed to reach
## the registry at all is named rather than silently emitting nothing.
static func _emitted(module_path: String, ace_id: String, params: Dictionary) -> String:
	if not _by_id(module_path).has(ace_id):
		return ""
	var shipped: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if shipped == null:
		return ""
	return ActionCodegen._apply_template(str(shipped.codegen_template), params)


static func _by_id(module_path: String) -> Dictionary:
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in load(module_path).get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	return by_id


## One parameter's hint, or "" when the row has no such field.
static func _hint_of(descriptor: ACEDescriptor, param_id: String) -> String:
	for param: ACEParam in descriptor.params:
		if str(param.id) == param_id:
			return str(param.hint)
	return ""


## One vector as the arithmetic hands it back: a rotated basis leaves millionths behind, and a
## millionth is finer than any distance a character moves in a frame.
static func _rounded_vector3(value: Variant) -> Vector3:
	var vector: Vector3 = value
	return Vector3(snappedf(vector.x, 0.000001), snappedf(vector.y, 0.000001), snappedf(vector.z, 0.000001))


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
