# Godot EventSheets - the huge project, fabricated on demand.
#
# Every budget in this suite until now was measured on THIS repository, which is a large Godot
# project by any normal standard and still nothing like the one the plugin has to survive: a game
# two years in, a thousand scripts, three hundred scenes, a hundred shaders, and a scene the
# level designer never split up. A budget measured on a small corpus is a budget that passes on
# the day the corpus stops being small.
#
# So the corpus is generated instead of committed. Committing 1,400 files would slow every import,
# every drift audit and every clone in the repository for the sake of two tests, so the generator
# writes them under `user://` the first time a test asks and leaves them there: machine-local,
# invisible to git, and rebuilt only when the shapes below change.
#
# DETERMINISTIC, with no random source at all. Everything is derived from the file's index, so two
# machines that generate it get byte-identical files and a budget measured on one means something
# on the other. The stamp file records the revision and the counts; a run whose stamp matches skips
# straight to the manifest, which is why asking for the fixture costs milliseconds after the first
# time.
#
# WHAT IT CANNOT DO: `res://` is fixed when the process starts, so the whole-project scanners (the
# Doctor's sheet list, the picker's vocabulary, the shared-resource index) cannot be pointed at it.
# Those are measured against this repository instead, which carries 111 packs and every demo, and
# the budget test says so where it does it.
#
# USAGE - a helper, not a test (it declares no `run`, so the suite skips it):
#
#     const HugeProject := preload("res://tests/huge_project_fixture.gd")
#     var project: Dictionary = HugeProject.build()
#     var source: String = FileAccess.get_file_as_string(project["big_script"])
@tool
extends RefCounted

## Where the fabricated project lives. Machine-local, outside the repository, and safe to delete.
const ROOT: String = "user://eventsheets_huge_fixture"

## Bump when the SHAPES below change, so a stale fixture on a developer's machine is rebuilt
## instead of quietly measuring last month's corpus.
const REVISION: int = 2

## The corpus, sized at what the design brief calls a huge project.
const SCRIPT_COUNT: int = 1000
const SCENE_COUNT: int = 300
const SHADER_COUNT: int = 100

## The one script nobody wants to open and everybody has: a two-thousand-line controller.
const BIG_SCRIPT_LINES: int = 2000

## The scene a level designer never split up, and the two smaller ones beside it, so a budget can
## tell a 2,000-node walk from a 40-node one.
const BIG_SCENE_NODES: int = 2000
const BIG_SCENE_COUNT: int = 3
const SMALL_SCENE_NODES: int = 40

## Nodes per parent in a generated scene: a flat list of 2,000 children is not a scene anybody
## builds, and a reader that walks paths pays differently for a deep tree than for a wide one.
const NODES_PER_BRANCH: int = 20

## The seven shapes real project scripts come in. Every generated script is one of them, chosen by
## its index, so the corpus carries the same mix of work the plugin meets in a real tree.
const SHAPES: Array[String] = ["variables", "groups", "functions", "networking",
	"lighting", "effects", "raw"]

## Node classes the generated scenes are built from - lights the lighting facts read, sprites the
## effect facts read, bodies and areas that are neither, so a fact reader pays for the filtering it
## really does rather than for a scene made entirely of what it is looking for.
const SCENE_CLASSES: Array[String] = ["Node2D", "Sprite2D", "PointLight2D", "StaticBody2D",
	"Area2D", "LightOccluder2D", "AnimatedSprite2D", "CollisionShape2D"]

## Dial types the generated shaders declare, with the hint each one is normally written with.
const DIAL_TYPES: Array[String] = ["float", "vec4", "sampler2D", "int", "bool", "vec2"]


## Builds the project if it is missing or stale, then returns its manifest:
##   {root, scripts, scenes, shaders, big_script, big_scene, small_scene}
## `scripts`, `scenes` and `shaders` are every generated path, in generation order; the last three
## name the one file of each shape a budget usually wants. Calling this twice in one session costs
## one file read.
static func build() -> Dictionary:
	if not _is_current():
		_generate()
	return manifest()


## The manifest WITHOUT generating anything - the paths the generator would have written. Useful
## for a caller that only wants to know where something is.
static func manifest() -> Dictionary:
	var scripts: PackedStringArray = PackedStringArray()
	for index in SCRIPT_COUNT:
		scripts.append(script_path(index))
	var scenes: PackedStringArray = PackedStringArray()
	for index in SCENE_COUNT:
		scenes.append(scene_path(index))
	var shaders: PackedStringArray = PackedStringArray()
	for index in SHADER_COUNT:
		shaders.append(shader_path(index))
	return {
		"root": ROOT,
		"scripts": scripts,
		"scenes": scenes,
		"shaders": shaders,
		"big_script": script_path(0),
		"big_scene": scene_path(0),
		"small_scene": scene_path(SCENE_COUNT - 1),
	}


static func script_path(index: int) -> String:
	return "%s/scripts/script_%04d.gd" % [ROOT, index]


static func scene_path(index: int) -> String:
	return "%s/scenes/scene_%04d.tscn" % [ROOT, index]


static func shader_path(index: int) -> String:
	return "%s/shaders/shader_%03d.gdshader" % [ROOT, index]


## Deletes the whole fixture. Nothing in the suite calls this; it is here so a developer chasing a
## generator bug can force the next run to rebuild without hunting for the folder.
static func clear() -> void:
	_remove_tree(ROOT)


## True when the fixture on disk was written by THIS revision at THESE counts.
static func _is_current() -> bool:
	return FileAccess.get_file_as_string("%s/stamp.txt" % ROOT).strip_edges() == _stamp()


static func _stamp() -> String:
	return "revision=%d scripts=%d scenes=%d shaders=%d lines=%d nodes=%d" % [
		REVISION, SCRIPT_COUNT, SCENE_COUNT, SHADER_COUNT, BIG_SCRIPT_LINES, BIG_SCENE_NODES]


## Writes the whole corpus. The stamp is written LAST, so a run interrupted half way through
## regenerates next time instead of being trusted.
static func _generate() -> void:
	_remove_tree(ROOT)
	for folder: String in ["scripts", "scenes", "shaders"]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [ROOT, folder])
	for index in SCRIPT_COUNT:
		_write(script_path(index), _script_source(index))
	for index in SCENE_COUNT:
		_write(scene_path(index), _scene_source(index))
	for index in SHADER_COUNT:
		_write(shader_path(index), _shader_source(index))
	_write("%s/stamp.txt" % ROOT, _stamp())
	# Nothing outside the editor sends the filesystem ping the by-file readers invalidate on, so a
	# regenerated corpus at the same paths would be read through the identities the last one had.
	EventForgeFileStamp.forget_all()


## Writes one file with explicit LF endings. Godot's FileAccess stores exactly what it is given, but
## every string built here goes through one door so a future edit cannot introduce CRLF by accident:
## a reader that matches `@tool` or a preload head exactly stops recognising `@tool\r`.
static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[huge project fixture] could not write %s" % path)
		return
	file.store_string(text.replace("\r\n", "\n"))
	file.close()


static func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for entry: String in directory.get_directories():
		_remove_tree(path.path_join(entry))
	for entry: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(entry))
	DirAccess.remove_absolute(path)


# ── The scripts ────────────────────────────────────────────────────────────────────────────────


## One script's whole text. Index 0 is the two-thousand-line controller (every shape, over and
## over, with unique names); every other index is one shape, at the length most files really are.
static func _script_source(index: int) -> String:
	if index == 0:
		return _big_script_source()
	var shape: String = SHAPES[index % SHAPES.size()]
	var lines: PackedStringArray = PackedStringArray([
		"# %s - generated fixture, shaped like a %s script." % [_script_class(index), shape],
		"extends %s" % _script_base(shape),
		"",
		"",
	])
	lines.append_array(_variable_lines(index))
	lines.append("")
	for step in 4:
		lines.append_array(_function_lines(shape, index, step))
		lines.append("")
	return "\n".join(lines).strip_edges() + "\n"


## The two-thousand-line one. Its functions cycle through every shape so the open budget pays for
## the whole vocabulary rather than for one family's recognisers.
static func _big_script_source() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"# The controller nobody wanted to write and everybody has.",
		"extends CharacterBody2D",
		"",
		"",
	])
	lines.append_array(_variable_lines(0))
	lines.append("")
	var step: int = 0
	while lines.size() < BIG_SCRIPT_LINES:
		lines.append_array(_function_lines(SHAPES[step % SHAPES.size()], 0, step))
		lines.append("")
		step += 1
	return "\n".join(lines).strip_edges() + "\n"


static func _script_class(index: int) -> String:
	return "Fixture%04d" % index


static func _script_base(shape: String) -> String:
	match shape:
		"networking":
			return "CharacterBody2D"
		"lighting":
			return "Node2D"
		"effects":
			return "Sprite2D"
		_:
			return "Node2D"


## The declarations at the top of a file: exported dials, a constant, a static counter and the
## plain instance variables. Four kinds, because reading a declaration is four different jobs.
static func _variable_lines(index: int) -> PackedStringArray:
	return PackedStringArray([
		"const MAX_HEALTH: int = %d" % (50 + index % 50),
		"",
		"@export var speed: float = %d.0" % (100 + index % 200),
		"@export_range(0.0, 1.0) var friction: float = 0.%02d" % (index % 100),
		"static var spawned: int = 0",
		"var health: int = %d" % (10 + index % 40),
		"var alive: bool = true",
		"var label: String = \"unit %04d\"" % index,
	])


## One function of a given shape. `step` keeps the names unique inside a file, so a two-thousand
## line script really does declare two hundred different functions rather than one repeated.
static func _function_lines(shape: String, index: int, step: int) -> PackedStringArray:
	var name_text: String = "%s_%02d" % [shape, step]
	var lines: PackedStringArray = PackedStringArray()
	match shape:
		"variables":
			lines.append("func %s() -> void:" % name_text)
			lines.append("\thealth = health - %d" % (1 + step % 5))
			lines.append("\tspawned += 1")
			lines.append("\tif health <= 0:")
			lines.append("\t\talive = false")
		"groups":
			lines.append("#region %s" % name_text)
			lines.append("func %s() -> void:" % name_text)
			lines.append("\tvar total: int = health + MAX_HEALTH")
			lines.append("\tprint(\"%s \" + str(total))" % name_text)
			lines.append("#endregion")
		"functions":
			lines.append("func %s(amount: int = %d) -> int:" % [name_text, step + 1])
			lines.append("\thealth += amount")
			lines.append("\treturn health")
		"networking":
			lines.append("@rpc(\"any_peer\", \"call_local\", \"reliable\")")
			lines.append("func %s(value: int) -> void:" % name_text)
			lines.append("\tif not is_multiplayer_authority():")
			lines.append("\t\treturn")
			lines.append("\thealth = value")
		"lighting":
			lines.append("func %s() -> void:" % name_text)
			lines.append("\t$Torch.energy = 0.%02d" % (step % 100))
			lines.append("\t$Torch.color = Color(\"ffd9a1\")")
			lines.append("\t$Torch.shadow_enabled = true")
		"effects":
			lines.append("func %s() -> void:" % name_text)
			lines.append("\tmaterial.set_shader_parameter(&\"dissolve\", 0.%02d)" % (step % 100))
			lines.append("\tmaterial.set_shader_parameter(&\"tint\", Color(\"88ccff\"))")
		_:
			lines.append("func %s(state: int) -> void:" % name_text)
			lines.append("\tmatch state:")
			lines.append("\t\t0:")
			lines.append("\t\t\twhile health > 0 and alive:")
			lines.append("\t\t\t\thealth -= 1")
			lines.append("\t\t_:")
			lines.append("\t\t\talive = health > %d" % (index % 7))
	lines.append("")
	return lines


# ── The scenes ─────────────────────────────────────────────────────────────────────────────────


## One scene file. The first BIG_SCENE_COUNT scenes are the 2,000-node kind; the rest are the size
## a normal scene is. Each one carries the script of the same index, so a reader asked "what scene
## uses this script" has a real answer to find, and one shader material every sprite in it wears, so
## the effect facts have wearers to count rather than an empty walk.
static func _scene_source(index: int) -> String:
	var node_count: int = BIG_SCENE_NODES if index < BIG_SCENE_COUNT else SMALL_SCENE_NODES
	var lines: PackedStringArray = PackedStringArray([
		"[gd_scene load_steps=4 format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"%s\" id=\"1_script\"]" % script_path(index % SCRIPT_COUNT),
		"[ext_resource type=\"Shader\" path=\"%s\" id=\"2_shader\"]" % shader_path(index % SHADER_COUNT),
		"",
		"[sub_resource type=\"ShaderMaterial\" id=\"ShaderMaterial_1\"]",
		"shader = ExtResource(\"2_shader\")",
		"shader_parameter/dial_00 = 0.5",
		"",
		"[node name=\"Root%04d\" type=\"Node2D\"]" % index,
		"script = ExtResource(\"1_script\")",
		"",
	])
	var branch: String = "."
	for node_index in node_count:
		if node_index % NODES_PER_BRANCH == 0:
			branch = "Branch%03d" % (node_index / NODES_PER_BRANCH)
			lines.append("[node name=\"%s\" type=\"Node2D\" parent=\".\"]" % branch)
			lines.append("")
			continue
		lines.append_array(_scene_node_lines(node_index, branch))
	return "\n".join(lines)


## One node block, with the property lines a fact reader actually looks for: a light's shadow flag
## and cull mask, an occluder's mask, a sprite's material.
static func _scene_node_lines(node_index: int, branch: String) -> PackedStringArray:
	var node_class: String = SCENE_CLASSES[node_index % SCENE_CLASSES.size()]
	var lines: PackedStringArray = PackedStringArray([
		"[node name=\"Node%04d\" type=\"%s\" parent=\"%s\"]" % [node_index, node_class, branch],
	])
	match node_class:
		"PointLight2D":
			lines.append("shadow_enabled = %s" % ("true" if node_index % 3 == 0 else "false"))
			lines.append("range_item_cull_mask = %d" % (1 + node_index % 4))
			lines.append("energy = 0.%02d" % (node_index % 100))
		"LightOccluder2D":
			lines.append("occluder_light_mask = %d" % (1 + node_index % 4))
		"Sprite2D":
			lines.append("material = SubResource(\"ShaderMaterial_1\")")
			lines.append("position = Vector2(%d, %d)" % [node_index % 640, node_index % 360])
		"AnimatedSprite2D":
			lines.append("frame = %d" % (node_index % 8))
		_:
			lines.append("position = Vector2(%d, 0)" % (node_index % 320))
	lines.append("")
	return lines


# ── The shaders ────────────────────────────────────────────────────────────────────────────────


## One shader, with eight dials in the shapes the uniform reader has to tell apart: a ranged float,
## a colour, a texture, a stepper, a toggle and a vector, each described by the comment above it.
static func _shader_source(index: int) -> String:
	var lines: PackedStringArray = PackedStringArray([
		"shader_type canvas_item;",
		"",
	])
	for dial_index in 8:
		var type_text: String = DIAL_TYPES[dial_index % DIAL_TYPES.size()]
		lines.append("// What dial %d of shader %03d does." % [dial_index, index])
		lines.append(_uniform_line(type_text, dial_index))
		lines.append("")
	lines.append("void fragment() {")
	lines.append("\tCOLOR = texture(TEXTURE, UV);")
	lines.append("}")
	lines.append("")
	return "\n".join(lines)


static func _uniform_line(type_text: String, dial_index: int) -> String:
	var dial_name: String = "dial_%02d" % dial_index
	match type_text:
		"float":
			return "uniform float %s : hint_range(0.0, 1.0, 0.01) = 0.5;" % dial_name
		"vec4":
			return "uniform vec4 %s : source_color = vec4(1.0, 1.0, 1.0, 1.0);" % dial_name
		"sampler2D":
			return "uniform sampler2D %s : filter_linear;" % dial_name
		"int":
			return "uniform int %s = %d;" % [dial_name, dial_index]
		"bool":
			return "uniform bool %s = true;" % dial_name
		_:
			return "uniform vec2 %s = vec2(0.0, 0.0);" % dial_name
