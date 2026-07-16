@icon("res://eventsheet_addons/behavior.svg")
class_name DrawingPrefabResource
extends Resource
## A reusable drawing: an ordered grid of shape steps replayed by the Drawing Canvas's Draw Prefab action at any position, scale, and rotation. Fill the steps grid in the Inspector and save as a .tres.

## A label for your own reference (the canvas does not read it).
@export var prefab_name: String = "marker"
## The shapes, drawn top to bottom. kind: circle / ring / rect / line / cone / stamp. x,y = the step's offset from the prefab origin. p1,p2,p3 by kind - circle: p1 radius; ring: p1 radius, p2 width; rect: p1 width, p2 height; line: p1,p2 = end offset, p3 width; cone: p1 facing deg, p2 fov deg, p3 radius; stamp: p1 scale, p2 rotation deg (texture = the image path). color: a name or hex like #ff8800.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:kind=enum(circle|ring|rect|line|cone|stamp),x=float,y=float,p1=float,p2=float,p3=float,color=color,texture=String") var steps: Array = []

## The steps pre-parsed into typed draw entries, cached until the resource changes - so replaying
## this prefab across many stamps does not re-parse colors/kinds every draw. Runtime only (not
## exported, so never serialized). Read ONLY on the main thread (the draw paths); the off-thread
## thumbnail rasterizer reads the raw steps instead and never calls this.
var _compiled: Array = []
var _compiled_valid: bool = false
var _compiled_size: int = -1

func compiled_steps() -> Array:
	if not changed.is_connected(_invalidate_compiled):
		changed.connect(_invalidate_compiled)
	if _compiled_valid and _compiled_size == steps.size():
		return _compiled
	_compiled = compile_steps(steps)
	_compiled_size = steps.size()
	_compiled_valid = true
	return _compiled

func _invalidate_compiled() -> void:
	_compiled_valid = false
	_compiled = []

static func compile_steps(raw: Array) -> Array:
	var out: Array = []
	for step: Variant in raw:
		if not (step is Dictionary):
			continue
		var entry: Dictionary = step
		var kind: String = str(entry.get("kind", ""))
		var tex: Texture2D = null
		if kind == "stamp":
			var texture_path: String = str(entry.get("texture", "")).strip_edges()
			if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
				tex = load(texture_path) as Texture2D
		out.append({
			"kind": kind,
			"x": float(entry.get("x", 0.0)),
			"y": float(entry.get("y", 0.0)),
			"p1": float(entry.get("p1", 0.0)),
			"p2": float(entry.get("p2", 0.0)),
			"p3": float(entry.get("p3", 0.0)),
			"color": Color.from_string(str(entry.get("color", "white")), Color.WHITE),
			"tex": tex,
		})
	return out
