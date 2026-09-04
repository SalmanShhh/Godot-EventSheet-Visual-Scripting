# Music, Prompts, Text Effects and Animation - What Plays, Prompts, Speaks and Moves

Four jobs on the presentation side of a game, and every genre borrows all four. A song that follows
what is happening instead of looping under it. A prompt that asks the player for a button at the
right moment and shows the button they actually hold. Text that does more than sit there. And a
character that blends between animations instead of cutting between them.

They are on one page because they meet each other constantly: a note travels a lane to land on the
song's next beat, a line of dialogue ducks the music while it types itself out, a swing's blend tree
enters a state and the sheet reacts to it. Nothing here is a runtime. Every row compiles to plain
GDScript over Godot's own `AudioStreamSynchronized`, `RichTextLabel`, `AnimationTree`, `Skeleton3D`
and `Input` calls, with no plugin reference in the emitted file, and a line written by hand opens
back as the row that writes it.

## Table of Contents

1. [One song at a time](#one-song-at-a-time)
2. [Layers, stingers and getting out of the way](#layers-stingers-and-getting-out-of-the-way)
3. [The beat is read, never counted](#the-beat-is-read-never-counted)
4. [Asking the player for a button](#asking-the-player-for-a-button)
5. [The glyph is the thing in their hands](#the-glyph-is-the-thing-in-their-hands)
6. [A note that lands on the beat](#a-note-that-lands-on-the-beat)
7. [Text that moves](#text-that-moves)
8. [A line typed out](#a-line-typed-out)
9. [What the accessibility settings do to all of it](#what-the-accessibility-settings-do-to-all-of-it)
10. [The rest of what a blend tree does](#the-rest-of-what-a-blend-tree-does)
11. [Root motion: the animator's own step](#root-motion-the-animators-own-step)
12. [Bones: pointing one, asking where one is, holding one](#bones-pointing-one-asking-where-one-is-holding-one)
13. [What the Doctor says about a blend tree](#what-the-doctor-says-about-a-blend-tree)
14. [Tips and common mistakes](#tips-and-common-mistakes)

## One song at a time

The Audio rows play a sound **on a player**: the right shape for a footstep, the wrong shape for a
song. A song is one thing at a time, crossfaded rather than cut, that survives a scene change and
keeps playing under a pause menu.

The **Music** pack is that other shape. It installs as an autoload the same way Scene Flow and Save
System do, so every sheet reaches it by name with no node path and nothing to place in a scene.

A song is a **`MusicTrackResource`** file you own: the stream, its layers, its tempo, its bar length
and its loop points, saved wherever you keep your music. The pack ships none, and there is no list
of songs anywhere in the editor.

| Condition | Actions |
| --- | --- |
| **System** ▸ On start of layout | **Music** ▸ Play **"forest"**, fade **2** s |
| **Boss** ▸ On defeated | **Music** ▸ Crossfade to **"victory"** over **1.5** s |

```gdscript
extends Node


func _ready() -> void:
	get_node("Boss").defeated.connect(_on_boss_defeated)
	Music.play("forest", 2.0)


func _on_boss_defeated() -> void:
	Music.crossfade_to("victory", 1.5)
```

`"forest"` is a **name, not a path**. The Play row looks it up in the pack's Music Folder setting,
so moving your music folder is one setting rather than a search across every sheet. A full
`res://` path is still accepted for the song that lives somewhere else.

**The trap this removes.** Written by hand, a crossfade is two `AudioStreamPlayer` nodes, a tween per
fade, and a rule about which of the two is "current" that goes wrong the third time somebody changes
songs mid-fade. The pack keeps two decks and swaps them; the sheet only ever says which song and how
long.

## Layers, stingers and getting out of the way

Adaptive music is normally described as several stems started at the same moment and hoped for.
Hoping is the problem: two `AudioStreamPlayer` nodes started on the same frame drift apart over a
long track, and a pause makes it worse.

A track's layers are **one `AudioStreamSynchronized` stream**, so they cannot drift. Fading one is
a volume change on a stream that is already exactly where the song is.

| Condition | Actions |
| --- | --- |
| **Enemy** ▸ On spotted player | **Music** ▸ Fade layer **"drums"** to **1**, over **1.5** s |
| **Enemy** ▸ On lost player | **Music** ▸ Fade layer **"drums"** to **0**, over **4** s |
| **Dialogue** ▸ On line started | **Music** ▸ Duck by **8** dB, over **0.25** s |
| **Dialogue** ▸ On line finished | **Music** ▸ Unduck over **0.5** s |

```gdscript
extends Node


func _ready() -> void:
	get_node("Enemy").spotted_player.connect(_on_enemy_spotted_player)
	get_node("Enemy").lost_player.connect(_on_enemy_lost_player)


func _on_enemy_spotted_player() -> void:
	Music.fade_layer("drums", 1.0, 1.5)


func _on_enemy_lost_player() -> void:
	Music.fade_layer("drums", 0.0, 4.0)
```

**Set Layers** is the same thing said as a whole mix: `"pads, drums, brass"` fades those up and
everything else down, in one row. That makes it safe to fire on every state change, because it
states what the mix **is** rather than what changed, and a state that forgot to turn something off
cannot leave it on.

**Stinger** is one row for a flourish that ducks the music under itself for exactly as long as it
lasts and brings it back with nobody asking. **Duck** and **Unduck** are the two halves when you
want to hold it down for a line of dialogue, a radio call or a cutscene.

**The trap this removes.** A duck written by hand is a tween on a bus volume, and the bug is always
the same: two things duck at once, the first one finishes, and the music comes back up while the
second is still talking. The director counts its own ducks.

## The beat is read, never counted

Every beat answer here is **the stream's own playback position**, less the output latency your audio
device adds on the way out, turned into beats at the track's tempo. Nothing counts.

That distinction is the whole feature. A beat counter written in a process event accumulates float
error and drifts audibly against the song inside a minute, and it drifts differently on a machine
with a slow buffer. A position cannot drift, because it is the position.

| Condition | Actions |
| --- | --- |
| **Music** ▸ On beat | **Pulse** ▸ Set **scale** to **Vector2(1.1, 1.1)** |
| **System** ▸ Every tick | **Lamp** ▸ Set **energy** to **1 + Music.Beat Phase() * 0.4** |

```gdscript
extends Node


func _ready() -> void:
	Music.beat.connect(_on_music_beat)


func _process(delta: float) -> void:
	$Lamp.energy = 1 + Music.beat_phase() * 0.4


func _on_music_beat(number: int) -> void:
	$Pulse.scale = Vector2(1.1, 1.1)
```

**On Bar** fires on the first beat of every bar, and how many beats a bar holds is the track file's
own Beats Per Bar, so a waltz bars in three with nothing changed in the sheet. **On Beat Number**
fires every nth beat for a change that should land on the phrase rather than on each beat.

The expressions are the same reading from the other direction: **Beat Phase** runs 0 to 1 inside
every beat, which is exactly the shape a pulse, a bob or a breathing light wants. **Seconds To Next
Beat** is the wait before an action that should land on the beat. **Next Beat At** is the moment the
next beat lands, on the same engine clock the Timed Input rows measure a press with, which is what
lets the shipped **Beat Grade** row grade a press against a song.

**The trap this removes.** Latency. The position the stream reports is where it has got to
internally, and the player hears that position a few milliseconds later. Grading a press against the
untouched number marks early presses perfect and on-time presses late, and the amount is different
on every machine. The pack subtracts the audio server's own reported latency once, in one place.

## Asking the player for a button

The **Timed Input** rows already do the thinking: Open Input Window, Pressed In The Window, Window
Grade, Start Mash Count, Beat Grade, Off The Beat By. What they do not do is show the player
anything, and a quick-time event nobody can see is a quick-time event nobody can answer.

The **Prompts** pack is the showing. It is an autoload like Music, and it grades in the same two
words the window rows use, `"perfect"` and `"good"`, plus the third every prompt needs, `"miss"`.
A sheet that already branches on a window grade needs nothing rewritten.

| Condition | Actions |
| --- | --- |
| **Boss** ▸ On grabbed player | **Prompts** ▸ Prompt **"jump"** for **0.8** s at *Player* |
| **Prompts** ▸ On prompt hit + **Prompts** ▸ Grade is **"perfect"** | **Player** ▸ Set **grabbed** to **false** |
| **Prompts** ▸ On prompt missed | **Player** ▸ Take **10** damage |

```gdscript
extends Node


func _ready() -> void:
	get_node("Boss").grabbed_player.connect(_on_boss_grabbed_player)
	Prompts.prompt_hit.connect(_on_prompts_prompt_hit)
	Prompts.prompt_missed.connect(_on_prompts_prompt_missed)


func _on_boss_grabbed_player() -> void:
	Prompts.prompt("jump", 0.8, $Player)


func _on_prompts_prompt_hit(action: String, grade: String) -> void:
	if Prompts.grade_is("perfect"):
		$Player.grabbed = false


func _on_prompts_prompt_missed(action: String) -> void:
	$Player.take_damage(10)
```

That is a whole quick-time event: the glyph, the shrinking ring, the grade and both answers. The
other three shapes are the same moment asked differently. **Hold Prompt** wants the control held
down for a while, and letting go resets the hold, because a hold that survived being let go is not a
hold. **Mash Prompt** wants a number of presses, over the shipped mash rows. **Sequence** asks for
several controls one after another and fires once at the end carrying whether all of them landed,
with the first miss ending it.

**Cancel Prompt** takes whatever is being asked off the screen with no grade and no miss: the
cutscene was skipped, the enemy died first, the player walked away.

**The prompt is a scene, and the scene is yours.** `prompt.tscn` ships beside the pack as a starter
to copy and restyle. The director looks for children by name and leaves everything else alone: a
`Ring` gets the time left written into its `value`, a `Glyph` gets the texture, a `Label` gets the
Input Map's own words when no picture was drawn. A prompt scene with none of those children still
works; it just shows what you drew.

## The glyph is the thing in their hands

Which picture stands for a control is a **`GlyphSheetResource`** you own: one dictionary per device
family, keyed by control name. The device is whichever one the last input event came from, so a
player who puts the pad down and reaches for the keyboard sees keyboard glyphs on the very next
prompt, with nothing polling anything.

`plain_glyphs.tres` ships as a starter drawn as flat coloured circles **on purpose**. It is there so
the first run shows something; it is not a set to ship.

| Condition | Actions |
| --- | --- |
| **Player** ▸ On interactable entered | **HintIcon** ▸ Set **texture** to **Prompts.Glyph For("interact")** |
| **OptionsMenu** ▸ On value changed | **Prompts** ▸ Force device **"playstation"** |

```gdscript
extends Node


func _ready() -> void:
	get_node("Player").interactable_entered.connect(_on_player_interactable_entered)
	get_node("OptionsMenu").value_changed.connect(_on_optionsmenu_value_changed)


func _on_player_interactable_entered() -> void:
	$HintIcon.texture = Prompts.glyph_for("interact")


func _on_optionsmenu_value_changed(value: float) -> void:
	Prompts.force_device("playstation")
```

**Glyph For fixes the "Press E" problem across the whole game**, not just inside a prompt. A HUD
hint, a tutorial card and a rebinding screen all ask the same expression and all follow the
controller the player actually picked up.

**Force Device** is for the times the player's hardware is not the answer: an options screen showing
a layout on purpose, a tutorial card printed for one platform. `"auto"` hands it back to the last
input event.

**The trap this removes.** Guessing the device from `Input.get_connected_joypads()` says a pad is
plugged in, not that anyone is holding it. Half of desktop players have a controller connected and
are typing.

## A note that lands on the beat

The two packs meet here, and so does Timed Input. **Prompt On Beat** sends a note down a lane to
arrive on the song's next beat, which is a moment Music can answer exactly because it reads the
position rather than counting.

| Condition | Actions |
| --- | --- |
| **Music** ▸ On beat | **Prompts** ▸ Prompt on beat **"hit"** in lane *Lane* |
| **Prompts** ▸ On prompt hit | **Score** ▸ Add **100** to **value** |

```gdscript
extends Node


func _ready() -> void:
	Music.beat.connect(_on_music_beat)
	Prompts.prompt_hit.connect(_on_prompts_prompt_hit)


func _on_music_beat(number: int) -> void:
	Prompts.prompt_on_beat("hit", $Lane)


func _on_prompts_prompt_hit(action: String, grade: String) -> void:
	$Score.value += 100
```

A **lane** is a small scene, `lane.tscn`, shipped as a starter. Its `HitLine` child says where a note
has to reach on its moment, and its `Note` child is the hidden thing every note is a copy of, so the
art is the lane's and not the pack's. A lane with no `HitLine` lands its notes at its own left edge
rather than refusing to work.

**Without a Music director in the project a lane still works**: the note travels for the pack's Lead
Seconds instead of to a beat. That is deliberate. A rhythm-flavoured section in a game with no
adaptive music should not require the audio pack.

The hit and perfect windows are **milliseconds** on the director, because that is the unit rhythm
designers think in, and the same two words come back out of Grade Is.

## Text that moves

Godot's `RichTextLabel` already knows six effects as BBCode tags: `wave`, `shake`, `tornado`,
`rainbow`, `fade` and `pulse`. None of them had a word on the sheet, so a title that wobbles was a
tag typed by hand into a string, and a custom effect was a class nobody found.

| Condition | Actions |
| --- | --- |
| **Title** ▸ On start of layout | **Title** ▸ Set text to **"Starfall"** with **wave** |
| **Enemy** ▸ On killed | **DamageLabel** ▸ Set text to **"CRITICAL"** with **shake** |

```gdscript
extends Node


func _ready() -> void:
	$Title.bbcode_enabled = true
	$Title.text = "[wave amp=%s freq=5]" % (40 * float(Engine.get_meta("text_size_scale", 1.0))) + "Starfall" + "[/wave]"


func _on_enemy_killed() -> void:
	$DamageLabel.bbcode_enabled = true
	$DamageLabel.text = "[shake rate=20 level=%s]" % (5 * (0.3 if bool(Engine.get_meta("no_flashing", false)) else 1.0)) + "CRITICAL" + "[/shake]"
```

**Each effect fills its own knob.** A wave takes `amp`, a shake takes `level`, a tornado takes
`radius`, a rainbow and a pulse take `freq`, a fade takes `length`. Writing `amp` into a shake is
accepted by the parser and does nothing on screen, which is the single commonest thing to get wrong
about these tags and the reason the row has one Strength field rather than six.

The other three rows in the family:

| Row | Kind | Does |
|---|---|---|
| **Wrap Selection In Effect** | Action | Puts the tag around a stretch of the text already on the label, counted in characters, so one word shakes inside a calm sentence |
| **Clear Effects** | Action | Takes every tag back off by asking the label for its own parsed text, so it clears effects nobody here wrote |
| **Effect Is Active** | Condition | True while the label's text carries that effect's tag |
| **Install Text Effect** | Action | Teaches this label one `RichTextEffect` of your own, whose name the "custom" choice then writes |

**Custom effects are a door, not a list.** Point the Effect field at `custom`, type the bbcode name
your own `RichTextEffect` answers to, and the row writes that tag instead of one of the six. The
resource lives in a folder you own; the plugin ships none and knows none.

**The trap this removes.** `bbcode_enabled` starts **false**. A label handed a tag without it draws
the tag as literal characters, which is why every row that writes a tag turns it on in the line
above and why those templates are two statements rather than one.

## A line typed out

The Dialogue Kit owns a typewriter and keeps it. **Reveal Text** is the same idea for every other
label in the game: a sign, a tutorial card, a boss name, an item description.

| Condition | Actions |
| --- | --- |
| **Sign** ▸ On interacted | **SignText** ▸ Pause the reveal at character **12** for **0.4** s |
| | **SignText** ▸ Reveal **"The bridge is out."** at **40** chars/s |
| **SignText** ▸ On reveal finished | **Continue** ▸ Show |
| **Input** ▸ On **"interact"** pressed + **SignText** ▸ Is revealing | **SignText** ▸ Skip the reveal |

```gdscript
extends Node


func _on_sign_interacted() -> void:
	var __pauses_hold: Dictionary = $SignText.get_meta(&"reveal_pauses", {})
	__pauses_hold[int(12)] = float(0.4)
	$SignText.set_meta(&"reveal_pauses", __pauses_hold)
	$SignText.bbcode_enabled = true
	$SignText.text = "The bridge is out."
	$SignText.visible_characters = 0
	if $SignText.has_meta(&"reveal"):
		($SignText.get_meta(&"reveal") as Tween).kill()
	var __voice_sign: Node = null
	var __pauses_sign: Dictionary = $SignText.get_meta(&"reveal_pauses", {})
	var __step_sign: float = 1.0 / maxf(1.0, float(40))
	var __reveal_sign: Tween = $SignText.create_tween()
	$SignText.set_meta(&"reveal", __reveal_sign)
	for __at_sign: int in range(1, $SignText.get_total_character_count() + 1):
		__reveal_sign.tween_callback($SignText.set_visible_characters.bind(__at_sign)).set_delay(__step_sign)
		if __voice_sign != null:
			__reveal_sign.tween_callback(__voice_sign.play)
		if __pauses_sign.has(__at_sign):
			__reveal_sign.tween_interval(float(__pauses_sign[__at_sign]))
	__reveal_sign.tween_callback(_on_reveal_finished)


func _on_reveal_finished() -> void:
	$Continue.show()
```

**The reveal is a tween of callbacks, one per character, rather than one tween over the ratio.** That
is what buys the two things a typed line needs and a smooth interpolation cannot give: a sound on
each character, and a pause held at a named one. **Pause Reveal At** is the comma pause that makes a
typed line sound like speech rather than a printer, and it goes **before** the Reveal Text row
because it writes the pause down on the label for the reveal that follows to read.

**Skip Reveal answers in the same place a finished reveal does.** Both call `_on_reveal_finished`,
which is what On Reveal Finished compiles to, so the Continue prompt is written once and the second
press of the same button is one row. **Is Revealing** and **Revealed Fraction** are how one button
does both jobs: skip while it is typing, go on to the next line when it is not.

**Starting a second reveal on a label ends the first**, because the running tween is parked on the
label under a meta and killed before a new one starts. That is the difference between a player
pressing the button twice and two lines typing over each other.

**The trap this removes.** `RichTextLabel` has a `finished` signal, and it is not this. It is about
the document being **loaded**, not about a reveal ending, and a project that connects to it gets a
Continue prompt on the first frame. On Reveal Finished is a named moment the reveal's own tween
calls, so a sheet with a Reveal Text row and no On Reveal Finished event does not parse, which is the
plainest way a missing answer can announce itself.

## What the accessibility settings do to all of it

Two settings the Game Accessibility shelf writes as Engine metas are read by these rows, at the
moment the row runs, so a player turning one on mid-game is answered by the next line of text:

- **Text Size** (`text_size_scale`) multiplies an effect's own knob, so a wave grows with the text it
  is drawn on rather than staying the amplitude it was designed at.
- **Reduce Flashing** (`no_flashing`) calms what flashes. A shake drops to a third of its strength,
  which is a drift rather than a rattle. The two colour-cycling effects, rainbow and pulse, go to a
  frequency of **zero**, which is the engine's own way of spelling "hold still" rather than a second
  spelling invented here.

You can see both in the emitted lines above: `40 * float(Engine.get_meta("text_size_scale", 1.0))`
on the wave, and `5 * (0.3 if bool(Engine.get_meta("no_flashing", false)) else 1.0)` on the shake.
There is no row to remember and nothing to wire; the effect answers the setting because the tag's
number is the answer.

The prompt flash obeys the same setting, and a lane's notes are drawn at the player's text size where
they carry text.

## The rest of what a blend tree does

Nine rows already drive an `AnimationTree`: Travel To State, Set Blend, Is In State, Current State
Is, Tree Parameter, Is Tree Active, Set AnimationTree Active, Play One-Shot Animation. **All of them
keep their ids and their templates.** What they were missing was a field that knows the tree's own
names, and that was added to the rows themselves rather than beside them.

Everything a blend tree does is a value written into, or read out of, a magic string:

```
parameters/playback                  the state machine's own object: travel, start, where it is now
parameters/<space>/blend_position    where a blend space is sampled (a float, or a Vector2)
parameters/<layer>/blend_amount      how much of a Blend2 or an Add2 is mixed in
parameters/conditions/<name>         the booleans a transition advances on
```

Written by hand, every one of those is a string nothing checks and nothing complains about. As rows,
the string is assembled from a field that lists the tree's **own** names, read off the scene as text.

| Condition | Actions |
| --- | --- |
| **System** ▸ Every tick | **Anim** ▸ Set **Locomotion** blend to **move_input** |
| **Input** ▸ On **"attack"** pressed + **Anim** ▸ Is in state **["Idle", "Run"]** | **Anim** ▸ Travel to **&"Swing"** |
| **Player** ▸ Is locked on | **Anim** ▸ Blend layer **Aim** to **1**, over **0.2** s |

```gdscript
extends AnimationTree


func _process(delta: float) -> void:
	set("parameters/Locomotion/blend_position", move_input)
	if $Player.locked_on:
		create_tween().tween_property(self, "parameters/Aim/blend_amount", 1.0, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		if get("parameters/playback").get_current_node() in ["Idle", "Run"]:
			get("parameters/playback").travel(&"Swing")
```

The fourteen rows that landed beside the shipped nine:

| Row | Kind | Does |
|---|---|---|
| **Jump To** | Action | `start(state)`: puts the machine into a state at once, ignoring every transition. Travel To State is the everyday one; this is the cut |
| **Is In Any State** | Condition | True while the machine is in any of the states listed, for the attack that may start from a stand or a run |
| **Set Blend Position** | Action | Moves where a blend space is sampled. One number for a 1D space, a Vector2 for a 2D one |
| **Blend Toward** | Action | The same move taken over seconds, as a tween on the tree's own parameter |
| **Blend Layer** | Action | Mixes a Blend2 or Add2 in or out over seconds: the aim pose that fades on when a target is locked |
| **Set Condition** | Action | Writes one of the booleans the transitions advance on. The tree decides when to move; the sheet only says what is true |
| **Set Tree Time Scale** | Action | Slows or speeds everything under one TimeScale node without touching the game's clock |
| **Time In State** | Expression | How many seconds the machine has been playing its current state |
| **On State Entered** | Trigger | The moment the machine enters a state, with the name handed to the event |
| **On State Left** | Trigger | The moment the state it was in finishes |
| **On Animation Reached Marker** | Trigger | The frame a clip's play head crosses a named moment on its timeline |
| **Just Reached Marker** | Condition | True on that one frame and false after, unlike the shipped Reached Marker which stays true for the rest of the clip |
| **Apply Root Motion** | Action | On a CharacterBody2D and on a CharacterBody3D. See the next section |

**The two state moments are real signals, and they are not the tree node's.** They belong to the
playback object under `parameters/playback`, so the `_ready` line reaches through the tree to it:

```gdscript
func _ready() -> void:
	get_node("Anim").get("parameters/playback").state_started.connect(_on_anim_state_started)
```

which is exactly the line a hand-written project writes to hear the same thing.

**The trap this removes.** `travel(&"Swng")` walks nowhere, at run time, in silence. The state,
blend space and layer fields list the names the tree really declares, read out of the scene as text
so a tree kept in a `.tres` is followed as readily as one kept in the scene.

## Root motion: the animator's own step

Root motion is the animation moving the character rather than a number in the sheet moving it. The
swing steps forward because the animator made it step forward, and the code's only job is handing
that step to the body.

| Condition | Actions |
| --- | --- |
| **System** ▸ Every physics tick | **Player** ▸ Apply root motion from *$Anim*, scale **1** |
| | **Player** ▸ Move and slide |

```gdscript
extends CharacterBody3D


func _physics_process(delta: float) -> void:
	velocity = (basis * $Anim.get_root_motion_position()) / delta * 1.0
	quaternion *= $Anim.get_root_motion_rotation()
	move_and_slide()
```

**The division by `delta` is the whole of the arithmetic**, and it is the half everybody drops. A
velocity is a distance per second; root motion is a distance per **frame**. A metre forward in half a
step is two metres a second, and the same animation played on a machine running at half the frame
rate has to come out the same speed.

**The 3D form turns the animator's step by the body's own basis first**, because the animation was
authored facing forward and the character is facing wherever it is facing. The 2D twin has no basis
to turn by: the tree still answers in three dimensions, so the row takes the x and the y of its
answer and leaves the z alone.

Put the row in a **physics** tick, before Move And Slide. The tree is stepped in the physics frame
when its Callback Mode is physics, and reading root motion from an idle frame reads whatever the
last physics step left there, twice on a fast machine and never on a slow one.

## Bones: pointing one, asking where one is, holding one

A rig was the one part of an animated character the sheet could not reach. Everything else about an
animation is a clip name or a blend value; a bone is an index inside a skeleton. The three things
games actually do with one now have words.

**In 3D a bone is an index** in a Skeleton3D that a name resolves to. **In 2D a bone is a node**, a
Bone2D under the Skeleton2D, so the 2D rows are node-scoped on Bone2D and address it the way every
other 2D row addresses a node. The words are the same in both.

| Condition | Actions |
| --- | --- |
| **Player** ▸ Is locked on | **HeadLook** ▸ Point **"Head"** at *Player.locked_target*, over **0.2** s, weight **1** |
| **Weapon** ▸ On fired | **Muzzle** ▸ Set **global_position** to **Skeleton3D.Bone Position("hand.R")** |

```gdscript
extends Node3D


func _process(delta: float) -> void:
	if $Player.locked_on:
		$HeadLook.bone_name = "Head"
		$HeadLook.target_node = $HeadLook.get_path_to($Player.locked_target)
		$HeadLook.duration = 0.2
		$HeadLook.influence = 1.0


func _on_weapon_fired() -> void:
	$Muzzle.global_position = ($Skeleton3D.global_transform * $Skeleton3D.get_bone_global_pose($Skeleton3D.find_bone("hand.R"))).origin
```

**Point Bone At in 3D sets four dials on the engine's own `LookAtModifier3D`** rather than doing the
maths itself, and that is the point of it. The modifier already knows how to ease into a look, how to
respect the neck's limits and how to blend out again, and none of that is worth writing again in a
template. The modifier node has to be under the skeleton already; this row is the sheet's hand on its
dials, and it keeps aiming every frame whether or not the sheet asks again.

The 2D twin has no modifier to lean on, so it does the one line the modifier would have done: turn
the bone toward the thing, this frame's share of the seconds asked for. Asked every tick it eases;
left at a whole weight over a very short time it snaps.

**Set Bone Pose Override** holds a bone somewhere the animation did not put it, with a **strength**,
so a hit reaction twists the spine a little while the run keeps running. Setting the amount back to 0
hands the bone back to the animation.

**The trap this removes.** `get_bone_global_pose` is global to the **skeleton**, not to the world. A
muzzle flash placed at the raw pose appears wherever the skeleton's own origin happens to be, which
looks correct at the world origin and wrong everywhere else. Bone Position multiplies it back out by
the skeleton's transform, which is what makes the number mean what its name says.

## What the Doctor says about a blend tree

Two things a blend tree accepts in complete silence, both of them wrong, both now named before the
game runs. They are **notes, never errors**, and they follow the quiet sheet: amber on the row, the
words in the triage inbox and in the selected row's help strip, and nothing drawn inside the row
itself.

- **A travel to a state no tree in the scene declares.** `travel(&"Swng")` walks nowhere and reports
  nothing. The note names the state, and offers the nearest name the tree really has when there is
  one close enough.
- **A vector written into a one-dimensional blend space.** `set()` accepts it and drops everything
  but the x, without a word. The note says which space, and that it is one-dimensional.

Both are answered by the **scene** rather than by the sheet, so a script that no single scene runs
has nothing to be checked against and is passed over in silence rather than reported as wrong.

## Tips and common mistakes

- **Make the Music bus before the first Play.** The director plays out on the bus named in its own
  setting, `Music` by default, and Set Music Volume writes the same bus an options slider does. No
  bus, no volume control, and the pack's debug mode is what says so.
- **A track name is not a file path.** Play looks the name up in the Music Folder setting. Renaming
  the folder is one setting; retyping the path in nine sheets is not.
- **The music does not stop for a pause menu.** The director runs while the tree is paused on
  purpose, so the song plays under the menu. Pause is the row that stops it, and Resume carries on
  from the same place rather than starting the track again.
- **Every layer must be the same length as the song.** They play as one synchronized stream. A layer
  half the length is a layer that ends half way.
- **Switch To Clip needs an interactive stream.** `AudioStreamInteractive` arrived in Godot 4.3. On
  any other stream the row does nothing and the pack's debug mode says why.
- **Grade Is asks about the last prompt to end**, not about the one that is open. Ask it under On
  Prompt Hit, where the answer is about the prompt that just fired the event.
- **Register both autoloads.** Every Music and Prompts row addresses `Music.` or `Prompts.` by name.
  Without the registration the emitted lines have nothing to talk to, and the error arrives at run
  time.
- **Replace the starter glyph sheet.** `plain_glyphs.tres` is flat coloured circles on purpose. It
  proves the wiring and it is not art.
- **Turn BBCode on for a label you tag by hand.** The rows do it for you in the line above. A tag on
  a label without it is drawn as characters, which is the first thing to check when an effect
  "does not work".
- **Pause Reveal At goes before Reveal Text.** It writes the pause down on the label, and the reveal
  that follows reads it. After the reveal row it applies to the next line, which is a bug that looks
  like a timing problem.
- **A shake is not the row to reach for twice.** Two shaking things on one screen read as a broken
  screen. The engine's own effects are strongest used sparingly, and Reduce Flashing exists because
  some players cannot ignore them.
- **Apply Root Motion belongs in a physics tick, before Move And Slide**, and the tree's Callback
  Mode has to match. Reading root motion in an idle frame reads whatever the last physics step left.
- **Set Condition does not move the machine.** It writes a boolean the transitions read; the tree
  decides when to advance. If nothing moves, the transition is not drawn to advance on that
  condition.
- **The look-at modifier has to exist.** Point Bone At in 3D sets dials on a `LookAtModifier3D` under
  the skeleton. There is no row that creates one, because a modifier's place in the modifier stack is
  a rig decision.
- **A bone pose is skeleton space until you multiply it out.** If a weapon attaches correctly at the
  world origin and drifts everywhere else, that multiplication is the missing line.
