# Screen FX - Full-Screen Effects as Ordinary Rows

Screen FX is a Godot EventSheets pack for the effects that happen to the whole screen: a shockwave
ring from a point in the world, a fade to a colour you can wait on, a blur, and a chromatic pulse -
and on top of those, the **post stack**: a named list of full-screen effects drawn in order, nine of
them shipped, any of them one row away.

A full-screen effect in Godot is a CanvasLayer holding a ColorRect whose shader reads
`hint_screen_texture`. That is three nodes and a shader before a game gets its first flash of white,
which is why most projects never get one. This pack ships that scene. Adding it to an object drops
`screen_fx.tscn` into the scene, copies the shader into your project, and the four verbs are ordinary
rows from then on.

**Fade To is awaited**, which is the part worth knowing before anything else: the rows under it run
when the fade has landed. That is a scene transition, spelled as two rows in one event.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [The post stack](#the-post-stack)
5. [Looks - a whole screen as one file](#looks---a-whole-screen-as-one-file)
6. [Colour vision and reduced flashing](#colour-vision-and-reduced-flashing)
7. [ACE reference](#ace-reference)
8. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
9. [Use cases](#use-cases)
10. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Scene transitions.** Fade to black, change the scene, fade back, in one event.
- **Impacts.** A shockwave ring from the thing that exploded.
- **Pause menus.** Blur the world behind the menu, sharpen it when the menu closes.
- **Knockouts.** Blur and fade together as the player goes down.
- **Boss deaths.** A ring, a white fade, and the credits.
- **Hit feedback.** A chromatic pulse on the frame a big attack lands.
- **Cutscene punctuation.** A slow fade to white between beats.
- **Dream and underwater states.** A held blur while the state lasts.
- **Photo finishes.** A fade to white the frame a race is won.
- **Damage vignetting.** A held vignette that deepens as health falls.
- **Old-machine looks.** Scanlines, dither and a little grain, saved once as a look.
- **Cutscenes.** Letterbox bars walk in, the grade warms, the bars walk out.
- **Accessibility.** See As while you build, Correct Colours For behind a settings row.

---

## Core concepts

**One rectangle, four effects.** All four live in one shader on one ColorRect, so the screen is read
once per frame rather than once per effect.

**It costs nothing at rest.** A rectangle covering the viewport redraws every pixel of it through the
shader every frame. The pack hides the rectangle whenever every effect has finished and shows it again
the moment one starts, and a hidden Control is not drawn at all. The plugin's health checks look for
exactly the opposite shape - a visible screen rectangle with every dial at rest - so if you build your
own, hide it.

**The shockwave takes a world point.** `shockwave(Boss.position, 1.0)` is a ring where the boss is,
not where the ring's own coordinates happen to be. The camera transform is applied, so the ring stays
on the thing that caused it however the camera moves.

**Fade To and Fade Back wait.** Both are awaited rows: the event continues when the fade has landed.
Fade To goes to the colour, Fade Back comes from it, and a transition is one of each with the scene
change between them.

**Blur is a state, the others are moments.** Blur holds at whatever you set it to until something sets
it back. Shockwave and Chromatic Pulse time themselves out. Fade holds where it lands.

**Clear Screen Effects is the panic button.** It puts every dial back to rest at once, which is the
row a pause menu closing or a scene change wants.

---

## Setup

**1. Add the pack.** Right-click an object in the Object bar, **Add behavior**, Screen FX. Because
this pack ships a scene, that instantiates `screen_fx.tscn` rather than adding a bare node: a
CanvasLayer named `ScreenFx` with a hidden ColorRect named `Screen` under it, already wearing the
shader. Nothing is copied into the project, because the scene has dressed itself - which is the
difference between this pack and the five that go under a node.

**2. Move it if you want to.** A full-screen layer usually belongs at the root of the scene rather
than under one object. Drag it there; the rows carry an **On node** parameter, so point them at
wherever it ended up.

| Property | Default | What it does |
|---|---|---|
| `ring_seconds` | `0.55` | How long a shockwave ring takes to cross the screen. |

**3. Use it.**

```
On Boss Died
  -> ScreenFx: Shockwave at Boss.position, strength 1.0
  -> ScreenFx: Fade to black over 1.5 s
  -> change scene to Credits
```

The scene change runs when the fade has landed, because the fade row waits.

---

## The post stack

The four verbs above all live on ONE rectangle and one shader, which is what makes them cheap. The
post stack is the other half: a **named list** of effects, each with its own full-screen rectangle
and its own shader, drawn in the order the list holds them.

**One row is the whole thing.** `Pulse Post Effect  glitch  0.8  0.25` needs no setup: if the stack
does not hold a glitch it borrows one, flashes it, and gives it back. That is the jam form, and it is
the row to reach for first.

**Nine effects ship with the pack**, each one shader file beside the script:

| Word | What it looks like | Its own dials |
|---|---|---|
| `vignette` | The corners go dark, so the middle is where the eye goes. | `vignette_color`, `softness` |
| `film grain` | A fine moving speckle, the way film stock looks. | `grain_size`, `grain_speed` |
| `scanlines` | Dark horizontal lines, the way a tube television drew one. | `line_count`, `roll_speed` |
| `pixelate` | The picture resampled into big square blocks. | `pixel_size` |
| `colour grade` | Every colour looked up in an image and replaced. | `grade_table`, `lut_size` |
| `dither` | A few levels per channel, an ordered pattern deciding the rounding. | `levels`, `dot_size` |
| `fisheye` | The picture bulges out of the middle, or pinches into it. | `bulge`, `zoom` |
| `glitch` | Bands jump sideways and the colour channels come apart. | `band_height`, `jump`, `colour_split`, `glitch_speed` |
| `letterbox` | Solid bars close in from the top and the bottom. | `bar_depth`, `bar_colour`, `feather` |

Every one also has `strength`, which is the dial the rows turn: 0 hands the screen back untouched, 1
is the whole effect.

**Order is the look.** The first entry is applied to the screen first and the last one has the last
word. A colour grade UNDER a vignette grades the game; the same grade OVER it grades the vignette
too. **Move Post Effect Before** is how you say which.

**Names.** Add an effect without a name and it is called after itself, which is what one of each
wants. Give it a name (`Add Post Effect  vignette  danger  0.0`) when you want two of the same
effect, or when a later row should be able to find this one without knowing what it is.

**What it costs.** Every entry reads the whole screen back. That is one screen read per pixel of the
viewport, per entry that is on. Two or three is a look; nine is a bill, and the frame rate will say
so. **Post Effect Count** reads how many are drawing right now, which is the number to look at when
the frame rate has gone.

**It costs nothing at rest.** An entry whose strength is 0 hides its own rectangle, exactly the way
the first four effects hide theirs, and a hidden Control is not drawn at all.

**Where the stack draws.** The whole stack lives on the `ScreenFx` CanvasLayer, so anything on a
layer above it is untouched by every effect at once. **Draw Post Effects Below** and **Draw Post
Effects Above** take a CanvasLayer and put the stack on the right side of it: below keeps a health
bar sharp while the game behind it is graded, above puts the letterbox over everything. The Doctor
says so as a quiet note when a scene has an interface layer and no row has settled the question.

---

## Looks - a whole screen as one file

A **look** is the post stack written down: which effects, in which order, how far each one goes, and
what its own dials are set to. It is a `ScreenLookResource` - an ordinary Godot resource file.

**Nothing here is a preset.** This plugin ships no named looks and no dropdown of house styles. The
one file that comes with the pack is `clean.tres`, which holds no rows at all - the screen as the
game drew it. Every other look in your project is one you made.

**How a look is authored:**

1. Build it live. Add effects with rows until the screen is right.
2. **Save Look**, once, with a path and a name.
3. From then on, **Use Look** wears it and **Blend To Look** walks to it.

Edit it afterwards in the Inspector like any other resource, rename it, put it in version control,
send the file to somebody else. It is yours.

**Blend To Look crosses rather than cuts.** Effects both looks hold walk from one strength to the
other, effects only the old look had fade out and go, and effects only the new look has fade in from
nothing.

**A settings screen of looks** needs no seam of its own: point a Game Settings choice at a folder of
`.tres` files, and the row that applies the choice is `Use Look` with the chosen file. **Current
Look** reads back the name of the one on the screen, which is what a settings screen shows as the
current value, and **Look Is** is the condition for a rule that should only run under one of them.

---

## Colour vision and reduced flashing

**See As** is the designer's row. Turn it on, walk the level, and the health bar that vanishes into
the background is the bug you came to find. It simulates protanopia, deuteranopia or tritanopia;
`normal` takes it off again. The matrices are the usual published approximation of a thing that
varies between people, so it is a check rather than a certificate.

**Correct Colours For** is the player's row, and it belongs behind a settings choice rather than on
by default. It puts each colour through that same simulation, works out what would be lost, and
pushes that difference into the channels the viewer can still tell apart. The picture stops being
accurate and starts being readable, which is the trade the setting is making.

Both are ordinary stack entries under reserved names, so a look records them, Clear Look takes them
away, and Move Post Effect Before can put the correction last where it usually belongs.

**Reduced flashing is already a project-wide setting**, so this pack does not add a second one. The
built-in **Set No Flashing** action and **No Flashing** condition write and read the one answer the
whole project shares, and the post stack obeys it: every strength it is asked for is held under a
ceiling, and every walk it is asked for is held over a floor. A player who asked for no flashing
still gets the rows - the pulse pulses and the look lands - and nothing the stack draws can strobe.
The built-in **Set Effect Strength** dial scales every post strength too, so a player who turns
effects down turns these down with them.

---

## ACE reference

All rows carry an **On node** parameter (default `$ScreenFx`), so a project with a layer per viewport
picks which one it means.

### Actions

| Row | Parameters | What it does |
|---|---|---|
| **Shockwave** | `at` (Vector2, world point), `strength` (float, default `1.0`) | Sends a ring out from that point, travelling and fading over `ring_seconds`. |
| **Fade To** | `colour` (Color, default black), `seconds` (float, default `1.0`) | Fades the whole screen to the colour, and WAITS for it to land. |
| **Fade Back** | `colour` (Color, default black), `seconds` (float, default `1.0`) | Starts fully at the colour and fades back to the game, and waits. |
| **Blur** | `amount` (float, default `2.0`), `seconds` (float, default `0.3`) | Blurs the screen over a time. 0 is sharp again. |
| **Chromatic Pulse** | `strength` (float, default `0.6`), `seconds` (float, default `0.35`) | Pulls the colour channels apart and lets them snap back. |
| **Clear Screen Effects** | none | Ends every effect at once. |
| **Set Ring Seconds** | `value` (float) | How long a ring takes to cross. |
| **Add Post Effect** | `effect` (one of the nine words), `called` (String, default empty), `strength` (float, default `0.6`) | Adds one effect to the top of the post stack and turns it on. An empty name calls it after its effect. |
| **Pulse Post Effect** | `effect`, `strength` (float, default `0.6`), `seconds` (float, default `0.35`) | Turns an effect up and lets it fall back in one row, borrowing an entry and giving it back if the stack did not hold one. |
| **Remove Post Effect** | `called` (String) | Takes one entry off the stack and frees its rectangle, so it stops costing anything. |
| **Enable Post Effect** | `called` (String) | Turns one entry back on at the strength it already holds. |
| **Disable Post Effect** | `called` (String) | Turns one entry off without forgetting how far up it was. |
| **Set Post Strength** | `called` (String), `strength` (float, default `1.0`) | Sets how far one entry goes, at once. |
| **Fade Post Strength** | `called`, `to` (float), `seconds` (float, default `0.5`), `then_back_seconds` (float, default `0.0`) | Walks one entry's strength to a value over a time, and back again afterwards if a second time is given. |
| **Move Post Effect Before** | `called` (String), `before` (String, empty for last) | Moves one entry so it is drawn before another, which is what decides whose look wins. |
| **Draw Post Effects Below** | `other` (CanvasLayer) | Draws the whole post stack under that layer, so the interface on it stays sharp. |
| **Draw Post Effects Above** | `other` (CanvasLayer) | Draws the whole post stack over that layer, so the interface is graded along with the game. |
| **See As** | `vision` (normal / protanopia / deuteranopia / tritanopia) | Redraws the screen the way a player with that kind of colour blindness sees it. Normal takes it off. |
| **Correct Colours For** | `vision` (normal / protanopia / deuteranopia / tritanopia) | Redraws the screen so colours that would land on top of each other can be told apart. Normal takes it off. |
| **Save Look** | `path` (file path), `called` (String) | Writes the live stack out as a look file: every entry, in order, with its strength and its own dials. |
| **Use Look** | `look` (ScreenLookResource) | Wears a look at once: the stack becomes exactly what the look says, in its order. |
| **Blend To Look** | `look` (ScreenLookResource), `seconds` (float, default `1.0`) | Walks from the look on the screen to another one, crossing rather than cutting. Awaited. |
| **Clear Look** | none | Takes every effect off the stack and puts the screen back the way the game drew it. |

### Conditions

| Row | What it answers |
|---|---|
| **Screen Effect Is Running** | True while any effect is running - a fade held on, a blur, a ring still travelling. |
| **Post Effect Is On** | True while that entry is on the stack, enabled and actually drawing something. |
| **Look Is** | True while that look is the one on the screen, compared by the look's own name. |

### Expressions

| Row | What it reads |
|---|---|
| **Ring Seconds** | How long a shockwave takes to cross the screen. |
| **Post Strength** | How far one entry currently goes, 0 to 1, after the accessibility dials have had their say. |
| **Post Effect Count** | How many post effects are drawing right now - the number to look at when the frame rate has gone. |
| **Current Look** | The name of the look on the screen, or empty when the stack was built row by row. |
| **Post Effect Words** | Every effect word the stack knows, so a settings screen can list them without a second copy. |

### The shader's own dials

| Dial | Type | Starts at | What it is |
|---|---|---|---|
| `blur` | 0 to 6 | `0.0` | How far the blur reaches. |
| `fade_color` | colour | black | The colour the screen fades towards. |
| `fade_amount` | 0 to 1 | `0.0` | How far it has faded. |
| `shock_center` | vector | `(0.5, 0.5)` | Where the ring started, in screen coordinates. |
| `shock_radius` | 0 to 2 | `0.0` | How far the ring has travelled. |
| `shock_strength` | 0 to 1 | `0.0` | How hard the ring pushes. |
| `chromatic` | 0 to 1 | `0.0` | How far the colour channels are pulled apart. |

---

## Reading it from expressions - the Self section

Type `self` into any ƒx field on the layer and its members insert as `$ScreenFx.` chains:
`$ScreenFx.screen_effect_is_running()` as a condition on a rule that should hold off while a
transition is in flight, `$ScreenFx.ring_seconds` where a timer should match the ring.

---

## Use cases

Each example targets the `ScreenFx` layer.

### 1. Scene transition, both halves

```
On Exit Reached
  -> ScreenFx: Fade to black over 0.6 s
  -> change scene to NextLevel
  -> ScreenFx: Fade back from black over 0.6 s
```

Every row after a fade runs when that fade has landed, which is why this reads top to bottom.

### 2. Boss death

```
On Boss Died
  -> ScreenFx: Shockwave at Boss.position, strength 1.0
  -> ScreenFx: Fade to white over 2.0 s
  -> change scene to Credits
```

### 3. Explosion ring

```
On Barrel Exploded
  -> ScreenFx: Shockwave at Barrel.position, strength 0.8
```

The world point is the whole argument; the ring lands on the barrel.

### 4. Ring strength from distance

```
On Explosion
  -> ScreenFx: Shockwave at Blast.position, strength clampf(1.0 - Player.position.distance_to(Blast.position) / 600.0, 0, 1)
```

A blast far away barely moves the screen, which is what makes a near one feel near.

### 5. Pause blur

```
On Pause Pressed
  -> ScreenFx: Blur to 3 over 0.2 s
On Pause Closed
  -> ScreenFx: Blur to 0 over 0.2 s
```

### 6. Knocked out

```
On Player Died
  -> ScreenFx: Blur to 5 over 1.2 s
  -> ScreenFx: Fade to Color(0.2, 0, 0) over 1.5 s
  -> show game over screen
```

### 7. Big hit landed

```
On Heavy Attack Connected
  -> ScreenFx: Chromatic pulse at 0.7
```

### 8. Chained hits, escalating

```
On Combo Increased  -> count
  -> ScreenFx: Chromatic pulse at clampf(count / 10.0, 0.2, 1.0)
```

### 9. Low health vignette

```
On Health Changed
  Condition: Player.hp / Player.max_hp  <  0.25
    -> ScreenFx: Fade to Color(0.5, 0, 0, 0.35) over 0.4 s
  Else
    -> ScreenFx: Fade to Color(0.5, 0, 0, 0.0) over 0.4 s
```

The fade colour's own alpha limits how far the fade can go, so a red wash can hold at a quarter.

### 10. Underwater blur

```
On Entered Water
  -> ScreenFx: Blur to 1.5 over 0.5 s
On Left Water
  -> ScreenFx: Blur to 0 over 0.5 s
```

### 11. Cutscene punctuation

```
On Beat Ended
  -> ScreenFx: Fade to white over 0.4 s
  -> set up next beat
  -> ScreenFx: Fade back from white over 0.4 s
```

### 12. Do not start a transition inside a transition

```
On Exit Reached
  Condition: NOT ScreenFx: Screen Effect Is Running
    -> ScreenFx: Fade to black over 0.6 s
    -> change scene to NextLevel
```

### 13. Panic button when a menu closes

```
On Menu Closed
  -> ScreenFx: Clear Screen Effects
```

### 14. A faster ring for a small game

```
On Ready
  -> ScreenFx: Set Ring Seconds  0.3
```

### 15. Landing impact from the player's own feet

```
On Landed From Height  -> fall_distance
  Condition: fall_distance  >  200
    -> ScreenFx: Shockwave at Player.position, strength 0.5
```

### 16. A hit that costs one row

```
On Player Hurt
  -> ScreenFx: Pulse glitch at 0.7 for 0.2 s
```

Nothing was added, nothing has to be cleaned up, and the screen is exactly as it was afterwards.

### 17. A vignette that deepens as health falls

```
On Ready
  -> ScreenFx: Add vignette at 0.0
Every tick
  -> ScreenFx: Set vignette strength to (1 - Player.health / 100) * 0.7
```

### 18. Keep the interface out of it

```
On Ready
  -> ScreenFx: Draw post effects below Hud
```

One row, and every effect for the rest of the game leaves the health bar alone.

### 19. Cutscene bars

```
On Cutscene Started
  -> ScreenFx: Add letterbox at 0.0
  -> ScreenFx: Fade letterbox to 1.0 over 0.6 s
On Cutscene Ended
  -> ScreenFx: Fade letterbox to 0.0 over 0.6 s
  -> ScreenFx: Remove post effect letterbox
```

### 20. An old-machine look, saved once

```
On Debug Key Pressed
  -> ScreenFx: Add scanlines at 0.4
  -> ScreenFx: Add dither at 0.6
  -> ScreenFx: Add film grain at 0.2
  -> ScreenFx: Save the look as user://looks/old_machine.tres
```

Run it once while you tune the numbers, then delete the event and use the file.

### 21. Wearing that look on start

```
On Ready
  -> ScreenFx: Use the look OldMachine
```

### 22. Crossing between two looks at nightfall

```
On Night Fell
  -> ScreenFx: Blend to the look Night over 4.0 s
On Day Broke
  -> ScreenFx: Blend to the look Day over 4.0 s
```

### 23. Underwater, held for as long as it lasts

```
On Entered Water
  -> ScreenFx: Add fisheye at 0.5
  -> ScreenFx: Add colour grade at 0.8
On Left Water
  -> ScreenFx: Remove post effect fisheye
  -> ScreenFx: Remove post effect colour grade
```

### 24. The grade goes under the vignette, not over it

```
On Ready
  -> ScreenFx: Add vignette at 0.4
  -> ScreenFx: Add colour grade at 1.0
  -> ScreenFx: Draw colour grade before vignette
```

### 25. A dying machine

```
On Reactor Failing
  -> ScreenFx: Add glitch at 0.0
  -> ScreenFx: Fade glitch to 0.9 over 8.0 s
```

### 26. Pausing without a second overlay

```
On Menu Opened
  -> ScreenFx: Add pixelate at 0.5
On Menu Closed
  -> ScreenFx: Remove post effect pixelate
```

### 27. Checking your own colours while you build

```
On Key F9 Pressed
  -> ScreenFx: See as deuteranopia
On Key F10 Pressed
  -> ScreenFx: See as normal
```

### 28. The player's own colour setting

```
On Colour Setting Changed  -> choice
  -> ScreenFx: Correct colours for  choice
```

### 29. Do not stack a second one on top

```
On Big Hit
  Condition: NOT ScreenFx: vignette is on
    -> ScreenFx: Pulse vignette at 0.8 for 0.3 s
```

### 30. Watch what the stack is costing

```
Every 1.0 seconds
  Condition: ScreenFx: Post Effect Count  >  4
    -> print "the post stack is drawing " & ScreenFx.Post Effect Count & " effects"
```

### Other use cases

**Photo finish.** A race won fades to white over two frames and back over half a second, so the
winning moment is punctuated rather than narrated.

**Rhythm game downbeat.** A very small chromatic pulse on every bar keeps the screen breathing with
the music without ever getting in the way.

**Teleport arrival.** A ring centred on the destination the frame the player appears, so the arrival
has weight.

**Dream sequences.** A held blur at about 1 for the length of the sequence, cleared on waking, reads
as memory without a filter over the art.

**Loading covers.** Fade to black, load, fade back - and because both halves wait, the load never
shows a half-faded frame.

---

## Tips and common mistakes

- **Put the layer where a layer belongs.** Adding the pack drops it under the object you picked. A
  full-screen effect usually wants to be at the root of the scene, or in an autoload scene if it
  should survive scene changes.
- **Fade To waits, and that is the feature.** If you do not want to wait, do not use Fade - set
  `effect.fade_amount` from a dial row instead.
- **Fade Back starts fully faded.** It sets the fade to 1 and walks it down, so calling it on a clear
  screen will flash the colour first. Use it as the second half of a transition.
- **Blur holds.** Nothing turns it off but a row. That is deliberate, because underwater is a state.
- **The ring is in world coordinates.** Pass `SomeNode.position`, not a screen position. The camera
  transform is applied for you.
- **The rectangle hides itself, so do not hide it yourself.** Setting `visible` by hand fights the
  pack's own switch and will surprise you the next time an effect starts.
- **One layer is usually enough.** Every effect shares the rectangle, so there is no reason for a
  second unless you have a second viewport.
- **To change what the effects look like, make the scene yours.** The layer is an instance of
  `screen_fx.tscn`, which lives in the pack and belongs to the pack. Right-click the node and turn on
  **Editable Children** to change one project's layer, or copy `screen_fx.gdshader` into your own
  folder and point a new material at it if you want a shader an update cannot touch. This is the one
  place the effect packs differ: the five that go under a node copy their shader into `res://effects/`
  for you, because there is no scene of theirs to own it.
- **A blur above about 4 shows the mip levels.** That is the technique, not a bug; keep it low for
  realism and high for dreams.
- **A post effect reads the whole screen.** One is cheap, three is a look, nine is a bill. Post
  Effect Count is the number to check when the frame rate has gone.
- **Say which side of the interface the stack draws on, once.** Otherwise it is decided by two layer
  numbers that were picked for other reasons, and you find out when your health bar goes dark.
- **Order decides the look.** Two entries in the other order are a different picture. Move Post
  Effect Before is how you say which, and the row reads as the sentence it is.
- **A pulse gives back what it borrowed.** It is safe to fire from a rule that runs often, because it
  leaves the stack exactly as it found it - unless you asked for zero seconds, which is a set.
- **A look is your file, not a preset.** Nothing here ships a named style. Build one live, save it,
  and it belongs to your project like any other resource. The only one that comes with the pack is
  the empty Clean.
- **A colour grade needs its table before it does anything.** With no image assigned, `lut_size`
  rests at 0 and the effect hands the screen back untouched however far up its strength is. That is
  deliberate: mapping every pixel through a blank image would paint the screen white.
- **Reduced flashing is not this pack's setting.** Use the built-in Set No Flashing row; the stack
  reads it and holds every amplitude and every rate under it for you.
