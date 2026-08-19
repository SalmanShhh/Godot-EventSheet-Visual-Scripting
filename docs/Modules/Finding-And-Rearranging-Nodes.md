# Finding And Rearranging Nodes

Every Godot game is a tree of nodes, and most gameplay logic is one of two sentences: **"put this
thing here"** or **"find me that thing"**. This builtin vocabulary covers both, so the everyday tree work -
spawning a bullet under the level, freeing a dead enemy, grabbing the nearest target, reading a
child's name - never forces a drop into a GDScript block.

They divide into four families:

- **Building and rearranging** - Add Child, Remove Child, Move Child To Index, Free Node, Queue Free,
  Set Node Name, Duplicate Node, Clone Into, Reparent To.
- **Reading a node** - Node Name, Node Path, Index In Parent, Is Inside Tree, Get Parent, Get Child
  Count, Get Child (by index), Find Child (by name), Get Node Or Null, Has Node, Get Scene Owner,
  Is Ancestor Of, Current Scene Root.
- **Picking** - the expressions that hand you a node or a list of nodes: by class, by name pattern, by
  group, by distance, or by the largest or smallest value of a property.
- **Metadata** - a private key/value shelf on any node, for the little bit of state that does not
  deserve a variable.

Every one compiles to the exact native call. **Node Name** ships as `{target}.name` and nothing more.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Spawning** - instance something, then Add Child it where it belongs.
- **Cleaning up** - Queue Free the enemy that just died, safely, at the end of the frame.
- **Draw order** - Move Child To Index puts the player in front of the fence.
- **Picking up and carrying** - Reparent To keeps the on-screen position while changing parents.
- **Copying live things** - Clone Into duplicates, adds, places and tags in one row.
- **Reaching a component without a brittle path** - First Child Of Type finds the AnimationPlayer
  wherever it sits.
- **Targeting** - Nearest Node In Group is the auto-aim primitive; Group Member With Smallest
  Property is "attack the weakest".
- **Random selection** - a random spawn point, a random patrol node, safely on an empty group.
- **Defensive checks** - Has Node and Get Node Or Null instead of a crash when a child is missing.
- **Per-node bookkeeping** - Set Metadata remembers a spawn point, an owner, a resting height.

## Core concepts

- **Almost every row here takes a Target.** Its default is `self`, so a row means "this node" until you
  point it somewhere else. That is why Get Parent, Node Name and Set Metadata all read naturally on
  the sheet's own host and still work on any node you hand them.
- **Free at the end of the frame, not now.** Free Node and Queue Free both use `queue_free`, so the
  node is removed once the frame finishes. Anything still holding the node this frame keeps a valid
  reference, which is exactly what makes it safe.
- **Duplicate gives you a copy; it does not place it.** Duplicate Node is an EXPRESSION - it hands you
  a clone that is not in the tree yet. Add Child puts it there. Clone Into is the one-row form when
  you want copy plus add plus place plus group in a single action.
- **Reparent keeps the transform.** Reparent To moves the node under a new parent and preserves its
  global position, which is what makes "pick up an item into the player's hand" one row.
- **Picking by TYPE beats picking by path.** Find Children Of Type, First Child Of Type and Has Child
  Of Type walk the whole subtree by class name, so "the Area2D of this object" survives someone
  reorganising the scene. `$A/B/C/D` does not.
- **A group is a flat set, and picking from it is a one-liner.** Nodes In Group is the list; Nearest
  Node In Group, Furthest Node In Group, Random Node In Group and the two property picks are reduce
  expressions over that list. Every one of them answers **nothing** on an empty group rather than
  erroring - with one exception, noted in the tips.
- **Metadata is invisible state on a node.** Set Metadata, Get Metadata, Has Metadata and Remove
  Metadata are Godot's own `set_meta` family. Nothing declares them in advance, and they travel with
  the node, which is why several builtin rows quietly use metadata for their own bookkeeping.

## Reference tables

Every `{target}` parameter defaults to `self`.

### Building and rearranging

| Name | What it does | Ships as |
|------|--------------|----------|
| Add Child | Attaches another node as a child of this one at runtime | `add_child({node})` |
| Remove Child | Detaches a child without deleting it | `remove_child({node})` |
| Move Child To Index | Reorders a child, changing draw and process order | `move_child({node}, {index})` |
| Free Node | Safely deletes a node at the end of the frame | `{target}.queue_free()` |
| Queue Free | Removes THIS node safely at the end of the frame | `queue_free()` |
| Set Node Name | Renames a node at runtime | `{target}.name = {name}` |
| Duplicate Node | Clones a node so you can add the copy elsewhere | `{target}.duplicate()` |
| Reparent To | Moves this node under a new parent, keeping its on-screen position | `reparent({new_parent})` |
| Clone Into | Copy, add, place and optionally group a live node in one row | see below |

**Clone Into** is the multi-line one. Its parameters are `Copy` (the live node, default `self`),
`Into` (default `get_parent()`), `At` (a world position) and `Group` (blank for none):

```gdscript
var __clone_figure = self.duplicate()
get_parent().add_child(__clone_figure)
if __clone_figure is Node2D or __clone_figure is Node3D or __clone_figure is Control:
	__clone_figure.global_position = Vector2(0, 0)
if not str("coins").is_empty():
	__clone_figure.add_to_group(StringName("coins"), true)
```

The group is added with `true`, meaning persistent, because a non-persistent group vanishes when a
node is packed into a scene and every later group check then silently never fires.

### Reading a node

| Name | What it does | Ships as |
|------|--------------|----------|
| Node Name | The node's name as text | `{target}.name` |
| Node Path | The node's full path in the scene tree | `{target}.get_path()` |
| Index In Parent | The node's position among its siblings | `{target}.get_index()` |
| Is Inside Tree | True when the node is part of the active scene tree | `{target}.is_inside_tree()` |
| Current Scene Root | The root node of the currently running scene | `get_tree().current_scene` |
| Get Parent | The node directly above this one | `{target}.get_parent()` |
| Get Child Count | How many direct children a node has | `{target}.get_child_count()` |
| Get Child (by index) | The child at a position number, starting from zero | `{target}.get_child({index})` |
| Find Child (by name) | A child matching a name pattern, wildcards allowed | `{target}.find_child({pattern})` |
| Get Node Or Null | The node at a path, or nothing instead of an error | `{target}.get_node_or_null({path})` |
| Has Node | True when a node exists at the given path | `{target}.has_node({path})` |
| Get Scene Owner | The scene this node was saved as part of | `{target}.owner` |
| Is Ancestor Of | True when this node is somewhere above the other one | `{target}.is_ancestor_of({node})` |

### Picking

| Name | What it does | Ships as |
|------|--------------|----------|
| Get Children | The list of a node's direct children | `{target}.get_children()` |
| Find Children (by name) | Every descendant whose name matches a pattern | `{target}.find_children({pattern}, "", true, false)` |
| Find Children Of Type | Every descendant of a given class | `{target}.find_children("*", {type}, true, false)` |
| First Child Of Type | The first descendant of a given class, or nothing | `{target}.find_children("*", {type}, true, false).pop_front()` |
| Has Child Of Type | True when at least one descendant of that class exists | `not {target}.find_children("*", {type}, true, false).is_empty()` |
| Nodes In Group | Every node belonging to a named group | `get_tree().get_nodes_in_group({group})` |
| Random Node In Group | A randomly chosen member of a group | `get_tree().get_nodes_in_group({group}).pick_random()` |
| Random Node In Group (empty-safe) | The same, but nothing instead of an error when empty | `get_tree().get_nodes_in_group({group}).pick_random() if not get_tree().get_nodes_in_group({group}).is_empty() else null` |
| Nearest Node In Group | The closest member of a group to this node | a `reduce` over the group comparing `global_position.distance_to` |
| Furthest Node In Group | The farthest member of a group from this node | the same `reduce`, comparing the other way |
| Group Member With Smallest Property | The member whose named property is lowest | a `reduce` comparing `__n.get({property})` |
| Group Member With Largest Property | The member whose named property is highest | the same `reduce`, comparing the other way |

Nearest Node In Group and Furthest Node In Group are filed under Node2D, because they measure from
this node's `global_position`. All four reduce-based picks return nothing on an empty group.

### Metadata

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Metadata | Stores a custom named value on an object | `{target}.set_meta({name}, {value})` |
| Get Metadata | Reads a stored metadata value back | `{target}.get_meta({name})` |
| Has Metadata | True when the object has metadata under that key | `{target}.has_meta({name})` |
| Remove Metadata | Deletes a stored metadata value by key | `{target}.remove_meta({name})` |

### Asking the tree by name

The replacement for the fragile node path the Project Doctor already scolds you for. A node
publishes itself under a **role** name once, and every other row asks for that name - no path, no
`$../../`, and no crash after a scene reload. The shelf is metadata on the SceneTree itself, so
there is no autoload to install and nothing survives between two runs of the game.

Registering a name again REPLACES it, and a node that has been freed answers as nothing at all,
because both readers test `is_instance_valid` first. That is deliberately all the bookkeeping there
is: a registration that erased itself when its node left the tree would, in the ordinary
scene-reload order, delete the entry belonging to the node that had already replaced it.

| Name | What it does | Ships as |
|------|--------------|----------|
| Register As Service | Publishes this node under a short name anything can ask for | `get_tree().set_meta(&"__ef_services", …)`, and nothing else - both readers refuse a freed node |
| Service Named | The node published under a name, or nothing when it is gone | `get_tree().get_meta(&"__ef_services", {}).get({service_name}, null)` guarded by `is_instance_valid` |
| Has Service | True when a node is registered under this name and still alive | `is_instance_valid(…get({service_name}, null))` |
| For Each Node That Can | Loops the event's actions once per node ANYWHERE in the tree that answers to a method name | the tree root plus `find_children("*", "", true, false)`, filtered by `has_method({method_name})` |

**For Each Node That Can** is a loop ROW in the condition lane, not an action: its items arrive as
`node`, and the per-item work is the event's actions. It walks the whole tree, so run it on an
event - a save sweep, a pause sweep, a shutdown sweep - never every frame.

## Use cases

**1. Spawn a bullet under the level, not under the gun.** Adding it to the gun would make it inherit
the gun's rotation forever.

```gdscript
func _on_fired() -> void:
	var bullet = preload("res://bullet.tscn").instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = $Muzzle.global_position
```

**2. Remove a dead enemy.** Free Node aimed at another node, or Queue Free on this one.

```gdscript
func _on_health_depleted() -> void:
	queue_free()
```

**3. Put the player in front of the scenery.** Index 0 draws first, so a high index draws last.

```gdscript
func _ready() -> void:
	get_parent().move_child(self, get_parent().get_child_count() - 1)
```

**4. Pick an item up into the player's hand.** Reparent To keeps it exactly where it was on screen,
then you place it deliberately.

```gdscript
func _on_picked_up(hand: Node) -> void:
	reparent(hand)
	position = Vector2.ZERO
```

**5. Put it back down in the world.** The same action, aimed at the current scene root.

```gdscript
func _on_dropped() -> void:
	reparent(get_tree().current_scene)
```

**6. Detach a node without destroying it.** Remove Child takes it out of the tree; it is still alive
and can be added somewhere else later.

```
On stow item
  -> Inventory: Remove Child  get_child(0)
```

**7. Copy a live decoration.** Clone Into does duplicate plus add plus place plus tag in one row.

```
On stamp pressed
  -> Clone Into  Copy: $Decoration  Into: $Level  At: get_global_mouse_position()  Group: "decor"
```

**8. Name a spawned node so you can find it later.**

```gdscript
func _on_spawned(minion: Node) -> void:
	minion.name = "Minion_%d" % _count
```

**9. Reach the AnimationPlayer without a path.** First Child Of Type walks the subtree by class.

```gdscript
func _on_hit() -> void:
	var player = find_children("*", "AnimationPlayer", true, false).pop_front()
	if player != null:
		player.play(&"hurt")
```

**10. Only run the fancy version when the component exists.** Has Child Of Type is the gate.

```gdscript
func _ready() -> void:
	if not find_children("*", "Area2D", true, false).is_empty():
		set_process(true)
```

**11. Turn off every light in a room.** Find Children Of Type returns the whole list to loop.

```gdscript
func _on_blackout() -> void:
	for light in find_children("*", "PointLight2D", true, false):
		light.enabled = false
```

**12. A defensive read.** Get Node Or Null hands back nothing instead of erroring when the optional
child was left out of a variant scene.

```gdscript
func _ready() -> void:
	var banner = get_node_or_null("Banner")
	if banner != null:
		banner.show()
```

**13. Auto-aim at the closest enemy.**

```gdscript
func _process(delta: float) -> void:
	var target = get_tree().get_nodes_in_group("enemies").reduce(func(__acc, __n): return __n if __acc == null or global_position.distance_to(__n.global_position) < global_position.distance_to(__acc.global_position) else __acc, null)
	if target != null:
		look_at(target.global_position)
```

**14. Attack the weakest.** Group Member With Smallest Property compares a named property on each
member, so any group carrying `hp` works.

```gdscript
func _on_choose_target() -> void:
	_target = get_tree().get_nodes_in_group("enemies").reduce(func(__acc, __n): return __n if __acc == null or __n.get("hp") < __acc.get("hp") else __acc, null)
```

**15. Spawn at a random point, safely.** The empty-safe form answers nothing rather than erroring when
the group has no members yet.

```gdscript
func _on_spawn_timer_timeout() -> void:
	var point = get_tree().get_nodes_in_group("spawns").pick_random() if not get_tree().get_nodes_in_group("spawns").is_empty() else null
	if point != null:
		_spawn_at(point.global_position)
```

**16. A wave counter.** Count the group without touching any node.

```
Every second
  -> set Label text = str(get_tree().get_nodes_in_group("enemies").size())
```

Nodes In Group hands you the array. If counting is all you need, Groups, Tags And Systems has a
dedicated Count Nodes In Group expression.

**17. Remember where something started.** Metadata is a shelf on the node itself, so no variable has
to be declared and nothing has to be wired in _ready.

```gdscript
func _ready() -> void:
	set_meta("home", global_position)


func _on_reset() -> void:
	if has_meta("home"):
		global_position = get_meta("home")
```

**18. Tag a spawned enemy with who summoned it.**

```gdscript
func _on_summoned(minion: Node) -> void:
	minion.set_meta("summoner", self)
```

**19. Clear a one-off marker once it has been used.**

```gdscript
func _on_consumed() -> void:
	if has_meta("charge"):
		remove_meta("charge")
```

**20. Check a parent relationship before allowing a drop.** Is Ancestor Of stops an inventory panel
being dropped into one of its own slots.

```gdscript
func _can_drop(node: Node) -> bool:
	return not node.is_ancestor_of(self)
```

**21. Report a node honestly in a debug label.**

```gdscript
func _process(delta: float) -> void:
	$Debug.text = "%s  #%d  %s" % [name, get_index(), str(get_path())]
```

**22. Publish the player under a role name, once, on ready.** Every HUD, menu and ability afterwards
asks for `"player"` instead of walking a path that a scene reorganise will quietly break.

```gdscript
extends Node


func _ready() -> void:
	var services: Dictionary = get_tree().get_meta(&"__ef_services", {})
	services["player"] = self
	get_tree().set_meta(&"__ef_services", services)
```

**23. Heal whoever is registered as the player.** The healing row never learns where the player node
lives in the tree.

```gdscript
extends Node


func _on_heal_pressed() -> void:
	get_tree().get_meta(&"__ef_services", {}).get("player", null).heal(25)
```

**24. Make an optional system genuinely optional.** Has Service answers no when the audio director
was never added to this build, and the row is simply skipped.

```gdscript
extends Node


func _on_boss_started() -> void:
	if is_instance_valid(get_tree().get_meta(&"__ef_services", {}).get("audio_director", null)):
		play_music("boss")
```

**25. Split-screen without two divergent path sets.** Each player registers under its own role, and
the same HUD sheet is instanced twice pointing at different names.

```gdscript
extends Node


func _ready() -> void:
	var services: Dictionary = get_tree().get_meta(&"__ef_services", {})
	services["player_2"] = self
	get_tree().set_meta(&"__ef_services", services)
```

**26. Sweep every system that can save itself.** The list of savers is a question you ask, not a list
you maintain.

```gdscript
extends Node


func _on_quit_requested() -> void:
	for node: Node in get_tree().get_root().find_children("*", "", true, false):
		if node.has_method("save_state"):
			node.call("save_state")
```

**27. Pause everything that knows how to pause.** A node that does not implement the method is
skipped, which is what makes the sweep safe to run in a half-built scene.

```gdscript
extends Node


func _on_pause_pressed() -> void:
	for node: Node in get_tree().get_root().find_children("*", "", true, false):
		if node.has_method("on_game_paused"):
			node.call("on_game_paused")
```

**28. Ask for a service that has been freed.** The guard is why this answers nothing instead of
crashing, which is the entire difference from holding a node reference across a scene reload.

```gdscript
extends Node


func _process(_delta: float) -> void:
	var boss: Object = get_tree().get_meta(&"__ef_services", {}).get("boss", null)
	$BossBar.visible = is_instance_valid(boss)
```

### Other use cases

**Layered spawn ordering.** Spawn every enemy into one container, then Move Child To Index by their Y position each frame, and you have painter-style depth sorting with no Z index maths.

**A pooled projectile.** Remove Child instead of Free Node when a bullet leaves the screen, keep it in an array, and Add Child it again on the next shot so nothing is ever allocated mid-fight.

**Scene-variant tolerance.** Guard every optional decoration with Has Node so one shared script drives three level variants that each leave out different children.

**Escort formation.** Furthest Node In Group finds the straggler in the party, so the leader can slow down until the group closes up.

**Debug tree dump on demand.** Get Children plus Node Name in a For Each writes a readable one-line listing of any container into the output, which beats scrolling the remote tree while the game runs.

## Tips and common mistakes

- **Random Node In Group ERRORS on an empty group.** `pick_random()` on an empty array is a runtime
  error. That is exactly why **Random Node In Group (empty-safe)** exists as a separate expression. If the
  group can ever be empty - and a group of enemies always can - use the empty-safe one.
- **A freed node is not gone until the frame ends.** Queue Free schedules the removal. Reading the
  node's properties on the very next row still works, and that is deliberate. What you must not do is
  keep the reference across frames.
- **Duplicate Node does not add anything.** It is an expression. Its own help says to add the clone
  with Add Child. If your duplicate never appears, that is why - or reach for Clone Into instead.
- **A group added without `persistent` disappears when a scene is packed.** Clone Into passes `true`
  for you. If you tag nodes yourself in a tool script, pass it too, or every later group check will
  silently find nothing.
- **Move Child To Index is about siblings, not about the whole scene.** Index 0 is the first child of
  THAT parent. Moving a node to index 0 does not put it behind things that live under a different
  parent.
- **Reparent To keeps the global transform on purpose.** A node that seems not to have moved after
  reparenting has behaved correctly. Set its local position afterwards if you wanted it snapped.
- **Find Child (by name) searches by pattern and can be slow in a deep tree.** It is fine on a hit or
  a menu press; it is not something to run for every enemy every frame. Cache the result.
- **Find Children Of Type takes the class name as text.** `"AnimationPlayer"`, `"Area2D"`,
  `"Sprite2D"`. A typo compiles happily and simply finds nothing, so check the spelling against the
  node's class in the Inspector.
- **The property picks read the property by NAME.** Group Member With Smallest Property calls
  `get("hp")` on each member. A member that does not have that property answers null, and comparing
  null against a number is a runtime error, so keep the group homogeneous.
- **Nearest and Furthest need a 2D position.** They are filed under Node2D because they read
  `global_position`. On a 3D host the same reduce shape works, but you will be writing it in a
  GDScript block.
- **Metadata keys are strings and nobody validates them.** `set_meta("home", ...)` and
  `get_meta("Home")` are different shelves. Guard reads with Has Metadata, or read through an
  expression that takes a fallback.
- **Get Scene Owner is not Get Parent.** The owner is the scene a node was SAVED as part of, which for
  a node spawned at runtime is often nothing at all.
