# EventForge — ACE-level import lifting (reverse template matching)
#
# Turns generated GDScript back into real sheet events when a file is opened as a
# GDScript-backed sheet: lifecycle trigger functions (_ready/_process/_physics_process)
# lift into EventRows — `if <condition templates>:` blocks become conditioned events,
# adjacent `elif`/`else:` chains become else_mode siblings, NESTED if/elif/else become
# sub-events (recursively), and action-template lines become ACEActions; statements
# that match no template become in-flow GDScript blocks, so the event still lifts.
# Reverse templates come from the builtin descriptor registry (`{param}` placeholders
# become named captures; params round-trip as strings because codegen substitutes with
# plain str()).
#
# THE CONTRACT (lossless rule): lifting is all-or-nothing per file and verified by
# recompiling the whole sheet — if the output is not byte-identical to the source, the
# lift is reverted and every function stays a verbatim block row. Only the trailing run of
# trigger functions is considered (EventForge's own layout); files with other layouts
# simply keep their blocks.
@tool
extends RefCounted
class_name EventSheetACELifter

## Lifecycle handlers reversible from the header alone (signal handlers reverse via the
## `_ready` connection map — see _parse_connections/_lift_function).
const LIFECYCLE_TRIGGERS: Dictionary = {
	"func _ready() -> void:": "OnReady",
	"func _process(delta: float) -> void:": "OnProcess",
	"func _physics_process(delta: float) -> void:": "OnPhysicsProcess",
	"func _input(event: InputEvent) -> void:": "OnInput",
	"func _unhandled_input(event: InputEvent) -> void:": "OnUnhandledInput",
	"func _run() -> void:": "OnEditorRun"
}

## Attempts the lift on an imported external sheet. Mutates sheet.events only when the
## byte-identical round-trip verifies; otherwise leaves the sheet untouched.
## Two-pass: the full lift (events + sheet functions + trailing comments) is tried first;
## if its byte-verify fails (e.g. annotations we can't regenerate), the event-only lift is
## retried so files keep at least the coverage older versions had.
static func attempt_lift(sheet: EventSheetResource, source: String, lift_functions: bool = true) -> bool:
	if sheet == null:
		return false
	# The trailing run: function blocks, their @ace annotation blocks, blank separators,
	# and a final top-level comment block — EventForge's emission layout in row form.
	var first_run_index: int = sheet.events.size()
	for index in range(sheet.events.size() - 1, -1, -1):
		var row: Variant = sheet.events[index]
		if row is RawCodeRow and _run_row_kind((row as RawCodeRow).code, lift_functions) != "other":
			first_run_index = index
			continue
		break
	# When the first run function directly follows the prelude, its annotation block is
	# glued to that preceding "other" row — split it off (stripped at mutation time).
	var boundary_annotations_text: String = ""
	var pending_annotations: Dictionary = {}
	if lift_functions and first_run_index > 0 and sheet.events[first_run_index - 1] is RawCodeRow:
		var boundary_lines: PackedStringArray = (sheet.events[first_run_index - 1] as RawCodeRow).code.split("\n")
		var annotation_start: int = boundary_lines.size()
		while annotation_start > 0 and boundary_lines[annotation_start - 1].begins_with("## "):
			annotation_start -= 1
		if annotation_start < boundary_lines.size():
			var annotation_lines: PackedStringArray = boundary_lines.slice(annotation_start)
			boundary_annotations_text = "\n" + "\n".join(annotation_lines)
			pending_annotations = _parse_annotations("\n".join(annotation_lines))
	# `_ready`'s leading connect lines reveal which functions are signal handlers
	# (and for which signal/source node). Emission regenerates the connects.
	var connections: Dictionary = {}
	for index in range(first_run_index, sheet.events.size()):
		var ready_row: RawCodeRow = sheet.events[index] as RawCodeRow
		if ready_row != null and ready_row.code.begins_with("func _ready() -> void:"):
			connections = _parse_connections(ready_row.code.split("\n"))
	# Lift every run row (all-or-nothing). Annotation blocks attach to the NEXT function.
	var lifted_events: Array = []
	var lifted_functions: Array = []
	var lifted_comments: Array = []
	var saw_function: bool = false
	for index in range(first_run_index, sheet.events.size()):
		var row: RawCodeRow = sheet.events[index] as RawCodeRow
		match _run_row_kind(row.code, lift_functions):
			"blank":
				continue  # separator; emission re-adds it
			"annotations":
				pending_annotations = _parse_annotations(row.code)
				if pending_annotations.is_empty():
					return _retry_or_fail(sheet, source, lift_functions)
			"comments":
				# Trailing top-level comments (deferred emission): one CommentRow per
				# blank-separated chunk.
				for chunk: String in row.code.strip_edges().split("\n\n"):
					var comment: CommentRow = CommentRow.new()
					comment.text = chunk.trim_prefix("# ").replace("\n# ", "\n")
					lifted_comments.append(comment)
			"func":
				saw_function = true
				var header: String = row.code.split("\n")[0]
				if LIFECYCLE_TRIGGERS.has(header) or _is_connected_handler(header, connections):
					if not pending_annotations.is_empty():
						return _retry_or_fail(sheet, source, lift_functions)
					# Lenient ifs: unmatched control flow becomes in-flow GDScript inside
					# the event instead of failing the file (byte-verify still gates).
					var lift: Dictionary = _lift_function(row.code.split("\n"), connections, true)
					if not bool(lift.get("ok", false)):
						return _retry_or_fail(sheet, source, lift_functions)
					lifted_events.append_array(lift.get("events", []))
				else:
					if not lift_functions:
						return false
					var function_lift: Dictionary = _lift_sheet_function(row.code.split("\n"), pending_annotations)
					pending_annotations = {}
					if not bool(function_lift.get("ok", false)):
						return _retry_or_fail(sheet, source, lift_functions)
					lifted_functions.append(function_lift.get("function"))
			_:
				return _retry_or_fail(sheet, source, lift_functions)
	if not saw_function or (lifted_events.is_empty() and lifted_functions.is_empty()):
		return false

	var backup: Array[Resource] = sheet.events.duplicate()
	var functions_backup: Array[Resource] = sheet.functions.duplicate()
	sheet.events.resize(first_run_index)
	# Emission inserts one blank line before each section; the import attached that blank
	# (and possibly the first function's annotation block) to the preceding row, so drop
	# them to avoid doubling. The backup array is SHALLOW — the boundary row's original
	# code must be restored explicitly on revert.
	var boundary: RawCodeRow = null
	var boundary_code: String = ""
	if not sheet.events.is_empty() and sheet.events[sheet.events.size() - 1] is RawCodeRow:
		boundary = sheet.events[sheet.events.size() - 1] as RawCodeRow
		boundary_code = boundary.code
		if not boundary_annotations_text.is_empty() and boundary.code.ends_with(boundary_annotations_text):
			boundary.code = boundary.code.substr(0, boundary.code.length() - boundary_annotations_text.length())
		if boundary.code.ends_with("\n"):
			boundary.code = boundary.code.substr(0, boundary.code.length() - 1)
		elif boundary.code.strip_edges().is_empty():
			sheet.events.remove_at(sheet.events.size() - 1)
	for event: Variant in lifted_events:
		sheet.events.append(event)
	for comment: Variant in lifted_comments:
		sheet.events.append(comment)
	for function: Variant in lifted_functions:
		sheet.functions.append(function)

	# Verify: the lifted sheet must reproduce the source byte-for-byte.
	var saved_path: String = sheet.external_source_path
	sheet.external_source_path = "user://eventforge_lift_verify.gd"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_lift_verify.gd").get("output", ""))
	sheet.external_source_path = saved_path
	if output == source:
		return true
	sheet.events = backup
	sheet.functions = functions_backup
	if boundary != null:
		boundary.code = boundary_code
	return _retry_or_fail(sheet, source, lift_functions)

## The two-pass fallback: a failed full lift retries event-only before giving up, so the
## function/comment upgrades can never regress what already lifted before them.
static func _retry_or_fail(sheet: EventSheetResource, source: String, lift_functions: bool) -> bool:
	if lift_functions:
		return attempt_lift(sheet, source, false)
	return false

## Build-time de-coding for behaviour packs: replaces each sheet function's single-RawCode body with
## lifted ACE rows (the same reverse grammar that opens a .gd as events), kept ONLY when the whole
## sheet still recompiles BYTE-IDENTICALLY — a PER-FUNCTION gate, so one un-liftable body never reverts
## the others. Lets pack builders ship code-free without hand-authoring every row; bodies that can't
## round-trip (inner classes, exotic control flow) keep their RawCode. Idempotent + deterministic, so
## the regenerated .tres stays byte-stable (drift=0). Returns the number of functions de-coded.
static func lift_function_bodies(sheet: EventSheetResource) -> int:
	if sheet == null or sheet.functions.is_empty():
		return 0
	var reverse_entries: Array = _build_reverse_entries()
	var verify_path: String = "user://_eventforge_pack_body_verify.gd"
	var converted: int = 0
	for fn_variant: Variant in sheet.functions:
		var fn: EventFunction = fn_variant as EventFunction
		if fn == null:
			continue
		var body_rows: Array = fn.events if not fn.events.is_empty() else fn.rows
		if body_rows.size() != 1 or not (body_rows[0] is RawCodeRow):
			continue  # only the un-converted shape (one verbatim block)
		var code: String = (body_rows[0] as RawCodeRow).code
		if code.strip_edges().is_empty():
			continue
		var before: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
		# Parse the body as a depth-1 function body (one leading tab per line, plus a dummy header).
		var lines: PackedStringArray = PackedStringArray(["func _ready() -> void:"])
		for line: String in code.split("\n"):
			lines.append("\t" + line)
		var parsed: Dictionary = _parse_body(lines, 1, 1, "", "", "", "", reverse_entries, true)
		if not bool(parsed.get("ok", false)) or int(parsed.get("next", 0)) < lines.size():
			continue
		var lifted: Array = parsed.get("rows", [])
		if lifted.is_empty():
			continue
		var backup: Array[Resource] = (fn.events if not fn.events.is_empty() else fn.rows).duplicate()
		var had_events: bool = not fn.events.is_empty()
		fn.events = _to_resource_array(lifted)
		fn.rows = []
		var after: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
		if after == before:
			converted += 1
		else:
			if had_events:
				fn.events = backup
				fn.rows = []
			else:
				fn.rows = backup
				fn.events = []
	return converted

static func _to_resource_array(rows: Array) -> Array[Resource]:
	var out: Array[Resource] = []
	for r: Variant in rows:
		if r is Resource:
			out.append(r as Resource)
	return out

## Build-time de-coding for EVENT bodies — the sibling of lift_function_bodies, for sheet.events.
## An event whose body is a single verbatim RawCode block (e.g. a behaviour's OnProcess /
## OnPhysicsProcess tick) is reverse-lifted into the SAME ordered row list a function body uses, then
## folded into the event's sub_events (the compiler walks sub_events in order: a condition-less row
## emits its actions inline, a conditioned row emits if/elif/else). Kept ONLY when the whole sheet
## still recompiles BYTE-IDENTICALLY — a PER-EVENT gate, so one stubborn body never reverts the rest.
## This is what turns a behaviour's code cell into the event-sheet-style if/else/elseif + action rows.
## Idempotent + deterministic (byte-stable regeneration, drift=0). Returns the number of events lifted.
static func lift_event_bodies(sheet: EventSheetResource) -> int:
	if sheet == null or sheet.events.is_empty():
		return 0
	var reverse_entries: Array = _build_reverse_entries()
	var verify_path: String = "user://_eventforge_event_body_verify.gd"
	var targets: Array[EventRow] = []
	_collect_single_block_event_rows(sheet.events, targets)
	var converted: int = 0
	for row: EventRow in targets:
		var code: String = (row.actions[0] as RawCodeRow).code
		if code.strip_edges().is_empty():
			continue
		var before: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
		# Parse the body under a throwaway depth-1 header, exactly like the function-body path.
		var lines: PackedStringArray = PackedStringArray(["func _ready() -> void:"])
		for line: String in code.split("\n"):
			lines.append("\t" + line)
		var parsed: Dictionary = _parse_body(lines, 1, 1, "", "", "", "", reverse_entries, true)
		if not bool(parsed.get("ok", false)) or int(parsed.get("next", 0)) < lines.size():
			continue
		var lifted: Array = parsed.get("rows", [])
		if lifted.is_empty():
			continue
		var backup_actions: Array[Resource] = row.actions.duplicate()
		var backup_subs: Array[Resource] = row.sub_events.duplicate()
		row.actions = []
		row.sub_events = _to_resource_array(lifted)
		var after: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
		if after == before:
			converted += 1
		else:
			row.actions = backup_actions
			row.sub_events = backup_subs
	return converted

## Converts hand-written `## @ace_trigger` (+ @ace_name / @ace_category) `signal X` declaration blocks
## inside top-level RawCode rows into SignalRow rows, so a behaviour's trigger signals read as
## keyword-badged Trigger rows (and feed the On Signal / Emit Signal pickers + autocomplete) instead
## of a code cell. The declarations relocate to the compiler's signal prelude — behaviour-identical,
## the SAME `## @ace_trigger` annotations, just emitted as rows. At pack-build time the .gd regenerates
## (byte_gated=false); the importer calls it byte_gated=true so a user's .gd only converts when the
## recompile stays byte-identical. Returns the number of signals lifted.
static func lift_signal_declarations(sheet: EventSheetResource, byte_gated: bool = false) -> int:
	if sheet == null or sheet.events.is_empty():
		return 0
	var verify_path: String = "user://_eventforge_signal_verify.gd"
	var before: String = ""
	if byte_gated:
		before = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
	var new_events: Array[Resource] = []
	var lifted_total: int = 0
	for item: Variant in sheet.events:
		if item is RawCodeRow:
			var split: Dictionary = _split_signal_declarations(item as RawCodeRow)
			lifted_total += int(split.get("count", 0))
			for produced: Variant in split.get("rows", []):
				new_events.append(produced as Resource)
		else:
			new_events.append(item as Resource)
	if lifted_total == 0:
		return 0
	var backup: Array[Resource] = sheet.events.duplicate()
	sheet.events = new_events
	if byte_gated:
		var after: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
		if after != before:
			sheet.events = backup  # reorder/spacing changed — keep the verbatim block (round-trip safe)
			return 0
	return lifted_total

## Splits one RawCode block into [SignalRow…, remainder RawCode]: each leading `## @ace_trigger`
## signal group becomes a trigger SignalRow; everything else stays a single verbatim block (its
## relative order preserved), so @ace_condition/@ace_expression helper functions are untouched.
static func _split_signal_declarations(raw: RawCodeRow) -> Dictionary:
	var src_lines: PackedStringArray = raw.code.split("\n")
	var signal_rows: Array = []
	var remainder: PackedStringArray = PackedStringArray()
	var count: int = 0
	var i: int = 0
	while i < src_lines.size():
		if src_lines[i].strip_edges() == "## @ace_trigger":
			# Collect the annotation lines, then require a `signal …` line to confirm a signal group.
			var j: int = i + 1
			var ace_name: String = ""
			var ace_category: String = ""
			while j < src_lines.size() and src_lines[j].strip_edges().begins_with("## @ace_"):
				var annotation: String = src_lines[j].strip_edges()
				var name_arg: String = _extract_annotation_arg(annotation, "@ace_name")
				if not name_arg.is_empty():
					ace_name = name_arg
				var category_arg: String = _extract_annotation_arg(annotation, "@ace_category")
				if not category_arg.is_empty():
					ace_category = category_arg
				j += 1
			if j < src_lines.size() and src_lines[j].strip_edges().begins_with("signal "):
				var parsed_signal: Dictionary = _parse_signal_line(src_lines[j].strip_edges())
				var signal_row: SignalRow = SignalRow.new()
				signal_row.signal_name = str(parsed_signal.get("name", ""))
				signal_row.params = parsed_signal.get("params", PackedStringArray())
				signal_row.trigger = true
				signal_row.ace_name = ace_name
				signal_row.ace_category = ace_category
				signal_rows.append(signal_row)
				count += 1
				i = j + 1
				if i < src_lines.size() and src_lines[i].strip_edges().is_empty():
					i += 1  # consume the blank that separated this signal from the next block
				continue
		remainder.append(src_lines[i])
		i += 1
	var out: Array = []
	for produced: Variant in signal_rows:
		out.append(produced)
	if not "\n".join(remainder).strip_edges().is_empty():
		var remainder_row: RawCodeRow = RawCodeRow.new()
		remainder_row.code = "\n".join(remainder)
		out.append(remainder_row)
	return {"rows": out, "count": count}

## Pulls the quoted argument out of an annotation line, e.g. `## @ace_name("On Jumped")` → `On Jumped`.
## Returns "" when the key is absent or unquoted.
static func _extract_annotation_arg(line: String, key: String) -> String:
	var anchor: String = "%s(\"" % key
	var start: int = line.find(anchor)
	if start == -1:
		return ""
	start += anchor.length()
	var end: int = line.find("\"", start)
	if end == -1:
		return ""
	return line.substr(start, end - start)

## Parses a `signal name` / `signal name(a, b: int)` declaration into {name, params}.
static func _parse_signal_line(line: String) -> Dictionary:
	var rest: String = line.substr("signal ".length()).strip_edges()
	var params: PackedStringArray = PackedStringArray()
	var paren: int = rest.find("(")
	if paren != -1:
		var name: String = rest.substr(0, paren).strip_edges()
		var inside: String = rest.substr(paren + 1, rest.rfind(")") - paren - 1)
		for piece: String in inside.split(","):
			if not piece.strip_edges().is_empty():
				params.append(piece.strip_edges())
		return {"name": name, "params": params}
	return {"name": rest, "params": params}

## Converts hand-written `func` declarations inside top-level RawCode rows into EventFunction rows,
## reusing the importer's _lift_sheet_function (so a `## @ace_*` block exposes the function as an
## ACE, and a plain helper becomes an un-exposed function). This is what makes a behaviour's helper
## functions (Is Moving, Can Jump, _perform_jump…) read as Function rows instead of one code block.
## At pack-build time the .gd regenerates (byte_gated=false) — exposed functions gain the sheet's
## `@ace_icon`; the importer calls it byte_gated=true. Returns the number of functions lifted.
static func lift_function_declarations(sheet: EventSheetResource, byte_gated: bool = false) -> int:
	if sheet == null or sheet.events.is_empty():
		return 0
	var verify_path: String = "user://_eventforge_function_verify.gd"
	var before: String = ""
	if byte_gated:
		before = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
	var new_events: Array[Resource] = []
	var harvested: Array = []
	for item: Variant in sheet.events:
		if item is RawCodeRow:
			var split: Dictionary = _split_function_declarations(item as RawCodeRow)
			for produced: Variant in split.get("functions", []):
				harvested.append(produced)
			var remainder: Variant = split.get("remainder")
			if remainder != null:
				new_events.append(remainder as Resource)
		else:
			new_events.append(item as Resource)
	if harvested.is_empty():
		return 0
	var backup_events: Array[Resource] = sheet.events.duplicate()
	var backup_functions: Array[Resource] = sheet.functions.duplicate()
	sheet.events = new_events
	for produced: Variant in harvested:
		sheet.functions.append(produced as Resource)
	if byte_gated:
		var after: String = str(SheetCompiler.compile(sheet, verify_path).get("output", ""))
		if after != before:
			sheet.events = backup_events
			sheet.functions = backup_functions
			return 0
	return harvested.size()

## Splits one RawCode block into [EventFunction…, remainder RawCode]: each `func …:` block (with its
## preceding `## @ace_*` annotations) becomes an EventFunction; a plain `#` comment above an
## un-annotated function relocates into the function body so nothing is lost. Lines that aren't part
## of a liftable function stay in the verbatim remainder.
static func _split_function_declarations(raw: RawCodeRow) -> Dictionary:
	var src: PackedStringArray = raw.code.split("\n")
	var remainder: PackedStringArray = PackedStringArray()
	var functions: Array = []
	var i: int = 0
	while i < src.size():
		var line: String = src[i]
		if line.begins_with("func ") and line.strip_edges().ends_with(":"):
			var function_lines: PackedStringArray = PackedStringArray([line])
			var k: int = i + 1
			while k < src.size() and (src[k].strip_edges().is_empty() or src[k].begins_with("\t") or src[k].begins_with(" ")):
				function_lines.append(src[k])
				k += 1
			while function_lines.size() > 1 and function_lines[function_lines.size() - 1].strip_edges().is_empty():
				function_lines.remove_at(function_lines.size() - 1)
			# Pull the contiguous comment/annotation block that precedes the function off the remainder.
			var lead: PackedStringArray = PackedStringArray()
			while remainder.size() > 0 and remainder[remainder.size() - 1].strip_edges().begins_with("#"):
				lead.insert(0, remainder[remainder.size() - 1])
				remainder.remove_at(remainder.size() - 1)
			while remainder.size() > 0 and remainder[remainder.size() - 1].strip_edges().is_empty():
				remainder.remove_at(remainder.size() - 1)
			var ace_block: PackedStringArray = PackedStringArray()
			var plain_comments: PackedStringArray = PackedStringArray()
			for lead_line: String in lead:
				if lead_line.strip_edges().begins_with("##"):
					ace_block.append(lead_line)
				else:
					plain_comments.append(lead_line.strip_edges().trim_prefix("#").strip_edges())
			var annotations: Dictionary = _parse_annotations("\n".join(ace_block)) if not ace_block.is_empty() else {}
			var lift: Dictionary = _lift_sheet_function(function_lines, annotations)
			if bool(lift.get("ok", false)):
				var event_function: EventFunction = lift.get("function") as EventFunction
				if not plain_comments.is_empty():
					var comment_row: CommentRow = CommentRow.new()
					comment_row.text = "\n".join(plain_comments)
					event_function.events.insert(0, comment_row)
				functions.append(event_function)
				i = k
				continue
			for lead_line: String in lead:
				remainder.append(lead_line)
			for function_line: String in function_lines:
				remainder.append(function_line)
			i = k
			continue
		remainder.append(line)
		i += 1
	var out: Dictionary = {"functions": functions, "remainder": null}
	if not "\n".join(remainder).strip_edges().is_empty():
		var remainder_row: RawCodeRow = RawCodeRow.new()
		remainder_row.code = "\n".join(remainder)
		out["remainder"] = remainder_row
	return out

## Collects EventRows whose body is exactly one verbatim RawCode block (the un-converted shape:
## a single RawCodeRow action and no sub-events). Recurses through sub-events and groups so a
## nested single-block tick lifts too.
static func _collect_single_block_event_rows(events: Array, into: Array[EventRow]) -> void:
	for item: Variant in events:
		if item is EventRow:
			var row: EventRow = item as EventRow
			if row.actions.size() == 1 and row.actions[0] is RawCodeRow and row.sub_events.is_empty():
				into.append(row)
			else:
				_collect_single_block_event_rows(row.sub_events, into)
		elif item is EventGroup:
			_collect_single_block_event_rows((item as EventGroup).events, into)

## Classifies a trailing-run row: "func", "annotations" (## @ace block), "blank",
## "comments" (top-level # lines), or "other" (breaks the run).
static func _run_row_kind(code: String, lift_functions: bool) -> String:
	if code.begins_with("func "):
		return "func"
	if code.strip_edges().is_empty():
		return "blank"
	var saw_annotation: bool = false
	var saw_comment: bool = false
	for line: String in code.split("\n"):
		if line.strip_edges().is_empty():
			continue
		if line.begins_with("## "):
			saw_annotation = true
		elif line.begins_with("# "):
			saw_comment = true
		else:
			return "other"
	if saw_annotation and not saw_comment and lift_functions:
		return "annotations"
	if saw_comment and not saw_annotation and lift_functions:
		return "comments"
	return "other"

## True when the header is a signal handler present in the `_ready` connection map.
static func _is_connected_handler(header: String, connections: Dictionary) -> bool:
	var header_regex: RegEx = RegEx.new()
	header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)")
	var header_match: RegExMatch = header_regex.search(header)
	return header_match != null and connections.has(header_match.get_string(1))

## Reverse of _emit_expose_annotations: parses a `## @ace_*` block into EventFunction
## exposure fields. {} = unrecognized shape (lift falls back).
static func _parse_annotations(code: String) -> Dictionary:
	var fields: Dictionary = {"expose": false, "name": "", "category": "", "description": ""}
	var recognized: bool = false
	for line: String in code.split("\n"):
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		if text == "## @ace_hidden":
			recognized = true
		elif text == "## @ace_action" or text == "## @ace_condition" or text == "## @ace_expression":
			# Three-way expose (action / condition / expression). The exposed TYPE is re-derived from the
			# function's return type on emit, so all three directives simply mark the function exposed.
			fields["expose"] = true
			recognized = true
		elif text.begins_with("## @ace_name(\"") and text.ends_with("\")"):
			fields["name"] = text.substr(14, text.length() - 16)
		elif text.begins_with("## @ace_category(\"") and text.ends_with("\")"):
			fields["category"] = text.substr(18, text.length() - 20)
		elif text.begins_with("## @ace_description(\"") and text.ends_with("\")"):
			fields["description"] = text.substr(21, text.length() - 23)
		elif text.begins_with("## @ace_codegen_template("):
			pass  # regenerated from the function shape; byte-verify confirms it matches
		elif text.begins_with("## @ace_icon("):
			pass  # regenerated from the sheet's custom_class_icon; byte-verify confirms
		else:
			return {}
	return fields if recognized else {}

## A non-trigger function → EventFunction (sheet function), body parsed with the same
## grammar as event bodies (events without triggers). {} fields come from the preceding
## annotation block (every generated sheet function has one: @ace_action… or @ace_hidden).
static func _lift_sheet_function(function_lines: PackedStringArray, annotations: Dictionary) -> Dictionary:
	# A generated sheet function always carries an annotation block (@ace_action… or @ace_hidden); a
	# hand-written helper in an opened .gd has none. Both lift — the un-annotated one becomes an
	# un-exposed function whose @ace_hidden emission is suppressed (lifted_unannotated), so it
	# round-trips byte-identically. Needs an explicit `-> Type:` header (the regex below); a
	# return-type-less `func foo():` still falls back to a verbatim block.
	var unannotated: bool = annotations.is_empty()
	var header_regex: RegEx = RegEx.new()
	header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\) -> ([A-Za-z_][A-Za-z0-9_]*):$")
	var header_match: RegExMatch = header_regex.search(function_lines[0])
	if header_match == null:
		return {"ok": false}
	var event_function: EventFunction = EventFunction.new()
	event_function.lifted_unannotated = unannotated
	event_function.function_name = header_match.get_string(1)
	var return_name: String = header_match.get_string(3) if header_match.get_group_count() >= 3 else "void"
	var return_types: Dictionary = {"void": TYPE_NIL, "bool": TYPE_BOOL, "int": TYPE_INT, "float": TYPE_FLOAT, "String": TYPE_STRING, "Vector2": TYPE_VECTOR2, "Vector3": TYPE_VECTOR3, "Color": TYPE_COLOR, "Array": TYPE_ARRAY, "Dictionary": TYPE_DICTIONARY, "Variant": TYPE_MAX}
	if not return_types.has(return_name):
		return {"ok": false}
	event_function.return_type = return_types[return_name]
	for argument: String in header_match.get_string(2).split(", ", false):
		var param: ACEParam = ACEParam.new()
		var argument_text: String = argument
		# Split off a default value (`amount: int = 5`) first, so it never leaks into the type name.
		var equals: int = argument_text.find(" = ")
		if equals >= 0:
			param.gdscript_default = argument_text.substr(equals + 3).strip_edges()
			argument_text = argument_text.substr(0, equals)
		var colon: int = argument_text.find(": ")
		if colon >= 0:
			param.id = argument_text.substr(0, colon)
			param.type_name = argument_text.substr(colon + 2)
		else:
			param.id = argument_text
		event_function.params.append(param)
	event_function.expose_as_ace = bool(annotations.get("expose", false))
	event_function.ace_display_name = str(annotations.get("name", ""))
	event_function.ace_category = str(annotations.get("category", ""))
	event_function.description = str(annotations.get("description", ""))
	var body: Dictionary = _lift_function(PackedStringArray(["func _ready() -> void:"]) + function_lines.slice(1), {}, true)
	if not bool(body.get("ok", false)):
		return {"ok": false}
	# Function-body events carry no trigger (the function header is the entry point).
	for event: Variant in body.get("events", []):
		(event as EventRow).trigger_provider_id = ""
		(event as EventRow).trigger_id = ""
		event_function.events.append(event)
	return {"ok": true, "function": event_function}

## Core signal names ↔ trigger ids, mirroring TriggerResolver's signal-backed table.
const CORE_SIGNAL_TRIGGERS: Dictionary = {
	"body_entered": "OnBodyEntered",
	"area_entered": "OnAreaEntered",
	"body_exited": "OnBodyExited",
	"area_exited": "OnAreaExited",
	"timeout": "OnTimeout",
	"animation_finished": "OnAnimationFinished",
	"tree_entered": "OnTreeEntered",
	"tree_exiting": "OnTreeExiting",
	"tree_exited": "OnTreeExited",
	"renamed": "OnRenamed",
	"child_entered_tree": "OnChildEnteredTree"
}

## Parses `_ready`'s leading connect lines into {handler_name: {signal, source}}.
## Shapes (exactly what _emit_grouped_trigger_functions emits):
##   	body_entered.connect(_on_body_entered)
##   	get_node("Platform").landed.connect(_on_platform_landed)
static func _parse_connections(ready_lines: PackedStringArray) -> Dictionary:
	var connections: Dictionary = {}
	var regex: RegEx = RegEx.new()
	if regex.compile("^\t(?:get_node\\(\"([^\"]+)\"\\)\\.)?([A-Za-z_][A-Za-z0-9_]*)\\.connect\\(([A-Za-z_][A-Za-z0-9_]*)\\)$") != OK:
		return connections
	for index in range(1, ready_lines.size()):
		var regex_match: RegExMatch = regex.search(ready_lines[index])
		if regex_match == null:
			break  # connects are emitted first; the rest is OnReady body
		connections[regex_match.get_string(3)] = {
			"signal": regex_match.get_string(2),
			"source": regex_match.get_string(1)
		}
	return connections

## One trigger function → {ok: bool, events: Array}. Recognizes lifecycle headers and —
## via the `_ready` connection map — signal handlers, which lift to signal-trigger events
## (Core signals reverse to their trigger ids; others become "signal:<name>" triggers with
## the handler's argument signature baked as trigger_args and the connect's source node as
## trigger_source_path). `_ready`'s connect lines are skipped: emission regenerates them.
static func _lift_function(function_lines: PackedStringArray, connections: Dictionary = {}, lenient_ifs: bool = false) -> Dictionary:
	if function_lines.is_empty():
		return {"ok": false}
	var trigger_id: String = ""
	var trigger_provider: String = "Core"
	var trigger_args: String = ""
	var trigger_source: String = ""
	var index: int = 1
	if LIFECYCLE_TRIGGERS.has(function_lines[0]):
		trigger_id = str(LIFECYCLE_TRIGGERS[function_lines[0]])
		if function_lines[0].begins_with("func _ready()"):
			# Skip the regenerated connect lines; what remains is the OnReady body.
			while index < function_lines.size() and _is_connect_line(function_lines[index]):
				index += 1
			if index >= function_lines.size():
				return {"ok": true, "events": []}  # connects-only _ready
	else:
		var header_regex: RegEx = RegEx.new()
		header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\) -> void:$")
		var header_match: RegExMatch = header_regex.search(function_lines[0])
		if header_match == null or not connections.has(header_match.get_string(1)):
			return {"ok": false}
		var connection: Dictionary = connections[header_match.get_string(1)]
		var signal_name: String = str(connection.get("signal", ""))
		trigger_source = str(connection.get("source", ""))
		if CORE_SIGNAL_TRIGGERS.has(signal_name):
			trigger_id = str(CORE_SIGNAL_TRIGGERS[signal_name])
		else:
			trigger_id = "signal:%s" % signal_name
			trigger_provider = ""
			trigger_args = header_match.get_string(2)
	var reverse_entries: Array = _build_reverse_entries()
	var parsed: Dictionary = _parse_body(function_lines, index, 1, trigger_id, trigger_provider, trigger_args, trigger_source, reverse_entries, lenient_ifs)
	if not bool(parsed.get("ok", false)) or int(parsed.get("next", 0)) < function_lines.size():
		return {"ok": false}  # dedented/blank content inside a function — not our shape
	var events: Array = parsed.get("rows", [])
	for event: Variant in events:
		if _is_plain_collector(event as EventRow) and (event as EventRow).actions.is_empty():
			return {"ok": false}
	return {"ok": true, "events": events}

## Recursive body grammar (the reverse of _emit_event_body): at each depth,
## `if <conds>:` opens a conditioned row, an adjacent `elif <conds>:`/`else:` chains
## onto it via else_mode (ELSE + conditions == ELIF — the emitter's rule), and the
## block's own body parses one level deeper — statements become the row's actions,
## nested blocks its sub_events. Anything unrepresentable (unmatched conditions,
## statements interleaved AFTER a nested block, arbitrary control flow) falls back to
## the lenient path: the raw line + its deeper lines stay in-flow GDScript with their
## relative indentation, exactly as before this grammar existed. The byte-identical
## recompile in attempt_lift gates every shape this parser produces.
## Returns {ok, rows: Array[EventRow], next: int}; a "plain collector" row (no
## conditions, no else_mode) holds the statements between blocks.
static func _parse_body(lines: PackedStringArray, start: int, depth: int, trigger_id: String, trigger_provider: String, trigger_args: String, trigger_source: String, reverse_entries: Array, lenient_ifs: bool) -> Dictionary:
	var indent: String = "\t".repeat(depth)
	var rows: Array = []
	var current: EventRow = null
	var pending_raw: PackedStringArray = PackedStringArray()
	var chain_open: bool = false
	var index: int = start
	while index < lines.size():
		var line: String = lines[index]
		if line.strip_edges().is_empty():
			return {"ok": false}  # blank inside a generated body never happens; bail to blocks
		if not line.begins_with(indent):
			break  # dedent: this body is done; the caller resumes here
		var rest: String = line.substr(depth)
		var at_this_depth: bool = not rest.begins_with("\t")
		var is_if: bool = at_this_depth and rest.begins_with("if ") and rest.ends_with(":")
		var is_elif: bool = at_this_depth and chain_open and rest.begins_with("elif ") and rest.ends_with(":")
		var is_else: bool = at_this_depth and chain_open and rest == "else:"
		if is_if or is_elif or is_else:
			var expression: String = ""
			if is_if:
				expression = rest.substr(3, rest.length() - 4)
			elif is_elif:
				expression = rest.substr(5, rest.length() - 6)
			var block_event: EventRow = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			if not is_if:
				block_event.else_mode = EventRow.ElseMode.ELSE
			var representable: bool = expression.is_empty() or _parse_conditions(expression, block_event, reverse_entries)
			var inner: Dictionary = {}
			if representable:
				inner = _parse_body(lines, index + 1, depth + 1, "", "", "", "", reverse_entries, lenient_ifs)
				representable = bool(inner.get("ok", false)) and _adopt_block_body(block_event, inner.get("rows", []))
			if not representable:
				if not lenient_ifs:
					return {"ok": false}
				# Raw fallback: the header line joins the open collector; its deeper
				# lines arrive through the statement branch below, tabs preserved.
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					rows.append(current)
				pending_raw.append(rest)
				index += 1
				chain_open = false
				continue
			_flush_raw(current, pending_raw)
			current = null
			rows.append(block_event)
			index = int(inner.get("next"))
			chain_open = true
			continue
		# Loops ('For Each' / repeat / while): `for X in EXPR:` or `while EXPR:` at this
		# depth opens a pick-filter row whose body parses one level deeper — exactly the if/elif/else
		# grammar above, but the wrapper is a PickFilter, not conditions. _adopt_block_body folds the
		# body (leading statements → actions, nested blocks → sub_events); a statement AFTER a nested
		# block is unrepresentable (actions emit before sub-events) and falls to the lenient raw path.
		var is_for: bool = at_this_depth and rest.begins_with("for ") and rest.contains(" in ") and rest.ends_with(":")
		var is_while: bool = at_this_depth and rest.begins_with("while ") and rest.ends_with(":")
		if is_for or is_while:
			var loop_event: EventRow = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			loop_event.pick_filters.append(_loop_pick_filter(rest, is_while))
			var loop_inner: Dictionary = _parse_body(lines, index + 1, depth + 1, "", "", "", "", reverse_entries, lenient_ifs)
			var loop_ok: bool = bool(loop_inner.get("ok", false)) and _adopt_block_body(loop_event, loop_inner.get("rows", []))
			if not loop_ok:
				if not lenient_ifs:
					return {"ok": false}
				# Raw fallback: the header joins the open collector; its deeper lines arrive
				# through the statement branch below, tabs preserved (same as if/elif/else).
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					rows.append(current)
				pending_raw.append(rest)
				index += 1
				chain_open = false
				continue
			_flush_raw(current, pending_raw)
			current = null
			rows.append(loop_event)
			index = int(loop_inner.get("next"))
			chain_open = false  # a loop never opens an if/elif/else chain
			continue
		# Match ("switch"): `match EXPR:` at this depth plus its arm lines (one level deeper)
		# become a MatchRow ACTION — subject + verbatim branch text, exactly as the emitter re-prefixes
		# body_indent+tab onto each line. A blank inside the arms (the lifter's hand-written-code signal)
		# ends collection, so the whole function safely stays blocks; byte-verify gates the rebuild.
		var is_match: bool = at_this_depth and rest.begins_with("match ") and rest.ends_with(":")
		if is_match:
			var branch_indent: String = "\t".repeat(depth + 1)
			var branch_lines: PackedStringArray = PackedStringArray()
			var scan: int = index + 1
			while scan < lines.size():
				var branch_line: String = lines[scan]
				if branch_line.strip_edges().is_empty() or not branch_line.begins_with(branch_indent):
					break  # dedent (or a blank) closes the match block
				branch_lines.append(branch_line.substr(depth + 1))  # strip body_indent + the arm tab
				scan += 1
			if not branch_lines.is_empty():
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					rows.append(current)
				_flush_raw(current, pending_raw)  # any raw before the match emits before it (order)
				var match_row: MatchRow = MatchRow.new()
				match_row.match_expression = rest.substr(6, rest.length() - 7)  # strip "match " and ":"
				match_row.branches_text = "\n".join(branch_lines)
				current.actions.append(match_row)
				index = scan
				chain_open = false
				continue
			# An empty arm list isn't our shape — fall through and treat `match …:` as a raw line.
		# Statement at this depth (or deeper, inside an unlifted block): collect with
		# relative indentation intact.
		if current == null:
			current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			rows.append(current)
		_consume_action_line(current, rest, 0, pending_raw, reverse_entries)
		index += 1
		chain_open = false
	_flush_raw(current, pending_raw)
	return {"ok": true, "rows": rows, "next": index}

## Folds a parsed block body into its event: a leading plain collector's statements
## become the event's actions, every conditioned/chained row becomes a sub-event.
## False when the shape can't survive emission (actions emit BEFORE sub-events, so
## statements after a nested block have no faithful home).
static func _adopt_block_body(block_event: EventRow, inner_rows: Array) -> bool:
	var cursor: int = 0
	if cursor < inner_rows.size() and _is_plain_collector(inner_rows[cursor] as EventRow):
		for action: Variant in (inner_rows[cursor] as EventRow).actions:
			block_event.actions.append(action)
		cursor += 1
	while cursor < inner_rows.size():
		var child: EventRow = inner_rows[cursor] as EventRow
		if _is_plain_collector(child):
			return false
		block_event.sub_events.append(child)
		cursor += 1
	return true

## A "plain collector" holds only the loose statements between blocks — no conditions, no loop
## wrapper, no else-chain. A pick_filter-bearing loop row is NOT plain (its body belongs in
## sub_events, and its wrapper must survive _adopt_block_body / the _lift_function empty-row drop).
static func _is_plain_collector(event: EventRow) -> bool:
	return event != null and event.conditions.is_empty() and event.pick_filters.is_empty() and event.else_mode == EventRow.ElseMode.NONE

## Builds the PickFilter for a `for`/`while` header (already stripped to this depth, trailing `:`).
## `while EXPR:` → WHILE (no loop variable). `for X in EXPR:` → REPEAT when EXPR is a pure
## `range(...)` call, else EXPRESSION (`X` is kept verbatim, so tuple targets like `k, v` survive).
## Mirrors _emit_pick_filters / _pick_collection_expression so the minimal loop (predicate, order-by,
## first-N and frame-spread all left at their empty/zero defaults) round-trips byte-identically.
static func _loop_pick_filter(rest: String, is_while: bool) -> PickFilter:
	var pick: PickFilter = PickFilter.new()
	if is_while:
		pick.collection_kind = PickFilter.CollectionKind.WHILE
		pick.collection_value = rest.substr(6, rest.length() - 7)  # strip "while " and trailing ":"
		pick.iterator_name = ""  # a while loop has no loop variable (the emitter ignores it)
		return pick
	var header: String = rest.substr(4, rest.length() - 5)  # strip "for " and ":" -> "X in EXPR"
	var split_at: int = header.find(" in ")
	pick.iterator_name = header.substr(0, split_at)
	var collection: String = header.substr(split_at + 4)
	if _is_pure_range(collection):
		pick.collection_kind = PickFilter.CollectionKind.REPEAT
		pick.collection_value = collection.substr(6, collection.length() - 7)  # the args inside range(...)
	else:
		pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
		pick.collection_value = collection
	return pick

## True only when EXPR is exactly a `range(...)` call whose opening paren closes at the final
## character, so it round-trips through REPEAT. `range(5) + 1` is NOT pure (stays EXPRESSION).
static func _is_pure_range(expr: String) -> bool:
	# Needs at least one char between the parens — a bare `range()` is invalid GDScript and would
	# classify as a Repeat with an empty count; let it stay EXPRESSION (still round-trips verbatim).
	if expr.length() <= 7 or not expr.begins_with("range(") or not expr.ends_with(")"):
		return false
	var depth: int = 0
	for i in range(5, expr.length()):
		var c: String = expr[i]
		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0:
				return i == expr.length() - 1
	return false

## True for a `_ready` body line that is a regenerated signal connection.
static func _is_connect_line(line: String) -> bool:
	return line.begins_with("\t") and line.ends_with(")") and line.contains(".connect(")

static func _make_event(trigger_id: String, trigger_provider: String = "Core", trigger_args: String = "", trigger_source: String = "") -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = trigger_provider
	event.trigger_id = trigger_id
	event.trigger_args = trigger_args
	event.trigger_source_path = trigger_source
	return event

## Splits a joined condition on TOP-LEVEL " and " only — ignoring " and " inside (), [], {} or a
## string literal — so a compound term like `f(a and b)`, `x == "a and b"`, or `not (a and b)` stays
## ONE condition. The naive String.split(" and ") fragmented these into garbage Expression-Is-True
## rows ("f(a", "b)"); each piece still round-tripped when rejoined, but the structure was nonsense.
static func _split_top_level_and(expression: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var start: int = 0
	var i: int = 0
	var n: int = expression.length()
	while i < n:
		var c: String = expression[i]
		if in_string:
			if c == "\\":
				i += 2  # skip the escaped char, whatever it is
				continue
			if c == quote:
				in_string = false
			i += 1
			continue
		if c == "\"" or c == "'":
			in_string = true
			quote = c
		elif c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		elif depth == 0 and c == " " and expression.substr(i, 5) == " and ":
			parts.append(expression.substr(start, i - start))
			i += 5
			start = i
			continue
		i += 1
	parts.append(expression.substr(start))
	return parts

## Splits a joined condition expression on top-level " and " and reverse-matches every term
## (supporting `not (...)` negation). All terms must match or the lift fails — though the generic
## Expression Is True condition (bare {expr}) catches any term no specific ACE claims.
static func _parse_conditions(expression: String, event: EventRow, reverse_entries: Array) -> bool:
	for term: String in _split_top_level_and(expression):
		var negated: bool = false
		var candidate: String = term
		if candidate.begins_with("not (") and candidate.ends_with(")"):
			negated = true
			candidate = candidate.substr(5, candidate.length() - 6)
		var matched: Dictionary = _match_entry(candidate, reverse_entries, "condition")
		if matched.is_empty():
			return false
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = str(matched.get("provider", ""))
		condition.ace_id = str(matched.get("ace_id", ""))
		condition.params = matched.get("params", {})
		condition.negated = negated
		event.conditions.append(condition)
	return true

## Action line → ACEAction when a template matches; otherwise queued as raw GDScript so the
## event still lifts (in-flow blocks re-emit verbatim at the body indent).
static func _consume_action_line(event: EventRow, line: String, _depth: int, pending_raw: PackedStringArray, reverse_entries: Array) -> void:
	var matched: Dictionary = _match_entry(line, reverse_entries, "action")
	if matched.is_empty():
		pending_raw.append(line)
		return
	_flush_raw(event, pending_raw)
	var action: ACEAction = ACEAction.new()
	action.provider_id = str(matched.get("provider", ""))
	action.ace_id = str(matched.get("ace_id", ""))
	action.params = matched.get("params", {})
	event.actions.append(action)

static func _flush_raw(event: EventRow, pending_raw: PackedStringArray) -> void:
	if pending_raw.is_empty() or event == null:
		return
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(pending_raw)
	# Import triage: these lines matched no ACE template, so they stayed verbatim. Record why
	# (non-emitted — never affects the byte-exact round-trip) so the editor can show an
	# actionable "stayed as code" hint instead of an opaque block. See RawCodeRow.lift_note.
	block.lift_note = "no matching ACE template"
	event.actions.append(block)
	pending_raw.clear()

## Reverse index over builtin descriptors: template → anchored regex with named captures.
static func _build_reverse_entries() -> Array:
	var entries: Array = []
	var brace_regex: RegEx = RegEx.new()
	brace_regex.compile("\\{[^}]*\\}")
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		var template: String = descriptor.codegen_template.strip_edges()
		if template.is_empty() or template.contains("{,"):
			continue  # optional-segment templates are not reversible (v1)
		# Helper ACEs are mostly forward-authoring conveniences with deliberately generic templates
		# ({code}, math expressions) that would shadow specific ACEs — kept out of the reverse index.
		# EXCEPT four statement catch-alls, admitted at LOWEST specificity (the literal_len sort at the
		# bottom puts them after every specific ACE) so they reverse-lift only what nothing else claims:
		# Set Property (`{target}.{property} = {value}`) and Call Method (`{target}.{method}({args})`)
		# (Stage B), plus Set Local Variable (`var {name} = {value}`) and its typed sibling (Stage D),
		# so a local declaration in a hand-written body becomes a row, not a code cell. Byte-verify gates.
		if descriptor.category == "Helpers" and not (descriptor.ace_id in ["SetProperty", "CallMethod", "SetLocalVar", "SetLocalVarTyped"]):
			continue
		if template in ["break", "continue", "pass"]:
			# Bare loop-control keywords also appear in generated pick-loop bodies, so
			# reverse-lifting them would mis-claim the compiler's own break/continue lines.
			continue
		var kind: String = ""
		match descriptor.ace_type:
			ACEDescriptor.ACEType.CONDITION:
				kind = "condition"
			ACEDescriptor.ACEType.ACTION:
				kind = "action"
			_:
				continue
		# Optional-prefix `{target.}` templates compile to two shapes — the blank-target host form
		# (`play()`) and the set-target form (`$Enemy.play()`) — so register a reverse entry for each.
		for variant: String in _optional_prefix_variants(template):
			var regex: RegEx = _template_to_regex(variant)
			if regex == null:
				continue
			var literal_len: int = brace_regex.sub(variant, "", true).length()
			entries.append({"provider": descriptor.provider_id, "ace_id": descriptor.ace_id, "kind": kind, "regex": regex, "literal_len": literal_len, "order": entries.size()})
	# Try SPECIFIC templates before generic catch-alls. The Core generics (SetVar `{var_name} = {value}`,
	# CallFunction `{function_name}({args})`, …) use lazy `.+?` captures that match almost any
	# assignment/call, so in raw registry order they SHADOW every specific node ACE (`position = …`
	# would reverse-lift as SetVar). _match_entry is first-match, so stable-sort by literal-char count
	# (descending) — `velocity = {vel}` outranks `{var_name} = {value}`; the `order` tiebreaker keeps
	# registry order among equal-specificity twins (sort_custom is not guaranteed stable).
	entries.sort_custom(func(a, b): return a["literal_len"] > b["literal_len"] if a["literal_len"] != b["literal_len"] else a["order"] < b["order"])
	return entries

static func _match_entry(line: String, reverse_entries: Array, kind: String) -> Dictionary:
	for entry: Variant in reverse_entries:
		if str((entry as Dictionary).get("kind", "")) != kind:
			continue
		var regex: RegEx = (entry as Dictionary).get("regex")
		var regex_match: RegExMatch = regex.search(line)
		if regex_match == null:
			continue
		var params: Dictionary = {}
		for group_name: String in regex.get_names():
			params[group_name] = regex_match.get_string(group_name)
		return {"provider": (entry as Dictionary).get("provider"), "ace_id": (entry as Dictionary).get("ace_id"), "params": params}
	return {}

## Expands an optional-prefix template `{name.}foo` into the two shapes it can compile to, so both
## round-trip: the blank-target form (`foo`) and the set-target form (`{name}.foo`, where `{name}`
## reverses to a named capture). Templates without `{name.}` pass through as a one-element list.
## (Multi-line `{name.}` templates also expand, but stay single-line-unmatchable like every multi-line
## template — harmless; they were never line-reversible.)
static func _optional_prefix_variants(template: String) -> Array:
	var prefix_re: RegEx = RegEx.new()
	prefix_re.compile("\\{([A-Za-z_][A-Za-z0-9_]*)\\.\\}")
	var hit: RegExMatch = prefix_re.search(template)
	if hit == null:
		return [template]
	var placeholder: String = hit.get_string(0)  # e.g. "{target.}"
	var capture_name: String = hit.get_string(1)  # e.g. "target"
	return [template.replace(placeholder, ""), template.replace(placeholder, "{%s}." % capture_name)]

## "{amount}" placeholders become lazy named captures; everything else matches literally.
static func _template_to_regex(template: String) -> RegEx:
	var pattern: String = "^"
	var cursor: int = 0
	while cursor < template.length():
		var open: int = template.find("{", cursor)
		if open == -1:
			pattern += _escape_regex(template.substr(cursor))
			break
		var close: int = template.find("}", open)
		if close == -1:
			pattern += _escape_regex(template.substr(cursor))
			break
		pattern += _escape_regex(template.substr(cursor, open - cursor))
		var param_name: String = template.substr(open + 1, close - open - 1)
		# Call-argument captures may legitimately be empty — a zero-arg call like `landed.emit()`,
		# `jump()` or `super()` — so `{args}` uses a zero-or-more lazy capture; every other placeholder
		# (value, expression, target…) still requires at least one char. An empty match can only land
		# against the literal `()` in the template, so this never over-claims, and it round-trips.
		var quantifier: String = "*?" if param_name == "args" else "+?"
		pattern += "(?<%s>.%s)" % [param_name, quantifier]
		cursor = close + 1
	pattern += "$"
	var regex: RegEx = RegEx.new()
	return regex if regex.compile(pattern) == OK else null

static func _escape_regex(text: String) -> String:
	var escaped: String = ""
	for character in text:
		escaped += ("\\" + character) if character in "\\^$.|?*+()[]{}" else character
	return escaped
