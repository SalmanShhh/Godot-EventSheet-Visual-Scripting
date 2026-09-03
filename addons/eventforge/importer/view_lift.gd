# EventForge - the two-line thing a VIEW is asked to do, and the row it means.
#
# There is one, and one is enough for a file: writing a picture of a view to disk. It is two
# statements because the first one is a WAIT - reading a viewport's texture before the frame has
# finished drawing hands back whatever was in the buffer, usually black - and the two only mean the
# row together.
#
# WHY IT IS HERE RATHER THAN NOWHERE. Both lines are already claimed on their own by rows that
# shipped long before this one: `await RenderingServer.frame_post_draw` is Wait For Signal, and
# `get_viewport().get_texture().get_image().save_png(path)` is Take Screenshot verbatim (a named
# view instead of `get_viewport()` is Save Image As). So a hand-written still opened as two ordinary
# rows, and Save A Still Of A View - which emits exactly those two lines - could never read back as
# itself. A run claimed here is asked before either single line is looked at, which is the whole
# reason the run seam exists.
#
# WHAT IS DELIBERATELY NOT CLAIMED. The wait on its own, and the write on its own: each keeps the
# row it already had. Only the pair, adjacent and at the same indentation, is the still.
@tool
class_name EventForgeViewLift
extends RefCounted

## The wait that makes the picture a picture rather than an empty buffer. Written out here because
## it is the entry's `mark` as well as its first statement, and the two must not drift apart.
const FRAME_WAIT: String = "await RenderingServer.frame_post_draw"

## Built once for the life of the session, like every other family's table.
static var _entries: Array[Dictionary] = []


## The row a run of statements means, or {} when nothing here claims it.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## Every run this family claims.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_save_still_entry()]
	return _entries


## The still: wait for the frame to finish drawing, then write what the view is drawing to a PNG.
## The view and the file are the row's two fields, and both ride back out as the author wrote them.
static func _save_still_entry() -> Dictionary:
	return {
		"id": "view_save_still",
		"ace_id": "ViewSaveStill",
		"mark": FRAME_WAIT,
		"statements": [
			{"pattern": "^await RenderingServer\\.frame_post_draw$"},
			{"pattern": "^(?<view>.+)\\.get_texture\\(\\)\\.get_image\\(\\)\\.save_png\\((?<path>.+)\\)$"}
		],
		"params": ["view", "path"],
		"shape": FRAME_WAIT + "\n{view}.get_texture().get_image().save_png({path})",
		"slots": {"view": "get_viewport()", "path": "\"user://still.png\""}
	}
