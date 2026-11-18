# Godot EventSheets - a narrow row keeps its words whole.
#
# Three cells of an opened script's rows shared a lane in a way that broke the words in a narrow dock:
#   - a trigger's own words ("On leaving STAGGER") were left what its payload chips did not take, and
#     in a narrow lane that was a few pixels, so the state name was drawn a letter to a line;
#   - the names a match arm binds were laid after the arm's sentence at their own width, and ran on
#     over the cell beside it;
#   - the cue after an undo step ("the steps below are the edit") filled whatever the other cells of
#     its line left, and with a few pixels over it wrapped a letter to a line in a row as tall as the
#     sentence was long.
# Each is measured on the layout a real viewport makes at three dock widths.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "narrow_row_cells_test"
const PATH := "res://narrow_row_cells.gd"

const STATES := """extends CharacterBody2D

enum State { PATROL, CHASE, STAGGER }

signal state_changed(from_state: int, to_state: int)

var state_entered_msec: int = Time.get_ticks_msec()
var previous_state: State = State.PATROL
var state: State = State.PATROL:
	set(value):
		if value == state:
			return
		var was: int = state
		previous_state = was
		state = value
		state_entered_msec = Time.get_ticks_msec()
		state_changed.emit(was, value)


func _ready() -> void:
	state_changed.connect(_on_state_changed)


func _process(_delta: float) -> void:
	if state == State.PATROL:
		state = State.CHASE
	if state == State.STAGGER and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > 1.0:
		state = State.PATROL
	if previous_state == State.CHASE:
		state = State.STAGGER


func _on_state_changed(from_state: int, to_state: int) -> void:
	if from_state == State.STAGGER:
		state = State.PATROL
	if to_state == State.CHASE:
		state = State.PATROL
"""

const PATTERNS := """extends Node2D

var event: Array = []
var hp: int = 100

func _process(_delta: float) -> void:
	match event:
		["move", var x, var y]:
			position = Vector2(x, y)
		{"type": "hit", "amount": var a}:
			hp -= a
		var other when other is String:
			print(other)
		_:
			pass
"""

const UNDO_STEP := """@tool
extends RefCounted

var _dock: Control = null
var mode: String = ""


func _init(dock: Control) -> void:
	_dock = dock


func apply() -> void:
	var changed: bool = _dock._perform_undoable_sheet_edit("Apply Cell Edit", func() -> bool:
		if mode == "new_condition_event":
			_append_condition_entry()
			return true
		if mode == "replace_action":
			_replace_action()
			return true
		return false)
	if changed:
		_dock._set_status("Applied.")


func _append_condition_entry() -> void:
	mode = "done"


func _replace_action() -> void:
	mode = "done"
"""

const NOTES := """extends Node2D

var speed: float = 10.0


func _process(delta: float) -> void:
	# Remember to tune the speed value before shipping because the designers keep changing their minds about it.
	position.x += speed * delta
	# Collision layers are documented elsewhere so check the project settings page before touching anything here ever.
	print(speed)
	# Short one.
	print(delta)
"""


static func run() -> bool:
	var ok: bool = true
	for width: float in [800.0, 900.0, 996.0]:
		ok = _triggers(width) and ok
		ok = _patterns(width) and ok
	for width: float in [480.0, 520.0, 640.0, 700.0]:
		ok = _notes_inside(width) and ok
	for width: float in [700.0, 760.0, 800.0, 860.0, 900.0, 950.0, 996.0, 1100.0]:
		ok = _undo_step(width) and ok
	return ok


## A viewport in the scrolling window a dock gives it, with every row of `source` laid out.
static func _laid_out(source: String, width: float) -> Array:
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, PATH)
	sheet.external_source_path = PATH
	sheet.read_only = true
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(width, 900.0)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(view)
	view.set_sheet(sheet)
	view._row_metrics_helper.rebuild()
	for index: int in range(view.get_flat_rows().size()):
		view.get_row_layout_for_test(index)
	return [scroll, view]


## The longest word of a cell fits the width its words are drawn in.
static func _words_whole(view: EventSheetViewport, span: EventSheetSemanticSpan) -> bool:
	var font: Font = view._get_font()
	var font_size: int = view._get_font_size()
	var metadata: Dictionary = span.metadata as Dictionary
	var room: float = view._row_metrics_helper._fill_text_wrap_width(metadata, span.rect.size.x, font, font_size,
		float(metadata.get("object_column_px", -1.0)))
	for word: String in span.text.split(" ", false):
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > room + 0.5:
			return false
	return true


## The first span of the row's action lane, where the cell before it must end.
static func _action_left(row_data: EventRowData) -> float:
	for span: EventSheetSemanticSpan in row_data.spans:
		if str((span.metadata as Dictionary).get("lane", "")) == "action" and span.rect.size.x > 0.0:
			return span.rect.position.x
	return INF


static func _triggers(width: float) -> bool:
	var made: Array = _laid_out(STATES, width)
	var view: EventSheetViewport = made[1]
	var seen: int = 0
	var broken: int = 0
	var over: int = 0
	var left_out: int = 0
	var outside: int = 0
	var overlap: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		var action_left: float = _action_left(row_data)
		var cell_top: float = INF
		var cell_bottom: float = -INF
		for span: EventSheetSemanticSpan in row_data.spans:
			if str((span.metadata as Dictionary).get("kind", "")) == "trigger" and span.rect.size.x > 0.0:
				cell_top = span.rect.position.y
				cell_bottom = span.rect.end.y
		for span: EventSheetSemanticSpan in row_data.spans:
			var kind: String = str((span.metadata as Dictionary).get("kind", ""))
			# A chip under its cell starts below the cell's own words, never inside them.
			if kind == "trigger_payload" and span.rect.size.x > 0.0 and span.rect.position.y > cell_top + 1.0 					and span.rect.position.y < cell_bottom - 0.5:
				overlap += 1
			if kind == "trigger" and (span.text.begins_with("On leaving") or span.text.begins_with("On entering")):
				seen += 1
				if not _words_whole(view, span):
					broken += 1
			if kind == "trigger_payload":
				if span.rect.size.x <= 0.0:
					left_out += 1
				elif span.rect.end.x > action_left:
					over += 1
				if span.rect.end.y > view._row_metrics_helper.row_top(index) + view._row_metrics_helper.row_height(index):
					outside += 1
	var ok: bool = SUPPORT.check(P, "at %d px both state triggers were laid out" % int(width), seen, 2)
	ok = SUPPORT.check(P, "at %d px a state's name is never broken inside a word" % int(width), broken, 0) and ok
	ok = SUPPORT.check(P, "at %d px no payload chip reaches into the action lane" % int(width), over, 0) and ok
	ok = SUPPORT.check(P, "at %d px every value the trigger hands over is drawn, inside its row" % int(width), [left_out, outside], [0, 0]) and ok
	ok = SUPPORT.check(P, "at %d px a chip under its cell does not stand inside the cell" % int(width), overlap, 0) and ok
	made[0].free()
	return ok


static func _patterns(width: float) -> bool:
	var made: Array = _laid_out(PATTERNS, width)
	var view: EventSheetViewport = made[1]
	var seen: int = 0
	var broken: int = 0
	var over: int = 0
	var unmarked: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		var action_left: float = _action_left(row_data)
		for span: EventSheetSemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata as Dictionary
			var kind: String = str(metadata.get("kind", ""))
			if kind == "match_pattern":
				seen += 1
				if not _words_whole(view, span):
					broken += 1
			if kind == "match_binding":
				if span.rect.size.x <= 0.0:
					unmarked += 1
				elif span.rect.end.x > action_left:
					over += 1
	var ok: bool = SUPPORT.check(P, "at %d px the match arms were laid out" % int(width), seen > 2, true)
	ok = SUPPORT.check(P, "at %d px an arm's words are never broken inside a word" % int(width), broken, 0) and ok
	ok = SUPPORT.check(P, "at %d px no name an arm binds runs over the cell beside it" % int(width), over, 0) and ok
	ok = SUPPORT.check(P, "at %d px every name an arm binds is drawn" % int(width), unmarked, 0) and ok
	made[0].free()
	return ok


static func _undo_step(width: float) -> bool:
	var made: Array = _laid_out(UNDO_STEP, width)
	var view: EventSheetViewport = made[1]
	var line_height: float = view._get_event_line_height(view._get_font_size())
	var cue_rows: int = 0
	var tall: int = 0
	var wrapped: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null:
			continue
		for span: EventSheetSemanticSpan in row_data.spans:
			if not span.text.begins_with("↓"):
				continue
			cue_rows += 1
			if span.rect.size.y > line_height * 1.5:
				tall += 1
			if bool((span.metadata as Dictionary).get("comment_wrap", false)):
				wrapped += 1
	var ok: bool = SUPPORT.check(P, "at %d px the undo step's cue was laid out" % int(width), cue_rows, 1)
	ok = SUPPORT.check(P, "at %d px the cue is one line, never a column of letters" % int(width), [tall, wrapped], [0, 0]) and ok
	made[0].free()
	return ok


## A note beside an action wraps to what the reader can see: nothing in the action lane reaches past the
## visible edge, even where the canvas keeps its 640 px floor.
static func _notes_inside(width: float) -> bool:
	var made: Array = _laid_out(NOTES, width)
	var view: EventSheetViewport = made[1]
	var visible: float = view.get_visible_content_width()
	var seen: int = 0
	var past: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		for span: EventSheetSemanticSpan in row_data.spans:
			if str((span.metadata as Dictionary).get("lane", "")) != "action" or span.rect.size.x <= 0.0:
				continue
			seen += 1
			if span.rect.end.x > visible + 0.5:
				past += 1
	var ok: bool = SUPPORT.check(P, "at %d px the actions were laid out" % int(width), seen > 2, true)
	ok = SUPPORT.check(P, "at %d px no action or note reaches past the visible edge" % int(width), past, 0) and ok
	made[0].free()
	return ok
