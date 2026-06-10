import io

# ── 1. LocalVariable: options field (the C3 "Combo" property) ──
p = "addons/eventforge/resources/local_variable.gd"
s = io.open(p, encoding="utf-8").read()
old = "@export var exported: bool = false"
assert old in s
s = s.replace(old, old + """
## C3-style "Combo": allowed values for a String variable. When exported, compiles to
## @export_enum so the Inspector shows a dropdown; the value picker uses it too.
@export var options: PackedStringArray = PackedStringArray()""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("local_variable done")

# ── 2. Compiler: @export_enum emission for combo variables ──
p = "addons/eventforge/compiler/sheet_compiler.gd"
s = io.open(p, encoding="utf-8").read()
old = """	if local_var.is_constant:
		return "const %s: %s = %s" % [local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]
	var export_prefix: String = "@export " if local_var.exported else ""
	return "%svar %s: %s = %s" % [export_prefix, local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]"""
assert old in s
s = s.replace(old, """	if local_var.is_constant:
		return "const %s: %s = %s" % [local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]
	# Combo (C3): exported String with options -> @export_enum dropdown in the Inspector.
	if local_var.exported and local_var.type_name == "String" and not local_var.options.is_empty():
		return "%s var %s: String = %s" % [_export_enum_prefix(local_var.options), local_var.name, _to_code_literal(local_var.default_value)]
	var export_prefix: String = "@export " if local_var.exported else ""
	return "%svar %s: %s = %s" % [export_prefix, local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]

## Canonical @export_enum prefix ("@export_enum(\\"a\\", \\"b\\")") — verify-lift relies on
## this exact form.
static func _export_enum_prefix(options: PackedStringArray) -> String:
	var quoted: PackedStringArray = PackedStringArray()
	for option: String in options:
		if not option.strip_edges().is_empty():
			quoted.append("\\"%s\\"" % option.strip_edges())
	return "@export_enum(%s)" % ", ".join(quoted)""", 1)
old = """			var exported: bool = bool(descriptor.get("exported", true))
			var export_prefix: String = "@export " if exported else ""
			lines.append("%svar %s: %s = %s" % [export_prefix, var_name, type_name, _to_code_literal(default_value)])"""
assert old in s
s = s.replace(old, """			var exported: bool = bool(descriptor.get("exported", true))
			var combo_options: PackedStringArray = PackedStringArray(descriptor.get("options", []))
			if exported and type_name == "String" and not combo_options.is_empty():
				lines.append("%s var %s: String = %s" % [_export_enum_prefix(combo_options), var_name, _to_code_literal(default_value)])
				continue
			var export_prefix: String = "@export " if exported else ""
			lines.append("%svar %s: %s = %s" % [export_prefix, var_name, type_name, _to_code_literal(default_value)])"""
, 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("compiler done")

# ── 3. VariableParser: read @export_enum lines back (verify-lift) ──
p = "addons/eventforge/importer/variable_parser.gd"
s = io.open(p, encoding="utf-8").read()
old = """		var line: String = raw_line.strip_edges()
		var exported: bool = false
		if line.begins_with("@export "):
			exported = true
			line = line.substr("@export ".length()).strip_edges()"""
assert old in s
s = s.replace(old, """		var line: String = raw_line.strip_edges()
		var exported: bool = false
		var combo_options: PackedStringArray = PackedStringArray()
		if line.begins_with("@export_enum(") and line.find(") ") != -1:
			exported = true
			var close_index: int = line.find(") ")
			for raw_option: String in line.substr("@export_enum(".length(), close_index - "@export_enum(".length()).split(", "):
				combo_options.append(raw_option.strip_edges().trim_prefix("\\"").trim_suffix("\\""))
			line = line.substr(close_index + 2).strip_edges()
		elif line.begins_with("@export "):
			exported = true
			line = line.substr("@export ".length()).strip_edges()"""
, 1)
old = """		variables[variable_name] = {
			"type": type_name,
			"default": _parse_literal(default_text),
			"exported": exported
		}"""
assert old in s
s = s.replace(old, """		variables[variable_name] = {
			"type": type_name,
			"default": _parse_literal(default_text),
			"exported": exported,
			"options": combo_options
		}""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("parser done")

# ── 4. Importer: lifted variables keep their options ──
p = "addons/eventforge/importer/gdscript_importer.gd"
s = io.open(p, encoding="utf-8").read()
old = """	lifted.exported = bool(descriptor.get("exported", false))
	if SheetCompiler._emit_tree_variable_line(lifted) != line:"""
assert old in s
s = s.replace(old, """	lifted.exported = bool(descriptor.get("exported", false))
	lifted.options = PackedStringArray(descriptor.get("options", []))
	if SheetCompiler._emit_tree_variable_line(lifted) != line:""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("importer done")

# ── 5. Analyzer: @ace_param_options annotation (addon combos) ──
p = "addons/eventsheet/ace/semantic_analyzer.gd"
s = io.open(p, encoding="utf-8").read()
old = """        elif directive.begins_with("@ace_param_hint"):"""
assert old in s
s = s.replace(old, """        elif directive.begins_with("@ace_param_options"):
            # `@ace_param_options(movement horizontal, vertical, angle)` -> the param
            # renders as a dropdown (C3's Combo) in the params dialog.
            var options_value: String = _extract_annotation_value(directive)
            var options_split: PackedStringArray = options_value.split(" ", false, 1)
            if options_split.size() == 2:
                var param_options: Dictionary = overrides.get("param_options", {})
                var option_values: Array = []
                for raw_option in options_split[1].split(","):
                    if not raw_option.strip_edges().is_empty():
                        option_values.append(raw_option.strip_edges())
                param_options[options_split[0].strip_edges()] = option_values
                overrides["param_options"] = param_options
        elif directive.begins_with("@ace_param_hint"):""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("analyzer done")

# ── 6. Generator: plumb param_options onto parameter dicts ──
p = "addons/eventsheet/ace/ace_generator.gd"
s = io.open(p, encoding="utf-8").read()
old = """    var param_hints: Dictionary = overrides.get("param_hints", {})
    for argument_info in raw_args:"""
assert old in s
s = s.replace(old, """    var param_hints: Dictionary = overrides.get("param_hints", {})
    var param_options: Dictionary = overrides.get("param_options", {})
    for argument_info in raw_args:""", 1)
old = """        if param_hints.has(argument_name) and not parameter_override.has("hint"):
            parameter_override = parameter_override.duplicate()
            parameter_override["hint"] = str(param_hints[argument_name])"""
assert old in s
s = s.replace(old, old + """
        if param_options.has(argument_name) and not parameter_override.has("options"):
            parameter_override = parameter_override.duplicate()
            parameter_override["options"] = param_options[argument_name]""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("generator done")

# ── 7. Params dialog: enum-driven dropdowns + color picker fields ──
p = "addons/eventsheet/editor/ace_params_dialog.gd"
s = io.open(p, encoding="utf-8").read()
old = """	if hint == EXPRESSION_HINT:
		return _create_expression_field(key, default_value)"""
assert old in s
s = s.replace(old, """	if hint.begins_with("enum:"):
		return _create_enum_reference_field(key, default_value, hint.get_slice(":", 1))
	if hint == "color" or field_type == TYPE_COLOR:
		return _create_color_field(key, default_value)
	if hint == EXPRESSION_HINT:
		return _create_expression_field(key, default_value)""", 1)
old = "func _create_expression_field(key: String, default_value: Variant) -> Control:"
assert old in s
s = s.replace(old, """## Sheet-enum-driven dropdown (hint "enum:State"): options are the enum's members as
## State.MEMBER values — the C3 Combo backed by a real enum.
func _create_enum_reference_field(key: String, default_value: Variant, enum_name: String) -> Control:
	var sheet: EventSheetResource = (_lint_context_provider.call() as EventSheetResource) if _lint_context_provider.is_valid() else null
	var member_options: Array = []
	if sheet != null:
		for entry in sheet.events:
			if entry is EnumRow and (entry as EnumRow).enum_name == enum_name and (entry as EnumRow).enabled:
				for member: String in (entry as EnumRow).members:
					var member_name: String = member.get_slice("=", 0).strip_edges()
					member_options.append({"key": "%s.%s" % [enum_name, member_name], "label": member_name})
	if member_options.is_empty():
		var fallback: LineEdit = LineEdit.new()
		fallback.text = str(default_value)
		fallback.placeholder_text = "%s.MEMBER (enum not found in this sheet)" % enum_name
		_fields[key] = fallback
		return fallback
	return _create_options_field(key, member_options, default_value)

## Color picker param (hint "color" or a Color-typed param). The value round-trips as a
## canonical Color(r, g, b, a) literal so the sheet can show a swatch next to the text.
func _create_color_field(key: String, default_value: Variant) -> Control:
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(72.0, 0.0)
	var parsed: Variant = str_to_var(str(default_value))
	picker.color = parsed if parsed is Color else Color.WHITE
	_fields[key] = picker
	return picker

static func color_to_literal(value: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [String.num(value.r, 3), String.num(value.g, 3), String.num(value.b, 3), String.num(value.a, 3)]

func _create_expression_field(key: String, default_value: Variant) -> Control:""", 1)
old = """	if field is LineEdit:
		return (field as LineEdit).text"""
assert old in s
s = s.replace(old, """	if field is ColorPickerButton:
		return color_to_literal((field as ColorPickerButton).color)
	if field is LineEdit:
		return (field as LineEdit).text""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("dialog done")

# ── 8. Viewport: swatch metadata when an ACE param is a Color literal ──
p = "addons/eventsheet/editor/event_sheet_viewport.gd"
s = io.open(p, encoding="utf-8").read()
old = """                            "object_label": _object_label_for(condition.provider_id, condition.ace_id),
                            "object_icon": _object_icon_for(condition.provider_id, condition.ace_id)
                        }.merged(condition_style_meta, true)"""
assert old in s
s = s.replace(old, """                            "object_label": _object_label_for(condition.provider_id, condition.ace_id),
                            "object_icon": _object_icon_for(condition.provider_id, condition.ace_id),
                            "swatch_color": _first_color_in_params(condition)
                        }.merged(condition_style_meta, true)""", 1)
old = """                            "object_label": _object_label_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
                            "object_icon": _object_icon_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id)
                        }.merged(action_style_meta, true)"""
assert old in s
s = s.replace(old, """                            "object_label": _object_label_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
                            "object_icon": _object_icon_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
                            "swatch_color": _first_color_in_params(action_resource)
                        }.merged(action_style_meta, true)""", 1)
old = "func _build_row_from_resource(entry: Resource, indent: int) -> EventRowData:"
assert old in s
s = s.replace(old, """## First Color(...) literal among an ACE's param values (null when none) — drives the
## little color swatch drawn after the condition/action text.
func _first_color_in_params(ace: Resource) -> Variant:
    var params: Variant = ace.get("params")
    if not (params is Dictionary):
        return null
    for key: Variant in (params as Dictionary).keys():
        var value: Variant = (params as Dictionary)[key]
        if value is String and (value as String).strip_edges().begins_with("Color("):
            var parsed: Variant = str_to_var((value as String).strip_edges())
            if parsed is Color:
                return parsed
    return null

func _build_row_from_resource(entry: Resource, indent: int) -> EventRowData:""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("viewport done")

# ── 9. Renderer: draw the swatch after the span text ──
p = "addons/eventsheet/editor/event_row_renderer.gd"
s = io.open(p, encoding="utf-8").read()
old = """        var value_ranges: Array = metadata.get("value_ranges", []) if span_index != editing_span_index else []
        if value_ranges.is_empty():
            _draw_text(control, Vector2(text_x, baseline_y), draw_text, text_width, font, draw_font_size, color)
        else:
            var value_color: Color = event_style.value_highlight_color if event_style != null else COLOR_VALUE
            _draw_text_with_values(control, Vector2(text_x, baseline_y), draw_text, value_ranges, text_width, font, draw_font_size, color, value_color)"""
assert old in s
s = s.replace(old, old + """
        # Color params get a small swatch right after the text (C3-style color preview).
        var swatch: Variant = metadata.get("swatch_color")
        if swatch is Color:
            var swatch_advance: float = minf(font.get_string_size(draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x, text_width)
            var swatch_size: float = maxf(draw_font_size * 0.7, 8.0)
            var swatch_rect: Rect2 = Rect2(text_x + swatch_advance + 6.0, span.rect.position.y + (span.rect.size.y - swatch_size) * 0.5, swatch_size, swatch_size)
            control.draw_rect(swatch_rect, swatch as Color, true)
            control.draw_rect(swatch_rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)""", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("renderer done")

# ── 10. SetModulate gets the color picker; Sine pack movement becomes a combo ──
p = "addons/eventforge/registration/builtin_aces.gd"
s = io.open(p, encoding="utf-8").read()
old = '_make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Tint (RGBA).", "expression")'
assert old in s
s = s.replace(old, '_make_param("color", "String", "Color(1, 1, 1, 1)", "Color", "Tint (RGBA).", "color")', 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("builtins done")

p = "tools/build_sample_behaviors.gd"
s = io.open(p, encoding="utf-8").read()
old = '''		"movement": {"type": "String", "default": "horizontal", "exported": true},'''
assert old in s
s = s.replace(old, '''		"movement": {"type": "String", "default": "horizontal", "exported": true, "options": ["horizontal", "vertical", "angle"]},''', 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("sine combo done")
