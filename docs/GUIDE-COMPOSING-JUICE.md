# Composing Juice: The Beat A Hit Is Made Of

A hit that lands well is never one thing. It is a shake, a freeze, a flash, a crunch, a rumble in
the hand and the health bar catching up a moment later, and the reason it feels good is that those
things happen in an order, at different strengths, at different distances. Writing that out as six
timers and a boolean per effect is how most games do it, and it is why nobody ever tunes it twice.

This guide is the other way: **a beat is written down, once, as rows**, and then it is played by
name. It covers the Moment block and its four timing words, the Feedback Player and the list of
cards an object carries, the rows that edit that list while the game runs, strength and place and
range, playing a beat backwards or turning it around mid-play, channels, springs and curves under
any property, blink patterns, audio sweeps and mix snapshots, haptics, the sequencer, and a bar
whose underlay trails the value down. It closes with what all of it costs on a phone and in a
browser tab.

Everything here is ordinary Godot underneath: signals, groups, tweens, resources and plain typed
GDScript in your own project folder. Nothing invents a parallel environment to learn.

## Table of Contents

- [Three homes, one shape](#three-homes-one-shape)
- [The Moment block, and its four timing words](#the-moment-block-and-its-four-timing-words)
- [Where it happened, and how far it reaches](#where-it-happened-and-how-far-it-reaches)
- [Backwards, reverted, skipped, put back](#backwards-reverted-skipped-put-back)
- [What a beat says while it plays](#what-a-beat-says-while-it-plays)
- [The Feedback Player: the list an object carries](#the-feedback-player-the-list-an-object-carries)
- [Every card, by its label](#every-card-by-its-label)
- [Channels: one row heard by everything listening](#channels-one-row-heard-by-everything-listening)
- [Springs under any property](#springs-under-any-property)
- [Curves you own](#curves-you-own)
- [Blink: a rhythm as a file](#blink-a-rhythm-as-a-file)
- [The room going under: audio sweeps and snapshots](#the-room-going-under-audio-sweeps-and-snapshots)
- [Haptics: a shape in the hand](#haptics-a-shape-in-the-hand)
- [The sequencer: a grid of moments on a beat](#the-sequencer-a-grid-of-moments-on-a-beat)
- [A bar that lags](#a-bar-that-lags)
- [What a beat costs on a phone and in a browser](#what-a-beat-costs-on-a-phone-and-in-a-browser)

---

## Three homes, one shape

A beat is a list of felt things, each with how much, which extra word, and how long. That list has
three homes, and they hold the same shape:

| Home | What it is | Best for |
| --- | --- | --- |
| A **moment file** (`MomentResource`) | A `.tres` in your project holding the steps | A beat several objects share: the standard hit, the standard death |
| A **Feedback Player** node | A node under one object, whose Inspector is the list | This object's own beat: this enemy's hit, this button's hover |
| A **Moment block** | A block of rows in the sheet, its children the steps | A beat with timing in it, read in the sheet beside the event that fires it |

All three are played by the same runner, so a beat behaves identically wherever it was written, and
there are doors between them: **Save Moment As File** writes a block or a player's list out, and
**Open Moment File As Block** and **Load Moment File** read one back in.

Pick the home by who the beat belongs to, not by what it does. Six starter files ship beside the
Juice pack - `impact`, `kill`, `triumph`, `danger`, `calm` and `cut` - and they are ordinary
resources: open one, retune it, rename it, duplicate it, or delete all six. There is no house set of
beats anywhere in the plugin, because how a game feels is the game's.

---

## The Moment block, and its four timing words

A file is the right home for a beat whose steps all happen at once. A beat with **timing** in it -
the shake now, the sound a frame later, the scale settling only once the sound has finished - wants
to be read in order. That is a **Moment block**: a block whose children are its steps, a timing word
on the left and any actions at all on the right.

```
Moment  impact  (strength, from)
  At 0 s            -> Enemy | JuiceBehavior: Moment Step  "shake"  0.4
  At 0.05 s         -> Enemy | Audio: Play Sound  "hit.ogg"
  Then 0.02 s       -> Enemy | JuiceBehavior: Moment Step  "flash"  1.0
  Hold, then 0.1 s  -> Enemy | Tween: Tween Property  "scale"  Vector2(1, 1)  over 0.2 s
```

| Word | When the step runs |
| --- | --- |
| **At** | That many seconds after the moment began. Two steps At the same number happen together. |
| **Then** | That many seconds after the step above it started. |
| **Hold** | When the slowest step above has finished, plus a delay of its own. |
| **Loop Back** | Back to the last Hold (or the top) for that many more passes. |

A step that says how long it **lasts** is what a Hold waits for; a step that says nothing counts as
instant, which is the common case. Each step also picks its clock: game time follows `time_scale`,
so a slowmo stretches the beat with everything else, while real time ignores it, which is what the
step after a hitstop wants.

The block compiles to one ordinary coroutine on the host,
`func moment_impact(strength: float = 1.0, from: Node = null)`, so what the sheet plays is a
function a hand-written script could have held - and a hand-written one of that shape opens back as
the block. **Moment "impact"** plays it: the row looks for a moment written as rows on the host
first and falls through to a file when there is none, so a game can keep some of its beats in files
and write the rest down in the sheet without either row knowing the difference.

Reorder the steps by dragging the rows, the way you reorder any rows. There is no widget inside the
block to press: the play, stop, skip and restore buttons live on the resting toolbar's **Moment**
segment, which appears while a row about a beat is selected.

---

## Where it happened, and how far it reaches

A moment played on every enemy in a room is one beat felt ten times over. **Play Moment At** takes a
place and a range instead: the strength falls off between the two, and a moment that happened
outside the range does not play at all.

```
On Bomb exploded
  -> Player | JuiceBehavior: Play Moment At  "kill"  1.0  from *Bomb*  within 600  (smooth)
  -> Player | JuiceBehavior: Set Moment Strength  Settings.effect_strength
```

The falloff is a word on the row: `linear` is a straight line to the edge, `smooth` rounds the
shoulders so a near blast keeps more of itself, and `none` holds full strength right up to the edge.
The distance is measured once per play, from the place to whoever is watching - the active camera,
or the host itself in a game with no camera. A range of `0` is no range at all: the moment plays
everywhere, at full strength.

**Set Moment Strength** is the other dial: one number every moment this node plays is scaled by, for
a quiet scene at `0.4`, a boss fight at `1.5`, or whatever the player chose in the options menu.
**Moment Strength** answers what that number currently is, which is what the options slider reads to
draw itself.

---

## Backwards, reverted, skipped, put back

A hover-in and a hover-out are one beat played two ways. An intro somebody has seen twenty times is
a beat they want to be over. A scene on its way out wants everything a beat moved put back. Four
rows cover all of it, and none of them needs a second beat kept in step with the first by hand.

```
On Card mouse entered
  -> Card | JuiceBehavior: Moment  "hover"  1.0
On Card mouse exited
  -> Card | JuiceBehavior: Revert Moment  "hover"
On Skip pressed
  -> Game | JuiceBehavior: Skip Moment To End  "intro"
On Level exiting
  -> Game | JuiceBehavior: Restore Moment Values  ""
```

**Play Moment Backwards** plays the beat from its last step to its first. Every step is in the walk
either way, and the amounts are scaled and held to the no-flashing ceiling exactly as they are
forwards.

**Revert Moment** turns a beat that is *still playing* around from where it is. Every value its
steps wrote walks home to what it was when the beat began, over the beat's own length, so a
hover-out does not have to know how far the hover-in got. The steps that cannot be undone - a shake
already felt, a hitstop already let go - are stepped over on the way back rather than fired again.

**Skip Moment To End** ends the beat now, on the values it would have finished on: a held effect
lands at full strength, a freeze lets time go, a shake settles.

**Restore Moment Values** puts back every value a beat moved, to what it was the FIRST time that
beat touched it rather than what the last play left behind. Leave the name empty and every moment
this node has played is put back, which is what a scene wants on the way out. It plays nothing, and
it never undoes anything that was not a beat's doing.

---

## What a beat says while it plays

A beat used to happen and the sheet heard nothing. Four triggers and three readings fix that, and
they are ordinary signals on the behaviour, so anything that can hang off a trigger can hang off a
beat.

```
On JuiceBehavior moment finished
  -> Music | MusicBehavior: Fade Layer  "drums"  to 0  over 2 s
On JuiceBehavior moment step
  -> HUD | HUDKitBehavior: Set Label  "debug"  JuiceBehavior.Moment Step Name
```

| Row | Kind | What it says |
| --- | --- | --- |
| On Moment Started / On Moment Finished | triggers | The two ends of a play. The finish carries whether it was cut short |
| On Moment Step | trigger | Each step as it is reached, carrying the step's own label |
| On Moment Skipped | trigger | Somebody skipped it to the end |
| Moment Is Playing / Moment Is Reverting | conditions | Whether a beat is running, and whether it is running backwards home |
| Moment Was Cut Short | condition | The last play ended early rather than finishing |
| Moment Progress / Moment Elapsed | expressions | How far through, `0` to `1`, and how many seconds in |
| Moment Step Name | expression | The label of the step the beat is on |

A second play of the same beat while the first is in the air closes the first one, cut short, rather
than running two copies of it over each other.

---

## The Feedback Player: the list an object carries

A moment file is shared between objects. Sometimes the beat belongs to ONE object, and lives better
on the object itself. That is the **Feedback Player**: a node you add under any object, holding the
list of feedbacks that object plays. Its Inspector is the list; the sheet's side of it is one row
that never changes as the list is tuned.

```
On Enemy damaged
  -> HitFeedback | FeedbackPlayer: Play Feedbacks  at 0.6
On Enemy died
  -> HitFeedback | FeedbackPlayer: Play Feedbacks And Wait  at 1.0
  -> Enemy | Object: Destroy
```

Each feedback is a **card**: a stripe coloured by its family, a drag handle to reorder it, a fold
arrow, a tick box, its label, a badge saying how long it takes, and a menu. Under the list sits
**Add a feedback**, a searchable dropdown grouped by family.

![The Feedback Player's Inspector: four cards, one of them unfolded](images/feedback-player-inspector.png)

The head counts the cards and adds up the **longest path** through the list: cards between two holds
run at once, so a stretch is as long as its slowest card, and the holds and pauses add up. That is
the same number the **Feedbacks Duration** expression answers, so a row can wait exactly as long as
the beat lasts without the number being typed twice.

Ten of the card words are the same words a moment file holds - shake, hitstop, slowmo, flash, punch,
zoom, shockwave, chromatic, pulse and the screen-effect hold - and they are played by the Juice
behaviour beside the player, which is why one goes under the same object. Four more move the head
rather than being felt (**Pause**, **Hold**, **Loop Start**, **Loop Back**), and three are neither a
feeling nor a wait (**Tween Property**, **Emit Signal**, **Play Player**, which plays another player
from inside this one at a share of this play's strength).

Unfold a card and it opens: what that feedback does, **Active**, **Label**, **Chance**, a **Timing**
foldout (delay, cooldown, repeat and interval, the clock, a strength window it only plays inside,
skip on stop), and then the card's own fields drawn with the real Inspector drawers. While the game
runs, the values the play is writing back are shown greyed, through Godot's own remote Inspector.

**Play** on the Inspector strip samples the list in the editor and applies it to the object, and
**Stop** and **Restore** put the object back the way they found it; the scene's saved bytes are
never touched. Only the three things an editor can honestly show are drawn - a shake as a wobble, a
punch as a swell, and a tweened property walking to its value - because a hitstop and a flash are
things a running game does to time and to the screen. **Debug view** draws the timeline of the plan,
a bar per card at the time it starts, which is how you see why the flash came late.

---

## Every card, by its label

Everything the Inspector's list does has a row, and every one of them names ONE card by its
**label** - the name you typed on the card, or, for a card you never named, its own word. That is
the whole addressing scheme, so a list you tuned in the Inspector and a list your sheet retunes can
never disagree about which step is meant.

```
On Weapon changed
  -> FireFeedback | FeedbackPlayer: Replace Feedback  "kick"  with  {"verb": "recoil", "amount": Weapon.recoil}
  -> FireFeedback | FeedbackPlayer: Set Feedback Field  "shot"  "effect"  Weapon.sound
On Options screen shake changed
  -> FireFeedback | FeedbackPlayer: Scale Feedback Amounts  "camera"  Settings.shake_percent
```

The rows fall into four groups. The **editing** rows are the Inspector's own gestures: Add Feedback,
Insert Feedback Before, Replace Feedback, Remove Feedback, Move Feedback To, Enable Feedback and
Disable Feedback, Set Feedback Field, Set Feedback Timing, Set Feedback Chance, Set Feedback Label,
Duplicate Feedback, Clear Feedbacks, Copy Feedbacks From, Load Moment File and Save Moment File, Set
Player Strength, Set Player Cooldown and Set Can Play While Playing.

The **running-game** rows are the ones a designed list cannot have: Mute Feedback Category (and Mute
Feedback Category On Channel) silences a whole family at once, which is the accessibility option -
one row per switch; Scale Feedback Amounts is the effect-strength slider, where half is still the
same beat; Retime Feedbacks multiplies every length and wait, so a snappier version needs nothing
retuned; Shuffle Feedbacks Between reorders a stretch; Pick One Feedback Of ticks one of several and
unticks the rest; Jump To Feedback, Skip Feedback Once, Set Loop Count, Hold Here and Release Hold
move the head of a play that is already running.

The **asks** are Feedback Is Playing, Has Feedback, Feedback Is Enabled, the looping condition For
Each Feedback, and the readings Feedback Count, Feedback Label At, Feedback Field, Feedback Progress,
Feedback Duration, Current Feedback and Loops Left. A settings screen is For Each Feedback over the
list, one switch per label, each one Disable Feedback on the label it is about.

The **triggers** are On Feedbacks Started and On Feedbacks Finished, On Feedback Started, On Feedback
Finished and On Feedback Skipped (which carries why: off, muted, chance, strength, or skipped once),
On Feedback Signal, On Hold Reached and On Loop.

An edit row never writes into a moment file. A player whose file slot is filled is playing a beat
other objects may be playing too, so the first edit takes a copy of it into this list and lets the
slot go: the shared beat is unchanged, and this one is this object's own.

**When a label names nothing.** Rename a card and every row that named it goes on compiling, goes on
running, and does nothing. The editor says so before the game runs: the row takes the quiet amber
state, and the sentence is in the Doctor's Feedbacks section and in the row's help strip once the
row is selected. It stays quiet without evidence, so a sheet no scene runs, a scene with no Feedback
Player in it, and a label that comes from an expression all earn nothing rather than a guess.

---

## Channels: one row heard by everything listening

A quake should shake every prop in the level. A hit should shake the health panel. Neither wants a
list of references, and neither is really about the camera. **A channel is a group** - the same
groups the Node dock shows - so one row says the shake and everything listening hears it.

```
On Fridge ready
  -> Fridge | JuiceBehavior: Listen On Channel  "props"  and shake  "this node"
On Camera ready
  -> Camera | JuiceBehavior: Listen On Channel  "world"  and shake  "the camera"
On Truck passed
  -> Truck | JuiceBehavior: Shake Channel  "props"  with 0.5  for 0.6 s
```

A listener says what it shakes when the channel speaks: **the camera** (the pack's own screenshake,
held up for as long as the broadcast asked), **this node** (the node the behaviour is on, riding the
same noise around the pose it was found in - a HUD panel, a lamp, a sign), or **the screen** (the
colour channels, through Chromatic Shake). The answer is the node's, not the channel's, so a lamp
listening on two channels rattles the same way for both; a node that wants to do two different
things is two nodes. **Stop Listening On Channel** takes it off one channel and settles it back,
leaving every other channel it listens on alone.

The same three words answer on the Juice 3D pack, so one Shake Channel row reaches a prop in a 3D
level and a panel on the 2D interface and shakes both. **Play On Channel** does the same for a whole
group of Feedback Players.

Nothing new is invented for any of this: Shake Channel is one `call_group`, a listener is a node in
that group, and the Node dock already tells you which groups a node is in.

---

## Springs under any property

A tween knows where it is going. A **spring** does not: it is pulled toward a value and overshoots,
which is why a spring reads as alive and a tween reads as animated. **Spring Property To** and
**Bump Property** take a property path, spelled exactly as the Inspector shows it - `modulate`,
`position`, `rotation_degrees`, `scale:x` - and write that property every frame until the spring
settles.

```
On Coin collected
  -> HUD | SpringBehavior: Bump Property  "scale"  Vector2(0.35, 0.35)
  -> HUD | SpringBehavior: Set Spring Damping And Frequency  "scale"  0.35  6.0
On Menu opened
  -> Panel | SpringBehavior: Spring Property To  "position:y"  240
```

Any number, `Vector2`, `Vector3` or `Color` property works. The type is read once, on the first row
that names the property, and the spring hands the same type back - so a camera's zoom, a light's
energy, a post effect's strength, a label's font size and a bar's value are all the same row with a
different path in it. There is no pack per target.

A **Bump** is the fastest juice there is: it adds velocity and never moves the target, so the
property leaves where it was and comes back on its own. One row, no duration, nothing to undo.
**Set Spring Damping And Frequency** is the two numbers a spring really has (how fast the bounce
dies out, and how many swings a second it wants), **Clamp Spring Between** stops it dead at a wall
instead of pushing through, and **Spring Is Settled**, **Spring Value Of** and **Spring Velocity Of**
read it back - drive a lean or a stretch off the velocity and the motion shows its own speed.

---

## Curves you own

Godot's transitions and easings are a fixed set. A **Curve** resource is not: it is a file in your
project, drawn in the Inspector, and **Tween Property Along Curve** reads it four ways.

```
On Chest opened
  -> Lid | TweenBehavior: Tween Property Along Curve  "rotation_degrees"  -95  over 0.4 s  (overshoot, to destination)
On Chest closed
  -> Lid | TweenBehavior: Tween Property Back  "rotation_degrees"  over 0.25 s
```

| Mode | What the property does |
| --- | --- |
| `to destination` | Travels from where it is to the final value along the curve. The everyday one |
| `relative` | Adds the final value times the curve to where it started - a nudge that returns if the curve does |
| `absolute` | Takes the final value times the curve outright: the curve *is* the motion |
| `remap` | Maps the curve's `0` and `1` onto two numbers you name |

A curve that rises past `1` and settles back is an overshoot; one that spikes early and falls away is
a flare. Two starter curves ship beside the Tween pack, and they are ordinary files: open one, drag
its points, rename it, duplicate it, or delete both. Nothing in the pack names them.

The first curve tween on a property records what that property held, and **Tween Property Back**
returns to that number however many tweens have run since - which is what a hover-out, a lid closing
or a panel sliding home is, without the number being typed twice. **Tween Property And Wait** is the
same tween with the rows under it waiting on it, so a beat reads as one column of rows rather than a
timer guessed to match.

---

## Blink: a rhythm as a file

Flash has one rhythm, its interval. A **blink pattern** has as many as you like: it is a
`BlinkPatternResource` holding a list of phases, and a phase is *on for this long, off for that long,
this many times*. Six fast winks and then three slow ones is two phases.

```
On Player hurt
  -> Player | FlashBehavior: Blink  starter_blink_invulnerable  for 1.5 s
On Player invulnerability ended
  -> Player | FlashBehavior: Stop Blink
```

**Blink Phase** answers which phase is playing, counting from `1`, so a row can tell the fast winks
from the slow ones that follow them, and **Is Blinking** is the guard. One starter file ships beside
the pack; retune it, rename it, duplicate it into the rhythm this game actually wants, or delete it.

A pattern is never a strobe. When the project has asked for no flashing - the plain `no_flashing`
metadata on `Engine` that every flashing thing here reads - no part of a blink is allowed to be
shorter than `0.4` seconds, and the host stays on the screen and steps between full and faint
opacity instead of disappearing. The pattern still plays, at a rate nobody can be hurt by. The same
ceiling holds every amount a moment's steps write, so a beat cannot be turned into a strobe by
raising its strength either.

---

## The room going under: audio sweeps and snapshots

Switching a bus is one thing (dry, then underwater). Moving it is what a hit actually sounds like:
the room going under for a tenth of a second and coming back.

```
On Boss hit
  -> Game | Audio Server: Muffle Bus  "Master"  to 400 Hz  over 0.08 s
  -> Game | Audio Server: Dive Bus Volume  "SFX"  to -8 dB  over 0.08 s
  -> Game | JuiceBehavior: Hitstop  0.12
On JuiceBehavior hitstop finished
  -> Game | Audio Server: Restore Bus  "Master"  over 0.25 s
  -> Game | Audio Server: Restore Bus  "SFX"  over 0.25 s
```

**Muffle Bus** walks a low-pass filter's cutoff down, **Dive Bus Volume** walks a level down through
an amplify effect, and **Wash Bus** grows a reverb's wet amount behind the sound with its dry left
alone. **Restore Bus** walks every kind this bus was swept by back to where it rested *before the
first sweep touched it* - home is where the mix was to start with, not where the last beat left it,
which is why a beat can muffle and dive without ever saying how to come back. **Bus Is Sweeping** is
the guard before a second sweep over the top of the first.

Three things worth knowing. The effect is **added once and kept**: the first Muffle on a bus adds a
low-pass filter opened so wide it does nothing, and every later Muffle reuses it, so your bus layout
gains one slot per kind and never gains another. The player's own volume is **never touched**,
because that number is theirs and a beat that moved it would leave their setting wherever the beat
happened to end. And **no snapshot ships**: **Snapshot Buses As** writes down every bus's level, mute
and solo under a name you choose, **Recall Bus Snapshot** puts it back (levels walked, mutes and
solos cut), and **Bus Snapshot Exists** is the guard. Take the first one at startup, call it
`normal`, and every later recall has somewhere honest to come back to.

---

## Haptics: a shape in the hand

A game does not think in motor strengths. It thinks in shapes: this is a tap, this is an alarm, the
car is on gravel. A shape is a **HapticPatternResource** you own - how hard, how long, how many
times, and the air between the pulses - and one row plays it on whatever the player is holding.

```
On Weapon fired
  -> Game | Vibration: Haptic  pattern_recoil
On Options haptics slider changed
  -> Game | Vibration: Set Haptic Strength  Settings.haptics_percent
```

**Haptic Emphasis** is one short strong knock with no file behind it; **Haptic Continuous Start** and
**Haptic Continuous Stop** are the engine rumble; **Haptic Is Playing** and **Haptics Can Be Felt**
are the two questions. **Set Haptic Strength** is the player's own dial, and every haptic row
multiplies itself by it, so `0` turns the whole vocabulary off with no branch anywhere in a sheet.
No Flashing does not touch it: a rumble is not light.

Nothing ships. There is no house "success" and no house "failure", because how a game feels in the
hand is the game's; a new pattern opens on the one shape that is not a taste, a single short tap at
full strength. The gap is what makes a repeat a repeat, so the air between pulses sits beside the
repeat count in the file.

**The silence is deliberate.** On the web there is nothing to rumble, and on a desktop with no pad
there is nothing either, so the rows do nothing at all, quietly, with no warning per hit. The
Doctor's ship-it section says it once for the whole project, because it is one decision: carry the
same beat in sound or picture too.

---

## The sequencer: a grid of moments on a beat

Lights that pulse on the beat are, in most games, a counter and a modulo in a per-frame row, and
changing the pattern means rewriting the arithmetic. What the pattern actually is is a grid: a track
per thing that can fire, a step per beat subdivision, and a name in the cells that should fire. A
**SequenceResource** is that grid, and these rows play it.

```
On Level ready
  -> Stage | Sequencer: Play Sequence  chorus_grid  at 0 bpm
On Sequence Step
  -> HUD | HUDKitBehavior: Set Label  "beat"  str(Sequencer.Current Sequence Step)
```

A crossed cell is said twice, both times in the engine's own plumbing: once as this node's
`sequence_stepped` signal, which **On Sequence Step** connects to (a plain signal your sheet declares
for itself, `sequence_stepped(track, step, name)`), and once to the **group the track is named
after**, so a `lights` track reaches every light listening on it and no reference is held anywhere.
A light in that group with a moment of that name plays it.

**The song is the clock.** With a Music autoload in the tree the grid reads the song's own beat
position and cannot drift from what the player hears; with no song it counts its own beats from the
tempo it was given, which is what keeps a browser tab that throttles frames landing on the beat. A
tempo of `0` on the row means the one the file was saved with. **Set Sequence Tempo** changes it
without restarting, **Jump To Sequence Step** moves the head (the step named is the next one said out
loud, so `0` starts the pattern again), **Stop Sequence** parks the head, and **Sequence Is Playing**
and **Current Sequence Step** read it back. Tracks are their own length, so a four-cell track and a
three-cell track run against each other and a cross-rhythm costs nothing.

Nothing ships here either: a new grid is empty, and the first track is the first thing you add.

---

## A bar that lags

A bar with a lag is the one HUD element every game has, and it is the cheapest juice in this guide.

```
On Game ready
  -> HUD | HUDKitBehavior: Set Bar Lag  "HealthBar"  0.6  Color(0.4, 0.05, 0.05)
On Player damaged
  -> HUD | HUDKitBehavior: Set Bar  "HealthBar"  Player.health
```

Run **Set Bar Lag** once at startup and the bar grows an underlay that stays where the value used to
be, waits those seconds, then slides down to the new value. The player sees how much they just lost
rather than only how much they have left. A bar going UP has nothing to trail, so the underlay lands
with it. **Bar Lag Value** reads where the underlay has got to, and **Is Bar Lagging** is true while
it is still catching up - the pair a "you are about to die" flash reads.

The lag **watches the bar** rather than being told, so it does not matter whether the value came
from a Set Bar row, from a sheet writing the Range directly, or from an animation. Seconds of `0`
takes the underlay away again.

---

## What a beat costs on a phone and in a browser

Every piece in this guide was built to the same three rules, because a beat that stutters is worse
than no beat at all.

**Every tick parks itself.** A behaviour that is not doing anything calls `set_process(false)` and
costs exactly zero frame time. A Feedback Player with no play running, a Juice behaviour whose shake
has faded to nothing, a spring bank where every spring has settled, a stopped sequencer head, a HUD
with no bar lagging, and a level full of channel listeners with nothing shaking are all free. A
channel listener in particular is a group membership, which costs no frames at all until a broadcast
wakes the tick the behaviour already had.

**Nothing allocates per frame.** The per-frame work in a play is arithmetic on values the play
already holds. Where a walk is a tween it is one `Tween`, which the engine parks and frees the moment
it lands, so a swept audio bus and a curve tween both cost nothing at rest.

**The costs that are real, named honestly.** A screen effect is a full-screen shader pass, so a
chromatic shake or a vignette pulse is the one thing in here that is measured in fill rate rather
than in a few floats: on a phone, one at a time. A reverb Wash is the costliest of the three audio
sweeps, being a real effect on a bus. And a screen reader is a cost, counted once for the project
rather than once per beat.

**On the web specifically:** there is no rumble, so the haptics rows are silent and say so once in
the Doctor rather than warning per hit; no threads are assumed anywhere, so nothing in a beat waits
on one; and a tab that throttles frames is exactly why the sequencer reads the song's own playback
position rather than counting frames. A dropped frame never eats a beat - a frame long enough to
cross three steps says all three, in order.

**Two habits that pay for themselves.** Scale Feedback Amounts and Mute Feedback Category give a
mobile build a lighter version of the same beat with nothing rewritten and no second list to keep in
step. And a beat that reaches far - a quake, an explosion - is one Play Moment At with a range,
which does its distance arithmetic once per play, rather than one moment per object in earshot.
