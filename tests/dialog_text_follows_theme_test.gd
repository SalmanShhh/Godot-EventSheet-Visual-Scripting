@tool
extends RefCounted
# Godot EventSheets - dialog text follows the editor theme. A dialog's panels take their fill from
# the editor theme, so text on them must too: a fixed light grey reads on the dark theme and all but
# vanishes on the light one (the variable dialog's help strip did exactly that). This sweeps the
# dialog files for a font colour taken from the dark-only palette or a pale literal, and pins the
# light-panel rule of readable_on_panel.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "dialog_text_follows_theme_test"
## The windows that sit on editor-themed panels. The sheet canvas draws its own background and is
## deliberately not in this list.
const DIALOG_FILES: Array[String] = [
	"res://addons/eventsheet/editor/popup_ui.gd",
	"res://addons/eventsheet/editor/variable_dialog.gd",
	"res://addons/eventsheet/editor/function_dialog.gd",
	"res://addons/eventsheet/editor/param_dialog.gd",
	"res://addons/eventsheet/editor/ace_params_dialog.gd",
	"res://addons/eventsheet/editor/small_prompt.gd",
	"res://addons/eventsheet/editor/inspector_preview_card.gd",
	"res://addons/eventsheet/editor/dock/quick_prompt_dialogs.gd",
	"res://addons/eventsheet/editor/dock/variable_gestures.gd",
	"res://addons/eventsheet/editor/dock/verb_properties_popup.gd",
	"res://addons/eventsheet/editor/dock/function_inspector.gd",
	"res://addons/eventsheet/editor/dock/modes_dialog.gd",
	"res://addons/eventsheet/editor/dock/states_dialog.gd",
	"res://addons/eventsheet/editor/dock/new_resource_wizard.gd",
	"res://addons/eventsheet/editor/dock/welcome_window.gd",
	"res://addons/eventsheet/editor/dock/open_progress.gd",
	"res://addons/eventsheet/editor/dock/rail_panels.gd",
	"res://addons/eventsheet/editor/ace_picker.gd",
	"res://addons/eventsheet/editor/ace_params_expression_picker.gd",
	"res://addons/eventsheet/editor/ace_params_node_picker.gd",
	"res://addons/eventsheet/editor/dock/struct_row_dialogs.gd",
	"res://addons/eventsheet/editor/connect_signal_dialog.gd",
	"res://addons/eventsheet/editor/dock/paste_special_dialog.gd",
	"res://addons/eventsheet/editor/dock/insert_snippet_dialog.gd",
	"res://addons/eventsheet/editor/add_behavior_dialog.gd",
	"res://addons/eventsheet/editor/dock/new_addon_panel.gd",
	"res://addons/eventsheet/editor/dock/own_members_window.gd",
	"res://addons/eventsheet/editor/dock/compare_condition_dialog.gd",
	"res://addons/eventsheet/editor/dock/comment_and_scope_dialogs.gd",
	"res://addons/eventsheet/editor/dock/insert_object_dialog.gd",
	"res://addons/eventsheet/editor/dock/class_properties.gd",
	"res://addons/eventsheet/editor/inspector_designer_dialog.gd",
	"res://addons/eventsheet/editor/dock/start_page.gd",
	"res://addons/eventsheet/editor/dock/tour_window.gd",
	"res://addons/eventsheet/editor/new_sheet_dialog.gd",
	"res://addons/eventsheet/editor/dock/sheet_type_dialog.gd",
	"res://addons/eventsheet/editor/dock/include_manager.gd",
	"res://addons/eventsheet/editor/dock/import_sheet_wizard.gd",
]


static func run() -> bool:
	var dark_only: RegEx = RegEx.create_from_string("\"font_color\",\\s*(EventSheetPalette\\.TEXT_|Color\\((0\\.[6-9]|1\\.0))")
	# A tinted modulate is the same fixed colour by another door: it multiplies a pale tint into the
	# text instead of following the theme. A white one with an alpha only dims, which reads on both.
	var tinted: RegEx = RegEx.create_from_string("modulate\\s*=\\s*Color\\(0\\.")
	var offenders: Array[String] = []
	for path: String in DIALOG_FILES:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			if dark_only.search(lines[index]) != null or tinted.search(lines[index]) != null:
				offenders.append("%s:%d" % [path.get_file(), index + 1])
	var light_panel_red: Color = Color(0.95, 0.5, 0.5).darkened(0.45)
	return SUPPORT.pins(NAME, [
		["no dialog text takes a dark-theme-only colour", offenders, [] as Array[String]],
		["outside the editor the primary text keeps the palette value", EventSheetPopupUI.text_color(), EventSheetPalette.TEXT_PRIMARY],
		["outside the editor the muted text keeps the palette value", EventSheetPopupUI.muted_text_color(), EventSheetPalette.TEXT_MUTED],
		["a dark panel leaves a tone as it is", EventSheetPopupUI.readable_on_panel(Color(0.95, 0.5, 0.5)), Color(0.95, 0.5, 0.5)],
		["the light-panel tone is darker than the dark-panel one", light_panel_red.get_luminance() < Color(0.95, 0.5, 0.5).get_luminance(), true],
	])
