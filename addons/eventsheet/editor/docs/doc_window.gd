# EventSheet - EventSheetDocWindow: the Documentation window (Tools > Documentation..., F1).
#
# The Phase 2 home for the reference panel. A window rather than a tooltip because PERSISTENCE is
# the point: a hover vanishes the moment the reader moves the mouse to the row they are building,
# while this stays open beside the sheet, keeps its scroll position, and follows the selection
# every time F1 or the row menu asks a new question.
#
# NON-MODAL on purpose (`exclusive = false`): the reader keeps editing the sheet with the page
# open, which is exactly the gesture a modal help dialog forbids.
#
# The dock owns one instance and calls open(); the window builds itself on the FIRST open, so a
# session that never asks for documentation never pays for the panel, the figure or the viewport
# behind it. Headless runs never popup - the suite constructs docks freely, and a test that pops
# a real window hangs a CI machine.
@tool
class_name EventSheetDocWindow
extends RefCounted

## The guide index, opened by the window's "Browse all guides" button. The guides live in the
## repo rather than in the plugin zip, so this is a version-pinned browser link, not a local file.
const INDEX_DOC_PATH := "docs/README.md"

var _dock: Control = null
var _dialog: AcceptDialog = null
var _panel: EventSheetDocPanel = null


## Wires the dock reference used to parent the dialog and to report into the status line.
func init(dock: Control) -> void:
	_dock = dock


## Opens the window on `doc_id` (empty for the index). Returns false when the id names nothing,
## so a caller can say so instead of showing a page that is silently blank.
func open(doc_id: String = "") -> bool:
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
	_ensure_built()
	if not _panel.show_doc(doc_id):
		return false
	_dialog.title = _title_for(doc_id)
	if not _dialog.visible:
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(560.0)), int(EventSheetPalette.scaled_f(620.0))))
	return true


## The panel this window hosts, for a caller that wants to drive it directly (and for the
## preview harness, which screenshots the panel on its own).
func panel() -> EventSheetDocPanel:
	return _panel


func _ensure_built() -> void:
	if _dialog != null:
		return
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Documentation"
	dialog.ok_button_text = "Close"
	# Non-modal: reading and building happen together, so the sheet stays live behind this.
	dialog.exclusive = false
	dialog.unresizable = false
	_panel = EventSheetDocPanel.new()
	_panel.link_activated.connect(func(target: String) -> void:
		_dock._set_status("Opened %s in your browser." % target.get_file()))
	_panel.snippet_inserted.connect(func() -> void:
		_dock._set_status("Inserted the illustrated rows below your selection - one undo step."))
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	# The page scrolls, the column does not grow sideways: horizontal scrolling is disabled so
	# every wrapping label inside is width-driven by the window rather than by its own content.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(360.0))
	scroll.add_child(_panel)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var index_button: Button = Button.new()
	index_button.text = "Browse all guides"
	index_button.tooltip_text = "Opens the full guide index in your browser, pinned to the version you installed."
	index_button.pressed.connect(func() -> void: EventSheets.open_online_doc(INDEX_DOC_PATH))
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_child(index_button)
	body.add_child(footer)
	dialog.add_child(EventSheetPopupUI.margined(body))
	_dock.add_child(dialog)
	# Chrome translates for free once the dialog is in the plugin's translation domain.
	EventSheetL10n.apply_to(dialog)
	_dialog = dialog


## The window title names what is on screen, so a reader with the window parked beside the sheet
## can tell at a glance which verb it is still showing.
func _title_for(doc_id: String) -> String:
	var route: Dictionary = EventSheetDocExplain.resolve(doc_id)
	match str(route.get("scheme", "")):
		"ace":
			return "Documentation - %s" % _panel.current_title()
		"section":
			return "Documentation - %s" % str(route.get("section", ""))
	return "Documentation"
