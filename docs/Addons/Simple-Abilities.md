# Simple Abilities - Cooldowns, Charges, and Tags, One Behavior Per Node

Simple Abilities is a Godot EventSheets behavior pack that gives any node a small ability manager. You attach a `SimpleAbilitiesBehavior` behavior to a host Node - a player, an enemy, a turret, a vehicle - and that node can now hold as many named abilities as you like: a `"dash"`, a `"fireball"`, a `"heal"`, a `"shield"`. Each ability is identified by a string id and carries its own cooldown, its own stack charges that regenerate over time, an optional auto-expire timer, custom key/value data, and any number of tags. You grant abilities, put them on cooldown, spend charges, and query how much time is left, all with plain event-sheet rows. Triggers fire when abilities are created, activated, become ready, gain or spend a stack, or get removed - and because one behavior manages many abilities, the triggers report which ability fired through the Current Ability ID expression. It is a per-node behavior, so there is no manager singleton to route through: every Action, Condition, and Expression targets the abilities on the node you drop it on.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Player skill cooldowns.** A dash, a blink, or a grapple that rests for a fixed time after use, with a clean "ready again" trigger for the HUD.
- **Charge-based abilities.** A double or triple dash where each charge regenerates on its own timer, so the player can burst two in a row then wait.
- **Long-cooldown ultimates.** A big move on a 60-second timer, with Cooldown Progress driving a radial fill and On Ability Ready flashing the icon.
- **Temporary power-ups.** A pickup grants a `"rapid_fire"` ability that auto-removes after 8 seconds, firing On Ability Removed to clean up the effect.
- **Cooldown-reduction stats.** A haste buff sets the global cooldown multiplier to 0.8 so every future cooldown is 20% shorter, no per-ability math.
- **Reset-on-kill mechanics.** Score a kill and instantly reset the dash cooldown, the classic aggressive-movement reward loop.
- **Spell hotbars.** Several named spells on one caster, each with its own cooldown and charges, read straight into a bar of HUD slots.
- **Silence and disable effects.** A silence disables every ability so activation fails until it lifts, without deleting any of them.
- **Toggle and channeled abilities.** A shield or a stealth that stays "active" until toggled off, tracked with the active flag instead of a loose boolean.
- **Class kits and loadouts.** Tag abilities `"fire"`, `"ice"`, or `"movement"` and enable, disable, or refresh a whole group in one row.
- **Roguelite ability grants.** Level up or pick a card to grant a new ability by id, and drop abilities you no longer have.
- **Limited-use items.** A potion belt with three charges that refills at a shop, using stacks as the count and On Max Stacks Reached for a "full" cue.

---

## Core concepts

The model is small. Learn these seven ideas and the rest is just calling the right row.

**An ability is a named slot on the node.** Everything is keyed by a string id you pick - `"dash"`, `"fireball"`, `"potion"`. One `SimpleAbilitiesBehavior` holds a whole dictionary of them, so a single player node can own every skill it has. You grant one with **Create Ability** (or one of the richer create actions), and remove it with **Remove Ability**. Passing an id that was never created is a safe no-op for most actions, so a typo fails quietly rather than crashing - if an ability never seems to work, check the id spelling first.

**Cooldown is a rest timer.** **Set Ability Cooldown** puts an ability on cooldown for N seconds; while it is counting down the ability is not ready. **Reset Cooldown** sets it straight to 0 (instantly ready). The create-with-cooldown actions bake a cooldown into the ability so activating it automatically starts the rest.

**Stacks are charges that refill.** An ability can hold several charges (max stacks). Activating spends one charge; when charges are below the max, a cooldown timer runs and hands back one charge at a time. That is how "two dashes, then wait for each to come back" works with zero extra wiring. **Create Ability With Cooldown And Stacks** sets this up; **Add Stacks**, **Set Stacks**, and **Consume Ability Stack** adjust the count by hand.

**Activate is the "use it" verb.** **Activate Ability** only succeeds if the ability is enabled and has at least one charge. On success it spends a charge, starts the regen cooldown if needed, and fires On Stack Consumed then On Ability Activated. If it is not ready, the call does nothing - so you can call it freely and let it self-gate, or guard it with the **Is Ability Ready** condition for feedback.

**Temporary abilities auto-expire.** **Create Temporary Ability** grants an ability that removes itself after N seconds (calling it again refreshes the timer). **Remove Ability After Duration** schedules that expiry on an ability you already have. When the timer runs out the ability is deleted and On Ability Removed fires.

**Tags group abilities for bulk work.** **Add Tag** labels an ability - `"fire"`, `"movement"`, `"consumable"`. Then one row can act on every ability carrying a tag: **Set Abilities With Tag Enabled**, **Remove All Abilities With Tag**, **Reset Cooldown For Abilities With Tag**. You can also count and list abilities by tag for a loadout screen.

**Triggers fire for any ability - read which one.** There is one On Ability Activated, one On Ability Ready, and so on, shared by every ability on the node. To tell which ability set off the trigger, read the **Current Ability ID** expression, or gate the reaction with the **Current Ability Is** condition. Enabled versus active is a related distinction worth pinning down: **enabled** means the ability is allowed to activate (a silence disables it); **active** is a free flag you set yourself for toggle or channeled abilities (a shield that is currently up).

---

## Setup

**1. Attach the behavior.** Add a `SimpleAbilitiesBehavior` behavior as a child of the node that should own the abilities - your player, an enemy, a vehicle (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The behavior acts on its parent, and any Node works as the host. Each node that needs its own abilities gets its own behavior.

**2. Optional Inspector knob.** Select the behavior node and set the one property if you want a global cooldown scale:

| Property | Default | What it does |
|---|---|---|
| `cooldown_multiplier` | `1.0` | Multiplies every future Set Ability Cooldown. `0.8` = 20% shorter cooldowns; `1.5` = 50% longer. Also settable at runtime with Set Cooldown Multiplier. |

**3. Grant, use, react.** Three moves: create your abilities on ready, activate them on input, and react in the triggers. Here is a complete first ability - a dash with a 2-second cooldown:

```
On Ready
  -> Player | Simple Abilities: Create Ability With Cooldown  "dash", 2.0, true

On "dash" key pressed
  Condition: Player | Simple Abilities  Is Ability Ready  "dash"
    -> Player | Simple Abilities: Activate Ability  "dash"

On Ability Activated
  Condition: Player | Simple Abilities  Current Ability Is  "dash"
    -> Player: apply dash velocity

On Ability Ready
  Condition: Player | Simple Abilities  Current Ability Is  "dash"
    -> HUD: flash the dash icon
```

`reset_instantly` true means the dash starts ready. Activating spends its single charge and starts the 2-second cooldown; when the timer ends the charge comes back and On Ability Ready fires. The Current Ability Is guards make sure each reaction only runs for its own ability, since the triggers are shared across everything on the node.

---

## ACE reference

All ACEs live in the **Abilities** category and target the `SimpleAbilitiesBehavior` on the node they are placed on. Almost every one takes an ability `id` string as its first parameter; the tag actions take a `tag` instead.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Create Ability | `id` (String) | Grants an empty ability (no cooldown, 1 charge, enabled). Fires On Ability Created if it is new. |
| Create Ability With Cooldown | `id` (String), `seconds` (float), `reset_instantly` (bool) | Grants an ability and sets its cooldown. `reset_instantly` true starts it ready; false starts it on cooldown. |
| Create Ability With Cooldown And Stacks | `id` (String), `seconds` (float), `max_stacks` (int), `reset_instantly` (bool) | Grants a charge-based ability where each charge regenerates over `seconds`. `reset_instantly` true starts full; false starts empty. |
| Create Temporary Ability | `id` (String), `seconds` (float) | Grants an ability that auto-removes after `seconds`. Calling it again refreshes the timer. |
| Remove Ability After Duration | `id` (String), `seconds` (float) | Schedules removal of an existing ability after `seconds`. |
| Remove Ability | `id` (String) | Deletes an ability and all its data. Fires On Ability Removed. |
| Clear All Abilities | (none) | Removes every ability. Fires On Ability Removed for each. |
| Activate Ability | `id` (String) | Activates the ability if it is ready (enabled and has a charge): spends a charge, starts regen, fires On Stack Consumed then On Ability Activated. Does nothing if not ready. |
| Set Ability Cooldown | `id` (String), `seconds` (float) | Puts an ability on cooldown (scaled by the global cooldown multiplier). |
| Reset Cooldown | `id` (String) | Sets an ability's cooldown to 0 (instantly ready). |
| Set Max Stacks | `id` (String), `max_stacks` (int) | Changes the maximum charges; current charges clamp down to fit. |
| Set Stacks | `id` (String), `stacks` (int) | Sets the current charges (clamped 0 to max). |
| Add Stacks | `id` (String), `count` (int) | Adds charges up to the max. Fires On Stack Gained, and On Max Stacks Reached if it would overflow. |
| Consume Ability Stack | `id` (String) | Removes one charge without activating; starts regen if needed. Fires On Stack Consumed. |
| Set Ability Enabled | `id` (String), `enabled` (bool) | Enables or disables activation (a disabled ability cannot be activated). |
| Set Ability Active | `id` (String), `active` (bool) | Sets the active flag, for channeled or toggle abilities. |
| Set Ability Data | `id` (String), `key` (String), `value` (String) | Stores a custom string key/value on an ability. |
| Add Tag | `id` (String), `tag` (String) | Tags an ability (safe if it already has the tag). |
| Remove Tag | `id` (String), `tag` (String) | Removes a tag from an ability. |
| Clear All Tags | `id` (String) | Removes every tag from an ability. |
| Set Abilities With Tag Enabled | `tag` (String), `enabled` (bool) | Enables or disables every ability carrying a tag. |
| Remove All Abilities With Tag | `tag` (String) | Deletes every ability with a tag. Fires On Ability Removed for each. |
| Reset Cooldown For Abilities With Tag | `tag` (String) | Sets cooldown to 0 for every ability with a tag. |
| Set Cooldown Multiplier | `multiplier` (float) | Global cooldown scaling for all future Set Ability Cooldown calls (0.8 = 20% reduction). |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Ability | `id` (String) | Whether an ability with this id exists on the node. |
| Is Ability Ready | `id` (String) | Whether the ability is enabled and has at least one charge. |
| Is Ability Active | `id` (String) | Whether the ability's active flag is set. |
| Is Ability Enabled | `id` (String) | Whether the ability is enabled. |
| Has Stacks Available | `id` (String) | Whether the ability has at least one charge. |
| Ability Has Tag | `id` (String), `tag` (String) | Whether the ability carries a tag. |
| Current Ability Is | `id` (String) | Whether the ability that last fired a trigger is this one. Use it inside trigger events. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Ability ID | (none) | String | The id of the ability that last fired a trigger (empty if none). |
| Cooldown Remaining | `id` (String) | float | Seconds left on the ability's cooldown (0 if ready). |
| Cooldown Progress | `id` (String) | float | Fraction of the cooldown still remaining, 0 to 1 (1 just started, 0 ready). |
| Stacks | `id` (String) | int | Current charges on the ability. |
| Max Stacks | `id` (String) | int | Maximum charges the ability can hold. |
| Stack Cooldown Remaining | `id` (String) | float | Seconds until the next charge regenerates. |
| Stack Progress | `id` (String) | float | Regen progress toward the next charge, 0 to 1. |
| Expiration Time | `id` (String) | float | Seconds left before a temporary ability auto-removes (0 if not temporary). |
| Expiration Progress | `id` (String) | float | How far through its lifetime a temporary ability is, 0 (fresh) to 1 (about to expire). |
| Max Expiration Time | `id` (String) | float | The full lifetime a temporary ability was granted. |
| Ability Count | (none) | int | How many abilities exist on the node. |
| List Active Abilities | (none) | String | A comma-separated list of every ability id on the node. |
| Ready Abilities | (none) | String | A comma-separated list of the ids that are currently ready. |
| Ability Data | `id` (String), `key` (String) | String | The stored value for a key on an ability (empty if unset). |
| Count Abilities By Tag | `tag` (String) | int | How many abilities carry a tag. |
| Ability By Tag Index | `tag` (String), `index` (int) | String | The id of the tagged ability at a position (empty past the end). |
| List Abilities By Tag | `tag` (String) | String | A comma-separated list of the ids carrying a tag. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Ability Created | A new ability is granted by one of the create actions. |
| On Ability Activated | Activate Ability succeeds on a ready ability. |
| On Ability Ready | A charge regenerates and the ability becomes usable again. |
| On Stack Consumed | A charge is spent (by Activate Ability or Consume Ability Stack). |
| On Stack Gained | A charge is added or regenerated. |
| On Max Stacks Reached | Adding stacks would push an ability past its max. |
| On Ability Removed | An ability is deleted (Remove Ability, Clear All Abilities, a tag removal, or an expiry). |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `cooldown_multiplier` | float | `1.0` | 0 - 10 |

---

## Use cases

Each example targets the `SimpleAbilitiesBehavior` on the named node. Create abilities in `On Ready`, activate them on input or a stimulus, and react in the trigger events. Guard trigger reactions with Current Ability Is so each one only runs for its own ability.

### 1. Dash on a cooldown

The staple movement skill: instant on the first press, then a short rest before it comes back.

```
On Ready
  -> Player | Simple Abilities: Create Ability With Cooldown  "dash", 2.0, true

On "dash" pressed
  -> Player | Simple Abilities: Activate Ability  "dash"

On Ability Activated
  Condition: Player | Simple Abilities  Current Ability Is  "dash"
    -> Player: apply dash impulse
```

Activate Ability self-gates - it does nothing while the dash is cooling down, so no explicit ready check is needed here.

### 2. Multi-charge dash

Two dashes back to back, then wait as each charge refills on its own timer.

```
On Ready
  -> Player | Simple Abilities: Create Ability With Cooldown And Stacks  "dash", 3.0, 2, true

On "dash" pressed
  -> Player | Simple Abilities: Activate Ability  "dash"

On Stack Gained
  Condition: Player | Simple Abilities  Current Ability Is  "dash"
    -> HUD: light up one dash pip
```

`max_stacks` 2 with `reset_instantly` true starts the player with both charges. Each activation spends one and a 3-second regen hands it back.

### 3. Long-cooldown ultimate with a HUD sweep

A powerful ultimate on a 60-second timer, with a radial fill and a "ready" flash.

```
On Ready
  -> Player | Simple Abilities: Create Ability With Cooldown  "ultimate", 60.0, false

On "ultimate" pressed
  Condition: Player | Simple Abilities  Is Ability Ready  "ultimate"
    -> Player | Simple Abilities: Activate Ability  "ultimate"
    -> Player: unleash ultimate

Every tick
  -> UltIcon: set radial fill to Player | Simple Abilities  Cooldown Progress  "ultimate"

On Ability Ready
  Condition: Player | Simple Abilities  Current Ability Is  "ultimate"
    -> UltIcon: play "ready" glow
```

`reset_instantly` false means the ultimate starts on cooldown at the match open. Cooldown Progress runs 1 down to 0, perfect for a draining radial.

### 4. Temporary power-up pickup

Grabbing a pickup grants rapid fire for 8 seconds, then it removes itself.

```
On Player picks up "rapid_fire" crate
  -> Player | Simple Abilities: Create Temporary Ability  "rapid_fire", 8.0
  -> Player: halve weapon fire interval

On Ability Removed
  Condition: Player | Simple Abilities  Current Ability Is  "rapid_fire"
    -> Player: restore normal fire interval
```

Grabbing a second crate before the first expires refreshes the 8-second timer instead of stacking.

### 5. Cooldown-reduction buff

A haste rune shortens every cooldown while it is active, using the global multiplier.

```
On Haste rune activated
  -> Player | Simple Abilities: Set Cooldown Multiplier  0.7

On Haste rune expired
  -> Player | Simple Abilities: Set Cooldown Multiplier  1.0
```

The multiplier applies to future Set Ability Cooldown calls, so it shapes cooldowns started after the buff turns on.

### 6. Reset the dash on a kill

Reward aggressive play by refunding the dash cooldown whenever the player scores a kill.

```
On Enemy killed by Player
  -> Player | Simple Abilities: Reset Cooldown  "dash"

On Ability Ready
  Condition: Player | Simple Abilities  Current Ability Is  "dash"
    -> HUD: flash "dash refreshed"
```

Reset Cooldown drops the timer to 0 instantly, so the dash is usable again the same frame.

### 7. Spell hotbar HUD

Read charges and cooldown straight into a bar of slots so the player always sees what is ready.

```
Every tick
  -> Slot1_Count: set text to Player | Simple Abilities  Stacks  "fireball"
  -> Slot1_Sweep: set fill to Player | Simple Abilities  Cooldown Progress  "fireball"
  -> Slot2_Count: set text to Player | Simple Abilities  Stacks  "frostbolt"
  -> Slot2_Sweep: set fill to Player | Simple Abilities  Cooldown Progress  "frostbolt"
```

One behavior holds every spell, so the whole hotbar reads from the same node with different ids.

### 8. Silence disables everything

A silence debuff blocks all activation without deleting any ability, then lifts cleanly.

```
On Player silenced
  -> Player | Simple Abilities: Set Ability Enabled  "fireball", false
  -> Player | Simple Abilities: Set Ability Enabled  "dash", false

On Silence expired
  -> Player | Simple Abilities: Set Ability Enabled  "fireball", true
  -> Player | Simple Abilities: Set Ability Enabled  "dash", true
```

While disabled, Is Ability Ready returns false and Activate Ability does nothing, so charges and cooldowns keep their state and resume when the silence ends.

### 9. Toggle a shield with the active flag

A shield that stays up until toggled off, tracked by the active flag rather than a loose variable.

```
On "shield" pressed
  Condition: Player | Simple Abilities  Is Ability Active  "shield"
    -> Player | Simple Abilities: Set Ability Active  "shield", false
    -> Shield sprite: hide
  Else
    -> Player | Simple Abilities: Set Ability Active  "shield", true
    -> Shield sprite: show
```

Create the `"shield"` ability once on ready with Create Ability; the active flag carries the on/off state.

### 10. Class kit via tags

Tag a mage's spells and disable the whole school during an anti-magic phase in one row.

```
On Ready
  -> Player | Simple Abilities: Create Ability With Cooldown  "fireball", 1.5, true
  -> Player | Simple Abilities: Create Ability With Cooldown  "meteor", 12.0, false
  -> Player | Simple Abilities: Add Tag  "fireball", "fire"
  -> Player | Simple Abilities: Add Tag  "meteor", "fire"

On Anti-magic zone entered
  -> Player | Simple Abilities: Set Abilities With Tag Enabled  "fire", false

On Anti-magic zone exited
  -> Player | Simple Abilities: Set Abilities With Tag Enabled  "fire", true
```

One tag row touches every fire spell, so adding a third fire spell later needs no change to the zone logic.

### 11. Refresh-all cooldown pickup

A cooldown-reset shrine clears the timers on a whole group of abilities at once.

```
On Player touches reset shrine
  -> Player | Simple Abilities: Add Tag  "dash", "resettable"
  -> Player | Simple Abilities: Reset Cooldown For Abilities With Tag  "resettable"
  -> Shrine: play consumed animation
```

Tag whichever abilities the shrine should refresh, then one Reset Cooldown For Abilities With Tag row makes them all ready.

### 12. Potion belt with limited charges

Three potions that deplete as they are used and refill to full at a shop, with a "full" cue.

```
On Ready
  -> Player | Simple Abilities: Create Ability  "potion"
  -> Player | Simple Abilities: Set Max Stacks  "potion", 3
  -> Player | Simple Abilities: Set Stacks  "potion", 3

On "drink potion" pressed
  Condition: Player | Simple Abilities  Has Stacks Available  "potion"
    -> Player | Simple Abilities: Consume Ability Stack  "potion"
    -> Player: heal 40

On Player buys refill
  -> Player | Simple Abilities: Add Stacks  "potion", 3

On Max Stacks Reached
  Condition: Player | Simple Abilities  Current Ability Is  "potion"
    -> HUD: show "belt full"
```

Consume Ability Stack spends a potion without the activate flow; Add Stacks past the cap fires On Max Stacks Reached for the full-belt message.

### 13. Store ability metadata

Keep an ability's damage and element on the ability itself, then read it back when it fires.

```
On Ready
  -> Player | Simple Abilities: Create Ability With Cooldown  "fireball", 1.5, true
  -> Player | Simple Abilities: Set Ability Data  "fireball", "damage", "35"
  -> Player | Simple Abilities: Set Ability Data  "fireball", "element", "fire"

On Ability Activated
  Condition: Player | Simple Abilities  Current Ability Is  "fireball"
    -> Spawn projectile with damage = Player | Simple Abilities  Ability Data  "fireball", "damage"
    -> Spawn projectile with element = Player | Simple Abilities  Ability Data  "fireball", "element"
```

Data values are strings, so convert to a number where the receiving side expects one.

### 14. Loadout screen listing abilities by tag

Build an equipped-skills panel by counting and walking the abilities under a tag.

```
On Loadout screen opened
  -> Set loop count to Player | Simple Abilities  Count Abilities By Tag  "equipped"
  For each index i
    -> SlotLabel[i]: set text to Player | Simple Abilities  Ability By Tag Index  "equipped", i

On Debug key pressed
  -> Console: print Player | Simple Abilities  List Abilities By Tag  "equipped"
```

Count Abilities By Tag gives the loop bound and Ability By Tag Index reads each id by position; List Abilities By Tag returns the whole comma-separated set at once.

---

## Tips and common mistakes

- **The node is the manager - abilities are keyed by id.** Every ability lives on the `SimpleAbilitiesBehavior` of the node you dropped it on, identified by the string id you pass. There is no separate manager singleton and no owner argument; the node is the owner, and the id picks the ability.
- **Spell the id the same way everywhere.** `"dash"` and `"Dash"` are two different abilities. Most actions silently do nothing when handed an unknown id, so a mismatched string fails quietly - if an ability never responds, compare the id in Create against the id in Activate and the conditions.
- **Create before you use.** Grant abilities in On Ready (or at spawn) before any Activate, condition, or expression touches them. Activating or querying an ability that was never created just returns the empty defaults and makes debugging harder.
- **Triggers are shared - gate them with Current Ability Is.** One On Ability Activated fires for every ability on the node. Read Current Ability ID or add a Current Ability Is condition so each reaction only runs for its own ability, otherwise the dash logic will also run when the fireball fires.
- **Activate self-gates; the ready check is for feedback.** Activate Ability already does nothing when an ability is on cooldown or disabled, so you can call it on every press. Add an Is Ability Ready condition only when you want to branch - for example to play an "on cooldown" buzzer on the failed press.
- **Enabled and active are different things.** Enabled controls whether an ability can activate at all (a silence disables it). Active is a free flag you set yourself for toggles and channels (a shield that is currently up). Disabling an ability does not clear its active flag, and setting active does not make a disabled ability usable.
- **Cooldown Progress counts down, not up.** It returns the fraction of the cooldown still remaining - 1 the instant it starts, 0 when ready - which suits a draining radial directly. If you want a filling bar instead, drive it from 1 minus the value.
- **The multiplier applies to Set Ability Cooldown, not retroactively.** Changing the cooldown multiplier scales cooldowns that start after the change. An ability already resting keeps the timer it was given; the new scale kicks in the next time it goes on cooldown.
- **Temporary abilities refresh, they do not stack.** Calling Create Temporary Ability again on the same id resets the expiry timer rather than adding a second copy. If you want a longer duration from re-pickup, that refresh is the behavior you get; there is only ever one ability per id.
- **Tag actions act on whatever currently carries the tag.** Set Abilities With Tag Enabled, Remove All Abilities With Tag, and Reset Cooldown For Abilities With Tag hit every ability tagged at call time. Tag your abilities right after creating them so a later bulk row does not miss one.
