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


func _init() -> void:
	for theme_name: String in PALETTES.keys():
		var palette: Dictionary = PALETTES[theme_name]
		var path: String = "res://demo/themes/%s_theme.tres" % theme_name
		var error: Error = ResourceSaver.save(_build_style(palette), path)
		print("[build_theme_presets] %s -> %s (%d)" % [theme_name, path, error])
	quit(0)


func _build_style(palette: Dictionary) -> EventSheetEditorStyle:
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
	return style
