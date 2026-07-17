@tool
class_name EventSheetSemanticAnalyzer
extends RefCounted

## Every annotation token the provider dialect understands, plus the sheet-attribute
## markers the compiler writes into pack .gd files (a pack is a compiled sheet AND a
## provider, so those markers are legitimate in scanned sources). Anything else that
## looks like an @ace_ annotation is a typo and gets a warning instead of vanishing.
const KNOWN_ANNOTATIONS := {
	"@ace_hidden": true,
	"@ace_deprecated": true,
	"@ace_category": true,
	"@ace_name": true,
	"@ace_description": true,
	"@ace_icon": true,
	"@ace_action": true,
	"@ace_condition": true,
	"@ace_expression": true,
	"@ace_trigger": true,
	"@ace_display_template": true,
	"@ace_codegen_template": true,
	"@ace_param_options": true,
	"@ace_param_autocomplete": true,
	"@ace_param_hint": true,
	"@ace_param": true,
	"@ace_tags": true,
	"@ace_expose_all": true,
	"@ace_featured": true,
	"@ace_family": true,
	"@ace_family_member": true,
	"@ace_family_var": true,
	"@ace_group": true,
	"@ace_region": true,
	"@ace_includes": true,
	"@ace_uses": true
}


func parse_source_metadata(script: Script) -> Dictionary:
	var metadata := {
		"class_name": "",
		"class_description": "",
		"tags": [],
		"expose_all": false,
		"expose_all_mode": "",
		"default_category": "",
		"default_icon": "",
		"native_icon": "",
		"unknown_annotations": [],
		"signals": {},
		"methods": {},
		"properties": {}
	}
	if script == null or script.resource_path.is_empty() or not FileAccess.file_exists(script.resource_path):
		return metadata
	var source: String = FileAccess.get_file_as_string(script.resource_path)
	var pending_directives: Array[String] = []
	var pending_export: bool = false
	# The compiler emits the class description as a `##` block right AFTER `extends` (Godot's
	# doc position); capture that contiguous block too, so generated packs get a provider
	# description without hand-annotating. The first blank/non-doc line ends the block - a
	# member's own doc (always separated by a blank line) is never swallowed.
	var awaiting_class_doc: bool = false
	var class_doc_lines: PackedStringArray = PackedStringArray()
	for raw_line in source.split("\n"):
		var stripped: String = raw_line.strip_edges()
		if awaiting_class_doc:
			if stripped.begins_with("## ") and not stripped.begins_with("## @"):
				class_doc_lines.append(stripped.trim_prefix("##").strip_edges())
				continue
			awaiting_class_doc = false
		if stripped.is_empty():
			continue
		if stripped.begins_with("class_name ") or stripped.begins_with("extends "):
			# Leading `##` doc lines become the provider's description (zero-config addon
			# metadata: everything derives from the script itself, no manifest).
			if str(metadata["class_description"]).is_empty():
				var doc_lines: Array[String] = []
				for pending in pending_directives:
					match _annotation_token(pending):
						"@ace_tags":
							# `@ace_tags(movement, retro, jam)` -> provider tags (searchable
							# in the picker, filterable over MCP, shown in tooltips).
							for raw_tag in _extract_annotation_value(pending).split(","):
								if not raw_tag.strip_edges().is_empty():
									(metadata["tags"] as Array).append(raw_tag.strip_edges())
						"@ace_expose_all":
							# One class-level opt-in: every own public method/signal becomes an ACE with
							# zero per-member annotations (type from return type, name from the identifier,
							# codegen synthesized). `@ace_expose_all(node)` synthesizes the node-targeted
							# $Provider.method() form (vs the owned-instance default) for behaviors.
							metadata["expose_all"] = true
							if _extract_annotation_value(pending).strip_edges() == "node":
								metadata["expose_all_mode"] = "node"
						"@ace_category":
							# Class-level category is the pack-wide default: every member without
							# its own @ace_category inherits it (member annotations win).
							metadata["default_category"] = _extract_annotation_value(pending)
						"@ace_icon":
							# Class-level icon likewise defaults every member's picker icon.
							metadata["default_icon"] = _extract_annotation_value(pending)
						"":
							doc_lines.append(pending)
						var other_token:
							_note_unknown_annotation(other_token, metadata)
				metadata["class_description"] = " ".join(doc_lines).strip_edges()
			pending_directives.clear()
			pending_export = false
			if stripped.begins_with("class_name "):
				metadata["class_name"] = stripped.trim_prefix("class_name ").strip_edges()
			elif stripped.begins_with("extends "):
				awaiting_class_doc = true
			continue
		if stripped.begins_with("##"):
			pending_directives.append(stripped.trim_prefix("##").strip_edges())
			continue
		if stripped.begins_with("@ace_"):
			pending_directives.append(stripped)
			continue
		if stripped.begins_with("@icon("):
			# The native @icon class annotation doubles as the member-icon default (below an
			# explicit class-level ## @ace_icon and a registrar pack_icon): every behaviour pack
			# already ships one, so its reflected signals/properties/methods show the pack's own
			# icon in the picker and on viewport object labels with zero extra annotations.
			var native_icon: String = stripped.trim_prefix("@icon(").trim_suffix(")").strip_edges().trim_prefix("\"").trim_suffix("\"")
			if native_icon.begins_with("res://"):
				metadata["native_icon"] = native_icon
			continue
		if stripped.begins_with("@export"):
			pending_export = true
			var inline_property_name: String = _parse_var_name(stripped)
			if not inline_property_name.is_empty():
				metadata["properties"][inline_property_name] = _build_overrides(pending_directives, true, metadata)
				pending_directives.clear()
				pending_export = false
			continue
		if stripped.begins_with("signal "):
			var signal_name: String = _parse_signal_name(stripped)
			metadata["signals"][signal_name] = _build_overrides(pending_directives, false, metadata)
			pending_directives.clear()
			pending_export = false
			continue
		if stripped.begins_with("func "):
			var method_name: String = _parse_func_name(stripped)
			metadata["methods"][method_name] = _build_overrides(pending_directives, false, metadata)
			pending_directives.clear()
			pending_export = false
			continue
		if pending_export and stripped.begins_with("var "):
			var property_name: String = _parse_var_name(stripped)
			metadata["properties"][property_name] = _build_overrides(pending_directives, true, metadata)
			pending_directives.clear()
			pending_export = false
			continue
		if not stripped.begins_with("@"):
			pending_directives.clear()
			pending_export = false
	if str(metadata["class_description"]).is_empty() and not class_doc_lines.is_empty():
		metadata["class_description"] = " ".join(class_doc_lines).strip_edges()
	_merge_registrar_metadata(script, metadata)
	if str(metadata["default_icon"]).is_empty():
		metadata["default_icon"] = str(metadata.get("native_icon", ""))
	_apply_class_defaults(metadata)
	_warn_unknown_annotations(script.resource_path, metadata)
	return metadata


## Providers may also register through the typed hook
## `static func _eventforge_register(reg: EventForgeRegistrar) -> void` - real code,
## so the script editor autocompletes the vocabulary and typos are compile errors.
## The hook's output merges ONTO the comment dialect field by field (explicit
## registrar calls win), BEFORE class defaults fill the gaps, so both dialects flow
## through one pipeline and stay definition-equivalent.
func _merge_registrar_metadata(script: Script, metadata: Dictionary) -> void:
	var has_hook: bool = false
	for method_info in script.get_script_method_list():
		if str(method_info.get("name", "")) == "_eventforge_register":
			has_hook = true
			break
	if not has_hook:
		return
	var registrar := EventForgeRegistrar.new()
	script.call("_eventforge_register", registrar)
	if not registrar.pack_category_value.is_empty() and str(metadata.get("default_category", "")).is_empty():
		metadata["default_category"] = registrar.pack_category_value
	if not registrar.pack_icon_value.is_empty() and str(metadata.get("default_icon", "")).is_empty():
		metadata["default_icon"] = registrar.pack_icon_value
	for tag in registrar.pack_tags:
		if not (metadata["tags"] as Array).has(tag):
			(metadata["tags"] as Array).append(tag)
	for member_name in registrar.members:
		var entry: Dictionary = registrar.members[member_name]
		var section: String = str(entry.get("section", "methods"))
		var section_dict: Dictionary = metadata.get(section, {})
		var base: Dictionary = section_dict.get(member_name, _build_overrides([], section == "properties", metadata))
		var registrar_overrides: Dictionary = entry.get("overrides", {})
		for key in registrar_overrides:
			if key in ["param_hints", "param_options", "param_autocomplete", "param_descriptions"]:
				# Param channels merge per param so a registrar call can refine one
				# parameter without erasing comment annotations on the others.
				var merged: Dictionary = base.get(key, {})
				for param_name in (registrar_overrides[key] as Dictionary):
					merged[param_name] = (registrar_overrides[key] as Dictionary)[param_name]
				base[key] = merged
			else:
				base[key] = registrar_overrides[key]
		section_dict[member_name] = base
		metadata[section] = section_dict


## Members without their own category/icon inherit the class-level defaults
## (precedence: member annotation > class default > the generator's per-kind fallback).
func _apply_class_defaults(metadata: Dictionary) -> void:
	var default_category: String = str(metadata.get("default_category", ""))
	var default_icon: String = str(metadata.get("default_icon", ""))
	if default_category.is_empty() and default_icon.is_empty():
		return
	for section in ["signals", "methods", "properties"]:
		var entries: Dictionary = metadata.get(section, {})
		for member_name in entries:
			var overrides: Dictionary = entries[member_name]
			if not default_category.is_empty() and str(overrides.get("category", "")).is_empty():
				overrides["category"] = default_category
			if not default_icon.is_empty() and str(overrides.get("icon", "")).is_empty():
				overrides["icon"] = default_icon


func _warn_unknown_annotations(script_path: String, metadata: Dictionary) -> void:
	var unknown: Array = metadata.get("unknown_annotations", [])
	if unknown.is_empty():
		return
	push_warning("EventSheets: %s ignores unknown ACE annotation(s): %s (typo?)" % [
		script_path, ", ".join(PackedStringArray(unknown))
	])


func _note_unknown_annotation(token: String, metadata: Dictionary) -> void:
	if token.is_empty() or KNOWN_ANNOTATIONS.has(token):
		return
	var unknown: Array = metadata.get("unknown_annotations", [])
	if not unknown.has(token):
		unknown.append(token)
	metadata["unknown_annotations"] = unknown


## The bare annotation token of a directive line: "@ace_name(\"X\")" -> "@ace_name";
## returns "" for prose lines (anything not starting with @ace_).
func _annotation_token(directive: String) -> String:
	if not directive.begins_with("@ace_"):
		return ""
	var token: String = "@ace_"
	for index in range(5, directive.length()):
		var character: String = directive.substr(index, 1)
		if character == "_" or (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			token += character
		else:
			break
	return token


func get_provider_id(target: Object, source_metadata: Dictionary) -> String:
	var class_name_text: String = str(source_metadata.get("class_name", ""))
	if not class_name_text.is_empty():
		return class_name_text
	var script: Script = target.get_script() as Script
	if script != null and not script.resource_path.is_empty():
		return script.resource_path.get_file().get_basename().capitalize()
	return target.get_class()


func build_property_display_name(name: String) -> String:
	return _humanize_identifier(name)


func build_method_display_name(name: String, ace_type: int) -> String:
	var normalized: String = name
	if ace_type == ACEDefinition.ACEType.CONDITION and normalized.begins_with("is_"):
		normalized = normalized.trim_prefix("is_")
	elif ace_type == ACEDefinition.ACEType.EXPRESSION and normalized.begins_with("get_"):
		normalized = normalized.trim_prefix("get_")
	return _humanize_identifier(normalized)


func build_trigger_display_name(signal_name: String) -> String:
	return "On %s" % _humanize_identifier(signal_name)


func _build_overrides(directives: Array[String], exported: bool = false, metadata: Dictionary = {}) -> Dictionary:
	var overrides := {
		"exported": exported,
		"hidden": false,
		"featured": false,
		"deprecated": false,
		"deprecation_message": "",
		"category": "",
		"name": "",
		"description": "",
		"icon": "",
		"forced_ace_type": -1
	}
	var doc_lines: Array[String] = []
	for directive_text in directives:
		var directive: String = directive_text.strip_edges()
		match _annotation_token(directive):
			"":
				doc_lines.append(directive)
			"@ace_hidden":
				overrides["hidden"] = true
			"@ace_featured":
				# The everyday-verb highlight: the picker renders this member bold and
				# floats it to the top of its category. Reserve for a pack's hero verbs.
				overrides["featured"] = true
			"@ace_deprecated":
				# `## @ace_deprecated("Use knock_back() instead")` - the ACE keeps working (existing sheets
				# compile) but is hidden from the picker and flagged on hover, mirroring built-in .deprecated().
				overrides["deprecated"] = true
				overrides["deprecation_message"] = _extract_annotation_value(directive)
			"@ace_category":
				overrides["category"] = _extract_annotation_value(directive)
			"@ace_name":
				overrides["name"] = _extract_annotation_value(directive)
			"@ace_description":
				overrides["description"] = _extract_annotation_value(directive)
			"@ace_icon":
				overrides["icon"] = _extract_annotation_value(directive)
			"@ace_action":
				overrides["forced_ace_type"] = ACEDefinition.ACEType.ACTION
			"@ace_condition":
				overrides["forced_ace_type"] = ACEDefinition.ACEType.CONDITION
			"@ace_expression":
				overrides["forced_ace_type"] = ACEDefinition.ACEType.EXPRESSION
			"@ace_trigger":
				overrides["forced_ace_type"] = ACEDefinition.ACEType.TRIGGER
			"@ace_display_template":
				overrides["display_template"] = _extract_annotation_value(directive)
			"@ace_codegen_template":
				overrides["codegen_template"] = _extract_annotation_value(directive)
			"@ace_param_options":
				# `@ace_param_options(movement horizontal, vertical, angle)` -> the param
				# renders as a dropdown (a Combo) in the params dialog.
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
			"@ace_param_autocomplete":
				# `@ace_param_autocomplete(anim "idle", "run", "jump")` -> the param renders as
				# an EDITABLE suggest combo (autocomplete): the user may type any value AND
				# filter/pick from these. Toggled purely by the behavior's own code (present =
				# on). Values are inserted verbatim, so quote string suggestions in the source.
				# Extract the parens content RAW (unlike _extract_annotation_value, which would
				# strip the trailing quote off the last suggestion).
				var auto_open: int = directive.find("(")
				var auto_close: int = directive.rfind(")")
				var auto_value: String = ""
				if auto_open != -1 and auto_close > auto_open:
					auto_value = directive.substr(auto_open + 1, auto_close - auto_open - 1).strip_edges()
				var auto_split: PackedStringArray = auto_value.split(" ", false, 1)
				if auto_split.size() == 2:
					var param_autocomplete: Dictionary = overrides.get("param_autocomplete", {})
					var auto_values: Array = []
					for raw_suggestion in auto_split[1].split(","):
						if not raw_suggestion.strip_edges().is_empty():
							auto_values.append(raw_suggestion.strip_edges())
					param_autocomplete[auto_split[0].strip_edges()] = auto_values
					overrides["param_autocomplete"] = param_autocomplete
			"@ace_param_hint":
				# `@ace_param_hint(amount expression)` -> param "amount" gets hint "expression"
				# (drives the params dialog: expression fx field, variable_reference dropdown...).
				var hint_parts: PackedStringArray = _extract_annotation_value(directive).split(" ", false)
				if hint_parts.size() >= 2:
					var param_hints: Dictionary = overrides.get("param_hints", {})
					param_hints[hint_parts[0].strip_edges().trim_suffix(",")] = hint_parts[1].strip_edges()
					overrides["param_hints"] = param_hints
			"@ace_param":
				# `@ace_param(amount, hint: expression, options: a|b|c, desc: "Help, with commas.")` -
				# the one-line form of the param_* family: widget hint, fixed dropdown options
				# (|-separated so commas stay free for the key list), editable autocomplete
				# suggestions, and a per-param description, all in a single annotation.
				_parse_param_spec(_extract_annotation_parens_raw(directive), overrides)
			var other_token:
				_note_unknown_annotation(other_token, metadata)
	if str(overrides["description"]).is_empty() and not doc_lines.is_empty():
		# Plain `##` prose above a member IS its description: writing a normal GDScript
		# doc comment is enough; @ace_description is only needed when the picker text
		# should differ from the code documentation.
		overrides["description"] = " ".join(doc_lines).strip_edges()
	return overrides


## Fills the param_hints/param_options/param_autocomplete/param_descriptions channels
## from one `@ace_param(name, key: value, ...)` spec. Keys: hint, options (|-separated),
## autocomplete (|-separated, values verbatim so quoted strings survive), desc.
func _parse_param_spec(spec: String, overrides: Dictionary) -> void:
	var segments: Array[String] = _split_outside_quotes(spec, ",")
	if segments.is_empty():
		return
	var param_name: String = segments[0].strip_edges()
	if param_name.is_empty():
		return
	for segment_index in range(1, segments.size()):
		var segment: String = segments[segment_index]
		var colon_index: int = segment.find(":")
		if colon_index == -1:
			continue
		var key: String = segment.substr(0, colon_index).strip_edges()
		var value: String = segment.substr(colon_index + 1).strip_edges()
		match key:
			"hint":
				var param_hints: Dictionary = overrides.get("param_hints", {})
				param_hints[param_name] = value
				overrides["param_hints"] = param_hints
			"options":
				var param_options: Dictionary = overrides.get("param_options", {})
				param_options[param_name] = _split_pipe_values(value)
				overrides["param_options"] = param_options
			"autocomplete":
				var param_autocomplete: Dictionary = overrides.get("param_autocomplete", {})
				param_autocomplete[param_name] = _split_pipe_values(value)
				overrides["param_autocomplete"] = param_autocomplete
			"desc":
				var param_descriptions: Dictionary = overrides.get("param_descriptions", {})
				param_descriptions[param_name] = value.trim_prefix("\"").trim_suffix("\"")
				overrides["param_descriptions"] = param_descriptions


func _split_pipe_values(value: String) -> Array:
	var output: Array = []
	for raw_entry in value.split("|"):
		if not raw_entry.strip_edges().is_empty():
			output.append(raw_entry.strip_edges())
	return output


## Splits on a separator only outside double quotes, so `desc: "Slow, steady"` keeps
## its comma while the segments around it still split.
func _split_outside_quotes(text: String, separator: String) -> Array[String]:
	var segments: Array[String] = []
	var current: String = ""
	var in_quotes: bool = false
	for index in range(text.length()):
		var character: String = text.substr(index, 1)
		if character == "\"":
			in_quotes = not in_quotes
		if character == separator and not in_quotes:
			segments.append(current)
			current = ""
			continue
		current += character
	segments.append(current)
	return segments


## The raw parenthesized payload of an annotation, quotes preserved (unlike
## _extract_annotation_value, which trims a surrounding quote pair).
func _extract_annotation_parens_raw(text: String) -> String:
	var open_index: int = text.find("(")
	var close_index: int = text.rfind(")")
	if open_index != -1 and close_index > open_index:
		return text.substr(open_index + 1, close_index - open_index - 1).strip_edges()
	return ""


func _extract_annotation_value(text: String) -> String:
	var open_index: int = text.find("(")
	var close_index: int = text.rfind(")")
	if open_index != -1 and close_index > open_index:
		return text.substr(open_index + 1, close_index - open_index - 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	var parts: PackedStringArray = text.split(" ", false, 1)
	if parts.size() > 1:
		return parts[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""


func _parse_signal_name(line: String) -> String:
	var rest: String = line.trim_prefix("signal ").strip_edges()
	var delimiter_index: int = rest.find("(")
	if delimiter_index == -1:
		delimiter_index = rest.length()
	return rest.substr(0, delimiter_index).strip_edges()


func _parse_func_name(line: String) -> String:
	var rest: String = line.trim_prefix("func ").strip_edges()
	var delimiter_index: int = rest.find("(")
	if delimiter_index == -1:
		delimiter_index = rest.length()
	return rest.substr(0, delimiter_index).strip_edges()


func _parse_var_name(line: String) -> String:
	var var_index: int = line.find("var ")
	if var_index == -1:
		return ""
	var rest: String = line.substr(var_index + 4).strip_edges()
	for separator in [":", "=", " "]:
		var separator_index: int = rest.find(separator)
		if separator_index != -1:
			rest = rest.substr(0, separator_index)
			break
	return rest.strip_edges()


func _humanize_identifier(text: String) -> String:
	if text.is_empty():
		return ""
	var builder: String = ""
	for index in range(text.length()):
		var current: String = text.substr(index, 1)
		var previous: String = text.substr(index - 1, 1) if index > 0 else ""
		if current == "_":
			builder += " "
			continue
		if index > 0 and current == current.to_upper() and previous != previous.to_upper() and previous != "_":
			builder += " "
		builder += current
	var words: PackedStringArray = builder.split(" ", false)
	for word_index in range(words.size()):
		var word: String = words[word_index].strip_edges()
		if word.is_empty():
			continue
		words[word_index] = word.substr(0, 1).to_upper() + word.substr(1).to_lower()
	return " ".join(words)
