# EventForge — Plugin entry point
# Registers the EventForge editor plugin and runtime bridge autoload.
@tool
extends EditorPlugin
class_name EventForgePlugin

const BRIDGE_NAME: String = "EventForgeBridge"
const BRIDGE_PATH: String = "res://addons/eventforge/runtime/eventforge_bridge.gd"
const EVENT_SHEET_EDITOR_PATH: String = "res://addons/eventforge/editor/event_sheet_editor.gd"

var _event_sheet_editor: Control = null
var _bottom_panel_button: Button = null

## Returns the display name of the plugin.
func _get_plugin_name() -> String:
	return "EventForge"

## Registers plugin services when the plugin is enabled.
func _enter_tree() -> void:
	add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)
	var editor_script: Script = load(EVENT_SHEET_EDITOR_PATH)
	if editor_script == null:
		push_warning("[EventForge] Failed to load editor script at %s" % EVENT_SHEET_EDITOR_PATH)
	else:
		_event_sheet_editor = editor_script.new()
		_bottom_panel_button = add_control_to_bottom_panel(_event_sheet_editor, "EventForge")
		# setup() is treated as an optional integration entrypoint.
		if _event_sheet_editor.has_method("setup"):
			_event_sheet_editor.call("setup")
		make_bottom_panel_item_visible(_event_sheet_editor)
	print("[EventForge] v0.1.0 loaded")

## Unregisters plugin services when the plugin is disabled.
func _exit_tree() -> void:
	if _event_sheet_editor != null:
		remove_control_from_bottom_panel(_event_sheet_editor)
		_event_sheet_editor.queue_free()
		_event_sheet_editor = null
	_bottom_panel_button = null
	remove_autoload_singleton(BRIDGE_NAME)
	print("[EventForge] unloaded")
