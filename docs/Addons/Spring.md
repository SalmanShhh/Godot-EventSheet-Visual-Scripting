# Spring - Bouncy, Physical Motion for Any Number

Spring is a Godot EventSheets behavior pack for motion that feels alive. You attach a `SpringBehavior` to a Node2D and it becomes a bank of named springs. A spring is just a number that chases a target with real velocity, overshoot, and settle - instead of snapping to the target instantly, it accelerates toward it, sails a little past, and eases back. Name a spring, point it at a target with **Spring To**, and read the live value back with **Spring Value**. For the common case, one-line helpers - **Spring Host X**, **Spring Host Y**, **Spring Host Angle**, **Spring Host Scale** - spring the parent node's position, rotation, and scale directly, so squash-and-stretch juice is a single row. There are named color springs too, for hit flashes and pulses. It is a per-node behavior, not an autoload: every Action, Condition, Expression, and Trigger targets the `SpringBehavior` living on the node you drop it on. The host node must be a `Node2D` (or a subclass, like `Sprite2D` or a body).

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

- **UI juice.** Buttons, icons, and cards that pop and settle when pressed or shown read as responsive instead of static.
- **Squash and stretch.** A character that squashes on landing and stretches on a jump sells weight and impact with one spring on its scale.
- **Springy camera follow.** A camera that springs toward its target lags behind fast motion and eases in, giving movement a sense of mass.
- **Menu and panel slide-ins.** A HUD element that springs in from off-screen overshoots slightly and settles, far nicer than a linear slide.
- **Weapon recoil and kickback.** An impulse on a recoil spring kicks the gun back and springs it home, no keyframing.
- **Hit flashes and color pulses.** A color spring snaps to white on a hit and springs back to normal, a classic damage tell.
- **Smooth resource bars.** A health or mana bar that springs toward its new value instead of jumping communicates the change and feels premium.
- **Rolling number counters.** A score or coin counter that springs toward the real total counts up with a snappy, satisfying settle.
- **Lean and tilt.** A vehicle or character that springs its angle into turns and back adds secondary motion for free.
- **Pickup and collectible bounce.** Coins and gems that pop in on spawn with a springy scale draw the eye.
- **Secondary motion.** Antennae, tails, and dangly bits that spring toward a rest pose add life to otherwise stiff sprites.
- **Anything that should not snap.** Any value that currently jumps instantly - a door angle, a camera zoom driver, a shader parameter - becomes juicier when a spring drives it.

---

## Core concepts

The model is small. A handful of ideas cover the whole pack.

**A spring is a named number that chases a target.** You give it a name (any string) and a target. Each frame it accelerates toward the target, overshoots a little, and eases back until it settles. Point it somewhere with **Spring To**; read where it is right now with **Spring Value**. The motion is framerate-independent, so it behaves the same at 30 and 144 fps.

**Springs are created on demand and independent.** The first time you name a spring, it is created using the Inspector defaults. Two different names are two different springs on the same behavior - `"health"` and `"score"` never interfere. There is no "register first" step; naming it is creating it.

**Three knobs shape the feel.** Every spring has:

- **Stiffness** - the pull toward the target. Higher is snappier and reaches the target faster.
- **Damping** - how quickly the bounce dies out. This one runs backwards from intuition: `0` oscillates forever, `1` removes all overshoot. Low damping is bouncy; high damping settles flat.
- **Precision** - how close (in distance and speed) counts as arrived. Once inside it, the spring snaps exactly onto the target and settles.

Set global defaults for new springs in the Inspector, or override one spring at a time with **Configure Spring**.

**Host helpers apply for you.** **Spring Host X**, **Spring Host Y**, **Spring Host Angle**, and **Spring Host Scale** drive the parent Node2D directly, every frame, no reading back. Spring Host Scale springs uniform scale, which is your squash-and-stretch. These are the fast path for juicing a node's own transform.

**Custom springs you read back yourself.** For anything that is not the host transform - a health bar, a score number, a sprite's modulate, a shader value - spring a named value and read it each frame with **Spring Value**, then apply that number wherever you want. The spring does the physics; you decide what it drives.

**Color springs are a separate family.** **Spring Color** animates a named color component by component. Read it back with **Color Value** and apply it to a sprite's modulate. Seed it first with **Set Color Value** so it springs from the right starting color. This is the whole recipe for a hit flash.

**Targets pull, impulses kick.** **Spring To** and **Set Spring Value** move where the spring is heading. **Add Impulse** does not touch the target - it jolts the current velocity for a one-off bump (recoil, a nudge), and the spring naturally springs back to wherever the target already was.

**Triggers tell you when motion starts and ends.** **On Spring Started** fires when **Spring To** or **Spring Color** kicks a settled spring back into motion. **On Spring Reached** fires the frame a spring lands on its target. Both report the spring's name, so you can react to a specific one.

---

## Setup

**1. Attach the behavior.** Add a `SpringBehavior` as a child node of a `Node2D` (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior acts on its parent, so the parent must be a Node2D or a subclass. One behavior gives that node as many named springs as you want.

**2. Set the Inspector defaults (optional).** Select the behavior node and tune the feel new springs start with:

| Property | Default | What it does |
|---|---|---|
| `default_stiffness` | `170.0` | Spring force toward the target. Higher is snappier. |
| `default_damping` | `0.85` | How fast the bounce dies out. `0` oscillates forever, `1` no overshoot. Lower is bouncier. |
| `default_precision` | `0.01` | Distance and speed below which a spring counts as settled. |

**3. Drive a spring.** Point a spring at a target, then either let a host helper apply it or read it back and apply it yourself. Here is a complete first behavior - an icon that pops in when it spawns:

```
On Ready
  # The Icon's Scale is set to (0, 0) in the editor, so it grows in from nothing.
  -> Icon | Spring: Spring Host Scale  1.0

On Spring Reached
  -> Icon: enable click input
```

**Spring Host Scale** seeds from the node's current scale (0), springs up toward `1.0`, overshoots a touch, and settles - a bouncy pop-in. Because it is a host helper, it writes to the node's scale for you; there is nothing to read back. **On Spring Reached** then fires the moment it lands, a clean hook for "the intro is done, turn input on."

---

## ACE reference

All ACEs live in the **Spring** category and act on the `SpringBehavior` of the node they are placed on. Spring names are plain strings you choose - the same name always refers to the same spring on that behavior.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Spring To | `spring_name` (String), `target` (float) | Springs the named value toward a target. Creates the spring on first use. |
| Spring Between | `spring_name` (String), `from_value` (float), `to_value` (float) | Snaps to a start value, then springs to the end value. |
| Set Spring Value | `spring_name` (String), `value` (float) | Snaps the named spring to a value instantly, with no motion (also seeds its target). |
| Add Impulse | `spring_name` (String), `amount` (float) | Kicks the named spring's velocity for instant juice, without changing its target. |
| Stop Spring | `spring_name` (String) | Freezes the named spring where it is. |
| Configure Spring | `spring_name` (String), `stiffness` (float), `damping` (float), `precision` (float) | Per-spring stiffness, damping, and precision overrides (damping is clamped to 0 - 1). |
| Spring Host X | `target` (float) | Springs the host's X position and writes it to the parent each frame. |
| Spring Host Y | `target` (float) | Springs the host's Y position and writes it to the parent each frame. |
| Spring Host Angle | `degrees` (float) | Springs the host's rotation in degrees. |
| Spring Host Scale | `target` (float) | Springs the host's uniform scale - your squash and stretch. |
| Set Color Value | `spring_name` (String), `color` (Color) | Snaps a named color spring instantly, no motion. Seed it before you spring it. |
| Spring Color | `spring_name` (String), `target_color` (Color) | Springs a named color toward a target color, channel by channel. |
| Pause Spring | `spring_name` (String) | Freezes a spring in place (numeric and/or color); Resume continues it. |
| Resume Spring | `spring_name` (String) | Resumes a paused spring toward its target. |
| Remove Spring | `spring_name` (String) | Deletes a named spring (numeric and/or color). |
| Reset All Springs | (none) | Clears every spring on this behavior. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Springing | `spring_name` (String) | Whether the named numeric spring exists and is still moving toward its target. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Spring Value | `spring_name` (String) | float | The current value of a named numeric spring (0 if it does not exist). |
| Spring Velocity | `spring_name` (String) | float | The named spring's current velocity (0 if it does not exist). |
| Spring Progress | `spring_name` (String) | float | How far the spring has travelled from its start toward its target, 0 to 1 (1 if it does not exist). |
| Color Value | `spring_name` (String) | Color | The current color of a named color spring (white if it does not exist). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Spring Started | A settled spring is kicked back into motion by **Spring To** or **Spring Color**. Reports the spring's name. |
| On Spring Reached | A spring settles onto its target, numeric or color. Reports the spring's name (host springs report their internal names). |

### Inspector properties

| Property | Type | Default | Range | What it does |
|---|---|---|---|---|
| `default_stiffness` | float | `170.0` | 1 - 1000 | Pull toward the target for new springs; higher is snappier. |
| `default_damping` | float | `0.85` | 0 - 1 | Bounce decay for new springs; `0` oscillates forever, `1` no overshoot. |
| `default_precision` | float | `0.01` | - | Distance and speed below which a new spring counts as settled. |

These seed every new spring. Override a single spring at runtime with **Configure Spring**.

---

## Use cases

Each example targets the `SpringBehavior` on the named node. Host helpers apply to the parent for you; for custom named springs, read the value back with an expression and apply it in an "Every tick" event.

### 1. Pop-in on spawn

A collectible grows in from nothing with a springy overshoot. Set the node's Scale to `(0, 0)` in the editor, then spring it to full size on ready.

```
On Ready
  -> Coin | Spring: Spring Host Scale  1.0
```

Spring Host Scale seeds from the current scale (0), so it grows in, sails a little past 1.0, and settles.

### 2. Juicy button press

A button squishes and pops when pressed, without keyframes. Seed a `"pop"` spring at 1.0 so its target is rest scale, kick it with an impulse on press, and drive the button's scale from it.

```
On Ready
  -> Button | Spring: Set Spring Value  "pop", 1.0

On Button Pressed
  -> Button | Spring: Add Impulse  "pop", 6

Every tick
  -> Button: set uniform scale to  Button | Spring: Spring Value  "pop"
```

The impulse jolts the velocity; because the target is still 1.0, the spring overshoots and springs back to rest on its own.

### 3. Squash and stretch on landing

A character squashes on impact and springs back to normal. **Spring Between** snaps to the squashed scale, then springs to 1.0; read it into the sprite's scale.

```
On Landed
  -> Player | Spring: Spring Between  "squash", 0.7, 1.0

Every tick
  -> Player: set uniform scale to  Player | Spring: Spring Value  "squash"
```

The snap-to-0.7 gives the impact; the spring back to 1.0 overshoots slightly for the "boing."

### 4. Springy camera follow

A camera trails its target with mass. Spring the host X and Y toward the player every frame - the lag and ease come free from the spring.

```
Every tick
  -> Camera | Spring: Spring Host X  Player.global_position.x
  -> Camera | Spring: Spring Host Y  Player.global_position.y
```

Lower the Inspector `default_stiffness` for a looser, laggier camera; raise it for a tight follow.

### 5. Slide-in HUD panel

A panel springs in from off-screen when a menu opens. Place the node at its off-screen X in the editor, then spring the host X to its on-screen target.

```
On Menu Opened
  -> Panel | Spring: Spring Host X  240

On Spring Started
  -> Panel: play "whoosh" sound
```

On Spring Started fires as the slide begins (Spring Host X does not fire it, so this hooks the Spring To on a companion spring or a follow-up motion; for the whoosh here, trigger it off the same Menu Opened event instead).

### 6. Weapon recoil and kickback

Firing kicks the gun sprite back and springs it home. Seed a `"recoil"` spring at 0, add a negative impulse on each shot, and read it as a local offset. Spring Velocity can also drive a muzzle stretch.

```
On Ready
  -> Gun | Spring: Set Spring Value  "recoil", 0

On Fired
  -> Gun | Spring: Add Impulse  "recoil", -30

Every tick
  -> GunSprite: position.x = Gun | Spring: Spring Value  "recoil"
  -> Muzzle: scale.x = 1.0 + abs(Gun | Spring: Spring Velocity  "recoil") * 0.002
```

The impulse jolts the gun back; the spring pulls it back to 0. Spring Velocity is largest right after the shot, so the muzzle stretch peaks on the kick.

### 7. Hit flash

An enemy flashes white on damage and springs back to its normal tint. Seed the flash color, snap it to white on a hit, spring it back, and apply Color Value to the sprite's modulate.

```
On Ready
  -> Enemy | Spring: Set Color Value  "flash", Color.WHITE

On Damaged
  -> Enemy | Spring: Set Color Value  "flash", Color(2, 2, 2)
  -> Enemy | Spring: Spring Color  "flash", Color.WHITE

Every tick
  -> EnemySprite: modulate = Enemy | Spring: Color Value  "flash"
```

Set Color Value snaps to a bright over-white instantly; Spring Color eases it back to normal for a soft fade-out.

### 8. Smooth health bar

A health bar springs toward its new value instead of jumping. Spring a `"hp"` value toward the ratio whenever health changes, and drive the fill from it.

```
On Health Changed
  -> Bar | Spring: Spring To  "hp", Player.hp / Player.max_hp

Every tick
  -> BarFill: scale.x = Bar | Spring: Spring Value  "hp"
```

A big hit visibly drains the bar with a little settle at the end, which reads better than an instant drop.

### 9. Rolling score counter

The score counts up with a snappy settle. Spring a `"score"` value toward the real total, read it back, and round it for display.

```
On Score Changed
  -> HUD | Spring: Spring To  "score", Game.score

Every tick
  -> ScoreLabel: text = str(round(HUD | Spring: Spring Value  "score"))
```

Raise the stiffness on the `"score"` spring for a faster roll-up, lower it for a lazier count.

### 10. Lean into turns

A vehicle tilts as it turns and springs back upright. Spring the host angle on the turn stimulus.

```
On Turn Left
  -> Car | Spring: Spring Host Angle  -12

On Turn Right
  -> Car | Spring: Spring Host Angle  12

On Stop Turning
  -> Car | Spring: Spring Host Angle  0
```

The overshoot on the return gives a natural little wobble as the car straightens out.

### 11. Bouncy chest lid with Configure Spring

A chest lid springs open with an exaggerated bounce. Configure that one spring with low damping for extra overshoot, then spring its angle and read it into the lid's rotation.

```
On Ready
  -> Chest | Spring: Configure Spring  "lid", 260, 0.25, 0.01

On Opened
  -> Chest | Spring: Spring To  "lid", 95

Every tick
  -> Lid: rotation_degrees = Chest | Spring: Spring Value  "lid"
```

Damping `0.25` is deliberately bouncy, so the lid flings open, overshoots past 95, and rocks back into place.

### 12. Chain the next beat with On Spring Reached

A door springs open, and the next event only fires once it has fully settled. Filter On Spring Reached by the spring's name so other springs on the same node do not trigger it.

```
On Opened
  -> Door | Spring: Spring To  "swing", 110

Every tick
  -> Door: rotation_degrees = Door | Spring: Spring Value  "swing"

On Spring Reached  (name = "swing")
  -> Room: spawn ambush enemies
```

Because On Spring Reached carries the spring's name, you can gate the follow-up to the exact spring that finished.

### 13. Gate an effect on Spring Progress

A charge-up ability sparks once it is halfway charged. Read Spring Progress and compare it in a condition.

```
On Charging
  -> Ability | Spring: Spring To  "charge", 1.0

Every tick
  Condition: Ability | Spring: Spring Progress  "charge"  >=  0.5
    -> Ability: emit charge sparks
```

Spring Progress runs 0 to 1 from the spring's start to its target, so `>= 0.5` is "past the halfway point" regardless of the actual values.

### 14. Block input while a spring is animating

A dash locks out other input until it finishes. Guard the jump on Is Springing being false for the dash spring.

```
On Dash Pressed
  -> Player | Spring: Spring To  "dash", 400

On Jump Pressed
  Condition: Player | Spring: Is Springing  "dash"  (inverted)
    -> Player: start jump
```

Is Springing stays true while the dash spring is still moving, so the jump is ignored until the dash settles.

### 15. Pause, resume, stop, reset, and clean up

Freeze springs when the game pauses and resume them after; cancel one mid-flight; wipe them on respawn. These are the housekeeping actions.

```
On Game Paused
  -> Elevator | Spring: Pause Spring  "lift"

On Game Resumed
  -> Elevator | Spring: Resume Spring  "lift"

On Player Hit
  -> Player | Spring: Stop Spring  "dash"

On Respawn
  -> Player | Spring: Reset All Springs
```

Pause Spring freezes a spring exactly where it is; Resume Spring picks it back up toward the same target. Stop Spring cancels one spring's motion for good. Reset All Springs clears every spring on the behavior, and **Remove Spring** deletes a single named one when you no longer need it.

### Other use cases

**Fishing bobber.** The float sits on a Y spring; a nibble calls Add Impulse for a convincing dip-and-recover, and the real bite gives a bigger kick the player learns to read.

**Beat-reactive props.** On every music beat, Add Impulse to a scale spring driving speakers, dancers, or a pulsing logo, so the whole scene throbs in time without any keyframed loop.

**Analog gauge needles.** A speedometer, heat gauge, or danger meter springs its needle angle toward each new reading, overshooting slightly on sharp changes the way a real needle would.

**Pokeable jelly pet.** Clicking a slime or mascot fires an impulse into a low-damping scale spring, so it wobbles when prodded and slowly settles - a toy built from one spring.

**Aim-down-sights zoom.** Drive the camera zoom from a named spring: aiming springs it toward the zoomed value and releasing springs it back, giving the snap-in feel without a tween chain in each direction.

---

## Tips and common mistakes

- **The host must be a Node2D.** The behavior reads and writes the parent's position, rotation, and scale, and warns if the parent is not a Node2D (or a subclass like Sprite2D or a body). The host helpers do nothing on a wrong parent; custom named springs still work, but you would have nothing to apply them to automatically.
- **Host helpers apply themselves; custom springs you read back.** Spring Host X, Y, Angle, and Scale write to the parent every frame - no reading needed. Any other named spring only integrates internally; read it with Spring Value (or Color Value) each tick and apply it wherever you want.
- **Seed color springs before you spring them.** Color Value returns white for a spring that was never set. Call Set Color Value first (usually to the resting color) so a flash springs from the right starting point instead of jumping in from white.
- **Do not build a Spring Reached to Spring To loop on the same spring.** If you re-target a spring the instant it reaches, it bounces forever. Chain to a different spring, use a one-shot, or filter On Spring Reached by name so only the intended spring re-triggers.
- **On Spring Reached fires for every spring on the behavior.** With several springs on one node, filter by the reported name. Host helpers report internal names (`__x`, `__y`, `__angle`, `__scale`), so a host spring reaching its target will show one of those, not a name you chose.
- **On Spring Started only fires for Spring To and Spring Color.** Spring Between, Add Impulse, and the Spring Host helpers start motion without firing it. If you need a "motion began" hook for those, trigger it off the same event that starts them.
- **Damping runs backwards - lower is bouncier.** `0` oscillates forever, `1` removes overshoot entirely. For juice, try `0.2` to `0.5`; for a clean, no-wobble slide, use `0.8` or higher. It is clamped to 0 - 1 inside Configure Spring, so out-of-range values are pinned.
- **Impulses kick, targets pull.** Add Impulse jolts velocity without touching the target, so the spring springs back to wherever it was already heading - perfect for recoil and bumps. Use Spring To or Set Spring Value when you actually want a new destination.
- **Configure before the first motion if you care about the first spring.** Configure Spring changes one named spring; the Inspector defaults seed the rest. Call it before the first Spring To on that name so even the opening motion uses your stiffness and damping.
- **Reset All Springs wipes the host springs too.** After a reset, the next Spring Host X / Y / Angle / Scale call re-seeds from the parent's current transform, so it will spring from wherever the node is right now, not from the old value.
