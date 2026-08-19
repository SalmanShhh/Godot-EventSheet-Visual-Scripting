# Working In 3D

The 3D half of the builtin vocabulary: move, turn, scale and drive a Node3D; run a CharacterBody3D with
velocity and Move And Slide; push a RigidBody3D; switch cameras and set a field of view; and build
geometry at runtime with the primitive mesh builders. Every row here wraps a native Godot 3D call, so
the engine maintains the behaviour and the sheet only names it.

These rows are builtin - no pack to enable, nothing to attach. They compile to plain GDScript with no
plugin reference left behind.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **First-person and third-person controllers** - velocity, slide, a floor check, a jump.
- **Grey-box prototyping**, where the level is boxes and ramps you make at runtime.
- **Camera work** - swapping between cameras, zooming a field of view for a sprint or a scope.
- **Turrets, lookers and cutscene framing** with a one-row Look At.
- **Physics props** in 3D, launched with an impulse.
- **Procedural layouts** where meshes are made, sized and placed from data.
- **Placeholder characters** built from a capsule while the real art is still being made.
- **Rings, ramps and pillars** as torus, prism and cylinder meshes with no modelling.
- **Recolouring at runtime** by swapping a mesh's material.
- **Fitting and spacing** driven by a mesh's real measured size.

## Core concepts

- **Y is up in 3D, and up is positive.** In 2D, negative Y is up. In 3D, `Vector3.UP` is `(0, 1, 0)`.
  Jump velocities are positive here.
- **Rotation is in radians, unless the action says degrees.** **Rotate (3D)** takes a **Radians** angle,
  which is usually `speed * delta`. **Set Rotation (3D, Degrees)** takes Euler degrees for the times
  you want to type numbers a human recognises.
- **Move By (3D) is local, Set Position (3D) is not.** **Move By (3D)** compiles to `translate()`,
  which moves along the node's own facing. That is what makes "walk forward" one row, and it is also
  why a rotated node does not move along the world axes.
- **A CharacterBody3D still needs Move And Slide (3D).** Setting velocity plans the motion; the slide
  executes it, once, at the end of the physics tick.
- **The mesh builders create and assign in one row.** Each one makes the mesh resource, sets its
  dimensions, and puts it on this MeshInstance3D. They are multi-line templates, which keeps them
  host-only: the row acts on the MeshInstance3D the sheet is on.
- **The plain mesh members gain an "On node" target.** **Set Mesh Material**, **Clear Mesh**,
  **Has Mesh**, **Mesh Surface Count** and **Mesh Size** are single member operations, so they can be
  pointed at another node. The builders cannot.
- **Node-scoped means picker-scoped.** Node3D rows appear where a Node3D is in scope, CharacterBody3D
  rows where a CharacterBody3D is, and so on. A missing row is nearly always a host-class mismatch.

## Reference tables

On the canvas these read as sentences, with the parameter values drawn in bold:

- Set position to **Vector3(0, 2, 0)**
- Rotate **speed \* delta** rad around **Vector3.UP**
- Look at *target*
- make a box mesh **Vector3(1, 1, 1)**

### General Actions - transform and motion (Node3D)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Position (3D) | Teleports a 3D node to an exact world **Position**. | `position = {pos}` |
| Move By (3D) | Nudges a 3D node by an **Offset** relative to its own facing. | `translate({offset})` |
| Rotate (3D) | Spins a node around an **Axis** by **Radians**, often `speed * delta`. | `rotate({axis}, {radians})` |
| Set Rotation (3D, Degrees) | Sets rotation directly from Euler **Degrees**. | `rotation_degrees = {degrees}` |
| Look At | Turns the node to face a world **Target** position. | `look_at({target})` |
| Set Scale (3D) | Sets how big the node is via a **Scale** factor. | `scale = {scale}` |

### General Actions - bodies and cameras

| Name | What it does | Ships as |
|------|--------------|----------|
| Move And Slide (3D) | Moves a CharacterBody3D by its velocity, sliding along walls and slopes. | `move_and_slide()` |
| Set Velocity (3D) | Sets a CharacterBody3D's **Velocity** as a Vector3. | `velocity = {vel}` |
| Apply Central Impulse (3D) | Gives a RigidBody3D a sudden push - a knockback or a launch. | `apply_central_impulse({impulse})` |
| Make Camera Current (3D) | Switches the view to this Camera3D. | `make_current()` |
| Set Camera FOV | Sets a Camera3D's field of view in **Degrees**. | `fov = {degrees}` |

### General Conditions and Expressions

| Name | What it does | Ships as |
|------|--------------|----------|
| Is On Floor (3D) | True when a CharacterBody3D is standing on the ground. | `is_on_floor()` |
| Get Position (3D) | A Node3D's current position as a Vector3. | `position` |
| Get Velocity (3D) | A CharacterBody3D's current velocity vector. | `velocity` |

### Input

| Name | What it does | Ships as |
|------|--------------|----------|
| Input Vector | A movement direction built from four actions: **Left**, **Right**, **Up**, **Down**. | `Input.get_vector(&{left}, &{right}, &{up}, &{down})` |

### Mesh - the primitive builders (MeshInstance3D)

| Name | What it does | Ships as |
|------|--------------|----------|
| Make Box Mesh | Builds a box of the given **Size** (width, height, depth in metres) and shows it. | a `BoxMesh` built into a `{uid}` local, its `size` set, then assigned to `mesh` |
| Make Sphere Mesh | Builds a sphere of the given **Radius** (its height is set to a full diameter). | a `SphereMesh` with `radius` and `height` set, then assigned to `mesh` |
| Make Cylinder Mesh | Builds a cylinder of a **Radius** and **Height**. | a `CylinderMesh` with `top_radius`, `bottom_radius` and `height` set, then assigned |
| Make Plane Mesh | Builds a flat plane of a **Size** (width and depth) - a quick floor or wall. | a `PlaneMesh` with `size` set, then assigned |
| Make Capsule Mesh | Builds a capsule (a pill) of a **Radius** and **Height** - a stand-in character body. | a `CapsuleMesh` with `radius` and `height` set, then assigned |
| Make Prism Mesh | Builds a triangular prism (a wedge or ramp) of a **Size**. | a `PrismMesh` with `size` set, then assigned |
| Make Torus Mesh | Builds a ring from an **Inner Radius** and an **Outer Radius**. | a `TorusMesh` with both radii set, then assigned |

### Mesh - material, clearing and readouts

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Mesh Material | Overrides the whole mesh's **Material** - one line to recolour or reskin. | `material_override = {material}` |
| Clear Mesh | Removes the mesh so nothing draws. | `mesh = null` |
| Has Mesh | True when this MeshInstance3D currently shows a mesh. | `mesh != null` |
| Mesh Surface Count | How many surfaces (material slots) the mesh has, or 0 when there is none. | `(mesh.get_surface_count() if mesh != null else 0)` |
| Mesh Size | The mesh's bounding-box size in local space - handy for fitting or spacing. | `get_aabb().size` |

## Use cases

**1. Put something at an exact place in the world.**

```
On Ready
  -> Set Position (3D)   Vector3(0, 2, -5)
```

**2. Walk forward along the node's own facing.**

```
Every Frame
  -> Move By (3D)   Vector3(0, 0, -1) * 4.0 * delta
```

```gdscript
translate(Vector3(0, 0, -1) * 4.0 * delta)
```

`-Z` is forward in Godot. Because `translate` is local, turning the node changes where "forward" is,
with no extra rows.

**3. A slowly spinning pickup.**

```
Every Frame
  -> Rotate (3D)   axis = Vector3.UP, radians = 1.5 * delta
```

The **Axis** must be normalised. `Vector3.UP` already is; a hand-typed axis often is not.

**4. Frame something exactly, with numbers you can read.**

```
On Ready
  -> Set Rotation (3D, Degrees)   Vector3(-30, 45, 0)
```

**5. A turret that faces the player.**

```
Every Frame
  -> Look At   $Player.global_position
```

The target must differ from the node's own position, and must not be directly above or below it -
`look_at` has no way to choose an up direction in either case.

**6. The smallest complete 3D character.**

```
Every Physics Tick
  -> Set Local Variable (typed)   move : Vector2 = Input Vector( "ui_left", "ui_right", "ui_up", "ui_down" )
  -> Set Velocity (3D)   Vector3(move.x, velocity.y - 9.8 * delta, move.y) * 1.0
  -> Move And Slide (3D)
```

**Input Vector** hands back a Vector2 from four actions, which maps straight onto the X and Z of a
ground plane.

**7. Jump, and only from the ground.**

```
Every Physics Tick
  Condition: Is On Floor (3D)
  Condition: On Action Just Pressed   "ui_accept"
    -> Set Velocity (3D)   Vector3(velocity.x, 5.0, velocity.z)
```

Positive Y is up in 3D. Rebuilding the whole vector keeps the horizontal motion the character already
had.

**8. Launch a physics prop.**

```
On Body Entered ( body )
  -> Apply Central Impulse (3D)   Vector3(0, 6, -4)
```

**9. Switch to a cutscene camera and back.**

```
On cutscene started
  -> Make Camera Current (3D)

On cutscene finished
  -> Call Method   $PlayerCamera.make_current()
```

**10. Zoom in while aiming.**

```
Every Frame
  Condition: Is Action Pressed   "aim"
    -> Set Camera FOV   50.0
  Else
    -> Set Camera FOV   75.0
```

A lower FOV zooms in, a higher one widens. For a smooth transition, tween the value instead of setting
it directly.

**11. Grey-box a floor at runtime.**

```
On Ready
  -> Make Plane Mesh   Vector2(20, 20)
```

**12. A block you can size from data.**

```
On Ready
  -> Make Box Mesh   Vector3(width, height, depth)
```

```gdscript
extends MeshInstance3D


var __mesh_figure := BoxMesh.new()
__mesh_figure.size = Vector3(width, height, depth)
mesh = __mesh_figure
```

That is the whole row: build, size, assign. The `{uid}` local is unique per row, so two builders in one
event never collide.

**13. A stand-in character while the art is being made.**

```
On Ready
  -> Make Capsule Mesh   radius = 0.3, height = 1.8
```

**14. A ramp without modelling one.**

```
On Ready
  -> Make Prism Mesh   Vector3(2, 1, 4)
```

**15. A ring marker under the selected unit.**

```
On unit selected
  -> Make Torus Mesh   inner radius = 0.5, outer radius = 0.6
  -> Show
```

**16. Recolour a shape at runtime.**

```
On damaged
  -> Set Mesh Material   preload("res://materials/hurt.tres")
```

**17. Hide a shape without deleting the node.**

```
On collected
  -> Clear Mesh
```

**Clear Mesh** leaves the node and its children in place, which is what you want when the same node
gets a new mesh later. **Has Mesh** is the condition that tells the two states apart.

**18. Space objects by their real size instead of a guessed number.**

```
On Ready
  -> Set Local Variable (inferred)   step := Mesh Size().x + 0.2
  -> Set Position (3D)   Vector3(index * step, 0, 0)
```

**Mesh Size** is the bounding box in local space, so it does not include this node's own scale.

**19. Skip work on a node with nothing to draw.**

```
Every Frame
  Condition: Has Mesh
    -> Rotate (3D)   axis = Vector3.UP, radians = 1.0 * delta
```

**20. Check whether a model has more than one material slot.**

```
On Ready
  Condition: Compare Values   Mesh Surface Count() > 1
    -> Print Log   "This model has multiple surfaces."
```

`Mesh Surface Count` answers 0 rather than erroring when there is no mesh at all, so the test is safe
on an empty MeshInstance3D.

### Other use cases

**Procedural corridors.** A For Each over a room list with Make Box Mesh and Set Position (3D) lays out a whole grey-box level from data, and swapping the data reshapes the level with no scene edits.

**Debug volumes.** A Make Box Mesh sized from an Area3D's extents, with a translucent material, makes invisible triggers visible during testing and costs one Clear Mesh to switch off.

**Third-person camera rig.** Look At from a camera pivot to the player, driven under After Every Frame (post-tick), keeps the framing settled because the player has already moved by then.

**Impact scatter.** Apply Central Impulse (3D) on every member of a group, with a direction computed from the blast centre, turns a stack of RigidBody3D props into an explosion.

**Scope zoom.** Set Camera FOV stepped between two values gives a working scope without a second camera or a render target.

## Tips and common mistakes

- **Up is positive Y in 3D.** Copying a 2D jump straight across gives you a jump that drives into the
  floor.
- **Rotate (3D) is in radians and needs a normalised axis.** A non-normalised axis skews the result.
  Use `Vector3.UP` / `Vector3.RIGHT`, or convert with **Degrees To Radians** when you would rather type
  degrees.
- **Move By (3D) is local space.** It is `translate()`, not a world offset. For a world-space move, add
  to the position instead.
- **Look At refuses degenerate targets.** A target equal to the node's own position, or directly above
  or below it, has no valid facing. Offset the target, or use a different up axis by other means.
- **A CharacterBody3D does not move until Move And Slide (3D) runs.** Once, last, under
  **Every Physics Tick**.
- **The mesh builders are host-only.** Their templates are multi-line, so they never gain an "On node"
  parameter. To build a mesh on another node, put the row on a sheet attached to that node.
- **Set Mesh Material overrides everything.** It writes `material_override`, which replaces the
  material on every surface at once. For per-surface materials, that is not the action you want.
- **Mesh Size is local, before scale.** It reads `get_aabb().size`, so a node scaled to 2x still
  reports its unscaled bounds. Multiply by the scale yourself if you need world size.
- **A mesh alone is not a collider.** The builders make something visible, not something solid. A body
  still needs its own CollisionShape3D.
- **Set Camera FOV only affects perspective cameras.** On an orthogonal Camera3D the field of view is
  not what controls the framing.
- **Make Sphere Mesh sets height for you.** It writes `height` as twice the **Radius**, so the sphere
  is round. Reaching for a squashed sphere means setting the mesh's own properties instead.
- **Input Vector's four parameters are actions from the InputMap.** They are picked from the project's
  real action list; a typed-in name that is not in the InputMap silently reads as never pressed.
