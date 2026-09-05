# EventSheet - EventSheetDocAceReference: a pack guide's verb tables, drawn from the vocabulary
# the editor actually loaded rather than from the Markdown somebody typed.
#
# Seventy of the seventy-two addon guides carry a "## ACE reference" section, and every one of
# them is a hand-written copy of something the editor already knows. A copy of a list of verbs is
# a list that goes stale: a verb renamed through `@ace_name`, a method added to a pack, a whole
# family of reflected verbs the author never listed - none of it reaches the guide, and nothing
# fails when it does not.
#
# So the reader never sees that section's Markdown. When a guide belongs to a pack, the section is
# REPLACED at render time with tables built from the live registry, which cannot disagree with the
# picker because it is the picker's own data. The Markdown stays in the file (it is what GitHub
# shows, and what the build step diffs against), but in the editor it is decoration.
#
# TWO DERIVATIONS, ONE ROW SHAPE. Inside a running editor the registry answers, and it includes
# every reflected verb an annotation-only reading would miss. Headless - the suite, the build
# tool - there is no registry, so the SCRIPT-LEVEL derivation the guide scaffolder already
# performs answers instead. Both produce {name, params, note}, and the scaffolder's half is
# literally its own function, so there is no second implementation to drift.
@tool
class_name EventSheetDocAceReference
extends RefCounted

## The heading this replaces, and the slug it resolves to. Frozen in the sense that matters: it is
## the heading 70 shipped guides already use, so changing it here silently stops replacing them.
const SECTION_TITLE := "ACE reference"
const SECTION_SLUG := "ace-reference"

## Where packs live, and the two page-id prefixes a pack guide can arrive under: the bundled
## docs/Addons copy, and a pack's own discovered guide.md.
const PACKS_ROOT := "res://eventsheet_addons"

## The groups, in the order the guides already print them, keyed by ACEDefinition.ACEType.
const GROUP_ORDER := ["Actions", "Conditions", "Expressions", "Triggers"]

## The first header cell of a table that lists rows the picker offers. The corpus writes these
## tables five ways ("| Name |", "| Verb |", "| Action |", "| Condition |", "| Expression |"), and
## the same section also carries an Inspector-properties table - so the head is what tells the
## advisory diff which lines are picker rows and which are knobs. "Name" is the head the derived
## tables draw themselves, so it must be readable back or the diff sees an empty section; "Verb" is
## the head the older shipped guides were written with and stays readable forever.
const VERB_TABLE_HEADS := ["name", "verb", "action", "condition", "expression", "trigger"]

## The OTHER shape the corpus writes a verb table in: one table for the whole pack, with the kind
## in the first column and the name in the second ("| Kind | Name | Parameters | Description |").
## Six shipped guides use it, and a reader that only knew the first shape both kept their stale
## table on screen and reported every verb in it as undocumented.
const KIND_TABLE_HEAD := "kind"
const KIND_TABLE_NAME_HEADS := ["name", "verb"]

## page id -> the pack directories it documents, resolved once per session. The lookup walks the
## pack directories and asks each one what guide NAME it derives to, so the mapping is derived
## rather than a table.
static var _packs_by_page: Dictionary = {}
static var _pack_map_built: bool = false

## page id -> the verbs its packs publish, held for the session. Deriving them is cheap in a running
## editor (the registry already holds them) and expensive outside one, where every pack script has to
## be read and its members reflected - and the callers ask the same page the same question more than
## once: the page view draws the tables, the coverage audit diffs them, and the audit's own
## suggestions rank against them. Dropped by `reload`, which is also what a gained or lost pack
## drops the page map with, so the two can never disagree about what a page is about.
static var _verbs_by_page: Dictionary = {}


## The packs a page documents, sorted. Usually one - but a guide legitimately covers SEVERAL pack
## directories (the Quest guide documents both the quest behaviour and its resource), and a
## reference built from only one of them would silently drop half the vocabulary the page is
## about. That is why this returns a list and not a name.
##   "Packs/my_pack"   -> ["my_pack"]           (a pack's own discovered guide.md)
##   "Addons/Quest"    -> ["quest", "quest_resource"]
static func packs_for_page(page_id: String) -> PackedStringArray:
	var id: String = page_id.strip_edges()
	if id.begins_with("%s/" % EventSheetDocLibrary.PACKS_SET):
		return PackedStringArray([id.substr(EventSheetDocLibrary.PACKS_SET.length() + 1)])
	if not id.begins_with("%s/" % EventSheetDocLibrary.ADDONS_DIR):
		return PackedStringArray()
	_ensure_pack_map()
	return _packs_by_page.get(id, PackedStringArray())


## Drops the page -> pack mapping, for a session that gained or lost a pack.
static func reload() -> void:
	_pack_map_built = false
	_packs_by_page = {}
	_verbs_by_page = {}


static func _ensure_pack_map() -> void:
	if _pack_map_built:
		return
	_pack_map_built = true
	if not DirAccess.dir_exists_absolute(PACKS_ROOT):
		return
	var pack_dirs: PackedStringArray = DirAccess.get_directories_at(PACKS_ROOT)
	pack_dirs.sort()
	for pack_dir: String in pack_dirs:
		var guide_name: String = EventSheets.addon_guide_name(pack_dir)
		if guide_name.is_empty():
			continue
		var page_id: String = "%s/%s" % [EventSheetDocLibrary.ADDONS_DIR, guide_name]
		var packs: PackedStringArray = _packs_by_page.get(page_id, PackedStringArray())
		packs.append(pack_dir)
		_packs_by_page[page_id] = packs


## Every verb a pack publishes, grouped: {"Actions": [{name, params, note}], ...}. Empty groups are
## kept out, so a pack with no conditions shows no Conditions table.
static func verb_rows(pack_dir: String) -> Dictionary:
	var grouped: Dictionary = _rows_from_registry(pack_dir)
	if grouped.is_empty():
		grouped = _rows_from_scripts(pack_dir)
	for group: String in GROUP_ORDER:
		if grouped.has(group):
			(grouped[group] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("name", "")) < str(b.get("name", "")))
	return grouped


## A pack's designer knobs, as the {name, params, note} rows every reference table draws: the
## exported properties of its scripts, with the DEFAULT in the params column (a knob has a default
## where a verb has parameters, and that is the fact a reader wants beside its name).
##
## Read off the scripts rather than off an instance: instance reflection is dead in the editor for
## a non-@tool script, so a pack's knobs would silently be an empty table for most of the corpus.
## Sorted by name, and de-duplicated across a pack's scripts so a knob declared on a base class and
## its subclass is one row.
static func property_rows(pack_dir: String) -> Array:
	var directory: String = PACKS_ROOT.path_join(pack_dir.strip_edges())
	if not DirAccess.dir_exists_absolute(directory):
		return []
	var seen: Dictionary = {}
	var file_names: PackedStringArray = DirAccess.get_files_at(directory)
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != "gd":
			continue
		var path: String = directory.path_join(file_name)
		var script: Script = load(path) as Script if ResourceLoader.exists(path) else null
		if script == null:
			continue
		for property_info: Dictionary in script.get_script_property_list():
			var usage: int = int(property_info.get("usage", 0))
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_EDITOR == 0:
				continue
			var property_name: String = str(property_info.get("name", ""))
			if property_name.is_empty() or property_name.begins_with("_") or seen.has(property_name):
				continue
			# The name in the sheet's own spelling ("max_hp" -> "max hp"), which is how the Object
			# properties panel and the rows already say it. The note is deliberately left empty: a
			# knob's type is already visible in its default, and a made-up sentence in the "what it
			# does" column would be the page inventing documentation nobody wrote.
			seen[property_name] = {
				"name": property_name.capitalize().to_lower(),
				"params": str(script.get_property_default_value(property_name)),
				"note": "",
			}
	var names: PackedStringArray = PackedStringArray()
	for name: Variant in seen:
		names.append(str(name))
	names.sort()
	var rows: Array = []
	for name: String in names:
		rows.append(seen[name])
	return rows


## The live half: what the running editor's registry offers for this pack's providers. Empty
## outside the editor, which is what hands the question to the script-level half.
static func _rows_from_registry(pack_dir: String) -> Dictionary:
	var grouped: Dictionary = {}
	for provider_id: String in EventSheets.pack_providers(pack_dir):
		for definition: ACEDefinition in EventSheets.provider_verbs(provider_id):
			var group: String = _group_of(definition.ace_type)
			if not grouped.has(group):
				grouped[group] = []
			(grouped[group] as Array).append({
				"name": EventSheetL10n.translate(definition.display_name),
				"params": definition_params(definition),
				"note": EventSheetL10n.translate(str(definition.description).strip_edges()),
			})
	return grouped


## The script-level half, reusing the guide scaffolder's own derivation so the live table and the
## generated guide can never describe the pack differently.
static func _rows_from_scripts(pack_dir: String) -> Dictionary:
	var grouped: Dictionary = {}
	var directory: String = PACKS_ROOT.path_join(pack_dir.strip_edges())
	if not DirAccess.dir_exists_absolute(directory):
		return grouped
	var file_names: PackedStringArray = DirAccess.get_files_at(directory)
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != "gd":
			continue
		var members: Dictionary = EventSheetAddonGuideScaffold.member_rows(directory.path_join(file_name))
		for group: String in GROUP_ORDER:
			for entry: Variant in (members.get(group.to_lower(), []) as Array):
				if not grouped.has(group):
					grouped[group] = []
				(grouped[group] as Array).append({
					"name": str((entry as Dictionary).get("name", "")),
					"params": str((entry as Dictionary).get("params", "")),
					"note": "",
				})
	return grouped


## The parsed page with its ACE reference section swapped for the derived one. Unchanged when the
## page has no such section, when it documents no pack, and when the derivation found no verbs - a
## blank section where a written one used to be is strictly worse than a stale one.
static func replace_section(blocks: Array[Dictionary], page_id: String) -> Array[Dictionary]:
	var start: int = _section_start(blocks)
	if start < 0:
		return blocks
	var derived: Array[Dictionary] = blocks_for_page(page_id)
	if derived.is_empty():
		return blocks
	var end: int = _section_end(blocks, start)
	# Only the VERB tables are the vocabulary's to draw. Everything else the section carries - the
	# styled-sentence bullets that open it, the "### Inspector properties" table that closes it,
	# any prose the author wrote under the heading - is knowledge the registry does not hold, and
	# replacing it would delete documentation to fix a table. The kept blocks stay on the side of
	# the tables they were written on, so the section still reads in the order it was written.
	var kept: Dictionary = _kept_section_blocks(blocks, start, end)
	var out: Array[Dictionary] = []
	out.append_array(blocks.slice(0, start))
	out.append(derived[0])
	out.append_array(kept.get("before", []) as Array[Dictionary])
	out.append_array(derived.slice(1))
	out.append_array(kept.get("after", []) as Array[Dictionary])
	out.append_array(blocks.slice(end))
	return out


## The parts of a guide's ACE reference section that survive the swap, split by where they sat:
## {before, after} the first thing the live tables replace. Two things are replaced, and a guide
## that carries only the second is why:
##   - a "### Actions" / "Conditions" / "Expressions" / "Triggers" subsection and everything under
##     it, which is how most guides lay the reference out;
##   - a VERB TABLE anywhere in the section, which is how the rest lay it out - one table for the
##     whole pack under the bare heading, with no subsection to recognise. Keeping that table
##     printed the pack's verbs TWICE: once from the Markdown the reader is not supposed to see,
##     once from the registry.
## Everything else - the styled-sentence bullets, the "### Inspector properties" table, any prose -
## is knowledge the registry does not hold and is kept exactly where it was written.
static func _kept_section_blocks(blocks: Array[Dictionary], start: int, end: int) -> Dictionary:
	var before: Array[Dictionary] = []
	var after: Array[Dictionary] = []
	var dropping: bool = false
	var seen_group: bool = false
	for index: int in range(start + 1, end):
		var block: Dictionary = blocks[index]
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) >= 3:
			dropping = GROUP_ORDER.has(str(block.get("text", "")).strip_edges())
			seen_group = seen_group or dropping
		var is_verb_table: bool = str(block.get("kind", "")) == "table" \
			and verb_name_column(block.get("headers", []) as Array) >= 0
		if dropping or is_verb_table:
			seen_group = seen_group or is_verb_table
			continue
		if seen_group:
			after.append(block)
		else:
			before.append(block)
	return {"before": before, "after": after}


## Every verb of every pack a page documents, merged and de-duplicated by name within a group. Held
## for the session: outside a running editor this reads and reflects every script of every pack the
## page is about, and three separate readers ask it the same question about the same page.
static func verb_rows_for_page(page_id: String) -> Dictionary:
	if _verbs_by_page.has(page_id):
		return _verbs_by_page[page_id]
	var merged: Dictionary = {}
	var seen: Dictionary = {}
	for pack_dir: String in packs_for_page(page_id):
		var grouped: Dictionary = verb_rows(pack_dir)
		for group: String in GROUP_ORDER:
			for entry: Variant in (grouped.get(group, []) as Array):
				var key: String = "%s|%s" % [group, str((entry as Dictionary).get("name", ""))]
				if seen.has(key):
					continue
				seen[key] = true
				if not merged.has(group):
					merged[group] = []
				(merged[group] as Array).append(entry)
	_verbs_by_page[page_id] = merged
	return merged


## The columns the derived tables draw. Verb and Parameters always; "What it does" only when at
## least one verb ON THE PAGE declares a note - a reflected pack whose methods carry no doc comment
## would otherwise ship three tables with a blank third column, which reads as a broken table rather
## than as an honest one. Decided once for the WHOLE page rather than per group, so the Actions,
## Conditions and Expressions tables stay the same shape as each other down the page.
##
## Pure over the grouped rows, so which columns a real pack draws is pinned by a test.
static func reference_columns(grouped: Dictionary) -> PackedStringArray:
	for group: String in GROUP_ORDER:
		for entry: Variant in (grouped.get(group, []) as Array):
			if not str((entry as Dictionary).get("note", "")).strip_edges().is_empty():
				return PackedStringArray(["Name", "Parameters", "What it does"])
	return PackedStringArray(["Name", "Parameters"])


## The section as page blocks: the heading the guide already had (so its anchor still resolves),
## a line saying where the tables come from, and one table per group.
static func blocks_for_page(page_id: String) -> Array[Dictionary]:
	var grouped: Dictionary = verb_rows_for_page(page_id)
	var blocks: Array[Dictionary] = []
	var total: int = 0
	for group: String in GROUP_ORDER:
		total += (grouped.get(group, []) as Array).size()
	if total == 0:
		return blocks
	var headers: PackedStringArray = reference_columns(grouped)
	blocks.append({"kind": "heading", "level": 2, "text": SECTION_TITLE,
		"bbcode": SECTION_TITLE, "slug": SECTION_SLUG})
	blocks.append({"kind": "paragraph", "bbcode":
		"[i]Read live from the vocabulary this editor has loaded, so it always matches the picker.[/i]"})
	for group: String in GROUP_ORDER:
		var rows: Array = grouped.get(group, []) as Array
		if rows.is_empty():
			continue
		blocks.append({"kind": "heading", "level": 3, "text": group,
			"bbcode": group, "slug": EventSheetDocMarkdown.slug(group)})
		var table_rows: Array = []
		for entry: Variant in rows:
			var row: Dictionary = entry as Dictionary
			var cells: Array = [
				"[code]%s[/code]" % EventSheetDocMarkdown.escape_brackets(str(row.get("name", ""))),
				EventSheetDocMarkdown.escape_brackets(str(row.get("params", ""))),
			]
			if headers.size() > 2:
				cells.append(EventSheetDocMarkdown.escape_brackets(str(row.get("note", ""))))
			table_rows.append(cells)
		blocks.append({"kind": "table", "headers": Array(headers), "rows": table_rows})
	return blocks


## The verb names the guide's OWN Markdown lists in its ACE reference tables. The build step's
## advisory diff compares these against the derived ones; nothing else reads them.
static func markdown_verbs(blocks: Array[Dictionary]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var start: int = _section_start(blocks)
	if start < 0:
		return names
	var end: int = _section_end(blocks, start)
	for index: int in range(start, end):
		var block: Dictionary = blocks[index]
		if str(block.get("kind", "")) != "table":
			continue
		# Verb tables only. The same section carries an Inspector-properties table, and counting
		# its rows as verbs would report every knob a pack exports as a name no verb answers to.
		var column: int = verb_name_column(block.get("headers", []) as Array)
		if column < 0:
			continue
		for entry: Variant in (block.get("rows", []) as Array):
			var cells: Array = entry as Array
			if cells.size() <= column:
				continue
			var name: String = _bare_name(str(cells[column]))
			if not name.is_empty() and not names.has(name):
				names.append(name)
	return names


## Which column of a table holds the verb NAME, or -1 when the table is not a verb table at all.
## One answer, used by both readers of these tables - the swap that drops them from the page and
## the advisory diff that compares them - so a table can never be stale on screen and invisible to
## the report at the same time.
static func verb_name_column(headers: Array) -> int:
	if headers.is_empty():
		return -1
	var first: String = _bare_name(str(headers[0])).to_lower()
	if VERB_TABLE_HEADS.has(first):
		return 0
	if first == KIND_TABLE_HEAD and headers.size() > 1 and KIND_TABLE_NAME_HEADS.has(_bare_name(str(headers[1])).to_lower()):
		return 1
	return -1


## What the guide and the vocabulary disagree about, as {packs, missing, extra}:
##   missing - verbs the pack publishes that its guide never lists
##   extra   - names the guide lists that no verb answers to any more
## ADVISORY, never a gate: a guide legitimately lists a verb under a friendlier name, and a pack
## legitimately publishes plumbing its guide does not document.
static func diff_for_page(page_id: String, blocks: Array[Dictionary]) -> Dictionary:
	var packs: PackedStringArray = packs_for_page(page_id)
	var diff: Dictionary = {"packs": packs, "missing": PackedStringArray(), "extra": PackedStringArray()}
	if packs.is_empty():
		return diff
	var written: PackedStringArray = markdown_verbs(blocks)
	var derived: PackedStringArray = PackedStringArray()
	var grouped: Dictionary = verb_rows_for_page(page_id)
	for group: String in GROUP_ORDER:
		for entry: Variant in (grouped.get(group, []) as Array):
			var name: String = str((entry as Dictionary).get("name", ""))
			if not name.is_empty() and not derived.has(name):
				derived.append(name)
	# Built as locals and assigned back at the end: a PackedStringArray read out of a Dictionary is
	# a COPY, so appending to `diff["missing"]` in place would report an empty diff forever.
	var missing: PackedStringArray = PackedStringArray()
	var extra: PackedStringArray = PackedStringArray()
	for name: String in derived:
		if not names_match(written, name):
			missing.append(name)
	for name: String in written:
		if not names_match(derived, name):
			extra.append(name)
	diff["missing"] = missing
	diff["extra"] = extra
	return diff


## Verb names are compared loosely on purpose: a guide writes the method (`advance_objective`)
## where the registry publishes the display name ("Advance Objective"), and reporting every one of
## those as a difference would bury the real ones.
##
## A TRIGGER IS WRITTEN TWO WAYS AND IS ONE VERB. The vocabulary derives a trigger from the signal
## it listens for - `anchored`, `bound_hit` - and every guide in the corpus writes the row the way
## the sheet reads it, "On Anchored", "On Hit Bound". Comparing those literally reported the same
## trigger twice on every page that has one: once as a verb the guide never lists and once as a name
## no verb answers to. So the leading "on" is optional on either side of the comparison.
##
## AND SO IS THE ARTICLE AFTER IT. A trigger reads out as a sentence, and a sentence takes an
## article: the vocabulary derives `file_appeared` and every guide writes the row the way the sheet
## says it, "On A File Appeared". Dropping only the "on" left "afileappeared" against
## "fileappeared", so the two never met - and because a trigger's own name is what the reader looks
## it up by, one unread article was enough to report a verb as missing from the very page that
## documents it.
static func names_match(names: PackedStringArray, wanted: String) -> bool:
	var wanted_forms: PackedStringArray = _forms_of(wanted)
	for name: String in names:
		for form: String in _forms_of(name):
			if wanted_forms.has(form):
				return true
	return false


## The articles a trigger sentence may put between its "on" and the thing that happened.
const LEADING_ARTICLES: PackedStringArray = ["a", "an", "the"]


## Every spelling one name is allowed to be met by: the name itself, the name without a leading
## "on", and that without the article behind it. Each form is normalized LAST, and the words are
## dropped as WORDS, which is the whole reason this is not three string slices: reduced letter by
## letter, "On Anchored" would lose the "an" of "anchored" and match a verb that does not exist.
## A name that is nothing BUT those words keeps them - "On" compares as itself, never as nothing.
static func _forms_of(name: String) -> PackedStringArray:
	var words: PackedStringArray = _words_of(name)
	var forms: PackedStringArray = PackedStringArray([_normalize(name)])
	if words.size() > 1 and words[0].to_lower() == "on":
		words.remove_at(0)
		forms.append(_normalize(" ".join(words)))
		if words.size() > 1 and LEADING_ARTICLES.has(words[0].to_lower()):
			words.remove_at(0)
			forms.append(_normalize(" ".join(words)))
	return forms


## A name as the words it is made of. Anything that is not a letter or a digit separates two words,
## so `file_appeared` and "On A File Appeared" come apart the same way. Only punctuation separates:
## a run of letters is one word however it is capitalised, because the two spellings this reader
## compares are a method name and a display name, and neither ever relies on a capital to say where
## one word ends.
static func _words_of(name: String) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var current: String = ""
	for index: int in range(name.length()):
		var character: String = name[index]
		var lowered: String = character.to_lower()
		if (lowered >= "a" and lowered <= "z") or (lowered >= "0" and lowered <= "9"):
			current += character
			continue
		if not current.is_empty():
			words.append(current)
			current = ""
	if not current.is_empty():
		words.append(current)
	return words


static func _normalize(name: String) -> String:
	var out: String = ""
	for index: int in range(name.length()):
		var character: String = name[index].to_lower()
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			out += character
	return out


## A table cell back to a bare verb name: the code span the guides write it in, stripped, and the
## emphasis too. The parser turns a guide's `**Create Grid**` into `[b]Create Grid[/b]`, and a name
## read with its tags on matched nothing - so every verb on a page whose first column was bold
## counted twice against it, once as unlisted and once as unknown, and the advisory could never go
## quiet for that guide however complete it was.
static func _bare_name(cell: String) -> String:
	var bare: String = cell
	for tag: String in ["[code]", "[/code]", "[b]", "[/b]", "[i]", "[/i]", "[u]", "[/u]", "`"]:
		bare = bare.replace(tag, "")
	return bare.strip_edges()


static func _section_start(blocks: Array[Dictionary]) -> int:
	for index: int in range(blocks.size()):
		var block: Dictionary = blocks[index]
		if str(block.get("kind", "")) != "heading" or int(block.get("level", 0)) > 2:
			continue
		if str(block.get("slug", "")) == SECTION_SLUG:
			return index
	return -1


## Where the section ends: the next heading at the same level or higher. A "### Actions" inside it
## belongs to the section; a "## Use cases" after it does not.
static func _section_end(blocks: Array[Dictionary], start: int) -> int:
	for index: int in range(start + 1, blocks.size()):
		var block: Dictionary = blocks[index]
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) <= 2:
			return index
	return blocks.size()


static func _group_of(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "Conditions"
		ACEDefinition.ACEType.EXPRESSION:
			return "Expressions"
		ACEDefinition.ACEType.TRIGGER:
			return "Triggers"
	return "Actions"


## A definition's parameters as "name: Type", handling both shapes the registry produces -
## authored ACEParam resources and the plain Dictionaries reflection builds.
static func definition_params(definition: ACEDefinition) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for parameter: Variant in definition.parameters:
		if parameter is ACEParam:
			var param: ACEParam = parameter as ACEParam
			parts.append("%s: %s" % [param.get_param_name(), param.type_name])
		elif parameter is Dictionary:
			var entry: Dictionary = parameter as Dictionary
			parts.append("%s: %s" % [str(entry.get("display_name", entry.get("id", ""))),
				type_string(int(entry.get("type", TYPE_NIL)))])
	return ", ".join(parts)
