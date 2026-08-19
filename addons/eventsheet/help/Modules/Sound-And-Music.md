# Sound and Music

Audio in EventSheets comes in three layers, and picking the right one is most of the job.

1. **Fire-and-forget one-shots.** **Play Sound** builds a throwaway `AudioStreamPlayer`, plays a file
   once, and frees itself when it finishes. No node to place, no bookkeeping. The shot is remembered
   as the LAST SOUND, so the row right after it can retune the pitch or the volume of the sound that
   just fired.
2. **A player node you control.** Put a sheet (or a behavior) on an `AudioStreamPlayer` and you get
   **Play**, **Play Sound File**, **Stop**, **Seek**, **Set Volume**, **Set Pitch**,
   **Is Playing** and **Playback Position**. This is the layer music, looping ambience and anything
   you need to interrupt belongs on.
3. **The mixing desk.** Buses are Godot's own idea of "all the SFX" or "all the music", and the
   **Audio Server** rows speak to them by name: volume, mute, solo, effect bypass, and the metering
   numbers a VU bar reads. An options menu talks in percent instead of decibels, and the
   **Game Options** rows cover that.

Every row here compiles to plain Godot (`AudioStreamPlayer`, `AudioServer`, `linear_to_db`) with no
plugin runtime behind it.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Hit and pickup sounds** - one row, no player node, natural pitch variation.
- **Positional 2D sound** that gets quieter as the player walks away.
- **Music that you start, pause, seek and fade** from a named player node.
- **An options menu** with Master / Music / SFX sliders in 0-100 percent, saved between runs.
- **The underwater or cave state** - flip a prepared bus effect instead of writing DSP.
- **Slow motion that sounds slow**, because global playback speed drops with time scale.
- **A VU meter or audio-reactive visual** driven by the bus peak level.
- **Rhythm games** that subtract the real output latency when judging a hit.
- **A mute button** that survives a restart.
- **Cutscene dialogue focus** by soloing the voice bus for its duration.

## Core concepts

- **A one-shot is a node that deletes itself.** **Play Sound** creates an `AudioStreamPlayer`, adds it
  as a child, connects `finished` to `queue_free`, and plays. Nothing to clean up, and nothing to
  reuse either - once it finishes it is gone.
- **"Last sound" means the last one THIS node played.** The one-shot is remembered as a meta value on
  the emitting node, so **Set Last Sound Playback Rate**, **Set Last Sound Volume** and
  **Stop Last Sound** always talk about the shot this sheet fired, never another node's.
- **Buses are addressed by name, resolved at the call.** Every bus row wraps
  `AudioServer.get_bus_index("Music")`. A name that is not in the bus layout resolves to -1, which is
  silently ignored - so a typo is a row that quietly does nothing. **Bus Exists** is the guard.
- **Decibels are not percent.** 0 dB is full volume and -80 dB is silence, and the scale is
  logarithmic: half the dB is nowhere near half the loudness. A slider gives you a percent, so use
  **Set Bus Volume (percent)** for sliders and the dB rows for mixing decisions.
- **Node-scoped rows get an optional "On node".** Every player row is scoped to
  `AudioStreamPlayer`, and the builtin targetable pass adds an **On node** parameter to each. Leave
  it blank and the row acts on the node the sheet is on; fill it in (`$Music`) and the exact same row
  acts on that node instead.
- **Effects are prepared in the editor and flipped from events.** Add a lowpass to a bus in the Audio
  panel, note its slot number, then **Set Bus Effect Enabled** toggles it at runtime.

## Reference tables

Multi-line templates are shown by their first line; the full emitted block appears in the matching
use case below.

### One-shots (picker section: Audio)

| Name | What it does | Ships as |
|------|--------------|----------|
| Play Sound | Plays a sound file once on a chosen bus and volume, then cleans itself up. Remembers the shot as the last sound. | `var __sfx_{uid} = AudioStreamPlayer.new()` … (multi-line, use case 1) |
| Play Sound At (2D) | Plays a sound at a world position so it gets louder or quieter with distance. Node2D only. | `var __sfx_{uid} = AudioStreamPlayer2D.new()` … (multi-line, use case 3) |
| Set Last Sound Playback Rate | Changes the speed and pitch of the sound the last Play Sound started. | `var __last_sfx_{uid} = get_meta("__last_sfx", null)` … (multi-line, use case 2) |
| Set Last Sound Volume | Changes the volume of the last one-shot, in decibels. | `var __last_sfx_{uid} = get_meta("__last_sfx", null)` … (multi-line) |
| Stop Last Sound | Silences and frees the last one-shot (a throwaway player, so stopping IS freeing). | `var __last_sfx_{uid} = get_meta("__last_sfx", null)` … (multi-line) |

Parameters: **Play Sound** takes Sound (an audio file, with a preview button in the params dialog),
Bus (default `"Master"`) and Volume dB (default `0.0`). **Play Sound At (2D)** takes Sound and
Position (default `global_position`). **Set Last Sound Playback Rate** takes Rate, whose default is
already `randf_range(0.9, 1.1)`.

### The player node (picker section: Audio, node type AudioStreamPlayer)

| Name | What it does | Ships as |
|------|--------------|----------|
| Play | Starts this player, optionally from a time in seconds. | `{target.}play({from})` |
| Play Sound File | Loads an audio file into this player and starts it. | `{target.}stream = load({path})` + `{target.}play()` |
| Stop | Stops this player right now. | `{target.}stop()` |
| Seek | Jumps playback to a time in seconds. | `{target.}seek({seconds})` |
| Set Volume | Sets this player's loudness in decibels. | `{target.}volume_db = {db}` |
| Set Pitch | Changes this player's speed and pitch (1 = normal). | `{target.}pitch_scale = {pitch}` |
| Set Sound | Puts a sound file into this player, ready to play. | `{target.}stream = load({path})` |
| Set Bus | Sends this player's sound out on a named bus, like SFX or Music. | `{target.}bus = {bus}` |
| Set Volume (0 to 1) | Sets how loud this player is from a slider level, decibels done for you. | `{target.}volume_db = linear_to_db({level})` |
| Is Playing | True while this player is making sound. | `{target.}playing` |
| Playback Position | The current playback time in seconds. | `{target.}get_playback_position()` |

`{target.}` is the optional **On node** parameter: blank emits the bare call on the host node.

### The same player, from the general sections (picker: General Actions / Conditions / Expressions)

| Name | What it does | Ships as |
|------|--------------|----------|
| Play Sound | Plays the sound already assigned to an audio player, optionally from a second. | `{target.}play({from_position})` |
| Stop Sound | Stops the sound currently playing on an audio player. | `{target.}stop()` |
| Set Volume (dB) | Sets an audio player's loudness in decibels. | `{target.}volume_db = {db}` |
| Is Playing | True while the audio player is playing a sound. | `{target.}playing` |
| Playback Position | How many seconds into the sound the player currently is. | `{target.}get_playback_position()` |

These five are the older, plainly-named siblings of the Audio-section rows above and emit the same
code. Two actions really are called **Play Sound** and two conditions really are called
**Is Playing** - see the tips at the end for how to tell them apart in the picker.

### Buses (picker sections: Audio and Audio Server)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Bus Volume | Sets a named bus's volume in decibels. | `AudioServer.set_bus_volume_db(AudioServer.get_bus_index({bus}), {db})` |
| Mute Bus | Mutes or unmutes a named bus (Muted is a true / false dropdown). | `AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})` |
| Bus Volume | The bus's current volume in decibels. | `AudioServer.get_bus_volume_db(AudioServer.get_bus_index({bus}))` |
| Set Bus Muted | The same mute, taking a bool expression instead of a dropdown. | `AudioServer.set_bus_mute(AudioServer.get_bus_index({bus}), {muted})` |
| Set Bus Solo | Plays ONLY soloed buses. | `AudioServer.set_bus_solo(AudioServer.get_bus_index({bus}), {solo})` |
| Set Bus Effects Bypassed | Skips or restores every effect on a bus at once. | `AudioServer.set_bus_bypass_effects(AudioServer.get_bus_index({bus}), {bypassed})` |
| Set Bus Effect Enabled | Flips ONE prepared effect slot on a bus. | `AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index}, {enabled})` |
| Is Bus Effect Enabled | True while that effect slot is switched on. | `AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index({bus}), {effect_index})` |
| Bus Exists | True when a bus with this name is in the current layout. | `AudioServer.get_bus_index({bus}) >= 0` |
| Bus Count | How many buses the layout has. | `AudioServer.get_bus_count()` |
| Bus Peak Volume (dB) | The bus's current peak level (very negative = silence). | `AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index({bus}), 0)` |
| Set Audio Playback Speed | Scales EVERY sound's speed and pitch. | `AudioServer.playback_speed_scale = {scale}` |
| Audio Playback Speed | The current global playback speed scale. | `AudioServer.playback_speed_scale` |
| Audio Output Latency | Output latency in seconds. | `AudioServer.get_output_latency()` |

### The options-menu forms (picker section: Game Options)

| Name | What it does | Ships as |
|------|--------------|----------|
| Set Master Volume (percent) | Sets the overall game volume from a 0-100 slider value. | `AudioServer.set_bus_volume_db(0, linear_to_db(clampf({percent} / 100.0, 0.0, 1.0)))` |
| Set Bus Volume (percent) | Sets one bus's volume from a 0-100 slider value. | `AudioServer.set_bus_volume_db(AudioServer.get_bus_index({bus}), linear_to_db(clampf({percent} / 100.0, 0.0, 1.0)))` |
| Bus Volume (percent) | Reads a bus's volume back as 0-100, to set a slider's start value. | `clampf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index({bus}))), 0.0, 1.0) * 100.0` |
| Is Bus Muted | True when a bus is currently muted. | `AudioServer.is_bus_mute(AudioServer.get_bus_index({bus}))` |

## Use cases

**1. A hit sound with no setup at all.** On the enemy's hit event, add **Play Sound** with the file,
the bus `"SFX"` and volume `0.0`. It emits the whole throwaway player, guard included:

```gdscript
var __sfx_a1 = AudioStreamPlayer.new()
__sfx_a1.stream = load("res://sfx/hit.ogg")
if __sfx_a1.stream == null:
	__sfx_a1.queue_free()
else:
	__sfx_a1.bus = "SFX"
	__sfx_a1.volume_db = 0.0
	add_child(__sfx_a1)
	set_meta("__last_sfx", __sfx_a1)
	__sfx_a1.finished.connect(__sfx_a1.queue_free)
	__sfx_a1.play()
```

The `if stream == null` arm is why a missing file is a silent no-op rather than a crash.

**2. Stop the machine-gun effect.** Put **Set Last Sound Playback Rate** directly after the
**Play Sound** row. Its default is already the pitch jitter you want:

```gdscript
var __last_sfx_a2 = get_meta("__last_sfx", null)
if is_instance_valid(__last_sfx_a2):
	__last_sfx_a2.pitch_scale = randf_range(0.9, 1.1)
```

**3. A footstep that fades with distance.** **Play Sound At (2D)** on a `Node2D`, leaving Position at
its default `global_position`:

```gdscript
var __sfx_a3 = AudioStreamPlayer2D.new()
__sfx_a3.stream = load("res://sfx/step.ogg")
if __sfx_a3.stream == null:
	__sfx_a3.queue_free()
else:
	__sfx_a3.global_position = global_position
	add_child(__sfx_a3)
	set_meta("__last_sfx", __sfx_a3)
	__sfx_a3.finished.connect(__sfx_a3.queue_free)
	__sfx_a3.play()
```

**4. A quieter one-shot without touching the bus.** **Play Sound** then **Set Last Sound Volume** at
`-12.0`, so only that shot is quieter.

```gdscript
var __last_sfx_a4 = get_meta("__last_sfx", null)
if is_instance_valid(__last_sfx_a4):
	__last_sfx_a4.volume_db = -12.0
```

**5. Cut a long one-shot short.** A charge-up sound that should die the moment the player releases:
**Stop Last Sound**.

```gdscript
var __last_sfx_a5 = get_meta("__last_sfx", null)
if is_instance_valid(__last_sfx_a5):
	__last_sfx_a5.queue_free()
```

**6. Start the level music.** On a sheet attached to a `Music` node (an `AudioStreamPlayer`), use
**Play Sound File** so the file and the start live in one row:

```gdscript
stream = load("res://music/level1.ogg")
play()
```

**7. The same, driven from the level sheet instead.** Keep the rows on the level and fill the
**On node** parameter with `$Music`:

```gdscript
$Music.stream = load("res://music/level1.ogg")
$Music.play()
```

**8. Resume music where it left off.** Store **Playback Position** into a variable before switching
scenes, then **Seek** back to it:

```gdscript
resume_at = $Music.get_playback_position()
```

```gdscript
$Music.play(0.0)
$Music.seek(resume_at)
```

**9. Do not restart music that is already playing.** Put **Is Playing** on the condition side,
inverted, and the **Play** action on the right.

```
On Ready
  Condition: Is Playing  (On node $Music, inverted)
    -> Play  from 0.0  (On node $Music)
```

**10. A tension riser.** Raise **Set Pitch** as the timer runs down:

```gdscript
$Music.pitch_scale = 1.0 + progress * 0.3
```

**11. Master, Music and SFX sliders.** Under an **On Signal** `value_changed` event (or simply every
frame), one row per bus sets it from the slider's 0-100 value. Master uses the percent action that goes straight to bus 0:

```gdscript
AudioServer.set_bus_volume_db(0, linear_to_db(clampf($MasterSlider.value / 100.0, 0.0, 1.0)))
AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(clampf($MusicSlider.value / 100.0, 0.0, 1.0)))
AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(clampf($SfxSlider.value / 100.0, 0.0, 1.0)))
```

**12. Show the sliders where the volume actually is** when the options screen opens, with
**Bus Volume (percent)**:

```gdscript
$MusicSlider.value = clampf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.0, 1.0) * 100.0
```

**13. A mute button that reports its own state.** **Set Bus Muted** flips it, **Is Bus Muted** reads
it back for the button's label:

```gdscript
AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
```

**14. Remember the choice between runs.** **Save Setting** writes to `user://settings.cfg`, and the
Game Options and Window guides both use the same file:

```gdscript
var __cfg_a6 = ConfigFile.new()
__cfg_a6.load("user://settings.cfg")
__cfg_a6.set_value("audio", "music_volume", $MusicSlider.value)
__cfg_a6.save("user://settings.cfg")
```

**15. Underwater in one row.** Add a lowpass filter to the Master bus in the Audio panel (it lands in
slot 0), then use **Set Bus Effect Enabled** when the player goes under and again when they surface:

```gdscript
AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Master"), 0, true)
```

**Is Bus Effect Enabled** answers "are we underwater?" without a tracking variable.

**16. Dry vs processed, everywhere at once.** A debug hotkey with
**Set Bus Effects Bypassed** on `"Master"`:

```gdscript
AudioServer.set_bus_bypass_effects(AudioServer.get_bus_index("Master"), true)
```

**17. Slow motion that sounds slow.** Pair the time scale change with
**Set Audio Playback Speed**, and set both back to 1 when the effect ends:

```gdscript
Engine.time_scale = 0.4
AudioServer.playback_speed_scale = 0.4
```

**18. Focus the voice during a cutscene** with **Set Bus Solo** on `"Voice"`, then solo it off again
at the end:

```gdscript
AudioServer.set_bus_solo(AudioServer.get_bus_index("Voice"), true)
```

**19. A VU meter.** Feed **Bus Peak Volume (dB)** through a progress bar every frame. Peak dB is very
negative in silence, so map it rather than using it raw:

```gdscript
$VuBar.value = clampf(inverse_lerp(-60.0, 0.0, AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Master"), 0)), 0.0, 1.0) * 100.0
```

**20. A rhythm game that is fair.** Subtract **Audio Output Latency** from the judged time:

```gdscript
hit_time = $Music.get_playback_position() - AudioServer.get_output_latency()
```

**21. Guard an optional bus.** A bus layout shipped by one project may not exist in another, so put
**Bus Exists** on the condition side before any row that names it.

```
On Ready
  Condition: Bus Exists  "Voice"
    -> Set Bus Volume  "Voice", -6.0
```

### Other use cases

**Ducking the music under dialogue.** Watch Bus Peak Volume (dB) on the Voice bus every frame and drive Set Bus Volume on Music down while it is above a threshold, back up when it is not.

**A sound test screen.** One button per file firing Play Sound, with a Set Last Sound Playback Rate row wired to a pitch slider so designers can audition variations without leaving the game.

**Menu clicks that never overlap badly.** Play Sound for the click plus Set Last Sound Volume driven by how many clicks happened this second, so a mashed button gets quieter instead of louder.

**A pause menu that silences the world but not itself.** Mute Bus on SFX and Music while paused, leaving the UI bus alone, then unmute on resume.

**An accessibility "reduce audio" toggle.** One Set Bus Effects Bypassed row plus Set Audio Playback Speed pinned at 1.0, so players who dislike processed audio get the dry mix.

## Tips and common mistakes

- **Two different actions are called "Play Sound".** The one in the **Audio** section builds a
  throwaway player from a file path. The one in **General Actions** is node-scoped to
  `AudioStreamPlayer` and plays the stream that node already holds. **Is Playing** and
  **Playback Position** are duplicated the same way (Audio versus General Conditions / General
  Expressions) and emit identical code. Read the section header in the picker, not just the name.
- **A misspelled bus name does nothing, quietly.** `get_bus_index` answers -1 for an unknown bus and
  the AudioServer call is ignored. If a volume row seems dead, check the spelling against the Audio
  panel, or guard it with **Bus Exists**.
- **The last-sound actions only see THIS node's last shot.** The meta lives on the emitting node, so a
  **Set Last Sound Volume** in a different sheet retunes a different sound (or nothing at all, which
  is a safe no-op because of the `is_instance_valid` guard).
- **Put the last-sound row immediately after the Play Sound row.** Any other **Play Sound** in
  between - including one in a nested condition - moves the target.
- **Stop Last Sound frees the player.** There is nothing to resume afterwards; if you need to pause
  and continue, use a real `AudioStreamPlayer` node and the **Stop** / **Play** / **Seek** actions.
- **A one-shot cannot be looped or faded over time.** It is created, played and freed. Music,
  ambience and anything you want to fade belongs on a player node.
- **Percent and decibels are not interchangeable.** Feeding a slider's 0-100 into **Set Bus Volume**
  sets +50 dB, which is deafening and clips. Use **Set Bus Volume (percent)**, whose template does
  the `linear_to_db` and the clamp for you.
- **Set Master Volume (percent) is hard-wired to bus 0.** That is the Master bus in any default
  layout; if you reordered the layout so Master is not first, use **Set Bus Volume (percent)** with
  the name instead.
- **Effect slot numbers are positions, not names.** The top effect on a bus is 0. Reordering the
  effects in the Audio panel silently repoints every **Set Bus Effect Enabled** row that used the old
  index.
- **Solo is a mode, not a one-shot.** A bus left soloed keeps everything else silent forever. Always
  pair the solo-on row with a solo-off row.
- **Set Audio Playback Speed affects everything, including the UI.** If menu clicks should stay
  normal during slow motion, set the speed back to 1 before opening the pause menu.
- **The sound file parameter has a preview button.** In the params dialog the Sound field shows a
  play button, so you can hear the file before applying the row - use it instead of guessing from
  the filename.
