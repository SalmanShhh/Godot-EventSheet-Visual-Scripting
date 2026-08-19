@tool
class_name EventSheetChromeStyle
extends Resource

## Theme tokens for the BARS AROUND the sheet - the editor chrome that frames the canvas rather than
## painting a row: the Object bar, the status strip with its row address, the tab title's unsaved dot
## and file path, and the wash the Object bar throws over the rows that use the object you point at.
##
## These are Controls, not canvas draws, so they cannot reach the sheet's style the way the renderer
## does. They read it through EventSheetActiveTheme, the one place a panel outside the canvas asks
## "what is the sheet painted with right now".
##
## Every token seeds from the value that surface already painted, so a sheet with no theme looks
## exactly as it did before this resource existed.


# ── The Object bar ────────────────────────────────────────────────────────────────────────────
## The section headings down the Object bar (SCENE, GLOBALS, INPUT ...) and the quiet count on the
## right of each entry.
@export var object_bar_section_color: Color = EventSheetPalette.TEXT_MUTED
## The ⚠ on an entry the sheet flagged (an input action that is not in the Input Map, a node the
## scene no longer has). Amber by default so the mark reads as "look at this", never as an error.
@export var object_bar_warning_color: Color = EventSheetPalette.COLOR_HEALTH_WARN
## The wash the sheet throws over every row that uses the object under your pointer in the Object
## bar, and the drag grip that appears on the row you are over.
@export var object_bar_hover_wash_color: Color = Color(1.0, 1.0, 1.0, 0.07)
@export var object_bar_grip_color: Color = Color(1.0, 1.0, 1.0, 0.28)
## The stronger version of both while the pointer sits in the drag zone.
@export var object_bar_grip_active_color: Color = Color(1.0, 1.0, 1.0, 0.62)

# ── The status strip ──────────────────────────────────────────────────────────────────────────
## The message along the bottom of the dock, and the red it turns when something went wrong.
@export var status_text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var status_error_color: Color = Color(1.0, 0.48, 0.48, 1.0)
## The row address beside it ("event 12 ▸ action 2").
@export var row_address_color: Color = Color(1.0, 1.0, 1.0, 0.65)

# ── The tab title ─────────────────────────────────────────────────────────────────────────────
## The ● that says this sheet has unsaved edits, and the file path printed beside its name.
@export var unsaved_dot_color: Color = Color(0.99, 0.78, 0.30, 1.0)
@export var title_path_color: Color = Color(0.72, 0.76, 0.84, 1.0)
