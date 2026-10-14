# Godot EventSheets - the Run Tests… report window.
#
# Tools > Run Tests… finds every Test sheet in the project, runs each one in the editor's own tree,
# and shows what each claim said. THE REPORT IS A PANEL, NEVER ROW CHROME: nothing here writes back
# onto the sheet, no row gains a mark, and with this window closed the canvas is byte-identical to
# what it was before the run. A test result is a fact about a run, not a property of a row.
#
# The wording, the totals and the verdict come from test_sheet_runner.gd - the same file the headless
# `tools/run_test_sheets.gd` command uses - so the window and the terminal never disagree. The raw
# report text sits at the bottom in a copyable card, which is what makes a failure paste-able into a
# bug report without a screenshot; Copy Report puts the same text on the clipboard, and Run Again
# runs every test once more without closing the window.
#
# Loaded by path from the Tools menu (no class_name, nothing preloaded): the editor's boot path must
# not grow a window nobody has asked for yet.
@tool
extends RefCounted

const RUNNER_PATH := "res://addons/eventsheet/editor/test_sheet_runner.gd"
## The footer button that copies the report rather than closing anything.
const COPY_ACTION: StringName = &"copy_report"

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _body: VBoxContainer = null
## The report as text, for Copy Report: the lines the card at the bottom shows.
var _report_text: String = ""
## True while a run is in progress. The run awaits each test, so the menu item can be chosen again
## before it finishes; a second run started then would interleave with the first in the same tree.
var _running: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Opens the window, shows it running, then fills it in. Opening FIRST matters: a project with a
## slow test would otherwise look like a menu item that does nothing at all.
func open() -> void:
	_ensure_dialog()
	if not _dialog.visible:
		_dialog.popup_centered(Vector2i(EventSheetPalette.scaled(620), EventSheetPalette.scaled(460)))
	if _running:
		return
	_fill(_placeholder(EventSheetL10n.translate("Running every test sheet in the project…")))
	var runner: GDScript = load(RUNNER_PATH)
	var tree: SceneTree = _dock.get_tree()
	if tree == null:
		_fill(_placeholder(EventSheetL10n.translate("Tests need a running editor tree to run in.")))
		return
	var results: Array = []
	_set_running(true)
	for path: String in runner.call("discover", "res://"):
		var result: Dictionary = await runner.call("run_script", tree, path, 5.0)
		results.append(result)
		# A sheet's health card says how its tests last went, and this run is what it means by
		# "last". Nothing is written onto any sheet: the memory is the editor's own, per project.
		EventSheetHealthCard.record_test_result(path, recorded_failures(result))
	_set_running(false)
	_report_text = "\n".join(runner.call("report_lines", results))
	_fill(build_body(results))


## Run Again is greyed while a run is going, so it cannot start a second one beside it.
func _set_running(running: bool) -> void:
	_running = running
	_dialog.get_ok_button().disabled = running


## How many failures one test's result counts as - the runner's own count, so a test that recorded
## no claims at all is one failure here exactly as it is FAIL in the report beside it.
static func recorded_failures(result: Dictionary) -> int:
	var runner: GDScript = load(RUNNER_PATH)
	return int((runner.call("summarize", [result]) as Dictionary)["failed"])


## The whole window content for a finished run: the verdict, one card per test with a line per
## claim, and the raw report text. Static and results-driven so the assembly is testable without an
## editor - the panel is only ever the sum of these pieces.
static func build_body(results: Array) -> VBoxContainer:
	var runner: GDScript = load(RUNNER_PATH)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	if results.is_empty():
		box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("No test sheets found. Set a sheet's type to Test (Sheet > Sheet Type…), add an On Test Start event, and assert something."), 560.0))
		return box
	var header: HBoxContainer = HBoxContainer.new()
	header.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Verdict")))
	var tone: String = EventSheetPopupUI.TONE_OK if int((runner.call("summarize", results) as Dictionary)["failed"]) == 0 \
		else EventSheetPopupUI.TONE_ERROR
	header.add_child(EventSheetPopupUI.metadata_badge(str(runner.call("totals_line", results)), EventSheetPopupUI.tone_color(tone)))
	header.add_child(EventSheetPopupUI.metadata_badge(str(runner.call("verdict_line", results)), EventSheetPopupUI.tone_color(tone)))
	box.add_child(header)
	for result: Dictionary in results:
		var counts: Dictionary = runner.call("summarize", [result])
		var claims: VBoxContainer = VBoxContainer.new()
		for row: Array in runner.call("claim_rows", result):
			claims.add_child(claim_line(row))
		box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("%s - %d passed, %d failed") % [
			str(result.get("test", "test")), int(counts["passed"]), int(counts["failed"])], claims))
	box.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Report (copyable)")))
	box.add_child(EventSheetPopupUI.code_card("\n".join(runner.call("report_lines", results)), 560.0))
	return box


## One claim as a line: its name, and PASS or FAIL at the right. A failing claim is a red edge plus
## its reason - the state note's shape - and a passing one sits at the same indent with no edge.
static func claim_line(row: Array) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	var passed: bool = str(row[1]) == "PASS"
	var said: Control = null
	if passed:
		var name_label: Label = Label.new()
		name_label.text = str(row[0])
		said = PanelContainer.new()
		var indent: StyleBoxEmpty = StyleBoxEmpty.new()
		indent.content_margin_left = EventSheetPalette.scaled_f(8.0) + EventSheetPalette.scaled(3)
		said.add_theme_stylebox_override("panel", indent)
		said.add_child(name_label)
	else:
		var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(360.0))
		note.say("%s - %s" % [str(row[0]), str(row[2])] if not str(row[2]).is_empty() else str(row[0]))
		said = note
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(said)
	var result: Label = Label.new()
	result.text = str(row[1])
	result.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(
		EventSheetPopupUI.TONE_OK if passed else EventSheetPopupUI.TONE_ERROR))
	line.add_child(result)
	return line


func _placeholder(message: String) -> VBoxContainer:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(EventSheetPopupUI.hint_label(message, 560.0))
	return box


func _fill(content: VBoxContainer) -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(content)


func _ensure_dialog() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = EventSheetL10n.translate("Run every test sheet")
	# Run Again keeps the window: the next run fills it where the last one was read.
	_dialog.ok_button_text = EventSheetL10n.translate("Run Again")
	_dialog.dialog_hide_on_ok = false
	_dialog.cancel_button_text = EventSheetL10n.translate("Close")
	_dialog.confirmed.connect(open)
	var copy: Button = _dialog.add_button(EventSheetL10n.translate("Copy Report"), false, COPY_ACTION)
	copy.get_parent().move_child(copy, 0)
	_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == COPY_ACTION and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			DisplayServer.clipboard_set(_report_text))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Lines wrap to the window instead of running off its right edge, where PASS and FAIL stand.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_dialog.add_child(EventSheetPopupUI.margined(scroll))
	_dock.add_child(_dialog)
