@tool
class_name EventSheetReadingStyle
extends Resource

## Theme tokens for the READING MARKS inside a sheet - everything the sheet draws to say what a row
## IS, as opposed to the row shells and lanes (EventSheetEventStyle) or the chips in them
## (EventSheetElementStyle).
##
## These surfaces arrived with the "an opened script reads like an event sheet" work: the chips on an
## Include bar, the coverage chip, the tempo badges, the Script block and ⚠ code badges, the scope and
## Inspector chips on a variable row, the guide lines, the stripes that flag an error or a live fire,
## the refusal bubble a bad drop shows. Every one of them used to be a constant read straight from
## EventSheetPalette, so a theme could not touch them and a pale preset kept EventForge's dark marks.
##
## Every token seeds from the palette constant it replaced, so a sheet with no theme paints exactly
## what it painted before this resource existed. The Theme Editor enumerates the tokens reflectively,
## so they appear there as "Reading marks" with no editor changes.


# ── Chips and badges ──────────────────────────────────────────────────────────────────────────
## The neutral chip on an Include bar button (Run now / Reload / Output / Enable plugin), the
## coverage chip, and every other plain chip in a reading row.
@export var plain_chip_background_color: Color = EventSheetPalette.COLOR_CHIP_BG
@export var plain_chip_foreground_color: Color = EventSheetPalette.COLOR_CHIP_FG
## The picker-category chip ("Group › Subgroup" on a variable row, a pack's category).
@export var category_chip_background_color: Color = EventSheetPalette.COLOR_CAT_CHIP_BG
@export var category_chip_foreground_color: Color = EventSheetPalette.COLOR_CAT_CHIP_FG
## The "Inspector" chip on an exported variable row - blue, deliberately not the category purple, so
## "where it sits in the Inspector" never reads as "where it sits in the picker".
@export var inspector_chip_background_color: Color = EventSheetPalette.COLOR_GROUP_CHIP_BG
@export var inspector_chip_foreground_color: Color = EventSheetPalette.COLOR_GROUP_CHIP_FG
## The `const` / `static` badge on a variable row.
@export var constant_badge_background_color: Color = EventSheetPalette.COLOR_CONST_BADGE_BG
@export var constant_badge_foreground_color: Color = EventSheetPalette.COLOR_CONST_BADGE_FG
## The dim badge on a setup / scaffolding strip (the ▣ and ⇥ marks on an Include bar).
@export var setup_badge_background_color: Color = EventSheetPalette.COLOR_SETUP_BADGE_BG
@export var setup_badge_foreground_color: Color = EventSheetPalette.COLOR_SETUP_BADGE_FG
## The "Script block" pill on a row that kept its GDScript verbatim.
@export var code_badge_background_color: Color = EventSheetPalette.COLOR_CODE_BADGE_BG
@export var code_badge_foreground_color: Color = EventSheetPalette.COLOR_CODE_BADGE_FG
## The amber "⚠ code" badge that flags a line the reader should look at.
@export var lift_note_badge_background_color: Color = EventSheetPalette.COLOR_LIFT_NOTE_BADGE_BG
@export var lift_note_badge_foreground_color: Color = EventSheetPalette.COLOR_LIFT_NOTE_BADGE_FG
## The plate behind an OR badge in the badge column, when the condition lane's own badge pair has
## nothing to say. (A negated condition's ✕ takes the event style's invert marker instead - one red,
## one meaning, wherever a condition is turned around.)
@export var or_badge_background_color: Color = Color(0.26, 0.29, 0.36, 0.95)
@export var or_badge_foreground_color: Color = Color(0.82, 0.87, 0.95, 1.0)

# ── How often an event runs ───────────────────────────────────────────────────────────────────
## The filled badge that says how OFTEN an event runs: ⟳ every tick (a tween beat, a repeating
## timer), ⌨ an input, ▶ once. The ➜ signal badge keeps the event style's trigger badge pair.
@export var tempo_every_tick_background_color: Color = EventSheetPalette.COLOR_TEMPO_EVERY_TICK_BG
@export var tempo_every_tick_foreground_color: Color = EventSheetPalette.COLOR_TEMPO_EVERY_TICK_FG
@export var tempo_input_background_color: Color = EventSheetPalette.COLOR_TEMPO_INPUT_BG
@export var tempo_input_foreground_color: Color = EventSheetPalette.COLOR_TEMPO_INPUT_FG
@export var tempo_once_background_color: Color = EventSheetPalette.COLOR_TEMPO_ONCE_BG
@export var tempo_once_foreground_color: Color = EventSheetPalette.COLOR_TEMPO_ONCE_FG

# ── Text tones ────────────────────────────────────────────────────────────────────────────────
## The main word of a reading sentence, its quieter half, and the muted detail after it (an Include
## bar's receipt, an INPUT row's bindings, a head bar's subtitle, an Object bar section heading).
@export var primary_text_color: Color = EventSheetPalette.TEXT_PRIMARY
@export var secondary_text_color: Color = EventSheetPalette.TEXT_SECONDARY
@export var muted_text_color: Color = EventSheetPalette.TEXT_MUTED
## Text literals and true/false inside a parameter, tinted by type so "where are the magic values"
## is a colour question. Numbers keep the event style's value_highlight_color.
@export var string_value_color: Color = EventSheetPalette.COLOR_VALUE_STRING
@export var boolean_value_color: Color = EventSheetPalette.COLOR_VALUE_BOOL

# ── Flags and stripes ─────────────────────────────────────────────────────────────────────────
## "N errors - the game will not run this script", and the red stripe + wash down the offending row.
@export var error_text_color: Color = EventSheetPalette.COLOR_ERROR_TEXT
@export var error_stripe_color: Color = Color("#ff5555")
## The cyan stripe that pulses on an event firing right now in a debug run.
@export var firing_stripe_color: Color = Color("#4fd6ff")
## The scrim over a disabled row.
@export var disabled_row_color: Color = EventSheetPalette.COLOR_DISABLED
## The breakpoint dot and the bookmark pennant in the event-number margin, and the hairline rail
## down its right edge.
@export var breakpoint_color: Color = EventSheetPalette.COLOR_BREAKPOINT
@export var bookmark_color: Color = EventSheetPalette.COLOR_BOOKMARK
@export var event_number_rail_color: Color = EventSheetPalette.COLOR_GUTTER_RAIL

# ── Guides and gestures ───────────────────────────────────────────────────────────────────────
## The whisper of an indent stop, and the stronger tree connector you follow with your eye from a
## parent event down to its sub-events.
@export var indent_guide_color: Color = EventSheetPalette.COLOR_GUIDE
@export var tree_guide_color: Color = EventSheetPalette.COLOR_TREE_GUIDE
## The insert line a dragged row shows, and the red a refused drop turns.
@export var drag_line_color: Color = EventSheetPalette.COLOR_DRAG_LINE
@export var drag_refusal_color: Color = EventSheetPalette.COLOR_BREAKPOINT
## The bubble under the pointer that says why a drop was refused ("dealt is not visible here").
@export var drag_bubble_refused_background_color: Color = Color(0.45, 0.14, 0.17, 0.96)
@export var drag_bubble_background_color: Color = Color(0.17, 0.21, 0.28, 0.96)
@export var drag_bubble_text_color: Color = Color(1.0, 1.0, 1.0, 0.96)

# ── Small marks ───────────────────────────────────────────────────────────────────────────────
## The outline stroked around a colour value's swatch, so a pale colour still reads as a swatch.
@export var color_swatch_border_color: Color = Color(0.0, 0.0, 0.0, 0.55)
## How strongly every OTHER use of a hovered local variable lights up, inside that variable's own
## scope. The colour is the row hover fill; this is only how far it is pushed.
@export_range(0.0, 1.0, 0.01) var name_highlight_strength: float = 0.34
