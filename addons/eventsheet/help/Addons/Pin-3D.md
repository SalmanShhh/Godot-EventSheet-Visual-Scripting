# Pin 3D - Stick One 3D Object to Another

`Pin3DBehavior` is the Pin behavior's twin for a `Node3D` host, mode for mode. Attach it as a child
of the node that should ride something, call **Pin To** with the object, and from that frame on the
host copies that object's **position**, its **angles**, or both, kept apart by however far the two
were standing when the pin was made. **Unpin** lets go and the host keeps whatever place it had.

Pinning is the most-written relationship in a game - a health bar over a head, a weapon in a hand, a
camera target that lags, a lantern on a rope - and until this pack it had to be written out in three
axes every time.

The mode decides *how* it follows, not just *what* it copies:

| Mode | What it does | What it is for |
|---|---|---|
| `position` | Lands on the anchor's place every tick. | Nameplates, hitboxes, mounted parts. |
| `angle` | Copies the anchor's rotation only. | A gauge, a part that inherits a vehicle's tilt. |
| `position and angle` | Both. The default. | Anything worn. |
| `rope` | Free to move inside a length; pulled back the moment the line goes taut. | Lanterns, leashes, tethers, wrecking balls. |
| `bar` | Held at exactly that length, every tick, whatever happens. | Carriages, tow bars, rigid arms. |
| `soft` | Closes a share of the gap each second, so it trails behind. | Chase-camera targets, pets, drones. |
| `spring` | Overshoots, wobbles, settles. | Hats, antennae, backpacks that bounce on landing. |
| `size` | Copies the anchor's scale and nothing else. | Shadow decals that swell on landing. |

## The one difference from the 2D pack: the seat

In 2D a named point is a `Marker2D` or a `Bone2D`. In 3D it is usually a **BoneAttachment3D** - the
node Godot already keeps glued to a `Skeleton3D` bone. **Pin To Point** takes that node's *name*, so
"pin the sword to the hand" is one row and the skeleton does the hard half:

```
On Pick Up -> Sword | Pin 3D: Pin To Point  Player, "HandAttachment"
```

Any child of the anchor works - a `Marker3D` on a prop, a socket node on a vehicle - and a name that
matches nothing falls back to the anchor rather than silently dropping the pin.

Everything else - rope, bar, soft, spring, one axis at a time, size, path - is the 2D pack's meaning
with a `Vector3`. **Pin Axes** grows a third option (`z only`) and there is a **Pin Z Position To**
row and a **PinOffsetZ** expression to match.

## Pin or child?

Both mean "this thing goes where that thing goes", and the difference decides what happens when the
other object is destroyed:

- **A pin follows at runtime and can let go.** Unpin, and the host stays exactly where it was. When
  the anchor is destroyed the pin simply stops and **Is Pinned** goes false.
- **A child is structure and is destroyed with its parent.** Use Add Child when the two are one
  thing that lives and dies together.

Doing both to the same object is the classic "it drifts twice as fast" bug, and the Doctor names it.

## Where this pack shines

- **Rigged characters.** Weapons, shields, torches and cosmetics riding a skeleton's attachments.
- **Vehicles and trains.** Tow bars, carriages, trailers - a chain of one row each, no joints.
- **Cameras and markers.** Soft-following aim points, world-space nameplates, ground shadows.

## Setup

1. Attach `Pin3DBehavior` as a child of the node that should ride something.
2. Place the host where you want it to sit relative to its anchor.
3. Call **Pin To** with the anchor - the gap you set up in step 2 is remembered as the offset. Or
   call one of the mode rows (**Pin To Rope**, **Pin To Bar**, **Pin To Softly**, **Pin To With
   Spring**), which start from the anchor's own place and let the length or the speed do the work.

```
On Ready -> Nameplate | Pin 3D: Pin To At Offset  Enemy, 0, 2.2, 0
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
| Action | Pin To At Offset | `target`, `offset_x`, `offset_y`, `offset_z` | Ride an object at a chosen distance instead. |
| Action | Set Pin Offset | `offset_x`, `offset_y`, `offset_z` | Change the distance while pinned. |
| Action | Pin To Rope | `target`, `max_length` | Hang off an object; free inside the length, pulled when taut. |
| Action | Pin To Bar | `target`, `length` | Held at exactly that distance every tick. |
| Action | Pin To Softly | `target`, `speed` | Follow with a lag - the share of the gap closed each second. |
| Action | Pin To With Spring | `target`, `stiffness`, `damping` | Follow on a spring: overshoot, wobble, settle. |
| Action | Pin X Position To | `target` | Follow along X only. |
| Action | Pin Y Position To | `target` | Follow the height only. |
| Action | Pin Z Position To | `target` | Follow along Z only. |
| Action | Pin Size To | `target` | Copy the anchor's scale and nothing else. |
| Action | Pin To Point | `target`, `point_name` | Ride a named child - usually a BoneAttachment3D. |
| Action | Pin To Path | `path_node` | Ride a point travelling a Path3D (or an existing PathFollow3D). |
| Action | Set Path Progress | `ratio` | Drive a path pin along its curve, 0 to 1. |
| Action | Set Pin Mode | `mode` (`position`/`angle`/`position and angle`/`rope`/`bar`/`soft`/`spring`/`size`) | What to copy, and how to travel there. |
| Action | Set Pin Axes | `axes` (`all`/`x only`/`y only`/`z only`) | Which axes of the place follow. |
| Action | Unpin | - | Let go; the host stays where it was. |
| Condition | Is Pinned | - | True while the host is riding something. |
| Condition | Is Taut | - | True while a rope or bar pin is stretched to its full length. |
| Expression | PinOffsetX / PinOffsetY / PinOffsetZ | - | The current offset, in world units. |
| Expression | PinDistance | - | How far the host is from its anchor right now. |
| Expression | PinPathProgress | - | How far along its curve a path pin has travelled, 0 to 1. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `pin_mode` | `position and angle` | What the host copies, and how it travels there. |
| `rotate_with_anchor` | `true` | The offset rides the anchor's own frame, so the host orbits it. |
| `pin_enabled` | `true` | Master switch (Unpin turns it off). |
| `pin_length` | `2.0` | The rope's max length, or the bar's exact length, in world units. |
| `pin_speed` | `10.0` | How much of the gap a soft pin closes each second. |
| `pin_stiffness` | `170.0` | A spring pin's pull toward the anchor. |
| `pin_damping` | `0.85` | 0 oscillates forever, 1 never overshoots. |
| `pin_axes` | `all` | Follow all three axes, or one line of the world only. |
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

- `$Pin3DBehavior.pin_mode` inserts the **Pin Mode** entry straight into any expression
- `$Pin3DBehavior.pin_length` inserts the **Pin Length** entry straight into any expression

The `$Pin3DBehavior` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag.

## Use cases

### 1. Weapon in a rigged hand

The skeleton keeps the attachment on the bone; the pin keeps the sword on the attachment.

```
On Pick Up -> Sword | Pin 3D: Pin To Point  Player, "HandAttachment"
On Drop    -> Sword | Pin 3D: Unpin
```

### 2. World-space nameplate

A plate above the head that must stay upright even when the enemy leans.

```
On Ready -> Nameplate | Pin 3D: Set Pin Mode  "position"
         -> Nameplate | Pin 3D: Pin To At Offset  Enemy, 0, 2.2, 0
```

### 3. Chase-camera aim point

Point the camera at a soft-pinned target rather than the player, and the whole rig gains a lag you
can tune with one number.

```
On Ready -> AimPoint | Pin 3D: Pin To Softly  Player, 3
```

### 4. Backpack that bounces on landing

Spring the pack to a spine attachment and it settles after every jump without an animation.

```
On Ready -> Backpack | Pin 3D: Pin To With Spring  $Player/SpineAttachment, 140, 0.6
```

### 5. Trailer behind a truck

A bar holds its length through every corner - a tow hitch with no joint to configure.

```
On Ready -> Trailer | Pin 3D: Pin To Bar  Truck, 4
```

### 6. Wrecking ball on a crane

The rope is the point: the ball hangs free inside its length and only swings once the line goes
straight.

```
On Ready   -> Ball | Pin 3D: Pin To Rope  $Crane/Hook, 6
Every tick -> Ball | subtract 9.8 * dt from y
```

### 7. Ground shadow decal

Follow the character across the floor and keep your own height, so the decal stays on the ground
whatever the jump does.

```
On Ready -> ShadowDecal | Pin 3D: Pin X Position To  Player
         -> ShadowDecal | Pin 3D: Set Pin Axes  "all"
```

### 8. A shadow that swells on landing

Size is its own follow, so the decal can grow with the thing above it.

```
On Ready -> ShadowDecal | Pin 3D: Pin Size To  Player
```

### 9. Water line marker

The mirror of the shadow: follow only the height, so a depth gauge rides the lift without sliding
with it.

```
On Ready -> DepthGauge | Pin 3D: Pin Y Position To  Lift
```

### 10. Mine cart on a rail

Pin to a Path3D and the pack makes the follower for you; **Set Path Progress** drives it.

```
On Ready   -> Cart | Pin 3D: Pin To Path  $Rail
Every tick -> Cart | Pin 3D: Set Path Progress  ride_progress
```

### 11. Turret on a hull

Pin the place and leave the angles free, so the hull drives and the turret aims on its own.

```
On Ready -> Turret | Pin 3D: Set Pin Mode  "position"
         -> Turret | Pin 3D: Pin To  Hull
```

### 12. Passenger on a moving platform

Riding a lift is a pin, not physics - no friction to tune and nothing to slide off.

```
On Player Steps On  -> Player | Pin 3D: Pin To  Platform
On Player Steps Off -> Player | Pin 3D: Unpin
```

### 13. Torch handed between actors in a cutscene

Two rows instead of a keyframed prop track.

```
On Hand Over -> Torch | Pin 3D: Unpin
             -> Torch | Pin 3D: Pin To Point  ActorB, "HandAttachment"
```

### 14. Grapple that reels in

Shrink the rope and the host is pulled along it, because a rope pulls the moment it is taut.

```
Every tick -> Player | Pin 3D: subtract 6 * dt from Pin Length
```

### 15. Ask whether the line is taut

**Is Taut** is the frame a swing starts pulling - the cue for a creak, a dust puff, a stamina drain.

```
Every tick
  Condition: Is Taut -> Juice 3D | Play Sound  "rope_creak"
```

### 16. A drone that keeps station

A soft pin with an offset lets an escort hover beside its owner and catch up when it moves.

```
On Ready -> Drone | Pin 3D: Pin To Softly  Player, 2
         -> Drone | Pin 3D: Set Pin Offset  1.5, 2, 0
```

### 17. Ask how far it has drifted

**PinDistance** is the number behind the feel: a soft pin's lag, a rope's slack, a spring's
overshoot are all one expression.

```
Every tick
  Condition: PinDistance > 4 -> Camera | Snap To  Player
```

### Other use cases

**Multiplayer name tags.** One pinned plate per player, re-pinned as players join and leave, with no per-plate script.

**Held torch light.** Pin an OmniLight3D to the hand attachment so the light swings with the animation instead of hovering at the body's origin.

**Wing mirrors and gun sockets.** Pin each accessory to its own named socket on the vehicle, so a swapped body needs no code change.

**Boss weak point.** A hitbox pinned to a named attachment rides the animation exactly, including the frames a hand-placed collider would miss.

**Debug gizmo.** Pin a marker mesh to whatever you are inspecting, then Unpin to leave it behind as a breadcrumb.

## Tips and common mistakes

- **Pin To remembers where you put it; the mode rows do not.** Place the host first, then Pin To -
  the gap at that moment becomes the offset. **Pin To Rope**, **Pin To Bar**, **Pin To Softly** and
  **Pin To With Spring** start from the anchor's own place instead.
- **A rope only pulls.** It never pushes the host back out to its length. Give the host something to
  move it - gravity, a walk, a throw - or the rope has nothing to be slack about. A **bar** is the
  one that holds its length in both directions.
- **The offset rides the anchor's own frame by default.** That is what a worn item wants; turn
  `rotate_with_anchor` off for anything that must stay world-aligned, like a nameplate.
- **Point names are looked up fresh each frame.** A rig that re-parents its attachments cannot leave
  the pin holding a stale node, and a name that matches nothing falls back to the anchor.
- **It runs on the physics frame.** Pin a node whose anchor also moves on the physics frame, or the
  pinned node will trail by one frame.
- **Do not be a child of the thing you are pinned to.** Being a child already carries the host; the
  pin then writes its place a second time and the two fight. Pick one.
