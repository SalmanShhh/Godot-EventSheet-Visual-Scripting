@tool
class_name ScriptReflectionParityTest
extends RefCounted

# Godot EventSheets - a pack reflected from its SCRIPT publishes exactly what its instance does.
#
# The editor will not instantiate a script that is not `@tool` - it runs no game code - so there the
# registry reflects most packs from the script resource instead of from an object. This suite runs
# outside the editor, where every pack DOES instantiate, which is exactly how the editor's picker came
# to hold 142 pack verbs where a plain run held 4,477 with every test green. So both doors are asked
# here, pack by pack, and must agree field for field and in the same order:
#   1. every scanned pack script, instance vs script;
#   2. a provider with no class_name takes its id from its file, not from "GDScript";
#   3. the one door every caller uses falls back to the script when there is no instance to make.

const SUPPORT := preload("res://tests/support.gd")
## A pack that is not a tool script - the shape the editor refused - and a verb it publishes.
const PLAIN_PACK: String = "res://eventsheet_addons/flash/flash_behavior.gd"
const PLAIN_PACK_VERB: String = "method:flash"


static func run() -> bool:
	var ok: bool = _every_pack_agrees()
	ok = _the_id_comes_from_the_file() and ok
	ok = _the_door_falls_back_to_the_script() and ok
	return ok


static func _every_pack_agrees() -> bool:
	var ok: bool = true
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	for path: String in EventSheetAddonScanner.list_addon_scripts():
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			ok = _check("%s instantiates outside the editor" % path.get_file(), false, true) and ok
			continue
		var instance: Variant = script.new()
		var from_instance: PackedStringArray = _fingerprint(generator.generate_from_object(instance as Object))
		if instance is Node:
			(instance as Node).free()
		var from_script: PackedStringArray = _fingerprint(generator.generate_from_script(script))
		ok = _check("%s publishes the same verbs from its script" % path.get_file(), from_script, from_instance) and ok
	return ok


static func _the_id_comes_from_the_file() -> bool:
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var script: Script = load(PLAIN_PACK) as Script
	return SUPPORT.pins("script_reflection_parity_test", [
		["a class_name is the id", analyzer.provider_id_for_script(script, "Node", {"class_name": "Flasher"}), "Flasher"],
		["no class_name: the file name, pascal-cased",
			analyzer.provider_id_for_script(script, "Node", {}), "FlashBehavior"],
		["no script at all: the engine class", analyzer.provider_id_for_script(null, "Node2D", {}), "Node2D"],
	])


## The editor's refusal cannot be staged headless, so the fallback is asked for directly: a Script
## handed in as the source is reflected as the provider it is, not as an object of class GDScript.
static func _the_door_falls_back_to_the_script() -> bool:
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var script: Script = load(PLAIN_PACK) as Script
	var ids: PackedStringArray = PackedStringArray()
	var providers: Dictionary = {}
	for definition: ACEDefinition in generator.generate_from_object(script):
		ids.append(definition.id)
		providers[definition.provider_id] = true
	return SUPPORT.pins("script_reflection_parity_test", [
		["a Script given as the source publishes the pack's verbs", ids.has(PLAIN_PACK_VERB), true],
		["under the pack's own provider id, never GDScript", providers.has("GDScript"), false],
		["the one door agrees with the script door", _fingerprint(generator.reflect_script(script)),
			_fingerprint(generator.generate_from_script(script))],
	])


## Every field of every definition, in order, as text a comparison can print when it fails.
static func _fingerprint(definitions: Array[ACEDefinition]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		lines.append("|".join([definition.provider_id, definition.id, definition.display_name,
			definition.category, str(definition.ace_type), definition.description,
			var_to_str(definition.parameters), str(definition.return_type), definition.icon,
			var_to_str(definition.metadata), str(definition.editor_exposed), str(definition.property_hint),
			definition.hint_string, definition.widget_hint, definition.category_override]))
	return lines


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("script_reflection_parity_test", label, actual, expected)
