# EventForge - render harness (dev tool) for the object-first Add flow: opens the ACE
# picker with the object-cards front page (the Construct add-event gesture) so the card
# grid can be eyeballed - System first, packs as their own cards with icons. Run
# NON-headless:
#   godot --path . --script tools/render_object_first_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _picker: ACEPickerDialog = null


func _init() -> void:
	root.title = "Object-First Add"
	root.size = Vector2i(760, 580)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var registry: EventSheetACERegistry = EventSheetACERegistry.new()
		# The dock feeds the registry addon-scanned providers; mirror that so pack cards show.
		var sources: Array[Object] = []
		for script_path: String in EventSheetAddonScanner.list_addon_scripts().slice(0, 14):
			var pack_script: Script = load(script_path) as Script
			if pack_script != null and pack_script.can_instantiate():
				var instance: Object = pack_script.new()
				if instance != null:
					sources.append(instance)
		registry.refresh_from_sources(sources)
		_picker = ACEPickerDialog.new()
		_picker.init_dialog(root, registry)
		_picker.open("new_event", false, null, {"object_first": true})
		return
	if _frames < 10 or _picker == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/object-first-add.png")
	print("[preview] object-first add %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
