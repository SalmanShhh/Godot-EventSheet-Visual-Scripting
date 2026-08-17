# Timers, Waiting And Cooldowns

Everything in your game that is measured in seconds lives here. **Wait** pauses an event mid-flow.
**Every X Seconds** turns a per-frame trigger into a metronome. **Start Cooldown** and
**Cooldown Is Ready** give a dash, a heal or a special attack a recharge with no variable to declare.
**Buffer Press** forgives a player who pressed jump a fraction too early. **Tween Property** moves a
value smoothly instead of instantly. And underneath all of it sit the engine's own clocks: game time,
frame count, frames per second, time scale, and the wall-clock date.

These verbs are builtin vocabulary, so they are in the picker from any sheet with nothing to enable
and nothing to attach. They compile to plain Godot: `await get_tree().create_timer(...)`,
`Engine.time_scale`, `create_tween()`, `set_meta`. There is no runtime library behind them.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Delays inside a sequence** - flash, wait, then explode, written top to bottom in one event.
- **Ability cooldowns** - a dash that recharges, addressed by name from anywhere on the node.
- **Forgiving input** - a jump pressed just before landing that still fires.
- **Spawner cadence** - a wave every 3 seconds, or every 2 to 5 seconds so it never sounds metronomic.
- **Slow motion and hit-stop** - one row on the whole game's speed.
- **Respawning pickups** - a health pack that vanishes and comes back.
- **HUD readouts** - seconds left on a cooldown, current FPS, a run clock.
- **Smooth motion** - a panel that slides in, a bar that eases to its new value.
- **Timer nodes** - the classic Godot Timer, started, stopped and read from rows.
- **Heavy loops that must not stutter** - a per-frame millisecond budget that yields when spent.

## Core concepts

- **Waiting suspends the event, scheduling does not.** **Wait**, **Wait For Signal**,
  **Repeat With Delay**, **Vanish, Respawn In** and **Await If Over Budget** all suspend the event
  they sit in: the rows below them run later. **Call After Delay** and **Tween Callback** schedule
  something for later and let the current event carry straight on. Pick the one that matches how you
  want the rest of the row to behave.
- **Every X Seconds needs a per-frame trigger.** It accumulates frame time, so it only counts while
  the event it sits in is being evaluated. Under Every Frame it is a metronome; under a one-shot
  trigger it is a condition that never comes true.
- **A wait that can end two ways names itself.** Wait Until, Wait For All Of and Wait For Any Of each
  take a name, stamp their verdict under it, and hand the branch back as two ordinary conditions:
  **Wait Succeeded** and **Wait Timed Out**, on the next rows of the same event. The outcome is never
  a variable you have to remember to check, and two waits under one trigger stay unambiguous.
- **Retrying is a loop row, not a clever action.** **Retry Up To N Times** sits in the condition lane
  with the attempt as its actions, success is a nested condition whose action is **Stop Retrying**,
  and giving up is the sibling condition **Retries Exhausted**. The canvas nesting is the emitted
  nesting, so what you read is what compiles.
- **The two rate limits are opposites.** **At Most Every** is the leading edge - run now, then refuse
  until the window passes. **Poke** plus **Has Been Quiet For** is the trailing edge - run only once
  things have stopped happening. A debounce has to fire when nothing is happening, which is why no
  signal can back it and it needs a per-frame trigger.
- **Cooldowns and buffers are named, not declared.** **Start Cooldown** writes a deadline into node
  metadata keyed by the name you type, so a Start Cooldown in one event and a **Cooldown Is Ready**
  in a completely different event on the same node agree with no wiring and no variable between them.
- **A cooldown counts down, a buffer counts up.** Both store a deadline. A cooldown is ready when the
  deadline has passed; a buffered press is valid while the deadline is still ahead.
- **A cooldown that was never started is ready.** So the first use of an ability is always allowed
  without a "has it been used yet" flag.
- **Engine time is not game time.** **Game Time** counts seconds since the process started, including
  time spent in the menu. **Start Ramp Clock** exists precisely because a difficulty ramp should
  count from when the run began, not from when the executable launched.
- **Time Scale bends everything.** It slows physics, process and the timers built on them at once.
  It is a whole-game knob, not a per-node one.
- **A Timer node is a separate thing.** **Start Timer**, **Stop Timer**, **Is Timer Stopped** and
  **Get Time Left** are node-scoped verbs on a `Timer` in your scene. They have nothing to do with
  the named cooldowns above; use whichever suits the shape of the problem.

## Verb reference

Ships as is the template the row compiles to, so you can see exactly what lands in your `.gd`.
Where a template carries `{uid}`, the editor bakes a short per-row id into the name when you drop the
row, so two Every X Seconds conditions in the same script keep separate accumulators.

### Time: waiting and scheduling

| Verb | What it does | Ships as |
|------|--------------|----------|
| Wait | Pauses this event for a number of seconds before continuing | `await get_tree().create_timer({seconds}).timeout` |
| Wait For Signal | Pauses this event until a chosen signal fires, like a timer finishing | `await {signal_expression}` |
| Call After Delay | Schedules a method to run later without pausing this event | `get_tree().create_timer({seconds}).timeout.connect({callable})` |
| Repeat With Delay | Runs one statement several times with a pause between each | `for __rep_{uid}: int in maxi({times}, 0):` then `{do}` then an await of `{delay}` |
| Vanish, Respawn In | Hides this node, pauses its Area sensing, waits, brings it back and calls its `reset()` if it has one | `visible = false` … `await get_tree().create_timer(maxf({seconds}, 0.0)).timeout` … `visible = true` |

### Time: waits that can end two ways

Wait pauses for a clock and Wait For Signal for one signal. These three wait for a CHECK, for ALL of
several signals, or for the FIRST of them - and because each can end either way, each stamps its
verdict under the name you give it, which Wait Succeeded / Wait Timed Out read back on the next row.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Wait Until | Pauses this event until a check comes true, or until the give-up time passes | a `while not ({check})` loop with a deadline and `await get_tree().process_frame`, then a `set_meta` verdict |
| Wait For All Of | Pauses until every signal in the list has fired at least once | a one-shot `connect` per signal (its own arguments unbound) up front, then a wait on the remaining count |
| Wait For Any Of | Pauses until the first of several signals fires | the same one-shot connections, then a wait on an empty winner slot |
| Wait Succeeded | True when the named wait ended because what it waited for happened | `int(get_meta(&"__ef_wait_" + str({wait_name}).to_utf8_buffer().hex_encode(), 0)) == 1` |
| Wait Timed Out | True when the named wait gave up instead of finishing | `int(get_meta(&"__ef_wait_" + str({wait_name}).to_utf8_buffer().hex_encode(), 0)) == 2` |
| First To Finish | Which signal a Wait For Any Of raced finished first, as `Node.signal` | `str(get_meta(&"__ef_first_" + str({wait_name}).to_utf8_buffer().hex_encode(), ""))` |

### Loops: retrying until it works

| Verb | What it does | Ships as |
|------|--------------|----------|
| Retry Up To N Times | Runs this event's actions up to a number of attempts, so a nested Stop Retrying can end it | a loop row over a named `range()`, opening a three-state record, with `attempt` as its iterator |
| Retry Attempt Number | Which try this is, counting from 1 | `({loop_var} + 1)`, reading the retry loop's own variable |
| Stop Retrying | Ends the retry loop now because the attempt worked, and records that it worked | `set_meta(&"__ef_retry_" + str({retry_name}).to_utf8_buffer().hex_encode(), 2)` then `break` |
| Retries Exhausted | True when the loop above ran out of tries without a Stop Retrying | a helper that reads the three-state record and clears it in the same call |
| Wait Before Next Try | Pauses before the next attempt, waiting longer each time when growth is above 1 | `await get_tree().create_timer(maxf({delay}, 0.0) * pow(maxf({growth}, 1.0), maxf(float({attempt}) - 1.0, 0.0))).timeout` |

### Time: the settle-down pair

| Verb | What it does | Ships as |
|------|--------------|----------|
| Poke | Marks by name that something just happened | `set_meta(&"__ef_poke_" + str({poke_name}), Time.get_ticks_msec())` |
| Clear Poke | Forgets a poke so Has Been Quiet For stops firing | `set_meta(&"__ef_poke_" + str({poke_name}), 0)` |

### Time: repeating cadence

| Verb | What it does | Ships as |
|------|--------------|----------|
| Every X Seconds | True once each time the chosen number of seconds passes | `__every_{uid} >= maxf({seconds}, 0.001)` with a per-frame accumulator |
| Every X To Y Seconds | True once each time a random wait between the two lengths passes, re-rolled each firing | `__everyr_{uid}(maxf({min_seconds}, 0.001), maxf({max_seconds}, 0.001))` |
| Start Ramp Clock | Marks minute zero for this node's Ramped values | `set_meta(&"__ramp_zero", float(Time.get_ticks_msec()) / 60000.0)` |

### Time: cooldowns

| Verb | What it does | Ships as |
|------|--------------|----------|
| Start Cooldown | Starts or restarts a named cooldown lasting the given seconds | `set_meta(&"__ef_cool_" + str({name}), Time.get_ticks_msec() + int(maxf({seconds}, 0.0) * 1000.0))` |
| Cooldown Is Ready | True when the named cooldown has finished (one never started counts as ready) | `Time.get_ticks_msec() >= int(get_meta(&"__ef_cool_" + str({name}), 0))` |
| Cooldown Time Left | Seconds left on a named cooldown, or 0 when ready | `maxf(0.0, float(int(get_meta(&"__ef_cool_" + str({name}), 0)) - Time.get_ticks_msec()) / 1000.0)` |

### Time: input buffering

| Verb | What it does | Ships as |
|------|--------------|----------|
| Buffer Press | Remembers a press for a fraction of a second so an early input still counts | `set_meta(&"__ef_buffer_" + str({name}), Time.get_ticks_msec() + int(maxf({seconds}, 0.0) * 1000.0))` |
| Press Is Buffered | True while a recently buffered press is still valid | `Time.get_ticks_msec() <= int(get_meta(&"__ef_buffer_" + str({name}), 0))` |
| Clear Buffer | Forgets a buffered press, so one press never fires twice | `set_meta(&"__ef_buffer_" + str({name}), 0)` |

### Time: the engine's clocks

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Time Scale | Speeds up or slows the whole game (1 normal, 0.5 slow motion, 0 paused) | `Engine.time_scale = {scale}` |
| Time Scale | The current game speed | `Engine.time_scale` |
| Game Time | Seconds elapsed since the game started | `(Time.get_ticks_msec() / 1000.0)` |
| FPS | The current frames per second | `Engine.get_frames_per_second()` |
| Frame Count | How many frames have run since startup | `Engine.get_process_frames()` |
| Set Max FPS | Caps how many frames per second the game renders (0 is uncapped) | `Engine.max_fps = int({fps})` |
| Set Physics Rate | Changes how often physics steps per second (default 60) | `Engine.physics_ticks_per_second = int({fps})` |
| Date & Time Text | The system's current date and time as readable text | `Time.get_datetime_string_from_system()` |
| Unix Time | The current Unix timestamp in seconds | `Time.get_unix_time_from_system()` |

### Time: turning a number into clock text

These three are expressions, so they belong in a Label's text or anywhere else a string is wanted.
Format Time (mm:ss) is the one that turns a cooldown's remaining seconds, or a run clock, into the
text a HUD shows - there is no need to hand-roll the division.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Format Time (mm:ss) | Turns a number of seconds into a tidy `mm:ss` string | `("%02d:%02d" % [int({seconds}) / 60, int({seconds}) % 60])` |
| System Time String | The player's current clock time as text | `Time.get_time_string_from_system()` |
| System Date String | The player's current calendar date as text | `Time.get_date_string_from_system()` |

### Timer nodes

These four are node-scoped: they run on a `Timer` node you pick in the row's On node cell.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Start Timer | Starts the Timer, optionally overriding its duration (-1 uses its own wait_time) | `start({time})` |
| Stop Timer | Stops the Timer without firing it | `stop()` |
| Is Timer Stopped | True while the Timer is not running | `is_stopped()` |
| Get Time Left | Seconds remaining before the Timer fires | `time_left` |

### Tween

| Verb | What it does | Ships as |
|------|--------------|----------|
| Tween Property | Animates a node's property to a target value over time with an easing curve | `create_tween().tween_property({target}, {property}, {value}, {duration}).set_trans({transition}).set_ease({ease})` |
| Tween Callback | Waits a delay, then calls a method or function once | `create_tween().tween_callback({callable}).set_delay({delay})` |

Transition offers Linear, Sine, Quad, Cubic, Quart, Elastic, Back, Bounce, Expo and Circ; Ease offers
In, Out and In-Out.

### Performance: the frame budget

| Verb | What it does | Ships as |
|------|--------------|----------|
| Await Next Frame | Pauses this event until the next game frame, to spread work out | `await get_tree().process_frame` |
| Begin Frame Budget | Starts a per-frame millisecond budget for the loop that follows | `var __ace_budget_end := Time.get_ticks_usec() + int({ms} * 1000.0)` |
| Await If Over Budget | Yields to the next frame only if this frame's budget is used up, then re-arms it | `if Time.get_ticks_usec() >= __ace_budget_end:` … `await get_tree().process_frame` |

## Use cases

**1. A delay in the middle of a sequence.** The rows below Wait run after it, not before.

```
On enemy died
  -> play the death animation
  -> Wait  0.6
  -> spawn the loot drop
```

The emitted event reads exactly the way you wrote it:

```gdscript
func _on_enemy_died() -> void:
	await get_tree().create_timer(0.6).timeout
```

**2. Do something later without pausing this event.** Call After Delay connects the timer's timeout
to a callable and returns immediately, so the rows after it run this frame.

```
On bullet fired
  -> Call After Delay  3.0, queue_free
  -> play the muzzle flash
```

```gdscript
func _on_bullet_fired() -> void:
	get_tree().create_timer(3.0).timeout.connect(queue_free)
```

**3. A metronome.** Every X Seconds under a per-frame trigger.

```
Every Frame
  Condition: Every X Seconds  3.0
    -> Spawn Scene At  "res://enemy.tscn", spawn_point.position
```

**4. A cadence that does not sound like a machine.** Every X To Y Seconds re-rolls its wait each time
it fires, so the gaps vary.

```
Every Frame
  Condition: Every X To Y Seconds  2.0, 5.0
    -> play an idle bark
```

**5. An ability with a recharge.** The two halves do not need to be in the same event.

```
On dash pressed
  Condition: Cooldown Is Ready  "dash"
    -> Start Cooldown  "dash", 1.5
    -> dash the player forward
```

```gdscript
func _on_dash_pressed() -> void:
	if Time.get_ticks_msec() >= int(get_meta(&"__ef_cool_" + str("dash"), 0)):
		set_meta(&"__ef_cool_" + str("dash"), Time.get_ticks_msec() + int(maxf(1.5, 0.0) * 1000.0))
```

**6. A cooldown readout on the HUD.** Cooldown Time Left is 0 when the ability is ready, so the same
expression drives both the number and a filling bar.

```
Every Frame
  -> set DashLabel text = str(Cooldown Time Left("dash"))
  -> set DashBar value = 100 - Cooldown Time Left("dash") / 1.5 * 100
```

**7. Forgiving jump input.** Record the press when the button goes down, act where the jump actually
happens, then consume the buffer so it cannot fire twice.

```
On jump pressed
  -> Buffer Press  "jump", 0.12

Every Physics Tick
  Condition: Press Is Buffered  "jump"
  Condition: is_on_floor()
    -> Clear Buffer  "jump"
    -> apply the jump velocity
```

**8. Hit-stop.** Slow the whole game for a heartbeat, then put it back.

```
On heavy hit landed
  -> Set Time Scale  0.15
  -> Wait  0.08
  -> Set Time Scale  1.0
```

Wait itself is affected by Time Scale, so that 0.08 is 0.08 of slowed time. Use **Call After Delay**
instead if you want the restore to land at a fixed real interval.

**9. A pause menu.** Set Time Scale to 0 freezes physics and process together.

```
On pause pressed
  -> Set Time Scale  0
  -> show the pause panel

On resume pressed
  -> Set Time Scale  1.0
  -> hide the pause panel
```

**10. A pickup that comes back.** One row hides the node, stops its Area sensing while it is gone,
waits, restores both, and calls the node's own `reset()` if it defines one.

```
On body entered
  -> heal the player 25
  -> Vanish, Respawn In  10.0
```

**11. A burst.** Repeat With Delay is the for loop with an await inside, written as a single row.

```
On boss enrages
  -> Repeat With Delay  5, 0.2, fire_bullet()
```

```gdscript
func _on_boss_enrages() -> void:
	for __rep: int in maxi(5, 0):
		fire_bullet()
		await get_tree().create_timer(maxf(0.2, 0.001)).timeout
```

**12. Wait for something other than a clock.** Wait For Signal takes any signal expression.

```
On cutscene starts
  -> play the door animation
  -> Wait For Signal  $DoorAnim.animation_finished
  -> start the dialogue
```

**13. A Timer node you already have in the scene.** The classic Godot shape, driven from rows.

```
On round starts
  -> Start Timer  60.0   (On node: RoundTimer)

Every Frame
  -> set ClockLabel text = str(Get Time Left())   (On node: RoundTimer)

On player wins
  -> Stop Timer   (On node: RoundTimer)
```

**14. Only arm the timer if it is not already running.**

```
On checkpoint reached
  Condition: Is Timer Stopped   (On node: RoundTimer)
    -> Start Timer  -1   (On node: RoundTimer)
```

Passing -1 keeps the Timer's own `wait_time` from the Inspector.

**15. Slide a panel in.** Tween Property animates any property path, including nested ones like
`modulate:a`.

```
On menu opened
  -> Tween Property  MenuPanel, "position", Vector2(0, 0), 0.4, Tween.TRANS_BACK, Tween.EASE_OUT
```

**16. Fade something out and then free it.** Tween Callback is the delayed one-shot call.

```
On popup dismissed
  -> Tween Property  Popup, "modulate:a", 0.0, 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT
  -> Tween Callback  Popup.queue_free, 0.35
```

**17. A run clock that starts when the run does.** Game Time counts from process start, so stash a
zero point of your own.

```
On run starts
  -> set run_started_at = Game Time()

Every Frame
  -> set ClockLabel text = str(Game Time() - run_started_at)
```

**18. A difficulty ramp anchored to the run.** Start Ramp Clock marks minute zero for this node, so
the **Ramped** expression counts from the run rather than from launch.

```
On run starts
  -> Start Ramp Clock

Every Frame
  Condition: Every X Seconds  Ramped(2.0, -0.3, 0.5)
    -> spawn an enemy
```

The spawn gap starts at 2 seconds, shortens by 0.3 per minute, and never goes below 0.5.

**19. A performance readout while you are testing.**

```
Every Frame
  -> set DebugLabel text = str(FPS()) + " fps, frame " + str(Frame Count())
```

**20. Cap the frame rate on a menu screen** so a laptop fan stops screaming, then release it.

```
On main menu opened
  -> Set Max FPS  30

On game starts
  -> Set Max FPS  0
```

**21. Stamp a save with the real-world time.**

```
On game saved
  -> set save["saved_at"] = Date & Time Text()
  -> set save["saved_unix"] = Unix Time()
```

Unix Time is the one to compare against later (daily rewards, offline earnings); Date & Time Text is
the one to show the player.

**22. A heavy build loop that does not stutter.** Begin Frame Budget and Await If Over Budget must
sit in the SAME handler, with the second at the bottom of the loop body.

```
On level generation requested
  -> Begin Frame Budget  8.0
  -> Repeat 10000 times
       -> place one tile
       -> Await If Over Budget  8.0
```

The loop pauses at the next frame whenever it has spent 8ms, then carries on where it left off.

**23. Wait for a condition, with a deadline.** Wait Until pauses the event until a check comes true.
Give the wait a name, and the very next rows read which way it ended.

```
On Ready
  -> Show  "Loading..."
  -> Wait Until  "load", not loader.is_running, give up after 10
  Condition: Wait Timed Out  "load"
    -> Show  "Could not load in time"
  Condition: Wait Succeeded  "load"
    -> Show  "Ready"
```

The emitted wait is a plain polling loop with a deadline and a verdict, which is the part hand-written
versions leave out:

```gdscript
extends Node

var loading_done: bool = false


func _ready() -> void:
	var __wait_end_a: int = Time.get_ticks_msec() + int(maxf(10.0, 0.0) * 1000.0)
	var __wait_ok_a: bool = true
	while not (loading_done):
		if 10.0 > 0.0 and Time.get_ticks_msec() >= __wait_end_a:
			__wait_ok_a = false
			break
		await get_tree().process_frame
	set_meta(&"__ef_wait_" + str("load"), 1 if __wait_ok_a else 2)
	if int(get_meta(&"__ef_wait_" + str("load"), 0)) == 1:
		print("Ready")
```

**24. Reveal the level only when every stream has reported in.** Wait For All Of connects every
signal one-shot BEFORE it starts waiting, so a signal that fires while another is still being awaited
is not lost - the bug in every hand-written chain of awaits.

```
On Signal  boss_intro
  -> Wait For All Of  "gate", [ $Door.opened, $Camera.arrived, $Music.finished ], give up after 8
  Condition: Wait Succeeded  "gate"
    -> Start Dialogue
  Condition: Wait Timed Out  "gate"
    -> Skip to  "fight"
```

**25. A race, and the winner decides the ending.** Wait For Any Of carries on the moment the first of
its signals fires, and First To Finish names which one it was - as `Node.signal`, because the two
racers here carry a signal with the SAME name and only the owner tells them apart.

```
On Ready
  -> Wait For Any Of  "race", [ $Player.died, $Boss.died ]
  Condition: First To Finish ( "race" ) = "Boss.died"
    -> Go To Scene  "res://victory.tscn"
  Condition: First To Finish ( "race" ) = "Player.died"
    -> Go To Scene  "res://defeat.tscn"
```

**26. Try a slow thing until it works, waiting longer each time.** Retry Up To N Times is a loop
row, so the attempt is its actions and success is an ordinary nested condition whose action is Stop
Retrying. Because Wait Before Next Try SUSPENDS the event, the give-up is reported from inside the
loop with Report Failure and handled as its own On Failure Of event - a sibling Retries Exhausted
row would be reached while the retry is still running, and would answer for a loop that has not
finished. (Use case 27 shows the sibling form, which is right when nothing inside the loop waits.)

```
On Save Failed
  Condition: Retry Up To N Times  "save", 4
    -> Save Game
    -> Wait Before Next Try  0.5, growing 2.0, on try Retry Attempt Number
    Condition: Save Game succeeded
      -> Set text from  "Saved on try " & Retry Attempt Number
      -> Stop Retrying  "save"
    Condition: Retry Attempt Number = 4
      -> Report Failure  "save_game", "four tries, still no disk"

On Failure Of  ( verb_id, reason )
  Condition: Compare Text  verb_id = "save_game"
    -> Set text from  "Could not save: " & reason
```

**27. Place a room until one fits.** The same loop with no waiting at all stays fully synchronous,
so it is the procedural-placement loop as much as the disk retry - and because nothing suspends,
the loop has really finished by the time the sibling row beneath it is reached, which is what makes
Retries Exhausted the right give-up branch here.

```
On Ready
  Condition: Retry Up To N Times  "room", 30
    -> Place room at  Random Point In Rectangle ( map_rect )
    Condition: Room was placed
      -> Stop Retrying  "room"
  Condition: Retries Exhausted  "room"
    -> Print  "gave up placing room"
```

That compiles to a plain loop over a named range, plus the two small helpers the sheet synthesizes
for the shared three-state record - 0 for a retry that has never run, 1 while it is running, 2 once
a Stop Retrying has ended it:

```gdscript
extends Node

var placed: bool = false


func __retry_begin_r1(key: String, times: int) -> Array:
	set_meta(StringName("__ef_retry_" + key.to_utf8_buffer().hex_encode()), 1)
	return range(maxi(times, 1))


func __exhausted_r1(key: String) -> bool:
	var meta_key: StringName = StringName("__ef_retry_" + key.to_utf8_buffer().hex_encode())
	var state: int = int(get_meta(meta_key, 0))
	set_meta(meta_key, 0)
	return state == 1


func place_room() -> bool:
	return true


func _ready() -> void:
	for attempt: int in __retry_begin_r1(str("room"), int(30)):
		placed = place_room()
		if placed:
			set_meta(&"__ef_retry_" + str("room").to_utf8_buffer().hex_encode(), 2)
			break
	if __exhausted_r1(str("room")):
		print("gave up placing room")
```

**28. Search as you type, without refiltering on every keystroke.** Poke marks that something just
happened; the throttle limits how often the expensive work runs; Has Been Quiet For notices when the
typing stops.

```
Every Frame
  Condition: search_box.text has changed
    -> Poke  "search"
  Condition: At Most Every  0.25
    -> Filter the list by  search_box.text
  Condition: Has Been Quiet For  "search", 0.6
    -> Save Game
    -> Clear Poke  "search"
```

```gdscript
extends Node


func _process(_delta: float) -> void:
	set_meta(&"__ef_poke_" + str("search"), Time.get_ticks_msec())
	if (int(get_meta(&"__ef_poke_" + str("search"), 0)) > 0 and Time.get_ticks_msec() - int(get_meta(&"__ef_poke_" + str("search"), 0)) >= int(maxf(0.6, 0.0) * 1000.0)):
		set_meta(&"__ef_poke_" + str("search"), 0)
```

**29. Autosave once the player stops editing.** The trailing edge on its own: Poke on every change,
and let the save wait for two seconds of quiet.

```
On level edited
  -> Poke  "editing"

Every Frame
  Condition: Has Been Quiet For  "editing", 2.0
    -> Save Game
    -> Clear Poke  "editing"
```

**30. One hit sound instead of twenty.** At Most Every caps the rate whatever the event is reached by,
and it is hoisted to the end of the row's condition chain so the window is only spent when everything
else already held.

```
On body entered  body
  Condition: body is in group  "bullets"
  Condition: At Most Every  0.08
    -> Play Sound  "res://hit.ogg"
```

**31. A timeout another sheet can handle.** Every wait that gives up also reports on the sheet's
`verb_failed` signal, so a UI sheet can own the "could not load" message without knowing where the
wait lives. Declare the signal once with a Declare Signal row and the trigger is available.

```
Declare Signal  verb_failed(verb_id: String, reason: String)

On Ready
  -> Wait Until  "load", assets_ready, give up after 10

On Failure Of  verb_id, reason
  -> Show text from  "Could not load: " & reason
```

### Other use cases

**Combo window.** Buffer the second attack press for 0.3s and let the swing animation's end check Press Is Buffered, so a well-timed player chains hits and a mashing one does not.

**Invulnerability frames.** Start Cooldown "hurt" for 0.8 the moment damage lands and gate the damage event on Cooldown Is Ready "hurt", so a spike floor cannot drain the whole health bar in one touch.

**Bullet-time power-up.** Set Time Scale to 0.4 on pickup and Call After Delay a restore method five seconds later, so the effect ends on real time no matter how slow the world got.

**Traffic light cycle.** Three Every X Seconds rows at different intervals, or one Timer node restarted from its own timeout event with the next phase's duration.

**Idle-game offline earnings.** Store Unix Time on quit, compare it against Unix Time on load, and pay out the elapsed seconds capped at whatever your economy can stand.

## Tips and common mistakes

- **Every X Seconds under a one-shot trigger never fires.** It counts frame time from inside the event
  it lives in, so it needs a per-frame trigger (Every Frame, Every Physics Tick). This is
  the single most common "my timer does nothing" report.
- **Wait suspends everything below it in that event.** If the trigger can fire again while the event
  is still suspended, you get overlapping runs. Add the **Once At A Time** condition to the event and
  the second copy is skipped until the first finishes.
- **Repeat With Delay suspends too**, for the whole burst. The same Once At A Time guard applies, and
  its own description says so.
- **Call After Delay does not pause.** If you write it expecting the next row to run later, it will
  not: the next row runs this frame. Use Wait when you meant to suspend.
- **Cooldown names are plain strings and typos are silent.** `"dash"` in Start Cooldown and `"Dash"`
  in Cooldown Is Ready are two different cooldowns, and the second one has never been started, so it
  reads as ready forever.
- **A cooldown lives on the node, not the sheet.** Two sheets on the same node share the name. Two
  different enemies each have their own. That is usually what you want, but it is worth knowing
  before you name a cooldown `"attack"` on every enemy type.
- **Consume a buffer after acting on it.** Press Is Buffered stays true for the whole window, so an
  event that does not call Clear Buffer will fire on every frame of that window.
- **Time Scale 0 stops your Waits too.** A pause implemented with Set Time Scale 0 freezes any
  `create_timer` already ticking, which means a menu animation built on Wait will not run while
  paused. Tween nodes and `Timer` nodes have their own process-mode settings for exactly this.
- **Time Scale is global.** There is no per-node version here. Slowing one enemy means moving that
  enemy's own speed values, not this verb.
- **Game Time includes the main menu.** It measures the process, not the run. Subtract a stored zero
  point, or use Start Ramp Clock for the ramp case.
- **Ramped without Start Ramp Clock counts from engine start**, so a spawner that should begin at
  2-second gaps will already have ramped past that by the time the player presses Play.
- **Start Timer's -1 is not "no duration"** - it means "use the Timer node's own wait_time". Passing
  0 starts a timer that fires immediately.
- **Get Time Left, Start Timer, Stop Timer and Is Timer Stopped need a Timer node.** They are
  node-scoped verbs; pick the node in the row's On node cell. Pointing them at something that is not
  a Timer will not compile into working code.
- **Tween Property takes a property PATH as text**, not a value: `"position"`, `"modulate:a"`,
  `"scale"`. A misspelled path fails at runtime, not at compile time.
- **Each Tween Property row creates its own tween.** Two rows animating the same property at once
  will fight. Tween the node once, or stagger them with delays.
- **Await If Over Budget only compiles inside a handler that ran Begin Frame Budget**, because it
  reads the `__ace_budget_end` local that verb declares. Split across two events, it will not build.
- **Frame budgeting belongs in a one-shot trigger.** Inside a re-firing Every Frame trigger, overlapping
  suspended runs duplicate the work they were spreading out. The Time Slicer pack is the easy path if
  you want spreading without minding this yourself.
- **Vanish, Respawn In awaits**, so it suspends the event like Wait does. It also only touches
  `monitoring` when the node actually has it, so it is safe on a plain Sprite2D as well as an Area2D.
- **A wait with a give-up time of 0 waits forever.** That is deliberate for Wait For Any Of, whose
  whole job is often "whichever of these happens first". It is a hang for Wait Until, so leave the
  give-up time on unless you are certain the check comes true.
- **Wait Until polls once a frame.** Where a pack already emits a signal for the thing you are
  waiting on - Run In Background's On Done, Time Slicer's On Drained - wait for that signal instead.
  Wait For All Of and Wait For Any Of exist to COMBINE those signals, not to replace them.
- **Name every wait, and use the same name in the read-back.** `"load"` in the wait and `"Load"` in
  Wait Timed Out are two different waits, and the second one has never run, so neither outcome
  condition ever fires. This is the cooldown-name trap wearing a different hat.
- **A wait that never ran is neither succeeded nor timed out.** Both conditions read false, so rows
  under them stay quiet until the wait has actually happened once.
- **Any name will do, spaces and all.** `"boss intro"` is as good a wait name as `"boss_intro"`: the
  name is encoded into the metadata key rather than used as one, so nothing is quietly dropped.
- **Read Retries Exhausted exactly once per loop**, in a sibling row directly beneath it. Reading it
  clears the record, so a second reading of the same name in the same pass answers "not exhausted".
- **Retries Exhausted needs a retry that has FINISHED.** A retry that has never run is not
  exhausted, so nothing fires before the loop does - but a retry that WAITS inside itself is still
  running when the rows beneath it are reached, so pair that one with Report Failure and an On
  Failure Of event instead (use case 26).
- **The retry loop, Stop Retrying and Retries Exhausted must all share a name**, the same way Start
  Cooldown and Cooldown Is Ready do. A mismatch means the give-up branch never fires.
- **Retry Attempt Number reads the loop's own variable.** It ships as `attempt` because that is what
  the loop row ships as; rename the loop variable and change the cell to match.
- **Wait Before Next Try suspends**, so a retry that uses it is asynchronous for the whole run. Add
  the Once At A Time condition when the trigger can fire again mid-retry. Leave it out and the retry
  is fully synchronous, which is what the procedural-placement case wants.
- **Has Been Quiet For stays true until you Clear Poke.** It is a state, not an edge, so an event
  without a Clear Poke fires on every frame after the quiet begins.
- **A name that was never poked is never quiet**, which is what stops every debounce row in the
  project firing once at startup.
