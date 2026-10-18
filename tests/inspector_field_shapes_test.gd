# Godot EventSheets - four shapes a field can take in the Inspector, written both ways.
#
#   * Show when / Read-only when another bool is on: the bool's setter refreshes the Inspector, one
#     _validate_property hides or greys the field, and Godot only asks it of a @tool script - so a
#     sheet that is not one is told;
#   * Groups as tabs: `# @inspector_tabs`, one tab per @export_group, plain headings without the plugin;
#   * Side by side: `# @inspector_side_by_side` before the first of a pair of numbers, drawn as one line;
#   * Pick from a list a function gives: `# @inspector_choices <function>`, a dropdown of the words the
#     script's function returns, silent and plain when the script is not a @tool script.
#
# Each one compiles to the lines the design shows, opens back as the same choice, saves back byte for
# byte, and leaves a script that runs in a project without the plugin.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P: String = "inspector_field_shapes_test"
const DRAWERS_PATH: String = "res://addons/eventsheet/editor/attribute_drawers.gd"
const OBJECT_DECOR_PATH: String = "res://addons/eventsheet/editor/inspector/object_decor.gd"
const WIDGETS_PATH: String = "res://addons/eventsheet/editor/drawer_widgets.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _shapes_compile() and ok
	ok = _shapes_open_back() and ok
	ok = _decor_reads_the_shapes() and ok
	ok = _tabs_follow_the_groups() and ok
	ok = _choices_come_from_the_function() and ok
	ok = _show_when_runs_without_the_plugin() and ok
	ok = _shaped_script_runs_without_the_plugin() and ok
	return ok


static func _row(var_name: String, type_name: String, value: Variant, attributes: Dictionary) -> LocalVariable:
	var row: LocalVariable = LocalVariable.new()
	row.name = var_name
	row.type_name = type_name
	row.default_value = value
	row.exported = true
	row.attributes = attributes
	return row


## The enemy stats of the design, with every new shape on it. A group line opens a group until the
## next one, so only the first variable of each names it, as the design's file does.
static func _enemy_stats(tool_sheet: bool = true) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = tool_sheet
	sheet.host_class = "Resource"
	sheet.events.append(_row("max_health", "int", 100, {"group": "Stats", "tabs": true}))
	sheet.events.append(_row("min_damage", "int", 4, {"side_by_side": true}))
	sheet.events.append(_row("max_damage", "int", 9, {}))
	sheet.events.append(_row("has_shield", "bool", true, {}))
	sheet.events.append(_row("shield_amount", "int", 3, {"show_if": "has_shield"}))
	sheet.events.append(_row("attack", "String", "slash", {"choices_function": "attack_names"}))
	sheet.events.append(_row("drop_row", "int", 1, {"group": "Loot"}))
	var names: RawCodeRow = RawCodeRow.new()
	names.code = "func attack_names() -> PackedStringArray:\n\treturn [\"slash\", \"lunge\", \"spin\"]"
	sheet.events.append(names)
	return sheet


static func _shapes_compile() -> bool:
	var result: Dictionary = SheetCompiler.compile(_enemy_stats(), "user://eventsheets_field_shapes.gd")
	var output: String = str(result.get("output", ""))
	var plain: Dictionary = SheetCompiler.compile(_enemy_stats(false), "user://eventsheets_field_shapes_plain.gd")
	return SUPPORT.pins(P, [
		["tabs ride above the first group line",
			output.contains("# @inspector_tabs\n@export_group(\"Stats\")\n@export var max_health: int = 100\n"), true],
		["side by side sits before the first of the pair",
			output.contains("# @inspector_side_by_side\n@export var min_damage: int = 4\n@export var max_damage: int = 9\n"), true],
		["the choices name the function that gives them",
			output.contains("# @inspector_choices attack_names\n@export var attack: String = \"slash\"\n"), true],
		["the bool a Show when reads refreshes the Inspector",
			output.contains("@export var has_shield: bool = true:\n\tset(value):\n\t\thas_shield = value\n\t\tnotify_property_list_changed()\n"), true],
		["one _validate_property hides the field",
			output.count("func _validate_property(property: Dictionary) -> void:\n\tif str(property.name) == \"shield_amount\" and not bool(has_shield):\n\t\tproperty.usage &= ~PROPERTY_USAGE_EDITOR\n"), 1],
		["a @tool sheet has nothing to be told", result.get("warnings"), []],
		["any other sheet is told the Show when needs @tool", plain.get("warnings"),
			["Show if / Lock unless need a @tool sheet to work in the Inspector - enable Tool in the Sheet Type dialog."]],
	])


## The design's own file, typed by hand, opens as the same choices and saves back byte for byte.
static func _design_file() -> String:
	return "@tool\nextends Resource\n\n# @inspector_tabs\n@export_group(\"Stats\")\n@export var max_health: int = 100\n" \
		+ "# @inspector_side_by_side\n@export var min_damage: int = 4\n@export var max_damage: int = 9\n" \
		+ "# @inspector_choices attack_names\n@export var attack: String = \"slash\"\n@export_group(\"Loot\")\n" \
		+ "@export var drop_row: int = 1\n\nfunc attack_names() -> PackedStringArray:\n\treturn [\"slash\", \"lunge\", \"spin\"]\n"


static func _shapes_open_back() -> bool:
	var output: String = SUPPORT.compile_output(_enemy_stats(), "user://eventsheets_field_shapes.gd")
	var rows: Dictionary = _rows(SUPPORT.reopen(output))
	var design: String = _design_file()
	var design_rows: Dictionary = _rows(SUPPORT.reopen(design))
	# A marker that names no function is not the shape: it stays the comment it is.
	var broken: String = design.replace("# @inspector_choices attack_names", "# @inspector_choices attack names")
	return SUPPORT.pins(P, [
		["tabs open back onto their variable", _attribute(rows, "max_health", "tabs"), true],
		["side by side opens back onto the first of the pair", _attribute(rows, "min_damage", "side_by_side"), true],
		["the second of the pair carries nothing", _attribute(rows, "max_damage", "side_by_side"), null],
		["the choices open back with their function", _attribute(rows, "attack", "choices_function"), "attack_names"],
		["the Show when opens back too", _attribute(rows, "shield_amount", "show_if"), "has_shield"],
		["the compiled file saves back byte for byte", SUPPORT.reemit(output, "user://eventsheets_field_shapes_again.gd"), output],
		["the hand-typed file opens as the same tabs", _attribute(design_rows, "max_health", "tabs"), true],
		["and the same pair", _attribute(design_rows, "min_damage", "side_by_side"), true],
		["and the same choices", _attribute(design_rows, "attack", "choices_function"), "attack_names"],
		["the hand-typed file saves back byte for byte", SUPPORT.reemit(design, "user://eventsheets_field_shapes_design.gd"), design],
		["a marker naming no function saves back as it was", SUPPORT.reemit(broken, "user://eventsheets_field_shapes_broken.gd"), broken],
		["and is no choice", _attribute(_rows(SUPPORT.reopen(broken)), "attack", "choices_function"), null],
	])


static func _decor_reads_the_shapes() -> bool:
	var drawers: GDScript = load(DRAWERS_PATH)
	var map: Dictionary = drawers.build_decor_map(_design_file())
	var target: Object = _load_design(true).new()
	return SUPPORT.pins(P, [
		["the tabs line is read", map.get("max_health"), [{"kind": "tabs"}]],
		["the first of the pair knows the second", map.get("min_damage"), [{"kind": "side_by_side", "second": "max_damage"}]],
		["the second knows the first", map.get("max_damage"), [{"kind": "side_by_side_second", "first": "min_damage"}]],
		["the choices name their function", map.get("attack"), [{"kind": "choices", "function": "attack_names"}]],
		["a field with no marker carries nothing", map.has("drop_row"), false],
		["the tabs belong to the whole object", bool(load(OBJECT_DECOR_PATH).parse(_design_file()).get("tabs")), true],
		["two numbers share a line", drawers.side_by_side_fits(target, "min_damage", "max_damage"), true],
		["a number and a word do not", drawers.side_by_side_fits(target, "max_health", "attack"), false],
		["a field that is not there does not", drawers.side_by_side_fits(target, "max_damage", "armour"), false],
		["a pair never reaches across a group line",
			drawers.build_decor_map("# @inspector_side_by_side
@export var max_damage: int = 9
@export_group(\"Loot\")
@export var drop_row: int = 1
"),
			{"max_damage": [{"kind": "side_by_side", "second": ""}]}],
		["...nor across a subgroup line",
			drawers.build_decor_map("# @inspector_side_by_side
@export var max_damage: int = 9
@export_subgroup(\"Drops\")
@export var drop_row: int = 1
"),
			{"max_damage": [{"kind": "side_by_side", "second": ""}]}],
	])


static func _tabs_follow_the_groups() -> bool:
	var object_decor: GDScript = load(OBJECT_DECOR_PATH)
	var target: Object = _load_design(true).new()
	var shown_first: Array = [object_decor.chosen_tab(target), object_decor.hidden_by_tabs(target, "attack"),
		object_decor.hidden_by_tabs(target, "drop_row")]
	object_decor.choose_tab(target, "Loot")
	var shown_after: Array = [object_decor.chosen_tab(target), object_decor.hidden_by_tabs(target, "attack"),
		object_decor.hidden_by_tabs(target, "drop_row")]
	var prefixed: Array = [
		{"name": "enemy.gd", "usage": PROPERTY_USAGE_CATEGORY},
		{"name": "lead", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "Bullet", "usage": PROPERTY_USAGE_GROUP, "hint_string": "bullet_"},
		{"name": "bullet_speed", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "Trail", "usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""},
		{"name": "bullet_trail", "usage": PROPERTY_USAGE_DEFAULT},
		{"name": "after", "usage": PROPERTY_USAGE_DEFAULT},
	]
	return SUPPORT.pins(P, [
		["one tab per group, in order", object_decor.tab_groups(target), PackedStringArray(["Stats", "Loot"])],
		["the first tab shows first, hiding the other group", shown_first, ["Stats", false, true]],
		["picking a tab swaps what hides", shown_after, ["Loot", true, false]],
		["a prefix group holds only its names, subgroups included",
			object_decor.read_groups(prefixed).get("group_of"), {"bullet_speed": "Bullet", "bullet_trail": "Bullet"}],
		["a heading with nothing drawn under it is hidden; one holding a plugin's own control is not",
			[_holds_nothing(null), _holds_nothing(Label.new()), _holds_nothing(ColorRect.new())], [true, false, false]],
	])


## A heading as Godot builds one - its column, a subgroup's heading inside it - holding `content`.
static func _holds_nothing(content: Control) -> bool:
	var heading: Control = Control.new()
	var column: VBoxContainer = VBoxContainer.new()
	heading.add_child(column)
	var subgroup: VBoxContainer = VBoxContainer.new()
	column.add_child(subgroup)
	if content != null:
		subgroup.add_child(content)
	var answer: bool = load(WIDGETS_PATH).GroupTabs.holds_nothing(heading)
	heading.free()
	return answer


static func _choices_come_from_the_function() -> bool:
	var widgets: GDScript = load(WIDGETS_PATH)
	var tool_target: Object = _load_design(true).new()
	var plain_target: Object = _load_design(false).new()
	var field: OptionButton = widgets.ChoicesField.new("attack_names")
	field.call("show_choices", tool_target, "lunge")
	var listed: Array = [field.item_count, field.get_item_text(0), field.get_item_text(field.selected)]
	field.call("show_choices", tool_target, "slahs")
	var kept: Array = [field.item_count, field.get_item_text(field.selected), field.get_item_tooltip(field.selected)]
	# An Inspector refresh with nothing changed leaves the list as it is, so an open list stays open.
	field.set_item_text(0, "untouched")
	field.call("show_choices", tool_target, "slahs")
	var refreshed: String = field.get_item_text(0)
	field.call("show_choices", tool_target, "spin")
	var refilled: Array = [field.get_item_text(0), field.get_item_text(field.selected)]
	field.free()
	return SUPPORT.pins(P, [
		["a @tool script with the function is asked", widgets.ChoicesField.can_ask(tool_target, "attack_names"), true],
		["any other script is left as Godot's plain field", widgets.ChoicesField.can_ask(plain_target, "attack_names"), false],
		["a function it does not have is not asked", widgets.ChoicesField.can_ask(tool_target, "level_names"), false],
		["a list of words is the choices", widgets.ChoicesField.read_choices(PackedStringArray(["a", "b"])), [["a", ""], ["b", ""]]],
		["a Dictionary gives each word its sentence", widgets.ChoicesField.read_choices({"slash": "A wide cut."}), [["slash", "A wide cut."]]],
		["anything else is no choices", widgets.ChoicesField.read_choices(3), []],
		["the dropdown lists the words and picks the value", listed, [3, "slash", "lunge"]],
		["a word the list no longer has stays, marked", kept, [4, "slahs", "Not one of the words attack_names() gives."]],
		["a refresh that changes nothing does not refill the list", refreshed, "untouched"],
		["...and a new value does", refilled, ["slash", "spin"]],
	])


## Show when, run as plain Godot: no plugin anywhere, only the script's own _validate_property.
static func _show_when_runs_without_the_plugin() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Resource"
	sheet.events.append(_row("has_shield", "bool", false, {}))
	sheet.events.append(_row("shield_amount", "int", 3, {"show_if": "has_shield"}))
	sheet.events.append(_row("block_chance", "float", 0.5, {"lock_unless": "has_shield"}))
	var target: Object = _load_source(SUPPORT.compile_output(sheet, "user://eventsheets_show_when.gd"), "user://eventsheets_show_when_run.gd").new()
	var off: Array = [_shown(target, "shield_amount"), _read_only(target, "block_chance")]
	target.set("has_shield", true)
	var on: Array = [_shown(target, "shield_amount"), _read_only(target, "block_chance")]
	return SUPPORT.pins(P, [
		["while the bool is off the field is hidden and the other greyed", off, [false, true]],
		["once it is on both are back", on, [true, false]],
		["the value is kept while hidden", target.get("shield_amount"), 3],
	])


## The shaped script, as a project without the plugin has it: it names no class of this plugin, it
## loads, and its fields and its function are the plain ones.
static func _shaped_script_runs_without_the_plugin() -> bool:
	var output: String = SUPPORT.compile_output(_enemy_stats(), "user://eventsheets_field_shapes.gd")
	var plugin_classes: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("path", "")).begins_with("res://addons/"):
			plugin_classes.append(str(entry.get("class", "")))
	var named: PackedStringArray = PackedStringArray()
	for line: String in output.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		for class_name_text: String in plugin_classes:
			if line.contains(class_name_text) and not named.has(class_name_text):
				named.append(class_name_text)
	var target: Object = _load_source(output, "user://eventsheets_field_shapes_run.gd").new()
	return SUPPORT.pins(P, [
		["the code names no class of the plugin", named, PackedStringArray()],
		["the fields hold their plain values",
			[target.get("max_health"), target.get("min_damage"), target.get("max_damage"), target.get("attack")], [100, 4, 9, "slash"]],
		["the function runs as written", target.call("attack_names"), PackedStringArray(["slash", "lunge", "spin"])],
		["every field still shows, under Godot's own group headings",
			[_shown(target, "max_health"), _shown(target, "min_damage"), _shown(target, "attack"), _shown(target, "drop_row")],
			[true, true, true, true]],
	])


static func _rows(sheet: EventSheetResource) -> Dictionary:
	var rows: Dictionary = {}
	if sheet != null:
		for entry: Variant in sheet.events:
			if entry is LocalVariable:
				rows[(entry as LocalVariable).name] = entry
	return rows


static func _attribute(rows: Dictionary, var_name: String, key: String) -> Variant:
	var row: LocalVariable = rows.get(var_name) as LocalVariable
	if row == null:
		return "<missing %s>" % var_name
	return (row.attributes as Dictionary).get(key) if row.attributes is Dictionary else null


static func _load_design(tool_script: bool) -> GDScript:
	var source: String = _design_file() if tool_script else _design_file().trim_prefix("@tool\n")
	return _load_source(source, "user://eventsheets_field_shapes_%s.gd" % ("tool" if tool_script else "plain"))


## A real file, loaded: a script built from a string in memory has no path and no source to read decor
## from, so it would prove nothing about the editor's reading.
static func _load_source(source: String, path: String) -> GDScript:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as GDScript


static func _usage(target: Object, property: String) -> int:
	for entry: Dictionary in target.get_property_list():
		if str(entry.get("name", "")) == property:
			return int(entry.get("usage", 0))
	return -1


static func _shown(target: Object, property: String) -> bool:
	var usage: int = _usage(target, property)
	return usage >= 0 and (usage & PROPERTY_USAGE_EDITOR) != 0


static func _read_only(target: Object, property: String) -> bool:
	return (_usage(target, property) & PROPERTY_USAGE_READ_ONLY) != 0
