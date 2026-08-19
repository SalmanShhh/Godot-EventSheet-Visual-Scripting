# EventSheet - EventSheetDocReference: the Manual's REFERENCE half, one page per thing.
#
# A manual for an event sheet has two halves. The guides teach a task; the reference lists what a
# thing can do - its conditions, its actions, its expressions - and there is one page per thing:
# a page per builtin category (the System reference), a page per behavior pack (the behavior
# reference), and a page per object class the reader can select on the sheet.
#
# EVERY PAGE IS DERIVED. Nothing here is authored: the rows come from the vocabulary the editor has
# actually loaded, so a renamed verb renames on the page and a pack that ships tomorrow has a page
# tomorrow. That is also what makes the STUB honest - a pack with no written guide is not a dead
# link, it is this page with a line saying the guide is not written yet and a button that writes
# the skeleton.
#
# THE ID SCHEME (joins the frozen set in EventSheetDocExplain):
#   "reference:section/<Category>"  the System reference page for a picker category
#   "reference:pack/<pack dir>"     a behavior's reference
#   "reference:class/<ClassName>"   an object's reference
#   "reference:glossary"            the words another event-sheet editor spells differently
#   "reference:glossary/<term key>" the same page, at one term
#   "reference:legend"              what the marks on a sheet mean - the Manual's first page
#
# Everything is STATIC and PURE where it can be: the block assembly takes rows as an argument, so
# the page's shape is pinned by the suite while the live gathering (which needs a running editor)
# stays a thin layer on top.
@tool
class_name EventSheetDocReference
extends RefCounted

## The scheme, and the kinds after it. Frozen with the ids themselves.
const SCHEME := "reference:"
const KIND_SECTION := "section"
const KIND_PACK := "pack"
const KIND_CLASS := "class"
const KIND_GLOSSARY := "glossary"
const KIND_LEGEND := "legend"
const KIND_WHATS_NEW := "whatsnew"
const KIND_TUTORIALS := "tutorials"
const KIND_TUTORIAL := "tutorial"
const KIND_PATTERNS := "patterns"
const KIND_PATTERN := "pattern"
const KIND_DICTIONARY := "dictionary"

## The kinds a "reference:" id may name, so an unknown one fails loudly instead of drawing blank.
const KINDS: Array[String] = [KIND_SECTION, KIND_PACK, KIND_CLASS, KIND_GLOSSARY, KIND_LEGEND,
	KIND_WHATS_NEW, KIND_TUTORIALS, KIND_TUTORIAL, KIND_PATTERNS, KIND_PATTERN, KIND_DICTIONARY]

## What the reading surface is called, everywhere the reader can see it. An event sheet's
## documentation is its Manual, and every crumb trail starts here.
const MANUAL_TITLE := "Manual"

## The tree sections these pages hang under. The words are the Manual's own, and the search tags
## its results with them.
const SECTION_TREE_TITLE := "System reference"
const PACK_TREE_TITLE := "Behavior reference"
const CLASS_TREE_TITLE := "Object reference"

## The tree section the hands-on tutorials hang under.
const TUTORIALS_TREE_TITLE := "Tutorials"

## THE FIXED SHAPE of every reference page, and the whole point of it: Properties, then Conditions,
## Actions, Expressions, Triggers, in that order, on every object, module and behavior. A reader's
## eye learns where to land once and lands there on every page after it. Triggers is the fifth
## section because signals are what this sheet has more of than any other kind of verb.
const GROUP_ORDER: Array[String] = ["Properties", "Conditions", "Actions", "Expressions", "Triggers"]

## The group a page's PROPERTIES are filed under - the one section that is not a verb group, so
## every caller that walks GROUP_ORDER can still ask "is this the property table?".
const GROUP_PROPERTIES := "Properties"

## The mark each section's rows wear in the icon column. These are the sheet's own glyphs: a
## condition is a diamond, an action an arrow, an expression the function sign, a trigger the
## recurrence mark. A property is a value rather than something that happens, so it wears nothing.
const GROUP_MARKS := {
	"Properties": "",
	"Conditions": "◆",
	"Actions": "➜",
	"Expressions": "ƒ",
	"Triggers": "⟳",
}

## The marks a sheet draws, and what each one means. The legend page is built from this, and so is
## the hover help on the marks themselves - one table, so a mark can never mean two things.
const MARKS: Array[Dictionary] = [
	{"mark": "⟳", "name": "Runs every frame",
		"help": "This event is checked on every frame. A signal trigger reacts once instead, where there is one."},
	{"mark": "◆", "name": "Trigger",
		"help": "This event runs when something happens, not on a schedule."},
	{"mark": "➜", "name": "Calls a function",
		"help": "This row hands over to a function; the function's own events run there."},
	{"mark": "ƒ", "name": "Function",
		"help": "A named block of actions with typed parameters, called from any row."},
	{"mark": "✕", "name": "Inverted condition",
		"help": "The condition is true when the opposite is: read it as \"not\"."},
	{"mark": "⏸", "name": "Disabled",
		"help": "The row is kept in the sheet but compiles to nothing."},
]


## The doc id for a reference page. `name` is empty for the pages that have only one ("legend").
static func doc_id(kind: String, name: String = "") -> String:
	var wanted: String = kind.strip_edges()
	if wanted.is_empty():
		return ""
	var suffix: String = name.strip_edges()
	return "%s%s" % [SCHEME, wanted] if suffix.is_empty() else "%s%s/%s" % [SCHEME, wanted, suffix]


## A "reference:" id split into {kind, name}, or an empty Dictionary when it is not one (or names a
## kind this build does not know). The parse is deliberately not a get_slice: a class name never
## carries a slash but a category legitimately could, so everything after the FIRST one is the name.
static func parse(doc_id_text: String) -> Dictionary:
	var id: String = doc_id_text.strip_edges()
	if not id.begins_with(SCHEME):
		return {}
	var rest: String = id.substr(SCHEME.length())
	var separator: int = rest.find("/")
	var kind: String = rest if separator < 0 else rest.substr(0, separator)
	var name: String = "" if separator < 0 else rest.substr(separator + 1)
	if not KINDS.has(kind):
		return {}
	return {"kind": kind, "name": name}


## Whether an id names a page this build can actually draw. A section must be one the editor
## offers, a pack must exist on disk, and a class must be a class - a page that resolves to
# "nothing at all" has to fail at the caller rather than paint an empty reference.
static func has_page(doc_id_text: String) -> bool:
	var route: Dictionary = parse(doc_id_text)
	if route.is_empty():
		return false
	var name: String = str(route.get("name", ""))
	match str(route.get("kind", "")):
		KIND_LEGEND, KIND_WHATS_NEW, KIND_TUTORIALS, KIND_PATTERNS, KIND_DICTIONARY:
			return true
		KIND_PATTERN:
			return not EventSheetPatternVocabulary.fixture_source(name).is_empty()
		KIND_TUTORIAL:
			return not EventSheetDocTutorials.tutorial(name).is_empty()
		KIND_GLOSSARY:
			return name.is_empty() or not EventSheetDocGlossary.term(name).is_empty()
		KIND_PACK:
			return not name.is_empty() and DirAccess.dir_exists_absolute("res://eventsheet_addons".path_join(name))
		KIND_CLASS:
			return not name.is_empty()
		KIND_SECTION:
			return not name.is_empty()
	return false


## The page's own title, for a breadcrumb, a tree row and a window title.
static func title_for(kind: String, name: String) -> String:
	match kind:
		KIND_LEGEND:
			return "What the marks on a sheet mean"
		KIND_WHATS_NEW:
			return EventSheetDocWhatsNew.PAGE_TITLE
		KIND_DICTIONARY:
			return EventSheetDocDictionary.PAGE_TITLE
		KIND_TUTORIALS:
			return EventSheetDocTutorials.PAGE_TITLE
		KIND_PATTERNS:
			return EventSheetPatternManual.PAGE_TITLE
		KIND_PATTERN:
			return EventSheetPatternVocabulary.words(name)
		KIND_TUTORIAL:
			return str(EventSheetDocTutorials.tutorial(name).get("title", ""))
		KIND_GLOSSARY:
			return EventSheetDocGlossary.PAGE_TITLE
		KIND_PACK:
			return pack_title(name)
		KIND_CLASS:
			return name.strip_edges()
		KIND_SECTION:
			return name.strip_edges()
	return ""


## A pack directory as the Manual names it ("priced_table" -> "Priced Tables"). Derived from the
## guide name the whole plugin already agrees on, so the Manual and the picker call a pack the
## same thing.
static func pack_title(pack_dir: String) -> String:
	var guide: String = EventSheets.addon_guide_name(pack_dir)
	if guide.is_empty():
		return pack_dir.strip_edges()
	return guide.replace("-", " ")


## The guide page id a reference page can hand the reader on to, or "" when none ships. What the
## stub is decided by, and what "Open guide" opens.
static func guide_page_for(kind: String, name: String) -> String:
	match kind:
		KIND_PACK:
			# Resolved from the pack directory rather than through the "addon:" route, because the
			# router reads THIS file: asking it back would be a cycle between two classes.
			var directory: String = name.strip_edges()
			var bundled: String = EventSheetDocLibrary.id_for_repo_path(EventSheets.addon_guide_for_pack(directory))
			if EventSheetDocLibrary.has_page(bundled):
				return bundled
			return EventSheetDocLibrary.pack_page_id(directory)
		KIND_SECTION:
			var target: String = EventSheets.module_guide_target(name)
			var derived: String = EventSheetDocLibrary.id_for_repo_path(target)
			return derived if EventSheetDocLibrary.has_page(derived) else ""
	return ""


## Where the reader is, as crumbs starting at "Manual". Pure over the id and the title already on
## screen, so the trail is pinned by the suite and can never say a different thing from the page.
##
## The middle crumb is the PART of the Manual the page belongs to - the words its tree uses - which
## is the whole job of a breadcrumb here: not a file path, but "you are in the System reference".
static func breadcrumb(doc_id_text: String, title: String) -> PackedStringArray:
	var crumbs: PackedStringArray = PackedStringArray([MANUAL_TITLE])
	var id: String = doc_id_text.strip_edges()
	var page_title: String = title.strip_edges()
	var route: Dictionary = parse(id)
	if not route.is_empty():
		match str(route.get("kind", "")):
			KIND_SECTION:
				crumbs.append(SECTION_TREE_TITLE)
			KIND_PACK:
				crumbs.append(PACK_TREE_TITLE)
			KIND_CLASS:
				crumbs.append(CLASS_TREE_TITLE)
			KIND_GLOSSARY:
				crumbs.append(EventSheetDocGlossary.PAGE_TITLE)
			KIND_LEGEND:
				crumbs.append(title_for(KIND_LEGEND, ""))
			KIND_WHATS_NEW:
				crumbs.append(EventSheetDocWhatsNew.PAGE_TITLE)
			KIND_TUTORIALS, KIND_TUTORIAL:
				crumbs.append(TUTORIALS_TREE_TITLE)
			KIND_PATTERNS, KIND_PATTERN:
				crumbs.append(EventSheetPatternManual.PAGE_TITLE)
			KIND_DICTIONARY:
				crumbs.append(EventSheetDocDictionary.PAGE_TITLE)
	elif id.begins_with("ace:"):
		crumbs.append(SECTION_TREE_TITLE if EventSheets.addon_pack_directory(
			id.substr(4).get_slice("/", 0)).is_empty() else PACK_TREE_TITLE)
	elif id.begins_with("guide:"):
		var group: String = group_title_for_page(id.substr("guide:".length()))
		if not group.is_empty():
			crumbs.append(group)
	if not page_title.is_empty() and (crumbs.size() < 2 or crumbs[crumbs.size() - 1] != page_title):
		crumbs.append(page_title)
	return crumbs


## The tree group a shipped page sits in ("Getting started"), or "" for a page no group lists.
static func group_title_for_page(page_id: String) -> String:
	var wanted: String = page_id.strip_edges()
	for group: Dictionary in EventSheetDocLibrary.groups():
		for id: String in (group.get("ids", PackedStringArray()) as PackedStringArray):
			if id == wanted:
				return str(group.get("title", ""))
	return ""


## The page that follows `page_id` inside its own group, as {doc_id, title}, or an empty Dictionary
## for the last page of a group. What "Next: ..." at the foot of a guide is built from.
static func next_page_after(page_id: String) -> Dictionary:
	var wanted: String = page_id.strip_edges()
	for group: Dictionary in EventSheetDocLibrary.groups():
		var ids: PackedStringArray = group.get("ids", PackedStringArray())
		var index: int = Array(ids).find(wanted)
		if index < 0 or index + 1 >= ids.size():
			continue
		var next_id: String = ids[index + 1]
		return {"doc_id": "guide:%s" % next_id, "title": EventSheetDocLibrary.page_title(next_id)}
	return {}


# ── The rows a page lists ─────────────────────────────────────────────────────────────────────


## Every verb the live vocabulary files under a picker category. Empty outside the editor (there is
## no registry there), which is what makes the page say "no verbs to list" instead of inventing any.
static func definitions_in_section(section_name: String) -> Array[ACEDefinition]:
	var wanted: String = section_name.strip_edges()
	var found: Array[ACEDefinition] = []
	if wanted.is_empty():
		return found
	for definition: ACEDefinition in EventSheets.all_verbs():
		if category_of(definition) == wanted:
			found.append(definition)
	return found


## Every category the live vocabulary offers, sorted - the System reference's own tree.
static func section_names() -> PackedStringArray:
	var seen: Dictionary = {}
	for definition: ACEDefinition in EventSheets.all_verbs():
		# A pack's verbs are the BEHAVIOR reference's business; the System reference is the
		# vocabulary that ships with the plugin, which is what its name promises.
		if not EventSheets.addon_pack_directory(definition.provider_id).is_empty():
			continue
		seen[category_of(definition)] = true
	var names: PackedStringArray = PackedStringArray()
	for name: Variant in seen:
		names.append(str(name))
	names.sort()
	return names


## Every pack directory that publishes vocabulary, sorted - the behavior reference's own tree.
## Read from disk rather than from the registry, so a pack with no verbs loaded yet still has a
## page (which is where its stub lives).
static func pack_names() -> PackedStringArray:
	var root: String = "res://eventsheet_addons"
	if not DirAccess.dir_exists_absolute(root):
		return PackedStringArray()
	var names: PackedStringArray = DirAccess.get_directories_at(root)
	names.sort()
	return names


## A verb list as the {name, params, note} rows every reference table draws, grouped by kind.
## Pure over the definitions it is handed, so the grouping is pinned without a registry.
static func rows_from_definitions(definitions: Array[ACEDefinition]) -> Dictionary:
	var grouped: Dictionary = {}
	for definition: ACEDefinition in definitions:
		if definition == null:
			continue
		var group: String = group_of(definition.ace_type)
		if not grouped.has(group):
			grouped[group] = []
		(grouped[group] as Array).append({
			"name": EventSheetL10n.translate(definition.display_name),
			"params": EventSheetDocAceReference.definition_params(definition),
			"note": EventSheetL10n.translate(str(definition.description).strip_edges()),
			"doc_id": "" if definition.id.strip_edges().is_empty() else "ace:%s/%s" % [definition.provider_id, definition.id],
		})
	for group: String in GROUP_ORDER:
		if grouped.has(group):
			(grouped[group] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("name", "")) < str(b.get("name", "")))
	return grouped


## The picker category a verb files under, with the picker's own "General" fallback. Spelled out
## here rather than asked of the router, which reads this file - two classes that name each other
## are a cycle the parser cannot resolve.
static func category_of(definition: ACEDefinition) -> String:
	if definition == null:
		return "General"
	var category: String = definition.category.strip_edges()
	return category if not category.is_empty() else "General"


## Which table a verb's type belongs in.
static func group_of(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "Conditions"
		ACEDefinition.ACEType.EXPRESSION:
			return "Expressions"
		ACEDefinition.ACEType.TRIGGER:
			return "Triggers"
	return "Actions"


# ── The page ──────────────────────────────────────────────────────────────────────────────────


## A reference page, ready for the page view. Empty for an id this build cannot draw, so the
## caller reports the miss rather than showing a page with a title and nothing under it.
static func blocks_for(kind: String, name: String) -> Array[Dictionary]:
	match kind:
		KIND_LEGEND:
			return legend_blocks()
		KIND_WHATS_NEW:
			return EventSheetDocWhatsNew.blocks()
		KIND_DICTIONARY:
			return EventSheetDocDictionary.blocks()
		KIND_TUTORIALS:
			return EventSheetDocTutorials.list_blocks()
		KIND_PATTERNS:
			return EventSheetPatternManual.blocks()
		KIND_PATTERN:
			return EventSheetPatternManual.pattern_blocks(name)
		KIND_TUTORIAL:
			return EventSheetDocTutorials.step_blocks(name)
		KIND_GLOSSARY:
			return EventSheetDocGlossary.blocks()
		KIND_PACK:
			return _pack_blocks(name)
		KIND_CLASS:
			return _rows_page(title_for(KIND_CLASS, name),
				"Everything this sheet can ask of a %s, drawn from the vocabulary this editor has loaded." % name.strip_edges(),
				rows_from_definitions(EventSheets.class_vocabulary(name.strip_edges())), "")
		KIND_SECTION:
			return _rows_page(title_for(KIND_SECTION, name), _section_lead(name),
				rows_from_definitions(definitions_in_section(name)), guide_page_for(KIND_SECTION, name))
	return []


## The lead line of a System reference page: the category's own blurb when it has one, and an
## honest sentence when it does not.
static func _section_lead(section_name: String) -> String:
	var blurb: String = EventSheetSectionInfo.description_for(section_name.strip_edges())
	if not blurb.is_empty():
		return EventSheetL10n.translate(blurb)
	return "The conditions, actions and expressions this editor files under %s." % section_name.strip_edges()


## A behavior's reference. The one page that can be a STUB: when the pack ships no written guide,
## the page says so in a sentence and offers to write the skeleton, and lists the vocabulary under
## it either way - which is the half of a guide the reader came for.
static func _pack_blocks(pack_dir: String) -> Array[Dictionary]:
	var directory: String = pack_dir.strip_edges()
	# A directory that is not installed draws NOTHING, not a stub: a stub says "this behavior has
	# no guide yet", and a behavior that is not here has no guide to be missing.
	if directory.is_empty() or not DirAccess.dir_exists_absolute("res://eventsheet_addons".path_join(directory)):
		return []
	var grouped: Dictionary = EventSheetDocAceReference.verb_rows(directory)
	# The fixed shape opens with what the behavior IS before what it does: its designer knobs, read
	# off the pack's own scripts so a knob renamed in the pack renames on the page.
	var knobs: Array = EventSheetDocAceReference.property_rows(directory)
	if not knobs.is_empty():
		grouped[GROUP_PROPERTIES] = knobs
	var guide_page: String = guide_page_for(KIND_PACK, directory)
	var title: String = pack_title(directory)
	var lead: String = "The conditions, actions and expressions %s publishes." % title
	var blocks: Array[Dictionary] = _rows_page(title, lead, grouped, guide_page)
	if guide_page.is_empty():
		# The stub, and it goes ABOVE the tables: the reader's first question is "why is there no
		# guide", and answering it under three tables is answering it too late.
		blocks.insert(2, {"kind": "quote", "bbcode":
			"No guide yet for [b]%s[/b] - its conditions, actions and expressions are listed below." % title})
		blocks.insert(3, {"kind": "button", "label": "Write this guide",
			"tooltip": "Writes the guide skeleton for this behavior from its own vocabulary, ready to fill in.",
			"action": "write_guide", "argument": directory})
	return blocks


## The shared shape of every reference page: a title, a lead line, one table per group, and a way
## on to the written guide when there is one. Pure over the rows it is handed.
static func _rows_page(title: String, lead: String, grouped: Dictionary, guide_page: String) -> Array[Dictionary]:
	if title.strip_edges().is_empty():
		return []
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": title, "bbcode": title,
			"slug": EventSheetDocMarkdown.slug(title)},
		{"kind": "paragraph", "bbcode": EventSheetDocMarkdown.escape_brackets(lead)},
	]
	if not guide_page.is_empty():
		blocks.append({"kind": "paragraph", "bbcode": "[url=guide:%s]Open the guide[/url]" % guide_page})
	var total: int = 0
	for group: String in GROUP_ORDER:
		var rows: Array = grouped.get(group, []) as Array
		total += rows.size()
		if rows.is_empty():
			continue
		blocks.append({"kind": "heading", "level": 2, "text": group, "bbcode": group,
			"slug": EventSheetDocMarkdown.slug(group)})
		var columns: PackedStringArray = table_columns(grouped, group)
		blocks.append({"kind": "table", "headers": Array(columns),
			"rows": table_rows(rows, columns.size() > 3, str(GROUP_MARKS.get(group, "")))})
	if total == 0:
		blocks.append({"kind": "paragraph", "bbcode":
			"[i]No conditions, actions or expressions are loaded for this yet.[/i]"})
	return blocks


## The columns a page's tables draw: the row's own mark, what it is called, what it takes, and one
## line about it. "What it does" only when at least one row ON THE PAGE has something to say there -
## a column of blank cells reads as a broken table, not as an honest one - and the decision is made
## once for the whole page so the tables stay the same shape down it.
##
## The PROPERTY table names its two middle columns differently, because a knob has a default rather
## than parameters and calling it "Parameters" would be a table lying about its own contents.
static func table_columns(grouped: Dictionary, group: String = "") -> PackedStringArray:
	var noted: bool = false
	for name: String in GROUP_ORDER:
		for entry: Variant in (grouped.get(name, []) as Array):
			if not str((entry as Dictionary).get("note", "")).strip_edges().is_empty():
				noted = true
	if group == GROUP_PROPERTIES:
		return PackedStringArray(["Mark", "Property", "Default", "What it does"]) if noted \
			else PackedStringArray(["Mark", "Property", "Default"])
	return PackedStringArray(["Mark", "Name", "Parameters", "What it does"]) if noted \
		else PackedStringArray(["Mark", "Name", "Parameters"])


## One group's rows as table cells, led by the group's own mark. A row that knows its own doc id
## links to its entry, so a reference page is a way IN to the entries rather than a list that ends
## at itself.
static func table_rows(rows: Array, with_note: bool, mark: String = "") -> Array:
	var out: Array = []
	for entry: Variant in rows:
		var row: Dictionary = entry as Dictionary
		var name: String = EventSheetDocMarkdown.escape_brackets(str(row.get("name", "")))
		var doc: String = str(row.get("doc_id", "")).strip_edges()
		var cells: Array = [
			mark,
			"[url=%s]%s[/url]" % [doc, name] if not doc.is_empty() else "[code]%s[/code]" % name,
			EventSheetDocMarkdown.escape_brackets(str(row.get("params", ""))),
		]
		if with_note:
			cells.append(EventSheetDocMarkdown.escape_brackets(str(row.get("note", ""))))
		out.append(cells)
	return out


## The icon legend - the Manual's first page, and the source of the hover help on the marks
## themselves.
static func legend_blocks() -> Array[Dictionary]:
	var title: String = title_for(KIND_LEGEND, "")
	var rows: Array = []
	for entry: Dictionary in MARKS:
		rows.append([str(entry.get("mark", "")), str(entry.get("name", "")),
			EventSheetDocMarkdown.escape_brackets(str(entry.get("help", "")))])
	return [
		{"kind": "heading", "level": 1, "text": title, "bbcode": title,
			"slug": EventSheetDocMarkdown.slug(title)},
		{"kind": "paragraph", "bbcode":
			"A sheet marks the rows that behave differently. Hovering a mark on the sheet says the same thing this table does."},
		{"kind": "table", "headers": ["Mark", "What it is", "What it means"], "rows": rows},
	]


## What one mark means, for the hover help the sheet itself shows. "" for a glyph this table does
## not carry, so a caller shows no tooltip rather than an empty one.
static func mark_help(mark: String) -> String:
	var wanted: String = mark.strip_edges()
	for entry: Dictionary in MARKS:
		if str(entry.get("mark", "")) == wanted:
			return "%s - %s" % [str(entry.get("name", "")), str(entry.get("help", ""))]
	return ""
