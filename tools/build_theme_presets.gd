# Godot EventSheets - iconic theme preset builder
# Generates the bundled "iconic" presets from well-known editor palettes (Dracula, Nord,
# Gruvbox Dark, Monokai, Solarized Light, Catppuccin Mocha) so the sheet can match the
# themes people already live in. Rerun after token additions:
#   <godot> --headless --path . --script tools/build_theme_presets.gd
# Every token is mapped deliberately: bg/alt from the palette's background pair,
# conditions take the palette's cool accent, actions the warm/green accent, groups the
# signature color, comments the palette's comment color.
@tool
extends SceneTree

# {name: {bg, bg_alt, surface, line, fg, comment, cool, warm, signature, yellow}}
const PALETTES: Dictionary = {
	"dracula": {
		"bg": "#282a36", "bg_alt": "#2c2f3d", "surface": "#44475a", "line": "#191a21",
		"fg": "#f8f8f2", "comment": "#6272a4", "cool": "#8be9fd", "warm": "#50fa7b",
		"signature": "#bd93f9", "yellow": "#f1fa8c"
	},
	"nord": {
		"bg": "#2e3440", "bg_alt": "#333a47", "surface": "#3b4252", "line": "#272c36",
		"fg": "#eceff4", "comment": "#616e88", "cool": "#88c0d0", "warm": "#a3be8c",
		"signature": "#81a1c1", "yellow": "#ebcb8b"
	},
	"gruvbox_dark": {
		"bg": "#282828", "bg_alt": "#2e2c2a", "surface": "#3c3836", "line": "#1d2021",
		"fg": "#ebdbb2", "comment": "#928374", "cool": "#83a598", "warm": "#b8bb26",
		"signature": "#fe8019", "yellow": "#fabd2f"
	},
	"monokai": {
		"bg": "#272822", "bg_alt": "#2c2d26", "surface": "#3e3d32", "line": "#1e1f1c",
		"fg": "#f8f8f2", "comment": "#75715e", "cool": "#66d9ef", "warm": "#a6e22e",
		"signature": "#f92672", "yellow": "#e6db74"
	},
	"solarized_light": {
		"bg": "#fdf6e3", "bg_alt": "#f5eed9", "surface": "#eee8d5", "line": "#d9d2c2",
		"fg": "#657b83", "comment": "#93a1a1", "cool": "#268bd2", "warm": "#859900",
		"signature": "#6c71c4", "yellow": "#b58900"
	},
	"catppuccin_mocha": {
		"bg": "#1e1e2e", "bg_alt": "#232336", "surface": "#313244", "line": "#11111b",
		"fg": "#cdd6f4", "comment": "#7f849c", "cool": "#89dceb", "warm": "#a6e3a1",
		"signature": "#cba6f7", "yellow": "#f9e2af"
	}
}

# The native-look tokens of each palette, designed from that palette's own accents: numbers in its
# green, text in its orange, true/false in its blue, vectors and the Include line in its teal or
# aqua, colours in its pink, enums and the comment edge in its yellow, lists and the inner-class
# block in its purple. Every word and glyph colour was checked against the surface it is drawn on
# (the lanes, a variable row, the Include bar, the class block, its badge tile) for at least 4.5:1,
# and nudged in lightness only, hue kept, where the palette's own value fell short.
const NATIVE: Dictionary = {
	"dracula": {
		"type_number_color": "#50fa7b",
		"type_text_color": "#ffb86c",
		"type_bool_color": "#9aa9e6",
		"type_vector_color": "#8be9fd",
		"type_color_color": "#ff79c6",
		"type_object_color": "#c4c8d8",
		"type_enum_color": "#f1fa8c",
		"type_collection_color": "#bd93f9",
		"type_class_color": "#ddc9fb",
		"word_variable_color": "#8be9fd",
		"word_text_color": "#ffb86c",
		"word_number_color": "#50fa7b",
		"word_keyword_color": "#a6adc9",
		"include_border_color": "#5a8a9a",
		"include_fill_color": "#384956",
		"include_tag_color": "#8be9fd",
		"include_name_color": "#d1e5ee",
		"include_note_color": "#b2e7f5",
		"class_border_color": "#6b598e",
		"class_fill_color": "#343246",
		"class_head_color": "#3d3951",
		"class_tag_color": "#c8abf5",
		"class_name_color": "#dedcec",
		"class_note_color": "#b7a5d7",
		"comment_border_color": "#80855b",
		"gutter_icon_color": "#b2b4bb",
		"selected_gutter_fill_color": "#585f80",
		"object_hairline_color": "#464853",
		"link_color": "#8be9fd",
		"inspector_badge_foreground_color": "#a4b2e9",
		"inspector_badge_background_color": "#3f4359",
		"range_badge_foreground_color": "#c6a1fa",
		"range_badge_background_color": "#463f5d",
		"tooltip_badge_foreground_color": "#f1fa8c",
		"tooltip_badge_background_color": "#505447",
		"saved_badge_foreground_color": "#50fa7b",
		"saved_badge_background_color": "#305444",
		"active_tab_edge_color": "#bd93f9",
	},
	"nord": {
		"type_number_color": "#a3be8c",
		"type_text_color": "#d69581",
		"type_bool_color": "#8aa7c5",
		"type_vector_color": "#8fbcbb",
		"type_color_color": "#d9919a",
		"type_object_color": "#c2cad8",
		"type_enum_color": "#ebcb8b",
		"type_collection_color": "#bc9ab6",
		"type_class_color": "#d4c0f0",
		"word_variable_color": "#88c0d0",
		"word_text_color": "#dca694",
		"word_number_color": "#a3be8c",
		"word_keyword_color": "#aab3c3",
		"include_border_color": "#5f787e",
		"include_fill_color": "#3e4a54",
		"include_tag_color": "#95c0bf",
		"include_name_color": "#d2dde1",
		"include_note_color": "#b5cfd1",
		"class_border_color": "#6a5d71",
		"class_fill_color": "#393b49",
		"class_head_color": "#41414f",
		"class_tag_color": "#c2a8c0",
		"class_name_color": "#dedde5",
		"class_note_color": "#b4a5b7",
		"comment_border_color": "#807661",
		"gutter_icon_color": "#b3b7be",
		"selected_gutter_fill_color": "#516276",
		"object_hairline_color": "#4b505b",
		"link_color": "#88c0d0",
		"inspector_badge_foreground_color": "#a5bcd3",
		"inspector_badge_background_color": "#3f4a5a",
		"range_badge_foreground_color": "#cab0c5",
		"range_badge_background_color": "#494656",
		"tooltip_badge_foreground_color": "#ebcb8b",
		"tooltip_badge_background_color": "#54524f",
		"saved_badge_foreground_color": "#b0c79c",
		"saved_badge_background_color": "#45504f",
		"active_tab_edge_color": "#88c0d0",
	},
	"gruvbox_dark": {
		"type_number_color": "#b8bb26",
		"type_text_color": "#fe8019",
		"type_bool_color": "#83a598",
		"type_vector_color": "#8ec07c",
		"type_color_color": "#fb6a5a",
		"type_object_color": "#bdae93",
		"type_enum_color": "#fabd2f",
		"type_collection_color": "#d3869b",
		"type_class_color": "#e0bfc0",
		"word_variable_color": "#89a99d",
		"word_text_color": "#fe8019",
		"word_number_color": "#b8bb26",
		"word_keyword_color": "#aea08d",
		"include_border_color": "#5b7452",
		"include_fill_color": "#384035",
		"include_tag_color": "#8ec07c",
		"include_name_color": "#d1ddd3",
		"include_note_color": "#b4d0ad",
		"class_border_color": "#75525c",
		"class_fill_color": "#363031",
		"class_head_color": "#403538",
		"class_tag_color": "#d8a2b2",
		"class_name_color": "#e1dbe1",
		"class_note_color": "#c19faa",
		"comment_border_color": "#84692b",
		"gutter_icon_color": "#b2b3b7",
		"selected_gutter_fill_color": "#4e5d57",
		"object_hairline_color": "#464647",
		"link_color": "#83a598",
		"inspector_badge_foreground_color": "#95b2a7",
		"inspector_badge_background_color": "#3a413e",
		"range_badge_foreground_color": "#da99aa",
		"range_badge_background_color": "#4a3b3f",
		"tooltip_badge_foreground_color": "#fabd2f",
		"tooltip_badge_background_color": "#524629",
		"saved_badge_foreground_color": "#b8bb26",
		"saved_badge_background_color": "#454528",
		"active_tab_edge_color": "#fe8019",
	},
	"monokai": {
		"type_number_color": "#a6e22e",
		"type_text_color": "#fd971f",
		"type_bool_color": "#66d9ef",
		"type_vector_color": "#a1efe4",
		"type_color_color": "#fa5c94",
		"type_object_color": "#c2c2b0",
		"type_enum_color": "#e6db74",
		"type_collection_color": "#ae81ff",
		"type_class_color": "#d6c6fb",
		"word_variable_color": "#66d9ef",
		"word_text_color": "#fd971f",
		"word_number_color": "#a6e22e",
		"word_keyword_color": "#ada78f",
		"include_border_color": "#648c83",
		"include_fill_color": "#3b4841",
		"include_tag_color": "#a1efe4",
		"include_name_color": "#d5e7e8",
		"include_note_color": "#beeae6",
		"class_border_color": "#645085",
		"class_fill_color": "#322f34",
		"class_head_color": "#3a3441",
		"class_tag_color": "#be9ff8",
		"class_name_color": "#dddaeb",
		"class_note_color": "#b09dd6",
		"comment_border_color": "#7a7646",
		"gutter_icon_color": "#b1b3b5",
		"selected_gutter_fill_color": "#417278",
		"object_hairline_color": "#454642",
		"link_color": "#66d9ef",
		"inspector_badge_foreground_color": "#66d9ef",
		"inspector_badge_background_color": "#344b4b",
		"range_badge_foreground_color": "#bd98ff",
		"range_badge_background_color": "#423a4e",
		"tooltip_badge_foreground_color": "#e6db74",
		"tooltip_badge_background_color": "#4d4c32",
		"saved_badge_foreground_color": "#a6e22e",
		"saved_badge_background_color": "#404d24",
		"active_tab_edge_color": "#f92672",
	},
	"solarized_light": {
		"type_number_color": "#627000",
		"type_text_color": "#b94414",
		"type_bool_color": "#1f70a9",
		"type_vector_color": "#1f7770",
		"type_color_color": "#c42b75",
		"type_object_color": "#586e75",
		"type_enum_color": "#876600",
		"type_collection_color": "#5c61bd",
		"type_class_color": "#736297",
		"word_variable_color": "#1d6aa0",
		"word_text_color": "#b24213",
		"word_number_color": "#5d6b00",
		"word_keyword_color": "#5b6969",
		"include_border_color": "#93ccbe",
		"include_fill_color": "#dbe8d7",
		"include_tag_color": "#1d706a",
		"include_name_color": "#284142",
		"include_note_color": "#296b67",
		"class_border_color": "#bcbad5",
		"class_fill_color": "#f1ebe1",
		"class_head_color": "#e9e3df",
		"class_tag_color": "#575b96",
		"class_name_color": "#2e303b",
		"class_note_color": "#65678b",
		"comment_border_color": "#dec680",
		"gutter_icon_color": "#5f5e5c",
		"selected_gutter_fill_color": "#bcd6de",
		"object_hairline_color": "#dbd5c6",
		"link_color": "#1f71ab",
		"inspector_badge_foreground_color": "#1b6498",
		"inspector_badge_background_color": "#d2e1e0",
		"range_badge_foreground_color": "#4f55b8",
		"range_badge_background_color": "#e0dbdd",
		"tooltip_badge_foreground_color": "#7a5d00",
		"tooltip_badge_background_color": "#efe0b6",
		"saved_badge_foreground_color": "#5b6900",
		"saved_badge_background_color": "#e5e3b6",
		"active_tab_edge_color": "#268bd2",
	},
	"catppuccin_mocha": {
		"type_number_color": "#a6e3a1",
		"type_text_color": "#fab387",
		"type_bool_color": "#89b4fa",
		"type_vector_color": "#94e2d5",
		"type_color_color": "#f5c2e7",
		"type_object_color": "#a6adc8",
		"type_enum_color": "#f9e2af",
		"type_collection_color": "#cba6f7",
		"type_class_color": "#e8ecff",
		"word_variable_color": "#89b4fa",
		"word_text_color": "#fab387",
		"word_number_color": "#a6e3a1",
		"word_keyword_color": "#999fb6",
		"include_border_color": "#598082",
		"include_fill_color": "#313d49",
		"include_tag_color": "#94e2d5",
		"include_name_color": "#d2e3e5",
		"include_note_color": "#b7e3de",
		"class_border_color": "#6c5b88",
		"class_fill_color": "#2c293e",
		"class_head_color": "#36314a",
		"class_tag_color": "#d2b8f3",
		"class_name_color": "#dfddeb",
		"class_note_color": "#bbacd5",
		"comment_border_color": "#7d7366",
		"gutter_icon_color": "#aeb0b9",
		"selected_gutter_fill_color": "#4b5d84",
		"object_hairline_color": "#3d3e4c",
		"link_color": "#89b4fa",
		"inspector_badge_foreground_color": "#89b4fa",
		"inspector_badge_background_color": "#333c57",
		"range_badge_foreground_color": "#cba6f7",
		"range_badge_background_color": "#413956",
		"tooltip_badge_foreground_color": "#f9e2af",
		"tooltip_badge_background_color": "#4a4548",
		"saved_badge_foreground_color": "#a6e3a1",
		"saved_badge_background_color": "#394545",
		"active_tab_edge_color": "#cba6f7",
	}
}


func _init() -> void:
	for theme_name: String in PALETTES.keys():
		var palette: Dictionary = PALETTES[theme_name]
		var path: String = "res://demo/themes/%s_theme.tres" % theme_name
		var error: Error = ResourceSaver.save(_build_style(palette, theme_name), path)
		print("[build_theme_presets] %s -> %s (%d)" % [theme_name, path, error])
	quit(0)


func _build_style(palette: Dictionary, theme_name: String) -> EventSheetEditorStyle:
	var bg: Color = Color(str(palette.get("bg")))
	var bg_alt: Color = Color(str(palette.get("bg_alt")))
	var surface: Color = Color(str(palette.get("surface")))
	var line: Color = Color(str(palette.get("line")))
	var fg: Color = Color(str(palette.get("fg")))
	var comment: Color = Color(str(palette.get("comment")))
	var cool: Color = Color(str(palette.get("cool")))
	var warm: Color = Color(str(palette.get("warm")))
	var signature: Color = Color(str(palette.get("signature")))
	var yellow: Color = Color(str(palette.get("yellow")))
	var dark: bool = bg.v < 0.5

	var event_style: EventSheetEventStyle = EventSheetEventStyle.new()
	event_style.sheet_background_color = bg
	event_style.row_background_color = bg
	event_style.row_background_alt_color = bg_alt
	event_style.row_border_color = line
	event_style.lane_divider_color = line
	# Lanes: a whisper of the lane accents over the background.
	event_style.condition_lane_color = bg.lerp(cool, 0.05)
	event_style.action_lane_color = bg.lerp(warm, 0.04)
	event_style.trigger_badge_background_color = signature
	event_style.trigger_badge_foreground_color = bg
	event_style.group_background_color = bg.lerp(signature, 0.10)
	event_style.group_background_alt_color = bg.lerp(signature, 0.16)
	event_style.group_accent_color = signature
	event_style.group_title_color = signature.lightened(0.25) if dark else signature.darkened(0.2)
	event_style.group_badge_background_color = signature
	event_style.group_badge_foreground_color = bg
	event_style.group_fold_background_color = surface
	event_style.comment_row_background_color = bg.lerp(yellow, 0.06)
	event_style.comment_text_color = comment
	event_style.selection_fill_color = Color(signature.r, signature.g, signature.b, 0.25)
	event_style.hover_fill_color = Color(signature.r, signature.g, signature.b, 0.10)
	event_style.column_header_background_color = surface
	event_style.column_header_conditions_color = cool
	event_style.column_header_actions_color = warm
	event_style.object_label_color = yellow
	event_style.value_highlight_color = cool
	event_style.behavior_accent_color = signature
	event_style.cell_hover_color = Color(fg.r, fg.g, fg.b, 0.12)
	# Corner + region styling (the newer theme tokens): a soft, modern rounded look shared across the
	# iconic presets so they stay current with the Default look's rounding capabilities.
	event_style.event_corner_radius = 8
	event_style.cell_corner_radius = 4
	event_style.group_corner_radius = 6
	event_style.region_corner_radius = 8
	event_style.region_line_width = 1
	# Language blocks and published verbs wear the PRESET'S own hues. Without this a regenerated
	# preset silently falls back to EventForge's indigo and amber/teal/purple and stops looking like
	# the theme it claims to be - which is exactly what happened the first time these were added by a
	# one-shot backfill instead of by the builder.
	event_style.language_block_accent_color = signature
	event_style.ace_action_accent_color = yellow
	event_style.ace_condition_accent_color = cool
	event_style.ace_expression_accent_color = signature
	event_style.ace_action_badge_background_color = bg.lerp(yellow, 0.28)
	event_style.ace_condition_badge_background_color = bg.lerp(cool, 0.28)
	event_style.ace_expression_badge_background_color = bg.lerp(signature, 0.28)
	event_style.verb_chip_background_color = surface
	event_style.verb_chip_foreground_color = fg
	# The event-number margin and the ✗ on an inverted condition sit OUTSIDE the lanes, so a preset
	# that skips them keeps EventForge's own near-black rail and its own red on a palette that asked
	# for neither. The margin is the sheet sunk a step, its numbers are the palette's comment tone,
	# and the ✗ is a red pulled a fifth of the way toward the palette's signature so it belongs here.
	event_style.gutter_background_color = bg.darkened(0.18) if dark else bg.darkened(0.06)
	event_style.gutter_text_color = comment
	event_style.invert_marker_color = Color("#e05c5c").lerp(signature, 0.20)
	# The head of the sheet (the class head row, an Include line in a theme that leaves the Include
	# fill clear): a quiet band a step toward the palette's surface, the way the editor draws a header.
	event_style.head_bar_color = bg.lerp(surface, 0.6)

	var condition_style: EventSheetElementStyle = EventSheetElementStyle.new()
	condition_style.text_color = cool
	condition_style.chip_background_color = Color(cool.r, cool.g, cool.b, 0.08)
	condition_style.chip_border_color = Color(cool.r, cool.g, cool.b, 0.20)
	condition_style.chip_hover_color = Color(cool.r, cool.g, cool.b, 0.30)
	condition_style.badge_background_color = surface
	condition_style.badge_foreground_color = cool

	var action_style: EventSheetElementStyle = EventSheetElementStyle.new()
	action_style.text_color = warm
	action_style.chip_background_color = Color(warm.r, warm.g, warm.b, 0.08)
	action_style.chip_border_color = Color(warm.r, warm.g, warm.b, 0.20)
	action_style.chip_hover_color = Color(warm.r, warm.g, warm.b, 0.30)
	action_style.badge_background_color = surface
	action_style.badge_foreground_color = warm

	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.event_style = event_style
	style.condition_style = condition_style
	style.action_style = action_style
	# The reading marks, the bars around the sheet and the Manual are derived from the tokens above
	# rather than listed again per palette: one rule, so a new token reaches all six presets the day
	# it ships instead of leaving them on EventForge's own dark marks.
	EventSheetThemeDerivation.fill_derived_tokens(style)
	var native: Dictionary = NATIVE.get(theme_name, {})
	for token_name: String in native:
		if token_name == "active_tab_edge_color":
			style.get_chrome_style().active_tab_edge_color = Color(str(native[token_name]))
		else:
			event_style.set(token_name, Color(str(native[token_name])))
	return style
