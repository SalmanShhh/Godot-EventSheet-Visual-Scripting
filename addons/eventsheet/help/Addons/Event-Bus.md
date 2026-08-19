# Event Bus

**Event Bus** ships as the `EventBus` autoload - a game-wide message board addressed by **name**
instead of by node. One row broadcasts a channel ("boss_defeated") with a record of details; any
sheet anywhere answers it with the **On Event** trigger and reads the channel and the details
straight off the row, because the trigger is a real Godot signal and its arguments are the row's
captured context.

The action nobody else has is **Wait For Event**: it suspends an event until a named message arrives
or a give-up time passes, so a cutscene, a tutorial gate and a wave director stop needing a state
variable each. Its outcome is read back by two ordinary conditions, never by a flag you have to
remember to check.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Achievements and analytics** reacting to every "the player did a thing" with no reference into gameplay.
- **Cutscenes and tutorials**, where Wait For Event replaces a flag plus a polling condition.
- **A HUD that listens** for a money channel and never holds the wallet.
- **Cross-scene coordination** by a director while scenes come and go.
- **Boss fights** announcing phase changes that music, lighting and the arena each answer separately.
- **Pick-ups and shops** telling the quest log something happened without knowing a quest exists.
- **Optional systems** that simply are not there in some builds, and cost nothing when they are absent.
- **Debugging**, since Print Event Bus Report shows who broadcast what this session.

## Core concepts

- **A channel is a name, not an object.** That is the whole difference from a signal. A listener can
  subscribe before the broadcaster is spawned and stay subscribed after it is freed, which is exactly
  the case group signals cannot serve.
- **The payload arrives as the trigger's own arguments.** On Event gives the row `channel` and
  `payload`. Read a detail by key on the row itself. Nothing is stored as a "last value", which is
  why two broadcasts in one frame each read correctly.
- **There is one signal behind the whole bus.** Filtering to a channel is the row's channel field, or
  an ordinary condition on the captured value underneath it.
- **Wait For Event suspends the event it is in**, and only that event. The rows below it run when it
  resolves; sibling events keep running the whole time.
- **A wait's outcome is a condition, not a variable.** Wait For Event Succeeded and Wait For Event
  Timed Out are read on the rows under the wait, and each names the channel it asks about.
- **Listen Once For Event unsubscribes itself.** It is the CONNECT_ONE_SHOT idea as a row: a delayed
  hint can neither leak nor fire twice.

## Setup

1. Open **Sheet > New Behaviour Addon…** and pick Event Bus, or use **Tools > Register Autoload** on
   `res://eventsheet_addons/event_bus/event_bus_addon.gd`. It registers as `EventBus`.
2. Nothing else. There is no node to place and no wiring: every sheet in the project can reach the
   vocabulary the moment the autoload exists.
3. Agree on channel names with yourself early. `boss_defeated` and `money_changed` are good names;
   `event1` is not.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, exactly as the
rows draw them:

- Broadcast event **"boss_defeated"** with **{ "title": "The Warden", "xp": 500 }**
- Wait for event **"door_opened"**, give up after **8**s
- Listen once for **"tutorial_done"**, then call **"_on_bus_event"** on **HintPanel**

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Broadcast Event | channel, payload | Sends a named message to everyone listening, with a record of details. Anyone anywhere can answer it with On Event. |
| Wait For Event | channel, seconds | Suspends this event until the message arrives or the give-up time passes. 0 waits forever. Read the outcome with the two conditions below. |
| Listen Once For Event | channel, on_node, method_name | Asks for ONE delivery and then unsubscribes itself. The method is called with the channel and the payload. |
| Broadcast To Group | group, method_name, payload | Calls a named method on every member of a group that has it, handing over the payload. The fan-out half of the bus. |
| Clear Event Log | (none) | Empties the record of what has been broadcast this session. Counters are kept. |
| Print Event Bus Report | (none) | Prints every broadcast recorded this session to the output, newest last. A diagnostic, not a shipping row. |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Wait For Event Succeeded | channel | Whether the most recent Wait For Event on this channel ended because the message arrived. |
| Wait For Event Timed Out | channel | Whether it gave up instead. The recovery branch. A wait still running is neither - it has not given up yet. |
| Event Was Broadcast This Frame | channel | Whether this channel was broadcast during the frame being processed now. |
| Event Was Ever Broadcast | channel | Whether this channel has been broadcast at least once since the game started. |

### Expressions

| Expression | Returns | Description |
|-----------|---------|-------------|
| Event Broadcast Count | number | How many times this channel has been broadcast since the game started. |
| Event Bus Report | String | Everything broadcast this session as text, one "channel  payload" line each. |

### Triggers

| Trigger | Fires with | Description |
|---------|-----------|-------------|
| On Event | channel, payload | A message was broadcast. Both values are the signal's own arguments, in scope as row values. |

## Use cases

**1. Announce a boss kill from the health event that already exists.** The health pack knows nothing
about banners, scores or achievements, and does not need to.

```gdscript
extends Node


func _on_died() -> void:
	EventBus.broadcast("boss_defeated", {"title": "The Warden", "xp": 500})
```

**2. A HUD that answers it without holding a reference to anything.** The banner sheet and the boss
sheet never meet.

```gdscript
extends Node


func _on_event_raised(channel: String, payload: Dictionary) -> void:
	if channel == "boss_defeated":
		$Banner.show_text(str(payload["title"]))
```

**3. Add the reward on a completely different sheet.** Two listeners, one broadcast, no ordering
problem between them.

```gdscript
extends Node


func _on_event_raised(channel: String, payload: Dictionary) -> void:
	if channel == "boss_defeated":
		score += int(payload["xp"])
```

**4. A cutscene that waits for a door and gives up gracefully.** The give-up branch is what stops a
stuck door from stranding the player forever.

```gdscript
extends Node


func _on_cutscene_started() -> void:
	await EventBus.wait_for("door_opened", 8.0)
	if EventBus.wait_for_event_timed_out("door_opened"):
		$Dialogue.say("The east door is stuck. Try the hatch.")
```

**5. And the success half of the same wait.** Read it on the next rows of the same event: it is a
state check on the wait that just finished.

```gdscript
extends Node


func _on_cutscene_started() -> void:
	await EventBus.wait_for("door_opened", 8.0)
	if EventBus.wait_for_event_succeeded("door_opened"):
		$Camera.punch_scale(1.2, 0.3)
```

**6. A tutorial hint that shows once and unsubscribes itself.** No flag, no "did I already show
this" variable, no leak when the panel is freed.

```gdscript
extends Node


func _ready() -> void:
	EventBus.listen_once("first_jump", self, "_on_bus_event")
```

**7. Wait forever for a scripted beat.** A give-up time of 0 is legitimate under a one-shot trigger,
where the event can only be running once.

```gdscript
extends Node


func _on_ready() -> void:
	await EventBus.wait_for("intro_finished", 0.0)
	$Music.play()
```

**8. A wave director that paces itself off the game rather than off a clock.** Each wave starts when
the last one is actually cleared.

```gdscript
extends Node


func _on_wave_started() -> void:
	await EventBus.wait_for("wave_cleared", 60.0)
	spawn_next_wave()
```

**9. Fan a pause out to every system that can answer it.** Nothing has to be registered anywhere,
and a system that cannot pause is skipped rather than crashed into.

```gdscript
extends Node


func _on_pause_pressed() -> void:
	EventBus.broadcast_to_group("pausable", "on_game_paused", {"paused": true})
```

**10. Count how often something happened this run.** Useful for "you fell in the lava eleven times"
end-of-run screens.

```gdscript
extends Node


func _on_run_finished() -> void:
	$Summary.text = "Falls: %d" % EventBus.event_broadcast_count("player_fell")
```

**11. Gate content on something having happened at all.** Event Was Ever Broadcast is the "once it
has happened it stays happened" read.

```gdscript
extends Node


func _process(_delta: float) -> void:
	$SecretDoor.visible = EventBus.event_was_ever_broadcast("boss_defeated")
```

**12. React to something in the same frame it happened.** The polled read, for a per-frame event that
must see this frame's traffic.

```gdscript
extends Node


func _process(_delta: float) -> void:
	if EventBus.event_was_broadcast_this_frame("shot_fired"):
		$Recoil.kick()
```

**13. Broadcast a bare ping with no details.** An empty record is a legitimate message: sometimes the
name is the whole content.

```gdscript
extends Node


func _on_lever_pulled() -> void:
	EventBus.broadcast("door_opened", {})
```

**14. Print who broadcast what while hunting a listener that never fired.** The first thing to reach
for when a channel looks dead.

```gdscript
extends Node


func _on_debug_pressed() -> void:
	EventBus.print_event_bus_report()
```

**15. Start a session's log clean.** Clearing the record leaves the counters alone, so long-run
statistics survive.

```gdscript
extends Node


func _on_new_run() -> void:
	EventBus.clear_event_log()
```

**16. Let a shop tell the quest log about a purchase.** The shop has never heard of quests, which is
what keeps a shop reusable between games.

```gdscript
extends Node


func _on_item_bought(item_id: String) -> void:
	EventBus.broadcast("item_bought", {"item": item_id, "price": price_of(item_id)})
```

### Other use cases

**Achievement engine.** One sheet listens to every channel it cares about and holds no reference into gameplay at all, which means adding an achievement never means editing the code that earns it.

**Analytics funnel.** Broadcast a channel at each step of onboarding and read Event Broadcast Count at the end of the session to see exactly where players stop.

**Difficulty director.** A listener counts deaths, near-misses and clean rooms off channels the gameplay already sends, and nudges spawn rates without any system knowing a director exists.

**Radio chatter.** A dialogue sheet waits on channels rather than on timers, so a line about the collapsing bridge plays when the bridge actually collapses.

**Save prompts.** A channel broadcast at every safe moment lets a single listener decide whether enough has happened to be worth an autosave.

## Tips and common mistakes

- **Spell the channel the same way everywhere.** A channel is a plain name and nothing validates it;
  `boss_defeated` and `bossDefeated` are two different channels that both look right.
- **Read the payload by key, on the row.** On Event hands the row `payload`. Reaching for a stored
  "last payload" instead is both extra work and wrong the moment two broadcasts land in one frame.
- **Wait For Event suspends the event it lives in.** Do not put it under a per-frame trigger without a
  gate: overlapping suspended runs each wait separately. Under a one-shot trigger it is exactly right.
- **A give-up time of 0 waits forever.** That is intentional, and it is a hang if the message never
  comes. Give a deadline to anything the player could interrupt.
- **The two outcome conditions name a channel, not a row.** Two waits on the SAME channel under one
  trigger overwrite each other's verdict; give them different channels or read the outcome before
  starting the second wait.
- **Listen Once For Event needs a method that takes two arguments** - the channel and the payload, in
  that order. A method with the wrong shape is called and errors at that moment, not at author time.
- **Broadcast To Group calls a method, not a channel.** It is the has_method fan-out, so a member
  without that method is skipped silently - which is the point, and also why a typo does nothing.
- **A bus is not a replacement for a signal between two nodes that already know each other.** Reach
  for it when the sender should NOT know the receiver, not everywhere.
