# HTN Agent - Hierarchical Task Planning, One Planner Per Node

HTN Agent is a Godot EventSheets behavior pack that turns a pile of hand-written if/else steps into a planner. You attach an `HTNAgent` behavior to any `Node2D` - an enemy, a worker, a companion - and that node gains a small hierarchical task planner. You describe a goal as a tree of tasks: **primitive tasks** your sheet performs directly (walk, attack, pick up), and **compound tasks** that break down into smaller ones through **methods**. Each method carries **preconditions** (facts that must hold) and a **utility** score, so the planner reads the current world state, picks the best applicable way to reach the goal, and hands you back a flat, ordered list of primitive tasks to run. You feed facts with **Set World State**, call **Request Plan**, run the **Current Task** in your sheet, and call **Mark Task Complete** as each step finishes. When the situation changes, you re-plan instead of rewriting a state machine. There is no "agent id" to pass around: every Action, Condition, Expression, and Trigger targets the planner living on the node you drop it on.

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

- **Multi-step enemy routines.** Instead of a tangle of states, describe "engage the player" as approach, flank, strike, and reposition, and let the planner emit the exact ordered steps for the current situation.
- **Gather and craft chains.** A worker plans "build a wall" as gather wood, chop planks, then assemble - a clean dependency chain that runs in order and re-plans if a resource runs out.
- **Fetch and deliver chores.** A courier or companion plans "restock the chest" as walk to source, pick up, walk to chest, drop, with each leg a primitive task your sheet drives.
- **Stealth infiltration.** Plan "reach the objective" as find cover, sneak between cover points, and slip past the guard, choosing the safer method when a threat fact is high.
- **Job-sim and farming NPCs.** A villager plans a daily chore - go to field, till, plant, water - and loops it each morning by re-planning from the same root goal.
- **Quest and errand givers.** An NPC plans "deliver the letter" through a series of waypoints and reactions, no bespoke sequencing code per quest.
- **Puzzle-solving agents.** Plan "open the vault" as find key, unlock door, then proceed, with a precondition that only picks the unlock method once the key fact is set.
- **Squad and tactics units.** Each unit plans "take the point" as advance, secure, and hold, and a shared world fact steers whether they push or dig in.
- **Boss combos that adapt.** Describe a signature combo as an ordered method, and swap to a different method (a ranged pattern) when a distance fact says the player is far.
- **Base-building and automation workers.** Plan "process the ore" as haul, smelt, then store, and let backtracking skip a method whose inputs are not ready.
- **Escort and follow behaviors.** Plan "escort the VIP" as move to VIP, match pace, and screen threats, re-planning the instant the VIP moves or danger appears.
- **Ambient task loops.** Any NPC that should look busy - sweep, restock, patrol - runs a looping plan that re-requests itself on completion.

---

## Core concepts

The mental model is small and it composes. Learn these ideas and the rest of the pack is just filling in tasks.

**World state is a bag of facts.** The planner remembers plain key/value facts you push in with **Set World State** - `"has_key" = true`, `"wood" = 5`, `"threat" = 0.8`. Methods read these facts to decide whether they apply. **Clear World State** removes one, and the **World Value** expression reads one back. An unset fact reads as `0` in numeric comparisons and as empty in equality checks.

**Primitive tasks are the things your sheet actually does.** A primitive is a leaf - `"walk_to_well"`, `"attack"`, `"pick_up"` - that the planner cannot break down further. You register each one with **Add Primitive Task**. When a primitive becomes the current task, it is your job to perform it in the sheet (move the node, play an animation, fire a shot) and then call **Mark Task Complete**. The planner never runs the action itself; it only tells you which primitive is up next.

**Compound tasks decompose into smaller tasks.** A compound - `"get_water"`, `"engage"`, `"restock"` - is a goal that is not done directly but broken down through one or more methods. Register it with **Add Compound Task** (adding a method also registers its compound automatically). A subtask inside a method can itself be a compound, so plans can nest as deep as you like.

**A method is one way to accomplish a compound.** Add it with **Add Method** (`task_name`, `method_id`, `utility`). A method carries three things: an ordered list of **subtasks** (added with **Add Method Subtask**), a set of **preconditions** (added with **Add Method Condition**), and a **utility** score. A compound can have several competing methods - "attack up close" versus "shoot from range" - and the planner chooses between them.

**Preconditions gate a method; utility ranks it.** Each **Add Method Condition** is a fact check: a world-state `key`, an operator, and an expected `value`. All of a method's conditions must hold for it to be applicable. Among the applicable methods, the planner takes the one with the **highest utility** first. So you use conditions to say "this way is only valid when...", and utility to say "all else equal, prefer this way." **Set Method Utility** re-scores a method at runtime, which lets priorities shift as the fight or the day goes on.

The valid operators for a method condition are `==`, `!=`, `<`, `<=`, `>`, and `>=`. Equality (`==`, `!=`) compares numbers loosely and everything else as text; the ordering operators (`<`, `<=`, `>`, `>=`) compare numbers.

**Planning turns the root goal into a flat list.** You name a goal in the `root_task` Inspector property, then call **Request Plan**. The planner decomposes the root: at every compound it gathers the methods whose preconditions hold, tries them in descending utility order, and expands their subtasks. If a subtask cannot be decomposed (a dead end), it **backtracks** to the next method. The result is a single ordered list of primitive tasks - the **plan** - and the first task starts immediately.

**Execution walks the plan one task at a time.** After Request Plan, the first primitive is the **Current Task** and **On Task Started** fires. Your sheet performs it, then calls **Mark Task Complete** to advance to the next primitive (which fires On Task Started again), or **Mark Task Failed** to abandon the plan. When the last task completes, **On Plan Complete** fires. **Has Plan** tells you whether a plan is still running, and **Plan Length** how many steps it holds.

**Re-planning is how the agent stays reactive.** The world changes, so the plan goes stale. **Mark Task Failed** re-plans from the root when `auto_replan_on_fail` is on (the default), or gives up and fires **On Plan Failed** when it is off. **Invalidate Plan** quietly drops the current plan without firing anything, so your next Request Plan rebuilds it from fresh facts. **Clear Task Network** wipes every task and method (but keeps world state) when you want to rebuild the whole tree.

**The golden loop.** Four moves: build the task network on ready, feed facts, request a plan, and drive the current task until the plan completes. Everything else is tuning.

---

## Setup

**1. Attach the planner.** Add an `HTNAgent` behavior as a child node of your `Node2D` agent (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The behavior reads its parent as the host, so its parent must be a `Node2D`. One planner per agent - each worker or enemy gets its own.

**2. Set the Inspector knobs.** Select the `HTNAgent` node and set the goal and re-plan behavior:

| Property | Default | What it does |
|---|---|---|
| `root_task` | `""` | The goal the planner decomposes when you call Request Plan - a compound or primitive task name. |
| `auto_replan_on_fail` | `true` | When on, Mark Task Failed re-plans from the root; when off, it gives up and fires On Plan Failed. |

**3. Wire the golden loop.** Build the network in `On Ready`, feed any facts, call Request Plan, then react to On Task Started and mark each step complete. Here is a complete first agent - a guard that walks a three-point patrol and loops it:

```
Inspector: Root Task = "patrol_route"

On Ready
  -> Guard | HTNAgent: Add Primitive Task  "go_to_a"
  -> Guard | HTNAgent: Add Primitive Task  "go_to_b"
  -> Guard | HTNAgent: Add Primitive Task  "go_to_c"
  -> Guard | HTNAgent: Add Method  "patrol_route", "loop", 1
  -> Guard | HTNAgent: Add Method Subtask  "patrol_route", "loop", "go_to_a"
  -> Guard | HTNAgent: Add Method Subtask  "patrol_route", "loop", "go_to_b"
  -> Guard | HTNAgent: Add Method Subtask  "patrol_route", "loop", "go_to_c"
  -> Guard | HTNAgent: Request Plan

On Task Started
  Condition: Guard | HTNAgent  Current Task Is  "go_to_a"
    -> Guard: move toward point A
  Condition: Guard | HTNAgent  Current Task Is  "go_to_b"
    -> Guard: move toward point B
  Condition: Guard | HTNAgent  Current Task Is  "go_to_c"
    -> Guard: move toward point C

On Guard reached its target
  -> Guard | HTNAgent: Mark Task Complete

On Plan Complete
  -> Guard | HTNAgent: Request Plan   // loop the patrol from the top
```

`Add Method "patrol_route", "loop"` also registers the `patrol_route` compound, so no separate Add Compound Task is needed here. Register every task and method before you ever Request Plan. Perform the primitive in your own sheet logic, and only advance with Mark Task Complete when that step is genuinely done.

---

## ACE reference

All ACEs live in the **HTN** category and target the `HTNAgent` behavior on the node they are placed on. There is no agent-id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set World State | `key` (String), `value` | Writes a fact the planner reads in method preconditions. |
| Clear World State | `key` (String) | Removes a world-state key. |
| Add Primitive Task | `task_name` (String) | Registers a leaf task your sheet executes directly. |
| Add Compound Task | `task_name` (String) | Registers a task that decomposes via methods. |
| Add Method | `task_name` (String), `method_id` (String), `utility` (float) | Adds (or re-scores) a way to accomplish a compound task; the highest-utility applicable method wins. Registers the compound if it is new. |
| Add Method Condition | `task_name` (String), `method_id` (String), `key` (String), `op` (String), `value` | Adds a precondition to a method: a world-state key, an operator (`==`, `!=`, `<`, `<=`, `>`, `>=`), and an expected value. All of a method's conditions must hold for it to be chosen. |
| Add Method Subtask | `task_name` (String), `method_id` (String), `subtask` (String) | Appends a subtask (a primitive or another compound) to a method, in order. |
| Set Method Utility | `task_name` (String), `method_id` (String), `utility` (float) | Updates a method's utility at runtime for utility-driven re-prioritising. |
| Clear Task Network | (none) | Wipes all tasks and methods; keeps world state. |
| Request Plan | (none) | Decomposes the root task into a plan and starts the first task (or fires On Plan Failed if nothing decomposes). |
| Mark Task Complete | (none) | Advances to the next task, firing On Task Started; fires On Plan Complete after the last one. |
| Mark Task Failed | (none) | Re-plans from the root, or fires On Plan Failed if auto-replan is off. |
| Invalidate Plan | (none) | Drops the current plan (fires nothing) so the next Request Plan rebuilds it. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Plan | (none) | Whether the agent currently has an unfinished plan still running. |
| Current Task Is | `task_name` (String) | Whether the task running right now is this one. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Current Task | (none) | String | The primitive task running right now ("" if none). |
| Plan Length | (none) | int | How many primitive tasks the current plan holds. |
| World Value | `key` (String) | Variant | The current value of a world-state fact (0 if unset). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Task Started | A new primitive task becomes current - after Request Plan starts the plan, and after each Mark Task Complete that advances to another task. Passes the task name. |
| On Plan Complete | The last task in the plan is marked complete. |
| On Plan Failed | Request Plan produces no plan, or Mark Task Failed fires while auto-replan is off. |

### Method condition operators

The `op` parameter of Add Method Condition accepts these strings:

| Operator | Compares | Meaning |
|---|---|---|
| `==` | value (numbers loosely, else text) | fact equals the expected value |
| `!=` | value (numbers loosely, else text) | fact differs from the expected value |
| `<` | numbers | fact is less than the value |
| `<=` | numbers | fact is at most the value |
| `>` | numbers | fact is greater than the value |
| `>=` | numbers | fact is at least the value |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `root_task` | String | `""` | The goal the planner decomposes on Request Plan (a compound or primitive task name). |
| `auto_replan_on_fail` | bool | `true` | On: Mark Task Failed re-plans from the root. Off: it gives up and fires On Plan Failed. |

---

## Use cases

Each example targets the `HTNAgent` behavior on the named node. Build the network in `On Ready`, feed facts with Set World State, call Request Plan, and drive the plan through On Task Started plus Mark Task Complete.

### 1. A simple linear plan

The most basic HTN: one compound with one method whose subtasks run in order. A worker walks to a tree, chops it, and hauls the log.

```
Inspector: Root Task = "harvest_tree"

On Ready
  -> Worker | HTNAgent: Add Primitive Task  "walk_to_tree"
  -> Worker | HTNAgent: Add Primitive Task  "chop"
  -> Worker | HTNAgent: Add Primitive Task  "haul_log"
  -> Worker | HTNAgent: Add Method  "harvest_tree", "do_it", 1
  -> Worker | HTNAgent: Add Method Subtask  "harvest_tree", "do_it", "walk_to_tree"
  -> Worker | HTNAgent: Add Method Subtask  "harvest_tree", "do_it", "chop"
  -> Worker | HTNAgent: Add Method Subtask  "harvest_tree", "do_it", "haul_log"
  -> Worker | HTNAgent: Request Plan

On Task Started
  Condition: Worker | HTNAgent  Current Task Is  "walk_to_tree"
    -> Worker: move toward the nearest tree
  Condition: Worker | HTNAgent  Current Task Is  "chop"
    -> Worker: play chop animation
  Condition: Worker | HTNAgent  Current Task Is  "haul_log"
    -> Worker: carry the log to the stockpile

On Worker finished its step
  -> Worker | HTNAgent: Mark Task Complete
```

The plan is just `[walk_to_tree, chop, haul_log]`. Each Mark Task Complete advances one step and fires On Task Started for the next.

### 2. Two methods, utility picks the plan

Give a compound two ways to solve it and let the higher utility win. An enemy prefers a melee combo but has a ranged fallback registered at lower utility.

```
Inspector: Root Task = "engage"

On Ready
  -> Enemy | HTNAgent: Add Primitive Task  "close_distance"
  -> Enemy | HTNAgent: Add Primitive Task  "melee_swing"
  -> Enemy | HTNAgent: Add Primitive Task  "throw_knife"
  -> Enemy | HTNAgent: Add Method  "engage", "melee", 2
  -> Enemy | HTNAgent: Add Method Subtask  "engage", "melee", "close_distance"
  -> Enemy | HTNAgent: Add Method Subtask  "engage", "melee", "melee_swing"
  -> Enemy | HTNAgent: Add Method  "engage", "ranged", 1
  -> Enemy | HTNAgent: Add Method Subtask  "engage", "ranged", "throw_knife"
  -> Enemy | HTNAgent: Request Plan
```

Both methods are applicable (neither has conditions), so utility decides: `melee` (2) beats `ranged` (1) and the plan is `[close_distance, melee_swing]`.

### 3. Preconditions branch the plan

Use conditions so a method only applies when a fact holds. A raider opens a door by unlocking it if it has the key, otherwise it bashes the door down.

```
Inspector: Root Task = "get_through_door"

On Ready
  -> Raider | HTNAgent: Add Primitive Task  "use_key"
  -> Raider | HTNAgent: Add Primitive Task  "bash_door"
  -> Raider | HTNAgent: Add Method  "get_through_door", "unlock", 2
  -> Raider | HTNAgent: Add Method Condition  "get_through_door", "unlock", "has_key", "==", true
  -> Raider | HTNAgent: Add Method Subtask  "get_through_door", "unlock", "use_key"
  -> Raider | HTNAgent: Add Method  "get_through_door", "force", 1
  -> Raider | HTNAgent: Add Method Subtask  "get_through_door", "force", "bash_door"

On player gives the raider a key
  -> Raider | HTNAgent: Set World State  "has_key", true
  -> Raider | HTNAgent: Request Plan
```

If `has_key` is true, the `unlock` method (utility 2) applies and wins. If not, its precondition fails, so only `force` is applicable and the plan is `[bash_door]`.

### 4. A gather-then-build dependency chain

Conditions can guard on counts, not just booleans. A builder only picks the "assemble" method once it has enough wood.

```
Inspector: Root Task = "build_wall"

On Ready
  -> Builder | HTNAgent: Add Primitive Task  "gather_wood"
  -> Builder | HTNAgent: Add Primitive Task  "assemble_wall"
  -> Builder | HTNAgent: Add Method  "build_wall", "assemble", 2
  -> Builder | HTNAgent: Add Method Condition  "build_wall", "assemble", "wood", ">=", 5
  -> Builder | HTNAgent: Add Method Subtask  "build_wall", "assemble", "assemble_wall"
  -> Builder | HTNAgent: Add Method  "build_wall", "collect", 1
  -> Builder | HTNAgent: Add Method Subtask  "build_wall", "collect", "gather_wood"

On Builder picks up a log
  -> Builder | HTNAgent: Set World State  "wood", Builder.wood_count
  -> Builder | HTNAgent: Invalidate Plan
  -> Builder | HTNAgent: Request Plan
```

Below 5 wood the `assemble` precondition fails, so the builder keeps gathering; once the fact reaches 5, the re-plan picks the higher-utility assemble method.

### 5. Re-plan when a step fails

If a primitive cannot be carried out - the target moved, the resource vanished - call Mark Task Failed and let auto-replan rebuild from the current facts.

```
Inspector: Root Task = "deliver_package"

On Task Started
  Condition: Courier | HTNAgent  Current Task Is  "pick_up"
    -> Courier: try to grab the package

On package is gone before pickup
  -> Courier | HTNAgent: Set World State  "package_here", false
  -> Courier | HTNAgent: Mark Task Failed   // auto-replan builds a new plan from fresh facts
```

With `auto_replan_on_fail` on (the default), Mark Task Failed simply calls Request Plan again, so the new facts steer a different method.

### 6. Give up cleanly when no plan exists

Turn `auto_replan_on_fail` off in the Inspector when a failure should end the behavior instead of looping. Catch On Plan Failed for the fallback.

```
Inspector: Root Task = "reach_exit", Auto Replan On Fail = false

On Task Started
  Condition: Robot | HTNAgent  Current Task Is  "cross_bridge"
    -> Robot: walk across

On bridge collapses
  -> Robot | HTNAgent: Mark Task Failed

On Plan Failed
  -> Robot: play "stuck" animation and idle
```

Request Plan also fires On Plan Failed when the root task cannot decompose at all (every method vetoed), so this same handler covers "there was never a valid plan."

### 7. Re-prioritise a method at runtime

Change how attractive a method is while the game runs with Set Method Utility. As a boss loses health, raise the utility of its escape method so it starts choosing to flee.

```
Inspector: Root Task = "act"

On Ready
  -> Boss | HTNAgent: Add Primitive Task  "attack"
  -> Boss | HTNAgent: Add Primitive Task  "flee_to_cover"
  -> Boss | HTNAgent: Add Method  "act", "fight", 2
  -> Boss | HTNAgent: Add Method Subtask  "act", "fight", "attack"
  -> Boss | HTNAgent: Add Method  "act", "escape", 1
  -> Boss | HTNAgent: Add Method Subtask  "act", "escape", "flee_to_cover"

On Boss health below 30 percent
  -> Boss | HTNAgent: Set Method Utility  "act", "escape", 3   // escape now outranks fight
  -> Boss | HTNAgent: Invalidate Plan
  -> Boss | HTNAgent: Request Plan
```

Set Method Utility only changes the score; you still need a re-plan (Invalidate Plan plus Request Plan, or Mark Task Failed) for the new ranking to take effect.

### 8. Nested compounds for reusable sub-plans

A subtask can be another compound, so common sequences are written once and reused. A soldier's "assault" compound expands into a shared "reload_if_needed" compound plus a fire step.

```
Inspector: Root Task = "assault"

On Ready
  -> Soldier | HTNAgent: Add Primitive Task  "reload"
  -> Soldier | HTNAgent: Add Primitive Task  "fire"
  // reusable sub-plan
  -> Soldier | HTNAgent: Add Method  "top_off", "do_reload", 2
  -> Soldier | HTNAgent: Add Method Condition  "top_off", "do_reload", "ammo", "<", 3
  -> Soldier | HTNAgent: Add Method Subtask  "top_off", "do_reload", "reload"
  -> Soldier | HTNAgent: Add Method  "top_off", "skip", 1   // no subtasks: a valid empty step? see note
  // the main goal reuses it
  -> Soldier | HTNAgent: Add Method  "assault", "push", 1
  -> Soldier | HTNAgent: Add Method Subtask  "assault", "push", "top_off"
  -> Soldier | HTNAgent: Add Method Subtask  "assault", "push", "fire"
  -> Soldier | HTNAgent: Set World State  "ammo", 1
  -> Soldier | HTNAgent: Request Plan
```

A compound only decomposes if a method's subtasks all decompose, so keep at least one method that actually resolves (give `top_off` a real primitive when ammo is fine, rather than relying on an empty method). With `ammo` at 1 the plan is `[reload, fire]`.

### 9. Loop a plan forever

Re-request the same plan on completion for a routine that should repeat, like a sweeping cleaner NPC.

```
Inspector: Root Task = "clean_route"

On Ready
  -> Cleaner | HTNAgent: Add Primitive Task  "sweep_lobby"
  -> Cleaner | HTNAgent: Add Primitive Task  "empty_bin"
  -> Cleaner | HTNAgent: Add Method  "clean_route", "round", 1
  -> Cleaner | HTNAgent: Add Method Subtask  "clean_route", "round", "sweep_lobby"
  -> Cleaner | HTNAgent: Add Method Subtask  "clean_route", "round", "empty_bin"
  -> Cleaner | HTNAgent: Request Plan

On Cleaner finished its step
  -> Cleaner | HTNAgent: Mark Task Complete

On Plan Complete
  -> Cleaner | HTNAgent: Request Plan   // start the round again
```

Re-planning each loop means the round automatically adapts if you change facts between passes.

### 10. Companion fetch-and-deliver

A companion restocks the player's chest: walk to the pile, grab an item, carry it back, drop it. Facts track whether items remain.

```
Inspector: Root Task = "restock"

On Ready
  -> Buddy | HTNAgent: Add Primitive Task  "go_to_pile"
  -> Buddy | HTNAgent: Add Primitive Task  "pick_up"
  -> Buddy | HTNAgent: Add Primitive Task  "go_to_chest"
  -> Buddy | HTNAgent: Add Primitive Task  "drop"
  -> Buddy | HTNAgent: Add Method  "restock", "haul", 2
  -> Buddy | HTNAgent: Add Method Condition  "restock", "haul", "items_left", ">", 0
  -> Buddy | HTNAgent: Add Method Subtask  "restock", "haul", "go_to_pile"
  -> Buddy | HTNAgent: Add Method Subtask  "restock", "haul", "pick_up"
  -> Buddy | HTNAgent: Add Method Subtask  "restock", "haul", "go_to_chest"
  -> Buddy | HTNAgent: Add Method Subtask  "restock", "haul", "drop"
  -> Buddy | HTNAgent: Add Primitive Task  "idle"
  -> Buddy | HTNAgent: Add Method  "restock", "wait", 1
  -> Buddy | HTNAgent: Add Method Subtask  "restock", "wait", "idle"

On Plan Complete
  -> Buddy | HTNAgent: Set World State  "items_left", Pile.count
  -> Buddy | HTNAgent: Request Plan   // haul again while items remain, else idle
```

When `items_left` drops to 0 the `haul` precondition fails and only the low-utility `wait` method applies, so the companion idles instead of stalling on On Plan Failed.

### 11. Stealth route chosen by threat level

Use ordering operators so a numeric fact selects the plan. A spy takes the direct route when it is safe and the vent route when threat is high.

```
Inspector: Root Task = "reach_vault"

On Ready
  -> Spy | HTNAgent: Add Primitive Task  "walk_hallway"
  -> Spy | HTNAgent: Add Primitive Task  "crawl_vents"
  -> Spy | HTNAgent: Add Method  "reach_vault", "direct", 2
  -> Spy | HTNAgent: Add Method Condition  "reach_vault", "direct", "threat", "<", 0.5
  -> Spy | HTNAgent: Add Method Subtask  "reach_vault", "direct", "walk_hallway"
  -> Spy | HTNAgent: Add Method  "reach_vault", "sneaky", 1
  -> Spy | HTNAgent: Add Method Condition  "reach_vault", "sneaky", "threat", ">=", 0.5
  -> Spy | HTNAgent: Add Method Subtask  "reach_vault", "sneaky", "crawl_vents"

On alertness changes
  -> Spy | HTNAgent: Set World State  "threat", Level.alert_ratio
  -> Spy | HTNAgent: Invalidate Plan
  -> Spy | HTNAgent: Request Plan
```

The two methods have mutually exclusive conditions on `threat`, so exactly one is applicable at a time and the utility numbers never even come into play.

### 12. Read the plan with expressions

Show a HUD hint of what the agent is doing and how far along it is, using Current Task and Plan Length.

```
Every 0.5 seconds
  Condition: Worker | HTNAgent  Has Plan
    -> HUD: set label to "Doing: " & Worker | HTNAgent.Current Task
    -> HUD: set progress bar max to Worker | HTNAgent.Plan Length

On no plan is running
  Condition: [inverted] Worker | HTNAgent  Has Plan
    -> HUD: set label to "Idle"
```

Current Task returns "" between plans, and Has Plan goes false the moment the last task completes, so the HUD reads Idle without any extra flag.

### 13. React to a world change by invalidating

When the world shifts under the agent, drop the stale plan quietly and rebuild from current facts. A guard that hears a noise abandons its patrol to investigate.

```
Inspector: Root Task = "patrol_or_check"

On Ready
  -> Guard | HTNAgent: Add Primitive Task  "patrol"
  -> Guard | HTNAgent: Add Primitive Task  "investigate"
  -> Guard | HTNAgent: Add Method  "patrol_or_check", "check", 2
  -> Guard | HTNAgent: Add Method Condition  "patrol_or_check", "check", "heard_noise", "==", true
  -> Guard | HTNAgent: Add Method Subtask  "patrol_or_check", "check", "investigate"
  -> Guard | HTNAgent: Add Method  "patrol_or_check", "walk", 1
  -> Guard | HTNAgent: Add Method Subtask  "patrol_or_check", "walk", "patrol"
  -> Guard | HTNAgent: Request Plan

On Noise Heard
  -> Guard | HTNAgent: Set World State  "heard_noise", true
  -> Guard | HTNAgent: Invalidate Plan
  -> Guard | HTNAgent: Request Plan   // now the check method applies and wins
```

Invalidate Plan fires nothing, so it will not trip your On Plan Failed handler - it is the polite way to force a fresh plan mid-behavior.

### 14. Rebuild the whole network for a new phase

When an agent switches to an entirely different behavior set, wipe the task tree with Clear Task Network and register the new one. World-state facts survive, so context carries over.

```
On boss enters phase 2
  -> Boss | HTNAgent: Clear Task Network
  -> Boss | HTNAgent: Add Primitive Task  "summon_adds"
  -> Boss | HTNAgent: Add Primitive Task  "laser_sweep"
  -> Boss | HTNAgent: Add Method  "act", "phase2", 1
  -> Boss | HTNAgent: Add Method Subtask  "act", "phase2", "summon_adds"
  -> Boss | HTNAgent: Add Method Subtask  "act", "phase2", "laser_sweep"
  -> Boss | HTNAgent: Request Plan
```

Clear Task Network keeps world state, so a fact like `enrage_stacks` set in phase 1 is still readable by the new phase-2 methods.

### 15. Daily chore loop for a farm NPC

A farmer runs a fixed morning routine, then loops it, and a weather fact swaps in a different method on rainy days.

```
Inspector: Root Task = "morning_chores"

On Ready
  -> Farmer | HTNAgent: Add Primitive Task  "till"
  -> Farmer | HTNAgent: Add Primitive Task  "plant"
  -> Farmer | HTNAgent: Add Primitive Task  "water"
  -> Farmer | HTNAgent: Add Primitive Task  "shelter"
  -> Farmer | HTNAgent: Add Method  "morning_chores", "field_work", 2
  -> Farmer | HTNAgent: Add Method Condition  "morning_chores", "field_work", "raining", "==", false
  -> Farmer | HTNAgent: Add Method Subtask  "morning_chores", "field_work", "till"
  -> Farmer | HTNAgent: Add Method Subtask  "morning_chores", "field_work", "plant"
  -> Farmer | HTNAgent: Add Method Subtask  "morning_chores", "field_work", "water"
  -> Farmer | HTNAgent: Add Method  "morning_chores", "stay_in", 1
  -> Farmer | HTNAgent: Add Method Condition  "morning_chores", "stay_in", "raining", "==", true
  -> Farmer | HTNAgent: Add Method Subtask  "morning_chores", "stay_in", "shelter"

On new day starts
  -> Farmer | HTNAgent: Set World State  "raining", Weather.is_raining
  -> Farmer | HTNAgent: Request Plan
```

Because the two methods have opposite conditions on `raining`, the farmer plans field work on clear days and stays sheltered when it rains, with no extra branching in the sheet.

### Other use cases

**Restaurant kitchen sim.** A cook plans "serve the order" as fetch ingredients, cook, plate, and deliver, with a world fact per ingredient so a missing item makes the planner backtrack to a simpler dish.

**Creature needs loop.** A pet or zoo animal keeps hunger, energy, and fun as world-state facts and re-plans a "live your life" root each time a plan completes, so the method with the most urgent need (highest utility) wins next.

**Heist crew roles.** Each crew member runs its own planner against shared facts like "alarm" and "vault_open", so the safecracker plans drill-and-grab while the lookout plans watch-and-warn, and one tripped alarm re-plans everyone into escape methods.

**Repair drone rounds.** A maintenance drone plans "keep the base running" as fly to the most damaged structure, repair, and return to dock, marking each leg complete and re-requesting the plan so it always services whatever broke most recently.

**Wildlife predator.** A wolf plans "eat" through a stalk-chase-feed method gated on a "prey_near" fact, with a lower-utility scavenge method as the fallback when the hunt precondition fails, so the ecosystem keeps moving without a state machine.

---

## Tips and common mistakes

- **The node is the agent - there is no agent id.** Every Action, Condition, and Expression acts on the `HTNAgent` behavior of the node it is placed on. One planner, one agent. The behavior expects a `Node2D` parent, so attach it as a child of your movable game object.
- **Register the network before you Request Plan.** Add all your primitives, compounds, methods, conditions, and subtasks in `On Ready` (or at spawn) first. Requesting a plan against an empty or half-built network just decomposes to nothing and fires On Plan Failed, which makes debugging harder.
- **Add Method before its conditions and subtasks.** Add Method Condition and Add Method Subtask look the method up by its `method_id`; if the method does not exist yet, they silently do nothing. Always create the method first, then attach its conditions and subtasks.
- **Set the Root Task in the Inspector.** Request Plan decomposes whatever `root_task` names. If you leave it blank, there is nothing to plan and On Plan Failed fires. Point it at your top-level compound (or a single primitive for a trivial agent).
- **Utility only ranks methods that are already applicable.** A method is a candidate only when every one of its Add Method Condition checks holds. Among the survivors, the highest utility wins. A high utility never rescues a method whose precondition failed, so if a method is being ignored, check its conditions before its score.
- **Facts are read at plan time, not continuously.** Set World State updates the fact, but the plan already in flight does not change on its own. To act on a new fact, re-plan: Invalidate Plan then Request Plan, or Mark Task Failed. Set Method Utility likewise needs a re-plan to take effect.
- **Primitives are yours to perform; the planner only names them.** When On Task Started fires (or Current Task Is matches), your sheet does the actual work. The planner does not move the node or play an animation - it waits for you to call Mark Task Complete before advancing.
- **Mark Task Complete advances; Mark Task Failed re-plans.** Complete moves to the next primitive (or fires On Plan Complete at the end). Failed rebuilds from the root when `auto_replan_on_fail` is on, or gives up with On Plan Failed when it is off. Pick the one that matches "this step is done" versus "this step cannot be done."
- **A method decomposes only if all its subtasks do.** If any subtask is an unregistered task or a compound with no applicable method, that whole method is a dead end and the planner backtracks to the next one. When a plan comes out empty or wrong, check that every subtask name is a registered primitive or a resolvable compound.
- **Invalidate Plan is the quiet re-plan.** It drops the current plan without firing On Plan Complete or On Plan Failed, so it will not trip those handlers. Use it (paired with Request Plan) when the world changed and you just want a fresh plan, and reserve Mark Task Failed for genuine step failures.
