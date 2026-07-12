# UtilityBrain - Scoring-Based AI Decisions, One Brain Per Node

UtilityBrain is a Godot EventSheets behavior pack that replaces brittle if/else state machines with a scoring engine. You attach a `UtilityBrain` behavior to each AI node - an enemy, a companion, an NPC - and that node becomes the agent. There is no "agent id" to pass around: every Action, Condition, Expression, and Trigger targets the brain living on the node you drop it on. You register a handful of candidate **actions** (attack, flee, patrol, idle), give each a few **considerations** (a world-state input mapped through a response curve to a 0-1 score), feed the current world state with **Set Input**, then call **Evaluate**. The highest-scoring action wins and fires triggers your sheet reacts to. Tune the feel with weights, curves, cooldowns, and inertia instead of rewriting event trees. It is a Construct-3-addon port of "UtilityAI", made Godot-native: because the node is the agent, all the agent-id plumbing the original threaded through every call is gone.

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

- **Reactive enemy combat.** One brain weighs attack, retreat, reload, and reposition every beat, and the choice bends to health, distance, and ammo instead of a fixed script.
- **Boss behavior shaping.** Move a boss from predictable scripted phases to score-driven transitions - enrage, slam, summon, and retreat all compete, and priorities shift as the fight escalates.
- **Stealth guards.** Blend patrol, investigate, alert, and chase off a shared alert level, so a guard eases between states instead of snapping between them.
- **Companion support.** A follower picks heal, buff, protect, or hold based on the party's state - it revives the downed ally when it matters, not on a timer.
- **Survival creatures.** Wildlife rebalances forage, flee, drink, and shelter from local hunger and danger signals, so instincts read as instincts.
- **Ambient open-world life.** Villagers score wander, rest, socialize, and work from time of day and mood, filling a town without a scheduler.
- **RTS or tactics units.** Each unit continuously scores hold, pursue, flank, and regroup from cover and pressure values, no per-unit state graph.
- **Roguelite and horde AI.** Enemies shift between chase, kite, flank, and disengage from health and cooldown availability so a crowd never all does the same thing.
- **Encounter pacing.** Alternate offense, downtime, and repositioning with weighted-random selection so repeated fights avoid a robotic loop.
- **Creature taming and pets.** A tamed companion picks offense, defense, support, or regroup from bond, stamina, and owner distance.
- **Naval or vehicle AI.** Ships weigh broadside, ram, evade, and retreat from hull integrity and angle advantage.
- **Adaptive directors.** A hidden brain scores when to spawn a wave, drop a pickup, or stay quiet from how hard the player is struggling.

---

## Core concepts

The mental model is small and it composes. Learn these six ideas and the rest of the pack is just plumbing.

**Actions are candidate behaviors.** You register the things the AI *could* do - `"attack"`, `"flee"`, `"patrol"`, `"idle"` - with **Add Action**. An action carries a cooldown, an interruptible flag, and a priority (an overall weight multiplier, 1 = normal). Registering an action does not run it; it just enters the pool the brain chooses from.

**Considerations turn world state into a score.** A consideration reads one world-state input (a number you push in, normally 0-1 like a health ratio) and maps it through a **response curve** to a 0-1 score. You add them with **Add Consideration**. "Flee harder as health drops" is one consideration: input `hp`, curve `inverse`. An action's final score is the **product** of all its considerations, so any single factor near zero **vetoes** the whole action - that is how "never flee at full health" falls out naturally without an if statement.

**The named response curves** shape how an input maps to a score. Pick one in the **Add Consideration** `curve` dropdown:

- `linear` - score follows the input straight up (0 to 1).
- `inverse` - score falls as the input rises (1 to 0). "More urgent when the value is low", e.g. low health.
- `quadratic` - like linear but slow at first, then sharp - rewards high inputs.
- `inverse_quadratic` - high at first, then falls off sharply - rewards low inputs.
- `logistic` - an S-curve. A soft threshold: below the `center` it stays low, above it it rises fast. `slope` sets the steepness.
- `threshold` - a hard gate: 1 at or above the `center`, 0 below it. Use it as an on/off veto.
- `bell` - peaks at the `center` and falls off on both sides; `slope` sets the width. "Best at medium range", "ideal when health is around half".

`center` and `slope` only matter for `logistic`, `threshold`, and `bell`; the other four ignore them.

**Weight sharpens or softens a factor.** The `weight` on a consideration raises the score to that power: `> 1` makes the factor decisive (sharper), `< 1` makes it a gentle nudge (softer), `1` leaves it as-is.

**Priority scales the whole action.** The `priority` on **Add Action** multiplies the final score, so a priority-2 action beats a priority-1 action at equal considerations. Use it to say "all else equal, prefer this."

**Inertia stops flip-flopping.** When two actions score near-tied, a brain re-evaluating each frame can jitter between them. The `inertia_bonus` Inspector knob adds a small bump to the action already running so it wins the tie and stays put. Important: inertia only nudges an action that is *already viable* (already scoring at or above `min_score`); it never rescues an action its own considerations have vetoed below the threshold.

**Cooldowns gate availability.** An action's cooldown (set on **Add Action**, or started with **Set Action Cooldown**) rests it for N seconds after **Mark Action Complete**. While cooling down it is skipped in scoring - that is how you stop a special attack from spamming.

**Two selection modes.** The `selection_mode` Inspector knob decides how the winner is picked. `highest` always takes the top score - predictable and readable. `weighted_random` samples among the top few actions (how many is `weighted_top_n`) in proportion to their scores - varied and less robotic, great for ambient behavior.

**The consideration-less fallback.** An action with *no* considerations scores a flat `fallback_score` (times its priority). That is deliberately low, so it only wins when nothing else clears the bar. Registering an `"idle"` action with zero considerations **is** the keep-a-fallback best practice - there is nothing else to wire. If even that does not clear `min_score` (or you never registered one), **On No Valid Action** fires instead.

---

## Setup

**1. Attach the brain.** Add a `UtilityBrain` behavior as a child node of your AI node (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). One brain per agent - each enemy gets its own.

**2. Set the Inspector knobs.** Select the brain node and tune the feel:

| Property | Default | What it does |
|---|---|---|
| `selection_mode` | `highest` | `highest` always takes the top score (predictable); `weighted_random` samples among the top few by score (varied). |
| `weighted_top_n` | `3` | Weighted-random only: how many of the highest-scoring actions to sample from. |
| `inertia_bonus` | `0.1` | Bonus added to the running action so the brain does not flip-flop between near-tied choices (0 = off). |
| `min_score` | `0.05` | Actions scoring below this are ignored; if nothing clears it, On No Valid Action fires. |
| `fallback_score` | `0.1` | The score given to an action with no considerations - a natural low fallback. |
| `score_compensation` | `true` | Smooths many-consideration actions so multiplying lots of 0-1 factors does not unfairly deflate them. |
| `history_length` | `5` | How many past actions to remember (for the Action History expression and anti-repeat logic). |

**3. Wire the golden loop.** Four moves: register on ready, feed inputs on a timer, evaluate, react to the triggers. Here is a complete first brain - an enemy that flees when hurt and idles otherwise:

```
On Ready
  -> Enemy | UtilityBrain: Add Action  "idle", 0, true, 1
  -> Enemy | UtilityBrain: Add Action  "flee", 0, true, 1
  -> Enemy | UtilityBrain: Add Consideration  "flee", "hp", "inverse", 1, 0.5, 1

Every 0.25 seconds
  -> Enemy | UtilityBrain: Set Input  "hp", Enemy.hp / Enemy.max_hp
  -> Enemy | UtilityBrain: Evaluate

On Action Started
  Condition: Enemy | UtilityBrain  Is Running  "flee"
    -> Enemy: play "run" animation
  Condition: Enemy | UtilityBrain  Is Running  "idle"
    -> Enemy: play "idle" animation
```

`"idle"` has no considerations, so it scores the flat fallback and only wins when `"flee"` is quiet (high health means `inverse` of `hp` is near zero, which vetoes fleeing). Push the input right before Evaluate; register everything before you ever Evaluate.

---

## ACE reference

All ACEs live in the **Utility AI** category and target the `UtilityBrain` behavior on the node they are placed on. There is no agent-id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Add Action | `action_name` (String), `cooldown` (float), `interruptible` (bool), `priority` (float) | Registers a candidate action the brain can choose. `cooldown` = seconds it rests after Mark Action Complete (0 = none); `interruptible` = whether Interrupt Action can cancel it; `priority` = an overall weight multiplier (1 = normal). |
| Add Consideration | `action_name` (String), `input_key` (String), `curve` (String), `weight` (float), `curve_center` (float), `curve_slope` (float) | Adds a scoring factor to an action: reads a world-state input (0-1) and maps it through a response curve to a 0-1 score. An action's considerations all multiply, so any near-zero factor vetoes it. `weight` sharpens (>1) or softens (<1) this factor; `curve_center` + `curve_slope` tune the logistic / threshold / bell curves. |
| Remove Action | `action_name` (String) | Removes an action (and any cooldown on it). Clears the current action if it was the one running. |
| Set Action Enabled | `action_name` (String), `enabled` (bool) | Enables or disables an action without removing it (a disabled action is never chosen). |
| Set Input | `key` (String), `value` (float) | Writes a world-state value considerations read by key (usually normalized 0-1, e.g. hp_ratio). Push these right before Evaluate; an unset key reads as 0. |
| Clear Inputs | (none) | Clears all world-state inputs on this brain. |
| Evaluate | (none) | Scores every enabled, off-cooldown action from the current world state and picks a winner. Fires On Decision Made (plus On Action Changed + On Action Started when the choice changes), or On No Valid Action if nothing clears the minimum score. Call it on a timer or after a stimulus. |
| Force Action | `action_name` (String) | Overrides the decision and starts an action directly (fires On Decision Made + On Action Started). Use it for cutscenes, scripted beats, or an emergency fallback, then return to Evaluate. |
| Mark Action Complete | (none) | Marks the running action finished: fires On Action Completed, starts its cooldown if it has one, then re-evaluates. Call it when your gameplay finishes performing the action (it already re-evaluates, so do not also call Evaluate). |
| Interrupt Action | (none) | Stops the running action if it is interruptible (fires On Action Interrupted) and re-evaluates. A non-interruptible action is left alone. |
| Set Action Cooldown | `action_name` (String), `seconds` (float) | Starts (or, with seconds <= 0, clears) a cooldown on an action, so it cannot be chosen until the timer expires. Fires On Cooldown Started. |
| Clear Cooldowns | (none) | Clears every active cooldown on this brain (e.g. a refresh powerup). |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Running | `action_name` (String) | Whether the brain's current action is this one. |
| Has Action | `action_name` (String) | Whether an action is registered on this brain. |
| Is Action Enabled | `action_name` (String) | Whether an action is registered and enabled. |
| Is On Cooldown | `action_name` (String) | Whether an action is currently cooling down. |
| Was Last Action | `action_name` (String) | Whether the previous action (before the current one) was this one - for anti-repeat / transition logic. |
| Is Idle | (none) | Whether the brain has no current action (nothing chosen yet, or the last evaluation found none valid). |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Action | (none) | String | The id of the action running now ("" if none). |
| Previous Action | (none) | String | The id of the action that ran before the current one. |
| Decision Score | (none) | float | The winning action's score from the most recent Evaluate. |
| Action Score | `action_name` (String) | float | An action's score from the most recent Evaluate (0 if it was not scored). |
| Action History | `index` (int) | String | A past action by index, most-recent first (0 = current). "" past the end. |
| Action Count | (none) | int | How many actions are registered on this brain. |
| Cooldown Remaining | `action_name` (String) | float | Seconds left on an action's cooldown (0 if not cooling down). |
| Cooldown Action | (none) | String | The action whose cooldown just started or ended (inside On Cooldown Started / On Cooldown Ended). |
| Get Input | `key` (String) | float | The current value of a world-state input (0 if unset). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Decision Made | Every Evaluate that selects a winner (fires even if the winner is unchanged). |
| On Action Started | A new action begins (on change, or when Force Action starts one). |
| On Action Changed | The chosen action differs from what was running. |
| On Action Completed | Mark Action Complete is called. |
| On Action Interrupted | Interrupt Action cancels an interruptible action. |
| On Cooldown Started | A cooldown begins (Mark Action Complete on a cooldown action, or Set Action Cooldown). |
| On Cooldown Ended | An action's cooldown timer expires. |
| On No Valid Action | Evaluate finds nothing that clears the minimum score. |

### Response curves

Choose one in the `curve` parameter of Add Consideration:

| Curve | Shape | Use it for |
|---|---|---|
| `linear` | score rises with the input | "more of X, more score" |
| `inverse` | score falls as the input rises | urgency when a value is low (low health, low ammo) |
| `quadratic` | slow then sharp rise | strongly reward high inputs |
| `inverse_quadratic` | sharp then slow fall | strongly reward low inputs |
| `logistic` | soft S-curve threshold around `center` | "kick in past this point", steepness via `slope` |
| `threshold` | hard on/off gate at `center` | a binary veto (1 above, 0 below) |
| `bell` | peaks at `center`, falls off both sides | "best at medium", width via `slope` |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `selection_mode` | String | `highest` | `highest` or `weighted_random` |
| `weighted_top_n` | int | `3` | 1 - 10 |
| `inertia_bonus` | float | `0.1` | 0.0 - 1.0 |
| `min_score` | float | `0.05` | 0.0 - 1.0 |
| `fallback_score` | float | `0.1` | 0.0 - 1.0 |
| `score_compensation` | bool | `true` | on / off |
| `history_length` | int | `5` | 1 - 32 |

---

## Use cases

Each example targets the `UtilityBrain` behavior on the named node. Register in `On Ready`, feed inputs and Evaluate on a timer or after a stimulus, and react in the trigger events.

### 1. Patrol vs attack by proximity

An enemy patrols until the player gets close, then attacks. One input, two actions, opposite curves.

```
On Ready
  -> Enemy | UtilityBrain: Add Action  "patrol", 0, true, 1
  -> Enemy | UtilityBrain: Add Action  "attack", 0, true, 1
  -> Enemy | UtilityBrain: Add Consideration  "patrol", "proximity", "inverse", 1, 0.5, 1
  -> Enemy | UtilityBrain: Add Consideration  "attack", "proximity", "logistic", 1, 0.6, 1

Every 0.25 seconds
  -> Enemy | UtilityBrain: Set Input  "proximity", clamp(1.0 - Enemy.global_position.distance_to(Player.global_position) / 600.0, 0, 1)
  -> Enemy | UtilityBrain: Evaluate

On Action Started
  Condition: Enemy | UtilityBrain  Is Running  "attack"
    -> Enemy: start attack
```

### 2. Shooter with reload pressure

A soldier keeps firing until ammo runs low, then reload wins. The `inverse` curve on ammo makes reload urgent only when the magazine is near empty.

```
On Ready
  -> Soldier | UtilityBrain: Add Action  "fire", 0, true, 1
  -> Soldier | UtilityBrain: Add Action  "reload", 0, false, 1
  -> Soldier | UtilityBrain: Add Consideration  "fire", "ammo", "logistic", 1, 0.2, 1
  -> Soldier | UtilityBrain: Add Consideration  "reload", "ammo", "inverse", 2, 0.5, 1

Every 0.2 seconds
  -> Soldier | UtilityBrain: Set Input  "ammo", Soldier.ammo / Soldier.mag_size
  -> Soldier | UtilityBrain: Evaluate

On Action Started
  Condition: Soldier | UtilityBrain  Is Running  "reload"
    -> Soldier: play reload animation
```

Reload is registered non-interruptible so a stun cannot cancel a reload mid-swap.

### 3. Boss emergency retreat

A boss fights normally but bails when health goes critical. A high `weight` on the health consideration makes the drop decisive, and `priority` 2 lets retreat outscore its attacks at equal footing.

```
On Ready
  -> Boss | UtilityBrain: Add Action  "attack", 0, true, 1
  -> Boss | UtilityBrain: Add Action  "retreat", 0, true, 2
  -> Boss | UtilityBrain: Add Consideration  "retreat", "hp", "inverse", 3, 0.5, 1

On Damaged
  -> Boss | UtilityBrain: Set Input  "hp", Boss.hp / Boss.max_hp
  -> Boss | UtilityBrain: Evaluate

On Action Changed
  Condition: Boss | UtilityBrain  Is Running  "retreat"
    -> Boss: dash to cover
```

Evaluating on the `On Damaged` stimulus means the boss reacts the instant it is hurt, not on the next timer tick.

### 4. Stealth guard investigates a noise

A guard patrols, but a heard sound spikes an investigate score. Set the `heard` input to 1 on the sound stimulus and let it decay back to 0 over time (or clear it after investigating).

```
On Ready
  -> Guard | UtilityBrain: Add Action  "patrol", 0, true, 1
  -> Guard | UtilityBrain: Add Action  "investigate", 0, true, 1
  -> Guard | UtilityBrain: Add Consideration  "patrol", "heard", "inverse", 1, 0.5, 1
  -> Guard | UtilityBrain: Add Consideration  "investigate", "heard", "threshold", 1, 0.5, 1

On Noise Heard
  -> Guard | UtilityBrain: Set Input  "heard", 1
  -> Guard | UtilityBrain: Evaluate

On Action Started
  Condition: Guard | UtilityBrain  Is Running  "investigate"
    -> Guard: move toward last noise position
```

The `threshold` curve gates investigate on: it only becomes a candidate once `heard` reaches its `center`.

### 5. Cooldown-gated special attack

A `"slam"` special is powerful, so it gets a cooldown. After the gameplay finishes it, Mark Action Complete starts the rest timer automatically - the slam cannot be chosen again until it expires.

```
On Ready
  -> Enemy | UtilityBrain: Add Action  "melee", 0, true, 1
  -> Enemy | UtilityBrain: Add Action  "slam", 5, true, 1
  -> Enemy | UtilityBrain: Add Consideration  "slam", "proximity", "logistic", 1, 0.7, 1

On Action Started
  Condition: Enemy | UtilityBrain  Is Running  "slam"
    -> Enemy: play slam windup
    -> Enemy: deal area damage
    -> Enemy | UtilityBrain: Mark Action Complete

On Cooldown Ended
  -> Enemy: flash "ready" icon
```

The `Add Action  "slam", 5, ...` sets the 5-second cooldown; `On Cooldown Ended` is a clean hook for a HUD "ready" cue.

### 6. Interrupt on stun

A stun cancels whatever the enemy is doing (if that action allows it) and forces an immediate re-evaluation. Interrupt Action respects the interruptible flag, so a non-interruptible cast is left to finish.

```
On Stunned
  -> Enemy | UtilityBrain: Interrupt Action
  -> Enemy: play stagger animation

On Action Interrupted
  -> Enemy: cancel current attack hitbox
```

### 7. Force a scripted action

During a cutscene or scripted beat, override the brain entirely and play a specific pose, then hand control back to Evaluate when the scene ends.

```
On Cutscene Start
  -> Boss | UtilityBrain: Force Action  "intro_roar"

On Cutscene End
  -> Boss | UtilityBrain: Evaluate
```

Force Action still fires On Decision Made and On Action Started, so your normal `Is Running` reactions light up.

### 8. Fall back to idle when nothing qualifies

Two safety nets. Register a consideration-less `"idle"` so it always scores the flat fallback and wins quiet moments; and catch On No Valid Action for the case where even idle is disabled or missing.

```
On Ready
  -> NPC | UtilityBrain: Add Action  "idle", 0, true, 1
  -> NPC | UtilityBrain: Add Action  "work", 0, true, 1
  -> NPC | UtilityBrain: Add Consideration  "work", "has_task", "threshold", 1, 0.5, 1

On No Valid Action
  -> NPC | UtilityBrain: Force Action  "idle"
```

With `"idle"` registered, the brain rarely reaches On No Valid Action at all - the fallback score covers the gap.

### 9. Weighted-random variety

For ambient enemies that should not all pick the same thing, set `selection_mode` to `weighted_random` and `weighted_top_n` to 3 in the Inspector. Each Evaluate samples among the top three by score, so a crowd spreads out naturally.

```
On Ready
  -> Enemy | UtilityBrain: Add Action  "circle", 0, true, 1
  -> Enemy | UtilityBrain: Add Action  "approach", 0, true, 1
  -> Enemy | UtilityBrain: Add Action  "feint", 0, true, 1
  -> Enemy | UtilityBrain: Add Consideration  "circle", "proximity", "bell", 1, 0.5, 0.3
  -> Enemy | UtilityBrain: Add Consideration  "approach", "proximity", "inverse", 1, 0.5, 1
  -> Enemy | UtilityBrain: Add Consideration  "feint", "proximity", "logistic", 1, 0.6, 1

Every 0.4 seconds
  -> Enemy | UtilityBrain: Set Input  "proximity", clamp(1.0 - Enemy.global_position.distance_to(Player.global_position) / 500.0, 0, 1)
  -> Enemy | UtilityBrain: Evaluate
```

The `bell` curve on circle makes it favored at medium range; weighted-random keeps three nearby enemies from mirroring each other.

### 10. Anti-repeat with Action History and Was Last Action

Stop a guard from patrolling twice in a row. Read the history and push a `boredom` input that shifts the score away from the just-done action, and use Was Last Action for transition-specific reactions.

```
Every 0.5 seconds
  Condition: Guard | UtilityBrain  Is Running  "patrol"
  Condition: [Expression] Guard | UtilityBrain  Action History  1  ==  "patrol"
    -> Guard | UtilityBrain: Set Input  "boredom", 1
  -> Guard | UtilityBrain: Evaluate

On Action Changed
  Condition: Guard | UtilityBrain  Was Last Action  "flee"
    Condition: Guard | UtilityBrain  Is Running  "attack"
      -> Guard: play "rally" animation
```

Add a `boredom` consideration to `"patrol"` with the `inverse` curve so a high boredom input suppresses repeating it. Action History index 0 is the current action, index 1 the one before.

### 11. Companion heal and buff decisions

A companion chooses between healing a hurt ally, buffing, or holding. Multiple considerations multiply, so heal only wins when an ally is actually low *and* the companion has resources.

```
On Ready
  -> Companion | UtilityBrain: Add Action  "hold", 0, true, 1
  -> Companion | UtilityBrain: Add Action  "heal", 3, true, 2
  -> Companion | UtilityBrain: Add Action  "buff", 8, true, 1
  -> Companion | UtilityBrain: Add Consideration  "heal", "ally_hp", "inverse", 2, 0.5, 1
  -> Companion | UtilityBrain: Add Consideration  "heal", "mana", "threshold", 1, 0.3, 1
  -> Companion | UtilityBrain: Add Consideration  "buff", "in_combat", "threshold", 1, 0.5, 1

Every 0.3 seconds
  -> Companion | UtilityBrain: Set Input  "ally_hp", Ally.hp / Ally.max_hp
  -> Companion | UtilityBrain: Set Input  "mana", Companion.mana / Companion.max_mana
  -> Companion | UtilityBrain: Set Input  "in_combat", CombatState.active
  -> Companion | UtilityBrain: Evaluate

On Action Started
  Condition: Companion | UtilityBrain  Is Running  "heal"
    -> Companion: cast heal on Ally
    -> Companion | UtilityBrain: Mark Action Complete
```

Heal's `mana` threshold vetoes it when the companion is dry; the `inverse` on `ally_hp` makes it urgent only for a wounded ally. Priority 2 lets a needed heal outweigh a buff.

### 12. Survival creature balancing hunger, threat, and shelter

A wild animal juggles feed, flee, and seek-shelter. Each action reads a different world signal, and flee's `threshold` on threat makes danger override everything.

```
On Ready
  -> Deer | UtilityBrain: Add Action  "graze", 0, true, 1
  -> Deer | UtilityBrain: Add Action  "flee", 0, true, 2
  -> Deer | UtilityBrain: Add Action  "shelter", 0, true, 1
  -> Deer | UtilityBrain: Add Consideration  "graze", "hunger", "linear", 1, 0.5, 1
  -> Deer | UtilityBrain: Add Consideration  "graze", "threat", "inverse", 2, 0.5, 1
  -> Deer | UtilityBrain: Add Consideration  "flee", "threat", "threshold", 1, 0.5, 1
  -> Deer | UtilityBrain: Add Consideration  "shelter", "is_night", "threshold", 1, 0.5, 1

Every 0.3 seconds
  -> Deer | UtilityBrain: Set Input  "hunger", Deer.hunger
  -> Deer | UtilityBrain: Set Input  "threat", DangerField.at(Deer.global_position)
  -> Deer | UtilityBrain: Set Input  "is_night", DayNight.is_night
  -> Deer | UtilityBrain: Evaluate

On Action Started
  Condition: Deer | UtilityBrain  Is Running  "flee"
    -> Deer: sprint away from threat
```

Graze wants food but its `inverse` threat consideration vetoes it near danger; flee's `threshold` on threat fires the moment danger crosses the line; priority 2 keeps survival ahead of eating.

### 13. Ambient town life on a schedule

Villagers pick wander, rest, socialize, or work from time of day and energy, using weighted-random so a plaza does not move in lockstep.

```
On Ready
  -> Villager | UtilityBrain: Add Action  "wander", 0, true, 1
  -> Villager | UtilityBrain: Add Action  "rest", 0, true, 1
  -> Villager | UtilityBrain: Add Action  "socialize", 0, true, 1
  -> Villager | UtilityBrain: Add Consideration  "rest", "energy", "inverse", 1, 0.5, 1
  -> Villager | UtilityBrain: Add Consideration  "socialize", "crowd", "logistic", 1, 0.5, 1
  -> Villager | UtilityBrain: Add Consideration  "wander", "energy", "linear", 1, 0.5, 1

Every 1.0 seconds
  -> Villager | UtilityBrain: Set Input  "energy", Villager.energy
  -> Villager | UtilityBrain: Set Input  "crowd", Plaza.nearby_count / 10.0
  -> Villager | UtilityBrain: Evaluate
```

Set `selection_mode` to `weighted_random` in the Inspector so nearby villagers spread across the top choices instead of clumping.

### 14. Boss phase shaping by enabling actions

Rather than a phase state machine, unlock stronger actions as the fight escalates. Set Action Enabled flips a move on at a threshold, and the brain folds it into scoring immediately.

```
On Ready
  -> Boss | UtilityBrain: Add Action  "swipe", 0, true, 1
  -> Boss | UtilityBrain: Add Action  "meteor", 12, true, 2
  -> Boss | UtilityBrain: Add Consideration  "meteor", "proximity", "inverse", 1, 0.5, 1
  -> Boss | UtilityBrain: Set Action Enabled  "meteor", false

On Damaged
  Condition: Boss.hp / Boss.max_hp  <  0.5
    -> Boss | UtilityBrain: Set Action Enabled  "meteor", true
  -> Boss | UtilityBrain: Set Input  "proximity", clamp(1.0 - Boss.global_position.distance_to(Player.global_position) / 700.0, 0, 1)
  -> Boss | UtilityBrain: Evaluate
```

Meteor stays out of the pool until the boss drops below half health, then its long cooldown and `inverse` proximity (favoring range) shape when it lands.

### 15. Reset a pooled enemy's brain on respawn

A recycled enemy must not wake up with the dead one's stale inputs and cooldowns. Wipe the transient state when it leaves the pool so its first Evaluate reads a fresh world.

```
On Enemy Respawned
  -> Enemy | UtilityBrain: Clear Inputs
  -> Enemy | UtilityBrain: Clear Cooldowns
  -> Enemy | UtilityBrain: Set Input  "hp", 1.0
  -> Enemy | UtilityBrain: Evaluate
```

Registered actions and considerations survive the reset, so there is nothing to re-add - only the world state and cooldowns are cleared.

### Other use cases

**Timer pack heartbeat.** Pair with the Timer pack: a repeating Timer is the cleanest Evaluate pulse, and stopping it freezes the whole brain during pauses and cutscenes without touching a single action.

**Adaptive spawn director.** A hidden brain on the level scores "spawn wave", "drop pickup", and "stay quiet" from inputs like player health and recent deaths, pacing the pressure to how hard the player is struggling.

**Racing rubber-banding.** Each AI driver weighs push, block, and coast from a gap-to-player input, so the field naturally tightens when the player leads and eases off when they trail.

**Pet mood system.** A companion pet picks nap, play, and beg from hunger and energy inputs, with weighted-random selection keeping its day-to-day behavior lively instead of scripted.

**Squad role balancing.** Every squad member runs the same actions - frontline, flank, support - but feeds its own distance and health inputs, so the group self-organizes without a commander script.

---

## Tips and common mistakes

- **The node is the agent - there is no agent id.** Every Action, Condition, and Expression acts on the `UtilityBrain` behavior of the node it is placed on. If you ported patterns from the raw Construct 3 addon, drop the agent-id argument you used to thread through every call. One brain, one enemy.
- **Considerations are discrete typed ACEs, not hand-written JSON.** You add each factor with a real Add Consideration row, so there is no JSON blob to hand-edit and no consideration-id string to typo (a mismatch there silently dropped a factor in the original). If a factor is not affecting scoring, check the input key and curve on the row, not a text field.
- **Response curves are a friendly dropdown, not raw math.** Pick `linear`, `inverse`, `quadratic`, `inverse_quadratic`, `logistic`, `threshold`, or `bell` instead of writing curve parameters by hand. Remember `curve_center` and `curve_slope` only affect logistic, threshold, and bell.
- **A consideration-less action is your fallback - use it.** An action with no considerations scores the flat `fallback_score`, so registering an `"idle"` (or `"hold"`) with zero considerations IS the always-have-a-fallback best practice. There is nothing else to wire, and it keeps the brain from stalling into On No Valid Action.
- **Register actions and considerations before you Evaluate.** Evaluating an empty or half-built brain just fires On No Valid Action and makes debugging harder. Do all your Add Action / Add Consideration in On Ready (or at spawn), then feed inputs and Evaluate on your loop.
- **Push inputs right before Evaluate.** World-state inputs are read at evaluation time and an unset key reads as 0. Treat them as transient decision input: Set Input, then Evaluate, in the same event. Stale or missing inputs quietly skew scores.
- **Mark Action Complete already re-evaluates - do not also call Evaluate.** Completing an action fires On Action Completed, starts its cooldown, and re-evaluates in one step. Adding a second Evaluate right after just runs an extra, redundant decision pass.
- **Inertia nudges, it does not rescue.** The `inertia_bonus` only bumps an action that is already viable (already at or above `min_score`). It will not keep a running action alive once its own considerations have vetoed it below the threshold, so do not lean on inertia to hold a behavior that should end - use a cooldown or a dedicated consideration.
- **Considerations multiply, so any near-zero factor vetoes the action.** This is a feature: "never heal without mana" is one `threshold` consideration, not an if statement. But it also means one badly tuned factor can silently zero out an action - if something never fires, check each of its considerations for a curve that is bottoming out.
- **Keep considerations few and meaningful.** Two or three sharp factors read more clearly and tune more predictably than a pile of weak ones. `score_compensation` (on by default) keeps many-factor actions from unfairly deflating, but it is not a license to stack ten considerations.
- **Interrupt Action respects the interruptible flag.** If you register an action with `interruptible` false (a reload, a heavy cast), Interrupt Action leaves it alone by design. Set the flag when you register the action, not at interrupt time.
