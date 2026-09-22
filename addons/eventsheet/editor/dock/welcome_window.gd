@tool
class_name EventSheetWelcomeWindow
extends RefCounted

# First-run welcome / onboarding window (Tools ▸ Welcome…).
#
# Shown once per project on first run (tracked in editor metadata - nothing committed), and
# reopenable any time from Tools → Welcome or the command palette. Lazily builds an AcceptDialog
# (so it sizes itself to the content) grouped into themed cards: About / Get Started / Preferences.
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
## The Classic sheet starter's own file - the look another event-sheet editor's users already know.
const CLASSIC_THEME_PATH := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
## The guide a reader from another event-sheet editor is handed, opened in the Manual.
const MIGRATION_GUIDE_ID := "GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR"

var _dock: Control = null
var _welcome_window: Window = null


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
	said.append("Classic sheet theme" if not str(settings["theme"]).is_empty() else "the editor-matching theme")
	if bool(settings["project_bar"]):
		said.append("Project bar on")
	if bool(settings["code_panel"]):
		said.append("the GDScript panel beside every sheet")
	if not str(settings["guide"]).is_empty():
		said.append("the migration guide open in the Manual")
	if bool(settings["tour"]):
		said.append("the tour")
	return "Sets: %s. Change any of it later in Settings ▸ Words and the View menu." % ", ".join(said)


## Wires the dock reference used to parent the window + reach the Simple-mode / template callbacks.
func init(dock: Control) -> void:
	_dock = dock


## Called by the plugin at startup: first run per project (editor metadata, nothing committed) pops
## the welcome; after that it lives in Tools → Welcome….
func show_if_first_run() -> void:
	if not Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if bool(editor_settings.get_project_metadata("eventsheets", "welcomed", false)):
		return
	editor_settings.set_project_metadata("eventsheets", "welcomed", true)
	# First run in a project starts in Simple Mode (the Welcome's checkbox shows it checked): the
	# newcomer surface should be the default surface, and the toolbar's Simple Mode pill makes
	# flipping to Expert one visible click - so experts lose seconds, beginners gain a fighting start.
	_dock.set_simple_mode(true)
	show()


func show() -> void:
	if _welcome_window == null:
		_build()
	# The checkboxes reflect the CURRENT settings on every open, not first-run state.
	var native_check: CheckBox = _welcome_window.get_meta("native_check") as CheckBox
	if native_check != null:
		native_check.set_pressed_no_signal(bool(ProjectSettings.get_setting("eventsheets/editor/open_code_panel_by_default", false)))
	var simple_check: CheckBox = _welcome_window.get_meta("simple_check") as CheckBox
	if simple_check != null:
		simple_check.set_pressed_no_signal(_dock._simple_mode)
	# Rescan the translation folders on every open, so "drop a CSV in, open the Welcome" is the
	# whole flow for a new language - no registration step, no restart.
	EventSheetL10n.rescan()
	_refresh_language_picker()
	# Collapse the content-fitting AcceptDialog to its real minimum size FIRST, so popup_centered has
	# the final dimensions to center against - without this, the first open centers on a pre-layout
	# (too-small) size and the content then expands down-and-right, leaving the window off-centre.
	_welcome_window.reset_size()
	_welcome_window.popup_centered()


## An AcceptDialog so the window sizes itself to the content (the hand-sized Window of the first two
## cuts clipped buttons and text at the edges); every label wraps inside a fixed content width.
func _build() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Godot EventSheets - welcome"
	dialog.ok_button_text = "Close"
	_welcome_window = dialog
	# Themed onboarding: a form_box of titled_card sections (matching the picker / variable /
	# function dialogs) wrapped in margined() so it doesn't touch the window edges. The outer box
	# carries the 440px width-bound that previously sat on the flat content VBox, so the
	# content-sized AcceptDialog keeps the same width.
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.custom_minimum_size = Vector2(440.0, 0.0)
	var about_box: VBoxContainer = EventSheetPopupUI.form_box()
	var blurb: Label = Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Width-bound the autowrap label itself: the parent box's custom_minimum_size.x does NOT bound a
	# child's min-height pass, so without this the label wraps to one glyph per line at width 0 and
	# balloons this AcceptDialog (it sizes to content min) to thousands of px tall on first launch.
	blurb.custom_minimum_size = Vector2(440.0, 0.0)
	blurb.text = "Event sheets that compile to plain GDScript - zero runtime, performance parity, and every sheet shows you its honest generated code."
	about_box.add_child(blurb)
	box.add_child(EventSheetPopupUI.titled_card("About EventSheets", about_box))
	# The one question that sets the words, the look and the panels a reader already expects,
	# instead of three settings in three menus they would have to know existed.
	box.add_child(EventSheetPopupUI.titled_card("How do you usually make games?", _build_came_from()))
	var start_box: VBoxContainer = EventSheetPopupUI.form_box()
	# The first-time walkthrough - a floating 6-step tour of the core loop, done in the live editor.
	var tour_button: Button = Button.new()
	tour_button.text = "Take the 2-minute tour"
	tour_button.pressed.connect(func() -> void:
		_welcome_window.hide()
		_dock.start_tour())
	start_box.add_child(tour_button)
	var showcase_button: Button = Button.new()
	showcase_button.text = "Open the playable showcase scene"
	showcase_button.pressed.connect(func() -> void:
		var showcase_scene: String = EventForgePlugin._find_showcase_scene()
		if Engine.is_editor_hint() and _dock.is_inside_tree() and not showcase_scene.is_empty():
			EditorInterface.open_scene_from_path(showcase_scene)
		_welcome_window.hide())
	start_box.add_child(showcase_button)
	var starter_button: Button = Button.new()
	starter_button.text = "New sheet from a starter template"
	starter_button.pressed.connect(func() -> void:
		_welcome_window.hide()
		_dock._open_template_menu())
	start_box.add_child(starter_button)
	box.add_child(EventSheetPopupUI.titled_card("Get Started", start_box))
	# Surface the Simple/Expert choice on the one newcomer-guaranteed surface (the Welcome). Simple Mode is the
	# canonical audience flag but is otherwise off-by-default and menu-buried.
	var prefs_box: VBoxContainer = EventSheetPopupUI.form_box()
	var simple_check: CheckBox = CheckBox.new()
	simple_check.text = "Simple mode - hide advanced rows & menu items"
	simple_check.tooltip_text = "New to event sheets? Simple mode keeps the picker and menus to the essentials. Everything still works in Expert mode - toggle any time in View → Simple Mode."
	simple_check.toggled.connect(func(on: bool) -> void: _dock.set_simple_mode(on))
	prefs_box.add_child(simple_check)
	_welcome_window.set_meta("simple_check", simple_check)
	var native_check: CheckBox = CheckBox.new()
	native_check.text = "Open the GDScript panel with every sheet"
	native_check.tooltip_text = "The Godot-native default: every sheet opens with its generated script beside it (eventsheets/editor/open_code_panel_by_default)."
	native_check.toggled.connect(func(on: bool) -> void:
		ProjectSettings.set_setting("eventsheets/editor/open_code_panel_by_default", true if on else null))
	prefs_box.add_child(native_check)
	_welcome_window.set_meta("native_check", native_check)
	# Editor language: English by default; every locale a drop-in translation file provides is
	# offered automatically (see editor/l10n.gd for the file format + folders). Switching applies
	# live to auto-translated Controls; some already-drawn text refreshes on the next open/redraw.
	var language_row: HBoxContainer = HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 8)
	var language_label: Label = Label.new()
	language_label.text = "Editor language"
	language_row.add_child(language_label)
	var language_picker: OptionButton = OptionButton.new()
	language_picker.tooltip_text = "Translations are plain CSV files - drop one into eventsheet_translations/ and its language appears here."
	language_picker.item_selected.connect(_on_language_selected)
	language_row.add_child(language_picker)
	prefs_box.add_child(language_row)
	_welcome_window.set_meta("language_picker", language_picker)
	# Extension preferences (EventSheets.register_preference): each builder returns one Control
	# row - extensions get a settings home without inventing their own dialog.
	for preference_builder: Callable in EventSheets.preference_builders():
		if preference_builder.is_valid():
			var preference_row: Variant = preference_builder.call()
			if preference_row is Control:
				prefs_box.add_child(preference_row)
	box.add_child(EventSheetPopupUI.titled_card("Preferences", prefs_box))
	# Second footer row: somebody hitting a bug on day one should not have to work out where the
	# project lives. The Tools menu carries the same action for people already past the Welcome.
	var issue_row: HBoxContainer = HBoxContainer.new()
	issue_row.add_theme_constant_override("separation", 8)
	var issue_label: Label = Label.new()
	issue_label.text = "Something not working right?"
	issue_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.65))
	issue_row.add_child(issue_label)
	var issue_button: Button = Button.new()
	issue_button.text = "Report an issue"
	issue_button.flat = true
	issue_button.tooltip_text = "Opens the plugin's issue tracker in your browser, with your Godot and plugin versions pre-filled."
	issue_button.pressed.connect(func() -> void: _dock._report_issue())
	issue_row.add_child(issue_button)
	box.add_child(issue_row)
	box.add_child(EventSheetPopupUI.hint_label("Reopen this window any time: Tools → Welcome…", 440.0))
	dialog.add_child(EventSheetPopupUI.margined(box))
	_dock.add_child(dialog)


## The three answers as toggle buttons in one group, and the line that says what the pressed one set.
## Pressing an answer applies it at once; the answer is remembered per project, so the card opens on
## it next time.
func _build_came_from() -> VBoxContainer:
	var card: VBoxContainer = EventSheetPopupUI.form_box()
	var group: ButtonGroup = ButtonGroup.new()
	var summary: Label = EventSheetPopupUI.hint_label("", 440.0)
	var remembered: String = _remembered_choice()
	for choice: String in CAME_FROM_CHOICES:
		var answer: Button = Button.new()
		answer.text = str(choice_settings(choice)["label"])
		answer.toggle_mode = true
		answer.button_group = group
		answer.alignment = HORIZONTAL_ALIGNMENT_LEFT
		answer.tooltip_text = choice_summary(choice)
		answer.set_pressed_no_signal(choice == remembered)
		answer.pressed.connect(func() -> void:
			summary.text = choice_summary(choice)
			apply_choice(choice))
		card.add_child(answer)
	summary.text = choice_summary(remembered) if not remembered.is_empty() else "Pick one - it sets the words, the look and the panels, and each stays changeable."
	card.add_child(summary)
	return card


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
	var language_picker: OptionButton = _welcome_window.get_meta("language_picker") as OptionButton
	if language_picker == null:
		return
	language_picker.clear()
	var locales: PackedStringArray = EventSheetL10n.available_locales()
	var active: String = EventSheetL10n.get_locale()
	for index: int in range(locales.size()):
		language_picker.add_item(EventSheetL10n.locale_display_name(locales[index]), index)
		if locales[index] == active:
			language_picker.select(index)


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
