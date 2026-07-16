# EventForge - lambda / callable EXPRESSION helpers: Lambda (returns a value), Lambda (runs a statement),
# Callable of Method, and Bind Arguments, so a beginner can hand a small inline function to sort()/map(),
# connect one to a signal, or pre-fill arguments - without leaving the picker. Expressions are opaque
# strings in ACE params, so a lambda baked into a value round-trips verbatim (pinned below). Templates are
# FROZEN once shipped; builtin_ace_compile_test independently proves each compiles standalone.
@tool
class_name LambdaAcesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Registration: the four descriptors exist with the exact frozen templates ──
	ok = _check("LambdaValue template", _template("LambdaValue"), "(func({params}): return {value})") and ok
	ok = _check("LambdaStatement template", _template("LambdaStatement"), "(func({params}): {statement})") and ok
	ok = _check("CallableFromMethod template", _template("CallableFromMethod"), "Callable({target}, \"{method}\")") and ok
	ok = _check("CallableBind template", _template("CallableBind"), "{callable}.bind({args})") and ok
	# All four are EXPRESSION-type (values, not rows) - they must never join the reverse ACTION index.
	for ace_id: String in ["LambdaValue", "LambdaStatement", "CallableFromMethod", "CallableBind"]:
		var d: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
		ok = _check("%s is an EXPRESSION" % ace_id, d != null and d.ace_type == ACEDescriptor.ACEType.EXPRESSION, true) and ok

	# ── A lambda baked into a param value round-trips byte-identically (opaque expression) ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var set_action: ACEAction = ACEAction.new()
	set_action.provider_id = "Core"
	set_action.ace_id = "SetLocalVar"
	set_action.params = {"name": "doubler", "value": "(func(x): return x * 2)"}
	event.actions.append(set_action)
	sheet.events.append(event)
	var source: String = str(SheetCompiler.compile(sheet, "user://lambda_src.gd").get("output", ""))
	ok = _check("the lambda emits verbatim inside the declaration",
		source.contains("var doubler = (func(x): return x * 2)"), true) and ok
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://lambda_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://lambda_rt.gd").get("output", ""))
	ok = _check("a lambda-in-a-param round-trips byte-identically", roundtrip == source, true) and ok
	if roundtrip != source:
		print("  --- source ---\n%s\n  --- roundtrip ---\n%s" % [source, roundtrip])

	return ok


static func _template(ace_id: String) -> String:
	var d: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return d.codegen_template if d != null else "<missing>"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] lambda_aces_test: %s" % label)
		return true
	print("[FAIL] lambda_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
