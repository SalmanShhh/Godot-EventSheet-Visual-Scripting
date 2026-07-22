@tool
class_name EventSheetEventStyle
extends Resource

@export var sheet_background_color: Color = EventSheetPalette.BG_0
@export var row_background_color: Color = EventSheetPalette.BG_0
@export var row_background_alt_color: Color = EventSheetPalette.BG_1
@export var row_border_color: Color = EventSheetPalette.COLOR_LANE_DIVIDER
@export var condition_lane_color: Color = EventSheetPalette.COLOR_LANE_CONDITIONS
@export var action_lane_color: Color = EventSheetPalette.COLOR_LANE_ACTIONS
@export var lane_divider_color: Color = EventSheetPalette.COLOR_LANE_DIVIDER
@export_range(0.20, 0.80, 0.01) var condition_lane_ratio: float = EventSheetPalette.CONDITION_LANE_RATIO
@export_range(120, 480, 1) var minimum_conditions_lane_width: int = int(EventSheetPalette.MIN_CONDITIONS_LANE_WIDTH)
@export_range(0, 32, 1) var condition_lane_padding: int = int(EventSheetPalette.CONDITION_LANE_PADDING)
@export_range(0, 64, 1) var condition_badge_column_width: int = int(EventSheetPalette.CONDITION_BADGE_COLUMN_WIDTH)
@export_range(0, 32, 1) var action_lane_padding: int = int(EventSheetPalette.ACTION_LANE_PADDING)
@export_range(1, 8, 1) var lane_divider_width: int = int(EventSheetPalette.LANE_DIVIDER_WIDTH)
@export_range(28, 200, 1) var minimum_row_height: int = EventSheetPalette.ROW_HEIGHT
## Height of GROUP header rows. Defaults to double the event row height so groups read as
## strong section bars (a C3 reflex); themes can pull it back down to the classic slim bar.
@export_range(28, 200, 1) var group_row_height: int = EventSheetPalette.GROUP_ROW_HEIGHT
## Fixed width of the object-name column inside the CONDITIONS lane, in pixels (the C3 sub-lane:
## object names left, condition text aligned at the column edge). Aligned by DEFAULT, so every row's
## text starts at the same x and the sheet scans as a table - the Construct look. 0 = flow, where the
## text instead follows each label and so starts at a different x on every row. Set by dragging the
## gap between an object name and its text, or here / in a theme.
## The value is LOGICAL pixels, like every other geometry token here, so it does not grow with the
## editor's display scale - on a HiDPI editor a long name elides sooner, and the column can be dragged
## (or themed) wider to suit.
@export_range(0, 480, 1) var condition_object_column_width: int = EventSheetPalette.OBJECT_COLUMN_WIDTH
## Fixed width of the object-name column inside the ACTIONS lane, in pixels. 0 = flow.
@export_range(0, 480, 1) var action_object_column_width: int = EventSheetPalette.OBJECT_COLUMN_WIDTH
@export var trigger_badge_background_color: Color = EventSheetPalette.COLOR_TRIGGER_ARROW_BG
@export var trigger_badge_foreground_color: Color = EventSheetPalette.COLOR_TRIGGER_ARROW_FG
@export var group_background_color: Color = EventSheetPalette.COLOR_GROUP_BG
@export var group_background_alt_color: Color = EventSheetPalette.COLOR_GROUP_BG_ALT
@export var group_accent_color: Color = EventSheetPalette.COLOR_GROUP_ACCENT
@export var group_title_color: Color = EventSheetPalette.COLOR_GROUP_TITLE
@export var group_badge_background_color: Color = EventSheetPalette.COLOR_GROUP_BADGE_BG
@export var group_badge_foreground_color: Color = EventSheetPalette.COLOR_GROUP_BADGE_FG
@export var group_fold_background_color: Color = EventSheetPalette.COLOR_GROUP_FOLD_BG
# A warm note band (Construct-style) so a full-width comment reads as a banner, not another row.
@export var comment_row_background_color: Color = Color("#38321f")
@export var comment_text_color: Color = EventSheetPalette.COLOR_COMMENT
@export var selection_fill_color: Color = EventSheetPalette.COLOR_SELECTION
@export var hover_fill_color: Color = EventSheetPalette.COLOR_HOVER
@export var column_header_background_color: Color = Color("#22242b")
@export var column_header_conditions_color: Color = Color("#8fb0e0")
@export var column_header_actions_color: Color = Color("#6fd0bf")
## Red ✗ shown on inverted (negated) conditions (the --invert-icon-color). Softened from pure
## #FF0000: full-saturation red reads as "error!" and vibrates against the dark theme; this stays
## unmistakably red without shouting.
@export var invert_marker_color: Color = Color("#e05c5c")
## Object/origin label drawn before each condition/action ("System", node class).
@export var object_label_color: Color = EventSheetPalette.COLOR_OBJECT
## Parameter values (numbers / strings / booleans) highlighted inside ACE text.
@export var value_highlight_color: Color = EventSheetPalette.COLOR_VALUE
## Hover tint for an individual condition/action cell.
@export var cell_hover_color: Color = Color(1.0, 1.0, 1.0, 0.14)
## Accent for behavior sheets (identity banner / tab badge) - soft purple, the event-sheet-style
## "this is a behavior" color language.
@export var behavior_accent_color: Color = Color("#8a7bd8")
## The left gutter strip (line + event numbers, breakpoints, bookmark pennants).
@export var gutter_background_color: Color = EventSheetPalette.COLOR_GUTTER_BG
## Line and event numbers drawn in the gutter.
@export var gutter_text_color: Color = EventSheetPalette.COLOR_GUTTER_TEXT
## Accent for LANGUAGE blocks - rows that render a GDScript construct (a data-class holder, a
## methods-class, a host binding, a lifted switch case, a collapsed function) rather than a regular
## ACE event. Drawn as a quiet left stripe + faint wash so the distinction reads at a glance.
@export var language_block_accent_color: Color = EventSheetPalette.COLOR_LANGUAGE_BLOCK
## PUBLISHED VERB rows (a behaviour's own Actions / Conditions / Expressions, the vocabulary it
## publishes) are tinted by which KIND of verb they are. Each role's ACCENT drives five surfaces at
## once - the role badge's text, the verb name's tint, the row wash, the left accent bar, and the
## description caption's band - so one colour re-skins that whole role. The BADGE background is the
## pill behind the role word.
@export var ace_action_badge_background_color: Color = EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG
@export var ace_action_accent_color: Color = EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG
@export var ace_condition_badge_background_color: Color = EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG
@export var ace_condition_accent_color: Color = EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG
@export var ace_expression_badge_background_color: Color = EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG
@export var ace_expression_accent_color: Color = EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG
## How loud a published verb's role tint is - the alpha of the wash behind the row (its description
## caption uses 70% of it). The default is tuned for a dark sheet; a pale sheet usually needs more,
## because a faint dark-on-dark wash disappears over a light row.
@export_range(0.0, 0.4, 0.01) var verb_row_tint_strength: float = 0.10
## The neutral chips on a published verb's ACTION lane - "gives back <type>", "waits", "static",
## "internal", "featured". The de-emphasised chips (static / internal) derive from this pair.
@export var verb_chip_background_color: Color = EventSheetPalette.COLOR_CHIP_BG
@export var verb_chip_foreground_color: Color = EventSheetPalette.COLOR_CHIP_FG
## Corner roundness of the event BLOCK, in pixels. The LEFT side (including the always-
## rounded bottom-left) uses this full radius; the right side uses half of it, so blocks
## read as opening toward their actions. 0 = the classic square look.
@export_range(0, 24, 1) var event_corner_radius: int = 8
## Corner roundness of individual condition/action CELLS, in pixels.
@export_range(0, 16, 1) var cell_corner_radius: int = 4
## Corner roundness of GROUP rows, in pixels. 0 = the classic square group bar.
@export_range(0, 24, 1) var group_corner_radius: int = 0
## Corner roundness of REGION marker bubbles, in pixels.
@export_range(0, 24, 1) var region_corner_radius: int = 7
## Line thickness of REGION marker borders, in pixels.
@export_range(1, 6, 1) var region_line_width: int = 1
