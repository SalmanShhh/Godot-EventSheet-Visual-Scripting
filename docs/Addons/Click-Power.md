# Click Power

Click Power is the manual-tap income at the heart of a clicker, driven from any event sheet. One row - Do Click - works out what a single tap earns (base value, plus a flat bonus, plus a fraction of your current production, all times a multiplier), rolls for a crit, records the result as Last Click, and fires On Click (and On Crit) so your effects and popups react. It ships as an **autoload**: once the pack is installed it is the `ClickPower` singleton, live from the first frame with no node to place and no wiring. It does not hold your money - the wallet lives in the separate Currency Ledger pack. Click Power computes what a tap is worth; you read Last Click and Add it to your currency yourself. Configure the base, multiplier, flat bonus, crit chance/size, and how much of your per-second production each click also grants (the "clicking is worth X% of production" rule popularised by Cookie Clicker).

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Clicker and incremental games.** The big cookie, the ore vein, the paperclip button - one Do Click row resolves the tap and hands you the payout to bank.
- **"Clicking is worth X% of production" loops.** Set CPS Fraction so a tap also grants a slice of your current per-second income, the Cookie-Clicker rule that keeps active play relevant deep into an idle run.
- **Crit-based tapping.** Set Crit gives a chance for a lucky x10 tap (Cookie Clicker's golden-cookie frenzy, AdVenture Capitalist's lucky payouts); On Crit fires only when it lands, so gold sparks and screen shakes wire themselves.
- **Prestige and upgrade multipliers.** Compose your prestige bonus, upgrade stack, and temporary boost into one number and feed it to Set Multiplier - the tap yield scales without touching the click code.
- **"Per click" HUD labels.** Click Yield previews exactly what a tap earns right now (no crit) so a "+12.5 / click" label stays truthful as upgrades land.
- **Flat upgrade buffs.** Set Flat Bonus adds a fixed amount to every tap before the multiplier, the classic "+5 per click" shop upgrade.
- **Idle games with an active-play layer.** Automation earns while you idle; Click Power is the manual layer on top, and both feed the same wallet.
- **Achievement and milestone tracking.** Total Clicks counts every resolved tap, so "click 1,000 times" achievements read straight off the pack.
- **Auto-clicker automation.** A timer that calls Do Click on an interval is a bought auto-clicker; the same yield math and crit rolls apply to automated taps.
- **Combo and frenzy windows.** Bump the multiplier for a few seconds during a frenzy, then restore it - every tap in the window pays more with no special-case click logic.
- **Mobile tap-to-earn prototypes.** The whole "tap the screen, watch the number go up" loop is Do Click plus a Currency Ledger Add, wired in two rows.

---

## Core concepts

The mental model is one formula and one recorded result. Every tap is worth:

```
yield = (base + flat_bonus + cps_fraction * current_cps) * multiplier
```

If a crit lands, that yield is multiplied again by the crit multiplier. The pack records the outcome as **Last Click** and never touches your wallet - crediting is your job.

| Field | What it means | Set with |
|---|---|---|
| **base** | The value of one plain click before anything else. | Configure |
| **multiplier** | Scales the whole yield. Feed it your composed prestige x upgrade x boost value. | Set Multiplier |
| **flat bonus** | A flat amount added to every click *before* the multiplier. | Set Flat Bonus |
| **cps fraction** | Each click also grants this fraction of the production-per-second you pass in (0 = off). | Set CPS Fraction |
| **crit chance** | Probability (0 to 1) that a tap crits. | Set Crit |
| **crit multiplier** | What a crit multiplies the yield by (e.g. 10 for a x10 click). | Set Crit |

A few rules tie it together, and they are the whole behaviour of the pack:

- **Do Click is the only thing that pays out.** It computes the yield, rolls the crit, stores Last Click and Was Crit, bumps Total Clicks, and fires On Click (then On Crit if it critted). Nothing is added to any currency - you read Last Click and credit it.
- **You pass current production per second in.** Do Click and Click Yield both take `current_cps`. Pass your Currency Ledger production rate if you use the CPS Fraction rule, or `0` if you don't. With CPS Fraction at 0 the value you pass is ignored.
- **Click Yield previews, Do Click commits.** Click Yield returns the deterministic no-crit value for a label and rolls nothing. Do Click is the one that rolls the crit and records the result.
- **The multiplier is a single composed number.** The pack does not stack multipliers for you. Multiply your prestige, upgrade, and boost factors together in your own logic and hand the product to Set Multiplier.
- **Context is last-write.** Last Click and Was Crit describe the most recent Do Click. Read them right after the call or inside On Click / On Crit, not much later.

---

## Setup

Nothing to install per project beyond the pack. Once the Click Power pack is in `eventsheet_addons/`, it registers itself as the `ClickPower` autoload, so every sheet can call it by name with no node to drop and no reference to pass around.

The minimal manual-tap loop, as event-sheet rows (the wallet is the separate Currency Ledger pack):

```
On Ready
  -> ClickPower: Configure  1
  # one plain tap is worth 1

On Big Button Pressed
  -> ClickPower: Do Click  0
  # 0 = no production to share; this resolves the tap and fires On Click

On Click
  -> CurrencyLedger: Add  "cookies", ClickPower.Last Click()
  # Click Power computed the payout; you bank it
```

That is the whole loop: configure once, Do Click on the tap, and credit Last Click to your wallet inside On Click.

---

## ACE reference

All names below are the exact display names from the pack. Numbers are floats unless noted.

### Actions

| Action | Parameters | What it does |
|---|---|---|
| Configure | base_click | Sets the base value of one click. |
| Set Multiplier | multiplier | Sets the click multiplier - feed it your composed prestige x upgrade x boost value. |
| Set Flat Bonus | bonus | Adds a flat amount to every click before the multiplier (from an upgrade). |
| Set CPS Fraction | fraction | Makes each click also worth this fraction of current production per second (the "clicking is worth X% of production" rule; 0 = off). |
| Set Crit | chance, multiplier | Sets the crit chance (0 to 1) and its multiplier (e.g. 10 for a lucky x10 click). |
| Do Click | current_cps | Resolves one tap: computes the yield (pass your current total production per second, or 0), rolls a crit, records Last Click / Was Crit, and fires On Click (and On Crit). Then Add Last Click to your wallet. |

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Was Crit | (none) | Whether the last click critted (read after Do Click / inside On Click). |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Click Yield | Number | current_cps | What one click earns right now, without a crit (pass current production per second, or 0) - for a "per click" label. |
| Last Click | Number | (none) | What the last Do Click earned (after any crit) - Add this to your wallet. |
| Total Clicks | Number (int) | (none) | How many clicks have been resolved. |
| Click Multiplier | Number | (none) | The current click multiplier. |
| Crit Chance | Number | (none) | The current crit chance, 0 to 1. |

### Triggers

| Trigger | When it fires |
|---|---|
| On Click | Every time Do Click resolves a tap. Read Last Click / Was Crit inside it and credit the payout. |
| On Crit | Only when the resolved tap critted. Fires after On Click; use it for crit-only sparks, shakes, and sounds. |

---

## Use cases

Each snippet uses real display names. `ClickPower.Name(...)` is how you read an expression inside a value field. The wallet is the Currency Ledger pack; short number strings come from the Big Numbers pack.

### 1. The basic cookie tap

Scenario: tapping the big button earns one cookie and banks it.

```
On Ready
  -> ClickPower: Configure  1

On Big Button Pressed
  -> ClickPower: Do Click  0

On Click
  -> CurrencyLedger: Add  "cookies", ClickPower.Last Click()
  # Click Power computed the payout - you credit it
```

### 2. A "per click" HUD label that stays truthful

Scenario: a label reads "+X / click" and updates whenever upgrades change the yield.

```
On Ready
  -> Per Click Label: set text to "+" + BigNumber.Format Short(ClickPower.Click Yield(0)) + " / click"

On Upgrade Purchased
  -> Per Click Label: set text to "+" + BigNumber.Format Short(ClickPower.Click Yield(0)) + " / click"
  # Click Yield previews the no-crit value without rolling anything
```

### 3. Flat "+N per click" upgrade

Scenario: a shop upgrade adds a flat amount to every tap before the multiplier.

```
On Sturdy Fingers Purchased
  -> ClickPower: Set Flat Bonus  5
  # every click now starts at base + 5, then the multiplier applies
```

### 4. Composing prestige, upgrades, and a boost into one multiplier

Scenario: your click power is prestige x upgrade stack x temporary boost.

```
On Click Power Changed
  -> Local: set total to prestige_mult * upgrade_mult * boost_mult
  -> ClickPower: Set Multiplier  total
  # the pack does not stack for you - hand it the composed product
```

### 5. Clicking is worth a fraction of your production

Scenario: deep into the run, a tap should also grant 5% of your current per-second income.

```
On Ready
  -> ClickPower: Set CPS Fraction  0.05

On Big Button Pressed
  -> ClickPower: Do Click  CurrencyLedger.Balance("cps")
  # pass your live production rate; a tap now grants base + 5% of it
```

### 6. Lucky crits with a golden spark

Scenario: 1-in-20 taps crit for x10, and only crits play the spark.

```
On Ready
  -> ClickPower: Set Crit  0.05, 10

On Big Button Pressed
  -> ClickPower: Do Click  0

On Crit
  -> Golden Spark: play at cursor
  -> Crit Sound: play
  # On Crit fires only when the tap critted, after On Click
```

### 7. A "CRITICAL!" popup versus a normal "+N"

Scenario: the floating text over the cookie differs on a crit.

```
On Click
  Condition: ClickPower  Was Crit
    -> Floating Text: create "CRITICAL +" + BigNumber.Format Short(ClickPower.Last Click()) + "!"
  Else
    -> Floating Text: create "+" + BigNumber.Format Short(ClickPower.Last Click())
  -> CurrencyLedger: Add  "cookies", ClickPower.Last Click()
```

### 8. An auto-clicker you can buy

Scenario: an upgrade buys automation that taps once a second on its own.

```
On Auto Clicker Purchased
  -> Auto Timer: start (1 second, looping)

On Auto Timer Timeout
  -> ClickPower: Do Click  CurrencyLedger.Balance("cps")
  # automated taps run the same yield math and crit rolls
```

### 9. A timed frenzy that boosts every tap

Scenario: a power-up makes clicks worth x7 for five seconds, then restores normal.

```
On Frenzy Started
  -> ClickPower: Set Multiplier  7
  -> Frenzy Timer: start (5 seconds)

On Frenzy Timer Timeout
  -> ClickPower: Set Multiplier  1
  # every Do Click during the window paid at x7 with no special click logic
```

### 10. A click-count achievement

Scenario: unlock a badge after the player has tapped 1,000 times.

```
On Click
  Condition: ClickPower.Total Clicks() >= 1000
    -> Achievements: unlock "Thousand Taps"
  -> CurrencyLedger: Add  "cookies", ClickPower.Last Click()
```

### 11. Prestige that rescales click power and resets the wallet

Scenario: prestiging bumps a permanent multiplier and re-seeds the run.

```
On Prestige Confirmed
  -> CurrencyLedger: Add  "prestige_points", 1
  -> Local: set total to 1.0 + 0.1 * CurrencyLedger.Balance("prestige_points")
  -> ClickPower: Set Multiplier  total
  -> CurrencyLedger: Define Currency  "cookies", 0, -1
  # click power grows 10% per prestige point; the cookie wallet resets
```

### 12. Save and load click tuning

Scenario: persist the tuning so a reloaded game clicks exactly as before.

```
On Save Requested
  -> Save: set "click_mult" to ClickPower.Click Multiplier()
  -> Save: set "crit_chance" to ClickPower.Crit Chance()
  -> Save: set "total_clicks" to ClickPower.Total Clicks()

On Load Complete
  -> ClickPower: Set Multiplier  Save.get("click_mult")
  -> ClickPower: Set Crit  Save.get("crit_chance"), 10
  # Total Clicks is display-only; restore the tuning that drives yield
```

### 13. Offline catch-up for idle taps

Scenario: while away, an auto-clicker "kept tapping" - credit an estimate on return.

```
On Load Complete
  -> Local: set taps to seconds_away * auto_clicks_per_second
  -> Local: set gain to taps * ClickPower.Click Yield(CurrencyLedger.Balance("cps"))
  -> CurrencyLedger: Add  "cookies", gain
  -> Welcome Popup: show "Your auto-clicker earned " + BigNumber.Format Short(gain) + " while away"
  # Click Yield gives the per-tap value; multiply by the missed taps
```

### 14. A shop that spends the tap's own payout

Scenario: a "reinvest" button spends the last tap straight into an upgrade.

```
On Big Button Pressed
  -> ClickPower: Do Click  0

On Click
  -> CurrencyLedger: Add  "cookies", ClickPower.Last Click()

On Reinvest Pressed
  Condition: CurrencyLedger  Can Afford  "cookies", 50
    -> CurrencyLedger: Spend  "cookies", 50
    -> ClickPower: Set Flat Bonus  10
  # Click Power never touches the wallet - Currency Ledger does the spending
```

### 15. Screen shake scaled to the crit payout

Scenario: bigger crits shake harder.

```
On Crit
  -> Camera: shake with strength ClickPower.Last Click() * 0.001
  # Last Click already includes the crit multiplier
```

### 16. A crit-chance upgrade line

Scenario: successive upgrades raise the crit chance toward a soft ceiling.

```
On Lucky Charm Purchased
  -> Local: set chance to min(ClickPower.Crit Chance() + 0.02, 0.5)
  -> ClickPower: Set Crit  chance, 10
  # read the current chance, nudge it up, cap it, write it back
```

### 17. A combo meter that rewards fast tapping

Scenario: rapid taps build a combo that temporarily raises the multiplier.

```
On Big Button Pressed
  -> Local: set combo to combo + 1
  -> ClickPower: Set Multiplier  1.0 + combo * 0.05
  -> ClickPower: Do Click  0
  -> Combo Reset Timer: restart (2 seconds)

On Combo Reset Timer Timeout
  -> Local: set combo to 0
  -> ClickPower: Set Multiplier  1
```

### Other use cases

**Tap-damage boss battles.** Nothing says the payout has to be money: treat Last Click as damage and subtract it from a boss health pool on every On Click. Crits become massive hits with their own On Crit slam effect, and the composed multiplier is your hero's total DPS stat.

**Resource-node harvesting.** Each pickaxe swing on an ore vein is a Do Click, with the flat bonus as your tool tier and a crit as striking a rich seam. The same node logic covers trees, rocks, and herbs - only the Configure numbers change.

**Button-mash minigames.** A tug-of-war or reel-in-the-fish mash fills a meter by Last Click per press, so upgrades the player bought elsewhere genuinely make mashing stronger. Total Clicks doubles as a "presses this attempt" stat for the results screen.

**Pet and egg progress tapping.** Tapping an egg adds Last Click to a hatch meter, and a crit gives the shell a lucky big crack. The CPS Fraction rule even lets an incubator's passive warmth make each tap worth more as the nursery upgrades.

**Restaurant serving rushes.** In an idle-hybrid diner, every customer served by hand is a Do Click and the payout is the tip, with crits as generous big spenders. Set Multiplier composes the menu quality and decor bonuses, so active play scales with the same economy as the idle layer.

---

## Tips and common mistakes

- **This pack never touches your wallet.** Do Click computes the payout and records Last Click, but nothing is credited until you Add it yourself. Wire `CurrencyLedger.Add(..., ClickPower.Last Click())` inside On Click; if the number never goes up, you probably forgot the Add.
- **Read Last Click, don't recompute the tap.** Last Click already includes the crit. Do not call Click Yield inside On Click and bank that instead - Click Yield never crits, so you would silently pay out the non-crit amount and lose every crit.
- **Click Yield previews; Do Click commits.** Click Yield rolls no crit and changes nothing - it is for labels. Only Do Click resolves a tap. Calling Click Yield does not count as a click or fire On Click.
- **Context is only valid right after the tap.** Last Click and Was Crit describe the most recent Do Click, so read them inside On Click / On Crit or immediately after the call. Reading them a frame later reflects whatever tapped last, not the tap you meant.
- **On Crit fires after On Click, not instead of it.** A critical tap fires both. Put the payout in On Click and crit-only flourishes (sparks, shakes, sounds) in On Crit; do not credit the wallet in both or you double-pay.
- **The multiplier is one composed number.** The pack does not stack prestige, upgrades, and boosts for you - multiply them together in your own logic and pass the product to Set Multiplier. Calling Set Multiplier again overwrites the previous value; it does not accumulate.
- **CPS Fraction needs a real production value.** If you set a non-zero CPS Fraction, pass your live production-per-second to Do Click (and Click Yield). Passing 0 there quietly drops the production share of the tap. With the fraction at 0, the value you pass is ignored, so 0 is fine.
- **Crit chance is clamped to 0 to 1.** Set Crit clamps the chance into that range, so passing 1.5 does not give 150% - it lands at 1.0 (always crit). The crit multiplier is not clamped; keep it sane.
- **Total Clicks is display and achievement only.** It counts resolved taps and does not feed the yield. Restoring it on load is cosmetic - the values that actually drive a tap are the base, multiplier, flat bonus, CPS fraction, and crit settings.
- **Number formatting lives in the Big Numbers pack.** Click Power returns raw floats. Wrap them for HUD text with `BigNumber.Format Short(ClickPower.Last Click())` so a late-game payout does not overflow the label.
