# EventForge module - Systems vocabulary (composition / ECS-lite queries over groups).
#
# The building blocks of the "entities = nodes in a group, systems = events that run over that group"
# pattern (see the composition guide). A group is a set of entities; these ACEs query or act on every
# member, or on the ones that are in TWO groups at once (an archetype intersection, like "alive AND
# poisoned"). They compile to the exact plain Godot you would hand-write - get_nodes_in_group + filter -
# with zero plugin references, honouring the parity covenant. This is composition, not a real ECS: it is
# node iteration, so keep group sizes reasonable and prefer triggers over polling for big sets. Grouped
# under "Systems"; the everyday tag / count / roll-up group ACEs live under "Groups".
@tool
class_name EventForgeCompositionACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Systems"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Query a single group as a set of entities ──
	descriptors.append(F.expr("NodesInGroup", "Entities In Group", "get_tree().get_nodes_in_group({group})", CAT, "entities in {group}", "Every node in a group, as an array - loop it with For Each to run a system over that entity type.").param("group", "\"enemies\"", "Group", "The group name (your entity type).", "group_reference").featured())
	descriptors.append(F.cond("AnyInGroup", "Any Entity In Group", "not get_tree().get_nodes_in_group({group}).is_empty()", CAT, "any entity in {group}", "True when at least one node is in the group (any entity of that type exists).").param("group", "\"enemies\"", "Group", "The group name.", "group_reference"))

	# ── Archetype intersection: entities in BOTH groups (the "has both components" query) ──
	descriptors.append(F.expr("NodesInBothGroups", "Entities In Both Groups", "get_tree().get_nodes_in_group({group_a}).filter(func(__entity: Node) -> bool: return __entity.is_in_group({group_b}))", CAT, "entities in {group_a} and {group_b}", "Every node that is in BOTH groups at once, as an array (an archetype like alive AND poisoned).").param("group_a", "\"enemies\"", "Group A", "First group.", "expression").param("group_b", "\"poisoned\"", "Group B", "Second group.", "expression"))
	descriptors.append(F.expr("CountInBothGroups", "Count In Both Groups", "get_tree().get_nodes_in_group({group_a}).filter(func(__entity: Node) -> bool: return __entity.is_in_group({group_b})).size()", CAT, "count in {group_a} and {group_b}", "How many nodes are in both groups at once.").param("group_a", "\"enemies\"", "Group A", "First group.", "expression").param("group_b", "\"poisoned\"", "Group B", "Second group.", "expression"))
	descriptors.append(F.expr("FirstInBothGroups", "First In Both Groups", "get_tree().get_nodes_in_group({group_a}).filter(func(__entity: Node) -> bool: return __entity.is_in_group({group_b})).front()", CAT, "first in {group_a} and {group_b}", "The first node in both groups, or nothing if there is none.").param("group_a", "\"enemies\"", "Group A", "First group.", "expression").param("group_b", "\"boss\"", "Group B", "Second group.", "expression"))
	descriptors.append(F.cond("IsInBothGroups", "Is In Both Groups", "({node}.is_in_group({group_a}) and {node}.is_in_group({group_b}))", CAT, "{node} is in {group_a} and {group_b}", "True when an entity belongs to both groups (has both tags/components).").param_typed("Node", "node", "self", "Entity", "The node to test.", "expression").param("group_a", "\"enemies\"", "Group A", "First group.", "expression").param("group_b", "\"poisoned\"", "Group B", "Second group.", "expression"))

	# ── A system in one row: call a method on every tagged entity ──
	descriptors.append(F.act("CallOnTagged", "Run On Tagged Entities", "for __entity_{uid}: Node in get_tree().get_nodes_in_group({group}):\n\tif __entity_{uid}.is_in_group({tag}) and __entity_{uid}.has_method({method}):\n\t\t__entity_{uid}.call({method})", CAT, "run {method} on {group} that are {tag}", "Calls a method on every entity in a group that also has a tag - a whole system in one action.").param("group", "\"enemies\"", "Group", "The entity type to run over.", "group_reference").param("tag", "\"stunned\"", "Also In", "Only entities also in this group (leave as a tag/component).", "group_reference").param("method", "\"tick\"", "Method", "The method to call on each (your system's step).", "expression"))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Composition / ECS-lite helpers: treat a group as a set of entities and query or act on every member, or the ones in two groups at once. The building blocks of a system that runs over a group each frame."}
