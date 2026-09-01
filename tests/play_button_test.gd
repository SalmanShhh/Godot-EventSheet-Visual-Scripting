@tool
class_name PlayButtonTest
extends RefCounted

# EventSheets test - ONE PLAY BUTTON, SIX WAYS TO PLAY.
#
# The strip used to front six separate run buttons (Run Scene, Play as host + client, and the four
# Preview/Debug/Profiler ones), and the beginner Add toolbar duplicated four of them one strip
# below. Six doors to the same room, none of them the obvious one. There is one now: a face Button
# that performs the run this project chose, beside a narrow dropdown holding all six - Godot's own
# split button, which Godot does not have, built the way Godot builds one (two adjacent controls in
# a single frame).
#
# Nothing was removed. The six are one table now, and the expanded strip still shows every one of
# them as the plain button it always was. What changed is that the table is read in one place, so
# the dropdown, the face and the buttons cannot drift apart.
#
# Pinned by VALUE: the dropdown's entries in order (with the keys printed from the shortcut table
# rather than typed here), the chosen-run tri-state, the face's relabel to Stop, and the Add
# toolbar's own children - which no longer include a way to start a game.


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_dropdown() and ok
	ok = _test_the_chosen_face() and ok
	ok = _test_the_face_says_stop() and ok
	ok = _test_the_add_toolbar_only_adds() and ok
	return ok


## THE DROPDOWN, entry by entry: the four runs the sheet owns, Godot's own two under their own
## heading, and Main button at the foot. The keys are read from the shortcut table here exactly as
## the popup reads them, so a rebind (or the "another event-sheet editor" preset, which moves F6)
## moves both sides of this check together and never one of them.
static func _test_the_dropdown() -> bool:
	var editor: EventSheetEditor = _editor()
	var menu: MenuButton = editor._toolbar.find_child("EventSheetPlayMenu", true, false) as MenuButton
	var ok: bool = _check("the play slot carries a dropdown", menu != null, true)
	if menu == null:
		editor.free()
		return false
	var popup: PopupMenu = menu.get_popup()
	var entries: PackedStringArray = PackedStringArray()
	for index: int in popup.item_count:
		entries.append(popup.get_item_text(index))
	ok = _check("the dropdown lists the six ways to play, then the choice", entries,
		PackedStringArray([
			_t("Run Scene"),
			_t("🐞 Debug layout"),
			_t("⏱ Run with profiler"),
			_t("Play as host + client"),
			_t("Godot's own"),
			_with_key("▶ Preview layout", "preview_layout"),
			_with_key("▶▶ Preview project", "preview_project"),
			"",
			_t("Main button"),
		])) and ok
	# The two under the heading are separated from the four above them, and the heading itself is a
	# separator - Godot's own way of drawing a muted, unclickable line of words in a menu.
	ok = _check("Godot's own two sit under a separator", popup.is_item_separator(4), true) and ok
	ok = _check("and the choice is fenced off by another", popup.is_item_separator(7), true) and ok
	# Main button is the same six again, ticked, so the two lists cannot drift apart.
	var choices: PopupMenu = popup.find_child("EventSheetPlayMainChoice", true, false) as PopupMenu
	var choice_labels: PackedStringArray = PackedStringArray()
	for index: int in choices.item_count:
		choice_labels.append(choices.get_item_text(index))
	ok = _check("Main button offers the same six", choice_labels,
		PackedStringArray([
			_t("Run Scene"),
			_t("🐞 Debug layout"),
			_t("⏱ Run with profiler"),
			_t("Play as host + client"),
			_with_key("▶ Preview layout", "preview_layout"),
			_with_key("▶▶ Preview project", "preview_project"),
		])) and ok
	ok = _check("with Run Scene ticked in a project that never chose",
		choices.is_item_checked(0), true) and ok
	editor.free()
	return ok


## THE CHOSEN FACE. Which run the button does is per-project metadata read through a NON-null
## sentinel: "" is nobody's choice, and so is any id the table does not carry (a project that chose
## a run a later version retired must not end up with a face that runs nothing).
static func _test_the_chosen_face() -> bool:
	var ok: bool = _check("nobody chose, so the face runs the scene this sheet is on",
		EventSheetRunControls.main_run_from(""), "run_scene")
	ok = _check("a stored choice is the face", EventSheetRunControls.main_run_from("debug_layout"),
		"debug_layout") and ok
	ok = _check("an id the table does not carry is nobody's choice",
		EventSheetRunControls.main_run_from("run_the_dishwasher"), "run_scene") and ok
	ok = _check("and neither is a value of the wrong type",
		EventSheetRunControls.main_run_from(null), "run_scene") and ok
	# The instance half: choosing writes the choice and reads it straight back, and an id that is
	# not one of the six is refused rather than stored.
	var controls: EventSheetRunControls = EventSheetRunControls.new()
	ok = _check("a fresh dock's face is Run Scene", controls.main_run_id(), "run_scene") and ok
	controls.set_main_run("host_client")
	ok = _check("choosing one sticks", controls.main_run_id(), "host_client") and ok
	controls.set_main_run("nonsense")
	ok = _check("and a choice the table does not carry is refused",
		controls.main_run_id(), "host_client") and ok
	# The face follows the choice: its words, its tick and the run it hands over are one answer.
	var editor: EventSheetEditor = _editor()
	var play: EventSheetPlayButton = editor._menu_bar.play_button()
	editor._run_controls.set_main_run("preview_project")
	play.apply_choice()
	ok = _check("the face wears the chosen run's words", play.face().text,
		_t("▶▶ Preview project")) and ok
	var choices: PopupMenu = play.menu().get_popup().find_child(
		"EventSheetPlayMainChoice", true, false) as PopupMenu
	ok = _check("and the tick moved with it", choices.is_item_checked(5), true) and ok
	ok = _check("the run it left is unticked", choices.is_item_checked(0), false) and ok
	editor.free()
	return ok


## THE FACE SAYS STOP. It is an adopter of its chosen run like every other run button on the strip -
## one source of truth for what a run is called right now - so the relabel is pinned the way
## run_controls_adopt_test pins it: through label_for and through an adopted button, with no editor
## behind it (a headless run has no game to play and is never "running").
static func _test_the_face_says_stop() -> bool:
	var controls: EventSheetRunControls = EventSheetRunControls.new()
	var face: Button = Button.new()
	controls.adopt("run_scene", face)
	controls.refresh()
	var ok: bool = _check("at rest the face says what it will run", face.text, _t("Run Scene"))
	ok = _check("and while a game runs it says Stop",
		EventSheetRunControls.label_for("run_scene", true), "■ Stop") and ok
	ok = _check("host + client stops the game it started too",
		EventSheetRunControls.label_for("host_client", true), "■ Stop") and ok
	ok = _check("Preview project restarts instead",
		EventSheetRunControls.label_for("preview_project", true), "↻ Restart") and ok
	# Re-choosing moves the face between adopters. A face left in its old run's list would be
	# relabelled by a run it no longer performs, so it leaves before it joins.
	controls.release(face)
	controls.adopt("debug_layout", face)
	controls.refresh()
	ok = _check("a re-chosen face wears the new run", face.text, _t("🐞 Debug layout")) and ok
	ok = _check("and the run it left has no adopters holding it",
		(controls._buttons["run_scene"] as Array).size(), 0) and ok
	face.free()
	return ok


## THE ADD TOOLBAR ONLY ADDS. It used to end with a separator and four run buttons, which put a
## second way to start a game one strip below the first. Its children are the eight Add gestures,
## and nothing else.
static func _test_the_add_toolbar_only_adds() -> bool:
	var root: Node = Node.new()
	var toolbar: EventSheetBeginnerToolbar = EventSheetBeginnerToolbar.new()
	var strip: Control = toolbar.build(root)
	var labels: PackedStringArray = PackedStringArray()
	for child: Node in strip.get_children():
		labels.append(_t(str((child as Button).text)) if child is Button else str(child.get_class()))
	var ok: bool = _check("the Add toolbar is the eight Add gestures and nothing else", labels,
		PackedStringArray([_t("+ Event"), _t("+ Sub-event"), _t("+ Condition"), _t("+ Action"),
			_t("+ Group"), _t("+ Comment"), _t("+ Variable"), _t("+ Function")]))
	root.free()
	return ok


static func _t(text: String) -> String:
	return EventSheetL10n.translate(text)


## A dropdown entry as the popup builds it: the run's words, then its key from the ONE shortcut
## table. Nothing in this file types a key name.
static func _with_key(label: String, action: String) -> String:
	var binding: String = EventSheetShortcuts.binding_for(action)
	return _t(label) if binding.is_empty() else "%s  (%s)" % [_t(label), binding]


static func _editor() -> EventSheetEditor:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	return editor


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] play_button_test: %s" % label)
		return true
	print("[FAIL] play_button_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
