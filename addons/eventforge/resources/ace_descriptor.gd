# EventForge — ACEDescriptor resource
# Defines a registerable trigger, condition, action, or expression.
@tool
extends Resource
class_name ACEDescriptor

enum ACEType {
	TRIGGER,
	CONDITION,
	ACTION,
	EXPRESSION
}

@export var ace_type: ACEType = ACEType.ACTION
@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var display_name: String = ""
@export var list_name: String = ""
@export var listName: String = "" # event-sheet-style alias.
@export var description: String = ""
@export_multiline var display_text: String = ""
@export_multiline var displayText: String = "" # event-sheet-style alias.
@export var category: String = ""
## Godot class/namespace this ACE belongs to (e.g. "CharacterBody2D", "Area2D", "Node").
## When set, the ACE picker groups the entry under this node type instead of its category.
@export var node_type: String = ""
## Stateful conditions ("Every X seconds"/latches): a class member the compiler
## declares per applied instance ({uid} is baked fresh at apply), plus lines emitted
## before the if (prelude) and just inside it (on_true). Params substitute like the
## main template.
var member_template: String = ""
var codegen_prelude: String = ""
var codegen_on_true: String = ""
@export var nodeType: String = "" # event-sheet-style alias for node_type.
@export var params: Array[ACEParam] = []
@export var signal_name: String = ""
@export var return_type: int = TYPE_NIL
@export var codegen_template: String = ""

## Curated poll -> signal-twin map (the shared "reactivity" datum): the handful of polling CONDITIONS
## that have a clean reactive trigger, so the editor can nudge "react to a signal instead of checking
## this every frame". Keyed "<provider>::<ace_id>" -> {trigger_id, trigger_name}. Deliberately omits
## conditions with NO real signal twin — is_on_floor (Godot has no floor signal) and held input-action
## polls (no per-action signal) — because suggesting one there would be cargo-cult, not idiomatic.
const REACTS_TO: Dictionary = {
	"Core::IsTimerStopped": {"trigger_id": "OnTimeout", "trigger_name": "On Timeout"},
	"Core::OverlapsBody": {"trigger_id": "OnBodyEntered", "trigger_name": "On Body Entered"},
	"Core::OverlapsArea": {"trigger_id": "OnAreaEntered", "trigger_name": "On Area Entered"},
	"Core::HasOverlappingBodies": {"trigger_id": "OnBodyEntered", "trigger_name": "On Body Entered"},
	"Core::HasOverlappingAreas": {"trigger_id": "OnAreaEntered", "trigger_name": "On Area Entered"},
	"Core::IsAnimationPlaying": {"trigger_id": "OnAnimationFinished", "trigger_name": "On Animation Finished"},
	"Core::IsSpriteAnimationPlaying": {"trigger_id": "OnAnimationFinished", "trigger_name": "On Animation Finished"},
	"Core::IsButtonPressed": {"trigger_id": "OnButtonPressed", "trigger_name": "On Pressed"},
}

## The reactive trigger that replaces a polling condition, or {} if none. The single lookup the picker
## tip — and later the Project Doctor / inline hint — all read, so the nudge is defined once.
static func reactive_alternative(provider_id: String, ace_id: String) -> Dictionary:
	return REACTS_TO.get("%s::%s" % [provider_id, ace_id], {})

## Returns the display label used in ACE pickers.
func get_list_name() -> String:
	if not list_name.is_empty():
		return list_name
	if not listName.is_empty():
		return listName
	if not display_name.is_empty():
		return display_name
	return ace_id

## Returns the template used for human-friendly summaries.
func get_display_text() -> String:
	if not display_text.is_empty():
		return display_text
	if not displayText.is_empty():
		return displayText
	return get_list_name()

## Sets the plain-language description and returns self, so a module authors help INLINE, right next to the
## descriptor: `F.make_descriptor(...).described("What it does, in friendly English.")`. This keeps every
## ACE's help in its own file — the same self-contained way custom addons use `## @ace_description(...)` —
## so behaviour packs are easy to author, integrate, and update without touching any central registry.
func described(text: String) -> ACEDescriptor:
	description = text
	return self

## Returns params dictionary pre-populated from descriptor defaults.
func build_default_params() -> Dictionary:
	var output: Dictionary = {}
	for param: ACEParam in params:
		if param == null:
			continue
		var key: String = param.id
		if key.is_empty():
			key = param.name
		if key.is_empty():
			continue
		output[key] = param.get_initial_value()
	return output

## Formats display_text/list_name with values from params.
func format_display(params_dict: Dictionary) -> String:
	var template: String = get_display_text()
	if template.is_empty():
		return ace_id
	var output: String = template
	for i: int in range(params.size()):
		var param: ACEParam = params[i]
		if param == null:
			continue
		var key: String = param.id
		if key.is_empty():
			key = param.name
		if key.is_empty():
			continue
		var value: Variant = params_dict.get(key, param.get_initial_value())
		output = output.replace("{%d}" % i, str(value))
		output = output.replace("{%s}" % key, str(value))
	return output
