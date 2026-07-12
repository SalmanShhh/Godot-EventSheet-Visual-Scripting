# Flash - Blink a Node On and Off, Then Restore It

Flash is a Godot EventSheets behavior pack for the oldest trick in the game-feel book: making a thing blink. You attach a `FlashBehavior` to any visible node - a sprite, a health bar, a pickup, a UI button - and that node becomes the thing that flashes. There is no id to pass around and nothing to register: every Action, Expression, and Trigger targets the behavior living on the node you drop it on. Call **Flash** with a duration and the host toggles its visibility on and off at a set interval, then snaps back to fully visible and fires **On Flash Finished**. Call **Stop Flash** to cancel early. The only knob is `interval` - how fast it blinks - and you can change it live from the sheet. It is a per-node behavior, not a global singleton: one `FlashBehavior` per node that needs to blink.

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

- **Hit reactions.** Flash the player or an enemy for a fraction of a second when it takes damage, the classic "I got hit" read, with zero timers to wire.
- **Invincibility frames.** Blink the player for the whole i-frame window so it is obvious they cannot be hurt right now, then Stop Flash the instant the window ends.
- **Pickups about to vanish.** Blink a dropped coin or heart for its last couple of seconds so the player knows to grab it before it despawns.
- **Low-resource warnings.** Flash a health bar, ammo counter, or fuel gauge when it crosses a danger line so the eye is pulled straight to it.
- **Hazard telegraphs.** Blink a spike trap, falling platform, or laser emitter right before it fires so the player gets a fair warning.
- **Selection highlights.** Flash a unit portrait or inventory slot while it is selected, and stop the blink the moment it is deselected.
- **Objective and quest cues.** Blink a quest marker or map icon for a few seconds when the objective updates so the player notices the change.
- **Boss enrage tells.** Flash a boss when it shifts phase, and tighten the blink interval as the fight gets more dangerous.
- **Rejected-input feedback.** A quick flash on a shop button or locked door when the action fails reads as "no" without a single line of UI text.
- **Countdown urgency.** Blink a timer label faster and faster as it runs out by shrinking the interval live.
- **Cutscene focus pulses.** Flash an NPC or prop to draw the player's eye, then continue the scene when On Flash Finished fires so the timing is exact.
- **Persistent alarm lights.** Kick off a long flash to make an alert lamp pulse, and Stop Flash it when the threat clears.

---

## Core concepts

The whole pack fits in a few ideas. Learn these and there is nothing left to look up.

**The node is the thing that flashes.** You attach a `FlashBehavior` as a child of the node you want to blink, and that parent becomes the **host**. The host must be a `CanvasItem` - that covers every 2D node (Node2D, Sprite2D, AnimatedSprite2D) and every UI Control. Every ACE in this pack acts on the host of the behavior you placed it on, so there is no target id to pass anywhere.

**Flashing means toggling visibility, not tinting.** A flash repeatedly flips the host's `visible` on and off. It is a genuine show/hide, not a color fade or a modulate pulse, so the node fully disappears on each off beat and reappears on each on beat. That is exactly the crisp on/off read you want for a hit blink or a warning.

**Duration and interval are two different times.** **Flash** takes a `seconds` argument - the total length of the blinking burst. The `interval` property is the time between each visibility toggle - the blink speed. A `Flash 1.0` with `interval` at `0.1` blinks about ten times over one second. Duration is "how long", interval is "how fast".

**It always restores itself.** When the duration runs out, the host is set back to fully visible (so you never get left invisible on a half-blink) and **On Flash Finished** fires. That trigger is your clean hand-off point for whatever should happen after the blink ends - re-enable input, continue a cutscene, hide a marker.

**Stop Flash cancels without firing the trigger.** **Stop Flash** ends the blink immediately and restores visibility, but it does **not** fire On Flash Finished. Use it when something else takes over (the player got deselected, the threat cleared) and you do not want the "finished naturally" reaction to run.

**Interval is live and per node.** `interval` is an exported Inspector value you can set in the editor, and you can also change it mid-game with **Set Interval**, **Add To Interval**, and **Subtract From Interval** - and read it back with the **Interval** expression. Because each node carries its own behavior, changing one node's interval never touches another's.

---

## Setup

**1. Attach the behavior.** Add a `FlashBehavior` as a child node of the node you want to blink (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The parent must be a `CanvasItem`; if it is not, the behavior prints a warning and does nothing. One behavior per node that flashes.

**2. Set the interval (optional).** Select the behavior node and set `interval` in the Inspector - the seconds between each on/off toggle. The default `0.1` is a fast, snappy blink; raise it for a slow, deliberate pulse.

| Property | Default | What it does |
|---|---|---|
| `interval` | `0.1` | Seconds between visibility toggles - the blink speed. Smaller is faster; larger is slower. |

**3. Call Flash when you want a blink.** There is nothing to register on ready. Just call **Flash** with a duration wherever the game wants a blink, and react to **On Flash Finished** if you need to do something when it ends. Here is a complete first setup - the player blinks for half a second when it is hit:

```
On Player Hit
  -> Player | FlashBehavior: Flash  0.5

On Flash Finished
  -> Player: re-enable hit detection
```

The host blinks for half a second, snaps back to visible on its own, and On Flash Finished lets you turn damage back on the moment the flash ends. No timer, no visibility bookkeeping.

---

## ACE reference

All Flash ACEs target the `FlashBehavior` on the node they are placed on - there is no id parameter anywhere. The hand-authored ACEs (Flash, Stop Flash, On Flash Finished) sit in the **Flash** category; the exported `interval` property also contributes the four property ACEs listed below automatically.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Flash | `seconds` (float) | Starts a blinking burst on the host: toggles its visibility on and off at `interval` for this many seconds, then restores it and fires On Flash Finished. |
| Stop Flash | (none) | Ends the blink immediately and restores the host to fully visible. Does not fire On Flash Finished. |
| Set Interval | `value` (float) | Sets the blink speed - the seconds between visibility toggles - live. |
| Add To Interval | `amount` (float) | Adds to the current interval, slowing the blink (a negative amount speeds it up). |
| Subtract From Interval | `amount` (float) | Subtracts from the current interval, speeding the blink up. |

### Conditions

Flash ships no conditions of its own. To branch on whether a node is currently shown or hidden, read the host's own `visible` property in a general comparison condition.

| Condition | Parameters | Description |
|---|---|---|
| (none) | | This pack exposes no conditions. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Interval | (none) | float | The current blink interval in seconds. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Flash Finished | A flash reaches the end of its duration. The host has already been restored to fully visible. (Stop Flash does not fire this.) |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `interval` | float | `0.1` | Seconds between visibility toggles - the blink speed. Smaller is faster, larger is slower. Also settable live with Set / Add To / Subtract From Interval. |

---

## Use cases

Each example targets the `FlashBehavior` on the named node. Attach the behavior once, then call Flash where the moment happens and react in the triggers.

### 1. Damage flash on the player

The bread-and-butter hit react. When the player takes a hit, blink it briefly so the strike lands visually.

```
On Player Hit
  -> Player | FlashBehavior: Flash  0.3
```

A short duration with the default fast interval reads as a single sharp flinch.

### 2. Invincibility frames

Blink the player for the whole i-frame window so it is clear they are temporarily untouchable, and cut the blink the instant the window ends.

```
On Player Hit
  -> Player | FlashBehavior: Flash  1.5
  -> Player: start invincibility timer (1.5s)

On Invincibility Ended
  -> Player | FlashBehavior: Stop Flash
```

Matching the Flash duration to the i-frame length means the blink and the invulnerability end together; the Stop Flash is a belt-and-braces guarantee visibility is restored if the timer ends early.

### 3. Pickup blinking before it despawns

A dropped coin lives for a few seconds. Flash it for its final stretch so the player knows to hurry.

```
On Coin Lifetime  <  2.0
  -> Coin | FlashBehavior: Flash  2.0

On Flash Finished
  -> Coin: queue_free()
```

The coin blinks for its last two seconds, then On Flash Finished is a tidy place to actually remove it.

### 4. Low-health bar warning

When health drops into the danger zone, blink the health bar to pull the eye to it.

```
On Health Changed
  Condition: Player.hp / Player.max_hp  <  0.25
    -> HealthBar | FlashBehavior: Flash  1.0
```

Firing the flash on the health-change stimulus means the warning reacts the instant the hit lands, not on a timer tick.

### 5. Hazard telegraph before a trap fires

Give the player a fair warning: blink a spike trap right before it springs, then trigger the trap when the flash ends.

```
On Trap Armed
  -> Spikes | FlashBehavior: Flash  0.8

On Flash Finished
  -> Spikes: extend spikes and enable hitbox
```

The blink is the tell; On Flash Finished is the exact frame the danger becomes real.

### 6. Speeding-up countdown

Make a countdown feel more urgent by tightening the blink as time runs out. Start a slow flash, then shrink the interval each second.

```
On Timer Second Tick
  -> Timer | FlashBehavior: Subtract From Interval  0.02

On Round Start
  -> Timer | FlashBehavior: Set Interval  0.4
  -> Timer | FlashBehavior: Flash  10.0
```

The blink begins lazy and grows frantic as the interval shrinks, without restarting the flash.

### 7. Selected unit highlight

Blink a selected unit's portrait while it is chosen, and stop the moment the player picks something else.

```
On Unit Selected
  -> Portrait | FlashBehavior: Set Interval  0.25
  -> Portrait | FlashBehavior: Flash  9999

On Unit Deselected
  -> Portrait | FlashBehavior: Stop Flash
```

A huge duration keeps the highlight going indefinitely; Stop Flash ends it cleanly on deselect with no leftover blinking.

### 8. Quest marker attention pulse

When an objective updates, blink its map icon for a few seconds so the player notices the change, then leave it steady.

```
On Objective Updated
  -> QuestMarker | FlashBehavior: Flash  3.0
```

Three seconds of blink is enough to catch the eye; the marker restores itself to fully visible afterward.

### 9. Boss enrage tell with a tightening blink

Flash a boss when it enters an enraged phase, and set a fast interval so the blink itself signals the escalation.

```
On Boss Phase Changed
  Condition: Boss.hp / Boss.max_hp  <  0.5
    -> Boss | FlashBehavior: Set Interval  0.06
    -> Boss | FlashBehavior: Flash  1.2
```

The tight interval makes the enrage flash read faster and angrier than a normal hit blink.

### 10. Rejected purchase feedback

When a player cannot afford an item, a single quick flash on the shop button says "no" instantly.

```
On Buy Pressed
  Condition: Player.gold  <  Item.cost
    -> BuyButton | FlashBehavior: Set Interval  0.08
    -> BuyButton | FlashBehavior: Flash  0.24
```

A short duration at a snappy interval gives one crisp double-blink of denial.

### 11. Cutscene focus pulse with precise timing

Draw the player's eye to an NPC, then continue the dialogue exactly when the flash ends so the beat is frame-accurate.

```
On Reveal Villain
  -> Villain | FlashBehavior: Flash  1.0

On Flash Finished
  -> Dialogue: show next line
```

On Flash Finished chains the next scene step to the end of the pulse instead of guessing at a timer length.

### 12. Persistent alarm light

Kick off a long, slow flash to make an alert lamp pulse for the duration of an alarm, and stop it when the threat clears.

```
On Alarm Raised
  -> AlarmLight | FlashBehavior: Set Interval  0.5
  -> AlarmLight | FlashBehavior: Flash  9999

On Alarm Cleared
  -> AlarmLight | FlashBehavior: Stop Flash
```

The slow interval gives a steady beacon pulse rather than a frantic blink.

### 13. Combo-tier flash on the score meter

Blink the combo meter briefly each time the player reaches a new tier, matching the blink speed to the tier for extra punch.

```
On Combo Tier Up
  -> ComboMeter | FlashBehavior: Set Interval  0.05
  -> ComboMeter | FlashBehavior: Flash  0.4
```

Setting the interval before Flash guarantees this celebration blinks faster than a routine one.

### 14. Slow a blink back down after a burst

Read the current interval, and if a warning flash has been sped up over time, ease it back toward a calm value once the danger passes.

```
On Danger Cleared
  Condition: [Expression] Warning | FlashBehavior  Interval  <  0.2
    -> Warning | FlashBehavior: Set Interval  0.3
    -> Warning | FlashBehavior: Stop Flash
```

The Interval expression lets the sheet check how fast the blink currently is before deciding to reset it and stop.

### 15. A disarmable trap telegraph

An interrupt case: the trap blinks its warning, but a rogue can disarm it mid-telegraph. Because Stop Flash never fires On Flash Finished, cancelling the blink also cancels the spring.

```
On Trap Armed
  -> Spikes | FlashBehavior: Flash  0.8

On Trap Disarmed
  -> Spikes | FlashBehavior: Stop Flash

On Flash Finished
  -> Spikes: extend spikes and enable hitbox
```

The spikes only fire when the telegraph runs its full course; a successful disarm silently parks the trap visible and harmless.

### Other use cases

**Rhythm-beat cues.** Target rings blink on every beat with the interval matched to the song's tempo, so the flash itself teaches the timing.

**Tower ammo warnings.** Towers running low blink faster as the clip empties, letting the player triage reloads across the whole map at a glance.

**Failing corridor light.** A long Flash with a slow interval reads as glitching wiring in a horror hallway, and Stop Flash steadies the lamp when the generator is fixed.

**Respawn grace period.** Freshly respawned players blink for the length of their protection window, so opponents read the no-damage state without a UI banner.

**Treasure sonar.** A compass icon blinks quicker as the player nears buried loot, shrinking the interval with distance until the dig spot is obvious.

---

## Tips and common mistakes

- **The node is the target - there is no id.** Every Action, Expression, and Trigger acts on the `FlashBehavior` of the node it is placed on. Attach one behavior per node that needs to blink; do not try to route one behavior to flash several nodes.
- **The host must be a CanvasItem.** Attach the behavior under a 2D node or a UI Control. If the parent is not a `CanvasItem` (for example a plain Node or a 3D node), the behavior warns on entry and flashing does nothing.
- **Flashing hides the node, it does not tint it.** Each blink flips `visible` off and on, so the node fully disappears on the off beats. If you want a color pulse that keeps the shape on screen instead, that is a different effect - Flash is a true show/hide.
- **Duration and interval are not the same number.** The `seconds` you pass to Flash is how long the burst lasts; `interval` is how fast it blinks within that burst. Mixing them up gives either a blink that is over too soon or one that toggles too slowly to read.
- **Flash always ends visible.** When the duration runs out the host is restored to fully visible, so you never get stranded invisible on a half-blink. You do not need to manually re-show the node after a flash.
- **Stop Flash does not fire On Flash Finished.** Only a flash that runs its full duration fires the trigger. If you cancel with Stop Flash, put any follow-up in the same event that calls Stop Flash, not in On Flash Finished.
- **Set the interval before you call Flash for a one-off speed.** Interval is read continuously while blinking, so Set Interval mid-flash changes the live speed - but if you want a specific blink speed for one burst, set it just before the Flash action in the same event.
- **Keep the interval above zero.** A zero or negative interval means it tries to toggle every frame, which reads as a flicker rather than a blink. Values from about `0.05` (fast) to `0.5` (slow) cover most needs.
- **Re-calling Flash restarts the duration.** Calling Flash again while a blink is running resets the remaining time to the new duration; it does not stack. That is usually what you want for repeated hits - each hit refreshes the blink.
