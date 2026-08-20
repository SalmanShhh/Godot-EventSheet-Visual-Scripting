## @ace_version(1.0.0)
@icon("res://eventsheet_addons/behavior.svg")
class_name TouchShapeLibraryResource
extends Resource
## The drawn shapes a project recognises, as a data asset. Each entry is a name and the smoothed outline that was drawn to teach it; Touch Gestures matches a finished stroke against every entry and fires On Shape Drawn with the closest name.

# @inspector_header Shape Library #7bc96f
# @inspector_info Draw a shape in the running game and call Teach Shape From Stroke to add it here, then Save Shapes To this file.
## A label for your own reference (Touch Gestures does not read it).
@export var library_name: String = "shapes"
## Shape name to the smoothed outline that was drawn for it. Taught by drawing, not by typing - use Teach Shape From Stroke while the game runs.
@export var shapes: Dictionary = {}
