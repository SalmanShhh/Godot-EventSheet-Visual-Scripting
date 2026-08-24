# EventForge - Event sheet compiler
# Compiles EventSheetResource assets into deterministic GDScript output.
#
# THE PIPELINE (main path, in emission order - each phase is a "## …" section below):
#   1. includes merge (event-sheet-style; policy-gated - see _merge_includes/_addon_policy)
#   2. header comments, @tool, @ace_tags, @icon, class_name, extends
#   3. behavior host accessor (behavior_mode)
#   4. enums → signals → variables (with Inspector attributes) → tree variables
#      → group locals → stateful-condition members → Lane B uses-instances
#   5. class-level raw GDScript blocks
#   6. trigger sections (events grouped per trigger; _emit_event_body does rows,
#      pick filters/loops, stateful preludes, breakpoints, actions, sub-events)
#   7. sheet functions, deferred comments, provider/stateful member insertion
# The EXTERNAL path (_compile_external) is order-preserving instead: rows re-emit in
# file order so untouched GDScript-backed sheets reproduce byte-identically.
# CONTRACTS: parity (plain GDScript, no runtime indirection), lossless round-trips,
# bake-at-apply (templates), policy-gates-never-bytes (composition).
@tool
class_name SheetCompiler
extends RefCounted

const VERSION: String = "0.17.0"

## X30. The name of the shared aimed-floor helper the cursor and floor expressions call. One
## definition per file, whichever of them the picker wrote first.
const AIMED_CURSOR_HELPER: String = "__eventsheets_aim_floor"

## X30, the 2D twins. The point query that answers what the cursor is over on a 2D canvas, and the
## tile lookup that answers which cell it is over. Same discipline as the aimed-floor helper above:
## one definition per file, appended last, skipped outright when the file already defines it.
const POINT_CURSOR_HELPER: String = "__eventsheets_object_at_2d"
const TILE_CURSOR_HELPER: String = "__eventsheets_tile_under"

## V4. The comment written above a hoisted Static local, naming the ROW the member belongs to. A
## cosmetic marker with zero runtime weight, exactly like the `# @group:` row tags: it is what lets an
## opened file hand the member back to the row instead of reading it as an ordinary private member.
const STATIC_LOCAL_MARKER: String = "# @static_local:%s"

# Set per-compile from sheet.emit_breakpoints (single-threaded compiles).
static var _emit_breakpoints_flag: bool = false
static var _emit_event_trace_flag: bool = false

# Live-values payload for the current compile (same single-threaded pattern as the
# breakpoints flag - the trigger-section helper injects it into _process).
static var _live_values_payload: String = ""
# Whether the current debug compile still needs the edit-back receiver emitted (the
# Live Values window's value edits arrive through it). Cleared once injected.
static var _live_values_receiver_pending: bool = false
# Whether the throttled _process (live-values and/or event-trace senders) has been emitted yet,
# so the synthesized _process and the user-_process injection never both emit it. This is the
# coordination signal that lets the event trace run WITHOUT live values (empty payload).
static var _throttle_process_emitted: bool = false
# Whether the current debug compile still needs the runtime-error reporter ARMED in _ready
# (OS.add_logger of the emitted Logger subclass). Cleared once injected, like the receiver flag.
static var _error_reporter_pending: bool = false

# Runtime-toggleable groups: event -> "__group_<snake>_active" guard (per-compile).
static var _runtime_group_guards: Dictionary = {}
# [group snake-name, initially_active] pairs for member emission, in encounter order.
static var _runtime_group_members: Array = []
# Event-group round-trip (EventGroup ↔ GDScript). Groups dissolve into the flat trigger sections at
# compile, so they're preserved with cosmetic comment markers the importer reconstructs them from:
# a class-scope `## @ace_group(...)` declaration per group, and a `# @group:<slug>` line before each
# member event. _group_slugs maps each EventGroup → its deterministic slug; _row_group_path maps each
# direct member EventRow → its group's slug. Both are filled per-compile (see _collect_groups) and
# read during emit; they carry NO runtime weight (the markers are comments).
static var _group_slugs: Dictionary = {}
static var _row_group_path: Dictionary = {}
# Host-targeting prefix for {host.} ACE templates: "host" inside a behavior sheet (where node-scoped
# ACEs must call on the parent host, not the behavior Node itself), "" everywhere else. Per-compile.
static var _behavior_host_default: String = ""

# Serializes every compile. The per-compile scratch statics above (and the scratch output file a
# verify compile writes) are shared process-wide, and opening a .gd as a sheet now runs its lift -
# which recompiles the whole sheet to byte-verify it - on a WORKER THREAD while the editor keeps
# painting. A compile-on-save or a Project Doctor pass on the main thread would otherwise stomp
# that scratch mid-emission. Locked at the two PUBLIC entry points ONLY (compile and
# emit_function_block_text); no helper takes it, and neither entry point calls the other, so the
# lock is never taken twice on one thread and cannot deadlock.
static var _compile_mutex: Mutex = Mutex.new()


## Compiles an event sheet resource to a GDScript output file.
## omit_generated_banner drops the "AUTO-GENERATED / DO NOT EDIT" header - used when the .gd IS the
## user's source of truth (Save As .gd), not a regenerated companion of a .tres sheet.
## The body lives in _compile_body so this can hold the compile lock across every early return
## (GDScript has no try/finally, so a wrapper is the only leak-proof shape).
static func compile(sheet: EventSheetResource, output_path: String = "", omit_generated_banner: bool = false) -> Dictionary:
	_compile_mutex.lock()
	var locked_result: Dictionary = _compile_body(sheet, output_path, omit_generated_banner)
	_compile_mutex.unlock()
	return locked_result


static func _compile_body(sheet: EventSheetResource, output_path: String = "", omit_generated_banner: bool = false) -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"errors": [] as Array[String],
		"warnings": [] as Array[String],
		"output": "",
		# Provenance: [{uid: String (resource instance id), start: int, end: int, kind: String}]
		# with 1-based inclusive line numbers into "output". Lets the editor highlight the
		# generated lines for a selected sheet row.
		"source_map": [] as Array
	}

	if sheet == null:
		result["success"] = false
		(result["errors"] as Array[String]).append("Sheet is null")
		return result

	# Host-targeting default for {host.} templates - reset before the external-source path so a
	# prior behavior compile never leaks "host" into a later non-behavior compile.
	_behavior_host_default = ""

	# GDScript-backed sheets (opened FROM a .gd file) compile via the order-preserving
	# external path: no generated header, no synthesized extends, rows emit in sheet order
	# so an untouched file reproduces byte-identically.
	if not sheet.external_source_path.is_empty():
		return _compile_external(sheet, result, output_path)

	_emit_breakpoints_flag = sheet.emit_breakpoints
	_emit_event_trace_flag = false
	_throttle_process_emitted = false
	_runtime_group_guards = {}
	_runtime_group_members = []
	_group_slugs = {}
	_row_group_path = {}
	# Event-sheet-style includes: merge included sheets' rows/variables/functions (compile-time
	# only; the root sheet wins collisions, cycles are skipped with warnings).
	# Include ORDER: an included (library) sheet's events run BEFORE the root sheet's own events -
	# shared setup/library logic initializes first (the common "include the library at the top"). So the
	# merged list is seeded with the includes, and the root's own events are appended last.
	var all_events: Array = []
	var all_functions: Array = sheet.functions.duplicate()
	var merged_variables: Dictionary = sheet.variables.duplicate(true)
	if not sheet.includes.is_empty():
		var visited: Dictionary = {}
		if not sheet.resource_path.is_empty():
			visited[sheet.resource_path] = true
		_merge_includes(sheet, all_events, all_functions, merged_variables, visited, result["warnings"], result["errors"], 1)
		if not (result["errors"] as Array).is_empty():
			result["success"] = false
			return result
	all_events.append_array(sheet.events)
	# Event-group round-trip: collect every group → deterministic slug now (includes' groups are
	# already merged in), so the `## @ace_group` declarations can emit after the class description and
	# the per-row `# @group:` tags emit in the trigger sections. Fills _group_slugs read during emit.
	var group_decls: Array = []
	_collect_groups(all_events, group_decls, {}, _group_slugs)

	var lines: PackedStringArray = PackedStringArray()
	if not omit_generated_banner:
		lines.append("# AUTO-GENERATED by EventForge v%s" % VERSION)
		lines.append("# Source: %s" % sheet.resource_path)
		lines.append("# DO NOT EDIT — this file is regenerated on every compile.")
		lines.append("")
	# Tool sheets (EXPERIMENTAL): @tool must precede class_name/extends.
	if sheet.tool_mode:
		lines.append("@tool")
	# Test sheets carry a marker line so a runner can FIND them without a registry: the headless
	# tools/run_test_sheets.gd and the editor's Run Tests panel both scan for this exact comment.
	# Metadata only (the importer recovers it without removing it from a .gd sheet's verbatim
	# prelude, exactly like @ace_tags), so it can never double-emit.
	if sheet.test_mode:
		lines.append("## @ace_test_sheet")
	# A named sheet defines a custom node type: `@icon` + `class_name` make the generated
	# script register in the Create Node dialog exactly like hand-written GDScript.
	if not sheet.custom_class_name.strip_edges().is_empty():
		if not sheet.addon_tags.is_empty():
			lines.append("## @ace_tags(%s)" % ", ".join(sheet.addon_tags))
		# Class-level picker defaults + the expose-all opt-in: metadata-only lines like
		# @ace_tags above (the importer recovers them without removing them from the
		# prelude, so they can never double-emit).
		if not sheet.addon_category.strip_edges().is_empty():
			lines.append("## @ace_category(\"%s\")" % sheet.addon_category.strip_edges())
		if sheet.ace_expose_all_mode == "node":
			lines.append("## @ace_expose_all(node)")
		elif sheet.ace_expose_all_mode == "all":
			lines.append("## @ace_expose_all")
		# Family marker (metadata only, exactly like @ace_tags above): declares that this class is an
		# event-sheet Family, so other sheets can write one rule over ALL its instances. No code is
		# emitted from this flag - membership is an explicit "Add To Family" action - so the annotation
		# round-trips byte-exact and can never double-emit.
		if sheet.is_family:
			lines.append("## @ace_family(%s)" % sheet.custom_class_name.strip_edges())
		# Dependency declaration (metadata only, same family as @ace_tags): what this pack
		# needs installed - class names, autoload:Name, pack:folder - for the Doctor to audit.
		if not sheet.addon_requires.is_empty():
			lines.append("## @ace_requires(%s)" % ", ".join(sheet.addon_requires))
		# Pack identity metadata (version/author/help), same family: metadata-only lines the
		# importer recovers without removing, so they can never double-emit.
		if not sheet.addon_version.strip_edges().is_empty():
			lines.append("## @ace_version(%s)" % sheet.addon_version.strip_edges())
		if not sheet.addon_author.strip_edges().is_empty():
			lines.append("## @ace_author(\"%s\")" % sheet.addon_author.strip_edges())
		if not sheet.addon_help_url.strip_edges().is_empty():
			lines.append("## @ace_help(\"%s\")" % sheet.addon_help_url.strip_edges())
		if not sheet.custom_class_icon.strip_edges().is_empty():
			lines.append("@icon(\"%s\")" % sheet.custom_class_icon)
		lines.append("class_name %s" % sheet.custom_class_name.strip_edges())
	# Behavior sheets compile to attachable Node components that act on their PARENT (the
	# host) - Godot's component idiom standing in for node-attached behaviors. host_class is
	# the declared required host type, not the script's base.
	if sheet.behavior_mode:
		# Node-scoped ACEs ({host.} templates) target the parent host, not the behavior Node.
		_behavior_host_default = "host"
		lines.append("extends Node")
	else:
		lines.append("extends %s" % sheet.host_class)
	# Class description: a `##` doc comment immediately after `extends` (Godot's class-doc position),
	# so a behaviour/custom node shows its blurb in the Create Node dialog. The importer recovers the
	# `##` block right after `extends`, so it round-trips byte-identically.
	for description_line: String in _class_description_lines(sheet):
		lines.append(description_line)
	# Event-group declarations: one `## @ace_group(...)` per group at class scope, right after the doc
	# block. Main path only - the external/.gd path keeps these verbatim in its preserved prelude, so
	# emitting here too would duplicate them (compile() returns into _compile_external before this).
	_emit_group_declarations(lines, group_decls)
	# Family without a type: the @ace_family marker (and the derived family_<class> group) both need a
	# class name, so a flagged-but-unnamed sheet would silently be no family at all - surface it.
	if sheet.is_family and sheet.custom_class_name.strip_edges().is_empty():
		(result["warnings"] as Array).append("Sheet is marked as a Family but has no custom class name; a Family needs a type its instances share - give it a Custom Node class name. The @ace_family marker was skipped.")

	var source_map: Array = result["source_map"]
	if sheet.behavior_mode:
		var host_type: String = sheet.host_class if ClassDB.class_exists(sheet.host_class) else "Node"
		var behavior_label: String = sheet.custom_class_name.strip_edges()
		if behavior_label.is_empty():
			behavior_label = "This"
		lines.append("")
		lines.append("## The node this behavior acts on (its parent). Required host: %s." % host_type)
		lines.append("var host: %s = null" % host_type)
		lines.append("")
		lines.append("func _enter_tree() -> void:")
		lines.append("\thost = get_parent() as %s" % host_type)
		lines.append("\tif host == null:")
		lines.append("\t\tpush_warning(\"%s behavior requires a %s parent.\")" % [behavior_label, host_type])
		# Lane B.2: declared sibling dependencies surface as the editor's ⚠ badge.
		var required_behaviors: PackedStringArray = PackedStringArray()
		for required_entry: String in sheet.requires_behaviors:
			if EventSheetIdentifierRules.is_valid(required_entry.strip_edges()):
				required_behaviors.append("\"%s\"" % required_entry.strip_edges())
			elif not required_entry.strip_edges().is_empty():
				(result["warnings"] as Array).append("Requires entry \"%s\" isn't a valid class name - skipped." % required_entry.strip_edges())
		if not required_behaviors.is_empty():
			lines.append("")
			lines.append("## Declared sibling dependencies (attach these to the same parent).")
			lines.append("func _get_configuration_warnings() -> PackedStringArray:")
			lines.append("\tvar dependency_warnings: PackedStringArray = PackedStringArray()")
			lines.append("\tfor required_class: String in [%s]:" % ", ".join(required_behaviors))
			lines.append("\t\tvar dependency_found: bool = false")
			lines.append("\t\tfor sibling: Node in (get_parent().get_children() if get_parent() != null else []):")
			lines.append("\t\t\tif sibling.is_class(required_class) or (sibling.get_script() != null and str(sibling.get_script().get_global_name()) == required_class):")
			lines.append("\t\t\t\tdependency_found = true")
			lines.append("\t\t\t\tbreak")
			lines.append("\t\tif not dependency_found:")
			lines.append("\t\t\tdependency_warnings.append(\"Requires a %s sibling behavior.\" % required_class)")
			lines.append("\treturn dependency_warnings")
	# Enums emit FIRST so enum-typed variable declarations below can reference them.
	var enum_rows: Array = []
	_collect_enum_rows(all_events, enum_rows)
	if not enum_rows.is_empty():
		lines.append("")
		for enum_entry: Variant in enum_rows:
			var enum_lines: PackedStringArray = _emit_enum_lines(enum_entry as EnumRow)
			if enum_lines.is_empty():
				continue
			var enum_start: int = lines.size() + 1
			lines.append_array(enum_lines)
			source_map.append({"uid": str((enum_entry as EnumRow).get_instance_id()), "start": enum_start, "end": lines.size(), "kind": "enum"})
	var signal_rows: Array = []
	_collect_signal_rows(all_events, signal_rows)
	if not signal_rows.is_empty():
		lines.append("")
		for signal_entry: Variant in signal_rows:
			var signal_row: SignalRow = signal_entry as SignalRow
			var signal_line: String = _emit_signal_line(signal_row)
			if signal_line.is_empty():
				continue
			# Trigger signals carry a `## @ace_*` annotation block above the declaration; plain
			# signals emit none (byte-identical). The source-map span covers the whole block.
			var signal_start: int = lines.size() + 1
			for annotation_line: String in _emit_signal_annotations(signal_row):
				lines.append(annotation_line)
			lines.append(signal_line)
			source_map.append({"uid": str(signal_row.get_instance_id()), "start": signal_start, "end": lines.size(), "kind": "signal"})
	# A Test sheet's own start signal - the thing behind the On Test Start trigger. Declared HERE
	# rather than asked of the author, because a test sheet that cannot be started is not a test
	# sheet; a runner emits it with the test's name. Skipped when the sheet already declares one
	# itself, so a hand-written declaration is never duplicated into a parse error.
	if sheet.test_mode and not _declares_signal_named(signal_rows, "test_started"):
		lines.append("")
		lines.append("## Emitted by a test runner as this test begins - On Test Start events handle it.")
		lines.append("signal test_started(test_name: String)")
	# Custom Block API rows (preloads, region markers, registered pack kinds) emit before the
	# variables so a `const … := preload(…)` can be referenced by a variable default below.
	var custom_block_rows: Array = []
	_collect_custom_blocks(all_events, custom_block_rows)
	var pending_custom_sections: Array = []
	for block_entry: Variant in custom_block_rows:
		var custom_kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind((block_entry as CustomBlockRow).kind_id)
		if custom_kind == null:
			continue
		var custom_lines: PackedStringArray = custom_kind.emit(block_entry as CustomBlockRow)
		if not custom_lines.is_empty():
			pending_custom_sections.append({"row": block_entry, "lines": custom_lines})
	if not pending_custom_sections.is_empty():
		lines.append("")
		for custom_section: Variant in pending_custom_sections:
			var custom_start: int = lines.size() + 1
			for custom_line: String in (custom_section as Dictionary)["lines"]:
				lines.append(custom_line)
			source_map.append({"uid": str(((custom_section as Dictionary)["row"] as CustomBlockRow).get_instance_id()), "start": custom_start, "end": lines.size(), "kind": "custom_block"})
	var tree_variables: Array = []
	_collect_tree_variables(all_events, tree_variables)
	# Nudge (never an error): a deprecated ACE still compiles, but warn once per distinct one so the user
	# is steered to its replacement even without hovering the row.
	_collect_deprecated_aces(all_events, result["warnings"], {})
	var sheet_function_names: Dictionary = {}
	for known_function: Variant in all_functions:
		if known_function is EventFunction:
			sheet_function_names[(known_function as EventFunction).function_name] = true
	var variable_lines: PackedStringArray = _emit_variables(merged_variables, result["warnings"], sheet_function_names)
	if variable_lines.size() > 0:
		lines.append("")
		for line: String in variable_lines:
			lines.append(line)
	if not tree_variables.is_empty():
		if variable_lines.is_empty():
			lines.append("")
		for tree_entry: Variant in tree_variables:
			var declaration: String = _emit_tree_variable_line(tree_entry as LocalVariable)
			if declaration.is_empty():
				continue
			# Split multi-line declarations (a `## doc` comment above the `@export var`) so lines.size()
			# and every later row's map range count the true line total, not one element for two lines.
			var tree_var_start: int = lines.size() + 1
			for declaration_line: String in declaration.split("\n"):
				lines.append(declaration_line)
			source_map.append({"uid": str((tree_entry as LocalVariable).get_instance_id()), "start": tree_var_start, "end": lines.size(), "kind": "variable"})

	# Group-local variables: class members under a per-group header comment.
	var group_local_sets: Array = []
	_collect_group_locals(all_events, group_local_sets)
	for group_set: Dictionary in group_local_sets:
		lines.append("")
		lines.append("# %s — group locals" % str(group_set.get("group", "Group")))
		for local_entry: Variant in group_set.get("locals", []):
			var local_line: String = _emit_tree_variable_line(local_entry as LocalVariable)
			if not local_line.is_empty():
				var local_var_start: int = lines.size() + 1
				for local_declaration_line: String in local_line.split("\n"):
					lines.append(local_declaration_line)
				source_map.append({"uid": str((local_entry as LocalVariable).get_instance_id()), "start": local_var_start, "end": lines.size(), "kind": "variable"})

	# V4 Static locals: class members for the locals whose rows sit under an event. GDScript has no
	# function-scope `static`, so a local that must keep its value between runs of its event is
	# hoisted here (beside the group locals, which solve the same problem one scope wider) and the
	# event's uses are rewritten onto the member by _rewrite_static_local_uses.
	var static_locals: Array = _collect_sheet_static_locals(all_events, all_functions, result["warnings"])
	if not static_locals.is_empty():
		lines.append("")
		for static_entry: Variant in static_locals:
			var static_start: int = lines.size() + 1
			for static_line: String in _emit_tree_variable_line(static_entry as LocalVariable).split("\n"):
				lines.append(static_line)
			source_map.append({"uid": str((static_entry as LocalVariable).get_instance_id()), "start": static_start, "end": lines.size(), "kind": "variable"})

	# Runtime-toggleable group flags (Set Group Active targets these members). Collected
	# in a dedicated early pass - the flatten that ALSO maps guards runs later, in the
	# trigger-section phase, after this member block has already emitted.
	_collect_runtime_group_members(all_events)
	if not _runtime_group_members.is_empty():
		if variable_lines.is_empty() and tree_variables.is_empty():
			lines.append("")
		for group_member: Array in _runtime_group_members:
			lines.append("var %s: bool = %s" % [str(group_member[0]), "true" if bool(group_member[1]) else "false"])

	# Stateful-condition members (Every X Seconds…): one class member per applied instance.
	var stateful_members: Array = []
	_collect_stateful_members(all_events, stateful_members)
	for function_entry: Variant in all_functions:
		if function_entry is EventFunction:
			_collect_stateful_members(_function_body_rows(function_entry as EventFunction), stateful_members)
	if not stateful_members.is_empty():
		if variable_lines.is_empty() and tree_variables.is_empty():
			lines.append("")
		# A member may span SEVERAL lines (a condition can ship a helper beside its state var). Append ONE
		# ENTRY PER LINE - the source map indexes `lines` one line per entry, so a multi-line entry here would
		# mis-map every event row below it - with the plain one-liner vars first, so no `var` follows a `func`.
		for member_line: String in _order_stateful_members(stateful_members):
			lines.append(member_line)

	# Live values (debugging rung 2): a throttle timer member; the send block itself
	# lands inside _process below. Variables list is baked at compile time.
	_live_values_payload = ""
	_live_values_receiver_pending = false
	if sheet.emit_live_values:
		var live_keys: Array = merged_variables.keys()
		live_keys.sort()
		var payload_parts: PackedStringArray = PackedStringArray()
		for live_key: Variant in live_keys:
			payload_parts.append("\"%s\", %s" % [str(live_key), str(live_key)])
		if payload_parts.is_empty():
			(result["warnings"] as Array).append("Live values: this sheet has no variables to stream - add some or turn the toggle off.")
		else:
			_live_values_payload = ", ".join(payload_parts)
			_live_values_receiver_pending = true
	if sheet.emit_event_trace:
		_emit_event_trace_flag = true
	# Runtime errors (debugging rung 5): with ANY sheet-debug switch armed, the compiled script
	# carries a Logger that announces script errors to the editor (message, file, line) over the
	# sheet's channel. Announced, not captured: the engine's own error channel never reaches
	# editor debugger plugins, so the game says its own trouble - the paused-row pattern.
	_error_reporter_pending = _wants_error_reporter(sheet)
	# Live values and the event trace share one throttled _process, so they share the timer member;
	# the trace also needs its per-frame buffer. Declared whenever either is enabled - the trace can
	# run on its own (without live values), so this is no longer gated behind emit_live_values.
	if _live_values_receiver_pending or _emit_event_trace_flag:
		if variable_lines.is_empty() and tree_variables.is_empty():
			lines.append("")
		lines.append("var __live_values_timer: float = 0.0")
		if _emit_event_trace_flag:
			lines.append("var __eventsheets_fired: PackedStringArray = PackedStringArray()")
			# The trace's WHEN: one microsecond stamp beside every recorded fire, and the fire-count
			# at the top of each frame. The editor reads a fire's self time as the gap to the NEXT
			# fire in the SAME frame - which is why the frame ruler exists, and why the last fire of
			# a frame is left unmeasured rather than charged the frame's idle time.
			lines.append("var __eventsheets_timed: PackedInt64Array = PackedInt64Array()")
			lines.append("var __eventsheets_frames: PackedInt32Array = PackedInt32Array()")

	# Lane B composition (has-a): owned helper instances for the declared addon classes.
	if not sheet.uses_addons.is_empty():
		if variable_lines.is_empty() and tree_variables.is_empty():
			lines.append("")
		for uses_class: String in sheet.uses_addons:
			var trimmed_class: String = uses_class.strip_edges()
			if trimmed_class.is_empty():
				continue
			if not EventSheetIdentifierRules.is_valid(trimmed_class):
				(result["warnings"] as Array).append("Uses entry \"%s\" isn't a valid class name - skipped." % trimmed_class)
				continue
			lines.append("var __uses_%s := %s.new()" % [trimmed_class.to_snake_case(), trimmed_class])

	# Tool buttons (Inspector-attributes spec, Tier 2): one Callable export per labeled
	# sheet function. The Callable resolves at class scope, so emitting before the
	# function bodies is fine.
	var emitted_tool_button: bool = false
	for button_function: Variant in all_functions:
		if button_function is EventFunction and not (button_function as EventFunction).tool_button_label.strip_edges().is_empty():
			var button_label: String = (button_function as EventFunction).tool_button_label.strip_edges()
			var button_target: String = (button_function as EventFunction).function_name
			if not emitted_tool_button:
				lines.append("")
				emitted_tool_button = true
			lines.append("@export_tool_button(\"%s\") var _btn_%s: Callable = %s" % [button_label.c_escape(), button_target, button_target])
	if emitted_tool_button and not sheet.tool_mode:
		(result["warnings"] as Array).append("Tool buttons need a @tool sheet to run in the editor - enable Tool in the Sheet Type dialog.")

	# Tree-placed GDScript blocks (top level / inside groups) are emitted verbatim at class
	# level - helper functions, @onready vars, signal declarations, etc.
	var raw_blocks: Array = []
	_collect_class_level_raw_rows(all_events, raw_blocks)
	for raw_entry: Variant in raw_blocks:
		var raw_block: RawCodeRow = raw_entry as RawCodeRow
		if raw_block == null or not raw_block.enabled or raw_block.code.strip_edges().is_empty():
			continue
		lines.append("")
		var raw_start: int = lines.size() + 1
		for code_line: String in raw_block.code.split("\n"):
			lines.append(code_line)
		source_map.append({"uid": str(raw_block.get_instance_id()), "start": raw_start, "end": lines.size(), "kind": "raw"})

	for hook_name: String in ["_validate_property", "_get_configuration_warnings", "_process", "_ready", "_physics_process"]:
		var hook_generated: bool = false
		for emitted_line: String in lines:
			if emitted_line.begins_with("func %s(" % hook_name):
				hook_generated = true
				break
		if hook_generated:
			for raw_entry2: Variant in raw_blocks:
				if raw_entry2 is RawCodeRow and (raw_entry2 as RawCodeRow).code.contains("func %s(" % hook_name):
					(result["warnings"] as Array).append("A script block also defines %s() - remove it or clear the Inspector/Requires settings (duplicate functions don't compile)." % hook_name)

	var deferred_rows: PackedStringArray = PackedStringArray()
	var top_level_events: Array = []
	for row: Variant in all_events:
		if not (row is Resource):
			continue
		if row is LocalVariable:
			continue  # emitted above as a class-level variable
		if row is RawCodeRow:
			continue  # emitted above as a class-level GDScript block
		if row is CommentRow:
			# Top-level comments compile to real comment lines (emitted after the trigger
			# sections - position is approximate, content is preserved).
			if (row as CommentRow).enabled and not (row as CommentRow).text.strip_edges().is_empty():
				for comment_line: String in (row as CommentRow).text.split("\n"):
					deferred_rows.append("# %s" % comment_line)
			continue
		if row is EventGroup:
			# Groups are organizational: their events compile inline (the helper flattens,
			# honoring event-sheet semantics - a DISABLED group drops all of its children).
			top_level_events.append(row)
			continue
		if row is EnumRow or row is SignalRow:
			continue  # emitted above as class-level declarations
		if row.has_method("get_row_kind") and str(row.call("get_row_kind")) != "event":
			deferred_rows.append("# (unknown row type — preserved as a comment so nothing is silently dropped)")
			continue
		if not (row is EventRow):
			continue
		var event_row: EventRow = row
		if not event_row.enabled:
			continue
		# A BLANK top-level event - no trigger picked - runs every tick, which is what a blank event
		# means in an event sheet. It compiles exactly as an every-tick event would (the resolver
		# reads the blank id as the tick one), so its actions land in `_process(delta)` and its
		# conditions, if any, are checked there. Nothing is written onto the row: blank stays blank.
		top_level_events.append(event_row)
	var declared_signals: Array = _scan_declared_signals(raw_blocks)
	for signal_entry: Variant in signal_rows:
		if signal_entry is SignalRow and (signal_entry as SignalRow).enabled:
			declared_signals.append((signal_entry as SignalRow).signal_name)
	if sheet.test_mode:
		declared_signals.append("test_started")  # emitted above; On Test Start connects to it
	var connect_context: Dictionary = {
		"self_class": "Node" if sheet.behavior_mode else (sheet.host_class if ClassDB.class_exists(sheet.host_class) else "Node"),
		"declared_signals": declared_signals
	}
	var group_comment_lines: PackedStringArray = PackedStringArray()
	_emit_grouped_trigger_functions(top_level_events, lines, source_map, result, connect_context, group_comment_lines)
	for group_comment_line: String in group_comment_lines:
		deferred_rows.append("# %s" % group_comment_line)

	if not _throttle_process_emitted and (not _live_values_payload.is_empty() or _emit_event_trace_flag):
		lines.append("")
		lines.append("func _process(delta: float) -> void:")
		# The trace's frame ruler: how many fires had happened by the top of THIS frame.
		# Unthrottled on purpose - it marks every frame, not every streamed window, and
		# without it a gap between two frames is indistinguishable from a slow event.
		if _emit_event_trace_flag:
			lines.append("\tif EngineDebugger.is_active():")
			lines.append("\t\t__eventsheets_frames.append(__eventsheets_fired.size())")
		lines.append("\t__live_values_timer += delta")
		lines.append("\tif __live_values_timer >= 0.25 and EngineDebugger.is_active():")
		lines.append("\t\t__live_values_timer = 0.0")
		if not _live_values_payload.is_empty():
			_emit_live_values_send(lines)
		if _emit_event_trace_flag:
			lines.append("\t\tEngineDebugger.send_message(\"eventsheets:fired_events\", __eventsheets_fired)")
			lines.append("\t\t__eventsheets_fired.clear()")
			lines.append("\t\tEngineDebugger.send_message(\"eventsheets:event_times\", [__eventsheets_timed, __eventsheets_frames, Time.get_ticks_usec()])")
			lines.append("\t\t__eventsheets_timed.clear()")
			lines.append("\t\t__eventsheets_frames.clear()")
		_throttle_process_emitted = true
		_live_values_payload = ""

	if sheet.emit_live_values and not sheet.variables.is_empty():
		lines.append("")
		lines.append("## Live Values edit-back receiver (debug sessions only).")
		lines.append("func _eventsheets_debug_set(message: String, data: Array) -> bool:")
		lines.append("\tif message == \"query_children\" and data.size() >= 1:")
		lines.append("\t\t__eventsheets_report_children(str(data[0]))")
		lines.append("\t\treturn true")
		lines.append("\tif message != \"set_value\" or data.size() < 2:")
		lines.append("\t\treturn false")
		lines.append("\tset(str(data[0]), data[1])")
		lines.append("\treturn true")
		lines.append("")
		lines.append("## Live grounding (debug sessions only): reports the behaviour children of the first node")
		lines.append("## running the asked-for script, so the editor reads real runtime names - including")
		lines.append("## behaviours attached at runtime. One receiver answers for every sheet in the game.")
		lines.append("func __eventsheets_report_children(script_path: String) -> void:")
		lines.append("\tvar __matches: Array = []")
		lines.append("\t__eventsheets_collect_running(get_tree().root, script_path, __matches)")
		lines.append("\tvar __reply: Array = [script_path, __matches.size()]")
		lines.append("\tif not __matches.is_empty():")
		lines.append("\t\tvar __owner: Node = __matches[0]")
		lines.append("\t\t__reply.append(str(__owner.name))")
		lines.append("\t\tfor __child in __owner.get_children():")
		lines.append("\t\t\tvar __child_script: Script = __child.get_script() as Script")
		lines.append("\t\t\tif __child_script != null and not str(__child_script.get_global_name()).is_empty():")
		lines.append("\t\t\t\t__reply.append_array([str(__child.name), str(__child_script.get_global_name()), str(__child_script.resource_path)])")
		lines.append("\tEngineDebugger.send_message(\"eventsheets:children_report\", __reply)")
		lines.append("")
		lines.append("func __eventsheets_collect_running(node: Node, script_path: String, matches: Array) -> void:")
		lines.append("\tvar __node_script: Script = node.get_script() as Script")
		lines.append("\tif __node_script != null and __node_script.resource_path == script_path:")
		lines.append("\t\tmatches.append(node)")
		lines.append("\tfor __child in node.get_children():")
		lines.append("\t\t__eventsheets_collect_running(__child, script_path, matches)")

	# Replay recording (debug compiles only): report every CONTROL the player presses or releases,
	# with the frame it happened on, so the editor's replay recorder can write the play back as a
	# Test sheet. Controls, never raw device events - a mouse jiggle cannot be replayed and "jump
	# pressed on frame 12" can. Skipped without a word of complaint when the sheet already handles
	# unhandled input itself: a second _unhandled_input would be a parse error, and a recording is
	# never worth breaking someone's script for.
	if sheet.emit_input_recording and not _handles_unhandled_input(lines):
		lines.append("")
		lines.append("## Replay recording receiver (debug sessions only).")
		lines.append("func _unhandled_input(event: InputEvent) -> void:")
		lines.append("\tif not EngineDebugger.is_active():")
		lines.append("\t\treturn")
		lines.append("\tfor __recorded_action: StringName in InputMap.get_actions():")
		lines.append("\t\tif not event.is_action(__recorded_action):")
		lines.append("\t\t\tcontinue")
		lines.append("\t\tEngineDebugger.send_message(\"eventsheets:input\", [str(__recorded_action), event.is_action_pressed(__recorded_action), Engine.get_frames_drawn()])")

	# Runtime-error reporter (debugging rung 5, debug compiles only): a Logger subclass the game
	# registers in _ready, announcing each script error's message, file and line to the editor over
	# the sheet's channel, so the dock can re-say the failure as the row said it. Each failing line
	# is announced once per run - the strip says a failure the FIRST time it happens, and a row that
	# fails every tick must not flood the debugger wire on its way there. The engine hands the
	# message in `rationale` for asserts and in `code` for plain script errors, so whichever is
	# non-empty wins.
	if _wants_error_reporter(sheet):
		lines.append("")
		lines.append("## Runtime-error reporter (debug sessions only): announces each script error's message,")
		lines.append("## file and line to the editor, once per failing line per run.")
		lines.append("class __EventSheetsErrorReporter extends Logger:")
		lines.append("\tstatic var armed: bool = false")
		lines.append("\tvar _said: Dictionary = {}")
		lines.append("")
		lines.append("\tfunc _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:")
		lines.append("\t\tif error_type != ERROR_TYPE_SCRIPT or not EngineDebugger.is_active():")
		lines.append("\t\t\treturn")
		lines.append("\t\tvar location: String = \"%s:%d\" % [file, line]")
		lines.append("\t\tif _said.has(location):")
		lines.append("\t\t\treturn")
		lines.append("\t\t_said[location] = true")
		lines.append("\t\tvar message: String = rationale if not rationale.is_empty() else code")
		lines.append("\t\tEngineDebugger.send_message.call_deferred(\"eventsheets:runtime_error\", [message, file, line])")

	# Emit sheet functions as callable GDScript methods (after the trigger handlers).
	for function_resource: Variant in all_functions:
		if not (function_resource is EventFunction):
			continue
		var event_function: EventFunction = function_resource as EventFunction
		if not event_function.enabled or event_function.function_name.strip_edges().is_empty():
			continue
		lines.append("")
		var function_start: int = lines.size() + 1
		_emit_function_doc_comment(event_function, lines)
		_emit_expose_annotations(event_function, sheet, lines)
		_emit_function_annotation_prefix(event_function, lines)
		lines.append("%sfunc %s(%s) -> %s:" % ["static " if event_function.is_static else "", event_function.function_name, _emit_function_params(event_function), _function_return_type_name(event_function)])
		var function_events: Array = _function_body_rows(event_function)
		var function_body_start: int = lines.size()
		_emit_event_body(function_events, lines, source_map, 1, result["warnings"])
		if not _has_statement(lines, function_body_start):
			lines.append(_empty_function_stub(event_function))
		source_map.append({"uid": str(event_function.get_instance_id()), "start": function_start, "end": lines.size(), "kind": "function"})

	for deferred: String in deferred_rows:
		lines.append("")
		lines.append(deferred)

	_insert_missing_member_declarations(lines, sheet, result.get("source_map", []))
	_insert_provider_member_declarations(lines, result)
	_append_aimed_cursor_helper(lines)
	_append_remembered_persistence(lines, sheet, result)
	var output: String = "\n".join(lines) + "\n"
	result["output"] = output

	var final_output_path: String = _resolve_output_path(sheet, output_path)
	if not _write_output_if_changed(final_output_path, output):
		result["success"] = false
		(result["errors"] as Array[String]).append("Failed to open output path: %s" % final_output_path)
		return result
	return result


## True when the file at `path` already holds exactly `output` - used to skip no-op rewrites.
## Rewriting a byte-identical file bumps its mtime, which makes the Godot editor prompt
## "Files have been modified outside Godot" on the next scene open/close - even though the
## generated code is byte-stable (the drift audit proves it) and nothing actually changed.
static func _output_is_current(path: String, output: String) -> bool:
	return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == output


## Writes `output` to `path` only when it differs from what is already on disk, so an unchanged
## recompile (sheet save, Attach to Node, Test Bench, export - all funnel through compile()) never
## touches the file and never trips Godot's external-change watcher. Returns true on success,
## including the "already up to date" no-op; false only if a genuinely-needed write failed.
## The write is ATOMIC (temp file + rename): opening the target with FileAccess.WRITE truncates
## it FIRST, so a crash / disk-full / OneDrive lock mid-write used to leave the user's sheet as a
## zero-byte or half-written .gd with no way back. The rename either fully lands or leaves the
## original untouched.
static func _write_output_if_changed(path: String, output: String) -> bool:
	if _output_is_current(path, output):
		return true
	var temp_path: String = path + ".efwrite.tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(output)
	file.flush()
	file.close()
	# Verify the temp landed whole before it replaces the real file (catches silent disk-full).
	if FileAccess.get_file_as_string(temp_path) != output:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	var absolute_temp: String = ProjectSettings.globalize_path(temp_path)
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(absolute_temp, absolute_path) != OK:
		DirAccess.remove_absolute(absolute_temp)
		return false
	return true


## Order-preserving emission for GDScript-backed sheets: rows reproduce the original file
## (verbatim blocks + verify-lifted variables) in sheet order; events/groups the user adds
## afterwards append as standard trigger functions at the end. Disabled blocks still emit -
## external mode is lossless, never a filter.
static func _compile_external(sheet: EventSheetResource, result: Dictionary, output_path: String) -> Dictionary:
	_live_values_receiver_pending = false
	_emit_breakpoints_flag = sheet.emit_breakpoints
	_emit_event_trace_flag = false
	_live_values_payload = ""
	_throttle_process_emitted = false
	# External mode is lossless, so it carries no synthesized debug members - the runtime-error
	# reporter (like live values) rides sheet-native compiles only.
	_error_reporter_pending = false
	# Event groups dissolve into the trigger sections on this path too, so refill the per-compile slug
	# map for THIS sheet (compile() returns into _compile_external before the main path's reset/collect
	# runs). The `## @ace_group` declarations ride along verbatim in the preserved prelude rows - we only
	# need _group_slugs populated so _emit_event_body re-emits the `# @group:` markers (else an imported
	# grouped sheet would lose them on the next save).
	_group_slugs = {}
	_row_group_path = {}
	_collect_groups(sheet.events, [], {}, _group_slugs)
	if not sheet.includes.is_empty() or not sheet.uses_addons.is_empty() or not sheet.requires_behaviors.is_empty():
		(result["warnings"] as Array).append("GDScript-backed sheets ignore Includes/Uses/Requires - the .gd file is the source of truth (write the equivalent code directly).")
	var lines: PackedStringArray = PackedStringArray()
	var source_map: Array = result["source_map"]
	var added_event_rows: Array = []
	var deferred_comment_lines_external: PackedStringArray = PackedStringArray()
	# Lifted MID-FILE lifecycle handlers (EventAnchorRow): the events they own emit as one function
	# at the anchor's slot below, so the trailing grouped section must not claim them a second time.
	var anchored_event_uids: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is EventAnchorRow:
			for anchored_uid: String in (entry as EventAnchorRow).event_uids:
				anchored_event_uids[anchored_uid] = true
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			# The declaration can be MULTI-LINE (a `## doc` comment above the `@export var` line).
			# Append each output line separately so lines.size() - and every row's map range after
			# this one - counts the true line total; appending the whole string as one element would
			# undercount and drift the source map for the rest of the file.
			var variable_start: int = lines.size() + 1
			for declaration_line: String in _emit_tree_variable_line(entry as LocalVariable).split("\n"):
				lines.append(declaration_line)
			source_map.append({"uid": str((entry as LocalVariable).get_instance_id()), "start": variable_start, "end": lines.size(), "kind": "variable"})
		elif entry is CollectionDeclRow:
			# A top-level structured collection declaration (a const table, a var default set): the
			# brackets exist only in this emission, which parse() byte-gates against.
			var decl_top: CollectionDeclRow = entry as CollectionDeclRow
			var decl_top_start: int = lines.size() + 1
			for decl_top_line: String in decl_top.emit_lines():
				lines.append(decl_top_line)
			source_map.append({"uid": str(decl_top.get_instance_id()), "start": decl_top_start, "end": lines.size(), "kind": "collection_decl"})
		elif entry is RawCodeRow:
			var block_start: int = lines.size() + 1
			for code_line: String in (entry as RawCodeRow).code.split("\n"):
				lines.append(code_line)
			source_map.append({"uid": str((entry as RawCodeRow).get_instance_id()), "start": block_start, "end": lines.size(), "kind": "raw"})
		elif entry is EventRow and anchored_event_uids.has((entry as EventRow).event_uid):
			pass  # emitted in place by its EventAnchorRow, just above it in this array
		elif entry is EventRow or entry is EventGroup:
			added_event_rows.append(entry)
		elif entry is CommentRow and (entry as CommentRow).enabled and not (entry as CommentRow).text.strip_edges().is_empty():
			deferred_comment_lines_external.append_array((entry as CommentRow).text.split("\n"))
		elif entry is EnumRow:
			var external_enum_lines: PackedStringArray = _emit_enum_lines(entry as EnumRow)
			if not external_enum_lines.is_empty():
				var external_enum_start: int = lines.size() + 1
				lines.append_array(external_enum_lines)
				source_map.append({"uid": str((entry as EnumRow).get_instance_id()), "start": external_enum_start, "end": lines.size(), "kind": "enum"})
		elif entry is SignalRow:
			var external_signal_line: String = _emit_signal_line(entry as SignalRow)
			if not external_signal_line.is_empty():
				# A trigger signal carries its `## @ace_trigger` (+ @ace_name / @ace_category) block ABOVE
				# the declaration, exactly like the main path (:216-222) - so a behaviour's exposed trigger
				# signal round-trips as a first-class row instead of stranding those annotations in a separate
				# GDScript block. Plain signals emit none (byte-identical → existing .gd sheets never change).
				var external_signal_start: int = lines.size() + 1
				for external_annotation_line: String in _emit_signal_annotations(entry as SignalRow):
					lines.append(external_annotation_line)
				lines.append(external_signal_line)
				source_map.append({"uid": str((entry as SignalRow).get_instance_id()), "start": external_signal_start, "end": lines.size(), "kind": "signal"})
		elif entry is CustomBlockRow:
			# Custom Block API: the registered kind owns the GDScript. Emission is in array
			# position (the same ordering contract enums/signals follow), so a lifted block
			# re-emits exactly where it came from and the whole-file byte-verify holds.
			var block_kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind((entry as CustomBlockRow).kind_id)
			if block_kind != null:
				var block_lines: PackedStringArray = block_kind.emit(entry as CustomBlockRow)
				if not block_lines.is_empty():
					var custom_block_start: int = lines.size() + 1
					for block_line: String in block_lines:
						lines.append(block_line)
					source_map.append({"uid": str((entry as CustomBlockRow).get_instance_id()), "start": custom_block_start, "end": lines.size(), "kind": "custom_block"})
		elif entry is FunctionAnchorRow:
			# A lifted MID-FILE function emits at its original slot (no added blank - the
			# separator blank lives verbatim in the raw block above). The trailing functions
			# section skips anchored names, so the function emits exactly once.
			var anchored_function: EventFunction = _find_function_by_name(sheet, (entry as FunctionAnchorRow).function_name)
			if anchored_function != null and anchored_function.enabled:
				_emit_function_block(anchored_function, sheet, lines, source_map, result)
		elif entry is EventAnchorRow:
			# A lifted MID-FILE lifecycle handler emits its ONE function at the original slot (no
			# added blank - the separator lives verbatim in the raw block above), so a
			# `_unhandled_input` written below a pack's verbs keeps its place in the file.
			_emit_anchored_trigger_function(_collect_anchored_events(sheet, entry as EventAnchorRow), lines, source_map, result)
	# External sheets: raw rows include the original file's verbatim segments, so signals
	# declared anywhere in the source validate self-connections.
	var external_raw_rows: Array = []
	for entry: Variant in sheet.events:
		if entry is RawCodeRow:
			external_raw_rows.append(entry)
	var external_connect_context: Dictionary = {
		"self_class": sheet.host_class if ClassDB.class_exists(sheet.host_class) else "Node",
		"declared_signals": _scan_declared_signals(external_raw_rows),
		# Opened-file path: honor each lifted function's source blank-line spacing (the main/generated path
		# omits this flag, so packs keep the fixed single blank and stay byte-identical).
		"external": true,
	}
	_emit_grouped_trigger_functions(added_event_rows, lines, source_map, result, external_connect_context, deferred_comment_lines_external)
	# Anchored functions (FunctionAnchorRow) already emitted at their in-file slot above - the
	# trailing section emits only the rest, so a mid-file lifted helper never re-emits at the end.
	var anchored_names: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is FunctionAnchorRow:
			anchored_names[(entry as FunctionAnchorRow).function_name] = true
	for function_resource: Variant in sheet.functions:
		if not (function_resource is EventFunction):
			continue
		var event_function: EventFunction = function_resource as EventFunction
		if not event_function.enabled or event_function.function_name.strip_edges().is_empty():
			continue
		if anchored_names.has(event_function.function_name):
			continue
		# One blank before each trailing function. This loop is the EXTERNAL (opened-file) path only, so it
		# honors the function's captured source blank spacing (__source_leading_blanks) - a hand-written
		# two-blank gap before a helper round-trips instead of reverting. Default 1 (a lifted function with
		# no captured multi-blank gap, and every generated pack, which emits via the main path) is unchanged.
		# Floor 0, not 1: a lift can legitimately record that the source had NO blank here (a `#`
		# note written directly above the function). Absent meta still defaults to a single blank,
		# so every generated file and every pack is unchanged.
		var function_blanks: int = maxi(int(event_function.get_meta("__source_leading_blanks", 1)), 0)
		for _blank_index: int in range(function_blanks):
			lines.append("")
		_emit_function_block(event_function, sheet, lines, source_map, result)

	# Top-level comments emit last, one blank before each line (main path's deferred format).
	for comment_line: String in deferred_comment_lines_external:
		lines.append("")
		lines.append("# %s" % comment_line)
	_insert_missing_member_declarations(lines, sheet, result.get("source_map", []))
	_insert_provider_member_declarations(lines, result)
	_append_aimed_cursor_helper(lines)
	_append_remembered_persistence(lines, sheet, result)
	var output: String = "\n".join(lines) + "\n"
	result["output"] = output
	var final_output_path: String = output_path if not output_path.is_empty() else sheet.external_source_path
	if not _write_output_if_changed(final_output_path, output):
		result["success"] = false
		(result["errors"] as Array[String]).append("Failed to open output path: %s" % final_output_path)
		return result
	return result


## Remember Between Runs (variable attribute `remember: true`): appends the persistence trio at
## the very end of the file - an @onready boot member that recalls saved values at ready time and
## arms save-on-exit, plus the recall/store pair iterating every remembered variable. Appending at
## the tail keeps the source map untouched. Name-addressed: a sheet that already carries a
## `_ef_recall_remembered` function (a reopened generated file, where the trio lifted as ordinary
## rows) gets NO second copy, so the reopen -> resave cycle stays byte-identical.
static func _append_remembered_persistence(lines: PackedStringArray, sheet: EventSheetResource, result: Dictionary) -> void:
	var remembered: PackedStringArray = PackedStringArray()
	for var_key: Variant in sheet.variables.keys():
		var descriptor: Variant = sheet.variables.get(var_key)
		if not descriptor is Dictionary:
			continue
		if bool((descriptor as Dictionary).get("const", false)):
			continue
		var attributes: Variant = (descriptor as Dictionary).get("attributes")
		if attributes is Dictionary and bool((attributes as Dictionary).get("remember", false)):
			remembered.append(str(var_key))
	if remembered.is_empty():
		return
	if _find_function_by_name(sheet, "_ef_recall_remembered") != null:
		return
	var host: String = str(sheet.host_class).strip_edges()
	if not host.is_empty() and ClassDB.class_exists(host) and host != "Node" and not ClassDB.is_parent_class(host, "Node"):
		(result["warnings"] as Array).append("Remember Between Runs needs a Node host (recall runs at ready, save on exit) - remembered variables were not persisted on host %s." % host)
		return
	var section: String = str(sheet.custom_class_name).strip_edges()
	if section.is_empty():
		section = "vars"
	lines.append("")
	lines.append("@onready var __ef_remember_boot: bool = _ef_recall_remembered()")
	lines.append("")
	lines.append("## Generated by Remember Between Runs: loads every remembered variable, then saves them back when this node leaves the tree (scene change or quit).")
	lines.append("func _ef_recall_remembered() -> bool:")
	lines.append("\tvar __remember_cfg: ConfigFile = ConfigFile.new()")
	lines.append("\tif __remember_cfg.load(\"user://remembered.cfg\") == OK:")
	for remembered_name: String in remembered:
		lines.append("\t\t%s = __remember_cfg.get_value(\"%s\", \"%s\", %s)" % [remembered_name, section, remembered_name, remembered_name])
	lines.append("\ttree_exiting.connect(_ef_store_remembered)")
	lines.append("\treturn true")
	lines.append("")
	lines.append("func _ef_store_remembered() -> void:")
	lines.append("\tvar __remember_cfg: ConfigFile = ConfigFile.new()")
	lines.append("\t__remember_cfg.load(\"user://remembered.cfg\")")
	for remembered_name: String in remembered:
		lines.append("\t__remember_cfg.set_value(\"%s\", \"%s\", %s)" % [section, remembered_name, remembered_name])
	lines.append("\t__remember_cfg.save(\"user://remembered.cfg\")")


static func _find_function_by_name(sheet: EventSheetResource, function_name: String) -> EventFunction:
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == function_name:
			return function_entry
	return null


## One function block (annotations + typed header + body/stub + its source-map range), shared by
## the trailing functions section, the in-place FunctionAnchorRow slots, and the lifter's
## per-anchor byte-gate. Deliberately does NOT emit the separating blank line - each call site
## owns that decision (an anchored mid-file function's preceding blank already lives verbatim in
## the raw block above it).
static func _emit_function_block(event_function: EventFunction, sheet: EventSheetResource, lines: PackedStringArray, source_map: Array, result: Dictionary) -> void:
	var function_start: int = lines.size() + 1
	_emit_function_doc_comment(event_function, lines)
	_emit_expose_annotations(event_function, sheet, lines)
	_emit_function_annotation_prefix(event_function, lines)
	lines.append("%sfunc %s(%s) -> %s:" % ["static " if event_function.is_static else "", event_function.function_name, _emit_function_params(event_function), _function_return_type_name(event_function)])
	var function_events: Array = _function_body_rows(event_function)
	var function_body_start: int = lines.size()
	_emit_event_body(function_events, lines, source_map, 1, result["warnings"])
	if not _has_statement(lines, function_body_start):
		lines.append(_empty_function_stub(event_function))
	source_map.append({"uid": str(event_function.get_instance_id()), "start": function_start, "end": lines.size(), "kind": "function"})


## The lifter's per-anchor gate: exactly what _emit_function_block would produce for this
## function, as text, with no side effects. A mid-file helper lifts only when this equals the
## original source lines byte-for-byte, so anchoring can never change a file.
## Takes the same compile lock as compile(): the lifter calls this per candidate function from the
## async-open worker thread, and _emit_function_block reads the same per-compile scratch statics.
## The EventRows an anchor owns, in sheet order - they follow the anchor in sheet.events and are
## addressed by event_uid, so an edit that reorders or removes one simply narrows the handler
## rather than emitting a stale copy.
static func _collect_anchored_events(sheet: EventSheetResource, anchor: EventAnchorRow) -> Array:
	var wanted: Dictionary = {}
	for anchored_uid: String in anchor.event_uids:
		wanted[anchored_uid] = true
	var events: Array = []
	for entry: Variant in sheet.events:
		if entry is EventRow and wanted.has((entry as EventRow).event_uid):
			events.append(entry)
	return events


## One trigger handler emitted at an EventAnchorRow's slot: the header (the source's own spelling
## when the lift captured one) plus the events' body, and nothing else. Deliberately narrower than
## _emit_grouped_trigger_functions - no leading blank (the raw block above owns the separator), no
## regenerated `_ready` connections (a handler whose connects live in a raw block must keep them
## there), no live-values plumbing (an opened hand-written file is not a streaming sheet). Anything
## outside that narrow shape simply fails the lifter's byte gate and stays a raw block.
static func _emit_anchored_trigger_function(events: Array, lines: PackedStringArray, source_map: Array, result: Dictionary) -> void:
	if events.is_empty() or not (events[0] is EventRow):
		return
	var signature: Dictionary = TriggerResolver.resolve_trigger(events[0] as EventRow)
	var function_name: String = str(signature.get("function_name", ""))
	if function_name.is_empty():
		(result["warnings"] as Array[String]).append("Unsupported anchored trigger %s" % (events[0] as EventRow).trigger_id)
		return
	var source_header: String = str((events[0] as EventRow).get_meta("__source_trigger_header", ""))
	var args: String = str(signature.get("args", ""))
	var returns: String = str(signature.get("return_type", "void"))
	if not source_header.is_empty():
		lines.append(source_header)
	elif args.is_empty():
		lines.append("func %s() -> %s:" % [function_name, returns])
	else:
		lines.append("func %s(%s) -> %s:" % [function_name, args, returns])
	if _emit_notification_match(events, lines, source_map, result["warnings"]):
		return
	if _emit_menu_match(events, lines, source_map, result["warnings"]):
		return
	var handler_body_start: int = lines.size()
	_emit_event_body(events, lines, source_map, 1, result["warnings"])
	if not _has_statement(lines, handler_body_start):
		lines.append("\tpass")


## W6. A menu handler's body: `match id:` with one case per item of that menu, in sheet order - the
## shape every menu in Godot is already written in, and the shape the reading reads back as one
## trigger per item. Returns false (emitting nothing) unless EVERY event in the group is a menu item,
## which keeps every other trigger on the ordinary body path.
static func _emit_menu_match(events: Array, lines: PackedStringArray, source_map: Array, warnings: Array) -> bool:
	var ids: PackedStringArray = PackedStringArray()
	for event_entry: Variant in events:
		if not (event_entry is EventRow):
			return false
		var item_id: String = TriggerResolver.menu_item_id_of(event_entry as EventRow)
		if item_id.is_empty():
			return false
		ids.append(item_id)
	if ids.is_empty():
		return false
	lines.append("\tmatch id:")
	for case_index: int in range(events.size()):
		lines.append("\t\t%s:" % ids[case_index])
		var case_body_start: int = lines.size()
		_emit_event_body([events[case_index]], lines, source_map, 3, warnings)
		if not _has_statement(lines, case_body_start):
			lines.append("\t\t\tpass")
	return true


## The `_notification` handler's body: `match what:` with one case per notification the sheet reacts
## to, in sheet order. Returns false (emitting nothing) unless EVERY event in the group names a
## notification, which is what keeps every other trigger on the ordinary body path. The engine calls
## `_notification` once for every notification, so the match - not one function each - is the shape.
static func _emit_notification_match(events: Array, lines: PackedStringArray, source_map: Array, warnings: Array) -> bool:
	var constants: PackedStringArray = PackedStringArray()
	for event_entry: Variant in events:
		if not (event_entry is EventRow):
			return false
		var constant: String = TriggerResolver.notification_constant_for((event_entry as EventRow).trigger_id)
		if constant.is_empty():
			return false
		constants.append(constant)
	if constants.is_empty():
		return false
	lines.append("\tmatch what:")
	for case_index: int in range(events.size()):
		lines.append("\t\t%s:" % constants[case_index])
		var case_body_start: int = lines.size()
		_emit_event_body([events[case_index]], lines, source_map, 3, warnings)
		if not _has_statement(lines, case_body_start):
			lines.append("\t\t\tpass")
	return true


## The lifter's per-anchor gate for a lifecycle handler: exactly what the slot above would emit for
## these events, as text, with no side effects. The handler anchors only when this equals the
## original source lines byte-for-byte, so anchoring can never change a file.
## Both text emitters below clear _behavior_host_default first, exactly as compile() does. Their two
## helpers are reached from _compile_external ONLY, where that default is always "" - so leaving a
## previous BEHAVIOR compile's "host" standing would emit `host.velocity.y += …` for a line the file
## spells `velocity.y += …`, the byte gate would refuse it, and every function in the opened file
## would fall back to a verbatim block. The gate has to emit what the compile of this sheet emits.
## `group_guards` is {EventRow: guard expression} - what a full compile fills from the group tree
## while flattening it. The anchored probe re-emits ONE handler with no groups around it, so a caller
## that took a group's guard off a row hands it back here; every other caller passes nothing and the
## emission is exactly what it always was.
static func emit_anchored_trigger_text(events: Array, group_guards: Dictionary = {}) -> String:
	_compile_mutex.lock()
	_behavior_host_default = ""
	_runtime_group_guards = group_guards
	var lines: PackedStringArray = PackedStringArray()
	var scratch: Dictionary = {"warnings": [], "errors": []}
	_emit_anchored_trigger_function(events, lines, [], scratch)
	_runtime_group_guards = {}
	_compile_mutex.unlock()
	return "\n".join(lines)


static func emit_function_block_text(event_function: EventFunction, sheet: EventSheetResource) -> String:
	_compile_mutex.lock()
	_behavior_host_default = ""
	var lines: PackedStringArray = PackedStringArray()
	var scratch: Dictionary = {"warnings": [], "errors": []}
	_emit_function_block(event_function, sheet, lines, [], scratch)
	_compile_mutex.unlock()
	return "\n".join(lines)


## Instance-backed addon ACEs: baked templates may call through a per-provider member
## (`__eventsheet_provider_<Class>.method(...)`). This pass scans the emitted lines for
## those members and declares each one ONCE as a plain owned instance of the addon class -
## a direct, typed call path with zero EventForge dependency in the output (the addon
## script ships with the game like any other class). Providers extending Node should
## prefer behaviors/autoloads; RefCounted providers are the intended shape.
## External-path counterpart of the main path's stateful-member emission: declares the
## members baked onto stateful conditions (Every X Seconds…) before the first function,
## skipping any already present verbatim (untouched files stay byte-identical).
## Insertions happen AFTER the source map was built, so every mapped range at or past the insertion
## point must shift down with the text or line→row lookups (the GDScript panel's click-to-select,
## error deep-links) land a few rows off - exactly the bug this fixes. A range that STRADDLES the
## insertion grows (its end shifts, its start doesn't).
static func _shift_source_map(source_map: Array, first_inserted_line: int, count: int) -> void:
	if count <= 0:
		return
	for entry: Variant in source_map:
		if not (entry is Dictionary):
			continue
		if int((entry as Dictionary).get("start", 0)) >= first_inserted_line:
			(entry as Dictionary)["start"] = int((entry as Dictionary)["start"]) + count
		if int((entry as Dictionary).get("end", 0)) >= first_inserted_line:
			(entry as Dictionary)["end"] = int((entry as Dictionary)["end"]) + count


## The class members a path did not write itself: the stateful-condition declarations (Every X
## Seconds and friends), and the hoisted member of any Static local whose row is under an event on a
## path that emits rows in file order. Each is inserted before the first function, and only when the
## file does not already carry it - so an opened .gd, whose member lines are rows of their own,
## comes back untouched.
static func _insert_missing_member_declarations(lines: PackedStringArray, sheet: EventSheetResource, source_map: Array = []) -> void:
	var members: Array = []
	_collect_stateful_members(sheet.events, members)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_stateful_members(_function_body_rows(function_entry as EventFunction), members)
	for static_local: Variant in _collect_sheet_static_locals(sheet.events, sheet.functions):
		members.append(_emit_tree_variable_line(static_local as LocalVariable))
	# A member may span several lines, so its identity is its FIRST line (the state var) - a plain
	# `lines.has()` of the whole multi-line string never matches once it has been emitted one line per entry.
	var missing: Array = []
	for member_line: Variant in members:
		if not lines.has(str(member_line).split("\n")[0]):
			missing.append(str(member_line))
	if missing.is_empty():
		return
	var insert_index: int = -1
	for index in range(lines.size()):
		if lines[index].begins_with("func ") or lines[index].begins_with("## @ace"):
			insert_index = index
			break
	if insert_index < 0:
		insert_index = lines.size()
	# Flatten to ONE ENTRY PER LINE (see _order_stateful_members) and shift the source map by the REAL
	# emitted line count, not the number of member entries.
	var ordered: PackedStringArray = _order_stateful_members(missing)
	for offset in range(ordered.size()):
		lines.insert(insert_index + offset, ordered[offset])
	lines.insert(insert_index + ordered.size(), "")
	_shift_source_map(source_map, insert_index + 1, ordered.size() + 1)


## True for an edge-gate condition the compiler must evaluate LAST in the chain (Trigger Once style,
## descriptor `.evaluated_last()`): the flag baked at apply time wins; the registry lookup covers
## conditions the importer rebuilt from source, where apply-time baking never ran.
static func _condition_evaluates_last(condition: ACECondition) -> bool:
	if condition.evaluate_last:
		return true
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	return descriptor != null and descriptor.evaluate_last


## Flattens stateful members to one line per entry (a member may carry a helper function beside its state
## var), the plain one-liner declarations first so no `var` ever trails a `func`.
static func _order_stateful_members(members: Array) -> PackedStringArray:
	var ordered: PackedStringArray = PackedStringArray()
	for member_text: Variant in members:
		if not str(member_text).contains("\n"):
			ordered.append(str(member_text))
	for member_text: Variant in members:
		if str(member_text).contains("\n"):
			for member_line: String in str(member_text).split("\n"):
				ordered.append(member_line)
	return ordered


static func _insert_provider_member_declarations(lines: PackedStringArray, result: Dictionary) -> void:
	# A real use-site is always a MEMBER ACCESS - every emitter of this convention writes
	# `__eventsheet_provider_<Class>.<member>` (the Project Doctor's matching check already
	# requires the dot). Requiring it here too stops prose from being read as code: an opened
	# .gd whose COMMENTS merely discuss the convention was having provider declarations
	# injected into it on save, which silently rewrote a hand-written file - the one thing the
	# lossless rule forbids. Comment lines are skipped for the same reason.
	var member_regex: RegEx = RegEx.new()
	if member_regex.compile("__eventsheet_provider_([A-Za-z_][A-Za-z0-9_]*)(?=\\.)") != OK:
		return
	# A member the file already declares needs no injection. On the external (opened-file) path the
	# declaration rides verbatim in the source's own rows, so injecting it again would duplicate the
	# line and rewrite a hand-written file on save - an untouched round-trip must never change a byte.
	var declaration_regex: RegEx = RegEx.new()
	if declaration_regex.compile("^\\s*var\\s+(__eventsheet_provider_[A-Za-z_][A-Za-z0-9_]*)\\b") != OK:
		return
	var providers: Dictionary = {}  # member name -> class name, deduped
	var declared: Dictionary = {}  # member name -> true, already present in the emitted lines
	for line: String in lines:
		if line.strip_edges().begins_with("#"):
			continue
		var declaration_match: RegExMatch = declaration_regex.search(line)
		if declaration_match != null:
			declared[declaration_match.get_string(1)] = true
		# String literals are prose, not use-sites: a hand-written file whose STRINGS merely quote the
		# convention (a harness pinning "__eventsheet_provider_X.y()") was having a declaration
		# injected into it on save - the same silent rewrite the comment skip above prevents.
		for regex_match: RegExMatch in member_regex.search_all(_without_string_literals(line)):
			providers[regex_match.get_string(0)] = regex_match.get_string(1)
	for declared_name: Variant in declared:
		providers.erase(declared_name)
	if providers.is_empty():
		return
	# Members are declared right before the first function (GDScript allows members
	# anywhere at class level; this placement keeps the generated file readable).
	var insert_index: int = -1
	for index in range(lines.size()):
		if lines[index].begins_with("func ") or lines[index].begins_with("## @ace"):
			insert_index = index
			break
	if insert_index < 0:
		return
	if insert_index > 0 and lines[insert_index - 1].is_empty():
		insert_index -= 1
	var member_names: Array = providers.keys()
	member_names.sort()
	var declarations: PackedStringArray = PackedStringArray()
	declarations.append("")
	declarations.append("# Owned addon-provider instances (instance-backed ACEs).")
	for member_name: Variant in member_names:
		var provider_class: String = str(providers[member_name])
		declarations.append("var %s := %s.new()" % [str(member_name), provider_class])
	for offset in range(declarations.size()):
		lines.insert(insert_index + offset, declarations[offset])
	_shift_source_map(result.get("source_map", []), insert_index + 1, declarations.size())


## `line` with every quoted string literal's content blanked out, so a scan for code constructs never
## reads text inside a string as code. Handles both quote styles and backslash escapes; the interior
## lines of a triple-quoted literal are out of scope for a per-line scan (the declared-member dedup
## in the provider pass backstops that shape).
static func _without_string_literals(line: String) -> String:
	var kept: String = ""
	var open_quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if open_quote.is_empty():
			kept += character
			if character == "\"" or character == "'":
				open_quote = character
		elif character == "\\":
			index += 1
		elif character == open_quote:
			kept += character
			open_quote = ""
		index += 1
	return kept


## Recursively merges included sheets (see EventSheetResource.includes): variables and
## functions skip name collisions with a warning (root wins), rows append in include
## order. Compile-time only - included rows never enter the editing model.
## Composition policy: ProjectSettings gates under
## "eventsheets/addons/*". THE INVARIANT: policy never changes emitted bytes - it only
## decides allowed (error), flagged (warning) or clean. Defaults are permissive so jams
## never meet the policy system.
static func _addon_policy(key: String, default_value: Variant) -> Variant:
	var setting_name: String = "eventsheets/addons/%s" % key
	if ProjectSettings.has_setting(setting_name):
		return ProjectSettings.get_setting(setting_name)
	return default_value


static func _merge_includes(sheet: EventSheetResource, all_events: Array, all_functions: Array, merged_variables: Dictionary, visited: Dictionary, warnings: Array, errors: Array = [], depth: int = 1) -> void:
	var composition_mode: String = str(_addon_policy("composition_mode", "allowed"))
	var max_depth: int = int(_addon_policy("max_include_depth", 2))
	var collision_policy: String = str(_addon_policy("collision_policy", "warn"))
	var include_sources: String = str(_addon_policy("include_sources", "anywhere"))
	var deprecated_blocks: String = str(_addon_policy("deprecated_tag_blocks", "warn"))
	for include_entry: Variant in sheet.includes:
		var include_path: String = str(include_entry).strip_edges()
		if include_path.is_empty():
			continue
		if composition_mode == "off" and sheet.behavior_mode:
			var sheet_label: String = sheet.resource_path.get_file() if not sheet.resource_path.is_empty() else (sheet.custom_class_name if not sheet.custom_class_name.is_empty() else "this sheet")
			errors.append("Policy: addon composition is off (eventsheets/addons/composition_mode) - %s can't include %s." % [sheet_label, include_path.get_file()])
			continue
		if depth > max_depth:
			var depth_message: String = "Include chain deeper than policy max (%d): %s. Deep chains are where addon ecosystems rot - consider flattening." % [max_depth, include_path.get_file()]
			if str(_addon_policy("depth_overflow", "warn")) == "error":
				errors.append(depth_message)
				continue
			warnings.append(depth_message)
		if visited.has(include_path):
			warnings.append("Include skipped (cycle or duplicate): %s" % include_path)
			continue
		visited[include_path] = true
		if not ResourceLoader.exists(include_path):
			warnings.append("Include not found: %s" % include_path)
			continue
		var included: EventSheetResource = load(include_path) as EventSheetResource
		if included == null:
			warnings.append("Include is not an EventSheetResource: %s" % include_path)
			continue
		if include_sources.begins_with("tagged:"):
			var required_tag: String = include_sources.trim_prefix("tagged:").strip_edges()
			if not included.addon_tags.has(required_tag):
				errors.append("Policy: includes must be tagged \"%s\" (eventsheets/addons/include_sources) - %s isn't." % [required_tag, include_path.get_file()])
				continue
		if included.addon_tags.has("deprecated") and deprecated_blocks != "off":
			var deprecated_message: String = "Include %s is tagged deprecated." % include_path.get_file()
			if deprecated_blocks == "error":
				errors.append(deprecated_message)
				continue
			warnings.append(deprecated_message)
		for variable_name: Variant in included.variables.keys():
			if merged_variables.has(variable_name):
				if collision_policy == "error":
					errors.append("Include %s: variable \"%s\" already defined (collision_policy = error)." % [include_path.get_file(), variable_name])
				elif collision_policy != "silent":
					warnings.append("Include %s: variable \"%s\" already defined - root wins." % [include_path.get_file(), variable_name])
			else:
				merged_variables[variable_name] = included.variables[variable_name]
		var existing_function_names: Dictionary = {}
		for existing: Variant in all_functions:
			if existing is EventFunction:
				existing_function_names[(existing as EventFunction).function_name] = true
		for function_resource: Variant in included.functions:
			if function_resource is EventFunction and existing_function_names.has((function_resource as EventFunction).function_name):
				if collision_policy == "error":
					errors.append("Include %s: function \"%s\" already defined (collision_policy = error)." % [include_path.get_file(), (function_resource as EventFunction).function_name])
					continue
				warnings.append("Include %s: function \"%s\" already defined - root wins." % [include_path.get_file(), (function_resource as EventFunction).function_name])
			else:
				all_functions.append(function_resource)
		all_events.append_array(included.events)
		_merge_includes(included, all_events, all_functions, merged_variables, visited, warnings, errors, depth + 1)


## Counts the EventRows nested anywhere under a row list (recursing groups) - drives the
## "N rows omitted" figure in the disabled-group breadcrumb.
static func _count_event_rows(rows: Array) -> int:
	var total: int = 0
	for row: Variant in rows:
		if row is EventRow:
			total += 1
		elif row is EventGroup:
			var inner: EventGroup = row as EventGroup
			total += _count_event_rows(inner.child_rows())
	return total


## A group name sanitized to a legal GDScript identifier fragment: lowercase snake-case,
## non-alphanumerics collapsed to a single underscore, trimmed, "group" when nothing remains.
## Used for BOTH the runtime-toggle guard member and (via _group_slug) the round-trip markers.
## Public: the editor's group picker writes the very token Set/Is Group Active address here.
## No collision suffix here ON PURPOSE: Set/Is Group Active address guards BY NAME
## ("__group_" + name + "_active"), so same-named toggleable groups deliberately share one
## guard - a suffix would make the second group unaddressable from those ACEs.
static func guard_token(group_name: String) -> String:
	var token: String = group_name.strip_edges().to_snake_case()
	var sanitizer: RegEx = RegEx.new()
	sanitizer.compile("[^a-z0-9]+")
	token = sanitizer.sub(token, "_", true)
	while token.begins_with("_"):
		token = token.substr(1)
	while token.ends_with("_"):
		token = token.substr(0, token.length() - 1)
	if token.is_empty():
		token = "group"
	return token


## A deterministic, GDScript-safe slug for a group name - NOT the random group_uid (which would make
## the emitted markers churn on every save). Lowercase, snake-cased, non-alphanumerics collapsed to a
## single underscore, with a numeric suffix on collision so two same-named groups stay distinct.
## `used` accumulates the slugs already handed out this compile.
static func _group_slug(group_name: String, used: Dictionary) -> String:
	var slug: String = guard_token(group_name)
	var candidate: String = slug
	var suffix: int = 2
	while used.has(candidate):
		candidate = "%s_%d" % [slug, suffix]
		suffix += 1
	used[candidate] = true
	return candidate


## Walks the event tree assigning every EventGroup a deterministic slug (filling `slugs`) and
## appending an ordered {slug, parent, group} record to `decls` (parents before children, so the
## importer can rebuild nesting). Recurses into group bodies, mirroring _flatten_trigger_rows' walk.
## A compile hands it the per-compile `_group_slugs`; group_declaration_lines hands it a scratch
## dictionary, so asking what a group's line says never disturbs a compile in flight.
static func _collect_groups(rows: Array, decls: Array, used: Dictionary, slugs: Dictionary,
		parent_slug: String = "") -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			var group_name: String = group.group_name if not group.group_name.is_empty() else group.name
			var slug: String = _group_slug(group_name, used)
			slugs[group] = slug
			decls.append({"slug": slug, "parent": parent_slug, "group": group})
			_collect_groups(group.child_rows(), decls, used, slugs, slug)


## The `## @ace_group(...)` declaration line this compiler writes for every group in `rows`, keyed by
## the EventGroup itself: {EventGroup: String}. PURE - it slugs the tree exactly the way a compile
## does and writes through the same emitter, so a head echoing its group's line can never drift from
## the file, and nothing a compile in flight holds is touched.
static func group_declaration_lines(rows: Array) -> Dictionary:
	var decls: Array = []
	_collect_groups(rows, decls, {}, {})
	var lines: PackedStringArray = PackedStringArray()
	_emit_group_declarations(lines, decls)
	var by_group: Dictionary = {}
	for index: int in range(mini(decls.size(), lines.size())):
		by_group[(decls[index] as Dictionary)["group"]] = lines[index]
	return by_group


## True when free text can be written inside a double-quoted annotation field without breaking it.
static func _group_text_is_safe(text: String) -> bool:
	return not text.contains("\"") and not text.contains("\n")


## Emits the class-scope `## @ace_group(...)` declaration block (one line per group, parents first).
## Only non-default fields are written, and any free-text field with a quote or newline is dropped so
## the single-line annotation always parses - the round-trip degrades gracefully (the group still
## reconstructs from its slug) rather than emitting a line the importer can't read back.
static func _emit_group_declarations(lines: PackedStringArray, decls: Array) -> void:
	for decl: Dictionary in decls:
		var group: EventGroup = decl["group"] as EventGroup
		var group_name: String = group.group_name if not group.group_name.is_empty() else group.name
		var parts: PackedStringArray = PackedStringArray()
		parts.append("uid=\"%s\"" % str(decl["slug"]))
		parts.append("name=\"%s\"" % (group_name if _group_text_is_safe(group_name) else ""))
		if not str(decl["parent"]).is_empty():
			parts.append("parent=\"%s\"" % str(decl["parent"]))
		var description: String = group.description.strip_edges()
		if not description.is_empty() and _group_text_is_safe(description):
			parts.append("description=\"%s\"" % description)
		var color: String = group.color_tag.strip_edges()
		if not color.is_empty() and _group_text_is_safe(color):
			parts.append("color=\"%s\"" % color)
		if group.collapsed:
			parts.append("collapsed=true")
		if group.runtime_toggleable:
			parts.append("toggleable=true")
		# M3 - who runs it, written only when the answer is not "everybody". A single-player sheet
		# therefore emits exactly the header it always emitted.
		if not EventGroup.runs_on_guard(group.runs_on).is_empty():
			parts.append("runs_on=\"%s\"" % group.runs_on.strip_edges())
		lines.append("## @ace_group(%s)" % ", ".join(parts))


## M3. The guards a row inherits from its groups, joined as one and-chain in the order they gate:
## the runtime switch, then who runs it. Either half may be empty, and both empty means no guard.
static func _joined_group_guard(runtime_guard: String, runs_on_guard: String) -> String:
	var terms: PackedStringArray = PackedStringArray()
	for guard: String in [runtime_guard, runs_on_guard]:
		if not guard.strip_edges().is_empty():
			terms.append(guard)
	return " and ".join(terms)


## Flattens trigger-bearing rows for emission: EventRows kept, ENABLED groups recursed (a disabled
## group is dropped but leaves a breadcrumb comment - group-disable semantics), and group comments
## collected as deferred comment lines.
static func _flatten_trigger_rows(rows: Array, into_events: Array, deferred_comment_lines: PackedStringArray, runtime_guard: String = "", group_slug: String = "", runs_on_guard: String = "") -> void:
	for row: Variant in rows:
		if row is EventRow:
			# M3 - the two group guards a row can inherit, as the one and-chain the emitter wraps its
			# conditions in: the runtime switch first (a group that is off runs nothing at all), then
			# who runs it. Either alone is the whole guard; neither leaves the row exactly as it was.
			var guards: String = _joined_group_guard(runtime_guard, runs_on_guard)
			if not guards.is_empty():
				_runtime_group_guards[row] = guards
			# Tag the row with its group's slug so _emit_event_body can emit a `# @group:` marker before
			# it - the breadcrumb the importer reconstructs the EventGroup from.
			if not group_slug.is_empty():
				_row_group_path[row] = group_slug
			into_events.append(row)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			if group.enabled:
				# Runtime-toggleable groups guard their events (nested groups inherit the
				# INNERMOST toggleable guard - toggling the inner group wins, event-sheet-style).
				var child_guard: String = runtime_guard
				if group.runtime_toggleable:
					# guard_token, not raw to_snake_case: "Wave 1!" used to emit
					# `__group_wave_1!_active` - a parse error in the generated script.
					child_guard = "__group_%s_active" % guard_token(group.group_name)
					var already_known: bool = false
					for member_pair: Array in _runtime_group_members:
						if str(member_pair[0]) == child_guard:
							already_known = true
					if not already_known:
						_runtime_group_members.append([child_guard, group.enabled])
				# M3 - who runs it inherits exactly as the switch does, and the INNERMOST answer wins:
				# an owner group inside a host group is the owner's, because that is the one the
				# reader put closest to the rows.
				var child_runs_on: String = EventGroup.runs_on_guard(group.runs_on)
				if child_runs_on.is_empty():
					child_runs_on = runs_on_guard
				_flatten_trigger_rows(group.child_rows(), into_events, deferred_comment_lines, child_guard, _group_slugs.get(group, ""), child_runs_on)
			else:
				# Don't silently drop a disabled group: leave a breadcrumb so the omission is visible
				# in the generated code. Disabling a group intentionally excludes its events (the
				# editor's "Set Group Active" toggle), but vanishing them with no trace is a footgun.
				var omitted: int = _count_event_rows(group.child_rows())
				if omitted > 0:
					var disabled_label: String = (group.group_name if not group.group_name.is_empty() else group.name).strip_edges()
					if disabled_label.is_empty():
						disabled_label = "group"
					deferred_comment_lines.append("(disabled group \"%s\" — %d row%s omitted)" % [disabled_label, omitted, "" if omitted == 1 else "s"])
		elif row is CommentRow and (row as CommentRow).enabled and not (row as CommentRow).text.strip_edges().is_empty():
			deferred_comment_lines.append_array((row as CommentRow).text.split("
"))


## Signal names declared in class-level GDScript blocks, so self-connections to
## block-declared signals validate at compile time.
static func _scan_declared_signals(raw_blocks: Array) -> Array:
	var declared: Array = []
	var regex: RegEx = RegEx.new()
	regex.compile("(?m)^\\s*signal\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for entry: Variant in raw_blocks:
		if not (entry is RawCodeRow):
			continue
		for regex_match in regex.search_all((entry as RawCodeRow).code):
			declared.append(regex_match.get_string(1))
	return declared


## Groups event rows by trigger and emits one handler function per trigger (the standard
## trigger sections), plus the `_ready` connections signal-backed triggers need. Shared by
## the main compile path and the external (GDScript-backed sheet) path.
## connect_context: {self_class: String, declared_signals: Array} - self-connections are
## validated against these at compile time (emitting a connect to a missing signal would
## make the whole generated script fail to parse).
static func _emit_grouped_trigger_functions(event_rows: Array, lines: PackedStringArray, source_map: Array, result: Dictionary, connect_context: Dictionary = {}, deferred_comment_lines: PackedStringArray = PackedStringArray()) -> void:
	var flattened: Array = []
	_flatten_trigger_rows(event_rows, flattened, deferred_comment_lines)
	var grouped: Dictionary = {}
	var trigger_order: PackedStringArray = PackedStringArray()
	for entry: Variant in flattened:
		if not (entry is EventRow):
			continue
		var event_row: EventRow = entry as EventRow
		# A blank trigger is not "no event": it is the every-tick event (TriggerResolver reads it
		# that way), so a blank top-level event groups into `_process` with the explicit ones.
		if not event_row.enabled:
			continue
		var key: String = TriggerResolver.get_trigger_key(event_row)
		if not grouped.has(key):
			grouped[key] = []
			trigger_order.append(key)
		(grouped[key] as Array).append(event_row)

	# Resolve all signatures first so signal-backed triggers' `_ready` connections are
	# known up front (handlers used to be generated but never connected - they only fired
	# when the user wired the signal manually in the scene).
	var signatures: Dictionary = {}
	var ready_connections: PackedStringArray = PackedStringArray()
	for key: String in trigger_order:
		var events: Array = grouped.get(key, [])
		if events.is_empty():
			continue
		var signature: Dictionary = TriggerResolver.resolve_trigger(events[0])
		signatures[key] = signature
		var signal_name: String = str(signature.get("signal_name", ""))
		var function_name: String = str(signature.get("function_name", ""))
		if signal_name.is_empty() or function_name.is_empty():
			continue
		# A LIFTED handler carries the connect line that actually wired it in the source. Re-emit that
		# verbatim: the canonical `get_node("X").sig.connect(fn)` spelling would rewrite a hand-written
		# `$X.sig.connect(fn)` and fail the byte-verify, reverting the whole file to code blocks. Only
		# ever set at lift time, so every authored sheet still gets the generated line below.
		var lifted_connect: String = str((events[0] as EventRow).get_meta("__source_connect_line", "")) if events[0] is EventRow else ""
		if not lifted_connect.is_empty():
			ready_connections.append(lifted_connect)
			continue
		# A handler the project wired in its SCENE FILE. The .tscn owns that connection; the script
		# never held one, so emitting the canonical line here would add a second connection at runtime
		# and put a line into a file that must come back byte-identical. Only ever set at lift time.
		if events[0] is EventRow and bool((events[0] as EventRow).get_meta("__scene_connected", false)):
			continue
		var source_path: String = str(signature.get("source_path", ""))
		if source_path.is_empty():
			# Self-connection: the signal must exist on the script's base class or be
			# declared in a class-level GDScript block, or the generated script would not
			# parse. Skipped connections keep the old behavior (wire it in the scene).
			var self_class: String = str(connect_context.get("self_class", "Node"))
			var declared_signals: Array = connect_context.get("declared_signals", [])
			if not ClassDB.class_has_signal(self_class, signal_name) and not declared_signals.has(signal_name):
				(result["warnings"] as Array[String]).append(
					"Trigger %s: %s has no signal \"%s\" - connection skipped (connect it in the scene or declare the signal in a script block)." % [key, self_class, signal_name]
				)
				continue
		var source_prefix: String = ""
		if source_path == "@tree":
			# Global SceneTree signals (process_frame / physics_frame) - post-tick triggers connect here.
			source_prefix = "get_tree()."
		elif source_path == "@editor_files":
			# W18. The editor's file watcher (filesystem_changed) - On project files changed connects here.
			source_prefix = "EditorInterface.get_resource_filesystem()."
		elif source_path == "@editor_preferences":
			# W18. The user's Editor Settings (settings_changed) - On preferences changed connects here.
			source_prefix = "EditorInterface.get_editor_settings()."
		elif source_path == "@window":
			# Root-window signals (close_requested) - the On Close Requested trigger connects here.
			source_prefix = "get_window()."
		elif source_path == TriggerResolver.MULTIPLAYER_SOURCE:
			# E1. The scene tree's own MultiplayerAPI (peer_connected, server_disconnected, …) - the
			# seven connection triggers connect here. `multiplayer` is a property of every node, which
			# is why the line needs no lookup at all and reads exactly as a hand-written one does.
			source_prefix = "multiplayer."
		elif source_path.begins_with(TriggerResolver.MEMBER_SOURCE_PREFIX):
			# W6. A menu is a variable of this script, not a node looked up by path: the line that
			# wires it is `sheet_popup.id_pressed.connect(...)`, which is what every hand-written
			# menu already says.
			source_prefix = "%s." % source_path.trim_prefix(TriggerResolver.MEMBER_SOURCE_PREFIX)
		elif source_path.begins_with("autoload:"):
			# Bus triggers: autoloads are global - connect by name, no node paths.
			source_prefix = "%s." % source_path.trim_prefix("autoload:")
		elif not source_path.is_empty():
			source_prefix = "get_node(\"%s\")." % source_path
		ready_connections.append("\t%s%s.connect(%s)" % [source_prefix, signal_name, function_name])

	var has_ready_group: bool = false
	for key: String in trigger_order:
		if str((signatures.get(key, {}) as Dictionary).get("function_name", "")) == "_ready":
			has_ready_group = true
	# No OnReady events but connections/receiver needed → synthesize a `_ready`.
	if not has_ready_group and (not ready_connections.is_empty() or _live_values_receiver_pending \
			or _error_reporter_pending):
		# On the external (opened-file) path, honor the SOURCE's own spacing and header spelling
		# when the lift recorded them: a connects-only `_ready` leaves no OnReady event to carry
		# the usual __source_leading_blanks, so its gap (and a non-canonical header) ride the first
		# lifted event instead. Defaults - one blank, canonical header - keep authored sheets
		# byte-identical to what they always emitted.
		var ready_blanks: int = 1
		var ready_header: String = "func _ready() -> void:"
		if bool(connect_context.get("external", false)):
			for entry: Variant in flattened:
				if not (entry is EventRow):
					continue
				var flat_event: EventRow = entry as EventRow
				if flat_event.has_meta("__source_ready_blanks") or flat_event.has_meta("__source_ready_header"):
					ready_blanks = maxi(int(flat_event.get_meta("__source_ready_blanks", 1)), 1)
					ready_header = str(flat_event.get_meta("__source_ready_header", ready_header))
					break
		for _ready_blank_index: int in range(ready_blanks):
			lines.append("")
		lines.append(ready_header)
		if _live_values_receiver_pending:
			lines.append("\tif EngineDebugger.is_active() and not EngineDebugger.has_capture(\"eventsheets\"):")
			lines.append("\t\tEngineDebugger.register_message_capture(&\"eventsheets\", _eventsheets_debug_set)")
			_live_values_receiver_pending = false
		if _error_reporter_pending:
			_emit_error_reporter_arming(lines)
			_error_reporter_pending = false
		for connection_line: String in ready_connections:
			lines.append(connection_line)

	for key: String in trigger_order:
		var events: Array = grouped.get(key, [])
		if events.is_empty():
			continue
		var signature: Dictionary = signatures.get(key, {})
		var function_name: String = str(signature.get("function_name", ""))
		if function_name.is_empty():
			(result["warnings"] as Array[String]).append("Unsupported trigger %s" % key)
			continue
		var args: String = str(signature.get("args", ""))
		# One blank line before each trigger func on the generated path. On the EXTERNAL (opened-file) path,
		# honor the source's own inter-function spacing captured at lift time (__source_leading_blanks on the
		# group's leading event), so a hand-written file with the idiomatic two blank lines between functions
		# round-trips byte-for-byte instead of reverting to a raw block. Default 1 keeps packs single-blank.
		var leading_blanks: int = 1
		if bool(connect_context.get("external", false)) and events[0] is EventRow:
			leading_blanks = maxi(int((events[0] as EventRow).get_meta("__source_leading_blanks", 1)), 1)
		for _blank_index: int in range(leading_blanks):
			lines.append("")
		# A lifted handler whose SOURCE spelled the signature differently (beginner-style
		# `func _physics_process(delta):` - untyped param, no return arrow) re-emits that exact
		# header. Stamped at lift time; the whole-file byte gate verifies it like everything else.
		var source_header: String = str((events[0] as EventRow).get_meta("__source_trigger_header", "")) if events[0] is EventRow else ""
		var returns: String = str(signature.get("return_type", "void"))
		if not source_header.is_empty():
			lines.append(source_header)
		elif args.is_empty():
			lines.append("func %s() -> %s:" % [function_name, returns])
		else:
			lines.append("func %s(%s) -> %s:" % [function_name, args, returns])
		var had_body: bool = false
		var handler_body_start: int = lines.size()
		if function_name == "_ready" and _live_values_receiver_pending:
			# Edit-back channel: the Live Values window's edits arrive as
			# "eventsheets:set_value" messages (debug sessions only; one receiver per
			# game - the first streaming sheet wins, noted in the window).
			lines.append("\tif EngineDebugger.is_active() and not EngineDebugger.has_capture(\"eventsheets\"):")
			lines.append("\t\tEngineDebugger.register_message_capture(&\"eventsheets\", _eventsheets_debug_set)")
			had_body = true
			_live_values_receiver_pending = false
		if function_name == "_ready" and _error_reporter_pending:
			_emit_error_reporter_arming(lines)
			had_body = true
			_error_reporter_pending = false
		if function_name == "_process" and not _throttle_process_emitted and (not _live_values_payload.is_empty() or _emit_event_trace_flag):
			# Live-values stream and/or the event trace: throttled, debug-session-only, before user logic.
			# The trace's frame ruler: how many fires had happened by the top of THIS frame.
			# Unthrottled on purpose - it marks every frame, not every streamed window, and
			# without it a gap between two frames is indistinguishable from a slow event.
			if _emit_event_trace_flag:
				lines.append("\tif EngineDebugger.is_active():")
				lines.append("\t\t__eventsheets_frames.append(__eventsheets_fired.size())")
			lines.append("\t__live_values_timer += delta")
			lines.append("\tif __live_values_timer >= 0.25 and EngineDebugger.is_active():")
			lines.append("\t\t__live_values_timer = 0.0")
			if not _live_values_payload.is_empty():
				_emit_live_values_send(lines)
			if _emit_event_trace_flag:
				lines.append("\t\tEngineDebugger.send_message(\"eventsheets:fired_events\", __eventsheets_fired)")
				lines.append("\t\t__eventsheets_fired.clear()")
				lines.append("\t\tEngineDebugger.send_message(\"eventsheets:event_times\", [__eventsheets_timed, __eventsheets_frames, Time.get_ticks_usec()])")
				lines.append("\t\t__eventsheets_timed.clear()")
				lines.append("\t\t__eventsheets_frames.clear()")
			had_body = true
			_throttle_process_emitted = true
			_live_values_payload = ""
		if function_name == "_ready" and not ready_connections.is_empty():
			# Signal connections run before the user's OnReady logic.
			for connection_line: String in ready_connections:
				lines.append(connection_line)
			had_body = true
		# Sibling isolation (the async-events rule): in a SHARED per-frame handler, an await
		# in one event would suspend the whole function - its sibling events below would
		# freeze until the wait ends. An awaiting event therefore splits into its own
		# coroutine, called WITHOUT await (fire-and-forget) so siblings never wait. Gated
		# to per-frame groups with 2+ events and no else-chains (a chain crossing a split
		# boundary has no meaning); single-event handlers keep the plain shape.
		var split_events: Array = []
		if function_name in ["_process", "_physics_process"] and events.size() > 1:
			var group_chains: bool = false
			for event_entry: Variant in events:
				if event_entry is EventRow and (event_entry as EventRow).else_mode != EventRow.ElseMode.NONE:
					group_chains = true
			if not group_chains:
				for event_entry: Variant in events:
					if event_entry is EventRow and _subtree_awaits(event_entry as EventRow):
						split_events.append(event_entry)
		if _emit_notification_match(events, lines, source_map, result["warnings"]):
			continue
		if _emit_menu_match(events, lines, source_map, result["warnings"]):
			continue
		if split_events.is_empty():
			had_body = _emit_event_body(events, lines, source_map, 1, result["warnings"]) or had_body
		else:
			for event_entry: Variant in events:
				if split_events.has(event_entry):
					lines.append("\t_event_%s_async(delta)" % (event_entry as EventRow).event_uid)
					had_body = true
				else:
					had_body = _emit_event_body([event_entry], lines, source_map, 1, result["warnings"]) or had_body
		if not _has_statement(lines, handler_body_start):
			lines.append("\tpass")
		# The split-out coroutines follow their dispatcher immediately, in event order.
		for event_entry: Variant in split_events:
			lines.append("")
			lines.append("func _event_%s_async(delta: float) -> void:" % (event_entry as EventRow).event_uid)
			var async_body_start: int = lines.size()
			_emit_event_body([event_entry], lines, source_map, 1, result["warnings"])
			if not _has_statement(lines, async_body_start):
				lines.append("\tpass")


## Emits the condition/action body for a list of event rows, appending to lines.
## Shared by trigger handlers, sheet functions, and (recursively) sub-events.
##
## Semantics, mirroring the visual event-sheet model:
## - Each event's conditions emit one `if` at `depth`; its actions and sub-events nest one
##   level deeper. Sub-events therefore run only when the parent's conditions held.
## - An ELSE/ELIF sibling chains onto the previous sibling's `if` (`else:` / `elif c:`).
##   ELSE with conditions is the same thing as ELIF. A chain row without a preceding `if`
##   degrades to a plain event and a warning is recorded.
## - Comments compile to `#` comment lines; GDScript blocks emit with adaptive indentation
##   (pre-indented imported code keeps its own tabs; flat user code is indented for them);
##   variables dropped into an event's flow become function-local `var` declarations.
##
## When source_map is provided, records {uid, start, end, kind} (1-based inclusive lines)
## per emitted row so the editor can highlight a row's generated code.
## Re-emits the author-facing blank lines a lifted body item carries (__source_body_blanks, stamped by
## the lifter). They emit as truly-empty lines (no indent), mirroring the inter-function spacing
## re-emitted from __source_leading_blanks - so a paragraph-formatted hand-written body round-trips
## byte-exact instead of reverting to a verbatim wall. A no-op for every authored row (the meta only
## ever originates at lift time), so ordinary emission is untouched.
static func _emit_leading_body_blanks(item: Variant, lines: PackedStringArray) -> void:
	if not (item is Resource):
		return
	var blanks: int = int((item as Resource).get_meta("__source_body_blanks", 0))
	for _blank_index: int in range(blanks):
		lines.append("")


static func _emit_event_body(
	events: Array,
	lines: PackedStringArray,
	source_map: Array = [],
	depth: int = 1,
	warnings: Array = [],
	inherited_node_target: String = ""
) -> bool:
	var had_body: bool = false
	var indent: String = "\t".repeat(depth)
	# True while the previous sibling ended an if/elif block at this depth, meaning an
	# ELSE/ELIF sibling may legally chain onto it.
	var chain_open: bool = false
	for event_item: Variant in events:
		if event_item is RawCodeRow:
			var raw_row: RawCodeRow = event_item as RawCodeRow
			if raw_row.enabled and not raw_row.code.is_empty():
				_emit_leading_body_blanks(raw_row, lines)
				var raw_start: int = lines.size() + 1
				for code_line: String in _indent_raw_lines(raw_row.code, depth):
					lines.append(code_line)
					had_body = true
				source_map.append({"uid": str(raw_row.get_instance_id()), "start": raw_start, "end": lines.size(), "kind": "raw"})
			chain_open = false
			continue
		if event_item is CommentRow:
			var comment_row: CommentRow = event_item as CommentRow
			if comment_row.enabled and not comment_row.text.strip_edges().is_empty():
				_emit_leading_body_blanks(comment_row, lines)
				var comment_start: int = lines.size() + 1
				for comment_line: String in comment_row.text.split("\n"):
					lines.append("%s# %s" % [indent, comment_line])
					had_body = true
				source_map.append({"uid": str(comment_row.get_instance_id()), "start": comment_start, "end": lines.size(), "kind": "comment"})
			# Comments are transparent to else-chaining (annotating a chain shouldn't break it).
			continue
		if event_item is LocalVariable:
			# A variable inside an event's flow is a function-local declaration. @export is
			# meaningless locally and const is not allowed in function scope, so both emit
			# as plain locals (with a warning so the author knows).
			var local_variable: LocalVariable = event_item as LocalVariable
			if not local_variable.name.strip_edges().is_empty():
				_emit_leading_body_blanks(local_variable, lines)
				if local_variable.exported or local_variable.is_constant:
					warnings.append("Variable '%s' inside an event compiles as a plain local var." % local_variable.name)
				lines.append("%svar %s: %s = %s" % [indent, local_variable.name, local_variable.type_name, _to_code_literal(local_variable.default_value)])
				source_map.append({"uid": str(local_variable.get_instance_id()), "start": lines.size(), "end": lines.size(), "kind": "variable"})
				had_body = true
			chain_open = false
			continue
		if not (event_item is EventRow):
			continue
		var event_row: EventRow = event_item as EventRow
		if not event_row.enabled:
			continue
		# A blank run captured before this block re-emits above its group marker / condition header.
		_emit_leading_body_blanks(event_row, lines)
		# "With node X:" scope: this row's own target (if set) wins, otherwise it inherits an enclosing
		# With-node block's. Threaded into action codegen (blank/self targets inline to X) and down to
		# sub-events. Empty = host-scoped, exactly as before.
		var own_node_target: String = event_row.with_node_target.strip_edges()
		var effective_node_target: String = own_node_target if not own_node_target.is_empty() else inherited_node_target
		var event_start_line: int = lines.size() + 1
		var condition_texts: PackedStringArray = PackedStringArray()
		# Edge-gate terms (Trigger Once style, descriptor `.evaluated_last()`) are hoisted to the END of
		# the chain regardless of their cell position: the edge test asks "was I reached last tick?",
		# which only means "were the OTHER conditions true then?" when every other term short-circuits
		# before it. Collected apart, appended last below.
		var tail_condition_texts: PackedStringArray = PackedStringArray()
		var runtime_group_guard: String = str(_runtime_group_guards.get(event_row, ""))
		for condition: ACECondition in event_row.conditions:
			var condition_line: String = ConditionCodegen.generate_condition(condition, _behavior_host_default)
			if not condition_line.is_empty():
				if _condition_evaluates_last(condition):
					tail_condition_texts.append(condition_line)
				else:
					condition_texts.append(condition_line)
			elif condition != null and condition.enabled and condition.codegen_template.strip_edges().is_empty() and (not condition.ace_id.is_empty() or not condition.provider_id.is_empty()):
				# Unresolvable ACE (addon uninstalled / stale provider_id|ace_id). Fail CLOSED so a
				# vanished gate can never silently run the event body unconditionally every tick.
				warnings.append("Condition %s/%s could not be resolved (addon missing or stale) \u2014 gate forced closed (if false)." % [condition.provider_id, condition.ace_id])
				condition_texts.append("false")
		var joiner: String = " or " if event_row.condition_mode == EventRow.ConditionMode.OR else " and "
		var joined_conditions: String = joiner.join(condition_texts)
		# Runtime-group guards AND-wrap the whole condition - joining a guard into an
		# OR list would silently disable the gate (`guard or a or b`).
		if not runtime_group_guard.is_empty():
			if condition_texts.is_empty():
				joined_conditions = runtime_group_guard
			elif event_row.condition_mode == EventRow.ConditionMode.OR and condition_texts.size() > 1:
				joined_conditions = "%s and (%s)" % [runtime_group_guard, joined_conditions]
			else:
				joined_conditions = "%s and %s" % [runtime_group_guard, joined_conditions]
			condition_texts.append(runtime_group_guard)
		# Append the hoisted edge-gate terms as the FINAL and-terms. An OR list is parenthesized first
		# (unless the guard wrap above already did), so the edge test gates the whole OR result -
		# `(a or b) and __trigger_once_x()` - instead of leaking in by precedence.
		if not tail_condition_texts.is_empty():
			var tail_expression: String = " and ".join(tail_condition_texts)
			if joined_conditions.is_empty():
				joined_conditions = tail_expression
			else:
				if event_row.condition_mode == EventRow.ConditionMode.OR and condition_texts.size() > 1 and runtime_group_guard.is_empty():
					joined_conditions = "(%s)" % joined_conditions
				joined_conditions = "%s and %s" % [joined_conditions, tail_expression]
			condition_texts.append_array(tail_condition_texts)

		# Stateful conditions: prelude lines run every tick BEFORE the if (so they must
		# not sit between an if and its elif - stateful events never chain).
		var stateful_preludes: PackedStringArray = PackedStringArray()
		var stateful_on_true: PackedStringArray = PackedStringArray()
		var stateful_on_exit: PackedStringArray = PackedStringArray()
		for condition: ACECondition in event_row.conditions:
			if not condition.enabled:
				continue
			if not condition.codegen_prelude.is_empty():
				stateful_preludes.append(_substitute_params(condition.codegen_prelude, condition.params))
			# ANY stateful condition breaks when inverted - it would advance its state on the ticks it does
			# not fire. Keyed on the member (Trigger Once carries no on-true rebase, so the old check missed it).
			if condition.negated and not condition.member_declaration.is_empty():
				warnings.append("Stateful conditions (Every X Seconds\u2026) can not be inverted; ignoring the negation.")
			if not condition.codegen_on_true.is_empty():
				stateful_on_true.append(_substitute_params(condition.codegen_on_true, condition.params))
			if not condition.codegen_on_exit.is_empty():
				stateful_on_exit.append(_substitute_params(condition.codegen_on_exit, condition.params))
		for prelude_line: String in stateful_preludes:
			lines.append(indent + prelude_line)
			had_body = true
		# Group breadcrumb: a `# @group:<slug>` line before a grouped event's block, so the importer can
		# reconstruct the EventGroup. Only top-of-group events (else_mode NONE) are tagged - chained
		# else/elif rows belong to the same group as the `if` they continue.
		if event_row.else_mode == EventRow.ElseMode.NONE and _row_group_path.has(event_row):
			lines.append("%s# @group:%s" % [indent, str(_row_group_path[event_row])])
		# Resolve the block header: if / elif / else, per the chaining rules above.
		var wants_chain: bool = event_row.else_mode != EventRow.ElseMode.NONE
		if wants_chain and not stateful_preludes.is_empty():
			warnings.append("Stateful conditions (Every X Seconds…) can't chain as Else/Else-If; emitted standalone.")
			wants_chain = false
		if not stateful_on_true.is_empty() and event_row.condition_mode == EventRow.ConditionMode.OR and event_row.conditions.size() > 1:
			warnings.append("Stateful conditions in OR events rebase whenever ANY condition passes - consider a dedicated event.")
		if wants_chain and not chain_open:
			warnings.append("Else/Else-If event has no preceding conditioned event to chain onto; emitted standalone.")
			wants_chain = false
		var emitted_block: bool = false
		var block_header_line: int = -1
		if wants_chain:
			block_header_line = lines.size()
			if condition_texts.size() > 0:
				lines.append("%selif %s:" % [indent, joined_conditions])
			else:
				lines.append("%selse:" % indent)
			emitted_block = true
			had_body = true
		elif condition_texts.size() > 0:
			block_header_line = lines.size()
			lines.append("%sif %s:" % [indent, joined_conditions])
			emitted_block = true
			had_body = true

		var body_depth: int = depth + (1 if emitted_block else 0)
		if emitted_block:
			for on_true_line: String in stateful_on_true:
				lines.append("\t".repeat(body_depth) + on_true_line)
		# Pick filters ('for each' picking, the Godot way): each enabled filter wraps the
		# event's body in a direct `for` loop - group members, children, or any GDScript
		# iterable - with an optional predicate and first-N cap. Conditions gate the whole
		# loop; multiple filters nest in order. Plain loops keep the parity contract.
		var pick_start_size: int = lines.size()
		body_depth = _emit_pick_filters(event_row, lines, body_depth, warnings)
		var emitted_pick_loop: bool = lines.size() > pick_start_size
		had_body = had_body or emitted_pick_loop
		var body_indent: String = "\t".repeat(body_depth)
		if _emit_event_trace_flag:
			lines.append("%s__eventsheets_fired.append(\"%s\")" % [body_indent, event_row.event_uid])
			lines.append("%s__eventsheets_timed.append(Time.get_ticks_usec())" % body_indent)
			had_body = true
		if _emit_breakpoints_flag and event_row.debug_break:
			var break_condition: String = event_row.debug_break_condition.strip_edges()
			# Announce WHICH row is about to pause before the breakpoint statement: the editor-side
			# debugger bridge captures "eventsheets:paused_row" and reveals that row on the sheet -
			# core debugger messages (stack dumps) never reach editor plugins, so the generated code
			# reports its own location over the same custom channel live-values already uses.
			var announce: String = "if EngineDebugger.is_active(): EngineDebugger.send_message(\"eventsheets:paused_row\", [\"%s\"])" % event_row.event_uid
			if break_condition.is_empty():
				lines.append(body_indent + announce)
				lines.append(body_indent + "breakpoint")
			else:
				lines.append("%sif %s:" % [body_indent, break_condition])
				lines.append("%s	%s" % [body_indent, announce])
				lines.append("%s	breakpoint" % body_indent)
			had_body = true
		var body_start_size: int = lines.size()

		for action_item: Variant in event_row.actions:
			if action_item is ACEAction:
				var action_line: String = ActionCodegen.generate_action(action_item, effective_node_target, _behavior_host_default)
				if action_line.is_empty():
					continue
				_emit_leading_body_blanks(action_item, lines)
				# Multi-statement templates (Spawn Scene At…) emit one line each; an awaited action
				# awaits only its LAST statement (the actual call) - prefixing `await` onto the joined
				# multi-line string would land it on a `var … =` declaration line (a parse error).
				var action_lines: PackedStringArray = action_line.split("\n")
				for line_index: int in action_lines.size():
					var emitted_line: String = action_lines[line_index]
					if (action_item.is_awaited or action_item.await_call) and line_index == action_lines.size() - 1:
						emitted_line = "await %s" % emitted_line
					lines.append(body_indent + emitted_line)
				had_body = true
			elif action_item is RawCodeRow:
				# In-flow GDScript block (inline scripting): emitted verbatim inside the
				# event body at the body indent (inner indentation preserved beneath it).
				var inline_raw: RawCodeRow = action_item as RawCodeRow
				if not inline_raw.enabled or inline_raw.code.strip_edges().is_empty():
					continue
				_emit_leading_body_blanks(inline_raw, lines)
				var inline_start: int = lines.size() + 1
				for inline_line: String in inline_raw.code.split("\n"):
					lines.append(body_indent + inline_line)
				had_body = true
				source_map.append({"uid": str(inline_raw.get_instance_id()), "start": inline_start, "end": lines.size(), "kind": "raw"})
			elif action_item is CollectionDeclRow:
				# A structured in-body collection declaration (Declare <name> with entry rows). The
				# brackets exist only HERE: emit_lines() writes them back around the entries, and it is
				# the same function the importer's parse() byte-gate compares against, so the two can
				# never disagree about what an untouched declaration looks like on disk.
				var decl: CollectionDeclRow = action_item as CollectionDeclRow
				if not decl.enabled:
					continue
				_emit_leading_body_blanks(decl, lines)
				var decl_start: int = lines.size() + 1
				for decl_line: String in decl.emit_lines():
					lines.append(body_indent + decl_line)
				had_body = true
				source_map.append({"uid": str(decl.get_instance_id()), "start": decl_start, "end": lines.size(), "kind": "collection_decl"})
			elif action_item is MatchRow:
				# A GDScript `match` as a structured action row (the switch idiom): subject + branches one
				# level deeper. Structured `cases` (each an editable action body) win when present; otherwise
				# the verbatim branches_text form (the raw escape hatch + what today's importer lifts).
				var match_row: MatchRow = action_item as MatchRow
				if not match_row.enabled or match_row.match_expression.strip_edges().is_empty():
					continue
				_emit_leading_body_blanks(match_row, lines)
				var match_start: int = lines.size() + 1
				lines.append(body_indent + "match %s:" % match_row.match_expression.strip_edges())
				if not match_row.cases.is_empty():
					for match_case: MatchCase in match_row.cases:
						if match_case == null or not match_case.enabled:
							continue
						lines.append(body_indent + "\t" + match_case.pattern.strip_edges() + ":")
						var case_lines: PackedStringArray = _emit_match_case_body(match_case.events, body_indent + "\t\t", effective_node_target)
						if case_lines.is_empty():
							lines.append(body_indent + "\t\tpass")  # a match branch may not be empty
						else:
							lines.append_array(case_lines)
				else:
					for branch_line: String in match_row.branches_text.split("\n"):
						lines.append(body_indent + "\t" + branch_line)
				had_body = true
				source_map.append({"uid": str(match_row.get_instance_id()), "start": match_start, "end": lines.size(), "kind": "match"})
			elif action_item is TimelineRow:
				# A Timeline: the schedule as an await-chain, exactly what a GDScript author would
				# write by hand. Steps emit in stored order; only FORWARD gaps await, so equal
				# times run back to back. The whole chain suspends - same contract as Wait.
				var timeline: TimelineRow = action_item as TimelineRow
				if not timeline.enabled or timeline.steps.is_empty():
					continue
				_emit_leading_body_blanks(timeline, lines)
				var timeline_start: int = lines.size() + 1
				var timeline_cursor: float = 0.0
				for step: TimelineStep in timeline.steps:
					if step == null or not step.enabled or step.action == null:
						continue
					if step.at > timeline_cursor + 0.0001:
						# snappedf keeps 1.2 - 1.0 reading "0.2", not "0.19999999999999996".
						lines.append(body_indent + "await get_tree().create_timer(%s).timeout" % var_to_str(snappedf(step.at - timeline_cursor, 0.001)))
						timeline_cursor = step.at
					var step_lines: PackedStringArray = _emit_match_case_body([step.action], body_indent, effective_node_target)
					lines.append_array(step_lines)
				had_body = true
				source_map.append({"uid": str(timeline.get_instance_id()), "start": timeline_start, "end": lines.size(), "kind": "timeline"})
			elif action_item is CommentRow:
				# Action-cell comment: annotates the flow, compiles to comment lines.
				var action_comment: CommentRow = action_item as CommentRow
				if action_comment.enabled and not action_comment.text.strip_edges().is_empty():
					_emit_leading_body_blanks(action_comment, lines)
					var action_comment_start: int = lines.size() + 1
					# The marker is whatever the source used, so a `#no space` note re-emits as written rather
					# than gaining a space. Authored comments carry none and get the ordinary "# ".
					var comment_marker: String = action_comment.emit_marker()
					for comment_line: String in action_comment.text.split("\n"):
						lines.append("%s%s%s" % [body_indent, comment_marker, comment_line])
					had_body = true
					source_map.append({"uid": str(action_comment.get_instance_id()), "start": action_comment_start, "end": lines.size(), "kind": "comment"})
			elif action_item is Resource and action_item.has_method("get_row_kind"):
				lines.append(body_indent + "# (unknown row type — preserved as a comment so nothing is silently dropped)")
				had_body = true

		# Sub-events run inside the parent's block (under its conditions).
		if not event_row.sub_events.is_empty():
			had_body = _emit_event_body(event_row.sub_events, lines, source_map, body_depth, warnings, effective_node_target) or had_body

		# The run-finished hook (Once At A Time's reset): emitted INSIDE the event's block,
		# after actions and sub-events - in a coroutine body this line runs when the last
		# await has completed, which is exactly what "the run is over" means. Emitted at the
		# CONDITION depth, not the pick depth, so a gated loop resets once per whole run.
		if emitted_block and not stateful_on_exit.is_empty():
			for on_exit_line: String in stateful_on_exit:
				lines.append("\t".repeat(depth + 1) + on_exit_line)
			had_body = true
		# An if/elif/else block (or pick loop) whose body emitted nothing needs `pass` to
		# stay valid GDScript (e.g. a condition-only event, or one whose actions all
		# compiled to nothing).
		if (emitted_block or emitted_pick_loop) and not _has_statement(lines, body_start_size):
			lines.append(body_indent + "pass")
			had_body = true
		# A block the importer lifted from a ONE-LINE source (`if target == null: return`) folds its
		# single body line back onto its header, which is where that line was written. Only ever taken
		# for a row carrying the lift's own flag, so nothing an author builds in the editor changes
		# shape; refused the moment the body is not exactly one line (a pick loop, a sub-event, a
		# multi-statement template), because then there is no one line to fold.
		if emitted_block and not emitted_pick_loop and block_header_line >= 0 \
				and bool(event_row.get_meta("__source_inline_block", false)) \
				and lines.size() == block_header_line + 2:
			lines[block_header_line] = "%s %s" % [lines[block_header_line], lines[block_header_line + 1].substr(body_indent.length())]
			lines.remove_at(block_header_line + 1)
		# V4. The row's Static locals live as class members, so every line this event just wrote -
		# its condition header and its sub-events included, which is exactly the scope the local had -
		# says the member's name instead of the row's. The rewrite happens on the emitted TEXT, never
		# on the row model: what the author typed stays what the author typed.
		_rewrite_static_local_uses(event_row, lines, event_start_line - 1)
		if lines.size() >= event_start_line:
			source_map.append({"uid": str(event_row.get_instance_id()), "start": event_start_line, "end": lines.size(), "kind": "event"})
		# A bare `else:` ENDS the chain - nothing may follow it but a fresh `if`. Left open, a second
		# Else sibling chained onto the first and wrote `else:` twice in a row, which is a file that
		# does not parse. An `elif` keeps the chain open, because more may still follow it.
		chain_open = emitted_block and not (wants_chain and condition_texts.is_empty())
	return had_body


## V4. Rewrites an event's uses of its Static locals onto the members they were hoisted to, over the
## lines the event emitted from `from_index` on. Whole-word and literal-safe (a printed sentence that
## happens to contain the name is displayed text), through the one rename the refactors already use.
static func _rewrite_static_local_uses(event_row: EventRow, lines: PackedStringArray, from_index: int) -> void:
	for local_entry: Variant in event_row.local_variables:
		if not (local_entry is LocalVariable) or not (local_entry as LocalVariable).static_local:
			continue
		var local_var: LocalVariable = local_entry as LocalVariable
		var member: String = LocalVariable.static_local_member(local_var.name)
		for index: int in range(maxi(from_index, 0), lines.size()):
			lines[index] = EventSheetRefactor.rename_in_code(lines[index], local_var.name, member)


## Emits one structured match branch's body (the action-lane items of a MatchCase) at `indent`, reusing the
## ordinary action codegen so a case runs actions exactly like an event body does. Returns the lines (empty
## when the case has no emittable body, so the caller can substitute `pass`). Handles ACEAction (with the
## same last-statement `await` rule the main loop uses), a verbatim RawCodeRow, and a CommentRow.
static func _emit_match_case_body(events: Array, indent: String, node_target: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for item: Variant in events:
		if item is ACEAction:
			var action: ACEAction = item as ACEAction
			var action_line: String = ActionCodegen.generate_action(action, node_target, _behavior_host_default)
			if action_line.is_empty():
				continue
			var action_lines: PackedStringArray = action_line.split("\n")
			for line_index: int in action_lines.size():
				var emitted: String = action_lines[line_index]
				if (action.is_awaited or action.await_call) and line_index == action_lines.size() - 1:
					emitted = "await %s" % emitted
				out.append(indent + emitted)
		elif item is RawCodeRow:
			var raw: RawCodeRow = item as RawCodeRow
			if not raw.enabled or raw.code.strip_edges().is_empty():
				continue
			for raw_line: String in raw.code.split("\n"):
				out.append(indent + raw_line)
		elif item is CommentRow:
			var comment: CommentRow = item as CommentRow
			if comment.enabled and not comment.text.strip_edges().is_empty():
				for comment_line: String in comment.text.split("\n"):
					out.append("%s# %s" % [indent, comment_line])
	return out


## Emits the `for` loop headers for an event's pick filters and returns the new body depth.
## Supported per filter: collection (GROUP → get_nodes_in_group, CHILDREN → get_children,
## EXPRESSION/ARRAY → verbatim GDScript iterable), predicate_expression (iterator-scoped
## GDScript), pick_first_n. order_by is not compiled yet (warning); filter_conditions use
## host-context templates and are likewise warned - write the predicate instead.
static func _emit_pick_filters(event_row: EventRow, lines: PackedStringArray, body_depth: int, warnings: Array) -> int:
	var loop_index: int = 0
	var pick_idx: int = -1
	var event_awaits: bool = _subtree_awaits(event_row)
	for filter_entry: Variant in event_row.pick_filters:
		pick_idx += 1
		if not (filter_entry is PickFilter) or not (filter_entry as PickFilter).enabled:
			continue
		var pick: PickFilter = filter_entry as PickFilter
		var collection: String = _pick_collection_expression(pick)
		if collection.is_empty():
			warnings.append("Pick filter skipped: no collection for kind %d (set collection_value)." % pick.collection_kind)
			continue
		var iterator: String = pick.iterator_name.strip_edges()
		if iterator.is_empty():
			iterator = "item"
		var indent: String = "\t".repeat(body_depth)
		var counter_name: String = "__pick_count_%d" % loop_index
		# Budgeted For Each (frame-spreading): process a slice per frame over a persistent snapshot, then
		# resume next frame. The cursor + snapshot are class members (see _collect_stateful_members); BOTH
		# the budget/count break and the pass-restart sit at the TOP of the loop (the body is emitted by the
		# caller, so there is no after-body hook). Not yet combined with While/Repeat/order-by/pick-first-N.
		var is_budgeted: bool = pick.frame_spread_count > 0 or pick.frame_spread_budget_ms > 0.0
		if is_budgeted and (pick.collection_kind == PickFilter.CollectionKind.WHILE or pick.collection_kind == PickFilter.CollectionKind.REPEAT or not pick.order_by_expression.strip_edges().is_empty() or pick.pick_first_n > 0):
			warnings.append("Frame-spreading ignored on this loop: not yet supported with While/Repeat, order-by, or pick-first-N - emitting a normal loop.")
			is_budgeted = false
		if is_budgeted and not pick.index_name.strip_edges().is_empty():
			warnings.append("Loop index ignored on this loop: not yet supported with frame-spreading (the cursor would reset every frame).")
		if is_budgeted:
			var uid: String = "%s_%d" % [event_row.event_uid, pick_idx]
			# A budgeted loop only resumes because its trigger re-fires every frame. Warn on the common
			# footgun: a top-level event whose trigger is one-shot would process only the first slice. (A
			# sub-event has no trigger_id of its own, so it can't be checked here - that's documented.)
			if not event_row.trigger_id.is_empty() and event_row.trigger_id != "OnProcess" and event_row.trigger_id != "OnPhysicsProcess":
				warnings.append("Budgeted For Each under a one-shot trigger ('%s') only processes the first slice - drive it from On Process, or clear the frame-spread budget." % event_row.trigger_id)
			var count_lit: int = pick.frame_spread_count
			var budget_str: String = str(pick.frame_spread_budget_ms)
			lines.append("%sif __loop_cursor_%s >= __loop_items_%s.size():" % [indent, uid, uid])
			lines.append("%s\t__loop_cursor_%s = 0" % [indent, uid])
			lines.append("%sif __loop_cursor_%s == 0:" % [indent, uid])
			lines.append("%s\t__loop_items_%s = Array(%s)" % [indent, uid, collection])
			lines.append("%svar __loop_end_%s: int = Time.get_ticks_usec() + int(%s * 1000.0)" % [indent, uid, budget_str])
			lines.append("%svar __done_%s: int = 0" % [indent, uid])
			lines.append("%swhile __loop_cursor_%s < __loop_items_%s.size():" % [indent, uid, uid])
			body_depth += 1
			indent = "\t".repeat(body_depth)
			# Break only AFTER at least one item this frame (__done > 0); otherwise a tiny ms budget that is
			# already spent at loop entry would break with the cursor unmoved and stall the pass forever.
			lines.append("%sif __done_%s > 0 and ((%d > 0 and __done_%s >= %d) or (%s > 0.0 and Time.get_ticks_usec() >= __loop_end_%s)):" % [indent, uid, count_lit, uid, count_lit, budget_str, uid])
			lines.append("%s\tbreak" % indent)
			lines.append("%svar %s = __loop_items_%s[__loop_cursor_%s]" % [indent, iterator, uid, uid])
			lines.append("%s__loop_cursor_%s += 1" % [indent, uid])
			lines.append("%s__done_%s += 1" % [indent, uid])
			lines.append("%sif %s is Object and not is_instance_valid(%s):" % [indent, iterator, iterator])
			lines.append("%s\tcontinue" % indent)
		else:
			# Event-sheet loop index (opt-in): a named 0-based counter - declared just above
			# the loop, bumped as the body's FIRST statement. The importer lifts this exact
			# three-line shape back into index_name, so it round-trips byte-identically. Kept
			# 0-based independently of the iterator (a Repeat over range(2, 8) still counts from
			# 0), which is what makes it the loop index counter rather than "the iterator again".
			var loop_index_name: String = pick.index_name.strip_edges()
			if not loop_index_name.is_valid_identifier():
				loop_index_name = ""
			if not loop_index_name.is_empty():
				lines.append("%svar %s: int = -1" % [indent, loop_index_name])
			if pick.pick_first_n > 0:
				lines.append("%svar %s: int = 0" % [indent, counter_name])
			if pick.collection_kind == PickFilter.CollectionKind.WHILE:
				# While loops reuse the picking pipeline (predicate/first-N still apply).
				lines.append("%swhile %s:" % [indent, collection])
			else:
				# Ordered picking (pick nearest/furthest): sort a copy by the order
				# expression (written in terms of the iterator) before looping.
				if not pick.order_by_expression.strip_edges().is_empty():
					var sorted_name: String = "__pick_sorted_%d" % loop_index
					var iterator_regex: RegEx = RegEx.new()
					iterator_regex.compile("\\b%s\\b" % iterator)
					var key_a: String = iterator_regex.sub(pick.order_by_expression.strip_edges(), "__pick_a", true)
					var key_b: String = iterator_regex.sub(pick.order_by_expression.strip_edges(), "__pick_b", true)
					lines.append("%svar %s: Array = Array(%s)" % [indent, sorted_name, collection])
					lines.append("%s%s.sort_custom(func(__pick_a, __pick_b): return (%s) %s (%s))" % [indent, sorted_name, key_a, ">" if pick.order_descending else "<", key_b])
					collection = sorted_name
				lines.append("%sfor %s in %s:" % [indent, iterator, collection])
			body_depth += 1
			indent = "\t".repeat(body_depth)
			if not loop_index_name.is_empty():
				lines.append("%s%s += 1" % [indent, loop_index_name])
			# Unpick-on-free (the async-events rule): when this event's body awaits, an item
			# can be freed while the handler is suspended - guard every iteration so freed
			# objects are skipped, exactly like the budgeted loop's validity check. One flat
			# line on purpose: it lifts as a plain leading statement and regenerates on emit.
			if event_awaits and pick.collection_kind != PickFilter.CollectionKind.REPEAT:
				lines.append("%sif %s is Object and not is_instance_valid(%s): continue" % [indent, iterator, iterator])
		var predicate: String = pick.predicate_expression.strip_edges()
		if not predicate.is_empty():
			lines.append("%sif not (%s):" % [indent, predicate])
			lines.append("%s\tcontinue" % indent)
		var filter_guard: String = _compile_filter_conditions(pick, iterator)
		if not filter_guard.is_empty():
			lines.append("%sif not (%s):" % [indent, filter_guard])
			lines.append("%s\tcontinue" % indent)
		if not is_budgeted and pick.pick_first_n > 0:
			lines.append("%s%s += 1" % [indent, counter_name])
			lines.append("%sif %s > %d:" % [indent, counter_name, pick.pick_first_n])
			lines.append("%s\tbreak" % indent)
		loop_index += 1
	return body_depth


## Whether an event's body (actions, raw blocks, sub-events) contains an await - i.e. the
## handler can suspend mid-loop and picked objects may be freed before it resumes. Checks
## the baked template AND the builtin coroutine ids: a lifted builtin action carries only
## its ace_id (the template re-resolves at emit), so the id list is load-bearing here.
const _COROUTINE_ACE_IDS: Array[String] = ["Wait", "AwaitSignal", "AwaitNextFrame", "AwaitIfOverBudget"]


static func _subtree_awaits(event_row: EventRow) -> bool:
	for action_item: Variant in event_row.actions:
		if action_item is ACEAction:
			var action: ACEAction = action_item as ACEAction
			if action.is_awaited or action.await_call or action.codegen_template.contains("await ") or _COROUTINE_ACE_IDS.has(action.ace_id):
				return true
		elif action_item is RawCodeRow and (action_item as RawCodeRow).code.contains("await "):
			return true
	for sub: Variant in event_row.sub_events:
		if sub is EventRow and _subtree_awaits(sub as EventRow):
			return true
	return false


## Compiles a pick filter's structured conditions into one iterator-scoped boolean guard.
## Node-typed conditions are called on the picked instance ({iterator}.<expr>); global
## templates (Input.*, variable compares) stay as-is. AND (filter_mode 0) or OR (1).
static func _compile_filter_conditions(pick: PickFilter, iterator: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in pick.filter_conditions:
		if not (entry is ACECondition) or not (entry as ACECondition).enabled:
			continue
		var cond: ACECondition = entry as ACECondition
		var base: String = _condition_base_expr(cond)
		if base.strip_edges().is_empty():
			continue
		# An inverted comparison flips its operator instead of wearing a `not (...)`, exactly as it
		# does in an event header (ConditionCodegen). "" whenever the condition is not the plain
		# `{a} {op} {b}` shape, which is what keeps every other inverted filter term wrapped.
		var flipped: String = _flipped_condition_expr(cond) if cond.negated else ""
		var inverted: bool = cond.negated and flipped.is_empty()
		if not flipped.is_empty():
			base = flipped
		if _condition_is_node_scoped(cond):
			base = "%s.%s" % [iterator, base]
		var part: String = "not (%s)" % base if inverted else base
		parts.append("(%s)" % part)
	if parts.is_empty():
		return ""
	var joiner: String = " or " if pick.filter_mode == 1 else " and "
	return joiner.join(parts)


## The condition's boolean template with params applied, WITHOUT negation (so a node scope
## can be inserted before the `not`). Mirrors ConditionCodegen.generate_condition lookup.
static func _condition_base_expr(condition: ACECondition) -> String:
	var template: String = condition.codegen_template.strip_edges()
	if template.is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
		if descriptor == null:
			return ""
		template = descriptor.codegen_template
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	return ActionCodegen._apply_template(template, params)


## The same expression with the comparison operator flipped to its opposite, or "" when the condition
## is not the plain `{a} {op} {b}` shape - or when it was lifted from a file that wrote the long
## spelling, which re-emits the words its own file has. The short spelling of an inverted comparison.
static func _flipped_condition_expr(condition: ACECondition) -> String:
	if condition.negation_wrapped:
		return ""
	var template: String = condition.codegen_template.strip_edges()
	if template.is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
		if descriptor == null:
			return ""
		template = descriptor.codegen_template
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var flipped: Dictionary = EventForgeACEFactory.flipped_comparison_params(template, params)
	return "" if flipped.is_empty() else ActionCodegen._apply_template(template, flipped)


## The GDScript a condition compiles to, negation aside - the editor's readers use it to recognize
## shapes no single template names, like the input-event type test a handler branches on. Public
## because reading a row must never have to guess at what the row will emit.
static func condition_source_text(condition: ACECondition) -> String:
	return _condition_base_expr(condition) if condition != null else ""


## True when a condition targets the implicit node (node_type set), so in a pick loop it
## must be scoped to the picked instance. Resolves node_type via the registry; a custom/addon
## condition carrying ONLY a baked codegen_template with no findable descriptor is treated as
## non-node-scoped (its base expression still compiles, it just isn't iterator-prefixed).
## Builtins + registered addons - the common case - resolve correctly.
static func _condition_is_node_scoped(condition: ACECondition) -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	return descriptor != null and not descriptor.node_type.strip_edges().is_empty()


## The GDScript iterable a pick filter loops over ("" = unsupported configuration).
static func _pick_collection_expression(pick: PickFilter) -> String:
	var value: String = pick.collection_value.strip_edges()
	if value.is_empty():
		value = pick.source_expression.strip_edges()
	match pick.collection_kind:
		PickFilter.CollectionKind.REPEAT:
			return "range(%s)" % value
		PickFilter.CollectionKind.WHILE:
			return value
		PickFilter.CollectionKind.GROUP:
			return "get_tree().get_nodes_in_group(\"%s\")" % value if not value.is_empty() else ""
		PickFilter.CollectionKind.CHILDREN:
			return "get_children()"
		PickFilter.CollectionKind.EXPRESSION, PickFilter.CollectionKind.ARRAY:
			return value
		_:
			# NODE_PATH_ARRAY / NODE_TREE / CUSTOM: honor an explicit expression, else skip.
			return value


## Indents a sibling GDScript block's lines for `depth`. Imported code already carries its
## own leading tab (function bodies arrive pre-indented for depth 1), while code written in
## the block editor is flat - detect which and prepend accordingly so both emit correctly.
static func _indent_raw_lines(code: String, depth: int) -> PackedStringArray:
	var raw_lines: PackedStringArray = code.split("\n")
	var self_indented: bool = false
	for raw_line: String in raw_lines:
		if not raw_line.strip_edges().is_empty():
			self_indented = raw_line.begins_with("\t")
			break
	var prefix: String = "\t".repeat(depth - 1 if self_indented else depth)
	var output: PackedStringArray = PackedStringArray()
	for raw_line: String in raw_lines:
		output.append(prefix + raw_line if not raw_line.strip_edges().is_empty() else raw_line)
	return output


## Emits the `@ace_*` annotation block above an exposed sheet function. The annotations are
## parsed back by EventSheetSemanticAnalyzer when the compiled script is registered as a
## provider (drop it into res://eventsheet_addons/), publishing the function as an ACE in
## every sheet - the sheet → script → addon loop behaviors and custom nodes build on.
## Emits the function's Godot doc comment (the plain `##` block) ABOVE everything else - the topmost lines,
## matching Godot's convention that a member's doc comment sits directly above it (and above annotations).
## A blank stored line emits a bare `##`. Empty doc_comment emits nothing, so existing output is unchanged.
static func _emit_function_doc_comment(event_function: EventFunction, lines: PackedStringArray) -> void:
	if event_function.doc_comment.strip_edges().is_empty():
		return
	for doc_line: String in event_function.doc_comment.split("\n"):
		lines.append("##" if doc_line.is_empty() else "## %s" % doc_line)


## Emits any verbatim GDScript annotation lines (`@rpc(...)`, `@warning_ignore(...)`, ...) carried on the
## function, between the `## @ace_*` block and the `func` header. Empty for every function without them, so
## existing output is byte-unchanged.
static func _emit_function_annotation_prefix(event_function: EventFunction, lines: PackedStringArray) -> void:
	for annotation_line: String in event_function.annotation_lines:
		lines.append(annotation_line)


static func _emit_expose_annotations(event_function: EventFunction, sheet: EventSheetResource, lines: PackedStringArray) -> void:
	if event_function.lifted_unannotated:
		# Reverse-lifted from a hand-written helper with no annotation block - the source had no
		# `## @ace_hidden`, so emit none (keeps the opened .gd byte-identical on save).
		return
	if not event_function.expose_as_ace:
		# Reflection publishes any public method of a provider script, so unexposed sheet
		# functions are explicitly hidden - expose_as_ace is the single publication switch.
		lines.append("## @ace_hidden")
		return
	# Three-way expose: the return type picks the directive - void = action, bool = condition, any
	# other value = expression (one method → one ACE, so exactly ONE directive). The shared
	# @ace_codegen_template ($Class.fn(args)) serves all three: a method call returning bool/value is a
	# valid condition/expression. The lifter re-derives the type from the return type on round-trip.
	match event_function.return_type:
		TYPE_NIL:
			lines.append("## @ace_action")
		TYPE_BOOL:
			lines.append("## @ace_condition")
		_:
			lines.append("## @ace_expression")
	# Featured rides directly on the expose directive (starred + bold in the picker).
	if event_function.featured:
		lines.append("## @ace_featured")
	var display_name: String = event_function.ace_display_name.strip_edges()
	if not display_name.is_empty():
		lines.append("## @ace_name(\"%s\")" % display_name)
	var category: String = event_function.ace_category.strip_edges()
	if not category.is_empty():
		lines.append("## @ace_category(\"%s\")" % category)
	if not event_function.description.strip_edges().is_empty():
		lines.append("## @ace_description(\"%s\")" % event_function.description.strip_edges())
	# A readable sentence for the row (and the picker), with {param} slots - emitted right after the
	# description so the block round-trips in a stable order.
	if not event_function.display_template.strip_edges().is_empty():
		lines.append("## @ace_display_template(\"%s\")" % event_function.display_template.strip_edges())
	# Param dropdowns and widget hints ship as one-line annotations the provider scanner
	# reads back - without these the picker loses the combos a builder declared.
	for annotated_param in event_function.params:
		if annotated_param is ACEParam:
			var ace_param: ACEParam = annotated_param
			if not ace_param.options.is_empty():
				var option_texts: PackedStringArray = PackedStringArray()
				for option_value in ace_param.options:
					option_texts.append(_param_option_text(option_value))
				lines.append("## @ace_param_options(%s %s)" % [ace_param.id, ", ".join(option_texts)])
			if not ace_param.hint.strip_edges().is_empty():
				lines.append("## @ace_param_hint(%s %s)" % [ace_param.id, ace_param.hint.strip_edges()])
	# The sheet's icon flows to the published ACE (one icon, set once, shown everywhere).
	if not sheet.custom_class_icon.strip_edges().is_empty():
		lines.append("## @ace_icon(\"%s\")" % sheet.custom_class_icon.strip_edges())
	# Default codegen template so consumer sheets compile a direct call: behaviors are
	# child nodes (default node name = class name) → `$Class.fn({args})`; custom-node /
	# plain sheets expose self methods → `fn({args})`. Authors can refine via re-annotation.
	var argument_tokens: PackedStringArray = PackedStringArray()
	for param in event_function.params:
		if param is ACEParam and not (param as ACEParam).id.strip_edges().is_empty():
			argument_tokens.append("{%s}" % (param as ACEParam).id)
	# A template that is not of the prefix + call shape (kept verbatim from an opened file) wins outright.
	if not event_function.codegen_template_override.strip_edges().is_empty():
		lines.append("## @ace_codegen_template(\"%s\")" % event_function.codegen_template_override)
		return
	var call_prefix: String = ""
	if event_function.codegen_prefix_known:
		# The opened file's own prefix (`Quests.`, `BigNumber.`, `$FPSController.`): a pack read outside
		# its project cannot re-derive an autoload or static address, so the source's is authoritative.
		call_prefix = event_function.codegen_call_prefix
	elif sheet.behavior_mode and not sheet.custom_class_name.strip_edges().is_empty():
		call_prefix = "$%s." % sheet.custom_class_name.strip_edges()
	elif not sheet.autoload_singleton_name().is_empty():
		# Singletons are addressed by their autoload name - works from every scene,
		# no node paths (the whole point of an autoload).
		call_prefix = "%s." % sheet.autoload_singleton_name()
	lines.append("## @ace_codegen_template(\"%s%s(%s)\")" % [call_prefix, event_function.function_name, ", ".join(argument_tokens)])


## One dropdown option, in the form the provider scanner reads back out of the emitted pack.
##
## A `{"key", "label"}` option becomes `key=Label`, so the dropdown READS as English while
## INSERTING the real token. Plain string options stay bare, which is what keeps every pack that
## never labeled its options emitting byte-identically. str()-ing the dict instead baked raw
## GDScript into the annotation, and since the scanner splits that list on commas, one labeled
## option came back as several broken ones.
##
## A key that contains a separator ships QUOTED - `"<="=<= (at most)` - so the scanner can tell
## where it ends. Every comparison operator needs this: the split is on the first `=`, so a bare
## `>==>= (at least)` would come back as key `>`.
##
## Labels have no such escape (the entry itself is comma delimited), so a label containing a comma
## degrades to its bare key rather than emitting an annotation that parses into garbage: the
## dropdown still offers the right value, it just loses the prettier wording.
static func _param_option_text(option_value: Variant) -> String:
	if not option_value is Dictionary:
		return str(option_value)
	var pair: Dictionary = option_value as Dictionary
	var key: String = str(pair.get("key", ""))
	var label: String = str(pair.get("label", key))
	var key_text: String = key
	if key.contains("=") or key.contains(",") or key.contains("|") or key.begins_with("\""):
		key_text = "\"%s\"" % key
	if label == key or label.is_empty() or label.contains(","):
		return key_text
	return "%s=%s" % [key_text, label]


## True when the lines from `from_index` on carry at least one real STATEMENT, not just comments and
## blanks. GDScript needs a statement after a `:` - a body of nothing but comment rows is a parse
## error, so "did this body emit anything" has to be asked of the statements, never of the line
## count. An imported sheet is exactly where this bites: a row nobody could spell keeps its original
## words as a comment, and an event whose every action was such a row would otherwise write a
## headed block with no body at all.
static func _has_statement(lines: PackedStringArray, from_index: int) -> bool:
	for index: int in range(max(from_index, 0), lines.size()):
		var stripped: String = lines[index].strip_edges()
		if not stripped.is_empty() and not stripped.begins_with("#"):
			return true
	return false


## The stub emitted for a function whose body has no rows yet ("published before implemented").
## `pass` only parses for void - a bool/typed function needs a type-correct `return <default>` or the
## whole generated script fails to load, taking every OTHER verb on the sheet down with it.
static func _empty_function_stub(event_function: EventFunction) -> String:
	# A named (custom/engine class) return can't be defaulted structurally - null parses for any
	# object/collection type, so a bodiless helper with a named return still loads.
	if not event_function.return_type_name.strip_edges().is_empty():
		return "\treturn null"
	match event_function.return_type:
		TYPE_NIL:
			return "\tpass"
		TYPE_BOOL:
			return "\treturn false"
		TYPE_INT:
			return "\treturn 0"
		TYPE_FLOAT:
			return "\treturn 0.0"
		TYPE_STRING:
			return "\treturn \"\""
		TYPE_VECTOR2:
			return "\treturn Vector2.ZERO"
		TYPE_VECTOR3:
			return "\treturn Vector3.ZERO"
		_:
			# Variant (TYPE_MAX sentinel) and any other typed return: null is assignable everywhere
			# it parses; exotic value types can refine this case as they join the dialog's list.
			return "\treturn null"


## Builds the typed parameter list for a sheet function (e.g. "amount: int, label: String").
## "-> void" unless the function declares a Variant.Type return (TYPE_NIL = void).
static func _function_return_type_name(event_function: EventFunction) -> String:
	# An explicit type NAME wins - it can express what a Variant.Type can't (custom/engine classes,
	# typed collections), so a lifted `-> HealthPool` helper round-trips verbatim.
	if not event_function.return_type_name.strip_edges().is_empty():
		return event_function.return_type_name.strip_edges()
	if event_function.return_type == TYPE_NIL:
		return "void"
	# TYPE_MAX is the "returns Variant" sentinel (there is no Variant.Type for Variant).
	if event_function.return_type == TYPE_MAX:
		return "Variant"
	return type_string(event_function.return_type)


static func _emit_function_params(event_function: EventFunction) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if not event_function.params.is_empty():
		for param: ACEParam in event_function.params:
			if param == null:
				continue
			var param_id: String = param.id if not param.id.is_empty() else param.name
			if param_id.is_empty():
				continue
			# An EMPTY type is the bare-parameter sentinel; a named one always renders, "Variant"
			# included. Treating "Variant" as bare made an explicit `row: Variant` annotation
			# indistinguishable from no annotation, so a lifted helper re-emitted `row` and failed
			# the whole-file byte-verify - taking every other function in that file down with it.
			var type_name: String = param.type_name
			var rendered: String = param_id if type_name.is_empty() else "%s: %s" % [param_id, type_name]
			# Optional GDScript default argument (`amount: int = 5`) - a dedicated field, NOT the picker
			# pre-fill default_value. GDScript requires defaulted params to be trailing; the function
			# dialog enforces that on author.
			var default_text: String = param.gdscript_default.strip_edges()
			if not default_text.is_empty():
				rendered += " = %s" % default_text
			parts.append(rendered)
	else:
		for param_name: Variant in event_function.parameters:
			var clean_name: String = str(param_name).strip_edges()
			if not clean_name.is_empty():
				parts.append(clean_name)
	return ", ".join(parts)


## The three Inspector section levels, outermost first - the order the headers are written in, and
## the order a variable's section path is built in.
const VARIABLE_SECTION_LEVELS: PackedStringArray = ["category", "group", "subgroup"]


## V2 - the order the declarations are emitted in: the order they were WRITTEN, bucketed only as
## far as the Inspector forces. `@export_group` applies to every property after it and no line
## closes one, so a section's variables must emit CONTIGUOUSLY and the sectionless ones must come
## first, or a plain variable written after a grouped one is swallowed into that group's fold. So a
## variable sorts by WHERE ITS SECTION FIRST APPEARED (category, then group, then subgroup; "in no
## section at this level" always ranks first) and, inside one section, by the order it was written
## in. A sheet with no Inspector sections therefore emits exactly as authored, which is what lets a
## drag-reorder and Sort A-Z reach the file instead of stopping at the canvas.
##
## Public because it is the ONE answer to "which variable comes first": the Inspector Designer
## previews the properties in this order too, and a preview in a different order is a lie.
static func variable_emit_order(variables: Dictionary) -> Array:
	var ranks: Dictionary = {}
	var sort_keys: Dictionary = {}
	var author_index: int = 0
	for key: Variant in variables.keys():
		var descriptor: Variant = variables[key]
		var exported: bool = descriptor is Dictionary and bool(descriptor.get("exported", true))
		var attributes: Dictionary = descriptor.get("attributes") if (descriptor is Dictionary and descriptor.get("attributes") is Dictionary) else {}
		var path: String = ""
		var section_key: String = ""
		for level: String in VARIABLE_SECTION_LEVELS:
			var part: String = str(attributes.get(level, "")).strip_edges() if exported else ""
			path += "%s" % part
			section_key += "%04d" % _section_rank(ranks, path, part)
		sort_keys[key] = "%s%06d" % [section_key, author_index]
		author_index += 1
	var order: Array = variables.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(sort_keys[a]) < str(sort_keys[b]))
	return order


## Where one section level ranks: 0 for "in none at this level", which must emit before the sections
## themselves, and otherwise the position that section was first written at. `path` is the whole
## nesting path, so the same group name under two categories ranks as two sections.
static func _section_rank(ranks: Dictionary, path: String, leaf: String) -> int:
	if leaf.is_empty():
		return 0
	if not ranks.has(path):
		ranks[path] = ranks.size() + 1
	return int(ranks[path])


## Emits `@export var` lines from the sheet variables dictionary.
static func _emit_variables(variables: Dictionary, warnings: Array = [], function_names: Dictionary = {}) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	# Author order, with each Inspector section kept contiguous - the @export_group /
	# @export_subgroup / @export_category header is then written ONCE per section (deduped below
	# on change) instead of before every variable, which is what makes the Inspector collapse into
	# clean folds rather than one section per var.
	var keys: Array = variable_emit_order(variables)
	var last_category: String = ""
	var last_group: String = ""
	var last_subgroup: String = ""
	# Tier 2 conditions (Show If / Lock Unless) aggregate into ONE generated
	# _validate_property below, in variable order - canonical shape, dialog-edited.
	var property_conditions: Array = []

	for key: Variant in keys:
		var var_name: String = str(key)
		var descriptor: Variant = variables[key]
		if descriptor is Dictionary:
			var type_name: String = str(descriptor.get("type", "Variant"))
			var default_value: Variant = descriptor.get("default", "null")
			var exported: bool = bool(descriptor.get("exported", true))
			var combo_options: PackedStringArray = PackedStringArray(descriptor.get("options", []))
			# Inspector attributes (Tier 1):
			# canonical order is tooltip doc-comment, group, then the export line. The
			# doc comment is Godot's native Inspector tooltip.
			var attributes: Dictionary = descriptor.get("attributes") if descriptor.get("attributes") is Dictionary else {}
			if exported:
				for decor_line: String in _decor_prefix_lines(attributes):
					lines.append(decor_line)
			# The variable's description doubles as its Inspector tooltip (Godot's `##` doc-comment
			# convention): an explicit "tooltip" attribute wins, else the plain description field is
			# used - so a comment typed on a variable becomes the property's Inspector description
			# automatically. Newlines collapse to spaces (a bare second line would break the `##` block).
			var tooltip_text: String = str(attributes.get("tooltip", "")).strip_edges()
			if tooltip_text.is_empty():
				tooltip_text = str(descriptor.get("description", "")).strip_edges()
			if exported and not tooltip_text.is_empty():
				lines.append("## %s" % tooltip_text.replace("\n", " "))
			# Section headers, emitted only when they CHANGE from the previous exported variable
			# (the sort clustered same-section vars together), so each header lands ONCE and the
			# Inspector shows one fold per group instead of a header per var. A category is the
			# heaviest divider (its own band); it precedes the group exactly as Godot applies them.
			# Entering a new category or group resets the nested trackers so a repeated subgroup
			# name under a different parent still re-emits.
			if exported:
				var this_category: String = str(attributes.get("category", "")).strip_edges()
				var this_group: String = str(attributes.get("group", "")).strip_edges()
				var this_subgroup: String = str(attributes.get("subgroup", "")).strip_edges()
				if this_category != last_category:
					if not this_category.is_empty():
						lines.append("@export_category(\"%s\")" % this_category)
					last_category = this_category
					last_group = ""
					last_subgroup = ""
				if this_group != last_group:
					if not this_group.is_empty():
						lines.append("@export_group(\"%s\")" % this_group)
					last_group = this_group
					last_subgroup = ""
				# Nested Inspector grouping: @export_subgroup follows the group and nests under it.
				if this_subgroup != last_subgroup:
					if not this_subgroup.is_empty():
						lines.append("@export_subgroup(\"%s\")" % this_subgroup)
					last_subgroup = this_subgroup
			if exported and type_name == "String" and not combo_options.is_empty():
				for unsupported_key: String in ["clamp", "on_changed", "read_only", "show_if", "lock_unless", "drawer"]:
					if attributes.has(unsupported_key):
						warnings.append("Variable \"%s\": combo variables don't support the %s attribute yet - ignored." % [var_name, unsupported_key])
				lines.append("%s var %s: String = %s" % [_export_enum_prefix(combo_options), var_name, _to_code_literal(default_value)])
				continue
			var export_prefix: String = "@export " if exported else ""
			# Structured hint families (range + its modifier tail / flags / layers / file /
			# node path / int-enum / storage): one canonical builder shared with the
			# tree-variable path, so both emit byte-identical shapes.
			var structured_prefix: String = _structured_hint_prefix(attributes, type_name) if exported else ""
			if not structured_prefix.is_empty():
				export_prefix = structured_prefix
			elif exported and bool(attributes.get("multiline", false)) and type_name == "String":
				export_prefix = "@export_multiline "
			elif exported and bool(attributes.get("no_alpha", false)) and type_name == "Color":
				export_prefix = "@export_color_no_alpha "
			elif exported and bool(attributes.get("exp_easing", false)) and type_name == "float":
				export_prefix = "@export_exp_easing "
			elif exported and type_name == "String" and not str(attributes.get("placeholder", "")).strip_edges().is_empty() and not str(attributes.get("placeholder", "")).contains("\""):
				export_prefix = "@export_placeholder(\"%s\") " % str(attributes.get("placeholder")).strip_edges()
			# Tier 3 drawers: a marker rides an @export_custom hint string; without the editor plugin the
			# property degrades to a plain field (parity preserved). One helper drives both var paths.
			if exported:
				var drawer_prefix: String = _drawer_export_prefix(attributes, type_name)
				if not drawer_prefix.is_empty():
					export_prefix = drawer_prefix
			# Read-only wins over range/multiline/drawers (a locked field needs no slider).
			if exported and bool(attributes.get("read_only", false)):
				export_prefix = "@export_custom(PROPERTY_HINT_NONE, \"\", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY) "
			# Tier 2 setters: Clamp (needs Range + numeric) and/or On Changed (a sheet
			# function called after assignment). Canonical multi-line shape.
			var on_changed: String = str(attributes.get("on_changed", "")).strip_edges() if exported else ""
			var clamp_enabled: bool = exported and bool(attributes.get("clamp", false)) and attributes.get("range") is Dictionary and (type_name == "int" or type_name == "float")
			# Warn on typos even when the sheet has no functions at all (the empty-dict
			# guard used to silently skip exactly the case most likely to be a mistake).
			if not on_changed.is_empty() and not function_names.has(on_changed):
				warnings.append("Variable \"%s\": On Changed targets unknown function \"%s\" - check the spelling." % [var_name, on_changed])
			if not on_changed.is_empty() or clamp_enabled:
				lines.append("%svar %s: %s = %s:" % [export_prefix, var_name, type_name, _to_code_literal(default_value)])
				lines.append("\tset(value):")
				if clamp_enabled:
					var clamp_range: Dictionary = attributes.get("range")
					var clamp_call: String = "clampi" if type_name == "int" else "clampf"
					lines.append("\t\t%s = %s(value, %s, %s)" % [var_name, clamp_call, str(clamp_range.get("min", "0")), str(clamp_range.get("max", "100"))])
				else:
					lines.append("\t\t%s = value" % var_name)
				if not on_changed.is_empty():
					lines.append("\t\t%s()" % on_changed)
			else:
				lines.append("%svar %s: %s = %s" % [export_prefix, var_name, type_name, _to_code_literal(default_value)])
			for condition_key: String in ["show_if", "lock_unless"]:
				var condition_predicate: String = str(attributes.get(condition_key, "")).strip_edges()
				if exported and not condition_predicate.is_empty():
					if not variables.has(condition_predicate):
						warnings.append("Variable \"%s\": %s targets unknown variable \"%s\" - check the spelling." % [var_name, condition_key, condition_predicate])
					property_conditions.append({"name": var_name, "predicate": condition_predicate, "kind": condition_key})
		else:
			lines.append("@export var %s: Variant = %s" % [var_name, _to_code_literal(descriptor)])

	if not property_conditions.is_empty():
		lines.append("")
		lines.append("## Inspector conditions (Show If / Lock Unless) — generated; edit via the Variable dialog.")
		lines.append("func _validate_property(property: Dictionary) -> void:")
		for condition: Dictionary in property_conditions:
			lines.append("\tif str(property.name) == \"%s\" and not bool(%s):" % [str(condition.get("name")), str(condition.get("predicate"))])
			if str(condition.get("kind")) == "show_if":
				lines.append("\t\tproperty.usage &= ~PROPERTY_USAGE_EDITOR")
			else:
				lines.append("\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY")

	return lines


## Recursively gathers tree-placed GDScript blocks from the top level and groups (sub-event
## raw blocks stay deferred until sub-events compile).
## Canonical single-line enum emission ("" when unnamed/empty/disabled). The importer's
## verify-lift depends on this exact form - change it only with a lifter update.
## The throttled live-values SEND block (shared by both _process emission sites): builds the
## frame from the sheet's baked variable pairs, then asks each CHILD node implementing
## `debugger_properties() -> Dictionary` for its live section - the behavior-debugger seam
## (the live debugger-properties idea other event-sheet editors expose). Keys arrive namespaced
## "ChildName.key" and the Live Values panel groups them per behavior. Plain duck-typed GDScript: a
## pack opts in by defining the method, with zero plugin coupling (parity covenant intact).
## True when the script being emitted already defines `_unhandled_input`, so the replay recorder's
## receiver must stand aside rather than define it a second time.
static func _handles_unhandled_input(lines: PackedStringArray) -> bool:
	for line: String in lines:
		if line.begins_with("func _unhandled_input("):
			return true
	return false


static func _emit_live_values_send(lines: PackedStringArray) -> void:
	lines.append("\t\tvar __live_frame: Array = [%s]" % _live_values_payload)
	lines.append("\t\tfor __live_child in get_children():")
	lines.append("\t\t\tif __live_child.has_method(\"debugger_properties\"):")
	lines.append("\t\t\t\tvar __live_props: Dictionary = __live_child.debugger_properties()")
	lines.append("\t\t\t\tfor __live_key in __live_props:")
	lines.append("\t\t\t\t\t__live_frame.append(str(__live_child.name) + \".\" + str(__live_key))")
	lines.append("\t\t\t\t\t__live_frame.append(__live_props[__live_key])")
	lines.append("\t\tEngineDebugger.send_message(\"eventsheets:live_values\", __live_frame)")


## Any of the sheet-debug switches arms the runtime-error reporter: an error matters to the
## strip whenever the reader is debugging, whichever switch they reached for first.
static func _wants_error_reporter(sheet: EventSheetResource) -> bool:
	return sheet.emit_live_values or sheet.emit_event_trace or sheet.emit_breakpoints


## The _ready arming for the runtime-error reporter. The static `armed` guard keeps a scene with
## several instances of the same debug sheet from registering several loggers (every logger hears
## every error, so duplicates would say each failure that many times).
static func _emit_error_reporter_arming(lines: PackedStringArray) -> void:
	lines.append("\tif EngineDebugger.is_active() and not __EventSheetsErrorReporter.armed:")
	lines.append("\t\t__EventSheetsErrorReporter.armed = true")
	lines.append("\t\tOS.add_logger(__EventSheetsErrorReporter.new())")


static func _emit_enum_line(enum_row: EnumRow) -> String:
	# Single-line convenience (lint scaffolds, tests); multi-line rows join with newlines.
	return "
".join(_emit_enum_lines(enum_row))


static func _emit_enum_lines(enum_row: EnumRow) -> PackedStringArray:
	# EnumRow is a registered RESOURCE kind on the Custom Block API - the compiler actively
	# dispatches the built-in through the same emit contract pack kinds use. One line for the
	# classic form, a whole block for a multiline enum (one member per line).
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(enum_row)
	if kind == null:
		return PackedStringArray()
	return kind.emit_lines(enum_row)


## Canonical single-line signal emission ("" when unnamed/disabled). The importer's
## verify-lift depends on this exact form.
## Class description as `## …` doc lines (one per source line; a blank line emits a bare `##`),
## or empty when unset. Recovered by the importer right after `extends`, so it round-trips.
static func _class_description_lines(sheet: EventSheetResource) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if sheet == null or sheet.class_description.strip_edges().is_empty():
		return out
	for line: String in sheet.class_description.split("\n"):
		out.append("##" if line.is_empty() else "## %s" % line)
	return out


static func _emit_signal_line(signal_row: SignalRow) -> String:
	# SignalRow is a registered RESOURCE kind on the Custom Block API - like enums, the
	# built-in's declaration contract dispatches through the registry.
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(signal_row)
	if kind == null:
		return ""
	var emitted: PackedStringArray = kind.emit_lines(signal_row)
	return "" if emitted.is_empty() else emitted[0]


## Trigger-ACE annotation lines emitted ABOVE a trigger SignalRow's `signal` declaration, so the
## signal publishes as a trigger ACE (a code-free alternative to a hand-written @ace_trigger block).
## Empty for a plain signal - byte-identical to before, so existing signals never change.
static func _emit_signal_annotations(signal_row: SignalRow) -> PackedStringArray:
	var annotations: PackedStringArray = PackedStringArray()
	if signal_row == null or not signal_row.enabled or not signal_row.trigger:
		return annotations
	# The prose leads, because a `##` doc comment above a member IS its description to the
	# analyzer - so the picker shows a sentence under the trigger's name instead of nothing.
	# Emitted one `##` line per stored line, which is exactly what the importer absorbed.
	if not signal_row.description.is_empty():
		for doc_line: String in signal_row.description.split("\n"):
			annotations.append("##" if doc_line.is_empty() else "## %s" % doc_line)
	annotations.append("## @ace_trigger")
	if not signal_row.ace_name.strip_edges().is_empty():
		annotations.append("## @ace_name(\"%s\")" % signal_row.ace_name.strip_edges())
	if not signal_row.ace_category.strip_edges().is_empty():
		annotations.append("## @ace_category(\"%s\")" % signal_row.ace_category.strip_edges())
	return annotations


## Recursively gathers SignalRow rows (top level and inside groups).
static func _collect_signal_rows(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is SignalRow:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_signal_rows(group.child_rows(), into)


## True when the sheet already declares a signal by this name as a first-class row, so a
## compiler-supplied declaration (a Test sheet's test_started) can stand down instead of
## emitting a duplicate `signal` line, which would not parse.
## Only an ENABLED row declares anything: a disabled SignalRow emits no `signal` line, so treating
## it as the declaration would suppress the compiler's own and leave a Test sheet connecting to a
## signal that exists nowhere.
static func _declares_signal_named(signal_rows: Array, wanted: String) -> bool:
	for entry: Variant in signal_rows:
		if entry is SignalRow and (entry as SignalRow).enabled and (entry as SignalRow).signal_name.strip_edges() == wanted:
			return true
	return false


## Recursively gathers EnumRow rows (top level and inside groups).
static func _collect_enum_rows(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is EnumRow:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_enum_rows(group.child_rows(), into)


## Gathers Custom Block API rows (registered non-ACE kinds) from the event tree, group-recursive
## like enums/signals so a block inside a group still emits.
static func _collect_custom_blocks(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is CustomBlockRow:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_custom_blocks(group.child_rows(), into)


## Gathers stateful-condition member declarations (deduped) from the event tree.
## Gathers group-local variables: [{group: name, locals: [LocalVariable…]}] in order.
static func _collect_group_locals(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			var locals: Array = []
			for local_entry: Variant in group.local_variables:
				if local_entry is LocalVariable:
					locals.append(local_entry)
			if not locals.is_empty():
				into.append({"group": group.group_name if not group.group_name.is_empty() else group.name, "locals": locals})
			_collect_group_locals(group.child_rows(), into)


## The rows one function's body is made of, across the `events` / `rows` alias pair. Every pass that
## walks function bodies asks here, so a pass cannot walk one spelling and miss the other.
static func _function_body_rows(event_function: EventFunction) -> Array:
	if event_function == null:
		return []
	return event_function.events if not event_function.events.is_empty() else event_function.rows


## V4. Every Static local a sheet declares: the ones under its own events AND the ones under events
## inside its functions - a function body is ordinary selectable rows, so a local can be written on
## one. Both hoisting paths ask here: _rewrite_static_local_uses runs over function bodies too, so a
## sheet collected from `events` alone rewrote uses onto a member nothing declared, and the emitted
## file did not parse. One `seen` set across both, because both hoist into the same class.
static func _collect_sheet_static_locals(events: Array, functions: Array, warnings: Array = []) -> Array:
	var static_locals: Array = []
	var seen: Dictionary = {}
	_collect_static_locals(events, static_locals, warnings, seen)
	for function_entry: Variant in functions:
		if function_entry is EventFunction:
			_collect_static_locals(_function_body_rows(function_entry as EventFunction), static_locals, warnings, seen)
	return static_locals


## V4. Gathers every Static local declared under an event, in reading order (nested events included),
## de-duplicated by the member each would write: two events cannot both declare `hits_taken`, because
## both hoist to `var _hits_taken`. The second one is a warning, not an error - it still compiles, it
## just shares the first one's member, which is what the reader has to be told.
static func _collect_static_locals(entries: Array, into: Array, warnings: Array = [], seen: Dictionary = {}) -> void:
	for entry: Variant in entries:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_static_locals(group.child_rows(), into, warnings, seen)
		elif entry is EventRow:
			var event_row: EventRow = entry as EventRow
			for local_entry: Variant in event_row.local_variables:
				if not (local_entry is LocalVariable) or not (local_entry as LocalVariable).static_local:
					continue
				var local_var: LocalVariable = local_entry as LocalVariable
				if local_var.name.strip_edges().is_empty():
					continue
				var member: String = LocalVariable.static_local_member(local_var.name)
				if seen.has(member):
					warnings.append("Static local '%s' is declared on more than one event - they share the one %s member." % [local_var.name, member])
					continue
				seen[member] = true
				into.append(local_var)
			_collect_static_locals(event_row.sub_events, into, warnings, seen)


## Early pass for the flag members of runtime-toggleable groups (nested included).
static func _collect_runtime_group_members(rows: Array) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			if group.enabled and group.runtime_toggleable:
				# Must mirror _flatten_trigger_rows' guard exactly (same guard_token) or the
				# declared member and the guard reads drift apart.
				var guard_name: String = "__group_%s_active" % guard_token(group.group_name)
				var already_known: bool = false
				for member_pair: Array in _runtime_group_members:
					if str(member_pair[0]) == guard_name:
						already_known = true
				if not already_known:
					_runtime_group_members.append([guard_name, group.enabled])
			if group.enabled:
				_collect_runtime_group_members(group.child_rows())


static func _collect_stateful_members(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is EventRow:
			var event_row: EventRow = entry as EventRow
			for condition: Variant in event_row.conditions:
				if condition is ACECondition and (condition as ACECondition).enabled and not (condition as ACECondition).member_declaration.is_empty():
					if not into.has((condition as ACECondition).member_declaration):
						into.append((condition as ACECondition).member_declaration)
			# Each Budgeted For Each pick needs a persistent cursor + snapshot so it can resume next frame.
			# The eligibility test MUST mirror _emit_pick_filters' final is_budgeted (after its fallbacks),
			# and the uid (event_uid + raw pick index) must match, or the loop and its members won't line up.
			var pick_idx: int = -1
			for filter_entry: Variant in event_row.pick_filters:
				pick_idx += 1
				if not (filter_entry is PickFilter) or not (filter_entry as PickFilter).enabled:
					continue
				var pick: PickFilter = filter_entry as PickFilter
				if (pick.frame_spread_count > 0 or pick.frame_spread_budget_ms > 0.0) \
						and pick.collection_kind != PickFilter.CollectionKind.WHILE \
						and pick.collection_kind != PickFilter.CollectionKind.REPEAT \
						and pick.order_by_expression.strip_edges().is_empty() \
						and pick.pick_first_n == 0 \
						and not _pick_collection_expression(pick).is_empty():
					var uid: String = "%s_%d" % [event_row.event_uid, pick_idx]
					for decl: String in ["var __loop_cursor_%s: int = 0" % uid, "var __loop_items_%s: Array = []" % uid]:
						if not into.has(decl):
							into.append(decl)
			_collect_stateful_members(event_row.sub_events, into)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_stateful_members(group.child_rows(), into)


## Substitutes {param} tokens with the row's param values (plain str(), like codegen).
static func _substitute_params(template: String, params: Dictionary) -> String:
	var output: String = template
	for key: Variant in params.keys():
		output = output.replace("{%s}" % str(key), str(params[key]))
	return output


static func _collect_class_level_raw_rows(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is RawCodeRow:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_class_level_raw_rows(group.child_rows(), into)


## Recursively gathers tree-placed LocalVariable rows from the event tree (top level, groups
## and sub-events) so they can be emitted as class-level declarations.
static func _collect_tree_variables(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is LocalVariable:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_tree_variables(group.child_rows(), into)
		elif entry is EventRow:
			_collect_tree_variables((entry as EventRow).sub_events, into)


## Walks every trigger / condition / action and adds ONE compile warning per distinct deprecated ACE.
## Deprecated ACEs still compile byte-for-byte (the covenant), so this is a nudge toward the replacement,
## not a build break. `seen` dedupes so a deprecated ACE used ten times warns once.
static func _collect_deprecated_aces(entries: Array, warnings: Array, seen: Dictionary) -> void:
	for entry: Variant in entries:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_deprecated_aces(group.child_rows(), warnings, seen)
		elif entry is EventRow:
			var row: EventRow = entry as EventRow
			_warn_if_deprecated(row.trigger_provider_id, row.trigger_id, warnings, seen)
			for condition: Variant in row.conditions:
				if condition is ACECondition:
					_warn_if_deprecated((condition as ACECondition).provider_id, (condition as ACECondition).ace_id, warnings, seen)
			for action: Variant in row.actions:
				if action is ACEAction:
					_warn_if_deprecated((action as ACEAction).provider_id, (action as ACEAction).ace_id, warnings, seen)
			_collect_deprecated_aces(row.sub_events, warnings, seen)


## Appends a deprecation warning for one ACE if its descriptor is marked deprecated (and not already seen).
static func _warn_if_deprecated(provider_id: String, ace_id: String, warnings: Array, seen: Dictionary) -> void:
	if provider_id.strip_edges().is_empty() or ace_id.strip_edges().is_empty():
		return
	var key: String = "%s::%s" % [provider_id, ace_id]
	if seen.has(key):
		return
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor == null or not descriptor.is_deprecated:
		return
	seen[key] = true
	var detail: String = descriptor.deprecation_message.strip_edges()
	if not descriptor.replacement_ace_id.strip_edges().is_empty():
		detail += (" " if not detail.is_empty() else "") + "Use %s instead." % descriptor.replacement_ace_id.strip_edges()
	var message: String = "%s (%s) is deprecated." % [descriptor.get_list_name(), key]
	if not detail.is_empty():
		message += " " + detail
	warnings.append(message)


## The canonical @export prefix for the structured inspector attributes beyond the original
## tier set: range WITH its modifier tail, checkbox flags, the seven layer-mask grids,
## file/folder pickers, node-path type filters, int-backed enums, and storage. One builder
## drives the dict-variable path and the tree-variable path, so both emit byte-identical
## shapes and the importer's verify-gated extraction recognizes exactly one spelling.
## Returns "" when none of these attributes apply (callers fall through to the older tiers).
static func _structured_hint_prefix(attributes: Dictionary, type_name: String) -> String:
	if bool(attributes.get("storage", false)):
		return "@export_storage "
	# PropertyHints with no dedicated annotation ride @export_custom as named presets - the
	# dialog says "Password field", the file says exactly this.
	match str(attributes.get("custom_preset", "")):
		"password":
			if type_name == "String":
				return "@export_custom(PROPERTY_HINT_PASSWORD, \"\") "
		"expression":
			if type_name == "String":
				return "@export_custom(PROPERTY_HINT_EXPRESSION, \"\") "
		"link":
			if type_name in ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i"]:
				return "@export_custom(PROPERTY_HINT_LINK, \"\") "
	# A String that OFFERS choices but accepts free text: the suggestion dropdown. Choices ride the
	# hint string; anything typed still sticks (unlike @export_enum, which locks the set). Values
	# with quotes/commas are skipped - they cannot survive the comma-joined hint.
	if type_name == "String" and attributes.get("suggestions") is Array and not (attributes.get("suggestions") as Array).is_empty():
		var suggestion_values: PackedStringArray = PackedStringArray()
		for suggestion: Variant in attributes.get("suggestions"):
			var cleaned: String = str(suggestion).strip_edges()
			if not cleaned.is_empty() and not cleaned.contains("\"") and not cleaned.contains(","):
				suggestion_values.append(cleaned)
		if not suggestion_values.is_empty():
			return "@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, \"%s\") " % ",".join(suggestion_values)
	# Exp-easing WITH flags (plain exp_easing keeps its original branch, byte-unchanged).
	if type_name == "float" and bool(attributes.get("exp_easing", false)) and attributes.get("exp_easing_flags") is Array and not (attributes.get("exp_easing_flags") as Array).is_empty():
		var easing_flags: PackedStringArray = PackedStringArray()
		for easing_flag: Variant in attributes.get("exp_easing_flags"):
			if str(easing_flag) in ["attenuation", "positive_only"]:
				easing_flags.append("\"%s\"" % str(easing_flag))
		if not easing_flags.is_empty():
			return "@export_exp_easing(%s) " % ", ".join(easing_flags)
	var numeric: bool = type_name == "int" or type_name == "float"
	if attributes.get("range") is Dictionary and numeric:
		var range_spec: Dictionary = attributes.get("range")
		var arguments: PackedStringArray = PackedStringArray([
			str(range_spec.get("min", "0")), str(range_spec.get("max", "100")), str(range_spec.get("step", "1")),
		])
		# Fixed modifier order keeps the byte gate deterministic; hand-written other orders
		# stay verbatim hints (graceful degradation, never corruption).
		if bool(range_spec.get("or_greater", false)):
			arguments.append("\"or_greater\"")
		if bool(range_spec.get("or_less", false)):
			arguments.append("\"or_less\"")
		if bool(range_spec.get("exp", false)):
			arguments.append("\"exp\"")
		if bool(range_spec.get("hide_slider", false)):
			arguments.append("\"hide_slider\"")
		var angle: String = str(range_spec.get("angle", "")).strip_edges()
		if angle == "radians_as_degrees" or angle == "degrees":
			arguments.append("\"%s\"" % angle)
		var suffix: String = str(range_spec.get("suffix", "")).strip_edges()
		if not suffix.is_empty() and not suffix.contains("\""):
			arguments.append("\"suffix:%s\"" % suffix)
		return "@export_range(%s) " % ", ".join(arguments)
	if type_name == "int" and attributes.get("flags") is Array and not (attributes.get("flags") as Array).is_empty():
		return "@export_flags(%s) " % ", ".join(_labeled_value_arguments(attributes.get("flags")))
	if type_name == "int" and attributes.get("enum_values") is Array and not (attributes.get("enum_values") as Array).is_empty():
		return "@export_enum(%s) " % ", ".join(_labeled_value_arguments(attributes.get("enum_values")))
	if type_name == "int" and not str(attributes.get("layers", "")).strip_edges().is_empty():
		var layer_kind: String = str(attributes.get("layers")).strip_edges()
		if layer_kind in ["2d_physics", "2d_render", "2d_navigation", "3d_physics", "3d_render", "3d_navigation", "avoidance"]:
			return "@export_flags_%s " % layer_kind
	if type_name == "String" and attributes.get("file") is Dictionary:
		var file_spec: Dictionary = attributes.get("file")
		var global_scope: String = "global_" if bool(file_spec.get("global", false)) else ""
		if str(file_spec.get("mode", "file")) == "dir":
			return "@export_%sdir " % global_scope
		var filters: PackedStringArray = PackedStringArray()
		for filter_entry: Variant in file_spec.get("filters", []):
			var filter_text: String = str(filter_entry).strip_edges()
			if not filter_text.is_empty() and not filter_text.contains("\""):
				filters.append("\"%s\"" % filter_text)
		if filters.is_empty():
			return "@export_%sfile " % global_scope
		return "@export_%sfile(%s) " % [global_scope, ", ".join(filters)]
	if type_name == "NodePath" and attributes.get("node_path_types") is Array and not (attributes.get("node_path_types") as Array).is_empty():
		var type_filters: PackedStringArray = PackedStringArray()
		for filter_type: Variant in attributes.get("node_path_types"):
			var type_text: String = str(filter_type).strip_edges()
			if not type_text.is_empty() and not type_text.contains("\""):
				type_filters.append("\"%s\"" % type_text)
		if not type_filters.is_empty():
			return "@export_node_path(%s) " % ", ".join(type_filters)
	return ""


## Formats [{label, value}] entries for @export_flags / @export_enum: "Fire" or "Fire:1".
## Values are stored as STRINGS and re-emitted verbatim, never re-derived integers, so the
## exact source spelling round-trips.
static func _labeled_value_arguments(entries: Array) -> PackedStringArray:
	var arguments: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var label: String = str((entry as Dictionary).get("label", "")).strip_edges()
		if label.is_empty() or label.contains("\""):
			continue
		var value: String = str((entry as Dictionary).get("value", "")).strip_edges()
		arguments.append("\"%s\"" % label if value.is_empty() else "\"%s:%s\"" % [label, value])
	return arguments


## Emits the class-level declaration for one tree-placed variable (const / @export var / var).
static func _emit_tree_variable_line(local_var: LocalVariable) -> String:
	if local_var == null or local_var.name.strip_edges().is_empty():
		return ""
	# V4. A Static local is written as a local and lives as a member: two lines, the marker that says
	# which row the member belongs to and the member itself. Every other branch below is about how a
	# declaration is spelled; this one is about WHERE the declaration ended up, so it answers first.
	if local_var.static_local:
		return "%s\n%s" % [STATIC_LOCAL_MARKER % local_var.name, static_local_declaration(local_var)]
	# Tier 3 custom-drawer prefix (if any): a structured @export_custom marker, computed once so it can both
	# gate its branch and fill it. Empty for non-drawer vars, so their emission stays byte-unchanged.
	var drawer_prefix: String = ""
	if local_var.exported and local_var.attributes is Dictionary:
		drawer_prefix = _drawer_export_prefix(local_var.attributes, local_var.type_name)
	var var_line: String
	# The inferred-type walrus spelling (`var hp := 100`) re-emits exactly as written - the
	# default is verbatim source text. Wins over every hint branch: a `:=` declaration carries
	# no type to hang a hint on, and the byte gate rejects any other rendering of it.
	if local_var.inferred_type:
		var walrus_prefix: String = ""
		if local_var.onready:
			walrus_prefix = "@onready "
		elif local_var.is_static:
			walrus_prefix = "static "
		elif local_var.exported:
			walrus_prefix = "@export "
		var_line = "%s%s %s := %s" % [walrus_prefix, "const" if local_var.is_constant else "var", local_var.name, str(local_var.default_value)]
	elif local_var.is_constant:
		var_line = "const %s: %s = %s" % [local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]
	# @onready: deferred init (node refs like $Path). The default is a raw EXPRESSION, emitted
	# verbatim (not a quoted literal) so `$Sprite2D` / `get_node(...)` stay code, not strings.
	elif local_var.onready:
		var_line = "@onready var %s: %s = %s" % [local_var.name, local_var.type_name, str(local_var.default_value)]
	# Combo: exported String with options -> @export_enum dropdown in the Inspector.
	elif local_var.exported and local_var.type_name == "String" and not local_var.options.is_empty():
		var_line = "%s var %s: String = %s" % [_export_enum_prefix(local_var.options), local_var.name, _to_code_literal(local_var.default_value)]
	# Tier 3 drawer: a structured @export_custom marker (progress_bar / vector_dial / swatch_row / …), emitted
	# from attributes so it round-trips identically to the dict-var path instead of staying a verbatim hint.
	elif not drawer_prefix.is_empty():
		# Expression defaults re-emit verbatim like the structured branch - this includes the
		# setter-suffixed form ("= 120:" on a clamped var), whose drawer otherwise failed the
		# extraction verify and stranded as a verbatim hint.
		var drawer_default: String = str(local_var.default_value) if local_var.expression_default else _to_code_literal(local_var.default_value)
		var_line = "%svar %s: %s = %s" % [drawer_prefix, local_var.name, local_var.type_name, drawer_default]
	# Structured hint families (range + modifiers / flags / layers / file / node path /
	# int-enum / storage): the shared canonical builder, so tree variables round-trip these
	# as editable attributes instead of verbatim hints.
	elif local_var.exported and local_var.attributes is Dictionary and not _structured_hint_prefix(local_var.attributes, local_var.type_name).is_empty():
		# Expression defaults (NodePath(""), Vector2.ZERO) re-emit verbatim, exactly like the
		# plain-var branch below - a quoted literal would fail the round-trip byte gate.
		var structured_default: String = str(local_var.default_value) if local_var.expression_default else _to_code_literal(local_var.default_value)
		var_line = "%svar %s: %s = %s" % [_structured_hint_prefix(local_var.attributes, local_var.type_name), local_var.name, local_var.type_name, structured_default]
	# Color with the "no alpha" attribute → @export_color_no_alpha (a solid RGB-only swatch in the Inspector).
	# Structured (from attributes) so it round-trips into the dialog tick, not a verbatim hint.
	elif local_var.exported and local_var.attributes is Dictionary and bool((local_var.attributes as Dictionary).get("no_alpha", false)) and local_var.type_name == "Color":
		var_line = "@export_color_no_alpha var %s: %s = %s" % [local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]
	# float "exponential easing" → @export_exp_easing (a curve handle in the Inspector for attenuation values).
	elif local_var.exported and local_var.attributes is Dictionary and bool((local_var.attributes as Dictionary).get("exp_easing", false)) and local_var.type_name == "float":
		var_line = "@export_exp_easing var %s: %s = %s" % [local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]
	# String "placeholder" → @export_placeholder("hint") (grey hint text shown in the empty field).
	elif local_var.exported and local_var.type_name == "String" and local_var.attributes is Dictionary and not str((local_var.attributes as Dictionary).get("placeholder", "")).strip_edges().is_empty() and not str((local_var.attributes as Dictionary).get("placeholder", "")).contains("\""):
		var_line = "@export_placeholder(\"%s\") var %s: %s = %s" % [str((local_var.attributes as Dictionary).get("placeholder")).strip_edges(), local_var.name, local_var.type_name, _to_code_literal(local_var.default_value)]
	# R32. An Inspector button: `@export_tool_button("Bake", "Bake") var bake = _bake`. The one export
	# family emitted WITHOUT a `: Type`, because the value is the function the button calls and Godot's
	# own spelling annotates nothing. The arguments are the author's own, kept verbatim on the
	# attribute, so a one-argument and a two-argument button both re-emit as they were written.
	elif local_var.exported and local_var.attributes is Dictionary \
			and (local_var.attributes as Dictionary).get("tool_button") is Dictionary:
		var button: Dictionary = (local_var.attributes as Dictionary)["tool_button"] as Dictionary
		var_line = "@export_tool_button(%s) var %s = %s" % [
			str(button.get("args", "")), local_var.name, str(local_var.default_value)]
	# Hinted export (@export_range / @export_file / @export_flags / …): the annotation is kept verbatim.
	elif not local_var.export_hint.strip_edges().is_empty():
		var hinted_default: String = str(local_var.default_value) if local_var.expression_default else _to_code_literal(local_var.default_value)
		var_line = "%s var %s: %s = %s" % [local_var.export_hint, local_var.name, local_var.type_name, hinted_default]
	else:
		var export_prefix: String = "static " if local_var.is_static else ("@export " if local_var.exported else "")
		# A bare-expression default (Vector2.ZERO, Color.RED, Type.CONST) emits VERBATIM; a literal
		# goes through _to_code_literal (which quotes strings). This keeps a `= Vector2.ZERO` var a
		# first-class row instead of stranding it as a GDScript block over a quoted `"Vector2.ZERO"`.
		var default_code: String = str(local_var.default_value) if local_var.expression_default else _to_code_literal(local_var.default_value)
		var_line = "%svar %s: %s = %s" % [export_prefix, local_var.name, local_var.type_name, default_code]
	# A property (setter and/or getter body set): suffix the declaration with `:` and emit the accessor
	# blocks beneath it. The bodies are stored verbatim + dedented, so re-indenting them one/two tabs
	# reproduces the source exactly (the lift byte-gate below refuses anything that does not).
	if local_var.has_property_accessors():
		var_line = _append_property_accessors(local_var, var_line)
	# Inspector grouping rides in front, matching the dict-var path (_emit_variables) byte-for-byte so the
	# round-trip lift can absorb it back onto the variable instead of stranding it as a GDScript block.
	return _tree_variable_group_prefix(local_var) + var_line


## V4. The member line a Static local compiles to: `var _hits_taken := 0`. Private (the row is a
## local, so nothing outside its event should reach it) and inferred, because the row already says
## the type in words and the literal carries it. A float whose literal reads as a whole number spells
## the fraction out, or `:=` would infer int and refuse the first fractional assignment.
static func static_local_declaration(local_var: LocalVariable) -> String:
	if local_var == null or local_var.name.strip_edges().is_empty():
		return ""
	var literal: String = str(local_var.default_value) if local_var.expression_default \
		else _to_code_literal(local_var.default_value)
	if local_var.type_name.strip_edges() == "float" and literal.is_valid_int():
		literal = "%s.0" % literal
	# `:=` has nothing to infer from `null` - the resource types (Texture2D, Curve, Gradient) parse
	# their empty default to exactly that, and so does any type left with no initial value. Godot
	# refuses such a script with "Cannot infer the type of 'variable'", which is a silent fault: the
	# compile reports success and the emitted file simply does not parse. So a null spells its type.
	if literal == "null":
		var declared_type: String = local_var.type_name.strip_edges()
		return "var %s: %s = null" % [LocalVariable.static_local_member(local_var.name),
			declared_type if not declared_type.is_empty() else "Variant"]
	return "var %s := %s" % [LocalVariable.static_local_member(local_var.name), literal]


## Appends `set(param):` / `get:` accessor blocks under a property declaration. The declaration gains a
## trailing `:`; each accessor body line is re-indented one tab under its header (two tabs total from the
## var). Canonical order is setter then getter, matching what the property dialog authors and what the lift
## re-emits, so a hand-written variant that differs fails the byte-gate and stays a verbatim block.
static func _append_property_accessors(local_var: LocalVariable, declaration_line: String) -> String:
	var out: PackedStringArray = PackedStringArray([declaration_line + ":"])
	if not local_var.setter_body.strip_edges().is_empty():
		var param: String = local_var.setter_param.strip_edges() if not local_var.setter_param.strip_edges().is_empty() else "value"
		out.append("\tset(%s):" % param)
		for body_line: String in local_var.setter_body.split("\n"):
			out.append("\t\t%s" % body_line)
	if not local_var.getter_body.strip_edges().is_empty():
		out.append("\tget:")
		for body_line: String in local_var.getter_body.split("\n"):
			out.append("\t\t%s" % body_line)
	return "\n".join(out)


## Decodes a table-column enum type token: "enum(circle|ring|rect)" -> ["circle", "ring", "rect"];
## returns [] for any non-enum token (String/int/float/bool or malformed), so callers fall back to
## their plain-type path. The `|` option delimiter is chosen because it avoids every reserved marker
## char ( , = : " ), so the option list survives the column/name/type/marker splits verbatim. Shared by
## the compiler emit, the importer lift, the editor drawer parse, and the variable dialog so all four
## agree on the encoding (a mismatch would silently downgrade an enum column to free text).
## Returns {key, label} pairs - the same shape an ACE param's options use, so one convention covers
## both. A bare entry is its own label, which is what every option shipped before labels existed is.
static func table_enum_options(type_token: String) -> Array:
	var token: String = type_token.strip_edges()
	if not token.begins_with("enum(") or not token.ends_with(")"):
		return []
	var options: Array = []
	for entry: String in token.substr(5, token.length() - 6).split("|"):
		var pair: Dictionary = table_enum_pair(entry)
		if not pair.is_empty():
			options.append(pair)
	return options


## One marker entry -> {key, label}, or {} when it is unusable.
##
## `gte=>= (at least)` labels a choice, so the designer reads ">= (at least)" while the cell stores
## `gte`. The separator is `=` for a reason that makes the whole scheme safe: a bare `=` has ALWAYS
## been rejected inside an option (see _valid_enum_option), so no marker written before labels
## existed can contain one. The pair form is therefore unambiguous against every file already on
## disk, and needs no escape character - which matters, because the obvious escape lead-ins are all
## either legal in options today or fatal inside the double-quoted GDScript literal the marker rides.
## An `=` is a pair separator ONLY when both sides stand on their own. That one condition is what
## lets a comparison operator still be a plain stored value: `<=` tries to split into key `<` and an
## empty label, fails, and falls through to being the bare key `<=`. Without it, declaring
## `enum(==|!=|<|<=|>|>=)` silently kept only `<` and `>`.
static func table_enum_pair(entry: String) -> Dictionary:
	var text: String = entry.strip_edges()
	if text.is_empty():
		return {}
	var split_at: int = text.find("=")
	if split_at > 0:
		var key: String = text.substr(0, split_at).strip_edges()
		var label: String = text.substr(split_at + 1).strip_edges()
		if _valid_enum_option(key) and _valid_enum_label(label):
			return {"key": key, "label": _unescape_marker_label(label)}
	# Not a pair, so the whole entry is the key. It may carry `=` - that is exactly what makes
	# `==`, `<=`, `>=` and `!=` storable - but nothing that would break one of the splits.
	return {"key": text, "label": text} if _valid_enum_key(text) else {}


## The value an option stores in the user's data. Accepts either shape, so an extension that builds
## table_columns by hand with plain strings keeps working.
static func table_enum_key(option: Variant) -> String:
	if option is Dictionary:
		return str((option as Dictionary).get("key", ""))
	return str(option)


## The text an option shows in the dropdown.
static func table_enum_label(option: Variant) -> String:
	if option is Dictionary:
		var pair: Dictionary = option as Dictionary
		return str(pair.get("label", pair.get("key", "")))
	return str(option)


## Encodes an option list into the marker type token: ["circle", "ring"] -> "enum(circle|ring)".
## Accepts plain strings or {key, label} pairs. A label that just repeats its key emits BARE, which
## is what keeps every option shipped today byte-identical (and the pack drift gate at zero).
## Returns "" when no option survives, so the column falls back to a plain String cell.
static func table_enum_type(options: Array) -> String:
	var clean: PackedStringArray = PackedStringArray()
	for option: Variant in options:
		var entry: String = table_enum_entry(option)
		if not entry.is_empty():
			clean.append(entry)
	if clean.is_empty():
		return ""
	return "enum(%s)" % "|".join(clean)


## One option -> its marker entry, or "" when the key cannot be written at all.
##
## The last guard is the load-bearing one: an entry is only emitted if reading it back yields the
## key we started from. That makes the round-trip self-checking rather than something to reason
## about case by case - a key like `a=b` would read back as the pair {a, b}, so it is refused
## instead of being written as something that means something else on the way in.
static func table_enum_entry(option: Variant) -> String:
	var key: String = table_enum_key(option).strip_edges()
	if not _valid_enum_key(key):
		return ""
	var label: String = table_enum_label(option).strip_edges()
	# A key carrying `=` cannot also carry a label (the split would land in the wrong place), so it
	# keeps its value and loses the prettier wording rather than losing the choice entirely.
	var bare: bool = label.is_empty() or label == key or key.contains("=") or not _valid_enum_label(label)
	if bare:
		return key if str(table_enum_pair(key).get("key", "")) == key else ""
	return "%s=%s" % [key, _escape_marker_label(label)]


## A bare KEY may carry `=`, because table_enum_pair only treats one as a separator when both sides
## stand on their own - so `<=` and `==` read back whole. Everything else that would break a split
## is still refused, and table_enum_entry re-reads what it is about to write, so a key that WOULD be
## mistaken for a pair is dropped rather than written.
static func _valid_enum_key(key: String) -> bool:
	var cleaned: String = key.strip_edges()
	if cleaned.is_empty():
		return false
	return not (cleaned.contains(",") or cleaned.contains(":") or cleaned.contains("\"") or cleaned.contains("|") or cleaned.contains("(") or cleaned.contains(")"))


## The stricter rule for the LEFT side of a labeled pair: a key that carries `=` cannot also carry a
## label, because the split would land in the wrong place. Also the historical rule for an option,
## which is what makes the pair form unambiguous against every marker written before labels existed.
static func _valid_enum_option(option: String) -> bool:
	var cleaned: String = option.strip_edges()
	if cleaned.is_empty():
		return false
	return not (cleaned.contains(",") or cleaned.contains("=") or cleaned.contains(":") or cleaned.contains("\"") or cleaned.contains("|") or cleaned.contains("(") or cleaned.contains(")"))


## The four characters a LABEL cannot carry literally, and the sequence each becomes. Every one is a
## split the marker depends on: `,` splits columns, `|` splits options, `:` splits the marker
## segments, and `"` would terminate the GDScript string literal the whole marker lives inside.
##
## `=` and parentheses are absent on purpose. A label needs both - ">= (at least)" is the motivating
## case - and both are already safe: the pair splits on the FIRST `=`, and the enum wrapper is
## stripped by index arithmetic that only ever consumes the final `)`.
##
## Escaping is applied to LABELS ONLY. A key is left exactly as it was, which is what keeps `<=` and
## `==` emitting as themselves - escaping `=` in keys would rewrite every operator column on disk.
const MARKER_ESCAPES: Dictionary = {",": "~2C", "|": "~7C", ":": "~3A", "\"": "~22"}


## The tilde is never itself escaped, so `~` stays an ordinary character and the sequence list is
## closed: exactly four spellings decode, everything else is literal text. That is what makes
## decode(encode(x)) == x AND encode(decode(t)) == t hold together - if the lead-in were escapable,
## two spellings would collapse to one value and the importer's byte gate would turn a working grid
## into a verbatim block on the next open.
static func _escape_marker_label(label: String) -> String:
	var output: String = label
	for literal: String in MARKER_ESCAPES:
		output = output.replace(literal, str(MARKER_ESCAPES[literal]))
	return output


static func _unescape_marker_label(label: String) -> String:
	var output: String = label
	for literal: String in MARKER_ESCAPES:
		output = output.replace(str(MARKER_ESCAPES[literal]), literal)
	return output


## With escaping in place a label only has to be non-empty - anything it carries is representable.
static func _valid_enum_label(label: String) -> bool:
	return not label.strip_edges().is_empty()


## Tier 3 custom-drawer @export_custom prefix. The `eventsheet:<drawer>`
## marker rides an @export_custom hint string; the editor's EventSheetAttributeDrawers plugin recognises it
## and swaps in a richer control, while WITHOUT the plugin (or in an exported game) the property degrades to
## a plain field - the parity covenant is untouched. Returns "" when there's no drawer or the var type can't
## host it (so emission is unchanged). One helper drives BOTH _emit_variables (dict) and _emit_tree_variable_
## line (tree) so a drawer round-trips identically on either path. progress_bar/vector_dial read their numeric
## bounds from attributes.range; the other drawers carry no config.
static func _drawer_export_prefix(attributes: Dictionary, type_name: String) -> String:
	var drawer: String = str(attributes.get("drawer", "")).strip_edges()
	if drawer.is_empty():
		return ""
	var bounds: Dictionary = attributes.get("range") if attributes.get("range") is Dictionary else {}
	var marker: String = ""
	match drawer:
		"progress_bar":
			if type_name != "int" and type_name != "float":
				return ""
			marker = "eventsheet:progress_bar:%s:%s" % [str(bounds.get("min", "0")), str(bounds.get("max", "100"))]
		"min_max":
			# Vector2 as a range: x = low end, y = high end; the bounds are the slider's track.
			if type_name != "Vector2":
				return ""
			marker = "eventsheet:min_max:%s:%s" % [str(bounds.get("min", "0")), str(bounds.get("max", "100"))]
		"toggle_row":
			# A String's fixed choices as one row of toggle buttons - the choices ride the marker
			# (INSTEAD of @export_enum: one annotation slot). Without the plugin the field degrades
			# to plain text; the compiled game never depended on the dropdown either way.
			if type_name != "String" or not (attributes.get("toggle_options") is Array):
				return ""
			var toggle_values: PackedStringArray = PackedStringArray()
			for toggle_option: Variant in attributes.get("toggle_options"):
				var cleaned_option: String = str(toggle_option).strip_edges()
				if not cleaned_option.is_empty() and not cleaned_option.contains(",") and not cleaned_option.contains(":") and not cleaned_option.contains("\""):
					toggle_values.append(cleaned_option)
			if toggle_values.is_empty():
				return ""
			marker = "eventsheet:toggle_row:%s" % ",".join(toggle_values)
		"table":
			# Array of Dictionary rows edited as a grid; the column schema (name=type pairs) rides
			# the marker. Names that can't survive the joined form (separators, quotes) are skipped.
			# Both the untyped list and its typed form (Array[Dictionary]) host the grid - a typed row
			# list is the same data with a compile-time guarantee, and reaches the drawer as TYPE_ARRAY
			# either way. A list typed to a NON-Dictionary element (Array[int]) cannot hold rows, so it
			# still degrades to a plain field rather than emitting a grid it could never fill.
			if not (type_name in ["Array", "Array[Dictionary]"]) or not (attributes.get("table_columns") is Array):
				return ""
			var column_pairs: PackedStringArray = PackedStringArray()
			for column: Variant in attributes.get("table_columns"):
				if not (column is Dictionary):
					continue
				var column_name: String = str((column as Dictionary).get("name", "")).strip_edges()
				var column_type: String = str((column as Dictionary).get("type", "String")).strip_edges()
				if column_name.is_empty() or column_name.contains(",") or column_name.contains("=") or column_name.contains(":") or column_name.contains("\""):
					continue
				if column_type == "enum":
					# A fixed-choice String column: re-encode the option list as enum(a|b|c). An empty /
					# fully-invalid option list degrades to a plain String cell (never a broken marker).
					var enum_token: String = table_enum_type((column as Dictionary).get("options", []))
					column_type = enum_token if not enum_token.is_empty() else "String"
				elif column_type.begins_with("enum("):
					# A PRE-FORMED token, which is what EventSheets.resource_grid hands over. It used to
					# fall through to the catch-all below and be coerced to "String", so an API-built
					# dropdown silently shipped as a plain text column - and the suite never saw it,
					# because the wizard test stops at the descriptor and never reads the emitted marker.
					# Round-tripping it through the codec validates and canonicalises it instead.
					var formed_token: String = table_enum_type(table_enum_options(column_type))
					column_type = formed_token if not formed_token.is_empty() else "String"
				elif not column_type in ["String", "key", "int", "float", "bool", "color"]:
					column_type = "String"
				column_pairs.append("%s=%s" % [column_name, column_type])
			if column_pairs.is_empty():
				return ""
			marker = "eventsheet:table:%s" % ",".join(column_pairs)
		"vector_dial":
			if type_name != "Vector2":
				return ""
			marker = "eventsheet:vector_dial:%s" % str(bounds.get("max", "100"))
		"swatch_row":
			if type_name != "Color":
				return ""
			marker = "eventsheet:swatch_row"
		"texture_preview":
			# Texture2D only - matches the dialog's per-type picker (a String-path variant was an inconsistency:
			# the picker never offered it, so editing such a var would silently drop the drawer).
			if type_name != "Texture2D":
				return ""
			marker = "eventsheet:texture_preview"
		"curve_editor":
			if type_name != "Curve":
				return ""
			marker = "eventsheet:curve_editor"
		_:
			return ""
	return "@export_custom(PROPERTY_HINT_NONE, \"%s\") " % marker


## @export_group/@export_subgroup lines emitted before an EXPORTED tree variable that carries Inspector
## grouping. Empty for non-exported or un-grouped vars (the common case - existing emission stays
## byte-identical). Must match _emit_variables' format exactly (the verify-lift compares against it).
static func _tree_variable_group_prefix(local_var: LocalVariable) -> String:
	# A plain-description exported variable (no attributes) still earns a `##` doc line, so the
	# guard is on `exported` alone; the attribute-driven lines below all no-op on an empty dict.
	if not local_var.exported:
		return ""
	var attributes: Dictionary = local_var.attributes if local_var.attributes is Dictionary else {}
	var prefix: String = ""
	# Decor first, then tooltip, then category/group/subgroup - same canonical order as the
	# dict-var path (_emit_variables), so the importer's absorb can verify-lift the whole block.
	# The ## doc attaches to the following @export var.
	for decor_line: String in _decor_prefix_lines(attributes):
		prefix += decor_line + "\n"
	# The description doubles as the Inspector tooltip: an explicit "tooltip" attribute wins, else the
	# plain description field is used (so a comment on a variable becomes its Inspector description).
	# Newlines collapse to spaces - a bare second line would break Godot's `##` doc-comment block.
	var tooltip: String = str(attributes.get("tooltip", "")).strip_edges()
	if tooltip.is_empty():
		tooltip = local_var.description.strip_edges()
	var doc_line: String = "## %s\n" % tooltip.replace("\n", " ") if not tooltip.is_empty() else ""
	# Both orders are ordinary Godot: this plugin writes the doc above the section lines, while
	# Godot's own convention writes `@export_group("…")` first and the doc directly above the variable
	# it documents. A variable opened from a file that used the second order carries that fact
	# (doc_after_group), so saving it back reproduces the file it came from byte for byte.
	var doc_after_group: bool = bool(attributes.get("doc_after_group", false))
	if not doc_after_group:
		prefix += doc_line
	var category: String = str(attributes.get("category", "")).strip_edges()
	if not category.is_empty():
		prefix += "@export_category(\"%s\")\n" % category
	var group: String = str(attributes.get("group", "")).strip_edges()
	if not group.is_empty():
		prefix += "@export_group(\"%s\")\n" % group
	var subgroup: String = str(attributes.get("subgroup", "")).strip_edges()
	if not subgroup.is_empty():
		prefix += "@export_subgroup(\"%s\")\n" % subgroup
	if doc_after_group:
		prefix += doc_line
	return prefix


## Inspector decor comment lines emitted before an exported variable's tooltip: a section header
## (`# @inspector_header Title` with an optional trailing `#rrggbb` accent) and an info note
## (`# @inspector_info text`). Plain `#` comments, never `##` - consecutive doc-comment lines merge
## into the Inspector's hover tooltip and decor must not. Editor-only: the drawers plugin reads them
## from the script source and renders a header label / info panel above the property; without the
## plugin (or in an exported game) they are inert comments - the parity covenant is untouched.
static func _decor_prefix_lines(attributes: Dictionary) -> PackedStringArray:
	var decor: PackedStringArray = PackedStringArray()
	var header: String = str(attributes.get("header", "")).strip_edges()
	if not header.is_empty():
		var accent: String = str(attributes.get("header_color", "")).strip_edges()
		decor.append("# @inspector_header %s" % (header + " " + accent if not accent.is_empty() else header))
	var info: String = str(attributes.get("info", "")).strip_edges()
	if not info.is_empty():
		decor.append("# @inspector_info %s" % info)
	# Required: the editor shows a warning badge above the property while it is unset/empty
	# (a Resource slot left null, a String left ""). Editor-only, like all decor.
	if bool(attributes.get("required", false)):
		decor.append("# @inspector_required")
	# Validate: a sheet function returning a warning String ("" = valid); the editor calls it
	# while the property is edited and shows the returned message above the field. Needs a
	# @tool sheet to run in-editor (silent otherwise). Function names only - no arguments.
	var validate_function: String = str(attributes.get("validate", "")).strip_edges()
	if not validate_function.is_empty() and validate_function.is_valid_identifier():
		decor.append("# @inspector_validate %s" % validate_function)
	# Field button: a small button rendered WITH the property, calling a sheet function on click
	# (reroll_stats, refresh_preview). The optional label rides after the function name.
	var action_function: String = str(attributes.get("action", "")).strip_edges()
	if not action_function.is_empty() and action_function.is_valid_identifier():
		var action_label: String = str(attributes.get("action_label", "")).strip_edges()
		decor.append(("# @inspector_action %s %s" % [action_function, action_label]) if not action_label.is_empty() else "# @inspector_action %s" % action_function)
	return decor


## Canonical @export_enum prefix ("@export_enum(\"a\", \"b\")") - verify-lift relies on
## this exact form.
static func _export_enum_prefix(options: PackedStringArray) -> String:
	var quoted: PackedStringArray = PackedStringArray()
	for option: String in options:
		if not option.strip_edges().is_empty():
			quoted.append("\"%s\"" % option.strip_edges())
	return "@export_enum(%s)" % ", ".join(quoted)


## Converts a Variant to a deterministic code literal.
static func _to_code_literal(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			var text: String = str(value)
			if text.begins_with("\"") and text.ends_with("\""):
				return text
			return "\"%s\"" % text.replace("\\", "\\\\").replace("\"", "\\\"")
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_FLOAT:
			var float_text: String = str(float(value))
			var normalized_float_text: String = float_text.to_lower()
			if float_text.find(".") == -1 and normalized_float_text.find("e") == -1:
				float_text += ".0"
			return float_text
		TYPE_NIL:
			return "null"
		TYPE_ARRAY:
			# Canonical container literals (recursive, deterministic, str_to_var-parseable):
			# verify-lift depends on this exact spacing - change only with a lifter update.
			var parts: PackedStringArray = PackedStringArray()
			for item: Variant in (value as Array):
				parts.append(_to_code_literal(item))
			return "[%s]" % ", ".join(parts)
		TYPE_DICTIONARY:
			var entries: PackedStringArray = PackedStringArray()
			var dictionary_value: Dictionary = value as Dictionary
			for key: Variant in dictionary_value.keys():
				entries.append("%s: %s" % [_to_code_literal(key), _to_code_literal(dictionary_value[key])])
			return "{%s}" % ", ".join(entries)
		# Emit constructor literals for the common game-value types (so Vector/Color variables emit valid,
		# str_to_var-parseable GDScript that the importer round-trips - str(Vector2) would give "(0, 0)").
		# Components reuse the float rule, whose str() form is shortest-round-trippable, keeping re-emission
		# byte-stable.
		#
		# The WHOLE vector family is listed, not just the types someone happened to need: anything that
		# falls through to str() below emits a bare "(0, 0, 0)", which is not GDScript. That is a silent
		# fault - the compile reports success and the emitted file simply does not parse - so a missing
		# entry here costs a 3D user their whole sheet.
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return "Vector2(%s, %s)" % [_to_code_literal(v2.x), _to_code_literal(v2.y)]
		TYPE_VECTOR2I:
			var v2i: Vector2i = value
			return "Vector2i(%s, %s)" % [_to_code_literal(v2i.x), _to_code_literal(v2i.y)]
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return "Vector3(%s, %s, %s)" % [_to_code_literal(v3.x), _to_code_literal(v3.y), _to_code_literal(v3.z)]
		TYPE_VECTOR3I:
			var v3i: Vector3i = value
			return "Vector3i(%s, %s, %s)" % [_to_code_literal(v3i.x), _to_code_literal(v3i.y), _to_code_literal(v3i.z)]
		TYPE_VECTOR4:
			var v4: Vector4 = value
			return "Vector4(%s, %s, %s, %s)" % [_to_code_literal(v4.x), _to_code_literal(v4.y), _to_code_literal(v4.z), _to_code_literal(v4.w)]
		TYPE_VECTOR4I:
			var v4i: Vector4i = value
			return "Vector4i(%s, %s, %s, %s)" % [_to_code_literal(v4i.x), _to_code_literal(v4i.y), _to_code_literal(v4i.z), _to_code_literal(v4i.w)]
		TYPE_RECT2:
			var r2: Rect2 = value
			return "Rect2(%s, %s, %s, %s)" % [_to_code_literal(r2.position.x), _to_code_literal(r2.position.y), _to_code_literal(r2.size.x), _to_code_literal(r2.size.y)]
		TYPE_RECT2I:
			var r2i: Rect2i = value
			return "Rect2i(%s, %s, %s, %s)" % [_to_code_literal(r2i.position.x), _to_code_literal(r2i.position.y), _to_code_literal(r2i.size.x), _to_code_literal(r2i.size.y)]
		TYPE_QUATERNION:
			var quat: Quaternion = value
			return "Quaternion(%s, %s, %s, %s)" % [_to_code_literal(quat.x), _to_code_literal(quat.y), _to_code_literal(quat.z), _to_code_literal(quat.w)]
		TYPE_COLOR:
			var col: Color = value
			return "Color(%s, %s, %s, %s)" % [_to_code_literal(col.r), _to_code_literal(col.g), _to_code_literal(col.b), _to_code_literal(col.a)]
		_:
			return str(value)


## Resolves output path from explicit input or sheet resource path. With no explicit
## path the sheet's EXISTING pair wins: the conventional <name>_generated.gd when
## present, else a sibling <name>.gd - but only when its header proves the compiler
## wrote it for THIS sheet (the pack builder's take_over_path convention); a
## hand-written same-name script is never adopted as an output target. This keeps
## compile-on-save and the export-integrity pass refreshing the committed pair
## instead of inventing a parallel *_generated.gd next to it.
static func _resolve_output_path(sheet: EventSheetResource, output_path: String) -> String:
	if not output_path.is_empty():
		return output_path
	if not sheet.resource_path.is_empty():
		# get_basename() (full path minus extension) - building from get_base_dir()
		# yields user:///… triple slashes for root-level paths.
		var base: String = sheet.resource_path.get_basename()
		var generated: String = base + "_generated.gd"
		if FileAccess.file_exists(generated):
			return generated
		var sibling: String = base + ".gd"
		if FileAccess.file_exists(sibling) and FileAccess.get_file_as_string(sibling).left(400).contains("# Source: %s" % sheet.resource_path):
			return sibling
		return generated
	return "res://event_sheet_generated.gd"


## Whether `needle` appears in `line` OUTSIDE every string literal. A file that merely TALKS about
## the helper - a pattern table, a doc string, a test's expected text - must never be handed the
## helper's definition: injecting it breaks the byte-exact reopen of a file that was only opened.
static func _calls_outside_strings(line: String, needle: String) -> bool:
	var in_string: bool = false
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if in_string:
			if character == "\\":
				index += 2
				continue
			if character == quote:
				in_string = false
		elif character == "\"" or character == "'":
			in_string = true
			quote = character
		elif line.substr(index).begins_with(needle):
			return true
		index += 1
	return false


## X30. The one function every aimed-floor word calls, written into the file the first time any of
## them appears in it. All three answers - the floor point, the floor object and the floor's slope -
## and both cursor questions share this ONE definition, so a project that asks for the point AND the
## slope gains the plumbing once rather than twice.
##
## APPENDED, never inserted: nothing follows it, so no source-map line ever moves. Skipped outright
## when the file already defines it, which is what makes reopening an emitted file and saving it
## again byte-identical - the definition read back as an ordinary function is the same definition
## this would have written.
static func _append_aimed_cursor_helper(lines: PackedStringArray) -> void:
	_append_shared_helper(lines, AIMED_CURSOR_HELPER,
		"func %s(canvas_point: Vector2, layer_mask: int, reach: float) -> Dictionary:" % AIMED_CURSOR_HELPER,
		["	var camera: Camera3D = get_viewport().get_camera_3d()",
		"	if camera == null:",
		"		return {}",
		"	var from: Vector3 = camera.project_ray_origin(canvas_point)",
		"	var to: Vector3 = from + camera.project_ray_normal(canvas_point) * reach",
		"	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)",
		"	query.collision_mask = layer_mask",
		"	return get_viewport().find_world_3d().direct_space_state.intersect_ray(query)"])
	_append_shared_helper(lines, POINT_CURSOR_HELPER,
		"func %s(canvas_point: Vector2, layer_mask: int) -> Dictionary:" % POINT_CURSOR_HELPER,
		["	var world: World2D = get_viewport().find_world_2d()",
		"	if world == null:",
		"		return {}",
		"	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()",
		"	query.position = canvas_point",
		"	query.collision_mask = layer_mask",
		"	query.collide_with_areas = true",
		"	var hits: Array[Dictionary] = world.direct_space_state.intersect_point(query, 1)",
		"	if hits.is_empty():",
		"		return {}",
		"	return hits[0]"])
	# The map is deliberately UNTYPED: a tile lookup is asked of whatever node the row names, and a
	# `Node`-typed parameter would refuse `local_to_map` at parse time in every project that uses it.
	_append_shared_helper(lines, TILE_CURSOR_HELPER,
		"func %s(map) -> Vector2i:" % TILE_CURSOR_HELPER,
		["	if map == null:",
		"		return Vector2i.ZERO",
		"	return map.local_to_map(map.get_local_mouse_position())"])


## One shared helper's definition, appended when the file calls it and does not already define it.
## Every rule the aimed-floor helper documents above holds for each of them: appended last so no
## source-map line moves, skipped when the head line is already present so a reopened file re-emits
## byte-identically, and a mere mention inside a string literal never counts as a call.
static func _append_shared_helper(lines: PackedStringArray, helper_name: String, head: String,
		body: Array) -> void:
	var called: bool = false
	for line: String in lines:
		if line == head:
			return
		if line.strip_edges().begins_with("#"):
			continue
		if _calls_outside_strings(line, "%s(" % helper_name):
			called = true
	if not called:
		return
	lines.append("")
	lines.append(head)
	for body_line: String in body:
		lines.append(body_line)
