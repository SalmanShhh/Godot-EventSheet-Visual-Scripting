# Outline - A Border Around What the Sprite Actually Is

Outline is a Godot EventSheets behavior pack for the selection ring, the highlight and the "you can
interact with this" border. You attach an `OutlineBehavior` under any 2D node or Control, the pack
copies its shader into your project and puts the material on that node, and then **Outline** draws a
border in a colour and a thickness, **No Outline** clears it, and **Fade Outline** breathes it in or
out over a time.

The border follows the sprite's own alpha, so it is the shape of the art rather than the shape of its
rectangle. That is the whole difference between a highlight that looks made for the game and one that
looks like a debug box.

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

- **Selection in a strategy game.** The unit under the cursor, and the units in the current order.
- **Interactables.** Anything the player can pick up, open or talk to, marked while they are near.
- **Inventory and shop slots.** The hovered item, the equipped item, the one that cannot be afforded.
- **Tutorials.** Ring the one thing the player is supposed to click.
- **Team colours.** A border is the cheapest way to say whose unit this is.
- **Rarity.** Gold, purple and grey borders on loot, with nothing else changed.
- **Stealth and vision cones.** Outline the enemy that has seen you.
- **Puzzle matching.** Ring the pieces that make a set.
- **Accessibility.** A thick, high-contrast border for players who cannot rely on colour alone.
- **Photo modes and editors.** The object currently being moved.

---

## Core concepts

**The node is the thing outlined.** Attach an `OutlineBehavior` as a child, and that parent is the
**host**. It must be a `CanvasItem` - any 2D node or UI Control.

**The border is drawn inside the node's own rectangle.** A canvas_item shader may only colour pixels
the node already covers, so a sprite whose art runs right to the edge of its image has nowhere to put
a border. Give the image a few transparent pixels of margin and the outline appears. This is a
property of the picture rather than of the pack, and it catches everybody once.

**Thickness is in the sprite's own pixels.** A node scaled up in the scene gets a border scaled up
with it, which is usually what you want and is worth knowing when it is not.

**No Outline leaves the colour where it was.** Clearing sets the thickness to 0 and nothing else, so
the next Outline with the same colour is a one-argument row.

**Every node gets its own copy at run time.** A material is a Resource, so two nodes pointing at the
same `.tres` share it. The behavior duplicates it the first time it writes, so highlighting one unit
does not highlight the army. `own_material` turns that off when a whole group should light together.

---

## Setup

**1. Add the pack to the node.** Right-click the object in the Object bar, **Add behavior**, Outline.
That adds the `OutlineBehavior` child, copies `outline.gdshader` and `outline_material.tres` into
`res://effects/`, and puts the material on the node as an undoable scene edit.

**2. Give the art room (if it needs it).** If the sprite's pixels touch the edge of its image, add a
few transparent pixels of padding, or turn on the texture's region with margin.

| Property | Default | What it does |
|---|---|---|
| `own_material` | `true` | Take a private copy of the material before turning a dial, so this node's border is its own. |

**3. Ring it.**

```
On Mouse Entered  -> Unit
  -> Unit | OutlineBehavior: Outline  yellow  2 px
On Mouse Exited  -> Unit
  -> Unit | OutlineBehavior: No Outline
```

---

## ACE reference

All rows target the `OutlineBehavior` on the node they are placed on, through the **On node**
parameter every pack row carries (default `$OutlineBehavior`).

### Actions

| Row | Parameters | What it does |
|---|---|---|
| **Outline** | `colour` (Color, default white), `pixels` (float, default `2.0`) | Draws a border of that colour and thickness. |
| **No Outline** | none | Clears the border, leaving the colour set. |
| **Fade Outline** | `pixels` (float, default `0.0`), `seconds` (float, default `0.25`) | Walks the thickness to a value over a time, for a border that breathes. |
| **Set Own Material** | `value` (bool) | Turns the private-copy rule on or off. |

### Conditions

| Row | What it answers |
|---|---|
| **Is Outlined** | True while a border is being drawn. |

### Expressions

| Row | What it reads |
|---|---|
| **Own Material** | Whether this behavior takes a private copy of the material. |

### The shader's own dials

| Dial | Type | Starts at | What it is |
|---|---|---|---|
| `outline_color` | colour | white | The colour drawn around the sprite. |
| `outline_width` | 0 to 16 | `0.0` | Thickness in the sprite's own pixels. 0 is no outline. |

---

## Reading it from expressions - the Self section

Type `self` into any ƒx field on a node carrying the pack and its members insert as
`$OutlineBehavior.` chains: `$OutlineBehavior.is_outlined()` as a condition when a rule should only
run on the highlighted thing.

The dials read back through the picked dial rows: `effect.outline_width` as an expression is the
current thickness, which is a fine input to a pulse.

---

## Use cases

Each example targets the `OutlineBehavior` on the named node.

### 1. Hover highlight

```
On Mouse Entered  -> Unit
  -> Unit | OutlineBehavior: Outline  yellow  2 px
On Mouse Exited  -> Unit
  -> Unit | OutlineBehavior: No Outline
```

### 2. Selection, in a different colour from hover

```
On Unit Selected
  -> Unit | OutlineBehavior: Outline  Color(0.3, 0.8, 1)  3 px
On Unit Deselected
  -> Unit | OutlineBehavior: No Outline
```

Two colours and two thicknesses give hover and selection without a second sprite.

### 3. Interactable within reach

```
Every 0.2 seconds
  Condition: Player.position.distance_to(Chest.position)  <  80
    -> Chest | OutlineBehavior: Outline  white  2 px
  Else
    -> Chest | OutlineBehavior: No Outline
```

### 4. A border that breathes

```
On Quest Item Found
  -> Relic | OutlineBehavior: Outline  Color(1, 0.85, 0.3)  1 px
Every 0.8 seconds
  -> Relic | OutlineBehavior: Fade outline to 4 px over 0.4 s
  -> Wait 0.4 seconds
  -> Relic | OutlineBehavior: Fade outline to 1 px over 0.4 s
```

### 5. Team colours

```
On Unit Spawned
  -> Unit | OutlineBehavior: Outline  Unit.team_colour  2 px
```

One row, and every unit on the field says whose it is.

### 6. Loot rarity

```
On Item Dropped
  -> Item | OutlineBehavior: Outline  RARITY_COLOURS[Item.rarity]  2 px
```

### 7. Tutorial pointer

```
On Tutorial Step 3
  -> InventoryButton | OutlineBehavior: Fade outline to 5 px over 0.3 s
On Tutorial Step 4
  -> InventoryButton | OutlineBehavior: No Outline
```

A Control wears a material like anything else, so UI gets the same ring the game does.

### 8. The enemy that has seen you

```
On Enemy Alerted
  -> Enemy | OutlineBehavior: Outline  Color(1, 0.2, 0.2)  2 px
On Enemy Lost Player
  -> Enemy | OutlineBehavior: No Outline
```

### 9. Cannot afford it

```
On Shop Opened
  Condition: Player.coins  <  Item.price
    -> ItemCard | OutlineBehavior: Outline  Color(0.6, 0.2, 0.2)  2 px
```

### 10. Matching pieces in a puzzle

```
On Piece Picked Up
  -> MatchA | OutlineBehavior: Outline  Color(0.4, 1, 0.6)  3 px
  -> MatchB | OutlineBehavior: Outline  Color(0.4, 1, 0.6)  3 px
```

### 11. High-contrast accessibility mode

```
On Settings Changed
  Condition: Settings.high_contrast
    -> Player | OutlineBehavior: Outline  white  4 px
```

A thick white border is a real accessibility feature and costs one row.

### 12. A whole group lighting together

```
On Squad Selected
  -> Trooper1 | OutlineBehavior: Set Own Material  false
  -> Trooper1 | OutlineBehavior: Outline  Color(0.3, 0.9, 0.4)  2 px
```

With the private copy off, every node wearing the file rings as one.

### 13. Only act on the highlighted thing

```
On Click
  Condition: Chest | OutlineBehavior: Is Outlined
    -> Chest: open
```

The border becomes the state as well as the picture, so there is no second flag to keep in step.

### 14. Fade it out rather than snapping

```
On Deselected
  -> Unit | OutlineBehavior: Fade outline to 0 px over 0.2 s
```

### 15. Thickness that follows a value

```
On Charge Changed
  -> Sword | OutlineBehavior: Set effect.outline_width to Player.charge * 6.0
```

Setting the dial straight is the row for a border that tracks a number continuously.

### Other use cases

**Photo mode.** The object currently being dragged carries a thin white ring, so the player can see
what the controls are attached to.

**Colour-blind mode.** Swap every rarity colour for a distinct thickness instead, and the same rows
carry the information without relying on hue.

**Cursor-free console UI.** The focused card in a grid holds a border that moves with the stick,
which is the whole focus indicator.

**Damage-type marking.** Enemies weak to the equipped element ring faintly, so target choice reads
from the field rather than from a menu.

**Screenshot cleanup.** Turn every outline off in one row before a promotional shot, by clearing the
shared material with the private copy off.

---

## Tips and common mistakes

- **The art needs margin.** The border is drawn inside the node's own rectangle. A sprite whose
  pixels touch the edge of its image has nowhere for a border to go, and looks like the pack is
  broken. A few transparent pixels fix it.
- **Thickness is in the sprite's pixels, not the screen's.** A node at scale 3 has a border three
  times as thick on screen. Divide by the scale where that matters.
- **No Outline keeps the colour.** That is deliberate, so a repeat highlight is one argument. If you
  want the colour back to white, say so.
- **Very thick borders cost more.** The shader samples eight neighbours whatever the thickness, so the
  cost is flat, but a thickness above about 8 pixels starts to look like a glow rather than a line.
- **A Control passes nothing down.** Put the behavior under the node that actually draws, not under
  its container.
- **Your own copy is the default.** Only turn `own_material` off when you really mean "every node
  wearing this file, together".
- **The shader file is yours after the first add.** Edits to `res://effects/outline.gdshader` survive
  updates, because nothing here ever overwrites a file that exists.
- **An outline on a fully opaque rectangle is invisible.** There is no transparent pixel for the
  border to be drawn in. Outline works on shapes, not on solid blocks.
