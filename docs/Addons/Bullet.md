# Bullet - Fire-and-Forget Projectile Movement for a Node2D

Bullet is a Godot EventSheets behavior pack that makes a node fly on its own. You attach a `BulletBehavior` behavior to a `Node2D` - a Sprite2D, an Area2D, a CharacterBody2D, anything 2D - and that node becomes a projectile. The instant it exists it launches in the direction it is facing and keeps going every frame, with no per-frame movement code to write. Tune the feel with three numbers - **speed**, **acceleration**, and **gravity** - and the sprite can turn to face wherever it is heading. There is no "projectile id" to pass around: every Action and Expression targets the `BulletBehavior` on the node you drop it on. Change the speed live, redirect the angle, pause and resume, or read how far it has flown, all from plain event-sheet rows.

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

- **Player shots in a top-down or side shooter.** Spawn a bullet, aim it by rotation, and it streaks off on its own - no velocity math to write.
- **Enemy bullet-hell patterns.** Fire a fan, a ring, or a spiral of projectiles, each set to its own angle, and let them all fly themselves.
- **Arrows and spears with a drop.** Add a little gravity and the arrow arcs, and with rotation-alignment on it noses down as it falls.
- **Lobbed grenades and thrown items.** A higher gravity gives a heavy, short arc that lands where you aimed the throw.
- **Rockets and missiles that speed up.** A positive acceleration ramps the projectile from a slow launch to a screaming finish.
- **Thrown objects that slow to a stop.** A negative acceleration bleeds speed, so a tossed rock loses momentum as it travels.
- **Homing and curving projectiles.** Re-aim the angle toward a target on a timer and the bullet curves to track it.
- **Ricochets and bounces.** On a wall hit, redirect the angle to the reflected heading and the shot bounces onward.
- **Charge shots.** Read a charge meter and set the launch speed from it, so a held button fires faster.
- **Bullet-time and freeze frames.** Pause every projectile's movement during a hitstop or a slow-mo beat, then resume it.
- **Fireballs, magic bolts, spit, and breath attacks.** Any straight-line or arcing hazard becomes one attached behavior.
- **Range-limited shots.** Read the distance flown and despawn the bullet once it has travelled far enough.

---

## Core concepts

The mental model is small. Learn these ideas and the rest is Inspector tuning.

**The node is the bullet.** You attach one `BulletBehavior` per projectile, and it moves its parent `Node2D`. Every Action and Expression acts on the behavior of the node it sits on - there is no projectile id to thread through calls. If you attach it to something that is not a `Node2D`, it warns and stays inert.

**It launches itself the instant it exists.** There is no "fire" or "activate" call. The moment the behavior enters the tree it starts moving on the very next frame - so a bullet you spawn is already flying by the time the next event runs. You do not write per-frame movement and you do not set the node's position yourself.

**Aim is the host's rotation.** On its first frame the behavior reads the parent node's `rotation` and launches straight along it. So you aim a projectile by setting its rotation before or at spawn - point the node where you want the shot to go, and that is the direction it travels. If rotation-alignment is on, the behavior then keeps the node turned to face its actual heading as it moves.

**Three numbers shape the motion.** `speed` is how fast it launches (pixels per second). `acceleration` is added along the current heading every second - positive to speed up, negative to slow down. `gravity` is a downward pull added to the vertical velocity every second, which bends a straight shot into an arc. Set gravity to 0 for a flat top-down bullet, and to a positive value for an arrow or grenade that falls.

**Redirect and re-speed live.** Two actions steer a bullet already in flight. **Set Angle Of Motion** points it along an absolute angle in degrees, keeping its current speed. **Set Bullet Speed** changes how fast it is going while keeping its current direction. Between them you can bounce, home, brake, and boost.

**Angles are degrees, and down is positive.** In Godot 2D the y axis points down, so `0` degrees is right, `90` is down, `180` is left, and `-90` (or `270`) is up. Set Angle Of Motion takes an absolute heading in these degrees, not a turn relative to where the bullet was already going.

**Pause without destroying.** **Set Bullet Enabled** (or the reflected **Set Enabled Movement**) freezes the behavior in place - the bullet keeps its velocity and simply stops moving until you enable it again. It is the hook for pause menus, hitstop, and bullet-time, and it does not hide or delete the projectile.

**It only moves - collision is yours.** The behavior handles motion and nothing else. Give the projectile its own Area2D or body to detect hits, and destroy or recycle it yourself on impact. The behavior tracks how far it has flown in `distance_travelled`, which you read to despawn a shot that has outrun its range.

---

## Setup

**1. Attach the behavior.** Add a `BulletBehavior` behavior as a child of your projectile's `Node2D` (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The parent is the host it moves - a Sprite2D for the art, an Area2D so it can register hits, or a CharacterBody2D, are all fine (they are all Node2D). One behavior per projectile.

**2. Set the Inspector knobs.** Select the behavior node and tune the feel:

| Property | Default | What it does |
|---|---|---|
| `speed` | `300.0` | Launch and travel speed in pixels per second. |
| `acceleration` | `0.0` | Added along the current heading every second (positive speeds up, negative slows down). |
| `gravity` | `0.0` | Downward pull added to the vertical velocity every second (arcs a straight shot). |
| `gravity_angle` | `90.0` | Direction gravity pulls, in degrees (90 = down, 270 = up, 0 = right) - arcs bend that way instead of downward. |
| `align_rotation` | `true` | Turn the node to face the direction it is actually moving. |
| `enabled_movement` | `true` | Whether the behavior moves the node each frame (turn off to freeze). |

**3. Aim it and let it fly.** The behavior launches along the node's rotation, so a complete first shot is just spawn, aim, and clean up:

```
# The "Bullet" scene: a Node2D (your art plus an Area2D for hits) with a BulletBehavior child, speed 600.

On "shoot" pressed
  -> System: create "Bullet" at Muzzle.global_position
  -> Bullet: set rotation to aim from Muzzle toward the crosshair

On Bullet/Area2D: body entered
  -> Bullet: destroy
```

That is a full projectile. Point the node the way you want it to go, the behavior fires it there on the next frame at the Inspector speed, and your Area2D handles the hit. Everything below is polish on top of this.

---

## ACE reference

All ACEs live in the **Bullet** category and target the `BulletBehavior` on the node they are placed on. Each one has a leading "On node" target that defaults to the bullet's own behavior; retarget it with `$`-autocomplete to reach a bullet living elsewhere. The `Speed`, `Acceleration`, `Gravity`, `Gravity Angle`, `Align Rotation`, and `Enabled Movement` entries are generated automatically from the Inspector properties, so each exposes a matching read (expression) and write (Set, plus Add To / Subtract From for the numeric ones).

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Bullet Speed | `value` (float) | Changes speed now, keeping the current direction (recomputes the velocity), so a flying bullet immediately speeds up or slows down. |
| Set Angle Of Motion | `degrees` (float) | Redirects the bullet along an absolute angle in degrees (0 right, 90 down, 180 left, -90 up), keeping its current speed. |
| Set Gravity Angle | `angle` (float) | Points gravity in a new direction in degrees (90 = down, 270 = up, 0 = right) - the arc bends that way from now on. Magnet fields, wind wells, and upside-down zones in one action. |
| Set Bullet Enabled | `is_enabled` (bool) | Pauses the movement (`false`) or resumes it (`true`); a paused bullet keeps its velocity and simply holds position. |
| Set Speed | `value` (float) | Writes the underlying speed value that feeds the launch and Set Angle Of Motion. For a live change on a bullet already in flight, prefer Set Bullet Speed. |
| Add To Speed | `amount` (float) | Adds to the underlying speed value (see Set Speed). |
| Subtract From Speed | `amount` (float) | Subtracts from the underlying speed value (see Set Speed). |
| Set Acceleration | `value` (float) | Sets the per-second acceleration live (positive speeds the bullet up along its heading, negative slows it). |
| Add To Acceleration | `amount` (float) | Adds to the acceleration value. |
| Subtract From Acceleration | `amount` (float) | Subtracts from the acceleration value. |
| Set Gravity | `value` (float) | Sets the downward pull live (positive falls, negative floats up, 0 flies flat). |
| Add To Gravity | `amount` (float) | Adds to the gravity value. |
| Subtract From Gravity | `amount` (float) | Subtracts from the gravity value. |
| Set Align Rotation | `value` (bool) | Turns rotation-alignment on or off (`true` makes the node face its heading, `false` leaves its rotation alone). |
| Set Enabled Movement | `value` (bool) | The reflected form of Set Bullet Enabled - `true` moves the node each frame, `false` freezes it. |

### Conditions

Bullet ships no dedicated conditions - it is a pure movement behavior. To gate logic on a bullet's state, compare one of its expressions in a condition, for example `Speed  >  0` to catch a bullet still moving, or `Enabled Movement  ==  true` to catch one that is not frozen.

### Expressions

| Expression | Returns | Description |
|---|---|---|
| Speed | float | The current launch/travel speed value in pixels per second. |
| Acceleration | float | The current per-second acceleration. |
| Gravity | float | The current per-second downward pull. |
| Gravity Angle | float | The direction gravity pulls, in degrees (90 = down). |
| Align Rotation | bool | Whether the node is being turned to face its heading. |
| Enabled Movement | bool | Whether the behavior is moving the node (`false` while frozen). |

Distance flown is tracked internally and read directly with `$BulletBehavior.distance_travelled` (retarget the node path to the bullet you mean) - use it to despawn a shot once it has outrun its range.

### Triggers

Bullet fires no triggers - it only moves the node. React to a projectile with your own events instead: an Area2D `body entered` for hits, a timer for lifetime, or a distance check on `distance_travelled` for range.

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `speed` | float | `300.0` | any (pixels per second) |
| `acceleration` | float | `0.0` | any (negative slows down) |
| `gravity` | float | `0.0` | any (negative floats up) |
| `gravity_angle` | float | `90.0` | 0-360 degrees (90 = down) |
| `align_rotation` | bool | `true` | on / off |
| `enabled_movement` | bool | `true` | on / off |

---

## Use cases

Each example targets the `BulletBehavior` on the named node. The behavior launches itself along the node's rotation, so you aim by setting rotation, then react and re-steer with the actions and expressions.

### 1. A straight forward shot

The bread and butter. Spawn the bullet and point it - the behavior fires it along that rotation at the Inspector speed and keeps it going.

```
On "shoot" pressed
  -> System: create "Bullet" at Muzzle.global_position
  -> Bullet: set rotation = Player.rotation
```

No launch call is needed. The bullet is already flying on the next frame.

### 2. Aim at the mouse or a target

Point the projectile at wherever the player is aiming before it launches, and it travels dead at that spot.

```
On "shoot" pressed
  -> System: create "Bullet" at Muzzle.global_position
  -> Bullet: set rotation = Muzzle.global_position.angle_to_point(get_global_mouse_position())
```

Because aim is the host's rotation at spawn, setting rotation is all the aiming you do.

### 3. A gravity-arced grenade

Give the shot some gravity and it lobs instead of flying flat, falling toward the ground as it goes - perfect for a thrown grenade or a mortar.

```
On "throw" pressed
  -> System: create "Grenade" at Hand.global_position
  -> Grenade: set rotation = -45 degrees (up and forward)
  -> Grenade | BulletBehavior: Set Gravity  900
```

The upward launch angle plus a positive gravity makes a clean parabola that comes back down.

### 4. An arrow that noses down as it falls

Keep rotation-alignment on (the default) and add gravity, so the arrow points along its arc - tip up on the way out, tip down on the way in.

```
On "fire bow" pressed
  -> System: create "Arrow" at Bow.global_position
  -> Arrow: set rotation = Bow.aim_angle
  -> Arrow | BulletBehavior: Set Gravity  600
```

If you ever want the art to hold a fixed angle instead, turn it off with Set Align Rotation `false`.

### 5. An accelerating rocket

Launch slow and let a positive acceleration build the speed up over the flight, so a rocket lurches off the rail and then screams away.

```
On "launch rocket" pressed
  -> System: create "Rocket" at Pod.global_position
  -> Rocket: set rotation = Pod.rotation
  -> Rocket | BulletBehavior: Set Bullet Speed  120
  -> Rocket | BulletBehavior: Set Acceleration  700
```

Set Bullet Speed gives it a gentle launch, and the acceleration ramps it up along its heading every second.

### 6. A thrown object that slows down

A negative acceleration bleeds speed as the object travels, so a tossed rock or a dud slows toward a stop.

```
On "throw rock" pressed
  -> System: create "Rock" at Hand.global_position
  -> Rock: set rotation = Hand.aim_angle
  -> Rock | BulletBehavior: Set Acceleration  -500
```

The rock keeps its heading but loses momentum, coming to rest instead of flying forever.

### 7. A homing shot that curves toward the player

On a timer, re-aim the bullet at its target and it curves to track. Feed Set Angle Of Motion the absolute angle from the bullet to the player each tick.

```
Every 0.1 seconds
  -> Missile | BulletBehavior: Set Angle Of Motion  rad_to_deg(Missile.global_position.angle_to_point(Player.global_position))
```

A slower timer curves loosely (easy to dodge); a faster one tracks tightly. Speed stays whatever it was - only the heading changes.

### 8. A ricochet off a wall

On a wall hit, redirect the bullet along the reflected heading and it bounces onward instead of stopping.

```
On Bullet/Area2D: body entered  (a wall)
  -> Bullet | BulletBehavior: Set Angle Of Motion  (the reflected angle, in degrees)
```

There is no current-heading expression, so compute the reflected absolute angle from the wall normal yourself and pass it in.

### 9. A ricochet that loses speed each bounce

Bleed a chunk of speed on every bounce so a ricochet eventually dies, and destroy it once it is too slow to matter.

```
On Bullet/Area2D: body entered  (a wall)
  -> Bullet | BulletBehavior: Set Bullet Speed  Bullet | BulletBehavior.Speed * 0.7
  -> Bullet | BulletBehavior: Set Angle Of Motion  (the reflected angle)

Every frame
  Condition: [Expression] Bullet | BulletBehavior  Speed  <  60
    -> Bullet: destroy
```

Reading the Speed expression and multiplying it lets each bounce keep only part of the energy.

### 10. A shotgun spread

Fire several pellets at once, each redirected to a slightly different angle around the aim, for a fan pattern.

```
On "shoot shotgun" pressed
  For each offset in [-15, -7, 0, 7, 15]
    -> System: create "Pellet" at Muzzle.global_position
    -> Pellet | BulletBehavior: Set Angle Of Motion  Player.aim_degrees + offset
```

Each pellet gets its own absolute heading, so they leave the barrel as a spread instead of a single line.

### 11. A charge shot that fires faster the longer you hold

Build a charge value while the button is held, then set the launch speed from it, so a full charge fires a much faster round.

```
While "shoot" is held
  -> Player: add to Player.charge  1 * delta

On "shoot" released
  -> System: create "Bullet" at Muzzle.global_position
  -> Bullet: set rotation = Player.aim_angle
  -> Bullet | BulletBehavior: Set Bullet Speed  300 + Player.charge * 400
  -> Player: set Player.charge = 0
```

Set Bullet Speed on the fresh bullet launches it at exactly the charged speed while keeping the aim direction.

### 12. Bullet-time that freezes every shot

Pause all projectiles during a slow-motion or hitstop beat by disabling their movement, then resume when it ends. A frozen bullet keeps its velocity and simply holds still.

```
On "focus" pressed
  For each Bullet in group "projectiles"
    -> Bullet | BulletBehavior: Set Bullet Enabled  false

On "focus" released
  For each Bullet in group "projectiles"
    -> Bullet | BulletBehavior: Set Bullet Enabled  true
```

Nothing is hidden or destroyed, so every bullet picks up exactly where it left off.

### 13. A spiraling bullet pattern

Keep an angle variable, nudge it every tick, and feed it to Set Angle Of Motion - the bullet sweeps around into a spiral.

```
Every 0.05 seconds
  -> Bullet: add to Bullet.spin_angle  20
  -> Bullet | BulletBehavior: Set Angle Of Motion  Bullet.spin_angle
```

Because Set Angle Of Motion is absolute, storing and advancing your own angle is how you make a smooth continuous curve.

### 14. Despawn a shot after a set range

Read how far the bullet has flown and destroy it once it has outrun its useful range, so strays do not live forever off-screen.

```
Every frame
  Condition: [Expression] $Bullet/BulletBehavior.distance_travelled  >  900
    -> Bullet: destroy
```

The behavior sums the distance for you, so a range limit is one comparison and a destroy.

### 15. A spent shot that dissolves with Fade

Pair with the Fade pack so a bullet at the end of its range fades away instead of popping: freeze its movement, fade it out, and let Fade's free-on-fade-out option delete it.

```
Every frame
  Condition: [Expression] $Bullet/BulletBehavior.distance_travelled  >  800
    -> Bullet | BulletBehavior: Set Bullet Enabled  false
    -> Bullet | Fade: Fade Out  0.2
```

Freezing first keeps the shot from drifting while it dissolves, and the fade handles the cleanup for you.

### Other use cases

**Carnival shooting gallery.** Ducks and targets glide across the booth as slow flat bullets on fixed headings, reusing the same behavior for the props as for the player's shots.

**Confetti and firework bursts.** Spawn a handful of nodes at one point, give each a random rotation and some gravity, and every piece arcs outward and falls on its own.

**Underwater drag zones.** While a shot is inside water, set a strong negative acceleration so bullets visibly lose punch, then restore it when they exit.

**Volley warnings.** Fire a slow telegraph shot along the boss's aim line first, then the real fast round a beat later at the same angle, so players can read the attack.

**Ejected shell casings.** Each shot also spawns a tiny casing node with low speed, high gravity, and rotation-alignment off, for a physics-free cosmetic that arcs to the floor.

---

## Tips and common mistakes

- **The host must be a `Node2D`.** The behavior moves its parent, and that parent has to be a `Node2D` or a subclass (Sprite2D, Area2D, CharacterBody2D, and so on). Attached to anything else it warns and does nothing. The behavior is the child; the projectile is the parent. One behavior per projectile.
- **It launches itself - there is no fire call.** The moment the behavior spawns it starts moving on the next frame. Do not look for an "activate" action; instead aim the node before or at spawn and it goes.
- **Aim by rotation.** The initial direction is the host's `rotation` on its first frame, so you aim a shot by setting the projectile's rotation, not by any Bullet action. Point the node at the target before it launches.
- **Angles are degrees, and down is positive.** In Godot 2D, `0` is right, `90` is down, `180` is left, and `-90` is up. Set Angle Of Motion takes an absolute heading in these degrees - it is not a turn relative to the bullet's current direction.
- **Set Bullet Speed changes a flying bullet; Set Speed does not.** Set Bullet Speed recomputes the velocity, so it speeds up or slows down a bullet already in flight while keeping its direction. Set Speed / Add To Speed / Subtract From Speed only write the underlying speed value that feeds the launch and Set Angle Of Motion - they do not, by themselves, re-speed a bullet mid-flight. Reach for Set Bullet Speed for a live change.
- **There is no current-heading expression.** To reflect off a wall or turn relative to where the bullet is going, compute the target absolute angle yourself (from a wall normal, or a stored angle variable) and pass it to Set Angle Of Motion.
- **Gravity only pulls down.** It is added to the vertical velocity, so it arcs a shot toward positive y. Leave gravity at `0` for a flat top-down bullet; use a positive value for arrows and grenades, or a negative value to make a bubble float up.
- **Collision is not included - you handle hits.** The behavior only moves the node. Give the projectile its own Area2D or body to detect impacts, and destroy or pool it yourself; use `distance_travelled` or a lifetime timer to clean up shots that miss.
- **`align_rotation` turns the whole host.** With it on, the node is rotated to face its heading every frame - great for arrows and missiles. If your art should not spin (a round ball, an already-oriented sprite), turn it off in the Inspector or with Set Align Rotation `false`.
- **Freezing keeps the bullet alive.** Set Bullet Enabled `false` (or Set Enabled Movement `false`) only stops the motion - it does not hide or delete the projectile, and the bullet resumes with the same velocity when you enable it again.
