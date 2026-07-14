@icon("res://eventsheet_addons/behavior.svg")
class_name DrawingPrefabResource
extends Resource
## A reusable drawing: an ordered grid of shape steps replayed by the Drawing Canvas's Draw Prefab action at any position, scale, and rotation. Fill the steps grid in the Inspector and save as a .tres.

## A label for your own reference (the canvas does not read it).
@export var prefab_name: String = "marker"
## The shapes, drawn top to bottom. kind: circle / ring / rect / line / cone / stamp. x,y = the step's offset from the prefab origin. p1,p2,p3 by kind - circle: p1 radius; ring: p1 radius, p2 width; rect: p1 width, p2 height; line: p1,p2 = end offset, p3 width; cone: p1 facing deg, p2 fov deg, p3 radius; stamp: p1 scale, p2 rotation deg (texture = the image path). color: a name or hex like #ff8800.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:kind=enum(circle|ring|rect|line|cone|stamp),x=float,y=float,p1=float,p2=float,p3=float,color=String,texture=String") var steps: Array = []
