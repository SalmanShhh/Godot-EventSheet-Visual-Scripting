# EventForge - ACE-level import lifting (reverse template matching)
#
# Turns generated GDScript back into real sheet events when a file is opened as a
# GDScript-backed sheet: lifecycle trigger functions (_ready/_process/_physics_process)
# lift into EventRows - `if <condition templates>:` blocks become conditioned events,
# adjacent `elif`/`else:` chains become else_mode siblings, NESTED if/elif/else become
# sub-events (recursively), and action-template lines become ACEActions; statements
# that match no template become in-flow GDScript blocks, so the event still lifts.
# Reverse templates come from the builtin descriptor registry (`{param}` placeholders
# become named captures; params round-trip as strings because codegen substitutes with
# plain str()).
#
# THE CONTRACT (lossless rule): lifting is all-or-nothing per file and verified by
# recompiling the whole sheet - if the output is not byte-identical to the source, the
# lift is reverted and every function stays a verbatim block row. Only the trailing run of
# trigger functions is considered (EventForge's own layout); files with other layouts
# simply keep their blocks.
@tool
class_name EventSheetACELifter
extends RefCounted

## Lifecycle handlers reversible from the header alone (signal handlers reverse via the
## `_ready` connection map - see _parse_connections/_lift_function).
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
	# and a final top-level comment block - EventForge's emission layout in row form.
	var first_run_index: int = sheet.events.size()
	for index in range(sheet.events.size() - 1, -1, -1):
		var row: Variant = sheet.events[index]
		if row is RawCodeRow and _run_row_kind((row as RawCodeRow).code, lift_functions) != "other":
			first_run_index = index
			continue
		break
	# When the first run function directly follows the prelude, its annotation block is
	# glued to that preceding "other" row - split it off (stripped at mutation time).
	var boundary_annotations_text: String = ""
	var pending_annotations: Dictionary = {}
	# Verbatim `@rpc`-style function annotations riding onto the next lifted function (see annotation_lines).
	var pending_annotation_lines: PackedStringArray = PackedStringArray()
	# The plain `##` Godot doc-comment text riding onto the next lifted function (see doc_comment).
	var pending_doc_comment: String = ""
	if lift_functions and first_run_index > 0 and sheet.events[first_run_index - 1] is RawCodeRow:
		var boundary_lines: PackedStringArray = (sheet.events[first_run_index - 1] as RawCodeRow).code.split("\n")
		var annotation_start: int = boundary_lines.size()
		# Peel the trailing `## @ace_*` doc block, a plain `##` doc comment, AND any `@rpc`-style annotations.
		while annotation_start > 0 and (boundary_lines[annotation_start - 1].begins_with("## ") or boundary_lines[annotation_start - 1] == "##" or _is_function_annotation_line(boundary_lines[annotation_start - 1])):
			annotation_start -= 1
		if annotation_start < boundary_lines.size():
			var annotation_lines: PackedStringArray = boundary_lines.slice(annotation_start)
			boundary_annotations_text = "\n" + "\n".join(annotation_lines)
			pending_annotations = _parse_annotations("\n".join(annotation_lines))
			pending_annotation_lines = _collect_gd_annotation_lines("\n".join(annotation_lines))
			pending_doc_comment = _collect_doc_comment_text("\n".join(annotation_lines))
	# `_ready`'s leading connect lines reveal which functions are signal handlers
	# (and for which signal/source node). Emission regenerates the connects.
	var connections: Dictionary = {}
	for index in range(first_run_index, sheet.events.size()):
		var ready_row: RawCodeRow = sheet.events[index] as RawCodeRow
		if ready_row != null and ready_row.code.begins_with("func _ready() -> void:"):
			connections = _parse_connections(ready_row.code.split("\n"))
	# Lift the run PER FUNCTION with re-anchoring: when a function's body (or a stray row) can't
	# lift, everything scanned so far - including it - stays raw and the run RE-ANCHORS just after
	# it, so the longest cleanly-lifting TRAILING subset still becomes real functions instead of one
	# hairy body reverting the whole file. Only a trailing subset can lift at all: emission places
	# sheet.functions after the in-place raw rows, so a raw leftover BETWEEN lifted functions would
	# reorder the file (the byte-verify at the end still gates whatever the scan produced).
	var lifted_events: Array = []
	var lifted_functions: Array = []
	var lifted_comments: Array = []
	var saw_function: bool = false
	var anchor_index: int = first_run_index
	# The blank-line count separating the previous lifted function from the next one. Emission re-adds a
	# single blank by default; this carries the SOURCE count so a hand-written two-blank gap round-trips.
	# It survives ONLY from a "blank" row to the immediately following row (the "blank" branch continues
	# past the end-of-body reset below); every other row type clears it.
	var pending_blank_count: int = 0
	for index in range(first_run_index, sheet.events.size()):
		var row: RawCodeRow = sheet.events[index] as RawCodeRow
		var failed: bool = false
		match _run_row_kind(row.code, lift_functions):
			"blank":
				# N blank lines import as a joined "\n"*(N-1) block, so size() == N. Stamped onto the next
				# lifted function's first event below; the compiler re-emits it on the external path.
				pending_blank_count = row.code.split("\n").size()
				continue  # separator; emission re-adds it
			"annotations":
				pending_annotations = _parse_annotations(row.code)
				pending_annotation_lines = _collect_gd_annotation_lines(row.code)
				pending_doc_comment = _collect_doc_comment_text(row.code)
				if pending_annotations.is_empty() and pending_annotation_lines.is_empty() and pending_doc_comment.is_empty():
					failed = true
			"comments":
				# Trailing top-level comments (deferred emission): one CommentRow per
				# blank-separated chunk.
				for chunk: String in row.code.strip_edges().split("\n\n"):
					var comment: CommentRow = CommentRow.new()
					comment.text = chunk.trim_prefix("# ").replace("\n# ", "\n")
					lifted_comments.append(comment)
			"func":
				var header: String = row.code.split("\n")[0]
				if LIFECYCLE_TRIGGERS.has(header) or _is_connected_handler(header, connections):
					if not pending_annotations.is_empty() or not pending_annotation_lines.is_empty() or not pending_doc_comment.is_empty():
						failed = true  # a lifecycle handler lifts to events, not an EventFunction, so it can't carry a doc
					else:
						# Lenient ifs: unmatched control flow becomes in-flow GDScript inside
						# the event instead of failing the file (byte-verify still gates).
						var lift: Dictionary = _lift_function(row.code.split("\n"), connections, true)
						if bool(lift.get("ok", false)):
							saw_function = true
							var lift_events: Array = lift.get("events", [])
							# Preserve the source's inter-function spacing: stamp the gap count onto this
							# function's FIRST event (only when >1, so ordinary single-blank sources stay
							# meta-free). The first lifted function's gap is owned by the boundary-detach path
							# below, so this only governs gaps BETWEEN lifted sections and never double-counts.
							if pending_blank_count > 1 and not lift_events.is_empty() and lift_events[0] is EventRow:
								(lift_events[0] as EventRow).set_meta("__source_leading_blanks", pending_blank_count)
							lifted_events.append_array(lift_events)
						else:
							failed = true
				else:
					if not lift_functions:
						failed = true  # event-only pass: helper funcs stay raw; the run restarts after
					else:
						var function_lift: Dictionary = _lift_sheet_function(row.code.split("\n"), pending_annotations, false, pending_annotation_lines, pending_doc_comment)
						pending_annotations = {}
						pending_annotation_lines = PackedStringArray()
						pending_doc_comment = ""
						if bool(function_lift.get("ok", false)):
							saw_function = true
							var lifted_function: Variant = function_lift.get("function")
							# Same source-spacing preservation as the trigger branch, for a helper/sheet function:
							# stamp the gap count so a hand-written two-blank gap before a helper round-trips.
							# Only when >1; the first lifted function's gap lives in the prelude (boundary-detach),
							# never a "blank" row here, so it is never stamped and can't double-count.
							if pending_blank_count > 1 and lifted_function is EventFunction:
								(lifted_function as EventFunction).set_meta("__source_leading_blanks", pending_blank_count)
							lifted_functions.append(lifted_function)
						else:
							failed = true
			_:
				failed = true
		if failed:
			# This row (and everything collected before it) stays raw; restart the run after it.
			lifted_events.clear()
			lifted_functions.clear()
			lifted_comments.clear()
			pending_annotations = {}
			pending_annotation_lines = PackedStringArray()
			pending_doc_comment = ""
			saw_function = false
			anchor_index = index + 1
		# A blank separator's count was just consumed by (or is irrelevant to) this non-blank row - clear it
		# so it never leaks onto a later function. The "blank" branch continues past here, keeping its count.
		pending_blank_count = 0
	var trailing_lifted: bool = saw_function and not (lifted_events.is_empty() and lifted_functions.is_empty())
	var backup: Array[Resource] = sheet.events.duplicate()
	var functions_backup: Array[Resource] = sheet.functions.duplicate()
	var boundary: RawCodeRow = null
	var boundary_code: String = ""
	if trailing_lifted:
		# The boundary-annotation split (glued to the prelude row) belongs to the FIRST run function -
		# it only applies when the anchor never moved past it.
		if anchor_index != first_run_index:
			boundary_annotations_text = ""
		sheet.events.resize(anchor_index)
		# Emission inserts one blank line before each section; the import attached that blank
		# (and possibly the first function's annotation block) to the preceding row, so drop
		# them to avoid doubling. The backup array is SHALLOW - the boundary row's original
		# code must be restored explicitly on revert.
		if not sheet.events.is_empty() and sheet.events[sheet.events.size() - 1] is RawCodeRow:
			boundary = sheet.events[sheet.events.size() - 1] as RawCodeRow
			boundary_code = boundary.code
			if not boundary_annotations_text.is_empty() and boundary.code.ends_with(boundary_annotations_text):
				boundary.code = boundary.code.substr(0, boundary.code.length() - boundary_annotations_text.length())
			if boundary.code.ends_with("\n"):
				boundary.code = boundary.code.substr(0, boundary.code.length() - 1)
			elif boundary.code.strip_edges().is_empty():
				sheet.events.remove_at(sheet.events.size() - 1)
		# Reconstruct event groups from the recovered `## @ace_group` declarations + the per-row `# @group:`
		# tags the lift captured (transient meta on the rows). A no-op when the source declares no groups.
		lifted_events = _reconstruct_groups(lifted_events, _recover_group_declarations(source))
		for event: Variant in lifted_events:
			sheet.events.append(event)
		for comment: Variant in lifted_comments:
			sheet.events.append(comment)
		for function: Variant in lifted_functions:
			sheet.functions.append(function)

	# MID-FILE helper functions: the trailing run above can only lift functions at the file's
	# end (they emit in the trailing functions section). A helper stranded between raw blocks
	# lifts here instead, anchored in place: its row becomes a FunctionAnchorRow and the
	# external compile path emits the function AT THAT SLOT. Each candidate is gated
	# individually - it anchors only when the compiler's re-emission reproduces the row's bytes
	# exactly - so this pass can never regress a file that already lifts (a failed candidate
	# just stays a raw block). Runs after the backup above, so the whole-file revert undoes it.
	var anchored_count: int = 0
	if lift_functions:
		for mid_index in range(sheet.events.size()):
			var mid_row: RawCodeRow = sheet.events[mid_index] as RawCodeRow
			if mid_row == null or not (mid_row.code.begins_with("func ") or mid_row.code.begins_with("static func ")):
				continue
			var mid_header: String = mid_row.code.split("\n")[0]
			if LIFECYCLE_TRIGGERS.has(mid_header) or _is_connected_handler(mid_header, connections):
				continue
			# Engine virtual callbacks are STRUCTURE, not sheet vocabulary: `_enter_tree` is the
			# host binding (folds to metadata on open), `_get_configuration_warnings` is the
			# requires-behavior guard, and so on. Lifting one to an editable EventFunction would
			# hide load-bearing boilerplate inside the Functions panel. Private HELPERS
			# (`_get_pool`) still lift - only known virtual names are excluded.
			if _is_engine_virtual_header(mid_header):
				continue
			# A `## @ace_*` block right above belongs to this function (exposure metadata); the
			# trailing scan owns that flow - anchoring would silently orphan the annotations.
			if mid_index > 0 and sheet.events[mid_index - 1] is RawCodeRow:
				var previous_lines: PackedStringArray = (sheet.events[mid_index - 1] as RawCodeRow).code.strip_edges().split("\n")
				if previous_lines[previous_lines.size() - 1].strip_edges().begins_with("## @ace_"):
					continue
			var mid_lift: Dictionary = _lift_sheet_function(mid_row.code.split("\n"), {}, true)
			if not bool(mid_lift.get("ok", false)):
				continue
			var mid_function: EventFunction = mid_lift.get("function")
			if mid_function == null or SheetCompiler._find_function_by_name(sheet, mid_function.function_name) != null:
				continue
			if SheetCompiler.emit_function_block_text(mid_function, sheet) != mid_row.code:
				continue
			var anchor: FunctionAnchorRow = FunctionAnchorRow.new()
			anchor.function_name = mid_function.function_name
			sheet.events[mid_index] = anchor
			sheet.functions.append(mid_function)
			anchored_count += 1
	if not trailing_lifted and anchored_count == 0:
		# Nothing lifted anywhere and nothing was mutated - same exit the trailing-only lift had.
		return _retry_or_fail(sheet, source, lift_functions) if anchor_index != first_run_index else false

	# Verify: the lifted sheet must reproduce the source byte-for-byte.
	var saved_path: String = sheet.external_source_path
	sheet.external_source_path = "user://eventforge_lift_verify.gd"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_lift_verify.gd").get("output", ""))
	sheet.external_source_path = saved_path
	# Group markers (## @ace_group declarations + # @group:<slug> row tags) are cosmetic comments with
	# zero runtime weight - the groups dissolve into the flat trigger sections at compile, so a sheet
	# whose groups interleave within one trigger bucket may re-emit a marker in a slightly different
	# place. Strip them from BOTH sides before the byte-compare so such a sheet still lifts (with
	# approximate grouping) rather than falling back to a verbatim block; the runtime-bearing code
	# still has to match exactly. When a sheet has no groups this strips nothing (identity compare).
	if _strip_group_markers(output) == _strip_group_markers(source):
		return true
	if OS.get_environment("EVENTFORGE_LIFT_DEBUG") == "1":
		var src_lines: PackedStringArray = source.split("\n")
		var out_lines: PackedStringArray = output.split("\n")
		for diff_index in range(mini(src_lines.size(), out_lines.size())):
			if src_lines[diff_index] != out_lines[diff_index]:
				print("[lift-debug] FIRST DIFF line ", diff_index + 1)
				print("[lift-debug]   src: <", src_lines[diff_index], ">")
				print("[lift-debug]   out: <", out_lines[diff_index], ">")
				# Print surrounding OUTPUT context so the mis-emitted construct is identifiable.
				for context_index in range(maxi(diff_index - 6, 0), mini(diff_index + 3, out_lines.size())):
					print("[lift-debug]   out L", context_index + 1, ": <", out_lines[context_index], ">")
				break
		print("[lift-debug] src=", src_lines.size(), " out=", out_lines.size(), " lines")
	sheet.events = backup
	sheet.functions = functions_backup
	if boundary != null:
		boundary.code = boundary_code
	return _retry_or_fail(sheet, source, lift_functions)


## Godot engine virtual callbacks by header name - excluded from the mid-file anchor lift (they
## are structural boilerplate, not vocabulary; several are regenerated from sheet metadata).
static func _is_engine_virtual_header(header: String) -> bool:
	# Strip a leading `static ` so the name extraction (substr past "func ") works for a static engine
	# hook like `_static_init`, which stays structural boilerplate rather than an editable row.
	var bare: String = header.substr(7) if header.begins_with("static func ") else header
	var name_end: int = bare.find("(")
	if name_end < 0:
		return false
	var function_name: String = bare.substr(5, name_end - 5).strip_edges()
	return function_name in [
		"_init", "_static_init", "_ready", "_enter_tree", "_exit_tree", "_process", "_physics_process",
		"_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input", "_gui_input",
		"_draw", "_notification", "_get_configuration_warnings", "_to_string",
		"_get_property_list", "_validate_property", "_property_can_revert", "_property_get_revert",
		"_integrate_forces", "_physics_process_internal",
	]


## The two-pass fallback: a failed full lift retries event-only before giving up, so the
## function/comment upgrades can never regress what already lifted before them.
static func _retry_or_fail(sheet: EventSheetResource, source: String, lift_functions: bool) -> bool:
	if lift_functions:
		return attempt_lift(sheet, source, false)
	return false


## Removes the cosmetic event-group marker lines (`## @ace_group(…)` declarations and `# @group:<slug>`
## row tags) so the lift's byte-verify compares only the runtime-bearing code. Stripping nothing when a
## sheet has no groups, so it leaves the strict byte-compare untouched for the common case.
static func _strip_group_markers(text: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("## @ace_group(") or trimmed.begins_with("# @group:"):
			continue
		kept.append(line)
	return "\n".join(kept)


## Recovers every `## @ace_group(uid="…", name="…", parent?, description?, color?, collapsed?,
## toggleable?)` declaration from the source into a {slug → fields} registry, the reverse of the
## compiler's _emit_group_declarations. Used to rebuild EventGroup resources during the lift.
static func _recover_group_declarations(source: String) -> Dictionary:
	var registry: Dictionary = {}
	var decl_regex: RegEx = RegEx.new()
	if decl_regex.compile("(?m)^## @ace_group\\((.*)\\)\\s*$") != OK:
		return registry
	for decl_match: RegExMatch in decl_regex.search_all(source):
		var fields: Dictionary = _parse_group_fields(decl_match.get_string(1))
		var slug: String = str(fields.get("uid", ""))
		if not slug.is_empty():
			registry[slug] = fields
	return registry


## Parses an @ace_group field list (`uid="x", name="y", collapsed=true`) into a typed dict: quoted
## values become Strings, bare true/false become bools. Tolerant of order + missing optional fields.
static func _parse_group_fields(inner: String) -> Dictionary:
	var fields: Dictionary = {}
	var field_regex: RegEx = RegEx.new()
	if field_regex.compile("([a-z_]+)=(\"[^\"]*\"|true|false)") != OK:
		return fields
	for field_match: RegExMatch in field_regex.search_all(inner):
		var key: String = field_match.get_string(1)
		var raw: String = field_match.get_string(2)
		if raw == "true":
			fields[key] = true
		elif raw == "false":
			fields[key] = false
		else:
			fields[key] = raw.substr(1, raw.length() - 2)  # strip the surrounding quotes
	return fields


## Rebuilds EventGroup resources from the flat lifted event list using the recovered `## @ace_group`
## registry - the reverse of the compiler dissolving groups into the trigger sections. Each EventRow
## carrying the transient `__group_slug` meta is routed into its group; a group nests under its parent
## by slug, and its top-level ancestor is inserted into the output at the position its first member is
## met. Ungrouped events keep their place. Groups whose rows scatter across trigger buckets reconstruct
## approximately (member order may differ) - the byte-verify in attempt_lift gates the whole thing, so
## a mis-grouping reverts to verbatim rather than corrupting. Returns the new top-level events array.
static func _reconstruct_groups(events: Array, registry: Dictionary) -> Array:
	if registry.is_empty():
		return events
	var groups: Dictionary = {}      # slug -> EventGroup
	var parent_of: Dictionary = {}   # slug -> parent slug ("" = top level)
	for slug: String in registry:
		var fields: Dictionary = registry[slug]
		var group: EventGroup = EventGroup.new()
		group.group_name = str(fields.get("name", slug))
		group.name = group.group_name
		group.description = str(fields.get("description", ""))
		group.color_tag = str(fields.get("color", ""))
		group.collapsed = bool(fields.get("collapsed", false))
		group.expanded = not group.collapsed
		group.runtime_toggleable = bool(fields.get("toggleable", false))
		groups[slug] = group
		parent_of[slug] = str(fields.get("parent", ""))
	var output: Array = []
	var placed: Dictionary = {}       # slug -> true once its subtree is linked into output/parent
	for event: Variant in events:
		var slug: String = ""
		if event is EventRow and (event as EventRow).has_meta("__group_slug"):
			slug = str((event as EventRow).get_meta("__group_slug"))
			(event as EventRow).remove_meta("__group_slug")
		if slug.is_empty() or not groups.has(slug):
			output.append(event)
			continue
		(groups[slug] as EventGroup).events.append(event)
		# Link this group's ancestor chain into place on first encounter: the group nests into its
		# parent's events (or lands in the output if top-level), walking up until an already-placed
		# ancestor or the top level.
		var chain_slug: String = slug
		while not chain_slug.is_empty() and not bool(placed.get(chain_slug, false)):
			placed[chain_slug] = true
			var parent_slug: String = str(parent_of.get(chain_slug, ""))
			if parent_slug.is_empty() or not groups.has(parent_slug):
				output.append(groups[chain_slug])
			else:
				(groups[parent_slug] as EventGroup).events.append(groups[chain_slug])
			chain_slug = parent_slug
	return output


## Build-time de-coding for behaviour packs: replaces each sheet function's single-RawCode body with
## lifted ACE rows (the same reverse grammar that opens a .gd as events), kept ONLY when the whole
## sheet still recompiles BYTE-IDENTICALLY - a PER-FUNCTION gate, so one un-liftable body never reverts
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


## Build-time de-coding for EVENT bodies - the sibling of lift_function_bodies, for sheet.events.
## An event whose body is a single verbatim RawCode block (e.g. a behaviour's OnProcess /
## OnPhysicsProcess tick) is reverse-lifted into the SAME ordered row list a function body uses, then
## folded into the event's sub_events (the compiler walks sub_events in order: a condition-less row
## emits its actions inline, a conditioned row emits if/elif/else). Kept ONLY when the whole sheet
## still recompiles BYTE-IDENTICALLY - a PER-EVENT gate, so one stubborn body never reverts the rest.
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
## of a code cell. The declarations relocate to the compiler's signal prelude - behaviour-identical,
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
			sheet.events = backup  # reorder/spacing changed - keep the verbatim block (round-trip safe)
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
## At pack-build time the .gd regenerates (byte_gated=false) - exposed functions gain the sheet's
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
		if (line.begins_with("func ") or line.begins_with("static func ")) and line.strip_edges().ends_with(":"):
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
			var has_ace_directive: bool = false
			for lead_line: String in lead:
				if lead_line.strip_edges().begins_with("##"):
					ace_block.append(lead_line)
					if lead_line.strip_edges().begins_with("## @"):
						has_ace_directive = true
				else:
					plain_comments.append(lead_line.strip_edges().trim_prefix("#").strip_edges())
			var annotations: Dictionary = _parse_annotations("\n".join(ace_block)) if not ace_block.is_empty() else {}
			if has_ace_directive and annotations.is_empty():
				# `## @` directives were present but the block wasn't recognized (e.g. @ace_name
				# without a type marker): lifting would silently eat them. Keep it all verbatim.
				for lead_line: String in lead:
					remainder.append(lead_line)
				for function_line: String in function_lines:
					remainder.append(function_line)
				i = k
				continue
			# An un-annotated function's plain `##` lines are its Godot doc comment: carry them onto
			# the EventFunction so re-emission keeps them (they used to be dropped here). A recognized
			# annotation block instead folds them into the ACE description inside _parse_annotations.
			var doc_comment: String = "" if has_ace_directive else _collect_doc_comment_text("\n".join(ace_block))
			var lift: Dictionary = _lift_sheet_function(function_lines, annotations, false, PackedStringArray(), doc_comment)
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


## True for a leading GDScript annotation that decorates a FUNCTION (`@rpc`, `@warning_ignore`, `@abstract`,
## `@static_unload`, ...). Excludes variable annotations (`@export`/`@onready var ...`), which lift as their
## own LocalVariable rows, so this never steals a variable's annotation.
static func _is_function_annotation_line(line: String) -> bool:
	var text: String = line.strip_edges()
	return text.begins_with("@") and not text.begins_with("@export") and not text.begins_with("@onready")


## The function-annotation lines of a block, verbatim and in order (the `@rpc(...)` etc. that ride onto the
## next function as EventFunction.annotation_lines). Skips `## @ace_*` doc lines and blanks.
static func _collect_gd_annotation_lines(code: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line: String in code.split("\n"):
		if _is_function_annotation_line(line):
			out.append(line)
	return out


## The Godot DOC-comment text of a block (plain `##` lines that are NOT `## @ace_*` directives), stripped of
## the `## ` prefix and joined - what rides onto the next function as EventFunction.doc_comment. Returns ""
## when the block carries no plain doc lines. A block of ONLY doc lines is a documented plain helper.
static func _collect_doc_comment_text(code: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in code.split("\n"):
		var text: String = line.strip_edges()
		if line == "##":
			out.append("")  # a bare `##` is a blank doc line (a paragraph break)
		elif line.begins_with("## ") and not text.begins_with("## @"):
			out.append(line.substr(3))  # drop the "## " prefix
	return "\n".join(out)


## Classifies a trailing-run row: "func", "annotations" (## @ace and/or @rpc-style annotation block),
## "blank", "comments" (top-level # lines), or "other" (breaks the run).
static func _run_row_kind(code: String, lift_functions: bool) -> String:
	if code.begins_with("func ") or code.begins_with("static func "):
		return "func"
	if code.strip_edges().is_empty():
		return "blank"
	var saw_annotation: bool = false
	var saw_gd_annotation: bool = false
	var saw_comment: bool = false
	for line: String in code.split("\n"):
		if line.strip_edges().is_empty():
			continue
		if line.begins_with("## "):
			saw_annotation = true
		elif line.begins_with("# "):
			saw_comment = true
		elif _is_function_annotation_line(line):
			saw_gd_annotation = true  # @rpc / @warning_ignore / ... - rides onto the next function
		else:
			return "other"
	if (saw_annotation or saw_gd_annotation) and not saw_comment and lift_functions:
		return "annotations"
	if saw_comment and not saw_annotation and not saw_gd_annotation and lift_functions:
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
	var fields: Dictionary = {"expose": false, "name": "", "category": "", "description": "", "display_template": "", "param_options": {}, "param_hints": {}}
	var recognized: bool = false
	var doc_lines: PackedStringArray = PackedStringArray()
	for line: String in code.split("\n"):
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		if text == "## @ace_hidden":
			recognized = true
		elif text == "## @ace_featured":
			fields["featured"] = true
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
		elif text.begins_with("## @ace_display_template(\"") and text.ends_with("\")"):
			fields["display_template"] = text.substr(26, text.length() - 28)
		elif text.begins_with("## @ace_param_options(") and text.ends_with(")"):
			# `@ace_param_options(mode add, multiply, override)` -> dropdown options; carried
			# onto the lifted param so emission ships them (they used to be dropped here,
			# silently unpublishing the whole function).
			var options_inner: String = text.substr(22, text.length() - 23)
			var options_space: int = options_inner.find(" ")
			if options_space > 0:
				var option_values: Array = []
				for value: String in options_inner.substr(options_space + 1).split(","):
					option_values.append(value.strip_edges())
				(fields["param_options"] as Dictionary)[options_inner.substr(0, options_space)] = option_values
		elif text.begins_with("## @ace_param_hint(") and text.ends_with(")"):
			# `@ace_param_hint(amount expression)` -> the params-dialog widget hint.
			var hint_inner: String = text.substr(19, text.length() - 20)
			var hint_space: int = hint_inner.find(" ")
			if hint_space > 0:
				(fields["param_hints"] as Dictionary)[hint_inner.substr(0, hint_space)] = hint_inner.substr(hint_space + 1).strip_edges()
		elif text.begins_with("## @ace_codegen_template("):
			pass  # regenerated from the function shape; byte-verify confirms it matches
		elif text.begins_with("## @ace_icon("):
			pass  # regenerated from the sheet's custom_class_icon; byte-verify confirms
		elif text.begins_with("## @"):
			# An @ace annotation this parser doesn't know - refuse the block rather than
			# silently dropping information.
			return {}
		else:
			# A plain doc comment above the annotations - the human description. Folded into
			# the ACE description (doc-comment-as-description), never a reason to refuse.
			doc_lines.append(text.trim_prefix("##").strip_edges())
	if str(fields["description"]).is_empty() and not doc_lines.is_empty():
		fields["description"] = " ".join(doc_lines)
	return fields if recognized else {}


## A non-trigger function → EventFunction (sheet function), body parsed with the same
## grammar as event bodies (events without triggers). {} fields come from the preceding
## annotation block (every generated sheet function has one: @ace_action… or @ace_hidden).
static func _lift_sheet_function(function_lines: PackedStringArray, annotations: Dictionary, allow_custom_return: bool = false, annotation_lines: PackedStringArray = PackedStringArray(), doc_comment: String = "") -> Dictionary:
	# A generated sheet function always carries an annotation block (@ace_action… or @ace_hidden); a
	# hand-written helper in an opened .gd has none. Both lift - the un-annotated one becomes an
	# un-exposed function whose @ace_hidden emission is suppressed (lifted_unannotated), so it
	# round-trips byte-identically. Needs an explicit `-> Type:` header (the regex below); a
	# return-type-less `func foo():` still falls back to a verbatim block.
	var unannotated: bool = annotations.is_empty()
	var header_regex: RegEx = RegEx.new()
	# Optional non-emitting `(static )?` prefix (group 1) shifts the name/args/return captures to 2/3/4.
	header_regex.compile("^(static )?func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\) -> ([A-Za-z_][A-Za-z0-9_]*):$")
	var header_match: RegExMatch = header_regex.search(function_lines[0])
	if header_match == null:
		return {"ok": false}
	var event_function: EventFunction = EventFunction.new()
	event_function.lifted_unannotated = unannotated
	event_function.annotation_lines = annotation_lines
	event_function.doc_comment = doc_comment
	event_function.is_static = not header_match.get_string(1).is_empty()
	event_function.function_name = header_match.get_string(2)
	var return_name: String = header_match.get_string(4) if header_match.get_group_count() >= 4 else "void"
	var return_types: Dictionary = {"void": TYPE_NIL, "bool": TYPE_BOOL, "int": TYPE_INT, "float": TYPE_FLOAT, "String": TYPE_STRING, "Vector2": TYPE_VECTOR2, "Vector3": TYPE_VECTOR3, "Color": TYPE_COLOR, "Array": TYPE_ARRAY, "Dictionary": TYPE_DICTIONARY, "Variant": TYPE_MAX}
	if return_types.has(return_name):
		event_function.return_type = return_types[return_name]
	elif allow_custom_return:
		# A custom / engine class the Variant.Type set can't name (`HealthPool`, `Camera2D`):
		# return_type_name carries it verbatim and the emitter re-emits it exactly. ONLY the
		# FunctionAnchorRow pass may take this branch - anchored emission stays in source
		# position and each anchor is byte-gated. The TRAILING scan must keep refusing these:
		# claiming a mid-run custom-return helper there re-emits it at the file's end, reorders
		# the output, fails the whole-file verify, and reverts EVERYTHING the run lifted
		# (health went 34 lifted functions -> 0 when this gate was opened for both paths).
		event_function.return_type = TYPE_MAX
		event_function.return_type_name = return_name
	else:
		return {"ok": false}
	for argument: String in header_match.get_string(3).split(", ", false):
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
			# An untyped parameter must STAY untyped: ACEParam defaults type_name to "String", which
			# would re-emit `final_value: String` for a source `final_value` and fail the byte-verify.
			# "Variant" is the emitter's render-bare sentinel, so the header round-trips exactly.
			param.type_name = "Variant"
		event_function.params.append(param)
	event_function.expose_as_ace = bool(annotations.get("expose", false))
	event_function.ace_display_name = str(annotations.get("name", ""))
	event_function.ace_category = str(annotations.get("category", ""))
	event_function.description = str(annotations.get("description", ""))
	event_function.display_template = str(annotations.get("display_template", ""))
	event_function.featured = bool(annotations.get("featured", false))
	# @ace_param_options / @ace_param_hint ride on the params themselves, so emission can
	# ship them back out and the picker gets its dropdowns and widgets.
	var lifted_param_options: Dictionary = annotations.get("param_options", {})
	var lifted_param_hints: Dictionary = annotations.get("param_hints", {})
	for lifted_param: ACEParam in event_function.params:
		if lifted_param_options.has(lifted_param.id):
			for option_value: Variant in (lifted_param_options[lifted_param.id] as Array):
				lifted_param.options.append(str(option_value))
		if lifted_param_hints.has(lifted_param.id):
			lifted_param.hint = str(lifted_param_hints[lifted_param.id])
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


## One trigger function → {ok: bool, events: Array}. Recognizes lifecycle headers and -
## via the `_ready` connection map - signal handlers, which lift to signal-trigger events
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
		return {"ok": false}  # dedented/blank content inside a function - not our shape
	var events: Array = parsed.get("rows", [])
	for event: Variant in events:
		if _is_plain_collector(event as EventRow) and (event as EventRow).actions.is_empty():
			return {"ok": false}
	return {"ok": true, "events": events}


## Recursive body grammar (the reverse of _emit_event_body): at each depth,
## `if <conds>:` opens a conditioned row, an adjacent `elif <conds>:`/`else:` chains
## onto it via else_mode (ELSE + conditions == ELIF - the emitter's rule), and the
## block's own body parses one level deeper - statements become the row's actions,
## nested blocks its sub_events, and statements interleaved AFTER a nested block become
## condition-less sub_events (the emitter sequences them in place). Anything still
## unrepresentable (unmatched conditions, arbitrary control flow) falls back to the
## lenient path: the raw line + its deeper lines stay in-flow GDScript with their
## relative indentation, exactly as before this grammar existed. The byte-identical
## recompile in attempt_lift gates every shape this parser produces.
## Returns {ok, rows: Array[EventRow], next: int}; a "plain collector" row (no
## conditions, no else_mode) holds the statements between blocks.
static func _parse_body(lines: PackedStringArray, start: int, depth: int, trigger_id: String, trigger_provider: String, trigger_args: String, trigger_source: String, reverse_entries: Array, lenient_ifs: bool, in_loop: bool = false) -> Dictionary:
	var indent: String = "\t".repeat(depth)
	var rows: Array = []
	var current: EventRow = null
	var pending_raw: PackedStringArray = PackedStringArray()
	var chain_open: bool = false
	# An event-group marker (`# @group:<slug>`) the compiler emits before a grouped event's `if`,
	# captured here and stamped on the next opened event as transient meta - attempt_lift then rebuilds
	# real EventGroups from these. Skipping the line keeps it out of the lifted body; the group re-emits
	# it on recompile and the byte-verify strips group markers, so it still round-trips.
	var pending_group_slug: String = ""
	var index: int = start
	while index < lines.size():
		var line: String = lines[index]
		if line.strip_edges().is_empty():
			return {"ok": false}  # blank inside a generated body never happens; bail to blocks
		if not line.begins_with(indent):
			break  # dedent: this body is done; the caller resumes here
		var rest: String = line.substr(depth)
		if rest.begins_with("# @group:"):
			pending_group_slug = rest.substr(9)  # 9 == len("# @group:")
			index += 1
			continue
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
			if is_if and not pending_group_slug.is_empty():
				block_event.set_meta("__group_slug", pending_group_slug)
				pending_group_slug = ""
			if not is_if:
				block_event.else_mode = EventRow.ElseMode.ELSE
			var representable: bool = expression.is_empty() or _parse_conditions(expression, block_event, reverse_entries)
			var inner: Dictionary = {}
			if representable:
				# An `if` inherits the loop context of its parent (a break/continue inside it belongs to the
				# enclosing loop), so pass in_loop straight through.
				inner = _parse_body(lines, index + 1, depth + 1, "", "", "", "", reverse_entries, lenient_ifs, in_loop)
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
		# depth opens a pick-filter row whose body parses one level deeper - exactly the if/elif/else
		# grammar above, but the wrapper is a PickFilter, not conditions. _adopt_block_body folds the
		# body (leading statements → actions, nested blocks → sub_events); a statement AFTER a nested
		# block is unrepresentable (actions emit before sub-events) and falls to the lenient raw path.
		# Loop-index prelude (the emitter's exact three-line shape): `var X: int = -1` directly
		# above a loop whose body's FIRST line is `X += 1` lifts back into PickFilter.index_name -
		# the C3-style loopindex. All three lines must match or the var stays an ordinary statement.
		var loop_index_lift: String = ""
		if at_this_depth and index + 2 < lines.size():
			var index_probe: RegEx = RegEx.new()
			index_probe.compile("^var ([A-Za-z_][A-Za-z0-9_]*): int = -1$")
			var index_match: RegExMatch = index_probe.search(rest)
			if index_match != null:
				var candidate_name: String = index_match.get_string(1)
				var header_line: String = lines[index + 1]
				var header_at_depth: bool = header_line.begins_with(indent) and not header_line.substr(depth).begins_with("\t")
				var header_rest: String = header_line.substr(depth) if header_at_depth else ""
				var header_is_loop: bool = header_at_depth and ((header_rest.begins_with("for ") and header_rest.contains(" in ")) or header_rest.begins_with("while ")) and header_rest.ends_with(":")
				var bump_expected: String = "\t".repeat(depth + 1) + candidate_name + " += 1"
				if header_is_loop and lines[index + 2] == bump_expected:
					loop_index_lift = candidate_name
					rest = header_rest
					index += 1  # the loop header takes over as the current line; body starts past the bump
		var is_for: bool = (at_this_depth or not loop_index_lift.is_empty()) and rest.begins_with("for ") and rest.contains(" in ") and rest.ends_with(":")
		var is_while: bool = (at_this_depth or not loop_index_lift.is_empty()) and rest.begins_with("while ") and rest.ends_with(":")
		if is_for or is_while:
			var loop_event: EventRow = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			var lifted_pick: PickFilter = _loop_pick_filter(rest, is_while)
			lifted_pick.index_name = loop_index_lift
			loop_event.pick_filters.append(lifted_pick)
			# The loop body IS a loop context: break/continue in it (or in an `if` nested in it) lift.
			# A lifted loop index skips its bump line - it regenerates from index_name on emit.
			var loop_inner: Dictionary = _parse_body(lines, index + (2 if not loop_index_lift.is_empty() else 1), depth + 1, "", "", "", "", reverse_entries, lenient_ifs, true)
			var loop_ok: bool = bool(loop_inner.get("ok", false)) and _adopt_block_body(loop_event, loop_inner.get("rows", []))
			if not loop_ok:
				if not lenient_ifs:
					return {"ok": false}
				# Raw fallback: the header joins the open collector; its deeper lines arrive
				# through the statement branch below, tabs preserved (same as if/elif/else).
				# A consumed loop-index prelude re-joins first so no source line is ever lost.
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					rows.append(current)
				if not loop_index_lift.is_empty():
					pending_raw.append("var %s: int = -1" % loop_index_lift)
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
		# become a MatchRow ACTION - subject + verbatim branch text, exactly as the emitter re-prefixes
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
				# Structured lift: parse the branch text into first-class cases (pattern + body) so the switch
				# reads and (later) edits as event-sheet blocks, not a text blob. Byte-gated - the cases are
				# only taken when re-emitting them reproduces the branch text exactly; otherwise the verbatim
				# branches_text stands (the raw fallback), so this never risks the round-trip.
				match_row.cases = _structure_match_cases(branch_lines)
				current.actions.append(match_row)
				index = scan
				chain_open = false
				continue
			# An empty arm list isn't our shape - fall through and treat `match …:` as a raw line.
		# Statement at this depth (or deeper, inside an unlifted block): collect with
		# relative indentation intact.
		if current == null:
			current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			rows.append(current)
		if at_this_depth:
			_consume_action_line(current, rest, 0, pending_raw, reverse_entries, in_loop)
		else:
			# A DEEPER line lives inside an unlifted control block above it. Template-matching it
			# would tear it out as a standalone ACTION that re-emits at the event's depth - one tab
			# shallower than the source - and fail the byte-verify. Keep it raw, tabs intact.
			pending_raw.append(rest)
		index += 1
		chain_open = false
	_flush_raw(current, pending_raw)
	return {"ok": true, "rows": rows, "next": index}


## Parses a match's dedented branch lines (patterns at column 0, bodies one tab deeper) into structured
## MatchCases (pattern + a RawCodeRow body dedented one more tab). Returns [] - so the caller keeps the
## verbatim branches_text - unless the parse is clean AND re-emitting the cases reproduces the branch lines
## byte-for-byte (the verify-lift gate: a case body compiles at pattern-indent + one tab, exactly where the
## branch line sat, so a structured re-emit equals the raw one, and the whole-match round-trip is preserved).
static func _structure_match_cases(branch_lines: PackedStringArray) -> Array[MatchCase]:
	var cases: Array[MatchCase] = []
	var current_case: MatchCase = null
	var current_body: PackedStringArray = PackedStringArray()
	for line: String in branch_lines:
		if not line.begins_with("\t"):
			# A pattern line at column 0; it must end with ":" to be a branch head.
			if not line.ends_with(":"):
				return []
			if current_case != null:
				_finish_match_case(current_case, current_body)
				current_body = PackedStringArray()
			current_case = MatchCase.new()
			current_case.pattern = line.substr(0, line.length() - 1)
			cases.append(current_case)
		else:
			if current_case == null:
				return []  # a body line before any pattern - not a clean case list
			current_body.append(line.substr(1))  # dedent one tab, relative to its pattern
	if current_case != null:
		_finish_match_case(current_case, current_body)
	if cases.is_empty():
		return []
	# Every branch must carry a body (a match arm is never empty in real code) and re-emitting the cases must
	# reproduce the exact branch lines - otherwise fall back to the verbatim text so the round-trip is safe.
	for match_case: MatchCase in cases:
		if (match_case.events as Array).is_empty():
			return []
	if _reconstruct_match_branches(cases) != "\n".join(branch_lines):
		return []
	return cases


static func _finish_match_case(match_case: MatchCase, body: PackedStringArray) -> void:
	if body.is_empty():
		return
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "\n".join(body)
	match_case.events = [raw]


## Rebuilds the dedented branch-line text from structured cases (the inverse of _structure_match_cases): each
## `pattern:` line plus its body re-indented one tab. Used only to verify a structured lift is lossless.
static func _reconstruct_match_branches(cases: Array[MatchCase]) -> String:
	var out: PackedStringArray = PackedStringArray()
	for match_case: MatchCase in cases:
		out.append(match_case.pattern + ":")
		for item: Variant in match_case.events:
			if item is RawCodeRow:
				for code_line: String in (item as RawCodeRow).code.split("\n"):
					out.append("\t" + code_line)
	return "\n".join(out)


## Folds a parsed block body into its event: a LEADING plain collector's statements become the event's
## actions, every conditioned/chained/loop row becomes a sub-event, and a plain collector that appears
## AFTER a block becomes a condition-less sub-event too. The emitter sequences actions-then-(blocks
## interleaved with condition-less collectors) at the parent's body depth, so `do A; if C: D; do E` reads
## as actions=[A] + sub_events=[if C -> D, condition-less -> E] and re-emits byte-exact - a post-block
## statement no longer collapses the whole block to a verbatim cell. The byte-verify still gates it.
static func _adopt_block_body(block_event: EventRow, inner_rows: Array) -> bool:
	var cursor: int = 0
	if cursor < inner_rows.size() and _is_plain_collector(inner_rows[cursor] as EventRow):
		for action: Variant in (inner_rows[cursor] as EventRow).actions:
			block_event.actions.append(action)
		cursor += 1
	while cursor < inner_rows.size():
		var child: EventRow = inner_rows[cursor] as EventRow
		# An empty plain collector can't arise from _parse_body (collectors are created lazily on a
		# consumed statement); bail defensively rather than emit a stray no-op sub-event.
		if _is_plain_collector(child) and child.actions.is_empty():
			return false
		block_event.sub_events.append(child)
		cursor += 1
	return true


## A "plain collector" holds only the loose statements between blocks - no conditions, no loop
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
	# Needs at least one char between the parens - a bare `range()` is invalid GDScript and would
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


## Splits a joined condition on a TOP-LEVEL separator (" and " or " or ") only - ignoring the separator
## inside (), [], {} or a string literal - so a compound term like `f(a and b)`, `x == "a or b"`, or
## `not (a and b)` stays ONE condition. The naive String.split(sep) fragmented these into garbage
## Expression-Is-True rows ("f(a", "b)"); each piece still round-tripped when rejoined, but the structure
## was nonsense. (Both separators start with a space, so the `c == " "` guard covers either.)
static func _split_top_level(expression: String, sep: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var start: int = 0
	var i: int = 0
	var n: int = expression.length()
	var sep_len: int = sep.length()
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
		elif depth == 0 and c == " " and expression.substr(i, sep_len) == sep:
			parts.append(expression.substr(start, i - start))
			i += sep_len
			start = i
			continue
		i += 1
	parts.append(expression.substr(start))
	return parts


## Splits a joined condition expression into terms and reverse-matches every term (supporting `not (...)`
## negation), setting the event's AND/OR condition_mode. All terms must match or the lift fails - though
## the generic Expression Is True condition (bare {expr}) catches any term no specific ACE claims. A
## top-level ` and ` takes precedence (GDScript binds `and` tighter than `or`), so ` or ` splitting fires
## only for a PURELY-OR expression (`a or b or c`, no top-level ` and `), which lifts as OR'd conditions -
## a C3-style "Or block". A mixed `a and b or c` keeps the ` and ` split, which still re-emits byte-exact.
static func _parse_conditions(expression: String, event: EventRow, reverse_entries: Array) -> bool:
	var terms: PackedStringArray = _split_top_level(expression, " and ")
	if terms.size() == 1:
		var or_terms: PackedStringArray = _split_top_level(expression, " or ")
		if or_terms.size() > 1:
			terms = or_terms
			event.condition_mode = EventRow.ConditionMode.OR
	for term: String in terms:
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
static func _consume_action_line(event: EventRow, line: String, _depth: int, pending_raw: PackedStringArray, reverse_entries: Array, in_loop: bool = false) -> void:
	var matched: Dictionary = _match_entry(line, reverse_entries, "action", in_loop)
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
	# (non-emitted - never affects the byte-exact round-trip) so the editor can show an
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
		# ({code}, math expressions) that would shadow specific ACEs - kept out of the reverse index.
		# EXCEPT the statement catch-alls, admitted at LOWEST specificity (the literal_len sort at the
		# bottom puts them after every specific ACE) so they reverse-lift only what nothing else claims:
		# Set Property (`{target}.{property} = {value}`) and its compound-assign twins (`+= -= *= /=`),
		# Call Method (`{target}.{method}({args})`) (Stage B), plus Set Local Variable (`var {name} = {value}`)
		# and its typed/inferred siblings (Stage D) AND their `const` twins (`const {name} = {value}`, typed,
		# inferred), so a local declaration or constant in a hand-written body becomes a row, not a code cell.
		# Each has more literal chars than the bare-var forms, so `self.x += 1` prefers the property twin over
		# Add Variable, and typed outranks plain (`const N: int = 3` binds name="N"). Byte-verify gates all.
		if descriptor.category == "Helpers" and not (descriptor.ace_id in ["SetProperty", "AddToProperty", "SubtractFromProperty", "MultiplyProperty", "DivideProperty", "CallMethod", "SetLocalVar", "SetLocalVarTyped", "SetLocalVarInferred", "SetLocalConst", "SetLocalConstTyped", "SetLocalConstInferred"]):
			continue
		# `break` / `continue` are admitted but tagged loop_control: _match_entry only claims them inside a
		# lifted loop body (they are invalid GDScript anywhere else), so they never mis-claim a bare keyword
		# at function scope. (`pass` has no ACE - the compiler emits it only as an empty-body stub, so there
		# is nothing to reverse-lift and an empty block stays empty rather than gaining a spurious action.)
		var loop_control: bool = template in ["break", "continue"]
		var kind: String = ""
		match descriptor.ace_type:
			ACEDescriptor.ACEType.CONDITION:
				kind = "condition"
			ACEDescriptor.ACEType.ACTION:
				kind = "action"
			_:
				continue
		# Optional-prefix `{target.}` templates compile to two shapes - the blank-target host form
		# (`play()`) and the set-target form (`$Enemy.play()`) - so register a reverse entry for each.
		for variant: String in _optional_prefix_variants(template):
			var regex: RegEx = _template_to_regex(variant)
			if regex == null:
				continue
			var literal_len: int = brace_regex.sub(variant, "", true).length()
			# A compound-assign template (`… += …`) can match a PLAIN assignment whose string value happens
			# to contain the operator (`label.text = "score += 1"`), producing a byte-identical but wrong row.
			# Record the operator so _match_entry can reject that case and fall through to Set Property / Set
			# Variable. (A real lvalue never has a plain ` = ` before the operator.)
			var assign_op: String = ""
			for op: String in [" += ", " -= ", " *= ", " /= ", " %= "]:
				if variant.contains(op):
					assign_op = op
					break
			# A local declaration template (`var {name}…` / `const {name}…`) whose `{name}` capture is lazy
			# `.+?` can mis-carve a string value that contains `:`/`=` (a typed const `const S: T = V` regex
			# eats `const FMT = "a: b = c"` into name=`FMT = "a`). Flag it so _match_entry rejects any match
			# whose captured name is not a bare identifier, letting the plain (correct) template win.
			var decl_name: bool = variant.begins_with("var ") or variant.begins_with("const ")
			entries.append({"provider": descriptor.provider_id, "ace_id": descriptor.ace_id, "kind": kind, "regex": regex, "literal_len": literal_len, "order": entries.size(), "assign_op": assign_op, "loop_control": loop_control, "decl_name": decl_name})
	# Try SPECIFIC templates before generic catch-alls. The Core generics (SetVar `{var_name} = {value}`,
	# CallFunction `{function_name}({args})`, …) use lazy `.+?` captures that match almost any
	# assignment/call, so in raw registry order they SHADOW every specific node ACE (`position = …`
	# would reverse-lift as SetVar). _match_entry is first-match, so stable-sort by literal-char count
	# (descending) - `velocity = {vel}` outranks `{var_name} = {value}`; the `order` tiebreaker keeps
	# registry order among equal-specificity twins (sort_custom is not guaranteed stable).
	entries.sort_custom(func(a, b): return a["literal_len"] > b["literal_len"] if a["literal_len"] != b["literal_len"] else a["order"] < b["order"])
	return entries


static func _match_entry(line: String, reverse_entries: Array, kind: String, in_loop: bool = true) -> Dictionary:
	for entry: Variant in reverse_entries:
		if str((entry as Dictionary).get("kind", "")) != kind:
			continue
		# A loop-control action (`break`/`continue`) is only valid - and only lifts - inside a loop body.
		if bool((entry as Dictionary).get("loop_control", false)) and not in_loop:
			continue
		var regex: RegEx = (entry as Dictionary).get("regex")
		var regex_match: RegExMatch = regex.search(line)
		if regex_match == null:
			continue
		# Reject a compound-assign that only matched because the operator sits inside a plain assignment's
		# string value (`x = "a += b"`): a genuine `x += …` has no plain ` = ` before the operator.
		var assign_op: String = str((entry as Dictionary).get("assign_op", ""))
		if not assign_op.is_empty():
			var op_index: int = line.find(assign_op)
			if op_index != -1 and line.substr(0, op_index).contains(" = "):
				continue
		var params: Dictionary = {}
		for group_name: String in regex.get_names():
			params[group_name] = regex_match.get_string(group_name)
		# A declaration template's `{name}` must be a bare identifier - otherwise the lazy capture carved a
		# string/expression value at an internal `:` or `=` (see decl_name). Reject so the plain form wins.
		if bool((entry as Dictionary).get("decl_name", false)) and not _is_bare_identifier(str(params.get("name", ""))):
			continue
		return {"provider": (entry as Dictionary).get("provider"), "ace_id": (entry as Dictionary).get("ace_id"), "params": params}
	return {}


## True when the text is a single GDScript identifier (no spaces, operators, or quotes) - used to reject a
## declaration whose `{name}` capture actually swallowed part of a string/typed value.
static func _is_bare_identifier(text: String) -> bool:
	if text.is_empty():
		return false
	var regex: RegEx = RegEx.new()
	regex.compile("^[A-Za-z_][A-Za-z0-9_]*$")
	return regex.search(text) != null


## Expands an optional-prefix template `{name.}foo` into the two shapes it can compile to, so both
## round-trip: the blank-target form (`foo`) and the set-target form (`{name}.foo`, where `{name}`
## reverses to a named capture). Templates without `{name.}` pass through as a one-element list.
## (Multi-line `{name.}` templates also expand, but stay single-line-unmatchable like every multi-line
## template - harmless; they were never line-reversible.)
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
		# Call-argument captures may legitimately be empty - a zero-arg call like `landed.emit()`,
		# `jump()` or `super()` - so `{args}` uses a zero-or-more lazy capture; every other placeholder
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
