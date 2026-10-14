# EventForge - the quick questions that were one-off dialogs now take the one shape every quick
# question takes (small_prompt.gd): the title is the question, one sentence says what happens, the
# blue button is the safe answer and Enter in the field the question asks for presses it.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "quick_questions_test"
const SMALL_PROMPT_PATH := "res://addons/eventsheet/editor/small_prompt.gd"


static func run() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(EventSheetResource.new())
	dock._open_go_to_event_dialog()
	var go_to: ConfirmationDialog = _last_question(dock)
	var named: Array = []
	dock._quick_prompts.prompt_extract_function_name(func(entered: String) -> void: named.append(entered))
	var extract: ConfirmationDialog = _last_question(dock)
	var name_field: LineEdit = extract.find_children("*", "LineEdit", true, false).filter(
		func(field: Node) -> bool: return (field as LineEdit).placeholder_text == "apply_physics").front() as LineEdit
	var prefilled: String = name_field.text
	name_field.text = "apply_physics"
	# Enter in the name field is the blue button.
	name_field.text_submitted.emit(name_field.text)
	var ok: bool = SUPPORT.pins(NAME, [
		["Go to event asks which event", [go_to.title, go_to.ok_button_text], ["Go to which event?", "Go"]],
		["Extract asks for the function's name, pre-filled", [extract.title, prefilled],
			["Extract these actions to a function?", "do_something"]],
		["...and Enter in the field extracts under the typed name", named, ["apply_physics"]],
	])
	ok = _enter_is_wired_once(dock) and ok
	dock.free()
	return ok


## The quick question owns Enter: a caller that wires the field again makes Godot refuse the second
## connection out loud every time the question opens. One line question, the function's button
## question and the Add > Inspector button question, each asked with an ear on the engine's errors.
static func _enter_is_wired_once(dock: EventSheetDock) -> bool:
	var ear: ErrorEar = ErrorEar.new()
	OS.add_logger(ear)
	dock._ask_for_line("Row Comment", "", "", func(_typed: String) -> void: pass)
	var line: LineEdit = _last_question(dock).find_children("*", "LineEdit", true, false).front() as LineEdit
	dock.prompt_inspector_button_for("bake")
	dock._variable_gestures.prompt_inspector_button()
	OS.remove_logger(ear)
	return SUPPORT.pins(NAME, [
		["the line question's field submits to one listener", line.get_signal_connection_list("text_submitted").size(), 1],
		["no question wires a field twice", ear.refused, []],
	])


## Hears every engine error while it is added, and keeps the ones refusing a second connection.
class ErrorEar extends Logger:
	var refused: Array = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if (code + rationale).contains("already connected"):
			refused.append(rationale if not rationale.is_empty() else code)


## The question the dock opened last.
static func _last_question(host: Node) -> ConfirmationDialog:
	var asked: Array = host.get_children().filter(func(child: Node) -> bool: return child is ConfirmationDialog)
	return asked.back() as ConfirmationDialog
