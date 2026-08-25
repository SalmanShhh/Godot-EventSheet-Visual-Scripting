# EventSheet - the files a pack ships, and what adding the pack does with them.
#
# A pack used to be one script. Five of the shipped effect packs are a script AND a shader, and one
# is a script and a whole scene, so adding a pack now has a second half: copy what it brought into
# the author's project and put it on the node.
#
# Pinned here by value: what each pack is found to ship (derived from its folder, so a pack ships an
# asset by putting a file in it), that installing copies both files exactly once and never a second
# time, that a node already wearing a material of its own keeps it, and that the two public calls on
# EventSheets answer the same thing as the seam under them.
#
# Installing writes files, so every install here writes into `user://` - a test that installed into
# `res://effects` would leave the repository holding a copy of a shader.
@tool
class_name PackAssetsTest
extends RefCounted

const HIT_FLASH: String = "res://eventsheet_addons/hit_flash/hit_flash_behavior.gd"
const SCREEN_FX: String = "res://eventsheet_addons/screen_fx/screen_fx.gd"
const FLASH: String = "res://eventsheet_addons/flash/flash_behavior.gd"

## Where this test installs. Wiped before each run so a second run measures the same thing as the
## first - "already there" is one of the answers being pinned.
const SANDBOX: String = "user://pack_assets_probe"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _what_each_pack_ships() and all_passed
	all_passed = _installing_copies_once() and all_passed
	all_passed = _a_node_keeps_the_material_it_had() and all_passed
	all_passed = _the_public_calls_answer_the_same() and all_passed
	return all_passed


## What a pack brings with it, read off its own folder.
static func _what_each_pack_ships() -> bool:
	var all_passed: bool = true
	var effect: Dictionary = EventSheetPackAssets.shipped_by(HIT_FLASH)
	all_passed = _check("an effect pack ships its shader",
		str(effect.get("shader", "")), "res://eventsheet_addons/hit_flash/hit_flash.gdshader") and all_passed
	all_passed = _check("and no scene", str(effect.get("scene", "")), "") and all_passed
	var screen: Dictionary = EventSheetPackAssets.shipped_by(SCREEN_FX)
	all_passed = _check("the screen pack ships a scene",
		str(screen.get("scene", "")), "res://eventsheet_addons/screen_fx/screen_fx.tscn") and all_passed
	all_passed = _check("and a shader with it",
		str(screen.get("shader", "")), "res://eventsheet_addons/screen_fx/screen_fx.gdshader") and all_passed
	# That shader is worn by the scene's own rectangle, so adding the pack drops the scene in and
	# copies nothing: the scene has dressed itself, and there is no host that should wear anything.
	all_passed = _check("the scene it ships really wears its own shader",
		FileAccess.get_file_as_string(str(screen.get("scene", ""))).contains(
			"path=\"res://eventsheet_addons/screen_fx/screen_fx.gdshader\""), true) and all_passed
	var plain: Dictionary = EventSheetPackAssets.shipped_by(FLASH)
	all_passed = _check("a pack that is only a script ships neither",
		"%s|%s" % [str(plain.get("shader", "")), str(plain.get("scene", ""))], "|") and all_passed
	all_passed = _check("and nowhere at all ships nothing",
		str(EventSheetPackAssets.shipped_by("").get("shader", "")), "") and all_passed
	return all_passed


## Installing writes the shader and a material wearing it, once. A second call finds both and reports
## nothing created, which is what makes adding the pack to a second node safe.
static func _installing_copies_once() -> bool:
	var all_passed: bool = true
	_wipe(SANDBOX)
	var shipped: String = "res://eventsheet_addons/dissolve/dissolve.gdshader"
	var first: Dictionary = EventSheetPackAssets.install(shipped, SANDBOX)
	all_passed = _check("the install works", bool(first.get("ok", false)), true) and all_passed
	all_passed = _check("the shader lands under the name it shipped with",
		str(first.get("shader_path", "")), SANDBOX + "/dissolve.gdshader") and all_passed
	all_passed = _check("with a material beside it",
		str(first.get("material_path", "")), SANDBOX + "/dissolve_material.tres") and all_passed
	all_passed = _check("and both are what it says it wrote",
		", ".join(first.get("created", PackedStringArray())),
		"%s/dissolve.gdshader, %s/dissolve_material.tres" % [SANDBOX, SANDBOX]) and all_passed
	all_passed = _check("the shader really is on disk",
		FileAccess.file_exists(SANDBOX + "/dissolve.gdshader"), true) and all_passed
	all_passed = _check("and it is the shader that shipped",
		FileAccess.get_file_as_string(SANDBOX + "/dissolve.gdshader"),
		FileAccess.get_file_as_string(shipped)) and all_passed
	var material: ShaderMaterial = ResourceLoader.load(
		SANDBOX + "/dissolve_material.tres", "ShaderMaterial", ResourceLoader.CACHE_MODE_IGNORE) as ShaderMaterial
	all_passed = _check("the material wears the copy rather than the shipped file",
		"" if material == null or material.shader == null else material.shader.resource_path,
		SANDBOX + "/dissolve.gdshader") and all_passed

	var again: Dictionary = EventSheetPackAssets.install(shipped, SANDBOX)
	all_passed = _check("a second install works too", bool(again.get("ok", false)), true) and all_passed
	all_passed = _check("and writes nothing, because the author's copy is the author's",
		", ".join(again.get("created", PackedStringArray())), "") and all_passed
	all_passed = _check("a pack shipping no shader installs nothing",
		bool(EventSheetPackAssets.install("", SANDBOX).get("ok", false)), false) and all_passed
	_wipe(SANDBOX)
	return all_passed


## Whatever an author put on a node outranks what a pack would have put there.
static func _a_node_keeps_the_material_it_had() -> bool:
	var all_passed: bool = true
	_wipe(SANDBOX)
	var installed: Dictionary = EventSheetPackAssets.install(
		"res://eventsheet_addons/outline/outline.gdshader", SANDBOX)
	var material_path: String = str(installed.get("material_path", ""))
	var bare: Sprite2D = Sprite2D.new()
	all_passed = _check("a node with nothing on it wears the pack's material",
		EventSheetPackAssets.wear_material(bare, material_path), true) and all_passed
	all_passed = _check("and really is wearing it", bare.material is ShaderMaterial, true) and all_passed
	all_passed = _check("a node already wearing one is left alone",
		EventSheetPackAssets.wear_material(bare, material_path), false) and all_passed
	var not_drawn: Node = Node.new()
	all_passed = _check("a node that cannot wear a material is not asked to",
		EventSheetPackAssets.wear_material(not_drawn, material_path), false) and all_passed
	bare.free()
	not_drawn.free()
	_wipe(SANDBOX)
	return all_passed


## The two public calls hand back what the seam under them does, so a pack's own tooling and the Add
## flow can never answer differently.
static func _the_public_calls_answer_the_same() -> bool:
	var all_passed: bool = true
	_wipe(SANDBOX)
	all_passed = _check("the public reading of what a pack ships",
		str(EventSheets.pack_shipped_assets(SCREEN_FX).get("scene", "")),
		"res://eventsheet_addons/screen_fx/screen_fx.tscn") and all_passed
	var installed: Dictionary = EventSheets.install_pack_effect(
		"res://eventsheet_addons/wave/wave.gdshader", SANDBOX)
	all_passed = _check("the public install writes the same two files",
		", ".join(installed.get("created", PackedStringArray())),
		"%s/wave.gdshader, %s/wave_material.tres" % [SANDBOX, SANDBOX]) and all_passed
	_wipe(SANDBOX)
	return all_passed


## Removes the sandbox and everything in it, so each run starts from nothing.
static func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s" % label)
	print("       expected: ", expected)
	print("       actual:   ", actual)
	return false
