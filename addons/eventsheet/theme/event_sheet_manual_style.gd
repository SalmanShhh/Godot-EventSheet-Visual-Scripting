@tool
class_name EventSheetManualStyle
extends Resource

## Theme tokens for the MANUAL - the docked help pages, their headings, the amber a search hit wears,
## the contents entry for the page you are on, the note above a deprecated verb, and the rule under a
## table's header row.
##
## The Manual is built from plain editor Controls with no path back to the sheet, so it reads these
## through EventSheetActiveTheme (the same seam the Object bar and the status strip use). The figures
## INSIDE a page are real sheet views and were always themed - this resource is the page around them.
##
## Every token seeds from what the Manual already painted, so a reader who never opens the Theme
## Editor sees no change.


## The page surface behind the prose. Fully transparent by default, which is the shipped look: the
## Manual sits on the editor's own background and inherits it. Give it an alpha and the page gets a
## paper of its own.
@export var page_background_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Headings on a page. Levels three and below are drawn from this, darkened, so one token moves the
## whole ladder.
@export var heading_color: Color = Color(0.93, 0.94, 0.96, 1.0)
## Captions, breadcrumbs, the "was this page helpful?" prompt, the text-size readout and the version
## line - every quiet word on a page.
@export var muted_text_color: Color = EventSheetPalette.TEXT_MUTED
## The highlight behind a search hit inside a page.
@export var search_hit_color: Color = Color("#c8a13a66")
## The contents entry for the page you are reading: a filled pill, and the near-black word on it.
@export var contents_active_background_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var contents_active_text_color: Color = Color(0.08, 0.09, 0.11, 1.0)
## The amber note above a verb the pack has deprecated.
@export var note_color: Color = Color(0.88, 0.70, 0.32, 1.0)
## The rule under a table's header row on a page.
@export var table_hairline_color: Color = Color(1.0, 1.0, 1.0, 0.16)


## The contents pill fill, or the editor accent when this theme has no opinion (the shipped look).
## Kept here rather than at the call site so the "no opinion" rule lives with the token it belongs to.
func resolve_contents_active_background(accent: Color) -> Color:
	return contents_active_background_color if contents_active_background_color.a > 0.01 else accent
