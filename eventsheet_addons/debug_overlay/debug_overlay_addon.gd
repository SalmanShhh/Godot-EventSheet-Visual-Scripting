## @ace_tags(debug, overlay, hud, profiling)
## @ace_category("Debug Overlay")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/debug_overlay/icon.svg")
class_name DebugOverlayAddon
extends CanvasLayer
## An on-screen debug display driven from event rows, drawn over the running game and only in debug builds. Watch Value lists named values, Show Bar draws a labelled meter, Mark Point drops a fading cross in the world, Draw Ray shows a direction, and Label Above floats text over a node. Nothing exists until a row calls one of them, and the toggle key hides the whole thing while you play.

## @ace_trigger
## @ace_name("On Overlay Toggled")
## @ace_category("Debug Overlay")
signal overlay_toggled(shown: bool)

## Key that shows and hides the overlay while the game runs, by name (F3, F1, Tab, Escape). Leave blank for no key.
@export_group("Debug Overlay")
@export var toggle_key: String = "F3"
## Start hidden: rows still record, nothing is drawn until you press the toggle key.
@export var start_hidden: bool = false

# The drawing surface is a plain Control child whose `draw` signal we paint from, so the
# whole overlay stays one dependency-free script with no second file to ship. It is null
# until a verb calls _ensure_surface(), which is what makes an unused overlay cost nothing.
var _surface: Control = null
var _shown: bool = true
# Watches and bars are keyed by name (with a parallel order list so the list does not
# reshuffle every frame). Marks, rays and labels are timed entries that age themselves out.
var _watches: Dictionary = {}
var _watch_order: PackedStringArray = PackedStringArray()
var _bars: Dictionary = {}
var _bar_order: PackedStringArray = PackedStringArray()
var _marks: Array = []
var _rays: Array = []
var _labels: Array = []

func _process(delta: float) -> void:
	_expire_overlay_entries()

func _ready() -> void:
	layer = 128
	_shown = not start_hidden

## @ace_action
## @ace_featured
## @ace_name("Watch Value")
## @ace_category("Debug Overlay")
## @ace_description("Shows name = value in the on-screen list, refreshed every time you set it. Call it from an Every Frame row and it reads like a live watch window over the running game. Debug builds only.")
## @ace_display_template("Watch [b]{watch_name}[/b] = [b]{value}[/b]")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.watch_value({watch_name}, {value})")
func watch_value(watch_name: String, value: Variant) -> void:
	if not _ensure_surface():
		return
	if not _watches.has(watch_name):
		_watch_order.append(watch_name)
	_watches[watch_name] = str(value)

## @ace_action
## @ace_name("Clear Watch")
## @ace_category("Debug Overlay")
## @ace_description("Drops one named value from the on-screen list, for when a watch has served its purpose and is just taking up a line.")
## @ace_display_template("Stop watching [b]{watch_name}[/b]")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.clear_watch({watch_name})")
func clear_watch(watch_name: String) -> void:
	_watches.erase(watch_name)
	var index: int = _watch_order.find(watch_name)
	if index >= 0:
		_watch_order.remove_at(index)

## @ace_action
## @ace_name("Show Bar")
## @ace_category("Debug Overlay")
## @ace_description("Draws a named meter filled to a fraction from 0 to 1, in the colour you pick. The fastest way to see stamina, a cooldown, or an AI's confidence without building any UI.")
## @ace_display_template("Bar [b]{bar_name}[/b] = [b]{fraction}[/b] in [b]{bar_color}[/b]")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.show_bar({bar_name}, {fraction}, {bar_color})")
func show_bar(bar_name: String, fraction: float, bar_color: Color) -> void:
	if not _ensure_surface():
		return
	if not _bars.has(bar_name):
		_bar_order.append(bar_name)
	_bars[bar_name] = [fraction, bar_color]

## @ace_action
## @ace_featured
## @ace_name("Mark Point")
## @ace_category("Debug Overlay")
## @ace_description("Drops a labelled cross at a world position for a moment, so you can SEE where something happened. The mark stays glued to the world while the camera moves, then fades out on its own.")
## @ace_display_template("Mark point [b]{at}[/b] label [b]{mark_label}[/b] for [b]{seconds}[/b]s")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.mark_point({at}, {mark_label}, {seconds})")
func mark_point(at: Vector2, mark_label: String, seconds: float) -> void:
	if not _ensure_surface():
		return
	_marks.append([at, mark_label, Color(1.0, 0.4, 0.4), Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)])

## @ace_action
## @ace_name("Draw Ray")
## @ace_category("Debug Overlay")
## @ace_description("Draws a line from a world position along a direction for a given length, which is what you want on screen while tuning a detection cone, an aim vector, or a raycast that keeps missing.")
## @ace_display_template("Draw ray from [b]{origin}[/b] toward [b]{direction}[/b] length [b]{length}[/b]")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.draw_ray({origin}, {direction}, {length}, {ray_color}, {seconds})")
func draw_ray(origin: Vector2, direction: Vector2, length: float, ray_color: Color, seconds: float) -> void:
	if not _ensure_surface():
		return
	_rays.append([origin, origin + direction.normalized() * length, ray_color, Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)])

## @ace_action
## @ace_name("Label Above")
## @ace_category("Debug Overlay")
## @ace_description("Floats a line of text above a node for a moment - the fastest way to debug a dozen enemies at once, because each one carries its own state on screen. Works for a Node2D, a Control, or a Node3D seen through the active camera.")
## @ace_display_template("Label above [i]{node}[/i] text [b]{label_text}[/b]")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.label_above({node}, {label_text}, {seconds})")
func label_above(node: Node, label_text: String, seconds: float) -> void:
	if not _ensure_surface():
		return
	_labels.append([node, label_text, Time.get_ticks_msec() + int(maxf(seconds, 0.05) * 1000.0)])

## @ace_action
## @ace_name("Show Overlay")
## @ace_category("Debug Overlay")
## @ace_description("Makes the overlay visible again after it was hidden. Fires On Overlay Toggled when it was actually hidden.")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.show_overlay()")
func show_overlay() -> void:
	_set_overlay_shown(true)

## @ace_action
## @ace_name("Hide Overlay")
## @ace_category("Debug Overlay")
## @ace_description("Hides the overlay without clearing anything. Rows keep recording, so showing it again brings the values straight back.")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.hide_overlay()")
func hide_overlay() -> void:
	_set_overlay_shown(false)

## @ace_action
## @ace_name("Toggle Overlay")
## @ace_category("Debug Overlay")
## @ace_description("Flips the overlay between shown and hidden, the same thing the toggle key does - put it on a button so a playtester can turn it on for a screenshot.")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.toggle_overlay()")
func toggle_overlay() -> void:
	_set_overlay_shown(not _shown)

## @ace_action
## @ace_name("Clear Overlay")
## @ace_category("Debug Overlay")
## @ace_description("Wipes every watch, bar, mark, ray and label at once. Useful between levels, or at the head of a run so last run's evidence does not confuse this one.")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.clear_overlay()")
func clear_overlay() -> void:
	_watches.clear()
	_watch_order = PackedStringArray()
	_bars.clear()
	_bar_order = PackedStringArray()
	_marks.clear()
	_rays.clear()
	_labels.clear()

## @ace_condition
## @ace_name("Overlay Is Visible")
## @ace_category("Debug Overlay")
## @ace_description("True while the overlay is on screen. False in a release build, before any row has drawn to it, and while the toggle key has it hidden.")
## @ace_icon("res://eventsheet_addons/debug_overlay/icon.svg")
## @ace_codegen_template("DebugOverlay.is_overlay_visible()")
func is_overlay_visible() -> bool:
	return _shown and _surface != null

## @ace_hidden
func _ensure_surface() -> bool:
	# Builds the surface on FIRST use, and only in a debug build. Every verb starts with this,
	# so an exported release build never creates a node and never draws a pixel.
	if not OS.is_debug_build():
		return false
	if _surface != null:
		return true
	_surface = Control.new()
	_surface.name = "DebugOverlaySurface"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.draw.connect(_paint_overlay)
	_surface.visible = _shown
	return true

## @ace_hidden
func _expire_overlay_entries() -> void:
	# Ages every timed entry out and repaints. Called once a frame by the pack's own tick row.
	if _surface == null:
		return
	var now: int = Time.get_ticks_msec()
	for index: int in range(_marks.size() - 1, -1, -1):
		if now >= int((_marks[index] as Array)[3]):
			_marks.remove_at(index)
	for index: int in range(_rays.size() - 1, -1, -1):
		if now >= int((_rays[index] as Array)[3]):
			_rays.remove_at(index)
	for index: int in range(_labels.size() - 1, -1, -1):
		var entry: Array = _labels[index] as Array
		if now >= int(entry[2]) or not is_instance_valid(entry[0]):
			_labels.remove_at(index)
	_surface.queue_redraw()

## @ace_hidden
func _paint_overlay() -> void:
	# The painter. Watches and bars stack down the top-left corner; marks, rays and labels are
	# world positions pushed through the canvas transform so they sit where the thing is.
	if _surface == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var row_y: float = 20.0
	for watch_name: String in _watch_order:
		_surface.draw_string(font, Vector2(12.0, row_y), "%s = %s" % [watch_name, str(_watches.get(watch_name, ""))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 1.0, 1.0))
		row_y += 18.0
	for bar_name: String in _bar_order:
		var bar: Array = _bars.get(bar_name, [0.0, Color.WHITE]) as Array
		var fraction: float = clampf(float(bar[0]), 0.0, 1.0)
		_surface.draw_string(font, Vector2(12.0, row_y), bar_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 1.0, 1.0))
		_surface.draw_rect(Rect2(Vector2(140.0, row_y - 11.0), Vector2(160.0, 12.0)), Color(0.0, 0.0, 0.0, 0.45))
		_surface.draw_rect(Rect2(Vector2(140.0, row_y - 11.0), Vector2(160.0 * fraction, 12.0)), bar[1] as Color)
		row_y += 18.0
	for mark: Array in _marks:
		var at: Vector2 = _world_to_screen(mark[0] as Vector2)
		var mark_color: Color = mark[2] as Color
		_surface.draw_line(at + Vector2(-6.0, -6.0), at + Vector2(6.0, 6.0), mark_color, 2.0)
		_surface.draw_line(at + Vector2(-6.0, 6.0), at + Vector2(6.0, -6.0), mark_color, 2.0)
		_surface.draw_string(font, at + Vector2(10.0, -8.0), str(mark[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, mark_color)
	for ray: Array in _rays:
		_surface.draw_line(_world_to_screen(ray[0] as Vector2), _world_to_screen(ray[1] as Vector2), ray[2] as Color, 2.0)
	for label_entry: Array in _labels:
		if not is_instance_valid(label_entry[0]):
			continue
		_surface.draw_string(font, _node_screen_position(label_entry[0] as Node) + Vector2(-16.0, -18.0), str(label_entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1.0, 0.9, 0.55))

## @ace_hidden
func _world_to_screen(world_position: Vector2) -> Vector2:
	# World space to screen space. The 2D canvas transform already accounts for the camera, so
	# a marked point stays glued to the world while the camera moves.
	var view: Viewport = get_viewport()
	if view == null:
		return world_position
	return view.get_canvas_transform() * world_position

## @ace_hidden
func _node_screen_position(node: Node) -> Vector2:
	# Where a node appears on screen, in 2D or in 3D (a Node3D goes through the active camera's
	# projection). An off-tree or unprojectable node reads as the top-left corner.
	if node is Node2D:
		return _world_to_screen((node as Node2D).global_position)
	if node is Control:
		return (node as Control).global_position
	if node is Node3D:
		var view: Viewport = get_viewport()
		var camera: Camera3D = view.get_camera_3d() if view != null else null
		if camera != null:
			return camera.unproject_position((node as Node3D).global_position)
	return Vector2.ZERO

## @ace_hidden
func _set_overlay_shown(shown: bool) -> void:
	# Shows or hides the overlay and announces it. The signal only fires on a real change, so a
	# row under On Overlay Toggled never sees a repeat of the state it is already in.
	if _shown == shown:
		return
	_shown = shown
	if _surface != null:
		_surface.visible = _shown
	overlay_toggled.emit(_shown)

func _unhandled_input(event: InputEvent) -> void:
	# The toggle key, read by name (F3, F1, Tab...) so the Inspector field stays readable. Only
	# in a debug build, and only when a key name is set.
	if not OS.is_debug_build() or toggle_key.strip_edges().is_empty():
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == OS.find_keycode_from_string(toggle_key.strip_edges()):
		_set_overlay_shown(not _shown)

# Debug Overlay (autoload): register as the DebugOverlay autoload, then call its verbs from any sheet - Watch Value, Show Bar, Mark Point, Draw Ray, Label Above. The drawing surface is created on the FIRST call and only in a debug build, so a project that never calls it pays nothing and an exported release draws nothing. Press the toggle key (F3 by default) to hide it while you play. This pack is an event sheet - extend it by editing it.
