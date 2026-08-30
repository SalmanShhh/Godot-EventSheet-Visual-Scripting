# Godot EventSheets - EVERY PROPERTY TOO.
#
# The layer beside the derived calls, on the other half of what an object offers. A curated word map
# can only ever rename the properties somebody sat down and wrote words for - brightness for a
# light's energy, opacity for an alpha, size for a scale - and the property list underneath is far
# bigger than that, and a project's own exported variables bigger again. Everything the maps do not
# name used to read as one shape: the property's identifier, bold, with nothing said about it.
#
# It is very often knowable. The receiver of a property write is the same thing the receiver of a
# call is - `self`, an @onready node, a typed declaration, an Autoload, a bare class name - and the
# derived call layer already answers that question, so this asks it there rather than a second time.
# Once the class is known, so is whether the property EXISTS on it, and so are its words: the
# engine's own class reference for a built-in property, or the `##` lines above a project script's
# own `var`.
#
# THE INSPECTOR IS THE DESIGN BAR. Object, property, value - the three things the Inspector shows,
# in that order, with nothing to learn. Every reading here is that shape: a write is
# `Torch ▸ Set shadow_blur to 1.5`, a question is `Torch ▸ shadow_blur ≥ 1`, and a read of one
# answers inside the value slot it sits in, which is where the grammar says an expression answers.
#
# THE TWO LAYERS MUST NEVER LOOK ALIKE, for the same reason they must not among the calls: a curated
# sentence was written by a person and a derived reading is the API read back. Both are true, and the
# polished half stops meaning anything the moment a reader cannot tell which is which. So a derived
# property wears the same plainer tone a derived verb wears - not the bold `name` of the generic
# reading it replaces - and the class it was read off sits muted beside the object.
#
# CURATED OUTRANKS, AND UPGRADES IN PLACE. The word maps run inside the grammar, long before this,
# and a line one of them claims is never marked generic and therefore never reaches here at all.
# `$Torch.energy = 1.2` on a Light2D is "Set light energy to 120%", written by a person, and stays
# so. The day a word map lands for a property this reads today, its rows read the polished way on the
# next open with the file untouched: same bytes, better words.
#
# WHAT IS NOT CLAIMED. A receiver whose class nothing can answer for is not guessed at. A property
# the class does not have is not the class's property - it is somebody else's, reached through a name
# this cannot see - and dressing it up as one would be a guess. A bare `hp = 5` with no receiver
# written down is left exactly as it read, because the sheet's own variable rows own that reading.
# All three decline, the line keeps the plainer view it already had, and the ledger goes on counting
# it - general purpose includes the right to just be code.
#
# THE ROW IS THE LINE. Nothing here rewrites, re-orders or re-emits anything: it repaints segments
# the grammar already built, over an unchanged RawCodeRow, so byte-exactness is structural rather
# than earned. The suite proves it anyway, on the same buffers.
#
# COST. This runs at row-build time, once per generic property statement, on files with thousands of
# statements in them. Every answer is cached: the property set of a class once per class, each
# resolved property once per class and file, and the receiver facts through the derived call layer's
# own caches. The maps a caller already hoists per rebuild are passed in rather than rebuilt here.
@tool
class_name EventSheetDerivedProperties
extends RefCounted

## `<class>|<script path>|<property>` -> what that property is. One entry per property a file
## actually writes or asks about, so a sheet pays for the properties in front of the reader.
static var _property_cache: Dictionary = {}

## Class name -> {property name: declared type}. One walk of ClassDB per class, inherited included,
## because a reading asks "does this class have that property" once per statement.
static var _class_properties: Dictionary = {}


## The derived reading of a grammar sentence that marked itself generic, or {} when the sheet cannot
## honestly claim it:
##   {"segments", "class", "property", "script_path", "source", "doc", "credit", "doc_id"}
##
## `segments` is the grammar's own {text, tone} list with two tones changed and nothing else touched:
## the property drops from the generic reading's bold `name` to the plainer derived tone, and the
## value does the same when the value is ITSELF a read of a property this can answer for. Every word,
## every translation and every value spelling is the grammar's, exactly as it built them.
##
## `context` is the sentence context, `class_map` the object-label to class map the caller already
## hoists, `autoloads` the singleton name to script path map it hoists beside it.
static func derived_reading(sentence: Dictionary, context: Dictionary, class_map: Dictionary,
		autoloads: Dictionary) -> Dictionary:
	var mark: String = str(sentence.get("generic", ""))
	if mark != EventSheetSentence.GENERIC_PROPERTY_SET \
			and mark != EventSheetSentence.GENERIC_PROPERTY_COMPARE:
		return {}
	# `self.energy` splits to ["self", "energy"] and resolves to the script's own class, exactly as a
	# call on `self` does - the receiver layer is the same one, asked the same question.
	var split: PackedStringArray = EventSheetSentence.owner_and_member(
		str(sentence.get("generic_target", "")))
	if split.is_empty():
		return {}
	var receiver: Dictionary = EventSheetDerivedCalls.receiver_facts(
		split[0], context, class_map, autoloads)
	if receiver.is_empty():
		return {}
	var facts: Dictionary = property_facts(receiver, split[1])
	if facts.is_empty():
		return {}
	# The other half of the reading: what sits in the VALUE slot. An expression answers where it
	# stands, so a value that is itself a property this can answer for answers in the same derived
	# tone the property on the left wears, and its words ride along with the row's.
	var read: Dictionary = read_facts(str(sentence.get("generic_value", "")), context, class_map, autoloads)
	return {
		"segments": _repainted(sentence.get("segments", []) as Array, not read.is_empty()),
		"class": str(receiver.get("class", "")),
		"property": split[1],
		"script_path": str(receiver.get("script_path", "")),
		"source": str(receiver.get("source", "")),
		"doc": _joined_words(facts, read),
		"credit": str(facts.get("credit", "")) if not str(facts.get("credit", "")).is_empty() \
			else str(read.get("credit", "")),
		"doc_id": str(facts.get("doc_id", "")),
	}


## What the sheet knows about a property READ used as a value: the same facts a written one gets,
## plus the class it was read off. {} for an expression that is not exactly one object's one
## property, and for one whose class or property nothing can answer for - a value the sheet cannot
## place keeps the spelling the grammar gave it.
static func read_facts(expression: String, context: Dictionary, class_map: Dictionary,
		autoloads: Dictionary) -> Dictionary:
	var text: String = expression.strip_edges()
	if text.is_empty() or not EventSheetSentence.is_simple_target(text):
		return {}
	var split: PackedStringArray = EventSheetSentence.owner_and_member(text)
	if split.is_empty():
		return {}
	var receiver: Dictionary = EventSheetDerivedCalls.receiver_facts(
		split[0], context, class_map, autoloads)
	if receiver.is_empty():
		return {}
	var facts: Dictionary = property_facts(receiver, split[1])
	if facts.is_empty():
		return {}
	var read: Dictionary = facts.duplicate()
	read["class"] = str(receiver.get("class", ""))
	read["property"] = split[1]
	return read


## What one property of a known receiver is: {"doc", "credit", "doc_id", "type"} - or {} when that
## receiver has no such property, which is the whole refusal this layer rests on.
##
## The FILE'S OWN declarations lead, because those are the ones somebody wrote for this game and they
## carry the `##` lines; what the engine class underneath adds follows, with the engine's own
## sentence and the credit its licence requires.
static func property_facts(receiver: Dictionary, property: String) -> Dictionary:
	var wanted: String = property.strip_edges()
	if wanted.is_empty():
		return {}
	var class_text: String = str(receiver.get("class", "")).strip_edges()
	var script_path: String = str(receiver.get("script_path", "")).strip_edges()
	var key: String = "%s|%s|%s" % [class_text, script_path, wanted]
	if _property_cache.has(key):
		return _property_cache[key]
	var facts: Dictionary = _read_property(class_text, script_path, wanted)
	_property_cache[key] = facts
	return facts


## The Manual door for a derived property row, or "" when there is no page to open: the engine's own
## class reference has one per member, and a project script's `var` has none - its words are the `##`
## lines above it, which are shown where the row is instead. Public so the row menu and F1 ask the
## same question of the same function.
static func doc_id_for(class_text: String, property: String) -> String:
	var bare: String = class_text.strip_edges()
	if bare.is_empty() or property.strip_edges().is_empty() or not ClassDB.class_exists(bare):
		return ""
	if not _properties_of(bare).has(property.strip_edges()):
		return ""
	return EventSheetDocEngineReference.doc_id(bare, property.strip_edges())


## The Inspector's own spelling of a property name, for the line the hover leads with:
## `shadow_blur` -> "Shadow Blur". Never drawn on the row itself - the row shows the identifier the
## file writes, because that is the text a reader is looking at in the code beside it.
static func inspector_name(property: String) -> String:
	return property.strip_edges().capitalize()


## Drops every cached answer. Called from the same filesystem ping that drops the derived call
## layer's caches: a property added to a script nobody opened still has to reach the rows writing it.
static func clear_cache() -> void:
	_property_cache.clear()
	_class_properties.clear()


# ── the pieces ──────────────────────────────────────────────────────────────────


## The grammar's segments with the derived layer's two tones applied and nothing else touched: the
## property (the generic reading's one bold `name`) and, when the value is a property read this can
## answer for too, the value beside it. Matched by TONE rather than by position, because the order of
## the words in "Set {name} to {value}" is the translator's and not this layer's business.
static func _repainted(segments: Array, value_is_derived: bool) -> Array:
	var painted: Array = []
	var named: bool = false
	var valued: bool = false
	for entry: Variant in segments:
		var segment: Dictionary = (entry as Dictionary).duplicate()
		var tone: String = str(segment.get("tone", "plain"))
		if tone == "name" and not named:
			named = true
			segment["tone"] = EventSheetDerivedCalls.TONE_DERIVED
		elif tone == "value" and value_is_derived and not valued:
			valued = true
			segment["tone"] = EventSheetDerivedCalls.TONE_DERIVED
		painted.append(segment)
	return painted


## What the row says about itself on hover: the property's own words, and - when the value is a read
## of another property - that one's words after them, each led by the Inspector's name for it so a
## reader can tell the two apart. "" when neither said anything, which is honest and leaves the row
## hovering as the line it is.
static func _joined_words(facts: Dictionary, read: Dictionary) -> String:
	var said: PackedStringArray = PackedStringArray()
	var written: String = str(facts.get("doc", "")).strip_edges()
	if not written.is_empty():
		said.append(written)
	var answered: String = str(read.get("doc", "")).strip_edges()
	if not answered.is_empty():
		said.append("%s: %s" % [inspector_name(str(read.get("property", ""))), answered])
	return "\n".join(said)


## One property resolved, uncached. Declared-in-the-file first, then the engine class.
static func _read_property(class_text: String, script_path: String, property: String) -> Dictionary:
	var host: String = class_text
	if not script_path.is_empty():
		var declared: Dictionary = EventSheetScriptMembers.of_script(script_path)
		for entry: Variant in (declared.get("properties", []) as Array):
			var member: Dictionary = entry
			if str(member.get("name", "")) != property:
				continue
			return {"doc": str(member.get("doc", "")), "credit": "", "doc_id": "",
				"type": str(member.get("args", ""))}
		# The class the FILE extends answers for everything it did not declare itself, so an
		# ordinary engine property on a project script still reads.
		var base: String = str(declared.get("base", "")).strip_edges()
		if host.is_empty() and ClassDB.class_exists(base):
			host = base
	if host.is_empty() or not ClassDB.class_exists(host):
		return {}
	var known: Dictionary = _properties_of(host)
	if not known.has(property):
		return {}
	var described: String = EventSheetDocEngineReference.member_description(host, property)
	return {
		"doc": described,
		"credit": "" if described.strip_edges().is_empty() else EventSheetDocEngineReference.CREDIT_LINE,
		"doc_id": EventSheetDocEngineReference.doc_id(host, property),
		"type": str(known[property]),
	}


## Every property one engine class answers to, inherited included, as {name: declared type}. Sorted
## by nothing, because it is a lookup rather than a listing - every reader asks it by name.
##
## The Inspector's own headings (a category, a group, a subgroup) are entries in the same list and
## are not properties at all, so they are dropped; so is the privacy convention every project shares.
static func _properties_of(class_text: String) -> Dictionary:
	var bare: String = class_text.strip_edges()
	if _class_properties.has(bare):
		return _class_properties[bare]
	var found: Dictionary = {}
	const HEADINGS: int = PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP
	for info: Dictionary in ClassDB.class_get_property_list(bare):
		var name: String = str(info.get("name", ""))
		if name.is_empty() or name.begins_with("_") or (int(info.get("usage", 0)) & HEADINGS) != 0:
			continue
		var declared_class: String = str(info.get("class_name", ""))
		found[name] = declared_class if not declared_class.is_empty() \
			else type_string(int(info.get("type", TYPE_NIL)))
	_class_properties[bare] = found
	return found
