# Godot EventSheets - the Building rows: making, adding and keeping nodes while the game runs.
#
# Pins, by VALUE: each row's id, host, category and the lines it writes; that the two shapes of a row
# with an optional line (Add New Node with and without a name, Add Behaviour with Only one and Allow
# another) both parse as GDScript; that the type field carries the hint the dialog turns into Godot's
# Create New Node window; that Keep As Prefab says the same owner walk Save Branch As Scene File does;
# and that a row compiled in a sheet puts its lines in the event in the order Godot needs.
@tool
class_name BuildingRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "building_rows_test"
const FILE_ACES := preload("res://addons/eventforge/registration/modules/file_aces.gd")
const BUILDING := preload("res://addons/eventforge/registration/modules/building_aces.gd")

## Every row the module ships, with the host class it is offered on.
const ROWS: Dictionary = {
	"AddNewNodeInto": "Node", "AddBehaviourInto": "Node", "RemoveBehaviour": "Node",
	"AddSpriteTo": "Node2D", "AddSprite3DTo": "Node3D",
	"AddCircleShapeTo": "Node2D", "AddRectangleShapeTo": "Node2D", "AddCapsuleShapeTo": "Node2D",
	"AddSphereShapeTo": "Node3D", "AddBoxShapeTo": "Node3D", "AddCapsuleShape3DTo": "Node3D",
	"AddTimerTo": "Node", "AddToGroupSaved": "Node", "KeepAsPrefab": "Node", "RemoveBuiltNodes": "Node",
}


static func run() -> bool:
	var passed: bool = true
	passed = _the_rows_are_in_one_category() and passed
	passed = _the_lines_the_rows_write() and passed
	passed = _every_shape_of_every_row_parses() and passed
	passed = _the_type_fields_open_godots_create_node_window() and passed
	passed = _keep_as_prefab_says_the_same_walk_as_the_file_row() and passed
	passed = _a_row_in_a_sheet_writes_its_lines_in_order() and passed
	passed = _the_saved_group_is_a_different_line_from_the_plain_one() and passed
	passed = _a_tool_sheet_owns_what_it_builds() and passed
	passed = _the_dock_keeps_the_tool_lines_only_in_a_tool_sheet() and passed
	return passed


static func _descriptor(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


## The row's template as a GAME sheet writes it: the optional lines a tool sheet adds are not part of it.
static func _template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	if descriptor == null:
		return "(missing)"
	var tool_segment: RegEx = RegEx.create_from_string("\\{\\?tool=yes\\}[\\s\\S]*?\\{/tool\\}")
	return tool_segment.sub(descriptor.codegen_template, "", true)


static func _the_rows_are_in_one_category() -> bool:
	var passed: bool = true
	for ace_id: String in ROWS:
		var descriptor: ACEDescriptor = _descriptor(ace_id)
		passed = SUPPORT.pin_value(NAME, "%s exists" % ace_id, descriptor != null, true) and passed
		if descriptor == null:
			continue
		passed = SUPPORT.pin_value(NAME, "%s is filed under Building" % ace_id, descriptor.category, "Building") and passed
		passed = SUPPORT.pin_value(NAME, "%s is offered on %s" % [ace_id, ROWS[ace_id]], descriptor.node_type, ROWS[ace_id]) and passed
		passed = SUPPORT.pin_value(NAME, "%s is an action" % ace_id, descriptor.ace_type, ACEDescriptor.ACEType.ACTION) and passed
	return passed


static func _the_lines_the_rows_write() -> bool:
	return SUPPORT.pins(NAME, [
		["Add New Node makes the node, optionally names it, then adds it",
			_template("AddNewNodeInto"),
			"var {name} := {type}.new()\n{?label}{name}.name = {label}\n{/label}{parent}.add_child({name})"],
		["Remove Behaviour detaches before it frees, so a same-frame check says it is gone",
			_template("RemoveBehaviour"),
			"var __behaviour_{uid} := {target}.get_node_or_null(\"{behaviour}\")\nif __behaviour_{uid} != null:\n\t{target}.remove_child(__behaviour_{uid})\n\t__behaviour_{uid}.queue_free()"],
		["Add Sprite sets the picture before the sprite joins the tree",
			_template("AddSpriteTo"),
			"var __sprite_{uid} := Sprite2D.new()\n__sprite_{uid}.texture = {texture}\n{target}.add_child(__sprite_{uid})"],
		["Add Sprite (3D) is the same three lines with a Sprite3D",
			_template("AddSprite3DTo"),
			"var __sprite_{uid} := Sprite3D.new()\n__sprite_{uid}.texture = {texture}\n{target}.add_child(__sprite_{uid})"],
		["Add Circle Shape builds the shape, then the node that holds it",
			_template("AddCircleShapeTo"),
			"var __shape_{uid} := CollisionShape2D.new()\nvar __circle_{uid} := CircleShape2D.new()\n__circle_{uid}.radius = {radius}\n__shape_{uid}.shape = __circle_{uid}\n{target}.add_child(__shape_{uid})"],
		["Add Rectangle Shape sizes a RectangleShape2D",
			_template("AddRectangleShapeTo"),
			"var __shape_{uid} := CollisionShape2D.new()\nvar __rectangle_{uid} := RectangleShape2D.new()\n__rectangle_{uid}.size = {size}\n__shape_{uid}.shape = __rectangle_{uid}\n{target}.add_child(__shape_{uid})"],
		["Add Capsule Shape sets radius and height",
			_template("AddCapsuleShapeTo"),
			"var __shape_{uid} := CollisionShape2D.new()\nvar __capsule_{uid} := CapsuleShape2D.new()\n__capsule_{uid}.radius = {radius}\n__capsule_{uid}.height = {height}\n__shape_{uid}.shape = __capsule_{uid}\n{target}.add_child(__shape_{uid})"],
		["Add Sphere Shape (3D)",
			_template("AddSphereShapeTo"),
			"var __shape_{uid} := CollisionShape3D.new()\nvar __sphere_{uid} := SphereShape3D.new()\n__sphere_{uid}.radius = {radius}\n__shape_{uid}.shape = __sphere_{uid}\n{target}.add_child(__shape_{uid})"],
		["Add Box Shape (3D)",
			_template("AddBoxShapeTo"),
			"var __shape_{uid} := CollisionShape3D.new()\nvar __box_{uid} := BoxShape3D.new()\n__box_{uid}.size = {size}\n__shape_{uid}.shape = __box_{uid}\n{target}.add_child(__shape_{uid})"],
		["Add Capsule Shape (3D)",
			_template("AddCapsuleShape3DTo"),
			"var __shape_{uid} := CollisionShape3D.new()\nvar __capsule_{uid} := CapsuleShape3D.new()\n__capsule_{uid}.radius = {radius}\n__capsule_{uid}.height = {height}\n__shape_{uid}.shape = __capsule_{uid}\n{target}.add_child(__shape_{uid})"],
		["Add Timer starts on entering the tree and connects before it joins",
			_template("AddTimerTo"),
			"var __timer_{uid} := Timer.new()\n__timer_{uid}.wait_time = {seconds}\n__timer_{uid}.autostart = true\n__timer_{uid}.timeout.connect({callable})\n{target}.add_child(__timer_{uid})"],
		["Add To Group (Saved With Scene) passes the persistent flag",
			_template("AddToGroupSaved"), "{target}.add_to_group({group}, true)"],
	])


## The text a row writes for its DEFAULT fill, with every optional shape: `params` overrides a field.
static func _written(ace_id: String, overrides: Dictionary = {}) -> String:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	var params: Dictionary = {"uid": "0"}
	for param: ACEParam in descriptor.params:
		params[param.id] = str(param.default_value)
	for key: Variant in overrides:
		params[key] = overrides[key]
	return EventSheetActionCodegen._apply_template(descriptor.codegen_template, params)


## Whether the lines are GDScript, inside the host the row is offered on. A row that parses here is
## one a reader can drop in and run; the compile gate checks the defaults, this checks the shapes.
static func _parses(ace_id: String, lines: String) -> bool:
	var host: String = str(ROWS.get(ace_id, "Node"))
	var body: String = ""
	for line: String in lines.split("\n"):
		body += "\t" + line + "\n"
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends %s\nvar v: PackedScene\nfunc __t() -> void:\n%s" % [host, body]
	return script.reload() == OK


static func _every_shape_of_every_row_parses() -> bool:
	var passed: bool = true
	for ace_id: String in ROWS:
		passed = SUPPORT.pin_value(NAME, "%s parses with its defaults" % ace_id,
			_parses(ace_id, _written(ace_id, {"prefab": "v"} if ace_id == "KeepAsPrefab" else {})), true) and passed
	# The optional name line: both shapes.
	var unnamed: String = _written("AddNewNodeInto", {"label": ""})
	var named: String = _written("AddNewNodeInto", {"label": "\"Marker\""})
	passed = SUPPORT.pin_value(NAME, "Add New Node with a blank name writes no name line",
		unnamed, "var new_node := Node2D.new()\nget_tree().current_scene.add_child(new_node)") and passed
	passed = SUPPORT.pin_value(NAME, "Add New Node with a name writes the name before it adds",
		named, "var new_node := Node2D.new()\nnew_node.name = \"Marker\"\nget_tree().current_scene.add_child(new_node)") and passed
	passed = SUPPORT.pin_value(NAME, "the unnamed shape parses", _parses("AddNewNodeInto", unnamed), true) and passed
	passed = SUPPORT.pin_value(NAME, "the named shape parses", _parses("AddNewNodeInto", named), true) and passed
	# Add Behaviour: Only one and Allow another.
	var only_one: String = _written("AddBehaviourInto", {"behaviour": "Timer", "once": "yes"})
	var another: String = _written("AddBehaviourInto", {"behaviour": "Timer", "once": "no"})
	passed = SUPPORT.pin_value(NAME, "Add Behaviour, only one, looks before it adds and keeps the node in its variable",
		only_one, "var new_behaviour: Timer = self.get_node_or_null(\"Timer\") as Timer\nif new_behaviour == null:\n\tnew_behaviour = Timer.new()\n\tnew_behaviour.name = \"Timer\"\n\tself.add_child(new_behaviour)") and passed
	passed = SUPPORT.pin_value(NAME, "Add Behaviour, allow another, always adds a named node",
		another, "var new_behaviour := Timer.new()\nnew_behaviour.name = \"Timer\"\nself.add_child(new_behaviour)") and passed
	passed = SUPPORT.pin_value(NAME, "the only-one shape parses", _parses("AddBehaviourInto", only_one), true) and passed
	passed = SUPPORT.pin_value(NAME, "the allow-another shape parses", _parses("AddBehaviourInto", another), true) and passed
	return passed


static func _the_type_fields_open_godots_create_node_window() -> bool:
	var passed: bool = true
	var node: ACEDescriptor = _descriptor("AddNewNodeInto")
	var behaviour: ACEDescriptor = _descriptor("AddBehaviourInto")
	var removal: ACEDescriptor = _descriptor("RemoveBehaviour")
	passed = SUPPORT.pin_value(NAME, "Add New Node's type field is the node-type field", _hint_of(node, "type"), "node_type") and passed
	passed = SUPPORT.pin_value(NAME, "Add Behaviour's field is the node-type field", _hint_of(behaviour, "behaviour"), "node_type") and passed
	passed = SUPPORT.pin_value(NAME, "Remove Behaviour's field is the node-type field", _hint_of(removal, "behaviour"), "node_type") and passed
	passed = SUPPORT.pin_value(NAME, "a new node goes under the running scene by default",
		_default_of(node, "parent"), "get_tree().current_scene") and passed
	passed = SUPPORT.pin_value(NAME, "Add Behaviour offers one choice, only one, first",
		str((_param(behaviour, "once").options[0] as Dictionary).get("label", "")), "only one") and passed
	return passed


static func _param(descriptor: ACEDescriptor, param_id: String) -> ACEParam:
	for param: ACEParam in descriptor.params:
		if param.id == param_id:
			return param
	return null


static func _hint_of(descriptor: ACEDescriptor, param_id: String) -> String:
	var param: ACEParam = _param(descriptor, param_id)
	return str(param.hint) if param != null else "(missing)"


static func _default_of(descriptor: ACEDescriptor, param_id: String) -> String:
	var param: ACEParam = _param(descriptor, param_id)
	return str(param.default_value) if param != null else "(missing)"


static func _keep_as_prefab_says_the_same_walk_as_the_file_row() -> bool:
	var prefab: String = _template("KeepAsPrefab")
	var file_row: String = _template("SaveBranchAsSceneFile")
	var walk: String = FILE_ACES.owner_walk_head("{x}")
	return SUPPORT.pins(NAME, [
		["Keep As Prefab opens with the owner walk", prefab.begins_with(FILE_ACES.owner_walk_head("{node}")), true],
		["Save Branch As Scene File opens with the same walk", file_row.begins_with(FILE_ACES.owner_walk_head("{branch}")), true],
		["the walk is recursive and only adopts nodes with no owner",
			walk.contains("find_children(\"*\", \"\", true, false)") and walk.contains("if __part_{uid}.owner == null:"), true],
		["Keep As Prefab gives the ownership back after the pack",
			prefab.contains("\t__lent_{uid}.owner = null") and prefab.find("pack(") < prefab.find("__lent_{uid}.owner = null"), true],
		["Keep As Prefab reports a pack that failed", prefab.contains("push_error(\"Keep As Prefab:"), true],
	])


## The rows are written into an event the way the dock would drop them (uid baked), and compiled.
static func _a_row_in_a_sheet_writes_its_lines_in_order() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var add: ACEAction = _applied("AddNewNodeInto", {"type": "Node2D", "label": "\"Hero\"", "parent": "self", "name": "hero"})
	var shape: ACEAction = _applied("AddCircleShapeTo", {"radius": "12.0", "target": "hero"})
	event.actions.append(add)
	event.actions.append(shape)
	sheet.events.append(event)
	var output: String = SUPPORT.compile_output(sheet)
	var make_at: int = output.find("\tvar hero := Node2D.new()\n\thero.name = \"Hero\"\n\tself.add_child(hero)\n")
	var shape_at: int = output.find("\t__circle_t1.radius = 12.0\n")
	return SUPPORT.pins(NAME, [
		["the node is made, named and added", make_at >= 0, true],
		["the shape is written after the node it goes on", shape_at > make_at, true],
		["the shape is added to the node the first row named", output.contains("\thero.add_child(__shape_t1)\n"), true],
	])


static func _applied(ace_id: String, params: Dictionary) -> ACEAction:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	# What the dock bakes into a row when it is applied.
	action.codegen_template = descriptor.codegen_template.replace("{uid}", "t1")
	return action


## `add_to_group(name)` is not kept by a pack, and the saved twin is told apart by its flag alone.
static func _the_saved_group_is_a_different_line_from_the_plain_one() -> bool:
	return SUPPORT.pins(NAME, [
		["the plain row writes one argument", _template("AddToGroup"), "{target}.add_to_group({group})"],
		["the saved row writes the persistent flag", _template("AddToGroupSaved"), "{target}.add_to_group({group}, true)"],
		["the two rows are not the same template", _template("AddToGroup") != _template("AddToGroupSaved"), true],
	])


## A tool sheet's rows own what they build: the node is given the scene being edited as its owner, so it
## is saved with the scene, and a mark, so a rebuild can find it. A game sheet's row writes none of it.
static func _a_tool_sheet_owns_what_it_builds() -> bool:
	var passed: bool = true
	var raw: String = _descriptor("AddNewNodeInto").codegen_template
	passed = SUPPORT.pin_value(NAME, "the tool lines are an optional segment of the row",
		raw.contains("{?tool=yes}\nif Engine.is_editor_hint():\n\t{name}.owner = get_tree().edited_scene_root\n\t{name}.set_meta(&\"built_by_sheet\", get_script().resource_path){/tool}"), true) and passed
	passed = SUPPORT.pin_value(NAME, "a game sheet's row collapses them away",
		_written("AddNewNodeInto").contains("owner"), false) and passed
	passed = SUPPORT.pin_value(NAME, "the picker shows the row without the tool lines",
		ACEPickerDialog.without_tool_lines(raw), _template("AddNewNodeInto")) and passed
	var baked: String = BUILDING.tool_form(raw)
	passed = SUPPORT.pin_value(NAME, "a tool sheet keeps them as part of the row", baked.contains("{?tool") or baked.contains("{/tool}"), false) and passed
	var lines: String = EventSheetActionCodegen._apply_template(baked.replace("{uid}", "t1"),
		{"type": "Node2D", "label": "", "parent": "get_tree().edited_scene_root", "name": "fence"})
	passed = SUPPORT.pin_value(NAME, "and writes the owner and the mark after the node is in the tree", lines,
		"var fence := Node2D.new()\nget_tree().edited_scene_root.add_child(fence, true)\nif Engine.is_editor_hint():\n\tfence.owner = get_tree().edited_scene_root\n\tfence.set_meta(&\"built_by_sheet\", get_script().resource_path)") and passed
	passed = SUPPORT.pin_value(NAME, "that parses as GDScript", _parses("AddNewNodeInto", lines), true) and passed
	for ace_id: String in ["AddBehaviourInto", "AddSpriteTo", "AddSprite3DTo", "AddCircleShapeTo", "AddRectangleShapeTo",
			"AddCapsuleShapeTo", "AddSphereShapeTo", "AddBoxShapeTo", "AddCapsuleShape3DTo", "AddTimerTo"]:
		var row: String = _descriptor(ace_id).codegen_template
		passed = SUPPORT.pin_value(NAME, "%s has the tool segment, closed" % ace_id,
			row.contains("{?tool=yes}") and row.contains("{/tool}"), true) and passed
		var tool_lines: String = _written_tool(ace_id)
		passed = SUPPORT.pin_value(NAME, "%s in a tool sheet parses and owns what it built" % ace_id,
			tool_lines.contains(".owner = get_tree().edited_scene_root") and tool_lines.contains("set_meta(&\"built_by_sheet\", get_script().resource_path)")
			and _parses(ace_id, tool_lines), true) and passed
	var swapped: Dictionary = BUILDING.tool_params({"parent": "get_tree().current_scene", "name": "n"})
	passed = SUPPORT.pin_value(NAME, "a tool sheet builds in the scene being edited by default", swapped["parent"], "get_tree().edited_scene_root") and passed
	passed = SUPPORT.pin_value(NAME, "a parent the reader chose is left alone",
		BUILDING.tool_params({"parent": "$Level"})["parent"], "$Level") and passed
	passed = SUPPORT.pins(NAME, [
		["Remove What This Sheet Built finds the marked children",
			_template("RemoveBuiltNodes"),
			"for __built_{uid}: Node in {parent}.get_children():\n\tif __built_{uid}.has_meta(&\"built_by_sheet\") and __built_{uid}.get_meta(&\"built_by_sheet\") == get_script().resource_path:\n\t\t{parent}.remove_child(__built_{uid})\n\t\t__built_{uid}.queue_free()"],
	]) and passed
	return passed


static func _written_tool(ace_id: String) -> String:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	var params: Dictionary = {"uid": "0"}
	for param: ACEParam in descriptor.params:
		params[param.id] = str(param.default_value)
	return EventSheetActionCodegen._apply_template(BUILDING.tool_form(descriptor.codegen_template), params)


## The dock keeps the tool lines in a row dropped into a TOOL sheet, and leaves a game sheet's row alone.
static func _the_dock_keeps_the_tool_lines_only_in_a_tool_sheet() -> bool:
	var passed: bool = true
	for in_a_tool: bool in [false, true]:
		var editor: EventSheetEditor = EventSheetEditor.new()
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.tool_mode = in_a_tool
		editor.setup(sheet)
		var params: Dictionary = {"type": "Node2D", "label": "", "parent": "get_tree().current_scene", "name": "fence"}
		var action: ACEAction = editor._ace_apply._create_action_from_definition(
			editor._find_definition("Core", "AddNewNodeInto"), params)
		var label: String = "a tool sheet" if in_a_tool else "a game sheet"
		passed = SUPPORT.pin_value(NAME, "%s: the owner lines are %s" % [label, "the row's own text" if in_a_tool else "still an optional segment"],
			action.codegen_template.contains("{?tool=yes}"), not in_a_tool) and passed
		var written: String = EventSheetActionCodegen.generate_action(action, "Node2D")
		passed = SUPPORT.pin_value(NAME, "%s: the row %s the owner" % [label, "writes" if in_a_tool else "does not write"],
			written.contains(".owner = get_tree().edited_scene_root"), in_a_tool) and passed
		passed = SUPPORT.pin_value(NAME, "%s: the parent starts as %s" % [label, "the edited scene" if in_a_tool else "the running scene"],
			str(action.params.get("parent", "")), "get_tree().edited_scene_root" if in_a_tool else "get_tree().current_scene") and passed
		var part: ACEAction = editor._ace_apply._create_action_from_definition(
			editor._find_definition("Core", "AddSpriteTo"), {"texture": "load(\"res://icon.svg\")", "target": "self"})
		passed = SUPPORT.pin_value(NAME, "%s: a part row is baked the same way" % label,
			part.codegen_template.contains(".set_meta(&\"built_by_sheet\", get_script().resource_path)") and not part.codegen_template.contains("{?tool"),
			in_a_tool) and passed
		editor.free()
	return passed
