# Feedback Player - The List Of Feedbacks An Object Carries

Feedback Player is a Godot EventSheets node you add under any object so that object carries its own beat of game feel. You add a `FeedbackPlayer` as a child, fill its Inspector list with cards - a shake, a flash, a hold, a loop, a property walked to a value, a word said out loud - and one row plays the lot. The sheet's side never changes as the list is tuned: `Play Feedbacks` is the same row on the day the list holds one card and on the day it holds twelve. The list holds the same steps a moment file holds, so a beat can be saved out as a file, shared with other objects, and loaded back. The strength on the play row scales every amount in the list, so a light hit and a heavy hit are one list at two numbers. It is a per-node behavior, not an autoload: every Action, Condition, Expression and Trigger targets the `FeedbackPlayer` living under the object you dropped it on.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [What a card can be](#what-a-card-can-be)
5. [ACE reference](#ace-reference)
6. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
7. [Use cases](#use-cases)
8. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **One hit, felt everywhere.** An enemy's damage beat is a list on the enemy, played by one row, so the sheet says "it was hit" and the node says what that feels like.
- **Beats an artist can tune without opening a sheet.** The list is an Inspector list with a Play button on it. Somebody who never opens the event sheet can reorder cards, retime them and preview the result.
- **Buttons that respond.** A hover beat and a press beat on the same button, each one a player node, each one two rows in the sheet.
- **Weapons whose feel changes with the weapon.** One tuned beat, and one row that swaps the kick card out when the weapon changes. Everything else in the beat stays exactly as it was tuned.
- **Accessibility that costs one row per switch.** Cards belong to families, and a whole family can be silenced at once, on one object or on every player in a group.
- **Effect-strength sliders that keep the timing.** Scaling amounts leaves the beat the same length, so half strength is still the same beat rather than a shorter one.
- **Variety out of the list itself.** Three shake cards named `shake_a`, `shake_b` and `shake_c`, one row that ticks exactly one of them, and a repeated hit stops sounding repeated.
- **Charge-ups and holds.** A loop that goes round while the button is held, and a head parked on a card until the sheet says to let go.
- **Cutscene-safe beats.** A play that can be skipped to its end, stopped where it is, or reverted so everything it moved goes back the way it found it.
- **Squads and menus.** A group of players played at once so the whole squad flinches or every button in a menu bounces on one row.

---

## Core concepts

**A card is one felt thing.** Each entry in the list is a card: a word saying what it does, how much of it, an extra word for the two kinds that need one, and how long it lasts. That is the same four keys a moment file's step holds, which is what lets a list be saved out as a file and a file be loaded into a list without either being converted.

**The label is the whole addressing scheme.** Every row that names one feedback names it by its **label** - the name typed on the card, or, for a card nobody named, its own word. A list tuned in the Inspector and a list retuned by rows can never disagree about which step is meant, and a label that is not in the list is said out loud in a warning rather than quietly ignored.

**A play is a walk down the list.** The head starts at one end, takes each card, and moves on. Cards between two holds run at once, so a stretch of the list is as long as its slowest card. A **Hold** waits for the slowest card above it; a **Pause** waits a flat time whatever is still running. That is why the list has a duration at all, and it is the number `Feedbacks Duration` answers.

**Strength multiplies twice.** The player's own `Strength` scales every amount in the list, and then the strength on the play row scales it again. One is the object's volume knob; the other is how hard this particular hit was.

**Families, not cards, are what a settings screen switches.** Every word belongs to a family: `audio`, `transform`, `camera`, `screen`, `pause`, `loop` or `signal`. Muting a family skips every card in it without anybody having to find and untick cards one at a time.

**The felt words come from the Juice behaviour beside it.** The ten moment words - shake, hitstop, slowmo, flash, punch, zoom, shockwave, chromatic, pulse and the screen-effect hold - are played by the Juice node under the same object. A list of those words with no Juice behaviour beside it warns once and does nothing, rather than warning ten times a frame.

**A channel is a group.** `Play On Channel` plays every Feedback Player in a named group at one strength. No references are held anywhere: the players join the group, and the row names the group.

**Edits copy, never write into a shared file.** A player whose moment-file slot is filled is playing a beat other objects may be playing too. The first edit row takes a copy of that beat into this list and lets the slot go, so the file is never changed underneath somebody else.

---

## Setup

**1. Add the node.** Add a plain `Node` as a child of the object that should carry the beat, and attach `FeedbackPlayer` to it. Name it after what it is for (`HitFeedback`, `HoverFeedback`), because that name is what the sheet's rows are read on. The player acts on its parent, so the parent is the object the beat is about.

**2. Put a Juice node beside it.** The ten felt words are played by the Juice behaviour, found beside the player (a sibling under the same parent, or a child of the player). Without one, the shake, flash and hitstop cards do nothing and the player says so once.

**3. Fill the list.** Select the player node and use **Add a feedback** under the list. Each card gets a stripe coloured by its family, a drag handle, a fold arrow, a tick box, its label and a badge saying how long it takes. The head of the list counts the cards and adds up the longest path through them.

```
Feedbacks 7 - 0.95 s total
  | Sound              hit_crunch      0.00 s
  | Punch Scale        1.3             0.30 s
  | Hold               until the above finish
  | Shake              0.4             0.20 s
  | Loop Start
  | Pulse Post Effect  chromatic 0.6   0.15 s     (unticked - skipped)
  | Loop Back          2 times         0.25 s
  Add a feedback  |  Play  Stop  Skip  Restore  Debug view  Save as file  Load from file
```

**4. Play it from the sheet, once.** The row never changes again as the list is tuned:

```
Enemy: On damaged
  -> HitFeedback | Feedback Player: Play Feedbacks  0.6
```

**5. Preview without running the game.** **Play** on the strip samples the list in the editor and applies it to the object; **Stop** and **Restore** put the object back the way they found it, and the scene's saved bytes are never touched. Only the three things an editor can honestly show are drawn: a shake as a wobble, a punch as a swell, and a tweened property walking to its value. A hitstop and a flash are things a running game does to time and to the screen, so they are left out rather than guessed at. **Debug view** draws the timeline of the plan, a bar per card at the time it starts, which is how you see why the flash came late.

---

## What a card can be

**The ten felt words**, played by the Juice behaviour beside the player: `shake`, `hitstop`, `slowmo`, `flash`, `punch`, `zoom`, `shockwave`, `chromatic`, `pulse` and `hold` (the screen-effect hold, titled **Hold Effect** on a card so it is not confused with the list's own Hold). Each carries an amount and a length; `flash`, `pulse` and `hold` also read the extra word, which is the colour a flash goes to and the name of the post effect a pulse or a hold reaches for.

**Four words that move the head** instead of being felt:

| Card | Fields | What it does |
| --- | --- | --- |
| **Pause** | Pause (default `0.25` s) | Waits this long before the next card, whatever the cards above are still doing. |
| **Hold** | Then wait (default `0.0` s) | Waits for the slowest card above to finish, then this long. What is under a hold is what happens after the hit rather than during it. |
| **Loop Start** | (none) | Marks where a Loop Back below sends the head. A list with no Loop Start loops back to its last Hold instead. |
| **Loop Back** | Pause (`0.25` s), Loop to last Hold (`true`), Loop to last Loop Start (`true`), Loops (`2`) | Moves the head back to the last Hold or Loop Start above, a number of times, pausing each time it lands. Shows **Loops left** counting down while the game runs. |

**Three that are neither a feeling nor a wait:**

| Card | Fields | What it does |
| --- | --- | --- |
| **Tween Property** | Property (`rotation`), To (`1.0`), Over (`0.2` s) | Walks one property of the object this player is under to a value, over a time. Restore Initial Values puts it back. |
| **Emit Signal** | Word | Says one word out of the player's **On Feedback Signal** trigger, so a sheet can hang anything at all off a point in the list. |
| **Play Player** | Player, Strength (`1.0`) | Plays another Feedback Player from inside this one, at a share of this play's strength. |

**The unfolded card.** Click a card's arrow and it opens: a line saying what that feedback does, **Active**, **Label**, **Chance**, a **Timing** foldout, then the card's own fields drawn with the real drawers, and, while the game runs, the values the play is writing back, greyed. The Timing foldout is the same on every card: initial delay, cooldown, repeat count and interval, the clock (game time or real time), a strength window the card only plays inside, and skip on stop. Every one of those keys is absent by default, which is what keeps a plain card identical to a moment file's step.

---

## ACE reference

All rows live in the **Feedback Player** category and are read on the player node.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Play Feedbacks | `at_strength` (float, `1.0`) | Plays this node's list of feedbacks and carries straight on with the rows under this one. The strength scales every amount in the list, so a light hit and a heavy one are one list at two numbers. |
| Play Feedbacks And Wait | `at_strength` (float, `1.0`) | Plays the list and WAITS for the last card to finish - the rows under this one are what happens afterwards. Use it when the hit has to land before the death animation starts. |
| Play Backwards | `at_strength` (float, `1.0`) | Plays the list from the far end, so the last feedback is felt first. The other half of a beat that has to undo itself - a door that opened, closing. |
| Play On Channel | `channel` (String, `feedback`), `at_strength` (float, `1.0`) | Plays every feedback player in a group at once, at one strength - the whole squad flinching, every button in a menu bouncing. Put the players in the group and name it here. |
| Stop Feedbacks | (none) | Stops the play where it is. Whatever a card already started keeps running on its own - this stops the LIST, not the shake it set going. |
| Skip To End | (none) | Stops waiting and does everything that is left at once - the cutscene skip of a feedback list. Every card from the head down is felt, without the pauses between them. |
| Restore Initial Values | (none) | Puts every value this player's Tween Property cards changed back the way they found it. The undo of a list that moved the object rather than flashing it. |
| Revert | (none) | Stops the play and puts back what it changed, the LAST change first - so a stack of tweens unwinds in the order it was built rather than all at once. |
| Pause Feedbacks | (none) | Holds the play where it is without losing its place. Resume Feedbacks carries on from the same card. |
| Resume Feedbacks | (none) | Carries on from where Pause Feedbacks left off. |
| Add Feedback | `step` (card, `{"verb": "shake", "amount": 0.4, "seconds": 0.2}`), `after_label` (String, empty) | Adds one feedback to this player's list while the game runs - the same card the Inspector adds, with the same fields. Leave the after box empty to put it at the end, or name a card to put it straight after that one. |
| Insert Feedback Before | `step` (card, `{"verb": "flash", "amount": 1.0, "seconds": 0.1}`), `before_label` (String, `shake`) | Puts a feedback into the list immediately ABOVE the card you name - the other half of Add Feedback, for a step that has to be felt before something already in the beat. |
| Replace Feedback | `label` (String, `kick`), `step` (card, `{"verb": "recoil", "amount": 1.0, "seconds": 0.1}`) | Swaps one card in the list for another, in place. THE weapon-change row: the beat the designer tuned stays the beat, and only the kick inside it changes. The new card keeps the old one's label unless it brings its own. |
| Remove Feedback | `label` (String, `shake`) | Takes one card out of the list. What an upgrade that drops a part of a beat does, and the undo of Add Feedback. |
| Move Feedback To | `label` (String, `shake`), `position` (int, `1`) | Moves one card to a place in the list - the drag handle, as a row. The first card is 1; a number past the end puts it last. |
| Enable Feedback | `label` (String, `shake`) | Ticks one card's box, so it is felt again from the next play on. The enable box in the Inspector, as a row. |
| Disable Feedback | `label` (String, `shake`) | Unticks one card's box, so the play steps over it. What an accessibility option that drops the screen shake and keeps the sound does with one row. |
| Set Feedback Field | `label` (String, `shake`), `field` (`amount` \| `effect` \| `seconds` \| `delay` \| `interval` \| `repeat` \| `chance` \| `loops`, default `amount`), `value` (`1.0`) | Retunes ONE value on one card: how much, how long, which extra word. The number box in the Inspector, as a row, so a weapon or a difficulty can move an amount without a second list. |
| Set Feedback Timing | `label` (String, `shake`), `delay` (float, `0.0`), `repeat` (int, `1`), `interval` (float, `0.0`), `clock` (`game` \| `real`, default `game`) | Moves one card in time: how long it waits first, how many times it repeats and how far apart, and which clock it counts on. The card's Timing foldout, as a row. |
| Set Feedback Chance | `label` (String, `shake`), `percent` (float, `100.0`) | How often one card is felt at all, as a percentage. 100 is every time, 25 is a quarter of the hits - the cheapest variety there is. |
| Set Feedback Label | `label` (String, `shake`), `new_label` (String, `big shake`) | Renames one card. Every other row addresses cards by this name, so renaming one is renaming what the rest of the sheet has to say. |
| Duplicate Feedback | `label` (String, `shake`), `new_label` (String, empty) | Copies one card and puts the copy straight under it, under a name of its own. Two shakes a frame apart out of one tuned card. |
| Clear Feedbacks | (none) | Empties the list. What a player that is about to be handed a whole beat by Copy Feedbacks From or Load Moment File wants first. |
| Copy Feedbacks From | `other` (Node) | Takes another player's whole list and makes it this one's - a copy, so retuning either afterwards leaves the other alone. One tuned enemy hit, given to every enemy that spawns. |
| Load Moment File | `path` (String, `res://eventsheet_addons/juice/impact.tres`) | Brings a moment file's beat INTO this player's list, as a copy - so it can be retuned by rows afterwards without ever writing to the file two other objects may be playing. |
| Save Moment File | `path` (String, `user://my_moment.tres`) | Writes this list out as a moment file, so a beat tuned while the game ran can be shared, shipped or loaded back. Only the four keys a file holds are written: a card that is switched off, and the timing words a list adds, are named in a warning and left out. |
| Set Player Strength | `value` (float, `1.0`) | Turns this whole player up or down without retuning a single card - the object's own volume knob, on top of the strength the play row asks for. |
| Set Player Cooldown | `seconds` (float, `0.1`) | The shortest gap between two plays, in seconds. A play asked for sooner is refused, which is how a rapid-fire hit stops stacking its own feedback. |
| Set Can Play While Playing | `answer` (`restart` \| `ignore` \| `overlap`, default `restart`) | What a second play does while the first is still running: start again from the top, be ignored, or run alongside it. |
| Mute Feedback Category | `category` (`audio` \| `transform` \| `camera` \| `screen` \| `pause` \| `loop` \| `signal`, default `screen`), `muted` (bool, `true`) | Silences a whole family of cards at once and lets them back with the same row. THE accessibility option: one row per switch on the settings screen, and no card has to be found and unticked. |
| Mute Feedback Category On Channel | `channel` (String, `feedback`), `category` (same seven, default `screen`), `muted` (bool, `true`) | The same switch, thrown for every Feedback Player in a group at once - which is what a settings screen wants, because the option is about the game rather than about one object. |
| Scale Feedback Amounts | `category` (empty \| the seven families, default empty), `factor` (float, `0.5`) | Multiplies how much every card in a family does - the effect-strength slider on a settings screen, where half is still the same beat and not a shorter one. Leave the family empty to move the whole list. |
| Retime Feedbacks | `factor` (float, `0.5`) | Stretches or squeezes the whole beat in time: every length, every wait and every gap multiplied by the same number. Half makes a snappier version of a beat nobody has to retune card by card. |
| Shuffle Feedbacks Between | `first_label` (String, `shake_a`), `last_label` (String, `shake_c`) | Reorders the stretch of the list between two cards, both included, at random. The cheapest variety a repeated hit can have: the same feedbacks, in a different order every time. |
| Pick One Feedback Of | `prefix` (String, `shake_`) | Ticks exactly one of the cards whose label starts with what you type and unticks the rest, so shake_a, shake_b and shake_c become one shake chosen fresh each time. Variety out of the list itself, with no branch in the sheet. |
| Jump To Feedback | `label` (String, `impact`) | Moves the head of a RUNNING play to the card you name, so the rest of the beat starts there. What a hit that interrupts its own wind-up wants. |
| Skip Feedback Once | `label` (String, `shake`) | Steps over one card the NEXT time the play reaches it, and then forgets about it. The one-off exception a disable would have to be undone after. |
| Set Loop Count | `label` (String, `loop_back`), `loops` (int, `2`) | How many times a Loop Back card sends the head round. A charge that gets longer the further it is held, without a second list. |
| Hold Here | (none) | Stops the head where it is and leaves it there - a charge held, a beat waiting on the player. Release Hold carries on from the same card, and nothing ticks while it waits. |
| Release Hold | (none) | Lets a held play carry on from the card it stopped on. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Playing | (none) | True while a play is running - between the started and the finished trigger. |
| Has Played | (none) | True once this player has played at least once, and stays true. The "they have seen this already" question, with nothing to store. |
| Feedback Is Playing | `label` (String, `shake`) | True while the head is on that card - the moment the hit is being felt rather than the whole beat around it. |
| Has Feedback | `label` (String, `shake`) | True when this player's list holds a card by that name. The question a row asks before it retunes one. |
| Feedback Is Enabled | `label` (String, `shake`) | True when that card's box is ticked, so a settings screen can show the switch the way the list actually has it. |
| For Each Feedback | (none) | A LOOPING condition: runs the actions under it once per feedback in this player's list, top to bottom, with the label of each one in hand. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Feedbacks Progress | (none) | float | How far down the list the play has got, 0 at the first card and 1 when the last one is done. |
| Feedbacks Duration | (none) | float | The longest path through the list in seconds - the same number the head of the Inspector shows, so a row can wait exactly as long as the beat lasts. |
| Feedback Count | (none) | int | How many cards this player's list holds, ticked or not - the number the head of the Inspector shows. |
| Feedback Label At | `position` (int, `1`) | String | The name of the card at a place in the list. The first card is 1; a number past the end answers with nothing. |
| Feedback Field | `label` (String, `shake`), `field` (`amount` \| `effect` \| `seconds` \| `delay` \| `interval` \| `repeat` \| `chance` \| `loops`, default `amount`) | Variant | What one card says at one of its fields. The read half of Set Feedback Field, so a slider can be shown at the value the list actually holds. |
| Feedback Progress | `label` (String, `shake`) | float | How far through one card the play is, 0 before it starts and 1 once it is done. Read off the plan rather than off a tick, so asking it costs nothing. |
| Feedback Duration | `label` (String, `shake`) | float | How long ONE card lasts, its own wait included - beside Feedbacks Duration, which is how long the whole beat lasts. |
| Current Feedback | (none) | String | The label of the card the head is on right now, or nothing when no play is running. |
| Loops Left | `label` (String, `loop_back`) | int | How many times round a Loop Back card still has to go in the play that is running. |

### Triggers

| Trigger | Carries | Fires when |
| --- | --- | --- |
| On Feedbacks Started | `at_strength` (float) | A play begins, with the strength it began at. |
| On Feedbacks Finished | (nothing) | The last card of a play is done. |
| On Feedback Signal | `word` (String) | An Emit Signal card said its word. |
| On Feedback Started | `label` (String) | The head reached one card. |
| On Feedback Finished | `label` (String) | That one card is done. |
| On Feedback Skipped | `label` (String), `why` (String) | A card was stepped over, and why: off, muted, chance, strength, or skipped once. |
| On Hold Reached | (nothing) | A Hold card began waiting. |
| On Loop | `loops_left` (int) | A Loop Back sent the head round, with the loops it still has to go. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `steps` | Array[Dictionary] | empty | The card list itself, in order. |
| `strength` | float | `1.0` | What every amount in the list is scaled by, before the strength on the row is applied. |
| `direction` | `top to bottom` / `bottom to top` | `top to bottom` | Which end of the list a play starts from. |
| `while_playing` | `restart` / `ignore` / `overlap` | `restart` | What a second play does while the first is still running. |
| `cooldown` | float | `0.0` | The shortest gap between two plays, in seconds. A play asked for sooner than this is refused. |
| `moment_file` | Resource | none | Optional: a moment file to play INSTEAD of the list. Drop one here to share a beat between objects. |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the vocabulary above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs and value expressions as ready-to-insert chains once the node is attached:

- `$FeedbackPlayer.strength` inserts the **Strength** entry straight into any expression
- `$FeedbackPlayer.cooldown` inserts the **Cooldown** entry straight into any expression

The `$FeedbackPlayer` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this node at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("FeedbackPlayer")` chains,
which survive auto-named children. While **Live Values** streams from a running game, the group
upgrades to *Behaviours (live - on your node)* and reads the RUNNING instance. And with your node
selected in the Scene dock, the section grounds to that node's actual children before you even press Run.

---

## Use cases

Each example names the player node the rows are read on. The list itself lives in that node's Inspector, so the rows below never change as the beat is tuned.

### 1. The hit beat, played at the size of the hit

An enemy has one damage beat, and how hard the hit was is a number on the row rather than a second list.

```
Enemy: On damaged
  -> HitFeedback | Feedback Player: Play Feedbacks  Damage.amount / Enemy.max_hp
```

A scratch plays a light version of the same beat, a finisher plays it at full strength, and the list was tuned once.

### 2. Wait for the beat before the death animation

The hit has to land before anything else happens, so the rows under the play are what happens afterwards.

```
Enemy: On killed
  -> HitFeedback | Feedback Player: Play Feedbacks And Wait  1.0
  -> Enemy: play "death" animation
  -> Loot: spawn drops
```

Play Feedbacks And Wait holds the rows under it until the last card is done. The plain Play Feedbacks would have run them the same frame.

### 3. A door that closes by playing its opening backwards

The undo of a beat is the beat read the other way, so no second list has to be kept in step with the first.

```
Player: On interact with Door
  Condition: Door: is closed
    -> DoorFeedback | Feedback Player: Play Feedbacks  1.0
  Else
    -> DoorFeedback | Feedback Player: Play Backwards  1.0
```

Play Backwards starts at the far end of the list. Every card is still played, so it is the whole beat rather than a trimmed one.

### 4. The whole squad flinches on one row

Put every enemy's player node in a group, and one row reaches all of them without a single reference.

```
On Ready
  -> Enemy: add to group  "squad"

Boss: On slam
  -> AnyFeedback | Feedback Player: Play On Channel  "squad", 0.8
```

Play On Channel plays every Feedback Player in the group at one strength. It is the engine's own groups underneath, which is why nothing has to be registered.

### 5. A rapid-fire weapon that stops stacking its own feedback

A cooldown on the player refuses a play asked for sooner than the gap, which is cheaper than a guard in the sheet.

```
On Ready
  -> FireFeedback | Feedback Player: Set Player Cooldown  0.08
  -> FireFeedback | Feedback Player: Set Can Play While Playing  "ignore"

Player: On fire
  -> FireFeedback | Feedback Player: Play Feedbacks  1.0
```

With `ignore`, a second play while the first runs is dropped rather than restarting it, so a held trigger reads as one continuous feel instead of a stutter.

### 6. The weapon-change beat, in two rows

The beat the designer tuned stays the beat; only the kick inside it changes.

```
Player: On weapon changed
  -> FireFeedback | Feedback Player: Replace Feedback  "kick", {"verb": "punch", "amount": Weapon.recoil, "seconds": 0.12}
  -> FireFeedback | Feedback Player: Set Feedback Field  "shot", "effect", Weapon.flash_colour
```

The replacement keeps the old card's name unless it brings one of its own, so every other row that addressed `kick` goes on working.

### 7. A settings screen built out of the list

For Each Feedback walks the list and hands you each label, so a screen that lists a beat's parts needs to know nothing about what is in it.

```
On Settings Opened
  Condition: HitFeedback | Feedback Player: For Each Feedback
    -> UI: add a switch labelled  feedback_label
    -> UI: set that switch to  HitFeedback | Feedback Player: Feedback Is Enabled  feedback_label

On Switch Toggled
  Condition: UI.switch_on  is false
    -> HitFeedback | Feedback Player: Disable Feedback  UI.switch_label
  Else
    -> HitFeedback | Feedback Player: Enable Feedback  UI.switch_label
```

Feedback Is Enabled is what makes the screen show the list as it actually is rather than as it was when the screen was built.

### 8. One accessibility switch for every screen effect in the game

Families are what a settings screen switches, and a channel throws the switch for every player at once.

```
On Ready
  -> HitFeedback: add to group  "feedback"

On Reduce Screen Effects Toggled
  -> AnyFeedback | Feedback Player: Mute Feedback Category On Channel  "feedback", "screen", Settings.reduce_screen_effects
```

Nobody has to find and untick a card. The seven families are audio, transform, camera, screen, pause, loop and signal.

### 9. An effect-strength slider that keeps the timing

Scaling amounts leaves every length alone, so half strength is the same beat felt less rather than a shorter beat.

```
On Effect Strength Changed
  -> HitFeedback | Feedback Player: Scale Feedback Amounts  "", Settings.effect_strength
```

Leaving the family empty moves every card. Naming one moves only that family, which is how "keep the sound, soften the camera" is one row.

### 10. A snappier version of a whole beat, with nothing retuned

Retiming multiplies every length, wait and gap by the same number.

```
On Difficulty Set To Fast
  -> HitFeedback | Feedback Player: Retime Feedbacks  0.6
```

The shape of the beat survives: the holds still hold, the loops still loop, everything just arrives sooner.

### 11. Variety out of three cards and one row

Name three shakes `shake_a`, `shake_b` and `shake_c`, and let the list pick between them.

```
Enemy: On damaged
  -> HitFeedback | Feedback Player: Pick One Feedback Of  "shake_"
  -> HitFeedback | Feedback Player: Play Feedbacks  1.0
```

Pick One Feedback Of ticks exactly one of them and unticks the rest, so a repeated hit stops sounding repeated with no branch in the sheet.

### 12. Shuffle a stretch of the beat

The same feedbacks in a different order is variety that costs nothing to author.

```
Enemy: On damaged
  -> HitFeedback | Feedback Player: Shuffle Feedbacks Between  "shake_a", "shake_c"
  -> HitFeedback | Feedback Player: Play Feedbacks  1.0
```

Both ends of the stretch are included, and the cards outside it are left exactly where they are.

### 13. A charge-up that holds until the button is let go

Hold Here parks the head; Release Hold carries on from the same card. Nothing ticks while it waits.

```
Player: On charge pressed
  -> ChargeFeedback | Feedback Player: Play Feedbacks  1.0

On Hold Reached
  -> ChargeFeedback | Feedback Player: Hold Here

Player: On charge released
  -> ChargeFeedback | Feedback Player: Release Hold
```

The Hold card in the list is what raises On Hold Reached, so where the beat waits is a decision made in the Inspector rather than in the sheet.

### 14. A charge whose loop gets longer the further it is held

Set Loop Count moves the number on a Loop Back card, so one list covers every charge level.

```
Player: On charge level changed
  -> ChargeFeedback | Feedback Player: Set Loop Count  "loop_back", Player.charge_level

Every tick
  -> ChargeMeter: value = ChargeFeedback | Feedback Player: Loops Left  "loop_back"
```

Loops Left counts down in the running play, which is what a meter should be reading rather than a variable the sheet keeps in step by hand.

### 15. Hang anything at all off a point in the beat

An Emit Signal card says one word, and the sheet answers it.

```
On Feedback Signal  (word = "impact")
  -> Camera: spawn impact particles
  -> Audio: play "crunch"
```

The card is where in the beat it happens; the rows are what happens. Moving the card in the Inspector moves the moment without touching the sheet.

### 16. A hit that interrupts its own wind-up

Jump To Feedback moves the head of a running play, so the rest of the beat starts from the card you name.

```
Player: On hit landed
  Condition: SwingFeedback | Feedback Player: Is Playing
    -> SwingFeedback | Feedback Player: Jump To Feedback  "impact"
  Else
    -> SwingFeedback | Feedback Player: Play Feedbacks  1.0
```

Without the jump, a fast second hit would restart the wind-up the player had already seen.

### 17. Skip a card exactly once

A one-off exception that a Disable would have to be undone after.

```
Player: On first tutorial hit
  -> HitFeedback | Feedback Player: Skip Feedback Once  "hitstop"
  -> HitFeedback | Feedback Player: Play Feedbacks  1.0
```

The card is stepped over the next time the play reaches it, and the player forgets about it afterwards.

### 18. Undo everything a beat moved

Tween Property cards move real values on the object, so a cancelled beat needs a way back.

```
Player: On menu closed
  -> PanelFeedback | Feedback Player: Revert

Player: On scene left
  -> PanelFeedback | Feedback Player: Restore Initial Values
```

Revert stops the play and unwinds the changes last-first. Restore Initial Values puts every tweened value back without caring about order.

### 19. A cutscene skip for a beat

Skip To End does everything that is left at once, without the pauses between the cards.

```
On Skip Pressed
  Condition: IntroFeedback | Feedback Player: Is Playing
    -> IntroFeedback | Feedback Player: Skip To End
```

Every card from the head down is still felt, so the state the beat leaves behind is the state it would have left anyway.

### 20. One tuned beat, given to every enemy that spawns

Copy Feedbacks From takes another player's whole list as a copy, so retuning either afterwards leaves the other alone.

```
On Enemy Spawned
  -> NewEnemy.HitFeedback | Feedback Player: Clear Feedbacks
  -> NewEnemy.HitFeedback | Feedback Player: Copy Feedbacks From  Template.HitFeedback
```

Clearing first is what stops the template's cards landing on top of whatever the new node was carrying.

### 21. Save a beat tuned while the game ran

The list writes out as a moment file, so a beat found by playing can be shipped.

```
On Debug Save Beat Pressed
  -> HitFeedback | Feedback Player: Save Moment File  "user://tuned_hit.tres"

On Ready
  -> HitFeedback | Feedback Player: Load Moment File  "res://eventsheet_addons/juice/impact.tres"
```

Only the four keys a file holds are written: a card that is switched off, and the timing words a list adds, are named in a warning and left out rather than written down half.

### 22. Wait exactly as long as the beat lasts

Feedbacks Duration is the longest path through the list, so a wait can be written once and stay right as the list is tuned.

```
Enemy: On killed
  -> HitFeedback | Feedback Player: Play Feedbacks  1.0
  -> System: wait  HitFeedback | Feedback Player: Feedbacks Duration  seconds
  -> Enemy: queue free
```

Reorder the cards, add a hold, retime the whole thing, and the wait is still exactly right.

### 23. A progress bar for a long beat

Feedbacks Progress runs 0 to 1 down the list, and Current Feedback says which card the head is on.

```
Every tick
  Condition: IntroFeedback | Feedback Player: Is Playing
    -> IntroBar: value = IntroFeedback | Feedback Player: Feedbacks Progress
    -> IntroLabel: text = IntroFeedback | Feedback Player: Current Feedback
```

Both are read off the plan rather than off a tick, so asking them every frame costs nothing.

### 24. Tell the player why a card did nothing

On Feedback Skipped carries the label and the reason, which is what turns a beat that felt wrong into a beat you can debug.

```
On Feedback Skipped
  -> Debug Overlay: watch  label + " skipped: " + why
```

The reason is one of off, muted, chance, strength, or skipped once.

### 25. A beat built out of the beats of its parts

A Play Player card plays another Feedback Player from inside this one, at a share of this play's strength.

```
Boss: On phase change
  -> BossFeedback | Feedback Player: Play Feedbacks  1.0
```

With `HeadFeedback`, `ArmFeedback` and `CameraFeedback` named on Play Player cards inside `BossFeedback`, one row moves the whole boss. A nested play obeys the outer one, so stopping, skipping or restoring the outer list does the same to them.

### Other use cases

**Vehicle surfaces.** A player per surface type, each list holding its own shake, rumble and audio cards, and one row on the surface-changed trigger swapping which player the wheels talk to.

**Menu focus.** Every focusable control carries a hover player and a press player, and one channel row on the settings screen mutes the camera family across the whole menu without touching a single card.

**Boss telegraphs.** A wind-up list with a Loop Start and a Loop Back that goes round while the boss decides, and a Jump To Feedback that leaves the loop the instant the attack commits.

**Crafting and looting.** A rarity beat per drop, played at a strength read off the item's tier, so a common and a legendary are the same list at two numbers rather than two lists that drift apart.

**Photosensitivity presets.** One switch on the settings screen throwing Mute Feedback Category On Channel for the screen family, and a second slider running Scale Feedback Amounts over the camera family, covering every beat in the game with two rows.

---

## Tips and common mistakes

- **The player needs a Juice behaviour beside it for the felt words.** The ten moment words are played by the Juice node under the same object. Without one, those cards do nothing and the player warns once, by name. The timing cards, Tween Property, Emit Signal and Play Player all work regardless.
- **Rename a card and every row that named it stops finding it.** Rows address cards by label. A renamed card leaves those rows compiling, running and doing nothing. The editor says so before the game runs, in the row's quiet amber state and in the Doctor's Feedbacks section, but Set Feedback Label is still a rename of what the rest of the sheet has to say.
- **Stop Feedbacks stops the LIST, not what it started.** A shake a card set going keeps running on its own. Use Revert when the point is to put back what the beat changed.
- **Only Tween Property cards are restorable.** Restore Initial Values and Revert put back values this player's tweens moved. A flash, a hitstop or a shockwave is something the screen did, and there is nothing to restore.
- **A cooldown of 0 lets every play through.** If a held trigger is stacking its own feedback, the fix is a cooldown, a `while_playing` of `ignore`, or both. Restarting is the default because a fresh hit usually should restart the beat.
- **Hold and Pause are not the same wait.** A Hold waits for the slowest card above it to finish and then waits its own time; a Pause waits a flat time whatever is still running. Getting these the wrong way round is the commonest reason a beat feels late.
- **A Loop Back with nothing to end it is caught, not hung.** A play gives up after its step limit and says so rather than looping forever, but a Loop Back always wants either a Loop Start or a Hold above it and a loop count that ends.
- **Editing a player whose moment-file slot is filled takes a copy first.** The file two other objects may be playing is never written into. The beat is unchanged; from the first edit row on, it is this object's own list.
- **Save Moment File cannot carry the whole list.** Only the four keys a file holds are written, so a switched-off card and the timing words a list adds are named in a warning and left out. Keep the list on the node when the timing words matter.
- **Preview shows three things, not everything.** In the editor, a shake, a punch and a tweened property are drawn; a hitstop and a flash are left out because they are things a running game does to time and to the screen. A beat that looks thin in preview is not necessarily thin.
- **Scale Feedback Amounts and Retime Feedbacks change the list.** They are not a temporary lens: they multiply the values the cards hold. Scaling by 0.5 twice leaves the amounts at a quarter, so drive them from a setting's absolute value rather than applying them repeatedly.
