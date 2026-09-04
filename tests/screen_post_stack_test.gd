# Godot EventSheets - the Screen FX post stack, its looks, and the one quiet finding it earns.
#
# The stack is a NAMED LIST of full-screen effects drawn in order, and everything a row asks of it -
# add, order, enable, set, pulse, save, wear, blend - is a change to that list. So that list is what
# this test drives: a ScreenFx built in memory, never added to a tree, with its own verbs called on
# it exactly as the emitted rows call them. Nothing here needs a renderer, a viewport or a frame,
# which is what makes it a suite test rather than a thing somebody looks at.
#
# WITH NO TREE TO RUN A TWEEN IN, the pack's walks land on their final value at once and say so in
# their own comments. That is not a compromise for the test's sake: it is the answer a moment later,
# and it is what makes "a pulse puts the strength back where it found it" a fact this can pin at all.
#
# The three things nothing else in the suite catches:
#   - a row that stops going through the ONE clamp, so a player who asked for no flashing gets a
#     strobe from the layer that was added to protect them;
#   - a look that does not survive being written and read back, which is the whole point of a look
#     being a file the project owns rather than a name in a dropdown;
#   - a shader shipped without the `strength` dial every entry turns, which is an effect that runs,
#     errors at nothing, and shows nothing.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "screen_post_stack_test"

## The pack under test and the look resource it writes, loaded by path rather than named as classes:
## a test that names a class the class cache has not caught up with fails for the wrong reason.
const SCREEN_FX_SCRIPT := "res://eventsheet_addons/screen_fx/screen_fx.gd"
const LOOK_SCRIPT := "res://eventsheet_addons/screen_look_resource/screen_look_resource.gd"

## Where the pack keeps its shaders, and the dial every one of them has to declare.
const POST_DIRECTORY := "res://eventsheet_addons/screen_fx/"
const STRENGTH_DIAL := "strength"
const VISION_DIAL := "vision"


static func run() -> bool:
	var passed: bool = _the_stack_is_a_list()
	passed = _a_pulse_puts_it_back() and passed
	passed = _looks_are_files() and passed
	passed = _no_flashing_is_a_ceiling() and passed
	passed = _the_dials_have_one_say() and passed
	passed = _an_effects_own_dials() and passed
	passed = _every_effect_has_a_shader() and passed
	passed = _the_quiet_finding() and passed
	passed = _no_meta_is_left_behind() and passed
	return passed


## THE STACK AS A LIST: what add, move, enable, disable and remove do to it, in the order a reader
## would do them. Every answer is read back through the pack's own condition and expression, because
## those are what a sheet asks, and a list only the test can see is a list nobody can use.
static func _the_stack_is_a_list() -> bool:
	var layer: Node = _a_layer()
	layer.add_post_effect("vignette", "", 0.4)
	layer.add_post_effect("film grain", "", 0.2)
	layer.add_post_effect("scanlines", "lines", 0.5)
	var rows: Array = [
		["three effects go on in the order they were added", _order(layer),
			"vignette,film grain,lines"],
		["an entry with no name of its own is called after its effect",
			layer.post_effect_is_on("vignette"), true],
		["and one given a name answers to that name instead", layer.post_strength("lines"), 0.5],
		["a name nothing was added under reads back as nothing at all",
			layer.post_strength("bloom"), 0.0],
		["the count is how many are actually drawing", layer.post_effect_count(), 3]
	]
	layer.move_post_effect_before("lines", "film grain")
	rows.append(["moving one before another is the order the screen is built in", _order(layer),
		"vignette,lines,film grain"])
	layer.move_post_effect_before("vignette", "")
	rows.append(["and moving one before nothing gives it the last word", _order(layer),
		"lines,film grain,vignette"])
	layer.disable_post_effect("lines")
	rows.append(["a disabled entry stops drawing", layer.post_effect_is_on("lines"), false])
	rows.append(["without forgetting how far up it was", layer.post_strength("lines"), 0.5])
	rows.append(["and it is still on the stack, in its place", _order(layer),
		"lines,film grain,vignette"])
	layer.enable_post_effect("lines")
	rows.append(["enabling it brings it back exactly as it was",
		"%s %s" % [layer.post_effect_is_on("lines"), layer.post_strength("lines")], "true 0.5"])
	layer.set_post_strength("film grain", 0.9)
	rows.append(["setting a strength is the value the expression reads",
		layer.post_strength("film grain"), 0.9])
	layer.remove_post_effect("film grain")
	rows.append(["removing one takes it off the list", _order(layer), "lines,vignette"])
	layer.add_post_effect("boom", "", 0.5)
	rows.append(["a word that is not an effect is refused rather than added", _order(layer),
		"lines,vignette"])
	layer.clear_look()
	rows.append(["and clearing takes every one of them away at once", _order(layer), ""])
	layer.free()
	return SUPPORT.pins(P, rows)


## THE ONE-SHOT. A pulse is the jam form - one row, no setup - and the whole of its promise is that
## it leaves the screen the way it found it: an effect it borrowed is given back, and one that was
## already there returns to the strength it had.
static func _a_pulse_puts_it_back() -> bool:
	var layer: Node = _a_layer()
	layer.pulse_post_effect("glitch", 0.8, 0.4)
	var rows: Array = [
		["a pulse on an effect the stack did not have leaves nothing behind", _order(layer), ""]
	]
	layer.add_post_effect("vignette", "", 0.25)
	layer.pulse_post_effect("vignette", 0.9, 0.4)
	rows.append(["and a pulse on one that was already there puts its strength back",
		layer.post_strength("vignette"), 0.25])
	rows.append(["leaving the entry itself alone", _order(layer), "vignette"])
	layer.pulse_post_effect("vignette", 0.9, 0.0)
	rows.append(["a pulse with no time at all is a set that stays, because nothing else is honest",
		layer.post_strength("vignette"), 0.9])
	layer.clear_look()
	layer.see_as("deuteranopia")
	rows.append(["See As wears one of the pack's own entries", _order(layer), "see as"])
	rows.append(["numbered the way its shader numbers the four kinds of vision",
		_dial(layer, "see as", VISION_DIAL), 2])
	layer.see_as("normal")
	rows.append(["and normal takes it off again rather than leaving a dial at zero", _order(layer),
		""])
	layer.correct_colours_for("tritanopia")
	rows.append(["the correction is its own entry, numbered the same way",
		"%s %s" % [_order(layer), _dial(layer, "correct colours", VISION_DIAL)],
		"correct colours 3"])
	layer.correct_colours_for("nonsense")
	rows.append(["a kind of vision nobody has is refused rather than guessed at",
		_dial(layer, "correct colours", VISION_DIAL), 3])
	layer.free()
	return SUPPORT.pins(P, rows)


## A LOOK IS A FILE. Built live with rows, written once, read back on another day and worn - and the
## blend between two of them keeps what they share, drops what only the old one had and brings in
## what only the new one has. No preset, no dropdown, no name this plugin chose.
static func _looks_are_files() -> bool:
	var layer: Node = _a_layer()
	layer.add_post_effect("vignette", "", 0.4)
	layer.add_post_effect("scanlines", "", 0.25)
	var path: String = "user://tests/screen_post_stack_look.tres"
	layer.save_look(path, "Dusk")
	var written: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var rows: Array = [
		["the live stack writes out as a file", written != null, true],
		["under the name the row gave it",
			"" if written == null else str(written.get("look_name")), "Dusk"],
		["holding one row per entry, in order", _look_order(written), "vignette,scanlines"],
		["with the strengths that were on the screen", _look_strengths(written), "0.4,0.25"]
	]
	layer.clear_look()
	layer.use_look(written)
	rows.append(["wearing it again rebuilds the stack it came from", _order(layer),
		"vignette,scanlines"])
	rows.append(["at the strengths it recorded",
		"%s %s" % [layer.post_strength("vignette"), layer.post_strength("scanlines")], "0.4 0.25"])
	rows.append(["and the look on the screen answers to its own name", layer.current_look(), "Dusk"])
	rows.append(["which is what Look Is compares", layer.look_is(written), true])
	var night: Array[Dictionary] = [
		{"called": "vignette", "effect": "vignette", "strength": 0.9, "params": {}},
		{"called": "film grain", "effect": "film grain", "strength": 0.3, "params": {}}
	]
	var arriving: Resource = _a_look("Night", night)
	layer.blend_to_look(arriving, 0.6)
	rows.append(["blending to another look keeps what both hold, drops what only the old one had",
		_order(layer), "vignette,film grain"])
	rows.append(["and lands on the new look's own strengths",
		"%s %s" % [layer.post_strength("vignette"), layer.post_strength("film grain")], "0.9 0.3"])
	rows.append(["with the arriving look's name on the screen", layer.current_look(), "Night"])
	layer.clear_look()
	rows.append(["clearing a look leaves no name behind either", layer.current_look(), ""])
	rows.append(["and the empty stack is what the shipped Clean starter holds",
		_look_order(ResourceLoader.load(POST_DIRECTORY + "clean.tres", "",
			ResourceLoader.CACHE_MODE_IGNORE)), ""])
	layer.free()
	return SUPPORT.pins(P, rows)


## NO FLASHING IS A CEILING, not a switch that turns the effects off. A player who asked for it still
## gets the rows - the pulse pulses, the look lands - held under an amplitude and over a time. The
## same two Engine meta the built-in accessibility rows write, so a game already carrying those needs
## nothing else.
static func _no_flashing_is_a_ceiling() -> bool:
	var flashing_was: Variant = Engine.get_meta("no_flashing", null)
	var strength_was: Variant = Engine.get_meta("effect_strength", null)
	var layer: Node = _a_layer()
	Engine.set_meta("no_flashing", false)
	Engine.set_meta("effect_strength", 1.0)
	layer.pulse_post_effect("vignette", 1.0, 0.0)
	var rows: Array = [
		["with nothing asked for, a full pulse is a full pulse", _on_screen(layer, "vignette"),
			"1.000"]
	]
	Engine.set_meta("no_flashing", true)
	layer.pulse_post_effect("vignette", 1.0, 0.0)
	rows.append(["a player who asked for no flashing gets the same row under the ceiling",
		_on_screen(layer, "vignette"), "%.3f" % layer.FLASH_CEILING])
	layer.set_post_strength("vignette", 1.0)
	rows.append(["and every other row goes through the same clamp",
		_on_screen(layer, "vignette"), "%.3f" % layer.FLASH_CEILING])
	rows.append(["a quick walk is slowed to the floor, because a small strobe is still a strobe",
		layer._slowed(0.05), layer.FLASH_FLOOR_SECONDS])
	rows.append(["while a slow one is left alone", layer._slowed(2.0), 2.0])
	Engine.set_meta("no_flashing", false)
	Engine.set_meta("effect_strength", 0.5)
	layer.set_post_strength("vignette", 1.0)
	rows.append(["the effect-strength dial scales every row too",
		_on_screen(layer, "vignette"), "0.500"])
	rows.append(["and leaves the time alone, because it is about how much, not how fast",
		layer._slowed(0.05), 0.05])
	layer.free()
	_put_meta_back("no_flashing", flashing_was)
	_put_meta_back("effect_strength", strength_was)
	return SUPPORT.pins(P, rows)


## THE DIALS HAVE ONE SAY, and the two colour-vision rows are exempt from both.
##
## An entry remembers what its ROW ASKED FOR and the dials are applied once, on the way to the
## shader. Get that wrong and the dial lands twice on anything that walks: a pulse falls back to
## strength times the dial instead of where it started, a fade arrives at target times the dial
## squared, and a look saved under a dial decays a little more every time it is saved and worn. None
## of it shows at a dial of 1, which is why this asks at 0.5.
##
## And a colour-vision correction is not an amplitude that can strobe - it is what makes the screen
## readable at all - so a player who has turned the effect strength to nothing, or asked for no
## flashing, still gets the colours told apart.
##
## WHICH OF THE TWO NUMBERS POST STRENGTH ANSWERS WITH is the other half of the same idea. It answers
## with the REQUEST - what the rows asked for - because that is the number a sheet's own arithmetic
## means: Set Post Strength to Post Strength + 0.1 has to walk up in tenths under any dial, and a row
## that read the dialled value back and wrote it in again would fold the dial in once more on every
## round trip until the effect was gone. So the two are asked separately here: the expression for what
## was asked, the shader's own dial for what the player is looking at.
static func _the_dials_have_one_say() -> bool:
	var flashing_was: Variant = Engine.get_meta("no_flashing", null)
	var strength_was: Variant = Engine.get_meta("effect_strength", null)
	Engine.set_meta("no_flashing", false)
	Engine.set_meta("effect_strength", 0.5)
	var layer: Node = _a_layer()
	layer.add_post_effect("vignette", "", 0.25)
	var rows: Array = [
		["a dial of a half puts a quarter-strength row on the screen at an eighth",
			_on_screen(layer, "vignette"), "0.125"]
	]
	layer.pulse_post_effect("vignette", 1.0, 0.4)
	rows.append(["and a pulse over it falls back to where it found it, not to that times the dial",
		_on_screen(layer, "vignette"), "0.125"])
	layer.fade_post_strength("vignette", 1.0, 0.5)
	rows.append(["a fade arrives at what it was asked for, through the dial exactly once",
		_on_screen(layer, "vignette"), "0.500"])
	layer.set_post_strength("vignette", 0.8)
	# THE ROUND TRIP a sheet writes by hand: read the strength, do arithmetic on it, write it back.
	# The expression answers with the request, so the number that comes back is the number that went
	# in, and the dial has its one say on the way to the shader.
	rows.append(["Post Strength answers with what the row asked for, whatever the dials are doing",
		layer.post_strength("vignette"), 0.8])
	rows.append(["while the shader is handed that through the dial, once",
		_on_screen(layer, "vignette"), "0.400"])
	layer.set_post_strength("vignette", layer.post_strength("vignette") + 0.1)
	rows.append(["so a row that adds a tenth to what it read adds a tenth",
		"%.3f" % layer.post_strength("vignette"), "0.900"])
	layer.set_post_strength("vignette", 0.8)
	var look_path: String = "user://tests/screen_post_stack_dialled.tres"
	layer.save_look(look_path, "Dialled")
	var written: Resource = ResourceLoader.load(look_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	rows.append(["a look records what the rows ASKED for, not what one player's dials allowed",
		_look_strengths(written), "0.8"])
	layer.use_look(written)
	rows.append(["so wearing it back is the same screen, and not a dimmer one every time",
		_on_screen(layer, "vignette"), "0.400"])
	Engine.set_meta("effect_strength", 0.0)
	Engine.set_meta("no_flashing", true)
	layer.correct_colours_for("deuteranopia")
	rows.append(["the colour-vision correction is exempt from both dials, because it is not an amplitude",
		_on_screen(layer, layer.CORRECT_EFFECT), "1.000"])
	layer.see_as("protanopia")
	rows.append(["and so is the simulation the designer walks the level with",
		_on_screen(layer, layer.SEE_AS_EFFECT), "1.000"])
	# Written again rather than only asked about: a dial has its say as an entry is applied, so what
	# an ordinary effect does under a dial of nothing is what the next row that touches it writes.
	layer.set_post_strength("vignette", 0.8)
	rows.append(["while everything else is still held at nothing by a dial of nothing",
		_on_screen(layer, "vignette"), "0.000"])
	rows.append(["and still answers with what that row asked for", layer.post_strength("vignette"),
		0.8])
	layer.free()
	_put_meta_back("no_flashing", flashing_was)
	_put_meta_back("effect_strength", strength_was)
	return SUPPORT.pins(P, rows)


## AN EFFECT'S OWN DIALS, which is the careful control one dropdown deeper than the quick form. A
## strength says how far an effect goes; these say what it IS - the vignette's colour, the letterbox's
## depth, and above all the colour grade's lookup image, without which that effect hands the screen
## straight back however far up its strength is.
static func _an_effects_own_dials() -> bool:
	var layer: Node = _a_layer()
	layer.add_post_effect("vignette", "", 0.5)
	var rows: Array = [
		["a dial nobody has set reads as nothing", layer.post_dial("vignette", "softness"), null]
	]
	layer.set_post_dial("vignette", "softness", 0.8)
	rows.append(["a row sets one of the effect's own dials",
		layer.post_dial("vignette", "softness"), 0.8])
	layer.set_post_dial("vignette", "vignette_color", Color.RED)
	rows.append(["and a dial that is a colour is a colour",
		layer.post_dial("vignette", "vignette_color"), Color.RED])
	layer.set_post_dial("vignette", "", 1.0)
	rows.append(["a dial with no name sets nothing rather than an entry called nothing",
		layer.post_dial("vignette", ""), null])
	rows.append(["and an entry that is not there answers with nothing",
		layer.post_dial("glitch", "band_height"), null])
	layer.add_post_effect("colour grade", "", 1.0)
	layer.set_post_dial("colour grade", "lut_size", 16)
	rows.append(["the grade's table size is a dial a row can set, which is what makes it draw at all",
		layer.post_dial("colour grade", "lut_size"), 16])
	layer.free()
	return SUPPORT.pins(P, rows)


## THE SHADERS ARE THE EFFECTS. An entry the pack cannot find a file for draws nothing and errors at
## nothing, so every word the pack offers is checked against a file that exists, compiles, and
## declares the one dial every row turns.
static func _every_effect_has_a_shader() -> bool:
	var layer: Node = _a_layer()
	var missing: PackedStringArray = PackedStringArray()
	var dialless: PackedStringArray = PackedStringArray()
	var words: PackedStringArray = layer.effect_words()
	for word: String in words:
		var path: String = POST_DIRECTORY + "post_" + word.replace(" ", "_") + ".gdshader"
		if not ResourceLoader.exists(path):
			missing.append(word)
			continue
		var shader: Shader = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Shader
		if shader == null or not _declares(shader, STRENGTH_DIAL):
			dialless.append(word)
	var rows: Array = [
		["every effect word the pack offers has a shader file", ",".join(missing), ""],
		["and every one of those declares the dial the rows turn", ",".join(dialless), ""],
		["the twelve looks plus the two the colour-vision rows wear", words.size(), 14],
		["the two vision shaders take the kind of vision as a dial of their own",
			"%s %s" % [_declares_in("post_see_as.gdshader", VISION_DIAL),
				_declares_in("post_correct_colours.gdshader", VISION_DIAL)], "true true"],
		["and the pack's first shader is still beside them, untouched",
			ResourceLoader.exists(POST_DIRECTORY + "screen_fx.gdshader"), true]
	]
	layer.free()
	return SUPPORT.pins(P, rows)


## THE QUIET FINDING: post effects cover the whole viewport, so a scene with its interface on a
## CanvasLayer has a question nobody answered - is the health bar graded along with the game? One
## row settles it for the whole stack, and until one does, this is the amber state on the row and the
## sentence in the inbox.
##
## The second fixture is the point of the check: a sheet that DOES say which side is said nothing
## about, and a check that could not stay quiet would be a check nobody leaves on.
static func _the_quiet_finding() -> bool:
	var unsaid: Array[Dictionary] = EventSheetEffectFindings.findings(
		GDScriptImporter.new().import_external("res://tests/fixtures/post_stack_hud.gd"))
	var settled: Array[Dictionary] = EventSheetEffectFindings.findings(
		GDScriptImporter.new().import_external("res://tests/fixtures/post_stack_hud_ordered.gd"))
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in unsaid:
		kinds.append(str(finding["kind"]))
	var rows: Array = [
		["two post rows in a scene with an interface layer are ONE finding, not two",
			",".join(kinds), EventSheetEffectFindings.KIND_POST_ORDER_UNSAID],
		["and a sheet that says which side is said nothing about", settled.size(), 0]
	]
	if not unsaid.is_empty():
		rows.append(["it names the layer the interface is on", str(unsaid[0]["subject"]), "Hud"])
		rows.append(["and names the row that settles it, both ways round",
			str(unsaid[0]["message"]).contains("Draw Post Effects Below Hud"), true])
		rows.append(["it is amber rather than red, because the game runs either way",
			str(unsaid[0]["severity"]), "warning"])
		rows.append(["and offers no fix door, because below and above are both right answers",
			str(unsaid[0]["fix"]), ""])
	rows.append(["the Doctor files it under its own check id",
		str(EventSheetEffectsDoctor.CHECK_FOR_KIND[EventSheetEffectFindings.KIND_POST_ORDER_UNSAID]),
		EventSheetEffectsDoctor.CHECK_POST_ORDER])
	rows.append(["it reads the interface layer straight off the scene",
		EventSheetEffectFindings.interface_layer_of("res://tests/fixtures/post_stack_hud.tscn"),
		"Hud"])
	rows.append(["and says nothing at all about a scene with no interface layer in it",
		EventSheetEffectFindings.interface_layer_of("res://tests/fixtures/blend_scene_glow.tscn"),
		""])
	# A COVER IS NOT AN INTERFACE. The effects layer this pack builds is a CanvasLayer holding one
	# ColorRect called Screen, and so is nearly every hand-rolled fade - so a heuristic that took the
	# first CanvasLayer with any Control under it advised the sheet to draw its post effects below its
	# own post effects. The interface is the layer with something a player reads or presses on it.
	rows.append(["a layer whose only Control is a full-screen rectangle is a cover, not an interface",
		EventSheetEffectFindings.interface_layer_of("res://tests/fixtures/post_stack_cover.tscn"),
		"Hud"])
	# And the sweep that decides which scripts are opened as sheets at all. Every word here is a
	# spelling a ROW writes - a member reached through, a call made, a write emitted - never a bare
	# class name, because a script that merely names the class in a comment or a type would match and
	# each match buys a whole sheet build in memory. Pinned as the list itself, since that is the
	# thing a later hand would widen.
	rows.append(["the effects sweep opens a script for spellings a row writes, not names it mentions",
		",".join(EventSheetEffectsDoctor.SHEET_WORDS),
		"set_shader_parameter,get_shader_parameter,global_shader_parameter,.blend_as(,"
		+ "material_override = ,is CanvasItemMaterial,as CanvasItemMaterial,post_effect(,"
		+ "post_effect_is_on(,post_effect_count(,post_effects_below(,post_effects_above(,"
		+ "use_look(,blend_to_look("])
	return SUPPORT.pins(P, rows)


## One Screen FX layer, built and never added to a tree - which is what a headless test has, and what
## the pack's own walks are written to answer for.
static func _a_layer() -> Node:
	return (load(SCREEN_FX_SCRIPT) as GDScript).new()


## One look resource with the rows given, for the half of the blend test that needs a look nobody
## saved. The rows arrive as an `Array[Dictionary]` because that is what the resource declares, and
## Godot's `set` on a typed property given an untyped array does NOTHING AT ALL - silently, with the
## property left holding its default. That is the trap this whole helper exists to keep in one place.
static func _a_look(called: String, rows: Array[Dictionary]) -> Resource:
	var made: Resource = (load(LOOK_SCRIPT) as GDScript).new()
	made.set("look_name", called)
	made.set("rows", rows)
	return made


## The stack's entries, in order, by the names rows address them with.
static func _order(layer: Node) -> String:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in layer._stack:
		names.append(str(entry.get("called", "")))
	return ",".join(names)


## WHAT THE PLAYER IS LOOKING AT, as opposed to what the rows asked for: the strength the entry's own
## rectangle is actually wearing, read off the ShaderMaterial the pack hands to the screen. That is
## the far side of the accessibility dials, and the only honest place to ask about them now that Post
## Strength answers with the request. Printed to three places because a dial applied to a float is
## not the float anyone would type, and a pin reading "0.4 is not 0.4" teaches nobody anything.
static func _on_screen(layer: Node, called: String) -> String:
	for entry: Dictionary in layer._stack:
		if str(entry.get("called", "")) != called:
			continue
		var rect: ColorRect = entry.get("rect", null) as ColorRect
		if rect == null or rect.material == null:
			return "no rectangle"
		return "%.3f" % float((rect.material as ShaderMaterial).get_shader_parameter(STRENGTH_DIAL))
	return "no entry"


## One entry's own dial, for the two the colour-vision rows write.
static func _dial(layer: Node, called: String, dial: String) -> Variant:
	for entry: Dictionary in layer._stack:
		if str(entry.get("called", "")) == called:
			return (entry.get("params", {}) as Dictionary).get(dial, null)
	return null


## A look file's rows, in order, by effect - what a reader would see in the Inspector.
static func _look_order(look: Resource) -> String:
	var names: PackedStringArray = PackedStringArray()
	if look == null:
		return ""
	for row: Variant in (look.get("rows") as Array):
		names.append(str((row as Dictionary).get("effect", "")))
	return ",".join(names)


## And the strengths it recorded, in the same order.
static func _look_strengths(look: Resource) -> String:
	var values: PackedStringArray = PackedStringArray()
	if look == null:
		return ""
	for row: Variant in (look.get("rows") as Array):
		values.append(str(float((row as Dictionary).get("strength", 0.0))))
	return ",".join(values)


## Whether a shader declares a uniform by that name.
static func _declares(shader: Shader, dial: String) -> bool:
	for declared: Dictionary in shader.get_shader_uniform_list():
		if str(declared.get("name", "")) == dial:
			return true
	return false


## The same question, of a file in the pack folder.
static func _declares_in(file_name: String, dial: String) -> bool:
	var shader: Shader = ResourceLoader.load(POST_DIRECTORY + file_name, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Shader
	return shader != null and _declares(shader, dial)


## Puts an Engine meta back the way this test found it - including "there was none", which is the
## state a fresh project is in and the one a leaked `false` would quietly replace.
static func _put_meta_back(key: String, was: Variant) -> void:
	if was == null:
		Engine.remove_meta(key)
	else:
		Engine.set_meta(key, was)


## THE LEDGER'S LAST LINE: neither accessibility meta is left standing when this file is done.
##
## `no_flashing` and `effect_strength` live on Engine, which is ONE object shared by every test in
## the process, so a `true` left behind here does not fail here - it halves or clamps every strength
## a later test reads and fails somewhere that has nothing to do with it. Each function above puts
## back exactly what it found; this asks whether that actually happened, and then sweeps, so a leak
## is a named failure rather than a mystery three tests later.
static func _no_meta_is_left_behind() -> bool:
	var standing: Array = [Engine.has_meta("no_flashing"), Engine.has_meta("effect_strength")]
	for key: String in ["no_flashing", "effect_strength"]:
		if Engine.has_meta(key):
			Engine.remove_meta(key)
	return SUPPORT.pins(P, [
		["no accessibility meta is left standing for the next test", standing, [false, false]]
	])
