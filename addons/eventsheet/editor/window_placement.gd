@tool
class_name EventSheetWindowPlacement
extends RefCounted

## Where a window the plugin opens lands, so none of them opens partly off screen, on the wrong
## monitor, or away from what opened it. Every dialog, menu and floating panel goes through the
## functions at the bottom (popup_centered, popup_below, popup_at, move_within, ...); a sweep test
## fails when a new opener calls the engine's popup functions directly.
##
## The engine already clamps a PopupMenu against its own screen, but it does not do it for a plain
## Window or a dialog (an oversize dialog, or one centred over an editor window that is itself half
## off screen, opens with its title bar or buttons out of reach), it never flips an anchored popup
## above its anchor, and it centres on the parent window with no thought for which monitor that
## window sits on. This file adds exactly that and nothing else:
##
##   * the rect a window may use is the USABLE rect (the screen less the task bar) of the screen the
##     window's anchor is on - the pointer, the control, or the editor window it opens over;
##   * a window embedded in the editor (the project setting embed_subwindows) lives in the editor
##     window's own coordinates, so its bounds are that window, not a screen;
##   * a window larger than the room it has is made smaller, then moved inside;
##   * an anchored popup opens below its anchor, or above it when there is no room below, and
##     right-aligned to the anchor when there is no room to the right;
##   * a window with a native title bar keeps that bar on screen: the room it has starts a title
##     bar's height lower.
##
## The rect maths is pure (the rects go in, the rect comes out), so it is pinned headless; only the
## last section asks the engine which screen and which embedding mode.

## The gap kept between a window and the edge of the room it has, in editor-scale-1 pixels.
const EDGE_MARGIN: int = 8
## What a native title bar costs at editor-scale 1; the engine does not say before the window shows.
const NATIVE_TITLE_BAR: int = 32
## The smallest content scale a window is shrunk to when its content is bigger than the room it has.
const MIN_SCALE: float = 0.35
const SCALE_SLACK: float = 0.95
## Set on a window this file has scaled, so the next open puts it back before measuring.
const SCALED_META: StringName = &"window_placement_scaled"


# ── Pure rect maths ───────────────────────────────────────────────────────────────────────────


## `rect` made to lie inside `bounds`: shrunk when it is larger, then slid in. A bounds with no area
## (a headless run, a screen the OS has not described) is "no constraint" and returns `rect`.
static func fit(rect: Rect2i, bounds: Rect2i) -> Rect2i:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return rect
	var fitted: Vector2i = Vector2i(mini(rect.size.x, bounds.size.x), mini(rect.size.y, bounds.size.y))
	var left: int = clampi(rect.position.x, bounds.position.x, bounds.end.x - fitted.x)
	var top: int = clampi(rect.position.y, bounds.position.y, bounds.end.y - fitted.y)
	return Rect2i(Vector2i(left, top), fitted)


## `bounds` with `margin` pixels kept clear all round and `top` more along its upper edge (the room
## a title bar takes). Never produces a negative size.
static func inset(bounds: Rect2i, margin: int, top: int = 0) -> Rect2i:
	var room: Vector2i = Vector2i(maxi(bounds.size.x - margin * 2, 0), maxi(bounds.size.y - margin * 2 - top, 0))
	return Rect2i(bounds.position + Vector2i(margin, margin + top), room)


## A window of `size` centred on `around` (the editor window, or the visible part of it), then fitted
## into `bounds`.
static func centred(size: Vector2i, around: Rect2i, bounds: Rect2i) -> Rect2i:
	var wanted: Rect2i = Rect2i(around.position + (around.size - size) / 2, size)
	return fit(wanted, bounds)


## A window of `size` opening beside `anchor`: below it and left-aligned with it by default. With no
## room below it opens above (when that has room, else on whichever side has more); with no room to
## the right of the anchor's left edge it is right-aligned to the anchor's right edge instead. The
## result is fitted into `bounds` last, so an oversize window still ends up inside.
static func anchored(size: Vector2i, anchor: Rect2i, bounds: Rect2i) -> Rect2i:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return Rect2i(anchor.position + Vector2i(0, anchor.size.y), size)
	var left: int = anchor.position.x
	if left + size.x > bounds.end.x:
		left = anchor.end.x - size.x
	var top: int = anchor.end.y
	if top + size.y > bounds.end.y:
		var above: int = anchor.position.y - size.y
		var room_below: int = bounds.end.y - anchor.end.y
		var room_above: int = anchor.position.y - bounds.position.y
		if above >= bounds.position.y or room_above > room_below:
			top = above
	return fit(Rect2i(Vector2i(left, top), size), bounds)


## A window of `size` opening at a point (a context menu at the pointer): its corner on the point,
## flipped to the left of the point and above it when it would run off the right or bottom edge.
static func at_point(size: Vector2i, point: Vector2i, bounds: Rect2i) -> Rect2i:
	return anchored(size, Rect2i(point, Vector2i.ZERO), bounds)


## The usable rect, out of `usables`, that holds most of `rect`; with none overlapping, the one whose
## centre is nearest. `usables` is every screen's usable rect, so a second monitor at a negative or
## large offset is just another entry. An empty list answers an empty rect.
static func screen_of(rect: Rect2i, usables: Array) -> Rect2i:
	var best: Rect2i = Rect2i()
	var best_area: int = -1
	var best_distance: float = INF
	var centre: Vector2 = Vector2(rect.position) + Vector2(rect.size) * 0.5
	for entry: Variant in usables:
		var usable: Rect2i = entry as Rect2i
		var overlap: Rect2i = usable.intersection(rect)
		var area: int = overlap.size.x * overlap.size.y
		var distance: float = centre.distance_to(Vector2(usable.position) + Vector2(usable.size) * 0.5)
		if area > best_area or (area == best_area and distance < best_distance):
			best = usable
			best_area = area
			best_distance = distance
	return best


## The part of `rect` that is inside `bounds`, or `bounds` itself when none of it is: what a window
## centres on when the editor window it opens over is partly (or wholly) off screen.
static func visible_part(rect: Rect2i, bounds: Rect2i) -> Rect2i:
	var seen: Rect2i = rect.intersection(bounds)
	if seen.size.x <= 0 or seen.size.y <= 0:
		return bounds
	return seen


# ── What the engine says ──────────────────────────────────────────────────────────────────────


## Every screen's usable rect, in screen coordinates.
static func usable_rects() -> Array:
	var rects: Array = []
	for index: int in DisplayServer.get_screen_count():
		rects.append(DisplayServer.screen_get_usable_rect(index))
	return rects


## True when `window` will live inside the editor window instead of being a window of its own.
static func is_embedded(window: Window) -> bool:
	return window != null and window.is_inside_tree() and window.is_embedded()


## The coordinate system `window` is positioned in, as {"bounds": the room it may use, "around": what
## it centres on}. Embedded: the editor window's own pixels. Otherwise screen pixels, the room being
## the usable rect of the screen holding `focus` (a rect of the window's anchor) - or, with no focus,
## the screen holding the window it opens over.
static func room_for(window: Window, focus: Rect2i = Rect2i()) -> Dictionary:
	var decorated: bool = not (window is Popup) and not window.borderless
	if is_embedded(window):
		var parent: Node = window.get_parent()
		var hosting: Viewport = parent.get_viewport() if parent != null else window.get_viewport()
		var whole: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(hosting.get_visible_rect().size))
		var bar: int = window.get_theme_constant("title_height", "Window") if decorated else 0
		return {"bounds": inset(whole, _margin(decorated), bar), "around": whole}
	var host: Window = _host_of(window)
	var host_rect: Rect2i = Rect2i(host.position, host.size) if host != null else Rect2i()
	var anchor: Rect2i = focus if focus.size != Vector2i.ZERO or focus.position != Vector2i.ZERO else host_rect
	var screen: Rect2i = screen_of(anchor, usable_rects())
	var bar: int = int(EventSheetPalette.scaled_f(float(NATIVE_TITLE_BAR))) if decorated else 0
	var bounds: Rect2i = inset(screen, _margin(decorated), bar)
	var around: Rect2i = visible_part(host_rect, bounds) if host_rect.size != Vector2i.ZERO else bounds
	return {"bounds": bounds, "around": around}


## Where the pointer is, in the coordinates `window` is positioned in.
static func pointer_for(window: Window) -> Vector2i:
	if is_embedded(window):
		var parent: Node = window.get_parent()
		var hosting: Viewport = parent.get_viewport() if parent != null else window.get_viewport()
		return Vector2i(hosting.get_mouse_position())
	return DisplayServer.mouse_get_position()


## Where the pointer is, in the coordinates a window opened from `source` is positioned in: the
## screen's, or - when the editor embeds its sub-windows - the editor window's own.
static func pointer_over(source: Node) -> Vector2i:
	var hosting: Viewport = source.get_viewport() if source != null and source.is_inside_tree() else null
	if hosting != null and hosting.is_embedding_subwindows():
		return Vector2i(hosting.get_mouse_position())
	return DisplayServer.mouse_get_position()


## Opens `window` centred over the editor window it belongs to, at `size` (zero keeps the size it
## has), fully inside the screen. The replacement for Window.popup_centered.
static func popup_centered(window: Window, size: Vector2i = Vector2i.ZERO) -> void:
	var room: Dictionary = room_for(window)
	var wanted: Vector2i = _size_wanted(window, size, room["bounds"])
	window.popup(centred(wanted, room["around"], room["bounds"]))
	_keep_inside(window, room["bounds"])


## Opens `window` centred at a share of the room it has (the file browsers' 0.6). The replacement for
## Window.popup_centered_ratio.
static func popup_centered_ratio(window: Window, ratio: float = 0.8) -> void:
	var room: Dictionary = room_for(window)
	var bounds: Rect2i = room["bounds"]
	var wanted: Vector2i = Vector2i(Vector2(bounds.size) * ratio)
	popup_centered(window, wanted if wanted != Vector2i.ZERO else _size_wanted(window, Vector2i.ZERO))


## Opens `window` beside `anchor` (a rect in the window's own coordinates - a control's
## get_screen_position() and size), below it or above when there is no room below.
static func popup_below(window: Window, anchor: Rect2i, size: Vector2i = Vector2i.ZERO) -> void:
	var room: Dictionary = room_for(window, anchor)
	window.popup(anchored(_size_wanted(window, size, room["bounds"]), anchor, room["bounds"]))
	_keep_inside(window, room["bounds"])


## Opens `window` with its corner at `point` (the pointer, in the window's own coordinates),
## flipping away from the edges it would cross. A menu's size is measured, not guessed.
static func popup_at(window: Window, point: Vector2i, size: Vector2i = Vector2i.ZERO) -> void:
	var room: Dictionary = room_for(window, Rect2i(point, Vector2i.ONE))
	window.popup(at_point(_size_wanted(window, size, room["bounds"]), point, room["bounds"]))
	_keep_inside(window, room["bounds"])


## Opens `window` where it already is (its position and size untouched) but inside the room, for a
## panel that was placed by hand or remembers where it was.
static func popup_placed(window: Window) -> void:
	var room: Dictionary = room_for(window, Rect2i(window.position, window.size))
	window.popup(fit(Rect2i(window.position, _size_wanted(window, Vector2i.ZERO, room["bounds"])), room["bounds"]))
	_keep_inside(window, room["bounds"])


## Moves an OPEN window so it starts at `corner` if it fits there, else as near as keeps it inside
## (a dialog that opens beside the row it describes).
static func move_within(window: Window, corner: Vector2i) -> void:
	var room: Dictionary = room_for(window, Rect2i(corner, Vector2i.ONE))
	var rect: Rect2i = fit(Rect2i(corner, window.size), room["bounds"])
	window.size = rect.size
	window.position = rect.position


## Shows a window that is positioned by hand (the tour) at `corner`, kept inside the room.
static func show_at(window: Window, corner: Vector2i) -> void:
	var room: Dictionary = room_for(window, Rect2i(corner, Vector2i.ONE))
	var rect: Rect2i = fit(Rect2i(corner, _size_wanted(window, Vector2i.ZERO, room["bounds"])), room["bounds"])
	window.position = rect.position
	window.size = rect.size
	window.show()
	_keep_inside(window, room["bounds"])


## Pulls an open window back inside the room it has after its size changed (a dialog that grew to
## fit its words). Safe to call on a hidden window: it does nothing.
static func keep_on_screen(window: Window) -> void:
	if window == null or not window.visible or not window.is_inside_tree():
		return
	var room: Dictionary = room_for(window, Rect2i(window.position, window.size))
	_keep_inside(window, room["bounds"])


# ── Internals ─────────────────────────────────────────────────────────────────────────────────


## The size a window opens at: the one asked for, else the one it has, else what its content needs.
## A window whose content cannot be any smaller than the room it has (a long form in a small editor
## window, or on a small screen) is scaled down with the engine's own content scale until it fits, so
## the whole window - title bar and buttons - stays reachable instead of running off the edge. A window
## that fits is put back to scale 1.
static func _size_wanted(window: Window, size: Vector2i, bounds: Rect2i = Rect2i()) -> Vector2i:
	var wanted: Vector2i = size
	var least: Vector2 = window.get_contents_minimum_size()
	if window.has_meta(SCALED_META):
		window.content_scale_factor = 1.0
		window.remove_meta(SCALED_META)
		least = window.get_contents_minimum_size()
	if wanted.x <= 0 or wanted.y <= 0:
		# A menu is exactly as big as its items; every other window keeps the size it has.
		wanted = Vector2i(least.ceil()) if window is PopupMenu else window.size
	var factor: float = scale_to_fit(Vector2i(least.ceil()).max(window.min_size), bounds) if not (window is PopupMenu) else 1.0
	if factor < 1.0:
		window.content_scale_factor = factor
		window.set_meta(SCALED_META, true)
		window.min_size = window.min_size.min(bounds.size)
		var scaled: Vector2i = Vector2i((Vector2(wanted.max(Vector2i(least.ceil()))) * factor).ceil())
		return scaled.min(bounds.size)
	wanted = wanted.max(Vector2i(least.ceil())).max(window.min_size)
	return Vector2i(maxi(wanted.x, 1), maxi(wanted.y, 1))


## How far a window whose content needs at least `least` pixels must be scaled to fit `bounds`: 1.0
## when it already fits (or there is no room to measure), never below MIN_SCALE - a window that would
## need less than that is left at MIN_SCALE and kept inside by the clamp instead of becoming unreadable.
static func scale_to_fit(least: Vector2i, bounds: Rect2i) -> float:
	if bounds.size.x <= 0 or bounds.size.y <= 0 or least.x <= 0 or least.y <= 0:
		return 1.0
	if least.x <= bounds.size.x and least.y <= bounds.size.y:
		return 1.0
	# A hair under the exact ratio: a popup's panel margins are not scaled with its content.
	return clampf(minf(float(bounds.size.x) / float(least.x), float(bounds.size.y) / float(least.y)) * SCALE_SLACK, MIN_SCALE, 1.0)


## After the engine has shown the window: its real rect may differ from the one asked for (a dialog
## grows to its content's minimum, a menu measures its items), so fit that too.
static func _keep_inside(window: Window, bounds: Rect2i) -> void:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var actual: Rect2i = Rect2i(window.position, window.size)
	var fitted: Rect2i = fit(actual, bounds)
	if fitted.size != actual.size:
		window.size = fitted.size
	if fitted.position != actual.position:
		window.position = fitted.position


static func _margin(decorated: bool) -> int:
	return int(EventSheetPalette.scaled_f(float(EDGE_MARGIN))) if decorated else 0


## The window `window` opens over: its parent's window.
static func _host_of(window: Window) -> Window:
	if window == null or not window.is_inside_tree():
		return null
	var parent: Node = window.get_parent()
	return parent.get_window() if parent != null else window.get_window()
