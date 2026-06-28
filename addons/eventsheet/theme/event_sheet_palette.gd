@tool
class_name EventSheetPalette
extends RefCounted

const ROW_HEIGHT := 28
const INDENT_WIDTH := 18
const FONT_SIZE := 13
const MIN_FONT_SIZE := 8
const GUTTER_WIDTH := 20
const ICON_SIZE := 10
const ROW_HORIZONTAL_PADDING := 10.0
const SPAN_GAP := 6.0
const LANE_DIVIDER_WIDTH := 2.0
const CONDITION_LANE_RATIO := 0.38
const MIN_CONDITIONS_LANE_WIDTH := 160.0
const CONDITION_LANE_PADDING := 8.0
const CONDITION_BADGE_COLUMN_WIDTH := 26.0
const ACTION_LANE_PADDING := 8.0

const BG_0 = Color("#1e1f24")
const BG_1 = Color("#24262d")
const TEXT_PRIMARY = Color("#d7dae0")
const TEXT_SECONDARY = Color("#9aa1ad")
const TEXT_MUTED = Color("#6f7580")
const COLOR_OBJECT = Color("#6bb6ff")
const COLOR_ACTION = Color("#ffd166")
const COLOR_TRIGGER = Color("#d291ff")
const COLOR_TRIGGER_ARROW_BG = Color("#2ea043")
const COLOR_TRIGGER_ARROW_FG = Color("#f0fff4")
const COLOR_VALUE = Color("#7ee787")
const COLOR_COMMENT = Color("#7f848e")
const COLOR_SELECTION = Color(0.36, 0.51, 0.79, 0.38)
const COLOR_HOVER = Color(1.0, 1.0, 1.0, 0.10)
const COLOR_GUIDE = Color(1.0, 1.0, 1.0, 0.08)
const COLOR_DEBUG = Color(0.49, 0.91, 0.53, 0.14)
const COLOR_DEBUG_TEXT = Color(0.58, 0.96, 0.64, 0.92)
const COLOR_DRAG_LINE = Color(0.56, 0.74, 1.0, 0.95)
const COLOR_GUTTER_BG = Color("#1a1b20")
const COLOR_GUTTER_TEXT = Color("#6f7580")
const COLOR_GUTTER_RAIL = Color("#2e3139")
const COLOR_LANE_CONDITIONS = Color(0.30, 0.56, 0.82, 0.08)
const COLOR_LANE_ACTIONS = Color(0.25, 0.66, 0.56, 0.06)
const COLOR_LANE_DIVIDER = Color("#2f3641")
const COLOR_BREAKPOINT = Color("#f26d7d")
const COLOR_BOOKMARK = Color("#e8c558")
const COLOR_DISABLED = Color(0.0, 0.0, 0.0, 0.35)
const COLOR_GROUP_BG = Color("#222139")
const COLOR_GROUP_BG_ALT = Color("#262444")
const COLOR_GROUP_ACCENT = Color("#8c78ff")
const COLOR_GROUP_TITLE = Color("#f2ecff")
const COLOR_GROUP_BADGE_BG = Color("#5b4db9")
const COLOR_GROUP_BADGE_FG = Color("#f4f0ff")
const COLOR_GROUP_FOLD_BG = Color(0.55, 0.48, 0.94, 0.20)
const COLOR_CONST_BADGE_BG = Color("#3e5c34")
const COLOR_CONST_BADGE_FG = Color("#eafde5")

static func clamp_font_size(value: int) -> int:
	return max(value, MIN_FONT_SIZE)

static func resolve_font_size(base_size: int, delta: int = 0, offset: int = 0) -> int:
	return clamp_font_size(base_size + delta + offset)
