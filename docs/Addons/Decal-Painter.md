# Decal Painter - Blob Shadows, Splats, and Ground Marks in 3D

Sheet-driven Godot `Decal` nodes: stamp textures onto world surfaces (splats, scorch marks,
target rings) with lifetimes and a FIFO cap, keep a soft **blob shadow** ground-snapped under
any character (no asset needed - the shadow texture is generated), and project a 2D
**Drawing Canvas**'s live texture onto the 3D world.

## Where this pack shines

- **Character shadows in one row.** `Spawn Blob Shadow` follows a node, raycasts down against
  your floor mask (picked from a checkbox list of named layers), and hugs the ground - the
  cheap, readable shadow every stylized 3D game uses.
- **Splats that manage themselves.** Lifetime decals fade out and free; the max-decals cap
  recycles the oldest - a hundred bullet holes never becomes a leak.
- **2D drawing on 3D ground.** `Spawn Canvas Decal` takes a Drawing Canvas behavior node and
  projects its LIVE texture - draw a telegraph ring or a line-of-sight fan with 2D verbs and
  paint it on the floor.

## Setup

1. Attach `DecalPainter` as a child of any Node3D (spawned decals parent under the host).
2. Rows call the spawn verbs; positions are world coordinates. Decals project downward and
   catch slopes (a deep projection box).

```
On Ready -> World | Decal Painter: Spawn Blob Shadow  $Player, 1.2, 0.7, [Floor]
On Shot Hit -> World | Decal Painter: Spawn Decal  preload("res://fx/hole.png"),
               hit_x, hit_y, hit_z, 0.4, rand_deg, 12.0
```

## ACE reference

### Actions

| Action | Parameters | Description |
|---|---|---|
| Spawn Decal | `texture`, `x`, `y`, `z`, `size`, `rotation_deg`, `lifetime` | Stamps a decal at a world position. Lifetime 0 = forever (until the cap recycles it); otherwise it fades out over Fade Seconds and frees. |
| Spawn Blob Shadow | `follow` (Node), `radius`, `opacity`, `collision_mask_3d` | A soft generated shadow that follows the node, ground-snapped by raycast against the mask. The mask param opens the 3D layer PICKER. |
| Stop Blob Shadow | `follow` | Removes that node's blob shadow. |
| Spawn Canvas Decal | `canvas` (Node), `x`, `y`, `z`, `size`, `rotation_deg` | Projects a Drawing Canvas behavior's live texture onto the world - it updates as the canvas draws. |
| Clear Decals | (none) | Frees every spawned decal and blob shadow. |
| Set Max Decals | `count` (int) | The FIFO cap (oldest freed when over). |

### Expressions and Inspector properties

| Kind | Name | Description |
|---|---|---|
| Expression | Decal Count | Live spawned decals (blob shadows not included). |
| Property | `max_decals` (`64`) | The FIFO cap. |
| Property | `fade_seconds` (`0.5`) | Fade-out length when a lifetime ends. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

## Use cases

### 1. Squad shadows

```
On Ready -> For each Soldier:
  World | Decal Painter: Spawn Blob Shadow  Soldier, 0.9, 0.6, [Floor]
```

Shadows track each soldier over ramps and stairs - the raycast finds the floor every frame.

### 2. Bullet holes with a budget

```
On Ready    -> World | Decal Painter: Set Max Decals  80
On Shot Hit -> World | Decal Painter: Spawn Decal  $HoleTex, hx, hy, hz, 0.25, random(360), 0
```

Eighty holes stay; the eighty-first recycles the oldest. Zero cleanup rows.

### 3. AoE target ring from the 2D canvas

```
On Ready -> Hud | Drawing Canvas: Draw Ring  256, 256, 200, 24, Color(0.3, 1, 0.5)
         -> World | Decal Painter: Spawn Canvas Decal  $Hud/DrawingCanvas, cast_x, 0, cast_z, 6, 0
```

Animate the ring on the canvas (auto-clear + redraw with a growing radius) and the ground
marking animates too - the decal shows the live texture.

### 4. Scorch marks that fade

`Spawn Decal` with lifetime 8: the blast mark lingers, fades over half a second, and frees
itself - battlefield reads recent history without bookkeeping.

### 5. The one-row shadow

The simplest setup - a single row gives the player character the grounded depth cue every 3D
platformer needs.

```
On Ready -> World | Decal Painter: Spawn Blob Shadow  $Player, 1.0, 0.65, [Floor]
```

### 6. Footprints in the snow

Stamp a small print behind the player on a cadence; a short lifetime melts the trail away on
its own.

```
Every 0.4 seconds
  Condition: player is moving -> World | Decal Painter: Spawn Decal  $PrintTex, px, py, pz, 0.2, facing_deg, 12
```

Alternate a small left/right offset per stamp and the trail reads as actual steps.

### 7. Paint-coverage scoring

A splat shooter where the score IS the paint on the ground - Decal Count does the counting
for you.

```
On Ready     -> World | Decal Painter: Set Max Decals  400
On Paint Hit -> World | Decal Painter: Spawn Decal  $SplatTex, hx, hy, hz, 0.6, random(360), 0
Every tick   -> set HUD score to Decal Count
```

Raise the cap first - the default 64 would quietly recycle your score.

### 8. Wounded enemies leave a trail

Pair with the Health pack: once an enemy is badly hurt, drip marks let the player track it
through the brush.

```
Every 0.5 seconds
  Condition: enemy is low on health (Health pack) -> World | Decal Painter: Spawn Decal  $DripTex, ex, ey, ez, 0.15, random(360), 20
```

### 9. Landing dust ring

Pair with the FPS Controller pack: the instant the character touches down, puff a ring under
their feet - lifetime 1 plus the default half-second fade reads as settling dust.

```
On player landed (FPS Controller pack) -> World | Decal Painter: Spawn Decal  $DustRing, px, py, pz, 0.8, 0, 1
```

### 10. Drift skid marks

Stamp short dark streaks under the rear wheels while the car drifts; the FIFO cap quietly
eats the oldest rubber.

```
Every 0.1 seconds
  Condition: car is drifting -> World | Decal Painter: Spawn Decal  $SkidTex, wx, wy, wz, 0.3, car_yaw_deg, 15
```

### 11. Player graffiti on the floor

Let players doodle in a 2D panel with the Drawing Canvas pack, then stamp the LIVE drawing
onto the ground - it keeps updating while they keep drawing.

```
On Stamp Pressed -> World | Decal Painter: Spawn Canvas Decal  $Hud/DrawingCanvas, px, 0, pz, 3, 0
```

### 12. Clean slate between levels

Clear Decals frees every splat AND every blob shadow - so respawn the shadows for the units
that carry over.

```
On Level End   -> World | Decal Painter: Clear Decals
On Level Start -> World | Decal Painter: Spawn Blob Shadow  $Player, 1.0, 0.65, [Floor]
```

### 13. Low-spec decal budget

A settings toggle shrinks the FIFO cap on weaker devices - lowering the cap frees the oldest
marks immediately, no restart needed.

```
On Low Spec Enabled -> World | Decal Painter: Set Max Decals  16
```

### 14. Ground-slam telegraph

The boss's warning ring appears exactly where the slam will land and fades out right as the
impact hits.

```
On Slam Windup -> World | Decal Painter: Spawn Decal  $WarnRing, bx, by, bz, 4, 0, 1.5
```

### 15. Minion shadows with tidy exits

Summons get a shadow the frame they appear and lose it the frame they expire - Stop Blob
Shadow is per followed node, so nothing orphans.

```
On Minion Summoned -> World | Decal Painter: Spawn Blob Shadow  Minion, 0.6, 0.5, [Floor]
On Minion Expired  -> World | Decal Painter: Stop Blob Shadow  Minion
```

### Other use cases

**Golf divots.** Every landing stamps a small dark divot with a long lifetime, so the fairway slowly records the whole round.

**Horror scene dressing.** Stains and drag marks spawned at level start from a data list dress a crime scene without hand-placing Decal nodes in the editor.

**RTS rally markers.** A flat rally-ring decal at each squad's ordered destination hugs ramps and cliffs, so the order reads correctly on any terrain.

**Shooting-range scoring.** Each hit stamps a small ring on the target berm; clearing the round wipes them all in one action before the next shooter steps up.

**Crop trampling.** A farming sim stamps a faint flattened-grass mark wherever livestock wander, and lifetimes let the field slowly recover on its own.

## Tips and common mistakes

- **Decals need surfaces.** A Godot Decal projects onto meshes inside its box - floating it
  in empty air shows nothing. Spawn at (or just above) the surface; the deep projection box
  does the rest.
- **Name your 3D physics layers.** The blob shadow's mask param reads Project Settings >
  Layer Names > 3D Physics - "Floor" as a checkbox beats guessing the bitmask.
- **Blob shadows are decals too** - they render on whatever is beneath, including moving
  platforms and ramps, which is exactly why they read better than a static dark sprite.
- **Canvas decals inherit canvas alpha.** Draw on the canvas with transparent backgrounds
  (the default) so only your strokes project.
