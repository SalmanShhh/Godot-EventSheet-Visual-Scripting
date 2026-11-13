# Godot EventSheets - the provider registry needs no autoload.
#
# The plugin used to write an `EventForgeBridge` autoload into every project it was enabled in, and
# the autoload was exported with the game although nothing in a shipped game uses it. The registry is
# a plain static class now. Pinned here: code-registered providers reach the vocabulary with no
# autoload, the plugin recognises its OWN old autoload line (by path or by uid) and never one a
# project made for itself under the same name, and nothing adds the line any more.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "bridge_without_autoload_test"
const SCRIPT_UID := "*uid://duh4jgpamtcwn"


static func run() -> bool:
	var old_by_uid: bool = EventForgePlugin.is_old_bridge_autoload(SCRIPT_UID)
	var descriptor: Dictionary = {"provider_id": "BridgeTestProvider", "ace_id": "BridgeTestAction", "display_name": "Bridge Test Action",
		"ace_type": "action", "category": "Tests", "codegen_template": "pass"}
	var holder_script: GDScript = GDScript.new()
	holder_script.source_code = "extends RefCounted
func get_provider_id() -> String:
	return \"BridgeTestProvider\"
"
	holder_script.reload()
	var holder: RefCounted = holder_script.new()
	EventForgeBridgeRuntime.new().register_provider(holder, [descriptor])
	var by_provider: ACEDescriptor = ACERegistry.find_descriptor("BridgeTestProvider", "BridgeTestAction")
	EventForgeBridgeRuntime.new().unregister_provider("BridgeTestProvider")
	var source: String = FileAccess.get_file_as_string("res://addons/eventforge/plugin.gd")
	return SUPPORT.pins(P, [
		["the old line by path is recognised", EventForgePlugin.is_old_bridge_autoload("*res://addons/eventforge/runtime/eventforge_bridge.gd"), true],
		["the old line by uid is recognised", old_by_uid, true],
		["a project's own autoload under the same name is left alone", EventForgePlugin.is_old_bridge_autoload("*res://my_bridge.gd"), false],
		["an unknown uid is left alone", EventForgePlugin.is_old_bridge_autoload("*uid://zzzzzzzzzzzzz"), false],
		["a provider registered in code is in the vocabulary with no autoload", by_provider != null, true],
		["nothing in the plugin adds the autoload", source.contains("add_autoload_singleton(BRIDGE_NAME"), false],
		["unregistering takes it out again", ACERegistry.find_descriptor("BridgeTestProvider", "BridgeTestAction") == null, true],
	])
