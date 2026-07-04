@tool
class_name EventSheetACEGenerator
extends RefCounted

## Types considered primitive for editor exposure purposes.
const PRIMITIVE_TYPES := [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]

const COMMON_METHOD_IGNORE := {
	"_get_property_list": true,
	"_get": true,
	"_set": true,
	"_notification": true,
	"get_class": true,
	"get_method_list": true,
	"get_property_list": true,
	"get_script": true,
	"get_signal_list": true,
	"notification": true,
	"to_string": true
}

var _analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
## Set per generate_from_object() call from the provider's @ace_expose_all(node) marker; when "node",
## un-annotated methods get a synthesized $Provider.method() template (node-targeted) instead of the
## owned-instance default - so a behavior needs no per-method @ace_codegen_template.
var _expose_all_mode: String = ""
## Whether the provider being reflected IS a Node: its properties live on the scene node, so
## property reads/writes must target it ($Provider.prop, retargetable) - writing to an owned
## instance would silently change a copy the game never sees.
var _provider_is_node: bool = false
## The registered autoload singleton name when the provider script IS an autoload, else "".
## An autoload is a live global: reflected members must call THE singleton by name - the
## owned-instance form would spawn a second bus, and the $-node form resolves against the
## wrong branch of the tree.
var _autoload_singleton: String = ""
## The $-path token synthesized node-form templates use. The provider DISPLAY id can carry
## spaces ("Bus Fixture" from a class_name-less filename) which is not a valid bare $-path
## and defeats {target} parameterization - so node templates use the class_name, else the
## PascalCase filename.
var _provider_node_name: String = ""


func generate_from_object(target: Object) -> Array[ACEDefinition]:
	var output: Array[ACEDefinition] = []
	if target == null:
		return output
	var script: Script = target.get_script() as Script
	var source_metadata: Dictionary = _analyzer.parse_source_metadata(script)
	_expose_all_mode = str(source_metadata.get("expose_all_mode", ""))
	_provider_is_node = target is Node
	_autoload_singleton = _autoload_name_for(script)
	var provider_id: String = _analyzer.get_provider_id(target, source_metadata)
	_provider_node_name = str(source_metadata.get("class_name", ""))
	if _provider_node_name.is_empty() and script != null and not script.resource_path.is_empty():
		_provider_node_name = script.resource_path.get_file().get_basename().to_pascal_case()
	if _provider_node_name.is_empty():
		_provider_node_name = provider_id
	var signal_overrides: Dictionary = source_metadata.get("signals", {})
	var property_overrides: Dictionary = source_metadata.get("properties", {})
	var method_overrides: Dictionary = source_metadata.get("methods", {})

	for signal_info in target.get_signal_list():
		var signal_name: String = str(signal_info.get("name", ""))
		if signal_name.is_empty() or (script != null and not signal_overrides.has(signal_name)):
			continue
		var overrides: Dictionary = signal_overrides.get(signal_name, {})
		if bool(overrides.get("hidden", false)):
			continue
		var signal_definition: ACEDefinition = _build_signal_definition(provider_id, signal_name, signal_info, overrides)
		_apply_deprecation_metadata(signal_definition, overrides)
		output.append(signal_definition)

	for property_info in target.get_property_list():
		var property_name: String = str(property_info.get("name", ""))
		if property_name.is_empty() or (script != null and not property_overrides.has(property_name)):
			continue
		var property_overrides_entry: Dictionary = property_overrides.get(property_name, {})
		if bool(property_overrides_entry.get("hidden", false)):
			continue
		if not bool(property_overrides_entry.get("exported", false)):
			continue
		var property_definitions: Array[ACEDefinition] = _build_property_definitions(provider_id, property_name, property_info, property_overrides_entry)
		for property_definition: ACEDefinition in property_definitions:
			_apply_deprecation_metadata(property_definition, property_overrides_entry)
		output.append_array(property_definitions)

	for method_info in target.get_method_list():
		var method_name: String = str(method_info.get("name", ""))
		if method_name.is_empty() or method_name.begins_with("_") or COMMON_METHOD_IGNORE.has(method_name):
			continue
		if script != null and not method_overrides.has(method_name):
			continue
		var method_entry_overrides: Dictionary = method_overrides.get(method_name, {})
		if bool(method_entry_overrides.get("hidden", false)):
			continue
		var method_definition: ACEDefinition = _build_method_definition(provider_id, method_name, method_info, method_entry_overrides)
		_apply_deprecation_metadata(method_definition, method_entry_overrides)
		output.append(method_definition)
	# Provider description derives from the script's top doc comment (zero-config addons).
	var class_description: String = str(source_metadata.get("class_description", ""))
	if not class_description.is_empty():
		for definition in output:
			definition.metadata["provider_description"] = class_description
	var provider_tags: Array = source_metadata.get("tags", [])
	if not provider_tags.is_empty():
		for definition in output:
			definition.metadata["tags"] = provider_tags.duplicate()
	return output


## Applies the @ace_display_template / @ace_codegen_template overrides onto a definition's
## metadata (the picker/rows read display_template; codegen + tooltips read codegen_template).
static func _apply_template_overrides(definition: ACEDefinition, overrides: Dictionary) -> void:
	var display_template: String = str(overrides.get("display_template", ""))
	if not display_template.is_empty():
		definition.metadata["display_template"] = display_template
	var codegen_template: String = str(overrides.get("codegen_template", ""))
	if not codegen_template.is_empty():
		definition.metadata["codegen_template"] = codegen_template
	_parameterize_node_target(definition)


## Behavior-pack ACEs author their codegen as "$<Node>.method()" - the conventional behavior-node
## path. To let a sheet target the SAME behavior wherever it actually lives (e.g. $Player/WeaponKit,
## not only a direct child literally named WeaponKit), turn that leading "$<Node>." into a
## configurable {target} param defaulting to the authored path. The default substitutes back to the
## identical string, so existing sheets are byte-for-byte unchanged (drift stays 0); the user retargets
## via $-autocomplete. This is the "the ACE acts on the object instance you picked" model,
## expressed as a Godot node path. Only a bare $Identifier prefix is parameterized - $"Quoted",
## %Unique, and multi-segment $A/B paths are already explicit and stay verbatim.
static func _parameterize_node_target(definition: ACEDefinition) -> void:
	if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
		return
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if not template.begins_with("$"):
		return
	var dot: int = template.find(".")
	if dot < 2:
		return
	var node_ref: String = template.substr(0, dot)
	var bare: String = node_ref.substr(1)
	if bare.is_empty() or bare.contains("/") or bare.contains("\"") or bare.contains(" ") or bare.contains("%"):
		return
	var first_char: String = bare.substr(0, 1)
	if not (first_char == "_" or first_char.to_lower() != first_char.to_upper()):
		return
	# Avoid colliding with a method param literally named "target" (e.g. spring_host_scale(target)):
	# fall back to "on_node" so the injected node path and the method's own arg stay distinct.
	var node_param_id: String = "target"
	for existing_param in definition.parameters:
		if str((existing_param as Dictionary).get("id", "")) == node_param_id:
			node_param_id = "on_node"
			break
	definition.metadata["codegen_template"] = "{%s}.%s" % [node_param_id, template.substr(dot + 1)]
	var target_param: Dictionary = {
		"id": node_param_id,
		"display_name": "On node",
		"description": "Which node carries this behavior (default %s). Pick or type a node path - e.g. $Player/WeaponKit." % node_ref,
		"type": TYPE_STRING,
		"default_value": node_ref,
		"property_hint": PROPERTY_HINT_NONE,
		"hint": "expression",
		"hint_string": "",
		"widget_hint": "",
		"options": [],
		"autocomplete": []
	}
	var reordered: Array = [target_param]
	reordered.append_array(definition.parameters)
	definition.parameters = reordered


## Carries an addon's `## @ace_deprecated("…")` into the definition's metadata, matching how a built-in's
## .deprecated() flows via the adapter - so the picker hides it and the hover flags it, while the ACE keeps
## compiling in sheets that already use it (the compatibility covenant). Also carries the
## `## @ace_featured` highlight (a built-in's .featured() twin): the picker renders
## featured verbs bold and floats them to the top of their category.
static func _apply_deprecation_metadata(definition: ACEDefinition, overrides: Dictionary) -> void:
	if definition == null:
		return
	if bool(overrides.get("featured", false)):
		definition.metadata["featured"] = true
	if not bool(overrides.get("deprecated", false)):
		return
	definition.metadata["deprecated"] = true
	var message: String = str(overrides.get("deprecation_message", "")).strip_edges()
	# Parenthesised (not "[Deprecated]") so it survives a rich (BBCode) hover/tooltip - see deprecation_note().
	var note: String = "(Deprecated)"
	if not message.is_empty():
		note += " " + message
	definition.metadata["deprecation_note"] = note


func _build_signal_definition(provider_id: String, signal_name: String, signal_info: Dictionary, overrides: Dictionary) -> ACEDefinition:
	var definition := ACEDefinition.new()
	definition.provider_id = provider_id
	definition.id = "signal:%s" % signal_name
	definition.display_name = _string_override(overrides, "name", _analyzer.build_trigger_display_name(signal_name))
	definition.category = _string_override(overrides, "category", "Signals")
	definition.ace_type = ACEDefinition.ACEType.TRIGGER
	definition.description = _string_override(overrides, "description", "Signal trigger generated from gameplay code.")
	definition.parameters = _build_parameter_definitions(signal_info.get("args", []), overrides)
	definition.return_type = TYPE_NIL
	definition.icon = _string_override(overrides, "icon", "signal")
	definition.metadata = {
		"semantic_source": "reflection",
		"source_kind": "signal",
		"source_name": signal_name,
		"display_template": definition.display_name,
		"trigger_state_model": "captured_context",
		"trigger_context_params": definition.parameters.duplicate(true)
	}
	# Signals are triggers, not directly editor-exposed as inspector parameters.
	definition.editor_exposed = false
	_apply_template_overrides(definition, overrides)
	return definition


func _build_property_definitions(provider_id: String, property_name: String, property_info: Dictionary, overrides: Dictionary) -> Array[ACEDefinition]:
	var output: Array[ACEDefinition] = []
	var property_type: int = int(property_info.get("type", TYPE_NIL))
	var display_name: String = _string_override(overrides, "name", _analyzer.build_property_display_name(property_name))
	var category: String = _string_override(overrides, "category", EventSheetCategoryInference.infer_category(property_name, ACEDefinition.ACEType.EXPRESSION, property_type))
	var description: String = _string_override(overrides, "description", "Gameplay property generated from an exported variable.")
	var icon_name: String = _string_override(overrides, "icon", "property")

	var expression_definition := ACEDefinition.new()
	expression_definition.provider_id = provider_id
	expression_definition.id = "property:%s" % property_name
	expression_definition.display_name = display_name
	expression_definition.category = category
	expression_definition.ace_type = ACEDefinition.ACEType.EXPRESSION
	expression_definition.description = description
	expression_definition.return_type = property_type
	expression_definition.icon = icon_name
	expression_definition.metadata = {
		"semantic_source": "reflection",
		"source_kind": "property",
		"source_name": property_name,
		"display_template": display_name
	}
	# Exported properties are editor-exposed: their value can be overridden in the inspector.
	expression_definition.editor_exposed = bool(overrides.get("editor_exposed", _property_is_exposable(property_type)))
	expression_definition.property_hint = _infer_property_hint(property_type, overrides)
	expression_definition.hint_string = _string_override(overrides, "hint_string", "")
	expression_definition.widget_hint = _string_override(overrides, "widget_hint", "")
	expression_definition.category_override = _string_override(overrides, "category_override", "")
	# Real code behind the picker entry (the covenant: nothing may compile to nothing).
	# Inserted into expressions as-is for owned instances; the node form is parameterized
	# to {target} by _parameterize_node_target and re-substitutes its default on insert.
	# An explicit @ace_codegen_template override still wins inside _apply_template_overrides.
	expression_definition.metadata["codegen_template"] = _property_access(provider_id, property_name)
	_apply_template_overrides(expression_definition, overrides)
	output.append(expression_definition)

	var set_definition := _build_property_action_definition(provider_id, property_name, display_name, category, "set", "Set %s" % display_name, TYPE_NIL)
	output.append(set_definition)
	if property_type in [TYPE_INT, TYPE_FLOAT]:
		output.append(_build_property_action_definition(provider_id, property_name, display_name, category, "add", "Add To %s" % display_name, TYPE_NIL, "amount"))
		output.append(_build_property_action_definition(provider_id, property_name, display_name, category, "subtract", "Subtract From %s" % display_name, TYPE_NIL, "amount"))
	return output


func _build_property_action_definition(provider_id: String, property_name: String, display_name: String, category: String, prefix: String, action_name: String, return_type: int, parameter_name: String = "value") -> ACEDefinition:
	var definition := ACEDefinition.new()
	definition.provider_id = provider_id
	definition.id = "%s:%s" % [prefix, property_name]
	definition.display_name = action_name
	definition.category = category
	definition.ace_type = ACEDefinition.ACEType.ACTION
	definition.description = "Generated property action for %s." % display_name
	definition.parameters = [
		{
			"id": parameter_name,
			"display_name": _analyzer.build_property_display_name(parameter_name),
			"type": TYPE_NIL,
			"default_value": "0"
		}
	]
	definition.return_type = return_type
	definition.icon = "property_action"
	definition.metadata = {
		"semantic_source": "reflection",
		"source_kind": "property_action",
		"source_name": property_name,
		"display_template": "%s {%s}" % [action_name, parameter_name]
	}
	# Property writes used to carry NO template and compiled to EMPTY output (a silent
	# no-op). Synthesize the real assignment: node providers write through the behavior
	# node (parameterized to a retargetable {target} param below), everything else
	# through the compiler-declared owned instance.
	var operator: String = "=" if prefix == "set" else ("+=" if prefix == "add" else "-=")
	definition.metadata["codegen_template"] = "%s %s {%s}" % [_property_access(provider_id, property_name), operator, parameter_name]
	_parameterize_node_target(definition)
	return definition


## The code path a reflected property compiles through: the autoload singleton by name
## when the provider is one, the behavior node for Node providers (and
## @ace_expose_all(node) providers), the compiler-declared owned instance
## (__eventsheet_provider_<Class>) for RefCounted/Resource utility classes.
func _property_access(provider_id: String, property_name: String) -> String:
	if not _autoload_singleton.is_empty():
		return "%s.%s" % [_autoload_singleton, property_name]
	if _provider_is_node or _expose_all_mode == "node":
		return "$%s.%s" % [_provider_node_name, property_name]
	return "__eventsheet_provider_%s.%s" % [provider_id, property_name]


## The autoload entry whose script path matches this provider script, or "". Resolved per
## generate_from_object call so the same generator instance serves scans and tests alike.
static func _autoload_name_for(script: Script) -> String:
	if script == null or script.resource_path.is_empty():
		return ""
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property_info.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		if str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*") == script.resource_path:
			return setting_name.trim_prefix("autoload/")
	return ""


func _build_method_definition(provider_id: String, method_name: String, method_info: Dictionary, overrides: Dictionary) -> ACEDefinition:
	var parameter_definitions: Array = _build_parameter_definitions(method_info.get("args", []), overrides)
	var parameter_types: Array = []
	for parameter_definition in parameter_definitions:
		parameter_types.append(parameter_definition.get("type", TYPE_NIL))
	var return_info: Variant = method_info.get("return", {})
	var return_type: int = TYPE_NIL
	if return_info is Dictionary:
		return_type = int((return_info as Dictionary).get("type", TYPE_NIL))
	var ace_type: int = _resolve_method_ace_type(return_type, overrides)
	var display_name: String = _string_override(overrides, "name", _analyzer.build_method_display_name(method_name, ace_type))
	var category: String = _string_override(overrides, "category", EventSheetCategoryInference.infer_category(method_name, ace_type, return_type, parameter_types))
	var definition := ACEDefinition.new()
	definition.provider_id = provider_id
	definition.id = "method:%s" % method_name
	definition.display_name = display_name
	definition.category = category
	definition.ace_type = ace_type
	definition.description = _string_override(overrides, "description", "Gameplay capability generated from a script method.")
	definition.parameters = parameter_definitions
	definition.return_type = return_type
	definition.icon = _string_override(overrides, "icon", _icon_for_ace_type(ace_type))
	definition.metadata = {
		"semantic_source": "reflection",
		"source_kind": "method",
		"source_name": method_name,
		"display_template": _build_method_display_template(display_name, parameter_definitions)
	}
	# Methods with primitive params (non-signal, non-hidden) can be editor-exposed.
	definition.editor_exposed = bool(overrides.get("editor_exposed", _method_is_exposable(ace_type, return_type, parameter_definitions)))
	definition.property_hint = int(overrides.get("property_hint", PROPERTY_HINT_NONE))
	definition.hint_string = _string_override(overrides, "hint_string", "")
	definition.widget_hint = _string_override(overrides, "widget_hint", "")
	definition.category_override = _string_override(overrides, "category_override", "")
	# A registered autoload is a live global: synthesize the singleton call by name - the
	# owned-instance bake would spawn a SECOND bus, and the $-node form resolves the wrong
	# branch. Otherwise, @ace_expose_all(node) synthesizes the node-targeted call so no
	# per-method @ace_codegen_template is needed; _parameterize_node_target (inside
	# _apply_template_overrides) then turns the leading $Provider. into a configurable
	# {target} "On node" param. An explicit override still wins below.
	if str(definition.metadata.get("codegen_template", "")).is_empty():
		var __arg_ids: PackedStringArray = PackedStringArray()
		for __pd in parameter_definitions:
			__arg_ids.append("{%s}" % str((__pd as Dictionary).get("id", "")))
		if not _autoload_singleton.is_empty():
			definition.metadata["codegen_template"] = "%s.%s(%s)" % [_autoload_singleton, method_name, ", ".join(__arg_ids)]
		elif _expose_all_mode == "node":
			definition.metadata["codegen_template"] = "$%s.%s(%s)" % [_provider_node_name, method_name, ", ".join(__arg_ids)]
	_apply_template_overrides(definition, overrides)
	return definition


func _resolve_method_ace_type(return_type: int, overrides: Dictionary) -> int:
	var forced_ace_type: int = int(overrides.get("forced_ace_type", -1))
	if forced_ace_type >= 0:
		return forced_ace_type
	if return_type == TYPE_BOOL:
		return ACEDefinition.ACEType.CONDITION
	if return_type == TYPE_NIL:
		return ACEDefinition.ACEType.ACTION
	return ACEDefinition.ACEType.EXPRESSION


func _build_parameter_definitions(raw_args: Variant, overrides: Dictionary = {}) -> Array:
	var output: Array = []
	if not (raw_args is Array):
		return output
	var param_overrides: Dictionary = overrides.get("params", {})
	var param_hints: Dictionary = overrides.get("param_hints", {})
	var param_options: Dictionary = overrides.get("param_options", {})
	var param_autocomplete: Dictionary = overrides.get("param_autocomplete", {})
	var param_descriptions: Dictionary = overrides.get("param_descriptions", {})
	for argument_info in raw_args:
		if not (argument_info is Dictionary):
			continue
		var argument_dict: Dictionary = argument_info
		var argument_name: String = str(argument_dict.get("name", ""))
		if argument_name.is_empty():
			continue
		var parameter_override: Dictionary = param_overrides.get(argument_name, {})
		if param_hints.has(argument_name) and not parameter_override.has("hint"):
			parameter_override = parameter_override.duplicate()
			parameter_override["hint"] = str(param_hints[argument_name])
		if param_options.has(argument_name) and not parameter_override.has("options"):
			parameter_override = parameter_override.duplicate()
			parameter_override["options"] = param_options[argument_name]
		if param_autocomplete.has(argument_name) and not parameter_override.has("autocomplete"):
			parameter_override = parameter_override.duplicate()
			parameter_override["autocomplete"] = param_autocomplete[argument_name]
		var param_type: int = int(parameter_override.get("type", argument_dict.get("type", TYPE_NIL)))
		var hint_value: String = str(parameter_override.get("hint", ""))
		if hint_value.is_empty():
			hint_value = _convention_hint(argument_name)
		output.append({
			"id": argument_name,
			"display_name": str(parameter_override.get("display_name", _analyzer.build_property_display_name(argument_name))),
			"description": str(parameter_override.get("description", param_descriptions.get(argument_name, ""))),
			"type": param_type,
			"default_value": parameter_override.get("default_value", _default_value_for_type(param_type)),
			"property_hint": int(parameter_override.get("property_hint", PROPERTY_HINT_NONE)),
			"hint": hint_value,
			"hint_string": str(parameter_override.get("hint_string", "")),
			"widget_hint": str(parameter_override.get("widget_hint", "")),
			"options": _normalize_options_to_key_label(parameter_override.get("options", [])),
			"autocomplete": _normalize_autocomplete(parameter_override.get("autocomplete", []))
		})
	return output


## Derives a widget hint from a parameter's NAME when no annotation set one, so common
## params get the right picker with zero ceremony. Any explicit hint (long or one-line
## form) wins; the conventions are deliberately narrow to avoid surprising matches.
func _convention_hint(argument_name: String) -> String:
	if argument_name == "color" or argument_name == "colour" or argument_name.ends_with("_color") or argument_name.ends_with("_colour"):
		return "color"
	if argument_name == "animation" or argument_name == "anim" or argument_name.ends_with("_anim") or argument_name.ends_with("_animation"):
		return "animation_reference"
	if argument_name == "signal_name" or argument_name.ends_with("_signal"):
		return "signal_reference"
	if argument_name == "scene_path" or argument_name.ends_with("_scene"):
		return "scene_path"
	if argument_name == "audio_path" or argument_name.ends_with("_audio"):
		return "audio_path"
	return ""


func _build_method_display_template(display_name: String, parameters: Array) -> String:
	if parameters.is_empty():
		return display_name
	var parts: Array[String] = [display_name]
	for parameter_definition in parameters:
		parts.append("{%s}" % str(parameter_definition.get("id", "value")))
	return " ".join(parts)


func _default_value_for_type(value_type: int) -> String:
	match value_type:
		TYPE_INT:
			return "0"
		TYPE_FLOAT:
			return "0.0"
		TYPE_BOOL:
			return "false"
		_:
			return ""


func _icon_for_ace_type(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "expression"
		ACEDefinition.ACEType.TRIGGER:
			return "trigger"
		_:
			return "action"


## Returns true when a method ACE is eligible for editor parameter exposure.
## Conditions and actions with all-primitive parameters are exposable.
## Expressions are only exposable when their return type is a primitive.
## Triggers are never editor-exposed.
func _method_is_exposable(ace_type: int, return_type: int, params: Array) -> bool:
	if ace_type == ACEDefinition.ACEType.TRIGGER:
		return false
	if ace_type == ACEDefinition.ACEType.EXPRESSION:
		if return_type not in PRIMITIVE_TYPES:
			return false
	for param in params:
		if not (param is Dictionary):
			return false
		var ptype: int = int((param as Dictionary).get("type", TYPE_NIL))
		if ptype not in PRIMITIVE_TYPES:
			return false
	return true


func _property_is_exposable(property_type: int) -> bool:
	return property_type in PRIMITIVE_TYPES


## Infer a PropertyHint for the given Variant type.
## Callers can pass a "property_hint" override in the overrides dict
## (e.g. PROPERTY_HINT_RANGE for a bounded integer).
func _infer_property_hint(value_type: int, overrides: Dictionary) -> int:
	var hint_override: int = int(overrides.get("property_hint", -1))
	if hint_override >= 0:
		return hint_override
	# Default hints by type; extend here as richer widgets are added.
	match value_type:
		TYPE_INT, TYPE_FLOAT:
			return PROPERTY_HINT_NONE
		TYPE_STRING:
			return PROPERTY_HINT_NONE
		_:
			return PROPERTY_HINT_NONE


func _string_override(overrides: Dictionary, key: String, default_value: String) -> String:
	var resolved: String = str(overrides.get(key, ""))
	return resolved if not resolved.is_empty() else default_value


func _normalize_options_to_key_label(raw_options: Variant) -> Array:
	var output: Array = []
	if not (raw_options is Array):
		return output
	for option_entry in raw_options:
		if option_entry is Dictionary:
			var option_dict: Dictionary = option_entry as Dictionary
			var option_key: String = str(option_dict.get("key", ""))
			if option_key.is_empty():
				option_key = str(option_dict.get("value", ""))
			if option_key.is_empty():
				option_key = str(option_dict.get("label", ""))
			if option_key.is_empty():
				continue
			output.append({
				"key": option_key,
				"label": str(option_dict.get("label", option_key))
			})
			continue
		var scalar: String = str(option_entry)
		if scalar.is_empty():
			continue
		output.append({"key": scalar, "label": scalar})
	return output


## Autocomplete suggestions are a flat list of insert-verbatim strings (an editable combo,
## not a key/label dropdown). Mirrors _normalize_options_to_key_label's tolerance.
func _normalize_autocomplete(raw_suggestions: Variant) -> Array:
	var output: Array = []
	if not (raw_suggestions is Array):
		return output
	for suggestion in raw_suggestions:
		var text: String = str(suggestion).strip_edges()
		if not text.is_empty():
			output.append(text)
	return output
