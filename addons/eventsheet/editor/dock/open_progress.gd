@tool
class_name EventSheetOpenProgress
extends RefCounted
# How an asynchronous .gd open says it is working, with nothing drawn over or above the sheet.
#
# Opening a .gd paints the RAW sheet at once (rows and verbatim code blocks), then runs the ACE lift
# on a worker thread (EventSheetOpenJob) that the dock polls once a frame. While that runs the open
# says so in three quiet places, none of which takes room from the sheet, so nothing pushes the rows
# down when it starts and nothing jumps back when it ends:
#   - the file's TAB swaps its icon for a small spinner drawn in the look's accent,
#   - a 2 px HAIRLINE along the foot of the tab strip fills by the job's progress ratio,
#   - the STATUS LINE reads "Opening <file> · <pass>" and offers "Show as code".
# "Show as code" (and Code in the Events / Code / Both switch, which the dock routes here) cancels
# the lift and keeps the raw sheet, exactly as the old banner's button did.
#
# Every colour comes from the editor theme the look rides on (accent, text, quieter text), so dark
# and light need nothing of their own. With reduced motion the spinner holds still and the hairline
# jumps to each new ratio instead of sliding.
#
# WIDGETS LIVE HERE, not on the dock: the hairline and the link are built by this helper and handed
# to the dock builder to place; nothing outside reads them. The dock owns the poll timer wiring only.

const SPIN_FRAME_COUNT: int = 8
const SPIN_FRAME_MSEC: int = 90
const HAIRLINE_HEIGHT: int = 2

var _dock: Control = null
var _hairline: Hairline = null
var _link: LinkButton = null
var _active: bool = false
var _path: String = ""
var _last_status: String = ""
var _asked: bool = false
var _spin_frames: Array[Texture2D] = []
var _spin_key: String = ""
## Set by the dock when the user asks for the raw code; this helper only reports the request, the
## job owns the actual cancel.
var cancel_requested_callback: Callable = Callable()


## The 2 px line along the foot of the tab strip. It is a child of the tab bar, anchored to its
## bottom edge, so it takes no layout room anywhere.
class Hairline extends Control:

	var ratio: float = 0.0
	var shown: float = 0.0
	var accent: Color = Color.WHITE


	func _init() -> void:
		name = "EventSheetOpenHairline"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor_left = 0.0
		anchor_right = 1.0
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_top = -float(EventSheetOpenProgress.HAIRLINE_HEIGHT)
		offset_bottom = 0.0
		visible = false
		z_index = 2


	func _draw() -> void:
		var track: Color = accent
		track.a = 0.22
		draw_rect(Rect2(Vector2.ZERO, size), track)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(shown, 0.0, 1.0), size.y)), accent)


func init(dock: Control) -> void:
	_dock = dock


## Builds the hairline (hidden) for the dock builder to add under the tab strip.
func build_hairline() -> Control:
	_hairline = Hairline.new()
	return _hairline


## Builds the "Show as code" link (hidden) for the dock builder to place in the status strip.
func build_link() -> Control:
	_link = LinkButton.new()
	_link.name = "EventSheetOpenShowAsCode"
	_link.text = EventSheetL10n.translate("Show as code")
	_link.tooltip_text = EventSheetL10n.translate("Stop working out which events this code maps to and just show the file as script blocks. Nothing is changed on disk either way.")
	_link.underline = LinkButton.UNDERLINE_MODE_NEVER
	_link.visible = false
	_link.pressed.connect(request_code)
	return _link


func is_active() -> bool:
	return _active


## Whether `path` is the file being opened right now (the tab bar asks, to keep the spinner).
func is_opening(path: String) -> bool:
	return _active and path == _path


## The user asked for the raw code: report it once, and show the link as taken.
func request_code() -> void:
	if not _active or _asked:
		return
	_asked = true
	if is_instance_valid(_link):
		_link.disabled = true
		_link.text = EventSheetL10n.translate("Showing as code…")
	if cancel_requested_callback.is_valid():
		cancel_requested_callback.call()


## Starts the open's signs for `path`, reset to their starting state.
func show_for(path: String) -> void:
	_active = true
	_asked = false
	_path = path
	_last_status = ""
	if is_instance_valid(_link):
		_link.disabled = false
		_link.text = EventSheetL10n.translate("Show as code")
		_apply_link_colors()
		_link.visible = true
	if is_instance_valid(_hairline):
		_hairline.ratio = 0.0
		_hairline.shown = 0.0
		_hairline.accent = EventSheetPopupUI.accent_color()
		_hairline.visible = true
		_hairline.queue_redraw()
	_ring_code_door(true)
	update(EventSheetL10n.translate("reading the file"), 0.0)


## One poll tick: advances the spinner and the hairline and republishes the pass in the status line.
func update(detail: String, ratio: float) -> void:
	if not _active:
		return
	if is_instance_valid(_hairline):
		_hairline.ratio = maxf(_hairline.ratio, clampf(ratio, 0.0, 1.0))
		if EventSheetAccessibility.reduced_motion():
			_hairline.shown = _hairline.ratio
		else:
			_hairline.shown = lerpf(_hairline.shown, _hairline.ratio, 0.35)
			if absf(_hairline.ratio - _hairline.shown) < 0.002:
				_hairline.shown = _hairline.ratio
		_hairline.queue_redraw()
	_set_spinner_icon()
	var line: String = EventSheetL10n.translate("Opening %s · %s") % [_path.get_file(), detail]
	if line != _last_status and _dock != null and _dock.has_method("_set_status"):
		_last_status = line
		_dock._set_status(line)
		# A message that fades to muted after a few seconds would dim a long pass; this one is live.
		if "_status_fade_tween" in _dock and _dock._status_fade_tween != null:
			_dock._status_fade_tween.kill()
			_dock._status_fade_tween = null
		if "_status_label" in _dock and _dock._status_label != null:
			_dock._status_label.modulate.a = 1.0


## Takes every sign down: the hairline, the link, the ring on Code, and the tab's own icon back.
func hide_strip() -> void:
	if not _active:
		return
	_active = false
	_path = ""
	_last_status = ""
	if is_instance_valid(_hairline):
		_hairline.visible = false
	if is_instance_valid(_link):
		_link.visible = false
	_ring_code_door(false)
	if _dock != null and _dock.has_method("_refresh_tab_bar"):
		_dock._refresh_tab_bar()


## The spinner frame the tab wears now: still (frame 0) under reduced motion.
func spinner_texture() -> Texture2D:
	var accent: Color = EventSheetPopupUI.accent_color()
	var side: int = EventSheetPalette.scaled(14)
	var key: String = "%s|%d" % [accent.to_html(), side]
	if key != _spin_key or _spin_frames.is_empty():
		_spin_key = key
		_spin_frames = _build_spin_frames(accent, side)
	if EventSheetAccessibility.reduced_motion():
		return _spin_frames[0]
	return _spin_frames[(Time.get_ticks_msec() / SPIN_FRAME_MSEC) % SPIN_FRAME_COUNT]


func _set_spinner_icon() -> void:
	if _dock == null or not ("_tab_bar" in _dock) or _dock._tab_bar == null:
		return
	var bar: TabBar = _dock._tab_bar
	for index: int in _dock._open_tabs.size():
		if str(_dock._open_tabs[index].get("path", "")) == _path and index < bar.get_tab_count():
			bar.set_tab_icon(index, spinner_texture())


## A ring with a quarter missing, turned by one step per frame, in the accent.
static func _build_spin_frames(accent: Color, side: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var center: float = float(side) * 0.5
	var outer: float = center - 0.5
	var inner: float = outer - maxf(1.6, float(side) * 0.17)
	var sweep: float = TAU * 0.72
	for step: int in SPIN_FRAME_COUNT:
		var start: float = TAU * float(step) / float(SPIN_FRAME_COUNT)
		var image: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
		for y: int in side:
			for x: int in side:
				var offset: Vector2 = Vector2(float(x) + 0.5 - center, float(y) + 0.5 - center)
				var radius: float = offset.length()
				var edge: float = clampf(minf(outer - radius, radius - inner) + 0.5, 0.0, 1.0)
				if edge <= 0.0:
					continue
				var turn: float = fposmod(offset.angle() - start, TAU)
				if turn > sweep:
					continue
				# The tail fades so the turn reads as motion rather than as a broken ring.
				var fade: float = 0.25 + 0.75 * (turn / sweep)
				image.set_pixel(x, y, Color(accent.r, accent.g, accent.b, accent.a * edge * fade))
		frames.append(ImageTexture.create_from_image(image))
	return frames


func _apply_link_colors() -> void:
	if not is_instance_valid(_link):
		return
	var accent: Color = EventSheetPopupUI.accent_color()
	_link.add_theme_color_override("font_color", accent)
	_link.add_theme_color_override("font_hover_color", accent.lightened(0.2))
	_link.add_theme_color_override("font_pressed_color", accent)
	_link.add_theme_color_override("font_disabled_color", EventSheetPopupUI.muted_text_color())


## Rings the Code button of the Events / Code / Both switch in the accent while the open runs: it is
## the other door to "show as code".
func _ring_code_door(on: bool) -> void:
	if _dock == null or not ("_code_panel_glue" in _dock) or _dock._code_panel_glue == null:
		return
	var door: Variant = _dock._code_panel_glue.get("_view_switch")
	if door == null or not is_instance_valid(door):
		return
	var button: Button = (door as EventSheetPopupUI.ViewSwitch).buttons.get(EventSheetPopupUI.ViewSwitch.CODE)
	if button == null:
		return
	if not on:
		button.remove_theme_stylebox_override("normal")
		return
	var base: StyleBox = button.get_theme_stylebox("normal")
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(1)
	ring.border_color = EventSheetPopupUI.accent_color()
	ring.set_corner_radius_all(3)
	if base != null:
		ring.content_margin_left = base.get_margin(SIDE_LEFT)
		ring.content_margin_right = base.get_margin(SIDE_RIGHT)
		ring.content_margin_top = base.get_margin(SIDE_TOP)
		ring.content_margin_bottom = base.get_margin(SIDE_BOTTOM)
	button.add_theme_stylebox_override("normal", ring)
