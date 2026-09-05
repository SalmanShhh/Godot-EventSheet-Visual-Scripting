# Godot EventSheets - the strip under a Feedback Player's list (editor-only).
#
# The list itself is drawn by the shared card-list drawer; this is the row of doors under it - how
# long the beat is, and the buttons that let a designer feel it without pressing Play on the game.
#
# NONE OF IT IS A ROW. A sheet row says WHEN a beat plays; how the beat is tuned is a property of
# the object, and the buttons that try it are Inspector chrome. Nothing here is drawn in a sheet,
# nothing here is emitted, and an exported game neither ships this file nor knows it existed.
#
# HOW PLAYING IN THE EDITOR WORKS. The pack script is not a `@tool` script, so its instance methods
# do not run in the editor at all - but its STATICS do, and the pack publishes two: the plan of a
# list (when each card starts and how long it lasts) and a sample of what the object would be doing
# at one moment of it. That is the same opt-in contract the Tools-menu behaviour preview reads, so a
# pack ships one pure function and both doors show the same picture. The host's rest state is
# captured before a play and put back when it ends, so the scene's saved bytes are never touched.
@tool
class_name EventSheetFeedbackPlayerStrip
extends VBoxContainer

## The pack whose statics the preview reads. By PATH: naming the class here would compile the pack
## into every editor boot, in projects that hold no feedback player at all.
const PACK_PATH: String = "res://eventsheet_addons/juice/feedback_player.gd"

## The moment file's own class, written when a list is saved out. Also by path, and also for the
## same reason.
const MOMENT_RESOURCE_PATH: String = "res://eventsheet_addons/moment_resource/moment_resource.gd"

## The keys a moment FILE holds. A card using nothing else saves out exactly; a card that uses the
## timing keys is named in the report instead of being written down half.
const FILE_KEYS: PackedStringArray = ["verb", "amount", "effect", "seconds"]

## How often the preview samples, and the properties it is allowed to write. The rest state is
## captured for these and only these, so a preview can never leave anything else moved.
const FRAME_SECONDS: float = 1.0 / 30.0
const PREVIEWED: PackedStringArray = ["position", "rotation", "scale", "modulate"]

## The timeline's own size, and the ground it is drawn on.
const TIMELINE_HEIGHT: int = 74
const TIMELINE_BACKGROUND: Color = Color(0.11, 0.12, 0.15, 1.0)
const TIMELINE_BAR: Color = Color(0.48, 0.62, 0.92, 0.85)
const TIMELINE_HEAD: Color = Color(0.96, 0.72, 0.32, 0.95)

var _player: Node = null
var _head: Label = null
var _timeline: Control = null
var _timer: Timer = null
var _time: float = 0.0
var _base: Dictionary = {}
var _dialog: EditorFileDialog = null
var _saving: bool = true


## The strip for one player. The argument defaults so the class stays constructible with a bare
## new() - a Control with a class_name is offered by the editor's own node dialog.
func _init(player: Node = null) -> void:
	_player = player
	add_theme_constant_override("separation", 4)
	_head = Label.new()
	_head.add_theme_font_size_override("font_size", 11)
	add_child(_head)
	add_child(_build_buttons())
	_timeline = _build_timeline()
	add_child(_timeline)
	refresh()


## The head line and the timeline, re-read from the player as it is edited.
func refresh() -> void:
	var list: Array = steps_of(_player)
	_head.text = "%d feedback%s - %s total" % [list.size(), "" if list.size() == 1 else "s", seconds_text(duration_of(list))]
	if _timeline != null:
		_timeline.queue_redraw()


## The steps a player is holding: the moment file's when one is on the slot, else its own list. The
## same order of preference the running node uses, so the head never counts a list the game ignores.
static func steps_of(player: Object) -> Array:
	if player == null:
		return []
	var file: Variant = player.get("moment_file")
	if file is Resource and (file as Resource).get("steps") is Array:
		return (file as Resource).get("steps")
	var list: Variant = player.get("steps")
	return list if list is Array else []


## The longest path through a list, asked of the pack itself so the strip and the running game can
## never disagree about how long a beat is. 0 when the pack is not in the project.
static func duration_of(list: Array) -> float:
	var pack: Script = load(PACK_PATH) as Script
	if pack == null:
		return 0.0
	return float(pack.call("duration_of", list))


## A number of seconds as the strip writes it.
static func seconds_text(seconds: float) -> String:
	return "%.2f s" % maxf(seconds, 0.0)


## The list as the steps a moment file can hold, plus the cards it cannot: {steps, left_behind}. A
## card that uses a timing key is left behind by NAME rather than written down without its timing,
## because a file that plays everything at once is not the beat the list was.
static func file_steps_of(list: Array) -> Dictionary:
	var carried: Array = []
	var left_behind: PackedStringArray = PackedStringArray()
	for entry: Variant in list:
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry as Dictionary
		var extra: bool = false
		for key: Variant in card:
			if not FILE_KEYS.has(str(key)) and str(key) != "label" and str(key) != "category" and str(key) != "active":
				extra = true
		if extra:
			left_behind.append(str(card.get("label", card.get("verb", "a card"))))
			continue
		var kept: Dictionary = {}
		for key: String in FILE_KEYS:
			kept[key] = card.get(key, "" if key == "verb" or key == "effect" else 0.0)
		carried.append(kept)
	return {"steps": carried, "left_behind": left_behind}


## The row of doors: the four that play, the one that draws, and the two that move the list between
## this node and a file.
func _build_buttons() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for entry: Array in [["Play", _on_play], ["Stop", _on_stop], ["Skip", _on_skip],
			["Restore", _on_restore], ["Debug view", _on_debug], ["Save as file", _on_save],
			["Load from file", _on_load]]:
		var button: Button = Button.new()
		button.text = str(entry[0])
		button.pressed.connect(entry[1] as Callable)
		row.add_child(button)
	return row


## The timeline: a bar per card at the time it starts, holds as the gaps between them, and the head
## where the preview has got to. Editor-only, hidden until Debug view is pressed, and it emits
## nothing - it is the answer to "why did the flash come late", drawn rather than guessed at.
func _build_timeline() -> Control:
	var drawing: Control = Control.new()
	drawing.custom_minimum_size = Vector2(0, TIMELINE_HEIGHT)
	drawing.hide()
	drawing.draw.connect(_draw_timeline.bind(drawing))
	return drawing


func _draw_timeline(canvas: Control) -> void:
	var pack: Script = load(PACK_PATH) as Script
	if pack == null:
		return
	var list: Array = steps_of(_player)
	var plan: Array = pack.call("schedule_of", list)
	var span: float = maxf(duration_of(list), 0.001)
	var size: Vector2 = canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, size), TIMELINE_BACKGROUND)
	var font: Font = get_theme_default_font()
	var rows: int = maxi(plan.size(), 1)
	var row_height: float = minf(size.y / float(rows), 16.0)
	for index: int in range(plan.size()):
		var entry: Dictionary = plan[index] as Dictionary
		var card: Dictionary = entry.get("card") as Dictionary
		var left: float = size.x * float(entry.get("at", 0.0)) / span
		var width: float = maxf(size.x * maxf(float(entry.get("seconds", 0.0)), 0.0) / span, 3.0)
		var top: float = float(index) * row_height
		canvas.draw_rect(Rect2(left, top + 1.0, width, row_height - 2.0), TIMELINE_BAR)
		if font != null:
			canvas.draw_string(font, Vector2(left + 4.0, top + row_height - 4.0),
				str(card.get("label", card.get("verb", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	if _timer != null and not _timer.is_stopped():
		var head: float = size.x * clampf(_time / span, 0.0, 1.0)
		canvas.draw_line(Vector2(head, 0.0), Vector2(head, size.y), TIMELINE_HEAD, 2.0)


func _on_debug() -> void:
	if _timeline != null:
		_timeline.visible = not _timeline.visible
		_timeline.queue_redraw()


## Start sampling. The host's rest state is written down first, so Stop and Restore have something
## exact to put back rather than a guess at what the numbers were.
func _on_play() -> void:
	_on_restore()
	var target: Node = _host()
	if target == null:
		return
	_base = {}
	for property: String in PREVIEWED:
		var value: Variant = target.get(property)
		if value != null:
			_base[property] = value
	_time = 0.0
	if _timer == null:
		_timer = Timer.new()
		_timer.wait_time = FRAME_SECONDS
		_timer.timeout.connect(_tick)
		add_child(_timer)
	_timer.start()


func _on_stop() -> void:
	if _timer != null:
		_timer.stop()
	_on_restore()
	if _timeline != null:
		_timeline.queue_redraw()


## Jump to the end of the plan - the same door the running node's Skip To End is, in the one form an
## editor can honestly offer: the last frame of the beat, drawn.
func _on_skip() -> void:
	_time = duration_of(steps_of(_player))
	_tick()


func _on_restore() -> void:
	var target: Node = _host()
	if target != null:
		for property: Variant in _base:
			target.set(str(property), _base[property])
	_base = {}


func _tick() -> void:
	var target: Node = _host()
	var pack: Script = load(PACK_PATH) as Script
	if target == null or pack == null:
		_on_stop()
		return
	var params: Dictionary = {"steps": steps_of(_player), "strength": float(_player.get("strength"))}
	var written: Variant = pack.call("editor_preview_sample", params, _base, _time)
	if written is Dictionary:
		for property: Variant in written as Dictionary:
			target.set(str(property), (written as Dictionary)[property])
	_time += FRAME_SECONDS
	if _timeline != null:
		_timeline.queue_redraw()
	if _time > duration_of(steps_of(_player)) + FRAME_SECONDS:
		_on_stop()


## The object this player is under - the one a beat is felt on.
func _host() -> Node:
	if _player == null or not _player.is_inside_tree():
		return null
	return _player.get_parent()


func _on_save() -> void:
	_saving = true
	_open_dialog(EditorFileDialog.FILE_MODE_SAVE_FILE)


func _on_load() -> void:
	_saving = false
	_open_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE)


func _open_dialog(mode: int) -> void:
	if _dialog == null:
		_dialog = EditorFileDialog.new()
		_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_dialog.add_filter("*.tres", "Moment file")
		_dialog.file_selected.connect(_on_file_chosen)
		add_child(_dialog)
	_dialog.file_mode = mode as EditorFileDialog.FileMode
	_dialog.popup_centered_ratio(0.6)


## Writing a list out, and reading one back in. Both are ordinary resource operations on a file the
## designer named: nothing is written anywhere they did not point at, and a load never deletes the
## list it replaces - it fills the moment-file slot, which the list is only hidden behind.
func _on_file_chosen(path: String) -> void:
	if _player == null:
		return
	if _saving:
		var script: Script = load(MOMENT_RESOURCE_PATH) as Script
		if script == null:
			return
		var carried: Dictionary = file_steps_of(steps_of(_player))
		var file: Resource = script.new()
		file.set("moment_name", path.get_file().get_basename())
		file.set("steps", carried.get("steps"))
		if ResourceSaver.save(file, path) != OK:
			push_warning("Feedback Player: %s could not be written." % path)
			return
		if not (carried.get("left_behind") as PackedStringArray).is_empty():
			push_warning("Feedback Player: %s holds the cards a file can hold. These use timing a file cannot carry and were left in the list: %s." % [
				path.get_file(), ", ".join(carried.get("left_behind") as PackedStringArray)])
		return
	var loaded: Resource = load(path)
	if loaded == null or not (loaded.get("steps") is Array):
		push_warning("Feedback Player: %s is not a moment file." % path.get_file())
		return
	_player.set("moment_file", loaded)
	refresh()
