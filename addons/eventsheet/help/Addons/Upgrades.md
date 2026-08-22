# Upgrades

Upgrades is the stacking buff engine an incremental game is built from, driven from any event sheet. Register an upgrade by string id (click_power, auto_miner, prestige_boost, crit_chance, or anything you can name) with a base cost, a cost growth per level, a max level, a per-level effect, an effect mode (add or mult), and a tag. Then buy levels, read the stacked effect, and roll every tagged upgrade into one number. It ships as an **autoload**: once the pack is installed it is the `Upgrades` singleton, live from the first frame with no node to place and no wiring. It holds the levels and the cost curves and fires a trigger on every purchase attempt. It does NOT touch your wallet - Try Purchase checks a budget you hand it and records the price, and you Spend that yourself from the Currency Ledger pack. It also does not draw buttons, bars, or numbers - that stays your job, driven by the triggers below.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [The Skill Tree data asset](#the-skill-tree-data-asset)
7. [Progression - prerequisites, points and grants](#progression---prerequisites-points-and-grants)
8. [Use cases](#use-cases)
9. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Idle clickers.** Cookie Clicker style "buy Cursor, buy Grandma" upgrades: each is a mult-mode upgrade with a cost that grows per level, and one Total Multiplier(tag) call scales your whole cookies-per-second.
- **Buy-max and rapid buy loops.** Try Purchase buys exactly one level and reports the price, so a "buy 10" or "buy max" button is just the same call in a loop until On Purchase Failed fires.
- **Business tycoons.** AdVenture Capitalist style ventures where each upgrade both raises output (mult tag) and the whole panel reads back one production multiplier without per-upgrade math.
- **Paperclip-style single-track escalation.** Universal Paperclips leans on one relentless cost curve - set base_cost and cost_growth once and the price climbs on its own each level.
- **Prestige and rebirth trees.** Reset wipes every upgrade back to level 0 while keeping the definitions, so a prestige button re-runs the whole run without re-registering anything.
- **Permanent meta-upgrades.** Give prestige perks their own tag; Reset only clears the run-scoped tags you choose to reset, and the meta tags keep stacking across runs.
- **Additive stat boards.** RPG-flavoured "+5 attack per level" upgrades are add-mode; Total Bonus(tag) sums a whole category into one flat number you add to a base stat.
- **Combined additive and multiplicative scaling.** Real idle math is `(base + flatBonus) * multiplier`. Total Bonus(tag) and Total Multiplier(tag) give you exactly those two aggregates from the same upgrade table.
- **Offline catch-up.** Read Total Multiplier and Total Bonus once on load to rebuild your production rate, then credit the away time - the upgrades already carry all the scaling.
- **Automation and generator unlocks.** An upgrade with max_level 1 is a one-time toggle; Owns(id) gates the automation loop that upgrade unlocks.
- **Save and load.** Level Of(id) reads out every level for saving; Set Level(id, level) restores them on load, clamped to the cap for you.
- **Live balancing.** Set Effect retunes an upgrade's payoff and mode mid-session without disturbing the level a player already bought.
- **Skill and talent trees.** The tree half answers from a Skill Tree data asset: prerequisites, a skill-point currency, per-node levels and what each node grants. Is Unlocked, Can Unlock, Unlock and Respec are the whole vocabulary.
- **Perks that gate behaviour.** A node that grants nothing at all is a perk: Is Unlocked("double_jump") is the one question the rest of your game asks about it.

---

## Core concepts

The mental model is one thing: an **upgrade** is a named record with a level. Everything else is a field on that record that decides what a level costs and what it is worth.

| Field | What it means |
|---|---|
| **base_cost** | The price of the first level (level 0 -> 1). Default `10`. |
| **cost_growth** | The multiplier applied to the price each level. `1.15` means every level costs 15% more than the last; `1.0` means a flat price forever. |
| **max_level** | The level cap. `-1` means unlimited. At the cap, Cost Of returns -1 and Try Purchase fails. |
| **per_level** | The effect one level is worth - a flat amount in add mode, or a factor in mult mode. |
| **mode** | `"add"` or `"mult"`. Decides how per_level stacks and which aggregate the upgrade feeds. |
| **tag** | A group name. Total Multiplier(tag) and Total Bonus(tag) roll every upgrade sharing a tag into one number. |
| **level** | The current level, starting at 0. Buying, granting, and setting move it. |

A few rules tie those fields together, and they are the whole behaviour of the pack:

- **Cost climbs geometrically.** The next level's price is `base_cost * cost_growth ^ level`. Level 0 -> 1 costs base_cost; the growth compounds from there. At the cap the cost is -1 (unbuyable).
- **Effect stacks by mode.** In add mode an upgrade's effect is `level * per_level` (a flat sum). In mult mode it is `per_level ^ level` (a compounding factor, `1.0` at level 0). Effect Of(id) gives that single upgrade's stacked value.
- **Tags compose.** Total Multiplier(tag) multiplies the Effect Of every mult-mode upgrade with that tag (1.0 if none). Total Bonus(tag) sums the Effect Of every add-mode upgrade with that tag (0.0 if none). Mixing modes under one tag is fine - each aggregate only reads the mode it belongs to.
- **The wallet stays external.** Try Purchase(id, budget) only compares the budget you pass against Cost Of. It never earns or spends money. On success it raises the level, records Last Cost, and fires On Upgrade Bought so you Spend Last Cost yourself; on failure it fires On Purchase Failed and changes nothing.

This is one clean upgrade model. There is no separate "one-time" versus "repeatable" type: a one-time upgrade is simply one with `max_level` 1, and a repeatable one has a higher cap or -1 for unlimited.

---

## Setup

Nothing to install per project beyond the pack. Once the Upgrades pack is in `eventsheet_addons/`, it registers itself as the `Upgrades` autoload, so every sheet can call it by name with no node to drop and no reference to pass around. Because it does not hold money, it pairs with the Currency Ledger pack for the wallet and the Big Numbers pack for display - both referenced by name below.

A minimal first upgrade, as event-sheet rows:

```
On Ready
  -> Upgrades: Define Upgrade  "click_power", 10, 1.15, -1, 1, "add", "click"
  # first level costs 10, each level costs 15% more, no cap, +1 per level

On Buy Button Pressed
  -> Upgrades: Try Purchase  "click_power", CurrencyLedger.Balance("gold")

On Upgrade Bought
  -> CurrencyLedger: Spend  "gold", Upgrades.Last Cost()
  # the pack raised the level; you take the money it cost
```

That is the whole loop: define once, buy against your balance, and pay the recorded cost when a purchase lands.

---

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references in *italic*, exactly as the rows draw them:

- Define upgrade **id**: base cost **base_cost** growing **cost_growth**x, max level **max_level**, **per_level** per level (**mode**)
- Try purchase **id** with budget **budget**
- Effect of **id**

Every id and tag below is a string. Costs, budgets, and effects are numbers. All names are the exact display names from the pack.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Define Upgrade | id, base_cost, cost_growth, max_level, per_level, mode, tag | Creates (or resets) an upgrade: base cost, cost growth per level, max level (-1 = unlimited), effect per level, mode ("add" or "mult"), and a tag to group it for Total Multiplier / Total Bonus. Starts at level 0. |
| Set Effect | id, per_level, mode | Retunes an existing upgrade's per-level effect and mode without touching its level (for live balancing). |
| Try Purchase | id, budget | Buys the next level if `budget` covers Cost Of and it is not maxed. On success records Last Cost and fires On Upgrade Bought (Spend Last Cost from your wallet); otherwise fires On Purchase Failed. Never touches the wallet itself. |
| Grant Level | id | Adds one free level (a reward), up to the max. No cost, no budget check. |
| Set Level | id, level | Forces an upgrade's level (for a load or cheat), clamped to 0 and the max. |
| Reset | (none) | Sets every upgrade back to level 0 (keeps the definitions) - for a prestige wipe. |
| Load Skill Tree | tree | Points the tree words at a SkillTreeResource (.tres). Clears whatever was unlocked and hands the asset's Starting Points to the points counter, so one row opens a fresh tree. |
| Set Skill Points | points | Forces the unspent skill points to a value (for a load or a cheat). Clamped at 0. |
| Earn Skill Points | points | Adds skill points - the level-up reward. Goes into the Currency Ledger account when one was named. |
| Use Points Account | account_id | Keeps skill points in a Currency Ledger account of this id instead of here, so the HUD, the save file and the shop all read one balance. Blank goes back to the built-in counter. |
| Apply Grants To | stats | Names the node whose StatForge stack an unlocked skill's grants are applied to, and re-applies everything already unlocked. Without it a tree still unlocks - it just grants nothing. |
| Unlock | id | Takes one level of a skill: spends its cost, records the level, applies its grants and fires On Skill Unlocked. Refuses (On Unlock Refused) when a required skill is still locked, the skill is capped, or the points are short. |
| Respec | (none) | Refunds every point spent on the tree, clears every unlock and takes back every grant it applied - one action, so a respec button is one row. |

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Is Maxed | id | Whether an upgrade is at its max level. |
| Owns | id | Whether an upgrade has at least one level. |
| Purchase Succeeded | (none) | Whether the last Try Purchase went through (read it right after, or in On Upgrade Bought). |
| Is Unlocked | id | Whether a skill has been taken at least once - the perk test a game asks wherever the perk matters. |
| Can Unlock | id | Whether every skill this one requires is unlocked, it is not already capped, and the points are there. |
| Can Afford | id | Whether the unspent points cover this skill's cost, ignoring its prerequisites. |
| Requires | id, required_id | Whether the tree says this skill needs that one unlocked first. |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Cost Of | Number | id | The next level's price (-1 if maxed or undefined). |
| Level Of | Number | id | An upgrade's current level. |
| Max Level Of | Number | id | An upgrade's max level (-1 = unlimited). |
| Effect Of | Number | id | An upgrade's current stacked effect (level*per_level for add mode, per_level^level for mult mode). |
| Total Multiplier | Number | tag | The product of every mult-mode upgrade sharing this tag (1.0 if none) - multiply production by it. |
| Total Bonus | Number | tag | The sum of every add-mode upgrade sharing this tag (0.0 if none) - add it to a base value. |
| Last Cost | Number | (none) | What the last Try Purchase cost - Spend this from your wallet. |
| Last Upgrade | String | (none) | The id of the last upgrade bought or failed (read in the trigger). |
| Upgrade Count | Number | (none) | How many upgrades are defined. |
| Skill Points | Number | (none) | The unspent skill points - the number a tree screen's "points left" label shows. |
| Skill Cost | Number | id | What one level of a skill costs in points (0 when the id is not in the tree). |
| Skill Level | Number | id | How many levels of a skill are unlocked (0 = locked). |
| Skill Max Level | Number | id | How many levels a skill can take (1 for a one-off perk). |
| Skill Name | String | id | A skill's readable name from the asset ("" when the id is not in the tree). |
| Skill Requires | String | id | The ids a skill needs first, comma-separated as the asset wrote them ("" for a root skill). |
| Skill Grants | String | id | What a skill grants, as the asset's own words - the line a tree screen shows on hover. |
| Skill Column | Number | id | A skill's column on a tree screen, or -1 when the asset leaves the layout to the screen. |
| Skill Row | Number | id | A skill's row on a tree screen, or -1 when the asset leaves the layout to the screen. |
| Skill Depth | Number | id | How many prerequisites deep a skill sits - 0 for a root, 1 for its children, and so on. A screen with no column/row in its asset lays the tree out by this. |
| Skill Id At | String | index | The skill id at a position in the asset's own order ("" out of range) - what a screen walks to build its nodes. |
| Skill Count | Number | (none) | How many skills the loaded tree holds (0 when none is loaded). |
| Unlocked Count | Number | (none) | How many skills have at least one level - the "12 of 30" a tree screen prints. |
| Last Skill | String | (none) | The skill Unlock last touched - read it inside On Skill Unlocked or On Unlock Refused. |
| Tree Name | String | (none) | The loaded tree's readable name ("" when none is loaded) - a tree screen's title. |

### Triggers

| Trigger | When it fires |
|---|---|
| On Upgrade Bought | After a Try Purchase raises a level. Read Last Cost (Spend it), Last Upgrade, and Purchase Succeeded inside it. |
| On Purchase Failed | When a Try Purchase can't be afforded or the upgrade is maxed; nothing changed. Read Last Upgrade inside it. |
| On Skill Unlocked | After Unlock takes a level of a skill. Read Last Skill, Skill Level and Skill Points inside it. |
| On Unlock Refused | When Unlock could not go through - a prerequisite is missing, the skill is capped, or the points are short. Read Last Skill inside it; nothing changed. |

---

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the behaviour is attached:

- `$UpgradesAddon.cost_of(id)` inserts the **Cost Of** entry straight into any expression
- `$UpgradesAddon.level_of(id)` inserts the **Level Of** entry straight into any expression

The `$UpgradesAddon` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this behaviour at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("UpgradesAddon")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance - behaviours
attached at runtime included, under their real names. And with your node selected in the Scene
dock, the section grounds to that node's actual children before you even press Run.

## The Skill Tree data asset

Levels and cost curves are the incremental half of this pack. A skill TREE adds three things a curve
has no room for: a list of nodes each node needs first, a currency spent on unlocking, and what a
node actually GRANTS. All three live in one data asset - **SkillTreeResource**, the companion pack
that ships beside this one - so a designer edits a grid instead of writing a dictionary of unlocked
ids and a loop over a requires list.

Make one with **FileSystem right-click ▸ Create New ▸ Resource ▸ SkillTreeResource**, or from the
Upgrades pack folder. It follows the same `*_resource` convention as PriceTableResource and
LootTableResource: a plain `Resource` with exported fields, editable in Godot's own Inspector, with
no plugin needed at run time. Right-click the `.tres` and **Open as Event Sheet** to edit it as a
TABLE instead - one row per skill, one column per field.

| Field | What it holds |
|---|---|
| **tree_name** | A readable name for this tree ("Warrior", "Ship upgrades"), read back with the Tree Name expression for a screen's title. |
| **starting_points** | How many skill points a fresh save begins with. Load Skill Tree hands this to the points counter. |
| **skills** | One row per node of the tree. |

And one row of `skills` is one node:

| Column | What it holds |
|---|---|
| **id** | The string every action, condition and expression addresses. Keep it short and unique. |
| **name** | What the player reads. |
| **cost** | What unlocking one level costs in skill points. |
| **requires** | The ids that must be unlocked first, separated by commas. Blank means a root node. |
| **max_level** | How many times it can be taken. `1` is a one-off perk. |
| **grants** | What unlocking applies to a StatForge stack (see below). Blank means a pure perk. |
| **column** / **row** | Where the node sits on a skill-tree screen. Leave both at `-1` and the screen lays the tree out by depth. |

The `grants` cell is a **StatForge modifier written as words**: `<stat> <op><amount>`, with an
optional ` per level`, several separated by `;`. `x` (or `*`) multiplies, `+` and `-` add, `=`
overrides. So `speed x1.1 per level` is a 10%-per-level speed buff and `speed x1.1 per level; jump +5`
is that plus a flat jump bonus. Name the node whose stack they land on once, with **Apply Grants To**,
and Unlock does the rest - there is no formula to write and nothing to re-apply by hand.

Two mistakes in a tree are errors rather than balance decisions, and the **Project Doctor** says both
out loud: a `requires` cell naming an id the tree does not hold (nothing can ever unlock that node),
and a cycle - a needs b, b needs a - which locks a whole branch forever with no error at run time. A
node that grants nothing AND whose id no script anywhere asks about is a warning, because that one is
sometimes a deliberate placeholder.

---

## Progression - prerequisites, points and grants

A whole tree is five rows. Point the pack at the asset, spend points, and read the three states.

```
On Ready
  -> Upgrades: Load Skill Tree  tree
  -> Upgrades: Apply Grants To  Player/Stats

On Level Up
  -> Upgrades: Earn Skill Points  1

On Skill Button Pressed
  -> Upgrades: Unlock  HudKit.Last Button Name()

On Skill Unlocked
  -> HUD Kit: Show Toast  Upgrades.Skill Name(Upgrades.Last Skill()) + " unlocked"

On Respec Button Pressed
  -> Upgrades: Respec
```

Three questions colour a node, and they are the same three the pack answers internally, so a screen
can never disagree with what a click actually does:

- **Is Unlocked(id)** - already taken.
- **Can Unlock(id)** - takeable right now: every prerequisite met, not capped, points in hand.
- Neither - locked, because a prerequisite is still missing or the points are short. **Can Afford(id)**
  separates those two if you want to say which.

Skill points can live here or in the **Currency Ledger** pack. Call **Use Points Account("skill_points")**
once and every Earn, Spend and Respec refund goes through that account instead, so the HUD, the save
file and any shop all read one balance. Leave it alone and the pack keeps the number itself.

Persistence is the Save System's usual seam: the pack's own `save_state` / `load_state` carry the
unlocked table and the points beside the upgrade levels, and loading re-applies every grant.

For the SCREEN, **New Sheet ▸ Skill Tree Screen** writes the whole thing: one button per skill laid
out from the asset (or by depth when the asset leaves `column`/`row` at -1), a line drawn to each
node a skill requires, the three states as tints, a click that is one Unlock row, a hover that shows
the Grants cell, and a points-left label - all bound through the **HUD Kit** pack.

![A skill tree screen: two branches, prerequisite lines, and locked, affordable and unlocked nodes](../images/skill-tree-screen.png)

A tree written out by hand - an unlocked table, a points number and a walk over a requires list -
opens as those same words rather than as dictionary lookups and arithmetic, and offers this pack as
the thing to adopt:

![A hand-written skill tree read as event-sheet rows](../images/skill-tree-reading.png)

---

## Use cases

Each snippet uses real display names. `Upgrades.Name(...)` is how you read an expression inside a value field. Where money or display is involved, `CurrencyLedger` is the wallet pack and `BigNumber` is the number-formatting pack.

### 1. Define an upgrade catalogue on load

Scenario: a fresh save registers the whole upgrade tree once.

```
On Ready
  -> Upgrades: Define Upgrade  "click_power", 10, 1.15, -1, 1, "add", "click"
  -> Upgrades: Define Upgrade  "auto_miner", 50, 1.2, -1, 0.5, "add", "production"
  -> Upgrades: Define Upgrade  "gold_boost", 500, 2.0, 5, 1.5, "mult", "production"
  -> Upgrades: Define Upgrade  "double_prestige", 1000000, 1, 1, 2, "mult", "prestige"
  # click_power is unlimited and additive; gold_boost caps at 5 and multiplies
```

### 2. A buy button that pays for itself

Scenario: pressing Buy tries the next level against your gold and deducts the price only if it lands.

```
On Buy Button Pressed
  -> Upgrades: Try Purchase  "click_power", CurrencyLedger.Balance("gold")

On Upgrade Bought
  -> CurrencyLedger: Spend  "gold", Upgrades.Last Cost()
  -> Buy Sound: play
  # the level already went up - here you take the money it cost
```

### 3. A "not enough gold" message on a failed buy

Scenario: let the player tap Buy freely and nudge them when they are short.

```
On Buy Button Pressed
  -> Upgrades: Try Purchase  "auto_miner", CurrencyLedger.Balance("gold")

On Purchase Failed
  -> Error Sound: play
  -> Toast: show "Need " + BigNumber.Format Short(Upgrades.Cost Of(Upgrades.Last Upgrade())) + " gold for " + Upgrades.Last Upgrade()
  # On Purchase Failed changed nothing - the level and the wallet are untouched
```

### 4. An upgrade button label that updates itself

Scenario: the button shows the upgrade's level and its next price.

```
On Upgrade Bought
  -> Miner Button: set text to "Auto Miner  Lv " + Upgrades.Level Of("auto_miner") + "  (" + BigNumber.Format Short(Upgrades.Cost Of("auto_miner")) + ")"

On Ready
  -> Miner Button: set text to "Auto Miner  Lv " + Upgrades.Level Of("auto_miner") + "  (" + BigNumber.Format Short(Upgrades.Cost Of("auto_miner")) + ")"
  # refresh once on load and again after every purchase
```

### 5. Buy-max in a loop

Scenario: a "Buy Max" button spends gold on one upgrade until it can't anymore.

```
On Buy Max Pressed
  Repeat 1000 times
    Condition: Upgrades  Purchase Succeeded  (evaluated after the call below)
    -> Upgrades: Try Purchase  "click_power", CurrencyLedger.Balance("gold")

On Upgrade Bought
  -> CurrencyLedger: Spend  "gold", Upgrades.Last Cost()
  # each successful level pays immediately, lowering the balance for the next iteration; a failed one stops the run
```

### 6. Compose a production rate from tags

Scenario: gold-per-second is a base value lifted by additive and multiplicative upgrades together.

```
Every 1 seconds
  -> Local: set base_rate to 1
  -> Local: set rate to (base_rate + Upgrades.Total Bonus("production")) * Upgrades.Total Multiplier("production")
  -> CurrencyLedger: Add  "gold", rate
  # (base + flat bonuses) * multiplier - the classic idle formula, both aggregates from one table
```

### 7. Click power scales your tap earnings

Scenario: each tap earns a base 1 plus everything in the "click" tag.

```
On Screen Tapped
  -> Local: set earn to (1 + Upgrades.Total Bonus("click"))
  -> CurrencyLedger: Add  "gold", earn
  # buying click_power raises Total Bonus("click"), so taps earn more with no other change
```

### 8. Gate an automation loop behind ownership

Scenario: the auto-miner only runs once its upgrade has at least one level.

```
Every 1 seconds
  Condition: Upgrades  Owns  "auto_miner"
    -> CurrencyLedger: Add  "gold", Upgrades.Effect Of("auto_miner")
  # Effect Of("auto_miner") is level * 0.5 here - it grows as you buy levels
```

### 9. A one-time unlock that sells out

Scenario: a permanent "golden touch" perk can be bought once, then the button disables.

```
On Ready
  -> Upgrades: Define Upgrade  "golden_touch", 2500, 1, 1, 1, "mult", "perk"

On Buy Perk Pressed
  Condition: NOT Upgrades  Is Maxed  "golden_touch"
    -> Upgrades: Try Purchase  "golden_touch", CurrencyLedger.Balance("gold")

On Upgrade Bought
  -> CurrencyLedger: Spend  "gold", Upgrades.Last Cost()

On Upgrade Bought
  Condition: Upgrades  Is Maxed  "golden_touch"
    -> Buy Perk Button: disable
```

### 10. Grant a free level as a quest reward

Scenario: finishing a quest hands the player a click_power level for free, no cost.

```
On Quest Completed
  -> Upgrades: Grant Level  "click_power"
  -> Toast: show "Reward: Click Power now Lv " + Upgrades.Level Of("click_power")
  # Grant Level skips the budget and the wallet entirely, capped at max_level
```

### 11. A prestige button that wipes the run

Scenario: prestige grants a permanent boost, then clears every run-scoped upgrade back to level 0.

```
On Prestige Confirmed
  -> Upgrades: Reset
  -> Upgrades: Grant Level  "double_prestige"
  -> CurrencyLedger: Define Currency  "gold", 0, -1
  # Reset zeroes levels but keeps definitions - buy costs start fresh at base_cost
```

Note: Reset returns every upgrade to level 0, including double_prestige. Because Reset wipes ALL upgrades, a meta perk must be re-Granted AFTER the Reset (as above), never before - a level granted first would be zeroed by the Reset. Or read Total Multiplier for its tag into a saved variable before wiping.

### 12. Save every upgrade level

Scenario: on save, walk the catalogue and store each id's level.

```
On Save Requested
  -> SaveSystem: begin "upgrades"
  -> Upgrades: (for each known id in your list)
  -> SaveSystem: write "click_power", Upgrades.Level Of("click_power")
  -> SaveSystem: write "auto_miner", Upgrades.Level Of("auto_miner")
  -> SaveSystem: write "gold_boost", Upgrades.Level Of("gold_boost")
  # Level Of reads out the number to persist; Upgrade Count() tells you how many are defined
```

### 13. Load upgrade levels back

Scenario: on load, restore each saved level - Set Level clamps to the cap for you.

```
On Load Finished
  -> Upgrades: Define Upgrade  "click_power", 10, 1.15, -1, 1, "add", "click"
  -> Upgrades: Define Upgrade  "gold_boost", 500, 2.0, 5, 1.5, "mult", "production"
  -> Upgrades: Set Level  "click_power", SaveSystem.read("click_power")
  -> Upgrades: Set Level  "gold_boost", SaveSystem.read("gold_boost")
  # define first so the cost curve exists, then Set Level to the saved value
```

### 14. Offline catch-up using the current multiplier

Scenario: on return, credit away-time gold at the production rate the player's upgrades already earn.

```
On Ready
  -> Upgrades: (definitions and Set Level restored first, see use case 13)
  -> Local: set rate to (1 + Upgrades.Total Bonus("production")) * Upgrades.Total Multiplier("production")
  -> CurrencyLedger: Add  "gold", rate * seconds_since_last_played
  -> Welcome Popup: show "While away you earned " + BigNumber.Format Short(rate * seconds_since_last_played) + " gold"
  # the upgrades carry all the scaling - one rate, times the seconds away
```

### 15. Live-balance an upgrade mid-session

Scenario: a difficulty patch nerfs gold_boost's payoff without resetting anyone's level.

```
On Balance Patch Applied
  -> Upgrades: Set Effect  "gold_boost", 1.35, "mult"
  # existing gold_boost levels stay; each level is now worth *1.35 instead of *1.5
```

### 16. A catalogue counter for a menu header

Scenario: an upgrades screen shows how many upgrades exist and how many the player owns.

```
On Upgrades Screen Opened
  -> Header Label: set text to Upgrades.Upgrade Count() + " upgrades available"

On Upgrade Bought
  -> Total Spent Label: set text to "Just spent " + BigNumber.Format Short(Upgrades.Last Cost()) + " on " + Upgrades.Last Upgrade()
```

### 17. A talent tree gated on its own prerequisites

Scenario: a warrior tree where Sprint needs Swift, which needs Toughness, and a click may only spend
points on a node the player has actually earned.

```
On Ready
  -> Upgrades: Load Skill Tree  tree
  -> Upgrades: Set Skill Points  4

On Node Button Pressed
  -> Upgrades: Unlock  HudKit.Last Button Name()

On Unlock Refused
  -> HUD Kit: Show Toast  "Needs " + Upgrades.Skill Requires(Upgrades.Last Skill()) + " first"
```

### 18. A perk that gates a mechanic, granting nothing at all

Scenario: Double Jump is a node with a blank Grants cell. The tree records it; the player script asks.

```
On Physics Process  |  Player is on floor
  -> Set jumps_left to 2 when Upgrades: Is Unlocked "double_jump", otherwise 1

On Jump Pressed  |  jumps_left is greater than 0
  -> Subtract 1 from jumps_left
  -> Player: set velocity Y to -340
```

### 19. A speed upgrade carried by StatForge instead of a formula

Scenario: Swift is `speed x1.1 per level` in the asset, taken up to three times. Nothing multiplies
anything by hand - the body asks its stat stack for its speed every frame.

```
On Ready
  -> Upgrades: Apply Grants To  Player/Stats
  -> StatForge: Set Stat Base  "speed", 120

On Physics Process
  -> Player: set velocity X to steer * StatForge.Stat Total("speed")
```

### 20. A respec button that gives every point back

Scenario: a "reset my build" button refunds the whole tree, clears the unlocks and strips the buffs
they applied - without touching the player's gold, their level, or any upgrade outside the tree.

```
On Respec Button Pressed
  -> Upgrades: Respec
  -> HUD Kit: Set Text  "PointsValue", "Skill points left: " + Upgrades.Skill Points()
  -> HUD Kit: Show Toast  "Build reset"
```

### Other use cases

**Tower-defense between-wave shops.** Define "tower_damage", "tower_range", and "fire_rate" as add-mode upgrades and let the player spend wave gold in the intermission. Each tower reads Total Bonus("damage") on the next wave, so one aggregate call retunes every turret on the map.

**Roguelite meta-progression.** Permanent between-run perks like "+10 starting health" are add-mode upgrades bought with the bones or gems a run banks. Because the prestige-style Reset is something you invoke yourself, the meta catalogue simply never gets wiped and keeps compounding across runs.

**Blacksmith gear enhancement.** A weapon enhanced from +1 to +10 is one upgrade with max_level 10 and a steep cost_growth, so each rank costs visibly more at the forge. Is Maxed swaps the button for a MAX badge, and Effect Of drives the weapon's bonus damage.

**Survivors-style level-up drafts.** When the run's XP bar fills, offer three upgrade cards and call Grant Level on the chosen one - no wallet involved mid-fight. The build's stats stay readable as Total Bonus and Total Multiplier per tag, and the run-scoped catalogue resets cleanly for the next attempt.

**City-builder building tiers.** Each structure's level is an upgrade: the town hall at level 3 gates the barracks via Level Of, and a max_level keeps districts finite. Cost growth per tier gives the classic "each expansion costs more" pacing without a hand-written price table.

---

## Tips and common mistakes

- **This pack never touches your wallet.** Try Purchase only compares the `budget` number you pass to Cost Of. It does not earn or spend anything. You must Spend Last Cost from the Currency Ledger pack inside On Upgrade Bought - if you skip that, the level goes up for free.
- **Pass your real balance as the budget.** Feed Try Purchase the actual money you have (`CurrencyLedger.Balance("gold")`), not a guess. If the budget is bigger than what you own, the buy will succeed and you will try to Spend more than you have.
- **Last Cost is the price that was just paid - Cost Of is the next price.** Inside On Upgrade Bought, Spend `Last Cost()` (what the level you just bought cost). Use `Cost Of(id)` to show the price of the level the player has NOT bought yet.
- **Context expressions are only meaningful right after the call.** Last Cost, Last Upgrade, and Purchase Succeeded describe the most recent Try Purchase. Read them inside On Upgrade Bought / On Purchase Failed or immediately after the call, not on a later frame.
- **add versus mult must match the aggregate.** Total Bonus(tag) only sees `mode = "add"` upgrades and Total Multiplier(tag) only sees `mode = "mult"` ones. An add-mode upgrade under a tag you read with Total Multiplier contributes nothing, and vice versa. Combine them as `(base + Total Bonus) * Total Multiplier`.
- **Effect Of is one upgrade; Total Bonus / Total Multiplier are a whole tag.** Use Effect Of(id) when a single generator's output matters; use the Total aggregates when a category should compose into one number. Do not sum Effect Of by hand across a tag - that is exactly what the aggregates do.
- **Cost Of returns -1 at the cap.** A maxed or undefined upgrade reports -1, and Try Purchase on it fires On Purchase Failed. Guard buttons with Is Maxed(id) if you want to grey them out before the player taps.
- **A one-time upgrade is just max_level 1.** There is no separate one-time type. Set max_level to 1 for a single purchase, a small number for a limited track, or -1 for unlimited. Owns(id) tells you if it has any levels; Is Maxed(id) tells you if it is full.
- **Reset keeps definitions, wipes levels.** Reset sends every upgrade to level 0 but leaves its cost curve and tag intact, so buy prices restart at base_cost. It resets ALL upgrades, including prestige perks - re-Grant any meta upgrade that must survive, or read its value out before resetting.
- **A tree grants nothing until you say where.** Unlock records the level and reads the Grants cell either way, but the modifiers land on a StatForge stack only after **Apply Grants To** has named one. Call it once on ready, beside Load Skill Tree.
- **Levels replace, they do not stack.** A grant is written as one buff keyed by skill and stat, so taking Swift a second time REPLACES the first level's buff with the second's (`x1.1` becomes `x1.1^2`). That is why a per-level multiplier compounds correctly and a flat one does not double-count.
- **Loading a tree wipes what was unlocked.** Load Skill Tree is "open this tree fresh": it clears the unlocked table and resets the points to the asset's Starting Points. Restore a save with Set Skill Points and the Save System's load_state, not by re-loading the asset afterwards.
- **Requires is spelled with the id, not the name.** The `requires` cell holds ids from the `id` column, comma-separated. A display name there names a skill that does not exist, and the Project Doctor reports it as an error rather than letting the node sit unreachable.
- **Define first, then Set Level on load.** Set Level needs the record to exist to clamp against the cap. Call Define Upgrade before Set Level when restoring a save, or the level lands on a default record instead of your real one.
