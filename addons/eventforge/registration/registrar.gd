@tool
class_name EventForgeRegistrar
extends RefCounted

## The typed, autocompleting alternative to the `## @ace_*` comment dialect.
##
## A provider script may declare a static hook:
##
##     static func _eventforge_register(reg: EventForgeRegistrar) -> void:
##         reg.pack_category("Health")
##         reg.action("heal").name("Heal")\
##             .description("Restores health by an amount.")\
##             .template("health += {amount}")\
##             .param("amount", {"hint": EventForgeRegistrar.EXPRESSION})
##
## The scanner calls the hook while reflecting the script and merges the result into
## the same metadata the comment dialect produces, so both forms yield identical
## ACE definitions (the equivalence is test-pinned). Because every method here is
## real GDScript, the script editor autocompletes the whole vocabulary and a typo
## is a compile error instead of a silently ignored comment.
##
## Registrar calls ANNOTATE existing members (funcs, signals, exported vars); they
## do not create members. A member configured here wins over its own comment
## annotations field by field.

## Widget-hint vocabulary for param() specs (matches the params dialog).
const EXPRESSION := "expression"
const VARIABLE := "variable_reference"
const COLOR := "color"
const KEY_CAPTURE := "key_capture"
const AUDIO_PATH := "audio_path"
const SCENE_PATH := "scene_path"
const ANIMATION := "animation_reference"
const SIGNAL_REFERENCE := "signal_reference"
const METHOD_REFERENCE := "method_reference"
const PROPERTY_REFERENCE := "property_reference"

## member name -> {"section": "signals"|"methods"|"properties", "overrides": {set keys only}}
var members: Dictionary = {}
## Pack-wide defaults, same precedence as class-level @ace_category/@ace_icon.
var pack_category_value: String = ""
var pack_icon_value: String = ""
var pack_tags: Array = []


## Annotates a method as an Action (void verbs).
func action(member_name: String) -> EventForgeRegistrarMember:
	return _member(member_name, "methods", ACEDefinition.ACEType.ACTION)


## Annotates a method as a Condition (bool tests).
func condition(member_name: String) -> EventForgeRegistrarMember:
	return _member(member_name, "methods", ACEDefinition.ACEType.CONDITION)


## Annotates a method as an Expression (value getters).
func expression(member_name: String) -> EventForgeRegistrarMember:
	return _member(member_name, "methods", ACEDefinition.ACEType.EXPRESSION)


## Annotates a signal as a Trigger.
func trigger(signal_name: String) -> EventForgeRegistrarMember:
	return _member(signal_name, "signals", ACEDefinition.ACEType.TRIGGER)


## Annotates an @export var (read/set/add ACEs derive from it).
func property(property_name: String) -> EventForgeRegistrarMember:
	return _member(property_name, "properties", -1)


## Annotates a method without forcing its ACE type (return type decides).
func member(member_name: String) -> EventForgeRegistrarMember:
	return _member(member_name, "methods", -1)


## Pack-wide default category (member-level values win). Chainable.
func pack_category(text: String) -> EventForgeRegistrar:
	pack_category_value = text
	return self


## Pack-wide default picker icon (member-level values win). Chainable.
func pack_icon(icon_path: String) -> EventForgeRegistrar:
	pack_icon_value = icon_path
	return self


## Provider search tags, same as class-level @ace_tags. Chainable.
func tags(tag_list: Array) -> EventForgeRegistrar:
	for tag in tag_list:
		if not str(tag).strip_edges().is_empty() and not pack_tags.has(str(tag).strip_edges()):
			pack_tags.append(str(tag).strip_edges())
	return self


func _member(member_name: String, section: String, forced_ace_type: int) -> EventForgeRegistrarMember:
	var entry: Dictionary = members.get(member_name, {"section": section, "overrides": {}})
	entry["section"] = section
	if forced_ace_type >= 0:
		(entry["overrides"] as Dictionary)["forced_ace_type"] = forced_ace_type
	members[member_name] = entry
	var builder := EventForgeRegistrarMember.new()
	builder.overrides = entry["overrides"]
	return builder


## Fluent per-member builder. Every setter records ONLY the keys it was asked to set,
## so merging onto comment-dialect overrides replaces exactly what the author wrote.
class EventForgeRegistrarMember:
	extends RefCounted

	var overrides: Dictionary = {}


	func name(text: String) -> EventForgeRegistrarMember:
		overrides["name"] = text
		return self


	func category(text: String) -> EventForgeRegistrarMember:
		overrides["category"] = text
		return self


	func description(text: String) -> EventForgeRegistrarMember:
		overrides["description"] = text
		return self


	func icon(icon_path: String) -> EventForgeRegistrarMember:
		overrides["icon"] = icon_path
		return self


	## The emitted GDScript, with {param} placeholders (same rules as
	## @ace_codegen_template: {uid} instance locals, {target.} optional prefix).
	func template(codegen: String) -> EventForgeRegistrarMember:
		overrides["codegen_template"] = codegen
		return self


	## The picker row phrasing, with {param} placeholders.
	func display(display_text: String) -> EventForgeRegistrarMember:
		overrides["display_template"] = display_text
		return self


	func hidden() -> EventForgeRegistrarMember:
		overrides["hidden"] = true
		return self


	func deprecated(message: String = "") -> EventForgeRegistrarMember:
		overrides["deprecated"] = true
		overrides["deprecation_message"] = message
		return self


	## Everything about one parameter: {"hint": ..., "options": [...],
	## "autocomplete": [...], "desc": ...} - any subset. Chainable per param.
	func param(param_name: String, spec: Dictionary) -> EventForgeRegistrarMember:
		if spec.has("hint"):
			var param_hints: Dictionary = overrides.get("param_hints", {})
			param_hints[param_name] = str(spec["hint"])
			overrides["param_hints"] = param_hints
		if spec.has("options"):
			var param_options: Dictionary = overrides.get("param_options", {})
			param_options[param_name] = (spec["options"] as Array).duplicate()
			overrides["param_options"] = param_options
		if spec.has("autocomplete"):
			var param_autocomplete: Dictionary = overrides.get("param_autocomplete", {})
			param_autocomplete[param_name] = (spec["autocomplete"] as Array).duplicate()
			overrides["param_autocomplete"] = param_autocomplete
		if spec.has("desc"):
			var param_descriptions: Dictionary = overrides.get("param_descriptions", {})
			param_descriptions[param_name] = str(spec["desc"])
			overrides["param_descriptions"] = param_descriptions
		return self
