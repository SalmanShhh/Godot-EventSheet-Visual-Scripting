# Triggers, Signals And When Rows Run

Every row in an event sheet needs a reason to run. That reason is the **trigger** at the top of the
event: the lifecycle moment, the scene-tree change, or the signal that hands the event its turn. This
guide covers the builtin vocabulary that answers "when?" - the per-frame and lifecycle triggers, the
scene-tree and Area signals, **On Signal** and **Emit Signal**, the runtime connect family, and the
gates that turn "every tick" into "once".

These rows are builtin: they are in the picker from any sheet, with no pack to enable and nothing to
attach. They compile to plain Godot callbacks and plain `signal.connect()` calls, with zero plugin
runtime left in the output.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Setup that runs exactly once** when a node enters the game.
- **Per-frame logic** that needs `delta`, and physics logic that needs the fixed step.
- **Logic that must come last**, after every other node already moved this frame.
- **Trigger zones** - a player walking into an Area, a hitbox touching a hurtbox.
- **Custom events** you broadcast yourself, with arguments, and react to from another sheet.
- **Wiring that happens at runtime**, when the node you want to listen to did not exist at startup.
- **Listening to a whole group at once** without holding a reference to any of its members.
- **Edge detection** - "the tick it became true", not "while it is true".
- **First-run moments** - a tutorial hint that fires once per install and never again.
- **Async events that must not stack**, where a run with a Wait in it is still going next frame.

## Core concepts

- **The trigger is the event's turn.** A bare event with no trigger emits nothing. The trigger decides
  which Godot function or signal handler the event's rows land in.
- **Lifecycle triggers become callbacks.** **On Ready** becomes `_ready()`, **Every Frame** becomes
  `_process(delta)`, **Every Physics Tick** becomes `_physics_process(delta)`. That is why `delta` is a
  usable value inside those events and not inside **On Ready**.
- **Signal triggers become a connection plus a handler.** The compiler emits the handler function and,
  in `_ready`, the `source.signal_name.connect(handler)` line that arms it. Nothing is polled.
- **Post-tick is not "another frame trigger".** **After Every Frame (post-tick)** connects to the
  SceneTree's `process_frame` signal, which fires once after *every* node has processed. That is the
  place for a camera that must follow after movement, or for end-of-frame cleanup.
- **Every event of the same trigger shares one handler.** Two events both under **Every Frame** compile
  into one `_process`, in sheet order. Ordering on the sheet is ordering in the code.
- **A condition can also be a gate.** **Trigger Once**, **Has Changed**, **Was Recently True**,
  **Once At A Time** and **Only Once Ever** are conditions, not triggers: they sit in the condition lane
  of an event that already has a trigger, and narrow "every tick" down to the tick you meant.
- **An outcome is something that happens, so it is a trigger.** An action that refuses announces it
  with **Report Failure**, and **On Failure Of** heads the event that recovers - which may sit anywhere
  on the sheet, far from the row that made the attempt. This is the shape the shipped packs already use
  for On Save Failed and On Purchase Refused, shared so any action can raise it.
- **A trigger's payload is the signal's own arguments.** `verb_failed(verb_id, reason)` puts both on
  the row, in scope as values. Nothing stores a "last failure" for you to fetch, which is also why
  two failures in one frame can never be confused. Narrow the row to one action with an ordinary
  condition on `verb_id`, exactly as you would filter any other payload.
- **Once per ROW and once per THING are different questions.** **Trigger Once** is per row instance,
  so inside a For Each it fires for the first item only. **Only Once Per Node**, **Only Once Per Name**
  and **Only Once This Scene Load** key the memory by the thing, which is what the row usually means.
- **Signals are the decoupling tool.** **Emit Signal** broadcasts without knowing who is listening;
  **On Signal** listens without knowing who emits. That pair is how two sheets talk without either one
  holding a path to the other.

## Reference tables

On the canvas these read as sentences, with the parameter values drawn in bold:

- On body entered **body**
- Emit signal **died**
- connect **self**.**pressed** -> **_on_pressed** (if not already)
- **is_on_floor()** was true within **0.1**s

### Run Context - the triggers that mark out a frame

| Name | What it does | Ships as |
|------|--------------|----------|
| On Ready | Runs once when this node first enters the scene, ideal for setup and initial values. | the `_ready()` callback |
| Every Frame | Runs every rendered frame, perfect for continuous movement, timers, or polling input. | the `_process(delta: float)` callback |
| Every Physics Tick | Runs every fixed physics step, the right place for physics-based movement and forces. | the `_physics_process(delta: float)` callback |
| After Every Frame (post-tick) | Runs once AFTER every node has processed this frame. | a handler connected to `get_tree().process_frame` |
| After Every Physics Tick | Runs once AFTER every node has finished its physics step this tick. | a handler connected to `get_tree().physics_frame` |
| On Editor Run | Runs inside the editor while building, useful for tool scripts and live previews. | the `_run()` callback |

### Run Context - the gates that turn "every tick" into "once"

| Name | What it does | Ships as |
|------|--------------|----------|
| Trigger Once | True only on the first tick each time the event's other conditions become true, and again after they have gone false. | `__trigger_once_{uid}()`, backed by a per-instance tick counter |
| Has Changed | True on any tick where the watched **Value** differs from the tick before. | `__has_changed_{uid}({value})` |
| Was Recently True | True while the watched **Value** is true, and **For Seconds** after it stops - coyote time. | `__recent_{uid}(bool({value}), maxf({window}, 0.0))` |
| Once At A Time | Skips the event while a previous run is still going, awaits included. | `not __busy_{uid}` |
| Only Once Ever | True exactly once, ever, even across closing the game - keyed by **Name**. | `__once_ever_{uid}({key})` |
| Forget First Time | Resets an Only Once Ever memory so it fires again. | a `ConfigFile` write of `false` into the `OnceEver` section of `user://remembered.cfg` |
| On Group Emptied | True on the single tick a watched **Group**'s last member leaves or dies. | `__group_emptied_{uid}({group})` |
| On Group Gains First Member | True on the single tick a watched **Group** goes from empty to holding something. | `__group_first_{uid}({group})` |

### Run Context - once per THING, and the two rate limits

Trigger Once is per ROW instance and Only Once Ever is per machine forever. These sit in between: the
memory is keyed by the node, by a name, or by this scene load. At Most Every and Has Been Quiet For
are the two rate limits - the leading edge and the trailing edge.

| Name | What it does | Ships as |
|------|--------------|----------|
| Only Once Per Node | True the first time this row is reached for each **Node**, and never again for that node. | `__once_node_{uid}({node}, str({label}))`, a helper over the node's own metadata |
| Only Once Per Name | True the first time this row is reached for each **Name**, kept on this node. | `__once_name_{uid}(str({key}))` |
| Only Once This Scene Load | True the first time per **Name** in this scene load, and again after a reload. | `__once_scene_{uid}(str({key}))`, over a per-row Dictionary member |
| Forget Once For | Clears an Only Once Per Node / Per Name memory so the row fires again. | a guarded `remove_meta` of `__ef_once_{label}` on the node |
| At Most Every | Lets this event run at most once every so many **Seconds**, however often it is reached. | `__throttle_{uid}(maxf({seconds}, 0.0))`, hoisted to the end of the condition chain |
| Has Been Quiet For | True once a poked **Name** has stopped being poked for **Seconds**. | a comparison of `Time.get_ticks_msec()` against the `__ef_poke_{name}` stamp |

### Run Context - outcomes: what happened to an action

GDScript has no exceptions, so an outcome is announced rather than thrown. One signal per outcome
carries the action's name and the reason as its ARGUMENTS, which arrive on the trigger row as
`verb_id` and `reason`. Declare the signal once with a Declare Signal row.

| Name | What it does | Ships as |
|------|--------------|----------|
| On Failure Of | Runs when a verb reports that it refused; hands you **verb_id** and **reason**. | a handler connected to the sheet's `verb_failed(verb_id: String, reason: String)` |
| On Success Of | Runs when a verb reports that it finished; hands you **verb_id**. | a handler connected to the sheet's `verb_succeeded(verb_id: String)` |
| Report Failure | Announces that a **Verb** refused, with a **Reason** a player can read. | `if has_signal(&"verb_failed"):` then `emit_signal(&"verb_failed", str({verb}), str({reason}))` |
| Report Success | Announces that a **Verb** finished. | the same guarded emit of `verb_succeeded` |
| Wait Succeeded | True when the named wait ended because what it waited for happened. | `int(get_meta(&"__ef_wait_" + str({wait_name}), 0)) == 1` |
| Wait Timed Out | True when the named wait gave up instead of finishing. | `int(get_meta(&"__ef_wait_" + str({wait_name}), 0)) == 2` |
| First To Finish | Which signal a Wait For Any Of raced finished first, as `Node.signal`. | `str(get_meta(&"__ef_first_" + str({wait_name}).to_utf8_buffer().hex_encode(), ""))` |

### General Conditions

| Name | What it does | Ships as |
|------|--------------|----------|
| Always | Always true, so its actions run every time the event is checked. | `true` |

### Signals / Scene / Input - the signal triggers

| Name | What it does | Ships as |
|------|--------------|----------|
| On Signal | Runs whenever the named signal fires. Takes **Signal Name** and an optional **Arguments** signature. | a handler connected to that signal |
| On Body Entered | Runs when a physics body enters this 2D Area. Hands you **body**. | the `body_entered` signal of an Area2D |
| On Body Exited | Runs when a physics body leaves this 2D Area. Hands you **body**. | the `body_exited` signal of an Area2D |
| On Area Entered | Runs when another 2D Area overlaps this one. Hands you **area**. | the `area_entered` signal of an Area2D |
| On Area Exited | Runs when another 2D Area stops overlapping this one. | the `area_exited` signal of an Area2D |
| On Timeout | Runs when this Timer counts down to zero. | the `timeout` signal of a Timer |
| On Animation Finished | Runs when an animation finishes playing. Hands you **anim_name**. | the `animation_finished` signal of an AnimationPlayer |
| On Tree Entered | Runs when this node is added into the scene tree. | the `tree_entered` signal of a Node |
| On Tree Exiting | Runs just before this node leaves the scene tree, a good spot for cleanup. | the `tree_exiting` signal of a Node |
| On Tree Exited | Runs after this node has been removed from the scene tree. | the `tree_exited` signal of a Node |
| On Renamed | Runs when this node's name changes in the scene tree. | the `renamed` signal of a Node |
| On Child Entered Tree | Runs when a child node is added beneath this one. Hands you **node**. | the `child_entered_tree` signal of a Node |
| On Close Requested | Runs when the player clicks the window's close button or asks to quit. | the `close_requested` signal of the root window |
| Emit Signal | Fires a signal so other events or nodes can react. Takes **Signal Name** and optional **Arguments**. | `{signal_name}.emit({args})` |

### Input triggers and tests

| Name | What it does | Ships as |
|------|--------------|----------|
| On Input | Runs on every input event the node receives. | the `_input(event: InputEvent)` callback |
| On Unhandled Input | Runs on input no UI element consumed, ideal for gameplay controls that ignore menu clicks. | the `_unhandled_input(event: InputEvent)` callback |
| Is Action Pressed | True while the named **Action** is held down, for continuous controls. | `Input.is_action_pressed(&{action})` |
| On Action Just Pressed | True only on the frame the **Action** was first pressed. | `Input.is_action_just_pressed(&{action})` |
| On Action Just Released | True only on the frame the **Action** was let go. | `Input.is_action_just_released(&{action})` |

### Helpers - wiring signals at runtime

| Name | What it does | Ships as |
|------|--------------|----------|
| Connect Signal | Wires a **Source**'s **Signal** to run a **Callable** whenever it fires. | `{source}.{signal}.connect({callable})` |
| Connect Signal (if not already) | The same wiring, guarded, so re-running never stacks duplicate handlers. | `if not {source}.{signal}.is_connected({callable}):` then the connect |
| Connect Signal (one-shot) | Wires a signal to run ONCE; the connection drops itself after it fires. | `{source}.{signal}.connect({callable}, CONNECT_ONE_SHOT)` |
| Disconnect Signal | Stops a signal from calling a method. | `{source}.{signal}.disconnect({callable})` |
| Signal Is Connected | True when a **Callable** is currently hooked up to that signal. | `{source}.{signal}.is_connected({callable})` |
| Emit Signal On | Fires a signal on another object, not just on self. | `{target}.{signal}.emit({args})` |
| Connect Group Signal | Listens to a **Signal** on every current member of a **Group** at once, with no reference to any of them. Guarded, so re-runs are safe. | a `for` over `get_tree().get_nodes_in_group({group})` with an `is_connected` guard around the connect |
| Disconnect Group Signal | Stops listening to a signal on every current member of a group. | the same loop around a guarded `disconnect` |

## Use cases

**1. Set up a node the moment it exists.**

```
On Ready
  -> Set value  health = 100
  -> Set value  score = 0
```

**2. Move something every frame, using the frame's own delta.**

```
Every Frame
  -> Add To Property  self.position += Vector2(1, 0) * 200.0 * delta
```

**3. Do physics work on the physics clock, not the render clock.**

```gdscript
func _physics_process(delta: float) -> void:
	velocity.y += 980.0 * delta
	move_and_slide()
```

That is what an **Every Physics Tick** event holding **Apply Gravity** and **Move And Slide** emits.
Use **Every Frame** for anything visual, and **Every Physics Tick** for anything that touches bodies,
velocities or forces.

**4. Follow the player with a camera, after the player has already moved.**

```
After Every Frame (post-tick)
  -> Set Property  self.global_position = $Player.global_position
```

Under **Every Frame** the camera might read the player's position before the player updates it, which
is exactly the one-frame lag that reads as jitter. Post-tick runs after every node's `_process`, so the
value it reads is final.

**5. A trigger zone that reacts to whatever walked in.**

```
On Body Entered ( body )
  Condition: Expression Is True  body.is_in_group("player")
    -> Emit Signal  checkpoint_reached
```

The **body** the signal hands you is a real value in the event, so you can test it and pass it on.

**6. Broadcast a custom event with a value on it.**

```
On enemy hit
  -> Emit Signal  died  ( score_value )
```

```gdscript
died.emit(score_value)
```

Declare the signal itself in the sheet's signal block, then any sheet can listen for it.

**7. Listen for that custom event somewhere else.**

```
On Signal  "died"  ( amount: int )
  -> Add to  score += amount
```

The **Arguments** field is the signature the handler receives. Leave it empty for a signal that carries
nothing; fill it in as `amount: int` (or `x: float, y: float`) when the signal carries values, or the
handler will not accept them.

**8. Wire something up that did not exist at startup.**

```
On enemy spawned
  -> Connect Signal (if not already)   source = spawned_enemy, signal = died, callable = _on_enemy_died
```

Use the guarded form as your default. Plain **Connect Signal** run twice stacks a second handler and
the response fires twice - the classic "my handler runs forty times" bug.

**9. A connection that fires once and cleans itself up.**

```
On cutscene started
  -> Connect Signal (one-shot)   source = $AnimationPlayer, signal = animation_finished, callable = _on_cutscene_done
```

**10. React to every enemy dying without holding a single enemy reference.**

```
On Ready
  -> Connect Group Signal   group = "enemies", signal = died, callable = _on_any_enemy_died
```

This wires the CURRENT members of the group. Nodes that join later are not wired, so re-run the row
when a wave spawns, or wire each enemy from its own spawn event.

**11. Stop listening when the fight ends.**

```
On wave cleared
  -> Disconnect Group Signal   group = "enemies", signal = died, callable = _on_any_enemy_died
```

**12. Do something on the tick a condition becomes true, not every tick after.**

```
Every Frame
  Condition: Is On Floor
  Condition: Trigger Once
    -> Play Sound
```

The landing sound plays once when the character touches the ground, and re-arms once it leaves it
again. **Trigger Once** is hoisted to the end of the condition chain no matter which cell it sits in,
so "was I reached last tick?" really does mean "were the other conditions already true last tick?".

**13. Watch a value and react only when it moves.**

```
Every Frame
  Condition: Has Changed   value = health
    -> Set Text  "HP: " + str(health)
```

The very first tick only seeds the watcher and returns false, so a health bar does not flash on frame
one.

**14. Forgiving jumps (coyote time), with no timer of your own.**

```
Every Physics Tick
  Condition: On Action Just Pressed   "jump"
  Condition: Was Recently True   value = is_on_floor(), window = 0.1
    -> Set Velocity Y  -400.0
```

The player can still jump for a tenth of a second after walking off a ledge. This needs a per-frame
trigger, because that is what stamps the moment.

**15. An event with a Wait in it that must never overlap itself.**

```
Every Frame
  Condition: Once At A Time
    -> Play Sound
    -> Wait  0.5
    -> Spawn Scene At   "res://enemy.tscn", Vector2(0, 0)
```

A run that awaits counts as still going until the last await completes, so a per-frame trigger with a
Wait inside runs one copy at a time instead of stacking a new one every frame.

**16. A tutorial hint that fires once per install.**

```
On Ready
  Condition: Only Once Ever   "hint_dash"
    -> Show
    -> Set Text  "Press Shift to dash"
```

The memory lives in `user://remembered.cfg`, the same file the variable option Remember Between Runs
uses. While testing, drop a **Forget First Time** row with the same **Name** to reset it - it takes
effect on the next run, because rows already running keep their cached answer for the session.

**17. The wave director, without counting nodes by hand.**

```
Every Frame
  Condition: On Group Emptied   "enemies"
    -> Add to  wave += 1
    -> Call Function  spawn_wave(wave)
```

A group that is already empty at startup never fires it, so the first wave still has to be started by
you.

**18. Save before the window closes.**

```
On Ready
  -> Handle Quit Myself   Intercept (handle it myself)

On Close Requested
  -> Call Function  save_game()
  -> Quit Game
```

By default the window's X quits instantly. **Handle Quit Myself** set to Intercept makes the close wait
for your handler, which then quits explicitly.

**19. Clean up as a node leaves the tree.**

```
On Tree Exiting
  -> Disconnect Signal   source = $Boss, signal = died, callable = _on_boss_died
```

**On Tree Exiting** fires while the node is still in the tree, so paths still resolve. **On Tree
Exited** fires after removal, when they no longer do.

**20. Gameplay input that ignores menu clicks.**

```
On Unhandled Input
  Condition: On Action Just Pressed   "fire"
    -> Call Function  fire_weapon()
```

If a Control consumed the click, this event never runs - which is what you want for a game that also
has a HUD.

**21. Recovery as its own event.** GDScript has no exceptions, so an action that refuses has to
announce it. Report Failure raises one shared signal, and On Failure Of heads the event that handles it - which
may sit anywhere on the sheet, far from where the attempt was made.

```
Declare Signal  verb_failed(verb_id: String, reason: String)

On Action  "save" pressed
  -> Save Game

On Failure Of  verb_id, reason
  Condition: verb_id = "save_game"
    -> Show text from  "Could not save: " & reason
    -> Wait  2
    -> Save Game To Slot  2
```

The reason is not something to go looking for: it is the signal's own second argument, in scope on
the row the moment it fires.

```gdscript
extends Node

signal verb_failed(verb_id: String, reason: String)


func _ready() -> void:
	verb_failed.connect(_on_verb_failed)


func _on_verb_failed(verb_id: String, reason: String) -> void:
	if verb_id == "save_game":
		print("Could not save: " + reason)
```

**22. An action you wrote this morning can refuse in the same words.** Report Failure is an ordinary
action, so any row of yours can raise the outcome instead of returning a null nobody checks.

```
On Ready
  -> Set local variable  data = Load Resource  "res://mods/pack.tres"
  Condition: data is null
    -> Report Failure  "load_resource", "mod pack missing"

On Failure Of  verb_id, reason
  Condition: verb_id = "load_resource"
    -> Log Value  "mods" = reason
    -> Use fallback pack
```

**23. Confirmation, the same shape.** Report Success and On Success Of are the pair for the happy
path, so the "Saved" toast lives in the UI sheet rather than being copied into every save row.

```
Declare Signal  verb_succeeded(verb_id: String)

On Success Of  verb_id
  Condition: verb_id = "save_game"
    -> Show  "Saved"
```

**24. Initialise each spawned enemy exactly once.** Trigger Once is per ROW, so inside a For Each it
fires for the first item and never for the rest. Only Once Per Node is per THING, which is what this
row actually means.

```
Every Frame
  Condition: For Each  enemy in group "enemies"
    Condition: Only Once Per Node  ( enemy, "init" )
      -> Apply stat sheet to  enemy
      -> Set property  enemy.modulate = team_color
```

```gdscript
extends Node


func __once_node_q(node: Object, label: String) -> bool:
	if node == null:
		return false
	var key: StringName = StringName("__ef_once_" + label)
	if node.has_meta(key):
		return false
	node.set_meta(key, true)
	return true


func _process(_delta: float) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if __once_node_q(enemy, str("init")):
			enemy.modulate = Color.RED
```

**25. One discovery line per item type.** Only Once Per Name keys the memory by a name instead of a
node, so a hundred torches share one "you found a torch" line without a flag variable each.

```
On Focus Changed
  Condition: Only Once Per Name  ( focused.item_id )
    -> Show  "New item type discovered!"
```

**26. A welcome line that comes back when the level does.** Only Once This Scene Load is forgotten
when the scene reloads, which is the difference between it and Only Once Ever.

```
On Ready
  Condition: Only Once This Scene Load  ( "welcome" )
    -> Show  "Welcome to the caves"
```

**27. Recycle an instance and let it initialise again.** Forget Once For clears the memory that lives
on the node, so a pooled enemy coming back out is a fresh one.

```
On pool item reset  item
  -> Forget Once For  ( item, "init" )
```

### Other use cases

**Hitbox and hurtbox pairs.** On Area Entered on the hurtbox, with a group test on the incoming **area**, keeps damage wiring to one event per fighter instead of one per attack.

**Spawn counters from the tree itself.** On Child Entered Tree under a spawn container counts what actually exists, so a spawner that failed cannot inflate the count.

**Debug renaming.** On Renamed paired with Set Node Name turns runtime renames into a live label, useful while tracking down which pooled instance is which.

**A one-shot intro.** Connect Signal (one-shot) to the AnimationPlayer's animation_finished lets a title sequence hand control to the menu without a state flag or a polling condition.

**Editor-time previews.** On Editor Run drives a tool script that lays out or regenerates content in the editor, using the same rows as the game.

## Tips and common mistakes

- **On Failure Of and On Success Of need their signal declared.** Add a Declare Signal row for
  `verb_failed(verb_id: String, reason: String)` (and `verb_succeeded(verb_id: String)`) to the sheet
  that listens. Without it the compiler has nothing to connect to and the trigger never fires.
- **Report Failure on a sheet with no declared signal does nothing.** That is deliberate - the row is
  always droppable and never errors - but it also means a missing Declare Signal row is silent. If a
  recovery event is not running, check the declaration first.
- **The outcome signals are the sheet's own.** They fire on the node the sheet is attached to, so the
  handler belongs on that node's sheet. To reach another node, connect the signal there with the
  shipped Connect Signal, or route it through an autoload bus.
- **Narrow the trigger with a condition, not a second signal.** One `verb_failed` carries every action,
  and the row that only cares about saving puts `verb_id = "save_game"` underneath. Two saves in one
  sheet stay unambiguous because the name is the payload.
- **Trigger Once inside a For Each is almost always the wrong condition.** It is per row, so it fires for
  the first item and never for the rest. Only Once Per Node is the one that means "once per thing".
- **Only Once Per Node keeps its memory ON the node**, so it survives reparenting and a pooled
  instance remembers it was already initialised. Clear it with Forget Once For in the pool's reset.
- **Only Once This Scene Load is forgotten on Restart Layout**, unlike Only Once Ever, which persists
  to `user://remembered.cfg` across runs. Pick by how long you want the memory to last.
- **At Most Every is a rate, not an edge.** It lets the event run once per window however often it is
  reached; Trigger Once fires on the rising edge and never again until the conditions go false.
- **Has Been Quiet For needs a per-frame trigger**, because it has to be asked repeatedly while
  nothing is happening. That is the whole point of a debounce, and no signal can back it.
- **A bare event with no trigger emits nothing.** If a row seems to do nothing at all, check the event
  actually has a trigger and not just conditions.
- **`delta` only exists where the callback provides it.** It is a real value under **Every Frame** and
  **Every Physics Tick**. Under **On Ready** or a signal trigger there is no `delta`, which is why the
  gravity and acceleration actions default their **Delta** parameter to `delta` and expect a per-frame
  trigger.
- **Plain Connect Signal is not idempotent.** Running it twice connects twice and the handler fires
  twice. Prefer **Connect Signal (if not already)** anywhere the row can run more than once.
- **Connect Group Signal only wires current members.** A node that joins the group afterwards is not
  connected. Re-run the row, or connect on spawn.
- **The stateful gates need a per-frame trigger.** **Has Changed**, **Was Recently True**, **On Group
  Emptied**, **On Group Gains First Member** and **Every X Seconds** all compare against the previous
  tick or accumulate time in a prelude that runs with the event. Under a one-shot trigger they have
  nothing to compare against.
- **Trigger Once on its own fires exactly once.** It is the other conditions in the row that make it
  re-arm. That is a feature, not a bug, but it surprises people who put it in an empty condition lane
  expecting "once per second".
- **Only Once Ever is per name, per machine.** Two rows with the same **Name** share one memory, and
  the first of them to run consumes it. Give each hint its own name.
- **Forget First Time takes effect next run.** The condition caches its answer in a member after the
  first read, so resetting the file mid-session does not re-arm a row that already answered.
- **A signal-backed trigger needs its Signal row, or the event is dead and silent.** On Failure Of,
  On Success Of, On Scene Spawned and On Data File Changed each bind to a signal your sheet declares.
  Leave the declaration out and the sheet still compiles - the handler is emitted, nothing is
  connected to it, and the event simply never runs. The Project Doctor reports it by name, which is
  the only warning you get.
- **Emit Signal takes a bare identifier**, not a quoted string: `died`, not `"died"`. The emitted form
  is the modern `died.emit(...)`.
- **On Signal's Arguments field is a signature, not values.** Write `amount: int`, not `5`. Leaving it
  empty on a signal that carries arguments means the handler cannot see them.
- **Post-tick is not a substitute for ordering.** It runs after every node, so two post-tick events
  still run in sheet order relative to each other. If two of them fight over the same value, the fix is
  which one writes it, not which trigger they use.
- **On Tree Exiting and On Tree Exited are not the same moment.** Exiting still has the tree, exited
  does not. Anything that resolves a path belongs in Exiting.
