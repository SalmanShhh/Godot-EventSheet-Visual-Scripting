# Common Game Patterns Without Code

State machines, timers, cooldowns, saving, tweens, randomness - the patterns every game needs,
written as event rows instead of GDScript. Each section below shows the code pattern being
replaced, the rows that replace it, and where to find them in the picker. If you have never
written the code versions, even better: you are skipping them entirely.

![The patterns as rows: Every X Seconds, Has Changed, cooldowns, Wait, Tween](images/code-patterns-rows.png)

## Run something every X seconds

The code version keeps a scratch timer variable, adds `delta` every frame, and resets it when it
overflows. The row version is one condition:

- Add a **Run every tick** event, then the condition **Every X Seconds** (System, Time).
- Everything in the actions column runs each time the interval elapses. No timer variable
  exists anywhere on your sheet.

## React only when a value changes

Updating a HUD every frame works, but juice ("pop the score label when it changes") needs to
know the exact tick a value became different. In code that is a `previous_value` variable and a
comparison you have to order correctly. As a row:

- Condition **Has Changed** (System, Run Context) watching `score` - true only on the tick the
  value becomes different.
- Pair it with a **Tween Property** action for one-row juice: score changes, label pops.

**Trigger Once** is its close cousin: Has Changed fires per change of a value, Trigger Once
fires once per time a whole condition set becomes true.

## Cooldowns by name

No `last_dash_time` variable, no clock math:

- **Start Cooldown** (System, Time) - `Start Cooldown "dash" for 1.5s`.
- **Cooldown Is Ready** (condition) - gate the dash event on it. A cooldown you never started
  counts as ready, so the first press always works.
- **Cooldown Time Left** (expression) - feed a progress bar or an ability icon sweep.

Cooldowns are per-node and keyed by the name string, so `"dash"` and `"attack"` never collide,
and two enemies' `"attack"` cooldowns are independent.

## Wait, then continue

**Wait** (System, Time) pauses the action list mid-flow: `Show message "Ready..."`, `Wait 1.0 seconds`,
`Show message "GO!"`. Everything below the Wait runs after the delay - the sheet reads top to
bottom exactly like the timeline it is. **Wait For Signal** does the same for "until something
happens" instead of "until time passes", and **Single Flight** (Run Context) keeps a waiting
event from stacking a second copy of itself while the first is still going.

## Remember a variable between runs

Right-click any sheet variable and choose **Remember Between Runs**. That is the whole feature:

- The variable loads its last saved value when the node enters the scene.
- Every remembered variable saves back automatically when the node leaves the tree (scene
  change or quitting the game), to `user://remembered.cfg`.
- A sheet with a class name saves under that name, so two sheets' variables never collide.

The fifteen lines of ConfigFile ritual this replaces are generated into your file where you can
read them - open the compiled script and look for `_ef_recall_remembered`. For whole save-game
systems (slots, versioning, migration), the Save Studio is the bigger tool; Remember Between
Runs is for "the high score should survive closing the game" and nothing heavier.

## A state machine you can read

Attach the **State Machine** behavior pack and the pattern that usually needs an enum, a match
statement, and transition bookkeeping becomes vocabulary:

- **Go to state** switches state (and only fires on a real change).
- **Current state is** is the condition each behavior event sits behind.
- **On any state change** triggers with `previous` and `next` - your enter/exit hook.
- **Time in state** tells how long the current state has been running: "flee for two seconds,
  then go back" is `Time in state > 2` then `Go to state previous_state`.
- **previous_state** always holds where you came from.

The shape that reads best: one named group for the machine, ONE **Every Physics Tick** event,
each STATE as a sub-event under it (its condition reads as the ◆ `Current state is "patrol"` header,
the same words the behavior publishes, so a hand-rolled machine and the pack read alike), and each
transition nested one level deeper with its own condition lane - so piling on more guards later
("and cooldown ready", "and player still visible") never means restructuring. The nesting is
exactly the code's own indentation: the tick event is `_physics_process`, each state sub-event
is a `match` branch one tab in, each transition the `if` one tab deeper.

![A state machine as a consumer writes it: one tick event, states as sub-events, transitions nested deeper](images/code-patterns-state-machine.png)

And the door swings both ways: a hand-written `enum` + `match` machine OPENS in this shape.
The `match` lifts into structured cases (byte-exact, like every lift), and because the match
subject is named `state`, the whole machine reads in plain words with zero conversion work:

- The enum shows as the machine's identity bar ("State is one of PATROL, CHASE or FLEE" -
  click it open for one row per value).
- The tick event's lane says **decides by state - 3 states below** instead of `match state:`.
- Each case is a `◆ State:` row; its plain statements read as sentences and calls
  (`Patrol Step ( delta )`).
- Each transition is a NESTED CONDITION ROW - the guard in the condition cell, in plain words
  (`Can See Player`, `Not Can See Player`, `hp < 20`), the state change as its action
  (`Set state to State.CHASE`). A small ƒ badge marks a guard that is a computed check rather
  than a variable. Branching never appears in the action lane - anywhere.
- Hovering any of it shows the exact GDScript line; saving reproduces the file byte-for-byte.

![A hand-written enum + match machine opened as a sheet](images/code-patterns-lifted-machine.png)

## Pick one node out of a group

The code version is a `for` loop with a `best` variable and a comparison - easy to get subtly
wrong. The expression version (Nodes, Picking) is one pick:

- **Nearest Node In Group** / **Furthest Node In Group** - by distance to this node.
- **Random Node In Group (empty-safe)** - uniform pick that returns nothing instead of crashing
  when the group is empty.
- **Group Member With Smallest/Largest Property** - weakest enemy (`hp`), slowest racer
  (`speed`), any property by name.

Set the result into a variable, then drive the following actions with it.

## Chance and randomness in plain words

The **Advanced Random** pack speaks probability the way designers do:

- **Chance** - a condition that is true 10% of the time when you write `Chance(10)`.
- **One In** - `One In(6)` for dice logic.
- **Pick From** - a random element of any list; **Shuffle Bag** draws every item once before
  any repeats (loot that feels fair); **Pick From Table** rolls a weighted `.tres` table you
  author as a data asset.

Because the pack is seeded, a run can be replayed exactly - set the seed once and your daily
challenge mode exists.

## Animate a property without a tween chain

**Tween Property** (System, Tween) is one action: the node, the property, the target value, the
duration, and easing dropdowns. Two Tween Property actions under the same event run as separate
one-shot tweens; **Tween Callback** runs something after a delay (the classic
"fade out, then free it").

## When a button is pressed

Signals connect themselves. The **HUD Kit** pack ships **On Button Pressed** (any descendant
button by name, no wiring), and **Connect Group Signal** (System, Signals) wires every current
member of a group to a handler in one action. Declaring your own signal on a sheet publishes an
**On <signal>** trigger for other sheets automatically.

## The second wave - more patterns as rows

Ten more spellings of everyday game code, shipped the same way:

![The second wave live: a Timeline with its beats as condition/action rows, Every 2 to 5 seconds, smooth damping, aiming, wrap, bob, toggle and a distance check](images/pattern-verbs.png)

- **Move Toward (smooth)** (Variables) - the frame-rate-INDEPENDENT damping (`1 - exp(-k*dt)`)
  compiled for you; works on numbers, vectors and colors. Drag the speed under Live Values to
  feel it.
- **Toggle** (Variables) - `paused = not paused` in one word.
- **As Clock Time** (Text expression) - 90 seconds reads "01:30".
- **Every X To Y Seconds** (Time) - spawner cadence that re-rolls each firing.
- **Is Within Distance / Turn Toward / Wrap Inside The Screen / Bob Up And Down** (Movement,
  2D) - prompts and aggro ranges, turret aiming with a real turn speed, the Asteroids rule,
  floating pickups - all without transform math or sin().
- **The Object Pool pack** - named pools with Create Pool / Spawn / Despawn / Prewarm, spawn
  and despawn triggers, and a `reset()` seam: a pooled scene that defines `reset()` gets it
  called on every spawn, so velocity and hp clear without the pool knowing them.
- **The Timeline block** - "at 0.0s Show Ready, at 1.0s Show GO": Insert > Timeline, then
  Add Step on the block; each beat is a condition/action row (the WHEN left, the WHAT right)
  and the compiled form is the await-chain you would have written.

![The Object Pool in use: Create Pool on ready, Spawn on a random cadence, Despawn on screen exited](images/pattern-pool.png)

## The third wave - game feel and directors

![The third wave: buffered coyote jumping, the wave director, knockback with i-frames and floating text, and the motion verbs](images/pattern-wave3.png)

- **Coyote time + input buffering.** The Platformer pack already ships both as Inspector
  feel-numbers (`coyote_time`, `jump_buffer_time`) - most users just tune. For custom
  controllers the generic rows exist: **Buffer Press / Press Is Buffered / Clear Buffer**
  (Time) and **Was Recently True** (Run Context) - `is_on_floor() was true within 0.1s` IS
  coyote time, spelled as a condition.
- **The wave director.** **On Group Emptied** fires the tick the last member leaves a group
  (never on a still-empty group at startup); **On Group Gains First Member** covers the other
  edge. `wave += 1`, `Start Wave ( wave )` - the whole rounds loop in one event.
- **Knockback.** **Push Away From** sets the impulse; **Apply Pushes** under Every Frame moves
  and decays it with the same honest exp form Move Toward uses.
- **Springs.** Already a whole pack: the **Spring** behavior gives named springs with real
  velocity, overshoot and settle - squash-and-stretch juice as single rows.
- **Magnet, orbit, charge.** **Pull Group Toward** (the vacuum-pickup loop), **Orbit Around**
  (the sin/cos pair, angle hidden in node metadata), **Charge Toward** (hold-to-charge that
  clamps itself).
- **I-frames.** The Health pack's **Grant Invincibility / Is Invincible** - and its own Take
  Damage respects them, so an invincible hit never lands and never fires On Damaged. The Flash
  pack is the flicker.
- **Progress Of / Percent Of** (Math & Random) - the `inverse_lerp` nobody finds, clamped,
  feeding bars directly.
- **Repeat With Delay** (Time) - `5 times, 0.1s apart:` burst fire; suspends like Wait.
- **Pop Floating Text** (HUD Kit) - the score popup's label, drift tween and cleanup as one
  action.

## The fourth wave - goals, places, and firsts

![The fourth wave: a quest advancing, checkpoints, interaction focus, a phase cycle, the metric distance and Only Once Ever](images/pattern-wave4.png)

- **The Quest pack** - quests as `.tres` data assets (objectives, chains, reward notes,
  authored in the Inspector): `Start Quest`, `Advance Objective "gems"`, triggers for
  started/objective/completed, and `Objective Text` ("3/5") feeding the journal. Register a
  chained quest first; Save/Load ride the Remember file.
- **Checkpoint** - `Set Checkpoint Here`, `Respawn At Checkpoint` (restores position and calls
  the host's `reset()` - the same seam the Object Pool wake uses), `On Respawned` for the
  camera snap.
- **Interaction** - `Focus Nearest Interactable` under Every Frame, `Interact With Focus` on
  the press, `On Interacted` on the thing's own sheet - a chest, a door and an NPC differ only
  in what their On Interacted does.
- **Phase Cycle** - `Cycle Phases "day,night" every 60s`, `On Phase Changed`, and
  `Phase Progress` (0-1) for sun dials.
- **Home & Leash** - a home point, `Is Beyond Home` and `Distance From Home` with FIVE metric
  geometries (straight line, horizontal/vertical only, grid steps, king moves), `Return Home`
  with its arrival trigger.
- **Is Within Distance (choose metric)** - the same five-geometry dropdown on the generic
  condition, and `Tiles(3)` sizes any distance by the `eventforge/tile_size` project setting.
- **Only Once Ever** - Trigger Once across RUNS (tutorial hints), stored in the Remember file;
  `Forget First Time` re-arms it.
- **Vanish, Respawn In** - the pickup that comes back, reset seam included.
- **Ramped** - the difficulty curve as a value (`Every Ramped(2, -0.3, 0.5) seconds` is a
  spawner that speeds up); `Start Ramp Clock` marks minute zero.

## The same patterns, hand-written, opened as a sheet

You do not have to author a pattern from the picker for the sheet to know it is one. Open a script
that already writes one of these shapes by hand and it reads as the same events, and the event that
owns it says which pattern it is, with the exact lines that made the sheet think so.

- **A countdown.** `cooldown -= delta` in a tick, and `cooldown <= 0` asked somewhere, reads
  `Count down cooldown (by dt)`, `cooldown has run out` and `Start cooldown for 0.5 seconds`. Both
  halves are needed: a number that shrinks by a delta and is never asked about is a subtraction, and
  the row keeps saying so. `max(0.0, x - delta)` and `move_toward(x, 0, delta)` read the same with
  `(never below 0)` on the end.
- **An object pool.** `var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()`
  followed by `add_child(b)` is one `System ▸ Create object Bullet [pooled]` row; `pool.push_back(b)`
  is `b ▸ Return to pool`. Pooling is how the object is got hold of, not a different thing to do
  with it, which is why the row is the ordinary Create object row with a chip.
- **A sequence.** A function whose rows alternate `await get_tree().create_timer(N).timeout` and
  actions wears a `sequence · 3 s` chip on its header, with the total of its waits. A wait on
  something whose length nobody knows (an animation, a signal) adds `+ a wait` rather than a wrong
  total.
- **Saving.** ConfigFile lines read under **Local Storage**: `Set item player/score to score`,
  `Local Storage.Item("player/score") (or 0)`, `Save`, `Load`, `has item player/score`, and
  `cfg.load(path) != OK` reads `save file is missing`. The path is on hover.
- **Existence.** `is_instance_valid(t)` is `t exists`, `target = null` is `Forget target`, and
  `get_parent().remove_child(self)` is `Remove from layout (kept alive, not destroyed)` - which is
  the answer to the first question anyone has about a removed object.
- **Lists and tables.** `stats.get("hp", 100)` is `stats "hp" (or 100 when missing)`,
  `items.slice(0, 3)` is `the first 3 of items`, a one-line `sort_custom` is
  `Sort items by price (lowest first)`, a one-line `reduce` is `the sum of price over items`,
  `items.has(sword)` is `items contains sword`, and `commands["equip"].call()` is
  `Functions ▸ Call the function stored in commands "equip"`. A lambda written over two lines keeps
  its Script block - a sentence may only stand for a shape it can see whole.

## Effects, tilemaps and the camera

![The effect, tilemap and camera rows an opened script reads as](images/pattern-effects-tilemap-camera.png)

Three families of line nearly every 2D game writes, and the sheet has words for all three. They
read the same whether you typed them into a `.gd` file or dropped them from the picker, and the
event that owns one is marked as the pattern it is.

- **Effects** (the Effects section of the picker, on any CanvasItem) - a ShaderMaterial parameter
  IS an effect parameter. `Set effect parameter flash to 1`, the expression
  `sprite's effect parameter "flash"`, `Set effect to outline`, `Remove effect`, and
  `Tween effect parameter dissolve from 0 to 1 in 0.5 seconds` for the one tween shape an effect
  has a sentence for. A hand-written `sprite.material.set_shader_parameter("flash", 1.0)` reads as
  the first of those, and `tween.tween_method(func(v): mat.set_shader_parameter("dissolve", v),
  0.0, 1.0, 0.5)` reads as the last one - one row, on the material it drives.
- **Tilemaps** (the Tilemap section) - `Set tile at cell to 2, 0` with the layer and the tileset
  said quietly after it, `Erase tile at cell`, and the three coordinate questions as the names you
  type into a field: `TileAt(cell)`, `PositionToTile(position)`, `TileToPosition(cell)`. A tile's
  own data is one condition, `tile at cell has solid set` - the guard and the lookup a script
  spells over two lines. Both node generations read alike: the older node names its layer first,
  and the reading says so behind the sentence.
- **Camera** (the Camera section, on a Camera2D) - `Make current`, `Set zoom to 200%`,
  `Set scroll limits 0 to 1920`, `Set smoothing on`, and `Scroll toward target at 5 (per second)`
  for the lerp-follow every 2D game writes. A run of adjacent `limit_left` / `limit_right` /
  `limit_top` / `limit_bottom` writes reads as ONE scroll-limits row; hover it to see every line
  it stands for, and the file keeps all four exactly as they were.

## A loading screen that shows progress

Godot can load the next layout on another thread while the current one keeps running. Written by
hand that is four `ResourceLoader` calls, a status enum and an array passed by reference; as rows it
is three sentences and one expression, and each of them writes exactly the line the reading
recognises - so a loading screen you type and one you pick are the same bytes.

1. On start of layout: **System ▸ Load layout `"res://levels/level_2.tscn"` in the background**.
2. Every tick, feed the bar: **ProgressBar ▸ Set value to `System.LoadingProgress * 100`**. The
   expression answers 0 to 1, so multiply by 100 for a percentage.
3. Add a condition **System ▸ layout `"res://levels/level_2.tscn"` has finished loading**, and under
   it **System ▸ Go to layout `"res://levels/level_2.tscn"`**. That switch reuses what was already
   loaded, so there is no second load and no pause.

Use the same path in all three rows - that is what ties them together. Open the file afterwards and
it reads back as those three sentences, with the layout named the way the file is named.

## Movement, multiplayer and paths in one vocabulary

Three more shapes every Godot script makes now read - and are written - as the rows a behavior
already has words for.

- **Movement, on a `CharacterBody2D` or `CharacterBody3D`**: **Apply gravity**, **Accelerate x
  toward … at … (per second)**, **Limit speed to …**, **Move (and slide along what it hits)**,
  **Disable collisions with …**, **Ignore collisions with …**, **Set angle toward …** and **Rotate
  toward … at … (per second)**. A plain node's `velocity` is just a variable, so none of these words
  is claimed on one.
- **Multiplayer**: mark a function as a message, then **Multiplayer ▸ Send `<message>` to everyone**
  / **to the host** / **to one peer**, ask **Is host** or **Owns this object**, and read
  **Multiplayer.MyID**. An `@rpc` function reads with its name in the condition lane and its mode
  words muted beside it - *from any peer · runs here too · reliable*.
- **Navigation**: **Find path to …**, **Move along path at …** and **Has arrived**. When the file
  wires the avoidance callback, the move row says **(avoiding others)**.

Where a shipped behavior could replace the hand-written block, the sheet says so: a body that
applies gravity offers the Platformer pack, one that only steers offers Eight Direction, and a
navigation block offers the pathfinding pack that matches its dimension.

## Sprites, UI, sound and game feel - the same words either way

![A sprite, UI, sound and game-feel script opened as a sheet: mirrored, animation frame, focus, master volume, sound, pitch, shake and bob](images/reading-sprite-sound-juice.png)

These four families are most of what a small script actually does, and each of them now reads and
is written in the same words:

- **Sprites and animation** - `Set mirrored` (and `Set mirrored when dir < 0` when a test decides
  it), `Set flipped`, `Set animation frame`, `Set animation speed`, `Set opacity`, `Set image`,
  `Is playing`, plus an animation tree's `Set blend blend position` and
  `Travel to animation state "Hurt"`.
- **UI** - `Set focus`, `Set progress to hp of max hp` (the value and the maximum in one row),
  `Open centered`, `Set text to "Score: " & score`, `Set master volume to v (0 to 1)` and
  `Pause the game`.
- **Sound** - `Set sound to jump.wav`, `Set pitch`, `Set bus to SFX`, `Set volume to 50%` (the
  decibel conversion is done for you and Godot's own line is one hover away), `Seek to 12 seconds`,
  `Play sound` and `Is playing`.
- **Game feel** - `Shake by 4`, `Hitstop for 0.05 seconds`, `Bob y (sine, magnitude 8, 3 per
  second)`, `Flash red for 0.1 seconds` and `Ease size back to normal at 10 (per second)`. The
  Juice, Sine and Flash behaviors ship exactly these words with state of their own, so attaching
  one of them is the first option and these free actions are the second.

A hand-written script that already does any of this reads as those rows the moment you open it,
with the exact GDScript still on the hover - and the row the picker drops writes the same bytes
back, so the two can never drift apart.
## A hand-rolled behavior, in the behavior's own words

Some of the most common shapes in any project are a behavior that already ships as a pack, written
out by hand. Those now read as the behavior they are, so a jam script and a sheet that attached the
pack say the same thing:

- **A projectile is a Bullet.** `velocity = Vector2.RIGHT.rotated(rotation) * speed` reads **Set
  angle of motion to angle**; `position += velocity * delta` (or `move_and_collide(velocity * delta)`)
  reads **Move**; `speed += accel * delta` reads **Set speed to speed** *accelerating by accel*;
  `velocity.y += gravity * delta` reads **Set gravity to gravity**; `velocity.bounce(n)` reads
  **Bounce off solids**; and `position.distance_to(start) > range_px` reads **Distance travelled >
  range px**.
- **A turret is a Turret.** The nearest-in-family loop is claimed as **Acquire nearest enemy within
  range px**, `if target:` reads **Has target**, and the `lerp_angle` toward the target reads
  **Rotate toward target at turn rate**.
- **A glide is Move To.** `position.move_toward(destination, speed * delta)` reads **Move toward
  destination at speed**, the flag beside it reads **Start moving** / **Is moving** / **Stop**, and
  the distance check reads **Has arrived**.
- **Five one-liners name themselves.** **Rotate clockwise at k (degrees per second)**, **Wrap around
  layout horizontally**, **Bound to layout (inside …)**, **Pin to anchor (position · offset …)** and
  **Fade out over 1 seconds (then destroy)**.

Each of these claims its pattern on the event that owns it, with the exact source lines as the
evidence and the pack that could replace the shape - Bullet, Weapon Kit, Move To, Rotate, Wrap,
Bound To, Pin, Fade. Every ambiguous half is gated on something only a real instance of the shape can
say: an acceleration reads as a bullet's only in a file that also writes the angle-of-motion line and
the step, so a lone piece of arithmetic keeps the reading it had.

All of them are authorable in the same words. The picker writes **Set Angle Of Motion**, **Move**,
**Bounce Off Solids**, **Move Toward Position**, **Rotate Clockwise**, **Wrap Around Layout
Horizontally / Vertically**, **Bound To Layout**, **Pin To** and **Pin Angle To** as exactly the
lines above, so a dropped row and a typed line are the same bytes; the four shapes a shipped row
already writes keep that row (**Add To Variable** for the acceleration, **Apply Gravity**, **Distance
To**, **Is Within Distance**) rather than gaining a duplicate. Where a pack covers the whole shape,
attaching it is the tidier answer, and that is what the pattern chip offers first.

## Where these live

Everything above except the State Machine, Advanced Random, and HUD Kit sections is built into
every sheet - open the picker and browse System's Time, Run Context, Tween, and Nodes: Picking
sections. The three packs install from the addon browser like any other behavior, and each is
itself an event sheet: open it, read it, extend it.

## When the sheet recognises a pattern you already wrote

Everything above is about writing a pattern from the picker. The other direction is just as
supported: open a hand-written `.gd` file as a sheet and the reading recognises the shapes it
knows, then says so.

![An opened cooldown script: the event that counts the number down wears a Cooldown marker, and the head bar says 1 pattern, 1 adoptable](images/pattern-chip.png)

An event that IS a pattern wears a muted **⟡** chip naming it, at the end of its first condition
line. Only the event that OWNS the shape gets one - the row that counts the number down, the
function that hands an object out - never every row that mentions the same variable, because the
chip is a name for the whole idea rather than a label on each of its parts.

- **Hover the chip** for the one line that says what the pattern is, and the offer to open its
  page in the Manual. **Click it** to open that page.
- **Hover any row of the event** for the evidence: *read as the Cooldown pattern because:
  `cooldown -= delta`, `cooldown <= 0.0`, `cooldown = 0.5`*. Those are the exact lines in your
  file. A pattern reading is a claim spanning several lines, so it owes you the lines.
- **View ▸ Patterns** turns the whole thing off. The sheet then reads as its own plain sentences,
  which is how you check a claim you doubt.
- The head bar's coverage chip grows two counts - *reads as events · 4 patterns · 2 adoptable* -
  and clicking it walks the script blocks and then the ⟡ events, one per click.

### Adopt behavior

When a shipped behavior could do what the hand-written shape does, the event's right-click menu
offers **Adopt behavior: <name>…**. It opens a preview first, never a change:

- the events as they read now on the left, as they would read after adopting on the right,
- every row that changes marked,
- and a **keeps working because** line saying what was checked - that the variable is used only by
  these events, that the behavior counts the same seconds the code did, that the condition becomes
  true at the same moment.

![The Adopt behavior preview: the events as they read now beside the events after adopting, with a keeps-working-because line](images/pattern-adopt-dialog.png)

Press Adopt and the rewrite lands in one undo step. Every line of the file the plan did not list
is untouched, so the rest of your script re-emits exactly as it was.

Adopting is **refused with a reason** when your code does something the behavior cannot - a
countdown nothing ever restarts has no length for the behavior to keep, a countdown compared to
something other than zero needs a number the behavior does not have, and a countdown a readout
also reads would lose its readout. A refusal is the feature working: the alternative is quietly
rewriting your game into one that does less.

### The Manual page, and the Doctor

![The Common Game Patterns page: the hand-written GDScript on the left, the same file read as events on the right](images/pattern-manual-page.png)

**Manual ▸ Common Game Patterns** shows every pattern as two columns - the hand-written GDScript
on the left, the same text read as events on the right. The right column is drawn by the same
renderer your sheet uses, from the same file the reading tests open, so the page cannot show you a
shape the sheet does not actually read. Each one has Insert (put these rows in my sheet), Try it
(open them in a scratch sheet), and Adopt behavior where one ships. **Add ▸ Pattern…** opens the
same page, most common first.

The Doctor knows the halves of every pattern it recognises, so it can spot the classic
half-written ones: a countdown that never restarts, a pooled object never returned to the pool, a
state set but never asked about, a timer started on entering a state and never stopped on leaving.
Each finding points at the event. It also leaves a quiet note - *this block is the Cooldown
behavior - Adopt behavior?* - which is how the swap above gets discovered in the first place.
