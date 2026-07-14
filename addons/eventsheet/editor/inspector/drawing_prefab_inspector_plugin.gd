# Godot EventSheets - DrawingPrefabResource Inspector preview (editor-only).
#
# When a DrawingPrefabResource is selected, this drops a live preview panel at the top of its Inspector,
# so you SEE the composed drawing (all its steps, in order) while you edit the steps grid below. The panel
# re-renders whenever the resource changes. Purely cosmetic: the resource and the pack are untouched, and
# without this plugin the resource still edits as a plain steps table.
@tool
class_name EventSheetDrawingPrefabInspector
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	return object is DrawingPrefabResource


func _parse_begin(object: Object) -> void:
	if object is DrawingPrefabResource:
		add_custom_control(PreviewPanel.new(object as Resource))


## The preview surface: a fixed-size raster of the prefab, scaled to fit the Inspector column. Re-rasterizes
## on the resource's `changed` signal (so editing a step updates the picture) and cleans up its connection
## when freed.
class PreviewPanel:
	extends PanelContainer

	var _resource: Resource = null
	var _rect: TextureRect = null

	func _init(resource: Resource) -> void:
		_resource = resource
		# Height tracks the raster's own aspect (384x200) at a typical inspector-column width, so the
		# preview is a compact card instead of a tall box with big empty letterbox bands above and below.
		custom_minimum_size = Vector2(0, 158)
		var margin: MarginContainer = MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 4)
		add_child(margin)
		_rect = TextureRect.new()
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(_rect)
		if _resource != null and not _resource.changed.is_connected(_refresh):
			_resource.changed.connect(_refresh)

	func _ready() -> void:
		_refresh()

	func _exit_tree() -> void:
		if _resource != null and _resource.changed.is_connected(_refresh):
			_resource.changed.disconnect(_refresh)

	func _refresh() -> void:
		if _rect == null:
			return
		var steps: Variant = _resource.get("steps") if _resource != null else []
		if not (steps is Array):
			steps = []
		var bg: Color = Color(0.11, 0.12, 0.15, 1.0)
		_rect.texture = EventSheetDrawingPrefabPreview.rasterize_texture(steps as Array, Vector2i(384, 200), bg)
