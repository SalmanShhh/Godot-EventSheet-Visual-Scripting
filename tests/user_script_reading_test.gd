# Godot EventSheets - a script somebody else wrote, opened as a sheet the way a user opens one.
#
# Every reading below was first seen wrong in a fresh project with the plugin installed, opening
# hand-written scripts nobody had written for the plugin - a player, an enemy with a class inside it,
# an editor plugin. Each pin is the line the sheet now draws, read off the dock's own canvas:
#
#   - `not is_on_floor()` is the inverted condition on the player itself ("Player", "Is on floor",
#     the inverted mark), the same words `is_on_floor()` reads as anywhere else, and so is the
#     same test written inside a `match` branch;
#   - a verb filed under the body's class (Move and slide, Set velocity Y) and a call to one of the
#     script's own functions lead with the script's own name, as the script's variables do;
#   - a local the physics step declares is a variable, so the next event's test of it grows no note;
#   - a class written inside the file does not make the file's own members "not a variable";
#   - a variable whose type the file never wrote is not the wrong kind for any verb;
#   - an `@onready` node reads as a variable row - its type, its name, its value - and not as a row
#     led by an "Object" word;
#   - the chips after a condition never take so much of the lane that the condition's own words are
#     drawn a letter per line.
#
# Read through a real dock rather than a bare viewport, because the object a class verb belongs to
# and the variable notes are both answered from the definitions the dock's registry generates.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "user_script_reading_test"
const PLAYER_PATH := "user://eventsheets_user_script_reading_player.gd"
const ENEMY_PATH := "user://eventsheets_user_script_reading_enemy.gd"
const LAMBDA_PATH := "user://eventsheets_user_script_reading_lambda.gd"

const PLAYER_SOURCE := """class_name ReadingTestPlayer
extends CharacterBody2D

enum State { IDLE, JUMP }

const GRAVITY := 980.0

@export var speed: float = 220.0

var state: State = State.IDLE
var health := 3
var coins := 0

@onready var sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = direction * speed

	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = -400.0

	move_and_slide()
	add_coin()


func _update_state() -> void:
	match state:
		State.JUMP:
			if is_on_floor():
				state = State.IDLE


func add_coin() -> void:
	coins += 1


func take_damage(amount):
	health -= amount
"""

const ENEMY_SOURCE := """extends Area2D

var _start_x: float
var _dir := 1.0
var _push: Vector2 = Vector2.ZERO


class Patrol:
	var turns: int = 0

	func record_turn() -> void:
		turns += 1


func _ready() -> void:
	_start_x = position.x


func _process(delta: float) -> void:
	position.x += _dir * 40.0 * delta
	if absf(position.x - _start_x) > 64.0:
		_dir = -_dir
	_push += Vector2.ONE


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_dir = 1.0


func count(rows: Array) -> int:
	var total := 0
	for row: Variant in rows:
		if row is Dictionary:
			total += 1
	return total
"""


# Names a function written inline declares: a connected lambda's parameter, and the local and loop
# item of a body handed to the sheet-edit funnel, which the canvas reads as rows of their own - so a
# note under them must know those names as well as the file's. The plugin's own editor helpers are
# written this way, and a user who opens one reads it like any other script.
const LAMBDA_SOURCE := """extends Node

var _label: Label
var _dock: Object = null


func _ready() -> void:
	_label = Label.new()
	_label.gui_input.connect(func(input_event: InputEvent) -> void:
		if input_event is InputEventKey and (input_event as InputEventKey).pressed and (input_event as InputEventKey).keycode == KEY_ESCAPE:
			_label.visible = false
			if _label.get_parent() != null:
				_label.grab_focus()
	)


func refill(rows: Array, anchor: Resource) -> bool:
	var changed: bool = _dock._perform_undoable_sheet_edit("Paste", func() -> bool:
		var insert_after: Resource = anchor
		for row_entry: Variant in rows:
			_dock.place(row_entry, insert_after)
			insert_after = row_entry
		return true
	)
	return changed
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_player() and ok
	ok = _test_inner_class_keeps_the_members() and ok
	ok = _test_inline_function_names() and ok
	ok = _test_chips_leave_the_condition_room() and ok
	return ok


static func _test_player() -> bool:
	var dock: EventSheetDock = _open(PLAYER_PATH, PLAYER_SOURCE)
	var lines: PackedStringArray = _lines(dock)
	var ok: bool = SUPPORT.pins(NAME, [
		["the inverted floor test reads on the player, under the inverted mark",
			_line_with(lines, "Is on floor", 0),
			"System: Every tick (physics) | [not] ReadingTestPlayer: Is on floor | ReadingTestPlayer: Apply gravity GRAVITY (per second) | ⟡ Movement"],
		["the same test inside a match branch reads the same words on the same object",
			_line_with(lines, "Is on floor", 1), "ReadingTestPlayer: Is on floor | System: Go to Idle"],
		["a velocity verb leads with the script's own name, not its class",
			_line_with(lines, "Set velocity Y", 0), "Keyboard: On \"ui_accept\" pressed | ReadingTestPlayer: Set velocity Y to -400"],
		["a call to the script's own function leads with the script's own name",
			_line_with(lines, "ReadingTestPlayer: add_coin", 0),
			"System: Every tick (physics) | ReadingTestPlayer: Move (and slide along what it hits) | ReadingTestPlayer: add_coin | ⟡ Movement"],
		["a local the step declares is a variable: no note says otherwise",
			_notes(dock), PackedStringArray()],
		# The same variable row every other member reads as (its scope and type words are painted as
		# the type tile, `Sprite2D`), with its own line as the echo - not the "Object" row it was.
		["an @onready node reads as a variable row - its type, its name and its value",
			_line_with(lines, "sprite", 0),
			"Instance | object | sprite | = | $Sprite2D | @onready var sprite: Sprite2D = $Sprite2D"],
	])
	dock.free()
	return ok


static func _test_inner_class_keeps_the_members() -> bool:
	var dock: EventSheetDock = _open(ENEMY_PATH, ENEMY_SOURCE)
	# Every name the file uses here is real: its members (the class inside it notwithstanding), a
	# vector added to, an input handler's event, a loop's item and a function's local.
	var ok: bool = SUPPORT.check(NAME, "a class inside the file leaves the file's own members variables",
		_notes(dock), PackedStringArray())
	dock.free()
	return ok


static func _test_inline_function_names() -> bool:
	var dock: EventSheetDock = _open(LAMBDA_PATH, LAMBDA_SOURCE)
	var ok: bool = SUPPORT.check(NAME, "a lambda's parameter, local and loop item are names the file declares",
		_notes(dock), PackedStringArray())
	dock.free()
	return ok


static func _test_chips_leave_the_condition_room() -> bool:
	var dock: EventSheetDock = _open(PLAYER_PATH, PLAYER_SOURCE)
	var row: EventRowData = EventRowData.new()
	row.row_type = EventRowData.RowType.EVENT
	var chip: SemanticSpan = SemanticSpan.new()
	chip.text = "Making an object and putting it somewhere, said at length so it cannot fit"
	chip.type = SemanticSpan.SpanType.CONDITION
	chip.metadata = {"kind": "pattern_chip", "lane": "condition", "chip": true, "line_index": 0}
	row.spans = [chip]
	var font: Font = ThemeDB.fallback_font
	var viewport: EventSheetViewport = dock._viewport
	viewport.size = Vector2(900, 600)
	var lane: float = viewport.lane_width_for("condition")
	var taken: float = viewport._row_metrics_helper.condition_trailing_width(row, 0, font, 14)
	var ok: bool = SUPPORT.check(NAME, "a long chip after a condition takes under half the lane",
		taken <= lane * 0.45 + 0.01, true)
	dock.free()
	return ok


## The dock with `source` opened from `path`, read the way an opened script is read.
static func _open(path: String, source: String) -> EventSheetDock:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	dock._viewport.set_reading_mode(true)
	return dock


## One line per row of the canvas: each condition and action cell as `object: words`, ` | ` between
## them, and `[not]` before a cell wearing the inverted mark.
static func _lines(dock: EventSheetDock) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row: EventRowData in _walk(dock._viewport._root_rows, dock._viewport):
		var cells: PackedStringArray = PackedStringArray()
		var mark: String = ""
		for span: SemanticSpan in row.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if str(metadata.get("badge_style", "")) == "negated":
				mark = "[not] "
				continue
			var text: String = span.text.strip_edges()
			var object_label: String = str(metadata.get("object_label", ""))
			if text.is_empty() or bool(metadata.get("badge", false)):
				continue
			if object_label.is_empty():
				cells.append(mark + text)
			else:
				cells.append("%s%s: %s" % [mark, object_label, text])
			mark = ""
		out.append(" | ".join(cells))
	return out


## The `nth` line holding `needle`, or "" when there are fewer.
static func _line_with(lines: PackedStringArray, needle: String, nth: int) -> String:
	var seen: int = 0
	for line: String in lines:
		if line.contains(needle):
			if seen == nth:
				return line
			seen += 1
	return ""


## The words of every variable note the canvas hangs under an event.
static func _notes(dock: EventSheetDock) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row: EventRowData in _walk(dock._viewport._root_rows, dock._viewport):
		if row.row_uid.begins_with("variable_note_"):
			var words: PackedStringArray = PackedStringArray()
			for span: SemanticSpan in row.spans:
				words.append(span.text)
			out.append(" ".join(words))
	return out


## Every row in the tree, parents before children, with its spans built.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var out: Array = []
	for row: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row)
		out.append(row)
		out.append_array(_walk(row.children, viewport))
	return out
