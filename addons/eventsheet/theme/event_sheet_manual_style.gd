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
## EVERY token here starts with NO OPINION (alpha zero). The Manual has always dressed itself from
## the running editor's own theme - its font colour, its accent - and that is the right default: a
## reader who never picks a theme should see help that looks like the rest of their editor. A token
## with alpha takes over; a token left clear hands the decision back. Each one is read through its
## resolve_ helper, which takes the value the Manual would otherwise have used, so the rule lives in
## one place instead of at every call site.


## The page surface behind the prose. Clear by default: the Manual sits on the editor's own
## background. Give it an alpha and the page gets a paper of its own.
@export var page_background_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Headings on a page. Levels three and below are drawn from this, darkened, so one token moves the
## whole ladder.
@export var heading_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## Captions, breadcrumbs, the "was this page helpful?" prompt and the text-size readout - every quiet
## word on a page.
@export var page_muted_text_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The highlight behind a search hit inside a page.
@export var search_hit_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The contents entry for the page you are reading: a filled pill, and the word on it.
@export var contents_active_background_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var contents_active_text_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The amber note above a verb the pack has deprecated.
@export var note_color: Color = Color(0.0, 0.0, 0.0, 0.0)
## The rule under a table's header row on a page.
@export var table_hairline_color: Color = Color(0.0, 0.0, 0.0, 0.0)


## True when a token was given a value at all - the one rule every resolve_ helper below applies.
static func has_opinion(token: Color) -> bool:
	return token.a > 0.01


func resolve_heading(editor_heading: Color) -> Color:
	return heading_color if has_opinion(heading_color) else editor_heading


func resolve_muted(editor_muted: Color) -> Color:
	return page_muted_text_color if has_opinion(page_muted_text_color) else editor_muted


func resolve_search_hit(shipped_hit: Color) -> Color:
	return search_hit_color if has_opinion(search_hit_color) else shipped_hit


func resolve_contents_active_background(accent: Color) -> Color:
	return contents_active_background_color if has_opinion(contents_active_background_color) else accent


func resolve_contents_active_text(shipped_text: Color) -> Color:
	return contents_active_text_color if has_opinion(contents_active_text_color) else shipped_text


func resolve_note(shipped_note: Color) -> Color:
	return note_color if has_opinion(note_color) else shipped_note


func resolve_table_hairline(shipped_hairline: Color) -> Color:
	return table_hairline_color if has_opinion(table_hairline_color) else shipped_hairline
