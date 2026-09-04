# Pack-builder shared library (no class_name: tool scripts stay out of the global namespace). save_pack
# compiles the in-memory sheet straight to a banner-less .gd - the .gd IS the pack (the editable event
# sheet AND the runtime script), with no .tres companion. audit_addons enforces no-drift: every shipped
# .gd must re-import and recompile to itself byte-for-byte.
@tool

# Lives WITH the shipped packs (eventsheet_addons/), not the editor addon (addons/eventsheet/), so a
# generated pack stays self-contained - removing the editor never dangles its @icon (clean_removal_test).
const BEHAVIOR_ICON := "res://eventsheet_addons/behavior.svg"

# Where save_pack writes. Empty (the only value the build tool ever uses) means the shipped path
# the builder asked for. A gate that wants to regenerate a pack WITHOUT touching the repository
# sets a temporary directory here, calls the builder's build(), reads the file back and clears this
# again - the pack is then produced by the real builder through the real pipeline, so a builder
# that no longer reproduces its shipped pack fails instead of hiding until someone rebuilds.
static var output_override_dir: String = ""


## The order the members are DECLARED in a builder is the order they are emitted in, so a
## builder's `sheet.variables` order is part of the shipped pack, not a private detail: change it
## and the pack's file, its head bars and any .tres saved against it all change with it.
static func save_pack(sheet: EventSheetResource, base_path: String, icon_path: String = BEHAVIOR_ICON) -> bool:
	# The whole pack pipeline (icon auto-detect, the four byte-gated de-coding lifts, stable
	# row uids, banner-less .gd-is-the-pack compile) lives on the PUBLIC API now -
	# EventSheets.publish_pack - so the bundled builders, the dock's Export Addon flow, and
	# third-party tooling all publish through one seam and can never drift apart. This wrapper
	# only adds the builder conveniences: the shared behaviour icon as the default fallback,
	# and the build-log line.
	# Every bundled pack ships versioned (builders may set their own; 1.0.0 is the floor) -
	# the Addon Pack banner chip shows it and future update tooling compares against it.
	if sheet.addon_version.strip_edges().is_empty():
		sheet.addon_version = "1.0.0"
	# The pack-local icon is resolved against the path the builder ASKED for, not the path the
	# bytes land on, so a redirected build still emits the shipped @icon line.
	if sheet.custom_class_icon.strip_edges().is_empty():
		var local_icon: String = base_path.get_base_dir() + "/icon.svg"
		if FileAccess.file_exists(local_icon):
			sheet.custom_class_icon = local_icon
	var write_path: String = base_path
	if not output_override_dir.is_empty():
		write_path = output_override_dir.path_join(base_path.get_file())
	var compile_result: Dictionary = EventSheets.publish_pack(sheet, write_path, icon_path)
	if not bool(compile_result.get("success", false)):
		push_error("Failed to compile %s.gd: %s" % [base_path, compile_result.get("errors")])
		return false
	print("[build_sample_behaviors] built %s (.gd), warnings: %s" % [base_path.get_file(), compile_result.get("warnings")])
	return true


## Shared shape for the spring/tween builders: one exposed-as-ACE function. The optional
## display_template is the authored row SENTENCE ("Heal [b]{amount}[/b] HP") - it round-trips
## as `## @ace_display_template(...)` and may carry BBCode-lite ([b]/[i]) for the event-sheet
## styled read; empty keeps the auto-derived "Name {param}" form (which the viewport already
## bolds automatically).
static func append_function(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, display_template: String = "") -> void:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	event_function.expose_as_ace = true
	event_function.ace_display_name = display_name
	event_function.ace_category = category
	event_function.description = description
	event_function.display_template = display_template
	for param_pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(param_pair[0])
		parameter.type_name = str(param_pair[1])
		event_function.params.append(parameter)
	var body_row: RawCodeRow = RawCodeRow.new()
	body_row.code = body
	event_function.events.append(body_row)
	sheet.functions.append(event_function)


## Declares a REQUIRED resource slot on a behavior pack - the data-driven-config helper. Adds an
## exported var (a Resource slot the user drags a .tres onto) marked `required`, so the Inspector shows a
## "required" warning on the field while it is empty - the "you forgot to attach it" safety net a
## beginner needs, with no boilerplate. (This is the plugin's own required-field marker, the same one the
## EnemyStats Custom Resource showcase uses for its portrait; it is the intended way to flag a missing
## reference in the Inspector, and it stays warning-free because the compiler owns the config-warnings
## hook.) The slot is typed Resource (generic) on purpose: a pack cannot reference another pack's class
## name at build time, and any resource - including your Custom Resource .tres - is a Resource.
## `display_name` seeds the tooltip; call it once per resource.
static func require_resource(sheet: EventSheetResource, var_name: String, display_name: String, description: String) -> void:
	sheet.variables[var_name] = {"type": "Resource", "default": null, "exported": true,
		"attributes": {"required": true, "tooltip": "%s. %s" % [display_name, description]}}


## _append_function, but returning the function for return-type tweaks.
static func exposed_function(function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	event_function.expose_as_ace = true
	event_function.ace_display_name = display_name
	event_function.ace_category = category
	event_function.description = description
	for param_pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(param_pair[0])
		parameter.type_name = str(param_pair[1])
		event_function.params.append(parameter)
	var body_row: RawCodeRow = RawCodeRow.new()
	body_row.code = body
	event_function.events.append(body_row)
	return event_function


## Appends a bool-returning exposed function - a Condition in the picker. (Same helper the
## currency_ledger builder grew locally; hoisted here so every data pack shares one shape.)
static func condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


## Sets authored display SENTENCES on named exposed verbs - the BBCode-styled row read
## ("Heal [b]{amount}[/b] HP": [b] bold around values, [i] italic around node params).
## Round-trips as `## @ace_display_template(...)`. Same name-addressing as feature_verbs;
## call it right beside it: Lib.verb_sentences(sheet, {"heal": "Heal [b]{amount}[/b] HP"}).
static func verb_sentences(sheet: EventSheetResource, sentences: Dictionary) -> void:
	var missing: Array = sentences.keys()
	for function_resource: Resource in sheet.functions:
		if function_resource is EventFunction and sentences.has((function_resource as EventFunction).function_name):
			(function_resource as EventFunction).display_template = str(sentences[(function_resource as EventFunction).function_name])
			missing.erase((function_resource as EventFunction).function_name)
	if not missing.is_empty():
		push_warning("verb_sentences: no function named %s on this sheet (typo?)" % str(missing))


## Marks the named exposed functions FEATURED - the pack's hero verbs, starred + bold at the
## top of their picker section. Call once at the end of a builder with the 1-3 verbs a new
## user should meet first: Lib.feature_verbs(sheet, ["take_damage", "heal"]).
static func feature_verbs(sheet: EventSheetResource, function_names: Array) -> void:
	var missing: Array = function_names.duplicate()
	for function_resource: Resource in sheet.functions:
		if function_resource is EventFunction and function_names.has((function_resource as EventFunction).function_name):
			(function_resource as EventFunction).featured = true
			missing.erase((function_resource as EventFunction).function_name)
	if not missing.is_empty():
		push_warning("feature_verbs: no function named %s on this sheet (typo?)" % str(missing))


## Appends a value-returning exposed function - an Expression - with the given return type
## (TYPE_FLOAT / TYPE_INT / TYPE_STRING / TYPE_BOOL / TYPE_ARRAY / TYPE_VECTOR2 ...).
static func number(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)


# ── Shared light-behaviour runtime ───────────────────────────────────────────────────────
# The two light behaviours (flicker, pulse) both have to answer the same question before they can
# touch anything: which property does THIS host spell brightness with. Godot spells it `energy` on a
# 2D light and `light_energy` on a 3D one, spells reach three more ways again, and neither light
# class is the other's parent - so a behaviour that works on any light has to ask its host rather
# than name a class. That question is one block, emitted verbatim by both packs, so a fix lands once.


## The binding block both light behaviours open with: the resolved brightness property, the helpers
## that fill it in, and the one line that writes a frame of the effect. Everything here is
## `_`-prefixed, so none of it publishes as vocabulary - it is the plumbing under the verbs that do.
##
## `reach_knob` names the pack's own "scale the reach too" export, for a pack that HAS one - the
## flicker does (`also_flicker_reach`), the pulse does not. A pack that names none gets no reach
## plumbing at all: two members it never fills and a branch it never runs are three things a reader
## of the shipped sheet has to work out are dead.
static func light_binding_lines(reach_knob: String = "") -> PackedStringArray:
	var scales_reach: bool = not reach_knob.strip_edges().is_empty()
	var lines: PackedStringArray = PackedStringArray([
		"## The property this host spells brightness with - `energy` on a 2D light, `light_energy` on",
		"## a 3D one. Resolved once when the behaviour starts, because a light answers to exactly one",
		"## of them and the answer cannot change while the game runs.",
		"var _brightness_property: String = \"\""
	])
	if scales_reach:
		lines.append_array(PackedStringArray([
			"## The property this host spells reach with, when it has one: a 2D point light scales a",
			"## texture, an omni light has a radius in metres, a spot light has its own. A directional",
			"## light reaches everywhere and has none, and then this stays empty.",
			"var _reach_property: String = \"\"",
			"## The reach the light was authored with. Reach is SCALED around this rather than",
			"## replaced, so a designer's own radius survives the effect - and a scale of 1 is the way",
			"## back to it, which is what the light settles on when the effect stops.",
			"var _authored_reach: float = 0.0"
		]))
	lines.append_array(PackedStringArray([
		"",
		"## The first of these properties the host really has. `in` on an object is the honest",
		"## question: it answers for a project's own subclass of a light exactly as it does for the",
		"## engine's classes, with no list of class names here to keep in step with the engine.",
		"func _first_property_of(candidates: PackedStringArray) -> String:",
		"\tfor candidate: String in candidates:",
		"\t\tif host != null and candidate in host:",
		"\t\t\treturn candidate",
		"\treturn \"\"",
		"",
		"## Binds to the parent light: finds the property it spells brightness with%s." % (
			", and remembers the reach it was authored with" if scales_reach else ""),
		"## False means the parent is not a light at all, which is the one setup mistake to warn about.",
		"func _bind_to_light() -> bool:",
		"\t_brightness_property = _first_property_of(PackedStringArray([\"energy\", \"light_energy\"]))"
	]))
	if scales_reach:
		lines.append_array(PackedStringArray([
			"\t_reach_property = _first_property_of(PackedStringArray([\"texture_scale\", \"omni_range\", \"spot_range\"]))",
			"\tif not _reach_property.is_empty():",
			"\t\t_authored_reach = float(host.get(_reach_property))"
		]))
	lines.append_array(PackedStringArray(["\treturn not _brightness_property.is_empty()", ""]))
	if not scales_reach:
		lines.append_array(PackedStringArray([
			"## Writes one frame of the effect. Brightness is all this pack moves.",
			"func _apply_light(brightness: float) -> void:",
			"\thost.set(_brightness_property, brightness)"
		]))
		return lines
	lines.append_array(PackedStringArray([
		"## Writes one frame of the effect: brightness always, and reach whenever %s asked for it." % reach_knob,
		"## The scale is around the reach the scene was AUTHORED with rather than around the current",
		"## one, so a scale of 1 is the way back - which is what a stopped effect settles on. Skipping",
		"## the write for a scale of 1 is how a torch put out mid-flicker kept the radius of the frame",
		"## it happened to die on.",
		"func _apply_light(brightness: float, reach_scale: float) -> void:",
		"\thost.set(_brightness_property, brightness)",
		"\tif %s and not _reach_property.is_empty():" % reach_knob,
		"\t\thost.set(_reach_property, _authored_reach * reach_scale)"
	]))
	return lines


# ── Shared shader-effect runtime ─────────────────────────────────────────────────────────
# The five node effect packs (hit flash, dissolve, outline, grayscale, wave) each ship one shader
# and turn its dials. Everything under the verbs is the same question in all five - which material
# am I allowed to write on, and how does one dial get from here to there over time - so it is one
# block emitted verbatim into each of them, and a fix lands once.


## The block every shader-effect pack opens with: the private-copy knob, the material it writes
## through, and the three helpers its verbs are made of. Everything here is `_`-prefixed apart from
## the knob, so none of it publishes as vocabulary.
##
## `pack_name` and `shader_file` are only spoken in the one warning a mis-set node produces, and
## naming them there is what makes that warning worth reading.
static func effect_material_lines(pack_name: String, shader_file: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray([
		"## Give this node its own copy of the material before anything turns a dial on it. A material",
		"## is a RESOURCE, so every node pointing at the same file SHARES it: turn a dial on one goblin",
		"## and every goblin wearing that file turns with it. On is the safe answer and the one you",
		"## almost always want. Off when a whole row of nodes really should react together, which is the",
		"## one case where sharing is the feature rather than the bug.",
		"@export var own_material: bool = true",
		"",
		"## The material this behaviour writes through, resolved on first use so the copy is taken once.",
		"var _worn: ShaderMaterial = null",
		"",
		"## The dial walks running right now, keyed by dial name, so a second call on the same dial",
		"## replaces the first instead of the two of them fighting over it.",
		"var _walks: Dictionary = {}",
		"",
		"## Whether the missing-material warning has been said. A setup mistake is worth saying once;",
		"## saying it per dial per call is a log nobody can read past to find it.",
		"var _warned: bool = false",
		"",
		"## The material to write on, copied on first use when own_material is on. Null means the parent",
		"## wears no ShaderMaterial at all: attaching the pack copies %s into the project and assigns it," % shader_file,
		"## so a null here means it was cleared afterwards.",
		"func _effect_material() -> ShaderMaterial:",
		"\tif _worn != null:",
		"\t\treturn _worn",
		"\tif host == null:",
		"\t\treturn null",
		"\tvar found: ShaderMaterial = host.material as ShaderMaterial",
		"\tif found == null:",
		"\t\tif not _warned:",
		"\t\t\t_warned = true",
		"\t\t\tpush_warning(\"%s needs its parent to wear the %s material. Add the pack again, or set the material in the Inspector.\")" % [pack_name, shader_file],
		"\t\treturn null",
		"\t_worn = found.duplicate() if own_material else found",
		"\thost.material = _worn",
		"\t_seed_dials()",
		"\treturn _worn",
		""
	])
	lines.append_array(seed_dials_lines("_worn"))
	lines.append_array(PackedStringArray([
		"",
		"## Turns one dial straight away, ending any walk that was moving it.",
		"func _set_dial(dial: String, value: Variant) -> void:",
		"\tvar used: ShaderMaterial = _effect_material()",
		"\tif used == null:",
		"\t\treturn",
		"\t_stop_walk(dial)",
		"\tused.set_shader_parameter(dial, value)",
		"",
		"## Walks one dial to a value over a number of seconds and hands the tween back, so a verb can",
		"## wait on it or hang something off its end. No time at all - or no scene tree to run a tween",
		"## in - is a straight set rather than a tween nobody can see. A walk replaces whatever walk was",
		"## already on that dial.",
		"func _walk_dial(dial: String, to_value: float, seconds: float) -> Tween:",
		"\tvar used: ShaderMaterial = _effect_material()",
		"\tif used == null:",
		"\t\treturn null",
		"\t_stop_walk(dial)",
		"\tif seconds <= 0.0 or not is_inside_tree():",
		"\t\tused.set_shader_parameter(dial, to_value)",
		"\t\treturn null",
		"\tvar walk: Tween = create_tween()",
		"\t# `shader_parameter/<name>` is how Godot addresses a uniform as a property, which is what lets",
		"\t# one tween move it with no per-frame code here at all.",
		"\twalk.tween_property(used, \"shader_parameter/\" + dial, to_value, seconds)",
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
		"## What a dial reads right now. An un-set uniform reads back as null rather than as the value",
		"## the shader declares for it, which is the fault every effect pack hits once, so the value the",
		"## caller knows the shader starts at is what an unwritten dial answers with.",
		"func _dial(dial: String, when_unset: float) -> float:",
		"\tvar used: ShaderMaterial = _worn",
		"\tif used == null and host != null:",
		"\t\tused = host.material as ShaderMaterial",
		"\tif used == null:",
		"\t\treturn when_unset",
		"\tvar held: Variant = used.get_shader_parameter(dial)",
		"\treturn when_unset if held == null else float(held)"
	]))
	return lines


## The one-time seeding block, for any pack that walks a dial on a material it holds in `member`.
##
## Godot answers get_shader_parameter with NULL for a uniform nothing has written yet - not with the
## value the file declares - so `shader_parameter/<dial>` is not a property a tween can even address
## until something has written it once. The engine knows the declared value and is asked for it here.
## This is the fault every effect pack hits exactly once, which is why it is one block rather than
## six: the five node packs seed on the first write, and the screen layer seeds when it starts.
static func seed_dials_lines(member: String) -> PackedStringArray:
	return PackedStringArray([
		"## Writes every dial the shader declares, once, before anything reads or walks one. An un-set",
		"## uniform reads back as null rather than as the shader's own value, and a tween cannot even",
		"## address `shader_parameter/<dial>` until it has been written.",
		"func _seed_dials() -> void:",
		"\tif %s == null or %s.shader == null:" % [member, member],
		"\t\treturn",
		"\tfor declared: Dictionary in %s.shader.get_shader_uniform_list():" % member,
		"\t\tvar dial: String = str(declared.get(\"name\", \"\"))",
		"\t\tif dial.is_empty() or %s.get_shader_parameter(dial) != null:" % member,
		"\t\t\tcontinue",
		"\t\tvar starts_at: Variant = RenderingServer.shader_get_parameter_default(",
		"\t\t\t%s.shader.get_rid(), dial)" % member,
		"\t\t# A renderer that draws nothing - a headless run, a dedicated server - knows no shader",
		"\t\t# defaults and answers null. The declared TYPE is still known, so an empty one of that is",
		"\t\t# written instead: the dial is addressable, and its value is never seen because nothing",
		"\t\t# is being drawn.",
		"\t\tif starts_at == null:",
		"\t\t\tstarts_at = type_convert(starts_at, int(declared.get(\"type\", TYPE_NIL)))",
		"\t\t%s.set_shader_parameter(dial, starts_at)" % member
	])


# ── Shared Juice runtime blocks ──────────────────────────────────────────────────────────
# The screen-FX overlay (bundled shader + build/visibility helpers) is identical in the 2D and 3D
# Juice packs; single-sourcing it here means a fix (or the un-set-uniform-null crash fix) lands ONCE
# and both packs regenerate from it. Emission stays byte-identical, so the drift audit still passes.


## The full-screen FX overlay block: one shader with four dials (vignette / chromatic aberration /
## the chromatic shake's directional split / radial speed lines), built on first use and hidden when
## every dial is 0. Both Juice packs append this verbatim as their fx overlay block. The paired verbs
## (Pulse Vignette / Chromatic Kick / Chromatic Shake / Set Speed Lines) are per-pack (their help text
## differs) but share the same bodies below.
static func juice_fx_overlay_lines() -> PackedStringArray:
	return PackedStringArray([
		"# The screen-FX overlay: one full-screen shader with three dials (vignette, chromatic",
		"# aberration, radial speed lines) built on first use, hidden whenever every dial is 0.",
		"var _fx_layer: CanvasLayer = null",
		"var _fx_rect: ColorRect = null",
		"var _fx_material: ShaderMaterial = null",
		"var _vignette_tween: Tween = null",
		"var _chroma_tween: Tween = null",
		"const _FX_SHADER: String = \"\"\"",
		"shader_type canvas_item;",
		"uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap;",
		"uniform float vignette_strength = 0.0;",
		"uniform vec4 vignette_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);",
		"uniform float chroma_strength = 0.0;",
		"uniform vec2 chroma_shift = vec2(0.0, 0.0);",
		"uniform float chroma_intensity = 0.0;",
		"uniform float speed_lines = 0.0;",
		"",
		"void fragment() {",
		"\tvec2 uv = SCREEN_UV;",
		"\tvec2 centered = uv - vec2(0.5);",
		"\tvec2 chroma_offset = centered * chroma_strength * 0.03;",
		"\tvec3 col = vec3(",
		"\t\ttexture(screen_texture, uv + chroma_offset).r,",
		"\t\ttexture(screen_texture, uv).g,",
		"\t\ttexture(screen_texture, uv - chroma_offset).b);",
		"\t// The SHAKE's split, on top of the kick's: the kick pulls the channels apart outwards from",
		"\t// the middle, while this slides the whole screen's channels along one direction that moves.",
		"\t// Red leads, green trails the other way, blue overshoots four times as far, and a fourth,",
		"\t// nearer tap ghosts behind the three - the smear that reads as impact rather than as a lens.",
		"\t// Behind a gate, because those are FOUR more reads of the screen per pixel and the overlay",
		"\t// is also on screen for a vignette or for speed lines, with no shake anywhere near it.",
		"\tif (chroma_intensity > 0.0) {",
		"\t\tvec3 shaken = vec3(",
		"\t\t\ttexture(screen_texture, uv + chroma_shift).r,",
		"\t\t\ttexture(screen_texture, uv - chroma_shift).g,",
		"\t\t\ttexture(screen_texture, uv + chroma_shift * 4.0).b);",
		"\t\tshaken = mix(shaken, texture(screen_texture, uv + chroma_shift * 1.25).rgb, 0.25);",
		"\t\tcol = mix(col, shaken, clamp(chroma_intensity, 0.0, 1.0));",
		"\t}",
		"\tfloat vignette = smoothstep(0.35, 1.0, length(centered) * 1.5) * vignette_strength;",
		"\tcol = mix(col, vignette_color.rgb, clamp(vignette, 0.0, 1.0));",
		"\tfloat angle = atan(centered.y, centered.x);",
		"\tfloat streak = step(0.86, fract(sin(floor(angle * 60.0) + floor(TIME * 24.0) * 7.0) * 43758.545));",
		"\tfloat ring = smoothstep(0.2, 0.65, length(centered));",
		"\tcol = mix(col, vec3(1.0), streak * ring * clamp(speed_lines, 0.0, 1.0) * 0.65);",
		"\tCOLOR = vec4(col, 1.0);",
		"}",
		"\"\"\"",
		"",
		"## @ace_hidden",
		"func _ensure_fx_overlay() -> void:",
		"\tif _fx_layer != null or not is_inside_tree():",
		"\t\treturn",
		"\t_fx_layer = CanvasLayer.new()",
		"\t_fx_layer.layer = 91",
		"\tadd_child(_fx_layer)",
		"\t_fx_rect = ColorRect.new()",
		"\t_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"\t_fx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
		"\tvar fx_shader: Shader = Shader.new()",
		"\tfx_shader.code = _FX_SHADER",
		"\t_fx_material = ShaderMaterial.new()",
		"\t_fx_material.shader = fx_shader",
		"\t# Seed every uniform so get_shader_parameter never returns null: reading an un-set uniform",
		"\t# returns null (NOT the shader default), and _fx_update_visibility's float() would fault on it",
		"\t# whenever only one of the effects had been used.",
		"\t_fx_material.set_shader_parameter(\"vignette_strength\", 0.0)",
		"\t_fx_material.set_shader_parameter(\"chroma_strength\", 0.0)",
		"\t_fx_material.set_shader_parameter(\"chroma_shift\", Vector2.ZERO)",
		"\t_fx_material.set_shader_parameter(\"chroma_intensity\", 0.0)",
		"\t_fx_material.set_shader_parameter(\"speed_lines\", 0.0)",
		"\t_fx_rect.material = _fx_material",
		"\t_fx_rect.visible = false",
		"\t_fx_layer.add_child(_fx_rect)",
		"",
		"## @ace_hidden",
		"func _fx_update_visibility() -> void:",
		"\tif _fx_rect == null or _fx_material == null:",
		"\t\treturn",
		"\t_fx_rect.visible = float(_fx_material.get_shader_parameter(\"vignette_strength\")) > 0.001 \\",
		"\t\t\tor float(_fx_material.get_shader_parameter(\"chroma_strength\")) > 0.001 \\",
		"\t\t\tor float(_fx_material.get_shader_parameter(\"chroma_intensity\")) > 0.001 \\",
		"\t\t\tor float(_fx_material.get_shader_parameter(\"speed_lines\")) > 0.001"
	])


## The CHROMATIC SHAKE block: the state a running shake keeps, the four questions it answers each
## frame (how far through it is, which way the split points, how big it is right now, is the player
## asking for no flashing), the tick step, and the condition + expression a sheet reads it with.
## Both Juice packs append this verbatim beside their fx overlay block, so the shake behaves the
## same over a 2D camera and over a 3D one.
##
## It is the camera Shake's twin, on the screen instead of the lens: an amount in pixels that either
## falls to nothing over a duration or holds flat and then stops dead, pointed by the SAME noise the
## camera shake wobbles with (so the two read as one hit), and advanced by delta - which the engine
## has already scaled by time, so slow motion glides the split and a hitstop freezes it mid-frame.
## The radial Chromatic Kick's own dial is untouched: the two draw on top of each other.
static func juice_chroma_shake_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Chromatic shake: a directional channel split that moves while it lasts ---",
		"",
		"## How much of the peak a fixed-angle shake can lose to the wander. A shake told which way to",
		"## point keeps that direction, so the noise lands on the AMOUNT instead and the split breathes",
		"## along one line rather than swinging around the screen.",
		"const CHROMA_SHAKE_WANDER: float = 0.35",
		"",
		"## The Engine meta the whole project keeps the no-flashing answer in - the one the built-in Set",
		"## No Flashing row writes. A game carrying that row needs nothing else: the split comes out half",
		"## as wide and wanders half as fast, which is the same shake without the strobe.",
		"const CHROMA_SHAKE_NO_FLASHING_META: StringName = &\"no_flashing\"",
		"",
		"# The magnitude the screen is showing right now, in pixels - what the expression answers with.",
		"var _chroma_shake_magnitude: float = 0.0",
		"# The magnitude the gesture was fired at, before falloff, wander and the no-flashing halving.",
		"var _chroma_shake_from: float = 0.0",
		"var _chroma_shake_duration: float = 0.3",
		"var _chroma_shake_elapsed: float = 0.0",
		"# True for the \"constant\" mode: hold the amount flat for the duration, then stop dead.",
		"var _chroma_shake_hold: bool = false",
		"# The direction in degrees, or below zero for a direction that wanders with the noise.",
		"var _chroma_shake_angle: float = -1.0",
		"# The noise clock, advanced by delta so the wander rides the game's own time - and advanced",
		"# ALREADY SCALED BY THE RATE, which is what lets the rate change mid-shake. Keeping a raw clock",
		"# and multiplying the whole of it by the rate at sampling time would move every past frame's",
		"# sample too, so turning no flashing on would teleport the split to an unrelated direction in",
		"# that one frame: a strobe delivered by the setting that exists to prevent strobing.",
		"var _chroma_shake_phase: float = 0.0",
		"var _chroma_shake_active: bool = false",
		"",
		"## Whether this player has asked for no flashing.",
		"## @ace_hidden",
		"func _chroma_shake_quiet() -> bool:",
		"\treturn bool(Engine.get_meta(CHROMA_SHAKE_NO_FLASHING_META, false))",
		"",
		"## How fast the split's direction wanders: the same knob the camera shake scrolls its noise at,",
		"## halved while no flashing is on.",
		"## @ace_hidden",
		"func _chroma_shake_rate() -> float:",
		"\treturn shake_frequency * (0.5 if _chroma_shake_quiet() else 1.0)",
		"",
		"## One sample of the shared noise at the shake's own clock - what makes the split move.",
		"## @ace_hidden",
		"func _chroma_shake_wander() -> float:",
		"\tif _noise == null:",
		"\t\treturn 0.0",
		"\treturn _noise.get_noise_2d(_chroma_shake_phase, 0.0)",
		"",
		"## How much of the shake is left: all of it while a constant one holds, and a straight line down",
		"## to nothing while a reducing one runs.",
		"## @ace_hidden",
		"func _chroma_shake_fade() -> float:",
		"\tif not _chroma_shake_active:",
		"\t\treturn 0.0",
		"\tif _chroma_shake_hold:",
		"\t\treturn 1.0",
		"\treturn clampf(1.0 - _chroma_shake_elapsed / maxf(_chroma_shake_duration, 0.0001), 0.0, 1.0)",
		"",
		"## Which way the split points this frame: the angle it was told, or the shared noise walking it",
		"## around. Without a seeded noise (a shake fired before _ready) it points right rather than",
		"## nowhere, so the effect is still visible.",
		"##",
		"## It is a UNIT direction whichever way it came, because the magnitude beside it is the whole",
		"## promise: 12 pixels asked for is 12 pixels wide on screen, and the expression that answers 12",
		"## is answering about the same split. The noise therefore picks the ANGLE - one full turn per",
		"## unit of noise - rather than the vector. Reading a PAIR of samples as the vector instead would",
		"## hand back a direction shorter than one almost always, and nothing at all in the frames where",
		"## both samples crossed zero together, so the split would quietly be a fraction of what the row",
		"## and the expression both said it was.",
		"## @ace_hidden",
		"func _chroma_shake_direction() -> Vector2:",
		"\tif _chroma_shake_angle >= 0.0:",
		"\t\treturn Vector2.from_angle(deg_to_rad(_chroma_shake_angle))",
		"\tif _noise == null:",
		"\t\treturn Vector2.RIGHT",
		"\treturn Vector2.from_angle(_chroma_shake_wander() * TAU)",
		"",
		"## The magnitude the screen shows this frame, in pixels: what was asked for, less the falloff",
		"## spent, less the wander a fixed angle leaves on the amount, halved while no flashing is on.",
		"## @ace_hidden",
		"func _chroma_shake_amount() -> float:",
		"\tvar amount: float = _chroma_shake_from * _chroma_shake_fade()",
		"\tif _chroma_shake_angle >= 0.0:",
		"\t\tamount *= 1.0 - CHROMA_SHAKE_WANDER * absf(_chroma_shake_wander())",
		"\tif _chroma_shake_quiet():",
		"\t\tamount *= 0.5",
		"\treturn amount",
		"",
		"## Writes this frame of the shake onto the overlay shader. The shift is in pixels here and in",
		"## screen fractions there, so it is divided by the viewport - a 12-pixel split is 12 pixels wide",
		"## on every resolution. The magnitude is kept whether or not there is a shader to write to, so",
		"## the expression answers off-tree (and headless) exactly as it does on screen.",
		"## @ace_hidden",
		"func _chroma_shake_write() -> void:",
		"\t_chroma_shake_magnitude = _chroma_shake_amount()",
		"\tif _fx_material == null:",
		"\t\treturn",
		"\tvar span: Vector2 = Vector2(1.0, 1.0)",
		"\tvar vp: Viewport = get_viewport()",
		"\tif vp != null:",
		"\t\tspan = vp.get_visible_rect().size",
		"\tspan = Vector2(maxf(span.x, 1.0), maxf(span.y, 1.0))",
		"\t# The same global dial the camera effects are scaled by, so a player who turned the shake",
		"\t# down turned this down with it.",
		"\tvar effect_strength: float = float(Engine.get_meta(\"effect_strength\", 1.0))",
		"\tvar shift: Vector2 = _chroma_shake_direction() * _chroma_shake_magnitude * effect_strength",
		"\t_fx_material.set_shader_parameter(\"chroma_shift\", shift / span)",
		"\t# The falloff is spent ONCE, and it is spent on the shift above. This dial is how far the",
		"\t# shaken taps are mixed in at all, so writing the fade here as well would square the curve:",
		"\t# a reducing shake would be a quarter of itself half way through while the row, the docs and",
		"\t# the expression all promised half. It is a GATE - on while a shake runs, and put back to 0",
		"\t# by Stop Chromatic Shake - which is also what the overlay's visibility check reads it as.",
		"\t_fx_material.set_shader_parameter(\"chroma_intensity\", 1.0)",
		"",
		"## One frame of the shake. The clock is advanced by DELTA, which the engine has already scaled",
		"## by time: slow motion glides the split, a hitstop freezes it mid-frame, and the duration",
		"## stretches with them - the shake belongs to the game's time, not the wall clock. The noise",
		"## clock takes the wander rate on the way in, so a rate that changes mid-shake bends the walk",
		"## from here on rather than moving where the whole walk so far was read from.",
		"## @ace_hidden",
		"func _chroma_shake_step(delta: float) -> void:",
		"\tif not _chroma_shake_active:",
		"\t\treturn",
		"\t_chroma_shake_phase += delta * _chroma_shake_rate()",
		"\t_chroma_shake_elapsed += delta",
		"\tif _chroma_shake_elapsed >= _chroma_shake_duration:",
		"\t\t# A reducing shake has reached nothing and a constant one has held long enough: both end",
		"\t\t# here, the overlay is put back to clean, and the tick parks itself on the next pass.",
		"\t\tstop_chromatic_shake()",
		"\t\treturn",
		"\t_chroma_shake_write()",
		"",
		"## Whether a chromatic shake is running right now - true from the row that fires it until the",
		"## duration is up or Stop Chromatic Shake takes it off.",
		"## @ace_condition",
		"## @ace_name(\"Is Chromatic Shaking\")",
		"func is_chromatic_shaking() -> bool:",
		"\treturn _chroma_shake_active",
		"",
		"## How wide the split is right now, in pixels: the magnitude after the falloff, the wander and",
		"## the no-flashing halving. Zero when nothing is shaking. Drive a rumble or a HUD wobble from it",
		"## and the whole hit reads as one thing.",
		"## @ace_expression",
		"## @ace_name(\"Chromatic Shake Magnitude\")",
		"func chromatic_shake_magnitude() -> float:",
		"\treturn _chroma_shake_magnitude"
	])


# Shared verb BODIES (the help text stays per-pack; the runtime code is one source). A fix to any of
# these lands once for both Juice packs.
const JUICE_PULSE_VIGNETTE_BODY := "_ensure_fx_overlay()\nif _fx_material == null:\n\treturn\nif _vignette_tween != null and _vignette_tween.is_valid():\n\t_vignette_tween.kill()\n_fx_material.set_shader_parameter(\"vignette_color\", Color(color.r, color.g, color.b, 1.0))\n_fx_material.set_shader_parameter(\"vignette_strength\", clampf(strength, 0.0, 1.0))\n_fx_rect.visible = true\nvar tw: Tween = create_tween()\ntw.tween_property(_fx_material, \"shader_parameter/vignette_strength\", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)\ntw.finished.connect(_fx_update_visibility)\n_vignette_tween = tw"

const JUICE_CHROMATIC_KICK_BODY := "_ensure_fx_overlay()\nif _fx_material == null:\n\treturn\nif _chroma_tween != null and _chroma_tween.is_valid():\n\t_chroma_tween.kill()\n_fx_material.set_shader_parameter(\"chroma_strength\", clampf(strength, 0.0, 1.0))\n_fx_rect.visible = true\nvar tw: Tween = create_tween()\ntw.tween_property(_fx_material, \"shader_parameter/chroma_strength\", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)\ntw.finished.connect(_fx_update_visibility)\n_chroma_tween = tw"

const JUICE_CHROMATIC_SHAKE_BODY := "_ensure_fx_overlay()\n_chroma_shake_from = maxf(magnitude, 0.0)\n_chroma_shake_duration = maxf(duration, 0.01)\n_chroma_shake_hold = mode == \"constant\"\n_chroma_shake_angle = angle_degrees\n# Firing again RESTARTS the shake rather than stacking a second one on it: the same split, from\n# the top. The noise clock deliberately keeps running, so a second hit carries the wander on\n# instead of snapping the split back to where the first one started.\n_chroma_shake_elapsed = 0.0\n_chroma_shake_active = true\nif _fx_rect != null:\n\t_fx_rect.visible = true\n_chroma_shake_write()\nset_process(true)"

const JUICE_STOP_CHROMATIC_SHAKE_BODY := "_chroma_shake_active = false\n_chroma_shake_elapsed = 0.0\n_chroma_shake_magnitude = 0.0\nif _fx_material == null:\n\treturn\n_fx_material.set_shader_parameter(\"chroma_shift\", Vector2.ZERO)\n_fx_material.set_shader_parameter(\"chroma_intensity\", 0.0)\n# Hands the overlay back: it hides itself unless a vignette, a kick or speed lines are still on it.\n_fx_update_visibility()"

## The chromatic shake's frame, as its own tick row. It runs BEFORE the camera mixer in both packs
## because the mixer can return early when there is no camera, and the split is drawn on the screen
## rather than through a lens - it must go on shaking in a scene that has no camera at all.
const JUICE_CHROMA_SHAKE_TICK_BODY := "_chroma_shake_step(delta)"

const JUICE_SET_SPEED_LINES_BODY := "_ensure_fx_overlay()\nif _fx_material == null:\n\treturn\n_fx_material.set_shader_parameter(\"speed_lines\", clampf(intensity, 0.0, 1.0))\n_fx_update_visibility()"

const JUICE_PLAY_SOUND_VARIED_BODY := "_spawn_one_shot(path, 1.0 + randf_range(-pitch_jitter, pitch_jitter), randf_range(-absf(volume_jitter_db), 0.0))"

const JUICE_PLAY_SOUND_INTENSITY_BODY := "var power: float = clampf(intensity, 0.0, 1.0)\n_spawn_one_shot(path, lerpf(0.85, 1.15, power) * (1.0 + randf_range(-0.03, 0.03)), lerpf(-14.0, 0.0, power))"

const JUICE_COUNT_TO_BODY := "var from: float = float(_tickers.get(ticker_name, 0.0))\n_ticker_targets[ticker_name] = target\nvar old_tween: Tween = _ticker_tweens.get(ticker_name, null)\nif old_tween != null and is_instance_valid(old_tween):\n\told_tween.kill()\nvar tw: Tween = create_tween()\ntw.tween_method(func(v: float) -> void: _tickers[ticker_name] = v, from, target, maxf(duration, 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)\ntw.finished.connect(_finish_ticker.bind(ticker_name))\n_ticker_tweens[ticker_name] = tw"

const JUICE_SET_TICKER_BODY := "var old_tween: Tween = _ticker_tweens.get(ticker_name, null)\nif old_tween != null and is_instance_valid(old_tween):\n\told_tween.kill()\n_tickers[ticker_name] = value\n_ticker_targets[ticker_name] = value"


# ── Why a 2D pack and its 3D twin are two builders ───────────────────────────────────────
# Nine packs ship as a 2D/3D pair (bullet, juice, line_of_sight, move_to, orbit, pin, sine,
# skateboard, traversal_kit). They read like one source and a substitution table away from each
# other, and they are not. Measured over all nine, with Vector2/Node2D/Area2D and the rest of the
# mechanical spellings normalised away first:
#   - 61% of the 3D builders' LINES have a match in their 2D twin, but only 3% of those lines sit
#     in a block that matches WHOLE. An override can only replace a whole piece, so the block is
#     the unit that counts, and 97% of every 3D builder would be override.
#   - 803 of the 1,097 differing lines are CODE, not wording. The 3D twin aims along -Z instead of
#     a rotation angle, carries a third axis, and exposes different verbs: bullet 3D has Launch
#     Forward and an editor preview, bullet 2D has acceleration, an angle of motion and an enable
#     verb, and neither pack has the other's.
#   - move_to is authored entirely as ACE rows under the zero-RawCode budget the suite pins;
#     move_to_3d is not. That pair does not even share an authoring style.
# What the two DO emit identically was already lifted out, in the sections above: the
# light-brightness question, the five shader effects, and the Juice overlay with its verb bodies.
# What is left in each pair is the part that genuinely differs, so a transposition engine plus a
# per-pack override file would buy nothing. Costed on the closest pair, line_of_sight, where 86%
# of lines match: its 3D builder falls from 92 lines to about 38, its 2D builder gains a seam, and
# the engine costs 60 or more - a NET GAIN of lines, on the best pair in the set. Single-source a
# block the two packs emit identically, the way the sections above do. Do not derive the pair.


# ── Pack source folders: the behaviour code as REAL GDScript ─────────────────────────────
# A pack's behaviour code used to be authored as quoted, backslash-escaped string literals inside
# its builder: no syntax highlighting, no parse checking, no breakpoints, and an escaped quote
# between the author and every line they wrote. The code now lives in real `.gd` files under
# `tools/pack_builders/src/<pack>/`, and a builder names the pieces it wants instead of quoting
# them.
#
# THE RULES OF A SOURCE FILE, in full. There are two kinds of piece, and both are ordinary GDScript:
#   - `#region <name>` ... `#endregion` around TOP-LEVEL code marks one piece: the exports, signals
#     and helpers a pack emits verbatim. The piece is the lines between the markers, with the
#     opening marker's own indentation removed from each of them.
#   - A top-level `func <name>(...):` that is not inside a region is a piece too: its BODY, dedented
#     by one tab, named after the function. That is how a statement body - an event body, a verb
#     body - stays real GDScript, with a signature the editor resolves its parameters against,
#     rather than a quoted fragment nothing can check. Trailing blank lines are trimmed, so a piece
#     ends where its code ends.
#   - Everything else outside a region is scaffolding: the `extends`, and the members the pack
#     declares for itself at build time (its host, its Inspector variables). Scaffolding is what
#     lets the editor check the file; it never reaches the pack. A `static func` is scaffolding
#     too - only a plain `func` at column 0 opens a piece - so a helper the pack is meant to emit
#     goes in a region, not in a static.
#   - A FUNC PIECE ENDS AT THE FIRST LINE THAT IS NOT BLANK AND NOT INDENTED, which is how the
#     body knows where it stops - and which means a `#` comment written at COLUMN 0 inside a body
#     ends the piece there, with the rest of that body becoming scaffolding nobody emits. Comment
#     a body's lines at the body's own indentation. The same rule makes a space-indented line
#     (rather than a tab-indented one) end a piece, which is one more reason this tree is tabs.
#   - Piece names are unique across the whole folder. A folder may hold several files (one per part
#     of a large pack); they are read in sorted order, so a build is deterministic.
#   - Regions may NOT nest.
#
# The pieces are assembled by the same makers a builder always used and published through the same
# save_pack, so a converted builder emits byte-identical bytes - which is what the pack drift gate
# (tools/audit_addons.gd) checks on every build.
const SOURCE_ROOT := "res://tools/pack_builders/src"

# Everything wrong with the folder the last `_read_pieces` walked, in the order it was found: a
# folder that is not there, a file that could not be read, a duplicate piece name, a region nobody
# closed. Reset by that call and carried onto the PackSource it opened, so a build FAILS on it
# rather than printing an error and writing the pack anyway.
static var _read_problems: PackedStringArray = PackedStringArray()


# One problem with a source folder: pushed as an engine error so it is visible where errors are, and
# kept so the build's exit code can be made of it.
static func _source_problem(message: String) -> void:
	push_error(message)
	_read_problems.append(message)



## Everything about a pack that its source folder cannot carry: the facts the SHEET holds rather
## than the code does. One typed field per fact and one setter per fact, because the shape this
## replaced was a dictionary of magic strings - `{"behaviour": true}` built a pack that was not a
## behavior, silently and with no error, because nothing rejected a key nobody knew.
##
## Every setter returns the manifest, so a pack declares itself in one expression:
##
##   Lib.manifest().behavior().category("Wrap").tags(["movement", "screen"])
##
## A pack that declares none of this passes no manifest at all.
class PackManifest extends RefCounted:

	## A behavior pack: it attaches to a host and gets its `_enter_tree`.
	var is_behavior: bool = false

	## The autoload name, for a pack that ships as one. Non-empty also turns autoload_mode on.
	var autoload_name: String = ""

	## The pack's own category in the Add Behavior list.
	var addon_category: String = ""

	## The picker category new verbs default to. Empty means the Add Behavior category.
	var picker_category: String = ""

	## The pack's search tags.
	var search_tags: PackedStringArray = PackedStringArray()

	## The pack's own version. 1.0.0 is the floor; empty leaves the sheet's default.
	var addon_version: String = ""

	## The Inspector variables, in DECLARATION ORDER - which is emission order, so it is part of
	## the shipped pack rather than a private detail.
	var inspector_variables: Dictionary = {}

	## How the pack exposes its verbs wholesale, set by `expose_all_verbs`/`_on_a_node` rather
	## than by writing the mode's own spelling at a call site.
	var expose_all_mode: String = ""

	## Declares a behavior pack.
	func behavior() -> PackManifest:
		is_behavior = true
		return self

	## Declares the pack an autoload under this name.
	func autoload(singleton_name: String) -> PackManifest:
		autoload_name = singleton_name
		return self

	## Sets the Add Behavior category (and, unless `verb_category` says otherwise, the picker
	## category its verbs default to).
	func category(name: String) -> PackManifest:
		addon_category = name
		return self

	## Sets the picker category new verbs default to, for a pack whose verbs shelve somewhere
	## other than its own Add Behavior category.
	func verb_category(name: String) -> PackManifest:
		picker_category = name
		return self

	## Sets the pack's search tags.
	func tags(names: PackedStringArray) -> PackManifest:
		search_tags = names
		return self

	## Sets the pack's own version.
	func version(number: String) -> PackManifest:
		addon_version = number
		return self

	## Sets the Inspector variables, in declaration order.
	func variables(declared: Dictionary) -> PackManifest:
		inspector_variables = declared
		return self

	## Exposes every function of the pack as vocabulary.
	func expose_all_verbs() -> PackManifest:
		expose_all_mode = "all"
		return self

	## Exposes every function of the pack as vocabulary, each one scoped to a picked node.
	func expose_all_verbs_on_a_node() -> PackManifest:
		expose_all_mode = "node"
		return self


## One pack's source folder, read once, plus the sheet being assembled from it. A builder gets one
## from `Lib.pack_from_source(...)`, names the pieces it wants in the order the pack declares them,
## and finishes with `Lib.publish(...)`.
class PackSource extends RefCounted:

	## The sheet being assembled. A builder may set anything on it directly; the makers below are
	## the shapes every pack shares.
	var sheet: EventSheetResource = null

	## The picker category new verbs get when `verb`/`condition`/`expression` is not given one.
	var verb_category: String = ""

	# Piece name -> the piece's text, dedented. Filled once, when the folder is read.
	var _pieces: Dictionary = {}

	# The folder these pieces came from, named in every error so a typo says where to look.
	var _dir: String = ""

	# Everything that went wrong assembling this pack: the folder's own problems, plus every piece
	# asked for by a name the folder does not hold. `publish` refuses on a non-empty one.
	var _problems: PackedStringArray = PackedStringArray()

	## The piece named `piece_name`, as the pack will emit it.
	##
	## A MISTYPED NAME FAILS THE BUILD. It used to push an error and return "", and the caller
	## appended that empty string as a row: the pack was written, `save_pack` returned true, the
	## build's exit code was 0, and the only thing that noticed was the drift gate - which can only
	## notice for a pack that is already committed. A NEW pack with a hole in it shipped green.
	func code(piece_name: String) -> String:
		if not _pieces.has(piece_name):
			var message: String = "pack source %s has no piece named '%s' (it has: %s)" % [
				_dir, piece_name, ", ".join(piece_names())]
			push_error(message)
			_problems.append(message)
			return ""
		return str(_pieces[piece_name])

	## Everything that went wrong assembling this pack, in the order it was found. Empty is a pack
	## that may be published.
	func problems() -> PackedStringArray:
		return _problems

	## Whether the folder holds a piece by that name.
	func has(piece_name: String) -> bool:
		return _pieces.has(piece_name)

	## Every piece name the folder holds, sorted - the list an error message prints.
	func piece_names() -> PackedStringArray:
		var names: PackedStringArray = PackedStringArray(_pieces.keys())
		names.sort()
		return names

	## Appends a prose comment row - the pack's "what this is" note. Prose rather than code, so it
	## stays in the builder instead of moving to a source file.
	func note(text: String) -> void:
		var comment: CommentRow = CommentRow.new()
		comment.text = text
		sheet.events.append(comment)

	## Appends one piece of top-level code (exports, signals, private helpers) as its own row.
	func block(piece_name: String) -> void:
		var row: RawCodeRow = RawCodeRow.new()
		row.code = code(piece_name)
		sheet.events.append(row)

	## Appends the piece as the body of the host's `_ready`.
	func on_ready(piece_name: String = "_ready") -> void:
		_trigger("OnReady", piece_name)

	## Appends the piece as the body of the host's `_process`.
	func on_process(piece_name: String = "_process") -> void:
		_trigger("OnProcess", piece_name)

	## Appends the piece as the body of the host's `_physics_process`.
	func on_physics_process(piece_name: String = "_physics_process") -> void:
		_trigger("OnPhysicsProcess", piece_name)

	## Appends the piece as the body of the host's `_exit_tree`.
	func on_tree_exiting(piece_name: String = "_exit_tree") -> void:
		_trigger("OnTreeExiting", piece_name)

	## Appends an exposed void verb - an Action in the picker - whose body is the piece named after
	## the function. `params` is the `[[id, type_name], ...]` list the picker builds its row from.
	func verb(function_name: String, display_name: String, description: String, params: Array, category: String = "") -> void:
		sheet.functions.append(_exposed(function_name, display_name, description, params, category))

	## Appends an exposed bool verb - a Condition in the picker.
	func condition(function_name: String, display_name: String, description: String, params: Array, category: String = "") -> void:
		var fn: EventFunction = _exposed(function_name, display_name, description, params, category)
		fn.return_type = TYPE_BOOL
		sheet.functions.append(fn)

	## Appends an exposed value-returning verb - an Expression - with the given return type
	## (TYPE_FLOAT / TYPE_INT / TYPE_STRING / TYPE_ARRAY / TYPE_VECTOR2 ...; TYPE_MAX is Variant).
	## `params` is the `[[id, type_name], ...]` list every maker in this library takes - the one
	## shape the whole pack-builder tree shares, so it stays that shape here too.
	func expression(function_name: String, display_name: String, description: String, params: Array, ret: Variant.Type, category: String = "") -> void:
		var fn: EventFunction = _exposed(function_name, display_name, description, params, category)
		fn.return_type = ret
		sheet.functions.append(fn)

	## Appends an exposed verb that returns an OBJECT of a named class - a Texture2D, a Node, a
	## Resource. Godot's TYPE_* numbers only reach as far as "an object"; the class is the name.
	func object_expression(function_name: String, display_name: String, description: String, params: Array, returns_class: String, category: String = "") -> void:
		var fn: EventFunction = _exposed(function_name, display_name, description, params, category)
		fn.return_type = TYPE_MAX
		fn.return_type_name = returns_class
		sheet.functions.append(fn)

	# One engine-callback event row carrying one piece as its whole body.
	func _trigger(trigger_id: String, piece_name: String) -> void:
		var row: EventRow = EventRow.new()
		row.trigger_provider_id = "Core"
		row.trigger_id = trigger_id
		var body: RawCodeRow = RawCodeRow.new()
		body.code = code(piece_name)
		row.actions.append(body)
		sheet.events.append(row)

	# The shared exposed-function shape; the body is always the piece named after the function.
	func _exposed(function_name: String, display_name: String, description: String, params: Array, category: String) -> EventFunction:
		var event_function: EventFunction = EventFunction.new()
		event_function.function_name = function_name
		event_function.expose_as_ace = true
		event_function.ace_display_name = display_name
		event_function.ace_category = verb_category if category.is_empty() else category
		event_function.description = description
		for param_pair: Array in params:
			var parameter: ACEParam = ACEParam.new()
			parameter.id = str(param_pair[0])
			parameter.type_name = str(param_pair[1])
			event_function.params.append(parameter)
		var body_row: RawCodeRow = RawCodeRow.new()
		body_row.code = code(function_name)
		event_function.events.append(body_row)
		return event_function


## Compiles and writes a pack assembled from a source folder, exactly as a string-array builder
## always did - the same `save_pack`, so the bytes are the bytes. It is a static beside the class
## rather than a method on it because an inner class cannot reach its own file's statics.
## The bytes, and NOT the bytes of a pack with a hole in it: a folder that could not be read or a
## piece asked for by a name it does not hold refuses here, so the build that called it fails
## instead of writing a pack whose body is an empty string.
static func publish(opened: PackSource, base_path: String, icon_path: String = BEHAVIOR_ICON) -> bool:
	var problems: PackedStringArray = opened.problems()
	if not problems.is_empty():
		push_error("pack %s is not published: %d problem(s) assembling it - %s" % [
			base_path, problems.size(), problems[0]])
		return false
	return save_pack(opened.sheet, base_path, icon_path)


## Opens a pack's source folder and starts the sheet assembled from it.
##
##   source_dir   the folder's own name under `tools/pack_builders/src/` (e.g. "wrap")
##   host_class   the class the behaviour attaches to ("Node2D"), or the sheet's own base
##   pack_class   the `class_name` the pack ships as ("WrapBehavior")
##   description  the sheet's class description - the sentence the Add Behavior list reads
##   manifest     everything a source file cannot carry, declared by name on `Lib.manifest()`;
##                a pack that declares none of it passes nothing
##
## The returned PackSource carries the sheet: a builder adds the pack's rows and verbs to it, in
## the order the pack declares them, and finishes with `Lib.publish(src, base_path)`.
static func pack_from_source(source_dir: String, host_class: String, pack_class: String, description: String, manifest: PackManifest = null) -> PackSource:
	var declared: PackManifest = PackManifest.new() if manifest == null else manifest
	var opened: PackSource = PackSource.new()
	opened._dir = SOURCE_ROOT.path_join(source_dir)
	opened._pieces = _read_pieces(opened._dir)
	opened._problems = _read_problems.duplicate()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = host_class
	sheet.custom_class_name = pack_class
	sheet.class_description = description
	if declared.is_behavior:
		sheet.behavior_mode = true
	if not declared.autoload_name.is_empty():
		sheet.autoload_mode = true
		sheet.autoload_name = declared.autoload_name
	if not declared.addon_category.is_empty():
		sheet.addon_category = declared.addon_category
	if not declared.search_tags.is_empty():
		sheet.addon_tags = declared.search_tags
	if not declared.addon_version.is_empty():
		sheet.addon_version = declared.addon_version
	if not declared.inspector_variables.is_empty():
		sheet.variables = declared.inspector_variables
	if not declared.expose_all_mode.is_empty():
		sheet.ace_expose_all_mode = declared.expose_all_mode
	opened.sheet = sheet
	opened.verb_category = declared.addon_category if declared.picker_category.is_empty() else declared.picker_category
	return opened


## A fresh, empty manifest for a builder to declare its pack on. Every setter returns it, so the
## whole declaration is one expression at the call site.
static func manifest() -> PackManifest:
	return PackManifest.new()


## Ships a pack's COMPANION FILES: the files a pack needs beside its script that are not GDScript at
## all - a `.gdshader`, a `.glsl`, a `.tscn`. They are authored in the pack's own source folder,
## where they are highlighted and (for a shader) parse-checked on import, and copied here to the
## folder the pack itself is written into, so a shipped pack folder is self-contained.
##
## THE COPY IS THE BUILD, so it obeys the same two rules the pack's own bytes do: it follows
## `output_override_dir` (a gate rebuilding into a temporary folder gets the companions there too,
## rather than writing into the repository behind the gate's back), and it is byte-stable - a file
## whose bytes already match is left alone, so a second build changes nothing and `git status` after
## one is empty.
##
## `extensions` names what to copy, without the dot, so a folder may hold both the source `.gd` the
## pieces come from (never shipped) and the companions that are.
static func ship_files(source_dir: String, base_path: String, extensions: PackedStringArray) -> bool:
	var from_dir: String = SOURCE_ROOT.path_join(source_dir)
	var into_dir: String = base_path.get_base_dir()
	if not output_override_dir.is_empty():
		into_dir = output_override_dir
	var reader: DirAccess = DirAccess.open(from_dir)
	if reader == null:
		push_error("pack source folder %s does not exist, so its companion files cannot ship" % from_dir)
		return false
	if DirAccess.make_dir_recursive_absolute(into_dir) != OK and not DirAccess.dir_exists_absolute(into_dir):
		push_error("companion files cannot be written to %s" % into_dir)
		return false
	var names: PackedStringArray = PackedStringArray()
	for entry: String in reader.get_files():
		if extensions.has(entry.get_extension()):
			names.append(entry)
	names.sort()
	if names.is_empty():
		push_error("pack source folder %s holds no companion file with one of these extensions: %s" % [
			from_dir, ", ".join(extensions)])
		return false
	for file_name: String in names:
		var text: String = FileAccess.get_file_as_string(from_dir.path_join(file_name))
		var into_path: String = into_dir.path_join(file_name)
		if FileAccess.file_exists(into_path) and FileAccess.get_file_as_string(into_path) == text:
			continue
		var handle: FileAccess = FileAccess.open(into_path, FileAccess.WRITE)
		if handle == null:
			push_error("companion file %s could not be written" % into_path)
			return false
		handle.store_string(text)
	print("[build_sample_behaviors] shipped %d companion file(s) beside %s" % [
		names.size(), base_path.get_file()])
	return true


# Every piece in every `.gd` of one source folder, read in sorted file order so a build is
# deterministic. A duplicate piece name is an error rather than a silent last-one-wins, because the
# two pieces would be indistinguishable at the call site that asks for one of them.
static func _read_pieces(dir_path: String) -> Dictionary:
	_read_problems = PackedStringArray()
	var pieces: Dictionary = {}
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		_source_problem("pack source folder %s does not exist" % dir_path)
		return pieces
	var file_names: PackedStringArray = PackedStringArray()
	for entry: String in dir.get_files():
		if entry.get_extension() == "gd":
			file_names.append(entry)
	file_names.sort()
	for file_name: String in file_names:
		_read_file_pieces(dir_path.path_join(file_name), pieces)
	return pieces


# The pieces of one file, by the two rules written at the top of this section: a `#region` pair
# around top-level code, and the body of any top-level `func` outside every region.
static func _read_file_pieces(file_path: String, pieces: Dictionary) -> void:
	var text: String = FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		_source_problem("pack source file %s is empty or unreadable" % file_path)
		return
	var open_name: String = ""
	var open_indent: String = ""
	var in_function: bool = false
	var collected: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if not open_name.is_empty() and not in_function:
			if trimmed == "#endregion":
				_store_piece(file_path, pieces, open_name, collected, false)
				open_name = ""
			elif line.begins_with(open_indent):
				collected.append(line.substr(open_indent.length()))
			else:
				collected.append(line.lstrip("\t "))
			continue
		if in_function:
			if line.is_empty() or line.begins_with("\t"):
				collected.append(line.substr(1) if line.begins_with("\t") else line)
				continue
			_store_piece(file_path, pieces, open_name, collected, true)
			open_name = ""
			in_function = false
		if trimmed == "#region":
			_source_problem("pack source %s: a #region with no name cannot be asked for by name" % file_path)
			return
		if trimmed.begins_with("#region "):
			open_name = trimmed.substr(8).strip_edges()
			open_indent = line.substr(0, line.length() - line.lstrip("\t ").length())
			collected = PackedStringArray()
			continue
		if line.begins_with("func "):
			if not line.ends_with(":"):
				_source_problem("pack source %s: '%s' spreads its signature over more than one line" % [
					file_path, trimmed])
				return
			var paren: int = line.find("(")
			if paren < 0:
				_source_problem("pack source %s: '%s' is a func line with no parameter list" % [file_path, trimmed])
				return
			open_name = line.substr(5, paren - 5).strip_edges()
			in_function = true
			collected = PackedStringArray()
	if in_function:
		_store_piece(file_path, pieces, open_name, collected, true)
	elif not open_name.is_empty():
		_source_problem("pack source %s: region '%s' is never closed" % [file_path, open_name])


# One finished piece. A function body loses its trailing blank lines - the ones separating it from
# whatever comes next in the source file, which are the file's punctuation and not the pack's.
static func _store_piece(file_path: String, pieces: Dictionary, piece_name: String, collected: PackedStringArray, trim_tail: bool) -> void:
	if pieces.has(piece_name):
		_source_problem("pack source %s: a second piece is also named '%s'" % [file_path, piece_name])
		return
	var lines: PackedStringArray = collected
	if trim_tail:
		while lines.size() > 0 and lines[lines.size() - 1].strip_edges().is_empty():
			lines.remove_at(lines.size() - 1)
	pieces[piece_name] = "\n".join(lines)
