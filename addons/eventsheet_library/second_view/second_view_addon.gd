## @ace_tags(camera, viewport, minimap, ui)
## @ace_category("Second View")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/second_view/icon.svg")
class_name SecondViewPackAddon
extends Node
## A second picture of the world you are already in, as the SecondView autoload singleton: name a view, give it a node to follow, and show it in a frame. Each view is a SubViewport sharing the running world with a camera of its own, so a minimap, a security monitor, a character portrait and a rear-view mirror are the same rows with different frames. Drawing surfaces belong to the Canvas Surface pack; this one owns world views.

# The square a view renders at until a frame it is shown in gives it a size of its own.
const STARTING_VIEW_PIXELS: int = 256

# How far above a followed Node3D the view's camera sits at zoom 1, in metres. Zoom divides it,
# so a bigger zoom is a closer look at less ground - the same direction zoom means for a Camera2D.
const OVERHEAD_METRES: float = 20.0

# view name -> what that view is made of: the SubViewport it renders into, the camera inside it,
# the instance id of the node it follows, its zoom, whether it has parked, and the frames it has
# been handed to (frame instance id -> the resize callable connected to that frame, so Stop View
# can take it off again).
var _views: Dictionary = {}

## The live handle on a view's picture. It is taken only once the viewport is really in the tree,
## and it is marked NOT local to scene before it is handed out: a ViewportTexture that is local to
## scene re-resolves its viewport by node path whenever the scene holding it is set up, and this
## viewport is a child of this autoload rather than of any scene. Off, the handle stays bound to
## the viewport it came from, wherever the frame showing it happens to live.
func _texture_of(record: Dictionary) -> Texture2D:
	var view: SubViewport = record["viewport"]
	if not is_instance_valid(view) or not is_inside_tree():
		return null
	var handle: ViewportTexture = view.get_texture()
	if handle != null:
		handle.resource_local_to_scene = false
	return handle

## @ace_action
## @ace_featured
## @ace_name("Make A View")
## @ace_category("Second View")
## @ace_description("Builds a second view of the world you are already in, under a name every other row addresses it by. The view is a SubViewport sharing the running world with a camera of its own that follows the node you name - a Camera2D when that node is 2D, a Camera3D looking straight down at it when it is 3D. Zoom is how much of the world is in frame: below 1 shows more of it (a minimap), above 1 shows less of it (a magnifier). Making a view under a name that already exists replaces it, so a row that runs twice leaves one view rather than two cameras drawing the same picture.")
## @ace_display_template("Make a view named [b]{view_name}[/b] following [i]{followed}[/i] at zoom [b]{zoom}[/b]")
## @ace_param_hint(followed scene_node)
## @ace_icon("res://eventsheet_addons/second_view/icon.svg")
## @ace_codegen_template("SecondView.make_a_view({view_name}, {followed}, {zoom})")
func make_a_view(view_name: String, followed: Node, zoom: float) -> void:
	if view_name.is_empty():
		push_warning("Second View: Make A View needs a name to call the view by.")
		return
	if followed == null or not is_instance_valid(followed):
		push_warning("Second View: Make A View needs a node for the view to follow.")
		return
	if not (followed is Node2D or followed is Node3D):
		push_warning("Second View: a view follows a Node2D or a Node3D, and %s is neither - there would be nowhere to put the camera." % followed.name)
		return
	if not is_inside_tree():
		return
	stop_view(view_name)
	var view: SubViewport = SubViewport.new()
	view.name = "View_" + view_name
	view.size = Vector2i(STARTING_VIEW_PIXELS, STARTING_VIEW_PIXELS)
	view.transparent_bg = true
	# A SubViewport outside a SubViewportContainer is never "visible", and the default update
	# mode only draws what is visible - which is why a second view built by hand so often ends up
	# a blank texture. Always is the honest answer for a viewport something is looking at.
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera: Node = null
	if followed is Node3D:
		# Sharing the world is the whole trick: the view draws the world the game is already
		# running rather than a second empty one, which is why own_world_3d stays off.
		view.world_3d = get_viewport().find_world_3d()
		var eye: Camera3D = Camera3D.new()
		eye.current = true
		camera = eye
	else:
		# The 2D world is shared the same way. A CanvasLayer belongs to the viewport it is in
		# rather than to the world, so the HUD is not drawn into the view - which is what you want.
		view.world_2d = get_viewport().find_world_2d()
		var lens: Camera2D = Camera2D.new()
		lens.enabled = true
		camera = lens
	view.add_child(camera)
	add_child(view)
	var record: Dictionary = {"viewport": view, "camera": camera, "followed_id": followed.get_instance_id(), "zoom": maxf(zoom, 0.01), "parked": false, "frames": {}}
	_views[view_name] = record
	_aim(record)
	set_process(true)

## @ace_action
## @ace_featured
## @ace_name("Show View In")
## @ace_category("Second View")
## @ace_description("Hands a view's live picture to the frame you want to see it in - a TextureRect on your HUD, or anything else that takes a texture (a Sprite2D, a Sprite3D on a screen standing in the world). One view can be shown in as many frames as you like, and a Control frame also sizes the render: a minimap in a 200 by 120 panel renders 200 by 120 pixels instead of being stretched out of a square, and follows that panel when the window resizes.")
## @ace_display_template("Show view [b]{view_name}[/b] in [i]{frame}[/i]")
## @ace_param_hint(frame scene_node)
## @ace_icon("res://eventsheet_addons/second_view/icon.svg")
## @ace_codegen_template("SecondView.show_view_in({view_name}, {frame})")
func show_view_in(view_name: String, frame: Node) -> void:
	if not _views.has(view_name):
		push_warning("Second View: there is no view named '%s' to show - make it first." % view_name)
		return
	if frame == null or not is_instance_valid(frame):
		push_warning("Second View: Show View In needs a frame to show the view in.")
		return
	if not ("texture" in frame):
		push_warning("Second View: %s takes no texture. Show a view in a TextureRect, or in anything else with one - a Sprite2D, a Sprite3D." % frame.name)
		return
	var record: Dictionary = _views[view_name]
	frame.set("texture", _texture_of(record))
	var frames: Dictionary = record["frames"]
	if frames.has(frame.get_instance_id()):
		return
	var refit: Callable = Callable()
	if frame is Control:
		# A Control has no size until the layout has run, so the first fit usually lands on the
		# frame's own resized signal rather than here - which is also what keeps it true afterwards.
		refit = _fit_to_frame.bind(view_name, frame.get_instance_id())
		(frame as Control).resized.connect(refit)
		refit.call()
	frames[frame.get_instance_id()] = refit

## @ace_action
## @ace_name("Set View Zoom")
## @ace_category("Second View")
## @ace_description("Changes how much of the world one view has in frame, without rebuilding it. Below 1 pulls back and shows more (a minimap that zooms out as the level opens up), above 1 pushes in and shows less (a magnifier over the cursor, a portrait tightening on a face). Naming a view that does not exist warns and changes nothing.")
## @ace_display_template("Set view [b]{view_name}[/b] zoom to [b]{zoom}[/b]")
## @ace_icon("res://eventsheet_addons/second_view/icon.svg")
## @ace_codegen_template("SecondView.set_view_zoom({view_name}, {zoom})")
func set_view_zoom(view_name: String = "minimap", zoom: float = 0.25) -> void:
	if not _views.has(view_name):
		push_warning("Second View: there is no view named '%s' to zoom." % view_name)
		return
	var record: Dictionary = _views[view_name]
	record["zoom"] = maxf(zoom, 0.01)
	_aim(record)

## @ace_action
## @ace_name("Stop View")
## @ace_category("Second View")
## @ace_description("Frees a view and everything it built - its SubViewport and the camera inside it - and takes its picture back off every frame it was shown in first, so a frame is left blank rather than holding the texture of a viewport that no longer exists. A view whose followed node was destroyed parks itself and costs nothing per frame, but it is still plumbing: this is the row that removes it. Stopping a view that is not there does nothing.")
## @ace_display_template("Stop view [b]{view_name}[/b]")
## @ace_icon("res://eventsheet_addons/second_view/icon.svg")
## @ace_codegen_template("SecondView.stop_view({view_name})")
func stop_view(view_name: String = "minimap") -> void:
	if not _views.has(view_name):
		return
	var record: Dictionary = _views[view_name]
	# The frames are cleared BEFORE the viewport goes: a TextureRect still holding the texture of
	# a freed viewport draws nothing and reports nothing, which reads as the pack breaking rather
	# than as the view being stopped.
	_forget_frames(record)
	var view: SubViewport = record["viewport"]
	if is_instance_valid(view):
		view.queue_free()
	_views.erase(view_name)

## @ace_expression
## @ace_name("View Texture Of")
## @ace_category("Second View")
## @ace_description("A view's live picture as a texture, for the places Show View In cannot reach: a material's albedo, a shader parameter, a theme icon. It is a live handle rather than a copy - whatever the view is looking at now is what it shows - and it answers with nothing for a name no view answers to.")
## @ace_icon("res://eventsheet_addons/second_view/icon.svg")
## @ace_codegen_template("SecondView.view_texture_of({view_name})")
func view_texture_of(view_name: String = "minimap") -> Texture2D:
	if not _views.has(view_name):
		return null
	return _texture_of(_views[view_name])

func _ready() -> void:
	# There is nothing to follow until a view exists, and the frame is handed straight back the
	# moment every view has lost the node it was following.
	set_process(false)

func _process(_delta: float) -> void:
	var following: bool = false
	for view_name: String in _views:
		var record: Dictionary = _views[view_name]
		var followed: Node = instance_from_id(int(record["followed_id"])) as Node
		if followed == null or not is_instance_valid(followed):
			_park(record)
			continue
		following = true
		_aim(record)
	if not following:
		set_process(false)

## Parks a view whose followed node is gone: the picture cannot change again, so the viewport
## stops being redrawn. The plumbing stays until Stop View frees it, so a frame showing the view
## keeps the last picture instead of going black on its own.
func _park(record: Dictionary) -> void:
	if bool(record["parked"]):
		return
	record["parked"] = true
	var view: SubViewport = record["viewport"]
	if is_instance_valid(view):
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED

## Points one view's camera at the node it follows, in whichever of the two worlds that node
## lives in.
func _aim(record: Dictionary) -> void:
	var camera: Node = record["camera"]
	if not is_instance_valid(camera):
		return
	var zoom: float = maxf(float(record["zoom"]), 0.01)
	var followed_2d: Node2D = instance_from_id(int(record["followed_id"])) as Node2D
	if camera is Camera2D and followed_2d != null:
		(camera as Camera2D).global_position = followed_2d.global_position
		(camera as Camera2D).zoom = Vector2(zoom, zoom)
		return
	var followed_3d: Node3D = instance_from_id(int(record["followed_id"])) as Node3D
	if camera is Camera3D and followed_3d != null:
		# Straight down from above, written as a placement rather than as a look_at: looking down
		# the Y axis leaves Godot's default up parallel to the look direction, which is the one case
		# look_at cannot resolve. A camera looks along its own -Z, so pointing that at the ground is
		# the basis whose Z is world up, with world -Z as the screen's up so north stays north.
		# Local placement IS world placement here: the camera's parent is the SubViewport, which
		# carries no transform of its own.
		(camera as Camera3D).position = followed_3d.global_position + Vector3(0.0, OVERHEAD_METRES / zoom, 0.0)
		(camera as Camera3D).basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)

## Sizes a view's render to the frame it is shown in. A Control has no size until the layout has
## run, so a zero is left alone and the frame's own resized signal calls this again once it has one.
func _fit_to_frame(view_name: String, frame_id: int) -> void:
	var frame: Control = instance_from_id(frame_id) as Control
	if frame == null or not _views.has(view_name):
		return
	var wanted: Vector2i = Vector2i(frame.size)
	if wanted.x < 1 or wanted.y < 1:
		return
	var view: SubViewport = (_views[view_name] as Dictionary)["viewport"]
	if is_instance_valid(view):
		view.size = wanted

## Takes a view's texture back off every frame it was handed to, and disconnects the resize hook
## that was keeping the render sized to that frame.
func _forget_frames(record: Dictionary) -> void:
	var frames: Dictionary = record["frames"]
	for frame_id: int in frames:
		var frame: Object = instance_from_id(frame_id)
		if frame == null or not is_instance_valid(frame):
			continue
		var refit: Callable = frames[frame_id]
		if frame is Control and refit.is_valid() and (frame as Control).resized.is_connected(refit):
			(frame as Control).resized.disconnect(refit)
		frame.set("texture", null)
	frames.clear()

# Second View: register as the SecondView autoload. Make A View names a view and gives it a node to follow, Show View In hands its picture to a TextureRect, Set View Zoom changes how much of the world is in frame, and Stop View frees the plumbing. Two views in two frames IS split screen - there is no separate row for it. The nodes this pack builds are ordinary Godot: each view is a SubViewport named View_<the name> parented to this autoload, with an ordinary Camera2D or Camera3D inside it. This pack is an event sheet - extend it by editing it.
