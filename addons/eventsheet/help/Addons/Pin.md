# Pin - Stick One Object to Another

The event-sheet-parity "pin to" behavior: attach `PinBehavior` to any Node2D, call **Pin To**
with the object it should ride, and from that frame on the host copies that object's
**position**, its **angle**, or both, kept apart by however far the two were standing when the
pin was made. **Unpin** lets go and the host keeps whatever place it had.

The mode decides *how* it follows, not just *what* it copies:

| Mode | What it does | What it is for |
|---|---|---|
| `position` | Lands on the anchor's place every tick. | Health bars, hitboxes, mounted parts. |
| `angle` | Copies the anchor's rotation only. | A gauge needle, a turret that inherits the hull's tilt. |
| `position and angle` | Both. The default. | Anything worn. |
| `rope` | Free to move inside a length; pulled back the moment the line goes taut. | Lanterns, leashes, tethers, wrecking balls. |
| `bar` | Held at exactly that length, every tick, whatever happens. | Carriages, linked carts, rigid arms. |
| `soft` | Closes a share of the gap each second, so it trails behind. | Camera targets, pets, followers that should feel alive. |
| `spring` | Overshoots, wobbles, settles. | Hats, antennae, anything that should bounce when its owner stops. |
| `size` | Copies the anchor's scale and nothing else. | Shadows that swell on landing, rings around resizing tokens. |

Two more knobs cut across all eight: **Pin Axes** follows a column only or a height only, and
**Pin To Point** rides a *named child* of the anchor - a `Marker2D`, a `Bone2D`, the hand a
weapon hangs off - rather than the anchor's own origin.

This is the one-liner a hundred jam scripts write by hand:

```gdscript
global_position = anchor.global_position + pin_offset
rotation = anchor.rotation
```

Opened as a sheet, those two lines already read as `Pin ▸ Pin to anchor (position · offset 0, -20)`
and `Pin ▸ Pin to anchor (angle)`, so the shape and the pack say the same thing. The other modes
read too, from the arithmetic people actually write for them:

```gdscript
global_position = anchor.global_position + (global_position - anchor.global_position).limit_length(80.0)
global_position = anchor.global_position + (global_position - anchor.global_position).normalized() * 80.0
global_position = global_position.lerp(anchor.global_position, 10.0 * delta)
global_position.x = anchor.global_position.x
scale = anchor.scale
```

read as `Pin to anchor (rope, max length 80.0)`, `Pin to anchor (bar, length 80.0)`,
`Pin to anchor softly (speed 10.0)`, `Pin X position to anchor` and `Pin size to anchor`. And a
variable *declared* as a point on somebody - `@onready var hand: Marker2D = $Player/Hand` - turns
`global_position = hand.global_position` into `Pin to Player's hand`, which is the sentence the
author had in their head.

Three of those spellings are deliberately **gated**: `scale = x.scale`, `position.x = x.position.x`
and the per-second `lerp` are among the most general lines in the language - the last of them is
byte for byte how a camera scrolls toward a target - so they only read as a pin in a file that has
already pinned that anchor another way (or copies both axes from it, or declared it as a point on
somebody). A lone axis copy in a parallax layer stays a lone axis copy, and a camera keeps its own
row.

For the same reason only the **rope** and the **bar** are offered as free picker rows (Pin ▸ Pin To
(Rope) / Pin To (Bar)): a picker row's template is also what the importer matches, so a row for one
of the general spellings would silently re-file every such line in every project as a pin. The other
modes are authored by attaching the pack, which is the tidier answer anyway.

Attaching the pack is the tidier of the two: it remembers the offset for you, survives the anchor
being destroyed, and gives you **Is Pinned** and **Is Taut** to ask about.

## Pin or child?

Both mean "this thing goes where that thing goes", and the difference decides what happens when the
other object is destroyed:

- **A pin follows at runtime and can let go.** Unpin, and the host stays exactly where it was. When
  the anchor is destroyed the pin simply stops and **Is Pinned** goes false.
- **A child is structure and is destroyed with its parent.** Use Add Child when the two are one
  thing that lives and dies together.

Doing both to the same object is the classic "it drifts twice as fast" bug - being a child already
carries the host, and the pin then writes its place a second time from the same source. The Doctor
names it as **double follow** with both ways out, and names a pin whose anchor is destroyed without
an Unpin as **pin to a freed object**.

## Seeing the modes side by side

`demo/showcase/pin_modes/` runs six of them at once, with the sheet moving only the anchors - the
post, the engine and the walker - so the differences between the modes ARE the demo. A 3D twin scene
beside it does the same on the Pin 3D pack.

![The Pin Modes showcase running: a lantern hanging from a moving post on a rope, a cart held behind an engine on a bar, and a walking figure carrying a spring-pinned hat, a point-pinned sword, a soft-following camera target and an axis-locked shadow, with a readout reading rope 90 of 90 px, bar 70 of 70 px, soft lag 10 px](../images/pin-modes-showcase.png)

Measured over 360 physics frames of that scene: the rope never exceeds its 90 px and falls to 63.8 px
of slack; the bar holds 70.000 px at both ends of the run; the soft pin trails up to 68.7 px behind.

## Where this pack shines

- **Anything worn.** Hats, backpacks, shields, held weapons - the art rides the character.
- **Anything floating above.** Health bars, name plates, damage numbers, quest markers.
- **Anything mounted or towed.** A turret on a tank, a lantern on a stick, a cart behind an engine.

## Setup

1. Attach `PinBehavior` as a child of the node that should ride something.
2. Position the host where you want it to sit relative to its anchor.
3. Call **Pin To** with the anchor - the gap you set up in step 2 is remembered as the offset. Or
   call one of the mode rows (**Pin To Rope**, **Pin To Bar**, **Pin To Softly**, **Pin To With
   Spring**), which start from the anchor's own place and let the length or the speed do the work.

```
On Ready -> HealthBar | Pin: Pin To  get_parent()
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Pin to **target**
- Pin to *target* on a rope of **max length**
- Pin to *target* softly at **speed**
- Unpin

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Pin To | `target` | Ride an object, remembering the current gap as the offset. |
| Action | Pin To At Offset | `target`, `offset_x`, `offset_y` | Ride an object at a chosen distance instead. |
| Action | Set Pin Offset | `offset_x`, `offset_y` | Change the distance while pinned. |
| Action | Pin To Rope | `target`, `max_length` | Hang off an object; free inside the length, pulled when taut. |
| Action | Pin To Bar | `target`, `length` | Held at exactly that distance every tick. |
| Action | Pin To Softly | `target`, `speed` | Follow with a lag - the share of the gap closed each second. |
| Action | Pin To With Spring | `target`, `stiffness`, `damping` | Follow on a spring: overshoot, wobble, settle. |
| Action | Pin X Position To | `target` | Follow the column only; keep your own height. |
| Action | Pin Y Position To | `target` | Follow the height only; keep your own column. |
| Action | Pin Size To | `target` | Copy the anchor's scale and nothing else. |
| Action | Pin To Point | `target`, `point_name` | Ride a named child of the anchor - a marker, a bone, a hand. |
| Action | Pin To Path | `path_node` | Ride a point travelling a Path2D (or an existing PathFollow2D). |
| Action | Set Path Progress | `ratio` | Drive a path pin along its curve, 0 to 1. |
| Action | Set Pin Mode | `mode` (`position`/`angle`/`position and angle`/`rope`/`bar`/`soft`/`spring`/`size`) | What to copy, and how to travel there. |
| Action | Set Pin Axes | `axes` (`both`/`x only`/`y only`) | Which axes of the place follow. |
| Action | Unpin | - | Let go; the host stays where it was. |
| Condition | Is Pinned | - | True while the host is riding something. |
| Condition | Is Taut | - | True while a rope or bar pin is stretched to its full length. |
| Expression | PinOffsetX / PinOffsetY | - | The current offset, in pixels. |
| Expression | PinDistance | - | How far the host is from its anchor right now. |
| Expression | PinPathProgress | - | How far along its curve a path pin has travelled, 0 to 1. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `pin_mode` | `position and angle` | What the host copies, and how it travels there. |
| `rotate_with_anchor` | `true` | The offset turns with the anchor, so the host orbits it. |
| `pin_enabled` | `true` | Master switch (Unpin turns it off). |
| `pin_length` | `80.0` | The rope's max length, or the bar's exact length, in pixels. |
| `pin_speed` | `10.0` | How much of the gap a soft pin closes each second. |
| `pin_stiffness` | `170.0` | A spring pin's pull toward the anchor. |
| `pin_damping` | `0.85` | 0 oscillates forever, 1 never overshoots. |
| `pin_axes` | `both` | Follow both axes, the column only, or the height only. |
| `pin_follow_size` | `false` | Also copy the anchor's scale, whatever else the mode copies. |
| `pin_point` | `""` | The name of a child of the anchor to ride instead of the anchor. |

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
- `$PinBehavior.pin_length` inserts the **Pin Length** entry straight into any expression

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

A shadow follows the character's column across the ground and ignores the jump entirely. That is
one row, not a per-frame override: **Pin X Position To** leaves the height alone.

```
On Ready -> Shadow | Pin: Pin X Position To  Player
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

### 10. A lantern on a rope

The rope is the point: the lantern hangs free inside its length and is only dragged once the line
goes straight, which is what makes it swing instead of glide.

```
On Ready   -> Lantern | Pin: Pin To Rope  Post, 90
Every tick -> Lantern | add 220 * dt to y
```

### 11. A cart behind an engine

A bar holds its length through every corner, so a train of carts is a chain of one row each - no
joints, no physics bodies, no jitter.

```
On Ready -> Cart1 | Pin: Pin To Bar  Engine, 70
         -> Cart2 | Pin: Pin To Bar  Cart1, 70
```

### 12. A camera target that trails

A camera that snaps to the player feels welded on. Give it a soft pin and a low speed, and the lag
alone makes the movement feel alive.

```
On Ready -> CamTarget | Pin: Pin To Softly  Player, 3
```

### 13. A hat that bounces when you stop

The spring is the difference between "attached" and "alive": stiffness is the pull, damping is how
fast the wobble dies.

```
On Ready -> Hat | Pin: Pin To With Spring  $Player/Head, 140, 0.6
```

### 14. A sword in the hand, not beside the body

**Pin To Point** rides a named child of the anchor, so the weapon follows the hand through every
animation frame rather than the body's origin.

```
On Pick Up -> Sword | Pin: Pin To Point  Player, "Hand"
```

### 15. A shadow that swells on landing

Size is its own follow flag, so a shadow can copy the scale of the thing above it while a different
pin handles its place.

```
On Ready -> Shadow | Pin: Pin Size To  Player
```

### 16. A trolley on a track

Pin to a Path2D and the pack makes the follower for you; **Set Path Progress** then drives the host
along the curve from anywhere in the sheet.

```
On Ready   -> Trolley | Pin: Pin To Path  $Track
Every tick -> Trolley | Pin: Set Path Progress  ride_progress
```

### 17. A side bar riding a lift

The mirror of the shadow: **Pin Y Position To** follows the height and leaves the column alone, so a
UI rail tracks the lift without sliding sideways with it.

```
On Ready -> DepthMarker | Pin: Pin Y Position To  Lift
```

### 18. Ask whether the rope is taut

**Is Taut** is the frame a swing starts pulling - the cue for a creak, a dust puff, or a stamina
drain on a grapple.

```
Every tick
  Condition: Is Taut -> Juice | Play Sound  "rope_creak"
```

### 19. A grapple that reels in

**Set Pin Offset** on a plain pin, or shrinking `pin_length` on a rope, pulls the host in over time.

```
Every tick -> Grapple | Pin: subtract 300 * dt from Pin Length
```

### 20. Ask whether it is still held

**Is Pinned** answers what a hand-written script needs a flag for, and it goes false on its own
when the anchor is destroyed. **PinDistance** is the number behind it.

```
Every tick
  Condition: Is Pinned is false -> Crate | fall
```

### Other use cases

**Split-screen border widget.** Pin a divider sprite to the midpoint marker between two players so the on-screen split follows them without a layout pass.

**Fishing bobber.** Pin the bobber to the float point while the line is out, then unpin the moment a fish bites so it can be yanked under.

**Attached parasite enemy.** A leech pins itself to whatever it lands on, riding its host until shaken off - Unpin is the shake.

**Ghost preview in a builder.** Pin the placement ghost to the snapped grid marker so it never lags a frame behind the cursor's snapping.

**Cutscene prop hand-off.** Pin a torch to the first actor, unpin and re-pin it to the second at the hand-over beat - two rows instead of a keyframed prop track.

## Tips and common mistakes

- **Pin To remembers where you put it; the mode rows do not.** Position the host first, then Pin To -
  the gap at that moment becomes the offset. **Pin To Rope**, **Pin To Bar**, **Pin To Softly** and
  **Pin To With Spring** start from the anchor's own place instead, because the length or the speed
  is what decides where the host ends up.
- **A rope only pulls.** It never pushes the host back out to its length, which is exactly what makes
  it a rope. Give the host something to move it - gravity, a walk, a throw - or the rope has nothing
  to be slack about. A **bar** is the one that holds its length in both directions.
- **The offset turns with the anchor by default.** That is what a worn item wants. For a health
  bar that must stay directly overhead, turn `rotate_with_anchor` off, or set the pin mode to
  `position`.
- **It runs on the physics frame.** Pin a node whose anchor also moves on the physics frame, or
  the pinned node will trail by one frame.
- **A destroyed anchor stops the pin.** The host simply stays where it was, and **Is Pinned**
  goes false - there is nothing to clean up.
- **Do not be a child of the thing you are pinned to.** Being a child already carries the host; the
  pin then writes its place a second time and the two fight. Pick one - the Doctor's *double follow*
  note names both ways out.
