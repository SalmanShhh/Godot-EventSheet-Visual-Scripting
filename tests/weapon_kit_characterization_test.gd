# Godot EventSheets - Weapon Kit vocabulary characterization (the expose_all migration proof).
#
# Weapon Kit migrated from per-member annotations (name + category + codegen template +
# type marker on every member) to the terse form: class-level @ace_category("Weapon") +
# @ace_expose_all(node), keeping per-member @ace_name ONLY where the curated name differs
# from the humanized identifier (On Fire, On Empty, On Reload Complete, Is Full,
# Is Reloading; the function-system actions keep their own annotations - that emission
# shape is frozen). This table pins the ENTIRE reflected vocabulary - id, type, display
# name, category, codegen template - so the terse form provably publishes the same
# language. The ONE deliberate change from the pre-migration vocabulary: property ACEs
# moved from the inferred "Gameplay" category into the pack's "Weapon" group.
@tool
class_name WeaponKitCharacterizationTest
extends RefCounted

## Every definition the pack publishes, "id|ace_type|display_name|category|codegen_template",
## sorted by id. A row changing here is a compatibility event: ids and shipped shapes are
## promises, so a diff must be a deliberate, changelog-noted decision - never refactor fallout.
const EXPECTED := [
	"add:burst_count|1|Add To Burst Count|Weapon|{target}.burst_count += {amount}",
	"add:current_ammo|1|Add To Current Ammo|Weapon|{target}.current_ammo += {amount}",
	"add:fire_mode|1|Add To Fire Mode|Weapon|{target}.fire_mode += {amount}",
	"add:fire_rate|1|Add To Fire Rate|Weapon|{target}.fire_rate += {amount}",
	"add:max_ammo|1|Add To Max Ammo|Weapon|{target}.max_ammo += {amount}",
	"add:reload_time|1|Add To Reload Time|Weapon|{target}.reload_time += {amount}",
	"add:reserve_ammo|1|Add To Reserve Ammo|Weapon|{target}.reserve_ammo += {amount}",
	"method:add_ammo|1|Add Ammo|Weapon|{target}.add_ammo({amount})",
	"method:add_reserve|1|Add Reserve Ammo|Weapon|{target}.add_reserve({amount})",
	"method:ammo_percent|2|Ammo Percent|Weapon|{target}.ammo_percent()",
	"method:can_fire|0|Can Fire|Weapon|{target}.can_fire()",
	"method:cancel_reload|1|Cancel Reload|Weapon|{target}.cancel_reload()",
	"method:cooldown_progress|2|Cooldown Progress|Weapon|{target}.cooldown_progress()",
	"method:fire|1|Fire|Weapon|{target}.fire()",
	"method:has_ammo|0|Has Ammo|Weapon|{target}.has_ammo()",
	"method:instant_reload|1|Instant Reload|Weapon|{target}.instant_reload()",
	"method:is_full|0|Is Full|Weapon|{target}.is_full()",
	"method:is_reloading|0|Is Reloading|Weapon|{target}.is_reloading()",
	"method:reload_progress|2|Reload Progress|Weapon|{target}.reload_progress()",
	"method:reload|1|Reload|Weapon|{target}.reload()",
	"method:set_fire_mode|1|Set Fire Mode|Weapon|{target}.set_fire_mode({mode})",
	"method:set_fire_rate|1|Set Fire Rate|Weapon|{target}.set_fire_rate({rate})",
	"method:set_max_ammo|1|Set Magazine Size|Weapon|{target}.set_max_ammo({size})",
	"property:auto_reload|2|Auto Reload|Weapon|{target}.auto_reload",
	"property:burst_count|2|Burst Count|Weapon|{target}.burst_count",
	"property:current_ammo|2|Current Ammo|Weapon|{target}.current_ammo",
	"property:fire_mode|2|Fire Mode|Weapon|{target}.fire_mode",
	"property:fire_rate|2|Fire Rate|Weapon|{target}.fire_rate",
	"property:infinite_reserve|2|Infinite Reserve|Weapon|{target}.infinite_reserve",
	"property:max_ammo|2|Max Ammo|Weapon|{target}.max_ammo",
	"property:reload_time|2|Reload Time|Weapon|{target}.reload_time",
	"property:reserve_ammo|2|Reserve Ammo|Weapon|{target}.reserve_ammo",
	"set:auto_reload|1|Set Auto Reload|Weapon|{target}.auto_reload = {value}",
	"set:burst_count|1|Set Burst Count|Weapon|{target}.burst_count = {value}",
	"set:current_ammo|1|Set Current Ammo|Weapon|{target}.current_ammo = {value}",
	# Suffixed because this pack ALSO publishes authored "Set Fire Mode" / "Set Fire Rate" verbs: the
	# reflected twin writes the property raw, the authored one is the curated entry, and two identically
	# labelled rows in the picker is a silent-wrong-pick trap. Only the label differs - the ids and the
	# templates below are the frozen API and are unchanged.
	"set:fire_mode|1|Set Fire Mode (property)|Weapon|{target}.fire_mode = {value}",
	"set:fire_rate|1|Set Fire Rate (property)|Weapon|{target}.fire_rate = {value}",
	"set:infinite_reserve|1|Set Infinite Reserve|Weapon|{target}.infinite_reserve = {value}",
	"set:max_ammo|1|Set Max Ammo|Weapon|{target}.max_ammo = {value}",
	"set:reload_time|1|Set Reload Time|Weapon|{target}.reload_time = {value}",
	"set:reserve_ammo|1|Set Reserve Ammo|Weapon|{target}.reserve_ammo = {value}",
	"signal:emptied|3|On Empty|Weapon|",
	"signal:fired|3|On Fire|Weapon|",
	"signal:reload_completed|3|On Reload Complete|Weapon|",
	"signal:reload_started|3|On Reload Started|Weapon|",
	"subtract:burst_count|1|Subtract From Burst Count|Weapon|{target}.burst_count -= {amount}",
	"subtract:current_ammo|1|Subtract From Current Ammo|Weapon|{target}.current_ammo -= {amount}",
	"subtract:fire_mode|1|Subtract From Fire Mode|Weapon|{target}.fire_mode -= {amount}",
	"subtract:fire_rate|1|Subtract From Fire Rate|Weapon|{target}.fire_rate -= {amount}",
	"subtract:max_ammo|1|Subtract From Max Ammo|Weapon|{target}.max_ammo -= {amount}",
	"subtract:reload_time|1|Subtract From Reload Time|Weapon|{target}.reload_time -= {amount}",
	"subtract:reserve_ammo|1|Subtract From Reserve Ammo|Weapon|{target}.reserve_ammo -= {amount}",
]


static func run() -> bool:
	var ok: bool = true
	var script: Script = load("res://eventsheet_addons/weapon_kit/weapon_kit_behavior.gd")
	var instance: Object = (script as GDScript).new()
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var actual: Array = []
	for definition: ACEDefinition in generator.generate_from_object(instance):
		actual.append("%s|%d|%s|%s|%s" % [
			definition.id,
			definition.ace_type,
			definition.display_name,
			definition.category,
			str(definition.metadata.get("codegen_template", "")),
		])
	if instance is Node:
		(instance as Node).free()
	actual.sort()
	ok = _check("the pack publishes exactly the characterized vocabulary size", actual.size(), EXPECTED.size()) and ok
	for index in range(mini(actual.size(), EXPECTED.size())):
		if str(actual[index]) != str(EXPECTED[index]):
			ok = _check("row %d matches" % index, actual[index], EXPECTED[index]) and ok
	if ok:
		print("[PASS] weapon_kit_characterization_test: all %d vocabulary rows match" % EXPECTED.size())
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] weapon_kit_characterization_test: %s" % label)
		return true
	print("[FAIL] weapon_kit_characterization_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
