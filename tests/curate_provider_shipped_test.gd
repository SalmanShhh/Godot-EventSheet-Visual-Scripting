@tool
class_name CurateProviderShippedTest
extends RefCounted

# Godot EventSheets - the public door that curates a script writes nothing into a file the plugin
# ships. A row of a shipped behaviour belongs to the behaviour; the editor never rewrites a shipped
# pack file or anything under addons/, whoever asks and however the call is made.

const SUPPORT := preload("res://tests/support.gd")
## A throwaway file inside the shipped behaviour folder, made and removed by this test, so a red run
## can never write a real behaviour.
const PROBE_PACK_FILE: String = "res://eventsheet_addons/zz_curate_probe.gd"
const OWN_FILE: String = "user://curate_provider_own_script.gd"


static func run() -> bool:
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
	var plugin_result: Dictionary = EventSheets.curate_provider("res://addons/eventforge/plugin.gd", edits)
	var own: FileAccess = FileAccess.open(OWN_FILE, FileAccess.WRITE)
	own.store_string(source)
	own.close()
	var own_result: Dictionary = EventSheets.curate_provider(OWN_FILE, edits)
	var own_after: String = FileAccess.get_file_as_string(OWN_FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_FILE))
	return SUPPORT.pins("curate_provider_shipped_test", [
		["writing into a shipped behaviour folder is refused", str(result.get("ok", "")), "false"],
		["and the file is left exactly as it was", after, source],
		["no backup was made for a refused write", backup, ""],
		["the reason says whose file it is", str(result.get("reason", "")).contains("behaviour"), true],
		["a plugin file is refused the same way", str(plugin_result.get("ok", "")), "false"],
		["a script of yours is still written", str(own_result.get("ok", "")), "true"],
		["and carries the sentence", own_after.contains("Go now"), true],
	])
