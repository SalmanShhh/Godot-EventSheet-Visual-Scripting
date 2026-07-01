@tool
class_name ViewportTooltipHelper
extends RefCounted
# The hover-tooltip content for condition/action/trigger rows: the plain-language ACE/function
# description, the GDScript codegen preview the row compiles to, and the BBCode-aware custom
# tooltip panel. Extracted from event_sheet_viewport.gd to keep that file maintainable.
#
# This is a stateless content builder — it owns no per-frame state and never draws into the
# canvas, so unlike the live-values helper it has no draw proxy. It keeps a back-reference to
# the viewport only to read sheet data and the ACE-definition lookup (_find_definition, _sheet).
# Godot's tooltip virtuals (_get_tooltip, _make_custom_tooltip) MUST stay on the Control and
# delegate here; this helper supplies the bodies.

var _viewport: Control = null

func init(viewport: Control) -> void:
	_viewport = viewport

## Render a hover tooltip's BBCode ([b]/[i]/[color]) when the text carries any — so an ACE/function
## description authored with markup reads styled, not as raw tags. Plain descriptions (the common case) and
## the GDScript-preview fallback have no markup, so this returns null and Godot uses its default tooltip.
func build_custom_tooltip(for_text: String) -> Object:
	if not EventSheetBBCodeLite.has_markup(for_text):
		return null
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.11, 0.13, 0.98)
	style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", style)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.custom_minimum_size = Vector2(300.0, 0.0)
	rich.text = for_text
	panel.add_child(rich)
	return panel

## The plain-language description for an ACE — from its registered definition (custom/behaviour ACEs) or
## its built-in descriptor (filled from the generated descriptions map). "" when none is set.
func ace_description(provider_id: String, ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	# A deprecated ACE stays in the sheet and keeps compiling, but its hover is prefixed with the
	# "[Deprecated] … Use X instead." note so an existing usage clearly steers the user to the replacement.
	var prefix: String = ""
	if descriptor != null and descriptor.is_deprecated:
		prefix = descriptor.deprecation_note() + "\n"
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition != null and not str(definition.description).strip_edges().is_empty():
		return prefix + str(definition.description)
	if descriptor != null and not str(descriptor.description).strip_edges().is_empty():
		return prefix + str(descriptor.description)
	return prefix.strip_edges()

## The description of the Function a Call-Function action targets (the named verb you created), or "".
func function_call_description(action: ACEAction) -> String:
	var call_params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var function_name: String = str(call_params.get("function_name", "")).strip_edges()
	if function_name.is_empty() or _viewport._sheet == null:
		return ""
	for function_entry: Variant in _viewport._sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == function_name:
			return str((function_entry as EventFunction).description).strip_edges()
	return ""

## The GDScript snippet an ACE compiles to: its codegen template with parameter values
## substituted (definition metadata first, then the base descriptor registry).
func codegen_preview_for(provider_id: String, ace_id: String, params: Dictionary) -> String:
	var template: String = ""
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition != null:
		template = str(definition.metadata.get("codegen_template", ""))
	if template.strip_edges().is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
		if descriptor != null:
			template = descriptor.codegen_template
	return fill_codegen_template(template, params)

static func fill_codegen_template(template: String, params: Dictionary) -> String:
	if template.strip_edges().is_empty():
		return ""
	var filled: String = template
	for key in params.keys():
		filled = filled.replace("{%s}" % str(key), str(params[key]))
	return filled
