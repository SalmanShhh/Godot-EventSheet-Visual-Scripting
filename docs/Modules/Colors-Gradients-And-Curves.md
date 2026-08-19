# Colors, Gradients And Curves

**Colors, Gradients And Curves** is the builtin vocabulary for making a colour out of another colour,
and for reading a smooth value out of a shape somebody drew.

Seven **Color** expressions cover the everyday colour maths a game needs - a hit flash, a fade, a
rarity tint, a health bar that runs green to red - without dropping to GDScript and without mixing
channels by hand. Three **Gradients & Curves** rows cover the smooth cases: build a quick two-colour ramp at
runtime, and sample any gradient or curve at a 0-to-1 position.

Every colour parameter is a full expression, which is what makes them compose: a literal, the node's
own `modulate`, or another colour expression all drop into the same cell. `Lighten Color(Lerp Color(base,
Color(1, 0, 0, 1), damage), 0.3)` is one legal cell.

Everything compiles to plain Godot with zero plugin references: *lighten `modulate` by `0.2`* ships
as `(modulate).lightened(0.2)`.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Authoring a rich gradient or curve](#authoring-a-rich-gradient-or-curve)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Hit flashes** - a lightened tint for a few frames and back.
- **Fades** - in, out, and partway, without touching the RGB channels.
- **Health bars** that run green through yellow to red as one sampled ramp.
- **Rarity and faction tints** built from one hex string per tier.
- **Hover and pressed states** - the same colour, a little lighter or darker.
- **Day / night skies** driven by one gradient and a clock.
- **Heat maps and danger overlays** where a 0-to-1 number becomes a colour.
- **Designer-drawn difficulty curves** - a spawn rate that ramps the way somebody drew it, not the
  way an equation does.
- **Eased motion** without picking a tween easing from a list.
- **Falloff** - light, damage, sound and shake that fade with distance along a shaped curve.
- **Rainbow and hue-cycling effects** from one hue value driven by time.

## Core concepts

- **Colours are values.** Every Color row here is an EXPRESSION - it hands back a new colour and
  changes nothing. To put one on screen, feed it to something that takes a colour: the builtin
  Set Color Tint / Set Self Tint actions, a Label's font colour, a shader parameter.
- **Channels are 0 to 1, not 0 to 255.** `Color(1, 0, 0, 1)` is opaque red. Color From Hex is the
  escape hatch when you have `#ff8800` from a designer.
- **Lightened and darkened are not brightness knobs.** Lighten Color moves the colour a fraction of
  the way toward WHITE; Darken Color moves it toward BLACK. Both take a 0-to-1 amount, so 0 is
  no change and 1 is pure white or pure black.
- **Alpha is separate from colour.** Color With Alpha replaces only the transparency and leaves RGB
  alone, which is the whole of a fade.
- **A gradient is a ramp; a curve is a shape.** Sample either one at a position from 0 to 1. A
  Gradient hands back a Color, a Curve hands back a number.
- **Position is normalized, not "seconds" or "pixels".** Convert first: `elapsed / duration`,
  `distance / max_distance`, `health / max_health`. The builtin Progress Of expression is exactly that
  conversion with the clamp already applied.
- **Make Gradient is the quick two-colour case.** For a ramp with more than two stops, give a sheet
  variable the Gradient type and edit it in the Inspector with Godot's own ramp editor - the same is
  true of Curve and its curve editor.
- **Make Gradient is the only ACTION here.** It builds into a variable, which the other two then
  read.

## Reference tables

On the canvas these read as sentences with the values drawn in place: *lighten `modulate` by `0.2`*,
*lerp `Color(0, 1, 0, 1)` to `Color(1, 0, 0, 1)`*, *sample `ramp` at `0.5`*.

### Color

| Name | What it does | Ships as |
|------|--------------|----------|
| Lighten Color | The colour shifted toward white by a 0-to-1 amount. | `({color}).lightened({amount})` |
| Darken Color | The colour shifted toward black by a 0-to-1 amount. | `({color}).darkened({amount})` |
| Lerp Color | Two colours blended by a 0-to-1 weight, for smooth colour fades. | `({from}).lerp({to}, {weight})` |
| Color With Alpha | The colour with a new transparency, RGB untouched. | `Color({color}, {alpha})` |
| Color From HSV | A colour built from hue, saturation, value and alpha - each 0 to 1. | `Color.from_hsv({h}, {s}, {v}, {a})` |
| Color From Hex | A colour from an HTML hex string like `#ff8800`. | `Color.html({hex})` |
| Invert Color | The opposite colour, for highlights and negative effects. | `({color}).inverted()` |

### Gradients & Curves

| Name | What it does | Ships as |
|------|--------------|----------|
| Make Gradient | ACTION: builds a smooth two-colour ramp into a Gradient-typed variable at runtime. | `var __grad_{uid} := Gradient.new()` then `__grad_{uid}.set_color(0, {from})`, `__grad_{uid}.set_color(1, {to})`, `{var_name} = __grad_{uid}` |
| Sample Gradient | The colour at a 0-to-1 position along a gradient. 0 is the first colour, 1 is the last. | `{gradient}.sample({position})` |
| Sample Curve | A curve's value at a 0-to-1 position. 0 is the curve's start, 1 is its end. | `{curve}.sample_baked({position})` |

## Authoring a rich gradient or curve

Make Gradient covers two stops. Anything richer is authored, not built:

1. Add a sheet variable and give it the **Gradient** type (or **Curve**).
2. Select it and edit it in the Inspector. Godot shows its own editors - the ramp with draggable
   colour stops, and the curve editor with draggable points and tangents.
3. Sample it from any row with Sample Gradient or Sample Curve.

That is the whole workflow, and it is why the sampling expressions take a **variable reference** rather
than a literal: the ramp or the curve is a thing a designer owns and edits, and the sheet only reads
it.

A Curve is the honest answer to "I want this to ramp up, but not linearly, and not with any of the
named easings either". Draw the shape, sample it, and the tuning conversation stops being about
exponents.

## Use cases

**1. A hit flash.**

```
On hit
  -> Set Color Tint  Lighten Color(Color(1, 1, 1, 1), 0.6)
  -> Wait 0.08 seconds
  -> Set Color Tint  Color(1, 1, 1, 1)
```

**2. A pressed state that is just the same colour, darker.**

```
On button pressed
  -> Set Color Tint  Darken Color(base_color, 0.25)
On button released
  -> Set Color Tint  base_color
```

Deriving the state from one base colour means a re-skin edits one value instead of three.

**3. A health bar that runs green to red.**

```
Every tick
  -> set HealthBar.modulate = Lerp Color(Color(1, 0, 0, 1), Color(0, 1, 0, 1), Progress Of(health, 0.0, max_health))
```

Progress Of gives a clamped 0-to-1 reading, which is exactly what Lerp Color's weight wants.

**4. A fade out that does not touch the colour.**

```
Every tick
  -> set fade = fade - delta
  -> Set Color Tint  Color With Alpha(modulate, Progress Of(fade, 0.0, 1.0))
```

Color With Alpha replaces only the transparency, so a tinted sprite fades without turning grey.

**5. A fade in on spawn.**

```
On spawned
  -> Set Color Tint  Color With Alpha(Color(1, 1, 1, 1), 0.0)
  -> tween modulate to Color(1, 1, 1, 1) over 0.4 seconds
```

**6. Rarity colours from one hex string per tier.**

```
On item shown
  Condition: rarity = "legendary"
    -> set NameLabel.modulate = Color From Hex("#ff8800")
  Condition: rarity = "rare"
    -> set NameLabel.modulate = Color From Hex("#3388ff")
```

Hex is the format a designer hands you, so no conversion step goes wrong in between.

**7. A hue that cycles.**

```
Every tick
  -> Set Color Tint  Color From HSV(fmod(Game Time(), 3.0) / 3.0, 0.8, 1.0, 1.0)
```

Hue wraps at 1, so dividing a repeating 0-to-3 second clock by 3 gives one full rainbow every three
seconds.

**8. A team colour with a fixed hue and a varying brightness.**

```
On unit spawned
  -> Set Color Tint  Color From HSV(team_hue, 0.7, 0.6 + 0.4 * unit_rank / 5.0, 1.0)
```

HSV is the right space for this - the same job in RGB means changing all three channels together.

**9. A highlight that is guaranteed to contrast.**

```
On selection changed
  -> set OutlineRect.modulate = Invert Color(background_color)
```

**10. Build a fire ramp at runtime.**

```
On Ready
  -> Make Gradient  into fire_ramp, from Color From Hex("#ffee88"), to Color From Hex("#cc2200")
```

It emits a real Gradient into the variable:

```gdscript
extends Node


var __grad_a1 := Gradient.new()
__grad_a1.set_color(0, Color.html("#ffee88"))
__grad_a1.set_color(1, Color.html("#cc2200"))
fire_ramp = __grad_a1
```

**11. Sample that ramp over a particle's life.**

```
Every tick
  -> Set Color Tint  Sample Gradient(fire_ramp, Progress Of(age, 0.0, lifetime))
```

**12. A day / night sky from one authored gradient.** Give `sky_ramp` the Gradient type, drag in as
many stops as the day needs (dawn, noon, dusk, midnight), then:

```
Every tick
  -> set SkyRect.modulate = Sample Gradient(sky_ramp, time_of_day / 24.0)
```

Retinting the whole day is now a designer dragging stops, with no rows to touch.

**13. A heat map cell.**

```
For Each cell in grid
  -> set cell.modulate = Sample Gradient(danger_ramp, Progress Of(cell_threat, 0.0, max_threat))
```

**14. A difficulty curve somebody drew.** Give `difficulty` the Curve type and shape it in the
Inspector, then:

```
Every Ramped(2.0, -0.3, 0.5) seconds
  -> spawn "res://enemy.tscn" at spawn_point
  -> set enemy_health = base_health * Sample Curve(difficulty, Progress Of(run_seconds, 0.0, 600.0))
```

**15. Falloff with distance.**

```
Every tick
  -> set shake_strength = max_shake * Sample Curve(falloff, Progress Of(Distance Between(self.position, blast.position), 0.0, blast_radius))
```

Draw the falloff steep at the start and long in the tail, and the shake feels right without a single
exponent in the sheet.

**16. Eased motion with no named easing.**

```
Every tick
  -> set door.position = Vector Lerp(closed_position, open_position, Sample Curve(open_curve, Progress Of(open_time, 0.0, 0.6)))
```

The curve IS the easing, which means it can be tuned by looking at it.

**17. A charge meter that changes colour as it fills.**

```
Every tick while fire held
  -> Charge Toward  power, up to 100.0, over 1.5 seconds
  -> set ChargeBar.modulate = Sample Gradient(charge_ramp, Progress Of(power, 0.0, 100.0))
```

**18. A disabled control, derived rather than authored.**

```
On button disabled
  -> Set Color Tint  Color With Alpha(Darken Color(base_color, 0.4), 0.5)
```

Darker AND more transparent, from the one base colour, in one cell.

### Other use cases

**Damage-number colouring.** Lerp Color from white to red by the hit's fraction of max health, so a
big hit reads as red without a single threshold value in the sheet.

**Minimap ownership.** One HSV hue per faction and a fixed saturation and value gives every faction a
distinct marker colour from a single number stored on the faction.

**Terrain height tinting.** Sample an authored gradient at the normalized height of each tile, and a
whole map colours itself from one ramp a designer can redraw.

**Alarm pulse.** Sample a curve at a looping 0-to-1 clock and feed the result to Color With Alpha, so
the pulse shape is drawn rather than approximated with a sine.

**Screen-flash accessibility toggle.** Keep the flash colour in one variable and pass it through
Darken Color by a player-set amount, so a photosensitivity option is one slider and no extra rows.

## Tips and common mistakes

- **Amounts are 0 to 1, and so are channels.** `Lighten Color(c, 50)` is not "50 percent" - anything
  above 1 pushes the colour past white. Likewise `Color(255, 0, 0, 1)` is not red; it is a very
  out-of-range value. Use Color From Hex when your source is a `#rrggbb` string.
- **Lightened is not the same as raising Value in HSV.** Lightening mixes toward white and washes the
  saturation out; raising V keeps the hue pure. Pick the one that matches what you meant.
- **Nothing here changes anything on screen by itself.** Every Color expression hands back a value.
  Feed it to Set Color Tint, Set Self Tint, a font colour or a shader parameter.
- **Set Color Tint affects children; Set Self Tint does not.** Fading a whole panel and fading only
  its background are different actions, and confusing them is why "the fade also faded my text".
- **Color With Alpha writes over the alpha you had.** It does not multiply. Fading something already
  half-transparent back to 1.0 makes it fully opaque.
- **Sample position is 0 to 1.** Handing Sample Gradient a raw health value or a seconds count reads
  off the end of the ramp and returns the last colour forever - the effect looks "stuck" rather than
  broken. Convert with Progress Of.
- **Sample Curve uses the baked cache.** That is the fast path, and it means a Curve edited from code
  at runtime may need baking before the samples follow; a Curve authored in the Inspector is already
  baked and needs nothing.
- **A Curve is not clamped to 0-to-1 in its OUTPUT.** Its min and max values are properties on the
  resource, so a curve drawn between 0 and 5 samples up to 5. Check the curve's range before
  multiplying by it.
- **Make Gradient replaces the variable's whole gradient.** It builds a fresh two-stop Gradient every
  time it runs, so calling it per frame throws away an authored multi-stop ramp and allocates
  needlessly. Build once, on start.
- **Make Gradient needs a Gradient-typed variable to build into.** Pointing it at an untyped variable
  works, but nothing downstream will know what it holds, and the Inspector will not offer the ramp
  editor.
- **For more than two stops, author it, do not build it.** The Inspector's ramp editor is the tool;
  Make Gradient exists for the runtime case where the two colours are not known until the game runs.
- **Color From Hex wants a valid HTML string.** A malformed one does not fall back to your intent -
  check the string when it comes from data rather than from a literal.
