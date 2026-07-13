# StatForge - Stats as a Buff Stack, One Behavior Per Node

StatForge is a Godot EventSheets behavior pack that gives any node real, modifiable stats without a single line of GDScript and without a spreadsheet of hand-tracked variables. You attach a `StatForge` behavior to a node - the player, an enemy, a tower, a vehicle - and every modifier that ever touches that node's numbers becomes a named **buff**: a weapon bonus, a potion, a curse, a stance, a difficulty scale. Each buff targets one stat with one value and one mode (add, multiply, or override), optionally carries tags and a source for bulk operations, and optionally expires on its own after a duration. Reading the computed result is always one expression: Stat Total. The host can be any `Node`, so it works in 2D, 3D, and UI alike. Everything lives in the **StatForge** category and reads the behavior on the node it is placed on.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Stat sheets as data (.tres)](#stat-sheets-as-data-tres)
6. [Scaling the complexity](#scaling-the-complexity)
7. [Use cases](#use-cases)
8. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **RPG character stats.** Strength, speed, defense, crit chance - every equipment slot, blessing, and curse is a buff on the stack, and Stat Total always reports the current truth. No "recalculate stats" function to forget to call.
- **Timed potions and status effects.** A buff with a duration removes itself when time runs out and fires On Buff Expired so you can cue the fizzle. Re-drinking refreshes instead of stacking, if that is what you want.
- **Incremental and idle multipliers.** Prestige bonuses, upgrade tiers, and event multipliers pile up as separate multiply buffs; the pack does the compounding for you.
- **Turn-based games.** Turn off `auto_tick` and drive the clock yourself: Advance Timers 1 at the end of each turn makes "poisoned for 3 turns" exactly three turns, regardless of real time.
- **Threshold reactions.** A rule watches a stat and fires On Threshold Crossed the moment its total crosses a value, rising or falling - combo milestones, low-resource warnings, overheat cutoffs - with one-shot and repeating variants.
- **Designer-authored loadouts.** A `StatSheetResource` is a .tres asset holding a bases table and a buffs table, edited as plain Inspector grids. Load Stat Sheet applies the whole thing in one action: classes, enemy tiers, and difficulty presets become data files, not event rows.
- **Debuffs you can trace and cleanse.** Every buff remembers its source; when the cursing enemy dies, Remove Buffs By Source wipes everything it ever applied in one call.

---

## Core concepts

The model is small. Learn these five ideas and every ACE in the pack is just a lever on them.

**A stat is a base plus a stack of buffs.** Set Stat Base gives a stat its starting number (a stat you never set has base 0). Every modifier after that is a buff added with Add Buff: a unique `buff_id`, the `stat` it targets, a `value`, and a `mode`. The behavior owns all of it - you never keep a "current speed" variable that can drift out of sync.

**Stat Total is the one read.** The computation is `(base + active add buffs) * active multiply buffs` - unless any active **override** buff exists on that stat, in which case the HIGHEST override wins outright and the base, adds, and multipliers are ignored entirely. After that, the `overflow_mode` knob applies: `clamp` stops the result at `min_value` / `max_value`, `wrap` loops it around inside that range, `none` leaves it alone.

**Buff ids are unique per node, and re-adding replaces.** Adding a buff with an id that already exists replaces the old buff completely - new value, new mode, new timer, active again. That makes "picking up the same powerup twice" naturally refresh instead of stack. When you do want stacking, give each application its own id (`"poison_1"`, `"poison_2"`).

**Inactive is not removed.** Set Buff Active turns a buff off without losing it: an inactive buff contributes nothing to Stat Total but stays in the stack with its value, tags, and timer intact, ready to be switched back on. That is the tool for stances, toggled auras, and suppression zones. Removal (by id, tag, or source) actually deletes the buff and fires On Buff Removed.

**Time is a stream of seconds you control.** A buff with a `duration` above 0 counts down and removes itself when it hits zero, firing On Buff Expired. With `auto_tick` on (the default), the countdown runs on real time every physics frame. With it off, nothing ages until you call Advance Timers with however many seconds a "turn" or a "tick" is worth. Individual buffs can be frozen with Set Buff Timer Paused, and Refresh Buff restarts a countdown from a fresh duration.

**Threshold rules watch totals for you.** Add Threshold Rule registers a watcher on one stat: a boundary `value`, a `direction` (`rising`, `falling`, or `both`), and a `repeating` flag. Whenever a buff or base change (or a timer expiry) moves that stat's total across the boundary, On Threshold Crossed fires. A repeating rule fires on every genuine crossing; a one-shot rule fires once and stays spent until Re-Arm Threshold Rule. The rule seeds itself with the stat's current total when added, so it never fires just for being created.

---

## Setup

**1. Attach the behavior.** Add a `StatForge` behavior as a child node of your actor (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The parent can be any `Node` - a sprite, a body, a Control, even a bare data node. One behavior per actor; each keeps its own bases, buffs, and rules.

**2. Set the Inspector knobs.** Select the behavior node and tune:

| Property | Default | What it does |
|---|---|---|
| `auto_tick` | `true` | Temporary buffs count down automatically every physics frame. Turn off to drive time yourself with Advance Timers (turn-based games advance per turn). |
| `overflow_mode` | `clamp` | What happens when a computed total leaves the min/max range: `clamp` stops at the boundary, `wrap` loops around, `none` applies no limit. |
| `min_value` | `-99999` | The smallest allowed stat total (clamp/wrap modes). |
| `max_value` | `99999` | The largest allowed stat total (clamp/wrap modes). |

**3. Wire the basics.** Give a stat a base, buff it, read it. Here is a complete first setup - a player whose speed has a base and gains a temporary boost from a pickup:

```
On Ready
  -> Player | StatForge: Set Stat Base  "speed", 200

On Player Grabs Boots
  -> Player | StatForge: Add Buff  "boots", "speed", 1.5, "multiply", "", "pickup", 10.0

Every Tick
  -> Player: set move speed  Player.StatForge.Stat Total  "speed"
```

While the boots buff is live, Stat Total("speed") reports 300. Ten seconds later the buff expires by itself, On Buff Expired fires, and the total is 200 again - no cleanup rows, no timers of your own.

---

## ACE reference

All ACEs live in the **StatForge** category and target the `StatForge` behavior on the node they are placed on. Stats, buffs, rules, tags, and sources are all addressed by strings you choose.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Add Buff | `buff_id` (String), `stat` (String), `value` (float), `mode` (add / multiply / override), `tags` (String), `source` (String), `duration` (float) | The one verb that runs the whole system: a named buff targeting a stat. Tags are comma-separated labels for bulk operations, source names who applied it, duration in seconds expires it (0 = permanent). Re-adding an existing id REPLACES that buff. Fires On Buff Added. No-op if the id or stat is empty or the mode is invalid. |
| Remove Buff | `buff_id` (String) | Removes one buff by id (a no-op when absent). Fires On Buff Removed. |
| Remove Buffs By Tag | `tag` (String) | Removes every buff carrying the tag - unequip all "equipment" in one action. Fires On Buff Removed per buff. |
| Remove Buffs By Source | `source` (String) | Removes every buff a source applied - clear one enemy's curses when it dies. Fires On Buff Removed per buff. |
| Clear Buffs | (none) | Empties the whole stack. Bases stay. |
| Set Stat Base | `stat` (String), `value` (float) | Sets a stat's base value - the number the buff math starts from. |
| Set Buff Active | `buff_id` (String), `active` (bool) | Turns one buff on or off WITHOUT removing it - inactive buffs stay in the stack but contribute nothing. |
| Set Buffs Active By Tag | `tag` (String), `active` (bool) | Bulk activation by tag - silence every "aura" buff in an antimagic zone, restore them on exit. |
| Set Buff Value | `buff_id` (String), `value` (float) | Changes a live buff's value in place (a stacking poison that deepens). |
| Refresh Buff | `buff_id` (String), `duration` (float) | Restarts a timed buff's countdown from a fresh duration (re-drinking the potion refreshes, not stacks). No-op if the buff is absent or the duration is 0 or less. |
| Set Buff Timer Paused | `buff_id` (String), `paused` (bool) | Freezes or unfreezes one buff's countdown (cutscenes, pause-adjacent states). |
| Advance Timers | `seconds` (float) | Advances every unpaused timer by the given seconds - the manual clock for turn-based games (turn ends: Advance Timers 1). Expired buffs are removed and fire On Buff Expired. |
| Add Threshold Rule | `rule_id` (String), `stat` (String), `value` (float), `direction` (rising / falling / both), `repeating` (bool) | Watches a stat and fires On Threshold Crossed when its total crosses the value. A repeating rule fires on every crossing; a one-shot stays spent until Re-Arm Threshold Rule. |
| Remove Threshold Rule | `rule_id` (String) | Deletes a rule. |
| Re-Arm Threshold Rule | `rule_id` (String) | Re-arms a spent one-shot rule so it can fire again. |
| Load Stat Sheet | `stat_sheet` (StatSheetResource) | Applies a .tres stat sheet: its bases set stat bases, then its buff rows are added one by one IN ORDER - whole loadouts, classes, and difficulty presets as data. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Buff | `buff_id` (String) | Whether a buff with this id exists in the stack (active or not). |
| Buff Is Active | `buff_id` (String) | Whether the buff exists AND is currently active (contributing to totals). |
| Has Buffs With Tag | `tag` (String) | Whether any buff in the stack carries the tag. |
| Has Buffs From Source | `source` (String) | Whether any buff in the stack was applied by this source. |
| Stat Is At Least | `stat` (String), `value` (float) | The beginner-friendly stat compare: whether Stat Total is greater than or equal to the value. (Stat Total works in any expression too.) |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Stat Total | `stat` (String) | float | The computed value: (base + active adds) * active multipliers, unless an active override exists - then the highest override wins. Overflow applies last. |
| Stat Base | `stat` (String) | float | The stat's base value alone, ignoring every buff (0 if never set). |
| Buff Value | `buff_id` (String) | float | The named buff's raw value (0 if it does not exist). |
| Buff Time Left | `buff_id` (String) | float | Seconds left on a timed buff (-1 = permanent or unknown). |
| Buff Count | (none) | int | How many buffs are in the stack, active or not. |
| Buff Count With Tag | `tag` (String) | int | How many buffs carry the tag, active or not. |
| Last Expired Buff | (none) | String | The buff id that expired most recently - read it inside On Buff Expired. |
| Last Threshold Rule | (none) | String | The rule id that fired most recently - read it inside On Threshold Crossed. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Buff Added | Add Buff lands a buff (including a replacement of an existing id, and every buff row Load Stat Sheet applies). Carries the buff id and stat. |
| On Buff Removed | A buff is deleted by Remove Buff, Remove Buffs By Tag, or Remove Buffs By Source. Carries the buff id and stat. |
| On Buff Expired | A timed buff's countdown reaches zero and it removes itself. Carries the buff id and stat; Last Expired Buff holds the id. |
| On Threshold Crossed | A watched stat's total crosses a rule's boundary in the rule's direction. Carries the rule id, stat, and new total; Last Threshold Rule holds the id. |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `auto_tick` | bool | `true` | on / off |
| `overflow_mode` | String | `clamp` | clamp / wrap / none |
| `min_value` | float | `-99999` | any float |
| `max_value` | float | `99999` | any float |

---

## Stat sheets as data (.tres)

A **StatSheetResource** turns a whole loadout into a data asset a designer can author without ever opening an event sheet. Create one in the FileSystem dock (New Resource > StatSheetResource), save it as `Knight.tres`, `EliteGoblin.tres`, or `Nightmare.tres`, and fill in its three fields in the Inspector:

| Field | What it holds |
|---|---|
| `sheet_name` | A label for your own reference (StatForge does not read it). |
| `bases` | A grid of rows, one per stat: `stat` and `value`. The starting numbers before any buffs (speed 100, hp 50...). |
| `buffs` | A grid of rows, one per buff, applied top to bottom: `buff_id`, `stat`, `value`, `mode` (add / multiply / override), `tags` (comma-separated), `source`, `duration` (seconds, 0 = permanent). |

Both tables edit as plain **Inspector grids** - add a row, type the stat name, type the number. No code, no dialog diving. That makes .tres sheets the natural home for anything a designer iterates on: character classes, enemy tiers, weapon archetypes, difficulty presets. Balancing the Knight means editing `Knight.tres`, not hunting through event rows.

One action applies the whole file:

```
On Ready
  -> Player | StatForge: Load Stat Sheet  Knight.tres
```

The bases are set first, then the buff rows are added in order from top to bottom, each one exactly as if you had called Add Buff yourself - so they fire On Buff Added, respect the replace-by-id rule, and start their timers. Loading a second sheet on top does not wipe the first; call Clear Buffs first if you want a clean slate.

---

## Scaling the complexity

StatForge is deliberately front-loaded onto **two verbs**: Add Buff writes, Stat Total reads. That pair alone runs a complete RPG stat system - bases, equipment bonuses, percentage multipliers, and "set it to exactly X" overrides are all just modes on Add Buff, and every consumer of the number reads one expression. Everything else in the pack is optional depth you pull in only when a real need shows up:

- **RPGs** start with the two verbs, then grow into tags when inventory arrives (`"equipment"` unequips as a group), sources when enemies start cursing (cleanse per caster), and .tres stat sheets when a designer wants to balance classes without touching sheets.
- **Incremental games** start with a base and a pile of multiply buffs, then grow into permanent-vs-timed buffs for event boosts, Advance Timers for offline catch-up, and threshold rules to pop "you can now afford X" prompts.
- **Action games** start with speed and damage stats, then grow into durations for powerups, threshold rules for combo milestones and overheat cutoffs, and Set Buff Active for stances that flip every frame-relevant number at once.

You never pay for the features you are not using: a node with two verbs on it is exactly as simple as a variable, except it already knows how to be buffed.

---

## Use cases

Each example targets the `StatForge` behavior on the named node. Give stats a base first (with Set Stat Base or a stat sheet), then let buffs do the rest.

### 1. The simplest possible setup: two verbs

A stat with a base, one buff, one read. This is the whole system in three rows; everything else in this guide is optional depth.

```
On Ready
  -> Player | StatForge: Set Stat Base  "damage", 10

On Player Equips Sword
  -> Player | StatForge: Add Buff  "sword", "damage", 5, "add", "", "", 0

On Player Attacks
  -> Enemy: take damage  Player.StatForge.Stat Total  "damage"
```

Duration 0 means the sword bonus is permanent until you remove it. The attack row never changes no matter how many buffs pile up later.

### 2. RPG equipment loadout with tags

Every equipped item is a buff tagged `"equipment"`. Unequipping everything - a curse, a prison level, a naked run - is one action instead of a bookkeeping loop.

```
On Player Equips Helm
  -> Player | StatForge: Add Buff  "helm", "defense", 3, "add", "equipment", "inventory", 0

On Player Equips Boots
  -> Player | StatForge: Add Buff  "boots", "speed", 1.2, "multiply", "equipment", "inventory", 0

On Player Is Stripped
  -> Player | StatForge: Remove Buffs By Tag  "equipment"
```

Use the item's slot as the buff id ("helm", "boots") and swapping gear replaces the old piece automatically.

### 3. Timed haste potion that refreshes, not stacks

A potion buffs speed for 8 seconds and announces its own end. Drinking a second potion mid-effect refreshes the timer instead of doubling the boost, because re-adding the same id replaces.

```
On Player Drinks Haste
  -> Player | StatForge: Add Buff  "haste", "speed", 1.5, "multiply", "potion", "potion", 8.0

On Player | StatForge: On Buff Expired
  Condition: Player.StatForge.Last Expired Buff  =  "haste"
    -> Player: play slowdown puff
    -> HUD: hide haste icon
```

If you would rather extend the running timer without touching the value, use Refresh Buff "haste", 8.0 instead of a second Add Buff.

### 4. Enemy curse cleanup by source

A shaman slows the player with a curse. The buff's source names the caster, so when that exact shaman dies, only its curses lift - other enemies' debuffs stay.

```
On Shaman Casts Curse
  -> Player | StatForge: Add Buff  "curse_slow", "speed", 0.6, "multiply", "curse", "shaman_1", 0

On Shaman | Health: On Death
  -> Player | StatForge: Remove Buffs By Source  "shaman_1"
```

Use each enemy's unique name or instance id as the source string so two shamans never cleanse each other's work.

### 5. Turn-based poison with the manual clock

Turn `auto_tick` OFF in the Inspector so nothing ages in real time. At the end of each turn, Advance Timers 1 makes one turn cost exactly one "second" - a 3-turn poison is a buff with duration 3.

```
On Enemy Poisons Hero
  -> Hero | StatForge: Add Buff  "poison", "strength", -4, "add", "dot", "enemy", 3.0

On Turn Ends
  -> Hero | StatForge: Advance Timers  1

On Hero | StatForge: On Buff Expired
  Condition: Hero.StatForge.Last Expired Buff  =  "poison"
    -> HUD: show "The poison wears off."
```

Buff Time Left("poison") now literally reads "turns remaining" for the status panel.

### 6. Incremental-game prestige multiplier stack

Each prestige adds another permanent multiply buff, and the compounding is automatic: three prestiges at 2x each is 8x income, with no math on your side.

```
On Player Prestiges
  -> Game | StatForge: Add Buff  "prestige_" + str(prestige_count), "income", 2.0, "multiply", "prestige", "prestige", 0

Every Tick
  -> add to gold  Game.StatForge.Stat Total  "income" * delta
```

The unique id per prestige ("prestige_1", "prestige_2") is what makes them stack; reusing one id would replace instead. Buff Count With Tag("prestige") doubles as the prestige counter.

### 7. Combo counter with one-shot and repeating thresholds

Track the combo as a stat base and let rules do the watching: a one-shot fires the "first blood" fanfare exactly once per fight, a repeating rule celebrates every time the combo climbs past 10 again.

```
On Fight Starts
  -> Player | StatForge: Set Stat Base  "combo", 0
  -> Player | StatForge: Add Threshold Rule  "first_hit", "combo", 1, "rising", false
  -> Player | StatForge: Add Threshold Rule  "combo_10", "combo", 10, "rising", true

On Player Lands Hit
  -> Player | StatForge: Set Stat Base  "combo", Player.StatForge.Stat Total "combo" + 1

On Player Takes Hit
  -> Player | StatForge: Set Stat Base  "combo", 0

On Player | StatForge: On Threshold Crossed
  Condition: Player.StatForge.Last Threshold Rule  =  "first_hit"
    -> announcer: play "First blood!"
  Condition: Player.StatForge.Last Threshold Rule  =  "combo_10"
    -> Player: flash combo aura
```

The repeating rule re-fires only after the combo genuinely drops below 10 and climbs back - a crossing needs the total to actually pass the boundary, not just sit on it.

### 8. Low-health warning on a falling threshold

Run hp through StatForge and a falling rule at 25 catches the exact moment the player dips into danger - no per-frame compare rows.

```
On Ready
  -> Player | StatForge: Set Stat Base  "hp", 100
  -> Player | StatForge: Add Threshold Rule  "low_hp", "hp", 25, "falling", true

On Player Is Hit
  -> Player | StatForge: Set Stat Base  "hp", Player.StatForge.Stat Total "hp" - 10

On Player | StatForge: On Threshold Crossed
  Condition: Player.StatForge.Last Threshold Rule  =  "low_hp"
    -> HUD: show low-health vignette
    -> heartbeat sound: play
```

Add a second rising rule at the same value to hide the vignette when healing carries the player back out.

### 9. Difficulty presets as .tres stat sheets

Author `Normal.tres` and `Nightmare.tres` as StatSheetResource files - Inspector grids a designer fills without opening a sheet. Nightmare's buffs table might hold `enemy_hp_scale | hp | 1.5 | multiply` and `enemy_dmg_scale | damage | 2.0 | multiply`, all tagged `"difficulty"`.

```
On Enemy Spawns
  -> Enemy | StatForge: Load Stat Sheet  Nightmare.tres

On Difficulty Changed To Normal
  -> Enemy | StatForge: Remove Buffs By Tag  "difficulty"
  -> Enemy | StatForge: Load Stat Sheet  Normal.tres
```

Bases apply first, then the buff rows in table order. Balancing hard mode is now editing a data file, and the same sheet drops onto every enemy type.

### 10. Stance toggle with Set Buff Active

A defensive stance is a pair of buffs added once and switched on and off forever after. Inactive buffs contribute nothing but keep their values, so toggling is instant and lossless.

```
On Ready
  -> Player | StatForge: Add Buff  "stance_def", "defense", 2.0, "multiply", "stance", "", 0
  -> Player | StatForge: Add Buff  "stance_slow", "speed", 0.5, "multiply", "stance", "", 0
  -> Player | StatForge: Set Buffs Active By Tag  "stance", false

On Player Presses Stance Key
  Condition: Player | StatForge  Buff Is Active  "stance_def"
    -> Player | StatForge: Set Buffs Active By Tag  "stance", false
  Condition: [else]
    -> Player | StatForge: Set Buffs Active By Tag  "stance", true
```

Buff Is Active is the stance query for animations and HUD icons; Has Buff would say true either way.

### 11. Pausing timers during cutscenes (edge case)

A speed boost should not silently burn out while the player watches a dialogue scene. Freeze the countdown on the way in, resume on the way out - the buff keeps applying its value the whole time, only the clock stops.

```
On Cutscene Starts
  -> Player | StatForge: Set Buff Timer Paused  "haste", true

On Cutscene Ends
  -> Player | StatForge: Set Buff Timer Paused  "haste", false
```

Pausing is per buff, so a "cursed" debuff can keep ticking through the scene while the good buffs wait. To freeze everything at once, tag your timed buffs and loop, or turn `auto_tick` off and stop calling Advance Timers.

### 12. Buff bar on screen with HUD Kit

Combine with the HUD Kit pack (referenced by display name only): show how many effects are running and count down the potion live.

```
On Player | StatForge: On Buff Added
  -> Player | HUD Kit: Set Text  "BuffCount", "Effects: " + str(Player.StatForge.Buff Count)

Every Tick
  Condition: Player | StatForge  Has Buff  "haste"
    -> Player | HUD Kit: Set Text  "HasteTimer", str(Player.StatForge.Buff Time Left "haste")

On Player | StatForge: On Buff Expired
  -> Player | HUD Kit: Set Text  "BuffCount", "Effects: " + str(Player.StatForge.Buff Count)
```

Buff Time Left returns -1 for permanent buffs, so gate the timer label on values above zero if you mix both kinds.

### 13. A boss enrage that overrides everything

Override mode ignores the base, every add, and every multiplier: the stat simply IS the override value. When several overrides are active at once, the highest one wins - so a 500-speed enrage beats a 300-speed frenzy without you ordering anything.

```
On Boss Reaches Phase Two
  -> Boss | StatForge: Add Buff  "enrage", "speed", 500, "override", "phase", "boss_ai", 0

On Boss Is Stunned
  -> Boss | StatForge: Add Buff  "stun", "speed", 0, "override", "cc", "player", 2.0
```

Careful: while the 500 enrage is active, the 0-speed stun loses the highest-wins contest and does nothing. Set Buff Active "enrage", false for the stun's duration if crowd control must beat enrage.

### 14. A stacking poison that deepens

One poison buff whose value grows with every reapplication, using Set Buff Value to deepen it in place and Refresh Buff to restart the clock - one buff id, escalating pain.

```
On Snake Bites Player
  Condition: Player | StatForge  Has Buff  "venom"
    -> Player | StatForge: Set Buff Value  "venom", Player.StatForge.Buff Value "venom" - 2
    -> Player | StatForge: Refresh Buff  "venom", 5.0
  Condition: [else]
    -> Player | StatForge: Add Buff  "venom", "strength", -2, "add", "dot", "snake", 5.0
```

Each bite adds another -2 to the same buff and resets its 5-second timer. A plain Add Buff on every bite would instead replace it back to -2, which is the refresh-not-stack behavior - pick whichever your design wants.

### 15. Overheat cutoff with a manual re-arm

A one-shot rising rule at 100 heat shuts the weapon down once, and stays spent so cooling back and forth around 100 cannot re-trigger it. Only the explicit cooldown ritual re-arms the rule.

```
On Ready
  -> Weapon | StatForge: Set Stat Base  "heat", 0
  -> Weapon | StatForge: Add Threshold Rule  "overheat", "heat", 100, "rising", false

On Weapon Fires
  -> Weapon | StatForge: Set Stat Base  "heat", Weapon.StatForge.Stat Total "heat" + 8

On Weapon | StatForge: On Threshold Crossed
  Condition: Weapon.StatForge.Last Threshold Rule  =  "overheat"
    -> Weapon: disable firing
    -> Weapon: play steam burst

On Cooldown Complete
  -> Weapon | StatForge: Set Stat Base  "heat", 0
  -> Weapon | StatForge: Re-Arm Threshold Rule  "overheat"
  -> Weapon: enable firing
```

Without the Re-Arm row, the rule fires exactly once per game - a spent one-shot never comes back on its own.

### Other use cases

**Roguelike run modifiers.** Every relic, blessing, and pact picked up during a run is a permanent buff tagged `"run"`; the build's whole identity lives in the stack, Buff Count With Tag feeds the relic counter, and the run reset is a single Clear Buffs followed by loading the character's base .tres sheet.

**Tower defense auras.** A support tower applies a fire-rate multiply buff to each tower in range with itself as the source; when the aura tower is sold or destroyed, Remove Buffs By Source on its neighbours retracts the bonus cleanly, and overlapping auras from different towers stack because each uses its own buff id.

**Racing surface and vehicle tuning.** Mud, ice, and boost pads swap short-duration speed and handling buffs on the car as it drives over them, garage upgrades sit underneath as permanent adds, and each opponent loads a different .tres sheet so the field has personality without per-car event logic.

**Survival meters.** Hunger, warmth, and stamina are stats whose bases the world erodes; eating and campfires add timed buffs, falling thresholds at "peckish" and "starving" fire the warnings and screen effects, and wearing a coat is just Set Buff Active on the insulation buff.

**Idle offline catch-up.** An incremental game with `auto_tick` off runs all production boosts on the manual clock: on load, one Advance Timers call with the seconds since the last session expires exactly the boosts that should have lapsed, firing On Buff Expired for each so the welcome-back summary can list what ran out.

---

## Tips and common mistakes

- **Re-adding an id replaces - it never stacks.** Add Buff with an existing id throws away the old buff entirely: new value, new mode, fresh timer, active again. That is a feature for refreshing potions, and a trap for stacking poisons. When you want N copies, mint N ids ("poison_1", "poison_2") or grow one buff with Set Buff Value.
- **Override ignores everything, and the highest override wins.** One active override buff makes the base, every add, and every multiplier irrelevant for that stat. With several active overrides, the LARGEST value wins - so an override of 0 (a stun) silently loses to an override of 500 (an enrage). Deactivate the bigger one first if the smaller must apply.
- **Inactive is not removed.** A buff switched off with Set Buff Active contributes nothing to Stat Total, but Has Buff still says true, Buff Count and Buff Count With Tag still count it, and its timer keeps running unless paused. Use Buff Is Active when you mean "is it doing anything right now", and Remove Buff when you mean gone.
- **Wrap needs max_value greater than min_value.** In `wrap` mode the total loops inside the min/max range - but only when `max_value > min_value`; otherwise the wrap silently does nothing and the raw result passes through. Also remember the defaults are a huge -99999 to 99999 range, so clamp and wrap both look inert until you tighten the knobs.
- **With auto_tick off, nothing ever expires on its own.** Turning the knob off hands you the clock completely: durations, expiries, and On Buff Expired all wait for Advance Timers. The classic bug is a turn-based game where "3-turn" debuffs last forever because no row calls Advance Timers at end of turn.
- **Thresholds only watch stats that have rules, and only see StatForge changes.** A rule is registered per stat by Add Threshold Rule; stats without rules are not tracked at all. Crossings are detected when buffs, bases, or expiries change a total - a rule added AFTER the stat is already past the boundary will not fire retroactively, because it seeds itself with the current total on creation.
- **Read the "Last" expressions inside their own trigger.** Last Expired Buff is meaningful inside On Buff Expired and Last Threshold Rule inside On Threshold Crossed. Anywhere else they hold a stale id from the previous event. Note that Remove Buff does not set Last Expired Buff - only a real timer expiry does.
- **A multiplier on an empty stat is still zero.** Stats default to base 0, and (0 + no adds) * 1.5 is 0. If a multiply buff seems dead, check that the stat has a base (Set Stat Base or a stat sheet's bases row) or at least one add buff underneath it. Related: Refresh Buff on a permanent buff gives it a countdown - refreshing is "set the timer", not "extend if timed".
