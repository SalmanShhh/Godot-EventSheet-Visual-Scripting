# Godot EventSheets - the typed registrar (v0.11 chapter 4, P3).
#
# A provider may register through `static func _eventforge_register(reg)` instead of
# ## @ace_* comments: real GDScript, so the editor autocompletes the vocabulary and a
# typo is a compile error. The contract pinned here: the registrar and the comment
# dialect flow through ONE pipeline and produce IDENTICAL definitions - every shared
# member of the two twin fixtures must match field for field.
@tool
class_name RegistrarProviderTest
extends RefCounted

const COMMENT_TWIN := preload("res://tests/fixtures/terse_provider_sample.gd")
const REGISTRAR_TWIN := preload("res://tests/fixtures/registrar_provider_sample.gd")

const SHARED_KEYS := ["signal:reloaded", "method:fire", "method:reload", "method:shells_left", "method:aim"]


static func run() -> bool:
	var ok: bool = true
	var comment_sample: Node = COMMENT_TWIN.new()
	var registrar_sample: Node = REGISTRAR_TWIN.new()
	var comment_registry := EventSheetACERegistry.new()
	var registrar_registry := EventSheetACERegistry.new()
	comment_registry.refresh_from_sources([comment_sample], true)
	registrar_registry.refresh_from_sources([registrar_sample], true)

	for shared_key in SHARED_KEYS:
		var from_comments: ACEDefinition = comment_registry.find_definition("TerseProviderSample", shared_key)
		var from_registrar: ACEDefinition = registrar_registry.find_definition("RegistrarProviderSample", shared_key)
		ok = _check("%s exists via registrar" % shared_key, from_registrar != null, true) and ok
		if from_comments == null or from_registrar == null:
			continue
		ok = _check("%s ace_type matches" % shared_key, from_registrar.ace_type, from_comments.ace_type) and ok
		ok = _check("%s display_name matches" % shared_key, from_registrar.display_name, from_comments.display_name) and ok
		ok = _check("%s category matches" % shared_key, from_registrar.category, from_comments.category) and ok
		ok = _check("%s description matches" % shared_key, from_registrar.description, from_comments.description) and ok
		ok = _check("%s icon matches" % shared_key, from_registrar.icon, from_comments.icon) and ok
		ok = _check("%s parameters match" % shared_key, _parameter_signature(from_registrar), _parameter_signature(from_comments)) and ok

	# The copy-ready stubs (picker right-click) reproduce both dialects from a definition.
	var fire_definition: ACEDefinition = comment_registry.find_definition("TerseProviderSample", "method:fire")
	var comment_stub: String = EventSheetACEAnnotationStub.comment_stub(fire_definition)
	ok = _check("comment stub carries the prose description", comment_stub.contains("## Fires the weapon once."), true) and ok
	ok = _check("comment stub declares the type", comment_stub.contains("## @ace_action"), true) and ok
	ok = _check("comment stub ends in a func skeleton", comment_stub.contains("func fire() -> void:"), true) and ok
	var registrar_stub: String = EventSheetACEAnnotationStub.registrar_stub(fire_definition)
	ok = _check("registrar stub opens the hook", registrar_stub.contains("static func _eventforge_register(reg: EventForgeRegistrar) -> void:"), true) and ok
	ok = _check("registrar stub chains the member", registrar_stub.contains("reg.action(\"fire\")"), true) and ok
	ok = _check("registrar stub carries the category", registrar_stub.contains(".category(\"Weapons\")"), true) and ok
	var aim_definition: ACEDefinition = comment_registry.find_definition("TerseProviderSample", "method:aim")
	var aim_stub: String = EventSheetACEAnnotationStub.comment_stub(aim_definition)
	ok = _check("comment stub emits one-line params", aim_stub.contains("## @ace_param(mode, hint: expression)"), true) and ok
	ok = _check("comment stub emits pipe options", aim_stub.contains("## @ace_param(stance, options: crouch|stand|prone)"), true) and ok

	comment_sample.free()
	registrar_sample.free()
	return ok


## A comparable string of every field the params dialog consumes, so a drift in
## hint/options/autocomplete/description surfaces as a readable diff.
static func _parameter_signature(definition: ACEDefinition) -> String:
	var parts: Array[String] = []
	for parameter in definition.parameters:
		if not (parameter is Dictionary):
			continue
		var parameter_dict: Dictionary = parameter
		var option_keys: Array = []
		for option_entry in parameter_dict.get("options", []):
			option_keys.append(str((option_entry as Dictionary).get("key", "")))
		parts.append("%s|%s|%s|%s|%s" % [
			str(parameter_dict.get("id", "")),
			str(parameter_dict.get("hint", "")),
			str(parameter_dict.get("description", "")),
			str(option_keys),
			str(parameter_dict.get("autocomplete", []))
		])
	return "; ".join(parts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] registrar_provider_test: %s" % label)
		return true
	print("[FAIL] registrar_provider_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
