# Music - The Song That Follows The Game

One song playing at a time, **crossfaded rather than cut**, with layers that come up as the
danger rises, a stinger over the top, the music ducking under a line of dialogue, and a beat
the rest of the game can hear. The Audio rows play a sound **on a player**, which is the right
shape for a footstep and the wrong shape for a song; this pack is the other shape.

The beat is **read, never counted**. Every beat answer is the stream's own playback position,
less the output latency your audio device adds on the way out, turned into beats at the track's
tempo. A counter written in a process event drifts against the song inside a minute; the
position cannot.

Tracks are `MusicTrackResource` files **you** own: the stream, its layers, its tempo and its
loop points, in a file you make where you keep your music. The pack ships none, and there is no
list of songs anywhere in the editor.

## Where this pack shines

- **Music that reacts without a mixer.** Danger rises, drums come up; the fight ends, they go
  back down. One row each way, and the layers cannot drift out of time with the song because
  they are one stream rather than several players started at the same moment and hoped for.
- **Dialogue you can hear over.** Duck on the line starting, Unduck on it finishing. The
  alternative is a tween on a bus volume written once per game and copied wrong twice.
- **Rhythm without a metronome.** On Beat, Beat Phase and Next Beat At come off the playback
  position, so a pulse on the beat stays on the beat for a twelve-minute track.
- **Pause menus that do not kill the song.** The director runs while the tree is paused, so the
  music plays under the menu unless a row says otherwise.
- **Scene changes that keep the mood.** Crossfade To at the top of the next scene, and the two
  songs cross over the load instead of stopping dead at it.
- **A stinger that ducks itself.** One row plays the flourish and holds the music down for
  exactly as long as the flourish lasts, then brings it back with nobody asking.

## Setup

There is nothing to attach and nothing to place in a scene. Music registers itself as the
**`Music`** autoload, the same shape as Scene Flow and Save System, so the director exists from
the first frame and every sheet reaches it by name with no node path.

1. Make a **Music** bus in Godot's Audio panel (Audio > Add Bus, rename it `Music`). The
   director plays out on it and Set Music Volume writes it, so an options-menu slider and this
   pack are moving the same fader.
2. Register the pack as the `Music` autoload (Tools > Register Autoload, or Project Settings >
   Globals).
3. Make a folder for your songs, `res://music/` by default, and create a **MusicTrackResource**
   in it per song: New Resource > MusicTrackResource, drop the audio file into **Stream**, set
   **BPM**, save it as `forest.tres`.
4. Play it by the file's name, with no path and no preloading:

```
On Ready -> Music: Play  "forest", 2.0
         -> Music: Set tempo  120, 0
```

A track file already carries its tempo, so that second row is only for a song whose file does
not, or for a tempo that changes mid-piece.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node
references in *italic*, exactly as the rows draw them:

- Play **track**, fade **fade** s
- Fade layer **layer** to **to** over **seconds** s
- Duck by **db** dB

No verb takes a node: every row addresses the `Music` autoload by name, and every expression
reads back as `Music.<Name>(args)` from any sheet in the project.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Play | `track` (String), `fade` (float) | Plays a track, crossfading down whatever was playing over the fade seconds. A fade of 0 is a cut. The name is looked up as a file in the Music Folder, or given as a full res:// path. |
| Crossfade To | `track` (String), `seconds` (float) | Crossfades to another track over the seconds given, the same machinery as Play spelled the way a music change reads. It always takes time; Play with a fade of 0 is the cut. |
| Stop | `fade` (float) | Fades the music out over the seconds given and frees the players. A fade of 0 stops it dead. |
| Pause | (none) | Pauses the music where it is. The director runs while the tree is paused, so a pause menu does NOT silence the song by itself: this is the row that does, and Resume carries on from the same place. |
| Resume | (none) | Carries on from where Pause left off, rather than starting the track again. |
| Stinger | `path` (String), `duck_db` (float) | Plays a one-shot over the music, the sting on a discovery or the flourish on a win, and ducks the music underneath it for exactly as long as the sound lasts, then brings it back up. |
| Duck | `db` (float), `seconds` (float) | Drops the music by that many decibels over the seconds given and leaves it there, under a line of dialogue, a radio call or a cutscene. Unduck brings it back. |
| Unduck | `seconds` (float) | Brings the music back up to full over the seconds given. |
| Set Music Volume | `level` (float) | Sets the music bus's volume from a 0 to 1 level, the number an options-menu slider gives, with the decibel conversion done for you. It writes the same bus the Options rows do. |
| Fade Layer | `layer` (String), `to` (float), `seconds` (float) | Fades one of the track's layers to a 0 to 1 volume over the seconds given: the drums coming in as the danger rises, the strings dropping out as it passes. The layers are one synchronized stream, so they cannot drift out of time with the song. |
| Set Layers | `layers` (String), `seconds` (float) | Says which layers are on, all at once, as a comma separated list: every layer named fades up, every other layer of the track fades down. It states the whole mix rather than changing one thing, so it is safe to fire on every state change. |
| Switch To Clip | `clip` (String) | Switches an interactive track to another of its clips by name. The stream's own transition rules decide when the change lands, on the bar, at the end of the clip or through a filler. Needs the track's stream to be an AudioStreamInteractive, which Godot 4.3 and later provide. |
| Set Tempo | `bpm` (float), `offset` (float) | Sets the tempo the beat is counted at, and how many seconds into the file the first beat lands. A track file carries both already: this is for a song whose file does not, or for a tempo that changes mid-piece. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Playing | (none) | True while a track is playing and not paused. |

### Expressions

| Expression | Parameters | Description |
|---|---|---|
| Current Track | (none) | The name of the track playing now, or nothing when the music is stopped. It is the Track Name written on the file when the file carries one. |
| Position In Bars | (none) | How far into the song the player is, counted in bars: the number a music-driven level reads to know where it is. |
| Beat Number | (none) | Which beat of the song is playing right now, counted from the track's first beat. |
| Seconds To Next Beat | (none) | How long until the next beat lands, in seconds: the wait before a move that should fire on the beat. Standing exactly on a beat it answers a WHOLE beat, because the beat you are standing on has already happened. |
| Beat Phase | (none) | How far through its beat the song is, from 0 on the beat to just under 1 before the next: the number a pulse, a bob or a breathing light rides on. |
| Next Beat At | (none) | The moment the next beat lands, on the same engine clock the Timed Input rows measure a press with. Put it in Beat Grade's Beat At slot and a press is graded against the song. |
| Layer Volume | `layer` (String) | How loud one of the track's layers is right now, from 0 to 1. |

### Triggers

| Trigger | Parameters | Description |
|---|---|---|
| On Beat | `number` (int) | Fires on every whole beat of the track that is playing, carrying the beat's own number counted from the track's offset. Read from where the stream has actually got to, less the output latency, so it lands where the player HEARS it. |
| On Bar | `number` (int) | Fires on the first beat of every bar, carrying the bar's number. How many beats a bar holds is the track's own Beats Per Bar, so a waltz bars in three without anything changing. |
| On Beat Number | `number` (int) | Fires on every nth beat, where n is the Beat Number Every setting: the phrase rather than the beat, for a change that should land on the eighth or the sixteenth rather than on each one. |

### The track file

A **MusicTrackResource** is one song written down. It is an ordinary resource: rename it,
retune it in the Inspector, duplicate it, share it.

| Property | Default | What it does |
|---|---|---|
| `track_name` | empty | What the track answers to, and what Current Track reads back. |
| `stream` | empty | The song itself. Set the file's own looping in the Import panel. |
| `layers` | `{}` | The extra streams that ride on top, by name. They all start silent; Fade Layer brings one up. Every layer must be the same length as the song, because they play as one synchronized stream. |
| `bpm` | `120` | The tempo. On Beat, On Bar, Beat Number and the rest are all counted from it. |
| `beat_offset` | `0` | Seconds from the start of the file to the first beat, for a song that does not begin exactly on one. |
| `beats_per_bar` | `4` | How many beats a bar holds. 3 for a waltz. |
| `loop_from` | `0` | Seconds into the file where the loop starts. A song is played from its beginning the first time it is asked for and from here every time after, so an intro is heard when the level opens and skipped when the song comes back. |
| `loop_to` | `0` | Seconds into the file where the loop ends. Set it past Loop From and the director sends the song back to Loop From when it gets there; leave it at 0 and the file plays to its end, looping only if the stream itself is set to. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `music_bus` | `Music` | The audio bus the music plays out on, and the bus Set Music Volume writes. |
| `music_folder` | `res://music/` | Where the Play row looks a track NAME up. A row may give a full res:// path instead, which skips the folder. |
| `beat_number_every` | `8` | How many beats apart On Beat Number fires. |
| `debug_mode` | `false` | Warns about a name that finds no file, a track with no stream, a missing bus, and a Switch To Clip on a stream that is not interactive. |

## Reading it from expressions

Type `Music` in any fx field, or open the fx **Expressions dictionary**, and the pack's seven
expressions are listed ready to insert: `Music.beat_phase()` for a pulse, `Music.next_beat_at()`
for a graded press, `Music.current_track()` for a now-playing label.

## Use cases

### 1. A song for the level

Two rows, no preloading, no player node.

```
On Ready -> Music: Play  "forest", 2.0
```

### 2. Crossfading into the boss fight

The old song walks out while the new one walks in, over the same two seconds.

```
On Boss Spawned -> Music: Crossfade To  "boss", 2.0
```

### 3. Drums when you are seen

The danger layer rides on the same stream, so it arrives in time rather than on the next bar
by luck.

```
On Spotted Player -> Music: Fade Layer  "drums", 1, 1.5
On Lost Player    -> Music: Fade Layer  "drums", 0, 4.0
```

### 4. A whole mix per game state

Set Layers states what the mix IS, so it is safe to fire on every state change rather than
having to remember which layer the last state left up.

```
On State Entered  state = "explore" -> Music: Set Layers  "pads", 2.0
On State Entered  state = "combat"  -> Music: Set Layers  "pads, drums, brass", 1.0
On State Entered  state = "stealth" -> Music: Set Layers  "pads, pulse", 1.0
```

### 5. Ducking under a line of dialogue

The Dialogue Kit tells you when a line starts and finishes; the music gets out of the way.

```
On Line Started  -> Music: Duck  8, 0.25
On Line Finished -> Music: Unduck  0.5
```

### 6. A sting on a discovery

One row: the flourish plays, the music ducks for its length, and comes back on its own.

```
On Secret Found -> Music: Stinger  "res://music/sting_secret.ogg", 6
```

### 7. A pause menu the music plays under

The director runs while the tree is paused, so the song keeps going by default. This is the
setting that stops it, for players who would rather have silence.

```
On Pause Pressed  Setting "music in menus" = false -> Music: Pause
On Resume Pressed Setting "music in menus" = false -> Music: Resume
```

### 8. The music slider in the options menu

The same bus the Options rows write, so the two cannot disagree.

```
On Value Changed -> Music: Set Music Volume  MusicSlider.value
```

### 9. A punch on the beat

The Juice pack's punch, fired by the song rather than by a timer.

```
On Beat -> Player | Juice: Punch Scale  1.1
```

### 10. A light that breathes with the song

Beat Phase runs 0 to 1 within every beat, which is exactly the shape a pulse wants.

```
Every tick -> Lamp | set energy to 1 + Music.Beat Phase() * 0.4
```

### 11. Grading a press against the song

The Timed Input module's Beat Grade has always taken a moment to grade against. Next Beat At
is that moment, on the same clock it measures the press with.

```
On Punch Pressed -> Set variable  grade = Timed Input.Beat Grade(Music.Next Beat At(), 0.08)
                 -> Hit | Play Sound  grade = "perfect" ? "res://sfx/perfect.ogg" : "res://sfx/good.ogg"
```

### 12. An enemy that only moves on the bar

On Bar fires once per bar rather than once per beat, so a chess-clock enemy needs no counter.

```
On Bar -> Enemy | Move To Grid Cell  ahead
```

### 13. A change that lands on the phrase

Set Beat Number Every to 8 in the Inspector, and On Beat Number is the eighth beat rather than
every one.

```
On Beat Number -> Music: Fade Layer  "arp", 1, 0.5
```

### 14. A now-playing label

Current Track reads the name written on the file, so a track renamed in the Inspector renames
itself everywhere.

```
On Beat -> NowPlaying | set text to Music.Current Track()
```

### 15. Firing something exactly on the next beat

Seconds To Next Beat is the wait. Nothing has to poll.

```
On Dash Pressed -> Wait  Music.Seconds To Next Beat() seconds
                -> Player | Dash
```

### 16. A track with an intro that loops past it

The first Play of a song is from its beginning, intro and all; every Play after it comes in at
Loop From. Set Loop To as well and the song goes round between the two on its own.

```
On Ready       -> Music: Play  "town", 0
On Returned    -> Music: Play  "town", 1.0
```

### 17. Music across a scene change

Scene Flow swaps the scene; the song crosses over the swap because the director is an autoload
and outlives both scenes.

```
On Transition Finished -> Music: Crossfade To  "cavern", 3.0
```

### 18. An interactive track that changes on its own terms

A track whose stream is an AudioStreamInteractive carries its own transition rules, so the
change lands where the composer said it should. Such a stream does not report a playback
position, so the beat readings and the beat moments are silent on it: a song answers either the
clips or the beat, not both.

```
On Health Below  0.3 -> Music: Switch To Clip  "desperate"
```

### 19. A music-driven level

Position In Bars says where the song is; the level reads it rather than keeping a clock of its
own.

```
Every tick  Music.Position In Bars() > 16 -> Spawner | Set Wave  2
```

### Other use cases

**Rhythm platformer.** Every hazard opens on On Bar and closes on the next, so the level is
choreographed by the song rather than by a dozen timers that drift apart.

**Radio in a car.** Each station is a track file, Crossfade To with a short fade is the dial,
and a static stinger between them sells the tuning.

**Horror proximity mix.** One layer per monster, faded to how close the nearest one is, so the
mix itself is the warning and no sound effect has to say it.

**Menu that keeps playing.** The title song plays under the whole menu, ducks for the button
whoosh, and crossfades into the first level's track as the game starts.

**Practice mode.** Set Tempo at nine tenths of the track's own bpm slows the grading without
touching the audio, so a player can learn a chart before playing it at speed.

## Tips and common mistakes

- **Make the bus first.** With no bus called `Music` in the Audio panel, Set Music Volume has
  nothing to write and says so in Debug Mode. The players still sound, on the default bus.
- **Layers must be the same length as the song.** They are played as one synchronized stream,
  which is what stops them drifting; a layer half as long as the song ends halfway through.
- **A layer nothing has faded is silent.** That is deliberate: a track starts as its base
  stream, and Fade Layer is how a layer arrives. Set Layers at the top of a level if you want
  several up from the first bar.
- **Set the tempo on the FILE, not in a row.** Set Tempo exists for songs whose files do not
  carry one; a track file that does means the beat rows work with nothing typed anywhere.
- **Beat Grade wants Next Beat At, not Beat Number.** The grade compares two moments on the
  engine clock. Beat Number is a count, and comparing a press against a count grades nothing.
- **Play with a fade of 0 is a cut.** Use it deliberately. Every other Play is a crossfade, and
  a crossfade started while one is running stops the older one rather than stacking a third
  song into the mix.
- **Pause is not the tree's pause.** The director runs always, on purpose, so a pause menu
  keeps the song. If you want silence in the menu, Pause is the row.

## Already written it by hand? It reads as this pack

Two AudioStreamPlayers and a tween that walks `volume_db` on both of them is the crossfade
this pack does in a row, and the shipped **Crossfade** row in the Audio section still reads a
hand-written two-player fade exactly as it always did: this pack lands beside it rather than
over it.

A beat counter written as `beats += delta * bpm / 60.0` in a process event is the thing On Beat
replaces, and the reason to replace it is not the row count. The counter and the song start
together and are half a beat apart by the end of the track, because a frame that took a moment
too long is a moment the song did not lose.
