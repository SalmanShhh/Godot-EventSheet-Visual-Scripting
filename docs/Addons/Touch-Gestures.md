# Touch Gestures

Touch Gestures is a Godot EventSheets behavior pack that turns finger movement into sentences your sheet already understands. You attach a `TouchGesturesBehavior` under any `Node` and it watches the touch events itself - the finger going down, the drag in between, the finger coming up - so there is no input polling to write. It fires **On Swipe** with a direction (left, right, up, down, and the four diagonals when eight-way is on), **On Shape Drawn** with the name of the closest taught shape, and **On Stroke Started** the moment a finger lands. The two halves are deliberately separate: a **swipe** is a distance covered quickly enough in one dominant direction, while a **shape** is the whole stroke the drag gathered, smoothed and compared against templates you **taught by drawing them once**. There is no coordinate list to type anywhere in this pack. Taught shapes can live only for the run, or be saved into a **Touch Shape Library** data asset so they ship with the project. This guide covers the whole pack: the mental model, setup, every Action, Condition, Expression, and Trigger, a stack of concrete use cases, and the traps to avoid.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Card and tile swipes.** A left or right flick sorts a card into a pile, and the swipe speed decides how far it sails before settling.
- **Match-3 and puzzle grids.** A short swipe on a gem swaps it with the neighbour in that direction, with the four-way reading doing the work.
- **Endless runners.** Swipe up to jump, down to slide, left and right to change lane, straight off a single trigger with a direction condition.
- **Rune and sigil spellcasting.** Draw a circle for a shield and a zigzag for lightning; the shapes are taught by drawing them once, so a designer can add spells without touching code.
- **Handwriting and letter-tracing games.** Teach each letter as a shape, then score the child's attempt with the closeness value instead of a pass or fail.
- **Mobile menus and drawers.** A swipe from the edge opens a pause panel, a swipe back closes it, and a stroke interrupted by a menu is thrown away cleanly.
- **Photo and level browsers.** Swipe left or right to page through, with the swipe distance deciding whether the page commits or springs back.
- **Gesture-locked doors and safes.** A drawn sigil is the key, matched with a tight tolerance so a rough scribble does not open it.
- **Flick-to-throw mechanics.** The pixels-per-second speed of a flick scales the momentum a thrown object leaves with.
- **Drawing-based bosses and rituals.** A boss demands a specific shape under time pressure, and the closeness value decides how much damage the cast does.
- **Eight-way action controls.** Turning on the diagonals gives a twin-stick feel from a single finger, with eight named directions instead of four.
- **Accessibility gesture shortcuts.** A player teaches their own comfortable stroke for a common action, and it is saved into the shape library for next time.

---

## Core concepts

The pack has two halves that never overlap: **swipes** and **drawn shapes**. One stroke produces at most one of them, and a swipe always wins the test first.

**A stroke is one finger journey.** When a finger goes down the pack remembers the point and the time, fires **On Stroke Started**, and starts gathering points. Every drag event appends another point. When the finger comes up, the stroke is finished and tested.

**A swipe is distance over time.** If the straight-line distance from where the finger went down to where it came up is at least **swipe_min_distance** (default `100` pixels) AND the whole journey took no longer than **swipe_max_seconds** (default `0.4`), the stroke is a swipe. That is why a slow drag over the exact same distance is not a swipe: it is just a drag, and the pack lets it fall through to the shape test instead.

**The dominant axis names a four-way swipe.** With **eight_way** off (the default), the pack compares how far the finger went sideways against how far it went up or down, and the bigger of the two wins. A travel that is mostly horizontal reads as `"left"` or `"right"`; a travel that is mostly vertical reads as `"up"` or `"down"`. A diagonal therefore reports as whichever of the four it leaned towards, which is exactly what a lane-changing runner or a match-3 grid wants.

**Eight-way cuts the same circle into eight bands.** Turn **eight_way** on (in the Inspector, or live with **Set Eight Way**) and the swipe's angle is bucketed into eight 45-degree bands, adding `"up left"`, `"up right"`, `"down left"` and `"down right"` to the four. The direction names are lowercase with a single space, and **Swipe Was** compares against exactly those strings.

**Screen coordinates count Y downwards.** That is why **Swipe Angle** reports `0` for a swipe to the right and grows as the swipe turns towards the bottom of the screen. A swipe straight down is `90`, straight up is `-90`. If you are feeding the angle into a rotation, remember the screen's Y axis points down, not up.

**A shape is the whole stroke, not its endpoints.** If the stroke was not a swipe, and it gathered at least **minimum_stroke_points** points (default `8`), and at least one shape has been taught, the pack tries to recognise it. A tap gathers one or two points and is ignored on purpose.

**Resampling makes two strokes comparable.** Two strokes can only be compared point for point if they have the same number of points, so every stroke is reduced to a fixed 24 points spaced evenly **along its length**. Walking the length rather than taking every Nth point matters: it makes a slow corner and a fast straight weigh the same, so the recogniser cares about the drawn line, not about how quickly each part of it was drawn.

**Centring and unit scaling make size and position irrelevant.** The resampled points are then moved so their middle sits at the origin, and scaled so the longest side of their bounding box is `1`. After that a big circle drawn in the corner and a small circle drawn in the middle are literally the same numbers, which is the whole reason a drawn gesture can be recognised at all.

**Every template is compared both ways round.** The stroke is measured against each taught shape forwards and reversed, and the smaller of the two distances counts. So a circle drawn clockwise and one drawn anticlockwise are the same circle, and a line drawn left to right matches a line drawn right to left. You never have to teach a shape twice for direction.

**Tolerance is the one dial that decides how forgiving matching is.** **shape_tolerance** (default `0.22`, range `0.02` to `0.8`) is the largest average point-to-point distance a stroke may sit from a template and still count. Raise it and rough strokes match; raise it too far and two similar shapes start being confused for each other. **Shape Closeness** reports `1` for an exact match and falls towards `0` as the stroke approaches the tolerance limit, so you can grade an attempt instead of just accepting it. If nothing lands inside the tolerance, no trigger fires at all - silence is the "I did not recognise that" answer.

**Shapes are taught by drawing, never typed.** This is the design decision the pack is built around. You draw the shape in the running game, call **Teach Shape From Stroke** with a name, and the stroke that was just drawn becomes the template. Typing coordinates for a rune is miserable, imprecise, and impossible to hand to a designer; drawing it once takes a second and produces a template that already matches the way a real hand moves. That is why there is no coordinate list anywhere in this pack, and why the shape library holds outlines rather than authored geometry.

**A shape library makes taught shapes permanent, and teaching fills it as you go.** Without a library attached, taught shapes live only for the run. Attach a **Touch Shape Library** data asset to the **shape_library** knob and every **Teach Shape From Stroke** writes into it immediately and marks it changed - so the library you see in the Inspector is never a step behind what the behaviour knows, and the editor's own Save writes it out. **Save Shapes To Library** is the same write done deliberately from a running game, **Forget Shape** removes from both halves at once, and **Load Shapes From Library** (called for you when the behaviour starts) reads it back. Because it is a plain resource file it gets version-controlled, ships with the project, and can be swapped per level.

---

## Setup

**1. Attach the behavior.** Add a `TouchGesturesBehavior` as a child of any `Node` (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The host requirement is only `Node`, so a plain `Node`, a `Control`, a `Node2D` or your player scene all qualify. The behavior reads the touch events itself, so it does not matter where in the scene it sits - one per project is usually plenty.

**2. Optionally attach a shape library.** If you want taught shapes to survive the run, create a `TouchShapeLibraryResource` (a data asset with a `library_name` label and a `shapes` dictionary of name to drawn outline), save it as a `.tres` somewhere in your project, and drop it on the behavior's **shape_library** knob. Leave the knob empty and taught shapes are still fully usable, they just vanish when the game closes.

**3. On desktop, turn on touch emulation.** The behavior listens for touch events, which a mouse does not produce by default. Open Project Settings > Input Devices > Pointing and turn on **Emulate Touch From Mouse** so you can draw and swipe with the mouse while you build. Without it nothing will fire on a desktop run and the pack will look broken.

**4. React to the triggers.** A minimal first sheet, teaching one shape and reacting to a swipe:

```
On Stroke Started
  -> Show text  "drawing..."

On Swipe
  TouchGesturesBehavior: Swipe Was  "left"
    -> Go to previous page
  TouchGesturesBehavior: Swipe Was  "right"
    -> Go to next page

On teach button pressed
  -> TouchGesturesBehavior: Teach Shape From Stroke  "circle"
  -> TouchGesturesBehavior: Save Shapes To Library

On Shape Drawn
  TouchGesturesBehavior: Shape Was  "circle"
    -> Cast shield spell
```

Draw a circle, press the teach button, and the stroke you just drew becomes the `circle` template. From then on, drawing a circle slowly enough that it is not mistaken for a swipe fires **On Shape Drawn**. `Go to next page` and `Cast shield spell` stand in for whatever your game does; the `TouchGesturesBehavior` rows are the real part.

Because the pack is a live event sheet, you can open it and extend it directly, but you never have to: the ACEs below cover the whole workflow.

---

## ACE reference

On the canvas the two hero verbs read as styled sentences, with parameter values in **bold**, exactly as the rows draw them:

- Teach shape from stroke as **shape_name**
- Set swipe thresholds: **minimum_distance** px in **maximum_seconds** s

Every name below is exactly what appears in the picker. Parameters are listed in order.

### Actions

| Action | Parameters | What it does |
| --- | --- | --- |
| **Set Swipe Thresholds** | `minimum_distance`, `maximum_seconds` | Sets how far (pixels) and how fast (seconds) a drag has to be before it counts as a swipe. The defaults suit a phone held in one hand. |
| **Set Eight Way** | `on` | Turns the four diagonals on or off. Off, a diagonal swipe reports as whichever of left / right / up / down it leaned towards. |
| **Teach Shape From Stroke** | `shape_name` | Records the stroke that was just drawn as a template under a name. Draw the shape in the running game, then call this - there is no coordinate list to type. Saves into the attached shape library when there is one. |
| **Forget Shape** | `shape_name` | Removes a taught shape, so it stops being matched. |
| **Load Shapes From Library** | (none) | Reads every taught shape out of the attached shape library, replacing what is loaded. Called for you when the behaviour starts. |
| **Save Shapes To Library** | (none) | Writes the taught shapes back to the attached shape library file, so they survive the run. Does nothing when no library is attached. |
| **Clear Stroke** | (none) | Throws away the stroke gathered so far, so a gesture interrupted by a menu cannot finish afterwards. |

### Conditions

| Condition | Parameters | What it checks |
| --- | --- | --- |
| **Swipe Was** | `direction` | Whether the swipe that just fired went this way (`"left"`, `"right"`, `"up"`, `"down"`, and with eight-way on `"up left"`, `"up right"`, `"down left"`, `"down right"`). |
| **Shape Was** | `shape_name` | Whether the shape that was just drawn is this one. |
| **Knows Shape** | `shape_name` | Whether a shape has been taught under this name. |

### Expressions

| Expression | Parameters | Returns | What it gives you |
| --- | --- | --- | --- |
| **Swipe Direction** | (none) | String | Which way the swipe went, as a word (inside On Swipe). |
| **Swipe Angle** | (none) | float | The swipe's angle in degrees, `0` pointing right and counting clockwise the way screen coordinates do (inside On Swipe). |
| **Swipe Distance** | (none) | float | How far the finger travelled, in pixels (inside On Swipe). |
| **Swipe Seconds** | (none) | float | How long the swipe took, in seconds (inside On Swipe). |
| **Swipe Speed** | (none) | float | How fast the swipe was, in pixels per second - the number a flick's momentum should scale with (inside On Swipe). |
| **Shape Name** | (none) | String | The name of the shape that was just drawn (inside On Shape Drawn). |
| **Shape Closeness** | (none) | float | How close the stroke was to the taught shape, `0` to `1`, where `1` is an exact match (inside On Shape Drawn). |
| **Stroke Length** | (none) | float | How far the finger travelled along the whole stroke, in pixels - the drawn line's length, not the distance between its ends. |
| **Stroke Points** | (none) | int | How many points the stroke gathered so far. |

### Triggers

| Trigger | When it fires | Read inside it |
| --- | --- | --- |
| **On Stroke Started** | The moment a finger goes down and a new stroke begins (the previous stroke is discarded). | Nothing gesture-specific yet; use it to show a trail or a "drawing" hint. |
| **On Swipe** | When a finished stroke covered at least `swipe_min_distance` in no more than `swipe_max_seconds`. | Swipe Direction, Swipe Angle, Swipe Distance, Swipe Seconds, Swipe Speed (and the Swipe Was condition). |
| **On Shape Drawn** | When a finished stroke was not a swipe, gathered at least `minimum_stroke_points` points, and matched a taught shape inside the tolerance. | Shape Name, Shape Closeness (and the Shape Was condition). |

### Inspector knobs

Select the behavior node to see these.

| Knob | Type | Default | What it does |
| --- | --- | --- | --- |
| **swipe_min_distance** | float | `100.0` | How far the finger must travel, in pixels, before the drag counts as a swipe. Range `10.0` to `600.0`. (Live: Set Swipe Thresholds.) |
| **swipe_max_seconds** | float | `0.4` | How long the finger may take. A slow drag over the same distance is a drag, not a swipe. Range `0.05` to `3.0`. (Live: Set Swipe Thresholds.) |
| **eight_way** | bool | `false` | Off: four directions (left, right, up, down). On: the four diagonals as well (up left, up right, down left, down right). (Live: Set Eight Way.) |
| **shape_tolerance** | float | `0.22` | How far a stroke may sit from a taught shape and still count, `0` to `1`. Higher is more forgiving and more likely to confuse two similar shapes. Range `0.02` to `0.8`. |
| **minimum_stroke_points** | int | `8` | How many gathered points a stroke needs before it is worth matching. A tap gathers one or two. Range `4` to `64`. |
| **shape_library** | Resource | `null` | A Touch Shape Library data asset holding the taught shapes. Leave it empty to teach shapes that only live for this run. |
| **debug_logging** | bool | `false` | Print every swipe and every match to the Output panel while tuning the thresholds. |

### The Touch Shape Library data asset

`TouchShapeLibraryResource` is the companion data asset: the drawn shapes a project recognises, saved as a `.tres`. It has two properties.

| Property | Type | Default | What it does |
| --- | --- | --- | --- |
| **library_name** | String | `"shapes"` | A label for your own reference (Touch Gestures does not read it). |
| **shapes** | Dictionary | `{}` | Shape name to the smoothed outline that was drawn for it. Taught by drawing, not by typing - use Teach Shape From Stroke while the game runs. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Use cases

How to read these snippets: a line starting with **On** is a trigger in the left lane, a plain indented line is a condition, and a line starting with **`->`** is an action. Rows like `Go to next lane` and `Show text` stand in for however your own game reacts.

### 1. Endless-runner controls (four-way swipes)

**Scenario:** Swipe up to jump, down to slide, left and right to change lane. The default four-way reading is all you need, and a lazy diagonal still resolves to a real move.

```
On Swipe
  TouchGesturesBehavior: Swipe Was  "up"
    -> Jump
  TouchGesturesBehavior: Swipe Was  "down"
    -> Slide
  TouchGesturesBehavior: Swipe Was  "left"
    -> Move to left lane
  TouchGesturesBehavior: Swipe Was  "right"
    -> Move to right lane
```

With **eight_way** off, the dominant axis decides, so a swipe that drifts diagonally still lands on the direction the player meant. The direction strings are lowercase.

### 2. Match-3 gem swap

**Scenario:** Tapping and flicking a gem swaps it with its neighbour in the flick direction. Short flicks should count, so the distance threshold comes down.

```
On Ready
  -> TouchGesturesBehavior: Set Swipe Thresholds  40, 0.3

On Swipe
  -> Swap selected gem with neighbour  TouchGesturesBehavior.Swipe Direction()
```

`40` pixels is about one grid cell on a phone, so a flick that barely leaves the gem still registers, and **Swipe Direction** hands the word straight to your swap function instead of four separate condition rows.

### 3. Eight-way twin-stick feel from one finger

**Scenario:** A top-down shooter dashes in any of eight directions from a single flick.

```
On Ready
  -> TouchGesturesBehavior: Set Eight Way  true

On Swipe
  TouchGesturesBehavior: Swipe Was  "up right"
    -> Dash north-east
  TouchGesturesBehavior: Swipe Was  "down left"
    -> Dash south-west
```

With eight-way on, the swipe's angle is bucketed into eight 45-degree bands and the diagonal names become available. Note the exact spelling: one space, lowercase, vertical part first (`"up right"`, not `"right up"`).

### 4. Flick-to-throw with real momentum

**Scenario:** The player flicks an object across the table; how hard it was flicked decides how far it travels.

```
On Swipe
  -> Launch held object  TouchGesturesBehavior.Swipe Speed() * 0.5, TouchGesturesBehavior.Swipe Angle()
  -> Show text  "flicked " + str(TouchGesturesBehavior.Swipe Distance()) + " px"
```

**Swipe Speed** is pixels per second (distance divided by duration), which is the number a throw's momentum should scale with - a long slow drag and a short fast flick are correctly different. **Swipe Angle** gives the launch direction in degrees, with `0` pointing right and the angle growing clockwise because screen Y points down.

### 5. Teaching a spell rune by drawing it

**Scenario:** A designer wants to add a new spell rune without typing coordinates. They draw it in the running game and name it.

```
On Stroke Started
  -> Show text  "drawing..."

On teach button pressed
  -> TouchGesturesBehavior: Teach Shape From Stroke  "lightning"
  -> TouchGesturesBehavior: Save Shapes To Library
  -> Show text  "taught lightning"
```

**Teach Shape From Stroke** takes the stroke that was just drawn, smooths and normalises it, and stores it under the name. **Save Shapes To Library** then writes the library asset back to its `.tres` file so the rune ships with the project. If the stroke had fewer than **minimum_stroke_points** points, teaching quietly does nothing - draw a proper shape, not a tap.

### 6. Casting the taught rune

**Scenario:** Drawing a taught rune casts the matching spell, and the quality of the drawing scales the effect.

```
On Shape Drawn
  TouchGesturesBehavior: Shape Was  "lightning"
    -> Cast lightning  TouchGesturesBehavior.Shape Closeness()
  TouchGesturesBehavior: Shape Was  "circle"
    -> Cast shield
```

**On Shape Drawn** only fires when a match landed inside **shape_tolerance**, so an unrecognised scribble is simply silent. **Shape Closeness** is `1` for a near-exact drawing and falls towards `0` at the edge of the tolerance, which makes a natural damage or duration multiplier.

### 7. A gesture-locked door

**Scenario:** A vault opens on a specific drawn sigil, and a rough approximation should not be enough.

```
On Ready
  -> Set shape_tolerance  0.08

On Shape Drawn
  TouchGesturesBehavior: Shape Was  "vault_sigil"
    TouchGesturesBehavior.Shape Closeness() > 0.8
      -> Open the vault
  Else
    -> Show text  "the sigil fades"
```

Lowering **shape_tolerance** narrows what counts as a match at all, and the extra **Shape Closeness** check demands a genuinely accurate drawing on top of that. Both dials pull in the same direction, so tighten one at a time while testing.

### 8. Letter tracing that scores instead of judging

**Scenario:** A children's handwriting game shows a letter, the child traces it, and the attempt gets a star rating rather than a pass or fail.

```
On Shape Drawn
  TouchGesturesBehavior: Shape Was  current_letter
    -> Award stars  round(TouchGesturesBehavior.Shape Closeness() * 3)
    -> Show text  "nice " + TouchGesturesBehavior.Shape Name()
```

Because every template is compared both ways round, a child who traces a letter from the wrong end still matches. **Shape Name** echoes back what was recognised, which is handy when several letters are live at once.

### 9. Cancelling a gesture when a menu opens

**Scenario:** A pause panel opens mid-drag. The half-drawn stroke must not finish into a spell when the finger comes up.

```
On pause opened
  -> TouchGesturesBehavior: Clear Stroke
  -> Hide gesture trail
```

**Clear Stroke** throws away the points gathered so far, so the stroke can no longer reach **minimum_stroke_points** and cannot match anything. The swipe test still measures start to end, so also gate your own reactions while paused if a stray flick would matter.

### 10. A live gesture trail while drawing

**Scenario:** Show a fading trail as the finger moves, and only show it once the stroke is long enough to be a real gesture.

```
On Stroke Started
  -> Clear trail
  -> Show gesture trail

Every tick
  TouchGesturesBehavior.Stroke Points() > 4
    -> Set trail thickness  min(TouchGesturesBehavior.Stroke Length() / 400.0, 1.0)
```

**Stroke Points** counts the gathered points so far and **Stroke Length** measures the distance travelled along the whole line, not between its ends - so a tight scribble in one spot still reads as long, which is exactly what a trail's weight should follow.

### 11. Swapping rune sets per level

**Scenario:** Each level knows a different set of runes, loaded from its own library asset.

```
On level loaded
  -> Set shape_library  level_shape_library
  -> TouchGesturesBehavior: Load Shapes From Library
```

**Load Shapes From Library** clears what is currently loaded and reads the attached asset fresh, so pointing **shape_library** at a different `.tres` and calling it swaps the whole vocabulary. It also runs by itself when the behaviour starts, so the level's default set is loaded without a row.

### 12. Letting the player teach their own shortcut

**Scenario:** An accessibility option lets a player record whatever stroke is comfortable for them as the "open inventory" gesture, and keep it between sessions.

```
On record shortcut pressed
  -> Show text  "draw your gesture now"

On Shape Drawn
  -> TouchGesturesBehavior: Teach Shape From Stroke  "inventory"
  -> TouchGesturesBehavior: Save Shapes To Library
```

The player's own stroke becomes the template, so it already matches the way their hand moves. If they want to start over, **Forget Shape** with the same name removes it first.

### 13. Removing a shape when a spell is un-learned

**Scenario:** A spell is stripped by a curse, and drawing its rune should stop doing anything at all.

```
On spell forgotten
  TouchGesturesBehavior: Knows Shape  "fireball"
    -> TouchGesturesBehavior: Forget Shape  "fireball"
    -> TouchGesturesBehavior: Save Shapes To Library
    -> Show text  "the rune slips from memory"
```

**Knows Shape** guards the removal so the message only appears when the rune really was known, and **Forget Shape** drops it from both the live set and the attached library. Save afterwards if the loss should persist.

### 14. A photo browser that commits on a long swipe

**Scenario:** A gallery pages on a decisive swipe but springs back on a timid one, using the measured distance rather than a second threshold.

```
On Swipe
  TouchGesturesBehavior.Swipe Distance() > 200
    TouchGesturesBehavior: Swipe Was  "left"
      -> Next photo
    TouchGesturesBehavior: Swipe Was  "right"
      -> Previous photo
  Else
    -> Spring back
```

**Swipe Distance** is the straight-line travel in pixels, so you can keep **swipe_min_distance** generous enough that everything registers and then decide in the sheet what counts as decisive.

### 15. A practice mode that loosens everything

**Scenario:** A tutorial makes both swipes and shapes far more forgiving, then restores the real settings when the tutorial ends.

```
On tutorial started
  -> TouchGesturesBehavior: Set Swipe Thresholds  60, 1.0
  -> Set shape_tolerance  0.4
  -> TouchGesturesBehavior: Set Eight Way  false

On tutorial ended
  -> TouchGesturesBehavior: Set Swipe Thresholds  100, 0.4
  -> Set shape_tolerance  0.22
  -> TouchGesturesBehavior: Clear Stroke
```

Raising **swipe_max_seconds** to `1.0` lets a hesitant swipe still count, and a **shape_tolerance** of `0.4` accepts a much rougher drawing. Turning eight-way off during a tutorial also removes four directions a beginner can accidentally hit. Clear the stroke when you tighten things again so a lazy in-progress gesture cannot land under the new rules.

### Other use cases

**Rhythm-game flick charts.** Notes demand a swipe in a named direction on the beat, and the swipe speed grades the hit as good, great, or perfect.

**Map-drawing strategy orders.** A commander draws a route on the map and the taught shape decides the formation, while the stroke length sets how far the order extends.

**Signature capture in a shop scene.** The customer signs with a finger, the stroke length proves it was a real signature rather than a dot, and the outline is stored in a library for the receipt.

**Fishing and casting minigames.** A fast upward flick casts the line with distance scaled by swipe speed, and a downward flick sets the hook.

**Ghost-writing horror puzzles.** A spirit draws a sigil on the screen and the player must reproduce it, with the closeness value deciding whether the ritual completes or backfires.

---

## What a hand-written recogniser reads as

A project that gathers the touch events itself, without this behaviour, still reads as touch
bookkeeping - and the sheet says so, claiming the whole shape as one pattern and offering this pack
as the thing that does it properly:

![A hand-written stroke gatherer, claimed as swipes and drawn shapes](../images/swipe-gestures-reading.png)

## Tips and common mistakes

- **Nothing fires on desktop until you emulate touch.** The behavior listens for touch events only. Turn on Project Settings > Input Devices > Pointing > Emulate Touch From Mouse and the mouse starts producing them. This is the single most common "the pack is broken" report.
- **A stroke is a swipe or a shape, never both.** The swipe test runs first, and when it passes, the stroke returns immediately and no shape is matched. If your circles keep firing **On Swipe** instead of **On Shape Drawn**, they are being drawn fast enough and wide enough to look like a flick - raise **swipe_min_distance**, lower **swipe_max_seconds**, or ask the player to draw a little more deliberately.
- **Slow is what makes a drag a shape.** A slow drag over the same distance as a swipe is deliberately not a swipe. That is the mechanism the two halves use to stay out of each other's way, not a bug.
- **Teach before you match.** With no taught shapes, **On Shape Drawn** can never fire - the recogniser exits early when the shape set is empty. Teach at least one shape, or attach a library that already holds some.
- **Teaching a tap does nothing.** **Teach Shape From Stroke** refuses strokes with fewer than **minimum_stroke_points** points, and it refuses silently. If a shape will not teach, draw a longer line, or turn on **debug_logging** to see the point count it gathered.
- **Direction strings are exact.** **Swipe Was** compares strings literally: lowercase, one space, and the vertical part first in the diagonals (`"up left"`, `"down right"`). `"Left"`, `"LEFT"` and `"left up"` never match.
- **The diagonals do not exist until eight-way is on.** With **eight_way** off, a diagonal swipe reports as one of the four, so a `"up right"` condition simply never fires. Turn it on in the Inspector or with **Set Eight Way** first.
- **Angles count clockwise because screen Y points down.** `0` is right, `90` is down, `-90` is up. If your thrown objects fly the wrong way vertically, that is why.
- **Teaching updates the library there and then; saving is what puts it on disk.** **Teach Shape From Stroke** writes the shape straight into the attached library and marks that resource changed, so a shape taught while the editor is open is written out by the editor's own Save like any other edit. **Save Shapes To Library** is the explicit write a running game needs, and it now says why when it cannot do it: no library attached, or a library that has never been saved as a file and so has nowhere to write. With no library attached at all, taught shapes still last only for the run.
- **Raising tolerance too far makes shapes bleed into each other.** **shape_tolerance** is a single global dial. At `0.4` a rough circle and a rough square start looking alike, and the pack will confidently report the wrong one. Prefer a moderate tolerance plus a **Shape Closeness** check where accuracy really matters.
- **Read gesture context inside its trigger.** **Swipe Direction** / **Swipe Angle** / **Swipe Distance** / **Swipe Seconds** / **Swipe Speed** are meaningful inside **On Swipe**, and **Shape Name** / **Shape Closeness** inside **On Shape Drawn**. Read them there, not later, when the next gesture may already have overwritten them.
- **Shapes taught in one project and loaded into another must match the sample count.** The library stores outlines already smoothed to a fixed 24 points. A hand-edited dictionary entry with a different number of points is refused rather than stretched, so it silently never matches - always teach by drawing rather than editing the `.tres` by hand.
