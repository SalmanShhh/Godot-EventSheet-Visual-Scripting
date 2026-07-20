# Pack-builder shared library (no class_name: tool scripts stay out of the global namespace). save_pack
# compiles the in-memory sheet straight to a banner-less .gd - the .gd IS the pack (the editable event
# sheet AND the runtime script), with no .tres companion. audit_addons enforces no-drift: every shipped
# .gd must re-import and recompile to itself byte-for-byte.
@tool

# Lives WITH the shipped packs (eventsheet_addons/), not the editor addon (addons/eventsheet/), so a
# generated pack stays self-contained - removing the editor never dangles its @icon (clean_removal_test).
const BEHAVIOR_ICON := "res://eventsheet_addons/behavior.svg"


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
	var compile_result: Dictionary = EventSheets.publish_pack(sheet, base_path, icon_path)
	if not bool(compile_result.get("success", false)):
		push_error("Failed to compile %s.gd: %s" % [base_path, compile_result.get("errors")])
		return false
	print("[build_sample_behaviors] built %s (.gd), warnings: %s" % [base_path.get_file(), compile_result.get("warnings")])
	return true


## Shared shape for the spring/tween builders: one exposed-as-ACE function.
static func append_function(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
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


# ── Shared Juice runtime blocks ──────────────────────────────────────────────────────────
# The screen-FX overlay (bundled shader + build/visibility helpers) is identical in the 2D and 3D
# Juice packs; single-sourcing it here means a fix (or the un-set-uniform-null crash fix) lands ONCE
# and both packs regenerate from it. Emission stays byte-identical, so the drift audit still passes.


## The full-screen FX overlay block: one shader with three dials (vignette / chromatic aberration /
## radial speed lines), built on first use and hidden when every dial is 0. Both Juice packs append
## this verbatim as their fx overlay block. The paired verbs (Pulse Vignette / Chromatic Kick / Set
## Speed Lines) are per-pack (their help text differs) but share the same bodies below.
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
		"\t# whenever only one of the three effects had been used.",
		"\t_fx_material.set_shader_parameter(\"vignette_strength\", 0.0)",
		"\t_fx_material.set_shader_parameter(\"chroma_strength\", 0.0)",
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
		"\t\t\tor float(_fx_material.get_shader_parameter(\"speed_lines\")) > 0.001"
	])


# Shared verb BODIES (the help text stays per-pack; the runtime code is one source). A fix to any of
# these lands once for both Juice packs.
const JUICE_PULSE_VIGNETTE_BODY := "_ensure_fx_overlay()\nif _fx_material == null:\n\treturn\nif _vignette_tween != null and _vignette_tween.is_valid():\n\t_vignette_tween.kill()\n_fx_material.set_shader_parameter(\"vignette_color\", Color(color.r, color.g, color.b, 1.0))\n_fx_material.set_shader_parameter(\"vignette_strength\", clampf(strength, 0.0, 1.0))\n_fx_rect.visible = true\nvar tw: Tween = create_tween()\ntw.tween_property(_fx_material, \"shader_parameter/vignette_strength\", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)\ntw.finished.connect(_fx_update_visibility)\n_vignette_tween = tw"

const JUICE_CHROMATIC_KICK_BODY := "_ensure_fx_overlay()\nif _fx_material == null:\n\treturn\nif _chroma_tween != null and _chroma_tween.is_valid():\n\t_chroma_tween.kill()\n_fx_material.set_shader_parameter(\"chroma_strength\", clampf(strength, 0.0, 1.0))\n_fx_rect.visible = true\nvar tw: Tween = create_tween()\ntw.tween_property(_fx_material, \"shader_parameter/chroma_strength\", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)\ntw.finished.connect(_fx_update_visibility)\n_chroma_tween = tw"

const JUICE_SET_SPEED_LINES_BODY := "_ensure_fx_overlay()\nif _fx_material == null:\n\treturn\n_fx_material.set_shader_parameter(\"speed_lines\", clampf(intensity, 0.0, 1.0))\n_fx_update_visibility()"

const JUICE_PLAY_SOUND_VARIED_BODY := "_spawn_one_shot(path, 1.0 + randf_range(-pitch_jitter, pitch_jitter), randf_range(-absf(volume_jitter_db), 0.0))"

const JUICE_PLAY_SOUND_INTENSITY_BODY := "var power: float = clampf(intensity, 0.0, 1.0)\n_spawn_one_shot(path, lerpf(0.85, 1.15, power) * (1.0 + randf_range(-0.03, 0.03)), lerpf(-14.0, 0.0, power))"

const JUICE_COUNT_TO_BODY := "var from: float = float(_tickers.get(ticker_name, 0.0))\n_ticker_targets[ticker_name] = target\nvar old_tween: Tween = _ticker_tweens.get(ticker_name, null)\nif old_tween != null and is_instance_valid(old_tween):\n\told_tween.kill()\nvar tw: Tween = create_tween()\ntw.tween_method(func(v: float) -> void: _tickers[ticker_name] = v, from, target, maxf(duration, 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)\ntw.finished.connect(_finish_ticker.bind(ticker_name))\n_ticker_tweens[ticker_name] = tw"

const JUICE_SET_TICKER_BODY := "var old_tween: Tween = _ticker_tweens.get(ticker_name, null)\nif old_tween != null and is_instance_valid(old_tween):\n\told_tween.kill()\n_tickers[ticker_name] = value\n_ticker_targets[ticker_name] = value"
