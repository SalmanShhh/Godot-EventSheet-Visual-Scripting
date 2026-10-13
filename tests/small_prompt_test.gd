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

	# With its Cancel button hidden the way out still works: Esc goes through that same button's
	# answer, and a closed question frees itself.
	var heard: Array = []
	var bare: ConfirmationDialog = load(SMALL_PROMPT_PATH).open(host, {"title": "Keep it?", "cancel": "",
		"on_cancel": func() -> void: heard.append("cancel")})
	bare.get_cancel_button().pressed.emit()
	ok = _check("a hidden Cancel still cancels", heard, ["cancel"]) and ok
	# Outside a running tree hide() only sets the flag, so the signal Godot sends on closing is sent here.
	bare.hide()
	bare.visibility_changed.emit()
	ok = _check("a closed question frees itself", bare.is_queued_for_deletion(), true) and ok
	ok = _check("the badge reads in a light theme as well as a dark one",
		[load(SMALL_PROMPT_PATH).badge_tones("!", false), load(SMALL_PROMPT_PATH).badge_tones("!", true)],
		[[Color("#4A3E22"), Color("#FFD27A")], [Color("#F5E2B8"), Color("#7A4E00")]]) and ok
	ok = _check("the sentence wraps at the display's scale", load(SMALL_PROMPT_PATH).wrap_width(),
		EventSheetPalette.scaled_f(400.0)) and ok
	host.free()
	return _test_class_rename_question() and ok


## Rename class asks in words that follow what is typed, and refuses a name another class has.
static func _test_class_rename_question() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock._current_sheet = EventSheetResource.new()
	dock._current_sheet.custom_class_name = "SmallPromptProbe"
	var head: EventSheetHeadActions = EventSheetHeadActions.new()
	head.init(dock)
	head._rename_dialog = load(SMALL_PROMPT_PATH).open(dock, {"main": "Rename"})
	var say: Label = head._rename_dialog.find_child("Say", true, false) as Label
	head._sync_class_rename("SmallPromptProbe", "Node")
	var taken: Array = [head._rename_dialog.title, say.text, head._rename_dialog.get_ok_button().disabled]
	head._sync_class_rename("SmallPromptProbe", "Hero")
	var ok: bool = SUPPORT.pins("small_prompt_test", [
		["a taken name is refused, and says why", taken,
			["Rename SmallPromptProbe?", "\"Node\" is already the name of another class.", true]],
		["a free name is asked about by name", [head._rename_dialog.title, say.text, head._rename_dialog.get_ok_button().disabled],
			["Rename SmallPromptProbe to Hero?", "Hero will be the class name everywhere SmallPromptProbe is used.", false]],
		# Only this sheet's edit is an undo step: the other open tabs change unsaved, closed files saved.
		["the note says what Ctrl+Z reaches", head.class_rename_note(),
			"Ctrl+Z undoes it in this sheet. Other open tabs change and stay unsaved; closed files are saved, each with a backup in Sheet Backups."],
	])
	dock.free()
	return _test_places_follow_the_question() and ok


## The rename question shows at once with a counting row, and the walk of the project fills the list
## after it - so a big project never stalls the click.
static func _test_places_follow_the_question() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock._current_sheet = EventSheetResource.new()
	dock._current_sheet.custom_class_name = "SmallPromptProbe"
	var head: EventSheetHeadActions = EventSheetHeadActions.new()
	head.init(dock)
	head.open_class_rename()
	var places: Tree = head._rename_dialog.find_child("Places", true, false) as Tree
	var before: Array = [places.visible, places.get_root().get_child(0).get_text(0)]
	head.fill_class_rename_places(head._rename_dialog, "SmallPromptProbe")
	var ok: bool = SUPPORT.pins("small_prompt_test", [
		["the question shows first, counting", before, [true, "Looking for every place it is used..."]],
		["then the walk fills the list - a name used nowhere lists nothing", places.visible, false],
	])
	dock.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("small_prompt_test", label, actual, expected)
