# Juice - Screenshake, Recoil, Head Bob, Zoom, Squash, Slowmo and Hitstop in One Behavior

Juice is a Godot EventSheets behavior pack that adds game feel to a scene without a line of tween code. You attach a `JuiceBehavior` to a node - a sprite, the player, a UI panel, anything drawn on screen - and that node gains a toolbox of camera and squash effects you fire straight from event rows. The host must be a `CanvasItem` (that means a `Node2D` like a sprite, or a `Control` like a UI panel). Camera effects (Shake, Zoom) find the active `Camera2D` on their own, so Shake and Zoom "just work" from wherever you place the behavior with no path to wire. Squash effects animate the node the behavior is attached to. Slowmo and Hitstop drive `Engine.time_scale` globally. Every effect is fire-and-forget and, where it has a lifetime, ends by emitting an "On X Finished" trigger so you can chain the next beat.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [Moments - a whole beat in one row](#moments---a-whole-beat-in-one-row)
5. [ACE reference](#ace-reference)
6. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
7. [Use cases](#use-cases)
8. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Impact feedback on every hit.** Fire Shake with a small strength each time a bullet lands or an enemy takes damage; the trauma stacks and decays on its own so a burst of hits reads as a rising, settling rumble.
- **Platformer jump and land.** Spring Squash the character tall as it leaves the ground and squash it wide the frame it touches down, so a plain jump gains weight.
- **Finisher slow motion.** Slowmo the whole game to a crawl for a beat on a killing blow or a perfect dodge, then let it ease back to normal on its own.
- **Punchy melee hits.** Hitstop the game for a few frames the instant a sword connects, the brief freeze that makes a blow feel like it landed.
- **Cinematic zoom-ins.** Zoom By Percent to punch the camera in on a special move or a dramatic line, then zoom back out when it finishes.
- **Framing a spot.** Zoom To Position glides the camera so a boss door, a treasure, or a cutscene actor becomes the screen centre in one action.
- **Strategy and map zoom.** Zoom Toward Point keeps the world point under the cursor pinned as you zoom, the mouse-wheel-to-cursor feel players expect from a map view.
- **UI that feels alive.** Attach the behavior to a `Control` and Spring Squash a button when it is pressed or a panel when it pops open.
- **Explosions and screen kicks.** Scale Shake strength by distance to the blast so a nearby explosion rocks the camera and a far one barely nudges it.
- **Chained beats.** React to On Hitstop Finished or On Slowmo Finished to sequence a hit-pause into a slow-motion follow-through without a timer.
- **Split-screen and custom rigs.** Use Camera pins the effects to one specific `Camera2D` when the auto-found camera is not the one you want.
- **HUD rumble readouts.** Read the Trauma expression to drive a controller-rumble strength or a shaking HUD element that matches the camera.

---

## Core concepts

The pack is small. Learn these ideas and every ACE falls into place.

**The node is where you attach, the camera is found for you.** You drop a `JuiceBehavior` on a node and place all its ACEs on that node. Shake and the three Zoom actions do not care which node holds the behavior: they act on the active `Camera2D` (`get_viewport().get_camera_2d()`), found automatically. So you can put Juice on your player and still shake the camera. The squash actions are the exception: they scale the host node itself, so put the behavior on the thing you want to pop.

**Screenshake is trauma-based and additive.** Shake does not set a shake amount, it adds `strength` (0 to 1) to a hidden trauma value that then decays every second. The camera offset and roll are driven from trauma squared, so the shake ramps in perceptually and eases out as trauma bleeds off. Because it is additive on top of the camera's own offset and rotation, it composes with a follow camera instead of fighting it. Fire a little Shake on each hit and it stacks and settles by itself. When trauma reaches zero, On Shake Stopped fires.

**The Inspector knobs are the feel.** You tune how the effects look in the Inspector, not in the event rows. `max_offset`, `max_roll_degrees`, `shake_decay` and `shake_frequency` shape the shake; `min_zoom` and `max_zoom` clamp every zoom; the `slowmo_fade_*` knobs and the `squash_stiffness` / `squash_damping` knobs shape slowmo ramps and the spring bounce. The action rows carry only the "what and how much" - the "how it feels" lives on the node.

**Zoom comes in three flavors.** All three read a `percent` where 100 means no change, 150 means zoom in to 1.5x, and 50 means zoom out to half, and all three clamp the result to `min_zoom` / `max_zoom`. Zoom By Percent just changes the zoom. Zoom To Position also glides the camera so a world point ends up centred. Zoom Toward Point keeps a world point pinned under the same screen spot as it zooms (the cursor-anchored feel). Each ends with On Zoom Finished.

**Squash and stretch is volume-preserving, in two flavors.** Both take a `stretch`: positive stretches the host tall (a jump), negative squashes it wide (a landing), and the other axis compensates so the shape keeps its volume. Squash & Stretch uses a tween that springs back elastically over a `duration` you pass. Spring Squash uses a real spring driven by the `squash_stiffness` and `squash_damping` knobs, so it is bouncier and more organic and takes no duration - it settles on its own. Both end with On Squash Finished. On a `Control`, the pivot is centred for you so the pop reads from the middle.

**Slowmo ramps in, holds, then ramps out.** Slowmo eases `Engine.time_scale` down to your `target_scale`, holds it for `hold_duration`, then eases it back to 1.0. The ramp lengths and curves are Inspector knobs (`slowmo_fade_in_secs`, the trans/ease enums, and so on), separate from the hold. The `duration_clock` you pass picks whether the hold is measured in `realtime` (unaffected by the slowdown) or `gametime` (scaled). It emits On Slowmo Finished when it returns to normal. Clear Slowmo cancels it and snaps back to 1.0.

**Hitstop is a hard, brief freeze.** Hitstop slams `Engine.time_scale` to `freeze_scale` (0 is a full stop) for `freeze_duration`, then restores whatever the time scale was before. It runs on a realtime timer, so it un-freezes even at a full stop; it ignores a repeat call while already frozen; and it pauses any running Slowmo for the freeze so the two do not fight. It emits On Hitstop Finished. This is the tiny pause you feel on a connecting blow.

**Effects are fire-and-forget and announce when they end.** You never hold or await an effect. You fire it and, if you want to sequence the next beat, react to its finished trigger: On Shake Stopped, On Zoom Finished, On Squash Finished, On Slowmo Finished, On Hitstop Finished. That is how you chain a hitstop into a slowmo, or a zoom-in into a zoom-out.

---

## Setup

**1. Attach the behavior.** Add a `JuiceBehavior` as a child of the node you want to affect. Put it on the player (or any node) for camera Shake and Zoom; put it on the exact sprite or `Control` you want to pop for Squash. The host must be a `CanvasItem`, which every `Node2D` and every `Control` is. Camera effects need an active `Camera2D` somewhere in the scene.

**2. Tune the feel in the Inspector.** Select the behavior node and set the knobs (all have sensible defaults):

| Property | Default | What it does |
|---|---|---|
| `max_offset` | `(24, 16)` | Peak camera shake offset in pixels at full trauma. |
| `max_roll_degrees` | `3.0` | Peak camera roll (rotation) in degrees at full trauma. |
| `shake_decay` | `1.4` | Trauma lost per second - higher means shorter, snappier shakes. |
| `shake_frequency` | `25.0` | How fast the shake jitter scrolls. |
| `min_zoom` | `0.2` | Clamp: the most zoomed-out any zoom may go. |
| `max_zoom` | `5.0` | Clamp: the most zoomed-in any zoom may go. |
| `squash_stiffness` | `250.0` | Spring Squash stiffness - higher snaps back faster. |
| `squash_damping` | `0.6` | Spring Squash damping - lower is bouncier. |

**3. Fire an effect.** Here is a complete first setup - a shake on every hit, with a squash on the player when it lands:

```
On Player Damaged
  -> Player | JuiceBehavior: Shake  0.4

On Player Landed
  -> Player | JuiceBehavior: Spring Squash  -0.4
```

Shake adds trauma to the auto-found camera and it decays by itself; Spring Squash pops the player node wide and springs it back. No timers, no tweens, no cleanup.

---

## Moments - a whole beat in one row

A hit does not feel like a hit because of one effect. It feels like a hit because four things happen
at once: the camera kicks, time stops for a few frames, the colour splits, and the edges of the
screen darken. Writing those four rows out is easy. Writing them out again in the ten other places
something can be hit, and keeping all ten in step when the feel changes, is not.

A **moment** is that beat written down once, as a file. It is a list of steps - each step one word,
how much, and how long - and the **Moment** action plays it:

```
On Enemy Hit
  -> Enemy | JuiceBehavior: Moment  "impact"  1.0
```

The second parameter is the strength, and it scales every amount a player SEES. A glancing blow is
`Moment "impact" 0.4`; a critical is `Moment "impact" 1.5`. One file, one number, and every hit in
the game shares a feel you can retune in one place.

### The six starters

Six moment files ship beside this pack, in `res://eventsheet_addons/juice/`. They are not a house
style and nothing in the plugin depends on them: they are ordinary resources, and you are expected
to open them. Retune the numbers, duplicate one into a moment of your own, rename it, or delete the
ones your game has no use for.

| Moment | What it is | The steps it holds |
|---|---|---|
| `impact` | A hit that landed. | shake 0.45, hitstop 0.06 s, chromatic 0.55, vignette pulse 0.5 |
| `kill` | The same, bigger, with a ring and a beat of slow motion. | shake 0.7, hitstop 0.12 s, shockwave at the object, chromatic 0.7, vignette pulse 0.7, slowmo to 0.35 for 0.25 s |
| `triumph` | A win: the screen swells and brightens. | bloom pulse 0.8, saturate pulse 0.6, white flash 0.5 |
| `danger` | Held, not fired: the edges close in and the colour drains. | vignette held at 0.55 over 0.8 s, desaturate held at 0.7 over 1.2 s |
| `calm` | Everything back over a second - the other half of `danger`. | vignette, desaturate, bloom and saturate all walked to 0 over 1 s |
| `cut` | A single white frame and a snap zoom. | white flash for 0.06 s, zoom to 115% over 0.12 s |

`danger` and `calm` are a pair on purpose: one moment turns the pressure on and holds it there, and
the other takes it off. That is how a low-health state, a boss phase or a storm is authored - two
rows, no per-frame logic.

### The step words

A step is a dictionary with four keys: `verb`, `amount`, `effect` and `seconds`. These are the words
a `verb` may be, and what its `amount` means:

| Word | What it does | `amount` | `seconds` | `effect` |
|---|---|---|---|---|
| `shake` | Screenshake on the active camera. | trauma added, 0 to 1 | - | - |
| `hitstop` | The hit-pause: freezes time and lets go. | the freeze scale (0 is a full stop) | how long the freeze lasts | - |
| `slowmo` | Slow motion, held and eased back. | the time scale to fall to | how long it is held | - |
| `flash` | Pops the host towards a colour and fades back. | how far towards it, 0 to 1 | how long the fade back takes | the colour, by name or hex |
| `punch` | Kicks the host's scale and springs it back. | how hard | how long | - |
| `zoom` | Zooms the camera. | per cent (100 is no change) | how long the glide takes | - |
| `shockwave` | A ring from the object the behaviour is on. | how strong, 0 to 1 | - | - |
| `chromatic` | The colour channels split and snap back. | how far, 0 to 1 | how long the settle takes | - |
| `pulse` | A screen effect flashed up and let fall. | how far, 0 to 1 | how long it falls over | which effect |
| `hold` | A screen effect walked to a strength and LEFT there. | where it lands, 0 to 1 | how long the walk takes | which effect |

The `pulse` and `hold` words take one of the Screen FX post-stack effects in `effect`: vignette, film
grain, scanlines, pixelate, colour grade, dither, fisheye, glitch, letterbox, bloom, saturate,
desaturate. They draw on the Screen FX layer if the scene has one, so a moment never builds a second
full-screen rectangle to fight with the one already there. Without a Screen FX layer, a vignette
pulse falls back to this pack's own overlay and the other screen effects quietly do nothing - add
`screen_fx.tscn` to the scene and they all light up.

### Making your own

Two ways, and neither of them is code:

1. **Duplicate a starter.** Copy `impact.tres`, rename it `boss_hit.tres`, open it in the Inspector
   and change the numbers. `Moment "boss_hit"` finds it by file name, because the Moment row looks in
   the pack folder for a file of that name.
2. **Keep it wherever you like and name it once.** Make a new `MomentResource` in your own folder
   (right-click, New Resource, MomentResource), fill in its steps, and point a name at it:

The moment slot takes the RESOURCE, not a path, so what goes in it is the line that loads one.
Press **Browse…** beside the field and pick the file - it writes the line for you:

```
On Ready
  -> Game | JuiceBehavior: Define Moment  "hit"  preload("res://feel/my_hit.tres")

On Enemy Hit
  -> Enemy | JuiceBehavior: Moment  "hit"  1.0
```

Define Moment is game-wide: one row at startup and every Juice node's Moment row finds that name.
Point the same name at a different file later - during a boss fight, in a nightmare level - and every
row that plays it changes with it.

### A moment written as rows

A file is the right home for a beat whose steps all happen at once. A beat with TIMING in it - the
shake now, the sound a frame later, the scale settling only once the sound has finished - wants to
be read in order, and that is what a **Moment block** is: a block of rows in the sheet whose
children are its steps, a timing word on the left and any actions at all on the right.

```
Moment  impact  (strength, from)
  At 0 s          -> Enemy | JuiceBehavior: Moment Step  "shake"  0.4
  At 0.05 s       -> Enemy | Audio: Play Sound  "hit.ogg"
  Hold, then 0.1 s -> Enemy | Tween: Scale To  1.0  over  0.2 s
```

The four timing words are the whole grammar:

| Word | When the step runs |
|---|---|
| At | That many seconds after the moment began. Two steps At the same number happen together. |
| Then | That many seconds after the step above it started. |
| Hold | When the slowest step above has finished, plus a delay of its own. |
| Loop Back | Back to the last Hold (or the top) for that many more passes. |

A step that says how long it lasts is what a Hold waits for; a step that says nothing counts as
instant, which is the common case. Reorder the steps by dragging the rows, the way you reorder any
rows - there is no widget in the block to press.

The block compiles to one ordinary coroutine on the host - `func moment_impact(strength: float =
1.0, from: Node = null)` - so what a sheet plays is a function a hand-written script could have
held, and a hand-written one of that shape opens back as the block. **Moment "impact"** plays it:
the row looks for a moment written as rows on the host first and falls through to a file when there
is none, so a game can keep some of its beats in files and write the rest down in the sheet without
either row knowing the difference.

Right-click the block head for the two doors between the homes:

- **Save Moment As File…** writes the steps out as a `MomentResource`. A file has no timing and
  knows only the ten step words, so a block with a Hold in it, or a step that spawns something, is
  named in the refusal rather than quietly dropped - keep that beat as a block.
- **Open Moment File As Block…** reads a file back as a block whose steps all start together, which
  is exactly what the file meant. Give them a Then or a Hold afterwards and the beat is yours. The
  same item sits on the sheet's empty-space menu, for the first block in a sheet that has none.

### Where it happened, and how far it reaches

A moment played on every enemy in a room is one beat felt ten times over. **Play Moment At** takes a
place and a range instead: the strength falls off between the two, and a moment that happened
outside the range does not play at all.

```
On Explosion
  -> Player | JuiceBehavior: Moment "kill" at 1.0 from *Bomb* within 600 (smooth)
```

The falloff is a word on the row - `linear` is a straight line to the edge, `smooth` rounds the
shoulders so a near blast keeps more of itself, `none` holds full strength right up to the edge -
and the distance is measured once per play, from the place to whoever is watching (the active
camera, or the host itself in a game with no camera). A range of 0 is no range: the moment plays
everywhere at full strength, exactly as Moment does.

**Set Moment Strength** is the other dial: one number every moment this node plays is scaled by,
for a quiet scene at 0.4, a boss fight at 1.5, or whatever the player chose in the options menu.
**Moment Strength** answers what that number is.

### Moments and Reduce Flashing

Every moment obeys the player's accessibility answer. When the built-in **Set No Flashing** row has
turned it on, a moment still plays - the hit still hits - but every amount a player sees is held
under a ceiling and every time is held over a floor, so nothing a moment does can strobe. A slowmo's
time scale, a hitstop's freeze and a zoom's percentage are left alone, because they are not
amplitudes: half a zoom is not half of anything. You do not have to author a second set of moments
for it.

---

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Shake at **strength**
- Hitstop for **freeze_duration** s at scale **freeze_scale**
- Flash **color** for **seconds** s

All ACEs live in the **Juice** category and target the `JuiceBehavior` on the node they are placed on. The camera actions act on the active camera; the squash actions act on the host node. The numbers shown in parameter descriptions are the values the picker opens with; you can change any of them per row.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Shake | `strength` (float) | Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit. Opens at 0.4. |
| Stop Shake | (none) | Cancels any shake immediately (the camera returns to rest unless another effect - recoil, bob, jitter, tilt - is still holding it). |
| Use Camera | `camera_path` (NodePath) | Pins the effects to a specific `Camera2D` by path. Leave it unset to auto-target whichever camera is active. |
| Recoil | `angle_degrees` (float), `strength` (float) | Kicks the camera `strength` pixels in a direction (-90 = up, 0 = right) and springs it back at the Recoil Recovery rate. Fire on every shot - kicks stack, so rapid fire climbs. Opens at -90, 12. |
| Start Head Bob | `amplitude` (float), `frequency` (float) | Starts a walking head-bob: a figure-8 sway (side at half rate, one vertical dip per step). Pixels and steps-per-second. Call while moving; Stop Head Bob when halting. Opens at 6, 2.2. |
| Stop Head Bob | (none) | Stops the head bob. |
| Start Jitter | `amount` (float) | A continuous nervous wobble (pixels) that runs until Stop Jitter - unlike Shake it never decays. Idling engines, drunk vision, building earthquakes, low-health unease. Opens at 3. |
| Stop Jitter | (none) | Stops the jitter wobble. |
| Tilt To | `degrees` (float), `duration` (float) | Eases the camera roll to an angle and HOLDS it - lean into a drift, a hill, a dutch angle. Tilt back to 0 to level out. Opens at 6, 0.3. |
| Zoom By Percent | `percent` (float), `duration` (float) | Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs. Opens at 150, 0.4. |
| Zoom To Position | `world_position` (Vector2), `percent` (float), `duration` (float) | Zooms in while gliding the camera so a world position becomes the screen centre - frame a spot in one action. Opens at 150, 0.4. |
| Zoom Toward Point | `world_position` (Vector2), `percent` (float), `duration` (float) | Zooms while keeping a world position pinned under the same screen spot (mouse-wheel-to-cursor style) - great for strategy/map zoom. Opens at 150, 0.4. |
| Squash & Stretch | `stretch` (float), `duration` (float) | Pops the host (Node2D or Control) with a volume-preserving stretch that springs back elastically over `duration`. Positive = stretch tall (a jump), negative = squash wide (a landing). Opens at 0.3, 0.4. |
| Set Host Tint | `color`, `strength` | Blends the host's colors toward the tint (0 = untouched, 1 = fully the color) - the object tint with strength as the opacity dial. |
| Clear Host Tint | (none) | Back to the host's own colors. |
| Set Screen Tint | `color`, `strength` | Washes the whole screen with a color at Strength opacity - damage red, poison green, flashback sepia. |
| Fade Screen Tint | `seconds` | Fades the screen tint to nothing - the damage-flash pattern (Set red 0.4, Fade 0.3). |
| Clear Screen Tint | (none) | Removes the wash instantly. |
| Spring Squash | `stretch` (float) | Pops the host with a volume-preserving stretch that springs back via a real spring (the stiffness/damping knobs) - bouncier and more organic than Squash & Stretch, and it needs no duration. Opens at 0.3. |
| Slowmo | `target_scale` (float), `hold_duration` (float), `duration_clock` (String) | Eases `Engine.time_scale` down to `target_scale`, holds for `hold_duration`, then eases back to normal. `duration_clock` picks `realtime` or `gametime` for the hold. Fade curves are Inspector knobs. Opens at 0.15, 0.25, realtime. |
| Clear Slowmo | (none) | Cancels any slowmo and snaps `Engine.time_scale` back to 1.0 immediately (call on scene exit if a slowmo might still be running). |
| Hitstop | `freeze_duration` (float), `freeze_scale` (float) | The punchy hit-pause on a connecting blow: freezes `Engine.time_scale` (0 = full stop) for `freeze_duration`, then snaps back to what it was. Ignores repeat hits already mid-freeze and pauses any active Slowmo. Opens at 0.06, 0.0. |
| Flash | `color` (Color), `seconds` (float) | Pops the host to a solid color, then fades back to how it looked (tints included) - THE damage-hit read. Fire with Hitstop + Shake for a complete hit-confirm. Opens at white, 0.12. |
| Start Blinking | `times_per_second` (float), `min_alpha` (float) | Strobes the host's opacity (full / faint) - invulnerability frames, low-health warnings, interactable highlights. Runs until Stop Blinking. Opens at 8, 0.15. |
| Stop Blinking | (none) | Stops the blink and restores the host's opacity. |
| Punch Scale | `strength` (float), `duration` (float) | Kicks the host's scale up (or down, negative) and springs back elastically - button pops, pickups, flinches, beat pulses. Opens at 0.25, 0.35. |
| Punch Rotation | `degrees` (float), `duration` (float) | Kicks the host's rotation and springs back - wobbling signs, chest jolts, portrait reactions. Opens at 8, 0.35. |
| Punch Position | `offset` (Vector2), `duration` (float) | Kicks the host's position and springs back - knockback reads, UI nudges, shoves away from an attacker. Opens at (6, 0), 0.35. |
| Kick Camera Away From Point | `world_position` (Vector2), `strength` (float) | Kicks the camera AWAY from a world position (an explosion, a hit source) and springs back - Recoil's directional sibling when you know the cause's location. Opens at 14. |
| Start Ghost Trail | `stamps_per_second` (float), `fade_seconds` (float), `tint` (Color) | Stamps fading afterimages of the host's sprite behind it - dashes, teleports, speed power-ups. Works on a Sprite2D/AnimatedSprite2D host or the host's first Sprite2D child. Opens at 20, 0.4, translucent white. |
| Stop Ghost Trail | (none) | Stops stamping (the ghosts already out finish fading). |
| Pulse Vignette | `strength` (float), `color` (Color), `seconds` (float) | Darkens the screen edges to a color, then fades back out - taking damage, a near miss. Opens at 0.6, dark red, 0.5. |
| Chromatic Kick | `strength` (float), `seconds` (float) | Splits the screen's color channels for an instant and settles back - the AAA impact frame. Opens at 0.5, 0.25. |
| Chromatic Shake | `magnitude` (float), `duration` (float), `mode` (String), `angle_degrees` (float) | Shakes the screen's color channels apart along a direction that MOVES - the Shake you feel, on the screen instead of the camera. A reducing shake falls to nothing over the duration; a constant one holds and then stops dead. An angle below zero lets the split wander with the same noise the camera shake uses; an angle pins the line and lets only the amount breathe. Firing again restarts it, slow motion glides it, a hitstop freezes it, and no flashing halves it. Opens at 12, 0.3, reducing, -1. |
| Stop Chromatic Shake | (none) | Takes the chromatic shake off the screen at once - the way out of a constant one, and the way to end a reducing one early. |
| Set Speed Lines | `intensity` (float) | Radial anime-style speed streaks that HOLD until you set 0 - sprints, dashes, adrenaline. Opens at 0.5. |
| Play Sound Varied | `path` (String), `pitch_jitter` (float), `volume_jitter_db` (float) | Plays a sound with a random pitch/volume wobble - the #1 trick against repetitive footsteps, hits, coins, clicks. Opens at 0.08, 2. |
| Play Sound With Intensity | `path` (String), `intensity` (float) | Plays a sound scaled by a 0-1 intensity: quiet and low when light, full and bright when heavy - drive it, Shake, and Punch Scale from ONE hit-power value. Opens at 0.5. |
| Count To | `ticker_name` (String), `target` (float), `duration` (float) | Eases a named display value toward a target - scores and gold ROLL instead of snapping. Read it with the Ticker Value expression. Opens at score, 100, 0.6. |
| Set Ticker | `ticker_name` (String), `value` (float) | Sets a display value instantly (cancelling any roll) - initialise at 0, or snap on reset. |
| Moment | `moment_name` (String), `strength` (float) | Plays a moment - a whole beat of feedback written down as a file: a hit's shake and freeze and flash, a win's swell, danger draining the colour out. The strength scales every amount a player sees, so a light hit and a heavy one are one moment at two numbers. Six starters ship beside the pack. Opens at impact, 1. |
| Define Moment | `moment_name` (String), `moment` (Resource) | Points a name at a moment file, for the whole game: every Juice node's Moment row finds it afterwards. Use it for a moment kept elsewhere in the project, or to swap which file a name means (a boss fight that hits harder). An empty slot takes the name away again. |
| Play Moment At | `moment_name` (String), `strength` (float), `from` (Node), `within` (float), `falloff` (String) | Plays a moment WHERE it happened, so a far explosion is felt less than a near one. The strength falls off between that place and the edge of the range, and a moment outside the range does not play at all. Leave the range at 0 and it plays everywhere at full strength, exactly as Moment does. Opens at impact, 1, 600, linear. |
| Set Moment Strength | `value` (float) | Turns every moment this node plays up or down by one number - a quiet scene at 0.4, a boss fight at 1.5, an accessibility setting at whatever the player chose. The moments themselves are untouched. Opens at 1. |
| Moment Step | `verb` (String), `amount` (float), `effect` (String), `seconds` (float), `strength` (float) | Plays ONE step of a moment with no file behind it - the same step a moment file holds, played by the same code. Use it to write a beat straight into a sheet, or as the step of a Moment block. Opens at shake, 0.4, 0, 1. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Shaking | (none) | Whether the camera is currently shaking (trauma is above zero). |
| Is Hitstopped | (none) | Whether a hitstop freeze is active right now. |
| Is Chromatic Shaking | (none) | Whether a chromatic shake is running right now - true from the row that fires it until the duration is up or Stop Chromatic Shake takes it off. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Trauma | (none) | float | The current trauma level, 0 to 1 - drive a rumble strength or a shaking HUD element from it. |
| Ticker Value | `ticker_name` (String) | float | What a ticker currently SHOWS - the eased value Count To is rolling. Print or draw this instead of the real variable. |
| Chromatic Shake Magnitude | (none) | float | How wide the split is right now, in pixels: the magnitude after the falloff, the wander, the no-flashing halving and the player's effect-strength dial - the width the screen is showing. Zero when nothing is shaking - drive a rumble or a HUD wobble from it and the whole hit reads as one thing. |
| Moment Strength | (none) | float | The number every moment this node plays is scaled by - what Set Moment Strength last wrote, and 1 until it has been written. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Shake Stopped | Trauma reaches zero and the camera settles back to rest after a shake. |
| On Tilt Finished | A Tilt To ease reaches its target angle. |
| On Flash Finished | A Flash has faded back to the host's own look. |
| On Punch Finished | A Punch Scale / Rotation / Position has sprung back to rest. |
| On Ticker Finished | A Count To roll lands on its target (carries the ticker's name). |
| On Zoom Finished | Any of the three zoom actions finishes its glide. |
| On Squash Finished | A Squash & Stretch tween or a Spring Squash spring settles back to rest. |
| On Slowmo Finished | Slowmo has ramped back to normal time scale. |
| On Hitstop Finished | A hitstop freeze ends and the previous time scale is restored. |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `max_offset` | Vector2 | `(24, 16)` | any |
| `max_roll_degrees` | float | `3.0` | 0.0 - 30.0 |
| `shake_decay` | float | `1.4` | 0.1 - 10.0 |
| `shake_frequency` | float | `25.0` | 1.0 - 60.0 |
| `min_zoom` | float | `0.2` | 0.05 - 1.0 |
| `max_zoom` | float | `5.0` | 1.0 - 16.0 |
| `slowmo_fade_in_trans` | String | `sine` | linear, sine, quad, cubic, expo, circ, back |
| `slowmo_fade_in_ease` | String | `out` | in, out, in_out, out_in |
| `slowmo_fade_out_trans` | String | `sine` | linear, sine, quad, cubic, expo, circ, back |
| `slowmo_fade_out_ease` | String | `in` | in, out, in_out, out_in |
| `slowmo_fade_in_secs` | float | `0.15` | 0.0 - 2.0 |
| `slowmo_fade_out_secs` | float | `0.35` | 0.0 - 2.0 |
| `squash_stiffness` | float | `250.0` | 1.0 - 1000.0 |
| `squash_damping` | float | `0.6` | 0.0 - 1.0 |
| `recoil_recovery` | float | `140.0` | 10.0 - 2000.0 |

All camera effects (shake, recoil, bob, jitter, tilt) sum around ONE captured rest pose, so they
compose freely - a recoil during a shake during a head bob just works, and the camera is handed
back exactly where it started once everything settles. For a `Camera3D`, use the **Juice 3D**
pack - the same vocabulary, plus FOV punch/zoom and lean.

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$JuiceBehavior.max_offset` inserts the **Max Offset** entry straight into any expression
- `$JuiceBehavior.max_roll_degrees` inserts the **Max Roll Degrees** entry straight into any expression

The `$JuiceBehavior` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("JuiceBehavior")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance - behaviours
attached at runtime included, under their real names. And with your node selected in the Scene
dock, the section grounds to that node's actual children before you even press Run.

## Use cases

Each example places the ACEs on a node that carries a `JuiceBehavior`. Camera effects reach the active camera; squash effects animate the node named.

### 1. Screenshake on every hit

The classic. A small Shake per hit stacks into a rising rumble and decays on its own, so you never manage a timer.

```
On Enemy Took Damage
  -> Enemy | JuiceBehavior: Shake  0.3
```

Because trauma clamps at 1, a flurry of hits builds to a hard shake and then settles as `shake_decay` bleeds it off.

### 2. Jump and land squash on a platformer

Stretch the character tall as it leaves the floor, squash it wide the moment it lands. Spring Squash needs no duration, so both are one row.

```
On Player Jumped
  -> Player | JuiceBehavior: Spring Squash  0.35

On Player Landed
  -> Player | JuiceBehavior: Spring Squash  -0.45
```

Positive stretches tall, negative squashes wide; the spring back is shaped by `squash_stiffness` and `squash_damping` in the Inspector.

### 3. Finisher slow motion

Drop the whole game to a crawl for a beat on a killing blow, then let it ease back on its own.

```
On Enemy Killed
  Condition: Enemy  Is Last Enemy
    -> Player | JuiceBehavior: Slowmo  0.15, 0.4, realtime
```

The hold is measured in `realtime` so a 0.4-second hold really lasts 0.4 seconds of your life, not 0.4 of scaled game time.

### 4. Hitstop on a connecting blow

The tiny freeze that sells a hit. Fire it the instant a strike lands.

```
On Sword Hit Enemy
  -> Player | JuiceBehavior: Hitstop  0.06, 0.0
```

A full stop (`freeze_scale` 0) for 60 milliseconds. A second Hitstop during the freeze is ignored, so overlapping hits do not stack the pause.

### 5. Zoom punch-in on a special move

Punch the camera in as a special charges, then let On Zoom Finished cue the release.

```
On Special Triggered
  -> Player | JuiceBehavior: Zoom By Percent  150, 0.3

On Zoom Finished
  -> Player: release special beam
```

Zoom in to 1.5x over 0.3 seconds; the result is clamped to `max_zoom` so it never overshoots.

### 6. Frame a boss on spawn

Glide the camera so the boss ends up centred while zooming in a touch, in one action.

```
On Boss Spawned
  -> Camera | JuiceBehavior: Zoom To Position  Boss.global_position, 130, 0.8
```

Zoom To Position both zooms and recentres, so you frame the arrival without a separate camera move.

### 7. Zoom back out to reveal the arena

After the intro, pull the camera back out. A percent below 100 zooms out.

```
On Zoom Finished
  Condition: GameState  Is Boss Intro
    -> Camera | JuiceBehavior: Zoom By Percent  70, 1.0
```

Chaining off On Zoom Finished sequences the pull-back right after the punch-in with no timer.

### 8. Strategy map zoom toward the cursor

On a map or RTS view, keep the world point under the mouse pinned as you zoom - the wheel-to-cursor feel.

```
On Mouse Wheel Up
  -> Camera | JuiceBehavior: Zoom Toward Point  Mouse.world_position, 120, 0.15
```

Zoom Toward Point anchors the passed world position under the same screen spot, unlike Zoom To Position which recentres on it.

### 9. UI button pop

Attach the behavior to a `Control` and pop it when pressed. The pivot is centred for you, so the button scales from its middle.

```
On Button Pressed
  -> StartButton | JuiceBehavior: Spring Squash  0.25
```

The same behavior works on any `Control` - a panel that slides in, an icon that reacts to a hover.

### 10. Chain hitstop into slow motion for a big finisher

Freeze on impact, then, when the freeze ends, drop into slow motion for the follow-through.

```
On Finisher Landed
  -> Player | JuiceBehavior: Hitstop  0.12, 0.0

On Hitstop Finished
  -> Player | JuiceBehavior: Slowmo  0.2, 0.5, realtime
```

Hitstop pauses any running Slowmo, and here it hands off cleanly by starting the Slowmo only after On Hitstop Finished.

### 11. Explosion shake scaled by distance

A nearby blast rocks the screen, a distant one barely registers. Feed a distance-based strength into Shake.

```
On Explosion
  -> Player | JuiceBehavior: Shake  clamp(1.0 - Player.global_position.distance_to(Explosion.global_position) / 500.0, 0, 1)
```

The expression falls off with distance, so the same event gives near and far explosions different weight.

### 12. Pin the effects to a specific camera

In split screen or a custom rig, tell Juice which camera to drive instead of the auto-found one.

```
On Ready
  -> Player | JuiceBehavior: Use Camera  "../CameraRig/PlayerCamera"

On Player Damaged
  -> Player | JuiceBehavior: Shake  0.4
```

Once Use Camera is set, every Shake and Zoom targets that camera. Leave Use Camera out entirely and Juice targets whatever camera is active.

### 13. Rumble strength from the Trauma expression

Match a controller rumble or a shaking HUD element to the camera by reading Trauma each frame.

```
Every 0.05 seconds
  Condition: Player | JuiceBehavior  Is Shaking
    -> Input: start rumble at strength Player | JuiceBehavior.Trauma
```

Is Shaking gates the loop so you only push rumble while the camera is actually moving, and Trauma gives the matching intensity.

### 14. Charge-up pulse

Squash the host a little on each tick while a charge is held, building an anticipatory pulse before the release.

```
Every 0.2 seconds
  Condition: Player  Is Charging
    -> Player | JuiceBehavior: Spring Squash  0.15
```

Each pulse springs back before the next, so a held charge reads as a rhythmic breathing rather than a single pop.

### 15. Clean up slowmo on a scene change

If a slowmo could still be running when you leave a scene or open a menu, snap the time scale back so the next scene is not stuck slow.

```
On Level Exit
  -> Player | JuiceBehavior: Clear Slowmo
```

Clear Slowmo cancels the ramp and forces `Engine.time_scale` back to 1.0 immediately.

### 16. Elastic pop for a pickup

Use the tween Squash & Stretch when you want a fixed-duration, snappy elastic pop rather than a spring that settles on its own.

```
On Coin Collected
  -> Coin | JuiceBehavior: Squash & Stretch  0.5, 0.3

On Squash Finished
  -> Coin: queue free
```

Squash & Stretch runs over the `duration` you pass and fires On Squash Finished when the elastic settle completes, a clean hook to remove the coin.

---

### 17. Gun recoil that climbs under sustained fire

Each shot kicks the camera up 12 pixels; the spring-back is slower than the fire rate, so holding the trigger walks the view upward exactly like a real spray pattern.

```
On Shoot
  -> Player | Juice: Recoil  -90, 12
```

### 18. Footsteps you can feel

Bob while moving, stop when idle - two rows and the camera walks with the character.

```
Every tick
  Condition: Player  is moving
    -> Player | Juice: Start Head Bob  6, 2.2
  Else
    -> Player | Juice: Stop Head Bob
```

### 19. A drift lean

Tilt into the corner while drifting, level out on exit - the roll eases both ways.

```
On Drift Started
  -> Car | Juice: Tilt To  8, 0.3

On Drift Ended
  -> Car | Juice: Tilt To  0, 0.4
```

### 20. Low-health unease

A permanent subtle wobble below 25% health that vanishes on heal - jitter never decays, so it reads as a STATE, not an event.

```
On Health Changed
  Condition: Player.health < 25
    -> Player | Juice: Start Jitter  2
  Else
    -> Player | Juice: Stop Jitter
```

### 21. One row for every hit in the game

Instead of four rows on each of ten hit events, play the same moment and change one number.

```
On Enemy Hit
  -> Enemy | JuiceBehavior: Moment  "impact"  1.0

On Enemy Grazed
  -> Enemy | JuiceBehavior: Moment  "impact"  0.35
```

When the game's feel changes, you retune `impact.tres` once instead of editing twenty rows.

### 22. Danger held, then let go

The pressure comes on while the player is in trouble, and comes off when they are not - two rows and
no per-frame logic.

```
On Health Dropped Below 25
  -> Player | JuiceBehavior: Moment  "danger"  1.0

On Health Healed Above 25
  -> Player | JuiceBehavior: Moment  "calm"  1.0
```

`danger` holds the vignette and the drained colour where they land; `calm` walks all of it back over
a second.

### Other use cases

**Rhythm-synced pulses.** Fire a small Spring Squash on the album art or the whole HUD panel on every beat, and a slightly larger one on downbeats. The spring settles before the next beat at sensible tempos, so the interface breathes with the music using no tween code.

**Speed-sensitive racing cameras.** Map the car's velocity to Zoom By Percent so the view pulls back as speed climbs and tightens when braking, with the min/max zoom knobs keeping it sane. A nitro burst layers a quick Recoil kick backwards for the launch feel.

**Earthquake set pieces.** A collapsing mine or a rumbling titan approach is Start Jitter at low amount, escalated by re-calling it with bigger values as the scene builds, then Stop Jitter when the dust settles. Unlike Shake it never decays, so the ground keeps trembling exactly as long as the script says.

**Pinball table feedback.** Bumpers fire a tiny Shake, slingshots add a touch more, and a jackpot ramps a Zoom By Percent punch on the playfield camera - the trauma model sums a fast multiball into one satisfying rumble instead of discrete twitches. Nudging the table is a single Recoil in the shove direction.

**Jackpot celebrations.** A slot-machine or wheel-spin minigame lands its top prize with a chained beat: Hitstop the reels the instant the third symbol locks, then On Hitstop Finished rolls into a short Slowmo while coins burst and the camera Zoom To Position frames the payout counter.

## Tips and common mistakes

- **A moment is a file, so edit the file.** The six starters are yours: open `impact.tres` and change
  the numbers rather than adding rows around the Moment call. If you want two feels, duplicate the
  file rather than branching in the sheet.
- **Strength scales what a player sees, and only that.** A shake, a flash, a pulse and a punch all
  scale with the number on the row. A slowmo's time scale, a hitstop's freeze and a zoom's percentage
  do not - doubling those would not mean twice as much of anything, and a moment at 0.5 would break
  in a way you could not read off the file.
- **The screen steps want a Screen FX layer.** `pulse` and `hold` draw on the Screen FX post stack.
  Add `screen_fx.tscn` to the scene once and every moment that touches the screen works; without it a
  vignette pulse falls back to this pack's own overlay and the rest go quiet.
- **`hold` leaves the effect where it lands.** That is the point of it - `danger` is meant to stay on.
  Play `calm` (or your own version of it) to take it off again; a held effect at strength 0 costs
  nothing, so there is no need to remove it by hand.
- **Camera effects need an active Camera2D.** Shake and the three Zoom actions drive `get_viewport().get_camera_2d()`. If nothing is happening on Shake, confirm a `Camera2D` in the scene is set as current (or pin one with Use Camera). No camera means the action quietly does nothing.
- **Squash acts on the host, not the camera.** Squash & Stretch and Spring Squash scale the node the behavior is attached to. Put the behavior on the exact sprite or `Control` you want to pop - attaching it to a parent and expecting a child to move will not work.
- **Do not fight the shake by writing camera offset yourself.** The shake is additive on the camera's own offset and rotation and restores them when it settles. If your own code also writes `camera.offset` every frame, the two will overwrite each other. Let the follow logic set the base and let Juice add the shake on top.
- **Shake stacks, so keep per-hit strengths small.** Trauma clamps at 1, and a small `strength` per hit (say 0.2 to 0.4) builds naturally across a burst. Passing 1.0 on every hit pins it at maximum and you lose the sense of escalation.
- **Slowmo and Hitstop are global.** Both change `Engine.time_scale` for the whole game, not just this node. That is the point, but it means anything that must keep real-time speed (music, a realtime UI animation) needs its own handling. Hitstop already pauses a running Slowmo so the two do not compound.
- **Pick the right clock for a Slowmo hold.** `realtime` measures the hold in wall-clock seconds regardless of the slowdown; `gametime` measures it in scaled game time, so a deep slowmo makes the hold feel much longer. Reach for `realtime` when you want a predictable beat length.
- **Always have a way back from a freeze or a slowmo.** A Hitstop restores the previous time scale on its own, and a Slowmo ramps back by itself, but if a scene can be torn down mid-effect, call Clear Slowmo on exit so you never leave the game stuck slow. Repeated Hitstop calls during a freeze are ignored, so you cannot accidentally trap yourself frozen.
- **Positive stretch is tall, negative is wide.** For a jump you usually want a positive `stretch` (tall and thin); for a landing you want a negative one (short and wide). Passing the wrong sign makes a jump look like a squash. The value is clamped to the -0.9 to 5.0 range.
- **Choose Spring Squash for organic, Squash & Stretch for timed.** Spring Squash settles on its own using the stiffness and damping knobs and reads bouncier; Squash & Stretch runs for the exact `duration` you pass and springs back elastically. Use the spring for character feel, the tween when you need a fixed-length pop that ends with On Squash Finished.
- **React to the finished triggers instead of guessing timing.** To sequence a beat after an effect, wire On Zoom Finished, On Squash Finished, On Slowmo Finished, On Hitstop Finished or On Shake Stopped rather than an approximate `Every N seconds`. The triggers fire exactly when the effect ends, so chained sequences stay in sync.
