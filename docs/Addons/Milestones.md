# Milestones

Milestones is a threshold-achievement engine for incremental games, driven from any event sheet. Define a milestone by string id with a threshold to cross and a reward it grants, then report the tracked number to Update Progress wherever it changes; the first time the value reaches the threshold the milestone latches reached and fires a trigger once. The point is that a milestone is not just a badge that lights up - Total Reward sums the reward of every reached milestone into one number you fold into your production multiplier, so hitting "a million cookies" makes the player permanently stronger. It ships as an **autoload**: once the pack is installed it is the `Milestones` singleton, live from the first frame with no node to place and no wiring. It does not hold your currency, draw progress bars, or multiply anything for you - it tracks thresholds and hands you the reward total; spending, formatting, and multiplying stay your job.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Idle and clicker milestone rewards.** "Reach 1M cookies for +5% forever" is one Define Milestone plus one Update Progress on the counter, and Total Reward turns the latched bonuses into a live multiplier.
- **Prestige tiers that stack.** Register a milestone per lifetime-earnings tier; each one you cross adds its reward to Total Reward, so late-game production visibly compounds.
- **Automation unlocks.** Latch a milestone when a building count crosses a threshold, then flip on an auto-buyer inside On Milestone Reached - the achievement literally turns on the automation.
- **Boss and stage gates.** A "stage_10" milestone reached once stays reached; Is Reached gates content that should never re-lock even if the tracked number later drops.
- **Collection and completion tracking.** Reached Count over Milestone Count is a ready-made "37 of 50 achievements" progress readout with no bookkeeping of your own.
- **"Next goal" HUD hints.** Nearest Unreached names the milestone closest to firing, and Progress gives you the 0-to-1 fill for the bar pointing at it.
- **Offline catch-up.** After crediting offline production, call Update Progress once with the new total and every threshold the player blew past while away latches in order, firing its trigger.
- **Save and load.** Persist which ids were reached, then Force Reach each on load to restore the reward total without re-firing celebrations you already showed.
- **Multi-metric achievements.** Milestones are keyed by id, so "total_gold", "clicks", and "playtime_seconds" are three independent tracks sharing one earn / latch / reward loop.
- **Soft skill trees.** Treat each reward as a percentage and let the player unlock nodes in any order; Total Reward is the summed bonus regardless of path.
- **Score-attack and arcade tiers.** Bronze / silver / gold thresholds on a run score are three milestones; the highest reached drives the medal you show.

---

## Core concepts

The mental model is one thing: a **milestone** is a named record with a threshold, a reward, and a latch. Everything else reads or flips those fields.

| Field | What it means |
|---|---|
| **threshold** | The value the tracked number must reach to latch. Read it with `Threshold("id")`. |
| **reward** | The bonus this milestone grants once reached. Read one with `Reward("id")`; sum all reached with `Total Reward()`. |
| **reached** | The latch. `false` until the value first crosses the threshold, then `true` forever (until Reset or a fresh Define Milestone). |
| **value** | The last value you reported with Update Progress. Feeds Progress and Nearest Unreached. |

A few rules tie those fields together, and they are the whole behaviour of the pack:

- **The latch is one-way and one-shot.** Update Progress latches only on the first crossing (`value >= threshold` while not yet reached). It fires On Milestone Reached exactly once; reporting a higher value later does nothing, and a value dropping back below the threshold does not un-latch it.
- **The pack watches nothing.** It never polls your currency or the clock. You call Update Progress with the current number whenever it changes; that call is the only thing that can latch a milestone.
- **Reward is a plain number you own.** The pack sums the rewards of reached milestones into Total Reward, but it does not multiply your production - you read Total Reward and fold it into your own multiplier.
- **Milestones are created lazily.** The first Update Progress, Set Threshold, or Force Reach on an unknown id quietly creates it with a threshold and reward of 0. Define Milestone is how you set a real threshold and reward up front, and it doubles as a reset since it re-creates the record.

This is one clean achievement model. There is no separate "reward bank" and no special-case for one-off badges: a milestone either has a reward of 0 (a pure gate) or a positive reward that flows into Total Reward the moment it latches.

---

## Setup

Nothing to install per project beyond the pack. Once the Milestones pack is in `eventsheet_addons/`, it registers itself as the `Milestones` autoload, so every sheet can call it by name with no node to drop and no reference to pass around.

A minimal first milestone, as event-sheet rows:

```
On Ready
  -> Milestones: Define Milestone  "gold_1k", 1000, 0.05
  # reach 1000 gold to grant a +0.05 (5%) permanent reward

On Amount Changed  (your gold changed)
  -> Milestones: Update Progress  "gold_1k", CurrencyLedger.Balance("gold")
  # report the current gold every time it changes

On Milestone Reached
  -> Toast: show "Milestone reached: " + Milestones.Last Reached()
  -> Production: set multiplier to 1.0 + Milestones.Total Reward()
  # Total Reward is the summed bonus of every reached milestone
```

That is the whole loop: define once, report the number on every change, and let On Milestone Reached recompute your multiplier from Total Reward.

---

## ACE reference

Every id below is a string. Thresholds, values, and rewards are numbers. All names are the exact display names from the pack.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Define Milestone | id, threshold, reward | Creates (or resets) a milestone: the threshold to cross and the reward it grants once reached. |
| Set Threshold | id, threshold | Changes a milestone's threshold (does not un-reach it if already reached). |
| Update Progress | id, value | Reports the current value of the tracked number. The first time it reaches the threshold the milestone latches and On Milestone Reached fires (read Last Reached / Reward there). |
| Force Reach | id | Marks a milestone reached immediately (for a load) - fires On Milestone Reached if it was not already reached. |
| Reset | (none) | Un-reaches every milestone and zeroes progress (keeps the definitions). |

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Is Reached | id | Whether a milestone has been reached. |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Progress | Number | id | How close a milestone is, 0 to 1 (for a progress bar). |
| Threshold | Number | id | A milestone's threshold value. |
| Reward | Number | id | A milestone's reward value. |
| Reached Count | Number | (none) | How many milestones have been reached. |
| Milestone Count | Number | (none) | How many milestones are defined. |
| Total Reward | Number | (none) | The sum of the rewards of every reached milestone - fold this into your production multiplier. |
| Last Reached | String | (none) | The id of the milestone that just latched (read inside On Milestone Reached). |
| Nearest Unreached | String | (none) | The id of the unreached milestone closest to its threshold (for a "next goal" display); "" if all reached. |

### Triggers

| Trigger | When it fires |
|---|---|
| On Milestone Reached | The first time a milestone's reported value reaches its threshold (via Update Progress), or when Force Reach latches a not-yet-reached milestone. Read Last Reached / Reward inside it. |

---

## Use cases

Each snippet uses real display names. `Milestones.Name(...)` is how you read an expression inside a value field. Where a use case spends money it calls the separate Currency Ledger pack (`CurrencyLedger.Spend(...)`), and where it formats a big number it calls the Big Numbers pack (`BigNumber.Format Short(...)`).

### 1. Define a milestone ladder on load

Scenario: a cookie game with three lifetime-bake milestones, each a bigger permanent bonus.

```
On Ready
  -> Milestones: Define Milestone  "bake_1k", 1000, 0.05
  -> Milestones: Define Milestone  "bake_1m", 1000000, 0.10
  -> Milestones: Define Milestone  "bake_1b", 1000000000, 0.25
  # thresholds climb, rewards climb - the payoff of a long session
```

### 2. Feed the tracked number on every change

Scenario: report total gold to a milestone whenever the wallet changes, so crossings latch on their own.

```
On Amount Changed  (CurrencyLedger fired)
  -> Milestones: Update Progress  "gold_1k", CurrencyLedger.Balance("gold")
  # the crossing is detected inside Update Progress - no manual compare needed
```

### 3. Turn Total Reward into a live production multiplier

Scenario: every reached milestone should permanently speed up production.

```
On Milestone Reached
  -> Production: set rate to base_rate * (1.0 + Milestones.Total Reward())
  # Total Reward is the summed bonus of all reached milestones, recomputed on each latch
```

### 4. A "milestone unlocked" celebration

Scenario: pop a toast and a sound the moment any milestone latches, naming the reward.

```
On Milestone Reached
  -> Celebrate Sound: play
  -> Toast: show "Reached " + Milestones.Last Reached() + "  (+" + str(Milestones.Reward(Milestones.Last Reached()) * 100.0) + "%)"
  # Last Reached and Reward are only meaningful inside this trigger
```

### 5. An automation that switches on at a threshold

Scenario: reaching 25 farms unlocks the auto-farmer.

```
On Ready
  -> Milestones: Define Milestone  "auto_farms", 25, 0

On Farm Bought
  -> Milestones: Update Progress  "auto_farms", farm_count

On Milestone Reached
  Condition: Milestones.Last Reached() = "auto_farms"
    -> Auto Farmer: enable
  # reward is 0 - this milestone is a pure automation gate, not a multiplier
```

### 6. A "next goal" HUD label

Scenario: always show the closest upcoming milestone and how far along the player is.

```
Every 0.25 seconds
  -> Local: set next to Milestones.Nearest Unreached()
  Condition: next != ""
    -> Goal Label: set text to "Next: " + next
    -> Goal Bar: set value to Milestones.Progress(next)
  Else
    -> Goal Label: set text to "All milestones complete!"
```

### 7. A completion counter for an achievements screen

Scenario: show "12 / 40 milestones" on a stats panel.

```
On Stats Opened
  -> Count Label: set text to str(Milestones.Reached Count()) + " / " + str(Milestones.Milestone Count()) + " milestones"
```

### 8. Offline catch-up latches everything you passed

Scenario: while the game was closed, gold grew past several thresholds; one report should latch them all.

```
On Ready
  -> CurrencyLedger: Apply Offline Gain  "gold", seconds_since_last_played
  -> Milestones: Update Progress  "gold_1k", CurrencyLedger.Balance("gold")
  -> Milestones: Update Progress  "gold_1m", CurrencyLedger.Balance("gold")
  # each Update Progress that clears its threshold latches and fires On Milestone Reached in turn
```

### 9. Save and load without re-firing celebrations

Scenario: on load, restore which milestones were reached so Total Reward is correct, but skip the toasts.

```
On Ready
  Repeat saved_reached_ids.size() times
    -> Milestones: Force Reach  saved_reached_ids[loop_index]
  -> Suppress Toasts: set to false
  # gate your celebration UI on a "loading" flag; Force Reach still fires the trigger,
  # so keep toasts muted until this loop finishes
```

### 10. A prestige button that re-arms the run

Scenario: prestige should clear this run's milestone latches so they can be earned again, while a separate prestige tally keeps climbing.

```
On Prestige Confirmed
  -> Local: set prestige_total to prestige_total + 1
  -> Milestones: Reset
  -> Milestones: Update Progress  "prestige_count", prestige_total
  # Reset un-reaches EVERY milestone and zeroes progress, keeping the definitions.
  # Keep the running tally in your own variable (prestige_total) - a milestone
  # can't survive Reset, so re-report prestige_count AFTER Reset to re-latch its tier.
```

### 11. A shop upgrade priced by a milestone, spent yourself

Scenario: buying the "golden touch" upgrade costs 500 gold and raises a milestone's threshold for the next tier.

```
On Upgrade Button Pressed
  Condition: CurrencyLedger  Can Afford  "gold", 500
    -> CurrencyLedger: Spend  "gold", 500
    -> Milestones: Set Threshold  "click_power", Milestones.Threshold("click_power") * 2.0
  # this pack never touches the wallet - you Spend through Currency Ledger yourself
```

### 12. A big-number milestone banner

Scenario: announce a huge lifetime-earnings milestone with a short, readable number.

```
On Milestone Reached
  Condition: Milestones.Last Reached() = "earn_1t"
    -> Banner: show "You have earned " + BigNumber.Format Short(Milestones.Threshold("earn_1t")) + " total!"
  # Format Short turns 1000000000000 into "1T" for the banner
```

### 13. Bronze / silver / gold medals on a run score

Scenario: a score-attack mode awards a medal based on the highest score tier reached this run.

```
On Ready
  -> Milestones: Define Milestone  "medal_bronze", 5000, 0
  -> Milestones: Define Milestone  "medal_silver", 15000, 0
  -> Milestones: Define Milestone  "medal_gold", 50000, 0

On Run Ended
  -> Milestones: Update Progress  "medal_bronze", run_score
  -> Milestones: Update Progress  "medal_silver", run_score
  -> Milestones: Update Progress  "medal_gold", run_score
  Condition: Milestones  Is Reached  "medal_gold"
    -> Medal Icon: set to "gold"
  Else
    Condition: Milestones  Is Reached  "medal_silver"
      -> Medal Icon: set to "silver"
```

### 14. A permanent content gate that never re-locks

Scenario: unlock the second world at 100 total kills and keep it unlocked even if a stat later resets.

```
On Enemy Killed
  -> Milestones: Update Progress  "world_2", total_kills

On World Select Opened
  Condition: Milestones  Is Reached  "world_2"
    -> World 2 Button: enable
  # the latch is one-way, so world 2 stays open regardless of later changes
```

### 15. Show the exact reward each milestone grants

Scenario: an achievements list should display each milestone's percentage bonus next to its state.

```
On Achievements Opened
  -> Row Gold: set text to "1K gold  (+" + str(Milestones.Reward("gold_1k") * 100.0) + "%)"
  Condition: Milestones  Is Reached  "gold_1k"
    -> Row Gold: set colour to green
  Else
    -> Row Gold: set colour to grey
```

### 16. Retune difficulty by moving a threshold live

Scenario: an unreached milestone is too easy after a balance patch, so raise its bar without disturbing reached ones.

```
On Balance Patch Applied
  Condition: Milestones  Is Reached  "clicks_500"  (inverted)
    -> Milestones: Set Threshold  "clicks_500", 800
  # Set Threshold leaves already-reached milestones latched; it only affects future crossings
```

---

## Tips and common mistakes

- **The pack never touches your wallet.** Milestones tracks thresholds and totals rewards; it does not earn or spend anything. When a use case charges for an upgrade you call `CurrencyLedger.Spend(...)` yourself, and when you need a short display number you call `BigNumber.Format Short(...)` - those live in the Currency Ledger and Big Numbers packs.
- **The latch is one-shot.** On Milestone Reached fires exactly once per milestone, on the first crossing. Reporting a higher value later does nothing, so don't hang per-frame reward logic off the trigger - recompute your multiplier from Total Reward when it fires and cache it.
- **A milestone never un-latches on its own.** Once reached, a value dropping back below the threshold leaves it reached. Only Reset (all milestones) or a fresh Define Milestone (one milestone) clears the latch.
- **You must call Update Progress; nothing latches without it.** The pack does not watch your currency or a timer. Report the number on every change (hook Update Progress to your On Amount Changed), or milestones will sit unreached no matter how high the real value climbs.
- **Total Reward is a number, not a multiplier.** The pack sums the rewards of reached milestones; folding that into production is on you. If your rewards are percentages, use `1.0 + Total Reward()`; if they are flat bonuses, add them. The pack stays agnostic on purpose.
- **Context expressions are only valid inside their trigger.** Last Reached names the milestone that just latched, so read it (and Reward of that id) inside On Milestone Reached. Elsewhere it holds whatever latched last, which is rarely what you want.
- **Force Reach still fires On Milestone Reached.** It is meant for loading a save, but it emits the trigger just like a real crossing. Gate your celebration UI behind a "loading" flag while you Force Reach restored ids, or the player sees a burst of toasts on every launch.
- **Reset keeps definitions, Define Milestone rebuilds one.** Reset un-reaches everything and zeroes progress but leaves thresholds and rewards intact - ideal for prestige. Define Milestone re-creates a single record from scratch, which also clears its latch.
- **Progress needs a positive threshold.** Progress returns the reported value over the threshold, clamped to 0-1; a milestone whose threshold is 0 reads as fully complete (1.0). Set a real threshold before wiring a bar to Progress.
- **Nearest Unreached returns "" when everything is done.** Guard the empty string before using it as an id (see use case 6) or your "next goal" label will read a milestone that does not exist.
