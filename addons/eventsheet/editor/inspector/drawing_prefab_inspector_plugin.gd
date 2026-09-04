# Godot EventSheets - DrawingPrefabResource Inspector (editor-only).
#
# Two things for a DrawingPrefabResource:
#   1. A live preview panel at the top of the Inspector - you SEE the composed drawing while you edit the
#      steps below, re-rendered on the resource's `changed` signal. The card itself is the SHARED one any
#      object can ask for; the prefab hands it the tree-free rasterizer it has always drawn with, so the
#      picture, its size and its refresh are exactly what they were before the card was made general.
#   2. A shape-aware editor for the `steps` array: instead of the generic grid's opaque p1/p2/p3 columns,
#      each step is a CARD whose fields match its shape. That editor lives in its own file beside this
#      one, and the stored keys (kind, x, y, p1, p2, p3, color, texture) are unchanged, so the pack, the
#      rasterizer and the .tres bytes are all untouched.
# Both are cosmetic: without this plugin a prefab still edits as a plain steps table and draws identically.
#
# NOTHING HEAVY IS NAMED HERE. The plugin is constructed at editor boot (add_inspector_plugin takes an
# instance), so a class named in this file is a file compiled at every editor start, in every project -
# including projects with no drawing prefab in them at all. The preview card, the rasterizer, the steps
# editor and the card-list drawer behind it are therefore reached BY PATH, and even the resource this
# plugin claims is recognised by the name its script carries rather than by naming its class. Each of
# them is loaded the first time an Inspector actually asks for it.
@tool
class_name EventSheetDrawingPrefabInspector
extends EditorInspectorPlugin

const PREVIEW_PANEL_PATH: String = "res://addons/eventsheet/editor/inspector/preview_panel.gd"
const PREFAB_PREVIEW_PATH: String = "res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd"
const STEPS_PROPERTY_PATH: String = "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
## The class this plugin claims, as a NAME rather than as the class itself. Reading it off the object's
## own script costs nothing and loads nothing; `object is DrawingPrefabResource` would compile the pack's
## resource script into every editor boot to answer the same question.
const PREFAB_CLASS: StringName = &"DrawingPrefabResource"


func _can_handle(object: Object) -> bool:
	return is_drawing_prefab(object)


## Whether an object is a drawing prefab, asked of the script it already carries. The base chain is
## walked so a project's own subclass of the prefab resource is claimed too, exactly as `is` would.
static func is_drawing_prefab(object: Object) -> bool:
	if object == null:
		return false
	var script: Script = object.get_script() as Script
	while script != null:
		if script.get_global_name() == PREFAB_CLASS:
			return true
		script = script.get_base_script()
	return false


func _parse_begin(object: Object) -> void:
	if is_drawing_prefab(object):
		add_custom_control(load(PREVIEW_PANEL_PATH).new(object, rasterize_prefab))


## The prefab's own picture: the steps rasterized at the card's size, on the card's background. Handed to
## the shared card as its renderer, which is what keeps the prefab's preview byte for byte what it was.
static func rasterize_prefab(object: Object, size: Vector2i) -> Texture2D:
	var steps: Variant = object.get("steps") if object != null else []
	return load(PREFAB_PREVIEW_PATH).call("rasterize_texture",
		steps if steps is Array else [], size, load(PREVIEW_PANEL_PATH).BACKGROUND)


## Claim the `steps` array with the shape-aware editor. This plugin is registered BEFORE the generic
## attribute-drawers plugin, so returning true here wins the property before the opaque p1/p2/p3 grid runs.
func _parse_property(object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if name == "steps" and type == TYPE_ARRAY and is_drawing_prefab(object):
		add_property_editor(name, load(STEPS_PROPERTY_PATH).new())
		return true
	return false
