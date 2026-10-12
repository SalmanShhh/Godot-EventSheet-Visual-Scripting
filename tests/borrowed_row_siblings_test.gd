# Godot EventSheets - the rows that extend a row that already ships, filed beside it.
#
# Each one is a sibling of a shipped row rather than a change to it, because a shipped row's id and
# the line it writes are a promise to every project that already holds it. So this test asks four
# things of every sibling, and one of every original:
#   1. THE ROW. Its id, kind, name, page, fields, template and reading, pinned as text.
#   2. THE ORIGINAL BESIDE IT is unchanged, character for character.
#   3. WHAT THE LINE DOES. The emitted line is run, and its answer pinned as a value.
#   4. WHAT COMES BACK. A sheet holding the row is compiled, opened again the way the editor opens a
#      `.gd`, and pinned to read back as the same row and re-emit byte for byte - or, for the one row
#      whose helper is synthesized beside the class, to re-emit byte for byte as honest code.
# Then the two editor seams these rows use: the names another engine gives them find them in the
# picker, and the Ghost Row's move-children recipe writes the two shipped rows it is made of.
@tool
class_name BorrowedRowSiblingsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const RECIPES := preload("res://addons/eventsheet/editor/dock/ghost_recipes.gd")
const P := "borrowed_row_siblings_test"


static func run() -> bool:
	var ok: bool = _the_rows()
	ok = _the_originals_beside_them() and ok
	ok = _the_lines_run() and ok
	ok = _what_comes_back() and ok
	ok = _the_familiar_names() and ok
	ok = _the_move_children_recipe() and ok
	ok = _the_overlay_verbs() and ok
	return ok


## Every sibling as one line of text: id|kind|name|page|fields|template|reading.
static func _the_rows() -> bool:
	var rows: Array = []
	var expected: Dictionary = {
		"EventIsAnyPress": "condition|Event Is Any Press|Keyboard||(event.is_pressed() and not event.is_echo())|any key or button is pressed",
		"ForEachCellInRectangle": "condition|For Each Cell In Rectangle|Loops|top_left,size|range({top_left}.y, {top_left}.y + maxi({size}.y, 0)).reduce(func(__rows: Array, __y: int) -> Array: return __rows + range({top_left}.x, {top_left}.x + maxi({size}.x, 0)).map(func(__x: int) -> Vector2i: return Vector2i(__x, __y)), [])|for each cell in the [b]{size}[/b] block at [b]{top_left}[/b]",
		"PickFirstWhere": "action|Pick First Where|Nodes: Picking|name,list,item,test|var {name} = {list}.filter(func({item}): return {test}).pop_front()|pick the first of [i]{list}[/i] where {test} -> [b]{name}[/b]",
		"PickLastWhere": "action|Pick Last Where|Nodes: Picking|name,list,item,test|var {name} = {list}.filter(func({item}): return {test}).pop_back()|pick the last of [i]{list}[/i] where {test} -> [b]{name}[/b]",
		"ArrayRemoveWhere": "action|Remove Where|Variables: Array|var_name,predicate,element|{var_name}.assign({var_name}.filter(func({element}): return not ({predicate})))|remove from {var_name} where {predicate}",
		"HasBeenTrueFor": "condition|Has Been True For|Run Context|test,seconds|__true_for_{uid}({test}, {seconds})|[b]{test}[/b] has been true for [b]{seconds}[/b] seconds",
		"RescaleKeptInside": "action|Rescale (kept inside)|Math & Random|into,amount,in_low,in_high,out_low,out_high|{into} = clampf(remap({amount}, {in_low}, {in_high}, {out_low}, {out_high}), minf({out_low}, {out_high}), maxf({out_low}, {out_high}))|Rescale [i]{amount}[/i] from [i]{in_low}[/i]..[i]{in_high}[/i] to [i]{out_low}[/i]..[i]{out_high}[/i], kept inside, into [b]{into}[/b]",
		"RescaleIntoProperty": "action|Rescale Into Property|Math & Random|node,property,amount,in_low,in_high,out_low,out_high|{node}.{property} = clampf(remap({amount}, {in_low}, {in_high}, {out_low}, {out_high}), minf({out_low}, {out_high}), maxf({out_low}, {out_high}))|Rescale [i]{amount}[/i] from [i]{in_low}[/i]..[i]{in_high}[/i] to [i]{out_low}[/i]..[i]{out_high}[/i] into [i]{node}[/i]'s [b]{property}[/b]",
		"CeilWhole": "expression|Ceil (whole)|Helpers|value|ceili({value})|ceili({value})",
	}
	for ace_id: String in expected:
		rows.append([ace_id, _row_text(ace_id), expected[ace_id]])
	var loop: ACEDescriptor = ACERegistry.find_descriptor("Core", "ForEachCellInRectangle")
	rows.append(["For Each Cell In Rectangle is a real loop", loop.is_looping if loop != null else false, true])
	rows.append(["and its cells arrive as `cell`, like the radius loop's", loop.looping_iterator if loop != null else "", "cell"])
	rows.append(["Has Been True For carries its own since-when slot",
		str(ACERegistry.find_descriptor("Core", "HasBeenTrueFor").member_template).begins_with("var __truefor_{uid}: float = -1.0"), true])
	return SUPPORT.pins(P, rows)


## The rows these stand beside, as they shipped. A sibling that changed its original is a broken
## promise however good the sibling is.
static func _the_originals_beside_them() -> bool:
	return SUPPORT.pins(P, [
		["Key Pressed (event)", _template("KeyEventPressed"),
			"(event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == {key})"],
		["Cells In Rectangle", _template("CellsInRectangle"), _template("ForEachCellInRectangle")],
		["Pick Where", _template("PickWhere"), "var {name} = {list}.filter(func({item}): return {test})"],
		["Filter", _template("ArrayFilter"), "{var_name}.filter(func({element}): return {predicate})"],
		["FPS Below For", _template("FpsBelowFor"), "__fps_below_for_{uid}({fps}, {seconds})"],
		["Rescale", _template("RescaleInto"), "{into} = remap({amount}, {in_low}, {in_high}, {out_low}, {out_high})"],
		["Ceil", _template("CeilValue"), "ceil({value})"],
	])


## The lines, run. Each value is what the row promises in its own words.
static func _the_lines_run() -> bool:
	var rows: Array = []
	rows.append(["ceili(25 / 12.0) is three pages", _value(_filled("CeilWhole", {"value": "25 / 12.0"})), 3])
	rows.append(["and it is a whole number", typeof(_value(_filled("CeilWhole", {"value": "25 / 12.0"}))), TYPE_INT])
	rows.append(["a 2 by 3 block walks six cells",
		(_value(_filled("ForEachCellInRectangle", {"top_left": "Vector2i(0, 0)", "size": "Vector2i(2, 3)"})) as Array).size(), 6])
	rows.append(["the first of 1..6 over 2 is 3", _picked("PickFirstWhere", "n > 2"), 3])
	rows.append(["the last of 1..6 under 5 is 4", _picked("PickLastWhere", "n < 5"), 4])
	rows.append(["nothing passing picks null, without an error", _picked("PickLastWhere", "n > 99"), null])
	rows.append(["Remove Where takes the matches out in place", _removed("x % 2 == 0"), [1, 3, 5]])
	rows.append(["a typed array stays typed", _removed_typed(), "1,3,5|true"])
	var rescale: Dictionary = {"into": "out", "amount": "500.0", "in_low": "0.0", "in_high": "400.0", "out_low": "0.0", "out_high": "1.0"}
	rows.append(["plain Rescale overfills past its range", _assigned("RescaleInto", rescale), 1.25])
	rows.append(["kept inside, it stops at full", _assigned("RescaleKeptInside", rescale), 1.0])
	var fade: Dictionary = rescale.duplicate()
	fade["amount"] = "-100.0"
	fade["out_low"] = "1.0"
	fade["out_high"] = "0.0"
	rows.append(["a range that runs downward is kept inside too", _assigned("RescaleKeptInside", fade), 1.0])
	var held: Object = _true_for_host()
	rows.append(["a test that is not true is never true for long", held.call("check", false, 0.0), false])
	rows.append(["a test true for no time at all is true at once", held.call("check", true, 0.0), true])
	rows.append(["but not yet true for a thousand seconds", held.call("check", true, 1000.0), false])
	held.call("check", false, 0.0)
	rows.append(["a break starts the count again", held.get("__truefor_t"), -1.0])
	return SUPPORT.pins(P, rows)


## Every sibling row in a sheet, compiled and opened again.
static func _what_comes_back() -> bool:
	var rows: Array = []
	var round_trips: Dictionary = {
		"EventIsAnyPress": ["condition", "OnUnhandledInput", {}],
		"PickFirstWhere": ["action", "OnReady", {"name": "first_hurt", "list": "get_children()", "item": "one", "test": "one.visible"}],
		"PickLastWhere": ["action", "OnReady", {"name": "last_hurt", "list": "get_children()", "item": "one", "test": "one.visible"}],
		"ArrayRemoveWhere": ["action", "OnReady", {"var_name": "enemies", "predicate": "x.hp <= 0", "element": "x"}],
		"RescaleKeptInside": ["action", "OnReady", {"into": "fill", "amount": "speed", "in_low": "0.0", "in_high": "400.0", "out_low": "0.0", "out_high": "1.0"}],
		"RescaleIntoProperty": ["action", "OnReady", {"node": "$Exhaust", "property": "amount_ratio", "amount": "speed", "in_low": "0.0", "in_high": "400.0", "out_low": "0.0", "out_high": "1.0"}],
	}
	for ace_id: String in round_trips:
		var spec: Array = round_trips[ace_id]
		var source: String = _compiled(ace_id, str(spec[0]), str(spec[1]), spec[2] as Dictionary)
		rows.append(["%s reads back as itself" % ace_id, _lifted_ids(source).has(ace_id), true])
		rows.append(["%s re-emits byte for byte" % ace_id,
			SUPPORT.reemit(source, "user://borrowed_%s_roundtrip.gd" % ace_id.to_snake_case()), source])
	# The looping row lands as the event's pick filter, the way the dock lands every looping row, so
	# what comes back is that loop: the same cells, under the same name.
	var walked: String = _compiled_loop("ForEachCellInRectangle", {"top_left": "Vector2i(1, 2)", "size": "Vector2i(4, 3)"})
	rows.append(["For Each Cell In Rectangle writes a for loop over the block",
		walked.contains("for cell in range(Vector2i(1, 2).y, Vector2i(1, 2).y + maxi(Vector2i(4, 3).y, 0))"), true])
	rows.append(["it reads back as a loop over `cell`", _first_pick(walked), "cell"])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(walked, "user://borrowed_for_each_cell_rect_roundtrip.gd"), walked])
	var block: String = _filled("ForEachCellInRectangle", {"top_left": "Vector2i(1, 2)", "size": "Vector2i(4, 3)"})
	rows.append(["the loop reads as the row's sentence, not the walk",
		EventSheetSentence.cell_block_loop_words(block, "cell"), "For each cell in the Vector2i(4, 3) block at Vector2i(1, 2)"])
	rows.append(["the same walk under another name keeps its plain reading",
		EventSheetSentence.cell_block_loop_words(block, "tile"), ""])
	rows.append(["and a range that is not the walk is not read as one",
		EventSheetSentence.cell_block_loop_words("range(10)", "cell"), ""])
	# The helper this row calls is written beside the class, and no reading claims a helper back, so
	# the honest answer is the file coming back unchanged - the same answer FPS Below For gives.
	var held: String = _compiled("HasBeenTrueFor", "condition", "OnProcess", {"test": "velocity.length() < 1.0", "seconds": "2.0"})
	rows.append(["Has Been True For writes its helper", held.contains("func __true_for_t0(holds: bool, seconds: float) -> bool:"), true])
	rows.append(["and calls it with the test as written", held.contains("if __true_for_t0(velocity.length() < 1.0, 2.0):"), true])
	rows.append(["and that file re-emits byte for byte", SUPPORT.reemit(held, "user://borrowed_has_been_true_for_roundtrip.gd"), held])
	# The hand-written spelling of the any-press test, as a person types it under _unhandled_input.
	var typed: String = "extends Node\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif (event.is_pressed() and not event.is_echo()):\n\t\tprint(\"go\")\n"
	rows.append(["a hand-written any-press test reads as the row", _lifted_ids(typed).has("EventIsAnyPress"), true])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(typed, "user://borrowed_any_press_typed.gd"), typed])
	return SUPPORT.pins(P, rows)


static func _the_familiar_names() -> bool:
	return SUPPORT.pins(P, [
		["Input.anyKeyDown", ACEPickerDialog.foreign_query_matches("Input.anyKeyDown"), {"EventIsAnyPress": "Input.anyKeyDown"}],
		# "Any Key" names both jobs - the press edge and the held state - so a search holding it offers
		# the reader both rows to pick between, the longer name winning for the row it names.
		["On any key pressed", ACEPickerDialog.foreign_query_matches("on any key pressed"),
			{"EventIsAnyPress": "On any key pressed", "IsAnythingPressed": "Any Key"}],
		["Any Key finds the press and the held form", ACEPickerDialog.foreign_query_matches("any key"),
			{"EventIsAnyPress": "On any key pressed", "IsAnythingPressed": "Any Key"}],
		["each any-press row names the other", [
			str(ACERegistry.find_descriptor("Core", "EventIsAnyPress").description).contains("Anything Is Pressed"),
			str(ACERegistry.find_descriptor("Core", "IsAnythingPressed").description).contains("Event Is Any Press")], [true, true]],
		["For each XY element", ACEPickerDialog.foreign_query_matches("for each xy element"), {"ForEachCellInRectangle": "For each XY element"}],
		["FirstOrDefault", ACEPickerDialog.foreign_query_matches("FirstOrDefault"), {"PickFirstWhere": "FirstOrDefault"}],
		["FindLast", ACEPickerDialog.foreign_query_matches("FindLast"), {"PickLastWhere": "FindLast"}],
		["RemoveAll", ACEPickerDialog.foreign_query_matches("RemoveAll"), {"ArrayRemoveWhere": "RemoveAll"}],
		["Still For Seconds", ACEPickerDialog.foreign_query_matches("still for seconds"), {"HasBeenTrueFor": "Still For Seconds"}],
		["InverseLerp", ACEPickerDialog.foreign_query_matches("InverseLerp"),
			{"RescaleKeptInside": "InverseLerp", "RescaleIntoProperty": "InverseLerp"}],
		["CeilToInt", ACEPickerDialog.foreign_query_matches("CeilToInt"), {"CeilWhole": "CeilToInt"}],
		["Draw Debug Rect", ACEPickerDialog.foreign_query_matches("draw debug rect"), {"method:draw_rect": "Draw Debug Rect"}],
		["Mathf.CeilToInt reads as ceili", EventSheetForeignACEMap.translate_expression("Mathf.CeilToInt(count / 12f)"),
			{"text": "ceili(count / 12.0)", "translated": true}],
	])


static func _the_move_children_recipe() -> bool:
	var rows: Array = []
	rows.append(["the words alone offer this node's children, moved up",
		RECIPES.offer_for("move children"), {"recipe": "move_children", "from": "self", "to": "get_parent()"}])
	rows.append(["both ends can be named",
		RECIPES.offer_for("Move children of $Crate to $Level"), {"recipe": "move_children", "from": "$Crate", "to": "$Level"}])
	rows.append(["the other engine's call finds it", RECIPES.offer_for("SetParent").get("recipe", ""), "move_children"])
	rows.append(["words that are not the recipe offer nothing", RECIPES.offer_for("move child to index 2"), {}])
	rows.append(["a dangling `to` offers nothing", RECIPES.offer_for("move children to"), {}])
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var built: EventRow = RECIPES.event_for(RECIPES.offer_for("move children of $Crate to $Level"),
		registry.find_definition("Core", RECIPES.LOOP_ID), registry.find_definition("Core", RECIPES.MOVE_ID), "recipe0",
		_action_from)
	var sheet: EventSheetResource = EventSheetResource.new()
	var ready: EventRow = EventRow.new()
	ready.trigger_provider_id = "Core"
	ready.trigger_id = "OnReady"
	if built != null:
		ready.sub_events.append(built)
	sheet.events.append(ready)
	var output: String = SUPPORT.compile_output(sheet, "user://borrowed_move_children.gd")
	rows.append(["it writes For Each Child as the event's loop, the way picking it would",
		[built.pick_filters[0].collection_value, built.pick_filters[0].iterator_name] if built != null else [], ["$Crate.get_children()", "child"]])
	rows.append(["and Add Child (existing node) inside it",
		[str((built.actions[0] as ACEAction).ace_id), (built.actions[0] as ACEAction).params] if built != null else [],
		["HierarchyAddChild", {"child": "child", "parent": "$Level", "keep": ""}]])
	rows.append(["which compile to the loop a person writes",
		output.contains("for child in $Crate.get_children():\n\t\tchild.reparent($Level)"), true])
	return SUPPORT.pins(P, rows)


## The two Debug Overlay verbs, read off the pack the way the picker reads them.
static func _the_overlay_verbs() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([load("res://eventsheet_addons/debug_overlay/debug_overlay_addon.gd").new()], true)
	var found: Dictionary = {}
	for definition: ACEDefinition in registry.get_all_definitions():
		if definition.provider_id == "DebugOverlayAddon":
			found[str(definition.id)] = str(definition.metadata.get("codegen_template", ""))
	return SUPPORT.pins(P, [
		["Draw Rect ships as the autoload call", found.get("method:draw_rect", ""), "DebugOverlay.draw_rect({area}, {rect_color}, {seconds})"],
		["Draw Ray (3D) ships as the autoload call", found.get("method:draw_ray_3d", ""),
			"DebugOverlay.draw_ray_3d({origin}, {direction}, {length}, {ray_color}, {seconds})"],
		["Draw Ray is unchanged beside them", found.get("method:draw_ray", ""),
			"DebugOverlay.draw_ray({origin}, {direction}, {length}, {ray_color}, {seconds})"],
	])


# ── helpers ──────────────────────────────────────────────────────────────────────────────────


static func _row_text(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return "missing"
	var fields: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		fields.append(str(parameter.id))
	var kind: String = "expression"
	if descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
		kind = "condition"
	elif descriptor.ace_type == ACEDescriptor.ACEType.ACTION:
		kind = "action"
	return "%s|%s|%s|%s|%s|%s" % [kind, descriptor.display_name, descriptor.category, ",".join(fields),
		descriptor.codegen_template, descriptor.display_text]


static func _template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else str(descriptor.codegen_template)


## A template with the given values and every other field on its default.
static func _filled(ace_id: String, values: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var filled: Dictionary = {"uid": "t"}
	for parameter: ACEParam in descriptor.params:
		filled[str(parameter.id)] = str(parameter.default_value)
	filled.merge(values, true)
	return ActionCodegen._apply_template(descriptor.codegen_template, filled)


## Runs one expression in a throwaway script and returns its value.
static func _value(expression: String) -> Variant:
	return _run("func answer() -> Variant:\n\treturn %s\n" % expression)


static func _run(body: String) -> Variant:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\n\n%s" % body
	if script.reload() != OK:
		return "does not parse"
	var host: Object = script.new()
	return host.call("answer")


static func _picked(ace_id: String, test: String) -> Variant:
	var line: String = _filled(ace_id, {"name": "picked", "list": "[1, 2, 3, 4, 5, 6]", "item": "n", "test": test})
	return _run("func answer() -> Variant:\n\t%s\n\treturn picked\n" % line)


static func _removed(test: String) -> Variant:
	var line: String = _filled("ArrayRemoveWhere", {"var_name": "list", "predicate": test, "element": "x"})
	return _run("func answer() -> Variant:\n\tvar list: Array = [1, 2, 3, 4, 5, 6]\n\t%s\n\treturn list\n" % line)


static func _removed_typed() -> Variant:
	var line: String = _filled("ArrayRemoveWhere", {"var_name": "list", "predicate": "x % 2 == 0", "element": "x"})
	return _run("func answer() -> Variant:\n\tvar list: Array[int] = [1, 2, 3, 4, 5, 6]\n\t%s\n\treturn \"%%s|%%s\" %% [\",\".join(list.map(func(n: int) -> String: return str(n))), list.is_typed()]\n" % line)


static func _assigned(ace_id: String, values: Dictionary) -> Variant:
	return _run("var out: float = 0.0\n\n\nfunc answer() -> Variant:\n\t%s\n\treturn out\n" % _filled(ace_id, values))


## A host holding the Has Been True For helper under uid `t`, answering `check(holds, seconds)`.
static func _true_for_host() -> Object:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "HasBeenTrueFor")
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\n%s\n\n\nfunc check(holds: bool, seconds: float) -> bool:\n\treturn %s\n" % [
		str(descriptor.member_template).replace("{uid}", "t"),
		_filled("HasBeenTrueFor", {"test": "holds", "seconds": "seconds"})]
	script.reload()
	return script.new()


## One sheet holding the row under a trigger, compiled. Its template carries its uid baked as `t0`,
## the way the dock bakes one at apply time.
static func _compiled(ace_id: String, kind: String, trigger_id: String, params: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var filled: Dictionary = {}
	for parameter: ACEParam in descriptor.params:
		filled[str(parameter.id)] = str(parameter.default_value)
	filled.merge(params, true)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	if kind == "condition":
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = ace_id
		condition.params = filled
		condition.codegen_template = str(descriptor.codegen_template).replace("{uid}", "t0")
		condition.member_declaration = str(descriptor.member_template).replace("{uid}", "t0")
		event.conditions.append(condition)
		event.actions.append(_print_action())
	else:
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = ace_id
		action.params = filled
		action.codegen_template = str(descriptor.codegen_template).replace("{uid}", "t0")
		event.actions.append(action)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, "user://borrowed_%s.gd" % ace_id.to_snake_case())


static func _print_action() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = "print(\"go\")"
	return action


## The ace_ids every condition and action of a reopened source lifted to, walking sub-events too.
static func _lifted_ids(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened != null:
		for item: Variant in reopened.events:
			_collect_ids(item, found)
	return found


static func _collect_ids(item: Variant, found: PackedStringArray) -> void:
	if item is EventGroup:
		for inner: Variant in (item as EventGroup).events:
			_collect_ids(inner, found)
		return
	if not (item is EventRow):
		return
	var row: EventRow = item as EventRow
	for condition: Variant in row.conditions:
		if condition is ACECondition:
			found.append(str((condition as ACECondition).ace_id))
	for action: Variant in row.actions:
		if action is ACEAction:
			found.append(str((action as ACEAction).ace_id))
	for sub: Variant in row.sub_events:
		_collect_ids(sub, found)


## A sheet whose only event loops over a looping row's collection, the way the dock lands one.
static func _compiled_loop(ace_id: String, params: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = ActionCodegen._apply_template(descriptor.codegen_template, params)
	pick.iterator_name = descriptor.looping_iterator
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.pick_filters.append(pick)
	event.actions.append(_print_action())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, "user://borrowed_%s.gd" % ace_id.to_snake_case())


## The iterator of the first pick filter a reopened source carries, or "" when none came back.
static func _first_pick(source: String) -> String:
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened == null:
		return ""
	for item: Variant in reopened.events:
		if item is EventRow and not (item as EventRow).pick_filters.is_empty():
			return str((item as EventRow).pick_filters[0].iterator_name)
	return ""


## The dock's apply maker, in the shape the recipe takes it - enough of it for a test: the id, the
## params and the template baked onto the row.
static func _action_from(definition: ACEDefinition, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = definition.provider_id
	action.ace_id = definition.id
	action.params = params
	action.codegen_template = str(definition.metadata.get("codegen_template", ""))
	return action
