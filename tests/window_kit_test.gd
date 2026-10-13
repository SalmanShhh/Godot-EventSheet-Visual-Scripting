@tool
extends RefCounted
# Godot EventSheets - the window kit's parts: the described dropdown (every choice carries its
# sentence as Godot's own item tooltip, and the closed dropdown's tooltip follows the chosen one),
# the Events | Code | Both view switch, the result card and the state note.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "window_kit_test"


static func run() -> bool:
	var passed: bool = true
	passed = _described_dropdown() and passed
	passed = _view_switch() and passed
	passed = _result_card() and passed
	passed = _state_note() and passed
	return passed


static func _described_dropdown() -> bool:
	var dropdown: OptionButton = EventSheetPopupUI.described_option()
	EventSheetPopupUI.add_described_item(dropdown, "Auto", "Loaded when it enters, saved when it leaves.")
	EventSheetPopupUI.add_described_item(dropdown, "Manual", "Only when your events say so.", "manual")
	dropdown.add_item("Bare")
	var rows: Array = [
		["each choice carries its sentence as Godot's item tooltip", dropdown.get_item_tooltip(1),
			"Only when your events say so."],
		["a stored value rides as the item's metadata", dropdown.get_item_metadata(1), "manual"],
		["the closed dropdown says the chosen item's sentence", dropdown.tooltip_text,
			"Loaded when it enters, saved when it leaves."],
	]
	dropdown.select(1)
	dropdown.item_selected.emit(1)
	rows.append(["picking another choice moves the tooltip with it", dropdown.tooltip_text,
		"Only when your events say so."])
	# select() from code emits nothing - the pointer arriving brings the tooltip up to date.
	dropdown.select(0)
	dropdown.mouse_entered.emit()
	rows.append(["a choice made in code is said by the time the pointer arrives", dropdown.tooltip_text,
		"Loaded when it enters, saved when it leaves."])
	var told: OptionButton = OptionButton.new()
	told.tooltip_text = "What the field is for."
	EventSheetPopupUI.described_option(told)
	told.add_item("Plain")
	EventSheetPopupUI.follow_description(told)
	rows.append(["a choice with no sentence falls back to the field's own tooltip", told.tooltip_text,
		"What the field is for."])
	dropdown.free()
	told.free()
	return SUPPORT.pins(NAME, rows)


static func _view_switch() -> bool:
	var switch: EventSheetPopupUI.ViewSwitch = EventSheetPopupUI.ViewSwitch.new()
	var heard: Array = []
	switch.view_chosen.connect(func(view: String) -> void: heard.append(view))
	var rows: Array = [
		["it reads Events | Code | Both", _texts(switch), ["Events", "Code", "Both"]],
		["it opens on Both", switch.view, "both"],
		["with Both pressed", (switch.buttons["both"] as Button).button_pressed, true],
	]
	(switch.buttons["code"] as Button).pressed.emit()
	rows.append(["pressing Code emits the chosen view", heard, ["code"]])
	rows.append(["and presses Code alone", _pressed(switch), ["code"]])
	switch.choose("code")
	rows.append(["choosing the view already shown emits nothing", heard, ["code"]])
	switch.choose("events", false)
	rows.append(["a quiet choice from code moves the buttons", _pressed(switch), ["events"]])
	rows.append(["without emitting", heard, ["code"]])
	rows.append(["only the three views exist", _chosen_after(switch, "split"), "events"])
	switch.free()
	return SUPPORT.pins(NAME, rows)


static func _result_card() -> bool:
	var card: EventSheetPopupUI.ResultCard = EventSheetPopupUI.ResultCard.new("What happened")
	card.report([
		{"text": "Wrote 12 rows.", "file": "res://data/items.csv", "tone": EventSheetPopupUI.TONE_OK},
		{"text": "3 cells were empty.", "tone": EventSheetPopupUI.TONE_WARNING},
	], PackedStringArray(["12 rows", "4 columns", "items.csv"]))
	var first: HBoxContainer = card.lines_box.get_child(0) as HBoxContainer
	var second: HBoxContainer = card.lines_box.get_child(1) as HBoxContainer
	var rows: Array = [
		["the figures read as one flow", card.figures_label.text, "12 rows  →  4 columns  →  items.csv"],
		["one line per outcome", card.lines_box.get_child_count(), 2],
		["an ok line leads with its mark", (first.get_node("Mark") as Label).text, "✓"],
		["a warning line leads with its own", (second.get_node("Mark") as Label).text, "!"],
		["the file it touched closes the line as a chip", first.get_node("File").tooltip_text,
			"res://data/items.csv"],
		["a line that touched no file has no chip", second.has_node("File"), false],
	]
	card.report([])
	rows.append(["an empty report clears the figures", card.figures_label.visible, false])
	rows.append(["and the lines", card.lines_box.get_children().filter(
		func(child: Node) -> bool: return not child.is_queued_for_deletion()).size(), 0])
	card.free()
	return SUPPORT.pins(NAME, rows)


static func _state_note() -> bool:
	var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new()
	var rows: Array = [["a note with nothing to say is hidden", note.visible, false]]
	note.say("This name is already used by a function.")
	rows.append(["a sentence shows it", note.visible, true])
	rows.append(["and reads back", note.text, "This name is already used by a function."])
	rows.append(["a problem by default", note.tone, EventSheetPopupUI.TONE_ERROR])
	note.say("%Bullets is not in this scene yet.", EventSheetPopupUI.TONE_WARNING)
	rows.append(["a warning colours its edge amber", _edge(note), EventSheetPalette.COLOR_HEALTH_WARN])
	note.say("")
	rows.append(["saying nothing hides it again", note.visible, false])
	note.free()
	return SUPPORT.pins(NAME, rows)


static func _texts(switch: EventSheetPopupUI.ViewSwitch) -> Array:
	var texts: Array = []
	for child: Node in switch.get_children():
		texts.append((child as Button).text)
	return texts


static func _pressed(switch: EventSheetPopupUI.ViewSwitch) -> Array:
	var pressed: Array = []
	for id: String in switch.buttons:
		if (switch.buttons[id] as Button).button_pressed:
			pressed.append(id)
	return pressed


static func _chosen_after(switch: EventSheetPopupUI.ViewSwitch, wanted: String) -> String:
	switch.choose(wanted)
	return switch.view


static func _edge(note: EventSheetPopupUI.StateNote) -> Color:
	return (note.get_theme_stylebox("panel") as StyleBoxFlat).border_color
