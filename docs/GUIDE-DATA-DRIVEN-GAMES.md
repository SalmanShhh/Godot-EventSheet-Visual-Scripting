# Building a data-driven game

A data-driven game keeps its **content** - enemy stats, items, levels, dialogue, loot, upgrades - in
data files you edit in the Inspector, not baked into events or code. The payoff is huge: designers tune
numbers in a grid without touching logic, adding content is filling in a row, and the same events drive
every enemy or item because they read the data instead of hard-coding it.

Godot EventSheets is built for this. A **Custom Resource** holds the data (a `.tres` asset with an
Inspector grid), your sheets read it, and content becomes assets you can duplicate, balance, and hot-swap.
This guide is a cookbook: fourteen worked examples of game systems done data-driven, each with the
resource shape and how a sheet uses it. For the mechanics of authoring a Custom Resource and the loader
pattern, see [Data-driven addons](GUIDE-DATA-DRIVEN-ADDONS.md); for the exported-variable options (the
table grid, groups, ranges), see the Variable dialog.

## The core recipe

Every example below follows the same three-part shape:

1. **A Custom Resource for the data.** A sheet whose Sheet Type is **Custom Resource** (it `extends
   Resource`) with `@export` fields. For a list of things, an `Array` with the **table** drawer becomes an
   editable grid in the Inspector.
2. **A `.tres` you fill in.** Right-click in the FileSystem, New Resource, pick your class, and edit it in
   the Inspector. That file is your content - duplicate it for variants.
3. **Sheets that read it.** Load the resource and drive behaviour from its fields, so one set of events
   serves every entry.

And a rule of thumb: **data in the resource, logic in the sheet.** The resource says what an enemy's
health is; the sheet says what happens when health hits zero.

## The fourteen examples

### 1. Enemy stats

A single enemy that reads its numbers from a resource, so "goblin" and "dragon" are the same scene with
different `.tres` files.

- **Resource `EnemyStats`**: `max_health: int`, `move_speed: float`, `damage: int`, `xp_reward: int`,
  `sprite: Texture2D`.
- **Sheet**: On Ready, set `health = stats.max_health`, set the Sprite texture to `stats.sprite`. On hit,
  subtract; on death, grant `stats.xp_reward`. Every enemy scene uses one set of events; the `.tres`
  makes it a goblin or a dragon.

### 2. Item / weapon database

One inventory system that works for every item because items are data.

- **Resource `ItemDef`**: `id: String`, `display_name: String`, `icon: Texture2D`, `stack_size: int`,
  `value: int`, `tags: String`. Keep a folder of `.tres` files (one per item), or one `ItemDatabase`
  resource holding an `Array` of `ItemDef` (a table grid).
- **Sheet**: to add an item, look it up by id and read its stack size and icon. Adding a new item is
  dropping in a new `.tres`, never editing events.

### 3. Loot tables (shipped)

The bundled Loot Table pack is already data-driven. Fill a **LootTableResource** grid (item / weight /
tags plus pity), drop it on a **Loot Table Loader**, and roll.

- **Sheet**: On chest opened, `LootBox: Roll "chest"`; On Roll Result, spawn `LootBox.Roll Item()`.
  Balancing the chest is editing weight numbers in the Inspector.

### 4. Cosmetics catalog (shipped)

The bundled SkinVault pack too: a **SkinCatalogResource** with a rarities grid and a skins grid, loaded
by a **Skin Catalog Loader**. Add a skin by adding a row.

### 5. Dialogue as data

Conversations authored in a resource, not a wall of Queue Line actions.

- **Resource `Conversation`**: an `Array` table of `speaker: String`, `text: String`, `portrait:
  Texture2D`.
- **Sheet**: On talk to NPC, loop the conversation's rows and Queue Line each into the Dialogue Kit, then
  Start Dialogue. Writers edit the grid; the events never change. Give each NPC its own `.tres`.

### 6. Levels and waves

Enemy waves defined as data so a level designer builds encounters without events.

- **Resource `WaveSet`**: an `Array` table of `enemy: String`, `count: int`, `delay: float`.
- **Sheet**: On wave start, read the next row, Repeat `count` times spawning `enemy`, then Wait `delay`.
  A new level is a new `WaveSet.tres`. Pair it with the [loader pattern](GUIDE-DATA-DRIVEN-ADDONS.md) so a
  missing wave set warns in the Inspector.

### 7. Upgrade / skill tree

An upgrade shop or skill tree where every node is a data row.

- **Resource `UpgradeDef`**: `id: String`, `name: String`, `cost: int`, `stat: String`, `amount: float`,
  `requires: String` (a prerequisite id).
- **Sheet**: build the shop buttons by looping the upgrade list; on buy, check the cost (against your
  Currency Ledger), then apply `amount` to the named `stat`. Re-balancing is editing costs and amounts.

### 8. Quests

Quests as data with objectives and rewards.

- **Resource `QuestDef`**: `id: String`, `title: String`, `description: String`, an `Array` table of
  objectives (`kind: String`, `target: String`, `count: int`), and `reward_item: String`.
- **Sheet**: On quest accepted, track its objectives; when all reach their count, grant `reward_item`.
  Designers add quests as `.tres` files; the tracking events are written once.

### 9. Abilities and spells

One casting system, many abilities.

- **Resource `AbilityDef`**: `id: String`, `cooldown: float`, `mana_cost: int`, `damage: float`,
  `range: float`, `icon: Texture2D`, `vfx: PackedScene`.
- **Sheet**: On cast, check the cooldown and mana from the ability's fields, deal `damage` in `range`,
  and spawn its `vfx`. Combine with the Simple Abilities pack for the cooldown bookkeeping. A new spell is
  a new `.tres`.

### 10. Difficulty presets and game tuning

Easy / Normal / Hard as three resources instead of scattered magic numbers.

- **Resource `DifficultyPreset`**: `enemy_health_mult: float`, `enemy_damage_mult: float`,
  `spawn_rate_mult: float`, `loot_luck: float`.
- **Sheet**: On Ready, multiply your spawn and stat numbers by the active preset's fields. Switching
  difficulty is swapping which `.tres` is loaded - QA can tune each preset without touching logic.

### 11. Localization and text tables

Not just Godot's translation system - your own text data.

- **Resource `TextTable`**: an `Array` table of `key: String`, `text: String` (one table per language, or
  reuse Godot's translation ACEs for the tr() path).
- **Sheet**: look a key up in the active table when showing a message. Adding a language is a new `.tres`;
  writers edit strings in a grid.

### 12. Crafting recipes

A crafting system where recipes are data.

- **Resource `Recipe`**: `result: String`, `result_count: int`, an `Array` table of ingredients
  (`item: String`, `count: int`).
- **Sheet**: On craft, check the inventory has every ingredient in the required count, then consume them
  and grant the result. New recipes are new `.tres` files; the crafting events never change.

### 13. Shop inventory

A shop stocked from data, restockable per day.

- **Resource `ShopStock`**: an `Array` table of `item: String`, `price: int`, `stock: int`.
- **Sheet**: build the shop UI by looping the stock rows; on buy, check the price against your currency
  and decrement `stock`. Different shops are different `ShopStock.tres` files; a sale is editing prices.

### 14. Achievements

Achievements defined as data with a condition and a reward.

- **Resource `AchievementDef`**: `id: String`, `title: String`, `description: String`, `stat: String`,
  `threshold: int`, `icon: Texture2D`.
- **Sheet**: whenever a tracked `stat` changes, loop the achievements and unlock any whose `threshold` the
  stat has reached. Adding an achievement is a row, not an event.

## Putting it together: one project

A whole game leans on a handful of these at once. A typical roguelike:

- Enemies read **EnemyStats**; a level reads a **WaveSet**; drops come from a **LootTableResource**;
  the run's numbers scale by a **DifficultyPreset**; the shop between floors is a **ShopStock**; upgrades
  are **UpgradeDef** rows; and the meta layer tracks **AchievementDef** rows.
- The event sheets that spawn enemies, run waves, roll loot, and stock the shop are written **once**. All
  the balancing, all the content, all the variety lives in `.tres` files a designer edits.

The result is the data-driven promise: content scales by adding rows, not events, and the people tuning
the game never have to open a script.

## Tips

- **Reach for a resource when you have more than two or three of something** (enemies, items, levels).
  One-offs are fine as plain variables.
- **Use the table drawer for lists** - an `Array` with `drawer: "table"` is the Inspector spreadsheet that
  makes data-driven authoring pleasant.
- **Reference resources by id** across data (an upgrade's `requires`, a recipe's ingredient `item`), so
  the pieces link up without hard references.
- **Duplicate a `.tres` to make a variant** - a "goblin" and a "goblin elite" are two files, no new code.
- **Load data-driven content through a loader with a required slot** so a forgotten resource warns in the
  Inspector, as the Loot Table Loader and Skin Catalog Loader do.
- **Keep logic in the sheet, data in the resource.** If you find yourself putting an `if` in a resource,
  it wants to be a field the sheet branches on instead.
- **Hot-swap while playing** - because content is assets, you can tweak a `.tres` and see the change on the
  next load without recompiling anything.
