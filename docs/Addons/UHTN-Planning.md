# UHTN Planning - Utility AI Steering a Hierarchical Task Network

UHTN Planning is the pack where the two halves of smart game AI finally work as one: an **HTN planner** decides *how* to reach a goal (tasks decompose into ordered steps through methods with preconditions and backtracking), and **Utility AI** decides *which* way is best *right now* (response-curve scorers evaluated against live world state rank the methods at plan time). Attach a `UHTNPlanner` to any `Node2D` and that node gains both. The same task network makes an enemy patrol when the player is far and switch to a chase the moment a closeness score overtakes it - no re-authoring, no state machine, just the world state changing under a curve.

It is also **fully data-driven**: a `UHTNPlanResource` (.tres) holds an entire plan - tasks, methods, preconditions, and scoring curves - as friendly Inspector grids with dropdowns for task kinds, comparison operators, and curve shapes. A designer fills the grids, saves the asset, and drops it onto the planner's **Plan Resource** slot; one asset can drive a hundred agents, and a variant is just another .tres. Prefer events? Every grid row has a matching builder action, so the whole network can be authored in the sheet instead. (This pack supersedes the separate HTN Agent and UtilityBrain packs, which remain available for existing projects.)

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup - the data-driven way](#setup---the-data-driven-way)
4. [Setup - the event-sheet way](#setup---the-event-sheet-way)
5. [ACE reference](#ace-reference)
6. [Use cases](#use-cases)
7. [Other use cases](#other-use-cases)
8. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **AI that changes its mind for real reasons.** A guard patrols, investigates, chases, or flees because scoring curves over live facts said so - not because you wrote a hundred transitions.
- **Designer-owned balancing.** Aggression, fear, and caution live in a .tres grid as curves and weights. A designer retunes the whole cast without touching one event.
- **One archetype, many personalities.** Same plan asset, different seed facts (`seed_aggression`, `seed_caution`) - each instance ranks methods differently and plays differently.
- **Multi-step routines with fallbacks.** "Engage" decomposes into cover-then-shoot, or falls back to a rush when no cover fact is set - backtracking picks the first workable way.
- **Boss phases without a phase enum.** Health, distance, and rage facts flow through curves; the plan flips from combo pressure to ranged zoning when the scores cross.
- **Big casts on a budget.** Planning happens on Request Plan, not every tick - a hundred agents replan on events (seen, hurt, alarm), not on a timer.

## Core concepts

| Concept | Meaning |
| --- | --- |
| **World state** | The planner's facts: a per-node key-value blackboard you write with Set World State. Preconditions and scorers both read it. |
| **Primitive task** | A leaf step your event sheet executes (walk, shoot, hide). The plan is an ordered list of these. |
| **Compound task** | A task that decomposes into subtasks through methods. |
| **Method** | One way to accomplish a compound task: preconditions + an ordered subtask list + a rank source. |
| **Precondition** | A world-state check (`key op value`) a method needs before it can be chosen. |
| **Utility scorer** | The Utility-AI half: named inputs, each a world-state key fed through a response curve, averaged by weight into a live 0-1 score. |
| **Rank** | How methods compete: a method bound to a scorer ranks by the scorer's live value; otherwise by its fixed utility number. Highest applicable rank wins, with backtracking. |
| **Plan** | The flat, ordered primitive-task list decomposition produced. Run the Current Task, then Mark Complete / Mark Failed. |

**Response curves** (per scorer input): `linear`, `inverse`, `quadratic`, `inverse_quadratic`, `logistic` (center + slope), `threshold` (center), `bell` (center + slope). Inputs are clamped 0-1, so normalise facts (a distance becomes a closeness 0-1) before writing them.

## Setup - the data-driven way

1. In the FileSystem dock: right-click, **Create New > Resource**, pick `UHTNPlanResource`, and save it (for example `guard_plan.tres`).
2. Fill the Inspector grids:
   - **Tasks**: every task name, with the kind dropdown (`primitive` or `compound`).
   - **Methods**: one row per way to do a compound task - the task, a unique method id, its ordered comma-separated subtasks, an optional scorer id, and the fixed utility used when no scorer is set.
   - **Conditions**: preconditions per method id (`key`, an operator from the dropdown, `value`).
   - **Scorer Inputs**: the utility half - each row feeds a world-state key through a curve (dropdown) into a named scorer, with weight, center, and slope.
   - Set **Root Task** (the grid warns while it is empty).
3. Attach a `UHTNPlanner` behavior to the agent node and drop the .tres onto its **Plan Resource** slot - it loads on ready and fires **On Plan Loaded**.
4. In the sheet: write facts with **Set World State**, call **Request Plan**, execute the **Current Task** on **On Task Started**, and call **Mark Task Complete** / **Mark Task Failed** as steps finish.

## Setup - the event-sheet way

Every grid has a builder action, so the same guard reads as events:

```text
On ready:
  UHTNPlanner: Add Primitive Task "patrol_step"
  UHTNPlanner: Add Primitive Task "chase_step"
  UHTNPlanner: Add Compound Task "root"
  UHTNPlanner: Add Method "root", "m_patrol", utility 0.2
  UHTNPlanner: Add Method Subtask "root", "m_patrol", "patrol_step"
  UHTNPlanner: Add Method "root", "m_chase", utility 0
  UHTNPlanner: Add Method Subtask "root", "m_chase", "chase_step"
  UHTNPlanner: Add Scorer Input "aggro", "closeness", linear, weight 1, center 0.5, slope 0.2
  UHTNPlanner: Set Method Scorer "root", "m_chase", "aggro"
  UHTNPlanner: Request Plan

Every 0.2 seconds:
  UHTNPlanner: Set World State "closeness", 1 - clamp(distance(Self, Player) / 800, 0, 1)

UHTNPlanner: On Task Started
  ... run the Current Task (move, aim, animate), then Mark Task Complete
```

Far away, `aggro` scores low and the fixed 0.2 patrol wins; up close it overtakes and the same network chases.

## ACE reference

### Actions

| Action | What it does |
| --- | --- |
| Set World State | Writes a fact - preconditions and scorer inputs read it. |
| Clear World State | Removes a world-state key. |
| Add Primitive Task | Registers a leaf task your sheet executes directly. |
| Add Compound Task | Registers a task that decomposes via methods. |
| Add Method | Adds (or re-scores) a way to accomplish a compound task. |
| Add Method Condition | A precondition (key, operator, value) the method needs. |
| Add Method Subtask | Appends a subtask to a method, in order. |
| Add Scorer Input | Feeds a world-state key through a response curve into a named scorer. |
| Set Method Scorer | Binds a scorer to a method - ranked live at plan time. |
| Load Plan Resource | Loads a UHTNPlanResource (.tres): the whole network replaces the current one. |
| Clear Task Network | Wipes tasks, methods, and scorers (keeps world state). |
| Request Plan | Decomposes the root task into a plan and starts the first task. |
| Mark Task Complete | Advances to the next task, or fires On Plan Complete. |
| Mark Task Failed | Re-plans from the root (or fires On Plan Failed if auto-replan is off). |
| Force Task | Pushes a task to the front of the plan - the scripted-override escape hatch. |
| Invalidate Plan | Drops the current plan so the next Request Plan rebuilds it. |

### Conditions

| Condition | True when |
| --- | --- |
| Has Plan | A plan is in progress. |
| Current Task Is | The current task equals the given name. |

### Expressions

| Expression | Returns |
| --- | --- |
| Current Task | The task the sheet should be running ("" when idle). |
| Plan Length | Number of tasks in the current plan. |
| Plan Task At | The task at an index in the plan. |
| World Value | A world-state fact (0 when unset). |
| Scorer Value | A scorer's live 0-1 value - great for debugging curves on a label. |

### Triggers

| Trigger | Fires when |
| --- | --- |
| On Task Started | A task becomes current (plan start, Mark Complete advance, Force Task). |
| On Plan Complete | The last task completes. |
| On Plan Failed | Decomposition produced no plan (or a task failed with auto-replan off). |
| On Plan Loaded | A Plan Resource finished loading. |

### Method condition operators

`==`, `!=`, `<`, `<=`, `>`, `>=` - numeric compares coerce, equality is loose across types.

### Inspector properties

| Property | Meaning |
| --- | --- |
| Plan Resource | Optional UHTNPlanResource (.tres) loaded on ready - the data-driven path. |
| Root Task | The goal to plan for (a loaded resource overrides it with its own). |
| Auto Replan On Fail | Mark Task Failed re-plans from the root instead of giving up. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

## Use cases

1. **Patrol-or-chase guard.** Two methods on one root; the chase method scored by a closeness curve. Far = patrol, near = chase, one network.
2. **Fear-driven retreat.** An `inverse` curve on `health` feeds a `fear` scorer bound to the retreat method - the lower the health, the higher retreat ranks.
3. **Investigate a noise.** Write `heard_noise = 1` and the stimulus position as facts; an investigate method gated by a precondition wins the next replan.
4. **Cover-then-shoot combo.** One method with ordered subtasks `take_cover, shoot` - the plan runs them in order, Mark Complete advancing each leg.
5. **Rush fallback when no cover exists.** Give the cover method a precondition `cover_available == 1`; backtracking falls through to the plain rush method.
6. **Boss phase flip without a phase variable.** Bind the zoning method to a `bell` curve centered on mid distance and the melee combo to closeness - phases emerge from the curves crossing.
7. **Day and night schedules.** A `sleep` method gated by `is_night == 1` outranks chores after dusk; the same villager network runs both lives.
8. **Personality seeds.** Spawn each enemy with `seed_aggression` facts and include that key as a weighted scorer input - one .tres, timid and vicious variants.
9. **Squad tone from one shared fact.** Mirror a global `alarm` value into each agent's world state; every scorer that includes it shifts the whole squad's behavior at once.
10. **Worker gather-craft chain.** "Build wall" decomposes into gather, chop, assemble; a failed leg calls Mark Task Failed and the replan routes around the missing resource.
11. **Escort pacing.** The escort method's scorer weighs distance-to-VIP with an `inverse` curve, so drifting too far ranks return-to-VIP above screening threats.
12. **Cutscene override.** Force Task pushes `look_at_player` in front of whatever the plan was doing; Mark Complete resumes the plan untouched.
13. **Stagger and recovery.** On a heavy hit, Force Task `flinch` - the scripted beat plays without invalidating the tactical plan behind it.
14. **Difficulty as data.** Ship `guard_easy.tres` and `guard_hard.tres` differing only in curve centers and weights; swap the Plan Resource per difficulty.
15. **Live curve debugging.** Bind a label to the Scorer Value expression to watch aggression rise as the player closes - tune center and slope in the grid while previewing.
16. **Hot-swap plans mid-game.** Call Load Plan Resource with a different .tres when the agent is promoted (recruit to veteran) - the network is replaced in one action.
17. **Panic threshold.** A `threshold` curve on `health` (center 0.3) makes a flee scorer snap from 0 to 1 - a hard break, not a gradient, when the agent is nearly dead.

## Other use cases

- **Stealth alarm tiers:** map suspicion 0-1 into a fact and gate investigate/search/combat methods on threshold curves for clean tier transitions.
- **Colony-sim job boards:** each colonist plans the highest-scoring chore chain from shared facts like hunger, stock levels, and time of day.
- **Sports opponents:** score press, fall-back, and counter methods from possession and score-difference facts for a coach-like opponent.
- **Horde variety:** seed each zombie's speed and aggression facts at spawn so one plan asset yields a shambling, lurching, sprinting crowd.
- **Companion etiquette:** rank help-in-combat against stay-close and loot-nearby scorers so the companion feels attentive instead of scripted.

## Tips and common mistakes

- **Normalise scorer inputs to 0-1.** Curves clamp their input; write `closeness = 1 - clamp(dist / max_dist, 0, 1)`, not a raw pixel distance.
- **Scorer beats utility only when bound.** A method with no scorer competes with its fixed utility number - mixing both in one compound is fine and often ideal.
- **Keep method ids unique across the plan.** The resource's Conditions grid binds preconditions by method id alone.
- **Preconditions gate, scorers rank.** A method that fails its preconditions never competes, no matter how high its scorer sits.
- **Replan on events, not every tick.** Facts can change every frame cheaply; call Request Plan when something meaningful happens (seen, hurt, alarm, arrived).
- **Register an always-true fallback method** (low utility, no preconditions) so On Plan Failed stays a real emergency signal, not a Tuesday.
- **The resource replaces, never merges.** Load Plan Resource clears the network first; use the builder actions after it to layer per-instance extras.
