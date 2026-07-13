# Godot EventSheets - DrawingPrefabResource thumbnail generator (editor-only).
#
# Gives a DrawingPrefabResource `.tres` a real thumbnail of its composed drawing wherever the editor shows
# resource previews: the FileSystem dock, the resource picker on a Draw Prefab action, and quick-open. So
# you can pick the right prefab by its PICTURE, not its filename. Runs off the main thread, so it renders
# through the tree-free software rasterizer (a SubViewport would crash here). Cosmetic only.
@tool
class_name EventSheetDrawingPrefabPreviewGenerator
extends EditorResourcePreviewGenerator


func _handles(type: String) -> bool:
	return type == "DrawingPrefabResource"


func _can_generate_small_preview() -> bool:
	return true


func _generate(resource: Resource, size: Vector2i, metadata: Dictionary) -> Texture2D:
	if not (resource is DrawingPrefabResource):
		return null
	var steps: Variant = resource.get("steps")
	if not (steps is Array):
		steps = []
	var bg: Color = Color(0.11, 0.12, 0.15, 1.0)
	return EventSheetDrawingPrefabPreview.rasterize_texture(steps as Array, size, bg)
