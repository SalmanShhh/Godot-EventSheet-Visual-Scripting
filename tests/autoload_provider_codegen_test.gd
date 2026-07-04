# Godot EventSheets - autoload providers call THE singleton (never a second instance).
#
# A provider script registered as an autoload is a live global. Before this fix its
# template-less methods baked to the owned-instance form (spawning a SECOND bus whose
# state the game never sees) and its properties baked to the $-node form (resolving
# against the wrong branch of the tree). The generator now detects the registration
# (ProjectSettings autoload/* path match) and synthesizes <SingletonName>.member for
# methods, property writes, and property reads - with no retarget param (you do not
# retarget a singleton).
@tool
class_name AutoloadProviderCodegenTest
extends RefCounted

const BUS_PATH := "res://tests/fixtures/bus_fixture.gd"
const AUTOLOAD_SETTING := "autoload/TestBus"


static func run() -> bool:
	var ok: bool = true
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var script: GDScript = load(BUS_PATH) as GDScript

	# Registered as an autoload: every member goes through the singleton by name.
	ProjectSettings.set_setting(AUTOLOAD_SETTING, "*" + BUS_PATH)
	var bus: Node = script.new()
	var definitions: Array[ACEDefinition] = generator.generate_from_object(bus)
	ok = _check("autoload method calls the singleton",
		_template(definitions, "method:publish"), "TestBus.publish({value})") and ok
	ok = _check("autoload property write goes through the singleton",
		_template(definitions, "set:score"), "TestBus.score = {value}") and ok
	ok = _check("autoload property read goes through the singleton",
		_template(definitions, "property:score"), "TestBus.score") and ok
	ok = _check("singleton actions carry no retarget param",
		_has_param(definitions, "set:score", "target"), false) and ok
	bus.free()
	ProjectSettings.set_setting(AUTOLOAD_SETTING, null)

	# The same script NOT registered: the Node-provider form returns (regression guard).
	# The $-default derives from the FILENAME (PascalCase), never the spaced display id -
	# "$Bus Fixture" is not a valid bare node path and defeats {target} parameterization.
	var plain: Node = script.new()
	var plain_definitions: Array[ACEDefinition] = generator.generate_from_object(plain)
	ok = _check("unregistered node provider keeps the retargetable node form",
		_template(plain_definitions, "set:score"), "{target}.score = {value}") and ok
	ok = _check("the node default is the PascalCase filename",
		_param_default(plain_definitions, "set:score", "target"), "$BusFixture") and ok
	plain.free()
	return ok


static func _template(definitions: Array[ACEDefinition], definition_id: String) -> String:
	for definition: ACEDefinition in definitions:
		if definition != null and definition.id == definition_id:
			return str(definition.metadata.get("codegen_template", ""))
	return "<definition %s not found>" % definition_id


static func _param_default(definitions: Array[ACEDefinition], definition_id: String, param_id: String) -> String:
	for definition: ACEDefinition in definitions:
		if definition == null or definition.id != definition_id:
			continue
		for parameter: Variant in definition.parameters:
			if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == param_id:
				return str((parameter as Dictionary).get("default_value", ""))
	return ""


static func _has_param(definitions: Array[ACEDefinition], definition_id: String, param_id: String) -> bool:
	for definition: ACEDefinition in definitions:
		if definition == null or definition.id != definition_id:
			continue
		for parameter: Variant in definition.parameters:
			if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == param_id:
				return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] autoload_provider_codegen_test: %s" % label)
		return true
	print("[FAIL] autoload_provider_codegen_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
