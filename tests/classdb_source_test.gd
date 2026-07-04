# Godot EventSheets - the ClassDB reflected vocabulary (v0.11 chapter 5, P1).
#
# Any engine class becomes browsable vocabulary on demand: own methods classify by
# return type (void = Action, bool = Condition, else Expression), own signals become
# triggers, and every emission is the same plain `{target.}member(...)` call the
# curated vocabulary uses - so parity holds and future Godot classes work the day
# they ship. Pins use FLOORS + single stable members, never exact counts (engine
# versions add members), per the spec's engine-drift rule.
@tool
class_name ClassDBSourceTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Classification + template shape on a vocabulary-less class (GraphEdit) ──
	var graph_definitions: Array[ACEDefinition] = EventSheetClassDBSource.definitions_for_class("GraphEdit")
	ok = _check("GraphEdit reflects a real vocabulary", graph_definitions.size() >= 10, true) and ok
	var arrange: ACEDefinition = _find(graph_definitions, "method:arrange_nodes")
	ok = _check("a void method reflects as an Action", arrange != null and arrange.ace_type == ACEDefinition.ACEType.ACTION, true) and ok
	ok = _check("the emission is the plain call",
		str(arrange.metadata.get("codegen_template", "")) if arrange != null else "missing", "{target.}arrange_nodes()") and ok
	var zoom: ACEDefinition = _find(graph_definitions, "method:get_zoom")
	ok = _check("a value method reflects as an Expression", zoom != null and zoom.ace_type == ACEDefinition.ACEType.EXPRESSION, true) and ok
	var connection_signal: ACEDefinition = _find(graph_definitions, "signal:connection_request")
	ok = _check("an own signal reflects as a Trigger", connection_signal != null and connection_signal.ace_type == ACEDefinition.ACEType.TRIGGER, true) and ok
	ok = _check("reflected entries sit in the class section",
		str(arrange.category) if arrange != null else "missing", "All of GraphEdit") and ok

	# ── Properties reflect as Set action + Get expression pairs ──
	var set_zoom: ACEDefinition = _find(graph_definitions, "property:set:zoom")
	ok = _check("an editor property reflects a Set action",
		set_zoom != null and set_zoom.ace_type == ACEDefinition.ACEType.ACTION, true) and ok
	ok = _check("the setter emits plain assignment",
		str(set_zoom.metadata.get("codegen_template", "")) if set_zoom != null else "missing", "{target.}zoom = {value}") and ok
	var get_zoom_property: ACEDefinition = _find(graph_definitions, "property:get:zoom")
	ok = _check("the getter reads the plain property",
		get_zoom_property != null and str(get_zoom_property.metadata.get("codegen_template", "")) == "{target.}zoom", true) and ok

	# ── The class-aware helper dropdowns reflect real members (dialog statics) ──
	ok = _check("method suggestions include an inherited member",
		ACEParamsDialog.reflected_members("GraphEdit", "method").has("queue_free"), true) and ok
	ok = _check("property suggestions include an own member",
		ACEParamsDialog.reflected_members("GraphEdit", "property").has("zoom"), true) and ok

	# ── The session cache returns SHARED instances (the immutability contract) ──
	var second_pass: Array[ACEDefinition] = EventSheetClassDBSource.definitions_for_class("GraphEdit")
	ok = _check("the cache shares definition instances", _find(second_pass, "method:arrange_nodes") == arrange, true) and ok

	# ── Curated verbs are never shadowed by reflection ──
	var body_definitions: Array[ACEDefinition] = EventSheetClassDBSource.definitions_for_class("CharacterBody2D")
	ok = _check("a curated template filters its reflected twin",
		_find(body_definitions, "method:move_and_slide") == null, true) and ok

	# ── Unknown classes reflect to nothing, quietly ──
	ok = _check("an unknown class reflects to an empty vocabulary",
		EventSheetClassDBSource.definitions_for_class("NoSuchClass").is_empty(), true) and ok

	# ── A reflected action compiles to the bare call on the host ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "GraphEdit"
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "GraphEdit"
	action.ace_id = "method:arrange_nodes"
	action.codegen_template = str(arrange.metadata.get("codegen_template", "")) if arrange != null else ""
	event.actions.append(action)
	sheet.events.append(event)
	var compiled: String = str(SheetCompiler.compile(sheet).get("output", ""))
	ok = _check("the reflected action compiles to the plain call", compiled.contains("arrange_nodes()"), true) and ok
	ok = _check("no plugin reference rides along", compiled.contains("EventSheetClassDBSource"), false) and ok

	return ok


static func _find(definitions: Array[ACEDefinition], definition_id: String) -> ACEDefinition:
	for definition: ACEDefinition in definitions:
		if definition.id == definition_id:
			return definition
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] classdb_source_test: %s" % label)
		return true
	print("[FAIL] classdb_source_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
