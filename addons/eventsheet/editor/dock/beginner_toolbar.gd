@tool
class_name EventSheetBeginnerToolbar
extends RefCounted

# THE BEGINNER TOOLBAR. The eight Add gestures as buttons, above the canvas, on in Simple mode
# and off otherwise (View ▸ Add toolbar turns it on by hand at any time).
#
# Adding things is keys, the Add menu, right-click and the Ghost Row - all of which a beginner on day
# one has to be told about. Buttons are how they add something on the first afternoon, and each one
# names its KEY on hover, so the strip teaches the shortcut it is standing in for and makes itself
# unnecessary.
#
# It calls the same add paths everything else does. There is no second way to add anything here.
#
# IT IS AN ADD TOOLBAR, and only that. It used to end with the run buttons too - "how do I add
# something" and "how do I see it run" asked side by side - and that made a second place to start a
# game, one strip below the first. The one run control is the play button at the head of the strip:
# one face for the run this project chose, one dropdown for all six ways to play. Nothing was lost
# in moving them out; there is simply one of them now, where a reader already looks for it.

## The strip, in reading order, as [id, label, action id whose key it shows, what it does].
## The action id is looked up in EventSheetShortcuts, so a rebound key shows its NEW binding.
const BUTTONS: Array = [
	["add_event", "+ Event", "add_event", "Start a new event."],
	["add_sub_event", "+ Sub-event", "add_sub_condition", "Add an event under the selected one - it only runs when its parent does."],
	["add_condition", "+ Condition", "add_condition", "Add a condition to the selected event - one more thing that has to be true."],
	["add_action", "+ Action", "add_action", "Add an action to the selected event - one more thing it does."],
	["add_group", "+ Group", "add_group", "Wrap events in a named group you can collapse."],
	["add_comment", "+ Comment", "add_comment", "Write a note in the sheet."],
	["add_variable", "+ Variable", "add_variable", "Add a global variable - one value the whole project shares."],
	["add_function", "+ Function", "", "Add a function - actions you can call from anywhere by name."],
]

var _dock: Control = null
var _strip: HFlowContainer = null


func init(dock: Control) -> void:
	_dock = dock


## The tooltip a button wears: what it does, then the key that does the same thing. A button whose
## gesture has no key of its own simply says what it does.
static func tooltip_for(button_id: String) -> String:
	for entry: Variant in BUTTONS:
		var record: Array = entry
		if str(record[0]) != button_id:
			continue
		var what: String = EventSheetL10n.translate(str(record[3]))
		var action: String = str(record[2])
		if action.is_empty():
			return what
		var binding: String = EventSheetShortcuts.binding_for(action)
		return what if binding.is_empty() else "%s  (%s)" % [what, binding]
	return ""


## Builds the strip and inserts it directly above the canvas. Kept hidden until the visibility rule
## asks for it, so an expert's sheet is the sheet.
func build(root: Node) -> Control:
	_strip = HFlowContainer.new()
	_strip.name = "EventSheetBeginnerToolbar"
	_strip.add_theme_constant_override("h_separation", 4)
	_strip.visible = false
	for entry: Variant in BUTTONS:
		var record: Array = entry
		var button := Button.new()
		button.text = EventSheetL10n.translate(str(record[1]))
		button.tooltip_text = tooltip_for(str(record[0]))
		button.pressed.connect(activate.bind(str(record[0])))
		_strip.add_child(button)
	root.add_child(_strip)
	return _strip


## Every button calls the add path the menus and the keys already call.
func activate(button_id: String) -> void:
	match button_id:
		"add_event":
			_dock._on_add_event_requested()
		"add_sub_event":
			_dock._on_add_sub_condition_key()
		"add_condition":
			_dock._on_add_condition_requested()
		"add_action":
			_dock._on_add_action_requested()
		"add_group":
			_dock._on_add_group_requested()
		"add_comment":
			_dock._on_add_comment_requested()
		"add_variable":
			_dock._on_add_project_global_requested()
		"add_function":
			_dock._open_function_dialog()


## Whether the strip should be showing: an explicit View ▸ Add toolbar choice wins, and with no
## choice on record Simple mode decides.
static func should_show(explicit: Variant, simple_mode: bool) -> bool:
	if explicit is bool:
		return explicit
	return simple_mode


const _META_KEY: String = "eventsheets_add_toolbar_shown"


func apply_visibility() -> void:
	if _strip == null:
		return
	var chosen: Variant = EventSheetEditorSettings.stored_flag(_META_KEY)
	_strip.visible = should_show(chosen, _dock.is_simple_mode())
	_refresh_tooltips()
	_sync_view_menu(_strip.visible)


func set_shown(shown: bool) -> void:
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", _META_KEY, shown)
	apply_visibility()
	_dock._set_status("Add toolbar on - the eight ways to add something, each with its key on hover." if shown
		else "Add toolbar hidden. View ▸ Add toolbar brings it back.")


## Re-reads every key, so rebinding one (or applying a shortcuts preset) shows through immediately.
func _refresh_tooltips() -> void:
	if _strip == null:
		return
	for index: int in BUTTONS.size():
		var button: Node = _strip.get_child(index)
		if button is Button:
			(button as Button).tooltip_text = tooltip_for(str((BUTTONS[index] as Array)[0]))


func _sync_view_menu(shown: bool) -> void:
	if _dock._view_popup == null:
		return
	var index: int = _dock._view_popup.get_item_index(_dock.ADD_TOOLBAR_VIEW_ID)
	if index >= 0:
		_dock._view_popup.set_item_checked(index, shown)
