@tool
class_name ViewportTooltipHelper
extends RefCounted
# The hover-tooltip content for condition/action/trigger rows: the plain-language ACE/function
# description, the GDScript codegen preview the row compiles to, and the BBCode-aware custom
# tooltip panel. Extracted from event_sheet_viewport.gd to keep that file maintainable.
#
# This is a stateless content builder - it owns no per-frame state and never draws into the
# canvas, so unlike the live-values helper it has no draw proxy. It keeps a back-reference to
# the viewport only to read sheet data and the ACE-definition lookup (_find_definition, _sheet).
# Godot's tooltip virtuals (_get_tooltip, _make_custom_tooltip) MUST stay on the Control and
# delegate here; this helper supplies the bodies.

## The sentinel _get_tooltip returns for an exported variable row: _make_custom_tooltip recognizes it
## and swaps in the live Inspector-preview card instead of a text tooltip. Never shown to the user.
const INSPECTOR_PREVIEW_SENTINEL: String = "eventsheet:inspector_preview"

var _viewport: Control = null
# The variable payload staged by _get_tooltip for the sentinel's _make_custom_tooltip call that
# immediately follows it ({name, type_name, default_text, attributes, constant}).
var _pending_inspector_preview: Dictionary = {}


func init(viewport: Control) -> void:
	_viewport = viewport


## Stages the hovered variable for the Inspector-preview tooltip (see INSPECTOR_PREVIEW_SENTINEL).
func set_pending_inspector_preview(payload: Dictionary) -> void:
	_pending_inspector_preview = payload


## Render a hover tooltip's BBCode ([b]/[i]/[color]) when the text carries any - so an ACE/function
## description authored with markup reads styled, not as raw tags. Plain descriptions (the common case) and
## the GDScript-preview fallback have no markup, so this returns null and Godot uses its default tooltip.
## An exported variable row instead hovers as a small live mock of its Inspector - the same preview card
## the Variable dialog shows, built from the row's attributes (drawers, decor, grouping, range).
func build_custom_tooltip(for_text: String) -> Object:
	if for_text == INSPECTOR_PREVIEW_SENTINEL and not _pending_inspector_preview.is_empty():
		return build_inspector_preview_tooltip(_pending_inspector_preview)
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


## The hover card for an exported variable: the live Inspector mock (decor, grouping, widget miniature,
## plain sentence) at tooltip size. Static + dock-free so extensions and the render harness can build the
## identical card through EventSheets.build_inspector_preview.
static func build_inspector_preview_tooltip(payload: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.11, 0.13, 0.98)
	style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6.0)
	panel.add_theme_stylebox_override("panel", style)
	var card := EventSheetInspectorPreviewCard.new()
	card.custom_minimum_size = Vector2(320.0, 0.0)
	card.update_preview(
		str(payload.get("name", "")),
		str(payload.get("type_name", "Variant")),
		str(payload.get("default_text", "")),
		payload.get("attributes") if payload.get("attributes") is Dictionary else {},
		true,
		bool(payload.get("constant", false))
	)
	panel.add_child(card)
	return panel


## The plain-language description for an ACE - from its registered definition (custom/behaviour ACEs) or
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


## The `signal …` line a signal row compiles to, for that row's hover. The row itself reads by the
## friendly published name and drops the code cue on purpose, but the identifier is exactly what
## someone needs when they go to connect to it from a script - so it lives here rather than nowhere.
## Static: it reads only the resource, so tests can call it without a live viewport.
static func signal_declaration_tooltip(signal_row: SignalRow) -> String:
	var declaration: String = "signal %s" % signal_row.signal_name
	if not signal_row.params.is_empty():
		declaration += "(%s)" % ", ".join(signal_row.params)
	if not signal_row.trigger:
		return declaration
	var lines: PackedStringArray = PackedStringArray([declaration, "", "Published as a trigger."])
	if not signal_row.ace_category.strip_edges().is_empty():
		lines.append("Picker category: %s" % signal_row.ace_category.strip_edges())
	return "\n".join(lines)


## Everything a published verb declares, for its Define row's hover: the full name (a long one clips
## inside the condition lane, so the tooltip is where it is always readable), its description, each
## parameter with type / default / choices / its own blurb, and the markers that change how it is called.
## This is the overflow valve for the row - the row shows the shape, the tooltip shows the detail.
func verb_definition_tooltip(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	var title: String = event_function.ace_display_name.strip_edges()
	if title.is_empty():
		title = event_function.function_name.capitalize()
	var category: String = event_function.ace_category.strip_edges()
	# The category is not on the row (a pack files every verb under the same one), so it reads here.
	lines.append("%s  ·  %s" % [title, category] if not category.is_empty() else title)
	var description: String = event_function.description.strip_edges()
	if description.is_empty():
		description = event_function.doc_comment.strip_edges()
	if not description.is_empty():
		lines.append("")
		lines.append(description)
	var typed_params: Array[ACEParam] = []
	for entry: Variant in event_function.params:
		if entry is ACEParam:
			typed_params.append(entry as ACEParam)
	if not typed_params.is_empty():
		lines.append("")
		for param: ACEParam in typed_params:
			var detail: String = "  %s : %s" % [param.get_param_name(), param.type_name]
			var default_text: String = param.gdscript_default.strip_edges()
			if not default_text.is_empty():
				detail += " = %s" % default_text
			lines.append(detail)
			var param_description: String = param.get_param_description().strip_edges()
			if not param_description.is_empty():
				lines.append("      %s" % param_description)
	var markers: PackedStringArray = PackedStringArray()
	if event_function.is_async:
		markers.append("waits (async)")
	if event_function.is_static:
		markers.append("static")
	if not event_function.expose_as_ace:
		markers.append("internal - not published as an ACE")
	if event_function.featured:
		markers.append("featured")
	for annotation: String in event_function.annotation_lines:
		markers.append(annotation.strip_edges())
	if not event_function.tool_button_label.strip_edges().is_empty():
		markers.append("Inspector button: %s" % event_function.tool_button_label.strip_edges())
	if not markers.is_empty():
		lines.append("")
		lines.append(" · ".join(markers))
	return "\n".join(lines)


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
