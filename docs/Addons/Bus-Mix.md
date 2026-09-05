# Bus Mix - A Bus Swept Rather Than Switched

Bus Mix is the Godot EventSheets vocabulary for a mix that MOVES. Flipping a prepared bus effect on and off is one frame's worth of change: the world is dry, then it is underwater. A hit does not feel like that. What a heavy hit feels like is the room going under for a tenth of a second and coming back, and that is a number moving - a cutoff walking down and up again, a level dipping and returning, a reverb welling up behind the rest of the mix. These rows are those walks. Three sweeps (**muffle**, **dive**, **wash**), one row that puts the room right again (**Restore Bus**), and a pair that writes the whole desk down under a name and walks it back (**Snapshot Buses As**, **Recall Bus Snapshot**). A sweep never touches the bus volume the player set in the options screen: that one is theirs. The work is plain typed GDScript in your project's own folder, with no plugin class named anywhere in it, and a sweep is one Tween the engine parks and frees the moment it lands, so at rest the whole thing costs nothing.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [The rows beside these](#the-rows-beside-these)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Hits that land in the mix.** A tenth of a second of muffle under a hitstop is what makes a heavy blow feel heavy, and it is one row.
- **Underwater, and coming back up.** A cutoff walked down over half a second reads as going under; walked back it reads as surfacing.
- **Dialogue ducking.** The effects bus dives under a line and comes back when it ends, without ever moving the level the player chose.
- **Slow motion.** The whole world's level dropping away as time slows, then returning, so the audio agrees with the picture.
- **Rooms that sound like rooms.** A reverb's wet grown behind the sound rather than replacing it, for a cave mouth, a cathedral or a dream.
- **Pause menus.** One named snapshot for normal and one for paused, and two rows switching between them.
- **Death and defeat.** A muffle and a wash together, and one Restore Bus at the respawn that puts everything back without the sheet remembering what it changed.
- **Boss phases and stingers.** Different mixes per phase, each one a snapshot taken once and recalled by name.
- **Accessibility mixes.** A snapshot per preset (music quiet, speech forward), recalled from an options screen.
- **Anything that currently switches.** A prepared effect flipped on and off is a candidate for a sweep, and the difference is the whole reason the pack exists.

---

## Core concepts

**Three sweeps, and what each one really moves.**

- **Muffle** moves the cutoff of a low-pass filter on the bus. Everything above the cutoff goes quiet, so 400 Hz is a pillow over the speaker and 20500 Hz is not there at all.
- **Dive** moves the level of an **amplify** effect on the bus, never the bus's own volume. The player set that in the options screen and it is theirs; a beat that moved it would be arguing with them, and worse, would leave their setting wherever the beat happened to end.
- **Wash** moves the wet amount of a reverb on the bus, with its dry left alone, so the room grows behind the sound instead of replacing it.

**The effect is added once and kept.** The first sweep of a kind on a bus looks for an effect of that kind already in the bus layout and uses it; when there is none it adds one, opened at the value that does nothing at all, so adding it is silent. Every sweep after that reuses it. The bus layout in the Audio panel therefore GAINS a slot the first time a game runs one of these rows, and never gains another.

**Home is where the mix was, not where the last beat left it.** The value an effect had when a sweep first touched it is written down as that bus's resting value for that kind. `Restore Bus` walks every armed kind back to it. So a moment can muffle and dive without ever saying how to come back up, and one row at the end of it puts the room right.

**A snapshot is the mix, not a style.** `Snapshot Buses As` writes down every bus's level, mute and solo under a name the project chose, and `Recall Bus Snapshot` walks them back. Nothing ships: there is no house "underwater" and no house "paused", because a game's mix is the game's. Take the first snapshot from the live desk, usually at startup and usually called `normal`, and every later recall has somewhere honest to come back to.

**Levels walk, silence cuts.** A recall walks the levels over the seconds you name; the mutes and the solos are set at once, because there is nothing between silent and not silent to walk through.

**The mix outlives the scene.** The sweeps in the air, the resting values and the named snapshots live on the engine rather than on a node. A dive started in the arena finishes even if the arena is freed halfway through, and a snapshot taken at startup is still there in the third level.

**A sweep with no time is a write.** Naming 0 seconds, or running the row from somewhere with no node in the tree, writes the value at once rather than promising a walk nothing would step.

---

## Setup

**1. Make your buses.** Open the **Audio** panel at the bottom of the editor and add the buses your game mixes on. `Master` is always there; `Music`, `SFX`, `Voice` and `Ambience` are the usual four. Every row here addresses a bus by NAME, resolved when the row runs, so a bus that is not in the layout warns by name and changes nothing.

**2. Point your players at them.** Set each `AudioStreamPlayer`'s bus in the Inspector. A dive on `SFX` reaches everything playing on `SFX` and nothing else, which is what makes ducking a one-row job.

**3. Take the first snapshot at startup.** From the live desk, before anything has moved:

```
On Ready
  -> Audio Server: Snapshot Buses As  "normal"
```

Every later recall now has somewhere honest to come back to.

**4. Sweep something.**

```
Player: On heavy hit
  -> Audio Server: Muffle Bus  "Master", 400.0, 0.06
  -> Audio Server: Restore Bus  "Master", 0.25
```

The first row walks the room under; the second walks it back to wherever it was resting before any sweep touched it. Note the effect slot the first run adds to `Master` in the Audio panel: it is the low-pass the muffle moves, and it is opened so wide it does nothing until a sweep starts.

**5. Leave the player's own levels alone.** Nothing here writes the bus volume except a recall, and a recall only ever puts back a level a snapshot wrote down. The options screen's sliders stay the player's.

---

## ACE reference

All rows live in the **Audio Server** category. Buses are addressed by name.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Muffle Bus | `bus` (String, `"Master"`), `cutoff_hz` (float, `400.0`), `seconds` (float, `0.12`) | Walks a bus underwater: a low-pass filter's cutoff slides down to the number you name over the seconds you name, so everything brighter than it goes quiet. A tenth of a second of this under a hitstop is what makes the hit feel heavy. The filter is added to the bus the FIRST time this runs, opened so wide it does nothing, and reused every time after. Restore Bus opens it again. |
| Dive Bus Volume | `bus` (String, `"SFX"`), `volume_db` (float, `-12.0`), `seconds` (float, `0.12`) | Walks a bus's level down (or up) over time, so the sound effects duck under a line of dialogue or the whole world drops away under a slowmo. It moves an amplify effect on the bus, NOT the bus volume the player chose in the options screen. Restore Bus brings the level back. |
| Wash Bus | `bus` (String, `"Master"`), `wetness` (float, `0.5`), `seconds` (float, `0.12`) | Grows a room behind the sound: a reverb's wet amount walks up over the seconds you name, with its dry left alone, so the sound is still there and now it is somewhere. A kill, a cave mouth, a dream. The reverb is added to the bus the first time this runs, silent until the walk starts, and it is the costliest of the three sweeps on a phone. |
| Restore Bus | `bus` (String, `"Master"`), `seconds` (float, `0.12`) | Walks every sweep this bus has been under back to where it was resting BEFORE the first one touched it - the cutoff open, the level as it was, the room gone. Home is where the mix was to start with, not where the last beat left it, so a moment can muffle and dive without ever saying how to come back and one row at the end of it puts the room right. |
| Snapshot Buses As | `snapshot_name` (String, `"normal"`) | Writes down what every bus is doing right now - its level, whether it is muted, whether it is soloed - under a name you choose. Nothing ships with this: there is no house "underwater" and no house "paused". Take the first one at startup, call it normal, and every later recall has somewhere honest to come back to. |
| Recall Bus Snapshot | `snapshot_name` (String, `"normal"`), `seconds` (float, `0.3`) | Puts a mix you snapshotted back. The levels are WALKED over the seconds you name; the mutes and the solos are cut at once, because there is nothing between silent and not silent to walk through. A name nobody has taken says so and changes nothing, rather than inventing a mix. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Bus Is Sweeping | `bus` (String, `"Master"`) | True while a Muffle, Dive, Wash or Restore on this bus is still walking. The question a second beat asks before starting a sweep over the top of the first one. |
| Bus Snapshot Exists | `snapshot_name` (String, `"normal"`) | True once a Snapshot Buses As row has filed a mix under this name in this run - the guard before a recall in a scene that may have been reached without passing the place the snapshot was taken. |

### What a sweep moves, and where it rests

| Sweep | The effect it uses | The value it walks | The value that does nothing |
|---|---|---|---|
| Muffle | `AudioEffectLowPassFilter` | `cutoff_hz` | `20500` Hz |
| Dive | `AudioEffectAmplify` | `volume_db` | `0` dB |
| Wash | `AudioEffectReverb` (its dry left at full) | `wet` | `0` |

An effect the sweep ADDS is opened at the value that does nothing, so arming it is silent. An effect the project already put on the bus is used exactly as it was found, switched on, and its current value becomes that bus's resting value for that kind.

### What a snapshot remembers

| Key | What it is |
|---|---|
| Level | Each bus's `volume_db`, walked back over the recall's seconds |
| Muted | Whether the bus was silenced, set at once |
| Soloed | Whether the bus was the only one heard, set at once |

---

## The rows beside these

These sit on the same **Audio Server** shelf and compile to plain `AudioServer` calls. They switch rather than sweep, which is what makes them the right rows when the change really is instant.

| Row | Kind | Parameters | What it does |
|---|---|---|---|
| Set Bus Muted | action | `bus` (`"Music"`), `muted` (bool, `true`) | Mutes or unmutes a whole bus - the options-menu music/SFX toggle in one action. |
| Set Bus Solo | action | `bus` (`"Music"`), `solo` (bool, `true`) | Solos a bus so only it (and other soloed buses) is heard. |
| Set Bus Effects Bypassed | action | `bus` (`"Music"`), `bypassed` (bool, `true`) | Skips or restores ALL effects on a bus at once - dry against processed in one flip. |
| Set Bus Effect Enabled | action | `bus` (`"Master"`), `effect_index` (int, `0`), `enabled` (bool, `true`) | Flips ONE prepared effect on a bus, by its slot in the Audio panel (top = 0). |
| Set Audio Playback Speed | action | `scale` (float, `1.0`) | Scales EVERY sound's playback speed and pitch. Set it alongside a slowmo so the world's audio drops with time, then back to 1. |
| Bus Exists | condition | `bus` (`"Music"`) | True when a bus with this name is in the current layout - guard optional buses. |
| Is Bus Effect Enabled | condition | `bus` (`"Master"`), `effect_index` (int, `0`) | True while a bus effect slot is switched on. |
| Bus Peak Volume (dB) | expression | `bus` (`"Master"`) | The bus's current peak level in dB (very negative is silence) - drive a VU meter or audio-reactive visuals. |
| Audio Playback Speed | expression | (none) | The current global playback speed scale. |
| Bus Count | expression | (none) | How many buses the current layout has. |
| Audio Output Latency | expression | (none) | The output latency in seconds - rhythm games subtract it when judging hits. |

---

## Use cases

Every row below is in the **Audio Server** category. The sweeps schedule their walk on the node the row runs on, so run them somewhere that stays in the tree for the length of the sweep.

### 1. A heavy hit that takes the room with it

The one that made the pack: the room goes under for a moment and comes back.

```
Player: On heavy hit
  -> Audio Server: Muffle Bus  "Master", 400.0, 0.06
  -> Audio Server: Restore Bus  "Master", 0.25
```

Down fast, back slow. The restore knows where home is, so the sheet never has to say 20500.

### 2. Underwater, and surfacing

The same sweep over a longer time is a state rather than a hit.

```
Player: On entered water
  -> Audio Server: Muffle Bus  "Master", 600.0, 0.6
  -> Audio Server: Wash Bus  "Master", 0.4, 0.6

Player: On left water
  -> Audio Server: Restore Bus  "Master", 0.4
```

One Restore Bus puts BOTH sweeps back, because it walks every kind this bus has been under.

### 3. Duck the effects under a line of dialogue

The dive moves an amplify, so the player's own SFX slider is untouched at both ends.

```
Dialogue: On line started
  -> Audio Server: Dive Bus Volume  "SFX", -14.0, 0.15

Dialogue: On line finished
  -> Audio Server: Restore Bus  "SFX", 0.4
```

### 4. Duck the music too, but not as far

Two buses, two dives, one restore each. The numbers are the mix decision.

```
Dialogue: On line started
  -> Audio Server: Dive Bus Volume  "Music", -8.0, 0.15
  -> Audio Server: Dive Bus Volume  "SFX", -14.0, 0.15

Dialogue: On line finished
  -> Audio Server: Restore Bus  "Music", 0.4
  -> Audio Server: Restore Bus  "SFX", 0.4
```

### 5. Slow motion the audio agrees with

The world drops away as time slows, and the global playback speed drops the pitch with it.

```
On Slowmo Started
  -> Audio Server: Dive Bus Volume  "SFX", -10.0, 0.2
  -> Audio Server: Set Audio Playback Speed  0.6

On Slowmo Finished
  -> Audio Server: Restore Bus  "SFX", 0.3
  -> Audio Server: Set Audio Playback Speed  1.0
```

The playback speed is a switch rather than a sweep, so set it at the two ends.

### 6. A cave that sounds like a cave

The wash grows a room behind the sound rather than replacing it, because the reverb's dry is left alone.

```
Player: On entered cave
  -> Audio Server: Wash Bus  "Master", 0.55, 1.2

Player: On left cave
  -> Audio Server: Restore Bus  "Master", 0.8
```

Wash is the costliest of the three on a phone, so use it for places rather than for hits.

### 7. Death, and one row at the respawn

A beat can pile several sweeps on without ever saying how to come back.

```
Player: On died
  -> Audio Server: Muffle Bus  "Master", 300.0, 0.5
  -> Audio Server: Dive Bus Volume  "Master", -18.0, 0.8
  -> Audio Server: Wash Bus  "Master", 0.6, 0.8

Player: On respawn
  -> Audio Server: Restore Bus  "Master", 0.5
```

Restore Bus walks every armed kind home, so the respawn row does not have to know what the death beat did.

### 8. Take the mix down at startup

The first snapshot is the honest one, because nothing has moved yet.

```
On Ready
  -> Audio Server: Snapshot Buses As  "normal"
```

Every recall later in the game now has somewhere real to come back to.

### 9. A pause mix, as two rows

Snapshot once, recall by name.

```
On Options Confirmed
  -> Audio Server: Snapshot Buses As  "normal"

On Game Paused
  -> Audio Server: Dive Bus Volume  "SFX", -20.0, 0.2
  -> Audio Server: Dive Bus Volume  "Ambience", -20.0, 0.2

On Game Resumed
  -> Audio Server: Restore Bus  "SFX", 0.2
  -> Audio Server: Restore Bus  "Ambience", 0.2
```

Snapshotting after the options are confirmed is what makes `normal` the player's mix rather than the project's.

### 10. Recall a mix by name, safely

A name nobody has taken changes nothing, and the condition is how a scene that may have been reached another way checks first.

```
On Cutscene Started
  Condition: Audio Server: Bus Snapshot Exists  "cinematic"
    -> Audio Server: Recall Bus Snapshot  "cinematic", 0.5
  Else
    -> Audio Server: Snapshot Buses As  "cinematic"
```

### 11. Do not start a second beat over the first

Bus Is Sweeping is true while any sweep on that bus is still walking.

```
Enemy: On damaged
  Condition: Audio Server: Bus Is Sweeping  "Master"  (inverted)
    -> Audio Server: Muffle Bus  "Master", 500.0, 0.05
    -> Audio Server: Restore Bus  "Master", 0.2
```

Without the guard, a machine-gun of hits would keep restarting the muffle and the room would never come back up.

### 12. A boss phase with its own mix

A snapshot per phase, taken once and recalled by name afterwards.

```
Boss: On phase 2 begins
  Condition: Audio Server: Bus Snapshot Exists  "phase_2"  (inverted)
    -> Audio Server: Set Bus Muted  "Ambience", true
    -> Audio Server: Snapshot Buses As  "phase_2"
  Else
    -> Audio Server: Recall Bus Snapshot  "phase_2", 0.6
```

Mutes and solos are set at once by a recall, so the ambience goes silent on the frame rather than fading.

### 13. A stinger that ducks everything under it

The music makes room for the sound the moment demands, and takes it back.

```
On Level Complete
  -> Audio Server: Dive Bus Volume  "Music", -12.0, 0.1
  -> Audio Server: Dive Bus Volume  "Ambience", -18.0, 0.1
  -> Audio: play "fanfare" on "SFX"
  -> System: wait  2.5  seconds
  -> Audio Server: Restore Bus  "Music", 1.0
  -> Audio Server: Restore Bus  "Ambience", 1.0
```

### 14. A dream sequence

The mix is the transition, and the picture follows it.

```
On Dream Started
  -> Audio Server: Wash Bus  "Master", 0.8, 2.0
  -> Audio Server: Muffle Bus  "Master", 1200.0, 2.0

On Dream Ended
  -> Audio Server: Restore Bus  "Master", 1.5
```

A cutoff of 1200 Hz is a wall away rather than a pillow over the speaker, which is the difference between muted and gone.

### 15. Set a value at once, without a walk

Naming 0 seconds writes the value straight away, which is what a scene load wants.

```
On Scene Loaded
  Condition: Scene.is_underwater
    -> Audio Server: Muffle Bus  "Master", 600.0, 0.0
```

There is nothing to hear during a load, so the walk would only be a delay before the player arrives.

### 16. A VU meter, and ducking driven by it

The peak expression is what turns a mix into something the game can read back.

```
Every tick
  -> VUBar: value = Audio Server: Bus Peak Volume (dB)  "Voice"

Every tick
  Condition: Audio Server: Bus Peak Volume (dB)  "Voice"  >  -30
    -> Audio Server: Dive Bus Volume  "Music", -10.0, 0.1
  Else
    -> Audio Server: Restore Bus  "Music", 0.4
```

Give the two branches different sweep times so a speaker pausing for breath does not make the music pump.

### 17. An accessibility mix the player can choose

One snapshot per preset, each taken from the live desk once, and one row on the options screen.

```
On Speech Forward Preset Chosen
  Condition: Audio Server: Bus Snapshot Exists  "speech_forward"
    -> Audio Server: Recall Bus Snapshot  "speech_forward", 0.3

On Normal Preset Chosen
  -> Audio Server: Recall Bus Snapshot  "normal", 0.3
```

Because a snapshot holds levels, mutes and solos, a preset can be as small as one bus quieter or as large as the whole desk.

### 18. Guard an optional bus

A project that ships without a `Voice` bus should not warn on every line.

```
Dialogue: On line started
  Condition: Audio Server: Bus Exists  "Voice"
    -> Audio Server: Dive Bus Volume  "SFX", -14.0, 0.15
```

A sweep on a bus that is not in the layout says so by name and changes nothing, so the guard is about keeping the output clean rather than about safety.

### Other use cases

**Radio and telephone voices.** A muffle held at a narrow cutoff for the length of a call, with Restore Bus at the hang-up, so the effect is a state rather than a filter somebody has to remember to switch off.

**Horror stingers.** A wash grown fast and restored slowly behind a scare, which reads as the room reacting rather than as a sound effect being played.

**Racing tunnels.** A wash and a small muffle entering the tunnel and a restore at the mouth, driven off the same trigger the visuals use, so the picture and the mix arrive together.

**Menu layers.** A snapshot per menu depth, recalled as the player goes in and out, so a settings screen inside a pause screen sounds one step further from the game than the pause screen does.

**Rhythm-game calibration.** The output latency expression read once into the judging window, with a snapshot around the calibration screen so the mix it needs does not leak back into the game.

---

## Tips and common mistakes

- **The bus layout gains a slot on the first sweep.** The first Muffle, Dive or Wash on a bus adds the effect it moves, opened at the value that does nothing. Expect to see it in the Audio panel afterwards. It is added once and reused, so a bus never collects two.
- **A dive is not the bus volume.** It moves an amplify effect, deliberately, so the level the player set in the options screen is never touched and never left wherever a beat happened to end. If you actually want to move the player's level, that is a different row.
- **Home is the FIRST resting value, not the last.** The value written down is the one the effect had the first time a sweep of that kind touched that bus. Restore Bus always walks there, which is why a beat can pile sweeps on without saying how to come back.
- **Restore Bus puts every kind back at once.** One row after a muffle and a dive and a wash. It only knows about kinds that have been swept on that bus, so it never touches an effect nothing has armed.
- **A sweep needs a node in the tree to walk in.** The walk is a Tween scheduled on the node the row runs on. With 0 seconds, or with no node, the value is written at once instead - honest, but not a fade.
- **Guard repeated beats with Bus Is Sweeping.** A hit that fires ten times a second restarts the muffle ten times and the room never comes back up. The condition is the guard, and it covers restores as well as sweeps.
- **A recall of a name nobody took changes nothing.** It says so in a warning rather than inventing a mix. Take the snapshot before the scene that recalls it can be reached, or check with Bus Snapshot Exists.
- **Snapshots live for the run, not for the save file.** They are kept on the engine, so they survive scene changes and are gone when the game closes. Take `normal` at startup, every startup.
- **Mutes and solos in a recall do not fade.** Only the levels walk. If a bus should fade to silence, dive it instead of muting it.
- **Wash is the expensive one.** A reverb costs more than a filter or an amplify, especially on a phone. Use it for places the player stays in, and reach for muffle and dive for the beats inside them.
- **A bus is addressed by name, resolved when the row runs.** A typo or a renamed bus warns by name and changes nothing, which is safe but silent in a build. Bus Exists is the guard for buses your project may ship without.
