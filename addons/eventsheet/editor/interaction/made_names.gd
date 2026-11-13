# Godot EventSheets - the rows that make a node and name it.
#
# A row that makes a node declares a real local variable for it (`var new_enemy = Enemy.instantiate()`),
# so the name it was given is a name the rows after it can say. This is the one table of those rows and
# of the parameter that carries each one's name, read by the autocomplete chips (which offer the name in
# a field) and by the pick scope (which offers the thing the name stands for as an object).
#
# Constants only and no class_name, so loading it costs nothing and neither reader needs the other.
@tool
extends RefCounted

## The rows that name a new node, and the parameter each one names it in. Kept as data rather than as an
## `if` chain so a row added later is offered the moment it says which parameter carries its name.
const NAME_PARAMS: Dictionary = {
	"SpawnNewCopy": "name",
	"SpawnNewCopy3D": "name",
	"SpawnNewCopyDeferred": "name",
	"SpawnNewCopyDeferred3D": "name",
	"SpawnNewCopyDeferredWorld": "name",
	"SpawnNewCopyDeferredWorld3D": "name",
	"MakeNewCopy": "name",
	"SpawnIntoCrowd": "name",
	"SpawnIntoCrowdOldestFirst": "name",
	"SpawnIntoCrowdUnlessFull": "name",
	# The launched twin, which declares its local exactly as its frozen neighbour does. Its formation
	# sibling is deliberately NOT here: the name a formation gives a copy lives INSIDE the loop the
	# row writes, so it is gone by the time the next row runs and offering it would be offering a
	# name that cannot be said. The whole formation is addressed by its crowd instead.
	"SpawnFacingAndMoving": "name",
	"SpawnFacingAndMoving3D": "name",
	# A copy of the node's own scene declares its local exactly as the safe spawn it is written from.
	"SpawnCopyOfSelf": "name",
	"SpawnCopyOfSelf3D": "name",
	# And the free-spot spawn, which binds its name ABOVE the branch precisely so the rows underneath
	# can say it. The name is simply nothing when the arena was full, which is the question Is Still
	# Here answers - so the name is worth offering and worth guarding, not worth hiding.
	"SpawnInFreeSpot": "name",
	"SpawnInFreeSpot3D": "name",
	# The Building rows that keep what they made in a variable.
	"AddNewNodeInto": "name",
	"AddBehaviourInto": "name",
}

## The parameter that SAYS what type the node is, for the rows that are given a type directly. A row
## not listed here is a copy of a scene, and its type is the root of the scene its `scene` field names.
const TYPE_PARAMS: Dictionary = {
	"AddNewNodeInto": "type",
	"AddBehaviourInto": "behaviour",
}

## The parameter a copy-of-a-scene row names its scene in.
const SCENE_PARAM: String = "scene"
