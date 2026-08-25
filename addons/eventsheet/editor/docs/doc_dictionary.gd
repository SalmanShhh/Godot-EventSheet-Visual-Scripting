# EventSheet - EventSheetDocDictionary: the GDScript-to-events dictionary, generated.
#
# Every Godot call, property and idiom this editor's reading recognises, alphabetically, with the
# sentence it reads as and where that reading comes from. It is the reference a power user wants and
# the proof a doubter wants, and nobody has to write it: the reading's own tables and the loaded
# vocabulary ARE the page.
#
# THE GENERATION IS PURE (page_markdown over entries) and the BAKING is the build tool's, exactly
# like What's new: the page is derived from things that live in the plugin's code, so it travels in
# the bundle rather than as a Markdown file under docs/ that nobody maintains and that the bundle's
# own drift check would then report forever.
#
# THE GATE the page exists for: it can never list a reading that does not exist, because every row
# is READ OUT of the table that produces it. A test regenerates the page and compares it with the
# shipped bytes, so a table edited without a rebake fails the suite instead of shipping a lie.
@tool
class_name EventSheetDocDictionary
extends RefCounted

## The baked page, beside the manifest, the figure verdicts and the release notes.
const BUNDLE_PATH := "res://addons/eventsheet/help/dictionary.esdoc"
const BUNDLE_HEADER := "[eventsheet-dictionary v1]"

## The page's own title. Frozen with the id scheme.
const PAGE_TITLE := "Dictionary: GDScript to events"

## Where a row's reading comes from, in the words a reader can act on. One name per table, so the
## page says which part of the reading answered rather than naming a source file.
const FROM_VOCABULARY := "Vocabulary"
const FROM_BODY_STATE := "Body state"
const FROM_MEMBERS := "Object properties"
const FROM_PROCESS := "How often it runs"
const FROM_EXPRESSIONS := "Expressions"
const FROM_RECEIVERS := "Object expressions"
const FROM_LISTS := "Lists"

static var _markdown: String = ""
static var _loaded: bool = false


## The page's Markdown, read from the bundle once per session. Empty when no bundle is installed
## (a source checkout that has not run the build tool), which draws an honest "not shipped" line
## rather than a blank page.
static func markdown() -> String:
	if _loaded:
		return _markdown
	_loaded = true
	_markdown = ""
	var text: String = _read(BUNDLE_PATH)
	if text.is_empty():
		return _markdown
	var newline: int = text.find("\n")
	if newline < 0 or text.substr(0, newline).strip_edges() != BUNDLE_HEADER:
		push_warning("EventSheetDocDictionary: %s is not an %s file." % [BUNDLE_PATH, BUNDLE_HEADER])
		return _markdown
	var payload: Variant = str_to_var(text.substr(newline + 1))
	if payload is Dictionary:
		_markdown = str((payload as Dictionary).get("markdown", ""))
	return _markdown


## Drops the cached page, so a rebuilt bundle lands without an editor restart (and so a test can
## read one it just wrote).
static func reload() -> void:
	_loaded = false
	_markdown = ""


## The page, as blocks the page view draws.
static func blocks() -> Array[Dictionary]:
	var source: String = markdown()
	if source.strip_edges().is_empty():
		return [
			{"kind": "heading", "level": 1, "text": PAGE_TITLE, "bbcode": PAGE_TITLE,
				"slug": EventSheetDocMarkdown.slug(PAGE_TITLE)},
			{"kind": "paragraph", "bbcode":
				"[i]The dictionary did not ship with this build of the plugin.[/i]"},
		]
	return EventSheetDocMarkdown.parse(source, "dictionary")


# ── What the reading recognises ───────────────────────────────────────────────────────────────


## Every entry the page prints, alphabetically by the GDScript it names: {call, reads_as, object,
## from, doc_id}. `doc_id` points at the row's own Manual entry - where Show GDScript and Add this
## row already live - and is "" for a table entry that names no single row.
##
## Two sources, and only two, because both can be ENUMERATED: the loaded vocabulary (an action or
## condition whose template writes the call) and the reading's own idiom tables. Nothing here is
## typed out by hand, so nothing here can drift away from what the editor actually does.
static func entries(registry: Variant = null) -> Array[Dictionary]:
	var by_call: Dictionary = {}
	_collect_vocabulary(registry, by_call)
	_collect_table(EventSheetSentence.BODY_STATE_WORDS, FROM_BODY_STATE, "Object", by_call)
	_collect_table(EventSheetSentence.MEMBER_WORDS, FROM_MEMBERS, "Object", by_call)
	_collect_table(EventSheetSentence.PROCESS_SWITCH_WORDS, FROM_PROCESS, "System", by_call)
	_collect_table(EventSheetSentence.EXPRESSION_IDIOMS, FROM_EXPRESSIONS, "System", by_call)
	_collect_table(EventSheetSentence.RECEIVER_IDIOMS, FROM_RECEIVERS, "Object", by_call)
	_collect_table(EventSheetSentence.LIST_STEPS, FROM_LISTS, "Array", by_call)
	var calls: Array = by_call.keys()
	calls.sort()
	var found: Array[Dictionary] = []
	for call: String in calls:
		found.append(by_call[call])
	return found


## The loaded vocabulary, asked the way the code search asks it: the row a call is ABOUT claims that call. A
## row that only reaches the call along the way is skipped, so `queue_free` names Queue Free once
## rather than every row that happens to free something.
static func _collect_vocabulary(registry: Variant, into: Dictionary) -> void:
	if registry == null:
		return
	var best_rank: Dictionary = {}
	for definition: ACEDefinition in registry.get_all_definitions():
		for call: String in EventSheetCodeSearch.definition_calls(definition):
			if not _is_plain_call(call):
				continue
			# Several rows write the same call; the page names the one the call is ABOUT, by the
			# same ranking the picker sorts by. Ties keep the vocabulary's own order, so the page
			# comes out byte-identical on every rebuild.
			var rank: int = EventSheetCodeSearch.match_rank(definition, call) + _name_bonus(definition, call)
			if into.has(call) and rank >= int(best_rank.get(call, 0)):
				continue
			best_rank[call] = rank
			into[call] = {
				"call": call,
				"reads_as": definition.display_name,
				"object": definition.category,
				"from": FROM_VOCABULARY,
				"doc_id": EventSheetDocExplain.doc_id_for_definition(definition)
			}


## One idiom table. A call the vocabulary already claimed keeps the vocabulary's row: that row is
## the one a reader can add to a sheet, and the table says the same thing in the same words.
static func _collect_table(table: Dictionary, from: String, object: String, into: Dictionary) -> void:
	for key: Variant in table:
		var call: String = str(key)
		if into.has(call) or not _is_plain_call(call):
			continue
		var reads_as: String = EventSheetCodeSearch.plain_words(str(table[key]))
		if reads_as.is_empty():
			continue
		into[call] = {
			"call": call,
			"reads_as": reads_as,
			"object": object,
			"from": from,
			"doc_id": ""
		}


## A row NAMED after the call is the row that call is about, whatever else its template writes:
## `emit_signal` belongs to Emit Signal rather than to whichever other row happens to raise one.
## Big enough to beat every other difference, so the rule is a decision and not a nudge.
const NAME_BONUS := -500


static func _name_bonus(definition: ACEDefinition, call: String) -> int:
	return NAME_BONUS if definition.display_name.to_lower().replace(" ", "_") == call else 0


## A table key that is a plain call or property name: snake_case, no receiver, no arguments. Some
## tables are keyed by a whole expression ("Input.get_gyroscope()") or by a receiver-qualified name
## ("Tween.tween_property"), and some templates lead with a type - all real, but none of them the
## one word a reader types, so the page keeps to the plain ones.
static func _is_plain_call(call: String) -> bool:
	if call.strip_edges().is_empty() or call.contains(" ") or call.contains("(") or call.contains("."):
		return false
	if call != call.to_lower():
		return false
	for index: int in call.length():
		var letter: String = call[index]
		if letter == "_" or letter.to_lower() != letter.to_upper() or letter.is_valid_int():
			continue
		return false
	return true


# ── The page ──────────────────────────────────────────────────────────────────────────────────


## The page's Markdown. PURE over the entries, so the build tool bakes exactly what the suite pins.
static func page_markdown(found: Array[Dictionary]) -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("# %s" % PAGE_TITLE)
	out.append("")
	out.append("Every Godot call, property and idiom this editor's reading recognises, in alphabetical order, with the sentence it reads as here and where that reading comes from. The page is generated from the reading's own tables and the vocabulary this build loaded, so it can never list a reading that does not exist.")
	out.append("")
	out.append("The **Reads as** name links to the row's own page, where Show GDScript prints the code it writes and Add this row drops it into the sheet you have open. Searching this page by an object's name (Sprite, Timer, Input) is how you filter it to one object.")
	out.append("")
	out.append("| GDScript | Reads as | Object | Where the reading comes from |")
	out.append("| --- | --- | --- | --- |")
	for entry: Dictionary in found:
		var reads_as: String = str(entry.get("reads_as", ""))
		var doc_id: String = str(entry.get("doc_id", ""))
		if not doc_id.is_empty():
			reads_as = "[%s](%s)" % [reads_as, doc_id]
		out.append("| `%s` | %s | %s | %s |" % [str(entry.get("call", "")), reads_as,
			str(entry.get("object", "")), str(entry.get("from", ""))])
	out.append("")
	return "\n".join(out)


## The baked file's exact bytes: the frozen header line, then the payload.
static func bundle_text(found: Array[Dictionary]) -> String:
	return "%s\n%s\n" % [BUNDLE_HEADER,
		var_to_str({"version": 1, "markdown": page_markdown(found)})]


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return ""
	var text: String = handle.get_as_text()
	handle.close()
	return text
