# EventForge — Plugin entry point
@tool
extends EditorPlugin
class_name EventForgePlugin

const BRIDGE_NAME: String = "EventForgeBridge"
const BRIDGE_PATH: String = "res://addons/eventforge/runtime/eventforge_bridge.gd"

## Returns the display name of the plugin.
func _get_plugin_name() -> String:
return "EventForge"

## Registers plugin services when the plugin is enabled.
func _enter_tree() -> void:
add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)
print("[EventForge] v0.1.0 loaded")

## Unregisters plugin services when the plugin is disabled.
func _exit_tree() -> void:
remove_autoload_singleton(BRIDGE_NAME)
print("[EventForge] unloaded")
