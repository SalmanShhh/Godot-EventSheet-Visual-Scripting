# Godot EventSheets - every shipped pack row compiles with the values it opens on.
#
# `builtin_ace_compile_test` asks this question of the BUILTIN vocabulary and answers it well, but
# it walks `EventForgeBuiltinACEs` only - so the 136 packs under `eventsheet_addons/`, which are
# where a dropdown of words and a hand-written call template actually live, were never asked. This
# file asks it of them, through the same seam the live picker uses: the addon scanner's script list,
# `EventSheetACEGenerator.generate_from_object`, the real `ActionCodegen._apply_template`, and
# `GDScript.reload()` on the result wrapped in a host class.
#
# THE VALUES A ROW OPENS ON, not values a test invented. A pack parameter's starting value is the
# `default:` segment its shipped annotation carries; a dropdown whose annotation carries none opens
# on its FIRST option, because that is what the params dialog's OptionButton shows (it selects an
# index only when an option key matches the default, and Godot selects item 0 otherwise). Filling a
# dropdown with anything else would test a row nobody can author.
#
# What this catches that nothing else did: a default that is a QUOTED STRING LITERAL on a BARE slot.
# Both annotation readers strip one surrounding pair of quotes off a `default:` value
# (`EventSheetSemanticAnalyzer._parse_param_spec` trims the prefix and suffix; the importer's
# `EventSheetACELifter._unquoted_once` does the same), so a builder writing `"enemies"` ships a row
# that opens on the bare word `enemies` and emits `Codex.discover(enemies, slime)` - an undefined
# identifier the game does not parse. Five builders hold such a default today and none of them
# reaches an emitted pack, because the emitter drops a default whose parameter carries no help
# (`SheetCompiler._param_annotation_lines` returns early on an empty description). The day one of
# those parameters gains its help sentence the default starts shipping, and this gate is what turns
# red instead of the game.
#
# THE PARSE ERRORS THIS PRINTS MID-SUITE ARE DELIBERATE. Every row on `KNOWN_FAILING` below is still
# compiled rather than skipped, so a row that starts compiling is reported as a stale line to delete
# instead of sitting on the list for ever - and Godot writes each of those failures to stderr on its
# way past. A run of this file that prints no engine parse errors at all is the surprising one.
@tool
class_name PackDefaultRowsCompileTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## Rows that do NOT compile with their shipped defaults, each with the cause. An entry here is a
## defect written down rather than hidden, and it is DELETED the day the cause is fixed - never
## added to make a red run green. Keyed `<pack file>/<ace id>`.
##
## The eighteen lines here are ONE defect wearing two faces, and neither face has a one-line fix.
##
## A starting value reaches an emitted pack as bare annotation text between `default: ` and the next
## `, `, and BOTH readers strip one surrounding pair of quotes off it. So a default cannot say
## whether it is a WORD (for a slot the template quotes) or a LITERAL (for a slot it does not):
##   - Juice and Juice 3D quote nothing, and their starting words `impact`, `hover`, `intro` and
##     `props` reach the call as undefined identifiers.
##   - Screen FX and Post Kit quote the slot, and the reflected `called: String = ""` reaches the
##     call as the source text `""` inside those quotes, which is four quote characters.
## Quoting the slot in the first group would change a SHIPPED `codegen_template`, which is frozen;
## quoting the default in either group is undone by the readers. The fix is a spelling a default can
## carry through the round trip, which is a change to the emitter and both readers together, so it is
## written down here rather than smuggled into a pass about something else.
const KNOWN_FAILING: Dictionary = {
	"screen_fx.gd/method:add_post_effect": "the reflected `called: String = \"\"` lands inside the template's own quotes",
	"screen_fx.gd/method:move_post_effect_before": "the reflected `before: String = \"\"` lands inside the template's own quotes",
	"post_kit_behavior.gd/method:add_post_effect": "the reflected `called: String = \"\"` lands inside the template's own quotes"
}

## Rows whose template is correct GDScript but only compiles inside a context this standalone
## harness deliberately does not build - the same honest-coverage list `builtin_ace_compile_test`
## keeps, for the same reason. Keyed `<pack file>/<ace id>`, with the reason.
const NOT_STANDALONE: Dictionary = {
	# The documentation demo, whose whole subject is what an @ace_codegen_template may name: both of
	# its templates address `health`, a member of the SHEET that uses the demo. This harness wraps one
	# host class by hand and declares no sheet members, so the two rows cannot be tested here without
	# inventing the very thing they are demonstrating.
	"demo_health_addon.gd/method:heal": "the template names `health`, a member the using sheet declares",
	"demo_health_addon.gd/method:is_hurt": "the template names `health`, a member the using sheet declares"
}

## The scaffold members a pack row may name that a bare host class does not have. Declared untyped
## so any member access parses, exactly as `builtin_ace_compile_test` declares its own.
const SCAFFOLD_MEMBERS: Array[String] = ["v", "item", "loop_index", "event", "text", "data", "delta"]


static func run() -> bool:
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	var packs_walked: Dictionary = {}
	var checked: int = 0
	var skipped: Array[String] = []
	var known_bad: Array[String] = []
	var not_standalone_seen: Array[String] = []
	var failures: Array[String] = []

	for script_path: String in scripts:
		var script: Script = load(script_path) as Script
		if script == null or not script.can_instantiate():
			continue
		var instance: Object = script.new()
		if instance == null:
			continue
		var pack_file: String = script_path.get_file()
		for definition: ACEDefinition in generator.generate_from_object(instance):
			if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
				continue
			var template: String = str(definition.metadata.get("codegen_template", "")).strip_edges()
			if template.is_empty():
				template = definition.instance_backed_template().strip_edges()
			if template.is_empty():
				continue
			packs_walked[pack_file] = true
			var key: String = "%s/%s" % [pack_file, definition.id]
			if NOT_STANDALONE.has(key):
				not_standalone_seen.append("%s (%s)" % [key, str(NOT_STANDALONE[key])])
				continue
			var fill: Dictionary = _fill_params(definition, template)
			if fill.get("skip", false):
				skipped.append("%s (%s)" % [key, str(fill.get("reason", ""))])
				continue
			checked += 1
			var failure: String = _compile_failure(definition, template, fill["params"])
			if KNOWN_FAILING.has(key):
				known_bad.append("%s (%s)" % [key, str(KNOWN_FAILING[key])])
				if failure.is_empty():
					failures.append("%s is on KNOWN_FAILING but COMPILES - delete its line" % key)
				continue
			if not failure.is_empty():
				failures.append(failure)
		if instance is Node:
			(instance as Node).free()

	for f: String in failures:
		print("[FAIL] pack_default_rows_compile_test: %s" % f)
	print("[INFO] pack_default_rows_compile_test: %d packs walked, %d rows compiled with their shipped defaults, %d skipped, %d failed" % [
		packs_walked.size(), checked, skipped.size(), failures.size()])
	if not known_bad.is_empty():
		print("[INFO] pack_default_rows_compile_test: rows that do NOT compile, written down with their cause: %s" % ", ".join(known_bad))
	if not skipped.is_empty():
		print("[INFO] pack_default_rows_compile_test: skipped (a bare placeholder with no compilable stand-in): %s" % ", ".join(skipped))

	var ok: bool = _check("every shipped pack row compiles with the values it opens on", failures.is_empty(), true)
	# The walk itself is pinned, so a scanner change that quietly stops finding packs cannot turn
	# this gate into a vacuous pass. Pinned as a floor rather than an exact count, because a pack
	# lands here every week and the number is not the contract - walking the whole fleet is.
	ok = _check("the gate walks the whole shipped fleet", packs_walked.size() >= 100, true) and ok
	ok = _check("the gate compiles thousands of rows, not a handful", checked >= 3000, true) and ok
	# The detector self-check: a default that is a quoted string literal on a BARE slot must FAIL,
	# so the round-trip trip-wire this file exists for can never become a vacuous pass.
	ok = _check("a quoted-literal default on a bare slot is caught", _quoted_default_probe(), false) and ok
	return ok


## Compiles `Codex.discover(enemies, slime)` - what a `default: "enemies"` becomes once either
## annotation reader has stripped its outer quotes. False is the answer this file is named for.
static func _quoted_default_probe() -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Node\nvar Codex\nfunc __t() -> void:\n\tCodex.discover(enemies, slime)\n"
	return script.reload() == OK


## One compile of one filled template, as the message naming what went wrong - "" when it built.
static func _compile_failure(definition: ACEDefinition, template: String, params: Dictionary) -> String:
	var source: String = _wrap(definition, template, params)
	var script: GDScript = GDScript.new()
	script.source_code = source
	var err: int = script.reload()
	if err == OK:
		return ""
	return "%s/%s [%s] -> %s\n----\n%s\n----" % [
		definition.provider_id, definition.id, _type_name(definition.ace_type),
		error_string(err), source]


## The values the row opens on, as the params dict `_apply_template` substitutes.
##
## A dropdown answers first: its shipped `default:` when that names one of its own options, and
## otherwise its FIRST option, which is the item the params dialog's OptionButton shows. Then an
## optional slot (`{id.}` / `{, id}`), which drops cleanly whether the default is a value or blank.
## Then a plain default, used verbatim. Then a literal of the parameter's declared type. A parameter
## with none of those is a bare placeholder the author must fill, and the row is REPORTED as skipped
## rather than compiled against a value nobody would type.
static func _fill_params(definition: ACEDefinition, template: String) -> Dictionary:
	var params: Dictionary = {}
	for entry: Variant in definition.parameters:
		if not (entry is Dictionary):
			continue
		var parameter: Dictionary = entry
		var id: String = str(parameter.get("id", ""))
		if id.is_empty():
			continue
		var default_value: String = str(parameter.get("default_value", "")).strip_edges()
		var options: Array = parameter.get("options", []) as Array
		if not options.is_empty():
			params[id] = _option_fill(options, default_value)
			continue
		if template.contains("{%s.}" % id) or template.contains("{, %s}" % id):
			params[id] = default_value
			continue
		if not default_value.is_empty():
			params[id] = default_value
			continue
		# No starting value at all, so the harness supplies one - and WHICH one depends on the slot.
		# A template that already quotes the slot (`"{after_label}"`) is asking for the word an
		# author types into a plain field, not for a GDScript literal; filling that with `"x"` would
		# double the quotes and fail a row that is perfectly correct.
		var typed: String = _value_for_type(int(parameter.get("type", TYPE_NIL)), template.contains("\"{%s}\"" % id))
		if not typed.is_empty():
			params[id] = typed
			continue
		if str(parameter.get("hint", "")) == "expression":
			params[id] = "0"
			continue
		return {"skip": true, "reason": "bare placeholder for '%s'" % id}
	params["uid"] = "0"
	return {"params": params}


## The dropdown value a freshly dropped row carries: the shipped default when it names one of the
## options, and otherwise the FIRST option's key.
##
## A default naming no option cannot be what the row shows. `ACEParamsDialog._create_options_field`
## selects an index only when an option's key equals the default, so a default matching none leaves
## the OptionButton on the item Godot selected when it was added - item 0 - and item 0's key is what
## the dialog hands back. Is At Bound is the live example: its `side` default is the METHOD's own
## `= "any"`, quotes and all, which equals none of its five bare keys, so the row really does open
## on `left`.
static func _option_fill(options: Array, default_value: String) -> String:
	var first: String = ""
	for option: Variant in options:
		var option_key: String = str((option as Dictionary).get("key", "")) if option is Dictionary else str(option)
		if first.is_empty():
			first = option_key
		if option_key == default_value:
			return option_key
	return first


## Wraps the substituted template in a host class so the call parses.
##
## Packs reach their code two ways and both are honoured. A BEHAVIOUR pack writes `$SomeBehavior.x()`
## - `$` answers `Node`, so any member access on it parses without help. An AUTOLOAD pack writes its
## own singleton's name, `Storylets.x()`, and that identifier exists in a real project because the
## pack registers the autoload; here it is declared as an untyped member, which is the smallest thing
## that makes the same line parse. Only a capitalised identifier used as the base of a `.` access is
## declared, and only when it is neither an engine class nor a project `class_name` - so `Input`,
## `Time` and a pack's own `class_name` still resolve to the real thing.
static func _wrap(definition: ACEDefinition, template: String, params: Dictionary) -> String:
	var line: String = ActionCodegen._apply_template(template, params)
	var host: String = str(definition.metadata.get("node_type", "")).strip_edges()
	if host.is_empty() or not ClassDB.class_exists(host):
		host = "Node"
	var body_lines: Array[String] = []
	match definition.ace_type:
		ACEDefinition.ACEType.CONDITION:
			body_lines = ["if (%s):" % line, "\tpass"]
		ACEDefinition.ACEType.EXPRESSION:
			for statement: String in ("var __e = (%s)" % line).split("\n"):
				body_lines.append(statement)
			body_lines.append("__sink(__e)")
		_:
			for statement: String in line.split("\n"):
				body_lines.append(statement)
	var body: String = ""
	for body_line: String in body_lines:
		body += "\t" + body_line + "\n"
	var scaffold: String = ""
	for member: String in SCAFFOLD_MEMBERS:
		if not _host_has_member(host, member):
			scaffold += ("var %s := 0.0\n" % member) if member == "delta" else ("var %s\n" % member)
	if not _host_has_member(host, "sig"):
		scaffold += "signal sig\n"
	for singleton: String in _undeclared_singletons(line, host):
		scaffold += "var %s\n" % singleton
	scaffold += "func __sink(_a: Variant) -> void:\n\tpass\n"
	return "@tool\nextends %s\n%sfunc __t() -> void:\n%s" % [host, scaffold, body]


## The prefix the compiler gives the member it declares for an instance-backed reflected method.
## A pack that publishes a plain method with no template of its own bakes to
## `__eventsheet_provider_<Class>.method(...)`, and the member is written into the sheet's own file
## the first time such a row appears - so it is a real declaration in a real project, and the
## smallest honest stand-in here is a member of the same name.
const PROVIDER_MEMBER_PREFIX: String = "__eventsheet_provider_"


## The identifiers `line` calls into that nothing else in this file would declare, as the two shapes
## a pack row can name: its own AUTOLOAD (a capitalised identifier, which exists in a real project
## because the pack registers it) and the compiler-injected provider member above. An engine class, a
## project `class_name`, a host member and a scaffold name are all left alone so the line keeps
## resolving against the real thing - which is what lets a typo in a template still fail this gate.
static func _undeclared_singletons(line: String, host: String) -> Array[String]:
	var found: Array[String] = []
	var expression: RegEx = RegEx.create_from_string(
		"(?:^|[^A-Za-z0-9_.\"'])((?:%s|[A-Z])[A-Za-z0-9_]*)\\s*\\." % PROVIDER_MEMBER_PREFIX)
	for match_result: RegExMatch in expression.search_all(line):
		var name: String = match_result.get_string(1)
		if found.has(name) or SCAFFOLD_MEMBERS.has(name):
			continue
		if ClassDB.class_exists(name) or _is_builtin_type(name) or _is_global_class(name):
			continue
		if _host_has_member(host, name):
			continue
		found.append(name)
	return found


static var _builtin_type_names: Dictionary = {}


## True when `name` is one of Variant's own type names - `Color`, `Vector2`, `Callable`. They are not
## ClassDB classes, so without this the scaffold declared `var Color` over the built-in type and
## every row ending in `Color.WHITE` failed on the stand-in rather than on its own template.
static func _is_builtin_type(name: String) -> bool:
	if _builtin_type_names.is_empty():
		for type_id: int in range(TYPE_MAX):
			_builtin_type_names[type_string(type_id)] = true
	return _builtin_type_names.has(name)


static var _global_class_names: Dictionary = {}


## True when `name` is a project-wide `class_name`. Read once from the global class list, because a
## per-row walk of it over four thousand rows is the whole runtime of this gate.
static func _is_global_class(name: String) -> bool:
	if _global_class_names.is_empty():
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			_global_class_names[str(entry.get("class", ""))] = true
	return _global_class_names.has(name)


static var _member_cache: Dictionary = {}


## True when the host class (incl. inherited members) already exposes a property or method with this
## name, so the scaffold can skip declaring a colliding stand-in (e.g. Label.text).
static func _host_has_member(host: String, member: String) -> bool:
	var cache_key: String = "%s.%s" % [host, member]
	if _member_cache.has(cache_key):
		return bool(_member_cache[cache_key])
	var answer: bool = false
	if ClassDB.class_exists(host):
		if ClassDB.class_has_method(host, member):
			answer = true
		else:
			for property: Dictionary in ClassDB.class_get_property_list(host):
				if str(property.get("name", "")) == member:
					answer = true
					break
	_member_cache[cache_key] = answer
	return answer


## A compilable literal of the given declared type, or "" when there is no obvious stand-in.
## `slot_is_quoted` says the template wraps this parameter's slot in quotes of its own, so a string
## goes in as the bare word a plain field holds rather than as a literal that would double them.
static func _value_for_type(type_id: int, slot_is_quoted: bool = false) -> String:
	match type_id:
		TYPE_STRING, TYPE_STRING_NAME: return "x" if slot_is_quoted else "\"x\""
		TYPE_INT: return "0"
		TYPE_FLOAT: return "0.0"
		TYPE_BOOL: return "true"
		TYPE_ARRAY: return "[]"
		TYPE_DICTIONARY: return "{}"
		TYPE_VECTOR2: return "Vector2(0, 0)"
		TYPE_VECTOR2I: return "Vector2i(0, 0)"
		TYPE_VECTOR3: return "Vector3(0, 0, 0)"
		TYPE_VECTOR3I: return "Vector3i(0, 0, 0)"
		TYPE_COLOR: return "Color.WHITE"
	return ""


static func _type_name(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION: return "CONDITION"
		ACEDefinition.ACEType.EXPRESSION: return "EXPRESSION"
		ACEDefinition.ACEType.ACTION: return "ACTION"
		ACEDefinition.ACEType.TRIGGER: return "TRIGGER"
	return "?"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("pack_default_rows_compile_test", label, actual, expected)
