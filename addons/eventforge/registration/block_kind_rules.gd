# EventForge - the words and the rule for refusing a block kind registration.
#
# Loaded by path, only when a registration arrives, so the registry stays small on the first-open
# path. A kind is refused when its id belongs to a built-in kind or when the id is already taken;
# the built-in case is the one that matters most, because a plugin registers before anything has
# asked the registry for anything, and used to be able to replace a built-in kind for the session.
@tool
extends RefCounted


## Why a kind with `kind_id` would be refused, in the words a caller reads, or "" when it is accepted.
## `registered` is the registry's kind table and `built_in_ids` the ids the built-in kinds hold.
static func refusal(kind_id: String, registered: Dictionary, built_in_ids: Array) -> String:
	if built_in_ids.has(kind_id):
		return "EventSheets: the block kind id '%s' belongs to a built-in kind and cannot be replaced. Choose a different kind_id, such as 'my_pack.%s'." % [kind_id, kind_id]
	if registered.has(kind_id):
		return "EventSheets: duplicate block kind_id '%s' ignored." % kind_id
	return ""
