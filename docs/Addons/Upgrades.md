# Upgrades

Upgrades is the stacking buff engine an incremental game is built from, driven from any event sheet. Register an upgrade by string id (click_power, auto_miner, prestige_boost, crit_chance, or anything you can name) with a base cost, a cost growth per level, a max level, a per-level effect, an effect mode (add or mult), and a tag. Then buy levels, read the stacked effect, and roll every tagged upgrade into one number. It ships as an **autoload**: once the pack is installed it is the `Upgrades` singleton, live from the first frame with no node to place and no wiring. It holds the levels and the cost curves and fires a trigger on every purchase attempt. It does NOT touch your wallet - Try Purchase checks a budget you hand it and records the price, and you Spend that yourself from the Currency Ledger pack. It also does not draw buttons, bars, or numbers - that stays your job, driven by the triggers below.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

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

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Is Maxed | id | Whether an upgrade is at its max level. |
| Owns | id | Whether an upgrade has at least one level. |
| Purchase Succeeded | (none) | Whether the last Try Purchase went through (read it right after, or in On Upgrade Bought). |

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

### Triggers

| Trigger | When it fires |
|---|---|
| On Upgrade Bought | After a Try Purchase raises a level. Read Last Cost (Spend it), Last Upgrade, and Purchase Succeeded inside it. |
| On Purchase Failed | When a Try Purchase can't be afforded or the upgrade is maxed; nothing changed. Read Last Upgrade inside it. |

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
- **Define first, then Set Level on load.** Set Level needs the record to exist to clamp against the cap. Call Define Upgrade before Set Level when restoring a save, or the level lands on a default record instead of your real one.
