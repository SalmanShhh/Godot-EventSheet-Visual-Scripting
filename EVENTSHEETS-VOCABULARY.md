# Project vocabulary - Godot EventSheets

> Generated - do not edit. Regenerate via the dock (Tools → Vocabulary Doc…) or
> `godot --headless --path . --script tools/vocabulary_doc.gd`.

## Sheets

### compiler_golden_sheet (`res://tests/fixtures/compiler_golden_sheet.tres`)
Node script extending `CharacterBody2D`.

#### Properties
- `health: int` (default `100`)
- `speed: float` (default `200.0`)

## Script packs

### SimpleAbilitiesBehavior (`res://eventsheet_addons/abilities/abilities_behavior.gd`)
@ace_category("Abilities") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Ability Activated**
- **On Ability Ready**
- **On Ability Created**
- **On Ability Removed**
- **On Stack Consumed**
- **On Stack Gained**
- **On Max Stacks Reached**

#### Conditions
- **Has Ability** (`id: String`)
- **Is Ability Ready** (`id: String`)
- **Is Ability Active** (`id: String`)
- **Is Ability Enabled** (`id: String`)
- **Has Stacks Available** (`id: String`)
- **Ability Has Tag** (`id: String, tag: String`)
- **Current Ability Is** (`id: String`)

#### Actions
- **Create Ability** (`id: String`) - Grants an empty ability (no cooldown, 1 stack, enabled). Fires On Ability Created if new.
- **Create Ability With Cooldown** (`id: String, seconds: float, reset_instantly: bool`) - Grants an ability and sets its cooldown. reset_instantly=true starts it ready.
- **Create Ability With Cooldown And Stacks** (`id: String, seconds: float, max_stacks: int, reset_instantly: bool`) - Grants a charge-based ability; each stack regenerates over `seconds`. reset_instantly=true starts full.
- **Create Temporary Ability** (`id: String, seconds: float`) - Grants an ability that auto-removes after `seconds`. Calling again refreshes the timer.
- **Remove Ability After Duration** (`id: String, seconds: float`) - Schedules removal of an existing ability after `seconds`.
- **Remove Ability** (`id: String`) - Deletes an ability and all its data. Fires On Ability Removed.
- **Clear All Abilities** - Removes every ability. Fires On Ability Removed for each.
- **Activate Ability** (`id: String`) - Activates an ability if it is ready: consumes a stack, starts regen, fires On Ability Activated.
- **Set Ability Cooldown** (`id: String, seconds: float`) - Puts an ability on cooldown (scaled by the global cooldown multiplier).
- **Reset Cooldown** (`id: String`) - Refreshes an ability: clears its cooldown AND grants the next charge back, so a spent ability is ready again (readiness is charge-based). The kill-refresh / cooldown-reset mechanic. On a full ability it just clears the timer.
- **Set Max Stacks** (`id: String, max_stacks: int`) - Changes max charges (current stacks clamp down).
- **Set Stacks** (`id: String, stacks: int`) - Sets current charges (clamped 0..max).
- **Add Stacks** (`id: String, count: int`) - Adds charges up to max. Fires On Stack Gained, and On Max Stacks Reached if it would overflow.
- **Consume Ability Stack** (`id: String`) - Removes one charge without activating; starts regen if needed.
- **Set Ability Enabled** (`id: String, enabled: bool`) - Enables or disables activation.
- **Set Ability Active** (`id: String, active: bool`) - Sets the active flag (for channeled / toggle abilities).
- **Set Ability Data** (`id: String, key: String, value: String`) - Stores a custom key/value (string) on an ability.
- **Add Tag** (`id: String, tag: String`) - Tags an ability (safe if it already has the tag).
- **Remove Tag** (`id: String, tag: String`) - Removes a tag from an ability.
- **Clear All Tags** (`id: String`) - Removes every tag from an ability.
- **Set Abilities With Tag Enabled** (`tag: String, enabled: bool`) - Enables/disables every ability carrying a tag.
- **Remove All Abilities With Tag** (`tag: String`) - Deletes every ability with a tag. Fires On Ability Removed for each.
- **Reset Cooldown For Abilities With Tag** (`tag: String`) - Refreshes every ability with a tag: clears each cooldown and grants a charge back, so a whole group is ready again.
- **Set Cooldown Multiplier** (`multiplier: float`) - Global cooldown scaling for all future Set Cooldown calls (0.8 = 20% cooldown reduction).
- **Load Ability Set** (`resource: Resource`) - Creates every ability listed in an AbilitySetResource (.tres): id, cooldown, max stacks, temporary duration, and comma-separated tags. Each is granted ready. Drop the resource in the Inspector to auto-load on ready, or call this to swap loadouts at runtime.

#### Expressions
- **Current Ability ID**
- **Cooldown Remaining** (`id: String`)
- **Cooldown Progress** (`id: String`)
- **Stacks** (`id: String`)
- **Max Stacks** (`id: String`)
- **Stack Cooldown Remaining** (`id: String`)
- **Stack Progress** (`id: String`)
- **Expiration Time** (`id: String`)
- **Expiration Progress** (`id: String`)
- **Max Expiration Time** (`id: String`)
- **Ability Count**
- **List Active Abilities**
- **Ready Abilities**
- **Ability Data** (`id: String, key: String`)
- **Count Abilities By Tag** (`tag: String`)
- **Ability By Tag Index** (`tag: String, index: int`)
- **List Abilities By Tag** (`tag: String`)

### AdvancedRandomAddon (`res://eventsheet_addons/advanced_random/advanced_random_addon.gd`)
@ace_tags(random, noise, procedural) @ace_version(1.0.0)

#### Conditions
- **Chance** (`percent: float`) - True roughly percent of the time (0-100) - e.g. Chance(5) for a 5% event.
- **One In** (`n: int`) - True with a 1-in-n probability.

#### Actions
- **Set Seed** (`seed_value: int`) - Sets the seed for BOTH numbers and noise - same seed reproduces the same sequence.
- **Randomize Seed** - Picks a fresh, unpredictable seed (non-reproducible).
- **Set Noise Type** (`noise_type: int`) - FastNoiseLite.NoiseType: 0 Simplex · 1 Simplex Smooth · 2 Cellular · 3 Perlin · 4 Value Cubic · 5 Value.
- **Set Noise Frequency** (`frequency: float`) - Lower = smoother/larger features; higher = noisier (default 0.01).
- **Set Noise Octaves** (`octaves: int`) - Fractal detail layers - more octaves add fine detail (fractal/fBm noise).
- **Generate Permutation Table** (`size: int`) - Builds a shuffled 0..size-1 table (read with the Permutation expression) - a fixed deck order.
- **Make Shuffle Bag** (`bag_name: String, items: Array`) - Creates a named bag of items - Shuffle Bag Pick draws each once before any repeats.

#### Expressions
- **Random (0-1)** - A uniform float in [0, 1).
- **Random Range** (`minimum: float, maximum: float`) - A uniform float between min and max.
- **Random Int** (`minimum: int, maximum: int`) - A uniform integer between min and max (inclusive).
- **Roll Dice** (`sides: int`) - Rolls a die with the given number of sides (1..sides).
- **Random Sign** - Either -1 or +1.
- **Normal (Gaussian)** (`mean: float, deviation: float`) - A normally-distributed float around mean with the given deviation.
- **Noise 1D** (`x: float`) - Smooth noise along a line at x - returns [-1, 1].
- **Noise 2D** (`x: float, y: float`) - Smooth noise at (x, y) - great for terrain/heightmaps; returns [-1, 1].
- **Noise 3D** (`x: float, y: float, z: float`) - Smooth noise at (x, y, z) - returns [-1, 1].
- **Permutation Value** (`index: int`) - Reads index (wrapped) from the permutation table - generate it first.
- **Pick From** (`options: Array`) - A uniformly-random element of the array (null if empty).
- **Weighted Index** (`weights: Array`) - An index chosen in proportion to the weights array (heavier = likelier).
- **Pick From Table** (`table: Resource`) - A weighted-random value from a RandomTableResource (.tres) - author your odds as a data asset and draw from it. "" if the table is empty.
- **Shuffle Bag Pick** (`bag_name: String`) - Draws the next item from a named bag - every item appears once before any repeat.

### BackgroundRunner (`res://eventsheet_addons/background_runner/background_runner_behavior.gd`)
@ace_tags(performance, threading) @ace_category("Background") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Done** (`result: Variant`)

#### Conditions
- **Is Running**

#### Actions
- **Run In Background** (`work: Callable`) - Runs a PURE callable off the main thread; On Done(result) fires when it finishes. WARNING: the callable must NOT touch nodes / the scene tree / non-thread-safe resources - data in, data out only.
- **Run Batch In Background** (`items: Array, work: Callable`) - Fans an array across worker threads: runs work.bind(item) for each item (On Done fires per item). The callable must be PURE.

#### Expressions
- **Tasks Running**

### BigNumberAddon (`res://eventsheet_addons/big_number/big_number_addon.gd`)
@ace_tags(incremental, idle, format) @ace_category("Big Numbers") @ace_version(1.0.0)

#### Conditions
- **Is Bigger** (`a: Array, b: Array`) - Whether Decimal a is strictly bigger than Decimal b.
- **Is At Least** (`a: Array, b: Array`) - Whether Decimal a is at least as big as Decimal b.

#### Expressions
- **Format Short** (`value: float, decimals: int`) - A compact string with a short-scale suffix: 1250 -> "1.25K", 1250000 -> "1.25M", on through Qa/Qi/.../Dc, then scientific past 1e36. Pass how many decimals.
- **Format Scientific** (`value: float, decimals: int`) - Scientific notation: 1250000 -> "1.25e6". Pass how many decimals for the mantissa.
- **Format Engineering** (`value: float, decimals: int`) - Engineering notation - the exponent is always a multiple of 3: 1250000 -> "1.25e6", 12500 -> "12.50e3".
- **Format Time** (`seconds: float`) - Seconds as a friendly duration: 3725 -> "1h 2m 5s". Drops leading zero units (90 -> "1m 30s").
- **Format Time Short** (`seconds: float`) - Seconds as a clock: 3725 -> "1:02:05", 90 -> "1:30".
- **Format Ordinal** (`number: int`) - An ordinal string: 1 -> "1st", 2 -> "2nd", 13 -> "13th", 21 -> "21st".
- **Format Comma** (`value: float`) - Thousands separators on the whole-number part: 1234567 -> "1,234,567".
- **Format Percent** (`value: float, decimals: int`) - A fraction as a percent: 0.25 -> "25%". Pass how many decimals.
- **Format Multiplier** (`value: float, decimals: int`) - A multiplier label: 1.5 -> "x1.5", 2.0 -> "x2.0".
- **Suffix For** (`magnitude: int`) - The short-scale suffix for an order of magnitude: 6 -> "M", 9 -> "B". "" past Dc.
- **Order Of Magnitude** (`value: float`) - The power of ten of a value (floor log10): 1250 -> 3, 1000000 -> 6.
- **Make** (`mantissa: float, exponent: float`) - Builds a Decimal from a mantissa and an exponent: Make(1.5, 100) is 1.5e100. Normalized automatically.
- **From Number** (`value: float`) - Turns a plain number into a Decimal so it can grow past the float ceiling.
- **To Number** (`decimal: Array`) - Turns a Decimal back into a plain number (may be Infinity if it is above 1.8e308).
- **Add** (`a: Array, b: Array`) - Adds two Decimals. When one is more than ~15 orders of magnitude larger, the smaller is negligible and dropped.
- **Subtract** (`a: Array, b: Array`) - Subtracts Decimal b from Decimal a.
- **Multiply** (`a: Array, b: Array`) - Multiplies two Decimals (mantissas multiply, exponents add).
- **Divide** (`a: Array, b: Array`) - Divides Decimal a by Decimal b (returns 0 if b is 0).
- **Power** (`decimal: Array, power: float`) - Raises a Decimal to a power: Power(d, 2) squares it. Works in log space so a big power never overflows.
- **Scale** (`decimal: Array, factor: float`) - Multiplies a Decimal by a plain number - the easy way to apply a multiplier.
- **Compare** (`a: Array, b: Array`) - Compares two Decimals: -1 if a < b, 0 if equal, 1 if a > b.
- **Format Big** (`decimal: Array, decimals: int`) - Formats a Decimal with a short-scale suffix, falling through to scientific past Dc: Make(1.5, 100) -> "1.50e100".

### BoostAddon (`res://eventsheet_addons/boosts/boosts_addon.gd`)
@ace_tags(incremental, idle, boost) @ace_category("Boosts") @ace_version(1.0.0)

#### Triggers
- **On Boost Started**
- **On Boost Expired**

#### Conditions
- **Is Active** (`id: String`) - Whether a boost with this id is currently running.
- **Any Active** - Whether any boost is currently running.

#### Actions
- **Start Boost** (`id: String, multiplier: float, duration: float`) - Starts (or restarts) a timed multiplier by id for `duration` seconds and fires On Boost Started.
- **Start Tagged Boost** (`id: String, multiplier: float, duration: float, tag: String`) - Like Start Boost, but with a tag so Multiplier For Tag can group it (e.g. "production", "click").
- **Extend Boost** (`id: String, seconds: float`) - Adds seconds to an active boost's timer (does nothing if it is not active).
- **Stop Boost** (`id: String`) - Ends a boost immediately (no On Boost Expired - that is for timers running out).
- **Clear Boosts** - Ends every active boost at once.

#### Expressions
- **Total Multiplier** - The product of every active boost's multiplier (1.0 if none) - fold it into production.
- **Multiplier For Tag** (`tag: String`) - The product of active boosts that share this tag (1.0 if none).
- **Multiplier Of** (`id: String`) - One boost's multiplier (1.0 if it is not active).
- **Time Left** (`id: String`) - Seconds remaining on a boost (0 if not active) - for a countdown label.
- **Active Count** - How many boosts are currently running.
- **Last Expired** - The id of the boost that just ran out (read inside On Boost Expired).

### BoundToBehavior (`res://eventsheet_addons/bound_to/bound_to_behavior.gd`)
@ace_tags(movement, screen) @ace_category("Bound To") @ace_version(1.0.0)

#### Triggers
- **On Hit Bound** (`side: String`)

#### Conditions
- **Is At Bound** (`side: String = "any"`) - True while the host is pressed against a bound. side: left / right / top / bottom / any.

#### Actions
- **Set Bound Enabled** (`enabled: bool`) - Turns the binding on or off at runtime (off = the host moves freely).
- **Set Custom Bounds** (`x: float, y: float, width: float, height: float`) - Sets the custom rectangle (world-space pixels) and switches the binding to it - your level's playable area.
- **Set Bound Extents** (`new_half_width: float, new_half_height: float`) - Sets the host's half-size used by edge binding (half the sprite's width and height).
- **Set Bound Space** (`space: String`) - Switches what the host is kept inside: the on-screen camera view, or the custom rectangle.

### BulletBehavior (`res://eventsheet_addons/bullet/bullet_behavior.gd`)
@ace_category("Bullet") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Bullet Hit** (`collider: Object, point: Vector2, normal: Vector2`)

#### Actions
- **Set Bullet Speed** (`value: float`) - Changes speed, keeping the current direction.
- **Set Angle Of Motion** (`degrees: float`) - Redirects the bullet (degrees).
- **Set Gravity Angle** (`angle: float`) - Points gravity in a new direction, in degrees (90 = down, 270 = up, 0 = right) - the arc bends that way from now on. Magnet fields, wind wells, and upside-down zones in one action.
- **Set Bullet Enabled** (`is_enabled: bool`) - Pauses or resumes the movement.

### Bullet3DBehavior (`res://eventsheet_addons/bullet_3d/bullet_3d_behavior.gd`)
@ace_category("Bullet 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Bullet Hit** (`collider: Object, point: Vector3, normal: Vector3`)

#### Actions
- **Launch Forward** - (Re)launches along the host's current forward direction.
- **Set Bullet 3D Speed** (`value: float`) - Changes speed, keeping the current direction.
- **Set Gravity Direction** (`x: float, y: float, z: float`) - Points gravity along a new 3D direction (it is normalized for you) - the arc bends that way from now on. (0, -1, 0) is normal down, (0, 1, 0) pulls up, (1, 0, 0) pulls along +X.

### CarBehavior (`res://eventsheet_addons/car/car_behavior.gd`)
@ace_category("Car") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Drift Started**
- **On Drift Recovered**

#### Actions
- **Stop Car** - Kills all momentum.

### CheckpointBehavior (`res://eventsheet_addons/checkpoint/checkpoint_behavior.gd`)
@ace_category("Checkpoint") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Respawned**

#### Actions
- **Set Checkpoint Here** - Marks the spot the host is standing on right now as its checkpoint.
- **Set Checkpoint At** (`point: Vector2`) - Marks any point in the world as the checkpoint, without moving the host.
- **Respawn At Checkpoint** - Teleports the host back to its checkpoint and fires On Respawned. If the host defines a reset() method it is called too - the same duck-typed seam the Object Pool uses when it wakes a pooled node - so velocity, health, and timers clear without this behavior knowing about them.

#### Expressions
- **Checkpoint Position** - The point the host respawns at.

### ClickPowerAddon (`res://eventsheet_addons/click_power/click_power_addon.gd`)
@ace_tags(incremental, idle, clicker) @ace_category("Click Power") @ace_version(1.0.0)

#### Triggers
- **On Click**
- **On Crit**

#### Conditions
- **Was Crit** - Whether the last click critted (read after Do Click / inside On Click).

#### Actions
- **Configure** (`base_click: float`) - Sets the base value of one click.
- **Set Multiplier** (`multiplier: float`) - Sets the click multiplier - feed it your composed prestige x upgrade x boost value.
- **Set Flat Bonus** (`bonus: float`) - Adds a flat amount to every click before the multiplier (from an upgrade).
- **Set CPS Fraction** (`fraction: float`) - Makes each click also worth this fraction of current production per second (Cookie-Clicker's "clicking is worth X% of CpS"; 0 = off).
- **Set Crit** (`chance: float, multiplier: float`) - Sets the crit chance (0 to 1) and its multiplier (e.g. 10 for a lucky x10 click).
- **Do Click** (`current_cps: float`) - Resolves one tap: computes the yield (pass your current total production per second, or 0), rolls a crit, records Last Click / Was Crit, and fires On Click (and On Crit). Then Add Last Click to your wallet.

#### Expressions
- **Click Yield** (`current_cps: float`) - What one click earns right now, without a crit (pass current production per second, or 0) - for a "per click" label.
- **Last Click** - What the last Do Click earned (after any crit) - Add this to your wallet.
- **Total Clicks** - How many clicks have been resolved.
- **Click Multiplier** - The current click multiplier.
- **Crit Chance** - The current crit chance, 0 to 1.

### ComboBoxAddon (`res://eventsheet_addons/combo_box/combo_box_addon.gd`)
@ace_tags(input, combo) @ace_category("ComboBox") @ace_version(1.0.0)

#### Triggers
- **On Combo Matched**
- **On Combo Failed**
- **On Partial Progress**
- **On Buffer Cleared**

#### Conditions
- **Has Combo** (`id: String`) - Whether a combo id is registered.
- **Is Combo Enabled** (`id: String`) - Whether a combo is registered and enabled.
- **Is Buffer Empty** - Whether the input buffer has no tokens.
- **Combo Has Tag** (`id: String, tag: String`) - Whether a combo carries a tag.

#### Actions
- **Register Combo** (`id: String, sequence: String, timing_window: float`) - Registers (or replaces) a combo: a unique id and its sequence as comma-separated tokens (for example "down,forward,punch"). timing_window is the seconds allowed between inputs (-1 = use the default, 0 = no time limit). Use "*" as a token to match any input.
- **Set Combo Tags** (`id: String, tags: String`) - Tags a registered combo with comma-separated tags, so you can enable or disable it in batches (for example "ground_move").
- **Set Combo Priority** (`id: String, priority: int`) - Sets a combo's priority. When more than one combo completes on the same input, the highest priority wins (ties go to the longest, then to the first registered).
- **Set Combo Strict** (`id: String, strict: bool`) - When strict is on, the combo's inputs must be adjacent in the buffer (no unrelated input allowed between them). Off (the default) tolerates stray inputs in between, like a fighting-game motion.
- **Set Default Timing** (`seconds: float`) - Sets the default seconds allowed between inputs, used by any combo whose own timing window is -1.
- **Set Buffer Length** (`length: int`) - Sets how many recent inputs to remember. Older inputs drop off, so stale history cannot complete a combo.
- **Press Input** (`token: String`) - Pushes one input token into the buffer and checks every combo. Call this from your own input events (a key, a gamepad button, a swipe, a network packet). Fires On Combo Matched / On Partial Progress / On Combo Failed as needed.
- **Clear Buffer** - Empties the buffer and resets all partial progress (fires On Buffer Cleared). Call it on a context change - entering a cutscene or menu - so old inputs cannot leak into new combos.
- **Enable Combo** (`id: String`) - Enables a combo so it takes part in matching.
- **Disable Combo** (`id: String`) - Disables a combo so it is skipped in matching (its registration is kept).
- **Enable Combos By Tag** (`tag: String`) - Enables every combo carrying a tag (for example all "air_move" combos).
- **Disable Combos By Tag** (`tag: String`) - Disables every combo carrying a tag.
- **Remove Combo** (`id: String`) - Permanently removes a combo from the registry.

#### Expressions
- **Matched Id** - The id of the combo that just matched (inside On Combo Matched).
- **Matched Tags** - The matched combo's tags as a comma-separated string (inside On Combo Matched).
- **Match Time** - The clock time in seconds when the combo matched (inside On Combo Matched).
- **Failed Id** - The id of the combo that just failed (inside On Combo Failed).
- **Fail Index** - How many inputs deep the failed combo had reached before it broke (inside On Combo Failed).
- **Buffer Length** - How many tokens are in the buffer right now.
- **Buffer Token** (`index: int`) - The token at a buffer index (0 = oldest); "" if out of range.
- **Buffer Time** (`index: int`) - The clock time in seconds of the token at a buffer index (0 if out of range).
- **Cleared Count** - How many tokens were in the buffer when it was last cleared (inside On Buffer Cleared).
- **Partial Count** - How many combos are part-way matched after the last input (inside On Partial Progress).
- **Partial Id** (`index: int`) - The id of the part-way combo at an index (use with Partial Count to loop).
- **Partial Progress** (`index: int`) - How many inputs of the part-way combo at an index are matched so far.
- **Partial Length** (`index: int`) - The total length of the part-way combo at an index (pair with Partial Progress for a fill bar).
- **Combo Count** - How many combos are registered.
- **Combo Id At** (`index: int`) - The registered combo id at an index (use with Combo Count to list them).

### CurrencyLedgerAddon (`res://eventsheet_addons/currency_ledger/currency_ledger_addon.gd`)
@ace_tags(economy, currency) @ace_category("Currency") @ace_version(1.0.0)

#### Triggers
- **On Amount Changed**
- **On Spend Failed**
- **On Cap Hit**
- **On Daily Cap Hit**
- **On Offline Gain**

#### Conditions
- **Has Currency** (`id: String`) - Whether a currency with this id has been defined or touched.
- **Can Afford** (`id: String, amount: float`) - Whether the current balance is at least the amount.
- **Is At Cap** (`id: String`) - Whether the balance is at its max (false when there's no cap).
- **Is Daily Cap Reached** (`id: String`) - Whether today's earnings have hit the daily cap (false when there's none).
- **Is In Debt** (`id: String`) - Whether the balance is below zero (only possible after Allow Debt).

#### Actions
- **Define Currency** (`id: String, starting_amount: float, max_amount: float`) - Creates (or resets) a currency with a starting amount and a max (-1 = no cap). Min is 0 and there's no daily cap until you set one.
- **Set Max** (`id: String, max_amount: float`) - Changes the hard cap (-1 = no cap). If the current amount is above the new cap it clamps down.
- **Set Daily Cap** (`id: String, daily_cap: float`) - Caps how much can be EARNED (added) per day (-1 = no daily cap). You decide when a day rolls over by calling Reset Daily Caps.
- **Allow Debt** (`id: String, minimum: float`) - Lets a currency go negative down to this floor (e.g. -50). Use it for hunger, heat, or overdraft. Default floor is 0 (no debt).
- **Set Offline Rate** (`id: String, rate_per_second: float`) - Passive income per real second, used by Apply Offline Gain (0 = off).
- **Add** (`id: String, amount: float`) - Adds a SIGNED amount (negative subtracts) and clamps to the currency's min and max. Positive amounts also respect the daily cap. Fires On Amount Changed, plus On Cap Hit / On Daily Cap Hit if a limit bit.
- **Spend** (`id: String, amount: float`) - Subtracts the amount only if it can be afforded; otherwise nothing changes and On Spend Failed fires (read Failed Id / Requested Amount / Available Amount there).
- **Set Amount** (`id: String, amount: float`) - Forces the amount to a value, clamped to the currency's min and max. Fires On Amount Changed.
- **Reset Daily Caps** - Zeroes the earned-today counter for every currency (call this at your day rollover).
- **Apply Offline Gain** (`id: String, elapsed_seconds: float`) - Credits offline_rate * seconds to the currency (respecting caps) and fires On Offline Gain. One call - no separate Add needed.

#### Expressions
- **Balance** (`id: String`) - The current amount of a currency (0 if undefined).
- **Cap** (`id: String`) - The hard cap of a currency (-1 if none).
- **Daily Cap** (`id: String`) - The daily earn cap (-1 if none).
- **Daily Earned** (`id: String`) - How much has been earned today.
- **Debt Floor** (`id: String`) - The minimum a currency may reach (0 unless Allow Debt was used).
- **Currency Count** - How many currencies are defined.
- **Currency Id At** (`index: int`) - The currency id at a position (for menus); "" out of range.
- **Format Amount** (`value: float, decimals: int`) - A short display string with a K/M/B/T suffix (e.g. 12500 -> "12.5K").
- **Changed Id** - The currency that changed (inside On Amount Changed).
- **New Amount** - The amount after the change (inside On Amount Changed).
- **Previous Amount** - The amount before the change (inside On Amount Changed).
- **Amount Delta** - The signed change (inside On Amount Changed).
- **Failed Id** - The currency of the failed spend (inside On Spend Failed).
- **Requested Amount** - The amount that was asked for (inside On Spend Failed).
- **Available Amount** - What was actually available (inside On Spend Failed).
- **Offline Id** - The currency credited (inside On Offline Gain).
- **Offline Gain** - The amount credited offline (inside On Offline Gain).

### DebugOverlayAddon (`res://eventsheet_addons/debug_overlay/debug_overlay_addon.gd`)
@ace_tags(debug, overlay, hud, profiling) @ace_category("Debug Overlay") @ace_version(1.0.0)

#### Triggers
- **On Overlay Toggled** (`shown: bool`)

#### Conditions
- **Overlay Is Visible** - True while the overlay is on screen. False in a release build, before any row has drawn to it, and while the toggle key has it hidden.

#### Actions
- **Watch Value** (`watch_name: String, value: Variant`) - Shows name = value in the on-screen list, refreshed every time you set it. Call it from an Every Frame row and it reads like a live watch window over the running game. Debug builds only.
- **Clear Watch** (`watch_name: String`) - Drops one named value from the on-screen list, for when a watch has served its purpose and is just taking up a line.
- **Show Bar** (`bar_name: String, fraction: float, bar_color: Color`) - Draws a named meter filled to a fraction from 0 to 1, in the colour you pick. The fastest way to see stamina, a cooldown, or an AI's confidence without building any UI.
- **Mark Point** (`at: Vector2, mark_label: String, seconds: float`) - Drops a labelled cross at a world position for a moment, so you can SEE where something happened. The mark stays glued to the world while the camera moves, then fades out on its own.
- **Draw Ray** (`origin: Vector2, direction: Vector2, length: float, ray_color: Color, seconds: float`) - Draws a line from a world position along a direction for a given length, which is what you want on screen while tuning a detection cone, an aim vector, or a raycast that keeps missing.
- **Label Above** (`node: Node, label_text: String, seconds: float`) - Floats a line of text above a node for a moment - the fastest way to debug a dozen enemies at once, because each one carries its own state on screen. Works for a Node2D, a Control, or a Node3D seen through the active camera.
- **Show Overlay** - Makes the overlay visible again after it was hidden. Fires On Overlay Toggled when it was actually hidden.
- **Hide Overlay** - Hides the overlay without clearing anything. Rows keep recording, so showing it again brings the values straight back.
- **Toggle Overlay** - Flips the overlay between shown and hidden, the same thing the toggle key does - put it on a button so a playtester can turn it on for a screenshot.
- **Clear Overlay** - Wipes every watch, bar, mark, ray and label at once. Useful between levels, or at the head of a run so last run's evidence does not confuse this one.

### DecalPainter (`res://eventsheet_addons/decal_painter/decal_painter_behavior.gd`)
@ace_tags(3d, drawing, visual) @ace_category("Decal Painter") @ace_version(1.0.0)

#### Actions
- **Spawn Decal** (`texture: Texture2D, x: float, y: float, z: float, size: float, rotation_deg: float, lifetime: float`) - Stamps a decal onto the world at a position - splats, scorch marks, target rings. Lifetime 0 keeps it forever (until the max-decals cap recycles it).
- **Spawn Blob Shadow** (`follow: Node, radius: float, opacity: float, collision_mask_3d: int`) - Keeps a soft shadow blob ground-snapped under a node - the classic character shadow, no asset needed. The floor is found by raycast against the collision mask.
- **Stop Blob Shadow** (`follow: Node`) - Removes the blob shadow following a node.
- **Spawn Canvas Decal** (`canvas: Node, x: float, y: float, z: float, size: float, rotation_deg: float`) - Projects a 2D Drawing Canvas's LIVE texture onto the world as a decal - draw a line-of-sight fan or telegraph in 2D and paint it on the 3D floor. Pass the DrawingCanvas behavior node; the decal updates as the canvas draws.
- **Clear Decals** - Frees every spawned decal and blob shadow.
- **Set Max Decals** (`count: int`) - Changes the FIFO cap - the oldest decals free immediately if over it.

#### Expressions
- **Decal Count**

### DemoHealthAddon (`res://eventsheet_addons/demo_health_addon.gd`)
Demo EventSheet ACE addon. Drop scripts like this into res://eventsheet_addons/ and their annotated members become project-wide ACEs automatically - no manifest, no JSON, no per-sheet setup. Provider name comes from class_name, this comment is the addon description, and @ace_* annotations customize each ACE. @ace_version(1.0.0)

#### Triggers
- **On Healed** (`amount: int`) - Fires after health is restored.

#### Conditions
- **Is Hurt** (`threshold: int`) - True while health is below the given threshold.

#### Actions
- **Heal** (`amount: int`) - Restores health by an amount.
- **Announce Heal** (`amount: int`) - Prints a heal announcement. No @ace_codegen_template on purpose: the generated script owns a DemoHealthAddon instance and calls this directly (instance-backed ACE - the zero-config default for template-less addon methods).

### DialogueKitBehavior (`res://eventsheet_addons/dialogue_kit/dialogue_kit_behavior.gd`)
@ace_category("UI") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Dialogue Started**
- **On Dialogue Finished**
- **On Line Started**
- **On Line Finished**

#### Conditions
- **Is Dialogue Active**
- **Is Typing**
- **Speaker Is** (`speaker: String`)

#### Actions
- **Queue Line** (`speaker: String, text: String`) - Appends a line (speaker + text) to the conversation queue.
- **Start Dialogue** - Shows the panel and plays the queued lines from the top.
- **Advance** - Mid-line: completes the line instantly. Otherwise: next line, or ends the conversation.
- **End Dialogue** - Hides the panel, clears any remaining lines, and fires On Dialogue Finished.

#### Expressions
- **Current Speaker**
- **Current Text**
- **Lines Remaining**

### DragDropBehavior (`res://eventsheet_addons/drag_drop/drag_drop_behavior.gd`)
@ace_category("Drag & Drop") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Drag Started**
- **On Dropped**
- **On Drag Cancelled**
- **On Snapped**

#### Conditions
- **Is Dragging**
- **Is Enabled**
- **Is Snapping**

#### Actions
- **Start Drag** (`drag_point_x: float, drag_point_y: float, grab_mode: int`) - Begins a drag at a point. grab_mode 0 = keep offset from the host; 1 = centre on the point.
- **Start Drag At Object** (`target: Node2D, grab_mode: int`) - Begins a drag that follows the given object each tick.
- **Drop** (`how: int`) - Ends the drag. how 0 = apply throw/snap; 1 = cancel silently.
- **Set Drag Point** (`x: float, y: float`) - Updates the drag point (call each tick from your input source).
- **Set Drag Point To Object** (`target: Node2D`) - Sets the drag point to an object's current position (one-shot).
- **Set Follow Speed** (`speed: float`) - Max catch-up speed (px/s); 0 = instant snap each tick.
- **Set Directions** (`dirs: int`) - Direction lock: 0 free, 1 up/down, 2 left/right, 3 four-dir, 4 eight-dir.
- **Set Break Distance** (`distance: float, action: int`) - Auto-end the drag past this gap; action 0 = drop, 1 = cancel. 0 distance disables.
- **Set Throw Velocity** (`velocity_x: float, velocity_y: float`) - Overrides the auto-measured throw velocity for the next drop.
- **Set Enabled** (`is_enabled: bool`) - Enables/disables; disabling mid-drag cancels silently.
- **Add Snap Position** (`x: float, y: float`) - Registers a fixed snap/magnet position.
- **Add Snap Object** (`target: Node2D`) - Registers an object whose position is a live snap/magnet target.
- **Clear Snap Targets** - Removes every snap position and object.
- **Set Snap Radius** (`radius: float`) - Distance within which snapping/magnetism engages.
- **Set Snap Mode** (`mode: int`) - 0 = host-position proximity; 1 = drag-point overlap (v1 radius approximation).
- **Set Magnet Strength** (`strength: float`) - How strongly the drag is pulled toward a nearby snap target (0..1).

#### Expressions
- **Drag Point X**
- **Drag Point Y**
- **Drag Point Object UID**
- **Distance From Point**
- **Throw Velocity X**
- **Throw Velocity Y**
- **Throw Speed**
- **Drop Reason**
- **Snap Target X**
- **Snap Target Y**
- **Snapped Object UID**

### DrawingCanvas (`res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd`)
@ace_tags(drawing, visual) @ace_category("Drawing Canvas") @ace_requires(CanvasSurface, DrawingPrefabResource) @ace_version(1.0.0)

#### Conditions
- **Is Auto Clear**

#### Actions
- **Clear Canvas** - Wipes the canvas. In persistent mode the wipe happens on the next frame and the canvas keeps strokes again afterwards.
- **Set Auto Clear** (`enabled: bool`) - On: the canvas wipes itself every frame (re-issue draws each tick - vision cones, telegraphs). Off: strokes stay until Clear Canvas (paint, splats, skid marks).
- **Set Canvas Visible** (`visible_now: bool`) - Shows or hides the canvas display on the host.
- **Draw Line** (`from_x: float, from_y: float, to_x: float, to_y: float, width: float, color: Color`) - Draws a line segment - attack direction indicators, lasers, aim guides.
- **Draw Circle** (`x: float, y: float, radius: float, color: Color`) - Draws a filled circle - the classic soft blob shadow under a character.
- **Draw Ring** (`x: float, y: float, radius: float, width: float, color: Color`) - Draws a circle outline - selection rings, blast-radius previews.
- **Draw Rect** (`x: float, y: float, width: float, height: float, color: Color`) - Draws a filled rectangle (x/y = top-left corner).
- **Draw Dashed Line** (`from_x: float, from_y: float, to_x: float, to_y: float, dash_length: float, gap_length: float, width: float, color: Color`) - Draws a DASHED line segment - aim guides, tethers, boundary previews. dash_length and gap_length set the on/off rhythm.
- **Draw Dashed Ring** (`x: float, y: float, radius: float, dash_length: float, gap_length: float, width: float, color: Color`) - Draws a DASHED circle outline - range rings, dashed selection markers. The same dash primitive as Draw Dashed Line, wrapped around the circle.
- **Draw Dashed Rect** (`x: float, y: float, width: float, height: float, dash_length: float, gap_length: float, line_width: float, color: Color`) - Draws a DASHED rectangle outline - selection boxes, build-placement previews, zone markers. The dash rhythm carries continuously around all four sides.
- **Draw Cone** (`x: float, y: float, facing_deg: float, fov_deg: float, radius: float, color: Color`) - Draws a filled wedge - the attack-telegraph cone (pair with Auto Clear so it follows the attacker every frame).
- **Draw Stamp** (`texture: Texture2D, x: float, y: float, scale_factor: float, rotation_deg: float`) - Stamps a texture onto the canvas - bullet holes, footprints, splats. In persistent mode stamps pile up like decals.
- **Draw Line Of Sight** (`origin_x: float, origin_y: float, facing_deg: float, fov_deg: float, max_range: float, collision_mask: int, color: Color`) - Draws a character's LINE OF SIGHT as a filled fan: rays cast against the collision mask stop at walls, so the shape hugs the level exactly. Re-issue each tick with Auto Clear on for a live vision cone. Origin and range are WORLD coordinates.
- **Draw Prefab** (`prefab: Resource, x: float, y: float, scale_factor: float, rotation_deg: float`) - Replays a DrawingPrefabResource's steps IN ORDER at a position, scaled and rotated - author a target marker or scorch formation once as a .tres, stamp it everywhere.
- **Start Ribbon** (`follow: Node, point_count: int, width: float, color: Color`) - Starts a textured ribbon trailing a node - sword swooshes, skid marks, comet tails. The ribbon follows for Point Count frames of history; Set Ribbon Texture skins it.
- **Set Ribbon Texture** (`follow: Node, texture: Texture2D`) - Skins a running ribbon with a texture, stretched along its length.
- **Stop Ribbon** (`follow: Node`) - Ends the ribbon trailing a node.
- **Paste Node** (`node: Node`) - Bakes a node's CURRENT visual onto the canvas at its own world position - stamp a sprite, decal or icon permanently (persistent mode) or once per frame (auto clear). Non-destructive: the node stays, so pair it with Destroy to bake decor into one texture. Sprites, animated sprites and texture rects paste with their rotation, scale, flip, frame and tint; a node with no texture is skipped.
- **Paste Node At** (`node: Node, x: float, y: float, scale_factor: float, rotation_deg: float`) - Bakes a node's visual at an EXPLICIT spot (read like the other draw coordinates), scaled and rotated - stamp an off-screen template sprite anywhere, any number of times.
- **Paste Layer On Screen** (`layer: Node`) - Bakes every visible texture-bearing node under {layer} that is currently ON SCREEN onto the canvas - flatten a whole layer of decor into one texture (pair with Destroy for a performance bake). {layer} is any parent: a CanvasLayer, a container node, or the scene root.
- **Paste Layer In Box** (`layer: Node, x: float, y: float, width: float, height: float`) - Bakes every visible texture-bearing node under {layer} whose world rect falls inside the box at ({x}, {y}) sized {width} by {height} (world coordinates) onto the canvas - flatten a region regardless of the camera.

#### Expressions
- **Canvas Texture**

### EightDirectionMovement (`res://eventsheet_addons/eight_direction/eight_direction_movement_behavior.gd`)
@ace_category("Eight Direction") @ace_expose_all(node) @ace_version(1.0.0)

#### Actions
- **Set Move Speed** (`speed: float`) - Changes the movement speed.

### EncounterTimelineBehavior (`res://eventsheet_addons/encounter_timeline/encounter_timeline_behavior.gd`)
@ace_tags(spawning, waves, pacing, encounter) @ace_category("Encounter Timeline") @ace_version(1.0.0)

#### Triggers
- **On Entry Spawned** (`node: Node, group_name: String`)
- **On Encounter Finished**

#### Conditions
- **Encounter Is Running** - True between Start Encounter and the last beat (or Stop Encounter) - the guard that stops a second wave being started on top of the first.
- **Encounter Is Finished** - True once the last beat has played and the encounter has stopped itself - the "wave cleared, open the door" branch. False while it runs, false after Stop Encounter cut it short, and false again the moment Start Encounter rewinds it.
- **Encounter Is Empty** - True when no plan is loaded at all - the check for "did the designer forget the .tres".

#### Actions
- **Load Encounter** (`resource: Resource`) - Loads a whole plan from an EncounterResource (.tres) - every beat with its time, scene, count, group and note - REPLACING whatever was loaded before and rewinding the clock. Rows may be written in any order; they are sorted by time as they load.
- **Add Encounter Entry** (`at_seconds: float, scene_path: String, count: int, group_name: String, note: String`) - Adds one beat from a sheet, for an encounter built at runtime - a wave scaled to the player's level, a boss phase queued by the fight itself. It lands in time order wherever it belongs, even mid-encounter (a beat added before the clock has passed it still plays).
- **Clear Encounter** - Empties the plan and rewinds everything - no beats, clock at 0, nothing running. Load Encounter does this for you; call it yourself before building a plan out of Add Encounter Entry rows.
- **Start Encounter** - Runs the plan from the top: the clock restarts at 0, the spawn tally resets, and each beat fires as its time arrives. An encounter with no beats finishes on its very next frame, so On Encounter Finished still tells you the wave is over.
- **Stop Encounter** - Freezes the encounter where it stands - the clock stops and no further beat spawns. Already-spawned nodes are left alone (they are yours). Elapsed Seconds keeps its value, so a paused wave can be inspected; Start Encounter restarts from the top.
- **Use Object Pool Node** (`node: Node`) - Spawns through THIS pool node instead of searching for the ObjectPool autoload - for a per-arena pool, or a pool you wrote yourself. The contract is three functions: has_pool(name), create_pool(name, scene_path, prewarm) and spawn(name); a node missing any of them is ignored and the timeline instantiates scenes as usual. Pass nothing to go back to the autoload.
- **Skip To** (`seconds: float`) - Jumps the clock to a time WITHOUT spawning anything it passes - the debug verb for checking a late beat, or for a director that fast-forwards a tutorial the player already knows. Beats before that time are marked as played.
- **Write Encounter Report** (`path: String`) - Saves the Encounter Report to a text file - user://encounter_report.txt is the usual path, and lands in the app's user folder (the editor opens it from Project > Open User Data Folder). Everything in it is derived from the loaded beats, so it always matches the plan; it writes with plain file access and no editor at all, so a build server can produce it too. Warns in the output if the path cannot be written.

#### Expressions
- **Elapsed Seconds** - How far into the encounter the clock has run - the number behind a wave timer.
- **Encounter Duration** - When the LAST beat happens, in seconds (0 for an empty plan) - the length of the whole encounter.
- **Next Entry Seconds** - When the next beat is due, in seconds from the start of the encounter (-1 when none is left) - subtract Elapsed Seconds for a countdown to the next wave.
- **Entry Count** - How many beats the loaded plan holds.
- **Planned Spawn Count** - How many nodes the whole plan intends to spawn - every beat's count added up.
- **Spawned Count** - How many nodes this run has actually spawned so far - compare it with Planned Spawn Count to see how much of the wave is out.
- **Spawns Between** (`from_seconds: float, to_seconds: float`) - How many spawns the plan schedules in a window of time - from `from_seconds` (included) up to `to_seconds` (excluded). This is the pacing primitive: the density block of the Encounter Report is built out of it, so a graph you draw yourself agrees with the report exactly.
- **Entry Note At** (`index: int`) - The designer's note on the beat at a position, in time order ("" out of range) - the plain-language reminder written beside the row.
- **Entry Seconds At** (`index: int`) - When the beat at a position happens, in time order (-1 out of range).
- **Encounter Name** - The readable name written on the loaded encounter resource ("Wave 3") - the banner over an arena.
- **Last Spawned Node** - The node spawned most recently, or nothing before the first one - place it, aim it, or hand it to another pack right inside On Entry Spawned.
- **Last Spawned Group** - The group the most recent spawn was added to ("" when its beat named none).
- **Encounter Report** - The whole plan as plain text: the beat table (time, count, scene, group, note), the totals, everything the data does not say clearly, and the spawn density per 30 seconds. Every line is DERIVED from the loaded beats - nothing is written down twice - so it can never fall out of step with the encounter. Print it, show it in a debug overlay, or save it with Write Encounter Report.

### EventBusPackAddon (`res://eventsheet_addons/event_bus/event_bus_addon.gd`)
@ace_tags(events, messaging, decoupling) @ace_category("Events") @ace_version(1.0.0)

#### Triggers
- **On Event** (`channel: String, payload: Dictionary`)

#### Conditions
- **Wait For Event Succeeded** (`channel: String = "door_opened"`) - Whether the most recent Wait For Event on this channel ended because the message arrived. Put it on the rows under the wait - it is a state check on the wait that just finished, not a trigger. A wait still in flight is neither succeeded nor timed out.
- **Wait For Event Timed Out** (`channel: String = "door_opened"`) - Whether the most recent Wait For Event on this channel gave up without the message arriving. The recovery branch: say something else, open a different door, skip the beat. It stays false while a wait is still running, so it can only mean give-up.
- **Event Was Broadcast This Frame** (`channel: String = "boss_defeated"`) - Whether this channel was broadcast during the frame being processed right now. The polled read for a per-frame event; where you can, answer with the On Event trigger instead - it costs nothing and cannot miss.
- **Event Was Ever Broadcast** (`channel: String = "boss_defeated"`) - Whether this channel has been broadcast at least once since the game started. Useful for a gate that must stay open once something has happened, e.g. "the boss has been defeated at some point".

#### Actions
- **Wait For Event** (`channel: String = "door_opened", seconds: float = 8.0`) - Suspends this event until the named message is broadcast, or until the give-up time passes. The rows below it run when it resolves, so read what happened with the Wait For Event Succeeded / Wait For Event Timed Out conditions. A give-up time of 0 waits forever.
- **Broadcast Event** (`channel: String = "boss_defeated", payload: Dictionary = {}`) - Sends a named message to everyone listening, with a record of details. Anyone anywhere can answer it with On Event - the listener needs no reference to you, and you need none to it. The details arrive on the listener's row as the payload record, read by key.
- **Listen Once For Event** (`channel: String = "tutorial_done", on_node: Node = null, method_name: String = "_on_bus_event"`) - Asks for ONE delivery of a channel and then unsubscribes itself, so a tutorial gate or a one-time hint can never fire twice and can never leak. When the message arrives the named method is called on the node you picked, with the channel and the payload as its two arguments.
- **Broadcast To Group** (`group: String = "listeners", method_name: String = "on_bus_event", payload: Dictionary = {}`) - Calls a named method on every member of a group that actually has it, handing over the payload record. The fan-out half of the bus: use it when the answer belongs to a family of nodes rather than to a sheet, and nothing breaks when a member does not implement the method.
- **Clear Event Log** - Empties the record of what has been broadcast this session. The counters that Event Broadcast Count reads are kept, so only the report text is affected.
- **Print Event Bus Report** - Prints every broadcast recorded this session to the output, newest last, one channel and payload per line. A diagnostic: reach for it while you are hunting a missing listener, not in shipping rows.

#### Expressions
- **Event Broadcast Count** (`channel: String = "boss_defeated"`) - How many times this channel has been broadcast since the game started. 0 for a channel nobody has used.
- **Event Bus Report** - Everything broadcast this session as text, one "channel  payload" line each, newest last. Drop it into a debug label while you are hunting a listener that never fired.

### FadeBehavior (`res://eventsheet_addons/fade/fade_behavior.gd`)
@ace_tags(fade, juice) @ace_category("Fade") @ace_version(1.0.0)

#### Triggers
- **On Faded In**
- **On Fade Out Started**
- **On Faded Out**

#### Conditions
- **Is Fading**

#### Actions
- **Fade In** (`duration: float`) - Fades the node from its current transparency up to fully visible over a duration, then fires On Faded In.
- **Fade Out** (`duration: float`) - Fades the node down to invisible over a duration (fires On Fade Out Started now, On Faded Out at the end). Frees the node afterwards if Free On Faded Out is on.
- **Start Fade** - Runs the whole sequence from the Inspector times: fade in, hold, then fade out (firing On Faded In, On Fade Out Started, and On Faded Out along the way). Freeing the node at the end if set.
- **Stop Fade** - Cancels any running fade, leaving the node at its current transparency.
- **Set Opacity** (`alpha: float`) - Sets the node's transparency directly (0 = invisible, 1 = fully visible), cancelling any running fade.

#### Expressions
- **Opacity**

### FlashBehavior (`res://eventsheet_addons/flash/flash_behavior.gd`)
@ace_category("Flash") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Flash Finished**

#### Actions
- **Flash** (`seconds: float`) - Blinks the host for the given number of seconds.
- **Stop Flash** - Stops flashing and restores visibility.

### FollowBehavior (`res://eventsheet_addons/follow/follow_behavior.gd`)
@ace_category("Follow") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Reached Target**
- **On Path Blocked**

#### Actions
- **Start Following** (`path: String`) - Follows the node at the given path.
- **Follow Group** (`group: String`) - Follows the first node in a group - no tree path, so it survives the target being moved or renamed.
- **Stop Following** - Stops trailing the target.

### PathFollowBehavior (`res://eventsheet_addons/follow_path/path_follow_behavior.gd`)
@ace_tags(movement, path, curve) @ace_category("Path") @ace_version(1.0.0)

#### Triggers
- **On Path Finished**

#### Conditions
- **Is Following Path** - True while the host is actually travelling - the gate for a walk animation, a conveyor's hum, or a Stop row that should only fire once.
- **Is At Path End** - True while the host is parked at the far end of its route right now. This is the STATE question, asked whenever a row is reached; for the moment of arrival use the On Path Finished trigger instead - it fires once, for free, with no per-frame checking.

#### Actions
- **Follow Path** (`path: Path2D, speed: float = 120.0, mode: String = "once"`) - Sends the host travelling along a drawn Path2D at a real speed - patrol routes, conveyor lanes, camera dollies, tower-defence lanes. Ping-pong walks it back and forth forever; Once fires On Path Finished at the end.
- **Stop Following Path** - Halts the run where it stands, WITHOUT firing On Path Finished - a stunned patroller, a conveyor switched off, a dolly interrupted by the player. Follow Path starts it again from the top.

#### Expressions
- **Progress Along Path** - How far along its route the host has come, from 0 at the start to 1 at the end - a racer's lap bar, a delivery tracker, a boss phase keyed to how far the sweep has gone.
- **Point On Path At** (`path: Path2D, progress: float = 0.5`) - The world point a fraction of the way along a path (0 is the start, 1 is the end) - drive a camera dolly, a progress marker, or a preview ghost without moving anything.
- **Direction Along Path At** (`path: Path2D, progress: float = 0.5`) - Which way the path is heading a fraction of the way along it, as a direction one unit long - point a camera down the track, aim a spawned thing along the lane, or rotate a marker to match the curve.
- **Path Length** (`path: Path2D`) - How long a route is in pixels, measured along the curve rather than corner to corner - divide by a speed to know how many seconds the trip takes, or space things evenly along it.
- **Nearest Point On Path** (`path: Path2D, point: Vector2`) - The point on a route closest to a world position - snap a dragged tower onto the lane, work out where a stray unit rejoins its patrol, or find the spot on the track a racer left.

### FPSController (`res://eventsheet_addons/fps_controller/fps_controller_behavior.gd`)
@ace_category("FPS Controller") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Jumped**
- **On Air Jumped**
- **On Landed**
- **On Camera Mode Changed**
- **On Crouched**
- **On Stood Up**
- **On Slide Started**
- **On Slide Ended**
- **On Wall Ride Started**
- **On Wall Ride Ended**
- **On Wall Jumped**

#### Conditions
- **Is Sprinting** - True while the sprint key (Shift) is held.
- **Is First Person** - True in first-person camera mode.
- **Can Jump** - True while some jump is available right now: standing on the floor, within Coyote Time after leaving it, touching a wall with Wall Jump enabled, or holding a mid-air jump. Use it to show a jump prompt or gate a jump sound.
- **Is Crouching** - True while crouched (including during a crouch slide).
- **Is Sliding** - True during a crouch slide.
- **Is Wall Riding** - True while riding a wall (airborne, glued to it, gravity softened).
- **Can Stand Up** - True when there is headroom to stand from the current crouch (no ceiling in the way).

#### Actions
- **Jump** - Launches the host upward with Jump Velocity and fires On Jumped. The tick calls this from the floor or within Coyote Time; call it yourself for a scripted jump. Spends the coyote window, so it never grants a second ground jump.
- **Air Jump** - Performs a mid-air (double) jump with Jump Velocity and fires On Air Jumped, regardless of the remaining jump budget. The tick calls this automatically when Max Jumps allows; call it yourself for a power-up jump.
- **Add Look** (`x: float, y: float`) - Turns the view by a mouse delta (pixels): yaw rotates the host, pitch tilts the Head child, clamped to Pitch Min/Max.
- **Set Third Person** (`enabled: bool`) - Switches between first person (off) and third person (on) and fires On Camera Mode Changed.
- **Toggle Camera Mode** - Flips between first and third person.
- **Apply Camera Mode** - Re-applies the current camera mode to the Head's SpringArm3D (named Arm): ~0 length in first person, Camera Distance in third.
- **Capture Mouse** - Locks the mouse to the window for looking around (Esc releases it).
- **Release Mouse** - Frees the mouse cursor.
- **Set Move Speed** (`value: float`) - Changes the base walking speed.
- **Set Mouse Sensitivity** (`value: float`) - Changes look sensitivity (degrees per mouse pixel).
- **Crouch** - Crouches: the capsule shrinks to Crouch Height (feet stay planted), the Head drops, and movement slows to the crouch multiplier. Crouching at sprint speed starts a crouch slide (see Slide knobs). Fires On Crouched. Held Ctrl does this automatically.
- **Stand Up** - Stands back up from a crouch - unless a ceiling is in the way, in which case the crouch holds (re-check by calling again, or use the Can Stand Up condition). Ends any slide. Fires On Stood Up.
- **Set Crouching** (`enabled: bool`) - Crouches (on) or stands (off) - the scripted version of holding/releasing Ctrl.
- **Stop Sliding** - Ends a crouch slide early (you stay crouched). Fires On Slide Ended.
- **Wall Jump** - Kicks off the wall the host is touching: Jump Velocity upward plus Wall Jump Push away from the wall (the push fades over about half a second). Ends any wall ride. Fires On Wall Jumped. Pressing jump mid-air against a wall does this automatically.
- **Set Coyote Time** (`seconds: float`) - Changes the coyote grace window at runtime (0 turns it off) - a floaty-feel power-up, a hard-mode toggle, or a per-level tweak.
- **Reset Jumps** - Refills the mid-air jump budget right now (e.g. after grabbing a double-jump power-up), so the player gets their extra jumps back without landing.
- **Stop Wall Ride** - Detaches from the wall immediately (full gravity resumes). Fires On Wall Ride Ended.
- **Set Gravity Direction** (`x: float, y: float, z: float`) - Points gravity along a new 3D direction (normalized for you). (0, -1, 0) is normal down; (0, 1, 0) walks on ceilings - floor detection and jumps follow. A tilted direction still pulls correctly but the run plane stays world-horizontal.

#### Expressions
- **Current Speed** - The host's horizontal speed right now (metres per second).
- **Look Yaw** - The current horizontal look angle in degrees (-180..180).
- **Look Pitch** - The current vertical look angle in degrees (clamped to Pitch Min/Max).
- **Wall Normal X** - The touched wall's outward normal, X component (zero when not on a wall) - with Z, the direction a wall jump pushes; feed it to camera lean.
- **Wall Normal Z** - The touched wall's outward normal, Z component (zero when not on a wall).

### GameSettingsAddon (`res://eventsheet_addons/game_settings/game_settings_addon.gd`)
@ace_tags(settings, options, accessibility, audio) @ace_category("Settings") @ace_version(1.0.0)

#### Triggers
- **On Setting Changed** (`setting_name: String, value: Variant`)

#### Conditions
- **Changed Setting Is** (`setting_name: String`) - Whether the setting being announced right now is this one - the branch under On Setting Changed. Put one sub-event per setting under the trigger and each reaction stays a plain row. Once the announcement is over it keeps answering about the setting announced most recently, which is what makes it survive a reaction that waits; where several settings are applied in one go (Apply All Settings) and the reaction waits, branch on the trigger row's own setting_name value instead.
- **Setting Is** (`setting_name: String, value: Variant`) - Whether a setting currently holds this value - the plain state check, usable anywhere and at any time. difficulty is hard gates a rule; screen_shake is true guards an effect. An undeclared name reads as not matching.
- **Setting Is Declared** (`setting_name: String`) - Whether a setting has been declared at all. Useful when one sheet declares the settings and another might run first.

#### Actions
- **Declare Setting** (`setting_name: String, default_value: Variant, kind: String = "percent", choices: String = ""`) - Names a setting once: what it is called, what it defaults to, what kind of value it is, and (for a Choice) its options. Everything else in this pack reads that declaration, so the default is written in one place instead of at five call sites. Declaring the same name again replaces the declaration and keeps any value already set.
- **Set Setting** (`setting_name: String, value: Variant`) - Changes a declared setting and fires On Setting Changed with its name and new value. Setting it to the value it already holds does nothing at all, so a slider dragged back to where it started fires no reaction. A name that was never declared is refused with a warning rather than quietly stored.
- **Apply All Settings** - Re-fires On Setting Changed for EVERY declared setting, with the value in force now. This is the one row that makes boot and the options screen take the same path: the volume, the shake and the difficulty are applied by the same events either way, so they can never drift apart. Call it once after Load All Settings.
- **Reset Settings To Defaults** - Forgets every value that was set or loaded, so each setting falls back to its declared default, then re-applies them all (On Setting Changed fires for each). The options screen's Reset button, for free. Save All Settings afterwards to make it stick.
- **Load All Settings** - Reads saved values out of user://settings.cfg (the settings section) for every declared setting. The built-in Save Setting action writes the same file but takes its section as a parameter, so values saved that way are picked up when that row names the settings section. A setting with nothing saved keeps its default. Nothing is applied yet: follow it with Apply All Settings.
- **Save All Settings** - Writes every declared setting's current value into user://settings.cfg (the settings section), keeping anything else already in the file. Call it when the player closes the options screen. Settings live outside your save slots on purpose, so starting a new run never resets the volume.

#### Expressions
- **Setting Value** (`setting_name: String`) - The value a setting holds right now: the one that was set or loaded, or its declared default when nothing was ever saved. That fallback is the whole point of declaring - the game is correct on a fresh install, before the player has opened the options screen once. An undeclared name gives nothing.
- **Setting Kind** (`setting_name: String`) - What kind of value a setting is - percent, toggle, choice, number or text. This is what an options menu reads to know whether to build a slider, a checkbox or a dropdown. Blank when the name was never declared.
- **Setting Choices** (`setting_name: String`) - The options of a Choice setting as a list, in the order they were declared - drop it straight into a dropdown. Empty for every other kind.
- **Declared Setting Names** - Every declared setting's name, in the order they were declared - For Each over it and an options menu builds itself from the declaration instead of a hand-wired control per setting.
- **Settings Report** - Every declared setting as one readable line - name, kind, the value in force and the default it came from. What your game actually offers, in a form you can print, show in a debug overlay, or paste into a bug report. Blank when nothing has been declared.

### SimpleHealthBehavior (`res://eventsheet_addons/health/health_behavior.gd`)
@ace_category("Health") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Damaged**
- **On Death**
- **On Healed**
- **On Health Changed**
- **On Revived**
- **On Health Pool Added**
- **On Health Pool Absorbed**
- **On Health Pool Depleted**

#### Conditions
- **Is Invincible** - True while an invincibility window granted by Grant Invincibility is still open.
- **Is Dead**
- **Is Invulnerable**
- **Has Any Health Pool**
- **Has Health Pool** (`type: String`)
- **Health Pool Is Type** (`type: String`)

#### Actions
- **Take Damage** (`amount: float`) - Applies damage; health pools absorb in ascending-priority order before real HP. Ignored entirely while invincible (no HP lost, no On Damaged).
- **Heal** (`amount: float`) - Restores health up to max_health.
- **Set Health** (`amount: float`) - Sets current health directly, firing damage/heal/death as appropriate.
- **Set Max Health** (`amount: float`) - Sets max health (clamps current down if needed).
- **Set Invulnerable** (`state: bool`) - Toggles invulnerability (takeDamage no-op while true).
- **Grant Invincibility** (`seconds: float`) - Opens an invincibility window for the given seconds: Take Damage is ignored (no HP lost, no On Damaged) until it closes. Pair it with the Flash pack for the classic i-frame flicker.
- **Set Health Absorption Rate** (`rate: float`) - Damage multiplier for real HP (resistance); 0 = invulnerable.
- **Add Health Pool** (`type: String, amount: float`) - Adds to a named health pool (shield/armour).
- **Set Health Pool** (`type: String, amount: float`) - Sets a health pool amount (fires Added only when it increases).
- **Clear Health Pool** (`type: String`) - Zeroes one named health pool.
- **Clear All Health Pools** - Zeroes every health pool.
- **Set Health Pool Decay Rate** (`type: String, rate: float`) - Sets a pool's per-second decay rate.
- **Set Health Pool Absorption Rate** (`type: String, rate: float`) - Sets a pool's absorption multiplier (how hard it spends to soak damage).
- **Set Health Pool Rates** (`type: String, decay_rate: float, absorption_rate: float`) - Sets a pool's decay and absorption rates at once.
- **Set Health Pool Priority** (`type: String, priority: float`) - Sets a pool's absorption priority (lower absorbs first).
- **Setup Health Pool** (`type: String, amount: float, decay_rate: float, absorption_rate: float, priority: float`) - Creates/configures a health pool in one call.
- **Revive** (`amount: float`) - Clears death and restores health (amount<=0 → full).

#### Expressions
- **Current Health**
- **Max Health**
- **Health Percent**
- **Health Absorption Rate**
- **Last Damage**
- **Last Heal**
- **Health Pool** (`type: String`)
- **Health Pool Decay Rate** (`type: String`)
- **Health Pool Absorption Rate** (`type: String`)
- **Health Pool Priority** (`type: String`)
- **Last Pool Damage Absorbed**
- **Last Health Pool Type**

### HomeLeashBehavior (`res://eventsheet_addons/home_leash/home_leash_behavior.gd`)
@ace_category("Home & Leash") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Arrived Home**

#### Conditions
- **Is Beyond Home** (`distance: float, metric: int`) - True while the host has wandered further than this from home, in the distance metric you pick.

#### Actions
- **Set Home Here** - Plants home on the spot the host is standing on right now.
- **Set Home At** (`point: Vector2`) - Plants home on any point in the world, without moving the host.
- **Return Home** (`speed: float, delta: float`) - Walks the host one step back toward home - run it under a per-frame trigger and pass that trigger's delta. Fires On Arrived Home once, on the step that lands (within a pixel of home), not on every frame the host sits there.

#### Expressions
- **Distance From Home** (`metric: int`) - How far the host is from its home point, measured the way you pick: straight line, one axis only, grid steps (across plus down), or king moves (the larger of the two).

### HTNAgent (`res://eventsheet_addons/htn_agent/htn_agent_behavior.gd`)
@ace_tags(ai, planning) @ace_category("HTN") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Task Started** (`task_name: String`)
- **On Plan Complete**
- **On Plan Failed**

#### Conditions
- **Has Plan**
- **Current Task Is** (`task_name: String`)

#### Actions
- **Set World State** (`key: String, value: Variant`) - Writes a fact the planner reads in method preconditions.
- **Clear World State** (`key: String`) - Removes a world-state key.
- **Add Primitive Task** (`task_name: String`) - Registers a leaf task your sheet executes directly.
- **Add Compound Task** (`task_name: String`) - Registers a task that decomposes via methods.
- **Add Method** (`task_name: String, method_id: String, utility: float`) - Adds (or re-scores) a way to accomplish a compound task; highest utility wins.
- **Add Method Condition** (`task_name: String, method_id: String, key: String, op: String, value: Variant`) - A precondition (world-state key, operator, value) the method needs to be chosen.
- **Add Method Subtask** (`task_name: String, method_id: String, subtask: String`) - Appends a subtask (primitive or compound) to a method, in order.
- **Set Method Utility** (`task_name: String, method_id: String, utility: float`) - Updates a method's utility at runtime (utility-driven re-prioritising).
- **Clear Task Network** - Wipes all tasks/methods (keeps world state).
- **Request Plan** - Decomposes the root task into a plan and starts the first task.
- **Mark Task Complete** - Advances to the next task, or fires On Plan Complete at the end.
- **Mark Task Failed** - Re-plans from the root (or fires On Plan Failed if auto-replan is off).
- **Invalidate Plan** - Drops the current plan so the next Request Plan rebuilds it.

#### Expressions
- **Current Task**
- **Plan Length**
- **World Value** (`key: String`)

### HudKitBehavior (`res://eventsheet_addons/hud_kit/hud_kit_behavior.gd`)
@ace_category("UI") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Button Pressed**

#### Conditions
- **Button Is** (`button_name: String`)
- **Is Panel Visible** (`panel_name: String`)

#### Actions
- **Connect Buttons** - Wires every descendant Button's pressed signal into On Button Pressed (idempotent; re-run after spawning UI).
- **Set Text** (`control_name: String, text: String`) - Sets the text of a named Label, RichTextLabel, Button or LineEdit.
- **Set Bar** (`bar_name: String, value: float, max_value: float`) - Sets a named ProgressBar/TextureProgressBar's value (max_value too when > 0).
- **Show Panel** (`panel_name: String`) - Makes a named panel (any CanvasItem) visible.
- **Hide Panel** (`panel_name: String`) - Hides a named panel (any CanvasItem).
- **Toggle Panel** (`panel_name: String`) - Flips a named panel's visibility.
- **Switch Screen** (`panel_name: String`) - Shows the named panel and hides its sibling panels - one call flips a whole menu screen.
- **Show Toast** (`text: String`) - Pops a bottom-centre message that fades out after toast_seconds.
- **Pop Floating Text** (`text: String, at: Vector2, color: Color`) - Pops a damage number or score popup at a position: it drifts up, fades out and frees itself. No label to place, no tween to write, no cleanup to remember.

#### Expressions
- **Last Button Name**
- **Bar Value** (`bar_name: String`)

### IdleGeneratorBehavior (`res://eventsheet_addons/idle_generator/idle_generator_behavior.gd`)
@ace_tags(incremental, idle, economy) @ace_category("Idle Generator") @ace_version(1.0.0)

#### Triggers
- **On Purchased**
- **On Cycle Complete**

#### Conditions
- **Can Afford Next** (`budget: float`) - Whether `budget` covers the next single unit's price.
- **Is Owned** - Whether at least one unit is owned.

#### Actions
- **Buy One** - Adds one unit and records its price as Last Cost (Spend that from your wallet). Guard with Can Afford Next first.
- **Buy Amount** (`count: int`) - Adds `count` units at once and records the total price as Last Cost.
- **Buy Max** (`budget: float`) - Buys as many as `budget` affords, recording the exact total as Last Cost and the count as Last Bought. Buys nothing if not even one is affordable.
- **Set Owned** (`count: int`) - Forces the owned count to a value (clamped to 0). Does not record a cost.
- **Grant** (`count: int`) - Adds free units - a reward or a starting bonus (no cost recorded).
- **Set Output Multiplier** (`multiplier: float`) - Sets the overall output multiplier - feed it your composed prestige x upgrade x boost value.
- **Collect** - Cycle mode: hands you the banked output as Last Collected and clears the pending pile. Call it on On Cycle Complete (or from a manager) and credit Last Collected to your wallet.
- **Reset** - Clears owned, pending output, and cycle progress - for a prestige wipe.

#### Expressions
- **Owned** - How many units are owned.
- **Next Cost** - The price of the next single unit.
- **Cost For** (`count: int`) - The total price to buy `count` more units right now.
- **Max Affordable** (`budget: float`) - How many units `budget` can buy.
- **Cost To Buy Max** (`budget: float`) - The exact total spent if you Buy Max with `budget`.
- **Output Per Second** - Current production per second (owned * base_output * multiplier; in cycle mode, the lump divided by cycle time).
- **Production Over** (`seconds: float`) - How much is produced over `seconds` at the current rate - pass delta to credit each frame.
- **Pending** - Cycle mode: output banked and waiting for Collect.
- **Cycle Progress** - Cycle mode: how full the current cycle is, 0 to 1 (0 in continuous mode).
- **Last Cost** - What the last Buy cost - Spend this from your wallet.
- **Last Bought** - How many units the last Buy added (0 if Buy Max could not afford any).
- **Last Collected** - How much the last Collect handed you.

### InteractionBehavior (`res://eventsheet_addons/interaction/interaction_behavior.gd`)
@ace_tags(interaction, focus, prompt) @ace_category("Interaction") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Focus Changed** (`node: Node`)
- **On Interacted** (`node: Node`)

#### Conditions
- **Has Focus** - True while something interactable is in focus - the condition that shows and hides your "Press E" prompt.

#### Actions
- **Focus Nearest Interactable** (`group_name: String, within: float`) - Focuses the nearest node in the given group that is within reach (in pixels), or nothing at all when none are. Run this under a per-frame trigger (On Every Tick) - it re-picks every tick, but On Focus Changed only fires when the focused node actually changes, including when it becomes nothing.
- **Interact With Focus** - Interacts with the focused node: if it has a function named interact(), that function is called. On Interacted fires either way, so a thing with no interact() of its own can still be handled entirely from a sheet.
- **Clear Focus** - Drops the current focus (firing On Focus Changed with nothing) - for cutscenes, menus, and death, where the prompt should disappear even though the player has not moved.

#### Expressions
- **Focused Node** - The node currently in focus, or nothing when none is. Feed it to the Juice pack's Start Blinking to highlight it, or read a name off it for the prompt text.

### JuiceBehavior (`res://eventsheet_addons/juice/juice_behavior.gd`)
@ace_tags(camera, juice) @ace_category("Juice") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Shake Stopped**
- **On Zoom Finished**
- **On Squash Finished**
- **On Slowmo Finished**
- **On Hitstop Finished**
- **On Tilt Finished**
- **On Flash Finished**
- **On Punch Finished**
- **On Ticker Finished** (`ticker_name: String`)

#### Conditions
- **Is Shaking**
- **Is Hitstopped**

#### Actions
- **Shake** (`strength: float`) - Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit.
- **Stop Shake** - Cancels any shake immediately (the camera returns to rest unless another effect - recoil, bob, jitter, tilt - is still holding it).
- **Use Camera** (`camera_path: NodePath`) - Pin the effects to a specific Camera2D (by path). Leave it unused to auto-target whichever camera is active.
- **Recoil** (`angle_degrees: float, strength: float`) - Kicks the camera a distance (pixels) in a direction (degrees: -90 = up, 0 = right) and springs it back at the Recoil Recovery rate. Fire on every shot - kicks stack, so rapid fire climbs. Composes with Shake/Bob/Jitter.
- **Start Head Bob** (`amplitude: float, frequency: float`) - Starts a walking head-bob on the camera: a figure-8 sway (side at half rate, one vertical dip per step). Amplitude is pixels, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.
- **Stop Head Bob** - Stops the head bob (the camera returns to rest once every other effect settles too).
- **Start Jitter** (`amount: float`) - Starts a continuous nervous wobble on the camera (pixels) that runs until Stop Jitter - unlike Shake it never decays. Great for engines idling, drunk vision, earthquakes building, low-health unease.
- **Stop Jitter** - Stops the jitter wobble.
- **Tilt To** (`degrees: float, duration: float`) - Eases the camera roll to an angle (degrees) and HOLDS it - lean into a drift, a hill, or a dramatic dutch angle. Tilt back to 0 to level out. Emits On Tilt Finished.
- **Zoom By Percent** (`percent: float, duration: float`) - Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs.
- **Zoom To Position** (`world_position: Vector2, percent: float, duration: float`) - Zooms in while gliding the camera so a world position becomes the screen CENTRE - frame a spot in one action.
- **Zoom Toward Point** (`world_position: Vector2, percent: float, duration: float`) - Zooms while keeping a world position pinned under the same screen spot (mouse-wheel-to-cursor style) - great for strategy/map zoom.
- **Squash & Stretch** (`stretch: float, duration: float`) - Pops the host (Node2D or Control) with a volume-preserving stretch that springs back elastically. Positive = stretch tall (a jump), negative = squash wide (a landing).
- **Spring Squash** (`stretch: float`) - Pops the host (Node2D or Control) with a volume-preserving stretch that springs back via a real spring (the stiffness/damping knobs) - bouncier + more organic than the tween Squash & Stretch. Positive = stretch tall (a jump), negative = squash wide (a landing).
- **Slowmo** (`target_scale: float, hold_duration: float, duration_clock: String`) - Briefly slows Engine.time_scale to the target, HOLDS for a duration, then eases back to normal. Fade curves are Inspector knobs; pick whether the hold counts in realtime or scaled game time. Emits On Slowmo Finished.
- **Clear Slowmo** - Cancels any slowmo and snaps Engine.time_scale back to 1.0 immediately (call on scene exit if a slowmo might still be running).
- **Hitstop** (`freeze_duration: float, freeze_scale: float`) - The punchy hit-pause you feel on a connecting blow: freezes Engine.time_scale (0 = full stop) for a few frames, then snaps back to what it was. Uses a realtime timer so it un-freezes even at a full stop, ignores repeat hits already mid-freeze, pauses any active Slowmo for the duration, and emits On Hitstop Finished. Fire it the instant a hit lands.
- **Flash** (`color: Color, seconds: float`) - Pops the host to a solid color, then fades back to how it looked (tints included) - THE damage-hit read. Fire with Hitstop + Shake for a complete hit-confirm. Emits On Flash Finished.
- **Start Blinking** (`times_per_second: float, min_alpha: float`) - Strobes the host's opacity (full / faint) - the invulnerability-frames look, a low-health warning, an interactable highlight. Runs until Stop Blinking.
- **Stop Blinking** - Stops the blink and restores the host's opacity.
- **Punch Scale** (`strength: float, duration: float`) - Kicks the host's scale up (or down, negative) and springs it back elastically - button pops, pickups, flinches, beat pulses. Composes with Flash + Hitstop for melee hits. Emits On Punch Finished.
- **Punch Rotation** (`degrees: float, duration: float`) - Kicks the host's rotation by an angle (degrees) and springs it back elastically - wobbling signs, chest-opening jolts, portrait reactions. Emits On Punch Finished.
- **Punch Position** (`offset: Vector2, duration: float`) - Kicks the host's position by an offset (pixels) and springs it back elastically - knockback reads, UI nudges, impact shoves away from an attacker. Emits On Punch Finished.
- **Kick Camera Away From Point** (`world_position: Vector2, strength: float`) - Kicks the camera AWAY from a world position (an explosion, a hit source) and springs back - Recoil's directional sibling when you know the cause's location, so the kick always reads as pushback. Composes with Shake.
- **Start Ghost Trail** (`stamps_per_second: float, fade_seconds: float, tint: Color`) - Starts stamping fading afterimages of the host's sprite behind it - dashes, teleports, speed power-ups, bullet-time evades. Works on a Sprite2D/AnimatedSprite2D host or the host's first Sprite2D child. Runs until Stop Ghost Trail.
- **Stop Ghost Trail** - Stops stamping afterimages (the ones already out finish fading on their own).
- **Pulse Vignette** (`strength: float, color: Color, seconds: float`) - Darkens the screen edges to a color at a strength (0..1), then fades back out - taking damage, a near miss, holding your breath. Composes with Slowmo + Fade Screen Tint for last-stand moments.
- **Chromatic Kick** (`strength: float, seconds: float`) - Splits the screen's color channels for an instant and settles back - the AAA impact frame. Fire with Shake + Hitstop on explosions and heavy hits.
- **Set Speed Lines** (`intensity: float`) - Radial anime-style speed streaks at an intensity (0..1) that HOLD until you set 0 - sprints, dashes, adrenaline modes. Pair with Zoom By Percent or FOV punches for full sprint feel.
- **Play Sound Varied** (`path: String, pitch_jitter: float, volume_jitter_db: float`) - Plays a sound with a random pitch and volume wobble around the base - the #1 trick against repetitive footsteps, hits, coins, and clicks. Fire-and-forget (the player frees itself).
- **Play Sound With Intensity** (`path: String, intensity: float`) - Plays a sound scaled by an intensity (0..1): quiet + lower-pitched when light, full + brighter when heavy - drive it, Shake, and Punch Scale from ONE hit-power value so light and heavy hits differ by one number.
- **Count To** (`ticker_name: String, target: float, duration: float`) - Eases a named display value toward a target over a duration - scores and gold ROLL instead of snapping. Read it with the Ticker Value expression; emits On Ticker Finished (with the name) when it lands.
- **Set Ticker** (`ticker_name: String, value: float`) - Sets a named display value INSTANTLY (cancelling any roll) - initialise a score at 0, or snap on a reset.
- **Set Host Tint** (`color: Color, strength: float`) - Tints the HOST object: blends its color toward the tint by Strength (0 = its own colors untouched, 1 = fully the tint color) - the classic object tint, with the strength as your opacity dial. Children inherit (modulate).
- **Clear Host Tint** - Removes the host tint (back to its own colors).
- **Set Screen Tint** (`color: Color, strength: float`) - Washes the WHOLE SCREEN with a color at Strength opacity (0..1) - damage red, poison green, night blue, flashback sepia. Call again to retune; strength 0 clears.
- **Fade Screen Tint** (`seconds: float`) - Fades the screen tint's strength to zero over the given seconds - the damage-flash pattern: Set Screen Tint red 0.4, then Fade Screen Tint 0.3.
- **Clear Screen Tint** - Removes the screen tint instantly.

#### Expressions
- **Trauma**
- **Ticker Value** (`ticker_name: String`) - What a ticker currently SHOWS - the eased value Count To is rolling toward its target. Print or draw this instead of the real variable and scores roll instead of snapping.

### Juice3DBehavior (`res://eventsheet_addons/juice_3d/juice_3d_behavior.gd`)
@ace_tags(camera, juice, 3d) @ace_category("Juice 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Punch Finished**
- **On Ticker Finished** (`ticker_name: String`)
- **On Shake Stopped**
- **On Lean Finished**
- **On Zoom Finished**

#### Conditions
- **Is Shaking**

#### Actions
- **Shake** (`strength: float`) - Adds screenshake to the active 3D camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit or explosion.
- **Stop Shake** - Cancels any shake immediately (other effects keep running).
- **Recoil** (`vertical_kick: float, horizontal_spread: float`) - Weapon recoil: kicks the view UP by a pitch (degrees) plus a random side spread, then re-centres at the Recoil Recovery rate. Fire on every shot - kicks stack, so sustained fire climbs. Cosmetic (rides on top of mouse look; aim is untouched).
- **Start Head Bob** (`amplitude: float, frequency: float`) - Starts a walking head-bob on the camera: a figure-8 (side sway at half rate, one downward dip per step). Amplitude is metres, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.
- **Stop Head Bob** - Stops the head bob.
- **Start Jitter** (`position_amount: float, roll_degrees: float`) - Starts a continuous nervous wobble (position in metres + a touch of roll) that runs until Stop Jitter - unlike Shake it never decays. Engines idling, helicopters, low health, fear.
- **Stop Jitter** - Stops the jitter wobble.
- **Lean** (`degrees: float, duration: float`) - Eases the camera roll to an angle (degrees) and HOLDS it - lean into a wall ride, peek a corner, bank with a turn. Lean back to 0 to level out. Emits On Lean Finished.
- **FOV Punch** (`amount: float`) - Kicks the field of view wider (positive, a speed boost / dash) or tighter (negative, an impact) by an amount in degrees, then eases back at the FOV Recovery rate. Fire-and-forget.
- **Zoom FOV To** (`fov: float, duration: float`) - Smoothly changes the camera's base field of view to a value in degrees and keeps it there (an aim-down-sights zoom is FOV 40, back to 75 to unzoom). Emits On Zoom Finished.
- **Use Camera** (`camera_path: NodePath`) - Pin the effects to a specific Camera3D (by path). Leave it unused to auto-target whichever camera is active.
- **Kick Camera Away From Point** (`world_position: Vector3, strength: float`) - Shoves the camera AWAY from a world position (an explosion, a hit source) and re-centres at the Kick Recovery rate - Recoil's directional sibling when you know the cause's location. Cosmetic (additive; aim untouched). Composes with Shake.
- **Start Blinking** (`times_per_second: float`) - Strobes the host's visibility - invulnerability frames, respawn grace, a targeted highlight. Runs until Stop Blinking.
- **Stop Blinking** - Stops the blink and makes the host visible again.
- **Punch Scale** (`strength: float, duration: float`) - Kicks the host's scale up (or down, negative) and springs it back elastically - pickups, flinches, beat pulses. Emits On Punch Finished.
- **Punch Position** (`offset: Vector3, duration: float`) - Kicks the host's position by an offset (metres) and springs it back elastically - knockback reads, impact shoves away from an attacker. Emits On Punch Finished.
- **Pulse Vignette** (`strength: float, color: Color, seconds: float`) - Darkens the screen edges to a color at a strength (0..1), then fades back out - taking damage, a near miss, holding your breath. Composes with Fade Screen Tint for last-stand moments.
- **Chromatic Kick** (`strength: float, seconds: float`) - Splits the screen's color channels for an instant and settles back - the AAA impact frame. Fire with Shake on explosions and heavy hits.
- **Set Speed Lines** (`intensity: float`) - Radial anime-style speed streaks at an intensity (0..1) that HOLD until you set 0 - sprints, dashes, adrenaline modes. Pair with FOV Punch for full sprint feel.
- **Play Sound Varied** (`path: String, pitch_jitter: float, volume_jitter_db: float`) - Plays a sound with a random pitch and volume wobble around the base - the #1 trick against repetitive footsteps, hits, and shots. Fire-and-forget (the player frees itself).
- **Play Sound With Intensity** (`path: String, intensity: float`) - Plays a sound scaled by an intensity (0..1): quiet + lower-pitched when light, full + brighter when heavy - drive it, Shake, and Punch Scale from ONE hit-power value so light and heavy hits differ by one number.
- **Count To** (`ticker_name: String, target: float, duration: float`) - Eases a named display value toward a target over a duration - scores and gold ROLL instead of snapping. Read it with the Ticker Value expression; emits On Ticker Finished (with the name) when it lands.
- **Set Ticker** (`ticker_name: String, value: float`) - Sets a named display value INSTANTLY (cancelling any roll) - initialise a score at 0, or snap on a reset.
- **Set Screen Tint** (`color: Color, strength: float`) - Washes the WHOLE SCREEN with a color at Strength opacity (0..1) over the 3D view - damage red, poison green, night blue. Call again to retune; strength 0 clears.
- **Fade Screen Tint** (`seconds: float`) - Fades the screen tint's strength to zero over the given seconds - the damage-flash pattern: Set Screen Tint red 0.4, then Fade Screen Tint 0.3.
- **Clear Screen Tint** - Removes the screen tint instantly.

#### Expressions
- **Ticker Value** (`ticker_name: String`) - What a ticker currently SHOWS - the eased value Count To is rolling toward its target. Print or draw this instead of the real variable and scores roll instead of snapping.
- **Trauma**

### LOSBehavior (`res://eventsheet_addons/line_of_sight/line_of_sight_behavior.gd`)
@ace_category("Line Of Sight") @ace_expose_all(node) @ace_version(1.0.0)

#### Conditions
- **Has Line Of Sight To** (`point: Vector2`)
- **Has LOS Between** (`from_point: Vector2, to_point: Vector2`)

#### Expressions
- **Nearest Visible In Group** (`group: String`)

### LOS3DBehavior (`res://eventsheet_addons/line_of_sight_3d/line_of_sight_3d_behavior.gd`)
@ace_category("Line Of Sight 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Conditions
- **Has Line Of Sight To** (`point: Vector3`)
- **Has LOS Between** (`from_point: Vector3, to_point: Vector3`)

#### Expressions
- **Nearest Visible In Group** (`group: String`)

### LootBoxAddon (`res://eventsheet_addons/loot_table/loot_table_addon.gd`)
@ace_tags(loot, random) @ace_category("Loot") @ace_version(1.0.0)

#### Triggers
- **On Roll Result**
- **On Roll Complete**
- **On Pity Triggered**

#### Conditions
- **Has Table** (`table_id: String`) - Whether a table with this id is registered.
- **Entry Has Tag** (`table_id: String, tag: String`) - Whether any entry in a table carries the given tag.

#### Actions
- **Create Table** (`table_id: String`) - Starts a fresh, empty loot table with this id (replaces any existing one).
- **Add Entry** (`table_id: String, item_id: String, weight: float`) - Adds an item to a table with a relative weight (higher = likelier). Quantity 1, no tags.
- **Add Rare Entry** (`table_id: String, item_id: String, weight: float, quantity: float, tags: String`) - Adds an item with a weight, a quantity, and comma-separated tags (tags drive guarantees + pity).
- **Add Table Reference** (`table_id: String, sub_table_id: String, weight: float`) - Adds an entry that rolls ANOTHER table inline when picked (shared common-loot pools). Depth-limited.
- **Set Guarantee** (`table_id: String, tag: String, minimum: int`) - Guarantees at least `minimum` drops carrying this tag in every multi-roll batch.
- **Set Pity** (`table_id: String, tag: String, threshold: int`) - Hard pity: after `threshold` rolls in a row WITHOUT a tagged drop, the next roll GUARANTEES one (and fires On Pity Triggered).
- **Reset Pity** (`table_id: String, tag: String`) - Zeroes a tag's pity counter for a table.
- **Set Seed** (`seed_value: int`) - Makes rolls repeatable from a fixed seed (same seed = same sequence). Pass 0 to go back to random.
- **Use Advanced Random** (`enabled: bool`) - When on, rolls draw from the shared AdvancedRandom autoload instead of this pack's own generator, so one seed drives your whole game's randomness. When off (the default) it uses its own seed. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).
- **Load From Resource** (`loot_table: Resource`) - Loads a whole table from a Loot Table resource (a .tres you filled in the Inspector) - its name, entries, and pity - in one step. The data-driven alternative to Create Table plus a string of Add Entry actions.
- **Roll** (`table_id: String`) - Rolls the table once, firing On Roll Result then On Roll Complete.
- **Roll Times** (`table_id: String, count: int`) - Rolls the table `count` times in one batch (guarantees + pity apply across the batch), then shuffles.

#### Expressions
- **Table Count** - How many tables are registered.
- **Entry Count** (`table_id: String`) - How many entries a table has.
- **Pity Count** (`table_id: String, tag: String`) - The current miss streak for a table's tag.
- **Roll Table** - The table that was rolled (inside On Roll Result / Complete).
- **Roll Item** - The item id that dropped (inside On Roll Result).
- **Roll Quantity** - The quantity of the dropped item (inside On Roll Result).
- **Roll Tags** - Comma-separated tags of the dropped item (inside On Roll Result).
- **Roll Index** - The 0-based position of this drop in the batch (inside On Roll Result).
- **Total Rolls** - How many items dropped in the last batch (inside On Roll Complete).
- **Last Seed** - The seed used for the last roll (store it to replay the exact drop).
- **Pity Table** - The table whose pity fired (inside On Pity Triggered).
- **Pity Tag** - The tag whose pity fired (inside On Pity Triggered).
- **Pity Count At Trigger** - The miss streak when pity fired (inside On Pity Triggered).

### MilestonesAddon (`res://eventsheet_addons/milestones/milestones_addon.gd`)
@ace_tags(incremental, idle, achievement) @ace_category("Milestones") @ace_version(1.0.0)

#### Triggers
- **On Milestone Reached**

#### Conditions
- **Is Reached** (`id: String`) - Whether a milestone has been reached.

#### Actions
- **Define Milestone** (`id: String, threshold: float, reward: float`) - Creates (or resets) a milestone: the threshold to cross and the reward it grants once reached.
- **Set Threshold** (`id: String, threshold: float`) - Changes a milestone's threshold (does not un-reach it if already reached).
- **Update Progress** (`id: String, value: float`) - Reports the current value of the tracked number. The first time it reaches the threshold the milestone latches and On Milestone Reached fires (read Last Reached / Reward there).
- **Force Reach** (`id: String`) - Marks a milestone reached immediately (for a load) - fires On Milestone Reached if it was not already reached.
- **Reset** - Un-reaches every milestone and zeroes progress (keeps the definitions).

#### Expressions
- **Progress** (`id: String`) - How close a milestone is, 0 to 1 (for a progress bar).
- **Threshold** (`id: String`) - A milestone's threshold value.
- **Reward** (`id: String`) - A milestone's reward value.
- **Reached Count** - How many milestones have been reached.
- **Milestone Count** - How many milestones are defined.
- **Total Reward** - The sum of the rewards of every reached milestone - fold this into your production multiplier.
- **Last Reached** - The id of the milestone that just latched (read inside On Milestone Reached).
- **Nearest Unreached** - The id of the unreached milestone closest to its threshold (for a "next goal" display); "" if all reached.

### MoveToBehavior (`res://eventsheet_addons/move_to/move_to_behavior.gd`)
@ace_category("Move To") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Arrived**
- **On Path Blocked**

#### Actions
- **Move To Position** (`x: float, y: float`) - Replaces the queue and glides toward the point.
- **Add Waypoint** (`x: float, y: float`) - Appends a stop to the queue (waypoints).
- **Stop Moving** - Clears the queue without firing On Arrived.

### MoveTo3DBehavior (`res://eventsheet_addons/move_to_3d/move_to_3d_behavior.gd`)
@ace_category("Move To 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Arrived (3D)**
- **On Path Blocked (3D)**

#### Actions
- **Move To Position (3D)** (`x: float, y: float, z: float`) - Replaces the queue and glides toward the point.
- **Add Waypoint (3D)** (`x: float, y: float, z: float`) - Appends a stop to the queue.
- **Stop Moving (3D)** - Clears the queue without firing On Arrived.

### NamedScenesPackAddon (`res://eventsheet_addons/named_scenes/named_scenes_addon.gd`)
@ace_tags(scenes, navigation, levels) @ace_category("Scenes") @ace_version(1.0.0)

#### Triggers
- **On Scene Ready** (`scene_name: String`)

#### Conditions
- **Current Scene Is** (`scene_name: String = "hub"`) - Whether the named scene is the one running right now. It answers on the name last announced ready, so it keeps working for a scene you loaded by hand as long as Announce Scene Ready was called.
- **Scene Is Registered** (`scene_name: String = "arena"`) - Whether a name has a scene behind it. Ask before Go To Named Scene when the name comes from data (a level list, a save file) rather than from a row you typed.
- **Named Scene Is Preloaded** (`scene_name: String = "arena"`) - Whether Preload Named Scene has already warmed this scene. Show the Continue button when it has, a spinner while it has not.
- **Has Scene Argument** (`key: String = "door"`) - Whether the scene you are in was handed a value under this key. Lets a level tell "came in by a door" apart from "started here from the menu" without a magic default.

#### Actions
- **Register Scene** (`scene_name: String = "arena", scene_path: String = ""`) - Gives a scene file a short name every row can use instead of its path. Registering the same name again replaces the path, so a boot sheet can safely re-run. Do this once at startup, in a sheet every scene reaches.
- **Register Scenes In Folder** (`folder: String = "res://levels"`) - Registers every .tscn directly inside a folder under its own file name, so res://levels/arena.tscn becomes "arena". The folder IS the level list: add a scene to it and the game knows about it with no row to edit. Sub-folders are left alone.
- **Forget Named Scene** (`scene_name: String = "arena"`) - Removes one name from the registry and drops anything Preload Named Scene had warmed for it. Use it when a level is unlocked or retired at runtime; rows that still name it will warn instead of changing scene.
- **Go To Named Scene** (`scene_name: String = "arena"`) - Changes to the scene registered under this name. Nothing happens (with a warning) if the name was never registered, or if the file behind it can no longer be opened, so neither a typo nor a moved .tscn can leave the game on a black screen. On Scene Ready fires with the name only once the new scene is really the one running.
- **Preload Named Scene** (`scene_name: String = "arena"`) - Loads a registered scene into memory now, without changing to it, so the change is instant when it comes. Warm the next level while the player is reading a hint or watching a door open. Loading it twice does no extra work.
- **Carry Into Next Scene** (`payload: Dictionary = {}`) - Hands a record to the scene you are about to open: a spawn door, a difficulty, who sent you. It belongs to the NEXT scene, so the one you are leaving still reads its own arguments until the change lands.
- **Announce Scene Ready** (`scene_name: String = "arena"`) - Marks a named scene as the one now running: the carried record becomes readable through Scene Argument, Current Scene Is starts answering this name, and On Scene Ready fires with it. Go To Named Scene calls this for you once the new scene exists - call it yourself only when you changed scene some other way.

#### Expressions
- **Scene Argument** (`key: String = "door", fallback: String = ""`) - A value the previous scene carried over, as text - the door you came in by, who sent you. Answers the fallback when nothing was carried under that key.
- **Scene Argument Number** (`key: String = "attempt", fallback: float = 0.0`) - A carried value as a number - an attempt count, a difficulty, a starting score. Answers the fallback when nothing was carried under that key.
- **Path Of Named Scene** (`scene_name: String = "arena"`) - The res:// path registered under a name, or "" when the name is unknown. The escape hatch for a verb that still wants a path, e.g. the Scene Flow pack's Fade To Scene.
- **Current Scene Name** - The name of the scene running right now, or "" before the first one was announced. Stabler than a path: save it, show it in a debug corner, key a music track off it.
- **Registered Scene Names** - Every registered name, sorted. A level-select screen builds itself from this instead of from a list somebody has to keep in step.

### NavAgent3D (`res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd`)
@ace_tags(movement, 3d, ai, pathfinding) @ace_category("Nav Agent 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Path Found**
- **On Path Failed**
- **On Path Complete**
- **On Waypoint Reached**

#### Conditions
- **Has Path**
- **Target Is Reachable**

#### Actions
- **Find Path To** (`x: float, y: float, z: float, mode: String`) - Routes to a world position across the baked navmesh and starts moving. Mode "reach" fails (On Path Failed) when the spot is off the mesh; "nearest" never fails - the agent goes to the closest point on the mesh instead. Fires On Path Found / On Path Failed.
- **Find Path To Node** (`target: Node, mode: String`) - Routes to another node's position (the player, a beacon) - Find Path To with the position read for you. Re-call on a timer to chase.
- **Stop Pathfinding** - Clears the path and hands the driver sibling back to the player (ai_controlled off).
- **Set Auto Control** (`enabled: bool`) - On (default): drive the sibling controller or the body. Off: paths still compute - read Path Move X/Z and Current Waypoint X/Y/Z and drive anything you like.
- **Set Avoidance** (`enabled: bool`) - Agents steer around each other (RVO avoidance). Applies to the built-in driver; a driver sibling owns its own velocity.
- **Set Move Speed** (`value: float`) - Changes the built-in driver's speed (m/s).
- **Bake Navigation Region** (`region: Node`) - Rebakes a NavigationRegion3D's navmesh from its current child geometry, at runtime - call it on ready (or after the level changes) and every agent sees the walkable world. Slopes come free: the bake's max-angle setting decides what is walkable.

#### Expressions
- **Current Waypoint X**
- **Current Waypoint Y**
- **Current Waypoint Z**
- **Distance To Target**
- **Path Move X**
- **Path Move Z**

### ObjectPoolAddon (`res://eventsheet_addons/object_pool/object_pool_addon.gd`)
@ace_tags(performance, spawning) @ace_category("Object Pool") @ace_version(1.0.0)

#### Triggers
- **On Spawned**
- **On Despawned**

#### Conditions
- **Has Pool** (`pool_name: String`) - Whether a pool with this name exists.

#### Actions
- **Create Pool** (`pool_name: String, scene_path: String, prewarm: int`) - The easy way: makes a pool that spawns copies of a scene (a .tscn path), optionally pre-making some now so the first spawns never hitch.
- **Create Empty Pool** (`pool_name: String`) - The custom way: makes a pool with no scene of its own. Fill it with Add To Pool (your own nodes), and Spawn hands those back out.
- **Add To Pool** (`pool_name: String, node: Node`) - Puts one of your own existing nodes into a pool as a ready-to-reuse instance (for custom pools). The node is hidden and parked until spawned.
- **Prewarm** (`pool_name: String, count: int`) - Pre-makes more copies for a scene pool (so a burst of spawns stays smooth).
- **Despawn** (`node: Node`) - Hands a spawned node back to its pool to be reused (hides it and stops its processing) instead of freeing it. Fires On Despawned.
- **Despawn All** (`pool_name: String`) - Hands every active node of a pool back at once (for a level reset).
- **Clear Pool** (`pool_name: String`) - Frees (deletes) every node in a pool and removes the pool. Use it when the pool is truly done.

#### Expressions
- **Spawn** (`pool_name: String`) - Hands out a ready node from a pool (reusing a free one, or making a new copy from the pool's scene) - added to the current scene, shown, and returned so you can position it. Fires On Spawned. Returns nothing if the pool is empty and has no scene.
- **Last Spawned** - The node most recently spawned (handy inside On Spawned).
- **Last Despawned** - The node most recently despawned (handy inside On Despawned).
- **Free Count** (`pool_name: String`) - How many ready (unused) nodes a pool holds.
- **Active Count** (`pool_name: String`) - How many of a pool's nodes are currently spawned and in use.
- **Pool Size** (`pool_name: String`) - A pool's total nodes (free plus active).

### OrbitBehavior (`res://eventsheet_addons/orbit/orbit_behavior.gd`)
@ace_category("Orbit") @ace_expose_all(node) @ace_version(1.0.0)

#### Actions
- **Set Orbit Center** (`x: float, y: float`) - Orbits around the given point from now on.
- **Set Orbit Speed** (`degrees_per_second: float`) - Degrees per second (negative reverses).
- **Set Orbit Radii** (`primary: float, secondary: float`) - Primary/secondary radii (secondary 0 = circle).

### Orbit3DBehavior (`res://eventsheet_addons/orbit_3d/orbit_3d_behavior.gd`)
@ace_category("Orbit 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Actions
- **Set Orbit 3D Center** (`x: float, y: float, z: float`) - Orbits around the given point from now on.

### PhaseCycleAddon (`res://eventsheet_addons/phase_cycle/phase_cycle_addon.gd`)
@ace_tags(time, day-night, cycle) @ace_category("Phase Cycle") @ace_version(1.0.0)

#### Triggers
- **On Phase Changed** (`previous: String, next: String`)

#### Conditions
- **Phase Is** (`phase_name: String`) - True while the cycle is on the named phase - the branch for "only spawn ghosts at night". Names are matched exactly, so keep the spelling identical to the list you passed Cycle Phases.

#### Actions
- **Cycle Phases** (`phases: String, seconds_each: float`) - Starts (or restarts) the cycle from a comma-separated list of phase names - "day,night" or "spring,summer,autumn,winter" - with each phase lasting seconds_each. Begins on the first name and fires On Phase Changed for it right away, so the systems listening set themselves up correctly on the first frame.
- **Stop Cycle** - Freezes the cycle where it stands. The current phase and its progress keep their values (Phase Is and Phase Progress still read them) - only the clock stops. Call Cycle Phases again to start over.

#### Expressions
- **Current Phase** - The name of the phase the cycle is on right now (nothing at all before Cycle Phases runs) - print it straight into a HUD label.
- **Phase Progress** - How far through the current phase the cycle is, from 0 at its start to 1 at its end. Feed it to a sun dial's rotation, a light's colour blend, or a Progress Of style bar.
- **Phases Count** - How many phases the cycle holds - useful for a "day 3 of 4" readout or for stepping a dial in even slices.

### PhysicsCar (`res://eventsheet_addons/physics_car/physics_car_behavior.gd`)
@ace_tags(vehicle, physics) @ace_category("Physics Car") @ace_version(1.0.0)

#### Triggers
- **On Collided**
- **On Drift Started**
- **On Drift Ended**
- **On Drive Target Reached**

#### Conditions
- **Is Moving** - Whether the car is above a small movement speed.
- **Is Reversing** - Whether the car is moving backwards.
- **Is Drifting** - Whether the slip angle is past the drift threshold.
- **Is Handbrake Active** - Whether the handbrake was requested this physics frame.
- **Is At Max Speed** - Whether the car has hit its forward speed cap.
- **Has Reached Drive Target** - Whether the last Drive Toward Position target has been reached.
- **Has Surface Override** - Whether a terrain grip or resistance multiplier is currently in effect.
- **Is Driving Toward Angle** - Whether the car is in Drive Toward Angle mode.
- **Is Driving Toward Position** - Whether the car is in Drive Toward Position mode.

#### Actions
- **Set Throttle** (`amount: float`) - Sets the throttle from -1 (full reverse) to 1 (full forward). Persists until you change it or call Stop.
- **Set Brake** (`amount: float`) - Sets the brake from 0 (off) to 1 (full). Braking slows the car without reversing it.
- **Set Steer** (`amount: float`) - Sets the steering from -1 (full left) to 1 (full right). Persists until you change it or call Stop.
- **Simulate Control** (`direction: String`) - The keyboard-style control: pass "up" / "down" / "left" / "right" while the key is held, or "stop" to release. Call it every frame the key is down (pair with Stop when no key is down).
- **Stop** - Clears throttle, brake, and steer, and exits any Drive Toward mode. The car coasts to rest.
- **Enable Handbrake** - Cuts the grip for this one physics frame, so the back end slides. Call it every frame you want the handbrake held.
- **Drive Toward Angle** (`target_angle: float, throttle_amount: float, max_steer: float, tolerance: float`) - Auto-steers toward a heading (degrees) and applies throttle. Call it each frame; the car turns until it faces within the tolerance. Sets the Is Driving Toward Angle mode.
- **Drive Toward Position** (`x: float, y: float, throttle_amount: float, max_steer: float, tolerance: float`) - Auto-steers toward a world position and applies throttle. Call it each frame (for example toward a waypoint). Fires On Drive Target Reached inside the reach distance. Sets the Is Driving Toward Position mode.
- **Teleport** (`x: float, y: float`) - Moves the car to a position and clears its velocity and spin (for respawns and resets).
- **Set Max Speed** (`value: float`) - Changes the top forward speed at runtime (for boosts or speed caps).
- **Set Grip** (`value: float`) - Changes the base sideways grip at runtime (1 = glued, 0 = ice).
- **Set Surface Grip** (`multiplier: float`) - Sets a terrain grip multiplier on top of the base grip (for example 0.2 on ice, 0.45 in mud). 1 = no change.
- **Set Surface Resistance** (`multiplier: float`) - Sets a terrain drag multiplier (above 1 = sticky mud that slows you, below 1 = slick). 1 = no change.
- **Reset Surface** - Restores both terrain multipliers to 1 (call it when the car leaves a terrain zone).
- **Set Reach Distance** (`distance: float`) - Sets how close (pixels) a Drive Toward target must be to fire On Drive Target Reached.

#### Expressions
- **Speed** - Current speed, in pixels per second.
- **Forward Speed** - Speed along the way the car faces (negative when reversing).
- **Lateral Speed** - Sideways slide speed (the part grip fights).
- **Angle Of Motion** - The direction the car is actually moving, in degrees.
- **Slip Angle** - Degrees between where the car points and where it moves.
- **Drift Duration** - Seconds the current drift has lasted (or the final length inside On Drift Ended).
- **Throttle Input** - The current throttle value (-1 to 1).
- **Brake Input** - The current brake value (0 to 1).
- **Steer Input** - The current steer value (-1 to 1).
- **Heading Error** - Signed degrees a Drive Toward action still needs to turn.
- **Drive Target Distance** - Distance to the current Drive Toward Position target (0 if none).
- **Effective Grip** - The final grip after handbrake and terrain multipliers.
- **Surface Grip Multiplier** - The active terrain grip multiplier.
- **Surface Resistance Multiplier** - The active terrain drag multiplier.
- **Collision Force** - Approximate impact speed of the latest collision (inside On Collided).
- **Collision Angle** - Approximate impact direction in degrees (inside On Collided).

### PlatformInfoAddon (`res://eventsheet_addons/platform_info/platform_info_addon.gd`)
@ace_tags(platform, device, screen, system) @ace_category("Platform Info") @ace_version(1.0.0)

#### Conditions
- **Is On Mobile** - True on Android and iOS builds - the switch-to-touch-controls condition.
- **Is On Desktop** - True on Windows, macOS, and Linux builds.
- **Is On Web** - True in browser (HTML5) exports - hide quit buttons, mind autoplay rules.
- **Has Touchscreen** - True when a touchscreen is available (mobile, or a touch laptop).
- **Is Portrait** - True while the window is taller than it is wide - branch layouts on rotation.
- **Is Debug Build** - True in editor runs and debug exports - gate cheats and dev overlays.
- **Has Feature Tag** (`feature: String`) - True when the build has a feature tag - engine ones ("mobile", "web", "editor") or your own custom export tags ("demo", "steam").

#### Expressions
- **OS Name** - The operating system: "Windows", "macOS", "Linux", "Android", "iOS", "Web".
- **OS Version** - The operating system's version string.
- **Device Model** - The device model name (phones report their model; desktops report "GenericDevice").
- **Locale** - The player's full locale, like "en_US" - default your language picker to it.
- **Locale Language** - Just the language part of the locale, like "en" or "ja".
- **Engine Version** - The Godot version string, like "4.7.stable".
- **Screen Width** - The current screen's width in pixels (the whole display, not the window).
- **Screen Height** - The current screen's height in pixels.
- **Screen DPI** - The screen's pixel density - scale touch buttons by it so they stay finger-sized.
- **Screen Refresh Rate** - The screen's refresh rate in Hz (-1 when unknown) - cap or uncap smoothing with it.
- **Screen Count** - How many displays are connected.
- **Screen Scale** - The display's scale factor (2.0 on hiDPI/Retina screens; 1.0 elsewhere).
- **Safe Area Top** - Pixels shaved off the screen's TOP by notches/status bars - pad your HUD down by it.
- **Safe Area Left** - Pixels shaved off the screen's LEFT edge by cutouts.
- **Safe Area Bottom Inset** - Pixels shaved off the BOTTOM (home indicators): screen height minus the safe area's end.
- **Safe Area Right Inset** - Pixels shaved off the RIGHT edge: screen width minus the safe area's end.
- **GPU Name** - The graphics adapter's name - match against known slow chips to pick a quality preset.
- **GPU Vendor** - The graphics adapter's vendor ("NVIDIA", "AMD", "Intel", "Apple"...).
- **Rendering Method** - Which renderer is live: "forward_plus", "mobile", or "gl_compatibility".
- **CPU Thread Count** - How many CPU threads the machine has - budget background work with it.
- **CPU Name** - The CPU's name string.
- **Physical Memory (MB)** - The machine's physical RAM in megabytes (0 where the OS hides it) - drop texture quality under a threshold.

### PlatformerMovement (`res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd`)
@ace_tags(movement, platformer) @ace_category("Platformer") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Jumped**
- **On Landed**
- **On Double Jumped**
- **On Wall Jumped**

#### Conditions
- **Is Moving**
- **Is Jumping**
- **Is Falling**
- **Is Wall Sliding**
- **Can Jump**

#### Actions
- **Jump** - Jumps: from the floor or within coyote time, off a wall (if enabled), or a mid-air (double) jump if any remain. If none are available right now, the press is buffered.
- **Jump Released** - Call when the jump button is released - cuts the rise short for variable jump height (hold = higher).
- **Set Gravity Angle** (`angle: float`) - Points gravity in a new direction, in degrees (90 = down, 270 = up, 0 = right) - the whole movement frame rotates with it: floor detection, running, and jumps follow. Flip a level upside down or run on walls with one action.
- **Set Move Speed** (`speed: float`) - Changes the horizontal move speed.
- **Reset Jumps** - Refills the air-jump count (e.g. after grabbing a power-up).

#### Expressions
- **Gravity Angle**
- **Jumps Remaining**
- **Air Time**
- **Facing Direction**

### PlatformerPathfinding (`res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd`)
@ace_tags(movement, platformer, ai, pathfinding) @ace_category("Platformer Pathfinding") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Portal Taken**
- **On Waypoint Stuck**
- **On Repath**
- **On Hazard Entered**
- **On Path Found**
- **On Path Failed**
- **On Path Complete**
- **On Waypoint Reached**
- **On Nav Graph Built**

#### Conditions
- **Is Path Pending**
- **Is In Hazard**
- **Has Path**
- **Path Wants Jump**

#### Actions
- **Build Nav Graph From Tilemap** (`tilemap: Node`) - Scans a TileMapLayer's physics tiles into the navigation graph: standable cells become nodes, adjacent cells (one step up or down - stairs and tile slopes) become WALK edges, and jump arcs / fall drops connect the rest, sized to the sibling PlatformerMovement's real jump. Call once on ready; Regenerate after level edits. Fires On Nav Graph Built.
- **Regenerate Nav Graph** - Rebuilds the graph from the same TileMapLayer (after runtime tile edits).
- **Find Path To** (`x: float, y: float, mode: String`) - Routes to a world position and starts moving. Mode "reach" fails (On Path Failed) when the spot itself is unreachable; "nearest" never fails - it goes to the closest reachable node instead. Fires On Path Found / On Path Failed.
- **Find Path To Node** (`target: Node, mode: String`) - Routes to another node's position AND keeps following it: the route auto-refreshes every Repath Interval once the node has moved Repath Threshold pixels (firing On Repath) - one call chases forever. Stop Pathfinding ends the follow.
- **Stop Pathfinding** - Clears the path and releases the movement pack back to the keyboard (ai_controlled off).
- **Set Auto Control** (`enabled: bool`) - On (default): the behavior drives the sibling PlatformerMovement. Off: paths still compute - read Path Move Axis / Path Wants Jump / Current Waypoint X/Y and drive anything you like.
- **Set Ledge Restriction** (`enabled: bool`) - Patrol discipline: on, routes may only WALK - no jumps, no portals, and no drops beyond Ledge Leniency, so the agent stays on its platform. Applies from the next Find Path To.
- **Set Ledge Leniency** (`pixels: float`) - With Ledge Restriction on, drops up to this many pixels are still allowed (a patroller may hop down one step but never off the tower).
- **Set Jump Positioning** (`mode: String`) - relaxed (default): leap the moment a jump leg starts. strict: walk onto the exact takeoff spot first - slower but precise on tight arcs.
- **Set Coyote Time** (`seconds: float`) - Grace window (s) for AI jumps just after running off the takeoff ledge.
- **Set Repath Interval** (`seconds: float`) - While following a node, how often the route may refresh (chase freshness vs cost).
- **Set Repath Threshold** (`pixels: float`) - The route only refreshes when the followed node has moved at least this many pixels.
- **Set Max Paths Per Tick** (`count: int`) - The SHARED budget across every agent: at most this many route computations per physics tick - extras defer a tick (Is Path Pending) instead of spiking the frame. The difference between 20 chasers working and not.
- **Add Portal** (`from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool`) - Links two world positions as a PORTAL: an agent whose route uses it walks to the entrance and blinks to the exit (fires On Portal Taken). Bidirectional works both ways. Portals join the graph immediately and survive Regenerate - doors, teleporters, ladders, and elevators all model as portals.
- **Clear Portals** - Removes every registered portal (takes effect on the next Regenerate Nav Graph).
- **Add Hazard** (`x: float, y: float, width: float, height: float, deadly: bool`) - Marks a world-space rectangle as hazardous. Deadly: routes NEVER pass through it (spikes, lava). Not deadly: routes pay 4x to cross, so it is taken only when no clean way exists (fire patches, slow mud). Applies to routing instantly - no rebuild - and On Hazard Entered fires if the agent ends up inside one anyway.
- **Clear Hazards** - Removes every hazard (routing sees the change immediately).
- **Add Moving Platform** (`platform: Node, from_x: float, from_y: float, to_x: float, to_y: float`) - Registers a moving platform (an AnimatableBody2D you animate) by its two travel endpoints: the graph gains a PLATFORM edge between them, and an agent routed across it walks to the track, WAITS for the platform, boards, rides, and walks off at the far side. Survives Regenerate. The pack never moves the platform - your sheet animates it between exactly these endpoints.
- **Clear Moving Platforms** - Unregisters every moving platform (takes effect on the next Regenerate Nav Graph).
- **Set Nav Debug Draw** (`enabled: bool`) - Draws the active path as a line in the world (great while tuning a level).

#### Expressions
- **Path Move Axis**
- **Waypoint Count**
- **Current Waypoint Index**
- **Current Waypoint X**
- **Current Waypoint Y**
- **Current Path Action**

### PrestigeAddon (`res://eventsheet_addons/prestige/prestige_addon.gd`)
@ace_tags(incremental, idle, prestige) @ace_category("Prestige") @ace_version(1.0.0)

#### Triggers
- **On Prestige**

#### Conditions
- **Can Prestige** - Whether prestiging now would bank at least one point.

#### Actions
- **Configure** (`requirement: float, exponent: float, bonus_per_point: float`) - Sets the requirement (run earnings before you gain a point), the exponent (curve; 0.5 = square-root, the usual), and the bonus each banked point adds to Prestige Multiplier.
- **Track Earned** (`amount: float`) - Records earnings toward prestige - call it wherever the player earns the prestige currency. Feeds both the run total (drives the gain) and the all-time Total Earned.
- **Do Prestige** - Banks the current Prestige Gain, raises the prestige level, and clears the run total. Does nothing if the gain is 0. Reset your currencies and generators in the same event, reading Prestige Gain first.
- **Set Points** (`points: float`) - Forces banked prestige points to a value (for a load or a cheat menu).
- **Hard Reset** - Wipes EVERYTHING - points, level, run and all-time earnings. A full new-game, not a prestige.

#### Expressions
- **Prestige Gain** - How many prestige points the current run would bank right now.
- **Prestige Points** - Banked prestige currency.
- **Prestige Level** - How many times the player has prestiged.
- **Prestige Multiplier** - The permanent production multiplier from banked points: 1 + points * bonus.
- **Run Earned** - Earnings this run (resets on Do Prestige).
- **Total Earned** - All-time earnings (never resets).
- **Last Gain** - Points banked by the most recent Do Prestige (read inside On Prestige).
- **Requirement** - The run earnings needed before the first point.
- **Earned For Next Point** - The run earnings needed to reach the next prestige point.
- **Progress To Next** - How close this run is to the next point, 0 to 1 (for a progress bar).

### PricedTableBehavior (`res://eventsheet_addons/priced_table/priced_table_behavior.gd`)
@ace_tags(shop, economy, purchase, unlock) @ace_category("Priced Tables") @ace_version(1.0.0)

#### Triggers
- **On Purchased** (`entry_id: String, price: float`)
- **On Purchase Refused** (`entry_id: String, reason: String`)

#### Conditions
- **Can Afford Entry** (`entry_id: String`) - True when the wallet covers this entry's price right now - the condition that greys out a shop button before the player clicks it. Reads through the same seam the purchase uses, so it can never disagree with Buy Entry.
- **Entry In Stock** (`entry_id: String`) - True while the entry has something left to sell. An unlimited entry (-1) is always in stock; an unknown id never is.
- **Entry Is Unlocked** (`entry_id: String`) - True when the entry is open for business - the gate behind a tier, a prerequisite or a story beat.
- **Has Entry** (`entry_id: String`) - Whether the table holds an entry with this id at all - the guard that tells a typo apart from a sold-out row.
- **Table Is Sold Out** - True when nothing in the table can be bought any more: every entry is either at 0 stock or locked. An empty table counts as sold out.

#### Actions
- **Load Price Table** (`table: Resource`) - Stocks this table from a PriceTableResource (.tres) - every entry with its price, currency, stock, locked flag and requirement note - in one step instead of a wall of Add Entry actions. Entries that share an id with one already stocked are REPLACED (so loading a second table re-prices rather than duplicating); ids it has never seen are appended.
- **Add Entry** (`entry_id: String, label: String, price: float, currency: String, stock: int`) - Adds (or replaces) one entry from a sheet, for a table built at runtime - a shop whose stock is rolled per visit, a skill tree grown as the player levels. A stock of -1 is unlimited; the entry starts unlocked with no requirement note (set those with Set Entry Unlocked and the resource's requires column).
- **Clear Table** - Empties the table - every entry, price and stock count. Use it before loading a different table when you do NOT want the two merged by id.
- **Buy Entry** (`entry_id: String`) - The whole purchase in one row: refuses (firing On Purchase Refused with a reason) when the id is unknown, the entry is locked, its stock is 0, or the wallet cannot cover the price; otherwise it takes the price through whatever wallet answers, counts the stock down by one, and fires On Purchased with the id and what was paid. Hand over the goods in On Purchased - the pack never guesses what an entry means.
- **Restock Entry** (`entry_id: String, amount: int`) - Adds to one entry's remaining stock (a delivery, a daily refill). An unlimited entry (-1) is left alone, and stock never falls below 0.
- **Restock All** - Puts every entry back to the stock its table shipped with - the one row behind "the shop restocks each morning". Prices, locks and requirement notes are untouched.
- **Set Stock** (`entry_id: String, stock: int`) - Forces one entry's remaining stock to an exact number. -1 makes it unlimited, 0 sells it out.
- **Set Price** (`entry_id: String, price: float`) - Re-prices one entry while the game runs - a sale, a haggle, a reputation discount. Negative prices are clamped to 0 (a free entry still goes through the whole purchase, so its trigger still fires).
- **Set Entry Unlocked** (`entry_id: String, unlocked: bool`) - Opens (or closes) one entry. A locked entry still shows in the table - Entry Is Unlocked greys it out in your UI, and buying it is refused with the reason "locked" - which is how a tier gate, a skill-tree prerequisite or a story unlock is expressed without deleting the row.
- **Use Wallet Node** (`node: Node`) - Points this table at ONE wallet node, tried before anything else - the direct way when the purse is already in hand (the player's own wallet node, a shared bank, a per-faction till). The contract is two functions, balance(currency) and spend(currency, amount); a node missing either is ignored, so a wrong drag can never silently swallow the money. Pass nothing to go back to searching the wallet group and then the CurrencyLedger autoload.
- **Set Local Wallet** (`amount: float`) - Sets the fallback purse - the number this table spends from when no wallet node and no CurrencyLedger autoload answer. It is deliberately the ONLY money verb here: as soon as your game has a real economy, install one and this number stops being consulted.

#### Expressions
- **Price Of** (`entry_id: String`) - What one entry costs (-1 when the table has no such id, so a missing price never reads as free).
- **Stock Of** (`entry_id: String`) - How many of one entry are left: -1 for unlimited, 0 for sold out (which is also what an unknown id reads).
- **Currency Of** (`entry_id: String`) - The currency id one entry is priced in - pass it to your wallet's own expressions to show the right icon.
- **Label Of** (`entry_id: String`) - The player-facing name of one entry ("Iron Sword"), for the shop row's text.
- **Requirement Of** (`entry_id: String`) - The plain-language requirement note written on one entry ("needs the guild badge"), for the tooltip on a locked row. The pack never interprets it - YOUR game decides when to call Set Entry Unlocked.
- **Entry Count** - How many entries the table holds - the row count for a shop list.
- **Entry Id At** (`index: int`) - The entry id at a position, in table order ("" out of range) - walk 0..Entry Count to build the shop UI.
- **Table Name** - The readable name written on the loaded table resource ("Blacksmith") - the shop window's title.
- **Wallet Balance** (`currency: String`) - What the buyer can spend of one currency, read through the same seam a purchase uses: the node given to Use Wallet Node, else a wallet node in the wallet group, else the CurrencyLedger autoload, else this table's Local Wallet number (which is currency-blind).
- **Last Purchased Id** - The entry bought most recently ("" before the first one) - readable long after On Purchased, for a receipt line.
- **Last Price Paid** - What the last purchase actually cost - the number to show in "-25 gold" feedback.
- **Last Currency Paid** - The currency the last purchase was paid in.
- **Refused Entry Id** - The entry of the most recent refusal ("" if none yet).
- **Refused Reason** - Why the most recent purchase was refused, as plain words you can show: "unknown entry", "locked", "out of stock" or "too expensive".

### ProcRoomAddon (`res://eventsheet_addons/proc_room/proc_room_addon.gd`)
@ace_tags(procedural, roguelite) @ace_category("ProcRoom") @ace_version(1.0.0)

#### Triggers
- **On Graph Generated**
- **On Room Entered**
- **On Traversal Blocked**

#### Conditions
- **Is Graph Ready** - Whether a map has been generated.
- **Is Room Visited** (`room_id: String`) - Whether a room has been entered.
- **Is Room Available** (`room_id: String`) - Whether a room can be entered right now (connected forward from current and unlocked).
- **Is Room Locked** (`room_id: String`) - Whether a room is locked.
- **Is Room Connected** (`from_id: String, to_id: String`) - Whether room A connects forward to room B.

#### Actions
- **Register Room Type** (`type_id: String, weight: float, min_depth: int, max_depth: int, max_per_depth: int`) - Registers a room type that Generate may place: a weight (higher = commoner), the depth range it may appear in (max_depth -1 = anywhere), and a per-depth cap (-1 = no cap).
- **Set Start Type** (`type_id: String`) - The type name given to the single depth-0 room (default "start").
- **Set Boss Type** (`type_id: String`) - The type name given to the single final-depth room (default "boss").
- **Use Advanced Random** (`enabled: bool`) - When on, ProcRoom draws its randomness from the shared AdvancedRandom autoload, so one seed can drive every procedural system at once. When off (the default) it uses its own seeded generator. Set the AdvancedRandom seed before Generate for reproducible maps. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).
- **Generate** (`seed_text: String, depths: int, max_rooms_per_depth: int`) - Builds a reproducible tiered map from a seed: `depths` tiers (start at 0, boss at the last), up to `max_rooms_per_depth` rooms per interior tier. Same seed = same map. Fires On Graph Generated.
- **Regenerate** - Rebuilds the map from the SAME seed + settings as the last Generate (a fresh run of the same layout).
- **Enter Room** (`room_id: String`) - Moves to a room if it's connected forward from the current room and not locked; otherwise fires On Traversal Blocked (read Block Reason). On success marks it visited + fires On Room Entered.
- **Force Enter Room** (`room_id: String`) - Moves to any room ignoring connection + lock checks (for teleports / debug). Fires On Room Entered.
- **Lock Room** (`room_id: String`) - Locks a room so Enter Room is blocked until unlocked (a key door).
- **Unlock Room** (`room_id: String`) - Unlocks a locked room.
- **Reveal Room** (`room_id: String`) - Marks a room as revealed (for fog-of-war maps).
- **Reset Traversal** - Clears visited/revealed/locked and returns to the start room, keeping the same map (a fresh run of the same layout).

#### Expressions
- **Graph Seed** - The seed of the current map.
- **Total Rooms** - How many rooms the map has.
- **Total Depths** - How many depth tiers the map has.
- **Current Room** - The room the player is in ("" before entry).
- **Current Room Type** - The type of the current room.
- **Current Depth** - The depth tier of the current room.
- **Previous Room** - The room entered just before the current one.
- **Room Type** (`room_id: String`) - A room's type ("" if unknown).
- **Room Depth** (`room_id: String`) - A room's depth tier (-1 if unknown).
- **Rooms At Depth** (`depth: int`) - How many rooms are at a depth tier.
- **Room At Depth** (`depth: int, index: int`) - The room id at a depth + index ("" out of range).
- **Connections From** (`room_id: String`) - How many rooms a room connects forward to.
- **Connection From** (`room_id: String, index: int`) - The Nth room a room connects forward to ("" out of range).
- **Visited Count** - How many rooms have been visited.
- **Entered Id** - The room just entered (inside On Room Entered).
- **Entered Type** - The type of the room just entered (inside On Room Entered).
- **Blocked Id** - The room that couldn't be entered (inside On Traversal Blocked).
- **Block Reason** - Why entry was blocked - "locked" or "unreachable" (inside On Traversal Blocked).

### QuestPackAddon (`res://eventsheet_addons/quest/quest_addon.gd`)
@ace_tags(quest, objective, progression) @ace_category("Quest") @ace_version(1.0.0)

#### Triggers
- **On Quest Started** (`quest_id: String`)
- **On Objective Completed** (`quest_id: String, objective: String`)
- **On Quest Completed** (`quest_id: String`)

#### Conditions
- **Quest Is Active** (`quest_id: String`) - Whether this quest is being tracked right now (started, not yet completed or abandoned).
- **Quest Is Completed** (`quest_id: String`) - Whether this quest has been finished (every objective filled).
- **Objective Is Done** (`quest_id: String, objective: String`) - Whether one objective of an active quest has reached its needed count.

#### Actions
- **Start Quest** (`quest: Resource`) - Begins a quest from a Quest resource (a .tres you filled in the Inspector): every objective starts at 0 and On Quest Started fires. Starting a quest again resets its progress.
- **Register Quest** (`quest: Resource`) - Teaches the tracker a quest WITHOUT starting it, so another quest can chain into it through its Next Quest field (and so Quest Title / Quest Reward Note can read it). Register the later quests of a questline once at startup.
- **Advance Objective** (`quest_id: String, objective: String, amount: int`) - Counts progress on one objective of an active quest. Progress stops at the needed count, so an extra call can never double-fire: On Objective Completed fires the moment it fills, and once every objective is full the quest completes (On Quest Completed) and its Next Quest starts automatically.
- **Abandon Quest** (`quest_id: String`) - Drops an active quest and forgets its progress. It does NOT count as completed, and no trigger fires - start it again to try over.
- **Reset All Quests** - Clears every active quest and the completed list (e.g. on New Game). Registered quest definitions are kept, so a chain still works.
- **Save Quests** - Writes the active quests and the completed list into user://remembered.cfg (the same file the Remember Between Runs variable option uses) under a "Quests" section. Call it when the player saves or the level ends.
- **Load Quests** - Reads the active quests and the completed list back out of user://remembered.cfg (the Remember Between Runs store), replacing whatever is tracked now. Nothing happens if there is no save yet. Register your quest resources first if you want chains to keep working.

#### Expressions
- **Objective Text** (`quest_id: String, objective: String`) - An objective's progress as readable text, e.g. "3/5" - drop it straight into a quest-log label. "" if the quest is not active or has no such objective.
- **Objective Progress** (`quest_id: String, objective: String`) - An objective's progress as 0-1 - feed it straight to a progress bar's Progress Of. 0 if the quest is not active or has no such objective.
- **Active Quest Count** - How many quests are being tracked right now.
- **Completed Quest Count** - How many quests have been finished.
- **Quest Title** (`quest_id: String`) - The player-facing title of a started or registered quest ("" if the tracker has never seen it).
- **Quest Reward Note** (`quest_id: String`) - The reward note written on the quest resource - show it in your log and hand the reward out yourself in On Quest Completed.

### RotateBehavior (`res://eventsheet_addons/rotate/rotate_behavior.gd`)
@ace_tags(movement, visual) @ace_category("Rotate") @ace_version(1.0.0)

#### Conditions
- **Is Rotating**

#### Actions
- **Set Rotation Enabled** (`enabled: bool`) - Turns the spin on or off - the pause/resume toggle.
- **Set Rotation Speed** (`degrees_per_second: float`) - Sets the live rotation speed in degrees per second (negative = the other way).
- **Set Rotation Acceleration** (`degrees_per_second_squared: float`) - Sets the acceleration in degrees per second, per second (0 = constant).
- **Set Rotation Type** (`type: String`) - Switches what spins: a Node2D's rotation, or a Node3D's X / Y / Z axis.
- **Reverse Rotation** - Flips the spin direction (negates the live speed).

#### Expressions
- **Rotation Speed**

### SaveSystemAddon (`res://eventsheet_addons/save_system/save_system_addon.gd`)
@ace_tags(persistence) @ace_version(1.0.0)

#### Triggers
- **On Save Written** (`slot_index: int`)
- **On Before Save** (`slot_index: int`)
- **On After Load** (`slot_index: int`)
- **On Autosave Due** (`slot_index: int`)
- **On Save Needs Upgrade** (`save_data: Dictionary, from_version: int`)
- **On Load Failed** (`slot_index: int, reason: String`)
- **On Save Failed** (`slot_index: int, reason: String`)
- **On New Run Started** (`slot_index: int, run_number: int`)
- **On Key Saved** (`key: String, slot_index: int`)
- **On Key Loaded** (`key: String, slot_index: int`)
- **On Key Removed** (`key: String, slot_index: int`)
- **On Save Key Missing** (`key: String, slot_index: int`)

#### Conditions
- **For Each Saved Slot**
- **For Each Saveable Addon**
- **For Each Backup Of Slot** (`slot_index: int`)
- **Has Save Key** (`key: String`) - Whether the key exists in the active slot.
- **Save File Is Format** (`path: String, expected_format: String`) - Whether the save file at the path is the given format (config/json/binary/csv/ini/xml).
- **Save Format Is** (`expected_format: String`) - Whether the active save format (the Inspector format property) equals the given one.
- **Slot Exists** (`slot_index: int`) - Whether the slot has a save file.
- **Autosave Is Paused** - Whether Pause Autosave is currently holding the clock.
- **Safe To Save Now** - Whether writing the active slot right now would lose nothing: the slot either has no file yet, or its file reads back cleanly. Guard Save Game with it (and read it inside On Autosave Due before you commit to a write).
- **Slot Is Readable** (`slot_index: int`) - Whether that slot's file opens and parses. A slot with NO file reads as false, so pair it with Slot Exists to tell a slot with no save yet apart from a damaged one.
- **Addon Saves Itself** (`addon_name: String`) - Whether that autoload takes part in Save All Addons (it exposes save_state, itself or through a behavior child). Invert it to catch the pack somebody forgot to give a save seam.
- **Is Saving** - Whether a write is in flight right now - inside On Before Save, a Save All Addons sweep, or an autosave. Guard a second write with it, or hold a quit until it clears.
- **Is Loading** - Whether a load is in flight right now - the read, the migration gap and the On After Load broadcast are all inside it. Rows that must not fight the restore can stand aside while it is true.
- **Save Key Is** (`key: String, value: Variant`) - Whether the stored key equals this value, without loading it into a variable first. A key the slot does not hold never equals anything, so a missing key reads as false.

#### Actions
- **Save Value** (`key: String, value: Variant`) - Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.
- **Save Number** (`key: String, value: float`) - Writes a number under the key (active slot).
- **Save Text** (`key: String, value: String`) - Writes a string under the key (active slot).
- **Delete Slot** - Removes the active slot's save file (and its slot picture, which lives beside it).
- **Save Game** - Broadcasts On Before Save (every sheet writes its state), snapshots every node in the persist group, stamps the slot card, then fires On Save Written (or On Save Failed).
- **Load Game** - Reads the slot, gives migration rows their moment (On Save Needs Upgrade) when an older build wrote it, restores every persist-group snapshot, then broadcasts On After Load. A file it cannot read fires On Load Failed instead.
- **Save Node State** (`node: Node, key: String`) - Snapshots a node and its behaviors (any child with save_state) under the key.
- **Load Node State** (`node: Node, key: String`) - Restores a node and its behaviors from the key's snapshot.
- **Save Group State** (`group: String, key: String`) - Snapshots every node in the scene-tree group (and their behaviors) under the key.
- **Load Group State** (`key: String`) - Restores the group snapshot saved under the key (nodes matched by scene path).
- **Save Singleton State** (`singleton_name: String, key: String`) - Snapshots an autoload addon (Currency Ledger, Upgrades, Prestige...) by its autoload name.
- **Load Singleton State** (`singleton_name: String, key: String`) - Restores an autoload addon's snapshot from the key.
- **Set Slot Detail** (`detail_name: String, value: Variant`) - Writes one line of the active slot's card - the header a load menu reads without ever calling Load Game (chapter, hero name, percent, difficulty...). Playtime rides along automatically.
- **Capture Slot Thumbnail** (`width: int, height: int`) - Photographs the viewport, shrinks it to tile size and writes it beside the active slot's file, so the picture travels with the save - Copy Slot brings it along, Delete Slot takes it away, and an encryption key covers the picture exactly as it covers the save. Hide your pause menu first.
- **Copy Slot** (`from_slot: int, to_slot: int`) - Duplicates one slot's save file (and its picture) onto another slot - branching a save as one row. The destination is overwritten.
- **Delay Autosave By** (`seconds: float`) - Pushes the next autosave out by this many seconds. The beat is deferred, never dropped - use it in the not-now branch of On Autosave Due.
- **Pause Autosave** - Stops the autosave clock without losing the interval - for a boss fight, a cutscene, or a scene transition. Resume Autosave starts it again.
- **Resume Autosave** - Starts the autosave clock again after Pause Autosave, from a fresh interval.
- **Use Upgraded Save** (`save_data: Dictionary`) - Writes the record the migration rows just fixed back to the slot, stamped with the current Save Version, and lets Load Game carry on with it. Run it once at the end of On Save Needs Upgrade - the stamp makes the trigger stop firing for that file.
- **Save All Addons** - Snapshots every autoload that exposes the save_state seam - Currency Ledger, Upgrades, Prestige, Skin Vault, StatForge and anything you wrote - each under its own autoload name. There is no list to maintain: install a pack, register it, and it is in the save.
- **Load All Addons** - Restores every autoload snapshot Save All Addons wrote, matched by autoload name. An addon the save knows but this build does not have is reported, never dropped in silence.
- **Never Save This Key** (`key: String`) - Keeps this key out of every save from now on - cached node lists, scratch buffers, totals you recompute. It is dropped on the way to the file whichever row wrote it, and an already-saved copy disappears on the next write.
- **Restore Slot From Backup** (`slot_index: int, how_many_back: int`) - Puts an earlier version of the slot back (1 = the save before this one, 2 = the one before that). The CURRENT file is backed up first, so a restore is never a one-way door. Needs Backup Count above 0.
- **Carry Value Into Next Run** (`key: String`) - Marks one key to survive Start New Run - unlocked skins, a best time, the settings. Everything not marked is wiped. Marks last for the session, so declare them right before the reset.
- **Start New Run** (`slot_index: int`) - Wipes the slot and writes back ONLY the carried keys, its slot card, and a run counter one higher than before, then fires On New Run Started. New Game Plus, a chapter reset, a seasonal wipe, or the Reset Progress button that must keep the settings.
- **Remove Save Key** (`key: String`) - Takes one key out of the active slot and rewrites the file, then fires On Key Removed. A key the slot does not hold fires On Save Key Missing instead. Never Save This Key blocks a key forever; this removes the one copy that is already there.
- **Clear Slot Keys** - Empties the active slot of everything the game saved, and fires On Key Removed once per key. The file itself stays, and so do its slot card, its version stamp, its run number and its backups - the reset-profile button that does not cost the player their save file.
- **Check Save Key** (`key: String`) - Asks the slot whether it holds the key and answers with a row: On Key Loaded when it does, On Save Key Missing when it does not. The row that turns a silent default into a first-run seed.

#### Expressions
- **Load Value** (`key: String, default_value: Variant`) - Reads any value (your default when missing).
- **Load Number** (`key: String`) - Reads a number (0 when missing).
- **Load Text** (`key: String`) - Reads a string ("" when missing).
- **Read All** - Reads the whole active slot as one Dictionary (every saved key and value).
- **List Save Keys** - The keys stored in the active slot (loop them to read a whole save).
- **Read Save File** (`path: String, file_format: String`) - Reads ANY save file at a path in the given format (config/json/binary/csv/ini/xml; blank = the active format) and returns its Dictionary.
- **Save File Format** (`path: String`) - Detects the format of the save file at the path (config/json/binary/csv/ini/xml), or "" when it is missing or unrecognised. Feed it to Read Save File.
- **List Slots** - Slot numbers that have save files (for menus).
- **Slot Modified Time** (`slot_index: int`) - Unix mtime of the slot's file (0 when missing).
- **Slot Detail** (`slot_index: int, detail_name: String, fallback: Variant`) - Reads one card field of any slot straight off disk (your fallback when that slot has no such detail). Nothing is loaded and nothing is applied - safe to call for every tile of a load menu.
- **Slot Playtime** (`slot_index: int`) - Seconds played on that slot, accumulated by this pack and stamped on every save (0 when the slot has none). Feed it to Format Time for a 4h12m tile.
- **Slot Thumbnail** (`slot_index: int`) - The picture saved beside that slot, ready to drop into a TextureRect (null when the slot has none). Read off disk, so a load menu never loads a game to draw its tiles.
- **Slot Path** (`slot_index: int`) - Where that slot's file lives (built from the Save Directory and File Pattern properties). Feed it to Read Save File, File Size or Copy File - the paths the pack uses are no longer private.
- **Seconds Until Autosave** - How long until the next autosave beat - for a countdown pip in the corner. 0 when autosave is off or paused.
- **Slot Save Version** (`slot_index: int`) - Which Save Version wrote that slot's file. A file with no stamp counts as 1, so saves written before you ever bumped the number still answer.
- **Last Save Problem** - The last save or load failure as one readable sentence ("" when both worked). Show it in a label, or log it.
- **Slot Problem** (`slot_index: int`) - What is wrong with that slot's file, as one readable sentence ("" when it reads fine or does not exist) - the tooltip for a greyed-out Continue button.
- **Save Size** - How many bytes the active slot's file takes on disk (0 when there is none) - the number nobody sees until a player reports a 40MB save.
- **Save Report** - A plain-text breakdown of the active save: total bytes, key count, then the heaviest keys in order. Log it, or show it in a debug overlay when a player reports a save that will not stop growing. The total is the real size of the file on disk; the per-key numbers are relative WEIGHTS (each value written out as text, measured in characters), so they rank the keys against one another rather than adding up to the total.
- **Slot Backup Count** (`slot_index: int`) - How many earlier versions of that slot are kept right now (0 when backups are off or nothing has been overwritten yet).
- **Run Number** - 1 on a fresh save, 2 after the first New Game Plus, and so on - the number every NG+ banner, difficulty curve and you-have-beaten-this-N-times line is really asking for.
- **Save Key Count** - How many keys the active slot holds - the number a save inspector puts in its header. Counts exactly what List Save Keys lists, the pack's own reserved keys included.
- **Save Key At** (`index: int`) - The key at this position in the active slot, for a numbered or paged list ("" when the position is past the end). Loop List Save Keys instead when you just want them all.

### SceneFlowBehavior (`res://eventsheet_addons/scene_flow/scene_flow_behavior.gd`)
@ace_category("Scenes") @ace_expose_all(node) @ace_version(1.0.0)

#### Conditions
- **Is Transitioning**

#### Actions
- **Fade To Scene** (`path: String`) - Fades the screen out, changes to the scene, and fades back in (ignored while a transition runs).
- **Fade Reload Scene** - Fades out, reloads the current scene, and fades back in - the polished retry button.
- **Go To Scene** (`path: String`) - Changes to the scene immediately (no fade).
- **Reload Scene** - Reloads the current scene immediately (no fade).
- **Quit Game** - Quits the game (a no-op on platforms that forbid it, like web).

#### Expressions
- **Current Scene Path**

### SineBehavior (`res://eventsheet_addons/sine/sine_behavior.gd`)
@ace_category("Sine") @ace_expose_all(node) @ace_version(1.0.0)

#### Actions
- **Set Sine Active** (`is_active: bool`) - Pauses or resumes the oscillation.
- **Update Initial State** - Re-captures the host's current position/scale/angle/opacity as the wave's base (updateInitialState).
- **Set Phase** (`degrees: float`) - Phase offset in degrees.
- **Reset Sine** - Restarts the wave from the current state.

### Sine3DBehavior (`res://eventsheet_addons/sine_3d/sine_3d_behavior.gd`)
@ace_category("Sine 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Actions
- **Set Sine 3D Active** (`is_active: bool`) - Pauses or resumes the oscillation.
- **Set Phase** (`degrees: float`) - Phase offset in degrees.
- **Reset Sine 3D** - Restarts the wave from the current state.

### SkinVaultAddon (`res://eventsheet_addons/skin_vault/skin_vault_addon.gd`)
@ace_tags(cosmetics, gacha) @ace_category("SkinVault") @ace_version(1.0.0)

#### Triggers
- **On Skin Rolled**
- **On Skin Unlocked**
- **On Purchase Requested**
- **On Purchase Cancelled**
- **On Skin Revoked**
- **On Pool Empty**

#### Conditions
- **Is Owned** (`skin_id: String`) - Whether the player owns a skin.
- **Is Registered** (`skin_id: String`) - Whether a skin exists in the catalog.
- **Is Unlockable** (`skin_id: String`) - Whether a skin is registered but not yet owned (drives lock icons).
- **Is Pool Empty** (`tag: String`) - Whether there are no unowned skins left to roll (optional tag filter).

#### Actions
- **Register Rarity** (`name: String, weight: float, tier: int`) - Registers a rarity: a roll weight (higher = commoner) and a tier rank (higher = rarer; pity guarantees a tier at or above the pity rarity).
- **Use Advanced Random** (`enabled: bool`) - When on, rolls draw from the shared AdvancedRandom autoload instead of this pack's own generator, so one seed drives your whole game's randomness. When off (the default) it uses its own generator. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).
- **Register Skin** (`id: String, display_name: String, rarity: String, cost: float, tags: String`) - Registers a skin: a unique id, a display name, its rarity (must be registered), a cost (0 = not purchasable), and comma-separated tags.
- **Load Catalog** (`catalog: Resource`) - Registers a whole catalog (rarities + skins) from a Skin Catalog resource (a .tres you filled in the Inspector) in one step. The data-driven alternative to a string of Register Rarity + Register Skin actions.
- **Roll** (`tag: String`) - Rolls a weighted-random UNOWNED skin (optional tag filter; "" = any) and grants it. Applies pity, then fires On Skin Rolled and On Skin Unlocked. Fires On Pool Empty if nothing is left.
- **Grant** (`skin_id: String`) - Unlocks a skin for free (fires On Skin Unlocked). Does nothing if already owned.
- **Revoke** (`skin_id: String`) - Removes a skin from the owned set (fires On Skin Revoked).
- **Purchase** (`skin_id: String`) - Starts a purchase: fires On Purchase Requested carrying the skin id + cost. Check your wallet there, then call Confirm or Cancel Purchase. (SkinVault never touches currency itself.)
- **Confirm Purchase** (`skin_id: String`) - Completes a purchase and grants the skin (fires On Skin Unlocked with method "purchase").
- **Cancel Purchase** (`skin_id: String`) - Cancels a pending purchase (fires On Purchase Cancelled).
- **Reset Pity** - Sets the pity counter back to 0.
- **Load Owned** (`owned_csv: String`) - Restores the owned set from a comma-separated id list (pair with the Owned Ids expression to save).
- **Set Pity Count** (`count: int`) - Restores the pity counter (for save/load).

#### Expressions
- **Total Skins** - How many skins are registered.
- **Owned Count** - How many skins the player owns.
- **Pool Count** (`tag: String`) - How many unowned skins remain (optional tag filter).
- **Skin Name** (`skin_id: String`) - A skin's display name.
- **Skin Rarity** (`skin_id: String`) - A skin's rarity name.
- **Skin Cost** (`skin_id: String`) - A skin's cost (0 if not purchasable / unknown).
- **Pity Counter** - The current miss streak toward pity.
- **Pity Progress** - Progress toward pity as 0.0 - 1.0 (for a bar).
- **Owned Ids** - The owned skin ids as a comma-separated string (pair with Load Owned to save).
- **Rolled Id** - The skin just rolled (inside On Skin Rolled).
- **Unlocked Id** - The skin just unlocked (inside On Skin Unlocked).
- **Unlock Method** - How it was unlocked - "roll", "grant", or "purchase" (inside On Skin Unlocked).
- **Requested Id** - The skin being purchased (inside On Purchase Requested / Cancelled).
- **Requested Cost** - The cost of the requested purchase (inside On Purchase Requested).
- **Revoked Id** - The skin just revoked (inside On Skin Revoked).

### SlideMove (`res://eventsheet_addons/slide_move/slide_move_behavior.gd`)
@ace_tags(grid, movement) @ace_category("Slide Movement") @ace_version(1.0.0)

#### Triggers
- **On Slide Started**
- **On Slide Stopped**
- **On Hit Wall**

#### Conditions
- **Is Sliding** - Whether the character is mid-slide.
- **Can Slide** (`direction: String`) - Whether the tile next to the character in a direction is open (not a wall).

#### Actions
- **Slide** (`direction: String`) - Starts a slide in a direction (left / right / up / down): the character glides until the tile ahead is a wall, then stops snapped to the grid. Ignored while already sliding; fires On Hit Wall immediately if the very next tile is a wall.
- **Stop Slide** - Stops a slide immediately and snaps the character to the nearest tile.
- **Snap To Grid** - Snaps the character to the nearest grid intersection right now.
- **Teleport To Tile** (`tile_x: int, tile_y: int`) - Jumps instantly to a tile coordinate (multiplied by the grid size), cancelling any slide.
- **Set Grid Size** (`pixels: float`) - Changes the tile size in pixels at runtime.

#### Expressions
- **Slide Direction** - The direction of the current or last slide ("left" / "right" / "up" / "down").
- **Tile X** - The character's current column on the grid.
- **Tile Y** - The character's current row on the grid.

### SpringBehavior (`res://eventsheet_addons/spring/spring_behavior.gd`)
@ace_tags(motion, juice) @ace_category("Spring") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Spring Reached** (`spring_name: String`)
- **On Spring Started** (`spring_name: String`)

#### Conditions
- **Is Springing** (`spring_name: String`)

#### Actions
- **Spring To** (`spring_name: String, target: float`) - Springs the named value toward a target.
- **Spring Between** (`spring_name: String, from_value: float, to_value: float`) - Snaps to a start value, then springs to the end value.
- **Set Spring Value** (`spring_name: String, value: float`) - Snaps the named spring (no motion).
- **Add Impulse** (`spring_name: String, amount: float`) - Kicks the named spring's velocity (instant juice).
- **Stop Spring** (`spring_name: String`) - Freezes the named spring where it is.
- **Configure Spring** (`spring_name: String, stiffness: float, damping: float, precision: float`) - Per-spring stiffness/damping/precision overrides.
- **Spring Host X** (`target: float`) - Springs the host's X position.
- **Spring Host Y** (`target: float`) - Springs the host's Y position.
- **Spring Host Angle** (`degrees: float`) - Springs the host's rotation (degrees).
- **Spring Host Scale** (`target: float`) - Springs the host's uniform scale (squash & stretch!).
- **Set Color Value** (`spring_name: String, color: Color`) - Snaps a named colour spring (no motion) - seed it before springing.
- **Spring Color** (`spring_name: String, target_color: Color`) - Springs a named colour toward a target (read it back with Color Value - great for hit flashes).
- **Pause Spring** (`spring_name: String`) - Freezes a spring in place (resume continues it).
- **Resume Spring** (`spring_name: String`) - Resumes a paused spring toward its target.
- **Remove Spring** (`spring_name: String`) - Deletes a named spring (numeric and/or colour).
- **Reset All Springs** - Clears every spring on this behavior.

#### Expressions
- **Color Value** (`spring_name: String`)
- **Spring Value** (`spring_name: String`)
- **Spring Velocity** (`spring_name: String`)
- **Spring Progress** (`spring_name: String`)

### StatForge (`res://eventsheet_addons/stat_forge/stat_forge_behavior.gd`)
@ace_tags(stats, rpg, data) @ace_category("StatForge") @ace_requires(StatSheetResource) @ace_version(1.0.0)

#### Triggers
- **On Buff Added** (`buff_id: String, stat: String`)
- **On Buff Removed** (`buff_id: String, stat: String`)
- **On Buff Expired** (`buff_id: String, stat: String`)
- **On Threshold Crossed** (`rule_id: String, stat: String, total: float`)

#### Conditions
- **For Each Buff**
- **Has Buff** (`buff_id: String`)
- **Buff Is Active** (`buff_id: String`)
- **Has Buffs With Tag** (`tag: String`)
- **Has Buffs From Source** (`source: String`)
- **Stat Is At Least** (`stat: String, value: float`) - The beginner-friendly stat compare (Stat Total works in any expression too).

#### Actions
- **Add Buff** (`buff_id: String, stat: String, value: float, mode: String = "add", tags: String = "", source: String = "", duration: float = 0.0`) - The one verb that runs the whole system: a named buff targeting a stat with a value and a mode (add / multiply / override - highest override wins). Tags are comma-separated labels for bulk ops, source names who applied it, duration in seconds expires it (0 = permanent). Re-adding an id REPLACES that buff.
- **Remove Buff** (`buff_id: String`) - Removes one buff by id (a no-op when absent).
- **Remove Buffs By Tag** (`tag: String`) - Removes every buff carrying the tag - unequip all "equipment" in one action.
- **Remove Buffs By Source** (`source: String`) - Removes every buff a source applied - clear one enemy's curses when it dies.
- **Clear Buffs** - Empties the whole stack (bases stay).
- **Set Stat Base** (`stat: String, value: float`) - Sets a stat's base value - the number the buff math starts from.
- **Set Buff Active** (`buff_id: String, active: bool`) - Turns one buff on or off WITHOUT removing it - inactive buffs stay in the stack but contribute nothing (a stance toggle, a disabled rune).
- **Set Buffs Active By Tag** (`tag: String, active: bool`) - Bulk activation by tag - silence every "aura" buff in an antimagic zone.
- **Set Buff Value** (`buff_id: String, value: float`) - Changes a live buff's value in place (a stacking poison that deepens).
- **Refresh Buff** (`buff_id: String, duration: float`) - Restarts a timed buff's countdown (re-drinking the potion refreshes, not stacks).
- **Set Buff Timer Paused** (`buff_id: String, paused: bool`) - Freezes/unfreezes one buff's countdown (cutscenes, pause-adjacent states).
- **Advance Timers** (`seconds: float`) - Advances every unpaused timer by the given seconds - the manual clock for turn-based games (turn ends: Advance Timers 1).
- **Add Threshold Rule** (`rule_id: String, stat: String, value: float, direction: String = "rising", repeating: bool = true`) - Watches a stat and fires On Threshold Crossed when its total crosses the value. Direction rising / falling / both; a repeating rule re-arms once the stat is back across, a one-shot stays spent until Re-Arm Threshold Rule.
- **Remove Threshold Rule** (`rule_id: String`)
- **Re-Arm Threshold Rule** (`rule_id: String`) - Re-arms a spent one-shot rule so it can fire again.
- **Load Stat Sheet** (`stat_sheet: Resource`) - Applies a StatSheetResource (.tres): its bases set stat bases, its buff rows Add Buff one by one IN ORDER - whole loadouts, classes, and difficulty presets as data.

#### Expressions
- **Stat Total** (`stat: String`) - The stat computation: (base + active adds) * active multipliers - unless active OVERRIDE buffs exist, where the HIGHEST override wins outright. Overflow applies last (clamp / wrap / none).
- **Stat Base** (`stat: String`)
- **Buff Value** (`buff_id: String`)
- **Buff Time Left** (`buff_id: String`) - Seconds left on a timed buff (-1 = permanent or unknown).
- **Buff Count**
- **Buff Count With Tag** (`tag: String`)
- **Last Expired Buff** - The buff that expired most recently - read it inside On Buff Expired.
- **Last Threshold Rule** - The rule that fired most recently - read it inside On Threshold Crossed.

### StateMachineBehavior (`res://eventsheet_addons/state_machine/state_machine_behavior.gd`)
@ace_category("State Machine") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On any state change** (`previous: String, next: String`)

#### Conditions
- **Current state is** (`state_name: String`) - True while the machine is in the given state.

#### Actions
- **Go to state** (`next: String`) - Switches to the given state and fires On any state change.

#### Expressions
- **Time in state** - How many seconds the machine has been in its current state.

### StoryletsAddon (`res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd`)
@ace_tags(narrative, storylet) @ace_category("Storylets") @ace_version(1.3.0)

#### Triggers
- **On Storylet Drawn**
- **On Choice Made**
- **On None Available**

#### Conditions
- **Has Active Storylet** - Whether a storylet is currently active (drawn, not yet resolved).
- **Is Available** (`id: String`) - Whether a storylet is in the current available list (call Evaluate first).
- **Has Quality** (`key: String`) - Whether a quality key has been set.
- **Has Been Played** (`id: String`) - Whether a storylet has played at least once.
- **Is On Cooldown** (`id: String`) - Whether a storylet is still cooling down.
- **Is Library Empty** - Whether no storylets are registered.
- **Book Resource Is Valid** (`resource: Resource`) - Whether a StoryletResource is free of structural problems - every requirement / choice / effect / meta row names a defined storylet, every choice-rule row names a real choice, and no storylet id is blank or duplicated. Read the specific problems with Validate Book Resource.
- **JSON Book Is Valid** (`json: String`) - Whether a JSON storybook parses and is free of structural problems - the JSON equivalent of Book Resource Is Valid. Read the specific problems (including a parse failure) with Validate Book JSON.

#### Actions
- **Define Storylet** (`id: String, title: String, body: String`) - Registers (or replaces) a storylet: an id plus the title + body text your game shows.
- **Set Storylet Weight** (`id: String, weight: float`) - How strongly this storylet is preferred when several are eligible (higher = picked first / likelier).
- **Set Storylet Cooldown** (`id: String, seconds: float`) - Seconds this storylet is ineligible after it plays (0 = no cooldown).
- **Set Max Plays** (`id: String, max_plays: float`) - How many times it may ever play (-1 = unlimited, 1 = a one-shot).
- **Add Requirement** (`id: String, quality_key: String, op: String, value: Variant`) - A rule this storylet needs to be eligible, e.g. quality "courage" >= 3. A missing quality counts as 0 (or "").
- **Add Choice** (`id: String, choice_id: String, text: String`) - Adds a labelled choice the player can pick on this storylet (resolve it with Choose).
- **Add Choice Requirement** (`id: String, choice_id: String, quality_key: String, op: String, value: Variant`) - A rule that must pass for this choice to be OFFERED, e.g. quality "gold" >= 10. Choices whose rules fail are hidden. Add the choice first with Add Choice.
- **Add Choice Effect** (`id: String, choice_id: String, op: String, key: String, value: Variant`) - A quality change applied automatically when this choice is picked - so a choice carries its own consequence instead of a per-choice branch. Add the choice first with Add Choice.
- **Add Effect** (`id: String, op: String, key: String, value: Variant`) - A quality change applied automatically when this storylet is DRAWN - so a beat carries its own consequence. Define the storylet first.
- **Add Meta** (`id: String, key: String, value: Variant`) - Attaches an arbitrary key-value to a storylet (a speaker, a portrait, a sound). Read it back with Active Meta / Storylet Meta - the engine never interprets it.
- **Add Requirement (Key vs Key)** (`id: String, quality_key: String, op: String, other_key: String`) - A rule comparing one quality against ANOTHER quality's value, e.g. gold >= price - so a storylet reacts to a relationship between stats without hard-coding the number.
- **Add Chance Requirement** (`id: String, percent: float`) - A probability gate: the storylet is eligible only percent% of the time, re-rolled on every Evaluate/Draw. Use it to make a beat show only sometimes.
- **Add Recency Requirement** (`id: String, mode: String, within: int`) - An anti-repeat (or must-be-recent) gate by DRAW history: eligible only when this storylet was / was not among the last N drawn storylets.
- **Set Quality** (`key: String, value: Variant`) - Stores a quality value (a number like courage=3, or text like location="tavern"). Requirements read these.
- **Increment Quality** (`key: String, amount: float`) - Adds to a numeric quality (creating it at 0 if new).
- **Clear Quality** (`key: String`) - Removes a quality key.
- **Evaluate** - Rebuilds the available list: every eligible storylet, ordered by weight (highest first). Use the Available expressions to show a menu.
- **Draw** - Evaluates, then activates the highest-weight eligible storylet and fires On Storylet Drawn (or On None Available if nothing qualifies).
- **Draw Weighted** - Like Draw, but picks randomly among the eligible storylets in proportion to their weight (for variety).
- **Choose** (`choice_id: String`) - Resolves the active storylet's choice by id: applies that choice's effects, fires On Choice Made, then clears the active storylet. Only an ELIGIBLE choice resolves. React inside On Choice Made.
- **Use Advanced Random** (`enabled: bool`) - When on, Draw Weighted picks using the shared AdvancedRandom autoload instead of Godot's own randf(), so one seed drives your whole game's randomness. When off (the default) it uses randf(). Needs the Advanced Random pack installed (it safely falls back if not).
- **Load From Resource** (`resource: Resource`) - Registers a whole storybook from a StoryletResource asset (a .tres you fill in the Inspector) in one step, instead of a wall of Define Storylet actions. Additive: it defines each storylet and adds its requirements, choices, effects and meta, so you can still tweak the library with the discrete actions afterwards.
- **Load From JSON** (`json: String`) - Registers a whole storybook from a JSON string in one step - the same grid shape as a StoryletResource (an object with storylets / requirements / choices / choice_requirements / effects / choice_effects / meta arrays), so you can hot-reload narrative content or load user-made / downloaded books at runtime. Additive and forgiving like Load From Resource; ops may be symbols (>=) or word tokens (gte). Invalid or non-object JSON is ignored - check it first with Validate Book JSON.
- **Dismiss** - Clears the active storylet without making a choice (the play still counted).
- **Reset Play Count** (`id: String`) - Lets a one-shot or limited storylet play again.
- **Reset All History** - Clears every play count, cooldown, and the recency draw-history (e.g. on New Game).

#### Expressions
- **Quality Number** (`key: String`) - A quality as a number (0 if unset).
- **Quality Text** (`key: String`) - A quality as text ("" if unset).
- **Available Count** - How many storylets are eligible (after Evaluate/Draw).
- **Available Id** (`index: int`) - The eligible storylet id at a position ("" out of range).
- **Available Title** (`index: int`) - The title of the eligible storylet at a position.
- **Active Id** - The active storylet id ("" if none).
- **Active Title** - The active storylet's title.
- **Active Body** - The active storylet's body text.
- **Choice Count** - How many ELIGIBLE choices the active storylet offers (choices whose requirements fail are not counted).
- **Choice Id At** (`index: int`) - The id of the eligible choice at a position on the active storylet.
- **Choice Text At** (`index: int`) - The label of the eligible choice at a position on the active storylet.
- **Chosen Id** - The choice just picked (inside On Choice Made).
- **Forecast Storylet Effects** (`id: String`) - A readable preview of the quality changes a storylet applies when drawn, e.g. "gold -10, gate_open = 1". Never changes anything - put it on a button.
- **Forecast Choice Effects** (`id: String, choice_id: String`) - A readable preview of the quality changes a choice applies when picked. Pass Active Id() for the current storylet. Never changes anything.
- **Active Meta** (`key: String`) - A meta value on the active storylet ("" if unset).
- **Storylet Meta** (`id: String, key: String`) - A meta value on any registered storylet by id, without drawing it ("" if unset).
- **Available Meta** (`index: int, key: String`) - A meta value on the eligible storylet at a position in the available list.
- **Play Count** (`id: String`) - How many times a storylet has played.
- **Cooldown Remaining** (`id: String`) - Seconds left on a storylet's cooldown (0 if ready).
- **Storylet Count** - How many storylets are registered.
- **Validate Book Resource** (`resource: Resource`) - Checks a StoryletResource's grids and returns each structural problem - a requirement / choice / effect / meta row naming a storylet (or choice) that does not exist, a blank storylet id, or a duplicate id that silently overrides an earlier storylet - one per line, "" when the book is clean. Print it while authoring to catch typos in the tables.
- **Validate Book JSON** (`json: String`) - Checks a JSON storybook and returns each structural problem one per line, "" when clean - the JSON twin of Validate Book Resource. Also reports "not valid JSON" for a parse failure and a non-object root, so it doubles as a JSON syntax check before Load From JSON.

### TileMovementBehavior (`res://eventsheet_addons/tile_movement/tile_movement_behavior.gd`)
@ace_category("Tile Movement") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Step Finished**

#### Actions
- **Simulate Step** (`direction: String`) - Steps one tile in a direction: left, right, up or down (simulate control).
- **Teleport To Tile** (`tile_x: float, tile_y: float`) - Snaps to a tile coordinate instantly.

### TimeSlicerBehavior (`res://eventsheet_addons/time_slicer/time_slicer_behavior.gd`)
@ace_tags(performance, scheduling) @ace_category("Time Slicer") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Process Item** (`item: Variant`)
- **On Drained**

#### Conditions
- **Is Busy**

#### Actions
- **Enqueue Item** (`item: Variant`) - Adds one item to the work queue (processed later within the per-frame budget).
- **Enqueue Items** (`items: Array`) - Adds every element of an array to the work queue.
- **Enqueue Group** (`group: String`) - Adds every node in a group to the work queue (e.g. process all enemies, spread over frames).
- **Clear Queue** - Drops all pending items without processing them.
- **Set Frame Budget** (`ms: float`) - Sets the per-frame millisecond budget at runtime (dial it down during heavy scenes).
- **Pause** - Stops draining (items stay queued).
- **Resume** - Resumes draining the queue.

#### Expressions
- **Items Remaining**
- **Last Frame Item Count**

### TimerBehavior (`res://eventsheet_addons/timer/timer_behavior.gd`)
@ace_category("Timer") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Timer**

#### Actions
- **Start Timer** (`seconds: float`) - Starts (or restarts) the countdown with the given duration.
- **Stop Timer** - Stops the countdown without firing On Timer.

### TweenBehavior (`res://eventsheet_addons/tween/tween_behavior.gd`)
@ace_tags(motion, juice) @ace_category("Tween") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Tween Finished**

#### Conditions
- **Is Tweening**

#### Actions
- **Tween Property** (`property_path: String, final_value: float, duration: float`) - Tweens any host property (e.g. position:x) to a value.
- **Tween Position** (`x: float, y: float, duration: float`) - Moves the host to (x, y).
- **Tween Scale** (`amount: float, duration: float`) - Scales the host uniformly.
- **Tween Rotation** (`degrees: float, duration: float`) - Rotates the host to the given degrees.
- **Tween Alpha** (`alpha: float, duration: float`) - Fades the host's modulate alpha.
- **Stop Tweens** - Kills the running tween (host stays where it is).

### UHTNPlanner (`res://eventsheet_addons/uhtn_planning/uhtn_planning_behavior.gd`)
@ace_tags(ai, planning, utility) @ace_category("UHTN Planning") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Task Started** (`task_name: String`)
- **On Plan Complete**
- **On Plan Failed**
- **On Plan Loaded** (`plan_name: String`)

#### Conditions
- **Has Plan**
- **Current Task Is** (`task_name: String`)

#### Actions
- **Set World State** (`key: String, value: Variant`) - Writes a fact - preconditions and scorer inputs read it.
- **Clear World State** (`key: String`) - Removes a world-state key.
- **Add Primitive Task** (`task_name: String`) - Registers a leaf task your sheet executes directly.
- **Add Compound Task** (`task_name: String`) - Registers a task that decomposes via methods.
- **Add Method** (`task_name: String, method_id: String, utility: float`) - Adds (or re-scores) a way to accomplish a compound task; the best-ranked applicable method wins.
- **Add Method Condition** (`task_name: String, method_id: String, key: String, op: String, value: Variant`) - A precondition (world-state key, operator, value) the method needs to be chosen.
- **Add Method Subtask** (`task_name: String, method_id: String, subtask: String`) - Appends a subtask (primitive or compound) to a method, in order.
- **Add Scorer Input** (`scorer_id: String, input_key: String, curve: String, weight: float, center: float, slope: float`) - Feeds a world-state key through a response curve (linear / inverse / quadratic / inverse_quadratic / logistic / threshold / bell) into a named scorer. A scorer is the weighted average of its inputs.
- **Set Method Scorer** (`task_name: String, method_id: String, scorer_id: String`) - Binds a utility scorer to a method - the method is then ranked by the scorer's LIVE value at plan time instead of its fixed utility.
- **Clear Task Network** - Wipes all tasks, methods, and scorers (keeps world state).
- **Load Plan Resource** (`resource: Resource`) - Loads a UHTNPlanResource (.tres): its tasks, methods, preconditions, and scorer inputs replace the current network, and its root task becomes the goal. Fires On Plan Loaded.
- **Request Plan** - Decomposes the root task into a plan (best-ranked methods win) and starts the first task.
- **Mark Task Complete** - Advances to the next task, or fires On Plan Complete at the end.
- **Mark Task Failed** - Re-plans from the root (or fires On Plan Failed if auto-replan is off).
- **Force Task** (`task_name: String`) - Pushes a task to the front of the plan and starts it - the scripted-override escape hatch (cutscene beats, staggers).
- **Invalidate Plan** - Drops the current plan so the next Request Plan rebuilds it.

#### Expressions
- **Current Task**
- **Plan Length**
- **Plan Task At** (`index: int`)
- **World Value** (`key: String`)
- **Scorer Value** (`scorer_id: String`)

### UpgradesAddon (`res://eventsheet_addons/upgrades/upgrades_addon.gd`)
@ace_tags(incremental, idle, upgrade) @ace_category("Upgrades") @ace_version(1.0.0)

#### Triggers
- **On Upgrade Bought**
- **On Purchase Failed**

#### Conditions
- **Is Maxed** (`id: String`) - Whether an upgrade is at its max level.
- **Owns** (`id: String`) - Whether an upgrade has at least one level.
- **Purchase Succeeded** - Whether the last Try Purchase went through (read it right after, or in On Upgrade Bought).

#### Actions
- **Define Upgrade** (`id: String, base_cost: float, cost_growth: float, max_level: int, per_level: float, mode: String, tag: String`) - Creates (or resets) an upgrade: base cost, cost growth per level, max level (-1 = unlimited), effect per level, mode ("add" or "mult"), and a tag to group it for Total Multiplier / Total Bonus.
- **Set Effect** (`id: String, per_level: float, mode: String`) - Retunes an existing upgrade's per-level effect and mode without touching its level (for live balancing).
- **Try Purchase** (`id: String, budget: float`) - Buys the next level if `budget` covers Cost Of and it is not maxed. On success records Last Cost and fires On Upgrade Bought (Spend Last Cost from your wallet); otherwise fires On Purchase Failed. Never touches the wallet itself.
- **Grant Level** (`id: String`) - Adds one free level (a reward), up to the max. No cost, no budget check.
- **Set Level** (`id: String, level: int`) - Forces an upgrade's level (for a load or cheat), clamped to 0 and the max.
- **Reset** - Sets every upgrade back to level 0 (keeps the definitions) - for a prestige wipe.

#### Expressions
- **Cost Of** (`id: String`) - The next level's price (-1 if maxed or undefined).
- **Level Of** (`id: String`) - An upgrade's current level.
- **Max Level Of** (`id: String`) - An upgrade's max level (-1 = unlimited).
- **Effect Of** (`id: String`) - An upgrade's current stacked effect (level*per_level for add mode, per_level^level for mult mode).
- **Total Multiplier** (`tag: String`) - The product of every mult-mode upgrade sharing this tag (1.0 if none) - multiply production by it.
- **Total Bonus** (`tag: String`) - The sum of every add-mode upgrade sharing this tag (0.0 if none) - add it to a base value.
- **Last Cost** - What the last Try Purchase cost - Spend this from your wallet.
- **Last Upgrade** - The id of the last upgrade bought or failed (read in the trigger).
- **Upgrade Count** - How many upgrades are defined.

### UtilityBrain (`res://eventsheet_addons/utility_ai/utility_ai_addon.gd`)
@ace_tags(ai, decision) @ace_category("Utility AI") @ace_version(1.0.0)

#### Triggers
- **On Decision Made**
- **On Action Started**
- **On Action Changed**
- **On Action Completed**
- **On Action Interrupted**
- **On Cooldown Started**
- **On Cooldown Ended**
- **On No Valid Action**

#### Conditions
- **Is Running** (`action_name: String`) - Whether the brain's current action is this one.
- **Has Action** (`action_name: String`) - Whether an action is registered on this brain.
- **Is Action Enabled** (`action_name: String`) - Whether an action is registered and enabled.
- **Is On Cooldown** (`action_name: String`) - Whether an action is currently cooling down.
- **Was Last Action** (`action_name: String`) - Whether the previous action (before the current one) was this one - for anti-repeat / transition logic.
- **Is Idle** - Whether the brain has no current action (nothing chosen yet, or the last evaluation found none valid).

#### Actions
- **Add Action** (`action_name: String, cooldown: float, interruptible: bool, priority: float`) - Registers a candidate action the brain can choose. cooldown = seconds it rests after Mark Action Complete (0 = none); interruptible = whether Interrupt can cancel it; priority = an overall weight multiplier (1 = normal).
- **Add Consideration** (`action_name: String, input_key: String, curve: String, weight: float, curve_center: float, curve_slope: float`) - Adds a scoring factor to an action: it reads a world-state input (0-1) and maps it through a response curve to a 0-1 score. An action's considerations all multiply together, so any near-zero factor vetoes it. weight sharpens (>1) or softens (<1) this factor; center + slope tune the logistic / threshold / bell curves.
- **Remove Action** (`action_name: String`) - Removes an action (and any cooldown on it). Clears the current action if it was the one running.
- **Set Action Enabled** (`action_name: String, enabled: bool`) - Enables or disables an action without removing it (a disabled action is never chosen).
- **Set Input** (`key: String, value: float`) - Writes a world-state value considerations read by key (usually normalized 0-1, e.g. hp_ratio). Push these right before Evaluate; an unset key reads as 0.
- **Clear Inputs** - Clears all world-state inputs on this brain.
- **Evaluate** - Scores every enabled, off-cooldown action from the current world state and picks a winner. Fires On Decision Made (plus On Action Changed + On Action Started when the choice changes), or On No Valid Action if nothing clears the minimum score. Call it on a timer or after a stimulus.
- **Force Action** (`action_name: String`) - Overrides the decision and starts an action directly (fires On Decision Made + On Action Started). Use it for cutscenes, scripted beats, or an emergency fallback, then return to Evaluate.
- **Mark Action Complete** - Marks the running action finished: fires On Action Completed, starts its cooldown if it has one, then re-evaluates. Call it when your gameplay finishes performing the action (it already re-evaluates, so do not also call Evaluate).
- **Interrupt Action** - Stops the running action if it is interruptible (fires On Action Interrupted) and re-evaluates. A non-interruptible action is left alone.
- **Set Action Cooldown** (`action_name: String, seconds: float`) - Starts (or, with seconds <= 0, clears) a cooldown on an action - so it cannot be chosen until the timer expires. Fires On Cooldown Started.
- **Clear Cooldowns** - Clears every active cooldown on this brain (e.g. a refresh powerup).

#### Expressions
- **Current Action** - The id of the action running now ("" if none).
- **Previous Action** - The id of the action that ran before the current one.
- **Decision Score** - The winning action's score from the most recent Evaluate.
- **Action Score** (`action_name: String`) - An action's score from the most recent Evaluate (0 if it was not scored).
- **Action History** (`index: int`) - A past action by index, most-recent first (0 = current). "" past the end.
- **Action Count** - How many actions are registered on this brain.
- **Cooldown Remaining** (`action_name: String`) - Seconds left on an action's cooldown (0 if not cooling down).
- **Cooldown Action** - The action whose cooldown just started or ended (inside On Cooldown Started / On Cooldown Ended).
- **Get Input** (`key: String`) - The current value of a world-state input (0 if unset).

### VirtualCursor (`res://eventsheet_addons/virtual_cursor/virtual_cursor_behavior.gd`)
@ace_category("Virtual Cursor") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Interact Pressed** (`id: String`)
- **On Interact Released** (`id: String`)
- **On Layout Edge Hit**
- **On Cursor Arrived**
- **On Homing Target Entered**
- **On Homing Target Exited**
- **On Homing Snapped**
- **On Solid Hit**
- **On Bounce**

#### Conditions
- **Is Interact Held** (`id: String`)
- **Is Moving**
- **Is In Homing Range**
- **Is Blocked**
- **Is Enabled**
- **Is Ignoring Input**
- **Is Hovering** (`target: Node2D`)

#### Actions
- **Press Interact** (`id: String`) - Marks a named interact button held and fires On Interact Pressed.
- **Release Interact** (`id: String`) - Marks a named interact button released and fires On Interact Released.
- **Simulate Interact** (`id: String`) - Fires a press+release of a named button in one tick.
- **Set Max Speed** (`speed: float`) - Sets the max cursor speed (px/s).
- **Set Acceleration** (`rate: float`) - Sets the speed-up rate while an axis is held.
- **Set Deceleration** (`rate: float`) - Sets the slow-down rate when the axis is released.
- **Set Velocity** (`vel_x: float, vel_y: float`) - Sets the cursor velocity directly.
- **Simulate Direct Mouse Position** (`target_x: float, target_y: float`) - Teleports the cursor to a position, reporting the implied velocity.
- **Simulate Mouse** (`target_x: float, target_y: float, smoothing: float`) - Drives the cursor toward a target with smoothing (mouse-follow).
- **Simulate Axis** (`x: float, y: float`) - Feeds an analog axis for this tick (accel/decel applies).
- **Simulate Control** (`direction: int`) - Feeds a cardinal direction (0 up, 1 down, 2 left, 3 right) for this tick.
- **Set Homing Enabled** (`is_enabled: bool`) - Turns the homing magnet on/off.
- **Set Homing Mode** (`mode: int`) - 0 steer, 1 snap-radius, 2 snap-overlap.
- **Set Homing Radius** (`radius: float`) - Sets the homing engagement radius.
- **Set Homing Strength** (`strength: float`) - How strongly the cursor is pulled toward a homing target (0..1).
- **Add Homing Target** (`target: Node2D`) - Registers a node as a homing target.
- **Remove Homing Target** (`target: Node2D`) - Unregisters a homing target.
- **Clear Homing Targets** - Removes every homing target.
- **Add Solid** (`target: Node2D`) - Registers a node as a tracked solid (for SolidUID reporting).
- **Remove Solid** (`target: Node2D`) - Unregisters a tracked solid.
- **Clear Solids** - Clears the tracked-solids list.
- **Set Solid Collision** (`is_enabled: bool`) - Toggles solid push-out via move_and_slide.
- **Set Allow Sliding** (`state: bool`) - Slide along solids (true) or hard-stop (false).
- **Set Bounce** (`mode: int`) - 0 none, 1 solids, 2 constraints, 3 both.
- **Set Direction Mode** (`mode: int`) - 0 up/down, 1 left/right, 2 four-way, 3 eight-way.
- **Set Default Controls** (`state: bool`) - Read ui_left/right/up/down each tick.
- **Set Enabled** (`is_enabled: bool`) - Master on/off.
- **Set Ignoring Input** (`state: bool`) - Ignore all input while true (movement decays to zero).
- **Set Constrain To Layout** (`is_enabled: bool`) - Clamp the cursor inside the bounds.
- **Set Constraint Bounds** (`left: float, top: float, right: float, bottom: float`) - Sets explicit clamp bounds (all-zero clears them, falling back to the viewport).
- **Set Hover Mode** (`mode: int`) - 0 point (origin inside shape), 1 overlap (shapes overlap).

#### Expressions
- **Cursor X**
- **Cursor Y**
- **Speed**
- **Velocity X**
- **Velocity Y**
- **Moving Angle**
- **Axis X**
- **Axis Y**
- **Max Speed**
- **Hovered UID**
- **Homing Target UID**
- **Homing Target Dist**
- **Count Homing Targets**
- **Bounce Mode**

### WeaponKit (`res://eventsheet_addons/weapon_kit/weapon_kit_behavior.gd`)
@ace_tags(combat, shooter) @ace_category("Weapon") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Fire**
- **On Empty**
- **Reload Started**
- **On Reload Complete**

#### Conditions
- **Is Full**
- **Is Reloading**

#### Actions
- **Fire** - Fires if ready (not reloading, off cooldown, has ammo). In burst mode it kicks off a burst; if the magazine is empty it triggers On Empty (and auto-reloads when enabled).
- **Reload** - Starts a timed reload (if not full and reserve has rounds).
- **Cancel Reload** - Aborts an in-progress reload (no ammo gained).
- **Instant Reload** - Refills the magazine immediately (no reload time).
- **Add Ammo** (`amount: int`) - Adds rounds straight to the magazine (capped at the magazine size).
- **Add Reserve Ammo** (`amount: int`) - Adds spare rounds to the reserve pool (e.g. an ammo pickup).
- **Set Fire Rate** (`rate: float`) - Changes the shots-per-second.
- **Set Fire Mode** (`mode: int`) - 0 = single, 1 = auto, 2 = burst.
- **Set Magazine Size** (`size: int`) - Changes the magazine size.

### WrapBehavior (`res://eventsheet_addons/wrap/wrap_behavior.gd`)
@ace_tags(movement, screen) @ace_category("Wrap") @ace_version(1.0.0)

#### Triggers
- **On Wrapped** (`side: String`)

#### Actions
- **Set Wrap Enabled** (`enabled: bool`) - Turns wrapping on or off at runtime.
- **Set Custom Wrap Bounds** (`x: float, y: float, width: float, height: float`) - Sets the custom rectangle (world-space pixels) and switches wrapping to it - your arena's edges.
- **Set Wrap Axes** (`horizontal: bool, vertical: bool`) - Chooses which axes wrap (horizontal: left/right edges, vertical: top/bottom).
- **Set Wrap Extents** (`new_half_width: float, new_half_height: float`) - Sets the host's half-size (half the sprite's width and height) used by the fully-outside test.
- **Set Wrap Space** (`space: String`) - Switches what the host wraps around: the on-screen camera view, or the custom rectangle.
- **Set Circle Wrap Bounds** (`center_x: float, center_y: float, radius: float`) - Sets a CIRCULAR wrap constraint (world-space center + radius) and switches to it: fully outside the circle teleports to the antipode - a round arena in one action.

## Built-in vocabulary

Every action, condition and expression the picker offers with no pack enabled,
grouped by the module that authors it. Deprecated ones are marked - they still
compile, but the picker hides them.

### Animation Player (`res://addons/eventforge/registration/modules/animation_player_aces.gd`)
Animation control vocabulary (drive an AnimationPlayer from events).

#### Conditions
- **Has Animation** (`animation: String, target: String`) - True when this player owns a clip by that name - guard a Play so a missing animation never errors.

#### Actions
- **Set Animation Speed** (`scale: float, target: String`) - Scales how fast every animation on this player runs - slow-mo a death, speed up a fast-forward. 0 freezes it in place.
- **Seek Animation** (`time: float, target: String`) - Jumps the play head to a time in seconds (and updates the pose immediately) - scrub, restart from a beat, or sync to another clock.
- **Queue Animation** (`animation: String, target: String`) - Lines up an animation to play automatically when the current one ends - combo chains, or dropping back to idle after an attack, without a timer.
- **Pause Animation** (`target: String`) - Freezes the animation at its current position (Play resumes from here) - a hit-pause on a specific frame, or a photo mode.
- **Set Current Animation** (`animation: String, target: String`) - Switches which clip is current (assigning it starts it) - a direct set when you don't need Play's blend arguments.

#### Expressions
- **Animation Position** (`target: String`) - How many seconds into the current animation the play head is - sync an effect to a frame or drive a progress bar.
- **Animation Length** (`target: String`) - The current animation's total length in seconds - pair with Animation Position for a normalized 0-to-1 progress.
- **Animation Speed** (`target: String`) - The player's current speed scale (1 = normal).

### Array Functional (`res://addons/eventforge/registration/modules/array_functional_aces.gd`)
higher-order + typed-array operations for the "Variables: Array" vocabulary.

#### Conditions
- **Any Match** (`var_name: String, predicate: String, element: String`) - True when AT LEAST ONE element satisfies the test; FALSE for an empty array. The current element is named by the Element field - `x` unless you rename it. Godot's Array.any().
- **All Match** (`var_name: String, predicate: String, element: String`) - True when EVERY element satisfies the test; also TRUE for an empty array (there is nothing that fails). The current element is named by the Element field - `x` unless you rename it. Godot's Array.all().
- **Is Typed** (`var_name: String`) - True when the array is a typed container (e.g. Array[int]) rather than a plain untyped Array. Godot's Array.is_typed().

#### Actions
- **Assign (Type-Converting)** (`var_name: String, source: String`) - Replaces this array's contents with a COPY of the source array, converting each element to this array's element type - the type-safe way to fill a typed array (Array[int], ...) from another array. Converting values that fit is silent (a float 2.7 into an Array[int] truncates to 2); a value that cannot convert at all leaves the destination EMPTY and pushes an error. Godot's Array.assign().

#### Expressions
- **Filter** (`var_name: String, predicate: String, element: String`) - Returns a NEW array with only the elements where the test is true (the original is unchanged). The current element is named by the Element field - `x` unless you rename it. Godot's Array.filter().
- **Map** (`var_name: String, expression: String, element: String`) - Returns a NEW array with every element transformed by the expression (the original is unchanged). The current element is named by the Element field - `x` unless you rename it. Godot's Array.map().
- **Reduce** (`var_name: String, expression: String, seed: String, element: String, accumulator: String`) - Folds the whole array down to a SINGLE value: the accumulator holds the running result (starting at the seed) and is combined with each element in turn - e.g. acc + x from 0 sums the array. Godot's Array.reduce().
- **Element Type** (`var_name: String`) - The element type a typed array holds, as a Variant.Type value (TYPE_INT, TYPE_STRING, ...); TYPE_NIL (0) when the array is untyped. Godot's Array.get_typed_builtin().
- **Element Class** (`var_name: String`) - For an array typed to a class (e.g. Array[Node]), the element class name as a StringName; "" for a builtin-typed or untyped array. Godot's Array.get_typed_class_name().

### Audio (`res://addons/eventforge/registration/modules/audio_aces.gd`)
Audio (the Audio vocabulary, the Godot way).

#### Conditions
- **Is Playing** (`target: String`) - True when this audio player is currently making sound.

#### Actions
- **Play Sound** (`path: String, bus: String, volume_db: String`) - Plays a sound file once on a chosen bus and volume, then cleans itself up. Remembers the shot as the LAST SOUND, so Set Last Sound Playback Rate right after can retune it.
- **Play Sound At (2D)** (`path: String, position: String`) - Plays a sound at a world position so it gets louder or quieter with distance. Remembers the shot as the LAST SOUND for the last-sound actions.
- **Set Last Sound Playback Rate** (`rate: String`) - Changes the speed and pitch of the sound the last Play Sound started (1 = normal). Put it right after Play Sound - the default randf_range(0.9, 1.1) gives every shot a slightly different pitch.
- **Set Last Sound Volume** (`db: String`) - Changes the volume of the sound the last Play Sound started, in decibels.
- **Stop Last Sound** - Silences and frees the sound the last Play Sound started (one-shots are throwaway players, so stopping IS freeing).
- **Play** (`from: String, target: String`) - Starts this audio player, optionally from a given time in seconds.
- **Play Sound File** (`path: String, target: String`) - Loads an audio file into this player and starts playing it.
- **Stop** (`target: String`) - Stops this audio player from playing right now.
- **Seek** (`seconds: String, target: String`) - Jumps this audio player's playback to a specific time in seconds.
- **Set Volume** (`db: String, target: String`) - Sets how loud this audio player is, in decibels (0 = full, -80 = silent).
- **Set Playback Rate** (`pitch: String, target: String`) - Changes this player's speed and pitch (1 = normal, higher = faster).
- **Set Bus Volume** (`bus: String, db: String`) - Sets the volume of a named audio bus, like Music or SFX.
- **Mute Bus** (`bus: String, muted: String`) - Mutes or unmutes a named audio bus all at once.

#### Expressions
- **Playback Position** (`target: String`) - Gives the current playback time of this audio player, in seconds.
- **Bus Volume** (`bus: String`) - Gives the current volume of a named audio bus, in decibels.

### Audio Server (`res://addons/eventforge/registration/modules/audio_server_aces.gd`)
Audio Server vocabulary (the mixing desk from events).

#### Conditions
- **Bus Exists** (`bus: String`) - True when a bus with this name is in the current bus layout - guard optional buses.
- **Is Bus Effect Enabled** (`bus: String, effect_index: int`) - True while a bus effect slot is switched on - toggle states without a tracking variable.

#### Actions
- **Set Bus Muted** (`bus: String, muted: bool`) - Mutes or unmutes a whole bus - the options-menu music/SFX toggle in one action.
- **Set Bus Solo** (`bus: String, solo: bool`) - Solos a bus so only it (and other soloed buses) is heard - focus dialogue in a cutscene, audition a layer.
- **Set Bus Effects Bypassed** (`bus: String, bypassed: bool`) - Skips or restores ALL effects on a bus at once - dry vs processed in one flip.
- **Set Bus Effect Enabled** (`bus: String, effect_index: int, enabled: bool`) - Flips ONE prepared effect on a bus - add a lowpass to Master in the Audio panel, then toggle it for the underwater/muffled state; same trick for cave reverb or a flashbang highpass.
- **Set Audio Playback Speed** (`scale: float`) - Scales EVERY sound's playback speed and pitch - set it alongside Slowmo so the world's audio drops with time, then back to 1.

#### Expressions
- **Bus Peak Volume (dB)** (`bus: String`) - The bus's current peak level in dB (very negative = silence) - drive a VU meter, ducking, or audio-reactive visuals.
- **Audio Playback Speed** - The current global playback speed scale.
- **Bus Count** - How many buses the current layout has.
- **Audio Output Latency** - The output latency in seconds - rhythm games subtract it when judging hits.

### Camera Fov (`res://addons/eventforge/registration/modules/camera_fov_aces.gd`)
Camera FOV vocabulary (field of view from events).

#### Actions
- **Tween Camera FOV** (`degrees: float, duration: float`) - Smoothly eases the active 3D camera's field of view to a target over time - the aim-down-sights zoom, a speed-boost widen. Clamped to the legal 1-179 range; safe when there is no camera.
- **Adjust Camera FOV** (`delta: float`) - Nudges a 3D camera's field of view by a relative amount, clamped so a repeated zoom can never flip the camera inside-out.

#### Expressions
- **Camera FOV** (`target: String`) - A 3D camera's current field of view in degrees - read it for a HUD zoom indicator or a dynamic-FOV rig.

### Clipboard (`res://addons/eventforge/registration/modules/clipboard_aces.gd`)
Copying: share codes, the OS clipboard both ways, cloning a node, and

#### Conditions
- **Share Code Is Valid** (`code: String`) - True when the text really is a share code that decodes cleanly, so a paste box can refuse garbage before it reaches the game. Ask it when the pasted text CHANGES (a Paste button, On Text Changed) rather than every frame: a code mangled in transit can still reach the decoder, and the engine logs a line each time it is refused. A code that was made from nothing at all also reads as invalid.
- **Clipboard Has Text** - True when the operating system clipboard currently holds any text - gate a paste box on it.
- **Clipboard Has Image** - True when the operating system clipboard currently holds an image, such as a screenshot the player just copied.
- **Clipboard Text Is** (`op: String, value: String`) - Compares whatever text is on the clipboard against a value, with your choice of operator.
- **Has Remembered** (`name: String`) - True when something was remembered under that name this run - the gate on a Cancel button that should only undo a preview it actually took.

#### Actions
- **Copy Share Code To Clipboard** (`value: String`) - Encodes any value as a share code and puts it straight on the operating system clipboard, ready to paste.
- **Clone Into** (`source: String, parent: String, at: String, group: String`) - Copies a live node, adds the copy to a parent, places it and optionally puts it in a group - the one-row form of Duplicate Node plus Add Child plus Set Position. Use Spawn Scene when you are starting from a .tscn file instead.
- **Remember Value As** (`name: String, value: String`) - Copies any value aside under a name, in memory, for this run - the before-value for a preview, a buff or a cutscene. For memory that survives closing the game use Remember Between Runs on the variable, or the Save System pack.
- **Restore Value Into** (`name: String, var_name: String`) - Pours a remembered value back into a variable. When nothing was remembered under that name the variable keeps what it already had.
- **Forget Remembered** (`name: String`) - Drops a remembered value, so Has Remembered reads false again. Forgetting a name that was never remembered is harmless.

#### Expressions
- **Share Code For** (`value: String`) - Turns any value into one compact line of text a player can paste anywhere - a seed, a loadout, a whole save. Read it back with Value From Share Code.
- **Value From Share Code** (`code: String`) - Reads the value back out of a share code, giving nothing when the text is not a valid code.
- **Clipboard Image** - The image currently on the operating system clipboard - feed it to ImageTexture.create_from_image to show it.
- **Remembered Value** (`name: String, fallback: String`) - The value remembered under a name this run, or your fallback when there is none - read it without pouring it back.

### Collection (`res://addons/eventforge/registration/modules/collection_aces.gd`)
Collections (rich variables)

#### Conditions
- **Has Key** (`var_name: String, key: String`) - True when the dictionary contains the given key.
- **Has All Keys** (`var_name: String, keys: String`) - True when the dictionary contains every key in the given list.
- **Dictionary Is Empty** (`var_name: String`) - True when the dictionary has no keys at all.
- **Contains** (`var_name: String, value: String`) - True when the array holds the given value somewhere.
- **Array Is Empty** (`var_name: String`) - True when the array has no items at all.
- **Wait Succeeded** (`wait_name: String`) - True when the named wait ended because what it was waiting for happened. A wait that has never run is neither succeeded nor timed out, so nothing fires before the wait does.
- **Wait Timed Out** (`wait_name: String`) - True when the named wait gave up instead of finishing - the recovery branch for a load that never reported in. The same timeout also reports on verb_failed, so another event can handle it as On Failure Of.
- **Retry Up To N Times** (`retry_name: String, times: String`) - Runs this event's actions over and over, up to a number of attempts, so a nested Stop Retrying can end it the moment the thing works. With no waiting inside it stays instant, which makes it the procedural-placement loop as much as the disk retry. Read the try number with Retry Attempt Number.
- **Retries Exhausted** (`retry_name: String`) - True when the retry loop above ran out of tries without a Stop Retrying - the give-up branch. Put it in a sibling row directly beneath the retry loop, using the same name; a retry that has never run is not exhausted, so nothing fires before the loop does. Reading it clears the record, so the next run starts clean. When the retry WAITS between tries (Wait Before Next Try) the loop is still running while the rows beneath it are reached, so report that give-up with Report Failure on the last attempt and handle it in an On Failure Of event instead.
- **Is Game Paused** - True when the game is currently paused.
- **Is Playing** (`target: String`) - True while the audio player is currently playing a sound.
- **Is Animation Playing** (`target: String`) - True while the animated sprite is currently playing an animation.
- **Has Arrived** (`target: String`) - True once the navigation agent has reached its target destination.
- **Layout Has Finished Loading** (`path: String`) - True once a layout started with Load Layout In The Background is ready to switch to.
- **Is Visible** (`target: String`) - True when the node is currently visible on screen.
- **Is Equal (approx)** (`a: String, b: String`) - True when two numbers are nearly equal, avoiding tiny floating-point errors.
- **Is Zero (approx)** (`value: String`) - True when a value is essentially zero, ignoring tiny rounding differences.
- **Has Value** (`var_name: String, value: String`) - True when the dictionary contains the given value anywhere.
- **Text Contains** (`text: String, needle: String`) - True when the text contains the given substring somewhere inside it.
- **Text Begins With** (`text: String, prefix: String`) - True when the text starts with the given prefix.
- **Text Ends With** (`text: String, suffix: String`) - True when the text ends with the given suffix.
- **Is Tree Active** (`target: String`) - True when this AnimationTree is currently active and playing.
- **Is In State** (`state: String, target: String`) - True when the state machine is currently in the named animation state.

#### Actions
- **Set Key** (`var_name: String, key: String, value: String`) - Stores a value under a key in a dictionary variable, adding or overwriting it.
- **Delete Key** (`var_name: String, key: String`) - Removes a key and its value from a dictionary variable.
- **Clear Dictionary** (`var_name: String`) - Empties a dictionary variable, removing every key and value.
- **Merge Dictionary** (`var_name: String, other: String`) - Copies another dictionary's keys into this one, overwriting any clashes.
- **Push Back** (`var_name: String, value: String`) - Adds a value to the end of an array variable.
- **Insert At** (`var_name: String, index: String, value: String`) - Inserts a value into an array at a specific position.
- **Delete At** (`var_name: String, index: String`) - Removes the item at a specific position in an array.
- **Delete Value** (`var_name: String, value: String`) - Removes the first item in the array that matches a given value.
- **Clear Array** (`var_name: String`) - Empties an array, removing every item.
- **Sort Array** (`var_name: String`) - Sorts an array's items into ascending order.
- **Shuffle Array** (`var_name: String`) - Randomly reorders the items in an array.
- **Wait** (`seconds: String`) - Pauses this event for a number of seconds before continuing.
- **Wait For Signal** (`signal_expression: String`) - Pauses this event until a chosen signal fires, like a timer finishing.
- **Await Next Frame** - Pauses this event until the next game frame, to spread work out.
- **Begin Frame Budget** (`ms: String`) - Starts a per-frame time budget for the loop that follows, to avoid stutter.
- **Await If Over Budget** (`ms: String`) - Yields to the next frame only if this frame's time budget is used up.
- **Call After Delay** (`seconds: String, callable: String`) - Schedules a method to run later without pausing this event.
- **Repeat With Delay** (`times: String, delay: String, do: String`) - Runs one statement several times with a pause between each - burst fire, drip-spawns, a ticking countdown. It suspends this event the same way Wait does, so pair it with Once At A Time (Single Flight) when the trigger can fire again mid-burst.
- **Wait Until** (`wait_name: String, check: String, seconds: String`) - Pauses this event until a check comes true, or until the give-up time passes. Read which happened on the next row with Wait Succeeded / Wait Timed Out, naming this wait. It polls once a frame, so prefer Wait For Signal when a real signal exists for what you are waiting on.
- **Wait For All Of** (`wait_name: String, signals: String, seconds: String`) - Pauses this event until every signal in the list has fired at least once, or until the give-up time passes. It connects them ALL up front, one-shot, so nothing can fire into the gap between two waits - the bug a hand-written chain of awaits always has. An empty list succeeds at once.
- **Wait For Any Of** (`wait_name: String, signals: String, seconds: String`) - Pauses this event until the first of several signals fires, then carries on - a race, or a sudden-death timer. Read which one won with First To Finish, naming this wait: it answers "Node.signal", so racing $Player.died against $Boss.died still tells you which one it was. Every signal is connected one-shot up front, so the winner is whichever really fired first, and the losers are disconnected when the race ends.
- **Stop Retrying** (`retry_name: String`) - Ends the retry loop right now because the attempt worked, and records that it worked so Retries Exhausted below stays false. Put it under the condition that means success.
- **Wait Before Next Try** (`delay: String, growth: String, attempt: String`) - Pauses before the next attempt, waiting longer each time when you set a growth above 1 - the polite way to retry a disk or a slow source. It suspends this event like Wait does, so pair the retry with Once At A Time when the trigger can fire again mid-retry.
- **Read Input Axis Into** (`name: String, negative: String, positive: String`) - Reads a left/right input axis into a local variable for this event.
- **Tween Property** (`target: String, property: String, value: String, duration: String, transition: String, ease: String`) - Smoothly animates a node's property to a target value over time with an easing curve.
- **Tween Callback** (`callable: String, delay: String`) - Waits a delay, then calls a method or function once (handy for timed events).
- **Go To Layout** (`path: String`) - Switches the game to a different layout (a scene file), replacing the current one.
- **Restart Layout** - Restarts the current layout from scratch, useful for retrying a level.
- **Quit Game** - Closes the game and exits to desktop.
- **Pause The Game** - Freezes the whole game. Nodes set to Always (or a pause menu's Process Mode) keep running, which is how the menu on top stays alive.
- **Unpause** - Lets the game run again after Pause The Game.
- **Handle Quit Myself** (`mode: String`) - Stops the window's close button from quitting instantly, so On Close Requested can run first (save progress, pop a confirm dialog) and you quit explicitly with Quit Game. Choose "Allow" to restore Godot's default immediate quit.
- **Set Game Paused** (`paused: String`) - Pauses or resumes the whole game by toggling the scene tree's pause state.
- **Spawn Scene Instance** (`path: String`) - Loads a scene file and adds an instance of it as a child (spawning objects).
- **Play Sound** (`from_position: String, target: String`) - Plays the sound on an audio player, optionally starting from a given second.
- **Stop Sound** (`target: String`) - Stops the sound currently playing on an audio player.
- **Set Volume (dB)** (`db: String, target: String`) - Sets an audio player's loudness in decibels (0 is full, -80 is silent).
- **Play Sprite Animation** (`anim: String, target: String`) - Plays a named animation on an animated sprite (e.g. run or jump).
- **Stop Sprite Animation** (`target: String`) - Stops the animated sprite's current animation on the spot.
- **Set Frame** (`frame: String, target: String`) - Jumps the animated sprite to a specific frame number.
- **Set Mirrored** (`flipped: String, target: String`) - Mirrors the sprite horizontally, great for facing left or right.
- **Make Current** (`target: String`) - Makes this camera the active one the player views the game through.
- **Set Zoom** (`zoom: String, target: String`) - Sets how zoomed in or out the camera is.
- **Set Offset** (`offset: String, target: String`) - Shifts the camera view away from the position it follows.
- **Set Scroll Limits** (`left: String, top: String, right: String, bottom: String, target: String`) - Sets the boundaries the camera won't scroll past, keeping it inside the level.
- **Set Smoothing** (`enabled: String, target: String`) - Turns the camera's smooth catch-up on or off, so it eases toward what it follows instead of snapping.
- **Scroll Toward** (`toward: String, rate: String`) - Eases the camera toward another node, closing the gap at the given rate every second.
- **Set Text** (`value: String, target: String`) - Sets the text shown on a label, like a score or message.
- **Append Text** (`value: String, target: String`) - Adds more text onto the end of a label's existing text.
- **Find Path To** (`position: String, target: String`) - Tells a navigation agent to pathfind toward a world position, for AI movement.
- **Move Along Path** (`next: String, speed: String, target: String`) - Steers the body toward the next point on the path its navigation agent worked out. Follow it with Move so the body actually travels.
- **Load Layout In The Background** (`path: String`) - Starts loading a layout on another thread while the game keeps running, so a loading screen can show progress instead of freezing.
- **Go To Loaded Layout** (`path: String`) - Switches to a layout that finished loading in the background, with no second load and no pause.
- **Show** (`target: String`) - Makes a node visible on screen.
- **Hide** (`target: String`) - Hides a node so it no longer shows on screen.
- **Set Color Tint** (`color: String, target: String`) - Tints a node and its children with a color, also useful for fading via alpha.
- **Set Self Tint** (`color: String, target: String`) - Tints just this node with a color without affecting its children.
- **Seed Random** (`value: String`) - Sets the random seed so the same number gives a repeatable random sequence.
- **Randomize Seed** - Reseeds randomness from the clock so each playthrough differs.
- **Move Toward (smooth)** (`var_name: String, target: String, speed: String`) - Eases a variable smoothly toward a target instead of snapping to it. Works on numbers, Vector2/Vector3 and Colors alike (lerp is generic). It is frame-rate independent - the exponential form behaves the same at 30 and 144 fps.
- **Toggle boolean** (`var_name: String`) - Flips a true/false variable to its opposite - on becomes off, off becomes on.
- **Charge Toward** (`var_name: String, maximum: String, seconds: String`) - Fills a variable while the event runs, reaching the maximum after the given seconds - a hold-to-charge meter. Put it under a while-held input condition; it clamps itself at the top, and the release event just reads the value.
- **Reverse Array** (`var_name: String`) - Flips the array so its items run in the opposite order.
- **Push Front** (`var_name: String, value: String`) - Inserts a value at the start of the array, shifting the rest along.
- **Append Array** (`var_name: String, other: String`) - Adds every item from another array onto the end of this one.
- **Resize Array** (`var_name: String, size: String`) - Changes the array's length, adding empty slots or trimming items.
- **Fill Array** (`var_name: String, value: String`) - Sets every slot in the array to the same value.
- **Set Part Of** (`var_name: String, part: String, value: String`) - Changes one named part and leaves the rest alone: zero the vertical speed on landing and keep the horizontal, flatten a 3D direction to the ground plane, fade only the see-through part of a tint. Writing a part a record does not have yet ADDS it.
- **Set AnimationTree Active** (`active: String, target: String`) - Turns this AnimationTree's playback on or off.
- **Travel To State** (`state: String, target: String`) - Tells the state machine to transition to the named animation state.
- **Set Tree Parameter** (`path: String, value: String, target: String`) - Sets an AnimationTree parameter like a blend amount, condition or timescale.
- **Start Ramp Clock** - Marks minute zero for this node's Ramped values - call it when the run actually starts, not in menus.

#### Expressions
- **Get Key (with default)** (`var_name: String, key: String, default: String`) - Reads a key's value, returning your fallback when the key is missing.
- **Dictionary Size** (`var_name: String`) - Gives how many keys the dictionary currently holds.
- **Dictionary Keys** (`var_name: String`) - Gives a list of all the dictionary's keys.
- **Dictionary Values** (`var_name: String`) - Gives a list of all the dictionary's values.
- **Value At** (`var_name: String, index: String`) - Gives the item stored at a specific position in the array.
- **Array Size** (`var_name: String`) - Gives how many items the array currently holds.
- **Pick Random** (`var_name: String`) - Gives one random item picked from the array.
- **First To Finish** (`wait_name: String`) - Which signal a Wait For Any Of was watching finished first, written as "Node.signal" (the node's name, a dot, the signal's name), or empty text when it timed out. The node is part of the answer on purpose: a race between $Player.died and $Boss.died is two signals with the same name, and only the owner tells them apart. Compare it in a condition cell to branch on the winner.
- **Retry Attempt Number** (`loop_var: String`) - Which try this is, counting from 1 - the number you put in the log line or the HUD. Only readable inside a Retry Up To N Times loop, and it reads that loop's own variable, so change the cell if you renamed it.
- **Action Strength** (`action: String`) - Gives how hard an input action is pressed, from 0 to 1.
- **Input Axis** (`negative: String, positive: String`) - Gives a -1 to 1 value from two opposing input actions, like left and right.
- **Playback Position** (`target: String`) - Returns how many seconds into the sound the audio player currently is.
- **Current Animation** (`target: String`) - Returns the name of the animation the sprite is currently using.
- **Get Text** (`target: String`) - Returns the text currently displayed on the label.
- **Next Path Position** (`target: String`) - Returns the next point along the path the agent should move toward.
- **Distance To Target** (`target: String`) - Returns how far the agent still is from its navigation target.
- **Loading Progress** (`path: String`) - How far a background load has got, from 0 to 1 - multiply by 100 for a percentage bar.
- **Random** (`from: String, to: String`) - Returns a random decimal number between the two bounds you give.
- **Random Integer** (`from: String, to: String`) - Returns a random whole number between the two bounds, both included.
- **Choose** (`values: String`) - Randomly picks one value from a comma-separated list you provide.
- **Clamp** (`value: String, min: String, max: String`) - Keeps a value within a min and max, clipping anything outside the range.
- **Lerp** (`from: String, to: String, weight: String`) - Blends between two values by a 0-to-1 weight, for smooth interpolation.
- **Distance To** (`to: String, target: String`) - Returns the distance in pixels from this node to a target position.
- **Angle Toward** (`to: String, target: String`) - Returns the angle from this node toward a target position, handy for aiming.
- **Snap To Step** (`value: String, step: String`) - Rounds a value to the nearest step, useful for snapping to a grid.
- **Inverse Lerp** (`from: String, to: String, value: String`) - Returns where a value sits within a range as a 0-to-1 fraction.
- **Smoothstep** (`from: String, to: String, value: String`) - Eases a value between two edges with a smooth S-curve instead of a straight line.
- **Smooth Lerp** (`from: String, to: String, weight: String`) - Blends between two values like Lerp, but eases the 0-to-1 weight with a smooth S-curve first, so the motion starts and ends gently instead of at a constant speed.
- **Angle Of (atan2)** (`y: String, x: String`) - Returns the angle (radians) of the direction (x, y), correct in all four quadrants - the standard way to turn a velocity or offset into a heading.
- **Ping-Pong** (`value: String, length: String`) - Bounces a value back and forth between 0 and a length, great for looping motion.
- **Angle Difference** (`from: String, to: String`) - Returns the shortest signed turn from one angle to another, in radians.
- **Rotate Toward (angle)** (`from: String, to: String, delta: String`) - Steps an angle toward a target by a limited amount, for smooth turning.
- **Lerp Angle** (`from: String, to: String, weight: String`) - Blends between two angles by a 0..1 weight, taking the shortest path.
- **Degrees To Radians** (`degrees: String`) - Converts an angle from degrees into radians, which Godot uses internally.
- **Radians To Degrees** (`radians: String`) - Converts an angle from radians back into easy-to-read degrees.
- **Positive Modulo** (`a: String, b: String`) - Returns a modulo result that stays positive, handy for wrapping indexes.
- **Lighten Color** (`color: String, amount: String`) - Returns the colour shifted toward white by the given amount.
- **Darken Color** (`color: String, amount: String`) - Returns the colour shifted toward black by the given amount.
- **Lerp Color** (`from: String, to: String, weight: String`) - Blends two colours by a 0..1 weight for smooth colour fades.
- **Color With Alpha** (`color: String, alpha: String`) - Returns the colour with a new transparency, for fade-in or fade-out effects.
- **Color From HSV** (`h: String, s: String, v: String, a: String`) - Builds a colour from hue, saturation, value and alpha components.
- **Color From Hex** (`hex: String`) - Builds a colour from an HTML hex string like #ff8800.
- **Invert Color** (`color: String`) - Returns the opposite colour, useful for highlight or negative effects.
- **As Clock Time** (`seconds: String`) - Turns a number of seconds into minutes:seconds text - 90 seconds reads "01:30". For countdown timers, lap times and speedrun clocks.
- **Progress Of** (`value: String, from: String, to: String`) - Gives how far a value has come through a range, as 0 to 1 - feed it straight into a bar's scale, an alpha, or a colour lerp. This is the inverse_lerp nobody finds, with the clamp already applied.
- **Percent Of** (`value: String, from: String, to: String`) - The same reading as Progress Of, but as 0 to 100 - the number you show in text, like "73%" health.
- **Number Or** (`value: String, fallback: String`) - The value when it really is a number, or your own default when it is missing, null, text, or anything else. A zero counts as a real number and is kept. Use it to put a loaded value straight into a whole-number or decimal variable without a guard row first. The value is read twice in the emitted line, so keep it a plain read and not something that changes the game.
- **Text Or** (`value: String, fallback: String`) - The value when it really is text with something in it, or your own default when it is missing, null, blank, or another kind of value. The classic use is a saved player name that falls back to "Player". The value is read twice in the emitted line, so keep it a plain read and not something that changes the game.
- **List Or** (`value: String, fallback: String`) - The value when it really is a list with items in it, or your own default when it is missing, null, empty, or another kind of value. A Split Text result counts as a list. Safe to feed straight into a For Each. The value is read twice in the emitted line, so keep it a plain read and not something that changes the game.
- **Record Or** (`value: String, fallback: String`) - The value when it really is a record (a dictionary) with keys in it, or your own default when it is missing, null, empty, or another kind of value. Pair it with Get Key so a whole missing settings block reads as defaults. The value is read twice in the emitted line, so keep it a plain read and not something that changes the game.
- **Value Or** (`value: String, fallback: String`) - The value unless it is null, in which case your own default. This one guards nothing else: a zero, a blank text and an empty list all count as real values here. Use it for a method that can hand back null. The value is read twice in the emitted line, so keep it a plain read and not something that changes the game.
- **Get Variable** (`var_name: String`) - Returns the current value stored in the named variable.
- **Get Delta** - Returns the seconds since last frame, used to make motion frame-rate independent.
- **Get Position** (`target: String`) - Returns the node's 2D position as a Vector2.
- **Get Velocity** (`target: String`) - Returns the character body's current movement velocity.
- **Get Linear Velocity** (`target: String`) - Returns the rigid body's current linear velocity from physics.
- **Get Monitoring** (`target: String`) - Returns whether the area is currently watching for overlaps.
- **Get Time Left** (`target: String`) - Returns the seconds remaining before the timer fires.
- **Get Current Animation** (`target: String`) - Returns the name of the animation currently playing.
- **First Item** (`var_name: String`) - Returns the first item in the array.
- **Last Item** (`var_name: String`) - Returns the last item in the array.
- **Index Of** (`var_name: String, value: String`) - Returns the position of a value in the array, or -1 if it's missing.
- **Count Of** (`var_name: String, value: String`) - Returns how many times a value appears in the array.
- **Pop Back** (`var_name: String`) - Removes and returns the last item of the array.
- **Pop Front** (`var_name: String`) - Removes and returns the first item of the array.
- **Slice** (`var_name: String, from: String, to: String`) - Returns a sub-section of the array between the start and end indexes.
- **Join To Text** (`var_name: String, separator: String`) - Joins an array of strings into one text using a separator.
- **Array Max** (`var_name: String`) - Returns the largest value found in the array.
- **Array Min** (`var_name: String`) - Returns the smallest value found in the array.
- **Copy Array** (`var_name: String`) - Returns an independent copy of the array so edits don't affect the original.
- **Copy Dictionary** (`var_name: String`) - Returns an independent copy of the dictionary.
- **Make Vector2** (`x: String, y: String`) - Builds a Vector2 from separate x and y numbers, for positions or directions.
- **Make Vector3** (`x: String, y: String, z: String`) - Builds a 3D point or direction from X, Y and Z numbers.
- **Vector Length** (`vector: String`) - Returns how long a vector is, e.g. a velocity's speed.
- **Normalized** (`vector: String`) - Returns the vector shrunk to length 1, keeping only its direction.
- **Distance Between** (`a: String, b: String`) - Returns the straight-line distance between two points.
- **Direction To** (`a: String, b: String`) - Returns a unit vector pointing from one point toward another, handy for aiming.
- **Vector Angle** (`vector: String`) - Returns a 2D vector's angle in radians, useful for facing direction.
- **Dot Product** (`a: String, b: String`) - Returns the dot product of two vectors, telling how aligned they are.
- **Rotated** (`vector: String, radians: String`) - Returns the vector turned by the given angle in radians.
- **Vector Lerp** (`a: String, b: String, weight: String`) - Returns a point blended between two vectors, great for smooth movement.
- **Clamp Length** (`vector: String, max_length: String`) - Returns the vector capped to a maximum length, e.g. a speed limit.
- **Part Of** (`value: String, part: String`) - One named piece of a pair, a triple, a colour or a record: the up/down part of a velocity (the jump-or-fall test), the see-through part of a tint, the forward/back part of a 3D direction. Reads as a sentence instead of a typed-in .y. Pick a part the value actually has - a record that might be missing the field is the shipped Get Key (with default)'s job, because that one takes a fallback and this one does not.
- **Split Text** (`text: String, separator: String`) - Returns the text chopped into a list wherever the separator appears.
- **Text To Int** (`text: String`) - Returns the text parsed into a whole number.
- **Text To Float** (`text: String`) - Returns the text parsed into a decimal number.
- **Pad Number** (`number: String, digits: String`) - Returns the number padded with leading zeros, e.g. for scores like 007.
- **Repeat Text** (`text: String, count: String`) - Returns the text repeated the given number of times.
- **Current State** (`target: String`) - Returns the name of the state machine's current animation state.
- **Tree Parameter** (`path: String, target: String`) - Returns the current value of an AnimationTree parameter.
- **Ramped** (`start: String, per_minute: String, limit: String`) - A value that drifts over time and stops at a limit - 'Every Ramped(2, -0.3, 0.5) seconds' is a spawner that speeds up as the run goes on. Call Start Ramp Clock when the run begins.
- **Tiles** (`count: String`) - A distance in tiles: Tiles(3) is three tiles in pixels, sized by the eventforge/tile_size project setting (default 16). Set it once and every distance can speak in tiles.

### Collision (`res://addons/eventforge/registration/modules/collision_aces.gd`)
Collision vocabulary (the "Helper ACEs for collisions").

#### Conditions
- **Is By Wall** - True when this 2D character is pressing against a wall.
- **Is Touching Ceiling** - True when this 2D character is touching a ceiling above.
- **Is Jumping** - True while this 2D character is moving upward - the rising half of a jump. In 2D, Y grows downward, so going up is a NEGATIVE vertical speed.
- **Is Falling** - True while this 2D character is moving downward - the falling half of a jump, or walking off a ledge.
- **Is Moving** - True while this 2D character has any sideways speed - the walk-or-idle question an animation state usually asks.
- **Overlaps Body** (`body: String, target: String`) - True when this Area2D is overlapping the given physics body.
- **Overlaps Area** (`area: String, target: String`) - True when this Area2D is overlapping the given other area.
- **Has Overlapping Bodies** (`target: String`) - True when this Area2D currently overlaps any physics body.
- **Has Overlapping Areas** (`target: String`) - True when this Area2D currently overlaps any other area.
- **Is On Collision Layer** (`layer: String, target: String`) - True when this object occupies the given collision layer.
- **Is By Wall (3D)** - True when this 3D character is pressing against a wall.
- **Is Touching Ceiling (3D)** - True when this 3D character is touching a ceiling above.
- **Is Jumping (3D)** - True while this 3D character is moving upward. In 3D, Y grows upward, so going up is a POSITIVE vertical speed - the opposite sign from the 2D question.
- **Is Falling (3D)** - True while this 3D character is moving downward.
- **Is Moving (3D)** - True while this 3D character has any speed along X - the walk-or-idle question for a side-on 3D mover.
- **Has Overlapping Bodies (3D)** (`target: String`) - True when this 3D Area is currently overlapping at least one physics body.

#### Actions
- **Set Collision Layer Bit** (`layer: String, enabled: String, target: String`) - Turns a collision layer on or off, controlling what this object sits on.
- **Set Collision Mask Bit** (`mask: String, enabled: String, target: String`) - Turns a collision mask bit on or off, controlling what this object detects.
- **Enable Collision Shape** (`target: String`) - Switches this collision shape back on so it can collide again.
- **Disable Collision Shape** (`target: String`) - Switches this collision shape off, safely, so it stops colliding.

#### Expressions
- **Wall Normal** - Returns the direction the touched wall is facing, for wall-jumps or sliding.
- **Floor Normal** - Returns the direction the floor is facing, useful on slopes.
- **Slide Collision Count** (`target: String`) - Returns how many things the character hit during its last move.
- **Last Slide Collider** - Returns the node the character bumped into last, or nothing if none.
- **Last Slide Normal** - Returns the surface direction from the character's last collision.
- **Overlapping Bodies** (`target: String`) - Returns the list of physics bodies currently inside this Area2D.
- **Overlapping Areas** (`target: String`) - Returns the list of areas currently overlapping this Area2D.
- **Wall Normal (3D)** - Fires with the direction a 3D body just bumped into a wall, useful for wall-jumps or ricochets.
- **Floor Normal (3D)** - Fires with the slope direction of the floor a 3D body is standing on, handy for slope-aware movement.
- **Overlapping Bodies (3D)** (`target: String`) - Fires with the list of physics bodies currently inside this 3D Area.

### Comparison (`res://addons/eventforge/registration/modules/comparison_aces.gd`)
comparing values of every kind

#### Conditions
- **Text Equals (ignore case)** (`a: String, b: String`) - True when two pieces of text are the same, treating capitals and lowercase as identical - what you want for a typed-in name or a cheat code.
- **Text Begins With** (`text: String, prefix: String`) - True when text starts with something - filtering commands, ids with a prefix, or file paths.
- **Text Is Empty** (`text: String`) - True when text has no characters at all. Note that a single space is NOT empty.
- **Text Is Blank** (`text: String`) - True when text is empty OR only spaces - the check a name-entry box actually wants, since "   " should not count as a name.
- **Text Matches Pattern** (`text: String, pattern: String`) - True when text fits a wildcard pattern, where * stands for any run of characters and ? for one - simpler than a regular expression for things like "level_*".
- **Text Is One Of** (`text: String, options: String`) - True when text is one of a list of accepted values - one row instead of a chain of "or equals" conditions.
- **Text Sorts Before** (`a: String, b: String`) - True when the first text comes before the second alphabetically, ignoring case - for ordering names or building a sorted list.
- **Text Is A Number** (`text: String`) - True when this text would convert to a number cleanly. Ask it BEFORE converting, so a typo can never arrive as a silent 0 and the sheet bet nothing. Spaces around the number are ignored; empty text is not a number.
- **Text Is A Whole Number** (`text: String`) - True when this text would convert to a WHOLE number cleanly - a count, a level, a slot index. "12" passes and "12.5" does not, which is the only difference from Text Is A Number.
- **Contains Any Of** (`text: String, options: String`) - True when the text contains at least ONE of the listed pieces - a chat filter, a keyword-triggered line, a tag-gated card. Unlike Text Is One Of, which needs the WHOLE text to equal an entry, this looks INSIDE the text. Matching is case-sensitive, and an empty list is never a match.
- **Contains All Of** (`text: String, options: String`) - True only when the text contains EVERY listed piece - a combo whose rule text names two keywords, a search box where all the words must match. An empty list counts as true, because nothing is missing.
- **Contains None Of** (`text: String, options: String`) - True when the text contains none of the listed pieces - the accept-this-name branch, written as the thing you want to act on instead of an Else. An empty list always passes.
- **Values Are Near** (`a: String, b: String, tolerance: String`) - True when two numbers are close enough to count as the same. Decimal numbers almost never land exactly equal after any arithmetic, so this is the comparison you usually want instead of ==.
- **Is Outside Range** (`value: String, min: String, max: String`) - True when a value falls below the low bound or above the high one - the mirror of Is Between Values, for culling things that wandered off.
- **Is Positive** (`value: String`) - True when a number is greater than zero. Zero itself is neither positive nor negative.
- **Is Negative** (`value: String`) - True when a number is less than zero - a spent balance, a reversed direction, a debt.
- **Is Even** (`value: String`) - True for even whole numbers - alternating rows, checkerboards, every-other-turn rules.
- **Is Odd** (`value: String`) - True for odd whole numbers - the other half of an alternating pattern.
- **Is Multiple Of** (`value: String, divisor: String`) - True every Nth number - a milestone at every 10 kills, a wave every 5 rounds. Guards against a divisor of zero, which would otherwise crash.
- **Is A Whole Number** (`value: String`) - True when a decimal number has nothing after the point - useful for snapping checks and grid alignment.
- **Vectors Are Equal** (`a: String, b: String`) - True when two vectors are the same allowing for rounding. Comparing positions with == almost never works, because any arithmetic leaves a tiny remainder.
- **Is Within Distance** (`a: String, b: String, distance: String`) - True when two points are no further apart than a distance - proximity, aggro range, "close enough to interact".
- **Is Farther Than** (`a: String, b: String, distance: String`) - True when two points are further apart than a distance - despawning strays, dropping a chase, culling what nobody can see.
- **Points The Same Way** (`a: String, b: String, threshold: String`) - True when two directions broadly agree - is the enemy facing me, am I moving the way I am aiming, is this surface a floor. The Agreement number is how forgiving to be.
- **Is Longer Than** (`vector: String, length: String`) - True when a vector's length beats a number - "am I actually moving", "is this push hard enough".
- **Colors Are Equal** (`a: String, b: String`) - True when two colors match allowing for rounding - the same reason vectors need it, since colors are four decimal numbers.
- **Value Is Of Type** (`value: String, type: String`) - True when a value is of a particular kind - guarding code that is about to treat something as a number, a list, or text.
- **Values Are The Same Type** (`a: String, b: String`) - True when two values are of the same kind, so comparing them means anything. Text and a number are never equal, however similar they look.
- **Object Is Class** (`object: String, class_name: String`) - True when an object is of an engine class, or something derived from it - so a CharacterBody2D also counts as a Node2D. Checks for nothing-there first, so it is safe on an empty reference.
- **Is Nothing** (`value: String`) - True when there is nothing there: no value at all, empty text, an empty list (including an empty Split Text result), or an empty record - one row whatever the value turns out to be. A 0 is NOT nothing, because a score of zero is a real value, and neither is text made only of spaces (that is Text Is Blank).
- **Has Something** (`value: String`) - True when there IS something there - a name was typed, the inventory has items, the save slot was written, the item slot is filled. The exact opposite of Is Nothing, for the times the filled case is the one you want to act on.
- **Is The Same Object** (`a: String, b: String`) - True when two references point at the very same object, not merely one that looks alike - "did I just hit MYSELF", "is this the node I already picked".
- **Object Still Exists** (`object: String`) - True when an object has not been freed. A variable holding a deleted node is NOT null - it is a dangling reference, and touching it crashes. This is the check that catches it.
- **Object Has Method** (`object: String, method: String`) - True when an object can do something - the duck-typing check that lets one hit apply to anything with take_damage, without caring what class it is.
- **Object Has Property** (`object: String, property: String`) - True when an object carries a named property, so a sheet can read it without risking an error on something that has no such field.

#### Expressions
- **Text Natural Order** (`a: String, b: String`) - Compares two pieces of text the way a person would read numbers in them, so "item2" comes before "item10". Negative if the first sorts earlier, 0 if equal, positive if later.
- **Number From Text** (`text: String, fallback: String`) - Reads a number out of text, or hands back the fallback YOU chose - never a surprise zero. Pair it with Text Is A Number when the two cases need different rows. The text is read twice in the emitted line, so keep it a plain read and not something that changes the game.
- **Whole Number From Text** (`text: String, fallback: String`) - Reads a whole number out of text, or hands back your fallback. "12.5" is not a whole number, so it lands on the fallback rather than quietly becoming 12 - when you want that rounding, use Number From Text and round the result yourself.
- **Compare Result** (`a: String, b: String`) - Gives -1, 0 or 1 for "less than, equal to, greater than" in one value - the shape a sort comparison wants, instead of branching twice.
- **Value Type Name** (`value: String`) - The name of a value's type as readable text ("int", "Vector2", "Dictionary") - handy in a debug print when something is not what you expected.

### Composition (`res://addons/eventforge/registration/modules/composition_aces.gd`)
Systems vocabulary (composition / ECS-lite queries over groups).

#### Conditions
- **Any Entity In Group** (`group: String`) - True when at least one node is in the group (any entity of that type exists).
- **Is In Both Groups** (`node: Node, group_a: String, group_b: String`) - True when an entity belongs to both groups (has both tags/components).

#### Actions
- **Run On Tagged Entities** (`group: String, tag: String, method: String`) - Calls a method on every entity in a group that also has a tag - a whole system in one action.

#### Expressions
- **Entities In Group** (`group: String`) - Every node in a group, as an array - loop it with For Each to run a system over that entity type.
- **Entities In Both Groups** (`group_a: String, group_b: String`) - Every node that is in BOTH groups at once, as an array (an archetype like alive AND poisoned).
- **Count In Both Groups** (`group_a: String, group_b: String`) - How many nodes are in both groups at once.
- **First In Both Groups** (`group_a: String, group_b: String`) - The first node in both groups, or nothing if there is none.

### Console (`res://addons/eventforge/registration/modules/console_aces.gd`)
Console vocabulary (browser/console-style logging).

#### Actions
- **Log** (`message: String, level: String`) - Writes a message to the console as a Message, Warning, Error, or Rich text - one action for all four.
- **Log If** (`condition: String, message: String, level: String`) - Writes a message to the console only when a condition is true - as a Message, Warning, or Error.
- **Log (Debug Builds Only)** (`message: String, level: String`) - Writes to the console only in debug builds - the line is skipped entirely in an exported release game.
- **Log Value** (`label: String, value: String, level: String`) - Prints a value tagged with a name, e.g. "health = 80", so debug lines are easy to tell apart.

#### Expressions
- **To Text** (`value: String`) - Turns any value (numbers, vectors, arrays…) into readable text for a log message.

### Controls (`res://addons/eventforge/registration/modules/controls_aces.gd`)
Controls (R23-R29): analog, gamepads by number, touch and gestures,

#### Conditions
- **Compare Axis** (`axis: String, device: String, comparison: String, value: String`) - How far a stick or trigger is pushed, on the -100 to 100 scale the Gamepad object shows.
- **Compare Axis (either way)** (`axis: String, device: String, comparison: String, value: String`) - The same check ignoring which way the stick went - pushed this far in either direction.
- **Is Button Down** (`action: String`) - True while the control is held, counting only a binding that matches exactly - the way a menu tells one stick direction from another.
- **On Gamepad Button Pressed** (`device: String, button: String`) - True the moment a named gamepad's button goes down, used inside an input event - the local-multiplayer check.
- **On Gamepad Button Released** (`device: String, button: String`) - True the moment a named gamepad's button is let go, used inside an input event.
- **Has Gamepads** - True while at least one gamepad is plugged in - switch the control hints, offer the join screen.
- **On Drag** - True while a finger is moving across the screen, used inside an input event.
- **On Pinch** - True on a two-finger pinch or spread, used inside an input event - zoom the map.
- **On Pan** - True on a two-finger pan (or a trackpad scroll), used inside an input event.
- **On Double-Click** - True on the second click of a double-click, used inside an input event - open the item, rename the file.
- **Has Action** (`action: String`) - True when the Input Map knows this control - guard a row that names one the project might not have.
- **Key Is A Held-Down Repeat** - True when this key event is the operating system repeating a held key rather than a fresh press.
- **Compare Acceleration** (`sensor_axis: String, comparison: String, value: String`) - Tilt as a condition - X above zero is tilted to the right, Y is tilted forward. Reports 0 on desktop.

#### Actions
- **Vibrate Gamepad For** (`device: String, weak: String, strong: String, seconds: String`) - Rumbles one numbered gamepad for a moment - the sheet's phrasing for the thing every hit and every pickup wants.
- **Wait For The Next Key Or Button** (`name: String`) - Pauses this event until the player presses anything, and remembers what it was - the first step of every rebind screen.
- **Clear The Bindings Of** (`action: String`) - Takes every key and button off a control, so the next Bind is the only one left.
- **Bind Control To** (`action: String, event: String`) - Binds a key or a button to a control - the second step of a rebind screen.
- **Reset All Bindings** - Throws away every rebind and puts the project's own Input Map back - the Reset button.
- **Set Deadzone Of** (`action: String, deadzone: String`) - How far a stick must move before the control counts - the drift slider a controller options screen needs.
- **Save Bindings** (`path: String`) - Writes every control's bindings to a plain settings file under user://, so a rebind survives a restart.
- **Load Bindings** (`path: String`) - Puts saved bindings back on start-up. Does nothing when there is no saved file, so a first run keeps the project's own.
- **Simulate Control Pressed** (`action: String`) - Presses a control as though the player had - how an AI, a replay or a tutorial drives the same code the player does.
- **Simulate Control Released** (`action: String`) - Lets go of a control that Simulate Control Pressed is holding.
- **Simulate Input** (`event: String`) - Feeds a whole key, button or touch into the game as if it had just happened.
- **Stop This Input Here** (`target: String`) - Nothing after this event sees the key or the click - the click was for this and nothing else.
- **Request Pointer Lock** - Hides the cursor and locks it to the window, so mouse motion drives looking around.
- **Set Cursor Visible** - Gives the cursor back - pause menus, dialogs, quitting to the map.
- **Set Cursor Invisible** - Hides the cursor while leaving it free to move - a game that draws its own crosshair.
- **Keep Cursor Inside The Window** - The cursor stays visible but cannot leave the window - strategy games on two monitors.
- **Move Cursor To** (`position: String`) - Teleports the pointer - snap it to a menu item, re-centre it after a cutscene.

#### Expressions
- **Axis Of Gamepad** (`device: String, axis: String`) - How far a stick is pushed, -100 to 100 (Godot counts the same travel from -1 to 1).
- **Button Of Gamepad** (`action: String`) - How hard a trigger or a control is held, 0 to 100 (Godot counts the same pull from 0 to 1).
- **Touch Index** - Which finger this touch event is about, counting from 0 - multi-touch controls tell them apart by it.
- **Pinch Factor** - How much the pinch grew or shrank this event - multiply the zoom by it.
- **Pan Delta** - How far the two-finger pan moved this event, as a Vector2.
- **Key Name** (`event: String`) - The readable name of a key or button ("Space", "A button") - show it next to each row of a rebind screen.
- **Acceleration** - How the device is being moved right now, gravity included, as x, y, z. Reports 0 on desktop.
- **Gravity Direction** - Which way is down for the device, as x, y, z - how it is being held. Reports 0 on desktop.
- **Rotation Rate** - How fast the device is being turned, as x, y, z (the gyroscope). Reports 0 on desktop.
- **Magnetic Field** - The magnetic field around the device, as x, y, z (the compass). Reports 0 on desktop.

### Core (`res://addons/eventforge/registration/modules/core_aces.gd`)
Core vocabulary (the Phase-1 surface, fully migrated).

#### Triggers
- **On Ready** - Runs once when this node first enters the scene, ideal for setup and initial values.
- **Every Frame** - Runs every rendered frame, perfect for continuous movement, timers, or polling input.
- **Every Physics Tick** - Runs every fixed physics step, the right place for physics-based movement and forces.
- **After Every Frame (post-tick)** - Runs once AFTER every node has processed this frame - for logic that must come last, like a camera that follows after movement, or end-of-frame cleanup.
- **After Every Physics Tick** - Runs once AFTER every node has finished its physics step this tick - the physics sibling of post-tick.
- **On Created** - Runs the moment this object is added to the scene - before its children exist, which is what makes it earlier than On Ready.
- **On Destroyed** - Runs when this object leaves the scene - the place to let go of what it was holding, save its state, or tell others it is gone.
- **On Draw** - Runs when this object is asked to paint itself - the only place the drawing actions may be used. Ask for a repaint with Queue Redraw.
- **On Close Requested** - Runs when the player clicks the window's close button (X) or asks to quit - the place to save progress or pop a confirm dialog before exiting.
- **On Body Entered** (`body: Node`) - Runs when a physics body enters this 2D Area, e.g. detecting the player walking into a trigger.
- **On Area Entered** (`area: Area2D`) - Runs when another 2D Area overlaps this one, e.g. a hitbox touching a hurtbox.
- **On Body Exited** (`body: Node`) - Runs when a physics body leaves this 2D Area, e.g. the player stepping out of a zone.
- **On Area Exited** (`area: Area2D`) - Runs when another 2D Area stops overlapping this one.
- **On Signal** (`signal_name: String, args: String`) - Runs whenever the named signal fires, letting you react to any custom or built-in event.
- **On Editor Run** - Runs inside the editor while building, useful for tool scripts and live previews.
- **On Input** - Runs on every input event the node receives, for catching keys, mouse, or touch.
- **On Unhandled Input** - Runs on input no UI element consumed, ideal for gameplay controls that ignore menu clicks.
- **On Unhandled Key Input** - Runs on keyboard input no UI element consumed - the keys-only sibling of On Unhandled Input, so mouse and gamepad traffic never wakes it.
- **On Input On This Object** - Runs when input lands on this object's own collision shape - a click, a drag or a touch that hit it rather than the world behind it.
- **On Timeout** - Runs when this Timer counts down to zero, e.g. ending a cooldown or spawn delay.
- **On Animation Finished** (`anim_name: String`) - Runs when an animation finishes playing, e.g. chaining the next animation or action.
- **On Tree Entered** - Runs when this node is added into the scene tree.
- **On Tree Exiting** - Runs just before this node leaves the scene tree, a good spot for cleanup.
- **On Tree Exited** - Runs after this node has been removed from the scene tree.
- **On Renamed** - Runs when this node's name changes in the scene tree.
- **On Child Entered Tree** (`node: Node`) - Runs when a child node is added beneath this one, e.g. reacting to spawned items.

#### Conditions
- **Is Action Pressed** (`action: String`) - True while the named input action is held down, for continuous controls like running.
- **On Action Just Pressed** (`action: String`) - True only on the frame the named input action was first pressed, for jumps or single taps.
- **On Action Just Released** (`action: String`) - True only on the frame the named input action was let go, for charge-and-release moves.
- **Always** - Always true, so its actions run every time the event is checked.
- **Is On Floor** - True when this 2D character body is standing on the ground, used to gate jumping.
- **Has Group Member** (`group: String`) - True when this node belongs to the named group, for tagging and identifying objects.
- **Compare variable** (`var_name: String, op: String, value: String`) - True when a variable compares against a value as you specify, for branching on game state.
- **Is Timer Stopped** (`target: String`) - True when the Timer is not currently running.
- **Is Animation Playing** (`target: String`) - True while the AnimationPlayer is playing an animation.
- **RayCast Is Colliding (2D)** (`target: String`) - True when the RayCast2D is currently hitting something in its path.
- **World Raycast Hits? (2D)** (`from: String, to: String`) - True when a ray drawn between two points hits any physics object.

#### Actions
- **Set value** (`var_name: String, value: String`) - Sets a variable to a value you give, the basic way to store game state.
- **Add to** (`var_name: String, amount: String`) - Adds an amount to a variable, e.g. increasing score or health.
- **Subtract from** (`var_name: String, amount: String`) - Subtracts an amount from a variable, e.g. spending money or taking damage.
- **Multiply Variable** (`var_name: String, amount: String`) - Multiplies a variable by a factor, e.g. scaling speed or applying a bonus.
- **Divide Variable** (`var_name: String, amount: String`) - Divides a variable by a value, e.g. halving a stat.
- **Modulo Variable** (`var_name: String, amount: String`) - Replaces a variable with its remainder over a value, e.g. cycling an index that must stay in range.
- **Print Log** (`message: String`) - Prints a message to the output console, useful for debugging and checking values.
- **Queue Free** - Removes this node safely at the end of the frame, e.g. destroying a defeated enemy.
- **Return Value** (`value: String`) - Returns a value from the current function back to whatever called it.
- **Return (stop here)** - Exits the current function immediately, skipping any remaining actions.
- **Call Function** (`function_name: String, args: String`) - Calls one of your sheet functions with arguments, for reusing logic across events.
- **Emit Signal** (`signal_name: String, args: String`) - Fires a signal so other events or nodes can react, the way to broadcast custom events.
- **Set Position** (`pos: String, target: String`) - Places a 2D node at an exact position, e.g. teleporting or snapping to a spot.
- **Move By** (`offset: String, target: String`) - Shifts a 2D node by an offset from where it is, for simple step-based movement.
- **Set Rotation (Degrees)** (`degrees: String, target: String`) - Sets a 2D node's rotation in degrees, e.g. aiming or facing a direction.
- **Move And Slide** - Moves the character body using its velocity and slides along walls; call each physics frame.
- **Set Velocity** (`vel: String`) - Sets the character's full movement velocity to the Vector2 you provide.
- **Set Velocity X** (`x: String`) - Sets only the horizontal speed of the character, leaving vertical motion untouched.
- **Set Velocity Y** (`y: String`) - Sets only the vertical speed of the character (negative values move upward).
- **Add To Velocity** (`delta_v: String`) - Adds a Vector2 to the current velocity, handy for nudges, knockback or boosts.
- **Apply Gravity (with terminal velocity)** (`gravity: String, max_fall: String, delta_t: String`) - Pulls the character downward each frame but caps the maximum falling speed.
- **Apply Gravity** (`gravity: String, delta_t: String`) - Adds constant downward acceleration to the character each frame, making it fall.
- **Accelerate Velocity X Toward** (`target_speed: String, rate: String, delta_t: String`) - Smoothly eases horizontal speed toward a target, giving gradual acceleration and braking.
- **Accelerate Velocity Y Toward** (`target_speed: String, rate: String, delta_t: String`) - Smoothly eases vertical speed toward a target value over time.
- **Limit Speed** (`max_speed: String`) - Caps how fast the body can travel in any direction, keeping diagonal movement no faster than straight movement.
- **Ignore Collisions With** (`other: String`) - Lets this body pass through one other body from now on - a moving platform it rides, or the object that just fired it.
- **Rotate Toward** (`angle: String, rate: String, delta_t: String`) - Turns the object toward an angle a little each frame instead of snapping to it, taking the shorter way round.
- **Apply Central Impulse** (`impulse: String, target: String`) - Gives a rigid body an instant push in a direction, like a kick or explosion.
- **Apply Central Force** (`force: String, target: String`) - Applies a continuous push to a rigid body each physics frame, like steady thrust.
- **Apply Torque Impulse** (`torque: String, target: String`) - Gives a rigid body an instant spin, making it start rotating.
- **Start Timer** (`time: String, target: String`) - Starts a Timer node counting down, optionally with a custom duration.
- **Stop Timer** (`target: String`) - Stops a running Timer so it no longer counts down or fires.
- **Play Animation** (`anim_name: String, target: String`) - Plays a named animation on an AnimationPlayer, e.g. for walking or attacking.
- **Stop Animation** (`target: String`) - Stops the currently playing animation on the AnimationPlayer.
- **Force RayCast Update (2D)** (`target: String`) - Immediately re-checks the raycast this frame instead of waiting for physics.
- **Query Bodies At Point (2D)** (`into: String, point: String, max_results: String`) - Collects every physics object at a world point into a variable - like tapping the world with a finger.
- **Query Bodies In Circle (2D)** (`into: String, center: String, radius: String, max_results: String`) - Collects every physics object inside a circle into a variable - explosion radii, pickup magnets, proximity checks.
- **Query Bodies In Rectangle (2D)** (`into: String, center: String, size: String, max_results: String`) - Collects every physics object inside a rectangle into a variable - selection boxes, damage zones, room checks.
- **Save Setting** (`path: String, section: String, key: String, value: String`) - Writes a value into a config file on disk so it persists between play sessions.
- **Load Setting Into Variable** (`var_name: String, path: String, section: String, key: String, default: String`) - Reads a saved value from a config file into a variable, with a fallback default.
- **Set Window Title** (`title: String`) - Changes the text shown in the game window's title bar.
- **Set Clipboard Text** (`text: String`) - Copies text to the operating system clipboard for pasting elsewhere.
- **Reparent To** (`new_parent: String`) - Moves this node under a new parent while keeping its on-screen position.

#### Expressions
- **Velocity X** - Returns the character's current horizontal speed in pixels per second.
- **Velocity Y** - Returns the character's current vertical speed in pixels per second.
- **RayCast Collider (2D)** (`target: String`) - Returns the node the raycast is currently hitting, or nothing if clear.
- **RayCast Hit Point (2D)** (`target: String`) - Returns the world point where the raycast hit something.
- **RayCast Hit Normal (2D)** (`target: String`) - Returns the surface direction (normal) at the raycast's hit point.
- **World Raycast Point (2D)** (`from: String, to: String, target: String`) - Returns where a one-shot ray between two points strikes a surface.
- **World Raycast Collider (2D)** (`from: String, to: String, target: String`) - Returns the object a one-shot ray between two points hits, or nothing.
- **Window Size** - Returns the game window's current size in pixels.
- **Screen Size** - Returns the size of the player's monitor in pixels.
- **Clipboard Text** - Returns whatever text is currently on the system clipboard.
- **Performance Monitor** (`monitor: String`) - Returns a live engine performance reading, like FPS or memory, for debugging.
- **Static Memory (bytes)** - Returns how much memory the game is currently using, in bytes.
- **Format Time (mm:ss)** (`seconds: String`) - Turns a number of seconds into a tidy mm:ss string for timers and clocks.
- **System Time String** - Returns the player's current clock time as a text string.
- **System Date String** - Returns the player's current calendar date as a text string.

### Dev (`res://addons/eventforge/registration/modules/dev_aces.gd`)
Developer helper vocabulary (the everyday dev tools).

#### Conditions
- **Frame Took Longer Than** (`ms: String`) - True on a frame that took longer than your budget, which is the hitch caught as it happens. Needs a per-frame trigger.
- **FPS Below For** (`fps: String, seconds: String`) - True once the framerate has stayed under your floor for the whole stretch you name, which tells a real performance drop apart from one stuttery frame. Needs a per-frame trigger.
- **Is In Group** (`target: String, group: String`) - True when the given node currently belongs to the named group.
- **Has Metadata** (`target: String, name: String`) - True when the object has metadata stored under the given key.
- **Has Node** (`target: String, path: String`) - True when a node exists at the given path under this one.
- **Is Ancestor Of** (`target: String, node: String`) - True when this node is somewhere above the other node in the tree.

#### Actions
- **Print** (`value: String`) - Prints a value to the Output console, useful for debugging what's happening.
- **Print Labeled** (`label: String, value: String`) - Prints a value preceded by a label so you can tell debug messages apart.
- **Print Rich (BBCode)** (`value: String`) - Prints colored or bold text to the Output console using BBCode formatting.
- **Push Warning** (`message: String`) - Logs a warning message that appears in Godot's debugger panel.
- **Push Error** (`message: String`) - Logs an error message that appears in Godot's debugger panel.
- **Assert** (`condition: String, message: String`) - Crashes during testing if a condition isn't true, catching bugs early; removed from release.
- **Print Scene Tree** - Prints the whole scene's node hierarchy to the output log for debugging.
- **Breakpoint (pause debugger)** - Pauses the game in the debugger right here so you can inspect things.
- **Remember In Trail** (`value: String, trail: String, keep: String`) - Records a value into a named rolling history you can dump, chart, or check when something goes wrong.
- **Log Trail** (`trail: String`) - Prints the whole trail to the Output console, so the seconds before a bug arrive with the bug.
- **Save Trail To CSV** (`trail: String, path: String`) - Writes a trail to a two-column CSV file you can open in a spreadsheet and plot.
- **Clear Trail** (`trail: String`) - Forgets everything a trail recorded, so the next run starts from nothing.
- **Start Measuring** (`named: String`) - Starts a named stopwatch. Pair it with Stop Measuring around the work you suspect.
- **Stop Measuring** (`named: String`) - Stops a named stopwatch and files the result, keeping the last, the average and the worst reading for that name.
- **Log Measurements** - Prints every named measurement taken so far with its last, average and peak cost - the report you paste into a bug or a devlog.
- **Clear Measurements** - Throws away every measurement recorded so far, so a fresh run starts from a clean slate.
- **Add To Group** (`target: String, group: String`) - Tags a node into a named group so you can find or affect it later.
- **Remove From Group** (`target: String, group: String`) - Untags a node from a named group when it should no longer belong.
- **Call Method On Group** (`group: String, method: String`) - Calls the named method on every node in a group at once.
- **Call Method On Group (with value)** (`group: String, method: String, args: String`) - Calls a method with a value on every member of a group at once - a decoupled broadcast that carries data.
- **Set Metadata** (`target: String, name: String, value: String`) - Stores a custom named value on an object as hidden metadata.
- **Remove Metadata** (`target: String, name: String`) - Deletes a stored metadata value from an object by its key.

#### Expressions
- **Trail Values** (`trail: String`) - Returns the whole trail as an array, oldest first - feed it to a chart, a table, or an array action.
- **Lowest In Trail** (`trail: String`) - The smallest value recorded in a trail, which is the spike a per-frame watch blinked past. An empty trail reads as INF.
- **Highest In Trail** (`trail: String`) - The largest value recorded in a trail. An empty trail reads as -INF.
- **Average In Trail** (`trail: String`) - The mean of every number recorded in a trail - a rolling average that is as useful in gameplay as in debugging. An empty trail reads as 0.
- **Newest In Trail** (`trail: String`) - The most recently recorded value in a trail, or 0 when nothing has been recorded yet.
- **Trail Length** (`trail: String`) - How many values a trail is currently holding, which tops out at the Keep you gave it.
- **Last Measured (ms)** (`named: String`) - How many milliseconds the most recent run of a named measurement took.
- **Average Measured (ms)** (`named: String`) - The mean cost in milliseconds across every run of a named measurement, which is the number to quote when you claim an optimization worked.
- **Peak Measured (ms)** (`named: String`) - The worst run of a named measurement in milliseconds, which is usually the one the player felt.
- **Get First Node In Group** (`group: String`) - Returns the first node found in a named group, or nothing if empty.
- **Count Nodes In Group** (`group: String`) - Returns how many nodes are currently in the named group.
- **Sum In Group** (`group: String, property: String`) - Returns the total of a numeric property added up across every group member.
- **Average In Group** (`group: String, property: String`) - Returns the average of a numeric property across all members of a group.
- **Lowest In Group** (`group: String, property: String`) - Returns the smallest value of a property among all group members.
- **Highest In Group** (`group: String, property: String`) - Returns the largest value of a property among all group members.
- **Get Metadata** (`target: String, name: String`) - Returns a custom metadata value previously stored on an object.
- **Get Parent** (`target: String`) - Returns the node directly above this one in the scene tree.
- **Get Child Count** (`target: String`) - Returns how many direct children a node currently has.
- **Get Child (by index)** (`target: String, index: String`) - Returns a node's child at the given position number, starting from zero.
- **Find Child (by name)** (`target: String, pattern: String`) - Returns a child node matching a name pattern, useful when paths vary.
- **Get Node Or Null** (`target: String, path: String`) - Returns the node at a path, or nothing instead of erroring if missing.
- **Get Scene Owner** (`target: String`) - Returns the scene that this node was saved as part of.

### Device (`res://addons/eventforge/registration/modules/device_aces.gd`)
Device input (Keyboard/Mouse/Gamepad/Touch)

#### Conditions
- **Key Is Down** (`key: String`) - True while the given keyboard key is being held down.
- **On Key Pressed (event)** (`key: String`) - True the moment a key is pressed, used inside an input event.
- **On Key Released (event)** (`key: String`) - True the moment a key is released, used inside an input event.
- **Mouse Button Is Down** (`button: String`) - True while the given mouse button is being held down.
- **Gamepad Button Is Down** (`device: String, button: String`) - True while the given gamepad button is being held down.
- **Gamepad Is Connected** (`device: String`) - True when a gamepad at the given device slot is plugged in.
- **Mouse Is Captured** - True while the cursor is locked to the window (the FPS look mode) - gate pause menus and hints on it.
- **On Mouse Button Pressed (event)** (`button: String`) - True the moment a mouse button goes down, used inside an On Input event (the click-y partner of Mouse Button Is Down).
- **On Mouse Button Released (event)** (`button: String`) - True the moment a mouse button is let go, used inside an On Input event.
- **On Mouse Wheel Up (event)** - True on a wheel-up tick, used inside an On Input event - zoom in, next weapon, scroll a list.
- **On Mouse Wheel Down (event)** - True on a wheel-down tick, used inside an On Input event.
- **Anything Is Pressed** - True while ANY key, mouse button, or gamepad input is held - press-any-key screens and idle detection.
- **Gamepad Is Recognized** (`device: String`) - True when the gamepad matches a known mapping (its buttons mean what you expect).
- **On Gamepad Button Pressed (event)** (`button: String`) - True the moment a gamepad button goes down, used inside an On Input event.
- **Touchscreen Available** - True when the device running the game has a touchscreen.
- **On Touch (event)** - True the moment a finger touches the screen, used inside an input event.
- **On Touch Released (event)** - True the moment a finger lifts off the screen, used inside an input event.
- **Action Is Bound** (`action: String`) - True when the named input action has at least one key or button bound.
- **Event Matches Action** (`event: String, action: String`) - True when an input event matches the named action, like checking for jump.

#### Actions
- **Set Mouse Mode** (`mode: String`) - Changes whether the cursor is visible, hidden, or locked to the window.
- **Vibrate Gamepad** (`device: String, weak: String, strong: String, duration: String`) - Rumbles a connected gamepad at chosen strength for a set duration.
- **Capture Mouse** - Focuses the mouse into the window: the pointer locks and hides, and motion feeds your look/aim (FPS style). Release Mouse undoes it.
- **Release Mouse** - Unfocuses the mouse: the pointer is visible and free again - pause menus, dialogs, quitting to the map.
- **Move Mouse Pointer** (`position: String`) - Teleports the mouse pointer to a window position - snap it to a menu item or re-centre after a cutscene.
- **Set Custom Cursor** (`image_path: String`) - Swaps the mouse pointer for your own image - a crosshair, a sword, a hand.
- **Clear Custom Cursor** - Restores the system's normal mouse pointer.
- **Bind Event To Action** (`action: String, event: String`) - Binds a new key, button, or input to a named action at runtime, for remapping.
- **Clear Action Bindings** (`action: String`) - Removes all key and button bindings from a named input action.

#### Expressions
- **Mouse Position (world)** (`target: String`) - Returns the mouse position in world coordinates, matching where things sit in the level.
- **Mouse Position (screen)** - Returns the mouse position in screen pixels relative to the window.
- **Gamepad Axis** (`device: String, axis: String`) - Returns how far a gamepad stick or trigger is pushed, from -1 to 1.
- **Mouse Move Delta (event)** - How far the mouse moved THIS event (a Vector2 in pixels), used inside an On Input event - the raw aim delta while the mouse is captured.
- **Mouse Position (local)** (`target: String`) - The mouse position relative to THIS node (its own coordinate space) - is the cursor inside me, and where?
- **Mouse Ray Origin (3D)** (`target: String`) - Where the cursor's picking ray starts in 3D world space (needs an active Camera3D) - pair with Mouse Ray Direction for click-to-select and click-to-move.
- **Mouse Ray Direction (3D)** (`target: String`) - The direction the cursor's picking ray travels in 3D world space (needs an active Camera3D) - cast it with a raycast to find what the mouse is over.
- **Mouse Velocity** - How fast the mouse is moving (a Vector2 in pixels per second) - flick gestures, aim sway, spin-the-wheel minigames.
- **Key Name** (`key: String`) - The readable name of a key ("Space", "Escape") - show current bindings on a rebind screen.
- **Keycode From Name** (`name: String`) - The keycode for a key name - turn saved binding text back into a key.
- **Gamepad Count** - How many gamepads are plugged in - local-multiplayer joins and control-hint switching.
- **Gamepad Name** (`device: String`) - The connected gamepad's product name ("Xbox Series Controller") - show the right button glyphs.
- **Touch Position (event)** - Returns the screen position of a touch from the current input event.
- **Action Binding Count** (`action: String`) - Returns how many keys or buttons are bound to a named action.
- **Event As Text** (`event: String`) - Returns a readable label for an input event, like Space or Left Mouse.

### Drawing (`res://addons/eventforge/registration/modules/drawing_aces.gd`)
Drawing (2D immediate-mode canvas, on any node).

#### Conditions
- **Is Auto Clear** (`node: Node`) - True when a node's canvas wipes itself every frame.

#### Actions
- **Configure Canvas** (`node: Node, width: int, height: int, auto_clear: String, coordinates: String, display_on_host: String`) - Sets up (or retunes) the drawing surface on a node - size, auto-clear mode, coordinate mode, and whether it shows on the node.
- **Clear Canvas** (`node: Node`) - Wipes the node's canvas. In persistent mode the wipe happens next frame, then strokes keep again.
- **Set Auto Clear** (`node: Node, enabled: String`) - Switches a node's canvas between per-frame wipe (telegraphs, vision cones) and persistent strokes (paint, splats).
- **Draw Line** (`node: Node, from_x: float, from_y: float, to_x: float, to_y: float, width: float, color: Color`) - Draws a line segment onto a node's canvas - attack direction indicators, lasers, aim guides.
- **Draw Circle** (`node: Node, x: float, y: float, radius: float, color: Color`) - Draws a filled circle onto a node's canvas - the classic soft blob shadow under a character.
- **Draw Ring** (`node: Node, x: float, y: float, radius: float, width: float, color: Color`) - Draws a circle outline onto a node's canvas - selection rings, blast-radius previews.
- **Draw Rect** (`node: Node, x: float, y: float, width: float, height: float, color: Color`) - Draws a filled rectangle onto a node's canvas (x/y = top-left corner).
- **Draw Dashed Line** (`node: Node, from_x: float, from_y: float, to_x: float, to_y: float, dash_length: float, gap_length: float, width: float, color: Color`) - Draws a dashed line segment onto a node's canvas - aim guides, tethers, boundary previews. Dash and gap set the on/off rhythm.
- **Draw Dashed Ring** (`node: Node, x: float, y: float, radius: float, dash_length: float, gap_length: float, width: float, color: Color`) - Draws a dashed circle outline onto a node's canvas - range rings, dashed selection markers. Same dash primitive as Draw Dashed Line, wrapped around the circle.
- **Draw Dashed Rect** (`node: Node, x: float, y: float, width: float, height: float, dash_length: float, gap_length: float, line_width: float, color: Color`) - Draws a dashed rectangle outline onto a node's canvas - selection boxes, build-placement previews, zone markers. The dash rhythm carries continuously around all four sides.
- **Draw Cone** (`node: Node, x: float, y: float, facing_deg: float, fov_deg: float, radius: float, color: Color`) - Draws a filled wedge onto a node's canvas - the attack-telegraph cone (pair with Auto Clear so it follows each frame).
- **Draw Stamp** (`node: Node, texture: Texture2D, x: float, y: float, scale_factor: float, rotation_deg: float`) - Stamps a texture onto a node's canvas - bullet holes, footprints, splats. In persistent mode they pile up like decals.
- **Draw Line Of Sight** (`node: Node, origin_x: float, origin_y: float, facing_deg: float, fov_deg: float, max_range: float, collision_mask: int, color: Color`) - Draws a character's LINE OF SIGHT as a filled fan onto a node's canvas: rays stop at walls so the shape hugs the level. Re-issue each tick with Auto Clear for a live vision cone.
- **Draw Prefab** (`node: Node, prefab: Resource, x: float, y: float, scale_factor: float, rotation_deg: float`) - Replays a DrawingPrefabResource's steps onto a node's canvas at a position, scale, and rotation - a target marker or scorch stamped anywhere.
- **Start Ribbon** (`node: Node, follow: Node, point_count: int, width: float, color: Color`) - Starts a textured ribbon on a node's canvas trailing another node - sword swooshes, skid marks, comet tails. Its update runs automatically.
- **Set Ribbon Texture** (`node: Node, follow: Node, texture: Texture2D`) - Skins a running ribbon with a texture, stretched along its length.
- **Stop Ribbon** (`node: Node, follow: Node`) - Ends the ribbon trailing a node.

#### Expressions
- **Canvas Texture** (`node: Node`) - A node's LIVE canvas texture - assign it to a TextureRect, a material, a particle, or a 3D Decal. Updates as the canvas draws.

### Editor Object (`res://addons/eventforge/registration/modules/editor_object_aces.gd`)
the Editor object (plugin lifecycle, docks, menu items, object types).

#### Triggers
- **On Plugin Enabled** - Runs when the plugin is switched on - at editor start, or the moment you tick it in Project Settings. This is where a plugin hangs its dock, adds its Tools menu item and teaches the editor its object types.
- **On Plugin Disabled** - Runs when the plugin is switched off or the editor closes. Undo here everything On plugin enabled did, or the editor keeps a dock nobody owns.
- **On Object Selected** - Runs when the user selects an object this plugin handles. The selected object arrives as `object`.
- **On Draw Over 2D Viewport** - The editor's 2D overlay pass. Draw handles, guides or labels on top of the scene with the Drawing actions - the surface arrives as `overlay`.
- **On 2D Viewport Input** - Input that lands in the editor's 2D viewport, before the viewport itself sees it. End the event with Stop This Input Here to keep the viewport from also acting on it.
- **On Draw Gizmo** - A gizmo's own paint pass - what an EditorNode3DGizmo redraws when its node moves or changes.

#### Actions
- **Add Tools Menu Item** (`title: String, handler: Callable`) - Adds an item to the editor's Project > Tools menu. Remove it again on plugin disabled or the menu keeps a dead entry.
- **Remove Tools Menu Item** (`title: String`) - Takes the plugin's item back out of Project > Tools.
- **Add Dock** (`control: Control, slot: int`) - Hangs a Control in one of the editor's dock slots. Remove it on plugin disabled - a dock left behind survives the plugin.
- **Remove Dock** (`control: Control`) - Takes a dock back out of the editor.
- **Add Object Type** (`type_name: String, base: String, script: Script, icon: Texture2D`) - Teaches the editor a new object type, so it shows up in Create Node like a built-in one.
- **Remove Object Type** (`type_name: String`) - Takes a custom object type back out of the Create Node dialog.
- **Add Inspector Plugin** (`plugin: EditorInspectorPlugin`) - Registers a custom Inspector drawer, so your own fields appear in the Inspector.
- **Remove Inspector Plugin** (`plugin: EditorInspectorPlugin`) - Takes a custom Inspector drawer back out.
- **Redraw Viewport Overlays** - Asks the editor to run the overlay pass again, so On draw over 2D viewport repaints.

#### Expressions
- **Editor Settings** - The editor's own settings object - read a user's grid step, theme or font size from it.
- **Undo History** - The editor's undo / redo history. Put it in a local object variable and add do / undo steps to it, so Ctrl+Z reverses what your tool changed.

### File (`res://addons/eventforge/registration/modules/file_aces.gd`)
File management (read / write / JSON, plus directory + file operations).

#### Conditions
- **File Exists** (`path: String`) - True when a file exists at that path, so you can check before reading or writing it.
- **Directory Exists** (`path: String`) - True when a folder exists at that path, useful before creating or listing it.

#### Actions
- **Write Text File** (`path: String, text: String`) - Saves text to a file, overwriting anything already there (great for save data).
- **Append To File** (`path: String, text: String`) - Adds text to the end of an existing file without erasing it (handy for logs).
- **Delete File** (`path: String`) - Permanently deletes a file (or an empty folder) from disk.
- **Copy File** (`from: String, to: String`) - Copies a file from one path to another, leaving the original in place.
- **Move / Rename File** (`from: String, to: String`) - Moves or renames a file (or folder) to a new path.
- **Make Directory** (`path: String`) - Creates a folder, building any missing parent folders along the way.
- **Remove Directory** (`path: String`) - Deletes an empty folder (clear out its files first).

#### Expressions
- **Read Text File** (`path: String`) - Returns the whole file's contents as text (empty if it's missing or unreadable).
- **File Size (bytes)** (`path: String`) - Returns a file's size in bytes, or zero if the file doesn't exist.
- **List Files** (`path: String`) - Returns the list of file names inside a folder (empty if the folder is missing).
- **List Subdirectories** (`path: String`) - Returns the list of subfolder names inside a folder.

### Gradient Curve (`res://addons/eventforge/registration/modules/gradient_curve_aces.gd`)
Gradient & Curve vocabulary (smooth colour ramps and shaped 0-1 curves).

#### Actions
- **Make Gradient** (`var_name: String, from: Color, to: Color`) - Builds a smooth two-colour ramp into a variable at runtime - the quick way to make a fire or sky gradient without opening the editor. For many stops, give a variable the Gradient type and edit it in the Inspector.

#### Expressions
- **Sample Gradient** (`gradient: String, position: float`) - Reads the smooth colour at a 0-to-1 position along a gradient - drive a health-bar tint, a day/night sky, a heat map from one line.
- **Sample Curve** (`curve: String, position: float`) - Reads a curve's value at a 0-to-1 position - turn a designer-drawn easing / falloff / difficulty curve into a number, no math.

### Helper (`res://addons/eventforge/registration/modules/helper_aces.gd`)
Helper vocabulary (the "structured escape hatch").

#### Conditions
- **Evaluate GDScript** (`code: String`) - True when your own GDScript boolean expression evaluates to true.
- **Is Valid** (`target: String`) - True when the object still exists and hasn't been freed.
- **Is Null** (`target: String`) - True when the value is null, meaning nothing or missing.
- **Signal Is Connected** (`source: String, signal: String, callable: String`) - True when a method is currently hooked up to listen for that signal.

#### Actions
- **Set Property** (`target: String, property: String, value: String`) - Sets any property on any node, like visible, position, or modulate.
- **Add To Property** (`target: String, property: String, value: String`) - Adds an amount to a node's property, like nudging position or raising an alpha.
- **Subtract From Property** (`target: String, property: String, value: String`) - Subtracts an amount from a node's property, like fading an alpha down.
- **Multiply Property** (`target: String, property: String, value: String`) - Scales a node's property by a factor, like growing a sprite's scale.
- **Divide Property** (`target: String, property: String, value: String`) - Divides a node's property by a value, like shrinking a sprite's scale.
- **Call Method** (`target: String, method: String, args: String`) - Calls a method on a node when you need something not in the menus.
- **Run GDScript** (`code: String`) - Drops in one line of raw GDScript for things the menus can't do.
- **Toggle Boolean** (`var_name: String`) - Flips a true/false variable to its opposite value.
- **Set Local Variable** (`name: String, value: String`) - Creates a temporary variable used only within this event.
- **Set Local Variable (typed)** (`name: String, var_type: String, value: String`) - Creates a temporary variable of a fixed type within this event.
- **Set Local Variable (inferred)** (`name: String, value: String`) - Creates a temporary variable whose type is inferred from its value, within this event.
- **Set Local Constant** (`name: String, value: String`) - Creates a named constant used only within this event.
- **Set Local Constant (typed)** (`name: String, const_type: String, value: String`) - Creates a typed named constant used only within this event.
- **Set Local Constant (inferred)** (`name: String, value: String`) - Creates a named constant whose type is inferred from its value, within this event.
- **Connect Signal** (`source: String, signal: String, callable: String`) - Wires a node's signal to run a method whenever it fires.
- **Disconnect Signal** (`source: String, signal: String, callable: String`) - Stops a signal from calling a method, so that response no longer fires.
- **Connect Signal (if not already)** (`source: String, signal: String, callable: String`) - Wires a signal only when it is not already wired, so re-running never stacks duplicate handlers.
- **Connect Signal (one-shot)** (`source: String, signal: String, callable: String`) - Wires a signal to run ONCE - the connection drops itself after it fires.
- **Emit Signal On** (`target: String, signal: String, args: String`) - Fires a signal on an object to notify everything listening for it.
- **Connect Group Signal** (`group: String, signal: String, callable: String`) - Listens to a signal on every current member of a group at once, with no reference to any of them.
- **Disconnect Group Signal** (`group: String, signal: String, callable: String`) - Stops listening to a signal on every current member of a group.
- **Set Text (formatted)** (`target: String, template: String, args: String`) - Sets a label or button's text using a format string filled with your values.

#### Expressions
- **Get Property** (`target: String, property: String`) - Reads the current value of any property on any node.
- **Call Method (value)** (`target: String, method: String, args: String`) - Calls a method on a node and uses the value it returns.
- **Get Node** (`path: String`) - Looks up another node by its scene path so you can use it.
- **Evaluate Expression** (`code: String`) - Returns the result of any GDScript expression you type in.
- **Value If (one of two values)** (`true_value: String, condition: String, false_value: String`) - Picks one of two values depending on a condition, all in one line.
- **Lambda (returns a value)** (`params: String, value: String`) - A small inline function that computes and returns a value - hand it to sort(), map(), or filter().
- **Lambda (runs a statement)** (`params: String, statement: String`) - A small inline function that runs one statement - connect it to a signal or a timer.
- **Callable of Method** (`target: String, method: String`) - A reference to a named method you can pass around, connect, or call later.
- **Bind Arguments** (`callable: String, args: String`) - Pre-fills arguments of a callable, so the receiver can call it with fewer of its own.
- **Type Of** (`value: String`) - Returns a number identifying what kind of value something is.
- **Absolute Value** (`value: String`) - Returns a number's size without its sign, so -5 becomes 5.
- **Min** (`a: String, b: String`) - Returns whichever of two numbers is smaller.
- **Max** (`a: String, b: String`) - Returns whichever of two numbers is larger.
- **Round** (`value: String`) - Rounds a number to the nearest whole number.
- **Sign** (`value: String`) - Returns -1, 0, or 1 to tell whether a number is negative, zero, or positive.
- **Move Toward** (`from: String, to: String, amount: String`) - Nudges a value toward a target by a set step, great for smooth changes.
- **Wrap** (`value: String, min: String, max: String`) - Wraps a value to stay within a range, looping past the edges back around.
- **Remap Range** (`value: String, in_min: String, in_max: String, out_min: String, out_max: String`) - Rescales a number from one range into another, like mapping 0-100 onto 0-1.
- **Square Root** (`value: String`) - Returns the square root of a number.
- **Power** (`base: String, exp: String`) - Raises a base number to an exponent power, like 2 to the 8th.
- **Floor** (`value: String`) - Rounds a number down to the nearest whole number.
- **Ceil** (`value: String`) - Rounds a number up to the nearest whole number.
- **Float Modulo** (`a: String, b: String`) - Returns the remainder after dividing one number by another.
- **Ease** (`value: String, curve: String`) - Bends a 0-to-1 value along an easing curve for smoother eased motion.
- **Snapped** (`value: String, step: String`) - Snaps a value to the nearest multiple of a step, like a grid.
- **Load Resource** (`path: String`) - Loads a scene or resource from a res:// path so you can use it.
- **Sine** (`value: String`) - Returns the sine of an angle in radians, handy for waves and circular motion.
- **Cosine** (`value: String`) - Returns the cosine of an angle in radians, handy for waves and circular motion.
- **Tangent** (`value: String`) - Returns the tangent of an angle given in radians.
- **Arc Tangent (y, x)** (`y: String, x: String`) - Returns the angle (in radians) pointing toward a given y and x direction.
- **Clamp (float)** (`value: String, min: String, max: String`) - Keeps a number from going below a minimum or above a maximum.
- **Clamp (int)** (`value: String, min: String, max: String`) - Keeps a whole number within a min and max - use this (not the float clamp) for scores, health, and ammo.
- **Wrap (int)** (`value: String, min: String, max: String`) - Wraps a whole number around a range - perfect for cycling a menu or inventory index past the ends back to the start.
- **Degrees To Radians** (`degrees: String`) - Converts an angle from degrees into radians for math functions.
- **Radians To Degrees** (`radians: String`) - Converts an angle from radians back into easier-to-read degrees.
- **Format String** (`template: String, args: String`) - Builds a text string by filling placeholders with your values, like scores.

### Host (`res://addons/eventforge/registration/modules/host_aces.gd`)
Host (behaviour-only): the parent node a behaviour is attached to.

#### Conditions
- **Host Is Valid** - True when this behavior has a live host - the parent it acts on still exists. Guard host access with it before the host is bound or after it is freed.

#### Expressions
- **Host** - The parent node this behavior is attached to (its host) - the object your behavior reads and acts on.

### Input (`res://addons/eventforge/registration/modules/input_aces.gd`)
Input management vocabulary (define + rebind + read controls).

#### Conditions
- **Has Input Action** (`action: String`) - True when an input action is registered.

#### Actions
- **Add Input Action** (`action: String`) - Creates a named input action at runtime if it does not already exist.
- **Rebind Action To Key** (`action: String, physical_keycode: int`) - Clears an action's keys and binds it to a single key - the whole key-rebinding step in one action.
- **Remove Input Action** (`action: String`) - Removes a runtime input action entirely (the partner of Add Input Action).
- **Rebind Action To Mouse Button** (`action: String, button: String`) - Clears an action's bindings and binds it to a mouse button - the whole rebind step in one action.
- **Rebind Action To Gamepad Button** (`action: String, button: String`) - Clears an action's bindings and binds it to a gamepad button - keyboard, mouse, and gamepad rebinding all have a one-step action.
- **Set Action Deadzone** (`action: String, deadzone: String`) - How far a stick must move before the action counts - the drift-vs-responsiveness slider every controller options menu needs.
- **Restore Default Bindings** - Throws away every runtime rebind and reloads the Input Map exactly as set in Project Settings - the Reset to Defaults button.

#### Expressions
- **Move Vector** (`left: String, right: String, up: String, down: String`) - A ready-made movement direction (a Vector2) from four actions, with analog sticks handled.
- **Move Axis** (`negative: String, positive: String`) - A single -1 to 1 axis from two actions (for left/right or up/down).
- **Action Strength** (`action: String`) - How hard an action is held, 0 to 1 (a trigger or stick reads in between).
- **Action Binding As Text** (`action: String`) - The action's first binding as readable text ("Space", "Left Mouse Button") or "unbound" - print it next to each row of a rebind screen.
- **All Input Actions** - Every registered action name (an Array) - loop it to build a rebind screen instead of hand-listing rows.

### Json (`res://addons/eventforge/registration/modules/json_aces.gd`)
JSON (serialize, parse, validate, and save / load JSON files).

#### Conditions
- **JSON Is Valid** (`text: String`) - True when the given text is valid JSON, so you can check before parsing it.

#### Actions
- **Parse JSON Into Variable** (`var_name: String, text: String`) - Parses JSON text and stores the result in a variable (null if the text is bad).
- **Save JSON File** (`path: String, value: String`) - Serializes a value to pretty JSON and writes it to a file in one step.
- **Load JSON File** (`var_name: String, path: String`) - Reads a JSON file and parses it straight into a variable.

#### Expressions
- **To JSON Text** (`value: String`) - Turns a value like a dictionary or array into compact JSON text for saving or sending.
- **To JSON Text (pretty)** (`value: String`) - Turns a value into neatly indented JSON text that's easy for humans to read.
- **From JSON Text** (`text: String`) - Reads JSON text back into a usable value, returning nothing if the text is invalid.

### Locale Asset (`res://addons/eventforge/registration/modules/locale_asset_aces.gd`)
the parts of a localised game that are NOT strings: files, voice, data cells.

#### Conditions
- **Has Voice For Language** (`key: String, folder: String, extension: String`) - True when the player's language actually ships a clip for this key - the gate under "dub it if we have it, subtitle it if we do not", so a partly dubbed build degrades on purpose instead of going silent. A player on de_AT counts the de folder as theirs.

#### Actions
- **Say Line** (`key: String, folder: String, extension: String, caption: String, target: String`) - Plays this key's clip in the player's language and holds the translated line on a label for exactly as long as the clip runs, so a longer translation is never cut off and a shorter one never lingers. A language with no clip holds the caption for its own reading time instead (about 14 characters a second, never under 1.2s), which is also the whole accessibility-subtitle path. The caption goes up with the line and comes down with it, so the two can never drift apart.

#### Expressions
- **Localized File** (`path: String`) - The path that exists for the player's language. A language variant sits beside the base file as <name>.<locale>.<ext> - sign.ja.png, sign.pt_BR.png - and a player on pt_BR falls back to sign.pt.png and then to the base file, so no variant on disk simply means the base file rather than a missing-file error. Use it when you want the PATH; Load For Language when you want the asset.
- **Load For Language** (`path: String`) - Loads the variant of an asset that matches the player's language - a translated sign, a dubbed line, a font with the glyphs that language needs, a re-lettered scene. Name the variant <name>.<locale>.<ext> beside the base file and nothing else has to change. Run it under On Language Changed: a preload freezes its choice when the script loads and never follows a live switch. A project that uses Project Settings > Localization > Remaps instead still gets its remap here, because the no-variant answer is the plain base path.
- **Voice Line Length** (`key: String, folder: String, extension: String`) - How many seconds this key's clip runs in the player's language, for pacing a cutscene off the audio rather than off a guess. A language that ships no clip answers 0.0, so a Wait built on it does not stall a subtitle-only build.
- **Reading Time Of** (`text: String, chars_per_second: String, minimum_seconds: String`) - How long a caption should stay up for text this long, with a floor so a short line is still readable. Feed it the TRANSLATED text and every language gets the time it needs - the honest answer for a toast, a tutorial hint, a bark, or a subtitle in a language you never dubbed.
- **Translated Field Of** (`record: String, field: String`) - Reads a field as a translation KEY and hands back the player's language, so one .tres serves every language and the grid never needs a column per locale. It is safe to put on a pack that still stores plain English in that cell: an entry no catalog contains comes back exactly as it was written. A key with no entry comes back as the key itself, which is how a missing translation should show up - a visible "quest.bridge.title" rather than blank text.
- **Translated Column Of Table** (`table: String, column: String`) - A whole column read as translated text, in row order - a dropdown's items, a quest log, a shop list. Column Of Table gives you the cells; this gives you the words. A row missing that field contributes empty text rather than dropping out, so the list stays the same length as the table.

### Loop (`res://addons/eventforge/registration/modules/loop_aces.gd`)
Loop control vocabulary

#### Actions
- **Break Loop** - Stops the current loop early and skips any remaining items.
- **Continue Loop** - Skips to the next item in the loop, ignoring the rest of this pass.

#### Expressions
- **Current Loop Item** - Gives you the item the loop is currently working on inside a For Each.
- **Loop Index** - Counts 0, 1, 2… for the current loop pass. Name the loop's index "loop_index" (the Loop index field on For Each / Repeat / While) and read it here.
- **Loop Index Of** (`name: String`) - Reads a NAMED loop's counter, for nested loops: give the outer loop a distinct index name and read it from inside the inner one.

### Mesh (`res://addons/eventforge/registration/modules/mesh_aces.gd`)
Mesh vocabulary (build and swap 3D meshes from events).

#### Conditions
- **Has Mesh** (`target: String`) - True when this MeshInstance3D currently shows a mesh.

#### Actions
- **Make Box Mesh** (`size: Vector3`) - Builds a box mesh of the given size and shows it on this MeshInstance3D - the simplest way to make a block at runtime.
- **Make Sphere Mesh** (`radius: float`) - Builds a sphere of the given radius and shows it on this MeshInstance3D.
- **Make Cylinder Mesh** (`radius: float, height: float`) - Builds a cylinder of the given radius and height and shows it on this MeshInstance3D.
- **Make Plane Mesh** (`size: Vector2`) - Builds a flat plane of the given size and shows it on this MeshInstance3D - a quick floor or wall.
- **Make Capsule Mesh** (`radius: float, height: float`) - Builds a capsule (a pill shape) and shows it on this MeshInstance3D - a stand-in character body.
- **Make Prism Mesh** (`size: Vector3`) - Builds a triangular prism (a wedge / ramp) and shows it on this MeshInstance3D.
- **Make Torus Mesh** (`inner_radius: float, outer_radius: float`) - Builds a torus (a ring / donut) and shows it on this MeshInstance3D.
- **Set Mesh Material** (`material: String, target: String`) - Overrides the whole mesh's material - one line to recolour or reskin the shape.
- **Clear Mesh** (`target: String`) - Removes the mesh so nothing draws on this MeshInstance3D.

#### Expressions
- **Mesh Surface Count** - How many surfaces (material slots) this mesh has - 0 when there is no mesh.
- **Mesh Size** (`target: String`) - The mesh's bounding-box size (width, height, depth) in local space - handy for fitting or spacing.

### Multiplayer (`res://addons/eventforge/registration/modules/multiplayer_aces.gd`)

#### Conditions
- **Is Host** - True on the peer that is hosting the game. Put everything that decides what is true behind this.
- **Owns This Object** - True when this peer is the one allowed to move and change this object - the player's own character rather than everybody else's copy of it.

#### Actions
- **Send Message To Everyone** (`message: String, args: String`) - Runs a message on every peer in the game, including this one when the message says so. The function must be marked as a message first.
- **Send Message To The Host** (`message: String, args: String`) - Runs a message on the host only - the peer that decides what is true, so cheats cannot be sent straight to everybody.
- **Send Message To One Peer** (`message: String, peer: String, args: String`) - Runs a message on one named peer only - a private reply, or a correction sent back to the player it is about.

#### Expressions
- **My ID** - This peer's own id. The host is always 1; everyone else gets a number when they join.

### Native 3d (`res://addons/eventforge/registration/modules/native_3d_aces.gd`)
3D vocabulary

#### Conditions
- **Is On Floor (3D)** (`target: String`) - True when a 3D character body is standing on the ground (check before jumping).
- **RayCast Is Colliding (3D)** (`target: String`) - True when a RayCast3D is currently hitting something in front of it.
- **World Raycast Hits? (3D)** (`from: String, to: String`) - True when a ray cast between two points hits anything in the 3D world.

#### Actions
- **Set Position (3D)** (`pos: String, target: String`) - Teleports a 3D node to an exact world position.
- **Move By (3D)** (`offset: String, target: String`) - Nudges a 3D node by an offset relative to its own facing (local space).
- **Rotate (3D)** (`axis: String, radians: String, target: String`) - Spins a 3D node around an axis by an angle, often using speed times delta.
- **Set Rotation (3D, Degrees)** (`degrees: String, target: String`) - Sets a 3D node's rotation directly using degree angles.
- **Look At** (`target: String`) - Turns a 3D node to face a world position (e.g. an enemy facing the player).
- **Set Scale (3D)** (`scale: String, target: String`) - Sets how big a 3D node is by changing its scale.
- **Move And Slide (3D)** (`target: String`) - Moves a 3D character body by its velocity, sliding smoothly along walls and slopes.
- **Set Velocity (3D)** (`vel: String, target: String`) - Sets a 3D character body's velocity, which Move And Slide then uses to move it.
- **Apply Central Impulse (3D)** (`impulse: String, target: String`) - Gives a 3D physics body a sudden push (e.g. a knockback or launch).
- **Make Camera Current (3D)** (`target: String`) - Switches the view to this 3D camera, making it the active one.
- **Set Camera FOV** (`degrees: String, target: String`) - Sets a 3D camera's field of view in degrees (lower zooms in, higher widens).
- **Force RayCast Update (3D)** (`target: String`) - Forces a RayCast3D to recheck immediately instead of waiting for the next frame.

#### Expressions
- **Get Position (3D)** (`target: String`) - Returns a 3D node's current world position as a Vector3.
- **Get Velocity (3D)** (`target: String`) - Returns a 3D character body's current velocity vector.
- **Input Vector** (`left: String, right: String, up: String, down: String`) - Returns a movement direction from four input actions, ideal for player movement.
- **RayCast Collider (3D)** (`target: String`) - Returns the object a RayCast3D is currently hitting.
- **RayCast Hit Point (3D)** (`target: String`) - Returns the exact world point where a RayCast3D hits something.
- **RayCast Hit Normal (3D)** (`target: String`) - Returns the surface direction at the point a RayCast3D hits.
- **World Raycast Point (3D)** (`from: String, to: String, target: String`) - Returns the world point where a ray between two points first hits something.

### Node (`res://addons/eventforge/registration/modules/node_aces.gd`)
Node manipulation + picking (build, rearrange, and select scene-tree nodes).

#### Conditions
- **Is Inside Tree** (`target: String`) - True when the node is currently part of the active scene tree.
- **Has Child Of Type** (`target: String, type: String`) - True when at least one descendant node of the given class exists beneath this node.
- **Is Animating (in object)** (`target: String`) - True when any AnimationPlayer beneath the object is currently playing.
- **Is Within Distance (of a node)** (`other: String, distance: String, target: String`) - True when another node is closer than the given number of pixels. The proximity test behind prompts, pickups and aggro ranges - pick the node, type the pixels, no parentheses-math to write.
- **Is Within Distance (choose metric)** (`other: String, distance: String, metric: String`) - Is Within Distance with a geometry dropdown: straight line, horizontal or vertical only, grid steps (Manhattan), or king moves (Chebyshev) - one condition that fits platformers, roguelikes and strategy games alike.
- **Has Service** (`service_name: String`) - True when a node is registered under this name and is still alive. Guard an optional system with it - a missing audio director then costs you a skipped row instead of a crash.
- **For Each Node That Can** (`method_name: String`) - Runs this event's actions once per node ANYWHERE in the tree that answers to a method name - the save sweep, the pause sweep, the shutdown sweep, with no list to keep in step. It walks the whole tree, so run it on an event, not every frame. Read the current one as `node`.
- **Only Once This Frame** (`key_id: String`) - True the FIRST time it is reached in a frame under this name, and false for every other time that frame - counting a physics tick as its own frame, so a row under On Physics Process is not folded in with the drawn frame around it. Fifty inventory changes then rebuild the panel once instead of fifty times. Give two rows the same name and they share one run per frame.

#### Actions
- **Add Child** (`node: String`) - Attaches another node as a child of this one at runtime, e.g. spawning a bullet.
- **Remove Child** (`node: String`) - Detaches a child node from this one without deleting it, so you can reattach it later.
- **Move Child To Index** (`node: String, index: String`) - Reorders a child to a new sibling index, changing its draw and process order.
- **Free Node** (`target: String`) - Safely deletes a node at the end of the frame, e.g. removing a dead enemy.
- **Set Node Name** (`target: String, name: String`) - Renames a node at runtime, handy for tracking or finding it later.
- **Play Animation (in object)** (`target: String, anim: String`) - Plays a named animation by auto-finding the object's AnimationPlayer for you.
- **Stop Animation (in object)** (`target: String`) - Stops the object's animation by auto-finding its AnimationPlayer.
- **Play Sprite Animation (in object)** (`target: String, anim: String`) - Plays a named sprite animation via the object's AnimatedSprite2D, found automatically.
- **Flip Sprite (in object)** (`target: String, mirrored: String`) - Mirrors the object's sprite horizontally, e.g. flipping to face left or right.
- **Set Sprite Frame (in object)** (`target: String, frame: String`) - Shows a specific frame on the object's AnimatedSprite2D, found automatically.
- **Restart Animation (in object)** (`target: String, anim: String`) - Replays a named animation from the very start, e.g. retriggering an attack.
- **Emit Particles (in object)** (`target: String, emitting: String`) - Turns the object's particle emitter on or off, found automatically.
- **Turn Toward** (`target: String, degrees_per_second: String`) - Aims this node at another one, turning at a real speed instead of snapping - the turret and the chasing enemy. Frame-rate independent; for an instant snap, give it a huge turn speed.
- **Wrap Inside The Screen** - The Asteroids rule: leave the right edge and come back on the left, off the top and back at the bottom. Nothing ever escapes the screen.
- **Bob Up And Down** (`height: String, period: String`) - Floats the node gently up and down around wherever it was resting - pickups, idle hover, a breathing menu icon. No sin() to write; run it under a per-frame trigger.
- **Push Away From** (`source: String, strength: String, target: String`) - Sets the impulse; pair with Apply Pushes under a per-frame trigger, which moves and decays it.
- **Apply Pushes** (`friction: String`) - Knockback that decays honestly (the exp form, frame-rate independent) - one row under Every Frame.
- **Pull Group Toward** (`group: String, radius: String, speed: String`) - The vacuum-pickup loop - coins fly to the player, one row.
- **Orbit Around** (`center: String, radius: String, degrees_per_second: String`) - Circles this node around another one - a shield satellite, a moon, a spinning hazard. Run it under a per-frame trigger.
- **Vanish, Respawn In** (`seconds: String`) - Hides this pickup (and pauses its Area sensing when it has any), waits, then brings it back - calling its reset() if it defines one. The health-pack-respawns-in-10s pattern as one row; it awaits, so it suspends like Wait.
- **Register As Service** (`service_name: String`) - Publishes this node under a short name anything can ask for, so no other row needs a path to it. Run it under On Ready. Registering the same name again replaces it, and a freed node answers as nothing at all, so a scene reload leaves no dangling reference behind.
- **Do After This Frame** (`do: String`) - Runs one action once the frame's physics and signal storm has finished, which is the only safe moment to add, free or reparent nodes. The number one crash a beginner hits is doing that from inside a collision callback; this is the fix, and the rows below it still run immediately.
- **Call Later** (`seconds: String, do: String`) - Runs one action after a delay, with no Timer node and WITHOUT suspending - the rows below it keep running. The connection is one-shot, so a delayed beat can neither leak nor fire twice. The readable form of the small follow-up: eject the shell, close the door, play the second thud.
- **Set Property (after this frame)** (`target: String, property: String, value: String`) - Sets a property at the end of the frame instead of right now. The one Godot insists on for collision shapes and monitoring: flipping those mid-physics is the error every beginner meets, and deferring is the documented answer.

#### Expressions
- **Duplicate Node** (`target: String`) - Clones a node so you can add the copy elsewhere, e.g. mass-spawning identical objects.
- **Node Name** (`target: String`) - Returns the node's name as text, useful for labels or matching.
- **Node Path** (`target: String`) - Returns the node's full path in the scene tree as a reference.
- **Index In Parent** (`target: String`) - Returns the node's position among its siblings as a number.
- **Current Scene Root** - Returns the root node of the currently running scene.
- **Get Children** (`target: String`) - Returns the list of a node's direct children to loop over or pick from.
- **Find Children (by name)** (`target: String, pattern: String`) - Returns all descendant nodes whose name matches a pattern, wildcards allowed.
- **Find Children Of Type** (`target: String, type: String`) - Returns all descendant nodes of a given class, e.g. every Area2D beneath this one.
- **First Child Of Type** (`target: String, type: String`) - Returns the first descendant node of a given class, or nothing if none exist.
- **Nodes In Group** (`group: String`) - Returns every node belonging to a named group to loop over or count.
- **Random Node In Group** (`group: String`) - Returns a randomly chosen member of a named group, e.g. a random spawn point.
- **Nearest Node In Group** (`group: String, target: String`) - Returns the closest member of a group to this node, e.g. the nearest enemy.
- **Furthest Node In Group** (`group: String, target: String`) - Returns the farthest member of a group from this node by distance.
- **Random Node In Group (empty-safe)** (`group: String`) - Returns a random member of a group, or nothing at all when the group is empty.
- **Group Member With Smallest Property** (`group: String, property: String`) - Returns the group member whose named property is lowest, e.g. the weakest enemy.
- **Group Member With Largest Property** (`group: String, property: String`) - Returns the group member whose named property is highest, e.g. the toughest enemy.
- **Service Named** (`service_name: String`) - The node published under a name, or nothing at all when nobody registered it or it has been freed. Drop it wherever a node is asked for - it never crashes and never needs a path.

### Node Activation (`res://addons/eventforge/registration/modules/node_activation_aces.gd`)
turning nodes on and off, and pausing them

#### Conditions
- **Node Is Running** (`target: String`) - True when this node is actually running right now - it answers the whole question, taking its process mode AND whether the game is paused into account.
- **Node Is Frozen By The Game Pause** - True when the game is paused AND this node is one of the things it froze - so a check can tell "paused" apart from "paused but I am exempt".
- **Node Is Processing Per Frame** (`target: String`) - True when a node's every-frame work is switched on.
- **Node Is Physics Processing** (`target: String`) - True when a node's physics-step work is switched on.
- **Node Is Handling Input** (`target: String`) - True when a node is still receiving input events.
- **Node Is Ready** (`target: String`) - True once a node has finished entering the tree and its _ready has run. Guards code that reaches a freshly spawned node before it has set itself up.

#### Actions
- **Deactivate Node (2D)** (`target: String`) - Hides a node and stops it running, along with everything under it - the usual "switch this off" for a 2D object you want back later. Reversed by Activate Node.
- **Activate Node (2D)** (`target: String`) - Shows a node and starts it running again, along with everything under it. The exact undo of Deactivate Node.
- **Deactivate Node (3D)** (`target: String`) - Hides a 3D node and stops it running, along with everything under it. Reversed by Activate Node.
- **Activate Node (3D)** (`target: String`) - Shows a 3D node and starts it running again, along with everything under it.
- **Pause Node** (`target: String`) - Freezes one node and everything under it, whatever the rest of the game is doing - a cutscene actor, a disabled turret, an off-screen room.
- **Unpause Node** (`target: String`) - Lets a node follow its parent again, undoing Pause Node.
- **Keep Node Running While Paused** (`target: String`) - Exempts a node from the game pause, so it keeps running while everything else is frozen. This is how a pause menu, its music, and its animations stay alive.
- **Pause Node With The Game** (`target: String`) - Makes a node stop when the game pauses, regardless of what its parent does. The normal behaviour, stated explicitly.
- **Run Node Only While Paused** (`target: String`) - Runs a node ONLY while the game is paused and never otherwise - a pause overlay that should not tick during play.
- **Set Node Process Mode** (`mode: String, target: String`) - Sets how a node reacts to the game pause, picking any of the five modes directly. The Pause / Unpause / Keep Running actions are shorthands for the common three.
- **Set Node Per-Frame Processing** (`on: String, target: String`) - Turns just the every-frame work on or off, leaving physics and input alone. Cheaper than deactivating when only the per-frame cost is the problem.
- **Set Node Physics Processing** (`on: String, target: String`) - Turns just the physics-step work on or off. Movement usually lives here, so this stops a body moving without hiding it.
- **Set Node Input Handling** (`on: String, target: String`) - Turns a node's input handling on or off, so it stops responding to the player while still running everything else.
- **Set Node Unhandled Input Handling** (`on: String, target: String`) - Turns handling of UNHANDLED input on or off - the events the UI did not consume, which is where gameplay controls usually listen.
- **Set Node Process Order** (`priority: String, target: String`) - Decides where a node sits in the per-frame order among its siblings. Lower runs first, so a camera that must move after its target gets a higher number.
- **Set Node Physics Order** (`priority: String, target: String`) - The same ordering knob for the physics step, for when one body must resolve before another.

#### Expressions
- **Node Process Mode** (`target: String`) - Returns a node's current process mode, as one of the Node.PROCESS_MODE_* values.

### Options (`res://addons/eventforge/registration/modules/options_aces.gd`)
Game Options vocabulary (the knobs an options menu changes).

#### Conditions
- **Is Bus Muted** (`bus: String`) - True when an audio bus is currently muted.
- **Has Saved Settings** - True when a settings file has been saved before (so you can load it on startup).

#### Actions
- **Set Master Volume (percent)** (`percent: float`) - Sets the overall game volume from a 0-100 slider value.
- **Set Bus Volume (percent)** (`bus: String, percent: float`) - Sets one audio bus's volume from a 0-100 slider value (for separate music / sfx sliders).
- **Save Setting** (`section: String, key: String, value: String`) - Writes one setting to user://settings.cfg, keeping the other saved settings intact.

#### Expressions
- **Bus Volume (percent)** (`bus: String`) - Reads a bus's volume back as a 0-100 percent (to set a slider's start value).

### Particle (`res://addons/eventforge/registration/modules/particle_aces.gd`)
Particles (GPUParticles2D / CPUParticles2D)

#### Triggers
- **On Particles Finished** - Fires once when this particle emitter's one-shot burst finishes playing.

#### Conditions
- **Is Emitting** (`target: String`) - True when the particle emitter is currently emitting particles.

#### Actions
- **Set Emitting** (`emitting: String, target: String`) - Starts or stops the particle emitter, e.g. switching an effect on.
- **Restart / Burst** (`target: String`) - Restarts the particle system from scratch, e.g. firing a fresh burst.
- **Set One-Shot** (`one_shot: String, target: String`) - Sets the emitter to fire a single burst then stop, rather than looping.
- **Set Amount** (`amount: String, target: String`) - Sets how many particles the emitter spawns, controlling effect density.
- **Set Speed Scale** (`scale: String, target: String`) - Speeds up or slows down the particle effect, e.g. 0 freezes it, 2 doubles it.
- **Set Emitting (CPU)** (`emitting: String, target: String`) - Starts or stops a CPU particle emitter, e.g. switching an effect on.
- **Restart / Burst (CPU)** (`target: String`) - Restarts a CPU particle system from scratch, e.g. firing a fresh burst.
- **Set Speed Scale (CPU)** (`scale: String, target: String`) - Speeds up or slows down a CPU particle effect, e.g. 0 freezes it, 2 doubles it.

#### Expressions
- **Amount** (`target: String`) - Returns how many particles the emitter is set to spawn.

### Physics (`res://addons/eventforge/registration/modules/physics_aces.gd`)
Physics joints (Joint2D / Joint3D)

#### Actions
- **Set Joint Body A** (`target: String`) - Sets the first physics body a joint connects to.
- **Set Joint Body B** (`target: String`) - Sets the second physics body a joint connects to.
- **Break Joint** (`target: String`) - Breaks a joint by clearing its second body, e.g. snapping a rope or chain.
- **Set Disable Collision** (`disabled: String, target: String`) - Toggles whether the two bodies linked by the joint can collide with each other.
- **Set Pin Softness** (`softness: String, target: String`) - Sets how springy a pin joint is, higher values make the link looser.
- **Set Spring Rest Length** (`length: String, target: String`) - Sets a spring joint's resting length, the distance it tries to hold.
- **Set Spring Stiffness** (`stiffness: String, target: String`) - Sets how rigid a damped spring joint feels, so it snaps back harder or softer.
- **Set Spring Damping** (`damping: String, target: String`) - Sets how quickly a damped spring stops bouncing, controlling its wobble.
- **Set Joint Body A (3D)** (`target: String`) - Picks the first 3D body a joint connects, wiring up what it links to.
- **Set Joint Body B (3D)** (`target: String`) - Picks the second 3D body a joint connects, completing the link.
- **Break Joint (3D)** (`target: String`) - Snaps a 3D joint apart by clearing its second body, releasing the connection.

### Physics Server (`res://addons/eventforge/registration/modules/physics_server_aces.gd`)
Physics Server vocabulary (world-level physics from events).

#### Actions
- **Set World Gravity (2D)** (`gravity: float`) - Changes the whole 2D world's gravity strength at runtime - low-gravity power-ups, water levels, moon stages. Every RigidBody2D reacts; CharacterBody2D movement packs keep their own gravity knobs.
- **Set World Gravity Direction (2D)** (`direction: String`) - Points the whole 2D world's gravity in a new direction - gravity-flip mechanics and rotating stages for every rigid body at once.
- **Set Physics Active (2D)** (`active: bool`) - Pauses or resumes the whole 2D physics space - a photo mode or cutscene freeze that leaves rendering and scripts running (unlike pausing the tree).
- **Set World Gravity (3D)** (`gravity: float`) - Changes the whole 3D world's gravity strength at runtime - space stations, underwater sections, jump-boost arenas. Every RigidBody3D reacts; CharacterBody3D movement packs keep their own gravity knobs.
- **Set World Gravity Direction (3D)** (`direction: String`) - Points the whole 3D world's gravity in a new direction - walk-on-walls arenas and gravity puzzles for every rigid body at once.
- **Set Physics Active (3D)** (`active: bool`) - Pauses or resumes the whole 3D physics space - freeze the simulation without pausing the tree.

#### Expressions
- **Active Bodies (2D)** - How many 2D bodies are awake and simulating - the first number to watch when physics gets slow.
- **Collision Pairs (2D)** - How many 2D collision pairs are being processed this step.
- **Physics Islands (2D)** - How many independent groups of touching 2D bodies the solver is working on.
- **Active Bodies (3D)** - How many 3D bodies are awake and simulating.
- **Collision Pairs (3D)** - How many 3D collision pairs are being processed this step.
- **Physics Islands (3D)** - How many independent groups of touching 3D bodies the solver is working on.
- **Physics Interpolation Fraction** - How far between physics ticks the current frame is (0..1) - hand-smooth visuals that follow physics bodies.

### Procedural (`res://addons/eventforge/registration/modules/procedural_aces.gd`)
Procedural vocabulary (stateless, seeded generation for tools + resources).

#### Conditions
- **Seeded Chance** (`seed: String, index: int, percent: float`) - True for a stable share of seed+index pairs (0-100) - a deterministic Chance you can use in tools and resource generation.

#### Expressions
- **Seeded Value** (`seed: String, index: int`) - A stable pseudo-random float in [0, 1) for a seed and an index - the same inputs always give the same value. No autoload, so it works in Editor Tool sheets and while generating Custom Resource data, as well as at runtime.
- **Seeded Int** (`seed: String, index: int, minimum: int, maximum: int`) - A stable pseudo-random integer between min and max (inclusive) for a seed and an index - deterministic, no autoload.
- **Seeded Pick** (`seed: String, index: int, options: Array`) - A stable pseudo-random element of an array for a seed and an index (null if empty) - deterministic, no autoload.
- **Seeded Sign** (`seed: String, index: int`) - A stable -1 or +1 for a seed and an index - deterministic, no autoload.

### Raycast (`res://addons/eventforge/registration/modules/raycast_aces.gd`)
raycasting vocabulary (2D and 3D)

#### Conditions
- **RayCast Hits Group (2D)** (`group: String`) - True when the ray is hitting something that belongs to a group - "did I shoot an enemy?" in one cell.
- **RayCast Hits Group (3D)** (`group: String`) - True when the ray is hitting something that belongs to a group - "did I shoot an enemy?" in one cell.
- **ShapeCast Is Colliding (2D)** (`target: String`) - True when the swept shape is touching anything along its path.
- **ShapeCast Is Colliding (3D)** (`target: String`) - True when the swept shape is touching anything along its path.
- **Ray Result Hit Something (2D)** (`result: String`) - True when the stored cast found something. An empty result means the ray reached its end without touching anything.
- **Ray Result Is In Group (2D)** (`result: String, group: String`) - True when the stored cast hit something belonging to a group, checking for nothing-hit first so it is safe on a clear ray.
- **Ray Result Hit Something (3D)** (`result: String`) - True when the stored cast found something. An empty result means the ray reached its end without touching anything.
- **Ray Result Is In Group (3D)** (`result: String, group: String`) - True when the stored cast hit something belonging to a group, checking for nothing-hit first so it is safe on a clear ray.
- **Mouse Ray Hits Something (3D)** (`distance: String`) - True when the cursor is over something solid. Casts on the spot - for more than a yes/no answer, use Cast Ray From Mouse Into and read the result.

#### Actions
- **Point RayCast At (2D)** (`reach: String, target: String`) - Aims the ray and sets how far it reaches. The target is measured from the raycast itself, so Vector2(0, 100) points 100 pixels down.
- **Enable RayCast (2D)** (`on: String, target: String`) - Turns the ray on or off. A disabled raycast costs nothing and always reports no hit.
- **Set RayCast Mask (2D)** (`mask: String, target: String`) - Chooses which collision layers the ray can see, all at once.
- **Set RayCast Mask Layer (2D)** (`layer: String, on: String, target: String`) - Switches ONE collision layer on or off for the ray, leaving the others alone - easier than working out the mask number.
- **Ignore Node In RayCast (2D)** (`node: Node, target: String`) - Makes the ray pass straight through one specific object - the usual way to stop a gun's ray hitting the shooter.
- **Stop Ignoring Node In RayCast (2D)** (`node: Node, target: String`) - Undoes Ignore Node In RayCast for one object, so the ray can hit it again.
- **Clear RayCast Exceptions (2D)** (`target: String`) - Forgets every ignored object, so the ray hits everything on its mask again.
- **RayCast Detects Areas (2D)** (`on: String, target: String`) - Lets the ray notice Area2D nodes. Godot IGNORES areas by default, which is the usual reason a ray seems to miss a trigger zone.
- **RayCast Detects Bodies (2D)** (`on: String, target: String`) - Lets the ray notice solid physics bodies (on by default). Turn it off for a ray that should only see trigger areas.
- **RayCast Hits From Inside (2D)** (`on: String, target: String`) - Reports a hit even when the ray begins inside the shape. Off by default, which is why a ray starting inside a wall reads as clear.
- **RayCast Ignores Its Parent (2D)** (`on: String, target: String`) - Passes through the body the raycast is parented to (on by default), so a character's own ray never hits the character.
- **Point RayCast At (3D)** (`reach: String, target: String`) - Aims the ray and sets how far it reaches. The target is measured from the raycast itself, so Vector3(0, 0, -10) points 10 metres forward.
- **Enable RayCast (3D)** (`on: String, target: String`) - Turns the ray on or off. A disabled raycast costs nothing and always reports no hit.
- **Set RayCast Mask (3D)** (`mask: String, target: String`) - Chooses which collision layers the ray can see, all at once.
- **Set RayCast Mask Layer (3D)** (`layer: String, on: String, target: String`) - Switches ONE collision layer on or off for the ray, leaving the others alone - easier than working out the mask number.
- **Ignore Node In RayCast (3D)** (`node: Node, target: String`) - Makes the ray pass straight through one specific object - the usual way to stop a gun's ray hitting the shooter.
- **Stop Ignoring Node In RayCast (3D)** (`node: Node, target: String`) - Undoes Ignore Node In RayCast for one object, so the ray can hit it again.
- **Clear RayCast Exceptions (3D)** (`target: String`) - Forgets every ignored object, so the ray hits everything on its mask again.
- **RayCast Detects Areas (3D)** (`on: String, target: String`) - Lets the ray notice Area3D nodes. Godot IGNORES areas by default, which is the usual reason a ray seems to miss a trigger zone.
- **RayCast Detects Bodies (3D)** (`on: String, target: String`) - Lets the ray notice solid physics bodies (on by default). Turn it off for a ray that should only see trigger areas.
- **RayCast Hits From Inside (3D)** (`on: String, target: String`) - Reports a hit even when the ray begins inside the shape. Off by default, which is why a ray starting inside geometry reads as clear.
- **RayCast Hits Back Faces (3D)** (`on: String, target: String`) - Decides whether the ray hits a surface from behind - matters for concave level geometry, where the inside of a wall faces you.
- **RayCast Ignores Its Parent (3D)** (`on: String, target: String`) - Passes through the body the raycast is parented to (on by default), so a character's own ray never hits the character.
- **Force ShapeCast Update (2D)** (`target: String`) - Re-runs the sweep immediately instead of waiting for the next physics frame - do this after moving or re-aiming it in the same frame you read it.
- **Point ShapeCast At (2D)** (`reach: String, target: String`) - Aims the sweep and sets its length, measured from the shapecast itself.
- **Enable ShapeCast (2D)** (`on: String, target: String`) - Turns the sweep on or off.
- **Set ShapeCast Mask (2D)** (`mask: String, target: String`) - Chooses which collision layers the sweep can see.
- **Set ShapeCast Margin (2D)** (`margin: String, target: String`) - Pads the swept shape slightly. A small margin makes contact detection steadier when the shape slides along a surface.
- **Set ShapeCast Max Results (2D)** (`max_results: String, target: String`) - Caps how many objects one sweep will report, which bounds its cost in a crowd.
- **Ignore Node In ShapeCast (2D)** (`node: Node, target: String`) - Makes the sweep pass straight through one specific object.
- **Clear ShapeCast Exceptions (2D)** (`target: String`) - Forgets every ignored object, so the sweep hits everything on its mask again.
- **Force ShapeCast Update (3D)** (`target: String`) - Re-runs the sweep immediately instead of waiting for the next physics frame - do this after moving or re-aiming it in the same frame you read it.
- **Point ShapeCast At (3D)** (`reach: String, target: String`) - Aims the sweep and sets its length, measured from the shapecast itself.
- **Enable ShapeCast (3D)** (`on: String, target: String`) - Turns the sweep on or off.
- **Set ShapeCast Mask (3D)** (`mask: String, target: String`) - Chooses which collision layers the sweep can see.
- **Set ShapeCast Margin (3D)** (`margin: String, target: String`) - Pads the swept shape slightly. A small margin makes contact detection steadier when the shape slides along a surface.
- **Set ShapeCast Max Results (3D)** (`max_results: String, target: String`) - Caps how many objects one sweep will report, which bounds its cost in a crowd.
- **Ignore Node In ShapeCast (3D)** (`node: Node, target: String`) - Makes the sweep pass straight through one specific object.
- **Clear ShapeCast Exceptions (3D)** (`target: String`) - Forgets every ignored object, so the sweep hits everything on its mask again.
- **Cast Ray Into (2D)** (`into: String, from: String, to: String, mask: String, exclude: String, hit_areas: String`) - Fires one ray through the world and stores everything it learned in a variable. Use this instead of the single-shot expressions when you want more than one fact about the hit - they each re-cast the ray.
- **Query Bodies Under Mouse (2D)** (`into: String, hit_areas: String, max_results: String`) - Collects everything the mouse cursor is over into a variable - click-to-select for 2D games, without any coordinate maths.
- **Cast Circle Motion Into (2D)** (`into: String, from: String, motion: String, radius: String, mask: String`) - Asks how far a circle could travel before something stops it, as a fraction of the move (1 means the whole path is clear). Multiply the motion by it to move right up to the obstacle.
- **Cast Ray Into (3D)** (`into: String, from: String, to: String, mask: String, exclude: String, hit_areas: String`) - Fires one ray through the world and stores everything it learned in a variable. Use this instead of the single-shot expressions when you want more than one fact about the hit - they each re-cast the ray.
- **Query Bodies At Point (3D)** (`into: String, point: String, hit_areas: String, max_results: String`) - Collects every physics object at a world point into a variable - like tapping the world with a finger.
- **Query Bodies In Sphere (3D)** (`into: String, center: String, radius: String, mask: String, max_results: String`) - Collects every physics object inside a sphere into a variable - explosion radii, pickup magnets, proximity checks.
- **Query Bodies In Box (3D)** (`into: String, center: String, size: String, mask: String, max_results: String`) - Collects every physics object inside a box into a variable - room triggers, rectangular blast zones, selection volumes.
- **Cast Sphere Motion Into (3D)** (`into: String, from: String, motion: String, radius: String, mask: String`) - Asks how far a sphere could travel before something stops it, as a fraction of the move (1 means the whole path is clear) - the reliable way to move a fast object without tunnelling through walls.
- **Cast Ray From Mouse Into (3D)** (`into: String, distance: String, mask: String, exclude: String, hit_areas: String`) - Shoots a ray from the camera through the mouse cursor and stores what it finds - the whole of click-to-select in 3D, in one row. Needs an active Camera3D.

#### Expressions
- **RayCast Hit Shape Index (2D)** (`target: String`) - Which of the hit object's collision shapes was struck, as an index - for bodies built from several shapes (a head shape versus a body shape).
- **RayCast Target (2D)** (`target: String`) - Returns where the ray currently reaches, relative to the raycast node.
- **RayCast Hit Shape Index (3D)** (`target: String`) - Which of the hit object's collision shapes was struck, as an index - for bodies built from several shapes (a head shape versus a body shape).
- **RayCast Hit Face Index (3D)** (`target: String`) - Which triangle of a concave mesh the ray hit, as an index (-1 for other shape types) - useful for reading per-face surface data.
- **RayCast Target (3D)** (`target: String`) - Returns where the ray currently reaches, relative to the raycast node.
- **ShapeCast Hit Count (2D)** (`target: String`) - How many objects the sweep is touching. Unlike a plain ray, a shapecast can report several at once.
- **ShapeCast Collider At (2D)** (`index: String, target: String`) - Returns one of the objects the sweep is touching, by position in the hit list.
- **ShapeCast Hit Point At (2D)** (`index: String, target: String`) - The world point where one of the sweep's hits touches.
- **ShapeCast Hit Normal At (2D)** (`index: String, target: String`) - The surface direction at one of the sweep's hits - bounce and slide maths start here.
- **ShapeCast Safe Fraction (2D)** (`target: String`) - How far along the sweep the shape can travel WITHOUT touching anything, from 0 (blocked immediately) to 1 (path is clear). Multiply the target by it to stop just short of the wall.
- **ShapeCast Unsafe Fraction (2D)** (`target: String`) - How far along the sweep the shape is first touching something, from 0 to 1 - the contact point to the safe fraction's stopping point.
- **ShapeCast Hit Count (3D)** (`target: String`) - How many objects the sweep is touching. Unlike a plain ray, a shapecast can report several at once.
- **ShapeCast Collider At (3D)** (`index: String, target: String`) - Returns one of the objects the sweep is touching, by position in the hit list.
- **ShapeCast Hit Point At (3D)** (`index: String, target: String`) - The world point where one of the sweep's hits touches.
- **ShapeCast Hit Normal At (3D)** (`index: String, target: String`) - The surface direction at one of the sweep's hits - bounce and slide maths start here.
- **ShapeCast Safe Fraction (3D)** (`target: String`) - How far along the sweep the shape can travel WITHOUT touching anything, from 0 (blocked immediately) to 1 (path is clear). Multiply the target by it to stop just short of the wall.
- **ShapeCast Unsafe Fraction (3D)** (`target: String`) - How far along the sweep the shape is first touching something, from 0 to 1 - the contact point to the safe fraction's stopping point.
- **World Raycast Normal (2D)** (`from: String, to: String, target: String`) - The surface direction where a one-off ray hits, or a zero vector when it hits nothing.
- **World Raycast Collider (3D)** (`from: String, to: String, target: String`) - The object a one-off ray hits, or nothing when the path is clear.
- **World Raycast Normal (3D)** (`from: String, to: String, target: String`) - The surface direction where a one-off ray hits, or a zero vector when it hits nothing - what you reflect a bounce around.
- **Ray Result Collider (2D)** (`result: String`) - The object the stored cast hit, or nothing when it hit thin air.
- **Ray Result Point (2D)** (`result: String`) - Where in the world the stored cast struck - spawn the impact spark here.
- **Ray Result Normal (2D)** (`result: String`) - Which way the surface faces at the hit - reflect the velocity around it to bounce, or align a decal to it.
- **Ray Result Shape Index (2D)** (`result: String`) - Which of the hit object's collision shapes was struck, as an index - tell a headshot from a body shot.
- **Ray Result Collider (3D)** (`result: String`) - The object the stored cast hit, or nothing when it hit thin air.
- **Ray Result Point (3D)** (`result: String`) - Where in the world the stored cast struck - spawn the impact effect or bullet hole here.
- **Ray Result Normal (3D)** (`result: String`) - Which way the surface faces at the hit - reflect the velocity around it to bounce, or lay a decal flat against it.
- **Ray Result Shape Index (3D)** (`result: String`) - Which of the hit object's collision shapes was struck, as an index - tell a headshot from a body shot.
- **Ray Result Face Index (3D)** (`result: String`) - Which triangle of a concave mesh was hit, as an index (-1 for other shape types) - for reading per-face surface data like footstep materials.
- **Mouse Ray Collider (3D)** (`distance: String, target: String`) - The object under the mouse cursor, or nothing when the cursor is over empty space.
- **Mouse Ray Point (3D)** (`distance: String, target: String`) - The world point the cursor is pointing at - where to place a build ghost, a move order marker, or a decal.

### Regex (`res://addons/eventforge/registration/modules/regex_aces.gd`)
RegEx text matching (the Regex* verbs event-sheet authors expect, Godot-native).

#### Conditions
- **Text Matches Regex** (`pattern: String, text: String`) - True when the text matches the regular expression anywhere (e.g. "^[0-9]+$" tests for digits only).

#### Expressions
- **Regex Replace** (`pattern: String, text: String, replacement: String`) - Returns the text with EVERY match of the pattern replaced. Use $1/$2 in the replacement to reuse capture groups.
- **Regex First Match** (`pattern: String, text: String`) - Returns the first substring that matches the pattern, or an empty string when there's no match (never errors).
- **Regex Match Count** (`pattern: String, text: String`) - Returns how many times the pattern matches in the text (0 if none).
- **Regex All Matches** (`pattern: String, text: String`) - Returns an array of every substring that matches the pattern (an empty array if none).
- **Regex Capture Group** (`pattern: String, text: String, group: String`) - Returns capture group N from the first match - the text inside the Nth pair of parentheses - or empty if none.
- **Format Decimals** (`value: String, decimals: String`) - Returns a number as text with a fixed number of decimal places, e.g. 3.14159 → "3.14".

### Rendering (`res://addons/eventforge/registration/modules/rendering_aces.gd`)
Rendering vocabulary (the RenderingServer from events).

#### Conditions
- **Uses Modern Renderer** - True on the Forward+ / Mobile renderers, false on Compatibility (old GPUs, web) - gate fancy effects on it.

#### Actions
- **Set Clear Color** (`color: Color`) - Sets the default background color of the whole game - the color you see where nothing is drawn.
- **Set Global Shader Parameter** (`name: String, value: String`) - Drives a global shader uniform (Project Settings > Shader Globals) - every material reading it updates at once, the code-free way to animate weather, day-night tint, or a world-wide effect.
- **Set MSAA (2D)** (`level: String`) - Sets multisample antialiasing for 2D rendering on the current viewport - a standard graphics-options switch.
- **Set MSAA (3D)** (`level: String`) - Sets multisample antialiasing for 3D rendering on the current viewport - a standard graphics-options switch.
- **Set Screen-Space AA** (`mode: String`) - Turns FXAA on or off for the current viewport - cheaper than MSAA, softer result.
- **Set 3D Resolution Scale** (`scale: float`) - Renders the 3D scene at a fraction of the window resolution and upscales - the classic performance slider.
- **Set Debug Draw Mode** (`mode: String`) - Switches the viewport to a diagnostic view - wireframe, overdraw heat, or unshaded - and back. Great on a debug hotkey.
- **Set Occlusion Culling** (`enabled: bool`) - Toggles occlusion culling on the current viewport - big scenes skip drawing what walls already hide.
- **Set Debanding** (`enabled: bool`) - Toggles debanding - removes the visible stripes in smooth dark gradients for a tiny cost.

#### Expressions
- **Draw Calls (frame)** - How many draw calls the last frame issued - the first number to watch when rendering gets slow.
- **Objects Drawn (frame)** - How many objects the last frame rendered after culling.
- **Primitives Drawn (frame)** - How many triangles/points/lines the last frame rendered.
- **Video Memory Used** - Video memory in use, in bytes (textures + buffers).
- **Global Shader Parameter** (`name: String`) - Reads a global shader uniform's current value.
- **Clear Color** - The current default background color.

### Resource (`res://addons/eventforge/registration/modules/resource_aces.gd`)
Data assets: a folder of .tres as vocabulary, independent copies, pouring

#### Triggers
- **On Data File Changed** (`path: String`) - Runs when a Watch Data File row notices that a watched file has been written. The path arrives on the row as path, so the reaction reloads exactly the file that changed even when two land in the same check. Needs a Signal row for data_file_changed(path: String) - without one the sheet still compiles, but nothing connects this event, so it never runs. The Project Doctor flags that.

#### Conditions
- **Matches Properties Of** (`target: String, names: String, other: String`) - True while the listed properties hold the same values on both objects - the cheap 'is this ghost still in sync' or 'has anything changed' check. A name neither object has reads as NOT matching, so a typo shows up instead of quietly passing, and either side being gone reads as not matching too.
- **Data Is Older Than Version** (`record: String, field: String, version: String`) - True when a loaded record was written by an older build than this one - the gate a migration sits under. A record with NO version field counts as 0, so the very first format upgrades too, and so does one whose version field is empty or is not a number at all.
- **Data Folder Is Valid** (`folder: String`) - True when every data asset in a folder loads, has an id, and has an id no sibling shares - the check to put in front of loading a mod folder or user content. Read the reasons with Data Folder Problems.

#### Actions
- **Copy Values From** (`target: String, source: String, names: String`) - Pours a list of values off another object onto this one, in one row instead of one row per property. Names the target does not have are skipped, so a single preset can serve several kinds of node.
- **Fill Blanks From** (`target: String, base: String`) - Writes a base's values ONLY into fields this object left empty, leaving everything you did fill in alone. That is the override chain: a base item plus a rarity variant, or a shipped table plus a mod file. Empty means nothing there: no value at all, blank text, an empty list or an empty record - a 0 and a false are real values and are kept, exactly as Is Nothing and Missing Fields read them.
- **Apply Preset To Node** (`preset: String, target: String`) - Pours a data asset's fields onto the same-named properties of a node, so difficulty tiers, weapon tunings and boss phases become a data edit instead of a wall of rows.
- **Rename Field** (`record: String, from_field: String, to_field: String`) - Moves a value to its new field name, and does nothing at all when the old name is not there - so a migration is safe to run twice.
- **Stamp Data Version** (`record: String, field: String, version: String`) - Writes the current format number onto a record, so the next load knows it has already been migrated. Data Is Older Than Version reads it back, and reads it as 0 when it is missing or is not a number.
- **Watch Data File** (`path: String`) - Checks whether a data file has been written since the last check, and fires the sheet's data_file_changed(path) signal when it has - so you edit an enemy's numbers in the Inspector and the running game picks them up. Put it under Every X Seconds; the first check only takes a reading, so nothing fires just because the row started. This is a debug-build tool: it reads the file's timestamp each time it runs.
- **Reload Data Asset** (`path: String`) - Re-reads a data asset from disk into the copy every node is already holding, so the new numbers apply without restarting or re-assigning anything. It reloads DATA, not code: a changed script still needs a restart. Nothing happens when the path is not there.
- **Validate Data Folder** (`folder: String`) - Checks a folder of data assets and writes every problem it finds to the Output as one warning, saying which file and what is wrong. A clean folder says nothing at all, so it is safe to leave in a startup event.

#### Expressions
- **Resources In Folder** (`folder: String`) - Loads every data asset (.tres) in a folder as a list, so a folder of files becomes your content - items, enemies, levels, or a mod folder. A missing folder gives an empty list, and a file that fails to load is left out rather than arriving as nothing.
- **Resource In Folder** (`folder: String, name: String`) - Fetches one data asset out of a folder by its file name, or nothing at all when there is no such file - no red error.
- **Load Resource Or Default** (`path: String, fallback: String`) - Loads a file and hands back your fallback when it is missing, so a deleted or mod-supplied file never crashes the game.
- **Count Of Resources In** (`folder: String`) - How many data assets a folder holds, counted without loading any of them - zero if the folder is missing.
- **Copy Resource (Independent)** (`resource: String`) - Makes a private copy of a resource, right down to the resources inside it, so writing to the copy never changes the .tres on disk or any other node holding it. Use this before a node edits its own stats.
- **Copy Resource (Share Sub-Resources)** (`resource: String`) - Makes a cheap copy whose own fields are separate but whose inner resources and lists are still SHARED with the original. Pick this only when you want that sharing - otherwise use Copy Resource (Independent).
- **Deep Copy** (`var_name: String`) - Copies the array AND every list or dictionary nested inside it, so editing the copy cannot reach back into the original. Copy Array only copies the outer level.
- **Deep Copy** (`var_name: String`) - Copies the dictionary AND every list or dictionary nested inside it, so editing the copy cannot reach back into the original. Copy Dictionary only copies the outer level.
- **Data Folder Problems** (`folder: String`) - Every structural problem in a folder of data assets, one per line, and "" when it is clean: a file that cannot be loaded, one with no usable id, and two files claiming the same id (where the second quietly wins every lookup). Show it, log it, or fail a build with it.

### Spatial (`res://addons/eventforge/registration/modules/spatial_aces.gd`)
Spatial vocabulary (screen/world, random geometry, surfaces, grids, falloff).

#### Conditions
- **Is Point On Screen** (`world_point: Vector2, margin: float`) - True while a world point is inside the visible view - the honest gate for spawning, culling, showing an off-screen arrow, or holding a tutorial callout until its subject is actually visible.
- **Is Behind Camera (3D)** (`world_point: Vector3`) - True when a 3D point sits behind the camera plane, where its projected screen position is a mirrored lie. The guard every 3D waypoint marker needs before it draws. With no camera in the scene it reads true, so nothing is drawn into a view that does not exist.
- **Is Cell In Bounds** (`cell: Vector2i, size: Vector2i`) - True while a cell is on the board - the guard before every placement, every move and every array lookup keyed by cell. Counting starts at 0,0 in the top-left, so a 20 by 12 board's last cell is 19,11.
- **For Each Cell In Radius** (`center: Vector2i, radius: int, shape: String`) - Runs this event's actions once per cell within a step radius of a centre cell - range previews, blast footprints, fog reveal, area-of-effect highlights. Read the current one as `cell`.
- **Is Within Cone Of** (`origin: Vector2, facing_degrees: float, point: Vector2, fov_degrees: float, range_px: float`) - True while a point sits inside a facing wedge - guard vision, spotlight checks, melee arcs, directional blasts. The cheap test to put in front of an expensive raycast: if it is not in the cone, there is nothing to trace.

#### Actions
- **Wrap Inside The View (3D)** - The Asteroids rule in 3D: leave the right of the view and come back on the left, off the top and back at the bottom, at the same distance from the camera. The missing twin of the 2D Wrap Inside The Screen, for a wrap-around arena or an endless shoal. Does nothing while there is no 3D camera.
- **Face Along Velocity** (`velocity: Vector2`) - Turns this node to point the way it is travelling, and leaves it alone while it is standing still so a stopped thing never snaps back to facing right. Arrows, fish, cars, thrown knives, a camera that leads the motion.
- **Look At (safe up)** (`target: Vector3`) - Turns a 3D node to face a point WITHOUT the crash the plain Look At has: when the target is directly overhead or underfoot, the usual up vector points the same way as the look direction and Godot cannot build a rotation from that. This one swaps the up vector at the last moment, and does nothing at all when the target is where the node already is.
- **Look At (flat)** (`target: Vector3`) - Turns a 3D node to face a point but only around the up axis, so a character looks at the player without tipping over to stare at their feet. The rotation every humanoid, turret base and standing NPC actually wants.
- **Apply Radial Impulse** (`center: Vector2, strength: float, radius: float`) - Throws this physics body away from a blast, weaker the further it was - barrels, crates, ragdolls and debris flung by an explosion. One row on the body; the blast only has to say where it happened.
- **Push Group Away From** (`group: String, center: Vector2, radius: float, strength: float`) - Shoves every member of a group away from a point, hardest at the centre and not at all past the radius - the mirror of Pull Group Toward. A shockwave clearing a crowd, a repulsor field, a dash that parts the enemies it passes through.

#### Expressions
- **World Point To Screen** (`world_point: Vector2`) - Where a world point sits on screen right now, camera zoom and scroll included - pin a nameplate, a health bar or a damage number to something that moves. Put the answer on a node that lives on a CanvasLayer and it will track its target without lagging behind the camera.
- **Screen Point To World** (`screen_point: Vector2`) - The world position under a screen pixel - click-to-place, a gamepad cursor, a HUD marker dragged onto the map. The exact opposite of World Point To Screen, so the two round-trip.
- **Project To Screen (3D)** (`world_point: Vector3`) - Where a 3D world point lands on screen - nameplates over 3D characters, damage numbers, objective pins drawn on a CanvasLayer. Reads as 0,0 while there is no active 3D camera, so it never faults during a scene change. Check Is Behind Camera (3D) first: a point behind you still projects to a number.
- **Screen Edge Position For** (`world_point: Vector2, margin: float`) - A screen position that follows a target while it is visible and sticks to the edge of the view once it is not - the off-screen objective arrow, the radar blip, the "your teammate is over there" chevron. Pair it with Marker Angle Toward for the rotation.
- **Marker Angle Toward** (`world_point: Vector2`) - The rotation in degrees an on-screen arrow needs so it points from the middle of the view at a world thing - the other half of the off-screen marker, and it stays right while the camera zooms or rotates.
- **Visible World Rect** - The rectangle of the world the camera can currently see, in world coordinates - spawn just outside it, cull outside it, clamp a node inside it, or size a minimap to it. Follows the camera's zoom and position with nothing to keep in sync.
- **Random Point In Circle** (`center: Vector2, radius: float`) - An evenly spread random point inside a circle - the sqrt weighting is done for you, so scatter does not bunch up in the middle the way the obvious version does.
- **Random Point On Circle** (`center: Vector2, radius: float`) - A random point exactly ON the rim of a circle, never inside it - a spawn ring around the player, orbiting decor, a radial menu slot, the starting point of a homing shot.
- **Random Point In Ring** (`center: Vector2, inner_radius: float, outer_radius: float`) - A random point in the doughnut between two radii - the off-screen spawner that never drops an enemy in the player's lap, and never so far away it never arrives. Evenly spread across the whole band, not crowded against the inner edge.
- **Random Point In Rectangle** (`top_left: Vector2, size: Vector2`) - A random point inside an axis-aligned rectangle - loot scatter across a room, prop placement, confetti over a banner, a patrol target inside a zone. Feed it Visible World Rect's position and size to scatter across whatever the camera can see.
- **Random Point In Cone** (`center: Vector2, facing_degrees: float, spread_degrees: float, radius: float`) - A random point inside a wedge - shotgun spread, cone attacks, directional scatter, a spray of sparks away from a wall. Facing and spread are in degrees, so the row reads the way you think about it.
- **Random Point Around** (`node: String, min_radius: float, max_radius: float`) - Random scatter around a node that is already in the scene - blood splats around a hit, footprints around a stomp, sparkles around a pickup, a wander target around home. Pick the node instead of typing its position, and the scatter follows it as it moves.
- **Random Direction (2D)** - A random unit direction in 2D - multiply it by a speed for a random shove, by a distance for a random offset. Always exactly one unit long, so the strength stays where you set it.
- **Random Direction (3D)** - A random unit direction in 3D, evenly spread over the whole sphere. The naive three-random-numbers version crowds the corners of a cube; this one does not, so debris and shrapnel fly out honestly.
- **Random Point In Sphere** (`center: Vector3, radius: float`) - An evenly spread random point inside a 3D sphere - spawn clouds, debris fields, flocking targets. The cube-root weighting keeps the middle from filling up first.
- **Random Point In Box** (`center: Vector3, size: Vector3`) - A random point inside an axis-aligned 3D box - scatter trees over a chunk, spawn enemies in a room volume, place ambient audio emitters. Size is the FULL box, measured around the centre.
- **Random Point On Screen Edge** - A random WORLD position on the border of what the camera can see - the wave spawner that comes in from a random side, ambient wildlife entering the frame, a meteor starting its run. Grow it with Visible World Rect if you want them to appear from just outside.
- **Jitter** (`value: String, amount: String`) - Nudges a value by a random amount up to the size you give - pitch variation on a sound, a pixel or two of scatter on a decal, a shade of variation on a tint. Works on numbers, vectors and colors as long as the amount is the same kind of value.
- **Bounce Off Surface** (`velocity: Vector2, normal: Vector2, bounciness: float`) - The velocity a moving thing has AFTER hitting a surface - feed it the normal any hit trigger or raycast hands you. Ricochets, pinball, breakout, deflect shields.
- **Slide Along Surface** (`velocity: Vector2, normal: Vector2`) - The velocity left over once the part pushing INTO a surface is removed - a wall slide that keeps you moving along the wall instead of sticking to it, slope movement, a dash that grazes a corner rather than stopping dead.
- **Angle Reflected** (`degrees: float, normal: Vector2`) - The heading in degrees a thing travels on after bouncing off a surface - the answer to feed straight back into Set Angle Of Motion when a bullet should ricochet instead of dying.
- **Push Out Of Surface** (`point: Vector2, normal: Vector2, distance: float`) - A position just clear of a surface instead of exactly on it - park a ricocheting bullet, a decal or a spawned effect here. Landing exactly on a surface is how a thing ends up stuck inside it on the next frame, because a ray that starts inside a shape does not report it.
- **Aim At Moving Target** (`shooter_position: Vector2, target_position: Vector2, target_velocity: Vector2, projectile_speed: float`) - Where to aim so a shot MEETS a moving target instead of trailing it - the interception point every turret and archer needs. When the target is faster than the shot no lead exists, and it falls back to the target's current spot rather than pointing somewhere absurd.
- **Launch Angle For Arc** (`distance: float, height: float, speed: float, gravity: float`) - The angle in degrees to fire something so it ARCS onto a target - grenades, mortars, catapults, a coin tossed into a counter. Picks the flatter of the two possible arcs, and reads as 45 degrees when the shot cannot reach at all, so a row never produces a number that is not a number.
- **Time To Reach** (`from_position: Vector2, to_position: Vector2, speed: float`) - How many seconds something moving at a steady speed needs to cover a distance - time a warning before the missile lands, size a tween to match a walk, decide whether the interceptor can get there first.
- **Cell Of Point** (`point: Vector2, cell_size: float`) - Which grid cell a world position falls in - no TileMapLayer needed, so build grids, inventory slots and chunk keys all speak the same language. Negative positions land in negative cells, which is what a grid that extends left and up actually wants.
- **Center Of Cell** (`cell: Vector2i, cell_size: float`) - The world position at the middle of a grid cell - where the placement ghost sits, where the tower is built, where the piece lands. The exact partner of Cell Of Point, so the pair round-trips.
- **Snap Point To Grid** (`point: Vector2, cell_size: float`) - The nearest grid intersection to a loose position - a dragged card falling into its slot, a level editor brush, a UI element clicking onto a column. Rounds to the nearest, so a thing dropped just past halfway moves forward rather than back.
- **Snap Point To Grid (3D)** (`point: Vector3, cell_size: float`) - The nearest point on a 3D grid - voxel placement, modular level pieces clicking together, a build cursor that lines up with the floor tiles.
- **Cell Distance** (`from_cell: Vector2i, to_cell: Vector2i, metric: String`) - How far apart two grid cells are, with the same geometry dropdown the rest of the plugin uses: straight line, horizontal or vertical only, grid steps (Manhattan) or king moves (Chebyshev). One expression that fits a roguelike, a strategy game and a puzzle board alike.
- **Neighbours Of Cell** (`cell: Vector2i, shape: String`) - The cells touching a cell, as a list - flood fill, path search, "is anything next to me", spreading fire, match-three clearing. Choose four sides, eight including diagonals, or the six neighbours of an axial hex board.
- **Cells In Line** (`from_cell: Vector2i, to_cell: Vector2i`) - Every cell a straight line passes through, in order from one cell to the other - a laser beam's path, tile-based line of sight, a corridor carved between two rooms, a ruler for a ranged attack. Both ends are included.
- **Cells In Radius** (`center: Vector2i, radius: int, shape: String`) - Every cell within a step radius of a centre cell, as a list - a blast footprint, a range preview, a fog reveal, the tiles a tower covers. Choose the diamond (counting grid steps) or the square (counting king moves).
- **Cells In Rectangle** (`top_left: Vector2i, size: Vector2i`) - Every cell in a rectangular block, row by row - stamping a room, laying out an inventory grid, placing a multi-cell building, clearing a region of fog. An empty or negative size walks nothing rather than looping backwards.
- **Falloff At Distance** (`center: Vector2, point: Vector2, radius: float, shape: String`) - How strong an effect is at a distance, from 1 at the centre to 0 at the edge - the one number that makes an explosion, a sound, a magnet or a screen shake care how close it was. Anything past the radius reads as 0, so it is safe to multiply straight into damage. For a hand-drawn profile, feed this number into Sample Curve.
- **Strength Toward** (`node: String, radius: float`) - Falloff between THIS node and another one, without spelling out either position - guard suspicion that builds faster the closer you are, a magnet that pulls harder up close, a sound that ducks as you approach. Reads 0 once the other node is out of range.

### System (`res://addons/eventforge/registration/modules/system_aces.gd`)
System (event-sheet System parity)

#### Triggers
- **On Scene Spawned** (`spawn_name: String, node: Node`) - Runs when a Spawn Scene As row spawns something. The name and the new node arrive on the row as spawn_name and node, so a reaction can configure or announce the node without asking what was spawned last - correct even when one loop spawns six things in a frame. Needs a Signal row for scene_spawned(spawn_name: String, node: Node) - without one the sheet still compiles, but nothing connects this event, so it never runs. The Project Doctor flags that.
- **On Failure Of** (`verb_id: String, reason: String`) - Runs when an action reports that it refused. The action's name and the reason arrive on the row as verb_id and reason, so recovery lives in its own event - add a condition under it to handle one action only. Needs a Declare Signal row for verb_failed(verb_id: String, reason: String) - without one the sheet still compiles, but nothing connects this event, so it never runs. The Project Doctor flags that.
- **On Success Of** (`verb_id: String`) - Runs when an action reports that it finished. The action's name arrives on the row as verb_id. Needs a Declare Signal row for verb_succeeded(verb_id: String) - without one the sheet still compiles, but nothing connects this event, so it never runs. The Project Doctor flags that.

#### Conditions
- **Is Within Angle** (`angle: String, within: String, target: String`) - True when two angles are close, taking wrap-around into account (350 is within 20 of 10).
- **Is Clockwise From** (`angle: String, from: String`) - True when the shortest turn from the reference angle to this one is clockwise (in 2D screen space, where +Y points down).
- **Value Is A Number** (`value: String`) - True when the value holds a number - guard untyped variables and loaded JSON before math.
- **Value Is Text** (`value: String`) - True when the value holds text - guard untyped variables and loaded JSON before string work.
- **Is NaN** (`value: String`) - True when a calculation broke and produced not-a-number (like dividing zero by zero).
- **Is Fullscreen** - True while the game window is in fullscreen mode - pair with Set Fullscreen Mode for a toggle.
- **Platform Has Feature** (`feature: String`) - True when the current platform supports the given feature tag - mobile, web, editor, debug/release, a specific OS, or any custom tag your export preset defines.
- **Every X Seconds** (`seconds: String`) - True once each time the chosen number of seconds passes, for repeating timers.
- **Every X To Y Seconds** (`min_seconds: String, max_seconds: String`) - True once each time a random wait between the two lengths passes - spawner and idle-chatter cadence that never looks metronomic. Needs a per-frame trigger, like Every X Seconds; each firing re-rolls the next wait.
- **Trigger Once** - True only on the first tick each time the event's other conditions become true, and again after they have gone false. Works in any condition slot.
- **Has Changed** (`value: String`) - True on any tick where the watched value differs from the tick before (needs a per-frame trigger).
- **Cooldown Is Ready** (`name: String`) - True when the named cooldown has finished. A cooldown that was never started counts as ready, so the first use is always allowed.
- **Press Is Buffered** (`name: String`) - True while a recently buffered press is still valid - the player pressed jump just before landing, and it should still fire.
- **Was Recently True** (`value: String, window: String`) - True while the watched condition is true, and for a moment after it stops. This is coyote time: "is_on_floor() was true within 0.1s" lets a player jump just after walking off a ledge. Needs a per-frame trigger so the moment gets stamped.
- **On Group Emptied** (`group: String`) - True on the single tick a watched group's last member leaves or dies - the wave director's trigger, without counting nodes by hand. A group that is already empty at startup never fires it. Needs a per-frame trigger.
- **On Group Gains First Member** (`group: String`) - True on the single tick a watched group goes from empty to holding something - the wave STARTED, the first pickup spawned, combat just began. Needs a per-frame trigger.
- **Once At A Time** - Skips the event while a previous run is still going. A run that awaits (Wait, Wait For Signal) counts as still going until it finishes - so a per-frame event with a Wait runs one copy at a time instead of stacking a new one every frame.
- **Compare Values** (`a: String, op: String, b: String`) - True when two values match your chosen comparison, like equal, greater or less than.
- **Is Between Values** (`value: String, min: String, max: String`) - True when a value falls within a low and high range, bounds included.
- **Is Between Angles** (`angle: String, low: String, high: String`) - True when an angle falls inside a window of directions - a firing arc, a sight cone, a slope band. The angle is wrapped into one turn first, so 370 counts as 10.
- **Is About** (`a: String, b: String`) - True when two decimal numbers are near enough to count as the same. Any arithmetic leaves a tiny remainder, so this is the comparison you want wherever == would be a coin flip.
- **Seconds Have Passed Since** (`seconds: String, since: String`) - True once a stretch of time has gone by since a moment you stamped with Now - the cooldown every shooting, dashing or spawning row needs, without a timer node.
- **Chance** (`percent: String`) - True for the given share of the times it is asked - a 30% chance is true roughly three times in ten. The roll is fresh every time the row runs.
- **Is Outside Layout** (`point: String`) - True when a point has left the visible layout on any side - the bullet-culling and stray-enemy question, in one row instead of four edge comparisons.
- **Is On-Screen** (`point: String, target: String`) - True while a point is inside the visible layout - the guard that keeps off-screen things from doing expensive work.
- **Is Inside Area** (`area: String, point: String`) - True when a point falls inside a rectangle - a zone, a safe area, a spawn band - without needing an Area2D node in the scene.
- **Expression Is True** (`expr: String`) - True when your custom GDScript expression evaluates to true; an escape hatch for advanced checks.
- **Is Group Active** (`group: String`) - True when the named runtime group is currently switched on.
- **Only Once Ever** (`key: String`) - True exactly once, ever - even across closing the game. Show a tutorial hint the first time and never again; Forget First Time resets it for testing (takes effect next run).
- **Spawn Is Alive** (`spawn_name: String`) - True while the node spawned under this name still exists - the guard to put in front of any row that talks to a named spawn, and the honest way to ask 'is the boss still up?'.
- **At Most Every** (`seconds: String`) - Lets this event run at most once every so many seconds, however often it is reached. The rate limit for a search box, an expensive readout, or forty hit sounds landing in one frame.
- **Has Been Quiet For** (`poke_name: String, seconds: String`) - True once a poked name has stopped being poked for this long - the settle-down check. Autosave after the player stops editing, search after they stop typing. Needs a per-frame trigger, and stays true until you Clear Poke.
- **Only Once Per Node** (`node: String, label: String`) - True the first time this row is reached for each node, and never again for that node. The initialiser you want when the row sits inside a For Each over spawned things; the memory lives on the node, so Forget Once For clears it.
- **Only Once Per Name** (`key: String`) - True the first time this row is reached for each name, and never again for that name. One discovery line per item type, one loot roll per chest id - with no flag variable each. Kept on this node, so Forget Once For clears it.
- **Only Once This Scene Load** (`key: String`) - True the first time this row is reached for each name in this scene load, and again after the scene is reloaded or changed. The welcome line, the per-level check - forgotten on Restart Scene rather than remembered forever.

#### Actions
- **Set Time Scale** (`scale: String`) - Speeds up or slows the whole game; use for slow-motion or pausing.
- **Set Fullscreen Mode** (`mode: String`) - Switches the game window between windowed, fullscreen and other display modes.
- **Set Window Size** (`size: String`) - Resizes the game window to a chosen pixel width and height.
- **Take Screenshot** (`path: String`) - Saves what's on screen right now as a PNG file.
- **Set Max FPS** (`fps: String`) - Caps how many frames per second the game renders - save battery or steady the pace.
- **Set Physics Rate** (`fps: String`) - Changes how often physics steps per second (default 60).
- **Set Random Seed** (`seed: String`) - Pins the global randomness so a run replays identically - daily challenges, replays, tests.
- **Set Effect Parameter** (`param: String, value: String, target: String`) - Feeds a value into one of an effect's parameters to drive it at runtime.
- **Start Cooldown** (`name: String, seconds: String`) - Starts (or restarts) a named cooldown that lasts the given number of seconds.
- **Buffer Press** (`name: String, seconds: String`) - Remembers a press for a fraction of a second, so an input made slightly too early still counts. Record it when the button goes down, check Press Is Buffered where the act happens, then Clear Buffer.
- **Clear Buffer** (`name: String`) - Forgets a buffered press. Consume the buffer right after acting on it so one press never fires twice.
- **Spawn Scene At** (`path: String, position: String`) - Loads a scene and drops a copy into the world at a position.
- **Spawn Scene (Full)** (`path: String, position: String, rotation: String, group: String`) - Spawns a scene copy with position, rotation and an optional group in one step.
- **Set Group Active** (`group: String, active: String`) - Turns a runtime-toggleable group on or off to enable or disable its behaviour.
- **Set Effect** (`material: String, target: String`) - Puts an effect on this object, changing how it draws.
- **Remove Effect** (`target: String`) - Takes the effect off this object, returning it to how it normally draws.
- **Tween Effect Parameter** (`param: String, from: String, to: String, seconds: String, target: String`) - Drives one of an effect's parameters from one value to another over time.
- **Forget First Time** (`key: String`) - Resets an Only Once Ever memory so it fires again - for testing, or for New Game+. Rows already running this session keep their cached answer until the next run.
- **Spawn Scene As** (`path: String, spawn_name: String, values: String, parent: String, position: String`) - Spawns a scene under a name, sets a record of values on it before it enters the tree, and remembers it under that name so every later row can say The Spawned. If the sheet declares a scene_spawned(spawn_name, node) signal, this fires it with both, so another event can react to the new node without ever asking what was spawned last.
- **Report Failure** (`verb: String, reason: String`) - Announces that an action refused, so every On Failure Of event for that action runs. Use it inside an action you publish yourself, or after a check that found a null resource or an empty result.
- **Report Success** (`verb: String`) - Announces that an action finished, so every On Success Of event for that action runs. The confirmation twin of Report Failure.
- **Poke** (`poke_name: String`) - Marks that something just happened, by name. Poke on every keystroke or every change, then let Has Been Quiet For notice when it stops.
- **Clear Poke** (`poke_name: String`) - Forgets a poke so Has Been Quiet For stops firing. Clear it right after acting on the quiet, the same way you consume a buffered press.
- **Forget Once For** (`node: String, label: String`) - Clears an Only Once Per Node / Per Name memory so the row fires again for that node. Drop it in an Object Pool's reset seam and a recycled instance initialises like a fresh one.

#### Expressions
- **Time Scale** - Gives the current game speed (1 = normal, below 1 = slow motion).
- **Game Time** - Gives seconds elapsed since the game started, handy for timers.
- **FPS** - Gives the current frames per second, useful for performance checks.
- **Frame Count** - Gives how many frames have run since startup.
- **Window Width** - Gives the current window width in pixels.
- **Window Height** - Gives the current window height in pixels.
- **Text From Pattern** (`pattern: String, values: String`) - Builds text by filling {name} slots in a pattern - "{player} scored {score}!" becomes "Ada scored 300!". The friendly way to mix words and values, no format codes.
- **Token At** (`text: String, separator: String, index: String`) - Splits text by a separator and gives the chosen piece, like a CSV column.
- **Token Count** (`text: String, separator: String`) - Gives how many pieces text breaks into when split by a separator.
- **Find In Text** (`text: String, needle: String`) - Gives where a substring first appears in text, or -1 if it's missing.
- **Left** (`text: String, count: String`) - Gives the first few characters from the start of some text.
- **Right** (`text: String, count: String`) - Gives the last few characters from the end of some text.
- **Mid** (`text: String, from: String, count: String`) - Gives a chunk of text starting at a position for a set length.
- **Uppercase** (`text: String`) - Gives the text converted to all uppercase letters.
- **Lowercase** (`text: String`) - Gives the text converted to all lowercase letters.
- **Text Length** (`text: String`) - Gives how many characters are in some text.
- **Replace In Text** (`text: String, what: String, with: String`) - Gives the text with every match of one substring swapped for another.
- **Trim** (`text: String`) - Gives the text with leading and trailing whitespace removed.
- **Zero Pad** (`digits: String, value: String`) - Gives a number padded with leading zeros to a fixed width, like 007.
- **To Text** (`value: String`) - Gives any value as text, for joining into messages and labels.
- **Absolute Value** (`value: String`) - Gives the number without its sign: abs(-5) is 5.
- **Square Root** (`value: String`) - Gives the square root of a number.
- **Power** (`base: String, exponent: String`) - Gives a number raised to a power: 2 ^ 8 is 256.
- **Exponential** (`value: String`) - Gives e raised to a power, the natural growth curve.
- **Pi** - Gives the circle constant 3.14159…
- **Sin (degrees)** (`degrees: String`) - Gives the sine of an angle given in degrees - waves, bobbing, circular motion.
- **Cos (degrees)** (`degrees: String`) - Gives the cosine of an angle given in degrees.
- **Tan (degrees)** (`degrees: String`) - Gives the tangent of an angle given in degrees.
- **To Integer** (`value: String`) - Gives the value as a whole number: int("42") is 42, int(3.9) is 3.
- **To Decimal** (`value: String`) - Gives the value as a decimal number: float("3.5") is 3.5.
- **Date & Time Text** - Gives the system's current date and time as readable text.
- **Unix Time** - Gives the current Unix timestamp in seconds, useful for saving real-world time.
- **OS Name** - Gives the name of the operating system the game is running on.
- **Cooldown Time Left** (`name: String`) - Gives the seconds left on a named cooldown, or 0 when it is ready - handy for a HUD readout.
- **Now** - The moment right now, as the game's own running clock. Store it in a variable and ask Seconds Have Passed Since about it later. It restarts with the game.
- **Now (Clock Time)** - The moment right now by the system clock, in seconds. Unlike Now, this keeps counting while the game is closed - which is what a daily reward or an idle-earnings sum needs.
- **Viewport Width** (`target: String`) - How wide the visible layout is, in pixels - the right edge to spawn at, wrap around, or clamp to.
- **Viewport Height** (`target: String`) - How tall the visible layout is, in pixels - the bottom edge to spawn at, wrap around, or clamp to.
- **Effect Parameter** (`param: String, target: String`) - Gives the current value of one of this object's effect parameters.
- **The Spawned** (`spawn_name: String`) - The node a Spawn Scene As row made under this name, or nothing at all when it was never spawned or has since been freed - so a row that reaches for a dead boss gets nothing instead of a crash.

### Table (`res://addons/eventforge/registration/modules/table_aces.gd`)
Tables (a spreadsheet read as rows of records) plus the text/folder loops.

#### Conditions
- **For Each Line In Text** (`text: String`) - Runs this event's actions once per LINE of the text, skipping blank ones. Windows (CRLF) and old-Mac (CR) endings are handled, so no line arrives with a stray carriage return. Read the current one as `line`.
- **For Each Part In Text** (`text: String, separator: String`) - Runs this event's actions once per PIECE of the text. Each piece arrives with its surrounding spaces trimmed, and empty pieces are skipped, so "sword; shield;; bow" is three parts. Read the current one as `part`.
- **For Each Resource In Folder** (`folder: String`) - Runs this event's actions once per data asset (.tres / .res) in a folder, already loaded - the "a folder of items IS my item list" setup, with no list to maintain. A folder that is not there walks nothing (quietly - it is checked first, so a loop that runs every frame cannot spam errors), and anything that fails to load is skipped rather than arriving as null. Read the current one as `entry`.

#### Expressions
- **Table From File** (`path: String, separator: String`) - Reads a .csv whose FIRST line is the column names and gives you one record per row, each field reachable by column name - row["price"]. Quoted cells may contain the separator, Windows line endings are fine, and a missing file simply gives no rows. Store it in an Array variable, then walk it with a For Each pick filter.
- **Table From Text** (`text: String, separator: String`) - The same column-names-first parse as Table From File, but over text you already hold instead of a file on disk.
- **Column Of Table** (`table: String, column: String`) - Gives one whole column as a list, in row order - handy for a dropdown's items, a weights list, or a quick sum. A row missing that column contributes empty text.
- **Row Where** (`table: String, column: String, value: String`) - Finds the FIRST record whose column holds this value - the single-item lookup, e.g. the row for item "sword". Gives an empty record when nothing matches, so check it with Dictionary Is Empty before reading fields.

### Testing (`res://addons/eventforge/registration/modules/testing_aces.gd`)
Testing vocabulary (a sheet that makes claims and reports pass/fail).

#### Triggers
- **On Test Start** - Runs when a test runner starts this test sheet. A Test sheet declares signal test_started(test_name: String) and the runner emits it, so the test's name arrives as a parameter you can use in messages.

#### Conditions
- **Watch For Signal Succeeded** (`signal_name: String`) - True when the matching Watch For Signal row saw its signal fire before the time ran out.
- **Watch For Signal Timed Out** (`signal_name: String`) - True when the matching Watch For Signal row ran out of time without the signal firing - the outcome a test has to be able to name.

#### Actions
- **Assert That** (`named: String, claim: String`) - Records a pass when the check is true and a failure when it is not, under the name you give it. The failure message says what the check was, so the report can be read without opening the sheet.
- **Assert Equal** (`named: String, actual: String, expected: String`) - Records a pass when the two values are equal. The failure message carries BOTH values ("expected 3, got 2") - the one fact a failing equality check always needs.
- **Expect Signal** (`named: String, signal_name: String, target: String, seconds: String`) - Waits for a signal and records the verdict itself: a pass when it fires in time, a failure saying "expected within 2.00s, never fired" when it does not. Use Watch For Signal instead when the test should decide what each outcome means.
- **Pass Test** (`named: String`) - Records a pass under this name and marks the test finished, so a runner stops waiting on it and moves to the next one.
- **Fail Test** (`named: String, reason: String`) - Records a failure with its reason and marks the test finished. The reason is what the report prints beside the name.
- **Watch For Signal** (`signal_name: String, target: String, seconds: String`) - Waits until the signal fires or the time runs out, then records which happened. It states no verdict of its own: the next rows read it with Watch For Signal Succeeded / Watch For Signal Timed Out and decide what each outcome means.
- **Load Scene Under Test** (`scene_path: String, as_name: String`) - Instantiates a scene, adds it under the test node so it really runs, and remembers it under a short name. A missing scene is recorded as a failure rather than crashing the test.

#### Expressions
- **Scene Under Test** (`as_name: String`) - The node a Load Scene Under Test row loaded under this name, so later rows can read its position, call its methods, or watch its signals.

### Text Extract (`res://addons/eventforge/registration/modules/text_extract_aces.gd`)
reading a part out of a line, and saying what went wrong.

#### Expressions
- **Text Before** (`text: String, marker: String`) - The part of the text before the first marker: Text Before("Ada [angry]: hi", " [") is "Ada". When the marker is not there you get the whole text back, so nothing is silently lost.
- **Text After** (`text: String, marker: String`) - Everything after the first marker: Text After("Ada [angry]: hi", "]: ") is "hi". Empty when the marker is not there, because then there is no "after".
- **Text Between** (`text: String, open: String, close: String`) - The part between two markers: Text Between("Ada [angry]: hi", "[", "]") is "angry". Empty when the opening marker is missing, and the rest of the text when the closing one is.
- **Number In Text** (`text: String`) - The first number found anywhere in the text, whole or decimal: "Chapter 3" gives 3, "v1.25-beta" gives 1.25. You get 0 when there is no number at all, and you never write a pattern.
- **Split Keeping Quotes** (`text: String, separator: String`) - Splits text on a separator but keeps anything inside "double quotes" together as one piece, and drops the quotes: give "iron sword" 2 is three pieces, not four. Empty pieces are skipped, so runs of separators never produce blanks.
- **Explain JSON Problem** (`text: String`) - Why this JSON failed to parse, with the line: "line 4: Expected ':'". Empty when it parses fine, so an empty result IS the all-clear. Log it and the bug report writes itself. Branch on this expression's own emptiness (Text Is Blank, inverted) rather than on JSON Is Valid: that condition reads a file holding just the word null as invalid, and this one has nothing to say about it, so pairing them logs an error with a blank reason.
- **Explain Table Problem** (`records: String, columns: String`) - The first cell of a table that should be a number and is not, said out loud: "row 12, column "price": "abc" is not a number". Rows are counted from 1 over the rows you hold - Table From File has already used up the header line, so row 12 is line 13 of the file. A row that is not a record at all is reported too. Empty when every listed column checks out.
- **Missing Fields** (`record: String, fields: String`) - The listed fields that are missing or left blank, comma-separated, and empty when the record is complete. Blank means nothing there: null, empty text, an empty list or an empty record - a 0 is a real value and is never reported.

### Text Fit (`res://addons/eventforge/registration/modules/text_fit_aces.gd`)
the drawn side of text: direction, glyph coverage, and fit in PIXELS.

#### Conditions
- **Language Reads Right To Left** - True while the game is running in a right-to-left language: Arabic, Hebrew, Persian, Urdu. The engine answers, so a language you add later is covered without editing a list of codes.
- **Layout Is Mirrored** (`target: String`) - True when this control is currently laid out right to left. Ask it before a hand-placed offset or a slide-in tween, so the panel still enters from the side the player reads towards. Godot mirrors containers and anchors for you; this is for the positions you set yourself.
- **Font Can Show** (`font: Font, text: String`) - True when the font has a glyph for every character in the text, empty text included. It follows the fallback chain, so a font that has been given a CJK fallback answers true for Japanese. Invert it (right-click the row) and log the failure, and "we found out from a store review" becomes something you see while authoring.
- **Text Overflows** (`target: String`) - True when the text is wider than the control showing it - the clipped-button bug, answered in pixels with the control's real font instead of a character count. It measures what the control DRAWS, so a label still holding its English source string is measured in the language on screen. This is about controls that cannot grow: a Label or Button free to widen is grown by the engine to fit its text and honestly answers false, so turn on Clip Text (or a Text Overrun Behavior, or put it in a fixed-size container) for the answer to mean anything. It measures ONE line, so for a label that wraps, compare Wrapped Text Height against the box height instead.
- **Text Fits In Width** (`text: String, width: String, font: Font, font_size: String`) - True when the text would draw no wider than that many pixels - the check for a control you are about to fill or size, before it exists on screen. Invert it and widen the button, or pick a shorter key. The width is in pixels, so it survives the proportional font and the long language that a character count does not.

#### Actions
- **Mirror Layout For Language** (`target: String`) - Makes this control - and everything under it - lay itself out from the game's language: containers, anchors and margins mirror for a right-to-left language, and flip back the moment the language changes again. One row on your UI root usually covers the whole game.
- **Add Font Fallback** (`font: Font, fallback: Font`) - Any character the main font cannot draw is drawn by this one instead, so a Japanese, Russian or emoji-carrying build stops rendering empty boxes while your Latin text keeps the face you chose. Adding the same fallback twice does nothing, so this is safe to run on every load and after every language change.
- **Use Font** (`font: Font, slot: String, target: String`) - Gives ONE control its own font, without a theme resource: a per-language display face, a monospace font so the column actions line up, a bigger face for a heading. Run it again with another font and the new one wins.
- **Fit Text To Label** (`suffix: String, target: String`) - Backs this control's text up until it MEASURES inside the control, and marks the cut. Whole words first (the Shorten To Whole Words rule), falling back to cutting mid-word when one long word is all there is, and cutting with no marker at all when the control is too narrow to hold even the ending - so the result is never just the ending and never wider than the control. It cuts the TRANSLATED line, and remembers the string it was given in the node's "fit_source_text" meta, so running it again after a language switch re-fits the whole sentence instead of trimming its own leftovers - and a line that now fits is put back in full, still translating itself. Needs a control that cannot grow (Clip Text, a Text Overrun Behavior, or a fixed-size container); one free to widen never overflows in the first place.

#### Expressions
- **Font Of This Control** (`target: String`) - The font this control is actually drawing with right now, whether that came from a theme, a Use Font row or the engine default. Feed it to Font Can Show or Add Font Fallback so those rows are about the real font on screen instead of one you named twice.
- **Wrapped Text Height** (`text: String, width: String, font: Font, font_size: String`) - How TALL the text becomes once it wraps into a box that wide, in pixels. The answer for a dialogue box or a quest log: compare it with the box height and grow the panel, shrink the font or split the line before the last sentence disappears off the bottom in the one language nobody on the team reads.

### Text Format (`res://addons/eventforge/registration/modules/text_format_aces.gd`)
DISPLAY text: making a value readable before it reaches a Label.

#### Actions
- **Set Text (translated pattern)** (`pattern: String, values: String, target: String`) - Sets this Label's text from a pattern that is translated FIRST and filled second. The pattern - slots and all - is the translation key. Re-run it under On Language Changed so the label follows a live language switch.

#### Expressions
- **Shorten To Fit** (`text: String, max_chars: String, suffix: String`) - Trims text to a maximum number of characters and marks the cut with the ending you choose, so a clipped name never reads as the whole name. Text that already fits comes back untouched, and the result never runs past the width you gave - a width too narrow to hold the ending simply cuts without one. Cuts mid-word: use Shorten To Whole Words when the cut should land on a word boundary.
- **Shorten To Whole Words** (`text: String, max_chars: String, suffix: String`) - Like Shorten To Fit, but backs up to the last complete word before cutting, so "Ancient Sword of Thorns" reads "Ancient Sword..." instead of "Ancient Sword of Th". When the budget holds no whole word (one very long word) it falls back to cutting by characters, and when it is too narrow to hold the ending at all it cuts without one - so the result is never just the ending, and never wider than you asked for.
- **With Thousands Separators** (`value: String`) - Turns a number into grouped digits a player can take in at a glance: 1234567 reads "1,234,567". Whole numbers only (the fraction is dropped); a negative keeps its minus sign. For idle-game scale (1.23e15, "1.23 Qa") reach for the Big Numbers pack instead.
- **As Percent Text** (`value: String, decimals: String`) - Turns a fraction into percent TEXT with the sign on it: 0.73 reads "73%". Feed it a 0-to-1 value (Percent Of already returns 0-to-100, so divide that by 100 or use the raw fraction).
- **As Duration** (`seconds: String`) - Seconds as a duration that survives passing an hour: 3725 reads "1h 02m" and 90 reads "1m 30s". A negative duration reads as zero. Use As Clock Time when you want strict mm:ss (it rolls an hour into "60:00").
- **Align Left** (`text: String, width: String, fill: String`) - Pads text out on the RIGHT to a fixed width, so every row starts on the same edge and reads as a column. Text longer than the width is left alone (it is never cut - shorten it first). Give the Label a MONOSPACE theme font or the column will still drift.
- **Align Right** (`text: String, width: String, fill: String`) - Pads text out on the LEFT to a fixed width, so numbers END on the same edge and read as a column of figures. Text longer than the width is left alone. Give the Label a MONOSPACE theme font or the column will still drift.
- **Center In Width** (`text: String, width: String, fill: String`) - Pads text on BOTH sides to a fixed width, so a heading sits in the middle of a column. An odd leftover space goes on the right. Text longer than the width is left alone. Give the Label a MONOSPACE theme font or the centering will still drift.
- **As Title Text** (`text: String`) - Turns a machine id into a readable name: "fire_sword" reads "Fire Sword", "maxHealth" reads "Max Health". Use it wherever a key has to be shown to a player, so ids and labels never drift apart in two places.
- **As Sentence Text** (`text: String`) - Raises the FIRST letter only and leaves the rest of the text exactly as it is, so "NPC" and "HP" keep their capitals. Empty text stays empty.
- **Translated Text From Pattern** (`pattern: String, values: String`) - Looks the whole sentence up in the current language FIRST, then fills its {slots}. The pattern you type here - slots and all - is the translation key, so it is what goes in the catalog. Filling the slots first (Translate around Text From Pattern) produces a string no catalog can contain, and the text then never translates.

### Tilemap (`res://addons/eventforge/registration/modules/tilemap_aces.gd`)
Tilemaps (TileMapLayer, Godot 4.3+)

#### Conditions
- **Tile Has Custom Data** (`coords: String, name: String, target: String`) - True when the tile at a cell carries the named custom data - how a tileset marks walls, water or ladders.
- **Cell Is Empty** (`coords: String, target: String`) - True when the chosen tilemap cell has no tile in it.
- **Cell Has Tile** (`coords: String, target: String`) - True when the chosen tilemap cell actually has a tile placed.

#### Actions
- **Set Tile** (`coords: String, source_id: String, atlas_coords: String, target: String`) - Paints a tile at a grid cell, choosing which tileset and which tile of it to use.
- **Erase Tile** (`coords: String, target: String`) - Clears the tile at a single grid cell, leaving it empty.
- **Clear Tilemap** (`target: String`) - Wipes every tile from the tilemap layer, leaving it blank.

#### Expressions
- **Tile At** (`coords: String, target: String`) - Returns which tileset the tile at a cell came from, or -1 when the cell is empty.
- **Cell Atlas Coords** (`coords: String, target: String`) - Returns which tile in the atlas sits at the given cell.
- **Used Cells Count** (`target: String`) - Returns how many cells in the tilemap currently hold a tile.
- **Position To Tile** (`pos: String, target: String`) - Converts a pixel position into the cell coordinates that contain it.
- **Tile To Position** (`coords: String, target: String`) - Converts cell coordinates into the pixel position at that cell's center.

### Tooling (`res://addons/eventforge/registration/modules/tooling_aces.gd`)
Editor Tools vocabulary (build @tool / EditorScript sheets by events).

#### Triggers
- **On Project Export** - Runs while a project export is starting, before the files are written - the place to stamp a build number, bake a data file, or strip debug content.
- **On File Imported** - Runs just after Godot finishes importing assets - the paths that landed arrive as `paths`. The place to rename what a designer dropped in, check an atlas for the wrong settings, or write a manifest.

#### Conditions
- **Resource Exists** (`path: String`) - True when a resource file already exists at the given path.
- **Is In Editor** - True when the script is running inside the editor (a @tool script), not the running game.
- **Export Is Debug** - True when the export that triggered this bake step is a debug build. Use it inside On Project Export to keep test content out of release builds.
- **Export Has Feature** (`feature: String`) - True when the export preset that triggered this bake step carries the given feature tag - the way to bake different data for mobile, web or desktop.

#### Actions
- **Open Scene In Editor** (`path: String`) - Opens a scene file in the editor as the current edited scene.
- **Save Current Scene** - Saves the scene currently open in the editor.
- **Save Scene As** (`path: String`) - Saves the current scene to a new path.
- **Play Current Scene** - Runs the scene open in the editor, as if you pressed Play Scene.
- **Stop Playing** - Stops the running game started from the editor.
- **Rescan Project Files** - Re-imports the FileSystem dock so files written by a tool show up right away.
- **Select Node In Editor** (`node: Node`) - Clears the current selection and selects a node in the Scene dock.
- **Inspect In Editor** (`object: Object`) - Shows a node or resource in the Inspector dock.
- **Save Resource To File** (`resource: Resource, path: String`) - Writes a resource out to a file on disk.
- **Make Sure Folder Exists** (`path: String`) - Creates a folder (and any missing parents) so a tool can write into it.
- **Add Node To Edited Scene** (`node: Node, parent: Node`) - Adds a new node to the edited scene AND sets its owner, so it is saved with the scene.
- **Save Node As Scene** (`node: Node, path: String`) - Packs a node and its children into a PackedScene and saves it as a .tscn file.
- **Render Scene To Image** (`scene_path: String, width: int, height: int, save_path: String`) - Instantiates a scene into an off-screen viewport, lets it settle for a frame, and saves what it shows as a PNG - thumbnails, store shots, doc figures, baked sprites. Needs a windowed editor: a headless run has no renderer, so it warns and writes nothing.
- **Preview Table Rolls** (`table: String, rolls: int, seed: int, save_path: String`) - Rolls a weighted table many times and reports what actually came out: per entry the rolled percent, the percent its weight implies, and the gap between them. Pure maths - it runs anywhere, and the same seed always gives the same numbers.
- **Write Version Stamp** (`path: String, version: String`) - Writes a small build stamp file: the version string plus the date and time the stamp was written. The timestamp is read when the tool runs, so the generated code stays identical every save.

#### Expressions
- **Edited Scene Root** - Returns the root node of the scene currently open in the editor.
- **Selected Nodes** - Returns the array of nodes currently selected in the Scene dock.
- **Editor Scale** - Returns the editor's display scale (1.0 at 100%), for sizing tool UI.

### Translation (`res://addons/eventforge/registration/modules/translation_aces.gd`)
Translation vocabulary (localisation the Godot way).

#### Triggers
- **On Language Changed** - Runs when the game's language switches. Compiles to the _notification virtual with the Language Just Changed gate added for you.

#### Conditions
- **Language Just Changed** - The gate under On Language Changed: true only for the engine's translation-changed notification.
- **For Each Language** - Runs this event's actions once per language your project actually ships - the catalogs Godot loaded from Project Settings > Localization. Read the current one as `language`. A language you add later joins the menu with no sheet edit, and a demo build that ships fewer catalogs shows fewer entries. Only languages WITH a catalog are listed, so English usually appears only when it has one of its own.
- **Language Is Available** (`locale: String`) - True when a catalog for that language is registered in this build. Gate a flag button on it and a demo build hides the languages it did not ship. Matched the way Godot matches, not letter for letter, so a build that ships pt_BR answers true for "pt" as well - ask Language Has Text For when you need one exact catalog.
- **Language Matches** (`locale: String`) - True when the game is running in that language, region or not - "en" matches a player on en_US and on en_GB, which is what a content branch almost always wants. Comparing Current Language to a string by hand is right for "en" exactly and wrong for every regional player.
- **Region Is** (`country: String`) - True when the active locale names that country - pt_BR is region BR, plain pt is no region at all and answers false. It looks at every subtag after the language rather than only the last one, so sr_Latn_RS reads RS and a locale carrying a variant (ca_ES_valencia) still reads ES; and a country code is capitals, so a script subtag like the Hans in zh_Hans can never be mistaken for one. For a region-gated screen (an imprint page, an age gate, a storefront link) rather than a translation.
- **Text Is Translated** (`key: String`) - True when the active language has text for this key. A key with no entry comes back unchanged from tr(), which is exactly what a player then sees on screen - this is the row that catches it first. Note that a translation IDENTICAL to the source reads as untranslated; use Language Has Text For when that matters.
- **Language Has Text For** (`locale: String, key: String`) - Asks one language's catalog directly, without switching to it - the exact check, so a translation identical to its source still counts. Exact in the OTHER sense too: it answers about the catalog for that very locale, so a build shipping pt_BR answers false for "pt_PT" rather than handing back Brazilian text. A language with no catalog of its own answers false. Use it to offer a language only when the screen the player is about to see is actually translated.

#### Actions
- **Set Language** (`locale: String`) - Switches the game's language live. Auto-translated Controls and every later tr() lookup follow immediately.
- **Use Saved Language** (`fallback: String`) - Applies the language the player picked last time, reading the same user://settings.cfg the Save Setting action writes - section "game", key "language". A first run has no file yet and falls back to whatever you pass, so pair it with a Save Setting on the button that switches.
- **Set Text (follows language)** (`key: String, target: String`) - Sets the text AND remembers which key it came from, so one Refresh row re-applies it when the language switches. Godot only re-renders text a Control still HOLDS as its source string; the moment a sheet looks a key up and assigns the result, that node stops following - this is the fix. The key is kept in the node's "follows_language_key" meta and the node joins the "follows_language" group. Plain keys only: for a sentence with values in it use Set Text (translated pattern) and re-run it from a function.
- **Refresh Text That Follows Language** - Re-applies every remembered key in the current language. One row under On Language Changed and every label written by Set Text (follows language) switches in place - no scene reload, no per-label wiring. Nodes are found through the "follows_language" group, so a node you tagged yourself is refreshed too.
- **Keep This Text Untranslated** (`target: String`) - Stops Godot auto-translating this Control and everything under it - for text that is DATA, not writing: a player's name, chat, a save-slot label, a mod's item name, a debug overlay. Without it a save named "Play" turns into "Jouer" the moment a catalog happens to contain that word.
- **Set Text (counted)** (`singular: String, plural: String, count: String, target: String`) - Sets this Label to the counted sentence in one row: the language picks the form and the number is filled in. The same action as Counted Text without an expression to nest, down to keeping both forms' %d - a form that lost its %d comes back unfilled rather than erroring. Re-run it under On Language Changed so the line follows a live switch.
- **Test With Fake Translation** (`on: bool`) - Turns Godot's pseudolocalization on: every translatable string comes back accented and bracketed ("Ready" reads "[Ready]" with accents on every letter), so text that stays PLAIN is text you never marked. Length expansion is a separate Project Settings knob under Internationalization > Pseudolocalization - turn it up and a layout that overflows here will overflow in German. Gate it on a debug build.

#### Expressions
- **Current Language** - The active locale code, e.g. "en" or "es".
- **Translate** (`text: String`) - Looks the text up in the current language (tr). For a fixed label, the field's globe toggle does this without an expression.
- **Translate With Context** (`text: String, context: String`) - tr() with a translation context, for strings that read the same but translate differently.
- **Translate Plural** (`singular: String, plural: String, count: String`) - Picks the singular or plural form for the count in the current language (tr_n); languages with more plural forms use their catalog's rules. It returns the chosen form as it stands, so a "%d apples" form still carries its %d - Counted Text is the one that fills the number in.
- **Language Name In Its Own Language** (`locale: String`) - The language's name as its own speakers write it: put a LANGUAGE_NAME row in each catalog (LANGUAGE_NAME,Deutsch,Espanol) and a German player reads "Deutsch". It reads THAT language's own catalog and no other, so a build shipping only pt_BR does not label a pt_PT entry with the Brazilian name. Falls back to Godot's English name when the row is missing, and to the bare code when the language has no catalog of its own, so a menu entry is never blank.
- **Value For Language** (`choices: Dictionary, fallback: Variant`) - Picks the entry whose language BEST matches the player's, not the one that matches exactly - so a pt_BR player gets the "pt" entry and a zh_Hans player gets "zh". One row for a splash image, a voice folder, a name order, a currency shape or a regional variant. An entry that scores nothing leaves the fallback standing, so an unlisted language is never a wrong pick.
- **Current Language Name** - The language the game is running in, written out in ENGLISH - "Russian", or "Portuguese, Brazil" when the locale carries a region. For the name its own speakers would recognise, use Language Name In Its Own Language.
- **Country Name** (`country: String`) - Turns a country code into its readable name in English - "DE" reads "Germany". Pair it with Region Is when a screen has to name the region it is showing.
- **Counted Text** (`singular: String, plural: String, count: String`) - Picks the form the player's language uses for this count AND fills the number into it, so "%d apple" / "%d apples" reads "3 apples". Translate Plural stops one step short: it returns the chosen form with the %d still in it, which is why a label built from it reads "%d apples". A gettext (.po) catalog carrying three Russian forms uses all three; a CSV catalog holds the two forms as two ordinary rows and the count picks between them, which is as far as that file format can go. Both forms must keep their %d - a translation that drops it comes back unfilled, and nothing errors.
- **Counted Text From Pattern** (`singular: String, plural: String, count: String, values: String`) - The plural twin of Translated Text From Pattern: the language picks the form FIRST, then the slots fill. Use it when the sentence carries more than the count, so a translator can move {n} and {total} where their grammar wants them.
- **Translated Text Or Fallback** (`key: String, fallback: String`) - Looks the key up and falls back when the active language has no entry, so a half-finished catalog never shows a raw key to a player. Chain them by putting another Translated Text Or Fallback in the Otherwise field.
- **Translated Text From Pattern In Context** (`pattern: String, context: String, values: String`) - The two shipped halves in one row: the whole sentence is looked up in the current language WITH a context, then its {slots} fill. One key can hold a masculine, feminine and neutral translation, and the context can be read from a variable at runtime. A context with no entry falls back to the source sentence, so an unwritten variant still reads.
- **Translated Text With Words** (`pattern: String, words: String, values: String`) - Fills a translated sentence from a standing word set plus this line's values, so a player-named, player-gendered character reads correctly everywhere without an if-chain per line. Keep the word set in one variable and every line follows a change to it. The translator receives one key with {name} and {they} slots and decides where they land in their own grammar.
- **Number In Local Digits** (`value: String, locale: String`) - Writes a number in the digits the language uses, so an Arabic player reads Arabic-Indic numerals and an English one reads 1234. Digits ONLY - it does not group thousands (that is With Thousands Separators, which is comma-only). A language Godot has no digit set for comes back unchanged, which is most of them, so this is safe to leave on everywhere.
- **Number From Local Digits** (`text: String, locale: String`) - Turns digits the player typed in their own numeral system back into plain ASCII ones you can put through Whole Number From Text - the return trip for Number In Local Digits, so a quantity field works for every player.
- **Percent Sign** (`locale: String`) - The percent sign the language writes - Arabic and Persian use their own. Pair it with Number In Local Digits instead of typing "%" into a label.
- **Date Parts** (`unix: String`) - A date broken into {year}, {month}, {day}, {hour}, {minute}, {second} and {weekday}, ready to fill a translated pattern - so DATE_FORMAT reads "{month}/{day}/{year}" in English and "{day}.{month}.{year}" in German, and a translator fixes the order without a build. Drop it into the Values field of Set Text (translated pattern). The parts are UTC, the same clock Unix Time reads.

### Translation Quality (`res://addons/eventforge/registration/modules/translation_quality_aces.gd`)
Translation QUALITY: is the catalog actually finished?

#### Conditions
- **Translation Is Complete** (`locale: String, path: String, separator: String`) - True only when every source string in the spreadsheet has a filled cell for that language. An empty, missing or unreadable catalog is never "complete", so a mistyped path fails a build gate loudly instead of passing it. Put it under On Project Export beside Export Has Feature "release", inverted, and a release build can refuse to ship half-translated.

#### Expressions
- **Translation Coverage** (`locale: String, path: String, separator: String`) - How much of the translator's spreadsheet that language actually fills, as a number from 0 to 100. A cell holding only spaces counts as unfilled, and a file that is missing or unreadable reads as 0 rather than as finished. Reads the .csv exactly the way Table From File reads it, so the number in a build gate is the number the game sees.
- **Missing Translation Keys** (`locale: String, path: String, separator: String`) - The list of source strings that language has NOT filled in, in file order - so the Output panel, a debug overlay or an export gate can NAME them instead of only counting them. Empty when the language is finished. Each entry is the first column of its row, which is the string the catalog is keyed by.

### Ui (`res://addons/eventforge/registration/modules/ui_aces.gd`)
UI / menu vocabulary (Control / BaseButton / Range / LineEdit)

#### Triggers
- **On Pressed** - Runs when the player clicks or activates this button.
- **On Toggled** (`toggled_on: bool`) - Runs when a toggle button is switched on or off.

#### Conditions
- **Has Focus** (`target: String`) - True when this control currently holds keyboard focus.
- **Is Button Pressed** (`target: String`) - True while this button is currently pressed or toggled on.
- **Is Button Disabled** (`target: String`) - True when this button is disabled and can't be clicked.

#### Actions
- **Grab Focus** (`target: String`) - Gives this control keyboard focus, so input goes to it next.
- **Release Focus** (`target: String`) - Removes keyboard focus from this control.
- **Focus Next** - Moves keyboard focus to the next control in tab order.
- **Focus Previous** - Moves keyboard focus to the previous control in tab order.
- **Set Focus Neighbor** (`side: String, target: String`) - Sets which control gets focus when arrowing in a given direction.
- **Set Anchors Preset** (`preset: String, target: String`) - Snaps a control's anchors to a layout preset like full-rect or center.
- **Override Theme Color** (`name: String, color: String, target: String`) - Overrides one theme color on this control, like its font color.
- **Set Button Disabled** (`disabled: String, target: String`) - Enables or disables a button so it can or can't be clicked.
- **Set Button Pressed** (`pressed: String, target: String`) - Sets a toggle button's pressed state without firing its toggled event.
- **Set Slider Value** (`value: String, target: String`) - Sets a slider, progress bar, or spinbox to a specific value.
- **Set Max Value** (`max: String, target: String`) - Sets the maximum value of a slider, progress bar, or spinbox.
- **Set Field Text** (`value: String, target: String`) - Sets the text shown in a single-line text field.
- **Clear Field** (`target: String`) - Empties a single-line text field of all its text.

#### Expressions
- **Button Text** (`target: String`) - Returns the label text currently shown on the button.
- **Value** (`target: String`) - Returns the current value of a slider, progress bar, or spinbox.
- **Value Ratio** (`target: String`) - Returns the value as a 0-to-1 ratio, handy for filling bars.
- **Field Text** (`target: String`) - Returns whatever text the player has typed into the field.

### Vibration (`res://addons/eventforge/registration/modules/vibration_aces.gd`)
Vibration vocabulary (rumble a gamepad, buzz a phone).

#### Actions
- **Stop Gamepad Vibration** (`device: int`) - Stops a gamepad rumble that is still running.
- **Vibrate Phone** (`duration_ms: int`) - Buzzes a handheld device (phone / tablet) for a moment. Does nothing on desktop.

#### Expressions
- **Gamepad Vibration Strength** (`device: int`) - The current rumble strength of a gamepad as a Vector2 (weak, strong motor).

### Window (`res://addons/eventforge/registration/modules/window_aces.gd`)
Game Window vocabulary (control the OS window from events).

#### Conditions
- **Is Fullscreen** - True while the game is in either fullscreen mode.

#### Actions
- **Go Fullscreen** - Switches the game to borderless fullscreen.
- **Go Windowed** - Switches the game back to a normal window.
- **Go Exclusive Fullscreen** - Switches to exclusive fullscreen (the mode that takes over the whole display).
- **Toggle Fullscreen** - Flips between fullscreen and windowed - handy on an Alt+Enter shortcut.
- **Set Window Size** (`width: int, height: int`) - Resizes the game window to an exact pixel size.
- **Set Window Position** (`x: int, y: int`) - Moves the game window to a position on the screen.
- **Center Window** - Centers the game window on the screen.
- **Set VSync Enabled** (`enabled: bool`) - Turns vertical sync on or off - a common options-menu toggle.
- **Set Max FPS** (`fps: int`) - Caps the frame rate (0 means uncapped).
- **Set Always On Top** (`enabled: bool`) - Keeps the game window above every other window.
- **Minimize Window** - Minimizes the game window to the taskbar.
- **Maximize Window** - Maximizes the game window.

#### Expressions
- **Max FPS** - The current frame-rate cap (0 means uncapped).
