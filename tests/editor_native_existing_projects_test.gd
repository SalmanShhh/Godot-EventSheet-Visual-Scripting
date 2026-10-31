# Godot EventSheets - an updated project that never chose a look draws Editor Native
#
# Editor Native is the look of every sheet with no theme of its own, in a fresh install AND in a
# project that used the plugin before Editor Native became the default: no project setting holds the
# old look back. A sheet that chose a theme keeps it. Both halves are asked of the one function the
# viewport paints from, on Godot's own dark and light editor bases.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "editor_native_existing_projects_test"
const CLASSIC_PATH := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const STARTER_PATH := "res://addons/eventsheet/themes/editor_native_theme.tres"
## The setting an earlier draft gated the default behind; a project that wrote it off must not keep
## the old look either.
const OLD_GATE_SETTING := "eventsheets/editor/editor_native_by_default"


static func run() -> bool:
	var dark_base: Color = EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE
	var light_base: Color = EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE
	var had_gate: bool = ProjectSettings.has_setting(OLD_GATE_SETTING)
	ProjectSettings.set_setting(OLD_GATE_SETTING, false)
	var dark: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(null, dark_base)
	var light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(null, light_base)
	if not had_gate:
		ProjectSettings.set_setting(OLD_GATE_SETTING, null)
	var classic: EventSheetEditorStyle = load(CLASSIC_PATH) as EventSheetEditorStyle
	var kept: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(classic, dark_base)
	var kept_light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(classic, light_base)
	return SUPPORT.pins(TEST_NAME, [
		["no chosen look, dark editor: Editor Native's canvas and card",
			[dark.get_event_style().sheet_background_color.to_html(false),
			dark.get_event_style().row_background_color.to_html(false), dark.follow_editor_greys],
			["282828", "383838", true]],
		["no chosen look, light editor: Editor Native's canvas and card",
			[light.get_event_style().sheet_background_color.to_html(false),
			light.get_event_style().row_background_color.to_html(false), light.follow_editor_greys],
			["e4e4e4", "ffffff", true]],
		["a chosen look is kept as saved on a dark editor", kept == classic, true],
		["and on a light one", kept_light == classic, true],
		["outside the editor a chosen look is kept too",
			EventSheetEditorThemeDeriver.sheet_look(classic, Color(0.0, 0.0, 0.0, 0.0)) == classic, true],
		# A switch of the editor's theme while it runs re-seats the sheets that take their greys from
		# it, and leaves a theme with colours of its own alone.
		["an editor theme switch re-seats a sheet with no theme",
			EventSheetDock.reseats_on_editor_theme(EventSheetResource.new(), null), true],
		["and one wearing the Editor Native starter",
			EventSheetDock.reseats_on_editor_theme(EventSheetResource.new(), load(STARTER_PATH)), true],
		["but not one wearing Classic Sheet",
			EventSheetDock.reseats_on_editor_theme(EventSheetResource.new(), classic), false],
		["and nothing with no sheet open", EventSheetDock.reseats_on_editor_theme(null, null), false],
	])
