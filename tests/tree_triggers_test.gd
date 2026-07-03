# Godot EventSheets — Tree-membership triggers (react to tree events, don't poll IsInsideTree).
#
# Godot's nodes emit tree_entered / tree_exiting / tree_exited / renamed / child_entered_tree — so
# "when this OTHER node enters/leaves the scene" is a SIGNAL to react to, not a per-frame IsInsideTree
# check inside On Process (the poll-every-tick habit). Verifies the five triggers register,
# compile to a _ready signal connection on the source node with a named handler, carry their args, and
# round-trip back to the named trigger byte-identically.
@tool
class_name TreeTriggersTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor

	for ace_id: String in ["OnTreeEntered", "OnTreeExiting", "OnTreeExited", "OnRenamed", "OnChildEnteredTree"]:
		all_passed = _check("trigger registered: %s" % ace_id,
			by_id.has(ace_id) and by_id[ace_id].ace_type == ACEDescriptor.ACEType.TRIGGER, true) and all_passed

	# React to ANOTHER node's tree_entered (source path) — the compiler wires the connection in _ready.
	var source: String = _compile_tree_trigger("OnTreeEntered", "Spawner")
	all_passed = _check("wires the source node's tree_entered in _ready",
		source.contains("get_node(\"Spawner\").tree_entered.connect(_on_spawner_tree_entered)"), true) and all_passed
	all_passed = _check("emits the named handler",
		source.contains("func _on_spawner_tree_entered() -> void:"), true) and all_passed

	# child_entered_tree carries the entering child as an argument.
	var child_source: String = _compile_tree_trigger("OnChildEnteredTree", "")
	all_passed = _check("child_entered_tree handler takes the node arg",
		child_source.contains("func _on_child_entered_tree(node: Node) -> void:"), true) and all_passed

	# Round-trip: the generated connection lifts back to the NAMED trigger and recompiles byte-identically.
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://__tree_trigger_roundtrip.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://__tree_trigger_roundtrip.gd").get("output", ""))
	all_passed = _check("tree-trigger output round-trips byte-identically", roundtrip == source, true) and all_passed
	var lifted_trigger: String = ""
	for row: Variant in imported.events:
		if row is EventRow and (row as EventRow).trigger_id == "OnTreeEntered":
			lifted_trigger = (row as EventRow).trigger_id
	all_passed = _check("the connection lifts back to On Tree Entered", lifted_trigger, "OnTreeEntered") and all_passed

	return all_passed


## A one-event sheet whose trigger is `trigger_id` from `source_path`, with a raw body so the connection
## has something to call. Returns the compiled GDScript.
static func _compile_tree_trigger(trigger_id: String, source_path: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	event.trigger_source_path = source_path
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "print(\"entered\")"
	event.actions.append(body)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://__tree_trigger.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tree_triggers_test: %s" % label)
		return true
	print("[FAIL] tree_triggers_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
