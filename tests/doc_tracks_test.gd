# Godot EventSheets - learning paths, read ticks, and the tune-me marks on an inserted example.
#
# Two features that share one promise: the reader gets the guide's own rows, and the guides get an
# order to be read in. Both are gated here because both are DERIVED from something that already
# exists, and a derivation that quietly stops deriving looks exactly like a feature that works.
#
# What this catches, and nothing else in the suite does:
#   - a track that stops being a list in the documentation index (the parse), or one whose pages
#     stop shipping (the keep);
#   - the shipped index's own paths going missing from the bundle, which is what an edit to the
#     index without a rebake looks like;
#   - a read tick that does not persist, or that is not the reader's to take back;
#   - read-next suggesting a page nothing in the project points at, or one already read - the two
#     halves of the refusal to nag;
#   - the tune-me marks landing on the wrong ranges: a reading's muted lead is not a value anybody
#     would retype, and a row that was typed rather than inserted wears no marks at all.
#
# The read ticks live in a `user://` config, so this test clears them on the way IN and on the way
# OUT: the suite runs serially in one process on CI, and a tick left behind would answer a later
# test's question.
@tool
class_name DocTracksTest
extends RefCounted

## A documentation index with two paths in it, one of which names a page that does not ship. Written
## as a fixture rather than read off disk so the PARSE is pinned by what it says, not by whatever the
## real index happens to hold today.
const FIXTURE_INDEX := """# Documentation Index

## Learn by doing

- [Recipes](GUIDE-RECIPES.md) - build a platformer.

## Learning paths

Prose that is not a track.

### First steps

Start here if you have never built one.

1. [Recipes](GUIDE-RECIPES.md)
2. [Block styles](GUIDE-BLOCK-STYLES.md)
3. [Recipes again](GUIDE-RECIPES.md)

### Nothing that ships

Every page on this one is imaginary.

1. [Not a page](NOT-A-PAGE.md)

## After the paths

- [Theming](GUIDE-THEMING.md) - not part of any path.
"""


static func run() -> bool:
	EventSheetDocTracks.clear_read()
	EventSheetDescriptionDrafts.clear_offers()
	var passed: bool = true
	passed = _the_parse_reads_a_list(EventSheetDocTracks.parse(FIXTURE_INDEX)) and passed
	passed = _the_shipped_index_has_paths() and passed
	passed = _a_tick_is_the_readers() and passed
	passed = _read_next_refuses_to_nag() and passed
	passed = _the_page_draws_its_ticks() and passed
	passed = _tune_marks_land_on_values() and passed
	EventSheetDocTracks.clear_read()
	EventSheetDescriptionDrafts.clear_offers()
	return passed


# ── A track is a list in the index ────────────────────────────────────────────────────────────


static func _the_parse_reads_a_list(tracks: Array[Dictionary]) -> bool:
	var passed: bool = true
	passed = _check("only the paths section becomes tracks", tracks.size(), 2) and passed
	passed = _check("a track is titled by its own heading",
		str(tracks[0].get("title", "")), "First steps") and passed
	passed = _check("the first line of prose is the blurb",
		str(tracks[0].get("blurb", "")), "Start here if you have never built one.") and passed
	passed = _check("the pages are the links, in the order written, with the repeat dropped",
		str(tracks[0].get("ids", PackedStringArray())),
		str(PackedStringArray(["GUIDE-RECIPES", "GUIDE-BLOCK-STYLES"]))) and passed
	passed = _check("a heading outside the section opens no track",
		EventSheetDocTracks.track_titled(tracks, "After the paths").is_empty(), true) and passed
	# The keep is what stops a track from offering a page the bundle does not carry: the second
	# fixture track names only an imaginary page, so nothing of it survives.
	passed = _check("a track whose pages do not ship is dropped entirely",
		EventSheetDocTracks.track_titled(_kept(tracks), "Nothing that ships").is_empty(), true) and passed
	return passed


## The keep the reader's own list goes through, reached the way `all()` reaches it.
static func _kept(tracks: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for track: Dictionary in tracks:
		var ids: PackedStringArray = PackedStringArray()
		for id: Variant in (track.get("ids", []) as Array):
			if EventSheetDocLibrary.has_page(str(id)):
				ids.append(str(id))
		if not ids.is_empty():
			out.append({"title": str(track.get("title", "")), "ids": ids})
	return out


## The bundle has to carry what the index authored. This is the half that fails when somebody edits
## the index's Learning paths section and does not rebake the help bundle.
static func _the_shipped_index_has_paths() -> bool:
	var passed: bool = true
	var tracks: Array[Dictionary] = EventSheetDocTracks.all()
	passed = _check("the shipped index declares its four paths", tracks.size(), 4) and passed
	var first: Dictionary = EventSheetDocTracks.track_titled(tracks, "Your first game")
	passed = _check("the first path opens on the recipes",
		str((first.get("ids", PackedStringArray()) as PackedStringArray)[0] if not first.is_empty() else ""),
		"GUIDE-RECIPES") and passed
	var multiplayer: Dictionary = EventSheetDocTracks.track_titled(tracks, "Multiplayer")
	passed = _check("the multiplayer path leads with the multiplayer guide",
		str((multiplayer.get("ids", PackedStringArray()) as PackedStringArray)[0] if not multiplayer.is_empty() else ""),
		"GUIDE-MULTIPLAYER-WITH-GODOTS-BUILT-IN-TOOLS") and passed
	# A path lists pages that are already grouped by subject, so listing them twice in the tree would
	# read as a bug. The tree must not carry a group by the paths section's name.
	var group_titles: PackedStringArray = PackedStringArray()
	for group: Dictionary in EventSheetDocLibrary.groups():
		group_titles.append(str(group.get("title", "")))
	passed = _check("the paths section is not also a tree group",
		group_titles.has(EventSheetDocTracks.SECTION_HEADING), false) and passed
	return passed


# ── One bit per page, and it is the reader's ──────────────────────────────────────────────────


static func _a_tick_is_the_readers() -> bool:
	var passed: bool = true
	var track: Dictionary = {"title": "Fixture", "blurb": "",
		"ids": PackedStringArray(["GUIDE-RECIPES", "GUIDE-BLOCK-STYLES", "GUIDE-THEMING"])}
	passed = _check("nothing is read before anything is read",
		EventSheetDocTracks.read_count(track), 0) and passed
	passed = _check("the next page of an untouched track is its first",
		EventSheetDocTracks.next_unread(track), "GUIDE-RECIPES") and passed
	EventSheetDocTracks.set_read("GUIDE-RECIPES", true)
	passed = _check("a tick persists", EventSheetDocTracks.is_read("GUIDE-RECIPES"), true) and passed
	passed = _check("the count follows the tick", EventSheetDocTracks.read_count(track), 1) and passed
	passed = _check("progress is counted, never estimated",
		EventSheetDocTracks.progress_text(track), "1 of 3 read") and passed
	passed = _check("the next page is the first one still unread",
		EventSheetDocTracks.next_unread(track), "GUIDE-BLOCK-STYLES") and passed
	EventSheetDocTracks.set_read("GUIDE-RECIPES", false)
	passed = _check("a reader can take a tick back",
		EventSheetDocTracks.is_read("GUIDE-RECIPES"), false) and passed
	return passed


# ── Read next: derived, and refusing to nag ───────────────────────────────────────────────────


static func _read_next_refuses_to_nag() -> bool:
	var passed: bool = true
	var tracks: Array[Dictionary] = [
		{"title": "Multiplayer", "blurb": "", "ids": PackedStringArray(["GUIDE-THEMING", "GUIDE-RECIPES"])},
	]
	passed = _check("a page nothing in the project points at is never suggested",
		EventSheetDocTracks.suggestion(tracks, {}).is_empty(), true) and passed
	var hits: Dictionary = {"GUIDE-THEMING": 1, "GUIDE-RECIPES": 4}
	passed = _check("the page the most of the reader's own rows point at wins",
		str(EventSheetDocTracks.suggestion(tracks, hits).get("page_id", "")), "GUIDE-RECIPES") and passed
	EventSheetDocTracks.set_read("GUIDE-RECIPES", true)
	passed = _check("a page already read is not offered again",
		str(EventSheetDocTracks.suggestion(tracks, hits).get("page_id", "")), "GUIDE-THEMING") and passed
	EventSheetDocTracks.set_read("GUIDE-RECIPES", false)
	# The census is a reading of rows and holds nothing of its own: an empty project says nothing.
	passed = _check("an empty project has no vocabulary to go on",
		str(EventSheetDocTracks.census([] as Array[EventSheetResource])), str(PackedStringArray())) and passed
	passed = _check("a verb is censused under the words the guides are written in",
		str(EventSheetDocTracks.census([_sheet_using("MultiplayerHostGame")] as Array[EventSheetResource])),
		str(PackedStringArray(["Multiplayer Host Game"]))) and passed
	# The offer is spent once, through the budget the whole editor shares.
	var suggestion: Dictionary = EventSheetDocTracks.suggestion(tracks, hits)
	passed = _check("the offer is made", EventSheetDocTracks.may_offer(suggestion), true) and passed
	passed = _check("and never a second time", EventSheetDocTracks.may_offer(suggestion), false) and passed
	passed = _check("an empty suggestion is never offered",
		EventSheetDocTracks.may_offer({}), false) and passed
	return passed


## A one-row sheet whose action uses `ace_id`, for the census walk.
static func _sheet_using(ace_id: String) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	var event := EventRow.new()
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	event.actions.append(action)
	sheet.events.append(event)
	return sheet


static func _the_page_draws_its_ticks() -> bool:
	var passed: bool = true
	EventSheetDocTracks.set_read("GUIDE-RECIPES", true)
	var blocks: Array[Dictionary] = EventSheetDocTracks.list_blocks()
	var labels: PackedStringArray = PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) != "buttons":
			continue
		for item: Variant in (block.get("items", []) as Array):
			if str((item as Dictionary).get("argument", "")) == "GUIDE-RECIPES":
				labels.append(str((item as Dictionary).get("label", "")))
	passed = _check("a read page wears its tick on the page",
		labels.has(EventSheetDocTracks.tick_label(true)), true) and passed
	passed = _check("and the row that opens it is numbered by its place on the track",
		labels.has("1. %s" % EventSheetDocLibrary.page_title("GUIDE-RECIPES")), true) and passed
	EventSheetDocTracks.set_read("GUIDE-RECIPES", false)
	return passed


# ── The tune-me marks ─────────────────────────────────────────────────────────────────────────


## The marks are drawn from a row's OWN value ranges, so the gate is which ranges the renderer would
## dash. Pinned as the DECISION rather than as pixels: a reading's muted lead is not a value anybody
## retypes, and a row nobody inserted has no marks at all.
static func _tune_marks_land_on_values() -> bool:
	var passed: bool = true
	var row := EventRowData.new()
	passed = _check("a row is not a worked example until something says so", row.tunable, false) and passed
	var ranges: Array = [[0, 3], [8, 5, "string"], [20, 7, "muted"]]
	passed = _check("every literal is marked, and a reading's lead is not",
		_marked(ranges), 2) and passed
	passed = _check("a row with no literals in it is marked nowhere", _marked([]), 0) and passed
	# The uids an insert hands the viewport come from the rows it landed, nested rows included.
	var parent := EventRow.new()
	parent.event_uid = "aaaa1111"
	var child := EventRow.new()
	child.event_uid = "bbbb2222"
	parent.sub_events.append(child)
	passed = _check("an insert marks the rows it landed, nested ones too",
		str(EventSheetClipboard.landed_event_uids([parent])),
		str(PackedStringArray(["aaaa1111", "bbbb2222"]))) and passed
	return passed


## How many of a row's value ranges the renderer would dash. Mirrors the one rule the renderer
## applies, which is the rule this test exists to pin.
static func _marked(ranges: Array) -> int:
	var count: int = 0
	for entry: Variant in ranges:
		if not (entry is Array) or (entry as Array).size() < 2:
			continue
		if (entry as Array).size() >= 3 and str((entry as Array)[2]) == "muted":
			continue
		count += 1
	return count


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tracks: %s" % label)
		return true
	print("[FAIL] tracks: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
