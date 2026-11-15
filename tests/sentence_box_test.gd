@tool
class_name SentenceBoxTest
extends RefCounted

# Godot EventSheets - "How should this read?": the box that writes a function's sentence into its script.
#
# The preview is made on a COPY of the definition (definitions are shared and immutable for the whole
# session); a slot the sentence names that the function has not is a finding, not a silent blank; and
# nothing under a shipped behaviour folder or addons/ is ever written - not by the box, and not by the
# public curate_provider door the box writes through.
#
# The box is loaded by path (it must stay out of the editor's first-open closure), so a missing file or
# function fails a pin instead of stopping the suite.

const SUPPORT := preload("res://tests/support.gd")
const READER := preload("res://addons/eventsheet/ace/script_reader.gd")
const BOX_PATH: String = "res://addons/eventsheet/editor/dock/sentence_box.gd"
const FIXTURE: String = "res://tests/fixtures/script_rows_ui/sentence_thing.gd"
## A throwaway file inside the shipped behaviour folder, made and removed by this test, so a red run
## can never write a real behaviour.
const PROBE_PACK_FILE: String = "res://eventsheet_addons/zz_sentence_box_probe.gd"
const MISSING: String = "<not written yet>"


static func run() -> bool:
	var ok: bool = _preview_on_a_copy()
	ok = _a_call_finds_its_one_class() and ok
	ok = _shipped_files_are_never_written() and ok
	return ok


static func _box_call(method: String, args: Array) -> Variant:
	if not ResourceLoader.exists(BOX_PATH):
		return MISSING
	var script: GDScript = load(BOX_PATH)
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method:
			return script.callv(method, args)
	return MISSING


static func _take_damage() -> ACEDefinition:
	for definition: ACEDefinition in READER.definitions_for("ScriptRowsSentenceThing", load(FIXTURE) as Script, ""):
		if definition.id == "method:take_damage":
			return definition
	return null


static func _preview_on_a_copy() -> bool:
	var definition: ACEDefinition = _take_damage()
	var before: String = str(definition.metadata.get("display_template", ""))
	var preview: String = str(_box_call("preview", [definition, "Hit for {amount}"]))
	var unknown: String = str(_box_call("finding_for", [definition, "Hit for {amout}"]))
	var fine: String = str(_box_call("finding_for", [definition, "Hit for {amount}"]))
	return SUPPORT.pins("sentence_box_test", [
		["the preview says the typed sentence with the row's default", preview, "Hit for 10"],
		["the shared definition is not touched", str(definition.metadata.get("display_template", "")), before],
		["a slot the function does not have is named", unknown.contains("amout") and unknown != MISSING, true],
		["a sentence with known slots has no finding", fine, ""],
	])


static func _shipped_files_are_never_written() -> bool:
	var source: String = "extends Node\n\n\nfunc go() -> void:\n\tpass\n"
	var handle: FileAccess = FileAccess.open(PROBE_PACK_FILE, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	var edits: Array = [{"source_kind": "method", "member": "go", "display_template": "Go now"}]
	var result: Dictionary = EventSheets.curate_provider(PROBE_PACK_FILE, edits)
	var after: String = FileAccess.get_file_as_string(PROBE_PACK_FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PACK_FILE))
	var backup: String = str(result.get("backup", ""))
	if not backup.is_empty() and FileAccess.file_exists(backup):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	var shipped_reason: String = str(_box_call("writable_reason", ["res://eventsheet_addons/juice/juice_behavior.gd"]))
	var plugin_reason: String = str(_box_call("writable_reason", ["res://addons/eventforge/plugin.gd"]))
	return SUPPORT.pins("sentence_box_test", [
		["writing into a shipped behaviour folder is refused", str(result.get("ok", "")), "false"],
		["and the file is left exactly as it was", after, source],
		["the box says whose row it is instead", not shipped_reason.is_empty() and shipped_reason != MISSING, true],
		["a plugin file is refused the same way", not plugin_reason.is_empty() and plugin_reason != MISSING, true],
		["a script of yours may be written", str(_box_call("writable_reason", [FIXTURE])), ""],
	])


## A Call Method row names a function and no class: it finds the one project class that declares the
## function, and says nothing when several do or none does (no script to write).
static func _a_call_finds_its_one_class() -> bool:
	var one: Variant = _box_call("definition_for_call", ["clamp_score"])
	var several: Variant = _box_call("definition_for_call", ["take_damage"])
	var none: Variant = _box_call("definition_for_call", ["no_such_function_anywhere"])
	return SUPPORT.pins("sentence_box_test", [
		["a function one class declares finds its row", (one as ACEDefinition).id if one is ACEDefinition else "<none>", "method:clamp_score"],
		["a function several classes declare finds none", several == null, true],
		["and a function nobody declares finds none", none == null, true],
	])
