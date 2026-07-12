# Prestige

Prestige is the reset-for-a-permanent-multiplier loop at the heart of every incremental game, packaged as a tiny state machine you drive from any event sheet. You feed it what the player earns this run with Track Earned, it previews the prestige points a reset would bank with the classic square-root chip formula, and on Do Prestige it banks those points, raises the prestige level, and clears the run total so points are never double-awarded. Prestige Multiplier turns banked points into the permanent production boost you multiply your generators by. It ships as an **autoload**: once the pack is installed it is the `Prestige` singleton, live from the first frame with no node to place and no wiring. It does NOT touch your wallet or your generators - it only tracks the prestige currency and tells you the gain. Resetting the actual currencies (usually via the Currency Ledger pack) is your job, done in the same event that calls Do Prestige.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **The first-prestige wall.** Give a run a requirement of a million earned and a 0.5 exponent, and the "reset for +2% per point" loop that defines Cookie Clicker's heavenly chips is three rows: Track Earned, Can Prestige, Do Prestige.
- **Square-root prestige curves.** The built-in formula is `floor((run_earned / requirement) ^ exponent)`, so the usual diminishing-returns square-root curve (exponent 0.5) is the default and needs no math on your side.
- **Ascension and rebirth buttons.** Whatever your game calls it - prestige, ascend, rebirth, reincarnate - it is the same bank-and-reset, and Do Prestige is the whole button.
- **Permanent production multipliers.** Prestige Multiplier is `1 + points * bonus`, the exact permanent boost you multiply every generator's output by, so a single expression drives your whole economy's scaling.
- **Live "prestige for +N" previews.** Prestige Gain shows the points a reset would bank right now, so the button can read "Prestige for 12 points" and update as the run grows.
- **Progress bars toward the next point.** Progress To Next returns 0 to 1 across the current point's earning band, so a fill bar toward the next chip is one expression.
- **All-time achievement tallies.** Total Earned never resets, so lifetime-earning achievements and stat screens keep counting across every prestige.
- **Layered prestige (meta-prestige).** Prestige Level and Prestige Points are plain numbers, so a second, slower layer can gate on level or spend banked points however you design it.
- **Idle catch-up on load.** Bank a run offline, load Prestige Points and Total Earned from a save, and the permanent multiplier is correct on the first frame with Set Points.
- **Cheat and testing menus.** Set Points and Hard Reset make a debug panel that jumps to any prestige state or wipes to a clean new game trivial to build.

---

## Core concepts

The mental model is three running tallies plus a tuning curve. You feed one number in (earnings) and read four numbers out (gain, points, level, multiplier).

| Field | What it means |
|---|---|
| **run earned** | Earnings THIS run. Drives the gain, and Do Prestige resets it to 0 so points can't double-award. Read with `Run Earned()`. |
| **total earned** | All-time earnings. Never reset - for achievements and lifetime stats. Read with `Total Earned()`. |
| **points** | Banked prestige currency. Grows by the gain on each Do Prestige. Read with `Prestige Points()`. |
| **level** | How many times the player has prestiged. Read with `Prestige Level()`. |
| **requirement** | Run earnings needed before the first point. Default 1,000,000. Set with Configure. |
| **exponent** | The curve. 0.5 (default) is the classic square-root. Set with Configure. |
| **bonus per point** | How much each banked point adds to the multiplier. Default 0.02 (+2% each). Set with Configure. |

A few rules tie those together, and they are the whole behaviour of the pack:

- **Gain is `floor((run_earned / requirement) ^ exponent)`.** Below the requirement the gain is 0. It is guarded against a zero requirement and clamps an overflowed `pow()` so the value is always a sane integer.
- **The multiplier is `1 + points * bonus`.** With the default bonus of 0.02, ten banked points give a 1.2x permanent boost. Zero points give exactly 1.0, so it is safe to multiply by from frame one.
- **Do Prestige banks Prestige Gain, bumps the level, and clears run earned.** It does nothing if the gain is 0. Read Prestige Gain BEFORE calling it if you want to show "you banked N", or read Last Gain after (or inside On Prestige).
- **The pack never touches your wallet or generators.** It tracks the prestige currency only. You reset the actual game (currencies, upgrades, buildings) yourself in the same event, after reading the gain.

This is one clean prestige model. There is no hidden currency store and no automatic reset of your game state: Prestige owns the points and the curve, you own everything the reset actually wipes.

---

## Setup

Nothing to install per project beyond the pack. Once the Prestige pack is in `eventsheet_addons/`, it registers itself as the `Prestige` autoload, so every sheet can call it by name with no node to drop and no reference to pass around.

A minimal first prestige loop, as event-sheet rows:

```
On Ready
  -> Prestige: Configure  1000000, 0.5, 0.02
  # a point per sqrt(earned / 1,000,000); each point adds +2% forever

On Gold Earned
  -> Prestige: Track Earned  amount_of_gold_earned
  # feed the pack the same amount you added to the wallet

On Prestige Button Pressed
  Condition: Prestige  Can Prestige
    -> Prestige: Do Prestige
    -> CurrencyLedger: Define Currency  "gold", 0, -1
    # Do Prestige banks the points; you wipe the wallet yourself
```

That is the whole loop: configure once, feed earnings, and reset when the gain is worth it - resetting your own currencies in the same event.

---

## ACE reference

Every name below is the exact display name from the pack. Amounts are numbers.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Configure | requirement, exponent, bonus_per_point | Sets the requirement (run earnings before you gain a point), the exponent (curve; 0.5 = square-root, the usual), and the bonus each banked point adds to Prestige Multiplier. |
| Track Earned | amount | Records earnings toward prestige - call it wherever the player earns the prestige currency. Feeds both the run total (drives the gain) and the all-time Total Earned. |
| Do Prestige | (none) | Banks the current Prestige Gain, raises the prestige level, and clears the run total. Does nothing if the gain is 0. Reset your currencies and generators in the same event, reading Prestige Gain first. |
| Set Points | points | Forces banked prestige points to a value (for a load or a cheat menu). |
| Hard Reset | (none) | Wipes EVERYTHING - points, level, run and all-time earnings. A full new-game, not a prestige. |

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Can Prestige | (none) | Whether prestiging now would bank at least one point. |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Prestige Gain | Number | (none) | How many prestige points the current run would bank right now. |
| Prestige Points | Number | (none) | Banked prestige currency. |
| Prestige Level | Number | (none) | How many times the player has prestiged. |
| Prestige Multiplier | Number | (none) | The permanent production multiplier from banked points: 1 + points * bonus. |
| Run Earned | Number | (none) | Earnings this run (resets on Do Prestige). |
| Total Earned | Number | (none) | All-time earnings (never resets). |
| Last Gain | Number | (none) | Points banked by the most recent Do Prestige (read inside On Prestige). |
| Requirement | Number | (none) | The run earnings needed before the first point. |
| Earned For Next Point | Number | (none) | The run earnings needed to reach the next prestige point. |
| Progress To Next | Number | (none) | How close this run is to the next point, 0 to 1 (for a progress bar). |

### Triggers

| Trigger | When it fires |
|---|---|
| On Prestige | After Do Prestige banks points and resets the run. Read Last Gain inside it for how many points were just banked. |

---

## Use cases

Each snippet uses real display names. `Prestige.Name(...)` is how you read an expression inside a value field. Where a snippet spends money or formats a big number, it leans on the separate Currency Ledger and Big Numbers packs.

### 1. Configure the prestige curve on load

Scenario: a run banks a point per square-root of millions earned, each point worth +2% forever.

```
On Ready
  -> Prestige: Configure  1000000, 0.5, 0.02
  # requirement 1,000,000; exponent 0.5 (sqrt curve); +0.02 multiplier per point
```

### 2. Feed the pack whatever the player earns

Scenario: every gold gain should also count toward prestige.

```
On Gold Earned
  -> CurrencyLedger: Add  "gold", earned_amount
  -> Prestige: Track Earned  earned_amount
  # the wallet and the prestige tracker get the same number
```

Track Earned only tallies - it does not move any currency. You add to the wallet yourself.

### 3. A prestige button guarded by Can Prestige

Scenario: the button only works once a reset would bank at least one point.

```
On Prestige Button Pressed
  Condition: Prestige  Can Prestige
    -> Prestige: Do Prestige
    -> CurrencyLedger: Define Currency  "gold", 0, -1
    -> Generators: reset all to level 1
  # Do Prestige banks the points; you wipe the run yourself
```

### 4. A live "Prestige for N" button label

Scenario: the button should read how many points a reset would bank right now.

```
Every 0.25 seconds
  -> Prestige Button: set text to "Prestige for " + str(Prestige.Prestige Gain()) + " points"
  # Prestige Gain previews the bank without resetting anything
```

### 5. Apply the permanent multiplier to production

Scenario: every generator's output is scaled by the banked prestige boost.

```
Every 1 seconds
  -> Local: set output to base_production * Prestige.Prestige Multiplier()
  -> CurrencyLedger: Add  "gold", output
  -> Prestige: Track Earned  output
  # with 0 points the multiplier is exactly 1.0, so this is safe from frame one
```

### 6. A "you banked N points" popup on reset

Scenario: after a prestige, show how many points were just earned.

```
On Prestige
  -> Reset Sound: play
  -> Banner: show "Prestiged! +" + str(Prestige.Last Gain()) + " points"
  # Last Gain is only valid inside On Prestige (or right after Do Prestige)
```

### 7. A progress bar toward the next point

Scenario: a fill bar shows how close this run is to its next prestige point.

```
Every 0.1 seconds
  -> Next Point Bar: set value to Prestige.Progress To Next()
  # Progress To Next returns 0 to 1 across the current point's earning band
```

### 8. Show what the next point costs

Scenario: label the run earnings still needed to bank one more point.

```
Every 0.5 seconds
  -> Local: set remaining to Prestige.Earned For Next Point() - Prestige.Run Earned()
  -> Next Point Label: set text to "Next point at " + BigNumber.Format Short(Prestige.Earned For Next Point())
  # Format Short keeps millions and billions from overflowing the label
```

### 9. A permanent multiplier readout in the HUD

Scenario: a corner of the HUD always shows the current permanent boost and prestige count.

```
On Prestige
  -> Multiplier Label: set text = "x" + str(Prestige.Prestige Multiplier()) + "  (Lv " + str(Prestige.Prestige Level()) + ")"
  # refresh on every prestige instead of polling every tick
```

### 10. Save and load the prestige state

Scenario: on load, restore banked points so the permanent multiplier is correct immediately.

```
On Game Loaded
  -> Prestige: Set Points  saved_points
  # Set Points restores the banked currency; Prestige Multiplier updates from it

On Game Saving
  -> Save Data: write points = Prestige.Prestige Points()
  -> Save Data: write total = Prestige.Total Earned()
  # persist the banked points and the all-time tally
```

### 11. Offline catch-up that feeds prestige

Scenario: idle income earned while away should count toward the current run's gain.

```
On Ready
  -> Local: set offline_gold to CurrencyLedger.Offline Gain()
  -> Prestige: Track Earned  offline_gold
  # the wallet was credited by the Currency Ledger; mirror it into Track Earned
```

### 12. Auto-prestige when the gain crosses a threshold

Scenario: an automation upgrade prestiges by itself once a reset is worth at least 50 points.

```
Every 5 seconds
  Condition: auto_prestige_unlocked = true
  Condition: Prestige.Prestige Gain() >= 50
    -> Prestige: Do Prestige
    -> CurrencyLedger: Define Currency  "gold", 0, -1
    -> Generators: reset all to level 1
  # only fires when a reset banks 50+ points, so it isn't constantly resetting
```

### 13. A lifetime-earnings achievement

Scenario: award a badge when all-time earnings pass a billion, surviving every prestige.

```
On Prestige
  Condition: Prestige.Total Earned() >= 1000000000
  Condition: billion_badge_unlocked = false
    -> Local: set billion_badge_unlocked to true
    -> Achievements: unlock "Billionaire"
  # Total Earned never resets, so this keeps counting across resets
```

### 14. A second, slower meta-prestige layer

Scenario: after 25 prestiges the player unlocks a deeper reset that spends prestige levels.

```
On Prestige
  Condition: Prestige.Prestige Level() >= 25
  Condition: meta_layer_unlocked = false
    -> Local: set meta_layer_unlocked to true
    -> Meta Panel: reveal "Ascension"
  # Prestige Level is a plain number, so a second layer can gate on it
```

### 15. Rebalancing the curve from an upgrade

Scenario: an upgrade makes prestige cheaper by lowering the requirement mid-game.

```
On Cheaper Prestige Purchased
  -> Prestige: Configure  500000, 0.5, 0.02
  # halve the requirement; exponent and bonus stay the same
```

Configure re-tunes the curve live - the next Prestige Gain reflects the new requirement immediately.

### 16. A "new game" wipe from the options menu

Scenario: a full reset that clears prestige too, not just the run.

```
On Confirm New Game Pressed
  -> Prestige: Hard Reset
  -> CurrencyLedger: Define Currency  "gold", 0, -1
  -> Generators: reset all to level 1
  # Hard Reset wipes points, level, and both earnings tallies - unlike Do Prestige
```

### 17. A cheat menu that jumps to any prestige state

Scenario: a debug panel sets banked points directly for testing scaling.

```
On Cheat Set Points Pressed
  -> Prestige: Set Points  1000
  -> Debug Label: set text = "Multiplier now x" + str(Prestige.Prestige Multiplier())
  # 1000 points at 0.02 bonus reads x21.0
```

### Other use cases

**Roguelite soul banking.** Nothing says the earnings have to be idle gold: Track Earned the score a run accumulates, and on death Do Prestige converts it into permanent souls. The square-root curve naturally rewards deeper runs more than grinding shallow ones, and Prestige Multiplier is the hero's inherited power.

**Tycoon franchise sales.** Selling the restaurant chain to reopen with reputation stars is the same bank-and-reset: lifetime revenue feeds Track Earned, the "Sell for N stars" button reads Prestige Gain live, and every future venture earns faster by Prestige Multiplier.

**Seasonal ladder resets.** A live game's season end is one Do Prestige converting season earnings into legacy points, with Total Earned keeping the all-time career stats intact across every season. Prestige Level doubles as the "seasons played" badge.

**New Game Plus.** Finish the story, bank the playthrough's accumulated score, and start NG+ with a permanent multiplier on XP and drops. Because the pack never wipes your game itself, you choose exactly what carries over and what resets in the same event.

**Generational farm sims.** Passing the farm to an heir banks the parent's lifetime harvest into heirloom points, and each generation works the land a little faster. Progress To Next makes a gentle "legacy" bar that fills over a whole playthrough rather than a session.

---

## Tips and common mistakes

- **This pack never touches your wallet or generators.** Do Prestige banks points and clears the RUN total only. Resetting the actual currencies and building levels is your job, in the same event - usually `CurrencyLedger.Define Currency(...)` per currency and your own generator reset.
- **Track Earned only tallies - it moves no money.** Call it alongside your `CurrencyLedger.Add(...)`, passing the same amount. Forgetting to feed Track Earned means Prestige Gain stays at 0 no matter how rich the player gets.
- **Read Prestige Gain BEFORE Do Prestige, or Last Gain after.** Do Prestige clears the run and computes the bank from it, so once it returns, Prestige Gain is 0 again. Grab the number first for a "you will bank N" preview, or read Last Gain (valid inside On Prestige) for "you banked N".
- **Do Prestige does nothing when the gain is 0.** It silently returns below the requirement, so guard the button with Can Prestige (or check Prestige Gain) rather than assuming every press resets the run.
- **Prestige Multiplier is safe to multiply by from frame one.** With zero points it is exactly 1.0, so wiring `base * Prestige Multiplier()` into production before the first prestige changes nothing - no special-casing needed.
- **Hard Reset is not a prestige.** It wipes points, level, run earned, and total earned for a clean new game. Do not use it for the normal reset loop or the player loses their permanent progress - that is what Do Prestige is for.
- **Total Earned never resets; Run Earned does.** Use Run Earned (and Progress To Next) for the current-loop UI, and Total Earned for lifetime achievements and stat screens. Do Prestige zeroes Run Earned but leaves Total Earned climbing.
- **Last Gain is only meaningful right after a bank.** It holds the most recent Do Prestige result, so read it inside On Prestige (or immediately after Do Prestige). Reading it at other times gives you a stale number from the last reset.
- **The curve lives in Configure, not in Do Prestige.** Requirement, exponent, and bonus are set once (or re-set live from an upgrade). If your gains look wrong, check the Configure values, not the reset - a requirement of 0 is guarded to a gain of 0, not a divide-by-zero.
- **Format big numbers with the Big Numbers pack.** Requirement, Earned For Next Point, and Total Earned reach the millions and billions fast; wrap them in `BigNumber.Format Short(...)` so a HUD label reads "4.3M" instead of overflowing.
