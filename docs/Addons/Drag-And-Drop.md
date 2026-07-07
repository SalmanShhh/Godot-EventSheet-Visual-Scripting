# Drag And Drop - Pick Up, Move, Snap, and Throw, One Behavior Per Node

Drag And Drop is a Godot EventSheets behavior pack that turns any 2D node into something you can pick up, move, snap into place, and throw. You attach a `DragDropBehavior` behavior to a `Node2D` (its parent becomes the host), and that node becomes draggable. There is no drag manager to pass around: every Action, Condition, Expression, and Trigger targets the behavior living on the node you drop it on. The one rule that shapes everything: this pack is event-driven and does not read input for you. You feed it a drag point every tick from whatever source you like - the mouse, a touch, a gamepad cursor, or even an AI - and the behavior handles the rest: follow-speed lag, direction locking, snapping and magnetism, break-distance auto-drop, and a measured throw velocity you route on release. Because the node is the host, there is no object id threaded through every call.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Point-and-drag objects.** Pick up a sprite with the mouse or a finger, move it, and set it down - the classic grab that most 2D games need at some point.
- **Inventory and equipment slots.** Register each slot as a snap target so an item clicks into the nearest valid slot on release, and read back which slot it landed on.
- **Card games.** Drag a card, magnet it toward a play zone, snap it home, or flick it to the discard pile with the measured throw velocity.
- **Puzzle pieces on a grid.** Add fixed snap positions for the grid cells and lock movement to four or eight directions so pieces slide cleanly.
- **Physics throwing and flick mechanics.** The pack auto-measures how fast you were flinging on release, so a slingshot, a bowling ball, or a thrown bomb inherits real momentum.
- **Sliders, dials, and knobs.** Lock the drag to one axis with direction locking and read the drag point to drive a value - a volume knob, a health-bar scrubber, a difficulty slider.
- **Magnetic placement helpers.** Turn on magnetism so a piece is gently pulled toward the closest valid spot as you drag, making precise placement feel forgiving.
- **Tower or unit placement.** Drag a tower out of a build tray and let it snap onto the nearest grid node, then confirm placement in the drop trigger.
- **World-space UI and markers.** Drag a minimap pin, a waypoint flag, or a movable HUD panel that lives in the 2D world.
- **Non-mouse dragging.** Feed the drag point from a virtual gamepad cursor or a touch position - the pack never assumes the mouse, so console and mobile builds use the same rows.
- **Follow-another-object drags.** Start a drag that tracks a second node each tick, so an object can be dragged by a hand rig, a controller reticle, or an AI toward a goal.
- **Tear-off and break-away drags.** Set a break distance so a drag auto-ends when the pointer outruns the object - pull a card off a stack, or drop something that gets stuck on a wall.

---

## Core concepts

The mental model is small. Learn these ideas and the rest is just rows.

**The node is the host.** You attach a `DragDropBehavior` to a `Node2D`, and its parent is the thing that moves. Every ACE acts on that behavior, so there is no drag id or object handle to pass. One behavior, one draggable node.

**You feed the drag point; the pack never reads input.** This is the most important idea. The behavior does not poll the mouse or a key. Instead, you begin a drag with **Start Drag** at a point, then call **Set Drag Point** every tick with the current pointer position, and end it with **Drop**. Where that point comes from - `get_global_mouse_position()`, a touch, a gamepad cursor - is entirely your choice, which is why the same rows work on desktop, mobile, and console.

**The drag lifecycle is three moves.** Begin (Start Drag), track (Set Drag Point each tick while dragging), and release (Drop). Between begin and release the behavior moves the host toward the drag point on its own every frame.

**Grab mode decides the pickup feel.** When you Start Drag, `grab_mode` 0 keeps the offset between the host and the grab point, so the object holds wherever you grabbed it and does not jump. `grab_mode` 1 centres the object on the point instead. Use 0 for natural pickups, 1 for "the object teleports under the cursor."

**Following can lag and lock.** By default the host snaps to the drag point instantly each tick. Give it a **Set Follow Speed** above 0 and it eases toward the point at a maximum pixels-per-second, for a heavy or rubber-band feel. **Set Directions** locks movement to an axis or a grid: free, up/down, left/right, four-direction, or eight-direction.

**Snapping and magnetism guide placement.** Register snap targets with **Add Snap Position** (a fixed point) or **Add Snap Object** (a live node whose position is the target). **Set Snap Radius** is the distance within which snapping engages on release. Turn on **Set Magnet Strength** (0 to 1) together with a snap radius and the drag is actively pulled toward the nearest target as you move, not just on release.

**Throw velocity is measured, not applied.** While you drag, the pack samples how fast the drag point is moving. On a normal Drop it exposes that as **Throw Velocity X / Y** and **Throw Speed**, but it does not launch the object for you - you read those values in **On Dropped** and apply them to a physics body or your own velocity variable. A drop that snaps to a target has zero throw. You can also override the next throw with **Set Throw Velocity** for fixed-impulse launches.

**Break distance auto-ends a runaway drag.** With **Set Break Distance** above 0, the drag ends automatically once the host falls further than that gap behind the drag point (for example, the object is blocked by a wall while the cursor keeps going). The `action` decides whether that break drops (applies throw/snap) or cancels silently.

**Triggers tell you what happened.** React in **On Drag Started**, **On Dropped**, **On Drag Cancelled**, and **On Snapped**. Read **Drop Reason** inside a drop to tell a real release ("manual") from an auto-break ("broke_distance").

---

## Setup

**1. Attach the behavior.** Add a `DragDropBehavior` behavior as a child of the `Node2D` you want to drag (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The host is the behavior's parent, so the parent must be a `Node2D` (a Sprite2D, an Area2D, a CharacterBody2D, and so on all qualify). One behavior per draggable node.

**2. Set the Inspector knobs.** Select the behavior node and tune the feel:

| Property | Default | What it does |
|---|---|---|
| `enabled` | `true` | Active at start; disabling it mid-drag cancels the drag silently. |
| `follow_speed` | `0.0` | Max catch-up speed in pixels per second; 0 means instant snap to the point each tick. |
| `break_distance` | `0.0` | Gap that auto-ends the drag once the host lags this far behind the point; 0 disables. |
| `directions` | `free` | Per-tick movement lock: free, up_down, left_right, four_dir, or eight_dir. |

**3. Wire the drag loop.** Three moves: begin on a grab, feed the point while dragging, release on let-go. Here is a complete first drag - a piece the mouse picks up and puts down:

```
On "grab" pressed
  -> Piece | DragDropBehavior: Start Drag  get_global_mouse_position().x, get_global_mouse_position().y, 0

Every tick
  Condition: Piece | DragDropBehavior  Is Dragging
    -> Piece | DragDropBehavior: Set Drag Point  get_global_mouse_position().x, get_global_mouse_position().y

On "grab" released
  -> Piece | DragDropBehavior: Drop  0
```

`grab_mode` 0 keeps the offset, so the piece holds wherever you clicked it instead of jumping its centre to the cursor. Feed the point every tick only while **Is Dragging** is true, and pass `how` 0 to Drop so the release applies the throw or snap.

---

## ACE reference

All ACEs live in the **Drag & Drop** category and target the `DragDropBehavior` behavior on the node they are placed on. There is no drag-id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Start Drag | `drag_point_x` (float), `drag_point_y` (float), `grab_mode` (int) | Begins a drag at a point. `grab_mode` 0 keeps the offset from the host; 1 centres the host on the point. Does nothing if disabled or already dragging. |
| Start Drag At Object | `target` (Node2D), `grab_mode` (int) | Begins a drag that follows the given object's position each tick until you call Set Drag Point. `grab_mode` as above. |
| Drop | `how` (int) | Ends the drag. `how` 0 applies the throw or snap; 1 cancels silently. |
| Set Drag Point | `x` (float), `y` (float) | Updates the drag point; call it each tick from your input source. Also clears any object-follow set by Start Drag At Object. |
| Set Drag Point To Object | `target` (Node2D) | Sets the drag point to an object's current position once (a one-shot, does not keep following). |
| Set Follow Speed | `speed` (float) | Max catch-up speed in pixels per second; 0 means instant snap each tick. |
| Set Directions | `dirs` (int) | Movement lock: 0 free, 1 up/down, 2 left/right, 3 four-dir, 4 eight-dir. |
| Set Break Distance | `distance` (float), `action` (int) | Auto-ends the drag once the host lags past this gap; `action` 0 drops, 1 cancels. A `distance` of 0 disables it. |
| Set Throw Velocity | `velocity_x` (float), `velocity_y` (float) | Overrides the auto-measured throw velocity for the next drop. |
| Set Enabled | `is_enabled` (bool) | Enables or disables the behavior; disabling mid-drag cancels the drag silently. |
| Add Snap Position | `x` (float), `y` (float) | Registers a fixed point as a snap and magnet target. |
| Add Snap Object | `target` (Node2D) | Registers an object whose live position is a snap and magnet target. |
| Clear Snap Targets | (none) | Removes every registered snap position and snap object. |
| Set Snap Radius | `radius` (float) | Distance within which snapping and magnetism engage. |
| Set Snap Mode | `mode` (int) | 0 uses host-position proximity; 1 uses drag-point overlap. |
| Set Magnet Strength | `strength` (float) | How strongly the drag is pulled toward a nearby snap target, 0 to 1 (needs a snap radius above 0 to act). |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Dragging | (none) | Whether a drag is currently in progress. |
| Is Enabled | (none) | Whether the behavior is enabled. |
| Is Snapping | (none) | Whether the drag is currently within range of a snap target (would snap if dropped now). |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Drag Point X | (none) | float | Current drag point's X. |
| Drag Point Y | (none) | float | Current drag point's Y. |
| Drag Point Object UID | (none) | int | Instance id of the object being followed (from Start Drag At Object), or -1 if none. |
| Distance From Point | (none) | float | How far the host currently is from the drag point (the follow lag or stretch). |
| Throw Velocity X | (none) | float | Measured throw velocity's X from the last drop. |
| Throw Velocity Y | (none) | float | Measured throw velocity's Y from the last drop. |
| Throw Speed | (none) | float | Length of the last drop's throw velocity (its speed). |
| Drop Reason | (none) | String | Why the last drag ended: "manual" or "broke_distance". |
| Snap Target X | (none) | float | X of the nearest snap target being considered. |
| Snap Target Y | (none) | float | Y of the nearest snap target being considered. |
| Snapped Object UID | (none) | int | Instance id of the snap object the last drop landed on, or -1 if it did not snap to an object. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Drag Started | A drag begins (Start Drag or Start Drag At Object). |
| On Dropped | A drag ends with the throw or snap applied (Drop with `how` 0, or a break set to drop). |
| On Drag Cancelled | A drag ends silently (Drop with `how` 1, a break set to cancel, or the behavior disabled mid-drag). |
| On Snapped | A drop settled onto a snap target (also fires On Dropped; the throw is zero). |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `enabled` | bool | `true` | Active at start; disabling mid-drag cancels silently. |
| `follow_speed` | float | `0.0` | Max catch-up speed in pixels per second; 0 = instant snap each tick. |
| `break_distance` | float | `0.0` | Gap that auto-ends the drag; 0 disables. |
| `directions` | enum | `free` | Per-tick movement lock: free / up_down / left_right / four_dir / eight_dir. |

---

## Use cases

Each example targets the `DragDropBehavior` behavior on the named node. Begin the drag on a grab, feed the point each tick while dragging, and react in the triggers.

### 1. Basic mouse drag

Pick up a sprite, move it with the mouse, and set it down. This is the whole loop and every other example builds on it.

```
On "grab" pressed
  -> Piece | DragDropBehavior: Start Drag  get_global_mouse_position().x, get_global_mouse_position().y, 0

Every tick
  Condition: Piece | DragDropBehavior  Is Dragging
    -> Piece | DragDropBehavior: Set Drag Point  get_global_mouse_position().x, get_global_mouse_position().y

On "grab" released
  -> Piece | DragDropBehavior: Drop  0
```

### 2. Grab without a jump vs snap-to-cursor

`grab_mode` controls whether the object holds where you grabbed it or teleports under the pointer. Use 0 for a natural pickup, 1 for a cursor that yanks the object to its centre.

```
On "grab" pressed
  -> Piece | DragDropBehavior: Start Drag  get_global_mouse_position().x, get_global_mouse_position().y, 0
  (pass 1 instead of 0 to centre the piece on the cursor)
```

### 3. Throw a physics ball on release

The pack measures how fast you were flinging and hands you the velocity in On Dropped. Route it onto your physics body yourself, since the pack does not launch the object for you.

```
On Dropped
  -> Ball: set linear_velocity = Vector2( Ball | DragDropBehavior Throw Velocity X , Ball | DragDropBehavior Throw Velocity Y )
```

### 4. Snap items into inventory slots

Register each slot as a snap object and set a radius. On release the item settles onto the nearest slot inside that radius, and On Snapped fires instead of a loose drop.

```
On Ready
  -> Item | DragDropBehavior: Add Snap Object  Slot1
  -> Item | DragDropBehavior: Add Snap Object  Slot2
  -> Item | DragDropBehavior: Add Snap Object  Slot3
  -> Item | DragDropBehavior: Set Snap Radius  48

On Snapped
  -> UI: play "click" sound
```

### 5. Magnetic placement while dragging

Add a magnet on top of a snap radius so the item is pulled toward the nearest slot as you move, making precise drops forgiving. Strength 0 to 1.

```
On Ready
  -> Item | DragDropBehavior: Add Snap Object  Slot1
  -> Item | DragDropBehavior: Set Snap Radius  64
  -> Item | DragDropBehavior: Set Magnet Strength  0.6
```

Without a snap radius above 0 the magnet does nothing, so set both.

### 6. Puzzle pieces on a fixed grid

Register the grid cell centres as fixed snap positions and lock movement to four directions so pieces slide cleanly along the board.

```
On Ready
  -> Tile | DragDropBehavior: Add Snap Position  64, 64
  -> Tile | DragDropBehavior: Add Snap Position  128, 64
  -> Tile | DragDropBehavior: Add Snap Position  192, 64
  -> Tile | DragDropBehavior: Set Snap Radius  40
  -> Tile | DragDropBehavior: Set Directions  3
```

### 7. Horizontal slider handle

Lock the drag to left/right and read the drag point's X to drive a value. The handle can only move along its track.

```
On Ready
  -> Handle | DragDropBehavior: Set Directions  2

Every tick
  Condition: Handle | DragDropBehavior  Is Dragging
    -> Handle | DragDropBehavior: Set Drag Point  get_global_mouse_position().x, get_global_mouse_position().y
    -> Settings: set volume = clamp( ( Handle | DragDropBehavior Drag Point X - 100 ) / 300.0 , 0 , 1 )
```

### 8. Vertical knob

Same idea, locked to up/down for a knob or a stat scrubber.

```
On Ready
  -> Knob | DragDropBehavior: Set Directions  1
```

### 9. Eight-direction board piece

Lock to eight directions for a chess-like feel where a piece glides along ranks, files, and diagonals.

```
On Ready
  -> Bishop | DragDropBehavior: Set Directions  4
```

### 10. Heavy object with follow lag

Give the object a follow speed so it eases toward the pointer instead of sticking to it, and read Distance From Point to show how far it is stretched behind the cursor.

```
On Ready
  -> Crate | DragDropBehavior: Set Follow Speed  400

Every tick
  Condition: Crate | DragDropBehavior  Is Dragging
    -> Crate | DragDropBehavior: Set Drag Point  get_global_mouse_position().x, get_global_mouse_position().y
    -> Rope: set stretch = Crate | DragDropBehavior Distance From Point
```

### 11. Tear-off card with break distance

Set a break distance so pulling the pointer far enough tears the card off and drops it. `action` 0 drops (keeps the throw), 1 would cancel silently instead.

```
On Ready
  -> Card | DragDropBehavior: Set Break Distance  120, 0

On Dropped
  Condition: Card | DragDropBehavior  Drop Reason  ==  "broke_distance"
    -> Card: play "tear off" effect
```

### 12. Which slot did it land on

After a snapped drop, read Snapped Object UID to know exactly which registered snap object the item settled onto, then react per slot.

```
On Snapped
  Condition: Item | DragDropBehavior  Snapped Object UID  ==  WeaponSlot.get_instance_id()
    -> Inventory: equip the item
```

### 13. Drag that follows another node

Instead of a mouse, start a drag that tracks a second node each tick - a hand rig, a controller reticle, or an AI target. Read Drag Point Object UID to confirm what it is following.

```
On "grab" pressed
  -> Object | DragDropBehavior: Start Drag At Object  HandCursor, 0

On "grab" released
  -> Object | DragDropBehavior: Drop  0
```

The object keeps following `HandCursor` until you call Set Drag Point, which switches it back to a manual point.

### 14. Fixed-impulse slingshot

Compute your own launch velocity (for a slingshot pull, say) and override the measured throw so the release always fires with your value.

```
On "release sling" pressed
  -> Pebble | DragDropBehavior: Set Throw Velocity  ( SlingAnchor.global_position.x - Pebble.global_position.x ) * 5 , ( SlingAnchor.global_position.y - Pebble.global_position.y ) * 5
  -> Pebble | DragDropBehavior: Drop  0

On Dropped
  -> Pebble: set linear_velocity = Vector2( Pebble | DragDropBehavior Throw Velocity X , Pebble | DragDropBehavior Throw Velocity Y )
```

### 15. Turn dragging off during a cutscene

Disable the behavior so nothing can be grabbed, then re-enable it. Disabling mid-drag cancels the current drag silently (On Drag Cancelled fires).

```
On Cutscene Start
  -> Piece | DragDropBehavior: Set Enabled  false

On Cutscene End
  -> Piece | DragDropBehavior: Set Enabled  true
```

### 16. Cancel a drag with a right-click

Pass `how` 1 to Drop to abandon the drag with no throw and no snap - handy for a "put it back" cancel input.

```
On "cancel" pressed
  Condition: Piece | DragDropBehavior  Is Dragging
    -> Piece | DragDropBehavior: Drop  1

On Drag Cancelled
  -> Piece: tween back to its start position
```

---

## Tips and common mistakes

- **The pack does not read input - you must feed the drag point.** Nothing moves unless you call Set Drag Point each tick while Is Dragging. If a picked-up object sits still, you are missing the per-tick Set Drag Point, or you are calling it while Is Dragging is false. This is by design so the same rows work with a mouse, a touch, or a gamepad cursor.
- **Guard your per-tick Set Drag Point with Is Dragging.** Feeding the point when no drag is active does nothing useful and can hide bugs. Wrap the tick row in an Is Dragging condition.
- **Pass the right `how` to Drop.** `how` 0 applies the throw or snap (the normal release); `how` 1 cancels silently. Mixing these up is why a throw does not fire or a cancel unexpectedly launches the object.
- **The pack measures the throw but does not apply it.** On Dropped hands you Throw Velocity X / Y and Throw Speed, but you have to set them onto your physics body or velocity variable yourself. Expecting the object to fly on its own is the most common surprise.
- **A snapped drop has zero throw.** When a drop settles onto a snap target, On Snapped fires alongside On Dropped and the throw velocity is zero. Do not expect a snapped item to also fling.
- **Magnetism needs both a radius and a strength.** Set Magnet Strength alone does nothing; the magnet only pulls when Set Snap Radius is above 0 as well. Set the radius first, then the strength (0 to 1).
- **`grab_mode` 0 keeps the offset, 1 centres on the point.** If the object jumps its centre onto the cursor the instant you grab it, you passed 1 where you wanted 0. Use 0 for a natural pickup that holds where you clicked.
- **Break distance and follow speed interact.** A low follow speed makes the host lag behind the point, and a small break distance will then auto-end the drag as soon as it stretches too far. If drags keep ending on their own, raise the break distance or the follow speed, or set break distance to 0 to disable it.
- **Snap targets persist until you clear them.** Add Snap Position and Add Snap Object accumulate; call Clear Snap Targets when you rebuild a board or swap slots, otherwise old targets keep pulling the drag.
- **Read Drop Reason to tell a release from an auto-break.** Inside On Dropped, "manual" means the player let go and "broke_distance" means the break distance ended it. Branch on it when the two should behave differently.
