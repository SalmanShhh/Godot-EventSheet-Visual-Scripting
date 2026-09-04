# Godot EventSheets - the Inspector preview card, for any object that asks for one (editor-only).
#
# A picture of the thing you are editing, at the top of its Inspector, re-drawn as you edit it. The
# drawing prefab has had one since it shipped; this is that card made general, so a node or a
# resource opts in with one decor line in its script:
#
#   # @inspector_preview
#
# Where the picture comes from, in order: a renderer the caller passed in (the prefab hands over its
# own tree-free rasterizer, so its card behaves exactly as it always has), then a renderer a pack
# registered for the script through the public API, then an `inspector_preview_texture(size)` method
# on the object itself, and finally - for a node with none of those - the node rendered live into a
# small viewport of its own. A resource with no renderer anywhere shows the honest empty card.
#
# Under the picture sit the viewport handles the script declares, as chips, so an author reads what
# will be draggable before opening a scene. The card is chrome: it emits nothing, and an exported
# game neither ships it nor knows it existed.
@tool
class_name EventSheetInspectorPreviewPanel
extends PanelContainer

const API_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"

## The card's own height, and the raster it asks a renderer for. Both are the drawing prefab card's
## shipped numbers: its picture is 384x200 shown at a typical Inspector column width, which is why
## the card is compact instead of a tall box with empty bands above and below it.
const CARD_HEIGHT: int = 158
const RASTER_SIZE: Vector2i = Vector2i(384, 200)
const BACKGROUND: Color = Color(0.11, 0.12, 0.15, 1.0)
## How often the card looks for an edit nothing announced. A plain `@export` write fires no signal
## at all, so a card that only listened to `changed` drew once and then quietly went stale.
const POLL_SECONDS: float = 0.25

var _object: Object = null
var _renderer: Callable = Callable()
var _rect: TextureRect = null
var _poll_accumulator: float = 0.0
var _last_state: int = 0


## The card for one object. `renderer` is optional and takes priority over everything else:
## `renderer(object, size) -> Texture2D`. Both arguments default so the class stays constructible
## with a bare new() - a Control with a class_name is offered by the editor's own node dialog.
func _init(object: Object = null, renderer: Callable = Callable()) -> void:
	_object = object
	_renderer = renderer
	custom_minimum_size = Vector2(0, CARD_HEIGHT)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	if source_of(_object, _renderer) == "viewport":
		column.add_child(_build_live_viewport(_object as Node))
	else:
		_rect = TextureRect.new()
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(_rect)
	var chips: PackedStringArray = EventSheetInspectorObjectDecor.chips(EventSheetInspectorObjectDecor.handles_for(_object))
	if not chips.is_empty():
		column.add_child(_build_chips(chips))
	if _object is Resource and not (_object as Resource).changed.is_connected(refresh):
		(_object as Resource).changed.connect(refresh)


func _ready() -> void:
	refresh()


## The card watches the object it draws. A resource announces its own edits through `changed`, but a
## plain `@export` write announces nothing and a node announces nothing at all, so the card reads the
## object's stored values a few times a second and re-draws when they differ from the ones it drew.
## Editor-only, and only for an object that asked for a card: nothing here ships in a game.
func _process(delta: float) -> void:
	if _rect == null:
		return
	_poll_accumulator += delta
	if _poll_accumulator < POLL_SECONDS:
		return
	_poll_accumulator = 0.0
	var state: int = state_hash(_object)
	if state == _last_state:
		return
	_last_state = state
	refresh()


## A number that changes when any stored value of the object changes - the seam the poll compares.
## Sub-objects are skipped rather than walked: a resource inside a resource announces its own edits
## through `changed`, and walking one could recurse forever.
static func state_hash(object: Object) -> int:
	if not is_instance_valid(object):
		return 0
	var values: Array = []
	for entry: Dictionary in object.get_property_list():
		if int(entry.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var value: Variant = object.get(str(entry.get("name", "")))
		if value is Object:
			continue
		values.append(value)
	return hash(values)


func _exit_tree() -> void:
	if _object is Resource and (_object as Resource).changed.is_connected(refresh):
		(_object as Resource).changed.disconnect(refresh)


## Re-renders the picture. Called on the resource's `changed` signal, and by hand after an edit a
## signal does not announce.
func refresh() -> void:
	if _rect == null or not is_instance_valid(_object):
		return
	_rect.texture = render_texture(_object, RASTER_SIZE, _renderer)
	_last_state = state_hash(_object)


## The picture currently on the card, or null while it has none - the suite's seam onto a card it
## built without an editor around it.
func preview_texture() -> Texture2D:
	return _rect.texture if _rect != null else null


## WHERE this card's picture comes from, as one word: "given" (a renderer the caller passed),
## "registered" (a pack registered one for the script), "object" (the object renders itself),
## "viewport" (a node rendered live) or "none". Static + UI-free, so the order of preference is
## pinned by the suite rather than read off a screenshot.
static func source_of(object: Object, renderer: Callable = Callable()) -> String:
	if renderer.is_valid():
		return "given"
	if object == null:
		return "none"
	if registered_renderer_for(object).is_valid():
		return "registered"
	if object.has_method("inspector_preview_texture"):
		return "object"
	if object is Node:
		return "viewport"
	return "none"


## The renderer a pack registered for this object's script, or an invalid Callable.
static func registered_renderer_for(object: Object) -> Callable:
	if object == null:
		return Callable()
	var script: Script = object.get_script() as Script
	if script == null or script.resource_path.is_empty():
		return Callable()
	return load(API_PATH).inspector_preview_renderer_for(script.resource_path)


## The picture itself, through whichever source answers first. Null when nothing renders it.
static func render_texture(object: Object, size: Vector2i, renderer: Callable = Callable()) -> Texture2D:
	match source_of(object, renderer):
		"given":
			return renderer.call(object, size) as Texture2D
		"registered":
			return registered_renderer_for(object).call(object, size) as Texture2D
		"object":
			return object.call("inspector_preview_texture", size) as Texture2D
	return null


## The declared handles as a row of chips - the same reading the Inspector Designer shows.
func _build_chips(chips: PackedStringArray) -> Control:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	for chip: String in chips:
		var label: Label = Label.new()
		label.text = chip
		label.tooltip_text = "Drag this in the viewport"
		label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		label.modulate = Color(0.72, 0.76, 0.84)
		row.add_child(label)
	return row


## A node with no renderer of its own draws itself: a copy of it, live, in a viewport the size of
## the card. The copy is a child of THIS panel and never of the edited scene, so the scene file is
## untouched and the copy dies with the Inspector row.
func _build_live_viewport(node: Node) -> Control:
	var container: SubViewportContainer = SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var viewport: SubViewport = SubViewport.new()
	viewport.size = RASTER_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var copy: Node = node.duplicate(DUPLICATE_SCRIPTS)
	if copy == null:
		return container
	# The copy is a PICTURE, not a second live node: nothing in it ticks, listens or fires, so a node
	# whose script spawns, times or plays something does none of it twice while its Inspector is open.
	# A `_ready` still runs once when the copy enters this viewport, which is the one thing a
	# duplicate cannot be spared - a script with side effects there should draw its own card with an
	# `inspector_preview_texture(size)` method instead, which this card prefers anyway.
	copy.process_mode = Node.PROCESS_MODE_DISABLED
	if copy is Node3D:
		viewport.own_world_3d = true
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
		viewport.add_child(light)
		var camera: Camera3D = Camera3D.new()
		camera.position = Vector3(0.0, 1.2, 3.0)
		camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.UP)
		viewport.add_child(camera)
		(copy as Node3D).position = Vector3.ZERO
		viewport.add_child(copy)
		return container
	if copy is Node2D:
		# The holder keeps the copy in the middle of the card however wide the Inspector column is,
		# which is what a stretched SubViewportContainer changes underneath it.
		var holder: Node2D = Node2D.new()
		viewport.add_child(holder)
		holder.position = Vector2(viewport.size) * 0.5
		viewport.size_changed.connect(func() -> void: holder.position = Vector2(viewport.size) * 0.5)
		(copy as Node2D).position = Vector2.ZERO
		holder.add_child(copy)
		return container
	viewport.add_child(copy)
	return container
