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
## THE DENSITY TOKENS. Six numbers decide how much room a sheet gives its rows, and all six live
## here on the theme resource the project owns rather than in the plugin: a team that wants the
## rows tight and a team that wants them airy are both right, and neither has to patch the addon.
## The shipped starters (View > Sheet theme > Density) are ordinary `.tres` files stating exactly
## these tokens, so "Compact" is a file a user can copy and edit, never a hard-coded look.
##
## Height an event row reserves before its text asks for more.
@export_range(20, 200, 1) var minimum_row_height: int = EventSheetPalette.ROW_HEIGHT
## Height of GROUP header rows. Defaults to double the event row height so groups read as
## strong section bars (an event-sheet reflex); themes can pull it back down to the classic slim bar.
@export_range(28, 200, 1) var group_row_height: int = EventSheetPalette.GROUP_ROW_HEIGHT
## Fixed width of the object-name column inside the CONDITIONS lane, in pixels (the event-sheet
## sub-lane: object names left, condition text aligned at the column edge). Aligned by DEFAULT, so
## every row's text starts at the same x and the sheet scans as a table. 0 = flow, where the
## text instead follows each label and so starts at a different x on every row. Set by dragging the
## gap between an object name and its text, or here / in a theme.
## The value is LOGICAL pixels, like every other geometry token here, so it does not grow with the
## editor's display scale - on a HiDPI editor a long name elides sooner, and the column can be dragged
## (or themed) wider to suit.
@export_range(0, 480, 1) var condition_object_column_width: int = EventSheetPalette.OBJECT_COLUMN_WIDTH
## Fixed width of the object-name column inside the ACTIONS lane, in pixels. 0 = flow.
@export_range(0, 480, 1) var action_object_column_width: int = EventSheetPalette.OBJECT_COLUMN_WIDTH
## Vertical gap inserted before an event or group that starts a new sibling block, so a run of
## sub-events reads as one block hanging off its parent instead of a ladder of equal rows.
@export_range(0, 48, 1) var event_block_gap: int = EventSheetPalette.EVENT_BLOCK_GAP
## How far one nesting level indents a sub-event, in logical pixels.
@export_range(4, 96, 1) var sub_event_indent: int = EventSheetPalette.INDENT_WIDTH
## Draw the nesting RAIL - the vertical line a sub-event hangs from, run down the parent's indent
## step for the full height of the child's card. Off leaves the older faint indent guides alone.
@export var sub_event_rail_line: bool = true
## Thickness of the border drawn round a WHOLE event - both lanes, every row of an OR stack, the
## band under the shorter lane - so an event reads as one card. 0 keeps the older look, where each
## row carried its own top and bottom hairline and nothing said where an event ended.
@export_range(0, 4, 1) var event_card_border_width: int = EventSheetPalette.EVENT_CARD_BORDER_WIDTH
## Gap kept between the number gutter and the left edge of the card, so the number reads as a
## margin mark outside the event rather than as the first thing inside it.
@export_range(0, 16, 1) var event_card_gutter_gap: int = EventSheetPalette.EVENT_CARD_GUTTER_GAP
@export var trigger_badge_background_color: Color = EventSheetPalette.COLOR_TRIGGER_ARROW_BG
@export var trigger_badge_foreground_color: Color = EventSheetPalette.COLOR_TRIGGER_ARROW_FG
@export var group_background_color: Color = EventSheetPalette.COLOR_GROUP_BG
@export var group_background_alt_color: Color = EventSheetPalette.COLOR_GROUP_BG_ALT
@export var group_accent_color: Color = EventSheetPalette.COLOR_GROUP_ACCENT
@export var group_title_color: Color = EventSheetPalette.COLOR_GROUP_TITLE
@export var group_badge_background_color: Color = EventSheetPalette.COLOR_GROUP_BADGE_BG
@export var group_badge_foreground_color: Color = EventSheetPalette.COLOR_GROUP_BADGE_FG
@export var group_fold_background_color: Color = EventSheetPalette.COLOR_GROUP_FOLD_BG
# A warm note band (event-sheet style) so a full-width comment reads as a banner, not another row.
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
## The flat fill of the head bars - the file's own line, its Input, its variables, its behaviors -
## one quiet tint, one row tall, nothing drawn on the right. The muted green every other event-sheet
## editor paints its Include rows in, so a reader meets a familiar shape before a single event.
@export var head_bar_color: Color = Color(0.27, 0.46, 0.33, 0.42)
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
## caption uses 70% of it). OFF by default: a verb is an ordinary event row, and washing every one of
## them in its role colour made a pack of verbs read as a wall of tinted blocks. The role badge already
## says which kind it is. Raise this if you WANT the colour-coding back - a pale sheet needs more than
## a dark one, because a faint dark-on-dark wash disappears over a light row.
@export_range(0.0, 0.4, 0.01) var verb_row_tint_strength: float = 0.0
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
## The group head in two lines: the name over its description in italics, with the event count and
## the on/off switch drawn as an Active tick box at its right - no folder mark before the name and no
## echo of its line (the code panel still shows it). Off keeps the one-line head, the folder mark, the
## description beside the name, the echo and the switch as its glyph.
@export var group_head_two_line: bool = false
## A variable row drawn the way the Inspector lists a property: the GDScript type in mono in its
## family's colour, the name capitalised the way the Inspector capitalises it (editing still shows the
## identifier), the value as the Inspector shows it (a colour as its swatch and hex), the `##`
## description as the row's one italic note, and the attributes only as the icon tiles at the right.
## No kind mark, no scope word (it moves to the name's hover) and no code echo. Off keeps the
## sentence row: kind mark, scope word, the type in words and the declaration echo.
@export var inspector_variable_rows: bool = false
## Leaves out of the sheet's variable rows the bookkeeping variables the compiler writes for rows
## such as Every X Seconds (names starting with two underscores). They still compile and save; the
## view only stops listing them. The rule is the prefix, so a variable an author named with two
## underscores is left out too. Off lists every variable the file declares.
@export var hide_compiler_variables: bool = false
## Each Inspector-style variable row as its own card: the event card's fill and one-pixel edge with
## its corner radius, 28 px tall with a 6 px gap to the next, in place of the flat variable wash and
## its left rule. Drawing only - the row's words do not move. Off keeps the flat washed row.
@export var variable_row_cards: bool = false
## The sheet's head as the Inspector heads a script: ONE class head card - the class icon, the name
## in bold, the kind of file, "· extends" and the base in the faint colour, the share mark and who
## includes a shared sheet, and the attached scene at the right - with no code echo, no "change…"
## word, no rows for the scene's facts and no "+ add" row. Clicking the kind or the base opens the
## Sheet Type dialog, the canvas's "+ Add…" menu adds the lines "+ add" offered, and the scene's facts
## are read in the scene's hover. A fact that is a problem keeps its row. Off keeps the band stack.
@export var inspector_class_head: bool = false
## An event's "Add condition" and "Add action" lines take room only while the event is hovered or
## selected, so an event at rest is as tall as its conditions and actions and no taller. Off keeps
## the line reserved under every event and revealed in place.
@export var add_lines_on_hover: bool = false
## The trigger icon sits in the number gutter beside the event's number, at its first line, and the
## coloured trigger badge leaves the conditions lane, so the lane starts with the object column. Off
## keeps the badge column and centres the number on the event.
@export var trigger_icon_in_gutter: bool = false
## A behaviour's own row names the behaviour in the object column ("Platformer | Jump") rather
## than the script's object with the behaviour's name repeated at the head of the sentence.
@export var behaviour_in_object_column: bool = false
## The chips after a condition (a trigger's payload, the chip naming the event's pattern) take at most
## two fifths of the conditions lane, so the condition's own words keep their room and a long chip is
## cut short. Off lets a chip take what it measures, however little that leaves the condition.
@export var lane_chips_yield: bool = false
## A comment drawn as a note: the yellow card with a drag grip and a speech-bubble mark before its
## words, the same in its own row and inside an event's action lane, where it drops its "#" marker.
## No code echo beside it (the Code view and the code panel still show the line). Off keeps the
## banner with its echo and the "#"-led line in the action lane.
@export var comment_notes: bool = false
## A selected event is marked by its filled number gutter and a two-pixel frame in the gutter's
## colour, with nothing washed over its lanes, so its words read exactly as they did. A selected cell
## keeps its own highlight. Off keeps the selection fill over the whole event.
@export var selection_as_outline: bool = false
## The size the sheet's text is drawn at, in pixels at 100% editor scale. Never larger than the
## editor's own font. 0 follows the editor's font size.
@export_range(0, 32, 1) var row_font_size: int = 0
## Corner roundness of REGION marker bubbles, in pixels.
@export_range(0, 24, 1) var region_corner_radius: int = 7
## Line thickness of REGION marker borders, in pixels.
@export_range(1, 6, 1) var region_line_width: int = 1
## THE NATIVE-LOOK TOKENS. The colours the Editor Native starter is drawn with: what kind of value a
## variable holds, what kind of word a sentence is made of, the Include bar and the inner-class block,
## and the small marks around them. Two kinds live here, and the default says which:
##   - a token that RE-COLOURS something the sheet already draws (the comment edge, the selected
##     gutter, the Include line, the value highlight) defaults to CLEAR, and clear means "exactly as
##     before" - so a theme saved before these tokens existed looks the way it always did;
##   - a token for a mark that is new defaults to the dark design palette, and every bundled theme
##     states its own.
##
## Type colours: the type word of a variable row, one hue per kind of value, so a list of variables
## is read by its colours before a single type name is.
@export var type_number_color: Color = Color("#a6d18f")
@export var type_text_color: Color = Color("#e3b47e")
@export var type_bool_color: Color = Color("#8ec3f2")
@export var type_vector_color: Color = Color("#7fe3d3")
@export var type_color_color: Color = Color("#f0a6c8")
@export var type_object_color: Color = Color("#b9c9da")
@export var type_enum_color: Color = Color("#ffd27a")
@export var type_collection_color: Color = Color("#c9a6ff")
@export var type_class_color: Color = Color("#c2b4d6")
## Word colours: the pieces of a condition or action sentence by kind. Clear follows the colour the
## sheet already uses for that piece (the value highlight for a number, the string and true/false
## colours for text and keywords).
@export var word_variable_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var word_text_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var word_number_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var word_keyword_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The Include line of a sheet that includes a shared one. Clear keeps the head bar look: the head
## bar fill, no border, and the line's own inks.
@export var include_border_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var include_fill_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var include_tag_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var include_name_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var include_note_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The inner-class block: a class declared inside the script, its fields and what it is for.
@export var class_border_color: Color = Color("#5f566c")
@export var class_fill_color: Color = Color("#36323d")
@export var class_head_color: Color = Color("#3c3744")
@export var class_tag_color: Color = Color("#c2b4d6")
@export var class_name_color: Color = Color("#eeeaf3")
@export var class_note_color: Color = Color("#b9b0c6")
## The edge drawn round a full-width comment, so a note reads as a note card. Clear draws none.
@export var comment_border_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The small icon in the number gutter that says how an event is started (on ready, every tick).
@export var gutter_icon_color: Color = Color("#b0b7c2")
## The number gutter of a SELECTED event, filled so the selection reads from the margin. Clear
## leaves the gutter as it is.
@export var selected_gutter_fill_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The hairline between an object's name and the sentence that follows it.
@export var object_hairline_color: Color = Color("#454d59")
## Words drawn as links on the sheet (Add condition, Add action).
@export var link_color: Color = Color("#7fa7f5")
## The badges beside a variable that say how the Inspector shows it: shown in the Inspector, kept
## in a range, given a tooltip, and saved by the Save System. Each is an icon on a small tile.
@export var inspector_badge_foreground_color: Color = Color("#7cc4ff")
@export var inspector_badge_background_color: Color = Color("#23384d")
@export var range_badge_foreground_color: Color = Color("#c9a6ff")
@export var range_badge_background_color: Color = Color("#3a2f4d")
@export var tooltip_badge_foreground_color: Color = Color("#ffd27a")
@export var tooltip_badge_background_color: Color = Color("#4a3e22")
@export var saved_badge_foreground_color: Color = Color("#8ee09a")
@export var saved_badge_background_color: Color = Color("#25402a")


## A token that re-colours something older, or the colour it stands in for while the theme leaves it
## clear. The one reading of "clear means as before", shared by every painter that honours it.
static func stated_or(stated: Color, fallback: Color) -> Color:
	return stated if stated.a > 0.01 else fallback
