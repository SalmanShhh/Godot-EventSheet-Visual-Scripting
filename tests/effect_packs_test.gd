# EventForge - the six shader-effect packs (Hit Flash, Dissolve, Outline, Grayscale, Wave, Screen FX).
#
# Three halves, and all three pin VALUES:
#
#   WHAT THE SHEET SEES - the sentence each verb reads as and the line it compiles to. A saved sheet
#   depends on both, so a change to either shows up here as a named string.
#
#   WHAT THE SHADER DECLARES - the dials each shipped `.gdshader` really has, read through the one
#   uniform reader the plugin has. This is the half that makes the picked dial rows work: a pack
#   whose shader renamed a dial while its verbs still wrote the old name would turn nothing, silently,
#   which is the exact failure the reader exists to prevent.
#
#   WHAT THE CODE DOES - the verbs called on a real behaviour over a real Sprite2D, asserting the
#   material's dial really moved. No tree and no frames are needed for that: a walk with nowhere to
#   run a tween writes the value straight, which is deliberate so a verb called from a headless test
#   or from _init is never a no-op.
#
# The five node packs also have to keep SHARING their material block: "which material am I allowed to
# write on" is one answer emitted into all five, and a copy that drifted would be five answers.
@tool
class_name EffectPacksTest
extends RefCounted

const HIT_FLASH: String = "res://eventsheet_addons/hit_flash/hit_flash_behavior.gd"
const DISSOLVE: String = "res://eventsheet_addons/dissolve/dissolve_behavior.gd"
const OUTLINE: String = "res://eventsheet_addons/outline/outline_behavior.gd"
const GRAYSCALE: String = "res://eventsheet_addons/grayscale/grayscale_behavior.gd"
const WAVE: String = "res://eventsheet_addons/wave/wave_behavior.gd"
const SCREEN_FX: String = "res://eventsheet_addons/screen_fx/screen_fx.gd"
const SCREEN_SCENE: String = "res://eventsheet_addons/screen_fx/screen_fx.tscn"

## The five packs that hang under a node and turn its material's dials.
const NODE_PACKS: Array[String] = [HIT_FLASH, DISSOLVE, OUTLINE, GRAYSCALE, WAVE]

## The line all five must carry, byte for byte: the whole point of the shared block is that no pack
## owns its own copy of the private-copy rule.
const SHARED_COPY: String = "\t_worn = found.duplicate() if own_material else found"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _the_verbs_read_and_compile() and all_passed
	all_passed = _the_screen_verbs_read_and_compile() and all_passed
	all_passed = _the_shaders_declare_what_the_verbs_turn() and all_passed
	all_passed = _the_packs_share_one_material_block() and all_passed
	all_passed = _the_screen_scene_rests_hidden() and all_passed
	all_passed = _the_verbs_move_a_real_dial() and all_passed
	all_passed = _the_dials_are_seeded_before_anything_walks_them() and all_passed
	all_passed = _a_pack_without_a_material_says_so() and all_passed
	all_passed = _the_private_copy_is_private() and all_passed
	return all_passed


## The node packs' rows, each pinned by the sentence a reader sees and the line it emits.
static func _the_verbs_read_and_compile() -> bool:
	var all_passed: bool = true
	var flash: Dictionary = _published(HIT_FLASH)
	all_passed = _check("Flash reads as a sentence",
		_template(flash, "Flash"), "Flash [b]{colour}[/b] for [b]{seconds}[/b] s") and all_passed
	all_passed = _check("Flash compiles to the call",
		_code(flash, "Flash"), "{target}.flash({colour}, {seconds})") and all_passed
	all_passed = _check("a dropped Flash row is white",
		str(_param(flash, "Flash", "colour").get("default_value", "")), "Color(1.0, 1.0, 1.0, 1.0)") and all_passed
	all_passed = _check("and aims at its own behaviour node",
		str(_param(flash, "Flash", "target").get("default_value", "")), "$HitFlashBehavior") and all_passed
	all_passed = _check("Is Flashing is a condition",
		_kind(flash, "Is Flashing"), ACEDefinition.ACEType.CONDITION) and all_passed

	var dissolve: Dictionary = _published(DISSOLVE)
	all_passed = _check("Dissolve reads as a sentence",
		_template(dissolve, "Dissolve"), "Dissolve over [b]{seconds}[/b] s") and all_passed
	all_passed = _check("Dissolve compiles to the call",
		_code(dissolve, "Dissolve"), "{target}.dissolve({seconds})") and all_passed
	all_passed = _check("Appear compiles to the call",
		_code(dissolve, "Appear"), "{target}.appear({seconds})") and all_passed
	all_passed = _check("On Dissolved is a trigger",
		_kind(dissolve, "On Dissolved"), ACEDefinition.ACEType.TRIGGER) and all_passed
	all_passed = _check("On Dissolved names its signal",
		str(_definition(dissolve, "On Dissolved").metadata.get("source_name", "")), "dissolved") and all_passed
	all_passed = _check("Burnt Away reads back as an expression",
		_kind(dissolve, "Burnt Away"), ACEDefinition.ACEType.EXPRESSION) and all_passed

	var outline: Dictionary = _published(OUTLINE)
	all_passed = _check("Outline reads as a sentence",
		_template(outline, "Outline"), "Outline [b]{colour}[/b] at [b]{pixels}[/b] px") and all_passed
	all_passed = _check("Outline compiles to the call",
		_code(outline, "Outline"), "{target}.outline({colour}, {pixels})") and all_passed
	all_passed = _check("No Outline compiles to the call",
		_code(outline, "No Outline"), "{target}.no_outline()") and all_passed

	var grayscale: Dictionary = _published(GRAYSCALE)
	all_passed = _check("Grayscale reads as a sentence",
		_template(grayscale, "Grayscale"), "Grayscale to [b]{amount}[/b] over [b]{seconds}[/b] s") and all_passed
	all_passed = _check("Recolour compiles to the call",
		_code(grayscale, "Recolour"), "{target}.recolour({seconds})") and all_passed

	var wave: Dictionary = _published(WAVE)
	all_passed = _check("Wave reads as a sentence",
		_template(wave, "Wave"), "Wave at [b]{strength}[/b] over [b]{seconds}[/b] s") and all_passed
	all_passed = _check("Settle compiles to the call",
		_code(wave, "Settle"), "{target}.settle({seconds})") and all_passed
	all_passed = _check("a dropped Wave row is a shimmer rather than a hallucination",
		str(_param(wave, "Wave", "strength").get("default_value", "")), "0.03") and all_passed
	return all_passed


## Screen FX, whose rows are the ones a reader waits on. Fade To emits `await` in front of the call,
## and STILL carries the retargetable node slot every other pack row has - a project with a layer per
## viewport picks which one fades.
static func _the_screen_verbs_read_and_compile() -> bool:
	var all_passed: bool = true
	var screen: Dictionary = _published(SCREEN_FX)
	all_passed = _check("Shockwave reads as a sentence",
		_template(screen, "Shockwave"), "Shockwave at [b]{at}[/b], strength [b]{strength}[/b]") and all_passed
	all_passed = _check("Shockwave compiles to the call",
		_code(screen, "Shockwave"), "{target}.shockwave({at}, {strength})") and all_passed
	all_passed = _check("Fade To waits for the fade to land",
		_code(screen, "Fade To"), "await {target}.fade_to({colour}, {seconds})") and all_passed
	all_passed = _check("and is still aimed at a layer the reader picks",
		str(_param(screen, "Fade To", "target").get("default_value", "")), "$ScreenFx") and all_passed
	all_passed = _check("Fade Back waits too",
		_code(screen, "Fade Back"), "await {target}.fade_back({colour}, {seconds})") and all_passed
	all_passed = _check("a dropped Fade To row fades to black",
		str(_param(screen, "Fade To", "colour").get("default_value", "")), "Color(0.0, 0.0, 0.0, 1.0)") and all_passed
	all_passed = _check("Blur reads as a sentence",
		_template(screen, "Blur"), "Blur to [b]{amount}[/b] over [b]{seconds}[/b] s") and all_passed
	all_passed = _check("Chromatic Pulse compiles to the call",
		_code(screen, "Chromatic Pulse"), "{target}.chromatic_pulse({strength}, {seconds})") and all_passed
	all_passed = _check("Screen Effect Is Running is a condition",
		_kind(screen, "Screen Effect Is Running"), ACEDefinition.ACEType.CONDITION) and all_passed
	return all_passed


## Every dial a verb writes is one the shipped shader really declares, read through the plugin's one
## uniform reader. This is what makes the picked dial rows show up on a node wearing a pack's
## material, and what would catch a rename in a shader file that the verbs did not follow.
static func _the_shaders_declare_what_the_verbs_turn() -> bool:
	var all_passed: bool = true
	var turned: Dictionary = {
		"res://eventsheet_addons/hit_flash/hit_flash.gdshader": ["flash_color", "flash_amount"],
		"res://eventsheet_addons/dissolve/dissolve.gdshader": ["dissolve", "edge_color", "edge_width", "noise_scale"],
		"res://eventsheet_addons/outline/outline.gdshader": ["outline_color", "outline_width"],
		"res://eventsheet_addons/grayscale/grayscale.gdshader": ["grayscale", "gray_tint"],
		"res://eventsheet_addons/wave/wave.gdshader": ["wave_strength", "wave_length", "wave_speed"],
		"res://eventsheet_addons/screen_fx/screen_fx.gdshader": ["screen", "blur", "fade_color",
			"fade_amount", "shock_center", "shock_radius", "shock_strength", "chromatic"],
	}
	for shader_path: String in turned:
		all_passed = _check("%s declares its dials" % shader_path.get_file(),
			", ".join(EventForgeShaderUniforms.names_of(shader_path)),
			", ".join(PackedStringArray(turned[shader_path]))) and all_passed
	# The declarations the editors are derived from: a burn is a slider between two ends, an edge is a
	# colour swatch, and the screen shader is the one that samples the frame.
	var burn: Dictionary = EventForgeShaderUniforms.find(
		"res://eventsheet_addons/dissolve/dissolve.gdshader", "dissolve")
	all_passed = _check("the burn is a slider",
		EventForgeShaderUniforms.editor_kind(burn), EventForgeShaderUniforms.EDITOR_SLIDER) and all_passed
	all_passed = _check("the burn starts whole",
		EventForgeShaderUniforms.gdscript_default(burn), "0.0") and all_passed
	all_passed = _check("the burn explains itself",
		str(burn.get("about", "")), "How much of the sprite has burned away. 0 is whole, 1 is gone.") and all_passed
	var edge: Dictionary = EventForgeShaderUniforms.find(
		"res://eventsheet_addons/dissolve/dissolve.gdshader", "edge_color")
	all_passed = _check("the burning edge is a colour",
		EventForgeShaderUniforms.editor_kind(edge), EventForgeShaderUniforms.EDITOR_COLOR) and all_passed
	all_passed = _check("the screen shader samples the screen",
		EventForgeShaderUniforms.reads_the_screen(
			"res://eventsheet_addons/screen_fx/screen_fx.gdshader"), true) and all_passed
	all_passed = _check("an effect on a sprite does not",
		EventForgeShaderUniforms.reads_the_screen(
			"res://eventsheet_addons/wave/wave.gdshader"), false) and all_passed
	return all_passed


## The material question is answered once and emitted into all five node packs. A pack that grew its
## own copy would answer it five times, which is how four of them end up sharing a goblin's dials.
static func _the_packs_share_one_material_block() -> bool:
	var all_passed: bool = true
	for path: String in NODE_PACKS:
		all_passed = _check("%s carries the shared private copy" % path.get_file(),
			FileAccess.get_file_as_string(path).contains(SHARED_COPY), true) and all_passed
	return all_passed


## The shipped Screen FX scene is the shape the health checks read: a CanvasLayer with one ColorRect
## under it, wearing the screen shader, HIDDEN. Hidden is the load-bearing word - a visible rectangle
## with every dial at rest redraws the whole screen for no change, which is the finding the Doctor
## raises about exactly this shape.
static func _the_screen_scene_rests_hidden() -> bool:
	var all_passed: bool = true
	var scene: String = FileAccess.get_file_as_string(SCREEN_SCENE)
	all_passed = _check("the layer is a CanvasLayer carrying the pack",
		scene.contains("[node name=\"ScreenFx\" type=\"CanvasLayer\"]"), true) and all_passed
	all_passed = _check("the rectangle is named the one the pack looks for",
		scene.contains("[node name=\"Screen\" type=\"ColorRect\" parent=\".\"]"), true) and all_passed
	all_passed = _check("and it rests hidden", scene.contains("\nvisible = false\n"), true) and all_passed
	all_passed = _check("the pack looks for that name",
		FileAccess.get_file_as_string(SCREEN_FX).contains("const RECT_NAME: String = \"Screen\""), true) and all_passed
	# The Doctor's idle-screen finding reads the scene file, so the shipped scene must produce none.
	all_passed = _check("the shipped layer raises no idle-screen finding",
		EventSheetEffectFindings.idle_screen_effects(SCREEN_SCENE).size(), 0) and all_passed
	return all_passed


## THE VERBS, RUN. A real behaviour over a real Sprite2D wearing the pack's own shader: call the row
## and read the dial back. Values, not counts - and the material is the one the node ends up wearing,
## because the copy is part of what the verb does.
static func _the_verbs_move_a_real_dial() -> bool:
	var all_passed: bool = true
	var flash_pair: Array = _wearing(HIT_FLASH, "res://eventsheet_addons/hit_flash/hit_flash.gdshader")
	var sprite: Sprite2D = flash_pair[0]
	var behaviour: Node = flash_pair[1]
	behaviour.call("flash", Color.RED, 0.0)
	all_passed = _check("a flash with no time left in it is fully washed",
		_worn_dial(sprite, "flash_amount"), 0.0) and all_passed
	all_passed = _check("and the colour it washed with is the one the row named",
		_worn_dial(sprite, "flash_color"), Color.RED) and all_passed
	behaviour.call("_set_dial", "flash_amount", 1.0)
	all_passed = _check("a wash showing reads as flashing", behaviour.call("is_flashing"), true) and all_passed
	behaviour.call("stop_flashing")
	all_passed = _check("and stopping it ends the flash", behaviour.call("is_flashing"), false) and all_passed
	_free_pair(flash_pair)

	var burn_pair: Array = _wearing(DISSOLVE, "res://eventsheet_addons/dissolve/dissolve.gdshader")
	var burning: Sprite2D = burn_pair[0]
	var burner: Node = burn_pair[1]
	burner.call("dissolve", 0.0)
	all_passed = _check("a dissolve with no time is gone at once",
		_worn_dial(burning, "dissolve"), 1.0) and all_passed
	all_passed = _check("the sheet is told it went", burner.call("is_gone"), true) and all_passed
	all_passed = _check("and what has burned away reads back",
		burner.call("burnt_away"), 1.0) and all_passed
	all_passed = _check("a burnt-away node stops drawing", burning.visible, false) and all_passed
	burner.call("appear", 0.0)
	all_passed = _check("appearing brings it back whole", _worn_dial(burning, "dissolve"), 0.0) and all_passed
	all_passed = _check("and shows it again", burning.visible, true) and all_passed
	_free_pair(burn_pair)

	var edge_pair: Array = _wearing(OUTLINE, "res://eventsheet_addons/outline/outline.gdshader")
	edge_pair[1].call("outline", Color.YELLOW, 3.0)
	all_passed = _check("an outline is as thick as the row said",
		_worn_dial(edge_pair[0], "outline_width"), 3.0) and all_passed
	all_passed = _check("in the colour the row named",
		_worn_dial(edge_pair[0], "outline_color"), Color.YELLOW) and all_passed
	edge_pair[1].call("no_outline")
	all_passed = _check("and clearing it leaves no border",
		edge_pair[1].call("is_outlined"), false) and all_passed
	_free_pair(edge_pair)

	var grey_pair: Array = _wearing(GRAYSCALE, "res://eventsheet_addons/grayscale/grayscale.gdshader")
	grey_pair[1].call("grayscale", 1.0, 0.0)
	all_passed = _check("a drained node is grey", grey_pair[1].call("is_gray"), true) and all_passed
	all_passed = _check("and says how far it went", grey_pair[1].call("grayness"), 1.0) and all_passed
	grey_pair[1].call("recolour", 0.0)
	all_passed = _check("recolouring brings it all back", grey_pair[1].call("grayness"), 0.0) and all_passed
	_free_pair(grey_pair)

	var wave_pair: Array = _wearing(WAVE, "res://eventsheet_addons/wave/wave.gdshader")
	wave_pair[1].call("wave", 0.05, 0.0)
	all_passed = _check("a wave pushes as hard as the row said",
		wave_pair[1].call("wave_strength"), 0.05) and all_passed
	all_passed = _check("and reads as moving", wave_pair[1].call("is_waving"), true) and all_passed
	wave_pair[1].call("settle", 0.0)
	all_passed = _check("settling brings the picture back to still",
		wave_pair[1].call("is_waving"), false) and all_passed
	_free_pair(wave_pair)
	return all_passed


## THE FAULT EVERY EFFECT PACK HITS ONCE. Godot answers get_shader_parameter with null for a uniform
## nothing has written yet, not with the value the file declares - and `shader_parameter/<dial>` is
## not a property a tween can even address until something has written it, so a walk on an untouched
## dial fails with "the tweened property does not exist". Every pack therefore writes every dial the
## shader declares before anything walks one.
##
## What is asserted here is that each dial ENDS UP WRITTEN, which is the property the tween needs.
## The value it is written with comes from the renderer, and a headless run draws nothing and knows
## no shader defaults - so under this test a float dial seeds as 0 rather than as the file's own
## number. That the value really is the file's own is proved where it can be: a run with a renderer.
static func _the_dials_are_seeded_before_anything_walks_them() -> bool:
	var all_passed: bool = true
	var pair: Array = _wearing(DISSOLVE, "res://eventsheet_addons/dissolve/dissolve.gdshader")
	(pair[1] as Node).call("_effect_material")
	var unwritten: PackedStringArray = PackedStringArray()
	for dial: String in EventForgeShaderUniforms.names_of(
			"res://eventsheet_addons/dissolve/dissolve.gdshader"):
		if _worn_dial(pair[0], dial) == null:
			unwritten.append(dial)
	all_passed = _check("every dial the shader declares is written before anything walks one",
		", ".join(unwritten), "") and all_passed
	all_passed = _check("the burn is one a tween can address",
		_worn_dial(pair[0], "dissolve"), 0.0) and all_passed
	_free_pair(pair)
	# The screen layer has no host to resolve a material from, so it seeds when it starts instead.
	var screen_source: String = FileAccess.get_file_as_string(SCREEN_FX)
	all_passed = _check("the screen layer seeds its dials when it starts",
		screen_source.contains("_screen = _rect.material as ShaderMaterial\n\t_seed_dials()"), true) and all_passed
	all_passed = _check("through the same block the node packs use",
		screen_source.contains("RenderingServer.shader_get_parameter_default("), true) and all_passed
	return all_passed


## A behaviour whose parent wears no material at all: the verbs do nothing rather than fault, which
## is the case a pack dropped on the wrong node is really in.
static func _a_pack_without_a_material_says_so() -> bool:
	var bare: Sprite2D = Sprite2D.new()
	var behaviour: Node = load(HIT_FLASH).new()
	bare.add_child(behaviour)
	behaviour.set("host", bare)
	behaviour.call("flash", Color.WHITE, 0.0)
	var all_passed: bool = _check("a flash with nothing to write on changes nothing",
		bare.material == null, true)
	all_passed = _check("and the question it answers is no",
		behaviour.call("is_flashing"), false) and all_passed
	bare.free()
	return all_passed


## THE SHARING TRAP, proved rather than promised. Two nodes handed the SAME material file: turning a
## dial on one must not turn it on the other, because the pack takes a private copy first. With the
## knob off they share again, which is the one case where sharing is the point.
static func _the_private_copy_is_private() -> bool:
	var all_passed: bool = true
	var shared: ShaderMaterial = ShaderMaterial.new()
	shared.shader = load("res://eventsheet_addons/grayscale/grayscale.gdshader")
	var first: Sprite2D = Sprite2D.new()
	var second: Sprite2D = Sprite2D.new()
	first.material = shared
	second.material = shared
	var one: Node = load(GRAYSCALE).new()
	var two: Node = load(GRAYSCALE).new()
	first.add_child(one)
	second.add_child(two)
	one.set("host", first)
	two.set("host", second)
	one.call("grayscale", 1.0, 0.0)
	all_passed = _check("the node the row named goes grey", one.call("grayness"), 1.0) and all_passed
	all_passed = _check("and the one beside it does not", two.call("grayness"), 0.0) and all_passed
	all_passed = _check("because it is wearing its own copy now",
		first.material == shared, false) and all_passed
	# Off, and the two of them are one material again.
	var together_a: Sprite2D = Sprite2D.new()
	var together_b: Sprite2D = Sprite2D.new()
	var chorus: ShaderMaterial = ShaderMaterial.new()
	chorus.shader = load("res://eventsheet_addons/grayscale/grayscale.gdshader")
	together_a.material = chorus
	together_b.material = chorus
	var lead: Node = load(GRAYSCALE).new()
	var follower: Node = load(GRAYSCALE).new()
	together_a.add_child(lead)
	together_b.add_child(follower)
	lead.set("host", together_a)
	follower.set("host", together_b)
	lead.set("own_material", false)
	follower.set("own_material", false)
	lead.call("grayscale", 1.0, 0.0)
	all_passed = _check("with the knob off the whole row goes together",
		follower.call("grayness"), 1.0) and all_passed
	first.free()
	second.free()
	together_a.free()
	together_b.free()
	return all_passed


## A Sprite2D wearing a pack's own shader, with that pack's behaviour under it - the shape attaching
## the pack really makes. Returned as [sprite, behaviour] so the caller can free both.
static func _wearing(pack_path: String, shader_path: String) -> Array:
	var sprite: Sprite2D = Sprite2D.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(shader_path)
	sprite.material = material
	var behaviour: Node = load(pack_path).new()
	sprite.add_child(behaviour)
	behaviour.set("host", sprite)
	return [sprite, behaviour]


static func _free_pair(pair: Array) -> void:
	(pair[0] as Node).free()


## One dial off the material the node ENDS UP wearing, which is the private copy rather than the one
## the test handed it.
static func _worn_dial(node: CanvasItem, dial: String) -> Variant:
	var worn: ShaderMaterial = node.material as ShaderMaterial
	return null if worn == null else worn.get_shader_parameter(dial)


## Everything one pack publishes, keyed by the name a reader sees.
static func _published(script_path: String) -> Dictionary:
	var by_name: Dictionary = {}
	for definition: ACEDefinition in EventSheetPackReadingCheck.definitions_for_script(script_path):
		by_name[definition.display_name] = definition
	return by_name


static func _definition(published: Dictionary, display_name: String) -> ACEDefinition:
	var found: Variant = published.get(display_name, null)
	return found as ACEDefinition if found is ACEDefinition else ACEDefinition.new()


static func _template(published: Dictionary, display_name: String) -> String:
	return str(_definition(published, display_name).metadata.get("display_template", ""))


static func _code(published: Dictionary, display_name: String) -> String:
	return str(_definition(published, display_name).metadata.get("codegen_template", ""))


static func _kind(published: Dictionary, display_name: String) -> int:
	return _definition(published, display_name).ace_type


static func _param(published: Dictionary, display_name: String, parameter_id: String) -> Dictionary:
	for parameter: Variant in _definition(published, display_name).parameters:
		if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == parameter_id:
			return parameter as Dictionary
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s" % label)
	print("       expected: ", expected)
	print("       actual:   ", actual)
	return false
