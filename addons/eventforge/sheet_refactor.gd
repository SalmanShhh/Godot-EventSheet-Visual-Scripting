# Godot EventSheets - model-level refactors (True Rename)
#
# Word-boundary symbol rename across every surface a name can appear in:
# the variables key itself, LocalVariable rows, ACE param values and comments,
# raw-code rows (row- and ACE-level), pick filters, trigger args, other variables'
# attribute strings (show_if etc.), function names and bodies - and comments/prose,
# deliberately (a rename should keep prose honest; the opposite trade from the
# doctor's usage detection, which excludes comments).
#
# What it never touches: codegen templates, preludes and member declarations -
# those are machine-baked from descriptors and substitute params at compile time;
# a variable named "value" must not rewrite a `{value}` placeholder (covenant:
# refactors rewrite sheet model text, never baked machinery).
@tool
class_name EventSheetRefactor
extends RefCounted


## "" when the rename is allowed, else the user-facing problem.
static func validate_new_name(sheet: EventSheetResource, old_name: String, new_name: String) -> String:
	if not new_name.is_valid_identifier():
		return "\"%s\" is not a valid identifier." % new_name
	if new_name == old_name:
		return "That's already the name."
	if sheet.variables.has(new_name):
		return "A variable named \"%s\" already exists." % new_name
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == new_name:
			return "A function named \"%s\" already exists." % new_name
	return ""


## Renames a variable or function across the sheet. Returns the replacement count
## (0 = the symbol appears nowhere, including as a declaration).
##
## `skip_string_literals` leaves text INSIDE quotes alone. Rename Everywhere wants the default
## (an author renaming a concept means the prose too), but a caller substituting a value - inlining
## a verb's parameter with the argument passed at the call site - must not rewrite the sentences the
## body prints: `print("who is out")` is displayed text, not a reference to the parameter.
static func rename_symbol(sheet: EventSheetResource, old_name: String, new_name: String, skip_string_literals: bool = false) -> int:
	if sheet == null or old_name.is_empty():
		return 0
	var counter: Dictionary = {"count": 0, "skip_string_literals": skip_string_literals}
	var regex: RegEx = RegEx.create_from_string("\\b%s\\b" % old_name)
	# The declaration itself: a sheet-variables key (order preserved - Dictionaries
	# keep insertion order, so rebuild in place)…
	if sheet.variables.has(old_name):
		var rebuilt: Dictionary = {}
		for key: Variant in sheet.variables:
			rebuilt[new_name if str(key) == old_name else key] = sheet.variables[key]
		sheet.variables = rebuilt
		counter["count"] = int(counter["count"]) + 1
	# …or a function name.
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry
			if event_function.function_name == old_name:
				event_function.function_name = new_name
				counter["count"] = int(counter["count"]) + 1
			_rename_in_rows(event_function.events if not event_function.events.is_empty() else event_function.rows, regex, new_name, counter)
	# Attribute strings on every variable may reference the symbol (show_if, on_changed…).
	for key: Variant in sheet.variables:
		var descriptor: Variant = sheet.variables[key]
		if descriptor is Dictionary:
			_rename_in_dictionary(descriptor, regex, new_name, counter)
	_rename_in_rows(sheet.events, regex, new_name, counter)
	return int(counter["count"])


## The node-reference token grammar shared by collect + replace: $Path, $"Quoted/Path",
## and %UniqueName. `self` is handled separately (whole-value only - it appears inside
## countless expressions where a blind swap would corrupt them).
const NODE_REF_PATTERN := "\\$\"[^\"]*\"|\\$[A-Za-z_][A-Za-z0-9_/]*|%[A-Za-z_][A-Za-z0-9_]*"


## Every node reference appearing in the given rows - params, With-Node scopes, pick
## filters, raw GDScript - plus "self" when a whole param value is exactly that. Sorted;
## this is the Replace Object dialog's "from" list.
static func collect_node_references(rows: Array) -> Array[String]:
	var found: Dictionary = {}
	var token_regex: RegEx = RegEx.create_from_string(NODE_REF_PATTERN)
	_collect_refs_in_rows(rows, token_regex, found)
	var out: Array[String] = []
	for reference: Variant in found:
		out.append(str(reference))
	out.sort()
	return out


## The suggestion pool for retarget fields (the Replace Object References "To" box):
## every reference the SHEET already uses, plus the edited scene's own nodes - direct
## children as $Name (quoted when the name isn't a plain identifier) and every
## scene-unique node as %Name - plus `self`. Pure given its inputs, so tests pin it
## headless with a hand-built scene root.
static func reference_suggestions(rows: Array, scene_root: Node = null) -> Array[String]:
	var suggestions: Array[String] = collect_node_references(rows)
	if scene_root != null:
		for child: Node in scene_root.get_children():
			var token: String = _node_reference_token(str(child.name))
			if not suggestions.has(token):
				suggestions.append(token)
		_collect_unique_name_tokens(scene_root, suggestions)
	if not suggestions.has("self"):
		suggestions.append("self")
	return suggestions


static func _node_reference_token(node_name: String) -> String:
	if node_name.is_valid_identifier():
		return "$%s" % node_name
	return "$\"%s\"" % node_name


static func _collect_unique_name_tokens(node: Node, suggestions: Array[String]) -> void:
	for child: Node in node.get_children():
		if child.unique_name_in_owner:
			var token: String = "%" + str(child.name)
			if not suggestions.has(token):
				suggestions.append(token)
		_collect_unique_name_tokens(child, suggestions)


static func _collect_refs_in_rows(rows: Array, token_regex: RegEx, found: Dictionary) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			_collect_refs_in_text((row as RawCodeRow).code, token_regex, found)
		elif row is EventGroup:
			var group: EventGroup = row
			_collect_refs_in_rows(group.events if not group.events.is_empty() else group.rows, token_regex, found)
		elif row is EventRow:
			var event: EventRow = row
			if not event.with_node_target.strip_edges().is_empty():
				_collect_refs_in_text(event.with_node_target, token_regex, found)
				if event.with_node_target.strip_edges() == "self":
					found["self"] = true
			for ace: Variant in event.conditions + event.actions:
				if ace is RawCodeRow:
					_collect_refs_in_text((ace as RawCodeRow).code, token_regex, found)
				elif ace is Resource and ace.get("params") is Dictionary:
					var params: Dictionary = ace.get("params")
					for key: Variant in params:
						if params[key] is String:
							_collect_refs_in_text(str(params[key]), token_regex, found)
							if str(params[key]).strip_edges() == "self":
								found["self"] = true
			for pick: Variant in event.pick_filters:
				if pick is PickFilter:
					_collect_refs_in_text((pick as PickFilter).collection_value, token_regex, found)
					_collect_refs_in_text((pick as PickFilter).predicate_expression, token_regex, found)
			_collect_refs_in_rows(event.sub_events, token_regex, found)


static func _collect_refs_in_text(text: String, token_regex: RegEx, found: Dictionary) -> void:
	for token_match: RegExMatch in token_regex.search_all(text):
		found[token_match.get_string(0)] = true


## Token-safe replace of ONE node reference across the rows (the Replace Object gesture):
## $Enemy never touches $EnemySpawner (an identifier-boundary guard), quoted paths match
## literally, and "self" swaps only where a whole value IS self - never inside an
## expression. Returns the number of replacements.
static func replace_node_reference(rows: Array, from_ref: String, to_ref: String) -> int:
	if from_ref.strip_edges().is_empty() or from_ref == to_ref:
		return 0
	var counter: Dictionary = {"count": 0}
	if from_ref == "self":
		_replace_whole_value_refs(rows, "self", to_ref, counter)
		return int(counter["count"])
	var guarded: String = "%s(?![A-Za-z0-9_/])" % _regex_escape(from_ref)
	var regex: RegEx = RegEx.create_from_string(guarded)
	if regex == null:
		return 0
	_rename_in_rows(rows, regex, to_ref, counter)
	_replace_scope_refs(rows, regex, to_ref, counter)
	return int(counter["count"])


## With-Node scopes sit outside _rename_in_rows' fields - swept separately.
static func _replace_scope_refs(rows: Array, regex: RegEx, to_ref: String, counter: Dictionary) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_replace_scope_refs(group.events if not group.events.is_empty() else group.rows, regex, to_ref, counter)
		elif row is EventRow:
			var event: EventRow = row
			event.with_node_target = _rename_text(event.with_node_target, regex, to_ref, counter)
			_replace_scope_refs(event.sub_events, regex, to_ref, counter)


## The conservative self-swap: only param values / scopes that ARE exactly "self".
static func _replace_whole_value_refs(rows: Array, from_value: String, to_ref: String, counter: Dictionary) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_replace_whole_value_refs(group.events if not group.events.is_empty() else group.rows, from_value, to_ref, counter)
		elif row is EventRow:
			var event: EventRow = row
			if event.with_node_target.strip_edges() == from_value:
				event.with_node_target = to_ref
				counter["count"] = int(counter["count"]) + 1
			for ace: Variant in event.conditions + event.actions:
				if ace is Resource and ace.get("params") is Dictionary:
					var params: Dictionary = ace.get("params")
					for key: Variant in params:
						if params[key] is String and str(params[key]).strip_edges() == from_value:
							params[key] = to_ref
							counter["count"] = int(counter["count"]) + 1
			_replace_whole_value_refs(event.sub_events, from_value, to_ref, counter)


## Minimal regex escaping for reference tokens ($, quotes, and path characters).
static func _regex_escape(text: String) -> String:
	var escaped: String = ""
	for character: String in text:
		if character in ["\\", "^", "$", ".", "|", "?", "*", "+", "(", ")", "[", "]", "{", "}"]:
			escaped += "\\" + character
		else:
			escaped += character
	return escaped


static func _rename_in_rows(rows: Array, regex: RegEx, new_name: String, counter: Dictionary) -> void:
	for row: Variant in rows:
		if row is CommentRow:
			(row as CommentRow).text = _rename_text((row as CommentRow).text, regex, new_name, counter)
		elif row is RawCodeRow:
			(row as RawCodeRow).code = _rename_text((row as RawCodeRow).code, regex, new_name, counter)
		elif row is LocalVariable:
			var local: LocalVariable = row
			if regex.search(local.name) != null:
				local.name = _rename_text(local.name, regex, new_name, counter)
			if local.default_value is String:
				local.default_value = _rename_text(str(local.default_value), regex, new_name, counter)
		elif row is EventGroup:
			var group: EventGroup = row
			group.description = _rename_text(group.description, regex, new_name, counter)
			_rename_in_rows(group.events if not group.events.is_empty() else group.rows, regex, new_name, counter)
		elif row is EventRow:
			var event: EventRow = row
			event.trigger_args = _rename_text(event.trigger_args, regex, new_name, counter)
			for ace: Variant in event.conditions + event.actions:
				if ace is RawCodeRow:
					(ace as RawCodeRow).code = _rename_text((ace as RawCodeRow).code, regex, new_name, counter)
				elif ace is CommentRow:
					(ace as CommentRow).text = _rename_text((ace as CommentRow).text, regex, new_name, counter)
				elif ace is Resource and ace.get("params") is Dictionary:
					_rename_in_dictionary(ace.get("params") as Dictionary, regex, new_name, counter)
					if ace.get("comment") is String:
						ace.set("comment", _rename_text(str(ace.get("comment")), regex, new_name, counter))
			for pick: Variant in event.pick_filters:
				if pick is PickFilter:
					(pick as PickFilter).collection_value = _rename_text((pick as PickFilter).collection_value, regex, new_name, counter)
					(pick as PickFilter).predicate_expression = _rename_text((pick as PickFilter).predicate_expression, regex, new_name, counter)
			_rename_in_rows(event.sub_events, regex, new_name, counter)


## Rewrites String values in place (recursing into nested Dictionaries - variable
## attributes live one level down).
static func _rename_in_dictionary(values: Dictionary, regex: RegEx, new_name: String, counter: Dictionary) -> void:
	for key: Variant in values:
		var value: Variant = values[key]
		if value is String:
			values[key] = _rename_text(value, regex, new_name, counter)
		elif value is Dictionary:
			_rename_in_dictionary(value, regex, new_name, counter)


## One line of GDScript with every whole-word `old_name` rewritten to `new_name`, leaving anything
## inside a string literal alone (a printed sentence is displayed text, not a reference). The
## compiler rewrites a Static local's uses onto its hoisted member through here, and the importer
## rewrites them back - one implementation, so the two directions cannot drift.
static func rename_in_code(code: String, old_name: String, new_name: String) -> String:
	if code.is_empty() or not old_name.is_valid_identifier() or old_name == new_name:
		return code
	return _rename_text(code, RegEx.create_from_string("\\b%s\\b" % old_name), new_name,
		{"count": 0, "skip_string_literals": true})


static func _rename_text(text: String, regex: RegEx, new_name: String, counter: Dictionary) -> String:
	var found: Array[RegExMatch] = regex.search_all(text)
	if found.is_empty():
		return text
	# The mask is only computed when a caller asked for literal-safety, so the everyday rename pays
	# nothing for it.
	var mask: PackedByteArray = _string_literal_mask(text) if bool(counter.get("skip_string_literals", false)) 		else PackedByteArray()
	# Manual back-to-front splice instead of regex.sub: sub() treats "$" in the
	# replacement as a backreference marker, which would eat node references like
	# "$EliteEnemy". Renames are always literal here.
	var out: String = text
	for match_index: int in range(found.size() - 1, -1, -1):
		var found_match: RegExMatch = found[match_index]
		var start: int = found_match.get_start()
		if start < mask.size() and mask[start] == 1:
			continue
		counter["count"] = int(counter["count"]) + 1
		out = out.substr(0, start) + new_name + out.substr(found_match.get_end())
	return out


## One byte per character: 1 where the character sits inside a quoted string literal (the quotes
## themselves included), 0 everywhere else. Single and double quotes both open a literal, a
## backslash escapes the next character, and an unterminated quote runs to the end of the text -
## which is the safe direction, since the point is to leave displayed prose alone.
static func _string_literal_mask(text: String) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(text.length())
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if quote.is_empty():
			if character == "\"" or character == "'":
				quote = character
				mask[index] = 1
		else:
			mask[index] = 1
			if character == "\\":
				index += 1
				if index < text.length():
					mask[index] = 1
			elif character == quote:
				quote = ""
		index += 1
	return mask


# ── R2: a region and a group are the same idea said two ways ───────────────────────────────────
#
# Both directions are ONE edit on the container the rows already live in, and nothing inside moves:
# the byte change is the two fence lines against the one group. A group carries two things a region
# cannot - local variables and the runtime switch - so the group-to-region direction refuses with a
# reason instead of quietly dropping them.


## Turns a matched `#region` / `#endregion` pair into an EventGroup holding the rows between them.
## The fences go; the region's name, description and colour become the group's. Returns the new
## group, or null when this row is not an opening fence that closes in the same container.
static func region_to_group(container: Array, opener: CustomBlockRow) -> EventGroup:
	var opener_index: int = container.find(opener)
	if opener_index == -1 or not EventSheetRegionFacts.is_opening_fence(opener):
		return null
	var paired: Dictionary = EventSheetRegionFacts.pairing(container)["pairs"]
	if not paired.has(opener_index):
		return null
	var closer_index: int = int(paired[opener_index])
	var group := EventGroup.new()
	group.group_name = EventSheetRegionFacts.label(opener)
	if group.group_name.is_empty():
		group.group_name = "Group"
	group.name = group.group_name
	group.description = EventSheetRegionFacts.description(opener)
	var accent: String = EventSheetRegionFacts.accent_hex(opener)
	if not accent.is_empty():
		group.custom_color = Color.html(accent)
	for index: int in range(opener_index + 1, closer_index):
		group.events.append(container[index] as Resource)
	for _removed: int in range(closer_index - opener_index + 1):
		container.remove_at(opener_index)
	container.insert(opener_index, group)
	return group


## "" when this group can become a region, else the reason it cannot - said in the words the menu
## item itself wears, so the refusal is read BEFORE the click rather than after it.
static func group_to_region_problem(group: EventGroup) -> String:
	if group == null:
		return "no group here"
	var locals: int = 0
	for entry: Variant in group.local_variables:
		if entry is LocalVariable:
			locals += 1
	if locals > 0:
		return "has %d local" % locals if locals == 1 else "has %d locals" % locals
	if group.runtime_toggleable:
		return "can be switched at runtime"
	if not group.enabled:
		return "is switched off"
	return ""


## Turns an EventGroup into a `#region` / `#endregion` pair around the rows it held. The group's
## header goes; its name, description and colour ride the opening fence. False when the group is not
## in this container or carries something a region cannot (see group_to_region_problem).
static func group_to_region(container: Array, group: EventGroup) -> bool:
	var at: int = container.find(group)
	if at == -1 or not group_to_region_problem(group).is_empty():
		return false
	var opener := CustomBlockRow.new()
	opener.kind_id = EventSheetRegionFacts.KIND_ID
	opener.fields = {"label": group.display_name(), "is_end": false}
	if not group.description.strip_edges().is_empty():
		opener.fields["description"] = group.description.strip_edges()
	if group.custom_color.a > 0.01:
		opener.fields["color"] = "#%s" % group.custom_color.to_html(false)
	var closer := CustomBlockRow.new()
	closer.kind_id = EventSheetRegionFacts.KIND_ID
	closer.fields = {"label": "", "is_end": true}
	var held: Array[Resource] = group.child_rows()
	container.remove_at(at)
	var insert_at: int = at
	container.insert(insert_at, opener)
	insert_at += 1
	for entry: Resource in held:
		container.insert(insert_at, entry)
		insert_at += 1
	container.insert(insert_at, closer)
	return true


## Drops both fences and leaves everything they held exactly where it was. Returns how many rows
## were kept, or -1 when this row is not an opening fence that closes in the same container.
static func remove_region_keep_rows(container: Array, opener: CustomBlockRow) -> int:
	var opener_index: int = container.find(opener)
	if opener_index == -1 or not EventSheetRegionFacts.is_opening_fence(opener):
		return -1
	var paired: Dictionary = EventSheetRegionFacts.pairing(container)["pairs"]
	if not paired.has(opener_index):
		return -1
	var closer_index: int = int(paired[opener_index])
	container.remove_at(closer_index)
	container.remove_at(opener_index)
	return closer_index - opener_index - 1
