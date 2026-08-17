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
# bug report without a screenshot.
#
# Loaded by path from the Tools menu (no class_name, nothing preloaded): the editor's boot path must
# not grow a window nobody has asked for yet.
@tool
extends RefCounted

const RUNNER_PATH := "res://addons/eventsheet/editor/test_sheet_runner.gd"
## Tone for the verdict pill: green when everything passed, red when anything did not.
const PASS_TONE := Color(0.42, 0.78, 0.45)
const FAIL_TONE := Color(0.88, 0.42, 0.42)

var _dock: Control = null
var _dialog: AcceptDialog = null
var _body: VBoxContainer = null


func init(dock: Control) -> void:
	_dock = dock


## Opens the window, shows it running, then fills it in. Opening FIRST matters: a project with a
## slow test would otherwise look like a menu item that does nothing at all.
func open() -> void:
	_ensure_dialog()
	_fill(_placeholder("Running every test sheet in the project…"))
	_dialog.popup_centered(Vector2i(EventSheetPalette.scaled(620), EventSheetPalette.scaled(460)))
	var runner: GDScript = load(RUNNER_PATH)
	if runner == null:
		_fill(_placeholder("The test runner is missing from this project (%s)." % RUNNER_PATH))
		return
	var tree: SceneTree = _dock.get_tree()
	if tree == null:
		_fill(_placeholder("Tests need a running editor tree to run in."))
		return
	var results: Array = []
	for path: String in runner.call("discover", "res://"):
		results.append(await runner.call("run_script", tree, path, 5.0))
	_fill(build_body(results))


## The whole window content for a finished run: the verdict pill, one card per test with its claims
## as a table, and the raw report text. Static and results-driven so the assembly is testable
## without an editor - the panel is only ever the sum of these pieces.
static func build_body(results: Array) -> VBoxContainer:
	var runner: GDScript = load(RUNNER_PATH)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	if results.is_empty():
		box.add_child(EventSheetPopupUI.hint_label("No test sheets found. Set a sheet's type to Test (Sheet > Sheet Type…), add an On Test Start event, and assert something.", 560.0))
		return box
	var header: HBoxContainer = HBoxContainer.new()
	header.add_child(EventSheetPopupUI.small_caps_label("Verdict"))
	var failed: int = int((runner.call("summarize", results) as Dictionary)["failed"])
	header.add_child(EventSheetPopupUI.metadata_badge(str(runner.call("totals_line", results)),
		PASS_TONE if failed == 0 else FAIL_TONE))
	header.add_child(EventSheetPopupUI.metadata_badge(str(runner.call("verdict_line", results)),
		PASS_TONE if failed == 0 else FAIL_TONE))
	box.add_child(header)
	for result: Dictionary in results:
		var counts: Dictionary = runner.call("summarize", [result])
		var card_body: VBoxContainer = EventSheetPopupUI.form_box()
		card_body.add_child(EventSheetPopupUI.compact_table(
			PackedStringArray(["Claim", "Result", "Why"]),
			runner.call("claim_rows", result), 2))
		box.add_child(EventSheetPopupUI.titled_card("%s  -  %d passed, %d failed" % [
			str(result.get("test", "test")), int(counts["passed"]), int(counts["failed"])], card_body))
	box.add_child(EventSheetPopupUI.code_card("\n".join(runner.call("report_lines", results)), 560.0))
	return box


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
	_dialog = AcceptDialog.new()
	_dialog.title = "Run Tests"
	_dialog.ok_button_text = "Close"
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_dialog.add_child(EventSheetPopupUI.margined(scroll))
	_dock.add_child(_dialog)
