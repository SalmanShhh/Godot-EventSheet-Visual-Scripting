# Godot EventSheets - the small writing windows on the window kit.
#
# Each of these writes one row or one declaration, and each says what it writes before OK: the band
# shows the row, the help strip the code, a state note what is wrong with which field while OK waits.
# Pins, window by window: Edit Signal holds OK on a bad parameter with a red edge; the Parameter
# window refuses a misplaced default in the window and deletes with its own button; Edit Comment
# names a cleared swatch and makes no undo step on an untouched Save; Compare reads the row in its
# band; Connect Signal reads the event and notes a signal the sheet already handles; Add behavior
# shows a pack's knobs as typed fields under their own names with the pack's doc line.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "small_writing_windows_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_signal() and ok
	ok = _test_parameter() and ok
	ok = _test_comment() and ok
	ok = _test_connect_signal() and ok
	ok = _test_add_behavior() and ok
	return ok


static func _dock(sheet: EventSheetResource) -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	return dock


static func _test_signal() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var hit: SignalRow = SignalRow.new()
	hit.signal_name = "hit"
	hit.params = PackedStringArray(["damage: int"])
	sheet.events.append(hit)
	var dock: EventSheetDock = _dock(sheet)
	var rows: EventSheetStructRowDialogs = dock._struct_rows
	rows.open_signal_dialog(hit)
	var opened: Array = [rows._signal_band.words_label.text, rows._signal_strip.in_code_value.text, rows._signal_dialog.get_ok_button().disabled]
	rows._signal_params_edit.text = "damage: int\nfrom: Node\nclass"
	rows._refresh_signal()
	var refused: Array = [rows._signal_problem_label.text, rows._signal_dialog.get_ok_button().disabled,
		rows._signal_params_edit.has_theme_stylebox_override("normal")]
	dock.free()
	return SUPPORT.pins(NAME, [
		["the signal window shows the line it writes", opened, ["signal hit(damage: int)", "signal hit(damage: int)", false]],
		["a bad parameter is said while typing, OK held, the field edged red", refused,
			["\"class\" can't be a signal parameter name.", true, true]],
	])


static func _test_parameter() -> bool:
	var parent: Node = Node.new()
	var dialog: EventSheetParamDialog = EventSheetParamDialog.new()
	dialog.init_dialog(parent)
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "take_damage"
	for pair: Array in [["amount", "int", ""], ["knockback", "float", "0.0"]]:
		var param: ACEParam = ACEParam.new()
		param.id = str(pair[0])
		param.type_name = str(pair[1])
		param.gdscript_default = str(pair[2])
		verb.params.append(param)
	dialog.open_for_param(verb, 0)
	var opened: Array = [dialog._band.icon.glyph, dialog._band.object_label.text, dialog._band.words_label.text, dialog._strip.in_code_value.text,
		dialog._delete_button.visible]
	dialog._default_edit.text = "5"
	dialog._refresh()
	var fine: String = dialog._problem_label.text
	dialog._default_edit.text = ""
	dialog.open_for_param(verb, 1)
	dialog._default_edit.text = ""
	dialog._name_edit.text = "knockback"
	dialog._refresh()
	var trailing_ok: String = dialog._problem_label.text
	dialog.open_for_param(verb, 0)
	dialog._default_edit.text = "5"
	dialog._refresh()
	var emitted: Array = []
	dialog.param_confirmed.connect(func(data: Dictionary) -> void: emitted.append(data))
	# A default before an input without one would not parse: refused in the window, Apply held.
	var verb_two: EventFunction = verb.duplicate(true)
	(verb_two.params[1] as ACEParam).gdscript_default = ""
	dialog.open_for_param(verb_two, 0)
	dialog._default_edit.text = "5"
	dialog._refresh()
	var misplaced: Array = [dialog._problem_label.text, dialog._dialog.get_ok_button().disabled]
	dialog._on_confirmed()
	var after_refusal: int = emitted.size()
	dialog.delete_param()
	var deleted: Dictionary = emitted[0] if not emitted.is_empty() else {}
	dialog.open_for_new_param(verb)
	var new_one: bool = dialog._delete_button.visible
	parent.free()
	return SUPPORT.pins(NAME, [
		["the band is this input's own line under the head, the strip its func line", opened,
			["parameter", "amount", "int", "func take_damage(amount: int, knockback: float = 0.0)", true]],
		["a default ahead of a defaulted input is fine", fine, ""],
		["clearing the last default is fine", trailing_ok, ""],
		["a default ahead of an input without one is refused in the window", misplaced,
			["Parameters with a default value must come after those without - move this one down, or give the ones after it defaults too.", true]],
		["...and Apply sends nothing", after_refusal, 0],
		["Delete is its own button and removes this input", [deleted.get("removed", false), deleted.get("index", -1)], [true, 0]],
		["a new parameter has nothing to delete", new_one, false],
	])


static func _test_comment() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var comment: CommentRow = CommentRow.new()
	comment.text = "Enemies [b]only[/b] chase while the player is visible.\nSecond line"
	sheet.events.append(comment)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var manager: EventSheetEditorTest.FakeEditorUndoRedoManager = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	dock.set_undo_redo_manager(manager)
	dock.setup(sheet)
	dock._comments.open_comment_dialog(comment)
	var opened: Array = [dock._comments._comment_band.words_label.text, dock._comments._comment_color_label.text]
	dock._comments._on_comment_dialog_confirmed()
	var untouched: Array = [dock._dirty, manager._undo_stack.size()]
	var dirty_before: bool = false
	var history_before: int = 0
	dock._comments._comment_manual_check.button_pressed = true
	dock._comments._refresh_comment()
	var documented: String = dock._comments._comment_strip.in_code_value.text
	dock.free()
	return SUPPORT.pins(NAME, [
		["the comment window shows its first line as the file holds it", opened,
			["# Enemies [b]only[/b] chase while the player is visible. …", "theme default"]],
		["an untouched Save is no edit", untouched, [dirty_before, history_before]],
		["Shows in the manual writes ##", documented, "## Enemies [b]only[/b] chase while the player is visible. …"],
	])


static func _test_connect_signal() -> bool:
	var connect_script: GDScript = load("res://addons/eventsheet/editor/connect_signal_dialog.gd")
	var handled: PackedStringArray = connect_script.handled_signals(
		"extends Area2D\n\n\nfunc _on_body_exited(body: Node2D) -> void:\n\tpass\n\n\nfunc _ready() -> void:\n\tpass\n")
	return SUPPORT.pins(NAME, [
		["a signal the file already answers is found by its handler", handled, PackedStringArray(["body_exited"])],
		["a core signal reads as its trigger", connect_script.event_reading("body_entered"), "On Body Entered"],
		["any other reads On and its name as written", connect_script.event_reading("door_opened"), "On door_opened"],
		["the strip shows the handler it writes", connect_script.handler_line("body_entered", "body: Node2D"),
			"func _on_body_entered(body: Node2D) -> void:"],
	])


static func _test_add_behavior() -> bool:
	var path: String = "user://small_writing_windows_pack.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("extends Node\n\n## Grace window (s) to still jump just after walking off a ledge.\n@export var coyote_time: float = 0.1\n@export var double_jump: bool = true\n@export var jumps: int = 2\n@export var label_text: String = \"hop\"\n")
	file.close()
	var knobs: Array[Dictionary] = EventSheetAddBehavior.exported_properties(path)
	var fields: Array = []
	var texts: Array = []
	for knob: Dictionary in knobs:
		var field: Control = EventSheetAddBehaviorDialog.knob_field(knob)
		fields.append(field.get_class())
		texts.append(EventSheetAddBehaviorDialog.knob_text(field))
		field.free()
	DirAccess.remove_absolute(path)
	return SUPPORT.pins(NAME, [
		["each knob keeps the name the pack wrote", [str(knobs[0].get("name")), str(knobs[3].get("name"))], ["coyote_time", "label_text"]],
		["the pack's doc line says what the knob is for", str(knobs[0].get("description")), "Grace window (s) to still jump just after walking off a ledge."],
		["a knob is the field its type wants", fields, ["SpinBox", "CheckBox", "SpinBox", "LineEdit"]],
		["each field reads back the pack's default", texts, ["0.1", "true", "2", "\"hop\""]],
	])
