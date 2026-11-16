# Godot EventSheets - The quiet words of the Manual read in both editor brightnesses, and the light
# demo theme wears the amber that reads on a light sheet.
#
# Editor Native's quiet sheet words were raised to read at 4.5 to 1; the Manual's quiet words (its
# breadcrumbs, captions and the helpful prompt) come from the same theme and must read too, on the
# editor's own ground, dark and light. The light demo theme stores its amber; it must be the amber the
# shared rule now gives a light sheet, or every finding on it reads tan on cream.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_leftovers_test"
const LIGHT_DEMO := "res://demo/themes/solarized_light_theme.tres"


static func run() -> bool:
	var ok: bool = true
	for base: Color in [EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE, EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE]:
		var shown: EventSheetEditorStyle = EventSheetEditorThemeDeriver.default_style_for(base)
		var muted: Color = shown.get_manual_style().page_muted_text_color
		ok = SUPPORT.check(P, "the Manual's quiet words read at 4.5 on the editor's ground %s" % base.to_html(false),
			EventSheetEditorThemeDeriver.contrast_ratio(muted, base) >= 4.5, true) and ok
	var starter: EventSheetEditorStyle = load(EventSheetEditorThemeDeriver.NATIVE_STARTER_PATH) as EventSheetEditorStyle
	ok = SUPPORT.check(P, "the starter file stores the Manual's quiet words as the sheet's quiet words",
		starter.get_manual_style().page_muted_text_color, starter.get_reading_style().muted_text_color) and ok
	if ResourceLoader.exists(LIGHT_DEMO):
		var light: EventSheetEditorStyle = load(LIGHT_DEMO) as EventSheetEditorStyle
		var row: Color = light.get_event_style().row_background_color
		var amber: Color = light.get_chrome_style().object_bar_warning_color
		ok = SUPPORT.check(P, "the light demo theme's finding amber reads at 4.5 on its rows",
			EventSheetEditorThemeDeriver.contrast_ratio(amber, row) >= 4.5, true) and ok
	return ok
