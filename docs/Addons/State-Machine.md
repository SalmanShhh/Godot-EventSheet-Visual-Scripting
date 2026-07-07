# State Machine - One Named State Per Node, Clean Transitions

State Machine is a Godot EventSheets behavior pack that gives a node a single, named "what am I doing right now" value and a clean way to switch it. You attach a `StateMachineBehavior` to any node - a player, an enemy, a door, a game manager - and that node now holds one **current state**, a plain String like `"idle"`, `"patrol"`, or `"open"`. There is no machine id to pass around: every Action, Condition, and Trigger targets the machine living on the node you drop it on. You set the current state with **Set State**, branch on it with the **Is In State** condition, and react to every switch with the **On State Changed** trigger, which hands you both the state you left and the state you entered. States are just names you invent, so the same tiny vocabulary drives a character's animation, an enemy's brain, a door's open/closed flip, or your whole game's menu/playing/paused flow. It replaces tangled "am I jumping AND not attacking AND..." boolean soup with one readable value and one place that changes it.

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

- **Character animation states.** Give the player one machine that flips between `"idle"`, `"run"`, `"jump"`, and `"fall"`, then let a single On State Changed play the matching animation instead of scattering play calls everywhere.
- **Enemy AI phases.** Model an enemy as `"patrol"` -> `"chase"` -> `"attack"` -> `"flee"`, branching each frame on Is In State rather than juggling a pile of booleans.
- **Game flow and screens.** Attach a machine to a game-manager node and drive `"menu"`, `"playing"`, `"paused"`, and `"game_over"` from one value, so every system asks the same question.
- **Interactive objects.** Doors, chests, levers, and switches are two- or three-state machines (`"closed"` / `"open"`, `"locked"` / `"unlocked"`) that read cleanly and never end up half-open.
- **Boss fight phases.** Escalate a boss through `"phase_1"`, `"phase_2"`, and `"enrage"`, and hang the phase-entry effects off On State Changed.
- **Weapon and ability states.** A gun that cycles `"ready"`, `"firing"`, `"reloading"`, and `"empty"` gates input with Is In State so you never fire mid-reload.
- **Traffic and environment cycles.** A stoplight rolling `"green"` -> `"yellow"` -> `"red"`, a day/night ticker, or a puzzle emitter all fit a single looping machine.
- **Elevators and platforms.** Model an elevator as `"idle"`, `"moving_up"`, `"moving_down"`, and `"doors_open"` so it only ever does one thing at a time.
- **Turn-based phase tracking.** A match manager that steps `"player_turn"`, `"enemy_turn"`, and `"resolving"` keeps whose-turn logic in one place.
- **Quest and mission stages.** Track a quest through `"not_started"`, `"in_progress"`, and `"complete"` and let On State Changed fire the reward or update the log.
- **Traps and hazards.** An `"armed"` -> `"triggered"` -> `"reset"` trap is trivial, and the change guard stops a trap from re-firing while already sprung.
- **Pause and stun gating.** Wrap input and movement in an Is In State check so a stunned or paused actor simply stops reacting without you deleting anything.

---

## Core concepts

The whole pack is three ACEs and one property. Learn these ideas and there is nothing left to learn.

**The node is the machine.** You attach one `StateMachineBehavior` to a node, and that node now has exactly one current state. There is no machine id anywhere: Set State, Is In State, and On State Changed all act on the machine sitting on the node you place the row on. If a node needs its own independent state, give it its own behavior - one machine per node.

**A state is just a name you invent.** A state is a String. There is no fixed list and nothing to declare up front - `"idle"`, `"patrol"`, `"open"`, `"phase_2"`, and `"cooking_the_soup"` are all equally valid. Pick short, consistent names and reuse them across your Set State and Is In State rows. A typo is the one thing that bites, because `"idle"` and `"Idle"` are different states.

**Only one state at a time.** The machine holds a single current value, so it is never in two states at once. That is the whole point: instead of tracking `is_jumping`, `is_attacking`, and `is_dead` as separate flags that can contradict each other, you track one value that can only be one thing.

**Set State switches, and it guards against no-op changes.** **Set State** writes the new current state. Its key behavior is the built-in change guard: if you set the state to the value it already holds, nothing happens - the state does not "change" and On State Changed does not fire again. So you can safely call `Set State "run"` every single frame while running; only the first one, the real transition, fires the trigger. This is what keeps a walk animation from restarting 60 times a second.

**Is In State reads the current state as a condition.** **Is In State** is true while the machine's current state equals the name you pass. This is your branch: gate movement behind `Is In State "run"`, gate attacks behind `Is In State "attack"`, freeze input behind `Is In State "stunned"`. Because only one state is active, these conditions are naturally mutually exclusive.

**On State Changed gives you both sides of the transition.** Every real change fires the **On State Changed** trigger with two values: `previous` (the state you just left) and `next` (the state you just entered). This is the single best place to put entry and exit effects - play the animation named `next`, stop the effect tied to `previous`, log the transition, or check "did we just leave `attack` for `flee`?". Because the change guard suppresses same-state sets, this trigger fires once per genuine transition, never on a repeat.

**The starting state is an Inspector property.** The machine's `state` property is exported and defaults to `"idle"`. Set it in the Inspector to choose where the machine begins, or override it in code with a `Set State` on ready. Whatever you pick is the value the machine holds before the first transition.

**Transitions are not enforced - you decide the rules.** The pack does not hold a transition table, so any state can move to any other state. That is deliberate and flexible, but it means the "you can only go from `reloading` to `ready`" rules live in your sheet: guard a Set State with an Is In State (or a game condition) so a transition only happens when it should. The machine remembers the value; you own the rules around it.

---

## Setup

**1. Attach the machine.** Add a `StateMachineBehavior` as a child node of the node that needs a state (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The host can be any `Node` - a `CharacterBody2D` player, an `Area2D` door, a plain manager node, anything.

**2. Set the starting state.** Select the behavior node and set the `state` property in the Inspector. It defaults to `"idle"`; change it to whatever your machine should begin in (for a door, maybe `"closed"`; for a game manager, `"menu"`).

**3. Wire the three moves.** Switch with Set State, branch with Is In State, react with On State Changed. Here is a complete first machine - a player that flips between idle and run, with one animation hook that covers both:

```
(Inspector) StateMachineBehavior.state = "idle"

On Every Tick
  Condition: Player is moving
  Condition: Player | StateMachineBehavior  Is In State  "idle"
    -> Player | StateMachineBehavior: Set State  "run"
  Condition: Player is not moving
  Condition: Player | StateMachineBehavior  Is In State  "run"
    -> Player | StateMachineBehavior: Set State  "idle"

On State Changed
  -> Player: play animation named  next
```

Because Set State guards same-value writes, the animation in On State Changed plays exactly once per real switch, not every frame. The `next` value handed to the trigger is the state you just entered, so a single row drives both animations. Name your animations to match your state names and the hook stays this small as you add more states.

---

## ACE reference

All rows live in the **State Machine** category and target the `StateMachineBehavior` on the node they are placed on. There is no machine-id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set State | `next` (String) | Switches the machine to the `next` state and fires On State Changed - but only when `next` differs from the current state, so setting the same state again is a safe no-op. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is In State | `state_name` (String) | True while the machine's current state equals `state_name`. Use it to branch behavior on the active state. |

### Expressions

This pack ships no expression ACEs. To read the machine's current state, branch on it with the **Is In State** condition; to capture a switch as it happens, use the `previous` and `next` values handed to the **On State Changed** trigger.

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| (none) | - | - | Read state with the Is In State condition; capture transitions with On State Changed's `previous` / `next`. |

### Triggers

| Trigger | Parameters | Fires when |
|---|---|---|
| On State Changed | `previous` (String), `next` (String) | Set State actually changes the state. Carries the state you left (`previous`) and the state you entered (`next`); does not fire when the state is set to its current value. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `state` | String | `idle` | The machine's current state, and the value it starts in. Set it in the Inspector to choose the starting state; Set State overwrites it at runtime. |

---

## Use cases

Each example targets the `StateMachineBehavior` on the named node. Set the starting state in the Inspector, switch with Set State, branch with Is In State, and react in On State Changed.

### 1. Player movement states driving animation

The classic use: one machine, and one On State Changed row that plays whatever animation matches the state you just entered.

```
On Every Tick
  Condition: Player is on floor
  Condition: move input is not zero
    -> Player | StateMachineBehavior: Set State  "run"
  Condition: Player is on floor
  Condition: move input is zero
    -> Player | StateMachineBehavior: Set State  "idle"
  Condition: Player is not on floor
    -> Player | StateMachineBehavior: Set State  "fall"

On State Changed
  -> Player: play animation named  next
```

Setting `"run"` every frame while running is harmless - the change guard means the run animation only starts on the real idle-to-run switch.

### 2. Enemy patrol, chase, and attack

Model the enemy brain as three named states and gate each behavior behind Is In State.

```
(Inspector) StateMachineBehavior.state = "patrol"

On Every Tick
  Condition: Enemy | StateMachineBehavior  Is In State  "patrol"
  Condition: Player within 300 px
    -> Enemy | StateMachineBehavior: Set State  "chase"
  Condition: Enemy | StateMachineBehavior  Is In State  "chase"
  Condition: Player within 60 px
    -> Enemy | StateMachineBehavior: Set State  "attack"
  Condition: Enemy | StateMachineBehavior  Is In State  "chase"
  Condition: Player beyond 400 px
    -> Enemy | StateMachineBehavior: Set State  "patrol"
```

Each Is In State branch is mutually exclusive because the machine only holds one state, so the enemy is never patrolling and attacking at the same time.

### 3. A door that opens and closes

A two-state machine is the cleanest way to model an interactive object.

```
(Inspector) StateMachineBehavior.state = "closed"

On Interact pressed
  Condition: Door | StateMachineBehavior  Is In State  "closed"
    -> Door | StateMachineBehavior: Set State  "open"
  Condition: Door | StateMachineBehavior  Is In State  "open"
    -> Door | StateMachineBehavior: Set State  "closed"

On State Changed
  Condition: Door | StateMachineBehavior  Is In State  "open"
    -> Door: play "open" animation
  Condition: Door | StateMachineBehavior  Is In State  "closed"
    -> Door: play "close" animation
```

The door can never be half-open: it is exactly one of two states, and the toggle just flips between them.

### 4. Whole-game flow on a manager node

Attach a machine to a persistent game-manager node and let every system read the same value.

```
(Inspector) StateMachineBehavior.state = "menu"

On Play pressed
  -> GameManager | StateMachineBehavior: Set State  "playing"

On Pause pressed
  Condition: GameManager | StateMachineBehavior  Is In State  "playing"
    -> GameManager | StateMachineBehavior: Set State  "paused"

On State Changed
  Condition: GameManager | StateMachineBehavior  Is In State  "paused"
    -> get_tree(): set paused true
  Condition: GameManager | StateMachineBehavior  Is In State  "playing"
    -> get_tree(): set paused false
```

One value answers "what screen are we on" for the HUD, the pause menu, spawners, and input - no duplicated flags to keep in sync.

### 5. Pause gating with Is In State

Instead of deleting or disabling systems, just refuse to act unless the game is playing.

```
On Every Tick
  Condition: GameManager | StateMachineBehavior  Is In State  "playing"
    -> Player: read input and move
    -> Enemies: update AI
```

Wrapping the update in a single Is In State check freezes everything the moment the state leaves `"playing"`, and resumes it untouched when it returns.

### 6. Boss fight phases by health

Escalate a boss through named phases and put each phase's setup in On State Changed.

```
(Inspector) StateMachineBehavior.state = "phase_1"

On Damaged
  Condition: Boss | StateMachineBehavior  Is In State  "phase_1"
  Condition: Boss.hp / Boss.max_hp  <  0.5
    -> Boss | StateMachineBehavior: Set State  "phase_2"
  Condition: Boss | StateMachineBehavior  Is In State  "phase_2"
  Condition: Boss.hp / Boss.max_hp  <  0.2
    -> Boss | StateMachineBehavior: Set State  "enrage"

On State Changed
  Condition: Boss | StateMachineBehavior  Is In State  "enrage"
    -> Boss: play roar
    -> Boss: speed up attacks
```

The Is In State guard on each transition means the boss can only step forward one phase at a time, never skip or repeat.

### 7. Weapon cycle: ready, firing, reloading, empty

Gate the trigger behind state so you can never fire mid-reload.

```
(Inspector) StateMachineBehavior.state = "ready"

On Fire pressed
  Condition: Gun | StateMachineBehavior  Is In State  "ready"
  Condition: Gun.ammo  >  0
    -> Gun | StateMachineBehavior: Set State  "firing"

On Reload pressed
  Condition: Gun | StateMachineBehavior  Is In State  "ready"
    -> Gun | StateMachineBehavior: Set State  "reloading"

On State Changed
  Condition: Gun | StateMachineBehavior  Is In State  "reloading"
    -> Gun: play reload animation
```

Because fire only fires from `"ready"`, a half-finished reload simply cannot shoot - the state is the interlock.

### 8. Traffic light cycle

A looping machine that advances on a timer, one step per tick.

```
(Inspector) StateMachineBehavior.state = "green"

On Timer timeout
  Condition: Light | StateMachineBehavior  Is In State  "green"
    -> Light | StateMachineBehavior: Set State  "yellow"
  Condition: Light | StateMachineBehavior  Is In State  "yellow"
    -> Light | StateMachineBehavior: Set State  "red"
  Condition: Light | StateMachineBehavior  Is In State  "red"
    -> Light | StateMachineBehavior: Set State  "green"

On State Changed
  -> Light: show only the lamp named  next
```

The `next` value handed to the trigger names the lamp to light, so one row handles all three colors.

### 9. Elevator with distinct motion states

Keep an elevator honest by letting it be exactly one thing at a time.

```
(Inspector) StateMachineBehavior.state = "idle"

On Call up pressed
  Condition: Elevator | StateMachineBehavior  Is In State  "idle"
    -> Elevator | StateMachineBehavior: Set State  "moving_up"

On Reached top
  -> Elevator | StateMachineBehavior: Set State  "doors_open"

On Every Tick
  Condition: Elevator | StateMachineBehavior  Is In State  "moving_up"
    -> Elevator: move toward top floor
```

Since the machine cannot be `"moving_up"` and `"doors_open"` at once, the doors never open mid-travel.

### 10. Trap that arms, triggers, and resets

The change guard shines here: a sprung trap will not re-trigger while already triggered.

```
(Inspector) StateMachineBehavior.state = "armed"

On Body entered
  Condition: Trap | StateMachineBehavior  Is In State  "armed"
    -> Trap | StateMachineBehavior: Set State  "triggered"

On State Changed
  Condition: Trap | StateMachineBehavior  Is In State  "triggered"
    -> Trap: deal damage
    -> Trap: start 3s reset timer

On Reset timer timeout
  -> Trap | StateMachineBehavior: Set State  "armed"
```

Even if three bodies enter on the same frame, only the first `Set State "triggered"` changes the state and deals damage - the rest are no-ops.

### 11. Reacting to a specific transition with previous and next

On State Changed hands you both sides, so you can react to an exact edge, not just the destination.

```
On State Changed
  Condition: previous  ==  "chase"
  Condition: next  ==  "flee"
    -> Enemy: play "panic" barks
    -> Enemy: drop a smoke bomb
```

Checking `previous` alongside `next` lets you say "specifically when leaving chase for flee", which the destination state alone cannot express.

### 12. Turn-based phase manager

Step a match through turns and let the whole board read the current phase.

```
(Inspector) StateMachineBehavior.state = "player_turn"

On End turn pressed
  Condition: Match | StateMachineBehavior  Is In State  "player_turn"
    -> Match | StateMachineBehavior: Set State  "enemy_turn"

On Enemy done
  -> Match | StateMachineBehavior: Set State  "player_turn"

On Every Tick
  Condition: Match | StateMachineBehavior  Is In State  "player_turn"
    -> UI: enable the end-turn button
  Condition: Match | StateMachineBehavior  Is In State  "enemy_turn"
    -> UI: disable the end-turn button
```

Whose-turn-is-it lives in one value that the UI, input, and AI all consult.

### 13. Quest stage tracking with a reward on completion

Track a quest as a machine and hang the payoff off the entry transition.

```
(Inspector) StateMachineBehavior.state = "not_started"

On Talk to quest giver
  Condition: Quest | StateMachineBehavior  Is In State  "not_started"
    -> Quest | StateMachineBehavior: Set State  "in_progress"

On Item collected
  Condition: Quest | StateMachineBehavior  Is In State  "in_progress"
  Condition: Player has all items
    -> Quest | StateMachineBehavior: Set State  "complete"

On State Changed
  Condition: Quest | StateMachineBehavior  Is In State  "complete"
    -> Player: grant reward
    -> UI: mark quest done
```

Because On State Changed only fires on the real switch to `"complete"`, the reward is granted exactly once.

### 14. Stunned actor that ignores input

A stun is just another state, and Is In State does the gating for free.

```
On Hit by stun
  -> Player | StateMachineBehavior: Set State  "stunned"
  -> Player: start 2s stun timer

On Stun timer timeout
  -> Player | StateMachineBehavior: Set State  "idle"

On Every Tick
  Condition: Player | StateMachineBehavior  Is In State  "stunned"
    -> Player: do nothing (skip input and movement this frame)
```

No flags, no "can I move" boolean - if the state is `"stunned"`, every action-gating Is In State elsewhere simply reads false.

---

## Tips and common mistakes

- **The node is the machine - there is no machine id.** Every Set State, Is In State, and On State Changed acts on the `StateMachineBehavior` of the node it is placed on. If one node needs its own independent state, give it its own behavior. One machine, one node.
- **State names are strings, so a typo is a silent bug.** `"idle"`, `"Idle"`, and `" idle"` are three different states. If a branch never fires or a transition never lands, check the spelling and casing on the Set State and Is In State rows first. Pick a consistent style (short, lowercase, snake_case) and reuse the exact same literals.
- **Set State is safe to call every frame.** The built-in change guard means setting the state to the value it already holds does nothing and does not re-fire On State Changed. Lean on this - you do not need to wrap `Set State "run"` in an "am I already running" check; the machine handles it.
- **Put entry and exit effects in On State Changed, not in the transition rows.** The trigger fires exactly once per real switch and gives you `previous` and `next`, so it is the natural home for playing an animation, spawning an effect, or logging. Scattering those into the Set State rows risks running them on frames where nothing actually changed.
- **Transitions are not enforced - guard them yourself.** The pack lets any state move to any other. If a transition should only happen from a specific state, wrap the Set State in an `Is In State` for the state you are leaving. That one guard is how you turn "anything goes" into a real, rule-bound flow.
- **Set the starting state in the Inspector.** The `state` property defaults to `"idle"`; change it to match your machine (a door starts `"closed"`, a manager starts `"menu"`). The value you pick is what the machine holds before the first transition, and it is what your first-frame Is In State checks will see.
- **Only one state is active, so use that for mutual exclusion.** Because the machine can hold just one value, a set of Is In State branches is naturally exclusive - you never have to write "in run AND not in attack". Replace contradicting booleans (`is_jumping`, `is_attacking`) with one state and the impossible combinations disappear.
- **Read `previous` when the destination alone is not enough.** "Just entered flee" is `next == "flee"`; "entered flee specifically from chase" needs `previous == "chase"` too. Reach for `previous` whenever the reaction depends on where you came from, not just where you are going.
- **This pack tracks state; it does not run behavior.** State Machine holds and switches the current value - it does not move, animate, or attack on its own. Pair Is In State with your gameplay rows to act on the state, and use On State Changed to fire the one-shot effects.
