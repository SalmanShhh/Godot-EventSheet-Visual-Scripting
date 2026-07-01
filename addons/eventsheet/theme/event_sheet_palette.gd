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

# ── ACE role taxonomy ──────────────────────────────────────────────────────────────────────────
# The shared block-role colours for the function dialog's "kind of verb" cards + its live picker
# preview, and (later) the Behaviour Anatomy panel's Define-blocks. Action reuses the action-lane
# gold (COLOR_ACTION); Condition + Expression are kept DISTINCT from the trigger (#d291ff) / group
# purples so the three roles read as one legible colour family. Each carries a bright accent for the
# card + a tinted badge bg/fg pair for the pill.
const COLOR_CONDITION = Color("#5cc2a6")   # teal — a yes/no test
const COLOR_EXPRESSION = Color("#c07ad8")  # magenta-violet — a value (distinct from trigger/category purple)
const COLOR_ACE_ACTION_BADGE_BG = Color("#463414")
const COLOR_ACE_ACTION_BADGE_FG = Color("#f2c879")
const COLOR_ACE_CONDITION_BADGE_BG = Color("#123a30")
const COLOR_ACE_CONDITION_BADGE_FG = Color("#77d3b7")
const COLOR_ACE_EXPRESSION_BADGE_BG = Color("#3a2247")
const COLOR_ACE_EXPRESSION_BADGE_FG = Color("#d7a6ea")
# Chips reused by the preview: neutral param chips vs the picker-category chip.
const COLOR_CHIP_BG = Color("#2c313a")
const COLOR_CHIP_FG = Color("#9aa1ad")
const COLOR_CAT_CHIP_BG = Color("#34304f")
const COLOR_CAT_CHIP_FG = Color("#b3a8dd")

# ── Trigger tempo badges (glance layer §11) ──────────────────────────────────────────────────────
# How OFTEN an event runs, as a filled badge on the trigger row. SIGNAL keeps the shipped green arrow
# (from the event style) so the common case is byte-identical; the other three tempo classes get their
# own hot/cool/quiet fills here. Classified by TriggerResolver.tempo_class_for(trigger_id).
const COLOR_TEMPO_EVERY_TICK_BG = Color("#b5651d")  # ⟳ hot amber-orange — the per-frame hot path
const COLOR_TEMPO_EVERY_TICK_FG = Color("#ffeccc")
const COLOR_TEMPO_INPUT_BG = Color("#2f6bb0")       # ⌨ object blue — an input event
const COLOR_TEMPO_INPUT_FG = Color("#e3f0ff")
const COLOR_TEMPO_ONCE_BG = Color("#6a54b0")        # ▶ muted violet — runs once
const COLOR_TEMPO_ONCE_FG = Color("#efe8ff")

static func clamp_font_size(value: int) -> int:
	return max(value, MIN_FONT_SIZE)

static func resolve_font_size(base_size: int, delta: int = 0, offset: int = 0) -> int:
	return clamp_font_size(base_size + delta + offset)
