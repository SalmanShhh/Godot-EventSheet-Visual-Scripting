# EventForge - ACEDescriptor resource
# Defines a registerable trigger, condition, action, or expression.
@tool
class_name ACEDescriptor
extends Resource

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
## main template. Prefer the fluent `.stateful(member, prelude, on_true)`.
var member_template: String = ""
var codegen_prelude: String = ""
var codegen_on_true: String = ""
## Emitted after the event's whole body (actions + sub-events) - the "run finished" hook
## stateful gates like Once At A Time reset on.
var codegen_on_exit: String = ""
## Edge-gate conditions (Trigger Once style): the compiler HOISTS this term to the END of the emitted
## `and` chain regardless of which condition cell it occupies, so short-circuiting guarantees it is
## reached exactly when the row's other conditions are true - the property a "was I reached last
## tick?" state test depends on. Set via the fluent `.evaluated_last()`.
var evaluate_last: bool = false
## Rich-text declaration (see rich_text_when): the sheet renders this ACE's string params
## as BBCode effects when the param named rich_when_param holds exactly rich_when_value.
## Blank = never value-triggered rich (a bbcode_text param hint still counts as rich).
var rich_when_param: String = ""
var rich_when_value: String = ""
@export var nodeType: String = "" # event-sheet-style alias for node_type.
@export var params: Array[ACEParam] = []
@export var signal_name: String = ""
@export var return_type: int = TYPE_NIL
@export var codegen_template: String = ""
## Deprecation (a stability covenant): a deprecated ACE KEEPS COMPILING so existing sheets never
## break, but it is hidden from the picker (can't be added anew) and flagged on hover with its suggested
## replacement. Set inline via `.deprecated("Use X instead", "Provider::NewId")`. replacement_ace_id is the
## "<provider>::<ace_id>" of what to use instead (optional).
@export var is_deprecated: bool = false
@export var deprecation_message: String = ""
@export var replacement_ace_id: String = ""
## Featured everyday verb: the picker renders it bold and floats it to the top of its
## category (the event-sheet "highlight"). Set inline via `.featured()`.
@export var is_featured: bool = false

## Curated poll -> signal-twin map (the shared "reactivity" datum): the handful of polling CONDITIONS
## that have a clean reactive trigger, so the editor can nudge "react to a signal instead of checking
## this every frame". Keyed "<provider>::<ace_id>" -> {trigger_id, trigger_name}. Deliberately omits
## conditions with NO real signal twin - is_on_floor (Godot has no floor signal) and held input-action
## polls (no per-action signal) - because suggesting one there would be cargo-cult, not idiomatic.
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
## tip - and later the Project Doctor / inline hint - all read, so the nudge is defined once.
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
## ACE's help in its own file - the same self-contained way custom addons use `## @ace_description(...)` -
## so behaviour packs are easy to author, integrate, and update without touching any central registry.
func described(text: String) -> ACEDescriptor:
	description = text
	return self


## Marks this ACE as a FEATURED everyday verb and returns self, so it chains like
## .described(): `F.make_descriptor(...).featured()`. The picker renders featured verbs
## bold and floats them to the top of their category. Reserve it for a pack's hero
## verbs - featuring everything features nothing.
func featured() -> ACEDescriptor:
	is_featured = true
	return self


## Declares a STATEFUL condition in one chained call: `member` is the class-level state the compiler
## synthesizes per applied instance (may span several lines - Trigger Once ships a helper function
## beside its state var); `prelude` is a single statement emitted every tick before the if; `on_true`
## a single statement emitted just inside it. All three receive the same {uid} and {param}
## substitutions as the main template. Chains like .described():
## `F.make_descriptor(...).stateful("var __t_{uid}: float = 0.0", "__t_{uid} += delta")`.
func stateful(member: String, prelude: String = "", on_true: String = "", on_exit: String = "") -> ACEDescriptor:
	member_template = member
	codegen_prelude = prelude
	codegen_on_true = on_true
	codegen_on_exit = on_exit
	return self


## Declares WHEN this ACE's string params render as RICH TEXT in the sheet (BBCode
## effects instead of literal tags): when the param with this id holds exactly this
## value (the ConsoleLog "As: Rich text" stream choice). Declared HERE - on the
## descriptor - so the generic row builder checks a capability, never one provider's
## param-value idiom. Chains like .described():
## `F.make_descriptor(...).rich_text_when("level", "print_rich")`.
func rich_text_when(param_id: String, value: String) -> ACEDescriptor:
	rich_when_param = param_id
	rich_when_value = value
	return self


## Marks this condition as an EDGE GATE the compiler evaluates LAST: the term is hoisted to the end
## of the emitted `and` chain no matter which condition cell it occupies (an OR row is parenthesized
## first), so short-circuiting guarantees it is reached exactly when the row's other conditions are
## true. Use it for Trigger Once style conditions whose state test means "was I reached last tick?".
## Chains like .described(): `F.make_descriptor(...).stateful(...).evaluated_last()`.
func evaluated_last() -> ACEDescriptor:
	evaluate_last = true
	return self


## Marks this ACE deprecated and returns self, so it chains after make_descriptor like .described():
## `F.make_descriptor(...).deprecated("Use Move Toward instead", "Core::MoveToward")`. The ACE keeps
## working - existing sheets that already use it compile byte-for-byte unchanged - but it's hidden from the
## picker so it can't be added to new work, and its hover/tooltip flags it with the replacement. This is the
## compatibility covenant: never rename or delete a shipped ace_id, deprecate it instead.
func deprecated(message: String = "", replacement: String = "") -> ACEDescriptor:
	is_deprecated = true
	deprecation_message = message
	replacement_ace_id = replacement
	return self


## A one-line "[Deprecated] …" note for hover/tooltips, or "" when not deprecated. Defined once here so the
## picker, the viewport hover, and any future Project-Doctor hint all phrase it identically.
func deprecation_note() -> String:
	if not is_deprecated:
		return ""
	# Parenthesised, not "[Deprecated]" - square brackets would be parsed as an (unknown) BBCode tag and
	# eaten when this note prefixes a description that renders in a rich (BBCode) hover tooltip.
	var note: String = "(Deprecated)"
	if not deprecation_message.strip_edges().is_empty():
		note += " " + deprecation_message.strip_edges()
	if not replacement_ace_id.strip_edges().is_empty():
		note += " Use %s instead." % replacement_ace_id.strip_edges()
	return note


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
