# A drag slide used to ask for a redraw twice a frame: the pointer move that drives the drag queues
# one, and the per-frame slide step queued another that ran after it. The slide is a function of the
# clock, so the first draw already shows it; a frame that has drawn skips the slide's own redraw while
# the slide is still moving. The frame the slide STOPS is never skipped: the last picture drawn has
# to be the rest position.
@tool
class_name DragRedrawCoalesceTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var frame: int = Engine.get_process_frames()
	var ok: bool = true

	viewport._last_draw_frame = -1
	ok = SUPPORT.check("drag_redraw_coalesce_test", "a moving slide with no draw this frame asks for one", viewport.slide_needs_redraw(true, true), true) and ok
	viewport._last_draw_frame = frame
	ok = SUPPORT.check("drag_redraw_coalesce_test", "a moving slide that already drew this frame does not ask again", viewport.slide_needs_redraw(true, true), false) and ok
	ok = SUPPORT.check("drag_redraw_coalesce_test", "the first moving frame after a draw earlier in the frame is skipped too", viewport.slide_needs_redraw(true, false), false) and ok
	ok = SUPPORT.check("drag_redraw_coalesce_test", "the frame the slide stops always redraws, even after a draw this frame", viewport.slide_needs_redraw(false, true), true) and ok
	ok = SUPPORT.check("drag_redraw_coalesce_test", "a still slide that was still asks for nothing", viewport.slide_needs_redraw(false, false), false) and ok
	viewport._last_draw_frame = frame - 1
	ok = SUPPORT.check("drag_redraw_coalesce_test", "the next frame asks again", viewport.slide_needs_redraw(true, true), true) and ok

	viewport.free()
	return ok
