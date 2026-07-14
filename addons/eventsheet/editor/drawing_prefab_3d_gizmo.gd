@tool
class_name EventSheetDrawingPrefab3DGizmo
extends RefCounted

# Selection-driven 3D preview gizmo for DrawingPrefabResource references. Select a Node3D that exposes a
# DrawingPrefabResource property and the formation shows as a camera-facing billboard at the node's
# origin - so a 2D vector prefab (a target ring, a scorch mark, a cone) reads in the 3D viewport too,
# the same formations the Decal Painter already stamps onto 3D surfaces. The billboard is a transient
# owner-less Sprite3D (never written to the scene file) textured from the shared software rasterizer
# (EventSheetDrawingPrefabPreview - the exact renderer behind the Inspector preview and the FileSystem
# thumbnail), driven off EditorSelection.selection_changed so the 3D editor is never hijacked. Same
# discipline as EventSheetDrawingPrefabGizmo, in three dimensions.

const PREVIEW_NODE_NAME: String = "__DrawingPrefab3DPreview"
## A DrawingPrefabResource is recognised by its script path (never by class) so this file stays off the
## boot compile.
const PREFAB_SCRIPT_SUFFIX: String = "drawing_prefab_resource/drawing_prefab_resource.gd"
## The raster the billboard carries. Square so the prefab keeps its aspect (the rasterizer letterboxes).
const TEXTURE_SIZE: Vector2i = Vector2i(128, 128)
## World units per texture pixel: a 128 px raster stands ~1.28 units tall - a legible marker at scene scale.
const PIXEL_SIZE: float = 0.01

var _editor_interface: EditorInterface = null
var _preview: Node3D = null


## Wires the gizmo to editor selection and previews the current selection. Called from the plugin's
## _enter_tree; a null interface (non-editor context) is a safe no-op.
func init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	if _editor_interface == null:
		return
	var selection: EditorSelection = _editor_interface.get_selection()
	if selection != null and not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


## Tears the gizmo down: drops any live preview and disconnects from selection, so a disabled plugin
## leaves the edited scene byte-identical to how it found it.
func teardown() -> void:
	_clear_preview()
	if _editor_interface != null:
		var selection: EditorSelection = _editor_interface.get_selection()
		if selection != null and selection.selection_changed.is_connected(_on_selection_changed):
			selection.selection_changed.disconnect(_on_selection_changed)
	_editor_interface = null


## Rebuilds the preview for the current selection: exactly one Node3D that exposes a DrawingPrefabResource
## shows that formation as a billboard at its origin; every other selection clears it.
func _on_selection_changed() -> void:
	_clear_preview()
	if _editor_interface == null:
		return
	var selected: Array[Node] = _editor_interface.get_selection().get_selected_nodes()
	if selected.size() != 1:
		return
	var node: Node3D = selected[0] as Node3D
	if node == null:
		return
	var prefab: Resource = find_prefab(node)
	if prefab == null:
		return
	_add_preview(node, prefab)


## The first DrawingPrefabResource-typed property value stored on the node, or null. A self-contained
## twin of the 2D gizmo's detector (no cross-class dependency, so the two gizmos never wait on each
## other's class-cache registration): it walks stored properties and returns the first whose script is
## the prefab resource, duck-typed by path so this file never names the pack class.
static func find_prefab(node: Node) -> Resource:
	if node == null:
		return null
	for entry: Dictionary in node.get_property_list():
		if int(entry.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var value: Variant = node.get(str(entry.get("name", "")))
		if value is Resource and _is_prefab(value as Resource):
			return value as Resource
	return null


static func _is_prefab(res: Resource) -> bool:
	var script: Script = res.get_script() as Script
	return script != null and str(script.resource_path).ends_with(PREFAB_SCRIPT_SUFFIX)


## Rasterizes the prefab to a texture and hangs it under the host as a camera-facing Sprite3D. owner
## stays null so the billboard is never serialized into the scene. Returns the Sprite3D (or null when the
## prefab has no steps to draw) - split out so a render harness can build the same billboard headlessly.
static func build_billboard(prefab: Resource) -> Node3D:
	if prefab == null:
		return null
	var steps: Variant = prefab.get("steps")
	if not (steps is Array):
		return null
	var texture: ImageTexture = EventSheetDrawingPrefabPreview.rasterize_texture(steps as Array, TEXTURE_SIZE, Color(0, 0, 0, 0))
	if texture == null:
		return null
	var sprite: Sprite3D = Sprite3D.new()
	sprite.name = PREVIEW_NODE_NAME
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.pixel_size = PIXEL_SIZE
	return sprite


func _add_preview(host: Node3D, prefab: Resource) -> void:
	var sprite: Node3D = build_billboard(prefab)
	if sprite == null:
		return
	host.add_child(sprite)
	sprite.owner = null
	_preview = sprite


## Removes the live preview billboard, if any.
func _clear_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		if _preview.get_parent() != null:
			_preview.get_parent().remove_child(_preview)
		_preview.queue_free()
	_preview = null
