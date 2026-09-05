# EventForge module - Ownership: who made this, said once for the whole project.
#
# A bullet hits, an enemy dies, and the sheet cannot say who fired. Kill credit, assists, friendly
# fire, "killed by" on the death screen and a boss that turns on whoever hurt it last all need the
# same one fact: the owner of the thing that hit. Written privately on a bullet scene it is a field
# only that scene knows; written here it is ONE key every row can read.
#
# THE CONTRACT, in full, because rows that agree on a key owe the reader the key:
#   * the key is node metadata named `owner`, and nothing else in this module writes anything else;
#   * `Claim` sets it, `Disown` removes it, and a node that was never claimed simply has no key;
#   * the CHAIN is what makes it worth having - a bullet is owned by the turret, the turret by the
#     player - so the reading rows walk it: the nearest owner is Claimed By, the far end is Root
#     Owner Of, and the three comparison rows ask about ROOT owners on both sides, which is what
#     makes "same source" one idea rather than three.
#
# The walk is bounded at OWNER_CHAIN_LIMIT links, for two reasons that are one reason: an expression
# has no loop to write, and a chain that somehow points at itself must still answer rather than hang.
# Eight is far past any real chain (bullet, turret, player is three) and stops a cycle dead.
#
# Everything compiles to plain `set_meta` / `get_meta` / `has_meta` calls with zero plugin
# references, which is what lets a hand-written project read back as these rows.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeOwnershipACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const OWNERSHIP := "Ownership"

## How many links up the chain a reading row walks before it stops asking. An expression cannot
## write a loop, so the walk is a fold over this many steps - past the end it simply keeps the
## answer it already has, so a two-link chain costs the same answer as an eight-link one.
const OWNER_CHAIN_LIMIT: int = 8


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_writing(descriptors)
	_reading(descriptors)
	_asking(descriptors)
	return descriptors


## The far end of one node's owner chain, as a single expression - the fragment every reading and
## comparison row is built from, so the three can never drift into disagreeing about what "the
## source of this" means. `%s` is the node the walk starts at.
##
## It folds rather than loops because an expression has nowhere to declare a local: each step
## replaces the node it holds with that node's owner, and a step that finds no owner keeps what it
## has, so the answer settles on the root and stays there for the remaining steps.
##
## The node RIDES THE ARRAY as its first element rather than being passed as reduce's starting
## value, which is not a style choice: reduce reads a starting value of `null` as "no starting value
## given" and folds from the first element instead, so a row asking about a node that has been freed
## would answer with the number 0. Seeded this way the walk names the node once and answers nothing
## for nothing.
##
## A STEP THAT LANDS ON SOMETHING FREED ANSWERS NOTHING, which is the other half of that promise and
## the half a real game reaches first: the player dies while their bullet is still in the air, and
## the enemy that bullet kills would otherwise hand a row under On Death a previously-freed object to
## read a name off. The walk stops with nothing instead, and a sheet asks about nothing the way it
## asks about anything else - `is nothing`, or a field left empty.
static func root_owner_expression(node_text: String) -> String:
	return "([%s] + range(%d)).reduce(func(__own: Variant, __step: int) -> Variant: return __own.get_meta(&\"owner\") if is_instance_valid(__own) and __own.has_meta(&\"owner\") else (__own if is_instance_valid(__own) else null))" % [node_text, OWNER_CHAIN_LIMIT]


## The two rows that WRITE the key. Claim is the whole gesture - a spawn row, a trap being armed, a
## summon arriving - and Disown is what a pool does when the node goes back on the shelf.
static func _writing(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("Claim", "Claim", "{node}.set_meta(&\"owner\", {owner})", OWNERSHIP, "Claim [i]{node}[/i] for [i]{owner}[/i]", "Marks a node as belonging to somebody - the bullet you just fired, the trap you armed, the minion you summoned. Every ownership row in the project reads what this writes, so kill credit, assists and friendly fire all come from this one line. Claiming again simply replaces the owner.").param_typed("Node", "node", "self", "Node", "The thing being claimed - usually the node that was just spawned.", "scene_node").param_typed("Node", "owner", "self", "Owner", "Who it belongs to. Left as it is, that is the node running this row - the shooter, the turret, the trap.", "expression").featured())
	descriptors.append(F.act("Disown", "Disown", "\n".join(PackedStringArray([
		"if {node}.has_meta(&\"owner\"):",
		"\t{node}.remove_meta(&\"owner\")"
	])), OWNERSHIP, "Disown [i]{node}[/i]", "Takes the owner off a node, so it belongs to nobody again. A recycled node carries no credit from its last life, which is why a pool disowns on the way back to the shelf; a dropped weapon that anyone may pick up is the same idea.").param_typed("Node", "node", "self", "Node", "The node that stops belonging to anyone.", "scene_node"))


## The two rows that READ it. Both are values, so both drop into any other row's field.
static func _reading(descriptors: Array[ACEDescriptor]) -> void:
	# The key is ASKED FOR before it is read, rather than read with a fallback: Godot reads a `null`
	# fallback as "no fallback given" and errors on a node that was never claimed, which is the
	# ordinary case this row has to answer quietly. The owner it finds is asked about too, because a
	# turret that has been blown up must read as nothing rather than as a freed object.
	descriptors.append(F.expr("ClaimedBy", "Claimed By", "({node}.get_meta(&\"owner\") if is_instance_valid({node}) and {node}.has_meta(&\"owner\") and is_instance_valid({node}.get_meta(&\"owner\")) else null)", OWNERSHIP, "who claimed [i]{node}[/i]", "The node that claimed this one, one step up - the turret that fired the bullet, not the player behind the turret. Reads as nothing when it was never claimed, and when the owner itself has gone. For the far end of the chain, use Root Owner Of.").param_typed("Node", "node", "self", "Node", "The node whose owner is being read.", "scene_node"))
	descriptors.append(F.expr("RootOwnerOf", "Root Owner Of", "(%s)" % root_owner_expression("{node}"), OWNERSHIP, "root owner of [i]{node}[/i]", "The far end of the owner chain: bullet to turret to player answers with the player. This is the one a kill feed, a score row and an assist list all want, because it is the person rather than the thing they were holding. A node nobody claimed answers with itself, and a chain whose far end has been freed answers with nothing.").param_typed("Node", "node", "self", "Node", "The node the chain is walked from.", "scene_node").featured())


## The three rows that ASK about it. All three compare ROOT owners on both sides, so a bullet, the
## turret that fired it and the player behind the turret are one answer rather than three.
##
## TWO WALKS THAT END NOWHERE ARE NOT THE SAME OWNER, which is why each row carries a third fold.
## A chain whose far end has been freed answers with nothing, by design - and `null == null` is
## true, so a bullet whose player has died hitting an enemy whose spawner has been freed used to
## read as "mine" and have its hit refused as friendly fire against a total stranger. Being the
## same is now being the same SOMEBODY; the guard reads the other way round, because a hit whose
## ownership cannot be established is a hit on a stranger and must land.
static func _asking(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("IsOwnedBy", "Is Owned By", "(%s == %s and %s != null)" % [root_owner_expression("{node}"), root_owner_expression("{owner}"), root_owner_expression("{node}")], OWNERSHIP, "[i]{node}[/i] is owned by [i]{owner}[/i]", "True while a node traces back to the owner you name. Both sides are walked to the root, so a bullet fired by a turret the player built counts as the player's - and as the turret's, because the turret traces back to the same person.").param_typed("Node", "node", "self", "Node", "The thing being asked about.", "scene_node").param_typed("Node", "owner", "self", "Owner", "Who it should trace back to.", "expression"))
	descriptors.append(F.cond("IsMine", "Is Mine", "(%s == %s and %s != null)" % [root_owner_expression("{node}"), root_owner_expression("self"), root_owner_expression("self")], OWNERSHIP, "[i]{node}[/i] is mine", "True while a node traces back to the same owner this row does - my bullet, my turret, my summon, or me. The friendly half of the pair: Hit Is Not My Owner is the same question asked the other way.").param_typed("Node", "node", "self", "Node", "The thing being asked about.", "scene_node"))
	descriptors.append(F.cond("HitIsNotMyOwner", "Hit Is Not My Owner", "(%s != %s or %s == null)" % [root_owner_expression("{hit}"), root_owner_expression("self"), root_owner_expression("self")], OWNERSHIP, "hit [i]{hit}[/i] is not my owner", "The friendly-fire guard, for any hit trigger: true while the thing that was hit does not trace back to whoever fired this. Put the trigger's own collider in the field - the bullet stops shooting the player who fired it, and the turret that player built, without a single flag.").param_suggesting("hit", "self", "Hit", "What was hit - the collider, body or area the trigger above handed you.", ["collider", "body", "area", "hit"] as Array[String], "expression").featured())
