# Big Numbers

Big Numbers is the number-formatting layer an idle or incremental game lives on, callable from any event sheet. It turns raw values into the compact, readable strings the genre depends on - `1250000` becomes `"1.25M"`, `3725` seconds becomes `"1h 2m 5s"`, `0.25` becomes `"25%"` - and it carries the whole short-scale ladder past a trillion (K M B T Qa Qi Sx Sp Oc No Dc) before falling through to scientific notation. It also ships a **Decimal** type: an `[mantissa, exponent]` pair that lets a value keep growing past a float's `~1.8e308` ceiling, the way an Antimatter-Dimensions-scale prestige game needs. It installs as an **autoload**: once the pack is in place it is the `BigNumber` singleton, live from the first frame with no node to place and no wiring. It does **not** store your numbers, draw your HUD, or touch a wallet - it is a bank of pure calculators. There are no actions and no triggers here; every verb is an expression (or one of two comparison conditions) that takes a value and hands back a formatted string, a number, or a Decimal.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Idle clickers whose numbers balloon.** A gold counter that climbs from tens to septillions stays one short label - `Format Short` picks the suffix so `4300000` reads `"4.3M"` and `1.2e30` reads `"1.20No"`.
- **Prestige and ascension scale.** When soft-cap multipliers push a value past `1.8e308`, switch that value to a Decimal (`Make`, `Multiply`, `Power`) and it never overflows to Infinity again.
- **Cost curves in a buy loop.** A building whose price is `base * 1.15^owned` reaches the millions fast; format the next price with `Format Short` so the button label never runs off screen.
- **Offline catch-up recaps.** Turn "you were away 8420 seconds" into `"2h 20m 20s"` with `Format Time` for a clean welcome-back popup.
- **Automation and production ticks.** A factory that earns `production_per_second` can accumulate into a Decimal each tick with `Scale` and `Add`, staying exact far past the float range.
- **Multiplier stacking displays.** Show the combined boost from prestige, upgrades, and boosters as `"x12.5"` with `Format Multiplier`.
- **Progress and completion bars.** `Format Percent` turns a `0..1` fraction into `"73%"` for a research bar or a milestone tracker.
- **Milestone and rank labels.** `Format Ordinal` gives `"1st"`, `"2nd"`, `"13th"` for your Nth prestige, ascension tier, or leaderboard slot.
- **Exact bookkeeping panels.** `Format Comma` writes `1234567` as `"1,234,567"` when a stats screen wants the precise figure, not a rounded suffix.
- **Science-flavoured games.** `Format Engineering` keeps the exponent a multiple of three (`"12.50e3"`), the notation a Universal-Paperclips-style game wants.
- **Tier icons and thresholds.** `Order Of Magnitude` and `Suffix For` let you pick an icon or colour band by the power of ten a value has reached.

---

## Core concepts

Big Numbers has two layers, and picking the right one is the whole mental model.

**Layer 1 - format a plain float.** Godot floats are exact enough to roughly `1e300`, which covers most idle games start to finish. Feed a raw number to a `Format ...` expression and get a display string back. Nothing is stored; you call the formatter fresh each time you draw a label.

**Layer 2 - the Decimal type.** Past a float's `~1.8e308` ceiling a plain number becomes `Infinity` and your save is ruined. A **Decimal** dodges that: it is an `Array` of `[mantissa, exponent]` meaning `mantissa * 10^exponent`, kept normalized so `1 <= abs(mantissa) < 10`. You build one with `Make` or `From Number`, do maths on it with `Add` / `Subtract` / `Multiply` / `Divide` / `Power` / `Scale`, compare it with `Compare` / `Is Bigger` / `Is At Least`, and render it with `Format Big`. Because it is an `Array` (not a `Vector2`) the mantissa keeps full 64-bit precision.

| Piece | What it is |
|---|---|
| **plain value** | An ordinary Godot number. Format it with `Format Short`, `Format Scientific`, `Format Comma`, and so on. Good to about `1e300`. |
| **Decimal** | `[mantissa, exponent]`, e.g. `Make(1.5, 100)` is `1.5e100`. Grows without limit. Store it in your own sheet variable. |
| **suffix ladder** | `"" K M B T Qa Qi Sx Sp Oc No Dc`, one tier per three orders of magnitude. Past Dc (`1e33`) the short formatters fall through to scientific. |

A few rules tie it together:

- **This pack stores nothing.** There is no "balance" here. You keep your own values (in a sheet variable, or in the Currency Ledger pack for plain money) and call a formatter when you draw.
- **Decimals live in your variables.** `Make` and the maths verbs return an `Array`; assign it to a variable and pass that variable back in next time. `To Number` converts one back to a plain float (which may be `Infinity` if it is above `1.8e308`).
- **Decimals stay normalized.** Every Decimal verb re-normalizes its result, so you never have to tidy the mantissa yourself.
- **Add drops the negligible term.** When two Decimals differ by more than ~15 orders of magnitude the smaller one is below float precision and is dropped - by design, and invisible at idle scale.
- **The wallet is a different pack.** Currency Ledger holds and spends plain-number money; Big Numbers only formats. Where a use case spends, it calls `CurrencyLedger.Spend(...)`; where it displays, it wraps the value in `BigNumber.Format Short(...)`.

---

## Setup

Nothing to install per project beyond the pack. Once the Big Numbers pack is in `eventsheet_addons/`, it registers itself as the `BigNumber` autoload, so every sheet can call it by name with no node to drop and no reference to pass around.

A minimal first display, as event-sheet rows:

```
On Ready
  -> Score Label: set text to BigNumber.Format Short(1250000.0, 2)
  # shows "1.25M"

Every 0.1 seconds
  -> Score Label: set text to BigNumber.Format Short(score, 2)
  # score is your own variable; the label restyles itself as it grows
```

That is the pattern for the whole pack: keep the number yourself, and call a `Format ...` expression each time you paint it.

---

## ACE reference

Every formatter takes a value (and usually a `decimals` count) and returns a string; the Decimal verbs take and return `Array` Decimals. All names are the exact display names from the pack.

### Actions

This pack ships **no actions**. Big Numbers never mutates state - it only computes. Store the values it returns in your own sheet variables (or in the Currency Ledger pack for plain money).

### Conditions

| Condition | Parameters | What it checks |
|---|---|---|
| Is Bigger | a, b | Whether Decimal `a` is strictly bigger than Decimal `b`. |
| Is At Least | a, b | Whether Decimal `a` is at least as big as Decimal `b`. |

### Expressions

| Expression | Returns | Parameters | What it gives you |
|---|---|---|---|
| Format Short | String | value, decimals | A compact short-scale string: `1250 -> "1.25K"`, `1250000 -> "1.25M"`, on through Qa/Qi/.../Dc, then scientific past `1e36`. |
| Format Scientific | String | value, decimals | Scientific notation: `1250000 -> "1.25e6"`. `decimals` sets the mantissa places. |
| Format Engineering | String | value, decimals | Engineering notation - the exponent is always a multiple of 3: `1250000 -> "1.25e6"`, `12500 -> "12.50e3"`. |
| Format Time | String | seconds | Seconds as a friendly duration: `3725 -> "1h 2m 5s"`. Drops leading zero units (`90 -> "1m 30s"`). |
| Format Time Short | String | seconds | Seconds as a clock: `3725 -> "1:02:05"`, `90 -> "1:30"`. |
| Format Ordinal | String | number | An ordinal string: `1 -> "1st"`, `2 -> "2nd"`, `13 -> "13th"`, `21 -> "21st"`. |
| Format Comma | String | value | Thousands separators on the whole-number part: `1234567 -> "1,234,567"`. |
| Format Percent | String | value, decimals | A fraction as a percent: `0.25 -> "25%"`. |
| Format Multiplier | String | value, decimals | A multiplier label: `1.5 -> "x1.5"`, `2.0 -> "x2.0"`. |
| Suffix For | String | magnitude | The short-scale suffix for an order of magnitude: `6 -> "M"`, `9 -> "B"`. `""` past Dc. |
| Order Of Magnitude | Number | value | The power of ten of a value (floor log10): `1250 -> 3`, `1000000 -> 6`. |
| Make | Array | mantissa, exponent | Builds a Decimal: `Make(1.5, 100)` is `1.5e100`. Normalized automatically. |
| From Number | Array | value | Turns a plain number into a Decimal so it can grow past the float ceiling. |
| To Number | Number | decimal | Turns a Decimal back into a plain number (may be `Infinity` if above `1.8e308`). |
| Add | Array | a, b | Adds two Decimals. When one is ~15+ orders of magnitude larger, the smaller is dropped. |
| Subtract | Array | a, b | Subtracts Decimal `b` from Decimal `a`. |
| Multiply | Array | a, b | Multiplies two Decimals (mantissas multiply, exponents add). |
| Divide | Array | a, b | Divides Decimal `a` by Decimal `b` (returns `0` if `b` is `0`). |
| Power | Array | decimal, power | Raises a Decimal to a power: `Power(d, 2)` squares it. |
| Scale | Array | decimal, factor | Multiplies a Decimal by a plain number - the easy way to apply a multiplier. |
| Compare | Number | a, b | Compares two Decimals: `-1` if `a < b`, `0` if equal, `1` if `a > b`. |
| Format Big | String | decimal, decimals | Formats a Decimal with a short-scale suffix, falling through to scientific past Dc: `Make(1.5, 100) -> "1.50e100"`. |

### Triggers

This pack ships **no triggers**. Formatting is pure and instant, so there is nothing to fire on. Drive your displays off your own game's triggers (`On Ready`, `Every 0.1 seconds`, a button press) or off the Currency Ledger pack's `On Amount Changed`, and call a Big Numbers expression inside the row.

---

## Use cases

Each snippet uses real display names. `BigNumber.Name(...)` is how you read an expression inside a value field.

### 1. A HUD score label that stays short

Scenario: a clicker score climbs into the millions and beyond; the label must never overflow.

```
Every 0.1 seconds
  -> Score Label: set text to BigNumber.Format Short(score, 2)
  # 1002 -> "1.00K", 4300000 -> "4.30M", 1.2e30 -> "1.20No"
```

### 2. A geometric cost curve on a buy button

Scenario: each building costs `base * 1.15^owned`; the button shows the next price.

```
On Owned Changed  (your own event)
  -> Local: set next_cost to 50.0 * pow(1.15, buildings_owned)
  -> Buy Button: set text to "Buy - " + BigNumber.Format Short(next_cost, 2)
  # 50, then 57.50, ... climbing to "1.42K" and up
```

### 3. Buy loop that spends from the wallet

Scenario: the player buys a generator; the money lives in Currency Ledger, the price label in Big Numbers.

```
On Buy Button Pressed
  -> Local: set price to 50.0 * pow(1.15, generators_owned)
  Condition: CurrencyLedger  Can Afford  "gold", price
    -> CurrencyLedger: Spend  "gold", price
    -> Local: set generators_owned to generators_owned + 1
    -> Buy Button: set text to "Buy - " + BigNumber.Format Short(50.0 * pow(1.15, generators_owned), 2)
  # Big Numbers only formats; the wallet is Currency Ledger's job
```

### 4. Offline catch-up recap with a readable duration

Scenario: on return from being away, show how long the player was gone and what they earned.

```
On Ready
  -> Welcome Popup: set text to "Away for " + BigNumber.Format Time(seconds_since_last_played) + "\nEarned " + BigNumber.Format Short(offline_gold, 1) + " gold"
  # 8420 seconds reads "2h 20m 20s"
```

### 5. A countdown timer as a clock

Scenario: a booster is active for a while; the badge shows a mm:ss clock.

```
Every 0.1 seconds
  Condition: booster_remaining > 0
    -> Booster Badge: set text to BigNumber.Format Time Short(booster_remaining)
    # 90 -> "1:30", 3725 -> "1:02:05"
```

### 6. Late-game numbers that need a Decimal

Scenario: an endgame multiplier pushes production past `1.8e308`; a plain float would become Infinity.

```
On Ready
  -> Local: set antimatter to BigNumber.Make(1.0, 0)
  # antimatter starts at 1 as a Decimal

Every 1 seconds
  -> Local: set antimatter to BigNumber.Add(antimatter, BigNumber.Make(1.0, 6))
  # adds 1e6 per second; grows forever without overflowing
  -> Antimatter Label: set text to BigNumber.Format Big(antimatter, 2)
  # renders "1.00M", later "3.42e400"
```

### 7. Automation tick that scales a Decimal

Scenario: factories produce `rate` per second, boosted by a multiplier, accumulated as a Decimal.

```
Every 1 seconds
  -> Local: set tick to BigNumber.Scale(production_per_second, boost_multiplier)
  -> Local: set stockpile to BigNumber.Add(stockpile, tick)
  -> Stockpile Label: set text to BigNumber.Format Big(stockpile, 2)
  # Scale applies a plain-number multiplier to a Decimal in one step
```

### 8. Combining multipliers into one boost label

Scenario: prestige, an upgrade, and a temporary booster stack; show the combined multiplier.

```
On Boost Changed  (your own event)
  -> Local: set total_mult to prestige_mult * upgrade_mult * booster_mult
  -> Boost Label: set text to BigNumber.Format Multiplier(total_mult, 1)
  # 2.0 * 1.5 * 4.0 -> "x12.0"
```

### 9. A research progress bar with a percent label

Scenario: a research finishes over time; the label shows completion as a percent.

```
Every 0.1 seconds
  -> Local: set fraction to research_elapsed / research_total
  -> Research Bar: set value to fraction
  -> Research Label: set text to BigNumber.Format Percent(fraction, 0)
  # 0.73 -> "73%"
```

### 10. An ordinal label for the Nth prestige

Scenario: each prestige increments a counter; the banner reads "Your 3rd ascension".

```
On Prestige Confirmed
  -> Local: set ascensions to ascensions + 1
  -> Ascension Banner: set text to "Your " + BigNumber.Format Ordinal(ascensions) + " ascension"
  # 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 13 -> "13th"
```

### 11. A precise stats panel with comma grouping

Scenario: a lifetime-total screen wants the exact figure, not a rounded suffix.

```
On Stats Opened
  -> Total Clicks Line: set text to "Total clicks: " + BigNumber.Format Comma(lifetime_clicks)
  # 1234567 -> "1,234,567"
```

### 12. Gate a prestige unlock by comparing Decimals

Scenario: prestige unlocks once antimatter reaches `1e40`, well past the float-comfortable range.

```
Every 1 seconds
  Condition: BigNumber  Is At Least  antimatter, BigNumber.Make(1.0, 40)
    -> Prestige Button: enable
    -> Prestige Hint: set text to "Ready to ascend"
  # Is At Least never overflows - it compares exponent then mantissa
```

### 13. Save and load a Decimal value

Scenario: the endgame stockpile is a Decimal; persist and restore it across sessions.

```
On Save Requested
  -> SaveData: set "stockpile_mantissa" to stockpile[0]
  -> SaveData: set "stockpile_exponent" to stockpile[1]
  # a Decimal is an [mantissa, exponent] Array - store both parts

On Load Requested
  -> Local: set stockpile to BigNumber.Make(SaveData.get("stockpile_mantissa"), SaveData.get("stockpile_exponent"))
  # Make re-normalizes on the way back in
```

### 14. Compound growth with Power

Scenario: a value grows `1.1x` per tick for many ticks at once (an offline catch-up on a Decimal).

```
On Offline Catch Up  (your own event)
  -> Local: set growth to BigNumber.Power(BigNumber.Make(1.1, 0), ticks_elapsed)
  -> Local: set stockpile to BigNumber.Multiply(stockpile, growth)
  -> Stockpile Label: set text to BigNumber.Format Big(stockpile, 2)
  # Power raises a Decimal to a plain-number exponent in one step
```

### 15. Pick a tier icon by order of magnitude

Scenario: colour or swap the score icon by how many digits the value has reached.

```
On Score Changed  (your own event)
  -> Local: set oom to BigNumber.Order Of Magnitude(score)
  -> Tier Badge: set text to BigNumber.Suffix For(oom)
  # 1250000 -> oom 6 -> "M"; drives which badge art to show
  Condition: oom >= 9
    -> Tier Badge: set colour to gold
```

### 16. Engineering notation for a science game

Scenario: a Universal-Paperclips-style readout wants exponents locked to multiples of three.

```
Every 0.1 seconds
  -> Output Readout: set text to BigNumber.Format Engineering(watts, 2) + " W"
  # 12500 -> "12.50e3", 1250000 -> "1.25e6"
```

### 17. Show a Decimal cost back as a plain number when it is small

Scenario: an early Decimal-typed cost is still tiny; convert it to a plain float to spend from the wallet.

```
On Buy Pressed
  -> Local: set plain_cost to BigNumber.To Number(next_cost_decimal)
  Condition: CurrencyLedger  Can Afford  "gold", plain_cost
    -> CurrencyLedger: Spend  "gold", plain_cost
  # To Number is safe while the Decimal is below 1.8e308; guard huge costs by staying in Decimal
```

---

## Tips and common mistakes

- **This pack never stores anything.** There is no balance and no "current value" inside Big Numbers. Keep your own number in a sheet variable (or use the Currency Ledger pack for plain money) and call a `Format ...` expression when you draw. Big Numbers is all read-only calculators.
- **It never touches the wallet.** Spending money is Currency Ledger's job: `CurrencyLedger.Spend("gold", price)`. Big Numbers only turns the price into a label with `BigNumber.Format Short(price, 2)`. Mixing the two is the intended split.
- **There are no actions and no triggers.** Every verb is an expression you read inside a value field, plus the two Decimal comparison conditions. Drive your displays off your own game's triggers or off `CurrencyLedger.On Amount Changed`.
- **Plain floats are good to about `1e300` - Decimals are for past `1.8e308`.** Below the ceiling, format the raw number with `Format Short` and skip the Decimal ceremony. Only switch a value to a Decimal once it can realistically overflow, or a plain float will silently become `Infinity` and corrupt your save.
- **A Decimal is an `[mantissa, exponent]` Array - carry both parts.** To persist one, save `decimal[0]` and `decimal[1]` and rebuild it with `Make(...)` on load. Storing only one half loses the value.
- **Do maths on Decimals with the Decimal verbs, not `+` and `*`.** Adding two Decimals with plain `+` concatenates arrays; use `Add`, `Multiply`, `Scale`, and friends so the result stays a normalized Decimal.
- **`Add` drops a term that is ~15+ orders of magnitude smaller.** That is correct at idle scale (the small term is below float precision) but means micro-amounts vanish next to a huge stockpile - by design, not a bug.
- **`To Number` can hand back `Infinity`.** It is only safe while the Decimal is under `1.8e308`. For endgame values keep everything in Decimal and render with `Format Big` instead of converting.
- **The short formatters fall through to scientific past Dc.** `Format Short` and `Format Big` only carry named suffixes to `Dc` (`1e33`); above that they emit `"...e42"` style strings automatically, so a very large number never returns a blank suffix.
- **`Format Percent` expects a fraction, not a whole percent.** Pass `0.25` to get `"25%"`; passing `25` yields `"2500%"`. Divide your progress into a `0..1` fraction first.
- **`Format Amount` is the Currency Ledger name, `Format Short` is the Big Numbers name.** They do the same K/M/B/T job; use whichever pack you are already calling and do not expect one pack's expression to exist on the other.
