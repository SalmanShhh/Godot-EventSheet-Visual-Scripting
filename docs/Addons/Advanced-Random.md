# Advanced Random

Advanced Random is a randomness toolkit you drive entirely from event-sheet rows. It bundles seeded number generators, dice, a normal (bell-curve) distribution, smooth Perlin/Simplex noise, permutation tables, shuffle bags that draw without repeats, weighted picks, and plain-language chance conditions. It ships as the **`AdvancedRandom`** autoload singleton, so every sheet in your project can call it with no wiring, no node to attach, and no scene setup. One shared generator means one shared seed - pin it and an entire run replays identically.

Because it is an autoload, you write `AdvancedRandom: Set Seed  12345` from any sheet and read `AdvancedRandom.Roll Dice(6)` anywhere else. It never spawns anything, moves anything, or plays a sound. It just hands you numbers, picks, and yes/no rolls - what you do with each is up to you.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Odds as a data asset: RandomTableResource](#odds-as-a-data-asset-randomtableresource)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Chance-based events.** Critical hits, dodge rolls, "did the trap trigger" - `Chance(15)` reads as "15% of the time" with no float math to eyeball.
- **Rare surprises.** A 1-in-1000 shiny variant, a 1-in-50 golden apple, a 1-in-20 double drop - `One In  n` says exactly that.
- **Tabletop-style dice.** `Roll Dice  6` and `Roll Dice  20` give you clean 1-to-N rolls for combat, board games, and skill checks.
- **Stat and damage variation.** `Normal (Gaussian)` clusters most results near an average with rare extremes, so damage numbers feel organic instead of flatly uniform.
- **Procedural terrain and heightmaps.** `Noise 2D` over a grid gives smooth, continuous hills and valleys; tune the scale with Set Noise Frequency and the detail with Set Noise Octaves.
- **Organic motion.** Feed time into `Noise 1D` for gentle camera drift, torch-flicker, or a fish that wanders instead of jittering.
- **Fair randomness with shuffle bags.** A bag of enemy types or power-ups draws each once before any repeat, so players never hit a frustrating streak.
- **Weighted drops without percentage math.** `Weighted Index` picks in proportion to a weights array - "common 70, rare 25, epic 5" just works.
- **Reproducible runs.** A fixed `seed_on_start` (or `Set Seed`) makes a daily challenge, a bug report, or a speedrun seed replay the exact same sequence for everyone.
- **Scatter and placement.** `Random Range` spreads decorations, spawn points, and offsets across an area; `Random Sign` flips a direction left or right.
- **Deterministic shuffled orders.** A permutation table is a shuffled deck order you generate once and read back by index - same seed, same order, every run.

---

## Core concepts

The whole pack is a handful of small ideas sitting on one shared generator. Once these click, the rest is just picking the right expression.

**One shared generator.** Advanced Random owns a single random number generator and a single noise generator for the whole game. Every number, dice roll, pick, and noise sample comes from them. That is what makes seeding powerful - one seed pins *everything* at once.

**Seeds make runs reproducible.** A seed is the starting point of the sequence. Set the same seed and you get the same stream of results forever after. Set the `seed_on_start` Inspector value to any non-zero number for a fixed run, or leave it 0 for a fresh random run each launch. At runtime, `Set Seed  12345` pins both numbers and noise; `Randomize Seed` throws the pin away and goes unpredictable again.

**Numbers come in flavors.** `Random (0-1)` is the raw uniform float. `Random Range` and `Random Int` give you a uniform value between a min and max. `Roll Dice` is 1-to-N. `Random Sign` is a coin flip between -1 and +1. `Normal (Gaussian)` is the odd one out: instead of every value being equally likely, results cluster around a `mean` and thin out toward the edges by a `deviation` - that is the bell curve, ideal for "usually average, occasionally extreme."

**Chance is a condition, not a number.** `Chance  percent` and `One In  n` return true or false directly, so you drop them into an event's condition slot. `Chance(5)` is true roughly 5% of the time; `One In  20` is true roughly once every twenty checks. No comparing a random float to a threshold by hand.

**Noise is smooth, not jumpy.** Plain random values have no relationship to each other - each is a fresh dice roll. Noise is different: nearby inputs give nearby outputs, so a line of `Noise 1D` samples looks like a gentle wavy curve, and a grid of `Noise 2D` looks like rolling terrain. All three noise expressions return a value in the -1 to 1 range. Three knobs shape it: **Set Noise Type** picks the algorithm (0 Simplex, 1 Simplex Smooth, 2 Cellular, 3 Perlin, 4 Value Cubic, 5 Value), **Set Noise Frequency** sets the scale (lower = smoother, larger features; higher = busier), and **Set Noise Octaves** layers in fine detail.

**Picking from a list.** `Pick From` returns one uniformly-random element of an array - every option equally likely. `Weighted Index` instead returns an *index* chosen in proportion to a weights array, so heavier entries come up more often. You pass weights like `[70, 25, 5]` and it hands back 0, 1, or 2 in those proportions - you then use that index into your own parallel array of items. When keeping those two arrays in step gets tiresome, author the odds as a **RandomTableResource** `.tres` instead (value and weight side by side in an Inspector table) and draw from it with `Pick From Table`.

**Shuffle bags draw without repeats.** A shuffle bag is a named pool of items. `Make Shuffle Bag  "spawns", [...]` fills it; `Shuffle Bag Pick  "spawns"` draws one out. The trick: every item is drawn once before any repeats, and when the bag empties it silently refills. This gives "random but fair" sequences - great for enemy waves or music tracks where a real repeat feels like a bug.

**Permutation tables are a fixed shuffled order.** `Generate Permutation Table  size` builds a shuffled list of the numbers 0 to size-1 once. Then `Permutation Value  index` reads position `index` back out (wrapping around past the end). Same seed, same table, every run - so it is a reproducible shuffled deck order you can index into deterministically.

---

## Setup

There is nothing to attach and nothing to place in a scene. Advanced Random registers itself as the **`AdvancedRandom`** autoload, so the singleton exists from the first frame and is reachable from every sheet.

The one setting worth knowing is on the autoload itself. Select the `AdvancedRandom` autoload and set `seed_on_start` in the Inspector:

| Property | Type | Default | What it does |
|---|---|---|---|
| `seed_on_start` | int | `0` | The seed applied automatically when the game starts. `0` = a fresh random seed each run (unpredictable). Any other value = a reproducible run: the same seed produces the same sequence of numbers and noise every launch. |

A minimal first example, as event-sheet rows - roll for a critical hit whenever the player attacks, and pick a random reward when an enemy dies:

```
On player attack
  [ if AdvancedRandom.Chance(20) ]
    -> Deal double damage
    -> Show text "Critical!"

On enemy killed
  -> Set variable reward = AdvancedRandom.Pick From(["coin", "potion", "gem"])
  -> Spawn pickup named reward
```

`Chance(20)` is true about one attack in five. `Pick From` returns one of the three strings with equal odds. Neither needs any setup on ready - the singleton is already live. If you want the whole run to be reproducible (for a daily challenge or a bug repro), set `seed_on_start` to a fixed number in the Inspector, or call `AdvancedRandom: Set Seed  12345` yourself before the first roll.

---

## ACE reference

Every row below is exactly what the pack exposes. Parameter names and types are shown in order. Actions are called as `AdvancedRandom: <Action>  args`; expressions and conditions are read as `AdvancedRandom.<Name>(args)`.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Seed | `seed_value` (int) | Sets the seed for BOTH numbers and noise - the same seed reproduces the same sequence. |
| Randomize Seed | (none) | Picks a fresh, unpredictable seed (non-reproducible). |
| Set Noise Type | `noise_type` (int) | Chooses the noise algorithm: 0 Simplex, 1 Simplex Smooth, 2 Cellular, 3 Perlin, 4 Value Cubic, 5 Value. |
| Set Noise Frequency | `frequency` (float) | Sets the noise scale. Lower = smoother / larger features; higher = noisier (default 0.01). |
| Set Noise Octaves | `octaves` (int) | Sets the fractal detail layers - more octaves add fine detail (fractal / fBm noise). |
| Generate Permutation Table | `size` (int) | Builds a shuffled 0..size-1 table (read it back with the Permutation Value expression) - a fixed deck order. |
| Make Shuffle Bag | `bag_name` (String), `items` (Array) | Creates a named bag of items - Shuffle Bag Pick then draws each once before any repeats. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Chance | `percent` (float) | True roughly `percent` of the time (0-100). For example `Chance(5)` for a 5% event. |
| One In | `n` (int) | True with a 1-in-`n` probability. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Random (0-1) | (none) | float | A uniform float in the 0 to 1 range (1 excluded). |
| Random Range | `minimum` (float), `maximum` (float) | float | A uniform float between min and max. |
| Random Int | `minimum` (int), `maximum` (int) | int | A uniform integer between min and max (inclusive). |
| Roll Dice | `sides` (int) | int | Rolls a die with the given number of sides (1 to sides). |
| Random Sign | (none) | int | Either -1 or +1. |
| Normal (Gaussian) | `mean` (float), `deviation` (float) | float | A normally-distributed float clustered around mean, spread by deviation. |
| Noise 1D | `x` (float) | float | Smooth noise along a line at x - returns a value in -1 to 1. |
| Noise 2D | `x` (float), `y` (float) | float | Smooth noise at (x, y) - great for terrain / heightmaps; returns -1 to 1. |
| Noise 3D | `x` (float), `y` (float), `z` (float) | float | Smooth noise at (x, y, z) - returns -1 to 1. |
| Permutation Value | `index` (int) | int | Reads `index` (wrapped) from the permutation table - generate the table first. |
| Pick From | `options` (Array) | Variant | A uniformly-random element of the array (null if empty). |
| Weighted Index | `weights` (Array) | int | An index chosen in proportion to the weights array (heavier = likelier). |
| Pick From Table | `table` (Resource) | String | A weighted-random value drawn from a **RandomTableResource** (a `.tres` whose value/weight pairs you fill in the Inspector), so your odds live in a data asset instead of parallel arrays in the sheet. `""` when the table is empty. |
| Shuffle Bag Pick | `bag_name` (String) | Variant | Draws the next item from a named bag - every item appears once before any repeat. |

### Triggers

Advanced Random ships no triggers. It is a pure query-and-set toolkit: you *call* an action to configure it and *read* an expression or condition to get a result, all inside your own events. There is no callback to listen for - the answer comes back the instant you ask for it.

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `seed_on_start` | int | `0` | Seed applied on startup. `0` = a fresh random seed each run; any other value = reproducible runs. |

---

## Use cases

Each example uses only real ACE display names. Rows starting with `->` are actions; the lines above them are triggers or conditions. Expressions are read inline as `AdvancedRandom.<Name>(args)`.

### 1. Critical hit chance

A percent chance that reads like plain English. `Chance(15)` is true about one attack in seven.

```
On player attack
  [ if AdvancedRandom.Chance(15) ]
    -> Deal damage x 2
    -> Show floating text "CRIT!"
  [ else ]
    -> Deal normal damage
```

### 2. A rare shiny variant

`One In  n` is the natural way to write long-odds events. Roll it once when each creature spawns.

```
On creature spawned
  [ if AdvancedRandom.One In(1000) ]
    -> Set creature.is_shiny = true
    -> Swap to shiny sprite
```

### 3. Tabletop dice for combat

`Roll Dice` gives clean 1-to-N results. A d20 attack roll plus a d6 damage roll, straight into variables.

```
On attack declared
  -> Set variable attack_roll = AdvancedRandom.Roll Dice(20)
  [ if attack_roll >= enemy.armor_class ]
    -> Set variable damage = AdvancedRandom.Roll Dice(6) + strength_mod
    -> Apply damage to enemy
```

### 4. Bell-curve damage variation

`Normal (Gaussian)` clusters most hits near the average with rare high and low swings, which feels more alive than a flat range. Mean 10, deviation 2 keeps most hits between about 8 and 12.

```
On hit landed
  -> Set variable dmg = AdvancedRandom.Normal (Gaussian)(10, 2)
  -> Apply max(1, round(dmg)) damage
```

### 5. Perlin terrain heightmap

Configure the noise once, then sample `Noise 2D` across a grid to get smooth, continuous height. A low frequency makes broad rolling hills; octaves add finer bumps.

```
On generate terrain
  -> AdvancedRandom: Set Noise Type  3
  -> AdvancedRandom: Set Noise Frequency  0.008
  -> AdvancedRandom: Set Noise Octaves  4
  -> For each tile (tx, ty):
       -> Set tile height = AdvancedRandom.Noise 2D(tx, ty) * 100
```

Noise type 3 is Perlin. The output is -1 to 1, so multiplying by 100 gives heights from -100 to 100.

### 6. Smooth camera drift with 1D noise

Feed a slowly-advancing time value into `Noise 1D` for a gentle, non-repeating handheld sway. Because noise is continuous, the camera glides instead of snapping.

```
On process (delta)
  -> Set variable t = t + delta * 0.5
  -> Set camera.offset.x = AdvancedRandom.Noise 1D(t) * 8
  -> Set camera.offset.y = AdvancedRandom.Noise 1D(t + 100) * 8
```

Offsetting the y sample by 100 keeps the two axes from moving in lockstep.

### 7. Scatter decorations across an area

`Random Range` spreads objects over a region; `Random Sign` flips their facing. Great for grass, rocks, and clutter.

```
On spawn decorations (loop 40 times)
  -> Set variable px = AdvancedRandom.Random Range(0, 1920)
  -> Set variable py = AdvancedRandom.Random Range(0, 1080)
  -> Spawn bush at (px, py)
  -> Set bush.scale.x = AdvancedRandom.Random Sign()
```

### 8. Fair enemy waves with a shuffle bag

A shuffle bag draws every enemy type once before repeating, so a wave never dumps four of the same foe by unlucky chance.

```
On Ready
  -> AdvancedRandom: Make Shuffle Bag  "wave", ["grunt", "archer", "brute", "flyer"]

On spawn slot ready
  -> Set variable next = AdvancedRandom.Shuffle Bag Pick("wave")
  -> Spawn enemy named next
```

When all four have been drawn, the bag refills automatically and reshuffles.

### 9. Weighted loot rarity

`Weighted Index` returns 0, 1, or 2 in proportion to the weights, which you use to index a parallel array of item ids. No percentage math - just ratios.

```
On chest opened
  -> Set variable tiers = ["common", "rare", "epic"]
  -> Set variable i = AdvancedRandom.Weighted Index([70, 25, 5])
  -> Grant loot of tier: tiers[i]
```

Common comes up about 70% of the time, rare 25%, epic 5%.

### 10. Random taunt line

`Pick From` grabs one element with equal odds - perfect for barks, idle animations, or flavor text.

```
On enemy spots player
  -> Set variable line = AdvancedRandom.Pick From(["You'll regret that!", "Come here!", "Is that all?"])
  -> Show speech bubble: line
```

### 11. Reproducible daily challenge

Seed the whole run from the calendar day so every player faces the identical layout, drops, and dice for that day. Set it once before anything rolls.

```
On daily run start
  -> AdvancedRandom: Set Seed  today_as_number
  -> Generate level
  -> Populate loot

On run finished
  -> AdvancedRandom: Randomize Seed
```

Calling `Randomize Seed` at the end restores unpredictable behavior for free-play.

### 12. Deterministic shuffled deck order

A permutation table is a shuffled order you generate once and read back by index. With a fixed seed the order is identical every run, so a "puzzle of the day" deals the same cards to everyone.

```
On deal cards
  -> AdvancedRandom: Set Seed  daily_seed
  -> AdvancedRandom: Generate Permutation Table  52
  -> For draw slot d in 0..4:
       -> Set variable card = AdvancedRandom.Permutation Value(d)
       -> Add card to hand
```

`Permutation Value` wraps if you index past 52, so you never read out of bounds.

### 13. Random pitch on a sound

`Random Range` gives footsteps and impacts a little pitch variety so a repeated clip does not sound mechanical.

```
On footstep
  -> Play sound "step"
  -> Set sound.pitch_scale = AdvancedRandom.Random Range(0.9, 1.1)
```

### 14. Organic wandering fish with layered noise

Combine two noise samples to steer a fish that drifts naturally. Advancing one time value feeds both the angle and a slow speed wobble, so the path curves instead of zig-zagging.

```
On process (delta)
  -> Set variable t = t + delta
  -> Set variable angle = AdvancedRandom.Noise 1D(t * 0.3) * PI
  -> Set fish.velocity = Vector2(cos(angle), sin(angle)) * 40
```

### 15. Coin-flip branching

`Random Sign` is a one-call coin flip. Multiply an offset by it to dodge left or right, or branch on its value.

```
On enemy dodge
  -> Set variable dir = AdvancedRandom.Random Sign()
  -> Move enemy by (dir * 120, 0)
```

### Other use cases

**Slot machine reels.** Each reel picks its symbol with Weighted Index so jackpot symbols stay rare, and a Chance condition decides whether a bonus round triggers on top. The weights array is the whole payout tuning surface.

**Music playlist that never repeats.** Fill a shuffle bag with your track names and draw the next song with Shuffle Bag Pick whenever one ends - every track plays once before any comes around again, so the soundtrack feels curated instead of random.

**Dynamic weather.** Feed the game clock into Noise 1D and read the result as wind strength or storm intensity - weather drifts smoothly between calm and rough instead of snapping, and a fixed seed makes the same day play out identically.

**Cave wall texture from cellular noise.** Set Noise Type to Cellular and sample Noise 2D across a tile grid to carve cracked, cell-like rock patterns that read very differently from rolling Perlin hills.

**Crowd variety.** When spawning background NPCs, Pick From chooses a skin, Random Range nudges the walk speed, and Random Sign flips which way each one faces, so a copy-pasted crowd stops looking cloned.

---

## Odds as a data asset: RandomTableResource

`Weighted Index` works from a weights array you keep in step with a parallel array of items. That is fine for three outcomes and tiresome for thirty. **RandomTableResource** puts both columns in one file instead.

It is a plain Godot `Resource` you create as a `.tres`, with a single `entries` grid you fill in the Inspector:

| Column | What it is |
| --- | --- |
| `value` | The outcome - any string: an item id, a name, a scene path. |
| `weight` | How common it is (higher = commoner). |

Draw from it with the **Pick From Table** expression:

```
On chest opened
  -> Set variable  reward = AdvancedRandom.Pick From Table(preload("res://tables/chest.tres"))
```

It draws through the same seeded generator as every other verb here, so a fixed seed still reproduces the whole run exactly. An empty table returns `""`. Variants are just other `.tres` files - a rare-chest table, a fishing table, a per-biome table - and a designer can retune the odds without opening a sheet.

---

## Tips and common mistakes

- **`Chance` and `One In` are conditions, not numbers.** Put them in an event's condition slot (`[ if AdvancedRandom.Chance(25) ]`), not in a value field. They already return true or false, so you never compare them to anything.
- **Seed once, before you roll.** `Set Seed` pins the sequence from that point forward. If you want a reproducible run, set `seed_on_start` in the Inspector or call `Set Seed` before the first number is drawn - seeding halfway through only makes the *rest* of the run repeatable.
- **One seed pins everything.** Numbers and noise share the same generator, so `Set Seed` reproduces dice, picks, ranges, *and* terrain all at once. That is the point - but it also means an extra roll you added anywhere shifts every later result. Keep the order of your rolls stable if you rely on reproducibility.
- **`seed_on_start = 0` means random.** Zero is the "surprise me" value, not "seed with zero." Use any non-zero number for a fixed run. Call `Randomize Seed` at runtime to go back to unpredictable.
- **Noise is smooth, plain random is not.** If you want jittery, unrelated values, use `Random Range`. If you want a value that changes gently over space or time, use the noise expressions and advance the input a little each step - feeding the same x every frame just returns the same number.
- **Configure noise before you sample it.** Set Noise Type, Set Noise Frequency, and Set Noise Octaves change how every later `Noise 1D/2D/3D` reads. Set them once up front (default frequency is 0.01); a frequency that is far too high makes terrain look like static, too low makes it nearly flat.
- **Noise returns -1 to 1.** Scale and offset it for your use. For a 0-to-1 range, do `(AdvancedRandom.Noise 2D(x, y) + 1) / 2`; for a height in pixels, multiply by your amplitude.
- **`Weighted Index` returns an index, not the item.** It hands back a position (0, 1, 2...) proportional to the weights. Keep a parallel array of your actual items and index into it with the result. Weights are relative, so `[70, 25, 5]` and `[14, 5, 1]` behave the same.
- **Build a shuffle bag before you pick from it.** `Shuffle Bag Pick` on a bag you never made with `Make Shuffle Bag` returns null. Fill the bag on ready (or when the pool changes), then draw. The bag refills itself once emptied - you do not re-make it each cycle.
- **Generate the permutation table before reading it.** `Permutation Value` on a table you never generated returns 0. Call `Generate Permutation Table  size` first; after that you can read any index (it wraps past the end, so out-of-range reads are safe).
