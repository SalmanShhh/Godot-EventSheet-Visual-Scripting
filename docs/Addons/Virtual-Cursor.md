# Virtual Cursor - An Input-Agnostic Pointer You Can Drive Any Way

Virtual Cursor is a Godot EventSheets behavior pack that turns a node into a controllable, code-free pointer. You attach a `VirtualCursor` behavior to a `CharacterBody2D` and that node becomes the cursor: it moves, accelerates and decelerates, bumps into solids, bounces off walls, snaps to targets with a homing magnet, stays inside a play area, reports what it is hovering, and fires named interact buttons. The word "cursor" here does not mean the operating-system mouse pointer - it means any thing you steer around the screen. That could be a mouse-follow reticle, a keyboard or gamepad menu selector, a twin-stick aim dot, a point-and-click hand, or a bouncing ball. Because the behavior is input-agnostic, you decide where its movement comes from: real controls read each tick, an analog axis you feed in, a mouse position you push, or a scripted teleport. Every Action, Condition, Expression, and Trigger targets the `VirtualCursor` living on the node you drop it on - there is no cursor id to pass around. This pack also drives the Drag N Drop pack.

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

- **Menu and inventory navigation.** A keyboard or gamepad drives the cursor around a UI, constrained to the screen, and Press Interact selects whatever it is hovering - no mouse required.
- **Mouse-follow reticles.** Feed the real mouse position with Simulate Mouse and the cursor eases toward it with smoothing, so a custom crosshair trails the pointer instead of snapping.
- **Twin-stick aiming.** Push the right analog stick into Simulate Axis and the reticle accelerates smoothly with the movement feel you tuned, instead of teleporting.
- **Aim assist and magnetism.** Register nearby enemies as homing targets and let steer mode gently pull the reticle toward the closest one, or snap mode lock onto it when the player lets go of the stick.
- **Point-and-click adventures.** Is Hovering tells you exactly which object the hand is over, and On Interact Pressed fires the "examine" or "use" verb on it.
- **Accessibility and auto-play.** Simulate Interact fires a full press and release in one tick, and Simulate Control feeds a cardinal direction, so on-screen buttons or an assist mode can drive the cursor without a physical device.
- **Bouncing ball and pinball toys.** Turn Set Bounce to both and the cursor reflects losslessly off solids and the play-area edges, firing On Bounce each time.
- **Bounded play fields.** Constrain the cursor to the viewport or an explicit rectangle, and On Layout Edge Hit lets you react the moment it reaches a wall.
- **Grid and slider selectors.** Set Direction Mode to up/down or left/right to lock the cursor to a single axis for a column of options or a volume slider.
- **Drag and drop.** Hover an item, hold an interact button to grab, move, and release to drop - this pack is the movement and hover layer the Drag N Drop pack builds on.
- **Obstacle-aware pointers.** Register solids so the cursor is pushed out by move_and_slide and can slide along walls or hard-stop, with On Solid Hit for feedback.
- **Cutscenes and locked input.** Set Ignoring Input or Set Enabled to freeze the cursor during a scripted beat, then turn it back on when control returns to the player.

---

## Core concepts

The mental model is small. The cursor is a moving node, you choose where its motion comes from, and a handful of optional systems (homing, solids, bounce, constraints, hover, interact) layer on top.

**The cursor is a node.** You attach a `VirtualCursor` behavior to a `CharacterBody2D`, and that body is the cursor. It moves with `move_and_slide` under the hood, so it already understands physics collisions. Everything the pack does happens to the node it is placed on - there is no separate pointer object and no id to thread through calls.

**Movement is input-agnostic, and you pick the source.** Each physics tick the behavior resolves one movement input, in this order of precedence:

- **Ignoring input** - if Set Ignoring Input is on, the axis is zero and the cursor coasts to a stop.
- **A simulated axis** - if you called Simulate Axis or Simulate Control this tick, that analog direction is used (and then consumed).
- **Default controls** - otherwise, if Set Default Controls is on, the behavior reads `ui_left` / `ui_right` / `ui_up` / `ui_down` each tick (keyboard and gamepad both work out of the box).
- **Nothing** - if none of the above apply, there is no axis and the cursor decelerates.

Separately, Simulate Mouse and Simulate Direct Mouse Position drive the cursor toward a point. Simulate Mouse takes over velocity with smoothing until the cursor arrives; Simulate Direct Mouse Position teleports it instantly and reports the implied speed. A live mouse target takes precedence over the axis for that tick.

**Movement feel is three numbers plus a direction mode.** Max Speed caps how fast the cursor goes, Acceleration is how quickly it speeds up while an axis is held, and Deceleration is how quickly it slows when the axis is released. The direction mode restricts the axis: up/down locks to vertical, left/right locks to horizontal, four-way snaps to the dominant axis, and eight-way is free movement.

**Homing is an optional magnet.** Turn it on with Set Homing Enabled, register candidate nodes with Add Homing Target, and set a Radius and Strength. When the nearest target is within the radius the cursor is drawn toward it. The mode decides how: steer mode nudges velocity toward the target so the pull is soft; snap mode pulls hard and, when the player is not actively steering, locks the cursor onto the target and fires On Homing Snapped once. On Homing Target Entered and On Homing Target Exited fire as a target moves in and out of range.

**Solids are physical obstacles.** The cursor already collides via `move_and_slide`. Set Solid Collision toggles that push-out, and Set Allow Sliding chooses whether the cursor slides along a wall (true) or hard-stops (false). On Solid Hit fires when it touches something. Add Solid and Remove Solid register nodes so the Hovered UID and solid reporting can name them; Clear Solids empties that list.

**Bounce reflects the cursor losslessly.** Set Bounce chooses which surfaces reflect it: none, solids only, constraint edges only, or both. When it reflects, On Bounce fires. This is what makes a ball toy or a pinball feel right - the speed is preserved and the angle mirrors.

**Constraints keep the cursor in bounds.** Turn on Set Constrain To Layout to clamp the cursor inside the viewport by default, or inside an explicit rectangle you set with Set Constraint Bounds. When the cursor reaches an edge, On Layout Edge Hit fires once (not every frame it rests there).

**Hover detection asks "am I over this?"** Is Hovering takes a target node and returns whether the cursor is over it. The hover mode chooses the test: point mode checks whether the cursor's origin is inside the target's shape; overlap mode checks whether the shapes overlap. Whenever a hover matches, the Hovered UID expression reports that target's instance id.

**Interact buttons are named, not a single click.** Press Interact and Release Interact take an id string like `"select"` or `"grab"`, so one cursor can carry several independent buttons. Is Interact Held asks whether a named button (or, with an empty id, any button) is down, and On Interact Pressed and On Interact Released carry the id so you know which fired. Simulate Interact fires a press and release together in one tick.

---

## Setup

**1. Attach the behavior.** Make your cursor node a `CharacterBody2D` (give it a shape if you want it to collide with solids). Add a `VirtualCursor` behavior as a child node of it - open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in. The behavior acts on its parent, which must be a `CharacterBody2D`.

**2. Set the Inspector knobs.** Select the behavior node and tune the feel:

| Property | Default | What it does |
|---|---|---|
| `max_speed` | `600.0` | Max cursor speed in pixels per second. |
| `acceleration` | `1800.0` | Speed-up rate while an axis is held (px/s^2). |
| `deceleration` | `2400.0` | Slow-down rate when the axis is released (px/s^2). |
| `allow_sliding` | `true` | Slide along solids (true) instead of hard-stopping (false). |
| `default_controls` | `true` | Read `ui_left` / `ui_right` / `ui_up` / `ui_down` each tick (keyboard and gamepad). |
| `ai_controlled` | `false` | AI drive: read the held `ai_move_x`/`ai_move_y` intents instead of the ui_* actions - a sheet or AI steers the cursor (see docs/GUIDE-PLAYER-AND-AI-INPUT.md). Pair with `Simulate Mouse` + the `On Cursor Arrived` trigger for point-to-point glides. |
| `enabled` | `true` | Master on/off for the whole behavior. |
| `constrain_to_layout` | `false` | Clamp the cursor inside the viewport or constraint bounds. |
| `direction_mode` | `eight` | Movement axis constraint: `up_down`, `left_right`, `four`, or `eight`. |
| `hover_mode` | `point` | Hover test: `point` (origin inside shape) or `overlap` (shapes overlap). |
| `bounce_mode` | `none` | Which surfaces reflect the cursor: `none`, `solids`, `constraints`, or `both`. |

**3. Wire your first cursor.** With `default_controls` and `enabled` both on by default, the cursor already moves with the keyboard and gamepad the moment it is in the scene. Here is a complete first cursor - a menu selector that stays on screen and picks the button it is hovering:

```
On Ready
  -> Cursor | Virtual Cursor: Set Constrain To Layout  true

On "ui_accept" pressed
  -> Cursor | Virtual Cursor: Press Interact  "select"

On "ui_accept" released
  -> Cursor | Virtual Cursor: Release Interact  "select"

On Interact Pressed
  Condition: Cursor | Virtual Cursor  Is Hovering  StartButton
    -> (start the game)
  Condition: Cursor | Virtual Cursor  Is Hovering  QuitButton
    -> (quit)
```

The cursor drives itself from the arrow keys or stick; Set Constrain To Layout keeps it on screen; the named `"select"` button carries the accept press, and Is Hovering routes it to whatever the cursor is over.

---

## ACE reference

All ACEs live in the **Virtual Cursor** category and target the `VirtualCursor` behavior on the node they are placed on (a `CharacterBody2D`). There is no cursor-id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Press Interact | `id` (String) | Marks a named interact button held and fires On Interact Pressed. |
| Release Interact | `id` (String) | Marks a named interact button released and fires On Interact Released. |
| Simulate Interact | `id` (String) | Fires a press and release of a named button in one tick. |
| Set Max Speed | `speed` (float) | Sets the max cursor speed (px/s). |
| Set Acceleration | `rate` (float) | Sets the speed-up rate while an axis is held. |
| Set Deceleration | `rate` (float) | Sets the slow-down rate when the axis is released. |
| Set Velocity | `vel_x` (float), `vel_y` (float) | Sets the cursor velocity directly. |
| Simulate Direct Mouse Position | `target_x` (float), `target_y` (float) | Teleports the cursor to a position, reporting the implied velocity. |
| Simulate Mouse | `target_x` (float), `target_y` (float), `smoothing` (float) | Drives the cursor toward a target with smoothing (mouse-follow). |
| Simulate Axis | `x` (float), `y` (float) | Feeds an analog axis for this tick (accel/decel applies). |
| Simulate Control | `direction` (int) | Feeds a cardinal direction for this tick (0 up, 1 down, 2 left, 3 right). |
| Set Homing Enabled | `is_enabled` (bool) | Turns the homing magnet on or off. |
| Set Homing Mode | `mode` (int) | 0 steer, 1 snap-radius, 2 snap-overlap. |
| Set Homing Radius | `radius` (float) | Sets the homing engagement radius. |
| Set Homing Strength | `strength` (float) | How strongly the cursor is pulled toward a homing target (0..1). |
| Add Homing Target | `target` (Node2D) | Registers a node as a homing target. |
| Remove Homing Target | `target` (Node2D) | Unregisters a homing target. |
| Clear Homing Targets | (none) | Removes every homing target. |
| Add Solid | `target` (Node2D) | Registers a node as a tracked solid (for SolidUID reporting). |
| Remove Solid | `target` (Node2D) | Unregisters a tracked solid. |
| Clear Solids | (none) | Clears the tracked-solids list. |
| Set Solid Collision | `is_enabled` (bool) | Toggles solid push-out via move_and_slide. |
| Set Allow Sliding | `state` (bool) | Slide along solids (true) or hard-stop (false). |
| Set Bounce | `mode` (int) | 0 none, 1 solids, 2 constraints, 3 both. |
| Set Direction Mode | `mode` (int) | 0 up/down, 1 left/right, 2 four-way, 3 eight-way. |
| Set Default Controls | `state` (bool) | Read `ui_left` / `ui_right` / `ui_up` / `ui_down` each tick. |
| Set Enabled | `is_enabled` (bool) | Master on/off. |
| Set Ignoring Input | `state` (bool) | Ignore all input while true (movement decays to zero). |
| Set Constrain To Layout | `is_enabled` (bool) | Clamp the cursor inside the bounds. |
| Set Constraint Bounds | `left` (float), `top` (float), `right` (float), `bottom` (float) | Sets explicit clamp bounds (all-zero clears them, falling back to the viewport). |
| Set Hover Mode | `mode` (int) | 0 point (origin inside shape), 1 overlap (shapes overlap). |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Interact Held | `id` (String) | Whether a named interact button is down (empty id = any button held). |
| Is Moving | (none) | Whether the cursor currently has a non-zero reported velocity. |
| Is In Homing Range | (none) | Whether a homing target is within the engagement radius. |
| Is Blocked | (none) | Whether the cursor hit a solid this tick. |
| Is Enabled | (none) | Whether the behavior is enabled (master on/off). |
| Is Ignoring Input | (none) | Whether the cursor is currently ignoring input. |
| Is Hovering | `target` (Node2D) | Whether the cursor is over the target (using the current hover mode). |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Cursor X | (none) | float | The cursor's global X position. |
| Cursor Y | (none) | float | The cursor's global Y position. |
| Speed | (none) | float | The cursor's current reported speed (px/s). |
| Velocity X | (none) | float | The cursor's reported X velocity. |
| Velocity Y | (none) | float | The cursor's reported Y velocity. |
| Moving Angle | (none) | float | The cursor's movement angle in degrees (0..360). |
| Axis X | (none) | float | The resolved input axis X for this tick (-1..1). |
| Axis Y | (none) | float | The resolved input axis Y for this tick (-1..1). |
| Max Speed | (none) | float | The current max speed setting. |
| Hovered UID | (none) | int | The instance id of the last target Is Hovering matched (-1 if none). |
| Homing Target UID | (none) | int | The instance id of the nearest in-range homing target (-1 if none). |
| Homing Target Dist | (none) | float | Distance to the nearest in-range homing target (-1 if none). |
| Count Homing Targets | (none) | int | How many homing targets are registered. |
| Bounce Mode | (none) | String | The current bounce mode as a token (`none`, `solids`, `constraints`, `both`). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Interact Pressed | Press Interact (or Simulate Interact) marks a named button held; carries the id. |
| On Interact Released | Release Interact (or Simulate Interact) marks a named button released; carries the id. |
| On Layout Edge Hit | The cursor reaches a constraint or viewport edge (fires once per edge touch, not every frame). |
| On Homing Target Entered | The nearest homing target crosses into the engagement radius. |
| On Homing Target Exited | No homing target is in range anymore (or homing was turned off with targets present). |
| On Homing Snapped | The cursor snaps and rests onto a homing target in a snap mode (fires once per fresh snap). |
| On Solid Hit | The cursor touches a solid during move_and_slide. |
| On Bounce | The cursor reflects off a solid or a constraint edge (per the bounce mode). |

### Inspector properties

| Property | Type | Default | Range / values |
|---|---|---|---|
| `max_speed` | float | `600.0` | any (px/s) |
| `acceleration` | float | `1800.0` | any (px/s^2) |
| `deceleration` | float | `2400.0` | any (px/s^2) |
| `allow_sliding` | bool | `true` | slide / hard-stop |
| `default_controls` | bool | `true` | on / off |
| `enabled` | bool | `true` | on / off |
| `constrain_to_layout` | bool | `false` | on / off |
| `direction_mode` | enum int | `eight` (3) | `up_down`, `left_right`, `four`, `eight` |
| `hover_mode` | enum int | `point` (0) | `point`, `overlap` |
| `bounce_mode` | enum int | `none` (0) | `none`, `solids`, `constraints`, `both` |

---

## Use cases

Each example targets the `VirtualCursor` behavior on the named node (a `CharacterBody2D`). Set the feel and toggles in `On Ready` or the Inspector, feed movement from whatever input you like, and react in the trigger events.

### 1. Keyboard and gamepad menu selector

The cursor drives itself from `ui_*` and stays on screen, and the accept button selects whatever it is over.

```
On Ready
  -> Cursor | Virtual Cursor: Set Default Controls  true
  -> Cursor | Virtual Cursor: Set Constrain To Layout  true

On "ui_accept" pressed
  -> Cursor | Virtual Cursor: Press Interact  "select"

On Interact Pressed
  Condition: Cursor | Virtual Cursor  Is Hovering  PlayButton
    -> (load the level)
```

Default controls are on by default, so the cursor moves the instant the scene loads; Set Constrain To Layout keeps it inside the viewport.

### 2. Custom mouse-follow reticle

A drawn crosshair trails the real mouse with a little lag. Push the mouse position every frame and let smoothing ease the cursor toward it.

```
Every tick
  -> Cursor | Virtual Cursor: Simulate Mouse  get_global_mouse_position().x, get_global_mouse_position().y, 0.2

On tick
  -> Crosshair: set position to (Cursor.Cursor X, Cursor.Cursor Y)
```

Smoothing `0.2` gives a soft trail; raise it toward `1.0` to make the reticle stick tightly to the mouse.

### 3. Twin-stick aim dot

Feed the right analog stick into Simulate Axis so the aim reticle accelerates with the movement feel you tuned instead of teleporting.

```
Every tick
  -> Reticle | Virtual Cursor: Simulate Axis  Input.get_axis("aim_left", "aim_right"), Input.get_axis("aim_up", "aim_down")

On tick
  -> (fire weapon toward angle Reticle.Moving Angle)
```

Because Simulate Axis feeds an analog vector, half-tilting the stick moves the reticle at half input; Set Max Speed caps its top speed.

### 4. Snap-to aim assist on release

Register enemies as homing targets and use snap mode so the reticle locks onto the nearest one when the player lets go of the stick.

```
On Ready
  -> Reticle | Virtual Cursor: Set Homing Enabled  true
  -> Reticle | Virtual Cursor: Set Homing Mode  1
  -> Reticle | Virtual Cursor: Set Homing Radius  200
  -> Reticle | Virtual Cursor: Set Homing Strength  0.8

On Enemy Spawned
  -> Reticle | Virtual Cursor: Add Homing Target  Enemy

On Homing Snapped
  -> (play a lock-on chirp and show the reticle ring)
```

While the player steers, snap mode only nudges; the moment the stick is released and a target is in range, the cursor snaps and On Homing Snapped fires once.

### 5. Soft magnetic aim assist

Use steer mode instead for a gentle pull that never fully takes over. The reticle drifts toward the closest target but the player stays in control.

```
On Ready
  -> Reticle | Virtual Cursor: Set Homing Enabled  true
  -> Reticle | Virtual Cursor: Set Homing Mode  0
  -> Reticle | Virtual Cursor: Set Homing Radius  150
  -> Reticle | Virtual Cursor: Set Homing Strength  0.3

On Enemy Died
  -> Reticle | Virtual Cursor: Remove Homing Target  Enemy
```

Strength `0.3` is a light nudge; Remove Homing Target keeps a dead enemy from tugging the aim. Read Homing Target Dist if you want the assist to strengthen up close.

### 6. Point-and-click adventure hand

The hovered object drives which verb the click runs, and Hovered UID lets you highlight it.

```
Every 0.1 seconds
  Condition: Cursor | Virtual Cursor  Is Hovering  DoorObject
    -> (show "Open" prompt)

On Interact Pressed
  Condition: Cursor | Virtual Cursor  Is Hovering  DoorObject
    -> (open the door)
```

Set Hover Mode to overlap first if your objects are large areas rather than points; use point mode for pixel-precise pointing.

### 7. Bouncing ball toy

Turn the cursor into a ball that ricochets off walls and the play-area edges without losing speed.

```
On Ready
  -> Ball | Virtual Cursor: Set Default Controls  false
  -> Ball | Virtual Cursor: Set Constrain To Layout  true
  -> Ball | Virtual Cursor: Set Bounce  3
  -> Ball | Virtual Cursor: Set Velocity  300, 200

On Bounce
  -> (play a bounce sound and a spark)
```

Set Bounce `3` reflects off both solids and constraint edges; Set Velocity kicks the ball off, and with no default controls it just keeps bouncing.

### 8. Bounded play area with edge feedback

Fence the cursor into an explicit rectangle and flash the border when it hits an edge.

```
On Ready
  -> Cursor | Virtual Cursor: Set Constrain To Layout  true
  -> Cursor | Virtual Cursor: Set Constraint Bounds  100, 100, 900, 600

On Layout Edge Hit
  -> (flash the border red)
```

Set Constraint Bounds fixes the clamp rectangle; passing all zeros later clears it so the cursor falls back to the viewport.

### 9. One-axis slider control

Lock the cursor to a single axis so it slides along a volume bar or a column of options.

```
On Ready
  -> Handle | Virtual Cursor: Set Direction Mode  1
  -> Handle | Virtual Cursor: Set Constrain To Layout  true
  -> Handle | Virtual Cursor: Set Constraint Bounds  200, 400, 800, 440

On tick
  -> (set volume from Handle.Cursor X mapped across the bar)
```

Direction Mode `1` locks to left/right; the thin constraint band keeps the handle on the track.

### 10. Grab and drop with an interact button

Hold a named button while hovering an item to pick it up, and release to drop it. This is the pattern the Drag N Drop pack builds on.

```
On Interact Pressed
  Condition: Cursor | Virtual Cursor  Is Hovering  Crate
    -> (attach Crate to the cursor)

On Interact Released
  -> (drop the held item at Cursor.Cursor X, Cursor.Cursor Y)

Every tick
  Condition: Cursor | Virtual Cursor  Is Interact Held  "grab"
    -> (keep the held item glued to the cursor position)
```

Press the `"grab"` button on click, keep the item glued while Is Interact Held is true, and drop it on release.

### 11. Accessibility auto-click

An assist mode fires a full click on whatever the cursor rests over, without a physical button, using Simulate Interact.

```
Every 1.5 seconds
  Condition: Cursor | Virtual Cursor  Is Moving  (inverted: not moving)
    -> Cursor | Virtual Cursor: Simulate Interact  "select"

On Interact Pressed
  Condition: Cursor | Virtual Cursor  Is Hovering  FocusedButton
    -> (activate the button)
```

Simulate Interact fires press and release in one tick, so a dwell timer over a target triggers it hands-free.

### 12. On-screen D-pad for touch

Touch buttons feed cardinal directions into the cursor with Simulate Control, so mobile players steer without a stick.

```
On "up_button" pressed
  -> Cursor | Virtual Cursor: Simulate Control  0

On "down_button" pressed
  -> Cursor | Virtual Cursor: Simulate Control  1

On "left_button" pressed
  -> Cursor | Virtual Cursor: Simulate Control  2

On "right_button" pressed
  -> Cursor | Virtual Cursor: Simulate Control  3
```

Simulate Control feeds one tick of that direction, so hold-to-repeat the touch button each frame for continuous movement.

### 13. Obstacles that block and slide

Register walls as solids so the cursor is pushed out and can slide along them, with a bump reaction.

```
On Ready
  -> Cursor | Virtual Cursor: Set Solid Collision  true
  -> Cursor | Virtual Cursor: Set Allow Sliding  true
  -> Cursor | Virtual Cursor: Add Solid  WallA

On Solid Hit
  -> (play a soft thud)
  Condition: Cursor | Virtual Cursor  Is Blocked
    -> (show a small dust puff)
```

Set Allow Sliding true lets the cursor glide along the wall; set it false for a hard stop. Is Blocked confirms it collided this tick.

### 14. Snap the cursor to a spot instantly

Jump the cursor to a screen position on demand - for a "return to start" hotkey or teleporting focus to a new menu.

```
On "reset" pressed
  -> Cursor | Virtual Cursor: Simulate Direct Mouse Position  640, 360

On Menu Opened
  -> Cursor | Virtual Cursor: Simulate Direct Mouse Position  DefaultButton.global_position.x, DefaultButton.global_position.y
```

Simulate Direct Mouse Position teleports rather than eases, and it reports the implied velocity so Speed still reads a value that frame.

### 15. Freeze the cursor during a cutscene

Lock out input while a scripted beat plays, then hand control back cleanly.

```
On Cutscene Start
  -> Cursor | Virtual Cursor: Set Ignoring Input  true

On Cutscene End
  -> Cursor | Virtual Cursor: Set Ignoring Input  false
  Condition: Cursor | Virtual Cursor  Is Ignoring Input  (inverted: not ignoring)
    -> (show the "your turn" prompt)
```

Set Ignoring Input decays the cursor to a stop rather than snapping it dead. Use Set Enabled instead if you want to freeze the whole behavior, including homing and constraints.

---

## Tips and common mistakes

- **The host must be a CharacterBody2D.** The behavior acts on its parent and expects a `CharacterBody2D`; on any other node type it warns and does nothing. Solid push-out and bounce lean on `move_and_slide`, so give the body a collision shape if you want it to hit walls.
- **The node is the cursor - there is no cursor id.** Every Action, Condition, and Expression acts on the `VirtualCursor` of the node it is placed on. If you carried over patterns that threaded a pointer id through calls, drop it. One behavior, one cursor.
- **Only one movement source wins per tick, in a fixed order.** Ignoring input beats a simulated axis, which beats default controls; a live mouse target set by Simulate Mouse takes precedence over the axis. If your Simulate Axis feels ignored, check that Set Ignoring Input is not on and that you are not also driving a mouse target.
- **Feed Simulate Axis, Simulate Mouse, and Simulate Control every tick you want them to apply.** They describe input for a single physics tick and are consumed. Push them from a per-tick event, not once in On Ready, or the cursor will drift back to default controls.
- **Set Default Controls false when you drive the cursor yourself.** If you feed a mouse or analog axis but leave default controls on, the arrow keys fight your input. Turn them off for a purely mouse-driven or scripted cursor.
- **Homing needs three things on: enabled, a radius, and at least one target.** Set Homing Enabled alone does nothing without Add Homing Target, and a target outside the radius never engages. Remove or Clear targets when they die, or the magnet keeps pulling toward a stale node.
- **On Homing Snapped fires once per fresh snap, not every frame.** The cursor latches onto a target and stays put without re-firing, so treat the trigger as a one-shot lock-on cue. It re-arms when the cursor leaves and snaps again.
- **Bounce and constraints are separate switches.** Set Bounce chooses which surfaces reflect, but constraint-edge bounce only happens when Set Constrain To Layout is also on. For a ball that ricochets off the screen edges, turn on both.
- **Set Constraint Bounds with all zeros clears the bounds.** Passing `0, 0, 0, 0` is the documented way to drop an explicit rectangle and fall back to the viewport - it is not a zero-size box. Pass real corners (left, top, right, bottom) to fence a specific area.
- **Pick the hover mode that matches your targets.** Point mode tests the cursor's origin against the target shape (great for a precise pointer); overlap mode tests shape overlap and, for a true area test, wants an Area2D-style target. If Is Hovering never fires on a big object, try Set Hover Mode to overlap, and confirm the target is visible - a hidden node never counts as hovered.
