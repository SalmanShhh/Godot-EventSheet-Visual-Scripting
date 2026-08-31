@tool
class_name EventSheetAskAnswers
extends RefCounted

# ONE SEARCH THAT KNOWS WHAT THE SHEET KNOWS - what a typed word ANSWERS, as well as what it adds.
#
# The Quick Add field has always been a way to say a row and have it appear. But a name crossing a
# reader's mind is not always a row they want to add: "chase" is as often "where IS Chase" as it is
# "put a Chase row here", and answering that meant remembering which of four windows knows - the
# Command Palette for a function, Find in Project for a row, the Project Doctor for a finding, the
# head band for a state. Four doors for one question is three doors too many.
#
# So the field ANSWERS as well as adds. Every answer says what KIND of thing it is and what HOME it
# lives in, the answers of a kind stand together, and Enter opens the highlighted one. The add is
# still there and still first: Enter on an untouched list adds the row by sentence exactly as it
# always did, so nothing anybody already types has changed meaning.
#
# NO NEW INDEX AND NO SECOND STORE. Every answer here is a read of something the editor already
# holds: the completion seam's per-sheet lists (built once, filtered per keystroke, dropped by the
# same two invalidations as every other field kind), the project Find's own collection of what a
# sheet can be found by, and the findings of the last Doctor run as the Project bar already keeps
# them. The join happens at ASK time and is thrown away; nothing is written down.
#
# WHAT IS ANSWERED, AND WHAT IS NOT. NAMES come from every sheet the reader has open, because what a
# sheet declares is a handful of them and they are all already in memory. ROWS come from the sheet in
# front of you, because what a sheet SAYS is every parameter of every row, and ranking thousands of
# sentences per open tab per keypress is how a search stops being used. Neither boundary is hidden:
# the Rows group ends in the door to the Find window, which reaches every sheet in the project, and
# a keystroke that loaded and lifted every script to answer would be a keystroke that took seconds.
# An answer a reader cannot see the edge of is worse than one that states it.
#
# EXACT NAMES ABOVE PROSE, ALWAYS. A state, a variable, a function, a signal and a mode are NAMES; a
# row and a finding are SENTENCES. A word found in a sentence is a weaker answer than the same word
# being something's whole name, so every name answer sits above every prose answer, whatever else
# they score. Inside that, the shipped completion ranking decides - one ranker, so a name that ranks
# first in a field ranks first here.


## What an answer can BE, and the order two groups fall into when they are ranked equally. It is the
## order a reader's own question tends to arrive in: the machine they were just thinking about, the
## rows that mention it, the names it is built out of, and last the things the Doctor said about it.
const KIND_ORDER: PackedStringArray = [
	EventSheetCompletions.KIND_STATE,
	EventSheetCompletions.KIND_ROW,
	EventSheetCompletions.KIND_VARIABLE,
	EventSheetCompletions.KIND_FUNCTION,
	EventSheetCompletions.KIND_SIGNAL,
	EventSheetCompletions.KIND_MODE,
	EventSheetCompletions.KIND_FINDING,
]

## The kinds whose answer is a NAME. Everything else is prose, and prose never outranks a name.
const NAME_KINDS: PackedStringArray = [
	EventSheetCompletions.KIND_STATE,
	EventSheetCompletions.KIND_VARIABLE,
	EventSheetCompletions.KIND_FUNCTION,
	EventSheetCompletions.KIND_SIGNAL,
	EventSheetCompletions.KIND_MODE,
]

## What a name answer is lifted by, so that the weakest name still beats the strongest sentence. One
## band above the shipped ranker's own ceiling, which is 1000 for a whole-name match.
const NAME_BAND: int = 10000

## The shortest query worth answering. One letter matches most of a project and answers nothing; two
## is where a name starts to be a name. Below it the field is the add bar it has always been.
const ASK_FLOOR: int = 2

## How many answers of one kind are shown, and the total the list stops at. THE BAND SCALE LAW: a
## group says what it holds and how much of it is on screen, and it is the answers themselves that
## are enumerated rather than every kind that had something to say.
const GROUP_LIMIT: int = 4
const TOTAL_LIMIT: int = 24

## The separator between the halves of an answer's label - its kind, then its home. The completion
## seam's own, so an answer and a completion are punctuated alike.
const SEPARATOR: String = EventSheetCompletions.SEPARATOR


## Every answer to one query, grouped and ready to draw: heading entries and answer entries in one
## flat list, in the order they are shown. Empty for a query too short to answer.
##
## `shelf` is what the caller already had in its hands, and nothing here goes looking for more:
##     sheets    [{path, sheet}]   the sheets the reader has open, the active one first
##     findings  Array             the findings of the last Doctor run, as it reported them
##
## Pure over its two arguments, which is what lets a test pin the exact page for a fixture and the
## field draw the same one.
## ONLY THE ANSWERS THAT ARE SHOWN ARE EVER BUILT. A query of one or two characters matches most of
## a big project - every sentence in it contains an "h" - so a walk that made a labelled answer out
## of each match would build twelve thousand of them, translate a word for each, and then throw all
## but a dozen away on the very next keypress. So the walk keeps a running best few per kind and
## nothing else, and the label is composed at the end, for the handful on the page.
static func answers(query: String, shelf: Dictionary) -> Array[Dictionary]:
	var typed: String = query.strip_edges().to_lower()
	if typed.length() < ASK_FLOOR:
		return []
	var shelves: Dictionary = {}
	_walk(typed, shelf, shelves)
	var groups: Array[Dictionary] = []
	for kind: Variant in shelves.keys():
		var group: Dictionary = shelves[kind]
		var kept: Array = group["kept"]
		if kept.is_empty():
			continue
		groups.append({"kind": str(kind), "kept": kept, "held": int(group["held"]),
			"best": int((kept[0] as Dictionary)["score"])})
	groups.sort_custom(_group_before)
	var page: Array[Dictionary] = []
	for group: Dictionary in groups:
		var kept: Array = group["kept"]
		var shown: int = mini(kept.size(), TOTAL_LIMIT - page.size())
		if shown <= 0:
			break
		page.append(heading(str(group["kind"]), shown, int(group["held"])))
		for at: int in range(shown):
			page.append(_dressed(kept[at]))
	return page


## One answer offered to its group. `held` counts every match so a heading can say how much there is;
## `kept` holds only the best few, in order, so a group of ten thousand costs four Dictionaries.
##
## Returns the score a LATER answer has to reach to be worth offering at all - 0 while the group has
## room, and the worst kept score once it is full. A caller that carries that number can reject most
## of a big sheet with one integer comparison instead of a call, which on a sheet of thousands is the
## difference between a keystroke and a stutter.
static func _offer(shelves: Dictionary, kind: String, score: int, home: String, path: String,
		source: Dictionary) -> int:
	if not shelves.has(kind):
		shelves[kind] = {"kept": [], "held": 0}
	var group: Dictionary = shelves[kind]
	group["held"] = int(group["held"]) + 1
	var kept: Array = group["kept"]
	var text: String = str(source.get("text", ""))
	if kept.size() >= GROUP_LIMIT and not _outranks(score, home, text, kept[kept.size() - 1]):
		return int((kept[kept.size() - 1] as Dictionary)["score"])
	var record: Dictionary = {
		"text": text,
		"kind": kind,
		"home": home,
		"path": path,
		"score": score,
		"uid": str(source.get("uid", "")),
		"symbol": str(source.get("symbol", "")),
		"finding": source.get("finding", {}),
	}
	var at: int = kept.size()
	while at > 0 and _outranks(score, home, text, kept[at - 1]):
		at -= 1
	kept.insert(at, record)
	if kept.size() > GROUP_LIMIT:
		kept.resize(GROUP_LIMIT)
	return _floor_of(kept)


## The score a later answer must reach for a full group: the worst one being kept. 0 while the group
## still has room, which is what "everything is worth offering" reads as.
static func _floor_of(kept: Array) -> int:
	return int((kept[kept.size() - 1] as Dictionary)["score"]) if kept.size() >= GROUP_LIMIT else 0


## The total order two answers of one kind fall into: the better score first, then the home and the
## text. Total, so the best few are the same few whatever order the shelf was walked in - which is
## what keeps the list the same twice over an unchanged project.
static func _outranks(score: int, home: String, text: String, against: Dictionary) -> bool:
	if score != int(against["score"]):
		return score > int(against["score"])
	if home != str(against["home"]):
		return home < str(against["home"])
	return text < str(against["text"])


## The label, composed for the few answers that are actually shown: what kind it is, then where it
## lives. This is the only place a word is translated, which is why it is the last thing that happens.
static func _dressed(record: Dictionary) -> Dictionary:
	var answer: Dictionary = record.duplicate()
	answer["detail"] = "%s %s %s" % [kind_word(str(record["kind"]), record), SEPARATOR,
		str(record["home"])]
	return answer


## The heading over one group: the kind in the plural, and - when the group holds more than fits -
## how much of it is on screen. A count that is the whole group is not said, because "4 of 4" is a
## number a reader has to read to learn nothing.
static func heading(kind: String, shown: int, held: int) -> Dictionary:
	var word: String = group_word(kind)
	return {
		"text": word if shown >= held else EventSheetL10n.translate("%s - %d of %d") % [word, shown, held],
		"detail": "",
		"kind": kind,
		"heading": true,
	}


## Every kind the shelf can answer with, offered to its group. Nothing is built here that is not
## kept: this walk is what runs over every candidate in every open sheet, and everything expensive
## has been pushed either into the pools (built once) or into the dressing (done for a dozen).
static func _walk(typed: String, shelf: Dictionary, shelves: Dictionary) -> void:
	var sheets: Array = shelf.get("sheets", []) as Array
	for at: int in range(sheets.size()):
		var opened: Dictionary = sheets[at]
		var sheet: EventSheetResource = opened.get("sheet") as EventSheetResource
		if sheet == null:
			continue
		var path: String = str(opened.get("path", ""))
		var home: String = home_of(path, sheet)
		_take_symbols(sheet, path, home, typed, shelves)
		# ROWS COME FROM THE SHEET IN FRONT OF YOU. What a sheet DECLARES is a handful of names and
		# costs nothing to rank across every open tab; what it SAYS is every parameter of every row,
		# which on a long sheet is thousands of sentences. Ranking those for one sheet is a keystroke;
		# ranking them for eight is a stutter, and a stutter is how a search stops being used. So the
		# rows answered are the rows of the sheet being read, and the group ends in the door to the
		# window that reaches every sheet in the project - stated, rather than quietly narrower.
		if at == 0:
			_take_rows(sheet, path, home, typed, shelves)
	# The modes are the GAME's, not one object's, so they are asked once off the active sheet rather
	# than once per open tab - the same list would otherwise be answered as many times as there are
	# tabs, each claiming a different home for a declaration that has only one.
	if not sheets.is_empty():
		var first: Dictionary = sheets[0]
		_take_modes(first.get("sheet") as EventSheetResource, typed, shelves)
	_take_findings(shelf.get("findings", []) as Array, typed, shelves)


## The states, variables, functions and signals one sheet declares. The completion seam holds the
## list; this only ranks it, and lifts it clear of every sentence.
static func _take_symbols(sheet: EventSheetResource, path: String, home: String, typed: String,
		shelves: Dictionary) -> void:
	for candidate: Dictionary in EventSheetCompletions.candidates(sheet,
			EventSheetCompletions.FIELD_ASK_SYMBOL):
		var score: int = EventSheetCompletions.score_of(candidate, typed)
		if score > 0:
			_offer(shelves, str(candidate.get("kind", "")), score + NAME_BAND, home, path, candidate)


## The rows of one sheet, matched on the text the Find window matches on. Prose, so no letters-in-
## order tier: a subsequence hit inside a sentence is a coin toss, and testing it would cost a walk
## of every sentence in the sheet on every keypress.
static func _take_rows(sheet: EventSheetResource, path: String, home: String, typed: String,
		shelves: Dictionary) -> void:
	# The floor is what makes this walk cheap on a sheet of thousands: once the group is full, a
	# candidate that cannot reach the worst kept score is rejected here, on an integer, rather than
	# inside a call. A count is still wanted for the heading, so the rejected ones are still tallied.
	if not shelves.has(EventSheetCompletions.KIND_ROW):
		shelves[EventSheetCompletions.KIND_ROW] = {"kept": [], "held": 0}
	var group: Dictionary = shelves[EventSheetCompletions.KIND_ROW]
	var floor_score: int = _floor_of(group["kept"])
	for candidate: Dictionary in EventSheetCompletions.candidates(sheet,
			EventSheetCompletions.FIELD_ASK_ROW):
		var score: int = EventSheetCompletions.score_of(candidate, typed, false)
		if score <= 0:
			continue
		if score < floor_score:
			group["held"] = int(group["held"]) + 1
			continue
		floor_score = _offer(shelves, EventSheetCompletions.KIND_ROW, score, home, path, candidate)


## The modes the game declares. Said as the WORD a reader types and the row shows, with the enum
## member carried underneath - the same pair the dropdown offers, through the same cached list.
static func _take_modes(sheet: EventSheetResource, typed: String, shelves: Dictionary) -> void:
	if sheet == null:
		return
	var home: String = EventSheetL10n.translate("the game")
	for candidate: Dictionary in EventSheetCompletions.candidates(sheet,
			EventSheetCompletions.FIELD_MODE):
		var member: String = str(candidate.get("text", ""))
		var word: String = str(candidate.get("detail", member))
		var scoring: Dictionary = {"text": word, "lower": word.to_lower(), "symbol": member}
		var score: int = EventSheetCompletions.score_of(scoring, typed)
		if score > 0:
			_offer(shelves, EventSheetCompletions.KIND_MODE, score + NAME_BAND, home, "", scoring)


## The findings of the last Doctor run. Prose, like a row - and the reason this whole list is worth
## having: an inbox nobody opens is an inbox nobody reads, and a finding that surfaces the moment its
## subject crosses somebody's mind is a finding that gets fixed.
##
## Nothing here RUNS the Doctor. An empty findings list means nobody has run one this session, and
## the answer to that is a page with no Findings group rather than an audit on a keypress.
static func _take_findings(findings: Array, typed: String, shelves: Dictionary) -> void:
	for entry: Variant in findings:
		if not (entry is Dictionary):
			continue
		var finding: Dictionary = entry
		var message: String = str(finding.get("message", ""))
		var scoring: Dictionary = {"text": message, "lower": message.to_lower(),
			"detail": str(finding.get("subject", "")), "finding": finding}
		var score: int = EventSheetCompletions.score_of(scoring, typed, false)
		if score <= 0:
			continue
		var path: String = str(finding.get("path", ""))
		_offer(shelves, EventSheetCompletions.KIND_FINDING, score,
			path.get_file() if not path.is_empty() else EventSheetL10n.translate("the project"),
			path, scoring)


## What one answer's kind is CALLED, in the reader's own language. A finding says its SEVERITY rather
## than the word "finding", because "error" is what a reader is actually looking at - said in the
## singular, since one answer is one finding, and in the Doctor's own vocabulary, where "Note" is the
## word for the mildest kind because the page is read by people shipping a game.
static func kind_word(kind: String, source: Dictionary = {}) -> String:
	if kind == EventSheetCompletions.KIND_FINDING:
		match str((source.get("finding", {}) as Dictionary).get("severity", "info")):
			"error":
				return EventSheetL10n.translate("Error")
			"warning":
				return EventSheetL10n.translate("Warning")
		return EventSheetL10n.translate("Note")
	match kind:
		EventSheetCompletions.KIND_STATE:
			return EventSheetL10n.translate("State")
		EventSheetCompletions.KIND_ROW:
			return EventSheetL10n.translate("Row")
		EventSheetCompletions.KIND_VARIABLE:
			return EventSheetL10n.translate("Variable")
		EventSheetCompletions.KIND_FUNCTION:
			return EventSheetL10n.translate("Function")
		EventSheetCompletions.KIND_SIGNAL:
			return EventSheetL10n.translate("Signal")
		EventSheetCompletions.KIND_MODE:
			return EventSheetL10n.translate("Mode")
	return kind


## And the plural a group of them is headed with.
static func group_word(kind: String) -> String:
	match kind:
		EventSheetCompletions.KIND_STATE:
			return EventSheetL10n.translate("States")
		EventSheetCompletions.KIND_ROW:
			return EventSheetL10n.translate("Rows")
		EventSheetCompletions.KIND_VARIABLE:
			return EventSheetL10n.translate("Variables")
		EventSheetCompletions.KIND_FUNCTION:
			return EventSheetL10n.translate("Functions")
		EventSheetCompletions.KIND_SIGNAL:
			return EventSheetL10n.translate("Signals")
		EventSheetCompletions.KIND_MODE:
			return EventSheetL10n.translate("Modes")
		EventSheetCompletions.KIND_FINDING:
			return EventSheetL10n.translate("Findings")
	return kind


## What a sheet is CALLED where an answer has room to say it: the class it declares, else the file it
## is, else the word for a sheet nobody has saved yet.
static func home_of(path: String, sheet: EventSheetResource) -> String:
	if sheet != null and not sheet.custom_class_name.strip_edges().is_empty():
		return sheet.custom_class_name.strip_edges()
	if not path.strip_edges().is_empty():
		return path.get_file()
	return EventSheetL10n.translate("this sheet")


## Two groups: the one holding the better answer first, then the fixed order above. So typing a
## state's name puts States at the top and typing a word out of a finding puts Findings there,
## without either kind having been declared more important than the other.
static func _group_before(left: Dictionary, right: Dictionary) -> bool:
	if int(left["best"]) != int(right["best"]):
		return int(left["best"]) > int(right["best"])
	return _kind_rank(str(left["kind"])) < _kind_rank(str(right["kind"]))


static func _kind_rank(kind: String) -> int:
	var found: int = KIND_ORDER.find(kind)
	return found if found >= 0 else KIND_ORDER.size()
