@tool
class_name EventSheetWordsSettingsDialog
extends AcceptDialog

# Settings > Words: every word the sheet lets you choose, on one page, with a live preview.
#
# One row per choosable word: what it names on the left ("an inheritance set"), then the word it
# reads as with Familiar Words ON and the word it reads as with Familiar Words OFF - a dropdown
# each, offering the two defaults, any extra offered word, and "custom…" for a word you type.
# Under the table, one event rendered in the words currently chosen, so the page never asks
# anyone to imagine the result.
#
# The page only WRITES the choices; every reader goes through EventSheetWords.word(key), which
# is why nothing here knows what a family or a layout is.

const CUSTOM_LABEL := "custom…"
const _CUSTOM_ID := 9000

var _rows: Dictionary = {}
var _preview_condition: Label = null
var _preview_action: Label = null
var _preset_option: OptionButton = null
var _preset_note: Label = null
var _preview_verbs: Label = null


func _init() -> void:
	title = "Words"
	ok_button_text = "Close"
	add_child(EventSheetPopupUI.margined(_build_body()))


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.add_child(EventSheetPopupUI.hint_label(
		"A few things have two honest names: the Godot one and the one every other event-sheet editor uses. Choose either, or type your own - the sheet reads the same word everywhere at once.", 620.0))
	page.add_child(EventSheetPopupUI.titled_card("the whole vocabulary at once", _build_presets()))
	page.add_child(EventSheetPopupUI.titled_card("how the sheet talks", _build_table()))
	page.add_child(EventSheetPopupUI.titled_card("live preview", _build_preview()))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var reset: Button = Button.new()
	reset.text = "Reset to defaults"
	reset.tooltip_text = "Drops every word you chose and goes back to the two defaults. The Familiar Words toggle itself is left alone."
	reset.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset)
	page.add_child(buttons)
	page.add_child(EventSheetPopupUI.hint_label(
		"The choices are yours alone - they are stored with the editor settings, not in the project, so two people on one project can read the same sheet in different words.", 620.0))
	return page


## The preset row: three named vocabularies and the reading the page falls back on when the
## switches say none of them. Godot words is the plain editor; Familiar words is the nouns table
## below (the View menu's own toggle); the third adds the VERB aliases, so a row reads the sentence
## a reader arriving from another event-sheet editor already types. Every one of them is reversible
## and none of them moves a byte of a sheet.
func _build_presets() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_preset_option = OptionButton.new()
	_preset_option.custom_minimum_size = Vector2(230.0, 0.0)
	for index: int in EventSheetWords.PRESETS.size():
		_preset_option.add_item(EventSheetWords.preset_label(EventSheetWords.PRESETS[index]), index)
	_preset_option.item_selected.connect(_on_preset_selected)
	box.add_child(EventSheetPopupUI.form_row("Words", _preset_option, 150.0,
		"Sets both halves at once: whether the nouns read in the sheet's words, and whether the verbs do."))
	_preset_note = EventSheetPopupUI.hint_label("", 620.0)
	box.add_child(_preset_note)
	return box


func _build_table() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_child(EventSheetPopupUI.small_caps_label("what it names"))
	grid.add_child(EventSheetPopupUI.small_caps_label("with Familiar Words on"))
	grid.add_child(EventSheetPopupUI.small_caps_label("off"))
	for key: String in EventSheetWords.keys():
		var label: Label = Label.new()
		label.text = EventSheetWords.names_what(key)
		label.custom_minimum_size = Vector2(170.0, 0.0)
		grid.add_child(label)
		var familiar_field: Control = _build_field(key, true)
		var plain_field: Control = _build_field(key, false)
		grid.add_child(familiar_field)
		grid.add_child(plain_field)
	return grid


## One state's picker for one key: a dropdown of the offered words plus "custom…", with a line
## edit that appears only when a typed word is in play.
func _build_field(key: String, familiar: bool) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(150.0, 0.0)
	var offered: PackedStringArray = EventSheetWords.choices(key)
	for index: int in offered.size():
		option.add_item(offered[index], index)
	option.add_separator()
	option.add_item(CUSTOM_LABEL, _CUSTOM_ID)
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = "your word"
	edit.visible = false
	option.item_selected.connect(func(_index: int) -> void: _on_choice(key, familiar))
	edit.text_submitted.connect(func(_text: String) -> void: _on_choice(key, familiar))
	edit.focus_exited.connect(func() -> void: _on_choice(key, familiar))
	box.add_child(option)
	box.add_child(edit)
	_rows["%s|%s" % [key, EventSheetWords.state_key(familiar)]] = {"option": option, "edit": edit}
	return box


func _build_preview() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var band: HBoxContainer = HBoxContainer.new()
	band.add_theme_constant_override("separation", 12)
	_preview_condition = Label.new()
	_preview_condition.custom_minimum_size = Vector2(300.0, 0.0)
	_preview_action = Label.new()
	_preview_action.custom_minimum_size = Vector2(200.0, 0.0)
	band.add_child(EventSheetPopupUI.panel_section(_preview_condition))
	band.add_child(EventSheetPopupUI.panel_section(_preview_action))
	box.add_child(band)
	# The VERBS, on their own line: the nouns above change with the toggle, and these two change
	# with the preset - a trigger read by its name and an action read by its row.
	_preview_verbs = Label.new()
	box.add_child(EventSheetPopupUI.panel_section(_preview_verbs))
	box.add_child(EventSheetPopupUI.hint_label(
		"One event, in the words you have chosen for the state the toggle is in right now.", 620.0))
	return box


## Rebuilds every field from the store and re-renders the preview. Called on open and after any
## change, so the page never drifts from what the sheet will actually read.
func refresh() -> void:
	var familiar_now: bool = EventSheetWords.familiar_words_enabled()
	for key: String in EventSheetWords.keys():
		for familiar: bool in [true, false]:
			var entry: Variant = _rows.get("%s|%s" % [key, EventSheetWords.state_key(familiar)], null)
			if not (entry is Dictionary):
				continue
			var option: OptionButton = (entry as Dictionary)["option"]
			var edit: LineEdit = (entry as Dictionary)["edit"]
			var current: String = EventSheetWords.word_for(key, familiar, EventSheetWords.overrides())
			var offered: PackedStringArray = EventSheetWords.choices(key)
			var found: int = -1
			for index: int in offered.size():
				if offered[index] == current:
					found = index
					break
			if found >= 0:
				option.select(option.get_item_index(found))
				edit.visible = false
			else:
				option.select(option.get_item_index(_CUSTOM_ID))
				edit.visible = true
				edit.text = current
	_refresh_preset()
	_refresh_preview(familiar_now)


## The preset row follows the switches rather than remembering a choice of its own, so a Familiar
## Words flip made from the View menu shows up here as the vocabulary it actually produced.
func _refresh_preset() -> void:
	if _preset_option == null:
		return
	var current: String = EventSheetWords.preset()
	var index: int = EventSheetWords.PRESETS.find(current)
	if index >= 0:
		_preset_option.select(_preset_option.get_item_index(index))
	if _preset_note != null:
		_preset_note.text = _preset_description(current)


func _preset_description(preset: String) -> String:
	match preset:
		EventSheetWords.PRESET_GODOT:
			return "Godot's own words throughout - the nouns and the verbs the engine uses."
		EventSheetWords.PRESET_FAMILIAR:
			return "The nouns in the sheet's words (Family, Layout); the verbs stay Godot's."
		EventSheetWords.PRESET_SHEET:
			return "The nouns AND the verbs in the sheet's words - a row reads Create object where Godot says Spawn A Copy. The Godot spelling stays beside it in the picker, and the code panel and the tooltips never change."
	return "Your own mixture - a word you typed, or one half of a preset. Pick one above to go back to a named vocabulary."


func _on_preset_selected(index: int) -> void:
	if index < 0 or index >= EventSheetWords.PRESETS.size():
		return
	var chosen: String = EventSheetWords.PRESETS[index]
	# "custom" is what the switches ADD UP TO, never a thing to apply: picking it changes nothing
	# and the row snaps back to whatever the vocabulary actually is.
	if chosen != EventSheetWords.PRESET_CUSTOM:
		EventSheetWords.apply_preset(chosen)
	refresh()
	words_changed.emit()


func _refresh_preview(familiar: bool) -> void:
	if _preview_condition == null or _preview_action == null:
		return
	var override_map: Dictionary = EventSheetWords.overrides()
	var set_word: String = EventSheetWords.word_for("inheritance_set", familiar, override_map)
	var destroy_word: String = EventSheetWords.word_for("destroy", familiar, override_map)
	_preview_condition.text = "⟳  System ▸ For each  Enemy  %s" % set_word.to_lower()
	_preview_action.text = "Enemy ▸ %s" % destroy_word
	if _preview_verbs != null:
		_preview_verbs.text = "System ▸ %s      Player ▸ %s Bullet" % [
			EventSheetWords.verb_name_words("Core::OnProcess", "Every Frame"),
			EventSheetWords.verb_row_words("Core::SpawnNewCopy", "Spawn a copy of"),
		]


func _on_choice(key: String, familiar: bool) -> void:
	var entry: Variant = _rows.get("%s|%s" % [key, EventSheetWords.state_key(familiar)], null)
	if not (entry is Dictionary):
		return
	var option: OptionButton = (entry as Dictionary)["option"]
	var edit: LineEdit = (entry as Dictionary)["edit"]
	var chosen_id: int = option.get_selected_id()
	if chosen_id == _CUSTOM_ID:
		edit.visible = true
		EventSheetWords.set_word(key, familiar, edit.text)
	else:
		var offered: PackedStringArray = EventSheetWords.choices(key)
		if chosen_id >= 0 and chosen_id < offered.size():
			edit.visible = false
			EventSheetWords.set_word(key, familiar, offered[chosen_id])
	_refresh_preview(EventSheetWords.familiar_words_enabled())
	words_changed.emit()


func _on_reset_pressed() -> void:
	EventSheetWords.reset()
	refresh()
	words_changed.emit()


## Emitted whenever a word changes, so the dock can rebuild the open views (words are baked into
## row text at build time - a redraw is not enough).
signal words_changed
