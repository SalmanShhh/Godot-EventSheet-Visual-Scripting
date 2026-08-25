# Godot EventSheets - finding a row by the Godot call it writes
#
# The picker searches display names, categories and synonyms, which is the right answer for someone
# who thinks in the sheet's words. Someone who thinks in GDScript types `queue_free` and finds
# nothing - even though the row they want is Destroy, and Destroy's own template is the call they
# just typed.
#
# So the picker also searches the CODE: every identifier an ACE's codegen template calls or reads,
# plus the idiom tables the reading uses to turn a call into a sentence. Type `queue_free` and
# Destroy answers; type `is_on_floor` and Is on floor answers; and the match writes the GDScript
# beside the name, so the reader can see it really is the same thing.
#
# Everything here is pure and static: it reads a definition's shipped metadata and never changes it.
@tool
class_name EventSheetCodeSearch
extends RefCounted

## Below this a "code" query is indistinguishable from an ordinary word ("add", "set"), and the
## whole vocabulary would answer.
const MIN_QUERY_LENGTH := 4


## Does this query look like a Godot call or property rather than a plain word? Snake_case, an
## explicit `()`, or a dotted member - the three shapes a Godot user types from memory.
static func is_code_query(query: String) -> bool:
	var trimmed: String = query.strip_edges().trim_suffix("()")
	if trimmed.length() < MIN_QUERY_LENGTH:
		return false
	if trimmed != trimmed.to_lower():
		return false
	if not (trimmed.contains("_") or query.strip_edges().ends_with("()") or trimmed.contains(".")):
		return false
	return _is_identifier_ish(trimmed)


static func _is_identifier_ish(text: String) -> bool:
	for index: int in text.length():
		var letter: String = text[index]
		if letter == "_" or letter == ".":
			continue
		if not (letter.is_valid_identifier() or letter.to_lower() != letter.to_upper() or letter.is_valid_int()):
			return false
	return not text.begins_with(".") and not text.ends_with(".")


## The query with the sugar a reader types stripped off: `queue_free()` and `.queue_free` both come
## back as `queue_free`.
static func normalize(query: String) -> String:
	var trimmed: String = query.strip_edges().trim_suffix("()")
	var dot: int = trimmed.rfind(".")
	return trimmed.substr(dot + 1) if dot >= 0 else trimmed


## Every identifier a codegen template CALLS (`queue_free(`) or READS (`.position`). Order is the
## template's own, duplicates removed - so the first entry is the call the row is really about.
static func template_calls(template: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if template.strip_edges().is_empty():
		return found
	var call_pattern: RegEx = RegEx.create_from_string("([A-Za-z_][A-Za-z0-9_]*)\\s*\\(")
	for hit: RegExMatch in call_pattern.search_all(template):
		var name: String = hit.get_string(1)
		if not found.has(name):
			found.append(name)
	# `.position` reads a member, and so does `{target.}position` - a template's target slot ends
	# with the dot, so the member lands right after the closing brace instead of after a dot.
	var member_pattern: RegEx = RegEx.create_from_string("[.}]([A-Za-z_][A-Za-z0-9_]*)")
	for hit: RegExMatch in member_pattern.search_all(template):
		var name: String = hit.get_string(1)
		if not found.has(name):
			found.append(name)
	return found


## The calls one ACE writes. Reads the definition's shipped metadata only - the template is a
## frozen compatibility promise and nothing here touches it.
static func definition_calls(definition: ACEDefinition) -> PackedStringArray:
	if definition == null:
		return PackedStringArray()
	return template_calls(str(definition.metadata.get("codegen_template", "")))


## Does this ACE write the call the reader typed? An exact name, so `add_child` finds Create object
## and not every row whose template happens to contain the letters.
static func matches(definition: ACEDefinition, query: String) -> bool:
	var wanted: String = normalize(query)
	if wanted.is_empty():
		return false
	return definition_calls(definition).has(wanted)


## How CENTRAL the call is to this row - lower is more central. A row whose template LEADS with the
## call scores in the units; one that only reaches it along the way scores past a thousand. Within
## each, the row that writes the least around the call wins, because a template that is one call is
## a row that is about that call: `queue_free` must land on Queue Free, not on the sound row that
## frees its own player when the clip ends, and `add_child` on Add Child rather than on a spawn row
## that instances a scene and names it first.
const RANK_INCIDENTAL := 1000

## The tier a row whose own NAME is the call sits in when its template does not lead with it. A
## template can reach a call along the way and still be the row a reader came for: "Tween Property"
## writes `create_tween()` first, and every other row that reaches `tween_property` uses a tween to
## do something else (Fade Brightness walks a light). Between two incidental rows the name decides,
## and a row that LEADS with the call needs no help from its name.
const RANK_NAMED := 500


static func match_rank(definition: ACEDefinition, query: String) -> int:
	var calls: PackedStringArray = definition_calls(definition)
	var leads: bool = calls.size() > 0 and calls[0] == normalize(query)
	if leads:
		return calls.size()
	return (RANK_NAMED if is_named_for(definition, query) else RANK_INCIDENTAL) + calls.size()


## True when the row's own display name IS the call, in words: "Tween Property" for `tween_property`,
## "Queue Free" for `queue_free`. Compared with the punctuation and the case taken out of both, so
## the two spellings of one idea are the same string.
static func is_named_for(definition: ACEDefinition, query: String) -> bool:
	if definition == null:
		return false
	return definition.display_name.to_lower().replace(" ", "_") == normalize(query).to_lower()


## Every row that writes the call, the ones the call is ABOUT first. The picker appends this list
## and the tests read the same one, so what a reader sees and what is pinned cannot drift apart.
static func matching_definitions(candidates: Array, query: String) -> Array[ACEDefinition]:
	var ranked: Array[Dictionary] = []
	for entry: Variant in candidates:
		var definition: ACEDefinition = entry as ACEDefinition
		if definition == null or not matches(definition, query):
			continue
		ranked.append({"rank": match_rank(definition, query), "order": ranked.size(), "definition": definition})
	# Ties keep the vocabulary's own order, so the list is the same on every run.
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["rank"]) != int(right["rank"]):
			return int(left["rank"]) < int(right["rank"])
		return int(left["order"]) < int(right["order"]))
	var found: Array[ACEDefinition] = []
	for entry: Dictionary in ranked:
		found.append(entry["definition"])
	return found


## The GDScript written beside the matched name in the picker: `queue_free()` for a call, `.position`
## for a property. "" when this row does not write the call at all.
static func gdscript_hint(definition: ACEDefinition, query: String) -> String:
	if not is_code_query(query) or not matches(definition, query):
		return ""
	var wanted: String = normalize(query)
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if RegEx.create_from_string("\\b%s\\s*\\(" % wanted).search(template) != null:
		return "%s()" % wanted
	return ".%s" % wanted


## The sheet's own words for a Godot call, taken from the tables the READING already uses, so the
## picker and the reading can never disagree about what `is_on_floor` is called here. "" when no
## table names it. Fed back into the ordinary display-name search, which is how a table entry with
## no template of its own still lands on the right row.
static func idiom_words(query: String) -> String:
	var wanted: String = normalize(query)
	if wanted.is_empty():
		return ""
	if EventSheetSentence.BODY_STATE_WORDS.has(wanted):
		return str(EventSheetSentence.BODY_STATE_WORDS[wanted])
	if EventSheetSentence.MEMBER_WORDS.has(wanted):
		return str(EventSheetSentence.MEMBER_WORDS[wanted])
	if EventSheetSentence.PROCESS_SWITCH_WORDS.has(wanted):
		return plain_words(str(EventSheetSentence.PROCESS_SWITCH_WORDS[wanted]))
	if EventSheetSentence.EXPRESSION_IDIOMS.has(wanted):
		return plain_words(str(EventSheetSentence.EXPRESSION_IDIOMS[wanted]))
	if EventSheetSentence.RECEIVER_IDIOMS.has(wanted):
		return plain_words(str(EventSheetSentence.RECEIVER_IDIOMS[wanted]))
	if EventSheetSentence.LIST_STEPS.has(wanted):
		return plain_words(str(EventSheetSentence.LIST_STEPS[wanted]))
	return ""


## An idiom template with its slots taken out, so what is left is the words a reader would search
## for: "Push back {value} to {name}" becomes "Push back to".
static func plain_words(template: String) -> String:
	var stripped: String = RegEx.create_from_string("\\{[^}]*\\}").sub(template, " ", true)
	var words: PackedStringArray = PackedStringArray()
	for word: String in stripped.split(" ", false):
		var cleaned: String = word.strip_edges()
		if not cleaned.is_empty():
			words.append(cleaned)
	return " ".join(words).strip_edges()
