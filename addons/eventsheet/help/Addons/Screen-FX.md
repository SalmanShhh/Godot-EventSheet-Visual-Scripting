# Screen FX - Full-Screen Effects as Four Ordinary Rows

Screen FX is a Godot EventSheets pack for the effects that happen to the whole screen: a shockwave
ring from a point in the world, a fade to a colour you can wait on, a blur, and a chromatic pulse.

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
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

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
- **Damage vignetting.** A held colour fade at low health.

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

### Conditions

| Row | What it answers |
|---|---|
| **Screen Effect Is Running** | True while any effect is running - a fade held on, a blur, a ring still travelling. |

### Expressions

| Row | What it reads |
|---|---|
| **Ring Seconds** | How long a shockwave takes to cross the screen. |

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
