# Pack builder - touch_shape_library_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## TouchShapeLibraryResource: the drawn shapes a project recognises, as a .tres asset. Touch Gestures
## teaches into it (Teach Shape From Stroke) and reads out of it, so the rings, runes and letters a
## game knows are authored by DRAWING them once rather than by typing coordinates - and they ship
## with the project, get version-controlled, and can be swapped per level.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "TouchShapeLibraryResource"
	sheet.class_description = "The drawn shapes a project recognises, as a data asset. Each entry is a name and the smoothed outline that was drawn to teach it; Touch Gestures matches a finished stroke against every entry and fires On Shape Drawn with the closest name."
	sheet.variables = {
		"library_name": {"type": "String", "default": "shapes", "exported": true,
			"attributes": {"tooltip": "A label for your own reference (Touch Gestures does not read it).",
				"header": "Shape Library", "header_color": "#7bc96f",
				"info": "Draw a shape in the running game and call Teach Shape From Stroke to add it here, then Save Shapes To this file."}},
		"shapes": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "Shape name to the smoothed outline that was drawn for it. Taught by drawing, not by typing - use Teach Shape From Stroke while the game runs."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/touch_shape_library_resource/touch_shape_library_resource")
