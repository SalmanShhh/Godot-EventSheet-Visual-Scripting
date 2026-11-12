@tool
class_name EventSheetObjectLookup
extends RefCounted

# Finds the census entry an object label belongs to. The one lookup the hierarchy writer, the
# documentation helper and the objects rail share, so each reads the live sheet the same way.


## The census entry an object label belongs to, re-derived from the LIVE sheet at the moment it is
## asked: the undo funnel replaces every resource on commit, so a census taken when a row was drawn
## may describe a sheet that no longer exists. Falls back to {} for a label the file no longer uses.
##
## The label is matched with its "(global)" note taken off, because that note is part of how an
## autoload READS, not part of its name.
static func find_entry(sheet: EventSheetResource, object_label: String) -> Dictionary:
	var wanted: String = object_label.strip_edges().trim_suffix(
		EventSheetL10n.translate(EventSheetViewportReadingRows.GLOBAL_NOTE)).strip_edges()
	if sheet == null or wanted.is_empty():
		return {}
	for entry: Dictionary in EventSheetViewportReadingRows.object_census(sheet):
		if str(entry.get("label", "")) == wanted:
			return entry
	return {}
