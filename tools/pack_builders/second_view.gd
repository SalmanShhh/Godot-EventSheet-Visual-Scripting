# Pack builder - second_view (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

const PACK_ICON := "res://eventsheet_addons/second_view/icon.svg"


## Second View: a SECOND PICTURE of the world you are already in, as the SecondView autoload. A view
## is a SubViewport sharing the running world plus a camera of its own following a node, so the
## minimap, the security monitor, the character portrait, the rear-view mirror and the magnifier are
## the same four rows with different frames around them.
##
## Where it sits among its neighbours, because none of this may re-say a row that already ships:
##  - Canvas Surface owns DRAWING SURFACES - an offscreen target you paint shapes and ribbons onto.
##    This pack owns WORLD VIEWS - a second camera on the world that is already running. Both are
##    built out of a SubViewport and neither builds the other's; a drawing question belongs there.
##  - Render Scene To Image (the Editor Tools vocabulary) is the one-shot cousin: it photographs a
##    scene FILE to a .png from the editor. A view is live and belongs to the running game.
##  - Named Scenes addresses WHICH scene the player travels to. A view never changes scene - it is a
##    second look at the one they are in.
##  - The camera a view builds is an ordinary Camera2D / Camera3D, so the visibility-layer rows
##    (Show Only To) already decide what a view is allowed to draw. This pack publishes no culling
##    row of its own.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "SecondView"
	sheet.host_class = "Node"
	sheet.custom_class_name = "SecondViewPackAddon"
	sheet.class_description = "A second picture of the world you are already in, as the SecondView autoload singleton: name a view, give it a node to follow, and show it in a frame. Each view is a SubViewport sharing the running world with a camera of its own, so a minimap, a security monitor, a character portrait and a rear-view mirror are the same rows with different frames. Drawing surfaces belong to the Canvas Surface pack; this one owns world views."
	sheet.addon_category = "Second View"
	sheet.addon_tags = PackedStringArray(["camera", "viewport", "minimap", "ui"])
	var about: CommentRow = CommentRow.new()
	about.text = "Second View: register as the SecondView autoload. Make A View names a view and gives it a node to follow, Show View In hands its picture to a TextureRect, Set View Zoom changes how much of the world is in frame, and Stop View frees the plumbing. Two views in two frames IS split screen - there is no separate row for it. The nodes this pack builds are ordinary Godot: each view is a SubViewport named View_<the name> parented to this autoload, with an ordinary Camera2D or Camera3D inside it. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# The square a view renders at until a frame it is shown in gives it a size of its own.",
		"const STARTING_VIEW_PIXELS: int = 256",
		"",
		"# How far above a followed Node3D the view's camera sits at zoom 1, in metres. Zoom divides it,",
		"# so a bigger zoom is a closer look at less ground - the same direction zoom means for a Camera2D.",
		"const OVERHEAD_METRES: float = 20.0",
		"",
		"# view name -> what that view is made of: the SubViewport it renders into, the camera inside it,",
		"# the instance id of the node it follows, its zoom, whether it has parked, and the frames it has",
		"# been handed to (frame instance id -> the resize callable connected to that frame, so Stop View",
		"# can take it off again).",
		"var _views: Dictionary = {}"
	]))
	sheet.events.append(block)

	# --- Making and stopping a view ---
	Lib.append_function(sheet, "make_a_view", "Make A View", "Second View", "Builds a second view of the world you are already in, under a name every other row addresses it by. The view is a SubViewport sharing the running world with a camera of its own that follows the node you name - a Camera2D when that node is 2D, a Camera3D looking straight down at it when it is 3D. Zoom is how much of the world is in frame: below 1 shows more of it (a minimap), above 1 shows less of it (a magnifier). Making a view under a name that already exists replaces it, so a row that runs twice leaves one view rather than two cameras drawing the same picture.",
		[["view_name", "String"], ["followed", "Node"], ["zoom", "float"]],
		"\n".join(PackedStringArray([
			"if view_name.is_empty():",
			"\tpush_warning(\"Second View: Make A View needs a name to call the view by.\")",
			"\treturn",
			"if followed == null or not is_instance_valid(followed):",
			"\tpush_warning(\"Second View: Make A View needs a node for the view to follow.\")",
			"\treturn",
			"if not (followed is Node2D or followed is Node3D):",
			"\tpush_warning(\"Second View: a view follows a Node2D or a Node3D, and %s is neither - there would be nowhere to put the camera.\" % followed.name)",
			"\treturn",
			"if not is_inside_tree():",
			"\treturn",
			"stop_view(view_name)",
			"var view: SubViewport = SubViewport.new()",
			"view.name = \"View_\" + view_name",
			"view.size = Vector2i(STARTING_VIEW_PIXELS, STARTING_VIEW_PIXELS)",
			"view.transparent_bg = true",
			"# A SubViewport outside a SubViewportContainer is never \"visible\", and the default update",
			"# mode only draws what is visible - which is why a second view built by hand so often ends up",
			"# a blank texture. Always is the honest answer for a viewport something is looking at.",
			"view.render_target_update_mode = SubViewport.UPDATE_ALWAYS",
			"var camera: Node = null",
			"if followed is Node3D:",
			"\t# Sharing the world is the whole trick: the view draws the world the game is already",
			"\t# running rather than a second empty one, which is why own_world_3d stays off.",
			"\tview.world_3d = get_viewport().find_world_3d()",
			"\tvar eye: Camera3D = Camera3D.new()",
			"\teye.current = true",
			"\tcamera = eye",
			"else:",
			"\t# The 2D world is shared the same way. A CanvasLayer belongs to the viewport it is in",
			"\t# rather than to the world, so the HUD is not drawn into the view - which is what you want.",
			"\tview.world_2d = get_viewport().find_world_2d()",
			"\tvar lens: Camera2D = Camera2D.new()",
			"\tlens.enabled = true",
			"\tcamera = lens",
			"view.add_child(camera)",
			"add_child(view)",
			"var record: Dictionary = {\"viewport\": view, \"camera\": camera, \"followed_id\": followed.get_instance_id(), \"zoom\": maxf(zoom, 0.01), \"parked\": false, \"frames\": {}}",
			"_views[view_name] = record",
			"_aim(record)",
			"set_process(true)"
		])))
	Lib.append_function(sheet, "show_view_in", "Show View In", "Second View", "Hands a view's live picture to the frame you want to see it in - a TextureRect on your HUD, or anything else that takes a texture (a Sprite2D, a Sprite3D on a screen standing in the world). One view can be shown in as many frames as you like, and a Control frame also sizes the render: a minimap in a 200 by 120 panel renders 200 by 120 pixels instead of being stretched out of a square, and follows that panel when the window resizes.",
		[["view_name", "String"], ["frame", "Node"]],
		"\n".join(PackedStringArray([
			"if not _views.has(view_name):",
			"\tpush_warning(\"Second View: there is no view named '%s' to show - make it first.\" % view_name)",
			"\treturn",
			"if frame == null or not is_instance_valid(frame):",
			"\tpush_warning(\"Second View: Show View In needs a frame to show the view in.\")",
			"\treturn",
			"if not (\"texture\" in frame):",
			"\tpush_warning(\"Second View: %s takes no texture. Show a view in a TextureRect, or in anything else with one - a Sprite2D, a Sprite3D.\" % frame.name)",
			"\treturn",
			"var record: Dictionary = _views[view_name]",
			"frame.set(\"texture\", _texture_of(record))",
			"var frames: Dictionary = record[\"frames\"]",
			"if frames.has(frame.get_instance_id()):",
			"\treturn",
			"var refit: Callable = Callable()",
			"if frame is Control:",
			"\t# A Control has no size until the layout has run, so the first fit usually lands on the",
			"\t# frame's own resized signal rather than here - which is also what keeps it true afterwards.",
			"\trefit = _fit_to_frame.bind(view_name, frame.get_instance_id())",
			"\t(frame as Control).resized.connect(refit)",
			"\trefit.call()",
			"frames[frame.get_instance_id()] = refit"
		])))
	Lib.append_function(sheet, "set_view_zoom", "Set View Zoom", "Second View", "Changes how much of the world one view has in frame, without rebuilding it. Below 1 pulls back and shows more (a minimap that zooms out as the level opens up), above 1 pushes in and shows less (a magnifier over the cursor, a portrait tightening on a face). Naming a view that does not exist warns and changes nothing.",
		[["view_name", "String"], ["zoom", "float"]],
		"\n".join(PackedStringArray([
			"if not _views.has(view_name):",
			"\tpush_warning(\"Second View: there is no view named '%s' to zoom.\" % view_name)",
			"\treturn",
			"var record: Dictionary = _views[view_name]",
			"record[\"zoom\"] = maxf(zoom, 0.01)",
			"_aim(record)"
		])))
	Lib.append_function(sheet, "stop_view", "Stop View", "Second View", "Frees a view and everything it built - its SubViewport and the camera inside it - and takes its picture back off every frame it was shown in first, so a frame is left blank rather than holding the texture of a viewport that no longer exists. A view whose followed node was destroyed parks itself and costs nothing per frame, but it is still plumbing: this is the row that removes it. Stopping a view that is not there does nothing.",
		[["view_name", "String"]],
		"\n".join(PackedStringArray([
			"if not _views.has(view_name):",
			"\treturn",
			"var record: Dictionary = _views[view_name]",
			"# The frames are cleared BEFORE the viewport goes: a TextureRect still holding the texture of",
			"# a freed viewport draws nothing and reports nothing, which reads as the pack breaking rather",
			"# than as the view being stopped.",
			"_forget_frames(record)",
			"var view: SubViewport = record[\"viewport\"]",
			"if is_instance_valid(view):",
			"\tview.queue_free()",
			"_views.erase(view_name)"
		])))

	# --- The power user's handle on the same picture ---
	var texture_of: EventFunction = Lib.exposed_function("view_texture_of", "View Texture Of", "Second View",
		"A view's live picture as a texture, for the places Show View In cannot reach: a material's albedo, a shader parameter, a theme icon. It is a live handle rather than a copy - whatever the view is looking at now is what it shows - and it answers with nothing for a name no view answers to.",
		[["view_name", "String"]],
		"\n".join(PackedStringArray([
			"if not _views.has(view_name):",
			"\treturn null",
			"return _texture_of(_views[view_name])"
		])))
	texture_of.return_type = TYPE_OBJECT
	texture_of.return_type_name = "Texture2D"
	sheet.functions.append(texture_of)

	# The private plumbing under the verbs. Nothing here is `_`-free, so none of it publishes as
	# vocabulary. `_texture_of` is emitted ABOVE the verbs rather than here, because the compiler
	# hoists a helper the exposed verbs call - that is where to look for it in the shipped pack.
	var runtime: RawCodeRow = RawCodeRow.new()
	runtime.code = "\n".join(PackedStringArray([
		"func _ready() -> void:",
		"\t# There is nothing to follow until a view exists, and the frame is handed straight back the",
		"\t# moment every view has lost the node it was following.",
		"\tset_process(false)",
		"",
		"func _process(_delta: float) -> void:",
		"\tvar following: bool = false",
		"\tfor view_name: String in _views:",
		"\t\tvar record: Dictionary = _views[view_name]",
		"\t\tvar followed: Node = instance_from_id(int(record[\"followed_id\"])) as Node",
		"\t\tif followed == null or not is_instance_valid(followed):",
		"\t\t\t_park(record)",
		"\t\t\tcontinue",
		"\t\tfollowing = true",
		"\t\t_aim(record)",
		"\tif not following:",
		"\t\tset_process(false)",
		"",
		"## Parks a view whose followed node is gone: the picture cannot change again, so the viewport",
		"## stops being redrawn. The plumbing stays until Stop View frees it, so a frame showing the view",
		"## keeps the last picture instead of going black on its own.",
		"func _park(record: Dictionary) -> void:",
		"\tif bool(record[\"parked\"]):",
		"\t\treturn",
		"\trecord[\"parked\"] = true",
		"\tvar view: SubViewport = record[\"viewport\"]",
		"\tif is_instance_valid(view):",
		"\t\tview.render_target_update_mode = SubViewport.UPDATE_DISABLED",
		"",
		"## Points one view's camera at the node it follows, in whichever of the two worlds that node",
		"## lives in.",
		"func _aim(record: Dictionary) -> void:",
		"\tvar camera: Node = record[\"camera\"]",
		"\tif not is_instance_valid(camera):",
		"\t\treturn",
		"\tvar zoom: float = maxf(float(record[\"zoom\"]), 0.01)",
		"\tvar followed_2d: Node2D = instance_from_id(int(record[\"followed_id\"])) as Node2D",
		"\tif camera is Camera2D and followed_2d != null:",
		"\t\t(camera as Camera2D).global_position = followed_2d.global_position",
		"\t\t(camera as Camera2D).zoom = Vector2(zoom, zoom)",
		"\t\treturn",
		"\tvar followed_3d: Node3D = instance_from_id(int(record[\"followed_id\"])) as Node3D",
		"\tif camera is Camera3D and followed_3d != null:",
		"\t\t# Straight down from above, written as a placement rather than as a look_at: looking down",
		"\t\t# the Y axis leaves Godot's default up parallel to the look direction, which is the one case",
		"\t\t# look_at cannot resolve. A camera looks along its own -Z, so pointing that at the ground is",
		"\t\t# the basis whose Z is world up, with world -Z as the screen's up so north stays north.",
		"\t\t# Local placement IS world placement here: the camera's parent is the SubViewport, which",
		"\t\t# carries no transform of its own.",
		"\t\t(camera as Camera3D).position = followed_3d.global_position + Vector3(0.0, OVERHEAD_METRES / zoom, 0.0)",
		"\t\t(camera as Camera3D).basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)",
		"",
		"## The live handle on a view's picture. It is taken only once the viewport is really in the tree,",
		"## and it is marked NOT local to scene before it is handed out: a ViewportTexture that is local to",
		"## scene re-resolves its viewport by node path whenever the scene holding it is set up, and this",
		"## viewport is a child of this autoload rather than of any scene. Off, the handle stays bound to",
		"## the viewport it came from, wherever the frame showing it happens to live.",
		"func _texture_of(record: Dictionary) -> Texture2D:",
		"\tvar view: SubViewport = record[\"viewport\"]",
		"\tif not is_instance_valid(view) or not is_inside_tree():",
		"\t\treturn null",
		"\tvar handle: ViewportTexture = view.get_texture()",
		"\tif handle != null:",
		"\t\thandle.resource_local_to_scene = false",
		"\treturn handle",
		"",
		"## Sizes a view's render to the frame it is shown in. A Control has no size until the layout has",
		"## run, so a zero is left alone and the frame's own resized signal calls this again once it has one.",
		"func _fit_to_frame(view_name: String, frame_id: int) -> void:",
		"\tvar frame: Control = instance_from_id(frame_id) as Control",
		"\tif frame == null or not _views.has(view_name):",
		"\t\treturn",
		"\tvar wanted: Vector2i = Vector2i(frame.size)",
		"\tif wanted.x < 1 or wanted.y < 1:",
		"\t\treturn",
		"\tvar view: SubViewport = (_views[view_name] as Dictionary)[\"viewport\"]",
		"\tif is_instance_valid(view):",
		"\t\tview.size = wanted",
		"",
		"## Takes a view's texture back off every frame it was handed to, and disconnects the resize hook",
		"## that was keeping the render sized to that frame.",
		"func _forget_frames(record: Dictionary) -> void:",
		"\tvar frames: Dictionary = record[\"frames\"]",
		"\tfor frame_id: int in frames:",
		"\t\tvar frame: Object = instance_from_id(frame_id)",
		"\t\tif frame == null or not is_instance_valid(frame):",
		"\t\t\tcontinue",
		"\t\tvar refit: Callable = frames[frame_id]",
		"\t\tif frame is Control and refit.is_valid() and (frame as Control).resized.is_connected(refit):",
		"\t\t\t(frame as Control).resized.disconnect(refit)",
		"\t\tframe.set(\"texture\", null)",
		"\tframes.clear()"
	]))
	sheet.events.append(runtime)

	Lib.verb_sentences(sheet, {
		"make_a_view": "Make a view named [b]{view_name}[/b] following [i]{followed}[/i] at zoom [b]{zoom}[/b]",
		"show_view_in": "Show view [b]{view_name}[/b] in [i]{frame}[/i]",
		"set_view_zoom": "Set view [b]{view_name}[/b] zoom to [b]{zoom}[/b]",
		"stop_view": "Stop view [b]{view_name}[/b]",
	})
	Lib.feature_verbs(sheet, ["make_a_view", "show_view_in"])
	_set_hints(sheet, "make_a_view", {"followed": "scene_node"})
	_set_hints(sheet, "show_view_in", {"frame": "scene_node"})
	_set_defaults(sheet, "set_view_zoom", {"view_name": "\"minimap\"", "zoom": "0.25"})
	_set_defaults(sheet, "stop_view", {"view_name": "\"minimap\""})
	_set_defaults(sheet, "view_texture_of", {"view_name": "\"minimap\""})
	return Lib.save_pack(sheet, "res://eventsheet_addons/second_view/second_view_addon", PACK_ICON)


## Gives an exposed verb's parameters GDScript defaults, which become the row's pre-filled cells (the
## emitted pack carries no separate picker default). GDScript requires defaulted parameters to be
## trailing, so a verb whose first parameter is a node the author must supply gets none at all.
static func _set_defaults(sheet: EventSheetResource, function_name: String, defaults: Dictionary) -> void:
	for parameter: ACEParam in _params_of(sheet, function_name):
		if defaults.has(parameter.id):
			parameter.gdscript_default = str(defaults[parameter.id])


## Gives an exposed verb's parameters their widget hints - which field the dialog builds for them.
static func _set_hints(sheet: EventSheetResource, function_name: String, hints: Dictionary) -> void:
	for parameter: ACEParam in _params_of(sheet, function_name):
		if hints.has(parameter.id):
			parameter.hint = str(hints[parameter.id])


## The parameters of one exposed verb, by name, warning rather than failing silently on a typo.
static func _params_of(sheet: EventSheetResource, function_name: String) -> Array:
	for function_resource: Resource in sheet.functions:
		if function_resource is EventFunction and (function_resource as EventFunction).function_name == function_name:
			return (function_resource as EventFunction).params
	push_warning("second_view: no function named %s on this sheet (typo?)" % function_name)
	return []
