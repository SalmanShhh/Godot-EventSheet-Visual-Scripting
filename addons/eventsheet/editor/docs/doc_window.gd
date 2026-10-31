# EventSheet - EventSheetDocWindow: the Manual, as a window (Tools > Manual..., F1).
#
# The home of the reference surface. A window rather than a tooltip because PERSISTENCE is the
# point: a hover vanishes the moment the reader moves the mouse to the row they are building,
# while this stays open beside the sheet, keeps its scroll position, and follows the selection
# every time F1 or the row menu asks a new question.
#
# It is a thin HOST. Everything readable lives in EventSheetDocBrowser - the guide tree, the
# rendered guide pages and the generated "what does this row do?" panel - so the same control can
# be parented by an editor dock later without this file changing.
#
# NON-MODAL on purpose (`exclusive = false`): the reader keeps editing the sheet with the page
# open, which is exactly the gesture a modal help dialog forbids.
#
# The dock owns one instance and calls open(); the window builds itself on the FIRST open, so a
# session that never asks for documentation never pays for the browser, the figure or the viewport
# behind it. Headless runs never popup - the suite constructs docks freely, and a test that pops
# a real window hangs a CI machine.
@tool
class_name EventSheetDocWindow
extends RefCounted

var _dock: Control = null
var _dialog: AcceptDialog = null
var _browser: EventSheetDocBrowser = null
## The window the reader was working in when the Manual opened over it - the picker, say, when a
## section "?" asked for a page - so closing the Manual hands the focus back to it. Without that the
## OS gives it to the editor's main window, and the picker, still open, takes no hover and so no
## click on its first press.
var _opener: Window = null


## Wires the dock reference used to parent the dialog and to report into the status line.
func init(dock: Control) -> void:
	_dock = dock


## Opens the window on `doc_id` (empty for the index). Returns false when the id names nothing,
## so a caller can say so instead of showing a page that is silently blank.
func open(doc_id: String = "", anchor: String = "") -> bool:
	if DisplayServer.get_name() == "headless":
		# Still answer the routing question truthfully: a test asserts what WOULD be shown - and
		# that includes the registry lookup an "ace:" id needs, because resolve() can only check
		# its shape and a shape-only answer would report a removed verb as documented.
		var route: Dictionary = EventSheetDocExplain.resolve(doc_id)
		if not bool(route.get("valid", false)):
			return false
		if str(route.get("scheme", "")) == "ace":
			return EventSheets.find_ace(str(route.get("provider_id", "")), str(route.get("ace_id", ""))) != null
		return true
	# The reader's chosen home wins. A reader who has docked the documentation asked for it BESIDE
	# the sheet; popping a window over the sheet as well would be answering a question they already
	# answered. A dock that exists but is closed is not a choice, so the window still opens then.
	var docked: EventSheetDocDock = EventSheetDocDock.active_dock()
	if docked != null and docked.is_visible_in_tree():
		return docked.show_documentation(doc_id, anchor)
	_ensure_built()
	if not _browser.show_doc(doc_id, anchor):
		return false
	_dialog.title = _title_for(doc_id)
	if not _dialog.visible:
		_opener = focused_window()
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(900.0)), int(EventSheetPalette.scaled_f(640.0))))
	return true


## The window that holds the keyboard focus now, or null when none of this editor's windows does.
static func focused_window() -> Window:
	for window_id: int in DisplayServer.get_window_list():
		var window: Window = instance_from_id(DisplayServer.window_get_attached_instance_id(window_id)) as Window
		if window != null and window.has_focus():
			return window
	return null


## Where the focus goes when the Manual closes: back to the window it opened over, when that window
## is still showing and is not the Manual itself, else nowhere (the OS decides, as before).
static func focus_after_close(opener: Window, manual: Window) -> Window:
	if opener == null or opener == manual or not is_instance_valid(opener) or not opener.visible:
		return null
	return opener


func _on_dialog_visibility_changed() -> void:
	if _dialog == null or _dialog.visible:
		return
	var back: Window = focus_after_close(_opener, _dialog)
	_opener = null
	if back != null:
		back.grab_focus.call_deferred()


## The whole reading surface, for a host that wants to drive it directly (and for the preview
## harness, which screenshots it on its own).
func browser() -> EventSheetDocBrowser:
	return _browser


## The generated-reference half. Kept as its own accessor because a caller holding an
## ACEDefinition draws a verb page without a round trip through the registry.
func panel() -> EventSheetDocPanel:
	return null if _browser == null else _browser.panel()


func _ensure_built() -> void:
	if _dialog != null:
		return
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Manual"
	dialog.ok_button_text = "Close"
	# Non-modal: reading and building happen together, so the sheet stays live behind this.
	dialog.exclusive = false
	dialog.unresizable = false
	_browser = EventSheetDocBrowser.new()
	_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_browser.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(420.0))
	_browser.link_activated.connect(func(target: String) -> void:
		_dock._set_status("Opened %s in your browser." % target.get_file()))
	_browser.snippet_inserted.connect(func() -> void:
		_dock._set_status("Inserted the illustrated rows below your selection - one undo step."))
	_browser.control_highlight_requested.connect(func(control_label: String) -> void:
		EventSheets.pulse_control(control_label))
	# Esc gives the sheet its focus back, and closes the window that was over it.
	_browser.focus_returned.connect(func() -> void:
		if _dialog != null:
			_dialog.hide()
		EventSheets.focus_sheet())
	# "Go to first / next" on a reference entry: the window does not own the sheet either, so the
	# same public reveal answers here.
	_browser.row_requested.connect(func(provider_id: String, ace_id: String, index: int) -> void:
		if not EventSheets.reveal_verb_row(provider_id, ace_id, index):
			_dock._set_status("That row is not used in this sheet."))
	# And one of the reader's own rows elsewhere in the project, which needs the file opened first.
	_browser.project_row_requested.connect(func(sheet_path: String, line: int) -> void:
		if not EventSheets.reveal_project_row(sheet_path, line):
			_dock._set_status("Could not open that sheet."))
	# The page's own way online is the Open online button under the guide tree, so the window adds
	# no second one.
	dialog.add_child(EventSheetPopupUI.margined(_browser))
	EventSheetPopupUI.main_button(dialog.get_ok_button())
	dialog.visibility_changed.connect(_on_dialog_visibility_changed)
	_dock.add_child(dialog)
	# Chrome translates for free once the dialog is in the plugin's translation domain.
	EventSheetL10n.apply_to(dialog)
	_dialog = dialog


## The window title names what is on screen, so a reader with the window parked beside the sheet
## can tell at a glance which page it is still showing.
func _title_for(doc_id: String) -> String:
	var title: String = _browser.current_title().strip_edges()
	if title.is_empty() or str(EventSheetDocExplain.resolve(doc_id).get("scheme", "")) == "index":
		return "Manual"
	return "Manual - %s" % title
