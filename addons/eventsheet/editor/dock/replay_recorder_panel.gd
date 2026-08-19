@tool
class_name EventSheetReplayRecorderPanel
extends RefCounted
# ⏺ Record - the replay recorder's window (V9).
#
# Record, play the game, Stop, Save as Test Sheet…. Every control the running game sees is reported
# to the editor with the frame it happened on (the debug compile's replay-recording receiver) and
# lands here as the row it will become - "simulate control jump pressed at frame 12". Checkpoints
# the reader adds ("expect hp = 90 at frame 300") slot into the take by frame.
#
# What comes out is an ORDINARY Test sheet: readable, editable, diffable, and replayed by the same
# runner that runs every other Test sheet - headlessly in CI or from Tools > Run Tests… here.
#
# The take itself lives in EventSheetReplayRecorder (static-shaped, pure, pinned headless); this
# file is the shell: the two transport buttons, the list, the checkpoint form and the save.

var _dock: Control = null

var window: Window = null
var record_button: Button = null
var stop_button: Button = null
var save_button: Button = null
var take_list: ItemList = null
var status_label: Label = null
var checkpoint_named: LineEdit = null
var checkpoint_actual: LineEdit = null
var checkpoint_expected: LineEdit = null
var checkpoint_frame: SpinBox = null

var recorder: EventSheetReplayRecorder = EventSheetReplayRecorder.new()
var _connected: bool = false


func init(dock: Control) -> void:
	_dock = dock


func open() -> void:
	build()
	_refresh()
	window.popup_centered(Vector2i(680, 520))


## Builds the window without popping it, so a test drives the real widgets headlessly.
func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = EventSheetL10n.translate("Replay Recorder")
	window.size = Vector2i(680, 520)
	window.min_size = Vector2i(480, 340)
	window.close_requested.connect(func() -> void: window.hide())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var transport: HBoxContainer = HBoxContainer.new()
	transport.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	record_button = Button.new()
	record_button.text = EventSheetL10n.translate("⏺ Record")
	record_button.tooltip_text = EventSheetL10n.translate("Start a take. Every control the running game sees is recorded with the frame it happened on. Recording a second take throws the first one away.")
	record_button.pressed.connect(start_recording)
	transport.add_child(record_button)
	stop_button = Button.new()
	stop_button.text = EventSheetL10n.translate("⏹ Stop")
	stop_button.tooltip_text = EventSheetL10n.translate("Stop recording. The take is kept, so you can still add checkpoints and save it.")
	stop_button.pressed.connect(stop_recording)
	transport.add_child(stop_button)
	save_button = Button.new()
	save_button.text = EventSheetL10n.translate("Save as Test Sheet…")
	save_button.tooltip_text = EventSheetL10n.translate("Write the take as an ordinary Test sheet - readable rows, replayed by the same runner as every other test.")
	save_button.pressed.connect(_save_as_test_sheet)
	transport.add_child(save_button)
	body.add_child(transport)
	status_label = Label.new()
	body.add_child(status_label)
	take_list = ItemList.new()
	take_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("The take"), take_list))
	body.add_child(_checkpoint_card())
	window.add_child(EventSheetPopupUI.margined(body))
	_dock.add_child(window)


func _checkpoint_card() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	checkpoint_named = LineEdit.new()
	checkpoint_named.placeholder_text = "hp after the fall"
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Named"), checkpoint_named))
	checkpoint_actual = LineEdit.new()
	checkpoint_actual.placeholder_text = "hp"
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Read"), checkpoint_actual))
	checkpoint_expected = LineEdit.new()
	checkpoint_expected.placeholder_text = "90"
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Should be"), checkpoint_expected))
	checkpoint_frame = SpinBox.new()
	checkpoint_frame.max_value = 1000000.0
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("At frame"), checkpoint_frame))
	var add_button: Button = Button.new()
	add_button.text = EventSheetL10n.translate("Add checkpoint")
	add_button.pressed.connect(_add_checkpoint)
	box.add_child(add_button)
	return EventSheetPopupUI.titled_card(EventSheetL10n.translate("Checkpoint"), box)


## ⏺ Record. Arms the take AND turns the debug compile's recording on, because a take recorded
## against a game that is not reporting its controls would be a silent empty file.
func start_recording() -> void:
	_listen()
	if _dock._current_sheet != null and not _dock._current_sheet.emit_input_recording:
		_dock._current_sheet.emit_input_recording = true
		_dock._mark_dirty(EventSheetL10n.translate("Replay recording ON - save and run to record a take."))
	recorder.start(Engine.get_frames_drawn())
	_refresh()


func stop_recording() -> void:
	recorder.stop()
	_refresh()


## One control the running game reported. Public so the debugger channel and a test drive the same
## door.
func on_control(action: String, pressed: bool, frame: int) -> void:
	recorder.record_control(action, pressed, frame)
	_refresh()


func _listen() -> void:
	if _connected:
		return
	var debugger: EventSheetLiveValuesDebugger = _dock._ensure_live_values_panel().debugger as EventSheetLiveValuesDebugger
	if debugger == null:
		return
	debugger.input_recorded.connect(on_control)
	_connected = true


func _add_checkpoint() -> void:
	if checkpoint_actual.text.strip_edges().is_empty():
		_dock._set_status(EventSheetL10n.translate("A checkpoint needs something to read."), true)
		return
	recorder.add_checkpoint(checkpoint_named.text, checkpoint_actual.text, checkpoint_expected.text,
		int(checkpoint_frame.value))
	_refresh()


func _refresh() -> void:
	if take_list == null:
		return
	take_list.clear()
	for line: String in recorder.take_lines():
		take_list.add_item(line)
	status_label.text = summary_text(recorder)
	record_button.disabled = recorder.recording
	stop_button.disabled = not recorder.recording
	save_button.disabled = recorder.entries.is_empty()


## The one line above the list, worded once so the window and a test agree.
static func summary_text(take: EventSheetReplayRecorder) -> String:
	if take.recording:
		return EventSheetL10n.translate("Recording - %d rows so far.") % take.entries.size()
	if take.entries.is_empty():
		return EventSheetL10n.translate("No take yet. Press Record, then run the game.")
	return EventSheetL10n.translate("%d rows over %d frames. Save it as a Test sheet to keep it.") % [
		take.entries.size(), take.length_in_frames()]


func _save_as_test_sheet() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.title = EventSheetL10n.translate("Save as Test Sheet")
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.gd ; Test sheet"])
	dialog.current_file = "replay_test.gd"
	dialog.file_selected.connect(func(path: String) -> void:
		_write_test_sheet(path)
		dialog.call_deferred("queue_free"))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	_dock.add_child(dialog)
	dialog.popup_centered(Vector2i(820, 560))


func _write_test_sheet(path: String) -> void:
	var sheet: EventSheetResource = recorder.to_test_sheet(path.get_file().get_basename())
	var result: Dictionary = SheetCompiler.compile(sheet, path)
	if not bool(result.get("success", false)):
		_dock._set_status(EventSheetL10n.translate("The take would not compile: %s") % str(result.get("errors", "")), true)
		return
	window.hide()
	_dock._set_status(EventSheetL10n.translate("Saved %s - run it from Tools > Run Tests…, or headlessly with the rest.") % path.get_file())
	_dock._load_sheet_from_path(path)
