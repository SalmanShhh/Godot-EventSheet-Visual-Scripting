@tool
class_name EventSheetPlayButton
extends RefCounted

# THE PLAY BUTTON: one face, six ways to play.
#
# Godot has no split-button control, so this is two adjacent controls reading as one - a face Button
# beside a narrow dropdown MenuButton, both inside a single PanelContainer so one frame draws around
# the pair. Nothing here is custom-drawn and nothing is a new widget: a Button, a MenuButton and the
# PopupMenu that MenuButton already owns.
#
# The face performs the run this project CHOSE (Run Scene until somebody says otherwise, remembered
# in the editor's per-project metadata beside every other per-project editor choice), wearing that
# run's own words and icon. While a game is running it reads Stop, because the face is adopted by
# the run controls exactly like every other run button on the strip - one source of truth for what a
# run is called right now.
#
# The dropdown lists all six: the four the sheet owns, then Godot's own F6 and F5 under their own
# heading, then "Main button" - the same six again, ticked - so the choice is made where it is read.
# Every key printed here comes from the ONE shortcut table, so a rebind shows through without an
# edit in this file, and every entry hands its run to EventSheetRunControls. There is no second way
# to start a game in here.


## This file's own path, so a control it builds can say where it was built - the same mark every
## button on the strip carries. Written out rather than derived, because a RefCounted helper has no
## script path to ask for at the point it matters.
const THIS_FILE_PATH: String = "res://addons/eventsheet/editor/dock/play_button.gd"

## The dropdown's own ids. A run is its index in the ways-to-play table; the Main button submenu and
## its ticks sit past the end of that table, so the two popups never share a number however the
## table grows.
const MAIN_SUBMENU_ID: int = 90
const CHOICE_ID_BASE: int = 100

var _dock: Control = null
var _run_controls: EventSheetRunControls = null
var _face: Button = null
var _menu: MenuButton = null
var _choices: PopupMenu = null


## Fills the strip's play slot with the split button. The slot is built by the toolbar in its
## resting position, so nothing about the strip's order has to move to make room here.
func build(slot: HBoxContainer, dock: Control) -> void:
	_dock = dock
	_run_controls = dock._run_controls
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "EventSheetPlayButton"
	slot.add_child(frame)
	var pair: HBoxContainer = HBoxContainer.new()
	pair.add_theme_constant_override("separation", 0)
	frame.add_child(pair)
	_face = Button.new()
	_face.name = "EventSheetPlayFace"
	_face.flat = true
	# The face runs whatever it currently says it runs, asked at press time rather than bound once:
	# the choice can change under it, and a bound id would keep running the old one.
	_face.pressed.connect(func() -> void: _run_controls.activate(_run_controls.main_run_id()))
	EventSheetBuiltHere.mark(_face, THIS_FILE_PATH, "Play")
	pair.add_child(_face)
	_menu = MenuButton.new()
	_menu.name = "EventSheetPlayMenu"
	_menu.text = "▾"
	_menu.flat = true
	# Tab reaches the dropdown too. A MenuButton defaults to FOCUS_ACCESSIBILITY, which the focus
	# ring skips - so the face was keyboard-reachable and the six ways to play behind it were not.
	_menu.focus_mode = Control.FOCUS_ALL
	_menu.tooltip_text = EventSheetL10n.translate("Every way to play this sheet, and which one this button does. The main button is remembered for this project.")
	EventSheetBuiltHere.mark(_menu, THIS_FILE_PATH, "▾")
	pair.add_child(_menu)
	_build_dropdown(_menu.get_popup())
	apply_choice()


## The face, the tick and the run controls put on the same answer. Called after the choice changes
## and once at build time, so a project that chose Debug last week opens wearing it.
func apply_choice() -> void:
	var chosen: String = _run_controls.main_run_id()
	# The face is one adopter among several for its run, and it changes which run it is - so it
	# leaves the old id's list before joining the new one, or a run it no longer performs would keep
	# relabelling it.
	_run_controls.release(_face)
	_run_controls.adopt(chosen, _face)
	_face.icon = _editor_icon(EventSheetRunControls.icon_for(chosen))
	_face.tooltip_text = EventSheetRunControls.tooltip_for(chosen)
	if _choices != null:
		for index: int in EventSheetRunControls.BUTTONS.size():
			var item: int = _choices.get_item_index(CHOICE_ID_BASE + index)
			if item >= 0:
				_choices.set_item_checked(item,
					str((EventSheetRunControls.BUTTONS[index] as Array)[0]) == chosen)
	# The relabel is the run controls' to make: it is the same call that turns every run button on
	# the strip into Stop when a game starts.
	_run_controls.refresh()


## The face's button, for a test or a tutorial step that wants to point at the play control itself.
func face() -> Button:
	return _face


## The dropdown's menu button, whose popup carries the six runs and the Main button submenu.
func menu() -> MenuButton:
	return _menu


func _build_dropdown(popup: PopupMenu) -> void:
	var headed: bool = false
	for index: int in EventSheetRunControls.BUTTONS.size():
		var run_id: String = str((EventSheetRunControls.BUTTONS[index] as Array)[0])
		if not headed and EventSheetRunControls.GODOT_OWN.has(run_id):
			# The two below are Godot's F6 and F5 under the names an event-sheet author reaches for,
			# and nothing else - so they read quieter than the four the sheet owns. A titled
			# separator is how Godot's own menus draw a heading: dimmed, unclickable, no custom
			# chrome anywhere.
			popup.add_separator(EventSheetL10n.translate("Godot's own"))
			headed = true
		_add_run_item(popup, index, index, false)
	popup.add_separator()
	_choices = PopupMenu.new()
	_choices.name = "EventSheetPlayMainChoice"
	popup.add_child(_choices)
	popup.add_submenu_node_item(EventSheetL10n.translate("Main button"), _choices, MAIN_SUBMENU_ID)
	popup.set_item_tooltip(popup.get_item_index(MAIN_SUBMENU_ID),
		EventSheetL10n.translate("Which of these the button beside this arrow does. Remembered for this project."))
	for index: int in EventSheetRunControls.BUTTONS.size():
		_add_run_item(_choices, index, CHOICE_ID_BASE + index, true)
	popup.id_pressed.connect(_on_run_chosen)
	_choices.id_pressed.connect(_on_main_chosen)


## One entry, in either popup: the run's own words, its key printed from the shortcut table, its
## editor icon where the running theme carries one, and its tooltip. The Main button submenu shows
## the same six as radio ticks, which is why the two lists cannot drift apart.
func _add_run_item(popup: PopupMenu, index: int, id: int, as_choice: bool) -> void:
	var record: Array = EventSheetRunControls.BUTTONS[index]
	var run_id: String = str(record[0])
	var text: String = EventSheetL10n.translate(str(record[1]))
	var binding: String = EventSheetShortcuts.binding_for(
		EventSheetRunControls.shortcut_action_for(run_id))
	if not binding.is_empty():
		text = "%s  (%s)" % [text, binding]
	var icon: Texture2D = _editor_icon(EventSheetRunControls.icon_for(run_id))
	if as_choice:
		popup.add_radio_check_item(text, id)
	elif icon != null:
		popup.add_icon_item(icon, text, id)
	else:
		popup.add_item(text, id)
	popup.set_item_tooltip(popup.get_item_index(id), EventSheetRunControls.tooltip_for(run_id))


func _on_run_chosen(id: int) -> void:
	if id < 0 or id >= EventSheetRunControls.BUTTONS.size():
		return
	_run_controls.activate(str((EventSheetRunControls.BUTTONS[id] as Array)[0]))


func _on_main_chosen(id: int) -> void:
	var index: int = id - CHOICE_ID_BASE
	if index < 0 or index >= EventSheetRunControls.BUTTONS.size():
		return
	var record: Array = EventSheetRunControls.BUTTONS[index]
	_run_controls.set_main_run(str(record[0]))
	apply_choice()
	if _dock != null:
		_dock._set_status(EventSheetL10n.translate("The play button runs %s now.")
			% EventSheetL10n.translate(str(record[1])))


## An icon from the running editor theme, or null. Null is a normal answer: a headless run has no
## editor theme at all, and an editor theme without that icon is not an error either - the words on
## the control carry it on their own. Asked through the strip's one icon seam, so a name the theme
## does not ship is handled in exactly one place rather than once per control that wanted it.
static func _editor_icon(icon_name: String) -> Texture2D:
	return EventSheetEditorIcons.icon(icon_name)
