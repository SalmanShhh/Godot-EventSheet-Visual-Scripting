# Juice Player - The List Of Juice Cards An Object Carries

Juice Player is a Godot EventSheets node you add under any object so that object carries its own beat of game feel. You add a `JuicePlayer` as a child, fill its Inspector list with cards - a shake, a flash, a hold, a loop, a property walked to a value, a word said out loud - and one row plays the lot. The sheet's side never changes as the list is tuned: `Play Juice` is the same row on the day the list holds one card and on the day it holds twelve. The list holds the same steps a moment file holds, so a beat can be saved out as a file, shared with other objects, and loaded back. The strength on the play row scales every amount in the list, so a light hit and a heavy hit are one list at two numbers. A Juice node does one effect when a row asks; a Juice Player plays a list of juice cards, one after another. It was called Feedback Player before version 0.21.0, and a scene or script that still says `FeedbackPlayer` keeps working. It is a per-node behavior, not an autoload: every Action, Condition, Expression and Trigger targets the `JuicePlayer` living under the object you dropped it on.

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

**The label is the whole addressing scheme.** Every row that names one juice card names it by its **label** - the name typed on the card, or, for a card nobody named, its own word. A list tuned in the Inspector and a list retuned by rows can never disagree about which step is meant, and a label that is not in the list is said out loud in a warning rather than quietly ignored.

**A play is a walk down the list.** The head starts at one end, takes each card, and moves on. Cards between two holds run at once, so a stretch of the list is as long as its slowest card. A **Hold** waits for the slowest card above it; a **Pause** waits a flat time whatever is still running. That is why the list has a duration at all, and it is the number `Juice Duration` answers.

**Strength multiplies twice.** The player's own `Strength` scales every amount in the list, and then the strength on the play row scales it again. One is the object's volume knob; the other is how hard this particular hit was.

**Families, not cards, are what a settings screen switches.** Every word belongs to a family: `audio`, `transform`, `camera`, `screen`, `pause`, `loop` or `signal`. Muting a family skips every card in it without anybody having to find and untick cards one at a time.

**The felt words come from the Juice behaviour beside it.** The ten moment words - shake, hitstop, slowmo, flash, punch, zoom, shockwave, chromatic, pulse and the screen-effect hold - are played by the Juice node under the same object. A list of those words with no Juice behaviour beside it warns once and does nothing, rather than warning ten times a frame.

**A channel is a group.** `Play On Channel` plays every Juice Player in a named group at one strength. No references are held anywhere: the players join the group, and the row names the group.

**Edits copy, never write into a shared file.** A player whose moment-file slot is filled is playing a beat other objects may be playing too. The first edit row takes a copy of that beat into this list and lets the slot go, so the file is never changed underneath somebody else.

---

## Setup

**1. Add the node.** Add a plain `Node` as a child of the object that should carry the beat, and attach `JuicePlayer` to it (Create Node lists it as **JuicePlayer**; the `FeedbackPlayer` entry nested under it is the old name, kept so projects made before version 0.21.0 keep working). A node you add is called `JuicePlayer`, and you can name it after what it is for (`HitJuice`, `HoverJuice`): a row you place starts on the one Juice Player in the open scene, whatever it is called, and on `$JuicePlayer` when there are none or several. The player acts on its parent, so the parent is the object the beat is about.

**2. Put a Juice node beside it.** The ten felt words are played by the Juice behaviour, found beside the player (a sibling under the same parent, or a child of the player). Without one, the shake, flash and hitstop cards do nothing and the player says so once.

**3. Fill the list.** Select the player node and use **Add card** under the list. Each card gets a small tile in its family's colour, a drag handle, a fold arrow, a tick box, its label and a badge saying how long it takes. The head of the list counts the cards and adds up the longest path through them.

```
7 juice cards - 0.95 s total
  | Sound              hit_crunch      0.00 s
  | Punch Scale        1.3             0.30 s
  | Hold               until the above finish
  | Shake              0.4             0.20 s
  | Loop Start
  | Pulse Post Effect  chromatic 0.6   0.15 s     (unticked - skipped)
  | Loop Back          2 times         0.25 s
  Add card  |  Play  Stop  Skip  Restore  Debug view  Save as file  Load from file
```

**4. Play it from the sheet, once.** The row never changes again as the list is tuned:

```
Enemy: On damaged
  -> HitJuice | Juice Player: Play Juice  0.6
```

**5. Preview without running the game.** The strip sits under the cards. **Play** samples the list in the editor and applies it to the object; **Stop** and **Restore** put the object back the way they found it. Everything a preview may move (position, rotation, scale and colour, and each property a Tween Property card names) is written down first and put back on Stop, on Restore, at the end of each pass and when the editor saves or runs the scene, so the scene's saved bytes are never the middle of a preview. It plays for real a shake, a punch, a tweened property, a Sound card and the cards that move another node (the property of every node they point at is written down too), and shows the waits, Hitstop and Slowmo as time; a flash, a zoom and the screen effects are drawn by the running game, a signal runs your own code and another Juice Player runs its own list, so those are skipped and named. **Debug view** draws the timeline of the plan, a bar per card at the time it starts, which is how you see why the flash came late, and writes a line per card saying which of those it is. The play mark on a card head plays that one card alone, the card menu's **Play from here** plays it and everything under it, **Repeat** plays again each time the list ends (reading the list as it is then), and **Try at strength** plays at any strength. None of the three is saved.

---

## What a card can be

**The ten felt words**, played by the Juice behaviour beside the player: `shake`, `hitstop`, `slowmo`, `flash`, `punch`, `zoom`, `shockwave`, `chromatic`, `pulse` and `hold` (the screen-effect hold, titled **Hold Effect** on a card so it is not confused with the list's own Hold). Each carries an amount and a length; `flash`, `pulse` and `hold` also read the extra word, which is the colour a flash goes to and the name of the post effect a pulse or a hold reaches for.

**Four words that move the head** instead of being felt:

| Card | Fields | What it does |
| --- | --- | --- |
| **Pause** | Pause (default `0.25` s) | Waits this long before the next card, whatever the cards above are still doing. |
| **Hold** | Waits for (all the cards above, or one of them), Then wait (default `0.0` s) | Waits for the slowest card above to finish, then this long; or, with **Waits for** set to one card, for that card alone, so the others carry on beside what comes next. What is under a hold is what happens after the hit rather than during it. The head says how long it will wait, and the line under its fields says for which card. Typing `wait` in the Add box finds it, and Pause. |
| **Loop Start** | (none) | Marks where a Loop Back below sends the head. A list with no Loop Start loops back to its last Hold instead. |
| **Loop Back** | Pause (`0.25` s), Loop to last Hold (`true`), Loop to last Loop Start (`true`), Loops (`2`) | Moves the head back to the last Hold or Loop Start above, a number of times, pausing each time it lands. Shows **Loops left** counting down while the game runs. |

**Three that end or move a sound, or move a hand (Stop Sound, Fade Bus, Vibrate):** the player plays these itself too. None of them is felt in the editor; Debug view names each as skipped.

| Card | Fields | What it does |
| --- | --- | --- |
| **Stop Sound** | Sound card (one of the Sound cards above, or every sound of this player), Fade out (`0.0` s) | Stops the sound an earlier Sound card started, by that card's name, with a fade if you want one: a charge-up hum that ends on release. It belongs to the `audio` family. |
| **Fade Bus** | Bus, To (`-12` dB), Over (`0.3` s) | Moves a bus volume to a value over a time, and Restore Initial Values puts it back. A bus the project does not have is said once and left alone. It belongs to the `audio` family. |
| **Vibrate** | Weak motor (`0.5`), Strong motor (`0.5`), For (`0.2` s) | Rumbles every connected controller and buzzes a phone for the time, each motor scaled by the strength of the play. Does nothing on the web, and nothing when no controller is connected (it has been tried on a desktop with none, not on a real controller or a phone). It belongs to the `device` family. |

**Cards that point at something in the scene.** A card that acts on a node keeps the way to it as a node path written from this player, picked with Godot's own node picker, so a renamed or moved node is followed and a scene copied elsewhere still finds its nodes. A card that picks no node acts on the object this player is under. When a picked node is gone the card says so in quiet amber, and when the game runs a card that finds nothing says so once in the Output panel and does nothing: it never raises an error. Particles, Animation, Sprite Animation, Show or Hide, Squash And Stretch, Punch Position, Punch Rotation, Pop, Fade, Count To, Reveal Text, Fill Bar, Shader Value and a Tween Property card that points at another node play in the editor's preview, on the nodes they point at, and everything they moved is put back before the scene is saved. Spawn Scene, the body cards, Grab Focus, Call Method, Emit Signal and Play Player are not shown in the editor, and Debug view says why.

| Card | Fields | What it does |
|---|---|---|
| **Particles** | Node, Do (restart, start, stop), Length (`0.4` s) | Restarts, starts or stops a particles node. Picking a one-shot node sets the length to its lifetime. `scene` family. |
| **Spawn Scene** | Scene, Drop it at (this object, a node), Node | Adds a copy of a scene to the running game, taking it from the object pool when that scene has a pool. `scene` family. |
| **Animation** | Player, Animation, Length (`0.4` s) | Plays a clip of an animation player, stretched to the card's length. Choosing a clip sets the length to the clip's. |
| **Sprite Animation** | Sprite, Animation, Length | The same for an animated sprite. |
| **Show or Hide** | Node, Do (show, hide, show for a time), For (`0.2` s) | Shows or hides a node, or shows it for a time. |
| **Tween Property** | Node, Property, From (where it is now, or a value), To, Over, Transition, Ease, Then come back, Add to the value | Walks any property of any node to a value of its own kind: a number, a colour or a vector. A card saved with only a property, a number and a time is the one-number tween on this object it always was. |
| **Squash And Stretch, Punch Position, Punch Rotation** | Stretch, Across and Down, Degrees; Over | Done by the Juice node beside the player, on the object the player is under. Put them on the sprite under a body, never on the body. |
| **Push** | Body, Direction (away from a node, the way it is moving, fixed), Speed, Scaled by strength | A RigidBody takes an impulse; a CharacterBody has the speed added to its velocity once and carries on moving itself, so a script that sets velocity every frame overwrites it. |
| **Force For A Time, Gravity For A Time, Freeze Body** | Body and the numbers | A force, a gravity scale or a hold on a RigidBody for a time, put back when the time is up or on Restore. Freezing is asked for at the end of the frame, the safe moment. |
| **Pop, Fade, Grab Focus, Count To, Reveal Text, Fill Bar** | Node and the numbers | Cards for a Control: scale from the middle, fade the modulate, take focus, count a label to a number (a plain number or a name from the game such as `GameState.score`), reveal letters over the length, glide a bar to a value. They change scale, colour and text, never position, because a container owns that. Reveal Text takes a speed in letters a second and sets the card's length to the label's text divided by it. |
| **Shader Value** | Node, Value, To, Over, Transition, Then come back, Only this object | Moves one value of the node's shader. With Only this object on, the node gets a copy of its material for the play and Restore gives it back, so the others that share the file are left alone. |
| **Emit Signal, Call Method** | Node, Signal or Method, and its values | Fire a signal or call a method of the picked node's script. Left on this player, Emit Signal says one word out of On Juice Signal as before. |

Play Player now picks the other player instead of asking for its name; an older card that typed a name still plays. A player will not play itself or one that is playing it.

**Four that the player plays itself, because they are neither a moment word nor a wait (a sound, a value walked, a word said, another player played):**

| Card | Fields | What it does |
| --- | --- | --- |
| **Sound** | Stream (a file picked with Godot's resource picker, kept as its uid), Volume (dB), Random volume (dB), Pitch, Random pitch, Bus, Heard from (`here` or `everywhere`), Follows strength, Delay | Plays a sound when the list reaches the card, through one of four reusable voices on the player. Each play lands somewhere between the two ends of the random volume and pitch. Its length is the file's length at its pitch, it is muted with the `audio` family, and a card with no sound says so and plays nothing. Listen on the open card plays it alone in the editor. A moment file cannot hold it. |
| **Tween Property** | Property (`rotation`), To (`1.0`), Over (`0.2` s) | Walks one property of the object this player is under to a value, over a time. Restore Initial Values puts it back. |
| **Emit Signal** | Word | Says one word out of the player's **On Juice Signal** trigger, so a sheet can hang anything at all off a point in the list. |
| **Play Player** | Player, Strength (`1.0`) | Plays another Juice Player from inside this one, at a share of this play's strength. |

**Selecting cards.** Click a card to select it, Shift+click for the run from the last click, Ctrl+click to add or take one out. A selected card is filled the way a selected row is in the Scene dock. Ctrl+C copies the selected cards, Ctrl+X cuts them, Ctrl+V pastes them under the last selected card (or at the end when none is selected, and nothing is replaced), Ctrl+D duplicates them in place and Delete removes them; each is one change, so one Ctrl+Z takes it back. A right click on a card opens its menu, which acts on everything selected when the card is part of the selection: Duplicate, Cut, Copy, Paste, Paste over, Move to top, Move up, Move down, Remove, and Play from here. Cards are copied as text, so select the other object, click in its list and paste: a card that pointed at a node by name may find no such node under the new object. Cards that start together sit on one faint band.

**The unfolded card.** Click a card's arrow and it opens: a line saying what that juice card does, **Active**, **Label**, **Chance**, a **Timing** foldout, then the card's own fields drawn with the real drawers, and, while the game runs, the values the play is writing back, greyed. The Timing foldout is the same on every card: initial delay, cooldown, repeat count and interval, the clock (game time or real time), a strength window the card only plays inside, and skip on stop. Every one of those keys is absent by default, which is what keeps a plain card identical to a moment file's step.

**A card of your own.** The cards that ship are words the player knows. When none fits, write one: a script that extends `JuiceCard`, anywhere in the project.

```gdscript
class_name ScreenFlashCard
extends JuiceCard
## Flashes the whole screen a colour.

## The colour to flash.
@export var colour: Color = Color.WHITE
## How long the flash lasts.
@export_range(0.0, 2.0, 0.01, "suffix:s") var seconds: float = 0.1


func play(target: Node, strength: float) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(colour, strength)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	target.add_child(layer)
	await target.get_tree().create_timer(seconds).timeout
	layer.queue_free()
```

- **It lists itself.** A script with a `class_name` that extends `JuiceCard` appears in Add card under a **Yours** heading, named from the class (`ScreenFlashCard` reads Screen Flash, a closing Card is dropped), with the line under the class as its help. Delete the file and the card is gone from the box.
- **The exports are the fields.** Each export is drawn with Godot's own editor for its type, as it would be in the Inspector: a colour button, a range with its suffix, a file picker, a drop-down for an enum. A `NodePath` export is the node picker the built-in cards use, kept as a path from the player so a renamed node is followed. The `##` line above an export is its tooltip, and the field is named as you wrote the variable.
- **`play(target, strength)` is the only function you must write.** `target` is the object the player is under and `strength` is the strength of this play. `length()` says how long the card takes so a Hold card and the length of the list can wait for it; a card that exports a number called `seconds` is that long without it. `stop()` is called when Stop Juice is pressed and `restore()` when Restore Initial Values is. The player hands itself over as `player` just before `play` runs, so a card that exports a `NodePath` finds its node with `player.get_node_or_null(path)`.
- **How it is saved.** A card of yours is one more entry in the same list: its class name, the address of its script and a key for each export. Moving the script file is safe, because the address is the file's uid, and renaming the class works too, because the card is found by its script first. When the script is gone the card stays in the list with the values it holds and does nothing, and the game says so once in the Output panel.
- **Rows reach it.** Add Juice Card, Replace Juice Card and Set Juice Card Field work on a card of yours by its label and its export names. Type the export's name in the field box of Set Juice Card Field (it offers the eight shipped names and takes any other the card holds); the word of a card and the script it holds are the two it refuses to change.
- **The preview.** Play in the editor runs a card of yours only when its script is marked `@tool`, which is Godot's rule for any script that runs in the editor, and Debug view says which. A tool card is told to `stop` and `restore` when the pass ends, so put back there whatever it changed.
- **As an event sheet.** `eventsheet_addons/juice/screen_flash_card.gd` is this same card written as a Custom Resource sheet that extends `JuiceCard`: two variables marked editable, a `play` function and a `length` function. It is the plain script above with nothing of the plugin in it but its version line, so a card written as code opens as a sheet and a card made as a sheet can be read, shared and edited as code. Copy the file and rename the class to make another card.

**When a card goes wrong.** Every message a running Juice Player prints in the Output panel names the player, the card's label and the reason, for example `the card "Spin" on HitJuice points at Crate, which has no property called "wobble", so it did nothing`, and says it once per card. Three more doors lead from the message to the cause:

- **The Doctor** reads every saved scene for a card that points at a node the scene does not have, or names a sound, scene or card script the project does not have, and files a warning for each (two short sentences: what it points at, and to pick it again). It reads the scene's saved bytes without instancing anything, so it finds a lost node without running the game, and it stays quiet about a path that leads into a scene instanced inside this one or out of this one, because those cannot be judged from the file.
- **Show its cards** is an entry on the right-click menu of a row that plays a Juice Player (Play Juice, Play Juice And Wait, Play Juice Backwards, written in the sheet or as a line of code the sheet shows as one). It opens the scene the sheet runs in if it is not open, selects that player and leaves the Inspector on its list. It is offered only when the scene the sheet runs in holds a Juice Player of that name.
- **Find what plays this** is a button on the strip under the list. It lists the sheets of the project that play this player and opens the one you pick, or says in one quiet line that no sheet does.

---

## ACE reference

All rows live in the **Juice Player** category and are read on the player node.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Play Juice | `at_strength` (float, `1.0`) | Plays this node's list of juice cards and carries straight on with the rows under this one. The strength scales every amount in the list, so a light hit and a heavy one are one list at two numbers. |
| Play Juice And Wait | `at_strength` (float, `1.0`) | Plays the list and WAITS for the last card to finish - the rows under this one are what happens afterwards. Use it when the hit has to land before the death animation starts. |
| Play Juice Backwards | `at_strength` (float, `1.0`) | Plays the list from the far end, so the last juice card is felt first. The other half of a beat that has to undo itself - a door that opened, closing. |
| Play Juice On Channel | `channel` (String, `juice_players`), `at_strength` (float, `1.0`) | Plays every juice card player in a group at once, at one strength - the whole squad flinching, every button in a menu bouncing. Put the players in the group and name it here. |
| Stop Juice | (none) | Stops the play where it is. Whatever a card already started keeps running on its own - this stops the LIST, not the shake it set going. |
| Skip To End | (none) | Stops waiting and does everything that is left at once - the cutscene skip of a juice card list. Every card from the head down is felt, without the pauses between them. |
| Restore Initial Values | (none) | Puts every value this player's Tween Property cards changed back the way they found it. The undo of a list that moved the object rather than flashing it. |
| Revert | (none) | Stops the play and puts back what it changed, the LAST change first - so a stack of tweens unwinds in the order it was built rather than all at once. |
| Pause Juice | (none) | Holds the play where it is without losing its place. Resume Juice carries on from the same card. |
| Resume Juice | (none) | Carries on from where Pause Juice left off. |
| Add Juice Card | `step` (card, `{"verb": "shake", "amount": 0.4, "seconds": 0.2}`), `after_label` (String, empty) | Adds one juice card to this player's list while the game runs - the same card the Inspector adds, with the same fields. Leave the after box empty to put it at the end, or name a card to put it straight after that one. |
| Insert Juice Card Before | `step` (card, `{"verb": "flash", "amount": 1.0, "seconds": 0.1}`), `before_label` (String, `shake`) | Puts a juice card into the list immediately ABOVE the card you name - the other half of Add Juice Card, for a step that has to be felt before something already in the beat. |
| Replace Juice Card | `label` (String, `kick`), `step` (card, `{"verb": "recoil", "amount": 1.0, "seconds": 0.1}`) | Swaps one card in the list for another, in place. THE weapon-change row: the beat the designer tuned stays the beat, and only the kick inside it changes. The new card keeps the old one's label unless it brings its own. |
| Remove Juice Card | `label` (String, `shake`) | Takes one card out of the list. What an upgrade that drops a part of a beat does, and the undo of Add Juice Card. |
| Move Juice Card To | `label` (String, `shake`), `position` (int, `1`) | Moves one card to a place in the list - the drag handle, as a row. The first card is 1; a number past the end puts it last. |
| Enable Juice Card | `label` (String, `shake`) | Ticks one card's box, so it is felt again from the next play on. The enable box in the Inspector, as a row. |
| Disable Juice Card | `label` (String, `shake`) | Unticks one card's box, so the play steps over it. What an accessibility option that drops the screen shake and keeps the sound does with one row. |
| Set Juice Card Field | `label` (String, `shake`), `field` (`amount` \| `effect` \| `seconds` \| `delay` \| `interval` \| `repeat` \| `chance` \| `loops` or any value the card holds, default `amount`), `value` (`1.0`) | Retunes ONE value on one card: how much, how long, which extra word, or any value the card holds under that name (the export of a card of your own). The field box offers the keys of the card the label box names when the scene the sheet runs in is saved (with the Inspector's word beside each), and the eight common names when it is not. The number box in the Inspector, as a row, so a weapon or a difficulty can move an amount without a second list. |
| Set Juice Card Timing | `label` (String, `shake`), `delay` (float, `0.0`), `repeat` (int, `1`), `interval` (float, `0.0`), `clock` (`game` \| `real`, default `game`) | Moves one card in time: how long it waits first, how many times it repeats and how far apart, and which clock it counts on. The card's Timing foldout, as a row. |
| Set Juice Card Chance | `label` (String, `shake`), `percent` (float, `100.0`) | How often one card is felt at all, as a percentage. 100 is every time, 25 is a quarter of the hits - the cheapest variety there is. |
| Rename Juice Card | `label` (String, `shake`), `new_label` (String, `big shake`) | Renames one card. Every other row addresses cards by this name, so renaming one is renaming what the rest of the sheet has to say. |
| Duplicate Juice Card | `label` (String, `shake`), `new_label` (String, empty) | Copies one card and puts the copy straight under it, under a name of its own. Two shakes a frame apart out of one tuned card. |
| Clear Juice Cards | (none) | Empties the list. What a player that is about to be handed a whole beat by Copy Juice Cards From or Load Moment File wants first. |
| Copy Juice Cards From | `other` (Node) | Takes another player's whole list and makes it this one's - a copy, so retuning either afterwards leaves the other alone. One tuned enemy hit, given to every enemy that spawns. |
| Load Moment File | `path` (String, `res://eventsheet_addons/juice/impact.tres`) | Brings a moment file's beat INTO this player's list, as a copy - so it can be retuned by rows afterwards without ever writing to the file two other objects may be playing. |
| Save Moment File | `path` (String, `user://my_moment.tres`) | Writes this list out as a moment file, so a beat tuned while the game ran can be shared, shipped or loaded back. Only the four keys a file holds are written: a card that is switched off, and the timing words a list adds, are named in a warning and left out. |
| Set Juice Player Strength | `value` (float, `1.0`) | Turns this whole player up or down without retuning a single card - the object's own volume knob, on top of the strength the play row asks for. |
| Set Juice Player Cooldown | `seconds` (float, `0.1`) | The shortest gap between two plays, in seconds. A play asked for sooner is refused, which is how a rapid-fire hit stops stacking its own juice. |
| Set Can Play While Playing | `answer` (`restart` \| `ignore` \| `overlap`, default `restart`) | What a second play does while the first is still running: start again from the top, be ignored, or run alongside it. |
| Mute Juice Family | `category` (`audio` \| `transform` \| `camera` \| `screen` \| `pause` \| `loop` \| `signal`, default `screen`), `muted` (bool, `true`) | Silences a whole family of cards at once and lets them back with the same row. THE accessibility option: one row per switch on the settings screen, and no card has to be found and unticked. A Pause, a Hold and the loop cards only wait, so they are never muted and the beat keeps its length. |
| Mute Juice Family On Channel | `channel` (String, `juice_players`), `category` (same seven, default `screen`), `muted` (bool, `true`) | The same switch, thrown for every Juice Player in a group at once - which is what a settings screen wants, because the option is about the game rather than about one object. |
| Scale Juice Amounts | `category` (empty \| the seven families, default empty), `factor` (float, `0.5`) | Multiplies how much every card in a family does - the effect-strength slider on a settings screen, where half is still the same beat and not a shorter one. Leave the family empty to move the whole list. |
| Scale Juice Timing | `factor` (float, `0.5`) | Stretches or squeezes the whole beat in time: every length, every wait and every gap multiplied by the same number. Half makes a snappier version of a beat nobody has to retune card by card. |
| Shuffle Juice Cards Between | `first_label` (String, `shake_a`), `last_label` (String, `shake_c`) | Reorders the stretch of the list between two cards, both included, at random. The cheapest variety a repeated hit can have: the same juice cards, in a different order every time. |
| Pick One Juice Card Starting With | `prefix` (String, `shake_`) | Ticks exactly one of the cards whose label starts with what you type and unticks the rest, so shake_a, shake_b and shake_c become one shake chosen fresh each time. Variety out of the list itself, with no branch in the sheet. |
| Jump To Juice Card | `label` (String, `impact`) | Moves the head of a RUNNING play to the card you name, so the rest of the beat starts there. What a hit that interrupts its own wind-up wants. |
| Skip Juice Card Once | `label` (String, `shake`) | Steps over one card the NEXT time the play reaches it, and then forgets about it. The one-off exception a disable would have to be undone after. |
| Set Loop Count | `label` (String, `loop_back`), `loops` (int, `2`) | How many times a Loop Back card sends the head round. A charge that gets longer the further it is held, without a second list. |
| Hold Here | (none) | Stops the head where it is and leaves it there - a charge held, a beat waiting on the player. Release Hold carries on from the same card, and nothing ticks while it waits. |
| Release Hold | (none) | Lets a held play carry on from the card it stopped on. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Playing | (none) | True while a play is running - between the started and the finished trigger. |
| Has Played | (none) | True once this player has played at least once, and stays true. The "they have seen this already" question, with nothing to store. |
| Juice Card Is Playing | `label` (String, `shake`) | True while the head is on that card - the moment the hit is being felt rather than the whole beat around it. |
| Has Juice Card | `label` (String, `shake`) | True when this player's list holds a card by that name. The question a row asks before it retunes one. |
| Juice Card Is Enabled | `label` (String, `shake`) | True when that card's box is ticked, so a settings screen can show the switch the way the list actually has it. |
| For Each Juice Card | (none) | A LOOPING condition: runs the actions under it once per juice card in this player's list, top to bottom, with the label of each one in hand. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Juice Progress | (none) | float | How far down the list the play has got, 0 at the first card and 1 when the last one is done. |
| Juice Duration | (none) | float | The longest path through the list in seconds - the same number the head of the Inspector shows, so a row can wait exactly as long as the beat lasts. |
| Juice Card Count | (none) | int | How many cards this player's list holds, ticked or not - the number the head of the Inspector shows. |
| Juice Card Label At | `position` (int, `1`) | String | The name of the card at a place in the list. The first card is 1; a number past the end answers with nothing. |
| Juice Card Field | `label` (String, `shake`), `field` (`amount` \| `effect` \| `seconds` \| `delay` \| `interval` \| `repeat` \| `chance` \| `loops` or any value the card holds, default `amount`) | Variant | What one card says at one of its fields. The read half of Set Juice Card Field, so a slider can be shown at the value the list actually holds. |
| Juice Card Progress | `label` (String, `shake`) | float | How far through one card the play is, 0 before it starts and 1 once it is done. Read off the plan rather than off a tick, so asking it costs nothing. |
| Juice Card Duration | `label` (String, `shake`) | float | How long ONE card lasts, its own wait included - beside Juice Duration, which is how long the whole beat lasts. |
| Current Juice Card | (none) | String | The label of the card the head is on right now, or nothing when no play is running. |
| Loops Left | `label` (String, `loop_back`) | int | How many times round a Loop Back card still has to go in the play that is running. |

### Triggers

| Trigger | Carries | Fires when |
| --- | --- | --- |
| On Juice Started | `at_strength` (float) | A play begins, with the strength it began at. |
| On Juice Finished | (nothing) | The last card of a play is done. |
| On Juice Signal | `word` (String) | An Emit Signal card said its word. |
| On Juice Card Started | `label` (String) | The head reached one card. |
| On Juice Card Finished | `label` (String) | That one card is done. |
| On Juice Card Skipped | `label` (String), `why` (String) | A card was stepped over, and why: off, muted, chance, strength, or skipped once. |
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
| `autoplay` | bool | `false` | Plays the list once, at full strength, when the node enters the scene: a spawn pop, a pickup shimmer. Off, nothing is written into the scene for it. |
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

- `$JuicePlayer.strength` inserts the **Strength** entry straight into any expression
- `$JuicePlayer.cooldown` inserts the **Cooldown** entry straight into any expression

The `$JuicePlayer` token stays selected after insert, so retargeting to your child's actual name is one
keystroke, or a node drag. Attaching this node at runtime instead? Tick **Robust behaviour
lookups** in the dictionary and the same entries insert as `get_node_or_null("JuicePlayer")` chains,
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
  -> HitJuice | Juice Player: Play Juice  Damage.amount / Enemy.max_hp
```

A glancing hit plays a light version of the same beat, a finisher plays it at full strength, and the list was tuned once.

### 2. Wait for the beat before the death animation

The hit has to land before anything else happens, so the rows under the play are what happens afterwards.

```
Enemy: On killed
  -> HitJuice | Juice Player: Play Juice And Wait  1.0
  -> Enemy: play "death" animation
  -> Loot: spawn drops
```

Play Juice And Wait holds the rows under it until the last card is done, including a card still running when the head has walked past it (a 0.3 s shake on its own makes the rows under it wait 0.3 s). The plain Play Juice would have run them the same frame.

### 3. A door that closes by playing its opening backwards

The undo of a beat is the beat read the other way, so no second list has to be kept in step with the first.

```
Player: On interact with Door
  Condition: Door: is closed
    -> DoorJuice | Juice Player: Play Juice  1.0
  Else
    -> DoorJuice | Juice Player: Play Juice Backwards  1.0
```

Play Backwards starts at the far end of the list. Every card is still played, so it is the whole beat rather than a trimmed one.

### 4. The whole squad flinches on one row

Put every enemy's player node in a group, and one row reaches all of them without a single reference.

```
On Ready
  -> Enemy: add to group  "squad"

Boss: On slam
  -> AnyJuice | Juice Player: Play Juice On Channel  "squad", 0.8
```

Play On Channel plays every Juice Player in the group at one strength. It is the engine's own groups underneath, which is why nothing has to be registered.

### 5. A rapid-fire weapon that stops stacking its own juice

A cooldown on the player refuses a play asked for sooner than the gap, which is cheaper than a guard in the sheet.

```
On Ready
  -> FireJuice | Juice Player: Set Juice Player Cooldown  0.08
  -> FireJuice | Juice Player: Set Can Play While Playing  "ignore"

Player: On fire
  -> FireJuice | Juice Player: Play Juice  1.0
```

With `ignore`, a second play while the first runs is dropped rather than restarting it, so a held trigger reads as one continuous feel instead of a stutter.

### 6. The weapon-change beat, in two rows

The beat the designer tuned stays the beat; only the kick inside it changes.

```
Player: On weapon changed
  -> FireJuice | Juice Player: Replace Juice Card  "kick", {"verb": "punch", "amount": Weapon.recoil, "seconds": 0.12}
  -> FireJuice | Juice Player: Set Juice Card Field  "shot", "effect", Weapon.flash_colour
```

The replacement keeps the old card's name unless it brings one of its own, so every other row that addressed `kick` goes on working.

### 7. A settings screen built out of the list

For Each Juice Card walks the list and hands you each label, so a screen that lists a beat's parts needs to know nothing about what is in it.

```
On Settings Opened
  Condition: HitJuice | Juice Player: For Each Juice Card
    -> UI: add a switch labelled  feedback_label
    -> UI: set that switch to  HitJuice | Juice Player: Juice Card Is Enabled  feedback_label

On Switch Toggled
  Condition: UI.switch_on  is false
    -> HitJuice | Juice Player: Disable Juice Card  UI.switch_label
  Else
    -> HitJuice | Juice Player: Enable Juice Card  UI.switch_label
```

Juice Card Is Enabled is what makes the screen show the list as it actually is rather than as it was when the screen was built.

### 8. One accessibility switch for every screen effect in the game

Families are what a settings screen switches, and a channel throws the switch for every player at once.

```
On Ready
  -> HitJuice: add to group  "juice_players"

On Reduce Screen Effects Toggled
  -> AnyJuice | Juice Player: Mute Juice Family On Channel  "juice_players", "screen", Settings.reduce_screen_effects
```

Nobody has to find and untick a card. The seven families are audio, transform, camera, screen, pause, loop and signal.

### 9. An effect-strength slider that keeps the timing

Scaling amounts leaves every length alone, so half strength is the same beat felt less rather than a shorter beat.

```
On Effect Strength Changed
  -> HitJuice | Juice Player: Scale Juice Amounts  "", Settings.effect_strength
```

Leaving the family empty moves every card. Naming one moves only that family, which is how "keep the sound, soften the camera" is one row.

### 10. A snappier version of a whole beat, with nothing retuned

Retiming multiplies every length, wait and gap by the same number.

```
On Difficulty Set To Fast
  -> HitJuice | Juice Player: Scale Juice Timing  0.6
```

The shape of the beat survives: the holds still hold, the loops still loop, everything just arrives sooner.

### 11. Variety out of three cards and one row

Name three shakes `shake_a`, `shake_b` and `shake_c`, and let the list pick between them.

```
Enemy: On damaged
  -> HitJuice | Juice Player: Pick One Juice Card Starting With  "shake_"
  -> HitJuice | Juice Player: Play Juice  1.0
```

Pick One Juice Card Starting With ticks exactly one of them and unticks the rest, so a repeated hit stops sounding repeated with no branch in the sheet.

### 12. Shuffle a stretch of the beat

The same juice cards in a different order is variety that costs nothing to author.

```
Enemy: On damaged
  -> HitJuice | Juice Player: Shuffle Juice Cards Between  "shake_a", "shake_c"
  -> HitJuice | Juice Player: Play Juice  1.0
```

Both ends of the stretch are included, and the cards outside it are left exactly where they are.

### 13. A charge-up that holds until the button is let go

Hold Here parks the head; Release Hold carries on from the same card. Nothing ticks while it waits.

```
Player: On charge pressed
  -> ChargeJuice | Juice Player: Play Juice  1.0

On Hold Reached
  -> ChargeJuice | Juice Player: Hold Here

Player: On charge released
  -> ChargeJuice | Juice Player: Release Hold
```

The Hold card in the list is what raises On Hold Reached, so where the beat waits is a decision made in the Inspector rather than in the sheet.

### 14. A charge whose loop gets longer the further it is held

Set Loop Count moves the number on a Loop Back card, so one list covers every charge level.

```
Player: On charge level changed
  -> ChargeJuice | Juice Player: Set Loop Count  "loop_back", Player.charge_level

On process
  -> ChargeMeter: value = ChargeJuice | Juice Player: Loops Left  "loop_back"
```

Loops Left counts down in the running play, which is what a meter should be reading rather than a variable the sheet keeps in step by hand.

### 15. Hang anything at all off a point in the beat

An Emit Signal card says one word, and the sheet answers it.

```
On Juice Signal  (word = "impact")
  -> Camera: spawn impact particles
  -> Audio: play "crunch"
```

The card is where in the beat it happens; the rows are what happens. Moving the card in the Inspector moves the moment without touching the sheet.

### 16. A hit that interrupts its own wind-up

Jump To Juice Card moves the head of a running play, so the rest of the beat starts from the card you name.

```
Player: On hit landed
  Condition: SwingJuice | Juice Player: Is Playing
    -> SwingJuice | Juice Player: Jump To Juice Card  "impact"
  Else
    -> SwingJuice | Juice Player: Play Juice  1.0
```

Without the jump, a fast second hit would restart the wind-up the player had already seen.

### 17. Skip a card exactly once

A one-off exception that a Disable would have to be undone after.

```
Player: On first tutorial hit
  -> HitJuice | Juice Player: Skip Juice Card Once  "hitstop"
  -> HitJuice | Juice Player: Play Juice  1.0
```

The card is stepped over the next time the play reaches it, and the player forgets about it afterwards.

### 18. Undo everything a beat moved

Tween Property cards move real values on the object, so a cancelled beat needs a way back.

```
Player: On menu closed
  -> PanelJuice | Juice Player: Revert

Player: On scene left
  -> PanelJuice | Juice Player: Restore Initial Values
```

Revert stops the play and unwinds the changes last-first. Restore Initial Values puts every tweened value back without caring about order.

### 19. A cutscene skip for a beat

Skip To End does everything that is left at once, without the pauses between the cards.

```
On Skip Pressed
  Condition: IntroJuice | Juice Player: Is Playing
    -> IntroJuice | Juice Player: Skip To End
```

Every card from the head down is still felt, so the state the beat leaves behind is the state it would have left anyway.

### 20. One tuned beat, given to every enemy that spawns

Copy Juice Cards From takes another player's whole list as a copy, so retuning either afterwards leaves the other alone.

```
On Enemy Spawned
  -> NewEnemy.HitJuice | Juice Player: Clear Juice Cards
  -> NewEnemy.HitJuice | Juice Player: Copy Juice Cards From  Template.HitJuice
```

Clearing first is what stops the template's cards landing on top of whatever the new node was carrying.

### 21. Save a beat tuned while the game ran

The list writes out as a moment file, so a beat found by playing can be shipped.

```
On Debug Save Beat Pressed
  -> HitJuice | Juice Player: Save Moment File  "user://tuned_hit.tres"

On Ready
  -> HitJuice | Juice Player: Load Moment File  "res://eventsheet_addons/juice/impact.tres"
```

Only the four keys a file holds are written: a card that is switched off, and the timing words a list adds, are named in a warning and left out rather than written down half.

### 22. Wait exactly as long as the beat lasts

Juice Duration is the longest path through the list, so a wait can be written once and stay right as the list is tuned.

```
Enemy: On killed
  -> HitJuice | Juice Player: Play Juice  1.0
  -> System: wait  HitJuice | Juice Player: Juice Duration  seconds
  -> Enemy: queue free
```

Reorder the cards, add a hold, retime the whole thing, and the wait is still exactly right.

### 23. A progress bar for a long beat

Juice Progress runs 0 to 1 down the list, and Current Juice Card says which card the head is on.

```
On process
  Condition: IntroJuice | Juice Player: Is Playing
    -> IntroBar: value = IntroJuice | Juice Player: Juice Progress
    -> IntroLabel: text = IntroJuice | Juice Player: Current Juice Card
```

Both are read off the plan rather than off a tick, so asking them every frame costs nothing.

### 24. Tell the player why a card did nothing

On Juice Card Skipped carries the label and the reason, which is what turns a beat that felt wrong into a beat you can debug.

```
On Juice Card Skipped
  -> Debug Overlay: watch  label + " skipped: " + why
```

The reason is one of off, muted, chance, strength, or skipped once.

### 25. A beat built out of the beats of its parts

A Play Juice Player card plays another Juice Player from inside this one, at a share of this play's strength.

```
Boss: On phase change
  -> BossJuice | Juice Player: Play Juice  1.0
```

With `HeadJuice`, `ArmJuice` and `CameraJuice` named on Play Juice Player cards inside `BossJuice`, one row moves the whole boss. A nested play obeys the outer one, so stopping, skipping or restoring the outer list does the same to them.

### Other use cases

**Vehicle surfaces.** A player per surface type, each list holding its own shake, rumble and audio cards, and one row on the surface-changed trigger swapping which player the wheels talk to.

**Menu focus.** Every focusable control carries a hover player and a press player, and one channel row on the settings screen mutes the camera family across the whole menu without touching a single card.

**Boss telegraphs.** A wind-up list with a Loop Start and a Loop Back that goes round while the boss decides, and a Jump To Juice Card that leaves the loop the instant the attack commits.

**Crafting and looting.** A rarity beat per drop, played at a strength read off the item's tier, so a common and a legendary are the same list at two numbers rather than two lists that drift apart.

**Photosensitivity presets.** One switch on the settings screen throwing Mute Juice Family On Channel for the screen family, and a second slider running Scale Juice Amounts over the camera family, covering every beat in the game with two rows.

---

## Tips and common mistakes

- **The player needs a Juice behaviour beside it for the felt words.** The ten moment words are played by the Juice node under the same object. Without one, those cards do nothing and the player warns once, by name. The timing cards, Tween Property, Emit Signal and Play Player all work regardless.
- **Rename a card and every row that named it stops finding it.** Rows address cards by label. A renamed card leaves those rows compiling, running and doing nothing. The editor says so before the game runs, in the row's quiet amber state and in the Doctor's Juice Players section, but Rename Juice Card is still a rename of what the rest of the sheet has to say.
- **Stop Juice stops the LIST, not what it started.** A shake a card set going keeps running on its own. Use Revert when the point is to put back what the beat changed.
- **Only Tween Property cards are restorable.** Restore Initial Values and Revert put back values this player's tweens moved. A flash, a hitstop or a shockwave is something the screen did, and there is nothing to restore.
- **A cooldown of 0 lets every play through.** If a held trigger is stacking its own feedback, the fix is a cooldown, a `while_playing` of `ignore`, or both. Restarting is the default because a fresh hit usually should restart the beat.
- **Hold and Pause are not the same wait.** A Hold waits for the slowest card above it to finish and then waits its own time; a Pause waits a flat time whatever is still running. Getting these the wrong way round is the commonest reason a beat feels late.
- **A Loop Back with nothing to end it is caught, not hung.** A play gives up after its step limit and says so rather than looping forever, but a Loop Back always wants either a Loop Start or a Hold above it and a loop count that ends.
- **Editing a player whose moment-file slot is filled takes a copy first.** The file two other objects may be playing is never written into. The beat is unchanged; from the first edit row on, it is this object's own list.
- **Save Moment File cannot carry the whole list.** Only the four keys a file holds are written, so a switched-off card and the timing words a list adds are named in a warning and left out. Keep the list on the node when the timing words matter.
- **Preview shows most things, not everything.** In the editor, a shake, a punch, a tweened property and the cards that move another node are drawn; a hitstop and a flash are left out because they are things a running game does to time and to the screen. A beat that looks thin in preview is not necessarily thin.
- **Scale Juice Amounts and Scale Juice Timing change the list.** They are not a temporary lens: they multiply the values the cards hold. Scaling by 0.5 twice leaves the amounts at a quarter, so drive them from a setting's absolute value rather than applying them repeatedly.
