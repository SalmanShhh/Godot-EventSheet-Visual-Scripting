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

## The one file that knows both shapes of the pack's node, reached by path (see its header).
const NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"


func _can_handle(object: Object) -> bool:
	return is_feedback_player(object)


## Whether an object is a Juice Player (or an old Feedback Player, which is one), asked of the script
## it already carries. The base chain is walked so a project's own subclass of the pack's node is
## claimed too, exactly as `is` would.
static func is_feedback_player(object: Object) -> bool:
	# Most inspected objects carry no script at all: answer those without touching the names file.
	return object != null and object.get_script() != null and bool(load(NAMES_PATH).is_player(object))


func _parse_begin(object: Object) -> void:
	if is_feedback_player(object):
		add_custom_control(load(STRIP_PATH).new(object))
