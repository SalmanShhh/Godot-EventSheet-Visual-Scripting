# Blend Modes - How Two Pictures Meet

Twenty ways one picture can meet the one behind it, as rows. Five of them Godot draws by
itself; the other fifteen need a shader that reads the screen back, and this pack ships one
per mode. Plus a **mask**, so a second picture decides where the first is allowed to be.

## Where this pack shines

- **A glow that actually glows.** `Blend As: screen` on a flare sprite and it stops looking
  like a sticker.
- **A stain that darkens what is under it.** `multiply` on a scorch decal, one row.
- **A tint that keeps the shading.** `colour` recolours a sprite without flattening it.
- **A shape cut out of another.** `Mask With` hands the shape over to any texture with a
  transparent part.

## Setup

1. Add `blend_modes_addon.gd` as the **BlendModes** autoload (Project Settings ▸ Autoload),
   or let the Add Behavior flow do it.
2. Drop a **Blend As** row. It opens on `self` and `screen`, so it is already a sentence.
3. The mode field shows a little picture of every mode. Pick the one that looks right.

```
On start of layout -> Muzzle | Blend As: self, screen, 1.0
On start of layout -> Scorch | Blend As: self, multiply, 1.0
```

## The names you already know

Every mode here is the mode of the same name in the drawing tool you use. What changes is how
Godot spells it, and that is what the middle column is for.

| The name you know | How Godot does it | The row |
|---|---|---|
| Normal | `CanvasItemMaterial.blend_mode = BLEND_MODE_MIX` | Blend As: `normal` |
| Add / Linear dodge | `BLEND_MODE_ADD` | Blend As: `add` |
| Subtract | `BLEND_MODE_SUB` | Blend As: `subtract` |
| Multiply | `BLEND_MODE_MUL` | Blend As: `multiply` |
| Premultiplied alpha | `BLEND_MODE_PREMULT_ALPHA` | Blend As: `premultiplied` |
| Screen | no engine field - `blend_screen.gdshader` | Blend As: `screen` |
| Overlay | no engine field - `blend_overlay.gdshader` | Blend As: `overlay` |
| Darken | no engine field - `blend_darken.gdshader` | Blend As: `darken` |
| Lighten | no engine field - `blend_lighten.gdshader` | Blend As: `lighten` |
| Colour dodge | no engine field - `blend_colour_dodge.gdshader` | Blend As: `colour dodge` |
| Colour burn | no engine field - `blend_colour_burn.gdshader` | Blend As: `colour burn` |
| Hard light | no engine field - `blend_hard_light.gdshader` | Blend As: `hard light` |
| Soft light | no engine field - `blend_soft_light.gdshader` | Blend As: `soft light` |
| Difference | no engine field - `blend_difference.gdshader` | Blend As: `difference` |
| Exclusion | no engine field - `blend_exclusion.gdshader` | Blend As: `exclusion` |
| Hue | no engine field - `blend_hue.gdshader` | Blend As: `hue` |
| Saturation | no engine field - `blend_saturation.gdshader` | Blend As: `saturation` |
| Colour | no engine field - `blend_colour.gdshader` | Blend As: `colour` |
| Luminosity | no engine field - `blend_luminosity.gdshader` | Blend As: `luminosity` |
| Pass through / no blend | no engine field - `blend_copy.gdshader` | Blend As: `copy` |
| Clipping mask (a layer clipped to the one under it) | `CanvasItem.clip_children` | Clip My Children |
| Layer mask | a mask texture in a shader | Mask With |
| Group / merge down before blending | `CanvasGroup` | Blend As One |

## What it costs

- **The five native modes cost nothing.** They are a field on an ordinary
  `CanvasItemMaterial`; the renderer already knows how to draw a quad that way.
- **The fifteen shader modes read the screen.** Blending against what is behind you means
  having what is behind you, so the item samples the frame so far for every pixel it covers,
  every frame it is visible. That is fine for a flare, a decal, a boss aura - and wrong for
  every sprite in a bullet hell.
- **They must be drawn AFTER what they blend with.** Later in the tree, or on a higher
  `z_index`. An item that draws first has nothing under it to read.
- **Clipping costs nothing either.** `Clip My Children` is a rendering field, not a shader.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Blend *self* as **screen**
- Mask *self* with **hole_texture**, **inside**

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Blend As | `item`, `mode`, `strength` | Blends this item into whatever is drawn under it. Twenty modes; the five native ones cost nothing. |
| Action | Set Blend Strength | `item`, `strength` | Turns the blend up or down without changing which mode it is. |
| Action | Fade Blend Strength | `item`, `strength`, `seconds` | Walks the blend to a new strength over time. |
| Condition | Blend Mode Is | `item`, `mode` | True while the item is blending the way the row says. |
| Expression | Blend Mode | `item` | The mode word this item is blending by. |
| Action | Mask With | `item`, `shape`, `mode` | A texture's transparency decides where the item is allowed to be. |
| Action | Mask With Node | `item`, `shape_node`, `mode` | The same, reading the shape off another node's own picture. |
| Action | Unmask | `item` | Takes the mask off and puts back whatever was worn before. |
| Action | Blend As One | `item` | Draws the node's children into one picture first, so overlaps stop showing through each other. |
| Action | Blend Separately | `item` | Puts the children back to being drawn on their own. |
| Condition | Is Blended As One | `item` | True while the children are drawn as one picture. |

The two clipping rows are **built in** rather than part of this pack, because `clip_children`
is a field on every `CanvasItem` and needs nothing installed:

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Clip My Children | `mode` (draw me too / clip only) | Makes what this node draws the shape its children draw inside. |
| Action | Stop Clipping | - | Puts the node back to drawing normally. |

### The five mask modes

| Mode | What survives |
|---|---|
| `inside` | The item, only where the mask is solid. |
| `outside` | The item, only where the mask is clear - a hole punched through it. |
| `atop` | The mask's shape, painted with the item. |
| `behind` | The item, with the mask filling in everywhere the item is not. |
| `xor` | Whichever of the two is alone; where they meet, nothing. |

## Use cases

### 1. A muzzle flash that reads as light

```
On Fired -> Muzzle | Blend As: self, screen, 1.0
On Fired -> Muzzle | Fade Blend Strength: self, 0.0, 0.12
```

Screen never darkens anything, so the flash adds light instead of pasting a white blob over
the gun. The fade takes it away in a tenth of a second.

### 2. A scorch mark on the ground

```
On Explosion -> Scorch | Blend As: self, multiply, 1.0
```

Multiply can only darken, so the mark sits IN the floor texture rather than on top of it, and
the floor's own detail still shows through.

### 3. Recolour a sprite without flattening it

```
On Team Assigned -> Banner | Blend As: self, colour, 1.0
```

`colour` takes the hue and the strength of colour from the banner and keeps the brightness of
whatever is under it - every fold and shadow survives the recolour.

### 4. Drain the colour out of a defeated unit

```
On Defeated -> Enemy | Blend As: self, saturation, 1.0
On Defeated -> Enemy | Set Blend Strength: self, 0.0
```

A grey sprite blended by `saturation` pulls the colour out of what is under it. Strength 0 is
full colour, so fading it up is the unit greying out.

### 5. A grimy window pane

```
On start of layout -> Grime | Blend As: self, overlay, 0.6
```

Overlay deepens the shadows and brightens the highlights of the room behind the glass without
touching the midtones, which is exactly what dirt on glass does.

### 6. Heat haze over a fire

```
On start of layout -> Haze | Blend As: self, soft light, 0.35
```

Soft light nudges without ever hitting pure black or white, so the air over the fire shifts
rather than glares.

### 7. A scanner sweep that inverts what it passes

```
On Scan Started -> Sweep | Blend As: self, difference, 1.0
```

Difference cancels identical colours to black and pushes opposites bright - the classic
readout-sweep look, and it costs one row.

### 8. A spotlight that hides everything outside it

```
On Stealth Started -> Darkness | Mask With: self, spotlight_texture, outside
```

The darkness rectangle keeps only the part OUTSIDE the spotlight shape, so the lit circle is
a hole in the dark.

### 9. A torn-paper transition

```
On Level Cleared -> Curtain | Mask With: self, tear_texture, inside
On Level Cleared -> Curtain | Fade Blend Strength: self, 0.0, 0.8
```

The tear texture is the shape; fading the mask strength opens it.

### 10. A health bar that is a shape, not a rectangle

```
On start of layout -> HeartFrame | Clip My Children: clip only
On Health Changed -> Fill | Set width: Health Percent * 64
```

The frame is an invisible cutter; the plain rectangle sliding inside it is drawn as a heart
because the frame says so. No shader at all.

### 11. A portrait cut to its frame

```
On Portrait Shown -> Frame | Clip My Children: draw me too
```

The frame is both the shape AND drawn, so the border stays visible and the photograph inside
it cannot spill.

### 12. Water that stops at the edge of the pool

```
On start of layout -> PoolShape | Clip My Children: clip only
```

The pool shape is the cutter; the scrolling water texture under it is clipped to the pool's
outline however it moves.

### 13. Fade a character made of six sprites

```
On Vanish -> Character | Blend As One: self
On Vanish -> Character | Fade Opacity: 0.0 over 0.5
```

Without the first row, every sprite fades on its own and the overlaps show through each other
like a paper cut-out. Blended as one, the character fades as one picture.

### 14. A boss aura the whole arena feels

```
On Boss Enraged -> Aura | Blend As: self, colour dodge, 0.0
On Boss Enraged -> Aura | Fade Blend Strength: self, 1.0, 1.2
```

Colour dodge blows the light areas out fast, so the aura coming up over a second and a bit
reads as the room heating.

### 15. A shadow that only darkens

```
On start of layout -> Shadow | Blend As: self, darken, 1.0
```

Darken can never brighten a pixel, so the blob shadow works over grass, stone and water
without ever leaving a grey rectangle on the dark bits.

### 16. Ask what a thing is doing before changing it

```
Blend Mode Is: Sprite, screen -> Sprite | Blend As: self, normal, 1.0
```

The condition reads the same record the action wrote, so a toggle is two rows and no variable.

### 17. Turn a look off without losing it

```
On Quality Lowered -> Aura | Blend As: self, copy, 1.0
```

`copy` is a plain draw. The item keeps its material and its place in the scene; it just stops
reading the screen, which is the cheap setting for a low-end machine.

### 18. Mask one sprite with another sprite

```
On start of layout -> Reflection | Mask With Node: self, PuddleSprite, inside
```

The puddle's own texture is the shape, so moving or swapping the puddle changes where the
reflection is allowed to be, with no second texture to keep in step.

### Other use cases

**Damage flash that lights the enemy instead of whitening it.** A white sprite over the enemy blended `screen` at low strength reads as being lit rather than as a white silhouette.

**Ink-wash overlay for a paper level.** A paper texture blended `multiply` over the whole layer puts every sprite on the same sheet.

**Night-vision goggles.** A green rectangle blended `colour` keeps every shape readable while making the whole scene one hue.

**A wipe transition that is any shape at all.** `Mask With` on a full-screen rectangle, and the mask texture is whatever shape the game's identity wants.

**Frosted UI panel.** A soft-white panel blended `soft light` over the game leaves the menu legible without hiding what is behind it.

## Tips and common mistakes

- **Draw order decides everything.** A shader mode reads what has already been drawn. If the
  item draws first, there is nothing under it and the blend does nothing visible. Move it
  later in the tree, or raise its `z_index`.
- **One material per item.** If the item already wears a shader material of its own, `Blend
  As` refuses rather than throwing that shader away, and says so. Blend a parent or a child
  instead.
- **Strength is not opacity.** Opacity fades the item; strength fades how far the BLEND goes.
  A `screen` blend at strength 0.5 is still the whole sprite, half blended.
- **Native modes ignore strength.** There is no dial on a renderer field. Strength only
  reaches the fifteen shader modes.
- **Blend As One changes the tree.** It puts a `CanvasGroup` between the node and its
  children at run time. If the node is already a `CanvasGroup` in the scene, nothing is added
  and the condition still answers yes.
- **If it should ALWAYS be drawn that way, do it in the scene instead.** Open the Blend As One
  row's parameters and its node field offers **Draw <node>'s children as one** - one click puts
  the `CanvasGroup` in the scene, where it saves with the file and costs no row at all. It is a
  scene edit, so Ctrl+Z in the scene puts the children back.
- **Clip before you reach for a mask.** `Clip My Children` costs nothing and answers most of
  the "cut this to that shape" questions on its own.

## Already written it by hand? It reads as this pack

`material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD` reads as **Blend As: add** once the
pack is installed, and `clip_children = CanvasItem.CLIP_CHILDREN_ONLY` reads as **Clip My
Children, clip only** with nothing installed at all - that pair is built in.
