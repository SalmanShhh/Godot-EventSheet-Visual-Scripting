# EventForge - the one shape every quick question takes. The safe answer is OK (Enter), Esc and the
# close box only ever cancel, and the risky answer is its own button on the left that neither key
# reaches. An empty list or code card is hidden rather than drawn around nothing.
@tool
class_name SmallPromptTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const SMALL_PROMPT_PATH := "res://addons/eventsheet/editor/small_prompt.gd"


static func run() -> bool:
	var ok: bool = true
	var host: Node = Node.new()
	var ran: Array = []
	var dialog: ConfirmationDialog = load(SMALL_PROMPT_PATH).open(host, {
		"title": "Keep this event?",
		"say": "One plain sentence.",
		"note": "Ctrl+Z undoes it.",
		"main": "Keep it",
		"danger": "Delete the event",
		"on_main": func() -> void: ran.append("main"),
		"on_cancel": func() -> void: ran.append("cancel"),
		"on_danger": func() -> void: ran.append("danger"),
	})
	var danger: Button = dialog.find_child("Danger", true, false) as Button
	ok = _check("the dialog reads as its copy", [dialog.title, dialog.ok_button_text,
		dialog.cancel_button_text, dialog.get_cancel_button().visible, danger.text],
		["Keep this event?", "Keep it", "Cancel", true, "Delete the event"]) and ok
	ok = _check("the risky button stands first, on the left", danger.get_index(), 0) and ok
	ok = _check("nothing to list, no code: neither is drawn",
		[(dialog.find_child("Places", true, false) as Control).visible,
		(dialog.find_child("Code", true, false) as Control).visible], [false, false]) and ok
	dialog.canceled.emit()
	dialog.custom_action.emit(&"something_else")
	ok = _check("Esc and other actions only cancel", ran, ["cancel"]) and ok
	dialog.custom_action.emit(load(SMALL_PROMPT_PATH).DANGER_ACTION)
	dialog.confirmed.emit()
	ok = _check("the red button and OK each run their own answer", ran, ["cancel", "danger", "main"]) and ok

	# A question that touches places lists them, and can redraw them while an answer is typed.
	var listed: ConfirmationDialog = load(SMALL_PROMPT_PATH).open(host, {
		"title": "Rename Player?", "cancel": "", "code": "func a() -> void:\n\tb()",
		"list": [["player.gd", "class_name"], ["hud.gd", "2 places"]]})
	var places: Tree = listed.find_child("Places", true, false) as Tree
	ok = _check("the list shows each place and its count",
		[places.visible, places.get_root().get_child_count(), places.get_root().get_child(1).get_text(1),
		(listed.find_child("Code", true, false) as Control).visible, listed.get_cancel_button().visible,
		listed.find_child("Danger", true, false) == null],
		[true, 2, "2 places", true, false, true]) and ok
	load(SMALL_PROMPT_PATH).set_list(listed, [])
	ok = _check("an emptied list hides", places.visible, false) and ok
	host.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("small_prompt_test", label, actual, expected)
