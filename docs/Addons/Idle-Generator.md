# Idle Generator

Idle Generator is a buy-more-to-make-more producer for incremental games - the cursor, farm, factory, or mine you buy in bulk to raise your output. It ships as a **behavior you attach to a node** (one node per generator type), and every unit costs more than the last on a geometric curve (`cost = base_cost * cost_growth^owned`, the classic 1.15 growth), so buying a hundred at once is exact closed-form math, not a loop. It gives you three buy verbs (Buy One / Buy Amount / Buy Max), a continuous Output Per Second, and an optional fill-and-collect cycle mode for building-style production. It deliberately does NOT hold your money: the Buy actions only record what they cost as Last Cost, and it is your sheet that Spends that from the wallet. It also does not draw buttons, format big numbers, or grant currency - that stays your job.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Cookie-Clicker producers.** Cursors, grandmas, farms - each is one generator node with its own base cost and output, all humming out Output Per Second.
- **AdVenture-Capitalist buildings.** Set Cycle Time above zero and each building fills, fires On Cycle Complete, and banks a lump you Collect - the manager-and-timer loop without writing a timer.
- **Bulk buying with Buy One / x10 / x100 / Max.** Buy Amount and Buy Max compute the exact geometric-series price up front, so the "buy 100" button never runs a hundred-step loop.
- **Buy-Max buttons that spend exactly what they can.** Max Affordable and Cost To Buy Max let a button preview the count and price before the player commits.
- **Prestige resets.** Reset wipes owned, pending, and cycle progress in one row so a prestige button re-seeds the run cleanly.
- **Offline catch-up.** Production Over(seconds) gives the exact yield for any elapsed time, so a "while you were away" credit is one expression.
- **Stacked multipliers.** Feed a single composed prestige x upgrade x boost number into Set Output Multiplier and the whole generator scales at once.
- **Universal-Paperclips-style single producers.** One generator with a steep growth curve models a lone escalating machine just as well as a hundred cheap ones.
- **Automation and managers.** A manager is just an On Cycle Complete handler that calls Collect for you instead of a tap - no new mechanic needed.
- **Save and load.** The exported fields (owned, multiplier, cost curve, cycle time) are plain numbers you snapshot and restore with any save pack.
- **Mixed economies.** Continuous cursors and cycle-based factories coexist because each is its own node with its own mode.

---

## Core concepts

The mental model is one node = one generator type. You buy more of it, each costs more than the last, and it produces on one of two models. Everything is a field on the node.

| Field | What it means |
|---|---|
| **base_cost** | Price of the FIRST unit. The default is 10. |
| **cost_growth** | How much each unit multiplies the price. `1.15` = +15% each (the genre default); `1.0` = flat price. |
| **base_output** | Output of ONE unit - per second in continuous mode, or per cycle when Cycle Time is above 0. |
| **output_multiplier** | A multiplier over the whole generator. Feed it your composed prestige x upgrade x boost value. |
| **owned** | How many units are owned. Set a starting count or leave 0 and buy them in play. |
| **cycle_time** | `0` = continuous production (Output Per Second). Above 0 = a fill-and-collect cycle this many seconds long. |

A handful of rules are the whole behaviour of the pack:

- **Cost is a geometric curve.** Unit N costs `base_cost * cost_growth^N`. Next Cost, Cost For(n), Max Affordable(budget), and Cost To Buy Max(budget) are all exact closed-form values - correct even at millions owned, with no loop.
- **The pack never touches your wallet.** Buy One / Buy Amount / Buy Max add units and record the price as Last Cost, but they do not check or subtract money. Your sheet reads Last Cost and Spends it from Currency Ledger. Guard with Can Afford Next (or Max Affordable) first.
- **Two production models, chosen by Cycle Time.** Leave Cycle Time at 0 for continuous output - read Output Per Second and credit Production Over(delta) each frame. Set it above 0 and the generator fills a cycle, banks `owned * base_output * multiplier` into Pending on completion, and fires On Cycle Complete; you then Collect to claim Last Collected.
- **Output scales three ways at once.** Effective output is `owned * base_output * output_multiplier`. Buy more (owned), start with beefier units (base_output), or crank the multiplier - they all stack.

This is one clean producer. There is no separate "clicker" and "building" object: a generator with Cycle Time 0 is continuous, and the same generator with Cycle Time above 0 is a building.

---

## Setup

Idle Generator installs as a **behavior**. Once the pack is in `eventsheet_addons/`, attach the Idle Generator behavior to a node - one node per generator type (a Cursor node, a Farm node, a Factory node). Set its exported fields (base cost, growth, base output, cycle time, starting owned) in the inspector, then drive it from any sheet by calling its verbs on that node.

A minimal first generator, as event-sheet rows (the node is named `Farm`, and the wallet is the separate Currency Ledger pack):

```
On Ready
  # Farm's exported fields set in the inspector: base_cost 15, cost_growth 1.15, base_output 1

On Buy Farm Pressed
  Condition: Farm  Can Afford Next  CurrencyLedger.Balance("gold")
    -> Farm: Buy One
    -> CurrencyLedger: Spend  "gold", Farm.Last Cost()
    # the pack recorded the price; YOU spend it

Every tick (On Process)
  -> CurrencyLedger: Add  "gold", Farm.Production Over(delta)
  # credit this frame's continuous output
```

That is the whole loop: buy raises owned and records a cost you spend, and Production Over(delta) turns owned units into per-frame gold.

---

## ACE reference

Every verb below is called on the generator node it is attached to. Parameters are numbers. All names are the exact display names from the pack.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Buy One | (none) | Adds one unit and records its price as Last Cost (Spend that from your wallet). Guard with Can Afford Next first. Fires On Purchased. |
| Buy Amount | count | Adds `count` units at once and records the total price as Last Cost. Does nothing if count is 0 or less. Fires On Purchased. |
| Buy Max | budget | Buys as many as `budget` affords, recording the exact total as Last Cost and the count as Last Bought. Buys nothing (Last Bought 0) if not even one is affordable. Fires On Purchased when at least one is bought. |
| Set Owned | count | Forces the owned count to a value (clamped to 0). Does not record a cost. |
| Grant | count | Adds free units - a reward or a starting bonus (no cost recorded). |
| Set Output Multiplier | multiplier | Sets the overall output multiplier - feed it your composed prestige x upgrade x boost value. |
| Collect | (none) | Cycle mode: hands you the banked output as Last Collected and clears the pending pile. Call it on On Cycle Complete (or from a manager) and credit Last Collected to your wallet. |
| Reset | (none) | Clears owned, pending output, and cycle progress - for a prestige wipe. |

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Can Afford Next | budget | Whether `budget` covers the next single unit's price. |
| Is Owned | (none) | Whether at least one unit is owned. |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Owned | Number | (none) | How many units are owned. |
| Next Cost | Number | (none) | The price of the next single unit. |
| Cost For | Number | count | The total price to buy `count` more units right now. |
| Max Affordable | Number | budget | How many units `budget` can buy. |
| Cost To Buy Max | Number | budget | The exact total spent if you Buy Max with `budget`. |
| Output Per Second | Number | (none) | Current production per second (owned * base_output * multiplier; in cycle mode, the lump divided by cycle time). |
| Production Over | Number | seconds | How much is produced over `seconds` at the current rate - pass delta to credit each frame. |
| Pending | Number | (none) | Cycle mode: output banked and waiting for Collect. |
| Cycle Progress | Number | (none) | Cycle mode: how full the current cycle is, 0 to 1 (0 in continuous mode). |
| Last Cost | Number | (none) | What the last Buy cost - Spend this from your wallet. |
| Last Bought | Number | (none) | How many units the last Buy added (0 if Buy Max could not afford any). |
| Last Collected | Number | (none) | How much the last Collect handed you. |

### Triggers

| Trigger | When it fires |
|---|---|
| On Purchased | After a Buy One / Buy Amount / Buy Max adds at least one unit. Read Last Cost and Last Bought inside it. |
| On Cycle Complete | In cycle mode (Cycle Time above 0), each time a cycle fills and banks a lump into Pending. Call Collect to claim it. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Use cases

Each snippet uses real display names. `Farm.Name(...)` (or whatever the generator node is called) is how you read an expression inside a value field. The wallet is the separate Currency Ledger pack; short number strings come from the Big Numbers pack.

### 1. A buy button that spends from the wallet

Scenario: tap to buy one cursor, but only if the player can pay, and subtract the exact price.

```
On Buy Cursor Pressed
  Condition: Cursor  Can Afford Next  CurrencyLedger.Balance("gold")
    -> Cursor: Buy One
    -> CurrencyLedger: Spend  "gold", Cursor.Last Cost()
    # the pack recorded the price; you do the spending
```

### 2. A HUD label showing owned count and next price

Scenario: the buy button always shows how many you own and what the next one costs.

```
On Purchased
  -> Cursor Label: set text to BigNumber.Format Short(Cursor.Owned()) + " cursors"
  -> Price Label: set text to "Next: " + BigNumber.Format Short(Cursor.Next Cost())

On Ready
  -> Cursor Label: set text to BigNumber.Format Short(Cursor.Owned()) + " cursors"
  -> Price Label: set text to "Next: " + BigNumber.Format Short(Cursor.Next Cost())
  # On Purchased only fires on a buy, so seed the labels on load too
```

### 3. Continuous production credited every frame

Scenario: a Cookie-Clicker producer trickles gold into the wallet each tick.

```
Every tick (On Process)
  -> CurrencyLedger: Add  "gold", Farm.Production Over(delta)
  # Production Over(delta) = Output Per Second * this frame's delta
```

### 4. A "buy x10" button with an exact bulk price

Scenario: a bulk button buys ten at once and spends the exact geometric-series total.

```
On Buy Ten Pressed
  Condition: CurrencyLedger  Can Afford  "gold", Farm.Cost For(10)
    -> Farm: Buy Amount  10
    -> CurrencyLedger: Spend  "gold", Farm.Last Cost()
    # Cost For(10) previews the total before you commit
```

### 5. A Buy-Max button that spends everything affordable

Scenario: one tap buys as many as the wallet allows and shows how many landed.

```
On Buy Max Pressed
  -> Factory: Buy Max  CurrencyLedger.Balance("gold")
  Condition: Factory  Is Owned
    -> CurrencyLedger: Spend  "gold", Factory.Last Cost()
    -> Toast: show "Bought " + BigNumber.Format Short(Factory.Last Bought()) + " factories"

On Buy Max Pressed
  Condition: Factory.Last Bought() = 0
    -> Toast: show "Can't afford even one"
  # Buy Max buys nothing and sets Last Bought 0 when the next unit is too dear
```

### 6. Previewing the Buy-Max count and price on a label

Scenario: the Buy-Max button label reads "Buy 42 (1.2M)" before the player taps.

```
On Amount Changed
  Condition: CurrencyLedger  Has Currency  "gold"
    -> Max Button: set text to "Buy " + BigNumber.Format Short(Mine.Max Affordable(CurrencyLedger.Balance("gold"))) + " (" + BigNumber.Format Short(Mine.Cost To Buy Max(CurrencyLedger.Balance("gold"))) + ")"
  # Max Affordable and Cost To Buy Max are both exact, no loop
```

### 7. A cycle-based building you tap to collect

Scenario: an AdVenture-Capitalist lemonade stand fills over time and pays a lump when tapped.

```
On Ready
  # Stand's cycle_time set to 4 in the inspector: a 4-second fill

On Cycle Complete
  -> Collect Glow: play "ready to collect"
  # the lump is banked in Pending, waiting for a tap

On Stand Tapped
  -> Stand: Collect
  -> CurrencyLedger: Add  "gold", Stand.Last Collected()
  # Collect hands you Last Collected and clears Pending
```

### 8. A manager that auto-collects the cycle

Scenario: buying a manager makes a building collect itself the instant a cycle completes.

```
On Cycle Complete
  Condition: Managers  is manager hired "stand"
    -> Stand: Collect
    -> CurrencyLedger: Add  "gold", Stand.Last Collected()
  # a manager is just an auto-Collect on the same trigger a tap would use
```

### 9. A cycle fill bar

Scenario: a progress bar shows how full the current cycle is.

```
Every tick (On Process)
  -> Fill Bar: set value to Stand.Cycle Progress() * 100
  # Cycle Progress is 0 to 1 while filling, 0 in continuous mode
```

### 10. Offline catch-up on return

Scenario: continuous producers should credit what they made while the game was closed.

```
On Ready
  -> Local: set away_seconds to now_minus_last_played
  -> CurrencyLedger: Add  "gold", Farm.Production Over(away_seconds)
  -> CurrencyLedger: Add  "gold", Cursor.Production Over(away_seconds)
  -> Welcome Popup: show "While away your producers made " + BigNumber.Format Short(Farm.Production Over(away_seconds) + Cursor.Production Over(away_seconds)) + " gold"
  # Production Over(seconds) is the exact yield for any elapsed time
```

### 11. Stacking prestige, upgrade, and boost multipliers

Scenario: three separate multipliers combine into one number fed to the generator.

```
On Multipliers Changed
  -> Local: set total to prestige_mult * upgrade_mult * boost_mult
  -> Farm: Set Output Multiplier  total
  # Output Per Second now reflects owned * base_output * total
```

### 12. A prestige button that wipes producers

Scenario: prestige resets every generator but grants a permanent prestige point.

```
On Prestige Confirmed
  -> CurrencyLedger: Add  "prestige_points", 1
  -> Cursor: Reset
  -> Farm: Reset
  -> Factory: Reset
  -> CurrencyLedger: Set Amount  "gold", 0
  # Reset clears owned, pending, and cycle progress on each generator
```

### 13. Granting free starter units

Scenario: a first-time-bonus or an ad reward hands the player some free farms.

```
On Starter Bonus Claimed
  -> Farm: Grant  5
  # Grant adds units with no cost recorded and no Spend needed

On Rewarded Ad Watched
  -> Cursor: Grant  10
```

### 14. Saving and loading a generator

Scenario: persist each generator across sessions using a save pack.

```
On Save
  -> SaveSystem: set "farm_owned" to Farm.Owned()
  -> SaveSystem: set "farm_mult" to Farm.Output Multiplier field   # exported var
  -> SaveSystem: write

On Load
  -> Farm: Set Owned  SaveSystem.get "farm_owned"
  -> Farm: Set Output Multiplier  SaveSystem.get "farm_mult"
  # Set Owned restores the count without charging for it
```

### 15. A milestone bonus at owned thresholds

Scenario: every 25 cursors owned doubles that generator's output.

```
On Purchased
  Condition: Cursor.Owned() >= 25
  Condition: Cursor.Owned() mod 25 = 0
    -> Local: set milestones to Cursor.Owned() / 25
    -> Cursor: Set Output Multiplier  pow(2, milestones)
    -> Toast: show "Cursor milestone! Output doubled"
  # read Owned inside On Purchased right after the buy landed
```

### 16. A flat-price consumable generator

Scenario: a generator whose units never get pricier (set cost_growth to 1.0 in the inspector).

```
On Buy Torch Pressed
  Condition: Torch  Can Afford Next  CurrencyLedger.Balance("gold")
    -> Torch: Buy One
    -> CurrencyLedger: Spend  "gold", Torch.Last Cost()
  # with cost_growth 1.0 every torch costs exactly base_cost
```

### Other use cases

**Tower-defense banks.** An income tower is a generator node: each one bought costs more, and Production Over credits gold between waves, giving the classic "economy tower" tradeoff with no custom math.

**Escalating reroll prices.** A shop reroll button is a generator with zero output - Buy One just records the geometrically climbing Last Cost, so each reroll gets pricier along a tuned curve.

**City-builder power plants.** Plants run in cycle mode, banking energy every cycle; the player (or a built manager) Collects on visits, and Cycle Progress fills each plant's little gauge on the map.

**Restaurant staffing.** Each staff role is a generator - cooks produce meals per second, waiters raise the multiplier - so a food-truck-to-empire sim is a handful of nodes and one wallet.

**Garden that grows while you adventure.** An RPG farm plot uses Production Over with the time since your last visit, so returning from a dungeon pays out exactly what the crops earned while you were away.

---

## Tips and common mistakes

- **This pack never touches your wallet.** Buy One / Buy Amount / Buy Max only add units and record the price as Last Cost - they do not check or subtract money. Read Last Cost and Spend it yourself from Currency Ledger. Forgetting the Spend gives the player free units.
- **Guard the buy, or check Last Bought after.** Put Can Afford Next (single buys) or Max Affordable (bulk) in front, or let Buy Max run and check Last Bought - it is 0 when nothing was affordable. Do not Spend Last Cost after a Buy Max that bought nothing; Last Cost is 0 there anyway, but the Spend row is pointless.
- **Buy Max spends the whole budget's worth, not one.** Pass it the current balance and it buys every unit that fits, recording the exact total. It is not "buy the most expensive one"; it is "buy as many as you can".
- **Cost For and Cost To Buy Max are exact and loop-free.** They evaluate the geometric series in closed form, so previewing the price of buying 10,000 units is as cheap as previewing one. Do not hand-roll a purchase loop to total the cost.
- **Cycle mode needs Cycle Time above 0.** With Cycle Time at 0 the generator is continuous - Pending stays 0, Cycle Progress stays 0, and On Cycle Complete never fires. Set Cycle Time above 0 to get the fill-and-collect building; only then do Pending, Collect, and Last Collected mean anything.
- **Collect is the only thing that pays out a cycle.** On Cycle Complete banks the lump into Pending but does not credit your wallet. You must call Collect (from a tap or a manager) and then Add Last Collected to the wallet. Reading Pending without Collecting never spends it down.
- **Do not mix the two production models on one generator.** A generator is continuous or cycle-based, not both. In continuous mode credit Production Over(delta) each frame; in cycle mode credit Last Collected on Collect. Do not also Add Production Over in cycle mode or you double-pay.
- **Set Owned and Grant do not record a cost.** They are for saves, rewards, and starting bonuses - Last Cost is untouched, so do not Spend after them. Only the three Buy verbs set Last Cost.
- **Context expressions are only valid inside their trigger.** Last Cost and Last Bought describe the most recent buy, so read them inside On Purchased or right after your own Buy row. Last Collected describes the most recent Collect. Reading them at an unrelated time gives you a stale value.
- **Output Multiplier is a single composed number.** Set Output Multiplier replaces the multiplier, it does not stack onto it. Compose your prestige x upgrade x boost product yourself and set the result, or each source will clobber the others.
