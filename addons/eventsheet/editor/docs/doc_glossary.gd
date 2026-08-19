# EventSheet - EventSheetDocGlossary: "Coming from another event-sheet editor".
#
# A reader who already builds games with events arrives holding a vocabulary. Most of it survives
# the move unchanged (event, condition, action, sub-event, trigger); a handful of words mean
# something slightly different here, and two or three name a thing this editor spells another way.
# This file is that list, and it is a LIST OF TERMS rather than a page of prose so the same entries
# feed the Manual's search as its "glossary" kind.
#
# THE NAMING RULE, and it is not a style preference: the other editor is never named in code -
# not in an identifier, not in a string, not in a comment, not in a test label. The panel is
# titled "Coming from another event-sheet editor" and the entries say "there" and "here". The
# repo's prose guides may name it; nothing that ships as a string does.
#
# Each entry is {key, term, here, note, related}:
#   key      the slug the page anchors it under, and the id half of "reference:glossary/<key>"
#   term     the word the reader arrives with
#   here     the same idea in this editor's own words - one line, the way the sheet says it
#   note     what actually differs, or "" when nothing does
#   related  other terms worth reading next, as keys
@tool
class_name EventSheetDocGlossary
extends RefCounted

## The page's own title. Frozen in the sense that matters: it is what the tree row, the breadcrumb
## and the search result all read, and it is the phrasing the naming rule above requires.
const PAGE_TITLE := "Coming from another event-sheet editor"

## The terms, in reading order. Authored rather than derived: a glossary is a translation between
## two vocabularies, and only one of them is in this repo.
const TERMS: Array[Dictionary] = [
	{
		"key": "pick",
		"term": "Pick",
		"here": "A condition on an object filters which instances the actions below it run on - exactly as it did there.",
		"note": "A loop over a group with an \"if\" inside reads as one picking event, so hand-written code arrives as the picking row it already was.",
		"related": ["family", "for-each"],
	},
	{
		"key": "family",
		"term": "Family",
		"here": "Group. A sheet declared as a Family iterates every member, and Godot's own node groups do the same job one level down.",
		"note": "",
		"related": ["pick", "object-type"],
	},
	{
		"key": "layout",
		"term": "Layout",
		"here": "Scene. A layout there is a .tscn here, and changing one is Go To Scene.",
		"note": "",
		"related": ["object-type"],
	},
	{
		"key": "instance-variable",
		"term": "Instance variable",
		"here": "A sheet variable. Mark it exported and every instance gets its own value in the Inspector.",
		"note": "A variable placed inside the event flow is a local instead, exactly as a local variable was there.",
		"related": ["global-variable"],
	},
	{
		"key": "global-variable",
		"term": "Global variable",
		"here": "A variable on a shared sheet or an autoload - plain GDScript rules, no special kind of row.",
		"note": "",
		"related": ["instance-variable"],
	},
	{
		"key": "wait",
		"term": "Wait",
		"here": "Wait X seconds, and its family: Wait For Signal, Wait Until, Wait For All Of, Wait For Any Of.",
		"note": "A wait suspends the event it is in and lets the rest of the frame carry on, which is what it did there too.",
		"related": ["trigger-once", "every-tick"],
	},
	{
		"key": "else",
		"term": "Else",
		"here": "Else, and Else If - the same row, under the event it answers.",
		"note": "",
		"related": ["sub-event", "or-block"],
	},
	{
		"key": "or-block",
		"term": "Or block",
		"here": "An event whose conditions are joined with Or rather than And.",
		"note": "",
		"related": ["else"],
	},
	{
		"key": "trigger-once",
		"term": "Trigger once",
		"here": "Trigger Once - the same rising-edge condition, and it reads the same way in the row.",
		"note": "Where a signal exists, reacting to it beats polling plus Trigger Once, and the picker offers the signal twin when there is one.",
		"related": ["every-tick", "wait"],
	},
	{
		"key": "sub-event",
		"term": "Sub-event",
		"here": "Sub-event. Nested under its parent's conditions, and it compiles to nesting.",
		"note": "",
		"related": ["else", "group"],
	},
	{
		"key": "every-tick",
		"term": "Every tick",
		"here": "Every Tick, and it is still the row that runs each frame.",
		"note": "Most sheets need far fewer of them here: a signal trigger reacts once instead of asking every frame.",
		"related": ["trigger-once"],
	},
	{
		"key": "object-type",
		"term": "Object type",
		"here": "The object's class - CharacterBody2D, Area2D, Timer - and its conditions, actions and expressions group under it.",
		"note": "",
		"related": ["family", "behavior"],
	},
	{
		"key": "behavior",
		"term": "Behavior",
		"here": "Behavior. A pack you attach to a node, with its own conditions, actions and expressions.",
		"note": "",
		"related": ["object-type", "plugin"],
	},
	{
		"key": "plugin",
		"term": "Plugin",
		"here": "A script in the addons folder with annotations on it - no manifest, no registration call.",
		"note": "",
		"related": ["behavior"],
	},
	{
		"key": "function",
		"term": "Function",
		"here": "Function. A named block of actions with typed parameters and a return value, called from any row.",
		"note": "",
		"related": ["group"],
	},
	{
		"key": "group",
		"term": "Group",
		"here": "Group. A collapsible band of events with its own name, and it can be turned on and off.",
		"note": "",
		"related": ["sub-event", "function"],
	},
	{
		"key": "for-each",
		"term": "For each",
		"here": "For Each, over a list, a group or a family - the row that repeats what is under it.",
		"note": "",
		"related": ["pick", "family"],
	},
]


## Every term, in reading order. A copy, so a caller that sorts or filters cannot edit the table.
static func terms() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in TERMS:
		out.append(entry.duplicate(true))
	return out


## One term by its key, or an empty Dictionary. The lookup behind "reference:glossary/<key>".
static func term(key: String) -> Dictionary:
	var wanted: String = key.strip_edges().to_lower()
	for entry: Dictionary in TERMS:
		if str(entry.get("key", "")) == wanted:
			return entry.duplicate(true)
	return {}


## The keys whose term or its own words mention `query`, best first: the word itself before the
## sentence it is explained in, so typing "pick" answers with Pick rather than with every entry
## that happens to say "picking".
static func find(query: String) -> Array[Dictionary]:
	var wanted: String = query.strip_edges().to_lower()
	if wanted.is_empty():
		return terms()
	var exact: Array[Dictionary] = []
	var partial: Array[Dictionary] = []
	for entry: Dictionary in TERMS:
		var term_text: String = str(entry.get("term", "")).to_lower()
		if term_text.begins_with(wanted):
			exact.append(entry.duplicate(true))
			continue
		if term_text.contains(wanted) or str(entry.get("here", "")).to_lower().contains(wanted):
			partial.append(entry.duplicate(true))
	exact.append_array(partial)
	return exact


## The whole glossary as page blocks, in the shape the page view draws: the title, a lead line,
## then one chapter per term. Pure, so the suite pins the page's structure without a window.
static func blocks() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": PAGE_TITLE, "bbcode": PAGE_TITLE,
			"slug": EventSheetDocMarkdown.slug(PAGE_TITLE)},
		{"kind": "paragraph", "bbcode":
			"Most of what you know comes across unchanged. These are the words that are spelled differently here, and the two or three that mean something slightly different."},
	]
	for entry: Dictionary in TERMS:
		var key: String = str(entry.get("key", ""))
		blocks.append({"kind": "heading", "level": 2, "text": str(entry.get("term", "")),
			"bbcode": str(entry.get("term", "")), "slug": key})
		blocks.append({"kind": "paragraph",
			"bbcode": EventSheetDocMarkdown.escape_brackets(str(entry.get("here", "")))})
		var note: String = str(entry.get("note", "")).strip_edges()
		if not note.is_empty():
			blocks.append({"kind": "quote", "bbcode": EventSheetDocMarkdown.escape_brackets(note)})
		var related: PackedStringArray = _related_terms(entry)
		if not related.is_empty():
			blocks.append({"kind": "paragraph",
				"bbcode": "[i]Related: %s[/i]" % " · ".join(related)})
	return blocks


## A term's related entries, spelled as the words rather than as their keys.
static func _related_terms(entry: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for key: Variant in (entry.get("related", []) as Array):
		var found: Dictionary = term(str(key))
		if not found.is_empty():
			names.append(str(found.get("term", "")))
	return names
