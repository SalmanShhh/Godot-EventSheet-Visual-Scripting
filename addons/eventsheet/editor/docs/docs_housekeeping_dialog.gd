# Godot EventSheets - Tools > Docs Housekeeping: the documentation chores, with checkboxes.
#
# One window, one button, one report. The chores themselves live in doc_chores.gd and are the same
# ones the command line and the CI job run - this window is a door, and it deliberately knows
# nothing about how a manual page is written or what a drift check compares.
#
# WHAT IT REMEMBERS, and where. The ticked boxes are a property of the PROJECT rather than of the
# person: a team that regenerates the manual and exports the site wants everybody's Run to do that,
# and somebody who joined this week should not have to be told. They live in a small file beside the
# project's other generated state, so ticking a box never shows up as a change in version control.
#
# ONE REPORT, AT THE END. Not a line per chore as it goes: the interesting question is what the whole
# run found, and a panel that scrolls while you read it is a panel nobody reads. The report is the
# chores' own text, unchanged, so it can be pasted next to the terminal's output and compared.
#
# THE HONESTY LINE IS ON SCREEN, not just in this comment: every chore says what it would cost a
# person to do by hand, the drafting chore says out loud that its drafts stay drafts, and the CI
# button shows the exact file it would write before writing it.
@tool
class_name EventSheetDocsHousekeepingDialog
extends AcceptDialog

## Where the ticked boxes are remembered. Inside .godot/ because that folder is already the project's
## own generated state and is already out of version control everywhere - a preference that produced
## a diff would be a preference nobody sets.
const SETTINGS_PATH := "res://.godot/eventsheets_housekeeping.cfg"
const SETTINGS_SECTION := "chores"

## What a project that has never opened this window runs: the two chores that only ever describe
## what is already there. Nothing that writes a site or drafts prose is on by default - a first Run
## should surprise nobody.
const DEFAULT_CHORES: PackedStringArray = ["manual", "check"]

var _boxes: Dictionary = {}
var _report: TextEdit = null
var _status: Label = null
var _run_button: Button = null
var _ci_confirm: ConfirmationDialog = null
var _ci_text: String = ""
var _sheets_provider: Callable = Callable()


func _init() -> void:
	title = "Docs Housekeeping"
	ok_button_text = "Close"
	add_child(EventSheetPopupUI.margined(_build_body()))
	_load_ticked()


## `sheets_provider` answers {path: EventSheetResource} for whatever the editor has open, so the
## chores document the sheets the person can actually see as well as the ones on disk. Optional: a
## run with no provider documents the project's own sheets and says so.
func configure(sheets_provider: Callable) -> void:
	_sheets_provider = sheets_provider


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(680.0, 480.0)
	page.add_child(EventSheetPopupUI.hint_label(
		"Chores you could do by hand, done in one go. Nothing here is published: drafted prose is written to a drafts file and stays a draft, and every file it writes is one you can read and change.",
		640.0))
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in EventSheetDocChores.chores():
		list.add_child(_chore_row(entry))
	# The list scrolls inside its card. Every chore carries a sentence saying what it would cost by
	# hand, which is the whole point of the window and also more text than a dialog can show at once;
	# without this the Run button falls off the bottom of the screen on a laptop.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640.0, 260.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	page.add_child(EventSheetPopupUI.titled_card("what to run", scroll))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	_run_button = Button.new()
	_run_button.text = "Run the ticked chores"
	_run_button.tooltip_text = "Runs them in order and shows one report at the end."
	_run_button.pressed.connect(_on_run_pressed)
	actions.add_child(_run_button)
	var ci: Button = Button.new()
	ci.text = "Write a CI workflow…"
	ci.tooltip_text = "Shows you a GitHub Actions file that runs the checks and the export on every push, pinned to this project's Godot version. The file is yours; the plugin never reads it again."
	ci.pressed.connect(_on_ci_pressed)
	actions.add_child(ci)
	page.add_child(actions)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(640.0, 0.0)
	page.add_child(_status)
	_report = TextEdit.new()
	_report.editable = false
	_report.custom_minimum_size = Vector2(640.0, 180.0)
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.placeholder_text = "The report lands here."
	page.add_child(EventSheetPopupUI.titled_card("report", _report))
	return page


func _chore_row(entry: Dictionary) -> Control:
	var id: String = str(entry.get("id", ""))
	var box: CheckBox = CheckBox.new()
	box.text = str(entry.get("label", id))
	box.tooltip_text = str(entry.get("note", ""))
	box.toggled.connect(func(_pressed: bool) -> void: _save_ticked())
	_boxes[id] = box
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(box)
	column.add_child(EventSheetPopupUI.hint_label(str(entry.get("note", "")), 600.0))
	return column


## The chores whose box is ticked, in the chores module's own order.
func ticked() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for id: String in EventSheetDocChores.CHORE_ORDER:
		var box: CheckBox = _boxes.get(id) as CheckBox
		if box != null and box.button_pressed:
			ids.append(id)
	return ids


func _on_run_pressed() -> void:
	var ids: PackedStringArray = ticked()
	if ids.is_empty():
		_status.text = "Nothing is ticked."
		return
	_status.text = "Running…"
	var options: Dictionary = {"sheets": _open_sheets()}
	var report: Dictionary = EventSheetDocChores.run(ids, options)
	_report.text = EventSheetDocChores.report_text(report)
	var wrote: int = (report.get("wrote", PackedStringArray()) as PackedStringArray).size()
	_status.text = "%d chore(s) ran, %d file(s) changed%s." % [ids.size(), wrote,
		"" if bool(report.get("ok", true)) else ", and something wants a person"]


func _open_sheets() -> Dictionary:
	if not _sheets_provider.is_valid():
		return {}
	var found: Variant = _sheets_provider.call()
	return found as Dictionary if found is Dictionary else {}


# ── The CI file ───────────────────────────────────────────────────────────────────────────────


## Shows the workflow BEFORE writing it. A plugin that added a file to somebody's repository without
## showing it to them first would have taken a decision that is not its to take.
func _on_ci_pressed() -> void:
	_ci_text = EventSheetDocsCiWorkflow.workflow_text(EventSheetDocsCiWorkflow.version_tag())
	if _ci_confirm == null:
		_ci_confirm = ConfirmationDialog.new()
		_ci_confirm.title = "Write this file?"
		_ci_confirm.ok_button_text = "Write it"
		var body: VBoxContainer = EventSheetPopupUI.form_box()
		body.custom_minimum_size = Vector2(680.0, 420.0)
		body.add_child(EventSheetPopupUI.hint_label(
			"This is the whole file. It goes to %s, it runs on your repository's own runners, and the plugin never reads it again - edit it or delete it whenever you like." % EventSheetDocsCiWorkflow.WORKFLOW_PATH,
			640.0))
		var view: TextEdit = TextEdit.new()
		view.editable = false
		view.custom_minimum_size = Vector2(640.0, 320.0)
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.name = "WorkflowView"
		body.add_child(view)
		_ci_confirm.add_child(EventSheetPopupUI.margined(body))
		_ci_confirm.confirmed.connect(_on_ci_confirmed)
		add_child(_ci_confirm)
	var shown: TextEdit = _ci_confirm.find_child("WorkflowView", true, false) as TextEdit
	if shown != null:
		shown.text = _ci_text
	_ci_confirm.ok_button_text = "Replace it" if EventSheetDocsCiWorkflow.exists() else "Write it"
	_ci_confirm.popup_centered()


func _on_ci_confirmed() -> void:
	if EventSheetDocsCiWorkflow.write(_ci_text):
		_status.text = "Wrote %s. It is yours now." % EventSheetDocsCiWorkflow.WORKFLOW_PATH
	else:
		_status.text = "Could not write %s." % EventSheetDocsCiWorkflow.WORKFLOW_PATH


# ── Remembering the boxes ─────────────────────────────────────────────────────────────────────


## The ticked ids a project remembers, or the defaults when it has never been asked. Public and pure
## over a ConfigFile so the suite pins the fallback without a project on disk.
static func ticked_in(config: ConfigFile) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for id: String in EventSheetDocChores.CHORE_ORDER:
		if bool(config.get_value(SETTINGS_SECTION, id, DEFAULT_CHORES.has(id))):
			ids.append(id)
	return ids


func _load_ticked() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	var wanted: PackedStringArray = ticked_in(config)
	for id: Variant in _boxes:
		var box: CheckBox = _boxes[id] as CheckBox
		box.set_pressed_no_signal(wanted.has(str(id)))


func _save_ticked() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	for id: Variant in _boxes:
		config.set_value(SETTINGS_SECTION, str(id), (_boxes[id] as CheckBox).button_pressed)
	config.save(SETTINGS_PATH)
