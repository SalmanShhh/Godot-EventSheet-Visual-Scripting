# EventSheet - EventSheetDocScratch: the sandbox every Manual example opens into.
#
# The only way to play with an example used to be adding it into a real sheet of the reader's own
# project, which is a bad offer: it asks a beginner to risk a file to satisfy curiosity. A scratch
# sheet is the same example in a tab of its own - editable, Reading mode off, no path - so every
# command in the editor works on it and none of them touches the project.
#
# WHAT MAKES A SHEET SCRATCH is one piece of resource metadata, not a new exported field, and that
# is deliberate: an exported flag would be written into any .tres the reader eventually saved, and
# a saved sheet is by definition no longer scratch. The flag is DROPPED by claim_saved() the moment
# a Save As gives the tab a path.
#
# THREE CONSEQUENCES, all of them falling out of "no path" rather than being special-cased:
#   - it is never restored next session   (the session store only records tabs that have a path)
#   - it is never written to the project  (nothing writes a sheet with no path)
#   - it closes without asking            (the dirty guard asks about work that has somewhere to go)
#
# Everything here is static and PURE over its inputs - the tab title, the badge, the decision to
# skip the close prompt - so the suite pins the flags without opening a tab.
@tool
class_name EventSheetDocScratch
extends RefCounted

## The resource metadata key that says "this sheet is a scratch pad". Frozen: an older session's
## sheet carrying it must still read as scratch.
const META_KEY := "eventsheets_scratch"

## The mark a scratch tab wears, and the words its title is built from. The badge leads, the way
## the behavior and custom-node badges already do, so a reader's eye finds the odd tab out.
const BADGE := "✎"
const TITLE_PREFIX := "Scratch"


## Marks a sheet as a scratch pad and names the example it holds. The NAME is what the tab reads,
## so it is the example's own caption rather than a file stem.
static func mark(sheet: EventSheetResource, example_name: String) -> void:
	if sheet == null:
		return
	sheet.set_meta(META_KEY, example_name.strip_edges())


## True for a sheet opened as a scratch pad.
static func is_scratch(sheet: EventSheetResource) -> bool:
	return sheet != null and sheet.has_meta(META_KEY)


## The example a scratch sheet holds, or "" for a sheet that is not one.
static func example_name(sheet: EventSheetResource) -> String:
	if not is_scratch(sheet):
		return ""
	return str(sheet.get_meta(META_KEY, "")).strip_edges()


## Drops the flag, because a sheet that has been saved somewhere is not a scratch pad any more.
## Called by Save As; a sheet that was never scratch is untouched.
static func claim_saved(sheet: EventSheetResource) -> void:
	if is_scratch(sheet):
		sheet.remove_meta(META_KEY)


## The tab's title: the badge, the word, and the example. Pure, so the suite pins the words rather
## than a screenshot of the tab strip.
static func tab_title(example_name_text: String) -> String:
	var name: String = example_name_text.strip_edges()
	if name.is_empty():
		return "%s %s" % [BADGE, TITLE_PREFIX]
	return "%s %s - %s" % [BADGE, TITLE_PREFIX, name]


## The hover on a scratch tab: what it is and what happens to it, which is the whole reassurance a
## reader needs before they start typing in one.
static func tab_tooltip() -> String:
	return "A scratch sheet from the Manual. It lives in memory only - nothing is written to your project unless you Save As, it closes without asking, and it is gone next session."


## True when closing this tab may skip the "you have unsaved changes" prompt. A scratch sheet has
## nowhere to save TO, so the prompt would offer a choice that does not exist.
static func closes_without_asking(sheet: EventSheetResource) -> bool:
	return is_scratch(sheet)


## The label the Manual's own button carries, everywhere an example offers one.
static func try_it_label() -> String:
	return "Try it in a scratch sheet"


## And its hover.
static func try_it_tooltip() -> String:
	return "Opens this example in a scratch tab of its own - editable, in memory, never written to your project."
