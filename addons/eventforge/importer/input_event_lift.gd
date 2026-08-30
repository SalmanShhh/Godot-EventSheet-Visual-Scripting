# EventForge - the INPUT-EVENT questions people wrote before this plugin existed.
#
# `if event.is_action_pressed("jump"):` is the first line inside almost every `_input` ever written,
# and until the Input Event rows existed a sheet had nothing to say about it: it opened as Expression
# Is True, the honest catch-all. The rows say it now, and this is the half that recognises the
# spelling a person actually types.
#
# THE ONE THING THAT IS NOT THE ROW'S: the ampersand. Godot takes a StringName or a plain String
# wherever an action is named, the shipped templates write the `&` themselves (it saves a hash per
# call in a handler that runs on every keystroke), and the field's own dropdown offers `"jump"` -
# so the `&` is the author's spelling and stays outside the capture, which is exactly what makes it
# ride back out untouched. That span is `text` in the shared capture grammar, and this family is the
# first to ask for it by that name.
#
# Every entry here is DERIVED FROM THE LINE, marked up as a person writes it (see
# EventForgeLiftExample): there is no regex in this file, and the four questions the validator asks
# of a hand-written entry are asked of these in exactly the same way.
#
# WHAT IS DELIBERATELY LEFT TO THE GENERAL INDEX: the strength read (`event.get_action_strength(…)`)
# is an expression rather than a statement or a term, and the shipped template spells it character
# for character - so the reverse index already claims it and a table entry here would be a second
# opinion about a line that has one.
@tool
class_name EventForgeInputEventLift
extends RefCounted

const Example := preload("res://addons/eventforge/importer/lift_example.gd")

## The fragment a term must contain before any pattern here is worth running. Every spelling below is
## a question asked OF THE EVENT, so a term that never names it cannot be one of them - which rules
## out almost every condition in a project on a substring.
const MARK: String = "event.is_action"

static var _conditions: Array[Dictionary] = []


## The condition this term is, or {} when no spelling here claims it.
static func match_condition(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	return EventForgeLiftTable.match_line(condition_entries(), text)


## Every entry, under the name the harness's scan looks for. This family's spellings are all
## questions, so it is the same list twice rather than a second list that could drift from it.
static func lift_entries() -> Array[Dictionary]:
	return condition_entries()


## The four spellings, built once for the life of the session - these run on every condition term of
## every opened file, and the table compiles each pattern once.
##
## ORDER IS MEANING, even where the anchoring already separates them: the repeating press is the
## press with one more argument, so it is asked first and a reader of this list meets the narrower
## spelling above the wider one.
static func condition_entries() -> Array[Dictionary]:
	if _conditions.is_empty():
		_conditions = [
			Example.entry("event_action_pressed_repeating", "EventIsActionPressedRepeating",
				"event.is_action_pressed([[action|text: \"ui_down\"]], true)"),
			Example.entry("event_action_pressed", "EventIsActionPressed",
				"event.is_action_pressed([[action|text: \"jump\"]])"),
			Example.entry("event_action_released", "EventIsActionReleased",
				"event.is_action_released([[action|text: \"fire\"]])"),
			Example.entry("event_is_action", "EventIsAction",
				"event.is_action([[action|text: \"aim\"]])")
		]
	return _conditions
