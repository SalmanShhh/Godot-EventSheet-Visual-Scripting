# Platformer - Tight Jump-and-Run Movement for One CharacterBody2D

Platformer is a Godot EventSheets behavior pack that gives a character full jump-and-run movement in one drop. You attach a `PlatformerMovement` behavior to a `CharacterBody2D`, and that body starts running, falling, and jumping with the feel that good platformers are made of: acceleration and friction, gravity with a terminal velocity, coyote time, jump buffering, variable jump height, multi-jump, wall slide, and wall jump. There is no per-frame movement code to write. Every physics frame the behavior reads your left/right input, moves the body, and applies gravity for you. You only fire **Jump** on the button press, tune the feel in the Inspector, and react to the triggers it emits (**On Jumped**, **On Landed**, **On Double Jumped**, **On Wall Jumped**). Every Action, Condition, Expression, and Trigger targets the `PlatformerMovement` behavior on the node you drop it on - there is no character id to pass around.

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

- **A player character in a side-scroller.** Attach it, bind a jump button, and you have run, jump, gravity, and floor detection working the first minute - no movement math.
- **Tight, forgiving jumps.** Coyote time lets a jump land even a hair after you walk off a ledge, and jump buffering fires a press made just before you touch down, so inputs never feel dropped.
- **Variable jump height.** Tap for a hop, hold for a full leap - the rise is cut short the moment the player releases the button.
- **Double and triple jump.** Set the max jumps knob and mid-air jumps just work, each firing its own trigger for a puff or spin effect.
- **Wall climbing and wall jumps.** Flip two Inspector switches to cling and slow-slide down a wall, then kick away from it with a wall jump.
- **Metroidvania traversal upgrades.** Grant a double jump or wall jump later in the game by turning on a knob, and refill air jumps at a bounce pad.
- **Speed states.** Swap the run speed live for a sprint, a slow mud patch, a haste power-up, or a conveyor.
- **Animation driving.** Read whether the body is moving, jumping, falling, or wall sliding to pick the right sprite state, and read facing direction to flip it.
- **Impact feedback.** Landing fires a trigger you hook for dust, squash, and a thud, scaled by how long the character was airborne.
- **Fall-damage and long-drop mechanics.** Read air time on landing to hurt the player after a big fall.
- **Auto-runners and endless platformers.** The horizontal run is automatic, so you only ever call Jump - perfect for one-button runners.
- **Prototyping game feel.** Every feel value is an Inspector slider, so you tune jump height, gravity, and friction without touching code.

---

## Core concepts

The mental model is small. Learn these ideas and the rest is Inspector tuning.

**The node is the character - there is no character id.** Every Action, Condition, and Expression acts on the `PlatformerMovement` behavior of the node it sits on. You attach one behavior per character, and its host is the parent `CharacterBody2D`. If you attach it to something that is not a `CharacterBody2D`, it warns and stays inert.

**The behavior drives itself every physics frame.** Once attached, it runs its own loop: it reads the left/right input axis (`ui_left` and `ui_right`), accelerates the body toward your top run speed, applies gravity clamped to a terminal fall speed, handles wall slide and buffered jumps, and calls `move_and_slide` at the end. You do not write per-frame movement, and you do not set the body's velocity yourself. Steering left and right is automatic; the only movement you trigger by hand is the jump.

**You fire Jump on the press.** Jumping is an intentful moment, so you call the **Jump** action from your own jump-button event. Jump is smart: it jumps from the floor, from within the coyote-time grace window, off a wall (if wall jump is enabled), or as a mid-air jump if any remain. If none of those is available at that instant, it **buffers** the press and fires it automatically the moment a jump becomes possible. That means you always call Jump on the raw button press and let the behavior decide.

**Jump Released gives you hold-for-height.** With variable jump height on (the default), calling **Jump Released** when the player lets go of the button cuts the remaining rise short. Tap equals a small hop, hold equals a full jump. Call it on the button-release event; if you never call it, jumps always reach full height.

**Coyote time and jump buffering are built in.** Coyote time is a short grace window (a tenth of a second by default) where a jump still counts just after you leave a ledge. Jump buffering remembers a press made slightly too early and fires it on landing. Both are already wired inside the behavior - you get them for free just by calling Jump on the press.

**Multi-jump is a number.** Set max jumps to 2 for a double jump, 3 for a triple, and so on. Floor jumps and air jumps are counted for you; the count refills when the body touches the ground, or on demand with **Reset Jumps**. A mid-air jump fires **On Double Jumped** (the air-jump trigger), while a ground jump fires **On Jumped**.

**Wall slide and wall jump are opt-in.** Both start off. Turn on wall slide to cling and fall slowly while pressing into a wall in the air, and turn on wall jump to kick up and away from a wall when you press Jump against it. A wall jump fires **On Wall Jumped**.

**Triggers narrate what happened.** **On Jumped**, **On Landed**, **On Double Jumped**, and **On Wall Jumped** fire at the exact moment each event occurs, so you attach animation, sound, particles, and screen shake to them instead of polling.

**Conditions and expressions read live state.** Ask whether the body **Is Moving**, **Is Jumping**, **Is Falling**, **Is Wall Sliding**, or **Can Jump** to drive an animation state machine or gate logic. Read **Jumps Remaining**, **Air Time**, and **Facing Direction** to build counters, fall damage, and sprite flipping.

---

## Setup

**1. Attach the behavior.** Add a `PlatformerMovement` behavior as a child of your player's `CharacterBody2D` (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The `CharacterBody2D` is the host it moves. Give the body a `CollisionShape2D` and put it in a scene with a floor so `is_on_floor()` works.

**2. Make sure your input map has left and right.** The behavior reads the `ui_left` and `ui_right` input actions for horizontal movement - these ship in every Godot project by default (arrow keys), and you can add WASD or a gamepad stick to them in Project Settings > Input Map. The jump button is yours to bind: add an input action (call it `jump`, bind Space or a gamepad face button) and call the Jump action from it.

**3. Set the Inspector knobs.** Select the behavior node and tune the feel:

| Property | Default | What it does |
|---|---|---|
| `move_speed` | `200.0` | Top horizontal run speed in px/s. |
| `jump_velocity` | `-400.0` | Upward launch of a jump (negative is up). |
| `gravity` | `980.0` | Downward acceleration in px/s squared. |
| `acceleration` | `1500.0` | How fast you reach top speed when a direction is held. |
| `deceleration` | `1800.0` | How fast you stop when no direction is held. |
| `max_fall_speed` | `1000.0` | Terminal velocity - gravity never pulls faster than this. |
| `coyote_time` | `0.1` | Grace window in seconds to still jump just after leaving a ledge. |
| `jump_buffer_time` | `0.1` | Press jump this many seconds early and it still fires on landing. |
| `max_jumps` | `1` | Total jumps before touching ground again (2 is a double jump). |
| `variable_jump_height` | `true` | Releasing jump early cuts the rise (hold to go higher). |
| `jump_cut_factor` | `0.45` | Fraction of upward speed kept when jump is released early (0 to 1). |
| `enable_wall_slide` | `false` | Cling and slow your fall while pressing into a wall. |
| `wall_slide_speed` | `80.0` | Max fall speed while wall sliding, in px/s. |
| `enable_wall_jump` | `false` | Jump off walls (kicks away from the wall). |
| `wall_jump_push` | `260.0` | Horizontal kick away from the wall on a wall jump. |
| `wall_jump_velocity` | `-380.0` | Upward launch of a wall jump (negative is up). |

**4. Wire the jump.** Horizontal running is already handled by the behavior, so a complete first setup is just two input events plus reactions:

```
On "jump" pressed
  -> Player | PlatformerMovement: Jump

On "jump" released
  -> Player | PlatformerMovement: Jump Released

On Landed
  -> Player: play "land" sound

On Jumped
  -> Player: play "jump" sound
```

That is a full platformer character. Move with the arrow keys (the behavior reads them itself), tap the jump button for a hop, hold it for a full jump, and hear a landing thud. Everything else below is polish on top of this.

---

## ACE reference

All ACEs live in the **Platformer** category and target the `PlatformerMovement` behavior on the node they are placed on. The host is that node's parent `CharacterBody2D`.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Jump | (none) | Jumps from the floor or within coyote time, off a wall (if wall jump is enabled), or as a mid-air (double) jump if any remain. If none is available right now, the press is buffered and fires the instant a jump becomes possible. Call it on the raw jump-button press. |
| Jump Released | (none) | Call when the jump button is released - cuts the rise short for variable jump height (hold to go higher). Only has an effect while variable jump height is on and the body is still rising. |
| Set Move Speed | `speed` (float) | Changes the horizontal run speed live (for a sprint, a slow patch, a haste power-up). The Inspector `move_speed` is the starting value; set it back when the effect ends. |
| Reset Jumps | (none) | Refills the air-jump count, for example after grabbing a power-up or hitting a bounce pad. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Moving | (none) | True while the body has meaningful horizontal speed (it is actually running, not standing still). |
| Is Jumping | (none) | True while the body is off the floor and moving upward (rising). |
| Is Falling | (none) | True while the body is off the floor and moving downward (falling). |
| Is Wall Sliding | (none) | True while the body is clinging to and sliding down a wall (wall slide must be enabled). |
| Can Jump | (none) | True when a Jump call would actually fire right now: on the floor, within coyote time, with an air jump left, or (wall jump enabled) touching a wall. |

### Expressions

| Expression | Returns | Description |
|---|---|---|
| Jumps Remaining | int | How many air (mid-air) jumps are left before the body must touch the ground again. |
| Air Time | float | Seconds the body has been off the floor (resets to 0 on landing). Read it on landing for fall damage or hard-land effects. |
| Facing Direction | int | The last horizontal facing: `1` for right, `-1` for left. Does not change while standing still. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Jumped | A ground jump launches (from the floor or within coyote time). |
| On Landed | The body touches the floor after being airborne. |
| On Double Jumped | A mid-air (double) jump launches. |
| On Wall Jumped | A wall jump launches (wall jump must be enabled). |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `move_speed` | float | `200.0` | any |
| `jump_velocity` | float | `-400.0` | any (negative is up) |
| `gravity` | float | `980.0` | any |
| `acceleration` | float | `1500.0` | any |
| `deceleration` | float | `1800.0` | any |
| `max_fall_speed` | float | `1000.0` | any |
| `coyote_time` | float | `0.1` | seconds |
| `jump_buffer_time` | float | `0.1` | seconds |
| `max_jumps` | int | `1` | 1 or more |
| `variable_jump_height` | bool | `true` | on / off |
| `jump_cut_factor` | float | `0.45` | 0.0 - 1.0 |
| `enable_wall_slide` | bool | `false` | on / off |
| `wall_slide_speed` | float | `80.0` | px/s |
| `enable_wall_jump` | bool | `false` | on / off |
| `wall_jump_push` | float | `260.0` | any |
| `wall_jump_velocity` | float | `-380.0` | any (negative is up) |

---

## Use cases

Each example targets the `PlatformerMovement` behavior on the named node (here `Player`). Horizontal running is automatic - you only wire Jump, tune the Inspector, and react to triggers, conditions, and expressions.

### 1. Tap for a hop, hold for a full jump

The core jump. Call Jump on the press and Jump Released on the release, and variable jump height (on by default) gives you a low tap and a high hold from the same button.

```
On "jump" pressed
  -> Player | PlatformerMovement: Jump

On "jump" released
  -> Player | PlatformerMovement: Jump Released
```

Coyote time and buffering are already inside Jump, so a press just after a ledge or just before landing still counts.

### 2. Double jump with a flair

Set `max_jumps` to 2 in the Inspector and the same Jump button now does a mid-air jump. On Double Jumped fires only for the air jump, so it is the perfect hook for a spin, a puff of dust, or a second sound.

```
On "jump" pressed
  -> Player | PlatformerMovement: Jump

On Double Jumped
  -> Player: play "spin" animation
  -> Player: spawn double-jump puff at Player.global_position
```

On Jumped still fires for the ground jump, so ground and air jumps get different effects with no extra logic.

### 3. Landing dust and a squash

React the moment the body touches down. On Landed is the clean hook for a dust burst, a squash-and-stretch, and a footstep thud.

```
On Landed
  -> Player: play "land" animation
  -> Player: spawn dust at Player.global_position
  -> Player: play "thud" sound
```

### 4. Fall damage from a long drop

Read Air Time on landing. If the body was airborne long enough, it fell far - hurt the player scaled by the drop.

```
On Landed
  Condition: [Expression] Player | PlatformerMovement  Air Time  >  1.2
    -> Player: take damage (Player.Air Time - 1.2) * 20
    -> Player: play "hard land" animation
```

Air Time resets to 0 on landing, so a short hop never triggers it - only a real fall crosses the threshold.

### 5. Wall slide and wall jump

Turn on `enable_wall_slide` and `enable_wall_jump` in the Inspector. Pressing into a wall in the air now clings and slow-slides, and the jump button kicks away from it. React to the slide for a cling animation and to On Wall Jumped for the kick.

```
Every frame
  Condition: Player | PlatformerMovement  Is Wall Sliding
    -> Player: play "wall cling" animation

On "jump" pressed
  -> Player | PlatformerMovement: Jump

On Wall Jumped
  -> Player: play "wall kick" sound
  -> Player: spawn wall spark at Player.global_position
```

Jump handles the wall jump automatically when you are against a wall in the air, so you still only call Jump on the press.

### 6. Sprint by changing move speed

Hold a sprint key to raise the top speed, and drop it back on release. Set Move Speed changes the run speed live.

```
On "sprint" pressed
  -> Player | PlatformerMovement: Set Move Speed  340

On "sprint" released
  -> Player | PlatformerMovement: Set Move Speed  200
```

The Inspector `move_speed` (200) is the resting value, so setting it back to 200 restores normal running.

### 7. Speed pads and mud patches

A conveyor or haste zone speeds the player up on enter and restores normal speed on exit; a mud patch does the opposite.

```
On area "SpeedPad" entered
  -> Player | PlatformerMovement: Set Move Speed  400

On area "SpeedPad" exited
  -> Player | PlatformerMovement: Set Move Speed  200

On area "Mud" entered
  -> Player | PlatformerMovement: Set Move Speed  90
```

### 8. Refill air jumps on a bounce pad

A bounce pad or updraft gives the player their double jump back mid-air. Reset Jumps refills the air-jump count without touching the ground.

```
On area "BouncePad" entered
  -> Player | PlatformerMovement: Reset Jumps
  -> Player | PlatformerMovement: Jump
  -> Player: play "boing" sound
```

Calling Jump right after the refill launches an immediate bounce off the pad.

### 9. Drive the animation from conditions

Pick the sprite state each frame from what the body is doing. The conditions are mutually clear: moving on the ground, rising, or falling.

```
Every frame
  Condition: Player | PlatformerMovement  Is Jumping
    -> Player: play "jump" animation
  Condition: Player | PlatformerMovement  Is Falling
    -> Player: play "fall" animation
  Condition: Player | PlatformerMovement  Is Moving
    Condition: Player | PlatformerMovement  Is Falling  (inverted)
    Condition: Player | PlatformerMovement  Is Jumping  (inverted)
    -> Player: play "run" animation
```

Is Jumping is true only while rising and Is Falling only while descending, so an airborne character never shows the run animation.

### 10. Flip the sprite with facing direction

Read Facing Direction (1 for right, -1 for left) to mirror the sprite. It only changes when the player actually steers, so a standing character keeps facing the way it last moved.

```
Every frame
  Condition: [Expression] Player | PlatformerMovement  Facing Direction  ==  -1
    -> Player/Sprite2D: set flip_h = true
  Condition: [Expression] Player | PlatformerMovement  Facing Direction  ==  1
    -> Player/Sprite2D: set flip_h = false
```

### 11. A jump-ready HUD hint

Show a small icon only when a jump would actually fire. Can Jump is true on the floor, within coyote time, with an air jump left, or against a wall (wall jump on), so the hint appears exactly when pressing the button does something.

```
Every frame
  Condition: Player | PlatformerMovement  Can Jump
    -> JumpIcon: show
  Condition: Player | PlatformerMovement  Can Jump  (inverted)
    -> JumpIcon: hide
```

### 12. Footstep loop while running

Loop a footstep sound only while the body is genuinely moving along the ground, and stop it the instant the player stands still or leaves the floor.

```
Every frame
  Condition: Player | PlatformerMovement  Is Moving
    Condition: Player | PlatformerMovement  Is Jumping  (inverted)
    Condition: Player | PlatformerMovement  Is Falling  (inverted)
    -> Player/Footsteps: play if not already playing
  Else
    -> Player/Footsteps: stop
```

Is Moving watches the actual horizontal speed, so tiny drift while stopping does not keep the loop alive.

### 13. Screen shake and dust on every jump

On Jumped fires at the exact launch, a clean place to kick the camera and puff some dust for a weighty feel.

```
On Jumped
  -> Camera2D: add shake 4
  -> Player: spawn jump puff at Player.global_position
  -> Player: play "jump" sound
```

### 14. A double-jump counter on the HUD

Show how many air jumps remain. Jumps Remaining refills when the body lands (and on Reset Jumps), so the pips fill in as soon as the player touches the ground.

```
Every frame
  -> HUD/JumpPips: set count to Player | PlatformerMovement  Jumps Remaining

On Double Jumped
  -> HUD/JumpPips: flash the spent pip
```

Pair it with `max_jumps` set to 2 or 3 so there is a count to show.

---

## Tips and common mistakes

- **The host must be a `CharacterBody2D`.** The behavior moves its parent node, and that parent has to be a `CharacterBody2D` with a collision shape and a floor to stand on. Attached to anything else, it warns and does nothing. One behavior per character.
- **Horizontal movement is automatic - do not fight it.** The behavior reads `ui_left` and `ui_right` and sets the body's velocity itself every physics frame, then calls `move_and_slide`. Do not also write your own left/right movement or set `velocity.x` on the same body, or the two will cancel each other out. Steer by binding keys to `ui_left` and `ui_right` in the Input Map.
- **You bind and call Jump yourself.** The behavior does not read a jump input for you (it only reads left and right). Add your own jump input action and call the Jump action on its press. Call it on the raw press every time - Jump decides whether to jump, wall jump, air jump, or buffer.
- **Coyote time and buffering are already handled.** If a jump ever feels dropped, the cause is almost always input binding, not the behavior. Jump buffers a slightly-early press and coyote time covers a slightly-late one, both out of the box, so always call Jump on the press and let it sort the timing.
- **Jump Released only matters with variable jump height.** Call it on the button release to get the tap-hop, hold-high feel. If `variable_jump_height` is off, or you never call Jump Released, every jump reaches full height - which is fine if that is the feel you want.
- **Velocities are negative for up.** `jump_velocity` and `wall_jump_velocity` are negative because up is negative Y in Godot 2D. A positive value would launch the character downward, so keep the minus sign and make the number more negative for a bigger jump.
- **Double jump is just `max_jumps`.** Set it to 2 (or more) in the Inspector and Jump handles the air jumps automatically. Ground jumps fire On Jumped and air jumps fire On Double Jumped, so you can give each its own effect.
- **Wall slide and wall jump start off.** Turn on `enable_wall_slide` and `enable_wall_jump` in the Inspector to use them. Wall jump also needs the body to actually report touching a wall, so give walls collision and press into them in the air.
- **Set Move Speed is live, and the Inspector value is the default.** After a sprint or a slow patch, set the speed back to your resting `move_speed` (the Inspector default) yourself - the behavior does not restore it automatically.
- **Facing Direction only updates when steering.** It holds the last horizontal direction (1 or -1) and does not change while the character stands still, which is exactly what you want for keeping a sprite facing the way it last moved.
