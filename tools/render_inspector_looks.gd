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
	["color", "dark_color_1", "Editor"], ["color", "dark_color_2", "Editor"], ["color", "dark_color_3", "Editor"],
	["color", "property_color", "Editor"], ["color", "bottom_editor", "EditorProperty"], ["stylebox", "bottom_editor", "EditorProperty"],
	["stylebox", "child_bg", "EditorProperty"], ["color", "warning_color", "EditorProperty"],
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
	["checked_edited", "# @inspector_validate check_gap\n@export var gap: int = 5\n\n\nfunc _init() -> void:\n\tgap = 8\n\n\nfunc check_gap() -> String:\n\treturn \"Gap must be even.\"\n"],
	["required", "# @inspector_required\n@export var target_name: String = \"\"\n"],
	["note", "# @inspector_info Shared resource - edits affect every user.\n@export var shared_value: int = 3\n"],
	["checked", "# @inspector_validate check_gap\n@export var gap: int = 5\n\n\nfunc check_gap() -> String:\n\treturn \"Gap must be even.\"\n"],
	["table", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,count=int,rare=bool\") var loot: Array = [{\"item\": \"coin\", \"count\": 3, \"rare\": false}, {\"item\": \"gem\", \"count\": 1, \"rare\": true}]\n@export var loot_plain: Array = []\n"],
	["table_weighted", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float,tags=String:weight=weight\") var entries: Array = [{\"item\": \"coin\", \"weight\": 50.0, \"tags\": \"common\"}, {\"item\": \"gem\", \"weight\": 25.0, \"tags\": \"rare\"}, {\"item\": \"sword\", \"weight\": 5.0, \"tags\": \"rare,weapon\"}]
@export var entries_plain: Array = []
"],
	["table_rolled", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float,tags=String:weight=weight\") var entries: Array = [{\"item\": \"coin\", \"weight\": 50.0, \"tags\": \"common\"}, {\"item\": \"gem\", \"weight\": 25.0, \"tags\": \"rare\"}, {\"item\": \"sword\", \"weight\": 5.0, \"tags\": \"rare,weapon\"}]
"],
	["table_tag", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float,tags=String\") var entries: Array = [{\"item\": \"coin\", \"weight\": 50.0, \"tags\": \"common\"}, {\"item\": \"gem\", \"weight\": 25.0, \"tags\": \"rare\"}]
@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table_tag:entries:tags\") var pity_tag: String = \"rare\"
@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table_tag:entries:tags\") var missing_tag: String = \"epic\"
@export var pity_tag_plain: String = \"rare\"
"],
	["cards", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:cards:kind=kind,schema=feedback_steps,stripes=category\") var steps: Array[Dictionary] = [{\"kind\": \"shake\", \"category\": \"camera\"}, {\"kind\": \"flash\", \"category\": \"screen\"}]\n"],
	["texture_preview", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:texture_preview\") var icon_picture: Texture2D = preload(\"res://addons/eventsheet/icons/eventsheet.svg\")\n@export var icon_picture_plain: Texture2D = preload(\"res://addons/eventsheet/icons/eventsheet.svg\")\n"],
	["curve_editor", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:curve_editor\") var damage_falloff: Curve = null\n@export var damage_falloff_plain: Curve = null\n\n\nfunc _init() -> void:\n\tdamage_falloff = Curve.new()\n\tdamage_falloff.add_point(Vector2(0, 1))\n\tdamage_falloff.add_point(Vector2(1, 0))\n"],
	["unit", "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:unit:kinds=px|world|screen,store=px\") var thickness: float = 2.0\n@export var thickness_plain: float = 2.0\n"],
	["heading", "# @inspector_header Combat #e06666\n@export var damage: int = 5\n@export var speed: int = 9\n"],
	["side_by_side", "# @inspector_side_by_side\n@export var margin_left: int = 4\n@export var margin_right: int = 4\n"],
	["tabs", "# @inspector_tabs\n@export_group(\"Look\")\n@export var colour: Color = Color.WHITE\n@export_group(\"Feel\")\n@export var weight: float = 1.0\n"],
]

## The shipped packs, photographed through their own scripts: [picture name, script path, values set
## after it is built]. The path is the pack under eventsheet_addons (never the library copy, which
## sits in an ignored folder the editor does not load).
const PACK_PROBES: Array = [
	["pack_loot_table", "res://eventsheet_addons/loot_table_resource/loot_table_resource.gd", {"entries": [{"item": "coin", "weight": 50.0, "tags": "common"}, {"item": "gem", "weight": 25.0, "tags": "rare"}, {"item": "sword", "weight": 5.0, "tags": "rare,weapon"}], "pity_tag": "rare"}],
	["pack_random_table", "res://eventsheet_addons/random_table_resource/random_table_resource.gd", {"entries": [{"value": "north", "weight": 3.0}, {"value": "south", "weight": 1.0}]}],
	["pack_advanced_random", "res://eventsheet_addons/advanced_random/advanced_random_addon.gd", {}],
	["pack_drawing_canvas", "res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd", {}],
	# The Feedback Player is a pack too; its fourth card is unfolded by index (the fourth entry).
	["pack_feedback_player", "res://eventsheet_addons/juice/feedback_player.gd", {"steps": [
		{"verb": "punch_scale", "seconds": 0.3}, {"verb": "hold", "seconds": 0.1},
		{"verb": "shake", "seconds": 0.2}, {"verb": "loop_back", "seconds": 0.25, "loops": 2, "to_hold": true, "to_loop_start": true}]}, 3],
]

var _out: String = ""
var _tag: String = "dark"
var _only: PackedStringArray = PackedStringArray()
var _width: int = 0
var _width_tag: String = ""


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("tag="):
			_tag = arg.substr(4)
		elif arg.begins_with("width="):
			_width = int(arg.substr(6))
			_width_tag = "-w%d" % _width
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
	if _width > 0:
		_set_inspector_width(float(_width))
		await _frames(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROBE_FOLDER))
	for probe: Variant in PROBES:
		var entry: Array = probe as Array
		if not _only.is_empty() and not _only.has(str(entry[0])):
			continue
		await _photograph(str(entry[0]), str(entry[1]))
	for pack: Variant in PACK_PROBES:
		var pack_entry: Array = pack as Array
		if not _only.is_empty() and not _only.has(str(pack_entry[0])):
			continue
		var pack_script: GDScript = ResourceLoader.load(str(pack_entry[1]), "", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
		if pack_script == null:
			print("[looks] %s: pack script did not load" % str(pack_entry[0]))
			continue
		var pack_subject: Object = pack_script.new()
		for key: Variant in (pack_entry[2] as Dictionary):
			var current: Variant = pack_subject.get(str(key))
			if current is Array:
				# A typed array refuses a plain one; assign converts the rows.
				(current as Array).assign((pack_entry[2] as Dictionary)[key])
			else:
				pack_subject.set(str(key), (pack_entry[2] as Dictionary)[key])
		await _photograph_subject(str(pack_entry[0]), pack_subject, int(pack_entry[3]) if pack_entry.size() > 3 else -1)
		if pack_subject is Node:
			(pack_subject as Node).free()
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
	var prop_names: Array = []
	for info: Dictionary in ClassDB.class_get_property_list("EditorProperty", true):
		prop_names.append(info["name"])
	print("[theme] EditorProperty props=%s methods=%s" % [prop_names, ClassDB.class_get_method_list("EditorProperty", true).map(func(m: Dictionary) -> String: return m["name"])])
	for kind_name: String in ["EditorProperty", "EditorInspectorSection", "EditorInspector"]:
		print("[theme] %s styleboxes=%s colors=%s constants=%s" % [kind_name, editor_theme.get_stylebox_list(kind_name), editor_theme.get_color_list(kind_name), editor_theme.get_constant_list(kind_name)])


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
	await _photograph_subject(look_name, subject)


func _photograph_subject(look_name: String, subject: Object, unfold_card: int = -1) -> void:
	EditorInterface.inspect_object(subject)
	await _frames(24)
	var inspector: EditorInspector = EditorInterface.get_inspector()
	if look_name.ends_with("_rolled"):
		for button: Variant in inspector.find_children("*", "Button", true, false):
			if (button as Button).text.begins_with("Roll"):
				(button as Button).pressed.emit()
		await _frames(8)
	if unfold_card >= 0:
		var lists: Array = inspector.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node.get_script() != null and str(node.get_script().get_global_name()) == "EventSheetCardListDrawer")
		for list: Variant in lists:
			(list as Object).set("_unfolded", {unfold_card: true})
			(list as Object).call("_rebuild")
		await _frames(12)
	var image: Image = root.get_texture().get_image()
	var rect: Rect2 = inspector.get_global_rect()
	var to_pixels: Transform2D = root.get_final_transform()
	var content_height: float = _content_height(inspector)
	print("[looks] inspector width now %.0f" % inspector.size.x)
	if OS.get_cmdline_user_args().has("debug=1"):
		image.save_png("%s/%s-full-%s.png" % [_out, _tag, look_name])
		print("[looks] inspector rect=%s root=%s image=%s visible=%s" % [rect, root.size, image.get_size(), inspector.is_visible_in_tree()])
	var top_left: Vector2 = to_pixels * rect.position
	var bottom_right: Vector2 = to_pixels * Vector2(rect.end.x, rect.position.y + minf(rect.size.y, content_height + 4.0))
	var crop: Rect2i = Rect2i(Vector2i(top_left), Vector2i(bottom_right - top_left))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image = image.get_region(crop)
	var target: String = "%s/%s%s-%s.png" % [_out, _tag, _width_tag, look_name]
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


## Moves the split beside the Inspector dock until the Inspector is about `target` wide (in the
## editor's own units), so a look can be photographed narrow and wide as well as at the default.
func _set_inspector_width(target: float) -> void:
	var inspector: Control = EditorInterface.get_inspector()
	var split: SplitContainer = null
	var node: Node = inspector.get_parent()
	while node != null:
		if node is SplitContainer and not (node as SplitContainer).vertical:
			split = node as SplitContainer
			break
		node = node.get_parent()
	if split == null:
		print("[looks] no split found beside the Inspector; width stays")
		return
	var offsets: PackedInt32Array = split.split_offsets
	print("[looks] split offsets %s (%s)" % [offsets, split.name])
	if offsets.is_empty():
		return
	offsets[offsets.size() - 1] += int(inspector.size.x - target)
	split.split_offsets = offsets
	print("[looks] asked for width %.0f, Inspector was %.0f" % [target, inspector.size.x])
