# EventSheet - the Self expression section census (SPEC-self-expressions Phase 1).
# Pins the derived model VALUES (never counts): the C3 alias table's fragments, the host gating,
# the variables census, the expression-only function filter, and the query scoping. All static +
# pure - no dialog, no editor.
@tool
class_name SelfExpressionsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── Properties: the alias table under host gating ────────────────────────────────────
	var body_2d: Array = EventSheetSelfExpressions.property_entries("CharacterBody2D")
	all_passed = _check("Node2D-family host: X inserts position.x", _fragment_for(body_2d, "X"), "position.x") and all_passed
	all_passed = _check("Node2D-family host: Angle inserts rotation", _fragment_for(body_2d, "Angle"), "rotation") and all_passed
	all_passed = _check("Node2D-family host: Opacity inserts modulate.a", _fragment_for(body_2d, "Opacity"), "modulate.a") and all_passed
	all_passed = _check("Node2D-family host has no Width (that is Control's)", _fragment_for(body_2d, "Width"), "") and all_passed

	var control: Array = EventSheetSelfExpressions.property_entries("Control")
	all_passed = _check("Control host: Width inserts size.x", _fragment_for(control, "Width"), "size.x") and all_passed
	all_passed = _check("Control host: X inserts position.x", _fragment_for(control, "X"), "position.x") and all_passed
	all_passed = _check("Control host: Opacity inserts modulate.a", _fragment_for(control, "Opacity"), "modulate.a") and all_passed

	var node_3d: Array = EventSheetSelfExpressions.property_entries("CharacterBody3D")
	all_passed = _check("Node3D-family host: Z inserts position.z", _fragment_for(node_3d, "Z"), "position.z") and all_passed
	all_passed = _check("Node3D-family host has NO Angle (rotation is a Vector3 there)", _fragment_for(node_3d, "Angle"), "") and all_passed

	var bare_node: Array = EventSheetSelfExpressions.property_entries("Node")
	all_passed = _check("bare Node host: no X", _fragment_for(bare_node, "X"), "") and all_passed
	all_passed = _check("bare Node host: UID survives (Object-level)", _fragment_for(bare_node, "UID"), "get_instance_id()") and all_passed

	# A custom class_name host resolves through the global class list to its engine base.
	var custom: Array = EventSheetSelfExpressions.property_entries("CanvasSurface")
	all_passed = _check("custom class host resolves to its engine base (UID present)", _fragment_for(custom, "UID"), "get_instance_id()") and all_passed
	# An unresolvable host degrades to Object: only the Object-level commons remain.
	var unresolvable: Array = EventSheetSelfExpressions.property_entries("NoSuchClassAnywhere")
	all_passed = _check("unresolvable host keeps only Object commons", _fragment_for(unresolvable, "X"), "") and all_passed
	all_passed = _check("unresolvable host still offers UID", _fragment_for(unresolvable, "UID"), "get_instance_id()") and all_passed

	# ── Variables: dict + tree census, bare-name fragments ───────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {"health": {"type": "int"}}
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "combo"
	tree_var.type_name = "int"
	sheet.events.append(tree_var)
	var variables: Array = EventSheetSelfExpressions.variable_entries(sheet)
	all_passed = _check("dict variable inserts its bare name", _fragment_for(variables, "health"), "health") and all_passed
	all_passed = _check("tree variable inserts its bare name", _fragment_for(variables, "combo"), "combo") and all_passed

	# ── Functions: expression role only, call fragment carries the param names ───────────
	var dps: EventFunction = EventFunction.new()
	dps.function_name = "dps"
	dps.return_type = TYPE_FLOAT
	sheet.functions.append(dps)
	var damage_after: EventFunction = EventFunction.new()
	damage_after.function_name = "damage_after"
	damage_after.return_type = TYPE_INT
	var armor_param: ACEParam = ACEParam.new()
	armor_param.id = "armor"
	armor_param.name = "armor"
	damage_after.params.append(armor_param)
	sheet.functions.append(damage_after)
	var is_ready_check: EventFunction = EventFunction.new()
	is_ready_check.function_name = "is_ready_check"
	is_ready_check.return_type = TYPE_BOOL
	sheet.functions.append(is_ready_check)
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.return_type = TYPE_NIL
	sheet.functions.append(heal)
	var functions: Array = EventSheetSelfExpressions.function_entries(sheet)
	all_passed = _check("float function is an expression entry", _fragment_for(functions, "dps"), "dps()") and all_passed
	all_passed = _check("params ride the call fragment", _fragment_for(functions, "damage_after"), "damage_after(armor)") and all_passed
	all_passed = _check("bool function is a CONDITION, not listed", _fragment_for(functions, "is_ready_check"), "") and all_passed
	all_passed = _check("void function is an ACTION, not listed", _fragment_for(functions, "heal"), "") and all_passed

	# ── Query scoping: the C3 "type Self. and browse" reflex ─────────────────────────────
	var scoped: Dictionary = EventSheetSelfExpressions.normalize_query("Self.X")
	all_passed = _check("Self.X is self-scoped", bool(scoped.get("self_scoped")), true) and all_passed
	all_passed = _check("Self.X remainder is x", str(scoped.get("remainder")), "x") and all_passed
	all_passed = _check("bare self is self-scoped, empty remainder",
		EventSheetSelfExpressions.normalize_query("sELF"), {"self_scoped": true, "remainder": ""}) and all_passed
	all_passed = _check("a plain query is not self-scoped",
		EventSheetSelfExpressions.normalize_query("position"), {"self_scoped": false, "remainder": "position"}) and all_passed

	# Matching covers BOTH spellings: the C3 label and the GDScript fragment.
	var x_entry: Dictionary = {"label": "X · position.x", "fragment": "position.x"}
	all_passed = _check("query x matches the C3 label", EventSheetSelfExpressions.entry_matches(x_entry, "x"), true) and all_passed
	all_passed = _check("query position matches the fragment", EventSheetSelfExpressions.entry_matches(x_entry, "position"), true) and all_passed
	all_passed = _check("query angle does not match X", EventSheetSelfExpressions.entry_matches(x_entry, "angle"), false) and all_passed

	# ── Resource-host sheet: variables work, no node commons ─────────────────────────────
	var resource_sheet: EventSheetResource = EventSheetResource.new()
	resource_sheet.host_class = "Resource"
	resource_sheet.variables = {"max_stack": {"type": "int"}}
	var resource_section: Dictionary = EventSheetSelfExpressions.section_for(resource_sheet, "Resource")
	all_passed = _check("resource host: variable census works", _fragment_for(resource_section.get("variables", []), "max_stack"), "max_stack") and all_passed
	all_passed = _check("resource host: no X", _fragment_for(resource_section.get("properties", []), "X"), "") and all_passed
	all_passed = _check("resource host: UID remains (Object-level)", _fragment_for(resource_section.get("properties", []), "UID"), "get_instance_id()") and all_passed

	# ══ Phase 2 ══════════════════════════════════════════════════════════════════════════

	# ── The Host subgroup: behaviour mode re-aims the commons through the host binding ───
	var behaviour_sheet: EventSheetResource = EventSheetResource.new()
	behaviour_sheet.host_class = "CharacterBody2D"
	behaviour_sheet.behavior_mode = true
	var host_entries: Array = EventSheetSelfExpressions.section_for(behaviour_sheet, "CharacterBody2D").get("host", [])
	all_passed = _check("behaviour mode: Host X inserts host.position.x", _fragment_for(host_entries, "X"), "host.position.x") and all_passed
	all_passed = _check("plain sheet has NO Host subgroup", (EventSheetSelfExpressions.section_for(sheet, "CharacterBody2D").get("host", []) as Array).is_empty(), true) and all_passed

	# ── The robust transform + the retarget span (pure) ──────────────────────────────────
	all_passed = _check("robust: simple chain", EventSheetSelfExpressions.robust_fragment("$Sine.amplitude"), "get_node_or_null(\"Sine\").amplitude") and all_passed
	all_passed = _check("robust: pathed node token kept whole", EventSheetSelfExpressions.robust_fragment("$Player/Sine.amplitude"), "get_node_or_null(\"Player/Sine\").amplitude") and all_passed
	all_passed = _check("robust: bare node ref", EventSheetSelfExpressions.robust_fragment("$Sine"), "get_node_or_null(\"Sine\")") and all_passed
	all_passed = _check("robust: non-$ passes through", EventSheetSelfExpressions.robust_fragment("position.x"), "position.x") and all_passed
	all_passed = _check("retarget span: $ chain selects the node token", EventSheetSelfExpressions.retarget_span("$SineBehavior.magnitude"), Vector2i(0, 13)) and all_passed
	all_passed = _check("retarget span: robust form selects the quoted name", EventSheetSelfExpressions.retarget_span("get_node_or_null(\"SineBehavior\").magnitude"), Vector2i(18, 12)) and all_passed
	all_passed = _check("retarget span: plain fragment selects nothing", EventSheetSelfExpressions.retarget_span("position.x"), Vector2i(-1, 0)) and all_passed

	# ── Spawn-heavy detection (values, incl. nested rows) ────────────────────────────────
	var spawner: EventSheetResource = EventSheetResource.new()
	spawner.host_class = "Node2D"
	var outer: EventRow = EventRow.new()
	var inner: EventRow = EventRow.new()
	var spawn_action: ACEAction = ACEAction.new()
	spawn_action.provider_id = "Core"
	spawn_action.ace_id = "SpawnSceneAt"
	spawn_action.codegen_template = "x"
	inner.actions.append(spawn_action)
	outer.sub_events.append(inner)
	spawner.events.append(outer)
	all_passed = _check("SpawnSceneAt in a SUB-event marks the sheet spawn-heavy", EventSheetSelfExpressions.is_spawn_heavy(spawner), true) and all_passed
	all_passed = _check("a plain sheet is not spawn-heavy", EventSheetSelfExpressions.is_spawn_heavy(sheet), false) and all_passed

	# ── Behaviours: a REAL pack through the REAL registry (annotations read from disk) ───
	var sine_instance: Node = (load("res://eventsheet_addons/sine/sine_behavior.gd") as GDScript).new()
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([sine_instance], false)
	var user_sheet: EventSheetResource = EventSheetResource.new()
	user_sheet.host_class = "Node2D"
	var use_row: EventRow = EventRow.new()
	var use_action: ACEAction = ACEAction.new()
	use_action.provider_id = "SineBehavior"
	use_action.ace_id = "SetMagnitude"
	use_action.codegen_template = "x"
	use_row.actions.append(use_action)
	user_sheet.events.append(use_row)
	var groups: Array = EventSheetSelfExpressions.behaviour_groups(user_sheet, registry, false)
	var sine_group: Dictionary = _group_of(groups, "SineBehavior")
	all_passed = _check("the pack publishes a behaviour group", sine_group.is_empty(), false) and all_passed
	all_passed = _check("a knob reads as an attached-child chain", _fragment_for(sine_group.get("entries", []), "Magnitude"), "$SineBehavior.magnitude") and all_passed
	all_passed = _check("the sheet that calls the pack marks it used", bool(sine_group.get("used")), true) and all_passed
	var unused_groups: Array = EventSheetSelfExpressions.behaviour_groups(sheet, registry, false)
	all_passed = _check("a sheet that never calls it marks it unused", bool(_group_of(unused_groups, "SineBehavior").get("used")), false) and all_passed
	var robust_groups: Array = EventSheetSelfExpressions.behaviour_groups(user_sheet, registry, true)
	all_passed = _check("robust mode transforms every fragment", _fragment_for(_group_of(robust_groups, "SineBehavior").get("entries", []), "Magnitude"), "get_node_or_null(\"SineBehavior\").magnitude") and all_passed
	sine_instance.free()

	# ── Scale: the census paths that run per KEYSTROKE, against project-sized inputs ─────
	all_passed = _scale_checks() and all_passed

	return all_passed


## The refresh path re-derives the section on every keystroke, so it must stay flat against a
## project-sized registry (all bundled packs) and a large sheet (hundreds of rows + variables).
## Budgets are deliberately loose (CI machines vary); the point is catching an accidental
## O(packs x rows) coupling, not micro-benchmarks.
static func _scale_checks() -> bool:
	var all_passed: bool = true
	# Every bundled pack, reflected for real - the registry the editor actually carries.
	var sources: Array[Object] = []
	for pack_dir: String in DirAccess.get_directories_at("res://eventsheet_addons"):
		for file: String in DirAccess.get_files_at("res://eventsheet_addons/" + pack_dir):
			if not file.ends_with(".gd"):
				continue
			var script: GDScript = load("res://eventsheet_addons/%s/%s" % [pack_dir, file]) as GDScript
			if script == null or not script.can_instantiate():
				continue
			var instance: Object = script.new()
			if instance != null:
				sources.append(instance)
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources(sources, false)
	all_passed = _check("scale: the full pack fleet reflects (>= 60 providers)",
		registry.get_reflected_provider_ids().size() >= 60, true) and all_passed
	# A project-sized sheet: 300 events, 150 variables, 40 functions, deep nesting.
	var big: EventSheetResource = EventSheetResource.new()
	big.host_class = "CharacterBody2D"
	for i: int in range(150):
		big.variables["var_%d" % i] = {"type": "int"}
	for i: int in range(40):
		var fn: EventFunction = EventFunction.new()
		fn.function_name = "calc_%d" % i
		fn.return_type = TYPE_FLOAT
		big.functions.append(fn)
	for i: int in range(300):
		var row: EventRow = EventRow.new()
		var action: ACEAction = ACEAction.new()
		action.provider_id = "SineBehavior" if i % 7 == 0 else "Core"
		action.ace_id = "SetMagnitude" if i % 7 == 0 else "Print"
		action.codegen_template = "x"
		row.actions.append(action)
		var sub: EventRow = EventRow.new()
		sub.actions.append(action.duplicate())
		row.sub_events.append(sub)
		big.events.append(row)
	var started: int = Time.get_ticks_usec()
	var groups: Array = []
	for _pass: int in range(20):  # twenty keystrokes' worth of refresh
		var section: Dictionary = EventSheetSelfExpressions.section_for(big, "CharacterBody2D")
		groups = EventSheetSelfExpressions.behaviour_groups(big, registry, false)
		all_passed = (section.get("variables", []) as Array).size() == 150 and all_passed
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	all_passed = _check("scale: correctness holds (150 vars, 40 fns, groups found)",
		groups.size() >= 60 and bool(_group_of(groups, "SineBehavior").get("used")), true) and all_passed
	all_passed = _check("scale: 20 refreshes over 300 rows x full fleet stay under 2000ms (took %.0fms)" % elapsed_ms,
		elapsed_ms < 2000.0, true) and all_passed
	for source: Object in sources:
		if source is Node:
			(source as Node).free()
	return all_passed


static func _group_of(groups: Array, provider: String) -> Dictionary:
	for group: Variant in groups:
		if group is Dictionary and str((group as Dictionary).get("provider")) == provider:
			return group as Dictionary
	return {}


## The fragment of the entry whose label STARTS with the given C3 name / variable name ("" when
## absent) - value-pinning helper. The separator is " · " for aliases, " : " for typed variables.
static func _fragment_for(entries: Array, label_head: String) -> String:
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var label: String = str((entry as Dictionary).get("label", ""))
		var head: String = label.split(" · ")[0].split(" : ")[0].replace("ƒ ", "").split("(")[0].strip_edges()
		if head == label_head:
			return str((entry as Dictionary).get("fragment", ""))
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] self_expressions_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
