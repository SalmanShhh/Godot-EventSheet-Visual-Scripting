@tool
class_name EventSheetObjectThumbnails
extends RefCounted

# Q10 - an object's PICTURE, wherever the sheet shows the object.
#
# An event sheet shows a thing by showing the thing: the Include bar, the Object bar, the Object
# properties popup and every object label carry the object's own picture, not a diagram of its class.
# Godot already has that picture - the texture on the Sprite2D / TextureRect at the top of the
# object's scene - and it already has a THUMBNAIL of it, in the editor's own preview cache, which is
# what the FileSystem dock draws with.
#
# So nothing new is rendered here. The texture path is recovered from the .tscn as text (object_facts)
# and handed to EditorResourcePreview, which answers from its cache or renders once and calls back.
# Until it answers, the object keeps its class icon, which is what it wore before - the picture
# arriving a frame later is an improvement appearing, never a gap opening.
#
# HEADLESS IS ICON-ONLY BY CONSTRUCTION: without EditorInterface there is no previewer, every lookup
# answers null, and every caller falls back to the class icon it already had.


## Texture path -> the thumbnail the previewer answered with. Session-lifetime: the editor rebuilds
## its own preview when the file changes, and this is dropped with it.
static var _ready_thumbnails: Dictionary = {}

## Texture paths already asked for, so a row drawn sixty times a second queues one request, not sixty.
static var _requested: Dictionary = {}

## Called once whenever a newly arrived thumbnail makes a redraw worth doing.
static var _on_arrival: Callable = Callable()


## Who to tell when a thumbnail lands (the dock passes a viewport redraw). Optional: without it the
## picture simply appears at the next redraw the editor was going to do anyway.
static func set_arrival_handler(handler: Callable) -> void:
	_on_arrival = handler


## Drops every cached thumbnail and pending request.
static func clear_cache() -> void:
	_ready_thumbnails.clear()
	_requested.clear()


## The picture one census entry should wear, or null when it has none yet (or ever). Callers treat
## null as "use the class icon", which is what makes this safe to ask for on every draw.
##
## `sheet_source_path` is the open file, so the sheet's OWN object finds the scene it is attached to.
static func thumbnail_for(entry: Dictionary, sheet_source_path: String = "") -> Texture2D:
	var texture_path: String = texture_path_for(entry, sheet_source_path)
	if texture_path.is_empty():
		return null
	return thumbnail_of(texture_path)


## The picture behind one texture path, requesting it from the editor's preview cache the first time
## it is asked for. Null while the previewer is still working, and null forever without an editor.
static func thumbnail_of(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	if _ready_thumbnails.has(texture_path):
		return _ready_thumbnails[texture_path]
	if _requested.has(texture_path):
		return null
	if not (Engine.is_editor_hint() and Engine.has_singleton("EditorInterface")):
		return null
	_requested[texture_path] = true
	var previewer: EditorResourcePreview = EditorInterface.get_resource_previewer()
	if previewer == null:
		return null
	previewer.queue_resource_preview(texture_path, _receiver(), "_preview_ready", texture_path)
	return null


## The previewer calls back into an OBJECT, so one long-lived instance receives for everybody. Held
## statically because the request outlives whatever row asked for it.
static var _receiver_instance: EventSheetObjectThumbnails = null


static func _receiver() -> EventSheetObjectThumbnails:
	if _receiver_instance == null:
		_receiver_instance = EventSheetObjectThumbnails.new()
	return _receiver_instance


## The texture file one census entry's picture comes from, "" when the object has no scene or the
## scene has nothing picture-shaped on it.
##
## Three shapes and nothing else, because those are the three an object can be: the sheet's own
## object (the scene its script is the root of), a scene it spawns (that scene), and a node of the
## sheet's own scene (that node's own texture, so a `$Sprite2D` row shows the sprite rather than the
## whole object).
static func texture_path_for(entry: Dictionary, sheet_source_path: String) -> String:
	var kind: String = str(entry.get("kind", ""))
	if kind == "scene":
		return str(EventSheetObjectFacts.scene_facts(str(entry.get("path", ""))).get("picture", ""))
	if sheet_source_path.strip_edges().is_empty():
		return ""
	var scene_path: String = str(ViewportRowBuilder.scene_using_script(sheet_source_path).get("scene_path", ""))
	if scene_path.is_empty():
		return ""
	if kind == "script":
		return str(EventSheetObjectFacts.scene_facts(scene_path).get("picture", ""))
	if kind in ["node", "behaviour"]:
		return EventSheetObjectFacts.picture_of_node(scene_path, str(entry.get("label", "")))
	return ""


## The previewer's callback. `_thumbnail` is the small preview and `preview` the larger one; the small
## one is what a row-height mark wants, and the large one is the fallback for a format that has none.
func _preview_ready(_path: String, preview: Texture2D, thumbnail: Texture2D, texture_path: Variant) -> void:
	var key: String = str(texture_path)
	var picture: Texture2D = thumbnail if thumbnail != null else preview
	if picture == null:
		return
	_ready_thumbnails[key] = picture
	if _on_arrival.is_valid():
		_on_arrival.call()
