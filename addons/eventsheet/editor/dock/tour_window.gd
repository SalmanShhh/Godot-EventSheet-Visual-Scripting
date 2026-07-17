@tool
class_name EventSheetTourWindow
extends RefCounted

# The optional first-time tour (Tools ▸ Start the Tour…, or the Welcome window's tour button).
#
# A small NON-MODAL window that floats beside the sheet, walking the core loop in 6 steps: read a
# row, add an event, give it a condition, make it act, see the honest GDScript, and where to go
# next. The editor stays fully interactive underneath - each step asks the user to DO the thing in
# the real UI, and a light poll watches the live sheet so the step flips to "Done!" the moment the
# action lands. Next is NEVER gated on the check (a stuck check must not trap anyone); Skip closes
# the tour instantly. Nothing auto-opens: the tour is invited, not imposed.

var _dock: Control = null
var _window: Window = null
var _title_label: Label = null
var _body_label: Label = null
var _task_label: Label = null
var _done_label: Label = null
var _progress_label: Label = null
var _back_button: Button = null
var _next_button: Button = null
var _poll_timer: Timer = null
var _step_index: int = 0


## The tour script: title + body (why it matters) + task (what to do in the REAL UI, named exactly as
## the UI names it) + an optional `check` Callable(sheet) -> bool the poll evaluates to flip the step
## to Done. Static and data-driven so tests pin the content and every check without building a window.
static func steps() -> Array[Dictionary]:
	return [
		{
			"title": "Read a sheet like a sentence",
			"body": "Every rule is one row. WHEN the left side is true (the conditions), DO the right side (the actions). Nothing is hidden: the plain GDScript your game ships is always one click away.",
			"task": "Look at the sheet: conditions live in the left lane, actions in the right.",
			"check": Callable(),
		},
		{
			"title": "Add your first event",
			"body": "An event starts with a trigger - the moment it runs. On Ready fires once when the object appears; Every Frame runs continuously.",
			"task": "Click \"+ Add event…\" at the bottom of the sheet (or Add Event in the toolbar) and pick a trigger - try On Ready.",
			"check": func(sheet: EventSheetResource) -> bool: return _sheet_has_event(sheet),
		},
		{
			"title": "Give it a condition",
			"body": "Conditions decide WHEN the row runs this tick. Stack several and ALL must hold; conditions like Every X Seconds even keep their own timer.",
			"task": "Select your event and click Add Condition (or double-click the left lane). Try Every X Seconds.",
			"check": func(sheet: EventSheetResource) -> bool: return _sheet_has_condition(sheet),
		},
		{
			"title": "Make it DO something",
			"body": "Actions are the verbs - they run top to bottom whenever the conditions pass.",
			"task": "Click Add Action (or double-click the right lane) and pick Print Message, then type something friendly.",
			"check": func(sheet: EventSheetResource) -> bool: return _sheet_has_action(sheet),
		},
		{
			"title": "See the honest GDScript",
			"body": "Your sheet IS a plain Godot script - no runtime, no magic. Clicking a code line jumps to the row that made it, so the sheet and the script always explain each other.",
			"task": "Click the GDScript button in the toolbar and find the line your action just added.",
			"check": Callable(),
		},
		{
			"title": "Make your own data asset",
			"body": "Sheets aren't only for gameplay: Sheet > New Custom Resource… asks three plain questions (what one entry is called, what columns it has, whether it's required) and builds a data asset whose Inspector is a fill-in table - loot tables, dialogue lines, wave plans. Designers fill rows and save .tres variants; your sheets load them. And Sheet > New Editor Tool… makes one-click editor chores the same way.",
			"task": "Peek at Sheet > New Custom Resource… (Esc closes it without creating anything).",
			"check": Callable(),
		},
		{
			"title": "You know the loop",
			"body": "Events + conditions + actions, compiled to code you can read. From here: Sheet > New From Template opens full starters, Tools > Welcome has the playable showcase, and Add > Variable gives your sheet memory. Take this tour again any time: Tools > Start the Tour. Have fun!",
			"task": "Hit Finish and go make something.",
			"check": Callable(),
		},
	]


static func _sheet_has_event(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	for entry: Variant in sheet.events:
		if entry is EventRow:
			return true
	return false


static func _sheet_has_condition(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).conditions.is_empty():
			return true
	return false


static func _sheet_has_action(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).actions.is_empty():
			return true
	return false


func init(dock: Control) -> void:
	_dock = dock


## Custom steps (an extension tour via EventSheets.start_tour); empty = the built-in tour.
var _custom_steps: Array[Dictionary] = []


func _active_steps() -> Array[Dictionary]:
	return _custom_steps if not _custom_steps.is_empty() else steps()


func start(custom_steps: Array[Dictionary] = []) -> void:
	_custom_steps = custom_steps
	# A first-timer may start the tour before any sheet exists - hand them a blank practice sheet so
	# every step's gesture actually works (the no-sheet guard would otherwise reject each one).
	if _dock._current_sheet == null:
		_dock.setup(EventSheetStarterTemplates.build_starter(0))
		_dock._current_sheet_path = ""
		_dock._dirty = true
		_dock._refresh_title_strip()
		_dock._clear_undo_history()
		_dock._set_status("The tour opened a practice sheet - Save As… if you want to keep it.")
	if _window == null:
		_build()
	_step_index = 0
	_show_step()
	if _window.visible:
		return
	# Float at the dock's top-right so the sheet (where the doing happens) stays clear. Clamped left
	# to the dock edge for narrow (or not-yet-laid-out) docks.
	if _dock.is_inside_tree():
		_window.position = Vector2i(_dock.get_screen_position()) + Vector2i(maxi(16, int(_dock.size.x) - 460), 72)
	_window.show()
	_poll_timer.start()


func _build() -> void:
	_window = Window.new()
	_window.title = "The 2-minute tour"
	_window.wrap_controls = true
	_window.unresizable = true
	_window.always_on_top = false
	_window.transient = false
	_window.exclusive = false
	_window.close_requested.connect(_finish)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.custom_minimum_size = Vector2(420.0, 0.0)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 17)
	box.add_child(_title_label)
	_body_label = EventSheetPopupUI.hint_label("", 420.0)
	box.add_child(_body_label)
	var task_box: VBoxContainer = EventSheetPopupUI.form_box()
	_task_label = Label.new()
	_task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_label.custom_minimum_size = Vector2(400.0, 0.0)
	task_box.add_child(_task_label)
	_done_label = Label.new()
	_done_label.visible = false
	task_box.add_child(_done_label)
	box.add_child(EventSheetPopupUI.titled_card("Try it", task_box))
	var buttons: HBoxContainer = HBoxContainer.new()
	var skip_button: Button = Button.new()
	skip_button.text = "Skip tour"
	skip_button.flat = true
	skip_button.pressed.connect(_finish)
	buttons.add_child(skip_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_progress_label = Label.new()
	_progress_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	buttons.add_child(_progress_label)
	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.pressed.connect(func() -> void:
		if _step_index > 0:
			_step_index -= 1
			_show_step())
	buttons.add_child(_back_button)
	_next_button = Button.new()
	_next_button.pressed.connect(func() -> void:
		if _step_index >= _active_steps().size() - 1:
			_finish()
		else:
			_step_index += 1
			_show_step())
	buttons.add_child(_next_button)
	box.add_child(buttons)
	_window.add_child(EventSheetPopupUI.margined(box))
	# The live "did they do it?" watcher - cheap, and only while the tour is open.
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.timeout.connect(_poll_current_step)
	_window.add_child(_poll_timer)
	_dock.add_child(_window)


func _show_step() -> void:
	var tour_steps: Array[Dictionary] = _active_steps()
	var step: Dictionary = tour_steps[_step_index]
	_title_label.text = str(step["title"])
	_body_label.text = str(step["body"])
	_task_label.text = str(step["task"])
	_done_label.visible = false
	_progress_label.text = "%d / %d" % [_step_index + 1, tour_steps.size()]
	_back_button.disabled = _step_index == 0
	_next_button.text = "Finish" if _step_index == tour_steps.size() - 1 else "Next"
	_poll_current_step()
	if _window.visible:
		_window.child_controls_changed()


## Flips the step to a green "Done!" the moment the asked-for edit exists on the live sheet. Purely
## encouraging feedback - Next never waits for it.
func _poll_current_step() -> void:
	var step: Dictionary = _active_steps()[_step_index]
	var check: Callable = step["check"]
	if not check.is_valid():
		return
	if bool(check.call(_dock._current_sheet)):
		_done_label.text = "✓ Done - nice! Hit Next."
		_done_label.modulate = Color(0.55, 0.9, 0.55, 1.0)
		_done_label.visible = true


func _finish() -> void:
	_poll_timer.stop()
	_window.hide()
