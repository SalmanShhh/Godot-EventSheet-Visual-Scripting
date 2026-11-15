# Godot EventSheets - a script can keep the provider id its rows were saved under when its class is renamed.
#
# A ROW'S IDENTITY is `provider::ace_id`, and the provider is the script's class_name. One class-level
# line, `## @ace_provider_id(OldName)`, keeps the old provider when the class is renamed, so `.tres`
# rows saved under it keep resolving with no alias table. The analyzer reads annotations off DISK, so
# the probe scripts are real files under user://; one built from a string in memory would pass for the
# wrong reason.
class_name ScriptProviderIdTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "script_provider_id"
const KEPT_PATH: String = "user://script_provider_id_kept.gd"
const PLAIN_PATH: String = "user://script_provider_id_plain.gd"

const BODY: String = "extends Node\n\n## @ace_name(\"Speed\")\n@export var speed: float = 1.0\n\n## @ace_name(\"Ping\")\nfunc ping() -> void:\n\tpass\n"


static func run() -> bool:
	_write(KEPT_PATH, "## @ace_provider_id(ProbeOldName)\nclass_name ScriptProviderIdProbe\n" + BODY)
	_write(PLAIN_PATH, "class_name ScriptProviderIdPlainProbe\n" + BODY)
	var kept: Array[ACEDefinition] = EventSheetACEGenerator.new().generate_from_script(_fresh(KEPT_PATH))
	var plain: Array[ACEDefinition] = EventSheetACEGenerator.new().generate_from_script(_fresh(PLAIN_PATH))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the line keeps the old provider id", _providers(kept), ["ProbeOldName"]],
		["without it the class name is the provider, as ever", _providers(plain), ["ScriptProviderIdPlainProbe"]],
		["the node a property row starts on is still the class", _target(kept, "set:speed"), "$ScriptProviderIdProbe"],
		["the analyzer does not warn about the word", _unknown(KEPT_PATH), []],
	])
	ok = _round_trip_pins() and ok
	for path: String in [KEPT_PATH, PLAIN_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


## A sheet that carries the kept id writes the line and reads it back, byte for byte.
static func _round_trip_pins() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "ScriptProviderIdSheet"
	sheet.set("addon_provider_id", "ProbeOldName")
	var source: String = SUPPORT.compile_output(sheet, "user://script_provider_id_sheet.gd")
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	return SUPPORT.pins(TEST_NAME, [
		["the compiler writes the line", source.contains("\n## @ace_provider_id(ProbeOldName)\n") or source.begins_with("## @ace_provider_id(ProbeOldName)\n"), true],
		["the importer reads it back", str(reopened.get("addon_provider_id")), "ProbeOldName"],
		["and the file re-saves byte for byte", SUPPORT.reemit(source, "user://script_provider_id_sheet.gd"), source],
	])


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _fresh(path: String) -> Script:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script


static func _providers(definitions: Array[ACEDefinition]) -> Array:
	var seen: Dictionary = {}
	for definition: ACEDefinition in definitions:
		seen[definition.provider_id] = true
	return seen.keys()


static func _target(definitions: Array[ACEDefinition], id: String) -> String:
	for definition: ACEDefinition in definitions:
		if definition.id != id:
			continue
		for parameter: Variant in definition.parameters:
			if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == "target":
				return str((parameter as Dictionary).get("default_value", ""))
	return "<no %s row>" % id


static func _unknown(path: String) -> Array:
	var metadata: Dictionary = EventSheetSemanticAnalyzer.new().parse_source_metadata(_fresh(path))
	return metadata.get("unknown_annotations", [])
