# EventForge — Plugin entry point
# Registers the EventForge editor plugin and runtime bridge autoload.
@tool
extends EditorPlugin
class_name EventForgePlugin

const BRIDGE_NAME: String = "EventForgeBridge"
const BRIDGE_PATH: String = "res://addons/eventforge/runtime/eventforge_bridge.gd"

var _sheet_editor: EventSheetEditor = null
var _bottom_panel_button: Button = null

## Returns the display name of the plugin.
func _get_plugin_name() -> String:
    return "EventForge"

## Registers plugin services when the plugin is enabled.
func _enter_tree() -> void:
    add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)

    # Phase 2 MVP fallback: use a bottom panel shell until full main-screen integration lands.
    _sheet_editor = EventSheetEditor.new()
    _bottom_panel_button = add_control_to_bottom_panel(_sheet_editor, "EventForge")

    print("[EventForge] v0.1.0 loaded")

## Unregisters plugin services when the plugin is disabled.
func _exit_tree() -> void:
    if _sheet_editor != null:
        remove_control_from_bottom_panel(_sheet_editor)
        _sheet_editor.queue_free()
        _sheet_editor = null
    _bottom_panel_button = null

    remove_autoload_singleton(BRIDGE_NAME)
    print("[EventForge] unloaded")
