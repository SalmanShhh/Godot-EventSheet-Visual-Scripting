# EventForge - the stack and queue spellings, and the row each one means.
#
# A stack pushes and pops at the back and a queue pushes at the back and pops at the front. Written
# by hand they are plain Array calls, so each one opens as the row that writes it:
#
#     var last = undo_stack.pop_back()                      Pop back of undo_stack into last
#     var job: Callable = jobs.pop_front()                  Pop front of jobs into job
#     var last = undo_stack.pop_back() if not undo_stack.is_empty() else Vector2i(-1, -1)
#                                                           ... or Vector2i(-1, -1) if empty
#     redo_stack.append_array(undo_stack)                   Move all of undo_stack to redo_stack
#     undo_stack.clear()
#     var __swap_ab12 = hand                                Swap hand with $Enemy.hand
#     hand = $Enemy.hand
#     $Enemy.hand = __swap_ab12
#     trail.append(point)                                   Push back point to trail, keeping the last 20
#     while trail.size() > 20:
#         trail.pop_front()
#
# The pop is the one hand-written matcher here, because the line carries a type the row does not hold
# as a value: `var last: Vector2i = ...` is the same row as `var last = ...`, and the type rides on the
# baked template so the author's own bytes come back. The three runs are table entries, asked by the
# run seam before any single line of them is looked at alone.
#
# WHAT IS DELIBERATELY NOT CLAIMED. A swap through any temporary that is not spelled `__swap...` (a
# hand-written `var tmp = a` swap of two numbers is not a swap of two lists), a trim written with `if`
# or `remove_at(0)` instead of `while` and `pop_front`, and a pop whose fallback builds a scene (the
# pooled spawn reading owns that line). Each stays exactly what it was.
@tool
class_name EventForgeStackLift
extends RefCounted

const POP_BACK_ACE_ID: String = "ArrayPopBackInto"
const POP_FRONT_ACE_ID: String = "ArrayPopFrontInto"

## The two pop rows, by the Array call each one writes.
const POP_ACE_IDS: Dictionary = {"pop_back": POP_BACK_ACE_ID, "pop_front": POP_FRONT_ACE_ID}

## The list a row names: a sheet variable, another object's array (`$Enemy.draw_pile`,
## `%Deck.cards`), a member path. One spelling for every pattern here, so a change reaches them all.
const LIST: String = "[$%A-Za-z_][A-Za-z0-9_$%./]*"

const _POP_PATTERN: String = "^var (?<name>[A-Za-z_][A-Za-z0-9_]*)(?:: (?<type>[A-Za-z_][A-Za-z0-9_.]*(?:\\[[^\\]]*\\])?))? = (?<list>" \
	+ LIST + ")\\.(?<end>pop_back|pop_front)\\(\\)(?: if not \\k<list>\\.is_empty\\(\\) else (?<fallback>.+))?$"

static var _pop_regex: RegEx = null
static var _entries: Array[Dictionary] = []


## The row a pop line means, or {} when this does not claim it. {ace_id, provider, params, template}:
## the template is empty for the spelling the row's own template writes (so the row keeps following
## its descriptor) and carries the type for a typed local.
static func match_line(line: String) -> Dictionary:
	if not (line.contains(".pop_back()") or line.contains(".pop_front()")):
		return {}
	if _pop_regex == null:
		_pop_regex = RegEx.create_from_string(_POP_PATTERN)
	var hit: RegExMatch = _pop_regex.search(line)
	if hit == null:
		return {}
	var fallback: String = hit.get_string("fallback")
	# The pooled spawn (`pool.pop_back() if not pool.is_empty() else SCENE.instantiate()`) has its own
	# reading, which asks for exactly this line.
	if fallback.ends_with(".instantiate()"):
		return {}
	var ace_id: String = str(POP_ACE_IDS[hit.get_string("end")])
	var template: String = ""
	if not hit.get_string("type").is_empty():
		template = typed_template(canonical_template(ace_id), hit.get_string("type"))
	return {
		"ace_id": ace_id,
		"provider": "Core",
		"params": {"var_name": hit.get_string("list"), "name": hit.get_string("name"), "fallback": fallback},
		"template": template
	}


## The template a pop row's descriptor writes, read from the registry so there is one copy of it.
static func canonical_template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else descriptor.codegen_template


## A pop template with its local given a type: `var {name} = ...` becomes `var {name}: Vector2i = ...`.
## Untouched when `type` is blank or the template does not open on the local, so an untyped array
## gives the untyped local it always did.
static func typed_template(template: String, type: String) -> String:
	var clean: String = type.strip_edges()
	if clean.is_empty() or not template.begins_with("var {name} = "):
		return template
	return "var {name}: %s = %s" % [clean, template.substr("var {name} = ".length())]


## Whether the trim's limit is a COUNT (a number, a variable, a call, arithmetic) and not a longer test: a
## `while history.size() > 2 and <something else>:` trims by a rule the row cannot say, so it stays the
## While it is.
static func keeps_a_count(captures: Dictionary) -> bool:
	var limit: String = str(captures.get("keep", ""))
	for word: String in [" and ", " or ", " not ", "<", ">", "==", "!="]:
		if limit.contains(word):
			return false
	return true


## The three runs, as lift-table entries.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_swap_entry(), _move_all_entry(), _keep_last_entry(), _append_once_entry(), _set_from_group_entry(), _drop_freed_entry()]
	return _entries


## The row a run of statements means, or {} when nothing here claims it.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## Swap A with B: the temporary the sheet wrote (`__swap_<id>`), then the two writes. The temporary's
## name and its `:=` ride along as the author wrote them; they are not values of the row.
static func _swap_entry() -> Dictionary:
	return {
		"id": "array_swap",
		"ace_id": "ArraySwap",
		"mark": "var __swap",
		"statements": [
			{"pattern": "^var (?<temp>__swap[A-Za-z0-9_]*) :?= (?<var_name>" + LIST + ")$"},
			{"pattern": "^(?<var_name>" + LIST + ") = (?<other>" + LIST + ")$"},
			{"pattern": "^(?<other>" + LIST + ") = (?<temp>__swap[A-Za-z0-9_]*)$"}
		],
		"params": ["var_name", "other"],
		"shape": "var __swap_a1 = {var_name}\n{var_name} = {other}\n{other} = __swap_a1",
		"slots": {"var_name": "draw_pile", "other": "$Enemy.draw_pile"}
	}


## Move all of A to B: B takes every item of A, in order, and A is emptied.
static func _move_all_entry() -> Dictionary:
	return {
		"id": "array_move_all",
		"ace_id": "ArrayMoveAll",
		"mark": ".append_array(",
		"statements": [
			{"pattern": "^(?<other>" + LIST + ")\\.append_array\\((?<var_name>" + LIST + ")\\)$"},
			{"pattern": "^(?<var_name>" + LIST + ")\\.clear\\(\\)$"}
		],
		"params": ["var_name", "other"],
		"shape": "{other}.append_array({var_name})\n{var_name}.clear()",
		"slots": {"var_name": "redo_stack", "other": "undo_stack"}
	}


## Push back a value, keeping the last N: the append, then the trim from the front.
static func _keep_last_entry() -> Dictionary:
	return {
		"id": "array_append_keeping",
		"ace_id": "ArrayAppendKeeping",
		"mark": ".append(",
		"statements": [
			{"pattern": "^(?<var_name>" + LIST + ")\\.append\\((?<value>.+)\\)$"},
			{"pattern": "^while (?<var_name>" + LIST + ")\\.size\\(\\) > (?<keep>.+):$"},
			{"pattern": "^(?<var_name>" + LIST + ")\\.pop_front\\(\\)$", "indent": 1}
		],
		"guard": Callable(EventForgeStackLift, "keeps_a_count"),
		"params": ["var_name", "value", "keep"],
		"shape": "{var_name}.append({value})\nwhile {var_name}.size() > {keep}:\n\t{var_name}.pop_front()",
		"slots": {"var_name": "trail", "value": "global_position", "keep": "20"}
	}


## Push back, once: the has test, then the append under it.
static func _append_once_entry() -> Dictionary:
	return {
		"id": "array_append_once",
		"ace_id": "ArrayAppendOnce",
		"mark": ".has(",
		"statements": [
			{"pattern": "^if not (?<var_name>" + LIST + ")\\.has\\((?<value>.+)\\):$"},
			{"pattern": "^(?<var_name>" + LIST + ")\\.append\\((?<value>.+)\\)$", "indent": 1}
		],
		"params": ["var_name", "value"],
		"shape": "if not {var_name}.has({value}):\n\t{var_name}.append({value})",
		"slots": {"var_name": "selected", "value": "unit"}
	}


## Set a list to the instances of a group that pass a test.
static func _set_from_group_entry() -> Dictionary:
	return {
		"id": "array_set_from_group",
		"ace_id": "ArraySetFromGroup",
		"mark": ".assign(get_tree()",
		"statements": [
			{"pattern": "^(?<var_name>" + LIST + ")\\.assign\\(get_tree\\(\\)\\.get_nodes_in_group\\((?<group>.+?)\\)\\.filter\\(func\\(one\\): return (?<test>.+)\\)\\)$"}
		],
		"params": ["var_name", "group", "test"],
		"shape": "{var_name}.assign(get_tree().get_nodes_in_group({group}).filter(func(one): return {test}))",
		"slots": {"var_name": "selected", "group": "\"units\"", "test": "box.has_point(one.position)"}
	}


## Drop the instances that were freed.
static func _drop_freed_entry() -> Dictionary:
	return {
		"id": "array_drop_freed",
		"ace_id": "ArrayDropFreed",
		"mark": "is_instance_valid",
		"statements": [
			{"pattern": "^(?<var_name>" + LIST + ")\\.assign\\(\\k<var_name>\\.filter\\(is_instance_valid\\)\\)$"}
		],
		"params": ["var_name"],
		"shape": "{var_name}.assign({var_name}.filter(is_instance_valid))",
		"slots": {"var_name": "selected"}
	}
