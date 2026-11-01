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
## Set on a window whose original min_size was lowered to fit its room, so the next open restores it.
const MIN_SIZE_META: StringName = &"window_placement_min_size"
## Set on a scroll the plugin built with its own least size, which is that size where the room has it.
const WANTED_MIN_META: StringName = &"window_placement_wanted_min"
## The size a body is given to measure its window's frame by, bigger than any screen.
const PROBE: float = 16000.0
## The least a scrolled body is ever squeezed to (editor-scale-1 pixels), however little room is left.
const BODY_LEAST: float = 120.0


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
	fit_bodies(window, room["bounds"])
	_keep_inside(window, room["bounds"])


## Makes an open window at least as big as its content needs and no bigger than its room: the body is
## re-measured against the room (so it scrolls instead of outgrowing it), then the window grows to the
## content's least size and is pulled back inside. On a window that is hidden or not in the tree there is no room to measure: it only grows it.
static func fit_to_content(window: Window) -> void:
	if window == null:
		return
	if not window.is_inside_tree() or not window.visible:
		window.size = window.size.max(Vector2i(window.get_contents_minimum_size().ceil()))
		return
	var room: Dictionary = room_for(window, Rect2i(window.position, window.size))
	fit_bodies(window, room["bounds"])
	window.size = window.size.max(Vector2i(window.get_contents_minimum_size().ceil()))
	_keep_inside(window, room["bounds"])


# ── Internals ─────────────────────────────────────────────────────────────────────────────────


## The size a window opens at: the one asked for, else the one it has, else what its content needs.
## A window whose content cannot be any smaller than the room it has (a long form in a small editor
## window, or on a small screen) never shrinks its text: it is clamped to the room and its BODY
## scrolls (see fit_bodies), while its title bar and button row stay put and visible.
static func _size_wanted(window: Window, size: Vector2i, bounds: Rect2i = Rect2i()) -> Vector2i:
	var wanted: Vector2i = size
	var is_menu: bool = window is PopupMenu
	if not is_menu:
		fit_bodies(window, bounds)
	var least: Vector2i = Vector2i(window.get_contents_minimum_size().ceil())
	if wanted.x <= 0 or wanted.y <= 0:
		# A menu is exactly as big as its items; every other window keeps the size it has.
		wanted = least if is_menu else window.size
	wanted = wanted.max(least).max(window.min_size)
	if not is_menu and bounds.size.x > 0 and bounds.size.y > 0:
		wanted = wanted.min(bounds.size)
	return Vector2i(maxi(wanted.x, 1), maxi(wanted.y, 1))


## Makes `window`'s content fit the room `bounds` without shrinking it: when the content's least size
## is bigger than the room, the body of the dialog (everything but its title bar and its button row)
## is put in a BodyScroll, whose own least size is the content's clamped to what is left of the room
## after the window's chrome. A body that already scrolls is re-measured, so a window opened again in a
## bigger room gets its whole content back and one opened in a smaller room scrolls. A window whose
## content fits is left as it was. Popup menus and popups are untouched (they size to their items).
static func fit_bodies(window: Window, bounds: Rect2i) -> void:
	if window == null or window is PopupMenu:
		return
	if window is Popup:
		clamp_own_scrolls(window, bounds)
	if window.has_meta(MIN_SIZE_META):
		window.min_size = window.get_meta(MIN_SIZE_META)
		window.remove_meta(MIN_SIZE_META)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var scrolls: Array = body_scrolls(window)
	for scroll: Variant in scrolls:
		(scroll as Control).custom_minimum_size = Vector2.ZERO
	if scrolls.is_empty():
		var needed: Vector2i = Vector2i((window.get_contents_minimum_size() + _panel_extra(window)).ceil()).max(window.min_size)
		if needed.x <= bounds.size.x and needed.y <= bounds.size.y:
			return
		scrolls = wrap_bodies(window)
		if scrolls.is_empty():
			return
	if window.min_size.x > bounds.size.x or window.min_size.y > bounds.size.y:
		window.set_meta(MIN_SIZE_META, window.min_size)
		window.min_size = window.min_size.min(bounds.size)
	var left: Vector2 = Vector2(bounds.size) - frame_of(window, scrolls)
	for scroll: Variant in scrolls:
		(scroll as BodyScroll).fit_to(left)


## A popup panel whose content is a scroll of its own with a least size (the blend-mode strip) keeps
## that size where the room has it and is clamped to what is left of the room where it has not.
static func clamp_own_scrolls(popup: Window, bounds: Rect2i) -> void:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var scrolls: Array = []
	for child: Node in popup.get_children():
		if child is ScrollContainer and not child is BodyScroll:
			scrolls.append(child)
			if not child.has_meta(WANTED_MIN_META):
				child.set_meta(WANTED_MIN_META, (child as Control).custom_minimum_size)
			(child as Control).custom_minimum_size = Vector2.ZERO
	if scrolls.is_empty():
		return
	var left: Vector2 = Vector2(bounds.size) - frame_of(popup, scrolls)
	for scroll: Variant in scrolls:
		var wanted: Vector2 = (scroll as Node).get_meta(WANTED_MIN_META)
		(scroll as Control).custom_minimum_size = Vector2(minf(wanted.x, maxf(left.x, 0.0)), minf(wanted.y, maxf(left.y, 0.0)))


## What `window` needs around its scrolled bodies: the dialog's margins, its button row, a popup's
## panel. Read by giving the first body a size nothing else in the window can match, so the window's
## least size is that body plus exactly its frame (a button row is as wide as it is, and is no part of
## the frame's width, so subtracting its own least size would take it for one).
static func frame_of(window: Window, scrolls: Array) -> Vector2:
	if scrolls.is_empty():
		return Vector2.ZERO
	var probe: Vector2 = Vector2(PROBE, PROBE)
	var first: Control = scrolls[0] as Control
	first.custom_minimum_size = probe
	var frame: Vector2 = window.get_contents_minimum_size() + _panel_extra(window) - probe
	first.custom_minimum_size = Vector2.ZERO
	return frame.max(Vector2.ZERO)


## The BodyScrolls `window` already holds (a dialog's own children, or one level down in a plain
## window's backdrop).
static func body_scrolls(window: Window) -> Array:
	var found: Array = []
	for child: Node in window.get_children():
		if child is BodyScroll:
			found.append(child)
		elif child is EventSheetPopupUI.WindowBackdrop:
			for inner: Node in child.get_children():
				if inner is BodyScroll:
					found.append(inner)
	return found


## Puts each content control of `window` in a BodyScroll, in the same place in the tree, and returns the
## scrolls. A dialog's content controls are its direct children; a plain window's content sits under
## the backdrop window_body gives it, which stays the window's child (it fits the window and closes it
## on ESC), so it is the backdrop's children that are wrapped.
static func wrap_bodies(window: Window) -> Array:
	var host: Node = window
	for child: Node in window.get_children():
		if child is EventSheetPopupUI.WindowBackdrop:
			host = child
			break
	var wrapped: Array = []
	for child: Node in host.get_children():
		if not child is Control or child is ScrollContainer:
			continue
		var content: Control = child as Control
		var index: int = content.get_index()
		var scroll: BodyScroll = BodyScroll.new()
		host.remove_child(content)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
		host.add_child(scroll)
		host.move_child(scroll, index)
		wrapped.append(scroll)
	return wrapped


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


## What a popup panel's own background adds around its content, which its content minimum leaves out.
static func _panel_extra(window: Window) -> Vector2:
	if window is PopupPanel and window.has_theme_stylebox("panel", "PopupPanel"):
		return window.get_theme_stylebox("panel", "PopupPanel").get_minimum_size()
	return Vector2.ZERO


static func _margin(decorated: bool) -> int:
	return int(EventSheetPalette.scaled_f(float(EDGE_MARGIN))) if decorated else 0


## The window `window` opens over: its parent's window.
static func _host_of(window: Window) -> Window:
	if window == null or not window.is_inside_tree():
		return null
	var parent: Node = window.get_parent()
	return parent.get_window() if parent != null else window.get_window()


## A dialog's scrolling body: a ScrollContainer that reports the content's own least size as its
## least size, clamped to the room it was given, so the window can neither be forced bigger than its
## room by the content nor cut the content off - what does not fit scrolls.
class BodyScroll extends ScrollContainer:

	var _refit_pending: bool = false


	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


	## Sets the least size to the content's, no more than `room` (never under BODY_LEAST). When the
	## height has to scroll the width keeps a scroll bar's room, so the bar does not add a horizontal one.
	func fit_to(room: Vector2) -> void:
		var content: Control = get_child(0) as Control if get_child_count() > 0 else null
		if content == null:
			return
		if not content.minimum_size_changed.is_connected(_content_changed):
			content.minimum_size_changed.connect(_content_changed)
		var want: Vector2 = content.get_combined_minimum_size()
		var floor_size: float = EventSheetPalette.scaled_f(BODY_LEAST)
		var limit: Vector2 = Vector2(maxf(room.x, floor_size), maxf(room.y, floor_size))
		if want.y > limit.y:
			want.x += get_v_scroll_bar().get_combined_minimum_size().x
		custom_minimum_size = Vector2(minf(want.x, limit.x), minf(want.y, limit.y))


	## The content grew or shrank after the window opened (its labels wrapped, a list filled in): the
	## window is measured against its room again once, however many times that is said in a frame.
	func _content_changed() -> void:
		if _refit_pending:
			return
		_refit_pending = true
		_refit.call_deferred()


	func _refit() -> void:
		_refit_pending = false
		if is_inside_tree():
			EventSheetWindowPlacement.fit_to_content(get_window())
