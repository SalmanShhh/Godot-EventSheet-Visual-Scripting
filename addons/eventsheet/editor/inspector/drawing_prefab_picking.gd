# Godot EventSheets - picking a Drawing Prefab's shapes from its picture (editor-only).
#
# Joins the two halves of one prefab's Inspector: the picture at the top and the list of shape cards under it. A
# click on a shape in the picture selects that shape's card (and scrolls it into view); a selection in the list
# makes the picture draw those shapes at full strength and every other shape quietened. Nothing is written: a
# selection is a view, as it is in the list.
#
# It lives in its own file, loaded by path, and carries no `class_name`, for the reason the Inspector plugin gives:
# nothing heavy is named at editor start.
@tool
extends RefCounted

const PREVIEW_PATH: String = "res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd"
const PANEL_PATH: String = "res://addons/eventsheet/editor/inspector/preview_panel.gd"
## How far, in picture pixels, a click may miss a shape and still take it.
const CLICK_SLOP: float = 2.5

var _object: Object = null
var _panel: Control = null
var _cards: Control = null
## The steps (by position in the prefab's list) drawn at full strength; empty when nothing is selected.
var _chosen: Array = []


func _init(object: Object) -> void:
	_object = object


## The picture's renderer: the prefab's steps at the card's size, with every step but the chosen ones quietened.
func render(object: Object, size: Vector2i) -> Texture2D:
	return load(PREVIEW_PATH).call("rasterize_texture", _steps_of(object), size, load(PANEL_PATH).BACKGROUND, _chosen)


## The same picture as `render`, as a job for a worker thread: a Callable that makes the Image from its own copy of
## the steps and the chosen ones, so what is drawn is exactly what `render` would draw now, however the prefab changes
## meanwhile. A prefab holding a stamp (whose texture is loaded while it is drawn) is drawn on the main thread
## instead, so an invalid Callable comes back for it.
func render_job(object: Object, size: Vector2i) -> Callable:
	var steps: Array = _steps_of(object).duplicate(true)
	for step: Variant in steps:
		if step is Dictionary and str((step as Dictionary).get("kind", "")) == "stamp":
			return Callable()
	return Callable(load(PREVIEW_PATH), "rasterize").bind(steps, size, load(PANEL_PATH).BACKGROUND, _chosen.duplicate())


func attach_panel(panel: Control) -> void:
	_panel = panel
	panel.connect("picture_pressed", _on_picture_pressed)


func attach_cards(cards: Control) -> void:
	_cards = cards
	cards.connect("selection_changed", _on_selection_changed)
	_on_selection_changed(cards.call("selected_cards"))


func chosen_steps() -> Array:
	return _chosen.duplicate()


func _steps_of(object: Object) -> Array:
	var steps: Variant = object.get("steps") if is_instance_valid(object) else []
	return steps if steps is Array else []


## The positions in the prefab's list of the entries that are cards (a list may hold entries that are not shapes, which
## have no card), so card number N is step `positions[N]`.
func _positions(steps: Array) -> Array:
	var positions: Array = []
	for position: int in range(steps.size()):
		if steps[position] is Dictionary:
			positions.append(position)
	return positions


func _on_selection_changed(cards: Array) -> void:
	var positions: Array = _positions(_steps_of(_object))
	_chosen = []
	for card: Variant in cards:
		if int(card) >= 0 and int(card) < positions.size():
			_chosen.append(positions[int(card)])
	if is_instance_valid(_panel):
		_panel.call("request_refresh")


func _on_picture_pressed(point: Vector2, shift: bool, command: bool) -> void:
	if not is_instance_valid(_cards):
		return
	var steps: Array = _steps_of(_object)
	var size: Vector2i = load(PANEL_PATH).RASTER_SIZE
	var found: int = -1
	if point.x >= 0.0 and point.y >= 0.0 and point.x < float(size.x) and point.y < float(size.y):
		var preview: GDScript = load(PREVIEW_PATH)
		var local: Vector2 = preview.call("local_from_pixel", steps, size, point)
		found = int(preview.call("hit_step", steps, local, CLICK_SLOP / float(preview.call("view_scale", steps, size))))
	if found < 0:
		# Empty space brings the whole picture back; with Shift or Ctrl held it leaves the selection alone.
		if not shift and not command:
			_cards.call("clear_selection")
		return
	var card: int = _positions(steps).find(found)
	if card < 0:
		return
	_cards.call("select_card", card, "shift" if shift else ("ctrl" if command else "click"))
	_cards.call_deferred("reveal_card", card)
