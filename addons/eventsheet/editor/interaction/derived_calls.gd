# Godot EventSheets - EVERY CALL ON A KNOWN CLASS IS A ROW.
#
# A curated vocabulary can only ever name the verbs somebody sat down and wrote words for. The API
# underneath it is far bigger than that, and a project's own classes are bigger again - so a file
# full of perfectly ordinary calls used to read as a run of anonymous Object / Verb chips whose
# arguments were bare values, whatever the sheet already knew about the thing being called.
#
# It usually knows a great deal. The receiver of a call is very often something the sheet can name
# the CLASS of without running anything: `self` is the script's own host class, an @onready node
# carries its declared type, a `var timer: Timer` says so in the declaration, an Autoload is a
# script at a known path, and a bare class name is a class. Once the class is known, so are the
# method's parameter names and - for the engine's classes and for a project script with `##` lines
# above its declarations - the method's own words.
#
# THE TWO LAYERS MUST NEVER LOOK ALIKE. A curated sentence was written by a person; a derived
# reading is the API read back. Both are true, and a reader has to be able to tell them apart at a
# glance or the polished half stops meaning anything - so a derived reading keeps the PLAINER call
# style: the verb is not bold, and the object column carries the class it was read off as its muted
# note. Where a curated recogniser claims the line, the curated sentence wins outright and nothing
# here is ever asked. Landing a curated table later therefore upgrades a derived row in place, on
# the next open, with the file untouched: same bytes, better words.
#
# WHAT IS NOT CLAIMED. A receiver whose class nothing can answer for is not guessed at. The reading
# declines, the caller keeps whatever plainer view it already had, and the ledger goes on counting
# the line - general purpose includes the right to just be code.
#
# THE ROW IS THE LINE. Nothing here rewrites, re-orders or re-emits anything: it is a view over an
# unchanged RawCodeRow, so byte-exactness is structural rather than earned. The suite proves it
# anyway, on the same buffers.
#
# COST. This runs at row-build time, once per statement, on files with thousands of statements in
# them. So every answer is cached: the class facts per file identity (through the shared script
# reader, which the editor's filesystem ping drops), the project's class-name to path map once per
# session, and each resolved method once per class. The maps a caller already hoists per rebuild -
# the object-class map and the autoload list - are passed in rather than rebuilt here.
@tool
class_name EventSheetDerivedCalls
extends RefCounted

## The tone a derived reading's verb wears, told apart from the curated sentence's bold `name`.
## The renderer maps it; the constant lives here so the reading and the painting share one word.
const TONE_DERIVED: String = "derived"

## Where a receiver's class came from. Stable strings - a test pins them, and the workbench's
## per-line claim shows them, so a reading that starts answering from somewhere else is visible.
const SOURCE_SELF: String = "self"
const SOURCE_NODE: String = "node"
const SOURCE_DECLARED: String = "declared"
const SOURCE_AUTOLOAD: String = "autoload"
const SOURCE_CLASS: String = "class"

## `<class>|<script path>|<method>` -> what that method is. One entry per method a file actually
## calls, so a sheet pays for the methods in front of the reader rather than for every method in the
## project.
static var _method_cache: Dictionary = {}

## Class name -> the script that declares it, built once from the project's global class list.
## Deliberately NOT the project scanner's list: that one is filtered for what a PICKER should offer
## and hands back a deep copy on every call, and this is asked once per statement.
static var _class_paths: Dictionary = {}
static var _class_paths_built: bool = false


## The whole derived reading of one statement, or {} when the sheet cannot honestly claim it:
##   {"object", "pieces", "class", "method", "script_path", "source", "doc", "credit", "doc_id"}
##
## `pieces` is the row builder's own [text, tone] list, already in the plainer derived style.
## `doc_id` is the Manual door for the verb, which exists only for the engine's own classes - a
## project script's words are its `##` lines, which ride in the hover rather than in a page.
##
## `context` is the sentence context (for `self_class`, `variable_types` and the value spellings),
## `class_map` the object-label to class map the caller already hoists, `autoloads` the singleton
## name to script path map it hoists beside it.
static func derived_pieces(code: String, context: Dictionary, class_map: Dictionary,
		autoloads: Dictionary) -> Dictionary:
	var call: Dictionary = EventSheetSentence.call_parts(code.strip_edges())
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var receiver: Dictionary = receiver_facts(str(call.get("target", "")), context, class_map, autoloads)
	if receiver.is_empty():
		return {}
	var facts: Dictionary = method_facts(receiver, method)
	if facts.is_empty():
		return {}
	var reading: Dictionary = EventSheetSentence.call_reading(code, context,
		facts.get("params", PackedStringArray()))
	if reading.is_empty():
		return {}
	var pieces: Array = []
	for entry: Variant in (reading.get("segments", []) as Array):
		var segment: Dictionary = entry
		# The ONE thing this layer changes about the words: the verb stops being the bold name of a
		# curated sentence and reads in the plainer derived tone. The values, the connectives and
		# the object label are the grammar's, untouched.
		var tone: String = str(segment.get("tone", "plain"))
		pieces.append([str(segment.get("text", "")), TONE_DERIVED if tone == "name" else tone])
	return {
		"object": str(reading.get("object", "")),
		"pieces": pieces,
		"class": str(receiver.get("class", "")),
		"method": method,
		"script_path": str(receiver.get("script_path", "")),
		"source": str(receiver.get("source", "")),
		"doc": str(facts.get("doc", "")),
		"credit": str(facts.get("credit", "")),
		"doc_id": str(facts.get("doc_id", "")),
	}


## What the sheet knows about the thing a call is aimed at: {"class", "script_path", "source"}, or
## {} when it knows nothing - which is the answer for `get_parent().thing()`, for a Variant local
## and for a name that is only ever assigned at run time.
##
## The spellings, cheapest first: an empty or `self` receiver is the script's own class; the object
## map already carries every @onready node's declared type under its name, its `$Path` and its
## `%Unique`; a declaration says the type of a plain `var`; an Autoload is a singleton name; and a
## bare class name is a class.
static func receiver_facts(target: String, context: Dictionary, class_map: Dictionary,
		autoloads: Dictionary) -> Dictionary:
	var receiver: String = target.strip_edges()
	if receiver.is_empty() or receiver == "self":
		var host: String = str(context.get("self_class", "")).strip_edges()
		var own_path: String = str(context.get("self_script_path", "")).strip_edges()
		if host.is_empty() and own_path.is_empty():
			return {}
		return {"class": host, "script_path": own_path, "source": SOURCE_SELF}
	var mapped: String = str(class_map.get(receiver, "")).strip_edges()
	if mapped.is_empty():
		mapped = str(class_map.get(EventSheetSentence.object_of_reference(receiver), "")).strip_edges()
	if is_class_text(mapped):
		return {"class": mapped, "script_path": _script_of_class(mapped), "source": SOURCE_NODE}
	var declared: String = str((context.get("variable_types", {}) as Dictionary).get(receiver, "")).strip_edges()
	if is_class_text(declared):
		return {"class": declared, "script_path": _script_of_class(declared), "source": SOURCE_DECLARED}
	if autoloads.has(receiver):
		var singleton_path: String = str(autoloads[receiver]).strip_edges()
		if not singleton_path.is_empty():
			return {"class": "", "script_path": singleton_path, "source": SOURCE_AUTOLOAD}
	if is_class_text(receiver):
		return {"class": receiver, "script_path": _script_of_class(receiver), "source": SOURCE_CLASS}
	return {}


## True when a piece of declared type text names a CLASS - something a method can be called on and
## looked up against. False for a built-in value type (`int`, `float`, `String`), for a typed
## collection (`Array[Node]`, whose type names what is INSIDE it rather than the receiver), and for
## a name the project does not declare.
##
## The refusal is the load-bearing half: a declared type this cannot place is left alone, the row
## keeps whatever plainer view it already had, and nothing is guessed.
static func is_class_text(type_text: String) -> bool:
	var bare: String = type_text.strip_edges()
	if bare.is_empty() or bare.contains("["):
		return false
	return ClassDB.class_exists(bare) or _class_path_map().has(bare)


## What one method of a known receiver is: {"params", "doc", "credit", "doc_id"} - or {} when that
## receiver has no such method, which is the whole refusal this layer rests on. A name the class
## does not answer to is somebody else's method reached through a variable this cannot see, and
## dressing it up as the class's own would be a guess.
##
## The FILE'S OWN declarations lead, because those are the ones somebody wrote for this game and
## they carry the `##` lines; what the engine class underneath adds follows, with the engine's own
## sentence and the credit its licence requires.
static func method_facts(receiver: Dictionary, method: String) -> Dictionary:
	var wanted: String = method.strip_edges()
	if wanted.is_empty():
		return {}
	var class_text: String = str(receiver.get("class", "")).strip_edges()
	var script_path: String = str(receiver.get("script_path", "")).strip_edges()
	var key: String = "%s|%s|%s" % [class_text, script_path, wanted]
	if _method_cache.has(key):
		return _method_cache[key]
	var facts: Dictionary = _read_method(class_text, script_path, wanted)
	_method_cache[key] = facts
	return facts


## The Manual door for a derived row, or "" when there is no page to open: the engine's own class
## reference has one per member, and a project script's words are its `##` lines, which have no page
## and are shown where the row is instead. Public so the row menu and F1 ask the same question.
static func doc_id_for(class_text: String, method: String) -> String:
	var bare: String = class_text.strip_edges()
	if bare.is_empty() or method.strip_edges().is_empty() or not ClassDB.class_exists(bare):
		return ""
	return EventSheetDocEngineReference.doc_id(bare, method.strip_edges())


## THE MUTED WORD a derived row carries beside its object: the class the verb was read off, or "" when
## the object column is already saying that class and repeating it would be noise.
##
## It always WINS over the variable name the declaration lens leaves on a curated row. That lens
## answers a different question - what a receiver IS rather than what it was called - and for a class
## the project declared it moves the class INTO the object column and mutes the variable's own name.
## Left to run on a derived row it inverts the one mark that tells the two layers apart at a glance:
## the muted word beside a derived object has to be a class, because a name there is what a curated
## row looks like. One row, one answer, and both call sites ask this.
static func muted_note(reading: Dictionary, object_label: String) -> String:
	var read_class: String = str(reading.get("class", "")).strip_edges()
	var shown: String = object_label.strip_edges()
	if read_class.is_empty() or read_class == shown:
		return ""
	if EventSheetViewportReadingRows.class_object_label(read_class) == shown:
		return ""
	return read_class


## The hover a derived row carries above its code: what the verb does, in the method's own words,
## with the credit when those words are the engine's. "" when nothing said anything about it, which
## is honest and leaves the row hovering as the line it is.
static func hover_text(reading: Dictionary) -> String:
	var said: String = str(reading.get("doc", "")).strip_edges()
	if said.is_empty():
		return ""
	var credit: String = str(reading.get("credit", "")).strip_edges()
	return said if credit.is_empty() else "%s\n%s" % [said, credit]


## Drops every cached answer. Called from the same filesystem ping that drops the script reader's
## own cache: a method renamed in a file the reader never opened still has to reach the rows that
## call it.
static func clear_cache() -> void:
	_method_cache.clear()
	_class_paths.clear()
	_class_paths_built = false


# ── the pieces ──────────────────────────────────────────────────────────────────


## One method resolved, uncached. Declared-in-the-file first, then the engine class.
static func _read_method(class_text: String, script_path: String, method: String) -> Dictionary:
	if not script_path.is_empty():
		var declared: Dictionary = EventSheetScriptMembers.of_script(script_path)
		for entry: Variant in (declared.get("methods", []) as Array):
			var member: Dictionary = entry
			if str(member.get("name", "")) != method:
				continue
			return {"params": parameter_names(str(member.get("args", ""))),
				"doc": str(member.get("doc", "")), "credit": "", "doc_id": ""}
		# The class the FILE extends answers for everything it did not declare itself, so a
		# `queue_free()` on a project script still reads as the engine's own verb.
		var base: String = str(declared.get("base", "")).strip_edges()
		if class_text.is_empty() and ClassDB.class_exists(base):
			class_text = base
	if class_text.is_empty() or not ClassDB.class_exists(class_text):
		return {}
	if not ClassDB.class_has_method(class_text, method, false):
		return {}
	var described: String = EventSheetDocEngineReference.member_description(class_text, method)
	return {
		"params": EventSheetViewportReadingRows.method_parameter_names(class_text, method),
		"doc": described,
		"credit": "" if described.strip_edges().is_empty() else EventSheetDocEngineReference.CREDIT_LINE,
		"doc_id": doc_id_for(class_text, method),
	}


## `amount: int = 1, source: Node` -> ["amount", "source"]. The declaration exactly as the file
## writes it, split at the commas that are not inside a default value's own brackets. Public because
## the declaration map asks it the same question of a handler's own arguments, and two readings of
## what a parameter list is would be two ideas of which names a function shadows.
static func parameter_names(args: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for piece: String in EventSheetSentence.split_top_level(args, ","):
		var text: String = piece.strip_edges()
		for separator: String in [":", "="]:
			var at: int = text.find(separator)
			if at > 0:
				text = text.substr(0, at).strip_edges()
		if EventSheetViewportLenses.is_identifier(text):
			names.append(text)
	return names


## The script a project class is declared in, or "" for an engine class (which has none) and for a
## name the project does not declare.
static func _script_of_class(class_text: String) -> String:
	return str(_class_path_map().get(class_text.strip_edges(), ""))


## Class name -> script path, built once per session off the engine's own global class list. Sorted
## by nothing, because it is a lookup rather than a listing - every reader asks it by name.
static func _class_path_map() -> Dictionary:
	if _class_paths_built:
		return _class_paths
	_class_paths_built = true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var declared: String = str(entry.get("class", "")).strip_edges()
		var path: String = str(entry.get("path", "")).strip_edges()
		if not declared.is_empty() and not path.is_empty():
			_class_paths[declared] = path
	return _class_paths
