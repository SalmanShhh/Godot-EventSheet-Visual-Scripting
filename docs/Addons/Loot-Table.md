# Loot Table

Loot Table is a weighted drop roller you build entirely from event-sheet rows. You register named tables of weighted entries once (gold 70, gem 30, and so on), then roll a table by its id and react to whatever fell out. It ships as the **`LootBox`** autoload singleton, so every sheet in your project can call it with no wiring, no node to attach, and no scene setup. `LootBox` does not touch your inventory, spawn anything, or play a sound. It picks item ids and hands them back through triggers - what you do with each drop is up to you.

Because it is an autoload, you write `LootBox: Roll  "chest"` from any sheet and listen for `On Roll Result` anywhere else. Balancing your game becomes editing weight numbers, not rewiring events.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Chests and containers.** Wooden, iron, and legendary chests are three tables. Opening any of them rolls its table, and one `On Roll Result` handler processes every kind of chest.
- **Enemy and boss drops.** Each enemy type is a table. A boss can guarantee at least one rare and then fill the rest of its slots randomly with a single multi-roll.
- **Gacha banners and multi-pulls.** A ten-pull is one `Roll Times  "banner", 10` call. Guarantee at least one high rarity per pull, and set hard pity so a rare is certain after a dry streak.
- **Fishing, mining, and gathering.** Each spot or ore vein is a table. Rare fish and rich ore are just low-weight entries in the same pool.
- **Quest and mission rewards.** Roll a reward table on completion. The same resolution logic covers every quest; the table configuration drives the variety.
- **Procedural dungeon treasure.** One table per floor, deeper floors weighted toward richer loot. `Has Table` lets you fall back safely when a floor has no table.
- **Shared common-loot pools.** Many tables can reference one `common_loot` table. Change the common weights once and every table that references it updates automatically.
- **Slot machines and reels.** Three reels is `Roll Times  "reel", 3`. Collect the three symbols and check for a match when the batch completes.
- **Random enemy movesets.** A boss picks its next attack from a weighted pool each turn - a small table you roll once per turn.
- **Merchant stock refresh.** Roll the stock table N times on each shop visit to generate fresh, weighted inventory.
- **Reproducible drops for testing or dailies.** `Set Seed` makes a table roll the same sequence every time, so a "daily chest" gives every player the same loot, and bug reports replay exactly.
- **Tutorial and first-run seeding.** Guarantee useful early items with a guaranteed tag so new players are never handed junk on their first few rolls.

---

## Core concepts

The whole pack is built around a handful of small ideas. Once these click, everything else is just wiring.

**A table.** A named bucket of entries you can roll. You create one with `Create Table  "chest"` and refer to it by that id everywhere else. Creating a table with an id that already exists replaces it with a fresh empty one.

**A weighted entry.** An item id plus a weight. Weights are *relative*, not percentages. An entry with weight 70 in a table whose weights sum to 100 drops 70% of the time. Put that same weight-70 entry in a table summing to 140 and it drops 50% of the time. You think in ratios ("rare should be half as common as uncommon") and the sums take care of themselves. Add plain entries with `Add Entry  "chest", "gold", 70`. Add ones that carry a quantity and tags with `Add Rare Entry`.

**Tags.** Short labels on an entry, passed as a comma-separated string to `Add Rare Entry` (for example `"rare,equipment"`). Tags are what guarantees and pity target. A plain `Add Entry` item has no tags, so it can never satisfy a guarantee or a pity rule - use `Add Rare Entry` for anything you want to guarantee or pity.

**Rolling.** `Roll  "chest"` draws one item. `Roll Times  "chest", 10` draws ten in one batch. Every item drawn fires `On Roll Result` once (read `Roll Item`, `Roll Quantity`, `Roll Tags` inside it), and then `On Roll Complete` fires once at the end (read `Total Rolls` there). You never parse a list string - each drop is its own trigger.

**Guarantees.** `Set Guarantee  "table", "potion", 1` forces at least one drop carrying the `potion` tag into every multi-roll batch, then fills the remaining slots randomly. Guarantees are a batch feature: they show their value with `Roll Times`, where there are enough slots for the guaranteed items plus random fill.

**Hard pity.** `Set Pity  "banner", "5star", 90` means: after 90 rolls in a row that produced no `5star` drop, the very next roll is *guaranteed* to include one, and `On Pity Triggered` fires. This is real hard pity - the thing players actually expect from a pity system - not a soft "we nudged the odds a little." When the tagged item finally drops (whether by luck or by pity), the miss counter resets to zero. You can read the current streak any time with `Pity Count`.

**Nested tables.** `Add Table Reference  "boss_loot", "common_loot", 100` adds an entry that, when picked, rolls another table inline and folds its result into the parent roll. This is how several tables share one common pool without duplicating entries. Nesting is depth-limited (up to 8 levels deep) so a circular reference can never loop forever.

**Seeded rolls.** The pack owns one random number generator. It randomizes itself on startup so drops vary between runs. Call `Set Seed  12345` to pin it: the same seed produces the same sequence of drops. Pass `Set Seed  0` to go back to random. After any roll, `Last Seed` tells you which seed was used, so you can store it and replay that exact drop later.

One thing to keep straight: this is the full rolling engine. It is a different thing from the small "loot table" drawer you may have seen on the EnemyStats showcase, which is just a grid you type an array into and does no rolling. This pack rolls.

---

## Setup

There is nothing to install per project and nothing to attach. Loot Table registers itself as the **`LootBox`** autoload, so the singleton exists from the first frame and is reachable from every sheet.

A minimal first example, as event-sheet rows: build a table once on ready, roll it when a chest opens, and react to the drop.

```
On Ready
  -> LootBox: Create Table  "chest"
  -> LootBox: Add Entry  "chest", "gold", 70
  -> LootBox: Add Entry  "chest", "gem", 30

On chest opened
  -> LootBox: Roll  "chest"

On Roll Result
  -> Spawn item named LootBox.Roll Item()
```

`Add Entry` weight numbers are relative, so `gold 70` / `gem 30` means gold drops about 70% of the time and gem about 30%. Add a third entry and the split rebalances automatically - you never recompute percentages by hand.

To handle the end of a roll (for a "you got N items" message, for example), add:

```
On Roll Complete
  -> Show text "Chest opened. Got " + str(LootBox.Total Rolls()) + " items"
```

---

## ACE reference

Every row below is exactly what the pack exposes. Parameter names and types are shown in order.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Create Table | `table_id` (String) | Starts a fresh, empty loot table with this id (replaces any existing one). |
| Add Entry | `table_id` (String), `item_id` (String), `weight` (float) | Adds an item to a table with a relative weight (higher = likelier). Quantity 1, no tags. |
| Add Rare Entry | `table_id` (String), `item_id` (String), `weight` (float), `quantity` (float), `tags` (String) | Adds an item with a weight, a quantity, and comma-separated tags (tags drive guarantees + pity). |
| Add Table Reference | `table_id` (String), `sub_table_id` (String), `weight` (float) | Adds an entry that rolls ANOTHER table inline when picked (shared common-loot pools). Depth-limited. |
| Set Guarantee | `table_id` (String), `tag` (String), `minimum` (int) | Guarantees at least `minimum` drops carrying this tag in every multi-roll batch. |
| Set Pity | `table_id` (String), `tag` (String), `threshold` (int) | Hard pity: after `threshold` rolls in a row WITHOUT a tagged drop, the next roll GUARANTEES one (and fires On Pity Triggered). |
| Reset Pity | `table_id` (String), `tag` (String) | Zeroes a tag's pity counter for a table. |
| Set Seed | `seed_value` (int) | Makes rolls repeatable from a fixed seed (same seed = same sequence). Pass 0 to go back to random. |
| Roll | `table_id` (String) | Rolls the table once, firing On Roll Result then On Roll Complete. |
| Roll Times | `table_id` (String), `count` (int) | Rolls the table `count` times in one batch (guarantees + pity apply across the batch), then shuffles. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Table | `table_id` (String) | Whether a table with this id is registered. |
| Entry Has Tag | `table_id` (String), `tag` (String) | Whether any entry in a table carries the given tag. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Table Count | (none) | int | How many tables are registered. |
| Entry Count | `table_id` (String) | int | How many entries a table has. |
| Pity Count | `table_id` (String), `tag` (String) | int | The current miss streak for a table's tag. |
| Roll Table | (none) | String | The table that was rolled (inside On Roll Result / Complete). |
| Roll Item | (none) | String | The item id that dropped (inside On Roll Result). |
| Roll Quantity | (none) | float | The quantity of the dropped item (inside On Roll Result). |
| Roll Tags | (none) | String | Comma-separated tags of the dropped item (inside On Roll Result). |
| Roll Index | (none) | int | The 0-based position of this drop in the batch (inside On Roll Result). |
| Total Rolls | (none) | int | How many items dropped in the last batch (inside On Roll Complete). |
| Last Seed | (none) | int | The seed used for the last roll (store it to replay the exact drop). |
| Pity Table | (none) | String | The table whose pity fired (inside On Pity Triggered). |
| Pity Tag | (none) | String | The tag whose pity fired (inside On Pity Triggered). |
| Pity Count At Trigger | (none) | int | The miss streak when pity fired (inside On Pity Triggered). |

### Triggers

| Trigger | Description |
|---|---|
| On Roll Result | Fires once for each item drawn in a roll. Inside it, `Roll Table`, `Roll Item`, `Roll Quantity`, `Roll Tags`, and `Roll Index` are valid. |
| On Roll Complete | Fires once after all items from a single Roll or Roll Times call have been delivered. Inside it, `Roll Table`, `Total Rolls`, and `Last Seed` are valid. |
| On Pity Triggered | Fires when a tag's miss streak reaches its threshold and a tagged drop is forced. Inside it, `Pity Table`, `Pity Tag`, and `Pity Count At Trigger` are valid. |

---

## Use cases

Each example uses only real ACE display names. Rows starting with `->` are actions; the lines above them are triggers or conditions.

### 1. A basic three-item chest

A wooden chest gives one random item: gold most of the time, a potion sometimes, a gem rarely.

```
On Ready
  -> LootBox: Create Table  "wooden_chest"
  -> LootBox: Add Entry  "wooden_chest", "gold", 50
  -> LootBox: Add Entry  "wooden_chest", "health_potion", 30
  -> LootBox: Add Entry  "wooden_chest", "gem", 20

On chest clicked
  -> LootBox: Roll  "wooden_chest"

On Roll Result
  -> Add to inventory: LootBox.Roll Item()
```

### 2. Rarity tiers by weight

Five tiers in one table. The weights alone set how rare each tier is - legendary is a thousandth as likely as common.

```
On Ready
  -> LootBox: Create Table  "drop_pool"
  -> LootBox: Add Entry  "drop_pool", "common_item", 1000
  -> LootBox: Add Entry  "drop_pool", "uncommon_item", 500
  -> LootBox: Add Entry  "drop_pool", "rare_item", 100
  -> LootBox: Add Entry  "drop_pool", "epic_item", 50
  -> LootBox: Add Entry  "drop_pool", "legendary_item", 1

On enemy killed
  -> LootBox: Roll  "drop_pool"
```

### 3. A multi-slot boss drop with a guaranteed rare

The boss drops five items, and at least one of them always carries the `rare` tag. The other four are filled by weight.

```
On Ready
  -> LootBox: Create Table  "boss_loot"
  -> LootBox: Add Rare Entry  "boss_loot", "epic_shield", 5, 1, "rare,equipment"
  -> LootBox: Add Rare Entry  "boss_loot", "epic_sword", 5, 1, "rare,equipment"
  -> LootBox: Add Entry  "boss_loot", "gold_20", 50
  -> LootBox: Add Entry  "boss_loot", "health_potion", 30
  -> LootBox: Set Guarantee  "boss_loot", "rare", 1

On boss defeated
  -> LootBox: Roll Times  "boss_loot", 5

On Roll Result
  -> Add to inventory: LootBox.Roll Item()

On Roll Complete
  -> Show text "The boss dropped " + str(LootBox.Total Rolls()) + " items"
```

### 4. Gacha ten-pull with a guaranteed high rarity

A ten-pull that always contains at least one 4-star or better. `Roll Times` gives the batch enough slots for the guarantee plus nine random pulls.

```
On Ready
  -> LootBox: Create Table  "banner"
  -> LootBox: Add Rare Entry  "banner", "3star_char", 94, 1, "3star"
  -> LootBox: Add Rare Entry  "banner", "4star_char", 5, 1, "high"
  -> LootBox: Add Rare Entry  "banner", "5star_char", 1, 1, "high"
  -> LootBox: Set Guarantee  "banner", "high", 1

On ten pull pressed
  -> LootBox: Roll Times  "banner", 10

On Roll Result
  -> Add character: LootBox.Roll Item()
```

### 5. Hard pity - a 5-star guaranteed after a dry streak

After 90 rolls without a `5star`, the next roll forces one and `On Pity Triggered` fires. The counter resets on its own when a 5-star lands.

```
On Ready
  -> LootBox: Create Table  "pity_banner"
  -> LootBox: Add Rare Entry  "pity_banner", "3star_char", 94, 1, "3star"
  -> LootBox: Add Rare Entry  "pity_banner", "5star_char", 1, 1, "5star"
  -> LootBox: Set Pity  "pity_banner", "5star", 90

On pull pressed
  -> LootBox: Roll  "pity_banner"

On Pity Triggered
  -> Show text "Pity hit at " + str(LootBox.Pity Count At Trigger()) + " pulls. Guaranteed 5-star."

On Roll Result
  -> Add character: LootBox.Roll Item()
```

### 6. A live pity meter in the UI

Show the player how close they are to pity without rolling anything, using the `Pity Count` expression.

```
On Process
  -> Set Label text: "5-star in " + str(90 - LootBox.Pity Count("pity_banner", "5star")) + " pulls"
```

### 7. Shared common-loot pool with nested tables

One `common_loot` table, referenced by both a goblin and an orc table. Each enemy has its own signature drop plus a chance to roll the shared pool. Editing `common_loot` updates both.

```
On Ready
  -> LootBox: Create Table  "common_loot"
  -> LootBox: Add Entry  "common_loot", "gold_5", 100
  -> LootBox: Add Entry  "common_loot", "wood", 50
  -> LootBox: Add Entry  "common_loot", "cloth", 40
  -> LootBox: Create Table  "goblin_loot"
  -> LootBox: Add Entry  "goblin_loot", "goblin_dagger", 70
  -> LootBox: Add Table Reference  "goblin_loot", "common_loot", 100
  -> LootBox: Create Table  "orc_loot"
  -> LootBox: Add Entry  "orc_loot", "orc_axe", 70
  -> LootBox: Add Table Reference  "orc_loot", "common_loot", 100

On goblin killed
  -> LootBox: Roll  "goblin_loot"

On Roll Result
  -> Spawn pickup: LootBox.Roll Item()
```

### 8. Fishing hole with stack quantities

`Add Rare Entry` sets a quantity, so a catch can be a stack. A rare fish is just a low-weight entry.

```
On Ready
  -> LootBox: Create Table  "fishing_spot"
  -> LootBox: Add Rare Entry  "fishing_spot", "sardine", 70, 3, ""
  -> LootBox: Add Rare Entry  "fishing_spot", "bass", 25, 1, ""
  -> LootBox: Add Rare Entry  "fishing_spot", "golden_koi", 5, 1, "rare"

On line reeled in
  -> LootBox: Roll  "fishing_spot"

On Roll Result
  -> Add to catch: LootBox.Roll Item() x LootBox.Roll Quantity()
```

### 9. Ore vein with a rare-strike callout

React differently to a tagged rare drop by checking `Roll Tags` inside `On Roll Result`.

```
On Ready
  -> LootBox: Create Table  "ore_vein"
  -> LootBox: Add Rare Entry  "ore_vein", "stone", 100, 2, ""
  -> LootBox: Add Rare Entry  "ore_vein", "iron_ore", 30, 1, ""
  -> LootBox: Add Rare Entry  "ore_vein", "mithril_ore", 3, 1, "rare"

On pickaxe swing
  -> LootBox: Roll  "ore_vein"

On Roll Result
  [ if LootBox.Roll Tags() contains "rare" ]
    -> Show text "Rare strike! " + LootBox.Roll Item()
  -> Add to inventory: LootBox.Roll Item()
```

### 10. Quest reward that always includes gear and gold

Two guarantees on one table: every completion yields at least one `equipment` and one `currency`, plus a random third slot.

```
On Ready
  -> LootBox: Create Table  "quest_reward"
  -> LootBox: Add Rare Entry  "quest_reward", "iron_sword", 50, 1, "equipment"
  -> LootBox: Add Rare Entry  "quest_reward", "gold_10", 100, 10, "currency"
  -> LootBox: Add Entry  "quest_reward", "bonus_potion", 30
  -> LootBox: Set Guarantee  "quest_reward", "equipment", 1
  -> LootBox: Set Guarantee  "quest_reward", "currency", 1

On quest completed
  -> LootBox: Roll Times  "quest_reward", 3

On Roll Result
  -> Add to inventory: LootBox.Roll Item() x LootBox.Roll Quantity()
```

### 11. Procedural dungeon floors with a safe fallback

One table per floor, deeper floors richer. `Has Table` guards against a floor you never registered.

```
On Ready
  -> LootBox: Create Table  "floor_1"
  -> LootBox: Add Entry  "floor_1", "iron_coin", 100
  -> LootBox: Create Table  "floor_5"
  -> LootBox: Add Entry  "floor_5", "silver_coin", 70
  -> LootBox: Add Entry  "floor_5", "emerald", 30

On treasure opened
  [ if LootBox.Has Table("floor_" + str(current_floor)) ]
    -> LootBox: Roll  "floor_" + str(current_floor)
  [ else ]
    -> Show text "No treasure on this floor yet"
```

### 12. Reproducible daily chest with a seed

Seed the roll from the calendar day so every player who opens today's chest gets the same loot.

```
On daily chest opened
  -> LootBox: Set Seed  today_as_number
  -> LootBox: Roll Times  "daily_chest", 3
  -> LootBox: Set Seed  0

On Roll Result
  -> Add to inventory: LootBox.Roll Item()
```

### 13. Store a seed and replay the exact drop

Grab `Last Seed` after a roll, save it, and later feed it back through `Set Seed` to reproduce that drop for a bug report or an instant replay.

```
On chest opened
  -> LootBox: Roll  "chest"

On Roll Complete
  -> Set variable saved_seed = LootBox.Last Seed()

On replay pressed
  -> LootBox: Set Seed  saved_seed
  -> LootBox: Roll  "chest"
  -> LootBox: Set Seed  0
```

### 14. Slot machine with three reels

`Roll Times  "reel", 3` spins three symbols in one batch. Collect them on each result and check for a match when the batch completes.

```
On Ready
  -> LootBox: Create Table  "reel"
  -> LootBox: Add Entry  "reel", "cherry", 30
  -> LootBox: Add Entry  "reel", "bell", 30
  -> LootBox: Add Entry  "reel", "bar", 30
  -> LootBox: Add Entry  "reel", "seven", 10

On lever pulled
  -> Set variable symbols = empty array
  -> LootBox: Roll Times  "reel", 3

On Roll Result
  -> Append LootBox.Roll Item() to symbols

On Roll Complete
  [ if symbols[0] == symbols[1] and symbols[1] == symbols[2] ]
    -> Show text "JACKPOT"
```

### 15. Merchant stock refresh

Every shop visit rolls five items from a weighted pool, so the merchant's shelves change each time.

```
On Ready
  -> LootBox: Create Table  "merchant_stock"
  -> LootBox: Add Entry  "merchant_stock", "potion", 50
  -> LootBox: Add Entry  "merchant_stock", "sword", 30
  -> LootBox: Add Entry  "merchant_stock", "shield", 25
  -> LootBox: Add Entry  "merchant_stock", "rare_amulet", 5

On shop opened
  -> Set variable stock = empty array
  -> LootBox: Roll Times  "merchant_stock", 5

On Roll Result
  -> Append LootBox.Roll Item() to stock

On Roll Complete
  -> Display shop shelves from stock
```

### 16. Random boss moveset

The boss picks its next attack from a weighted pool once per turn.

```
On Ready
  -> LootBox: Create Table  "boss_attacks"
  -> LootBox: Add Entry  "boss_attacks", "slam", 40
  -> LootBox: Add Entry  "boss_attacks", "beam", 30
  -> LootBox: Add Entry  "boss_attacks", "teleport", 20
  -> LootBox: Add Entry  "boss_attacks", "ultimate", 5

On boss turn started
  -> LootBox: Roll  "boss_attacks"

On Roll Result
  -> Play attack animation: LootBox.Roll Item()
```

### 17. Hidden treasure with dig pity

A field where each dig has a small treasure chance. After 20 dry digs, the next one is guaranteed - a friendly floor so the player is never stuck forever.

```
On Ready
  -> LootBox: Create Table  "dig_spot"
  -> LootBox: Add Rare Entry  "dig_spot", "buried_treasure", 5, 1, "treasure"
  -> LootBox: Add Entry  "dig_spot", "dirt", 95
  -> LootBox: Set Pity  "dig_spot", "treasure", 20

On shovel used
  -> LootBox: Roll  "dig_spot"

On Pity Triggered
  -> Show text "You feel like something is close..."

On Roll Result
  [ if LootBox.Roll Item() == "buried_treasure" ]
    -> Show text "You found the treasure!"
```

---

## Tips and common mistakes

- **Tags only exist on `Add Rare Entry` items.** A plain `Add Entry` has no tags, so it can never satisfy a `Set Guarantee` or a `Set Pity` rule. If a guarantee seems to do nothing, check that the tagged entries were added with `Add Rare Entry` and that the tag strings match exactly.
- **Guarantees are a batch feature - use `Roll Times`.** A single `Roll` draws one item, so a table with a guarantee plus random fill needs multiple slots to show its effect. Roll the batch with `Roll Times  "table", N` where N is at least the number of guaranteed items plus the random ones you want.
- **Hard pity is a real floor, not a nudge.** `Set Pity  "banner", "5star", 90` guarantees a `5star` on the roll after 90 straight misses and fires `On Pity Triggered`. This is different from systems that merely double the odds and hope. The miss counter resets to zero automatically the moment the tagged item lands, by luck or by pity.
- **Read roll context inside the right trigger.** `Roll Item`, `Roll Quantity`, `Roll Tags`, and `Roll Index` are meaningful inside `On Roll Result` (they describe the current drop). `Total Rolls` and `Last Seed` are meaningful inside `On Roll Complete` (they describe the finished batch). Reading them elsewhere gives you leftover values from the last roll.
- **Weights are relative, so you never do percentage math.** Adding, removing, or retuning an entry rebalances every other entry's odds automatically. Think in ratios and let the sums settle themselves.
- **`Set Seed 0` returns to random.** A fixed seed makes rolls repeat forever, which is great for a daily chest or a test but wrong for normal gameplay. After a seeded roll you want to reproduce, call `Set Seed  0` to restore random behavior.
- **Nested tables are depth-limited (8 levels).** `Add Table Reference` lets one table roll another inline. Two tables that reference each other would loop forever, so the pack stops at 8 levels deep and returns nothing rather than hanging. Keep reference chains shallow and avoid circular references.
- **Creating a table with an existing id wipes it.** `Create Table  "chest"` always starts empty. If you meant to add to an existing table, skip `Create Table` and just call `Add Entry` - the table is created on first use if it does not exist yet.
- **This is the rolling engine, not the EnemyStats drawer.** The plugin also has a small "loot table" field on the EnemyStats showcase that is just a grid you type an array into - it does no rolling. When you want weighted picks, guarantees, pity, nesting, or seeds, this `LootBox` pack is the one that actually rolls.
- **`LootBox` does not touch your game state.** It hands you an item id and a quantity through `On Roll Result` and nothing more. Adding to inventory, spawning a pickup, playing a sound - all of that is yours to do in the handler. That separation is what lets one roll handler serve every table in your game.
