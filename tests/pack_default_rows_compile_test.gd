# Godot EventSheets - every shipped pack row compiles with the values it opens on.
#
# `builtin_ace_compile_test` asks this question of the BUILTIN vocabulary and answers it well, but
# it walks `EventForgeBuiltinACEs` only - so the packs under `eventsheet_addons/`, which are
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
# AND THEN EVERY OTHER WORD IN THE DROPDOWN. A dropdown is a promise that each of its items writes
# code the game builds, and the item nobody picked while authoring is the one whose spelling was
# never tried. `builtin_ace_compile_test` asks this of the builtin vocabulary; the walk below asks it
# of the packs, through the same fill, so the two passes can never test a row differently.
#
# NOTHING LEAVES THE WALK IN SILENCE. A script the scanner hands over is walked, or named as a
# runtime helper that publishes no row, or named as one that would not load - and the three are
# pinned to add up to what the scanner handed over, because a pack with a parse error otherwise
# looks exactly like a fleet that is one pack smaller. The autoload stand-ins the harness declares
# to make a line parse are checked against the autoload the pack's own BUILDER registers, so a typo
# in a template is caught by a file the template cannot edit.
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
# THE PARSE ERRORS THIS PRINTS MID-SUITE ARE DELIBERATE. The detector self-check at the bottom
# compiles `Codex.discover(enemies)` on purpose - half of a pair whose other half, with the word
# quoted, must build - and Godot writes that failure to stderr on its way past. So does every row on
# `KNOWN_FAILING` below, which is compiled rather than skipped so
# that a row which starts compiling is reported as a stale line to delete instead of sitting on the
# list for ever. The list is empty today, so the probe's own error is the only one a green run
# writes - a `Parse Error` naming `Codex` mid-suite is this file working, not this file failing.
@tool
class_name PackDefaultRowsCompileTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## Rows that do NOT compile with their shipped defaults, each with the cause. An entry here is a
## defect written down rather than hidden, and it is DELETED the day the cause is fixed - never
## added to make a red run green. Keyed `<pack file>/<ace id>`.
##
## It is EMPTY, and staying empty is the point: a row a beginner drops has to parse, because a sheet
## that looks right over a game that does not build is the worst way to learn that something is
## wrong. The eighteen lines that stood here were one defect wearing two faces, and both faces were
## answered by the fleet's own law rather than by a new spelling:
##   - Juice and Juice 3D took a word - `impact`, `hover`, `intro`, `props` - through an UNQUOTED
##     slot, so the starting word reached the call as an undefined identifier. The templates now
##     carry the quotes, the way every other pack offering a word already does, and the starting
##     value stays the bare word an author types.
##   - Screen FX and Post Kit quote their slot correctly, but three parameters carried no starting
##     value of their own, so the reflected `called: String = ""` fell through as the SOURCE TEXT of
##     an empty literal and landed inside the template's quotes as four quote characters. Each now
##     names the word its row opens on.
## A default still cannot say whether it is a WORD or a LITERAL - both readers strip one surrounding
## pair of quotes off it - so the answer for a word-shaped parameter is always the same: quote the
## slot in the template, and let the default be the word.
const KNOWN_FAILING: Dictionary = {
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

## The addon scripts the scanner hands over that publish no templated row at all, by file name.
##
## They are RUNTIME HELPERS, not vocabulary: a post-processing effect a pack instances, the shape
## resource a drawing node holds, the moment runner the feedback player drives. Each loads and
## instantiates cleanly and simply has nothing to say to the picker, which is a different thing from
## a pack that failed to load - and telling the two apart is the point of pinning them. A pack with a
## parse error drops out of the walk with no row of its own, and without this list the floors below
## would absorb the loss silently.
##
## A name joins this list only when the script genuinely publishes no vocabulary. A PACK appearing
## here is a pack that stopped compiling.
const NO_TEMPLATED_ROWS: Array[String] = [
	"bus_mix.gd", "free_spot.gd", "haptics.gd", "loading_screen.gd", "moment_runner.gd",
	"pooled_nodes.gd", "post_desaturate.gd", "post_effect.gd", "post_fade.gd", "post_outline.gd",
	"post_pixelate.gd", "post_tint.gd", "post_vignette.gd", "shape_sphere_3d.gd", "shape_style.gd",
	"world_look.gd"
]

## The fleet as it stands, measured by the walk below and written down so a shrink is a failure
## rather than a quieter run. Both are FLOORS at the measured figure: a pack that lands next week
## raises them and its own commit re-measures the line, but nothing may ever lower them, which is the
## direction a scanner regression or a pack that stopped loading would move.
##
## PROVIDER SCRIPTS, not packs. The scanner hands over one entry per script that publishes
## vocabulary, and a pack ships several - the shapes pack alone publishes its 2D node, its 3D node
## and its style resource. The fleet's pack count is a different measurement with a tool of its own
## (`tools/measure_packs.gd`), and reading this number as that one is how the records came to claim
## a fleet size the fleet never had.
const PROVIDER_SCRIPTS_WALKED: int = 163
const ROWS_COMPILED: int = 4016
const DROPDOWN_CHOICES_COMPILED: int = 301


static func run() -> bool:
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	var scripts_walked: Dictionary = {}
	var checked: int = 0
	var options_checked: int = 0
	var skipped: Array[String] = []
	var skipped_unloadable: Array[String] = []
	var quiet_scripts: Array[String] = []
	var known_bad: Array[String] = []
	var known_failing_seen: Dictionary = {}
	var not_standalone_seen: Dictionary = {}
	var declared_bases: Dictionary = {}
	var failures: Array[String] = []

	for script_path: String in scripts:
		var pack_file: String = script_path.get_file()
		# A script that will not load is NAMED, never skipped in silence. It is the shape a pack with
		# a parse error takes, and absorbing it into the floors above would report the fleet as whole
		# while a pack of it had quietly stopped existing.
		var script: Script = load(script_path) as Script
		if script == null:
			skipped_unloadable.append("%s (load returned null)" % pack_file)
			continue
		if not script.can_instantiate():
			skipped_unloadable.append("%s (cannot instantiate)" % pack_file)
			continue
		var instance: Object = script.new()
		if instance == null:
			skipped_unloadable.append("%s (new() returned null)" % pack_file)
			continue
		for definition: ACEDefinition in generator.generate_from_object(instance):
			if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
				continue
			var template: String = str(definition.metadata.get("codegen_template", "")).strip_edges()
			if template.is_empty():
				template = definition.instance_backed_template().strip_edges()
			if template.is_empty():
				continue
			scripts_walked[pack_file] = true
			var key: String = "%s/%s" % [pack_file, definition.id]
			if NOT_STANDALONE.has(key):
				not_standalone_seen[key] = true
				continue
			var fill: Dictionary = _fill_params(definition, template)
			if fill.get("skip", false):
				skipped.append("%s (%s)" % [key, str(fill.get("reason", ""))])
				# The ROW is not compiled - it has a slot only the author can fill, and compiling it
				# against an invented value would report on a row nobody drops. Its DROPDOWNS are a
				# different question, and one this gate must still ask: thirteen of the fleet's word
				# lists live on such a row, Follow Path's mode and Declare Setting's kind among them.
				# So the bare slot takes the scaffold's own untyped `v` - a value that says nothing
				# about the row and lets every word in the list be tried.
				for variant: Dictionary in _option_variants(definition, _stand_in_fill(definition, template)):
					options_checked += 1
					var stand_in_failure: String = _compile_failure(definition, template, variant["params"])
					if not stand_in_failure.is_empty():
						failures.append("with %s = %s: %s" % [
							str(variant["param"]), str(variant["value"]), stand_in_failure])
				continue
			checked += 1
			var params: Dictionary = fill["params"]
			for base: String in _undeclared_singletons(
					ActionCodegen._apply_template(template, params), HOST_CLASS):
				declared_bases["%s\t%s" % [base, definition.provider_id]] = true
			var failure: String = _compile_failure(definition, template, params)
			if KNOWN_FAILING.has(key):
				known_failing_seen[key] = true
				known_bad.append("%s (%s)" % [key, str(KNOWN_FAILING[key])])
				if failure.is_empty():
					failures.append("%s is on KNOWN_FAILING but COMPILES - delete its line" % key)
				continue
			if not failure.is_empty():
				failures.append(failure)
			# EVERY WORD IN THE DROPDOWN, not only the one the row opens on. A dropdown is a promise
			# that each of its items writes code the game builds, and the item nobody picked while
			# authoring is exactly the one whose spelling was never tried. `builtin_ace_compile_test`
			# asks this of the builtin vocabulary; this asks it of the packs, through the same fill.
			for variant: Dictionary in _option_variants(definition, params):
				options_checked += 1
				for base: String in _undeclared_singletons(
						ActionCodegen._apply_template(template, variant["params"]), HOST_CLASS):
					declared_bases["%s	%s" % [base, definition.provider_id]] = true
				var option_failure: String = _compile_failure(definition, template, variant["params"])
				if not option_failure.is_empty():
					failures.append("with %s = %s: %s" % [
						str(variant["param"]), str(variant["value"]), option_failure])
		if not scripts_walked.has(pack_file):
			quiet_scripts.append(pack_file)
		if instance is Node:
			(instance as Node).free()

	for f: String in failures:
		print("[FAIL] pack_default_rows_compile_test: %s" % f)
	print("[INFO] pack_default_rows_compile_test: %d provider scripts walked, %d rows compiled with their shipped defaults, %d further dropdown choices compiled, %d skipped, %d failed" % [
		scripts_walked.size(), checked, options_checked, skipped.size(), failures.size()])
	if not known_bad.is_empty():
		print("[INFO] pack_default_rows_compile_test: rows that do NOT compile, written down with their cause: %s" % ", ".join(known_bad))
	if not skipped.is_empty():
		print("[INFO] pack_default_rows_compile_test: skipped (a bare placeholder with no compilable stand-in): %s" % ", ".join(skipped))

	var ok: bool = _check("every shipped pack row compiles with the values it opens on", failures.is_empty(), true)
	# The walk itself is pinned, so a scanner change that quietly stops finding packs cannot turn
	# this gate into a vacuous pass.
	ok = _check("the gate walks the whole shipped fleet", scripts_walked.size() >= PROVIDER_SCRIPTS_WALKED, true) and ok
	ok = _check("the gate compiles every shipped row", checked >= ROWS_COMPILED, true) and ok
	ok = _check("the gate compiles the other words in every dropdown",
		options_checked >= DROPDOWN_CHOICES_COMPILED, true) and ok
	# Nothing the scanner handed over went missing between the two. Derived rather than counted, so
	# it stays true as packs land and false the moment a script leaves the walk unaccounted for.
	ok = _check("every scanned script is either walked or named",
		scripts_walked.size() + quiet_scripts.size() + skipped_unloadable.size(), scripts.size()) and ok
	ok = _check("no addon script failed to load", "\n".join(skipped_unloadable), "") and ok
	quiet_scripts.sort()
	var expected_quiet: Array[String] = NO_TEMPLATED_ROWS.duplicate()
	expected_quiet.sort()
	ok = _check("the scripts that publish no templated row are the known runtime helpers",
		"\n".join(quiet_scripts), "\n".join(expected_quiet)) and ok
	# A line on either table that no row ever reached is a line describing a row that has moved or
	# gone. The staleness check above only fires when a KNOWN_FAILING row COMPILES, so a key nothing
	# visits would sit there for ever unread.
	ok = _check("every KNOWN_FAILING line names a row the walk reached",
		_unvisited(KNOWN_FAILING, known_failing_seen), "") and ok
	ok = _check("every NOT_STANDALONE line names a row the walk reached",
		_unvisited(NOT_STANDALONE, not_standalone_seen), "") and ok
	ok = _check("every autoload the scaffold stands in for is one a pack builder declares",
		_unknown_bases(declared_bases), "") and ok
	# The detector self-check: a default that is a quoted string literal on a BARE slot must FAIL,
	# so the round-trip trip-wire this file exists for can never become a vacuous pass.
	ok = _check("a bare-word default on a bare slot fails, a quoted one builds",
		_quoted_default_probe(), {"bare": false, "quoted": true}) and ok
	return ok


## The keys of `table` that `seen` never recorded, newline-joined - "" when the table is current.
static func _unvisited(table: Dictionary, seen: Dictionary) -> String:
	var stale: Array[String] = []
	for key: Variant in table.keys():
		if not seen.has(str(key)):
			stale.append("%s (nothing in the walk reached this row)" % str(key))
	stale.sort()
	return "\n".join(stale)


## Whether the harness still catches the defect this file is named for, asked THROUGH THE HARNESS,
## as the pair {bare, quoted}: a bare word default must NOT compile and a quoted one must.
##
## A synthetic definition with one bare `{target}` slot defaulting to the word `enemies` - what
## `default: "enemies"` becomes once either annotation reader has stripped its outer quotes - is put
## through the same `_fill_params` and `_compile_failure` every shipped row goes through. A
## hand-typed source string would have proved only that Godot rejects bad GDScript; this proves that
## THIS harness's fill and wrap still carry such a row to a failure.
##
## The template names ONE slot and nothing else undefined, and the second half of the pair is a
## POSITIVE CONTROL on the same definition. Between them they pin the DIFFERENCE the quotes make,
## which is the only thing this probe is for: with a second bare identifier in the line, or with no
## control, a fill that started quoting every word - the exact regression guarded against - would
## still have produced a parse error and left the gate green.
static func _quoted_default_probe() -> Dictionary:
	return {
		"bare": _probe_compiles("enemies"),
		"quoted": _probe_compiles("\"enemies\"")
	}


## Whether one synthetic row carrying `default_text` on a bare slot compiles, through the fill and
## the wrap every shipped row uses.
static func _probe_compiles(default_text: String) -> bool:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "PackDefaultRowsProbe"
	definition.id = "method:probe"
	definition.ace_type = ACEDefinition.ACEType.ACTION
	definition.parameters = [{"id": "target", "type": TYPE_STRING, "default_value": default_text}]
	var template: String = "Codex.discover({target})"
	var fill: Dictionary = _fill_params(definition, template)
	if fill.get("skip", false):
		return false     # the probe never reached a compile, which the pinned pair reports as such
	return _compile_failure(definition, template, fill["params"]).is_empty()


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
static func _fill_params(definition: ACEDefinition, template: String,
		stand_in_for_placeholders: bool = false) -> Dictionary:
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
		if not stand_in_for_placeholders:
			return {"skip": true, "reason": "bare placeholder for '%s'" % id}
		params[id] = "v"
	params["uid"] = "0"
	return {"params": params}


## The same fill, but with every bare placeholder standing in as the scaffold's untyped `v`.
##
## Used for ONE question only: the other words in a dropdown that happens to sit on a row carrying a
## slot the author must fill. `v` is a value nobody would type, which is exactly why the row itself
## is never compiled against it - but a word list is a promise about the WORDS, and the promise
## holds whatever the row's other slots end up holding.
static func _stand_in_fill(definition: ACEDefinition, template: String) -> Dictionary:
	var fill: Dictionary = _fill_params(definition, template, true)
	return fill.get("params", {}) as Dictionary


## The dropdown value a freshly dropped row carries: the shipped default when it names one of the
## options, and otherwise the FIRST option's key.
##
## A default naming no option cannot be what the row shows. `ACEParamsDialog._create_options_field`
## selects an index only when an option's key equals the default, so a default matching none leaves
## the OptionButton on the item Godot selected when it was added - item 0 - and item 0's key is what
## the dialog hands back. Is At Bound is the live example: its `side` default is the METHOD's own
## `= "any"`, quotes and all, which equals none of its five bare keys, so the row really does open
## on `left`.
##
## `has_first` rather than an empty-string test, because a BLANK first option is a real thing a pack
## ships - "no filter", "keep the current one" - and an OptionButton showing it is showing item 0
## exactly as this function must report. Testing `first.is_empty()` would have walked straight past
## the blank and named the SECOND option as the value the row opens on, which is a row nobody sees.
static func _option_fill(options: Array, default_value: String) -> String:
	var first: String = ""
	var has_first: bool = false
	for option: Variant in options:
		var option_key: String = str((option as Dictionary).get("key", "")) if option is Dictionary else str(option)
		if not has_first:
			first = option_key
			has_first = true
		if option_key == default_value:
			return option_key
	return first


## Every OTHER word in every dropdown this row has, as {param, value, params}. The word the row opens
## on is left out (it was just compiled), and a list of one is no choice at all.
static func _option_variants(definition: ACEDefinition, filled: Dictionary) -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	for entry: Variant in definition.parameters:
		if not (entry is Dictionary):
			continue
		var parameter: Dictionary = entry
		var id: String = str(parameter.get("id", ""))
		var options: Array = parameter.get("options", []) as Array
		if id.is_empty() or options.size() < 2:
			continue
		for option: Variant in options:
			var value: String = str((option as Dictionary).get("key", "")) if option is Dictionary else str(option)
			if value == str(filled.get(id, "")):
				continue
			var params: Dictionary = filled.duplicate()
			params[id] = value
			variants.append({"param": id, "value": value, "params": params})
	return variants


## The class every pack row is compiled inside. ALWAYS `Node`, and there is no second answer to look
## for: `node_type` is written into an ACE's metadata only by `ace_adapter.gd`, which adapts a
## BUILTIN descriptor, and never by `generate_from_object`, which is the only door a pack comes
## through here. A pack narrows its host with `@ace_expose_all(node)` instead, and honouring that
## would mean compiling each row inside the node class the pack attaches to - worth doing the day a
## row needs it, and dishonest to pretend is happening while nothing sets the key.
const HOST_CLASS: String = "Node"


## Wraps the substituted template in a host class so the call parses.
##
## Packs reach their code two ways and both are honoured. A BEHAVIOUR pack writes `$SomeBehavior.x()`
## - `$` answers `Node`, so any member access on it parses without help. An AUTOLOAD pack writes its
## own singleton's name, `Storylets.x()`, and that identifier exists in a real project because the
## pack registers the autoload; here it is declared as an untyped member, which is the smallest thing
## that makes the same line parse. Only a capitalised identifier used as the base of a `.` access is
## declared, and only when it is neither an engine class nor a project `class_name` - so `Input`,
## `Time` and a pack's own `class_name` still resolve to the real thing.
##
## A stand-in makes ANY capitalised base parse, so on its own it would let `Storylet.add_requirement`
## - one letter short of the autoload the pack registers - sail through green. The base is therefore
## not trusted: every name this function declares is checked afterwards against the autoload the
## pack's own BUILDER declares, which is a different file from the template being tested, so a typo
## in one is caught by the other.
static func _wrap(definition: ACEDefinition, template: String, params: Dictionary) -> String:
	var line: String = ActionCodegen._apply_template(template, params)
	var host: String = HOST_CLASS
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


## Where the pack builders live. The autoload a pack registers is DECLARED here and nowhere in the
## shipped tree: the compiler spends `autoload_name` on the call prefix of each
## `@ace_codegen_template` and emits no marker of its own (an opened pack recovers the name from
## `project.godot` instead). So the builder is the one independent spelling - checking a template's
## prefix against another template's prefix would only prove the typo is consistent with itself.
const PACK_BUILDERS_DIR: String = "res://tools/pack_builders"


## The stand-ins the scaffold declared that nothing outside the template accounts for, newline-joined
## - "" when every one is real. Keys arrive as "<base>\t<provider id>". Two shapes, each answered by
## its own source:
##   - a capitalised base is an AUTOLOAD, and must be one a pack BUILDER registers by that exact
##     spelling. The builder is a different file from the template being tested, so `Storylet.` for
##     `Storylets.` is named here instead of parsing green against a stand-in that would accept it.
##   - `__eventsheet_provider_<Provider>` is the member the compiler writes into the sheet for an
##     instance-backed row, and `<Provider>` must be the provider whose row this is. A template that
##     names another pack's provider member addresses a member that sheet never declares.
static func _unknown_bases(declared_bases: Dictionary) -> String:
	var autoloads: Dictionary = _builder_autoload_names()
	var unknown: Array[String] = []
	for entry: String in declared_bases.keys():
		var base: String = entry.get_slice("\t", 0)
		var provider_id: String = entry.get_slice("\t", 1)
		if base.begins_with(PROVIDER_MEMBER_PREFIX):
			var named: String = base.trim_prefix(PROVIDER_MEMBER_PREFIX)
			if named != provider_id:
				unknown.append("%s (names provider '%s', but the row is %s's)" % [base, named, provider_id])
			continue
		if not autoloads.has(base):
			unknown.append("%s (no pack builder registers an autoload by this name, in a %s row)" % [
				base, provider_id])
	unknown.sort()
	return "\n".join(unknown)


## Every autoload name the pack builders register, as a set. Two dialects are in use and both are
## read: the manifest form `Lib.manifest().autoload("Storylets")` and the direct form
## `sheet.autoload_name = "Storylets"`. A blank name is the library's own field default, not a pack.
static func _builder_autoload_names() -> Dictionary:
	var names: Dictionary = {}
	var expression: RegEx = RegEx.create_from_string(
		"autoload(?:_name)?\\s*(?:\\(|=)\\s*\"([A-Za-z_][A-Za-z0-9_]*)\"")
	var builders: DirAccess = DirAccess.open(PACK_BUILDERS_DIR)
	if builders == null:
		return names
	for file_name: String in builders.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var source: String = FileAccess.get_file_as_string("%s/%s" % [PACK_BUILDERS_DIR, file_name])
		for match_result: RegExMatch in expression.search_all(source):
			names[match_result.get_string(1)] = true
	return names


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
