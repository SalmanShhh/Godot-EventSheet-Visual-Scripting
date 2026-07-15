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

const VERSION: String = "0.15.0"

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


## Compiles an event sheet resource to a GDScript output file.
## omit_generated_banner drops the "AUTO-GENERATED / DO NOT EDIT" header - used when the .gd IS the
## user's source of truth (Save As .gd), not a regenerated companion of a .tres sheet.
static func compile(sheet: EventSheetResource, output_path: String = "", omit_generated_banner: bool = false) -> Dictionary:
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
	_collect_groups(all_events, group_decls, {})

	var lines: PackedStringArray = PackedStringArray()
	if not omit_generated_banner:
		lines.append("# AUTO-GENERATED by EventForge v%s" % VERSION)
		lines.append("# Source: %s" % sheet.resource_path)
		lines.append("# DO NOT EDIT — this file is regenerated on every compile.")
		lines.append("")
	# Tool sheets (EXPERIMENTAL): @tool must precede class_name/extends.
	if sheet.tool_mode:
		lines.append("@tool")
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
			var enum_line: String = _emit_enum_line(enum_entry as EnumRow)
			if enum_line.is_empty():
				continue
			lines.append(enum_line)
			source_map.append({"uid": str((enum_entry as EnumRow).get_instance_id()), "start": lines.size(), "end": lines.size(), "kind": "enum"})
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
			_collect_stateful_members((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, stateful_members)
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
	# Live values and the event trace share one throttled _process, so they share the timer member;
	# the trace also needs its per-frame buffer. Declared whenever either is enabled - the trace can
	# run on its own (without live values), so this is no longer gated behind emit_live_values.
	if _live_values_receiver_pending or _emit_event_trace_flag:
		if variable_lines.is_empty() and tree_variables.is_empty():
			lines.append("")
		lines.append("var __live_values_timer: float = 0.0")
		if _emit_event_trace_flag:
			lines.append("var __eventsheets_fired: PackedStringArray = PackedStringArray()")

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
					(result["warnings"] as Array).append("A GDScript block also defines %s() - remove it or clear the Inspector/Requires settings (duplicate functions don't compile)." % hook_name)

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
		if event_row.trigger_id.is_empty():
			(result["warnings"] as Array[String]).append("Skipping event %s with no trigger" % event_row.event_uid)
			continue
		top_level_events.append(event_row)
	var declared_signals: Array = _scan_declared_signals(raw_blocks)
	for signal_entry: Variant in signal_rows:
		if signal_entry is SignalRow and (signal_entry as SignalRow).enabled:
			declared_signals.append((signal_entry as SignalRow).signal_name)
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
		lines.append("\t__live_values_timer += delta")
		lines.append("\tif __live_values_timer >= 0.25 and EngineDebugger.is_active():")
		lines.append("\t\t__live_values_timer = 0.0")
		if not _live_values_payload.is_empty():
			lines.append("\t\tEngineDebugger.send_message(\"eventsheets:live_values\", [%s])" % _live_values_payload)
		if _emit_event_trace_flag:
			lines.append("\t\tEngineDebugger.send_message(\"eventsheets:fired_events\", __eventsheets_fired)")
			lines.append("\t\t__eventsheets_fired.clear()")
		_throttle_process_emitted = true
		_live_values_payload = ""

	if sheet.emit_live_values and not sheet.variables.is_empty():
		lines.append("")
		lines.append("## Live Values edit-back receiver (debug sessions only).")
		lines.append("func _eventsheets_debug_set(message: String, data: Array) -> bool:")
		lines.append("\tif message != \"set_value\" or data.size() < 2:")
		lines.append("\t\treturn false")
		lines.append("\tset(str(data[0]), data[1])")
		lines.append("\treturn true")

	# Emit sheet functions as callable GDScript methods (after the trigger handlers).
	for function_resource: Variant in all_functions:
		if not (function_resource is EventFunction):
			continue
		var event_function: EventFunction = function_resource as EventFunction
		if not event_function.enabled or event_function.function_name.strip_edges().is_empty():
			continue
		lines.append("")
		var function_start: int = lines.size() + 1
		_emit_expose_annotations(event_function, sheet, lines)
		lines.append("%sfunc %s(%s) -> %s:" % ["static " if event_function.is_static else "", event_function.function_name, _emit_function_params(event_function), _function_return_type_name(event_function)])
		var function_events: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
		var function_had_body: bool = _emit_event_body(function_events, lines, source_map, 1, result["warnings"])
		if not function_had_body:
			lines.append(_empty_function_stub(event_function))
		source_map.append({"uid": str(event_function.get_instance_id()), "start": function_start, "end": lines.size(), "kind": "function"})

	for deferred: String in deferred_rows:
		lines.append("")
		lines.append(deferred)

	_insert_stateful_member_declarations(lines, sheet, result.get("source_map", []))
	_insert_provider_member_declarations(lines, result)
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
## including the "already up to date" no-op; false only if a genuinely-needed write could not open.
static func _write_output_if_changed(path: String, output: String) -> bool:
	if _output_is_current(path, output):
		return true
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(output)
	file.flush()
	file.close()
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
	# Event groups dissolve into the trigger sections on this path too, so refill the per-compile slug
	# map for THIS sheet (compile() returns into _compile_external before the main path's reset/collect
	# runs). The `## @ace_group` declarations ride along verbatim in the preserved prelude rows - we only
	# need _group_slugs populated so _emit_event_body re-emits the `# @group:` markers (else an imported
	# grouped sheet would lose them on the next save).
	_group_slugs = {}
	_row_group_path = {}
	_collect_groups(sheet.events, [], {})
	if not sheet.includes.is_empty() or not sheet.uses_addons.is_empty() or not sheet.requires_behaviors.is_empty():
		(result["warnings"] as Array).append("GDScript-backed sheets ignore Includes/Uses/Requires - the .gd file is the source of truth (write the equivalent code directly).")
	var lines: PackedStringArray = PackedStringArray()
	var source_map: Array = result["source_map"]
	var added_event_rows: Array = []
	var deferred_comment_lines_external: PackedStringArray = PackedStringArray()
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
		elif entry is RawCodeRow:
			var block_start: int = lines.size() + 1
			for code_line: String in (entry as RawCodeRow).code.split("\n"):
				lines.append(code_line)
			source_map.append({"uid": str((entry as RawCodeRow).get_instance_id()), "start": block_start, "end": lines.size(), "kind": "raw"})
		elif entry is EventRow or entry is EventGroup:
			added_event_rows.append(entry)
		elif entry is CommentRow and (entry as CommentRow).enabled and not (entry as CommentRow).text.strip_edges().is_empty():
			deferred_comment_lines_external.append_array((entry as CommentRow).text.split("\n"))
		elif entry is EnumRow:
			var external_enum_line: String = _emit_enum_line(entry as EnumRow)
			if not external_enum_line.is_empty():
				lines.append(external_enum_line)
				source_map.append({"uid": str((entry as EnumRow).get_instance_id()), "start": lines.size(), "end": lines.size(), "kind": "enum"})
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
		var function_blanks: int = maxi(int(event_function.get_meta("__source_leading_blanks", 1)), 1)
		for _blank_index: int in range(function_blanks):
			lines.append("")
		_emit_function_block(event_function, sheet, lines, source_map, result)

	# Top-level comments emit last, one blank before each line (main path's deferred format).
	for comment_line: String in deferred_comment_lines_external:
		lines.append("")
		lines.append("# %s" % comment_line)
	_insert_stateful_member_declarations(lines, sheet, result.get("source_map", []))
	_insert_provider_member_declarations(lines, result)
	var output: String = "\n".join(lines) + "\n"
	result["output"] = output
	var final_output_path: String = output_path if not output_path.is_empty() else sheet.external_source_path
	if not _write_output_if_changed(final_output_path, output):
		result["success"] = false
		(result["errors"] as Array[String]).append("Failed to open output path: %s" % final_output_path)
		return result
	return result


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
	_emit_expose_annotations(event_function, sheet, lines)
	lines.append("%sfunc %s(%s) -> %s:" % ["static " if event_function.is_static else "", event_function.function_name, _emit_function_params(event_function), _function_return_type_name(event_function)])
	var function_events: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
	if not _emit_event_body(function_events, lines, source_map, 1, result["warnings"]):
		lines.append(_empty_function_stub(event_function))
	source_map.append({"uid": str(event_function.get_instance_id()), "start": function_start, "end": lines.size(), "kind": "function"})


## The lifter's per-anchor gate: exactly what _emit_function_block would produce for this
## function, as text, with no side effects. A mid-file helper lifts only when this equals the
## original source lines byte-for-byte, so anchoring can never change a file.
static func emit_function_block_text(event_function: EventFunction, sheet: EventSheetResource) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var scratch: Dictionary = {"warnings": [], "errors": []}
	_emit_function_block(event_function, sheet, lines, [], scratch)
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


static func _insert_stateful_member_declarations(lines: PackedStringArray, sheet: EventSheetResource, source_map: Array = []) -> void:
	var members: Array = []
	_collect_stateful_members(sheet.events, members)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect_stateful_members((function_entry as EventFunction).events if not (function_entry as EventFunction).events.is_empty() else (function_entry as EventFunction).rows, members)
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
	var member_regex: RegEx = RegEx.new()
	if member_regex.compile("__eventsheet_provider_([A-Za-z_][A-Za-z0-9_]*)") != OK:
		return
	var providers: Dictionary = {}  # member name -> class name, deduped
	for line: String in lines:
		for regex_match: RegExMatch in member_regex.search_all(line):
			providers[regex_match.get_string(0)] = regex_match.get_string(1)
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
			total += _count_event_rows(inner.events if not inner.events.is_empty() else inner.rows)
	return total


## A deterministic, GDScript-safe slug for a group name - NOT the random group_uid (which would make
## the emitted markers churn on every save). Lowercase, snake-cased, non-alphanumerics collapsed to a
## single underscore, with a numeric suffix on collision so two same-named groups stay distinct.
## `used` accumulates the slugs already handed out this compile.
static func _group_slug(group_name: String, used: Dictionary) -> String:
	var slug: String = group_name.strip_edges().to_snake_case()
	var sanitizer: RegEx = RegEx.new()
	sanitizer.compile("[^a-z0-9]+")
	slug = sanitizer.sub(slug, "_", true)
	while slug.begins_with("_"):
		slug = slug.substr(1)
	while slug.ends_with("_"):
		slug = slug.substr(0, slug.length() - 1)
	if slug.is_empty():
		slug = "group"
	var candidate: String = slug
	var suffix: int = 2
	while used.has(candidate):
		candidate = "%s_%d" % [slug, suffix]
		suffix += 1
	used[candidate] = true
	return candidate


## Walks the event tree assigning every EventGroup a deterministic slug (filling _group_slugs) and
## appending an ordered {slug, parent, group} record to `decls` (parents before children, so the
## importer can rebuild nesting). Recurses into group bodies, mirroring _flatten_trigger_rows' walk.
static func _collect_groups(rows: Array, decls: Array, used: Dictionary, parent_slug: String = "") -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			var group_name: String = group.group_name if not group.group_name.is_empty() else group.name
			var slug: String = _group_slug(group_name, used)
			_group_slugs[group] = slug
			decls.append({"slug": slug, "parent": parent_slug, "group": group})
			_collect_groups(group.events if not group.events.is_empty() else group.rows, decls, used, slug)


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
		lines.append("## @ace_group(%s)" % ", ".join(parts))


## Flattens trigger-bearing rows for emission: EventRows kept, ENABLED groups recursed (a disabled
## group is dropped but leaves a breadcrumb comment - group-disable semantics), and group comments
## collected as deferred comment lines.
static func _flatten_trigger_rows(rows: Array, into_events: Array, deferred_comment_lines: PackedStringArray, runtime_guard: String = "", group_slug: String = "") -> void:
	for row: Variant in rows:
		if row is EventRow:
			if not runtime_guard.is_empty():
				_runtime_group_guards[row] = runtime_guard
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
					var guard_token: String = group.group_name.to_snake_case() if not group.group_name.is_empty() else "group"
					child_guard = "__group_%s_active" % guard_token
					var already_known: bool = false
					for member_pair: Array in _runtime_group_members:
						if str(member_pair[0]) == child_guard:
							already_known = true
					if not already_known:
						_runtime_group_members.append([child_guard, group.enabled])
				_flatten_trigger_rows(group.events if not group.events.is_empty() else group.rows, into_events, deferred_comment_lines, child_guard, _group_slugs.get(group, ""))
			else:
				# Don't silently drop a disabled group: leave a breadcrumb so the omission is visible
				# in the generated code. Disabling a group intentionally excludes its events (the
				# editor's "Set Group Active" toggle), but vanishing them with no trace is a footgun.
				var omitted: int = _count_event_rows(group.events if not group.events.is_empty() else group.rows)
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
		if not event_row.enabled or event_row.trigger_id.is_empty():
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
		var source_path: String = str(signature.get("source_path", ""))
		if source_path.is_empty():
			# Self-connection: the signal must exist on the script's base class or be
			# declared in a class-level GDScript block, or the generated script would not
			# parse. Skipped connections keep the old behavior (wire it in the scene).
			var self_class: String = str(connect_context.get("self_class", "Node"))
			var declared_signals: Array = connect_context.get("declared_signals", [])
			if not ClassDB.class_has_signal(self_class, signal_name) and not declared_signals.has(signal_name):
				(result["warnings"] as Array[String]).append(
					"Trigger %s: %s has no signal \"%s\" - connection skipped (connect it in the scene or declare the signal in a GDScript block)." % [key, self_class, signal_name]
				)
				continue
		var source_prefix: String = ""
		if source_path == "@tree":
			# Global SceneTree signals (process_frame / physics_frame) - post-tick triggers connect here.
			source_prefix = "get_tree()."
		elif source_path == "@window":
			# Root-window signals (close_requested) - the On Close Requested trigger connects here.
			source_prefix = "get_window()."
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
	if not has_ready_group and (not ready_connections.is_empty() or _live_values_receiver_pending):
		lines.append("")
		lines.append("func _ready() -> void:")
		if _live_values_receiver_pending:
			lines.append("\tif EngineDebugger.is_active() and not EngineDebugger.has_capture(\"eventsheets\"):")
			lines.append("\t\tEngineDebugger.register_message_capture(&\"eventsheets\", _eventsheets_debug_set)")
			_live_values_receiver_pending = false
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
		if args.is_empty():
			lines.append("func %s() -> void:" % function_name)
		else:
			lines.append("func %s(%s) -> void:" % [function_name, args])
		var had_body: bool = false
		if function_name == "_ready" and _live_values_receiver_pending:
			# Edit-back channel: the Live Values window's edits arrive as
			# "eventsheets:set_value" messages (debug sessions only; one receiver per
			# game - the first streaming sheet wins, noted in the window).
			lines.append("\tif EngineDebugger.is_active() and not EngineDebugger.has_capture(\"eventsheets\"):")
			lines.append("\t\tEngineDebugger.register_message_capture(&\"eventsheets\", _eventsheets_debug_set)")
			had_body = true
			_live_values_receiver_pending = false
		if function_name == "_process" and not _throttle_process_emitted and (not _live_values_payload.is_empty() or _emit_event_trace_flag):
			# Live-values stream and/or the event trace: throttled, debug-session-only, before user logic.
			lines.append("\t__live_values_timer += delta")
			lines.append("\tif __live_values_timer >= 0.25 and EngineDebugger.is_active():")
			lines.append("\t\t__live_values_timer = 0.0")
			if not _live_values_payload.is_empty():
				lines.append("\t\tEngineDebugger.send_message(\"eventsheets:live_values\", [%s])" % _live_values_payload)
			if _emit_event_trace_flag:
				lines.append("\t\tEngineDebugger.send_message(\"eventsheets:fired_events\", __eventsheets_fired)")
				lines.append("\t\t__eventsheets_fired.clear()")
			had_body = true
			_throttle_process_emitted = true
			_live_values_payload = ""
		if function_name == "_ready" and not ready_connections.is_empty():
			# Signal connections run before the user's OnReady logic.
			for connection_line: String in ready_connections:
				lines.append(connection_line)
			had_body = true
		had_body = _emit_event_body(events, lines, source_map, 1, result["warnings"]) or had_body
		if not had_body:
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
		if wants_chain:
			if condition_texts.size() > 0:
				lines.append("%selif %s:" % [indent, joined_conditions])
			else:
				lines.append("%selse:" % indent)
			emitted_block = true
			had_body = true
		elif condition_texts.size() > 0:
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
				var inline_start: int = lines.size() + 1
				for inline_line: String in inline_raw.code.split("\n"):
					lines.append(body_indent + inline_line)
				had_body = true
				source_map.append({"uid": str(inline_raw.get_instance_id()), "start": inline_start, "end": lines.size(), "kind": "raw"})
			elif action_item is MatchRow:
				# A GDScript `match` as a structured action row (the switch idiom): subject + branches one
				# level deeper. Structured `cases` (each an editable action body) win when present; otherwise
				# the verbatim branches_text form (the raw escape hatch + what today's importer lifts).
				var match_row: MatchRow = action_item as MatchRow
				if not match_row.enabled or match_row.match_expression.strip_edges().is_empty():
					continue
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
			elif action_item is CommentRow:
				# Action-cell comment: annotates the flow, compiles to comment lines.
				var action_comment: CommentRow = action_item as CommentRow
				if action_comment.enabled and not action_comment.text.strip_edges().is_empty():
					var action_comment_start: int = lines.size() + 1
					for comment_line: String in action_comment.text.split("\n"):
						lines.append("%s# %s" % [body_indent, comment_line])
					had_body = true
					source_map.append({"uid": str(action_comment.get_instance_id()), "start": action_comment_start, "end": lines.size(), "kind": "comment"})
			elif action_item is Resource and action_item.has_method("get_row_kind"):
				lines.append(body_indent + "# (unknown row type — preserved as a comment so nothing is silently dropped)")
				had_body = true

		# Sub-events run inside the parent's block (under its conditions).
		if not event_row.sub_events.is_empty():
			had_body = _emit_event_body(event_row.sub_events, lines, source_map, body_depth, warnings, effective_node_target) or had_body

		# An if/elif/else block (or pick loop) whose body emitted nothing needs `pass` to
		# stay valid GDScript (e.g. a condition-only event, or one whose actions all
		# compiled to nothing).
		if (emitted_block or emitted_pick_loop) and lines.size() == body_start_size:
			lines.append(body_indent + "pass")
			had_body = true
		if lines.size() >= event_start_line:
			source_map.append({"uid": str(event_row.get_instance_id()), "start": event_start_line, "end": lines.size(), "kind": "event"})
		chain_open = emitted_block
	return had_body


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
		if _condition_is_node_scoped(cond):
			base = "%s.%s" % [iterator, base]
		var part: String = "not (%s)" % base if cond.negated else base
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
					option_texts.append(str(option_value))
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
	var call_prefix: String = ""
	if sheet.behavior_mode and not sheet.custom_class_name.strip_edges().is_empty():
		call_prefix = "$%s." % sheet.custom_class_name.strip_edges()
	elif sheet.autoload_mode and not sheet.autoload_name.strip_edges().is_empty():
		# Singletons are addressed by their autoload name - works from every scene,
		# no node paths (the whole point of an autoload).
		call_prefix = "%s." % sheet.autoload_name.strip_edges()
	lines.append("## @ace_codegen_template(\"%s%s(%s)\")" % [call_prefix, event_function.function_name, ", ".join(argument_tokens)])


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
			var type_name: String = param.type_name
			var rendered: String = param_id if (type_name.is_empty() or type_name == "Variant") else "%s: %s" % [param_id, type_name]
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


## Emits `@export var` lines from the sheet variables dictionary.
static func _emit_variables(variables: Dictionary, warnings: Array = [], function_names: Dictionary = {}) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var keys: Array = variables.keys()
	keys.sort()
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
			# A category is the heaviest Inspector divider (its own header band); it precedes
			# the group exactly as Godot applies them.
			if exported and not str(attributes.get("category", "")).strip_edges().is_empty():
				lines.append("@export_category(\"%s\")" % str(attributes.get("category")).strip_edges())
			if exported and not str(attributes.get("group", "")).strip_edges().is_empty():
				lines.append("@export_group(\"%s\")" % str(attributes.get("group")).strip_edges())
			# Nested Inspector grouping for complex objects with many tunables: @export_subgroup follows the
			# group and nests under it (Godot applies it to the following @export vars).
			if exported and not str(attributes.get("subgroup", "")).strip_edges().is_empty():
				lines.append("@export_subgroup(\"%s\")" % str(attributes.get("subgroup")).strip_edges())
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
static func _emit_enum_line(enum_row: EnumRow) -> String:
	# EnumRow is a registered RESOURCE kind on the Custom Block API - the compiler actively
	# dispatches the built-in through the same emit contract pack kinds use.
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(enum_row)
	if kind == null:
		return ""
	var emitted: PackedStringArray = kind.emit_lines(enum_row)
	return "" if emitted.is_empty() else emitted[0]


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
			_collect_signal_rows(group.events if not group.events.is_empty() else group.rows, into)


## Recursively gathers EnumRow rows (top level and inside groups).
static func _collect_enum_rows(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is EnumRow:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_enum_rows(group.events if not group.events.is_empty() else group.rows, into)


## Gathers Custom Block API rows (registered non-ACE kinds) from the event tree, group-recursive
## like enums/signals so a block inside a group still emits.
static func _collect_custom_blocks(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is CustomBlockRow:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_custom_blocks(group.events if not group.events.is_empty() else group.rows, into)


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
			_collect_group_locals(group.events if not group.events.is_empty() else group.rows, into)


## Early pass for the flag members of runtime-toggleable groups (nested included).
static func _collect_runtime_group_members(rows: Array) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			if group.enabled and group.runtime_toggleable:
				var guard_token: String = group.group_name.to_snake_case() if not group.group_name.is_empty() else "group"
				var guard_name: String = "__group_%s_active" % guard_token
				var already_known: bool = false
				for member_pair: Array in _runtime_group_members:
					if str(member_pair[0]) == guard_name:
						already_known = true
				if not already_known:
					_runtime_group_members.append([guard_name, group.enabled])
			if group.enabled:
				_collect_runtime_group_members(group.events if not group.events.is_empty() else group.rows)


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
			_collect_stateful_members(group.events if not group.events.is_empty() else group.rows, into)


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
			_collect_class_level_raw_rows(group.events if not group.events.is_empty() else group.rows, into)


## Recursively gathers tree-placed LocalVariable rows from the event tree (top level, groups
## and sub-events) so they can be emitted as class-level declarations.
static func _collect_tree_variables(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is LocalVariable:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_tree_variables(group.events if not group.events.is_empty() else group.rows, into)
		elif entry is EventRow:
			_collect_tree_variables((entry as EventRow).sub_events, into)


## Walks every trigger / condition / action and adds ONE compile warning per distinct deprecated ACE.
## Deprecated ACEs still compile byte-for-byte (the covenant), so this is a nudge toward the replacement,
## not a build break. `seen` dedupes so a deprecated ACE used ten times warns once.
static func _collect_deprecated_aces(entries: Array, warnings: Array, seen: Dictionary) -> void:
	for entry: Variant in entries:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_deprecated_aces(group.events if not group.events.is_empty() else group.rows, warnings, seen)
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
	# Tier 3 custom-drawer prefix (if any): a structured @export_custom marker, computed once so it can both
	# gate its branch and fill it. Empty for non-drawer vars, so their emission stays byte-unchanged.
	var drawer_prefix: String = ""
	if local_var.exported and local_var.attributes is Dictionary:
		drawer_prefix = _drawer_export_prefix(local_var.attributes, local_var.type_name)
	var var_line: String
	if local_var.is_constant:
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
	# Inspector grouping rides in front, matching the dict-var path (_emit_variables) byte-for-byte so the
	# round-trip lift can absorb it back onto the variable instead of stranding it as a GDScript block.
	return _tree_variable_group_prefix(local_var) + var_line


## Decodes a table-column enum type token: "enum(circle|ring|rect)" -> ["circle", "ring", "rect"];
## returns [] for any non-enum token (String/int/float/bool or malformed), so callers fall back to
## their plain-type path. The `|` option delimiter is chosen because it avoids every reserved marker
## char ( , = : " ), so the option list survives the column/name/type/marker splits verbatim. Shared by
## the compiler emit, the importer lift, the editor drawer parse, and the variable dialog so all four
## agree on the encoding (a mismatch would silently downgrade an enum column to free text).
static func table_enum_options(type_token: String) -> Array:
	var token: String = type_token.strip_edges()
	if not token.begins_with("enum(") or not token.ends_with(")"):
		return []
	var options: Array = []
	for option: String in token.substr(5, token.length() - 6).split("|"):
		if _valid_enum_option(option):
			options.append(option.strip_edges())
	return options


## Encodes an option list into the marker type token: ["circle", "ring"] -> "enum(circle|ring)". Returns
## "" when no option survives the reserved-char filter, so the column falls back to a plain String cell.
static func table_enum_type(options: Array) -> String:
	var clean: PackedStringArray = PackedStringArray()
	for option: Variant in options:
		if _valid_enum_option(str(option)):
			clean.append(str(option).strip_edges())
	if clean.is_empty():
		return ""
	return "enum(%s)" % "|".join(clean)


## One option is valid iff it is non-empty and carries no reserved marker char. Shared by BOTH codecs
## so decode and encode agree - the dialog preview (which decodes free-typed text) can never show a
## choice the emitter would silently drop.
static func _valid_enum_option(option: String) -> bool:
	var cleaned: String = option.strip_edges()
	if cleaned.is_empty():
		return false
	return not (cleaned.contains(",") or cleaned.contains("=") or cleaned.contains(":") or cleaned.contains("\"") or cleaned.contains("|") or cleaned.contains("(") or cleaned.contains(")"))


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
			if type_name != "Array" or not (attributes.get("table_columns") is Array):
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
				elif not column_type in ["String", "int", "float", "bool", "color"]:
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
	if not tooltip.is_empty():
		prefix += "## %s\n" % tooltip.replace("\n", " ")
	var category: String = str(attributes.get("category", "")).strip_edges()
	if not category.is_empty():
		prefix += "@export_category(\"%s\")\n" % category
	var group: String = str(attributes.get("group", "")).strip_edges()
	if not group.is_empty():
		prefix += "@export_group(\"%s\")\n" % group
	var subgroup: String = str(attributes.get("subgroup", "")).strip_edges()
	if not subgroup.is_empty():
		prefix += "@export_subgroup(\"%s\")\n" % subgroup
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
		# Constructor literals for the common game-value types (so Vector2/Color variables emit valid,
		# str_to_var-parseable GDScript that the importer round-trips - str(Vector2) would give "(0, 0)").
		# Components reuse the float rule, whose str() form is shortest-round-trippable, keeping re-emission
		# byte-stable.
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return "Vector2(%s, %s)" % [_to_code_literal(v2.x), _to_code_literal(v2.y)]
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
