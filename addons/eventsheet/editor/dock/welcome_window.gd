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

var _dock: Control = null
var _welcome_window: Window = null


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
	var start_box: VBoxContainer = EventSheetPopupUI.form_box()
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
	box.add_child(EventSheetPopupUI.titled_card("Preferences", prefs_box))
	# Footer migration/reopen note - a muted, width-bounded hint at the bottom (not its own card).
	box.add_child(EventSheetPopupUI.hint_label("Coming from another event-sheet tool? The migration guide maps the vocabulary.\nReopen this window any time: Tools → Welcome…", 440.0))
	dialog.add_child(EventSheetPopupUI.margined(box))
	_dock.add_child(dialog)
