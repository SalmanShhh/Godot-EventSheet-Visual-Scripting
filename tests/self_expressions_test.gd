# EventSheet - the Self expression section census (Self section, Phase 1).
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
	var machinery: LocalVariable = LocalVariable.new()
	machinery.name = "__live_values_timer"
	machinery.type_name = "float"
	sheet.events.append(machinery)
	var variables: Array = EventSheetSelfExpressions.variable_entries(sheet)
	all_passed = _check("dict variable inserts its bare name", _fragment_for(variables, "health"), "health") and all_passed
	all_passed = _check("tree variable inserts its bare name", _fragment_for(variables, "combo"), "combo") and all_passed
	all_passed = _check("emitted machinery (__ prefix) never joins the census", _fragment_for(variables, "__live_values_timer"), "") and all_passed

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
	var groups: Array = EventSheetSelfExpressions.behaviour_groups(user_sheet, false)
	var sine_group: Dictionary = _group_of(groups, "SineBehavior")
	all_passed = _check("the pack publishes a behaviour group", sine_group.is_empty(), false) and all_passed
	all_passed = _check("a knob reads as an attached-child chain", _fragment_for(sine_group.get("entries", []), "Magnitude"), "$SineBehavior.magnitude") and all_passed
	all_passed = _check("the sheet that calls the pack marks it used", bool(sine_group.get("used")), true) and all_passed
	var unused_groups: Array = EventSheetSelfExpressions.behaviour_groups(sheet, false)
	all_passed = _check("a sheet that never calls it marks it unused", bool(_group_of(unused_groups, "SineBehavior").get("used")), false) and all_passed
	var robust_groups: Array = EventSheetSelfExpressions.behaviour_groups(user_sheet, true)
	all_passed = _check("robust mode transforms every fragment", _fragment_for(_group_of(robust_groups, "SineBehavior").get("entries", []), "Magnitude"), "get_node_or_null(\"SineBehavior\").magnitude") and all_passed
	sine_instance.free()

	# ══ Phase 3: the grounded tier ═══════════════════════════════════════════════════════
	all_passed = _grounded_checks() and all_passed

	# ══ Live grounding: the running-instance tier over the Live Values channel ════════════
	all_passed = _live_grounding_checks() and all_passed

	# ── Scale: the census paths that run per KEYSTROKE, against project-sized inputs ─────
	all_passed = _scale_checks() and all_passed

	return all_passed


## The live tier rides the SAME emitted receiver Live Values already ships: a debug-compiled
## sheet answers query_children with the running node's behaviour children. Pins the emission,
## the covenant (a normal compile carries NONE of it), the byte round-trip, the report parser,
## and that a report's children slot straight into grounded_groups.
static func _live_grounding_checks() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"hp": {"type": "int", "default": 100, "exported": true}}
	sheet.emit_live_values = true
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AddVar"
	action.codegen_template = "{var_name} += {amount}"
	action.params = {"var_name": "hp", "amount": "1"}
	row.actions.append(action)
	sheet.events.append(row)
	var debug_output: String = str(SheetCompiler.compile(sheet, "user://live_ground.gd").get("output", ""))
	all_passed = _check("debug compile answers query_children", debug_output.contains("query_children"), true) and all_passed
	all_passed = _check("debug compile carries the reporter", debug_output.contains("__eventsheets_report_children"), true) and all_passed
	all_passed = _check("the reply rides the eventsheets channel", debug_output.contains("eventsheets:children_report"), true) and all_passed
	# The lossless contract: the debug machinery round-trips byte-identically as content.
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(debug_output)
	reimported.external_source_path = "user://live_ground.gd"
	var recompiled: String = str(SheetCompiler.compile(reimported, "user://live_ground.gd").get("output", ""))
	all_passed = _check("live-grounding machinery round-trips byte-identically", recompiled == debug_output, true) and all_passed
	# The covenant: a NORMAL compile carries none of it.
	sheet.emit_live_values = false
	var clean_output: String = str(SheetCompiler.compile(sheet, "user://live_ground.gd").get("output", ""))
	all_passed = _check("normal compile has no live-grounding artifacts", clean_output.contains("query_children") or clean_output.contains("children_report"), false) and all_passed
	# The report parser (flat triples after the header; a truncated tail drops, never errors).
	var report: Dictionary = EventSheetLiveValuesDebugger.parse_children_report([
		"res://player.gd", 3, "Player",
		"RuntimeWobble", "SineBehavior", "res://eventsheet_addons/sine/sine_behavior.gd",
		"Legs", "PlatformerMovement",  # truncated triple - dropped
	])
	all_passed = _check("report: script path", str(report.get("script_path")), "res://player.gd") and all_passed
	all_passed = _check("report: instance count", int(report.get("instance_count")), 3) and all_passed
	all_passed = _check("report: owner name", str(report.get("owner_name")), "Player") and all_passed
	all_passed = _check("report: one whole triple kept, the truncated one dropped", (report.get("children") as Array).size(), 1) and all_passed
	all_passed = _check("report: empty payload fails closed",
		EventSheetLiveValuesDebugger.parse_children_report([]), {"script_path": "", "instance_count": 0, "owner_name": "", "children": []}) and all_passed
	# A report's children ARE grounded_groups input - a runtime-attached behaviour under its
	# runtime name inserts through that name.
	var live_groups: Array = EventSheetSelfExpressions.grounded_groups(report.get("children", []), false)
	all_passed = _check("a runtime-attached behaviour inserts under its runtime name",
		_fragment_for(_group_named(live_groups, "RuntimeWobble").get("entries", []), "Magnitude"), "$RuntimeWobble.magnitude") and all_passed
	return all_passed


## The grounded tier reads REAL children off the sheet's selected instance: renamed children
## keep their real name in every fragment (the point of grounding), two instances of one pack
## become two groups, and non-behaviour children never leak in.
static func _grounded_checks() -> bool:
	var all_passed: bool = true
	var sine_script: GDScript = load("res://eventsheet_addons/sine/sine_behavior.gd") as GDScript
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	var reflect_source: Node = sine_script.new()
	registry.refresh_from_sources([reflect_source], false)
	# The owner: a renamed Sine, a second Sine under another name, a plain child, and a child
	# whose script is NOT a provider (a scratch script with no global class name).
	var owner: Node2D = Node2D.new()
	var wobble: Node = sine_script.new()
	wobble.name = "Wobble"
	owner.add_child(wobble)
	var bob: Node = sine_script.new()
	bob.name = "HeadBob"
	owner.add_child(bob)
	var plain: Node = Node.new()
	plain.name = "Sprite"
	owner.add_child(plain)
	var children: Array = EventSheetSelfExpressions.grounded_children(owner)
	all_passed = _check("grounded census finds exactly the behaviour children", children.size(), 2) and all_passed
	var groups: Array = EventSheetSelfExpressions.grounded_groups(children, false)
	all_passed = _check("grounded groups: one per instance", groups.size(), 2) and all_passed
	all_passed = _check("a RENAMED child keeps its real name in the fragment",
		_fragment_for((_group_named(groups, "Wobble")).get("entries", []), "Magnitude"), "$Wobble.magnitude") and all_passed
	all_passed = _check("the second instance is its own group under its own name",
		_fragment_for((_group_named(groups, "HeadBob")).get("entries", []), "Magnitude"), "$HeadBob.magnitude") and all_passed
	all_passed = _check("grounded groups are marked grounded", bool(_group_named(groups, "Wobble").get("grounded")), true) and all_passed
	var robust_groups: Array = EventSheetSelfExpressions.grounded_groups(children, true)
	all_passed = _check("robust grounding uses the real name too",
		_fragment_for((_group_named(robust_groups, "Wobble")).get("entries", []), "Magnitude"), "get_node_or_null(\"Wobble\").magnitude") and all_passed
	all_passed = _check("null owner grounds nothing", EventSheetSelfExpressions.grounded_children(null).is_empty(), true) and all_passed
	owner.free()
	reflect_source.free()
	return all_passed


static func _group_named(groups: Array, node_name: String) -> Dictionary:
	for group: Variant in groups:
		if group is Dictionary and str((group as Dictionary).get("node_name")) == node_name:
			return group as Dictionary
	return {}


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
		groups = EventSheetSelfExpressions.behaviour_groups(big, false)
		all_passed = (section.get("variables", []) as Array).size() == 150 and all_passed
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	all_passed = _check("scale: correctness holds (150 vars, 40 fns, groups found)",
		groups.size() >= 60 and bool(_group_of(groups, "SineBehavior").get("used")), true) and all_passed
	all_passed = _check("scale: 20 refreshes over 300 rows x full fleet stay under 2000ms (took %.0fms)" % elapsed_ms,
		elapsed_ms < 2000.0, true) and all_passed
	# Grounded tier at scale: a crowded instance (100 children, 30 of them behaviours across the
	# whole fleet) derives correct and flat - it runs once per dialog-open.
	var owner: Node2D = Node2D.new()
	var behaviour_count: int = 0
	var source_index: int = 0
	for i: int in range(100):
		if i % 3 == 0 and source_index < sources.size():
			# Reuse the fleet's own scripts so every provider is a real reflected pack.
			var pack_script: GDScript = null
			while source_index < sources.size() and pack_script == null:
				var candidate: Object = sources[source_index]
				source_index += 1
				if candidate is Node and candidate.get_script() != null:
					pack_script = candidate.get_script() as GDScript
			if pack_script != null and not str(pack_script.get_global_name()).is_empty():
				var behaviour: Node = pack_script.new()
				behaviour.name = "B_%d" % i
				owner.add_child(behaviour)
				# A behaviour that publishes nothing (no knobs, no expression verbs) is CORRECTLY
				# dropped by the census, so the expectation counts only publishing children.
				if not EventSheetSelfExpressions.pack_entries_from_script(pack_script, "T", false).is_empty():
					behaviour_count += 1
				continue
		var filler: Node = Node.new()
		filler.name = "Filler_%d" % i
		owner.add_child(filler)
	var grounded_started: int = Time.get_ticks_usec()
	var grounded: Array = EventSheetSelfExpressions.grounded_children(owner)
	var grounded_built: Array = EventSheetSelfExpressions.grounded_groups(grounded, false)
	var grounded_ms: float = float(Time.get_ticks_usec() - grounded_started) / 1000.0
	all_passed = _check("scale: grounded census over 100 children finds every behaviour",
		grounded.size(), behaviour_count) and all_passed
	all_passed = _check("scale: grounded groups keep the synthetic names",
		grounded_built.is_empty() or str((grounded_built[0] as Dictionary).get("node_name", "")).begins_with("B_"), true) and all_passed
	all_passed = _check("scale: grounding a crowded node stays under 250ms (took %.0fms)" % grounded_ms,
		grounded_ms < 250.0, true) and all_passed
	owner.free()
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
