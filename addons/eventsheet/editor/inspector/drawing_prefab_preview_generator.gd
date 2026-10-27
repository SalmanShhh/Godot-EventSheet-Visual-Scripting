# Godot EventSheets - DrawingPrefabResource thumbnail generator (editor-only).
#
# Gives a DrawingPrefabResource `.tres` a real thumbnail of its composed drawing wherever the editor shows
# resource previews: the FileSystem dock, the resource picker on a Draw Prefab action, and quick-open. So
# you can pick the right prefab by its PICTURE, not its filename. Runs off the main thread, so it renders
# through the tree-free software rasterizer (a SubViewport would crash here). Cosmetic only.
@tool
class_name EventSheetDrawingPrefabPreviewGenerator
extends EditorResourcePreviewGenerator

## The prefab resource is recognised by its script path, never by its class name. The class lives in a
## pack, and a project without that pack installed has no such name to resolve: naming it here made
## this file fail to compile, which took the plugin's start-up down with it.
const PREFAB_SCRIPT_SUFFIX: String = "drawing_prefab_resource/drawing_prefab_resource.gd"


func _handles(type: String) -> bool:
	return type == "DrawingPrefabResource"


func _can_generate_small_preview() -> bool:
	return true


func _generate(resource: Resource, size: Vector2i, _metadata: Dictionary) -> Texture2D:
	var script: Script = resource.get_script() as Script if resource != null else null
	if script == null or not script.resource_path.ends_with(PREFAB_SCRIPT_SUFFIX):
		return null
	var steps: Variant = resource.get("steps")
	if not (steps is Array):
		steps = []
	var bg: Color = Color(0.11, 0.12, 0.15, 1.0)
	return EventSheetDrawingPrefabPreview.rasterize_texture(steps as Array, size, bg)
