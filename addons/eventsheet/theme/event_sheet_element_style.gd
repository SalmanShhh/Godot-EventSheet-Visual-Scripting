@tool
class_name EventSheetElementStyle
extends Resource

const MIN_LINE_HEIGHT_EXTRA := 10

@export var text_color: Color = EventSheetPalette.TEXT_PRIMARY
@export var chip_background_color: Color = Color(1.0, 1.0, 1.0, 0.08)
@export var chip_border_color: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var chip_hover_color: Color = Color(1.0, 1.0, 1.0, 0.14)
@export var badge_background_color: Color = EventSheetPalette.COLOR_LANE_DIVIDER
@export var badge_foreground_color: Color = EventSheetPalette.TEXT_PRIMARY
# Negative deltas are intentional so a style asset can subtly soften chip text
# while EventSheetPalette.clamp_font_size() still guards readability.
@export_range(-2, 12, 1) var font_size_delta: int = 0
@export_range(0, 24, 1) var horizontal_padding: int = 8
@export_range(0, 16, 1) var vertical_padding: int = 2
@export_range(0, 24, 1) var gap_after: int = 8
@export_range(0, 12, 1) var corner_radius: int = 5
@export_range(0, 32, 1) var badge_extra_width: int = 12

func resolve_line_height(base_font_size: int, base_row_height: int) -> float:
	return max(
		float(base_row_height),
		float(base_font_size + font_size_delta + (vertical_padding * 2) + MIN_LINE_HEIGHT_EXTRA)
	)
