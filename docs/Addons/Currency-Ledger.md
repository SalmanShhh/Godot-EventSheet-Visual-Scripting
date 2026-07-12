# Currency Ledger

Currency Ledger is a data-driven economy you drive from any event sheet. Register named currencies by string id (gold, gems, energy, xp, hunger, reputation, or anything you can name), then earn and spend them with single rows. It ships as an **autoload**: once the pack is installed it is the `CurrencyLedger` singleton, live from the first frame with no node to place and no wiring. It holds the numbers, enforces caps and floors, and fires a trigger on every meaningful change so your HUD, unlocks, and sound effects react instead of polling a variable every tick. It does not draw coins or bars - that stays your job, driven by the triggers below.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Idle and incremental games.** Give a currency an offline rate, call Apply Offline Gain on startup, and show a "welcome back" recap - all in one short event chain.
- **Economies that grow during development.** Currencies are created by name, so adding a fifth resource never touches the events that already earn and spend the first four.
- **Soft and hard currencies side by side.** Register gold and gems with different caps and rules; check Can Afford before any purchase.
- **RPG resource pools.** MP, SP, Rage, Heat, Sanity, Focus - each is a currency with its own cap and floor, and they all share the same earn / spend / threshold triggers.
- **Energy and stamina systems.** A currency with a max and an offline rate is the whole mobile-stamina loop: cap it, drain it on play, regenerate it over time.
- **Tutorial and quest gates.** A "tutorial_progress" currency is just a named counter - increment it on each step and unlock content when it crosses a threshold.
- **Hunger, heat, and overdraft meters.** Call Allow Debt to let a currency fall below zero to a floor you pick, then react with On Amount Changed or Is In Debt.
- **Daily login rewards and earn caps.** Set Daily Cap limits how much can be earned per day; Reset Daily Caps rolls the day over on your schedule.
- **Shops and vending.** Spend is atomic - the full price leaves or nothing does - and On Spend Failed hands you the shortfall for a clean "not enough gold" message.
- **Big-number displays.** Format Amount turns 12500 into "12.5K" and 4300000 into "4.3M" so a HUD label never overflows.
- **Board-game and strategy resource tracks.** Influence, Supply, Settlers, Honour - hard caps and spend guards with no per-resource event logic.
- **Prestige and reset loops.** Define Currency re-creates a currency from scratch, so a prestige button wipes and re-seeds the whole economy in a row per currency.

---

## Core concepts

The mental model is one thing: a **currency** is a named record. Everything else is a field on that record.

| Field | What it means |
|---|---|
| **amount** | The current balance. Read it with `Balance("id")`. |
| **min** (debt floor) | The lowest the amount may reach. Default `0` - the currency can't go negative until you call Allow Debt. |
| **max** (hard cap) | The highest the amount may reach. `-1` means no cap. Set at Define Currency time or later with Set Max. |
| **daily cap** | The most that can be *earned* (added) before the day rolls over. `-1` means no daily cap. |
| **daily earned** | How much has been added toward the daily cap today. Reset Daily Caps zeroes it. |
| **offline rate** | Passive income per real second, used by Apply Offline Gain. `0` means off. |

A few rules tie those fields together, and they are the whole behaviour of the pack:

- **Add is signed and clamps to [min, max].** A positive amount earns, a negative amount subtracts, and the result is pinned inside the floor and cap. Positive adds also respect the daily cap; negative adds only respect the floor.
- **Spend is atomic.** Spend subtracts only if the full amount can be afforded. If not, nothing changes and On Spend Failed fires. There is no partial spend.
- **Currencies are created lazily.** The first Add, Spend, or Set on an unknown id quietly creates it with defaults (min 0, no cap, no daily cap). You only need Define Currency when you want a starting amount or a cap up front.
- **Caps and days are yours to drive.** The pack clamps to caps automatically, but it never watches the clock. You decide when a "day" ends by calling Reset Daily Caps, and you decide how much time passed offline by passing seconds to Apply Offline Gain.

This is one clean money model. There is no separate "debt currency" and no non-negative special case: a currency either has a floor of 0 (the default) or a negative floor you opt into with Allow Debt.

---

## Setup

Nothing to install per project beyond the pack. Once the Currency Ledger pack is in `eventsheet_addons/`, it registers itself as the `CurrencyLedger` autoload, so every sheet can call it by name with no node to drop and no reference to pass around.

A minimal first economy, as event-sheet rows:

```
On Ready
  -> CurrencyLedger: Define Currency  "gold", 100, 500
  # gold starts at 100 with a hard cap of 500 (pass -1 for no cap)

On Coin Picked Up
  -> CurrencyLedger: Add  "gold", 10

On Amount Changed
  -> HUD Label: set text to "Gold: " + CurrencyLedger.Format Amount(CurrencyLedger.Balance("gold"), 0)
  # this row runs on every change, so the HUD updates itself
```

That is the whole loop: define once, earn and spend with single rows, and let On Amount Changed refresh the display.

---

## ACE reference

Every id below is a string. Amounts are numbers. All names are the exact display names from the pack.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Define Currency | id, starting_amount, max_amount | Creates (or resets) a currency with a starting amount and a max (-1 = no cap). Min is 0 and there's no daily cap until you set one. |
| Set Max | id, max_amount | Changes the hard cap (-1 = no cap). If the current amount is above the new cap it clamps down. |
| Set Daily Cap | id, daily_cap | Caps how much can be earned (added) per day (-1 = no daily cap). You decide when a day rolls over by calling Reset Daily Caps. |
| Allow Debt | id, minimum | Lets a currency go negative down to this floor (e.g. -50). Use it for hunger, heat, or overdraft. Default floor is 0 (no debt). |
| Set Offline Rate | id, rate_per_second | Passive income per real second, used by Apply Offline Gain (0 = off). |
| Add | id, amount | Adds a signed amount (negative subtracts) and clamps to the currency's min and max. Positive amounts also respect the daily cap. Fires On Amount Changed, plus On Cap Hit / On Daily Cap Hit if a limit is hit. |
| Spend | id, amount | Subtracts the amount only if it can be afforded; otherwise nothing changes and On Spend Failed fires (read Failed Id / Requested Amount / Available Amount there). |
| Set Amount | id, amount | Forces the amount to a value, clamped to the currency's min and max. Fires On Amount Changed. |
| Reset Daily Caps | (none) | Zeroes the earned-today counter for every currency (call this at your day rollover). |
| Apply Offline Gain | id, elapsed_seconds | Credits offline_rate * seconds to the currency (respecting caps) and fires On Offline Gain. One call - no separate Add needed. |

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Has Currency | id | Whether a currency with this id has been defined or touched. |
| Can Afford | id, amount | Whether the current balance is at least the amount. |
| Is At Cap | id | Whether the balance is at its max (false when there's no cap). |
| Is Daily Cap Reached | id | Whether today's earnings have hit the daily cap (false when there's none). |
| Is In Debt | id | Whether the balance is below zero (only possible after Allow Debt). |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Balance | Number | id | The current amount of a currency (0 if undefined). |
| Cap | Number | id | The hard cap of a currency (-1 if none). |
| Daily Cap | Number | id | The daily earn cap (-1 if none). |
| Daily Earned | Number | id | How much has been earned today. |
| Debt Floor | Number | id | The minimum a currency may reach (0 unless Allow Debt was used). |
| Currency Count | Number | (none) | How many currencies are defined. |
| Currency Id At | String | index | The currency id at a position (for menus); "" out of range. |
| Format Amount | String | value, decimals | A short display string with a K/M/B/T suffix (e.g. 12500 -> "12.5K"). Takes a raw value, not an id. |
| Changed Id | String | (none) | The currency that changed (inside On Amount Changed). |
| New Amount | Number | (none) | The amount after the change (inside On Amount Changed). |
| Previous Amount | Number | (none) | The amount before the change (inside On Amount Changed). |
| Amount Delta | Number | (none) | The signed change (inside On Amount Changed). |
| Failed Id | String | (none) | The currency of the failed spend (inside On Spend Failed). |
| Requested Amount | Number | (none) | The amount that was asked for (inside On Spend Failed). |
| Available Amount | Number | (none) | What was actually available (inside On Spend Failed). |
| Offline Id | String | (none) | The currency credited (inside On Offline Gain). |
| Offline Gain | Number | (none) | The amount credited offline (inside On Offline Gain). |

### Triggers

| Trigger | When it fires |
|---|---|
| On Amount Changed | Whenever a currency's amount changes (Add, Spend, Set Amount, or Apply Offline Gain). Read Changed Id / New Amount / Previous Amount / Amount Delta inside it. |
| On Spend Failed | When a Spend can't be afforded; nothing is deducted. Read Failed Id / Requested Amount / Available Amount inside it. |
| On Cap Hit | When an Add is clamped by the currency's hard cap. |
| On Daily Cap Hit | When an Add is clamped by the daily earn cap. |
| On Offline Gain | After Apply Offline Gain credits passive income. Read Offline Id / Offline Gain inside it. |

---

## Use cases

Each snippet uses real display names. `CurrencyLedger.Name(...)` is how you read an expression inside a value field.

### 1. Seed a starter economy on load

Scenario: a new game begins with some gold, a gem pouch, and unlimited xp.

```
On Ready
  -> CurrencyLedger: Define Currency  "gold", 100, 500
  -> CurrencyLedger: Define Currency  "gems", 0, 50
  -> CurrencyLedger: Define Currency  "xp", 0, -1
  # gold caps at 500, gems at 50, xp is uncapped (-1)
```

### 2. A HUD gold counter that updates itself

Scenario: a label should always show the current gold, without checking every frame.

```
On Amount Changed
  Condition: CurrencyLedger  Has Currency  "gold"
    -> Gold Label: set text to CurrencyLedger.Format Amount(CurrencyLedger.Balance("gold"), 0)
  # runs only when something changed, so no per-tick polling
```

### 3. A shop button guarded by Can Afford

Scenario: buy a sword for 50 gold, but only if the player can pay.

```
On Buy Button Pressed
  Condition: CurrencyLedger  Can Afford  "gold", 50
    -> CurrencyLedger: Spend  "gold", 50
    -> Inventory: give "sword"
    -> Shop: close
```

With the Can Afford guard in front, the Spend can never fail.

### 4. Spend without guarding, then handle the failure

Scenario: let the player tap buy freely and show an error when they are short.

```
On Buy Button Pressed
  -> CurrencyLedger: Spend  "gold", 100

On Spend Failed
  -> Error Sound: play
  -> Toast: show "Need " + CurrencyLedger.Format Amount(CurrencyLedger.Requested Amount(), 0) + " gold, you have " + CurrencyLedger.Format Amount(CurrencyLedger.Available Amount(), 0)
  # On Spend Failed changed nothing - the gold is untouched
```

### 5. Coin pickups add gold

Scenario: touching a coin awards 10 gold.

```
On Area Entered  (coin)
  -> CurrencyLedger: Add  "gold", 10
  -> Coin: queue free
```

### 6. A scarce gem pouch that caps out

Scenario: gems max at 50 and you want feedback when the pouch is full.

```
On Reward Claimed
  -> CurrencyLedger: Add  "gems", 20

On Cap Hit
  -> Toast: show "Gem pouch is full!"
  # Add already clamped the amount to the cap before this fired
```

### 7. Daily login reward with an earn cap

Scenario: the player can earn up to 100 daily coins, resetting each day.

```
On Ready
  -> CurrencyLedger: Define Currency  "daily_coins", 0, -1
  -> CurrencyLedger: Set Daily Cap  "daily_coins", 100

On Claim Pressed
  -> CurrencyLedger: Add  "daily_coins", 25

On Daily Cap Hit
  -> Claim Label: set text to "Daily limit reached - come back tomorrow"

On New Day  (your own midnight or session logic)
  -> CurrencyLedger: Reset Daily Caps
```

### 8. Energy that drains on play and refills

Scenario: sprinting costs energy; a rest spot refills it; the bar should stop at full.

```
On Sprint
  -> CurrencyLedger: Add  "energy", -5
  # negative Add subtracts and stops at the floor (0)

On Rest Tick
  Condition: CurrencyLedger  Is At Cap  "energy"
    -> [do nothing - already full]
  Else
    -> CurrencyLedger: Add  "energy", 2
```

### 9. Offline income and a welcome-back popup

Scenario: gold trickles in while the game is closed; show what was earned on return.

```
On Ready
  -> CurrencyLedger: Set Offline Rate  "gold", 0.5
  -> CurrencyLedger: Apply Offline Gain  "gold", seconds_since_last_played
  # one call credits the gain and fires On Offline Gain

On Offline Gain
  -> Welcome Popup: show "While away you earned " + CurrencyLedger.Format Amount(CurrencyLedger.Offline Gain(), 1) + " gold"
  # the gold is ALREADY credited - do not Add again
```

### 10. A hunger meter that can go negative

Scenario: hunger ticks down over time and starvation kicks in below zero.

```
On Ready
  -> CurrencyLedger: Define Currency  "hunger", 100, 100
  -> CurrencyLedger: Allow Debt  "hunger", -20
  # hunger may now fall to -20 instead of stopping at 0

Every 1 seconds
  -> CurrencyLedger: Add  "hunger", -3

On Amount Changed
  Condition: CurrencyLedger  Is In Debt  "hunger"
    -> Player: start starvation damage
```

### 11. Big idle numbers with a K/M/B/T suffix

Scenario: an idle clicker where gold reaches the millions and the label must stay short.

```
On Amount Changed
  Condition: CurrencyLedger  Has Currency  "gold"
    -> Gold Label: set text to CurrencyLedger.Format Amount(CurrencyLedger.New Amount(), 2) + " gold"
  # 1002.47 shows "1.00K", 4300000 shows "4.30M"
```

### 12. A multi-currency summary screen

Scenario: an end-of-level panel lists every currency and its amount, without hardcoding ids.

```
On Summary Opened
  Repeat CurrencyLedger.Currency Count() times
    -> Local: set id to CurrencyLedger.Currency Id At(loop_index)
    -> Summary Panel: add line id + ": " + CurrencyLedger.Format Amount(CurrencyLedger.Balance(id), 1)
```

### 13. Floating "+N" popups on every gain

Scenario: show a rising "+1.3K" above the player whenever gold increases.

```
On Amount Changed
  Condition: CurrencyLedger.Amount Delta() > 0
    -> Floating Text: create at player, text "+" + CurrencyLedger.Format Amount(CurrencyLedger.Amount Delta(), 1)
    -> Floating Text: play "rise and fade"
```

### 14. XP that levels the player up at a threshold

Scenario: defeating an enemy grants xp; crossing 100 xp levels up.

```
On Enemy Defeated
  -> CurrencyLedger: Add  "xp", 50

On Amount Changed
  Condition: CurrencyLedger  Has Currency  "xp"
  Condition: CurrencyLedger.Balance("xp") >= 100
    -> Player: level up
    -> CurrencyLedger: Add  "xp", -100
    # carry the remainder into the next level
```

### 15. An upgrade that raises the gold cap

Scenario: buying a bigger wallet lifts the gold cap from 500 to 750.

```
On Wallet Upgrade Purchased
  -> CurrencyLedger: Set Max  "gold", 750
  # existing gold is kept; only the ceiling moved
```

### 16. A prestige button that wipes and re-seeds

Scenario: prestige resets soft currencies but keeps a permanent "prestige_points" tally.

```
On Prestige Confirmed
  -> CurrencyLedger: Add  "prestige_points", 1
  -> CurrencyLedger: Define Currency  "gold", 0, 500
  -> CurrencyLedger: Define Currency  "gems", 0, 50
  # Define Currency re-creates each currency from scratch, clearing the old amount
```

### Other use cases

**Faction reputation.** Each faction's standing is a currency with Allow Debt, so favors Add and betrayals subtract, Is In Debt marks a hostile faction, and threshold checks unlock vendors or ambushes.

**Ammo pools.** Each ammo type is a currency spent one shot at a time; the atomic Spend means the trigger click on an empty magazine is just On Spend Failed driving a dry-fire sound and a reload prompt.

**Arcade ticket exchange.** Minigames Add tickets and the prize counter Spends them, with Format Amount keeping the ticket display readable once the totals balloon.

**Crafting stockpiles.** Wood, stone, and iron are three currencies, a recipe is a row of Can Afford checks followed by Spends, and On Spend Failed names exactly which material ran short.

**Wanted-level heat.** Crimes Add to a capped "heat" currency, a lay-low timer subtracts over time, and On Cap Hit is the moment maximum wanted level triggers the heavy response.

---

## Tips and common mistakes

- **Add is signed - there is no separate subtract.** Pass a negative amount to spend freely (`Add "hunger", -3`), or use Spend when you want the all-or-nothing behaviour with an On Spend Failed safety net. This one model replaces the old split between a non-negative balance and a separate debt value.
- **Spend is atomic.** If the balance is short, nothing leaves the wallet and On Spend Failed fires - it never partially deducts. Either guard it with Can Afford or handle On Spend Failed; don't do both and expect the failure branch to run.
- **Format Amount takes a value, not a currency id.** Wrap a balance inside it: `Format Amount(Balance("gold"), 1)`, or `Format Amount(New Amount(), 1)` inside On Amount Changed. Passing an id string will not compile the way you expect.
- **Apply Offline Gain credits in a single call.** It adds the gain and fires On Offline Gain for you. Do not follow it with your own Add - that double-pays the player. The two-step "calculate then add" dance is gone on purpose.
- **Daily caps never reset themselves.** The pack clamps earning to the daily cap, but it does not watch the clock. Call Reset Daily Caps when your own day-rollover logic fires. Reset Daily Caps clears the counter for every currency at once.
- **Only positive Adds count against the daily cap.** Spending, negative Adds, and Set Amount do not touch the earned-today counter - daily caps gate earning, not spending.
- **Context expressions are only valid inside their trigger.** Changed Id / New Amount / Amount Delta read the last change, so use them inside On Amount Changed. The same goes for Failed Id / Requested Amount / Available Amount inside On Spend Failed, and Offline Id / Offline Gain inside On Offline Gain.
- **A currency can't go below zero until you Allow Debt.** The default floor is 0, so Is In Debt stays false and a draining meter parks at 0. Call Allow Debt with a negative minimum first if you want hunger, heat, or overdraft.
- **You don't always need Define Currency.** The first Add, Spend, or Set on an unknown id creates it with defaults (min 0, no cap). Define Currency is for when you want a starting amount or a hard cap set up front - and it also doubles as a reset, since it re-creates the record.
- **Set Amount and Set Max clamp silently.** Setting an amount above the cap, or lowering the cap below the current amount, quietly clamps to the limit and fires On Amount Changed rather than erroring - so watch your HUD, not the console, to confirm the value landed where you expect.
