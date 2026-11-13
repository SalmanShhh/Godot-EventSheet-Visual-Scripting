# Building Nodes While The Game Runs

A game is a tree of nodes, and a running game can grow that tree. `Node2D.new()` makes a node,
`add_child` puts it in the tree, `queue_free` takes it out again. The Building rows say those calls as
sentences, for the things a game makes by hand most often: a node of any type, a behaviour, a sprite,
a collision shape, a timer, and the two rows that keep a result - a group that survives being packed,
and a whole branch kept as a prefab in a variable.

These are builtin rows, available from any sheet with nothing to enable. Every template compiles to
the lines a Godot user would have typed: `Type.new()`, `add_child`, `get_node_or_null`,
`remove_child`, `queue_free`, `PackedScene.pack`. Nothing here has a plugin dependency at runtime.

Making a copy of a scene you already built is a different job with its own page: the Instantiate row
and its family are in Spawning Copies Of Scenes, and moving or freeing nodes that already exist is in
Finding And Rearranging Nodes. This page is for the nodes that have no scene file at all.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **A bullet, a pickup, a marker** that is one node and a shape, with no scene file to keep in sync.
- **A power-up that adds a behaviour** to the player for a while and takes it away again.
- **A debris field** of sprites made from a list of pictures.
- **A trigger zone** made in code: an Area2D with a circle shape the size the level asks for.
- **A countdown** that starts itself and calls a function every few seconds.
- **A built enemy kept as a prefab**, so the next copy is one Instantiate away.
- **A level the player assembled**, packed into a PackedScene without losing its groups.

## Core concepts

- **The new node goes under the running scene by default.** Add New Node says so in its Under field
  (`get_tree().current_scene`). Change the field to put it anywhere else, or to `self` to keep it
  with this node.
- **A name is a real variable.** Add New Node and Add Behaviour keep what they made in a variable you
  name, and every row after them in the same event can say that name. The parts rows (sprite, shape,
  timer) make a part and carry on, so they do not name one.
- **A script node made with `.new()` is called "Node".** Godot names it after its native class, not
  after the `class_name` of its script, so `get_node("JetpackBehavior")` finds nothing. Add Behaviour
  names the node after its class itself, which is what Godot's own Add Child Node does.
- **Only one, or allow another.** Add Behaviour looks for a child with that name first. Only one keeps
  it when it is already there and uses that one; Allow another adds a new one every time.
- **Nothing owns a node you add at run time.** A scene file holds only the nodes its root owns, so a
  built node is simply not in a packed copy. Keep As Prefab lends ownership for the pack and gives it
  back, which is why it can run twice on the same branch.
- **`add_to_group(name)` is forgotten by a pack.** A group added without the second argument is not
  saved with the scene. Add To Group (Saved With Scene) writes `add_to_group(name, true)`, the form a
  packed copy keeps.
- **The type field is Godot's own Create New Node window.** Pick a node type or one of your script
  classes from the list, or type the name. A script class goes in by its `class_name`.
- **A script class whose `_init` wants arguments is not made by these rows.** `Type.new()` passes
  none. Make it with a Set Property row or a function of your own.

## Reference tables

Ships as is the template the row compiles to. Where a template carries `{uid}`, the editor bakes a
short per-row id into the local's name when you drop the row, so two of the same row in one script
never collide.

### Making nodes

| Name | What it does | Ships as |
|------|--------------|----------|
| Add New Node | Makes a node of any type, optionally names it, adds it under a parent and keeps it in a variable | `var {name} := {type}.new()` then `add_child` |
| Add Behaviour | Adds a behaviour as a child named after its class, keeping the node in a variable | `get_node_or_null` first, else `{behaviour}.new()` and `add_child` |
| Remove Behaviour | Takes a behaviour off a node, and does nothing when it is not there | `remove_child` then `queue_free` |

### Parts

| Name | What it does | Ships as |
|------|--------------|----------|
| Add Sprite | Adds a Sprite2D showing a picture | `Sprite2D.new()`, `texture`, `add_child` |
| Add Sprite (3D) | Adds a Sprite3D showing a picture | `Sprite3D.new()`, `texture`, `add_child` |
| Add Circle Shape | Adds a CollisionShape2D holding a circle | `CircleShape2D.new()` and its `radius` |
| Add Rectangle Shape | Adds a CollisionShape2D holding a rectangle | `RectangleShape2D.new()` and its `size` |
| Add Capsule Shape | Adds a CollisionShape2D holding a capsule | `CapsuleShape2D.new()`, `radius` and `height` |
| Add Sphere Shape (3D) | Adds a CollisionShape3D holding a sphere | `SphereShape3D.new()` and its `radius` |
| Add Box Shape (3D) | Adds a CollisionShape3D holding a box | `BoxShape3D.new()` and its `size` |
| Add Capsule Shape (3D) | Adds a CollisionShape3D holding a capsule | `CapsuleShape3D.new()`, `radius` and `height` |
| Add Timer | Adds a Timer that starts itself and calls a function every time it runs out | `Timer.new()`, `autostart`, `timeout.connect` |

### Keeping what was made

| Name | What it does | Ships as |
|------|--------------|----------|
| Add To Group (Saved With Scene) | Puts a node in a group that a packed copy keeps | `add_to_group({group}, true)` |
| Keep As Prefab | Packs a node and everything under it into a PackedScene variable | an owner walk, `PackedScene.pack`, the ownership given back |

### Rows that already exist for the rest

| Name | What it does | Ships as |
|------|--------------|----------|
| Instantiate | Makes a copy of a scene file, names it and places it | `scene.instantiate()` then `add_child` |
| Add Child | Adds a node you already made under this one | `add_child({node})` |
| Add Child (existing node) | Moves a node that is already in the scene under a new parent | `reparent` |
| Free Node | Frees a node at the end of the frame | `queue_free()` |
| Add To Group | Tags a node, forgotten by a packed copy | `add_to_group({group})` |
| Save Data Asset | Writes a resource, such as the prefab a row kept, to a file | `ResourceSaver.save` |

## Use cases

**1. A bullet with no scene file.** On the fire key, Add New Node of type Node2D named "Bullet" under the running scene into `bullet`, then Add Sprite and Add Circle Shape on `bullet`. Three rows, one throwaway object.

**2. A pickup dropped where an enemy died.** Add New Node of type Area2D into `pickup`, add a Circle Shape of radius 12 to it, then put it in the "pickups" group.

**3. A power-up that adds a behaviour.** On pickup, Add Behaviour "JetpackBehavior" to the player with Only one, so a second pickup does not stack a second jetpack.

**4. A power-up that wears off.** After a Wait, Remove Behaviour "JetpackBehavior" from the player. If it is already gone the row does nothing.

**5. A shield made of a sprite.** Add Sprite showing the shield picture to the player. When the shield ends, Free Node on it; the sprite lives under the player, so it goes with the player too.

**6. A trigger zone sized by the level.** Add New Node of type Area2D into `zone`, then Add Rectangle Shape with the size the level data gives, to `zone`.

**7. A character built in code.** Add New Node of type CharacterBody2D into `hero`, then a Capsule Shape, then a Sprite, all added to `hero`.

**8. A countdown that calls a function.** Add Timer to this node every 2 seconds, calling `_on_wave`. It starts itself and keeps going.

**9. A fuse.** Add Timer every 0.5 seconds calling `blink` to the bomb. The timer is a child of the bomb, so it is freed with it and needs no row of its own.

**10. A debris field.** For each picture in a list, Add Sprite showing it to the level, then place it with the rows that follow.

**11. A 3D pickup.** Add New Node of type Area3D into `crate`, add a Box Shape of size 1, 1, 1 to it and a Sprite (3D) for its picture.

**12. A group that survives packing.** Use Add To Group (Saved With Scene) for any group a packed copy must still belong to. A plain Add To Group is gone from the copy.

**13. Keep an enemy as a prefab.** Build the enemy from the rows above, then Keep As Prefab into the `enemy_prefab` variable. The next one is an Instantiate away.

**14. A level the player built.** Keep As Prefab the level root into `built_level`, then Save Data Asset with that variable and a `user://` path.

**15. A second copy of a built node.** Instantiate with the Scene field set to `enemy_prefab`, the variable the prefab was kept in.

**16. A behaviour on every enemy.** For Each enemy in the "enemies" group, Add Behaviour "PatrolBehavior" with Only one, so it is safe to run again.

**17. A named marker.** Add New Node of type Marker2D named "Spawn" under the level, so a later row can find it with `get_node("Spawn")`.

**18. A helper node that is not in the scene.** Add New Node of type Node under `self` into `helper`, set it up with Set Property rows, and free it with Free Node when done.

### Other use cases

**A tutorial arrow that appears.** Add Sprite with the arrow picture to the player when the hint opens, and Free Node on it when the hint closes.

**A one-off collision probe.** Add Circle Shape to a new Area2D, read what it overlaps, and free it in the same event.

**A prefab for the level editor.** Keep As Prefab a built prop, then Instantiate it wherever the player clicks.

**A repeating spawner with no scene.** Add Timer every few seconds calling a function that makes a node with Add New Node.

**A behaviour a menu toggles.** Add Behaviour when a setting is on and Remove Behaviour when it is off, both safe to repeat.

## Tips and common mistakes

- **Add Behaviour names the node after the class.** Do not rename it afterwards unless Remove Behaviour is told the same name.
- **Remove Behaviour looks for the class name.** A behaviour added by hand under another name is not found; the row then does nothing.
- **A shape needs a body to belong to.** Add it to a physics body or an Area; Godot warns when a shape sits under a plain node.
- **A row without a Called name keeps Godot's name for the node.** Two nodes of one type under one parent get different names automatically, but a later `get_node` cannot know which is which.
- **Add Timer's starting callable does nothing on purpose.** Type the name of one of this sheet's functions in the Calling field.
- **Adding to the scene inside its own `_ready` can fail.** Godot is still busy setting the scene's children up; add on the next frame, or put the row in a later trigger.
- **Keep As Prefab needs the node to be in the scene.** A node that was never added cannot be packed, and the row reports it in the debugger.
- **Declare the prefab variable as a PackedScene.** Keep As Prefab writes the variable; it does not declare it.
- **Instances stay instances.** A node that came from another scene file is saved into the prefab as that scene, not as a copy of its insides.
