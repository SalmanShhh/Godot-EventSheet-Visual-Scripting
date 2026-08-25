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
# THE CONTRACT (lossless rule): every lift is verified by recompiling the whole sheet - if
# the output is not byte-identical to the source, the lift is reverted and every function
# stays a verbatim block row. Per-function byte gates screen each candidate FIRST (a function
# whose lifted form cannot re-emit its own bytes re-anchors alone as a verbatim block), so
# the whole-file verify is the backstop, not the everyday judge. Only the trailing run of
# trigger functions plus the mid-file anchor pass are considered (EventForge's own layout);
# files with other layouts simply keep their blocks.
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
	"func _unhandled_key_input(event: InputEvent) -> void:": "OnUnhandledKeyInput",
	# The callback a clickable body gets when input lands ON it. It is an input handler like the
	# three above - the body branches on the event exactly the same way - so it lifts to a trigger
	# rather than staying the raw handler it used to be.
	"func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:": "OnInputEvent",
	# The same callback for a UI element: input that landed on THIS Control, after the ones above
	# have passed on it. A tool's whole canvas is one of these, and it branches on the event exactly
	# like the handlers above, so it lifts to a trigger and its branches read as Mouse / Keyboard.
	"func _gui_input(event: InputEvent) -> void:": "OnControlInput",
	# The tree + paint callbacks. They carry authored logic as often as `_ready` does, so they read as
	# the object's own lifecycle triggers rather than as helper functions. `_enter_tree` is the one that
	# needs a body check as well as a header one: the host-binding boilerplate every host-targeting pack
	# emits wears the same header, and the compiler regenerates THAT from the sheet's host metadata, so
	# lifting it would emit the function twice (see _is_host_binding_body).
	"func _draw() -> void:": "OnDraw",
	"func _enter_tree() -> void:": "OnEnterTree",
	"func _exit_tree() -> void:": "OnExitTree",
	"func _run() -> void:": "OnEditorRun",
	"func _on_project_export(is_debug: bool, features: PackedStringArray) -> void:": "OnProjectExport",
	"func _on_files_imported(paths: PackedStringArray) -> void:": "OnFileImported",
	# The half of Make Noise that RECEIVES. A guard's `hear` is a handler the noise maker calls
	# by name, so an opened stealth script reads it as the reaction it is rather than as a helper.
	"func hear(at: Variant) -> void:": "OnNoiseHeard",
	# The same seam, twice more: an enemy told who to come for, and a door tried without
	# its key. Both are handlers something else calls by name, so an opened level reads them as the
	# reactions they are rather than as two helpers nobody can see the caller of.
	"func alerted(who: Variant) -> void:": "OnAlerted",
	"func locked_door_tried(key: Variant) -> void:": "OnLockedDoorTried",
	# The editor's own callbacks. An opened plugin or gizmo script is one of the least
	# readable files there is until these read as what the editor calls them for: an object was
	# selected, the 2D overlay is being painted, input landed in the viewport, a gizmo is redrawing.
	"func _edit(object: Object) -> void:": "OnEditorObjectSelected",
	"func _forward_canvas_draw_over_viewport(overlay: Control) -> void:": "OnDrawOver2DViewport",
	"func _forward_canvas_gui_input(event: InputEvent) -> bool:": "On2DViewportInput",
	"func _redraw() -> void:": "OnDrawGizmo"
}

## The two tree callbacks that mean something DIFFERENT on an EditorPlugin: `_enter_tree` is not
## "on created" there, it is the moment the plugin was switched on. Keyed on the trigger the header
## table already resolved, so the rename is a display-level re-pin and the emitted function is the
## same one either way (see TriggerResolver).
const PLUGIN_LIFECYCLE_TRIGGERS: Dictionary = {
	"OnEnterTree": "OnPluginEnabled",
	"OnExitTree": "OnPluginDisabled"
}

## The class the file being lifted extends, as the importer read it off the `extends` line. Set by
## _attempt_lift_body around each lift and read by exactly one question: is this an EditorPlugin, so
## that `_enter_tree` reads as On plugin enabled rather than On created. Display-level attribution
## only - both trigger ids resolve to the same emitted `_enter_tree`, so a stale value cannot move a
## single byte of what the file compiles to.
static var _lift_host_class: String = ""

## ACEs whose template reads its TRIGGER'S OWN ARGUMENTS rather than the host, mapped to the trigger
## that supplies them. Such a template only compiles inside that handler, so it may only lift there:
## `is_debug` is a bare identifier with nine literal characters, so admitted to the index globally it
## outranks every generic reading and would claim `if is_debug:` in any game script, labelling the row
## "the export is a debug build". _match_entry drops a scoped entry everywhere else, which hands the
## line back to the generic conditions that used to take it (`is_debug` reads as Expression Is True,
## `features.has(x)` as Dict Has Key) - a wrong row is worse than a plain one.
## (Condition lifting carries the scope today; a scoped ACTION would simply never claim a line.)
const TRIGGER_SCOPED_ACES: Dictionary = {
	"ExportIsDebug": "OnProjectExport",
	"ExportHasFeature": "OnProjectExport",
}

## Async-open progress, published for the editor's "Opening <file>" strip. The lift can run on a
## worker thread (see EventSheetOpenJob) while the main thread paints, so these are DISPLAY ONLY:
## plain ints/strings written by the worker and read by the poller without a lock. A torn read
## shows a stale count for one frame and nothing else - no sheet data crosses this seam.
static var progress_phase: String = ""
static var progress_functions_total: int = 0
static var progress_functions_done: int = 0
## Set by the main thread to abandon the lift ("Show as code instead"). Checked before each
## function; the lift then reverts whatever it mutated and reports failure, so the caller keeps the
## raw (unlifted) sheet - exactly the state a file that cannot lift at all ends in.
static var cancel_requested: bool = false

## The res:// path of the file being lifted, when the caller knows it. Used for exactly one
## question the source text cannot answer: which scene(s) wire signals to this script, so a handler
## the Godot editor connected reads as the trigger it is rather than as a nameless helper. The
## importer sets it around the lift and clears it after; a caller that hands over a bare sheet with
## `external_source_path` already on it (the async open job) is picked up from there instead.
static var scene_source_path: String = ""


## The reverse index, shared by every caller that needs one (see _build_reverse_entries). Composing it
## compiles one RegEx per descriptor template - hundreds of them - so it is built once per descriptor
## set and handed out by reference. Keyed on the descriptor count so a rescan that publishes new ACEs
## rebuilds it.
static var _cached_reverse_entries: Array = []
## The loop-index prelude probe, compiled once (see _parse_body). Built on the main thread by
## warm_registries' reverse-index pass before the worker ever reads it.
static var _loop_index_probe: RegEx = null
static var _cached_reverse_count: int = -1

## Member names the file being lifted declares with an OBJECT type ({name: true}) - `var host: Node`,
## `@onready var cam: Camera2D`. Written by each lift entry point before it matches a line, and read
## only by _is_object_expression, which is what lets `candidate == host` stay an identity test while
## `i == 1` reads as the comparison it is. Display-level attribution only: both spellings emit the
## same `{a} == {b}` bytes, so a stale set can never change what a file compiles to.
static var _object_reference_names: Dictionary = {}

## GDScript's VALUE types - everything a `var x: T` can be annotated with that is NOT an object.
## Anything else (Node2D, PackedScene, Resource, a project class_name) is a reference, which is the
## only question _object_names_from_source asks.
const VALUE_TYPE_NAMES: Array[String] = [
	"bool", "int", "float", "String", "StringName", "NodePath", "RID", "Callable", "Signal",
	"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i",
	"Transform2D", "Transform3D", "Plane", "Quaternion", "AABB", "Basis", "Projection", "Color",
	"Array", "Dictionary", "Variant", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
	"PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
	"PackedVector3Array", "PackedVector4Array", "PackedColorArray"
]


## Lifts a run of DEDENTED body lines (a lambda body, a snippet) into event rows, exactly as a
## function body lifts: statements become actions, an `if`/`for`/`while` becomes a nested event.
## Nothing is written to a sheet and nothing is byte-verified, because nothing is being changed -
## this is for a reading of code that stays exactly where it is. Returns [] when the run does not
## lift cleanly.
static func lift_body_rows(body_lines: PackedStringArray, object_names: PackedStringArray = PackedStringArray()) -> Array:
	if body_lines.is_empty():
		return []
	# The caller knows the file's object-typed members; without them an identity test in a lambda
	# body would read differently from the identical line in a declared handler.
	_object_reference_names = {}
	for name: String in object_names:
		_object_reference_names[name] = true
	var parsed: Dictionary = _parse_body(
		body_lines, 0, 0, "", "", "", "", _build_reverse_entries(), true, false, "")
	if not bool(parsed.get("ok", false)):
		return []
	return parsed.get("rows", []) as Array


## Clears the progress/cancel state before a new open. Called on the MAIN thread by the job, never
## from attempt_lift itself - the event-only retry pass must not clear a cancel the user just asked for.
static func reset_progress() -> void:
	progress_phase = ""
	progress_functions_total = 0
	progress_functions_done = 0
	cancel_requested = false


## Attempts the lift on an imported external sheet. Mutates sheet.events only when the
## byte-identical round-trip verifies; otherwise leaves the sheet untouched.
## Two-pass: the full lift (events + sheet functions + trailing comments) is tried first;
## if its byte-verify fails (e.g. annotations we can't regenerate), the event-only lift is
## retried so files keep at least the coverage older versions had.
static func attempt_lift(sheet: EventSheetResource, source: String, lift_functions: bool = true) -> bool:
	# Only the OUTER pass owns the progress counters - the event-only retry below re-enters this
	# function and must not restart the bar the user is watching. The body has many early returns
	# (GDScript has no try/finally), so the finalize lives here in the wrapper.
	if sheet == null or not lift_functions:
		return _attempt_lift_body(sheet, source, lift_functions)
	progress_phase = "lifting"
	progress_functions_done = 0
	progress_functions_total = _count_lift_candidates(sheet)
	var lifted: bool = _attempt_lift_body(sheet, source, lift_functions)
	progress_functions_done = progress_functions_total
	progress_phase = "done"
	return lifted


## Every top-level function row the two lift passes below may attempt, counted before either runs -
## the stable denominator the progress strip divides into. An upper bound by construction (the
## trailing scan can re-anchor and the mid-file pass skips virtuals), which is why the per-function
## increment clamps and the wrapper above snaps the bar to full when the lift returns.
static func _count_lift_candidates(sheet: EventSheetResource) -> int:
	var total: int = 0
	for entry: Variant in sheet.events:
		var row: RawCodeRow = entry as RawCodeRow
		if row != null and (row.code.begins_with("func ") or row.code.begins_with("static func ")):
			total += 1
	return total


## One more function attempted. Clamped: the counters are display state read without a lock, and a
## bar that reads "9 of 7" is worse than one that sits at full for a beat.
static func _note_function_progress() -> void:
	progress_functions_done = mini(progress_functions_done + 1, progress_functions_total)


static func _attempt_lift_body(sheet: EventSheetResource, source: String, lift_functions: bool = true) -> bool:
	if sheet == null:
		return false
	# The file's own object-typed members, read before any line is matched: they are what tells
	# `candidate == host` apart from `i == 1` (see _is_object_expression).
	_object_reference_names = _object_names_from_source(source)
	# And its own function names, for the same reason: `restart()` beside a `func restart():` is the
	# author's own call, not whichever verb of the vocabulary is spelled the same way.
	_note_own_functions(source)
	# And its network peers, for the same reason: `peer.create_server(…)` only means "host a
	# game" when `peer` really is a multiplayer peer this file declared.
	EventForgeMultiplayerLift.note_source(source)
	# And the lights of the file's own scene, for the same reason again: `$Torch.enabled = false`
	# only means "turn the light off" when the scene says Torch is a light. Nothing else can say so,
	# and a row that guessed would relabel somebody's door.
	EventForgeLightingLift.note_source(source, _scene_source_path_of(sheet))
	# And the material-wearing nodes of that same scene, for the third time the same reason:
	# `material.set_shader_parameter(&"dissolve", 0.7)` only means "turn the dissolve dial" when the
	# scene says this node wears a material and that material's shader declares `dissolve`.
	EventForgeEffectLift.note_source(source, _scene_source_path_of(sheet))
	# And the groups' own "who runs it", resolved per slug (a group inherits its parent's
	# answer), so the guard the compiler wrote in front of each event can be taken back off.
	_note_group_guards(source)
	_lift_host_class = str(sheet.host_class).strip_edges()
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
	# The exact header text (annotation block, doc lines, @rpc lines) the next lifted function must
	# re-emit byte-for-byte - the per-function gate below, so one body the grammar cannot reproduce
	# re-anchors instead of failing the whole file at the end.
	var pending_header_text: String = ""
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
			pending_header_text = "\n".join(annotation_lines)
	# `_ready`'s leading connect lines reveal which functions are signal handlers
	# (and for which signal/source node). Emission regenerates the connects.
	# And so does the project's own scene wiring, for a handler the editor connected instead of
	# `_ready`. A handler sitting at the END of the file never reaches the mid-file pass below, so the
	# scene map has to seed this one too or the commonest shape of all (a UI script whose only
	# functions are `_on_*` handlers) still opens as a list of helpers.
	var connections: Dictionary = EventSheetSceneConnections.for_script(_scene_source_path_of(sheet)).duplicate(true)
	for index in range(first_run_index, sheet.events.size()):
		var ready_row: RawCodeRow = sheet.events[index] as RawCodeRow
		if ready_row != null and ready_row.code.begins_with("func _ready() -> void:"):
			connections.merge(_parse_connections(ready_row.code.split("\n")), true)
	# The same map over the WHOLE file, for the mid-file anchor pass below: a hand-written script
	# writes `_ready` FIRST, above the handlers it connects, so the trailing-run map above (which
	# only sees the tail) is empty there and every `_on_<node>_<signal>` would read as a helper
	# function instead of the trigger it is. Kept separate on purpose - widening the trailing
	# scan's map would change which functions that scan tries to lift as events.
	var all_connections: Dictionary = _parse_all_connections(sheet)
	# Lift the run PER FUNCTION with re-anchoring: when a function's body (or a stray row) can't
	# lift, everything scanned so far - including it - stays raw and the run RE-ANCHORS just after
	# it, so the longest cleanly-lifting TRAILING subset still becomes real functions instead of one
	# hairy body reverting the whole file. Only a trailing subset can lift at all: emission places
	# sheet.functions after the in-place raw rows, so a raw leftover BETWEEN lifted functions would
	# reorder the file (the byte-verify at the end still gates whatever the scan produced).
	# Sibling-isolation inverse: the compiler splits an awaiting per-frame event into its own
	# `func _event_<uid>_async(delta...)` coroutine, called fire-and-forget from the shared
	# handler. Index those funcs up front so the handler lift can inline them back as events
	# (uid preserved); a func the handler actually inlined is then CONSUMED below - emission
	# regenerates both the call and the func, so keeping it would double it.
	var async_funcs: Dictionary = {}
	var async_header_regex: RegEx = RegEx.create_from_string("^func _event_([A-Za-z0-9_]+)_async\\(delta: float\\) -> void:$")
	for scan_index in range(first_run_index, sheet.events.size()):
		var scan_row: RawCodeRow = sheet.events[scan_index] as RawCodeRow
		if scan_row != null and _run_row_kind(scan_row.code, lift_functions) == "func":
			var async_match: RegExMatch = async_header_regex.search(scan_row.code.split("\n")[0])
			if async_match != null:
				async_funcs[async_match.get_string(1)] = scan_row.code
	var inlined_async_uids: Dictionary = {}
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
	# The gap measured immediately before the FIRST section this run produces (-1 = none seen).
	# The per-section stamping below only records a gap WIDER than emission's default separator;
	# this carries the narrow ones too, so a run that re-anchors onto a boundary ending in text
	# can state "no blank here" instead of silently inheriting that default.
	var first_section_blanks: int = -1
	# A connects-only `_ready` lifts to ZERO events (emission regenerates it from the handlers'
	# connect metas), so no OnReady event survives to carry its leading gap or a non-canonical
	# header spelling. Both are remembered here and stamped onto the first lifted event below,
	# where the compiler's synthesized `_ready` reads them back. Without this, the idiomatic
	# two-blank gap above a connects-only `_ready` re-emitted as ONE blank, failed the whole-file
	# byte-verify, and reverted EVERY function in the file to raw blocks.
	var connects_ready_blanks: int = 0
	var connects_ready_header: String = ""
	# Whether THIS run has taken the `_ready` that holds the connect lines. A handler may only lift to
	# an event once it has: emission regenerates the connect for every lifted handler, so one lifted
	# beside a still-verbatim `_ready` writes that line twice. Cleared with everything else on a
	# re-anchor, because the restarted run no longer owns the `_ready` behind it.
	var ready_lifted: bool = false
	for index in range(first_run_index, sheet.events.size()):
		var row: RawCodeRow = sheet.events[index] as RawCodeRow
		var failed: bool = false
		var row_kind: String = _run_row_kind(row.code, lift_functions)
		match row_kind:
			"blank":
				# N blank lines import as a joined "\n"*(N-1) block, so size() == N. Stamped onto the next
				# lifted function's first event below; the compiler re-emits it on the external path.
				pending_blank_count = row.code.split("\n").size()
				continue  # separator; emission re-adds it
			"annotations":
				# The gap before a DOCUMENTED function lives here, not in a "blank" row: the import
				# groups contiguous non-func lines, so the separating blanks and the `##` block arrive
				# as one row. Its leading blanks are therefore this function's gap and must ride
				# through - without this the count was dropped and emission re-added a single blank,
				# so every style-guide file (two blanks between top-level functions) failed the
				# byte-verify and reverted to raw blocks, one line short per documented function.
				pending_blank_count = _leading_blank_count(row.code)
				pending_annotations = _parse_annotations(row.code)
				pending_annotation_lines = _collect_gd_annotation_lines(row.code)
				pending_doc_comment = _collect_doc_comment_text(row.code)
				# The header is the row minus its leading blank lines (those are the gap).
				var header_lines: PackedStringArray = row.code.split("\n")
				while not header_lines.is_empty() and header_lines[0].strip_edges().is_empty():
					header_lines.remove_at(0)
				pending_header_text = "\n".join(header_lines)
				if pending_annotations.is_empty() and pending_annotation_lines.is_empty() and pending_doc_comment.is_empty():
					failed = true
			"comments":
				# TRAILING top-level comments (deferred emission): one CommentRow per
				# blank-separated chunk. Comments lifted this way emit at the END of the file, so
				# this is only correct when nothing but comments follows. A plain `#` note above a
				# function - the ordinary way anyone annotates one - would otherwise be relocated
				# to the file's end, fail the whole-file verify, and revert every function in the
				# file (twelve of them, in one dock helper). Re-anchoring instead leaves the note
				# where it is and lets the functions below it lift, and the mid-file anchor pass
				# can still claim the ones above it in place.
				if _run_has_later_code(sheet, index, lift_functions):
					failed = true
				else:
					for chunk: String in row.code.strip_edges().split("\n\n"):
						var comment: CommentRow = CommentRow.new()
						comment.text = chunk.trim_prefix("# ").replace("\n# ", "\n")
						lifted_comments.append(comment)
			"func":
				# The user asked for the raw code instead ("Show as code instead"). Nothing in this
				# scan has mutated the sheet yet - the backup below is taken after the loop - so
				# bailing here simply hands back the unlifted sheet.
				if cancel_requested:
					return false
				_note_function_progress()
				var header: String = row.code.split("\n")[0]
				# A split-out async coroutine the handler above already inlined back as an
				# event: consumed here (emission regenerates it, single-blank attached).
				var consumed_async: RegExMatch = async_header_regex.search(header)
				if consumed_async != null and inlined_async_uids.has(consumed_async.get_string(1)):
					pending_blank_count = 0
					continue
				if _is_lifecycle_header(header) or _is_connected_handler(header, connections):
					if not pending_annotations.is_empty() or not pending_annotation_lines.is_empty() or not pending_doc_comment.is_empty():
						failed = true  # a lifecycle handler lifts to events, not an EventFunction, so it can't carry a doc
					elif not lifted_functions.is_empty():
						# A handler that sits AFTER functions in the file cannot lift as an event from
						# here: emission writes every event before the trailing functions, so lifting it
						# would move it above them and fail the whole-file verify - which used to revert
						# the ENTIRE file (every published verb of a pack whose `_unhandled_input` follows
						# its verbs). Re-anchor instead: the handler stays a verbatim block where it is,
						# the functions after it still lift here, and the ones before it anchor in place
						# in the mid-file pass below.
						failed = true
					elif _connects_through_ready(header, connections) and not ready_lifted:
						# A handler wired by a `_ready` this run did NOT take. Emission regenerates the
						# connect line for every lifted handler, so lifting one while its `_ready` stays a
						# verbatim block above it writes that connect TWICE - the signal wired twice at
						# runtime, and a whole-file byte-verify that fails and reverts every function in
						# the file. It happens whenever anything sits between the `_ready` and its
						# handlers (one plain helper in a lobby autoload was enough): the run re-anchors
						# past the helper, leaving the `_ready` outside it and the handlers below still
						# willing. Re-anchor here too - the mid-file pass anchors these handlers in place
						# instead, which is where they already are.
						failed = true
					else:
						# Lenient ifs: unmatched control flow becomes in-flow GDScript inside
						# the event instead of failing the file (byte-verify still gates).
						var lift: Dictionary = _lift_function(row.code.split("\n"), connections, true)
						# Per-function gate, the trigger-branch twin of the sheet-function gate below:
						# the lifted events must re-emit this handler's exact bytes, or the handler
						# stays raw and the run re-anchors after it (a mis-emitting handler used to
						# surface only at the whole-file verify, which reverted EVERY function in the
						# file). Exempt: `_ready` (its emission regenerates connect lines that live
						# outside its own events) and a `_process`/`_physics_process` that may inline
						# split-out async coroutines (its re-emission spans other rows by design).
						var gate_exempt: bool = header.begins_with("func _ready(") \
								or (not async_funcs.is_empty() and (header.begins_with("func _process(") or header.begins_with("func _physics_process(")))
						# Group markers are stripped from BOTH sides exactly as the whole-file verify
						# strips them: the `# @group:` tags re-emit from a registry the full compile
						# fills, which this per-function probe does not have.
						if bool(lift.get("ok", false)) and not gate_exempt \
								and not (lift.get("events", []) as Array).is_empty() \
								and _strip_group_markers(SheetCompiler.emit_anchored_trigger_text(lift.get("events", []),
									_group_guards_for(lift.get("events", [])))) != _strip_group_markers(row.code):
							lift = {"ok": false}
						if bool(lift.get("ok", false)):
							saw_function = true
							if header.begins_with("func _ready("):
								ready_lifted = true
							var lift_events: Array = lift.get("events", [])
							if header.begins_with("func _ready(") and not _has_trigger(lift_events, "OnReady"):
								# A `_ready` that lifted to no OnReady event of its own - it held
								# nothing but connections, or nothing but connect lambdas. Emission
								# synthesizes it, so its gap (and any non-canonical header spelling)
								# have to be remembered here - see the declarations above.
								connects_ready_blanks = pending_blank_count
								if header != "func _ready() -> void:":
									connects_ready_header = header
							if not async_funcs.is_empty() and (header.begins_with("func _process(") or header.begins_with("func _physics_process(")):
								lift_events = _inline_async_events(lift_events, header, async_funcs, connections, inlined_async_uids)
							# Preserve the source's inter-function spacing: stamp the gap count onto this
							# function's FIRST event (only when >1, so ordinary single-blank sources stay
							# meta-free). The first lifted function's gap is owned by the boundary-detach path
							# below, so this only governs gaps BETWEEN lifted sections and never double-counts.
							var gap_bearer: Resource = _gap_bearing_event(lift_events)
							if pending_blank_count > 1 and gap_bearer != null:
								gap_bearer.set_meta("__source_leading_blanks", pending_blank_count)
							if lifted_events.is_empty() and lifted_functions.is_empty():
								first_section_blanks = pending_blank_count
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
						var expected_block: String = (pending_header_text + "\n" if not pending_header_text.is_empty() else "") + row.code
						pending_header_text = ""
						# Per-function gate: the lifted function must re-emit header + body exactly, or it
						# stays raw and the run re-anchors after it (a bad body used to revert the file).
						if bool(function_lift.get("ok", false)) and SheetCompiler.emit_function_block_text(function_lift.get("function"), sheet) != expected_block:
							function_lift = {"ok": false}
						if bool(function_lift.get("ok", false)):
							saw_function = true
							var lifted_function: Variant = function_lift.get("function")
							# Same source-spacing preservation as the trigger branch, for a helper/sheet function:
							# stamp the gap count so a hand-written two-blank gap before a helper round-trips.
							# Only when >1; the first lifted function's gap lives in the prelude (boundary-detach),
							# never a "blank" row here, so it is never stamped and can't double-count.
							if pending_blank_count > 1 and lifted_function is EventFunction:
								(lifted_function as EventFunction).set_meta("__source_leading_blanks", pending_blank_count)
							if lifted_events.is_empty() and lifted_functions.is_empty():
								first_section_blanks = pending_blank_count
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
			pending_header_text = ""
			saw_function = false
			first_section_blanks = -1
			connects_ready_blanks = 0
			ready_lifted = false
			connects_ready_header = ""
			anchor_index = index + 1
		# A blank separator's count was just consumed by (or is irrelevant to) this non-blank row - clear it
		# so it never leaks onto a later function. The "blank" branch continues past here, keeping its
		# count, and an "annotations" row carries the gap it owns forward to the function it documents.
		if row_kind != "annotations":
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
			else:
				# The boundary ends on real TEXT, so it carries no trailing blank for the strip above
				# to hand back - whatever gap exists was measured by the scan instead, and emission
				# must reproduce exactly that rather than fall back to its default separator. A `#`
				# note written directly above a function measures 0, which the default would turn
				# into a line the file never had.
				_stamp_leading_blanks(lifted_events, lifted_functions, maxi(first_section_blanks, 0))
		elif sheet.events.is_empty():
			# NOTHING precedes the run: the file's very first line is the first lifted function, so
			# there is no gap at all and emission's default separator would add a blank line the file
			# never had. Same stamp as the ends-on-text case above, for the same reason.
			_stamp_leading_blanks(lifted_events, lifted_functions, maxi(first_section_blanks, 0))
		# The connects-only `_ready`'s remembered gap/header ride the first lifted event (the
		# synthesized `_ready` has no OnReady event of its own to carry them) - stamped on exactly
		# one event; the compiler scans for whichever event carries the metas.
		if connects_ready_blanks > 1 or not connects_ready_header.is_empty():
			for stamped_event: Variant in lifted_events:
				if stamped_event is EventRow:
					if connects_ready_blanks > 1:
						(stamped_event as EventRow).set_meta("__source_ready_blanks", connects_ready_blanks)
					if not connects_ready_header.is_empty():
						(stamped_event as EventRow).set_meta("__source_ready_header", connects_ready_header)
					break
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
	# Raw rows whose trailing annotation block was peeled onto an anchored function, with their
	# original code - the events backup is SHALLOW, so a revert must restore these explicitly.
	var peeled_rows: Array = []
	if lift_functions:
		var mid_index: int = 0
		while mid_index < sheet.events.size():
			var mid_row: RawCodeRow = sheet.events[mid_index] as RawCodeRow
			if mid_row == null or not (mid_row.code.begins_with("func ") or mid_row.code.begins_with("static func ")):
				mid_index += 1
				continue
			# Cancelled mid-run: this pass HAS mutated the sheet (the trailing lift above, and any
			# anchor already placed), so unwind it all before handing the raw sheet back.
			if cancel_requested:
				_revert_lift(sheet, backup, functions_backup, boundary, boundary_code, peeled_rows)
				return false
			_note_function_progress()
			var mid_header: String = mid_row.code.split("\n")[0]
			if _is_lifecycle_header(mid_header) or _is_connected_handler(mid_header, all_connections):
				# A lifecycle/signal handler stranded between raw blocks. The trailing scan above
				# cannot lift it (emission writes events BEFORE the trailing functions, so lifting
				# it there would hoist the handler above every verb below it and break the verify),
				# which is why an `_unhandled_input` written under a pack's vocabulary used to stay
				# a code block. Anchor it in place instead: an EventAnchorRow takes the slot, the
				# lifted EventRows follow it in the array, and the external compile path emits one
				# function for them right there. Gated exactly like a mid-file function - the
				# re-emitted handler text must equal this row's bytes, or it stays raw.
				var handler_events: Array = _anchor_handler_events(mid_row, all_connections)
				if handler_events.is_empty():
					mid_index += 1
					continue
				var event_anchor: EventAnchorRow = EventAnchorRow.new()
				event_anchor.trigger_id = (handler_events[0] as EventRow).trigger_id
				var handler_uids: PackedStringArray = PackedStringArray()
				for handler_event: Variant in handler_events:
					handler_uids.append((handler_event as EventRow).event_uid)
				event_anchor.event_uids = handler_uids
				sheet.events[mid_index] = event_anchor
				for insert_offset in range(handler_events.size()):
					sheet.events.insert(mid_index + 1 + insert_offset, handler_events[insert_offset])
				anchored_count += 1
				mid_index += 1 + handler_events.size()
				continue
			# Engine virtual callbacks are STRUCTURE, not sheet vocabulary: `_enter_tree` is the
			# host binding (folds to metadata on open), `_get_configuration_warnings` is the
			# requires-behavior guard, and so on. Lifting one to an editable EventFunction would
			# hide load-bearing boilerplate inside the Functions panel. Private HELPERS
			# (`_get_pool`) still lift - only known virtual names are excluded.
			if _is_engine_virtual_header(mid_header):
				mid_index += 1
				continue
			# A `## @ace_*` block, a plain `##` doc, or an `@rpc`-style annotation right above
			# belongs to this function. It rides onto the anchored function (exposure metadata, doc
			# comment, verbatim annotations) and is peeled off the raw row above - but ONLY when the
			# compiler's re-emission of the whole annotated block reproduces annotations + function
			# byte-for-byte. Before this, any function wearing a `## @ace_*` line was skipped here
			# outright, so a pack whose file layout defeated the trailing scan opened with every
			# published verb as a code block.
			var previous_row: RawCodeRow = sheet.events[mid_index - 1] as RawCodeRow if mid_index > 0 else null
			var previous_lines: PackedStringArray = previous_row.code.split("\n") if previous_row != null else PackedStringArray()
			var tail_start: int = previous_lines.size()
			while tail_start > 0 and (previous_lines[tail_start - 1].begins_with("## ") or previous_lines[tail_start - 1] == "##" or _is_function_annotation_line(previous_lines[tail_start - 1])):
				tail_start -= 1
			var tail_text: String = "\n".join(previous_lines.slice(tail_start)) if tail_start < previous_lines.size() else ""
			var mid_function: EventFunction = null
			var strip_tail: bool = false
			if not tail_text.is_empty():
				var tail_annotations: Dictionary = _parse_annotations(tail_text)
				var tail_gd_lines: PackedStringArray = _collect_gd_annotation_lines(tail_text)
				var tail_doc: String = _collect_doc_comment_text(tail_text)
				if not (tail_annotations.is_empty() and tail_gd_lines.is_empty() and tail_doc.is_empty()):
					var annotated_lift: Dictionary = _lift_sheet_function(mid_row.code.split("\n"), tail_annotations, true, tail_gd_lines, tail_doc)
					if bool(annotated_lift.get("ok", false)):
						var candidate: EventFunction = annotated_lift.get("function")
						if candidate != null and SheetCompiler._find_function_by_name(sheet, candidate.function_name) == null and SheetCompiler.emit_function_block_text(candidate, sheet) == tail_text + "\n" + mid_row.code:
							mid_function = candidate
							strip_tail = true
			if mid_function == null:
				# The tail (if any) stays where it is - but a `## @ace_*` block that could NOT be
				# absorbed must not be orphaned by anchoring the bare function under it.
				if tail_text.contains("## @ace_"):
					mid_index += 1
					continue
				var mid_lift: Dictionary = _lift_sheet_function(mid_row.code.split("\n"), {}, true)
				if not bool(mid_lift.get("ok", false)):
					mid_index += 1
					continue
				mid_function = mid_lift.get("function")
				if mid_function == null or SheetCompiler._find_function_by_name(sheet, mid_function.function_name) != null:
					mid_index += 1
					continue
				if SheetCompiler.emit_function_block_text(mid_function, sheet) != mid_row.code:
					mid_index += 1
					continue
			var anchor: FunctionAnchorRow = FunctionAnchorRow.new()
			anchor.function_name = mid_function.function_name
			sheet.events[mid_index] = anchor
			sheet.functions.append(mid_function)
			anchored_count += 1
			if strip_tail:
				peeled_rows.append([previous_row, previous_row.code])
				if tail_start == 0:
					# The row above was NOTHING but this function's block: drop it, or an empty raw
					# row would emit a blank line the source never had.
					sheet.events.remove_at(mid_index - 1)
					mid_index -= 1
				else:
					previous_row.code = "\n".join(previous_lines.slice(0, tail_start))
			mid_index += 1
	if not trailing_lifted and anchored_count == 0:
		# Nothing lifted anywhere and nothing was mutated - same exit the trailing-only lift had.
		return _retry_or_fail(sheet, source, lift_functions) if anchor_index != first_run_index else false

	# Verify: the lifted sheet must reproduce the source byte-for-byte.
	progress_phase = "verifying"
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
	_revert_lift(sheet, backup, functions_backup, boundary, boundary_code, peeled_rows)
	return _retry_or_fail(sheet, source, lift_functions)


## Puts the sheet back exactly as the import left it. The events backup is SHALLOW, so the two rows
## the lift edited in place - the boundary row it stripped a separator/annotation block off, and any
## raw row it peeled an annotation tail from - have to be restored by hand. Shared by the byte-verify
## failure path and the cancel path, which must land in the identical state.
static func _revert_lift(sheet: EventSheetResource, backup: Array[Resource], functions_backup: Array[Resource], boundary: RawCodeRow, boundary_code: String, peeled_rows: Array) -> void:
	sheet.events = backup
	sheet.functions = functions_backup
	if boundary != null:
		boundary.code = boundary_code
	for peeled: Array in peeled_rows:
		(peeled[0] as RawCodeRow).code = str(peeled[1])


## Records the source's blank-line gap before the FIRST section a lift produced, so emission
## reproduces it instead of falling back to its default single separator. Events emit before
## trailing functions on the opened-file path, so the first event wins when there is one.
static func _stamp_leading_blanks(lift_events: Array, lift_functions: Array, count: int) -> void:
	var target: Resource = _gap_bearing_event(lift_events)
	if target == null and not lift_functions.is_empty() and lift_functions[0] is EventFunction:
		target = lift_functions[0] as Resource
	# A gap the run actually MEASURED always wins. The scan sees a real blank row between the
	# boundary and the first lifted function and records its count there; this call only fills in
	# the case where the scan measured nothing, so it must never overwrite that.
	if target == null or target.has_meta("__source_leading_blanks"):
		return
	target.set_meta("__source_leading_blanks", count)


## The first lifted event that owns the gap before its own function - which is the first one that is
## not a connect LAMBDA. A lambda's event is a statement INSIDE `_ready`, so the blank lines above
## `_ready` are not its to carry; stamping them on it left the gap on a row emission never reads and
## re-emitted the file one line short.
static func _gap_bearing_event(lift_events: Array) -> Resource:
	for event: Variant in lift_events:
		if event is EventRow and not (event as EventRow).has_meta(SheetCompiler.LAMBDA_CONNECT_ID_META):
			return event as Resource
	return null


## True when any row after `index` still carries code rather than comments or blank separators.
## Deferred comment emission moves a comment to the file's end, so it is only safe for a comment
## block with nothing but comments behind it.
static func _run_has_later_code(sheet: EventSheetResource, index: int, lift_functions: bool) -> bool:
	for later_index in range(index + 1, sheet.events.size()):
		var later_row: RawCodeRow = sheet.events[later_index] as RawCodeRow
		if later_row == null:
			return true
		var later_kind: String = _run_row_kind(later_row.code, lift_functions)
		if later_kind != "comments" and later_kind != "blank":
			return true
	return false


## How many blank lines a row opens with - the inter-function gap an annotation row carries.
static func _leading_blank_count(code: String) -> int:
	var count: int = 0
	for line: String in code.split("\n"):
		if not line.strip_edges().is_empty():
			break
		count += 1
	return count


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
		"_input_event",
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
		group.runs_on = str(fields.get("runs_on", ""))
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
				signal_row.description = _take_trailing_doc_prose(remainder)
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


## Takes the plain `##` prose off the END of the remainder and hands it back newline-separated -
## the doc comment that sat directly above a `## @ace_trigger` block. That prose IS the trigger's
## picker description (a doc comment over a member is what the analyzer reads), so leaving it in
## the remainder strands the sentence in a code block while the signal moves to the top of the
## file and ships with an EMPTY description. Stops at the first line that is not `##` prose, so an
## unrelated comment two lines up is never claimed.
static func _take_trailing_doc_prose(remainder: PackedStringArray) -> String:
	var doc_lines: PackedStringArray = PackedStringArray()
	while not remainder.is_empty():
		var tail: String = remainder[remainder.size() - 1].strip_edges()
		if not tail.begins_with("##") or tail.begins_with("## @ace_"):
			break
		doc_lines.insert(0, tail.trim_prefix("##").trim_prefix(" "))
		remainder.remove_at(remainder.size() - 1)
	return "\n".join(doc_lines)


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
	# A doc / annotation block that ENDS on a blank line is not attached to what follows - it is a
	# class-level doc paragraph (the importer splits it off the function header below it), and it
	# must stay a verbatim row rather than ride onto the next function as its doc.
	if (saw_annotation or saw_gd_annotation) and not saw_comment and lift_functions:
		var block_lines: PackedStringArray = code.split("\n")
		if block_lines[block_lines.size() - 1].strip_edges().is_empty():
			return "other"
		return "annotations"
	if saw_comment and not saw_annotation and not saw_gd_annotation and lift_functions:
		return "comments"
	return "other"


## True when this handler's connection is a CODE connect line (a `_ready` wired it) rather than one
## the project made in its scene file. Only a code connect is re-emitted by the lift, so only a code
## connect can end up written twice.
static func _connects_through_ready(header: String, connections: Dictionary) -> bool:
	var header_regex: RegEx = RegEx.create_from_string("^func ([A-Za-z_][A-Za-z0-9_]*)")
	var header_match: RegExMatch = header_regex.search(header)
	if header_match == null:
		return false
	var connection: Dictionary = connections.get(header_match.get_string(1), {}) as Dictionary
	return not str(connection.get("line", "")).is_empty()


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
		elif text.begins_with("## @ace_codegen_template(\"") and text.ends_with("\")"):
			# Kept: the call prefix (or a custom template) is re-emitted from the function, because a
			# pack opened outside its own project cannot re-derive an autoload / static prefix.
			fields["codegen_template"] = text.substr(26, text.length() - 28)
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
	# round-trips byte-identically.
	var unannotated: bool = annotations.is_empty()
	var header_regex: RegEx = RegEx.new()
	# Optional non-emitting `(static )?` prefix (group 1) shifts the name/args/return captures to 2/3/4.
	# The return capture admits a TYPED COLLECTION (`Array[Dictionary]`, `Dictionary[String, int]`,
	# nested forms) as well as a bare name. Those are ordinary modern GDScript, and while the regex
	# refused them the header matched nothing at all: the helper stayed a block AND, because a
	# failure re-anchors the trailing run, it took every function above it down with it. Such a
	# return is not a Variant.Type, so it resolves through the verbatim return_type_name branch
	# below - which means only the individually byte-gated anchor path claims it.
	# The whole ` -> Type` is OPTIONAL, because `func hurt(amount):` is ordinary GDScript and the
	# commonest head in code written by anyone who did not meet the style guide first. It lifts into
	# the same function block its typed twin does; the only thing remembered is that the annotation
	# was absent, so emission writes the head back exactly as it was typed rather than correcting it.
	header_regex.compile("^(static )?func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)(?: -> ([A-Za-z_][A-Za-z0-9_]*(?:\\[[A-Za-z_][A-Za-z0-9_, \\[\\]]*\\])?))?:$")
	var header_match: RegExMatch = header_regex.search(function_lines[0])
	if header_match == null:
		return {"ok": false}
	var event_function: EventFunction = EventFunction.new()
	event_function.lifted_unannotated = unannotated
	event_function.annotation_lines = annotation_lines
	event_function.doc_comment = doc_comment
	event_function.is_static = not header_match.get_string(1).is_empty()
	event_function.function_name = header_match.get_string(2)
	event_function.no_return_annotation = header_match.get_string(4).is_empty()
	var return_name: String = "void" if event_function.no_return_annotation else header_match.get_string(4)
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
	# Top-level split: a typed collection like `scores: Dictionary[String, int]` is ONE argument -
	# the naive split(", ") fragmented it into two params that still REJOINED byte-identically,
	# so the round-trip gate passed while the picker showed garbage fields.
	for argument: String in EventSheetBlockRegistry.split_params_top_level(header_match.get_string(3)):
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
			# EMPTY is the emitter's render-bare sentinel, so the header round-trips exactly. It is
			# deliberately not "Variant": that is a type a parameter can actually be annotated with,
			# and using it to mean "no annotation" made the two forms impossible to tell apart.
			param.type_name = ""
		event_function.params.append(param)
	event_function.expose_as_ace = bool(annotations.get("expose", false))
	event_function.ace_display_name = str(annotations.get("name", ""))
	event_function.ace_category = str(annotations.get("category", ""))
	event_function.description = str(annotations.get("description", ""))
	event_function.display_template = str(annotations.get("display_template", ""))
	event_function.featured = bool(annotations.get("featured", false))
	# The source's call template: `<prefix>name({a}, {b})` keeps just the prefix (renames and
	# parameter edits still track); any other shape is kept verbatim.
	var source_template: String = str(annotations.get("codegen_template", ""))
	if not source_template.is_empty():
		var call_tokens: PackedStringArray = PackedStringArray()
		for template_param: ACEParam in event_function.params:
			if not template_param.id.strip_edges().is_empty():
				call_tokens.append("{%s}" % template_param.id)
		var derived_call: String = "%s(%s)" % [event_function.function_name, ", ".join(call_tokens)]
		if source_template.ends_with(derived_call):
			event_function.codegen_call_prefix = source_template.substr(0, source_template.length() - derived_call.length())
			event_function.codegen_prefix_known = true
		else:
			event_function.codegen_template_override = source_template
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
	# The sprite's own "I just moved to another frame". The clip-and-frame question stays a
	# condition inside the handler, so a lifted row and a picked one hold the same two resources.
	"frame_changed": "OnAnimationFrame",
	"tree_entered": "OnTreeEntered",
	"tree_exiting": "OnTreeExiting",
	"tree_exited": "OnTreeExited",
	"renamed": "OnRenamed",
	"child_entered_tree": "OnChildEnteredTree",
	"child_exiting_tree": "OnChildExitingTree",
	# The scene side's three. Keyed on the bare signal like every other entry here, and safe for
	# the same reason: a project with a `spawned` signal of its own reads as "On spawned" either way -
	# through this table, or through the `signal:<name>` fallback - so the words a reader gets are the
	# same, and the connect line re-emits from the author's own spelling regardless.
	"spawned": "OnSpawned",
	"despawned": "OnDespawned",
	"synchronized": "OnSynchronized"
}

## Two editor signals that only mean what the Editor object says they mean when they came off
## the editor's OWN objects. Keyed by the connect line's source FIRST and the signal second on
## purpose: `settings_changed` is a name any project could give its own object, and a table keyed on
## the bare signal would relabel every such handler in every game as "On preferences changed".
const EDITOR_SOURCE_SIGNAL_TRIGGERS: Dictionary = {
	"EditorInterface.get_resource_filesystem()": {"filesystem_changed": "OnProjectFilesChanged"},
	"EditorInterface.get_editor_settings()": {"settings_changed": "OnPreferencesChanged"}
}


## One `<something>.<signal>.connect(<handler>)` / `<something>.connect("<signal>", <handler>)` line
## -> {handler, signal, source, line}, or {} when the line is not a connect. Covers the shape
## _emit_grouped_trigger_functions writes AND the shapes people type by hand (`$Node`, `%Unique`,
## a member variable, the string-name overload). The verbatim `line` rides along so emission can
## reproduce the author's own spelling instead of the canonical one - the byte-verify is absolute,
## and rewriting a hand-written `$Hurtbox` connect as `get_node("Hurtbox")` would fail it.
static func _parse_connect_line(line: String) -> Dictionary:
	# The two editor objects a tool connects to are call chains, not identifiers, so they are
	# spelled out rather than allowed as a general `x.y()` alternative - widening the pattern to any
	# call chain would start claiming connect lines in every project that this reading has no words for.
	var source_pattern: String = "(?:(EditorInterface\\.get_resource_filesystem\\(\\)|EditorInterface\\.get_editor_settings\\(\\)|get_node\\(\"[^\"]+\"\\)|\\$[A-Za-z0-9_/]+|%[A-Za-z0-9_]+|[A-Za-z_][A-Za-z0-9_]*)\\.)?"
	# The optional trailing CONNECT_* flags. Godot's own one-shot spelling is a second argument, and
	# a handler wired with it is still exactly this shape - refusing the line only stranded the whole
	# handler as a code block. The line rides along VERBATIM as before, so emission reproduces the
	# flags without the compiler ever having to understand them.
	var flags_pattern: String = "(?:, *((?:Object\\.)?CONNECT_[A-Z_]+(?: *\\| *(?:Object\\.)?CONNECT_[A-Z_]+)*))?"
	var member_regex: RegEx = RegEx.create_from_string("^\\t+" + source_pattern + "([A-Za-z_][A-Za-z0-9_]*)\\.connect\\(([A-Za-z_][A-Za-z0-9_]*)" + flags_pattern + "\\)$")
	var string_regex: RegEx = RegEx.create_from_string("^\\t+" + source_pattern + "connect\\(\"([A-Za-z_][A-Za-z0-9_]*)\", *([A-Za-z_][A-Za-z0-9_]*)" + flags_pattern + "\\)$")
	var line_match: RegExMatch = member_regex.search(line)
	if line_match == null:
		line_match = string_regex.search(line)
	if line_match == null:
		return {}
	var source: String = line_match.get_string(1)
	if source.begins_with("get_node("):
		source = source.trim_prefix("get_node(\"").trim_suffix("\")")
	else:
		source = source.trim_prefix("$").trim_prefix("%")
	return {
		"handler": line_match.get_string(3),
		"signal": line_match.get_string(2),
		"source": source,
		"flags": line_match.get_string(4),
		"line": line,
	}


## The file the sheet under lift came from: the importer's hint when it set one, else whatever the
## sheet already knows. "" for an in-memory import, which simply gets no scene-connection reading.
static func _scene_source_path_of(sheet: EventSheetResource) -> String:
	if not scene_source_path.is_empty():
		return scene_source_path
	return sheet.external_source_path if sheet != null else ""


## Parses `_ready`'s leading connect lines into {handler_name: {signal, source, line}}.
## Shapes (what _emit_grouped_trigger_functions emits, plus the hand-written spellings):
##   	body_entered.connect(_on_body_entered)
##   	get_node("Platform").landed.connect(_on_platform_landed)
##   	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)
static func _parse_connections(ready_lines: PackedStringArray) -> Dictionary:
	var connections: Dictionary = {}
	for index in range(1, ready_lines.size()):
		var parsed: Dictionary = _parse_connect_line(ready_lines[index])
		if parsed.is_empty():
			break  # connects are emitted first; the rest is OnReady body
		connections[str(parsed["handler"])] = parsed
	return connections


## Every connect line ANYWHERE in the imported file, as handler_name -> {signal, source, line}. The
## trailing-run map above only reads the connects at the top of a `_ready` in the tail; a
## hand-written script puts `_ready` first and often mixes connects with other setup, so the
## mid-file anchor pass reads this wider map instead. Position-blind on purpose: the byte-verify is
## what decides whether a handler actually lifts.
static func _parse_all_connections(sheet: EventSheetResource) -> Dictionary:
	# The wiring a project did in the Godot editor lives in the .tscn, not here. Those handlers
	# are read FIRST so a connect actually written in the file still wins: the code is the closer
	# authority on its own bytes, and only a code connect has a line to re-emit.
	var connections: Dictionary = EventSheetSceneConnections.for_script(_scene_source_path_of(sheet)).duplicate(true)
	for entry: Variant in sheet.events:
		var raw_row: RawCodeRow = entry as RawCodeRow
		if raw_row == null or not raw_row.code.contains(".connect("):
			continue
		for line: String in raw_row.code.split("\n"):
			var parsed: Dictionary = _parse_connect_line(line)
			if not parsed.is_empty():
				connections[str(parsed["handler"])] = parsed
	return connections


## The EventRows a mid-file lifecycle/signal handler lifts to, or [] when it must stay raw. The
## gate: the compiler's in-place re-emission of those events has to reproduce this row's bytes
## exactly, so anchoring can never change a file.
static func _anchor_handler_events(mid_row: RawCodeRow, connections: Dictionary) -> Array:
	var handler_lift: Dictionary = _lift_function(mid_row.code.split("\n"), connections, true)
	if not bool(handler_lift.get("ok", false)):
		return []
	var handler_events: Array = handler_lift.get("events", [])
	if handler_events.is_empty() or not (handler_events[0] is EventRow):
		return []
	for handler_event: Variant in handler_events:
		if not (handler_event is EventRow):
			return []
	if SheetCompiler.emit_anchored_trigger_text(handler_events) != mid_row.code:
		return []
	return handler_events


## One trigger function → {ok: bool, events: Array}. Recognizes lifecycle headers and -
## via the `_ready` connection map - signal handlers, which lift to signal-trigger events
## (Core signals reverse to their trigger ids; others become "signal:<name>" triggers with
## the handler's argument signature baked as trigger_args and the connect's source node as
## trigger_source_path). `_ready`'s connect lines are skipped: emission regenerates them.
## True when a header names a lifecycle handler in ANY spelling - the canonical typed table
## entry, or the loose beginner form (`func _physics_process(delta):` - untyped param, no return
## arrow). Both dispatch to the event lift; the loose form carries its source header as meta so
## emission reproduces it exactly.
static func _is_lifecycle_header(header: String) -> bool:
	return LIFECYCLE_TRIGGERS.has(header) or header == NOTIFICATION_HEADER or _loose_lifecycle_match(header) != null


static func _loose_lifecycle_match(header: String) -> RegExMatch:
	var loose_regex: RegEx = RegEx.create_from_string("^func (_ready|_process|_physics_process|_input|_unhandled_input|_unhandled_key_input|_input_event|_gui_input)\\((.*)\\)(?: -> void)?:$")
	return loose_regex.search(header)


## True when an `_enter_tree` body is EXACTLY the host-binding boilerplate a host-targeting behaviour
## pack ships (`host = get_parent() as <Class>` plus the null warning). The compiler emits that block
## from the sheet's host metadata, never from an event, so it must stay a raw row: lifting it would
## emit the same function twice. The match is strict on all four lines, so a hand-modified
## `_enter_tree` - the case this rule is actually about - lifts to its trigger as normal.
static func _is_host_binding_body(function_lines: PackedStringArray) -> bool:
	var lines: PackedStringArray = function_lines.duplicate()
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	if lines.size() != 4 or lines[0] != "func _enter_tree() -> void:":
		return false
	var bind: RegEx = RegEx.create_from_string("^\\thost = get_parent\\(\\) as [A-Za-z_][A-Za-z0-9_]*$")
	if bind == null or bind.search(lines[1]) == null:
		return false
	if lines[2] != "\tif host == null:":
		return false
	return lines[3].begins_with("\t\tpush_warning(\"") and lines[3].rstrip(" ").ends_with("parent.\")")


## `_notification(what)` whose whole body is a `match what:` over NOTIFICATION_* constants: one
## trigger event per case, id "OnNotification:<CONSTANT>". The engine calls the ONE handler for every
## notification, so the cases - not a function each - are what the sheet's events map onto, and the
## compiler re-emits exactly this shape back from those ids. Anything else in the body (the `if what
## == ...` spelling, a statement beside the match, a case that is not a NOTIFICATION_ constant, or a
## case needing more than one event row) fails the lift and the function stays a code block.
static func _lift_notification_function(function_lines: PackedStringArray) -> Dictionary:
	if function_lines.size() < 3 or function_lines[1] != "\tmatch what:":
		return {"ok": false}
	var case_regex: RegEx = RegEx.create_from_string("^\\t\\t(NOTIFICATION_[A-Z0-9_]+):$")
	if case_regex == null:
		return {"ok": false}
	var reverse_entries: Array = _build_reverse_entries()
	var events: Array = []
	var index: int = 2
	while index < function_lines.size():
		var case_match: RegExMatch = case_regex.search(function_lines[index])
		if case_match == null:
			return {"ok": false}
		var trigger_id: String = "OnNotification:%s" % case_match.get_string(1)
		var parsed: Dictionary = _parse_body(function_lines, index + 1, 3, trigger_id, "Core", "", "", reverse_entries, false, false, trigger_id)
		if not bool(parsed.get("ok", false)):
			return {"ok": false}
		var case_rows: Array = parsed.get("rows", [])
		# One case is one event. A case whose body needs several top-level rows has no single event to
		# hang the trigger on, so the handler stays code rather than lifting a shape the emitter - which
		# writes exactly one event per case - could not put back byte-for-byte.
		if case_rows.size() != 1 or not (case_rows[0] is EventRow):
			return {"ok": false}
		var next_index: int = int(parsed.get("next", index + 1))
		if next_index <= index:
			return {"ok": false}
		events.append(case_rows[0])
		index = next_index
	if events.is_empty():
		return {"ok": false}
	return {"ok": true, "events": events}


## The one `_notification` header a match lift reads. Any other spelling stays a code block, which is
## also what keeps the `if what == NOTIFICATION_TRANSLATION_CHANGED:` shape of the language-changed
## trigger on the path it already had.
const NOTIFICATION_HEADER: String = "func _notification(what: int) -> void:"


static func _lift_function(function_lines: PackedStringArray, connections: Dictionary = {}, lenient_ifs: bool = false) -> Dictionary:
	if function_lines.is_empty():
		return {"ok": false}
	if function_lines[0] == NOTIFICATION_HEADER:
		return _lift_notification_function(function_lines)
	var trigger_id: String = ""
	var trigger_provider: String = "Core"
	var trigger_args: String = ""
	var trigger_source: String = ""
	# The connect line VERBATIM, so emission reproduces the author's own spelling of it.
	var connect_line: String = ""
	# True when the wiring lives in the .tscn instead. There is no connect line to reproduce and
	# none may be invented: the script's bytes must come back exactly as they went in.
	var scene_connected: bool = false
	# The emitting node's class as the scene declares it, so the row can draw its picture.
	var source_class: String = ""
	# The events `_ready`'s leading connect-LAMBDAS lifted to. They are siblings of whatever the
	# rest of `_ready` becomes, not part of it: each is its own trigger.
	var lambda_rows: Array = []
	var index: int = 1
	# A lifecycle header the canonical table missed but that still NAMES a lifecycle function is
	# beginner spelling (`func _physics_process(delta):` - untyped param, no return arrow). It
	# lifts to the same trigger with the source header carried as meta, so emission reproduces
	# the exact spelling and the byte gate holds on files no style guide ever touched.
	var source_header: String = ""
	var loose_lifecycle: RegExMatch = null
	if not LIFECYCLE_TRIGGERS.has(function_lines[0]):
		loose_lifecycle = _loose_lifecycle_match(function_lines[0])
	if LIFECYCLE_TRIGGERS.has(function_lines[0]) or loose_lifecycle != null:
		if loose_lifecycle != null:
			var loose_map: Dictionary = {
				"_ready": "OnReady", "_process": "OnProcess", "_physics_process": "OnPhysicsProcess",
				"_input": "OnInput", "_unhandled_input": "OnUnhandledInput",
				"_unhandled_key_input": "OnUnhandledKeyInput", "_input_event": "OnInputEvent",
				"_gui_input": "OnControlInput",
			}
			trigger_id = str(loose_map[loose_lifecycle.get_string(1)])
			source_header = function_lines[0]
		else:
			trigger_id = str(LIFECYCLE_TRIGGERS[function_lines[0]])
		if trigger_id == "OnEnterTree" and _is_host_binding_body(function_lines):
			# The host-binding `_enter_tree` a host-targeting behaviour pack ships. The compiler
			# regenerates it from the sheet's host metadata, so lifting it to a trigger event would
			# emit the function a second time and fail the byte-verify - reverting the WHOLE file to
			# code blocks. Left raw, it keeps reading as the one-line "Host binding" row it already is.
			return {"ok": false}
		# On an EditorPlugin the same two callbacks are the plugin being switched on and off.
		if _lift_host_class == "EditorPlugin" and PLUGIN_LIFECYCLE_TRIGGERS.has(trigger_id):
			trigger_id = str(PLUGIN_LIFECYCLE_TRIGGERS[trigger_id])
		if function_lines[0].begins_with("func _ready()"):
			# Skip the connect lines the map above CLAIMED; what remains is the OnReady body. Only
			# claimed lines are skipped: a connect the map could not read would otherwise vanish from
			# the file (emission regenerates only what a lifted trigger asked for), and the whole file
			# would revert on the byte-verify rather than lift with that line kept as a statement.
			# A connect whose handler is a LAMBDA has no named function to find, so it is read here
			# instead: the body becomes the event's rows and the wrapper is kept verbatim. Only in
			# this leading run, because emission writes every connection at the top of `_ready` - a
			# lambda from the middle of it would come back somewhere it never was.
			while index < function_lines.size():
				if _is_known_connect_line(function_lines[index], connections):
					index += 1
					continue
				var lambda_lift: Dictionary = _lift_connect_lambda(function_lines, index, lenient_ifs)
				if not bool(lambda_lift.get("ok", false)):
					break
				lambda_rows.append_array(lambda_lift.get("events", []) as Array)
				index = int(lambda_lift.get("next", index))
			if index >= function_lines.size():
				return {"ok": true, "events": lambda_rows}  # connects-only _ready
	else:
		var header_regex: RegEx = RegEx.new()
		header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\) -> void:$")
		var header_match: RegExMatch = header_regex.search(function_lines[0])
		if header_match == null or not connections.has(header_match.get_string(1)):
			return {"ok": false}
		var connection: Dictionary = connections[header_match.get_string(1)]
		var signal_name: String = str(connection.get("signal", ""))
		trigger_source = str(connection.get("source", ""))
		connect_line = str(connection.get("line", ""))
		scene_connected = bool(connection.get("scene", false))
		source_class = str(connection.get("source_class", ""))
		# A hand-written handler types the payload the way its scene needs it (`body: Node2D` where
		# the canonical Core trigger says `body: Node`), so the source header rides along and
		# emission reproduces it - otherwise the re-typed argument fails the byte-verify.
		source_header = function_lines[0]
		# The handler's own parameter list, kept for EVERY signal trigger (not just custom ones):
		# it is the payload the editor draws as chips beside the trigger row. The resolver only
		# consults it for a `signal:` id, so recording it on a Core trigger changes no emission.
		trigger_args = header_match.get_string(2)
		var editor_signals: Dictionary = EDITOR_SOURCE_SIGNAL_TRIGGERS.get(trigger_source, {}) as Dictionary
		if editor_signals.has(signal_name):
			# An editor signal off an editor object. The source is the editor itself rather than a
			# node in the scene, so it is cleared here: the resolver knows where to reconnect it, and a
			# leftover path would have emission reach for get_node("EditorInterface…").
			trigger_id = str(editor_signals[signal_name])
			trigger_source = ""
		elif trigger_source == EventForgeMultiplayerLift.CONNECT_SOURCE \
				and EventForgeMultiplayerLift.SIGNAL_TRIGGERS.has(signal_name):
			# MultiplayerAPI's own signals, off the `multiplayer` object the connect line names.
			# The source moves to the global "@multiplayer" token the resolver knows how to write
			# back, exactly as an editor signal's does - `multiplayer` is a property, not a node, so
			# a leftover path would have emission reach for get_node("multiplayer").
			trigger_id = str(EventForgeMultiplayerLift.SIGNAL_TRIGGERS[signal_name])
			trigger_source = TriggerResolver.MULTIPLAYER_SOURCE
		elif CORE_SIGNAL_TRIGGERS.has(signal_name):
			trigger_id = str(CORE_SIGNAL_TRIGGERS[signal_name])
		else:
			trigger_id = "signal:%s" % signal_name
			trigger_provider = ""
			trigger_args = header_match.get_string(2)
	var reverse_entries: Array = _build_reverse_entries()
	# The trigger id doubles as the lift SCOPE: an ACE reading this handler's own arguments is only in
	# the running here (see TRIGGER_SCOPED_ACES), and the scope rides every nested block with it.
	var parsed: Dictionary = _parse_body(function_lines, index, 1, trigger_id, trigger_provider, trigger_args, trigger_source, reverse_entries, lenient_ifs, false, trigger_id)
	if not bool(parsed.get("ok", false)) or int(parsed.get("next", 0)) < function_lines.size():
		return {"ok": false}  # dedented/blank content inside a function - not our shape
	var events: Array = parsed.get("rows", [])
	for event: Variant in events:
		if _is_plain_collector(event as EventRow) and (event as EventRow).actions.is_empty():
			return {"ok": false}
	if not source_header.is_empty():
		# Every event of this handler carries the source spelling - the section emitter reads
		# it off whichever event leads the group, so top-of-sheet reordering cannot lose it.
		for event: Variant in events:
			(event as EventRow).set_meta("__source_trigger_header", source_header)
	if not connect_line.is_empty():
		# The handler carries the exact connect line that wired it, so the regenerated ready
		# handler reproduces the author's spelling rather than the canonical get_node() one.
		for event: Variant in events:
			(event as EventRow).set_meta("__source_connect_line", connect_line)
	if scene_connected:
		# The .tscn already holds this wiring. Emission must add NOTHING: a generated
		# `<node>.<signal>.connect(<handler>)` would both duplicate the connection at runtime and
		# fail the byte-verify, reverting the whole file to code blocks.
		for event: Variant in events:
			(event as EventRow).set_meta("__scene_connected", true)
			if not source_class.is_empty():
				(event as EventRow).set_meta("__scene_source_class", source_class)
	return {"ok": true, "events": lambda_rows + events}


## One `signal.connect(func(…): …)` statement in `_ready` → {ok, events, next}. The body becomes the
## event's own rows and the wrapper is kept verbatim, so emission substitutes the body back between
## the two halves and the line comes back exactly as it was written.
##
## Every row of one lambda carries the same group token, which is what keeps a second lambda on the
## same signal from being folded into the first at emission - and what lets a body that reads as
## several rows (a statement and then a branch) belong to one wiring.
static func _lift_connect_lambda(function_lines: PackedStringArray, index: int, lenient_ifs: bool) -> Dictionary:
	var parts: Dictionary = EventForgeConnectLambdaLift.match_statement(function_lines, index)
	if parts.is_empty():
		return {"ok": false}
	var signal_name: String = str(parts.get("signal", ""))
	var trigger_id: String = str(CORE_SIGNAL_TRIGGERS.get(signal_name, "signal:%s" % signal_name))
	var trigger_provider: String = "Core" if CORE_SIGNAL_TRIGGERS.has(signal_name) else ""
	var depth: int = int(parts.get("depth", 1))
	var body_lines: PackedStringArray = function_lines
	var body_start: int = int(parts.get("body_start", index + 1))
	var body_end: int = int(parts.get("body_end", index + 1))
	if bool(parts.get("inline", false)):
		# An inline body has no line of its own; give it one at the indent the block form would
		# have used, so one body grammar reads both shapes.
		body_lines = PackedStringArray(["%s%s" % ["\t".repeat(depth + 1), str(parts.get("inline_body", ""))]])
		body_start = 0
		body_end = 1
	var parsed: Dictionary = _parse_body(body_lines, body_start, depth + 1, trigger_id,
		trigger_provider, str(parts.get("params", "")), str(parts.get("source", "")),
		_build_reverse_entries(), lenient_ifs, false, trigger_id)
	if not bool(parsed.get("ok", false)) or int(parsed.get("next", 0)) != body_end:
		return {"ok": false}
	var events: Array = parsed.get("rows", [])
	if events.is_empty() or not (events[0] is EventRow):
		return {"ok": false}
	var lead: EventRow = events[0] as EventRow
	if _is_plain_collector(lead) and lead.actions.is_empty():
		return {"ok": false}
	lead.set_meta(SheetCompiler.LAMBDA_CONNECT_META, EventForgeConnectLambdaLift.spelling_of(parts))
	for event: Variant in events:
		if not (event is EventRow):
			return {"ok": false}
		(event as EventRow).set_meta(SheetCompiler.LAMBDA_CONNECT_ID_META, lead.event_uid)
	return {"ok": true, "events": events, "next": int(parts.get("next", index + 1))}


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
static func _parse_body(lines: PackedStringArray, start: int, depth: int, trigger_id: String, trigger_provider: String, trigger_args: String, trigger_source: String, reverse_entries: Array, lenient_ifs: bool, in_loop: bool = false, scope_trigger: String = "") -> Dictionary:
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
	# Author-facing blank lines inside a hand-written body: a run of empty lines between two statements
	# (or before a nested block) is layout, not logic. We count each internal run and carry it onto the
	# NEXT visible row/action as transient meta (__source_body_blanks), so the compiler re-emits the exact
	# spacing and the whole-file byte-verify holds - turning a paragraph-formatted function into clean
	# rows instead of reverting the entire body to a verbatim wall. Boxed (single-element Array) so the
	# count survives across _flush_raw / _consume_action_line, which append the resource it must land on.
	var blank_box: Array = [0]
	var index: int = start
	while index < lines.size():
		var line: String = lines[index]
		if line.strip_edges().is_empty():
			# Measure the whole run of consecutive blank lines.
			var blank_run_start: int = index
			var blank_run: int = 0
			while index < lines.size() and lines[index].strip_edges().is_empty():
				blank_run += 1
				index += 1
			# A blank whose following line dedents out of this body (or ends it) belongs to an OUTER
			# scope, not here - rewind and break so the caller (or the function boundary) owns it. Only
			# a blank still FOLLOWED by content at this depth is internal spacing we can round-trip.
			if index >= lines.size() or not lines[index].begins_with(indent):
				index = blank_run_start
				break
			# Internal run: close any open raw block first (so the blank lands at a clean row boundary),
			# then carry the count onto whatever visible row/action comes next.
			_flush_raw(current, pending_raw, blank_box)
			blank_box[0] += blank_run
			continue
		if not line.begins_with(indent):
			break  # dedent: this body is done; the caller resumes here
		var rest: String = line.substr(depth)
		if rest.begins_with("# @group:"):
			pending_group_slug = rest.substr(9)  # 9 == len("# @group:")
			index += 1
			continue
		var at_this_depth: bool = not rest.begins_with("\t")
		# A guard clause written on ONE line (`if target == null: return`, `else: play("hurt")`) is the
		# same block as its multi-line twin, and a beginner writes far more of them than of the indented
		# form. The header is separated here so the whole if/elif/else grammar below runs unchanged; the
		# one-line shape is remembered on the row (__source_inline_block) and the compiler folds the body
		# back onto the header, so the file it came from re-emits byte for byte.
		var block_head: String = rest
		var inline_body: String = ""
		if at_this_depth and not rest.ends_with(":"):
			var inline_split: Dictionary = _inline_block_split(rest)
			if not inline_split.is_empty():
				block_head = str(inline_split.get("head", ""))
				inline_body = str(inline_split.get("body", ""))
		var is_if: bool = at_this_depth and block_head.begins_with("if ") and block_head.ends_with(":")
		var is_elif: bool = at_this_depth and chain_open and block_head.begins_with("elif ") and block_head.ends_with(":")
		var is_else: bool = at_this_depth and chain_open and block_head == "else:"
		if is_if or is_elif or is_else:
			var expression: String = ""
			if is_if:
				expression = block_head.substr(3, block_head.length() - 4)
			elif is_elif:
				expression = block_head.substr(5, block_head.length() - 6)
			# A group that says who runs it wears its guard on every event under it. The guard is
			# the GROUP's fact, so it comes off here and rides the EventGroup instead; re-emission puts
			# back exactly the term that was taken away, which is what keeps the file byte-identical.
			if is_if:
				expression = _without_group_guard(expression, pending_group_slug)
			var block_event: EventRow = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			if not is_if:
				block_event.else_mode = EventRow.ElseMode.ELSE
			var representable: bool = expression.is_empty() or _parse_conditions(expression, block_event, reverse_entries, scope_trigger)
			var inner: Dictionary = {}
			if representable:
				# An `if` inherits the loop context of its parent (a break/continue inside it belongs to the
				# enclosing loop), so pass in_loop straight through. A one-line body is parsed through the
				# very same walk, from a synthetic line at the depth it would have occupied - so a lifted
				# `if c: return` holds exactly the rows its indented twin holds.
				var body_lines: PackedStringArray = lines
				var body_start: int = index + 1
				if not inline_body.is_empty():
					body_lines = PackedStringArray(["\t".repeat(depth + 1) + inline_body])
					body_start = 0
				inner = _parse_body(body_lines, body_start, depth + 1, "", "", "", "", reverse_entries, lenient_ifs, in_loop, scope_trigger)
				representable = bool(inner.get("ok", false)) and _adopt_block_body(block_event, inner.get("rows", []))
			if not representable:
				if not lenient_ifs:
					return {"ok": false}
				# Raw fallback: the header line joins the open collector; its deeper
				# lines arrive through the statement branch below, tabs preserved.
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					pending_group_slug = _stamp_group(current, pending_group_slug)
					rows.append(current)
				pending_raw.append(rest)
				index += 1
				chain_open = false
				continue
			_flush_raw(current, pending_raw, blank_box)
			current = null
			if is_if:
				# Stamp only once the lift is CONFIRMED - a failed if degrades to the raw
				# collector above, which then carries the group instead. (elif/else rows never
				# start a group; the compiler emits markers only before else_mode NONE events.)
				pending_group_slug = _stamp_group(block_event, pending_group_slug)
			# A blank before this block re-emits above its `if`/`elif`/`else` header.
			_stamp_body_blanks(block_event, blank_box)
			if not inline_body.is_empty():
				# The one bit of the source shape a row cannot otherwise remember: this block was
				# written on its header's line. The compiler reads it back and re-folds exactly one
				# emitted body line onto the header, which is what keeps the file byte-identical.
				block_event.set_meta("__source_inline_block", true)
			rows.append(block_event)
			index = index + 1 if not inline_body.is_empty() else int(inner.get("next"))
			chain_open = true
			continue
		# Loops ('For Each' / repeat / while): `for X in EXPR:` or `while EXPR:` at this
		# depth opens a pick-filter row whose body parses one level deeper - exactly the if/elif/else
		# grammar above, but the wrapper is a PickFilter, not conditions. _adopt_block_body folds the
		# body (leading statements → actions, nested blocks → sub_events); a statement AFTER a nested
		# block is unrepresentable (actions emit before sub-events) and falls to the lenient raw path.
		# Loop-index prelude (the emitter's exact three-line shape): `var X: int = -1` directly
		# above a loop whose body's FIRST line is `X += 1` lifts back into PickFilter.index_name -
		# the loop index counter. All three lines must match or the var stays an ordinary statement.
		var loop_index_lift: String = ""
		if at_this_depth and index + 2 < lines.size():
			# Compiled once: this sits inside the statement loop, so it is asked of every line of
			# every function the lift walks.
			if _loop_index_probe == null:
				_loop_index_probe = RegEx.new()
				_loop_index_probe.compile("^var ([A-Za-z_][A-Za-z0-9_]*): int = -1$")
			var index_match: RegExMatch = _loop_index_probe.search(rest)
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
			var loop_inner: Dictionary = _parse_body(lines, index + (2 if not loop_index_lift.is_empty() else 1), depth + 1, "", "", "", "", reverse_entries, lenient_ifs, true, scope_trigger)
			var loop_ok: bool = bool(loop_inner.get("ok", false)) and _adopt_block_body(loop_event, loop_inner.get("rows", []))
			if not loop_ok:
				if not lenient_ifs:
					return {"ok": false}
				# Raw fallback: the header joins the open collector; its deeper lines arrive
				# through the statement branch below, tabs preserved (same as if/elif/else).
				# A consumed loop-index prelude re-joins first so no source line is ever lost.
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					pending_group_slug = _stamp_group(current, pending_group_slug)
					rows.append(current)
				if not loop_index_lift.is_empty():
					pending_raw.append("var %s: int = -1" % loop_index_lift)
				pending_raw.append(rest)
				index += 1
				chain_open = false
				continue
			_flush_raw(current, pending_raw, blank_box)
			current = null
			_consume_pick_validity_guard(loop_event)
			# A grouped loop event carries its group too (the marker precedes ANY grouped
			# event's first line, not just `if` headers). Stamped only after the lift held.
			pending_group_slug = _stamp_group(loop_event, pending_group_slug)
			# A blank before this loop re-emits above its `for`/`while` header.
			_stamp_body_blanks(loop_event, blank_box)
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
				if current != null and not pending_group_slug.is_empty():
					# A group marker right before the match starts a NEW grouped event - merging
					# into the open collector would silently drop the group on round-trip.
					_flush_raw(current, pending_raw, blank_box)
					current = null
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					pending_group_slug = _stamp_group(current, pending_group_slug)
					rows.append(current)
				_flush_raw(current, pending_raw, blank_box)  # any raw before the match emits before it (order)
				var match_row: MatchRow = MatchRow.new()
				match_row.match_expression = rest.substr(6, rest.length() - 7)  # strip "match " and ":"
				match_row.branches_text = "\n".join(branch_lines)
				# Structured lift: parse the branch text into first-class cases (pattern + body) so the switch
				# reads and (later) edits as event-sheet blocks, not a text blob. Byte-gated - the cases are
				# only taken when re-emitting them reproduces the branch text exactly; otherwise the verbatim
				# branches_text stands (the raw fallback), so this never risks the round-trip.
				match_row.cases = _structure_match_cases(branch_lines)
				# A blank before the match re-emits above its `match EXPR:` line.
				_stamp_body_blanks(match_row, blank_box)
				current.actions.append(match_row)
				index = scan
				chain_open = false
				continue
			# An empty arm list isn't our shape - fall through and treat `match …:` as a raw line.
		# Statement at this depth (or deeper, inside an unlifted block): collect with
		# relative indentation intact.
		if current != null and not pending_group_slug.is_empty():
			# A group marker between statements means a NEW grouped event starts here - the
			# collector would otherwise merge it into the previous event and lose the group.
			_flush_raw(current, pending_raw, blank_box)
			current = null
		if current == null:
			current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			pending_group_slug = _stamp_group(current, pending_group_slug)
			rows.append(current)
		if at_this_depth:
			# A networking run that only means something as a group: the two or three lines that
			# open a game are ONE row, so they are claimed together before any single line is. The
			# matched spelling rides back as the row's baked template, which is what re-emits the
			# author's own bytes instead of the canonical three-line form.
			var networked_run: Dictionary = EventForgeMultiplayerLift.match_run(lines, index, depth)
			if not networked_run.is_empty():
				_flush_raw(current, pending_raw, blank_box)
				current.actions.append(_matched_spelling_action(networked_run, blank_box))
				index += int(networked_run["consumed"])
				chain_open = false
				continue
			# A line that OPENS a multi-line collection literal takes the whole literal with it.
			# Matching only its head once published `var metadata := {` as an action and stranded the
			# entries in a block below it, so a table of defaults read as a wall of orphaned strings.
			var literal_end: int = _body_literal_close(lines, index, depth)
			if literal_end > index:
				# Close whatever was pending first: a comment run above the literal is a note in its own
				# right, and merged into the same block neither it nor the literal can be recognised.
				_flush_raw(current, pending_raw, blank_box)
				var decl_lines: PackedStringArray = PackedStringArray()
				for literal_index: int in range(index, literal_end + 1):
					decl_lines.append(lines[literal_index].substr(depth))
				# STRUCTURED first: a canonical `var name := { ... }` becomes ONE Declare action whose
				# entries are rows of their own - no bracket rows at all. parse() carries its own byte
				# gate (emit_lines() must reproduce the source exactly), so anything it cannot claim
				# falls to the per-line rows below, and the whole-file verify still gates everything.
				var decl: CollectionDeclRow = CollectionDeclRow.parse(decl_lines)
				if decl != null:
					_stamp_body_blanks(decl, blank_box)
					current.actions.append(decl)
				else:
					for decl_line: String in decl_lines:
						pending_raw.append(decl_line)
						_flush_raw(current, pending_raw, blank_box)
				index = literal_end + 1
				chain_open = false
				continue
			# A line whose BRACKETS are still open does not end here - the rest of the call or collection
			# is on the lines below it. Matching an ACE on the opening line alone consumed it and left the
			# continuation stranded, so the run that followed began mid-expression with a lone `)` as its
			# shallowest line - which then made the real statements around it look like continuations of
			# nothing. Take the whole bracketed run as one statement instead.
			var bracket_end: int = _bracket_run_close(lines, index)
			if bracket_end > index:
				for bracket_index: int in range(index, bracket_end + 1):
					pending_raw.append(lines[bracket_index].substr(depth))
				_flush_raw(current, pending_raw, blank_box)
				index = bracket_end + 1
				chain_open = false
				continue
			_consume_action_line(current, rest, 0, pending_raw, reverse_entries, in_loop, blank_box)
		else:
			# A DEEPER line lives inside an unlifted control block above it. Template-matching it
			# would tear it out as a standalone ACTION that re-emits at the event's depth - one tab
			# shallower than the source - and fail the byte-verify. Keep it raw, tabs intact. A
			# pending blank rides the box onto the raw block this line eventually flushes into.
			_append_raw_line(current, pending_raw, blank_box, rest)
		index += 1
		chain_open = false
	_flush_raw(current, pending_raw, blank_box)
	return {"ok": true, "rows": rows, "next": index}


## Splits a ONE-LINE `if`/`elif`/`else` (`if hp <= 0: die()`) into {head "if hp <= 0:", body "die()"},
## or {} when the line is not that shape. The split is deliberately strict, because it is only safe as
## far as it is byte-reversible: the colon must be followed by EXACTLY one space (the separator the
## compiler writes back), the body must carry no leading or trailing whitespace of its own, and a body
## that itself opens a block is refused - a nested one-liner would re-emit as two indented lines and
## fail the whole-file verify, taking the entire function back to a verbatim wall with it.
static func _inline_block_split(rest: String) -> Dictionary:
	var keyword: String = ""
	for candidate: String in ["if ", "elif ", "else:"]:
		if rest.begins_with(candidate):
			keyword = candidate
			break
	if keyword.is_empty():
		return {}
	var colon: int = 4 if keyword == "else:" else _top_level_colon(rest, keyword.length())
	if colon < 0 or colon + 2 >= rest.length():
		return {}
	if rest[colon + 1] != " ":
		return {}
	var body: String = rest.substr(colon + 2)
	if body != body.strip_edges() or body.is_empty():
		return {}
	for opener: String in ["if ", "elif ", "else:", "for ", "while ", "match "]:
		if body.begins_with(opener):
			return {}
	return {"head": rest.substr(0, colon + 1), "body": body}


## The index of the first `:` at bracket depth 0 outside a string literal, scanning from `from`, or -1.
## Bracket-aware so a lambda argument list (`func(v): …` inside a call) and a dictionary literal keep
## their own colons; a condition itself can hold none, so the first top-level one always ends it.
static func _top_level_colon(text: String, from: int) -> int:
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var index: int = from
	while index < text.length():
		var character: String = text[index]
		if in_string:
			if character == "\\":
				index += 2
				continue
			if character == quote:
				in_string = false
			index += 1
			continue
		if character == "\"" or character == "'":
			in_string = true
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif depth == 0 and character == ":":
			return index
		index += 1
	return -1


## Every group slug in a source mapped to the guard its events are wrapped in - its own runs_on
## answer, or the nearest ancestor's. Filled once per lift, for the same reason the peer variables
## are: it is one fact about the file being read.
static var _group_runs_on: Dictionary = {}


## Records that mapping. A source with no groups, or none that says who runs it, leaves it empty and
## every expression below passes through untouched.
static func _note_group_guards(source: String) -> void:
	_group_runs_on = {}
	if not source.contains("runs_on=\""):
		return
	var registry: Dictionary = _recover_group_declarations(source)
	for slug: String in registry:
		var walk: String = slug
		var seen: Dictionary = {}
		while not walk.is_empty() and registry.has(walk) and not seen.has(walk):
			seen[walk] = true
			var guard: String = EventGroup.runs_on_guard(str((registry[walk] as Dictionary).get("runs_on", "")))
			if not guard.is_empty():
				_group_runs_on[slug] = guard
				break
			walk = str((registry[walk] as Dictionary).get("parent", ""))


## The runs_on guard each of a handler's lifted events sits behind, keyed by the row it guards.
## A full compile fills this while flattening the group tree; the PER-FUNCTION probe re-emits one
## handler with no groups around it, so without this it would read a body that lifted perfectly as a
## mismatch and leave the whole function raw.
static func _group_guards_for(events: Array) -> Dictionary:
	var guards: Dictionary = {}
	if _group_runs_on.is_empty():
		return guards
	for event: Variant in events:
		if not (event is EventRow) or not (event as EventRow).has_meta("__group_slug"):
			continue
		var guard: String = str(_group_runs_on.get(str((event as EventRow).get_meta("__group_slug")), ""))
		if not guard.is_empty():
			guards[event] = guard
	return guards


## `expression` with the leading runs_on guard of `slug`'s group taken off, unwrapping the brackets
## the compiler puts around an Or list that sits behind a guard - so `a or b` splits as the Or block
## it was, rather than lifting as one opaque term. Unchanged when the group says nothing about who
## runs it, or when the expression does not open on that guard.
static func _without_group_guard(expression: String, slug: String) -> String:
	var guard: String = str(_group_runs_on.get(slug, ""))
	if guard.is_empty():
		return expression
	if expression == guard:
		return ""
	if not expression.begins_with(guard + " and "):
		return expression
	var rest: String = expression.substr(guard.length() + 5)
	if rest.begins_with("(") and rest.ends_with(")") and _split_top_level(rest, " or ").size() == 1:
		var inner: String = rest.substr(1, rest.length() - 2)
		if _split_top_level(inner, " or ").size() > 1:
			return inner
	return rest


## Stamps a pending `# @group:<slug>` breadcrumb onto a freshly lifted event (any row kind -
## conditioned, loop, match-carrier, or plain action collector) and consumes it. Returns the new
## pending value ("" when stamped) so call sites stay one line: `pending = _stamp_group(row, pending)`.
static func _stamp_group(event: EventRow, pending_group_slug: String) -> String:
	if event == null or pending_group_slug.is_empty():
		return pending_group_slug
	event.set_meta("__group_slug", pending_group_slug)
	return ""


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
	match_case.events = _statement_rows(body)


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


## The sibling-isolation inverse: a lifted per-frame handler may contain fire-and-forget
## dispatcher calls (`_event_<uid>_async(delta)`) whose bodies live in split-out coroutine
## funcs. Each call statement is replaced by the lift of its func's body (as an event of
## this handler's trigger, uid restored), and the func is marked consumed. A call whose
## func is missing stays a plain statement; the byte-verify gates whatever this produces.
static func _inline_async_events(lift_events: Array, handler_header: String, async_funcs: Dictionary, connections: Dictionary, inlined_async_uids: Dictionary) -> Array:
	var call_regex: RegEx = RegEx.create_from_string("^_event_([A-Za-z0-9_]+)_async\\(delta\\)$")
	var out: Array = []
	for event_entry: Variant in lift_events:
		var row: EventRow = event_entry as EventRow
		# Only a plain collector row (no conditions, no chain, no loop) can hold the calls.
		if row == null or not row.conditions.is_empty() or row.else_mode != EventRow.ElseMode.NONE or not row.pick_filters.is_empty():
			out.append(event_entry)
			continue
		var rebuilt_actions: Array = []
		var emitted_inline: bool = false
		for action_item: Variant in row.actions:
			# The dispatcher call usually reverse-matches as a Call Function ACE
			# ("{function_name}({args})") rather than staying a raw statement.
			if action_item is ACEAction and (action_item as ACEAction).ace_id == "CallFunction":
				var called: String = str((action_item as ACEAction).params.get("function_name", ""))
				var call_args: String = str((action_item as ACEAction).params.get("args", ""))
				var name_match: RegExMatch = RegEx.create_from_string("^_event_([A-Za-z0-9_]+)_async$").search(called)
				if name_match != null and call_args == "delta" and async_funcs.has(name_match.get_string(1)):
					var inlined_from_call: EventRow = _lift_async_func_event(str(async_funcs[name_match.get_string(1)]), handler_header, connections, name_match.get_string(1))
					if inlined_from_call != null:
						if not rebuilt_actions.is_empty():
							out.append(_collector_like(row, rebuilt_actions, PackedStringArray()))
							rebuilt_actions = []
						out.append(inlined_from_call)
						emitted_inline = true
						inlined_async_uids[name_match.get_string(1)] = true
						continue
			if not (action_item is RawCodeRow):
				rebuilt_actions.append(action_item)
				continue
			var pending_lines: PackedStringArray = PackedStringArray()
			for raw_line: String in (action_item as RawCodeRow).code.split("\n"):
				var call_match: RegExMatch = call_regex.search(raw_line)
				var inlined: EventRow = null
				if call_match != null and async_funcs.has(call_match.get_string(1)):
					inlined = _lift_async_func_event(str(async_funcs[call_match.get_string(1)]), handler_header, connections, call_match.get_string(1))
				if inlined == null:
					pending_lines.append(raw_line)
					continue
				# Flush statements collected before the call as their own collector row,
				# then splice the inlined event - order preserved exactly.
				if not pending_lines.is_empty() or not rebuilt_actions.is_empty():
					out.append(_collector_like(row, rebuilt_actions, pending_lines))
					rebuilt_actions = []
					pending_lines = PackedStringArray()
				out.append(inlined)
				emitted_inline = true
				inlined_async_uids[call_match.get_string(1)] = true
			if not pending_lines.is_empty():
				for residue: RawCodeRow in _statement_rows(pending_lines):
					rebuilt_actions.append(residue)
		if not emitted_inline:
			out.append(event_entry)
		elif not rebuilt_actions.is_empty():
			out.append(_collector_like(row, rebuilt_actions, PackedStringArray()))
	return out


## A collector row cloned from `like` (same trigger identity) holding the given actions
## plus an optional trailing raw statement block.
static func _collector_like(like: EventRow, actions: Array, extra_lines: PackedStringArray) -> EventRow:
	var collector: EventRow = _make_event(like.trigger_id, like.trigger_provider_id, like.trigger_args, like.trigger_source_path)
	for action_item: Variant in actions:
		collector.actions.append(action_item)
	if not extra_lines.is_empty():
		for extra_row: RawCodeRow in _statement_rows(extra_lines):
			collector.actions.append(extra_row)
	return collector


## Lifts one split-out coroutine's body as a single event of the handler's trigger, with
## the split uid restored so re-emission regenerates the same func name. Returns null when
## the body doesn't lift to exactly one event (the caller keeps the call verbatim then).
static func _lift_async_func_event(func_code: String, handler_header: String, connections: Dictionary, uid: String) -> EventRow:
	var func_lines: PackedStringArray = func_code.split("\n")
	var faked: PackedStringArray = PackedStringArray([handler_header])
	for line_index: int in range(1, func_lines.size()):
		faked.append(func_lines[line_index])
	var lift: Dictionary = _lift_function(faked, connections, true)
	if not bool(lift.get("ok", false)):
		return null
	var events: Array = lift.get("events", [])
	if events.size() != 1 or not (events[0] is EventRow):
		return null
	(events[0] as EventRow).event_uid = uid
	return events[0]


## The compiler regenerates a validity guard as an awaiting loop body's first statement
## ("if X is Object and not is_instance_valid(X): continue" - the unpick-on-free rule), so
## the lift must CONSUME it or re-emission would double it. Consumed only when the lifted
## body actually awaits - the exact condition under which the emitter re-adds it.
static func _consume_pick_validity_guard(loop_event: EventRow) -> void:
	if loop_event.pick_filters.is_empty() or loop_event.actions.is_empty():
		return
	if not SheetCompiler._subtree_awaits(loop_event):
		return
	var iterator: String = (loop_event.pick_filters[0] as PickFilter).iterator_name
	var guard: String = "if %s is Object and not is_instance_valid(%s): continue" % [iterator, iterator]
	var first: Variant = loop_event.actions[0]
	if first is RawCodeRow:
		var raw: RawCodeRow = first as RawCodeRow
		if raw.code == guard:
			loop_event.actions.remove_at(0)
		elif raw.code.begins_with(guard + "\n"):
			raw.code = raw.code.substr(guard.length() + 1)


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


## True when this line is one of the connects the connection map already claimed - the only ones a
## lifted `_ready` may drop, because only those come back when the handler they wire re-emits.
static func _is_known_connect_line(line: String, connections: Dictionary) -> bool:
	var parsed: Dictionary = _parse_connect_line(line)
	if parsed.is_empty():
		return false
	var claimed: Variant = connections.get(str(parsed["handler"]))
	return claimed is Dictionary and str((claimed as Dictionary).get("line", "")) == line


## The plain function names the file under lift declares, so a call to one of them can be read as the
## call it is. Filled once per file, before any line is matched; empty for a paste with no functions
## in it, which simply leaves the vocabulary to answer as it always did.
static var _own_function_names: Dictionary = {}


## Notes the file's own function headers. Every `func name(` at the top level of the source, whether
## or not that function itself goes on to lift.
static func _note_own_functions(source: String) -> void:
	_own_function_names.clear()
	var header: RegEx = RegEx.create_from_string("^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\\(")
	for line: String in source.split("\n"):
		var found: RegExMatch = header.search(line)
		if found != null:
			_own_function_names[found.get_string(1)] = true


## True when the line is a bare call to one of this file's own functions - `restart()`, `heal(5)` -
## and nothing else. A receiver in front of it (`$Timer.restart()`) is a call on something else and
## is left to the vocabulary, which is what knows about other objects.
static func _is_own_function_call(line: String) -> bool:
	if _own_function_names.is_empty():
		return false
	var call: RegEx = RegEx.create_from_string("^([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)$")
	var found: RegExMatch = call.search(line.strip_edges())
	return found != null and _own_function_names.has(found.get_string(1))


## Whether any of these lifted rows is an event on one named trigger. Asked of a `_ready` lift, whose
## rows may now be a mixture: its own OnReady body, and one event per connect lambda it wired.
static func _has_trigger(events: Array, trigger_id: String) -> bool:
	for event: Variant in events:
		if event is EventRow and (event as EventRow).trigger_id == trigger_id:
			return true
	return false


static func _make_event(trigger_id: String, trigger_provider: String = "Core", trigger_args: String = "", trigger_source: String = "") -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = trigger_provider
	event.trigger_id = trigger_id
	event.trigger_args = trigger_args
	event.trigger_source_path = trigger_source
	return event


## Splits a joined expression on a TOP-LEVEL separator (" and ", " or ", ", ") only - ignoring the
## separator inside (), [], {} or a string literal - so a compound term like `f(a and b)`, `x == "a or b"`,
## `not (a and b)`, or a typed collection `Dictionary[String, int]` stays ONE piece. The naive
## String.split(sep) fragmented these into garbage; each piece still round-tripped when rejoined, but the
## structure was nonsense.
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
		elif depth == 0 and c == sep[0] and expression.substr(i, sep_len) == sep:
			parts.append(expression.substr(start, i - start))
			i += sep_len
			start = i
			continue
		i += 1
	parts.append(expression.substr(start))
	return parts


## Splits a joined condition expression into terms and reverse-matches every term (supporting `not (...)`
## negation), setting the event's AND/OR condition_mode. All terms must match or the lift fails - though
## the generic Expression Is True condition (bare {expr}) catches any term no specific ACE claims.
## Top-level ` or ` splits FIRST (matching GDScript, where `or` binds loosest): any ` or ` at the top
## makes an event-sheet "Or block" whose terms keep their inner `and`s whole, and only a pure-AND
## expression splits on ` and ` into AND'd conditions.
static func _parse_conditions(expression: String, event: EventRow, reverse_entries: Array, scope_trigger: String = "") -> bool:
	# Precedence-correct split order: `or` binds LOOSEST in GDScript, so `a and b or c`
	# means `(a and b) or c` - split top-level ` or ` FIRST (an OR block whose terms keep
	# their inner `and`s whole), and only a pure-AND expression splits on ` and `. The old
	# and-first order lifted the mixed form as `a AND (b or c)`: the bytes round-tripped,
	# but the reconstructed structure was semantically wrong, so editing a condition in
	# the reopened sheet emitted different runtime behavior than the source expressed.
	var terms: PackedStringArray = _split_top_level(expression, " or ")
	if terms.size() > 1:
		event.condition_mode = EventRow.ConditionMode.OR
	else:
		terms = _split_top_level(expression, " and ")
	for term: String in terms:
		var negated: bool = false
		var candidate: String = term
		if candidate.begins_with("not (") and candidate.ends_with(")"):
			negated = true
			candidate = candidate.substr(5, candidate.length() - 6)
		var matched: Dictionary = _match_entry(candidate, reverse_entries, "condition", true, scope_trigger)
		if matched.is_empty():
			return false
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = str(matched.get("provider", ""))
		condition.ace_id = str(matched.get("ace_id", ""))
		condition.params = matched.get("params", {})
		condition.negated = negated
		# Both spellings of an inverted comparison are the SAME row: `not (hp <= 0)` lifts to the
		# comparison with the invert on, reading `hp > 0` exactly as a file that wrote the short form
		# does, so the Compare dialog, the operator glyphs and the invert toggle all still apply. The
		# file's own spelling is remembered on the row, because the compiler writes the opposite
		# operator by default and re-emitting the short form here would lose the byte gate.
		condition.negation_wrapped = negated and not _flips_when_inverted(matched).is_empty()
		event.conditions.append(condition)
	return true


## The flipped params of a matched condition, or {} when its ACE is not the plain `{a} {op} {b}`
## shape - which is the same question the compiler asks before writing the opposite operator.
static func _flips_when_inverted(matched: Dictionary) -> Dictionary:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(matched.get("provider", "")), str(matched.get("ace_id", "")))
	if descriptor == null:
		return {}
	return EventForgeACEFactory.flipped_comparison_params(descriptor.codegen_template,
		matched.get("params", {}))


## The index of the line on which a bracketed run STARTING at `start` closes, or -1 when the line
## is already balanced. Mirrors GDScript: a statement continues while `(`/`[`/`{` are open, so the
## whole run is one statement and must be kept together.
static func _bracket_run_close(lines: PackedStringArray, start: int) -> int:
	var depth: int = _bracket_delta(lines[start])
	if depth <= 0:
		return -1
	for scan: int in range(start + 1, lines.size()):
		depth += _bracket_delta(lines[scan])
		if depth <= 0:
			return scan
	return -1


## The index of the line closing a multi-line collection literal that STARTS at `start` inside a
## function body at `depth`, or -1 when none does. Mirrors the top-level rule: the head sits at
## the body depth and ends on `{` or `[` (a bare `(` is a wrapped call), the lines between are
## indented deeper and non-blank, and the closing line returns to the body depth carrying only
## bracket characters.
static func _body_literal_close(lines: PackedStringArray, start: int, depth: int) -> int:
	var indent: String = "	".repeat(depth)
	var head: String = lines[start]
	if not head.begins_with(indent) or head.substr(depth).begins_with("	"):
		return -1
	var head_text: String = head.strip_edges()
	if not (head_text.ends_with("{") or head_text.ends_with("[")):
		return -1
	for scan: int in range(start + 1, lines.size()):
		var line: String = lines[scan]
		if line.strip_edges().is_empty():
			return -1
		if not line.begins_with(indent):
			return -1
		if line.substr(depth).begins_with("	"):
			continue
		for character: String in line.strip_edges():
			if not (character in "}]),"):
				return -1
		return scan if scan > start + 1 else -1
	return -1


## Action line → ACEAction when a template matches; otherwise queued as raw GDScript so the
## event still lifts (in-flow blocks re-emit verbatim at the body indent).
static func _consume_action_line(event: EventRow, line: String, _depth: int, pending_raw: PackedStringArray, reverse_entries: Array, in_loop: bool = false, blank_box: Array = []) -> void:
	# A COMMENT is never an action, whatever it says. The reverse index matches on shape, so a
	# commented-out `# velocity.x = 0.0` used to claim the Set-property template with `# velocity` as
	# its target, and the row then read `set # velocity X = 0.0` - the `#` swallowed into a sentence.
	# Comment lines go to the raw path, which turns a run of them into the CommentRow they are.
	if line.strip_edges().begins_with("#"):
		_append_raw_line(event, pending_raw, blank_box, line)
		return
	# The networking spellings the generic index has no words for (`rpc(&"f", …)` reads as
	# "Call rpc" through it). Asked FIRST so the row that knows what the line is about wins, with the
	# spelling it matched baked on so emission writes the author's bytes back.
	var networked: Dictionary = EventForgeMultiplayerLift.match_line(line)
	if not networked.is_empty():
		_flush_raw(event, pending_raw, blank_box)
		event.actions.append(_matched_spelling_action(networked, blank_box))
		return
	# The lighting spellings, on the same footing and for the same reason: the row that knows
	# the node is a light wins, with the author's own spelling baked on. Its guard reads the attached
	# scene, so a line whose target cannot be shown to be a light falls straight through to the
	# general index below and stays whatever it was.
	var lit: Dictionary = EventForgeLightingLift.match_line(line)
	if not lit.is_empty():
		_flush_raw(event, pending_raw, blank_box)
		event.actions.append(_matched_spelling_action(lit, blank_box))
		return
	# The shader spellings, on the same footing: a line naming a dial the node's own shader really
	# declares becomes the picked row that says which dial it is. A line whose node wears no material,
	# or whose name the shader has never heard of, falls straight through to the general index and
	# stays the shipped free-string row - which is the honest reading of a name nothing can confirm.
	var turned: Dictionary = EventForgeEffectLift.match_line(line)
	if not turned.is_empty():
		_flush_raw(event, pending_raw, blank_box)
		event.actions.append(_matched_spelling_action(turned, blank_box))
		return
	var matched: Dictionary = _match_entry(line, reverse_entries, "action", in_loop)
	if matched.is_empty():
		# No ACE claims it - defer to the raw block. Any pending blank rides along and lands on that
		# block when it flushes (its position among the raw lines is what needs the spacing).
		_append_raw_line(event, pending_raw, blank_box, line)
		return
	_flush_raw(event, pending_raw, blank_box)
	var action: ACEAction = ACEAction.new()
	action.provider_id = str(matched.get("provider", ""))
	action.ace_id = str(matched.get("ace_id", ""))
	action.params = matched.get("params", {})
	_stamp_body_blanks(action, blank_box)
	event.actions.append(action)


## One matched spelling as the row it is, for every family that recognises the author's own
## text rather than the canonical template. The template the matcher handed back is BAKED onto the
## action, where it outranks the descriptor's canonical one - so a row lifted from a hand-written
## file writes that file's own line, and a row the sheet authored writes the canonical form. One
## field, already serialized, already the way an addon ACE carries its own template.
static func _matched_spelling_action(matched: Dictionary, blank_box: Array) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = str(matched.get("ace_id", ""))
	action.params = matched.get("params", {})
	action.codegen_template = str(matched.get("template", ""))
	_stamp_body_blanks(action, blank_box)
	return action


## Appends a verbatim line, closing a pending COMMENT run first when this line does not continue
## it. Without this a note and the code beneath it accumulate into one block, and a block that is
## part comment and part code can be neither - which is why most comments in real bodies were
## still rendering as code even after comment runs learned to lift.
static func _append_raw_line(event: EventRow, pending_raw: PackedStringArray, blank_box: Array, line: String) -> void:
	if not pending_raw.is_empty() and _is_comment_run(pending_raw) and not _is_comment_line(line):
		_flush_raw(event, pending_raw, blank_box)
	pending_raw.append(line)


## Splits a run of comment lines wherever it changes character - a commented-out statement beside a
## note about the code, or a `# ` note broken by the bare `#` that separates two paragraphs of it.
## Each group is {marker, lines} and carries its own marker, which is what lets those spellings sit
## in one run at all: the concatenation of the groups is always the input, so emission is unchanged.
static func _split_comment_run(pending_raw: PackedStringArray) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var current: PackedStringArray = PackedStringArray()
	var current_marker: String = ""
	var current_is_code: bool = false
	for line: String in pending_raw:
		var marker: String = _comment_marker_of(line)
		var is_code: bool = not CommentRow.code_text(line.substr(marker.length())).is_empty()
		if not current.is_empty() and (is_code != current_is_code or marker != current_marker):
			groups.append({"marker": current_marker, "lines": current})
			current = PackedStringArray()
		current.append(line)
		current_marker = marker
		current_is_code = is_code
	if not current.is_empty():
		groups.append({"marker": current_marker, "lines": current})
	return groups


static func _flush_raw(event: EventRow, pending_raw: PackedStringArray, blank_box: Array = []) -> void:
	if pending_raw.is_empty() or event == null:
		return
	# A run that is ENTIRELY `# ` comments becomes a real CommentRow - the same resource a comment
	# authored in the sheet uses - so it drags, disables and converts like any other comment rather
	# than being a code block that merely looks like one. Emission writes it back as
	# `<indent># <text>`, which is byte-identical only for lines starting with exactly "# ";
	# anything else (a `#comment` with no space, a `##` doc line) stays verbatim rather than risk
	# the round-trip.
	if _is_comment_run(pending_raw):
		# A run that mixes a commented-out STATEMENT with a note about it is two different things
		# said in the same marker: one is a row somebody switched off, the other is prose. Split at
		# that boundary so each becomes its own comment row - which is also what lets the switched-off
		# one be read, dragged and switched back on by itself. Byte-neutral: consecutive comment rows
		# re-emit their lines in order with their own marker.
		var first_note: bool = true
		for group: Dictionary in _split_comment_run(pending_raw):
			var comment_marker: String = str(group["marker"])
			var note: CommentRow = CommentRow.new()
			var note_lines: PackedStringArray = PackedStringArray()
			for comment_line: String in (group["lines"] as PackedStringArray):
				note_lines.append(comment_line.substr(comment_marker.length()))
			note.text = "
".join(note_lines)
			# Recording the marker is what lets an unusual one be claimed at all: emission writes it
			# back verbatim, so `#no space` and `## doc` reproduce as written instead of gaining or
			# losing a character. Left empty for the ordinary "# ", which every authored comment uses.
			note.source_marker = "" if comment_marker == "# " else comment_marker
			if first_note:
				_stamp_body_blanks(note, blank_box)
				first_note = false
			event.actions.append(note)
		pending_raw.clear()
		return
	# One STATEMENT, one action. A run of unmatched lines used to arrive as a single wall of code;
	# split at statement boundaries each line becomes its own action row - selectable, disableable
	# and draggable into a different order - which is what the condition/action model means. A
	# statement that OWNS indented lines (a `for` header, a multi-line string) keeps them, because
	# they are one statement and separating them would be a lie about the code.
	#
	# Byte-neutral: consecutive verbatim rows re-emit by appending their lines in order, so the
	# pieces re-join exactly. The guard re-joins them and falls back to the single block if they
	# ever do not.
	var statements: Array[PackedStringArray] = _split_statements(pending_raw)
	var rejoined: PackedStringArray = PackedStringArray()
	for piece: PackedStringArray in statements:
		rejoined.append_array(piece)
	if statements.size() < 2 or rejoined != pending_raw:
		var block: RawCodeRow = RawCodeRow.new()
		block.code = "\n".join(pending_raw)
		# Import triage: these lines matched no ACE template, so they stayed verbatim. Record why
		# (non-emitted - never affects the byte-exact round-trip) so the editor can show an
		# actionable "stayed as code" hint instead of an opaque block. See RawCodeRow.lift_note.
		block.lift_note = "no matching ACE template"
		_stamp_body_blanks(block, blank_box)
		event.actions.append(block)
		pending_raw.clear()
		return
	var first: bool = true
	for piece: PackedStringArray in statements:
		var statement_row: RawCodeRow = RawCodeRow.new()
		statement_row.code = "\n".join(piece)
		statement_row.lift_note = "no matching ACE template"
		if first:
			_stamp_body_blanks(statement_row, blank_box)
			first = false
		event.actions.append(statement_row)
	pending_raw.clear()


## Which lines sit INSIDE a triple-quoted string. A multi-line string is ONE statement however its
## content is indented, and its body routinely starts at column 0 - so without this a split point
## can land in the middle of a string literal, leaving rows that are fragments of one value.
static func _string_interior_mask(lines: PackedStringArray) -> PackedInt32Array:
	var mask: PackedInt32Array = PackedInt32Array()
	var inside: bool = false
	for line: String in lines:
		mask.append(1 if inside else 0)
		if line.count("\"\"\"") % 2 == 1:
			inside = not inside
	return mask


## One verbatim row PER STATEMENT for a run of lines. Every place that parks unmatched code on an
## event goes through this, so a match-case body, an inlined-async residue and an ordinary run all
## produce the same thing: rows, not a wall. Byte-neutral - the rows re-emit by appending their
## lines in order, so the run reproduces exactly.
static func _statement_rows(run: PackedStringArray) -> Array[RawCodeRow]:
	var rows: Array[RawCodeRow] = []
	for piece: PackedStringArray in _split_statements(run):
		var row: RawCodeRow = RawCodeRow.new()
		row.code = "
".join(piece)
		row.lift_note = "no matching ACE template"
		rows.append(row)
	return rows


## The net change in bracket depth a line makes, ignoring anything inside a string literal or
## after a `#` comment. A statement CONTINUES while brackets are open, so a wrapped call or a
## multi-line collection is one statement however many lines it spans - without this a split
## lands inside the brackets and leaves rows holding a fragment of one expression, with its
## closing bracket stranded on a row of its own.
static func _bracket_delta(line: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			break
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		index += 1
	return depth


## Splits a run of verbatim body lines into ONE PIECE PER STATEMENT. The run's own shallowest
## indent is the statement level - not column 0 - because a run collected from inside an unlifted
## `if` or `for` is entirely indented, and measuring from column 0 would see no statements there
## at all and leave the whole nested body as one wall. A statement takes every following
## deeper-indented line with it (its block body, or the rest of a multi-line string), and blank
## lines ride with the statement they follow. Line-preserving: the pieces always concatenate back
## to the input, which is what lets the caller prove the split changed no bytes.
static func _split_statements(pending_raw: PackedStringArray) -> Array[PackedStringArray]:
	var interior: PackedInt32Array = _string_interior_mask(pending_raw)
	var base_indent: int = -1
	for scan_index: int in pending_raw.size():
		if pending_raw[scan_index].strip_edges().is_empty() or interior[scan_index] == 1:
			continue
		var indent: int = pending_raw[scan_index].length() - pending_raw[scan_index].lstrip("\t ").length()
		base_indent = indent if base_indent < 0 else mini(base_indent, indent)
	if base_indent < 0:
		return [pending_raw]
	var pieces: Array[PackedStringArray] = []
	var current: PackedStringArray = PackedStringArray()
	var open_brackets: int = 0
	for line_index: int in pending_raw.size():
		var line: String = pending_raw[line_index]
		var line_indent: int = line.length() - line.lstrip("\t ").length()
		var at_statement_level: bool = line_indent == base_indent and interior[line_index] == 0 and open_brackets == 0
		var starts_statement: bool = not line.strip_edges().is_empty() and at_statement_level
		if starts_statement and not current.is_empty():
			pieces.append(current)
			current = PackedStringArray()
		current.append(line)
		if interior[line_index] == 0:
			open_brackets = maxi(open_brackets + _bracket_delta(line), 0)
	if not current.is_empty():
		pieces.append(current)
	# A LEADING run of deeper-than-base lines is the body of an unlifted control block above the
	# run (only the first piece can have this shape - every later piece starts with a base-level
	# statement). Left as one piece it renders as the last wall of code in the corpus; re-split at
	# its OWN shallowest indent it becomes ordinary statement rows under the header row, exactly
	# the rule everything else already gets. Recursion terminates because the sub-run's base is
	# strictly deeper, and the result is still line-preserving.
	if pieces.size() > 0 and _no_line_at_indent(pieces[0], base_indent, _string_interior_mask(pieces[0])):
		var lead_pieces: Array[PackedStringArray] = _split_statements(pieces[0])
		if lead_pieces.size() > 1:
			pieces = lead_pieces + pieces.slice(1)
	return pieces


## True when NO non-blank line of the run sits at `indent` (outside string interiors) - the
## orphan-continuation shape the re-split above exists for.
static func _no_line_at_indent(run: PackedStringArray, indent: int, interior: PackedInt32Array) -> bool:
	for line_index: int in run.size():
		if run[line_index].strip_edges().is_empty() or interior[line_index] == 1:
			continue
		if run[line_index].length() - run[line_index].lstrip("	 ").length() == indent:
			return false
	return true


## The comment marker EVERY line of a run shares, or "" when the run is not all comments (or the
## lines disagree). A run must be uniform, because emission writes one marker before every line -
## claiming a mixed run would rewrite half of it.
static func _comment_marker_of(line: String) -> String:
	if not line.begins_with("#"):
		return ""
	if line.begins_with("## "):
		return "## "
	if line.begins_with("##"):
		return "##"
	if line.begins_with("# "):
		return "# "
	return "#"


static func _is_comment_line(line: String) -> bool:
	return line.begins_with("#")


## Whether every line of a run is a comment. The MARKERS need not agree: a paragraph of `# ` notes
## broken by the bare `#` that separates two of them is one run of comments and reads as one, and
## before the split below carried a marker per group that whole run - and the function it sat in -
## stayed a wall of code.
static func _is_comment_run(pending_raw: PackedStringArray) -> bool:
	if pending_raw.is_empty():
		return false
	for line: String in pending_raw:
		if not _is_comment_line(line):
			return false
	return true


## Carries a captured run of author-facing blank lines onto the visible row/action that follows it,
## as transient meta the compiler re-emits (see __source_body_blanks in _emit_event_body). The count
## lives in a single-element box so it can survive across the append helpers above; stamping clears it
## so exactly one row wears each run. A no-op when the box is empty or zero (the ordinary no-blank path,
## and every authored sheet - the meta only ever originates here at lift time).
static func _stamp_body_blanks(resource: Resource, blank_box: Array) -> void:
	if resource == null or blank_box.is_empty() or int(blank_box[0]) <= 0:
		return
	resource.set_meta("__source_body_blanks", int(blank_box[0]))
	blank_box[0] = 0


## Reverse index over builtin descriptors: template → anchored regex with named captures.
## The reverse index every lift pass matches lines against, built once per descriptor set and then
## handed out BY REFERENCE. Composing it compiles a RegEx for every reversible descriptor template
## (hundreds), which is why it is memoized rather than rebuilt: the per-function lift path used to
## call this once per function, so opening a file with N functions paid N full index builds and that
## single line was ~80% of the time an open took. Entries are read-only by contract - _match_entry
## only reads them, and nothing anywhere assigns into an entry - so sharing one Array is safe,
## including with the import worker thread (the job warms this on the main thread before starting).
## Builds the lift's compiled-once matchers on the CALLING thread. The open job calls this from the
## main thread before starting the worker, so the worker only ever reads them - the same discipline
## the reverse index above follows, and for the same reason.
static func warm_matchers() -> void:
	if _loop_index_probe == null:
		_loop_index_probe = RegEx.new()
		_loop_index_probe.compile("^var ([A-Za-z_][A-Za-z0-9_]*): int = -1$")


static func _build_reverse_entries() -> Array:
	var descriptors: Array = ACERegistry.get_all_descriptors()
	if _cached_reverse_count == descriptors.size() and not _cached_reverse_entries.is_empty():
		return _cached_reverse_entries
	var built: Array = _compose_reverse_entries(descriptors)
	_cached_reverse_entries = built
	_cached_reverse_count = descriptors.size()
	return built


## The picker categories kept OUT of the reverse index, because the sentence grammar
## already has a better sentence for every line they write. Frozen alongside the readings: adding a
## category here is a promise that the reading covers it, and dropping one back in would silently
## swap those rows' words.
## Join them: every row on the 3D page writes a line the sentence grammar reads in the
## sheet's own words - "Move forward at speed", "Is within 45° of facing enemy" - where the lifted row
## could only repeat the template with the raw basis expression in it. The move template is the other
## half of the reason: `global_position += {direction} * {speed} * {delta_t}` is a GENERAL spelling,
## and admitting it to the reverse index would have it claim every three-part movement line in every
## project, shadowing readings that say more than it can.
const REVERSE_LIFT_EXCLUDED_CATEGORIES: PackedStringArray = [
	"AJAX", "Lighting", "Video", "3D: Move & Turn", "3D: Place", "3D: See"
]

## The same promise, for two rows that live in a category most of whose verbs SHOULD lift. A
## positional sound's two knobs read under the player they belong to, which the lifted row cannot say.
const REVERSE_LIFT_EXCLUDED_ACE_IDS: PackedStringArray = [
	"AudioSetHearingDistance", "AudioSetFalloff",
	# The two mission-clock rows whose templates are a plain Set and a plain Add. Their VALUE is
	# the minutes:seconds field the picker offers, not a new spelling - so admitting them to the
	# reverse index would have them claim every assignment and every increment in every project, and
	# the shipped countdown reading already says what those lines are.
	"StartMissionTimer", "AddMissionTime",
	# The boolean pair. `x = y` is Set value's own template and `{var_name}` alone would claim
	# every bare identifier in every file - both rows say a CLEARER sentence about a line that
	# already lifts, so they author only and the general spellings keep their existing rows.
	"SetBool", "IsBoolSet",
	# Rows whose template is a perfectly ordinary line - `x = y`, `x = ""`,
	# `x += 1`, `x = load(p)`, `list[i]`, `list.size()`, `a in b`, `absf(a - b)`. Each is exactly
	# right for the row that writes it and hopelessly general for the index that reads lines BACK:
	# admitted, they would claim every assignment, every resource load and every list length in
	# every project, and the specific rows those lines belong to would stop being recognised. They
	# author fine; they just do not get to speak for lines nobody wrote them for.
	# CloseInputWindow stays out for a second reason now that it carries an optional Prompt tail:
	# `{open_flag} = false{prompt}` ends in a capture that needs at least one character, so admitted
	# it would claim every `x = false…` line in every project rather than the one row it writes.
	# (Its sibling OpenInputWindow needs no entry here: a template spanning two lines can never match
	# the single lines the reverse index is asked about, so the tail widens nothing.)
	"StartListeningForControl", "StopListeningForControl", "CloseInputWindow", "CountMashPress",
	# Buffer Input, now that it is counted in SECONDS, writes `{input} = <now> + {seconds}` -
	# which is the SAME line Open Input Window writes as its second one. That template spans two
	# lines and so never enters the index itself, and the window is put back together by the
	# reading; admitting the one-line buffer would have it claim the deadline line first and
	# leave the window as two unrelated rows. Every other "a moment from now" line in every
	# project is the same story. The FRAME-counted twin stays in the index, where
	# `Engine.get_physics_frames() + {frames}` means one thing and nothing else writes it.
	"BufferInput",
	"UsePalette", "CurrentWeapon", "SecretsFoundCount", "SecretAlreadyFound", "OffBeatBy",
	# The keycard rows, out for exactly the reason the secrets rows above are: `list.append(x)`,
	# `(a in b)` and `(not a in b)` are the list operations every project writes, and a keycard row
	# admitted to the index would speak for all of them. They author the same bytes either way; which
	# WORDS a line reads in is settled by the reading, which asks what the line is about (a list named
	# for keys, a key name beside it) before it says the word "key" at all.
	"PickUpKey", "HasKey", "NeedsKey",
	# Add Item authors one line of a menu; `x.add_item("y", 1)` is written by dropdowns, lists
	# and trees as well, and the whole point of the menu reading is that the RUN of those lines is
	# one bar naming the menu's items in order. Admitted to the reverse index the row would claim
	# each line separately, and the bar would never see a run to collapse.
	"MenuAddItem",
	# The facing rows exist once per HOST, because `flip_h` lives on four unrelated classes
	# and the picker must offer the row only where the node can do it. That is a picker fact, not a
	# reading one: `flip_h = true` is one line whichever class wrote it, so exactly ONE row speaks for
	# it in the reverse index and the rest of the host table authors only. The kept ones are the
	# shipped SetFlipH / SetFlipV and, for the scale spellings, the Node2D / Node3D rows.
	"SetMirroredSprite2D", "SetMirroredSprite3D", "SetMirroredTextureRect",
	"SetFlippedSprite3D", "SetFlippedTextureRect", "SetFlippedAnimatedSprite2D",
	"IsMirroredAnimatedSprite2D", "IsMirroredSprite3D", "IsMirroredTextureRect",
	"IsFlippedAnimatedSprite2D", "IsFlippedSprite3D", "IsFlippedTextureRect",
	"IsMirroredSpatial", "IsMirroredControl", "SetMirroredLabel3D",
	# Two Multiplayer rows whose template is another row's template, letter for letter. Reject
	# player writes the same `disconnect_peer(id)` line Kick player writes, and only the event above
	# it says which of the two a reader means - so the bare line reads as Kick, and Reject authors.
	# Started as writes `OS.has_feature(tag)`, which is exactly Platform Has Feature's line; that row
	# already speaks for every feature test in every project, multiplayer tag or not.
	"RejectPlayer", "StartedAs",
	# Despawn writes `queue_free()`, which is the line every project writes to remove any node at
	# all - the networked meaning is in WHERE it runs (on the owner, with a spawner watching), not in
	# the line. Admitted to the index it would relabel every removal in every project as a networking
	# row, so it authors only and a bare `queue_free()` keeps the row it already had.
	"Despawn"
]


static func _compose_reverse_entries(all_descriptors: Array) -> Array:
	var entries: Array = []
	var brace_regex: RegEx = RegEx.new()
	brace_regex.compile("\\{[^}]*\\}")
	for descriptor: ACEDescriptor in all_descriptors:
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
		# The categories whose lines the READING already says better than the row would. A lift is only
		# ever worth making when the row it produces reads at least as well as the line it replaced,
		# and for these three it does not: the reading names the object the row belongs to (AJAX, the
		# light itself, Video) and says a brightness as the percentage a reader set, where the lifted
		# row can only repeat the template's own words with the raw value in them. Nothing about the
		# bytes changes either way - a line kept verbatim re-emits exactly as it came in - so the only
		# question is which of the two a reader would rather have, and it is the reading.
		if REVERSE_LIFT_EXCLUDED_CATEGORIES.has(descriptor.category) \
				or REVERSE_LIFT_EXCLUDED_ACE_IDS.has(descriptor.ace_id):
			continue
		# And a row whose choices come out of the open project is never claimed by a template match,
		# for the reason its own flag gives: deciding that `material.set_shader_parameter(&"x", v)` is
		# a DIAL row takes a question only the project can answer - does that node wear a material,
		# and does its shader declare `x`. The family's matcher asks it before this index is reached,
		# and a line it cannot answer for keeps whichever row it already had.
		if descriptor.is_project_scoped:
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
			entries.append({"provider": descriptor.provider_id, "ace_id": descriptor.ace_id, "kind": kind, "regex": regex, "literal_len": literal_len, "order": entries.size(), "assign_op": assign_op, "loop_control": loop_control, "decl_name": decl_name, "required_literal": _longest_literal_run(variant), "scope_trigger": str(TRIGGER_SCOPED_ACES.get(descriptor.ace_id, ""))})
	# Try SPECIFIC templates before generic catch-alls. The Core generics (SetVar `{var_name} = {value}`,
	# CallFunction `{function_name}({args})`, …) use lazy `.+?` captures that match almost any
	# assignment/call, so in raw registry order they SHADOW every specific node ACE (`position = …`
	# would reverse-lift as SetVar). _match_entry is first-match, so stable-sort by literal-char count
	# (descending) - `velocity = {vel}` outranks `{var_name} = {value}`; the `order` tiebreaker keeps
	# registry order among equal-specificity twins (sort_custom is not guaranteed stable).
	entries.sort_custom(func(a, b): return a["literal_len"] > b["literal_len"] if a["literal_len"] != b["literal_len"] else a["order"] < b["order"])
	return entries


static func _match_entry(line: String, reverse_entries: Array, kind: String, in_loop: bool = true, scope_trigger: String = "") -> Dictionary:
	# A call to a function THIS FILE declares is that call, whatever else in the vocabulary happens to
	# spell the same words. `restart()` beside a `func restart():` in the same script means the
	# author's own function; a particle verb whose template is also `restart()` is more specific by
	# character count and used to win, so the row said "Restart particles" about a call that restarts
	# a menu. The emitted line is identical either way - only the sentence was wrong.
	var own_call: bool = kind == "action" and _is_own_function_call(line)
	for entry: Variant in reverse_entries:
		if str((entry as Dictionary).get("kind", "")) != kind:
			continue
		if own_call and str((entry as Dictionary).get("ace_id", "")) != "CallFunction":
			continue
		# A loop-control action (`break`/`continue`) is only valid - and only lifts - inside a loop body.
		if bool((entry as Dictionary).get("loop_control", false)) and not in_loop:
			continue
		# A trigger-scoped entry reads that trigger's arguments (see TRIGGER_SCOPED_ACES), so it is only
		# in the running inside that handler - elsewhere the same text is ordinary game code.
		var entry_scope: String = str((entry as Dictionary).get("scope_trigger", ""))
		if not entry_scope.is_empty() and entry_scope != scope_trigger:
			continue
		# Cheap necessary conditions before the expensive one. The pattern is anchored and every
		# placeholder needs at least one character, so a line shorter than the template's literal text
		# cannot match; and it must contain the template's longest literal run (see
		# _longest_literal_run). Hundreds of entries are scanned per line, so rejecting the impossible
		# ones with a length compare and a substring search - instead of a PCRE run each - is where
		# most of the matching time went. Neither test can reject a line the regex would have matched.
		if line.length() < int((entry as Dictionary).get("literal_len", 0)):
			continue
		var required_literal: String = str((entry as Dictionary).get("required_literal", ""))
		if not required_literal.is_empty() and not line.contains(required_literal):
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
		var lopsided: bool = false
		for group_name: String in regex.get_names():
			params[group_name] = regex_match.get_string(group_name)
			# A captured param is always a WHOLE expression, so its brackets and quotes must balance.
			# A lazy capture that stopped mid-expression produces a lopsided one - `add_look((event as
			# InputEventMouseMotion).relative.x, …)` matched Call Method as target `add_look((event as
			# InputEventMouseMotion)`, method `relative.x, `, which reads as nonsense on the row. Reject
			# it here and the next candidate (Call Function, whose capture spans the whole argument
			# list) claims the line instead.
			if not _is_balanced_expression(str(params[group_name])):
				lopsided = true
				break
		if lopsided:
			continue
		# A declaration template's `{name}` must be a bare identifier - otherwise the lazy capture carved a
		# string/expression value at an internal `:` or `=` (see decl_name). Reject so the plain form wins.
		if bool((entry as Dictionary).get("decl_name", false)) and not _is_bare_identifier(str(params.get("name", ""))):
			continue
		# Is The Same Object's `{a} == {b}` matches every equality there is. It may only CLAIM one
		# that reads as an identity test; anything else falls through to Compare Variable, whose
		# `{var_name} {op} {value}` says what `i == 1` actually asks. Same bytes either way.
		if str((entry as Dictionary).get("ace_id", "")) == "IsSameObject" and not _reads_as_object_identity(params):
			continue
		# A keycard is a name in a list, so `keys.append("red_key")` is Push Back's spelling
		# exactly. Push Back steps aside for the one shape that is unmistakably about keys - a list
		# named for keys, with a key name going into it - which leaves the line for the reading that
		# says "Pick up key". Every other append in every project still reads as Push Back, and the
		# bytes are the same line either way, so nothing about what the file compiles to moves.
		if KEYCARD_SHADOWED_ACES.has(str((entry as Dictionary).get("ace_id", ""))) and _reads_as_keycard(params):
			continue
		return {"provider": (entry as Dictionary).get("provider"), "ace_id": (entry as Dictionary).get("ace_id"), "params": params}
	return {}


## The generic list rows that must NOT claim a keycard line, because the reading has better
## words for it. Frozen alongside the keycard reading: dropping an id back out here would silently
## swap those rows' words back to the list spelling.
const KEYCARD_SHADOWED_ACES: Dictionary = {"ArrayAppend": true}


## Whether a matched row is about KEYS rather than about a list: it names a list called `keys`
## (or `<colour>_keys`) AND a key beside it - a quoted name ending `_key`, or the `needs_key` a door
## carries. Both halves are required, so a `keys.append(score)` is still a plain push back and an
## `inventory.append("red_key")` still reads as the inventory line it is.
static func _reads_as_keycard(params: Dictionary) -> bool:
	var names_a_list: bool = false
	var names_a_key: bool = false
	for value: Variant in params.values():
		var text: String = str(value).strip_edges()
		if _is_bare_identifier(text) and (text == "keys" or text.ends_with("_keys")):
			names_a_list = true
		elif text.begins_with("\"") and text.ends_with("_key\""):
			names_a_key = true
		elif text == "needs_key" or text.ends_with(".needs_key"):
			names_a_key = true
	return names_a_list and names_a_key


## True when brackets and quotes balance across the text - the shape any complete GDScript expression
## has. Quote-aware, so a bracket inside a string literal never counts. Empty text is balanced.
static func _is_balanced_expression(text: String) -> bool:
	var round_depth: int = 0
	var square_depth: int = 0
	var curly_depth: int = 0
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
			index += 1
			continue
		match character:
			"\"", "'":
				quote = character
			"(":
				round_depth += 1
			")":
				round_depth -= 1
			"[":
				square_depth += 1
			"]":
				square_depth -= 1
			"{":
				curly_depth += 1
			"}":
				curly_depth -= 1
		if round_depth < 0 or square_depth < 0 or curly_depth < 0:
			return false
		index += 1
	return round_depth == 0 and square_depth == 0 and curly_depth == 0 and quote.is_empty()


## The file's object-typed member names, read off its `var`/`@onready var` declarations. Only a
## declaration with an EXPLICIT annotation counts: `var host: Node` says what it holds, `var best = null`
## does not, and guessing would be exactly the confident lie this whole grammar refuses.
static func _object_names_from_source(source: String) -> Dictionary:
	var names: Dictionary = {}
	var declaration: RegEx = RegEx.new()
	if declaration.compile("^(?:@onready\\s+)?var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*([A-Za-z_][A-Za-z0-9_]*)") != OK:
		return names
	for line: String in source.split("\n"):
		if line.begins_with("\t") or line.begins_with(" "):
			continue  # a member is written at file scope; a local is somebody else's business
		var found: RegExMatch = declaration.search(line.strip_edges())
		if found == null:
			continue
		if found.get_string(2) in VALUE_TYPE_NAMES:
			continue
		names[found.get_string(1)] = true
	return names


## True when an `==` / `!=` is really asking "are these the SAME OBJECT" rather than "is this value
## that value". The reverse template of Is The Same Object is the bare `{a} == {b}`, which matches
## every equality ever written, so without this test `if i == 1:` read "i is the same object as 1".
## One side has to be recognisably a reference: `null`, `self`, a `$Node` / `%Node` path, a lookup that
## returns a node, or a member the file declared with an object type.
static func _reads_as_object_identity(params: Dictionary) -> bool:
	return _is_object_expression(str(params.get("a", ""))) or _is_object_expression(str(params.get("b", "")))


## True when one side of an equality is clearly a node/object reference (see _reads_as_object_identity).
static func _is_object_expression(text: String) -> bool:
	var expression: String = text.strip_edges()
	if expression.is_empty():
		return false
	if expression in ["null", "self"]:
		return true
	if expression.begins_with("$") or expression.begins_with("%"):
		return true
	for lookup: String in ["get_node(", "get_parent()", "get_owner()", "get_tree()", "instantiate()"]:
		if expression.contains(lookup):
			return true
	return _is_bare_identifier(expression) and _object_reference_names.has(expression)


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
## The longest run of LITERAL text in a template - the cheap prefilter _match_entry tries before it
## pays for a regex. _template_to_regex emits every literal run escaped verbatim into an anchored
## pattern, and no run sits inside an alternation or an optional group, so any line the pattern can
## match must CONTAIN this run. String.contains is far cheaper than a PCRE search, and the index holds
## hundreds of entries that are scanned per line, so skipping the ones that cannot possibly match is
## most of the matching cost. Segmented exactly like _template_to_regex (same brace walk, same
## "a brace pair that is not a parameter name is literal text" rule) so the two cannot drift.
## Empty when the template is all placeholders - then there is nothing to prefilter on.
static func _longest_literal_run(template: String) -> String:
	var longest: String = ""
	var cursor: int = 0
	while cursor < template.length():
		var open: int = template.find("{", cursor)
		if open == -1:
			var tail: String = template.substr(cursor)
			return tail if tail.length() > longest.length() else longest
		var close: int = template.find("}", open)
		if close == -1:
			var rest: String = template.substr(cursor)
			return rest if rest.length() > longest.length() else longest
		var literal: String = template.substr(cursor, open - cursor)
		if literal.length() > longest.length():
			longest = literal
		var param_name: String = template.substr(open + 1, close - open - 1)
		if not _is_bare_identifier(param_name):
			# Not a capture - the braces are literal code (an empty dictionary literal above all), and
			# _template_to_regex escapes them into the pattern as text, so they may join this run.
			var braced: String = template.substr(open, close - open + 1)
			if braced.length() > longest.length():
				longest = braced
		cursor = close + 1
	return longest


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
		# A brace pair that does not spell a parameter NAME is literal code, not a capture - GDScript's
		# empty-dictionary literal `{}` above all. Injected raw it becomes an illegal group name
		# (`(?<>.+?)`), which fails the whole compile: the ACE drops out of the reverse index and every
		# lift attempt prints a PCRE error. Matching it as text keeps both the pattern and the console clean.
		if not _is_bare_identifier(param_name):
			pattern += _escape_regex(template.substr(open, close - open + 1))
			cursor = close + 1
			continue
		# Call-argument captures may legitimately be empty - a zero-arg call like `landed.emit()`,
		# `jump()` or `super()` - so `{args}` uses a zero-or-more lazy capture; every other placeholder
		# (value, expression, target…) still requires at least one char. An empty match can only land
		# against the literal `()` in the template, so this never over-claims, and it round-trips.
		var quantifier: String = "*?" if param_name == "args" else "+?"
		# A placeholder the template REPEATS (`{var_name} = not {var_name}`) must match the same text
		# both times - a backreference, not a second capture. Without it Toggle claimed
		# `_running = not _phases.is_empty() and ...` with var_name = _running, re-emitted it as
		# `_running = not _running`, and the whole file reverted on the byte-verify.
		if pattern.contains("(?<%s>" % param_name):
			pattern += "\\k<%s>" % param_name
		else:
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
