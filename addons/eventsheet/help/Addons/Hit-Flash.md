# Hit Flash - White Out a Sprite the Frame It Is Hit

Hit Flash is a Godot EventSheets behavior pack for the oldest reaction in action games: the moment a
thing is struck, it goes white. You attach a `HitFlashBehavior` under any 2D node or Control, the
pack copies its shader into your project and puts the material on that node, and then one row -
**Flash** - washes the node's own pixels towards a colour and lets them drain back.

It exists beside the shipped **Flash** verb rather than replacing it, and the difference is worth one
sentence: modulate MULTIPLIES, so a dark sprite tinted white stays dark and a black one does not move
at all. This pack mixes the pixels towards the colour instead, so every sprite whites out by the same
amount whatever it was painted. The modulate Flash needs no material, which is what makes it the
right answer for a node that has none.

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

- **Hit reactions.** The one-frame white-out that makes a strike land, on sprites of any brightness.
- **Poison, burning and freezing.** The same wash in green, orange or pale blue reads as a status
  without a single extra sprite.
- **Boss phase tells.** A long red wash while a boss winds up says "something is coming" without UI.
- **Healing and buffs.** A soft white or gold wash on the frame a heal lands, so it is felt.
- **Parries and perfect blocks.** A very short, very bright flash is the whole reward feedback.
- **Silhouette checks.** Wash a sprite fully white while designing to see its shape as the player does.
- **Pickups.** A quick wash when a coin is collected, before it is freed.
- **Invalid actions.** A red wash on a UI panel when an input is refused, with no text at all.
- **Screen-free feedback on small screens.** A wash costs no space, which matters on a phone.
- **Dark-art games.** The case the modulate blink cannot serve, because there is nothing to multiply.

---

## Core concepts

**The node is the thing that flashes.** You attach a `HitFlashBehavior` as a child of the node you
want to wash, and that parent becomes the **host**. The host must be a `CanvasItem` - every 2D node
and every UI Control. Every row acts on the host of the behavior it is placed on.

**The wash is a shader dial, not a modulate.** The pack's shader has two dials: `flash_color` (what
the wash is) and `flash_amount` (how much of it is showing, 0 to 1). **Flash** sets both, then walks
`flash_amount` back to 0 over the seconds you give.

**The shader file becomes yours.** Adding the pack copies `hit_flash.gdshader` into `res://effects/`
and makes `res://effects/hit_flash_material.tres` wearing it. Both are ordinary project files: open
the shader and change what a hit looks like. Nothing overwrites them, ever - a second node added to
the same project finds them and uses them.

**Every node gets its own copy at run time.** A material is a Resource, so two nodes pointing at the
same `.tres` share it: turn a dial on one and the other turns with it. The behavior duplicates the
material the first time it writes to it, so one goblin flashing never flashes the room. The
`own_material` knob turns that off for the one case where sharing IS the effect.

**The dials show up as rows too.** Because the node wears a real ShaderMaterial, the picker offers
**Set** `effect.flash_color` and the rest of the dial rows on that node. The pack's verbs are the
timing; the dial rows are the direct control.

---

## Setup

**1. Add the pack to the node.** Right-click the object in the Object bar and choose **Add behavior**,
then Hit Flash. That does three things at once: adds the `HitFlashBehavior` child, copies
`hit_flash.gdshader` and `hit_flash_material.tres` into `res://effects/`, and puts the material on the
node. The material assignment is a normal scene edit, so Ctrl+Z takes it back.

**2. Check the knob (optional).** Select the behavior node and look at `own_material`.

| Property | Default | What it does |
|---|---|---|
| `own_material` | `true` | Take a private copy of the material before turning a dial, so this node's flash is its own. Turn it off when a whole row of nodes should flash together. |

**3. Call Flash where the hit happens.**

```
On Player Hit
  -> Player | HitFlashBehavior: Flash  white  0.15
```

That is the whole setup. No timers, no bookkeeping, nothing to reset.

---

## ACE reference

All rows target the `HitFlashBehavior` on the node they are placed on, through the **On node**
parameter every pack row carries (default `$HitFlashBehavior`).

### Actions

| Row | Parameters | What it does |
|---|---|---|
| **Flash** | `colour` (Color, default white), `seconds` (float, default `0.15`) | Washes the host fully towards `colour` and drains it back over `seconds`. A second Flash restarts rather than stacking. |
| **Stop Flashing** | none | Ends the wash now, whatever was left of it. |
| **Set Own Material** | `value` (bool) | Turns the private-copy rule on or off at run time. |

### Conditions

| Row | What it answers |
|---|---|
| **Is Flashing** | True while any of the wash is still showing. |

### Expressions

| Row | What it reads |
|---|---|
| **Own Material** | Whether this behavior takes a private copy of the material. |

### The shader's own dials

| Dial | Type | Starts at | What it is |
|---|---|---|---|
| `flash_color` | colour | white | The colour the sprite is washed with. |
| `flash_amount` | 0 to 1 | `0.0` | How much of that colour is showing. |

---

## Reading it from expressions - the Self section

Type `self` into any ƒx field on a node carrying the pack and its members insert as
`$HitFlashBehavior.` chains: `$HitFlashBehavior.is_flashing()` in a condition,
`$HitFlashBehavior.own_material` where a rule needs to know whether this node flashes alone.

The dials read back the same way through the picked dial rows: `effect.flash_amount` as an
expression is how far through a wash the node is, which is a fine input to a sound's volume or a
number's scale.

---

## Use cases

Each example targets the `HitFlashBehavior` on the named node.

### 1. The plain damage flash

```
On Player Hit
  -> Player | HitFlashBehavior: Flash  white  0.12
```

Short and bright. Anything longer than about a fifth of a second stops reading as an impact and
starts reading as a state.

### 2. Enemy hit, scaled by how hard

```
On Enemy Damaged  -> amount
  -> Enemy | HitFlashBehavior: Flash  white  clampf(amount / 50.0, 0.06, 0.3)
```

A big hit whites out for longer, so damage numbers are felt before they are read.

### 3. Poison in green

```
On Poison Tick
  -> Enemy | HitFlashBehavior: Flash  Color(0.4, 1, 0.4)  0.2
```

The same row with a different colour is a whole second status effect.

### 4. Burning in orange, on a loop

```
Every 0.4 seconds
  Condition: Enemy.burning
    -> Enemy | HitFlashBehavior: Flash  Color(1, 0.5, 0.1)  0.35
```

A wash that restarts before it has drained reads as a steady glow rather than a pulse.

### 5. Frozen in pale blue, held on

```
On Frozen
  -> Enemy | HitFlashBehavior: Set effect.flash_color to Color(0.6, 0.85, 1)
  -> Enemy | HitFlashBehavior: Set effect.flash_amount to 0.55
On Thawed
  -> Enemy | HitFlashBehavior: Stop Flashing
```

For a status that lasts, set the dials directly and leave them; the pack's verbs are for moments.

### 6. Parry reward

```
On Parry Succeeded
  -> Player | HitFlashBehavior: Flash  white  0.05
  -> ScreenFx: Chromatic pulse at 0.5
```

Fifty milliseconds is barely visible and is exactly why a perfect parry feels sharp.

### 7. Heal feedback

```
On Healed
  -> Player | HitFlashBehavior: Flash  Color(0.8, 1, 0.8)  0.25
```

The same grammar as damage, in a colour that means the opposite.

### 8. Boss wind-up

```
On Boss Charging
  -> Boss | HitFlashBehavior: Flash  Color(1, 0.2, 0.2)  1.2
```

A long red drain is a fair warning that costs no screen space.

### 9. Refused input on a UI panel

```
On Buy Pressed
  Condition: Player.coins  <  Item.price
    -> ShopPanel | HitFlashBehavior: Flash  Color(1, 0.3, 0.3)  0.18
```

A Control wears a material like anything else, so UI gets the same feedback the game does.

### 10. Coin collected, then freed

```
On Coin Collected
  -> Coin | HitFlashBehavior: Flash  white  0.1
  -> Wait 0.1 seconds
  -> Coin: queue_free()
```

The wash covers the frame the coin disappears, which hides the pop.

### 11. Only flash when it is not already flashing

```
On Enemy Damaged
  Condition: NOT Enemy | HitFlashBehavior: Is Flashing
    -> Enemy | HitFlashBehavior: Flash  white  0.15
```

For an enemy taking many small hits, this keeps the first flash readable instead of restarting it.

### 12. A whole formation flashing as one

```
On Formation Hit
  -> Grunt1 | HitFlashBehavior: Set Own Material  false
  -> Grunt1 | HitFlashBehavior: Flash  white  0.2
```

With `own_material` off, every node sharing the material file washes together, which is what a
squad taking area damage should look like.

### 13. Invincibility, read as a rhythm

```
Every 0.25 seconds
  Condition: Player.invincible
    -> Player | HitFlashBehavior: Flash  white  0.12
```

A repeating wash reads as protection where a repeating hide reads as a rendering bug.

### 14. Level-up on the whole party

```
On Level Up
  -> Player | HitFlashBehavior: Flash  Color(1, 0.95, 0.6)  0.5
  -> Pet | HitFlashBehavior: Flash  Color(1, 0.95, 0.6)  0.5
```

Gold, slow, and on everything the player owns.

### 15. Silhouette review while designing

```
On Debug Key Pressed
  -> Enemy | HitFlashBehavior: Set effect.flash_amount to 1.0
```

Holding the wash fully on shows a sprite as its outline, which is how you find art that reads badly
against a busy background.

### Other use cases

**Rhythm game targets.** Ring sprites wash on the beat, with the wash length set from the song's
tempo so the flash itself teaches the timing.

**Photograph flash.** A camera item washes the whole subject white for two frames, and the picture
the game takes is the frame after.

**Electric damage.** Two very short washes in quick succession read as a spark where one reads as a
punch.

**Turn-order highlight.** In a tactics game the unit whose turn it is holds a faint wash, so the
active piece is obvious from across the board.

**Ghost and phase states.** A held wash in the background colour makes a unit read as half out of the
world without a second sprite.

---

## Tips and common mistakes

- **The host must wear the material.** The verbs write dials on the host's ShaderMaterial. If you
  clear the material in the Inspector, the behavior warns once and then does nothing. Adding the pack
  again puts it back.
- **This is not the modulate Flash, and both are right.** Use the shipped Flash verb on a node with
  no material and no need for one. Use this when the sprite is dark, when you want a colour that is
  not a tint, or when the wash has to be the same strength on every sprite.
- **Keep it short.** A hit flash lives between about 0.05 and 0.2 seconds. Longer than that and the
  eye reads a state rather than an event, which is a fine thing to want but a different one.
- **A second Flash restarts, it does not stack.** That is usually what you want for a fast string of
  hits: one bright thing rather than a sprite stuck white.
- **Your own copy is the default, and it is the right default.** Only turn `own_material` off when you
  really mean "every node wearing this file, together".
- **The shader file is yours after the first add.** Edits to `res://effects/hit_flash.gdshader`
  survive updates, because nothing here ever overwrites a file that exists.
- **A Control needs its material set on the Control, not on its parent.** UI containers do not pass
  a material down; put the behavior under the node that actually draws.
- **Flash colour alpha is part of the strength.** A `flash_color` with alpha `0.5` washes half as
  hard at full amount, which is a quiet way to soften every flash in one place.
