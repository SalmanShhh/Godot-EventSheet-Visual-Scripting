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

## Tips and common mistakes

- **A mismatched type is a safe no-op.** Rotation Type `2d` on a Node3D (or `x` on a Node2D)
  simply does nothing - swap the knob or reparent freely, nothing errors.
- **Speed is degrees, not radians.** 360 = one full turn per second.
- **The editor preview reads the Inspector live** - change Speed while previewing and the
  spin retunes instantly. It restores the node's rotation when stopped.
