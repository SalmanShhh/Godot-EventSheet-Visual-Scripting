# Building Custom Resources (Data Assets)

A custom resource is a data asset: a file that holds numbers, names, and tables instead of code. A loot table's drops, a boss's stats, a shop's stock, a quest's steps - anything that is "rows of data someone tunes" belongs in a custom resource. You design the shape once (the columns), and then designers fill in as many `.tres` files as the game needs, entirely in Godot's Inspector, without ever opening a script or an event sheet.

Godot EventSheets makes this a two-minute job. The **Sheet > New Custom Resource…** wizard asks three plain questions and generates a Resource-host sheet whose exported grid IS the Inspector: a real table with typed and dropdown columns, an optional "must be filled" warning, and an optional live validation check. Compile it and Godot treats your class like any built-in resource type - the FileSystem dock can stamp out `.tres` variants of it all day.

This guide covers the wizard, the column language, validation, designing the whole Inspector, adding logic to a resource, the `.tres` workflow, and the APIs pack authors use to build the same things in code.

## Table of Contents

1. [What is a custom resource?](#1-what-is-a-custom-resource)
2. [Your first data asset in 60 seconds (the wizard)](#2-your-first-data-asset-in-60-seconds-the-wizard)
3. [The column language](#3-the-column-language)
4. [Required fields and live validation](#4-required-fields-and-live-validation)
5. [Designing the whole Inspector](#5-designing-the-whole-inspector)
6. [Adding logic: functions on a resource](#6-adding-logic-functions-on-a-resource)
7. [The .tres workflow](#7-the-tres-workflow)
8. [Use cases](#8-use-cases)
9. [For pack authors: the APIs behind the wizard](#9-for-pack-authors-the-apis-behind-the-wizard)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. What is a custom resource?

In Godot, a `Resource` is a saveable data container. The engine's own `.tres` files (themes, materials, curves) are resources; a *custom* resource is one whose fields you define yourself. Three things make them the right home for game data:

- **Data lives outside scenes and scripts.** A designer balances the goblin's loot table by editing `goblin_loot.tres`, not by hunting through event sheets. Code and content stop stepping on each other.
- **One class, many assets.** You define `LootTable` once; the project can hold `wooden_chest.tres`, `boss_chest.tres`, and `fishing_spot.tres` - all the same shape, all separately tunable, all shareable between scenes.
- **The Inspector is the editor.** Nobody writes dictionaries by hand. Rows of a table drawer, dropdowns for choices, sliders for numbers - the Inspector becomes a tiny purpose-built tool for exactly your data.

Three resources that ship with this plugin show the pattern at full scale, and each one is an ordinary Resource-host sheet like the ones you will build:

- **`LootTableResource`** (`eventsheet_addons/loot_table_resource/`) - a drops table (`item`, `weight`, `tags` columns) plus pity settings. Drop a saved `.tres` onto a Loot Table Loader behavior and the LootBox autoload serves those drops.
- **`DrawingPrefabResource`** (`eventsheet_addons/drawing_prefab_resource/`) - an ordered grid of shape steps (kind dropdown, offsets, sizes, color) that the Drawing Canvas replays as a reusable stamp.
- **`UHTNPlanResource`** (`eventsheet_addons/uhtn_plan_resource/`) - an entire AI planner's brain as four grids (tasks, methods, preconditions, utility scorers). A whole hierarchical-task-network plan, authored in the Inspector, dropped onto a planner node.

If a grid of rows can describe an AI's decision-making, it can describe your shop stock.

---

## 2. Your first data asset in 60 seconds (the wizard)

Open the EventSheet dock and pick **Sheet > New Custom Resource…**. The dialog asks three beginner questions:

1. **"One entry is a…"** - name a single row of your data, in plain words. Type `Loot Drop` and the wizard derives everything else: the grid variable becomes `loot_drops`, and the class name defaults to `LootDropTable` (there is a **Resource name** field right below if you want a different class name, like `LootTable`).
2. **"What does an entry have?"** - the columns, one per line, as plain phrases:

   ```
   name
   kind: coin|gem|key
   weight: float
   ```

3. **"Before it works"** - two checkboxes:
   - **Warn in the Inspector until the table has rows (required)** - the Inspector shows a warning on every `.tres` whose grid is still empty, so a half-configured asset cannot slip by silently.
   - **Add a validation check (a function warning about bad data, live)** - generates a ready-to-edit `validate_loot_drops` function on the sheet; whatever warning String it returns shows above the field live, while the table is being edited.

As you type, a live **Ships as:** line at the bottom describes exactly what the grid will look like in the Inspector - it is phrased by the same API that builds the sheet, so the preview can never disagree with the result.

Press **Create** and the dock opens a fresh, unsaved Resource-host sheet: `host_class` is `Resource`, the class name is set, and the grid variable is already exported with a table drawer. The sheet starts with a comment row that re-explains the whole workflow right where you will see it. Use **Save As…** to keep it, then **Compile** - and your class exists.

That is genuinely all of it. No annotations, no hint strings, no `@export_custom` syntax - the wizard writes those for you.

---

## 3. The column language

Each line in the wizard's columns box (and each String in the `resource_grid` API) is one column of the table. The whole syntax is four small rules:

| You type | You get |
|---|---|
| `name` | A text column named `name` (plain words = String). |
| `weight: float` | A number column (decimals). `int` gives whole numbers, `bool` gives checkboxes, `String` is explicit text. |
| `kind: coin|gem|key` | A **dropdown** column - each row picks one of the listed choices. Spaces around the `|` are forgiven. |
| `tint: color` | Any other hint after the colon passes through as-is, for column types the shorthand does not name. |

Some worked examples, straight from shipped resources:

A loot drops table:

```
item
weight: float
tags
```

A drawing prefab's shape steps (note the dropdown for the shape kind):

```
kind: circle|ring|rect|line|cone|stamp
x: float
y: float
color: color
```

A dialogue line table:

```
speaker
line
emotion: neutral|happy|angry|sad
```

Column names become the keys of each row's Dictionary at runtime, so keep them short and snake_case-friendly (`weight`, not `How heavy is it`). Dropdown columns store the chosen text (`"gem"`), which your logic compares as a String.

---

## 4. Required fields and live validation

**Required** is the first checkbox. It marks the grid so the Inspector warns until the table has at least one row. Use it whenever an empty asset is a broken asset - a loot table with no drops, a wave plan with no waves. The same idea appears on loader behaviors like the Loot Table Loader and Skin Catalog Loader: their resource slots are marked required, so the Scene dock warns until a `.tres` is actually attached. Between a required grid and a required slot, "I forgot to fill it in" gets caught in the editor, not in a playtest.

**Validation** goes further: it checks the *content*, live. Ticking **Add a validation check** creates a function named `validate_<grid>` on the sheet:

- It returns a **String**: a warning message when something is wrong, or `""` when the data is fine.
- It runs **while the table is edited in the Inspector**, and the returned message shows above the field immediately.
- The generated body is a ready-to-edit skeleton (for a grid it starts as "warn when empty"); you extend it with your own condition rows.

For example, a loot table that requires weights to be positive - the validator is ordinary sheet logic:

```gdscript
func validate_loot_drops() -> String:
	if loot_drops.is_empty():
		return "Add at least one row."
	for drop in loot_drops:
		if float(drop.get("weight", 0)) <= 0.0:
			return "Every drop needs a weight above zero."
	return ""
```

Rules like "the boss wave must come last", "no two entries may share a name", "the total must sum to 100" all fit this shape: loop the rows, return a sentence when something is off. Designers see the sentence the moment they type the mistake, in the exact place they are typing it.

You can attach a validator to any variable later, too - see [section 9](#9-for-pack-authors-the-apis-behind-the-wizard) for `EventSheets.attach_validator`.

---

## 5. Designing the whole Inspector

The grid is usually the star, but most resources also carry a few loose fields (a display name, a toggle, a tuning number). Every variable on the sheet can shape its own Inspector presence through the variable dialog's attributes:

- **Tooltip** - hover text on the field. Your variable's comment doubles as the tooltip, so describing a field once describes it everywhere.
- **Group** - collapsible headings that bundle related fields (`Identity`, `Task Network`, `Utility Scorers` - the UHTN plan resource uses groups to keep four grids readable).
- **Required** - the warn-until-set marker, available on any field, not just grids.
- **Drawers** - how a value is presented: the `table` drawer is the grid; others include ranges/sliders for numbers, file pickers for paths, progress bars, and more. The variable dialog shows a live "Ships as:" strip with the exact annotation each choice emits.
- **Validate** - wire any variable to a validate function by name (what the wizard's checkbox does for the grid).

To see the result as one page, open **Sheet > Inspector Designer…**. It renders the sheet's *entire* Inspector top to bottom - every exported variable with its decor, grouping, and a miniature of its widget - exactly as a designer will meet it. It is a live view, not a separate editor: the pencil button on each entry opens the same variable dialog you already know, and the arrow buttons reorder fields, all through the normal undo system. When the Inspector is the product (and for a data asset, it is), this dialog is where you check your work.

A good habit: after the wizard creates your sheet, open the Inspector Designer once, read your Inspector like a designer would, and fix whatever needs a tooltip or a group before anyone else sees it.

---

## 6. Adding logic: functions on a resource

A resource is not a node: it has **no `_ready`, no `_process`, no signals firing every frame**. It is data plus, optionally, *questions you can ask the data*. Those questions are functions on the sheet:

- `roll()` on a loot table - pick one entry by weight.
- `find_by_name(name)` on a catalog - fetch one row.
- `total_cost()` on a recipe - sum a column.

The **Custom Resource (data + logic)** starter template (the New-Sheet template menu, under "Custom Resources - data assets") models this flavor: a small `LootTable` with exported fields and a `roll()` function that picks a random entry, published as an ACE. Two things in it are worth copying:

**Expose a function as an ACE.** In the function dialog, publish the function as a verb ("Roll Loot" in the starter). Any sheet that holds one of your `.tres` assets can then call it from the picker like built-in vocabulary - the resource stops being inert data and becomes a thing other sheets can *ask*.

**Give a function an Inspector button.** The function dialog has an **Inspector button** field: type a label (like `Re-bake` or `Validate now`) and the function appears as a one-click button in the Inspector (it ships as `@export_tool_button`). Pressing the button runs the function's rows. This is the beginner path to editor tooling: a "sort rows by weight" or "fill missing ids" chore becomes a button on the asset itself, and its behavior stays ordinary, readable event rows.

Keep resource functions **pure-ish**: read the resource's own fields, return an answer. Anything that needs the scene tree (spawning, sounds, nodes) belongs in the sheet that *loads* the resource, not in the resource.

---

## 7. The .tres workflow

Once your sheet compiles, the class is registered and the asset production line opens:

1. **Compile the sheet** (and save the generated `.gd`). Your `class_name` - say `LootTable` - now exists project-wide.
2. **FileSystem dock > right-click > New Resource… > LootTable.** Godot creates a `.tres` file of your class.
3. **Fill it in the Inspector.** The grid, the dropdowns, the tooltips - everything you designed. Save.
4. **One asset per variant.** `wooden_chest.tres`, `boss_chest.tres`, `event_chest.tres` - each is one file, cheap to copy, easy to diff, safe to hand to a designer.
5. **Drop it where it is used.** Onto an exported variable of one of your sheets, or onto a behavior's slot - the Loot Table Loader takes a `LootTableResource`, the Skin Catalog Loader takes a `SkinCatalogResource`. Loaders with a required slot warn in the Scene dock until you do.

Because `.tres` files are plain text, they play nicely with version control: a balance patch that changes three weights is a three-line diff, reviewable at a glance.

Two habits that pay off:

- **Name assets after their role**, not their contents: `goblin_loot.tres` beats `table_2.tres` forever.
- **Keep a `data/` folder** (or one folder per system: `data/loot/`, `data/waves/`) so designers always know where the tunable files live.

---

## 8. Use cases

Each one is a real shape you can build with the wizard today. The column sketch is exactly what you would type into the wizard's columns box.

### 1. A loot table

The classic. One entry is a "Loot Drop"; the loader behavior or your own sheet rolls it.

```
item
weight: float
tags
```

Tick **required** (an empty loot table is a bug) and add a validator that rejects zero weights. Compare with the shipped `LootTableResource` - same shape.

### 2. Dialogue lines

One entry is a "Dialogue Line". A conversation is one `.tres`; your dialogue sheet steps through the rows in order.

```
speaker
line
emotion: neutral|happy|angry|sad
portrait
```

One asset per conversation means writers edit dialogue without ever seeing an event sheet.

### 3. A wave plan

One entry is a "Wave". Your spawner sheet reads row N when wave N starts.

```
enemy
count: int
delay: float
boss: bool
```

Add a validator: warn when `count` is zero or when two boss waves are adjacent. Difficulty variants (`easy_waves.tres`, `nightmare_waves.tres`) are just different files on the same spawner.

### 4. A stat sheet

One entry is a "Stat". A character's whole numeric identity in one asset - drop different `.tres` files on the same enemy scene to make the grunt and the elite.

```
stat: health|damage|speed|armor|luck
base: float
per_level: float
```

The dropdown column keeps stat names typo-proof: `helth` cannot happen.

### 5. A shop catalog

One entry is a "Shop Item". The shop UI sheet loops the rows to build its shelves.

```
item
price: int
stock: int
category: weapon|armor|consumable|junk
featured: bool
```

Seasonal sales are alternate `.tres` files swapped on a date check - zero logic changes.

### 6. Quest definitions

One entry is a "Quest Step". A quest is one asset; your quest tracker advances through rows.

```
step
description
target
count: int
```

Add a `find_step(index)` function and expose it as an ACE so any sheet can ask "what is the player's current objective text?".

### 7. An ability loadout

One entry is an "Ability". A class or character kit as data - the paladin and the rogue are two `.tres` files on the same player scene.

```
ability
cooldown: float
cost: int
slot: primary|secondary|ultimate|passive
```

A validator that warns when two rows claim the same `slot` catches broken kits at edit time.

### 8. A skin catalog

One entry is a "Skin". The shipped `SkinCatalogResource` plus the Skin Catalog Loader behavior is exactly this pattern - cosmetics as data, dropped onto a loader with a required slot.

```
skin
texture
rarity: common|rare|epic|legendary
price: int
```

### 9. Crafting recipes

One entry is an "Ingredient". One recipe per `.tres`; the crafting sheet checks the player's inventory against the rows.

```
ingredient
amount: int
consumed: bool
```

A `total_items()` function (sum the `amount` column) makes the UI's "requires 7 items" label one call.

### 10. Enemy spawn tables per biome

One entry is a "Spawn". Each biome gets one asset; the director sheet rolls the table when a spawn is due.

```
enemy
weight: float
min_wave: int
night_only: bool
```

Because assets are files, modders can add a biome by adding a `.tres` - no code shipped.

### 11. Achievement definitions

One entry is an "Achievement". The tracker sheet loads one catalog asset and checks stats against it.

```
id
title
description
threshold: int
stat: kills|deaths|coins|jumps|playtime
hidden: bool
```

### 12. Level and biome settings

One entry is a "Setting Row", or skip the grid entirely: a resource can be a handful of loose typed fields (gravity, tint, music path) with groups and tooltips - the Inspector Designer makes a tidy settings page of it. One `.tres` per level; the level loader applies whichever it is handed.

```
key
value: float
```

### 13. Difficulty presets

One entry is a "Tuning Value". `easy.tres`, `normal.tres`, `brutal.tres` - the settings menu just swaps which asset the game state sheet points at.

```
knob: enemy_health|enemy_damage|player_healing|drop_rate
multiplier: float
```

A validator that warns when a multiplier is `0` prevents the classic "enemies have 0 health on easy" patch note.

### 14. A hint and tip deck

One entry is a "Tip". The loading screen rolls a random row; a `random_tip()` function exposed as an ACE makes it one picker verb from anywhere.

```
tip
category: combat|economy|movement|lore
min_playtime: float
```

### 15. Reusable drawing stamps

One entry is a "Shape Step". This is the shipped `DrawingPrefabResource` shape: an ordered grid of steps the Drawing Canvas replays at any position, scale, and rotation - a spell circle or minimap marker authored as rows.

```
kind: circle|ring|rect|line|cone|stamp
x: float
y: float
p1: float
p2: float
color: color
```

### 16. An AI plan

One entry is a "Task" (plus sibling grids for methods and scorers). The shipped `UHTNPlanResource` proves the ceiling: a full utility-driven hierarchical task network - tasks, decomposition methods, preconditions, response curves - authored entirely in Inspector grids and dropped onto a planner node. Start smaller: a patrol route table (`x: float`, `y: float`, `wait: float`) is the same idea at day one scale.

```
name
kind: primitive|compound
```

### Other use cases

**Card and unit databases.** A deckbuilder's every card - cost, attack, health, a rules-text column, a rarity dropdown - is one grid asset the whole game reads; balance patches become `.tres` diffs a designer can review line by line.

**Cutscene and camera scripts.** A sequence of rows (target, duration, easing dropdown, dialogue reference) that a director sheet plays back in order, so cinematic timing is tuned in the Inspector instead of re-compiled.

**Procedural generation palettes.** A biome's tile weights, prop lists, and color fields as one asset per biome; the generator sheet rolls against whichever palette the level hands it, and adding a biome never touches the generator.

**Sound and music banks.** Rows of event name, audio file path, volume, and pitch-variance columns; the audio sheet resolves "play footstep" through the bank, so swapping a whole soundscape is swapping one file.

**Tutorial and onboarding flows.** Step rows (trigger, message, highlight target, a completes-when dropdown) that the tutorial sheet walks through, letting a designer reorder or reword the first five minutes of the game without programmer time.

---

## 9. For pack authors: the APIs behind the wizard

Everything the wizard does goes through two static methods on the `EventSheets` API (`addons/eventsheet/api/eventsheets.gd`), so pack builders, editor extensions, and tests can build the same assets in code. Like the rest of the API, their shapes are stable once shipped.

### `EventSheets.resource_grid(columns, options)`

Builds one Inspector-grid variable descriptor (the `"drawer": "table"` payload) from plain column phrases - the same phrases the wizard accepts, because this method is the one owner of that syntax:

```gdscript
var sheet: EventSheetResource = EventSheets.new_sheet({"host_class": "Resource", "class_name": "LootTable"})
sheet.variables["drops"] = EventSheets.resource_grid(
	["item", "kind: coin|gem|key", "weight: float"],
	{"tooltip": "One drop per row.", "group": "Loot", "required": true})
```

- **`columns`**: an Array of String phrases (`"name"`, `"weight: float"`, `"kind: coin|gem|key"`) or pass-through Dictionaries (`{"name": ..., "type": ...}`) for column types the shorthand does not cover.
- **`options`** (all optional): `tooltip` (String), `group` (String), `required` (bool).
- **Returns** a full variable descriptor - `{"type": "Array", "default": [], "exported": true, "attributes": {...}}` - ready to drop into `EventSheetResource.variables` under the grid's name.

Because the wizard, pack builders, and your extension all call this one method, the column syntax can never drift between them.

### `EventSheets.attach_validator(sheet, variable_name)`

Gives a variable a live validation check without the caller learning the machinery:

```gdscript
var function_name: String = EventSheets.attach_validator(sheet, "drops")
# -> "validate_drops"
```

It creates a `validate_<variable>` function on the sheet (returning a warning String, `""` meaning valid, with a ready-to-edit skeleton body - for Array variables it starts as an is-empty check), and wires the variable's `validate` attribute to that function so the Inspector shows the returned message above the field while the value is edited. If a function of that name already exists it is reused, never duplicated. Returns the function name, or `""` when the sheet or variable does not exist. The wizard's "Add a validation check" box is literally this call.

### Rounding out a pack

A data-driven pack usually ships three pieces: the resource sheet (a grid built with `resource_grid`), a **loader behavior** with a required resource slot (the Loot Table Loader and Skin Catalog Loader in `eventsheet_addons/` are the templates - a `# @inspector_required` exported `Resource` slot, applied on `_ready`), and a **Load From Resource** action so sheets can load assets at runtime too. Author packs as builders under `tools/pack_builders/`, and pin your emission with `EventSheets.round_trips()` in a test like every built-in does.

---

## 10. Troubleshooting

**My class does not appear under New Resource… in the FileSystem dock.**
The class exists only after the sheet compiles and the generated `.gd` is saved. Compile first; if it still does not show, check the sheet has a class name (the wizard's Resource name field) and that its host is `Resource`. A freshly added `class_name` can also need an editor restart to enter Godot's class cache.

**The wizard's Create button complains at me.**
It needs two things before it can build: the entry name ("One entry is a…") and at least one column line. Everything else has a default.

**The grid shows in the Inspector but the columns are wrong.**
Re-read the column line syntax: the type goes *after* a colon (`weight: float`), and only `float`, `int`, `bool`, and `String` are the built-in words - anything else after the colon passes through as a raw hint. A choices column needs the `|` separators (`kind: coin|gem|key`).

**My validation message never appears.**
Three checks: the validate function must return a `String` (`""` for valid), the variable's validate attribute must name that exact function (the wizard and `attach_validator` wire this for you), and live Inspector validation runs on `@tool` sheets - the compiled script must be a tool script for the editor to execute it while editing.

**The required warning does not show on my behavior's slot.**
Required slots on loader behaviors come from the resource slot being marked required in the pack; the warning appears in the Scene dock on the node, not in the Inspector panel. For your own sheet's variables, set required in the variable dialog (or pass `"required": true` to `resource_grid`).

**Editing a `.tres` at runtime changes every user of it.**
By design: a resource is shared by everyone who loads it. If a function on your resource mutates its own fields (consuming stock, shuffling entries), call `duplicate(true)` on the asset first when each user needs an independent copy.

**My function needs the scene tree and cannot get it.**
Resources are not in the tree - there is no `get_node`, no `_process`, no signals from gameplay. Keep resource functions to reading and answering; do the spawning, sounds, and node work in the sheet or behavior that loaded the asset.

**I renamed a column and old `.tres` files kept the old key.**
Rows store their column name as the Dictionary key, so old assets keep old keys. After a rename, sweep existing assets (an Inspector button running a "migrate old key to new key" function on the resource is a tidy way to do it), or read both keys during a transition.
