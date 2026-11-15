# Godot EventSheets - the Juice Player's Inspector (editor-only).
#
# Says which nodes are Juice Players. The list is drawn by the shared card-list drawer through the
# ordinary `eventsheet:` marker on the export, and the strip of play buttons under it is that
# schema's footer, so there is no second list editor here and nothing to keep in step. (Godot asks
# the plugin registered LAST about a property first, and the attribute drawers are registered after
# this one, so claiming the list from here would never run and would lose its header and notes.)
#
# NOTHING HEAVY IS NAMED. The plugin is constructed at editor boot (add_inspector_plugin takes an
# instance), so a class named in this file is compiled at every editor start in every project -
# including projects with no feedback player in them. The strip is therefore reached BY PATH and the
# node this plugin claims is recognised by the name its script carries rather than by naming its
# class; both are loaded the first time an Inspector actually shows one.
@tool
class_name EventSheetFeedbackPlayerInspector
extends EditorInspectorPlugin

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

