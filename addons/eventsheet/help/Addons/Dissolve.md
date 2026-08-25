# Dissolve - Burn a Sprite Away, and Burn It Back

Dissolve is a Godot EventSheets behavior pack for the death that is not a fade: the sprite burns away
along a noise field, with a glowing edge where it is burning, and something happens when it is gone.
You attach a `DissolveBehavior` under any 2D node or Control, the pack copies its shader into your
project and puts the material on that node, and then two rows do the whole job - **Dissolve** burns it
away over the seconds you give and fires **On Dissolved** at the end, **Appear** burns it back.

The thing the pack really saves you is the bookkeeping between the walk and its end. Whether the node
is FREED when it has gone stays on the sheet, in the On Dissolved event, because a behavior that
deletes its own parent is a behavior nobody can debug.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Enemy deaths.** The burn is the death animation, and On Dissolved is where the loot drops.
- **Teleports and warps.** Burn out here, burn in there, with the same two rows.
- **Spawning.** Appear from nothing is more interesting than fading in, and costs the same row.
- **Doors and walls that open.** A wall that burns away reads as magic where a wall that slides reads
  as machinery.
- **Card and item destruction.** A card burning at the edges is a whole feedback language.
- **Ghosts and summons.** Burn in slowly for an arrival, out quickly for a banish.
- **Level transitions on a tilemap layer.** A layer that burns away while the next burns in.
- **Fire damage.** A partial burn held on says "this thing is being destroyed" while the fight runs.
- **Reveal effects.** Burn a cover sprite away to show what is under it.
- **Scene-clean-up you can see.** A pooled object that burns before it goes back to the pool.

---

## Core concepts

**The node is the thing that burns.** Attach a `DissolveBehavior` as a child of the node, and that
parent is the **host**. It must be a `CanvasItem` - any 2D node or UI Control.

**The burn is one dial walked from 0 to 1.** `dissolve` at 0 is a whole sprite; at 1 there is nothing
left. **Dissolve** walks it up over a time, **Appear** walks it back down, and both take the time as
their only argument.

**The noise is generated in the shader.** There is no texture to supply. `noise_scale` decides how big
the blotches are - small numbers burn in big patches, large numbers in speckles.

**The edge glows.** `edge_color` and `edge_width` are the burning front. Set `edge_width` to 0 for a
hard, clean disappearance with no glow at all.

**On Dissolved is the hand-off.** It fires the moment the burn arrives at gone. That is where a boss
drops its loot, a pooled object goes back to the pool, or a node is freed.

**Every node gets its own copy at run time.** A material is a Resource, so two nodes pointing at the
same `.tres` share it. The behavior duplicates it the first time it writes, so one goblin burning does
not burn the room. `own_material` turns that off when a whole row of things should go together.

---

## Setup

**1. Add the pack to the node.** Right-click the object in the Object bar, **Add behavior**, Dissolve.
That adds the `DissolveBehavior` child, copies `dissolve.gdshader` and `dissolve_material.tres` into
`res://effects/`, and puts the material on the node as an undoable scene edit.

**2. Set the knobs (optional).**

| Property | Default | What it does |
|---|---|---|
| `hide_when_gone` | `true` | Hide the host once the burn has finished. A fully dissolved sprite draws nothing anyway, so this saves the draw. Turn it off when something else is going to bring it back. |
| `own_material` | `true` | Take a private copy of the material before turning a dial, so this node's burn is its own. |

**3. Burn it.**

```
On Enemy Died
  -> Enemy | DissolveBehavior: Dissolve over 0.8 s

On Dissolved
  -> Enemy: queue_free()
```

---

## ACE reference

All rows target the `DissolveBehavior` on the node they are placed on, through the **On node**
parameter every pack row carries (default `$DissolveBehavior`).

### Actions

| Row | Parameters | What it does |
|---|---|---|
| **Dissolve** | `seconds` (float, default `0.8`) | Burns the host away over the time given, then fires On Dissolved. No time at all burns it away on the spot. |
| **Appear** | `seconds` (float, default `0.8`) | Shows the host and burns it back in from nothing. |
| **Set Hide When Gone** | `value` (bool) | Whether a finished burn hides the host. |
| **Set Own Material** | `value` (bool) | Turns the private-copy rule on or off. |

### Conditions

| Row | What it answers |
|---|---|
| **Is Gone** | True once the host has burned all the way away. |

### Expressions

| Row | What it reads |
|---|---|
| **Burnt Away** | How much of the host has burned, 0 to 1. |
| **Hide When Gone**, **Own Material** | The two knobs. |

### Triggers

| Row | When it fires |
|---|---|
| **On Dissolved** | The moment a burn arrives at gone. |

### The shader's own dials

| Dial | Type | Starts at | What it is |
|---|---|---|---|
| `dissolve` | 0 to 1 | `0.0` | How much has burned away. |
| `edge_color` | colour | orange | The colour the burning edge glows. |
| `edge_width` | 0 to 0.4 | `0.08` | How wide the glowing edge is. 0 is a hard edge. |
| `noise_scale` | 1 to 64 | `12.0` | How large the burn's blotches are. |

---

## Reading it from expressions - the Self section

Type `self` into any ƒx field on a node carrying the pack and its members insert as
`$DissolveBehavior.` chains: `$DissolveBehavior.burnt_away()` to drive a sound's volume down with the
burn, `$DissolveBehavior.is_gone()` as a condition.

The dials read back through the picked dial rows too: `effect.dissolve` as an expression is the same
number, and `effect.edge_color` is the one to change when a fire enemy should burn red.

---

## Use cases

Each example targets the `DissolveBehavior` on the named node.

### 1. Enemy death, then free

```
On Enemy Died
  -> Enemy | DissolveBehavior: Dissolve over 0.8 s

On Dissolved
  -> Enemy: queue_free()
```

The trigger is the point: the node is freed when the burn has finished, not on a guessed timer.

### 2. Loot dropped at the end of the burn

```
On Dissolved
  -> Spawn Coin at Enemy.position
  -> Enemy: queue_free()
```

The coin appears out of the ashes rather than out of a corpse that is still there.

### 3. Spawn in

```
On Enemy Spawned
  -> Enemy | DissolveBehavior: Set effect.dissolve to 1.0
  -> Enemy | DissolveBehavior: Appear over 0.6 s
```

Start gone, then burn in. Setting the dial first is what makes the arrival start from nothing.

### 4. Teleport, out and in

```
On Teleport
  -> Player | DissolveBehavior: Dissolve over 0.3 s
  -> Wait 0.3 seconds
  -> Player: position = destination
  -> Player | DissolveBehavior: Appear over 0.3 s
```

### 5. A pooled object that goes back rather than dies

```
On Bullet Expired
  -> Bullet | DissolveBehavior: Dissolve over 0.2 s

On Dissolved
  -> Bullet: return to pool
```

With `hide_when_gone` on, the bullet is already invisible when the pool takes it.

### 6. Fire damage held part-way

```
On Burning Tick
  -> Enemy | DissolveBehavior: Set effect.dissolve to clampf(Enemy.burn_stacks / 10.0, 0, 0.7)
```

A partial burn is a status, not a death. Keep it under 1 and it stays there.

### 7. A wall that burns open

```
On Puzzle Solved
  -> MagicWall | DissolveBehavior: Set effect.noise_scale to 4.0
  -> MagicWall | DissolveBehavior: Dissolve over 1.5 s

On Dissolved
  -> MagicWall: disable collision
```

Big blotches and a slow burn read as stone crumbling; the collision goes when the picture does.

### 8. A card burning in a deck-builder

```
On Card Consumed
  -> Card | DissolveBehavior: Set effect.edge_color to Color(1, 0.3, 0.05)
  -> Card | DissolveBehavior: Dissolve over 0.5 s
```

### 9. Ghost arriving slowly, banished quickly

```
On Ghost Summoned
  -> Ghost | DissolveBehavior: Appear over 2.0 s
On Ghost Banished
  -> Ghost | DissolveBehavior: Dissolve over 0.15 s
```

Two speeds of the same effect are two different feelings.

### 10. A clean disappearance with no glow

```
On Illusion Broken
  -> Decoy | DissolveBehavior: Set effect.edge_width to 0.0
  -> Decoy | DissolveBehavior: Dissolve over 0.25 s
```

### 11. Sound that follows the burn

```
Every tick
  Condition: NOT Enemy | DissolveBehavior: Is Gone
    -> BurnSound: volume_db = linear_to_db(1.0 - Enemy | DissolveBehavior: Burnt Away)
```

The expression is the whole link between picture and sound.

### 12. A whole row of enemies going together

```
On Screen Cleared
  -> Grunt1 | DissolveBehavior: Set Own Material  false
  -> Grunt1 | DissolveBehavior: Dissolve over 1.0 s
```

With the private copy off, every node wearing the file burns as one.

### 13. Reveal what is underneath

```
On Cover Removed
  -> CoverArt | DissolveBehavior: Dissolve over 0.9 s
```

A cover sprite that burns away is a reveal; one that fades is a transition.

### 14. Cancel a burn that started by mistake

```
On Revived
  -> Enemy | DissolveBehavior: Appear over 0.3 s
```

Appear replaces whatever walk was running, so a half-burnt enemy comes straight back.

### 15. Test the whole thing without a fight

```
On Debug Key Pressed
  -> Enemy | DissolveBehavior: Dissolve over 0.0 s
```

Zero seconds burns on the spot and fires On Dissolved immediately, which is the fastest way to check
what the trigger does.

### Other use cases

**Save-slot deletion.** The slot's panel burns away when the player confirms, and the row that
rewrites the file sits in On Dissolved so the picture and the data agree.

**Sand and ash enemies.** A very high `noise_scale` and a pale edge reads as a thing coming apart
into dust rather than burning.

**Photograph developing.** Appear with a slow burn and a white edge looks like an image coming up in
a tray, which is a good fit for a memory or a flashback.

**Retro screen wipes.** A full-screen ColorRect with the pack on it burns between menus, with the
scene change in On Dissolved.

**Ice shattering.** A pale blue edge and a hard, fast burn reads as glass rather than as fire.

---

## Tips and common mistakes

- **Free the node in On Dissolved, not on a timer.** That trigger is the exact frame the picture has
  gone. A `Wait` beside the Dissolve row will be wrong the first time somebody changes the duration.
- **Start at 1 to burn in.** Appear walks the dial down from wherever it is. On a node that has never
  burnt, that is 0, and Appear does nothing visible. Set `effect.dissolve` to 1 first.
- **Zero seconds is a legitimate answer.** It burns on the spot and still fires On Dissolved, which is
  what a pop-out-of-existence wants and what makes the effect testable.
- **`hide_when_gone` hides, it never frees.** The node is still there, still processing, still in
  groups. Freeing is your row.
- **A partial burn is a status.** Anything under 1 stays where you put it. Only the verbs walk.
- **Your own copy is the default.** Only turn `own_material` off when you really mean "every node
  wearing this file, together".
- **Big blotches want a slow burn.** A low `noise_scale` with a fast Dissolve looks like the sprite
  blinking out in chunks; give it time or raise the scale.
- **The shader file is yours after the first add.** Edits to `res://effects/dissolve.gdshader` survive
  updates, because nothing here ever overwrites a file that exists.
