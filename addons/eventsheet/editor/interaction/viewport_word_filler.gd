# Godot EventSheets - the words of the rows nobody has scrolled to, built while the editor is idle.
#
# A long sheet builds a row's words (its spans) when the row is first laid out, so a rebuild pays only
# for the screenful in view. But building a row's words is also when its readings claim the patterns
# they recognise, and the readers that count patterns over the WHOLE sheet - the coverage chip on the
# Project bar, an object's "could adopt", the Manual's "Patterns using this" - answered from however
# far the reader had scrolled. This builds the rest a few milliseconds per frame after every rebuild,
# so those answers arrive at what the whole sheet says without the rebuild waiting for it, and then
# measures every row again with its words (keeping the view where it was).
#
# Rows of an older build are never touched: a rebuild starts the walk over. Nothing runs without a
# main loop (a test, a headless tool), and nothing runs for a figure, which builds its own rows.
@tool
extends RefCounted

## How long one frame may spend building words, in microseconds.
const FRAME_BUDGET_USEC: int = 4000

var _viewport: Control = null
## The rows still to build, in sheet order, and the build they belong to.
var _pending: Array[EventRowData] = []
var _cursor: int = 0
var _revision: int = -1
var _scheduled: bool = false


func init(viewport: Control) -> void:
	_viewport = viewport


## Starts over on the rows the view holds now.
func restart() -> void:
	_pending.clear()
	_cursor = 0
	_revision = int(_viewport.get("_rows_revision"))
	if bool(_viewport.get("figure_mode")):
		return
	for row_data: EventRowData in _viewport.get("_root_rows"):
		_collect_unbuilt(row_data)
	if not is_done():
		_schedule()


## Whether every row of the current build has its words.
func is_done() -> bool:
	return _cursor >= _pending.size()


## Picks the walk up again if it was started while the view was out of the tree (no frames to wait for).
func resume() -> void:
	if not is_done():
		_schedule()


## Builds words until the frame's budget is spent. Public so a test can drive it without frames.
func pump(budget_usec: int = FRAME_BUDGET_USEC) -> void:
	if not is_instance_valid(_viewport) or int(_viewport.get("_rows_revision")) != _revision:
		_pending.clear()
		return
	var started: int = Time.get_ticks_usec()
	var builder: ViewportRowBuilder = _viewport.get("_row_builder")
	while _cursor < _pending.size() and Time.get_ticks_usec() - started < budget_usec:
		builder._ensure_event_spans(_pending[_cursor])
		_cursor += 1
	if is_done():
		_pending.clear()
		_cursor = 0
		_viewport.call("settle_all_row_heights")
		return
	_schedule()


func _collect_unbuilt(row_data: EventRowData) -> void:
	if row_data == null:
		return
	if row_data.row_type == EventRowData.RowType.EVENT and row_data.spans.is_empty():
		_pending.append(row_data)
	for child: EventRowData in row_data.children:
		_collect_unbuilt(child)


func _schedule() -> void:
	if _scheduled:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not is_instance_valid(_viewport) or not (_viewport as Node).is_inside_tree():
		return
	_scheduled = true
	tree.process_frame.connect(_on_frame, CONNECT_ONE_SHOT)


func _on_frame() -> void:
	_scheduled = false
	pump()
