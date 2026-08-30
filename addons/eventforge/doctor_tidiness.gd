# Godot EventSheets - the Doctor's tidiness sweep
#
# The rest of the Doctor asks "is this sheet WRONG". This file asks the quieter question a
# readable sheet also has to answer: "is any of this still EARNING its line". Seven notes, all
# advisory, all about vocabulary that is declared but dead, rows that say the same thing twice,
# and numbers that should have had a name:
#
#   * a local variable declared and never read
#   * a function nothing ever calls (and that is not published, not a trigger, not a lifecycle hook)
#   * a declared trigger nothing ever fires
#   * a behavior the sheet requires that no row uses
#   * an event that has been switched off for a long time
#   * two events that read identically
#   * the same literal typed three times or more - a setting waiting for a name
#   * an enum value nothing in the project ever names
#   * a signal announced but never heard (no scene connection, no connect call, no await)
#
# Every judgement is a PURE static function over plain data, so the suite pins the answers without
# planting a broken fixture in the project (a planted fixture would make the repo's own audit report
# the finding forever). The `check_*` wrappers only load sheets and turn those answers into findings.
#
# Severity is info throughout: a tidy sheet is a preference, never a build break.
@tool
class_name EventSheetDoctorTidiness
extends RefCounted

## How long an event has to have been switched off before the sweep mentions it.
const DISABLED_EVENT_DAYS := 30
## How many times a literal has to appear before "make it a setting?" is worth saying.
const REPEATED_LITERAL_THRESHOLD := 3
## Literals too small or too common to be worth a name. A `0` is not a magic number.
const UNREMARKABLE_LITERALS: PackedStringArray = [
	"", "0", "1", "-1", "0.0", "1.0", "true", "false", "self", "null",
	"Vector2.ZERO", "Vector3.ZERO", "\"\"",
]
## Names GDScript itself calls. A sheet never calls them, so "nothing calls it" is not a finding.
const LIFECYCLE_PREFIX := "_"


# ── 1. Locals declared and never read ────────────────────────────────────────────────────────
## The local variables `rows` declares that nothing in `rows` goes on to read. `rows` is one
## body (a function's rows, an event's sub-events): a local is only ever in scope there, so the
## corpus a name is looked for in is that body and nothing wider. A local's OWN default value is
## excluded - `var speed = speed` would otherwise excuse itself.
static func unread_locals(rows: Array) -> PackedStringArray:
	var declared: PackedStringArray = PackedStringArray()
	var corpus: PackedStringArray = PackedStringArray()
	_walk_body(rows, declared, corpus)
	var joined: String = "\n".join(corpus)
	var unread: PackedStringArray = PackedStringArray()
	for local_name: String in declared:
		if local_name.strip_edges().is_empty():
			continue
		if RegEx.create_from_string("\\b%s\\b" % local_name).search(joined) == null:
			unread.append(local_name)
	return unread


static func _walk_body(rows: Array, declared: PackedStringArray, corpus: PackedStringArray) -> void:
	for row: Variant in rows:
		if row is LocalVariable:
			declared.append((row as LocalVariable).name)
		elif row is EventGroup:
			var group: EventGroup = row
			_walk_body(group.events if not group.events.is_empty() else group.rows, declared, corpus)
		elif row is RawCodeRow:
			corpus.append((row as RawCodeRow).code)
		elif row is EventRow:
			var event: EventRow = row
			for local: LocalVariable in event.local_variables:
				declared.append(local.name)
			for ace: Variant in event.conditions + event.actions:
				if ace is RawCodeRow:
					corpus.append((ace as RawCodeRow).code)
				elif ace is Resource and ace.get("params") is Dictionary:
					for value: Variant in (ace.get("params") as Dictionary).values():
						corpus.append(str(value))
			for pick: Variant in event.pick_filters:
				if pick is PickFilter:
					corpus.append((pick as PickFilter).collection_value)
					corpus.append((pick as PickFilter).predicate_expression)
			_walk_body(event.sub_events, declared, corpus)


# ── 2. Functions nothing calls ───────────────────────────────────────────────────────────────
## The functions in `sheet` that nothing in `corpus` calls. A function published as vocabulary
## (`expose_as_ace`), a lifecycle hook (a leading underscore) and a function whose name the
## corpus mentions are all left alone: each of those has a caller the sheet cannot see.
static func uncalled_functions(sheet: EventSheetResource, corpus: String) -> PackedStringArray:
	var uncalled: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction):
			continue
		var event_function: EventFunction = entry
		var function_name: String = event_function.function_name.strip_edges()
		if function_name.is_empty() or function_name.begins_with(LIFECYCLE_PREFIX):
			continue
		if event_function.expose_as_ace:
			continue
		if RegEx.create_from_string("\\b%s\\b" % function_name).search(corpus) == null:
			uncalled.append(function_name)
	return uncalled


# ── 3. Triggers nothing fires ────────────────────────────────────────────────────────────────
## The signals `sheet` declares that nothing in `corpus` emits. Only declarations marked as a
## trigger are considered: a plain signal is an offer to the rest of the project, while a trigger
## is a promise this sheet makes to its own events.
static func unfired_triggers(sheet: EventSheetResource, corpus: String) -> PackedStringArray:
	var unfired: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.events:
		if not (entry is SignalRow):
			continue
		var signal_row: SignalRow = entry
		if not signal_row.trigger:
			continue
		var signal_name: String = signal_row.signal_name.strip_edges()
		if signal_name.is_empty():
			continue
		if not corpus.contains("%s.emit" % signal_name) and not corpus.contains("\"%s\"" % signal_name):
			unfired.append(signal_name)
	return unfired


# ── Enum values nothing names ────────────────────────────────────────────────────────────────
## The enum values `source` (one generated script's text) declares that nothing in `corpus`
## (every project script joined) ever writes as `Name.VALUE`. Declarations never spell that
## token themselves - `enum Mode { IDLE }` contains no `Mode.IDLE` - so the corpus may include
## the declaring file, and a match arm or a comparison anywhere counts as a use. Approximate on
## purpose in one direction only: a value read through a variable or by its number is invisible,
## which is why the finding asks rather than accuses.
static func dead_enum_values(source: String, corpus: String) -> PackedStringArray:
	var dead: PackedStringArray = PackedStringArray()
	for declaration: Dictionary in _declared_enums(source):
		var enum_name: String = str(declaration["name"])
		for member: String in (declaration["members"] as PackedStringArray):
			var token: RegEx = RegEx.create_from_string("\\b%s\\.%s\\b" % [enum_name, member])
			if token != null and token.search(corpus) == null:
				dead.append("%s.%s" % [enum_name, member])
	return dead


## The enums one script's text declares, as [{name, members}]. Reads the two canonical shapes the
## compiler emits (and the importer lifts): single-line `enum Name { A, B = 4 }`, and multi-line
## `enum Name {` with one tab-indented member per line until `}`. Member names keep only the part
## before any explicit `= number`.
static func _declared_enums(source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var one_line: RegEx = RegEx.create_from_string("^enum ([A-Za-z_][A-Za-z0-9_]*) \\{ (.+) \\}$")
	var header: RegEx = RegEx.create_from_string("^enum ([A-Za-z_][A-Za-z0-9_]*) \\{$")
	var lines: PackedStringArray = source.split("\n")
	var line_index: int = 0
	while line_index < lines.size():
		var line: String = lines[line_index]
		var single: RegExMatch = one_line.search(line)
		if single != null:
			found.append({"name": single.get_string(1), "members": _member_names(EventSheetBlockRegistry.split_params_top_level(single.get_string(2)))})
			line_index += 1
			continue
		var opener: RegExMatch = header.search(line)
		if opener != null:
			var members: PackedStringArray = PackedStringArray()
			var scan: int = line_index + 1
			while scan < lines.size() and lines[scan] != "}":
				if lines[scan].begins_with("\t"):
					members.append(lines[scan].substr(1).trim_suffix(","))
				scan += 1
			found.append({"name": opener.get_string(1), "members": _member_names(members)})
			line_index = scan + 1
			continue
		line_index += 1
	return found


## Bare member names from member declarations ("HURT = 4" -> "HURT").
static func _member_names(member_texts: PackedStringArray) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for member_text: String in member_texts:
		var member_name: String = member_text.get_slice("=", 0).strip_edges()
		if not member_name.is_empty():
			names.append(member_name)
	return names


# ── Signals announced but never heard ────────────────────────────────────────────────────────
## The signals `source` (one generated script's text) declares that nothing anywhere LISTENS to:
## no scene wires them (`signal="name"` in `scenes_text`, every .tscn joined), no script connects
## them (`name.connect` or a quoted "name" in `corpus`), and nothing awaits them. Emitting is the
## other side of the contract and deliberately does not count - an announcement with no listener
## is exactly the silence this note exists to name. The quoted-name test is generous on purpose:
## a name handed around as a string is probably being connected somewhere this sweep cannot parse,
## and accusing a working game is worse than missing a tidy-up.
static func unheard_signals(source: String, corpus: String, scenes_text: String) -> PackedStringArray:
	var unheard: PackedStringArray = PackedStringArray()
	var declaration: RegEx = RegEx.create_from_string("(?m)^signal ([A-Za-z_][A-Za-z0-9_]*)")
	for found: RegExMatch in declaration.search_all(source):
		var signal_name: String = found.get_string(1)
		if scenes_text.contains("signal=\"%s\"" % signal_name):
			continue
		if corpus.contains("\"%s\"" % signal_name):
			continue
		var connect_call: RegEx = RegEx.create_from_string("\\b%s\\.connect\\b" % signal_name)
		if connect_call != null and connect_call.search(corpus) != null:
			continue
		var awaited: RegEx = RegEx.create_from_string("await [^\\n]*\\b%s\\b" % signal_name)
		if awaited != null and awaited.search(corpus) != null:
			continue
		unheard.append(signal_name)
	return unheard


# ── 4. Behaviors attached but unused ─────────────────────────────────────────────────────────
## The behaviors `sheet` requires that no row names. An attached behavior no event uses is a
## node's worth of runtime nobody asked for.
static func unused_behaviors(sheet: EventSheetResource, corpus: String) -> PackedStringArray:
	var unused: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.requires_behaviors:
		var behavior: String = str(entry).strip_edges()
		if behavior.is_empty():
			continue
		if RegEx.create_from_string("\\b%s\\b" % behavior).search(corpus) == null:
			unused.append(behavior)
	return unused


# ── 5. Events switched off for a long time ───────────────────────────────────────────────────
## The 1-based margin numbers of the events in `entries` that are switched off. Sub-events of a
## disabled parent are not counted twice: the parent already carries the note.
static func disabled_event_numbers(entries: Array) -> PackedInt32Array:
	var numbers: Dictionary = EventSheetResource.event_numbers(entries)
	var disabled: PackedInt32Array = PackedInt32Array()
	_collect_disabled(entries, numbers, disabled)
	return disabled


static func _collect_disabled(rows: Array, numbers: Dictionary, into: PackedInt32Array) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_collect_disabled(group.events if not group.events.is_empty() else group.rows, numbers, into)
		elif row is EventRow:
			var event: EventRow = row
			if not event.enabled:
				into.append(int(numbers.get(event.get_instance_id(), 0)))
				continue
			_collect_disabled(event.sub_events, numbers, into)


## When `path` last changed, and how we know. Git is asked first because it knows the file's
## history; when it cannot answer (no repository, no git on PATH) the file's own date stands in
## and the finding says so, rather than quietly presenting a weaker fact as the stronger one.
static func last_change(path: String) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(path)
	var output: Array = []
	var status: int = OS.execute("git", ["log", "-1", "--format=%ct", "--", absolute], output, true)
	if status == 0 and not output.is_empty():
		var stamp: String = str(output[0]).strip_edges()
		if stamp.is_valid_int() and int(stamp) > 0:
			return {"unix": int(stamp), "source": "git"}
	var modified: int = int(FileAccess.get_modified_time(path))
	return {"unix": modified, "source": "file date"}


## How the sweep words an age it can only bound. Git gives a number of days; a file date gives
## "a long time", because a file rewritten yesterday says nothing about when a row was switched off.
static func age_words(source: String, days: int) -> String:
	if source == "git":
		return "for %d days (git)" % days
	return "for a long time (file date)"


# ── 6. Events that read identically ──────────────────────────────────────────────────────────
## The signature two events are compared by: their trigger, conditions and actions, in order,
## with the parameters they were given. Comments, uids, breakpoints and the enabled flag are
## deliberately out - two rows that DO the same thing are the finding, however they are annotated.
static func event_signature(event: EventRow) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("trigger:%s::%s" % [event.trigger_provider_id, event.trigger_id])
	for condition: ACECondition in event.conditions:
		parts.append("condition:%s::%s(%s)%s" % [condition.provider_id, condition.ace_id,
			_params_signature(condition.params), "!" if condition.negated else ""])
	for action: Variant in event.actions:
		if action is ACEAction:
			var ace_action: ACEAction = action
			parts.append("action:%s::%s(%s)" % [ace_action.provider_id, ace_action.ace_id,
				_params_signature(ace_action.params)])
		elif action is RawCodeRow:
			parts.append("code:%s" % (action as RawCodeRow).code.strip_edges())
	return "\n".join(parts)


static func _params_signature(params: Dictionary) -> String:
	var keys: Array = params.keys()
	keys.sort()
	var pairs: PackedStringArray = PackedStringArray()
	for key: Variant in keys:
		pairs.append("%s=%s" % [str(key), str(params[key])])
	return ",".join(pairs)


## Pairs of margin numbers whose events read identically: [[6, 19], …], each pair reported once
## and in the order the sheet numbers them. An event with no actions is skipped - a bare
## condition row repeated is a shape, not a duplicate.
static func identical_event_pairs(entries: Array) -> Array:
	var numbers: Dictionary = EventSheetResource.event_numbers(entries)
	var seen: Dictionary = {}
	var pairs: Array = []
	_collect_identical(entries, numbers, seen, pairs)
	return pairs


static func _collect_identical(rows: Array, numbers: Dictionary, seen: Dictionary, pairs: Array) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_collect_identical(group.events if not group.events.is_empty() else group.rows, numbers, seen, pairs)
		elif row is EventRow:
			var event: EventRow = row
			if not event.actions.is_empty():
				var signature: String = event_signature(event)
				var number: int = int(numbers.get(event.get_instance_id(), 0))
				if seen.has(signature):
					pairs.append([int(seen[signature]), number])
				else:
					seen[signature] = number
			_collect_identical(event.sub_events, numbers, seen, pairs)


# ── 7. A literal typed three times or more ───────────────────────────────────────────────────
## literal -> how many parameters spell it, for the literals worth naming. A value is a literal
## when it is a number or a quoted string; anything with an identifier in it is an expression and
## belongs to whatever it names. Sorted by the literal so the report is deterministic.
static func repeated_literals(entries: Array, threshold: int = REPEATED_LITERAL_THRESHOLD) -> Dictionary:
	var counts: Dictionary = {}
	_count_literals(entries, counts)
	var repeated: Dictionary = {}
	var keys: Array = counts.keys()
	keys.sort()
	for key: Variant in keys:
		if int(counts[key]) >= threshold:
			repeated[str(key)] = int(counts[key])
	return repeated


static func _count_literals(rows: Array, counts: Dictionary) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_count_literals(group.events if not group.events.is_empty() else group.rows, counts)
		elif row is EventRow:
			var event: EventRow = row
			for ace: Variant in event.conditions + event.actions:
				if ace is Resource and ace.get("params") is Dictionary:
					for value: Variant in (ace.get("params") as Dictionary).values():
						var literal: String = str(value).strip_edges()
						if is_nameable_literal(literal):
							counts[literal] = int(counts.get(literal, 0)) + 1
			_count_literals(event.sub_events, counts)


## True when a parameter's text is a bare value a reader would rather see behind a name: a number
## or a quoted string, and not one of the values too plain to be worth naming.
static func is_nameable_literal(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if UNREMARKABLE_LITERALS.has(trimmed):
		return false
	if trimmed.length() > 40:
		return false
	if trimmed.is_valid_float():
		return true
	if trimmed.length() >= 3 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return not trimmed.substr(1, trimmed.length() - 2).contains("\"")
	return false


## A first draft of the name a literal deserves: a quoted string becomes its own words, a number
## becomes a plainly-labelled value. Always a legal identifier, never the final word - the reader
## renames it from the row afterwards, which is the whole point of giving it one.
static func suggested_variable_name(literal: String) -> String:
	var trimmed: String = literal.strip_edges()
	if trimmed.begins_with("\"") and trimmed.ends_with("\"") and trimmed.length() >= 2:
		trimmed = trimmed.substr(1, trimmed.length() - 2)
	var out: String = ""
	for index: int in trimmed.length():
		var character: String = trimmed[index]
		out += character.to_lower() if character.is_valid_identifier() or character.is_valid_int() else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.strip_edges().lstrip("_").rstrip("_")
	if out.is_empty() or out[0].is_valid_int():
		out = "value_" + out
	return out.rstrip("_")


## The data half of the "Extract to variable" quick fix: gives `literal` the name
## `variable_name` on the sheet and points every parameter that spelled it at the name instead.
## Returns how many parameters moved over (0 when the sheet has nothing to change), so a caller
## can refuse to save a no-op edit.
static func extract_literal_to_variable(sheet: EventSheetResource, literal: String,
		variable_name: String) -> int:
	if sheet == null or literal.strip_edges().is_empty() or variable_name.strip_edges().is_empty():
		return 0
	if sheet.variables.has(variable_name):
		return 0
	var replaced: int = _replace_literal(sheet.events, literal.strip_edges(), variable_name)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry
			replaced += _replace_literal(
				event_function.events if not event_function.events.is_empty() else event_function.rows,
				literal.strip_edges(), variable_name)
	if replaced == 0:
		return 0
	sheet.variables[variable_name] = {
		"type": "float" if literal.strip_edges().is_valid_float() else "String",
		"default": literal.strip_edges(),
		"exported": true,
	}
	return replaced


static func _replace_literal(rows: Array, literal: String, variable_name: String) -> int:
	var replaced: int = 0
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			replaced += _replace_literal(group.events if not group.events.is_empty() else group.rows,
				literal, variable_name)
		elif row is EventRow:
			var event: EventRow = row
			for ace: Variant in event.conditions + event.actions:
				if not (ace is Resource) or not (ace.get("params") is Dictionary):
					continue
				var params: Dictionary = ace.get("params")
				for key: Variant in params.keys():
					if str(params[key]).strip_edges() == literal:
						params[key] = variable_name
						replaced += 1
				ace.set("params", params)
			replaced += _replace_literal(event.sub_events, literal, variable_name)
	return replaced


# ── The checks the Doctor runs ───────────────────────────────────────────────────────────────
## Declarations nobody reaches, across every GENERATED script in the project: enum values nothing
## names and signals nothing hears. Driven by the project's scripts rather than by sheet_paths
## (list_project_sheets() finds only `.tres`, so a sheet-driven walk skips most projects while
## looking like it works), and gated on the generated banner: only a compiled sheet's own output
## is judged, because in hand-written code (and in a `.gd` that IS a sheet, which carries no
## banner) an unused name can be a public offer to code that is not written yet. The usage CORPUS
## is still every project script, so a use anywhere excuses a declaration. Published packs
## (res://eventsheet_addons/) are vocabulary, not project wiring, and are skipped for the same
## reason the unused-pack check gives them their own gentler note.
static func check_declaration_reach(findings: Array[Dictionary]) -> void:
	var script_paths: PackedStringArray = EventSheetProjectDoctor._project_scripts()
	var sources: Dictionary = {}
	var corpus_parts: PackedStringArray = PackedStringArray()
	for script_path: String in script_paths:
		var text: String = EventSheetProjectDoctor.source_of(script_path)
		sources[script_path] = text
		corpus_parts.append(text)
	var corpus: String = "\n".join(corpus_parts)
	var scene_parts: PackedStringArray = PackedStringArray()
	for scene_path: String in EventSheetSceneConnections.scene_paths():
		scene_parts.append(EventSheetProjectDoctor.source_of(scene_path))
	var scenes_text: String = "\n".join(scene_parts)
	for script_path: String in script_paths:
		if script_path.begins_with("res://eventsheet_addons/"):
			continue
		var source: String = str(sources[script_path])
		# begins_with, never contains: the generated header is always line one, and a file that
		# merely TALKS about the convention (this check's own test, for one) must not be read as code.
		if not source.begins_with("# AUTO-GENERATED by EventForge"):
			continue
		for dead_value: String in dead_enum_values(source, corpus):
			_add(findings, "dead-enum-value", script_path,
				"Enum value %s is declared but nothing ever names it - remove it, or wire it in?" % dead_value)
		for signal_name: String in unheard_signals(source, corpus, scenes_text):
			_add(findings, "unheard-signal", script_path,
				"Signal \"%s\" is announced but nothing listens - connect it in a scene or an On %s event, or remove it." % [signal_name, signal_name])



## Every tidiness note for every sheet, appended to `findings` through the Doctor's own `_add`.
## One entry point rather than seven, because the sweep loads each sheet once and asks all seven
## questions of it - loading a project's sheets seven times over is the slow way to the same report.
static func check_tidiness(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	for sheet_path: String in sheet_paths:
		var sheet: EventSheetResource = load(sheet_path) as EventSheetResource
		if sheet == null:
			continue
		var corpus: String = EventSheetProjectDoctor._sheet_usage_text(sheet)
		_note_unread_locals(sheet, sheet_path, findings)
		for function_name: String in uncalled_functions(sheet, corpus):
			_add(findings, "uncalled-function", sheet_path,
				"Function \"%s\" is never called - published as vocabulary, or dead?" % function_name)
		for signal_name: String in unfired_triggers(sheet, corpus):
			_add(findings, "unfired-trigger", sheet_path,
				"Trigger \"%s\" is declared but never fired." % signal_name)
		for behavior: String in unused_behaviors(sheet, corpus):
			_add(findings, "unused-behavior", sheet_path,
				"Behavior \"%s\" is attached but no event uses it." % behavior)
		_note_disabled_events(sheet, sheet_path, findings)
		for pair: Array in identical_event_pairs(sheet.events):
			_add(findings, "identical-events", sheet_path,
				"Events %d and %d are identical - make one?" % [int(pair[0]), int(pair[1])], int(pair[0]))
		var repeated: Dictionary = repeated_literals(sheet.events)
		for literal: String in repeated.keys():
			# Carries the literal as the finding's SUBJECT, the key the quick-fix seam reads, so the
			# Extract to variable chip knows what to give a name without parsing the message back
			# out of English.
			findings.append({
				"severity": "info", "check": "repeated-literal", "path": sheet_path,
				"message": "%s appears %d times - make it a setting?" % [literal, int(repeated[literal])],
				"event": 0, "subject": literal,
			})


## The Doctor's finding shape, spelled here so the sweep depends on one thing from the audit
## (`_sheet_usage_text`, the canonical "what does this sheet reference" walk) rather than two.
static func _add(findings: Array[Dictionary], check: String, path: String, message: String,
		event_number: int = 0) -> void:
	findings.append({"severity": "info", "check": check, "path": path, "message": message,
		"event": event_number})


static func _note_unread_locals(sheet: EventSheetResource, sheet_path: String,
		findings: Array[Dictionary]) -> void:
	for local_name: String in unread_locals(sheet.events):
		EventSheetProjectDoctor._add(findings, "info", "unread-local", sheet_path,
			"Local variable \"%s\" is declared but never read." % local_name)
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction):
			continue
		var event_function: EventFunction = entry
		var body: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
		for local_name: String in unread_locals(body):
			_add(findings, "unread-local", sheet_path,
				"Local variable \"%s\" in \"%s\" is declared but never read."
					% [local_name, event_function.function_name])


static func _note_disabled_events(sheet: EventSheetResource, sheet_path: String,
		findings: Array[Dictionary]) -> void:
	var disabled: PackedInt32Array = disabled_event_numbers(sheet.events)
	if disabled.is_empty():
		return
	var change: Dictionary = last_change(sheet_path)
	var days: int = int(floor(float(int(Time.get_unix_time_from_system()) - int(change.get("unix", 0))) / 86400.0))
	if str(change.get("source")) == "git" and days < DISABLED_EVENT_DAYS:
		return
	for number: int in disabled:
		_add(findings, "long-disabled-event", sheet_path,
			"Event %d is switched off and has been %s."
				% [number, age_words(str(change.get("source")), days)], number)
