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

# ── The Project bar (the Object bar's other tab) ──────────────────────────────────────────────
## The by-kind headings down the Project bar (Scenes, Scripts, Classes, Base classes ...), and the
## muted note beside each entry (the file it came from, who extends it, how much reads as events).
@export var project_bar_heading_color: Color = EventSheetPalette.TEXT_MUTED
@export var project_bar_note_color: Color = EventSheetPalette.TEXT_MUTED

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

# ── The minimap ───────────────────────────────────────────────────────────────────────────────
## The thin column down the right edge of a long sheet: one bar per event, tinted by what the
## event IS, with the part of the sheet you are looking at drawn as a box over them. It frames the
## canvas rather than painting a row, so its colours live here with the rest of the chrome.
@export var minimap_background_color: Color = Color(0.0, 0.0, 0.0, 0.16)
## The translucent box over the rows currently on screen, and the line around it.
@export var minimap_window_color: Color = Color(1.0, 1.0, 1.0, 0.20)
@export var minimap_window_border_color: Color = Color(1.0, 1.0, 1.0, 0.48)
## One tint per kind of event, so the shape of a sheet reads without any text.
@export var minimap_trigger_color: Color = Color(0.98, 0.76, 0.36, 1.0)
@export var minimap_tick_color: Color = Color(0.55, 0.78, 0.98, 1.0)
@export var minimap_function_color: Color = Color(0.78, 0.61, 0.94, 1.0)
@export var minimap_group_color: Color = Color(0.88, 0.69, 0.44, 1.0)
@export var minimap_comment_color: Color = Color(0.56, 0.80, 0.56, 1.0)
@export var minimap_script_color: Color = Color(0.66, 0.72, 0.82, 1.0)
@export var minimap_event_color: Color = Color(1.0, 1.0, 1.0, 0.42)
## A disabled event keeps its place in the picture but stops asking to be read.
@export var minimap_disabled_color: Color = Color(1.0, 1.0, 1.0, 0.16)
## The marks beside the bars: a bookmark, and a row the Doctor flagged.
@export var minimap_bookmark_color: Color = Color(0.42, 0.72, 0.99, 1.0)
@export var minimap_finding_color: Color = Color(1.0, 0.48, 0.48, 1.0)
## The band a group paints down the column, and the name written on it.
@export var minimap_band_color: Color = Color(1.0, 1.0, 1.0, 0.05)
@export var minimap_band_text_color: Color = Color(1.0, 1.0, 1.0, 0.55)

# ── The Sheet map ─────────────────────────────────────────────────────────────────────────────
## The Sheet map window's boxes, one tint per kind: sheets, the scenes that carry them, and the
## globals they call. Each box wears its tint as a border and a faint fill of the same colour.
@export var sheet_map_sheet_color: Color = Color("#7fb3d5")
@export var sheet_map_scene_color: Color = Color("#e0b070")
@export var sheet_map_global_color: Color = Color("#c79bf0")
## The lines between the boxes: the quiet one for includes, calls and layout changes, and the warm
## one for a signal connection, so the wiring that fires at runtime stands out from the plumbing.
@export var sheet_map_edge_color: Color = Color(1.0, 1.0, 1.0, 0.30)
@export var sheet_map_signal_edge_color: Color = Color(0.98, 0.76, 0.36, 0.55)
## The name written inside every box.
@export var sheet_map_text_color: Color = Color("#dfe4ec")

# ── The Inspector drawers ─────────────────────────────────────────────────────────────────────
## The custom drawers a variable's decor comments put in the Inspector (progress bars, range
## sliders, direction dials, previews). One ACCENT fills everything interactive; the BRIGHT accent
## is its lit end - a slider's vector line's handle, a curve's plotted line. The INK is the quiet
## base every hairline, guide and value label mixes its own alpha from, and the WELL is the sunken
## plate a bar or preview sits in.
@export var drawer_accent_color: Color = Color(0.36, 0.66, 1.0, 0.92)
@export var drawer_accent_bright_color: Color = Color(0.45, 0.74, 1.0, 1.0)
@export var drawer_ink_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var drawer_well_color: Color = Color(0.0, 0.0, 0.0, 0.28)
## The min-max range slider's two round handles, and the line around each.
@export var drawer_handle_color: Color = Color(0.86, 0.9, 0.97, 1.0)
@export var drawer_handle_border_color: Color = Color(0.2, 0.28, 0.4, 1.0)
## The quiet note panel an `@inspector_info` comment builds, and the words on it.
@export var drawer_info_background_color: Color = Color(0.25, 0.42, 0.6, 0.22)
@export var drawer_info_border_color: Color = Color(0.36, 0.66, 1.0, 0.5)
@export var drawer_info_text_color: Color = Color(0.86, 0.9, 0.96, 1.0)
## An `@inspector_header` section label that named no accent of its own.
@export var drawer_header_text_color: Color = Color(0.85, 0.88, 0.95, 1.0)
## The ⚠ badges: "assign a value" while a required property is empty, and the message a sheet's own
## validator function returns while a value is out of bounds.
@export var drawer_required_color: Color = Color("#e06666")
@export var drawer_validate_color: Color = Color("#f0883e")
## The checkerboard behind a texture thumbnail, so a transparent sprite still reads.
@export var drawer_checker_dark_color: Color = Color(0.20, 0.20, 0.20, 1.0)
@export var drawer_checker_light_color: Color = Color(0.28, 0.28, 0.28, 1.0)

# ── The Anatomy rail ──────────────────────────────────────────────────────────────────────────
## The pills down the Anatomy rail take the sheet's own ACE badge pairs and plain chip pair, so the
## rail and the canvas speak one colour language. These three are the pills the sheet has no token
## for: the ➜ trigger pill (also worn by ⚒ Editor Tools - verbs the editor calls, like a trigger),
## and the @ ink on a designer knob's chip.
@export var anatomy_trigger_pill_background_color: Color = Color("#233b2b")
@export var anatomy_trigger_pill_foreground_color: Color = Color("#7fd494")
@export var anatomy_knob_pill_foreground_color: Color = Color("#9cc4ef")
