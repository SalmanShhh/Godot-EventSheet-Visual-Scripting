# Pack builder - screen_fx (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Screen FX: the four full-screen effects on one rectangle, added to a scene once.
##
## A full-screen effect in Godot is a CanvasLayer holding a ColorRect whose shader reads
## `hint_screen_texture`. That is three nodes and a shader before a game gets its first flash of
## white, which is why most projects never get one. The pack ships the scene (screen_fx.tscn) and the
## shader; adding it to a scene is the whole setup, and the verbs read as what the player sees.
##
## COSTING NOTHING AT REST is a property, not a hope. A rectangle covering the viewport redraws every
## pixel of it through the shader every frame, so the pack hides the rectangle whenever every effect
## has finished, and shows it again the moment one starts. A hidden Control is not drawn at all.
##
## AND THEN THE POST STACK, which is the rest of what a screen wants: a named list of effects, each
## its own full-screen rectangle and shader, drawn in order. Nine shaders ship beside the first one -
## vignette, film grain, scanlines, pixelate, colour grade, dither, fisheye, glitch, letterbox - plus
## the two the colour-vision rows wear. A whole stack saves as ONE look file the project owns, and
## the only look shipped beside them is an empty one called Clean. The six verbs above are frozen and
## go on working exactly as they did, on their own rectangle, underneath the stack.
##
## The stack's code and every shader are REAL FILES in the pack's source folder, so they are
## highlighted, parse-checked on import and breakpointable; the builder assembles the code and copies
## the shaders the way any pack ships a companion file.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("screen_fx", "CanvasLayer", "ScreenFx",
		"Full-screen effects on one rectangle: a shockwave ring from a point in the world, a fade to a colour you can wait on, a blur, and a chromatic pulse. Add the pack's own scene to a scene once and the verbs are ordinary rows. The rectangle hides itself whenever every effect is idle, so a layer nobody is using costs nothing.",
		Lib.manifest().category("Screen FX").tags(PackedStringArray([
			"effects", "shader", "juice", "camera", "visual"])).expose_all_verbs_on_a_node())
	var sheet: EventSheetResource = src.sheet

	src.note("Screen FX: add screen_fx.tscn to your scene once (the pack does it for you when you add it to an object) and the four verbs are rows - Shockwave at a world point, Fade To a colour, Blur, Chromatic Pulse. Fade To is awaited, so the rows after it run when the fade lands: that is the scene transition. The rectangle turns itself off whenever nothing is running. On top of those sits the post stack: Add Post Effect and Pulse Post Effect wear one of nine shaders each on its own rectangle, in order, and a whole stack saves as one look file you own. This pack is an event sheet - extend it by editing it.")

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(_runtime_lines())
	sheet.events.append(block)

	src.block("stack")

	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"_rect = get_node_or_null(RECT_NAME) as ColorRect",
		"if _rect == null:",
		"\tpush_warning(\"Screen FX expects a ColorRect named %s under it - add the pack's own screen_fx.tscn rather than a bare CanvasLayer.\" % RECT_NAME)",
		"\treturn",
		"_screen = _rect.material as ShaderMaterial",
		"_seed_dials()",
		"# Whatever the scene was saved with, a layer starts at rest: nothing is running yet, so",
		"# nothing should be drawing.",
		"_rect.visible = false"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	if not Lib.publish(src, "res://eventsheet_addons/screen_fx/screen_fx"):
		return false
	# The shaders ARE the effects: an entry the pack cannot find a file for draws nothing, so a pack
	# folder without them is a pack that silently does nothing. They ship in the same build, along
	# with the empty Clean look - the ONE starter, and the only look this plugin ever names.
	return Lib.ship_files("screen_fx", "res://eventsheet_addons/screen_fx/screen_fx",
		PackedStringArray(["gdshader", "tres"]))


## The whole runtime: the rest state, the rectangle, the four verbs and the switch that keeps an
## unused layer free. Split out only so build() reads as the shape of the pack rather than as a wall.
##
## Every verb spells its own `@ace_codegen_template` with the `$ScreenFx.` in front, which most packs
## do not have to. A pack whose script hangs UNDER the node it acts on is addressed by node path
## automatically; this script IS the node, and a script that is the node is normally called on
## itself. Saying the path here is what turns each row back into "which layer" - the picker then
## offers it as an On node parameter, so a project with a layer per viewport still works.
static func _runtime_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray([
		"## The ColorRect the effects are drawn on, by the name the shipped scene gives it.",
		"const RECT_NAME: String = \"Screen\"",
		"",
		"## Every dial screen_fx.gdshader declares that can be RUNNING, with the value that means it is",
		"## not. A rectangle whose dials all read these draws the screen back exactly as it arrived,",
		"## which is the moment it is worth switching off. fade_color and shock_center are not here:",
		"## they say what an effect looks like rather than whether one is happening.",
		"const AT_REST: Dictionary = {\"blur\": 0.0, \"fade_amount\": 0.0, \"shock_strength\": 0.0, \"chromatic\": 0.0}",
		"",
		"## How long a shockwave ring takes to cross the screen. A ring is a moment rather than a state,",
		"## so it times itself instead of asking every row how long it should last.",
		"@export_range(0.05, 3.0, 0.05) var ring_seconds: float = 0.55",
		"",
		"var _rect: ColorRect = null",
		"var _screen: ShaderMaterial = null",
		"",
		"## The walks running right now, keyed by the dial they move, so a second call on the same dial",
		"## replaces the first rather than the two of them fighting over it.",
		"var _walks: Dictionary = {}",
		"",
		"## Sends out a ring from a point in the WORLD - a boss that has just died, an explosion, a",
		"## landing. The camera transform is applied, so the ring stays on the thing that caused it",
		"## however the camera is moving.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Shockwave\")",
		"## @ace_codegen_template(\"$ScreenFx.shockwave({at}, {strength})\")",
		"## @ace_display_template(\"Shockwave at [b]{at}[/b], strength [b]{strength}[/b]\")",
		"func shockwave(at: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:",
		"\tif _screen == null:",
		"\t\treturn",
		"\t_screen.set_shader_parameter(\"shock_center\", _screen_point(at))",
		"\t_screen.set_shader_parameter(\"shock_radius\", 0.0)",
		"\t_set_dial(\"shock_strength\", clampf(strength, 0.0, 1.0))",
		"\t# The ring travels and fades at once, which is why the two walks are parallel: a ring that",
		"\t# faded after it had arrived would sit at the edge of the screen for half its life.",
		"\tvar ring: Tween = _walk_dial(\"shock_radius\", 1.4, ring_seconds)",
		"\tif ring != null:",
		"\t\tring.set_parallel(true)",
		"\t\tring.tween_property(_screen, \"shader_parameter/shock_strength\", 0.0, ring_seconds)",
		"",
		"## Fades the whole screen to a colour and WAITS for it to land, so the rows under it are what",
		"## happens next: change the scene, show the credits, start the level. That is the scene",
		"## transition, spelled as two rows in one event.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Fade To\")",
		"## @ace_codegen_template(\"await $ScreenFx.fade_to({colour}, {seconds})\")",
		"## @ace_display_template(\"Fade to [b]{colour}[/b] over [b]{seconds}[/b] s\")",
		"func fade_to(colour: Color = Color.BLACK, seconds: float = 1.0) -> void:",
		"\tif _screen == null:",
		"\t\treturn",
		"\t_screen.set_shader_parameter(\"fade_color\", colour)",
		"\tvar walk: Tween = _walk_dial(\"fade_amount\", 1.0, maxf(seconds, 0.0))",
		"\tif walk != null:",
		"\t\tawait walk.finished",
		"",
		"## Fades the screen back from a colour to the game, and waits for that too - the other half of",
		"## a transition, run once the new scene is up.",
		"## @ace_action",
		"## @ace_name(\"Fade Back\")",
		"## @ace_codegen_template(\"await $ScreenFx.fade_back({colour}, {seconds})\")",
		"## @ace_display_template(\"Fade back from [b]{colour}[/b] over [b]{seconds}[/b] s\")",
		"func fade_back(colour: Color = Color.BLACK, seconds: float = 1.0) -> void:",
		"\tif _screen == null:",
		"\t\treturn",
		"\t_screen.set_shader_parameter(\"fade_color\", colour)",
		"\t_set_dial(\"fade_amount\", 1.0)",
		"\tvar walk: Tween = _walk_dial(\"fade_amount\", 0.0, maxf(seconds, 0.0))",
		"\tif walk != null:",
		"\t\tawait walk.finished",
		"",
		"## Blurs the whole screen over a time - the world going soft behind a pause menu, a knockout,",
		"## a dream. 0 is sharp again.",
		"## @ace_action",
		"## @ace_name(\"Blur\")",
		"## @ace_codegen_template(\"$ScreenFx.blur({amount}, {seconds})\")",
		"## @ace_display_template(\"Blur to [b]{amount}[/b] over [b]{seconds}[/b] s\")",
		"func blur(amount: float = 2.0, seconds: float = 0.3) -> void:",
		"\t_walk_dial(\"blur\", maxf(amount, 0.0), maxf(seconds, 0.0))",
		"",
		"## Pulls the colour channels apart and lets them snap back - the one-frame lens error that",
		"## reads as impact.",
		"## @ace_action",
		"## @ace_name(\"Chromatic Pulse\")",
		"## @ace_codegen_template(\"$ScreenFx.chromatic_pulse({strength}, {seconds})\")",
		"## @ace_display_template(\"Chromatic pulse at [b]{strength}[/b]\")",
		"func chromatic_pulse(strength: float = 0.6, seconds: float = 0.35) -> void:",
		"\t_set_dial(\"chromatic\", clampf(strength, 0.0, 1.0))",
		"\t_walk_dial(\"chromatic\", 0.0, maxf(seconds, 0.0))",
		"",
		"## Ends every effect at once and puts the screen back the way it was, which is the row a pause",
		"## menu closing or a scene change wants.",
		"## @ace_action",
		"## @ace_name(\"Clear Screen Effects\")",
		"## @ace_codegen_template(\"$ScreenFx.clear_screen_effects()\")",
		"func clear_screen_effects() -> void:",
		"\tfor dial: String in AT_REST:",
		"\t\t_set_dial(dial, float(AT_REST[dial]))",
		"",
		"## True while any effect is running - a fade held on, a blur, a ring still travelling.",
		"## @ace_condition",
		"## @ace_name(\"Screen Effect Is Running\")",
		"## @ace_codegen_template(\"$ScreenFx.screen_effect_is_running()\")",
		"func screen_effect_is_running() -> bool:",
		"\tif _screen == null:",
		"\t\treturn false",
		"\tfor dial: String in AT_REST:",
		"\t\tvar held: Variant = _screen.get_shader_parameter(dial)",
		"\t\tif held != null and absf(float(held) - float(AT_REST[dial])) > 0.001:",
		"\t\t\treturn true",
		"\treturn false",
		"",
		"## A world point as the shader wants it: 0 to 1 across the viewport. The canvas transform is",
		"## whatever the camera did, so the ring lands where the thing was on screen.",
		"func _screen_point(world: Vector2) -> Vector2:",
		"\tvar view: Viewport = get_viewport()",
		"\tif view == null:",
		"\t\treturn Vector2(0.5, 0.5)",
		"\tvar size: Vector2 = view.get_visible_rect().size",
		"\tif size.x <= 0.0 or size.y <= 0.0:",
		"\t\treturn Vector2(0.5, 0.5)",
		"\treturn (view.get_canvas_transform() * world) / size",
		"",
		"## Turns one dial straight away and wakes the rectangle if the dial says something is running.",
		"func _set_dial(dial: String, value: float) -> void:",
		"\tif _screen == null:",
		"\t\treturn",
		"\t_stop_walk(dial)",
		"\t_screen.set_shader_parameter(dial, value)",
		"\t_settle()",
		"",
		"## Walks one dial to a value over a number of seconds, hands the tween back, and re-checks the",
		"## rectangle when it lands. No time at all is a straight set rather than a tween nobody sees.",
		"func _walk_dial(dial: String, to_value: float, seconds: float) -> Tween:",
		"\tif _screen == null:",
		"\t\treturn null",
		"\t_stop_walk(dial)",
		"\tif seconds <= 0.0 or not is_inside_tree():",
		"\t\t_screen.set_shader_parameter(dial, to_value)",
		"\t\t_settle()",
		"\t\treturn null",
		"\tif _rect != null:",
		"\t\t_rect.visible = true",
		"\tvar walk: Tween = create_tween()",
		"\twalk.tween_property(_screen, \"shader_parameter/\" + dial, to_value, seconds)",
		"\twalk.finished.connect(_settle)",
		"\t_walks[dial] = walk",
		"\treturn walk",
		"",
		"## Ends the walk on one dial, if there is one, leaving the dial wherever it had got to.",
		"func _stop_walk(dial: String) -> void:",
		"\tvar walk: Tween = _walks.get(dial, null)",
		"\tif walk != null and walk.is_valid():",
		"\t\twalk.kill()",
		"\t_walks.erase(dial)",
		"",
		"## THE SWITCH. A rectangle covering the viewport redraws every pixel of it through the shader",
		"## every frame, so one left on with nothing to do is a whole screen of work for no change at",
		"## all. Asked after every change and at the end of every walk: running means visible, at rest",
		"## means hidden, and a hidden Control is not drawn.",
		"func _settle() -> void:",
		"\tif _rect != null:",
		"\t\t_rect.visible = screen_effect_is_running()",
		""
	])
	lines.append_array(Lib.seed_dials_lines("_screen"))
	return lines
