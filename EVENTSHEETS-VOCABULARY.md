# Project vocabulary - Godot EventSheets

> Generated - do not edit. Regenerate via the dock (Tools → Vocabulary Doc…) or
> `godot --headless --path . --script tools/vocabulary_doc.gd`.

## Sheets

### player (`res://demo/sheets/player.tres`)
Node script extending `CharacterBody2D`.

#### Properties
- `health: int` (default `100`)
- `speed: float` (default `200.0`)

## Script packs

### SimpleAbilitiesBehavior (`res://eventsheet_addons/abilities/abilities_behavior.gd`)
@ace_category("Abilities") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Ability Activated**

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
- **Format Time** (`seconds: float`) - Seconds as a friendly duration: 3725 -> "1h 2m 5s". Drops leading zero units (90 -> "1m 30s
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

#### Conditions
- **Is Active** (`id: String`) - Whether a boost with this id is currently running.
- **Any Active** - Whether any boost is currently running.

#### Actions
- **Start Boost** (`id: String, multiplier: float, duration: float`) - Starts (or restarts) a timed multiplier by id for `duration` seconds and fires On Boost Started.
- **Start Tagged Boost** (`id: String, multiplier: float, duration: float, tag: String`) - Like Start Boost, but with a tag so Multiplier For Tag can group it (e.g. "production", "click
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

#### Actions
- **Set Bullet Speed** (`value: float`) - Changes speed, keeping the current direction.
- **Set Angle Of Motion** (`degrees: float`) - Redirects the bullet (degrees).
- **Set Gravity Angle** (`angle: float`) - Points gravity in a new direction, in degrees (90 = down, 270 = up, 0 = right) - the arc bends that way from now on. Magnet fields, wind wells, and upside-down zones in one action.
- **Set Bullet Enabled** (`is_enabled: bool`) - Pauses or resumes the movement.

### Bullet3DBehavior (`res://eventsheet_addons/bullet_3d/bullet_3d_behavior.gd`)
@ace_category("Bullet 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Actions
- **Launch Forward** - (Re)launches along the host's current forward direction.
- **Set Bullet 3D Speed** (`value: float`) - Changes speed, keeping the current direction.
- **Set Gravity Direction** (`x: float, y: float, z: float`) - Points gravity along a new 3D direction (it is normalized for you) - the arc bends that way from now on. (0, -1, 0) is normal down, (0, 1, 0) pulls up, (1, 0, 0) pulls along +X.

### CarBehavior (`res://eventsheet_addons/car/car_behavior.gd`)
@ace_category("Car") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Drift Started**

#### Actions
- **Stop Car** - Kills all momentum.

### ClickPowerAddon (`res://eventsheet_addons/click_power/click_power_addon.gd`)
@ace_tags(incremental, idle, clicker) @ace_category("Click Power") @ace_version(1.0.0)

#### Triggers
- **On Click**

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

#### Conditions
- **Has Combo** (`id: String`) - Whether a combo id is registered.
- **Is Combo Enabled** (`id: String`) - Whether a combo is registered and enabled.
- **Is Buffer Empty** - Whether the input buffer has no tokens.
- **Combo Has Tag** (`id: String, tag: String`) - Whether a combo carries a tag.

#### Actions
- **Register Combo** (`id: String, sequence: String, timing_window: float`) - Registers (or replaces) a combo: a unique id and its sequence as comma-separated tokens (for example "down,forward,punch
- **Set Combo Tags** (`id: String, tags: String`) - Tags a registered combo with comma-separated tags, so you can enable or disable it in batches (for example "ground_move
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
- **Format Amount** (`value: float, decimals: int`) - A short display string with a K/M/B/T suffix (e.g. 12500 -> "12.5K
- **Changed Id** - The currency that changed (inside On Amount Changed).
- **New Amount** - The amount after the change (inside On Amount Changed).
- **Previous Amount** - The amount before the change (inside On Amount Changed).
- **Amount Delta** - The signed change (inside On Amount Changed).
- **Failed Id** - The currency of the failed spend (inside On Spend Failed).
- **Requested Amount** - The amount that was asked for (inside On Spend Failed).
- **Available Amount** - What was actually available (inside On Spend Failed).
- **Offline Id** - The currency credited (inside On Offline Gain).
- **Offline Gain** - The amount credited offline (inside On Offline Gain).

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

### FadeBehavior (`res://eventsheet_addons/fade/fade_behavior.gd`)
@ace_tags(fade, juice) @ace_category("Fade") @ace_version(1.0.0)

#### Triggers
- **On Faded In**

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

#### Actions
- **Start Following** (`path: String`) - Follows the node at the given path.
- **Follow Group** (`group: String`) - Follows the first node in a group - no tree path, so it survives the target being moved or renamed.
- **Stop Following** - Stops trailing the target.

### FPSController (`res://eventsheet_addons/fps_controller/fps_controller_behavior.gd`)
@ace_category("FPS Controller") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Jumped**

#### Conditions
- **Is Sprinting** - True while the sprint key (Shift) is held.
- **Is First Person** - True in first-person camera mode.
- **Is Crouching** - True while crouched (including during a crouch slide).
- **Is Sliding** - True during a crouch slide.
- **Is Wall Riding** - True while riding a wall (airborne, glued to it, gravity softened).
- **Can Stand Up** - True when there is headroom to stand from the current crouch (no ceiling in the way).

#### Actions
- **Jump** - Launches the host upward with Jump Velocity and fires On Jumped. The tick calls this from the floor; call it yourself for a scripted jump.
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
- **Reset Jumps** - Refills the mid-air jump budget right now (e.g. after grabbing a double-jump power-up), so the player gets their extra jumps back without landing.
- **Stop Wall Ride** - Detaches from the wall immediately (full gravity resumes). Fires On Wall Ride Ended.
- **Set Gravity Direction** (`x: float, y: float, z: float`) - Points gravity along a new 3D direction (normalized for you). (0, -1, 0) is normal down; (0, 1, 0) walks on ceilings - floor detection and jumps follow. A tilted direction still pulls correctly but the run plane stays world-horizontal.

#### Expressions
- **Current Speed** - The host's horizontal speed right now (metres per second).
- **Look Yaw** - The current horizontal look angle in degrees (-180..180).
- **Look Pitch** - The current vertical look angle in degrees (clamped to Pitch Min/Max).
- **Wall Normal X** - The touched wall's outward normal, X component (zero when not on a wall) - with Z, the direction a wall jump pushes; feed it to camera lean.
- **Wall Normal Z** - The touched wall's outward normal, Z component (zero when not on a wall).

### SimpleHealthBehavior (`res://eventsheet_addons/health/health_behavior.gd`)
@ace_category("Health") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Damaged**

#### Conditions
- **Is Dead**
- **Is Invulnerable**
- **Has Any Health Pool**
- **Has Health Pool** (`type: String`)
- **Health Pool Is Type** (`type: String`)

#### Actions
- **Take Damage** (`amount: float`) - Applies damage; health pools absorb in ascending-priority order before real HP.
- **Heal** (`amount: float`) - Restores health up to max_health.
- **Set Health** (`amount: float`) - Sets current health directly, firing damage/heal/death as appropriate.
- **Set Max Health** (`amount: float`) - Sets max health (clamps current down if needed).
- **Set Invulnerable** (`state: bool`) - Toggles invulnerability (takeDamage no-op while true).
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

### HTNAgent (`res://eventsheet_addons/htn_agent/htn_agent_behavior.gd`)
@ace_tags(ai, planning) @ace_category("HTN") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Task Started** (`task_name: String`)

#### Conditions
- **Has Plan**
- **Current Task Is** (`task_name: String`)

#### Actions
- **Set World State** (`key: String, value`) - Writes a fact the planner reads in method preconditions.
- **Clear World State** (`key: String`) - Removes a world-state key.
- **Add Primitive Task** (`task_name: String`) - Registers a leaf task your sheet executes directly.
- **Add Compound Task** (`task_name: String`) - Registers a task that decomposes via methods.
- **Add Method** (`task_name: String, method_id: String, utility: float`) - Adds (or re-scores) a way to accomplish a compound task; highest utility wins.
- **Add Method Condition** (`task_name: String, method_id: String, key: String, op: String, value`) - A precondition (world-state key, operator, value) the method needs to be chosen.
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

#### Expressions
- **Last Button Name**
- **Bar Value** (`bar_name: String`)

### IdleGeneratorBehavior (`res://eventsheet_addons/idle_generator/idle_generator_behavior.gd`)
@ace_tags(incremental, idle, economy) @ace_category("Idle Generator") @ace_version(1.0.0)

#### Triggers
- **On Purchased**

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

### JuiceBehavior (`res://eventsheet_addons/juice/juice_behavior.gd`)
@ace_tags(camera, juice) @ace_category("Juice") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Shake Stopped**

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

#### Actions
- **Move To Position** (`x: float, y: float`) - Replaces the queue and glides toward the point.
- **Add Waypoint** (`x: float, y: float`) - Appends a stop to the queue (waypoints).
- **Stop Moving** - Clears the queue without firing On Arrived.

### MoveTo3DBehavior (`res://eventsheet_addons/move_to_3d/move_to_3d_behavior.gd`)
@ace_category("Move To 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Arrived (3D)**

#### Actions
- **Move To Position (3D)** (`x: float, y: float, z: float`) - Replaces the queue and glides toward the point.
- **Add Waypoint (3D)** (`x: float, y: float, z: float`) - Appends a stop to the queue.
- **Stop Moving (3D)** - Clears the queue without firing On Arrived.

### NavAgent3D (`res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd`)
@ace_tags(movement, 3d, ai, pathfinding) @ace_category("Nav Agent 3D") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Path Found**

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

### PhysicsCar (`res://eventsheet_addons/physics_car/physics_car_behavior.gd`)
@ace_tags(vehicle, physics) @ace_category("Physics Car") @ace_version(1.0.0)

#### Triggers
- **On Collided**

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
- **Has Feature Tag** (`feature: String`) - True when the build has a feature tag - engine ones ("mobile", "web", "editor

#### Expressions
- **OS Name** - The operating system: "Windows", "macOS", "Linux", "Android", "iOS", "Web".
- **OS Version** - The operating system's version string.
- **Device Model** - The device model name (phones report their model; desktops report "GenericDevice
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

### ProcRoomAddon (`res://eventsheet_addons/proc_room/proc_room_addon.gd`)
@ace_tags(procedural, roguelite) @ace_category("ProcRoom") @ace_version(1.0.0)

#### Triggers
- **On Graph Generated**

#### Conditions
- **Is Graph Ready** - Whether a map has been generated.
- **Is Room Visited** (`room_id: String`) - Whether a room has been entered.
- **Is Room Available** (`room_id: String`) - Whether a room can be entered right now (connected forward from current and unlocked).
- **Is Room Locked** (`room_id: String`) - Whether a room is locked.
- **Is Room Connected** (`from_id: String, to_id: String`) - Whether room A connects forward to room B.

#### Actions
- **Register Room Type** (`type_id: String, weight: float, min_depth: int, max_depth: int, max_per_depth: int`) - Registers a room type that Generate may place: a weight (higher = commoner), the depth range it may appear in (max_depth -1 = anywhere), and a per-depth cap (-1 = no cap).
- **Set Start Type** (`type_id: String`) - The type name given to the single depth-0 room (default "start
- **Set Boss Type** (`type_id: String`) - The type name given to the single final-depth room (default "boss
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

#### Conditions
- **Has Save Key** (`key: String`) - Whether the key exists in the active slot.
- **Save File Is Format** (`path: String, expected_format: String`) - Whether the save file at the path is the given format (config/json/binary/csv/ini/xml).
- **Save Format Is** (`expected_format: String`) - Whether the active save format (the Inspector format property) equals the given one.
- **Slot Exists** (`slot_index: int`) - Whether the slot has a save file.

#### Actions
- **Save Value** (`key: String, value`) - Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.
- **Save Number** (`key: String, value: float`) - Writes a number under the key (active slot).
- **Save Text** (`key: String, value: String`) - Writes a string under the key (active slot).
- **Delete Slot** - Removes the active slot's save file.
- **Save Game** - Broadcasts On Before Save (every sheet writes its state), snapshots every node in the persist group, then fires On Save Written.
- **Load Game** - Restores every persist-group snapshot, then broadcasts On After Load so every sheet reads its state back.
- **Save Node State** (`node: Node, key: String`) - Snapshots a node and its behaviors (any child with save_state) under the key.
- **Load Node State** (`node: Node, key: String`) - Restores a node and its behaviors from the key's snapshot.
- **Save Group State** (`group: String, key: String`) - Snapshots every node in the scene-tree group (and their behaviors) under the key.
- **Load Group State** (`key: String`) - Restores the group snapshot saved under the key (nodes matched by scene path).
- **Save Singleton State** (`singleton_name: String, key: String`) - Snapshots an autoload addon (Currency Ledger, Upgrades, Prestige...) by its autoload name.
- **Load Singleton State** (`singleton_name: String, key: String`) - Restores an autoload addon's snapshot from the key.

#### Expressions
- **Load Value** (`key: String, default_value`) - Reads any value (your default when missing).
- **Load Number** (`key: String`) - Reads a number (0 when missing).
- **Load Text** (`key: String`) - Reads a string ("" when missing).
- **Read All** - Reads the whole active slot as one Dictionary (every saved key and value).
- **List Save Keys** - The keys stored in the active slot (loop them to read a whole save).
- **Read Save File** (`path: String, file_format: String`) - Reads ANY save file at a path in the given format (config/json/binary/csv/ini/xml; blank = the active format) and returns its Dictionary.
- **Save File Format** (`path: String`) - Detects the format of the save file at the path (config/json/binary/csv/ini/xml), or "" when it is missing or unrecognised. Feed it to Read Save File.
- **List Slots** - Slot numbers that have save files (for menus).
- **Slot Modified Time** (`slot_index: int`) - Unix mtime of the slot's file (0 when missing).

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
- **Confirm Purchase** (`skin_id: String`) - Completes a purchase and grants the skin (fires On Skin Unlocked with method "purchase
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
- **Slide Direction** - The direction of the current or last slide ("left" / "right" / "up" / "down
- **Tile X** - The character's current column on the grid.
- **Tile Y** - The character's current row on the grid.

### SpringBehavior (`res://eventsheet_addons/spring/spring_behavior.gd`)
@ace_tags(motion, juice) @ace_category("Spring") @ace_expose_all(node) @ace_version(1.0.0)

#### Triggers
- **On Spring Reached** (`spring_name: String`)

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

#### Conditions
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
- **On State Changed** (`previous: String, next: String`)

#### Conditions
- **Is In State** (`state_name: String`) - True while the machine is in the given state.

#### Actions
- **Set State** (`next: String`) - Switches to the given state and fires On State Changed.

### StoryletsAddon (`res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd`)
@ace_tags(narrative, storylet) @ace_category("Storylets") @ace_version(1.3.0)

#### Triggers
- **On Storylet Drawn**

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
- **Add Requirement** (`id: String, quality_key: String, op: String, value`) - A rule this storylet needs to be eligible, e.g. quality "courage" >= 3. A missing quality counts as 0 (or "
- **Add Choice** (`id: String, choice_id: String, text: String`) - Adds a labelled choice the player can pick on this storylet (resolve it with Choose).
- **Add Choice Requirement** (`id: String, choice_id: String, quality_key: String, op: String, value`) - A rule that must pass for this choice to be OFFERED, e.g. quality "gold" >= 10. Choices whose rules fail are hidden. Add the choice first with Add Choice.
- **Add Choice Effect** (`id: String, choice_id: String, op: String, key: String, value`) - A quality change applied automatically when this choice is picked - so a choice carries its own consequence instead of a per-choice branch. Add the choice first with Add Choice.
- **Add Effect** (`id: String, op: String, key: String, value`) - A quality change applied automatically when this storylet is DRAWN - so a beat carries its own consequence. Define the storylet first.
- **Add Meta** (`id: String, key: String, value`) - Attaches an arbitrary key-value to a storylet (a speaker, a portrait, a sound). Read it back with Active Meta / Storylet Meta - the engine never interprets it.
- **Add Requirement (Key vs Key)** (`id: String, quality_key: String, op: String, other_key: String`) - A rule comparing one quality against ANOTHER quality's value, e.g. gold >= price - so a storylet reacts to a relationship between stats without hard-coding the number.
- **Add Chance Requirement** (`id: String, percent: float`) - A probability gate: the storylet is eligible only percent% of the time, re-rolled on every Evaluate/Draw. Use it to make a beat show only sometimes.
- **Add Recency Requirement** (`id: String, mode: String, within: int`) - An anti-repeat (or must-be-recent) gate by DRAW history: eligible only when this storylet was / was not among the last N drawn storylets.
- **Set Quality** (`key: String, value`) - Stores a quality value (a number like courage=3, or text like location="tavern
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

#### Conditions
- **Is Busy**

#### Actions
- **Enqueue Item** (`item`) - Adds one item to the work queue (processed later within the per-frame budget).
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

#### Conditions
- **Has Plan**
- **Current Task Is** (`task_name: String`)

#### Actions
- **Set World State** (`key: String, value`) - Writes a fact - preconditions and scorer inputs read it.
- **Clear World State** (`key: String`) - Removes a world-state key.
- **Add Primitive Task** (`task_name: String`) - Registers a leaf task your sheet executes directly.
- **Add Compound Task** (`task_name: String`) - Registers a task that decomposes via methods.
- **Add Method** (`task_name: String, method_id: String, utility: float`) - Adds (or re-scores) a way to accomplish a compound task; the best-ranked applicable method wins.
- **Add Method Condition** (`task_name: String, method_id: String, key: String, op: String, value`) - A precondition (world-state key, operator, value) the method needs to be chosen.
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

#### Conditions
- **Is Maxed** (`id: String`) - Whether an upgrade is at its max level.
- **Owns** (`id: String`) - Whether an upgrade has at least one level.
- **Purchase Succeeded** - Whether the last Try Purchase went through (read it right after, or in On Upgrade Bought).

#### Actions
- **Define Upgrade** (`id: String, base_cost: float, cost_growth: float, max_level: int, per_level: float, mode: String, tag: String`) - Creates (or resets) an upgrade: base cost, cost growth per level, max level (-1 = unlimited), effect per level, mode ("add" or "mult
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
