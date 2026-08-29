# Godot EventSheets - the manual your own game writes about itself.
#
# The reader already has a Manual for the plugin. This is the other one: a page per sheet saying what
# THAT sheet is, what it remembers, what it can be asked to do, what it announces and how its rules
# are grouped - in the words the sheet itself carries, never in words invented here.
#
# IT CANNOT GO STALE, because it is not a document. Nothing is stored: a page is composed from the
# sheet the moment somebody opens it, so a function renamed a minute ago is renamed on the page, and
# a page for a sheet that no longer exists cannot be left lying around. The old failure of project
# documentation - written once, wrong within a month - is not available here.
#
# EXPORTING IS A DIFF. The same page written to a file is byte-stable: the same sheet composes the
# same bytes on every machine and in every run, so a team can commit these pages and read what
# CHANGED about their game in a pull request. That rules out anything that varies - no timestamps, no
# absolute paths, no dictionary iteration order, no counts that depend on when the scan ran.
#
# THE FOOTER STATES COVERAGE AS A FACT. "41 of 52 described", with the list of the eleven, and no
# color, no bar and no grade. A game with eleven undescribed things works exactly as well as one with
# none; the number is there so a person can find the eleven, not so anybody is scored on them.
@tool
class_name EventSheetProjectManual
extends RefCounted

## The heading each section carries, keyed by the catalog kind it lists. Frozen with the page order:
## an export lands in version control, so a wording change would show up as a diff in every page.
const SECTION_TITLES := {
	"variable": "What it remembers",
	"function": "What it can be asked to do",
	"signal": "What it announces",
	"group": "How its rules are grouped",
}

## The order the sections appear in, which is the order a reader meets the sheet: its data, then the
## things that act on the data, then what it tells the rest of the game, then its chapters.
const SECTION_ORDER: PackedStringArray = ["variable", "function", "signal", "group"]

## How many undescribed names a footer spells out before it counts the rest.
const FOOTER_NAMED_LIMIT: int = 12

## How many hex characters disambiguate a sheet that lives in a folder. Six is 16 million: a project
## would need thousands of same-named sheets before two of them collided, and a longer tail buys
## nothing a reader can use.
const STEM_HASH_LENGTH: int = 6


## The name a sheet's page is filed under - its file name, plus a tail derived from where the file
## lives when it lives anywhere but the project root.
##
## THE FILE NAME ALONE IS NOT A NAME. `res://player/main.gd` and `res://enemy/main.gd` are two
## sheets, and keying their pages on "main" had the second silently overwrite the first: one page on
## disk, one entry in the search, and an exported site listing the id twice with one file behind it.
## The tail is a hash rather than the folder because a page id is published - it goes into an
## exported site that gets committed - and the id should say which sheet it is without publishing
## the shape of somebody's project.
##
## One definition, asked by the chore that writes every page, by the save that refreshes one, and by
## the site exporter, so the three cannot disagree about which page a sheet owns.
static func page_stem(sheet_path: String) -> String:
	var path: String = sheet_path.strip_edges().trim_suffix("/")
	var name: String = path.get_file()
	var stem: String = name.get_basename()
	if stem.is_empty():
		stem = name
	if stem.is_empty():
		return ""
	var folder: String = path.get_base_dir().trim_prefix("res://").trim_suffix("/")
	if folder.is_empty():
		return stem
	return "%s-%s" % [stem, _folder_tail(folder)]


## A folder path reduced to a short, stable, machine-independent tail. Deterministic by hand rather
## than through String.hash(), whose value is an engine implementation detail and could change an
## exported site's file names between Godot versions.
static func _folder_tail(folder: String) -> String:
	var accumulated: int = 2166136261
	for index: int in range(folder.length()):
		accumulated = (accumulated ^ folder.unicode_at(index)) & 0xFFFFFFFF
		accumulated = (accumulated * 16777619) & 0xFFFFFFFF
	var digits: String = "0123456789abcdef"
	var tail: String = ""
	for _step: int in range(STEM_HASH_LENGTH):
		tail = digits[accumulated & 0xF] + tail
		accumulated >>= 4
	return tail


## One sheet's page, as Markdown. Deterministic: the same sheet composes the same string every time,
## so the export can be committed and diffed.
static func page_for(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var entries: Array[Dictionary] = EventSheetDescriptions.catalog(sheet)
	var lines: PackedStringArray = PackedStringArray()
	var head: Dictionary = _head_entry(entries)
	lines.append("# %s" % str(head.get("name", "Sheet")))
	lines.append("")
	lines.append("*%s*" % str(head.get("detail", "")))
	lines.append("")
	lines.append(_described_line(head))
	lines.append_array(_prose_lines(sheet))
	for kind: String in SECTION_ORDER:
		var section: Array[Dictionary] = _entries_of_kind(entries, kind)
		if section.is_empty():
			continue
		lines.append("")
		lines.append("## %s" % str(SECTION_TITLES.get(kind, kind)))
		lines.append("")
		for entry: Dictionary in section:
			lines.append_array(_entry_lines(entry))
	lines.append("")
	lines.append_array(_footer_lines(sheet))
	return "\n".join(lines) + "\n"


## The pages for a whole set of sheets, keyed by the file name a reader would recognise. Sorted by
## that key, because a directory walk returns its own order (alphabetical on some filesystems, hash
## order on others) and an export that reordered itself between machines would diff for no reason.
static func pages_for(sheets: Dictionary) -> Dictionary:
	var pages: Dictionary = {}
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in sheets.keys():
		keys.append(str(key))
	keys.sort()
	for key: String in keys:
		var sheet: Variant = sheets.get(key)
		if sheet is EventSheetResource:
			pages[key] = page_for(sheet as EventSheetResource)
	return pages


## The sheet's own prose: its DOCUMENTATION comment rows, in sheet order, set as paragraphs between
## the head and the sections. This is the whole of "the book writes itself" - the words are already in
## the sheet, written where the person was looking, and the page just reads them in order.
##
## A private note is not here and cannot be made to appear here. A paragraph written inside a chapter
## carries that chapter's name in soft type, because a reader who meets a sentence about landing wants
## to know it was written under the group about landing.
static func _prose_lines(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for paragraph: Dictionary in EventSheetSheetProse.paragraphs(sheet):
		lines.append("")
		var where: String = str(paragraph.get("where", "")).strip_edges()
		if not where.is_empty():
			lines.append("*%s*" % where)
			lines.append("")
		lines.append(str(paragraph.get("text", "")))
	return lines


## The lines for one catalog entry: its name and detail as a heading line, its description or the
## nudge under it. Three lines, always, so the page's shape does not change with its content.
static func _entry_lines(entry: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var detail: String = str(entry.get("detail", "")).strip_edges()
	var heading: String = "### `%s`" % str(entry.get("name", ""))
	if not detail.is_empty():
		heading = "### `%s` - %s" % [str(entry.get("name", "")), detail]
	lines.append(heading)
	lines.append("")
	lines.append(_described_line(entry))
	lines.append("")
	return lines


## One entry's prose line: the words when it has them, and the nudge in italics when it does not, so a
## reader can see at a glance which lines are the sheet talking and which are a gap.
static func _described_line(entry: Dictionary) -> String:
	if bool(entry.get("described", false)):
		return str(entry.get("text", ""))
	return "*%s*" % EventSheetDescriptions.NO_DESCRIPTION_NUDGE


## The page footer: the coverage sentence, and then the undescribed things by name so the reader can
## go and write those lines. Lists them all when there are few and counts the tail when there are
## many, because a footer that ran to eighty names would be a page of its own.
static func _footer_lines(sheet: EventSheetResource) -> PackedStringArray:
	var numbers: Dictionary = EventSheetDescriptions.coverage(sheet)
	var undescribed: PackedStringArray = numbers.get("undescribed", PackedStringArray())
	var lines: PackedStringArray = PackedStringArray()
	lines.append("---")
	lines.append("")
	lines.append(EventSheetDescriptions.coverage_sentence(sheet) + ".")
	if undescribed.is_empty():
		return lines
	lines.append("")
	var named: PackedStringArray = PackedStringArray()
	for index: int in range(min(undescribed.size(), FOOTER_NAMED_LIMIT)):
		named.append("`%s`" % undescribed[index])
	var tail: int = undescribed.size() - named.size()
	var sentence: String = "Still to describe: %s" % ", ".join(named)
	if tail > 0:
		sentence += ", and %d more" % tail
	lines.append(sentence + ".")
	return lines


## The sheet's own head entry out of the catalog - the one entry of kind "sheet".
static func _head_entry(entries: Array[Dictionary]) -> Dictionary:
	for entry: Dictionary in entries:
		if str(entry.get("kind", "")) == "sheet":
			return entry
	return {"name": "Sheet", "detail": "", "described": false, "text": ""}


## Every catalog entry of one kind, in catalog order.
static func _entries_of_kind(entries: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if str(entry.get("kind", "")) == kind:
			found.append(entry)
	return found
