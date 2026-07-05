## @ace_category("UI")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name DialogueKitBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("DialogueKitBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Dialogue Started")
signal on_dialogue_started
## @ace_trigger
## @ace_name("On Dialogue Finished")
signal on_dialogue_finished
## @ace_trigger
## @ace_name("On Line Started")
signal on_line_started
## @ace_trigger
## @ace_name("On Line Finished")
signal on_line_finished

## Input action that advances the dialogue (blank = no built-in input; call Advance yourself).
@export var advance_action: String = "ui_accept"
## Typewriter speed; Advance mid-line completes it instantly.
@export_range(1, 400, 1) var chars_per_second: float = 40.0
var current_speaker: String = ""
var current_text: String = ""
var dialogue_active: bool = false
var line_queue: Array = []
## The named panel (any CanvasItem under the host) shown while dialogue runs.
@export var panel_name: String = "DialoguePanel"
var revealed_chars: float = 0.0
## The named Label that shows who is talking.
@export var speaker_label_name: String = "SpeakerLabel"
## The named Label the line types into.
@export var text_label_name: String = "TextLabel"
var typing: bool = false
var ui_cache: Dictionary = {}

## Named-descendant lookup under the host, cached (freed nodes fall out on the next miss).
func _ui(control_name: String) -> Node:
	var cached: Variant = ui_cache.get(control_name)
	if cached is Node and is_instance_valid(cached):
		return cached
	var found: Node = host.find_child(control_name, true, false) if host != null else null
	if found != null:
		ui_cache[control_name] = found
	return found

func _process(delta: float) -> void:
	if not dialogue_active:
		return
	if typing:
		revealed_chars += chars_per_second * delta
		var text_label: Node = _ui(text_label_name)
		if text_label != null:
			text_label.set("visible_characters", int(revealed_chars))
		if int(revealed_chars) >= current_text.length():
			_finish_line()
	if not advance_action.is_empty() and InputMap.has_action(advance_action) and Input.is_action_just_pressed(advance_action):
		advance_dialogue()

## @ace_action
## @ace_name("Queue Line")
## @ace_category("Dialogue")
## @ace_description("Appends a line (speaker + text) to the conversation queue.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.queue_line({speaker}, {text})")
func queue_line(speaker: String, text: String) -> void:
	line_queue.append({"speaker": speaker, "text": text})

## @ace_action
## @ace_name("Start Dialogue")
## @ace_category("Dialogue")
## @ace_description("Shows the panel and plays the queued lines from the top.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.start_dialogue()")
func start_dialogue() -> void:
	if dialogue_active or line_queue.is_empty():
		return
	dialogue_active = true
	_set_panel_visible(true)
	on_dialogue_started.emit()
	_show_next_line()

## @ace_action
## @ace_name("Advance")
## @ace_category("Dialogue")
## @ace_description("Mid-line: completes the line instantly. Otherwise: next line, or ends the conversation.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.advance_dialogue()")
func advance_dialogue() -> void:
	if not dialogue_active:
		return
	if typing:
		_finish_line()
		return
	if line_queue.is_empty():
		end_dialogue()
	else:
		_show_next_line()

## @ace_action
## @ace_name("End Dialogue")
## @ace_category("Dialogue")
## @ace_description("Hides the panel, clears any remaining lines, and fires On Dialogue Finished.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.end_dialogue()")
func end_dialogue() -> void:
	if not dialogue_active:
		return
	dialogue_active = false
	typing = false
	line_queue.clear()
	_set_panel_visible(false)
	on_dialogue_finished.emit()

## @ace_condition
## @ace_name("Is Dialogue Active")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.is_dialogue_active()")
func is_dialogue_active() -> bool:
	return dialogue_active

## @ace_condition
## @ace_name("Is Typing")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.is_typing()")
func is_typing() -> bool:
	return typing

## @ace_condition
## @ace_name("Speaker Is")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.speaker_is({speaker})")
func speaker_is(speaker: String) -> bool:
	return current_speaker == speaker

## @ace_expression
## @ace_name("Current Speaker")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.current_speaker_value()")
func current_speaker_value() -> String:
	return current_speaker

## @ace_expression
## @ace_name("Current Text")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.current_text_value()")
func current_text_value() -> String:
	return current_text

## @ace_expression
## @ace_name("Lines Remaining")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DialogueKitBehavior.lines_remaining()")
func lines_remaining() -> float:
	return float(line_queue.size())

func _set_panel_visible(state: bool) -> void:
	var panel: Node = _ui(panel_name)
	if panel is CanvasItem:
		(panel as CanvasItem).visible = state

func _show_next_line() -> void:
	var line: Dictionary = line_queue.pop_front()
	current_speaker = str(line.get("speaker", ""))
	current_text = str(line.get("text", ""))
	revealed_chars = 0.0
	typing = true
	var speaker_label: Node = _ui(speaker_label_name)
	if speaker_label != null:
		speaker_label.set("text", current_speaker)
	var text_label: Node = _ui(text_label_name)
	if text_label != null:
		text_label.set("text", current_text)
		text_label.set("visible_characters", 0)
	on_line_started.emit()

func _finish_line() -> void:
	typing = false
	var text_label: Node = _ui(text_label_name)
	if text_label != null:
		text_label.set("visible_characters", -1)
	on_line_finished.emit()

# Dialogue Kit behavior: queue lines (speaker + text), play them with a typewriter reveal into NAMED labels, advance on one input action (mid-line advance completes the line instantly). Triggers fire per line and per conversation, so portraits, sounds, and camera moves hang off the sheet - no dialogue system to write.
