# EventForge — visual probe for the Variable dialog's Tier 3 drawer picker + live preview (dev tool).
# Cycles the dialog through every drawer host type (int / Vector2 / Color / Texture2D / Curve) and saves one
# PNG per drawer, so the per-type picker and the live "what the drawer looks like" preview can be eyeballed
# for ALL five. Run NON-headless (needs a renderer):
#   godot --path . --script tools/render_variable_drawer_dialog.gd
@tool
extends SceneTree

const SPECS: Array[Dictionary] = [
	{"name": "health", "type": "int", "drawer": "progress_bar", "range": {"min": "0", "max": "100", "step": "1"}, "file": "progress_bar"},
	{"name": "aim_direction", "type": "Vector2", "drawer": "vector_dial", "range": {"min": "0", "max": "150", "step": "1"}, "file": "vector_dial"},
	{"name": "team_tint", "type": "Color", "drawer": "swatch_row", "range": {}, "file": "swatch_row"},
	{"name": "sprite", "type": "Texture2D", "drawer": "texture_preview", "range": {}, "file": "texture_preview"},
	{"name": "damage_falloff", "type": "Curve", "drawer": "curve_editor", "range": {}, "file": "curve_editor"},
]

var _index: int = 0
var _frames: int = 0
var _dlg: VariableDialog = null

func _init() -> void:
	root.title = "Variable Dialog — drawer gallery"
	root.size = Vector2i(620, 680)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#202024")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_dlg = VariableDialog.new()
	_dlg.init_dialog(root)
	_dlg.set_sheet_provider(func() -> Variant: return null)
	process_frame.connect(_on_frame)

func _open(spec: Dictionary) -> void:
	var attrs: Dictionary = {"drawer": spec["drawer"]}
	if not (spec["range"] as Dictionary).is_empty():
		attrs["range"] = spec["range"]
	var default_value: Variant = _default_for(str(spec["type"]))
	_dlg.open_for_edit(
		"tree",
		{"editing": true, "attributes": attrs},
		str(spec["name"]), str(spec["type"]), default_value, false,
		"Variable — %s drawer" % str(spec["drawer"]), false, true
	)

func _default_for(type_name: String) -> Variant:
	match type_name:
		"int":
			return 50
		"Vector2":
			return Vector2(0.0, 0.0)
		"Color":
			return Color.WHITE
		_:
			return null

func _on_frame() -> void:
	_frames += 1
	if _frames == 3:
		_open(SPECS[_index])
	elif _frames == 13:
		var image: Image = root.get_texture().get_image()
		var path: String = "res://_drawer_dlg_%d_%s.png" % [_index, str(SPECS[_index]["file"])]
		image.save_png(path)
		print("[drawer_dialog_gallery] saved %s" % path)
		_index += 1
		if _index >= SPECS.size():
			quit(0)
			return
		_frames = 0
