# Grayscale - Drain the Colour Out of One Node

Grayscale is a Godot EventSheets behavior pack for a state Godot has no other spelling for: a
disabled button, a dead unit still on the board, a memory, a world paused behind a menu. You attach a
`GrayscaleBehavior` under any 2D node or Control, the pack copies its shader into your project and
puts the material on that node, and then **Grayscale** drains the colour over a time you give and
**Recolour** brings it back.

Modulating towards grey darkens instead of draining, and darkening reads as "in shadow" rather than
as "not part of this any more". This drains: the grey it leaves is the eye's own weighting of red,
green and blue, so a saturated red and a saturated blue do not come out as the same middle grey.

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

- **Disabled UI.** A button that cannot be pressed, without a second sprite for every button.
- **Dead units left on the board.** Tactics games where a corpse stays visible but out of play.
- **Locked content.** Levels, skins and cards you have not unlocked.
- **Flashbacks and memories.** A sepia tint on a whole scene layer.
- **Pause.** The world behind a menu, drained while the menu stays in colour.
- **Frozen and petrified.** A cold blue or stone tint on the affected unit.
- **Out of range.** Units too far to be ordered this turn.
- **Health warnings.** Colour draining out of the screen edge as the player weakens.
- **Photo modes.** A monochrome filter that is one row rather than a post-process chain.
- **Ghost previews.** A drained copy of a building showing where it would go.

---

## Core concepts

**The node is the thing drained.** Attach a `GrayscaleBehavior` as a child, and that parent is the
**host**. It must be a `CanvasItem` - any 2D node or UI Control.

**Draining is one dial between 0 and 1.** `grayscale` at 0 is full colour, at 1 is fully grey.
**Grayscale** walks it to the amount you name, **Recolour** walks it back to 0.

**Part-way is a state of its own.** A half-drained node reads as faded rather than as dead, which is
what a disabled-but-still-there control usually wants.

**The grey can be tinted.** `gray_tint` multiplies the grey: white leaves it plain, a cold blue reads
as frozen, a brown as an old photograph. That is a dial rather than a verb, because it says what the
grey looks like rather than when it happens.

**Every node gets its own copy at run time.** A material is a Resource, so two nodes pointing at the
same `.tres` share it. The behavior duplicates it the first time it writes, so draining one card does
not drain the hand. `own_material` turns that off when a whole layer should drain together, which for
a pause screen is exactly what you want.

---

## Setup

**1. Add the pack to the node.** Right-click the object in the Object bar, **Add behavior**,
Grayscale. That adds the `GrayscaleBehavior` child, copies `grayscale.gdshader` and
`grayscale_material.tres` into `res://effects/`, and puts the material on the node as an undoable
scene edit.

**2. Set the knob (optional).**

| Property | Default | What it does |
|---|---|---|
| `own_material` | `true` | Take a private copy of the material before turning a dial. Turn it off when a whole group should drain together. |

**3. Drain it.**

```
On Button Disabled
  -> BuyButton | GrayscaleBehavior: Grayscale to 1 over 0.2 s
On Button Enabled
  -> BuyButton | GrayscaleBehavior: Recolour over 0.2 s
```

---

## ACE reference

All rows target the `GrayscaleBehavior` on the node they are placed on, through the **On node**
parameter every pack row carries (default `$GrayscaleBehavior`).

### Actions

| Row | Parameters | What it does |
|---|---|---|
| **Grayscale** | `amount` (float, default `1.0`), `seconds` (float, default `0.25`) | Drains the colour to that amount over that time. |
| **Recolour** | `seconds` (float, default `0.25`) | Brings the colour back. |
| **Set Own Material** | `value` (bool) | Turns the private-copy rule on or off. |

### Conditions

| Row | What it answers |
|---|---|
| **Is Gray** | True once more than half the colour has gone. |

### Expressions

| Row | What it reads |
|---|---|
| **Grayness** | How much colour has been drained, 0 to 1. |
| **Own Material** | Whether this behavior takes a private copy of the material. |

### The shader's own dials

| Dial | Type | Starts at | What it is |
|---|---|---|---|
| `grayscale` | 0 to 1 | `0.0` | How much colour has been drained. |
| `gray_tint` | colour | white | What the grey is tinted with once the colour is gone. |

---

## Reading it from expressions - the Self section

Type `self` into any ƒx field on a node carrying the pack and its members insert as
`$GrayscaleBehavior.` chains: `$GrayscaleBehavior.is_gray()` as a condition on a rule that should
skip units out of play, `$GrayscaleBehavior.grayness()` where a number should follow the drain.

The tint reads and writes through the picked dial rows: **Set** `effect.gray_tint` is the row that
turns plain grey into sepia.

---

## Use cases

Each example targets the `GrayscaleBehavior` on the named node.

### 1. Disabled button

```
On Coins Changed
  Condition: Player.coins  <  Item.price
    -> BuyButton | GrayscaleBehavior: Grayscale to 1 over 0.15 s
  Else
    -> BuyButton | GrayscaleBehavior: Recolour over 0.15 s
```

### 2. Faded rather than dead

```
On Card Exhausted
  -> Card | GrayscaleBehavior: Grayscale to 0.55 over 0.2 s
```

Half drained says "used this turn"; fully drained says "gone".

### 3. Dead unit left on the board

```
On Unit Killed
  -> Unit | GrayscaleBehavior: Grayscale to 1 over 0.6 s
  -> Unit: disable input
```

### 4. Locked level in a menu

```
On Menu Opened
  Condition: NOT Save.levels_unlocked.has(Level.id)
    -> LevelIcon | GrayscaleBehavior: Grayscale to 1 over 0.0 s
```

Zero seconds is a straight set, which is what a menu opening wants.

### 5. Pause drains the world

```
On Pause Pressed
  -> WorldLayer | GrayscaleBehavior: Set Own Material  false
  -> WorldLayer | GrayscaleBehavior: Grayscale to 0.85 over 0.25 s
```

With the private copy off, every node wearing the file drains together, which is how a whole layer
goes quiet behind a menu.

### 6. Frozen, in cold blue

```
On Frozen
  -> Enemy | GrayscaleBehavior: Set effect.gray_tint to Color(0.7, 0.85, 1)
  -> Enemy | GrayscaleBehavior: Grayscale to 1 over 0.15 s
On Thawed
  -> Enemy | GrayscaleBehavior: Recolour over 0.4 s
```

### 7. Petrified, in stone brown

```
On Petrified
  -> Enemy | GrayscaleBehavior: Set effect.gray_tint to Color(0.85, 0.8, 0.72)
  -> Enemy | GrayscaleBehavior: Grayscale to 1 over 0.8 s
```

### 8. Flashback

```
On Flashback Started
  -> SceneLayer | GrayscaleBehavior: Set effect.gray_tint to Color(1, 0.9, 0.72)
  -> SceneLayer | GrayscaleBehavior: Grayscale to 0.9 over 1.2 s
```

Sepia is grey with a warm tint, so it is the same two rows.

### 9. Out of range this turn

```
On Turn Started
  Condition: Unit.action_points  ==  0
    -> Unit | GrayscaleBehavior: Grayscale to 0.7 over 0.2 s
```

### 10. Health draining the colour out of the screen edge

```
On Health Changed
  -> Vignette | GrayscaleBehavior: Set effect.grayscale to 1.0 - (Player.hp / Player.max_hp)
```

### 11. Skip the units that are out

```
On End Turn
  For each Unit
    Condition: NOT Unit | GrayscaleBehavior: Is Gray
      -> Unit: refresh action points
```

The picture and the rule are the same fact, so they cannot disagree.

### 12. Ghost preview of a building

```
On Building Picked Up
  -> Preview | GrayscaleBehavior: Grayscale to 0.8 over 0.0 s
```

### 13. Photo mode filter

```
On Filter Chosen  -> filter
  Condition: filter  ==  "mono"
    -> Camera2D/Screen | GrayscaleBehavior: Grayscale to 1 over 0.4 s
```

### 14. Colour returning as a reward

```
On Colour Restored
  -> WorldLayer | GrayscaleBehavior: Recolour over 3.0 s
```

A slow recolour is a whole story beat and is one row.

### 15. Drain that follows a countdown

```
Every tick
  -> Portal | GrayscaleBehavior: Set effect.grayscale to 1.0 - (Portal.seconds_left / 30.0)
```

Setting the dial straight is the row for a drain that tracks a number continuously; the verbs are for
moments.

### Other use cases

**Replay and slow-motion.** A drained world during a kill-cam replay reads as "this already happened"
without a caption.

**Two-player split screen.** Drain the half belonging to the player who has been eliminated, so the
screen states it rather than a banner.

**Difficulty preview.** Options the current save cannot pick drain in the menu, and recolour as the
requirements are met.

**Sleep and dreams.** Grayscale with a deep blue tint on the world layer while the character sleeps,
recoloured on waking.

**Print-ready art export.** A single row drains the whole scene for a black and white promotional
image, with no separate export path.

---

## Tips and common mistakes

- **Draining is not darkening.** If you want the node darker, modulate it. This takes the colour out
  and leaves the brightness, which is what reads as "out of play".
- **Part-way is a real answer.** Do not reach for 1 every time. Around 0.5 to 0.7 is the range that
  says faded rather than dead.
- **Zero seconds is a straight set.** Use it when a menu opens and everything should already be in
  its state.
- **The tint multiplies the grey.** A tint darker than white will also darken; keep it near white
  unless you mean sepia or stone.
- **Turn the private copy off for a whole layer.** A pause screen wants every node draining together,
  and that is exactly what `own_material` off does.
- **A Control passes nothing down.** Put the behavior under the node that actually draws.
- **Is Gray asks about half.** It is a question about state, not a comparison. Use the **Grayness**
  expression when you need the number.
- **The shader file is yours after the first add.** Edits to `res://effects/grayscale.gdshader`
  survive updates, because nothing here ever overwrites a file that exists.
