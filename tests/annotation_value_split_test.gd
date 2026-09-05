# Godot EventSheets - one `@ace_param` line, read the same way by both of its readers.
#
# A pack's annotations are parsed TWICE: the importer's lifter reads them back when the file is
# opened as a sheet, and the semantic analyzer reads them when the pack publishes its vocabulary.
# The two split the same line, so a line they disagree about publishes one vocabulary and opens as
# another - and because the lift is gated on the compiler re-emitting the block byte for byte, a
# mis-split default degrades the whole verb to a verbatim code block.
#
# That is exactly what a Dictionary default did: `default: {"verb": "shake", "amount": 0.4}` was cut
# at the first comma INSIDE the literal, so the line read back was not the line on disk and 22 of
# the Feedback Player's 54 verbs opened as raw code. The split now understands brackets as well as
# quotes, and a text whose brackets do not balance falls back to the older, group-blind split so
# nothing that parsed before parses differently.
#
# Pinned by VALUE - the segments themselves, and the default each reader ends up holding - because a
# count of segments is the same number for a right answer and a wrong one.
#
# THE WHOLE JOURNEY, not just the reading. An option whose key is the EMPTY word taught this file
# that surviving both readers is not the same as reaching a person: the pair came back intact and
# was then dropped three more times on the way to the dropdown, because every normalizer between
# here and the picker identified an option by its first NON-EMPTY field. A verb whose description
# says "leave the family empty to move the whole list" published a list with no way to leave it
# empty, and a built-in whose blank choice carried a LABEL had that label promoted to the key - so
# picking it would have written the words "keeping its place" into somebody's GDScript. Sections 5
# and 6 therefore follow one blank all the way: analyzer, generator, adapter, dropdown, and the
# emitted line it opens and saves back as.
@tool
class_name AnnotationValueSplitTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## The three shapes a comma can hide in, and the plain line that must not change.
const DICTIONARY_DEFAULT: String = "{\"verb\": \"shake\", \"amount\": 0.4, \"seconds\": 0.2}"
const ARRAY_DEFAULT: String = "[1.0, 2.0, 3.0]"
const CALL_DEFAULT: String = "Vector2(0.5, 0.5)"
const COMMA_IN_QUOTES: String = "\"a, b\""


static func run() -> bool:
	var ok: bool = true

	# ---- 1. The split itself, on both readers, as the segments each returns ----
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var cases: Array = [
		["a Dictionary default is one segment",
			"step, hint: feedback_step, default: %s, desc: \"Help.\"" % DICTIONARY_DEFAULT,
			["step", " hint: feedback_step", " default: %s" % DICTIONARY_DEFAULT, " desc: \"Help.\""]],
		["an Array default is one segment",
			"sizes, default: %s, desc: \"Help.\"" % ARRAY_DEFAULT,
			["sizes", " default: %s" % ARRAY_DEFAULT, " desc: \"Help.\""]],
		["a constructor default is one segment",
			"offset, default: %s, desc: \"Help.\"" % CALL_DEFAULT,
			["offset", " default: %s" % CALL_DEFAULT, " desc: \"Help.\""]],
		["a quoted string holding a comma is one segment",
			"word, default: %s, desc: \"Slow, steady.\"" % COMMA_IN_QUOTES,
			["word", " default: %s" % COMMA_IN_QUOTES, " desc: \"Slow, steady.\""]],
		["a line with no brackets at all splits exactly as it always did",
			"amount, hint: expression, default: 1.0, desc: \"Help.\"",
			["amount", " hint: expression", " default: 1.0", " desc: \"Help.\""]],
		["an UNBALANCED bracket falls back to the older, group-blind split",
			"amount, desc: half (of it, roughly",
			["amount", " desc: half (of it", " roughly"]],
		# A quote is the single one as well as the double, and a backslash inside a string escapes
		# whatever follows it. Both are code an author may legitimately write as a starting value, and
		# the two readers used to answer them DIFFERENTLY: the analyzer's split toggled on the double
		# quote alone, so it cut a single-quoted value at its comma and read past an escaped quote
		# into the help text, while the lifter, which understood both, read them whole. The
		# disagreement was invisible in BOTH directions, because the byte gate asks whether the
		# COMPILER reproduces the file and the compiler writes back what the LIFTER read - so the pack
		# published one starting value, the sheet opened on another, and every gate stayed green.
		["a single-quoted value keeps the comma inside it",
			"word, default_code: 'a, b', desc: \"Help.\"",
			["word", " default_code: 'a, b'", " desc: \"Help.\""]],
		["a backslash-escaped quote does not close the string",
			"word, default_code: \"\\\"\", desc: \"Help.\"",
			["word", " default_code: \"\\\"\"", " desc: \"Help.\""]],
	]
	for entry: Variant in cases:
		var row: Array = entry as Array
		var wanted: Array = row[2] as Array
		ok = _check("lifter: %s" % row[0], _as_array(EventSheetACELifter._split_outside_quotes(str(row[1]), ",")), wanted) and ok
		ok = _check("analyzer: %s" % row[0], _as_array(analyzer._split_outside_quotes(str(row[1]), ",")), wanted) and ok

	# ---- 2. The default each reader ends up holding, off the whole annotation line ----
	for entry: Variant in [
		["a Dictionary", DICTIONARY_DEFAULT], ["an Array", ARRAY_DEFAULT], ["a constructor", CALL_DEFAULT],
	]:
		var row: Array = entry as Array
		var line: String = "## @ace_param(step, hint: feedback_step, default: %s, desc: \"Help.\")" % row[1]
		ok = _check("lifter reads %s default whole" % row[0], _lifter_default(line, "step"), str(row[1])) and ok
		ok = _check("analyzer reads %s default whole" % row[0], _analyzer_default(line, "step"), str(row[1])) and ok
		ok = _check("lifter keeps the help beside %s default" % row[0], _lifter_description(line, "step"), "Help.") and ok

	# A quoted default still loses exactly one pair of quotes, which is what makes a word a word.
	var quoted_line: String = "## @ace_param(word, default: \"a, b\", desc: \"Slow, steady.\")"
	ok = _check("a quoted default holding a comma survives whole", _lifter_default(quoted_line, "word"), "a, b") and ok
	ok = _check("the analyzer agrees about it", _analyzer_default(quoted_line, "word"), "a, b") and ok

	# ---- 3. The round trip the lift gate actually asks for ----
	# The compiler writes the line back from what the lifter read; a mis-split is invisible until the
	# two texts are held against each other, which is the comparison the byte gate makes.
	for entry: Variant in [DICTIONARY_DEFAULT, ARRAY_DEFAULT, CALL_DEFAULT, "1.0"]:
		var written: String = "## @ace_param(step, hint: feedback_step, default: %s, desc: \"Help.\")" % entry
		ok = _check("re-emitting the line reproduces it: %s" % entry, _reemit(written, "step"), written) and ok

	# And the one shape that CANNOT round-trip, pinned so nobody ships it again: a default whose
	# value carries its own quotes is read WITHOUT them and written back bare, so the line on disk
	# and the line the compiler makes of it differ and the byte gate refuses the whole verb. A
	# word's quotes belong in the call template, never in the value the sheet stores.
	ok = _check("a default that carries its own quotes comes back bare",
		_reemit("## @ace_param(word, default: \"shake\", desc: \"Help.\")", "word"),
		"## @ace_param(word, default: shake, desc: \"Help.\")") and ok

	# ---- 4. An option that is the EMPTY word ships quoted, so it is still there on the way back ----
	# Written bare it was nothing at all: `options: |audio|camera` came back as the words after the
	# gap, and the "or leave it empty" entry the list offered silently stopped existing.
	var empty_first: Array = ["", "audio", "camera"]
	ok = _check("an empty option is written as a quoted empty word",
		SheetCompiler._param_option_text(""), "\"\"") and ok
	ok = _check("the option list keeps its empty entry through a round trip",
		_option_keys(_emit_options(empty_first)), empty_first) and ok
	ok = _check("a plain option list is written exactly as it was",
		_emit_options(["audio", "camera"]), "audio|camera") and ok
	# The SECOND writer of the same grammar - the annotation stub a published verb is offered as -
	# spells the blank the same way. Two writers of one grammar disagreeing means a verb authored
	# through the stub loses the choice a verb authored through the compiler keeps.
	ok = _check("the annotation stub writes the empty option quoted too",
		EventSheetACEAnnotationStub._comment_options(
			[{"key": "", "label": ""}, {"key": "audio", "label": "audio"}]),
		"\"\"|audio") and ok

	# ---- 5. The rest of the journey: read back is not the same as PUBLISHED ----
	# Surviving both readers only got the pair as far as the override dictionary. Three normalizers
	# stood between that and the picker, and each of them decided an option was identified by its
	# first NON-EMPTY field - so the blank was read past to the label, or dropped outright, and the
	# verb's own "leave it empty" instruction named something no dropdown could offer.
	var blank_first: Array = [{"key": "", "label": ""}, {"key": "audio", "label": "audio"}]
	ok = _check("the generator keeps an option that spells an empty key",
		EventSheetACEGenerator.new()._normalize_options_to_key_label(blank_first), blank_first) and ok
	# An entry that names NONE of key/value/label is still nothing, and a bare "" in a plain list is
	# still a stray separator - the fix is about a key that was spelled, not about junk.
	ok = _check("an option naming no field at all is still dropped",
		EventSheetACEGenerator.new()._normalize_options_to_key_label([{"note": "x"}, "audio"]),
		[{"key": "audio", "label": "audio"}]) and ok
	ok = _check("a bare empty entry in a plain list is still dropped",
		EventSheetACEGenerator.new()._normalize_options_to_key_label(["", "audio"]),
		[{"key": "audio", "label": "audio"}]) and ok

	# The builtin half, through the adapter every built-in descriptor reaches the picker by. Add
	# Child's "keeping its place" IS the empty key, and reading past it made the key those three
	# words - which the template would have written into somebody's file as bare GDScript.
	var keep_param: ACEParam = ACEParam.of("keep", "String", "", "Its place", "", "",
		[{"key": "", "label": "keeping its place"}, {"key": "false", "label": "snapping to it"}])
	ok = _check("the adapter keeps the empty key rather than promoting the label",
		_adapted_options(keep_param),
		[{"key": "", "label": "keeping its place"}, {"key": "false", "label": "snapping to it"}]) and ok

	# ---- 6. The picker draws it, and the row it writes still compiles and re-emits ----
	# A strict OptionButton that skipped the blank is where the whole chain was finally invisible:
	# every earlier layer could hold the pair and the reader still could not choose it.
	ok = _check("the picker offers the blank as a selectable item, keyed on the empty string",
		_dropdown_items(blank_first), [["(none)", ""], ["audio", "audio"]]) and ok
	ok = _check("an author-given label on the blank is the words shown",
		_dropdown_items([{"key": "", "label": "keeping its place"}]),
		[["keeping its place", ""]]) and ok
	ok = _check("the blank is the item selected when the parameter opens empty",
		_dropdown_selected(blank_first, ""), "(none)") and ok

	# The verb the whole thing was reported against, as it actually publishes today.
	ok = _check("the shipped verb publishes the blank its own description tells you to use",
		_published_option_keys("res://eventsheet_addons/juice/feedback_player.gd",
			"method:scale_feedback_amounts", "category"),
		["", "audio", "transform", "camera", "screen", "pause", "loop", "signal"]) and ok

	# And the line a row carrying that blank becomes still opens and saves byte for byte.
	var blank_row_source: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t$FeedbackPlayer.scale_feedback_amounts(\"\", 0.5)\n"
	ok = _check("a row saved with the blank key re-emits byte for byte",
		SUPPORT.reemit(blank_row_source, "user://annotation_value_split_blank_option.gd"),
		blank_row_source) and ok

	# ---- 7. WHICH KIND a starting value is, said out loud ----
	# A starting value is text a field holds, and whether that text needs quotes is decided by the
	# verb's own TEMPLATE - which the value has no way of knowing. `moment({moment_name})` inserts it
	# as code, so the value must be `"impact"`, quotes and all; `add_post_effect("{called}", ...)`
	# quotes the slot itself, so the value is the bare word `vignette`. The shorthand `default:`
	# cannot tell the two apart - section 3 pins the quotes coming straight back off it - so eighteen
	# shipped rows wrote GDScript nobody could parse: one wrote `moment(impact, 1)`, an undefined
	# identifier, and another wrote four quote characters where a name belonged.
	#
	# So the kind is SPELLED. `default_word:` is text the template quotes, protected here only when
	# bare would be misread, which is what finally lets a default be EMPTY; `default_code:` is
	# GDScript, verbatim. Pinned through BOTH readers and then re-emitted, because a spelling only
	# one reader understands publishes one vocabulary and opens as another, and a spelling that
	# cannot be written back is a verb the byte gate degrades to a block of raw code.
	for entry: Variant in [
		["the shorthand is read and written exactly as it always was", "default: impact", "impact"],
		["a word, said out loud", "default_word: vignette", "vignette"],
		["a word that is EMPTY, which the shorthand cannot say at all", "default_word: \"\"", ""],
		["a word with a quote inside it", "default_word: say \"hi\"", "say \"hi\""],
		["code, keeping the quotes its call needs", "default_code: \"impact\"", "\"impact\""],
		["code that is the empty string literal", "default_code: \"\"", "\"\""],
		["code holding the comma the spec splits on", "default_code: \"a, b\"", "\"a, b\""],
		["code quoted the OTHER way, comma and all", "default_code: 'a, b'", "'a, b'"],
		["code that is one escaped quote", "default_code: \"\\\"\"", "\"\\\"\""],
	]:
		var row: Array = entry as Array
		var line: String = "## @ace_param(word, %s, desc: \"Help, with a comma.\")" % row[1]
		ok = _check("lifter: %s" % row[0], _lifter_default(line, "word"), str(row[2])) and ok
		ok = _check("analyzer: %s" % row[0], _analyzer_default(line, "word"), str(row[2])) and ok
		ok = _check("the help survives beside it: %s" % row[0],
			_lifter_description(line, "word"), "Help, with a comma.") and ok
		ok = _check("re-emitting reproduces the line: %s" % row[0], _reemit(line, "word"), line) and ok

	# The THIRD writer of the same grammar - the stub a published verb is offered as - spells the two
	# kinds with the same two keys. It used to double the quotes instead (`""idle""`), and had to
	# REFUSE a quoted value that also held a comma, because the extra pair closes before the comma
	# and the segment split there. There is nothing left for it to refuse.
	for entry: Variant in [
		["a quoted literal is code", "\"idle\"", "default_code: \"idle\""],
		["a literal holding a comma needs no refusal now", "\"a, b\"", "default_code: \"a, b\""],
		["a word carrying a comma is a protected word", "a, b", "default_word: \"a, b\""],
		["a plain value still ships under the shorthand", "1.0", "default: 1.0"],
	]:
		var row: Array = entry as Array
		ok = _check("the stub spells it the pipeline's way: %s" % row[0],
			EventSheetACEAnnotationStub._comment_default(str(row[1])), str(row[2])) and ok

	# And the receipt that the spelling reached a PERSON: the row the whole defect was reported
	# against opens on a cleared box again, which is what its own description offers.
	ok = _check("the shipped row opens on the empty name its description names",
		_published_default("res://eventsheet_addons/screen_fx/screen_fx.gd",
			"method:add_post_effect", "called"), "") and ok

	return ok


## The starting value a SHIPPED provider script publishes for one parameter - the vocabulary as the
## picker receives it. Read through the real file because annotations are read off DISK.
static func _published_default(script_path: String, ace_id: String, param_id: String) -> String:
	var script: Script = load(script_path) as Script
	if script == null or not script.can_instantiate():
		return "<no such script>"
	var instance: Object = script.new()
	var answer: String = "<no such parameter>"
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_object(instance):
		if definition.id != ace_id:
			continue
		for parameter: Variant in definition.parameters:
			if str((parameter as Dictionary).get("id", "")) == param_id:
				answer = str((parameter as Dictionary).get("default_value", ""))
	if instance is Node:
		(instance as Node).free()
	return answer


## One ACEParam's options as the ACEDefinition adapter hands them to the picker, with the `note`
## key (empty for every option that declares none) dropped so the pin reads as the pair itself.
static func _adapted_options(param: ACEParam) -> Array:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.ace_id = "AnnotationValueSplitProbe"
	descriptor.params = [param] as Array[ACEParam]
	var definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(descriptor)
	var output: Array = []
	for parameter: Variant in definition.parameters:
		for option: Variant in (parameter as Dictionary).get("options", []):
			var pair: Dictionary = (option as Dictionary).duplicate()
			pair.erase("note")
			output.append(pair)
	return output


## What the params dialog's dropdown actually holds, as [shown words, stored value] rows - the two
## halves a strict OptionButton keeps apart, and the only place the stored "" can be seen.
static func _dropdown_items(options: Array) -> Array:
	var dropdown: OptionButton = ACEParamsDialog.new()._create_options_field("probe", options, "")
	var rows: Array = []
	for index: int in range(dropdown.item_count):
		rows.append([dropdown.get_item_text(index), str(dropdown.get_item_metadata(index))])
	dropdown.free()
	return rows


## The words the dropdown opens on for a parameter whose starting value is `opening_value`.
static func _dropdown_selected(options: Array, opening_value: Variant) -> String:
	var dropdown: OptionButton = ACEParamsDialog.new()._create_options_field("probe", options, opening_value)
	var shown: String = dropdown.get_item_text(dropdown.selected) if dropdown.selected >= 0 else "<nothing selected>"
	dropdown.free()
	return shown


## The option keys a SHIPPED provider script publishes for one parameter - the vocabulary as the
## picker receives it, reflected exactly the way the live registry reflects an installed pack. The
## annotations are read off DISK, so this has to go through the real file rather than a source
## string, which would carry no annotations at all.
static func _published_option_keys(script_path: String, ace_id: String, param_id: String) -> Array:
	var script: Script = load(script_path) as Script
	if script == null or not script.can_instantiate():
		return ["<no such script>"]
	var instance: Object = script.new()
	var keys: Array = []
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_object(instance):
		if definition.id != ace_id:
			continue
		for parameter: Variant in definition.parameters:
			if str((parameter as Dictionary).get("id", "")) != param_id:
				continue
			for option: Variant in (parameter as Dictionary).get("options", []):
				keys.append(str((option as Dictionary).get("key", "")))
	if instance is Node:
		(instance as Node).free()
	return keys


## The `default:` one `@ace_param` line leaves the lifter holding for a parameter.
static func _lifter_default(line: String, param_id: String) -> String:
	var fields: Dictionary = EventSheetACELifter._parse_annotations("## @ace_action\n" + line)
	return str((fields.get("param_defaults", {}) as Dictionary).get(param_id, "<none>"))


## The help text beside it - proof the split did not swallow the key after the default.
static func _lifter_description(line: String, param_id: String) -> String:
	var fields: Dictionary = EventSheetACELifter._parse_annotations("## @ace_action\n" + line)
	return str((fields.get("param_descriptions", {}) as Dictionary).get(param_id, "<none>"))


## The same question asked of the analyzer, through its own param-spec reader.
static func _analyzer_default(line: String, param_id: String) -> String:
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var overrides: Dictionary = {}
	var inner: String = line.trim_prefix("## @ace_param(").trim_suffix(")")
	analyzer._parse_param_spec(inner, overrides)
	return str((overrides.get("param_defaults", {}) as Dictionary).get(param_id, "<none>"))


## One annotation line read by the lifter and written back by the compiler - the gate's own question.
static func _reemit(line: String, param_id: String) -> String:
	var fields: Dictionary = EventSheetACELifter._parse_annotations("## @ace_action\n" + line)
	var ace_param: ACEParam = ACEParam.new()
	ace_param.id = param_id
	ace_param.hint = str((fields.get("param_hints", {}) as Dictionary).get(param_id, ""))
	ace_param.default_value = (fields.get("param_defaults", {}) as Dictionary).get(param_id, "")
	ace_param.default_spelling = str((fields.get("param_default_spellings", {}) as Dictionary).get(param_id, ""))
	ace_param.description = str((fields.get("param_descriptions", {}) as Dictionary).get(param_id, ""))
	var written: PackedStringArray = SheetCompiler._param_annotation_lines(ace_param)
	return written[0] if written.size() > 0 else "<nothing written>"


## An options list as the compiler writes it into an `options:` value.
static func _emit_options(options: Array) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for option_value: Variant in options:
		texts.append(SheetCompiler._param_option_text(option_value))
	return "|".join(texts)


## The keys the lifter reads back out of such a value - the list the picker would offer.
static func _option_keys(value: String) -> Array:
	var keys: Array = []
	for pair: Variant in EventSheetACELifter._split_option_pairs(value):
		keys.append(str((pair as Dictionary).get("key", "")))
	return keys


## A PackedStringArray as a plain Array, so a pinned row reads as the segments themselves.
static func _as_array(parts: Variant) -> Array:
	var output: Array = []
	for part: Variant in parts:
		output.append(str(part))
	return output


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("annotation_value_split_test", label, actual, expected)
