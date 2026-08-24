# Day/Night Cycle - One Clock That Runs The Sky

Every day/night system anyone writes is the same three lines run forever: advance a clock, turn it
into a sun angle, lerp the colours. This pack owns those three and leaves the game the **moments**.

The clock, the shape of the day and the three curves are Inspector work. The sheet gets four
triggers (sunrise, sunset, midnight, the hour), two questions, one expression, and the four rows
that move the clock about.

Both dimensions work off the one clock. Point **Sun Light** at a `DirectionalLight3D` and **World
Lighting** at a `WorldEnvironment` for a 3D sky, or point World Lighting at the `CanvasModulate`
that holds a 2D level's darkness. A target left empty is skipped, so a project can adopt the
triggers alone and drive nothing at all.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **A world that keeps time.** Shops close, wolves come out, torches light themselves - all from
  triggers rather than from a timer somebody has to keep in sync.
- **2D and 3D from one behaviour.** The 2D half lifts the CanvasModulate colour the scene was
  authored with toward daylight instead of replacing it, so the designer's night colour survives.
- **A designer-owned look.** The three curves are drawn in Godot's own curve widget. Nobody has to
  touch a row to change how dusk feels.
- **Time as a mechanic.** *Set the time*, *Run the clock 4 times faster*, *Pause the clock* are the
  three verbs a bed, a cutscene and a debug key need.

## Core concepts

- **One clock, in hours.** `time_of_day` runs 0 to 24 and is the single source of truth; everything
  else is read from it. `day_length_minutes` says how long a whole day takes in real minutes, and
  `clock_scale` multiplies that rate without moving the hour.
- **Daylight is stretched over its own half of the turn.** Sunrise to sunset fills the first half of
  the sun's rotation and the night fills the second, whatever hours the project picks - so noon is
  overhead in a four-hour day, a night shift or a polar summer alike.
- **Two targets, and either dimension.** **Sun Light** is the light that plays the sun; **World
  Lighting** is a `WorldEnvironment` (3D) or a `CanvasModulate` (2D). Either left empty is skipped,
  so a project can take the triggers and drive nothing.
- **Three curves, read across the whole day.** Each is sampled at `time_of_day / 24`, so the left
  edge is midnight, the middle is noon and the right edge is midnight again. A curve nobody drew
  falls back to the pack's own daylight shape.
- **The moments are signals, and they only ring when the clock passes them.** *Set The Time* jumps
  the hour and does NOT ring the ones it skipped - a jump is one moment, not the twelve it passed.
- **Everything it writes is an ordinary property.** A rotation, a light's brightness, the ambient
  energy, a CanvasModulate colour. There is no lighting system underneath it.

## Setup

1. Add a `DayNightCycleBehavior` node anywhere in the level scene (it drives its targets by path, so
   it does not have to be under anything in particular).
2. Set **Sun Light** to the light that plays the sun, and **World Lighting** to the
   `WorldEnvironment` or the `CanvasModulate`. Leave either empty to drive neither.
3. Set **Day Length Minutes** to how long a whole day should take, and **Time Of Day** to the hour
   the scene opens on.
4. Optionally draw the three curves. Left to right is midnight to midnight.

```
On Sunset -> Streetlights | Light Pulse: Start Pulsing  0
          -> Torch        | Light Flicker: Start Flickering  1.5
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, exactly as the
rows draw them:

- Set the time to **hour**:00
- Run the clock **times_faster** times faster

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Set The Time | `hour` | Jumps the clock to an hour on the 24 hour clock, wrapping past the end of the day. |
| Action | Run The Clock Faster | `times_faster` | Changes how fast the clock runs without changing the time it is set to. |
| Action | Pause The Clock | - | Stops the clock where it is. The sky keeps whatever it is showing. |
| Action | Resume The Clock | - | Starts it again from where it was paused. |
| Condition | It Is Day | - | True between sunrise and sunset. |
| Condition | It Is Night | - | The other half of the same question, so a sheet never has to invert anything. |
| Expression | Time Of Day | - | What time it is now, as a number of hours: 8.5 is half past eight. |
| Trigger | On Sunrise | - | Fires as the clock passes Sunrise Hour. |
| Trigger | On Sunset | - | Fires as the clock passes Sunset Hour. |
| Trigger | On Midnight | - | Fires as the clock passes 0:00 - a whole game day has gone by. |
| Trigger | On The Hour | `hour` | Fires at every whole hour, carrying the hour it reached (0 to 23). |

Every exported knob is also a row: **Set Day Length Minutes**, **Set Sunrise Hour**, **Set Sunset
Hour**, **Set Clock Scale** and the rest, with the expressions that read them back.

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `day_length_minutes` | `20.0` | How long a whole game day takes in real minutes. |
| `sunrise_hour` | `6.0` | The hour the sun reaches the horizon on its way up. |
| `sunset_hour` | `19.0` | The hour it reaches the horizon on its way down. |
| `time_of_day` | `8.0` | What time it is now, on a 24 hour clock. |
| `clock_scale` | `1.0` | How many times faster than Day Length Minutes the clock really runs. 0 stops it. |
| `sun_brightness` | *(empty)* | Curve: how bright the sun light is through the day. |
| `ambient_brightness` | *(empty)* | Curve: how bright the environment's ambient light is. |
| `sky_tint_strength` | *(empty)* | Curve: how much daylight the sky itself carries. |
| `sun_light` | *(empty)* | The light that plays the sun. |
| `world_lighting` | *(empty)* | The `WorldEnvironment` or the `CanvasModulate` to drive. |

An empty curve is not an unlit sky: each one falls back to the arc the sun itself takes, so the
pack gives a working day before anybody opens the curve widget.

## Use cases

### 1. Streetlights at dusk

```
On Sunset -> Streetlights | Light Pulse: Start Pulsing  0
```

### 2. And out again at dawn

```
On Sunrise -> Streetlights | Light Pulse: Stop Pulsing  0
```

### 3. Something that only happens at three in the morning

```
On The Hour
  hour = 3 -> Ghosts: Spawn At  "graveyard"
```

The trigger carries the hour it struck, so one row branches on one hour.

### 4. A day counter

```
On Midnight -> System: Add 1 to Days Survived
```

### 5. Wolves that are braver after dark

```
Day/Night Cycle: It Is Night -> Wolves: Set Aggression  2.0
Day/Night Cycle: It Is Day   -> Wolves: Set Aggression  1.0
```

### 6. Sleeping until morning

```
On Bed Used -> Day/Night Cycle: Set The Time  6
            -> Scene Flow: Fade From Black  1.5
```

Jumping the clock does NOT ring the hours it skipped: a jump is one moment, not the twelve it
passed over.

### 7. A time-lapse while a menu is open

```
On Map Opened -> Day/Night Cycle: Run The Clock Faster  60
On Map Closed -> Day/Night Cycle: Run The Clock Faster  1
```

### 8. Pausing time during a cutscene

```
On Cutscene Started  -> Day/Night Cycle: Pause The Clock
On Cutscene Finished -> Day/Night Cycle: Resume The Clock
```

### 9. Showing the time on the HUD

```
Every tick -> HUD Kit: Set Label  "clock" = "%02d:%02d" % [int(Day/Night Cycle: Time Of Day), int(fmod(Day/Night Cycle: Time Of Day, 1.0) * 60)]
```

### 10. A shop that closes

```
On The Hour
  hour = 20 -> Shopkeeper: Walk To  "home"
            -> Shop Door: Lock
```

### 11. A curfew warning an hour before

```
On The Hour
  hour = 19 -> Dialogue Kit: Say  "The gates close at eight."
```

### 12. A boss that can only be fought at midnight

```
On Boss Door Touched
  Day/Night Cycle: Time Of Day > 23.5 -> Scene Flow: Change Scene  "res://boss.tscn"
  Else -> Dialogue Kit: Say  "Not yet. Come back at midnight."
```

### 13. A polar summer, or a night shift

Set `sunrise_hour` to 20 and `sunset_hour` to 4. The sun still peaks in the middle of ITS day rather
than at twelve o'clock: daylight and night are stretched over their own halves of the turn, so any
pair of hours gives a sun that is overhead halfway between them.

### 14. A 2D level whose darkness is the designer's

Point **World Lighting** at the level's `CanvasModulate` and leave its colour exactly as it was
authored. That colour is now this level's NIGHT, and the cycle lifts it toward daylight and back.
Two levels with two different night colours need no extra setup at all.

### 15. A 3D sky with a hand-drawn dusk

Point **World Lighting** at the `WorldEnvironment` and draw `ambient_brightness` with a shoulder
that stays up for half an hour after sunset. That half hour is dusk, and it exists nowhere in any
row.

### 16. A whole hearth that burns down over an evening

```
On The Hour
  hour > 20 -> Fireplace | Light Flicker: Set Between  Vector2(0.8 - (hour - 20) * 0.15, 1.2 - (hour - 20) * 0.15)
```

### Other use cases

**Tides.** Feed `Time Of Day` into a water plane's height and the sea follows the same clock the sky
does, with no second timer to keep in sync.

**Crop growth.** One On Midnight row per field advances every planted crop a stage - a farming game's
whole day loop is that row.

**Patrol schedules.** On The Hour with a comparison per guard is a town where everyone has somewhere
to be, written as rows rather than as a state machine.

**Timed multiplayer lobbies.** Run the clock at 60 and the sky becomes a match timer everyone can
see from anywhere in the level.

**A photo mode.** Pause the clock, expose `Set The Time` on a slider, and the player composes their
own golden hour.

## Tips and common mistakes

- **The two targets are paths, not parents.** They are picked in the Inspector and can point
  anywhere in the scene. That is what lets one behaviour drive a 2D level and a 3D sky.
- **An unset target is skipped, silently and on purpose.** A project that only wants the triggers
  should leave both empty; nothing warns, because nothing is wrong.
- **Only a 3D light turns.** A `DirectionalLight3D` gets its `rotation_degrees.x` written from the
  hour. A 2D light lies flat on the screen and only its brightness changes - which is correct, not a
  gap.
- **Curves read left to right across the whole day.** 0 on the curve is midnight and 1 is midnight
  again, NOT sunrise to sunset. Draw the night half deliberately rather than leaving it at zero.
- **`clock_scale` of 0 stops the clock.** It is the same stop that **Pause The Clock** does, with
  the difference that the row can be undone by **Resume** and the knob cannot.
- **Set The Time is the safe way to move the clock.** Writing `time_of_day` directly (through the
  generated **Set Time Of Day** row, or from code) moves the sky but leaves the hour bell where it
  was, so the next hour may ring twice or not at all. **Set The Time** re-baselines it.
- **Do not also tween the sun's brightness.** This pack writes it every frame from the curve; a
  tween on the same property will lose.
