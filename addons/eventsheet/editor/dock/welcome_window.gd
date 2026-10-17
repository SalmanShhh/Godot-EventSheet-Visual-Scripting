@tool
class_name EventSheetWelcomeWindow
extends RefCounted

# First-run welcome / onboarding window (Tools ▸ Welcome…).
#
# Shown once per project on first run (tracked in editor metadata - nothing committed), and
# reopenable any time from Tools → Welcome or the command palette. Lazily builds a content-sized
# dialog: the band that says what the plugin is, then cards for the one question, Get Started and
# Preferences, and the help strip that says what the chosen answer would set. Apply commits it.
#
# Extracted from event_sheet_dock.gd so the dock stays focused. The dock owns one instance, calls
# init(self), and keeps two thin delegates (show_welcome / show_welcome_if_first_run) so the menu,
# the command palette, and the plugin's startup hook all keep calling the dock unchanged. The window
# parents itself on the dock and reaches back through the dock reference for the showcase-open guard,
# the starter-template menu, and the Simple-mode toggle.

## The three answers to "how do you usually make games?", and exactly what each one sets. One table,
## read by the buttons, the line that says what changed, and the tests - so the promise the card
## makes and the settings it writes cannot drift apart. Every value is an existing, reversible
## setting: the card invents no mode of its own.
const CAME_FROM_NEW := "new"
const CAME_FROM_SHEETS := "sheets"
const CAME_FROM_GDSCRIPT := "gdscript"
const CAME_FROM_CHOICES: Array[String] = [CAME_FROM_NEW, CAME_FROM_SHEETS, CAME_FROM_GDSCRIPT]
## Where "this project has been welcomed" is kept. Spelled once, in a file that names nothing, so
## the workspace can ask the same question on every first open without compiling this window.
const DOCK_REGISTRY := preload("res://addons/eventsheet/api/dock_registry.gd")
## The Classic sheet starter's own file - the look another event-sheet editor's users already know.
const CLASSIC_THEME_PATH := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
## The guide a reader from another event-sheet editor is handed, opened in the Manual.
const MIGRATION_GUIDE_ID := "GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR"

var _dock: Control = null
var _welcome_window: ConfirmationDialog = null
var _simple_check: CheckBox = null
var _native_check: CheckBox = null
var _language_picker: OptionButton = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _sets_value: Label = null
## The answer buttons by choice, and the answer chosen but not yet applied ("" for none).
var _answers: Dictionary = {}
var _picked: String = ""


## What one answer sets: {label, note, words, theme, project_bar, code_panel, guide, tour}. `theme` is a
## theme file ("" keeps the editor-matching default); `words` is a words preset name.
static func choice_settings(choice: String) -> Dictionary:
	match choice:
		CAME_FROM_SHEETS:
			return {"label": "I come from another event-sheet editor",
				"words": EventSheetWords.PRESET_SHEET, "theme": CLASSIC_THEME_PATH, "project_bar": true,
				"code_panel": false, "guide": MIGRATION_GUIDE_ID, "tour": false}
		CAME_FROM_GDSCRIPT:
			return {"label": "I write GDScript",
				"words": EventSheetWords.PRESET_GODOT, "theme": "", "project_bar": false,
				"code_panel": true, "guide": "", "tour": false}
	return {"label": "I'm new to event sheets",
		"words": EventSheetWords.PRESET_FAMILIAR, "theme": "", "project_bar": false,
		"code_panel": false, "guide": "", "tour": true}


## The one line under the choices that says what an answer changed and where each thing lives, so
## nothing it set is a mystery to find later.
static func choice_summary(choice: String) -> String:
	var settings: Dictionary = choice_settings(choice)
	var said: PackedStringArray = PackedStringArray()
	said.append(EventSheetWords.preset_label(str(settings["words"])))
	said.append(EventSheetL10n.translate("Classic sheet theme") if not str(settings["theme"]).is_empty()
		else EventSheetL10n.translate("the editor-matching theme"))
	if bool(settings["project_bar"]):
		said.append(EventSheetL10n.translate("Project bar on"))
	if bool(settings["code_panel"]):
		said.append(EventSheetL10n.translate("the GDScript panel beside every sheet"))
	if not str(settings["guide"]).is_empty():
		said.append(EventSheetL10n.translate("the migration guide open in the Manual"))
	if bool(settings["tour"]):
		said.append(EventSheetL10n.translate("the tour"))
	return EventSheetL10n.translate("Sets: %s. Change any of it later in Settings ▸ Words and the View menu.") % ", ".join(said)


## The SETS line of the help strip: every setting an answer writes, each with the value it gets.
static func choice_sets(choice: String) -> String:
	var settings: Dictionary = choice_settings(choice)
	var on: String = EventSheetL10n.translate("on")
	var off: String = EventSheetL10n.translate("off")
	return EventSheetL10n.translate("words = %s · theme = %s · Project bar = %s · GDScript panel = %s · tour = %s") % [
		EventSheetWords.preset_label(str(settings["words"])),
		EventSheetL10n.translate("Classic sheet") if not str(settings["theme"]).is_empty() else EventSheetL10n.translate("editor"),
		on if bool(settings["project_bar"]) else off, on if bool(settings["code_panel"]) else off,
		on if bool(settings["tour"]) else off]


## Wires the dock reference used to parent the window + reach the Simple-mode / template callbacks.
func init(dock: Control) -> void:
	_dock = dock


## Called by the plugin at startup: first run per project (editor metadata, nothing committed) pops
## the welcome; after that it lives in Tools → Welcome….
func show_if_first_run() -> void:
	if not Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	var welcomed: Array = DOCK_REGISTRY.WELCOMED_METADATA
	if bool(editor_settings.get_project_metadata(welcomed[0], welcomed[1], false)):
		return
	editor_settings.set_project_metadata(welcomed[0], welcomed[1], true)
	# First run in a project starts in Simple Mode (the Welcome's checkbox shows it checked): the
	# newcomer surface should be the default surface, and the toolbar's Simple Mode pill makes
	# flipping to Expert one visible click - so experts lose seconds, beginners gain a fighting start.
	_dock.set_simple_mode(true)
	show()


func show() -> void:
	if _welcome_window == null:
		_build()
	# The checkboxes reflect the CURRENT settings on every open, not first-run state.
	_native_check.set_pressed_no_signal(bool(ProjectSettings.get_setting("eventsheets/editor/open_code_panel_by_default", false)))
	_simple_check.set_pressed_no_signal(_dock._simple_mode)
	# The answer the project gave last time is the one shown, and nothing is applied until Apply.
	_pick(_remembered_choice())
	# Rescan the translation folders on every open, so "drop a CSV in, open the Welcome" is the
	# whole flow for a new language - no registration step, no restart.
	EventSheetL10n.rescan()
	_refresh_language_picker()
	# Collapse the content-fitting dialog to its real minimum size FIRST, so popup_centered has the
	# final dimensions to center against - without this, the first open centers on a pre-layout
	# (too-small) size and the content then expands down-and-right, leaving the window off-centre.
	_welcome_window.reset_size()
	_welcome_window.popup_centered()


## A content-sized dialog, so the window fits what it holds; every label wraps inside a fixed width.
## Close leaves everything as it was; Apply commits the chosen answer.
func _build() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = EventSheetL10n.translate("Welcome - set EventSheets up for how you work")
	dialog.ok_button_text = EventSheetL10n.translate("Apply")
	dialog.cancel_button_text = EventSheetL10n.translate("Close")
	dialog.confirmed.connect(func() -> void:
		if not _picked.is_empty():
			apply_choice(_picked))
	_welcome_window = dialog
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(460.0), 0.0)
	# What the plugin is, as the band across the top: one sentence, not a card of its own.
	var band: EventSheetPopupUI.RowBand = EventSheetPopupUI.RowBand.new()
	band.show_row("", EventSheetL10n.translate("Event sheets that compile to plain GDScript - zero runtime, performance parity, and every sheet shows you its honest generated code."))
	band.words_label.clip_text = false
	band.words_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	band.words_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	band.words_label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(440.0), 0.0)
	box.add_child(band)
	# The one question that sets the words, the look and the panels a reader already expects,
	# instead of three settings in three menus they would have to know existed.
	box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("How do you usually make games?"), _build_came_from()))
	# The four doors, two by two, so the window keeps its width.
	var start_grid: GridContainer = GridContainer.new()
	start_grid.columns = 2
	for door: Array in [
		["Take the 2-minute tour", func() -> void: _dock.start_tour()],
		# The game most event-sheet users built first, rebuilt row by row - ten steps on the same
		# tour window, ending at the finished showcase.
		["Build a top-down shooter (10 steps)", func() -> void: EventSheets.start_tour(EventSheetShooterTour.steps())],
		["Open the playable showcase scene", func() -> void:
			var showcase_scene: String = EventForgePlugin._find_showcase_scene()
			if Engine.is_editor_hint() and _dock.is_inside_tree() and not showcase_scene.is_empty():
				EditorInterface.open_scene_from_path(showcase_scene)],
		["New sheet from a starter template", func() -> void: _dock._open_template_menu()],
	]:
		var door_button: Button = Button.new()
		door_button.text = EventSheetL10n.translate(str(door[0]))
		door_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var go: Callable = door[1]
		door_button.pressed.connect(func() -> void:
			_welcome_window.hide()
			go.call())
		start_grid.add_child(door_button)
	box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Get Started"), start_grid))
	# Surface the Simple/Expert choice on the one newcomer-guaranteed surface (the Welcome). Simple Mode is the
	# canonical audience flag but is otherwise off-by-default and menu-buried.
	var prefs_box: VBoxContainer = EventSheetPopupUI.form_box()
	_simple_check = CheckBox.new()
	_simple_check.text = "Simple mode - hide advanced rows & menu items"
	_simple_check.tooltip_text = EventSheetL10n.translate("New to event sheets? Simple mode keeps the picker and menus to the essentials. Everything still works in Expert mode - toggle any time in View → Simple Mode.")
	_simple_check.toggled.connect(func(on: bool) -> void: _dock.set_simple_mode(on))
	prefs_box.add_child(_simple_check)
	_native_check = CheckBox.new()
	_native_check.text = "Open the GDScript panel with every sheet"
	_native_check.tooltip_text = EventSheetL10n.translate("The Godot-native default: every sheet opens with its generated script beside it (eventsheets/editor/open_code_panel_by_default).")
	_native_check.toggled.connect(func(on: bool) -> void:
		ProjectSettings.set_setting("eventsheets/editor/open_code_panel_by_default", true if on else null))
	prefs_box.add_child(_native_check)
	# Editor language: English by default; every locale a drop-in translation file provides is
	# offered automatically (see editor/l10n.gd for the file format + folders). Switching applies
	# live to auto-translated Controls; some already-drawn text refreshes on the next open/redraw.
	_language_picker = OptionButton.new()
	_language_picker.tooltip_text = "Translations are plain CSV files - drop one into eventsheet_translations/ and its language appears here."
	_language_picker.item_selected.connect(_on_language_selected)
	prefs_box.add_child(EventSheetPopupUI.form_row("Editor language", _language_picker))
	# Extension preferences (EventSheets.register_preference): each builder returns one Control
	# row - extensions get a settings home without inventing their own dialog.
	for preference_builder: Callable in EventSheets.preference_builders():
		if preference_builder.is_valid():
			var preference_row: Variant = preference_builder.call()
			if preference_row is Control:
				prefs_box.add_child(preference_row)
	box.add_child(EventSheetPopupUI.titled_card("Preferences", prefs_box))
	# Somebody hitting a bug on day one should not have to work out where the project lives. The
	# Tools menu carries the same action for people already past the Welcome.
	var issue_row: HBoxContainer = HBoxContainer.new()
	issue_row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var issue_label: Label = Label.new()
	issue_label.text = "Something not working right?"
	issue_label.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	issue_row.add_child(issue_label)
	var issue_button: Button = Button.new()
	issue_button.text = "Report an issue"
	issue_button.flat = true
	issue_button.tooltip_text = EventSheetL10n.translate("Opens the plugin's issue tracker in your browser, with your Godot and plugin versions pre-filled.")
	issue_button.pressed.connect(func() -> void: _dock._report_issue())
	issue_row.add_child(issue_button)
	var reopen: Label = Label.new()
	reopen.text = "Reopen this window any time: Tools → Welcome…"
	reopen.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	reopen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reopen.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	issue_row.add_child(reopen)
	box.add_child(issue_row)
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(440.0))
	_sets_value = _strip.add_line(EventSheetL10n.translate("SETS"))
	box.add_child(_strip)
	dialog.add_child(EventSheetPopupUI.margined(box))
	_dock.add_child(dialog)


## The three answers as toggle buttons in one group. Pressing one CHOOSES it - the strip says what it
## would set - and Apply is what sets it; the answer is remembered per project, so the card opens on
## it next time.
func _build_came_from() -> VBoxContainer:
	var card: VBoxContainer = EventSheetPopupUI.form_box()
	var group: ButtonGroup = ButtonGroup.new()
	for choice: String in CAME_FROM_CHOICES:
		var answer: Button = Button.new()
		answer.text = EventSheetL10n.translate(str(choice_settings(choice)["label"]))
		answer.toggle_mode = true
		answer.button_group = group
		answer.alignment = HORIZONTAL_ALIGNMENT_LEFT
		answer.pressed.connect(_pick.bind(choice))
		_answers[choice] = answer
		card.add_child(answer)
	return card


## Chooses an answer without applying it: the button shows pressed and the strip says what Apply
## would set. "" is no answer yet.
func _pick(choice: String) -> void:
	_picked = choice
	for key: String in _answers:
		(_answers[key] as Button).set_pressed_no_signal(key == choice)
	_welcome_window.get_ok_button().disabled = choice.is_empty()
	if choice.is_empty():
		_strip.describe(EventSheetL10n.translate("This answer"),
			EventSheetL10n.translate("Pick one - it sets the words, the look and the panels, and each stays changeable."))
		_strip.set_line(_sets_value, "")
		return
	_strip.describe(EventSheetL10n.translate("This answer"), choice_summary(choice))
	_strip.set_line(_sets_value, choice_sets(choice))


## Applies one answer through the settings the rest of the editor already owns.
func apply_choice(choice: String) -> void:
	var settings: Dictionary = choice_settings(choice)
	EventSheetWords.apply_preset(str(settings["words"]))
	if _dock != null and _dock.get("_theme_manager") != null:
		var theme_path: String = str(settings["theme"])
		if theme_path.is_empty():
			_dock._theme_manager.use_default_theme()
		else:
			_dock._theme_manager.load_theme_style_from_path(theme_path)
		_dock._theme_manager._refresh_theme_menu_selection()
	if bool(settings["project_bar"]):
		# The reader told us which surfaces they expect; View ▸ Project bar takes it away again.
		EventSheetProjectBarGlue.mark_started_from_template()
		if _dock != null:
			_dock._project_bar_glue.apply_visibility()
	ProjectSettings.set_setting("eventsheets/editor/open_code_panel_by_default",
		true if bool(settings["code_panel"]) else null)
	if Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		EditorInterface.get_editor_settings().set_project_metadata("eventsheets", "came_from", choice)
	if not str(settings["guide"]).is_empty():
		EventSheets.open_docs(str(settings["guide"]))
	if bool(settings["tour"]) and _dock != null and _welcome_window != null:
		_welcome_window.hide()
		_dock.start_tour()


func _remembered_choice() -> String:
	if not Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return ""
	return str(EditorInterface.get_editor_settings().get_project_metadata("eventsheets", "came_from", ""))


## Fills the language picker from the discovered locales (English first, then one entry per
## locale a translation file provided) and selects the active one.
func _refresh_language_picker() -> void:
	_language_picker.clear()
	var locales: PackedStringArray = EventSheetL10n.available_locales()
	var active: String = EventSheetL10n.get_locale()
	for index: int in range(locales.size()):
		_language_picker.add_item(EventSheetL10n.locale_display_name(locales[index]), index)
		if locales[index] == active:
			_language_picker.select(index)


## Applies the picked language live: auto-translated Controls retranslate on the propagated
## notification; canvas-drawn text follows on its next redraw.
func _on_language_selected(index: int) -> void:
	var locales: PackedStringArray = EventSheetL10n.available_locales()
	if index < 0 or index >= locales.size():
		return
	EventSheetL10n.set_locale(locales[index])
	_dock.propagate_notification(MainLoop.NOTIFICATION_TRANSLATION_CHANGED)
	if _dock.get_viewport_control() != null:
		_dock.get_viewport_control().queue_redraw()
	_dock._set_status("Editor language: %s" % EventSheetL10n.locale_display_name(locales[index]))
