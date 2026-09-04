# Godot EventSheets - Inspector sections that unfold, fields that link, and corners in one number.
#
# Three pieces of Inspector chrome, pinned by VALUE:
#   * a show-if scoped to a whole @export_group - it rides as a plain `# @inspector_show_if` comment
#     directly above the group line (the one place a per-field annotation cannot reach, since
#     @export_group takes no hint string) and compiles to the SAME _validate_property the per-field
#     Show If compiles, once per member;
#   * `# @inspector_link a b` - two neighbouring numbers tied by an equals button. Editor-only decor:
#     it emits no code at all, so a project without the plugin simply has two ordinary numbers;
#   * the corners drawer - a Vector4 read clockwise from the top-left, as one number until the four
#     differ. The same shape margins and padding take.
#
# Every one of them must survive the round trip: opening generated GDScript as a sheet and saving it
# untouched reproduces the file byte for byte.
@tool
class_name InspectorSectionsAndLinksTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P: String = "inspector_sections_and_links_test"


static func run() -> bool:
	var ok: bool = true
	ok = _group_show_if() and ok
	ok = _link_decor() and ok
	ok = _corners_drawer() and ok
	return ok


# ── A show-if that scopes a whole group ─────────────────────────────────────
static func _group_show_if() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"dashed": {"type": "bool", "default": false, "exported": true, "attributes": {}},
		"dash_count": {"type": "int", "default": 16, "exported": true,
			"attributes": {"group": "Dashes", "group_show_if": "dashed"}},
		"dash_spacing": {"type": "float", "default": 4.0, "exported": true,
			"attributes": {"group": "Dashes", "group_show_if": "dashed"}}
	}
	var output: String = SUPPORT.compile_output(sheet, "user://eventsheets_group_show_if.gd")
	var marker_at: int = output.find("# @inspector_show_if dashed")
	var group_at: int = output.find("@export_group(\"Dashes\")")
	var ok: bool = SUPPORT.pins(P, [
		["the group carries the show-if comment", marker_at >= 0, true],
		["the comment sits directly above the group line", output.contains("# @inspector_show_if dashed\n@export_group(\"Dashes\")"), true],
		["one comment, not one per member", output.count("# @inspector_show_if dashed"), 1],
		["the marker precedes the group line", marker_at >= 0 and marker_at < group_at, true],
		# The hiding itself is the ordinary validate-property the per-field form emits - once per
		# member, which is what "the whole group hides" means to Godot.
		["the first member hides with the group", output.contains("\tif str(property.name) == \"dash_count\" and not bool(dashed):"), true],
		["the second member hides with the group", output.contains("\tif str(property.name) == \"dash_spacing\" and not bool(dashed):"), true],
		["it hides rather than locks", output.count("property.usage &= ~PROPERTY_USAGE_EDITOR"), 2],
		["nothing is locked read-only", output.contains("property.usage |= PROPERTY_USAGE_READ_ONLY"), false]
	])

	# A group show-if on a variable that is in no group has no group to scope: no comment, no code.
	var ungrouped: EventSheetResource = EventSheetResource.new()
	ungrouped.variables = {
		"dashed": {"type": "bool", "default": false, "exported": true, "attributes": {}},
		"width": {"type": "float", "default": 1.0, "exported": true, "attributes": {"group_show_if": "dashed"}}
	}
	var ungrouped_output: String = SUPPORT.compile_output(ungrouped, "user://eventsheets_group_show_if_none.gd")
	ok = SUPPORT.pins(P, [
		["no group means no comment", ungrouped_output.contains("# @inspector_show_if"), false],
		["no group means no validate-property", ungrouped_output.contains("_validate_property"), false]
	]) and ok

	# The decor parser reads the comment as a GROUP scope: every member below the group line carries
	# it, and a variable after the next group line does not.
	var source: String = "extends Node\n\n@export var dashed: bool = false\n# @inspector_show_if dashed\n@export_group(\"Dashes\")\n@export var dash_count: int = 16\n\n@export var dash_spacing: float = 4.0\n@export_group(\"Colour\")\n@export var tint: Color = Color(1, 1, 1, 1)\n"
	var decor_map: Dictionary = EventSheetAttributeDrawers.build_decor_map(source)
	ok = SUPPORT.pins(P, [
		["the first member of the group is scoped", decor_map.get("dash_count", []), [{"kind": "group_show_if", "predicate": "dashed"}]],
		["a blank line does not end the group", decor_map.get("dash_spacing", []), [{"kind": "group_show_if", "predicate": "dashed"}]],
		["the next group replaces the scope", decor_map.get("tint", []), []],
		["the variable above the group is untouched", decor_map.get("dashed", []), []]
	]) and ok

	# A group line consumes the show-if and NOTHING else: the header the canonical emission writes
	# above the group still belongs to the variable underneath it.
	var headed: String = "extends Node\n\n@export var dashed: bool = false\n# @inspector_header Dashes\n# @inspector_show_if dashed\n@export_group(\"Dashes\")\n@export var dash_count: int = 16\n"
	ok = SUPPORT.pins(P, [
		["a header above the group line still reaches its variable",
			EventSheetAttributeDrawers.build_decor_map(headed).get("dash_count", []),
			[{"kind": "group_show_if", "predicate": "dashed"}, {"kind": "header", "text": "Dashes", "color": ""}]]
	]) and ok

	# Round trip: a tree variable carrying the group scope re-emits byte for byte, and reopens with
	# the scope recovered as an editable attribute rather than a stray comment block.
	var lifted: EventSheetResource = SUPPORT.reopen(source)
	var lifted_count: LocalVariable = _find(lifted, "dash_count")
	ok = SUPPORT.pins(P, [
		["the group scope reopens as an attribute",
			(lifted_count.attributes as Dictionary).get("group_show_if", "") if lifted_count != null else "<missing>", "dashed"],
		["the group itself reopens too",
			(lifted_count.attributes as Dictionary).get("group", "") if lifted_count != null else "<missing>", "Dashes"],
		["the file re-emits byte for byte", SUPPORT.reemit(source, "user://eventsheets_group_show_if_roundtrip.gd"), source]
	]) and ok
	return ok


# ── One edit, one step ──────────────────────────────────────────────────────
## A followed edit goes through the editor's own undo manager and moves BOTH numbers in one step, so
## taking the edit back takes the follower back with it. Written against a plain UndoRedo, which is
## what the manager is duck-typed for.
static func _followed_edit_is_one_step() -> bool:
	var target: Object = _pair_object()
	var undo_redo: UndoRedo = UndoRedo.new()
	var wrote: bool = EventSheetDrawerWidgets.LinkToggle.commit_link(undo_redo, target, "count", 8, 16, "spacing", 2.0, 4.0)
	var after: String = "%s|%s" % [str(target.get("count")), str(target.get("spacing"))]
	undo_redo.undo()
	var undone: String = "%s|%s" % [str(target.get("count")), str(target.get("spacing"))]
	var ok: bool = SUPPORT.pins(P, [
		["a followed edit writes a step", wrote, true],
		["the pair lands where the ratio puts it", after, "16|4.0"],
		["one undo puts BOTH numbers back", undone, "8|2.0"],
		["a follower that did not move writes no step at all",
			EventSheetDrawerWidgets.LinkToggle.commit_link(undo_redo, target, "count", 8, 16, "spacing", 2.0, 2.0), false],
		["with no undo manager there is no step to write",
			EventSheetDrawerWidgets.LinkToggle.commit_link(null, target, "count", 8, 16, "spacing", 2.0, 4.0), false]
	])

	# THE READER'S ONE GESTURE. The Inspector writes its own step for the number that was dragged;
	# the tie JOINS that step instead of following it with a second, so the history holds one entry
	# and both Ctrl+Z and Ctrl+Y move the pair together (a second entry meant redo brought the
	# leader back on its own, with the follower left behind).
	var gesture_target: Object = _pair_object()
	var gesture: UndoRedo = UndoRedo.new()
	gesture.create_action("Set count", UndoRedo.MERGE_ENDS)
	gesture.add_do_property(gesture_target, "count", 16)
	gesture.add_undo_property(gesture_target, "count", 8)
	gesture.commit_action()
	EventSheetDrawerWidgets.LinkToggle.commit_link(gesture, gesture_target, "count", 8, 16, "spacing", 2.0, 4.0)
	var linked: String = "%s|%s" % [str(gesture_target.get("count")), str(gesture_target.get("spacing"))]
	gesture.undo()
	var taken_back: String = "%s|%s" % [str(gesture_target.get("count")), str(gesture_target.get("spacing"))]
	gesture.redo()
	var brought_back: String = "%s|%s" % [str(gesture_target.get("count")), str(gesture_target.get("spacing"))]
	ok = SUPPORT.pins(P, [
		["one gesture is one entry in the history", gesture.get_history_count(), 1],
		["under the name the editor gave the reader's own edit", gesture.get_current_action_name(), "Set count"],
		["the gesture leaves the pair where the ratio puts it", linked, "16|4.0"],
		["one undo takes the WHOLE gesture back", taken_back, "8|2.0"],
		["and one redo brings the whole gesture back", brought_back, "16|4.0"],
		["a step named for some other edit is not joined",
			EventSheetDrawerWidgets.LinkToggle.merge_target_name(gesture, gesture_target, "spacing"), ""],
		["a manager holding no step at all has nothing to join",
			EventSheetDrawerWidgets.LinkToggle.merge_target_name(null, gesture_target, "count"), ""],
		["a follower a hair from where it already is is where it already is",
			EventSheetDrawerWidgets.LinkToggle.same_value(2.0, 2.0 + 0.000000001), true],
		["two whole numbers apart are not",
			EventSheetDrawerWidgets.LinkToggle.same_value(2, 3), false]
	]) and ok
	gesture.clear_history()
	gesture.free()

	# UndoRedo is an Object, not a RefCounted: clearing the history drops what it holds, and freeing
	# it is what keeps the run's exit-time leak count at zero.
	undo_redo.clear_history()
	undo_redo.free()
	return ok


## A pair of numbers on a scriptless-looking object: one whole, one not, which is the pair the tie
## is usually drawn between (a dash count and its spacing).
static func _pair_object() -> Object:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\n\nvar count: int = 8\nvar spacing: float = 2.0\n"
	script.reload()
	return script.new()


# ── Two numbers kept in a ratio ─────────────────────────────────────────────
static func _link_decor() -> bool:
	# The ratio, by value: it is what the follower is worth per unit of the leader, read at the
	# moment the two are linked, and it works in both directions afterwards.
	var ok: bool = SUPPORT.pins(P, [
		["a ratio of four to one", EventSheetDrawerWidgets.LinkToggle.link_ratio(4.0, 16.0), 4.0],
		["a ratio under one", EventSheetDrawerWidgets.LinkToggle.link_ratio(16.0, 4.0), 0.25],
		["a leader of zero keeps the pair as it is", EventSheetDrawerWidgets.LinkToggle.link_ratio(0.0, 9.0), 1.0],
		["the follower moves with the leader", EventSheetDrawerWidgets.LinkToggle.link_follow(4.0, 5.0), 20.0],
		["the leader moves with the follower", EventSheetDrawerWidgets.LinkToggle.link_lead(4.0, 20.0), 5.0],
		["a ratio of zero leaves the leader where it is", EventSheetDrawerWidgets.LinkToggle.link_lead(0.0, 7.0), 7.0],
		["a whole-number property is written a whole number", EventSheetDrawerWidgets.LinkToggle.matched_type(3, 4.6), 5],
		["a number property is written the number itself", EventSheetDrawerWidgets.LinkToggle.matched_type(3.0, 4.6), 4.6]
	])
	ok = _followed_edit_is_one_step() and ok

	# Emission: the decor names BOTH fields, this one first, and it is the LAST decor line - closest
	# to the variable it belongs to.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"dash_count": {"type": "int", "default": 16, "exported": true,
			"attributes": {"info": "How many dashes go round.", "link_with": "dash_spacing"}},
		"dash_spacing": {"type": "float", "default": 4.0, "exported": true, "attributes": {}}
	}
	var output: String = SUPPORT.compile_output(sheet, "user://eventsheets_link_decor.gd")
	ok = SUPPORT.pins(P, [
		["the link names both fields, leader first", output.contains("# @inspector_link dash_count dash_spacing"), true],
		["the link sits closest to the variable", output.contains("# @inspector_info How many dashes go round.\n# @inspector_link dash_count dash_spacing\n@export var dash_count: int = 16"), true],
		# Comment-only: the decor is chrome, and chrome never reaches the running game.
		["it emits no code of its own", output.contains("_validate_property"), false],
		["a link to itself is not a link",
			SUPPORT.compile_output(_one_var_sheet("width", "link_with", "width"), "user://eventsheets_link_self.gd").contains("# @inspector_link"), false],
		["a link to a non-identifier is refused",
			SUPPORT.compile_output(_one_var_sheet("width", "link_with", "not a name"), "user://eventsheets_link_bad.gd").contains("# @inspector_link"), false]
	]) and ok

	# Round trip: the decor reopens as the editable attribute, and the file re-emits byte for byte.
	var source: String = "extends Node\n\n# @inspector_link dash_count dash_spacing\n@export var dash_count: int = 16\n@export var dash_spacing: float = 4.0\n"
	var lifted: EventSheetResource = SUPPORT.reopen(source)
	var lifted_count: LocalVariable = _find(lifted, "dash_count")
	var decor_map: Dictionary = EventSheetAttributeDrawers.build_decor_map(source)
	ok = SUPPORT.pins(P, [
		["the link reopens as an attribute",
			(lifted_count.attributes as Dictionary).get("link_with", "") if lifted_count != null else "<missing>", "dash_spacing"],
		["the file re-emits byte for byte", SUPPORT.reemit(source, "user://eventsheets_link_roundtrip.gd"), source],
		["the decor parser binds the link to the first field",
			decor_map.get("dash_count", []), [{"kind": "link", "first": "dash_count", "second": "dash_spacing"}]],
		["the partner carries nothing of its own", decor_map.get("dash_spacing", []), []]
	]) and ok
	return ok


# ── Four corners in one number ──────────────────────────────────────────────
static func _corners_drawer() -> bool:
	var ok: bool = SUPPORT.pins(P, [
		["the marker rides a Vector4 export",
			_emit_for("Vector4", Vector4(8.0, 8.0, 8.0, 8.0), {"drawer": "corners"}),
			"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:corners\") var v: Vector4 = Vector4(8.0, 8.0, 8.0, 8.0)"],
		["another type gets no marker", _emit_for("float", 8.0, {"drawer": "corners"}).contains("eventsheet:"), false],
		["the hint reads back as the drawer",
			EventSheetAttributeDrawers.parse_drawer_hint("eventsheet:corners").get("drawer", ""), "corners"],
		["the look knows which type it is for",
			EventSheetInspectorLooks.preset_by_id("corners").get("types", []), ["Vector4"]]
	])

	# Read and write: one number is four corners; four different corners open the four boxes and
	# every one of them keeps its own value.
	var widget: EventSheetDrawerWidgets.DrawerCorners = EventSheetDrawerWidgets.DrawerCorners.new()
	widget.set_value(EventSheetDrawerWidgets.DrawerCorners.uniform(8.0))
	var uniform_value: Vector4 = widget.get_value()
	var uniform_folded: bool = widget.is_expanded()
	widget.set_value(Vector4(1.0, 2.0, 3.0, 4.0))
	ok = SUPPORT.pins(P, [
		["one number is all four corners", uniform_value, Vector4(8.0, 8.0, 8.0, 8.0)],
		["one number needs no boxes", uniform_folded, false],
		["four corners are kept as four", widget.get_value(), Vector4(1.0, 2.0, 3.0, 4.0)],
		["corners that differ open the boxes by themselves", widget.is_expanded(), true],
		["clockwise from the top-left",
			EventSheetDrawerWidgets.DrawerCorners.CORNER_CELLS,
			[["Top-left", 0], ["Top-right", 1], ["Bottom-left", 3], ["Bottom-right", 2]]],
		["four the same is uniform", EventSheetDrawerWidgets.DrawerCorners.is_uniform(Vector4(2.0, 2.0, 2.0, 2.0)), true],
		["one corner apart is not", EventSheetDrawerWidgets.DrawerCorners.is_uniform(Vector4(2.0, 2.0, 2.0, 5.0)), false]
	]) and ok
	widget.free()

	# Round trip: the marker reopens as an editable drawer and the file comes back byte for byte.
	var source: String = "extends Node\n\n@export_custom(PROPERTY_HINT_NONE, \"eventsheet:corners\") var corner_radius: Vector4 = Vector4(8.0, 8.0, 8.0, 8.0)\n"
	var lifted: LocalVariable = _find(SUPPORT.reopen(source), "corner_radius")
	ok = SUPPORT.pins(P, [
		["the marker reopens as the drawer",
			(lifted.attributes as Dictionary).get("drawer", "") if lifted != null else "<missing>", "corners"],
		["the file re-emits byte for byte", SUPPORT.reemit(source, "user://eventsheets_corners_roundtrip.gd"), source]
	]) and ok
	return ok


## One exported sheet variable carrying one attribute - the shape the refusal pins need.
static func _one_var_sheet(var_name: String, attribute_key: String, attribute_value: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {var_name: {"type": "float", "default": 1.0, "exported": true,
		"attributes": {attribute_key: attribute_value}}}
	return sheet


## The emitted declaration line for one tree variable with the given attributes.
static func _emit_for(type_name: String, default_value: Variant, attributes: Dictionary) -> String:
	var local_var: LocalVariable = LocalVariable.new()
	local_var.name = "v"
	local_var.type_name = type_name
	local_var.default_value = default_value
	local_var.exported = true
	local_var.attributes = attributes
	return SheetCompiler._emit_tree_variable_line(local_var)


static func _find(sheet: EventSheetResource, var_name: String) -> LocalVariable:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == var_name:
			return entry as LocalVariable
	return null
