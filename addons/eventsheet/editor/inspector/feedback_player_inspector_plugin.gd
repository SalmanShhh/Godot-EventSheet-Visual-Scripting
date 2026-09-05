# Godot EventSheets - the Feedback Player's Inspector (editor-only).
#
# One thing: the strip under the list - the count and the length of the beat, the buttons that play
# it in the editor, the debug timeline, and the two doors between this node's list and a moment
# file. The list itself is drawn by the shared card-list drawer through the ordinary `eventsheet:`
# marker on the export, so there is no second list editor here and nothing to keep in step.
#
# NOTHING HEAVY IS NAMED. The plugin is constructed at editor boot (add_inspector_plugin takes an
# instance), so a class named in this file is compiled at every editor start in every project -
# including projects with no feedback player in them. The strip is therefore reached BY PATH and the
# node this plugin claims is recognised by the name its script carries rather than by naming its
# class; both are loaded the first time an Inspector actually shows one.
@tool
class_name EventSheetFeedbackPlayerInspector
extends EditorInspectorPlugin

const STRIP_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"

## The class this plugin claims, as a NAME rather than as the class itself.
const PLAYER_CLASS: StringName = &"FeedbackPlayer"


func _can_handle(object: Object) -> bool:
	return is_feedback_player(object)


## Whether an object is a feedback player, asked of the script it already carries. The base chain is
## walked so a project's own subclass of the pack's node is claimed too, exactly as `is` would.
static func is_feedback_player(object: Object) -> bool:
	if object == null:
		return false
	var script: Script = object.get_script() as Script
	while script != null:
		if script.get_global_name() == PLAYER_CLASS:
			return true
		script = script.get_base_script()
	return false


func _parse_begin(object: Object) -> void:
	if is_feedback_player(object):
		add_custom_control(load(STRIP_PATH).new(object))
