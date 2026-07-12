# Rotate - Spin Anything, 2D or 3D, Previewable in the Editor

The event-sheet-parity constant-rotation behavior: attach and the host spins at **Speed**
(degrees/second), optionally ramping by **Acceleration**. One **Rotation Type** knob covers a
2D node's rotation and a 3D node's X, Y, or Z axis - pickups, fans, windmills, planets,
drills, radar dishes. One action toggles it, and **Tools > Preview Behaviors on Selected
Node** animates the spin in the editor without running the game.

## Where this pack shines

- **Collectible spin in zero rows.** Attach to a coin (2D) or a powerup (3D, Y axis), done.
- **See it before you run it.** Select the node and Preview Behaviors - the spin animates in
  the editor viewport at the Inspector's live values; tweak Speed and watch it change.
- **Wind-up mechanics.** Acceleration ramps a drill or a saw from rest; `Reverse Rotation`
  flips a fan when the player hits the switch.
- **One pack, both dimensions.** The same behavior spins a 2D windmill and the 3D key it
  drops - swap the Rotation Type, nothing else.

## Setup

1. Attach `RotateBehavior` as a child of any Node2D or Node3D.
2. Set `speed` (degrees/second; negative spins the other way) and pick `rotation_type` -
   `2d` for a Node2D, `x`/`y`/`z` for a Node3D axis.
3. Optional: `acceleration` ramps the speed over time.

```
On Switch Pressed -> Fan | Rotate: Set Rotation Enabled  true
On Overload       -> Fan | Rotate: Set Rotation Acceleration  180
```

## ACE reference

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Set Rotation Enabled | `enabled` (bool) | The pause/resume toggle. |
| Action | Set Rotation Speed | `degrees_per_second` | Sets the live speed (negative = the other way). |
| Action | Set Rotation Acceleration | `degrees_per_second_squared` | Speed ramp (0 = constant). |
| Action | Set Rotation Type | `type` (`2d`/`x`/`y`/`z`) | What spins. |
| Action | Reverse Rotation | (none) | Flips the spin direction. |
| Condition | Is Rotating | (none) | Enabled and moving. |
| Expression | Rotation Speed | (none) | The live speed in degrees/second. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `rotate_enabled` | `true` | Spin on/off. |
| `speed` | `90.0` | Degrees per second. |
| `acceleration` | `0.0` | Degrees per second, per second. |
| `rotation_type` | `2d` | 2D rotation, or the 3D X / Y / Z axis. |

## Use cases

### 1. A coin carousel

Attach Rotate (`y`, 120 deg/s) to every 3D coin. Preview Behaviors while placing them to
check the feel without pressing Play.

### 2. The saw that spins up

```
On Blade Triggered -> Saw | Rotate: Set Rotation Acceleration  360
On Blade Cooldown  -> Saw | Rotate: Set Rotation Speed  0
                   -> Saw | Rotate: Set Rotation Acceleration  0
```

### 3. Direction puzzles

`Reverse Rotation` on a gear when the player flips a lever - chained gears read instantly
because each one visibly changes direction.

### 4. Loading spinner

The simplest setup: attach to the spinner icon (`rotation_type` `2d`, speed 270) and it
turns forever - one row stops it when the load completes.

```
On Load Finished -> Spinner | Rotate: Set Rotation Enabled  false
```

### 5. Windmill skyline

Scatter windmills with a slightly different Inspector `speed` on each (30, 42, 55) so the
skyline never looks cloned - then let the weather drive them all at once.

```
On Storm Start -> Windmills | Rotate: Set Rotation Speed  160
On Storm End   -> Windmills | Rotate: Set Rotation Speed  40
```

### 6. Prize wheel

Kick the wheel hard, bleed the speed off with negative acceleration, and award the slice
when the speed crosses zero.

```
On Spin Pressed -> Wheel | Rotate: Set Rotation Speed  720
                -> Wheel | Rotate: Set Rotation Acceleration  -160
Every tick
  Condition: Rotation Speed <= 0 -> Wheel | Rotate: Set Rotation Enabled  false
                                 -> award the slice under the pointer
```

Catch the zero crossing - negative acceleration keeps ramping, so an uncaught wheel would
start spinning backwards.

### 7. Radar sweep

The dish turns at 45 deg/s - one revolution every 8 seconds - so sync the Timer pack's
repeat to a full sweep and refresh the blips exactly once per pass.

```
On Ready -> Dish | Rotate: Set Rotation Speed  45
         -> Dish | Timer: repeat every 8 seconds, refresh the radar blips
```

### 8. Fan you can sneak past

The blades only hurt while they are actually turning - Is Rotating makes the powered-down
fan safe with zero extra bookkeeping.

```
On Player Touched Blades
  Condition: Is Rotating -> Player | Health: take damage
On Power Cut -> Fan | Rotate: Set Rotation Speed  0
```

### 9. Orbiting moon

Rotate spins nodes, and children ride along - attach it to an empty pivot at the planet's
center and offset the moon as the pivot's child to get an orbit for free.

```
On Ready -> MoonPivot | Rotate: Set Rotation Speed  20
```

### 10. Hold-to-drill

Ramp the drill up while the button is held and let the live speed drive the dig rate - a
wind-up mechanic in four rows.

```
On Drill Held     -> Drill | Rotate: Set Rotation Acceleration  240
On Drill Released -> Drill | Rotate: Set Rotation Speed  0
                  -> Drill | Rotate: Set Rotation Acceleration  0
Every tick -> set dig_rate to Rotation Speed / 720
```

### 11. Security camera that freezes on you

A sweeping camera stops dead the moment it spots the player - pausing keeps the angle, so
re-enabling resumes the sweep from exactly where it locked on.

```
On Player Spotted -> Camera | Rotate: Set Rotation Enabled  false
On Player Lost    -> Camera | Rotate: Set Rotation Enabled  true
```

### 12. Time-lapse sun dial

A sim game's day dial turns once per in-game day - the fast-forward buttons just retune the
speed and the art stays honest at every time scale.

```
On Speed x1 -> SunDial | Rotate: Set Rotation Speed  6
On Speed x4 -> SunDial | Rotate: Set Rotation Speed  24
```

### 13. One prefab, both dimensions

The same key prefab spins in the 3D world and in its 2D inventory preview - set the type per
context, and the mismatched type is a safe no-op in the other scene.

```
On Ready (world)     -> Key | Rotate: Set Rotation Type  "y"
On Ready (inventory) -> Key | Rotate: Set Rotation Type  "2d"
```

### 14. Shuriken that sticks

A thrown blade spins hard in flight and freezes at whatever angle it hit the wall - stopping
the rotation IS the impact feedback.

```
On Thrown      -> Shuriken | Rotate: Set Rotation Speed  1080
On Wall Impact -> Shuriken | Rotate: Set Rotation Enabled  false
```

### 15. Carousel ride

Spin the platform on the Y axis and every horse, pole, and rider mounted as a child turns
with it - the whole ride is one behavior on the parent.

```
On Ride Start -> Carousel | Rotate: Set Rotation Speed  25
On Ride End   -> Carousel | Rotate: Set Rotation Speed  0
```

### Other use cases

**Lighthouse beam.** A spotlight cone on a slow Y-axis rotate sweeps the bay all night; stealth boats time their runs between passes.

**Slot machine reels.** Three reels spinning on the X axis at different speeds, stopped one by one, give a pull-the-lever minigame with almost no code.

**Kaleidoscope title screen.** Layered patterned rings spinning at opposing slow speeds make a hypnotic menu backdrop for nearly zero effort.

**Cement mixer drum.** A builder sim's mixer drum turns while a batch is mixing and stops when the pour is ready, so the state reads at a glance from across the site.

**Orbiting shield orbs.** The pivot trick around the player gives an action game rotating shield orbs - speed the pivot up as the shield charges.

## Tips and common mistakes

- **A mismatched type is a safe no-op.** Rotation Type `2d` on a Node3D (or `x` on a Node2D)
  simply does nothing - swap the knob or reparent freely, nothing errors.
- **Speed is degrees, not radians.** 360 = one full turn per second.
- **The editor preview reads the Inspector live** - change Speed while previewing and the
  spin retunes instantly. It restores the node's rotation when stopped.
