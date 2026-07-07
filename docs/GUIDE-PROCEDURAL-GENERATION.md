# Randomness and Procedural Generation with Advanced Random

This is a workflow guide, not a single-pack reference. For the full list of Advanced Random's actions, conditions, and expressions, see the pack reference in `docs/Addons/Advanced-Random.md`. Here we show how Advanced Random works *together* with the other bundled addons - ProcRoom maps, Loot Table rolls, SkinVault cosmetics, Storylets - plus its two newest features: the `RandomTableResource` data asset and the stateless **Procedural** module that runs inside editor tools.

## Table of Contents

1. [The one shared random source](#the-one-shared-random-source)
2. [One seed for everything](#one-seed-for-everything)
3. [Data-driven odds with RandomTableResource](#data-driven-odds-with-randomtableresource)
4. [Tooling and Custom Resources: the Procedural module](#tooling-and-custom-resources-the-procedural-module)
5. [Workflow: a seeded roguelite run](#workflow-a-seeded-roguelite-run)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## The one shared random source

Advanced Random ships as an **autoload** called `AdvancedRandom`. Because it is a single global singleton, it holds one shared seed. Seed it once and every draw after that - numbers, dice, noise, weighted picks - replays in the exact same order on the next run. That is the whole point: one seed gives you a reproducible game.

Two things then plug into that shared source so your other systems reproduce from the same seed:

- **The "Use Advanced Random" toggle.** ProcRoom, Loot Table (LootBox), SkinVault, and Storylets each gained a `Use Advanced Random` action. Turn it on and that pack stops using its own private generator and draws from the shared `AdvancedRandom` autoload instead. One seed now drives that pack too.
- **Pick From Table.** Instead of hardcoding odds in events, you author a `RandomTableResource` (.tres) - a grid of value/weight rows - and draw from it with `AdvancedRandom.Pick From Table`. Designers tune drop rates by editing numbers, not events.

There is also a third piece for the editor: the stateless **Procedural** module (Seeded Value, Seeded Int, Seeded Pick, Seeded Sign, Seeded Chance). Those are pure expressions that need no autoload, so they work inside Editor Tool sheets and while filling Custom Resources, where the autoload does not run. More on that below.

---

## One seed for everything

Set the seed once, before you generate anything, and turn on `Use Advanced Random` on each procedural pack. Now the map, the loot, the cosmetics, and the narrative all come from the same seed - so a "share this seed" button reproduces the entire run.

```
On Ready
  -> AdvancedRandom: Set Seed  12345
  # Set Seed sets BOTH numbers and noise; same seed = same sequence

  -> ProcRoom: Use Advanced Random  true
  -> LootBox: Use Advanced Random  true
  -> SkinVault: Use Advanced Random  true
  -> Storylets: Use Advanced Random  true
  # every pack now draws from the shared AdvancedRandom source
```

After this, when ProcRoom builds a map, when a chest rolls loot, when SkinVault rolls a reward, and when Storylets draws a weighted beat, they all pull from the one seeded stream. Change `12345` and you get a completely different but equally reproducible run.

A few things to know:

- **The toggle needs the pack installed.** If the Advanced Random pack is missing, each toggle safely falls back to that pack's own local generator - nothing breaks, but the seeds are no longer shared.
- **Seed before you generate.** ProcRoom's `Generate`, a Loot `Roll`, a SkinVault `Roll` - all consume the shared stream in call order. Call `Set Seed` first, then generate, or the order (and the result) shifts.
- **`Set Seed` takes an int; `0` means "reproducible with seed 0".** To go back to unpredictable runs, call `Randomize Seed` instead.

---

## Data-driven odds with RandomTableResource

`RandomTableResource` is a Custom Resource - a `.tres` data asset you edit in the Inspector. It has one field, `entries`, shown as a grid with two columns: **value** (any string - an item id, a name, a scene path) and **weight** (higher = commoner). You author your odds as data, save the file, and draw from it with `AdvancedRandom.Pick From Table`, which picks a value in proportion to its weight.

Authoring the asset (in the editor, no code):

1. Right-click in the FileSystem, create a new resource of type `RandomTableResource`, name it e.g. `drops.tres`.
2. In the Inspector, add rows to the `entries` grid:

   | value | weight |
   |---|---|
   | `common_potion` | 60 |
   | `rare_sword` | 30 |
   | `epic_shield` | 9 |
   | `legendary_ring` | 1 |

3. Save. Weights are relative, so those four add up however you like - `legendary_ring` here lands roughly 1 draw in 100.

Drawing from it in a sheet:

```
On Chest Opened
  -> Local: set drop to AdvancedRandom.Pick From Table(preload("res://data/drops.tres"))
  -> Inventory: give  drop
  # Pick From Table reads the .tres and returns a weighted value; "" if the table is empty
```

The win: a designer retunes drop rates by editing numbers in a grid, and the same table can be reused by any chest, enemy, or shop. Because the draw goes through the shared `AdvancedRandom` stream, seeded runs reproduce these drops too.

---

## Tooling and Custom Resources: the Procedural module

The Advanced Random autoload only runs in the game. But sometimes you want deterministic randomness where there is no autoload:

- inside an **Editor Tool sheet** that generates content while you work in the editor, and
- while **filling a Custom Resource** with procedural data.

That is what the **Procedural** module is for. It is a set of *stateless, seeded expressions* that hold no state and need no autoload - a seed plus an index always gives the same value, because each one is a pure hash. They compile to plain Godot (`hash` / `absi`), so they honour the parity covenant and run at edit time, at author time, and at runtime alike.

The module (all under the "Procedural" picker section):

| Name | Kind | Parameters | Returns |
|---|---|---|---|
| Seeded Value | Expression | seed (String), index (int) | A stable float in [0, 1) for that seed + index. |
| Seeded Int | Expression | seed, index, minimum (int), maximum (int) | A stable integer between min and max (inclusive). |
| Seeded Pick | Expression | seed, index, options (Array) | A stable element of the array (null if empty). |
| Seeded Sign | Expression | seed, index | A stable -1 or +1. |
| Seeded Chance | Condition | seed, index, percent (float) | True for a stable share of seed+index pairs (0-100). |

The key property: **deterministic per seed + index**. `Seeded Int("map", 7, 0, 9)` returns the same number every time, forever, on every machine. Change the index and you walk the sequence; change the seed and you get a whole new sequence.

### Editor-Tool example: deterministically scatter props

An Editor Tool sheet (its host is a `@tool` node) can lay out decor *in the editor* so what you see while building is exactly what ships - and it never shuffles on reload, because the values are seeded, not live-random.

```
On Ready
  Repeat 40 times
    -> Local: set x to Seeded Int("forest", loop_index, 0, 1024)
    -> Local: set y to Seeded Int("forest", loop_index + 1000, 0, 768)
    -> Local: set kind to Seeded Pick("forest", loop_index, ["tree", "rock", "bush"])
    -> Scene: place  kind at (x, y)
  # runs in the editor; same layout every open because index + seed are fixed
```

Because the autoload is not involved, this works with the plugin's editor preview and while the game is not running. Use the same expressions to fill a Custom Resource - e.g. generating a table of enemy stats where each row's numbers come from `Seeded Int(stat_seed, row_index, min, max)`.

---

## Workflow: a seeded roguelite run

Here is the whole loop wired end to end: one seed drives the map, then each room rolls its own loot, and clearing the boss grants a cosmetic - every random choice from the same stream, so the run is shareable and reproducible.

**1. Seed the run and route every pack through the shared source.**

```
On Ready
  -> AdvancedRandom: Set Seed  run_seed
  -> ProcRoom: Use Advanced Random  true
  -> LootBox: Use Advanced Random  true
  -> SkinVault: Use Advanced Random  true

  -> ProcRoom: Register Room Type  "combat", 5, 0, -1, -1
  -> ProcRoom: Register Room Type  "treasure", 2, 0, -1, 1
  # args: type_id, weight, min_depth, max_depth (-1 = anywhere), max_per_depth (-1 = no cap)
  -> LootBox: Load From Resource  preload("res://data/room_loot.tres")
```

**2. Build the map from the seed.**

```
On Ready
  -> ProcRoom: Generate  "level1", 6, 3
  # a reproducible 6-tier map; same run_seed = same layout every time
```

**3. Roll loot when the player enters a room.**

```
On Room Entered
  Condition: ProcRoom.Current Room Type() = "treasure"
    -> LootBox: Roll  "room_loot"

On Roll Result
  -> Inventory: give  LootBox.Roll Item()
  # the roll came from the shared seed, so this room always drops the same thing this run
```

**4. Reward a cosmetic on the boss.**

```
On Room Entered
  Condition: ProcRoom.Current Room Type() = "boss"
    -> SkinVault: Roll  ""
    # a weighted, seeded cosmetic - reproducible with the run

On Skin Unlocked
  -> Toast: show  "Unlocked " + SkinVault.Skin Name(SkinVault.Unlocked Id())
```

Now `run_seed` is the only knob. Two players who enter the same seed get the same map, the same drops, and the same boss reward - a daily-challenge run in a handful of rows.

---

## Use cases

Each snippet uses the exact display names. `AdvancedRandom.Name(...)` reads an expression inside a value field; `Condition: AdvancedRandom  Name  args` is a condition row. The Procedural expressions (Seeded Value / Seeded Int / ...) have no autoload prefix because they are stateless.

### 1. Seed the whole run on load

Scenario: a shareable run - one seed reproduces map, loot, and cosmetics.

```
On Ready
  -> AdvancedRandom: Set Seed  run_seed
  -> ProcRoom: Use Advanced Random  true
  -> LootBox: Use Advanced Random  true
  -> SkinVault: Use Advanced Random  true
```

### 2. Random damage in a range

Scenario: a sword hits for 8 to 12.

```
On Enemy Hit
  -> Enemy: take damage  AdvancedRandom.Random Range(8, 12)
```

### 3. Roll a d20

Scenario: a tabletop-style skill check.

```
On Skill Check
  -> Local: set roll to AdvancedRandom.Roll Dice(20)
  Condition: roll >= 15
    -> Player: succeed
```

### 4. Critical hits with Chance

Scenario: a 5% chance to crit for double damage.

```
On Attack
  Condition: AdvancedRandom  Chance  5
    -> Enemy: take damage  base_damage * 2
  Else
    -> Enemy: take damage  base_damage
```

### 5. Rare events with One In

Scenario: a 1-in-1000 shiny variant on spawn.

```
On Enemy Spawned
  Condition: AdvancedRandom  One In  1000
    -> Enemy: play "shiny" effect
```

### 6. Weighted enemy spawns

Scenario: grunts common, brutes uncommon, elites rare.

```
On Spawn Wave
  -> Local: set which to AdvancedRandom.Weighted Index([70, 25, 5])
  -> Spawner: spawn  ["grunt", "brute", "elite"][which]
  # heavier weight = likelier index
```

### 7. Pick a random spawn point

Scenario: drop the player at one of several markers.

```
On Level Start
  -> Player: move to  AdvancedRandom.Pick From(spawn_points)
  # Pick From returns a uniformly-random element (null if the array is empty)
```

### 8. Data-driven loot with a RandomTableResource

Scenario: a chest drops from a designer-tuned table asset.

```
On Chest Opened
  -> Inventory: give  AdvancedRandom.Pick From Table(preload("res://data/drops.tres"))
  # edit odds in the .tres grid, not in events; "" if the table is empty
```

### 9. A shuffle-bag music playlist

Scenario: play every track once before any repeats.

```
On Ready
  -> AdvancedRandom: Make Shuffle Bag  "music", ["a.ogg", "b.ogg", "c.ogg", "d.ogg"]

On Track Finished
  -> Music: play  AdvancedRandom.Shuffle Bag Pick("music")
  # each track appears once per cycle - no immediate repeats
```

### 10. Random knockback direction

Scenario: an explosion flings debris left or right.

```
On Explosion
  -> Debris: apply force  AdvancedRandom.Random Sign() * 300
  # Random Sign is -1 or +1
```

### 11. Natural scatter with a normal distribution

Scenario: bullet spread clusters near the aim point, rarely wide.

```
On Fire
  -> Bullet: rotate by  AdvancedRandom.Normal (Gaussian)(0, 3)
  # most shots near 0 degrees, tails fall off - a bell curve, not a flat range
```

### 12. Noise-based terrain height

Scenario: a smooth, seamless heightmap for a tile world.

```
On Generate Terrain
  Repeat 128 times
    -> Local: set h to AdvancedRandom.Noise 2D(loop_index * 0.05, world_row * 0.05)
    -> Tilemap: set height  loop_index, world_row, h
  # Noise 2D returns [-1, 1]; low frequency = large smooth features
```

### 13. Wind and camera drift from 1D noise

Scenario: gentle, wandering wind strength over time.

```
Every tick
  -> Local: set wind to AdvancedRandom.Noise 1D(elapsed_time * 0.2)
  -> Grass: sway by  wind * 10
  # smooth wander, not jittery random
```

### 14. A fixed card-deck order

Scenario: a reproducible shuffle for a card game.

```
On Ready
  -> AdvancedRandom: Set Seed  match_seed
  -> AdvancedRandom: Generate Permutation Table  52

On Draw Card
  -> Local: set card to AdvancedRandom.Permutation Value(cards_drawn)
  -> Hand: add  card
  # the deck order is fixed by match_seed - both players see the same shuffle
```

### 15. A seeded roguelite map

Scenario: a daily-challenge dungeon everyone shares.

```
On Ready
  -> AdvancedRandom: Set Seed  daily_seed
  -> ProcRoom: Use Advanced Random  true
  -> ProcRoom: Generate  "daily", 6, 3
  # same daily_seed = same layout for every player
```

### 16. Per-room loot from the same seed

Scenario: each room's drops reproduce with the run.

```
On Room Entered
  -> LootBox: Roll  "room_loot"

On Roll Result
  -> Inventory: give  LootBox.Roll Item()
  # with Use Advanced Random on, the roll comes from the shared run seed
```

### 17. A seeded cosmetic reward

Scenario: clearing the boss grants a reproducible skin.

```
On Boss Defeated
  -> SkinVault: Roll  ""
  # Use Advanced Random on -> the reward is fixed by the run seed
```

### 18. Varied but reproducible narrative beats

Scenario: pick among eligible story cards, weighted, from the shared seed.

```
On Beat Requested
  -> Storylets: Draw Weighted
  # Draw Weighted uses the shared AdvancedRandom source when Use Advanced Random is on

On Storylet Drawn
  -> Dialogue: play  Storylets.Active Id()
```

### 19. Procedural NPC names

Scenario: generate a stable name from a seed and an id.

```
On NPC Created
  -> Local: set first to Seeded Pick("names", npc_id, ["Ada", "Bran", "Cass", "Dev"])
  -> Local: set last to Seeded Pick("surnames", npc_id, ["Vane", "Holt", "Crane"])
  -> NPC: set name  first + " " + last
  # same npc_id always yields the same name - no autoload needed
```

### 20. A seeded editor tool that scatters props

Scenario: lay out decor in the editor so what you build is what ships.

```
On Ready
  Repeat 40 times
    -> Scene: place  Seeded Pick("forest", loop_index, ["tree", "rock", "bush"]) at (Seeded Int("forest", loop_index, 0, 1024), Seeded Int("forest", loop_index + 999, 0, 768))
  # runs at edit time in a Tool sheet; identical every open
```

### 21. Fill a Custom Resource with procedural stats

Scenario: generate a table of enemy stats at author time, deterministically.

```
On Generate Stats
  Repeat 10 times
    -> Local: set hp to Seeded Int("enemy_hp", loop_index, 20, 80)
    -> Local: set dmg to Seeded Int("enemy_dmg", loop_index, 3, 12)
    -> Resource: add row  hp, dmg
  # Seeded Int works while filling a Custom Resource, where the autoload cannot run
```

### 22. A random production bonus with Currency Ledger

Scenario: a generator sometimes doubles its payout.

```
On Generator Tick
  Condition: AdvancedRandom  Chance  10
    -> CurrencyLedger: Add  "gold", 20
  Else
    -> CurrencyLedger: Add  "gold", 10
```

### 23. A crit chance on an ability

Scenario: a Simple Abilities cast rolls for a critical.

```
On Ability Used  (fireball)
  Condition: AdvancedRandom  Chance  15
    -> Enemy: take damage  spell_damage * 2
  Else
    -> Enemy: take damage  spell_damage
```

### 24. A random reward amount

Scenario: a quest pays out a variable gold sum.

```
On Quest Complete
  -> CurrencyLedger: Add  "gold", AdvancedRandom.Random Int(50, 150)
```

### 25. A weighted shop restock from a table

Scenario: fill a shop slot from a data-driven rarity table.

```
On Shop Restock
  Repeat 4 times
    -> Shop: add item  AdvancedRandom.Pick From Table(preload("res://data/shop_pool.tres"))
  # tune the shop's odds by editing shop_pool.tres, not this event
```

### 26. A seeded map preview with Seeded Chance

Scenario: decide which tiles are walls at author time, deterministically.

```
On Build Preview
  Repeat 256 times
    Condition: Seeded Chance  "cave", loop_index, 45
      -> Grid: set wall  loop_index
  # 45% of tiles become walls, the same set every run - great for a tool preview
```

---

## Tips and common mistakes

- **Seed before you generate.** `Set Seed` (or `Randomize Seed`) must come before any `Generate`, `Roll`, `Draw`, or expression that consumes the stream. Reproducibility depends on call order, so seed first, then generate.
- **The toggle needs the pack installed.** `Use Advanced Random` only shares the seed when the Advanced Random pack is present. If it is missing, each pack safely falls back to its own local generator - nothing breaks, but the seeds are no longer linked.
- **`Set Seed` sets both numbers and noise.** One call reseeds the number generator *and* the noise field, so a single seed reproduces dice, picks, and terrain together.
- **The Procedural module is deterministic per seed + index.** `Seeded Int("map", 7, 0, 9)` always returns the same value. To walk a sequence, change the index; to get a different sequence, change the seed. It is not a stream - there is no hidden state to advance.
- **Use the Procedural module where the autoload cannot run.** Editor Tool sheets and Custom-Resource filling happen with no game running, so the `AdvancedRandom` autoload is absent. The stateless Seeded Value / Int / Pick / Sign / Chance expressions work there because they need no autoload.
- **Pick From Table returns `""` when the table is empty.** A null or empty `RandomTableResource`, or one whose weights sum to zero, yields an empty string - guard for it before you use the value as an item id.
- **Weights are relative, not percentages.** In `Weighted Index` and in a `RandomTableResource`, `[70, 25, 5]` and `[14, 5, 1]` behave the same. You never have to make them add up to 100.
- **`Randomize Seed` breaks reproducibility on purpose.** Call it when you *want* an unpredictable run (a fresh non-seeded playthrough). Do not call it if you are trying to reproduce a shared seed.
