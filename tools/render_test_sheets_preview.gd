# EventForge - render harness (dev tool) for the Test sheets slice. Produces one PNG:
#
#   docs/images/tools-run-tests.png   the Run Tests… window after a real run
#
# The run behind the picture is REAL: two Test sheets are compiled here (one whose claims hold, one
# whose claims do not), written out as scripts, and run through the shipped runner in this harness's
# own tree - so the verdict pill, the per-test cards and the copyable report all show what the code
# actually produced, not a mock-up of what it should say.
#
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_test_sheets_preview.gd
@tool
extends SceneTree

const RUNNER_PATH := "res://addons/eventsheet/editor/test_sheet_runner.gd"
const PANEL_PATH := "res://addons/eventsheet/editor/dock/test_report_panel.gd"
const FIXTURE_DIR := "user://ef_preview_tests"

var _frames: int = 0
var _stage: int = 0
var _shot_at: int = -1
var _results: Array = []
var _panel: RefCounted = null
var _dock: Control = null


func _init() -> void:
	root.title = "Test sheets slice"
	root.size = Vector2i(760, 620)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_dock = Control.new()
	_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_dock)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _stage == 0 and _frames == 2:
		_stage = 1
		_run_fixtures()
		return
	if _stage == 2:
		_stage = 3
		_panel = load(PANEL_PATH).new()
		_panel.init(_dock)
		_panel._ensure_dialog()
		_panel._fill(load(PANEL_PATH).call("build_body", _results))
		_panel._dialog.popup_centered(Vector2i(700, 560))
		_shot_at = _frames + 8
		return
	if _stage == 3 and _frames == _shot_at:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/tools-run-tests.png")
		print("[preview] Run Tests window %dx%d" % [image.get_width(), image.get_height()])
		_stage = 4
		quit(0)


## Compiles the two fixture test sheets, writes them, and runs them through the shipped runner.
func _run_fixtures() -> void:
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)
	_write(FIXTURE_DIR + "/gravity_test.gd", _compile(_failing_sheet()))
	_write(FIXTURE_DIR + "/pickup_test.gd", _compile(_passing_sheet()))
	var runner: GDScript = load(RUNNER_PATH)
	for path: String in runner.call("discover", FIXTURE_DIR):
		_results.append(await runner.call("run_script", self, path, 3.0))
	_stage = 2


func _passing_sheet() -> EventSheetResource:
	return _test_sheet([
		_action("AssertThat", {"uid": "a1", "named": "\"a pickup adds to the score\"", "claim": "10 + 5 == 15"}),
		_action("AssertEqual", {"uid": "a2", "named": "\"the pouch holds three\"", "actual": "3", "expected": "3"}),
	])


func _failing_sheet() -> EventSheetResource:
	return _test_sheet([
		_action("AssertThat", {"uid": "b1", "named": "\"gravity pulls down\"", "claim": "1 > 2"}),
		_action("AssertEqual", {"uid": "b2", "named": "\"score after one pickup\"", "actual": "2", "expected": "3"}),
	])


func _test_sheet(actions: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.test_mode = true
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnTestStart"
	for action: Variant in actions:
		row.actions.append(action)
	sheet.events.append(row)
	return sheet


func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


## Compiles to a TEMPORARY path and removes it: with no path given, compile() writes
## res://event_sheet_generated.gd at the project root, and a test sheet left there is a real
## discoverable test the headless runner would pick up on every later run.
func _compile(sheet: EventSheetResource) -> String:
	var source: String = str(SheetCompiler.compile(sheet, FIXTURE_DIR + "/_temp_compile.gd").get("output", ""))
	DirAccess.remove_absolute(FIXTURE_DIR + "/_temp_compile.gd")
	return source


func _write(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()
