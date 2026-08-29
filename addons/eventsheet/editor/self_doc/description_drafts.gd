# Godot EventSheets - drafting the description a thing has not been given yet, out of its own rows.
#
# A function that raises hp and flashes an icon already SAYS what it does; the words are just spread
# over its rows. So the draft is assembled from the rows themselves - each row's sentence in the
# words the row already shows, joined into one line: "Raises hp by amount, capped at max_hp; flashes
# the heart icon". Nothing is invented, nothing is guessed, and the same rows always compose the same
# sentence, on every machine and in every run. No model, no network, no clock.
#
# A DRAFT IS NOT A DESCRIPTION until somebody accepts it. Drafts are never written to the store on
# their own, so nothing this file produces can overwrite a line a person wrote: a draft is computed
# fresh each time it is asked for, shown as a draft, and only becomes the thing's description when a
# person accepts it. That also means there is nowhere for a stale draft to hide.
#
# HONESTY OVER FLUENCY. A row this plugin cannot read as a sentence - a block of hand-written code -
# does not get glossed over or dressed up. It composes to "and runs its own code", which is exactly
# true and tells the reader the rest of the story is in the file. A draft that lied would be worse
# than no draft, because the reader would stop looking.
#
# IT LISTS WHAT IS THERE AND COUNTS THE REST. A function of forty actions does not compose a
# forty-clause sentence: the draft names the first few and says how many more there are, so the line
# stays a line.
@tool
class_name EventSheetDescriptionDrafts
extends RefCounted

## How many row sentences a draft spells out before it starts counting. Three is a sentence a person
## reads at a glance; the rest arrive as a number, which is still information.
const SPELLED_OUT_LIMIT: int = 3

## What a row nobody can read as a sentence composes to. Deliberately plain: it says the truth (the
## rest is code) rather than pretending the draft knows more than it does.
const OWN_CODE_PHRASE := "runs its own code"

## The marker a caller shows beside a drafted line so a reader can tell a draft from words a person
## wrote. Display only - it is never stored with the text, because a draft is never stored at all.
const DRAFT_LABEL := "draft"

## Words a row carries for structure rather than for meaning. A description that matched only on
## these would match every function, so the drift check does not count them as subjects.
const STRUCTURAL_WORDS: PackedStringArray = ["self", "true", "false", "null", "and", "or", "not",
	"if", "else", "is", "in", "the", "to", "of", "new", "host", "node", "get", "set"]


## The draft for one function: its rows' sentences, joined. Empty when the function has no rows to
## compose from - a draft of nothing would just be the function's own name said twice.
static func for_function(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	return _compose(_phrases(_rows_of(event_function)))


## The draft for one group: what its rows REACT TO rather than what they do, because that is what a
## group is - "When the player lands, when the player is hurt". A group whose rows carry no triggers
## falls back to composing their actions, so an organizational group still drafts something true.
static func for_group(group: EventGroup) -> String:
	if group == null:
		return ""
	var rows: Array = group.events if not group.events.is_empty() else group.rows
	var triggers: PackedStringArray = _trigger_phrases(rows)
	if not triggers.is_empty():
		return _compose(triggers)
	return _compose(_phrases(rows))


## The draft for the sheet's own head: its groups, named, because a sheet's chapters are the honest
## summary of it. A sheet with no groups drafts from its top-level rows instead.
static func for_sheet(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var group_names: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.events:
		if entry is EventGroup:
			var group_name: String = EventSheetDescriptions.group_name_of(entry as EventGroup)
			if not group_name.strip_edges().is_empty():
				group_names.append("handles %s" % _lower_lead(group_name))
	if not group_names.is_empty():
		return _compose(group_names)
	return _compose(_phrases(sheet.events))


## THE OFFER BUDGET: what has already been offered this session, as a set of keys. A draft is shown
## ONCE per thing per session - a person who dismissed the offer for `heal` is not asked about `heal`
## again while the editor is open, whichever surface asks. Session-only on purpose: this is a
## conversation, not a preference, and it has no business surviving a restart or landing in a file.
static var _offered: Dictionary = {}


## Whether a draft may be OFFERED for this thing right now, and books the offer when the answer is
## yes. The key is "kind:name", which is the same key the coverage list uses, so the dialog that asks
## about a function and the panel that asks about a group cannot both spend a budget of one.
##
## Never offers when the thing already has words: an accepted description is an answer, and asking
## again is the nagging this budget exists to prevent.
static func may_offer(kind: String, name: String, already_described: bool, draft: String) -> bool:
	if already_described or draft.strip_edges().is_empty():
		return false
	var key: String = "%s:%s" % [kind, name]
	if _offered.has(key):
		return false
	_offered[key] = true
	return true


## Forgets every offer made so far. The editor calls this when a project is closed, and a test calls
## it on the way in AND on the way out - a static set that outlived its test would decide the next
## test's answer, and the suite runs serially in one process.
static func clear_offers() -> void:
	_offered.clear()


## The draft for one of a function's parameters, taken from how the function's rows USE it: the first
## row that names the parameter says what it is for. Empty when no row mentions it - a parameter
## nothing reads has nothing honest to say about itself.
static func for_parameter(event_function: EventFunction, param_id: String) -> String:
	if event_function == null or param_id.strip_edges().is_empty():
		return ""
	for phrase: String in _phrases(_rows_of(event_function)):
		if _mentions_word(phrase, param_id):
			return "Used to %s" % _lower_lead(phrase)
	return ""


## The draft for any catalog entry, dispatched by its kind - what the Doctor's page calls per line so
## it never has to know which kind it is looking at.
static func for_entry(sheet: EventSheetResource, entry: Dictionary) -> String:
	var kind: String = str(entry.get("kind", ""))
	var name: String = str(entry.get("name", ""))
	match kind:
		"sheet":
			return for_sheet(sheet)
		"function":
			return for_function(_find_function(sheet, name))
		"group":
			return for_group(_find_group(sheet, name))
		_:
			return ""


## Whether a description a person ACCEPTED has drifted from what its rows now say. The test is not
## "the words changed": it is whether the accepted line still mentions ANY of the subjects the rows
## compose today. A rewritten sentence that still talks about hp and the heart icon has not drifted;
## a function whose rows were replaced wholesale has, and its description is now describing something
## that is no longer there.
##
## Says nothing about a thing with no description and nothing about a thing with no rows: there is no
## drift without both a claim and something to check it against.
static func function_description_drifted(event_function: EventFunction) -> bool:
	if event_function == null:
		return false
	var described: String = EventSheetDescriptions.for_function(event_function)
	if described.strip_edges().is_empty():
		return false
	return _drifted(described, _rows_of(event_function))


## The same question about a GROUP's description: does the chapter's prose still talk about what its
## rows do? Asked exactly the way it is asked of a function, because a description is a description
## and a reader who was told a group is about landing does not care that a group is not a function.
static func group_description_drifted(group: EventGroup) -> bool:
	if group == null:
		return false
	return _drifted(EventSheetDescriptions.for_group(group),
		group.events if not group.events.is_empty() else group.rows)


## And the same question about the sheet's PROSE PARAGRAPHS - its `##` comment rows. A paragraph
## claims something about the rows it introduces, so the rows it is checked against are the ones that
## FOLLOW it in its own container, up to the next paragraph: that run is what the paragraph is about,
## and it is the run that gets replaced when somebody reworks a section and leaves the words above it.
##
## Returns one entry per drifted paragraph, {text, where}, in sheet order. Says nothing about a
## paragraph that introduces no rows - there is no drift without something to check against.
static func drifted_paragraphs(sheet: EventSheetResource) -> Array[Dictionary]:
	var drifted: Array[Dictionary] = []
	if sheet == null:
		return drifted
	_walk_paragraphs(sheet.events, "", drifted)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			_walk_paragraphs(_rows_of(event_function), event_function.function_name, drifted)
	return drifted


## THE drift test, over any run of rows: an accepted line has drifted when it mentions none of the
## identifiers those rows name today. One implementation, so a function, a group and a paragraph are
## all judged by the same rule rather than by three that slowly diverge.
static func _drifted(described: String, rows: Array) -> bool:
	if described.strip_edges().is_empty():
		return false
	var subjects: PackedStringArray = _subjects_of(rows)
	if subjects.is_empty():
		return false
	for subject: String in subjects:
		if _mentions_word(described, subject):
			return false
	return true


## The recursive half of the paragraph drift walk. A documentation comment row opens a run; the run
## ends at the next one or at the end of the container.
static func _walk_paragraphs(rows: Array, where: String, drifted: Array[Dictionary]) -> void:
	for index: int in range(rows.size()):
		var entry: Variant = rows[index]
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_walk_paragraphs(group.events if not group.events.is_empty() else group.rows,
				EventSheetDescriptions.group_name_of(group), drifted)
		elif entry is CommentRow and EventSheetSheetProse.is_readable(entry as CommentRow):
			var paragraph: CommentRow = entry as CommentRow
			var introduced: Array = []
			for follow: int in range(index + 1, rows.size()):
				if rows[follow] is CommentRow and EventSheetSheetProse.is_readable(rows[follow] as CommentRow):
					break
				introduced.append(rows[follow])
			if _drifted(paragraph.text, introduced):
				drifted.append({"text": paragraph.text.strip_edges(), "where": where})
		elif entry is EventRow:
			_walk_paragraphs((entry as EventRow).sub_events, where, drifted)


## The words a drift check looks for in an accepted description: the identifiers the function's rows
## NAME - the variables they write, the values they read, the nodes and messages they carry. Taken
## from the rows' own parameter values rather than from the verbs around them, because the verb is
## the plugin's word ("Set", "Print") while the value is the user's, and a truthful description of
## these rows has to share at least one of the user's words with them.
##
## Structural words that every second row carries (`self`, `true`, a bare number) are not subjects: a
## description matching on `self` would match everything and the check would never fire.
static func _subjects_of(rows: Array) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for value: String in _named_values(rows):
		for token: String in _identifier_tokens(value):
			if not found.has(token):
				found.append(token)
	return found


## Every parameter value the actions under these rows carry, in row order.
static func _named_values(rows: Array) -> PackedStringArray:
	var values: PackedStringArray = PackedStringArray()
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			values.append_array(_named_values(group.events if not group.events.is_empty() else group.rows))
		elif entry is EventRow:
			var row: EventRow = entry as EventRow
			for action_entry: Variant in row.actions:
				if action_entry is ACEAction and (action_entry as ACEAction).enabled:
					var action: ACEAction = action_entry as ACEAction
					var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
					var keys: PackedStringArray = PackedStringArray()
					for key: Variant in params.keys():
						keys.append(str(key))
					keys.sort()
					for key: String in keys:
						values.append(str(params.get(key, "")))
			values.append_array(_named_values(row.sub_events))
	return values


## The identifier-ish words inside one value expression, lowercased: everything a person could
## reasonably repeat in a sentence about this row, minus the structural words nobody would.
static func _identifier_tokens(value: String) -> PackedStringArray:
	var separated: String = value.to_lower()
	for separator: String in ["(", ")", "\"", "'", ".", ",", "+", "-", "*", "/", "=", "<", ">", "[", "]", ":", "$", "%"]:
		separated = separated.replace(separator, " ")
	var tokens: PackedStringArray = PackedStringArray()
	for token: String in separated.split(" "):
		var word: String = token.strip_edges()
		if word.length() < 2 or STRUCTURAL_WORDS.has(word) or word.is_valid_int() or word.is_valid_float():
			continue
		tokens.append(word)
	return tokens


## Every readable sentence under these rows, depth first, in sheet order - a row's own conditions and
## actions before its children's, so the composed line reads in the order the rows run.
static func _phrases(rows: Array) -> PackedStringArray:
	var phrases: PackedStringArray = PackedStringArray()
	_walk(rows, phrases)
	return phrases


## The recursive half of the walk above. Kept separate so callers get a fresh array every time and
## two drafts can never share one.
static func _walk(rows: Array, into: PackedStringArray) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_walk(group.events if not group.events.is_empty() else group.rows, into)
		elif entry is RawCodeRow:
			if not into.has(OWN_CODE_PHRASE):
				into.append(OWN_CODE_PHRASE)
		elif entry is EventRow:
			var row: EventRow = entry as EventRow
			for action_entry: Variant in row.actions:
				var phrase: String = _action_phrase(action_entry)
				if not phrase.is_empty():
					into.append(phrase)
			_walk(row.sub_events, into)


## Every trigger sentence under these rows - what a group's draft is built from.
static func _trigger_phrases(rows: Array) -> PackedStringArray:
	var phrases: PackedStringArray = PackedStringArray()
	for entry: Variant in rows:
		if entry is EventRow:
			var row: EventRow = entry as EventRow
			var phrase: String = _condition_phrase(row.trigger)
			if not phrase.is_empty() and not phrases.has(phrase):
				phrases.append(phrase)
	return phrases


## One action's sentence, in the same words the row shows: the descriptor's display text with this
## action's own parameter values filled in. Empty when the action is disabled or its descriptor is not
## registered - a draft never guesses at a verb it cannot look up.
static func _action_phrase(action_entry: Variant) -> String:
	if not action_entry is ACEAction:
		return ""
	var action: ACEAction = action_entry as ACEAction
	if not action.enabled:
		return ""
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if descriptor == null:
		return ""
	var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	return _clean(descriptor.format_display(params))


## One trigger's sentence, resolved the same way an action's is.
static func _condition_phrase(condition_entry: Variant) -> String:
	if not condition_entry is ACECondition:
		return ""
	var condition: ACECondition = condition_entry as ACECondition
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if descriptor == null:
		return ""
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	return _clean(descriptor.format_display(params))


## Phrases joined into one line: the first few spelled out, the rest counted. Commas between the early
## clauses and a semicolon before the last, which is how the sentence reads aloud.
static func _compose(phrases: PackedStringArray) -> String:
	if phrases.is_empty():
		return ""
	var spelled: PackedStringArray = PackedStringArray()
	for index: int in range(min(phrases.size(), SPELLED_OUT_LIMIT)):
		spelled.append(_lower_lead(phrases[index]))
	var remainder: int = phrases.size() - spelled.size()
	var sentence: String = ""
	if spelled.size() == 1:
		sentence = spelled[0]
	else:
		var head: PackedStringArray = spelled.slice(0, spelled.size() - 1)
		sentence = "%s; %s" % [", ".join(head), spelled[spelled.size() - 1]]
	if remainder > 0:
		sentence += "; and %d more step%s" % [remainder, "" if remainder == 1 else "s"]
	return _upper_lead(sentence)


## Display text with its markup, slot braces and string quotes taken off, so a composed sentence reads
## as prose rather than as a template. The quotes go because a draft is a sentence: a message a row
## prints reads as its words, and leaving the quotes in would also mean nesting them inside the quoted
## draft a Doctor line shows.
static func _clean(text: String) -> String:
	var plain: String = EventSheetBBCodeLite.strip(text).replace("{", "").replace("}", "").replace("\"", "")
	while plain.contains("  "):
		plain = plain.replace("  ", " ")
	return plain.strip_edges().trim_suffix(".")


## A phrase with its first letter lowered, for a clause in the middle of a sentence. An identifier or
## an all-caps word is left exactly as it is - "HP" is not "hP".
static func _lower_lead(text: String) -> String:
	if text.length() < 2:
		return text
	var lead: String = text.substr(0, 1)
	var second: String = text.substr(1, 1)
	if lead != lead.to_lower() and second == second.to_upper() and second != second.to_lower():
		return text
	return lead.to_lower() + text.substr(1)


## A sentence with its first letter raised, which is how the composed line is shown.
static func _upper_lead(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


## Whether a piece of prose names this identifier as a WORD rather than as a fragment of a longer one,
## so "hp" does not match "shipping".
static func _mentions_word(text: String, word: String) -> bool:
	var needle: String = word.strip_edges().to_lower()
	if needle.is_empty():
		return false
	var haystack: String = " %s " % text.to_lower()
	for separator: String in [" ", ",", ".", ";", ":", "(", ")", "\"", "'"]:
		haystack = haystack.replace(separator, " ")
	return haystack.contains(" %s " % needle)


## The function of this sheet with this name, or null - the lookup the entry dispatch needs.
static func _find_function(sheet: EventSheetResource, name: String) -> EventFunction:
	if sheet == null:
		return null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == name:
			return entry as EventFunction
	return null


## The group of this sheet with this name, at any depth, or null.
static func _find_group(sheet: EventSheetResource, name: String) -> EventGroup:
	if sheet == null:
		return null
	return _find_group_in(sheet.events, name)


## A function's rows through both the current field and the older alias. One place, so the drift
## check, the draft and the subject walk cannot read a function's body three slightly different ways.
static func _rows_of(event_function: EventFunction) -> Array:
	if event_function == null:
		return []
	return event_function.events if not event_function.events.is_empty() else event_function.rows


## The recursive half of the group lookup above.
static func _find_group_in(rows: Array, name: String) -> EventGroup:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			if EventSheetDescriptions.group_name_of(group) == name:
				return group
			var nested: EventGroup = _find_group_in(group.events if not group.events.is_empty() else group.rows, name)
			if nested != null:
				return nested
		elif entry is EventRow:
			var nested_row: EventGroup = _find_group_in((entry as EventRow).sub_events, name)
			if nested_row != null:
				return nested_row
	return null
