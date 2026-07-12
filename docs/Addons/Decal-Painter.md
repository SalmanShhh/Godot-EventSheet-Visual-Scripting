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
