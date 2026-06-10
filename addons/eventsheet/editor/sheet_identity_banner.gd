# EventSheet — Sheet identity banner
# A slim band above the sheet announcing what kind of sheet is being edited:
#   ⚙ PatrolBehavior — Behavior · acts on host: CharacterBody2D
#   ◆ PatrollingGuard — Custom Node · extends CharacterBody2D
# Hidden for plain event sheets. Dual-audience cue (Godot: "custom node with an icon";
# C3: "behavior attached to an object"); clicking it opens the Sheet Type dialog.
@tool
class_name SheetIdentityBanner
extends Control

signal edit_requested

const BANNER_HEIGHT := 24.0
const ICON_SIZE := 14.0

var _viewport: EventSheetViewport = null
var _label: String = ""
var _is_behavior: bool = false
var _icon: Texture2D = null

func setup(viewport: EventSheetViewport) -> void:
	_viewport = viewport
	name = "SheetIdentityBanner"
	custom_minimum_size = Vector2(0.0, BANNER_HEIGHT)
	tooltip_text = "Click to edit the sheet type (name, icon, host class)."
	visible = false

## Refreshes the banner from the sheet; hides itself for plain event sheets.
func update_from_sheet(sheet: EventSheetResource) -> void:
	_icon = null
	if sheet == null or (not sheet.behavior_mode and sheet.custom_class_name.strip_edges().is_empty()):
		visible = false
		queue_redraw()
		return
	_is_behavior = sheet.behavior_mode
	var display_name: String = sheet.custom_class_name.strip_edges()
	if display_name.is_empty():
		display_name = "Behavior"
	if _is_behavior:
		_label = "%s — Behavior · acts on host: %s" % [display_name, sheet.host_class]
	else:
		_label = "%s — Custom Node · extends %s" % [display_name, sheet.host_class]
	var icon_path: String = sheet.custom_class_icon.strip_edges()
	if icon_path.begins_with("res://") and ResourceLoader.exists(icon_path):
		var loaded: Resource = load(icon_path)
		if loaded is Texture2D:
			_icon = loaded
	visible = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		edit_requested.emit()
		accept_event()

func _draw() -> void:
	if _viewport == null:
		return
	var style: EventSheetEventStyle = _viewport.get_event_style()
	var accent: Color = style.behavior_accent_color if _is_behavior else style.column_header_conditions_color
	var background: Color = style.column_header_background_color
	draw_rect(Rect2(Vector2.ZERO, size), background, true)
	draw_rect(Rect2(0.0, 0.0, 3.0, size.y), accent, true)
	var x: float = 10.0
	if _icon != null:
		var icon_y: float = (size.y - ICON_SIZE) * 0.5
		draw_texture_rect(_icon, Rect2(x, icon_y, ICON_SIZE, ICON_SIZE), false)
		x += ICON_SIZE + 6.0
	else:
		# Fallback glyphs keep the types visually distinct without custom art.
		var glyph: String = "⚙" if _is_behavior else "◆"
		draw_string(ThemeDB.fallback_font, Vector2(x, size.y * 0.5 + 5.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, accent)
		x += 18.0
	draw_string(ThemeDB.fallback_font, Vector2(x, size.y * 0.5 + 5.0), _label, HORIZONTAL_ALIGNMENT_LEFT, max(size.x - x - 8.0, 10.0), 13, accent)
