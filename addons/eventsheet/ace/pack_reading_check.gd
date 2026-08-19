@tool
class_name EventSheetPackReadingCheck
extends RefCounted

# The reading check a pack passes before it publishes.
#
# The readability promise ("an opened script reads like an event sheet") only holds if the packs
# keep it, so this is the rule written down once and read from three places: the Publish dialog,
# a Doctor check on the packs in this project, and a test over the shipped ones.
#
# What every published condition / action / expression must do:
#   1. read as a sentence - the words a reader sees are words, not a bare call like `set_thing()`
#   2. name its parameters - "Speed", not "arg0" and not the raw id
#   3. carry a description - one line saying what it does
#   4. avoid the words the sheet does not use about itself ("verb", "code card")
# and the pack's demo sheet must open with every line as a row and no Script blocks left.
#
# Publishing is never blocked: a pack that fails still publishes, and carries its score
# ("reads 94%") in the Addon manager until it passes. A check that stopped work would just be
# routed around.

## The words the sheet never uses about itself in anything a reader sees. `verb_*` identifiers are
## fine - this looks at DISPLAYED text only.
const FORBIDDEN_WORDS: Array[String] = ["verb", "verbs", "code card", "code cards"]

## Parameter names that name nothing. A pack that leaves these has not named its parameters.
const EMPTY_PARAM_NAMES: Array[String] = ["", "arg", "args", "param", "params", "value0", "p0"]


## Every problem with one published definition, each as
## {"ace": <display name>, "id": <ace id>, "problem": <what fails>, "fix": <what to do>}.
## An empty array means this one reads.
static func check_definition(definition: ACEDefinition) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	if definition == null:
		return problems
	var shown: String = str(definition.metadata.get("display_template", definition.display_name)).strip_edges()
	if shown.is_empty():
		shown = definition.display_name.strip_edges()
	var label: String = definition.display_name.strip_edges()
	if label.is_empty():
		label = definition.id
	if shown.is_empty() or _is_bare_call(shown):
		problems.append(_problem(definition, label,
			"the words a reader sees are a bare call, not a sentence",
			"give it @ace_name(\"Set thing to {value}\") - a sentence with its parameters in it"))
	if definition.description.strip_edges().is_empty():
		problems.append(_problem(definition, label,
			"it publishes no description",
			"give it @ace_description(\"…\") - one line saying what it does"))
	for parameter: Variant in definition.parameters:
		if not (parameter is Dictionary):
			continue
		var parameter_dict: Dictionary = parameter
		var parameter_id: String = str(parameter_dict.get("id", "")).strip_edges()
		var parameter_name: String = str(parameter_dict.get("display_name",
			parameter_dict.get("name", ""))).strip_edges()
		if _is_unnamed(parameter_name, parameter_id):
			problems.append(_problem(definition, label,
				"the parameter \"%s\" is not named" % (parameter_id if not parameter_id.is_empty() else parameter_name),
				"give it @ace_param(%s, \"Speed\", …) - the words the row shows beside the field" % parameter_id))
	var offending: String = _forbidden_word_in("%s %s %s" % [label, shown, definition.description])
	if not offending.is_empty():
		problems.append(_problem(definition, label,
			"it says \"%s\", which is not a word the sheet uses about itself" % offending,
			"say condition / action / expression / function instead"))
	return problems


## The whole verdict for a set of published definitions:
## {"total", "passed", "percent", "failures": Array[Dictionary]}.
## `percent` is floored, so one failing definition never rounds up to 100.
static func check_definitions(definitions: Array) -> Dictionary:
	var failures: Array[Dictionary] = []
	var total: int = 0
	var passed: int = 0
	for entry: Variant in definitions:
		if not (entry is ACEDefinition):
			continue
		total += 1
		var problems: Array[Dictionary] = check_definition(entry as ACEDefinition)
		if problems.is_empty():
			passed += 1
		else:
			failures.append_array(problems)
	var percent: int = 100 if total == 0 else int(floor(float(passed) * 100.0 / float(total)))
	if passed < total:
		percent = mini(percent, 99)
	return {"total": total, "passed": passed, "percent": percent, "failures": failures}


## The demo-sheet half: a pack's demo sheet must open with every line as a row and no Script
## blocks. Returns {"path", "percent", "block_rows", "failures"} - `path` is "" when the pack
## ships no demo sheet, which is itself a failure worth naming.
static func check_demo_sheet(sheet: EventSheetResource, sheet_path: String) -> Dictionary:
	var failures: Array[Dictionary] = []
	if sheet == null:
		return {"path": "", "percent": 0, "block_rows": 0, "failures": [{
			"ace": sheet_path.get_file(),
			"id": "",
			"problem": "the pack ships no demo sheet that opens",
			"fix": "add one sheet under the pack folder that shows the pack in use",
		}]}
	var coverage: Dictionary = EventSheetReadingCoverage.measure(sheet)
	var percent: int = int(coverage.get("percent", 0))
	var block_rows: int = int(coverage.get("block_rows", 0))
	if percent < 100 or block_rows > 0:
		failures.append({
			"ace": sheet_path.get_file(),
			"id": "",
			"problem": "the demo sheet reads %d%% with %d Script block%s left" % [
				percent, block_rows, "" if block_rows == 1 else "s"],
			"fix": "the lines still in a Script block have no row yet - use the pack's own actions for them, or publish the action they need",
		})
	return {"path": sheet_path, "percent": percent, "block_rows": block_rows, "failures": failures}


## The full verdict for a pack: its definitions plus its demo sheet, as one score and one list.
## `demo` may be an empty Dictionary when the caller has no demo sheet to hand.
static func combine(definition_result: Dictionary, demo_result: Dictionary) -> Dictionary:
	var failures: Array[Dictionary] = []
	failures.append_array(definition_result.get("failures", []))
	failures.append_array(demo_result.get("failures", []))
	var percent: int = int(definition_result.get("percent", 100))
	if not demo_result.is_empty():
		percent = mini(percent, int(demo_result.get("percent", 100)))
	if not failures.is_empty():
		percent = mini(percent, 99)
	return {
		"percent": percent,
		"total": int(definition_result.get("total", 0)),
		"passed": int(definition_result.get("passed", 0)),
		"failures": failures,
		"reads": failures.is_empty(),
	}


## Everything one pack script publishes, reflected the same way the picker reflects it. Empty
## when the script cannot be instantiated (an abstract base, a Resource host with no default).
static func definitions_for_script(script_path: String) -> Array[ACEDefinition]:
	var empty: Array[ACEDefinition] = []
	if script_path.strip_edges().is_empty() or not ResourceLoader.exists(script_path):
		return empty
	var resource: Resource = load(script_path)
	if not (resource is Script) or not (resource as Script).can_instantiate():
		return empty
	var instance: Variant = (resource as Script).new()
	if not (instance is Object):
		return empty
	var definitions: Array[ACEDefinition] = EventSheetACEGenerator.new().generate_from_object(instance as Object)
	# A pack is usually a Node, and `.new()` on one is not reference counted: without this every
	# check leaves an orphan behind, and a sweep over ninety packs leaks ninety of them.
	if instance is Node:
		(instance as Node).free()
	return definitions


## The whole verdict for one pack script: what it publishes, checked. The Publish dialog, the
## Doctor check and the shipped-pack gate all call THIS, so the three can never disagree.
##
## Cached on the file's own mtime + byte length, the same key the ACE registry uses: reflecting a
## pack means instantiating it and walking every member, and the Doctor asks about every installed
## pack on every run. The cache is what keeps that a once-per-change cost rather than a per-run one.
static func check_script(script_path: String) -> Dictionary:
	var key: String = "%s|%d|%d" % [script_path,
		FileAccess.get_modified_time(script_path), _file_length(script_path)]
	if _script_cache.has(key):
		return (_script_cache[key] as Dictionary).duplicate(true)
	var result: Dictionary = combine(check_definitions(definitions_for_script(script_path)), {})
	_script_cache[key] = result
	return result.duplicate(true)


static var _script_cache: Dictionary = {}


static func _file_length(script_path: String) -> int:
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return 0
	var length: int = file.get_length()
	file.close()
	return length


## The one line the Publish dialog and the Addon manager both show.
static func summary_text(result: Dictionary) -> String:
	if bool(result.get("reads", false)):
		return "Reads as sentences - every condition, action and expression, and the demo sheet."
	var failures: Array = result.get("failures", [])
	return "reads %d%% - %d thing%s to fix before this pack reads as the sheet promises." % [
		int(result.get("percent", 0)), failures.size(), "" if failures.size() == 1 else "s"]


## One failure, as the dialog lists it: "Set Thing: the template is a bare call - give it …".
static func failure_line(failure: Dictionary) -> String:
	return "%s: %s - %s" % [
		str(failure.get("ace", "")), str(failure.get("problem", "")), str(failure.get("fix", ""))]


static func _problem(definition: ACEDefinition, label: String, problem: String, fix: String) -> Dictionary:
	return {"ace": label, "id": definition.id, "problem": problem, "fix": fix}


## True when the shown words are a call rather than a sentence: `do_thing`, `do_thing()`,
## `node.do_thing({x})`. A sentence has a space between words that are not all one identifier.
static func _is_bare_call(shown: String) -> bool:
	var text: String = shown.strip_edges()
	if text.is_empty():
		return true
	# Strip the parameter placeholders first - "{value}" is not what makes it a sentence.
	var words: String = ""
	var depth: int = 0
	for index: int in text.length():
		var character: String = text[index]
		if character == "{":
			depth += 1
			continue
		if character == "}":
			depth = maxi(0, depth - 1)
			continue
		if depth == 0:
			words += character
	words = words.strip_edges()
	if words.is_empty():
		return true
	# One word IS a sentence for an expression ("Prefab", "Health"). What is not a sentence is one
	# word that still looks like code: a snake_case member, a dotted path, or a call's brackets.
	if words.contains(" "):
		return false
	return words.contains("_") or words.contains("(") or words.contains(".")


## True when a parameter's name says nothing a reader could not have guessed from its id.
static func _is_unnamed(parameter_name: String, parameter_id: String) -> bool:
	var name_text: String = parameter_name.strip_edges()
	if name_text.is_empty():
		return true
	if EMPTY_PARAM_NAMES.has(name_text.to_lower()):
		return true
	# "speed" for `speed` is the id repeated, not a name. "Speed" is - capitalisation is the pack
	# author saying this is what the row shows.
	return name_text == parameter_id and name_text == name_text.to_lower() and not name_text.contains(" ")


static func _forbidden_word_in(text: String) -> String:
	var lowered: String = " %s " % text.to_lower().replace("\n", " ")
	for word: String in FORBIDDEN_WORDS:
		for boundary: String in [" ", ".", ",", ":", ";", "!", "?", "\"", "'", ")"]:
			if lowered.contains(" %s%s" % [word, boundary]):
				return word
	return ""
