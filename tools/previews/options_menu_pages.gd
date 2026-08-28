# Godot EventSheets - the two pages the options rows build (preview module).
#
# Rendered by tools/render_previews.gd. Nothing here is drawn for the picture: both columns are built
# by the SHIPPED pack from declarations and from the Input Map, exactly as a game builds them, so the
# picture cannot drift from the behaviour.
#
#   THE DECLARED PAGE   four Declare Setting rows tagged with a page, and the rows that follow from
#                       them: the label each declaration gave, the control its kind asks for, every
#                       one bound both ways and showing the value in force.
#   THE CONTROLS PAGE   one row per action the Input Map declares, keyboard and pad in their own
#                       columns, with a reset. The bindings staged here are the ones a project ships.
@tool
extends RefCounted

const PREVIEW_NAME: String = "options-menu-pages"
const PREVIEW_SIZE: Vector2i = Vector2i(980, 220)

## The shipped pack, reached by path: this runs before any class cache is a given, and the pack's own
## class name is not what the picture is about.
const PACK_PATH: String = "res://eventsheet_addons/game_settings/game_settings_addon.gd"

## The staged controls, and the keys they answer to. Named as a game's own would be, because the page
## reads their names back as its labels.
const STAGED_BINDINGS: Array[Array] = [["move_left", KEY_A], ["jump", KEY_SPACE], ["interact", KEY_E]]


static func build(host: Window) -> Control:
	var settings: Node = (load(PACK_PATH) as GDScript).new()
	var stage: HBoxContainer = HBoxContainer.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_theme_constant_override("separation", 24)
	host.add_child(stage)
	# The pack is a Node with signals the pages connect to, so it is parented rather than held: the
	# picture is of a live menu, not of a snapshot.
	stage.add_child(settings)
	settings.call("declare_setting", "fullscreen", false, "toggle", "", "Video", "")
	settings.call("declare_setting", "quality", "Medium", "choice", "Low|Medium|High", "Video", "Graphics quality")
	settings.call("declare_setting", "resolution_scale", 100, "percent", "", "Video", "Resolution scale")
	settings.call("declare_setting", "screen_shake", true, "toggle", "", "Video", "Screen shake")
	stage.add_child(_titled("Video, from the declarations", settings, "page"))
	_stage_bindings()
	stage.add_child(_titled("Controls, from the Input Map", settings, "controls"))
	return stage


## One captioned column: the heading, then whichever page the pack builds into it.
static func _titled(heading: String, settings: Node, kind: String) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	var title: Label = Label.new()
	title.text = heading
	column.add_child(title)
	var page: VBoxContainer = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	column.add_child(page)
	if kind == "page":
		settings.call("build_settings_page", page, "Video")
	else:
		settings.call("build_controls_page", page)
	return column


## The Input Map a project would have shipped. Added at run time so the picture does not depend on
## this repository's own project settings, and left behind: the harness is a throwaway process.
static func _stage_bindings() -> void:
	for pair: Array in STAGED_BINDINGS:
		var action: String = str(pair[0])
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		var press: InputEventKey = InputEventKey.new()
		press.keycode = int(pair[1])
		InputMap.action_add_event(action, press)
