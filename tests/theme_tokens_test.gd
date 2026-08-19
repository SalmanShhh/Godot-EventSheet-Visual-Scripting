# Godot EventSheets - the theme token contract
#
# A token is only real when all four of these hold, and each one has broken at least once:
#   1. It EXISTS on a style resource, so a `.tres` can carry it and the reflective Theme Editor form
#      can show it (the form enumerates exported properties - a colour that lives in a `const` is
#      invisible there forever).
#   2. It has a DESCRIPTION in the Theme Editor, in the sheet's own words. A token with no entry
#      falls back to its identifier, which is how "Ace Action Badge Background Color" ends up on a
#      designer's screen.
#   3. It ROUND-TRIPS: saved to a `.tres` and loaded back, the value survives.
#   4. Every bundled PRESET has an opinion about it. A preset that skipped it keeps the plugin's own
#      dark default, which is exactly wrong on a pale theme - dark chips on white paper.
#
# Plus a source lint: no new literal Color in the files that paint the sheet and its bars. That is
# how the reading program's marks became unthemable in the first place - each one was one more
# `Color("#...")` in a painter, and no gate said otherwise.
@tool
class_name ThemeTokensTest
extends RefCounted

## The presets that must dress every token. All of them: the six generated from well-known palettes,
## the three hand-written ones, and the bundled Mockup Slate.
const PRESET_PATHS := [
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
	"res://demo/themes/catppuccin_mocha_theme.tres",
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://addons/eventsheet/themes/mockup_slate_theme.tres",
]

## The painters that must never grow a new literal colour. Deliberately the files that draw the
## SHEET and the bars around it - the surface this contract is about. A literal inside a comment or
## inside a `Color.from_string` parse of USER data is not a paint and is not counted.
const LINTED_PAINTERS := [
	"res://addons/eventsheet/editor/event_row_renderer.gd",
	"res://addons/eventsheet/editor/interaction/viewport_row_builder.gd",
	"res://addons/eventsheet/editor/objects_panel.gd",
]

## What each linted painter is still allowed to spell literally, and why. Every entry is a colour
## that is not a THEME decision: a transparent sentinel, an icon's own ink, or a value parsed out of
## the user's own sheet. Anything not on this list is a regression.
const LINT_ALLOWANCES := {
	"event_row_renderer.gd": [
		# The hit-count chip family and the object-icon plate: the debugger's own lens chrome and a
		# neutral plate, both drawn over whatever the row is, neither a token a theme would set.
		"HIT_CHIP", "OBJECT_ICON_PLATE", "CODE_CELL",
		# A transparent sentinel: "this row asked for no tint at all".
		"Color(0.0, 0.0, 0.0, 0.0)",
	],
	"viewport_row_builder.gd": [
		# A generated folder icon's ink, and transparent sentinels meaning "no badge disc".
		"folder_tone", "Color(0.0, 0.0, 0.0, 0.0)", "Color(0, 0, 0, 0)", "Color.WHITE",
	],
	"objects_panel.gd": [],
}


static func run() -> bool:
	var ok: bool = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()

	# ── 1. The token families exist as sub-styles the Theme Editor can enumerate ──────────────
	ok = _check("a fresh style has reading tokens", style.get_reading_style() is EventSheetReadingStyle, true) and ok
	ok = _check("a fresh style has chrome tokens", style.get_chrome_style() is EventSheetChromeStyle, true) and ok
	ok = _check("a fresh style has Manual tokens", style.get_manual_style() is EventSheetManualStyle, true) and ok

	# The exact token names, pinned as VALUES: a rename is a theme-file break for everyone who saved
	# a preset, so it has to be a deliberate edit here rather than a silent one in the resource.
	ok = _check("reading token names", _token_names(style.get_reading_style()), [
		"plain_chip_background_color", "plain_chip_foreground_color",
		"pattern_chip_background_color", "pattern_chip_foreground_color",
		"category_chip_background_color", "category_chip_foreground_color",
		"inspector_chip_background_color", "inspector_chip_foreground_color",
		"constant_badge_background_color", "constant_badge_foreground_color",
		"setup_badge_background_color", "setup_badge_foreground_color",
		"code_badge_background_color", "code_badge_foreground_color",
		"lift_note_badge_background_color", "lift_note_badge_foreground_color",
		"or_badge_background_color", "or_badge_foreground_color",
		"tempo_every_tick_background_color", "tempo_every_tick_foreground_color",
		"tempo_input_background_color", "tempo_input_foreground_color",
		"tempo_once_background_color", "tempo_once_foreground_color",
		"primary_text_color", "secondary_text_color", "muted_text_color",
		"string_value_color", "boolean_value_color",
		"error_text_color", "error_stripe_color", "firing_stripe_color", "disabled_row_color",
		"breakpoint_color", "runtime_error_color", "debugger_accent_color",
		"bookmark_color", "event_number_rail_color",
		"indent_guide_color", "tree_guide_color", "drag_line_color", "drag_refusal_color",
		"drag_bubble_refused_background_color", "drag_bubble_background_color", "drag_bubble_text_color",
		"text_selection_color", "default_chip_plate_color",
		"color_swatch_border_color", "name_highlight_strength",
	]) and ok
	ok = _check("chrome token names", _token_names(style.get_chrome_style()), [
		"object_bar_section_color", "object_bar_warning_color", "object_bar_hover_wash_color",
		"object_bar_grip_color", "object_bar_grip_active_color",
		# T13 - the Project bar is the Object bar's other tab, so its two tokens sit with them.
		"project_bar_heading_color", "project_bar_note_color",
		"status_text_color", "status_error_color", "row_address_color",
		"unsaved_dot_color", "title_path_color",
	]) and ok
	ok = _check("Manual token names", _token_names(style.get_manual_style()), [
		"page_background_color", "heading_color", "page_muted_text_color", "search_hit_color",
		"contents_active_background_color", "contents_active_text_color",
		"note_color", "table_hairline_color",
	]) and ok

	# ── 2. Every token the form shows has a description in the sheet's words ──────────────────
	# Not just "some string": the fallback IS the humanized identifier, so a missing entry looks like
	# a description until you read it. A description must differ from the fallback to count.
	var described_sections: Array = [
		style, style.get_event_style(), style.get_condition_style(), style.get_action_style(),
		style.get_reading_style(), style.get_chrome_style(), style.get_manual_style(),
	]
	var undescribed: Array[String] = []
	for section: Resource in described_sections:
		for token: Dictionary in EventSheetThemeEditor.editable_tokens(section):
			var token_name: String = str(token.get("name"))
			if EventSheetThemeEditor._token_description(token_name) == token_name.capitalize():
				undescribed.append(token_name)
	ok = _check("every token is described in plain words (undescribed: %s)" % str(undescribed),
		undescribed, [] as Array[String]) and ok

	# ── 3. Round-trip: a saved theme carries the new families back ────────────────────────────
	style.get_reading_style().error_stripe_color = Color(0.1, 0.2, 0.3, 1.0)
	style.get_chrome_style().row_address_color = Color(0.4, 0.5, 0.6, 1.0)
	style.get_manual_style().heading_color = Color(0.7, 0.8, 0.9, 1.0)
	var path: String = "user://eventsheet_theme_tokens_roundtrip.tres"
	ok = _check("theme saves", ResourceSaver.save(style, path), OK) and ok
	var loaded: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	ok = _check("theme loads back as an editor style", loaded != null, true) and ok
	if loaded != null:
		ok = _check("reading token survives the round trip",
			loaded.get_reading_style().error_stripe_color, Color(0.1, 0.2, 0.3, 1.0)) and ok
		ok = _check("chrome token survives the round trip",
			loaded.get_chrome_style().row_address_color, Color(0.4, 0.5, 0.6, 1.0)) and ok
		ok = _check("Manual token survives the round trip",
			loaded.get_manual_style().heading_color, Color(0.7, 0.8, 0.9, 1.0)) and ok

	# ── 4. Every bundled preset dresses the new marks in ITS palette ──────────────────────────
	var defaults: EventSheetEditorStyle = EventSheetEditorStyle.new()
	for preset_path: String in PRESET_PATHS:
		var preset: EventSheetEditorStyle = load(preset_path) as EventSheetEditorStyle
		var preset_name: String = preset_path.get_file()
		if preset == null:
			ok = _check("preset loads: %s" % preset_name, false, true) and ok
			continue
		# Loading must not need a missing key to be filled in by hand - a preset written before these
		# families existed still has to resolve every one of them.
		ok = _check("%s resolves all three new families" % preset_name,
			preset.get_reading_style() != null and preset.get_chrome_style() != null
				and preset.get_manual_style() != null, true) and ok
		ok = _check("%s dresses the reading chips itself (not EventForge's)" % preset_name,
			preset.get_reading_style().plain_chip_background_color
				!= defaults.get_reading_style().plain_chip_background_color, true) and ok
		ok = _check("%s dresses its own status strip" % preset_name,
			preset.get_chrome_style().status_text_color
				!= defaults.get_chrome_style().status_text_color, true) and ok
		# The point of deriving rather than defaulting: a PALE preset must end up with pale chips, or
		# a dark plate lands on white paper. Checked against the preset's own row background.
		var row_background: Color = preset.get_event_style().row_background_color
		var chip: Color = preset.get_reading_style().plain_chip_background_color
		ok = _check("%s keeps its chips on the same side of light as its rows" % preset_name,
			(chip.get_luminance() > 0.5) == (row_background.get_luminance() > 0.5), true) and ok

	# ── 5. The Godot-adaptive default derives them too, on a light editor as well as a dark one ─
	for editor_base: Color in [Color("#252525"), Color("#e8e8e8")]:
		var adapted: EventSheetEditorStyle = EventSheetEditorStyle.new()
		EventSheetGodotTheme.apply(adapted, editor_base, editor_base.darkened(0.15),
			editor_base.darkened(0.25), Color("#569eff"),
			Color("#202020") if editor_base.get_luminance() > 0.5 else Color("#ced0d2"))
		var adapted_chip: Color = adapted.get_reading_style().plain_chip_background_color
		ok = _check("the editor-matched default keeps chips on the editor's side of light (base %s)"
			% editor_base.to_html(false),
			(adapted_chip.get_luminance() > 0.5) == (editor_base.get_luminance() > 0.5), true) and ok

	# ── 6. The lint: a painter must not grow a new literal colour ─────────────────────────────
	var literal: RegEx = RegEx.create_from_string(
		"Color\\(\\s*[\\d.]|Color\\(\"#|Color\\.[A-Z]")
	for painter_path: String in LINTED_PAINTERS:
		var allowances: Array = LINT_ALLOWANCES.get(painter_path.get_file(), [])
		var offenders: Array[String] = []
		var line_number: int = 0
		for line: String in FileAccess.get_file_as_string(painter_path).split("\n"):
			line_number += 1
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("#") or literal.search(line) == null:
				continue
			var excused: bool = false
			for allowance: String in allowances:
				if line.contains(allowance):
					excused = true
					break
			if not excused:
				offenders.append("%d: %s" % [line_number, trimmed.left(80)])
		ok = _check("no unthemed literal colour in %s (%s)" % [painter_path.get_file(), str(offenders)],
			offenders, [] as Array[String]) and ok

	return ok


## The exported token names of a style resource, in declaration order - what the Theme Editor's form
## enumerates, and therefore what a designer sees.
static func _token_names(style_resource: Resource) -> Array:
	var names: Array = []
	for token: Dictionary in EventSheetThemeEditor.editable_tokens(style_resource):
		names.append(str(token.get("name")))
	return names


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] theme_tokens_test: %s" % label)
		return true
	print("[FAIL] theme_tokens_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
