# EventSheet - EventSheetDocTracks: the guides, put in an order.
#
# A corpus of fifty guides answers every question and teaches nobody: a reader who has never built a
# game does not know which five of them to read, or in which order. A TRACK is that order and nothing
# else - a named list of pages that already exist, read top to bottom.
#
# WHERE A TRACK LIVES: in the documentation index, as a list. There is no track store, no registry
# and no registration call, because a track holds no fact of its own - it holds page ids that the
# index already carries, in an order a human wrote. The build step reads the index's own
# "Learning paths" section into the manifest exactly as it reads the index's grouped link list into
# the tree, and a studio declares its own tracks by writing the same section in its own docs folder's
# index. Same format, same parser, no second implementation.
#
# WHAT IS ACTUALLY STORED, and it is one bit per page: whether this reader has read it. That is not
# in the index (it is not a fact about the documentation), it is not in the project file (it is not a
# fact about the game, and it would land in everybody's version control on the first tick), and it is
# not in the bundle (that ships identically to everyone). It lives in a `user://` config, which is
# per-project and per-machine and reaches nobody else - the same place the picker keeps its recents.
#
# READ NEXT is DERIVED, never stored. A project whose sheets already speak a family's vocabulary, on
# a track whose pages that reader has not opened, is a reader with a question they have not asked
# yet; the suggestion is the answer to it. The join runs against the Manual's own baked search index
# - the same table a keystroke in the search box ranks - so nothing here holds a second opinion about
# which guide teaches which verb, and the offer is spent through the editor's shared offer budget so
# it is made once and never again nags.
#
# Everything below is STATIC and PURE over its inputs where it can be: the parse takes text, the
# ranking takes a census and a hit table, and the suite pins all of it with no bundle and no project
# around it.
@tool
class_name EventSheetDocTracks
extends RefCounted

## The index heading a track section opens under, and the heading level one track's own title is
## written at. Frozen: every index already written with them is a promise, and a studio's index has
## to be readable by the same parser.
const SECTION_HEADING := "Learning paths"
const TRACK_HEADING_PREFIX := "### "

## Where this reader's read ticks live. `user://` is per-project and per-machine: it is never
## committed, never synced, and never seen by anybody the reader did not show it to. The same place -
## and the same reason - the picker keeps its recents.
const READ_FILE := "user://eventforge_docs_read.cfg"
const READ_SECTION := "read"

## The page id a studio's own index is read from, when the project ships one. Nothing else about the
## project's docs folder is special: this is simply the page that folder's index lands as.
const PROJECT_INDEX_PAGE := "Project/README"

## How many ranked search results one census entry is joined against, and the weakest evidence a hit
## may rest on. Both borrowed from the Manual's own reference join rather than re-decided here, so a
## verb that leads to a guide in one surface leads to the same guide in the other.
const HIT_CANDIDATES := EventSheetDocTeaches.SECTION_CANDIDATES
const WEAKEST_HIT_SCORE := EventSheetDocTeaches.WEAKEST_ACCEPTED_SCORE

## How many distinct verbs the census reports. A project is not unbounded but a reader pressing for a
## suggestion is waiting, and the ranking has long since settled by the time the list is this long.
const MAX_CENSUS_VERBS := 40

## What the read-next offer is booked against in the shared offer budget. A fixed word rather than
## the page a particular suggestion names: the offer is "one unprompted reading suggestion this
## session", so it has one subject, and keying it on the answer would buy a new offer every time the
## answer changed.
const OFFER_SUBJECT := "one per session"


# ── The tracks themselves ─────────────────────────────────────────────────────────────────────


## Every track written in one index, in document order, as [{title, blurb, ids}].
##
## A track opens at a `### ` heading inside the "Learning paths" section and closes at the next one
## (or at the next `## `). Its blurb is the first line of prose under the heading; its pages are every
## `.md` link below that, in the order they are written, with duplicates dropped - a page named twice
## is a typo, not a page to read twice.
##
## PURE over the text, so a studio's index and the plugin's own go through exactly this function.
static func parse(index_text: String) -> Array[Dictionary]:
	var tracks: Array[Dictionary] = []
	var matcher: RegEx = RegEx.create_from_string("\\]\\(([^)]+\\.md)\\)")
	var in_section: bool = false
	var current: Dictionary = {}
	for line: String in index_text.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("## "):
			if not current.is_empty():
				tracks.append(current)
				current = {}
			in_section = stripped.substr(3).strip_edges() == SECTION_HEADING
			continue
		if not in_section:
			continue
		if stripped.begins_with(TRACK_HEADING_PREFIX):
			if not current.is_empty():
				tracks.append(current)
			current = {"title": stripped.substr(TRACK_HEADING_PREFIX.length()).strip_edges(),
				"blurb": "", "ids": PackedStringArray()}
			continue
		if current.is_empty() or stripped.is_empty():
			continue
		var found: Array[RegExMatch] = matcher.search_all(stripped)
		if found.is_empty():
			if str(current["blurb"]).is_empty():
				current["blurb"] = stripped
			continue
		var ids: PackedStringArray = current["ids"]
		for entry: RegExMatch in found:
			var id: String = entry.get_string(1).trim_suffix(".md")
			if not ids.has(id):
				ids.append(id)
		current["ids"] = ids
	if not current.is_empty():
		tracks.append(current)
	return tracks


## Every track this reader can follow: the ones the shipped bundle baked from the plugin's own index,
## then the ones this project's own docs index declares. A studio track with the same title as a
## shipped one REPLACES it - a studio that rewrote "Your first game" for its own engine meant the
## reader to read theirs, not both.
##
## Pages that did not ship are dropped, so a track written against a larger corpus still reads.
static func all() -> Array[Dictionary]:
	var tracks: Array[Dictionary] = _kept(_baked())
	for studio: Dictionary in _kept(parse(EventSheetDocLibrary.page_source(PROJECT_INDEX_PAGE))):
		var replaced: bool = false
		for index: int in range(tracks.size()):
			if str(tracks[index].get("title", "")) == str(studio.get("title", "")):
				tracks[index] = studio
				replaced = true
				break
		if not replaced:
			tracks.append(studio)
	return tracks


## The tracks the bundle carries, read out of the manifest the build step wrote. An empty list is a
## valid state (a source checkout that has not run the build tool), and every caller degrades to
## "no tracks" rather than erroring.
static func _baked() -> Array[Dictionary]:
	var tracks: Array[Dictionary] = []
	for entry: Variant in (EventSheetDocLibrary.manifest().get("tracks", []) as Array):
		if entry is Dictionary:
			var track: Dictionary = (entry as Dictionary).duplicate()
			var ids: PackedStringArray = PackedStringArray()
			for id: Variant in (track.get("ids", []) as Array):
				ids.append(str(id))
			track["ids"] = ids
			tracks.append(track)
	return tracks


## The same tracks with pages the bundle does not carry removed, and empty tracks dropped entirely.
static func _kept(tracks: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for track: Dictionary in tracks:
		var ids: PackedStringArray = PackedStringArray()
		for id: Variant in (track.get("ids", []) as Array):
			if EventSheetDocLibrary.has_page(str(id)):
				ids.append(str(id))
		if ids.is_empty():
			continue
		out.append({"title": str(track.get("title", "")), "blurb": str(track.get("blurb", "")), "ids": ids})
	return out


## The track carrying `title`, or {} when no track does.
static func track_titled(tracks: Array[Dictionary], title: String) -> Dictionary:
	for track: Dictionary in tracks:
		if str(track.get("title", "")) == title:
			return track
	return {}


# ── The one bit per page: has this reader read it ─────────────────────────────────────────────


## Loaded once per session and written through on every tick. A missing file is an empty one, which
## is the correct reading for a reader who has never ticked anything.
static var _read: ConfigFile = null


static func _read_file() -> ConfigFile:
	if _read == null:
		_read = ConfigFile.new()
		_read.load(READ_FILE)
	return _read


## Whether this reader has ticked `page_id` off.
static func is_read(page_id: String) -> bool:
	return bool(_read_file().get_value(READ_SECTION, page_id.strip_edges(), false))


## Ticks a page (or unticks it - the tick is the reader's, and a reader who wants to read it again
## says so). Written straight through, because the alternative is losing the tick to a crash on the
## one session it was made in.
static func set_read(page_id: String, read: bool) -> void:
	var id: String = page_id.strip_edges()
	if id.is_empty():
		return
	var file: ConfigFile = _read_file()
	if read:
		file.set_value(READ_SECTION, id, true)
	else:
		file.erase_section_key(READ_SECTION, id)
	file.save(READ_FILE)


## How many of a track's pages this reader has ticked.
static func read_count(track: Dictionary) -> int:
	var count: int = 0
	for id: Variant in (track.get("ids", []) as Array):
		if is_read(str(id)):
			count += 1
	return count


## The line a track wears: how far through it this reader is. Written as a count rather than a
## percentage because a track is short enough to count, and "3 of 6" says which page is next in a way
## "50%" never does.
static func progress_text(track: Dictionary) -> String:
	var ids: Array = track.get("ids", []) as Array
	return EventSheetL10n.translate("%d of %d read") % [read_count(track), ids.size()]


## The first page of a track this reader has not ticked, or "" for a track they have finished.
static func next_unread(track: Dictionary) -> String:
	for id: Variant in (track.get("ids", []) as Array):
		if not is_read(str(id)):
			return str(id)
	return ""


## Forgets every tick, and drops the loaded file. The reader's own "start over", and what a test
## calls on the way in AND on the way out - a static config that outlived its test would answer the
## next test's questions, and the suite runs serially in one process.
static func clear_read() -> void:
	_read = null
	DirAccess.remove_absolute(READ_FILE)


# ── Read next: the suggestion the project itself asks for ─────────────────────────────────────


## What the sheets in front of this reader actually SAY, as the distinct display names of the verbs
## their rows use, sorted. Pure over the sheets it is handed, and deliberately not stored anywhere:
## it is a reading of rows that already exist, and an index of it would be a second copy of the sheet.
static func census(sheets: Array[EventSheetResource]) -> PackedStringArray:
	var seen: Dictionary = {}
	for sheet: EventSheetResource in sheets:
		if sheet != null:
			_census_rows(sheet.events, seen)
	var names: PackedStringArray = PackedStringArray(seen.keys())
	names.sort()
	if names.size() > MAX_CENSUS_VERBS:
		names.resize(MAX_CENSUS_VERBS)
	return names


static func _census_rows(rows: Array, seen: Dictionary) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_census_rows(group.events if not group.events.is_empty() else group.rows, seen)
			continue
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		_note_verb(event.trigger_provider_id, event.trigger_id, seen)
		for condition: ACECondition in event.conditions:
			if condition != null:
				_note_verb(condition.provider_id, condition.ace_id, seen)
		for action: Variant in event.actions:
			if action is ACEAction:
				_note_verb((action as ACEAction).provider_id, (action as ACEAction).ace_id, seen)
		_census_rows(event.sub_events, seen)


## Records one verb under the words a reader would search for it by. The guides are written in
## DISPLAY names ("Host Game"), never in ids ("HostGame"), so the id is spaced through `capitalize()`
## - which is the same fallback display name the registration API itself gives a verb whose author
## declared none, rather than a spelling invented here. The row carries the id and not the
## definition, so no registry has to be built for a census, and it runs headlessly.
static func _note_verb(_provider_id: String, ace_id: String, seen: Dictionary) -> void:
	var id: String = ace_id.strip_edges()
	if id.is_empty():
		return
	seen[id.capitalize()] = true


## The page each census verb is taught by, counted: page id -> how many of the reader's verbs land on
## it. Ranked through the Manual's own search, so nothing here holds a second opinion about which
## guide teaches which verb.
static func page_hits(verbs: PackedStringArray) -> Dictionary:
	var hits: Dictionary = {}
	for verb: String in verbs:
		var section: Dictionary = EventSheetDocTeaches.best_section(
			EventSheetDocSearch.search(verb, HIT_CANDIDATES))
		var page_id: String = str(section.get("page_id", section.get("doc_id", "")))
		if page_id.is_empty():
			continue
		hits[page_id] = int(hits.get(page_id, 0)) + 1
	return hits


## The one page worth suggesting, as {track, page_id, title, hits}, or {} when there is nothing
## honest to suggest. PURE over the tracks and the hit table, so the whole decision is pinned by the
## suite without a project or a bundle.
##
## THE RULE, and each half of it is a refusal to nag: a page only qualifies if the reader's own rows
## already point at it (hits above zero - a suggestion nothing in their game asked for is an
## advertisement), and only if they have NOT ticked it (a reader who read it does not need it
## offered). Ties break on the track order the index wrote, then on the page order inside it, so two
## identical projects get the same suggestion.
static func suggestion(tracks: Array[Dictionary], hits: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_hits: int = 0
	for track: Dictionary in tracks:
		for id: Variant in (track.get("ids", []) as Array):
			var page_id: String = str(id)
			var count: int = int(hits.get(page_id, 0))
			if count <= 0 or count <= best_hits or is_read(page_id):
				continue
			best_hits = count
			best = {"track": str(track.get("title", "")), "page_id": page_id,
				"title": EventSheetDocLibrary.page_title(page_id), "hits": count}
	return best


## The sentence a suggestion is offered in. Says what the reader's own rows did to earn it, because a
## suggestion whose reason is invisible reads as an advertisement.
static func suggestion_text(suggestion_entry: Dictionary) -> String:
	if suggestion_entry.is_empty():
		return ""
	return EventSheetL10n.translate("Your rows already use %d verb(s) this page teaches: %s (%s)") % [
		int(suggestion_entry.get("hits", 0)), str(suggestion_entry.get("title", "")),
		str(suggestion_entry.get("track", "")),
	]


## Whether this suggestion may be shown right now, and books it when the answer is yes. Spent through
## the editor's SHARED offer budget, so a reader who ignored it is not asked again this session and
## the Manual cannot spend a budget the dialogs already spent.
##
## ONE BOOKING FOR THE WHOLE KIND, not one per suggested page. The budget's keys are "kind:name", and
## a suggestion is derived from the sheet being opened - so booking under the page it happens to
## name meant every sheet with a different answer bought a fresh offer, and a reader opening thirty
## files got thirty suggestions from a budget whose whole promise is one.
static func may_offer(suggestion_entry: Dictionary) -> bool:
	if suggestion_entry.is_empty():
		return false
	return may_offer_at_all() \
		and EventSheetDescriptionDrafts.may_offer("read_next", OFFER_SUBJECT, false,
			str(suggestion_entry.get("title", "")))


## Whether the one read-next offer of this session is still unspent. Asked BEFORE the suggestion is
## worked out, because working one out means taking a census of the sheet and putting up to forty
## verbs through the search index - on the file-open path, for an offer that has already been made.
static func may_offer_at_all() -> bool:
	return not EventSheetDescriptionDrafts.was_offered("read_next", OFFER_SUBJECT)


## The live suggestion for a set of open sheets: census, join, rank. The one call a surface makes.
static func suggest_for(sheets: Array[EventSheetResource]) -> Dictionary:
	return suggestion(all(), page_hits(census(sheets)))


# ── The page ──────────────────────────────────────────────────────────────────────────────────


## What the tracks page is called wherever the reader can see it.
const PAGE_TITLE := "Learning paths"

## The two things the page's rows do, named rather than performed - a page cannot open a guide or
## write a tick itself, it reports the action and the host decides what the name means.
const ACTION_OPEN := "track_open"
const ACTION_TICK := "track_tick"


## The sheets the tracks page reasons about when it is drawn. Set by the host right before it asks
## for the blocks, because `blocks_for` takes a kind and a name and nothing else - and a page that
## silently reasoned about no sheets would print "nothing to suggest" in a project full of rows.
## Cleared by the same host, so it never outlives the draw it was set for.
static var _page_sheets: Array[EventSheetResource] = []


## Draws the page against these sheets. The array is not kept: it is read by the draw that follows
## and dropped, so nothing here holds a second copy of what the dock already has open.
static func blocks_for_sheets(sheets: Array[EventSheetResource]) -> Array[Dictionary]:
	_page_sheets = sheets
	var blocks: Array[Dictionary] = list_blocks()
	_page_sheets = []
	return blocks


## The "read next" lead: the one page this reader's own rows point at. Empty when their rows point at
## nothing they have not already read, which is the honest answer and draws nothing.
static func read_next_blocks(sheets: Array[EventSheetResource]) -> Array[Dictionary]:
	if sheets.is_empty():
		return []
	var found: Dictionary = suggest_for(sheets)
	if found.is_empty():
		return []
	return [
		{"kind": "paragraph", "bbcode": "[i]%s[/i]" % EventSheetDocMarkdown.escape_brackets(
			suggestion_text(found))},
		{"kind": "buttons", "items": [{"label": EventSheetL10n.translate("Read it now"),
			"tooltip": EventSheetL10n.translate("Opens the page your rows point at."),
			"action": ACTION_OPEN, "argument": str(found.get("page_id", ""))}]},
	]


## The tracks page, as the block list every derived page in the Manual is drawn from: one section per
## track, and under it one row per page - the page, and the tick beside it.
static func list_blocks() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": PAGE_TITLE, "bbcode": PAGE_TITLE,
			"slug": EventSheetDocMarkdown.slug(PAGE_TITLE)},
		{"kind": "paragraph", "bbcode": EventSheetDocMarkdown.escape_brackets(EventSheetL10n.translate(
			"Guides you already have, in the order that teaches them. Tick a page off as you read it - the ticks stay on this machine, in this project, and are never written into your game."))},
	]
	# The read-next line leads the page, and is NOT budget-gated here: the budget exists to stop the
	# editor from offering the same page unprompted twice, and a reader who opened the learning paths
	# came to be told what to read next. `sheets` is empty because a static page has no dock to ask;
	# the caller that HAS one (the page's host) fills it in through blocks_for_sheets below.
	blocks.append_array(read_next_blocks(_page_sheets))
	var tracks: Array[Dictionary] = all()
	if tracks.is_empty():
		blocks.append({"kind": "paragraph", "bbcode": EventSheetDocMarkdown.escape_brackets(
			EventSheetL10n.translate("No paths are declared. A path is a list in a documentation index - add a Learning paths section to your project's own index and it appears here."))})
		return blocks
	for track: Dictionary in tracks:
		var title: String = str(track.get("title", ""))
		blocks.append({"kind": "heading", "level": 2, "text": title, "bbcode": title,
			"slug": EventSheetDocMarkdown.slug(title)})
		blocks.append({"kind": "paragraph", "bbcode": "%s\n[i]%s[/i]" % [
			EventSheetDocMarkdown.escape_brackets(str(track.get("blurb", ""))), progress_text(track)]})
		var position: int = 0
		for id: Variant in (track.get("ids", []) as Array):
			var page_id: String = str(id)
			position += 1
			var read: bool = is_read(page_id)
			blocks.append({"kind": "buttons", "items": [
				{"label": "%d. %s" % [position, EventSheetDocLibrary.page_title(page_id)],
					"tooltip": EventSheetL10n.translate("Opens this page."),
					"action": ACTION_OPEN, "argument": page_id},
				{"label": tick_label(read),
					"tooltip": EventSheetL10n.translate("Ticks this page off, or takes the tick back. Kept on this machine only."),
					"action": ACTION_TICK, "argument": page_id},
			]})
	return blocks


## What the tick beside a page reads as, in each of its two states. Pure, so the suite pins the
## words without a page around them.
static func tick_label(read: bool) -> String:
	return EventSheetL10n.translate("Read") if read else EventSheetL10n.translate("Mark read")
