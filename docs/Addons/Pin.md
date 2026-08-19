# Pin - Stick One Object to Another

The event-sheet-parity "pin to" behavior: attach `PinBehavior` to any Node2D, call **Pin To**
with the object it should ride, and from that frame on the host copies that object's
**position**, its **angle**, or both, kept apart by however far the two were standing when the
pin was made. **Unpin** lets go and the host keeps whatever place it had.

This is the one-liner a hundred jam scripts write by hand:

```gdscript
global_position = anchor.global_position + pin_offset
rotation = anchor.rotation
```

Opened as a sheet, those two lines already read as `Pin ▸ Pin to anchor (position · offset 0, -20)`
and `Pin ▸ Pin to anchor (angle)`, so the shape and the pack say the same thing. Attaching the
pack is the tidier of the two: it remembers the offset for you, survives the anchor being
destroyed, and gives you **Is Pinned** to ask about.

## Where this pack shines

- **Anything worn.** Hats, backpacks, shields, held weapons - the art rides the character.
- **Anything floating above.** Health bars, name plates, damage numbers, quest markers.
- **Anything mounted.** A turret on a tank, a light on a helmet, a camera rig on a boat.

## Setup

1. Attach `PinBehavior` as a child of the node that should ride something.
2. Position the host where you want it to sit relative to its anchor.
3. Call **Pin To** with the anchor - the gap you set up in step 2 is remembered as the offset.

```
On Ready -> HealthBar | Pin: Pin To  get_parent()
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Pin to **target**
- Unpin

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Pin To | `target` | Ride an object, remembering the current gap as the offset. |
| Action | Pin To At Offset | `target`, `offset_x`, `offset_y` | Ride an object at a chosen distance instead. |
| Action | Set Pin Offset | `offset_x`, `offset_y` | Change the distance while pinned. |
| Action | Set Pin Mode | `mode` (`position`/`angle`/`position and angle`) | What to copy from the anchor. |
| Action | Unpin | - | Let go; the host stays where it was. |
| Condition | Is Pinned | - | True while the host is riding something. |
| Expression | PinOffsetX / PinOffsetY | - | The current offset, in pixels. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `pin_mode` | `position and angle` | Copy the anchor's place, its angle, or both. |
| `rotate_with_anchor` | `true` | The offset turns with the anchor, so the host orbits it. |
| `pin_enabled` | `true` | Master switch (Unpin turns it off). |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$PinBehavior.pin_mode` inserts the **Pin Mode** entry straight into any expression
- `$PinBehavior.rotate_with_anchor` inserts the **Rotate With Anchor** entry straight into any expression

The `$PinBehavior` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag.

## Use cases

### 1. Health bar over a head

The bar is its own node so it can draw above everything; pinning keeps it honest.

```
On Ready -> HealthBar | Pin: Pin To At Offset  Enemy, 0, -28
```

### 2. Name plate that never rotates

A plate should stay upright even when the enemy tumbles - copy the place, not the angle.

```
On Ready -> Plate | Pin: Set Pin Mode  "position"
         -> Plate | Pin: Pin To  Enemy
```

### 3. A hat that swings with the head

Leave `rotate_with_anchor` on and the offset turns with the anchor, so a hat perched to one
side stays perched to that side when the head turns.

```
On Equip Hat -> Hat | Pin: Pin To  Player
```

### 4. Held weapon

Pin the weapon to the hand marker and it inherits both the place and the swing.

```
On Pick Up -> Sword | Pin: Pin To  $Player/HandMarker
On Drop    -> Sword | Pin: Unpin
```

Unpin leaves the sword exactly where the hand was, which is precisely what dropping means.

### 5. Turret on a tank

The hull drives, the turret aims on its own - so pin the place and leave the angle free.

```
On Ready -> Turret | Pin: Set Pin Mode  "position"
         -> Turret | Pin: Pin To  Hull
```

### 6. Shadow under a jumper

A shadow follows the character across the ground but ignores the jump height. Pin it, then
overwrite the vertical part per frame.

```
On Ready   -> Shadow | Pin: Pin To At Offset  Player, 0, 0
Every tick -> Shadow | set y to ground_y
```

### 7. Damage number that floats away

Pin the number for the first moment so it starts on the target, then unpin and let a tween
carry it up.

```
On Hit -> Number | Pin: Pin To At Offset  Target, 0, -16
       -> Number | Pin: Unpin
       -> Number | tween position by 0, -40 over 0.6
```

### 8. Boss weak point

A weak point is a hitbox that must ride the body exactly, including its rotation.

```
On Ready -> WeakPoint | Pin: Pin To  Boss
```

### 9. Passenger on a moving platform

Riding a platform in a top-down game is a pin, not physics - no friction to tune.

```
On Player Steps On  -> Player | Pin: Pin To  Platform
On Player Steps Off -> Player | Pin: Unpin
```

### 10. Camera rig on a boat

Pin an empty node to the boat, put the Camera2D on the empty, and the camera inherits the
boat's sway without any smoothing code.

```
On Ready -> CamRig | Pin: Pin To  Boat
```

### 11. Quest marker over the objective

One marker node, re-pinned every time the objective changes - no per-objective UI.

```
On New Objective -> Marker | Pin: Pin To At Offset  objective_node, 0, -48
```

### 12. Chained carriages

Each carriage pins to the one in front at a fixed distance - a train with no joints.

```
On Ready -> Carriage2 | Pin: Pin To At Offset  Carriage1, -64, 0
         -> Carriage3 | Pin: Pin To At Offset  Carriage2, -64, 0
```

### 13. Grabbed object in a physics puzzle

The grab beam holds the crate at arm's length; letting go is one action.

```
On Grab    -> Crate | Pin: Pin To At Offset  Player, 48, 0
On Release -> Crate | Pin: Unpin
```

### 14. Ask whether it is still held

**Is Pinned** answers what a hand-written script needs a flag for, and it goes false on its own
when the anchor is destroyed.

```
Every tick
  Condition: Is Pinned is false -> Crate | fall
```

### 15. Lengthening tether

Change the offset while pinned and the host slides out to its new distance - a grapple reeling
in, a balloon rising on its string.

```
Every tick -> Balloon | Pin: Set Pin Offset  0, -tether_length
           -> System | Add 20 * dt to tether_length
```

### Other use cases

**Split-screen border widget.** Pin a divider sprite to the midpoint marker between two players so the on-screen split follows them without a layout pass.

**Fishing bobber.** Pin the bobber to the float point while the line is out, then unpin the moment a fish bites so it can be yanked under.

**Attached parasite enemy.** A leech pins itself to whatever it lands on, riding its host until shaken off - Unpin is the shake.

**Ghost preview in a builder.** Pin the placement ghost to the snapped grid marker so it never lags a frame behind the cursor's snapping.

**Cutscene prop hand-off.** Pin a torch to the first actor, unpin and re-pin it to the second at the hand-over beat - two rows instead of a keyframed prop track.

## Tips and common mistakes

- **Pin To remembers where you put it.** Position the host first, then pin - the gap at that
  moment becomes the offset. Use **Pin To At Offset** when you would rather state the distance.
- **The offset turns with the anchor by default.** That is what a worn item wants. For a health
  bar that must stay directly overhead, turn `rotate_with_anchor` off, or set the pin mode to
  `position`.
- **It runs on the physics frame.** Pin a node whose anchor also moves on the physics frame, or
  the pinned node will trail by one frame.
- **A destroyed anchor stops the pin.** The host simply stays where it was, and **Is Pinned**
  goes false - there is nothing to clean up.
