@tool
class_name EventSheetPalette
extends RefCounted

const ROW_HEIGHT := 28
const INDENT_WIDTH := 18
const FONT_SIZE := 13
const GUTTER_WIDTH := 20
const ICON_SIZE := 10
const ROW_HORIZONTAL_PADDING := 10.0
const SPAN_GAP := 6.0
const LANE_DIVIDER_WIDTH := 2.0
const CONDITIONS_LANE_RATIO := 0.38
const MIN_CONDITIONS_LANE_WIDTH := 160.0
const ACTION_LANE_PADDING := 8.0

const BG_0 = Color("#1e1f24")
const BG_1 = Color("#24262d")
const TEXT_PRIMARY = Color("#d7dae0")
const TEXT_SECONDARY = Color("#9aa1ad")
const TEXT_MUTED = Color("#6f7580")
const COLOR_OBJECT = Color("#6bb6ff")
const COLOR_ACTION = Color("#ffd166")
const COLOR_TRIGGER = Color("#d291ff")
const COLOR_VALUE = Color("#7ee787")
const COLOR_COMMENT = Color("#7f848e")
const COLOR_SELECTION = Color(0.36, 0.51, 0.79, 0.22)
const COLOR_HOVER = Color(1.0, 1.0, 1.0, 0.045)
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
const COLOR_DISABLED = Color(0.0, 0.0, 0.0, 0.35)
