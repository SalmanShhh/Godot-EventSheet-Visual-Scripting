# Boosts

Boosts is the golden-cookie layer of an idle game: temporary, timed multipliers that count themselves down. Start a named boost with a multiplier and a duration ("frenzy", x7, 77 seconds) and it ticks itself down every frame, then fires On Boost Expired the instant it runs out. Total Multiplier folds every active boost into one number you multiply straight into production, exactly the way you already fold in prestige and upgrade multipliers. It ships as an **autoload**: once the pack is installed it is the `Boost` singleton, live from the first frame with no node to place and no timer to wire. It does not touch your wallet, spawn the golden cookie, or draw a countdown bar - it holds the multipliers and the clocks, and hands you triggers and expressions so your production loop and HUD react. Money lives in the Currency Ledger pack; short number strings live in the Big Numbers pack.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Golden-cookie frenzies.** A random pickup starts a "frenzy" boost at x7 for a few seconds; Total Multiplier makes every building pay out seven times until it expires on its own.
- **Idle and incremental production.** Multiply your per-second yield by Total Multiplier in one place and every temporary buff, from ads to events, flows through automatically.
- **Click-power surges.** Start a tagged "click" boost so Multiplier For Tag narrows the bonus to manual clicks while leaving passive income untouched.
- **Rewarded-ad buffs.** Watching an ad calls Start Boost for a fixed window; the timer counts down whether the player keeps playing or not.
- **Stacking event multipliers.** A weekend event, a daily bonus, and a frenzy can all be active at once - each is its own id, and they multiply together in Total Multiplier.
- **Time-limited potions and elixirs.** Buy a "double xp" elixir that lasts ten minutes; Extend Boost lets a second potion top up the same timer.
- **Combo and streak meters.** Every fast action extends a "combo" boost a little; when the player stops, it runs out and On Boost Expired resets the streak.
- **HUD countdown chips.** Time Left drives a "Frenzy 12s" label and Active Count tells the HUD how many buff chips to show.
- **Prestige-friendly buff resets.** Clear Boosts wipes every temporary multiplier in one row when the player prestiges, without disturbing permanent bonuses.
- **Offline catch-up windows.** On return from a long absence, grant a short "welcome back" boost so the first minute back feels generous.
- **Automation and factory games.** A "overclock" boost speeds a line for a set duration and expires itself, so you never have to remember to turn it off.

---

## Core concepts

The mental model is one thing: a **boost** is a named, self-counting multiplier. Everything else is a field on that record.

| Field | What it means |
|---|---|
| **id** | The name you start it under (`"frenzy"`, `"double_xp"`). Starting the same id again replaces it. |
| **multiplier** | How much it scales production while active (7.0 = "x7"). Read one with `Multiplier Of("id")`. |
| **remaining** | Seconds left on the clock. Counts down every frame; read it with `Time Left("id")`. |
| **tag** | An optional group label from Start Tagged Boost (`"click"`, `"production"`) so Multiplier For Tag can fold just that group. |

A few rules tie those fields together, and they are the whole behaviour of the pack:

- **Boosts count themselves down.** Every frame the pack subtracts the elapsed time from every active boost. You never run a timer; you just start one and read Time Left if you want a label.
- **Total Multiplier is a product, not a sum.** Two active boosts at x2 and x3 give a Total Multiplier of 6.0, not 5.0. With no boosts active it is 1.0, so multiplying by it is always safe.
- **Expiring fires; stopping does not.** When a timer reaches zero the pack removes the boost and fires On Boost Expired (read Last Expired inside it). Stop Boost and Clear Boosts remove boosts silently - they are yours, not the clock's.
- **Starting an id replaces it.** Start Boost on an already-active id resets its multiplier and duration from scratch. To top up instead of replace, use Extend Boost.

This pack never touches money, xp, or any resource. It only tells you the current multiplier; you decide what to multiply. Fold Total Multiplier into your production the same way you fold in prestige and upgrade multipliers.

---

## Setup

Nothing to install per project beyond the pack. Once the Boosts pack is in `eventsheet_addons/`, it registers itself as the `Boost` autoload, so every sheet can call it by name with no node to drop and no reference to pass around.

A minimal first frenzy, as event-sheet rows:

```
On Golden Cookie Clicked
  -> Boost: Start Boost  "frenzy", 7.0, 77.0
  # x7 production for 77 seconds, counting itself down

Every 1 seconds  (your production tick)
  -> CurrencyLedger: Add  "cookies", base_rate * Boost.Total Multiplier()
  # Total Multiplier is 1.0 when no boost is active, so this is always safe

On Boost Expired
  -> Toast: show "Frenzy over"
```

That is the whole loop: start a boost with one row, multiply production by Total Multiplier, and let On Boost Expired tell you when it ends.

---

## ACE reference

Every id and tag below is a string. Multipliers and durations are numbers (seconds). All names are the exact display names from the pack.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Start Boost | id, multiplier, duration | Starts (or restarts) a timed multiplier by id for `duration` seconds and fires On Boost Started. |
| Start Tagged Boost | id, multiplier, duration, tag | Like Start Boost, but with a tag so Multiplier For Tag can group it (e.g. "production", "click"). |
| Extend Boost | id, seconds | Adds seconds to an active boost's timer (does nothing if it is not active). |
| Stop Boost | id | Ends a boost immediately (no On Boost Expired - that is for timers running out). |
| Clear Boosts | (none) | Ends every active boost at once. |

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Is Active | id | Whether a boost with this id is currently running. |
| Any Active | (none) | Whether any boost is currently running. |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Total Multiplier | Number | (none) | The product of every active boost's multiplier (1.0 if none) - fold it into production. |
| Multiplier For Tag | Number | tag | The product of active boosts that share this tag (1.0 if none). |
| Multiplier Of | Number | id | One boost's multiplier (1.0 if it is not active). |
| Time Left | Number | id | Seconds remaining on a boost (0 if not active) - for a countdown label. |
| Active Count | Number | (none) | How many boosts are currently running. |
| Last Expired | String | (none) | The id of the boost that just ran out (read inside On Boost Expired). |

### Triggers

| Trigger | When it fires |
|---|---|
| On Boost Started | Whenever Start Boost or Start Tagged Boost begins (or restarts) a boost. |
| On Boost Expired | When a boost's timer reaches zero and it is removed. Read Last Expired inside it. Stop Boost and Clear Boosts do NOT fire it. |

---

## Use cases

Each snippet uses real display names. `Boost.Name(...)` is how you read an expression inside a value field.

### 1. A golden-cookie frenzy

Scenario: clicking the golden cookie grants a big, short production multiplier.

```
On Golden Cookie Clicked
  -> Boost: Start Boost  "frenzy", 7.0, 77.0
  -> Frenzy Sound: play
  # x7 for 77 seconds, and it ends itself
```

### 2. Fold every boost into production

Scenario: your per-second income should scale with whatever buffs are live right now.

```
Every 1 seconds  (production tick)
  -> CurrencyLedger: Add  "cookies", base_rate * Boost.Total Multiplier()
  # no boost active -> Total Multiplier is 1.0, so income is just base_rate
```

### 3. Stack a frenzy on top of prestige and upgrades

Scenario: production already multiplies by prestige and upgrade bonuses; the boost multiplies on top.

```
Every 1 seconds
  -> Local: set yield to base_rate * prestige_mult * upgrade_mult * Boost.Total Multiplier()
  -> CurrencyLedger: Add  "cookies", yield
  # all four multipliers compose - the boost is just one more factor
```

### 4. A click-power surge that spares passive income

Scenario: a "sugar rush" should multiply manual clicks only, not idle production.

```
On Sugar Rush Picked Up
  -> Boost: Start Tagged Boost  "sugar_rush", 3.0, 20.0, "click"

On Big Cookie Clicked
  -> CurrencyLedger: Add  "cookies", click_value * Boost.Multiplier For Tag("click")
  # passive income keeps using Total Multiplier or nothing at all
```

### 5. A rewarded-ad double boost

Scenario: watching an ad gives double production for five minutes.

```
On Ad Watched
  -> Boost: Start Boost  "ad_boost", 2.0, 300.0
  -> Toast: show "Double production for 5 minutes!"
  # the timer counts down whether the player watches the game or not
```

### 6. A HUD countdown chip

Scenario: while a frenzy runs, show "Frenzy 12s" and hide the chip when it ends.

```
Every 0.25 seconds
  Condition: Boost  Is Active  "frenzy"
    -> Frenzy Chip: show
    -> Frenzy Chip: set text to "Frenzy " + str(ceil(Boost.Time Left("frenzy"))) + "s"
  Else
    -> Frenzy Chip: hide
```

### 7. Potions that top up the same timer

Scenario: a "double xp" elixir lasts ten minutes; drinking a second one extends it instead of resetting it.

```
On Elixir Used  (first time)
  Condition: Boost  Is Active  "double_xp"  [inverted]
    -> Boost: Start Boost  "double_xp", 2.0, 600.0

On Elixir Used  (already active)
  Condition: Boost  Is Active  "double_xp"
    -> Boost: Extend Boost  "double_xp", 600.0
    # Extend adds to the clock; Start would have thrown away the leftover time
```

### 8. A combo meter that decays

Scenario: fast actions keep a combo alive; when the player pauses, it expires and the streak resets.

```
On Fast Action
  Condition: Boost  Is Active  "combo"  [inverted]
    -> Boost: Start Boost  "combo", 1.0, 2.0
  Condition: Boost  Is Active  "combo"
    -> Boost: Extend Boost  "combo", 0.5

On Boost Expired
  Condition: Boost.Last Expired() == "combo"
    -> Streak Label: set text to "Combo lost"
    -> Streak: reset to 0
```

### 9. Show how many buffs are live

Scenario: a buff bar renders one icon per active boost.

```
On Buff Bar Refresh
  Condition: Boost  Any Active
    -> Buff Bar: show
    -> Buff Bar: set count to Boost.Active Count()
  Else
    -> Buff Bar: hide
```

### 10. A welcome-back boost on offline return

Scenario: after a long absence, the first minute back is extra generous.

```
On Ready
  Condition: seconds_since_last_played > 3600
    -> Boost: Start Boost  "welcome_back", 5.0, 60.0
    -> Welcome Popup: show "Welcome back! x5 for one minute"
  # Currency Ledger handles the actual offline gold; this just sweetens the return
```

### 11. A paid "overclock" that expires itself

Scenario: spend gold to overclock a line for 30 seconds; you never have to switch it back off.

```
On Overclock Button Pressed
  Condition: CurrencyLedger  Can Afford  "gold", 500
    -> CurrencyLedger: Spend  "gold", 500
    -> Boost: Start Boost  "overclock", 4.0, 30.0
  # this pack never touches the wallet - you Spend the cost yourself
```

### 12. Clear every boost on prestige

Scenario: prestiging should wipe all temporary multipliers but leave permanent bonuses alone.

```
On Prestige Confirmed
  -> Boost: Clear Boosts
  -> Prestige: apply permanent multiplier
  # Clear Boosts removes them silently - On Boost Expired does not fire
```

### 13. A boost-ready label from the shop

Scenario: a "Frenzy ready" button greys out while a frenzy is already running.

```
On Shop Refresh
  Condition: Boost  Is Active  "frenzy"
    -> Frenzy Button: disable
    -> Frenzy Button: set text to "Active (" + str(ceil(Boost.Time Left("frenzy"))) + "s)"
  Else
    -> Frenzy Button: enable
    -> Frenzy Button: set text to "Start Frenzy"
```

### 14. A big multiplier readout in the HUD

Scenario: show the live "x12.5" total production multiplier, formatted short when it climbs high.

```
Every 0.25 seconds
  -> Multiplier Label: set text to "x" + BigNumber.Format Short(Boost.Total Multiplier(), 1)
  # 1.0 when idle, 42.0 when several boosts stack - Big Numbers keeps it short
```

### 15. A save/load-friendly reseed

Scenario: on load you restore a boost that was still counting down when the player quit.

```
On Save
  -> SaveData: set frenzy_remaining to Boost.Time Left("frenzy")
  -> SaveData: set frenzy_mult to Boost.Multiplier Of("frenzy")

On Load
  Condition: SaveData.frenzy_remaining > 0
    -> Boost: Start Boost  "frenzy", SaveData.frenzy_mult, SaveData.frenzy_remaining
    # start it again with the leftover time and it keeps counting down
```

### 16. Automation that reacts when a buff ends

Scenario: an automated factory turns a haste effect back on the moment the last one expires.

```
On Boost Expired
  Condition: Boost.Last Expired() == "haste"
  Condition: CurrencyLedger  Can Afford  "energy", 20
    -> CurrencyLedger: Spend  "energy", 20
    -> Boost: Start Boost  "haste", 2.0, 15.0
    # a self-sustaining loop while the player has energy to spend
```

### 17. Chain-scaling event weekend

Scenario: a weekend event multiplier and a frenzy stack, and you want to know both at once.

```
On Event Weekend Start
  -> Boost: Start Boost  "weekend", 2.0, 172800.0
  # 2x for 48 hours; a frenzy on top gives Total Multiplier = weekend * frenzy

On Weekend Panel Refresh
  -> Weekend Label: set text to "Event x" + BigNumber.Format Short(Boost.Multiplier Of("weekend"), 0)
  -> Total Label: set text to "Total x" + BigNumber.Format Short(Boost.Total Multiplier(), 1)
```

### Other use cases

**Racing nitro pickups.** The pack never touches production specifically - it just reports a multiplier - so a nitro pad can Start Boost "nitro" and the car multiplies its top speed by Total Multiplier each frame. Driving over a second pad mid-burn is one Extend Boost, and the flame effect switches off inside On Boost Expired.

**Tower-defense war horns.** A support ability starts a tagged "attack_speed" boost for eight seconds and every tower divides its fire interval by Multiplier For Tag("attack_speed"). Stacking a commander aura on top multiplies in automatically, and the horde feels the difference without any per-tower timers.

**Survivor-run pickups.** Magnet, double-XP, and freeze pickups in a horde survivor are each a short boost under its own id, all live at once. The HUD reads Active Count for the icon row, and On Boost Expired is where each effect cleans itself up mid-swarm.

**Cafe-sim happy hours.** A restaurant or shop sim runs "happy_hour" as a tagged boost that multiplies tips while the rush lasts. Seasonal promotions and a celebrity-visit event stack multiplicatively with it, and the till just multiplies each sale by Multiplier For Tag("income").

**Lucky-charm drop windows.** A charm or shrine blessing starts a "luck" boost, and your loot logic multiplies its rare-drop chance by Multiplier Of("luck") for the duration. Because an inactive boost reads 1.0, the odds math needs no special case when the charm wears off.

---

## Tips and common mistakes

- **This pack never touches your wallet.** Start Boost only changes the multiplier; you still call `CurrencyLedger.Spend(...)` for a paid boost and multiply production by Total Multiplier yourself. It is a multiplier registry, not an economy.
- **Total Multiplier is a product.** Two x2 boosts give x4, not x4-added-somewhere - and no boosts active gives 1.0, so `base_rate * Total Multiplier()` is always safe to write. Never add Total Multiplier to your rate; multiply by it.
- **Starting an active id replaces it.** Start Boost throws away whatever time was left and begins fresh. To top up a still-running boost, use Extend Boost instead so the leftover seconds are kept.
- **Expiring fires a trigger; stopping does not.** On Boost Expired only fires when a timer runs out on its own. Stop Boost and Clear Boosts remove boosts silently, so do not rely on the trigger to clean up after a manual stop.
- **Last Expired is only valid inside On Boost Expired.** It holds the id of the boost that just ran out. Read it right there and branch on it (`Last Expired() == "combo"`); outside that trigger it is stale.
- **Tags only exist if you use Start Tagged Boost.** A boost started with plain Start Boost has an empty tag, so Multiplier For Tag will never include it. Match the tag string exactly - "click" and "clicks" are different groups.
- **Extend Boost does nothing on an inactive id.** If the boost already expired, Extend silently no-ops. Check Is Active first, or Start Boost it fresh, when you are not sure it is still running.
- **Time Left and Multiplier Of return safe defaults.** Time Left is 0 and Multiplier Of is 1.0 for an id that is not active, so a HUD label reading them never errors - it just shows the resting values. Use Is Active when you need to know the difference between "not active" and "active at x1".
- **Format big multipliers with Big Numbers.** When several boosts stack the total can climb fast; wrap it as `BigNumber.Format Short(Total Multiplier(), 1)` so a "x1240.0" never overflows the label. This pack returns raw floats.
- **Restore boosts on load by re-starting them with the leftover time.** There is no separate "resume" - save Time Left and Multiplier Of, then Start Boost with those two values and it counts down from where it left off.
