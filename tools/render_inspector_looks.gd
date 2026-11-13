# EventForge - photo harness for THE INSPECTOR LOOKS, drawn in Godot's REAL Inspector.
#
# A look is an EditorProperty, and an EditorProperty cannot be built outside a running editor, so no
# headless test can tell what one looks like next to Godot's own fields. This harness runs INSIDE an
# editor, hands each look (and each comment-line decoration) to the real Inspector on a throwaway
# object, and saves one cropped picture per look. It also prints, for every theme item the looks ask
# for, whether the running editor carries it - which is how a guessed item name gets caught.
#
# Run NON-headless AND in editor mode (a plain --script run has no editor theme at all):
#   godot --editor --path . --script tools/render_inspector_looks.gd -- out=<folder> tag=<name>
#
# The editor keeps its settings in the user's config folder, and a run must never touch them. Point
# the process at a separate config folder and say so with `config=<folder>`; the harness refuses to
# run when the editor's own config folder is not under that path. The variants:
#   dark    the default theme at 100%
#   light   config=<folder> seeded with the light colour preset (see tools/render_inspector_looks.ps1)
#   scaled  config=<folder> seeded with a custom display scale of 1.5
# A separate settings file may be seeded with `interface/theme/color_preset` and
# `interface/editor/appearance/display_scale`, which is what the wrapper script does.
@tool
extends SceneTree

const PROBE_FOLDER: String = "res://.godot/look_probe"

## Theme items the looks may ask for: [kind, name, theme type]. Printed with the editor's answer.
const THEME_PROBE: Array = [
	["stylebox", "normal", "LineEdit"], ["stylebox", "read_only", "LineEdit"],
	["stylebox", "sub_inspector_bg0", "EditorStyles"], ["stylebox", "sub_inspector_bg0", "Editor"],
	["stylebox", "prop_subsection", "Editor"], ["stylebox", "slider", "HSlider"],
	["stylebox", "grabber_area", "HSlider"], ["stylebox", "normal", "Button"],
	["stylebox", "pressed", "Button"], ["stylebox", "hover", "Button"],
	["stylebox", "normal", "OptionButton"], ["stylebox", "background", "ProgressBar"],
	["stylebox", "fill", "ProgressBar"],
	["constant", "inspector_property_height", "Editor"], ["constant", "separation", "VBoxContainer"],
	["constant", "separation", "HBoxContainer"], ["constant", "h_separation", "Button"],
	["constant", "base_scale", "Editor"], ["constant", "forced_font_size", "Editor"],
	["color", "accent_color", "Editor"], ["color", "font_color", "Editor"],
	["color", "base_color", "Editor"], ["color", "font_color", "Label"],
	["color", "font_placeholder_color", "LineEdit"], ["color", "font_disabled_color", "Editor"],
	["color", "error_color", "Editor"], ["color", "warning_color", "Editor"],
	["color", "success_color", "Editor"], ["color", "property_color_x", "Editor"],
	["color", "property_color_y", "Editor"], ["color", "property_color_z", "Editor"],
	["color", "property_color_w", "Editor"], ["color", "font_pressed_color", "Button"],
	["color", "font_hover_pressed_color", "Button"],
	["font", "font", "Label"], ["font", "bold", "EditorFonts"], ["font", "main", "EditorFonts"],
	["font_size", "font_size", "Label"], ["font_size", "bold_size", "EditorFonts"],
	["icon", "grabber", "HSlider"], ["icon", "grabber_highlight", "HSlider"],
	["icon", "Checkerboard", "EditorIcons"], ["icon", "GuiChecked", "EditorIcons"],
	["icon", "GuiCheckedDisabled", "EditorIcons"], ["icon", "Reload", "EditorIcons"],
	["icon", "Add", "EditorIcons"], ["icon", "Remove", "EditorIcons"], ["icon", "TripleBar", "EditorIcons"],
	["icon", "StatusError", "EditorIcons"], ["icon", "StatusWarning", "EditorIcons"],
	["icon", "StatusSuccess", "EditorIcons"], ["icon", "NodeInfo", "EditorIcons"],
	["icon", "Instance", "EditorIcons"], ["icon", "Unlinked", "EditorIcons"],
	["icon", "Link", "EditorIcons"], ["icon", "GuiTreeArrowDown", "EditorIcons"],
	["icon", "GuiTreeArrowRight", "EditorIcons"], ["icon", "GuiTabMenuHl", "EditorIcons"],
	["icon", "ControlAlignTopLeft", "EditorIcons"], ["icon", "ControlAlignTopRight", "EditorIcons"],
	["icon", "ControlAlignBottomLeft", "EditorIcons"], ["icon", "ControlAlignBottomRight", "EditorIcons"],
	["icon", "ArrowUp", "EditorIcons"], ["icon", "ArrowDown", "EditorIcons"],
	["icon", "Duplicate", "EditorIcons"], ["icon", "ActionCopy", "EditorIcons"],
	["icon", "ActionPaste", "EditorIcons"], ["icon", "MoveUp", "EditorIcons"],
	["icon", "MoveDown", "EditorIcons"], ["icon", "Curve", "EditorIcons"],
]

## One probe per look: the picture's name, then the script body. The look's property comes first and
## a plain twin of the same type sits under it, so the two read side by side in one picture.
const PROBES: Array = [
	["progress_bar", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:100\") var health: int = 60\n@export var health_plain: int = 60\n"],
	["swatch_row", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:swatch_row\") var team_colour: Color = Color(\"#e23b3b\")\n@export var team_colour_plain: Color = Color(\"#e23b3b\")\n"],
	["corners", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:corners\") var corner_radius: Vector4 = Vector4(8, 8, 8, 8)\n@export var corner_radius_plain: Vector4 = Vector4(8, 8, 8, 8)\n"],
	["vector_dial", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:vector_dial:150\") var wind: Vector2 = Vector2(60, -40)\n@export var wind_plain: Vector2 = Vector2(60, -40)\n"],
	["min_max", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:min_max:0:60\") var spawn_gap: Vector2 = Vector2(10, 40)\n@export var spawn_gap_plain: Vector2 = Vector2(10, 40)\n"],
	["toggle_row", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:toggle_row:easy,normal,hard\") var difficulty: String = \"normal\"\n@export var difficulty_plain: String = \"normal\"\n"],
	["action_button", "# @inspector_action reroll Reroll\n@export var seed_value: int = 7\n\n\nfunc reroll() -> void:\n\tseed_value += 1\n"],
	["required", "# @inspector_required\n@export var target_name: String = \"\"\n"],
	["note", "# @inspector_info Shared resource - edits affect every user.\n@export var shared_value: int = 3\n"],
	["checked", "# @inspector_validate check_gap\n@export var gap: int = 5\n\n\nfunc check_gap() -> String:\n\treturn \"Gap must be even.\"\n"],
	["table", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,count=int,rare=bool\") var loot: Array = [{\"item\": \"coin\", \"count\": 3, \"rare\": false}, {\"item\": \"gem\", \"count\": 1, \"rare\": true}]\n@export var loot_plain: Array = []\n"],
	["cards", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:cards:kind=kind,schema=feedback_steps,stripes=category\") var steps: Array[Dictionary] = [{\"kind\": \"shake\", \"category\": \"camera\"}, {\"kind\": \"flash\", \"category\": \"screen\"}]\n"],
	["texture_preview", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:texture_preview\") var icon_picture: Texture2D = preload(\"res://addons/eventsheet/icons/eventsheet.svg\")\n@export var icon_picture_plain: Texture2D = preload(\"res://addons/eventsheet/icons/eventsheet.svg\")\n"],
	["curve_editor", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:curve_editor\") var damage_falloff: Curve = null\n@export var damage_falloff_plain: Curve = null\n\n\nfunc _init() -> void:\n\tdamage_falloff = Curve.new()\n\tdamage_falloff.add_point(Vector2(0, 1))\n\tdamage_falloff.add_point(Vector2(1, 0))\n"],
	["unit", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:unit:kinds=px|world|screen,store=px\") var thickness: float = 2.0\n@export var thickness_plain: float = 2.0\n"],
	["heading", "# @inspector_header Combat #e06666\n@export var damage: int = 5\n@export var speed: int = 9\n"],
	["side_by_side", "# @inspector_side_by_side\n@export var margin_left: int = 4\n@export var margin_right: int = 4\n"],
	["tabs", "# @inspector_tabs\n@export_group(\"Look\")\n@export var colour: Color = Color.WHITE\n@export_group(\"Feel\")\n@export var weight: float = 1.0\n"],
]

var _out: String = ""
var _tag: String = "dark"
var _only: PackedStringArray = PackedStringArray()


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("tag="):
			_tag = arg.substr(4)
		elif arg.begins_with("only="):
			_only = arg.substr(5).split(",", false)
	_run()


func _frames(count: int) -> void:
	for step: int in count:
		await process_frame


func _run() -> void:
	await _frames(30)
	while EditorInterface.get_resource_filesystem().is_scanning():
		await _frames(5)
	await _frames(30)
	var paths: EditorPaths = EditorInterface.get_editor_paths()
	var config_dir: String = paths.get_config_dir()
	print("[looks] config folder: %s" % config_dir)
	var guard: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("config="):
			guard = arg.substr(7)
	if guard.is_empty() or not config_dir.replace("\\", "/").begins_with(guard.replace("\\", "/")):
		push_error("[looks] REFUSED: the editor's config folder is not under config=<separate folder>; its settings would be touched")
		quit(2)
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	print("[looks] preset=%s display_scale=%s custom_scale=%s editor_scale=%.2f" % [
		settings.get_setting("interface/theme/color_preset"),
		settings.get_setting("interface/editor/appearance/display_scale"),
		settings.get_setting("interface/editor/appearance/custom_display_scale"),
		EditorInterface.get_editor_scale()])
	_probe_theme()
	if _out.is_empty():
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROBE_FOLDER))
	for probe: Variant in PROBES:
		var entry: Array = probe as Array
		if not _only.is_empty() and not _only.has(str(entry[0])):
			continue
		await _photograph(str(entry[0]), str(entry[1]))
	quit(0)


func _probe_theme() -> void:
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	for item: Variant in THEME_PROBE:
		var row: Array = item as Array
		var kind: String = str(row[0])
		var item_name: String = str(row[1])
		var theme_type: String = str(row[2])
		var present: bool = false
		var detail: String = ""
		match kind:
			"stylebox":
				present = editor_theme.has_stylebox(item_name, theme_type)
				if present:
					var box: StyleBox = editor_theme.get_stylebox(item_name, theme_type)
					detail = "%s min=%s" % [box.get_class(), box.get_minimum_size()]
			"constant":
				present = editor_theme.has_constant(item_name, theme_type)
				if present:
					detail = str(editor_theme.get_constant(item_name, theme_type))
			"color":
				present = editor_theme.has_color(item_name, theme_type)
				if present:
					detail = "#" + editor_theme.get_color(item_name, theme_type).to_html()
			"font":
				present = editor_theme.has_font(item_name, theme_type)
			"font_size":
				present = editor_theme.has_font_size(item_name, theme_type)
				if present:
					detail = str(editor_theme.get_font_size(item_name, theme_type))
			"icon":
				present = editor_theme.has_icon(item_name, theme_type)
				if present:
					var icon: Texture2D = editor_theme.get_icon(item_name, theme_type)
					detail = "%dx%d" % [icon.get_width(), icon.get_height()]
		print("[theme] %-9s %-28s %-14s has=%s %s" % [kind, item_name, theme_type, present, detail])
	for variation: String in ["InspectorActionButton", "FlatButton", "FlatMenuButton", "EditorInspectorButton"]:
		print("[theme] variation %-24s has=%s" % [variation, editor_theme.get_type_variation_base(variation) != &""])
	for control_type: String in ["Button", "LineEdit", "HSlider", "ProgressBar"]:
		print("[theme] default_font_size %s=%s" % [control_type, editor_theme.get_font_size("font_size", control_type) if editor_theme.has_font_size("font_size", control_type) else "n/a"])
	print("[theme] default_base_scale=%s" % editor_theme.default_base_scale)


func _photograph(look_name: String, body: String) -> void:
	var path: String = "%s/%s.gd" % [PROBE_FOLDER, look_name]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("@tool\nextends Resource\n\n\n" + body)
	file.close()
	var script: GDScript = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
	if script == null:
		print("[looks] %s: probe script did not load" % look_name)
		return
	var subject: Resource = script.new() as Resource
	EditorInterface.inspect_object(subject)
	await _frames(24)
	var inspector: EditorInspector = EditorInterface.get_inspector()
	var image: Image = root.get_texture().get_image()
	var rect: Rect2 = inspector.get_global_rect()
	var to_pixels: Transform2D = root.get_final_transform()
	var content_height: float = _content_height(inspector)
	if OS.get_cmdline_user_args().has("debug=1"):
		image.save_png("%s/%s-full-%s.png" % [_out, _tag, look_name])
		print("[looks] inspector rect=%s root=%s image=%s visible=%s" % [rect, root.size, image.get_size(), inspector.is_visible_in_tree()])
	var top_left: Vector2 = to_pixels * rect.position
	var bottom_right: Vector2 = to_pixels * Vector2(rect.end.x, rect.position.y + minf(rect.size.y, content_height + 4.0))
	var crop: Rect2i = Rect2i(Vector2i(top_left), Vector2i(bottom_right - top_left))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image = image.get_region(crop)
	var target: String = "%s/%s-%s.png" % [_out, _tag, look_name]
	image.save_png(target)
	print("[looks] wrote %s %dx%d (content %.0f px)" % [target.get_file(), image.get_width(), image.get_height(), content_height])


## The height from the Inspector's top to where the throwaway object's own rows end, which is the top
## of the next category heading (the base class's), so a picture is not mostly empty dock.
func _content_height(inspector: EditorInspector) -> float:
	var top: float = inspector.get_global_rect().position.y
	var categories: Array = []
	var deepest: float = 0.0
	var pending: Array = [inspector]
	while not pending.is_empty():
		var node: Node = pending.pop_back() as Node
		for child: Node in node.get_children():
			var control: Control = child as Control
			if control != null and control.is_visible_in_tree():
				if control.get_class() == "EditorInspectorCategory":
					categories.append(control.get_global_rect().position.y - top)
				elif control is EditorProperty or control.get_class() == "EditorInspectorSection":
					deepest = maxf(deepest, control.get_global_rect().end.y - top)
			pending.append(child)
	categories.sort()
	if categories.size() > 1:
		return float(categories[1])
	return deepest
