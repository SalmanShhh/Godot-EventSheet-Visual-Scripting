# Haptics - What A Hit Feels Like In The Hand

Haptics is the Godot EventSheets vocabulary for the rumble a player actually feels. The device's own two calls - buzz the phone for this many milliseconds, rumble the pad's motors - are the machine's vocabulary, not a game's. A game thinks in shapes: this is a tap, this is an alarm, the car is on gravel. A shape here is a **haptic pattern**, a small file the project owns saying how hard, how long, how many times and the air between, and one row plays it on whatever the player is holding. A pad gets its motors; a phone with no pad gets a buzz as long as the shape; a desktop with neither does nothing at all, quietly. Every amplitude is multiplied by the player's own haptic strength before it reaches a device, so a player who cannot bear the rumble turns it off once and keeps the game. Nothing ships: there is no house "success" and no house "failure", because how a game feels in the hand is the game's. The rows compile to plain typed GDScript in your project's own folder, with no plugin class named anywhere in them.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [The pattern file](#the-pattern-file)
5. [ACE reference](#ace-reference)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Hits that land.** A weapon, a punch or a landing with a shape behind it reads as heavier than the same animation without one.
- **UI you can feel your way around.** A menu item landing, a lock clicking home, a slider hitting its end: one short knock each, with no file to author.
- **Surfaces under a vehicle.** A continuous rumble whose amplitude is written again as the surface changes, at one call per change rather than one a frame.
- **Alarms and countdowns.** Four pulses with air between them is an alarm, and it is one file rather than four rows and a timer.
- **Accessibility that is a real setting.** One dial every row multiplies itself by, and 0 turns the whole vocabulary off without a branch anywhere in the sheet.
- **Cross-device games.** The same row is a pad rumble on a console, a buzz on a phone and silence on a desktop with no pad, without the sheet asking which it is on.
- **Rhythm and timing feedback.** A knock on the beat, or a pattern whose length the sheet can wait for exactly.
- **Charge and hold mechanics.** A rumble that starts when the trigger is squeezed, grows as the charge builds, and stops on release: three rows, three calls.
- **Options screens that tell the truth.** A condition that says whether this machine can rumble at all, so the slider is greyed rather than lying.
- **Web builds that do not warn.** A page has no motors, and every row above is silent there without a single message per hit.

---

## Core concepts

**A shape is a file, not three numbers on a row.** A tap is one short pulse; an alarm is four with air between; a heavy landing is one long one. Those are three shapes, and a game uses each of them in twenty places, so the shape belongs somewhere it can be tuned once and felt everywhere. That is a **HapticPatternResource** the project owns.

**Four numbers, and nothing else.** `amplitude` is how hard, from 0 to 1. `seconds` is how long one pulse lasts. `repeats` is how many pulses: one is a tap, four is an alarm. `gap_seconds` is the air between two pulses, and without it four repeats are one long buzz.

**Both motors get the same amplitude.** There is no weak-and-strong pair on a pattern, because a shape that reads differently on every pad is not a shape.

**One row, either device.** Playing a pattern reaches every pad that is plugged in. With no pad at all, it buzzes the handheld for the same length. With neither, it does nothing, and it does not warn: a machine that cannot rumble is not a fault to report every time somebody is hit.

**The player's own dial scales everything.** Every amplitude is multiplied by the haptic strength before it reaches a device, and 0 means off. It is one number read the same way the other accessibility dials are read. A "no flashing" setting does not touch it, because a rumble is not light.

**Emphasis is the punctuation mark.** One short strong knock with no file behind it, fixed at the shortest length a hand reads as a single knock rather than a buzz. A menu item landing, a lock clicking home, a step of a countdown.

**A continuous rumble is two calls, not a call a frame.** It starts at an amplitude and runs until it is stopped. Writing the amplitude again while it runs changes it, still at one call. Stopping is safe when nothing is running, which is what lets it sit on the row that ends a state with no condition in front of it.

**It costs nothing at rest.** A pattern of several pulses is one Tween of callbacks, one call per pulse, which the engine parks and frees the moment the last one lands.

---

## Setup

**1. Make a shape.** In the FileSystem dock, create a new resource of type **HapticPatternResource** and save it somewhere your project owns, for example `res://haptics/tap.tres`. A new one opens on the one shape that is not a taste: a single short tap at full strength. Everything else is made from there.

**2. Name it after the feeling, not the event.** `tap`, `knock`, `alarm`, `heavy_landing`. One shape is used in twenty places, and naming it after the first of them is what makes the twenty-first awkward.

**3. Play it.** The rows are in the **Vibration** category of the picker and need nothing attached to a node:

```
Player: On damaged
  -> Vibration: Haptic  "res://haptics/heavy_landing.tres"
```

**4. Give the player the dial.** One row on the options screen, and every haptic row in the game moves with it:

```
On Haptic Slider Changed
  -> Vibration: Set Haptic Strength  Settings.haptic_percent
```

**5. Ask before you show the slider.** A desktop with no pad has nothing to rumble, and the honest options screen says so:

```
On Options Opened
  Condition: Vibration: Haptics Can Be Felt  (inverted)
    -> HapticSlider: disable and label "no rumble device"
```

---

## The pattern file

| Property | Type | Default | Range | What it does |
|---|---|---|---|---|
| `amplitude` | float | `1.0` | 0 - 1 | How hard the pulse is, from 0 (nothing) to 1 (as hard as the device goes). Scaled by the player's own haptic strength before it reaches the device. |
| `seconds` | float | `0.08` | 0 - 5, or greater | How long one pulse lasts, in seconds. |
| `repeats` | int | `1` | 1 - 32, or greater | How many pulses. One is a tap; four with air between them is an alarm. |
| `gap_seconds` | float | `0.06` | 0 - 2, or greater | The air between two pulses, in seconds. Without it a repeat is not felt as a repeat. |

The whole shape's length is `repeats * seconds + (repeats - 1) * gap_seconds`, from the start of the first pulse to the end of the last. That is what a moment step declares as its duration, so a Hold above it knows how long to wait.

Some shapes worth having, and none of them ships:

| Shape | amplitude | seconds | repeats | gap_seconds |
|---|---|---|---|---|
| Tap | `0.6` | `0.05` | `1` | `0.0` |
| Knock | `1.0` | `0.08` | `1` | `0.0` |
| Double tap | `0.7` | `0.05` | `2` | `0.07` |
| Alarm | `0.9` | `0.12` | `4` | `0.10` |
| Heavy landing | `1.0` | `0.30` | `1` | `0.0` |

---

## ACE reference

All rows live in the **Vibration** category. The first three are the device's own words, and the rest are the hand's.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Stop Gamepad Vibration | `device` (int, `0`) | Stops a gamepad rumble that is still running. Device 0 is the first controller. |
| Vibrate Phone | `duration_ms` (int, `200`) | Buzzes a handheld device (phone or tablet) for a moment. Does nothing on desktop. |
| Haptic | `pattern` (pattern file, empty) | Plays one haptic shape - a file you own saying how hard, how long, how many times, and the air between the pulses. A pad gets its motors, a phone with no pad gets a buzz as long as the shape, and a machine with neither does nothing at all, quietly. Every amplitude is scaled by the player's own haptic strength first. |
| Haptic Emphasis | `strength` (float, `1.0`) | One short strong knock, with no file behind it - the punctuation mark of the vocabulary: a menu item landing, a lock clicking home, a step of a countdown. The player's haptic strength scales it like everything else. |
| Haptic Continuous Start | `amplitude` (float, `0.5`) | Starts a rumble that runs until it is stopped - the car on gravel, the drill in the wall, the engine under the seat. Run it again with a different amplitude to change it while it runs; it is ONE call each time, never a call a frame. 0 stops it. |
| Haptic Continuous Stop | (none) | Stops a continuous rumble. Safe to run when nothing is running, which is what lets it sit on the row that ends a state without a condition in front of it. |
| Set Haptic Strength | `percent` (`100`) | One dial every haptic row multiplies itself by, as a player setting rather than a designer's guess. 0 is off and the rows go quiet without a branch anywhere in the sheet. A "no flashing" setting does not touch it - a rumble is not light. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Haptic Is Playing | (none) | True while a pattern's pulses are still arriving, or a continuous rumble is running - the guard that stops a second shape being laid over the first. |
| Haptics Can Be Felt | (none) | True when this machine can rumble at all: a pad plugged in, or a phone in a hand. The rows above do nothing quietly where it is false, so this is for the options screen that wants to grey the slider out rather than for guarding every hit. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Gamepad Vibration Strength | `device` (int, `0`) | Vector2 | The current rumble strength of a gamepad as a Vector2 (weak motor, strong motor). |
| Haptic Strength | (none) | float | The haptic dial as 0 to 1, 1 when nobody has set it - what the options screen's slider reads to know where to start. |

### What a machine answers

| Machine | Haptic / Haptic Emphasis | Haptic Continuous Start | Haptics Can Be Felt |
|---|---|---|---|
| Pad plugged in | every connected pad's motors | every connected pad | `true` |
| Phone or tablet, no pad | a buzz as long as the shape | nothing to rumble continuously | `true` |
| Desktop, no pad | nothing, quietly | nothing, quietly | `false` |
| Web | nothing, quietly | nothing, quietly | `false` |

---

## Use cases

Every row below is in the **Vibration** category and needs nothing attached to a node.

### 1. A hit the player feels

The simplest use of the whole vocabulary: one shape, one row.

```
Player: On damaged
  -> Vibration: Haptic  "res://haptics/knock.tres"
```

The same row is a pad rumble on a console and a phone buzz on mobile, and the sheet never asks which.

### 2. A hit sized by how hard it was

Two shapes rather than one row with arithmetic in it, because a light hit and a heavy hit are different feelings and not the same feeling quieter.

```
Player: On damaged
  Condition: Damage.amount  >  Player.max_hp * 0.25
    -> Vibration: Haptic  "res://haptics/heavy_landing.tres"
  Else
    -> Vibration: Haptic  "res://haptics/tap.tres"
```

Keeping them as two files means an artist can retune the heavy hit without touching the light one.

### 3. A menu you can feel your way around

Emphasis needs no file, which is exactly right for the punctuation of a UI.

```
On Menu Item Focused
  -> Vibration: Haptic Emphasis  0.4

On Menu Item Chosen
  -> Vibration: Haptic Emphasis  1.0
```

The focus knock is quiet and the choice knock is firm, and neither is worth a file of its own.

### 4. A lock clicking home

A confirmation the hand hears before the eye does.

```
On Puzzle Piece Snapped
  -> Vibration: Haptic Emphasis  0.8
```

Emphasis is fixed at the shortest length a hand reads as a single knock, so it lands as a click rather than a buzz.

### 5. The car on gravel

One call when the surface changes, and one when the car stops. Nothing per frame.

```
Car: On surface changed
  Condition: Car.surface  =  "gravel"
    -> Vibration: Haptic Continuous Start  0.35
  Else
    -> Vibration: Haptic Continuous Stop

Car: On stopped
  -> Vibration: Haptic Continuous Stop
```

Stopping is safe when nothing is running, which is why the stop row needs no condition in front of it.

### 6. A rumble that grows with speed

Writing the amplitude again while a continuous rumble runs changes it, still at one call.

```
Car: On speed changed
  -> Vibration: Haptic Continuous Start  clamp(Car.speed / Car.top_speed, 0, 0.6)
```

Hang it off a speed-changed event rather than a per-frame row: the point of the continuous rumble is that it is not a call a frame.

### 7. A drill or a chainsaw held down

The rumble is the tool running, so it starts and stops with the input rather than with a timer.

```
On Drill Pressed
  -> Vibration: Haptic Continuous Start  0.5

On Drill Released
  -> Vibration: Haptic Continuous Stop
```

### 8. A charge that builds in the hand

The amplitude is the charge, so the player can feel how far along it is without looking at a meter.

```
On Charge Level Changed
  -> Vibration: Haptic Continuous Start  Player.charge * 0.7

On Charge Released
  -> Vibration: Haptic Continuous Stop
  -> Vibration: Haptic  "res://haptics/knock.tres"
```

Stopping the continuous rumble before the knock is what makes the release read as a release rather than as more of the same.

### 9. A countdown you can feel

Three knocks and a shape: the steps are emphasis, the go is a file.

```
On Countdown Tick
  Condition: Race.count  >  0
    -> Vibration: Haptic Emphasis  0.6
  Else
    -> Vibration: Haptic  "res://haptics/alarm.tres"
```

### 10. The player's own dial, wired once

One row on the options screen moves every haptic row in the game.

```
On Haptic Slider Changed
  -> Vibration: Set Haptic Strength  Settings.haptic_percent

On Options Opened
  -> HapticSlider: value = Vibration: Haptic Strength  * 100
```

The expression is what lets the slider open where the player left it rather than at a guess.

### 11. An honest options screen

A machine with nothing to rumble should say so rather than showing a slider that does nothing.

```
On Options Opened
  Condition: Vibration: Haptics Can Be Felt
    -> HapticSlider: enable
  Else
    -> HapticSlider: disable
    -> HapticNote: text = "No rumble device connected."
```

Every haptic row is already silent there, so this is about the screen telling the truth rather than about guarding the rows.

### 12. Do not lay a second shape over the first

A pattern still arriving is a hand that is busy.

```
Enemy: On damaged
  Condition: Vibration: Haptic Is Playing  (inverted)
    -> Vibration: Haptic  "res://haptics/tap.tres"
```

The condition is true while a pattern's pulses are still arriving or a continuous rumble is running, so it covers both.

### 13. Wait exactly as long as an alarm lasts

A pattern's length is `repeats * seconds + (repeats - 1) * gap_seconds`, so a sheet can time itself to it.

```
On Alarm Raised
  -> Vibration: Haptic  "res://haptics/alarm.tres"
  -> System: wait  0.78  seconds
  -> Doors: seal
```

An alarm of four pulses of 0.12 s with 0.10 s of air between them is 0.78 s long. Retune the file and this number changes with it, which is the one place a magic number is worth writing down beside the shape.

### 14. Turn the rumble off for a cutscene

The dial is the off switch, and it costs no branch anywhere else in the sheet.

```
On Cutscene Started
  -> Vibration: Haptic Continuous Stop
  -> Vibration: Set Haptic Strength  0

On Cutscene Finished
  -> Vibration: Set Haptic Strength  Settings.haptic_percent
```

Stopping the continuous rumble first matters: the dial scales what is played from now on, and a rumble already running keeps running.

### 15. A mobile-only buzz for a mobile-only moment

The device's own word, for when the game really does mean the phone.

```
On Notification Arrived
  Condition: Platform Info: is mobile
    -> Vibration: Vibrate Phone  120
```

Prefer a pattern for anything that is about how the game feels; reach for this when the length in milliseconds is the point.

### 16. Kill a stuck rumble on a pad

The device's own stop, for a rumble that another system started.

```
On Game Paused
  -> Vibration: Stop Gamepad Vibration  0
  -> Vibration: Haptic Continuous Stop
```

Both rows together cover a rumble started by any route.

### 17. Show what the pad is doing right now

A debug read that answers with the two motors as a Vector2.

```
Every tick
  Condition: Debug.overlay_open
    -> Debug Overlay: watch  Vibration: Gamepad Vibration Strength  0
```

### 18. One shape, twenty places

The reason a shape is a file rather than three numbers on a row.

```
On Menu Item Chosen
  -> Vibration: Haptic  "res://haptics/knock.tres"

On Chest Opened
  -> Vibration: Haptic  "res://haptics/knock.tres"

On Level Complete
  -> Vibration: Haptic  "res://haptics/knock.tres"
```

Retune `knock.tres` once and all twenty places move together, which is the whole argument for the file.

### Other use cases

**Fishing and tension.** A continuous rumble whose amplitude tracks the line tension, and a pattern for the bite, so the player learns to read the difference through the pad alone.

**Stealth detection.** A quiet double tap as an enemy's suspicion rises and a hard knock when it commits, giving the player the state of the world without a UI element on screen.

**Weapon identity.** A pattern per weapon, named after the feeling rather than the gun, so swapping the file on a weapon is a design change and not a code change.

**Health warnings.** A slow alarm pattern on a repeating timer under a health threshold, turned off by the same dial as everything else, so a player who cannot bear it is not locked out of the information.

**Cooking, crafting and mini-games.** An emphasis on every step landing and a pattern on the finish, which is enough feel to make a timing bar readable without looking at it.

---

## Tips and common mistakes

- **A pattern of several pulses needs a node to schedule on.** The first pulse always plays; the rest are scheduled on the node the row runs on. A row run from somewhere with no node in the tree plays the first pulse and honestly does not promise the others.
- **A desktop with no pad is silence, not an error.** Nothing warns, ever. If a shape seems not to be playing, check `Haptics Can Be Felt` before looking for a bug in the pattern.
- **Web has no motors.** Every row is silent in a browser build, by design and without a message. Design the feedback so the game is still readable without it.
- **0 on the dial is off for everything.** Set Haptic Strength is a multiplier, so 0 silences patterns, emphasis and continuous rumbles alike. It does not stop a rumble already running, which is why a pause row usually stops the continuous rumble as well.
- **Continuous rumble is not a per-frame row.** It is one call at the start and one at the stop. Putting Haptic Continuous Start in an every-tick event works, but it throws away the whole reason the row exists.
- **Always pair a start with a stop.** A continuous rumble outlives the scene that started it, because it is the device that is running rather than a node. End it on the state change, on pause, and on leaving the scene.
- **Both motors get one amplitude.** There is no weak-and-strong split on a pattern. Reach for the device's own rows if a specific motor is genuinely the point, and accept that the result reads differently on different pads.
- **Emphasis has no length of its own to tune.** It is fixed at the shortest pulse a hand reads as a single knock. If you need a longer knock, that is a pattern file.
- **A gap of 0 makes repeats one long buzz.** The air between pulses is what makes a repeat felt as a repeat, so an alarm with `gap_seconds` at 0 is just a long pulse.
- **Nothing ships, and that is deliberate.** There is no house success and no house failure pattern, because how a game feels in the hand is the game's. Expect to author four or five shapes and use them everywhere.
