# Health - Damage, Death, and Layered Shields, One Behavior Per Node

Health is a Godot EventSheets behavior pack that gives any node a real health model without writing a single line of GDScript. You attach a `SimpleHealthBehavior` behavior to a node - a player, an enemy, a destructible crate, a boss - and that node becomes the thing that can be hurt, healed, and killed. There is no "entity id" to pass around: every Action, Condition, Expression, and Trigger targets the behavior living on the node you drop it on. The host must be a `Node2D` (or anything descended from it, like `Sprite2D`, `Area2D`, or `CharacterBody2D`). Out of the box you get current health that seeds to a max on ready, a death latch, a damage-resistance multiplier, and named **health pools** (shields and armour) that intercept damage in priority order, spend at their own rate, decay over time, and fire their own triggers. Everything lives in the **Health** category and reads the behavior on the node it is placed on.

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

- **Player and enemy health.** Drop the behavior on any actor and it has current health, a max, a death state, and clean triggers to react to - no bespoke health script per enemy type.
- **Destructibles.** Crates, barrels, doors, and turrets all take damage and fire On Death the same way; set Destroy On Death and the host cleans itself up.
- **Regenerating shields.** A named shield pool soaks hits first, then decays back to zero over a few seconds so it feels like a recharging barrier, all with On Health Pool Depleted to cue the break.
- **Layered armour and shields.** Stack multiple pools with different priorities so a shield absorbs before armour before real HP, each with its own toughness.
- **Damage resistance and vulnerability.** A single absorption rate turns any actor into a tank (half damage), a glass cannon (double damage), or briefly untouchable (zero), without touching the damage numbers.
- **Invulnerability windows.** Flip Set Invulnerable on for a moment after a hit for classic post-damage i-frames, then off again on a timer.
- **Overshields and temporary buffs.** Grant a decaying bonus pool from a pickup that fades on its own and fires a trigger when it runs out.
- **Floating damage numbers and hit feedback.** Read Last Damage right inside On Damaged to spawn the exact number that just landed, and Last Pool Damage Absorbed to show what a shield ate.
- **Health bars and HUDs.** Current Health, Max Health, and Health Percent feed a bar or a text readout every frame with zero math on your side.
- **Boss phase scaling.** Raise Max Health, swap resistance, or clear shields between phases to reshape a fight without a health state machine.
- **Respawns and revives.** Revive clears the death latch and restores health in one call, firing On Revived for your respawn effects.
- **Execute and instant-kill hazards.** Set Health to 0 to kill outright (spikes, pits, finishers) with all the normal death triggers firing.

---

## Core concepts

The model is small. Learn these six ideas and every ACE in the pack is just a lever on them.

**Current health seeds to max on ready.** The behavior has a `max_health` you set in the Inspector, and when the node is ready its current health starts equal to that max. From then on, Take Damage lowers it, Heal raises it (never above max), and the Current Health / Max Health / Health Percent expressions report it. You never track a health variable yourself - the behavior is the source of truth.

**Death is a latch.** When health reaches 0, On Death fires and the behavior marks itself dead. While dead, Take Damage, Heal, and Set Health are all no-ops - a corpse cannot be hurt or healed. The only way back is Revive, which clears the latch and fires On Revived. The Is Dead condition tells you the current state. If Destroy On Death is on, the host node is queue_free'd right after On Death.

**Absorption rate is whole-body resistance.** Set Health Absorption Rate is a multiplier on damage that reaches real HP: `1` is normal, `0.5` is a tank taking half, `2` is a glass cannon taking double, and `0` makes the actor invulnerable (it also flips the invulnerable flag on). This scales the damage that gets through after any shields have taken their cut. It is separate from Set Invulnerable, which is a hard on/off no-op switch.

**Health pools are named shields and armour.** A health pool is a bucket of extra points, referenced by a string type you choose (`"shield"`, `"armour"`, `"barrier"`, anything). When the actor takes damage, its pools absorb first, in ascending **priority** order - lower priority number soaks first - and only what is left over reaches real HP. You create and tune pools with Add Health Pool, Setup Health Pool, and the various Set Health Pool ... actions. Add Health Pool alone is enough to get a working shield; the rest fine-tune it.

**Each pool has three dials: priority, absorption rate, and decay rate.** *Priority* decides the order pools soak damage (lower first). *Absorption rate* is how hard the pool spends to eat damage: at `1` one point of pool soaks one point of damage; higher than `1` spends the pool faster (a weaker shield per point); lower than `1` stretches it further (a tougher shield per point). *Decay rate* drains the pool by that many points per second on its own, which is how you build a shield that fades - when it hits zero, On Health Pool Depleted fires.

**"Last" values snapshot the most recent event.** Right after a trigger fires, the Last Damage, Last Heal, Last Pool Damage Absorbed, and Last Health Pool Type expressions hold the numbers from that exact event. Read them inside the matching trigger (Last Damage inside On Damaged, Last Health Pool Type inside On Health Pool Absorbed or On Health Pool Depleted) to drive feedback that matches what just happened.

---

## Setup

**1. Attach the behavior.** Add a `SimpleHealthBehavior` behavior as a child node of your actor (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The parent it attaches to must be a `Node2D` or a descendant of one. One behavior per actor - each enemy, each crate gets its own.

**2. Set the Inspector knobs.** Select the behavior node and set the starting values:

| Property | Default | What it does |
|---|---|---|
| `max_health` | `100` | Starting max HP. Current health seeds to this when the node is ready. Range 1 - 10000. |
| `invulnerable` | `false` | Start invulnerable. While on, Take Damage is a no-op. |
| `destroy_on_death` | `false` | queue_free the host the moment health reaches 0, right after On Death fires. |

**3. Wire the basics.** Damage on contact, react to death, show the number. Here is a complete first setup - an enemy that takes hits, dies, and shows how much each hit dealt:

```
On Player Attack Hits Enemy
  -> Enemy | Health: Take Damage  25

On Enemy | Health: On Damaged
  -> spawn damage number  Enemy.Health.Last Damage
  -> Enemy: flash white

On Enemy | Health: On Death
  -> Enemy: play death animation
  -> add 100 to score
```

Take Damage lowers current health by 25. If it survives, On Damaged fires and Last Damage holds `25` for the number popup. If that hit brought it to 0, On Death fires instead and the enemy dies. Turn on Destroy On Death in the Inspector and you can drop the queue_free entirely.

---

## ACE reference

All ACEs live in the **Health** category and target the `SimpleHealthBehavior` behavior on the node they are placed on. There is no entity-id parameter anywhere. Health pools are addressed by a `type` string you pick.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Take Damage | `amount` (float) | Applies damage. Health pools absorb in ascending-priority order first, then the remainder hits real HP through the absorption rate. No-op while dead or invulnerable. |
| Heal | `amount` (float) | Restores health up to max_health. No-op while dead. |
| Set Health | `amount` (float) | Sets current health directly, firing On Damaged / On Healed / On Death as appropriate. No-op while dead. |
| Set Max Health | `amount` (float) | Sets max health (minimum 1) and clamps current health down if it now exceeds the new max. |
| Set Invulnerable | `state` (bool) | Toggles invulnerability. While true, Take Damage does nothing. |
| Set Health Absorption Rate | `rate` (float) | Sets the damage multiplier for real HP (resistance). `0.5` = half damage, `2` = double, `0` = invulnerable. |
| Add Health Pool | `type` (String), `amount` (float) | Adds points to a named health pool (shield / armour), creating it if needed. Fires On Health Pool Added. |
| Set Health Pool | `type` (String), `amount` (float) | Sets a pool's amount directly. Fires On Health Pool Added only when the new amount is higher than before. |
| Clear Health Pool | `type` (String) | Zeroes one named health pool. |
| Clear All Health Pools | (none) | Zeroes every health pool at once. |
| Set Health Pool Decay Rate | `type` (String), `rate` (float) | Sets a pool's per-second decay rate (points drained each second). |
| Set Health Pool Absorption Rate | `type` (String), `rate` (float) | Sets a pool's absorption multiplier - how hard it spends to soak damage (1 = one point per point). |
| Set Health Pool Rates | `type` (String), `decay_rate` (float), `absorption_rate` (float) | Sets a pool's decay and absorption rates in one call. |
| Set Health Pool Priority | `type` (String), `priority` (float) | Sets a pool's absorption priority. Lower priority soaks damage first. |
| Setup Health Pool | `type` (String), `amount` (float), `decay_rate` (float), `absorption_rate` (float), `priority` (float) | Creates or reconfigures a pool with all its dials in one call. |
| Revive | `amount` (float) | Clears the death latch and restores health. `amount` at or below 0 revives to full max health. Fires On Revived. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Dead | (none) | Whether the actor has died (health reached 0 and not yet revived). |
| Is Invulnerable | (none) | Whether the invulnerable flag is currently on. |
| Has Any Health Pool | (none) | Whether any health pool currently holds points above zero. |
| Has Health Pool | `type` (String) | Whether the named pool exists and holds points above zero. |
| Health Pool Is Type | `type` (String) | Whether the pool involved in the most recent pool event matches this type. Use it inside a pool trigger to branch by which pool fired. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Health | (none) | float | Current health right now. |
| Max Health | (none) | float | The current maximum health. |
| Health Percent | (none) | float | Current health as a percentage of max (0 - 100). |
| Health Absorption Rate | (none) | float | The current whole-body damage multiplier. |
| Last Damage | (none) | float | The real-HP damage dealt by the most recent damaging event. Read it inside On Damaged. |
| Last Heal | (none) | float | The amount restored by the most recent heal. Read it inside On Healed. |
| Health Pool | `type` (String) | float | The current amount in the named pool (0 if it does not exist). |
| Health Pool Decay Rate | `type` (String) | float | The named pool's per-second decay rate (0 if it does not exist). |
| Health Pool Absorption Rate | `type` (String) | float | The named pool's absorption multiplier (1 if it does not exist). |
| Health Pool Priority | `type` (String) | float | The named pool's absorption priority (0 if it does not exist). |
| Last Pool Damage Absorbed | (none) | float | How much damage the pool soaked in the most recent absorb event. Read it inside On Health Pool Absorbed. |
| Last Health Pool Type | (none) | String | The type of the pool involved in the most recent pool event. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Damaged | The actor loses real HP but survives (from Take Damage or a Set Health that lowers it). |
| On Death | Health reaches 0. If Destroy On Death is on, the host is freed right after. |
| On Healed | Health is restored (from Heal, a Set Health that raises it, or Revive). |
| On Health Changed | Any change to current health, whatever the cause. Good for redrawing a health bar. |
| On Revived | Revive brings the actor back from death. |
| On Health Pool Added | A pool gains points (Add Health Pool, or a Set Health Pool that increases it). |
| On Health Pool Absorbed | A pool soaks part of an incoming hit. Last Pool Damage Absorbed and Last Health Pool Type hold the details. |
| On Health Pool Depleted | A pool drops to 0, from absorbing a hit or from decay. |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `max_health` | float | `100` | 1 - 10000 |
| `invulnerable` | bool | `false` | on / off |
| `destroy_on_death` | bool | `false` | on / off |

---

## Use cases

Each example targets the `SimpleHealthBehavior` behavior on the named node. Set the Inspector `max_health` for the actor, then use these rows to drive the model and react to its triggers.

### 1. Basic enemy that takes damage and dies

The bread and butter: a hit deals damage, and death cues your effects. Turn on Destroy On Death in the Inspector and the enemy removes itself.

```
On Bullet Hits Enemy
  -> Enemy | Health: Take Damage  20

On Enemy | Health: On Death
  -> Enemy: play explosion
  -> add score
```

### 2. Live health bar HUD

Redraw a bar every time health moves. On Health Changed catches every source at once, and Health Percent hands you a ready 0 - 100 value.

```
On Player | Health: On Health Changed
  -> set HealthBar.value  Player.Health.Health Percent
  -> set HealthLabel.text  str(Player.Health.Current Health) + " / " + str(Player.Health.Max Health)
```

### 3. Floating damage numbers

Read Last Damage inside On Damaged to spawn the exact number that just landed. It holds the real-HP damage after any shields took their cut.

```
On Enemy | Health: On Damaged
  -> spawn DamageNumber at Enemy.global_position  Enemy.Health.Last Damage
```

### 4. Healing pickup

A health potion tops the player up, capped at max automatically. On Healed drives the heal sparkle.

```
On Player Touches Potion
  -> Player | Health: Heal  40
  -> Potion: queue_free

On Player | Health: On Healed
  -> Player: play heal sparkle  Player.Health.Last Heal
```

### 5. Post-hit invulnerability window

Give the player brief i-frames after a hit so a single spike does not chunk them repeatedly. Flip invulnerable on, wait, flip it off.

```
On Player | Health: On Damaged
  -> Player | Health: Set Invulnerable  true
  -> Player: start flashing
  -> Wait 1.0 seconds
  -> Player | Health: Set Invulnerable  false
  -> Player: stop flashing
```

### 6. Damage resistance buff

A "stone skin" powerup halves incoming damage for its duration. Absorption rate scales all real-HP damage; set it back to 1 when the buff ends.

```
On Player Uses Stone Skin
  -> Player | Health: Set Health Absorption Rate  0.5

On Stone Skin Expires
  -> Player | Health: Set Health Absorption Rate  1
```

Set it to `2` instead for a vulnerability debuff, or `0` for a short cinematic-untouchable moment.

### 7. A regenerating shield that soaks then recharges

Grant a shield pool that absorbs hits and drop it if broken, then rebuild it after a quiet spell. Setup Health Pool wires the amount and rates in one call.

```
On Ready
  -> Player | Health: Setup Health Pool  "shield", 50, 0, 1, 0

On Player | Health: On Health Pool Depleted
  Condition: Player | Health  Health Pool Is Type  "shield"
    -> Player: play shield break
    -> Wait 4.0 seconds
    -> Player | Health: Set Health Pool  "shield", 50
    -> Player: play shield recharge
```

Priority 0 means the shield soaks before real HP. On Health Pool Depleted with Health Pool Is Type "shield" catches the exact moment it breaks.

### 8. Layered shield over armour over HP

Two pools with different priorities absorb in order: shield first (priority 0), then armour (priority 1), then whatever is left hits health. The armour spends more per point, so it is tougher but drains slower.

```
On Ready
  -> Enemy | Health: Setup Health Pool  "shield", 30, 0, 1, 0
  -> Enemy | Health: Setup Health Pool  "armour", 40, 0, 0.5, 1

On Player Hits Enemy
  -> Enemy | Health: Take Damage  35
```

The shield (priority 0) eats first; overflow hits the armour (priority 1), whose 0.5 absorption rate stretches its 40 points across 80 damage; only then does real HP take a hit.

### 9. Decaying overshield from a pickup

A power-up grants a bonus shield that fades on its own. A decay rate drains it every second, and On Health Pool Depleted fires when it runs dry.

```
On Player Grabs Overshield
  -> Player | Health: Add Health Pool  "overshield", 60
  -> Player | Health: Set Health Pool Decay Rate  "overshield", 10

On Player | Health: On Health Pool Depleted
  Condition: Player | Health  Health Pool Is Type  "overshield"
    -> Player: play overshield fizzle
```

At decay rate 10, the 60-point overshield lasts about six seconds if nothing hits it first.

### 10. Shield-hit feedback

Flash the shield and show what it ate whenever it absorbs a hit. On Health Pool Absorbed hands you both the amount and the pool type.

```
On Enemy | Health: On Health Pool Absorbed
  -> spawn ShieldSpark at Enemy.global_position  Enemy.Health.Last Pool Damage Absorbed
  -> HUD: show "Absorbed by " + Enemy.Health.Last Health Pool Type
```

### 11. Instant-kill hazard

A pit or a finisher kills outright, no matter the health total. Set Health to 0 runs the full death path, firing On Death.

```
On Player Falls In Pit
  -> Player | Health: Set Health  0

On Player | Health: On Death
  -> reload checkpoint
```

### 12. Respawn with a revive

Bring the player back from death and restore health in one move. Revive with 0 or less refills to full max; pass a number to revive at partial health.

```
On Respawn Timer Ends
  -> Player | Health: Revive  0
  -> Player: move to spawn point

On Player | Health: On Revived
  -> Player: play respawn effect
```

### 13. Boss phase-two health scaling

At half health, a boss enrages: raise its max, top it back up, and drop its resistance so the fight speeds up. Set Max Health lifts the ceiling; Heal fills the new room.

```
On Boss | Health: On Damaged
  Condition: Boss.Health.Health Percent  <  50
  Condition: [not already enraged]
    -> Boss | Health: Set Max Health  400
    -> Boss | Health: Heal  400
    -> Boss | Health: Set Health Absorption Rate  1.5
    -> Boss: play enrage roar
```

### 14. Low-health warning and cleansing shields on death

Warn the player as they get critical, and strip any lingering shields when they finally fall so nothing survives them. Health Percent gates the warning; Clear All Health Pools tidies up on death.

```
On Player | Health: On Health Changed
  Condition: Player.Health.Health Percent  <  25
    -> HUD: show low-health vignette
  Condition: Player.Health.Health Percent  >=  25
    -> HUD: hide low-health vignette

On Player | Health: On Death
  -> Player | Health: Clear All Health Pools
  -> Player: play death
```

### 15. Timed armour buff you can inspect

Grant armour, and later check whether it is still up before deciding to refresh it. Has Health Pool tells you if a pool still holds points; the Health Pool expression reads the exact amount.

```
On Player Casts Iron Guard
  -> Player | Health: Add Health Pool  "armour", 50

On Refresh Check (every 2 seconds)
  Condition: Player | Health  Has Health Pool  "armour"
    -> HUD: show "Armour: " + str(Player.Health.Health Pool  "armour")
  Condition: [else] not Has Health Pool  "armour"
    -> HUD: show "Armour down"
```

### Other use cases

**Training dummy with a DPS meter.** A practice dummy takes hits normally but calls Revive the moment On Death fires, while every On Damaged adds Last Damage into a running total, giving players a damage-per-second readout that never runs out of target.

**Poison and burn ticks.** A status effect applies a small Take Damage on a repeating timer, so damage-over-time reuses the exact same pipeline as direct hits - shields soak it, resistance scales it, and On Death fires if it finishes the job.

**Vampiric lifesteal.** When the player's attack lands, read the victim's Last Damage inside its On Damaged and Heal the attacker for a fraction of it, turning lifesteal into two rows with no extra bookkeeping.

**Escort and payload missions.** Give the caravan or payload its own behavior; enemies chip at it like any actor, a bar tracks Health Percent, and its On Death is simply the mission-failed trigger.

**Difficulty settings without touching damage numbers.** On easy mode, Set Health Absorption Rate to 0.5 on the player and 1.5 on enemies at scene start - every weapon and hazard keeps its authored values while the whole game gets softer or harsher.

---

## Tips and common mistakes

- **The node is the actor - there is no entity id.** Every Action, Condition, and Expression acts on the `SimpleHealthBehavior` on the node it is placed on. Drop it on the player, drop another on each enemy; each keeps its own health, pools, and death state. There is nothing to pass around.
- **The host must be a Node2D.** The behavior looks for a Node2D parent and warns if it does not find one. Attach it under a Node2D or a descendant (Sprite2D, Area2D, CharacterBody2D, and so on), not under a plain Node or a Control.
- **You do not track a health variable yourself.** Current health seeds to `max_health` on ready and the behavior owns it from there. Read Current Health, Max Health, and Health Percent instead of keeping your own counter that can drift out of sync.
- **Dead is a latch - only Revive undoes it.** While dead, Take Damage, Heal, and Set Health all do nothing. If a "healing" pickup seems to ignore a corpse, that is why. Call Revive to clear the death state before health can move again.
- **Set Invulnerable and Set Health Absorption Rate are different tools.** Set Invulnerable is a hard on/off that makes Take Damage a no-op. Set Health Absorption Rate scales damage (0.5 half, 2 double); a rate of exactly 0 also flips invulnerable on. Use the rate for resistance tuning and the flag for clean i-frame windows.
- **Pools absorb before real HP, lowest priority first.** If a shield is not soaking a hit, check its priority (lower soaks first) and that its amount is above zero. Damage only reaches Current Health after every pool with points has taken its cut.
- **Higher pool absorption rate makes a weaker shield, not a stronger one.** Absorption rate is the pool's cost per point of damage: at `1` a 50-point pool soaks 50 damage; at `2` it soaks only 25; at `0.5` it stretches to 100. Lower the rate to make a pool tougher.
- **Decay drains pools every second on their own.** A pool with a decay rate above zero shrinks whether or not it is hit, and fires On Health Pool Depleted when it empties. That is the mechanism for fading overshields - leave decay at 0 for a permanent shield.
- **Read the "Last" values inside their own trigger.** Last Damage is meaningful inside On Damaged, Last Heal inside On Healed, Last Pool Damage Absorbed and Last Health Pool Type inside the pool triggers. Reading them at an unrelated moment gives you a stale snapshot from the previous event.
- **Set Health Pool only fires On Health Pool Added when it goes up.** Setting a pool to a value at or below its current amount changes the number silently, with no Added trigger. Use it to refill a shield to a cap; do not rely on it to fire when you lower a pool.
