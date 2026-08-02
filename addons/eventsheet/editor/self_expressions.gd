# EventSheet - the "Self" expression section (Phase 1: Variables / Properties / Functions).
# Answers the C3 reflex "type Self. and see what my object knows about itself": a pinned section in
# the Expressions dictionary listing the sheet's own variables, the host's C3-common properties
# under their C3 names, and the sheet's expression functions. Every entry inserts PLAIN GDScript -
# the C3 name is only the label a migrating user scans for, so the section teaches the real
# language and obsoletes itself.
#
# This file is the section's whole brain, static + pure, so the census is headless-testable
# without a dialog. It is a VIEW over data the plugin already derives (sheet variables, ClassDB
# host reflection, the define-role classifier) - it mints no vocabulary and no ace_ids, and no
# "Self" token ever reaches emitted code or the round-trip.
@tool
class_name EventSheetSelfExpressions
extends RefCounted

## The C3-name override table - the ONLY literal table in the feature, and it is an override list
## on top of reflection, never a property catalog. An alias exists ONLY when the C3 name and the
## Godot name genuinely differ (position.x needs "X"; scale needs nothing). `host` gates the entry:
## it is dropped (not disabled) when the sheet's host cannot reach the property.
const ALIAS_OVERRIDES: Array = [
	# `position` lives on Node2D, Node3D and Control separately (CanvasItem has none), so X/Y gate
	# on each rather than a shared ancestor. Angle deliberately excludes Node3D: its `rotation` is
	# a Vector3, and aliasing a scalar C3 name to a vector would insert a lie.
	{"label": "X", "fragment": "position.x", "host": "Node2D"},
	{"label": "Y", "fragment": "position.y", "host": "Node2D"},
	{"label": "X", "fragment": "position.x", "host": "Node3D"},
	{"label": "Y", "fragment": "position.y", "host": "Node3D"},
	{"label": "Z", "fragment": "position.z", "host": "Node3D"},
	{"label": "X", "fragment": "position.x", "host": "Control"},
	{"label": "Y", "fragment": "position.y", "host": "Control"},
	{"label": "Angle", "fragment": "rotation", "host": "Node2D"},
	{"label": "Angle", "fragment": "rotation", "host": "Control"},
	{"label": "Opacity", "fragment": "modulate.a", "host": "CanvasItem"},
	{"label": "Width", "fragment": "size.x", "host": "Control"},
	{"label": "Height", "fragment": "size.y", "host": "Control"},
	{"label": "ZIndex", "fragment": "z_index", "host": "CanvasItem"},
	{"label": "UID", "fragment": "get_instance_id()", "host": "Object"},
]


## The whole section model: {variables, properties, functions, host}, each an entry list
## {label, fragment, tooltip}. `label` is what the tree shows, `fragment` is the GDScript inserted
## at the caret. `host` fills only in behaviour mode: the same C3 commons against the pack's HOST
## through the `host` binding every behaviour carries (`host.position.x`) - the second audience
## with C3 muscle memory is the behaviour author, whose "my object" is the parent.
## Pure - callers pass the sheet and the resolved host class name.
static func section_for(sheet: EventSheetResource, host_class: String) -> Dictionary:
	var host_entries: Array = []
	if sheet != null and sheet.behavior_mode:
		host_entries = property_entries(host_class, "host.")
	return {
		"variables": variable_entries(sheet),
		"properties": property_entries(host_class),
		"functions": function_entries(sheet),
		"host": host_entries,
	}


## The host's C3-common properties, host-gated through ClassDB. A custom script class resolves to
## its nearest engine base first, so a `class_name PlayerBrain extends CharacterBody2D` host still
## receives X/Y/Angle. An unresolvable host keeps only the Object-level commons.
## `fragment_prefix` re-aims the commons at another object ("host." for a behaviour's parent).
static func property_entries(host_class: String, fragment_prefix: String = "") -> Array:
	var engine_class: String = resolve_engine_class(host_class)
	var out: Array = []
	for alias: Dictionary in ALIAS_OVERRIDES:
		var gate: String = str(alias.get("host"))
		if not ClassDB.is_parent_class(engine_class, gate):
			continue
		var fragment: String = fragment_prefix + str(alias.get("fragment"))
		out.append({
			"label": "%s · %s" % [str(alias.get("label")), fragment],
			"fragment": fragment,
			"tooltip": "C3's Self.%s - inserts %s" % [str(alias.get("label")), fragment],
		})
	return out


## The Behaviours subgroup: one group per behaviour pack, its knobs and value-returning verbs as
## `$PackName.member` chains - the attached-child access the README teaches, NOT the compiler's
## owned-instance seam. Only entries with CLEAN reflection metadata (source_kind property/method)
## are listed; a baked multi-line template cannot be represented as a chain, so it is skipped
## rather than guessed. Used-by-this-sheet packs sort first (the Uses census), the rest trail
## alphabetically for browsing. `robust` swaps `$Name` for `get_node_or_null("Name")` - the form
## that survives runtime attachment, defaulted on for spawn-heavy sheets.
## Returns [{provider, used, entries: [{label, fragment, tooltip}]}].
static func behaviour_groups(sheet: EventSheetResource, registry: EventSheetACERegistry, robust: bool = false) -> Array:
	if registry == null:
		return []
	var used: Dictionary = {}
	if sheet != null:
		for organ: Dictionary in BehaviourAnatomyPanel.collect_anatomy(sheet):
			if str(organ.get("id")) != "uses":
				continue
			for entry: Dictionary in organ.get("entries", []):
				used[str(entry.get("provider", ""))] = true
	var groups: Array = []
	for provider_id: String in registry.get_reflected_provider_ids():
		var entries: Array = []
		for definition: ACEDefinition in registry.get_provider_definitions(provider_id):
			if definition.ace_type != ACEDefinition.ACEType.EXPRESSION:
				continue
			if str(definition.metadata.get("semantic_source", "")) != "reflection":
				continue
			var source_name: String = str(definition.metadata.get("source_name", ""))
			if source_name.is_empty():
				continue
			var member: String = ""
			match str(definition.metadata.get("source_kind", "")):
				"property":
					member = source_name
				"method":
					var argument_names: PackedStringArray = PackedStringArray()
					for parameter: Variant in definition.parameters:
						if parameter is Dictionary:
							argument_names.append(str((parameter as Dictionary).get("id", "")))
					member = "%s(%s)" % [source_name, ", ".join(argument_names)]
				_:
					continue
			var fragment: String = "$%s.%s" % [provider_id, member]
			if robust:
				fragment = robust_fragment(fragment)
			entries.append({
				"label": "%s · %s" % [definition.display_name, member],
				"fragment": fragment,
				"tooltip": definition.description if not definition.description.is_empty()
					else "Reads %s from the attached %s behaviour." % [member, provider_id],
			})
		if entries.is_empty():
			continue
		groups.append({"provider": provider_id, "used": bool(used.get(provider_id, false)), "entries": entries})
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("used")) != bool(b.get("used")):
			return bool(a.get("used"))
		return str(a.get("provider")) < str(b.get("provider")))
	return groups


## `$Name.member` -> `get_node_or_null("Name").member` - the access that survives a behaviour
## attached at RUNTIME (a $-path to an auto-named child misses silently). Non-$ fragments pass
## through untouched. The node token may carry a path ("$A/B.x" keeps "A/B" whole).
static func robust_fragment(fragment: String) -> String:
	if not fragment.begins_with("$"):
		return fragment
	var dot: int = fragment.find(".")
	var node_token: String = fragment.substr(1, (dot - 1) if dot >= 0 else fragment.length() - 1)
	var tail: String = fragment.substr(dot) if dot >= 0 else ""
	return "get_node_or_null(\"%s\")%s" % [node_token, tail]


## The span a caller should leave SELECTED after inserting a behaviour fragment, as
## (offset, length) into the snippet - the node token, so retargeting is one keystroke or a node
## drag. `$SineBehavior.magnitude` selects `$SineBehavior`; the robust form selects the quoted
## name inside get_node_or_null. (-1, 0) means nothing to select (not a node chain).
static func retarget_span(snippet: String) -> Vector2i:
	if snippet.begins_with("$"):
		var dot: int = snippet.find(".")
		return Vector2i(0, dot if dot >= 0 else snippet.length())
	const ROBUST_HEAD: String = "get_node_or_null(\""
	if snippet.begins_with(ROBUST_HEAD):
		var quote_end: int = snippet.find("\"", ROBUST_HEAD.length())
		if quote_end > ROBUST_HEAD.length():
			return Vector2i(ROBUST_HEAD.length(), quote_end - ROBUST_HEAD.length())
	return Vector2i(-1, 0)


## Whether this sheet creates objects at runtime (Spawn verbs or the ObjectPool vocabulary) -
## the sheets whose behaviour access should DEFAULT to the robust get_node_or_null form.
static func is_spawn_heavy(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var rows: Array = []
	rows.append_array(sheet.events)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry as EventFunction
			rows.append_array(event_function.events if not event_function.events.is_empty() else event_function.rows)
	return _rows_spawn(rows)


static func _rows_spawn(rows: Array) -> bool:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			if _rows_spawn(group.events if not group.events.is_empty() else group.rows):
				return true
		elif row is EventRow:
			var event: EventRow = row as EventRow
			for ace: Variant in event.conditions + event.actions:
				if not (ace is Resource):
					continue
				if str((ace as Resource).get("ace_id")).begins_with("SpawnScene"):
					return true
				if str((ace as Resource).get("provider_id")) == "ObjectPool":
					return true
			if _rows_spawn(event.sub_events):
				return true
	return false


## Every reachable sheet variable as an entry inserting its bare name (C3's Self.MyVariable is a
## bare member in GDScript). Same census the ƒx picker's Sheet Variables group uses.
static func variable_entries(sheet: EventSheetResource) -> Array:
	var out: Array = []
	if sheet == null:
		return out
	for entry: Dictionary in gather_sheet_variables(sheet):
		var name_str: String = str(entry.get("name", ""))
		var type_name: String = str(entry.get("type_name", ""))
		out.append({
			"label": name_str if type_name.is_empty() else "%s : %s" % [name_str, type_name],
			"fragment": name_str,
			"tooltip": "This sheet's own variable - inserts the bare name (C3's Self.%s)" % name_str,
		})
	return out


## The sheet's EXPRESSION functions (a value-returning function is an expression; void is an
## action row's job and bool is a condition - the same classifier the verb rows use). Inserts a
## ready call with the parameter names as placeholders: `dps()` / `damage_after(armor)`.
static func function_entries(sheet: EventSheetResource) -> Array:
	var out: Array = []
	if sheet == null:
		return out
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction):
			continue
		var event_function: EventFunction = entry as EventFunction
		if ViewportRowBuilder.define_role_for(event_function) != "expression":
			continue
		var arg_names: PackedStringArray = PackedStringArray()
		for parameter: Variant in event_function.params:
			if parameter is ACEParam:
				arg_names.append((parameter as ACEParam).get_param_name())
		var fragment: String = "%s(%s)" % [event_function.function_name, ", ".join(arg_names)]
		out.append({
			"label": "ƒ " + fragment,
			"fragment": fragment,
			"tooltip": "This sheet's own function - returns a value, so it slots into any expression.",
		})
	return out


## Splits a search query into (self-scoped?, remainder): "Self.X" -> (true, "x"), "self" ->
## (true, ""), "position" -> (false, "position"). Self-scoped queries filter WITHIN the Self
## section and hide the rest of the tree - the C3 "type Self. and browse" reflex.
static func normalize_query(query: String) -> Dictionary:
	var lowered: String = query.strip_edges().to_lower()
	for prefix: String in ["self.", "self"]:
		if lowered.begins_with(prefix):
			return {"self_scoped": true, "remainder": lowered.substr(prefix.length()).strip_edges()}
	return {"self_scoped": false, "remainder": lowered}


## Whether an entry survives a (lowered) filter: the label carries the C3 name and the fragment
## carries the GDScript, so both spellings find it.
static func entry_matches(entry: Dictionary, lowered_query: String) -> bool:
	if lowered_query.is_empty():
		return true
	return str(entry.get("label", "")).to_lower().contains(lowered_query) \
		or str(entry.get("fragment", "")).to_lower().contains(lowered_query)


## Nearest ClassDB ancestor of a host class name: an engine class answers itself; a custom
## `class_name` walks the project's global class list to its engine base; anything unresolvable
## degrades to Object (so only the Object-level commons remain - honest, never a guess).
static func resolve_engine_class(host_class: String) -> String:
	var current: String = host_class.strip_edges()
	var hops: int = 0
	while not current.is_empty() and hops < 32:
		if ClassDB.class_exists(current):
			return current
		var next_base: String = ""
		for global_class: Dictionary in ProjectSettings.get_global_class_list():
			if str(global_class.get("class", "")) == current:
				next_base = str(global_class.get("base", ""))
				break
		current = next_base
		hops += 1
	return "Object"


## Every reachable sheet variable as [{name, type_name}], deduped by name (dict entry wins).
## Merges the `variables` DICT (family/per-instance) with the TREE variables (LocalVariable rows
## recovered from an opened .gd - @export, State, and the host binding). Shared with the ƒx
## picker's Sheet Variables group so the two listings can never drift apart.
static func gather_sheet_variables(sheet: EventSheetResource) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if sheet.variables is Dictionary:
		for var_name: Variant in sheet.variables.keys():
			var name_str: String = str(var_name).strip_edges()
			if name_str.is_empty() or seen.has(name_str):
				continue
			seen[name_str] = true
			var vdef: Variant = sheet.variables[var_name]
			var vtype: String = str((vdef as Dictionary).get("type", "")).strip_edges() if vdef is Dictionary else ""
			out.append({"name": name_str, "type_name": vtype})
	var tree_vars: Array = []
	collect_tree_variables_into(sheet.events, tree_vars)
	for tree_var: Variant in tree_vars:
		if not (tree_var is LocalVariable):
			continue
		var local_variable: LocalVariable = tree_var as LocalVariable
		var name_str: String = local_variable.name.strip_edges()
		if name_str.is_empty() or seen.has(name_str):
			continue
		seen[name_str] = true
		out.append({"name": name_str, "type_name": local_variable.type_name.strip_edges()})
	return out


## Recursively collect every LocalVariable row (top-level, inside groups, and nested in
## sub-events). Mirrors SheetCompiler._collect_tree_variables so the census stays read-only.
static func collect_tree_variables_into(entries: Array, into: Array) -> void:
	for entry: Variant in entries:
		if entry is LocalVariable:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			collect_tree_variables_into(group.events if not group.events.is_empty() else group.rows, into)
		elif entry is EventRow:
			collect_tree_variables_into((entry as EventRow).sub_events, into)
