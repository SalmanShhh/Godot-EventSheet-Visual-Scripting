@tool
class_name EventSheetMomentFileDoor
extends RefCounted
# "Save Moment As File…" and "Open Moment File As Block…" - the two doors between a moment written
# as rows in a sheet and a moment kept as a file in the project.
#
# WHY THEY ARE DOORS AND NOT BUTTONS IN THE ROW. Nothing is ever drawn inside a sheet row: the row
# reads, and the gestures live where the editor keeps gestures. So both of these are items on the
# Moment block's right-click menu, and each opens a one-field form naming the file - the same shape
# the grid CSV round trip and the extract prompt already use.
#
# WHAT EACH ONE PROMISES. Saving writes a moment resource holding the steps the block's rows carry,
# and REFUSES rather than half-writing when a step cannot be one: a file has no timing and no verb
# outside the ten a moment step is made of, so a block with a Hold in it, or a step that spawns
# something, is named in the refusal instead of being quietly dropped. Opening reads a file back as
# a block whose steps all start together, which is exactly what a file means, and lands through the
# dock's undo funnel so one Ctrl+Z takes it away again.
#
# The conversion itself is EventSheetMomentFile, which is arithmetic and text with no editor in it;
# this file is the form around it plus the two file operations, and `save_run` / `open_run` are the
# tested surface - the suite drives the same functions the buttons do.

## Where a moment file is offered first: beside the pack whose row plays one, which is where the
## six that ship already live. A suggestion in a field, never a rule - the path is typed.
const SUGGESTED_DIRECTORY: String = "res://eventsheet_addons/juice/"

## The four timing words a step may carry, and how the form says each one. The stored word is
## the key: it is the shape a saved sheet holds, and it never changes.
const TIMING_WORDS: Dictionary = {
	MomentStepRow.TIMING_AT: "At - this long after the moment began",
	MomentStepRow.TIMING_THEN: "Then - this long after the step above started",
	MomentStepRow.TIMING_HOLD: "Hold - when the slowest step above has finished",
	MomentStepRow.TIMING_LOOP_BACK: "Loop back - run the stretch again, this many more times"
}

## The script a moment file's resource is, loaded by path so this editor file never names a class
## a project may not have installed.
const RESOURCE_SCRIPT: String = "res://eventsheet_addons/moment_resource/moment_resource.gd"

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _path_edit: LineEdit = null
var _note: Label = null
var _saving: bool = true
var _block: MomentBlockRow = null
## The step form: a timing word, its number, and the one statement the step starts with.
var _step_dialog: ConfirmationDialog = null
var _step_timing: OptionButton = null
var _step_number: LineEdit = null
var _step_code: LineEdit = null
## The name form, for a moment that has no rows yet.
var _name_dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null


func init(dock: Control) -> void:
	_dock = dock


## Opens the save form for the Moment block that was right-clicked.
func open_save(block: MomentBlockRow) -> void:
	if block == null:
		_dock._set_status("Right-click a Moment block to save it as a file.", true)
		return
	var carried: Dictionary = EventSheetMomentFile.steps_of(block)
	var left_behind: PackedStringArray = carried.get("left_behind", PackedStringArray())
	_saving = true
	_block = block
	_build_dialog()
	_dialog.title = "Save Moment As File"
	_dialog.ok_button_text = "Write the file"
	_path_edit.text = SUGGESTED_DIRECTORY + _file_word(block.moment_name) + ".tres"
	_note.text = _save_note(carried.get("steps", []).size(), left_behind)
	_dialog.popup_centered()
	_path_edit.grab_focus()


## Opens the form that reads a moment file back into the sheet as a block.
func open_read() -> void:
	_saving = false
	_block = null
	_build_dialog()
	_dialog.title = "Open Moment File As Block"
	_dialog.ok_button_text = "Add the block"
	_path_edit.text = SUGGESTED_DIRECTORY + "impact.tres"
	_note.text = ("The file's steps arrive as rows that all start together, which is what a file "
		+ "means. Give them a Then or a Hold afterwards and the beat is yours.")
	_dialog.popup_centered()
	_path_edit.grab_focus()


## Opens the form that adds one step to a Moment block.
func open_step(block: MomentBlockRow) -> void:
	if block == null:
		_dock._set_status("Right-click a Moment block to add a step to it.", true)
		return
	_block = block
	if _step_dialog == null:
		_step_dialog = ConfirmationDialog.new()
		_step_dialog.title = "Add Moment Step"
		_step_dialog.ok_button_text = "Add the step"
		_step_dialog.min_size = Vector2i(420, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_step_timing = OptionButton.new()
		for word: String in TIMING_WORDS:
			_step_timing.add_item(TIMING_WORDS[word])
		box.add_child(EventSheetPopupUI.form_row("When", _step_timing))
		_step_number = LineEdit.new()
		_step_number.placeholder_text = "0.05"
		box.add_child(EventSheetPopupUI.form_row("Seconds (or the count)", _step_number))
		_step_code = LineEdit.new()
		_step_code.placeholder_text = "$JuiceBehavior.moment_step(\"shake\", 0.4, \"\", 0.0, strength)"
		box.add_child(EventSheetPopupUI.form_row("Do", _step_code))
		box.add_child(EventSheetPopupUI.hint_label("The step arrives as one row. Give it more "
			+ "actions, or another step, the way you would anywhere else in the sheet."))
		_step_dialog.add_child(EventSheetPopupUI.margined(box))
		_step_dialog.confirmed.connect(_apply_step)
		_dock.add_child(_step_dialog)
	_step_dialog.popup_centered()
	_step_number.grab_focus()


## Opens the form that starts a new moment: a name, and nothing else. The steps come after.
func open_new() -> void:
	if _name_dialog == null:
		_name_dialog = ConfirmationDialog.new()
		_name_dialog.title = "New Moment"
		_name_dialog.ok_button_text = "Add the block"
		_name_dialog.min_size = Vector2i(400, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "impact"
		box.add_child(EventSheetPopupUI.form_row("Called", _name_edit))
		box.add_child(EventSheetPopupUI.hint_label("The name the Moment row plays it by, and the "
			+ "name of the function it compiles to."))
		_name_dialog.add_child(EventSheetPopupUI.margined(box))
		_name_dialog.confirmed.connect(_apply_new)
		_dock.add_child(_name_dialog)
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


## One step onto a block, with the timing word given. Returns whether the block changed, which is
## what the undo funnel wants to hear.
static func step_added(block: MomentBlockRow, timing: String, number: float,
		code_line: String) -> bool:
	if block == null:
		return false
	var step: MomentStepRow = MomentStepRow.new()
	step.timing = timing
	if timing == MomentStepRow.TIMING_LOOP_BACK:
		step.loop_count = maxi(int(number), 1)
	else:
		step.seconds = maxf(number, 0.0)
	var written: String = code_line.strip_edges()
	if not written.is_empty():
		var action: RawCodeRow = RawCodeRow.new()
		action.code = written
		step.actions.append(action)
	block.steps.append(step)
	return true


## One step off a block. False when the block does not hold it, so a stale reference cannot look
## like a change that happened.
static func step_removed(block: MomentBlockRow, step: MomentStepRow) -> bool:
	if block == null or step == null:
		return false
	var at: int = block.steps.find(step)
	if at < 0:
		return false
	block.steps.remove_at(at)
	return true


## Writes one block out as a moment file. Returns {"ok": bool, "said": String} - what the status
## line says either way, so the outcome is a value a test can read rather than a message on screen.
static func save_run(block: MomentBlockRow, path: String) -> Dictionary:
	if block == null:
		return {"ok": false, "said": "Right-click a Moment block to save it as a file."}
	var target: String = path.strip_edges()
	if not target.ends_with(".tres"):
		return {"ok": false, "said": "A moment file is a .tres resource - name the file with that ending."}
	var carried: Dictionary = EventSheetMomentFile.steps_of(block)
	var left_behind: PackedStringArray = carried.get("left_behind", PackedStringArray())
	if not left_behind.is_empty():
		return {"ok": false, "said": _refusal(left_behind)}
	var steps: Array = carried.get("steps", [])
	if steps.is_empty():
		return {"ok": false, "said": "This block has no step a file could hold yet."}
	var script: Script = load(RESOURCE_SCRIPT) as Script
	if script == null:
		return {"ok": false, "said": "The moment resource is not installed in this project, so there is no file shape to write."}
	var written: Resource = script.new() as Resource
	if written == null:
		return {"ok": false, "said": "The moment resource is not installed in this project, so there is no file shape to write."}
	written.set("moment_name", block.moment_name)
	var typed: Array[Dictionary] = []
	for step: Variant in steps:
		if step is Dictionary:
			typed.append(step as Dictionary)
	written.set("steps", typed)
	var problem: int = ResourceSaver.save(written, target)
	if problem != OK:
		return {"ok": false, "said": "The file could not be written (%s)." % error_string(problem)}
	return {"ok": true, "said": "%s written - %d step(s)." % [target.get_file(), typed.size()]}


## Reads a moment file back as a block, ready to be added to a sheet. Returns
## {"ok": bool, "said": String, "block": MomentBlockRow}.
static func open_run(path: String) -> Dictionary:
	var target: String = path.strip_edges()
	if not ResourceLoader.exists(target):
		return {"ok": false, "said": "No file at %s." % target, "block": null}
	var file: Resource = load(target)
	if file == null:
		return {"ok": false, "said": "%s could not be read." % target.get_file(), "block": null}
	var steps: Variant = file.get("steps")
	if not (steps is Array):
		return {"ok": false, "said": "%s holds no steps, so it is not a moment." % target.get_file(), "block": null}
	var word: String = str(file.get("moment_name")).strip_edges()
	if word.is_empty():
		word = target.get_file().get_basename()
	var block: MomentBlockRow = EventSheetMomentFile.block_of(word, steps as Array)
	if block.function_name().is_empty():
		return {"ok": false, "said": "\"%s\" is not a name a function can carry - rename the moment first." % word, "block": null}
	if block.steps.is_empty():
		return {"ok": false, "said": "%s holds no steps yet." % target.get_file(), "block": null}
	return {"ok": true, "said": "%s opened - %d step(s)." % [target.get_file(), block.steps.size()], "block": block}


## What the save form says before anything is written: how many steps would go, and which would not.
static func _save_note(carried: int, left_behind: PackedStringArray) -> String:
	if left_behind.is_empty():
		return "%d step(s) go into the file, exactly as the rows have them." % carried
	return _refusal(left_behind)


## The one sentence a refusal is, naming the rows a file cannot hold. A file plays every step at
## once and knows only the ten step words, so those two are the whole reason a step stays behind.
static func _refusal(left_behind: PackedStringArray) -> String:
	var named: PackedStringArray = left_behind.slice(0, mini(left_behind.size(), 3))
	var tail: String = "" if left_behind.size() <= 3 else " (and %d more)" % (left_behind.size() - 3)
	return ("A file holds no timing and only the ten moment-step words, so it cannot hold: %s%s. "
		+ "Keep this beat as a block, or make those rows Moment Step rows that start together.") % [
			", ".join(named), tail]


## A moment name as the file it would be called, so the path field opens on a real suggestion.
static func _file_word(moment_name: String) -> String:
	var word: String = moment_name.strip_edges().to_lower().replace(" ", "_")
	return word if not word.is_empty() else "moment"


## The one form both doors use: a path, a sentence saying what will happen, and one button.
func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.min_size = Vector2i(460, 0)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = SUGGESTED_DIRECTORY + "impact.tres"
	box.add_child(EventSheetPopupUI.form_row("File", _path_edit))
	_note = EventSheetPopupUI.hint_label("")
	box.add_child(_note)
	_dialog.add_child(EventSheetPopupUI.margined(box))
	_dialog.confirmed.connect(_apply)
	_dock.add_child(_dialog)


## The button: whichever door is open, run it and say what happened.
func _apply() -> void:
	var path: String = _path_edit.text
	if _saving:
		var wrote: Dictionary = save_run(_block, path)
		_dock._set_status(str(wrote.get("said", "")), not bool(wrote.get("ok", false)))
		return
	var read: Dictionary = open_run(path)
	if not bool(read.get("ok", false)):
		_dock._set_status(str(read.get("said", "")), true)
		return
	var block: MomentBlockRow = read.get("block") as MomentBlockRow
	var added: bool = _dock._perform_undoable_sheet_edit("Open Moment File As Block",
		func() -> bool:
			if _dock._current_sheet == null:
				return false
			_dock._current_sheet.events.append(block)
			return true)
	_dock._set_status(str(read.get("said", "")) if added else "The block could not be added.", not added)


## The step form's button: one step, through the undo funnel like every other sheet edit.
func _apply_step() -> void:
	var words: Array = TIMING_WORDS.keys()
	var picked: int = clampi(_step_timing.selected, 0, words.size() - 1)
	var timing: String = str(words[picked])
	var typed: String = _step_number.text.strip_edges()
	var number: float = typed.to_float() if typed.is_valid_float() else 0.0
	var code_line: String = _step_code.text
	var block: MomentBlockRow = _block
	var added: bool = _dock._perform_undoable_sheet_edit("Add Moment Step",
		func() -> bool:
			return step_added(block, timing, number, code_line))
	_dock._set_status("Step added." if added else "The step could not be added.", not added)


## The name form's button: an empty moment, ready for its steps.
func _apply_new() -> void:
	var block: MomentBlockRow = MomentBlockRow.new()
	block.moment_name = EventSheetMomentFile.identifier_of(_name_edit.text)
	if block.function_name().is_empty():
		_dock._set_status("\"%s\" is not a name a function can carry - letters, digits and underscores." % _name_edit.text, true)
		return
	var added: bool = _dock._perform_undoable_sheet_edit("New Moment",
		func() -> bool:
			if _dock._current_sheet == null:
				return false
			_dock._current_sheet.events.append(block)
			return true)
	_dock._set_status("Moment \"%s\" added." % block.moment_name if added else "The moment could not be added.", not added)
