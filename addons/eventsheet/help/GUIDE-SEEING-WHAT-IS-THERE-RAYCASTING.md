# Seeing What Is There (Raycasting)

A raycast is how a game asks the world a question: *is anything between me and the player? what did this bullet hit? what is under the mouse? how far can I fall before I land?* Every line-of-sight check, hitscan weapon, ledge detector, click-to-select and ground probe is a cast of some kind.

Godot casts four different ways, and the picker has all four, in 2D and in 3D. This page explains which one to reach for and shows the rows.

## Table of Contents

1. [Which cast do I want?](#which-cast-do-i-want)
2. [See them running](#see-them-running)
3. [The RayCast node](#the-raycast-node)
4. [ShapeCast: a ray with thickness](#shapecast-a-ray-with-thickness)
5. [Casting from anywhere, no node needed](#casting-from-anywhere-no-node-needed)
6. [Reading a stored result](#reading-a-stored-result)
7. [Point and volume queries](#point-and-volume-queries)
8. [Clicking things in 3D](#clicking-things-in-3d)
9. [Full ACE reference](#full-ace-reference)
10. [Use cases](#use-cases)
11. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Which cast do I want?

![The picker filtered to "raycast": the Raycast 2D, Raycast 3D and Overlap 3D entries under their category icons](images/raycast-vocabulary.png)

| You want to… | Use | Why |
| --- | --- | --- |
| Check the same direction every frame from one object | **RayCast2D / RayCast3D node** | The physics server updates it for you. Cheapest option for a permanent probe. |
| Do that, but a hairline ray keeps slipping through gaps | **ShapeCast2D / ShapeCast3D node** | Sweeps a *shape*, so it cannot thread a needle. Also reports every hit along the sweep. |
| Cast once, from anywhere, right now | **Cast Ray Into** | No node required. Fires from any two world points, on demand. |
| Know what is at a single spot | **Query Bodies At Point** | A pinprick test, not a line. |
| Know what is inside an area | **Query Bodies In Sphere / Box / Circle / Rectangle** | Explosions, pickup magnets, room triggers. |
| Know how far something could move before it hits | **Cast Circle / Sphere Motion Into** | Gives back a fraction of the move that is clear. |
| Know what the mouse is over | **Cast Ray From Mouse Into** (3D) or **Query Bodies Under Mouse** (2D) | The whole of click-to-select, in one row. |

Picker categories: **Raycast 2D**, **Raycast 3D**, **Overlap 2D**, **Overlap 3D**.

---

## See them running

A cast is invisible, which is most of why it is hard to learn: when a ray "does not work", there is nothing on screen to look at. Two showcases fix that by drawing every cast as it happens. Open either scene and press play.

### Raycast Lab (2D) - `demo/showcase/raycast_lab/raycast_lab.tscn`

![Six casts drawn at once in a walled 2D arena: a dim yellow line sweeping from the player, a cyan beam running to an orange target under the cursor with a ring marking the impact, a dashed green scan circle with rings on the three bodies it caught, a white ring around the picked target, a pink dashed probe ending in a circle short of the wall, and a dashed blue ShapeCast rail down the right-hand side](images/raycast-lab.png)

Arrows move, the cursor aims the beam. Six casts run every frame:

| What you see | The cast | What it teaches |
| --- | --- | --- |
| Dim yellow line, bright when it lands | **RayCast2D node**, swept by Point RayCast At | A node-based ray, re-aimed every tick. The white stub at the impact is the surface normal. |
| Cyan beam to the cursor | **Cast Ray Into** + the **Ray Result** expressions | ONE cast, then the point, the normal and the group test are read off the stored result. The orange ring means it hit something in the `targets` group. |
| Dashed green circle + rings | **Query Bodies In Circle** | Everything within 130px, collected into a variable. |
| White ring under the pointer | **Query Bodies Under Mouse** | The 2D click-to-select idiom: a point query at the cursor. |
| Pink dashed probe | **Cast Circle Motion Into** | How far an 18px disc could slide before it jams. The ring is where it stops. |
| Dashed blue rail, far right | **ShapeCast2D node** | A ray with thickness. The disc parks at its safe fraction. |

### Raycast Lab 3D - `demo/showcase/raycast_lab_3d/raycast_lab_3d.tscn`

![The same six casts in a 3D arena: orange sphere targets and grey crates on a grey floor, a yellow beam from a turret to a crate, a pink beam to a marker, green rings hovering over the bodies a sphere query caught, a pale blue ShapeCast rail crossing the floor, and a cyan marker on bare floor with its surface normal standing straight up](images/raycast-lab-3d.png)

Move the mouse to aim; Left/Right orbit the camera. The same six casts, plus the two that only exist in 3D:

- **Cast Ray From Mouse Into** is the cyan marker. The camera projects a ray through your cursor and stores what it finds, which is the whole of click-to-select in 3D. The marker grows when the cursor is on a target.
- **Ray Result Face Index** is the `face` number in the readout: which mesh TRIANGLE the ray struck. The floor is deliberately a concave trimesh, because that is the only kind of shape that has a face index. Point at a sphere target instead and it reads -1, correctly.

Two details in that scene are worth stealing:

- The camera **orbits** rather than being mouse-driven. A first-person controller captures the pointer, and a captured pointer has no screen position to project a picking ray through. If your own click-to-select never fires, check this first.
- The beam drawn at the cursor is the **surface normal**, not the camera ray. You are looking straight down the camera ray, so drawing it renders as a stray line skidding over the floor.

Both scenes are generated, and every cast in them is a real ACE row rather than hand-written code, so `raycast_lab.gd` and `raycast_lab_3d.gd` beside them are exactly what these rows emit. Read either one next to its scene to see the whole vocabulary compiled.

---

## The RayCast node

Add a `RayCast2D` or `RayCast3D` as a child of the thing that needs to see. Point it, and it reports what it touches every physics frame.

```
Every tick
  -> Point RayCast At  Vector2(0, 40)

RayCast Is Colliding
  -> Set variable  grounded = true

RayCast hits something in "enemies"
  -> Call function  deal_damage
```

The target is measured **from the raycast node**, in its own local space, not from the world origin. `Vector2(0, 40)` means "40 pixels below me", and it turns with the node.

Aiming it at a moving target is the same idea, converted into local space:

```
Every tick
  -> Point RayCast At  to_local(player.global_position)
```

If you re-aim a raycast and want to read the answer **in the same frame**, add **Force RayCast Update** in between. Otherwise you are reading last frame's result.

---

## ShapeCast: a ray with thickness

A ray is infinitely thin. A fast bullet can step straight over a thin wall between two frames, and a hairline ground probe can drop through the crack between two floor tiles. A ShapeCast sweeps a real shape along the same path, so neither happens. Give the node a shape in the Inspector, then drive it exactly like a raycast.

It also answers something a ray cannot: **everything** along the sweep, not just the first thing.

```
Every tick
  -> Point ShapeCast At  Vector2(0, 120)
  -> Force ShapeCast Update

ShapeCast Is Colliding
  -> For 0 to (shapecast hit count - 1)
       -> Add to list  touched  = shapecast collider at (loopindex)
```

**Safe Fraction** is the useful one for movement. It is how far along the sweep the shape can travel without touching anything, from 0 (blocked right away) to 1 (clear all the way). Multiply your intended move by it to slide right up to the wall and stop:

```
Every tick
  -> Set position  position + velocity * delta * (shapecast safe fraction)
```

---

## Casting from anywhere, no node needed

**Cast Ray Into** fires one ray between two world points and stores everything it learned in a variable. No RayCast node, no scene setup.

```
On "fire" pressed
  -> Cast Ray Into  hit, from: muzzle.global_position, to: muzzle.global_position + aim * 1000
```

There are also single-shot expressions (**World Raycast Point**, **World Raycast Collider**, and so on) that read well in one cell. They have a real cost, though: **each one casts its own ray**. Asking for the point *and* the collider *and* the normal with three expressions is three casts of the same ray. Whenever you want more than one fact about a hit, cast once into a variable and read it.

---

## Reading a stored result

**Cast Ray Into** hands back the raw Dictionary Godot produced. The **Ray Result** rows name its parts so you never have to know the keys:

```
On "fire" pressed
  -> Cast Ray Into  hit, from: global_position, to: global_position + aim * 1000

  hit hit something
    -> Spawn  Spark  at (hit point)
    -> Set rotation  (hit normal).angle()

    hit is in "enemies"
      -> Call function  damage
```

| Name | Gives you |
| --- | --- |
| **Ray Result Hit Something** | Whether the cast touched anything at all. |
| **Ray Result Collider** | The object it hit. |
| **Ray Result Point** | Where in the world it struck. Spawn the impact effect here. |
| **Ray Result Normal** | Which way that surface faces. Reflect velocity around it to bounce; align a decal to it. |
| **Ray Result Shape Index** | Which of the object's collision shapes was hit, so a head shape can score differently from a body shape. |
| **Ray Result Face Index** (3D) | Which triangle of a concave mesh was hit, for per-face data like footstep materials. |
| **Ray Result Is In Group** | Whether the hit object belongs to a group. Safe on a clear ray - it checks for nothing-hit first. |

---

## Point and volume queries

Not every question is a line.

**At a point** - what is at this exact spot?

```
On "place" pressed
  -> Query Bodies At Point  blockers, point: build_ghost.global_position

  blockers is empty
    -> Spawn  Turret  at (build_ghost.global_position)
```

**In a volume** - what is inside this radius? This is the explosion, the pickup magnet, the "who is in the room" check.

```
On grenade exploded
  -> Query Bodies In Sphere  caught, center: global_position, radius: 8.0
  -> For each  caught
       -> Call function  apply_blast
```

2D has Circle and Rectangle; 3D has Sphere and Box.

**How far can I go?** - Cast Circle / Sphere Motion Into answers with a fraction of the move that is clear. 1 means the whole path is free. This is the reliable way to move something fast without it tunnelling through a wall:

```
Every tick
  -> Cast Sphere Motion Into  clear, from: global_position, motion: velocity * delta, radius: 0.5
  -> Set position  position + velocity * delta * clear
```

---

## Clicking things in 3D

Picking an object under the cursor in 3D means building a ray from the camera through the mouse position. **Cast Ray From Mouse Into** does the whole thing:

```
On "click" pressed
  -> Cast Ray From Mouse Into  picked, distance: 1000

  picked hit something
    -> Set variable  selected = (picked collider)

  picked is in "ground"
    -> Call function  order_move_to  (picked point)
```

In 2D there is no projection to do, so it is a point query at the cursor: **Query Bodies Under Mouse**, which hands back everything under the pointer as a list.

It needs a **current Camera3D**, and it needs the pointer to be **free**. A first-person controller captures the mouse, and a captured mouse has no screen position to project through, so the picking ray never moves. If you want both, release the pointer while a selection mode is active (`Input.mouse_mode = Input.MOUSE_MODE_VISIBLE`) and recapture it afterwards. The 3D showcase sidesteps it entirely by orbiting the camera on the arrow keys instead of the mouse.

---

## Full ACE reference

### RayCast node (2D and 3D)

| Name | Kind | What it does |
| --- | --- | --- |
| **RayCast Is Colliding** | Condition | Hitting something right now. |
| **RayCast Hits Group** | Condition | Hitting something in a group. |
| **Point RayCast At** | Action | Aims it and sets its reach, relative to the node. |
| **Enable RayCast** | Action | Turns it on or off. |
| **Force RayCast Update** | Action | Re-checks immediately, instead of next physics frame. |
| **Set RayCast Mask** | Action | Which collision layers it can see, as one number. |
| **Set RayCast Mask Layer** | Action | Switches one layer on or off, leaving the rest alone. |
| **Ignore Node In RayCast** | Action | Pass straight through one object. |
| **Stop Ignoring Node In RayCast** | Action | Undo that for one object. |
| **Clear RayCast Exceptions** | Action | Forget every ignored object. |
| **RayCast Detects Areas** | Action | Notice Area nodes (off by default). |
| **RayCast Detects Bodies** | Action | Notice solid bodies (on by default). |
| **RayCast Hits From Inside** | Action | Report a shape the ray starts inside. |
| **RayCast Hits Back Faces** (3D) | Action | Hit a surface from behind. |
| **RayCast Ignores Its Parent** | Action | Pass through the body it hangs from (on by default). |
| **RayCast Collider** / **Hit Point** / **Hit Normal** | Expression | What, where, and which way it faces. |
| **RayCast Hit Shape Index** | Expression | Which collision shape was struck. |
| **RayCast Hit Face Index** (3D) | Expression | Which mesh triangle was struck. |
| **RayCast Target** | Expression | Its current reach. |

### ShapeCast node (2D and 3D)

| Name | Kind | What it does |
| --- | --- | --- |
| **ShapeCast Is Colliding** | Condition | The swept shape is touching something. |
| **Point ShapeCast At** | Action | Aims the sweep and sets its length. |
| **Enable ShapeCast** | Action | Turns it on or off. |
| **Force ShapeCast Update** | Action | Re-runs the sweep immediately. |
| **Set ShapeCast Mask** | Action | Which layers the sweep can see. |
| **Set ShapeCast Margin** | Action | Pads the shape slightly, for steadier contact. |
| **Set ShapeCast Max Results** | Action | Caps how many hits one sweep collects. |
| **Ignore Node In ShapeCast** / **Clear ShapeCast Exceptions** | Action | Skip specific objects. |
| **ShapeCast Hit Count** | Expression | How many objects it is touching. |
| **ShapeCast Collider At** / **Hit Point At** / **Hit Normal At** | Expression | Read hit number *n*. |
| **ShapeCast Safe Fraction** | Expression | How much of the sweep is clear (0..1). |
| **ShapeCast Unsafe Fraction** | Expression | Where along the sweep contact begins (0..1). |

### World queries (2D and 3D)

| Name | Kind | What it does |
| --- | --- | --- |
| **Cast Ray Into** | Action | One ray, stored in a variable. From, to, mask, ignore list, detect-areas. |
| **Cast Ray From Mouse Into** (3D) | Action | Camera-through-cursor ray, stored in a variable. |
| **Query Bodies At Point** | Action | Everything at one spot, into a list. |
| **Query Bodies Under Mouse** (2D) | Action | Everything under the cursor, into a list. |
| **Query Bodies In Circle / Rectangle** (2D) | Action | Everything in a 2D area, into a list. |
| **Query Bodies In Sphere / Box** (3D) | Action | Everything in a 3D volume, into a list. |
| **Cast Circle / Sphere Motion Into** | Action | How much of a move is clear, as a fraction. |
| **World Raycast Hits?** | Condition | Single-shot: did a ray between two points hit? |
| **World Raycast Point / Collider / Normal** | Expression | Single-shot: one fact about that hit. |
| **Mouse Ray Hits Something / Collider / Point** (3D) | Condition / Expression | Single-shot versions of the mouse pick. |
| **Mouse Ray Origin / Direction** (3D) | Expression | The two halves of the cursor ray, if you want to build it yourself. |

### Ray result readers (2D and 3D)

**Ray Result Hit Something**, **Ray Result Is In Group** (conditions); **Ray Result Collider**, **Point**, **Normal**, **Shape Index**, **Face Index** (expressions).

---

## Use cases

1. **Ground check for a platformer.** A short `RayCast2D` pointing down; **RayCast Is Colliding** is your "can jump" test. A ShapeCast is steadier if your floors have seams.
2. **Hitscan weapon.** **Cast Ray Into** from the muzzle along the aim direction, then spawn a spark at **Ray Result Point** and rotate it to **Ray Result Normal**.
3. **Enemy line of sight.** Cast from the guard to the player; if **Ray Result Collider** is the player, nothing is in the way, so start chasing.
4. **Wall-slide detection.** A raycast to each side; **RayCast Is Colliding** on either one enables the slide.
5. **Ledge grab.** Two raycasts: one at chest height that must be clear, one just above it that must hit. The pair is the ledge.
6. **Click to select in 3D.** **Cast Ray From Mouse Into**, then **Ray Result Is In Group** "selectable".
7. **Move order on terrain.** Same cast, but read **Ray Result Point** and send the unit there.
8. **Build placement.** **Query Bodies At Point** where the ghost sits. Empty list means the spot is free.
9. **Explosion damage.** **Query Bodies In Sphere**, then For Each the results and scale damage by distance.
10. **Pickup magnet.** **Query Bodies In Circle** each tick, and pull anything in "coins" toward the player.
11. **Fast projectile that must not tunnel.** **Cast Sphere Motion Into**, then move by `velocity * delta * clear`.
12. **Bounce a ball.** Reflect velocity around **Ray Result Normal** at the moment of contact.
13. **Headshots.** **Ray Result Shape Index** tells a head collider from a body collider on the same enemy.
14. **Footstep sounds by surface.** **Ray Result Face Index** on a concave mesh picks the material under each step.
15. **Cover detection for AI.** Cast from several candidate spots to the player; the ones that are blocked are cover.
16. **Interaction prompt.** A short forward raycast in first person; if it hits something in "interactive", show the "Press E" label.
17. **Laser sight.** Cast each tick and draw a line from the muzzle to **Ray Result Point**, or to the ray's end when nothing was hit.
18. **Elevator safety.** A ShapeCast under the platform; **ShapeCast Hit Count** above zero means something is in the way, so do not descend.

**Other use cases**

- **Ignoring yourself.** **RayCast Ignores Its Parent** is on by default, but for a one-off **Cast Ray Into** pass `[get_rid()]` in the Ignore field so a shot never hits its shooter.
- **Seeing trigger zones.** Rays skip Area nodes unless you say otherwise. Turn **Detect Areas** on for water volumes, damage zones and pickup regions.
- **Aiming at a moving target.** Convert with `to_local(target.global_position)`, because a RayCast node's target is local, not world.
- **Reading in the same frame you aim.** Add **Force RayCast Update** between pointing the ray and asking what it hit.
- **Casting from inside a shape.** Turn **Hits From Inside** on, or a ray starting inside a wall will report a clear path.

---

## Tips and common mistakes

- **A raycast node's target is LOCAL.** `Vector2(0, 100)` means "100 pixels below me", and it rotates with the node. It is not a world position.
- **Areas are ignored by default.** This is the single most common "my raycast is broken" report. Turn on **Detect Areas** for the query, or the trigger zone will never register.
- **Reading the same frame you aimed gives you stale data.** The physics server updates a raycast once per physics frame. **Force RayCast Update** re-runs it on the spot.
- **A ray starting inside a shape reports nothing** until **Hits From Inside** is on.
- **Each single-shot expression casts its own ray.** Three expressions about one hit is three casts. Use **Cast Ray Into** and read the stored result instead.
- **Thin walls and fast objects need thickness.** If something occasionally passes through a wall, a ShapeCast or **Cast Sphere Motion Into** fixes what a hairline ray cannot.
- **Check "hit something" before reading the collider.** A cleared ray has no collider, and calling a method on nothing crashes. **Ray Result Is In Group** already guards this for you.
- **Volume queries are not free.** Cap them with Max Results, and prefer running them on an event rather than every tick when you can.
- **The exception actions need a physics object.** **Ignore Node In RayCast** takes a `CollisionObject2D` or `CollisionObject3D` - a plain Node will not compile.
