# EventForge - visual render harness for the Object properties HIERARCHY pane (dev tool).
# Builds the popup panel for one object with its hierarchy section and saves a PNG. Run NON-headless:
#   godot --path . --script tools/render_hierarchy_pane_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _panel: Control = null


func _init() -> void:
	root.title = "Hierarchy Pane Preview"
	root.size = Vector2i(560, 520)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#252525")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var facts: Dictionary = {
			"parent": {"label": "Level", "note": "(the layout)", "scene_owned": true},
			"children": [
				_sample_child("Camera Pivot", "Camera3D", 0, true, false, {}),
				_sample_child("Hand", "", 1, true, false, {}),
				_sample_child("HealthBar", "", 0, false, true, {}),
				_sample_child("Hat", "", 0, false, false, {"position": true, "angle": true, "size": false})
			]
		}
		var handlers: Dictionary = {
			"jump": func(_label: String) -> void: pass,
			"add_child": func(_label: String) -> void: pass,
			"flags": func(_label: String) -> void: pass,
			"unparent": func(_label: String) -> void: pass,
			"select": func(_label: String) -> void: pass,
			"edit_scene": func(_label: String) -> void: pass
		}
		var entry: Dictionary = {
			"label": "Player", "kind": "node", "class": "CharacterBody3D", "path": "$Player",
			"rows": 6, "verbs": PackedStringArray(["Move", "Set position"]),
			"signals": PackedStringArray()
		}
		_panel = EventSheetObjectProperties.build_panel(entry, "level.tscn", {},
			Callable(), Callable(), Callable(), "", Callable(), Callable(), Callable(), null,
			EventSheetObjectHierarchy.build_section(facts, handlers))
		_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		root.add_child(_panel)
		return
	if _frames < 8 or _panel == null:
		return
	# Cropped to the panel: a figure that is four fifths empty backdrop reads as a mistake.
	var image: Image = root.get_texture().get_image().get_region(Rect2i(0, 0, 504, 500))
	image.save_png("res://docs/images/hierarchy-pane.png")
	print("[hierarchy_pane_preview] saved res://docs/images/hierarchy-pane.png (%dx%d)"
		% [image.get_width(), image.get_height()])
	quit(0)


## One child of the sample hierarchy, in the shape the pane reads: what it is called, its class when
## the pane shows one, how many children of its own it has, whether the scene owns it, whether it
## stays put while the parent moves, and which transforms it follows. Spelled once here rather than
## the same six key names written out four times over.
func _sample_child(label: String, type: String, child_count: int, scene_owned: bool,
		ignores_movement: bool, transforms: Dictionary) -> Dictionary:
	return {
		"label": label,
		"type": type,
		"child_count": child_count,
		"scene_owned": scene_owned,
		"ignores_movement": ignores_movement,
		"transforms": transforms
	}
