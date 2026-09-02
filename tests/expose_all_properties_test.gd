# Godot EventSheets - reflected property codegen (the "compiles to EMPTY" covenant fix).
#
# An @export var on a provider reflects as an expression + Set/Add/Subtract actions.
# Before this fix those actions carried NO codegen template and compiled to empty
# output - a silent no-op. Now the generator synthesizes the real assignment at
# generation time: NODE providers write through the behavior node (a retargetable
# {target} param defaulting to $Provider, exactly like reflected methods), while
# RefCounted/Resource utility providers write through the compiler-declared owned
# instance (__eventsheet_provider_<Class>). The expression gets the matching read.
@tool
class_name ExposeAllPropertiesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NODE_SAMPLE := preload("res://tests/fixtures/auto_ace_sample.gd")
const UTILITY_SAMPLE := preload("res://tests/fixtures/utility_provider_fixture.gd")


static func run() -> bool:
	var ok: bool = true
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()

	# ── Node provider: property writes target the scene node, retargetable ──
	var node_sample: Node = NODE_SAMPLE.new()
	var node_definitions: Array[ACEDefinition] = generator.generate_from_object(node_sample)
	var set_health: ACEDefinition = _find(node_definitions, "set:health")
	ok = _check("node Set template targets the behavior node",
		str(set_health.metadata.get("codegen_template", "")) if set_health != null else "",
		"{target}.health = {value}") and ok
	ok = _check("node Set gained the On-node param with the authored default",
		_param_default(set_health, "target"), "$AutoACESample") and ok
	var add_health: ACEDefinition = _find(node_definitions, "add:health")
	ok = _check("node Add template is a += write",
		str(add_health.metadata.get("codegen_template", "")) if add_health != null else "",
		"{target}.health += {amount}") and ok
	var subtract_health: ACEDefinition = _find(node_definitions, "subtract:health")
	ok = _check("node Subtract template is a -= write",
		str(subtract_health.metadata.get("codegen_template", "")) if subtract_health != null else "",
		"{target}.health -= {amount}") and ok
	var health_expression: ACEDefinition = _find(node_definitions, "property:health")
	ok = _check("node property expression reads through the node",
		str(health_expression.metadata.get("codegen_template", "")) if health_expression != null else "",
		"{target}.health") and ok
	node_sample.free()

	# ── Utility (RefCounted) provider: writes go through the owned instance ──
	var utility_definitions: Array[ACEDefinition] = generator.generate_from_object(UTILITY_SAMPLE.new())
	var set_streak: ACEDefinition = _find(utility_definitions, "set:streak")
	ok = _check("utility Set writes through the owned instance",
		str(set_streak.metadata.get("codegen_template", "")) if set_streak != null else "",
		"__eventsheet_provider_UtilityProviderFixture.streak = {value}") and ok
	ok = _check("utility property expression reads the owned instance",
		str(_find(utility_definitions, "property:streak").metadata.get("codegen_template", "")) if _find(utility_definitions, "property:streak") != null else "",
		"__eventsheet_provider_UtilityProviderFixture.streak") and ok

	# ── End to end: the baked Set action emits a real assignment, never empty ──
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "AutoACESample"
	action.ace_id = "set:health"
	action.codegen_template = str(set_health.metadata.get("codegen_template", "")) if set_health != null else ""
	action.params = {"target": "$Enemy/AutoACESample", "value": "42"}
	event.actions.append(action)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://expose_all_properties_test.gd").get("output", ""))
	ok = _check("the applied Set compiles to the retargeted assignment",
		output.contains("$Enemy/AutoACESample.health = 42"), true) and ok

	# ── A reflected name that collides with an AUTHORED verb is suffixed, so the picker never shows two
	# identical rows that do different things. The authored verb keeps the plain label; only the LABEL
	# moves, because ace_ids and codegen templates are the frozen API. ──
	var combo: Node = load("res://eventsheet_addons/combo_box/combo_box_addon.gd").new()
	var combo_definitions: Array[ACEDefinition] = generator.generate_from_object(combo)
	var authored_length: ACEDefinition = _find(combo_definitions, "method:buffer_length_now")
	var reflected_length: ACEDefinition = _find(combo_definitions, "property:buffer_length")
	ok = _check("the authored verb keeps the plain label",
		authored_length.display_name if authored_length != null else "", "Buffer Length") and ok
	ok = _check("its reflected twin is suffixed instead of shadowing it",
		reflected_length.display_name if reflected_length != null else "", "Buffer Length (property)") and ok
	ok = _check("the reflected twin's ace_id is untouched (frozen API)",
		reflected_length.id if reflected_length != null else "", "property:buffer_length") and ok
	var reflected_setter: ACEDefinition = _find(combo_definitions, "set:buffer_length")
	ok = _check("a colliding reflected ACTION is suffixed too, keeping its parameter tail",
		str(reflected_setter.metadata.get("display_template", "")) if reflected_setter != null else "",
		"Set Buffer Length (property) {value}") and ok
	var uncontested: ACEDefinition = _find(combo_definitions, "property:debug_logging")
	ok = _check("a reflected name with NO authored twin is left alone",
		uncontested.display_name if uncontested != null else "", "Debug Logging") and ok
	combo.free()

	# ── A provider with NO class_name falls back to its file name, and that id is interpolated into a
	# GDScript IDENTIFIER for non-Node providers. capitalize() produced "Nameless Provider Fixture",
	# emitting `__eventsheet_provider_Nameless Provider Fixture.high_score`, which the compiler's
	# declaration scan read as `__eventsheet_provider_Nameless` and declared `Nameless.new()`. ──
	var nameless: RefCounted = preload("res://tests/fixtures/nameless_provider_fixture.gd").new()
	var nameless_definitions: Array[ACEDefinition] = generator.generate_from_object(nameless)
	var nameless_setter: ACEDefinition = _find(nameless_definitions, "set:high_score")
	ok = _check("a class_name-less provider id is a valid identifier",
		nameless_setter.provider_id if nameless_setter != null else "", "NamelessProviderFixture") and ok
	var nameless_template: String = str(nameless_setter.metadata.get("codegen_template", "")) if nameless_setter != null else ""
	ok = _check("its owned-instance write emits no space in the identifier",
		nameless_template, "__eventsheet_provider_NamelessProviderFixture.high_score = {value}") and ok
	# The emitted line must also parse - the whole point of the identifier being legal.
	var nameless_probe: GDScript = GDScript.new()
	nameless_probe.source_code = "@tool\nextends Node\nvar __eventsheet_provider_NamelessProviderFixture\nfunc _t() -> void:\n\t%s\n" % nameless_template.replace("{value}", "7")
	ok = _check("and the emitted assignment parses", nameless_probe.reload(), OK) and ok
	return ok


static func _find(definitions: Array[ACEDefinition], definition_id: String) -> ACEDefinition:
	for definition: ACEDefinition in definitions:
		if definition != null and definition.id == definition_id:
			return definition
	return null


static func _param_default(definition: ACEDefinition, param_id: String) -> String:
	if definition == null:
		return ""
	for parameter: Variant in definition.parameters:
		if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == param_id:
			return str((parameter as Dictionary).get("default_value", ""))
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("expose_all_properties_test", label, actual, expected)
